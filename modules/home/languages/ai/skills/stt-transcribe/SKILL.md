---
name: stt-transcribe
description: Transcribe audio files (voice memos, recordings, MP3/M4A/WAV) to text with the homelab speech-to-text models. Use when the user gives an audio file and asks what is said, wants a transcript, or wants to check a generated voice clip or song against its script.
---

Use this skill when the user wants text from audio. The end state is the transcript, reported with the model used and any words you doubt.

Fixed values:
- Tool: `@stt@`. Make every call through it. `stt` below means this path.
- Endpoint: llama-swap on the homelab, `https://llama.home.jeffutter.com/v1`. Point at another machine with `stt --api URL ...` or the `STT_API` environment variable. `--api` goes before the subcommand. Use it only when the user names another machine.
- `stt transcribe FILE... [--model M] [--language L] [--json]` prints each transcript to stdout and the model and timing to stderr. With several files, each transcript follows a `== path` line. `--json` prints the full response.
- `stt models` lists the speech-to-text models the endpoint serves. Run it when a model name fails.
- Any common audio format works. The server converts to 16 kHz mono itself, so do not pre-convert.

Models:
- `parakeet` (Parakeet TDT 0.6B v3; also answered by `stt` and `whisper-1`): the default. Very fast (a short clip takes about 0.1s) and strong on English and other European languages. Output has punctuation.
- `crisperwhisper`: slower (about 1x realtime on short clips) and more verbatim, so it keeps fillers and false starts. Use it when the user wants a word-for-word transcript. Its weights are non-commercial.
- `nemotron-asr`: multilingual alternative. It sometimes merges words and doubles spaces after periods. Use it only to compare.

Steps:

1. Run `stt transcribe` with the default model. Pass `--language` only when the audio is not English.

2. Read the transcript against what you know. Names, acronyms, and technical terms are the likeliest errors. Name each one you doubt in your report instead of silently fixing it.

3. When the user needs verbatim text, or the transcript looks cleaned up too much, rerun with `--model crisperwhisper` and report the differences.

4. Report the transcript, or the path of the file you saved it to when it is long. Save a long transcript as `<audio-name>.txt` beside the audio. Leave audio and transcripts out of git.

5. To check a generated clip against its script, transcribe it and compare word by word. Whisper-style models mishear unusual names, so flag mismatches for the user's ear instead of declaring a failure.

When something fails:
- Timeout or a slow first call: the model is loading, or the user's chat model evicts it. Wait, then rerun.
- `HTTP 400` on a valid file: the file may be empty or truncated. Check its size and duration with ffprobe.
- Model not found: run `stt models` and use a name it prints.
