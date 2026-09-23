---
name: review-pi-work
description: >-
  Audit the last N completed backlog tickets that the autonomous `pi` loop
  finished, judging the work on Correctness, Conciseness, Clarity, Organization,
  and Resilience. Small, mechanical findings against an unpushed commit get
  patched directly as a `git commit --fixup`; everything else gets a
  tightly-scoped backlog ticket with a thorough plan so the next `pi` round
  course-corrects. Invoke when checking in on pi's progress, e.g. "review pi's
  last few tickets".
---

# Review pi's Work

Run this when the user asks to check pi's recent tickets. Audit the work pi committed. Steer pi mainly by filing backlog tickets. Edit code yourself only for fixups that pass step 5. End with a report, zero or more committed tickets, and zero or more fixup commits. Leave the working tree clean: ralph's autosquash runs `git rebase --autosquash` after each review, and it refuses to run on a dirty tree.

Arguments: `$ARGUMENTS` holds a number N of tickets to review, or specific task IDs (e.g. `task-7 task-8`). With specific IDs, review exactly those. With neither, set N to 5.

SETUP preamble, used verbatim in every ticket plan:

    SETUP (read first): This is a Rust+WebAssembly core (crates/gql-core) with a
    TypeScript/React web app (web/). ALL commands must run inside the Nix dev
    shell: either run 'direnv allow' once, or prefix every command with
    'nix develop -c'. Work from the repository root unless told otherwise. Do not
    change pinned dependency versions.

## Steps

1. Find task commits by their `Task-Id:` trailer. Subject lines vary, so match the trailer only.
   ```bash
   git log --oneline -n 40 --grep='^Task-Id: ' --extended-regexp
   ```
   Run `git show <sha>` on each match to read its task ID. Take the first N distinct task IDs.

2. List Done tasks with `backlog task list -s Done --plain`. For each Done task with no matching commit, file a ticket now:
   - `--priority high`.
   - Description: the ticket's record and the repository disagree.
   - Acceptance criterion: check the working tree for uncommitted files matching the original plan before redoing any work.
   - Commit the ticket file as in step 8.

3. For each task ID, collect:
   - Intent: run `backlog task <TASK_ID> --plain`. Read Description, Acceptance Criteria (note unchecked ones), Implementation Plan, Definition of Done, and Final Summary.
   - Change: run `git show --stat <sha>`, then `git show <sha>`.
   - Context: for each suspicious hunk, read the whole current file.

4. Run the specialist skills and merge their findings into your own review in your own words:
   - `/rust-best-practices` on the changed Rust files, for every ticket that touched `crates/**` or `*.rs`.
   - `/code-review` on every diff, including `web/`.

5. Judge each ticket on five axes. Cite `file:line` for each finding. Apply the design philosophy in the project `CLAUDE.md`.
   - Correct: code satisfies every acceptance criterion. Tests assert real behaviour and cover success, error, and edge cases. No criterion is checked off without matching code or tests. The JS-Rust boundary passes JSON strings and returns project DTOs, never apollo-federation internals. Output is deterministic for a given `seed`. Errors are returned as values.
   - Concise: no dead code, speculative abstraction, pass-through layers, or duplication. An abstraction whose value you cannot state is a finding. Prefer fewer, deeper modules.
   - Clear: names create the right mental image. Comments give reasons and precision (units, invariants, null meaning), not restated code. A reader can use each function from its signature and doc alone.
   - Organized: deep modules with simple interfaces. No format, policy, or algorithm knowledge duplicated across modules. Changing one layer does not force changes in another.
   - Resilient: no `panic!`, `unwrap()`, or `expect()` outside tests. Edge cases are handled or designed away. Failure is safe where the design says so (e.g. composition failure keeps the last good supergraph). Inputs are validated.

   Assign each finding a severity:
   - blocker: incorrect behaviour, broken invariant, missing or failing tests, a panic reachable from the WASM boundary.
   - should-fix: a quality problem with real cost, e.g. a leaky module, a misleading public name, an untested error path.
   - nit: minor. Report it only; file no ticket.

6. For each blocker or should-fix finding, apply a fixup only if all three hold. Otherwise go to step 7.
   - Small: a few lines in one function or file, e.g. a one-line fix, a rename, a missing guard, a wrong flag or config value. A finding with design ambiguity or a tradeoff to explain fails this test.
   - Unpushed: `git merge-base --is-ancestor <sha> origin/<default-branch> && echo PUSHED || echo UNPUSHED` prints `UNPUSHED`.
   - Mechanical: it corrects something the original commit got wrong against its own stated intent, with no new behaviour.

   To apply a fixup:
   1. Make the minimal code change.
   2. Run the tests, typecheck, and lint the original ticket's acceptance criteria required for the touched files.
   3. Run `backlog task edit <TASK_ID> --append-notes "Fixup applied post-review: <what and why>."`
   4. Stage the changed code files and the ticket file by name, then commit:
      ```bash
      git add <file1> <file2> ... backlog/tasks/<task-id>.md
      git commit --fixup=<sha>
      ```
   Leave the fixup commit as is; pi's ralph loop squashes it. Do not use `git add -A`, `git add .`, `--amend`, or a manual squash here.

7. For each remaining blocker or should-fix finding, create one ticket per finding. Split unrelated findings into separate tickets.
   ```bash
   backlog task create "Fix: <short imperative summary>" \
     -m <milestone of the reviewed task> \
     --labels review-followup \
     --priority high \
     --ordinal 100 \
     --depends-on <reviewed TASK_ID> \
     --desc "Found while reviewing <TASK_ID> (<file:line>). <What is wrong, why it matters, and which axis it violates>." \
     --ac "<observable condition #1 that proves the fix>" \
     --ac "<observable condition #2>" \
     --ac "nix develop -c cargo test -p gql-core passes" \
     --plan "<SETUP preamble>

   1. <exact first step: file + function>
   2. <exact change>
   3. <test to add or adjust, and what it asserts>
   4. Run: nix develop -c cargo test -p gql-core (plus clippy/fmt as relevant)"
   ```
   - Use ordinals 100, 110, 120, and so on for successive tickets.
   - Write the plan as numbered literal steps naming exact files, functions, and commands. Match the style of existing tickets in `backlog/tasks/`.
   - Prefix every command with `nix develop -c`. Keep pinned dependency versions unchanged.
   - Write acceptance criteria as checkable facts: a passing test, a specific behaviour, a clippy-clean file. Make the last criterion the relevant test or lint command passing.
   - When a not-started task builds on the broken code, add the fix as its dependency: `backlog task edit <FUTURE_ID> --depends-on <NEW_FIX_ID>`, keeping its existing dependencies.

8. Run `backlog sequence list --plain` and confirm each new ticket appears in Sequence 1. Then commit every ticket file created this run:
   ```bash
   git add backlog/tasks/task-<new-id>.md   # one per ticket
   git commit -m "chore: file review-followup ticket(s) from review of <reviewed TASK_IDs>"
   ```

9. Report to the user:
   - Reviewed: each task ID with one line on overall quality.
   - Findings: grouped by severity, each with `file:line` and its axis. Include nits.
   - Fixups applied: the target `<sha>`, a one-line description, and the ticket whose notes reference it. List these apart from filed tickets.
   - Tickets filed: each new task ID, title, dependencies, and source task. State they are in Sequence 1 for pi's next round, and name any future task you blocked.
   - Verdict: pi is on track, or pause the loop until the review-followup tickets are done. Recommend a next action.
