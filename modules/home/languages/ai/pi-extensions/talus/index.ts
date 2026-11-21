/**
 * Talus: the outer loop. Fan a list of scree tickets out across git worktrees.
 *
 * `/talus SCR-1 SCR-2 ... [--concurrency N] [--max-per-ticket M] [--review-every R]`
 *
 * For each ticket it does four things, in this order, and nothing else:
 *   1. creates a worktree named after the ticket with Worktrunk (`wt switch --create`),
 *   2. moves the ticket and its subtasks into that worktree (`scree move`),
 *   3. opens a Herdr space for it whose terminal is a child of *this* session (`hc run`),
 *   4. starts a pi session in that space running `/ralph-scree` — the inner loop, which
 *      plans, executes and reviews the tickets living in that checkout.
 *
 * At most `concurrency` tickets are live at once; as one drains, the next leaves the queue.
 * Merge-back to main is deliberately not implemented yet: watch a few runs first, then
 * decide what shipping looks like (PR per worktree? rebase onto main? who resolves
 * conflicts?). Nothing here destroys work — every worktree and branch stays on disk after
 * the run, and `wt remove <branch>` is the way to discard one.
 *
 * Why this is an extension rather than a skill: the sequence has to be exact, repeated for
 * N tickets, while you watch. A model retyping absolute worktree paths and space ids is a
 * failure mode; a loop that reads them from command output is not.
 *
 * Three environment facts this file depends on, all measured on this machine:
 *   - Terminals started through the herdr-core CLI inherit the *core's* environment, not
 *     this session's, so a secret your shell exported (LITELLM_KEY) is absent. The launch
 *     therefore sources ~/.config/talus/env.sh when it exists. Keep the key there (mode
 *     600) rather than in a command line: argv shows up on the worker's screen and in its
 *     transcript.
 *   - A first message given to pi as an argument is parsed as a command, but text pasted in
 *     later (which is how `hc send` delivers it) arrives as an ordinary user message and
 *     never runs a slash command. So the inner-loop command goes in argv at launch, and it
 *     must be the whole message: anything appended becomes command arguments.
 *   - Renaming a space while `hc run --bg` is still registering its terminal comes back
 *     `nospace`, and the name herdr shows until then is derived from the folder. Hence spaces
 *     are named by the supervision ticks, not at launch.
 *
 * Whether a checkout is finished comes from the inner loop's own persisted state
 * (~/.pi/agent/ralph-scree/<project>/state.json, matched by the absolute path it records), not
 * from how busy the pane looks: a ralph-scree session sits idle while its headless worker runs
 * the step, so "looks idle" would read a healthy run as stuck. Once that loop reports done or
 * stopped, scree decides whether that means finished or finished early with tickets left. The
 * pane is still left open for a person to read.
 */

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";

// --- Constants -------------------------------------------------------------

const DEFAULT_CONCURRENCY = 3;
const MAX_CONCURRENCY = 8;
const DEFAULT_MAX_PER_TICKET = 8;
const DEFAULT_REVIEW_EVERY = 3;
/** How often the supervisor looks at every live worker. Each look is two cheap CLI calls
 * (`scree` reads a local database, `hc get` reads the core's table), so this is about
 * latency of slot refill, not load. */
const TICK_MS = 45_000;
const SHORT_TIMEOUT_MS = 30_000;
/** Env file the launched sessions source before exec'ing pi. Optional. */
const ENV_FILE = join(homedir(), ".config", "talus", "env.sh");

const WIDGET_KEY = "talus";

// --- Types -----------------------------------------------------------------

type WorkerStatus =
  | "launching"
  | "running"
  /** Its loop stopped with work still in the checkout: cap reached, or a failure streak. */
  | "ended"
  /** Nothing actionable left in the checkout. */
  | "drained"
  /** The pi terminal exited or never came up. */
  | "gone"
  /** The session is sitting on an approval or question dialog. */
  | "attention"
  | "failed";

type Worker = {
  ticketId: string;
  title: string;
  branch: string;
  path: string;
  spaceId: string;
  termName: string;
  startedAt: string;
  status: WorkerStatus;
  /** What the last probe saw, for the progress report: how much work is left here. */
  remaining?: { ready: number; active: number };
  note?: string;
  /** Has its Herdr space taken its ticket name yet? Renaming at launch does not stick. */
  named?: boolean;
  nameTries?: number;
};

