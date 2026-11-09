export const meta = {
  name: "ralph-backlog-loop",
  description:
    "Priority-ordered autonomous Backlog.md loop for the current repo: execute > plan > choose",
  whenToUse:
    "Work through a repo's Backlog.md tickets unattended. Args: a number (max iterations) or { maxIterations, reviewEvery }.",
  phases: [
    {
      title: "Setup",
      detail: "ensure the pipeline statuses exist in backlog/config.yml",
      model: "haiku",
    },
    {
      title: "State",
      detail:
        "one CLI-only sweep: In Progress / Dev Ready / Needs Plan tickets, dependency-unblocked To Do, priority-sorted To Do, no-ralph list, @human-assigned list",
      model: "haiku",
    },
    { title: "Execute", detail: "run /backlog-execute on one ticket" },
    {
      title: "Readers",
      detail:
        "when Execute asks for independent readers, start them on the requested models (workflow agents cannot spawn agents themselves), then resume Execute with their answers",
    },
    {
      title: "Review",
      detail:
        "every 4 executes (reviewEvery arg): review recent work and create follow-up tickets for issues",
    },
    {
      title: "Plan",
      detail:
        "run /backlog-planner; large tickets decomposed into sub-tasks that each re-enter the loop",
    },
    {
      title: "Choose",
      detail:
        "deterministically pick the priority-sorted To Do ticket whose dependencies are all Done, not @human-assigned, and move it to Needs Plan",
      model: "haiku",
    },
  ],
};

// Args may arrive as a number (40), a numeric string ("40"), a JSON string
// ('{"maxIterations":40}') or an object ({ maxIterations, reviewEvery }).
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
  if (a && typeof a === "object") return a;
  return { maxIterations: a };
})();

const positiveInt = (v, fallback) => {
  const n = typeof v === "string" ? Number(v.trim()) : v;
  return Number.isInteger(n) && n > 0 ? n : fallback;
};

const MAX_ITERATIONS = positiveInt(ARGS.maxIterations, 25);
const REVIEW_EVERY = positiveInt(ARGS.reviewEvery, 4);

// Workflow agents have no Agent tool, so this script must start any readers a ticket needs.
const READER_MODELS = ["haiku", "sonnet", "opus"];
const MAX_READERS = 4;
const MAX_READER_ROUNDS = 2;

// On PATH from home-manager; run from the repo root (it cds into backlog/ itself).
const UNBLOCKED = "backlog-unblocked";

const CONTEXT = `Work in the current repository, at its root. Tickets are Backlog.md tasks under backlog/, managed with the \`backlog\` CLI.`;

const HUMAN_MEANING = `An "@human" assignee means the ticket needs a person: hardware, physical checks, access, or a decision that is the owner's. An agent can only produce a false Done on it.`;

const SETUP_SCHEMA = {
  type: "object",
  properties: {
    statuses: { type: "array", items: { type: "string" } },
    changed: { type: "boolean" },
  },
  required: ["statuses", "changed"],
};

// The script, not an LLM, decides branch and target from these lists.
const STATE_SCHEMA = {
  type: "object",
  properties: {
    inProgress: {
      type: "array",
      items: { type: "string" },
      description: "Ticket IDs with status In Progress, in list order",
    },
    devReady: {
      type: "array",
      items: { type: "string" },
      description: "Ticket IDs with status Dev Ready, in list order",
    },
    needsPlan: {
      type: "array",
      items: { type: "string" },
      description: "Ticket IDs with status Needs Plan, in list order",
    },
    unblockedInProgress: {
      type: "array",
      items: { type: "string" },
      description: `Every ticket ID from \`${UNBLOCKED} "In Progress"\`. Output lines are "ID - Title"; take the ID. These are In Progress tickets whose dependencies are all Done and that have no open child tickets.`,
    },
    unblockedDevReady: {
      type: "array",
      items: { type: "string" },
      description: `Every ticket ID from \`${UNBLOCKED} "Dev Ready"\`. Output lines are "ID - Title"; take the ID. These are Dev Ready tickets whose dependencies are all Done and that have no open child tickets.`,
    },
    unblockedTodo: {
      type: "array",
      items: { type: "string" },
      description: `Every ticket ID from \`${UNBLOCKED} "To Do"\`. Output lines are "ID - Title"; take the ID. These are To Do tickets whose dependencies are all Done.`,
    },
    todoByPriority: {
      type: "array",
      items: { type: "string" },
      description:
        'Every ticket ID from `backlog task list -s "To Do" --sort priority --plain`, in the order shown (already sorted high -> medium -> low -> unset).',
    },
    noRalph: {
      type: "array",
      items: { type: "string" },
      description:
        'Every ticket ID from `backlog task list -s "To Do" -l no-ralph --plain` (may be empty).',
    },
    humanOnly: {
      type: "array",
      items: { type: "string" },
      description:
        'Every ticket ID from `backlog task list -a "@human" --plain`, across ALL statuses (the command groups by status; collect IDs from every group). The loop must never work these.',
    },
  },
  required: [
    "inProgress",
    "devReady",
    "needsPlan",
    "unblockedInProgress",
    "unblockedDevReady",
    "unblockedTodo",
    "todoByPriority",
    "noRalph",
    "humanOnly",
  ],
};

