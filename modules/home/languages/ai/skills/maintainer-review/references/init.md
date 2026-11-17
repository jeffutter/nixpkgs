# Init mode

With `init personal`, skip to section "Reviewer file".

End state: the context file at `MAIN/.github/maintainer-review.md` has content the user has approved. You do not commit it.

`MAIN` and `DEFAULT` are defined in `SKILL.md` under "Locations". Resolve them with git first.

1. Run `git show DEFAULT:.github/maintainer-review.md`. When it succeeds, you will fill gaps in that content, not replace it.
2. Read the project docs listed in step 1 of `references/agents/context.md`, from `MAIN`. Also read `MAIN/.gitattributes`, and look for codegen config to fill the generated globs.
3. Read `references/context-file-template.md`. Draft each section from what the docs say. Cite the source file for each item in your notes to the user, not in the file.
4. List the sections that the docs do not answer: usually Direction, Non-goals, Never accept, and Stable public surface. Ask the user about all of them in one message. Give a proposed answer for each from what you read.
5. Write the file to `MAIN/.github/maintainer-review.md` with the user's answers. Show it to the user. Tell them that reviews read it from `DEFAULT`, so it takes effect after they commit it and it merges there.

## Reviewer file

End state: `~/.config/maintainer-review/reviewer.md` has content the user has approved.

1. Read the file if it exists. You will add to it, not replace it. When it is a symlink into `/nix/store`, a config manager owns it: write your draft to `/tmp/maintainer-review-reviewer.md` and tell the user to copy it into their config source.
2. Read `references/reviewer-file-template.md`.
3. Ask the user, in one message, what they always check, prefer, push back on and want skipped. Propose items from the review comments they wrote, when a `WORK/report.md` or `WORK/review-body.md` exists under `GITDIR/maintainer-review/`.
4. Write the file with the user's answers and show it.
