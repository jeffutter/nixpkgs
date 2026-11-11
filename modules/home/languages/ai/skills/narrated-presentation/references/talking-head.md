# Talking head (optional)

A lip-synced circle of Jeff in a corner of the narrated scenes, rendered with FlashHead from the final narration. Do this only when Jeff asks for it, after the video is otherwise finished. The output is a second MP4 beside the original, `out/<name>-head.mp4`. The original stays untouched.

Load the `flashhead-video` skill before step 2. It covers the models, the portrait presets and their failures. `present head` calls its tool for you.

## What it costs

- Render time: about 9x the speech length with `pro` at size 384, so 20 minutes of speech takes about 3.3 hours. Tell Jeff the estimate first. Only the speech is rendered, plus one 8 s idle clip.
- `pro` holds the GPU host for the whole run, so Jeff's chat models get evicted.
- Jeff rejected `lite`: the smile looks creepy and the head barely moves. Do not offer it again.
- Size 256 is blurry and the framing drifts. Size 384 matches 512 at the size the head is shown, in half the time.
- Composite: 20-30 minutes of encoding for a 20-minute video.

## Steps

1. `present head timeline out/<name>.mp4`. Reads scenes.json and the assemble work dir. Writes `talking-head/timeline.json` with each scene's start and its narration start. It stops if the times do not add up to the video's length. In that case re-run `present video assemble`.

2. Pilot. Run `present head render <one-scene-id>` in the background. Report the wall time and the rate. Ask Jeff to watch `talking-head/clips/<id>.mp4` before the full batch. The clip's own audio is 16 kHz mono, which is only good enough to drive the lips. It never reaches the output.

3. Batch. Run `present head render` in the background. It skips clips that already exist, so a stopped run resumes. If Jeff asks for updates, schedule `present head progress` (clips done, rate, ETA) every 10 minutes with CronCreate. Delete the cron job when the log ends with `done`.

4. Place. Run `present head place out/<name>.mp4` while the batch runs. For each narrated scene it combines every frame (4 per second, full resolution) into one content mask. It picks the first spot where a 216 px circle, with a 20 px margin, touches nothing:
   - the bottom-right corner first;
   - then the other corners;
   - then positions along the edges;
   - then 192 and 168 px;
   - if nothing fits, the head is hidden for that scene, written as `null`.

   Look at every scene that is not bottom right: `present head sheet out/<name>.mp4 talking-head/sheet.png <id ...>`. Then Read the PNG. If a spot is wrong, edit `talking-head/placement.json` by hand.

5. Preview. Run `present head build out/<name>.mp4 talking-head/preview.mp4 --stand-in talking-head/clips/<pilot>.mp4 --from <s> --to <e>` over a window that has a corner swap. Jeff judges the look before the full composite.

6. Build. Run `present head timeline` after every `video assemble`, then `present head build out/<name>.mp4 out/<name>-head.mp4` in the background. It overlays the head with a soft shadow and a thin ring.
   - It rebuilds the cached head track whenever the timeline or a clip changed (`head-track.inputs.json`). A track built for an older timeline puts every clip after a changed scene out of lip sync.
   - The head fades out into every music scene and back in after it.
   - When the spot changes between scenes, the head crossfades with the slide transition.
   - It copies the audio and caption tracks, sets the captions to off by default, and prints whether they match the input byte for byte. FAIL is a bug: do not hand the video over.

7. Check frames at the corner swaps, the hidden scenes, and the edges of the music scenes. Then report: path, length, the audio PASS, the hidden scenes, and the render time.

Commit `talking-head/placement.json`. Keep `talking-head/clips/` and the other media out of git.

## When something fails

- The composite stops growing and ffmpeg sits at 0% CPU: a branch of the filter graph ended early and blocked the shared split. `build` never trims branches; keep it that way.
- The head covers a thin line: the content mask missed it. Check that `place` still reads full-resolution frames and max-pools them.
- A scene's spot is wrong after a visual changed: run `present head place out/<name>.mp4 <id>` for that scene, then `build`.
- Narration changed: re-run `timeline`. Delete the clips of the re-voiced scenes, then run `render`, `place` (for the changed scenes) and `build`.
