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
5. Mark acceptance criteria complete as you go: `backlog task edit $0 --check-ac <n>`
   for each one, right after its work is actually verified — not just described in
   notes or the final summary. The checkbox state itself is what review-pi-work and
   future runs treat as "done"; prose saying it's done is not a substitute.
6. Add implementation notes: `backlog task edit $0 --append-notes "..."`
7. Add a final summary: `backlog task edit $0 --final-summary "..."`
8. Verify every acceptance criterion is actually checked before proceeding:
   `backlog task $0 --plain` and confirm no `[ ]` remains. If one genuinely
   doesn't apply, say why in the implementation notes and check it anyway
   (`--check-ac <n>`) rather than leaving it unchecked. Never continue to the
   commit step with an unresolved, unchecked criterion — a ticket marked Done
   with unchecked ACs is exactly the kind of finding that stops review-pi-work
   from trusting the loop's own status.
9. Commit ALL changes (this is mandatory — never skip the commit step). Do this
   BEFORE marking the ticket Done — see step 11 for why:
   a. If you made changes inside sportsbook-bff/: cd into it, stage the changed files,
      and commit there FIRST (the pre-commit hook must pass).
   b. If you made changes inside penn-core/: cd into it, stage the changed files,
      and commit there FIRST.
   c. Back in the root repo, stage any changed files (including submodule pointer
      updates for sportsbook-bff and/or penn-core if you committed inside them,
      plus backlog task files). Commit with an informative but concise message.
   d. All commits must include both a `Co-Authored-By` trailer and a
      `Task-Id: <task-id>` trailer, even when the task ID already appears in the
      subject line — review-pi-work and other tooling correlate commits to
      tickets via this trailer, not by parsing the subject, since subject-line
      conventions aren't followed consistently across a project's history.
10. Mark the ticket done: `backlog task edit $0 -s Done`
11. Fold that status change into the commit from step 9 instead of leaving it
    separate: stage the updated ticket file and `git commit --amend --no-edit`.
    Committing the code first and folding the Done flip in afterward means an
    interruption between steps 9-11 (e.g. this process being killed) never
    leaves a ticket marked Done with its work uncommitted — worst case is a
    ticket that's already-committed but still shows its prior status, which a
    future run can safely re-check rather than silently losing finished work.
12. Print a summary of what you did and exit

Do NOT start work on multiple tickets. Complete exactly ONE ticket then exit.

Additional Information: $ARGUMENTS
