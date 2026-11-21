
// ---- Appended to my-spaces/main.js by the build; it shares that file's imports. ----
// Needs from there: div, exec, window.
//
// A space's PR state after its ahead/behind marks, so a glance shows what needs you.
// Same GitHub query as my-workspace-status/pr-status.js: a mod cannot import another's file.
// One `gh` call at a time, so render only reads the cache and a look runs in the background.

const SPACE_PR_QUERY = `query($owner: String!, $name: String!, $branch: String!) {
  repository(owner: $owner, name: $name) {
    pullRequests(headRefName: $branch, first: 1, orderBy: {field: CREATED_AT, direction: DESC}) {
      nodes {
        number state isDraft reviewDecision mergeable
        commits(last: 1) { nodes { commit { statusCheckRollup {
          state
          contexts(first: 1) {
            checkRunCountsByState { state count }
            statusContextCountsByState { state count }
          }
        } } } }
      }
    }
  }
}`;

const SPACE_PR_RUNNING = 30000; // checks still running
const SPACE_PR_SETTLED = 180000; // open PR, checks done
const SPACE_PR_NONE = 120000; // no PR yet: one may be opened soon after a push
const SPACE_PR_DONE = 600000; // merged or closed
const SPACE_PR_FAILED = 120000; // gh failed (offline, not GitHub, not logged in)
const SPACE_PR_AFTER_PUSH = 4000; // GitHub needs a moment to start checks
const SPACE_PR_SKIP = new Set(["master", "main", "(detached)"]);

const SPACE_PR_FAILING = new Set(["FAILURE", "ERROR", "TIMED_OUT", "STARTUP_FAILURE", "CANCELLED", "ACTION_REQUIRED"]);
const SPACE_PR_WAITING = new Set(["QUEUED", "IN_PROGRESS", "PENDING", "WAITING", "REQUESTED", "EXPECTED"]);

function parseSpacePr(reply) {
  const n = reply?.data?.repository?.pullRequests?.nodes?.[0];
  if (!n) return null;
  const rollup = n.commits?.nodes?.[0]?.commit?.statusCheckRollup;
  const counts = [...(rollup?.contexts?.checkRunCountsByState ?? []), ...(rollup?.contexts?.statusContextCountsByState ?? [])];
  const count = (states) => counts.reduce((sum, c) => sum + (states.has(c.state) ? c.count : 0), 0);
  return {
    number: n.number,
    state: n.state,
    draft: n.isDraft,
    review: n.reviewDecision,
    conflicts: n.mergeable === "CONFLICTING",
    failing: count(SPACE_PR_FAILING),
    running: count(SPACE_PR_WAITING),
  };
}

function spacePrLifetime(got) {
  if (got.failed) return SPACE_PR_FAILED;
  if (!got.pr) return SPACE_PR_NONE;
  if (got.pr.state !== "OPEN") return SPACE_PR_DONE;
  return got.pr.running ? SPACE_PR_RUNNING : SPACE_PR_SETTLED;
}

class SpacePrs {
  constructor() {
    this.cache = {}; // [repo, branch] -> { at, ahead, pr, failed }
    this.wanted = new Map(); // [repo, branch] -> { on, cwd, branch, ahead }
    this.busy = false;
  }

  // Queues a look at every branch in the list whose answer is missing or old.
  scan(view, cx) {
    if (!window()?.active) return;
    const now = Date.now();
    for (const g of Object.values(view.git)) {
      if (!g?.top || SPACE_PR_SKIP.has(g.branch)) continue;
      const [on] = JSON.parse(g.repo);
      if (view.folded.has(on)) continue;
      const key = JSON.stringify([g.repo, g.branch]);
      const got = this.cache[key];
      const pushed = got && got.ahead !== g.ahead && now - got.at > SPACE_PR_AFTER_PUSH;
      if (!got || pushed || now - got.at > spacePrLifetime(got)) this.wanted.set(key, { on, cwd: g.top, branch: g.branch, ahead: g.ahead });
    }
    this.next(cx);
  }

  next(cx) {
    if (this.busy) return;
    const [key, w] = this.wanted.entries().next().value ?? [];
    if (!key) return;
    this.wanted.delete(key);
    this.busy = true;
    cx.spawn(async (cx) => {
      const before = this.cache[key];
      // -F fills {owner} and {repo} from the folder's GitHub remote; -f keeps the branch a string.
      const args = ["api", "graphql", "-F", "owner={owner}", "-F", "name={repo}", "-f", `branch=${w.branch}`, "-f", `query=${SPACE_PR_QUERY}`];
      try {
        const r = await exec("gh", args, { cwd: w.cwd, on: w.on });
        this.cache[key] = r.code === 0
          ? { at: Date.now(), ahead: w.ahead, pr: parseSpacePr(JSON.parse(r.stdout)) }
          : { at: Date.now(), ahead: w.ahead, pr: before?.pr ?? null, failed: true };
      } catch {
        this.cache[key] = { at: Date.now(), ahead: w.ahead, pr: before?.pr ?? null, failed: true };
      }
      this.busy = false;
      cx.notify();
      this.next(cx);
    });
  }

  // Elements for the row's right edge, worst news first. Nothing when there is no PR.
  bits(g, t) {
    const pr = this.cache[JSON.stringify([g.repo, g.branch])]?.pr;
    if (!pr) return [];
    const bit = (color, text) => div().flex_none().text_color(color).child(text);
    if (pr.state === "MERGED") return [bit(t.ansi5, "◆")];
    if (pr.state === "CLOSED") return [bit(t.dim, "⊘")];
    const out = [];
    if (pr.failing) out.push(bit(t.ansi1, `✗${pr.failing}`));
    if (pr.conflicts) out.push(bit(t.ansi1, "≠"));
    if (pr.running) out.push(bit(t.ansi3, `●${pr.running}`));
    if (pr.draft) out.push(bit(t.dim, "○"));
    else if (pr.review === "APPROVED") out.push(bit(t.ansi2, "✓"));
    else if (pr.review === "CHANGES_REQUESTED") out.push(bit(t.ansi1, "↺"));
    else if (pr.review === "REVIEW_REQUIRED") out.push(bit(t.dim, "?"));
    return out;
  }
}
