# Review mode

End state: `WORK/report.md` holds a verdict and verified findings in the maintainer's voice. The user has read a briefing in chat that explains the change and each finding well enough to triage it without opening the report. Nothing is posted.

Fixed values:

- `SKILL`: the absolute path of this skill's base directory.
- `GITDIR`, `WORK`, `MAIN`, `DEFAULT` and the context file paths: as defined in `SKILL.md` under "Locations". Resolve them in step 1.1.
- `PARENT`: the branch this change is compared against, and the reason it was chosen, from step 1.2 or 1.4. In a stack it is the branch below this one, not `DEFAULT`.
- `BASE` and `HEAD`: the commits from step 1.2 or 1.4. `BASE` is the merge-base of `PARENT` and `HEAD`, so the review covers only this branch's own commits.
- In every command and prompt below, replace `SKILL`, `WORK`, `MAIN`, `DEFAULT`, `PARENT`, `BASE`, `HEAD` and `<...>` with their values.
- Agent calls: use `subagent_type: "general-purpose"`. If a call rejects its `model` value, repeat the call without `model`.
- Agents write no files. Each agent's final message is a file's content. Save it with the Write tool at the path the step names.

## 1. Resolve the target

1. Resolve `GITDIR`, `WORK`, `MAIN` and `DEFAULT` as `SKILL.md` "Locations" says.
2. For a PR, run these commands:
   - `gh pr view <n> --json number,title,body,author,url,baseRefName,headRefName,headRefOid,isCrossRepository,closingIssuesReferences,comments,reviews`
   - `gh pr checks <n>`. Keep the output even when the exit code is not zero. A non-zero exit means some checks failed or are pending.
   - `gh issue view <k> --json title,body` for each closing issue.
   - `gh repo view --json nameWithOwner` and `git remote -v`. The base remote is the remote whose URL contains that `nameWithOwner`.
   - `git fetch <base remote> <baseRefName> +pull/<n>/head:refs/maintainer-review/pr-<n>`. This fetch checks out nothing.
   - Set `HEAD` to `refs/maintainer-review/pr-<n>`.
   - Set `PARENT` to `<base remote>/<baseRefName>`, reason "PR base branch". With `--base <ref>`, set `PARENT` to `<ref>`, reason "--base".
   - Set `BASE` to the output of `git merge-base PARENT HEAD`.
3. For a PR, find the related PRs in its stack. Stop at 10 PRs.
   - Later PRs: run `gh pr list --state all --base <headRefName> --json number,title,state,headRefName,baseRefName,body`. Repeat with each result's `headRefName`.
   - Earlier PRs: when `baseRefName` is not the default branch, run `gh pr list --state all --head <baseRefName> --json number,title,state,headRefName,baseRefName,body`. Repeat with each result's `baseRefName`.
4. For a branch, or for no target (use the current branch from `git branch --show-current`):
   - Set `HEAD` to the branch.
   - Set `PARENT` with the first case that applies:
     - With `--base <ref>`: `<ref>`, reason "--base".
     - Run `gh pr list --head <branch> --state open --json number,baseRefName`. With one result: run `git fetch origin <baseRefName>`, then use `origin/<baseRefName>`, reason "base of open PR #<number>". Also run step 1.3 for that PR.
     - Run `git log --first-parent --simplify-by-decoration --format='%h%x09%D' DEFAULT..<branch>`. The first line is the branch's own tip; skip it. Take the next line that names a branch other than `<branch>` and `origin/<branch>`. Ignore `tag:` entries. When a line names a local branch and a remote branch, use the local one. Use that branch, reason "nearest ancestor branch".
     - Otherwise: `DEFAULT`, reason "no parent branch found".
   - Set `BASE` to the output of `git merge-base PARENT HEAD`.
5. If `WORK/report.md` exists, this run is a re-review. Apply section 10 together with sections 2 to 9.

## 2. Write the inputs into WORK

