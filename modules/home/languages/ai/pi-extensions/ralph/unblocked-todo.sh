#!/usr/bin/env bash
# List tasks in a given status (default "To Do") whose dependencies (if any) are all Done,
# split by who is allowed to do the work.
#
# Usage: unblocked-todo.sh [status] [--assignee agent|human|all] [--explain]
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
# --explain prints one "id|reason" line per task whose .status matches, ineligible ones included,
# so a caller that has to say why a ticket was refused gets verdict and reason for the whole pool
# in one call. Reasons come from the same three rules that set the verdict, computed in this file
# alongside it, so the two cannot disagree; reconstructing them in a caller would be a second copy
# of those rules, which is how this script's two copies drifted apart once already.
#
# The vocabulary is closed at four values, reported in this precedence:
#   dependencies-unresolved  some dependency does not resolve to Done
#   container-children-open  some descendant is not Done
#   assignee-human           some assignee normalises to human
#   eligible                 none of the three applies, so an agent may pick it up
# A reason names the condition and never the offending id, so TASK-038.06 reports
# `dependencies-unresolved` rather than naming the dependency holding it back: low cardinality is
# what lets a caller switch on the value, and the ticket's own frontmatter says which dependency.
# Reasons are identical in all three --assignee modes and --explain does not filter by mode, so
# they describe the board rather than what one mode happens to print: agent mode reads
# `assignee-human` as "not mine to pick up", human mode reads the same fact as "waiting on a
# person". Explain output is also a different line format from the listing (`id|reason` versus
# `ID - Title`), so callers must not feed one to the other's parser.
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
EXPLAIN=false
# Explain lines counted: how many tasks matched TARGET_STATUS at all, eligible or not.
explained=0
while [ $# -gt 0 ]; do
  case "$1" in
    --explain)
      EXPLAIN=true
      shift
      ;;
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
declare -A status_of seen_statuses
for f in archive/tasks/*.md completed/*.md tasks/*.md; do
  [ -f "$f" ] || continue
  fm=$(frontmatter "$f")
  id=$(printf '%s\n' "$fm" | yq -r '.id')
  st=$(printf '%s\n' "$fm" | yq -r '.status')
  status_of["$id"]="$st"
  seen_statuses["$st"]=1
done

for f in tasks/*.md; do
  [ -f "$f" ] || continue
  fm=$(frontmatter "$f")
  st=$(printf '%s\n' "$fm" | yq -r '.status')
  [ "$st" = "$TARGET_STATUS" ] || continue
  explained=$((explained + 1))

  id=$(printf '%s\n' "$fm" | yq -r '.id')
  title=$(printf '%s\n' "$fm" | yq -r '.title')
  mapfile -t deps < <(printf '%s\n' "$fm" | yq -o=json '.dependencies // []' | jq -r '.[]')

  blocked=false
  # Which condition holds this ticket, in the order the rules run: dependencies, then the container
  # check, then ownership. Rules 2 and 3 still execute after rule 1 has set `blocked`, so each one
  # writes the reason only while it is still `eligible`; that guard is what keeps the documented
  # precedence dependencies > container > assignee.
  reason=eligible
  for d in "${deps[@]:-}"; do
    [ -z "$d" ] && continue
    if [ "${status_of[$d]:-MISSING}" != "Done" ]; then
      blocked=true
      [ "$reason" = eligible ] && reason=dependencies-unresolved
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
      [ "$reason" = eligible ] && reason=container-children-open
      break
    fi
  done

  # Ownership. A ticket goes to a person iff any assignee normalises to `human` — the label
  # is written `@human`, tolerated without the sigil or in another case, and treated as
  # contagious across a multi-assignee list, matching the rule that a parent inherits the
  # strictest assignee among its children. Anything else, including no assignee at all, stays
  # agent-pickable: projects without the convention must keep working, and an unassigned
  # ticket is far more likely a filing slip than a request for a person.
  # In `all` mode the verdict needs no ownership at all, but an explanation does: without the
  # second condition `--assignee all --explain` would print `eligible` for a @human ticket.
  if [ "$ASSIGNEE_MODE" != all ] || [ "$EXPLAIN" = true ]; then
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
    [ "$human_owned" = true ] && [ "$reason" = eligible ] && reason=assignee-human
    if [ "$ASSIGNEE_MODE" = agent ]; then
      [ "$human_owned" = true ] && blocked=true
    else
      [ "$human_owned" = true ] || blocked=true
    fi
  fi

  if [ "$EXPLAIN" = true ]; then
    echo "$id|$reason"
  elif [ "$blocked" = false ]; then
    echo "$id - $title"
  fi
done

# A status nobody typed correctly looks exactly like a status that has nothing in it. stdout stays
# empty and the exit stays 0, because the line-per-matching-task contract holds either way; the
# difference goes to stderr, where it cannot reach the parsers of either caller. Only explain mode
# says anything: the ralph JS workflow reads this script's stderr interleaved with stdout.
if [ "$EXPLAIN" = true ] && [ "$explained" -eq 0 ]; then
  printf 'unblocked-todo.sh: no task on this board has status "%s" (statuses present: %s)\n' \
    "$TARGET_STATUS" "$(printf '%s\n' "${!seen_statuses[@]}" | sort | paste -sd ',' -)" >&2
fi
