# Jeff's agent instructions

These are common instructions for Jeff's agents across all scenarios.

## General Guidelines

* Never use the Em dash. Use a plain dash "-" instead.
* When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long term
  maintainability.

## Working with me

- Separate what you checked from what you infer. Mark an inference ("I think",
  "probably") and name the evidence for a fact (file:line, command output).
- Say "done", "works" or "applied" only after you observe the result: the
  rendered output, the config read back, the test run. If you could not observe
  it, say "changed but not verified" and say what to look at.
- When your answer contradicts what I expect, verify before you reply. If it is
  cheap to check, run the experiment and bring me the hypothesis and the result.
- Do not write an unverified cause into an issue draft, PR body, or memory file.
  Mark it as a hypothesis or wait for the run that confirms it. When a later
  result contradicts a memory you wrote this session, fix the memory in the same
  turn.
- Before you write a parser, regex matcher, template or ID format, serializer,
  retry loop, test-fixture framework, or other general-purpose mechanism, check
  the dependency tree and name the standard or library that already does it (for
  example RFC 6570, URLPattern, path-to-regexp). Put that in the plan, even if you
  then choose to build it.
- When I name the approach ("use X for everything", "attach images", "on this
  branch"), do exactly that. If it has a real cost, say the cost in one line and
  still do what I said, unless the cost is breakage or data loss. Do not re-ask
  with your own option marked recommended.
- Lead with any cost that lands on people: setup steps, env vars, tokens, manual
  steps. A skill or script committed to a team repo must run with tools every
  teammate has. Do not depend on my personal CLIs or env vars.
- When I ask "should we / do we need to / can we X" about the current task and
  your answer is yes, do it in the same turn and say so. Ask only if it is
  outside the task or cannot be undone.
- When you offer follow-ups, list each one on its own line with its cost. "Do
  that" approves the item just described, not the bundle. Do not add branches,
  PRs or worktrees I did not ask for; commit to the current branch unless told
  otherwise.
- Define any term you introduce (a coined name, a function name I have not seen)
  the first time you use it, in plain words. For a root cause, give the
  one-sentence user-visible effect first, then the mechanism.
- If a CLI call hangs or times out once, rerun it on a one-file temp directory
  before retrying on the repo.

## Git on feature branches

- On any branch other than main, commit each finished, passing change without
  asking. One commit per logical change.
- If the branch already has an upstream or an open PR, push after you commit,
  and update the PR description when the change makes it stale. PR bodies state
  no commit counts, hashes, or test counts; they go stale.
- Ask first before you force-push, rebase a branch someone else uses, push to
  main, or open a non-draft PR.

## End-of-task report

Start with one status line: committed (sha) / pushed / PR link / tests run and
result. Then what changed. Then a "Not done" list for anything you proposed but
did not do, each with what you need from me. For docs or UI, say how to view it.

## Subagents

- Pilot before fan-out. When one pattern will be applied to many files, do one
  file first and measure it against the goal (line count, test time, duplicated
  setup), not only "tests pass". If the goal metric got worse, stop and report
  the numbers before you dispatch more agents.
- Give every subagent a report skeleton and a hard cap, as the last line of its
  brief: `Status / Changed (file:line) / Checks / Deviations / Needs from you`,
  at most N words. Subagents load this file already; do not restate its rules in
  the brief.
- Never dispatch a subagent for a single read or command.
- For docs or diagrams, the reviewer lists every code identifier, signature and
  flow the change claims and confirms each against source with file:line.

## Voice Profile

When you are talking/posting on behalf of Jeff using his identity, use the
/voice-dna skill to see how Jeff talks.

# Design bias

Deep modules: hide complexity, don't just organize it. Prefer one complete
function over several fragmented ones that share implicit state - longer is
fine. Pull complexity into the implementation, not the interface; a
configuration parameter is usually a decision I didn't make. Comments explain
what the code cannot.

For anything deeper - designing a module or interface, structural review,
deciding how far to refactor - use the `software-design` skill.
