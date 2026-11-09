---
name: narrated-video
description: Make a narrated technical walkthrough video (MP4) in Jeff's voice from a script - slides, diagrams, charts and a simulated terminal, joined with transitions, normalised audio and toggleable captions. Use when the user asks for a video presentation, a narrated walkthrough or demo video, a talk recording, or "turn this into a video".
---

Use this skill when the user wants a narrated video for developers. The end state is one MP4 (1920x1080, 30 fps, H.264, AAC, -20 LUFS) with a soft English caption track that is off by default, plus an `.srt` beside it. Report its path, its length and how to open it.

Fixed values:
- Tool: `@video@`. Make every call through it. `video` below means this path. It pins ffmpeg, MP4Box (gpac), d2, resvg, vl2svg (Vega-Lite), agg (asciinema), marp, node, Pele, curl, Inter and JetBrains Mono. Do not run `nix shell` for these.
- Worked example: `assets/example/` beside this file (`scenes.json`, `slides/deck.md`, `diagrams/`, `terminal/`). Copy it to start a new project.
- Slide theme: `assets/night.css` (Marp theme `night`). Its colours are the `NIGHT` table at the top of `scripts/video.py`. Every renderer reads that table.
- Narration voice: Jeff's cloned `jeff` voice, seed 7, style `relaxed` (Breeze, relaxed conversational instruct, guidance_scale 2). This is Jeff's chosen default. `--style expressive` (Higgs, `<|prosody:expressive_high|>`) is the backup. Use `--style enthusiastic` (Higgs, `<|emotion:enthusiasm|>`) only when Jeff asks for a really enthusiastic read. The `tts-speech` skill explains the controls.
- Use the cloned voice only for content Jeff wants said in his own voice.

Project layout (paths in `scenes.json` are relative to it):

```
scenes.json        scene list: the single source of order, narration and transitions
storyboard.md      the script and what each screen shows (written first)
slides/deck.md     Marp deck -> slides/slide-NN.png
diagrams/*.d2 | *.mmd | *.vl.json -> diagrams/<id>.png
terminal/<id>.shots.json -> terminal/<id>.mp4
audio/<style>/<id>.opus  narration, with <id>.request.json stamps
out/<name>.mp4, out/<name>.srt
```

