# Narration and voice

## Writing for the ear

Load `voice-dna` before writing and follow it for perspective and humour (a tutorial is first person). Then run `writing-clearly-and-concisely` and `humanizer` on the narration. On top of those:

- One idea per scene, 10-30 s of speech at about 2.6 words per second. A rule the audience must apply gets its own scene with the reason it exists: what breaks without it, and who enforces it (the author, or a check, and when the check runs).
- Vary rhythm. Mix short sentences with long ones. Ask the question the viewer is about to ask, then answer it ("Why the question mark? ..."). Use a two-word sentence for a turn ("Small problem."). A run of same-length declarative sentences sounds monotone however the voice is set.
- Spell for the ear in the caption itself: numbers in words, "slash", "dot json", "curly braces". Put TTS spellings of acronyms and code words in `say.json`, not in the caption.
- Use commas for pauses. Never split a sentence to work around the TTS.
- No em or en dashes.
- The opening scene states the problem from the viewer's side. Credit what existed before and say what was missing.
- Say out loud where each audience can stop.
- Mark the future and the hypothetical as such ("Later, I'd expect...", "what if").

## say.json

`replace` pairs run first, then `regex` pairs, on each caption to make the TTS text. Start from the template. Known Breeze habits: a bare "id" can be read as a word, so it is "eye dee"; "UI" spelled "U I" came out "U one", so it is "you eye"; a letter-spaced acronym ("c m s") reads cleanly. Add an entry only after an STT check or Jeff's ear finds a misreading.

## Voice styles

Styles live in `VOICE_STYLES` in the kit's `video.py`; a scene picks one with `- Voice:`. Jeff's choices:
- `presenter` (default): engaged and varied, for most scenes.
- `relaxed`: calm, for dense scenes (code walk-throughs, internals, step lists).
- `dramatic`: the presenter instruct at higher guidance, only for the opener, the first scene of each part, the most important idea and the sign-off. It over-emphasises if used widely.
- Jeff rejected the short reference voice (`jeff_short`). The Higgs styles are backups.

To try a new style, render one passage per candidate with the `tts-speech` skill at a fixed seed, save them to `out/voice-ab/`, and let Jeff choose. `present prosody` prints rough pitch and loudness spreads; its pitch tracker is too crude to rank takes on its own.

## Checking

`present stt-check` diffs each clip's transcript against its TTS text. Ignore joined acronyms, digits for numbers, and "id" for "eye dee". Report real word swaps and misreadings by scene for Jeff's ear; re-voice only what he flags or what is clearly wrong.

The speech chain in `video.py` de-noises, cuts 180 and 380 Hz, lifts 3.2 and 7 kHz, compresses gently, sets each clip to -20 LUFS and limits at -3 dBFS. Breeze clips arrive dark and near -35 LUFS. Before this chain, narration sounded muffled and quiet against the music; the likely cause was one loudness pass over very uneven input. `present ab-speech <id>` writes a raw/processed pair; `present audio-stats` prints LUFS and band balance per clip.
