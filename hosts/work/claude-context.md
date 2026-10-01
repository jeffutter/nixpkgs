## git, gh and Atlassian CLIs run outside the sandbox only when bare

Settings exclude `git *`, `gh *`, `acli *`, `jira-axi *` and
`confluence-axi *` from the sandbox, but only when the whole command is a
single bare invocation. Commit signing (`ssh-keygen` reads `~/.ssh`),
`git push`, `gh`, and the Atlassian CLIs all depend on that.

- Never pipe, redirect, or loop these commands (`git commit ... | tail`,
  `gh api user > out.json`, `acli jira workitem view KEY > out.json`,
  `for ...; do gh ...; done`). Any of these runs the command sandboxed, even a
  lone `>` redirect to a file. Output can only come back as the tool result.
- Pass commit messages with `git commit -F <file>` (written under `$TMPDIR`),
  not a heredoc.
- Chain separate top-level calls with `;` instead of looping, but only
  excluded commands: `gh release view ...; java -version` runs sandboxed too.
- If signing fails (`Couldn't load public key`), `gh` says the token is
  invalid or fails TLS (`x509: OSStatus -26276`), push reports access rights,
  or `acli` says `failed to fetch work item details` / `command execution
  failed`, rerun the command bare before suspecting my credentials. Those
  errors are almost always this.
