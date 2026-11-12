
// ---- Appended to my-worktree/main.js by the build; it shares that file's imports. ----
// Needs from there: exec.
//
// Worktree operations through Worktrunk (`wt`), which owns where worktrees go
// (its `worktree-path`) and runs its hooks. `repo` is { top, main, name, linked }.
// `--yes` because nothing here can answer an approval prompt.

async function wtRun(cmd, cwd, args, on, timeout) {
  const r = await exec(cmd, args, { cwd, on, ...(timeout === undefined ? {} : { timeout }) });
  return { ok: r.code === 0, out: (r.stdout ?? "").trim(), err: (r.stderr ?? r.stdout ?? "").trim() };
}

const wtCmd = (cwd, args, on, timeout) => wtRun("wt", cwd, ["--yes", ...args], on, timeout);

// Upstream's own git worktree add/remove calls use this; hooks make wt slower, not faster.
const WT_SLOW_MS = 600_000;

// Every checkout of the repo, the main one first, then the most recently
// committed: { path, branch, main, at }.
async function wtCheckouts(repo, on) {
  const list = await wtCmd(repo.main, ["list", "--format=json"], on);
  if (!list.ok) return [];
  const out = [];
  for (const item of JSON.parse(list.out).items ?? []) {
    if (!item.worktree?.path) continue;
    const at = item.head?.committed_at;
    out.push({
      path: item.worktree.path,
      branch: item.branch ?? null,
      main: Boolean(item.worktree.main),
      at: typeof at === "number" ? at : Math.floor(Date.parse(at) / 1000) || 0,
    });
  }
  return out.sort((a, b) => b.main - a.main || b.at - a.at);
}

// Makes the branch's worktree (and the branch, if it is new). { path } or { error }.
// A branch only on a remote is not new: plain `wt switch` checks it out tracking the remote.
async function wtCreate(repo, branch, on) {
  // Best effort: offline, the refs already fetched decide. No prompt: nothing can answer one.
  await wtRun("env", repo.main, ["GIT_TERMINAL_PROMPT=0", "git", "fetch", "--all", "--quiet"], on).catch(() => {});
  const refs = await wtRun("git", repo.main, ["for-each-ref", "--count=1", "--format=%(refname)", `refs/heads/${branch}`, `refs/remotes/*/${branch}`], on);
  const exists = refs.ok && refs.out !== "";
  const r = await wtCmd(repo.top, ["switch", ...(exists ? [] : ["--create"]), "--no-cd", "--format=json", branch], on, WT_SLOW_MS);
  if (!r.ok) return { error: r.err || "wt switch failed." };
  // Hooks may print before the result: it is the last JSON line.
  const line = r.out.split("\n").reverse().find((l) => l.startsWith("{"));
  const path = line && JSON.parse(line).path;
  return path ? { path } : { error: "wt switch gave no worktree path." };
}

// Removes the repo's linked worktree. "" on success, else the error.
async function wtRemove(repo, force, on) {
  const r = await wtCmd(repo.main, ["remove", "--foreground", ...(force ? ["--force"] : []), repo.top], on, WT_SLOW_MS);
  return r.ok ? "" : r.err || "wt remove failed.";
}