`scenes.json`: `{"scenes": [{"id", "visual", "caption", "say"?, "transition"?, "audio"?, "seed"?, "hold"?}]}`.
- `caption`: the narration as it should read on screen, spelled properly.
- `say`: the same text spelled for the TTS when a word is misread ("Shroh-dinger's"). It defaults to `caption`. Keep the two identical apart from spelling, or the captions drift from the audio.
- `transition`: how the scene enters. Allowed: fade, fadeblack, fadewhite, dissolve, wipeleft/right/up/down, slideleft/right/up/down, circleopen, circleclose, radial, pixelize, zoomin, smoothleft, smoothright, hblur, distance. The default is fade. Use fade for most joins and save the others for a change of medium.
- `visual`: a PNG (held for the narration) or a video (frozen on its last frame if shorter than the narration). A video more than 1 s longer than lead + narration + tail stops `assemble`: it was made for an older, longer narration and would hold in silence. Re-render it after every re-voice.
- `seed`: a TTS seed for this scene only. Use it when one take changes tone partway through (close-mic'd or another room from one sentence on). Render two or three seeds and let Jeff pick.
- `hold`: seconds the visual may run past the narration and tail, for a beat meant to stay up after the words end.

Steps:

1. Write `storyboard.md`: the overall story, then per scene the medium, what is on screen and the narration. Keep a scene to one idea and 10 to 25 s of speech (about 2.6 words per second). Mix media: slides for framing, diagrams for structure, a terminal for behaviour, a chart for numbers. Show the storyboard to the user before you render anything long.

2. Write the narration into `scenes.json`.
   - Write for the ear. Spell out numbers, units and symbols ("one hundred percent", "thirty two").
   - Use commas for pauses.
   - Never split sentences to work around TTS problems. Jeff finds it choppy.
   - Known `say` spellings for Breeze: "id" as "eye dee", "UI" as "you eye", and a camelCase name like "pageUI" hyphenated as "page-you-eye" (with spaces it gets a gap). Write "json" as "jason"; alone it is read as "jotson".

3. Render the narration first, because its length sets every scene's length: `video voice scenes.json`. A scene renders again only when its text, model, style or seed changed, so rerun freely. Use `--only <id>...` for one scene. The server splits text over 600 characters (Breeze) into chunks generated independently, so the tone jumps at the join; `video voice` sends longer text as one chunk (`options.text_chunk_size`). Then run the `stt-transcribe` skill on each clip and compare it word by word with `say`. Flag names and acronyms for Jeff's ear rather than re-rendering on a mishearing. Parakeet writes "cache" as "cash" and drops "ö".

4. Make the visuals. Each parallel area (slides, diagrams, terminal) can go to its own subagent with this skill's path, the storyboard and the theme. Each subagent logs problems to `problems-<area>.md`.
   - Slides: run `video slides slides/deck.md slides`. Write each build step as its own slide; Marp has no per-step PNGs. Layout classes: `title` (with `.glyph`, `p.subtitle`, `p.footer`), `bullets` (numbered cards), and the `.cols` / `.col.good` / `.col.bad` two-column cards. See the example deck. If the command exits 2 because headless Chrome could not start, follow "Slides without a browser launch".
   - Diagrams: run `video diagram diagrams/s03-arch-a.d2 diagrams/s03-arch-a.png --title "The architecture"`.
     - D2 handles architecture and flows. For a build-up across scenes, put the full layout in a shared base file, pin cells with a grid, and hide elements per stage with `opacity: 0` rather than deleting them, so positions stay put. See `arch-base.d2` and `s03`/`s04`.
     - Mermaid (`.mmd`) is rendered by Pele with no browser. Use it for sequence diagrams.
     - Vega-Lite (`.vl.json`) handles charts. Set `background` and `config.font: "Inter"` in the spec, as in the example.
     - A warning about `var(` or `foreignObject` means parts will render black or blank. Fix the source.
   - Terminal: write `terminal/<id>.shots.json` and run `video terminal terminal/<id>.shots.json terminal/<id>.mp4`.
     - The output is a simulation: typed commands and canned output in a macOS-style window on a backdrop. No real command runs, so it is exact and repeatable.
     - Each shot is `{"at": seconds, "cmd": "...", "out": [[delay, "text"], ...]}`.
     - Colour the output with `{blue} {green} {pink} {amber} {muted} {purple} {cyan} {bold} {reset}`.
     - Set `end` to the narration length plus about 1.5 s.
     - Get `at` times from step 5.

5. Time the beats: `video cues scenes.json --only <id>` prints when each sentence starts in the scene. Start a terminal command just after the sentence that introduces it. If an output overruns the next beat, the terminal command stops with an error.

6. Look at every PNG and at a few terminal frames with the Read tool. Extract a frame with `video frame terminal/s05.mp4 12 <tmpdir>/f.png`. Check the following, then fix and re-render:
   - text that overflows or wraps badly
   - colours that are black or missing
   - labels that are cut off
   - diagram stages that shift position between scenes

7. Assemble: `video assemble scenes.json out/<name>.mp4` (add `--style` if you rendered another voice). It takes about 30 s for 2 minutes of video. It runs these steps:
   - de-noises and fades each narration clip
   - holds each visual for 0.4 s of lead, the narration, and a 1.3 s tail
   - joins the scenes with 0.8 s transitions
   - normalises loudness in two linear passes
   - writes sentence caption cues snapped to pauses
   - sets the subtitle track to off

8. Check the result.
   - Run `video check out/<name>.mp4`. Confirm it shows h264, aac, and a mov_text track marked "not default", with loudness about -20 LUFS and true peak at or below -2 dBFS.
   - Extract one frame per scene with `video frame`, using the scene start times that assemble printed, and look at each.
   - Then give the user the path. If `open` is blocked, give them `! open <path>` to run. Ask them to judge the voice, pacing and pronunciation, because you cannot hear the audio.

Slides without a browser launch (when `video slides` exits 2):
1. `deck.html` is already written.
2. Serve it: `python3 -I -m http.server 8765 --bind 127.0.0.1 --directory slides`, in the background.
3. With the Playwright MCP, resize to 1920x1080. Navigate to `http://127.0.0.1:8765/deck.html?v=<n>#<slide>`. Change `v` after each re-export, or the page will not reload.
4. Take each screenshot without a file name. Copy each one to `slides/slide-NN.png`.
5. Stop the server.

When something fails:
- Headless Chrome fails to start: `marp --images png` reports "browser is already running for userDataDir", and VHS reports "could not start browser". Inside the Claude Code sandbox, the cause is a denied Unix-socket bind for Chrome's `SingletonSocket` in the temp directory. Use the Playwright route above. Do not try to bypass the sandbox; changing it is the user's decision.
- `video voice` retries a short or failed download 3 times. Python urllib downloads came back truncated through the sandbox proxy, and curl did not, so the tool uses curl. If a scene still fails, rerun with `--only <id>`. The first call after a model swap takes about 40 s.
- `speed` returns an error on Breeze, and `exaggeration` is ignored. Pacing comes from punctuation and the style.
- Captions are timed per sentence, not per word, because neither TTS nor STT returns word timestamps here.
- A tool is missing or broken: see `references/alternatives.md` for the ranked fallbacks for each stage, and for the better tools to use once a browser can start.