type TalusState = {
  running: boolean;
  stopRequested: boolean;
  concurrency: number;
  maxPerTicket: number;
  reviewEvery: number;
  root: string;
  queue: string[];
  workers: Worker[];
  finished: { ticketId: string; outcome: string; note?: string }[];
  log: string[];
  lastError?: string;
};

// --- Small helpers ---------------------------------------------------------

function log(state: TalusState, line: string): void {
  state.log.push(`${new Date().toISOString().slice(11, 19)} ${line}`);
  if (state.log.length > 200) state.log.splice(0, state.log.length - 200);
}

/** scr-12-add-greet-sh — the ticket id leads so `wt list`, the Herdr sidebar and scree all sort
 * by ticket, and the words make a stray worktree self-describing six weeks later. */
function branchNameFor(id: string, title: string): string {
  const slug = title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .split("-")
    .slice(0, 5)
    .join("-");
  const key = id.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  return `scr-${key}${slug ? `-${slug}` : ""}`.slice(0, 60);
}

/** hc terminal names: [a-z][a-z0-9_-]{0,31}, and not shaped like an id. */
function termNameFor(id: string): string {
  return `talus-${id.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`.slice(0, 32);
}

/** A herdr-app space id we invent. Any unknown id becomes a new space, which is exactly how
 * we avoid the bootstrap shell pane `space.new` would have left behind. Must stay lowercase
 * enough to be unambiguous, and cannot look like a core address. */
function spaceIdFor(id: string): string {
  return `talus-${id.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`;
}

async function run(
  pi: ExtensionAPI,
  cwd: string,
  cmd: string,
  args: string[],
  timeout = SHORT_TIMEOUT_MS,
): Promise<{ code: number; killed: boolean; stdout: string; stderr: string }> {
  const r = await pi.exec(cmd, args, { cwd, timeout });
  return { code: r.code ?? -1, killed: !!r.killed, stdout: r.stdout ?? "", stderr: r.stderr ?? "" };
}

/** Every mutating call reports what failed in its own words; do not swallow it. */
function failWith(cmd: string, r: { stdout: string; stderr: string; killed: boolean }): string {
  const detail = (r.stderr || r.stdout).trim().split("\n").filter(Boolean).slice(-3).join(" / ");
  return `${cmd} failed${r.killed ? " (timed out)" : ""}: ${detail || "no output"}`;
}

// --- Preflight -------------------------------------------------------------

/** Read one ticket's fields talus needs. Undefined when scree could not answer. */
async function readTicket(pi: ExtensionAPI, cwd: string, id: string): Promise<
  { title: string; status: string; for: string; projectRoot: string; parent: string; worktree: string } | undefined
> {
  const r = await run(pi, cwd, "scree", ["show", id, "--json"]);
  if (r.code !== 0) return undefined;
  try {
    const raw = JSON.parse(r.stdout.trim());
    return {
      title: typeof raw.title === "string" ? raw.title : "",
      status: typeof raw.status === "string" ? raw.status : "",
      for: typeof raw.for === "string" ? raw.for : "agent",
      projectRoot: raw?.project?.root ?? "",
      parent: typeof raw.parent === "string" ? raw.parent : "",
      // Which checkout the ticket currently lives in; empty or the root when it has not been
      // fanned out yet. This is what makes a rerun of talus continue instead of fork.
      worktree: typeof raw.worktree === "string" ? raw.worktree : "",
    };
  } catch {
    return undefined;
  }
}

/** What is still actionable in a checkout: ready or active agent tickets. Drafts are not the
 * loop's business, so they do not keep a slot open. */
async function boardHere(pi: ExtensionAPI, cwd: string): Promise<{ ready: number; active: number } | undefined> {
  const ready = await run(pi, cwd, "scree", ["list", "--status", "ready", "--limit", "200", "--json"]);
  const active = await run(pi, cwd, "scree", ["list", "--status", "active", "--limit", "200", "--json"]);
  if (ready.code !== 0 || active.code !== 0) return undefined;
  try {
    return {
      ready: (JSON.parse(ready.stdout.trim())?.tickets ?? []).length,
      active: (JSON.parse(active.stdout.trim())?.tickets ?? []).length,
    };
  } catch {
    return undefined;
  }
}

/** The observed state of one launched session, from the core. `state` is live/finished;
 * `status.state` is what the agent inside it reported. */
async function probeTerminal(pi: ExtensionAPI, cwd: string, name: string): Promise<
  { live: boolean; agentState?: string; why?: string } | undefined
