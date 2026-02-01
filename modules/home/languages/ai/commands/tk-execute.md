---
description: Execute one ready ticket
---

1. Find an outstanding task that hasn't been assigned (`tk ready -T planned`):
2. Choose a task
3. View the issue and implement the plan
4. Once the implementation is complete:
   - Mark it complete (`tk close <id>`)
   - Commit the changes


If there are no ready tickets that are also planned, but there are unplanned tickets, warn the user that tickets need planning and quit.
