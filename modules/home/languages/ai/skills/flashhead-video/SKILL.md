---
name: flashhead-video
description: Make a talking-head video (MP4) from a portrait image and a speech clip with SoulX-FlashHead (audio.cpp on the dgx-spark, behind llama-swap). Use when the user wants a portrait or avatar to speak a TTS clip, lip-synced video from an image plus audio, or names FlashHead.
---

Use this skill when the user wants a still portrait to talk. The end state is an MP4 (portrait video muxed with the speech) in the directory the user named, reported with the model, size, and run time.

Fixed values:
- Tool: `@flashhead@`. Make every call through it. It holds the endpoint, ssh target, Python and ffmpeg.
- `flashhead PORTRAIT AUDIO OUT.mp4 [--model lite|pro] [--seed N] [--size N]` renders one MP4 and prints its path. Defaults: model `pro`, seed 42, size 512 (square, divisible by 32).
- Input audio can be any format ffmpeg reads. The tool converts it to 16 kHz mono WAV first. The MP4 carries that audio.
- Endpoint: audio.cpp behind the dgx-spark's llama-swap, `http://192.168.10.14:8000`, path `/audioapi/v1/tasks/run`. Override with `FLASHHEAD_API`. Model ids: `audio-cpp/SoulX-FlashHead-Lite`, `audio-cpp/SoulX-FlashHead-Pro`.
- audio.cpp reads only server-local paths, so the tool copies the portrait and the WAV over ssh to `~/audiocpp/io` on the spark (mounted read-only as `/io` in the container). The ssh target is `jeffutter@192.168.10.14`, override with `FLASHHEAD_SSH`. Files stay there under `<out-stem>.wav` and `<out-stem>.<image ext>`, so reusing an output name overwrites them.
- The response is raw RGB frames in base64, about 1.1 GB for 42 s of video. The call is one blocking HTTP request, so run it in the background.
- Output is 25 fps, generated in 24-frame blocks. A partial last block is padded with silence upstream.
- You cannot see or hear the result. The user judges likeness, lip sync, and motion.

Models (measured 2026-11-06 on the 42 s demo clip, 512x512):
- `lite` (Q8 GGUF): about 2.4x clip time of compute, about 3x end to end including a cold model load. Use for drafts and checking a portrait.
- `pro` (Wan VAE): about 16x clip time of compute, about 33x end to end (23 minutes for 42 s). Run from a locally normalized checkpoint, not a packaged GGUF. Use for the final render. The user asked for Pro whenever it works.
- Each model swap costs a load. llama-swap evicts other spark models to make room, so a render can stall if the user is chatting.

Steps:

1. Check the portrait: one clear front-facing face, a normal image file. Check the audio is the final speech clip, since Pro takes long to redo.

2. Render a short draft first when the clip is over about 20 seconds or the portrait is new: cut a 10 second piece with ffmpeg and run it with `--model lite`. Ask the user whether the portrait and motion look right.

3. Render the final with `--model pro`, in the background. Estimate the time up front: clip seconds x 33 (Pro) or x 3 (Lite). Tell the user the estimate.

4. Name files `<subject>-<model>.mp4`. Leave videos out of git.

5. Report the path, model, size, clip length, and wall time. Ask the user to judge likeness, lip sync, and any odd head motion.

6. Iterate one variable per round: `--seed` (untested here: expect it to change the generation), then `--size`, then the portrait.

When something fails:
- `HTTP 404 no router for requested model`: the call reached the homelab llama-swap instead of the spark. Check `FLASHHEAD_API`.
- Timeout or no response for minutes on a first call: the model is loading or the spark is busy. Pro legitimately takes tens of minutes. Check `ssh jeffutter@192.168.10.14 'docker logs --tail 5 audiocpp'` and `nvidia-smi`; high GPU use means it is working.
- ssh or scp errors: the machine running the tool needs ssh access to the spark.
- No video artifacts in the response: the portrait path was not found in the container. The tool copies it to `/io`; confirm `~/audiocpp/io` on the spark has the file.
