---
name: flashhead-video
description: Make a talking-head video (MP4) from a portrait image and a speech clip with SoulX-FlashHead (audio.cpp on the GPU host, behind llama-swap). Use when the user wants a portrait or avatar to speak a TTS clip, lip-synced video from an image plus audio, or names FlashHead.
---

Use this skill when the user wants a still portrait to talk. The end state is an MP4 (portrait video muxed with the speech) in the directory the user named, reported with the model, size, and run time.

Fixed values:
- Tool: `@flashhead@`. Make every call through it. It holds the endpoint, ssh target, Python and ffmpeg.
- `flashhead PORTRAIT AUDIO OUT.mp4 [--model lite|pro] [--seed N] [--size N]` renders one MP4 and prints its path. `PORTRAIT` is `preset:NAME` or a local image file.
- `flashhead portraits` lists the presets (`preset:jeff-desk`, `preset:demo`). Use a preset by default for Jeff: `preset:jeff-desk`. Defaults: model `pro`, seed 42, size 512 (square, divisible by 32).
- Input audio can be any format ffmpeg reads. The tool converts it to 16 kHz mono WAV first. The MP4 carries that audio.
- Endpoint: audio.cpp behind the talking-head host's llama-swap, `@talkingHeadApi@`, path `/audioapi/v1/tasks/run`. Preconfigured in `TALKING_HEAD_API`. Model ids: `audio-cpp/SoulX-FlashHead-Lite`, `audio-cpp/SoulX-FlashHead-Pro`.
- The speech goes to the server inline over HTTP (`audio_base64`), so audio needs no ssh. The portrait cannot: audio.cpp's `reference_image_file` is a server-local path only (a `data:` URI fails with HTTP 500, checked 2026-11-06 on v0.9.4).
- Presets are PNGs baked into the GPU host's container at `/portraits/<name>.png`, built from the `portraits/` directory of the host's deployment config. To add one: put `<name>.png` (square, a clear front-facing head and shoulders) in `portraits/`, commit, and redeploy the GPU host. PNG only; the build fails on anything else.
- A local image file is copied over ssh to `~/audiocpp/io` on the GPU host (mounted read-only as `/io`) as `<out-stem>.<ext>`, so reusing an output name overwrites it. The ssh target is `@talkingHeadSsh@`, preconfigured in `TALKING_HEAD_SSH`. `flashhead portraits` also uses ssh.
- The response is raw RGB frames in base64, about 1.1 GB for 42 s of video. The call is one blocking HTTP request, so run it in the background.
- Output is 25 fps, generated in 24-frame blocks. A partial last block is padded with silence upstream.
- You cannot see or hear the result. The user judges likeness, lip sync, and motion.

Models (measured 2026-11-06 on the 42 s demo clip, 512x512):
- `lite` (Q8 GGUF): about 2.4x clip time of compute, about 3x end to end including a cold model load. Use for drafts and checking a portrait.
- `pro` (Wan VAE): about 16x clip time of compute, about 33x end to end (23 minutes for 42 s). Size trades time for quality (Pro, 10 s clip, warm, GPU otherwise idle, 2026-11-06): `--size 512` 170 s (17x), `--size 384` 84 s (8.4x), `--size 256` 33 s (3.3x). Jeff's verdict by eye: 512 is clearly best, 384 is passable. 256 was timed but not rated. Default to 512 for finals; offer 384 when time matters or for a long timeline. A cold model load adds minutes on the first call after a swap. The 42 s demo took 33x at 512, which likely included a cold load; use about 17x warm and 33x as the cautious upper bound. Run from a locally normalized checkpoint, not a packaged GGUF. Use for the final render. The user asked for Pro whenever it works.
- Each model swap costs a load. llama-swap evicts other models on the GPU host to make room, so a render can stall if the user is chatting.

Steps:

1. Check the portrait: one clear front-facing face, a normal image file. Check the audio is the final speech clip, since Pro takes long to redo.

2. Render a short draft first when the clip is over about 20 seconds or the portrait is new: cut a 10 second piece with ffmpeg and run it with `--model lite`. Ask the user whether the portrait and motion look right.

3. Render the final with `--model pro` at `--size 512`, in the background. Estimate the time up front: clip seconds x 17 warm, x 33 cautious (Pro 512); x 8.4 at `--size 384`; x 3 (Lite 512). Tell the user the estimate. Check that nothing else is using the GPU host first (`curl -s @talkingHeadApi@/running`, `nvidia-smi`): a concurrent job inflated one run by 50%.

4. Name files `<subject>-<model>.mp4`. Leave videos out of git.

5. Report the path, model, size, clip length, and wall time. Ask the user to judge likeness, lip sync, and any odd head motion.

6. Iterate one variable per round: `--seed` (untested here: expect it to change the generation), then `--size`, then the portrait.

Narration timeline (several clips with gaps, head on screen the whole time):

Each clip starts from the same portrait, so clips differ only in motion. Do not render the gaps as part of one long audio file: that costs Pro time on silence and makes one line impossible to redo. Render the speech clips and one idle clip, then composite. Steps 1-4 were run end to end with `lite` on 2026-11-06 and gave a head track exactly as long as the timeline. Whether the seams look good was not judged by eye, so show the user the result.

1. Fix the timeline: each narration clip's start time `S` (seconds) and length `D`, and the total length `T`. Get `D` with `ffprobe -v error -show_entries format=duration -of csv=p=0 clip.mp4`.

