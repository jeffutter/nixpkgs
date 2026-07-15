---
name: review-pi-work
description: >-
  Audit the last N completed backlog tickets that the autonomous `pi` loop
  finished, judging the work on Correctness, Conciseness, Clarity, Organization,
  and Resilience. File any required fixes as tightly-scoped backlog tickets with
  thorough plans and proper dependencies so the next `pi` round course-corrects.
  Invoke when checking in on pi's progress, e.g. "review pi's last few tickets".
---

# Review pi's Work

`pi` runs autonomously, churning through backlog tickets one at
a time. This skill is the human-in-the-loop checkpoint: every few tickets you run
it to audit what pi shipped and steer it back on course **by filing new backlog
tickets**, not by editing code yourself.

The output of this skill is a short report plus zero or more new backlog tickets.
You do **not** fix anything directly here — pi fixes its own work on its next
round. Your job is to find what's wrong and write crystal-clear fix-it tickets.

## Arguments

`$ARGUMENTS` may contain a number `N` = how many recently-completed tickets to
review. If absent, default to **5**. It may also name specific tasks
(e.g. `task-7 task-8`) — review exactly those instead.

---

## Step 0 — Identify the tickets to review

Completed tickets are committed one-per-task by the committer step, so git log is
the reliable record of recency.

```bash
# Most recent task commits, newest first.
git log --oneline -n 40 --grep='^task-[0-9]+' -i --extended-regexp
```

Take the first `N` distinct `task-<id>` commits. Cross-check status:

```bash
backlog task list -s Done --plain
```

Record the list of `TASK_ID`s to review. If git log and the Done list disagree
(e.g. a task marked Done but never committed), note that as a finding — it means
the loop left work in an inconsistent state.

---

## Step 1 — Gather the evidence for each ticket

For each `TASK_ID`, collect three things:

1. **Intent** — what it was supposed to do:
   ```bash
   backlog task <TASK_ID> --plain
   ```
   Read the Description, Acceptance Criteria (all checked?), Implementation Plan,
   Definition of Done, and Final Summary.

2. **The change** — what actually landed:
   ```bash
   git show --stat <commit>      # files touched
   git show <commit>             # full diff
   ```

3. **The current state on disk** for any file that looks suspicious in the diff —
   read the whole file, not just the hunk, so you judge it in context.

---

## Step 2 — Run the deep-dive skills

Before forming your own opinion, lean on the specialist skills:

- **`/rust-best-practices`** — run this for every reviewed ticket that touched
  `crates/**` / `*.rs`. It encodes Apollo's Rust handbook (borrowing vs cloning,
  `Result` vs panic, no `unwrap()/expect()` outside tests, clippy lints, error
  hierarchies, testing idioms). Feed it the changed Rust files.
- **`/code-review`** — run this for a general production-quality pass over the
  diff (any language, including the TypeScript/React shell in `web/`).

Fold their findings into your own review below — don't just paste them.

---

## Step 3 — Judge each ticket on the five axes

Score every reviewed ticket against all five. Cite specific `file:line` for each
finding. The project's design philosophy in `CLAUDE.md` is the rubric for several
of these — apply it.

1. **Correct** — Does the code actually satisfy every acceptance criterion? Are
   the tests meaningful (asserting real behaviour, not tautologies) and do they
   cover success, error, and edge cases? Were ACs checked off without
   corresponding code/tests? Does it honour project invariants: the JSON-string
   JS↔Rust boundary returns our own DTOs (never apollo-federation internals),
   determinism keyed on `seed`, errors-as-values?

2. **Concise** — Is there dead code, speculative abstraction, pass-through
   layers, or duplication? Apply `value >> cost`: if an abstraction's value can't
   be articulated, it's a finding. Prefer fewer, deeper modules.

3. **Clear** — Naming creates the right mental image? Comments explain *why* /
   precision (units, invariants, null meaning), not restating code? Could a new
   reader use each function from its signature + doc without reading the body?

4. **Well organized** — Deep modules with simple interfaces hiding real
   complexity? No information leakage (the same format/policy/algorithm knowledge
   duplicated across modules)? Are module boundaries in the right place, or does
   changing one layer force changing another?

5. **Resilient** — No `panic!`/`unwrap()`/`expect()` outside tests (errors are
   returned as values across the WASM boundary). Edge cases handled or defined
   out of existence. Fails safe (e.g. composition failure keeps the last good
   supergraph where the design calls for it). Inputs validated.

