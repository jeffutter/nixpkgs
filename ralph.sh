# ralph.sh
# Autonomous work loop: plan tickets or execute work until complete

set -e

echo "Starting autonomous work loop..."

while true; do
  echo ""
  echo "========================================"
  echo "Checking for work..."
  echo "========================================"

  # Check for tickets needing planning
  tickets_needing_plan=$(tk list --status=open -T needs-plan 2>/dev/null || echo "")

  if [ -n "$tickets_needing_plan" ]; then
    echo "Found tickets needing planning:"
    echo "$tickets_needing_plan"
    echo ""

    result=$(claude --model opus --plugin-dir ~/src/claude-plugin -p "$(cat <<'EOF'
Plan one ticket that needs planning.

Tickets needing planning:
EOF
echo "$tickets_needing_plan"
cat <<'EOF'

Instructions:
1. Choose ONE ticket from the list above to plan
2. View the task: \`tk show <task_id>\`
3. View any tasks that the ticket depends on - these should already be planned
4. Understand this task's place relative to the other tickets
5. Use the /tk-planner skill to plan the ticket
6. Remove the 'needs-plan' tag from the ticket frontmatter
7. Ensure the 'planned' tag is added to the frontmatter. Note: tags must be on a single line ex: `tags: [foo, bar, baz]`
8. Commit your changes - Use an informative but concise commit message
9. Print a summary of what you did and exit

Do NOT start work on multiple tickets. Plan exactly ONE ticket then exit.
EOF
)")

    echo "========================================"
    echo "Planning result:"
    echo "$result"
    echo "========================================"
    continue
  fi

  # No planning needed, check for tickets ready to work
  echo "No tickets needing planning. Checking for ready work..."

  # Check for in-progress tickets first
  in_progress=$(tk list --status=in_progress 2>/dev/null || echo "")
  ready_tickets=$(tk ready 2>/dev/null || echo "")

  if [ -z "$in_progress" ] && [ -z "$ready_tickets" ]; then
    echo "========================================"
    echo "No work remaining. All tickets complete!"
    echo "========================================"
    exit 0
  fi

  echo "Found work to execute:"
  if [ -n "$in_progress" ]; then
    echo "In-progress tickets:"
    echo "$in_progress"
  fi
  if [ -n "$ready_tickets" ]; then
    echo "Ready tickets:"
    echo "$ready_tickets"
  fi
  echo ""

  result=$(claude --plugin-dir ~/src/claude-plugin -p "$(cat <<'EOF'
Execute one ticket to completion.

In-progress tickets:
EOF
echo "$in_progress"
cat <<'EOF'

Ready tickets:
EOF
echo "$ready_tickets"
cat <<'EOF'

Instructions:
1. If there are in-progress tickets, continue with one of those
2. Otherwise, choose ONE ready ticket (prioritize based on your judgment)
3. Claim the task if not already claimed: \`tk start <task_id>\`
4. View the task: \`tk show <task_id>\`
5. Execute the work described in the task
6. If you discover new distinct work while working on this ticket or any work that could be split off, create a new ticket (\`tk create\`) and add any dependencies \`tk dep <id> <dep-id>\`
7. Spawn one or more subagents to review the documents you just updated for clarity and correctness
8. Incorporate any feedback from the subagents
9. If you did anything differently than as requested in the ticket, add a note to the ticket: \`tk add-note <task_id> "note text"\`
10. Mark the ticket complete: \`tk close <task_id>\`
11. Commit your changes - Use an informative but concise commit message
12. Print a summary of what you did and exit

Do NOT start work on multiple tickets. Complete exactly ONE ticket then exit.
EOF
)")

  echo "========================================"
  echo "Execution result:"
  echo "$result"
  echo "========================================"
done
