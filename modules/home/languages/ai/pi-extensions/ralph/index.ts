/**
 * Ralph loop: autonomous backlog-churning extension.
 *
 * `/ralph [iterations] [reviewEvery]` drives tickets through
 * Needs Plan -> Dev Ready -> In Progress -> Done, periodically checkpointing
 * with a human-grade review, until `iterations` passes complete or the
 * backlog runs dry. Originally authored in the gql-fiddle repo (see that
 * repo's docs/plans/2026-07-14-ralph-loop-design.md for the design
 * rationale) and promoted here so it loads for every project, not just that
 * one.
 *
 * Each unit of real work (executing a ticket, planning one, choosing the next
 * one, reviewing recent work) runs in a fresh headless `pi -p` subprocess, so
 * no iteration's context leaks into the next — the "Ralph" technique. Only
 * bookkeeping (counters, exit conditions, backlog status queries) happens
 * here in plain TypeScript.
 *
 * Depends on skills already present as this user's global pi/Claude skills
 * (backlog-execute, backlog-planner, review-pi-work, herdr) and on "research" /
 * "planning" / "chat-fast" model aliases configured in pi's settings — see the
 * design doc for details. Requires HERDR_ENV=1 (the review step drives a
 * herdr pane) and the `backlog` CLI.
 *
 * Headless worker calls run with `--no-extensions`: confirmed live that
 * `pi -p` intermittently hangs after printing its response and never exits,
 * and every one of this user's ~15 globally-loaded extensions reproduces it
 * in isolation (roughly 1-in-2 to 1-in-3 runs each) — pointing at something
 * systemic in extension load/teardown rather than one buggy package, with
 * risk compounding across however many are loaded. Two exceptions re-enable a
 * specific extension via `-e` (`--no-extensions` only disables auto-discovery;
 * explicit `-e` paths still load): the research step's web search needs
 * `pi-web-access`, and the execute/research/plan/review steps load
 * `pi-intercom` so they can ping the orchestrating session with progress
 * updates (see `intercomStatusGuidance`). Both knowingly pay the hang-risk tax
 * above — accepted because the existing `execCapture` watchdog already turns
 * a hung subprocess into "runs its full timeout instead of returning
 * promptly," not a stuck loop, which was judged an acceptable price for live
 * progress visibility. Skills are unaffected — that's a separate `--no-skills`
 * flag we don't touch.
 *
 * The orchestrating session gets the mirror-image framing: while a loop is
 * running, a `before_agent_start` handler appends `ORCHESTRATOR_ROLE_GUIDANCE`
 * to this session's system prompt on every turn, so worker progress pings
 * (which arrive as ordinary injected user messages) are read as status
 * reports to relay — not task assignments to execute in parallel with the
 * worker that owns the ticket.
 */

