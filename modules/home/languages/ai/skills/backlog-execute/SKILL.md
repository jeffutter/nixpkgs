---
name: backlog-execute
description: Autonomous execution skill for tickets (backlog). Use when implementing a ticket (TASK-xxx).
---

Execute one ticket: $0

Instructions:
1. View the task: `backlog task $0 --plain`

   Before anything else, get your bearings from git rather than from this prompt or from ticket
   text. Record `git rev-parse HEAD`; run `git log --oneline -20`, `git log --grep="$0" --oneline`
   and `git status --porcelain`. Main moves underneath every session in this checkout, so re-run
   `git rev-parse HEAD` before you report results and re-read anything you meant to cite if it moved.

   If the ticket's status is already `Done`, stop and say so  - do not claim it, do not "finish off"
   any remaining criterion. A Done ticket that reached you is a queueing bug worth reporting, not
   work worth repeating.

   Then check whether the deliverable already exists before building it. Search for the artifacts
   the ticket names  - files, symbols, routes, columns  - not only the ticket ID, because much work
   landed under a descriptive subject line with the ID solely in a trailer. If it is already in
   HEAD, do NOT re-implement it or write a competing version into the same files: verify each
   acceptance criterion against what shipped, tick the ones it meets, and commit the ticket file
   alone at step 9 naming the commit that shipped it. If part of it shipped, build exactly the
   remainder and say which part was already there.

   After a context compaction, redo all of step 1 from the commands, not from your summary. A
   summary carries forward what you intended and goes quiet about what you finished, which is how
   five sessions on 2026-09-16 re-implemented tickets that had already merged  - two of them quoted
   commit hashes that existed in no repository, lifted from their own pre-compaction notes.
2. Claim the task (if not already In Progress): `backlog task edit $0 -s "In Progress" -a @ralph`

   Other agents share this exact checkout, so tracked files are not yours to tidy up. Never run
   `git checkout -- <path>`, `git restore`, `git stash`, or `git reset --hard` on a tracked file to
   undo an experiment, and never delete a tracked file you did not create: those commands discard
   another session's uncommitted edits silently and unrecoverably. Run throwaway probes in files you
   created  - an untracked `probe_*.rs`, a scratch file outside the repo  - and clean up by deleting
   your own.
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
5. Mark acceptance criteria complete as you go: `backlog task edit $0 --check-ac <n>`
   for each one, right after its work is actually verified — not just described in
   notes or the final summary. The checkbox state itself is what review-pi-work and
   future runs treat as "done"; prose saying it's done is not a substitute.
6. Add implementation notes: `backlog task edit $0 --append-notes "..."`
7. Add a final summary: `backlog task edit $0 --final-summary "..."`

   Then replace the plan with a record that it shipped:
   `backlog task edit $0 --plan "SHIPPED by <commit sha>. This plan is superseded; the ticket's
   final summary describes what actually landed."`

   Do not leave the plan text describing unfinished work. A plan never states which revision it was
   written against, so once the code merges it still reads as a queue entry, and a fresh session
   that trusts it starts building merged work again - five sessions did exactly that to
   TASK-2.15.3 on 2026-09-16. Nothing is lost by replacing it: the original text stays in the
   ticket file's git history.
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
   d. Every commit must carry both a `Co-Authored-By` trailer and a
      `Task-Id: <task-id>` trailer, even when the task ID already appears in the
      subject line — review-pi-work and other tooling correlate commits to
      tickets via this trailer, not by parsing the subject, since subject-line
      conventions aren't followed consistently across a project's history. Pass
      them as trailer flags rather than relying on the hook to add them, so the
      message is already correct when the hook checks it:

      ```
      git commit --trailer "Co-Authored-By: Claude Code <noreply@anthropic.com>" \
        --trailer "Task-Id: $0"
      ```

      This works alongside `-m` and `-F`. It is NOT idempotent: `git commit --trailer`
      appends without checking whether the message already carries that trailer, so the
      flags belong on the original commit only — never on an amend of a commit that already
      has them (see step 11).
10. Mark the ticket done: `backlog task edit $0 -s Done --remove-label ready-for-agent`

    Drop the pickup labels in the same command as the status flip. A ticket left carrying
    `ready-for-agent` while sitting in Done is bait for a fresh session: statuses filter the queues,
    but labels are what agent-written plans and ad-hoc listings key off, and today one such stale
    label helped send four sessions at TASK-2.15.3 long after `ecffcf1` had merged it.
11. Fold that status change into the commit from step 9 instead of leaving it
    separate: stage the updated ticket file and amend. Use `--amend --no-edit` with **no
    `--trailer` flags** — `--no-edit` keeps the existing message, trailers included, so the
    trailers are already carried through:

    ```
    git commit --amend --no-edit
    ```

    Re-passing the trailer flags here duplicates them. Verified against git 2.55 in a scratch
    repo: amending a commit whose message ends with one `Co-Authored-By`/`Task-Id` pair while
    passing both flags again produces two pairs, and every later amend keeps the damage — this
    is exactly how four consecutive TASK-62 commits each ended up with `Task-Id:` twice.

    Check it after the amend, since nothing else will catch it:

    ```
    git log -1 --format=%B | grep -c '^Task-Id:'   # must print 1
    ```

    If it prints more than 1, repair the message once by rewriting it (`git commit --amend -F
    <file>` with a single trailer block) rather than amending again with flags.

    Committing the code first and folding the Done flip in afterward means an
    interruption between steps 9-11 (e.g. this process being killed) never
    leaves a ticket marked Done with its work uncommitted — worst case is a
    ticket that's already-committed but still shows its prior status, which a
    future run can safely re-check rather than silently losing finished work.

    Only ever amend a commit you created yourself during this run. If HEAD is a
    commit you did not just make, do not amend it — make a new commit instead.
12. **Never bypass a git hook.** Do not pass `--no-verify` to `git commit`,
    `git push`, or anything else, and do not disable, move, or rewrite hook
    files. If a hook fails — including on the amend in step 11 — that failure
    is a real finding: read what it reported and fix the underlying problem.
    The attribution hook is mandatory policy, and the pre-commit hooks are the
    formatting, lint, and test gates this repo relies on; a commit that skipped
    them looks reviewed when it is not. If you genuinely cannot get a hook to
    pass, stop and report that in your summary rather than working around it.
13. Print a summary of what you did and exit

Do NOT start work on multiple tickets. Complete exactly ONE ticket then exit.

Additional Information: $ARGUMENTS
