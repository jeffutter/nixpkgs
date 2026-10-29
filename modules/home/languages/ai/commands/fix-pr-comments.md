---
description: Fetch and address unresolved PR review comments for the current branch
model: opus
---

Fetch unresolved review comments and the latest review bodies for the current branch's PR, fix them, then commit, push, and resolve the threads.

Extra instructions from me, if any: $ARGUMENTS

Run every `gh` and `git` command bare: no pipes, redirects, or loops. Use `--jq` instead of piping to `jq`.

First, get the PR number and repository info by running these commands:

```bash
gh pr view --json number -q .number
```

```bash
gh repo view --json owner,name -q '.owner.login + "/" + .name'
```

If there's no PR for the current branch, let me know.

Then fetch unresolved threads and the last reviews using those values (replace OWNER, REPO, PR_NUMBER). Do not request `diffHunk`; read the file at the given line instead.

```bash
gh api -X POST graphql -f query='query { repository(owner: "OWNER", name: "REPO") { pullRequest(number: PR_NUMBER) { reviews(last: 5) { nodes { state body author { login } } } reviewThreads(first: 100) { nodes { id isResolved comments(first: 100) { nodes { author { login } body url line startLine path } } } } } } }' --jq '.data.repository.pullRequest | {reviews: [.reviews.nodes[] | select(.body != "")], threads: [.reviewThreads.nodes[] | select(.isResolved == false) | {id, comments: [.comments.nodes[] | {author: .author.login, path, line, startLine, body}]}]}'
```

If there are no unresolved threads and no CHANGES_REQUESTED or COMMENTED review body with a concrete claim, let me know the PR looks good and stop.

Then:

1. Summarize each unresolved thread. Treat each claim in a review body (including bot reviews) as an item: test it against the code before you call it vague or wrong.
2. For each item, identify the file and code that needs to be changed. If an item is on code you are about to delete or rewrite anyway, say so and skip it.
3. Propose fixes for each issue.
4. Use the AskUserQuestion tool to ask which fixes to apply.
5. Apply the chosen fixes. Run the checks that cover the changed files (tests, lint, typecheck, format).
6. Commit the fixes. Write the message to a new file under `$TMPDIR` and use `git commit -F <file>`.
7. Push with `git push`.
8. After the push succeeds, resolve each thread you fixed:

   ```bash
   gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'
   ```

   Leave a thread unresolved if I chose to skip its fix.
9. To reply to a thread, write the body to a file with the Write tool first, then in a later turn run a bare:

   ```bash
   gh api graphql -F threadId=THREAD_ID -F body=@FILE -f query='mutation($threadId: ID!, $body: String!) { addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) { comment { url } } }'
   ```

   Never inline a body with backticks or quotes on the command line.
10. If the fixes change behaviour the PR body describes, update the body with `gh pr edit --body-file <file>`.

Do steps 6 to 10 without asking, unless my extra instructions say otherwise. Stop and tell me instead of continuing when something goes wrong:

- A check fails and the fix is not obvious.
- The commit hook fails.
- The push is rejected. If the remote has only new commits that do not touch the files I changed, `git fetch`, `git rebase` onto the remote branch, and push again. Otherwise, stop.
- The push needs `--force`. Never force-push without asking.

Never resolve a thread before its fix is pushed.