1. Run these commands:
   - `git diff --no-ext-diff --stat --output=WORK/stat.txt BASE HEAD`
   - `git diff --no-ext-diff --name-status --output=WORK/files.txt BASE HEAD`
   - `git diff --no-ext-diff --output=WORK/diff.patch BASE HEAD`
   - `git archive --format=tar --output=WORK/head.tar HEAD`
2. Run `git log --format='%h %an %s' BASE..HEAD`. Write its output to `WORK/log.txt`.
3. Run `rm -rf WORK/src`, then `mkdir -p WORK/src`, then `tar -xf WORK/head.tar -C WORK/src`, then `rm WORK/head.tar`.
4. Write `WORK/meta.md`: target, URL, author, `PARENT` and its reason, `BASE` and `HEAD` hashes, whether the PR is cross-repository, and today's date.
5. Run `git show DEFAULT:.github/maintainer-review.md`. When it succeeds, write its output to `WORK/context-file.md`. When it fails, write the single line `No context file on DEFAULT.` to `WORK/context-file.md`.
6. For a PR, write `WORK/pr.md` with these sections:
   - Title, body, and linked issue titles and bodies.
   - Each comment and review, with its author.
   - The `gh pr checks` output.
   - "Related PRs": for each PR from step 1.3, its number, title, state, base and head branches, and the first 60 lines of its body. Mark this PR's position in the stack.

## 3. Run the context agent

1. Call one Agent with `model: "haiku"` and this prompt:
   ```
   You are the context agent for maintainer-review. Read SKILL/references/agents/context.md and follow it. WORK=WORK.
   ```
2. Save its final message as `WORK/context.md`.

## 4. Run the reviewer agents

1. Call these five Agents in one message, so they run in parallel. The model in brackets applies with `--deep`.
   - `SEC`, brief `agents/security.md`, model `sonnet`.
   - `COR`, brief `agents/correctness.md`, model `opus` (`fable`).
   - `QUA`, brief `agents/quality.md`, model `sonnet`.
   - `MNT`, brief `agents/maintainability.md`, model `opus` (`fable`).
   - `FIT`, brief `agents/fit-cost.md`, model `sonnet`.
2. Give each Agent this prompt and nothing else. Your own view of the change would anchor the reviewer.
   ```
   You are the <ID> reviewer for maintainer-review. Read SKILL/references/<brief> and SKILL/references/agents/findings-format.md, then follow them. WORK=WORK. SKILL=SKILL.
   ```
3. Save each final message as `WORK/findings-<ID>.md` as it arrives.
4. For a local branch, run tests when all three conditions hold:
   - `WORK/findings-SEC.md` contains `Gate: PASS`.
   - `WORK/pr.md` does not exist, or has no CI results.
   - The repo's README, CONTRIBUTING or CLAUDE.md names a test command.
   Run that command for the touched areas in the worktree that has the branch checked out (`git worktree list --porcelain`). If no worktree has it, skip the tests and say so. Write the command and its result to `WORK/tests.md`.

## 5. Merge and verify the findings

1. Merge findings from different reviewers that describe the same defect. Keep every reviewer ID in the merged finding.
2. Number the merged findings `F1`, `F2`, ... in tier order: must, then should, then optional.
3. Group the must findings. With 10 or fewer, make one group per finding. With more than 10, make one group per file.
4. Call one Agent per group with `model: "sonnet"`, all in one message, with this prompt:
   ```
   You are a verifier for maintainer-review. Read SKILL/references/agents/verifier.md and follow it. WORK=WORK. Findings to verify:
   <the finding blocks, copied verbatim>
   ```
5. Apply each result:
   - CONFIRMED: keep the finding. Mark it verified.
   - REFUTED: remove the finding. List it under "Dropped" in the report, with the verifier's reason.
   - UNCERTAIN: change the finding to should, with low confidence.

## 6. Add figures

1. Pick the findings whose point is structural: a dependency direction changes, a public surface is added, or a data flow moves. Most reviews have none. With none, go to section 7.
2. Check your list of available skills for a diagram skill, for example `diagram-design` or `excalidraw-diagram`. With none, go to section 7. The report text must stand alone without figures.
3. For each picked finding, call one Agent with `model: "sonnet"`. Give it the diagram skill name, the finding block, and the output path `WORK/fig-<n>.png`. Tell it to render a PNG with that skill and to return only the path.

