---
name: song-cover
description: Make a cover of an existing recording in a new style, optionally with a reharmonized chord progression. Transcribes the audio to an ABC score with SheetSage2, gets or checks the lyrics, then renders takes with YuE2 on the GPU host. Use when the user gives an audio file and wants a cover, a different-style version, a reharmonization, or sheet music or chords from a recording.
---

Use this skill when the user gives a recording and wants it re-performed in another style, with the original chords or a reharmonization. The end state is the score (`-sheetsage.abc`), any reharmonized score, and MP3 takes in the user's directory, reported with check results, revised until the user stops asking.

This skill covers the pipeline. Rendering rules (style string, plans, BPM, checks) are in the `yue2-song` skill. Load it before step 5.

Fixed values:
- Helper: `@cover@`. `cover` below means this path.
- Renderer: `@yue2@`. `yue2` below means this path.
- Servers: audio.cpp on the GPU host behind llama-swap. SheetSage2, YuE2 and the Parakeet word-timestamp model evict each other. The first call after a model swap can take several minutes. If the user says audio.cpp is not loaded, wait for their go-ahead before any call that needs the server.
- `cover status` lists the audio.cpp models and whether each is loaded. It changes nothing.
- `cover transcribe AUDIO --out X-sheetsage.abc` converts the audio to mono 44.1 kHz WAV, uploads it and runs SheetSage2. It takes about 30s once the model is loaded. SheetSage2 accepts WAV only and must be the FP32 build, because the Q8 build changes notes.
- `cover lyrics AUDIO --out draft.txt` writes a flat speech-to-text draft of the words.
- `cover fit PLAN.abc LYRICS.txt` compares the notes in each sung plan section with the syllables in the matching lyric section. Offline.
- `cover reharm-check ORIGINAL.abc NEW.abc [--tolerance 0.12]` proves the melody is unchanged and lists chords that do not fit it. Offline.
- `cover timing TAKE.mp3 [--plan P.abc] [--bpm N]` prints first and last sung word, gaps over 6s, and the plan's expected end.
- Both models are CC BY-NC 4.0: personal and non-commercial use only. Say so if the user mentions releasing the result.
- File names in the user's directory: `<song>-sheetsage.abc`, `<song>-sheetsage-reharm-v<N>.abc`, `<song>-<style>-<original|reharm>-v<round>-<variant>.mp3`. Leave the MP3s out of git. Do not commit anything unless the user asks.

Inputs:
- Required: the audio file. Optional: a lyrics file. Optional: the target style and whether to reharmonize. If the style is missing, ask for it. It is the one decision you cannot default.
- If the user names a reference artist, search the web for the artist's instrumentation and production, then describe the sound in words. Do not put the artist's name in the style string.

Steps:

1. Check the server. Run `cover status`. `loaded=False` is normal. If a call later fails with a connection error, tell the user which server failed and stop.

2. Transcribe. Run `cover transcribe`. Read the printed meter, tempo, key and section list. Open the `.abc` and check it looks like a song: a `Vocal` voice with a melody, sections marked `% intro`, `% verse`, `% chorus`. SheetSage2 output is a sketch. Chord symbols are coarse (`Gm`, `D#`, `A#`) and the second voice is a plain pattern. Tell the user the key, meter and original tempo.

3. Lyrics.
   - A lyrics file was given: use its text as it is. Web-scraped lyrics often carry clutter lines such as "You might also like", song titles or artist names. Report any such lines to the user. Remove them from a copy, never from the user's file, unless they say to edit it.
   - No lyrics file: run `cover lyrics` for a draft. Speech-to-text mishears sung words and has no section structure. Split the draft into labeled sections that match the plan's sections, and show it to the user to confirm before you render.
   - Do not write out a commercial song's lyrics from memory, and do not make up substitutes while calling them the real ones. In the one session this skill comes from, placeholder lyrics were rendered by mistake and the user rejected the takes. If you have no lyrics and the draft is unusable, ask.
   - Label sections `[Verse 1]`, `[Chorus]`, `[Verse 2]`, `[Final Chorus]`, `[Outro]` in the plan's order. Put arrangement directions inside the label: `[Chorus: the band swells, ...]`. YuE2 does not sing them.
   - Keep the user's line breaks. The one test of re-flowing lines to melody phrases was judged worse by the user.

4. Check the fit. Run `cover fit PLAN LYRICS`. Section counts should match. A syllable-to-note ratio from about 0.8 to 1.15 is normal. A ratio far from 1 means words crowd the melody or the melody has spare notes. It cannot prove that words land on the right notes. That is the user's ear.

