---
name: explain-pr-body
description: Use when asked to revamp, rewrite or enrich a GitHub PR description so it explains the change with intuition and figures. Renders figures to PNG and uploads them to the PR with gh. Skips background and quiz.
model: opus
---

# Explain a PR in its body

Rewrite the PR body so a reviewer understands the change from the PR page alone. The output is a Markdown body with embedded images, not an HTML page. For a standalone HTML explanation, use `explain-diff-html`.

First load the `diff-explanation-core` skill. Follow its rules for research, the Intuition section, voice and diagrams. Skip Background, Code walkthrough and Quiz unless the user asks for them.

## Steps

1. Read the current body: `gh pr view <n> --json number,title,body,url`. Read the diff without generated files (the repo's CLAUDE.md names the excludes).
2. Plan one figure per idea that prose explains badly: a before/after, a request flow with toy data, a rule with pass and fail examples. Three or four is enough.
3. Build the figures as one HTML page, one `<div id="fig-...">` per figure, in a fresh directory under `$TMPDIR`. Draw them as the core skill describes.
4. Render each figure to PNG:
   - Serve the directory with `python3 -I -m http.server <port> --bind 127.0.0.1 --directory <dir>` in the background. Pick a high random port. A busy port serves someone else's page, so check the page title after you navigate.
   - Navigate with Playwright. Call `browser_take_screenshot` with `target: "#fig-..."`, `scale: "device"`, and no `filename`. Named files and `file://` URLs are denied here.
   - The tool result names the saved PNG, under `/tmp/playwright-mcp/`. Copy each into a fresh directory next to the body file, with a stable name such as `fig-paging.png`.
   - Look at each screenshot. Fix and re-render any that clip, wrap badly or state something untrue. Then stop the server.
5. Write the body to a new file. Reference each figure as `![alt text](./fig-name.png)`. Put the alt text in the Markdown. Do not add `#alt` to the path in the body.
6. Update the PR with one bare call, with every figure attached:
   `gh pr edit <n> --repo <org>/<repo> --body-file <body.md> --attach <dir>/fig-a.png --attach <dir>/fig-b.png`
   `gh` rewrites each `./fig-*.png` reference to an uploaded asset. Run it bare: no pipe, no redirect. A piped call runs sandboxed and fails TLS. Up to 50 files.
7. Read the body back with a bare `gh pr view <n> --json body --jq ...`. Confirm that every image link is a `github.com/user-attachments` URL and that no `./fig-` path is left. Print only pass or fail, not the body.

## Body shape

Keep the repo's PR template sections, and keep facts the old body already states (Jira link, assumptions, checklist, attribution line). Put the new sections between the summary and the template's tail:

- **Summary**: the user-visible effect first, then the mechanism, in a few sentences.
- **Intuition**: the figures and the prose that carries them. State the before and the after.
- **Tests**, **Docs**, **Assumptions**, **Checklist**, **Notes for reviewers**: as the old body had them.

Do not state commit counts, hashes or test counts. They go stale.

## Rules

- Say "done" only after the readback in step 7.
- Do not paste unverified causes into the body. Mark a hypothesis as one.
- Figures are documentation, not evidence. A toy value on a real type needs a label in the figure.
- Commit nothing for this. The body and images live on GitHub, not in the repo.