import { existsSync } from "node:fs";
import { appendFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { defineTool } from "@earendil-works/pi-coding-agent";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";
import { Type } from "@earendil-works/pi-ai";
import { Box, Key, matchesKey, Text, truncateToWidth } from "@earendil-works/pi-tui";

// --- Types & constants ---------------------------------------------------

const MAX_HISTORY = 50;

/**
 * Ralph's session state (state.json, history.jsonl) lives under the global pi
 * config rather than inside each project's own working tree — as a project-local
 * `.pi/ralph/`, it showed up as untracked cruft in every repo ralph touched and
 * needed its own .gitignore entry each time. Namespaced per project instead, one
 * level down here, so multiple projects' histories never collide.
 *
 * The namespace segment is the project's absolute path with every `/` replaced
 * by `-` — the same convention Claude Code itself uses for its own per-project
 * state under `~/.claude/projects/`, so a given project's ralph state and Claude
 * state sit under matching directory names.
 */
const RALPH_STATE_ROOT = join(homedir(), ".pi", "agent", "ralph");

function stateDirFor(cwd: string): string {
  return join(RALPH_STATE_ROOT, resolve(cwd).replace(/[\\/]/g, "-"));
}

/** Path assumption: wherever this user's `pi-web-access` package currently
 * resolves. May need updating if `pi update` changes the install layout. */
const PI_WEB_ACCESS_EXTENSION = join(
  homedir(),
  ".pi/agent/npm/node_modules/pi-web-access/index.ts",
);

/**
 * unblocked-todo.sh lists backlog.md tasks in a given status whose dependencies are all
 * Done. It's deployed by ai.nix alongside this extension's own index.ts (not inside each
 * project's own backlog/ directory, since ralph loads globally across projects) and cds
 * into the target project's backlog/ itself when run.
 */
const UNBLOCKED_TODO_SCRIPT = join(
  homedir(),
  ".pi/agent/extensions/ralph/unblocked-todo.sh",
);

/** Path assumption: wherever this user's `pi-intercom` package currently
 * resolves. May need updating if `pi update` changes the install layout. */
const PI_INTERCOM_EXTENSION = join(
  homedir(),
  ".pi/agent/npm/node_modules/pi-intercom/index.ts",
);

/** Path assumption: wherever this user's `@gotgenes/pi-subagents` package currently
 * resolves — the live `npm/` tree (npm2/npm3 are stale pre-migration backups; verified
 * 2026-08-18 via package versions and lockfile mtimes). May need updating if `pi update`
 * changes the install layout. Gives executors the subagent tool so widget screenshot
 * verification can be delegated to nested subagents (fresh context each) instead of
 * reading >4 screenshots into the executor's own context and tripping the vLLM
 * --limit-mm-per-prompt image=4 hard cap (HTTP 400). Verified end-to-end 2026-08-18:
 * a --no-extensions parent with this -e flag spawns in-process children that load
 * the parent's extensions (minus the recursion-guarded dispatch tools) and can read
 * images fine. */
const PI_SUBAGENTS_EXTENSION = join(
  homedir(),
  ".pi/agent/npm/node_modules/@gotgenes/pi-subagents/src/index.ts",
);

const DEFAULT_ITERATIONS = 16;
const DEFAULT_REVIEW_EVERY = 3;

const TRIAGE_TIMEOUT_MS = 5 * 60_000;
const RESEARCH_TIMEOUT_MS = 15 * 60_000;
const PLAN_TIMEOUT_MS = 45 * 60_000;
const EXECUTE_TIMEOUT_MS = 40 * 60_000;
const CHOOSE_TIMEOUT_MS = 10 * 60_000;
const REVIEW_TIMEOUT_MIN = 50;
const REVIEW_TIMEOUT_MS = REVIEW_TIMEOUT_MIN * 60_000;

/**
 * A step that fails this many times in a row (same kind + ticket) stops the
 * loop instead of retrying forever. Repeated identical failure is a signal
 * of a systemic problem (a hung subprocess, a broken tool), not a one-off
 * bad ticket — silently burning the iteration budget on it just hides that.
 */
const MAX_CONSECUTIVE_FAILURES = 2;

type RalphStatus = "running" | "stopping" | "stopped" | "done";

type StepKind = "execute" | "plan" | "choose" | "review" | "promote" | "squash";

type RalphHistoryEntry = {
  at: string;
  kind: StepKind;
  ticket?: string;
  outcome: "ok" | "failed";
  summary: string;
  /** New ticket IDs that appeared between the start and end of this step — only populated
   * for review steps, via a deterministic before/after diff rather than parsing the review
   * agent's free-text summary for ticket mentions. */
  createdTickets?: string[];
};

type RalphState = {
  status: RalphStatus;
  iterations: number;
  reviewEvery: number;
  loopCount: number;
  /** Completed executes (ok outcomes) since the last review; also the review trigger — a
   * review runs once this reaches `reviewEvery`, and once more at the very end if it's
   * still nonzero when the loop exits for any other reason. */
  executedSinceReview: number;
  stopRequested: boolean;
  currentStep?: string;
  /** When the current step started, for the live elapsed/remaining display. Cleared once
   * the loop settles on a final status so the widget doesn't show a stale countdown. */
  currentStepStartedAt?: string;
  /** The timeout backing the current step's subprocess call, if it has one (bookkeeping
   * steps like a single-candidate `choose` don't spawn a headless call and leave this unset). */
  currentStepTimeoutMs?: number;
  startedAt: string;
  history: RalphHistoryEntry[];
  /** Consecutive failures of the same (kind, ticket) step — see MAX_CONSECUTIVE_FAILURES. */
  failureStreak?: { key: string; count: number };
  /** Consecutive `choose` picks that landed on the same ticket — see MAX_CONSECUTIVE_FAILURES.
   * `choose` only runs once nothing is In Progress/Dev Ready/Needs Plan, so re-picking the same
   * ticket means it cycled all the way back to unblocked `To Do` without completing: a real
   * (often environmental, e.g. blocked on a manual step) block that `execute`'s own "ok" outcome
   * won't surface, since backlog-execute correctly reports success for documenting the blocker
   * and reverting status. */
  repeatedChoiceStreak?: { ticketId: string; count: number };
  /** Cached triage verdict / research output for the ticket currently being planned. A doPlan
   * retry (triggered by the outer loop re-finding the same still-"Needs Plan" ticket after a
   * failure) reuses this instead of redoing triage and research from scratch — only the step
   * that actually failed re-runs. Cleared once the ticket's plan succeeds (or trivial path
   * completes) or a different ticket starts planning. */
  planCache?: {
    ticketId: string;
    triage?: "TRIVIAL" | "NORMAL";
    researchOutput?: string;
  };
  /** This session's intercom id, captured once at `/ralph` start so headless steps can address
   * progress pings back here — see `intercomStatusGuidance`. */
  mainSessionId: string;
  /** The herdr pane this loop is running in, captured once at `/ralph` start from
   * `HERDR_PANE_ID` so the review step can split a known pane deterministically instead of
   * having each review call rediscover "the current pane" itself via `herdr pane list`. */
  mainPaneId: string;
};

/** Records outcome `ok` under `key`; returns true once the streak hits the cap. */
function trackFailureStreak(
  state: RalphState,
  key: string,
  ok: boolean,
): boolean {
  if (ok) {
    state.failureStreak = undefined;
    return false;
  }
  state.failureStreak =
    state.failureStreak?.key === key
      ? { key, count: state.failureStreak.count + 1 }
      : { key, count: 1 };
  return state.failureStreak.count >= MAX_CONSECUTIVE_FAILURES;
}

type Ticket = { id: string; title: string };

/** The one loop this session is running, if any. Lifetime = this pi process. */
let activeState: RalphState | null = null;

// --- State persistence -----------------------------------------------------

function createState(
  iterations: number,
  reviewEvery: number,
  mainSessionId: string,
  mainPaneId: string,
): RalphState {
  return {
    status: "running",
    iterations,
    reviewEvery,
    loopCount: 0,
    executedSinceReview: 0,
    stopRequested: false,
    currentStep: undefined,
    currentStepStartedAt: undefined,
    currentStepTimeoutMs: undefined,
    startedAt: new Date().toISOString(),
    history: [],
    failureStreak: undefined,
    repeatedChoiceStreak: undefined,
    planCache: undefined,
    mainSessionId,
    mainPaneId,
  };
}

async function ensureStateDir(cwd: string): Promise<void> {
  await mkdir(stateDirFor(cwd), { recursive: true });
}

async function persist(cwd: string, state: RalphState): Promise<void> {
  await ensureStateDir(cwd);
  await writeFile(
    join(stateDirFor(cwd), "state.json"),
    JSON.stringify(state, null, 2),
    "utf8",
  );
}

async function recordHistory(
  cwd: string,
  state: RalphState,
  entry: Omit<RalphHistoryEntry, "at">,
): Promise<void> {
  const full: RalphHistoryEntry = { at: new Date().toISOString(), ...entry };
  state.history.push(full);
  if (state.history.length > MAX_HISTORY) state.history.shift();
  await ensureStateDir(cwd);
  await appendFile(
    join(stateDirFor(cwd), "history.jsonl"),
    `${JSON.stringify(full)}\n`,
    "utf8",
  );
}

// --- Deterministic backlog queries (no LLM involved) ------------------------

/**
 * Grace period added on top of a caller's `timeout` before our own watchdog
 * gives up on `pi.exec()` and forces a result. Confirmed live (via `ps`):
 * `pi.exec`'s own `timeout` option does not reliably kill the underlying
 * process — two `pi -p` subprocesses from timed-out steps were found still
 * running, fully alive, hours after we'd recorded them as failed and moved
 * on. So alongside `timeout`, we also pass our own AbortSignal and abort it
 * ourselves at the same deadline, giving `pi.exec`'s documented cancellation
 * path ("respects Esc cancellation") an independent chance to actually kill
 * the process. Even with that, the watchdog below still races an outright
 * timer so a stuck exec call can never block the loop's forward progress —
 * if the process survives both kill attempts, the orphaned promise (and
 * process) is left running and simply ignored.
 */
const WATCHDOG_GRACE_MS = 30_000;

async function execCapture(
  pi: ExtensionAPI,
  cmd: string,
  args: string[],
  opts: { cwd: string; timeout?: number },
): Promise<{ ok: boolean; killed: boolean; stdout: string; stderr: string }> {
  const controller = opts.timeout ? new AbortController() : undefined;
  const execPromise = pi
    .exec(cmd, args, {
      cwd: opts.cwd,
      timeout: opts.timeout,
      signal: controller?.signal,
    })
    .then((result) => ({
      ok: result.code === 0 && !result.killed,
      killed: !!result.killed,
      stdout: result.stdout ?? "",
      stderr: result.stderr ?? "",
    }));

  if (!opts.timeout || !controller) return execPromise;

  const abortTimer = setTimeout(() => controller.abort(), opts.timeout);
  abortTimer.unref?.();

  const watchdog = new Promise<{
    ok: boolean;
    killed: boolean;
    stdout: string;
    stderr: string;
  }>((resolve) => {
    const timer = setTimeout(
      () =>
        resolve({
          ok: false,
          killed: true,
          stdout: "",
          stderr: `(watchdog: "${cmd}" exec call never returned ${opts.timeout! + WATCHDOG_GRACE_MS}ms after start — pi.exec's timeout and our own abort signal both failed to kill it; the process may still be running orphaned)`,
        }),
      opts.timeout + WATCHDOG_GRACE_MS,
    );
    timer.unref?.();
  });

  return Promise.race([execPromise, watchdog]);
}

function parsePlainTaskList(output: string): Ticket[] {
  const tasks: Ticket[] = [];
  for (const line of output.split("\n")) {
    // Each leading `[...]` is an optional priority/label tag — a ticket may have a
    // priority and a label, just a priority, or neither, so match zero or more of them
    // rather than assuming exactly two.
    const match = line.match(/^\s*(?:\[[^\]]+\]\s*)*(\S+)\s+-\s+(.+?)\s*$/);
    if (match) tasks.push({ id: match[1], title: match[2] });
  }
  return tasks;
}

function parseUnblockedList(output: string): Ticket[] {
  const tasks: Ticket[] = [];
  for (const line of output.split("\n")) {
    const match = line.match(/^(\S+)\s+-\s+(.+?)\s*$/);
    if (match) tasks.push({ id: match[1], title: match[2] });
  }
  return tasks;
}

async function findFirstByStatus(
  pi: ExtensionAPI,
  cwd: string,
  status: string,
): Promise<Ticket | undefined> {
  const { stdout } = await execCapture(
    pi,
    "backlog",
    ["task", "list", "-s", status, "--plain"],
    {
      cwd,
      timeout: 15_000,
    },
  );
  return parsePlainTaskList(stdout)[0];
}

async function listUnblockedByStatus(
  pi: ExtensionAPI,
  cwd: string,
  status: string,
): Promise<Ticket[]> {
  const { stdout } = await execCapture(pi, UNBLOCKED_TODO_SCRIPT, [status], {
    cwd,
    timeout: 30_000,
  });
  return parseUnblockedList(stdout);
}

async function listUnblocked(pi: ExtensionAPI, cwd: string): Promise<Ticket[]> {
  return listUnblockedByStatus(pi, cwd, "To Do");
}

/**
 * Tickets are sometimes filed straight into "Blocked" status with a dependency that isn't
 * Done yet (e.g. a subtask created alongside a parent whose sibling hasn't shipped). Nothing
 * ever moves them back to "To Do" once that dependency completes — `listUnblocked` only ever
 * scans "To Do" tickets, so a Blocked ticket whose blocker shipped months ago just sits there,
 * invisible to the loop, forever. This sweeps "Blocked" tickets whose dependencies are now all
 * Done and promotes them to "To Do" so the normal choose/plan/execute flow picks them up. Only
 * called as a fallback when the "To Do" pool is empty — it's an extra backlog scan, not worth
 * paying on every iteration while there's already unblocked work.
 */