5. Render the control first: the original chords, in the new style.
   - Pin the plan: `yue2 render --plan X-sheetsage.abc --bpm <original Q>`. Use the plan's own tempo. In the one song tried, the user judged 146 BPM (the original tempo) better than 132.
   - Export `STT_MODEL=whisper-1` if `yue2 check` reports HTTP 404 from the speech-to-text server.
   - Render takes one at a time, with the seeds `103` and `101` first. Run each in the background and read `yue2 check` and `cover timing --plan` when it ends.
   - Write the style string by the `yue2-song` skill's order. Lessons from the session this skill comes from, each tested on one song:
     - Name the voice early and in plain words ("female lead vocal, deep rich contralto"). Earlier takes said "female alto" once, in the middle of the vocal tag, and the user still asked for a female voice afterwards. Whether the lead-first wording fixes it was not heard.
     - The user asked for a vocal that is deep, soulful, dry and not breathy or reverby. "Dry and upfront" was in every later style string and the user stopped complaining about it. That is weak evidence, not proof.
     - Genre words steer the whole band. "ECM", "delay", "hushed", "brushed drums" and "looping ostinato" pulled a modern jazz request toward trip-hop. Wording such as "groove-driven and polished like a tight contemporary live jazz band", "live acoustic drum kit with ride cymbal, ghost notes and crisp fills" moved it back. That is inference from the user's ear, not a measurement.
     - "Rhythmic echo delay" on the guitar probably produced a picked rhythmic part. "Long sustained lush chords that ring out and swell" on the guitar helped, but the style string alone never fully removed the picking.
     - A 6/8 feel can only be hinted in words. The plan stays in 3/4. `yue2 check` may report it as "ambiguous" or compound.
   - Put the dynamics in the section labels: sparse first verse, swelling chorus, busier second verse, then the loudest and most active final chorus.

6. Reharmonize, if asked. Do this only after the user has heard the control.
   - Write a new copy of the ABC (`-reharm-v<N>.abc`). Change only the quoted chord symbols on the `Vocal` voice. Never touch the notes.
   - Fit each chord to the melody it covers: keep the melody's notes inside the chord's tones and its 9th, 11th and 13th. Prefer modern jazz moves: `m7`/`m9` for minor, `maj7`/`6` for major, `7sus4` and `9` for dominants, simple slash-bass inversions. Reuse the original chord as a safe fallback where nothing fits.
   - Stay in this vocabulary: `maj7 m7 m9 6 m6 9 7sus4 sus4 add9 m7b5 dim` and a single slash bass. In this session, symbols such as `13sus4`, `maj7#11`, `maj9#11/A#` and stacked slash chords made YuE2 drift off the plan's timeline (220s against a 174s plan, with dropouts). A control with the original chords stayed on plan. That is inference from a handful of takes on one song.
   - Do not insert extra passing chords between the original chords on the first pass. One round with 20 inserted chords made the lyrics separate from the melody. Add them back a few at a time only if the user wants more harmony, and re-check each round.
   - Do not write chord voicings into the instrument (`Ins`) voice to force a sustained guitar. Two such plans broke the timing (204s, with a 17s gap).
   - Run `cover reharm-check ORIGINAL NEW`. The melody line must read `YES`. Chords listed as outside the safe vocabulary or out of fit are hints, not proof: the checker's tension rules are generic. Fix the flagged chords or accept them knowingly.
   - Tell the user the harmonic changes in a few words, so they know what to listen for.

7. Shape the song, if the user wants a build or an ending. The plan fixes the structure and length, so changes go in the ABC.
   - A high point: repeat the final chorus block in the ABC and the lyrics, label the second pass as the peak (full band, crash cymbals, huge guitar chords, backing vocals).
   - An ending: add a `% outro` section with a short vocal phrase that resolves to the tonic and holds, plus empty bars, and an `[Outro: ...]` label asking the band to land on one final held chord.
   - Both were built in this session (`cover reharm-check` reports the added structure as a melody difference) but the render was stopped before anyone heard it. Treat both as untested.
   - Explicit syllable lines (`w:` under each vocal line, one syllable per note, `_` for a held note) were also built to pin the words to the notes. Whether YuE2 reads them is unknown. If you try it, render a take without them as the control.

8. Report each take: length, pulse verdict, lyric word count, first and last sung word, gaps, and the one variable that differed from the other takes. List the takes the checks favor first. Say what you cannot hear: style, voice, guitar sustain, bass, drum feel, and whether words sit on the right notes. Ask the user to judge those by ear.
   - The checks cannot see lyric alignment. In this session, word onsets sat within a quarter beat of a plan note throughout, which a dense melody would give by chance, so the measure proves nothing.
   - The user judged each round by ear and changed one thing at a time. Do the same: keep the seed of the take they liked and change one variable per round (style wording, chords, tempo, structure).

9. Finish. List the files you made. If the user is done, offer to delete the older takes and to commit the score, the reharmonized score and the lyrics file. Do both only on their yes.

Known limits:
- SheetSage2 gives the melody and rough chords of one sung line. Dense or heavily layered sources transcribe poorly.
- YuE2 sings its own timing against the plan. The plan fixes notes, key, structure and length, but not which word lands on which note. About 0.6x realtime to render.
- `cover timing` needs the Parakeet word-timestamp model. The ordinary Whisper endpoint returns no word times.
