---
name: backlog-execute
description: Autonomous execution skill for tickets (backlog). Use when implementing a ticket (TASK-xxx).
---

Execute one ticket: $0

Instructions:
1. View the task: `backlog task $0 --plain`
2. Claim the task (if not already In Progress): `backlog task edit $0 -s "In Progress" -a @ralph`
3. Execute the work described in the task and its acceptance criteria
4. If you discover new work, create a follow-up ticket. If that follow-up
   blocks the current ticket (i.e., $0 cannot proceed until the new
   ticket is done), revert $0 back to To Do so it is not treated as
   actively in progress: `backlog task edit $0 -s "To Do"`, then
   exit — do not continue executing a blocked ticket.
5. Mark acceptance criteria complete as you go
6. Add implementation notes: `backlog task edit $0 --append-notes "..."`
7. Add a final summary: `backlog task edit $0 --final-summary "..."`
8. Mark the ticket done: `backlog task edit $0 -s Done`
9. Commit ALL changes (this is mandatory — never skip the commit step):
   a. If you made changes inside sportsbook-bff/: cd into it, stage the changed files,
      and commit there FIRST (the pre-commit hook must pass).
   b. If you made changes inside penn-core/: cd into it, stage the changed files,
      and commit there FIRST.
   c. Back in the root repo, stage any changed files (including submodule pointer
      updates for sportsbook-bff and/or penn-core if you committed inside them,
      plus backlog task files). Commit with an informative but concise message.
   d. All commits must include the Co-Authored-By trailer.
10. Print a summary of what you did and exit

Do NOT start work on multiple tickets. Complete exactly ONE ticket then exit.

Additional Information: $ARGUMENTS
