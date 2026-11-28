#!/usr/bin/env node
// Generate a voiceover take with the local speech models.
//
//   local-take.mjs <voiceover-dir> [--seed N] [--model M] [--voice V] [--instruct TEXT]
//
// Reads <voiceover-dir>/provider_script.md and writes raw.mp3 and raw_stt.json
// beside it, ready for `retime.mjs check` and `apply`.
//
// Each stretch of script between [[pause]] markers is synthesized on its own and
// the pieces are joined with silence. In one long request the model silently
// drops short lines.

import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { ttsText } from "./retime.mjs";

const TTS = "@tts@";
const STT = "@stt@";
const CUT = "@@cut@@";
// Silence between pieces. retime.mjs needs at least 0.4s to set a pause.
const GAP_SECONDS = 0.6;

const { values, positionals } = parseArgs({
	allowPositionals: true,
	options: {
		seed: { type: "string", default: String(Math.floor(Math.random() * 100000)) },
		model: { type: "string", default: "breeze" },
		voice: { type: "string", default: "jeff" },
		instruct: {
			type: "string",
			default:
				"Speak in a relaxed, friendly, conversational tone, like explaining something interesting to a colleague.",
		},
	},
});
const [dir] = positionals;
if (!dir || positionals.length !== 1) {
	console.error("usage: local-take.mjs <voiceover-dir> [--seed N] [--model M] [--voice V] [--instruct TEXT]");
	process.exit(2);
}

const pieces = ttsText(readFileSync(join(dir, "provider_script.md"), "utf8"), CUT)
	.split(CUT)
	.map((piece) => piece.trim())
	.filter(Boolean);

const options = [`seed=${values.seed}`];
// Only breeze takes a style instruction, and it ignores it without guidance.
if (values.model === "breeze") options.push(`instruct=${values.instruct}`, "guidance_scale=2");

const work = mkdtempSync(join(tmpdir(), "videowright-voice-"));
try {
	const files = pieces.map((text, i) => {
		console.log(`piece ${i + 1}/${pieces.length}: ${text.slice(0, 60)}`);
		const out = join(work, `${i}.wav`);
		execFileSync(
			TTS,
			["say", "--file", "-", "--model", values.model, "--voice", values.voice, "--format", "wav",
				"--out", out, ...options.flatMap((o) => ["--option", o])],
			{ input: text, stdio: ["pipe", "ignore", "inherit"] },
		);
		return out;
	});

	const raw = join(dir, "raw.mp3");
	const filters = files.map((_, i) =>
		i < files.length - 1 ? `[${i}]apad=pad_dur=${GAP_SECONDS}[a${i}]` : `[${i}]anull[a${i}]`,
	);
	// The models speak quietly: normalize to the usual level for online video.
	filters.push(
		`${files.map((_, i) => `[a${i}]`).join("")}concat=n=${files.length}:v=0:a=1,loudnorm=I=-16:TP=-1.5:LRA=11[out]`,
	);
	execFileSync(
		"ffmpeg",
		["-loglevel", "error", "-y", ...files.flatMap((f) => ["-i", f]), "-filter_complex",
			filters.join(";"), "-map", "[out]", "-ar", "48000", "-c:a", "libmp3lame", "-b:a", "192k", raw],
		{ stdio: "inherit" },
	);

	const words = execFileSync(STT, ["transcribe", raw, "--words"], {
		maxBuffer: 64 * 1024 * 1024,
		stdio: ["ignore", "pipe", "inherit"],
	});
	writeFileSync(join(dir, "raw_stt.json"), words);
	console.log(`Wrote ${raw} and raw_stt.json (model=${values.model} voice=${values.voice} seed=${values.seed})`);
} finally {
	rmSync(work, { recursive: true, force: true });
}
