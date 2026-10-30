---
name: rebase
description: Rebase the current branch onto main with no argument, or onto the named branch with one argument, then force-push when the rebase was clean. Use when asked to "rebase", "rebase on main", "rebase on develop", "bring my branch up to date with main", or before pushing a branch that is behind its base.
argument-hint: "[branch]"
---

Rebase the current branch on top of the target branch. End state: the branch sits on top of the target and the remote matches it, or the rebase stopped short and you reported why without pushing.

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
4. Judge the result.
   - Clean, or conflicts that were purely mechanical (whitespace, import order, a moved line, two sides that both added independent code): continue to step 5.
   - Anything else — a conflict inside logic you had to reason about, a resolution where you guessed intent, commits git dropped or reordered, a rebase that needed more than one stop — stop at the conflict, leave the rebase in progress for me to resolve, and do not push. Summarize: which commit, which files, what each side does, what you tried, and the undo anchor from step 2.
5. Push.
   - `git push --force-with-lease`. If the branch has no upstream, push with `-u origin <current-branch>`; if neither works, say so instead of retrying.
   - Report: `<old sha> -> <new sha>`, how many commits were rebased, how many the target gained, and any conflict you resolved yourself with the reason it was safe.
