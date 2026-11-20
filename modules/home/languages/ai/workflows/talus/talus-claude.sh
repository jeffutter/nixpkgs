# talus-claude: the deterministic half of the talus-loop Claude workflow.
#
# A workflow script cannot run commands, so its agents run this and copy back the one JSON line
# it prints. Every path, branch and terminal name comes out of command output here, never out of
# a model retyping it. Same steps as the pi extension (pi-extensions/talus/index.ts); the worker
# it starts is `claude` running the ralph-scree-loop workflow instead of `pi` running /ralph-scree.
#
#   talus-claude preflight ID...                 tools, root checkout, tickets; subtasks folded
#   talus-claude launch ID MAX_PER_TICKET REVIEW_EVERY
#                                                worktree + scree move + herdr space + claude
#   talus-claude wait TERM PATH RESULT_FILE [SECONDS]
#                                                block until the worker finishes, exits, stalls, or
#                                                SECONDS
#   talus-claude nudge TERM RESULT_FILE MAX_PER_TICKET REVIEW_EVERY
#                                                tell a stalled worker to rerun its workflow
#   talus-claude drafts PATH                     ids of the agent drafts in that checkout
#   talus-claude promote PATH ID...              draft -> ready for each id, in that checkout
#   talus-claude merge-info ID                   branch, worktree and Herdr space of a done ticket, and
#                                                whether its branch is already in the current branch
#   talus-claude cleanup BRANCH PATH TERM        after a merge: close the Herdr space, remove the
#                                                worktree and branch (refuses unless merged and clean)
#   talus-claude rerun TERM PATH RESULT_FILE MAX_PER_TICKET REVIEW_EVERY
#                                                clear the result and tell an idle worker to run
#                                                its workflow again (for follow-up tickets)
#
# Every subcommand prints exactly one JSON object as its last stdout line and exits 0, errors
# included ({"ok":false,"error":...}), so the caller always has something to parse.

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/talus-claude"
POLL_SECONDS=20
# A worker whose session sits idle this long with no result file has lost its workflow (it failed
# in seconds, or never started): the session is waiting for a person, not for the workflow.
STALL_SECONDS=180

emit() { jq -cn "$@"; }
fail() {
  emit --arg e "$1" '{ok:false,error:$e}'
  exit 0
}

# The last three non-empty lines of a failed command's output, for an error message.
tail3() { printf '%s\n' "$1" | sed '/^[[:space:]]*$/d' | tail -n 3 | paste -sd'|' - | sed 's/|/ \/ /g'; }

main_root() {
  local common
  common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  realpath "${common%/.git}"
}

# Sets ROOT. Not called through $(...): fail() must exit the script, not a subshell.
require_root() {
  local here
  ROOT=$(main_root) || fail "talus must run inside a git repository"
  here=$(realpath "$PWD")
  [ "$here" = "$ROOT" ] ||
    fail "talus runs from the root checkout so it can hand worktrees to other sessions: you are in $here, the repo root is $ROOT"
}

