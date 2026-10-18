---
name: backlog-planner
description: Autonomous planning skill for tickets (backlog). Use when planning implementation for a ticket (TASK-xxx). Spawns research subagents, analyzes dependencies, creates sub-tickets only when the ticket is definitely too big for one session, and writes detailed implementation plans.
---

# Backlog Planner

Use this skill when the user runs `/backlog-planner <ticket_id>` or asks you to plan a backlog ticket. The end state: the ticket carries an implementation plan and the `planned` label, any sub-tickets exist only if step 10 required them, and you have printed a summary. Run every step in order without asking the user for confirmation.

Hierarchy and dependency rules:

- Tickets nest as Epic, then Feature, then Task.
- Children of an Epic are Features. Label them `-l feature`.
- Children of a Feature are Tasks. Label them `-l task`.
- A parent depends on each of its children. Set this with `backlog task edit <parent_id> --dep <child_id>`.

A trivial sub-ticket meets all of these:

- Under 20 changed lines.
- One file, or one tightly scoped area.
- One obvious implementation path.
- No further research needed.

Any other sub-ticket is non-trivial.

## Steps

1. Run `backlog task <ticket_id> --plain`. Record its status, Dependencies field, and description.

2. Run `git rev-parse HEAD`. Record the SHA.

3. Check whether the work already shipped:
   - Run `git log --oneline -20` and `git log --grep="<ticket_id>" --oneline`.
   - Grep the code for the files, symbols, and routes the ticket names. Many commits carry the ticket ID only in a trailer.
   - If the ticket status is Done: report ALREADY_SHIPPED with the SHA that landed it, then stop.
   - If HEAD already contains the deliverable and the ticket is not Done, the record is stale and closing it is your deliverable: tick each acceptance criterion the shipped code meets with `backlog task edit <ticket_id> --check-ac <n>`, run `backlog task edit <ticket_id> --final-summary "SHIPPED by <full sha> - <what shipped where>"`, then `backlog task edit <ticket_id> -s Done`. Report ALREADY_SHIPPED with the SHA, then stop. Never leave an unshipped-status ticket at Needs Plan after confirming the work is in HEAD - the next planning pass re-runs on it forever.

4. Run `backlog task list -s "To Do" --plain`. Find tickets that have this ticket as parent and lack the `planned` label.
   - If any exist: print "Plan these tickets first: <ticket IDs>", then stop.
   - If none exist: continue.

5. For each upstream dependency from step 1, run `backlog task <dep_id> --plain`. Record its status and Implementation Plan.

6. From the step 4 listing, find downstream tickets whose Dependencies include this ticket. Record the sequencing constraints from steps 5 and 6.

7. Consider these dimensions yourself, whether or not you spawn agents. They are a checklist for the plan, not a list of agents to spawn:
   - Architecture: modules involved, existing patterns for similar features, data flow, interfaces, project conventions.
   - Implementation: similar existing code, reusable helpers, tests that specify behavior, edge cases.
   - Data and API surface: data models, schemas, endpoint and payload conventions, validation rules, external services.
   - Risk: breaking changes to callers, performance, security, tech debt in the affected code.
   - Add any area the ticket hinges on outside this list, such as migration safety, auth, or a specific library.
   - Skip dimensions the ticket does not touch.

8. Pick a research tier from the ticket's size. When unsure between two tiers, pick the smaller one.
   - Small: one area, an obvious path, a handful of files you can name from the ticket. Spawn no subagents. Research inline with grep and reads, covering the dimensions from step 7 as you go.
   - Medium: touches several areas or you cannot yet name the files. Spawn one or two Explore-type subagents, each covering the dimensions that share files or patterns.
   - Large: cross-cutting, high-risk, or hinges on an unfamiliar library, schema, or migration. Spawn up to 4 Explore-type subagents in parallel, one per group of dimensions that do not share files. Set the subagent type with the field your agent tool's schema declares.

   For every subagent prompt:
   - List 2 to 4 specific questions drawn from the ticket and its acceptance criteria, not "investigate the architecture".
   - Pass along what step 3 already found so the agent does not rediscover it.
   - Ask for file paths with line references, patterns, and constraints, not prose tours.
   - Cap the reply at about 100 lines.

9. Wait for every agent to return. Reconcile their findings. Spawn a follow-up agent only for a gap that blocks planning. Record any other gap as an open question or risk in the plan and continue.

10. Decide whether to split. The default is NO split: write the whole plan on the ticket itself and skip to step 13. Planning is slow, and every sub-ticket adds a planning pass, so a split must pay for itself. Split only when BOTH hold:
    - The ticket is definitely too big for one focused execution session. Doubt means it is not too big.
    - You can name at least two sub-units that are each independently shippable (testable, leaves the application working, clear acceptance criteria) without the other sub-units.

    Never split because:
    - The work touches several files or has several steps. Steps belong in the plan, not in tickets.
    - The ticket is a Task, or a Feature you could finish in one session.
    - Pieces are tightly coupled or only make sense together.
    - A piece is under 20 lines.
    - A piece is only "research", "tests", or "docs" for the main change. These stay in the plan.

    If you split, create the fewest sub-tickets that satisfy the rule above, and fold small or coupled pieces back into the parent plan.

11. Create each sub-ticket (only if step 10 chose to split):
    - Trivial: `backlog task create "<action-oriented title>" --priority <high|medium|low> -p <ticket_id> -d "<description>" --plan "<implementation plan>" -l planned`
    - Non-trivial: `backlog task create "<action-oriented title>" --priority <high|medium|low> -p <ticket_id> -d "<description>"`. Leave out the plan and the `planned` label. A later `/backlog-planner` session plans it.
    - Add the hierarchy label (`-l feature` or `-l task`) to either command.

12. For each new sub-ticket (none if not split), run `backlog task edit <ticket_id> --dep <new_ticket_id>`.

13. Run `git rev-parse HEAD` again. If it changed from step 2, re-read any source you plan to cite and update findings that moved.

14. Write the main plan with `backlog task edit <ticket_id> --plan "<plan>"`. The plan contains, in order:
    - First line: `Planned against <output of git rev-parse --short HEAD>`.
    - The overall approach.
    - If split: how the sub-tickets fit together and why the work is too big for one session. If not split: the concrete ordered steps, with file paths.
    - Integration and verification steps.
    - Final testing.
    - Remaining work not covered by a sub-ticket.

15. Run `backlog task edit <ticket_id> --remove-label needs-plan --add-label planned`.

16. Review the result by running `backlog task <id> --plain` on the main ticket and each sub-ticket (if any). Check:
    - Finishing every sub-ticket plus the main plan achieves the ticket's goal, with no gaps between sub-tickets.
    - Each sub-ticket description states its scope and acceptance criteria on its own.
    - Each trivial sub-ticket has a plan and the `planned` label.
    - Each non-trivial sub-ticket has a description only.
    - The dependencies produce a sensible execution order with none missing.
    - Fix each problem with `backlog task edit <id>` and the matching flag.

17. Print a summary:
    - Main ticket ID, title, and level (Epic, Feature, or Task).
    - Each sub-ticket, marked `[planned]` (ready to execute) or `[unplanned]` (needs `/backlog-planner`).
    - The recommended execution order.
    - Which tickets need planning next and which are ready.
    - Risks found during research.
