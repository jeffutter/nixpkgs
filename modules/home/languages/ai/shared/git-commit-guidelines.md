# Git Commit Message Guidelines

When writing commit messages, follow these principles:

## Structure
- **Subject line**: Clear, imperative mood (50-72 chars) - "Add feature" not "Added feature"
- **Body**: Explain what and why, not how (wrapped at 72 chars)
- **Blank line** between subject and body

## Writing Style
- Clear, analytical, and technical without unnecessary verbosity
- Explain the "why" behind changes, not just the "what"
- Use active, imperative voice
- Avoid corporate speak ("leverage", "utilize"), hedging ("kind of", "basically"), and passive voice

## What to Include
- Performance numbers if measured: "reduces latency by 40%"
- Breaking changes: "BREAKING: removes deprecated X API"
- Migration requirements if applicable
- Architecture shifts: "moves from polling to event-driven"
- Bug identifiers: "fixes issue where X caused Y"

## Examples

Good:
- "Fix race condition in cache invalidation by introducing write-through semantics"
- "Add retry logic with exponential backoff to handle transient network failures"
- "Refactor authentication middleware to separate concerns between authN and authZ"

Avoid:
- "Fixed some bugs in the cache"
- "Made improvements to the auth system"
- "Updated code to be better"

## Remember
Write for the engineer reviewing code history six months from now. They're technical, time-constrained, and appreciate clarity over cleverness.
