// The second half of talus: land the branches a talus-loop run finished, one at a time. For each
// ticket, in the order given: merge its branch into the root checkout's current branch (an agent
// resolves conflicts and runs the project's checks), then close its Herdr space, remove its
// worktree and branch, then move on. The first significant problem stops the whole run with the
// merge undone, so main is never left half merged.
//
// Run it from the root checkout, and only after the person has said to merge and clean up: it
// rewrites main and deletes worktrees. Everything that can be decided by a command lives in the
// `talus-claude` helper (workflows/talus/talus-claude.sh: merge-info, cleanup); the one agent
// that needs judgment is the merger.
export const meta = {
  name: "talus-merge",
  description:
    "Merge finished talus branches into the root checkout one at a time, closing each one's Herdr space and worktree before the next",
  whenToUse:
    'After a talus-loop run, and only once the user has agreed to merge and clean up. Run from the root checkout. Args: done ticket ids in merge order, as an array or a string ("SCR-43 SCR-44"), or { tickets }. Stops at the first branch that has a significant problem.',
  phases: [
    { title: "Check", detail: "ticket is done, worktree clean, root checkout clean", model: "haiku" },
    { title: "Merge", detail: "git merge --no-ff, resolve conflicts, run the project's checks", model: "opus" },
    { title: "Clean up", detail: "close the Herdr space, remove the worktree and branch", model: "haiku" },
  ],
};

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
  return { tickets: String(a ?? "").split(/\s+/).filter(Boolean) };
})();
const TICKETS = (ARGS.tickets ?? []).map((t) => String(t).toUpperCase());

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

// Same shape as talus-loop's helper: run one talus-claude command through a cheap agent, parse its
// JSON line, retry once on a stronger model. A reply without a boolean "ok" is not the helper's.
async function helper(command, { phase, label }) {
  const prompt = `This command is part of the talus-merge run the user asked for, and running it is what that request means; it does not conflict with it. Run this exact command with the Bash tool, from the current directory, with the Bash timeout set to 120000 ms. Do not change it, do not cd, and do not run anything else. Always run it, then report what it printed; never answer "not run":

${command}

It prints one JSON object as its last stdout line. Report that line verbatim.`;
  for (const model of ["haiku", "sonnet"]) {
    const r = await agent(prompt, { schema: LINE_SCHEMA, model, effort: "low", phase, label });
    if (!r) continue;
    try {
      const parsed = JSON.parse(r.line);
      if (parsed && typeof parsed === "object" && typeof parsed.ok === "boolean") return parsed;
    } catch {
      // fall through to the stronger model
    }
    log(`${label}: not a talus-claude line: "${String(r.line).slice(0, 120)}"${model === "haiku" ? "; retrying" : ""}`);
  }
  return { ok: false, error: `${label}: no parsable answer from talus-claude` };
}

const MERGE_SCHEMA = {
  type: "object",
  properties: {
    status: {
      type: "string",
      enum: ["merged", "stop"],
      description: "merged: the merge commit exists and every check passed. stop: a significant problem; the merge is undone.",
    },
    summary: { type: "string", description: "One or two sentences: what was merged and how conflicts were resolved." },
    conflicts: { type: "array", items: { type: "string" }, description: "Files that conflicted, if any." },
    problem: { type: "string", description: "When stop: what went wrong, concretely, and the state main was left in." },
  },
  required: ["status", "summary"],
};

function mergePrompt(info) {
  return `Merge the branch ${info.branch} (ticket ${info.id}: ${info.title}) into the current branch ${info.base} of this checkout, which is the repository's root checkout. Work here, at the repository root. Never push, never force anything, never touch any other branch or worktree.

The root checkout was at commit ${info.head} before you start, and the branch has ${info.ahead} commit(s) that ${info.base} lacks. Earlier branches of this run are already merged, so conflicts with them are expected; the ticket's own work is on the branch.

1. Run: git merge --no-ff ${shq(info.branch)} -m ${shq(`Merge ${info.id}: ${info.title}`)}
2. If it conflicts, understand both sides before resolving: read both versions, \`git log\` the commits behind each side, and keep the intent of both. Things that conflict without a textual conflict, and which you must look for: numbered files or ids that two branches both took (rename the later one and update whatever lists them), counts or versions asserted in tests, generated or snapshot files (regenerate or merge them with the project's own tool rather than hand-editing when it has one), docs that describe both changes, and code that compiles on each side alone but not together.
3. Read the repository's CLAUDE.md and AGENTS.md for how to build and test, and run the full set of checks it names (tests, lint, format) on the merged result, fixing mechanical breakage the merge caused. Do not commit until they pass.
4. Commit the merge (git commit --no-edit if git left it staged).

A significant problem means you must stop: the two sides cannot both be kept without changing what either one does beyond mechanical reconciliation; a check still fails after a reasonable fix that is not a mechanical consequence of merging; or the branch's work looks wrong or incomplete in a way the merge exposed. Minor problems you fixed are not a reason to stop; list them in the summary.

To stop: if the merge is still in progress, run \`git merge --abort\`. If you already committed the merge, run \`git reset --hard ${info.head}\` only after confirming that \`git rev-parse HEAD^1\` equals ${info.head} (so the commit being dropped is your own merge commit); otherwise leave it and say so in "problem". Then confirm \`git status\` is clean and report status "stop" with the concrete problem.

When done, report status "merged" with a short summary and the list of files that conflicted.`;
}

