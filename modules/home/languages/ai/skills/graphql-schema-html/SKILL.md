---
name: graphql-schema-html
description: Draw GraphQL schema figures as plain HTML and CSS - a containment tree of what a type holds, a diff of a schema change, a type-neighborhood card graph for one concept, an annotated UI wireframe pinned to types and fields, and a capability matrix. Use when the user asks to visualize, diagram, illustrate or explain a GraphQL schema, an SDUI page or component tree, or a schema change, in a standalone HTML page or as figures for another HTML document such as explain-diff-html.
---

# GraphQL schema figures in HTML

Produce figures that explain a GraphQL schema or a change to one. Every figure is plain HTML and CSS from `references/kit.html`. No images, no Mermaid, no CDN scripts. The result is one self-contained file that can be mailed or pasted.

## Modes

- **Standalone** (default): write one HTML page to `/tmp/YYYY-MM-DD-schema-<slug>.html` with today's date, a title, one or two sentences of prose before each figure, and a legend. Keep prose short; the figures carry the explanation.
- **Figures only**: when called from another skill or the user asks for figures to embed, return `<figure>` blocks and tell the caller to paste the `<style>` and `<script>` from `references/kit.html` once into their page. Do not write a file.

## Inputs

Accept any of: a path to `.graphql` SDL, SDL pasted in the prompt, a diff, branch or PR that touches SDL, or a prose description of a proposed change. Read the SDL before drawing. Never invent a type or field: every name in a figure must appear in the SDL or in the user's proposal. If the SDL is not available, say so and draw from the user's description, labeling the figure "proposed".

Do not assume any repository layout. Ask for the SDL path if it is not given and not obvious from the current directory.

## Procedure

1. **Find the question.** Name in one sentence what the reader should understand after looking at the figure, for example "what a page response holds" or "what this PR adds to `Cta`". Pick figures from the table below. One to three figures is normal. Do not draw every family.
2. **Slice the schema.** Start from a root type. Follow fields to object and interface types. Stop at scalars and enums. Default depth: 4 levels for the containment tree, 2 for neighborhood cards. Collapse what the question does not need:
   - A list of many sibling types: show two or three and a dimmed box reading "… N more".
   - An interface with many implementers: show the implementers the question is about, then "… N more".
   - A type already drawn once: draw a dimmed reference box with its name only.
   - In diff mode: collapse every unchanged subtree to a single label.
3. **Build the markup** from the pattern for each figure in `references/kit.html`. Copy the `<style>` block verbatim. Copy the `<script>` block only when a neighborhood card figure is present.
4. **Caption every figure** with "Figure N." and one sentence saying what to look at.
5. **Check** before finishing (see Checks).

## Figure selection

| Reader's question | Figure | Pattern in kit |
|---|---|---|
| What does type X hold? What is the page / screen / component tree? | Containment tree | `#containment-tree` |
| What does this change add, remove, deprecate or retype? | Containment tree in diff mode | `#diff-mode` |
| How does one concept relate to its neighbors? Cross-cutting types referenced from many places, `implements`, union membership | Neighborhood cards | `#neighborhood-cards` |
| Which part of the screen comes from which field? | Annotated wireframe | `#annotated-wireframe` |
| Which of many things support which of many options? | Capability matrix | `#capability-matrix` |

Start with the containment tree when the root is a page, section, screen, or layout type. Pair the annotated wireframe with a containment tree so pins and boxes use the same names. Use neighborhood cards for a single concept at depth 1 or 2, never for a whole graph. Use a matrix only when both axes have three or more entries.

## Drawing rules

- **Colors mean kinds, everywhere.** Blue: root or page type. Grey-blue: section and container types. Green: component or leaf object types that render. Violet dashed: interfaces. Amber: value types such as `Cta` and, in diff mode, changed fields. Red: non-null marks and removals. Keep the kit's class names; do not add colors.
- **Show every field in the schema view.** Readers select all fields in practice. List `name` then type. Mark non-null with the red `!` span, lists with blue bracket spans. Trim only inside a collapsed box.
- **Open the next level with a slot rule.** Before a nested box, add `<div class="slot">fieldName: one UISection</div>` or `many UIContainer`. The slot names the field that holds the children.
- **Directives become badges.** Put `<span class="badge dir">@component</span>` in the label. Show arguments when they matter: `@component(requiresFields: ["lists"])`.
- **Deprecated fields** get the `del` row style and a badge with the reason's ticket or first clause.
- **Diff mode** uses row classes `add`, `del`, `chg` and box classes `add`, `del`. A changed type gets a count badge in its label, for example `+1 field` or `1 changed`. Write the type change as `String → String!`.
- **Annotated wireframe pins** are numbered spans positioned over a phone mock. Keep to eight pins. The legend row gives the type and field in `<code>`, then the dot path from the root query in the `.path` line, for example `pageUI(path).openSection.children[0].cta`.
- **Neighborhood cards** list every edge in the `edges` array of the script as `[from, to, kind]` with kind `ref`, `impl`, or `mem`. Give each card a `data-id` equal to the type name. Order cards so edges mostly point right or down. Include the legend line under the figure.
- **Capability matrix** marks a supported cell `y`, an unsupported cell `n`, and a cell added by the change `new`. State in the caption where the cells come from when they are not derivable from SDL alone.
- Never draw ASCII diagrams. Never use tabs for top-level structure. Keep basic responsive behavior from the kit's media query.

## Checks

Before saving or returning, confirm each of these:

1. Every type and field name in the figures exists in the SDL or in the user's proposal.
2. The `<style>` block is present once and unchanged; the `<script>` block is present only if a `.graph` figure exists and every `data-id` in `edges` matches a card.
3. Any `<pre>` or code block has `white-space: pre` or `pre-wrap`.
4. No `<script src>`, `<img>`, or `<link>` to an external URL.
5. Each figure has a numbered caption. A legend for colors appears once per page.
6. In standalone mode the file path starts with today's date and sits outside any repository.
