# script.md format

`script.md` is the source of truth. `present scenes` turns it into `scenes.json`; never edit that by hand.

## Top of the file

1. `## Story overview`: who watches, what they can do afterwards, the running examples, and the parts as a numbered ladder from general to specific, each with its audience and stop point.
2. `## Production reference`: canvas, palette, fonts, the colour code (one colour per core concept, used in every scene), the hypothetical tag, motion defaults, and what must never appear on screen. Every visual agent reads this once.

## Parts and scenes

`## Part X: <title>` starts a part. Each scene is a `### <id>` block. Ids are `<letter><nn>-<slug>`: the letter is the part, `00` is its bumper, and a scene inserted later takes a suffix (`B09a`). Ids only need to be unique; their order in the file is the video order. A part added between two others gets its own letter even if it is out of alphabetical order; say so in the README.

A narrated scene:

```
### B04-the-response

- Target: 24 s. Medium: svg-anim.
- Visual: <layout, then one bullet per change>
  - ["The client sends"]: <what appears>
  - ["A bad value"]: <what changes>
- Source: `<path>:<lines>`, one per claim the scene makes.
- Voice: relaxed
- Transition: fade
- Narration: <one line, written for the ear>
```

A music scene (opener, bumper, outro) names its audio file and has no narration:

```
### C00-bumper

- Target: 8 s. Medium: music-anim. Audio: `music/bumper-C.wav`. No narration.
- Transition: slideleft
- Visual: part card, four bars.
```

What `present scenes` reads:
- `- Narration:` the caption, one line. No em or en dashes (the build rejects them).
- `Audio:` followed by a backticked path, anywhere in the block: a music scene. Its cut is set in `music.json` under the same id.
- `- Voice:` presenter (default), relaxed or dramatic.
- `- Transition:` an xfade name (see the narrated-video skill). Default fade. Give each bumper its own and use `fadeblack` into the outro.
- `- Seed: 42 (<why>)`: a TTS seed for this scene only. Use it when one take changes tone partway through (sounds close-mic'd or in another room from one sentence on). Try two or three seeds and keep the one Jeff picks.
- `- Hold: 2.6 s (<why>)`: the visual may run this long past the narration and tail, for a beat that stays up after the words end. Without it, `present video assemble` stops on a visual more than 1 s longer, because that visual was rendered for an older, longer narration.

Everything else is for people and agents. Key each Visual bullet to the narration phrase it follows, quoted in brackets with its first words, because those phrases become `scene_cues` marks.

## Medium

- `svg-anim`: a `visuals-src/<id>.py` scene script rendering an mp4 with the kit. The default for anything that moves.
- `svg-still`: the same, saved as a png.
- `music-anim`: a music scene's card, from `_bumper.py`.
- `slide`, `diagram`, `terminal`: rendered with `present video slides|diagram|terminal` as in the narrated-video skill. Prefer svg-anim with the kit's `term()` for a terminal that must sync with other elements.

## Sources and honesty

Every claim cites `path:line` in its Source line. Invented examples and hypothetical features are fine when they teach, but each carries an on-screen "what if" or "invented" tag the first time it appears, and the narration says so. When the code contradicts Jeff's framing, write what the code does and tell Jeff in the report.
