---
description: Execute all ready beads (bd) tickets
---

Complete all ready beads (bd) tickets:

1. Find all outstanding tasks that have been planned (`bd ready -l planned -u`):
2. Complete these tasks one at a time (serially)
3. For each task:
  - Launch a sub-agent to do the work (to limit context)
  - In the agent, view the issue and implement the plan.
  - Once the implementation is complete:
    - Mark it complete in beads
    - Commit the changes
4. Finally, move on to the next task.
