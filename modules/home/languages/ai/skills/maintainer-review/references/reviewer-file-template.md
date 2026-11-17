# Reviewer file template

Template for `~/.config/maintainer-review/reviewer.md`. It holds one reviewer's own taste, the same for every project. The project's context file wins where they disagree. Every reviewer agent reads it, so keep each line a check an agent can apply to a diff.

```markdown
# My review preferences

## Always check
- <A check you want on every review, for example "a new config option needs a named caller">

## Prefer
- <Patterns you favour, for example "one complete function over several that share hidden state">

## Push back on
- <Patterns you ask contributors to change, for example "comments that describe the change history">

## Skip
- <Things you do not want flagged, for example "import order">
```
