---
name: diff-explanation-core
description: Shared rules for explaining a code change with intuition, toy examples and diagrams. Loaded by explain-diff-html and explain-pr-body. Do not use directly.
---

# Diff explanation core

The rules that every explanation of a code change shares, whatever the output medium. The calling skill decides the sections, the medium and the delivery. This skill decides how to write and draw.

## Research first

- Read the whole diff, then the code around it. Do not explain from the PR title or the old description.
- Every identifier, signature, flow and number you state must come from source you read. Confirm each against a file and line.
- When you describe what the old code did, find the removed line in the diff. Do not infer it.
- Toy data must not pass as real data. If a figure uses a made-up value on a real type, say so in the figure.

## Intuition section

- Explain the essence, not the full details. Open with the one-sentence effect a reader would notice, then the mechanism.
- Use concrete examples with toy data. Define each term you introduce, in plain words, at first use.
- Use figures liberally.

## Voice

- Write with the clarity and flow of Martin Kleppmann: engaging, classic style, smooth transitions between sections.
- Callouts for key concepts, definitions and important edge cases.

## Diagrams

- Pick a small number of diagram families and reuse them across the explanation. Useful families:
  - A simplified version of the UI the user sees, for UI changes.
  - A system diagram of data flow or communication between components, with example data on it.
  - A before/after pair, with the same layout on both sides.
  - Pass and fail examples side by side, for a rule or validation.
- If the change touches GraphQL SDL, use the `graphql-schema-html` skill in figures-only mode (containment tree, diff mode, annotated wireframe). Paste its `<style>` block once.
- Never draw ASCII diagrams. Build every diagram in simple HTML and CSS, and use HTML lists for lists.
- Code in a diagram uses `<pre>`. A styled `div` in place of `<pre>` must set `white-space: pre-wrap`, or the browser collapses newlines. Before you save, check every code block for `white-space: pre` or `pre-wrap`.
- Color carries meaning: green for passes or the new behavior, red for fails or the removed behavior, grey for neutral. Keep each figure under about 900px wide.