> {
  const r = await run(pi, cwd, "hc", ["get", name, "--json"]);
  if (r.code !== 0) {
    // A removed/never-created terminal is genuinely gone; anything else is "could not tell".
    return r.stderr.includes("not_found") ? { live: false } : undefined;
  }
  try {
    const d = JSON.parse(r.stdout.trim());
    const status = d?.status;
    return {
      live: d?.state === "live",
      agentState: typeof status === "string" ? status : status?.state,
    };
  } catch {
    return undefined;
  }
}

// --- Launch ------------------------------------------------------------------

/** The branch for a ticket, free of collisions. Reusing an existing branch is deliberate:
 * rerunning talus after a partial run should continue in the same checkout rather than fork a
 * second one with a "-2" suffix. Only a branch that exists without a worktree gets a suffix. */
async function pickBranch(
  pi: ExtensionAPI,
  root: string,
  base: string,
): Promise<{ branch: string; reusable: boolean }> {
  if ((await run(pi, root, "git", ["show-ref", "--verify", "--quiet", `refs/heads/${base}`])).code !== 0) {
    return { branch: base, reusable: false };
  }
  for (let n = 2; n < 20; n++) {
    const candidate = `${base}-${n}`;
    if ((await run(pi, root, "git", ["show-ref", "--verify", "--quiet", `refs/heads/${candidate}`])).code !== 0) {
      return { branch: candidate, reusable: false };
    }
  }
  return { branch: base, reusable: true };
}

/** Where `wt switch` put the worktree. Its result is the last JSON line on stdout — project
 * hooks print before it. */
function worktreePathFrom(stdout: string): string | undefined {
  const lines = stdout.split("\n");
  for (let i = lines.length - 1; i >= 0; i--) {
    if (!lines[i].trimStart().startsWith("{")) continue;
    try {
      const parsed = JSON.parse(lines[i]);
      if (typeof parsed?.path === "string") return parsed.path;
    } catch {
      // Not the result line; keep scanning upwards.
    }
  }
  return undefined;
}

/** Create (or reuse) the worktree for one ticket, move the ticket into it, and start a
/** The checkout a ticket should be worked in: the one it already lives in when talus (or a
 * person) fanned it out before, otherwise a fresh worktree named after the ticket with the
 * ticket and its subtasks moved into it. Reusing is what makes a rerun continue the same work
 * instead of forking a second copy of it. */
async function ensureCheckout(
  pi: ExtensionAPI,
  state: TalusState,
  ticketId: string,
  title: string,
  attached: string,
): Promise<{ path: string; branch: string; note: string } | { error: string }> {
  const existing = attached ? resolve(attached.replace(/^~/, homedir())) : "";
  if (existing && existing !== state.root) {
    if (!existsSync(existing)) {
      return { error: `${ticketId} is filed under worktree ${existing}, which no longer exists. Recreate it or clear the ticket's worktree with scree.` };
    }
    const b = await run(pi, existing, "git", ["branch", "--show-current"]);
    return { path: existing, branch: b.stdout.trim() || "(detached HEAD)", note: ", existing worktree" };
  }

  const picked = await pickBranch(pi, state.root, branchNameFor(ticketId, title));
  // `wt switch` prints hooks before its result line, so take the last JSON object it emitted.
  const sw = await run(
    pi,
    state.root,
    "wt",
    ["switch", ...(picked.reusable ? [] : ["--create"]), "--no-cd", "--format=json", picked.branch],
    10 * 60_000,
  );
  if (sw.code !== 0) {
    const hint = sw.stderr.includes("approval")
      ? " — project hooks need your approval; run `wt config approvals add` yourself"
      : "";
    return { error: `${failWith("wt switch", sw)}${hint}` };
  }
  const rawPath = worktreePathFrom(sw.stdout);
  if (!rawPath) return { error: `${ticketId}: wt switch printed no worktree path` };
  const path = resolve(rawPath.replace(/^~/, homedir()));

  const mv = await run(pi, state.root, "scree", ["move", ticketId, "--worktree", path, "--json"]);
  if (mv.code !== 0) {
    return { error: `${failWith(`scree move ${ticketId}`, mv)} (worktree ${path} was created and is yours to remove)` };
  }
  // Context the loop's workers read off the ticket: where they are and why.
  await run(pi, path, "scree", ["comment", "add", ticketId, `talus: moved to worktree ${path} on branch ${picked.branch}.`]);
  return { path, branch: picked.branch, note: "" };
}

