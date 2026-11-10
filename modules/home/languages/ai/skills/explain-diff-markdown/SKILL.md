---
name: explain-diff-markdown
description: Use when the user asks for a rich explanation of a code change, diff, branch, or PR as a Markdown file. Produces plain Markdown with PNG figures beside it.
model: opus
---

# Explain Diff as Markdown

Make a rich explanation of the specified code change as a Markdown file with PNG figures. For a single HTML page, use `explain-diff-html`.

First load the `diff-explanation-core` skill. Follow its rules for research, sections, voice, diagrams and "Before you finish". This skill adds the Markdown format.

Use the core sections Background, Intuition, Code and Quiz, in that order, then an Answers section.

## Output layout

Make a fresh directory outside the code repo, named with today's date: `/tmp/YYYY-MM-DD-explanation-<slug>/`. Put in it:

- `explanation.md`: the explanation.
- `fig-<name>.png`: one file per figure.
- `figures/`: the HTML source of the figures, so they can be re-rendered.

## Markdown rules

Write plain CommonMark. The only extensions you may use are pipe tables, `~~strikethrough~~` and a YAML front matter block. Renderers differ on everything else, and some drop it.

- No raw HTML at all: no `<details>`, `<img>`, `<br>`, `<sup>` or styled `<div>`. A renderer that drops raw HTML loses the content.
- No task lists, footnotes, math, or GitHub alerts (`> [!NOTE]`).
- No Mermaid or other diagram code fences. Draw every figure as the core says and render it to PNG.
- No hand-written table of contents and no links to heading anchors. Anchor ids differ between renderers. The headings are the outline.
- One `#` title at the top. Each section is a `##` heading. Use `###` for parts of a section. Give every heading unique text, so a path such as `Code > Validation` names one place.
- Callouts are blockquotes that start with a bold label: `> **Definition: page cursor.** ...`, `> **Edge case.** ...`.
- Code uses fenced blocks with a language tag. Keep each block short; a figure is better for anything longer than about 20 lines.

## Figures

1. Render every figure with "Rendering figures to PNG" in the core skill. Keep the figure page in `figures/index.html` in the output directory, and copy each PNG into the output directory itself.
2. Reference each figure on its own line as `![alt text](fig-<name>.png)`. Write alt text that states what the figure shows, because some renderers show only the alt text.
3. Put a short caption in italics on the line under the image. The prose must not depend on the reader seeing colour alone.

## Quiz

- Number the questions. Give each question its options as a list labelled `A.` to `D.`.
- Put an `## Answers` section after the Quiz. For each question give the letter and the feedback for every option.

## Report

Give the directory and the Markdown path as `/private/tmp/...`, and list the figure files.
