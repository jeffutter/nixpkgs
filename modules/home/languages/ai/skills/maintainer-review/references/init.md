# Init mode

End state: `.github/maintainer-review.md` exists in the working tree with content the user has approved. You do not commit it.

1. If `.github/maintainer-review.md` exists, read it. You will fill gaps in it, not replace it.
2. Read the project docs listed in step 1 of `references/agents/context.md`, from the working tree. Also read `.gitattributes`, and look for codegen config to fill the generated globs.
3. Read `references/context-file-template.md`. Draft each section from what the docs say. Cite the source file for each item in your notes to the user, not in the file.
4. List the sections that the docs do not answer: usually Direction, Non-goals, Never accept, and Stable public surface. Ask the user about all of them in one message. Give a proposed answer for each from what you read.
5. Write the file with the user's answers. Show it to the user and tell them to review and commit it.
