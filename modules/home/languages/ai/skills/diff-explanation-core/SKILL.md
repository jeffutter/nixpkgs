---
name: diff-explanation-core
description: Shared rules for explaining a code change with intuition, toy examples and diagrams. Loaded by explain-diff-html, explain-diff-markdown, explain-pr-body and explain-diff-video. Do not use directly.
---

# Diff explanation core

The rules that every explanation of a code change shares, whatever the output medium. The calling skill decides which sections to use, the medium and the delivery. This skill decides what each section holds and how to write and draw.

## Research first

- Read the whole diff, then the code around it. Do not explain from the PR title or the old description.
- Every identifier, signature, flow and number you state must come from source you read. Confirm each against a file and line.
- When you describe what the old code did, find the removed line in the diff. Do not infer it.
- Toy data must not pass as real data. If a figure uses a made-up value on a real type, say so in the figure.

## Sections

The calling skill names the sections it uses, in this order.

- **Background**: the existing system this change touches. Explore the surrounding code broadly for it. We do not know how much the reader knows, so give a deep background for beginners first (say that a familiar reader can skip it), then a narrow background directly relevant to the change.
- **Intuition**: explain the essence, not the full details. Open with the one-sentence effect a reader would notice, then the mechanism. Use concrete examples with toy data. Define each term you introduce, in plain words, at first use. Use figures liberally.
- **Code**: a high-level walkthrough, not a line-by-line tour. Group changes by role (primitives, registry, generator, validation, pages, docs), and order them so each group builds on the one before. Name the file for each group. Say what was removed as well as what was added.
- **Quiz**: five multiple-choice questions that test the reader's understanding of the change. Medium difficulty: a reader must understand the substance to answer, but no gotchas. Each answer gets feedback that says why it is right or wrong.

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
- Never draw ASCII diagrams. Build every diagram in simple HTML and CSS, and use HTML lists for lists, unless the calling skill names other renderers.
- Code in a diagram uses `<pre>`. A styled `div` in place of `<pre>` must set `white-space: pre-wrap`, or the browser collapses newlines. Before you save, check every code block for `white-space: pre` or `pre-wrap`.
- Color carries meaning: green for passes or the new behavior, red for fails or the removed behavior, grey for neutral. Keep each figure under about 900px wide.

## Rendering figures to PNG

Use this when the calling skill needs figures as image files.

1. Build the figures as one HTML page, one `<div id="fig-...">` per figure, in the directory the calling skill names, or else a fresh directory under `$TMPDIR`. Draw them as "Diagrams" says.
2. Serve the directory with `python3 -I -m http.server <port> --bind 127.0.0.1 --directory <dir>` in the background. Pick a high random port. A busy port serves someone else's page, so check the page title after you navigate.
3. Navigate with Playwright. Call `browser_take_screenshot` with `target: "#fig-..."`, `scale: "device"`, and no `filename`. Named files and `file://` URLs are denied here.
4. The tool result names the saved PNG, under `/tmp/playwright-mcp/`. Copy each to the directory the calling skill names, with a stable name such as `fig-paging.png`.
5. Look at each screenshot. Fix and re-render any that clip, wrap badly or state something untrue. Then stop the server.

## Before you finish

- List every code identifier, signature and flow the explanation claims. Confirm each against source.
- Read the rendered result, not only the source of it.
