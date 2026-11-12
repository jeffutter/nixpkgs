# Context file template

Template for `.github/maintainer-review.md`. Keep each section short. Every line is something a reviewer cannot learn from the code.

```markdown
# Maintainer review context

## Direction
<Where the project is going in the next 1-2 years. What kinds of change we want.>

## Non-goals
- <Things the project will not do, even if someone sends a good PR for them.>

## Stable public surface
- <APIs, CLI flags, config keys, file or wire formats, extension points we promise to keep.>

## Never accept
- <Specific patterns or dependencies we always reject, with the reason.>

## Conventions not written elsewhere
- <Patterns, layering rules, preferred libraries.>

## Ownership
- <Area> - <owner or team>

## Generated code
generated:
  - <glob>
max_changed_lines: <number, or delete this line for no limit>

## Other docs to read
- <path> - <what it covers>

## Decisions
<Answers to direction questions from earlier reviews. One line each, with the date.>
```
