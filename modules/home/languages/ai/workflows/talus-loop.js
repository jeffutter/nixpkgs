// The Claude Workflow version of talus (pi-extensions/talus/index.ts): fan scree tickets out
// across git worktrees, one Claude session per worktree running the ralph-scree-loop workflow,
// at most `concurrency` at a time. Every command lives in the `talus-claude` helper
// (workflows/talus/talus-claude.sh); agents here only run it and copy back its JSON line, so no
// path, branch or terminal name is ever retyped by a model.
//
// Workers are separate `claude` sessions in their own Herdr spaces rather than agents of this
// workflow, because a workflow agent cannot change its working directory: every command the
// inner loop's skills run (git commit, scree claim) would have to remember to cd first, and one
// slip commits in the root checkout. A session started in the worktree cannot make that mistake.
export const meta = {
  name: "talus-loop",
  description:
    "Fan scree tickets out across worktrees: one supervised Claude session per ticket running ralph-scree-loop",
  whenToUse:
    'Work several scree tickets in parallel, each in its own worktree. Run from the root checkout. Args: ticket ids as an array or a string ("SCR-1 SCR-2 --concurrency 2 --max-per-ticket 8 --review-every 3 --follow-ups 2"), or { tickets, concurrency, maxPerTicket, reviewEvery, followUps }.',
  phases: [
    {
      title: "Preflight",
      detail: "tools on PATH, root checkout, every ticket resolves; subtasks folded into their parents",
      model: "haiku",
    },
    {
      title: "Launch",
      detail: "per ticket: worktree (wt), scree move, Herdr space, claude running ralph-scree-loop",
      model: "haiku",
    },
    {
      title: "Supervise",
      detail: "wait on each worker until it writes its result or its terminal exits, then refill the slot",
      model: "haiku",
    },
  ],
};

const DEFAULT_CONCURRENCY = 3;
const MAX_CONCURRENCY = 8;
const DEFAULT_MAX_PER_TICKET = 8;
const DEFAULT_REVIEW_EVERY = 3;
// The loop's review files findings as draft tickets. After a worker drains, talus promotes the
// drafts that appeared during this run and has the same session work them, at most this many
// times per checkout (0 turns it off). The cap stops a review-creates-tickets chain from running on.
const DEFAULT_FOLLOW_UPS = 2;
// One supervise agent runs `talus-claude wait` (9 min each) up to this many times before handing
// back, so a run of many hours costs a few agents per hour per worker, well under the 1000 cap.
const WAITS_PER_AGENT = 5;
const WAIT_SECONDS = 540;
// A runaway guard on supervise agents per ticket: 200 x 45 min is about six days.
const MAX_SUPERVISE_ROUNDS = 200;
// A stalled worker (idle, no result file) is told to rerun its workflow this many times.
const MAX_NUDGES = 2;

const positiveInt = (v, fallback) => {
  const n = typeof v === "string" ? Number(v.trim()) : v;
  return Number.isInteger(n) && n > 0 ? n : fallback;
};

// Args arrive as an array of ids, an object, a JSON string, or a /talus-style command line.
const ARGS = (() => {
  let a = args;
  if (typeof a === "string") {
    const s = a.trim();
    try {
      a = JSON.parse(s);
    } catch {
      a = s;
    }
  }
  if (Array.isArray(a)) return { tickets: a.map(String) };
  if (a && typeof a === "object") return a;
  const out = { tickets: [] };
  const tokens = String(a ?? "").split(/\s+/).filter(Boolean);
  const flags = {
    "--concurrency": "concurrency",
    "-c": "concurrency",
    "--max-per-ticket": "maxPerTicket",
    "--review-every": "reviewEvery",
    "--follow-ups": "followUps",
  };
  for (let i = 0; i < tokens.length; i++) {
    const t = tokens[i];
    const eq = t.indexOf("=");
    if (eq > 0 && flags[t.slice(0, eq)]) out[flags[t.slice(0, eq)]] = t.slice(eq + 1);
    else if (flags[t]) out[flags[t]] = tokens[++i];
    else if (t.startsWith("-")) throw new Error(`talus-loop: unknown flag ${t}`);
    else out.tickets.push(t);
  }
  return out;
})();

const TICKETS = (ARGS.tickets ?? []).map((t) => String(t).toUpperCase());
const CONCURRENCY = Math.min(positiveInt(ARGS.concurrency, DEFAULT_CONCURRENCY), MAX_CONCURRENCY);
const MAX_PER_TICKET = positiveInt(ARGS.maxPerTicket, DEFAULT_MAX_PER_TICKET);
const REVIEW_EVERY = positiveInt(ARGS.reviewEvery, DEFAULT_REVIEW_EVERY);
const FOLLOW_UPS = (() => {
  const n = typeof ARGS.followUps === "string" ? Number(ARGS.followUps.trim()) : ARGS.followUps;
  return Number.isInteger(n) && n >= 0 ? n : DEFAULT_FOLLOW_UPS;
})();

