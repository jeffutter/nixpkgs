# Jeff's review preferences

Condensed from `pr-preflight/references/jeff-checks.md`. It keeps only the checks that apply to someone else's PR. Each check says when it applies and what to flag.

## Design

- Prior art. When the diff adds a parser, matcher, escaper, template, id format, serializer, retry loop or test-fixture framework, search the dependency tree and the standard library for one that does the job. Cite the standard when one exists: RFC 6570, URLPattern, Relay Global Object Identification.
- Duplicate mechanisms. When the diff adds a parse, match, validate, format or lookup function, `rg` for an existing one over the same data. Also flag a comment that copies a value from another source ("same as X") instead of referencing it.
- Justify each addition. For each new dependency, helper layer or guard for a finished migration, write one sentence on what it does that nothing else in the repo or CI does. Flag it when no such sentence exists.
- Speculative code. For each new branch, option, format variant or extension point, find a current caller, config or page that uses it. Flag it when nothing uses it.
- Parameters that avoid a decision. For each new optional parameter, flag or default argument, list the callers and the values they pass. Flag it when every caller passes the same value.
- Wrong owner. Flag a UI or interaction concern in a data source, or a data fetch in a pure resolver. State which module defines the concept.
- Throw on impossible data. Flag a silent default for a shape the upstream contract says cannot happen.
- Deep modules. Prefer one complete function over several that share hidden state. Length alone is not a defect. Extract a separate concern only when it fills more than about a third of a file with its own vocabulary, and do it in its own commit.

## Contracts and deploys

- Request values in identity. When the diff builds an id, cache key, entity key or component id, flag any input from the request (client, patron or user id, region, platform, locale) in the identity part. Identity goes before the `?`, options after.
- Deploy order. When the diff changes a federation key, schema contract or shared id format, or is one PR in a stack, state what breaks if either side deploys first. Check that this PR passes alone.

## Tests

- Each bug fix includes a test that fails without the fix.
- A commit labelled refactor, migrate or move keeps its assertions. Report a changed assertion there as a behaviour change hidden in a refactor.
- Flag shared fixture defaults that no assertion reads, and override pins added only to cancel a default.
- A new test tier states what it catches that CI and the other tiers do not.

## Docs and generated files

- Docs, diagrams and examples match the code. Check each signature, type, function name and flow arrow against source.
- A doc example shows the encouraged pattern. Flag an example that shows a legal but discouraged one.
- Prefer a command or a pointer to the source over a hand-written list of versions, pins, files or counts.
- Each generated or snapshot hunk has a cause in this branch.

## Tooling and operations

- Type packages match the runtime version they describe, such as `@types/bun` and `bun`.
- Sparse metrics have an explicit fill: zero for counts and rates, null for averages and percentiles. Metric tags come from a bounded set.
- A skill or script committed to a shared repo runs with tools every teammate has: no personal CLIs, unlisted env vars or tokens.

## Prose

- A comment states one constraint the code cannot show. Flag ticket ids, dates, "previously", "now", "this change", and names the code no longer has.
- Define each coined term at first use. A root-cause write-up starts with the user-visible effect, then the mechanism.
- Flag em dashes in team-facing prose.

## Skip

- Duplication that exists only during a staged migration, when a later PR or ticket in the stack removes it. Mention it once as optional.
