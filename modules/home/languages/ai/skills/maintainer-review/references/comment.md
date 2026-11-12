# Comment mode

End state: `WORK/review.json` holds a PR review for the contributor, as a general comment or with inline comments on the exact lines. With `--post` and the user's confirmation, it is posted to the PR and its comments are checked on GitHub.

Fixed values:

- `SKILL`: the absolute path of this skill's base directory.
- `WORK`: as defined in `SKILL.md` under "Locations". Resolve it with git; never look for `./.git`.
- `<n>`: the PR number from the target.
- `<repo>`: the `nameWithOwner` from `gh repo view --json nameWithOwner`.

## 1. Pick the items

1. Read `WORK/report.md`. If it does not exist, stop and tell the user to run `/maintainer-review <target>` first.
2. Pick the items to send:
   - When the invocation lists `F`, `Q` or `D` numbers, use exactly those.
   - Otherwise use each finding with `Status: accepted`.
   - Otherwise use each must and should finding that is not `Status: dismissed`.
3. Check that the PR has not changed since the review. Run `gh pr view <n> --json headRefOid`. Compare it with the `HEAD` hash in `WORK/meta.md`.
   - When they differ, tell the user, and recommend a re-review before posting. Continue only if the user says so.

## 2. Place each item

When the user asks for a general comment or for no inline comments, put every item in the body and go to section 3.

1. Collect the `Anchor` of each picked finding.
2. Run `python3 -I SKILL/scripts/diff_lines.py WORK/diff.patch <anchor> <anchor> ...`.
3. For each anchor marked `not-in-diff`, look in `WORK/diff.patch` for the nearest added or changed line in the same hunk that the comment is about. Run the script again on it.
4. An item with an `ok` anchor becomes an inline comment. Every other item goes into the review body, with its `path:line` in text. GitHub rejects the whole review when one inline line is outside the diff.

## 3. Draft the review

Write it yourself in the main session. The user's edits to the report are the input.

- Write to the contributor, as the project. Be direct and kind.
- Body: open with one sentence that matches the verdict.
  - Merge: it is ready, plus any optional notes.
  - Merge after changes: what must change before we merge.
  - Needs direction decision: we need to decide a project question first, and what happens next.
  - Decline: we will not merge it, why in one or two sentences, and what we would accept instead.
- Body: then the items that are not inline, under the headings "Required before merge", "Please consider" and "Questions". Leave out an empty heading. Add the split proposal as a request when the report has one.
- Inline comment: the problem in one or two sentences, the fix in one sentence, and the background only when the contributor may not know it.
- When a fix changes the design or is longer than one line, add a short code sketch in the repo's language. Read the code the sketch touches first, and use its real names. Say in the text that the sketch is untested.
- Never mention the security gate, ownership concerns about the contributor, "Assumptions", or tiers by name. Turn a security finding into a plain request ("Please pin this action to a commit hash").
- Review event: `REQUEST_CHANGES` when a must finding is picked, `COMMENT` otherwise, `APPROVE` only when the user asks. Use the event the user names when they name one.

Write the files, then build the payload:

1. Write the body to `WORK/review-body.md`.
2. With inline comments, write `WORK/review-comments.md`. Start each comment with a line `== <path>:<line> ==`, then its markdown. Without inline comments, delete that file if it exists.
3. Run `python3 -I SKILL/scripts/build_review.py WORK <headRefOid from step 1.3> <event>`. It writes `WORK/review.json` and `WORK/review-preview.md`.

Show the user `WORK/review-preview.md`. After it, list "Check before you post": each claim in the draft that no reviewer or verifier checked, such as a sketch's function names, a field the sketch adds, or a behaviour you inferred. If `cairn` is in your list of available skills, read `SKILL/references/cairn.md`, publish `WORK/review-preview.md`, and show the link.

When the user asks for changes, edit the markdown files and run the script again.

## 4. Post (only with `--post`, or when the user asks to post)

1. Ask the user to confirm. Name the event.
2. After the user confirms, run `gh api repos/<repo>/pulls/<n>/reviews --method POST --input WORK/review.json --jq '{id, state, html_url}'`.
3. With inline comments, check them: run `gh api repos/<repo>/pulls/<n>/comments --jq '.[] | select(.pull_request_review_id == <id>) | "\(.path):\(.line)"'`. Compare the output with the anchors you sent. The reviews endpoint shows `line: null` for new comments; use this comments endpoint.
4. In `WORK/report.md`, set `Status: posted` on each item you sent. If `WORK/cairn.md` lists `report.md`, publish it again as `SKILL/references/cairn.md` says.
5. Show the user the review URL and any comment that did not land on its anchor.

Without `--post`, tell the user the path `WORK/review.json`, and that "post it" posts it.
