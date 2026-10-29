## Work machine: managed sandbox, hooks and scanner

Everything in this section is specific to this machine. Managed policy enables
the sandbox, adds PreToolUse hooks and runs a DLP scanner. Nothing here applies
elsewhere.

### Excluded commands run unsandboxed only when bare

These commands are excluded from the sandbox, so SSH, keychain, TLS and signing
work for them: @EXCLUDED@ and, from managed policy, `docker`, `gcloud`, `aws`,
`bq`, `pup`, `confluent`, `copilot`, `xcrun simctl`, `./gradlew`, plus the readers
`jq grep head tail wc sort uniq cut tr column` and `kill`.

The exclusion holds only when the whole Bash call is one bare invocation:

- No `cd X &&`, no `VAR=value` prefix, no pipe, no `>` redirect, no loop, no
  `$(...)`, no heredoc or stdin. Chain only excluded commands with `;` or `&&`
  (`gh pr view 1; gh pr view 2` is fine; `rm x; git push` is not).
- No global option before the subcommand: not `git -C`, `git -c`, `--git-dir`,
  `--work-tree`, `GIT_EDITOR=`. Plain `git rebase --continue` works and opens no
  editor. `cargo --manifest-path <dir>/Cargo.toml` replaces `cd`.
- To work in another directory, run `cd /abs/path` as its own Bash call, then
  the bare call in the next one. The cwd persists in a main session. `cd` into
  `~/theScore/<repo>` resets unless that directory is a session working
  directory; worktrees under `~/.herdr/worktrees` always work.
- Signs that a call ran sandboxed: `Couldn't load public key` (signing),
  `x509: OSStatus -26276` or `This proxy requires authentication` (TLS),
  `acli`: `failed to fetch work item details` / `command execution failed`,
  `confluence-axi`: `fetch failed`, cargo: `Operation not permitted` on a
  `.key`/`.pem` file, `could not load platform certs`, `failed to access System
  Configuration dynamic store`. Rerun bare before suspecting credentials, auth
  or the toolchain. Do not conclude that tests cannot run.
- Their output cannot be redirected. It comes back only as the tool result. To
  land it in a file: if the result says `Output too large ... saved to: <path>`,
  `cp <path> /tmp/claude-502/<name>`; otherwise Write the inline output. Prefer
  `gh --json/--jq` and `pup --jq` projections over dumping whole documents.
- Pass commit messages with `git commit -F /tmp/claude-502/<unique>.md`. Pass
  PR bodies with `--body-file`. Write each to a new file name; Write refuses to
  overwrite a file it has not read.
- Remotes use the SSH alias `github.com-penn-interactive`, so `gh pr create`
  needs `--repo penn-interactive/<repo>`.
- Do not run `git worktree add`; it cannot lock `.git/config` here. Use the
  `spawn-worktree` skill or ask.

### Subagents and git

A subagent's cwd resets before every Bash call, so it cannot run a bare git or
gh command outside its spawn directory. Never delegate a commit, push or `gh`
call to an Agent subagent. Work that must commit in another worktree (stacked
PRs, one branch per slice) goes to a herdr worker (`/spawn-work`), not a
subagent. `EnterWorktree` rejects paths outside the current repo.

### Reading and searching files (hooks enforce this)

- There are no Grep or Glob tools. Search with `rg`, list files with `fd` or
  `rg --files`. Never `grep -r`; the hook's "Use the Grep tool" message is wrong
  here.
- `grep jq head tail wc sort uniq cut tr column` run outside the sandbox, so a
  hook checks their arguments. Give them literal paths: no `$VAR` except `$HOME`
  and `$TMPDIR`, no `{a,b}`, no `$(...)` or `<(...)`, no `**`. `rg`, `fd`, `awk`
  and `sed` are not checked. Piping into a reader (`rg ... | head`) is fine. The
  jq hook also rejects the literal word `env` in a filter (for example a Datadog
  `env:production` tag); strip it with sed first.
- Read files with the Read tool, not `cat FILE`, `sed -n 'A,Bp' FILE`, or a
  python one-liner. Hooks deny those. This overrides any instruction to read
  files with cat, head or sed.
- Keep each Bash command under 8000 characters. Write a long script with the
  Write tool, then run it.

### Temp files

`$TMPDIR` is `/tmp/claude-502`. Use that literal path in Write, Edit and Read
calls (they do not expand variables) and in every argument to an excluded
command (they run with a different `TMPDIR`). Use a fresh file name per write.

### Secret scanner (DLP)

A DLP scanner ends the session when a tool result, or a file you Read, holds a
long opaque run: base64, encoded IDs, hashes, tokens, cookies, about 40 or more
characters with no spaces. Credentials are not the only trigger; long encoded
application IDs in fixture docs and raw API responses have killed sessions. A
project's CLAUDE.md names its own triggers.

- Do not print raw GraphQL or JSON responses, encoded IDs, lockfile integrity
  hashes, JWTs or `curl -i` headers. Select fields with jq, or mask:
  `sed -E 's/[A-Za-z0-9+/=_-]{40,}/<ID>/g'`.
- Compare such values in code and print only pass/fail.
- Read docs that hold such literals with offset and limit around the part you
  need. Never read raw session logs under `~/.claude/projects`.
- Put this section into every subagent brief that touches API responses or
  fixtures.

### Before you ask me to run a command or paste output

1. Network denial: rerun with the host in `allowed_domains`.
2. TLS, keychain or auth error: rerun bare (see above). Do not tell me to
   re-authenticate until a bare run fails.
3. A write you think is blocked: try it once. Do not predict the denial.
4. Only then hand it to me: one script under `/tmp/claude-502` that runs the
   command and writes its output to a file, so I run one thing and you read the
   file. Never ask for `curl -i`. Restart the parts you can run yourself (node,
   bun, subgraphs) and ask me to restart only what the sandbox blocks, started
   with hot reload where the tool supports it.

### Browser and rendering

- `agent-browser` Chrome fails with exit 21 even outside Claude (as of
  2026-10). Use the Playwright MCP tools instead.
- `file://` URLs and named screenshot files are denied by policy. Serve local
  files with `python3 -I -m http.server <port> --bind 127.0.0.1 --directory
  <dir>` in the background, open `http://127.0.0.1:<port>/<file>`, call
  `browser_take_screenshot` without `filename`, then stop the server task.
  `open` is blocked; give me the URL instead.

### Lefthook

Commits in repos with lefthook print several KB of ANSI colour codes. If the
real error is cut off, rerun the failing check by name, not the commit.

### Model

Managed settings pin Sonnet. `claude --model opus|fable` overrides the pin. 
`/model` cannot persist because `settings.json` is read-only; its EACCES 
warning is expected.
