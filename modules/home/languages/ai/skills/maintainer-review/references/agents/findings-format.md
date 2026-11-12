# Findings format (all reviewer agents)

`WORK` is the work directory given in your prompt. It holds:

- `WORK/meta.md`: target, `BASE` and `HEAD` commits, PR or branch facts.
- `WORK/pr.md`: PR title, body, author, linked issues, discussion, CI results, and "Related PRs" (the other PRs in the same stack). Missing for a local branch.
- `WORK/context.md`: project direction, non-goals, stable surfaces, conventions, generated files, concerns.
- `WORK/files.txt`, `WORK/stat.txt`, `WORK/diff.patch`, `WORK/log.txt`: the change.
- `WORK/src/`: the full tree at `HEAD`. Read it and search it with `rg`. Never build, install, test or run anything in it.

Rules:

- Review only hand-written files. `WORK/context.md` lists the generated files. Skip them unless your brief names a check for them.
- Every finding needs evidence: `path:line` in `WORK/src/` (or a `diff.patch` hunk for removed code) and a quote of the lines.
- Before you claim "unused", "only caller", "nothing else does this" or "a second way to do X", run `rg` across `WORK/src/` and cite what you found.
- Drop a finding you cannot support with evidence. Put it under "Could not verify" with what would settle it.
- Report a defect once, at its root location. List each repeat only by `path:line`.
- Skip style that a formatter or linter in the repo enforces.
- Read "Related PRs" in `WORK/pr.md`. When a later PR in the stack already fixes a finding, set its tier to optional and fill `Resolved later`. Quote the later PR's body or diff summary as evidence.
- Write for a maintainer who knows the project but has not read this PR or this area of the code. Name each type, rule or mechanism in plain words the first time you use it.
- Use no abbreviation that this file does not define.

Your final message is your findings file, in full, in this layout. Write no file. The main session saves it as `WORK/findings-<your ID>.md`.

```markdown
# <reviewer name>

## Findings

### <ID>-<n>: <one-line title in plain words>
- Tier: must | should | optional
- Dimension: <one of the dimension codes below>
- Confidence: high | medium | low
- Background: <1-3 sentences: what the reader must know to follow the problem - what the code does here, what the rule or mechanism is, why it exists>
- Evidence: `path:line` - "<quoted line>"
- Anchor: `path:line` of the added or changed line that a PR comment should sit on, or "none"
- Problem: <what is wrong, one or two sentences>
- Long-term effect: <what this costs the project later; omit if none>
- Fix: <the change you would accept, with the existing function, library or pattern to use>
- Resolved later: <PR number and evidence, or omit>

## Questions for the author
- <a fact about the change only the author knows: intent, upstream behaviour, production data>. Affects: <finding IDs>. If the answer is <X>, <finding> becomes <tier>.

## Questions for the maintainer
- <a project direction choice that only a maintainer can make, not answered in WORK/context.md>. Affects: <finding IDs>.

## Could not verify
- <claim> - settle it by: <file to read or command to run>
```

Tiers:

- must: blocks the merge. Wrong behaviour, security risk, data loss, a public commitment the project does not want, a license problem, or missing tests for changed behaviour.
- should: fix before merge unless the maintainer accepts it. Drift, duplication, a future change made harder, missing docs.
- optional: a nit, an improvement the contributor may skip, or a problem a later PR in the stack fixes.

Dimension codes: SEC security, DEP dependencies and licensing, COR correctness, CMP completeness, TST tests, QUA quality and simplicity, RED readability, CON consistency with existing patterns, MNT maintainability and openness to change, API public surface and compatibility, OWN ownership, RSK long-term risk, FIT intent and scope fit, OPS operational cost and rollout, DOC docs and changelog, HYG PR hygiene, GEN generated code consistency.
