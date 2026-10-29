# PostToolUseFailure hook: when a top-level grep/rg finds nothing, suggest a zg semantic query.
# Prints nothing (no hint) unless a usable zg index exists for the repo.

input=$(cat)

[ "$(jq -r '.tool_name' <<<"$input")" = Bash ] || exit 0
[ "$(jq -r '.is_interrupt // false' <<<"$input")" = false ] || exit 0

# Exit code 1 with no output is grep/rg's "no match"; any output means something else failed.
error=$(jq -r '.error // ""' <<<"$input")
[ "$(printf '%s' "$error" | tr -d '[:space:]')" = "Exitcode1" ] || exit 0

# Only searches that start a command or follow ; or &&, not `... | grep` filters.
command=$(jq -r '.tool_input.command // ""' <<<"$input")
grep -qE '(^|;|&&)[[:space:]]*(rg|grep|git grep)[[:space:]]' <<<"$command" || exit 0

session=$(jq -r '.session_id // "none"' <<<"$input")
cwd=$(jq -r '.cwd // "."' <<<"$input")

# At most one hint per session every 10 minutes.
marker="${TMPDIR:-/tmp}/zg-hint-$session"
if [ -n "$(find "$marker" -mmin -10 2>/dev/null)" ]; then
  exit 0
fi

has_index() {
  local status
  status=$(cd "$1" && zg status 2>/dev/null) || return 1
  grep -q '^  Embedding' <<<"$status"
}

if has_index "$cwd"; then
  run='zg query --vector "<one sentence describing the behaviour>" --limit 5'
else
  # A worktree has no index of its own; the main checkout's index returns the same paths.
  common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
  main=$(dirname "$common")
  has_index "$main" || exit 0
  run="cd $main && zg query --vector \"<one sentence describing the behaviour>\" --limit 5"
  run="$run (main checkout's index; read the hits in this worktree)"
fi

touch "$marker"

hint="No matches. If you are searching for a behaviour rather than a known name, run: $run"
jq -n --arg ctx "$hint" \
  '{hookSpecificOutput: {hookEventName: "PostToolUseFailure", additionalContext: $ctx}}'