const MOVE_SCHEMA = {
  type: "object",
  properties: {
    ticketId: { type: "string" },
    success: { type: "boolean" },
  },
  required: ["ticketId", "success"],
};

const VERIFY_SCHEMA = {
  type: "object",
  properties: {
    ticketId: { type: "string" },
    status: {
      type: "string",
      description: "The ticket's current status field, exactly as shown",
    },
    isUnblocked: {
      type: "boolean",
      description: `True if the ticket ID appears in the output of \`${UNBLOCKED} "Dev Ready"\`, meaning all its dependencies are Done. False if absent (it still has an unresolved dependency).`,
    },
    corrected: {
      type: "boolean",
      description:
        "True if this call found status=Dev Ready and isUnblocked=false and fixed it (edited to Blocked + note), false otherwise (including when no fix was needed)",
    },
  },
  required: ["ticketId", "status", "isUnblocked", "corrected"],
};

const ACTION_SCHEMA = {
  type: "object",
  properties: {
    ticketId: { type: "string" },
    outcome: {
      type: "string",
      description:
        "One of: completed, blocked-reverted, planned, needs-readers, error",
    },
    summary: {
      type: "string",
      description: "One sentence describing what happened",
    },
    readers: {
      type: "array",
      description:
        'Only with outcome "needs-readers": one entry per independent reader the script must start.',
      maxItems: MAX_READERS,
      items: {
        type: "object",
        properties: {
          label: {
            type: "string",
            description: 'Short arm name, e.g. "read-a"',
          },
          model: {
            type: "string",
            enum: READER_MODELS,
            description: "Model to run this reader on",
          },
          prompt: {
            type: "string",
            description:
              "The complete reader prompt, sent verbatim. The reader sees nothing else.",
          },
        },
        required: ["label", "model", "prompt"],
      },
    },
  },
  required: ["ticketId", "outcome", "summary"],
};

const REVIEW_SCHEMA = {
  type: "object",
  properties: {
    ticketsReviewed: { type: "array", items: { type: "string" } },
    issuesFound: { type: "number" },
    ticketsCreated: { type: "array", items: { type: "string" } },
    summary: { type: "string" },
  },
  required: ["ticketsReviewed", "issuesFound", "ticketsCreated", "summary"],
};

const SETUP_PROMPT = `${CONTEXT}

Read backlog/config.yml and look at the \`statuses\` list. The loop needs this pipeline:
  To Do -> Needs Plan -> Dev Ready -> In Progress -> Done
plus "Blocked", a dead end for tickets that cannot proceed.

If backlog/config.yml does not exist, change nothing and report statuses [] and changed false.

Otherwise add each of "Needs Plan", "Dev Ready" and "Blocked" that is missing. Put "Needs Plan" and "Dev Ready", in that order, between "To Do" and "In Progress"; put "Blocked" after "Done". Edit the file directly; \`backlog config set\` rejects that key. Do not remove, rename, or reorder any other status (for example "Decision", which holds wayfinder tickets the loop must not see).

Report via structured output:
- statuses: the final statuses list (after your edit, if any)
- changed: true if you modified the file, false if it already had everything needed`;

