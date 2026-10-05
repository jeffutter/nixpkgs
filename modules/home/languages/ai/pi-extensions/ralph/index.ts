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
 * risk compounding across however many are loaded. A few exceptions re-enable a
 * specific extension via `-e` (`--no-extensions` only disables auto-discovery;
 * explicit `-e` paths still load): the research step's web search needs
 * `pi-web-access`; the execute/research/plan/review steps load `pi-intercom`
 * so they can ping the orchestrating session with progress updates (see
 * `intercomStatusGuidance`); and the execute and plan steps load
 * `@gotgenes/pi-subagents` so screenshot verification and `/backlog-planner`'s
 * codebase research can be delegated to nested subagents instead of running
 * inline — without it, planning's research runs serially (confirmed live: two
 * consecutive 20-min timeouts on TASK-051, both still mid-research at the kill).
 * The execute/research/plan/review steps also load the global `thinking-router`
 * extension (see THINKING_ROUTER_EXTENSION). All of these knowingly pay the
 * hang-risk tax above. It is cheap now: `TranscriptWatch` sees a worker's final
 * response land in its transcript and reaps a process that then fails to exit
 * within FINISHED_EXIT_GRACE_MS as a success, and any other hang goes quiet and is
 * stopped at WORKER_IDLE_LIMIT_MS.
 * Skills are unaffected — that's a separate `--no-skills` flag we don't touch.
 *
 * The orchestrating session gets the mirror-image framing: while a loop is
 * running, a `before_agent_start` handler appends `ORCHESTRATOR_ROLE_GUIDANCE`
 * to this session's system prompt on every turn, so worker progress pings
 * (which arrive as ordinary injected user messages) are read as status
 * reports to relay — not task assignments to execute in parallel with the
 * worker that owns the ticket.
 *
 * Pings never trigger an orchestrator turn: pi-intercom's config
 * (~/.pi/agent/intercom/config.json) sets `inboundTrigger: "replies"`, so a
 * plain `send` ping lands in the transcript inertly (the user reads it live)
 * and only a genuine `ask` reply triggers a model response. That kills both
 * failure modes confirmed live — wasted orchestrator turns on routine pings,
 * and the orchestrator intercom-acknowledging a worker, which injects a
 * message into the worker's own context mid-task and interrupts it. Delivery
 * is guaranteed by the broker, so no acknowledgement exists or is expected.
 * The setting is loaded once at extension init, so sessions started before
 * it was written keep triggering turns on pings until restarted.
 */

import { createHash, randomUUID } from "node:crypto";
import {
  closeSync,
  existsSync,
  openSync,
  readdirSync,
  readFileSync,
  readSync,
  statSync,
} from "node:fs";
import {
  appendFile,
  mkdir,
  readdir,
  readFile,
  writeFile,
} from "node:fs/promises";
import { homedir } from "node:os";
import { basename, join, resolve } from "node:path";
import {
  AssistantMessageComponent,
  BashExecutionComponent,
  BranchSummaryMessageComponent,
  buildSessionContext,
  CompactionSummaryMessageComponent,
  defineTool,
  getMarkdownTheme,
  parseSessionEntries,
  parseSkillBlock,
  SkillInvocationMessageComponent,
  ToolExecutionComponent,
  UserMessageComponent,
} from "@earendil-works/pi-coding-agent";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
  SessionContext,
  SessionEntry,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { Type } from "@earendil-works/pi-ai";
import type { Usage } from "@earendil-works/pi-ai";
import {
  Box,
  Container,
  Key,
  matchesKey,
  Spacer,
  Text,
  truncateToWidth,
  visibleWidth,
} from "@earendil-works/pi-tui";
import type { Component, MarkdownTheme, TUI } from "@earendil-works/pi-tui";

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

/**
 * Where each headless worker's own pi session (its full turn-by-turn transcript, not just
 * the tail `runHeadless` captures) is stored — see `runHeadless`'s `--session-id`/
 * `--session-dir` and `/ralph-log`, which reads these files back to render a step's log the
 * same way an interactive pi session renders. Namespaced under ralph's own state dir rather
 * than pi's default per-project sessions directory for two reasons: the file is then locatable
 * deterministically by session id alone (`<timestamp>_<id>.jsonl`, glob for the suffix) without
 * reverse-engineering pi's own directory-naming scheme, and dozens of a long ralph run's
 * headless workers don't clutter the project's interactive session list (`pi --resume`).
 */
function sessionDirFor(cwd: string): string {
  return join(stateDirFor(cwd), "sessions");
}

/** Locates a headless worker's session file by the id `runHeadless` gave it — see
 * `sessionDirFor`. Returns undefined if the directory or a matching file doesn't exist yet
 * (a worker's session file is only created after its first assistant response, per pi's own
 * session-manager, so a step that just started may not have one for a moment). */
