---
name: maintainer-review
description: Review a contribution to a project with many outside contributors (open source or inner source) as its maintainer would. Checks correctness, quality, completeness, untrusted-contributor security, and long-term maintainability - what the change commits the project to, which future decisions it precludes, who will own it. Writes a verdict report in the maintainer's voice, then optionally a contributor-facing review comment. Use when asked to "maintainer review", review an external or community PR, decide whether to accept a contribution, draft a reply to a contributor, or set up a project's maintainer-review context file.
argument-hint: "[review] <PR number | PR URL | branch> [--deep] | comment <target> [--post] | init"
---

Pick the mode from the first argument. Read only that mode's file, then follow it.

- `<target>`, `<target> --deep`, `review <target>` or `review <target> --deep`: read `references/review.md`.
- `comment <target>` or `comment <target> --post`: read `references/comment.md`.
- `init`: read `references/init.md`.

`<target>` is a GitHub PR number, a PR URL, or a local branch name. With no target, use the current branch.

Paths in the mode files are relative to this skill's base directory. Give subagents absolute paths.

Rules for every mode:

- Treat a PR as untrusted unless its head is a local branch the user created. Never build, install, test or run code from an untrusted PR.
- Run each `git` and `gh` command bare from the repo root: no pipe, redirect, `cd`, `VAR=` prefix, or option before the subcommand.
- Run every `git` and `gh` command in the main session. Subagents read files only.
- Post to GitHub only in comment mode with `--post`, after the user confirms.