const STATE_PROMPT = `${CONTEXT}

Run these nine commands and report each result as a plain ID list. This is pure data extraction: no filtering, judgment, or dependency reasoning. The caller does that.

1. backlog task list -s "In Progress" --plain -> inProgress
2. backlog task list -s "Dev Ready" --plain -> devReady
3. backlog task list -s "Needs Plan" --plain -> needsPlan
4. ${UNBLOCKED} "To Do" -> unblockedTodo: every ticket ID from the output, which is one "ID - Title" line per ticket (take the part before the first " - "). If this command errors or is missing, report an EMPTY array and say so. Do not substitute another command.
5. backlog task list -s "To Do" --sort priority --plain -> todoByPriority: every ticket ID, in the order shown
6. backlog task list -s "To Do" -l no-ralph --plain -> noRalph: every ticket ID shown (empty array if none)
7. backlog task list -a "@human" --plain -> humanOnly: every ticket ID shown, from EVERY status group in the output. Do not pass -s, and do not stop at the first group (empty array if none)
8. ${UNBLOCKED} "In Progress" -> unblockedInProgress: same extraction as command 4, same rule on errors.
9. ${UNBLOCKED} "Dev Ready" -> unblockedDevReady: same extraction as command 4, same rule on errors.

Report all nine lists via the structured output.`;

function moveToNeedsPlanPrompt(ticketId) {
  return `${CONTEXT}

Run: backlog task edit ${ticketId} -s "Needs Plan"

Report via structured output: ticketId "${ticketId}", success (true if the edit succeeded, false otherwise).`;
}

function verifyAndCorrectPrompt(ticketId) {
  return `${CONTEXT}

Run: backlog task ${ticketId} --plain
Run: ${UNBLOCKED} "Dev Ready"

Determine:
- status: this ticket's current status field, exactly as shown
- isUnblocked: true if "${ticketId}" appears in the script's output (one "ID - Title" line per ticket), false if absent. Absent means it still has a dependency that is not Done, or an open child.

If status is exactly "Dev Ready" AND isUnblocked is false, the planner was wrong to mark it ready. Correct it now, in this same turn:
  backlog task edit ${ticketId} -s "Blocked"
and append one implementation note: planning marked this Dev Ready, but its dependencies are not all Done, so it was forced to Blocked. Re-check it once its dependencies are Done.

Set corrected to true only if you made that fix just now; false otherwise (including when no fix was needed).

Report via structured output: ticketId "${ticketId}", status, isUnblocked, corrected.`;
}

const READERS_RULE = `INDEPENDENT READERS. You cannot spawn subagents: this session has no Agent tool, and none can be loaded. If the ticket needs independent readers (for example blind reads on a model different from yours), the workflow script starts them for you:
1. Do all the preparation first: frames or files copied to absolute paths the readers will open, and the full prompt for each reader.
2. Save your progress so a fresh session can finish without you: commit what you have, and add a ticket implementation note saying what is done, where the reader files are, and what is left after the reads.
3. Report outcome "needs-readers" with up to ${MAX_READERS} entries in readers: label, model (one of ${READER_MODELS.join(", ")}; pick models different from your own if the ticket asks for that, and say which you are in your note), and prompt. Each prompt is sent verbatim and is all the reader sees, so it must name every file by absolute path and ask every question.
Readers run as the "blind-reader" agent type, whose only tool is Read. Do not ask for readers unless the ticket requires them.`;

