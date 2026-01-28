---
name: beads-planner
description: Autonomous planning skill for beads tickets. Use when planning implementation for a beads ticket (bd-xxx). Spawns research subagents, analyzes dependencies, creates sub-tickets for discrete work, and writes detailed implementation plans.
---

# Beads Autonomous Planner

Plan a beads ticket by researching the codebase, analyzing dependencies, and creating actionable implementation plans.

## Task Hierarchy

Beads uses a three-level hierarchy:

```
Epic → Feature → Task
```

- **Epic:** Large initiatives spanning multiple features. When planning an Epic, break it into Features.
- **Feature:** Discrete, shippable capabilities. When planning a Feature, it may break into Tasks if granularity is discovered during research.
- **Task:** Atomic units of work. Tasks should be small enough to complete in a focused session.

When creating sub-tickets:
- Epic children are typically Features (use `-t feature`)
- Feature children are typically Tasks (use `-t task`)

### Dependency Direction

**Children block their parents.** Work flows bottom-up:

```
Task (do first) ──blocks──► Feature ──blocks──► Epic (complete last)
```

- An Epic cannot be started until its Features are planned
- An Epic cannot be completed until all its Features are done
- A Feature cannot be started until its Tasks are planned
- A Feature cannot be completed until all its Tasks are done

When you create a sub-ticket, the **parent becomes blocked by the child**:
```bash
bd dep add <parent_id> --blocked-by <child_id>
```

This ensures `bd ready` surfaces leaf tasks first—the actual work to execute.

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

1. **Create the ticket:**
   ```bash
   bd create "<clear, action-oriented title>" -t <task or feature> -p <priority> --parent <parent_ticket_id> -d "<brief description>" --json
   ```

   Choose the type based on hierarchy:
   - Planning an Epic → create Features (`-t feature`)
   - Planning a Feature → create Tasks (`-t task`)

2. **Set the dependency** (child blocks parent—parent cannot complete until child is done):
   ```bash
   bd dep add <parent_ticket_id> --blocked-by <new_ticket_id>
   ```

   This makes the child a blocker. The parent Epic/Feature remains blocked until all children are complete.

3. **Decide whether to add a design:**

   **Add design and mark planned** if the sub-ticket is trivial:
   - Under ~20 lines of changes
   - Single file or tightly scoped
   - Clear implementation path with no ambiguity
   - No further research needed

   For trivial sub-tickets (use `/tmp/claude/` for multi-line plans):
   ```bash
   cat > /tmp/claude/design.md << 'EOF'
   <brief implementation plan>
   EOF
   bd update <new_ticket_id> --design "$(cat /tmp/claude/design.md)"
   bd label add <new_ticket_id> planned
   ```

   **Leave unplanned** if the sub-ticket requires its own planning session:
   - Multiple files or components involved
   - Non-obvious implementation approach
   - Would benefit from focused research
   - Any uncertainty about the right approach

   For non-trivial sub-tickets:
   - Write only a clear description (already done in step 1)
   - Do NOT add design or planned label
   - It will be planned in a dedicated `/beads-planner` session later 

### Step 3: Write Main Ticket Plan

After creating sub-tickets, write the orchestration plan for the main ticket:

```bash
bd update <ticket_id> --design "<orchestration plan>"
```

Note: Claude has problems passing the plan as a heredoc. Write it to `/tmp/claude/` (pre-allowed, no permission prompt) and pass it with shell substitution:
```bash
# Write plan to temp file
cat > /tmp/claude/plan.md << 'EOF'
<plan content here>
EOF

# Update ticket with plan
bd update <ticket_id> --design "$(cat /tmp/claude/plan.md)"
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
   - Trivial tickets: Have design AND planned label
   - Non-trivial tickets: Have description only, NO design, NO planned label

3. **Dependencies:** Are blocking relationships correct?
   - Does the execution order make sense?
   - Are there missing dependencies?

### Make Corrections

If issues are found:

```bash
bd update <ticket_id> --design "<corrected plan>"
```

### Final Summary

Output a summary:
- Main ticket ID, title, and type (Epic/Feature/Task)
- List of sub-tickets created with their status:
  - `[planned]` - trivial, ready for execution
  - `[unplanned]` - requires `/beads-planner` before execution
- Recommended execution order
- Next steps (which tickets need planning, which are ready)
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

### Example: Planning an Epic

Input: `/beads-planner bd-100` where bd-100 is Epic "Implement user notification system"

Phase 1 spawns:
- Dependency analyzer (required)
- Architecture agent (new feature area)
- Data agent (new schema needed)
- Implementation agent (existing patterns)

Phase 2 creates Features:
- bd-101: User notification preferences (Feature) - **unplanned** (needs own research)
- bd-102: Email notification delivery (Feature) - **unplanned** (complex integration)
- bd-103: In-app notification UI (Feature) - **unplanned** (UI patterns TBD)

Output:
```
Planned bd-100: Implement user notification system (Epic)

Created 3 Features (all require separate planning):
- bd-101: User notification preferences [unplanned]
- bd-102: Email notification delivery [unplanned]
- bd-103: In-app notification UI [unplanned]

Execution order: bd-101 → bd-102 → bd-103

Next steps: Run /beads-planner on each Feature before execution.
```

### Example: Planning a Feature

Input: `/beads-planner bd-101` where bd-101 is Feature "User notification preferences"

Phase 1 spawns:
- Dependency analyzer (required)
- Data agent (schema design)
- Implementation agent (API patterns)

Phase 2 creates Tasks:
- bd-110: Add notification_preferences schema - **planned** (trivial migration)
- bd-111: Create preferences API endpoints - **unplanned** (needs detailed research)
- bd-112: Build preferences UI component - **unplanned** (UI patterns to determine)

Output:
```
Planned bd-101: User notification preferences (Feature)

Created 3 Tasks:
- bd-110: Add notification_preferences schema [planned - trivial]
- bd-111: Create preferences API endpoints [unplanned]
- bd-112: Build preferences UI component [unplanned]

Execution order: bd-110 → bd-111 → bd-112

bd-110 is ready for immediate execution.
bd-111, bd-112 need /beads-planner before execution.
```

---

## Beads Commands Reference

```bash
# View ticket
bd show <id> --json

# Create ticket
bd create "<title>" -t <type> -p <priority> --parent <parent id> -d "<description>" --json

# Update ticket design
bd update <id> --design "<plan content>"

# Add dependency (child blocks parent)
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