async function promoteUnblockedBlockedTickets(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  cwd: string,
  state: RalphState,
): Promise<Ticket[]> {
  setCurrentStep(ctx, state, "checking Blocked tickets for satisfied dependencies");
  const promotable = await listUnblockedByStatus(pi, cwd, "Blocked");
  const promoted: Ticket[] = [];
  for (const ticket of promotable) {
    const ok = await setTicketStatus(pi, cwd, ticket.id, "To Do");
    await recordHistory(cwd, state, {
      kind: "promote",
      ticket: ticket.id,
      outcome: ok ? "ok" : "failed",
      summary: ok
        ? `Blocked -> To Do, dependencies now satisfied (${ticket.title})`
        : `dependencies satisfied but failed to move ${ticket.id} out of Blocked`,
    });
    if (ok) promoted.push(ticket);
  }
  return promoted;
}

/** All known ticket IDs, across every status. Used to detect new tickets filed by a review
 * step via a before/after diff, rather than parsing the review agent's free-text summary. */
async function listAllTicketIds(pi: ExtensionAPI, cwd: string): Promise<Set<string>> {
  const { stdout } = await execCapture(pi, "backlog", ["task", "list", "--plain"], {
    cwd,
    timeout: 15_000,
  });
  return new Set(parsePlainTaskList(stdout).map((t) => t.id));
}

async function setTicketStatus(
  pi: ExtensionAPI,
  cwd: string,
  ticketId: string,
  status: string,
): Promise<boolean> {
  const { ok } = await execCapture(
    pi,
    "backlog",
    ["task", "edit", ticketId, "-s", status],
    {
      cwd,
      timeout: 15_000,
    },
  );
  return ok;
}

// --- Headless pi worker calls -----------------------------------------------

/**
 * Tagged template for multi-line prompts: strips the template's common leading indentation
 * (so the surrounding code's indentation doesn't leak into the string) and drops a leading/
 * trailing blank line, so a prompt can be written as an ordinary indented template literal
 * instead of an array of lines joined with `.join("\n")`.
 *
 * The indentation is measured from the template's own literal text only, not from any
 * interpolated `${...}` values — several of this file's prompts interpolate multi-line,
 * unindented content (subprocess output, a generated ticket list), and letting those lines
 * pull the common indentation down to zero would defeat the whole point.
 */
function dedent(strings: TemplateStringsArray, ...values: unknown[]): string {
  const indentCandidates: string[] = [];
  strings.forEach((part, i) => {
    const lines = part.split("\n");
    const start = i === 0 ? 0 : 1; // line 0 of parts after the first continues an interpolation
    for (let j = start; j < lines.length; j++) indentCandidates.push(lines[j]);
  });
  const indents = indentCandidates
    .filter((line) => line.trim() !== "")
    .map((line) => line.match(/^ */)![0].length);
  const minIndent = indents.length ? Math.min(...indents) : 0;
  const prefix = " ".repeat(minIndent);

  let raw = strings[0];
  for (let i = 0; i < values.length; i++)
    raw += String(values[i]) + strings[i + 1];

  const lines = raw
    .split("\n")
    .map((line) => (line.startsWith(prefix) ? line.slice(minIndent) : line));
  if (lines[0].trim() === "") lines.shift();
  if (lines.length && lines[lines.length - 1].trim() === "") lines.pop();

  return lines.join("\n");
}

function tailSummary(output: string, maxLen = 240): string {
  const collapsed = output.trim().replace(/\s+/g, " ");
  if (!collapsed) return "(no output)";
  return collapsed.length > maxLen ? `…${collapsed.slice(-maxLen)}` : collapsed;
}

/**
 * Progress-ping instructions appended to the long-running headless prompts (execute, research,
 * plan, review) so the subagent narrates back to the orchestrating session via pi-intercom
 * instead of running silently until it finishes or hits its timeout. Pair with `extensions:
 * [PI_INTERCOM_EXTENSION]` on the same `runHeadless` call — loading the extension without this
 * guidance leaves the tool available but unused, and the guidance without the extension gives
 * the model a tool call that doesn't exist.
 */
function intercomStatusGuidance(mainSessionId: string): string {
  return dedent`
    Progress updates: every few minutes, or after finishing each meaningfully distinct sub-step
    (not more often than that), send a one-line status ping back to the orchestrating session via
    the intercom tool. Use \`send\`, never \`ask\` — nobody is waiting on a reply:
    intercom({ action: "send", to: "${mainSessionId}", message: "<one sentence: what you just
    finished or are doing now>" })
    Skip this entirely if the intercom tool isn't available — it's a courtesy update, not part of
    the task itself.
  `;
}

/**
 * Standing role instructions appended to the orchestrating session's system prompt on every
 * turn while a loop is running (see the `before_agent_start` handler in the default export).
 * Guards against a confirmed live failure mode (2026-08-19): a worker's intercom progress ping
 * ("Starting TASK-58 research") reads like a task assignment, and without explicit role
 * framing the orchestrator spontaneously started parallel research on the same ticket —
 * duplicating the worker's effort and risking conflicting backlog/code edits. Re-appended on
 * every agent start, so the framing survives context compaction.
 */
const ORCHESTRATOR_ROLE_GUIDANCE = dedent`
  Ralph orchestrator role: an autonomous ralph backlog loop is currently running in this
  session. All real ticket work (research, planning, implementation, review) runs in separate
  headless worker sessions; their intercom messages (from sessions named \`subagent-chat-*\`)
  are progress reports about work those workers own end-to-end — NOT tasks assigned to you.
  - Do not perform the workers' work yourself: when a progress report names a ticket, do not
    start researching it, planning it, editing its code, or mutating its backlog record in this
    session. Parallel work duplicates effort and risks conflicting edits; each worker owns its
    ticket until its step finishes.
  - Your job is to orchestrate and report: track the loop with the ralph_status tool, relay
    worker progress to the user, and surface failures or stalls (loop history under
    ~/.pi/agent/ralph/<project>/history.jsonl; worker transcripts under ~/.pi/agent/sessions/).
  - Explicit user instructions always override this framing: if the user directly asks you to
    do something, follow them even if it touches a ralph-managed ticket.
`;

async function runHeadless(
  pi: ExtensionAPI,
  cwd: string,
  prompt: string,
  opts: {
    timeout: number;
    model?: string;
    extensions?: string[];
    noSkills?: boolean;
  },
): Promise<{ ok: boolean; killed: boolean; output: string }> {
  // No --no-session: pi-intercom needs the headless worker to have a live session identity
  // to address progress pings back to the orchestrator from.
  const args = ["-p", "--no-extensions"];
  // Steps that only read a ticket and make a judgment call (triage, choose) don't need any
  // project or global skill — but headless calls inherit the user's full global skill set by
  // default, and a skill can trigger on trigger words in the prompt that have nothing to do
  // with its real purpose. Confirmed live: a "choose the next ticket" prompt listing candidate
  // tickets tripped a globally-mandated Jira/acli skill (triggered by the word "ticket"), which
  // sent the chooser down an irrelevant investigation and burned enough of its turn that it
  // named a winner without ever running the status-edit command it was asked to. Steps that
  // genuinely need a skill (backlog-planner for planning, project skills for implementation)
  // must not pass this — they call runHeadless with noSkills left unset.
  if (opts.noSkills) args.push("--no-skills");
  for (const ext of opts.extensions ?? []) args.push("-e", ext);
  if (opts.model) args.push("--model", opts.model);
  args.push(prompt);
  const { ok, killed, stdout, stderr } = await execCapture(pi, "pi", args, {
    cwd,
    timeout: opts.timeout,
  });
  return { ok, killed, output: (stdout || stderr || "").trim() };
}

/** Prefixes a summary with a timeout marker when the subprocess was killed, so
 * history.jsonl (see stateDirFor) distinguishes "hung until we killed it" from other failures. */
function summarize(
  result: { killed: boolean; output: string },
  maxLen?: number,
): string {
  const prefix = result.killed ? "[timed out] " : "";
  return prefix + tailSummary(result.output, maxLen);
}

/** Scans a headless call's final message for a line matching one of `candidates` exactly
 * (last one wins), falling back to a plain substring search. Shared by any prompt that asks
 * the model to end with one of a fixed set of one-word/one-id answers. */
function extractMarkerLine(
  output: string,
  candidates: string[],
): string | undefined {
  const lines = output.trim().split("\n").reverse();
  for (const line of lines) {
    const trimmed = line.trim();
    if (candidates.includes(trimmed)) return trimmed;
  }
  return candidates.find((candidate) => output.includes(candidate));
}

