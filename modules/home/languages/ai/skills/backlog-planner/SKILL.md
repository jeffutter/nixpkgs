---
name: backlog-planner
description: Autonomous planning skill for tickets (backlog). Use when planning implementation for a ticket (TASK-xxx). Spawns research subagents, analyzes dependencies, creates sub-tickets for discrete work, and writes detailed implementation plans.
---

# Ticket Autonomous Planner

Plan a ticket by researching the codebase, analyzing dependencies, and creating actionable implementation plans.

## Task Hierarchy

Tickets use a three-level hierarchy:

```
Epic → Feature → Task
```

- **Epic:** Large initiatives spanning multiple features. When planning an Epic, break it into Features.
- **Feature:** Discrete, shippable capabilities. When planning a Feature, it may break into Tasks if granularity is discovered during research.
- **Task:** Atomic units of work. Tasks should be small enough to complete in a focused session.

When creating sub-tickets:
- Epic children are typically Features (use `-l feature`)
- Feature children are typically Tasks (use `-l task`)

### Dependency Direction

**Children block their parents.** Work flows bottom-up:

```
Task (do first) ──blocks──► Feature ──blocks──► Epic (complete last)
```

- An Epic cannot be started until its Features are planned
- An Epic cannot be completed until all its Features are done
- A Feature cannot be started until its Tasks are planned
- A Feature cannot be completed until all its Tasks are done

When you create a sub-ticket, the **parent depends on the child**:
```bash
backlog task edit <parent_id> --dep <child_id>
```

This ensures leaf tasks surface first as ready work—the actual work to execute.

## Invocation

```
/backlog-planner <ticket_id>
```

Example: `/backlog-planner TASK-42`

## Process Overview

Execute these phases sequentially. Do not ask for user confirmation between phases.

```
Phase 0: Prerequisites  →  Phase 1: Research  →  Phase 2: Plan  →  Phase 3: Review
   (check blockers)         (parallel agents)     (create tickets)   (validate)
```

---

## Phase 0: Prerequisites

**Goal:** Ensure the ticket is ready for planning.

1. Fetch ticket details:
   ```bash
   backlog task <ticket_id> --plain
   ```

2. Check for unplanned child tickets:
   ```bash
   backlog task list -s "To Do" --plain
   ```

   Review the output and cross-reference with the ticket's dependencies. Filter for tickets that:
   - Have this ticket as a parent (check dependencies)
   - Do NOT have the `planned` label

3. **If unplanned children exist:**
   - List them clearly
   - Exit with message: "Plan these tickets first: [list of ticket IDs]"
   - Do not proceed

4. **If no blockers:** Continue to Phase 1.

---

## Phase 1: Research

**Goal:** Gather the context needed to plan — no more, no less.

### Step 1: Analyze Dependencies Inline

Dependency analysis is metadata lookup, not codebase research — run the CLI directly instead of spawning a subagent:

1. Run `backlog task <ticket_id> --plain` and note the Dependencies field
2. For each upstream dependency, run `backlog task <dep_id> --plain` and read its Implementation Plan and status
3. Scan ticket listings for downstream dependents — tickets whose Dependencies reference this one
4. Record sequencing constraints

### Step 2: Spawn Research Subagents

Delegate codebase research to parallel subagents via the Task tool with `subagent_type: "Explore"`. **Choose the count based on the ticket — no prescribed number.** Spawn exactly as many as the work demands, and no more.

**Default to spawning subagents.** The plan produced here has to hold up during execution, so prefer thorough parallel research over inline shortcuts. Even moderate-sized tickets benefit from dedicated agents per dimension. Skip subagents entirely only when the ticket is truly trivial — planning effort matches implementation effort (e.g. a one-line fix, a rename, a config tweak). For sprawling Epics, several focused agents in parallel return better results than one catch-all.

Base the count and scope on:
- **Ticket scope** — a focused change may warrant a single agent; a cross-cutting Epic may need several
- **Which dimensions actually apply** — not every ticket involves data, APIs, architecture, and risk
- **Topic coupling** — two dimensions that share files or patterns are cheaper investigated by one agent than two
- **Unique areas** — if the ticket hinges on a concern outside the catalogue below, spawn an agent for it anyway

### Research Dimensions

