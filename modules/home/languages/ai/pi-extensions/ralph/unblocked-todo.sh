#!/usr/bin/env bash
# List tasks in a given status (default "To Do") whose dependencies (if any) are all Done.
# Usage: unblocked-todo.sh [status]
# e.g. `unblocked-todo.sh Blocked` finds tasks parked in "Blocked" status whose dependencies
# have since completed — status doesn't update itself when a blocker ships.
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

  if [ "$blocked" = false ]; then
    echo "$id - $title"
  fi
done
