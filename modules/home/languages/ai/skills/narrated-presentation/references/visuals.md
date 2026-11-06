# Scene visuals

Each scene is a Python script, `visuals-src/<id>.py`, that draws SVG frames with the kit and renders `visuals/<id>.mp4`. Run it with `present run visuals-src/<id>.py`; `present render-all [prefix]` runs them all.

## Rules for every scene

- Time every beat with `CUES, END = scene_cues(SID, {"name": "exact phrase from the caption"})`, and set `LENGTH = END + 1.6`. Never hard-code a time: re-voicing moves every phrase, and `render-all` re-times a scene only through `scene_cues`.
- Pick mark phrases that survive light edits: the first three or four words of a sentence.
- Build up rather than swap: a scene adds to what is on screen, and a series of scenes about one figure keeps its positions fixed.
- One colour per concept, from the script's production reference, in every scene.
- Code frames: at most 14 lines, real line numbers, a band on the discussed line, a muted source label.
- Hypothetical or invented things get `what_if()` on first appearance.
- Text must fit: `tw()` estimates width, so leave margin. Look at frames for overflow, overlap, clipped labels and lines crossing text.
- No long opaque strings (40+ characters without spaces) on screen or in logs: the DLP scanner ends the session. Use short fake ids.
- Helpers shared by one part's scenes go in `visuals-src/_<part>.py`. Move anything a second part needs into the kit instead of copying it.

## Kit API (svgkit)

- Timing: `prog` (ease in-out), `fin`/`fout` (ease-out fade in/out), `pulse`, `lerp`, `clamp`, `typed` (typewriter), `beat_grid`, `beat_bump`, `on_beat`.
- Motion wrappers: `rise` (40 px slide-in), `fade`, `xfade`, `group`, `scale_about`.
- Primitives: `doc`, `text`, `rect`, `circle`, `line` (with arrow), `arrow_path` (draws over p), `along` (a point on a path, to move tokens), `grid_bg`.
- Labels and boxes: `pill`, `chip`, `what_if`, `heading`, `caption`, `src_label`, `node_box`, `step_box`, `stamp`.
- Glyphs: `tick`, `cross`, `strike`, `bolt`, `lock_glyph`, `clock`, `finger` (tap), `wavy` (error underline).
- Code: `code_panel(lang=json|code|log|plain)` returns (svg, height); `code_line_y` and `code_char_x` anchor arrows and underlines to code.
- Terminal inside a scene: `term()` with `ev()` lines and `{green}` style tags. Output is canned; the script says so.
- Phone: `phone()` (tabs, sliding underline, badges, ghost tab, hidden tabs, clipped body, unclipped overlay), `card`, `list_row`, `skeleton`. Draw bodies in phone-local coordinates (`CARD_X`, `CARD_W`, `VIEW_TOP`).
- Output: `render_anim(frame, LENGTH, "visuals/<id>.mp4", keep_svg_at=...)`, `save_png`.
- Music cards: `_bumper.py` in the project holds `opener`, `bumper` and `outro`; edit its TITLE, BPM, PARTS and READ_NEXT.

## Production brief for visual agents

Write `production-brief.md` per project and give it to every visual agent with the kit path. It holds: the production reference from the script; the rules above; the kit API list; the helper module the part owns; "render, then look at 3-4 frames per scene with `present video frame` and the Read tool, and fix what you see"; "log every deviation from the spec to `problems-<part>.md`"; "no git, no edits to script.md, scenes.json or audio"; and the report skeleton from the user's CLAUDE.md with a word cap.

Pilot one scene per part before fanning out, and check it against the brief yourself. After a scene is split or added, run `present scenes` once it renders, so `scenes.json` points at the mp4.