/** One rename attempt. Returns undefined when herdr-app accepted it, else what it said.
 * A rename issued while `hc run --bg` is still registering the terminal comes back `nospace`
 * and does not stick (measured), so callers retry from the supervision tick. */
async function nameSpace(
  pi: ExtensionAPI,
  cwd: string,
  spaceId: string,
  name: string,
): Promise<string | undefined> {
  const r = await run(pi, cwd, "herdr-app", ["do", "space.rename", JSON.stringify({ id: spaceId, name })]);
  if (r.code === 0 && !(r.stdout + r.stderr).includes("error")) return undefined;
  return (r.stderr || r.stdout).trim().slice(0, 140) || "rename was refused";
}

/** Give a worker's space its ticket name, from whichever tick first finds the core willing to
 * take it. Cosmetic: after enough refusals talus stops asking and leaves the folder-derived
 * name, which is the branch and so still names the ticket. */
async function ensureSpaceName(pi: ExtensionAPI, state: TalusState, w: Worker): Promise<void> {
  if (w.named || (w.nameTries ?? 0) >= 6) return;
  w.nameTries = (w.nameTries ?? 0) + 1;
  const err = await nameSpace(pi, state.root, w.spaceId, `${w.ticketId} ${w.title}`.slice(0, 48));
  if (err) {
    log(state, `note: space rename for ${w.ticketId} did not land (${err})`);
    return;
  }
  w.named = true;
}

/** Create (or reuse) the worktree for one ticket, move the ticket into it, and start a
 * supervised pi session in its own Herdr space. Returns an error string, or null on success.
 * Each step reports what it could not undo, because by step 3 there is state on disk. */
async function launchWorker(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  state: TalusState,
  ticketId: string,
): Promise<string | null> {
  const ticket = await readTicket(pi, state.root, ticketId);
  if (!ticket) return `${ticketId}: scree could not read the ticket`;
  if (ticket.status === "done" || ticket.status === "abandoned") {
    log(state, `${ticketId} is already ${ticket.status}; skipped`);
    // Named in the report even though nothing was launched: a run that quietly did nothing is
    // the worst kind of silent success.
    state.finished.push({ ticketId, outcome: `skipped (${ticket.status})` });
    return null;
  }
  if (ticket.for === "human") return `${ticketId} is assigned to a human; talus does not move those`;

  const checkout = await ensureCheckout(pi, state, ticketId, ticket.title, ticket.worktree);
  if ("error" in checkout) return checkout.error;
  const { path, branch, note } = checkout;

  const spaceId = spaceIdFor(ticketId);
  const termName = termNameFor(ticketId);
  const innerArgs = `${state.maxPerTicket} ${state.reviewEvery}`;
  const script =
    `[ -f "$HOME/.config/talus/env.sh" ] && . "$HOME/.config/talus/env.sh"; ` +
    `exec pi "/ralph-scree ${innerArgs}"`;
  if (!existsSync(ENV_FILE)) {
    log(state, `note: no ${ENV_FILE}; launched sessions inherit only the herdr-core environment`);
  }
  const started = await run(pi, state.root, "hc", [
    "run", "--bg", "--name", termName, "--cwd", path, "--label", `herdr.space=${spaceId}`, "--",
    "bash", "-c", script,
  ]);
  if (started.code !== 0) return `${failWith("hc run", started)} (ticket ${ticketId} now lives in ${path})`;

  // Its space gets its ticket name from the supervision ticks; see ensureSpaceName.

  const worker: Worker = {
    ticketId,
    title: ticket.title,
    branch,
    path,
    spaceId,
    termName,
    startedAt: new Date().toISOString(),
    status: "launching",
  };
  state.workers.push(worker);
  log(state, `${ticketId} -> ${branch} @ ${path} (session ${termName}${note})`);
  ctx.ui.notify(`talus: ${ticketId} running in ${path}`, "info");
  return null;
}

// --- Supervision -------------------------------------------------------------

/** Statuses that no longer occupy a concurrency slot. `attention` deliberately does: a session
 * waiting on a person is still holding its ticket. */
function isSettled(status: WorkerStatus): boolean {
  return status === "drained" || status === "gone" || status === "failed" || status === "ended";
}

/** A note for a worker whose loop never reported in, once it has had time to. */
function waitingSince(w: Worker, why: string): string {
  const waitedMs = Date.now() - Date.parse(w.startedAt);
  return waitedMs > 3 * 60_000 ? `${why} (${Math.round(waitedMs / 60_000)} min)` : why;
}

