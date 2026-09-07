#!/usr/bin/env bash
# List tasks in a given status (default "To Do") whose dependencies (if any) are all Done.
# Usage: unblocked-todo.sh [status]
# e.g. `unblocked-todo.sh Blocked` finds tasks parked in "Blocked" status whose dependencies
# have since completed — status doesn't update itself when a blocker ships.
#
# Container tickets are held back: a ticket with an unfinished child is never listed, because
# there is nothing left to execute on it — its children own the remaining work. See the check
# below for why this matters and how a parent becomes eligible again.
#
# Deployed globally (see ai.nix) alongside the ralph pi extension, so unlike the original
# gql-fiddle copy this can't locate the backlog directory via its own path ($0) — it's invoked
# with cwd set to the target project's root instead, and cds into that project's backlog/.
set -euo pipefail
cd backlog

TARGET_STATUS="${1:-To Do}"

frontmatter() {
  awk '/^---$/{c++; next} c==1' "$1"
}

declare -A status_of
for f in tasks/*.md completed/*.md archive/tasks/*.md; do
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

  if [ "$blocked" = false ]; then
    echo "$id - $title"
  fi
done
