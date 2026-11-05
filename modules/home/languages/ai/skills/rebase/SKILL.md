---
name: rebase
description: Rebase the current branch onto main with no argument, or onto the named branch with one argument, resolve conflicts from the diffs, then force-push. Use when asked to "rebase", "rebase on main", "rebase on develop", "bring my branch up to date with main", or before pushing a branch that is behind its base.
argument-hint: "[branch]"
---

Rebase the current branch on top of the target branch. End state: the branch sits on top of the target and the remote matches it, or the rebase stopped at a question only I can answer and you reported it without pushing.

Invoking this skill is the authorization to force-push. Do not ask again. Use `--force-with-lease`, never bare `--force`: it refuses the push if the remote moved since the fetch, which is the one case where force-pushing loses someone's commit.

1. Resolve the target branch.
   - No argument: `main`.
   - One argument: that branch name.
   - More than one argument: stop and ask which one.
2. Check the starting point before touching anything.
   - `git status --short`: if the working tree is dirty, stop and report the paths. Do not stash.
   - `git rev-parse --abbrev-ref HEAD`: if the current branch is the target, or is detached/`HEAD`, stop and report.
   - Record the sha from `git rev-parse HEAD`. It is the undo anchor; quote it in every report.
3. Fetch and rebase.
   - `git fetch origin <target>` so the rebase lands on the real tip, not a stale local copy of the branch.
   - `git rebase origin/<target>`.
4. Resolve every conflict yourself. Resolving is the default; handing a conflict back to me is the exception. Repeat for each stop until the rebase finishes.
   - Learn what each side meant before you edit. For the commit being replayed, run `git show REBASE_HEAD`. For the target side, run `git log -p --merge -- <file>` or `git log -p <base>..origin/<target> -- <file>`, where `<base>` is `git merge-base <undo anchor> origin/<target>`. Read the commit messages too.
   - Write the result that keeps the intent of both sides. Typical cases:
     - The target renamed, moved, or changed the signature of something my commit uses: apply my change to the new shape.
     - The target refactored code that my commit also edited: apply my edit to the refactored code.
     - Both sides added code at the same place: keep both, in an order that compiles and reads well.
     - The target already contains my change, in the same or an equivalent form: take the target's version. If the commit becomes empty, run `git rebase --skip` and record that.
     - The target deleted code that my commit edited: if the target replaced it elsewhere, move my edit there. If my edit has no remaining home, drop it and record that.
     - Lockfiles and generated files: take the target's version, then regenerate with the repo's own tool.
   - After each resolution, search the files for leftover `<<<<<<<`, `=======` and `>>>>>>>` markers. Then run the repo's fast checks for the touched files (format, compile or typecheck, the nearest unit tests) when they finish in a few minutes. If a check fails because of your resolution, fix it and run it again.
   - `git add` the files, then `git rebase --continue`.
   - Stop and hand the conflict to me only when a correct resolution needs a decision that neither diff, the commit messages, nor the surrounding code can answer. Examples: the two sides change the same behaviour to different values and nothing says which wins; the target removed a feature that my commit extends; a fix needs a product or API choice. Do not stop because a conflict is large, touches logic, or spans many commits.
   - When you stop: leave the rebase in progress and do not push. Report the commit, the files, what each side does, the exact question you cannot answer, the resolutions you already made at earlier stops, and the undo anchor from step 2.
   - If a fast check fails and you cannot fix it, stop the same way and include the check output.
5. Push.
   - `git push --force-with-lease`. If the branch has no upstream, push with `-u origin <current-branch>`; if neither works, say so instead of retrying.
   - Report: `<old sha> -> <new sha>`, how many commits were rebased, how many the target gained, and the checks you ran with their result.
   - List every conflict you resolved: the commit, the file, the resolution in one line, and the evidence that it keeps both intents. List every commit you skipped or edit you dropped, with the reason.
