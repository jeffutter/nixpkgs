# Code search

`zg` (zvec-grep) is installed with its index daemon running as a login
service. Pick the tool by what you know:

- A name (identifier, string, error text): `rg`. Never `grep -r`. List files
  with `rg --files -g '<glob>'` or `fd`. If the Grep and Glob tools are not in
  your tool list, do not call them or search for them, and do not tell
  subagents to use them.
- A code shape (every default export, every call with a given argument): the
  `ast-grep` skill.
- A behaviour you can describe but cannot name: run
  `zg query --vector "<one sentence describing the behaviour>" --limit 5`,
  then read the top hit's line range before citing it.

Run the semantic query, before any grep, when:

- The question is "where does X happen" or "how does X work" and you would
  otherwise guess identifiers (`retry`, `backoff`, `withRetry`, ...).
- A grep for a concept returned nothing, or only unrelated hits.
- You are about to spawn an Explore agent only to find where something lives.

Skip it when you already know the name or the file. Rephrase once at most,
then fall back to rg or ast-grep. Load the `zg` skill when `zg status` reports
no index, results include generated files, or you need its `--rg` mode.