For each finding, assign a severity:
- **blocker** — incorrect behaviour, broken invariant, missing/again-failing
  tests, a panic reachable from the boundary.
- **should-fix** — clear quality problem with real cost (leaky module,
  misleading name on a public item, untested error path).
- **nit** — minor; mention in the report but usually **do not** file a ticket.

---

## Step 4 — File fix-it tickets (the important part)

Create a backlog ticket for **every blocker and should-fix** finding. Nits go in
the report only. Each ticket must be picked up cleanly by the next `pi` round, so
follow these rules exactly.

**One fix per ticket — tightly scoped.** Never bundle unrelated findings. If one
reviewed task produced three independent problems, create three tickets.

**Make it ready-now so the loop picks it up.** `pi` selects the first task in
"Sequence 1" of `backlog sequence list --plain` (tasks whose dependencies are all
Done). To land a fix there *and* keep lineage:
- Set `--depends-on <reviewed TASK_ID>` (that task is Done, so the dependency is
  satisfied → the fix appears in Sequence 1 immediately).
- Set `--priority high` and a **low `--ordinal`** (e.g. `100`, `110`, …) so the
  fix sorts ahead of feature work within Sequence 1 and gets done first.
- Label it: `--labels review-followup` so these are easy to find and audit.
- Assign the same `--milestone` (`-m`) as the reviewed task's area.

**Block future work when the fix is a prerequisite.** If a finding means a
not-yet-started task is now building on a broken foundation, add this new fix
ticket as a dependency of that future task too — edit the future task:
`backlog task edit <FUTURE_ID> --depends-on <NEW_FIX_ID>` (preserving its
existing deps). This is the "blocker" wiring: the dependent feature won't enter
Sequence 1 until the fix is Done.

**Write a thorough plan, in this project's house style.** Match the existing
tickets (see `backlog/tasks/`): the plan begins with the SETUP preamble, then
numbered, literal steps. Assume the implementer follows directions exactly but
isn't clever — name exact files, exact functions, and exact commands. Always use
the Nix shell: prefix commands with `nix develop -c` (e.g.
`nix develop -c cargo test -p gql-core`, `nix develop -c cargo clippy`). Never
change pinned dependency versions.

SETUP preamble to reuse verbatim at the top of every plan:
> SETUP (read first): This is a Rust+WebAssembly core (crates/gql-core) with a
> TypeScript/React web app (web/). ALL commands must run inside the Nix dev
> shell: either run 'direnv allow' once, or prefix every command with
> 'nix develop -c'. Work from the repository root unless told otherwise. Do not
> change pinned dependency versions.

Template for creating a ticket:

```bash
backlog task create "Fix: <short imperative summary>" \
  -m <milestone-id> \
  --labels review-followup \
  --priority high \
  --ordinal 100 \
  --depends-on <reviewed TASK_ID> \
  --desc "Found while reviewing <TASK_ID> (<file:line>). <What is wrong and why it matters, referencing the axis: Correct/Concise/Clear/Organized/Resilient>." \
  --ac "<observable condition #1 that proves the fix>" \
  --ac "<observable condition #2>" \
  --ac "nix develop -c cargo test -p gql-core passes" \
  --plan "SETUP (read first): ...<preamble>...

1. <exact first step: file + function>
2. <exact change>
3. <test to add/adjust and how to assert it>
4. Run: nix develop -c cargo test -p gql-core (and clippy/fmt as relevant)"
```

Acceptance criteria must be **observable and checkable** (a passing test, a
specific behaviour, a clippy-clean file) — never "code looks better". The last AC
should always be the relevant test/lint command passing.

After creating tickets, sanity-check the wiring:
```bash
backlog sequence list --plain     # confirm new fix tickets are in Sequence 1
```

---

## Step 5 — Report back

Give the user a concise report:

- **Reviewed:** the `TASK_ID`s and one line each on overall quality.
- **Findings:** grouped by severity, each with `file:line` and the axis it
  violates. Include nits here (not as tickets).
- **Tickets filed:** the new `task-<id>`s, their titles, deps, and which reviewed
  task each traces back to. State explicitly that they're in Sequence 1 and will
  be picked up on pi's next round (or, if you blocked a future task, say which).
- **Verdict:** is pi on track, or should the loop be paused until the
  review-followup tickets are cleared? Recommend a course of action.

Do not commit anything yourself — the new ticket files are created by the
`backlog` CLI; leave staging/committing to the user or to pi's normal flow.
