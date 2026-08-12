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
   ticket is done), park $0 durably and exit — do not continue executing a
   blocked ticket. Parking means all of the following, in one command where
   possible:

   ```
   backlog task edit $0 -s "Blocked" \
     --depends-on <every-blocking-ticket-id,comma-separated>
   ```

   - `-s "Blocked"` so it is neither treated as actively in progress nor
     mixed back into the To Do queue as though it were startable. If
     "Blocked" is not among the configured statuses, add it to the
     `statuses` list in `backlog/config.yml` first (`backlog config set`
     does not accept that key, so a direct file edit is the only way).
   - `--depends-on` recording every ticket that blocks it. This is the part
     that matters most: dependencies are what `backlog task list --ready`
     filters on, and `--ready` works independently of a task's own status.
     So `backlog task list -s "Blocked" --ready` is exactly the set of
     parked tickets that can now resume — which only works if the blockers
     were written down. A park with no recorded dependencies leaves the
     ticket stranded in Blocked with nothing to release it. Note
     `--depends-on` REPLACES the dependency list, so include the existing
     dependencies from step 1's view alongside the new ones.

   Then record why in a comment — what blocks it, the evidence from the code
   rather than from ticket statuses, and the next actionable step:
   `backlog task edit $0 --append-notes "..."`. A future run reads that
   instead of rediscovering the block.
5. Mark acceptance criteria complete as you go
6. Add implementation notes: `backlog task edit $0 --append-notes "..."`
7. Add a final summary: `backlog task edit $0 --final-summary "..."`
8. Commit ALL changes (this is mandatory — never skip the commit step). Do this
   BEFORE marking the ticket Done — see step 10 for why:
   a. If you made changes inside sportsbook-bff/: cd into it, stage the changed files,
      and commit there FIRST (the pre-commit hook must pass).
   b. If you made changes inside penn-core/: cd into it, stage the changed files,
      and commit there FIRST.
   c. Back in the root repo, stage any changed files (including submodule pointer
      updates for sportsbook-bff and/or penn-core if you committed inside them,
      plus backlog task files). Commit with an informative but concise message.
   d. Every commit must carry the Co-Authored-By trailer. Pass it as a trailer
      flag rather than relying on the hook to add it, so the message is already
      correct when the hook checks it:

      ```
      git commit --trailer "Co-Authored-By: Claude Code <noreply@anthropic.com>"
      ```

      This works alongside `-m` and `-F`, and repeating an identical trailer is
      a no-op, so it is safe even when something else already appended one.
9. Mark the ticket done: `backlog task edit $0 -s Done`
10. Fold that status change into the commit from step 8 instead of leaving it
    separate: stage the updated ticket file and amend, carrying the trailer
    through the amend as well:

    ```
    git commit --amend --no-edit \
      --trailer "Co-Authored-By: Claude Code <noreply@anthropic.com>"
    ```

    Committing the code first and folding the Done flip in afterward means an
    interruption between steps 8-10 (e.g. this process being killed) never
    leaves a ticket marked Done with its work uncommitted — worst case is a
    ticket that's already-committed but still shows its prior status, which a
    future run can safely re-check rather than silently losing finished work.

    Only ever amend a commit you created yourself during this run. If HEAD is a
    commit you did not just make, do not amend it — make a new commit instead.
11. **Never bypass a git hook.** Do not pass `--no-verify` to `git commit`,
    `git push`, or anything else, and do not disable, move, or rewrite hook
    files. If a hook fails — including on the amend in step 10 — that failure
    is a real finding: read what it reported and fix the underlying problem.
    The attribution hook is mandatory policy, and the pre-commit hooks are the
    formatting, lint, and test gates this repo relies on; a commit that skipped
    them looks reviewed when it is not. If you genuinely cannot get a hook to
    pass, stop and report that in your summary rather than working around it.
12. Print a summary of what you did and exit

Do NOT start work on multiple tickets. Complete exactly ONE ticket then exit.

Additional Information: $ARGUMENTS
