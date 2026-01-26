---
name: beads-planner
description: Autonomous planning skill for beads tickets. Use when planning implementation for a beads ticket (bd-xxx). Spawns research subagents, analyzes dependencies, creates sub-tickets for discrete work, and writes detailed implementation plans.
---

# Beads Autonomous Planner

Plan a beads ticket by researching the codebase, analyzing dependencies, and creating actionable implementation plans.

## Invocation

```
/beads-planner <ticket_id>
```

Example: `/beads-planner bd-42`

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
   bd show <ticket_id> --json
   ```

2. Check for unplanned child tickets:
   ```bash
   bd list --status open --json
   ```

   Filter for tickets that:
   - Have this ticket as a parent (check dependencies)
   - Do NOT have the `planned` label

3. **If unplanned children exist:**
   - List them clearly
   - Exit with message: "Plan these tickets first: [list of ticket IDs]"
   - Do not proceed

4. **If no blockers:** Continue to Phase 1.

---

## Phase 1: Research

**Goal:** Gather comprehensive context through parallel investigation.

Spawn 2-5 subagents based on ticket complexity. Use the Task tool with `subagent_type: "Explore"`.

### Required Agent: Dependency Analyzer

Always spawn this agent:

```
Analyze dependencies for ticket <ticket_id>:

1. Run `bd dep tree <ticket_id>` to see the dependency structure
2. Find tickets this ticket depends on (blocked-by relationships)
3. Find tickets that depend on this ticket (blocking relationships)
4. For each dependency:
   - Run `bd show <dep_id> --json`
   - Understand their plans (design field)
   - Note their status and priority

Return:
- Summary of upstream dependencies and their plans
- Summary of downstream dependents and implications
- Any sequencing constraints discovered
```

### Additional Research Agents

Spawn 1-4 more agents based on ticket scope. Choose from:

**Architecture Agent** - For tickets affecting system structure:
```
Research the architectural context for: <ticket description>

1. Identify the primary modules/components involved
2. Find existing patterns for similar features
3. Document the data flow and interfaces
4. Note any architectural constraints or conventions

Return:
- Key files and their responsibilities
- Existing patterns to follow
- Integration points
- Recommended architectural approach
```

**Implementation Agent** - For tickets with clear technical work:
```
Research implementation details for: <ticket description>

1. Find existing code that does similar work
2. Identify utility functions, helpers, or patterns to reuse
3. Check for relevant tests as specification
4. Note any edge cases in similar code

Return:
- Reference implementations
- Reusable components
- Test patterns to follow
- Potential edge cases
```

**Data/API Agent** - For tickets involving data or external interfaces:
```
Research data and API context for: <ticket description>

1. Identify relevant data models or schemas
2. Find existing API patterns (endpoints, payloads)
3. Check for validation rules and constraints
4. Document any external service integrations

Return:
- Data models involved
- API conventions to follow
- Validation requirements
- External dependencies
```

**Risk Agent** - For tickets with uncertainty or potential issues:
```
Analyze risks and constraints for: <ticket description>

1. Identify potential breaking changes
2. Check for performance implications
3. Note security considerations
4. Find areas of technical debt that may complicate work