/** The inner loop's own persisted view of a checkout, which is what it uses to decide its next
 * step -- so it is also the honest thing for talus to read. Guessing from "the session looks
 * idle" would be wrong on principle: a ralph-scree session sits idle while its headless worker
 * subprocess runs the step. Undefined when no run has written state there yet. Reading is one
 * small file per project directory, cheap enough to do inline every tick; board counts only
 * matter once a loop has stopped, so they stay behind this check. */
function readInnerLoopState(worktreePath: string): { status?: string; steps?: number; executed?: number } | undefined {
  const root = join(homedir(), ".pi", "agent", "ralph-scree");
  let entries: string[];
  try {
    entries = readdirSync(root);
  } catch {
    return undefined;
  }
  for (const entry of entries) {
    try {
      const raw = JSON.parse(readFileSync(join(root, entry, "state.json"), "utf8"));
      if (raw && typeof raw.projectPath === "string" && resolve(raw.projectPath) === resolve(worktreePath)) {
        return { status: raw.status, steps: raw.steps, executed: raw.executed };
      }
    } catch {
      // No state.json there, or caught mid-write; another directory may still match.
    }
  }
  return undefined;
}

/** One look at every live worker: is its session up, what did its own loop last report, and if
 * it stopped, is there work left? Then fill freed slots from the queue. */
async function tick(pi: ExtensionAPI, ctx: ExtensionCommandContext, state: TalusState): Promise<void> {
  for (const w of state.workers) {
    if (!isSettled(w.status)) await ensureSpaceName(pi, state, w);
    if (isSettled(w.status)) continue;
    const term = await probeTerminal(pi, state.root, w.termName);
    if (!term) {
      w.note = "probe failed (hc did not answer)";
      continue;
    }
    if (!term.live) {
      w.status = "gone";
      log(state, `${w.ticketId}: session ${w.termName} is not running any more`);
      state.finished.push({ ticketId: w.ticketId, outcome: "gone", note: "terminal exited" });
      continue;
    }
    const inner = readInnerLoopState(w.path);
    if (!inner?.status) {
      // Launched, but its loop has not written state yet (or its command never ran).
      w.note = waitingSince(w, "waiting for its loop to start");
      continue;
    }
    if (inner.status === "running" || inner.status === "stopping") {
      w.status = "running";
      w.note = term.agentState === "blocked" ? "waiting on a person in that pane" : `last report: step ${inner.steps}, ${inner.executed} executed`;
      if (term.agentState === "blocked") log(state, `${w.ticketId}: its session is waiting on a person (approval or question)`);
      continue;
    }
    // Its loop reported done or stopped. Only now does the board decide whether that means
    // finished, or finished early with tickets still queued in that checkout.
    const board = await boardHere(pi, w.path);
    if (!board) {
      w.note = "probe failed (scree did not answer)";
      continue;
    }
    w.remaining = { ready: board.ready, active: board.active };
    if (board.ready + board.active === 0) {
      w.status = "drained";
      log(state, `${w.ticketId}: nothing actionable left in ${w.path}`);
      state.finished.push({ ticketId: w.ticketId, outcome: "drained" });
      continue;
    }
    w.status = "ended";
    log(state, `${w.ticketId}: its loop reported ${inner.status} with ${board.ready} ready / ${board.active} active still in ${w.path} — raise --max-per-ticket, or work that checkout by hand`);
    state.finished.push({ ticketId: w.ticketId, outcome: "ended", note: `${board.ready} ready, ${board.active} active left` });
  }

  // Refill freed slots, oldest request first.
  while (!state.stopRequested && state.workers.filter((w) => !isSettled(w.status)).length < state.concurrency) {
    const next = state.queue.shift();
    if (!next) break;
    const err = await launchWorker(pi, ctx, state, next);
    if (err) {
      log(state, err);
      state.finished.push({ ticketId: next, outcome: "failed", note: err });
      ctx.ui.notify(`talus: ${err}`, "error");
    }
  }

  const live = state.workers.filter((w) => !isSettled(w.status)).length;
  if (live === 0 && state.queue.length === 0) {
    void finish(pi, ctx, state, state.stopRequested ? "stopped" : "done");
    return;
  }
  renderWidget(ctx, state);
}

/** "N tickets waiting on M decisions: ..." from `scree decisions --open` in the root checkout,
 * or undefined when none are open or scree could not answer. Same wording as ralph-scree. */
