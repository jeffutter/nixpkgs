---
description: Execute one ready beads (bd) tickets
---

1. Find an outstanding tasks that hasn't been assigned (`bd ready -l planned -u`):
2. Choose a task
3. View the issue and implement the plan
4. Once the implementation is complete:
   - Mark it complete in beads
   - Unassign yourself
   - Commit the changes


If there are no ready tickets that are also planned, but there are unplanned tickets, warn the user that tickets need planning and quit.
