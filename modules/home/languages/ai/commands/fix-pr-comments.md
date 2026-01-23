---
description: Fetch and address unresolved PR review comments for the current branch
---

Fetch unresolved review comments for the current branch's PR and help address them.

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
gh api -X POST graphql -f query='query { repository(owner: "OWNER", name: "REPO") { pullRequest(number: PR_NUMBER) { reviewThreads(first: 100) { nodes { id isResolved comments(first: 100) { nodes { author { login } body url diffHunk line startLine path } } } } } } }' | jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
```

Then:
1. Summarize each unresolved comment
2. For each comment, identify the file and code that needs to be changed
3. Propose fixes for each issue
4. Use the AskUserQuestion tool to ask if I want to apply the fixes

If there are no unresolved comments, let me know the PR looks good.
