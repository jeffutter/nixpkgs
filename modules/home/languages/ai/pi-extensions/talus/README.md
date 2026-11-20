# talus — the outer loop for scree tickets

Two commands work together:

| command | file | what it does |
| --- | --- | --- |
| `/ralph-scree [max] [reviewEvery]` | `../ralph-scree/index.ts` | inner loop: churns the scree tickets that live in **one** checkout — plan, execute, review — with headless `pi` workers and a liveness watchdog. |
| `/talus SCR-1 SCR-2 ... [--concurrency N]` | this directory | outer loop: fans a list of tickets out across git worktrees, one supervised session each running `/ralph-scree`. |

Under Claude Code, the same fan-out is the `talus-loop` workflow
(`../../workflows/talus-loop.js`, commands in `../../workflows/talus/talus-claude.sh`): it starts
`claude` running the `ralph-scree-loop` workflow in each worktree instead of `pi` running
`/ralph-scree`.

Run talus from the **root checkout** of a repo (`/talus` refuses elsewhere, because it has to
hand work to other sessions). It needs `wt`, `scree`, `hc` and `herdr-app` on PATH.

## What it does per ticket

1. Names a branch after the ticket: `scr-<ticket-id>-<first words of the title>`.
2. Creates the worktree with Worktrunk:
   `wt switch --create --no-cd --format=json <branch>` → `~/.herdr/worktrees/<repo>/<branch>`.
   The root checkout stays where it is. No `--yes`: if the project's `.config/wt.toml` hooks
   need approval, that decision is yours, and talus tells you to run
   `wt config approvals add`.
3. Moves the ticket and its subtasks into it: `scree move <id> --worktree <path>`, then leaves a
   comment on the ticket saying where it went, so the workers read their own context off the
   ticket.
4. Opens a Herdr space for it whose terminal is a **child of your session**
   (`hc run --bg --label herdr.space=talus-<id> -- …`) and names the space `<SCR-12 title>`. End
   that terminal and the space goes with it. Children die with your session by default — that is
   `hc`'s behaviour, no `--outlive-parent`.
5. Starts `pi` in it with `/ralph-scree <max-per-ticket> <review-every>` as its first message.

Then it supervises: every 45 s it reads each worktree's board (`scree list`) and each session's
state (`hc get`). A worktree with no ready or active agent tickets left is **drained** and its
slot goes to the next queued ticket. Your status line shows
`talus: SCR-1:running SCR-2:drained · queued 3 · concurrency 2`.

```
/talus SCR-1 SCR-2 SCR-3 --concurrency 2         # rolling window of 2
/talus SCR-1 --max-per-ticket 4 --review-every 2 # inner-loop knobs
/talus-progress                                  # worktrees, branches, sessions, queue, log
/talus-stop                                      # launch nothing else; running ones untouched
```

Tickets already done or abandoned are reported as `skipped (done)` rather than launched; a ticket
already filed under an existing worktree is worked **there**, so rerunning talus continues a fan-out
instead of forking a second checkout of it. An id scree does not know aborts the whole command
before any worktree is created.

To ask a running session something without touching your hands to the keyboard, use real keystrokes
rather than `hc send`, which pastes and therefore never runs a slash command:

```sh
hc keys talus-ts9-9 slash t a l u s minus p r o g r e s s enter
hc keys talus-ts9-9 slash r a l p h minus s c r e e minus s t o p enter   # stop one loop
```

Subtasks named next to their own parent are dropped from the list with a note — moving the parent
already moves them, and two sessions on one ticket would fight over the claim. Rerunning talus on
the same tickets reuses their existing worktrees instead of forking a second copy.

## Secrets: `~/.config/talus/env.sh`

A terminal started through `hc` inherits the herdr-core environment, **not** yours, so
`LITELLM_KEY` is missing there and the `pi` wrapper falls back to an interactive `op signin` —
which hangs unseen in a background pane. Talus therefore sources `~/.config/talus/env.sh` before
`exec pi`, and logs when that file is absent:

```sh
install -d -m 700 ~/.config/talus
umask 077
printf 'export LITELLM_KEY=%s\n' "$LITELLM_KEY" > ~/.config/talus/env.sh
```

Keep the key in a file rather than in `hc run --env KEY=…`: argv is typed onto the worker's screen
and lands in its transcript.

## Not implemented yet: merging back

Nothing here destroys work — every branch and worktree stays on disk after the run, and no merge,
rebase or PR happens. That is deliberate: watch a few runs before deciding what shipping looks
like (PR per worktree? rebase onto main as each drains? who resolves conflicts?). Meanwhile:

```sh
wt list                      # where everything is
cd ~/.herdr/worktrees/<repo>/<branch> && git log --oneline main..HEAD
wt remove <branch>           # discard a checkout you are done with
```

Ralph-scree's review step files anything it cannot fix itself as a follow-up ticket, so parallel
runs do not silently overwrite each other's findings.

## Why an extension and not a skill

The sequence has to be exact, repeated N times, while you watch. A model retyping absolute
worktree paths and space ids is a failure mode; a loop that reads them out of command output is
not. Two mechanics are also easy to get wrong and are handled in code:

- The first message must be a **pi argument**. Text delivered later with `hc send` arrives as a
  bracketed paste, which pi submits as an ordinary user message — slash commands never fire.
- `hc run --bg` returns before the core has registered the new space, so the space rename retries
  until it lands.