function executePrompt(ticketId) {
  return `${CONTEXT}

FIRST, a hard stop check. Run: backlog task ${ticketId} --plain

If its assignee is "@human", STOP IMMEDIATELY. Do not implement it, do not mark any acceptance criterion, do not change its status. ${HUMAN_MEANING} Report outcome "error" with a summary saying the ticket is @human-assigned and was skipped.

Acceptance criteria prefixed "HUMAN:" can never be satisfied by writing code or watching a build succeed. If a ticket you are working carries one, leave it unchecked and do not mark the ticket Done.

HAND-OFF RULE: once you are finished (including the case where the work was already committed and you have nothing left to change), re-read the ticket with \`backlog task ${ticketId} --plain\`. If EVERY acceptance criterion still unchecked is prefixed "HUMAN:" (and at least one exists), the ticket has nothing left for an agent. Hand it to the owner so the loop moves on: run \`backlog task edit ${ticketId} -a "@human"\`, leave the status as it is (do not mark Done), and say in your summary that the ticket was reassigned to @human because only HUMAN: criteria remain. If any non-HUMAN criterion is still unchecked, do not reassign. Report outcome "completed" when you reassigned after real work, or after finding the work was already committed.

Otherwise, proceed: use the Skill tool to invoke "/backlog-execute ${ticketId}". This skill will claim the ticket, implement the work, mark acceptance criteria, add implementation notes and a summary, set the ticket status to Done, and commit the result, all per its own instructions. If the skill finds the ticket blocked by new work discovered mid-implementation, it parks the ticket as Blocked.

Dependency readiness is already guaranteed before a ticket reaches you: the Execute pool is filtered by ${UNBLOCKED} (all dependencies Done, no open child tickets, not @human), so you should not need to re-check dependencies here. If you nonetheless find the ticket genuinely can't proceed, follow the skill's own blocked-handling behavior.

${READERS_RULE}

After the skill finishes, report via structured output:
- ticketId: "${ticketId}"
- outcome: "completed" if the ticket was finished and committed, "blocked-reverted" if it was parked as Blocked or reverted to To Do, "needs-readers" if you stopped to have the script start readers (see INDEPENDENT READERS), or "error" if something went wrong
- summary: one sentence describing what happened
- readers: only with "needs-readers"`;
}

function resumeWithReadersPrompt(ticketId, answers) {
  const blocks = answers
    .map(
      (a) => `### ${a.label} (model: ${a.model})

PROMPT (sent verbatim):
<<<
${a.prompt}
>>>

ANSWER (verbatim):
<<<
${a.answer}
>>>`,
    )
    .join("\n\n");
  return `${executePrompt(ticketId)}

RESUMING. An earlier session on this ticket prepared independent reads and reported "needs-readers". The workflow script ran them as "blind-reader" agents (Read tool only) on the models below. Read that session's implementation note on the ticket, then use the Skill tool to invoke "/backlog-execute ${ticketId}" and finish the ticket using these results. Record the prompts and answers verbatim wherever the ticket asks for transcripts, and record each reader's model as given here. Ask for readers again only if the ticket needs another round.

${blocks}`;
}

function planPrompt(ticketId) {
  return `${CONTEXT}

First, run: backlog task ${ticketId} --plain
If it already carries the "planned" label AND its status is still "Needs Plan", a previous loop iteration already finished planning it but failed to move it out of "Needs Plan". Do NOT re-invoke the planner skill (it is expensive and the work is done). Apply the status rule below directly, based on whether it has sub-tickets or direct work, and report outcome "planned".

Otherwise, use the Skill tool to invoke "/backlog-planner ${ticketId}". This skill researches the ticket, analyzes dependencies, and writes a detailed implementation plan.

Large ticket decomposition: if the ticket is large or complex, the planner SHOULD break it into sub-tasks. Each sub-task starts at "To Do" and goes through the full choose -> plan -> execute cycle on its own in a later iteration.

Once planning is complete, the ticket must NOT be left in "Needs Plan": the loop re-queries that status every iteration, and a ticket left there gets re-planned from scratch on the next pass. Set its status to exactly one of:
- "Dev Ready" if the ticket has direct implementation work of its own (with or without sub-tasks alongside it):
    backlog task edit ${ticketId} -s "Dev Ready"
- "Blocked" if all its work was delegated to sub-tasks and it is now a pure tracking ticket with no direct implementation of its own. A later pass (or a person) promotes it once its children are Done:
    backlog task edit ${ticketId} -s "Blocked"

Report via structured output:
- ticketId: "${ticketId}"
- outcome: "planned" if planning completed and the status was moved out of "Needs Plan" (to Dev Ready or Blocked), or "error" if something went wrong
- summary: one sentence describing what was planned (and any sub-tickets created)`;
}

