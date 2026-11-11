# Alternatives per stage

Read this when a pinned tool breaks, or when the environment changes. The usual change is headless Chrome starting, which happens outside the Claude Code sandbox or after the sandbox allows Chrome's Unix-socket bind. Status tags:
- **ran**: used in the 2026-11 pilot.
- **tested**: run once in research.
- **read**: from docs only.

## Browser: the main constraint

Inside the sandbox, Chrome aborts with `bind() .../SingletonSocket: Operation not permitted` under `/var/folders/*/*/T/`. Puppeteer reports this as "browser is already running for userDataDir", and go-rod reports "could not start browser". This blocks VHS, Marp PNG/PDF export, mmdc, decktape, Slidev export and any Playwright you launch yourself (tested). The Playwright MCP is not affected, because it runs outside the sandbox. A possible sandbox allowance is Unix-socket bind for `/var/folders/*/*/T/`. It is untested and may need more. That is the user's decision.

If Chrome can start, prefer, in order:
- Marp `--images png` in place of the Playwright screenshot route. `video slides` already tries it first.
- VHS for terminals that run real commands (see below).
- `mmdc` for Mermaid features that Pele lacks. Set `htmlLabels: false` or screenshot, because resvg drops `foreignObject` labels.

## Slides

| Tool | Status | Use when | Cost |
|---|---|---|---|
| Marp CLI (pinned) | ran | Default. Markdown plus a CSS theme; diffs well; LLMs write it reliably | PNG needs a browser |
| Typst (`nixpkgs#typst`) | tested | No browser at all: `typst compile deck.typ 's-{p}.png'` | Typst markup instead of Markdown. touying/polylux packages from packages.typst.org failed on proxy TLS; vendor them with `--package-path` |
| Slidev | read | Click-step PNGs (`--with-clicks`) and line-by-line code highlights | Heavy (Vite, Vue, Playwright); needs a browser |
| reveal.js + decktape | read | HTML authoring with fragments walked per PNG | Needs a browser |
| Pandoc beamer | read | Already have TeX | Multi-GB TeX |

Avoid: mdx-deck (unmaintained), Spectacle (React), Deckset (GUI only), Quarto (too large for this).

## Diagrams and charts

| Tool | Status | Use when | Note |
|---|---|---|---|
| D2 (pinned) | ran | Architecture, flows, staged build-ups | Grid plus `opacity: 0` keeps positions stable across stages. ELK/TALA layouts for big graphs |
| Pele (pinned, vendored npm) | ran | Mermaid syntax without a browser, especially sequence diagrams | Emits `var(--pele-*)`; `scripts/pele.mjs` flattens them. Check https://pele.run/compatibility for diagram types |
| Vega-Lite `vl2svg` (pinned) | ran | Data charts | `vl2png` needs node-canvas; rasterise the SVG with resvg instead |
| Graphviz `dot` | tested | Dense graphs where D2's layout is weak | No themes; set colours per attribute. `neato -n` pins positions for stages |
| matplotlib (`svg.fonttype=none`) | read | Charts Vega-Lite cannot draw | Needs a Python env with matplotlib |
| mermaid-rs-renderer (`mmdr`), beautiful-mermaid | read | Pele cannot draw a Mermaid type | Young projects; check quality first |
| Typst + fletcher/cetz | read | Diagram and slide in one typeset document | Package fetch blocked as above |
| Manim | read | Animated maths or algorithm explainers | Needs LaTeX and cairo; outputs video directly |
| mmdc (Mermaid CLI) | tested (failed) | Full Mermaid fidelity | Needs Chrome; the nix package ships none |

Skip: PlantUML (JVM, hung in tests), Excalidraw CLI (browser, hand-drawn look), Kroki (only if self-hosted). The `diagram-design` and `excalidraw-diagram` skills make HTML or JSON, not video frames. Use them only as a source you screenshot with the Playwright MCP.

## Terminal

| Tool | Status | Use when | Note |
|---|---|---|---|
| Hand-written asciinema cast -> agg -> ffmpeg (pinned, `video terminal`) | ran | Default. Exact timing, canned output, no pty and no browser | agg outputs GIF only, so ffmpeg overlays it on the backdrop. The nix package is `asciinema-agg`; `nixpkgs#agg` is Anti-Grain Geometry |
| charmbracelet VHS | tested (failed here) | Real commands, and Chrome can start | `.tape` language with `Type`, `Sleep`, `Wait /regex/`, `Hide`/`Show`, `Set WindowBar Colorful`, `Set Margin`, `Set MarginFill`, `Set BorderRadius`. Use canned-output scripts to stay deterministic. No image backdrop: overlay one with ffmpeg as `video terminal` does |
| `asciinema rec` live recording | tested (failed: needs a pty) | Capture a real session outside the sandbox | Then render with agg as above. Live timing will not match narration; edit the cast timestamps |
| xterm.js page + Playwright frame-by-frame | read | Full CSS control, frame-exact from a virtual clock | Custom code; needs a browser |
| charmbracelet freeze | read | A still frame of code or terminal output with window chrome | No time axis |

Skip: termtosvg (archived), svg-term-cli and terminalizer (stale; no video).

## Assembly and transitions

| Tool | Status | Use when | Note |
|---|---|---|---|
| ffmpeg `xfade` + `acrossfade` (pinned) | ran | Default. 58 transitions, deterministic, no GL | `video assemble` allowlists about 20 that suit technical content |
| xfade-easing (scriptituk) | read | Easing curves and about 90 ported GL transitions without OpenGL | Stock-ffmpeg expression mode is slow; the fast mode needs a patched ffmpeg build |
| MLT `melt` | tested (nix build failed on ladspa.h) | Multi-track compositing, such as a terminal picture-in-picture over a slide | Override with `USE_LADSPA=OFF` |
| HyperFrames, revideo | read | Rich animated overlays and WebGL transitions | Need headless Chrome; check telemetry and licences |
| MoviePy 2 | read | Python-scripted compositing | Few transitions |

Skip: ffmpeg-gl-transition, ffmpeg-concat and editly (need OpenGL; archived or dormant), Remotion (paid licence for companies), Motion Canvas (no headless render), Blender VSE, Natron, GES and OpenTimelineIO (heavy for few gains).

## Narration and timing

| Tool | Status | Use when | Note |
|---|---|---|---|
| Local TTS through `video voice` (curl) | ran | Default; Jeff's cloned voice | Styles live in `VOICE_STYLES` in `scripts/video.py` |
| The `tts-speech` skill | ran | One-off clips and auditioning a new style | Fixed to use curl on 2026-11-03; it used urllib, which truncated through the sandbox proxy |
| Kokoro (same server) | read | Drafts, or a voice that is not Jeff's | No cloning |
| audio.cpp `--task align` | read | Word timestamps for exact caption timing | Not exposed through the server yet |
| whisper.cpp (`-ml 1 -oj --split-on-word`) | read | Word timestamps from a transcript | Transcribes rather than aligns, so times are approximate |
| stable-ts `align()`, Montreal Forced Aligner | read | Exact alignment to known text | Heavy installs (PyTorch, Kaldi) |

## Prior art for the "script as a play" shape

- Anthropic's official skills (pptx, frontend-design and others) cover slides and documents, not video.
- Community skills that pair Remotion, VHS or ffmpeg exist. None covers the full narrated pipeline with sandbox-safe renderers, which is why this skill exists.