/** Parses the `REVIEW_PANE_ID: <id>` marker line the review prompt is required to print,
 * so the caller can enforce pane cleanup instead of trusting the model remembered to. */
function extractPaneId(output: string): string | undefined {
  return output.match(/^REVIEW_PANE_ID:\s*(\S+)/m)?.[1];
}

// --- Step implementations ---------------------------------------------------

function setCurrentStep(
  ctx: ExtensionCommandContext,
  state: RalphState,
  text: string,
  timeoutMs?: number,
): void {
  state.currentStep = text;
  state.currentStepStartedAt = new Date().toISOString();
  state.currentStepTimeoutMs = timeoutMs;
  renderWidget(ctx, state);
}

/** `git rev-parse HEAD`, or null if the command itself failed (not "no commits yet" — this
 * repo always has history; a null here means something is wrong with git itself). */
async function currentHeadSha(pi: ExtensionAPI, cwd: string): Promise<string | null> {
  const { ok, stdout } = await execCapture(pi, "git", ["rev-parse", "HEAD"], {
    cwd,
    timeout: 10_000,
  });
  return ok ? stdout.trim() : null;
}

/**
 * Folds any pending `fixup!` commits made since `runStartSha` into the commits they target,
 * via git's own --autosquash convention (a commit whose subject is `fixup! <original subject>`
 * is git's standard marker for "squash me into that commit"). This is how review-time findings
 * that are small enough to patch directly land without a full choose/plan/execute cycle and
 * without leaving a trail of "fix:" commits that later need manual squashing — review-pi-work
 * creates the fixup commit; this is what folds it back in.
 *
 * Only ever touches commits made since `runStartSha`, captured before this run did any work —
 * so this can never reach into history the run didn't create itself. On any failure (most
 * likely a real conflict), aborts and leaves the fixup as a separate commit rather than leaving
 * a rebase half-done; a stray fixup commit is a minor annoyance, a stuck rebase blocks the
 * entire loop.
 */
async function autosquashFixups(
  pi: ExtensionAPI,
  cwd: string,
  runStartSha: string | null,
): Promise<{ ok: boolean; summary: string }> {
  if (!runStartSha) return { ok: true, summary: "skipped (no run-start SHA recorded)" };

  const { stdout: log } = await execCapture(
    pi,
    "git",
    ["log", "--oneline", `${runStartSha}..HEAD`],
    { cwd, timeout: 15_000 },
  );
  if (!/\bfixup! /.test(log)) return { ok: true, summary: "no pending fixups" };

  const rebase = await execCapture(
    pi,
    "git",
    ["-c", "sequence.editor=true", "rebase", "--autosquash", "-i", runStartSha],
    { cwd, timeout: 60_000 },
  );
  if (rebase.ok) return { ok: true, summary: "folded pending fixup commit(s) into their targets" };

  await execCapture(pi, "git", ["rebase", "--abort"], { cwd, timeout: 15_000 });
  return {
    ok: false,
    summary: `autosquash failed, likely a conflict — aborted; fixup commit(s) left unsquashed: ${tailSummary(rebase.stderr || rebase.stdout, 200)}`,
  };
}

async function doExecute(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  cwd: string,
  state: RalphState,
  ticket: Ticket,
): Promise<boolean> {
  setCurrentStep(ctx, state, `executing ${ticket.id}`, EXECUTE_TIMEOUT_MS);
  const shaBefore = await currentHeadSha(pi, cwd);
  // Screenshot-cap guard: without the subagent tool, visual verification reads every
  // rendered screenshot into the executor's own context and dies at 5 images (vLLM
  // 4-image cap) — confirmed killer of TASK-55/57 runs. When the extension can't be
  // found (package moved/removed), degrade gracefully with an explicit fallback
  // instruction rather than silently losing the capability.
  const hasSubagents = existsSync(PI_SUBAGENTS_EXTENSION);
  const screenshotGuidance = hasSubagents
    ? dedent`
        Widget visual verification: never read more than 4 screenshots into your own session (the model provider rejects prompts with >4 images). Delegate screenshot review to subagent calls — one subagent per batch of <=4 images, each reporting findings back as text.
      `
    : dedent`
        Widget visual verification: the subagent tool is NOT available in this session. Never read more than 4 screenshots into your own context (the model provider rejects prompts with >4 images). Instead verify each batch of <=4 screenshots with a separate headless \`pi -p\` call that instructs the fresh process to read the image files with the read tool and report findings as text — each call starts from a clean context, so the 4-image cap is never exceeded.
      `;
  const result = await runHeadless(
    pi,
    cwd,
    dedent`
      /backlog-execute ${ticket.id}

      ${screenshotGuidance}

      ${intercomStatusGuidance(state.mainSessionId)}
    `,
    {
      timeout: EXECUTE_TIMEOUT_MS,
      extensions: [
        PI_INTERCOM_EXTENSION,
        ...(hasSubagents ? [PI_SUBAGENTS_EXTENSION] : []),
      ],
    },
  );

  // A subprocess reporting success — even a Final Summary claiming every AC is met — isn't
  // proof anything actually landed. Confirmed live: a first attempt hit EXECUTE_TIMEOUT_MS and
  // got killed mid-flight; the retry was a fresh subprocess with no memory of that, found the
  // half-finished files already on disk, treated them as "prior work" to build on, and wrote a
  // complete implementation summary with every AC checked off — without the run ever reaching
  // a commit. HEAD not moving is unambiguous, so a "successful" run that leaves it where it
  // started is treated as a failure here regardless of what the subprocess claimed.
  const shaAfter = result.ok ? await currentHeadSha(pi, cwd) : shaBefore;
  const committed = shaBefore !== null && shaAfter !== null && shaBefore !== shaAfter;
  const ok = result.ok && committed;

  if (ok) state.executedSinceReview += 1;
  await recordHistory(cwd, state, {
    kind: "execute",
    ticket: ticket.id,
    outcome: ok ? "ok" : "failed",
    summary:
      result.ok && !committed
        ? `claimed success but no commit landed (HEAD still ${shaBefore?.slice(0, 8) ?? "unknown"}) — ${summarize(result)}`
        : summarize(result),
  });
  return ok;
}

/**
 * Cheap upfront judgment call: is this ticket trivial enough (one-line fix, rename, config
 * tweak) that research and formal planning would just restate it? A failed or ambiguous
 * call defaults to `false` — falling through to the normal (safe, expensive) path costs a
 * few minutes, whereas wrongly skipping planning could not.
 */
async function classifyTrivial(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  cwd: string,
  state: RalphState,
  ticket: Ticket,
): Promise<boolean> {
  setCurrentStep(ctx, state, `triaging ${ticket.id}`, TRIAGE_TIMEOUT_MS);
  const prompt = dedent`
    Run \`backlog task ${ticket.id} --plain\` to read the full ticket ${ticket.id} ("${ticket.title}").

    Judge whether it is trivial enough to skip research and formal planning entirely — a one-line fix, a
    rename, a config tweak, or anything else where a written implementation plan would just restate the
    ticket. If there is any real ambiguity, design work, or more than a handful of lines likely to change,
    it is NOT trivial — when in doubt, say NORMAL.

    End your final message with a line containing exactly one word and nothing else: TRIVIAL or NORMAL.
  `;
  const result = await runHeadless(pi, cwd, prompt, {
    timeout: TRIAGE_TIMEOUT_MS,
    noSkills: true,
  });
  const verdict = extractMarkerLine(result.output, ["TRIVIAL", "NORMAL"]);
  await recordHistory(cwd, state, {
    kind: "plan",
    ticket: ticket.id,
    outcome: result.ok ? "ok" : "failed",
    summary: `triage: ${verdict ?? summarize(result, 80)}`,
  });
  return result.ok && verdict === "TRIVIAL";
}

