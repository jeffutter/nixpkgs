---
description: Plan all unplanned beads (bd) tickets
---

For every bd task that doesn't have the `planned` label (`bd list --json | jq -r '. | map(select(.status == "open" and ((.labels // []) | any(contains("planned")) | not))) | .[].id'`):
- Launch a foreground bd-planner subagent, passing one ticket id as an argument to the agent