2. Render every speech clip with the same `--model`, `--seed`, `--size` and portrait. Render the idle clip the same way from a silent WAV at least as long as the longest gap, and at least a few seconds: `ffmpeg -f lavfi -i anullsrc=r=16000:cl=mono -t 8 silence.wav`, then `flashhead portrait.png silence.wav idle.mp4`. Silent audio does not freeze the head (measured frame-to-frame motion 0.37 against 1.47 for speech), so it gives idle motion.

3. Build the idle loop for the whole timeline. Playing it forward and backward avoids a jump at the loop point. `loop` size is the frame count of one forward-and-back pass (25 fps x idle seconds x 2):

   `ffmpeg -i idle.mp4 -filter_complex "[0:v]split[a][b];[b]reverse[r];[a][r]concat=n=2:v=1:a=0,loop=loop=-1:size=300:start=0,trim=duration=$T,setpts=PTS-STARTPTS,fps=25[v]" -map "[v]" -an idleloop.mp4`

4. Lay each speech clip over the idle loop at its start time with a short alpha fade at both ends (0.2 s), and place the narration audio at the same offsets. One chain per clip, `st` of the fade-out is `D - 0.2`, the offset is `S`:

   ```
   ffmpeg -i idleloop.mp4 -i clip1.mp4 -i clip2.mp4 -i clip1.wav -i clip2.wav -filter_complex "
   [1:v]format=yuva420p,fade=t=in:st=0:d=0.2:alpha=1,fade=t=out:st=3.8:d=0.2:alpha=1,setpts=PTS-STARTPTS+S1/TB[c1];
   [2:v]format=yuva420p,fade=t=in:st=0:d=0.2:alpha=1,fade=t=out:st=3.8:d=0.2:alpha=1,setpts=PTS-STARTPTS+S2/TB[c2];
   [0:v][c1]overlay=eof_action=pass[v1];
   [v1][c2]overlay=eof_action=pass,format=yuv420p[v];
   [3:a]adelay=S1ms|S1ms[a1];[4:a]adelay=S2ms|S2ms[a2];
   [a1][a2]amix=inputs=2:normalize=0:duration=longest,apad,atrim=duration=$T[a]" \
    -map "[v]" -map "[a]" -c:v libx264 -crf 18 -c:a aac -t $T head-track.mp4
   ```
   Replace `S1`, `S2` with seconds in `setpts` and with milliseconds in `adelay`; add one `[N:v]...[cN]` chain, one overlay step and one `adelay` per extra clip. Use the original WAVs for the audio inputs.

5. Composite the head track over the screen recording. Scale it and place it in a corner. Use `enable` to hide the head during full-screen sections (here 8.5 s to 10.5 s). For several sections, join the `between()` terms with `+` inside `not(...)`:

   `ffmpeg -i screen.mp4 -i head-track.mp4 -filter_complex "[1:v]scale=240:240[h];[0:v][h]overlay=W-w-24:H-h-24:enable='not(between(t,8.5,10.5))'[v]" -map "[v]" -map 1:a -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a copy out.mp4`

   Use the screen recording's own audio only if the user wants it mixed in; the command above uses the narration alone.

Motion control (asked 2026-11-06: "head too still, mouth moves too much"):
- FlashHead v0.9.4 has no prompt, pose or motion option. The request options are `reference_image_file`, `width`, `height`, `num_inference_steps`, `seed`, `color_correction_strength` and `audio_guidance_scale`. The last is ignored by the distilled Lite and Pro checkpoints, and color correction only matches colors.
- Measured on a 10 s Lite clip (jeff-desk): forehead/hair frame-to-frame change was about 0.4x the mouth's, and seed 7 (0.42), 2 steps (0.44) and 8 steps (0.37) against 0.41 at the default did not move it. Crude metric, not a judgement of how it looks. Do not tell the user a seed or step count will fix stillness.
- Pro moves the head noticeably better than Lite (Jeff's judgement by eye, 2026-11-06, same 10 s clip and jeff-desk portrait; not measured). Use Pro for anything where head motion matters, and do not judge motion from a Lite draft. Lite drafts are for checking the portrait crop and lip sync only.
- Untested levers: a reference portrait with a more expressive or turned pose, and speech with more varied prosody. Post-processing the head track with a slow ffmpeg sway (a few degrees of `rotate`, a slight scale and shift) is cheap but adds fake motion, not lip-synced motion.

Seams and limits:
- The fade blends two heads whose pose and blink can differ, so a brief ghost at each seam is possible. A longer fade (0.3-0.4 s) trades that for a softer look. Use the same seed and model for idle and speech so the likeness matches.
- If a seam looks bad, shorten the gap by moving the clip, or render the speech-gap-speech stretch as one WAV with silence for that stretch only.
- A round or masked head overlay needs a mask filter before step 5; not tried.
- Estimate Pro time from the speech seconds only (rates in step 3 of the main steps), plus one idle clip. Use `--size 384` for the idle clip and speech alike only if the whole track uses it; mixed sizes will not overlay cleanly.

When something fails:
- `HTTP 404 no router for requested model`: the call reached a different llama-swap than the GPU host's. Check `TALKING_HEAD_API`.
- Timeout or no response for minutes on a first call: the model is loading or the GPU host is busy. Pro legitimately takes tens of minutes. Check `ssh @talkingHeadSsh@ 'docker logs --tail 5 audiocpp'` and `nvidia-smi`; high GPU use means it is working.
- ssh or scp errors: only local image files and `flashhead portraits` use ssh; the machine running the tool needs ssh access to the GPU host for those. `preset:` renders do not.
- HTTP 500 `Cannot read FlashHead portrait`: the portrait path is not in the container. For a preset, run `flashhead portraits` and check the name (a new preset needs a GPU host redeploy). For a local file, confirm `~/audiocpp/io` on the GPU host has it.
