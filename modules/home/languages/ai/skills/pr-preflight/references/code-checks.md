# Code checks: what Copilot's reviewer catches

Derived from 122 Copilot review threads on Jeff's PRs (acceptance rate per category in brackets, from the sample). Each check has a trigger (when to run it), a procedure, and the signal that makes it a finding. Apply a check only when its trigger matches the diff.

## C1. Validation and lookup disagree [92%]

Trigger: the diff touches a validator, schema, overlap or boundary check for something that is also parsed or matched at runtime (ids, paths, templates, headers, config keys).
Procedure: list every constant, regex and marker the runtime matcher uses (length limits, placeholder grammar, optional marker, query separator, repeat rule). For each one, `rg` the validation code for the same constant or grammar.
Signal: validation accepts a value that lookup rejects or matches differently. Write the shortest input pair that shows it. Require a test at the limit N and at N+1.

## C2. Round-trip and normalization [100%]

Trigger: the diff emits a value that is later parsed or compared: ids, cache keys, paths, headers, slugs.
Procedure: list every producer and every consumer of the value. For each, note the normalization (case, trim, lowercased UUID, decode) and its order relative to any exact-match or precedence step. If the same rule exists in two languages or layers (router script and resolver), diff the two.
Signal: one side normalizes and another compares verbatim, or normalization runs after an exact-match step. Test with an uppercase UUID, a delimiter inside a value, adjacent placeholders with no delimiter, and a non-BMP character.

## C3. Generated client or downstream code will not compile [100% outside one open PR]

Trigger: the diff touches a schema directive that changes fragment or type boundaries, an alias, a conditional spread, an interface, or a code-generator plugin.
Procedure: regenerate. For each changed type, open the generated fragment and the generated consumer (adapter, client model). Confirm every field the consumer reads is a direct selection, not behind a fragment accessor, `@include`/`@skip`, or an alias. For generics, check variance (`out T`) when a narrowed override exists. Grep the generator for a hard-coded value where a config option exists.
Signal: the consumer reads a field the generated type does not expose at that path, or exposes as optional. Compile the output when a toolchain exists.

## C4. Type-system edge cases in schema-walking code [71%]

Trigger: the diff calls `getNamedType`, `unwrap`, `astNode`, `hasDirective(`, `isInterfaceType`, or walks a schema or AST.
Procedure: for each call, ask whether a list wrapper, an interface implementor, a schema built without AST nodes, or a deprecated field changes the answer.
Signal: a check that should only strip NonNull also strips List; metadata read from AST that the typed API provides; a directive assumed inherited by implementors. Add a test with a list field, an interface with an implementor, and a deprecated field.

## C5. Stale comment, error message or doc after a rule change [80%]

Trigger: the diff widens or renames a concept (a new boundary kind, a renamed variable, a new state).
Procedure: name the old rule in one phrase. `rg` the whole repo, not the diff, for the old phrase, old directive names, old identifiers, and counts ("33 types"). Check module headers, JSDoc, thrown error strings, READMEs, docs, and CLAUDE.md. Compare each documented variable or type name with the generated artifacts.
Signal: text that states the old rule or names a thing that no longer exists. Report one finding with all locations.

## C6. Prose claims an invariant the code does not keep [80%]

Trigger: added prose contains always, never, only, every, each, guaranteed, cannot, deterministic, "the same", "each environment".
Procedure: for each absolute, `rg` for a counterexample: `Date.now`, `Math.random`, other call sites, other environments in config, other docs on the same topic.
Signal: a counterexample exists. Fix: remove the absolute or name the exception.

## C7. PR body or report disagrees with the diff [50%]

Trigger: a PR body or report exists.
Procedure: extract every number, type name, file count and "only / removed / added / no new" claim. Count the files, `rg` the schema, diff the manifest.
Signal: a claim the diff contradicts. Report once as one finding with all claims. Flag counts and hashes that will go stale.

## C8. Security and privacy sinks [100%]

Trigger: the diff handles data from a request, a header, a user, a URL, or a caller-supplied name; or starts a server; or gates behaviour on environment.
Procedure: trace each sensitive value to every sink: response body, cache headers, file name, generated source, logs, metric tags, test names. `rg` for `startsWith(`/`.startswith(` on hosts or URLs (prefix match is not an allowlist), `listen(`/`serve(` without a loopback host, `isProduction`/`RELEASE_ENV` gates (enumerate staging, UAT, demo, prod without a key), string interpolation into a path before `resolve` (then check the result stays under the root), and redaction lists against the repo's known credential headers.
Signal: a sink that is not covered, a prefix match, an all-interfaces listener, a gate with a bypass, a path escape. Add `Cache-Control: private, no-store` on PII responses.

