
// ---- Appended to my-workspace-status/main.js by the build; it shares that file's imports. ----
// Needs from there: div, h_flex, exec, panes, spaces, window, watchFolder.
//
// The GitHub PR for the focused pane's branch: number, review decision, checks.
// One `gh api graphql` call takes about a second, so render never waits on it: it shows the
// last answer for that repo and branch, and a look runs in the background when one is due.

// GitHub counts check runs and commit statuses by state, so the reply stays small on big PRs.
const PR_QUERY = `query($owner: String!, $name: String!, $branch: String!) {
  repository(owner: $owner, name: $name) {
    pullRequests(headRefName: $branch, first: 1, orderBy: {field: CREATED_AT, direction: DESC}) {
      nodes {
        number url state isDraft reviewDecision mergeable
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

// How long an answer stands while the window is in front.
const PR_RUNNING = 30000; // checks still running
const PR_SETTLED = 180000; // open PR, checks done
const PR_NONE = 120000; // no PR yet: one may be opened soon after a push
const PR_DONE = 600000; // merged or closed
const PR_FAILED = 120000; // gh failed (offline, not GitHub, not logged in)
const PR_REFOCUS = 30000; // coming back to the window looks again if the answer is older
const PR_AFTER_PUSH = 4000; // a push or fetch moved a remote ref: GitHub needs a moment for checks

const PR_FAILING = new Set(["FAILURE", "ERROR", "TIMED_OUT", "STARTUP_FAILURE", "CANCELLED", "ACTION_REQUIRED"]);
const PR_WAITING = new Set(["QUEUED", "IN_PROGRESS", "PENDING", "WAITING", "REQUESTED", "EXPECTED"]);

function parsePr(reply) {
  const n = reply?.data?.repository?.pullRequests?.nodes?.[0];
  if (!n) return null;
  const rollup = n.commits?.nodes?.[0]?.commit?.statusCheckRollup;
  const counts = [...(rollup?.contexts?.checkRunCountsByState ?? []), ...(rollup?.contexts?.statusContextCountsByState ?? [])];
  const count = (states) => counts.reduce((sum, c) => sum + (states.has(c.state) ? c.count : 0), 0);
  return {
    number: n.number,
    url: n.url,
    state: n.state,
    draft: n.isDraft,
    review: n.reviewDecision,
    conflicts: n.mergeable === "CONFLICTING",
    checks: rollup?.state ?? null,
    failing: count(PR_FAILING),
    running: count(PR_WAITING),
  };
}

function prLifetime(got) {
  if (got.failed) return PR_FAILED;
  if (!got.pr) return PR_NONE;
  if (got.pr.state !== "OPEN") return PR_DONE;
  return got.pr.running ? PR_RUNNING : PR_SETTLED;
}

class PrStatus {
  constructor(cx) {
    this.repos = {}; // [machine, cwd] -> { top, common }, or null: not a repo
    this.resolving = new Set();
    this.prs = {}; // [machine, top, branch] -> { at, pr, failed }
    this.pushed = {}; // local git common dir -> when a remote ref last changed
    this.watching = new Set();
    this.fetching = false;
    this.wasActive = window()?.active;
    cx.timer.every(2000, (cx) => this.tick(cx));
  }

  // The focused terminal in the shown space, else its shown tab's first, else its first.
  target() {
    const space = spaces().find((s) => s.active);
    if (!space) return null;
    const shownTab = space.tabs.find((t) => t.active)?.id;
    const tabs = new Set(space.tabs.map((t) => t.id));
    const ps = panes().filter((p) => tabs.has(p.tab) && p.terminal && p.cwd);
    const p = ps.find((p) => p.focused) ?? ps.find((p) => p.tab === shownTab) ?? ps[0];
    if (!p?.branch) return null;
    return { on: space.machine ?? null, cwd: p.cwd, branch: p.branch };
  }

  // The repo a folder is in, from cache; an unknown folder is looked up and answers next tick.
  repo(w, cx) {
    const key = JSON.stringify([w.on, w.cwd]);
    if (key in this.repos) return this.repos[key];
    if (this.resolving.has(key)) return null;
    this.resolving.add(key);
    cx.spawn(async (cx) => {
      try {
        const r = await exec("git", ["rev-parse", "--path-format=absolute", "--show-toplevel", "--git-common-dir"], { cwd: w.cwd, on: w.on });
        const [top, common] = r.stdout.trim().split("\n");
        this.repos[key] = r.code === 0 && top && common ? { top, common } : null;
        if (this.repos[key] && !w.on) this.watch(common, cx);
      } catch {
        // The machine is away: ask again on a later tick.
      }
      this.resolving.delete(key);
      this.tick(cx);
    });
    return null;
  }

  // A push (or fetch) rewrites refs/remotes or packed-refs under the shared .git folder.
  watch(common, cx) {
    if (this.watching.has(common)) return;
    this.watching.add(common);
    cx.spawn(async () => {
      try {
        for (;;) {
          const changed = await watchFolder(common);
          if (changed.some((p) => p.includes("refs/remotes/") || p.endsWith("packed-refs"))) this.pushed[common] = Date.now();
        }
      } catch {
        this.watching.delete(common);
      }
    });
  }

  tick(cx) {
    const active = window()?.active;
    const refocused = active && !this.wasActive;
    this.wasActive = active;
    const w = this.target();
    const repo = w && this.repo(w, cx);
    if (!repo || this.fetching) return;
    const key = JSON.stringify([w.on, repo.top, w.branch]);
    const got = this.prs[key];
    const now = Date.now();
    const pushed = this.pushed[repo.common] ?? 0;
    const due =
      !got ||
      (got.at < pushed + PR_AFTER_PUSH && now >= pushed + PR_AFTER_PUSH) ||
      (active && now - got.at > (refocused ? Math.min(PR_REFOCUS, prLifetime(got)) : prLifetime(got)));
    if (due) this.fetch(key, w.on, repo.top, w.branch, cx);
  }

  fetch(key, on, cwd, branch, cx) {
    this.fetching = true;
    cx.spawn(async (cx) => {
      const before = this.prs[key];
      // -F fills {owner} and {repo} from the folder's GitHub remote; -f keeps the branch a string.
      const args = ["api", "graphql", "-F", "owner={owner}", "-F", "name={repo}", "-f", `branch=${branch}`, "-f", `query=${PR_QUERY}`];
      try {
        const r = await exec("gh", args, { cwd, on });
        this.prs[key] = r.code === 0 ? { at: Date.now(), pr: parsePr(JSON.parse(r.stdout)) } : { at: Date.now(), pr: before?.pr ?? null, failed: true };
      } catch {
        this.prs[key] = { at: Date.now(), pr: before?.pr ?? null, failed: true };
      }
      this.fetching = false;
      cx.notify();
    });
  }

  open(url) {
    const opener = { macos: "open", linux: "xdg-open" }[window()?.platform];
    if (opener) exec(opener, [url]).catch(() => {});
  }

  // The branch label, then the PR's state when it has one.
  view(t, label, cx) {
    this.tick(cx);
    const w = this.target();
    if (!w) return div();
    const repo = this.repos[JSON.stringify([w.on, w.cwd])];
    const pr = repo && this.prs[JSON.stringify([w.on, repo.top, w.branch])]?.pr;
    const bit = (color, text) => div().flex_none().text_color(color).child(text);
    const bits = [];
    if (pr?.state === "MERGED") bits.push(bit(t.ansi5, "merged"));
    else if (pr?.state === "CLOSED") bits.push(bit(t.dim, "closed"));
    else if (pr) {
      if (pr.draft) bits.push(bit(t.dim, "draft"));
      else if (pr.review === "APPROVED") bits.push(bit(t.ansi2, "✓ approved"));
      else if (pr.review === "CHANGES_REQUESTED") bits.push(bit(t.ansi1, "changes requested"));
      else if (pr.review === "REVIEW_REQUIRED") bits.push(bit(t.dim, "needs review"));
      if (pr.conflicts) bits.push(bit(t.ansi1, "conflicts"));
      if (pr.failing) bits.push(bit(t.ansi1, `✗ ${pr.failing} failing`));
      if (pr.running) bits.push(bit(t.ansi3, `● ${pr.running} running`).loop("opacity", { from: 0.4, to: 1, period: 1200 }));
      if (!pr.failing && !pr.running && pr.checks === "SUCCESS") bits.push(bit(t.ansi2, "✓ checks"));
    }
    return h_flex()
      .flex_none()
      .gap(10)
      .items_center()
      .child(label("branch", w.branch))
      .when(Boolean(pr), (el) =>
        el
          .child(
            div()
              .id("pr-link")
              .flex_none()
              .cursor_pointer()
              .hover((s) => s.text_color(t.foreground))
              .on_click(() => this.open(pr.url))
              .child(`#${pr.number}`),
          )
          .children(bits),
      );
  }
}
