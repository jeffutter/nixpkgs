---
name: setup-backlog-tracker
description: Point the engineering skills (to-tickets, wayfinder, triage, to-spec) at Backlog.md as this repo's issue tracker, and add the statuses the ralph-backlog-loop workflow needs. Use when a repo should track work in Backlog.md, before running /to-tickets or /wayfinder there, or when asked to "use backlog for tickets here".
---

Configure this repo so every ticket lives in Backlog.md. Run every step in order.

1. If `backlog/config.yml` does not exist, run `backlog init "<repo directory name>" --defaults`. If that command rejects `--defaults`, run `backlog init --help` and pick the non-interactive form.
2. Read `backlog/config.yml`. Make its `statuses` list hold `To Do`, `Needs Plan`, `Dev Ready`, `In Progress`, `Done`, `Blocked` and `Decision`, in that order. Keep any other status that is already there, after `Done`. Edit the file directly; `backlog config set` rejects that key.
3. Copy [issue-tracker-backlog.md](./issue-tracker-backlog.md) verbatim to `docs/agents/issue-tracker.md`. If that file exists and describes another tracker, show its first 10 lines, ask the user before you replace it, and stop if they decline.
4. Add or update the `## Agent skills` block in `CLAUDE.md` (or `AGENTS.md` if that is the one that exists; never create the other). Keep any other subsection already in the block. Set the issue tracker subsection to:

   ```markdown
   ### Issue tracker

   Backlog.md tasks under `backlog/`, managed with the `backlog` CLI. See `docs/agents/issue-tracker.md`.
   ```
5. If `.scratch/*/issues/*.md` files exist, list them and tell the user that they are not in Backlog yet. Do not convert them unless the user asks. To convert, for each effort directory in file-number order: create one task per file as in the tracker doc's "publish to the issue tracker" section, map each `Blocked by` entry to the new ID of that file, map `Status: done` or `resolved` to `Done` and anything else to `To Do`, and print the old-path-to-new-ID table. Leave the old files for the user to delete.
6. Print the files you changed and the final status list.
