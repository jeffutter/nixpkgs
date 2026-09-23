---
name: backlog-execute
description: Autonomous execution skill for tickets (backlog). Use when implementing a ticket (TASK-xxx).
---

Execute one backlog ticket, $0, from claim to a committed Done state, then exit. Work on no other ticket.

Other sessions share this checkout and edit tracked files concurrently. These rules apply to every step:
- Undo your own experiments only in files you created, such as an untracked `probe_*.rs` or a scratch file outside the repo.
- Never run `git checkout -- <path>`, `git restore`, `git stash`, or `git reset --hard`, and never delete a tracked file you did not create. These silently destroy another session's uncommitted edits.
- Never pass `--no-verify`, and never disable, move, or edit hook files. When a hook fails, read its output and fix the cause. When you cannot make it pass, stop and report the failure in your summary.
- After a context compaction, restart at step 1 and rerun its commands. Trust command output over your pre-compaction summary, including any commit hashes it quotes.

Steps:

1. Run `backlog task $0 --plain` to read the ticket.
2. Run `git rev-parse HEAD` and record the hash.
3. Run `git log --oneline -20`, `git log --grep="$0" --oneline`, and `git status --porcelain`.
4. Check the ticket status from step 1.
   - Done: stop. Report that a Done ticket reached you as a queueing bug. Claim nothing and change nothing.
   - Any other status: continue.
5. Search HEAD for the artifacts the ticket names: files, symbols, routes, columns. Also search commit messages for those names, since many commits carry the ticket ID only in a trailer.
   - Fully shipped: tick each acceptance criterion that the shipped code meets (step 9 command). Skip to step 12 and commit only the ticket file, naming the commit that shipped it.
   - Partly shipped: build only the remainder. State in the notes which part already existed.
   - Not shipped: continue.
6. If the status is not In Progress, run `backlog task edit $0 -s "In Progress" -a @ralph`.
7. Do the work the ticket and its acceptance criteria describe.
8. When you discover new work, create a follow-up ticket. When that follow-up blocks $0, park $0 and exit:
   - Check that "Blocked" appears in the `statuses` list in `backlog/config.yml`. If missing, add it by editing the file directly. `backlog config set` rejects that key.
   - Run `backlog task edit $0 -s "Blocked" --depends-on <ids>`. List every blocking ticket ID, comma-separated. `--depends-on` replaces the list, so include the existing dependencies from step 1.
   - Run `backlog task edit $0 --append-notes "..."`. State what blocks it, the evidence from the code, and the next actionable step.
   - Exit without committing further work.
9. After you verify each acceptance criterion's work, run `backlog task edit $0 --check-ac <n>` for it. A criterion counts as done only when its checkbox is checked.
10. Run `backlog task edit $0 --append-notes "..."` with implementation notes.
11. Run `backlog task edit $0 --final-summary "..."`.
12. Run `backlog task edit $0 --plan "SHIPPED by <commit sha>. This plan is superseded; the ticket's final summary describes what actually landed."`. Use the sha of the commit that delivers the work.
13. Run `backlog task $0 --plain` and confirm no `[ ]` remains. For a criterion that does not apply, explain why in the implementation notes, then check it. Resolve every unchecked criterion before step 14.
14. Commit all changes, before marking the ticket Done:
   - Changes inside `sportsbook-bff/`: cd into it, stage the changed files, and commit there first.
   - Changes inside `penn-core/`: cd into it, stage the changed files, and commit there first.
   - In the root repo, stage changed files, submodule pointer updates, and backlog task files. Commit with a concise, informative message.
   - Add both trailers to every commit in this step, even when the subject already names $0: `git commit --trailer "Co-Authored-By: Claude Code <noreply@anthropic.com>" --trailer "Task-Id: $0"`. These flags work alongside `-m` and `-F`.
15. Run `backlog task edit $0 -s Done --remove-label ready-for-agent`.
16. Stage the updated ticket file.
17. Check that HEAD is the root-repo commit you created in step 14.
   - Yes: run `git commit --amend --no-edit` with no `--trailer` flags. `--no-edit` keeps the existing trailers; re-passing the flags duplicates them.
   - No: make a new commit with both trailers from step 14.
18. Run `git log -1 --format=%B | grep -c '^Task-Id:'` and confirm it prints 1. If it prints more, write the message with one trailer block to a file and run `git commit --amend -F <file>`.
19. Run `git rev-parse HEAD` again. If it differs from step 2, re-read anything you cite in the summary.
20. Print a summary of what you did and exit.

Additional Information: $ARGUMENTS