function reviewPrompt(executedTicketIds) {
  return `${CONTEXT}

The following tickets were recently implemented and committed: ${executedTicketIds.join(", ")}.

Review the work and create follow-up backlog tickets for any real issues found:

1. Find commits for this work:
     git log --oneline -20
   Identify commits related to the tickets listed above.

2. Use the Skill tool to invoke "/code-review" on the recent changes (medium effort is fine).

3. For each genuine issue (correctness bugs, significant inefficiencies, clear design problems; NOT nitpicks or style):
     backlog task create "Fix: <brief description>" --description "<detail>" --status "To Do" --label "review-fix" --priority high --depends-on <ID of the reviewed ticket the issue traces back to>

   The reviewed ticket is already Done, so the follow-up is immediately unblocked and sorts to the top by priority. Do not add a ready-for-agent label.

   Only create tickets you'd actually want implemented. Err on the side of fewer, higher-signal tickets.

4. Report via structured output:
   - ticketsReviewed: the ticket IDs that were reviewed (${executedTicketIds.join(", ")})
   - issuesFound: number of issues that warranted new tickets
   - ticketsCreated: list of new ticket IDs created (empty array if none)
   - summary: one sentence summarizing the review outcome`;
}

phase("Setup");
const setup = await agent(SETUP_PROMPT, {
  schema: SETUP_SCHEMA,
  model: "haiku",
  phase: "Setup",
});
if (!setup || setup.statuses.length === 0) {
  return {
    stopReason: setup ? "no-backlog" : "setup-error",
    iterations: 0,
    results: [],
    table: setup
      ? "(no backlog/config.yml in this repo; run /setup-backlog-tracker first)"
      : "(setup failed)",
  };
}
log(
  `Setup: statuses = [${setup.statuses.join(", ")}]${setup.changed ? " (updated config.yml)" : ""}`,
);

const results = [];
let stopReason = "cap";
let executeCount = 0;
let executedSinceReview = [];
// One execute and one plan per ticket per run; re-picking a stuck ticket would burn the cap on it.
const setAside = new Map();

