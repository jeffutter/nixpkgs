# Init mode

End state: the context file at `MAIN/.github/maintainer-review.md` has content the user has approved. You do not commit it.

`MAIN` and `DEFAULT` are defined in `SKILL.md` under "Locations". Resolve them with git first.

1. Run `git show DEFAULT:.github/maintainer-review.md`. When it succeeds, you will fill gaps in that content, not replace it.
2. Read the project docs listed in step 1 of `references/agents/context.md`, from `MAIN`. Also read `MAIN/.gitattributes`, and look for codegen config to fill the generated globs.
3. Read `references/context-file-template.md`. Draft each section from what the docs say. Cite the source file for each item in your notes to the user, not in the file.
4. List the sections that the docs do not answer: usually Direction, Non-goals, Never accept, and Stable public surface. Ask the user about all of them in one message. Give a proposed answer for each from what you read.
5. Write the file to `MAIN/.github/maintainer-review.md` with the user's answers. Show it to the user. Tell them that reviews read it from `DEFAULT`, so it takes effect after they commit it and it merges there.
