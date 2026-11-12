# Report template

Fill every `<...>`. Leave out a section marked "(if any)" when it has no content. Use the `F`, `Q` and `D` numbers from review step 7.

```markdown
# Maintainer review: <PR title or branch>

<URL or branch> by <author> - compared against `PARENT` (<reason>) - `BASE` <short hash> .. `HEAD` <short hash> - <date>
Context file: <present | missing - see Assumptions>. Models: <model per agent>.

## What this change does
<3-6 sentences in plain words: what was true before, what is true after, and why the author wants it.>

To do this, the change:
- <each main mechanism, one line each>

<Stack: this PR's position, and what the later PRs change. Omit for a single PR.>

## Verdict: <Merge | Merge after changes | Needs direction decision | Decline>
<2-4 sentences: why, in our voice. For Decline: what we would accept instead.>

## Security gate: <PASS | FAIL>
<When FAIL: each security must finding, one line each, with its F number. Say "Do not check out or run this branch" when a finding involves code that runs on checkout, install, build or CI.>

## Index
| # | Tier | Finding | Resolved later |
|---|---|---|---|
| F1 | must | <title in plain words> | <#N or blank> |

Tiers: must blocks the merge; should is fixed before merge unless we accept it; optional the contributor may skip.

## Split proposal (if any)
<PRs in merge order, files in each, dependencies between them.>

## Open questions (if any)
Answering them is optional. Each one names the findings it would change.
- Q1 (for the author): <question>. Affects: <F numbers>. If <answer>, <F> becomes <tier>.
- D1 (for us): <direction question>. Affects: <F numbers>.

## Direction decisions
<Decisions this change makes for the project that the docs had not made. For each: the decision, what it precludes, and the answer from review section 9 or "open".>

## Outlook
- Commits the project to: <...>
- Makes easy: <...>
- Makes hard: <...>
- New ownership burden: <...>

## Must fix
### F1: <title in plain words>
- Status: open
- Raised by: <reviewer names, for example correctness, maintainability> - Dimension: <code> - Confidence: <high | medium | low> - Verified: <yes | not verified>
- Background: <...>
- Evidence: `path:line` - "<quote>"
- Anchor: `path:line` or none
- Problem: <...>
- Long-term effect: <...>
- Fix: <...>
- Resolved later: <#N and evidence, or omit>
<figure, if any: ![<alt text>](fig-<n>.png)>

## Why we ask for the rework (if any)
<Only after review section 9 step 2. Findings that the rework makes moot, one short block each, with no tier and no Status. They explain the rework to the author.>

## Should fix
<same layout>

## Optional
<same layout, Background and Long-term effect may be omitted>

## Since last review (if any)
| Earlier finding | Now |
|---|---|
| <F number and title> | resolved / open / changed / dismissed / posted |

## Could not verify (if any)
- <claim> - settle it by: <...>

## Dropped (if any)
- <title> - <verifier's reason>

## Assumptions (if any)
<From WORK/context.md "Assumptions", when the context file is missing.>

## Dimension codes
SEC security, DEP dependencies and licensing, COR correctness, CMP completeness, TST tests, QUA quality and simplicity, RED readability, CON consistency with existing patterns, MNT maintainability, API public surface and compatibility, OWN ownership, RSK long-term risk, FIT intent and scope fit, OPS operational cost and rollout, DOC docs and changelog, HYG PR hygiene, GEN generated code consistency.
```
