---
name: explain-diff-html
description: Use when the user asks for a rich explanation of a code change, diff, branch, or PR. Produces HTML output.
model: opus
---

# Explain Diff as HTML

Please make me a rich, interactive explanation of the specified code change. For a Markdown file, use `explain-diff-markdown`.

First load the `diff-explanation-core` skill. Follow its rules for research, sections, voice, diagrams and "Before you finish". This skill adds the HTML format.

Use the core sections Background, Intuition, Code and Quiz, in that order.

## Format

- Output a single self-contained HTML file which includes CSS and JavaScript. Make the whole thing one long page with section headers and a table of contents. Don't use tabs for the top-level structure. Basic responsive styling so you can view it on a phone is nice too.
- Draw figures inline in the page as HTML and CSS, as the core "Diagrams" says.
- Callouts are styled boxes, one style per callout type (concept, definition, edge case).
- Make the Quiz interactive: when the reader clicks an answer, show whether it is correct and give the feedback.
- Put the file in a global place on my computer outside of the code repo, and make sure the filename always starts with today's date in `YYYY-MM-DD-` format, because it helps keep the files time-sorted and out of version control. For example: /tmp/2026-01-12-explanation-<slug>.html
