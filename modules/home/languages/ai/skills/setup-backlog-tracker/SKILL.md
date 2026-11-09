---
name: setup-backlog-tracker
description: Point the engineering skills (to-tickets, wayfinder, triage, to-spec) at Backlog.md as this repo's issue tracker, and add the statuses the ralph-backlog-loop workflow needs. Use when a repo should track work in Backlog.md, before running /to-tickets or /wayfinder there, or when asked to "use backlog for tickets here".
---

Configure this repo so every ticket lives in Backlog.md. Run every step in order.

1. If `backlog/config.yml` does not exist, run `backlog init "<repo directory name>" --defaults`. If that command rejects `--defaults`, run `backlog init --help` and pick the non-interactive form.
2. Read `backlog/config.yml`. Make its `statuses` list hold `To Do`, `Needs Plan`, `Dev Ready`, `In Progress`, `Done`, `Blocked` and `Decision`, in that order. Keep any other status that is already there, after `Done`. Edit the file directly; `backlog config set` rejects that key.
3. Copy [issue-tracker-backlog.md](./issue-tracker-backlog.md) verbatim to `docs/agents/issue-tracker.md`. If that file exists and describes another tracker, show its first 10 lines, ask the user before you replace it, and stop if they decline.
4. `backlog init` always creates `AGENTS.md`, so put the `## Agent skills` block in `AGENTS.md`. Keep any other subsection already in the block. If `CLAUDE.md` does not exist, create it containing only `@AGENTS.md`; if it exists and does not mention `AGENTS.md`, add that line at the top. Set the issue tracker subsection to:

   ```markdown
   ### Issue tracker

   Backlog.md tasks under `backlog/`, managed with the `backlog` CLI. See `docs/agents/issue-tracker.md`.
   ```
5. If `.scratch/*/issues/*.md` files exist, list them and tell the user that they are not in Backlog yet. Do not convert them unless the user asks. To convert, for each effort directory in file-number order:
   - Create one task per file as in the tracker doc's "publish to the issue tracker" section. Write a throwaway script in the scratchpad; do not run a probe `backlog task create` to learn the output, because it takes an ID. The create output contains `Task TASK-<n>`; read the new ID from it.
   - A file's `# NN: title` line gives the title. `**Blocked by:**` is a comma-separated list of `NN: title` entries, or `None`. A blocker has a lower number than the file that names it, so creating in file order means every `--dep` names an ID that exists. Stop if a blocker is not yet created.
   - Each `- [ ]` line is one `--ac`. The `**What to build:**` paragraph is the description.
   - Map `Status: done` or `resolved` to `Done`, and anything else (including `ready-for-agent`) to `To Do`. Do not use `Dev Ready`: the ralph-backlog-loop plans `To Do` tickets first and promotes them itself.
   - If a task was created by mistake, `backlog task archive <n>` then `backlog task delete <n>` frees its ID.
   - Print the old-path-to-new-ID table.
   - Run `git ls-files .scratch`. If the old files are tracked, offer to delete them (they stay in history); otherwise leave them for the user.
6. Print the files you changed and the final status list.
