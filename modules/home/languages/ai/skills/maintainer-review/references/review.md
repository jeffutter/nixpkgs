# Review mode

End state: `WORK/report.md` holds a verdict and verified findings in the maintainer's voice. The user has seen its path, the verdict and the must findings. Nothing is posted.

Fixed values:

- `SKILL`: the absolute path of this skill's base directory.
- `WORK`: the work directory from step 1.1.
- `BASE` and `HEAD`: the commits from step 1.2 or 1.3.
- In every command and prompt below, replace `SKILL`, `WORK`, `BASE`, `HEAD` and `<...>` with their values.
- Agent calls: use `subagent_type: "general-purpose"`. If a call rejects its `model` value, repeat the call without `model`.

## 1. Resolve the target

1. Run `git rev-parse --path-format=absolute --git-common-dir`. Set `WORK` to `<output>/maintainer-review/<slug>`.
   - PR: the slug is `pr-<number>`. Take the number from the URL when the target is a URL.
   - Branch: the slug is `branch-<name>`, with each `/` replaced by `-`.
2. For a PR, run these commands:
   - `gh pr view <n> --json number,title,body,author,url,baseRefName,headRefName,headRefOid,isCrossRepository,closingIssuesReferences,comments,reviews`
   - `gh pr checks <n>`. Keep the output even when the exit code is not zero. A non-zero exit means some checks failed or are pending.
   - `gh issue view <k> --json title,body` for each closing issue.
   - `gh repo view --json nameWithOwner` and `git remote -v`. The base remote is the remote whose URL contains that `nameWithOwner`.
   - `git fetch <base remote> <baseRefName> +pull/<n>/head:refs/maintainer-review/pr-<n>`. This fetch checks out nothing.
   - Set `HEAD` to `refs/maintainer-review/pr-<n>`.
   - Set `BASE` to the output of `git merge-base <base remote>/<baseRefName> refs/maintainer-review/pr-<n>`.
3. For a branch, or for no target (use the current branch from `git branch --show-current`):
   - Run `git symbolic-ref --short refs/remotes/origin/HEAD` to get the default branch.
   - Set `HEAD` to the branch.
   - Set `BASE` to the output of `git merge-base <default branch> <branch>`.
4. If `WORK/report.md` exists, this run is a re-review. Apply section 9 together with sections 2 to 8.

## 2. Write the inputs into WORK

1. Run these commands:
   - `git diff --no-ext-diff --stat --output=WORK/stat.txt BASE HEAD`
   - `git diff --no-ext-diff --name-status --output=WORK/files.txt BASE HEAD`
   - `git diff --no-ext-diff --output=WORK/diff.patch BASE HEAD`
   - `git archive --format=tar --output=WORK/head.tar HEAD`
2. Run `git log --format='%h %an %s' BASE..HEAD`. Write its output to `WORK/log.txt` with the Write tool.
3. Run `rm -rf WORK/src`, then `mkdir -p WORK/src`, then `tar -xf WORK/head.tar -C WORK/src`, then `rm WORK/head.tar`.
4. Write `WORK/meta.md`: target, URL, author, `BASE` and `HEAD` hashes, whether the PR is cross-repository, and today's date.
5. For a PR, write `WORK/pr.md`: title, body, linked issue titles and bodies, each comment and review with its author, and the `gh pr checks` output.

## 3. Run the context agent

1. Call one Agent with `model: "haiku"` and this prompt:
   ```
   You are the context agent for maintainer-review. Read SKILL/references/agents/context.md and follow it. WORK=WORK.
   ```
2. Wait for it to return. Read `WORK/context.md`.

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
3. Wait for all five to return.
4. For a local branch, run tests when all three conditions hold:
   - `WORK/findings-SEC.md` starts with `Gate: PASS`.
   - `WORK/pr.md` does not exist, or has no CI results.
   - The repo's README, CONTRIBUTING or CLAUDE.md names a test command.
   Run that command for the touched areas from the working tree. Write the command and its result to `WORK/tests.md`.

