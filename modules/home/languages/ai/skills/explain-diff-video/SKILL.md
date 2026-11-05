---
name: explain-diff-video
description: Use when the user asks for a narrated explainer video (MP4) of a code change, diff, branch, or PR. Collects the same material as explain-diff-html and hands it to narrated-video for slides, diagrams, voiceover and captions.
model: opus
---

# Explain a diff as a video

Make a narrated explainer video of the specified code change. This skill decides what the video says and shows. The `narrated-video` skill decides how to render it.

First load the `diff-explanation-core` skill. Follow its rules for research, the Intuition section, voice and diagrams. Then load the `narrated-video` skill. Follow it for the project layout, `scenes.json`, narration, rendering, assembly and checks. This skill adds the sections, the figure mapping and the claims pass.

## Sections

Aim for 2 to 5 minutes, about 8 to 16 scenes. Each scene is one idea.

- **Hook** (1 scene): the one-sentence effect a user or reviewer would notice, and what the video will cover. A `title` slide.
- **Background** (1 to 3 scenes): the existing system this change touches. Explore the surrounding code for it. Keep only what the reader needs to follow the change; a video cannot be skimmed, so cut the beginner background that `explain-diff-html` would include.
- **Intuition** (3 to 6 scenes): as the core skill describes. Toy data, before and after, one figure family reused across scenes.
- **Code** (2 to 4 scenes): a high-level walkthrough, not a line-by-line tour. Group changes by role and order them so each group builds on the one before. Name the file for each group on screen. Say what was removed as well as what was added.
- **Recap** (1 scene): three takeaways a reader should leave with, in place of the HTML quiz. A `bullets` slide.

## Figures

Map each core diagram family to a `narrated-video` renderer:

| Core family | Renderer |
|---|---|
| System or data flow with example data | D2, with a shared base file for build-ups across scenes |
| Request or call order | Mermaid sequence diagram |
| Before/after, pass/fail | Marp `.cols` with `.col.bad` and `.col.good` |
| Code excerpt | Marp slide with a fenced code block, 15 lines at most |
| Behaviour of a CLI, test run or log | Simulated terminal (`video terminal`) |
| Numbers (latency, counts) | Vega-Lite chart |
| Simplified UI, GraphQL schema figures | HTML and CSS, rendered to PNG |

- For an HTML figure, follow the core rules for HTML, but size the figure for a 1920x1080 frame and use the `NIGHT` colours from `scripts/video.py` in the `narrated-video` skill. Render it with the Playwright steps in "Slides without a browser launch" in that skill: resize to 1920x1080, screenshot without a file name, copy to `diagrams/<id>.png`.
- Keep the core's colour meaning: green for new or passing, red for removed or failing.
- A simulated terminal shows canned output. Use only output you saw in a real run or copied from source, and label toy values on screen.
- Put the core's callouts on screen as short slide text. The narration says the same thing in full sentences.

## Steps

1. Research the change as the core skill says. Write the claims list to `claims.md` in the project: every identifier, signature, flow and number the video will state, each with `file:line` or the diff hunk it comes from.
2. Make the project in a fresh directory outside the repo, named with today's date: `/tmp/YYYY-MM-DD-explainer-<slug>/`. Copy the `narrated-video` example into it as a start.
3. Write `storyboard.md` with the sections above. Show it to the user before you render narration.
4. Follow the `narrated-video` steps from narration through assembly and checks. Write narration for the ear: say "the `fetchPage` function" as "the fetch page function" in `say`, and keep the identifier in `caption`.
5. Before you finish, check each frame against `claims.md`. Every on-screen identifier and number must appear there with a source. Fix the scene, not the claims list.

## Report

Give the MP4 path (as `/private/tmp/...`), its length, and `! open <path>` to play it. Ask the user to judge the voice, pacing and pronunciation, because you cannot hear the audio.

Do not upload the video or commit anything for it unless the user asks.