Return:
- Breaking change risks
- Performance concerns
- Security checklist items
- Technical debt interactions
```

### Collecting Results

Wait for all agents to complete. Synthesize their findings into a coherent understanding before proceeding.

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

1. Create the ticket:
   ```bash
   bd create "<clear, action-oriented title>" -t task -p <priority> -d "<brief description>" --json
   ```

2. Set the dependency (parent ticket is blocked by this new ticket):
   ```bash
   bd dep add <parent_ticket_id> --blocked-by <new_ticket_id>
   ```

3. Write the implementation plan:
   ```bash
   bd update <new_ticket_id> --design "<detailed implementation plan>"
   ```

   The design should include:
   - Specific files to modify
   - Key implementation steps
   - Edge cases to handle
   - Testing approach

4. Mark as planned:
   ```bash
   bd label add <new_ticket_id> planned
   ```

### Step 3: Write Main Ticket Plan

After creating sub-tickets, write the orchestration plan for the main ticket:

```bash
bd update <ticket_id> --design "<orchestration plan>"
```

The main ticket's design should include:
- Overview of the approach
- How sub-tickets fit together
- Integration and verification steps
- Final testing and validation
- Any remaining work not captured in sub-tickets

### Step 4: Mark Main Ticket as Planned

```bash
bd label add <ticket_id> planned
```

---

## Phase 3: Review

**Goal:** Validate the plan is complete and actionable.

### Review Checklist

For each ticket (main + sub-tickets), verify:

1. **Clarity:** Can someone unfamiliar with the context understand what to do?
   - Are specific files and functions named?
   - Are steps concrete and actionable?
   - Is the "why" explained where non-obvious?

2. **Completeness:** When all tickets are done, is the original goal achieved?
   - Do the sub-tickets cover all identified work?
   - Are there gaps between tickets?
   - Is the integration path clear?

3. **Shippability:** Can each ticket ship independently?
   - Does it produce a working state?
   - Are there hidden dependencies?
   - Is rollback possible?

### Make Corrections

If issues are found:

```bash
bd update <ticket_id> --design "<corrected plan>"
```

### Final Summary

Output a summary:
- Main ticket ID and title
- List of sub-tickets created (ID, title, brief description)
- Recommended execution order
- Any risks or considerations noted

---

## Examples

### Example: Simple Enhancement

Input: `/beads-planner bd-42` where bd-42 is "Add retry logic to API client"

Phase 1 spawns:
- Dependency analyzer (required)
- Implementation agent (find existing retry patterns)

Phase 2:
- No sub-tickets (single focused change)
- Writes detailed plan to bd-42

Output:
```
Planned bd-42: Add retry logic to API client

No sub-tickets needed - this is a focused change.

Design written to ticket covering:
- Existing retry patterns in lib/http/client.ex
- Exponential backoff implementation
- Configuration options
- Test cases for retry scenarios
```

### Example: Complex Feature

Input: `/beads-planner bd-100` where bd-100 is "Implement user notification preferences"

Phase 1 spawns:
- Dependency analyzer (required)
- Architecture agent (new feature area)
- Data agent (new schema needed)
- Implementation agent (UI patterns)

Phase 2 creates:
- bd-101: Add notification_preferences schema and migrations
- bd-102: Create preferences API endpoints
- bd-103: Build preferences UI component
- bd-104: Integrate preferences with notification dispatch

Each sub-ticket has detailed implementation plans.

Output:
```
Planned bd-100: Implement user notification preferences

Created 4 sub-tickets:
- bd-101: Add notification_preferences schema (blocked-by: none)
- bd-102: Create preferences API endpoints (blocked-by: bd-101)
- bd-103: Build preferences UI component (blocked-by: bd-102)
- bd-104: Integrate with notification dispatch (blocked-by: bd-102, bd-103)

Execution order: bd-101 → bd-102 → [bd-103, bd-104 in parallel]

Main ticket bd-100 will track integration and final verification.
```

---

## Beads Commands Reference

```bash
# View ticket
bd show <id> --json

# Create ticket
bd create "<title>" -t <type> -p <priority> -d "<description>" --json

# Update ticket design
bd update <id> --design "<plan content>"

# Add dependency
bd dep add <parent_id> --blocked-by <child_id>

# View dependency tree
bd dep tree <id>

# Add label
bd label add <id> <label>

# List tickets
bd list --status open --json
```

---

## Constraints

- **No user prompts:** Execute autonomously. Do not use AskUserQuestion.
- **No code changes:** Research and plan only. Never edit application files.
- **Beads only:** All ticket operations through `bd` commands.
- **Read operations:** Use Bash only for read-only operations (ls, git log, git diff, find).