## 5. Ask the maintainer

1. Collect the items under "Questions for the maintainer" from every `WORK/findings-*.md` file.
2. Drop each question that `WORK/context.md` already answers.
3. Drop each question whose answer changes no tier and not the verdict.
4. Merge duplicate questions.
5. If no questions remain, go to section 6.
6. Ask the user all remaining questions in one message. Number them. Give each one its affected finding IDs and your best-guess answer.
7. Write the questions and answers to `WORK/answers.md`. Change the tiers of the affected findings to match the answers.
8. List the answers that state lasting project direction. Ask the user which ones to add to the "Decisions" section of `.github/maintainer-review.md` in the working tree. Add only the approved ones, with today's date. Leave the commit to the user.

## 6. Verify must findings

1. Group the must findings. With 10 or fewer, make one group per finding. With more than 10, make one group per file.
2. Call one Agent per group with `model: "sonnet"`, all in one message, with this prompt:
   ```
   You are a verifier for maintainer-review. Read SKILL/references/agents/verifier.md and follow it. WORK=WORK. Findings to verify:
   <the finding blocks, copied verbatim>
   ```
3. Apply each result:
   - CONFIRMED: keep the finding. Mark it verified.
   - REFUTED: remove the finding. List it under "Dropped" in the report, with the verifier's reason.
   - UNCERTAIN: change the finding to should, with low confidence.

## 7. Add figures

1. Pick the findings whose point is structural: a dependency direction changes, a public surface is added, or a data flow moves. Most reviews have none. With none, go to section 8.
2. Check your list of available skills for a diagram skill, for example `diagram-design` or `excalidraw-diagram`. With none, go to section 8. The report text must stand alone without figures.
3. For each picked finding, call one Agent with `model: "sonnet"`. Give it the diagram skill name, the finding block, and the output path `WORK/fig-<n>.png`. Tell it to render a PNG with that skill and to return only the path.

## 8. Write the report

1. Read `SKILL/references/report-template.md`.
2. Choose the verdict:
   - Decline: the change conflicts with a non-goal or the direction, or it costs the project more than it gives, and no change to the PR fixes that.
   - Needs direction decision: the code is acceptable, but merging it commits the project to a choice that nobody has made.
   - Merge after changes: one or more must findings remain, and each one has a fix.
   - Merge: no must findings remain.
3. Add a split proposal in either case:
   - `WORK/findings-FIT.md` has a "Split proposal" section.
   - The hand-written changed lines in `WORK/context.md` exceed its `max_changed_lines` value.
4. Fill the template from `WORK/context.md`, the findings files, `WORK/answers.md`, the verifier results and the figures. Write in the maintainer's voice: direct, first person plural for the project ("we would own this"). Write the result to `WORK/report.md`.
5. Show the user the path `WORK/report.md`, the verdict line, and each must finding in one line. Tell the user to edit a finding's `Status:` to `dismissed` or `accepted` if they disagree, and that `/maintainer-review comment <target>` drafts the contributor reply.

## 9. Re-review

Apply these changes when step 1.4 found an earlier `WORK/report.md`.

1. Read the earlier report. Take the `HEAD` short hash from its header line.
2. Rename it to `WORK/report-<that hash>.md`.
3. Before section 4, run `git diff --no-ext-diff --output=WORK/since-last.patch <that hash> HEAD`.
   - If the command fails because the hash is gone (the contributor force-pushed), skip this file. Review the full change, and say so in the report header.
4. Append this sentence to each reviewer prompt in step 4.2: "Earlier findings are in WORK/report-<hash>.md and the changes since then are in WORK/since-last.patch. Focus on those changes, use the full tree for context, and say for each earlier finding whether it is resolved, still open, or changed."
5. Carry each earlier finding with `Status: dismissed` into the new report as dismissed. Drop a reviewer's new finding when it repeats a dismissed one.
6. Fill the "Since last review" section of the template.
