#!/usr/bin/env bash
# List tasks in a given status (default "To Do") whose dependencies (if any) are all Done,
# split by who is allowed to do the work.
#
# Usage: unblocked-todo.sh [status] [--assignee agent|human|all]
#   --assignee agent   (default) Tickets an agent may pick up: unassigned, or assigned to
#                      anyone other than @human.
#   --assignee human   Tickets waiting on a person — identical dependency and container
#                      checks, opposite side of the assignment. This is what the ralph loop
#                      reports when it has run out of its own work but the project hasn't
#                      finished, so "nothing to do" never gets confused with "your turn".
#   --assignee all     No assignee filter. For status bookkeeping rather than work selection:
#                      promoting Blocked -> To Do must not depend on who owns the ticket, or a
#                      @human ticket sits in Blocked forever and every dependent looks blocked
#                      forever too.
#
# Why "agent" is the default even though it changes what a bare invocation prints: the two
# ways to get this wrong are not symmetric. Listing too narrowly idles the loop, which is
# loud and costs nothing. Listing too wide hands a hardware-verification ticket to an agent
# that can only spin on it — observed on TASK-004, where the executor correctly reported that
# a person had to flash the board, produced no commit, tripped the "claimed success but no
# commit landed" guard, and was re-picked until the failure-streak guard halted the whole run.
# Callers that want everything pass --assignee all explicitly.
#
# Container tickets are held back in every mode: a ticket with an unfinished child is never
# listed, because there is nothing left to execute on it — its children own the remaining
# work. See the check below for why this matters and how a parent becomes eligible again.
#
# Deployed globally (see ai.nix) alongside the ralph pi extension, so unlike the original
# gql-fiddle copy this can't locate the backlog directory via its own path ($0) — it's invoked
# with cwd set to the target project's root instead, and cds into that project's backlog/.
set -euo pipefail
cd backlog

TARGET_STATUS="To Do"
ASSIGNEE_MODE="agent"
while [ $# -gt 0 ]; do
  case "$1" in
    -a | --assignee)
      ASSIGNEE_MODE="${2:-}"
      shift 2
      ;;
    --assignee=*)
      ASSIGNEE_MODE="${1#*=}"
      shift
      ;;
    *)
      TARGET_STATUS="$1"
      shift
      ;;
  esac
done

# A typo'd mode must not quietly mean "no filter" — see the TASK-004 asymmetry above.
case "$ASSIGNEE_MODE" in
  agent | human | all) ;;
  *)
    echo "unblocked-todo.sh: unknown --assignee '$ASSIGNEE_MODE' (expected agent, human or all)" >&2
    exit 1
    ;;
esac

frontmatter() {
  awk '/^---$/{c++; next} c==1' "$1"
}

# Least authoritative directory first, most authoritative last, because assignment overwrites
# on ID collision and the live task must win.
#
# IDs are not guaranteed unique across these directories: archiving a task keeps its ID and
# its status verbatim, so an archived stub can share an ID with a real task. Observed live —
# an abandoned scratch task sat in archive/ as "To Do" under the same ID as a completed task,
# and being read last it overwrote the real "Done". Everything depending on that ID looked
# permanently blocked, so the loop quietly starved with no error anywhere. `backlog doctor`
# cannot catch this: it only scans active and completed tasks, not archive/.
declare -A status_of
for f in archive/tasks/*.md completed/*.md tasks/*.md; do
  [ -f "$f" ] || continue
  fm=$(frontmatter "$f")
  id=$(printf '%s\n' "$fm" | yq -r '.id')
  st=$(printf '%s\n' "$fm" | yq -r '.status')
  status_of["$id"]="$st"
done

for f in tasks/*.md; do
  [ -f "$f" ] || continue
  fm=$(frontmatter "$f")
  st=$(printf '%s\n' "$fm" | yq -r '.status')
  [ "$st" = "$TARGET_STATUS" ] || continue

  id=$(printf '%s\n' "$fm" | yq -r '.id')
  title=$(printf '%s\n' "$fm" | yq -r '.title')
  mapfile -t deps < <(printf '%s\n' "$fm" | yq -o=json '.dependencies // []' | jq -r '.[]')

  blocked=false
  for d in "${deps[@]:-}"; do
    [ -z "$d" ] && continue
    if [ "${status_of[$d]:-MISSING}" != "Done" ]; then
      blocked=true
      break
    fi
  done

  # Container tickets compete with their own children unless held back: sub-tasks are made
  # dependencies OF nothing — the parent has no dependencies of its own, so once planning puts
  # it in the target status it looks fully unblocked and gets picked alongside 62.3/62.4.
  # Confirmed live on TASK-62: the executor was handed the parent while two children were still
  # Dev Ready, and closed the epic with all nine acceptance criteria unchecked until an outside
  # session caught it. Backlog ids encode parenthood (`TASK-62.3` is `TASK-62`'s child), so hold
  # back any ticket with a non-Done child. Once every child reaches Done the parent reappears,
  # which is exactly when its remaining job — the acceptance-criteria walk over shipped work —
  # is actually doable. Note the trailing dot in the pattern: without it `TASK-62.1` would look
  # like a child of `TASK-62.10`'s parent-to-be rather than a sibling.
  for child_id in "${!status_of[@]}"; do
    [ "$child_id" = "$id" ] && continue
    case "$child_id" in
      "$id".*) ;;
      *) continue ;;
    esac
    if [ "${status_of[$child_id]}" != "Done" ]; then
      blocked=true
      break
    fi
  done

  # Ownership. A ticket goes to a person iff any assignee normalises to `human` — the label
  # is written `@human`, tolerated without the sigil or in another case, and treated as
  # contagious across a multi-assignee list, matching the rule that a parent inherits the
  # strictest assignee among its children. Anything else, including no assignee at all, stays
  # agent-pickable: projects without the convention must keep working, and an unassigned
  # ticket is far more likely a filing slip than a request for a person.
  if [ "$ASSIGNEE_MODE" != all ]; then
    human_owned=false
    mapfile -t assignees < <(
      printf '%s\n' "$fm" | yq -o=json '.assignee // []' 2>/dev/null |
        jq -r 'if type == "array" then .[] else . end' 2>/dev/null || true
    )
    for a in "${assignees[@]:-}"; do
      case "$(printf '%s' "${a#@}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')" in
        human) human_owned=true ;;
      esac
    done
    if [ "$ASSIGNEE_MODE" = agent ]; then
      [ "$human_owned" = true ] && blocked=true
    else
      [ "$human_owned" = true ] || blocked=true
    fi
  fi

  if [ "$blocked" = false ]; then
    echo "$id - $title"
  fi
done