## C9. Destructive or lossy side effects [86%]

Trigger: a script, skill or tool step writes, deletes, restarts, installs, updates or publishes.
Procedure: for each such action ask: is the target explicit or inherited from the environment (kubectl context, cwd, ambient config)? Is the precondition checked before the action, with a conditional or versioned write? Does each mode (fill, append, replace) do what its name says? In a skill, does an action run before a "stop and ask" step?
Signal: a check after the write, a default target, a mode that does something else, an action before the gate.

## C10. Range edges and arithmetic [100%]

Trigger: the diff has a comparison at a range edge, a statistic, a slice (`[:N]`), a filter that drops history, a `re.sub` with user text, or an append.
Procedure: test equal, empty and one-element inputs; even and odd lengths; a sequence where a later step needs data the slice dropped (rollback, skipped release); a replacement string with `\` in it; a second run of an append.
Signal: `>` where `>=` is needed, upper-middle instead of median, double counting, dropped data, non-idempotent append.

## C11. Null, empty and fallback states conflated [60%]

Trigger: the diff has `?? undefined`, `|| parent.id`, `?? parent`, `=== undefined` after a lookup, a default resolver on a field documented as null, or removes a fallback.
Procedure: name the states ("not found", "found but unresolved", "empty"). Confirm each stays distinct through the code path. For a schema field documented as null, confirm an explicit resolver returns null.
Signal: two states collapse to one and a later step picks the wrong entity. Before calling a removed fallback a break, confirm its id exists outside tests.

## C12. Language runtime pitfalls [100%]

Trigger: TypeScript or JavaScript in the diff.
Procedure: `rg` the diff for ` in ` on plain objects (use `Object.hasOwn`), `.map(` in a serializer (sparse holes), `z.int()`/`z.number()` feeding a GraphQL `Int` (32-bit), `JSON.stringify` in a generator (`NaN`/`Infinity` become null), `as boolean` on an external flag (require `=== true`), `localeCompare(` without a locale in generated output.
Signal: any hit without the guard.

## C13. Unbounded work [100%]

Trigger: a regex built from config or input with two or more greedy captures; a byte or time budget; buffering of a payload.
Procedure: run the regex on a long input that fails to match; find where bytes are produced versus where the budget is charged; check that truncated items drop their full source.
Signal: catastrophic backtracking, a budget charged once for data serialized many times, retained full payloads.

## C14. Test isolation and correctness [100%]

Trigger: tests in the diff use module mocks, iterate committed config files, or wrap failures.
Procedure: for `mock.module(`, confirm the restore uses a copy taken before the mock, not the live namespace. For a loop over committed files, ask whether a valid parameterized or restricted entry would fail. For a guard that converts an exception to a value, confirm the test cannot pass on the exception path. Each new script with logic has a test file.
Signal: a test that restores the mock, rejects valid config, or passes on failure.

## C15. Docs that break when followed [100% after verification]

Trigger: the diff changes a docs route, sidebar config, README link, or adds copyable code to a guide.
Procedure: `rg` docs and README for the old route prefix. Confirm README links use the deployed docs URL, not root-absolute site paths. Paste each code block from a guide into a scratch file and run the linter and type checker on it.
Signal: a broken link, a block that fails lint or types. Verify each extra location before listing it.

## C16. Companion pins and conventions [67%]

Trigger: a version bump, a new CLI in a doc, a sort in generated output.
Procedure: `rg` the repo for the old version string (companion files such as `.tool-versions`, `flake.nix`, CI). Check that documented commands use the pinned package runner. Check that a doc's prerequisites list every CLI it uses.
Signal: a companion still on the old version; `npx` where the repo pins `pnpm dlx`; a missing prerequisite.

## C17. Static-analysis bots (cycode) [0% real in the sample]

Trigger: a Python or Node script runs `subprocess`, opens a path built from arguments, or escapes HTML by hand.
Procedure: do not change the code for the bot. Pre-write the false-positive note: argument list with no shell, `--` before paths, a validated tag regex, a resolved path checked against an expected root, an escaping function with a named reason.
Signal: none of these facts is true, in which case it is a real C8 finding.
