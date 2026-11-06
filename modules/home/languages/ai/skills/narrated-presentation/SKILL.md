---
name: narrated-presentation
description: Produce a long-form narrated presentation video (10-30 min) on a topic Jeff hands over, end to end - research against primary sources, a high-to-low outline, a script in Jeff's voice, a sung walk-on jingle with part bumpers and an outro cut from it, per-scene voice styles, beat-synced title cards, animated SVG scenes timed to the narration, music beds, captions and a checked MP4, with every source kept so it can be recomposed. Use when Jeff asks for a tutorial, explainer, talk or presentation video with music and animation, or to rework one made this way. For a short walkthrough without music or custom animation, use narrated-video alone.
---

Use this skill when Jeff gives a topic, scope or source material and wants a produced presentation video. The end state is one checked MP4 with soft captions, the sources ready to commit (not the media), and a report of what to judge by ear.

Fixed values:
- Tool: `@present@`. `present` below means this path. Run it from the project root. `present --help` lists its commands. It pins the renderers, fonts, and the TTS and STT endpoints; run nothing through `nix shell`.
- `present video ...` is a fork of the narrated-video tool with per-scene voice styles, per-clip speech EQ and loudness, music scenes and music beds. Its `slides`, `diagram`, `terminal`, `frame` and `check` subcommands behave as in the narrated-video skill.
- Project template: `present init <dir>` writes `script.md`, `say.json`, `music.json`, `.gitignore`, `README.md` and `visuals-src/` (`_bumper.py` and example scenes).
- References, read when a step names them: `references/script-format.md`, `references/writing-and-voice.md`, `references/visuals.md`, `references/music.md`.
- Skills this process uses, by name: `narrated-video` (output spec, slides, diagrams, terminal), `tts-speech` (voice controls), `stt-transcribe`, `yue2-song` (the jingle), `voice-dna`, `humanizer`, `writing-clearly-and-concisely`. Load each when its step comes.
- You cannot hear audio or watch video. Jeff judges voice, pacing, music and sync. You check frames, levels and transcripts.

Steps:

1. Intake. Get from Jeff: topic and scope, audiences (ranked), target length, the running examples, which sources are authoritative, and anything that must not appear on screen. Ask only for what the request and the sources do not answer. Make a branch, then run `present init media/<slug>` (or the directory Jeff names).

2. Research. Send 2-4 Sonnet subagents in parallel, one per area, to read the primary sources and write `research/<area>.md` with a file:line or URL for every fact. Give each one the DLP rules from the user's CLAUDE.md when it reads API responses or fixtures. Read the notes yourself. When a source contradicts Jeff's framing, note it with the citation for the report.

3. Outline. Write `outline.md`: a ladder of 4-7 parts from the big picture down to internals, each with its audience and the point where that audience can stop. Give the idea Jeff calls most important its own part and bumper. Then send one Sonnet subagent per part to write `plans/<part>.md`: scenes of one idea each, 10-30 s of speech, the medium, what is on screen, the sources.

4. Script. Write `script.md` yourself (Opus) from the plans, in the format in `references/script-format.md`, following `references/writing-and-voice.md`. Load `voice-dna` before writing; run `writing-clearly-and-concisely` and `humanizer` over every narration line after. Show Jeff the story overview and part list before rendering anything long.

5. Music. Load `yue2-song` and make a short walk-on jingle whose chorus shouts the title. Follow `references/music.md` to scan its bar grid, find vocal-free windows, and fill `music.json`: the opener, a four-bar bumper for every part after the first, and a 12-16 s outro.

6. Voice. Run `present scenes`, then `present video voice scenes.json`. Each narrated scene's `- Voice:` line picks its style (`references/writing-and-voice.md`). Run `present stt-check`, fix real misreadings in `say.json`, and list doubtful words for Jeff's ear.

7. Visuals. Write `production-brief.md` from `references/visuals.md` and the script's production reference. Pilot one scene per part yourself and check it against the brief. Then send one subagent per part with the brief, the part's scene ids, and the kit API. Each agent renders with `present run`, looks at 3-4 frames per scene, logs deviations to `problems-<part>.md`, and ends with the report skeleton from the user's CLAUDE.md.

8. Compose. Run `present render-all`, `present scenes` (it picks up the mp4 paths), `present music`, `present video assemble scenes.json out/<name>.mp4`, then `present video check out/<name>.mp4`. Confirm h264, aac, a mov_text track marked not default, -20 LUFS, and true peak at or below -2 dBFS. Look at frames from every new or changed scene and from each music scene.

9. Report. Start with a status line: length, loudness, commit state. Say how to open it (`! open <path>`). Then what changed, the source corrections from step 2, and a "Needs your ear" list: voice styles, doubtful words, music windows, beat sync, and length against the target with ranked cuts and the seconds each saves. Commit the sources (script, plans, research, visuals-src, say.json, music.json, README) when Jeff asks; media stays untracked.

10. Iterate. Before each round of changes: confirm the sources are committed (offer a commit if not), and copy `out/`, `audio/`, `visuals/` and `music/*.wav` to `backup-v<N>/`. Narration edits re-voice only the changed scenes. After any re-voice, run `present render-all`, because every cue time moves. Then repeat steps 8 and 9.

When something fails:
- `scene_cues` asserts that a mark is not in the caption: the narration changed. Update the mark to a phrase in the new caption; never replace it with a number.
- A scene drifts from its narration after a re-voice: the scene hard-codes times. Convert it to `scene_cues`.
- A TTS or STT call is refused by the sandbox: rerun with that host in `allowed_domains`.
- The video runs long: measure the speaking rate per voice style first, then give Jeff ranked cuts; cut only what he approves.
