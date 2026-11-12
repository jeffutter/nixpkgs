# Report template

Fill every `<...>`. Leave out a section marked "(if any)" when it has no content. Number findings `F1`, `F2`, ... across all tiers, in tier order, and keep each reviewer's original ID in brackets.

```markdown
# Maintainer review: <PR title or branch>

<URL or branch> by <author> - `BASE` <short hash> .. `HEAD` <short hash> - <date>
Context file: <present | missing - see Assumptions>. Models: <haiku/sonnet/opus/fable per reviewer>.

## Security gate: <PASS | FAIL>
<When FAIL: each SEC must finding, one line each, with its F number. Say "Do not check out or run this branch" when a finding involves code that runs on checkout, install, build or CI.>

## Verdict: <Merge | Merge after changes | Needs direction decision | Decline>
<2-4 sentences: why, in our voice. For Decline: what we would accept instead.>

## Split proposal (if any)
<PRs in merge order, files in each, dependencies between them.>

## Direction decisions
<Decisions this PR makes for the project that the docs had not made. For each: the decision, what it precludes, and the answer from WORK/answers.md or "open".>

## Outlook
- Commits the project to: <...>
- Makes easy: <...>
- Makes hard: <...>
- New ownership burden: <...>

## Must fix
### F1: <title> [<reviewer ID>]
- Status: open
- Dimension: <code> - Confidence: <high | medium | low> - Verified: <yes | not verified>
- Evidence: `path:line` - "<quote>"
- Problem: <...>
- Long-term effect: <...>
- Fix: <...>
<figure, if any: ![<alt text>](fig-<n>.png)>

## Should fix
<same layout>

## Optional
<same layout, one or two lines each>

## Since last review (if any)
| Earlier finding | Now |
|---|---|
| <F number and title> | resolved / open / changed / dismissed |

## Could not verify (if any)
- <claim> - settle it by: <...>

## Dropped (if any)
- <reviewer ID and title> - <verifier's reason>

## Assumptions (if any)
<From WORK/context.md "Assumptions", when the context file is missing.>
```