Non-exhaustive catalogue — mix, combine, or omit based on the ticket, and **add your own dimensions when the ticket demands it**. If the work hinges on an area not listed below (e.g. migration safety, observability, auth, i18n, accessibility, a specific library's behavior), spawn a focused agent for it. When two dimensions share files or patterns, fold them into a single agent rather than spawning two.

**Architecture** — for tickets affecting system structure.
- Investigate: primary modules and components involved, existing patterns for similar features, data flow and interfaces between them, architectural constraints or conventions in the project
- Return: key files and their responsibilities, patterns to follow, integration points, recommended architectural approach

**Implementation** — for tickets with clear technical work.
- Investigate: existing code that does similar work, utility functions/helpers/patterns already available to reuse, relevant tests that specify behavior, edge cases handled in similar code
- Return: reference implementations, reusable components, test patterns to follow, potential edge cases

**Data / API surface** — for tickets involving data models or external interfaces.
- Investigate: relevant data models and schemas, existing API patterns (endpoints, payload shapes, error conventions), validation rules and constraints, external service integrations
- Return: data models involved, API conventions to follow, validation requirements, external dependencies

**Risk & constraints** — for tickets with uncertainty or potential issues.
- Investigate: potential breaking changes to callers or consumers, performance implications, security considerations, technical debt that may complicate the work
- Return: breaking change risks, performance concerns, security checklist items, tech debt interactions

### Prompt Construction

Each agent prompt should:
- State what to investigate and how it informs the ticket
- Request concrete artifacts (file paths, patterns, constraints) — not prose summaries
- Stay scoped — broad prompts return shallow answers

### Step 3: Synthesize

Wait for all agents to return. Reconcile their findings into a coherent picture before planning. If a gap blocks planning, spawn a targeted follow-up agent — don't guess.

---

## Phase 2: Plan Orchestration

**Goal:** Create actionable plans and sub-tickets for discrete work.

### Step 1: Identify Discrete Units of Work

Review the research findings and identify work that:
- Can ship independently without breaking the application
- Represents an incremental improvement
- Has clear boundaries and acceptance criteria

**Criteria for creating a sub-ticket:**
- The work is independently testable
- It produces a meaningful, shippable increment
- It can be completed in a focused session
- Other work depends on it completing first

**Do NOT create sub-tickets for:**
- Trivial changes (under 20 lines)
- Tightly coupled changes that must ship together
- Work that only makes sense in the context of the whole

### Step 2: Create Sub-Tickets

For each discrete unit of work:

1. **Create the ticket:**
   ```bash
   backlog task create "<clear, action-oriented title>" --priority <high|medium|low> -p <parent_ticket_id> -d "<brief description>"
   ```

   Optionally label with the hierarchy level:
   - Planning an Epic → label children as features (`-l feature`)
   - Planning a Feature → label children as tasks (`-l task`)

2. **Set the dependency** (parent depends on child—parent cannot complete until child is done):
   ```bash
   backlog task edit <parent_ticket_id> --dep <new_ticket_id>
   ```

   This makes the parent depend on the child. The parent Epic/Feature remains blocked until all children are complete.

3. **Decide whether to add a plan:**

   **Add plan and mark planned** if the sub-ticket is trivial:
   - Under ~20 lines of changes
   - Single file or tightly scoped
   - Clear implementation path with no ambiguity
   - No further research needed

   For trivial sub-tickets, add plan and label when creating:
   ```bash
   backlog task create "<title>" --priority <high|medium|low> -p <parent_ticket_id> -d "<brief description>" --plan "<implementation plan>" -l planned
   ```

   **Leave unplanned** if the sub-ticket requires its own planning session:
   - Multiple files or components involved
   - Non-obvious implementation approach
   - Would benefit from focused research
   - Any uncertainty about the right approach

   For non-trivial sub-tickets:
   - Write only a clear description (already done in step 1)
   - Do NOT add plan or planned label
   - It will be planned in a dedicated `/backlog-planner` session later

### Step 3: Write Main Ticket Plan

After creating sub-tickets, write the implementation plan for the main ticket:

```bash
backlog task edit <ticket_id> --plan "<orchestration plan>"
```

The main ticket's plan should include:
- Overview of the approach
- How sub-tickets fit together
- Integration and verification steps
- Final testing and validation
- Any remaining work not captured in sub-tickets

### Step 4: Mark Main Ticket as Planned

```bash
backlog task edit <ticket_id> --remove-label needs-plan --add-label planned
```

---

## Phase 3: Review

**Goal:** Validate the plan is complete and actionable.

### Review Checklist

**For the main ticket:**

1. **Clarity:** Is the orchestration plan clear?
   - Does it explain how sub-tickets fit together?
   - Are integration steps documented?
   - Is the "why" behind the breakdown explained?

2. **Completeness:** When all sub-tickets are done, is the original goal achieved?
   - Do the sub-tickets cover all identified work?
   - Are there gaps between tickets?
   - Is the final integration path clear?

**For sub-tickets:**

1. **Descriptions:** Can someone understand the scope from the description alone?
   - Is the work clearly bounded?
   - Are acceptance criteria implied or explicit?

2. **Planning status:** Is each sub-ticket correctly categorized?
   - Trivial tickets: Have plan AND planned label
   - Non-trivial tickets: Have description only, NO plan, NO planned label

3. **Dependencies:** Are blocking relationships correct?
   - Does the execution order make sense?
   - Are there missing dependencies?

### Make Corrections

If issues are found, use `backlog task edit <ticket_id>` with the appropriate flags to make corrections.

### Final Summary

Output a summary:
- Main ticket ID, title, and type (Epic/Feature/Task)
- List of sub-tickets created with their status:
  - `[planned]` - trivial, ready for execution
  - `[unplanned]` - requires `/backlog-planner` before execution
- Recommended execution order
- Next steps (which tickets need planning, which are ready)
- Any risks or considerations noted

---

## Examples

### Example: Simple Enhancement

Input: `/backlog-planner TASK-42` where TASK-42 is "Add retry logic to API client"

Phase 1:
- Inline dependency check via `backlog task` commands
- One Explore agent covering existing retry patterns (Architecture and Implementation collapse into a single scope)

Phase 2:
- No sub-tickets (single focused change)
- Writes detailed plan to TASK-42

