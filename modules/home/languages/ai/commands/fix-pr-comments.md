---
description: Fetch and address unresolved PR review comments for the current branch
---

Fetch unresolved review comments for the current branch's PR, fix them, then commit, push, and resolve the threads.

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

Then fetch unresolved comments using those values (replace OWNER, REPO, PR_NUMBER):

```bash
gh api -X POST graphql -f query='query { repository(owner: "OWNER", name: "REPO") { pullRequest(number: PR_NUMBER) { reviewThreads(first: 100) { nodes { id isResolved comments(first: 100) { nodes { author { login } body url diffHunk line startLine path } } } } } } }' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
```

If there are no unresolved comments, let me know the PR looks good and stop.

Then:

1. Summarize each unresolved comment.
2. For each comment, identify the file and code that needs to be changed.
3. Propose fixes for each issue.
4. Use the AskUserQuestion tool to ask which fixes to apply.
5. Apply the chosen fixes. Run the checks that cover the changed files (tests, lint, typecheck, format).
6. Commit the fixes. Write the message to a file under `$TMPDIR` and use `git commit -F <file>`.
7. Push with `git push`.
8. After the push succeeds, resolve each thread you fixed:

   ```bash
   gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'
   ```

   Leave a thread unresolved if I chose to skip its fix.

Do steps 6 to 8 without asking, unless my extra instructions say otherwise. Stop and tell me instead of continuing when something goes wrong:

- A check fails and the fix is not obvious.
- The commit hook fails.
- The push is rejected. If the remote has only new commits that do not touch the files I changed, `git fetch`, `git rebase` onto the remote branch, and push again. Otherwise, stop.
- The push needs `--force`. Never force-push without asking.

Never resolve a thread before its fix is pushed.
