# Comment mode

End state: `WORK/comment.md` holds a review comment for the contributor, and, with `--post` and the user's confirmation, it is posted to the PR.

## 1. Find the report

Find `WORK` as in step 1.1 of `references/review.md`, from the same target. Read `WORK/report.md`. If it does not exist, stop and tell the user to run `/maintainer-review <target>` first.

Use the report as the user left it. The user may have edited it. Skip every finding with `Status: dismissed`. Keep findings marked `accepted` as they are.

## 2. Draft the comment

Write the comment yourself in the main session. Delegate nothing: the user's edits to the report are the input.

- Write to the contributor, as the project. Be direct and kind. Thank them once, for something specific in the change.
- Never mention the security gate, the maintainer's private reasoning, ownership concerns about the contributor, or "Assumptions". Turn a security finding into a plain request ("Please pin this action to a commit hash").
- Lead with the outcome in one sentence that matches the verdict:
  - Merge: it is ready, plus any optional notes.
  - Merge after changes: what must change before we merge.
  - Needs direction decision: we need to decide <X> as a project first, and what happens next.
  - Decline: we will not merge it, why in one or two sentences, and what we would accept instead.
- Then add up to three lists, each under its heading. Leave out an empty list: "Required before merge" (must), "Please consider" (should), "Optional". One item per finding: `path:line`, the problem, and the fix. Do not paste the long-term-effect text; say what to change and why in one sentence.
- Add the split proposal as a request when the report has one.

Write it to `WORK/comment.md`. Show it to the user in full.

## 3. Post (only with `--post`)

1. Ask the user to confirm, and name the review type you will use: `--approve` for Merge, `--request-changes` for Merge after changes, `--comment` for the other verdicts.
2. After the user confirms, run `gh pr review <n> <type> --body-file WORK/comment.md`.
3. Show the user the PR URL.

Without `--post`, tell the user the path and the command above.