async function decisionsLine(pi: ExtensionAPI, cwd: string): Promise<string | undefined> {
  try {
    const r = await run(pi, cwd, "scree", ["decisions", "--open", "--json"]);
    if (r.code !== 0) return undefined;
    const rows: any[] = JSON.parse(r.stdout.trim())?.decisions ?? [];
    if (!Array.isArray(rows) || rows.length === 0) return undefined;
    const tickets = new Set<string>();
    for (const row of rows) for (const t of Array.isArray(row?.tickets) ? row.tickets : []) tickets.add(String(t));
    const plural = (n: number, w: string) => `${n} ${w}${n === 1 ? "" : "s"}`;
    const top = rows.slice(0, 3).map((row) => `${row.id} ${row.question}`).join("; ");
    return `${plural(tickets.size, "ticket")} waiting on ${plural(rows.length, "decision")}: ${top}. A human answers with \`scree decision answer\`.`;
  } catch {
    return undefined;
  }
}

async function finish(pi: ExtensionAPI, ctx: ExtensionCommandContext, state: TalusState, reason: "done" | "stopped"): Promise<void> {
  state.running = false;
  stopTicker();
  renderWidget(ctx, state);
  const waiting = await decisionsLine(pi, state.root);
  const lines = [`talus ${reason}: ${state.finished.length} ticket(s) handled`];
  for (const f of state.finished) {
    lines.push(`  ${f.ticketId} — ${f.outcome}${f.note ? `: ${f.note}` : ""}`);
  }
  if (waiting) lines.push("", waiting);
  lines.push("");
  lines.push("Worktrees left in place (nothing merged back yet):");
  for (const w of state.workers) lines.push(`  ${w.ticketId}  branch ${w.branch}  ${w.path}`);
  lines.push("Remove one you are done with: `wt remove <branch>` (from any checkout of the repo).");
  ctx.ui.notify(lines.join("\n"), reason === "done" ? "info" : "warn");
}

let ticker: ReturnType<typeof setInterval> | null = null;
function startTicker(pi: ExtensionAPI, ctx: ExtensionCommandContext, state: TalusState): void {
  stopTicker();
  ticker = setInterval(() => {
    void tick(pi, ctx, state).catch((err: unknown) => {
      state.lastError = err instanceof Error ? err.message : String(err);
      void finish(pi, ctx, state, "stopped");
    });
  }, TICK_MS);
  ticker.unref?.();
}
function stopTicker(): void {
  if (ticker) clearInterval(ticker);
  ticker = null;
}

function widgetLines(state: TalusState): string[] {
  if (!state.running) return [];
  const bits = state.workers
    .filter((w) => !isSettled(w.status))
    .map((w) => `${w.ticketId}:${w.status}`);
  return [`talus: ${bits.join(" ") || "starting"} · queued ${state.queue.length} · concurrency ${state.concurrency}`];
}

/** The ctx captured at `/talus` start can outlive the session (fork, /new, reload), and pi
 * then throws on any ctx.ui access. The supervision loop's real work goes through pi, so
 * drop the widget rather than take the process down. */
function renderWidget(ctx: ExtensionCommandContext, state: TalusState): void {
  try {
    ctx.ui.setWidget(WIDGET_KEY, widgetLines(state));
  } catch {
    stopTicker();
  }
}

// --- Argument parsing ---------------------------------------------------------

type Parsed =
  | { ok: true; tickets: string[]; concurrency: number; maxPerTicket: number; reviewEvery: number }
  | { ok: false; error: string };