async function resolveSessionFile(
  cwd: string,
  sessionId: string,
): Promise<string | undefined> {
  let files: string[];
  try {
    files = await readdir(sessionDirFor(cwd));
  } catch {
    return undefined;
  }
  const match = files.find((f) => f.endsWith(`_${sessionId}.jsonl`));
  return match ? join(sessionDirFor(cwd), match) : undefined;
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
 *
 * It also splits the result by assignee (`--assignee agent|human|all`, default `agent`), which
 * is what keeps the loop off `@human` tickets — see AssigneeFilter below.
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

/**
 * Worker liveness is read from the worker's own transcript, not from anything the worker
 * chooses to send — see `TranscriptWatch`. These are its limits.
 *
 * History: liveness used to be intercom pings, each one resetting a per-phase deadline. That
 * measured whether the model remembered to ping, not whether it was working. Measured
 * 2026-10-03 on weasel: all 12 most recent "silent" kills were live workers, ten of them with
 * a transcript entry under 5 minutes before the kill and none with a ping in the 40 minutes
 * before it. Across ~250 workers, counting their nested subagents' transcripts, the longest
 * quiet stretch was 21 minutes and the 99.9th percentile gap 5.4 minutes.
 */
const WORKER_POLL_INTERVAL_MS = 15_000;
/** No new transcript entry anywhere in a worker's tree for this long means it is dead: a hung
 * process, a stalled model stream, or a generation stuck reasoning in circles (pi writes an
 * assistant message only once it completes, so an endless thinking block writes nothing).
 * About 1.5x the longest healthy gap observed — see above. */
const WORKER_IDLE_LIMIT_MS = 30 * 60_000;
/** Hard wall-clock cap for any long-running worker step, whatever its transcript says. It is
 * the backstop for a worker that stays busy without converging in a way the loop detectors in
 * `TranscriptWatch` do not recognise. Longest successful steps observed: 163m (plan), 117m
 * (execute) — so the cap sits well clear of real work. */
const WORKER_CEILING_MS = 4 * 60 * 60_000;
/** Tool-call loop detector: the same call (tool name + identical arguments) quickly returning
 * the same result this many times inside the window, in any one transcript, is a model
 * spinning, not working. Keyed on model-agnostic transcript structure, so it holds for any
 * worker model; the thresholds are calibrated from the current one.
 * Healthy max observed across ~300 transcripts: 3 identical calls within any 20-call span.
 * Only calls that return within LOOP_FAST_CALL_MS count, so a deliberate poll that sleeps
 * between checks (see intercomStatusGuidance) never looks like a loop. */
const LOOP_REPEAT_LIMIT = 8;
const LOOP_REPEAT_WINDOW_MS = 15 * 60_000;
const LOOP_FAST_CALL_MS = 30_000;
/** Reasoning-loop detector: this many consecutive responses cut off at the output token limit
 * (stopReason "length") in one transcript. Healthy runs: 2 such responses across ~8,000. */
const LOOP_LENGTH_STOP_LIMIT = 3;
/** After the worker's top-level transcript records its final response (stopReason "stop"),
 * the process should exit within seconds. Past this grace with no further activity, it has
 * hit the known post-response hang (see file header) and is reaped as a success. */
const FINISHED_EXIT_GRACE_MS = 2 * 60_000;

/** Path assumption: wherever this user's `@gotgenes/pi-subagents` package currently
 * resolves — the live `npm/` tree (npm2/npm3 are stale pre-migration backups; verified
 * 2026-08-18 via package versions and lockfile mtimes). May need updating if `pi update`
 * changes the install layout. Gives executors the subagent tool so widget screenshot
 * verification can be delegated to nested subagents (fresh context each) instead of
 * reading >4 screenshots into the executor's own context and tripping the vLLM
 * --limit-mm-per-prompt image=4 hard cap (HTTP 400). Verified end-to-end 2026-08-18:
 * a --no-extensions parent with this -e flag spawns in-process children that load
 * the parent's extensions (minus the recursion-guarded dispatch tools) and can read
 * images fine. Same mechanism also lets the planning step spawn parallel Explore
 * subagents for `/backlog-planner`'s codebase research (verified headless: `pi -p
 * --no-session --no-extensions -e <this file>` spawns an Explore subagent that
 * completes in ~50s). */
const PI_SUBAGENTS_EXTENSION = join(
  homedir(),
  ".pi/agent/npm/node_modules/@gotgenes/pi-subagents/src/index.ts",
);

/** The global thinking-router extension (deployed by ai.nix). It reclassifies each worker
 * model turn with Jev and may move the step's `thinking` level up or down by one rung, so the
 * per-step levels below remain the anchor rather than a fixed setting. Loaded only by the
 * long-running reasoning-model steps (execute, research, plan, review). Triage and
 * choose run on chat-fast, which has no reasoning, so the router would do nothing there but add
 * hang risk. Subagents spawned by any worker pick the router up on their own via global discovery,
 * whether or not the worker loads it. */
const THINKING_ROUTER_EXTENSION = join(homedir(), ".pi/agent/extensions/thinking-router.ts");

const DEFAULT_ITERATIONS = 16;
const DEFAULT_REVIEW_EVERY = 3;

/** Budgets, not liveness limits: every step is also under `TranscriptWatch`. Triage and choose
 * are single judgment calls on a fast model. Research is best-effort input to planning, so it
 * gets a cost cap rather than WORKER_CEILING_MS — successful research ran up to 44m (weasel,
 * 164 steps through 2026-10-03), most under 25m. Every other step runs to WORKER_CEILING_MS. */
const TRIAGE_TIMEOUT_MS = 5 * 60_000;
const CHOOSE_TIMEOUT_MS = 10 * 60_000;
const RESEARCH_TIMEOUT_MS = 60 * 60_000;
/** How long the review worker waits on its herdr review pane in total. It waits in
 * REVIEW_WAIT_CHUNK_MIN slices so its own transcript keeps moving well inside
 * WORKER_IDLE_LIMIT_MS while it blocks. */
const REVIEW_WAIT_MIN = 60;
const REVIEW_WAIT_CHUNK_MIN = 10;

/**
 * A step that fails this many times in a row (same kind + ticket) stops the
 * loop instead of retrying forever. Repeated identical failure means the loop
 * should stop spending its budget on this step — but *why* it failed is not
 * something the count itself can tell you, and asserting a cause you have not
 * measured sends the reader off to check the wrong thing. Confirmed live
 * (2026-09-11, TASK-038.03.02): two consecutive execute failures were stopped
 * with "this looks like a systemic problem (a hung subprocess or broken tool)",
 * while the session logs showed both workers actively editing files when they
 * were cut exactly 40 minutes after their last intercom ping — a liveness
 * timeout from a too-large ticket and dropped ping discipline, with nothing
 * hung anywhere.
 *
 * So each failure carries a `FailureClass` into history.jsonl, and
 * `stoppedByFailureStreak` composes the stop reason from the classes it
 * actually observed rather than from one guess.
 */
const MAX_CONSECUTIVE_FAILURES = 2;

/** How a step failed. Produced where the truth lives (`execCapture` for the process,
 * `doExecute`'s HEAD comparison for the no-commit case), stored on the history entry, and
 * read back by `stoppedByFailureStreak` — see MAX_CONSECUTIVE_FAILURES for why the count
 * alone is not a diagnosis. */
type FailureClass =
  /** `pi.exec` never returned even after our abort fired: a genuinely wedged subprocess,
   * which may still be running orphaned. The only class here that really is systemic. */
  | "wedged"
  /** Killed because nothing in the worker's transcript tree (its own session file or any
   * nested subagent's) changed for WORKER_IDLE_LIMIT_MS. Unlike the old ping-based signal this
   * needs no cooperation from the model, so silence here really is a stalled process or model. */
  | "silent"
  /** Killed by a `TranscriptWatch` loop detector: the same quick tool call repeated, or
   * responses repeatedly cut off at the output token limit. */
  | "looping"
  /** Killed at its fixed budget: WORKER_CEILING_MS, or triage/choose's short budget. */
  | "timeout"
  /** The subprocess exited nonzero on its own — the step itself failed, no timeout involved. */
  | "exit"
  /** The worker claimed success but HEAD never moved: work left uncommitted on disk, which
   * the next attempt inherits as half-finished "prior work". */
  | "no-commit";

type RalphStatus = "running" | "stopping" | "stopped" | "done";

type StepKind = "execute" | "plan" | "choose" | "review" | "promote" | "squash";

type RalphHistoryEntry = {
  at: string;
  kind: StepKind;
  ticket?: string;
  outcome: "ok" | "failed";
  summary: string;
  /** Why a failed step failed — see FailureClass. Absent on success and on failures with no
   * headless subprocess behind them (a backlog CLI call that merely returned nonzero), where
   * we genuinely do not know. Read back by stoppedByFailureStreak to word the stop reason. */
  failure?: FailureClass;
  /** New ticket IDs that appeared between the start and end of this step — only populated
   * for review steps, via a deterministic before/after diff rather than parsing the review
   * agent's free-text summary for ticket mentions. */
  createdTickets?: string[];
  /** The headless worker session behind this step, if any (bookkeeping entries with no
   * `runHeadless` call — a cached triage/research reuse, the trivial mark-Dev-Ready path —
   * leave this unset). Resolved back to a transcript file by `/ralph-log` via
   * `resolveSessionFile`. */
  sessionId?: string;
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
  /** The hard budget backing the current step's subprocess call, if it has one (bookkeeping
   * steps like a single-candidate `choose` don't spawn a headless call and leave this unset). */
  currentStepTimeoutMs?: number;
  /** When the current step's worker last wrote to its transcript tree (epoch ms), as seen by
   * `TranscriptWatch`. The widget shows it as "quiet Nm" against WORKER_IDLE_LIMIT_MS. */
  currentStepLastActivityAt?: number;
  /** The in-flight step's worker session id, for `/ralph-log` to tail live — set by
   * `runHeadless` when it launches the worker. Cleared at the start of every step by
   * `setCurrentStep`, so a bookkeeping step with no worker never shows as "running" in
   * `/ralph-log`'s picker. */
  currentStepSessionId?: string;
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
  /** Set when the loop stops because its own pool was empty: unblocked `To Do` tickets assigned
   * to a person. Only ever populated on that path, so an empty field means either there was
   * agent work throughout or the run stopped for some other reason — see buildFinalSummary. */
  waitingOnHuman?: Ticket[];
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
    currentStepLastActivityAt: undefined,
    currentStepSessionId: undefined,
    startedAt: new Date().toISOString(),
    history: [],
    failureStreak: undefined,
    repeatedChoiceStreak: undefined,
    waitingOnHuman: undefined,
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
 *
 * Liveness watch: long-running headless steps pass `opts.watch` (see TranscriptWatch),
 * polled every WORKER_POLL_INTERVAL_MS. Once it returns a verdict we abort the process
 * right away and re-arm the watchdog to give up WATCHDOG_GRACE_MS later, so an early kill
 * carries the same "abort, then stop waiting" guarantee as a timeout. `timeout` stays the
 * hard ceiling either way.
 */
const WATCHDOG_GRACE_MS = 30_000;

/** Why a liveness watch wants a worker stopped. "finished" is not a failure: the worker
 * recorded its final response and then never exited — see FINISHED_EXIT_GRACE_MS. */
type WatchVerdict = { kind: "silent" | "looping" | "finished"; detail: string };

type ExecResult = {
  ok: boolean;
  killed: boolean;
  stdout: string;
  stderr: string;
  /** Why the call failed, once we know it did (see FailureClass). Undefined on success. */
  failure?: FailureClass;
  /** What the liveness watch saw when it stopped the process, if it did. */
  verdict?: WatchVerdict;
  /** Set on the promise the watchdog resolves, so a wedged exec is told apart from one we
   * successfully aborted. */
  watchdogFired?: boolean;
};

/** Classifies a failed exec from what actually distinguishes the causes: whether `pi.exec`
 * ever came back, and who killed it — a liveness verdict or the fixed budget. */
function classifyExecFailure(
  raced: ExecResult,
  verdict: WatchVerdict | undefined,
): FailureClass {
  if (raced.watchdogFired) return "wedged";
  if (verdict && verdict.kind !== "finished") return verdict.kind;
  if (raced.killed) return "timeout";
  return "exit";
}

async function execCapture(
  pi: ExtensionAPI,
  cmd: string,
  args: string[],
  opts: {
    cwd: string;
    timeout?: number;
    watch?: () => WatchVerdict | undefined;
  },
): Promise<ExecResult> {
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

  let watchdogResolve: ((r: ExecResult) => void) | undefined;
  const watchdog = new Promise<ExecResult>((resolve) => {
    watchdogResolve = resolve;
  });
  const armWatchdog = (delayMs: number): ReturnType<typeof setTimeout> => {
    const timer = setTimeout(
      () =>
        watchdogResolve!({
          ok: false,
          killed: true,
          stdout: "",
          stderr: `(watchdog: "${cmd}" exec call never returned after being aborted — pi.exec's timeout and our own abort signal both failed to kill it; the process may still be running orphaned)`,
          watchdogFired: true,
        }),
      delayMs,
    );
    timer.unref?.();
    return timer;
  };
  const abortTimer = setTimeout(() => controller.abort(), opts.timeout);
  abortTimer.unref?.();
  let watchdogTimer = armWatchdog(opts.timeout + WATCHDOG_GRACE_MS);

  let verdict: WatchVerdict | undefined;
  let poller: ReturnType<typeof setInterval> | undefined;
  if (opts.watch) {
    const watch = opts.watch;
    poller = setInterval(() => {
      if (verdict) return;
      try {
        verdict = watch();
      } catch {
        // A broken watch must not kill a worker; the hard ceiling still bounds it.
      }
      if (!verdict) return;
      controller.abort();
      clearTimeout(watchdogTimer);
      watchdogTimer = armWatchdog(WATCHDOG_GRACE_MS);
    }, WORKER_POLL_INTERVAL_MS);
    poller.unref?.();
  }

  const raced = await Promise.race([execPromise, watchdog]);
  clearTimeout(abortTimer);
  clearTimeout(watchdogTimer);
  if (poller) clearInterval(poller);
  // The worker's work is complete; only its exit hung. Even a wedged exec counts as done here,
  // since what the step produced is already on disk and in the transcript.
  if (verdict?.kind === "finished") {
    return { ...raced, ok: true, killed: false, verdict };
  }
  return {
    ...raced,
    verdict,
    failure: raced.ok ? undefined : classifyExecFailure(raced, verdict),
  };
}

/** Incremental read state for one transcript file inside a TranscriptWatch. */
type TranscriptTail = {
  offset: number;
  /** Bytes after the last newline read so far: a line pi is still writing. */
  partial: Buffer;
  /** Tool calls awaiting their result, by call id. */
  pending: Map<string, { key: string; name: string; at: number }>;
  /** Result timestamps of quick calls, by call+result fingerprint, pruned to LOOP_REPEAT_WINDOW_MS. */
  quickCalls: Map<string, number[]>;
  /** Consecutive assistant responses cut off at the output token limit. */
  lengthStops: number;
};

/**
 * Liveness and loop detection for one headless worker, read from transcripts pi already
 * writes: the worker's own session file (see runHeadless's --session-dir/--session-id) plus
 * every nested subagent transcript pi-subagents writes under `<session file minus .jsonl>/`
 * (its `tasks/` dir, recursively for subagents of subagents). Nothing here depends on the
 * worker model cooperating — the reason this replaced intercom-ping heartbeats (see
 * WORKER_IDLE_LIMIT_MS).
 *
 * Each `check()` reads the new bytes of every file and returns a verdict once one holds:
 *   - silent: no file in the tree changed for WORKER_IDLE_LIMIT_MS (from launch, until the
 *     first file appears). Catches hung processes, stalled streams, and a generation stuck
 *     reasoning in circles, which writes nothing until it completes.
 *   - looping: in any one transcript, LOOP_REPEAT_LIMIT quick identical tool calls returning
 *     identical results within LOOP_REPEAT_WINDOW_MS, or LOOP_LENGTH_STOP_LIMIT consecutive token-limit cutoffs. A
 *     looping model keeps the transcript growing, so growth alone cannot prove progress.
 *   - finished: the top-level transcript ends on a final response and nothing has moved for
 *     FINISHED_EXIT_GRACE_MS.
 * Activity is file mtime, so any write counts. Never throws: an unreadable file or malformed
 * line is skipped, which errs toward keeping the worker alive until WORKER_CEILING_MS.
 */
class TranscriptWatch {
  /** Newest write anywhere in the transcript tree (epoch ms); launch time until one exists. */
  lastActivityAt = Date.now();
  /** The top-level transcript's final response text while it is the latest message — the
   * step's output when the process has to be reaped before printing it. */
  finalText: string | undefined;
  private parentFile: string | undefined;
  private readonly tails = new Map<string, TranscriptTail>();
  private loop: WatchVerdict | undefined;

  constructor(
    private readonly sessionDir: string,
    private readonly sessionId: string,
  ) {}

  check(): WatchVerdict | undefined {
    for (const file of this.files()) this.scan(file);
    if (this.loop) return this.loop;
    const quiet = Date.now() - this.lastActivityAt;
    if (this.finalText !== undefined && quiet >= FINISHED_EXIT_GRACE_MS) {
      return {
        kind: "finished",
        detail: `process still running ${formatDuration(quiet)} after its final response`,
      };
    }
    if (quiet >= WORKER_IDLE_LIMIT_MS) {
      return {
        kind: "silent",
        detail: this.parentFile
          ? `no transcript activity for ${formatDuration(quiet)}`
          : `no transcript for session ${this.sessionId} appeared in ${this.sessionDir} within ${formatDuration(quiet)}`,
      };
    }
    return undefined;
  }

  private files(): string[] {
    if (!this.parentFile) {
      try {
        const name = readdirSync(this.sessionDir).find((f) =>
          f.endsWith(`_${this.sessionId}.jsonl`),
        );
        if (name) this.parentFile = join(this.sessionDir, name);
      } catch {
        // Session dir not created yet.
      }
    }
    if (!this.parentFile) return [];
    const files = [this.parentFile];
    const subagentRoot = this.parentFile.slice(0, -".jsonl".length);
    try {
      for (const f of readdirSync(subagentRoot, { recursive: true }) as string[]) {
        if (f.endsWith(".jsonl")) files.push(join(subagentRoot, f));
      }
    } catch {
      // No subagents spawned yet.
    }
    return files;
  }

  private scan(file: string): void {
    let tail = this.tails.get(file);
    if (!tail) {
      tail = {
        offset: 0,
        partial: Buffer.alloc(0),
        pending: new Map(),
        quickCalls: new Map(),
        lengthStops: 0,
      };
      this.tails.set(file, tail);
    }
    let chunk: Buffer;
    try {
      const st = statSync(file);
      this.lastActivityAt = Math.max(this.lastActivityAt, st.mtimeMs);
      if (st.size <= tail.offset) return;
      chunk = Buffer.alloc(st.size - tail.offset);
      const fd = openSync(file, "r");
      try {
        readSync(fd, chunk, 0, chunk.length, tail.offset);
      } finally {
        closeSync(fd);
      }
      tail.offset = st.size;
    } catch {
      return;
    }
    // Split on raw newline bytes so a multibyte character straddling a read is never decoded
    // in halves.
    const data = Buffer.concat([tail.partial, chunk]);
    const end = data.lastIndexOf(0x0a);
    tail.partial = data.subarray(end + 1);
    if (end < 0) return;
    for (const line of data.subarray(0, end).toString("utf8").split("\n")) {
      try {
        this.observe(file, tail, JSON.parse(line));
      } catch {
        // Malformed or unexpected line: skip it.
      }
    }
  }

  private observe(file: string, tail: TranscriptTail, entry: any): void {
    if (entry?.type !== "message") return;
    const msg = entry.message;
    const at = Date.parse(entry.timestamp);
    const content: any[] = Array.isArray(msg?.content) ? msg.content : [];
    const isParent = file === this.parentFile;
    if (msg?.role !== "assistant") {
      if (isParent) this.finalText = undefined;
      if (msg?.role !== "toolResult") return;
      const call = tail.pending.get(msg.toolCallId);
      tail.pending.delete(msg.toolCallId);
      if (!call || !(at - call.at <= LOOP_FAST_CALL_MS)) return;
      // Fingerprint the call together with what it returned: rerunning a typecheck after each
      // edit is the same call with a different result, and is work; a spinning model gets the
      // same answer back every time.
      const key = createHash("sha1")
        .update(`${call.key}\0${JSON.stringify(content)}`)
        .digest("hex");
      const times = (tail.quickCalls.get(key) ?? []).filter(
        (t) => at - t < LOOP_REPEAT_WINDOW_MS,
      );
      times.push(at);
      tail.quickCalls.set(key, times);
      if (times.length >= LOOP_REPEAT_LIMIT) {
        this.loop ??= {
          kind: "looping",
          detail: `the same ${call.name} call returned the same result ${times.length}× within ${formatDuration(LOOP_REPEAT_WINDOW_MS)} in ${basename(file)}`,
        };
      }
      return;
    }
    tail.lengthStops = msg.stopReason === "length" ? tail.lengthStops + 1 : 0;
    if (tail.lengthStops >= LOOP_LENGTH_STOP_LIMIT) {
      this.loop ??= {
        kind: "looping",
        detail: `${tail.lengthStops} consecutive responses cut off at the output token limit in ${basename(file)}`,
      };
    }
    for (const block of content) {
      // Intercom pings are status chatter, legitimately similar from one to the next.
      if (block?.type !== "toolCall" || block.name === "intercom") continue;
      const key = createHash("sha1")
        .update(`${block.name}\0${JSON.stringify(block.arguments)}`)
        .digest("hex");
      tail.pending.set(block.id, { key, name: block.name, at });
    }
    if (isParent) {
      this.finalText =
        msg.stopReason === "stop"
          ? content
              .filter((b) => b?.type === "text")
              .map((b) => b.text)
              .join("\n")
          : undefined;
    }
  }
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

/**
 * Which side of the `@agent`/`@human` ticket convention a listing should cover. Projects put
 * work that no agent can finish — plugging in a board, listening to a sound, deciding
 * something that belongs to the owner — under `@human`, with `HUMAN:`-prefixed acceptance
 * criteria an agent cannot satisfy by reading code. Nothing here used to read that label: the
 * choose step was handed `${id} - ${title}` alone, so a hardware-verification ticket looked
 * identical to any other and got queued, planned, executed, produced no commit (correctly — a
 * person was needed), tripped the no-commit guard, and was re-picked until the failure-streak
 * guard halted the whole run. Observed on TASK-004.
 */
type AssigneeFilter = "agent" | "human" | "all";

async function listUnblockedByStatus(
  pi: ExtensionAPI,
  cwd: string,
  status: string,
  assignee: AssigneeFilter = "agent",
): Promise<Ticket[]> {
  const { stdout } = await execCapture(
    pi,
    UNBLOCKED_TODO_SCRIPT,
    [status, "--assignee", assignee],
    {
      cwd,
      timeout: 30_000,
    },
  );
  return parseUnblockedList(stdout);
}

async function listUnblocked(pi: ExtensionAPI, cwd: string): Promise<Ticket[]> {
  return listUnblockedByStatus(pi, cwd, "To Do");
}

/** Unblocked `To Do` tickets sitting with a person. Read only when the agent pool has run dry,
 * so the run can say "nothing left for me, these N are yours" instead of the misleading "no
 * unblocked tickets remain" — those two states look the same from the outside and mean very
 * different things. */
async function listWaitingOnHuman(
  pi: ExtensionAPI,
  cwd: string,
): Promise<Ticket[]> {
  return listUnblockedByStatus(pi, cwd, "To Do", "human");
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
 *
 * Promotion is assignee-agnostic (`all`) on purpose: it is status bookkeeping, not work
 * selection. Filtering it would strand a `@human` ticket in "Blocked" forever, and every ticket
 * depending on it would silently look blocked forever too — the promotion exists precisely to
 * stop that class of quiet starvation.
 */
async function promoteUnblockedBlockedTickets(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  cwd: string,
  state: RalphState,
): Promise<Ticket[]> {
  setCurrentStep(
    ctx,
    state,
    "checking Blocked tickets for satisfied dependencies",
  );
  const promotable = await listUnblockedByStatus(pi, cwd, "Blocked", "all");
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

/** True if `ticketId` currently sits in `status` — a deterministic read of the
 * backlog, independent of what a worker subprocess claims or how it exited. */
async function isTicketInStatus(
  pi: ExtensionAPI,
  cwd: string,
  ticketId: string,
  status: string,
): Promise<boolean> {
  const { stdout } = await execCapture(
    pi,
    "backlog",
    ["task", "list", "-s", status, "--plain"],
    { cwd, timeout: 15_000 },
  );
  return parsePlainTaskList(stdout).some((t) => t.id === ticketId);
}

/** All known ticket IDs, across every status. Used to detect new tickets filed by a review
 * step via a before/after diff, rather than parsing the review agent's free-text summary. */
async function listAllTicketIds(
  pi: ExtensionAPI,
  cwd: string,
): Promise<Set<string>> {
  const { stdout } = await execCapture(
    pi,
    "backlog",
    ["task", "list", "--plain"],
    {
      cwd,
      timeout: 15_000,
    },
  );
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
 * Standing instructions appended to the long-running headless prompts (execute, research, plan,
 * review). Two jobs:
 *
 * Status pings via pi-intercom, so the person watching the orchestrating session can follow
 * along. Pair with `extensions: [PI_INTERCOM_EXTENSION]` on the same `runHeadless` call —
 * loading the extension without this guidance leaves the tool unused, and the guidance without
 * the extension names a tool that doesn't exist. Pings are courtesy only: liveness comes from
 * the worker's transcript (see TranscriptWatch), because ping discipline proved unreliable —
 * every recent "silent" kill under the old ping-based deadline was a live worker that had simply
 * stopped pinging (see WORKER_IDLE_LIMIT_MS).
 *
 * Foreground-command discipline, the one liveness rule the worker can still break: a command
 * blocking in the foreground writes nothing to the transcript until it returns, so a long
 * enough one is indistinguishable from a hang. The pgrep warning stays because it is a real
 * observed trap in the detach-and-poll pattern (confirmed live 2026-09-12: a worker polled a
 * finished suite with `pgrep -f "cargo test"` for roughly 25 minutes).
 */
function intercomStatusGuidance(mainSessionId: string): string {
  const idleMin = Math.round(WORKER_IDLE_LIMIT_MS / 60_000);
  const foregroundMin = Math.round(idleMin / 2);
  return dedent`
    Progress updates: send a one-line status ping to the orchestrating session via the intercom
    tool after each meaningfully distinct sub-step and right before any long-running operation
    (a full build, the test suite, an end-to-end check, a large refactor), so the person watching
    can follow along:
    intercom({ action: "send", to: "${mainSessionId}", message: "<one sentence: what you just
    finished or are about to run>" })
    Use \`send\`, never \`ask\` — nobody replies, nothing acknowledges it, and you never need to
    wait for or re-send anything. Don't ping between quick steps. Skip this entirely if the
    intercom tool isn't available.

    Long commands: you are watched through your own session transcript, and a step whose
    transcript records nothing for ${idleMin} minutes is treated as hung and stopped, discarding
    the work in flight. A command blocking in the foreground records nothing until it returns. So
    if one command may run longer than about ${foregroundMin} minutes, don't block on it: launch it
    detached and keep its pid (\`nohup <cmd> > /tmp/<name>.log 2>&1 & echo $!\`), then poll with
    a command that sleeps between 1 and 10 minutes before checking (\`sleep 300; kill -0 <pid>
    && tail -5 /tmp/<name>.log\`), or grep the log for its final summary line. Never wait on
    \`pgrep -f "<the command>"\`: \`-f\` matches whole command lines, so the polling shell
    matches itself and the loop never sees the run finish.
  `;
}


/**
 * Instructs a headless /backlog-planner run to set the `subagent` tool's `thinking` parameter to
 * "medium" on every subagent it spawns for codebase research (see PI_SUBAGENTS_EXTENSION above) —
 * otherwise those subagents inherit the parent call's own thinking level (xhigh, for the final
 * plan write) by default. Injected per-call from here rather than set in the backlog-planner skill
 * itself, since that skill is also invoked directly from interactive Claude Code, where its
 * subagents should keep Claude's own default thinking level instead of a pi-specific override.
 */
function subagentThinkingGuidance(level: "medium" | "xhigh"): string {
  return dedent`
    Subagent thinking level: for every subagent tool call you make to delegate codebase research,
    pass thinking: "${level}" as one of the call's parameters.
  `;
}

/**
 * Standing guidance nudging execute/plan workers toward pi-lens's structural tools instead of
 * blind whole-file `read` calls. Confirmed from session analysis (2026-09-02): reads with no
 * offset/limit against this repo's oversized files (lib.rs, interview.rs, meeting.rs, render.rs,
 * etc.) were the single largest source of tool-result bytes across a week of ralph runs, each
 * capped at pi's ~50KB read truncation and re-paid from zero by every fresh headless worker,
 * since headless sessions share no context with each other. `module_report` (always active, no
 * activation needed) returns a whole file's symbol table with exact line ranges in a fraction of
 * the bytes of one truncated read, and `ast_grep_search`/`lsp_navigation` (now statically active —
 * see the pi-lens tools.lazy: false home-manager config) locate a definition or its usages
 * directly. None of the three appeared meaningfully in a week of transcripts despite being
 * available, so the nudge is spelled out here rather than assumed.
 */
function largeFileGuidance(): string {
  return dedent`
    Large files: before running \`read\` on a file you haven't already seen in this session,
    consider whether you actually need the whole thing. For anything nontrivially sized, prefer:
      - \`module_report\` for "what's in this file and where" — it returns every symbol with exact
        line ranges for the whole file, cheaper than a full read and not subject to its truncation.
      - \`ast_grep_search\` or \`lsp_navigation\` (definition/references/documentSymbol) to jump
        straight to the function or symbol you need instead of reading the file top to bottom.
      - a targeted \`read\` with \`offset\`/\`limit\` once you know the line range you actually need.
    A blind \`read\` on a large file gets truncated (pi tells you how much was cut and how to
    continue) — if you do need the rest, follow up with \`offset\` rather than re-reading from the
    top or proceeding on a partial view.
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
 *
 * Re-confirmed live 2026-08-28 with the guidance in context: the orchestrator asked a
 * finished worker to resend its summary by intercom, then began reading the ticket's core
 * files "to verify the worker's findings" while waiting. Prose alone did not hold, which is
 * why the terminal-ping and no-pre-work rules below name those exact rationalisations, and
 * why the `context` handler additionally attaches a per-ping reminder (see PING_REMINDER)
 * at the moment the ping enters the LLM's context.
 *
 * Deterministic guard added the same day: pi-intercom's `inboundTrigger: "replies"` setting
 * (see file header) means routine pings no longer trigger an orchestrator turn at all —
 * they land in the transcript inertly and surface in context only on the next real turn.
 * The prose rules remain for that later turn (and for any session still running on the old
 * `always` default until restarted).
 *
 * The "only reply to correct a worker" exception originally lived as a clause inside the
 * intercom-pings bullet below, where it read as a footnote rather than the actual rule. Moved
 * to its own leading bullet (2026-09-24) so silence is the stated default and correction is the
 * named exception, not the other way around.
 */
const ORCHESTRATOR_ROLE_GUIDANCE = dedent`
  Ralph orchestrator role: an autonomous ralph backlog loop is currently running in this
  session. All real ticket work (research, planning, implementation, review) runs in separate
  headless worker sessions; their intercom messages (from sessions named \`subagent-chat-*\`)
  are progress reports about work those workers own end-to-end — NOT tasks assigned to you.
  - Default to silence: a worker's ping does not want or need a reply. Never intercom a worker
    back to acknowledge it, thank it, or ask it to resend something — a reply lands inside the
    worker's own context mid-task and interrupts it for nothing. The ONLY reason to message a
    worker is correction: it is duplicating another worker's ticket, working outside its
    assigned scope, or about to do something destructive. Status, findings, and "I'm done" all
    get relayed to the user — none of them get answered.
  - Do not perform the workers' work yourself: when a progress report names a ticket, do not
    start researching it, planning it, editing its code, or mutating its backlog record in this
    session. Parallel work duplicates effort and risks conflicting edits; each worker owns its
    ticket until its step finishes.
  - Your job is to orchestrate and report: track the loop with the ralph_status tool, relay
    worker progress to the user, and surface failures or stalls (loop history under
    ~/.pi/agent/ralph/<project>/history.jsonl; worker transcripts under ~/.pi/agent/sessions/).
  - Intercom pings are one-way by design — a worker sends them via \`send\`, never \`ask\`,
    delivery is guaranteed by the broker, and (with pi-intercom's inboundTrigger set to
    "replies") a routine ping doesn't even trigger a turn here: the user reads it live in the
    transcript. A ping saying a worker is done or "ready to return" its result still ends the
    conversation rather than starting one — the step's deliverable comes back through the
    loop's captured output and history.jsonl, not intercom. Never ask a worker to send or
    resend its results by intercom.
  - Waiting for a worker's deliverable is not a reason to pre-work the ticket. Do not open,
    read, or "verify" the ticket's source files, tests, or backlog record "while waiting" or
    "to check the worker's findings" — that is performing the worker's work under a different
    name. If you catch yourself about to open a file a worker just reported on, stop: your
    moves are ralph_status, relaying to the user, and (rarely) correcting a worker that is
    actually going wrong.
  - Explicit user instructions always override this framing: if the user directly asks you to
    do something, follow them even if it touches a ralph-managed ticket.
`;

/**
 * One-line reminder attached to a worker's progress ping for the first LLM call that includes
 * it. The standing guidance above sits at the top of the system prompt, but the drift moment
 * is the first turn after the ping lands in context — and that is exactly the turn where the
 * model rationalises around the standing rule ("I'm only verifying", "the worker is asking
 * for a fetch").
 * Confirmed live twice with the standing guidance in context (2026-08-19, 2026-08-28), so
 * the rule also lands beside the ping itself, where the decision is made.
 *
 * Pings reach the LLM as user messages rendered from pi-intercom's `intercom_message`
 * custom entries (header "**From subagent-chat-<id>** ..."), so the `context` event sees
 * them. Each ping's body carries a unique `_id <uuid>` line, which keys the once-only
 * annotation: the reminder rides the decision turn and does not linger in every later
 * context. Pings older than PING_REMINDER_MAX_AGE_MS are left alone, so a resumed session
 * does not re-annotate history.
 */
const PING_REMINDER =
  "[ralph] One-way progress report from a ralph worker; the user already sees it in the " +
  "transcript. Do not research, plan, edit, or mutate anything for the named ticket in this " +
  "session. Default to silence — do not message the worker back unless it is genuinely going " +
  "wrong (duplicating work, off scope, destructive) and needs correcting; its deliverable " +
  "otherwise arrives through the loop's captured output, not a reply.";
const PING_HEADER_PATTERN = /From subagent-chat-[0-9a-f]{8}-[0-9a-f]{4}/;
const PING_ID_PATTERN =
  /_id ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/;
const PING_INJECTED_PATTERN = /injected (\d{4}-\d{2}-\d{2}T[\d:.]+Z)/;
/** Pings older than this are history, not a fresh nudge — don't annotate them. */
const PING_REMINDER_MAX_AGE_MS = 15 * 60 * 1000;

/** The text of a user message, whatever shape its content takes, or null if not one. */
function userMessageText(message: unknown): string | null {
  const m = message as { role?: unknown; content?: unknown } | null;
  if (!m || m.role !== "user") return null;
  if (typeof m.content === "string") return m.content;
  if (Array.isArray(m.content)) {
    return m.content
      .map((block) =>
        typeof block === "object" &&
        block !== null &&
        typeof (block as { text?: unknown }).text === "string"
          ? (block as { text: string }).text
          : "",
      )
      .join("");
  }
  return null;
}

async function runHeadless(
  pi: ExtensionAPI,
  cwd: string,
  prompt: string,
  opts: {
    /** The loop's state: receives this worker's session id and live transcript activity for
     * the widget and `/ralph-log`. */
    state: RalphState;
    /** Hard wall-clock cap. Defaults to WORKER_CEILING_MS; only triage and choose pass a
     * shorter one. Liveness and looping are judged by TranscriptWatch regardless. */
    timeout?: number;
    model?: string;
    thinking?: "medium" | "xhigh";
    extensions?: string[];
    noSkills?: boolean;
  },
): Promise<{
  ok: boolean;
  killed: boolean;
  output: string;
  failure?: FailureClass;
  /** Set when TranscriptWatch stopped the worker — including a "finished" reap, which is ok. */
  verdict?: WatchVerdict;
  /** This call's pi session id. Every headless call gets one, so every step is viewable via
   * `/ralph-log` — see `sessionDirFor`. */
  sessionId: string;
}> {
  // No --no-session: pi-intercom needs the headless worker to have a live session identity
  // to address progress pings back to the orchestrator from, and TranscriptWatch reads the
  // session file. Explicit --session-id/--session-dir instead of pi's defaults, so this exact
  // run's transcript is locatable by id alone — see sessionDirFor.
  const sessionId = randomUUID();
  const args = [
    "-p",
    "--no-extensions",
    "--session-id",
    sessionId,
    "--session-dir",
    sessionDirFor(cwd),
  ];
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
  if (opts.thinking) args.push("--thinking", opts.thinking);
  args.push(prompt);

  const watch = new TranscriptWatch(sessionDirFor(cwd), sessionId);
  opts.state.currentStepSessionId = sessionId;
  opts.state.currentStepLastActivityAt = watch.lastActivityAt;
  const result = await execCapture(pi, "pi", args, {
    cwd,
    timeout: opts.timeout ?? WORKER_CEILING_MS,
    watch: () => {
      const verdict = watch.check();
      opts.state.currentStepLastActivityAt = watch.lastActivityAt;
      return verdict;
    },
  });
  // A reaped post-response hang may never have flushed stdout; the transcript has the answer.
  const stdout =
    result.stdout ||
    (result.verdict?.kind === "finished" ? (watch.finalText ?? "") : "");
  return {
    ok: result.ok,
    killed: result.killed,
    output: (stdout || result.stderr || "").trim(),
    failure: result.failure,
    verdict: result.verdict,
    sessionId,
  };
}

/** Prefixes a summary with why the subprocess was stopped, so history.jsonl (see stateDirFor)
 * tells a transcript-quiet kill, a loop kill, and the fixed budget apart. A worker reaped after
 * its final response is a success and says so as a suffix instead. */
function summarize(
  result: { killed: boolean; output: string; verdict?: WatchVerdict },
  maxLen?: number,
): string {
  const verdict = result.verdict;
  const prefix =
    verdict && verdict.kind !== "finished"
      ? `[killed, ${verdict.kind}: ${verdict.detail}] `
      : result.killed
        ? "[timed out] "
        : "";
  const suffix =
    verdict?.kind === "finished" ? ` [reaped: ${verdict.detail}]` : "";
  return prefix + tailSummary(result.output, maxLen) + suffix;
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
  state.currentStepLastActivityAt = undefined;
  state.currentStepSessionId = undefined;
  renderWidget(ctx, state);
}

/** `git rev-parse HEAD`, or null if the command itself failed (not "no commits yet" — this
 * repo always has history; a null here means something is wrong with git itself). */
async function currentHeadSha(
  pi: ExtensionAPI,
  cwd: string,
): Promise<string | null> {
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
  if (!runStartSha)
    return { ok: true, summary: "skipped (no run-start SHA recorded)" };

  const { stdout: log } = await execCapture(
    pi,
    "git",
    ["log", "--oneline", `${runStartSha}..HEAD`],
    { cwd, timeout: 15_000 },
  );
  if (!/\bfixup! /.test(log)) return { ok: true, summary: "no pending fixups" };

  // --autostash is not optional here. A review run leaves the worktree dirty whenever an
  // unrelated change is sitting unstaged (a stray deleted file is enough), and plain
  // `git rebase` refuses outright in that state — "cannot rebase: You have unstaged
  // changes" — before ever looking at the fixup. Confirmed live on TASK-62: the squash
  // step reported "failed, likely a conflict" for what was purely a dirty tree, so the
  // fixup had to be folded by hand. Autostash makes an unrelated dirty worktree irrelevant;
  // a genuine conflict still fails, and the abort below restores the stash.
  const rebase = await execCapture(
    pi,
    "git",
    [
      "-c",
      "sequence.editor=true",
      "rebase",
      "--autosquash",
      "--autostash",
      "-i",
      runStartSha,
    ],
    { cwd, timeout: 60_000 },
  );
  if (rebase.ok)
    return {
      ok: true,
      summary: "folded pending fixup commit(s) into their targets",
    };

  await execCapture(pi, "git", ["rebase", "--abort"], { cwd, timeout: 15_000 });
  return {
    ok: false,
    summary: `autosquash failed — aborted; fixup commit(s) left unsquashed: ${tailSummary(rebase.stderr || rebase.stdout, 200)}`,
  };
}

/**
 * Paths the working tree holds uncommitted, measured before dispatching an execute worker.
 * Returns [] when the repo is clean or git can't be consulted; callers only act on non-empty.
 */
async function dirtyPaths(pi: ExtensionAPI, cwd: string): Promise<string[]> {
  const { ok, stdout } = await execCapture(
    pi,
    "git",
    ["status", "--porcelain"],
    { cwd, timeout: 10_000 },
  );
  if (!ok) return [];
  return stdout
    .split("\n")
    .filter((line) => line.trim() !== "")
    .map((line) => line.slice(3));
}

/**
 * Tells an execute worker that the tree it is inheriting is not clean.
 *
 * A killed worker leaves its ticket In Progress and assigned, which is exactly what the loop reads
 * as work to run, so the next dispatch lands on the same ticket with the dead run's edits still on
 * disk and no memory of them. Confirmed live 2026-09-12 on TASK-2.15: three sessions were pointed
 * at it in a row, each surveying from scratch against a tree that already held its predecessor's
 * new crate, and none was told the tree was dirty. The existing HEAD-didn't-move guard catches the
 * resulting pretence of success after the fact; this says so up front, so continuing prior work is
 * a choice the worker makes knowingly rather than something it stumbles into or quietly undoes.
 */
function dirtyTreeGuidance(paths: string[]): string {
  const shown = paths.slice(0, 15);
  const rest = paths.length - shown.length;
  return dedent`
    Uncommitted work predating this run: \`git status\` shows ${paths.length} dirty path(s) -
    ${shown.join(", ")}${rest > 0 ? `, plus ${rest} more` : ""}. This ticket was already In Progress,
    so those edits are most likely a previous attempt at it that was killed mid-run. A headless retry
    shares no context with the run that died, so look before you write: read the diff, then decide
    knowingly whether to continue that work or discard it, and say which in your first intercom ping.
    Never silently revert, stash, clean or reset it. Discarding is allowed, but only as a decision you
    state out loud, because those edits may be the only copy of that design work. If they turn out to
    be complete and green, land them (commit with the ticket's Task-Id trailer) instead of redoing
    them.
  `;
}

/**
 * Tells a worker that its own account of what it has done is not evidence about the repo,
 * and gives it the three cheap reads that are.
 *
 * Confirmed on 2026-09-16 across one ralph cycle: five separate sessions were pointed at
 * TASK-2.15.3 and TASK-2.15.3.1, both of which had already shipped (`ecffcf1`, `6d00cad`,
 * `1c70c6c`). None of them was sloppy. Each had been through context compaction mid-ticket,
 * and a summary carries forward what the session intended while going quiet about what it
 * finished, so each one opened a Done ticket, read a plan that described merged work as
 * pending, and set out to build it again. Two of them reported landing commits whose hashes
 * existed in no repository - `5a61ff3` and `976f8d4` were values recited from their own
 * pre-compaction notes. The work they "did" was the work already on disk, which they then
 * described as their own.
 *
 * The failure is not reasoning quality but reference point: every finding those sessions
 * produced was true of the commit they had read and false of the one they were standing on.
 * A research session pinned at `0bd0019` reported four open contract gaps that later commits
 * had closed, citing prior art in detail. So the fix is to make the repo, not the transcript,
 * the thing a worker quotes: pin the SHA it reads, look for the deliverable before building
 * it, and re-establish its own progress from git after any compaction.
 */
function stateVerificationGuidance(
  ticketId: string,
  headSha: string | null,
  audience: "execute" | "plan",
): string {
  const shipped =
    audience === "execute"
      ? dedent`
        do NOT re-implement it and do not write a competing version into the same files - two
        implementations of one decision is worse than either alone, and whichever the tests fail to
        pin loses silently. Instead confirm the shipped code actually meets each acceptance
        criterion, tick the criteria it meets, mark the ticket Done, and commit the ticket file alone
        with the required trailers. Name the commit that shipped it in your summary. If only part of
        it shipped, build exactly the remainder and say which part was already there.
      `
      : dedent`
        do NOT write an implementation plan for it. A plan describing merged work as pending is the
        artifact that misled five sessions on 2026-09-16: once committed it reads as a queue entry
        forever, and it kept pointing fresh runs at finished tickets. Close the record yourself:
        check every acceptance criterion the shipped code meets, run
        \`backlog task edit ${ticketId} --final-summary "SHIPPED by <full sha> - <what shipped where>"\`,
        then \`backlog task edit ${ticketId} -s Done\`. End your run reporting ALREADY_SHIPPED with
        the SHA. Closing the record IS the deliverable here: while the ticket sits in Needs Plan the
        loop re-plans it every pass, and 60+ passes on one already-shipped ticket burned two full
        runs on 2026-10-03 because this verdict left no state change behind.
      `;
  return dedent`
    Verify state from git before believing anything about your own progress, including this prompt.

    HEAD is ${headSha ?? "unknown"} right now. Record that value. Every other agent
    working here shares this checkout and main moves underneath you, so before you quote any source
    file, and again before you report results, run \`git rev-parse HEAD\`. If it changed
    mid-task, re-read whatever you meant to cite - a finding about a file you read three commits
    ago is not a finding about that file.

    Then check whether ${ticketId}'s deliverable already exists before building it:

      git log --oneline -20
      git log --grep="${ticketId}" --oneline
      grep -rn "<the specific symbols/files/routes the ticket names>" crates/

    Search for the artifacts, not just the ticket ID: much of this project's work landed under
    descriptive subject lines with the ID only in a trailer. If the deliverable is already in HEAD,
    ${shipped}

    After a context compaction, none of the above is optional. A summary saying you are "about to
    implement X" is a statement about intent, not about the tree; several sessions today re-ran a
    completed plan for precisely that reason. Re-run \`git log --oneline -8\`, \`git status
    --porcelain\` and \`backlog task ${ticketId} --plain\` and believe those over the summary.
  `;
}

/**
 * Forbids restoring tracked files as a cleanup step, because cleanup in a shared checkout is not
 * a private act.
 *
 * Observed the same day: a research session announced it would temporarily edit
 * `crates/server/src/live.rs` - the file four other sessions were in and out of that afternoon -
 * and "leave the tree clean" with \`git checkout --\` afterward. On a file another session holds
 * uncommitted edits in, that command destroys their work with no conflict marker, no record in
 * the reflog, and nothing in the perpetrator's summary suggesting it happened. It also proposed
 * it in good faith, as tidiness.
 *
 * Complements dirtyTreeGuidance rather than repeating it: that block governs work inheriting a
 * dirty tree, this one governs the scratch files a run creates for itself. Deleting a file you
 * created cannot harm anybody, which makes an untracked probe strictly better than a temporary
 * edit to something tracked.
 */
function sharedCheckoutGuidance(): string {
  return dedent`
    Other agents work in this exact checkout, so treat tracked files as shared.

    Never undo someone else's work to tidy up. Do not run \`git checkout -- <path>\`,
    \`git restore\`, \`git stash\`, or \`git reset --hard\` on a tracked file to clean up after an
    experiment, and do not delete a tracked file you did not create. Those commands discard any
    uncommitted edit another session is holding in that file, silently and unrecoverably.

    Run throwaway probes in files you created and nobody else can be editing - an untracked
    \`crates/<crate>/tests/probe_*.rs\`, a scratch file outside the repo - and clean up by deleting
    your own file. Check \`git status --porcelain\` before and after any experiment anyway, and if a
    path you touched shows up modified in a way you did not cause, stop and report it rather than
    reverting it.
  `;
}

/**
 * Tells every worker that its own transcript is not part of the branch, and makes the ticket's
 * Implementation Notes the one place cross-attempt findings can survive.
 *
 * `dirtyTreeGuidance` covers half of inheriting a dead run: it names uncommitted *files*. It is
 * blind to the other half — the analysis a run produces without editing anything. Confirmed live
 * 2026-10-03 on TASK-46.1: the deliverable was a Rust gate whose cost was almost entirely a
 * ~70-line ground-trace survey (every CSS class mapped to the surface it actually paints on).
 * Attempt one produced the complete survey and quoted it in its final message; the harness saw
 * HEAD unmoved, scored it "uncommitted success", and killed it. Attempts two and three each
 * rebuilt the identical survey from source, because the survey existed only inside a transcript
 * neither of them reads — headless workers share no context by design, and the tree was clean,
 * so `dirtyTreeGuidance` never fired. Three workers, one artifact, zero commits.
 *
 * The fix has to route through something the next worker is already told to read, and the only
 * such place outside the repo is the ticket itself: `stateVerificationGuidance` makes every
 * worker run `backlog task <id> --plain`, and that output includes Implementation Notes. So
 * findings go there, bidirectionally — inherit them, leave them.
 */
function handoffGuidance(ticketId: string): string {
  return dedent`
    Your transcript is not part of the branch. A later attempt at this ticket starts from zero
    context: it reads the ticket, the repo, and nothing else. Everything you derive that never
    reaches a file - a survey, a computed table, the approaches you ruled out and why - dies with
    your turn. Two rules:
      - Inherit: the \`backlog task ${ticketId} --plain\` output has an "Implementation Notes"
        section. Lines starting HANDOFF were left by earlier attempts at this ticket. Trust them
        over a fresh re-derivation - they are a dead run's finished findings, cheaper than
        rebuilding them and usually more honest about what was already checked.
      - Leave: the moment a hard-won finding exists, append it - do not wait until you finish:
        \`backlog task edit ${ticketId} --append-notes "HANDOFF: <the finding>"\`
        You may be killed between producing a survey and committing it; a killed run's unwritten
        analysis is paid for twice. An appended note costs nothing if you land the work anyway,
        because the ticket file gets committed with it.
  `;
}

/**
 * Deterministic backstop for the same failure: when an execute attempt ends without a commit,
 * the harness itself appends a HANDOFF pointer to the ticket, naming the dead session's
 * transcript and the uncommitted paths it left behind.
 *
 * The prose above asks a worker to bank its own findings; a killed or hung worker is exactly the
 * one that cannot. This note does not carry the findings - the harness has no view into them - it
 * guarantees the next attempt knows a predecessor existed, where its full turn-by-turn transcript
 * lives, and which files on disk came from it instead of from the clean HEAD. Cheap, fail-open,
 * and independent of worker cooperation.
 */
async function appendFailureHandoff(
  pi: ExtensionAPI,
  cwd: string,
  ticketId: string,
  cause: string,
  sessionId: string,
  shaBefore: string | null,
  preExistingDirty: string[],
): Promise<void> {
  const transcript = await resolveSessionFile(cwd, sessionId);
  // What this attempt added to the tree, as opposed to what it inherited (which
  // dirtyTreeGuidance already named for it, and which belongs to some older run).
  const after = await dirtyPaths(pi, cwd);
  const inherited = new Set(preExistingDirty);
  const added = after.filter((path) => !inherited.has(path));
  const shown = added.slice(0, 15);
  const rest = added.length - shown.length;
  const note = dedent`
    HANDOFF (written by the ralph harness, not a worker): the previous attempt at this ticket
    ended ${cause} with no commit (HEAD stayed ${shaBefore?.slice(0, 8) ?? "unknown"}). Its full
    transcript — every survey it ran, every number it computed, what it ruled out — is readable
    at ${transcript ?? `(session file for ${sessionId} not found)`}.
    ${
      shown.length > 0
        ? `Uncommitted files on disk from that attempt: ${shown.join(", ")}${rest > 0 ? `, plus ${rest} more` : ""}. Read them before writing anything; land them if they are complete.`
        : `It left no uncommitted files of its own, so any work it finished exists only in the transcript above.`
    }
  `;
  await execCapture(
    pi,
    "backlog",
    ["task", "edit", ticketId, "--append-notes", note],
    { cwd, timeout: 15_000 },
  );
}

async function doExecute(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  cwd: string,
  state: RalphState,
  ticket: Ticket,
): Promise<boolean> {
  setCurrentStep(ctx, state, `executing ${ticket.id}`, WORKER_CEILING_MS);
  // Fail-open re-check against the backlog itself. Choose listed this ticket from a status query,
  // so it was startable moments ago; if it now reads Done, some other session closed it while this
  // step was queued, and handing it to a worker would restart finished work - which is what happened
  // five times over on TASK-2.15.3 on 2026-09-16. Only a positive Done reading skips, so a failed or
  // empty backlog read cannot strand the loop by pretending every ticket is complete.
  if (await isTicketInStatus(pi, cwd, ticket.id, "Done")) {
    await recordHistory(cwd, state, {
      kind: "execute",
      ticket: ticket.id,
      outcome: "ok",
      summary: "skipped - ticket already Done before dispatch, not re-executed",
    });
    return true;
  }
  const shaBefore = await currentHeadSha(pi, cwd);
  // Screenshot-cap guard: without the subagent tool, visual verification reads every
  // rendered screenshot into the executor's own context and dies at 5 images (vLLM
  // 4-image cap) — confirmed killer of TASK-55/57 runs. When the extension can't be
  // found (package moved/removed), degrade gracefully with an explicit fallback
  // instruction rather than silently losing the capability.
  const hasSubagents = existsSync(PI_SUBAGENTS_EXTENSION);
  // Measured before the worker touches anything, so a dirty tree can be named in its prompt.
  const dirty = await dirtyPaths(pi, cwd);
  const screenshotGuidance = hasSubagents
    ? dedent`
        Widget visual verification: never read more than 4 screenshots into your own session (the model provider rejects prompts with >4 images). Delegate screenshot review to subagent calls — one subagent per batch of <=4 images, each reporting findings back as text.
      `
    : dedent`
        Widget visual verification: the subagent tool is NOT available in this session. Never read more than 4 screenshots into your own context (the model provider rejects prompts with >4 images). Instead verify each batch of <=4 screenshots with a separate headless \`pi -p\` call that instructs the fresh process to read the image files with the read tool and report findings as text — each call starts from a clean context, so the 4-image cap is never exceeded.
      `;
  const promptBlocks = [
    `/backlog-execute ${ticket.id}`,
    screenshotGuidance,
    largeFileGuidance(),
    stateVerificationGuidance(ticket.id, shaBefore, "execute"),
    handoffGuidance(ticket.id),
    sharedCheckoutGuidance(),
    dirty.length > 0 ? dirtyTreeGuidance(dirty) : "",
    intercomStatusGuidance(state.mainSessionId),
  ].filter((block) => block.trim() !== "");
  const result = await runHeadless(pi, cwd, promptBlocks.join("\n\n"), {
    model: "coding",
    thinking: "medium",
    state,
    extensions: [
      PI_INTERCOM_EXTENSION,
      THINKING_ROUTER_EXTENSION,
      ...(hasSubagents ? [PI_SUBAGENTS_EXTENSION] : []),
    ],
  });

  // A subprocess reporting success — even a Final Summary claiming every AC is met — isn't
  // proof anything actually landed. Confirmed live: a first attempt hit its execute timeout and
  // got killed mid-flight; the retry was a fresh subprocess with no memory of that, found the
  // half-finished files already on disk, treated them as "prior work" to build on, and wrote a
  // complete implementation summary with every AC checked off — without the run ever reaching
  // a commit. HEAD not moving is unambiguous, so a "successful" run that leaves it where it
  // started is treated as a failure here regardless of what the subprocess claimed.
  const shaAfter = result.ok ? await currentHeadSha(pi, cwd) : shaBefore;
  const committed =
    shaBefore !== null && shaAfter !== null && shaBefore !== shaAfter;
  const ok = result.ok && committed;

  if (!ok && shaBefore !== null) {
    // Fail-open: a handoff note that cannot be appended must not turn a failed execute into an
    // erroring step — the next attempt simply loses the pointer, which is today's status quo.
    await appendFailureHandoff(
      pi,
      cwd,
      ticket.id,
      result.failure === "silent" || result.failure === "looping"
        ? `killed by the liveness watch (${result.verdict?.detail ?? result.failure})`
        : result.killed
          ? "cut at the step's hard time limit"
          : result.ok
          ? "finished talking without committing"
          : "exited unsuccessfully",
      result.sessionId,
      shaBefore,
      dirty,
    );
  }

  if (ok) state.executedSinceReview += 1;
  await recordHistory(cwd, state, {
    kind: "execute",
    ticket: ticket.id,
    outcome: ok ? "ok" : "failed",
    failure: ok ? undefined : (result.failure ?? "no-commit"),
    summary:
      result.ok && !committed
        ? `claimed success but no commit landed (HEAD still ${shaBefore?.slice(0, 8) ?? "unknown"}) — ${summarize(result)}`
        : summarize(result),
    sessionId: result.sessionId,
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
    state,
    timeout: TRIAGE_TIMEOUT_MS,
    model: "chat-fast",
    thinking: "medium",
    noSkills: true,
  });
  const verdict = extractMarkerLine(result.output, ["TRIVIAL", "NORMAL"]);
  await recordHistory(cwd, state, {
    kind: "plan",
    ticket: ticket.id,
    outcome: result.ok ? "ok" : "failed",
    failure: result.failure,
    summary: `triage: ${verdict ?? summarize(result, 80)}`,
    sessionId: result.sessionId,
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
    const researchSha = await currentHeadSha(pi, cwd);
    const researchPrompt = dedent`
      Research context to inform planning ticket ${ticket.id} ("${ticket.title}") in this repo.
      Run \`backlog task ${ticket.id} --plain\` first to see the full ticket, then search the web for
      relevant prior art, library documentation, or best practices that would help write a thorough
      implementation plan. Return a concise research summary (bullet points), not a plan.

      ${stateVerificationGuidance(ticket.id, researchSha, "plan")}

      ${intercomStatusGuidance(state.mainSessionId)}
    `;
    const research = await runHeadless(pi, cwd, researchPrompt, {
      state,
      timeout: RESEARCH_TIMEOUT_MS,
      model: "research",
      thinking: "medium",
      extensions: [PI_WEB_ACCESS_EXTENSION, PI_INTERCOM_EXTENSION, THINKING_ROUTER_EXTENSION],
    });
    await recordHistory(cwd, state, {
      kind: "plan",
      ticket: ticket.id,
      outcome: research.ok ? "ok" : "failed",
      failure: research.failure,
      summary: `research: ${summarize(research, 120)}`,
      sessionId: research.sessionId,
    });
    researchOutput = research.output;
    state.planCache = {
      ticketId: ticket.id,
      triage: "NORMAL",
      researchOutput,
    };
  }

  setCurrentStep(ctx, state, `planning ${ticket.id}`, WORKER_CEILING_MS);
  const planSha = await currentHeadSha(pi, cwd);
  const planPrompt = dedent`
    /backlog-planner ${ticket.id}

    ${stateVerificationGuidance(ticket.id, planSha, "plan")}

    ${handoffGuidance(ticket.id)}

    Research gathered before planning (best-effort — the research step may have been cut short by a
    timeout partway through, or its output may just be an unrelated startup warning with no real
    content; use it if it's useful, ignore it and rely on repo context otherwise):
    ${researchOutput.trim() || "(no output was produced)"}

    After planning completes (the ticket has a plan and, if applicable, is labeled planned), set its
    status to Dev Ready: \`backlog task edit ${ticket.id} -s "Dev Ready"\`. If /backlog-planner instead
    exited early because it found unplanned child tickets, leave the status as-is and explain why in
    your final message.

    Assignment — when a step needs a person: work here is done by an agent unless it genuinely
    cannot be — it needs the physical device, ears to judge what something sounds like, a real
    instrument, or a decision that belongs to the project owner. When planning surfaces such a
    step, split it into its own sub-task rather than leaving it inside an agent-owned ticket, and
    assign only that sub-task: \`backlog task create ... -a "@human"\` (or \`-a "@human"\` on edit),
    prefixing each of its acceptance criteria with \`HUMAN:\`. Keep everything else \`@agent\`.
    Both directions matter. A criterion left \`@agent\` that actually needs hands cannot be
    satisfied by reading code or watching a build succeed — the executor can only report that a
    person is required, which lands as a failed step and stalls the loop on the one ticket it was
    meant to move past. And reassigning a whole parent to \`@human\` because a single child needs
    hands is over-applying the label: a parent already inherits the strictest assignee among its
    children, so it stays unclosable until that child ships either way, while marking the parent
    itself \`@human\` additionally hides all of its remaining agent work from the loop.

    ${subagentThinkingGuidance("medium")}

    ${largeFileGuidance()}

    ${intercomStatusGuidance(state.mainSessionId)}
  `;
  const plan = await runHeadless(pi, cwd, planPrompt, {
    state,
    model: "planning",
    thinking: "xhigh",
    extensions: [PI_INTERCOM_EXTENSION, THINKING_ROUTER_EXTENSION, PI_SUBAGENTS_EXTENSION],
  });

  // The known post-response hang (see file header) means a run whose work fully landed can
  // still be killed at the deadline with result.ok false. The ticket's own status is
  // unambiguous external state — the same "don't trust the subprocess claim" check doExecute
  // does against HEAD — so a killed run that left the ticket Dev Ready counts as success.
  // A legitimate early exit for unplanned children leaves the status as-is and stays a failure.
  // An ALREADY_SHIPPED plan run closes the ticket itself (see stateVerificationGuidance), and
  // closing means Done - never Dev Ready, which would hand a shipped ticket to an execute step.
  // Done also satisfies the verify-after-plan status check below, since Done is terminal.
  const shippedInstead =
    plan.output.includes("ALREADY_SHIPPED") &&
    (await isTicketInStatus(pi, cwd, ticket.id, "Done"));
  const verified =
    !plan.ok &&
    ((await isTicketInStatus(pi, cwd, ticket.id, "Dev Ready")) || shippedInstead);
  const ok = plan.ok || verified;
  await recordHistory(cwd, state, {
    kind: "plan",
    ticket: ticket.id,
    outcome: ok ? "ok" : "failed",
    failure: ok ? undefined : plan.failure,
    summary:
      (verified
        ? `verified ${shippedInstead ? "Done (ALREADY_SHIPPED)" : "Dev Ready"} on disk despite subprocess ${plan.killed ? "timeout" : "failure"} — `
        : "") + summarize(plan),
    sessionId: plan.sessionId,
  });
  if (ok) state.planCache = undefined;
  return ok;
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
    state,
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
    failure: ok ? undefined : result.failure,
    summary,
    sessionId: result.sessionId,
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
    WORKER_CEILING_MS,
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
    3. Wait for that pane's agent to finish with blocking \`herdr agent wait\` calls — do NOT poll
       \`herdr pane list\` in a sleep loop, that wastes your own turns waiting on a subagent that
       hasn't moved. This pane was split with \`--no-focus\` and nothing ever focuses it, so per
       herdr's own state model it can only ever settle at \`done\` (idle work nobody's looked at
       yet), never \`idle\` (which additionally requires the tab to have been seen in the focused
       UI) — waiting on \`--until idle\` alone would block for the full timeout every time even
       though the agent finished. Accept either:
       \`herdr agent wait <new-pane-id> --until idle --until done --timeout ${REVIEW_WAIT_CHUNK_MIN * 60_000}\`
       (timeout is in milliseconds — ${REVIEW_WAIT_CHUNK_MIN} minutes). A nonzero exit means that wait
       timed out with the agent still working: run the same wait again. Wait in these
       ${REVIEW_WAIT_CHUNK_MIN}-minute calls rather than one long one, since a step that records
       nothing for ${Math.round(WORKER_IDLE_LIMIT_MS / 60_000)} minutes is treated as hung. Give up
       after ${REVIEW_WAIT_MIN} minutes of waiting in total; treat that the same as a failed review
       and continue to steps 4-5 anyway.
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
    state,
    noSkills: true,
    model: "orchestrator",
    thinking: "medium",
    extensions: [PI_INTERCOM_EXTENSION, THINKING_ROUTER_EXTENSION],
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
    if (closed.ok)
      cleanupNote = ` [cleanup: pane ${paneId} was still open, closed it]`;
  }

  const ticketsAfter = await listAllTicketIds(pi, cwd);
  const createdTickets = [...ticketsAfter].filter(
    (id) => !ticketsBefore.has(id),
  );

  await recordHistory(cwd, state, {
    kind: "review",
    outcome: result.ok ? "ok" : "failed",
    failure: result.failure,
    summary: summarize(result, 300) + cleanupNote,
    createdTickets: createdTickets.length ? createdTickets : undefined,
    sessionId: result.sessionId,
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
  state.currentStepLastActivityAt = undefined;
  state.currentStepSessionId = undefined;
}

/** What each observed FailureClass is worth telling the person who has to restart the loop:
 * a plain-language label plus the fix that class actually calls for. Wording matters here —
 * the old text asserted "a hung subprocess or broken tool" for every streak and sent people
 * hunting for a hang that was never there (see MAX_CONSECUTIVE_FAILURES). */
const FAILURE_CLASS_TEXT: Record<
  FailureClass,
  { label: string; advice: string }
> = {
  silent: {
    label: "stalled worker (nothing in its transcript tree changed for the idle limit)",
    advice:
      "No new transcript entry from the worker or any of its subagents in that window means the " +
      "process, the model stream, or a single endless generation stalled. The other usual cause is a " +
      "worker blocking on one foreground command longer than the idle limit. Open the worker's " +
      "transcript with /ralph-log and read its last entry: a bash call with no result points at the " +
      "command; an assistant turn with no follow-up points at the model or its server.",
  },
  looping: {
    label: "looping worker (repeated identical tool calls, or repeated token-limit cutoffs)",
    advice:
      "The worker kept producing output without converging. Read the end of its transcript with " +
      "/ralph-log for what it was repeating. A ticket that loops twice usually needs a smaller scope or a " +
      "clearer plan; one model looping where another doesn't may mean the loop thresholds need retuning.",
  },
  wedged: {
    label: "wedged subprocess (pi.exec never returned even after abort)",
    advice:
      "This one really is systemic: the subprocess may still be running orphaned. Check \"ps\" for " +
      "leftover \"pi -p\" processes and kill them, then find the command that does not return before " +
      "restarting.",
  },
  timeout: {
    label: "fixed-budget timeout",
    advice:
      "The worker stayed active, without tripping a loop detector, until the step's hard budget ran " +
      "out. For execute or plan that is WORKER_CEILING_MS, which is far beyond any healthy run seen, " +
      "so check its transcript for slow, subtle churn and consider splitting the ticket.",
  },
  exit: {
    label: "nonzero exit",
    advice:
      "The step ran to completion and failed on its own terms — read its summary in history.jsonl; no " +
      "timeout was involved.",
  },
  "no-commit": {
    label: "uncommitted success (reported done, moved no commit)",
    advice:
      "The worker finished talking with HEAD where it started, so its work sits uncommitted on disk " +
      "and the next attempt will inherit it as half-finished prior work. Check \"git status\"/\"git stash\" " +
      "before restarting.",
  },
};

/** The failure classes recorded for the streak behind `key` ("execute:<id>", "plan:<id>",
 * "review", "choose"), oldest first. Walks back from the newest history entry and stops at the
 * first one that is not a matching failure, so an older failure of the same kind separated by a
 * success is not counted into a message about the current streak. Entries with no recorded class
 * are reported as such rather than guessed at. */
function streakFailureClasses(
  state: RalphState,
  key: string,
): (FailureClass | "unrecorded")[] {
  const [kind, ticket] = key.split(":");
  const classes: (FailureClass | "unrecorded")[] = [];
  for (let i = state.history.length - 1; i >= 0; i--) {
    const h = state.history[i];
    if (
      h.outcome !== "failed" ||
      h.kind !== kind ||
      (ticket !== undefined && h.ticket !== ticket)
    ) {
      break;
    }
    classes.unshift(h.failure ?? "unrecorded");
    if (classes.length >= MAX_CONSECUTIVE_FAILURES) break;
  }
  return classes;
}

/** Turns the observed classes into the cause sentence of a stop reason. Phrasing is deliberately
 * count- and article-neutral ("observed cause:") — the cap is a constant, and labels that read as
 * noun phrases or clauses both have to fit. One shared class gets that class's advice; mixed
 * classes get each label and a note that they need different fixes. */
function describeFailureStreak(classes: (FailureClass | "unrecorded")[]): string {
  const text = (c: FailureClass | "unrecorded"): string =>
    c === "unrecorded"
      ? "cause not recorded (a step predating this build, or a failure with no subprocess behind it)"
      : FAILURE_CLASS_TEXT[c].label;
  const distinct = [...new Set(classes)];
  if (distinct.length === 1) {
    const c = distinct[0];
    return (
      `observed cause in all ${classes.length}: ${text(c)}.` +
      (c === "unrecorded" ? "" : " " + FAILURE_CLASS_TEXT[c].advice)
    );
  }
  return (
    `observed causes: ${distinct.map((c) => text(c)).join("; ")} — these attempts failed for ` +
    "different reasons, so there is no single cause to name. Each needs a different fix, so read " +
    "both attempts before choosing one."
  );
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
    `stopping: "${key}" failed ${MAX_CONSECUTIVE_FAILURES} times in a row — ` +
      describeFailureStreak(streakFailureClasses(state, key)) +
      ` Per-attempt detail: ${join(stateDirFor(cwd), "history.jsonl")}.`,
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
  const exitStepLastActivityAt = state.currentStepLastActivityAt;
  await doReviewAndSquash(pi, ctx, cwd, state, runStartSha);
  state.status = exitStatus;
  state.currentStep = exitStep;
  state.currentStepStartedAt = exitStepStartedAt;
  state.currentStepTimeoutMs = exitStepTimeoutMs;
  state.currentStepLastActivityAt = exitStepLastActivityAt;
}

/**
 * Reads this run's slice of history.jsonl (not `state.history`, which is capped at
 * MAX_HISTORY and would silently drop early tickets on a long run) and reports what
 * actually got done: tickets executed/planned/chosen and review outcomes.
 */
async function buildFinalSummary(
  cwd: string,
  state: RalphState,
): Promise<string> {
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
  if (state.waitingOnHuman?.length)
    lines.push(
      `Waiting on a human (${state.waitingOnHuman.length}) — these cannot be closed by agent work:` +
        state.waitingOnHuman.map((t) => `\n  ${t.id} - ${t.title}`).join(""),
    );
  if (planned.length)
    lines.push(`Also touched by planning: ${planned.join(", ")}`);
  if (promoted.length)
    lines.push(
      `Promoted from Blocked to To Do (${promoted.length}): ${promoted.join(", ")}`,
    );
  if (executeFailed.length)
    lines.push(`Failed to execute: ${executeFailed.join(", ")}`);
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
  const squashFailures = thisRun.filter(
    (e) => e.kind === "squash" && e.outcome === "failed",
  );
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
        if (stoppedByFailureStreak(cwd, state, `execute:${active.id}`, ok))
          break;
        continue;
      }

      const needsPlan = await findFirstByStatus(pi, cwd, "Needs Plan");
      if (needsPlan) {
        const ok = await doPlan(pi, ctx, cwd, state, needsPlan);
        await persist(cwd, state);
        renderWidget(ctx, state);
        if (stoppedByFailureStreak(cwd, state, `plan:${needsPlan.id}`, ok))
          break;
        continue;
      }

      let unblocked = await listUnblocked(pi, cwd);
      if (unblocked.length === 0) {
        const promoted = await promoteUnblockedBlockedTickets(
          pi,
          ctx,
          cwd,
          state,
        );
        await persist(cwd, state);
        renderWidget(ctx, state);
        if (promoted.length > 0) unblocked = await listUnblocked(pi, cwd);
      }
      if (unblocked.length === 0) {
        // Nothing left that an agent may take. Before declaring the backlog drained, check the
        // other half of the assignment convention: if unblocked work sits with a person, that
        // is the actual state of the project, and "no unblocked tickets remain" would be a lie
        // that sends the owner off to look for work that does not exist.
        const waiting = await listWaitingOnHuman(pi, cwd);
        state.waitingOnHuman = waiting;
        finish(
          state,
          "done",
          waiting.length > 0
            ? `no agent-pickable tickets remain (${waiting.length} waiting on a human)`
            : "no unblocked tickets remain",
        );
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

/** ` (12m03s elapsed · quiet 40s · cap 4h00m)` for the current step, or "" if it has no
 * subprocess behind it (bookkeeping steps like a single-candidate `choose`). "quiet" is the time
 * since the worker last wrote to its transcript tree, shown once it passes a minute, so the
 * idle limit is visible coming before it fires. */
function stepTimingSuffix(state: RalphState): string {
  if (!state.currentStepStartedAt || !state.currentStepTimeoutMs) return "";
  const now = Date.now();
  const parts = [`${formatDuration(now - Date.parse(state.currentStepStartedAt))} elapsed`];
  const quiet =
    state.currentStepLastActivityAt === undefined
      ? 0
      : now - state.currentStepLastActivityAt;
  if (quiet >= 60_000) {
    parts.push(`quiet ${formatDuration(quiet)} of ${formatDuration(WORKER_IDLE_LIMIT_MS)}`);
  }
  parts.push(`cap ${formatDuration(state.currentStepTimeoutMs)}`);
  return ` (${parts.join(" · ")})`;
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
 * elapsed/quiet timing in `widgetLines` updates live instead of only
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

// --- Step log viewer -----------------------------------------------------------

/**
 * `/ralph-log` renders a headless worker's own session file the same way pi renders an
 * interactive session — the same per-entry components (`AssistantMessageComponent`,
 * `ToolExecutionComponent`, ...), not a plain-text dump. Modeled on `@gotgenes/pi-subagents`'
 * `/subagents:sessions` transcript viewer (see that package's
 * docs/decisions/0007-transcript-viewer-is-not-an-overlay.md), but simpler in one respect: a
 * ralph worker is a separate `pi -p` subprocess, not an in-process subagent, so there is no
 * `AgentSession` to subscribe to — only its session file on disk (see `sessionDirFor`). A
 * still-running step's file is polled and fully re-rendered on each change instead, which is
 * simple rather than incremental, but a worker session's message count is small enough (tens
 * to low hundreds) that a full rebuild every couple of seconds is cheap.
 *
 * Mounted through `ui.custom`'s non-overlay path for the same reason `/subagents:sessions`
 * is: pi's regular-mode renderer composites `overlay: true` mounts into the buffer that
 * becomes terminal scrollback, so an overlay transcript viewer bakes its own chrome into
 * history once a large-enough render burst carries a row off-screen in one frame. The
 * non-overlay path (a full-width pane docked above the editor) never composites, so nothing
 * can be baked in.
 */

type SessionMessage = SessionContext["messages"][number];
type SessionModel = SessionContext["model"];

/** Reads a worker's session file fresh off disk and resolves it to the same message list (and
 * current model) pi's own interactive session builds from — drops the file's leading `session`
 * header entry. */
function readTranscript(
  file: string,
): { messages: SessionMessage[]; model: SessionModel } {
  const raw = readFileSync(file, "utf8");
  const entries = parseSessionEntries(raw).filter(
    (entry): entry is SessionEntry => entry.type !== "session",
  );
  const { messages, model } = buildSessionContext(entries);
  return { messages, model };
}

/** `4200` -> `"4.2k"`, `1234567` -> `"1.2M"`. No model-catalog lookup is attempted for a
 * denominator (a "% of context window" figure) — ralph's workers run under whatever model
 * alias the user's provider config resolves (frequently a custom litellm route), which isn't
 * a lookup key any bundled model catalog recognizes, so a computed percentage would be
 * fabricated for exactly the setups this runs under. Raw token counts from the session's own
 * reported usage are honest regardless of provider. */
function formatTokenCount(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`;
  return String(n);
}

/** Concatenates the text blocks of a user message's content (mirrors pi's own rendering). */
function transcriptUserText(
  content: string | readonly { type: string; text?: string }[],
): string {
  if (typeof content === "string") return content;
  return content
    .filter((block) => block.type === "text")
    .map((block) => block.text ?? "")
    .join("");
}

/**
 * A worker session's messages, rendered through pi's own per-entry components into one flat
 * row list. Rebuilt wholesale from the full message array on every `refresh()` that finds new
 * messages, rather than incrementally appended — see the file-header note on why that's an
 * acceptable trade for a file-backed (not live in-process) source.
 */
class RalphTranscriptContent {
  private root = new Container();
  private messageCount = 0;
  private width: number | undefined;
  private rows: readonly string[] | undefined;
  private model: SessionModel = null;
  /** The most recent assistant message's token usage, or undefined before any response has
   * landed — see `usageSummary`. */
  private lastUsage: Usage | undefined;

  constructor(
    private readonly tui: TUI,
    private readonly cwd: string,
    private readonly markdownTheme: MarkdownTheme,
    private readonly file: string,
  ) {
    this.refresh();
  }

  /** Re-reads the session file; rebuilds and returns true only if its message count changed. */
  refresh(): boolean {
    let messages: SessionMessage[];
    let model: SessionModel;
    try {
      ({ messages, model } = readTranscript(this.file));
    } catch {
      return false;
    }
    this.model = model;
    if (messages.length === this.messageCount) return false;
    this.build(messages);
    return true;
  }

  lineCount(width: number): number {
    return this.rendered(width).length;
  }

  slice(width: number, start: number, count: number): string[] {
    return this.rendered(width).slice(start, start + count);
  }

  invalidate(): void {
    this.root.invalidate();
    this.rows = undefined;
  }

  /**
   * One line summarizing what this worker is running and how much of its exchange the most
   * recent turn used — the closest honest equivalent to pi's own context-usage readout that's
   * available for an arbitrary headless session (see `formatTokenCount` on why this stops at
   * raw counts rather than a window percentage). Undefined before the first response lands.
   */
  usageSummary(): string | undefined {
    if (!this.lastUsage) return undefined;
    const modelLabel = this.model
      ? `${this.model.provider}/${this.model.modelId}`
      : "unknown model";
    const promptTokens =
      this.lastUsage.input + this.lastUsage.cacheRead + this.lastUsage.cacheWrite;
    return (
      `${modelLabel} · last turn: ${formatTokenCount(promptTokens)} in` +
      ` (${formatTokenCount(this.lastUsage.cacheRead)} cached) / ` +
      `${formatTokenCount(this.lastUsage.output)} out`
    );
  }

  private rendered(width: number): readonly string[] {
    if (this.width !== width) {
      this.width = width;
      this.rows = undefined;
    }
    if (!this.rows) {
      this.rows = this.root
        .render(width)
        .map((row) => truncateToWidth(row, width));
    }
    return this.rows;
  }

  /** Maps the full message list onto one flat component tree, mirroring pi's own
   * interactive-mode session-context rendering. */
  private build(messages: SessionMessage[]): void {
    const root = new Container();
    const pendingTools = new Map<string, ToolExecutionComponent>();
    let hasVisibleContent = false;
    let lastUsage: Usage | undefined;

    for (const message of messages) {
      switch (message.role) {
        case "assistant": {
          lastUsage = message.usage;
          root.addChild(
            new AssistantMessageComponent(message, false, this.markdownTheme),
          );
          for (const content of message.content) {
            if (content.type !== "toolCall") continue;
            const tool = new ToolExecutionComponent(
              content.name,
              content.id,
              content.arguments,
              { showImages: false },
              undefined,
              this.tui,
              this.cwd,
            );
            tool.setExpanded(true);
            root.addChild(tool);
            pendingTools.set(content.id, tool);
          }
          hasVisibleContent = true;
          break;
        }
        case "toolResult": {
          pendingTools.get(message.toolCallId)?.updateResult(message);
          pendingTools.delete(message.toolCallId);
          break;
        }
        case "user": {
          const text = transcriptUserText(message.content);
          if (!text) break;
          if (hasVisibleContent) root.addChild(new Spacer(1));
          const skillBlock = parseSkillBlock(text);
          if (skillBlock) {
            const skill = new SkillInvocationMessageComponent(
              skillBlock,
              this.markdownTheme,
            );
            skill.setExpanded(true);
            root.addChild(skill);
            if (skillBlock.userMessage) {
              root.addChild(new Spacer(1));
              root.addChild(
                new UserMessageComponent(
                  skillBlock.userMessage,
                  this.markdownTheme,
                ),
              );
            }
          } else {
            root.addChild(new UserMessageComponent(text, this.markdownTheme));
          }
          hasVisibleContent = true;
          break;
        }
        case "bashExecution": {
          const bash = new BashExecutionComponent(
            message.command,
            this.tui,
            message.excludeFromContext,
          );
          if (message.output) bash.appendOutput(message.output);
          bash.setComplete(
            message.exitCode,
            message.cancelled,
            undefined,
            message.fullOutputPath,
          );
          root.addChild(bash);
          hasVisibleContent = true;
          break;
        }
        case "compactionSummary": {
          root.addChild(new Spacer(1));
          const summary = new CompactionSummaryMessageComponent(
            message,
            this.markdownTheme,
          );
          summary.setExpanded(true);
          root.addChild(summary);
          hasVisibleContent = true;
          break;
        }
        case "branchSummary": {
          root.addChild(new Spacer(1));
          const summary = new BranchSummaryMessageComponent(
            message,
            this.markdownTheme,
          );
          summary.setExpanded(true);
          root.addChild(summary);
          hasVisibleContent = true;
          break;
        }
      }
    }

    this.root = root;
    this.messageCount = messages.length;
    this.lastUsage = lastUsage;
    this.rows = undefined;
  }
}

/** How often a still-running step's pane re-reads its worker's session file. Cheap relative
 * to a worker's own pace (pings every few minutes at most), so short polling slack is fine. */
const TRANSCRIPT_REFRESH_MS = 2_000;
/** Non-content rows: top rule, title, usage line, footer, bottom rule — see `render()`. */
const TRANSCRIPT_CHROME_LINES = 5;
const TRANSCRIPT_MIN_VIEWPORT = 3;
const TRANSCRIPT_VIEWPORT_PCT = 70;

/**
 * Read-only scrollable pane over a worker session transcript. Structurally the same
 * scroll/chrome/key-handling shape as `showProgressDashboard`'s dashboard component, with a
 * polling refresh in place of a plain interval repaint when the underlying step is still
 * running (`live`) — see the RalphTranscriptContent header for why polling instead of a
 * subscription.
 */
class RalphTranscriptPane implements Component {
  private scrollOffset = 0;
  private autoScroll = true;
  private renderedWidth: number | undefined;
  private closed = false;
  private pollTimer: ReturnType<typeof setInterval> | undefined;

  constructor(
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly title: string,
    private readonly content: RalphTranscriptContent,
    private readonly done: (result: undefined) => void,
    private readonly live: boolean,
  ) {
    if (live) {
      this.pollTimer = setInterval(() => {
        if (this.closed) return;
        if (this.content.refresh()) this.tui.requestRender();
      }, TRANSCRIPT_REFRESH_MS);
      this.pollTimer.unref?.();
    }
  }

  /**
   * Plain letter keys are the primary bindings here, not a fallback — pi's own
   * docs/keybindings.md documents that outside `--tui-mode fullscreen` (this pane's mode:
   * ralph never sets fullscreen), unmodified `up`/`down`/`pageUp`/`pageDown`/`home`/`end` are
   * hard-routed to the main input editor's cursor-movement bindings regardless of which
   * component currently holds focus. Confirmed live: those keys never reach this handler while
   * the pane is open. The named keys are kept below only because they're harmless if some
   * terminal/host combination ever does deliver them; j/k/f/b/g/e are what actually works.
   */
  handleInput(data: string): void {
    if (matchesKey(data, Key.escape) || matchesKey(data, "q")) {
      this.close();
      return;
    }
    const { viewportHeight, maxScroll } = this.scrollBounds(this.inputWidth());
    if (matchesKey(data, "up") || matchesKey(data, "k")) {
      this.scrollOffset = Math.max(0, this.scrollOffset - 1);
      this.autoScroll = this.scrollOffset >= maxScroll;
    } else if (matchesKey(data, "down") || matchesKey(data, "j")) {
      this.scrollOffset = Math.min(maxScroll, this.scrollOffset + 1);
      this.autoScroll = this.scrollOffset >= maxScroll;
    } else if (
      matchesKey(data, "pageUp") ||
      matchesKey(data, "shift+up") ||
      matchesKey(data, "b")
    ) {
      this.scrollOffset = Math.max(0, this.scrollOffset - viewportHeight);
      this.autoScroll = false;
    } else if (
      matchesKey(data, "pageDown") ||
      matchesKey(data, "shift+down") ||
      matchesKey(data, "f")
    ) {
      this.scrollOffset = Math.min(
        maxScroll,
        this.scrollOffset + viewportHeight,
      );
      this.autoScroll = this.scrollOffset >= maxScroll;
    } else if (matchesKey(data, "home") || matchesKey(data, "g")) {
      this.scrollOffset = 0;
      this.autoScroll = false;
    } else if (matchesKey(data, "end") || matchesKey(data, "e")) {
      this.scrollOffset = maxScroll;
      this.autoScroll = true;
    }
  }

  render(width: number): string[] {
    if (width < 6) return [];
    const th = this.theme;
    this.renderedWidth = width;
    const fit = (s: string) => truncateToWidth(s, width);
    // Top/bottom rules and an accent-colored title, so the pane reads as clearly bounded
    // against the ordinary conversation above it — a plain title line alone renders in the
    // same style as an assistant message, which made this pane easy to mistake for a
    // continuation of the main session rather than a separate worker's transcript.
    const rule = th.fg("mdHr", "─".repeat(width));
    const usageLine = this.content.usageSummary() ?? "(waiting for first response)";
    const lines: string[] = [
      rule,
      fit(th.bold(th.fg("accent", this.title))),
      fit(th.fg("dim", usageLine)),
    ];

    const { totalLines, viewportHeight, maxScroll } = this.scrollBounds(width);
    if (this.autoScroll) this.scrollOffset = maxScroll;
    const visibleStart = Math.min(this.scrollOffset, maxScroll);
    const visible = this.content.slice(width, visibleStart, viewportHeight);
    for (let i = 0; i < viewportHeight; i++) lines.push(fit(visible[i] ?? ""));

    const scrollPct =
      totalLines <= viewportHeight
        ? "100%"
        : `${Math.round(((visibleStart + viewportHeight) / totalLines) * 100)}%`;
    const footerLeft = th.fg(
      "dim",
      `${totalLines} lines · ${scrollPct}${this.live ? " · live" : ""}`,
    );
    const footerRight = th.fg("dim", "j/k scroll · f/b page · g/e top/end · q close");
    const gap = Math.max(
      1,
      width - visibleWidth(footerLeft) - visibleWidth(footerRight),
    );
    lines.push(fit(footerLeft + " ".repeat(gap) + footerRight));
    lines.push(rule);
    return lines;
  }

  invalidate(): void {
    this.content.invalidate();
  }

  dispose(): void {
    this.closed = true;
    if (this.pollTimer) clearInterval(this.pollTimer);
  }

  private close(): void {
    if (this.closed) return;
    this.dispose();
    this.done(undefined);
  }

  private inputWidth(): number {
    return this.renderedWidth ?? this.tui.terminal.columns;
  }

  private scrollBounds(width: number): {
    totalLines: number;
    viewportHeight: number;
    maxScroll: number;
  } {
    const totalLines = this.content.lineCount(width);
    const viewportHeight = this.viewportHeight(totalLines);
    return {
      totalLines,
      viewportHeight,
      maxScroll: Math.max(0, totalLines - viewportHeight),
    };
  }

  private viewportHeight(totalLines: number): number {
    const cap =
      Math.floor((this.tui.terminal.rows * TRANSCRIPT_VIEWPORT_PCT) / 100) -
      TRANSCRIPT_CHROME_LINES;
    return Math.max(TRANSCRIPT_MIN_VIEWPORT, Math.min(totalLines, cap));
  }
}

async function showRalphTranscript(
  ctx: ExtensionCommandContext,
  file: string,
  title: string,
  live: boolean,
): Promise<void> {
  const markdownTheme = getMarkdownTheme();
  await ctx.ui.custom<undefined>(
    (tui, theme, _keybindings, done) => {
      const content = new RalphTranscriptContent(
        tui,
        ctx.cwd,
        markdownTheme,
        file,
      );
      return new RalphTranscriptPane(tui, theme, title, content, done, live);
    },
    { overlay: false },
  );
}

/** One `/ralph-log` picker line for a finished step's history entry. */
function historyLogLabel(entry: RalphHistoryEntry): string {
  const marker = entry.outcome === "ok" ? "✓" : "✗";
  const ticketPart = entry.ticket ? ` ${entry.ticket}` : "";
  const ago = formatDuration(Date.now() - Date.parse(entry.at));
  return `${marker} [${entry.kind}]${ticketPart} — ${tailSummary(entry.summary, 70)} (${ago} ago)`;
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
  promptSnippet:
    "Check live status of the running ralph autonomous backlog loop",
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
    const prefix = theme.fg(
      color,
      `[ralph ${level === "warn" ? "needs you" : "done"}]`,
    );
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

  pi.registerCommand("ralph-log", {
    description:
      "View a ralph step's full worker session log, rendered like an interactive pi session",
    handler: async (_args, ctx) => {
      if (!activeState) {
        ctx.ui.notify(
          "ralph has not been run yet in this session. Use /ralph to start it.",
          "info",
        );
        return;
      }
      if (ctx.mode !== "tui") {
        ctx.ui.notify("ralph-log needs the interactive TUI.", "warn");
        return;
      }
      const state = activeState;
      const cwd = ctx.cwd;

      type Candidate = { label: string; sessionId: string; live: boolean };
      const candidates: Candidate[] = [];
      if (
        state.currentStepSessionId &&
        (state.status === "running" || state.status === "stopping")
      ) {
        candidates.push({
          label: `▶ (running) ${state.currentStep ?? "working"}`,
          sessionId: state.currentStepSessionId,
          live: true,
        });
      }
      for (const entry of [...state.history].reverse()) {
        if (!entry.sessionId) continue;
        candidates.push({
          label: historyLogLabel(entry),
          sessionId: entry.sessionId,
          live: false,
        });
      }

      if (candidates.length === 0) {
        ctx.ui.notify(
          "No viewable step logs yet — run some ralph steps first.",
          "info",
        );
        return;
      }

      const choice = await ctx.ui.select(
        "Ralph step logs",
        candidates.map((c) => c.label),
      );
      const picked = candidates.find((c) => c.label === choice);
      if (!picked) return;

      const file = await resolveSessionFile(cwd, picked.sessionId);
      if (!file) {
        ctx.ui.notify(
          "That step's session log hasn't been written to disk yet — pi only creates the file " +
            "after the worker's first response. Try again in a moment.",
          "warn",
        );
        return;
      }
      await showRalphTranscript(
        ctx,
        file,
        `Ralph log: ${picked.label}`,
        picked.live,
      );
    },
  });

  pi.registerCommand("ralph-clear", {
    description: "Clear the ralph status widget once the loop has finished",
    handler: async (_args, ctx) => {
      if (!activeState) {
        ctx.ui.notify("ralph has not been run in this session.", "info");
        return;
      }
      if (
        activeState.status === "running" ||
        activeState.status === "stopping"
      ) {
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

  // Attach PING_REMINDER to a worker's progress ping on the first LLM call after it arrives.
  // `context` fires before every LLM call with a deep copy of the messages, so annotating here
  // touches nothing on disk and costs one extra line on the decision turn only. Gated on the
  // loop being live, exactly like the standing guidance above.
  const annotatedPings = new Set<string>();
  pi.on("context", async (event) => {
    const state = activeState;
    if (!state || (state.status !== "running" && state.status !== "stopping")) {
      return undefined;
    }
    let changed = false;
    for (const message of event.messages) {
      const text = userMessageText(message);
      if (!text || !PING_HEADER_PATTERN.test(text)) continue;
      const id = PING_ID_PATTERN.exec(text)?.[1];
      if (!id || annotatedPings.has(id)) continue;
      const injectedAt = Date.parse(
        PING_INJECTED_PATTERN.exec(text)?.[1] ?? "",
      );
      if (
        Number.isFinite(injectedAt) &&
        Date.now() - injectedAt > PING_REMINDER_MAX_AGE_MS
      ) {
        // Remember stale pings too, so they are not re-tested on every later call.
        annotatedPings.add(id);
        continue;
      }
      annotatedPings.add(id);
      const m = message as { content: unknown };
      if (typeof m.content === "string") {
        m.content += "\n\n" + PING_REMINDER;
      } else if (Array.isArray(m.content)) {
        m.content.push({ type: "text", text: "\n\n" + PING_REMINDER });
      }
      changed = true;
    }
    return changed ? { messages: event.messages } : undefined;
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
