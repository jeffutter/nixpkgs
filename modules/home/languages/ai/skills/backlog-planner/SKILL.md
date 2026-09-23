---
name: backlog-planner
description: Autonomous planning skill for tickets (backlog). Use when planning implementation for a ticket (TASK-xxx). Spawns research subagents, analyzes dependencies, creates sub-tickets for discrete work, and writes detailed implementation plans.
---

# Backlog Planner

Use this skill when the user runs `/backlog-planner <ticket_id>` or asks you to plan a backlog ticket. The end state: the ticket carries an implementation plan and the `planned` label, each discrete unit of work is a sub-ticket, and you have printed a summary. Run every step in order without asking the user for confirmation.

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
   - If the ticket status is Done, or HEAD already contains the deliverable: report ALREADY_SHIPPED with the SHA that landed it, then stop.

4. Run `backlog task list -s "To Do" --plain`. Find tickets that have this ticket as parent and lack the `planned` label.
   - If any exist: print "Plan these tickets first: <ticket IDs>", then stop.
   - If none exist: continue.

5. For each upstream dependency from step 1, run `backlog task <dep_id> --plain`. Record its status and Implementation Plan.

6. From the step 4 listing, find downstream tickets whose Dependencies include this ticket. Record the sequencing constraints from steps 5 and 6.

7. Choose research dimensions for the ticket:
   - Architecture: modules involved, existing patterns for similar features, data flow, interfaces, project conventions.
   - Implementation: similar existing code, reusable helpers, tests that specify behavior, edge cases.
   - Data and API surface: data models, schemas, endpoint and payload conventions, validation rules, external services.
   - Risk: breaking changes to callers, performance, security, tech debt in the affected code.
   - Add a dimension for any area the ticket hinges on outside this list, such as migration safety, auth, or a specific library.
   - Merge dimensions that share files or patterns into one agent.
   - Omit dimensions the ticket does not touch.

8. Spawn one Explore-type subagent per chosen dimension, all in parallel. Set the subagent type with the field your agent tool's schema declares.
   - Each prompt names what to investigate and how it informs the ticket.
   - Each prompt asks for file paths, patterns, and constraints, not prose summaries.
   - Keep each prompt to one dimension.
   - Skip subagents only for a one-line fix, a rename, or a config tweak. Research inline instead.

9. Wait for every agent to return. Reconcile their findings. If a gap blocks planning, spawn one targeted follow-up agent for that gap.

10. Split the work into sub-tickets. Make a sub-ticket for a unit that is independently testable, ships without breaking the application, fits one focused session, and has clear acceptance criteria. Keep in the parent plan:
    - Changes under 20 lines.
    - Tightly coupled changes that ship together.
    - Work that only makes sense as part of the whole.

11. Create each sub-ticket:
    - Trivial: `backlog task create "<action-oriented title>" --priority <high|medium|low> -p <ticket_id> -d "<description>" --plan "<implementation plan>" -l planned`
    - Non-trivial: `backlog task create "<action-oriented title>" --priority <high|medium|low> -p <ticket_id> -d "<description>"`. Leave out the plan and the `planned` label. A later `/backlog-planner` session plans it.
    - Add the hierarchy label (`-l feature` or `-l task`) to either command.

12. For each new sub-ticket, run `backlog task edit <ticket_id> --dep <new_ticket_id>`.

13. Run `git rev-parse HEAD` again. If it changed from step 2, re-read any source you plan to cite and update findings that moved.

14. Write the main plan with `backlog task edit <ticket_id> --plan "<plan>"`. The plan contains, in order:
    - First line: `Planned against <output of git rev-parse --short HEAD>`.
    - The overall approach.
    - How the sub-tickets fit together and why the work splits this way.
    - Integration and verification steps.
    - Final testing.
    - Remaining work not covered by a sub-ticket.

15. Run `backlog task edit <ticket_id> --remove-label needs-plan --add-label planned`.

16. Review the result by running `backlog task <id> --plain` on the main ticket and each sub-ticket. Check:
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