function parseArgs(args: string): Parsed {
  const tokens = (args ?? "").trim().split(/\s+/).filter(Boolean);
  const tickets: string[] = [];
  let concurrency = DEFAULT_CONCURRENCY;
  let maxPerTicket = DEFAULT_MAX_PER_TICKET;
  let reviewEvery = DEFAULT_REVIEW_EVERY;
  const flagKeys = new Map<string, "concurrency" | "maxPerTicket" | "reviewEvery">([
    ["--concurrency", "concurrency"],
    ["-c", "concurrency"],
    ["--max-per-ticket", "maxPerTicket"],
    ["--review-every", "reviewEvery"],
  ]);
  const setFlag = (key: string, value: string): string | undefined => {
    const n = Number(value);
    if (!Number.isInteger(n) || n <= 0) return `invalid ${key}: "${value}"`;
    if (key === "concurrency") concurrency = Math.min(n, MAX_CONCURRENCY);
    else if (key === "maxPerTicket") maxPerTicket = n;
    else reviewEvery = n;
    return undefined;
  };
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    const eq = token.indexOf("=");
    // Accept both `--concurrency 3` and `--concurrency=3`; the values are never ticket ids.
    const inlineKey = eq > 0 ? flagKeys.get(token.slice(0, eq)) : undefined;
    if (inlineKey) {
      const err = setFlag(inlineKey, token.slice(eq + 1));
      if (err) return { ok: false, error: err };
      continue;
    }
    const spacedKey = flagKeys.get(token);
    if (spacedKey) {
      const value = tokens[++i];
      if (value === undefined) return { ok: false, error: `${token} needs a value` };
      const err = setFlag(spacedKey, value);
      if (err) return { ok: false, error: err };
      continue;
    }
    if (token.startsWith("-")) return { ok: false, error: `unknown flag ${token}` };
    tickets.push(token.toUpperCase());
  }
  if (tickets.length === 0) {
    return { ok: false, error: "give me ticket ids, e.g. /talus SCR-1 SCR-2 --concurrency 2" };
  }
  const seen = new Set(tickets);
  if (seen.size !== tickets.length) return { ok: false, error: "duplicate ticket ids in the list" };
  return { ok: true, tickets, concurrency, maxPerTicket, reviewEvery };
}

// --- Commands -----------------------------------------------------------------

let activeState: TalusState | null = null;

