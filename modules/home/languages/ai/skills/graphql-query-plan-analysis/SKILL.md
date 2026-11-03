---
name: graphql-query-plan-analysis
description: Work out what Apollo Router does for one federated operation under real variables - which fetches run, how many sequential levels, what each subgraph is asked to resolve, and which @requires pull data from another subgraph. Builds on `graphql-document-utils query plan`. Use when comparing the cost of a query with feature flags on vs off, explaining why a subgraph got slower or busier after a schema or client change, finding what a @requires drags into another subgraph's fetch, or counting fetches per subgraph for an operation.
---

# GraphQL query plan analysis

`graphql-document-utils query plan` prints the plan Apollo Router builds. This skill adds
three things the plan alone does not give you: evaluating the plan for real variables,
evaluating `@include`/`@skip` inside each subgraph operation, and listing `@requires`.
Read `graphql-document-utils skill` for the tool's own rules first.

## Inputs

- The supergraph SDL the router runs (for example from GraphOS, `rover supergraph fetch`, or
  a file the user gives). Use the deployed one; a local composition can plan differently.
- The operation document exactly as the client sends it. For a persisted query, take its
  `body` from the manifest in code. Do not print manifests: ids are 64-hex hashes.
- The variables the client sends, as JSON.

## Steps

1. Plan the operation in variable form, as JSON:

   ```sh
   graphql-document-utils query plan --json -s supergraph.graphql -q op.graphql > plan.json
   ```

   Do not inline variable values into the document to get a smaller plan. Router plans the
   variable form and branches at run time with `Condition` nodes; inlined literals give a
   different plan from the one production runs.

2. List the fetches for a variable set. Unlisted booleans count as false:

   ```sh
   python3 -I scripts/plan_fetches.py plan.json flagA=true flagB=false [--ops]
   ```

   Read: `L<n>` is the sequential level (fetches on the same level run in parallel),
   then subgraph, entity type for `_entities` fetches, operation size and response path.
   "sequential levels" is the critical path. "conditions defaulted to false" lists
   variables you did not pass; check each is meant to be false.

3. Compare what one subgraph is asked for under two variable sets:

   ```sh
   python3 -I scripts/subgraph_selection_diff.py plan.json SUBGRAPH a.json b.json [--entities] [--depth 6]
   ```

   The router forwards variables to subgraphs, so a root fetch's text is the same for every
   variable set; the `@include`/`@skip` inside it decide what the subgraph resolves. The
   script evaluates them, expands fragments, and prints total selected field paths, the
   largest differences, and paths only the second set selects. These are static counts:
   a list field counts once however many items it returns.

4. Find `@requires` that pull another subgraph's data into a fetch:

   ```sh
   python3 -I scripts/requires_list.py supergraph.graphql GRAPH_ENUM [--match 'fieldA|fieldB']
   ```

   `GRAPH_ENUM` is the `join__Graph` value, for example `BLUEPRINT`. A field that
   `@requires` a large selection makes the router fetch that selection from the owning
   subgraph first, usually inside the parent's existing fetch. New paths in step 3 that no
   client field asked for usually come from here.

5. Confirm against runtime before claiming cost. Static selections show what a subgraph must
   resolve, not how expensive it is. Check the subgraph's own span latency for the fetch
   (its operation name is `<Operation>__<subgraph>__<fetch index>`), and the router's entity
   cache hit rate for `_entities` fetches.

## Gotchas

- `@requires` copies are selected at their own paths (for example `card.event.richEvent`)
  next to the client's own selection (`card.richEvent`). The planner does not merge them,
  so the subgraph may resolve the same data twice.
- A fetch's index in its operation name (`__0`, `__118`) is its position in the plan, so it
  changes when the document or supergraph changes. Re-derive it; do not reuse old indexes.
- Run the scripts with `python3 -I` and keep them outside any directory holding downloaded
  files.
