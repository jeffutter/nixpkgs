---
name: pr-preflight
description: Review a change the way Copilot's PR reviewer and Jeff would, before the PR is opened or after it is updated. Checks the diff, tests, docs, diagrams and PR body for the defects Copilot catches on Jeff's PRs (validator vs runtime drift, round-trip and normalization, generated client code, stale docs, absolutes the code does not keep, security sinks, destructive tooling, off-by-one, null vs missing, test isolation) and the things Jeff asks to change (prior art before bespoke code, things that no longer earn their place, goal metrics, request values in ids, duplicate mechanisms, speculative code, scope creep, stale PR bodies, Mermaid where images belong). Use when asked to "preflight", "review before I open the PR", "what would copilot say", "review this like you were me", or before `gh pr create` in a spawn-work session.
argument-hint: "[base-branch | PR number | --fix] [extra focus]"
---

Review the change, verify every candidate finding against source, and report only what survives. End state: a ranked list of findings with `file:line`, a failure scenario and a fix for each, plus a PR-body check. Fix nothing unless the invocation says `--fix`.

## Fixed values

- Checklists: `references/code-checks.md` (what Copilot catches), `references/jeff-checks.md` (what Jeff asks for), and the design rubric in the `software-design` skill (`references/review-rubric.md`).
- Repo checklist: `<repo root>/.claude/review-checklist.md`, when it exists. It names generated paths, docs that track code, limits that must agree, and repo-specific pitfalls.
- Low-value categories (report once, at the end, or skip): asks for a human to verify something live; the same stale wording re-raised in several places; count mismatches in a PR body for a large generator PR; "this also appears on line N" lists; a compatibility break inferred from a test fixture; wording in vendored third-party files; defensive code for inputs the repo never produces; grammar that vale already checks.

## Steps

0. Run in a fresh subagent. The author's session context biases the review, so the review must not inherit it.
   - If you were started by the Agent tool with this skill named in your prompt, you are the subagent. Skip this step and start at step 1. Never spawn another subagent.
   - Otherwise call the Agent tool with `subagent_type: "general-purpose"`. Never use `"fork"`: a fork inherits this conversation.
   - The prompt contains only: the invocation arguments verbatim, the repo root path, and the sentence "You are the pr-preflight subagent. Invoke the pr-preflight skill and run it to completion. Return the full report."
   - Do not add your own opinion of the change, a list of suspected defects, or a summary of the work. Those anchor the reviewer.
   - Wait for the result. Give it to the user unchanged, then add your own notes after it, labelled as yours.

1. Resolve the target.
   - No argument: the current branch against its base. Find the base with `gh pr view --json baseRefName -q .baseRefName`; if there is no PR, use the default branch from `git symbolic-ref --short refs/remotes/origin/HEAD`.
   - A branch name: that base.
   - A PR number: `gh pr view <n> --json headRefName,baseRefName,body,title`. Check out nothing; review the local branch if it is the head, otherwise `git fetch` and use `origin/<head>`.
   - Record `BASE` and `HEAD`. Run each `git` and `gh` command bare: no pipe, redirect, `cd`, variable or option before the subcommand.

2. Gather the inputs, in this order, and keep each small.
   - `git diff --no-ext-diff --stat BASE...HEAD`.
   - `git diff --no-ext-diff BASE...HEAD -- . ':!**/generated/**' ':!*.lock' ':!pnpm-lock.yaml'` for hand-written changes. Read generated or snapshot hunks only when a check below asks for them.
   - `git log --oneline BASE..HEAD`.
   - The goal: the ticket key from the branch name (`acli jira workitem view KEY --fields "summary,description" --json`), the PR body, or the plan file under `docs/plans/`. Write the goal in one sentence and name any measurable target in it (size, speed, simplicity, "no new dependencies").
   - `<repo root>/.claude/review-checklist.md`, `CLAUDE.md` and `AGENTS.md` at the repo root. Read them once.

3. Run the checklists. For each file in the diff, apply every check in `references/code-checks.md` and `references/jeff-checks.md` whose trigger matches. Apply the repo checklist's items. For structure questions (new module, new layer, new option, duplicate mechanism) read `software-design/references/review-rubric.md` and apply it. Collect candidates as: file, line, check id, what is wrong, why it matters.

4. Verify each candidate before it becomes a finding.
   - Read the source at the line and the code it talks to. Confirm the defect with a concrete input and the wrong output, or with the exact two places that disagree (quote both).
   - For a claim that something is "used", "removed", or "the only caller": run `rg` for the symbol across the repo and confirm. Exclude `src/tests/**` and fixtures when the claim is about production data.
   - For a claim that a doc, comment, PR body or diagram contradicts code: quote the sentence and the code with `file:line`.
   - For each extra location you want to list, verify it separately. Drop any you did not verify.
   - Drop a candidate you cannot confirm. Do not report "possible" issues except under "Could not verify", with the one command that would settle it.

5. Check the PR body and commit messages, when a PR or body exists.
   - For each identifier, path, number, "only", "no new", "removed" and "N commits" claim: confirm against the diff and `git log`. Flag counts, hashes and test totals that will go stale; propose the sentence without them.
   - A stacked PR states its position, its base branch and that it deploys on its own.
   - If the work produced figures (explainer HTML, SVG), the body embeds rendered PNGs. Flag a ```` ```mermaid ```` block that stands in for a rendered figure.
   - Commit subjects match the repo's format (`git log --oneline -5 BASE`).

6. Measure the goal when step 2 found a measurable target.
   - Size: `git diff --no-ext-diff --stat BASE...HEAD -- '*test*'` and the longest test body before and after.
   - Speed: run the touched test files on HEAD, then on a BASE checkout found with `git worktree list`. If no BASE checkout exists, report HEAD only and say so.
   - Dependencies: diff `package.json` (or the repo's manifest) and the lockfile summary.
   Report the numbers. A goal metric that got worse is a High finding.

7. Report. Rank by severity: High (wrong behaviour, data loss, security, compile failure, goal metric worse), Medium (drift between two places, stale doc or body, missing test for a changed branch, duplicate mechanism), Low (naming, comments, prose). For each finding write:
   - `file:line` and the check id (for example `C1`, `J4`, `R-repo`).
   - One sentence: what is wrong.
   - Failure scenario: concrete input or sequence, then the wrong result.
   - Fix: one or two sentences, with the library, standard or existing function to use when one exists.
   Then a section "PR body" (claims verified, claims to change), a section "Goal metric" (numbers, or "none stated"), a section "Could not verify" (one command each), and one line "Low-value notes" for anything from the low-value list. End with one line: findings by severity, and whether you would open the PR.

8. With `--fix`: apply the High and Medium fixes that have one clear fix, run the checks the repo's commit hook does not run (tests), re-run steps 3 to 5 on the changed files, and report under the same headings with "Fixed in `file:line`" on each applied item. Commit on a feature branch with a bare `git commit -F <file>`; do not push.