async function doPlan(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  cwd: string,
  state: RalphState,
  ticket: Ticket,
): Promise<boolean> {
  // A retry (the outer loop re-finding this same still-"Needs Plan" ticket after doPlan
  // returned false) reuses whatever this cache already has for it instead of redoing that
  // work — only the step that actually failed last time re-runs.
  const cached =
    state.planCache?.ticketId === ticket.id ? state.planCache : undefined;

  // Bypasses /backlog-planner's own prerequisite check (unplanned child tickets block
  // planning) and leaves no Implementation Plan on the ticket — accepted tradeoff for
  // skipping both steps outright on genuinely trivial work; see classifyTrivial above.
  let trivial: boolean;
  if (cached?.triage) {
    trivial = cached.triage === "TRIVIAL";
    await recordHistory(cwd, state, {
      kind: "plan",
      ticket: ticket.id,
      outcome: "ok",
      summary: `triage: ${cached.triage} (reused from a prior attempt this run)`,
    });
  } else {
    trivial = await classifyTrivial(pi, ctx, cwd, state, ticket);
    state.planCache = {
      ticketId: ticket.id,
      triage: trivial ? "TRIVIAL" : "NORMAL",
    };
  }

  if (trivial) {
    setCurrentStep(ctx, state, `marking ${ticket.id} Dev Ready (trivial)`);
    const ok = await setTicketStatus(pi, cwd, ticket.id, "Dev Ready");
    await recordHistory(cwd, state, {
      kind: "plan",
      ticket: ticket.id,
      outcome: ok ? "ok" : "failed",
      summary: ok
        ? "trivial — skipped research/planning, marked Dev Ready directly"
        : "trivial — failed to mark Dev Ready",
    });
    if (ok) state.planCache = undefined;
    return ok;
  }

  let researchOutput: string;
  if (cached?.researchOutput !== undefined) {
    researchOutput = cached.researchOutput;
    await recordHistory(cwd, state, {
      kind: "plan",
      ticket: ticket.id,
      outcome: "ok",
      summary: "research: reused from a prior attempt this run",
    });
  } else {
    setCurrentStep(ctx, state, `researching ${ticket.id}`, RESEARCH_TIMEOUT_MS);
    const researchPrompt = dedent`
      Research context to inform planning ticket ${ticket.id} ("${ticket.title}") in this repo.
      Run \`backlog task ${ticket.id} --plain\` first to see the full ticket, then search the web for
      relevant prior art, library documentation, or best practices that would help write a thorough
      implementation plan. Return a concise research summary (bullet points), not a plan.

      ${intercomStatusGuidance(state.mainSessionId)}
    `;
    const research = await runHeadless(pi, cwd, researchPrompt, {
      timeout: RESEARCH_TIMEOUT_MS,
      model: "research",
      extensions: [PI_WEB_ACCESS_EXTENSION, PI_INTERCOM_EXTENSION],
    });
    await recordHistory(cwd, state, {
      kind: "plan",
      ticket: ticket.id,
      outcome: research.ok ? "ok" : "failed",
      summary: `research: ${summarize(research, 120)}`,
    });
    researchOutput = research.output;
    state.planCache = {
      ticketId: ticket.id,
      triage: "NORMAL",
      researchOutput,
    };
  }

  setCurrentStep(ctx, state, `planning ${ticket.id}`, PLAN_TIMEOUT_MS);
  const planPrompt = dedent`
    /backlog-planner ${ticket.id}

    Research gathered before planning (best-effort — the research step may have been cut short by a
    timeout partway through, or its output may just be an unrelated startup warning with no real
    content; use it if it's useful, ignore it and rely on repo context otherwise):
    ${researchOutput.trim() || "(no output was produced)"}

    After planning completes (the ticket has a plan and, if applicable, is labeled planned), set its
    status to Dev Ready: \`backlog task edit ${ticket.id} -s "Dev Ready"\`. If /backlog-planner instead
    exited early because it found unplanned child tickets, leave the status as-is and explain why in
    your final message.

    ${intercomStatusGuidance(state.mainSessionId)}
  `;
  const plan = await runHeadless(pi, cwd, planPrompt, {
    timeout: PLAN_TIMEOUT_MS,
    model: "planning",
    extensions: [PI_INTERCOM_EXTENSION],
  });
  await recordHistory(cwd, state, {
    kind: "plan",
    ticket: ticket.id,
    outcome: plan.ok ? "ok" : "failed",
    summary: summarize(plan),
  });
  if (plan.ok) state.planCache = undefined;
  return plan.ok;
}

async function doChoose(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  cwd: string,
  state: RalphState,
  candidates: Ticket[],
): Promise<boolean> {
  if (candidates.length === 1) {
    const only = candidates[0];
    setCurrentStep(ctx, state, `queuing ${only.id} for planning`);
    const ok = await setTicketStatus(pi, cwd, only.id, "Needs Plan");
    await recordHistory(cwd, state, {
      kind: "choose",
      ticket: only.id,
      outcome: ok ? "ok" : "failed",
      summary: `marked Needs Plan (${only.title})`,
    });
    return ok;
  }

  setCurrentStep(ctx, state, "choosing next ticket", CHOOSE_TIMEOUT_MS);
  const list = candidates.map((c) => `${c.id} - ${c.title}`).join("\n");
  const prompt = dedent`
    The following backlog tickets are unblocked (all dependencies Done) and waiting to be picked up:

    ${list}

    Pick exactly one to queue for planning next, using your judgment about priority, what unblocks the
    most future work, and risk. Do not run any backlog commands yourself — just decide. End your final
    message with a line containing only the chosen ticket ID and nothing else.
  `;
  const result = await runHeadless(pi, cwd, prompt, {
    timeout: CHOOSE_TIMEOUT_MS,
    model: "chat-fast",
    noSkills: true,
  });
  const chosenId = extractMarkerLine(
    result.output,
    candidates.map((c) => c.id),
  );

  // We apply the status change ourselves rather than trusting the subprocess ran `backlog
  // task edit` as instructed — a distracted or truncated run (e.g. one that burns its turn
  // on an unrelated tangent before naming a winner) could report a valid-looking chosen ID
  // without the edit ever having happened. That used to leave the ticket stuck in "To Do",
  // silently un-queued, and get re-chosen next iteration until the repeated-choice guard
  // tripped and stopped the whole loop with no clear cause.
  const validChoice = result.ok && !!chosenId;
  const statusOk = validChoice
    ? await setTicketStatus(pi, cwd, chosenId!, "Needs Plan")
    : false;
  const ok = validChoice && statusOk;
  const summary =
    validChoice && !statusOk
      ? `chose ${chosenId} but failed to set it to Needs Plan — ${summarize(result, 160)}`
      : summarize(result, 160);
  await recordHistory(cwd, state, {
    kind: "choose",
    ticket: chosenId,
    outcome: ok ? "ok" : "failed",
    summary,
  });
  return ok;
}

async function doReview(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  cwd: string,
  state: RalphState,
): Promise<boolean> {
  const n = Math.max(state.executedSinceReview, 1);
  setCurrentStep(
    ctx,
    state,
    `reviewing last ${n} ticket(s)`,
    REVIEW_TIMEOUT_MS,
  );
  const ticketsBefore = await listAllTicketIds(pi, cwd);
  const prompt = dedent`
    You are the review checkpoint for pi's autonomous backlog loop. Use the herdr CLI to have a
    fresh claude subagent audit the last ${n} completed ticket(s):

    1. Split off a new pane for the review agent from pane \`${state.mainPaneId}\` (the pane this
       loop is running in — use this id directly, don't look it up):
       \`herdr pane split ${state.mainPaneId} --direction right --no-focus\`.
    2. Change to pi's working directory in the new pane, then launch the review agent there with
       auto-approved permissions, so it sees the same repo checkout pi is running in. Quote the whole
       \`claude\` invocation as a single argument to \`pane run\` so its double-quoted prompt survives
       intact — e.g.:
       \`herdr pane run <new-pane-id> "cd '${cwd}'"\`
       \`herdr pane run <new-pane-id> 'claude --permission-mode auto "Run the /review-pi-work skill for the last ${n} tickets"'\`
    3. Wait for that pane's agent to finish with a single blocking call — do NOT poll
       \`herdr pane list\` in a sleep loop, that wastes your own turns waiting on a subagent that
       hasn't moved. This pane was split with \`--no-focus\` and nothing ever focuses it, so per
       herdr's own state model it can only ever settle at \`done\` (idle work nobody's looked at
       yet), never \`idle\` (which additionally requires the tab to have been seen in the focused
       UI) — waiting on \`--until idle\` alone would block for the full timeout every time even
       though the agent finished. Accept either:
       \`herdr agent wait <new-pane-id> --until idle --until done --timeout ${REVIEW_TIMEOUT_MS}\`
       (timeout is in milliseconds — ${REVIEW_TIMEOUT_MIN} minutes). A nonzero exit means it timed out;
       treat that the same as a failed review and continue to steps 4-5 anyway.
    4. Read its final output (\`herdr pane read <new-pane-id> --source recent --lines 400\`) and summarize
       what it found, including any new follow-up ticket IDs it filed.
    5. Close the review pane (\`herdr pane close <new-pane-id>\`) — do this even if a step above failed or
       timed out, so the pane never lingers.

    Report back a concise summary of the review findings and any follow-up ticket IDs filed. Regardless of
    what happened above (including if you couldn't close the pane yourself), end your final message with a
    line containing exactly \`REVIEW_PANE_ID: <new-pane-id>\` (the id from step 1) so the caller can verify
    the pane is gone.

    ${intercomStatusGuidance(state.mainSessionId)}
  `;
  const result = await runHeadless(pi, cwd, prompt, {
    timeout: REVIEW_TIMEOUT_MS,
    noSkills: true,
    extensions: [PI_INTERCOM_EXTENSION],
  });

  // Don't trust the model to have actually run step 5 — close the pane ourselves as a
  // guaranteed cleanup pass. Closing an already-closed pane just errors, which is the
  // expected (and ignored) outcome when the model did close it; a successful close here
  // means it didn't, which is worth surfacing since it points at a review pane silently
  // lingering unless we catch it.
  const paneId = extractPaneId(result.output);
  let cleanupNote = "";
  if (paneId) {
    const closed = await execCapture(pi, "herdr", ["pane", "close", paneId], {
      cwd,
      timeout: 10_000,
    });
    if (closed.ok) cleanupNote = ` [cleanup: pane ${paneId} was still open, closed it]`;
  }

  const ticketsAfter = await listAllTicketIds(pi, cwd);
  const createdTickets = [...ticketsAfter].filter((id) => !ticketsBefore.has(id));

  await recordHistory(cwd, state, {
    kind: "review",
    outcome: result.ok ? "ok" : "failed",
    summary: summarize(result, 300) + cleanupNote,
    createdTickets: createdTickets.length ? createdTickets : undefined,
  });
  // Only clear the trigger counter on success. A failed/timed-out review leaves it at or above
  // reviewEvery, so the next loop iteration retries review immediately instead of silently
  // skipping reviewEvery more tickets before trying again — stoppedByFailureStreak still stops
  // the loop after MAX_CONSECUTIVE_FAILURES if review is systemically broken rather than
  // retrying forever.
  if (result.ok) state.executedSinceReview = 0;
  return result.ok;
}