## 7. Write the report

1. Read `SKILL/references/report-template.md`.
2. Choose the verdict:
   - Decline: the change conflicts with a non-goal or the direction, or it costs the project more than it gives, and no change to the PR fixes that.
   - Needs direction decision: the code is acceptable, but merging it commits the project to a choice that nobody has made.
   - Merge after changes: one or more must findings remain, and each one has a fix.
   - Merge: no must findings remain.
3. Add a split proposal in either case:
   - `WORK/findings-FIT.md` has a "Split proposal" section.
   - The hand-written changed lines in `WORK/context.md` exceed its `max_changed_lines` value.
4. Collect the "Questions for the author" and "Questions for the maintainer" from every findings file.
   - Drop each question that `WORK/context.md` already answers.
   - Drop each question whose answer changes no tier and not the verdict.
   - Merge duplicates. Number author questions `Q1`, `Q2`, ... and maintainer questions `D1`, `D2`, ....
5. Fill the template from `WORK/pr.md`, `WORK/context.md`, the findings files, the verifier results and the figures. Write in the maintainer's voice: direct, first person plural for the project ("we would own this"). Write the result to `WORK/report.md`.

## 8. Brief the maintainer

Write the briefing in chat. The maintainer triages from it, so it must stand alone. Follow this order:

1. One line: "Compared against `PARENT` (<reason>). Rerun with `--base <ref>` if that is wrong."
2. What the change does: 3-6 sentences in plain words. Say what was true before, what is true after, and why the author wants it. Name the PR's place in its stack when there is one.
3. The verdict, and 2-4 sentences on why.
4. A table of all findings: `F` number, tier, and a title in plain words.
5. For each must and should finding, a short block:
   - The title.
   - Background: the concept the reader needs, from the finding's Background field.
   - The problem and its effect on the project, in 1-3 sentences.
   - The fix, in one sentence.
   - "Resolved later in #N" when a later PR fixes it.
6. Open questions: list `Q` and `D` items in one line each, with the findings each one affects. Say that answering them is optional.
7. Next steps, one line each:
   - The report path `WORK/report.md`.
   - Answer a `D` question to change tiers, or tell me which findings to dismiss.
   - `/maintainer-review comment <target> F1 F4 Q2` drafts a PR review with the chosen items as inline comments.

Use `F`, `Q` and `D` numbers only. Leave reviewer IDs (`COR-2`) and dimension codes out of the chat.

## 9. Apply the maintainer's answers

Run this section only when the user answers a `D` question or dismisses findings.

1. Change the affected findings' tiers, or set `Status: dismissed` with the user's reason.
2. Change the verdict if the must findings changed.
3. Rewrite `WORK/report.md` with the changes, and record each answer under "Direction decisions".
4. Ask the user whether to add each answer that states lasting project direction to the "Decisions" section of the context file at `MAIN/.github/maintainer-review.md`. Add only the approved ones, with today's date. Leave the commit to the user.

## 10. Re-review

Apply these changes when step 1.5 found an earlier `WORK/report.md`.

1. Read the earlier report. Take the `HEAD` short hash from its header line.
2. Rename it to `WORK/report-<that hash>.md`.
3. Before section 4, run `git diff --no-ext-diff --output=WORK/since-last.patch <that hash> HEAD`.
   - If the command fails because the hash is gone (the contributor force-pushed), skip this file. Review the full change, and say so in the report header.
4. Append this sentence to each reviewer prompt in step 4.2: "Earlier findings are in WORK/report-<hash>.md and the changes since then are in WORK/since-last.patch. Focus on those changes, use the full tree for context, and say for each earlier finding whether it is resolved, still open, or changed."
5. Carry each earlier finding with `Status: dismissed` or `Status: posted` into the new report with that status. Drop a reviewer's new finding when it repeats a dismissed one.
6. Fill the "Since last review" section of the template.