export default function (pi: ExtensionAPI) {
  pi.registerCommand("talus", {
    description: "Fan scree tickets out across worktrees, each worked by its own ralph-scree session",
    handler: async (args, ctx) => {
      if (activeState?.running) {
        ctx.ui.notify(
          `talus is already running (${activeState.workers.length} launched, ${activeState.queue.length} queued). Use /talus-stop first.`,
          "warn",
        );
        return;
      }
      const parsed = parseArgs(args ?? "");
      if (!parsed.ok) {
        ctx.ui.notify(`talus: ${parsed.error}`, "error");
        return;
      }

      // Tooling checks come first: a half-launched fan-out is the worst outcome, and each of
      // these binaries is a hard dependency of one of the four steps.
      // `command -v` rather than spawning each binary: presence is what matters here, and a
      // missing one would otherwise surface as an opaque ENOENT halfway through the fan-out.
      for (const tool of ["wt", "scree", "hc", "herdr-app"]) {
        const which = await run(pi, ctx.cwd, "sh", ["-c", `command -v ${tool}`]);
        if (which.code !== 0) {
          ctx.ui.notify(`talus needs \`${tool}\` on PATH (it drives ${tool} for every ticket).`, "error");
          return;
        }
      }

      const top = await run(pi, ctx.cwd, "git", ["rev-parse", "--show-toplevel"]);
      if (top.code !== 0) {
        ctx.ui.notify("talus must run inside a git repository.", "error");
        return;
      }
      const commonDir = await run(pi, ctx.cwd, "git", ["rev-parse", "--path-format=absolute", "--git-common-dir"]);
      const mainRoot = commonDir.code === 0 ? resolve(commonDir.stdout.trim()).replace(/\/\.git$/, "") : "";
      if (resolve(ctx.cwd) !== mainRoot) {
        ctx.ui.notify(
          `talus runs from the root checkout so it can hand worktrees to other sessions — you are in ${resolve(ctx.cwd)}, the repo root is ${mainRoot || "(unknown)"}.`,
          "error",
        );
        return;
      }

      // Confirm every ticket exists and belongs to this checkout's project before touching
      // anything: a typo'd id should fail here, not after three worktrees exist.
      const requested = new Map<string, NonNullable<Awaited<ReturnType<typeof readTicket>>>>();
      for (const id of parsed.tickets) {
        const t = await readTicket(pi, ctx.cwd, id);
        if (!t) {
          ctx.ui.notify(`talus: scree has no ticket ${id} visible from this checkout (is it in another worktree? \`scree list --all-worktrees\`).`, "error");
          return;
        }
        if (t.projectRoot && resolve(t.projectRoot) !== mainRoot && !existsSync(t.projectRoot)) {
          ctx.ui.notify(`talus: ${id} points at project root ${t.projectRoot}, which does not exist.`, "error");
          return;
        }
        requested.set(id, t);
      }
      // A subtask named alongside its own parent needs no worktree of its own: moving the
      // parent moves its subtasks, and two sessions on one ticket would fight over the claim.
      const tickets = parsed.tickets.filter((id) => {
        const parent = requested.get(id)?.parent ?? "";
        if (parent && requested.has(parent)) {
          ctx.ui.notify(`talus: dropping ${id} from the list — it is a subtask of ${parent}, so it travels in that ticket's worktree.`, "info");
          return false;
        }
        return true;
      });
      if (tickets.length === 0) {
        ctx.ui.notify("talus: nothing left to launch once subtasks were folded into their parents.", "warn");
        return;
      }

      const state: TalusState = {
        running: true,
        stopRequested: false,
        concurrency: parsed.concurrency,
        maxPerTicket: parsed.maxPerTicket,
        reviewEvery: parsed.reviewEvery,
        root: mainRoot,
        queue: [...tickets],
        workers: [],
        finished: [],
        log: [],
      };
      activeState = state;
      log(state, `start: ${tickets.length} ticket(s) (${parsed.tickets.length} requested), concurrency ${parsed.concurrency}, ${parsed.maxPerTicket} execute(s) per checkout, review every ${parsed.reviewEvery}`);
      startWidgetTickerOnly(ctx, state);
      startTicker(pi, ctx, state);

      // Fill the first window synchronously so the launch errors surface immediately.
      while (state.queue.length > 0 && state.workers.length < state.concurrency) {
        const id = state.queue.shift()!;
        const err = await launchWorker(pi, ctx, state, id);
        if (err) {
          log(state, err);
          state.finished.push({ ticketId: id, outcome: "failed", note: err });
          ctx.ui.notify(`talus: ${err}`, "error");
        }
      }
      renderWidget(ctx, state);
      if (state.workers.length === 0 && state.finished.length > 0) {
        void finish(pi, ctx, state, "stopped");
      }
    },
  });

  pi.registerCommand("talus-progress", {
    description: "Show the talus fan-out: worktrees, sessions, queue",
    handler: async (_args, ctx) => {
      if (!activeState) {
        ctx.ui.notify("talus has not run in this session. Use /talus <tickets> to start it.", "info");
        return;
      }
      const s = activeState;
      const lines = [
        `talus ${s.running ? "running" : "finished"} · concurrency ${s.concurrency} · ${s.workers.length} launched · ${s.queue.length} queued`,
      ];
      for (const w of s.workers) {
        const left = w.remaining ? ` · ${w.remaining.ready} ready, ${w.remaining.active} active` : "";
        lines.push(`  ${w.ticketId} ${w.status}${left} · ${w.branch} · session ${w.termName}${w.note ? ` · ${w.note}` : ""}`);
        lines.push(`    ${w.path}`);
      }
      for (const f of s.finished) lines.push(`  finished: ${f.ticketId} — ${f.outcome}${f.note ? ` (${f.note})` : ""}`);
      if (s.queue.length) lines.push(`  queued: ${s.queue.join(", ")}`);
      lines.push("");
      lines.push(...s.log.slice(-15));
      ctx.ui.notify(lines.join("\n"), "info");
    },
  });

  pi.registerCommand("talus-stop", {
    description: "Stop talus: launch nothing further, leave running sessions alone",
    handler: async (_args, ctx) => {
      if (!activeState?.running) {
        ctx.ui.notify("talus is not running.", "info");
        return;
      }
      activeState.stopRequested = true;
      activeState.queue = [];
      log(activeState, "stop requested: queue dropped; running sessions are untouched");
      const live = activeState.workers.filter((w) => !isSettled(w.status));
      ctx.ui.notify(
        live.length === 0
          ? "talus stopped."
          : `talus will not launch anything else. ${live.length} session(s) keep working — stop a loop in its own pane with /ralph-scree-stop, or end the session with \`hc kill ${live.map((w) => w.termName).join(" ")}\`.`,
        "warn",
      );
    },
  });

  pi.on("session_shutdown", () => {
    stopTicker();
    stopWidgetTick();
  });
}

/** Separate from the supervision tick so the seconds-resolution clock only paints timing; the
 * board probes stay on TICK_MS. */
let widgetTick: ReturnType<typeof setInterval> | null = null;
function startWidgetTickerOnly(ctx: ExtensionCommandContext, state: TalusState): void {
  stopWidgetTick();
  widgetTick = setInterval(() => renderWidget(ctx, state), 1000);
  widgetTick.unref?.();
}
function stopWidgetTick(): void {
  if (widgetTick) clearInterval(widgetTick);
  widgetTick = null;
}