// --- Loop driver -------------------------------------------------------------

function finish(state: RalphState, status: RalphStatus, reason: string): void {
  state.status = status;
  state.currentStep = reason;
  state.currentStepStartedAt = undefined;
  state.currentStepTimeoutMs = undefined;
}

/** True if this step's failure streak just hit the cap; `finish()`s the state with an explanatory reason. */
function stoppedByFailureStreak(
  cwd: string,
  state: RalphState,
  key: string,
  ok: boolean,
): boolean {
  if (!trackFailureStreak(state, key, ok)) return false;
  finish(
    state,
    "stopped",
    `stopping: "${key}" failed ${MAX_CONSECUTIVE_FAILURES} times in a row. This looks like a systemic ` +
      `problem (a hung subprocess or broken tool), not a one-off bad ticket — check ${join(stateDirFor(cwd), "history.jsonl")} ` +
      "before restarting.",
  );
  return true;
}

/** True if `choose` just picked the same ticket MAX_CONSECUTIVE_FAILURES times in a row;
 * `finish()`s the state with an explanatory reason. See `repeatedChoiceStreak` on RalphState
 * for why a ticket cycling back to `choose` repeatedly needs its own detection, separate from
 * failureStreak — each individual execute can report "ok" while making zero real progress. */
function stoppedByRepeatedChoice(
  state: RalphState,
  ticketId: string | undefined,
): boolean {
  if (!ticketId) return false;
  state.repeatedChoiceStreak =
    state.repeatedChoiceStreak?.ticketId === ticketId
      ? { ticketId, count: state.repeatedChoiceStreak.count + 1 }
      : { ticketId, count: 1 };
  if (state.repeatedChoiceStreak.count < MAX_CONSECUTIVE_FAILURES) return false;
  finish(
    state,
    "stopped",
    `stopping: ${ticketId} was chosen ${MAX_CONSECUTIVE_FAILURES} times in a row without completing — it ` +
      "keeps cycling back to unblocked To Do, which usually means it's blocked on something outside pi's " +
      "control (check its Implementation Notes). Resolve it manually or reprioritize before restarting.",
  );
  return true;
}

/**
 * Runs a review, then folds any `fixup!` commits it created back into their targets via
 * autosquashFixups. A squash failure is recorded but doesn't affect the review's own
 * outcome or feed the "review" failure streak — it's a real but non-blocking problem (the
 * fixup just stays as a separate commit instead of a stuck loop), tracked separately from
 * review pipeline health.
 */
async function doReviewAndSquash(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  cwd: string,
  state: RalphState,
  runStartSha: string | null,
): Promise<boolean> {
  const ok = await doReview(pi, ctx, cwd, state);
  const squash = await autosquashFixups(pi, cwd, runStartSha);
  await recordHistory(cwd, state, {
    kind: "squash",
    outcome: squash.ok ? "ok" : "failed",
    summary: squash.summary,
  });
  return ok;
}

/**
 * Runs one courtesy review after the loop has already decided to exit, if any executed
 * tickets since the last review haven't been covered by one yet. Skipped when the loop is
 * exiting *because* review itself just hit the failure streak cap — a broken review
 * pipeline isn't fixed by immediately trying it again. Leaves `state.status`/`currentStep`
 * (and the timing fields `finish()` cleared) as the loop's exit reason set them; this is a
 * best-effort extra step, not a status change.
 */
async function runFinalReviewIfNeeded(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  cwd: string,
  state: RalphState,
  runStartSha: string | null,
): Promise<void> {
  if (state.executedSinceReview <= 0) return;
  if (state.failureStreak?.key === "review") return;

  const exitStatus = state.status;
  const exitStep = state.currentStep;
  const exitStepStartedAt = state.currentStepStartedAt;
  const exitStepTimeoutMs = state.currentStepTimeoutMs;
  await doReviewAndSquash(pi, ctx, cwd, state, runStartSha);
  state.status = exitStatus;
  state.currentStep = exitStep;
  state.currentStepStartedAt = exitStepStartedAt;
  state.currentStepTimeoutMs = exitStepTimeoutMs;
}

/**
 * Reads this run's slice of history.jsonl (not `state.history`, which is capped at
 * MAX_HISTORY and would silently drop early tickets on a long run) and reports what
 * actually got done: tickets executed/planned/chosen and review outcomes.
 */
async function buildFinalSummary(cwd: string, state: RalphState): Promise<string> {
  const raw = await readFile(
    join(stateDirFor(cwd), "history.jsonl"),
    "utf8",
  ).catch(() => "");
  const thisRun = raw
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line) as RalphHistoryEntry)
    .filter((entry) => entry.at >= state.startedAt);

  const distinctTickets = (kind: StepKind, outcome: "ok" | "failed") => [
    ...new Set(
      thisRun
        .filter((e) => e.kind === kind && e.outcome === outcome && e.ticket)
        .map((e) => e.ticket!),
    ),
  ];

  const executed = distinctTickets("execute", "ok");
  const executeFailed = distinctTickets("execute", "failed");
  const planned = distinctTickets("plan", "ok").filter(
    (id) => !executed.includes(id),
  );
  const promoted = distinctTickets("promote", "ok");
  const reviews = thisRun.filter((e) => e.kind === "review");
  const elapsed = formatDuration(Date.now() - Date.parse(state.startedAt));

  const lines = [
    `Ralph run summary: ${state.status} after ${state.loopCount}/${state.iterations} iteration(s), ${elapsed} elapsed`,
    `Reason: ${state.currentStep ?? "(none)"}`,
    executed.length
      ? `Executed (${executed.length}): ${executed.join(", ")}`
      : "Executed: none",
  ];
  if (planned.length) lines.push(`Also touched by planning: ${planned.join(", ")}`);
  if (promoted.length)
    lines.push(`Promoted from Blocked to To Do (${promoted.length}): ${promoted.join(", ")}`);
  if (executeFailed.length) lines.push(`Failed to execute: ${executeFailed.join(", ")}`);
  lines.push(
    `Reviews: ${reviews.length} (${reviews.filter((r) => r.outcome === "ok").length} ok)`,
  );
  const createdByReview = [
    ...new Set(reviews.flatMap((r) => r.createdTickets ?? [])),
  ];
  lines.push(
    createdByReview.length
      ? `New tickets filed by review (${createdByReview.length}): ${createdByReview.join(", ")}`
      : "New tickets filed by review: none",
  );
  const squashFailures = thisRun.filter((e) => e.kind === "squash" && e.outcome === "failed");
  if (squashFailures.length) {
    lines.push(
      `Fixup squash failed ${squashFailures.length}x — left as separate commit(s), check history.jsonl`,
    );
  }
  return lines.join("\n");
}