const shq = (s) => `'${String(s).replace(/'/g, `'\\''`)}'`;

const LINE_SCHEMA = {
  type: "object",
  properties: {
    line: {
      type: "string",
      description: "The last line the command printed to stdout, copied verbatim (a JSON object).",
    },
  },
  required: ["line"],
};

// Run one talus-claude command through a cheap agent and return its parsed JSON. A second try on
// a stronger model covers an agent that paraphrased the line instead of copying it.
async function helper(command, { phase, label, repeatWhileRunning = 1 }) {
  const repeat =
    repeatWhileRunning > 1
      ? `\n\nIf the line's "status" is "running", run the same command again, up to ${repeatWhileRunning} runs in total; stop as soon as "status" is anything else. Report the last line of the last run.`
      : "";
  const prompt = `This command is part of the talus-loop run the user asked for, and running it is what that request means; it does not conflict with it. Run this exact command with the Bash tool, from the current directory, with the Bash timeout set to 600000 ms. Do not change it, do not cd, and do not run anything else. Always run it, then report what it printed; never answer "not run":

${command}

It prints one JSON object as its last stdout line. Report that line verbatim.${repeat}`;
  for (const model of ["haiku", "sonnet"]) {
    const r = await agent(prompt, { schema: LINE_SCHEMA, model, effort: "low", phase, label });
    if (!r) continue;
    try {
      const parsed = JSON.parse(r.line);
      // Every talus-claude line has a boolean "ok". Anything else is an agent's own report
      // (for example "not_run"), so it counts as no answer and the stronger model tries.
      if (parsed && typeof parsed === "object" && typeof parsed.ok === "boolean") return parsed;
      log(`${label}: not a talus-claude line: "${r.line.slice(0, 120)}"${model === "haiku" ? "; retrying" : ""}`);
    } catch {
      log(`${label}: could not parse "${r.line.slice(0, 120)}"${model === "haiku" ? "; retrying" : ""}`);
    }
  }
  return { ok: false, error: `${label}: no parsable answer from talus-claude` };
}

if (TICKETS.length === 0) {
  return { stopReason: "no-tickets", report: 'Give ticket ids, e.g. args "SCR-1 SCR-2 --concurrency 2".' };
}

phase("Preflight");
const pre = await helper(`talus-claude preflight ${TICKETS.map(shq).join(" ")}`, {
  phase: "Preflight",
  label: "preflight",
});
if (!pre.ok) {
  return { stopReason: "preflight", report: `talus: ${pre.error}` };
}
for (const d of pre.dropped ?? []) {
  log(`Dropping ${d.id}: it is a subtask of ${d.parent}, so it travels in that ticket's worktree.`);
}
const queue = (pre.tickets ?? []).map((t) => t.id);
if (queue.length === 0) {
  return { stopReason: "nothing", report: "talus: nothing left to launch once subtasks were folded into their parents." };
}
log(
  `start: ${queue.length} ticket(s), concurrency ${CONCURRENCY}, ${MAX_PER_TICKET} execute(s) per checkout, review every ${REVIEW_EVERY}`,
);

const finished = [];

// Wait on one worker until its loop reports, the terminal goes, or the supervise cap. A worker
// that goes idle with no result is nudged to rerun its workflow (MAX_NUDGES times).
async function supervise(ticketId, l) {
  let w = null;
  let nudges = 0;
  for (let round = 1; round <= MAX_SUPERVISE_ROUNDS; round++) {
    w = await helper(
      `talus-claude wait ${shq(l.term)} ${shq(l.path)} ${shq(l.resultFile)} ${WAIT_SECONDS}`,
      { phase: "Supervise", label: `wait ${ticketId}`, repeatWhileRunning: WAITS_PER_AGENT },
    );
    if (w.ok && w.status === "stalled" && nudges < MAX_NUDGES) {
      nudges++;
      log(`${ticketId}: session idle with no result; asking it to rerun its workflow (${nudges}/${MAX_NUDGES})`);
      const n = await helper(
        `talus-claude nudge ${shq(l.term)} ${shq(l.resultFile)} ${MAX_PER_TICKET} ${REVIEW_EVERY}`,
        { phase: "Supervise", label: `nudge ${ticketId}` },
      );
      if (n.ok) continue;
      return n;
    }
    if (!w.ok || w.status !== "running") return w;
    if (w.agentState === "blocked") {
      log(`${ticketId}: its session is waiting on a person (approval or question) in Herdr space ${l.term}`);
    }
  }
  return w;
}