for (let i = 0; i < MAX_ITERATIONS; i++) {
  phase("State");
  // An all-empty sweep means the agent skipped the commands, not a drained backlog: retry.
  let state = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    const s = await agent(
      attempt === 0
        ? STATE_PROMPT
        : `${STATE_PROMPT}\n\nYour previous answer had every list empty without running the commands. You MUST actually run all nine commands with the Bash tool and copy the IDs from their real output.`,
      {
        schema: STATE_SCHEMA,
        model: attempt === 0 ? "haiku" : "sonnet",
        phase: "State",
      },
    );
    if (!s) continue;
    const allEmpty = [
      s.inProgress,
      s.devReady,
      s.needsPlan,
      s.unblockedInProgress,
      s.unblockedDevReady,
      s.unblockedTodo,
      s.todoByPriority,
      s.noRalph,
      s.humanOnly,
    ].every((a) => a.length === 0);
    if (!allEmpty) {
      state = s;
      break;
    }
    log(
      `State sweep returned all-empty lists (attempt ${attempt + 1}); retrying.`,
    );
  }
  if (!state) {
    stopReason = "state-error";
    log(
      "State detection failed, or the backlog has no tickets in any loop status; stopping.",
    );
    break;
  }

  // @human tickets are filtered from every branch; unassigned tickets stay eligible.
  const humanOnly = new Set(state.humanOnly);
  // Execute pools also require backlog-unblocked to list the ticket: deps Done, no open children.
  const unblockedIP = new Set(state.unblockedInProgress);
  const unblockedDR = new Set(state.unblockedDevReady);
  const agentInProgress = state.inProgress.filter(
    (id) => !humanOnly.has(id) && unblockedIP.has(id) && !setAside.has(id),
  );
  const agentDevReady = state.devReady.filter(
    (id) => !humanOnly.has(id) && unblockedDR.has(id) && !setAside.has(id),
  );
  const heldBack = [
    ...state.inProgress.filter(
      (id) => !humanOnly.has(id) && !unblockedIP.has(id),
    ),
    ...state.devReady.filter(
      (id) => !humanOnly.has(id) && !unblockedDR.has(id),
    ),
  ];
  if (heldBack.length > 0) {
    log(
      `Holding back ${heldBack.length} In Progress/Dev Ready ticket(s) waiting on dependencies or open children: ${heldBack.join(", ")}.`,
    );
  }
  const agentNeedsPlan = state.needsPlan.filter(
    (id) => !humanOnly.has(id) && !setAside.has(id),
  );

  const skippedHuman = [
    ...state.inProgress,
    ...state.devReady,
    ...state.needsPlan,
  ].filter((id) => humanOnly.has(id)).length;
  if (skippedHuman > 0) {
    log(
      `Skipping ${skippedHuman} @human-assigned ticket(s) in the active pool; they need a person, not an agent.`,
    );
  }

  if (agentInProgress.length > 0 || agentDevReady.length > 0) {
    const target = agentInProgress[0] || agentDevReady[0];
    setAside.set(target, "already executed this run");

    phase("Execute");
    log(`Iteration ${i + 1}: execute -> ${target}`);
    let outcome = await agent(executePrompt(target), {
      schema: ACTION_SCHEMA,
      phase: "Execute",
    });
    for (
      let round = 1;
      outcome?.outcome === "needs-readers" && round <= MAX_READER_ROUNDS;
      round++
    ) {
      const requests = outcome.readers ?? [];
      if (requests.length === 0) {
        outcome = {
          ...outcome,
          outcome: "error",
          summary: `Reported needs-readers with no reader requests. ${outcome.summary}`,
        };
        break;
      }
      phase("Readers");
      log(
        `${target}: starting ${requests.length} reader(s), round ${round}: ${requests.map((r) => `${r.label} on ${r.model}`).join(", ")}`,
      );
      const answers = await parallel(
        requests.map(
          (r) => () =>
            agent(r.prompt, {
              agentType: "blind-reader",
              model: r.model,
              label: `${target} ${r.label}`,
              phase: "Readers",
            }).then((answer) => ({ ...r, answer })),
        ),
      );
      const failed = requests.filter((r, idx) => !answers[idx]?.answer);
      if (failed.length > 0) {
        outcome = {
          ...outcome,
          outcome: "error",
          summary: `Reader(s) ${failed.map((r) => r.label).join(", ")} returned nothing; progress is saved on the ticket. ${outcome.summary}`,
        };
        break;
      }
      phase("Execute");
      outcome = await agent(resumeWithReadersPrompt(target, answers), {
        schema: ACTION_SCHEMA,
        phase: "Execute",
      });
    }
    if (outcome?.outcome === "needs-readers") {
      outcome = {
        ...outcome,
        outcome: "error",
        summary: `Still asking for readers after ${MAX_READER_ROUNDS} round(s); progress is saved on the ticket. ${outcome.summary}`,
      };
    }
    if (!outcome) {
      results.push({
        ticketId: target,
        phase: "execute",
        outcome: "error",
        summary: "subagent returned no result",
      });
      stopReason = "execute-error";
      break;
    }
    results.push({
      ticketId: target,
      phase: "execute",
      outcome: outcome.outcome,
      summary: outcome.summary,
    });

    executeCount++;
    executedSinceReview.push(target);

    if (executeCount % REVIEW_EVERY === 0) {
      phase("Review");
      log(
        `Review triggered after ${REVIEW_EVERY} executes (${executedSinceReview.join(", ")})`,
      );
      const review = await agent(reviewPrompt(executedSinceReview), {
        schema: REVIEW_SCHEMA,
        phase: "Review",
      });
      executedSinceReview = [];
      if (review) {
        results.push({
          ticketId: "(review)",
          phase: "review",
          outcome:
            review.issuesFound > 0
              ? `${review.issuesFound} issue(s) queued`
              : "clean",
          summary: review.summary,
        });
        if (review.ticketsCreated.length > 0) {
          log(
            `Review created ${review.ticketsCreated.length} follow-up ticket(s): ${review.ticketsCreated.join(", ")}`,
          );
        }
      }
    }

    continue;
  }

  if (agentNeedsPlan.length > 0) {
    const target = agentNeedsPlan[0];
    setAside.set(target, "already planned this run");

    phase("Plan");
    log(`Iteration ${i + 1}: plan -> ${target}`);
    const outcome = await agent(planPrompt(target), {
      schema: ACTION_SCHEMA,
      phase: "Plan",
    });
    if (!outcome) {
      results.push({
        ticketId: target,
        phase: "plan",
        outcome: "error",
        summary: "subagent returned no result",
      });
      stopReason = "plan-error";
      break;
    }
    results.push({
      ticketId: target,
      phase: "plan",
      outcome: outcome.outcome,
      summary: outcome.summary,
    });

    // The planner judges direct work vs tracking ticket, not dependency state, so check that here.
    if (outcome.outcome === "planned") {
      const verify = await agent(verifyAndCorrectPrompt(target), {
        schema: VERIFY_SCHEMA,
        model: "haiku",
        phase: "Plan",
      });
      if (verify && verify.corrected) {
        log(
          `Corrected ${target}: planner set "Dev Ready" but it still has an unresolved dependency; forced to "Blocked".`,
        );
        results.push({
          ticketId: target,
          phase: "plan",
          outcome: "corrected-to-blocked",
          summary:
            "Planner marked this Dev Ready but it still has an unresolved dependency; forced to Blocked so Execute never receives it.",
        });
      }
    }
    continue;
  }

  phase("Choose");
  // unblockedTodo decides eligibility; todoByPriority only orders it, since the agent can drop IDs.
  const noRalph = new Set(state.noRalph);
  const rank = new Map(state.todoByPriority.map((id, idx) => [id, idx]));
  const byPriority = [...state.unblockedTodo].sort(
    (a, b) =>
      (rank.get(a) ?? Infinity) - (rank.get(b) ?? Infinity) ||
      state.unblockedTodo.indexOf(a) - state.unblockedTodo.indexOf(b),
  );
  const target =
    byPriority.find((id) => !noRalph.has(id) && !humanOnly.has(id)) ?? null;

  if (!target) {
    stopReason = "drained";
    const stillPooled = [
      ...state.inProgress,
      ...state.devReady,
      ...state.needsPlan,
    ].filter((id) => setAside.has(id));
    if (stillPooled.length > 0) {
      log(
        `Note: ${stillPooled.length} ticket(s) already handled this run are still in In Progress/Dev Ready/Needs Plan and were not retried: ${stillPooled.map((id) => `${id} (${setAside.get(id)})`).join(", ")}. Check their results above.`,
      );
    }
    if (heldBack.length > 0) {
      log(
        `Note: ${heldBack.length} In Progress/Dev Ready ticket(s) remain held back (dependencies or open children): ${heldBack.join(", ")}. A person must fix them.`,
      );
    }
    const blockedOnHuman = byPriority.filter(
      (id) => !noRalph.has(id) && humanOnly.has(id),
    );
    log(
      blockedOnHuman.length > 0
        ? `Backlog drained for agent work. ${blockedOnHuman.length} ready ticket(s) are waiting on a human: ${blockedOnHuman.join(", ")}.`
        : "Backlog drained: no To Do ticket has all dependencies Done, is unlabeled no-ralph, and is not @human-assigned.",
    );
    break;
  }

  const moved = await agent(moveToNeedsPlanPrompt(target), {
    schema: MOVE_SCHEMA,
    model: "haiku",
    phase: "Choose",
  });
  if (!moved || !moved.success) {
    stopReason = "choose-error";
    log(`Failed to move ${target} to Needs Plan; stopping.`);
    break;
  }

  log(`Iteration ${i + 1}: choose -> ${target}`);
  results.push({
    ticketId: target,
    phase: "choose",
    outcome: "queued-for-planning",
    summary: `Deterministically picked: highest-priority To Do ticket whose dependencies are all Done, not labeled no-ralph and not @human-assigned, out of ${state.todoByPriority.length} To Do candidate(s).`,
  });
}

const table = [
  "| Ticket | Phase | Outcome | Summary |",
  "|---|---|---|---|",
  ...results.map(
    (r) => `| ${r.ticketId} | ${r.phase} | ${r.outcome} | ${r.summary} |`,
  ),
].join("\n");

return { stopReason, iterations: results.length, results, table };
