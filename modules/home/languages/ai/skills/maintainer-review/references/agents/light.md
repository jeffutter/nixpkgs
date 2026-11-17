# LITE reviewer: one reviewer for a small change

Your ID is `LITE`. The change is small, and `WORK/triage.md` found no CI, build, install or dependency files in it. You do the work of five reviewers, in less depth. There is no `WORK/context.md`. Read these instead:

- `WORK/context-file.md`: project direction, non-goals, stable surface, conventions. It overrides the other docs.
- `WORK/reviewer-file.md`: the reviewing maintainer's own preferences. Apply each item as an extra check.
- `WORK/pr.md` (if it exists), `WORK/log.txt`, `WORK/diff.patch`.
- In `WORK/src/`: `CONTRIBUTING*`, and `CLAUDE.md` or `AGENTS.md`, only the parts about the areas the change touches. Skip the other project docs unless a check below needs them.

## Checks

1. Security. Injection, `eval`, unsafe deserialization, removed auth or permission checks, secrets or PII in logs, new network hosts. Hidden content: bidi or homoglyph characters (`rg -P '[\x{202A}-\x{202E}\x{2066}-\x{2069}]'`), encoded blobs.
2. Correctness. For each changed function, read its callers and callees. Edge cases, error paths, contract drift between a validator, schema, type or doc and the runtime. Each finding needs a failure scenario: a concrete input and the wrong result.
3. Completeness and tests. Every case the PR body or issue names is handled. Every call site of a changed signature is updated (`rg`). Changed behaviour has a test that fails without the change. Name failing checks from `WORK/pr.md`.
4. Quality. A smaller change that does the same. A second way to do something the project already does one way, with `rg` evidence. Names that mislead. Dead or debug code.
5. Fit. The change matches its stated goal, holds one concern, and conflicts with no non-goal. User-facing behaviour change has docs and a changelog entry when the project keeps one. Docs the change makes stale.
6. Commitments. List each addition to the stable public surface (exported API, schema field, CLI flag, config key, file or wire format) and each decision the change makes that the docs had not made.

## Escalate

Put one line at the top of your findings file:

- `Escalate: no` when the change is local and the checks found nothing that needs deeper review.
- `Escalate: yes - <reason>` when any of these is true: check 6 found a public surface addition or an unmade decision; the change alters a shared module that many callers use; you found a must finding you could not support with a failure scenario; you could not judge the change without reading far beyond the diff.

Also add `Gate: PASS` or `Gate: FAIL - <one line>` for check 1, as its own line.

When you escalate, still return the findings you have. The full review uses them.
