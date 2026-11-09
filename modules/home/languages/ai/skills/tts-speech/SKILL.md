---
name: tts-speech
description: Turn text into spoken audio (MP3/WAV) with the homelab text-to-speech models, including Jeff's cloned voice. Use when the user asks to read text aloud, narrate, voice a script or message, make a voice clip, or names Kokoro, Breeze, Higgs, or "my voice".
---

Use this skill when the user wants spoken audio from text. The end state is an audio file in the directory the user named (default: the current directory), reported with the model, voice, and what to listen for.

Fixed values:
- Tool: `@tts@`. Make every call through it. `tts` below means this path.
- Endpoint: llama-swap on the homelab, `https://llama.home.jeffutter.com/v1`. Point at another machine with `tts --api URL ...` or the `TTS_API` environment variable. `--api` goes before the subcommand. URL is a base URL, `host:port`, or a bare host. Use it only when the user names another machine.
- `tts say "TEXT" [--model M] [--voice V] [--format mp3|wav|opus|aac|flac|pcm] [--option KEY=VALUE]... [--file F|-] [--out F]` writes one file and prints its path. Defaults: model `breeze`, voice `jeff`, format `mp3`.
- `tts models` lists the TTS models the endpoint serves right now. Run it when a model name fails.
- You cannot hear audio. The user judges voice likeness, pacing, and emotion by ear.

Models:
- `breeze` (Breeze TTS 2, 3.5B, English/Chinese): the default for Jeff's voice. Calm, even delivery is preset on the `jeff` voice. About 12s for a short line. Weights are non-commercial. Style is set with `--option instruct="..."` plus `--option guidance_scale=N` (see Expressiveness).
- `higgs` (Higgs Audio v3 TTS 4B, 100+ languages): use for non-English text or when the user wants to compare against Breeze. Same `jeff` voice, stock sampling. About 14s for a short line.
- `kokoro` (Kokoro 82M, aliases `tts-1`, `tts`): fast (about 1.5s) and has 54 stock voices, but no cloning. Use for drafts, long text, or when the user wants a voice that is not Jeff's. The default voice is `af_heart`. Voice ids start with `af_`/`am_` (American) or `bf_`/`bm_` (British), female then male. OpenAI voice names (`alloy`, `coral`) are mapped to Kokoro voices by a shim.

Jeff's voice:
- Voices `jeff` (alias of `jeff_long`, a 30s reference) and `jeff_short` (a 5s reference) exist on `breeze` and `higgs`. Use `jeff` unless the user asks for the short one.
- Passing `--voice jeff` to `kokoro` fails or gives a stock voice. Always pair `jeff` with `breeze` or `higgs`.
- Use the cloned voice only for text the user wants in their own voice. Do not use it to put words in Jeff's mouth that go out under a false impression.

Steps:

1. Get the text. Write it as it should be spoken: spell out numbers, symbols, and abbreviations that the model could misread ("3.5B" becomes "three point five B"). Drop markdown, URLs, and code. Spell code words for the ear: "json" as "jason", and join a spelled-out camelCase name with hyphens ("page-you-eye" for pageUI); with spaces, Breeze pauses inside the name.

2. Pick the model.
   - Jeff's voice: `breeze`. Use `higgs` for non-English text.
   - Any other voice, or a quick draft: `kokoro`.
   - Comparing: same text and voice on each model, one call at a time. Each model swap costs a load, and llama-swap evicts other models to make room.

3. Run `tts say` once for a short sample (one or two sentences) when the text is long, and ask the user whether the voice is right before you render the whole thing.

4. Name files `<subject>-<model>-<voice>.<format>`. Leave audio out of git.

5. Report the path, model, voice, and approximate length. Ask the user to judge the qualities you cannot hear: likeness, pacing, mispronounced words. Name the words most likely to be wrong (names, acronyms).

6. Iterate on one variable per round: text wording, then voice, then model. Without `--option seed=N`, two takes of the same text differ slightly. With a seed, the same request gives the same audio on `breeze` and `higgs`. Opus files still differ in bytes, because of a random Ogg stream serial.

Expressiveness (verified through this tool):
- Defaults for Jeff's voice, in order:
  1. `breeze` with `--option instruct="Speak in a relaxed, friendly, conversational tone, like explaining something interesting to a colleague." --option guidance_scale=2`. Use this unless told otherwise.
  2. Backup: `higgs` with `<|prosody:expressive_high|>` at the start of the text.
  3. `higgs` with `<|emotion:enthusiasm|>` at the start only for a really enthusiastic read.
- Breeze `guidance_scale` defaults to 1.0, which turns guidance off. Then `instruct` barely changes the audio. 2 is the chosen middle. 4 is over the top and can sound less like Jeff.
- Higgs ignores `instruct`. It takes inline tags in the text, `<|category:tag|>`: `<|emotion:...|>`, `<|prosody:expressive_high|>`, `<|prosody:pause|>`, `<|sfx:laughter|>Haha`. Emotion and prosody tags go at the start of a sentence.
- Breeze card lists `(laugh)`, `(cough)`, `(sigh)` as text tags. The sound is unchecked by ear.
- `--option seed=N` makes a take repeatable. Use one seed to compare settings.
- `exaggeration` is ignored. `speed` returns HTTP 500 on `breeze`.
- Sandbox: `tts` downloads with curl and retries a short body. Urllib got truncated audio through the egress proxy. Observed, cause unknown.

When something fails:
- Timeout or a slow first call: the model is loading, or the user's chat model and TTS are evicting each other. Wait, then rerun. Ask the user whether they are chatting if it repeats.
- `unknown ... voice id` or a 400 on voice: the voice does not exist on that model. Pair `jeff` with `breeze` or `higgs` only.
- Model not found: run `tts models` and use a name it prints.
