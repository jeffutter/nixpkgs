---
name: yue2-song
description: Generate full songs with vocals using YuE2 (audio.cpp on the dgx-spark, behind llama-swap) and iterate on them with the user. Use when the user asks to write, generate, or render a song or music with lyrics, or to revise a YuE2 take (style, instruments, meter, melody, arrangement).
---

Use this skill when the user asks for a song with vocals or a revision of a YuE2 take. The end state is MP3 takes in the user's directory, reported with check results, revised until the user stops asking.

Fixed values:
- Tool: `~/.claude/skills/yue2-song/scripts/yue2`. Make every YuE2 call through it. It holds the endpoints, model ids, Python and ffmpeg.
- `yue2 render --lyrics F --style S --seed N --out X.mp3 [--plan P.abc] [--bpm N]` renders one MP3, embeds its recipe, then runs `check`.
- `yue2 plan --lyrics F --style S --seeds 101-124 --dir D` writes `D/plan-<seed>.abc` per seed, about 25s each. It ranks plans whose `M:` matches the meter in the style string first, then by `beat_fit`. `beat_fit` is the share of vocal notes on the beats of the plan's own meter.
- `yue2 check X.mp3... [--bpm N]` prints a pulse verdict and a Whisper lyric check. It reads the BPM and meter that `render` stored.
- `yue2 info X.mp3... [--lyrics]` prints the embedded recipe: seed, BPM, style, plan, timing.
- File name: `<song>-v<round>-<variant>.mp3`, in the directory the user named. Leave the MP3s out of git.
- Plan: the ABC score YuE2 writes, then sings. Without `--plan` (free mode), each render writes a new plan and runs about 3 minutes. With `--plan`, the plan fixes melody, key, structure and length.
- BPM counts quarter notes per minute in every meter.
- Render time: about 0.6x realtime, so a 3 minute song takes about 110s.
- You cannot hear audio. The user judges instrumentation, vocal timbre, accent and arrangement by ear.

Steps:

1. Write the lyrics file.
   - Label sections `[Verse 1]`, `[Chorus]`, `[Bridge]`, `[Final Chorus]`, `[Outro]`.
   - Put arrangement notes inside a label, such as `[Verse 2: brushed drums & cello]`. YuE2 does not sing them.
   - Put backing vocals in parentheses: `dance in your socks (dance, Olive, dance)`.
   - Keep the lyrics short.

2. Write the style string. Order the tags: language, genre, vocal, instruments, mood, production, meter, tempo. Example: `English, chamber Americana, warm low female alto lead vocal, pedal steel guitar and lap steel guitar, tender, bittersweet, polished studio recording, 4/4, 90 BPM`.
   - Write the meter as a fraction, such as "3/4". `plan` and `check` read it from the style string.
   - Spell out the meter's feel in words, such as "in 3/4 time with a one-two-three lilt". A genre word alone can yield the wrong meter.
   - YuE2 takes text only. Describe every sound requirement in words.
   - Describe a reference band's sound instead of naming the band.
   - When the user names a reference artist, search the web for its instrumentation and production first.
   - Name every instrument you want. Leave unwanted instruments out of the string.

3. Pick the mode for round 1.
   - Free mode misses the meter, melody or length the user asked for: do step 4, then skip to step 6.
   - Otherwise: go to step 5.

4. Pin the song with plans.
   - Run `yue2 plan` with `--seeds 101-124`.
   - Pick 3-5 plans from the top of the ranking. Open their .abc files and check that each melody fits the request.
   - Skip plans with `beat_fit` well below the others. Their melody fights the `M:` header and gets sung in another meter.
   - Choose the render BPM. Length becomes `length@Q` times plan `Q:` divided by that BPM.
   - Render each plan with `--plan` and `--bpm`, one at a time, in the background.

5. Render 3-5 takes in free mode, without asking first.
   - Use the same style string with different seeds.
   - Run one render at a time, in the background.

6. Handle a slow or failed render. YuE2 and the user's chat model evict each other on the dgx-spark. Ask the user whether they are chatting, then rerun the render.

7. Read each take's `check` output.
   - The pulse line says whether the take has a simple pulse (2/4, 3/4, 4/4) or a compound pulse (6/8, 9/8, 12/8).
   - MISMATCH means the take's pulse differs from the intended meter. Rank that take lower.
   - The check cannot tell 3/4 from 4/4. Ask the user to judge beats per bar by ear.   - Whisper word count over 1.4x the lyrics means the take likely loops a line at the end.
   - Word count under 0.6x means words are missing or mumbled.
   - Read the `last:` line to see where the take ends.
   - Whisper mishears sung names. Flag a suspicious opening line and let the user decide.

8. Report each take: length, pulse verdict, lyric check, and the one variable that differed. List the takes the checks favor first. Ask the user to judge by ear the qualities you cannot hear. Treat the pulse verdict as a screen and the user's ear as the decision.

9. Iterate on the take the user liked. Keep its seed and change one variable per round.
   - New performance of the same tune: same plan, different seed.
   - Different melody: different plan.
   - Compare wordings: different style strings, same seed.
   - The user asks what differed between takes: run `yue2 info` on them.
   - Go back to step 7 after each round.
