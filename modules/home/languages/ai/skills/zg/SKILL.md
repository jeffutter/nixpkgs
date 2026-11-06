---
name: zg
description: Search code with zg (zvec-grep) - semantic search for a behaviour you can describe but cannot name, exhaustive ripgrep that reports the enclosing function, and creating or repairing a repo's zg index with generated code excluded. Use when asked where or how something happens and you do not know the identifier, when a grep for a concept finds nothing useful, before spawning an Explore agent only to locate code, and whenever `zg --status` reports no index or results include generated files. Skip it when you already know the name or file.
---

Use the zg CLI, not its MCP server. The daemon it talks to runs as a login service (launchd on macOS, systemd user service on Linux); `zg --server status` confirms it is up.

zg 0.3 management commands take a `--` prefix (`--status`, `--index`, `--server`, `--rg`). A bare word is search text, so `zg status` searches for the word "status".

## Choose the mode

1. You know an identifier, string, or error text: use grep or `rg`. zg adds nothing.
2. You know the code shape: use the `ast-grep` skill.
3. You can describe the behaviour but not name it: semantic search, below.
4. You want every match plus the enclosing function or heading: `zg --rg <pattern> [path]`. It is ripgrep with symbol context. It rejects flags that change rg's output (`-l`, `-c`, `--json`, `-o`).

## Semantic search

1. Run `zg --vector "<one sentence describing the behaviour>" --limit 5`. Keep the default output (`--preview short`); it lists path, line range, symbol and a few source lines per hit. `--preview detail` is much larger.
2. Read the range of the top hit with the Read tool. Do not cite a hit you have not read.
3. Wrong file: rephrase once using words a maintainer would put in a comment. Still wrong: stop and use `rg` or ast-grep. Small undocumented object literals are invisible to semantic search; ast-grep finds them by shape.
4. Results that are only docs headings mean the code has no prose near it. Open the doc hit; it usually names the module.

## Create a repo's index

1. Run `zg --status`. `Coverage    Unavailable (index not configured)` means no index. Otherwise read the saved exclusions with `jq -r '.scan.globs[].pattern' .zvec-grep/manifest.json` (run from the repo root). Stop here if that list already excludes the generated paths.
2. List generated or vendored paths that are committed: read the repo's CLAUDE.md or contributing docs for "generated", "do not edit", and codegen output. `.gitignore`d paths are already excluded.
3. Run `zg --index -g '!<path>/**'` with one `-g` per path. Do not pass `--embedding`; `ZVEC_GREP_EMBEDDING` sets the model. The first build on a repo takes minutes.
4. Confirm with a query for a token that exists only in generated code; no generated file may appear.
5. A root `.ignore` file also excludes paths from both the indexer and `--rg`, and unlike `-g` it is a file in the repo. Use it only when the repo wants those paths skipped by every rg-based tool.

## Rebuild or change exclusions

- `zg --index --rebuild` keeps the stored model and the glob list.
- Any `-g` on an index run replaces the whole glob list. Read the current list from `.zvec-grep/manifest.json` as above and pass every entry again plus the new one. `--reset-paths` clears the saved scan rules.
- The index refreshes in the background while the daemon runs. `zg --status` shows `updating` until it settles; a query during that window reads the previous snapshot.