/**
 * Posts a "ralph-status" custom message into the pi session transcript via `pi.sendMessage()`.
 * Unlike a regular user/assistant message, this doesn't trigger an LLM turn (no `triggerTurn`,
 * default delivery) — it just renders inline, distinctly styled, and sits inertly in history
 * until whatever the user's next real prompt is. That gets ralph's status a permanent, visible
 * record in the transcript itself, complementing the ephemeral `ctx.ui.notify` toast and the
 * OS-level `notifyHuman` alert below. Requires the "ralph-status" renderer registered in the
 * extension's default export.
 */
function postStatusMessage(
  pi: ExtensionAPI,
  text: string,
  level: "info" | "warn",
): void {
  pi.sendMessage({
    customType: "ralph-status",
    content: text,
    display: true,
    details: { level },
  });
}

async function notifyHuman(
  pi: ExtensionAPI,
  cwd: string,
  state: RalphState,
): Promise<void> {
  if (state.status === "stopped" && state.stopRequested) return;
  const needsAttention = state.status === "stopped";
  await execCapture(
    pi,
    "herdr",
    [
      "notification",
      "show",
      needsAttention ? "ralph needs you" : "ralph finished",
      "--body",
      `${state.currentStep ?? ""} (${state.loopCount}/${state.iterations} iterations)`,
      "--sound",
      needsAttention ? "request" : "done",
    ],
    { cwd, timeout: 10_000 },
  ).catch(() => undefined);
}

async function runLoop(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  cwd: string,
  state: RalphState,
): Promise<void> {
  const runStartSha = await currentHeadSha(pi, cwd);
  try {
    while (true) {
      if (state.stopRequested) {
        finish(state, "stopped", "stop requested");
        break;
      }
      if (state.loopCount >= state.iterations) {
        finish(state, "done", `reached ${state.iterations} iteration(s)`);
        break;
      }

      if (state.executedSinceReview >= state.reviewEvery) {
        const ok = await doReviewAndSquash(pi, ctx, cwd, state, runStartSha);
        state.loopCount += 1;
        await persist(cwd, state);
        renderWidget(ctx, state);
        if (stoppedByFailureStreak(cwd, state, "review", ok)) break;
        continue;
      }

      state.loopCount += 1;

      const active =
        (await findFirstByStatus(pi, cwd, "In Progress")) ??
        (await findFirstByStatus(pi, cwd, "Dev Ready"));
      if (active) {
        const ok = await doExecute(pi, ctx, cwd, state, active);
        await persist(cwd, state);
        renderWidget(ctx, state);
        if (stoppedByFailureStreak(cwd, state, `execute:${active.id}`, ok)) break;
        continue;
      }

      const needsPlan = await findFirstByStatus(pi, cwd, "Needs Plan");
      if (needsPlan) {
        const ok = await doPlan(pi, ctx, cwd, state, needsPlan);
        await persist(cwd, state);
        renderWidget(ctx, state);
        if (stoppedByFailureStreak(cwd, state, `plan:${needsPlan.id}`, ok)) break;
        continue;
      }

      let unblocked = await listUnblocked(pi, cwd);
      if (unblocked.length === 0) {
        const promoted = await promoteUnblockedBlockedTickets(pi, ctx, cwd, state);
        await persist(cwd, state);
        renderWidget(ctx, state);
        if (promoted.length > 0) unblocked = await listUnblocked(pi, cwd);
      }
      if (unblocked.length === 0) {
        finish(state, "done", "no unblocked tickets remain");
        break;
      }
      const ok = await doChoose(pi, ctx, cwd, state, unblocked);
      await persist(cwd, state);
      renderWidget(ctx, state);
      if (stoppedByFailureStreak(cwd, state, "choose", ok)) break;
      const chosenTicketId = state.history[state.history.length - 1]?.ticket;
      if (stoppedByRepeatedChoice(state, chosenTicketId)) break;
    }

    await runFinalReviewIfNeeded(pi, ctx, cwd, state, runStartSha);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    finish(state, "stopped", `unexpected error: ${message}`);
  } finally {
    await persist(cwd, state);
    renderWidget(ctx, state);
    stopWidgetTicker();
    const summary = await buildFinalSummary(cwd, state);
    const level = state.status === "done" ? "info" : "warn";
    try {
      ctx.ui.notify(summary, level);
    } catch {
      // ctx is stale (see renderWidget); postStatusMessage below still records the summary.
    }
    postStatusMessage(pi, summary, level);
    await notifyHuman(pi, cwd, state);
  }
}

// --- Progress UI ---------------------------------------------------------

function formatDuration(ms: number): string {
  const totalSeconds = Math.max(0, Math.round(ms / 1000));
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  if (h > 0) return `${h}h${String(m).padStart(2, "0")}m`;
  if (m > 0) return `${m}m${String(s).padStart(2, "0")}s`;
  return `${s}s`;
}

/** ` (Nm left of timeout Mm)` for the current step, or "" if it has no tracked timeout
 * (bookkeeping steps like a single-candidate `choose` don't spawn a headless call). */
function stepTimingSuffix(state: RalphState): string {
  if (!state.currentStepStartedAt || !state.currentStepTimeoutMs) return "";
  const elapsedMs = Date.now() - Date.parse(state.currentStepStartedAt);
  const remainingMs = state.currentStepTimeoutMs - elapsedMs;
  const remaining = formatDuration(remainingMs);
  return ` (${remaining} left of ${formatDuration(state.currentStepTimeoutMs)} timeout)`;
}

function widgetLines(state: RalphState): string[] {
  const step = state.currentStep ? ` · ${state.currentStep}` : "";
  const timing = stepTimingSuffix(state);
  return [
    `ralph: ${state.status} · iter ${state.loopCount}/${state.iterations} · executed ${state.executedSinceReview}/${state.reviewEvery} since review${step}${timing}`,
  ];
}

/** The `ctx` captured by `/ralph` at start is used for the rest of the run — including from
 * the background widget ticker — so it can outlive the session it was captured from (the user
 * runs `/new`, forks, switches sessions, or reloads elsewhere while ralph keeps looping). pi
 * then throws on any `ctx.ui` access. That's not recoverable here, and the loop's real work
 * (headless subprocess calls via `pi`, not `ctx`) doesn't depend on it, so just stop trying to
 * paint the widget instead of taking the whole process down with an uncaught exception. */
function renderWidget(ctx: ExtensionCommandContext, state: RalphState): void {
  try {
    ctx.ui.setWidget("ralph", widgetLines(state));
  } catch {
    stopWidgetTicker();
  }
}

/** Ticks the persistent `ralph` widget every second while a run is active, so the
 * timeout/remaining-time display in `widgetLines` counts down live instead of only
 * updating at step transitions. */
let widgetTicker: ReturnType<typeof setInterval> | null = null;

function startWidgetTicker(
  ctx: ExtensionCommandContext,
  state: RalphState,
): void {
  stopWidgetTicker();
  widgetTicker = setInterval(() => renderWidget(ctx, state), 1000);
  widgetTicker.unref?.();
}

function stopWidgetTicker(): void {
  if (widgetTicker) {
    clearInterval(widgetTicker);
    widgetTicker = null;
  }
}

type DashboardTheme = {
  bold: (s: string) => string;
  fg: (color: string, s: string) => string;
};

const plainTheme: DashboardTheme = { bold: (s) => s, fg: (_c, s) => s };

function renderDashboardLines(
  state: RalphState,
  theme: DashboardTheme,
): string[] {
  const lines: string[] = [];
  lines.push(theme.bold(theme.fg("accent", "Ralph Loop")));
  lines.push(`status: ${state.status}`);
  lines.push(`iteration: ${state.loopCount} / ${state.iterations}`);
  lines.push(
    `executed since last review: ${state.executedSinceReview} / ${state.reviewEvery}`,
  );
  if (state.currentStep) {
    lines.push(`current: ${state.currentStep}${stepTimingSuffix(state)}`);
  }
  lines.push("");
  lines.push(theme.bold("recent history"));
  const recent = state.history.slice(-10).reverse();
  if (recent.length === 0) {
    lines.push("  (none yet)");
  } else {
    for (const entry of recent) {
      const marker = entry.outcome === "ok" ? "✓" : "✗";
      const ticketPart = entry.ticket ? ` ${entry.ticket}` : "";
      lines.push(`  ${marker} [${entry.kind}]${ticketPart} — ${entry.summary}`);
    }
  }
  lines.push("");
  lines.push(theme.fg("muted", "Esc to close (updates live while ralph runs)"));
  return lines;
}

