/**
 * thinking-router: picks the thinking level for every model turn with a Jev classifier.
 *
 * When a prompt arrives, the recent conversation and the prompt go to a Jev
 * `choice` question. After each turn that ends in tool calls, the question is
 * asked again with the fresh tool results, so reading test output or a grep hit
 * gets its own level instead of inheriting the prompt's. Once the run settles,
 * the level the session had before (what pi "asked for") comes back. If Jev is
 * slow or failing, that turn uses pi's level.
 *
 * The configured `levels` form a ladder, minus any rung the current model marks
 * unsupported in its thinkingLevelMap. The router moves at most one rung from
 * pi's level, so a level chosen on purpose (by hand, `--thinking`, a subagent's
 * `thinking` parameter) still anchors the run. With the default ladder, xhigh
 * can become medium, medium can become xhigh or low, and so on.
 *
 * Changing the thinking level by hand mid-run stops routing for the rest of that
 * run, and the hand-picked level is kept.
 *
 * Every decision is written to ~/.pi/agent/thinking-router/decisions.jsonl and
 * to the session as a custom entry, so `/thinking-router stats` can compare what
 * pi asked for against what was actually sent.
 *
 * Optional overrides live in ~/.pi/agent/thinking-router.json; any subset of:
 *   { "url", "model", "timeoutMs", "maxStateTokens", "instructions", "turnInstructions",
 *     "levels": [{ "level": "xhigh", "description": "..." }, ...] }
 * `levels` is ordered from most to least reasoning and is the only set of levels
 * the router will ever send. "none" is accepted as an alias for pi's "off".
 *
 * Commands: /thinking-router [on|off|status|stats]. on/off apply to the current
 * session and survive resume.
 */

