---
name: maintainer-review
description: Review a contribution to a project with many outside contributors (open source or inner source) as its maintainer would. Checks correctness, quality, completeness, untrusted-contributor security, and long-term maintainability - what the change commits the project to, which future decisions it precludes, who will own it. Writes a verdict report in the maintainer's voice, then optionally a contributor-facing review comment. Use when asked to "maintainer review", review an external or community PR, decide whether to accept a contribution, draft a reply to a contributor, or set up a project's maintainer-review context file.
argument-hint: "[review] <PR number | PR URL | branch> [--base <ref>] [--deep] | comment <target> [F1 F4 Q2 ...] [--post] | init"
---

Pick the mode from the first argument. Read only that mode's file, then follow it.

- `[review] <target> [--base <ref>] [--deep]`: read `references/review.md`.
- `comment <target> [F1 F4 Q2 ...] [--post]`: read `references/comment.md`.
- `init`: read `references/init.md`.

`<target>` is a GitHub PR number, a PR URL, or a local branch name. With no target, use the current branch.

Paths in the mode files are relative to this skill's base directory. Give subagents absolute paths.

Locations for every mode. The session may run in a linked worktree, where `.git` is a file, so resolve each one with git:

- `GITDIR`: the output of `git rev-parse --path-format=absolute --git-common-dir`. It is the main repository's `.git` directory, even from a worktree.
- `WORK`: `GITDIR/maintainer-review/<slug>`. The slug is `pr-<number>` for a PR (take the number from the URL when the target is a URL), or `branch-<name>` with each `/` replaced by `-`. Never build this path from `./.git`.
- `MAIN`: the main worktree root, from the first `worktree` line of `git worktree list --porcelain`.
- `DEFAULT`: the default branch, from `git symbolic-ref --short refs/remotes/origin/HEAD` (for example `origin/main`). If that fails, use `origin/<defaultBranchRef.name>` from `gh repo view --json defaultBranchRef`.
- Context file, to read: the output of `git show DEFAULT:.github/maintainer-review.md`. Read it from the default branch, never from the PR or the current worktree. When the command fails, the project has no context file.
- Context file, to write: `MAIN/.github/maintainer-review.md`.

Rules for every mode:

- Treat a PR as untrusted unless its head is a local branch the user created. Never build, install, test or run code from an untrusted PR.
- Run each `git` and `gh` command bare from the repo root: no pipe, redirect, `cd`, `VAR=` prefix, or option before the subcommand.
- Run every `git` and `gh` command in the main session. Subagents read files only.
- Post to GitHub only in comment mode with `--post`, after the user confirms.
