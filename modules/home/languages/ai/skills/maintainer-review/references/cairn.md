# Publish to cairn

Read this file only when `cairn` is in your list of available skills. These commands are enough; load the cairn skill only to read or answer the user's Comments.

`WORK/cairn.md` records each published file: one line `<file> <artifact id> <revision>`. Create it on first use.

To publish `<file>` (a path inside `WORK`):

1. Figures first. For each `fig-<n>.png` the file references:
   - Publish the PNG with these same steps, so it has an artifact id.
   - Write `WORK/<file stem>-cairn.md`: a copy of the file with each `](fig-<n>.png)` replaced by `](cairn:<id>)`. cairn does not upload local file paths. Publish that copy in place of the original. With no figures, publish the original.
2. If `WORK/cairn.md` has no line for `<file>`: run `cairn submit <path> --name "<name>"`. Use the names below.
3. If it has a line: run `cairn edit <id> <path> --base <revision>`. On exit code 6, run it again without `--base`.
4. Each command prints JSON with `id` and `revision`. Update the file's line in `WORK/cairn.md`.
5. Run `cairn view <id>` to get the link.

Names:

- `report.md`: "Maintainer review: <PR number or branch>"
- `review-preview.md`: "Draft PR review: <PR number>"
- `fig-<n>.png`: "<PR number or branch> fig-<n>.png". Keep the `.png` ending: cairn reads the media type from the name and rejects an image name without it.

If any cairn command fails for another reason, stop publishing, say so in one line, and continue the mode without cairn.

When you show the link, add: "It loads while `cairn serve` runs in a terminal. Comment there and tell me to read the comments."