import { appendFileSync, existsSync, mkdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { getAgentDir } from "@earendil-works/pi-coding-agent";

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
const THINKING_LEVELS: readonly string[] = ["off", "minimal", "low", "medium", "high", "xhigh", "max"];

interface LevelOption {
	level: ThinkingLevel;
	description: string;
}

interface Config {
	url: string;
	model: string;
	timeoutMs: number;
	/** Budget for the `state` payload. Jev rejects decider-4b state over 1536 tokens, and latency grows with size. */
	maxStateTokens: number;
	/** Question for a new user prompt. */
	instructions: string;
	/** Question for a follow-up turn inside a run, after tool results come back. */
	turnInstructions: string;
	levels: LevelOption[];
}

const DEFAULT_CONFIG: Config = {
	url: "https://llama.home.jeffutter.com/v1/systemone",
	model: "decider-4b",
	timeoutMs: 2000,
	// ~1000 chars. Jev latency scales with total input at ~1.9ms/token, and the uncached
	// instructions alone are ~285 tokens (~0.66s). At 1000 tokens almost every mid-run turn
	// in a long session hit the 2s timeout. At 500, the densest tool output measured
	// (hashes/paths, ~1.3 chars/token) takes ~1.8s, and typical output ~1.3-1.5s.
	maxStateTokens: 500,
	instructions:
		"The state is a coding agent session: recent history plus the latest user prompt. " +
		"Pick how much hidden reasoning the agent should spend on the latest prompt. " +
		"Tasks that need tool use or code changes need at least low. " +
		"When unsure between two levels, choose the higher one.",
	turnInstructions:
		"The state is a coding agent session in the middle of working on the user's task. " +
		"The end of history shows the results of the agent's latest tool calls. " +
		"Pick how much hidden reasoning the agent should spend on its next step: interpreting those results " +
		"and deciding what to do. Routine, expected results need little; surprising results, failures, " +
		"or hard decisions need more. When unsure between two levels, choose the higher one.",
	levels: [
		{
			level: "xhigh",
			description:
				"Hard or open-ended: designing features or architecture, multi-file refactors, debugging a failure " +
				"with an unknown cause, code review, security/concurrency/performance analysis, planning multi-step work.",
		},
		{
			level: "medium",
			description:
				"Moderate, well-scoped: a focused change in a known place, writing a small function or test, " +
				"explaining how code works, a technical question that needs some thought.",
		},
		{
			level: "low",
			description:
				"Mechanical: run a command or the tests, commit, show or rename something, simple lookups, " +
				"or continuing an already-planned task (e.g. 'yes', 'go ahead', 'next').",
		},
		{
			level: "off",
			description:
				"Pure social reply with nothing to look at or do: thanks, greetings, acknowledgements. " +
				"Never for questions about code.",
		},
	],
};

/**
 * Rough chars-per-token for the state JSON. Prose measures ~3.3 against decider-4b,
 * but real tool output (hashes, paths, JSON) came in near 2: at 3.2, full-budget
 * states were 1543-1745 tokens and Jev rejected them with HTTP 422. The budget is
 * sized so even ~1.3 chars/token output stays well under Jev's 1536-token cap.
 */
const CHARS_PER_TOKEN = 2;

/** History lines copied into each logged decision's `sent.tail`. */
const SENT_TAIL_ITEMS = 4;

const ENTRY_DECISION = "thinking-router-decision";
const ENTRY_TOGGLE = "thinking-router-toggle";
const STATUS_KEY = "thinking-router";

type Outcome = "routed" | "timeout" | "error";
/** "prompt": a new user prompt starting a run. "turn": a follow-up model call inside a run. */
type Trigger = "prompt" | "turn";

interface Decision {
	ts: string;
	sessionId: string;
	cwd: string;
	model: string | undefined;
	outcome: Outcome;
	/** Missing on entries logged before per-turn routing existed; those were all prompts. */
	trigger?: Trigger;
	turnIndex?: number;
	/** Level the session had before routing: what pi would have sent. */
	requested: ThinkingLevel;
	/** Levels the router could send this turn: the requested rung and its neighbors. */
	allowed?: ThinkingLevel[];
	/** Level the classifier picked, before clamping to `allowed`. */
	chosen?: ThinkingLevel;
	/** Level actually in effect for the turn. */
	applied: ThinkingLevel;
	latencyMs?: number;
	probabilities?: Record<string, number>;
	confidence?: number;
	inputTokens?: number;
	error?: string;
	/** The prompt that started the run, also for "turn" decisions. */
	prompt: string;
	/**
	 * A peek at the state sent to Jev: its size, and the last few history lines
	 * flattened and clipped. For a "turn" decision those are the tool calls and
	 * the start of their output, which is what the classifier is reacting to.
	 */
	sent?: { historyItems: number; chars: number; tail: string[] };
}

function loadConfig(): Config {
	const path = join(getAgentDir(), "thinking-router.json");
	if (!existsSync(path)) return DEFAULT_CONFIG;
	try {
		const raw = JSON.parse(readFileSync(path, "utf-8")) as Partial<Config>;
		const levels = (raw.levels ?? DEFAULT_CONFIG.levels).map((l) => ({
			level: (l.level === ("none" as string) ? "off" : l.level) as ThinkingLevel,
			description: l.description,
		}));
		const bad = levels.find((l) => !THINKING_LEVELS.includes(l.level));
		if (bad) throw new Error(`unknown thinking level "${bad.level}"`);
		if (levels.length < 2 || levels.length > 10) throw new Error("levels must have 2-10 entries");
		return { ...DEFAULT_CONFIG, ...raw, levels };
	} catch (err) {
		console.error(`thinking-router: ignoring ${path}: ${err}`);
		return DEFAULT_CONFIG;
	}
}

function clip(text: string, max: number): string {
	if (text.length <= max) return text;
	// Keep both ends: the ask is usually at the start, and pasted errors often end with the key line.
	const head = Math.ceil(max * 0.7);
	return `${text.slice(0, head)} ... ${text.slice(text.length - (max - head))}`;
}

/** One history line per message, dropping thinking and images, which cost budget without saying much about the next step. */
function renderMessage(message: any): { role: string; text: string } | undefined {
	const parts = (content: unknown): string => {
		if (typeof content === "string") return content;
		if (!Array.isArray(content)) return "";
		return content
			.map((c: any) => {
				if (c.type === "text") return c.text;
				if (c.type === "toolCall") return `[tool ${c.name} ${clip(JSON.stringify(c.arguments ?? {}), 160)}]`;
				return "";
			})
			.filter(Boolean)
			.join("\n");
	};
	switch (message.role) {
		case "user":
			return { role: "user", text: clip(parts(message.content), 600) };
		case "assistant":
			return { role: "assistant", text: clip(parts(message.content), 500) };
		case "toolResult":
			// Wider than other lines would suggest: for a follow-up turn this output is the main signal.
			return { role: "tool", text: clip(parts(message.content), 400) };
		case "bashExecution":
			return { role: "user-shell", text: clip(`$ ${message.command}\n${message.output}`, 200) };
		case "compactionSummary":
		case "branchSummary":
			return { role: "summary", text: clip(message.summary, 400) };
		default:
			return undefined;
	}
}

/**
 * Newest history first until the budget runs out, then restore chronological order.
 *
 * For a new prompt, the prompt is what's being judged, so it comes last and gets up
 * to half the budget (a huge paste can't crowd out all context). For a follow-up turn
 * the prompt is only background: it comes first as `task` and gets a quarter, leaving
 * room for the tool results at the end of history.
 */
function buildState(ctx: ExtensionContext, trigger: Trigger, prompt: string, maxTokens: number) {
	const budget = maxTokens * CHARS_PER_TOKEN;
	const promptText = clip(prompt, Math.floor(budget / (trigger === "prompt" ? 2 : 4)));
	let remaining = budget - promptText.length - 40;

	const history: { role: string; text: string }[] = [];
	const entries = ctx.sessionManager.buildContextEntries();
	for (let i = entries.length - 1; i >= 0 && remaining > 0; i--) {
		const entry = entries[i];
		if (entry.type !== "message") continue;
		const line = renderMessage(entry.message);
		if (!line || !line.text.trim()) continue;
		const cost = line.text.length + line.role.length + 20;
		if (cost > remaining) break;
		remaining -= cost;
		history.push(line);
	}
	history.reverse();
	return trigger === "prompt" ? { history, prompt: promptText } : { task: promptText, history };
}

/**
 * The configured levels this model can actually run, still most-reasoning first.
 * A model's thinkingLevelMap marks unsupported levels with null; offering those
 * to Jev would only produce picks that pi silently clamps to something else.
 */
function ladderFor(config: Config, model: ExtensionContext["model"]): LevelOption[] {
	const map = (model as { thinkingLevelMap?: Record<string, string | null> } | undefined)?.thinkingLevelMap;
	return config.levels.filter((l) => map?.[l.level] !== null);
}

/**
 * Index of the ladder rung closest to `level` in pi's full level order, ties going
 * to the higher rung. Handles levels off the ladder, like "high" set by hand or
 * "max" from `--thinking`, by anchoring on the nearest configured one.
 */
function rungFor(ladder: LevelOption[], level: ThinkingLevel): number {
	const rank = (l: ThinkingLevel) => THINKING_LEVELS.indexOf(l);
	let best = 0;
	for (let i = 1; i < ladder.length; i++) {
		if (Math.abs(rank(ladder[i].level) - rank(level)) < Math.abs(rank(ladder[best].level) - rank(level))) best = i;
	}
	return best;
}

async function classify(
	config: Config,
	levels: LevelOption[],
	trigger: Trigger,
	state: unknown,
	signal: AbortSignal | undefined,
): Promise<{ chosen: ThinkingLevel; probabilities: Record<string, number>; confidence: number; inputTokens?: number }> {
	const criteria = Object.fromEntries(levels.map((l) => [l.level, l.description]));
	const timeout = AbortSignal.timeout(config.timeoutMs);
	const res = await fetch(config.url, {
		method: "POST",
		headers: { "content-type": "application/json" },
		body: JSON.stringify({
			model: config.model,
			state,
			questions: {
				effort: {
					type: "choice",
					instructions: trigger === "prompt" ? config.instructions : config.turnInstructions,
					criteria,
				},
			},
		}),
		// Tied to the run's signal so pressing Esc mid-run doesn't wait on Jev.
		signal: signal ? AbortSignal.any([timeout, signal]) : timeout,
	});
	if (!res.ok) throw new Error(`HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`);
	const body = (await res.json()) as any;
	const answer = body?.answers?.effort;
	const probabilities: Record<string, number> | undefined = answer?.probabilities;
	if (!probabilities) throw new Error(`unexpected response: ${JSON.stringify(body).slice(0, 200)}`);

	// Most likely level, ties going to more reasoning. An earlier cumulative rule that leaned
	// toward more thinking turned mid-run answers like low .54 / medium .28 / xhigh .17 into
	// medium, hiding most "low" calls; the +/-1 window around pi's level is the guard now.
	let chosen = levels[0].level;
	for (const { level } of levels) {
		if ((probabilities[level] ?? 0) > (probabilities[chosen] ?? 0)) chosen = level;
	}
	return { chosen, probabilities, confidence: answer.confidence, inputTokens: body?.usage?.input_tokens };
}

function logPath(): string {
	return join(getAgentDir(), "thinking-router", "decisions.jsonl");
}

function readLog(): Decision[] {
	const path = logPath();
	if (!existsSync(path)) return [];
	return readFileSync(path, "utf-8")
		.split("\n")
		.filter(Boolean)
		.flatMap((line) => {
			try {
				return [JSON.parse(line) as Decision];
			} catch {
				return [];
			}
		});
}

function summarize(label: string, decisions: Decision[]): string {
	if (decisions.length === 0) return `${label}: no decisions yet`;
	const count = (pred: (d: Decision) => boolean) => decisions.filter(pred).length;
	const pct = (n: number) => `${Math.round((100 * n) / decisions.length)}%`;
	const routed = decisions.filter((d) => d.outcome === "routed");
	const latencies = decisions
		.map((d) => d.latencyMs)
		.filter((n): n is number => n !== undefined)
		.sort((a, b) => a - b);
	const quantile = (q: number) => latencies[Math.min(latencies.length - 1, Math.floor(q * latencies.length))];

	const pairs = new Map<string, number>();
	for (const d of routed) {
		const key = `${d.trigger ?? "prompt"}: ${d.requested} -> ${d.applied}`;
		pairs.set(key, (pairs.get(key) ?? 0) + 1);
	}
	const applied = new Map<string, number>();
	for (const d of decisions) applied.set(d.applied, (applied.get(d.applied) ?? 0) + 1);

	const prompts = count((d) => (d.trigger ?? "prompt") === "prompt");
	const lines = [
		`${label}: ${decisions.length} decisions (${prompts} prompts, ${decisions.length - prompts} follow-up turns)`,
		`  routed ${pct(routed.length)}, timeout ${pct(count((d) => d.outcome === "timeout"))}, ` +
			`error ${pct(count((d) => d.outcome === "error"))}`,
		`  changed from requested: ${pct(count((d) => d.requested !== d.applied))}, ` +
			`held back by the +/-1 window: ${pct(count((d) => d.allowed !== undefined && d.chosen !== undefined && d.chosen !== d.applied))}`,
	];
	if (latencies.length > 0) lines.push(`  latency p50 ${quantile(0.5)}ms, p95 ${quantile(0.95)}ms`);
	lines.push(
		`  sent: ${[...applied.entries()]
			.sort((a, b) => b[1] - a[1])
			.map(([k, v]) => `${k} ${v}`)
			.join(", ")}`,
	);
	for (const [pair, n] of [...pairs.entries()].sort((a, b) => b[1] - a[1])) lines.push(`  ${pair}: ${n}`);
	return lines.join("\n");
}

export default function thinkingRouter(pi: ExtensionAPI) {
	let enabled = true;
	/**
	 * The run being routed. `requested` is pi's level when the run started and is
	 * what comes back at the end; `applied` is what the router last set, used to
	 * notice a hand change (the level no longer matches what we set).
	 */
	let run: { prompt: string; requested: ThinkingLevel; applied: ThinkingLevel } | undefined;

	function endRun(ctx: ExtensionContext) {
		if (!run) return;
		if (pi.getThinkingLevel() === run.applied && run.applied !== run.requested) pi.setThinkingLevel(run.requested);
		run = undefined;
		ctx.ui.setStatus(STATUS_KEY, enabled ? undefined : "think-router off");
	}

	function record(ctx: ExtensionContext, decision: Decision) {
		pi.appendEntry(ENTRY_DECISION, decision);
		try {
			mkdirSync(join(getAgentDir(), "thinking-router"), { recursive: true });
			appendFileSync(logPath(), `${JSON.stringify(decision)}\n`);
		} catch (err) {
			ctx.ui.notify(`thinking-router: failed to write metrics: ${err}`, "warning");
		}
	}

	/** Classify and set the level for the next model call. Any failure falls back to pi's level. */
	async function route(ctx: ExtensionContext, trigger: Trigger, turnIndex?: number) {
		if (!run) return;
		const current = run;
		const config = loadConfig();
		const ladder = ladderFor(config, ctx.model);
		if (ladder.length < 2) return;
		const rung = rungFor(ladder, current.requested);
		const lo = Math.max(0, rung - 1);
		const hi = Math.min(ladder.length - 1, rung + 1);
		const allowed = ladder.slice(lo, hi + 1).map((l) => l.level);
		const base = {
			ts: new Date().toISOString(),
			sessionId: ctx.sessionManager.getSessionId(),
			cwd: ctx.cwd,
			model: ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : undefined,
			trigger,
			turnIndex,
			requested: current.requested,
			allowed,
			prompt: current.prompt.slice(0, 200),
		};

		const started = Date.now();
		let level = current.requested;
		let decision: Decision;
		let sent: Decision["sent"];
		try {
			const state = buildState(ctx, trigger, current.prompt, config.maxStateTokens);
			sent = {
				historyItems: state.history.length,
				chars: JSON.stringify(state).length,
				tail: state.history.slice(-SENT_TAIL_ITEMS).map((h) => `${h.role}: ${clip(h.text.replace(/\s+/g, " "), 100)}`),
			};
			// Jev sees the whole ladder so its pick stays comparable across requested
			// levels in the log; the window only bounds what gets applied.
			const result = await classify(config, ladder, trigger, state, ctx.signal);
			const pick = ladder.findIndex((l) => l.level === result.chosen);
			level = ladder[Math.min(hi, Math.max(lo, pick))].level;
			decision = {
				...base,
				outcome: "routed",
				chosen: result.chosen,
				applied: level,
				latencyMs: Date.now() - started,
				probabilities: result.probabilities,
				confidence: result.confidence,
				inputTokens: result.inputTokens,
				sent,
			};
		} catch (err: any) {
			// The user aborted the run; there's no next turn to route and nothing worth logging.
			if (ctx.signal?.aborted) return;
			const timedOut = err?.name === "TimeoutError";
			decision = {
				...base,
				outcome: timedOut ? "timeout" : "error",
				applied: level,
				latencyMs: Date.now() - started,
				error: timedOut ? undefined : String(err?.message ?? err),
				sent,
			};
		}
		// The run may have ended or been taken over by a hand change while Jev was answering.
		if (run !== current) return;

		pi.setThinkingLevel(level);
		current.applied = pi.getThinkingLevel() as ThinkingLevel;
		decision.applied = current.applied;
		const note =
			decision.outcome === "routed" ? (current.applied === current.requested ? "" : ` (pi ${current.requested})`)
			: ` (router ${decision.outcome})`;
		ctx.ui.setStatus(STATUS_KEY, `think ${current.applied}${note}`);
		record(ctx, decision);
	}

	pi.on("session_start", async (_event, ctx) => {
		enabled = true;
		run = undefined;
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type === "custom" && entry.customType === ENTRY_TOGGLE) {
				enabled = (entry.data as { enabled: boolean }).enabled;
			}
		}
		ctx.ui.setStatus(STATUS_KEY, enabled ? undefined : "think-router off");
	});

	pi.on("before_agent_start", async (event, ctx) => {
		// A previous run that never settled (crash, abort path) must not leak its level into this one.
		endRun(ctx);
		if (!enabled || !ctx.model?.reasoning) return;
		const requested = pi.getThinkingLevel() as ThinkingLevel;
		run = { prompt: event.prompt, requested, applied: requested };
		await route(ctx, "prompt");
	});

	pi.on("turn_end", async (event, ctx) => {
		if (!run) return;
		if (pi.getThinkingLevel() !== run.applied) {
			// Hand change mid-run: keep it for the rest of the run and don't restore over it.
			run = undefined;
			ctx.ui.setStatus(STATUS_KEY, undefined);
			return;
		}
		// Only route when another model call follows: tool results to process or queued user messages.
		const message = event.message as { role: string; stopReason?: string };
		const continues = (message.role === "assistant" && message.stopReason === "toolUse") || ctx.hasPendingMessages();
		if (continues) await route(ctx, "turn", event.turnIndex);
	});

	pi.on("agent_settled", async (_event, ctx) => endRun(ctx));
	pi.on("session_shutdown", async (_event, ctx) => endRun(ctx));

	pi.registerCommand("thinking-router", {
		description: "Route thinking level per turn: on | off | status | stats",
		getArgumentCompletions: (prefix: string) =>
			["on", "off", "status", "stats"]
				.filter((s) => s.startsWith(prefix))
				.map((s) => ({ value: s, label: s })),
		handler: async (args, ctx) => {
			const sub = args.trim() || "status";
			if (sub === "on" || sub === "off") {
				enabled = sub === "on";
				pi.appendEntry(ENTRY_TOGGLE, { enabled });
				endRun(ctx);
				ctx.ui.setStatus(STATUS_KEY, enabled ? undefined : "think-router off");
				ctx.ui.notify(`thinking-router ${sub} for this session`, "info");
				return;
			}
			if (sub === "stats") {
				const all = readLog();
				const sessionId = ctx.sessionManager.getSessionId();
				ctx.ui.notify(
					[summarize("This session", all.filter((d) => d.sessionId === sessionId)), summarize("All time", all)].join(
						"\n\n",
					),
					"info",
				);
				return;
			}
			const config = loadConfig();
			ctx.ui.notify(
				`thinking-router ${enabled ? "on" : "off"} (${config.model}, timeout ${config.timeoutMs}ms, ` +
					`levels ${ladderFor(config, ctx.model).map((l) => l.level).join("/")} for this model, ` +
					`+/-1 from pi's level)\nmetrics: ${logPath()}`,
				"info",
			);
		},
	});
}
