# Jeff's checks: what he asks to change

Derived from the changes Jeff asked for during sessions. Each check has a trigger, a procedure and the signal that makes it a finding. Where Jeff's own words exist they are quoted so the reviewer reports in his terms.

## Design

### J1. Prior art before bespoke code

Trigger: the diff adds a regex grammar, tokenizer, matcher, escaper, template or id format, serializer, retry loop, or test-fixture framework.
Procedure: search the dependency tree (`package.json`, the lockfile, the language's standard library) for a library that does the job. Name the standard (RFC 6570, URLPattern, Relay Global Object Identification) when one exists.
Signal: the diff or PR body does not name the library or standard, or hardens a hand-written matcher across several commits. Jeff: "i feel like backend web frameworks have this figured out."

### J2. Earns its place

Trigger: the diff adds or keeps a dependency, a helper layer, a test tier, or a guard for a finished migration.
Procedure: write one sentence on what it does that nothing else in the repo or CI does.
Signal: no sentence, or the sentence names something CI already checks. Jeff: "What role does @graphql-tools/mock even provide on this branch?" and "We do schema checks and composition checks in CI anyway."

### J3. Two mechanisms for one job

Trigger: the diff adds a parse, match, validate, format or lookup function.
Procedure: `rg` the repo for an existing function over the same grammar or data. Compare their rules.
Signal: a parallel implementation, or a comment that copies a value from another source ("same as X") instead of referencing it. Jeff: "do we reuse that parsing logic for the component ids in this PR? should we?"

### J4. Request values in identity

Trigger: the diff builds an id, cache key, entity key or component id.
Procedure: list the inputs. Mark any that come from request headers or context: client, patron or user id, region, platform, locale.
Signal: a request value inside the identity part, without a comment naming the downstream key that requires it. Identity goes before the `?`; options go after. Jeff: "We shouldn't bake the patron ID into that."

### J5. Speculative code

Trigger: the diff adds a branch, option, format variant or extension point.
Procedure: find a current caller, config file or page that exercises it.
Signal: none exists. Ask for the concrete case or remove it. Jeff: "there weren't really any components currently in the app that this even applies to, right?"

### J6. Separable concern in a large file

Trigger: more than about a third of a changed file serves one concern with its own vocabulary (parsing, formatting, a grammar).
Procedure: name the module it would become and the tests that move with it.
Signal: the concern is still inline. Propose the extraction as its own commit. Do not split one complete function.

### J7. Wrong owner

Trigger: the diff adds a field, behaviour or assumption about what another service or module returns.
Procedure: name the service or module that owns the concept.
Signal: a UI or interaction concern in a data source, or a data fetch in a pure resolver. Jeff: "Promotions shouldn't know anything about interactions."

### J8. Scope

Trigger: always.
Procedure: map each changed file to an item in the ticket, plan or explicit ask.
Signal: a file, test tier, branch or PR with no match. Jeff: "why do we have tests now that run the actual router?"

### J9. Configuration parameter instead of a decision

Trigger: the diff adds an optional parameter, flag or default argument.
Procedure: list the callers and the values they pass.
Signal: every caller passes the same value, or the parameter exists so the author did not have to decide. From Jeff's design bias: "a configuration parameter is usually a decision I didn't make."

### J10. Deployability and deploy order

Trigger: the diff changes a federation key, schema contract, shared id format, or is one PR in a stack.
Procedure: state what happens if this side deploys first, and if the other side deploys first. In a stack, confirm each PR passes the full gate alone.
Signal: an order that breaks, or a PR that only works with a later one. Jeff: "what if the code change on promotions ... hasn't been published yet".

### J11. Fail loudly on impossible data

Trigger: the diff handles a shape the upstream contract says cannot happen.
Procedure: check whether the code throws through the guard or returns a silent default.
Signal: a silent default for an impossible shape. Jeff: "Probably throw?"

## Tests

### J12. Goal metric for tests

Trigger: the goal names smaller, simpler, faster or more maintainable tests.
Procedure: `git diff --no-ext-diff --stat BASE...HEAD -- '*test*'`; longest test body before and after; per-file test time on HEAD and BASE.
Signal: net test lines grew, or a file got slower, when the goal was the opposite. Jeff: "It seem like we made them bigger and slower?"

### J13. Fixture defaults that nothing reads

Trigger: the diff adds shared fixture defaults or builders.
Procedure: for each default, find an assertion that reads it. Count explicit `null` or override pins added only to cancel a default.
Signal: defaults with no reader, or more cancel-pins than readers. The model's own diagnosis in that case: "they only filled fields nobody read."

### J14. Refactor commits keep assertions

Trigger: a commit is labelled refactor, migrate or move.
Procedure: diff the assertions in that commit.
Signal: an assertion changed. Report it as a behaviour change hidden in a refactor.

### J15. Bug fixes carry a failing test

Trigger: the goal is a bug fix.
Procedure: find the test that fails before the fix. Prefer the test in its own commit before the fix.
Signal: no such test. Jeff: "I'd like to commit the test, and then try to fix it."

### J16. Test tiers justify themselves

Trigger: the diff adds a test tier (plan tests, integration, real server).
Procedure: one sentence per tier on what it catches that CI and other tiers do not.
Signal: no sentence. Keep plan-shape tests that catch what composition cannot; question tiers that repeat CI.

## Docs, diagrams and PR content

### J17. Diagrams and docs match the code

Trigger: the diff changes a diagram, doc, or example code.
Procedure: list every signature, type, function name and flow arrow. Confirm each against source with `file:line`. Type-check each example against current types.
Signal: any mismatch. One wrong signature in a diagram is a High finding; readers copy it.

### J18. Examples teach the encouraged pattern

Trigger: a doc example shows a configuration or API use.
Procedure: read the example as an instruction a new engineer will copy.
Signal: it shows a legal but discouraged pattern. Jeff: "I don't want to encourage that."

### J19. PR body freshness

Trigger: a PR body exists and the branch gained commits since it was written.
Procedure: check every identifier, path, base branch, "N commits", hash, test count and "no new dependencies" claim.
Signal: a stale claim. Remove counts and hashes rather than updating them. A stacked PR states "PR k of n", its base, and that it deploys alone.

### J20. Rendered images, not Mermaid

Trigger: the work produced figures (explainer HTML, SVG, screenshots).
Procedure: check the PR body and docs for embedded rendered PNGs of those figures.
Signal: a Mermaid or ASCII stand-in. Jeff: "the mermaid diagrams are lame. I need you to generate the images".

### J21. Lists that drift

Trigger: a doc, skill or PR body enumerates versions, pins, files or counts.
Procedure: ask whether a command could derive the list.
Signal: a hand-written list a command could produce. Replace it with the command or a pointer to the source. Jeff: "Do we need to remove the skill's list as it may drift from the actual pins?"

### J22. Team-runnable tooling

Trigger: the diff commits a skill or script to a shared repo.
Procedure: list the CLIs, env vars and tokens it needs. Compare with the repo's toolchain and the team's standard setup.
Signal: a personal CLI, an unlisted env var, or a token teammates do not have. Jeff: "I can't expect people to do that."

### J23. Unexplained generated hunks

Trigger: a generated, published or snapshot file changed.
Procedure: name the source change and commit that caused each hunk.
Signal: a hunk with no cause in this branch. Jeff: "why is published-supergraph.graphql changed compared to main?"

### J24. Upstream issue drafts

Trigger: the work includes an issue or bug report for another project.
Procedure: resolve each version or commit claim with `git describe` or `git branch --contains`. Check the bug on the latest release and the development branch, or state that this was not done. Mark each cause observed or inferred. A fix PR carries the repo's changelog artifact.
Signal: a wrong version, an unchecked latest release, an inferred cause stated as fact.

### J25. Docs changes say how to view them

Trigger: the diff changes a docs site or rendered documentation.
Procedure: the PR body or report names the command or URL to preview it.
Signal: missing. Jeff: "How can I preview the docs?"

## Comments and prose

### J26. Comments

Trigger: a changed line has a comment.
Procedure: flag ticket ids, dates, "previously", "now", "this change", and names of things the code no longer has. A comment states a constraint the code cannot show, in one line.
Signal: any of those.

### J27. Terms and root causes

Trigger: a PR body, issue, or doc introduces a coined term or an unfamiliar function name, or explains a root cause.
Procedure: the term is defined at first use in plain words. A root cause starts with the user-visible effect in one sentence, then the mechanism, then the evidence.
Signal: an undefined term or a mechanism-first write-up. Jeff: "what do you mean by enrollment result?"

### J28. Prose tells

Trigger: any team-facing prose in the diff.
Procedure: `rg` for the em dash. Check for noun-phrase pairs joined by a comma as a closer, not-X-but-Y contrasts, forced triads, and one-line closers. Check that colleagues are named by first name, and that no sentence frames the change around what a colleague got wrong.
Signal: any of those. Load the `humanizer` skill for a full pass when the prose is long.

## Metrics and dashboards

### J29. Sparse metrics and tag cardinality

Trigger: the diff changes a dashboard query, monitor, or metric emission.
Procedure: each query on a sparse metric has an explicit fill: zero for counts and rates, null for averages and percentiles. Each metric tag comes from a bounded set (codes), not free text (messages, ids).
Signal: a missing fill or a free-text tag. Jeff: "Can we be careful about setting default zero on some things."

### J30. Types match the runtime

Trigger: the diff bumps a runtime or its type package.
Procedure: compare `@types/<runtime>` (or the equivalent) with the pinned runtime version.
Signal: a mismatch. Jeff: "leave @types/bun the same as the version of bun we're actually using."
