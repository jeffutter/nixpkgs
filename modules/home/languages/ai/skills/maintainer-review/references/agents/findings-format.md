# Findings format (all reviewer agents)

`WORK` is the work directory given in your prompt. It holds:

- `WORK/meta.md`: target, `BASE` and `HEAD` commits, PR or branch facts.
- `WORK/pr.md`: PR title, body, author, linked issues, discussion, CI results. Missing for a local branch.
- `WORK/context.md`: project direction, non-goals, stable surfaces, conventions, generated files, concerns. Written by the context agent.
- `WORK/files.txt`, `WORK/stat.txt`, `WORK/diff.patch`, `WORK/log.txt`: the change.
- `WORK/src/`: the full tree at `HEAD`. Read it and search it with `rg`. Never build, install, test or run anything in it.

Rules:

- Review only hand-written files. `WORK/context.md` lists the generated files. Skip them unless your brief names a check for them.
- Every finding needs evidence: `path:line` in `WORK/src/` (or a `diff.patch` hunk for removed code) and a quote of the lines.
- Before you claim "unused", "only caller", "nothing else does this" or "a second way to do X", run `rg` across `WORK/src/` and cite what you found.
- Drop a finding you cannot support with evidence. Put it under "Could not verify" with what would settle it.
- Report a defect once, at its root location. Do not list each repeat.
- Do not comment on style that a formatter or linter in the repo enforces.

Write your findings to `WORK/findings-<your id>.md` with this layout:

```markdown
# <reviewer name>

## Findings

### <ID>-<n>: <one-line title>
- Tier: must | should | optional
- Dimension: <one of the dimension codes below>
- Confidence: high | medium | low
- Evidence: `path:line` - "<quoted line>"
- Problem: <what is wrong, one or two sentences>
- Long-term effect: <what this costs the project later; omit if none>
- Fix: <the change you would accept, with the existing function, library or pattern to use>

## Questions for the maintainer
- <question about project direction whose answer changes a tier or the verdict>. Affects: <finding IDs>.

## Could not verify
- <claim> - settle it by: <file to read or command to run>
```

Tiers:

- must: blocks the merge. Wrong behaviour, security risk, data loss, a public commitment the project does not want, a license problem, or missing tests for changed behaviour.
- should: fix before merge unless the maintainer accepts it. Drift, duplication, a future change made harder, missing docs.
- optional: a nit or an improvement the contributor may skip.

Dimension codes: SEC security, DEP dependencies and licensing, COR correctness, CMP completeness, TST tests, QUA quality and simplicity, RED readability, CON consistency with existing patterns, MNT maintainability and openness to change, API public surface and compatibility, OWN ownership, RSK long-term risk, FIT intent and scope fit, OPS operational cost, DOC docs and changelog, HYG PR hygiene, GEN generated code consistency.

Return to the caller only: the number of findings per tier, and the path of your findings file. At most 60 words.
