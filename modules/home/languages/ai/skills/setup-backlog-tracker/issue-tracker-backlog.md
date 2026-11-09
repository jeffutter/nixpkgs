# Issue tracker: Backlog.md

Issues for this repo live as Backlog.md tasks under `backlog/`. Use the `backlog` CLI for every operation. Never edit task files by hand. Pass `--plain` to every read.

## Statuses

The pipeline is `To Do -> Needs Plan -> Dev Ready -> In Progress -> Done`. `Blocked` holds tickets that cannot proceed. `Decision` holds wayfinder maps and tickets, which the `ralph-backlog-loop` workflow never picks up.

## Conventions

- **Create an issue**: `backlog task create "<title>" -d "<description>" --ac "<criterion>" --ac "<criterion>"`. Add `--priority high|medium|low`, `-l <label>`, `-p <parent-id>` and `--dep <id>,<id>` as needed. Every acceptance criterion is its own `--ac`.
- **Read an issue**: `backlog task <id> --plain`.
- **List issues**: `backlog task list --plain` with `-s <status>`, `-l <label>`, `-p <parent-id>` or `-a <assignee>` filters.
- **Make an issue a sub-issue of a parent**: `-p <parent-id>` on create. The parent depends on each child: `backlog task edit <parent-id> --dep <child-id>`.
- **Comment on an issue**: `backlog task edit <id> --comment "<text>"`.
- **Apply / remove labels**: `backlog task edit <id> --add-label "<label>"` / `--remove-label "<label>"`.
- **Close**: `backlog task edit <id> --final-summary "<text>"`, then `backlog task edit <id> -s Done`.
- **Needs a person**: assign `@human` (`backlog task edit <id> -a @human`). Agents never work `@human` tickets. Start an acceptance criterion with `HUMAN:` when only a person can verify it.

## When a skill says "publish to the issue tracker"

Create one task per ticket, blockers first, so each `--dep` can name a real ID. Status `To Do`. Map the ticket's "Blocked by" to `--dep`, its acceptance criteria to `--ac`, and keep the rest of the body as the description.

## When a skill says "fetch the relevant ticket"

Read it as in **Read an issue** above.

## Wayfinding operations

Used by `/wayfinder`. The **map** is one task with **child** tasks as tickets. All of them have status `Decision`, never `To Do`.

- **Map**: `backlog task create "<effort>" -s Decision -l wayfinder:map -d "<Notes / Decisions so far / Not yet specified / Out of scope body>"`.
- **Child ticket**: `backlog task create "<question>" -s Decision -p <map-id> -l wayfinder:<type> -d "<question body>"`, with `<type>` one of `research`, `prototype`, `grilling`, `task`.
- **Blocking**: native dependencies. Create the tickets first, then wire edges with `backlog task edit <child-id> --dep <blocker-id>`. A ticket is unblocked when every dependency is `Done`.
- **Frontier query**: `backlog task list -s Decision -p <map-id> --plain`. Drop tickets with an assignee and tickets with a dependency that is not `Done` (`backlog task <id> --plain` shows dependencies). The first in ID order wins.
- **Claim**: `backlog task edit <id> -a @<driving-dev>`, the session's first write.
- **Resolve**: `backlog task edit <id> --comment "<answer>"`, then `backlog task edit <id> -s Done`, then append a context pointer (gist and task ID) to the map's Decisions-so-far with `backlog task edit <map-id> -d "<updated body>"`.