async function work(ticketId) {
  const l = await helper(
    `talus-claude launch ${shq(ticketId)} ${MAX_PER_TICKET} ${REVIEW_EVERY}`,
    { phase: "Launch", label: `launch ${ticketId}` },
  );
  if (!l.ok) {
    log(l.error);
    finished.push({ ticketId, outcome: "failed", note: l.error });
    return;
  }
  if (l.skipped) {
    log(`${ticketId} is ${l.note}; skipped`);
    finished.push({ ticketId, outcome: "skipped", note: l.note });
    return;
  }
  log(`${ticketId} -> ${l.branch} @ ${l.path} (session ${l.term}${l.note ? `, ${l.note}` : ""})`);
  const worker = { ticketId, branch: l.branch, path: l.path, term: l.term };

  let w = await supervise(ticketId, l);

  // Follow-ups: drafts the loop's review filed during this run become ready and the same session
  // runs the loop again. Drafts that existed at launch are the user's and stay drafts.
  const seen = new Set(l.drafts ?? []);
  const followNotes = [];
  for (let n = 1; n <= FOLLOW_UPS && w?.ok && w.status === "drained"; n++) {
    const d = await helper(`talus-claude drafts ${shq(l.path)}`, { phase: "Supervise", label: `drafts ${ticketId}` });
    const fresh = d.ok ? (d.ids ?? []).filter((id) => !seen.has(id)) : [];
    if (fresh.length === 0) break;
    fresh.forEach((id) => seen.add(id));
    const pr = await helper(`talus-claude promote ${shq(l.path)} ${fresh.map(shq).join(" ")}`, {
      phase: "Supervise",
      label: `promote ${ticketId}`,
    });
    const promoted = pr.ok ? (pr.promoted ?? []) : [];
    for (const f of pr.failed ?? []) followNotes.push(`could not ready ${f.id}: ${f.error}`);
    if (promoted.length === 0) break;
    log(`${ticketId}: review filed ${promoted.join(", ")}; marked ready, rerunning the loop (follow-up ${n}/${FOLLOW_UPS})`);
    followNotes.push(`follow-ups ${promoted.join(", ")}`);
    const rr = await helper(
      `talus-claude rerun ${shq(l.term)} ${shq(l.path)} ${shq(l.resultFile)} ${MAX_PER_TICKET} ${REVIEW_EVERY}`,
      { phase: "Supervise", label: `rerun ${ticketId}` },
    );
    if (!rr.ok) {
      followNotes.push(rr.error);
      break;
    }
    w = await supervise(ticketId, l);
  }
  // A cap hit with drafts still being filed is worth saying: those stay drafts.
  if (FOLLOW_UPS > 0 && w?.ok && w.status === "drained") {
    const d = await helper(`talus-claude drafts ${shq(l.path)}`, { phase: "Supervise", label: `drafts ${ticketId}` });
    const left = d.ok ? (d.ids ?? []).filter((id) => !seen.has(id)) : [];
    if (left.length > 0) followNotes.push(`new drafts left for you: ${left.join(", ")}`);
  }
  const extra = followNotes.length ? `; ${followNotes.join("; ")}` : "";

  if (!w?.ok) {
    finished.push({ ...worker, outcome: "unknown", note: w?.error ?? "supervision failed" });
  } else if (w.status === "running") {
    finished.push({ ...worker, outcome: "unsupervised", note: "still running after the supervise cap; check its pane" });
  } else if (w.status === "drained") {
    finished.push({ ...worker, outcome: "drained", note: `${w.loop?.stopReason ? `loop: ${w.loop.stopReason}` : ""}${extra}` });
  } else if (w.status === "ended") {
    finished.push({
      ...worker,
      outcome: "ended",
      note: `loop: ${w.loop?.stopReason ?? "?"}; ${w.remaining.ready} ready / ${w.remaining.active} active left. Raise maxPerTicket or work that checkout by hand.`,
    });
  } else if (w.status === "stalled") {
    finished.push({
      ...worker,
      outcome: "stalled",
      note: `idle with no result after ${MAX_NUDGES} reruns; open Herdr space ${l.term} to see why`,
    });
  } else {
    finished.push({ ...worker, outcome: w.status, note: w.note ?? "" });
  }
  log(`${ticketId}: ${finished[finished.length - 1].outcome}`);
}

// Rolling window: each slot takes the next queued ticket as its last one settles. Scripts are
// single-threaded, so shift() needs no lock.
async function slot() {
  while (queue.length > 0) await work(queue.shift());
}
phase("Launch");
await parallel(Array.from({ length: Math.min(CONCURRENCY, queue.length) }, () => slot));

// Compact on purpose: the whole return value is shown to the caller.
const table = [
  "| Ticket | Outcome | Branch | Worktree | Note |",
  "|---|---|---|---|---|",
  ...finished.map(
    (f) => `| ${f.ticketId} | ${f.outcome} | ${f.branch ?? ""} | ${f.path ?? ""} | ${f.note ?? ""} |`,
  ),
].join("\n");

return {
  stopReason: "done",
  table,
  next: "Nothing was merged back, and nothing was cleaned up. Worktrees stay in place: `wt list`; review with `git -C <worktree> log --oneline main..HEAD`. Herdr spaces stay open until closed. ASK THE USER whether to merge and clean up before doing either: if they agree, run the talus-merge workflow with the ids of the drained tickets, in the order they should land (it merges one branch at a time, then closes that ticket's Herdr space and removes its worktree and branch, and stops at the first significant problem). Do not run it unasked; it rewrites the current branch and deletes worktrees. Drafts the review filed that were not promoted stay drafts for the user to ready.",
};