# scree show as one compact object with the fields talus needs, or nothing.
read_ticket() {
  scree show "$1" --json 2>/dev/null | jq -c '{
    id: (.id // ""),
    title: (.title // ""),
    status: (.status // ""),
    for: (.for // "agent"),
    parent: (.parent // ""),
    worktree: (.worktree // "")
  }' 2>/dev/null || true
}

# scr-12-add-greet-sh: ticket id first so wt list, the Herdr sidebar and scree sort together.
branch_name() {
  local key slug
  key=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
  slug=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -d- -f1-5)
  local b="scr-$key${slug:+-$slug}"
  printf '%s' "${b:0:60}"
}

# hc names: [a-z][a-z0-9_-]{0,31}. The space id uses the same shape.
term_name() {
  local n
  n="talus-$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g')"
  printf '%s' "${n:0:32}"
}

board_counts() {
  local ready active
  ready=$(cd "$1" && scree list --status ready --limit 200 --json 2>/dev/null | jq '.tickets | length') || return 1
  active=$(cd "$1" && scree list --status active --limit 200 --json 2>/dev/null | jq '.tickets | length') || return 1
  [ -n "$ready" ] && [ -n "$active" ] || return 1
  emit --argjson r "$ready" --argjson a "$active" '{ready:$r,active:$a}'
}

# JSON array of the ids of the agent drafts in a checkout. The loop's review files its findings
# there as drafts, which is how talus finds the follow-ups it should promote.
draft_ids() {
  (cd "$1" && scree list --status draft --for agent --limit 200 --json 2>/dev/null) | jq -c '[.tickets[].id]'
}

cmd_preflight() {
  [ "$#" -gt 0 ] || fail "give me ticket ids, e.g. SCR-1 SCR-2"
  for tool in wt scree hc herdr-app claude jq; do
    command -v "$tool" >/dev/null || fail "talus needs \`$tool\` on PATH"
  done
  require_root

  local ids=() id
  for id in "$@"; do ids+=("$(printf '%s' "$id" | tr '[:lower:]' '[:upper:]')"); done
  local dups
  dups=$(printf '%s\n' "${ids[@]}" | sort | uniq -d | paste -sd, -)
  [ -z "$dups" ] || fail "duplicate ticket ids in the list: $dups"

  # Every ticket must resolve before anything is touched: a typo fails here, not after three
  # worktrees exist.
  local tickets="[]" t
  for id in "${ids[@]}"; do
    t=$(read_ticket "$id")
    [ -n "$t" ] || fail "scree has no ticket $id visible from this checkout (is it in another worktree? \`scree list --all-worktrees\`)"
    tickets=$(jq -c --argjson t "$t" --arg id "$id" '. + [$t + {id:$id}]' <<<"$tickets")
  done

  # A subtask named next to its own parent travels in the parent's worktree; two sessions on one
  # ticket would fight over the claim.
  jq -c --arg root "$ROOT" '
    (map(.id)) as $ids
    | def folded: .parent as $p | $p != "" and ($ids | any(. == $p));
      {ok:true, root:$root,
       tickets: [ .[] | select(folded | not) ],
       dropped: [ .[] | select(folded) | {id, parent} ]}
  ' <<<"$tickets"
}

# The checkout a ticket is worked in: the one it already lives in when fanned out before (so a
# rerun continues instead of forking), else a fresh worktree with the ticket moved into it.
# Prints "path<TAB>branch<TAB>note", or a {"ok":false} JSON line when it fails (it runs in a
# subshell, so its fail() cannot end the script; the caller checks for the JSON).
ensure_checkout() {
  local root=$1 id=$2 title=$3 attached=$4
  if [ -n "$attached" ]; then
    local existing
    existing=$(realpath -m "${attached/#\~/$HOME}")
    if [ "$existing" != "$root" ]; then
      [ -d "$existing" ] ||
        fail "$id is filed under worktree $existing, which no longer exists. Recreate it or move the ticket with \`scree move $id --root\`."
      local b
      b=$(git -C "$existing" branch --show-current 2>/dev/null || true)
      printf '%s\t%s\t%s' "$existing" "${b:-(detached HEAD)}" "existing worktree"
      return
    fi
  fi

  # The first free name of base, base-2 ... base-19. Only when all of those exist is base
  # reused (switched to, not created), which is what talus does too.
  local base branch create=1 n
  base=$(branch_name "$id" "$title")
  branch=$base
  if git show-ref --verify --quiet "refs/heads/$base"; then
    branch=""
    for n in $(seq 2 19); do
      if ! git show-ref --verify --quiet "refs/heads/$base-$n"; then
        branch="$base-$n"
        break
      fi
    done
    [ -n "$branch" ] || { branch=$base; create=0; }
  fi

  local out rc=0
  if [ "$create" = 1 ]; then
    out=$(wt switch --create --no-cd --format=json "$branch" 2>&1) || rc=$?
  else
    out=$(wt switch --no-cd --format=json "$branch" 2>&1) || rc=$?
  fi
  if [ "$rc" != 0 ]; then
    local hint=""
    case "$out" in *approval*) hint=" - project hooks need your approval; run \`wt config approvals add\` yourself" ;; esac
    fail "wt switch failed: $(tail3 "$out")$hint"
  fi
  # Project hooks print before the result, so the path is on the last JSON line.
  local path
  path=$(printf '%s\n' "$out" | grep '^[[:space:]]*{' | tail -n 1 | jq -r '.path // empty' 2>/dev/null || true)
  [ -n "$path" ] || fail "$id: wt switch printed no worktree path"
  path=$(realpath -m "${path/#\~/$HOME}")

  local mv
  mv=$(scree move "$id" --worktree "$path" --json 2>&1) ||
    fail "scree move $id failed: $(tail3 "$mv") (worktree $path was created and is yours to remove)"
  # Context the workers read off the ticket: where they are and why.
  (cd "$path" && scree comment add "$id" "talus: moved to worktree $path on branch $branch." >/dev/null 2>&1) || true
  printf '%s\t%s\t%s' "$path" "$branch" ""
}

cmd_launch() {
  [ "$#" = 3 ] || fail "usage: talus-claude launch ID MAX_PER_TICKET REVIEW_EVERY"
  local id max_per review
  id=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
  max_per=$2
  review=$3
  require_root

  local t
  t=$(read_ticket "$id")
  [ -n "$t" ] || fail "$id: scree could not read the ticket"
  local status for title attached
  status=$(jq -r .status <<<"$t")
  for=$(jq -r .for <<<"$t")
  title=$(jq -r .title <<<"$t")
  attached=$(jq -r .worktree <<<"$t")
  if [ "$status" = "done" ] || [ "$status" = "abandoned" ]; then
    emit --arg s "$status" '{ok:true,skipped:true,note:("already " + $s)}'
    return
  fi
  [ "$for" != human ] || fail "$id is assigned to a human; talus does not move those"

  local co path branch note
  co=$(ensure_checkout "$ROOT" "$id" "$title" "$attached")
  case "$co" in \{*) printf '%s\n' "$co"; return ;; esac
  IFS=$'\t' read -r path branch note <<<"$co"

  local baseline
  baseline=$(draft_ids "$path") || baseline='[]'
  [ -n "$baseline" ] || baseline='[]'

  local term result
  term=$(term_name "$id")
  mkdir -p "$STATE_DIR"
  result="$STATE_DIR/$term.json"
  rm -f "$result"

  # The worker's whole first message. A Claude session counts a plain request to run a named
  # workflow as opt-in; the result file is how this script knows the loop finished, since the
  # session goes idle as soon as the workflow starts in the background.
  local args prompt
  args=$(emit --argjson m "$max_per" --argjson r "$review" '{maxIterations:$m,reviewEvery:$r}')
  # The harness shows this message to every agent the workflow starts, as "the user request that
  # wins over the task text". A bare "do not do the work yourself" made one of those agents refuse
  # its own extraction task, so the message says the workflow's agents are expected to work.
  prompt="Your only job in this session: start the saved workflow ralph-scree-loop (Workflow tool, name \"ralph-scree-loop\") with args $args, then write the value it returns, as JSON, to $result with the Write tool, and stop. Do not do the tickets' work in this top-level session. The workflow's own agents run scree, git, tests and tools as their task text says; that is expected and covered by this request, so they must carry out their tasks and answer with the structured output they are asked for."

  # --no-notify: hc would otherwise type notes about the worker into the parent, which is the
  # Claude session running the talus-loop workflow. --add-dir lets the worker write its result
  # without a prompt. Children end with their parent's program, as under pi.
  # Absolute path: the terminal gets the herdr-core environment, whose PATH is not this one.
  local claude_bin started
  claude_bin=$(command -v claude)
  started=$(hc run --bg --no-notify --name "$term" --cwd "$path" --label "herdr.space=$term" -- \
    "$claude_bin" --permission-mode auto --add-dir "$STATE_DIR" -n "$id $title" "$prompt" 2>&1) ||
    fail "hc run failed: $(tail3 "$started") (ticket $id now lives in $path)"

  # Cosmetic: name the space after the ticket. A rename while hc is still registering the
  # terminal comes back nospace, so retry briefly and then leave the folder-derived name.
  local name n r
  name=$(printf '%s %s' "$id" "$title" | cut -c1-48)
  for n in 1 2 3 4 5 6; do
    if r=$(herdr-app "do" space.rename "$(emit --arg id "$term" --arg n "$name" '{id:$id,name:$n}')" 2>&1) &&
      ! grep -q error <<<"$r"; then
      break
    fi
    sleep 2
  done

  emit --arg path "$path" --arg branch "$branch" --arg term "$term" --arg result "$result" --arg note "$note" \
    --argjson drafts "$baseline" \
    '{ok:true,skipped:false,path:$path,branch:$branch,term:$term,resultFile:$result,note:$note,drafts:$drafts}'
}

cmd_wait() {
  [ "$#" -ge 3 ] || fail "usage: talus-claude wait TERM PATH RESULT_FILE [SECONDS]"
  local term=$1 path=$2 result=$3 limit=${4:-540}
  local waited=0 agent_state="" info idle=0
  while :; do
    if [ -s "$result" ]; then
      local board loop
      board=$(board_counts "$path") || fail "scree did not answer in $path"
      loop=$(jq -c . "$result" 2>/dev/null || jq -Rsc . "$result")
      # Drained: nothing ready or active left here. Drafts are not the loop's business.
      jq -c --argjson loop "$loop" '
        {ok:true, status: (if .ready + .active == 0 then "drained" else "ended" end),
         remaining: ., loop: $loop}' <<<"$board"
      return
    fi
    if ! info=$(hc get "$term" --json 2>&1); then
      case "$info" in
        *not_found*) emit '{ok:true,status:"gone",note:"terminal not found"}'; return ;;
      esac
    else
      if [ "$(jq -r .state <<<"$info")" != live ]; then
        emit --arg c "$(jq -r '.exit_code // "?"' <<<"$info")" \
          '{ok:true,status:"gone",note:("terminal exited (code " + $c + ") without writing a result")}'
        return
      fi
      agent_state=$(jq -r '.status | if type == "object" then .state else . end // ""' <<<"$info")
      # "done" is the session idle at its prompt. A running workflow keeps it "working".
      if [ "$agent_state" = "done" ]; then idle=$((idle + POLL_SECONDS)); else idle=0; fi
      if [ "$idle" -ge "$STALL_SECONDS" ]; then
        emit '{ok:true,status:"stalled",note:"session idle with no result file; its workflow probably failed"}'
        return
      fi
    fi
    [ "$waited" -lt "$limit" ] || break
    sleep "$POLL_SECONDS"
    waited=$((waited + POLL_SECONDS))
  done
  emit --arg a "$agent_state" '{ok:true,status:"running",agentState:$a}'
}

# What the merge step needs to know about one finished ticket, from command output only. Fails
# (so the merge stops) when the ticket is not done, lives in the root checkout, or its worktree is
# missing or has uncommitted changes, and when the root checkout is not clean to merge into.
cmd_merge_info() {
  [ "$#" = 1 ] || fail "usage: talus-claude merge-info ID"
  local id t status attached path branch base head merged ahead
  id=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
  require_root
  [ -z "$(git status --porcelain --untracked-files=no)" ] ||
    fail "the root checkout has uncommitted changes; commit or stash them before merging into it"
  base=$(git branch --show-current)
  [ -n "$base" ] || fail "the root checkout is on a detached HEAD"
  t=$(read_ticket "$id")
  [ -n "$t" ] || fail "$id: scree could not read the ticket"
  status=$(jq -r .status <<<"$t")
  [ "$status" = "done" ] || fail "$id is $status, not done; it is not ready to merge"
  attached=$(jq -r .worktree <<<"$t")
  [ -n "$attached" ] || fail "$id lives in the root checkout; there is no branch to merge"
  path=$(realpath -m "${attached/#\~/$HOME}")
  [ -d "$path" ] || fail "$id: worktree $path no longer exists"
  branch=$(git -C "$path" branch --show-current 2>/dev/null || true)
  [ -n "$branch" ] || fail "$id: worktree $path is not on a branch"
  [ -z "$(git -C "$path" status --porcelain --untracked-files=no)" ] ||
    fail "$id: worktree $path has uncommitted changes"
  head=$(git rev-parse HEAD)
  if git merge-base --is-ancestor "$branch" HEAD; then merged=true; else merged=false; fi
  ahead=$(git rev-list --count "HEAD..$branch")
  emit --arg id "$id" --arg title "$(jq -r .title <<<"$t")" --arg branch "$branch" --arg path "$path" \
    --arg term "$(term_name "$id")" --arg base "$base" --arg head "$head" \
    --argjson merged "$merged" --argjson ahead "$ahead" \
    '{ok:true,id:$id,title:$title,branch:$branch,path:$path,term:$term,base:$base,head:$head,merged:$merged,ahead:$ahead}'
}

# Close a merged ticket's workspace: the Herdr space (which ends its terminal), then the worktree
# and branch. Refuses unless the branch is already in the current branch and the worktree is clean,
# so nothing unmerged is ever removed.
cmd_cleanup() {
  [ "$#" = 3 ] || fail "usage: talus-claude cleanup BRANCH PATH TERM"
  local branch=$1 path=$2 term=$3 r closed=false
  require_root
  git show-ref --verify --quiet "refs/heads/$branch" || fail "no branch $branch"
  git merge-base --is-ancestor "$branch" HEAD || fail "$branch is not merged into $(git branch --show-current); not removing it"
  if [ -d "$path" ]; then
    [ -z "$(git -C "$path" status --porcelain --untracked-files=no)" ] ||
      fail "worktree $path has uncommitted changes; not removing it"
  fi

  if r=$(herdr-app "do" space.close "$(emit --arg id "$term" '{id:$id,confirmed:true}')" 2>&1) &&
    ! grep -q '"error"' <<<"$r"; then
    closed=true
  fi
  # A terminal that survived the space (or had no space) is ended directly.
  if hc get "$term" --json >/dev/null 2>&1; then
    hc kill "$term" >/dev/null 2>&1 || true
    hc rm "$term" >/dev/null 2>&1 || true
  fi

  r=$(wt remove "$branch" 2>&1) || fail "wt remove $branch failed: $(tail3 "$r")"
  # wt removes in the background: wait for the directory and the branch to go.
  for _ in $(seq 1 30); do
    if [ ! -e "$path" ] && ! git show-ref --verify --quiet "refs/heads/$branch"; then
      emit --argjson c "$closed" '{ok:true,spaceClosed:$c,removed:true}'
      return
    fi
    sleep 1
  done
  fail "wt remove $branch started but $path or the branch is still there after 30 s"
}

# Type a retry request into a stalled worker. Sent as one message; the worker treats it like the
# first prompt. If the workflow is in fact still running it is told to do nothing.
cmd_nudge() {
  [ "$#" = 4 ] || fail "usage: talus-claude nudge TERM RESULT_FILE MAX_PER_TICKET REVIEW_EVERY"
  local term=$1 result=$2 max_per=$3 review=$4 args msg out
  args=$(emit --argjson m "$max_per" --argjson r "$review" '{maxIterations:$m,reviewEvery:$r}')
  msg="Your ralph-scree-loop workflow is not running and no result file exists. Check /workflows. If it is still running, do nothing. Otherwise run the saved workflow ralph-scree-loop again (Workflow tool) with args $args, then write the value it returns, as JSON, to $result with the Write tool. If it fails again, write {\"stopReason\":\"failed\",\"error\":\"<the error text>\"} to that file instead. Its agents must carry out their own tasks and return the structured output they are asked for."
  out=$(hc send "$term" "$msg" 2>&1) || fail "hc send to $term failed: $(tail3 "$out")"
  emit --arg t "$term" '{ok:true,nudged:$t}'
}

cmd_drafts() {
  [ "$#" = 1 ] || fail "usage: talus-claude drafts PATH"
  local ids
  ids=$(draft_ids "$1") && [ -n "$ids" ] || fail "scree did not answer in $1"
  emit --argjson ids "$ids" '{ok:true,ids:$ids}'
}

cmd_promote() {
  [ "$#" -ge 2 ] || fail "usage: talus-claude promote PATH ID..."
  local path=$1 id out promoted="[]" failed="[]"
  shift
  for id in "$@"; do
    if out=$(cd "$path" && scree ready "$id" --json 2>&1); then
      promoted=$(jq -c --arg i "$id" '. + [$i]' <<<"$promoted")
    else
      failed=$(jq -c --arg i "$id" --arg e "$(tail3 "$out")" '. + [{id:$i,error:$e}]' <<<"$failed")
    fi
  done
  emit --argjson p "$promoted" --argjson f "$failed" '{ok:true,promoted:$p,failed:$f}'
}

# The worker session is still alive after it writes its result (it just goes idle), so follow-up
# tickets are worked by telling that same session to run the workflow again.
cmd_rerun() {
  [ "$#" = 5 ] || fail "usage: talus-claude rerun TERM PATH RESULT_FILE MAX_PER_TICKET REVIEW_EVERY"
  local term=$1 path=$2 result=$3 max_per=$4 review=$5 info args msg out
  info=$(hc get "$term" --json 2>&1) || fail "terminal $term is gone; its worktree is $path - start the loop there by hand"
  [ "$(jq -r .state <<<"$info")" = live ] || fail "terminal $term has exited; its worktree is $path - start the loop there by hand"
  args=$(emit --argjson m "$max_per" --argjson r "$review" '{maxIterations:$m,reviewEvery:$r}')
  rm -f "$result"
  msg="New ready tickets were added in this checkout. Run the saved workflow ralph-scree-loop again (Workflow tool) with args $args, then write the value it returns, as JSON, to $result with the Write tool, and stop. Do not do the tickets' work in this top-level session. The workflow's agents must carry out their own tasks and return the structured output they are asked for."
  out=$(hc send "$term" "$msg" 2>&1) || fail "hc send to $term failed: $(tail3 "$out")"
  emit --arg t "$term" '{ok:true,rerun:$t}'
}

sub=${1:-}
shift || true
case "$sub" in
  preflight) cmd_preflight "$@" ;;
  launch) cmd_launch "$@" ;;
  wait) cmd_wait "$@" ;;
  nudge) cmd_nudge "$@" ;;
  drafts) cmd_drafts "$@" ;;
  promote) cmd_promote "$@" ;;
  rerun) cmd_rerun "$@" ;;
  merge-info) cmd_merge_info "$@" ;;
  cleanup) cmd_cleanup "$@" ;;
  *) fail "usage: talus-claude preflight|launch|wait|nudge|drafts|promote|rerun|merge-info|cleanup ..." ;;
esac
