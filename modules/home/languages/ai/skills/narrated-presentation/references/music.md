# Music: jingle, bumpers, outro and beds

All music comes from one sung take, so the video sounds like one piece.

## The take

Load `yue2-song`. Write a short song (about 75 s) whose chorus shouts the title, with an instrumental stretch and an ending: the bumpers and outro come from the vocal-free parts. Pick a tempo and record it in `music.json` as `bpm`. Copy Jeff's chosen take to `music/take.mp3`.

## Finding cuts

1. `present music-scan music/take.mp3 <bpm>` prints the beat phase, the bar length, and the level of every bar. Bar n starts at `phase + n * bar`; start every cut on one.
2. Opener: the chorus with the title shout, about 20 s, set as `length`. Its card is `opener()` in `_bumper.py`. Make the card's video no longer than its lead plus `length`: the assembler holds the scene for the whole video, so extra video puts silence inside the crossfade and the bed starts out of step, which Jeff hears as a dip. `present music` stops on a mismatch.
3. Bumpers: four bars each (`"bars": 4`) from vocal-free stretches, preferably starting a four-bar phrase. To check a window for vocals, cut it to a wav with ffmpeg and transcribe it with the `stt-transcribe` skill; an empty transcript means no vocals. Parts may reuse windows. A quiet breakdown works as a bumper with `extra_db` (about +5).
4. Outro: from a phrase start to the end of the take (`"to_end": true`), 12-16 s, `"fade_out": 3.0`. A short outro feels abrupt.
5. `gain_window`: the loudest vocal stretch. One gain applies to every cut, set so that stretch sits at `music_lufs` (-19), 1 dB over the -20 LUFS speech. At -22, Jeff found the narration too loud after the jingle (2026-11-09).

## Beds

`present scenes` gives the narrated scene after a music scene a bed and a 1.2 s lead, and the scene before one a pre-roll. `present music` cuts them. The bed continues the take from where the music scene ended, holds full level for 0.9 s, ducks 12 dB by 1.3 s and fades out by 4.5 s, so the song never stops dead before the first words. The pre-roll fades the next cut in over the scene's last 2.2 s, sample-aligned, so the crossfade into a bumper is seamless. Run `present music` after the voice and the visuals, because the pre-roll position depends on the scene's final length.

## Beat sync

A music scene after the opener has lead 0 and starts on a downbeat, so its t = 0 is beat 1. The opener keeps the 0.4 s lead and usually starts mid-bar, so its grid is offset. Set `OPENER_SYNC` in `_bumper.py` to `(0.4 + d) % beat`, where `d = (phase - start) % bar` for the opener's cut `start`; then let Jeff confirm by eye, since a pulse can read as on the beat a few hundredths early. Put every beat-timed element of a scene (pulses, arrivals, a phone filling) on that same grid: one element on its own grid reads as out of time even when the rest is right. `beat_bump()` makes a pulse; `on_beat()` starts an arrival so its ease lands on the beat.

## Levels

`present video check` must show -21 LUFS (Jeff's pick: -20 was a little loud overall) and true peak at or below -2 dBFS. Music scenes skip the speech chain. If speech sounds quiet against the music, check per-clip loudness with `present audio-stats` before touching `music_lufs`.