async function showProgressDashboard(
  ctx: ExtensionCommandContext,
  state: RalphState,
): Promise<void> {
  await ctx.ui.custom<void>((tui, theme, _keybindings, done) => {
    let cachedWidth: number | undefined;
    let cachedLines: string[] | undefined;

    const interval = setInterval(() => {
      cachedWidth = undefined;
      cachedLines = undefined;
      tui.requestRender();
    }, 1000);

    const close = () => {
      clearInterval(interval);
      done();
    };

    return {
      render(width: number): string[] {
        if (cachedWidth === width && cachedLines) return cachedLines;
        cachedLines = renderDashboardLines(state, theme).map((line) =>
          truncateToWidth(line, width),
        );
        cachedWidth = width;
        return cachedLines;
      },
      invalidate(): void {
        cachedWidth = undefined;
        cachedLines = undefined;
      },
      handleInput(data: string): void {
        if (matchesKey(data, Key.escape)) close();
      },
    };
  });
}

// --- Commands ----------------------------------------------------------------

function parsePositiveInt(token: string): number | undefined {
  const parsed = Number.parseInt(token, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : undefined;
}

/**
 * Lets the LLM answer questions about the running ralph loop on demand, since nothing about
 * ralph's progress otherwise enters this session's context — `setCurrentStep`/`renderWidget`
 * only touch the UI widget, which the model never sees. Reads `activeState` directly (the same
 * live object `/ralph-progress` renders) rather than the on-disk state.json (see stateDirFor),
 * which only gets rewritten at specific checkpoints and can lag behind what's actually happening
 * mid-step.
 */
const ralphStatusTool = defineTool({
  name: "ralph_status",
  label: "Ralph Status",
  description:
    "Reports the live status of the autonomous ralph backlog loop (plan/execute/review tickets) " +
    "running in this pi session, if any: current step, iteration progress, and recent history.",
  promptSnippet: "Check live status of the running ralph autonomous backlog loop",
  promptGuidelines: [
    "Use ralph_status when the user asks what ralph is doing, whether it's running or stuck, " +
      "or wants a progress update on the autonomous backlog loop.",
  ],
  parameters: Type.Object({}),
  async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
    const text = activeState
      ? renderDashboardLines(activeState, plainTheme).join("\n")
      : "ralph has not been run in this session (use /ralph to start it).";
    return { content: [{ type: "text", text }], details: {} };
  },
});

export default function (pi: ExtensionAPI) {
  pi.registerTool(ralphStatusTool);

  pi.registerMessageRenderer("ralph-status", (message, _options, theme) => {
    const details = message.details as { level: "info" | "warn" } | undefined;
    const level = details?.level ?? "info";
    const color = level === "warn" ? "warning" : "success";
    const prefix = theme.fg(color, `[ralph ${level === "warn" ? "needs you" : "done"}]`);
    const box = new Box(1, 1, (t) => theme.bg("customMessageBg", t));
    box.addChild(new Text(`${prefix} ${message.content}`, 0, 0));
    return box;
  });

  pi.registerCommand("ralph", {
    description:
      "Start the autonomous backlog loop (plan/execute/review tickets until done or iteration limit)",
    handler: async (args, ctx) => {
      if (
        activeState &&
        (activeState.status === "running" || activeState.status === "stopping")
      ) {
        ctx.ui.notify(
          `ralph is already ${activeState.status} (iteration ${activeState.loopCount}/${activeState.iterations}). Use /ralph-stop first.`,
          "warn",
        );
        return;
      }
      if (process.env.HERDR_ENV !== "1") {
        ctx.ui.notify(
          "ralph requires running inside a herdr-managed pane (HERDR_ENV=1) because the review step drives a herdr pane.",
          "error",
        );
        return;
      }
      // Captured once here rather than rediscovered by each review call via `herdr pane
      // list` — the headless review subprocess runs in this same pane (it's a child process
      // in the same terminal), so this env var already names it deterministically. Guarded
      // separately from HERDR_ENV above: herdr should always set both together, but a prompt
      // built around an empty pane id would fail confusingly deep into a review run instead
      // of here at the point we can still give a clear error.
      const mainPaneId = process.env.HERDR_PANE_ID;
      if (!mainPaneId) {
        ctx.ui.notify(
          "ralph requires HERDR_PANE_ID to be set (herdr should set this alongside HERDR_ENV=1) so the review step knows which pane to split.",
          "error",
        );
        return;
      }

      const tokens = (args ?? "").trim().split(/\s+/).filter(Boolean);
      let iterations = DEFAULT_ITERATIONS;
      let reviewEvery = DEFAULT_REVIEW_EVERY;

      if (tokens.length >= 1) {
        const parsed = parsePositiveInt(tokens[0]);
        if (parsed === undefined) {
          ctx.ui.notify(`Invalid iterations value: "${tokens[0]}"`, "error");
          return;
        }
        iterations = parsed;
      }
      if (tokens.length >= 2) {
        const parsed = parsePositiveInt(tokens[1]);
        if (parsed === undefined) {
          ctx.ui.notify(`Invalid reviewEvery value: "${tokens[1]}"`, "error");
          return;
        }
        reviewEvery = parsed;
      }

      const cwd = ctx.cwd;
      activeState = createState(
        iterations,
        reviewEvery,
        ctx.sessionManager.getSessionId(),
        mainPaneId,
      );
      await persist(cwd, activeState);
      renderWidget(ctx, activeState);
      startWidgetTicker(ctx, activeState);
      ctx.ui.notify(
        `ralph started: ${iterations} iteration(s), reviewing every ${reviewEvery} execute(s).`,
        "info",
      );

      void runLoop(pi, ctx, cwd, activeState);
    },
  });

  pi.registerCommand("ralph-stop", {
    description: "Request a graceful stop of the running ralph loop",
    handler: async (_args, ctx) => {
      if (!activeState || activeState.status !== "running") {
        ctx.ui.notify("ralph is not currently running.", "info");
        return;
      }
      activeState.stopRequested = true;
      activeState.status = "stopping";
      renderWidget(ctx, activeState);
      ctx.ui.notify("ralph will stop after the current step finishes.", "info");
    },
  });

  pi.registerCommand("ralph-progress", {
    description: "Show the ralph loop's current progress",
    handler: async (_args, ctx) => {
      if (!activeState) {
        ctx.ui.notify(
          "ralph has not been run yet in this session. Use /ralph to start it.",
          "info",
        );
        return;
      }
      if (ctx.mode === "tui") {
        await showProgressDashboard(ctx, activeState);
      } else {
        ctx.ui.notify(
          renderDashboardLines(activeState, plainTheme).join("\n"),
          "info",
        );
      }
    },
  });

  pi.registerCommand("ralph-clear", {
    description: "Clear the ralph status widget once the loop has finished",
    handler: async (_args, ctx) => {
      if (!activeState) {
        ctx.ui.notify("ralph has not been run in this session.", "info");
        return;
      }
      if (activeState.status === "running" || activeState.status === "stopping") {
        ctx.ui.notify(
          "ralph is still running — use /ralph-stop first, then /ralph-clear.",
          "warn",
        );
        return;
      }
      ctx.ui.setWidget("ralph", undefined);
      ctx.ui.notify("Cleared the ralph status widget.", "info");
    },
  });

  // While the loop is live, frame every turn of THIS session as orchestration-only. Worker
  // progress pings arrive as ordinary injected user messages; without this standing
  // instruction the model treats them as task assignments and starts doing the workers'
  // work in parallel (confirmed live 2026-08-19 — see ORCHESTRATOR_ROLE_GUIDANCE).
  pi.on("before_agent_start", async (event) => {
    const state = activeState;
    if (!state || (state.status !== "running" && state.status !== "stopping")) {
      return undefined;
    }
    return {
      systemPrompt: event.systemPrompt + "\n\n" + ORCHESTRATOR_ROLE_GUIDANCE,
    };
  });

  pi.on("session_shutdown", async () => {
    stopWidgetTicker();
    if (
      activeState &&
      (activeState.status === "running" || activeState.status === "stopping")
    ) {
      activeState.status = "stopped";
      activeState.currentStep = "session ended";
    }
  });
}