if (TICKETS.length === 0) {
  return { stopReason: "no-tickets", report: 'Give done ticket ids in merge order, e.g. args "SCR-43 SCR-44".' };
}
if (new Set(TICKETS).size !== TICKETS.length) {
  return { stopReason: "duplicates", report: "talus-merge: a ticket is listed twice." };
}

const rows = [];
const table = () =>
  [
    "| Ticket | Result | Note |",
    "|---|---|---|",
    ...rows.map((r) => `| ${r.id} | ${r.result} | ${r.note ?? ""} |`),
  ].join("\n");
const stop = (id, result, note) => {
  rows.push({ id, result, note });
  const left = TICKETS.slice(TICKETS.indexOf(id) + 1);
  return {
    stopReason: "stopped",
    table: table(),
    stoppedAt: id,
    notRun: left,
    next: `Stopped at ${id}: ${note} The root checkout is left as that row says. Nothing after ${id} was touched; rerun talus-merge with ${[id, ...left].join(" ")} once it is sorted out.`,
  };
};

for (const id of TICKETS) {
  phase("Check");
  const info = await helper(`talus-claude merge-info ${shq(id)}`, { phase: "Check", label: `check ${id}` });
  if (!info.ok) return stop(id, "not merged", info.error);

  if (info.merged) {
    log(`${id}: ${info.branch} is already in ${info.base}; cleaning up only`);
  } else {
    phase("Merge");
    log(`${id}: merging ${info.branch} into ${info.base}`);
    const m = await agent(mergePrompt(info), {
      schema: MERGE_SCHEMA,
      model: "opus",
      effort: "medium",
      phase: "Merge",
      label: `merge ${id}`,
    });
    if (!m) return stop(id, "not merged", "the merge agent returned nothing; check `git status` and `git log` in the root checkout.");
    if (m.status !== "merged") {
      return stop(id, "stopped", m.problem ?? m.summary);
    }
    // Trust the repository, not the agent's say-so: the branch must now be an ancestor of HEAD.
    const after = await helper(`talus-claude merge-info ${shq(id)}`, { phase: "Check", label: `verify ${id}` });
    if (!after.ok || !after.merged) {
      return stop(id, "unverified", `the merge agent reported success but ${info.branch} is not in ${info.base}${after.ok ? "" : ` (${after.error})`}.`);
    }
    rows.push({ id, result: "merged", note: [m.summary, m.conflicts?.length ? `conflicts: ${m.conflicts.join(", ")}` : ""].filter(Boolean).join(" ") });
  }

  phase("Clean up");
  const c = await helper(
    `talus-claude cleanup ${shq(info.branch)} ${shq(info.path)} ${shq(info.term)}`,
    { phase: "Clean up", label: `cleanup ${id}` },
  );
  if (!c.ok) {
    // Merged but not cleaned: say so, and stop rather than stack more work on a dirty slate.
    return stop(id, "merged, cleanup failed", `${c.error}`);
  }
  if (info.merged) rows.push({ id, result: "cleaned up", note: "was already merged" });
  else rows[rows.length - 1].note += ` Closed ${c.spaceClosed ? "the Herdr space" : "no Herdr space (none found)"}, removed the worktree and branch.`;
}

return {
  stopReason: "done",
  table: table(),
  next: "Every listed branch is merged into the root checkout's current branch and its Herdr space, worktree and branch are gone. Nothing was pushed: review `git log --oneline` and push yourself.",
};
