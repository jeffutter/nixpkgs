STRUCTURE:
- Subject line: Clear summary in imperative mood (50-72 chars)
- Blank line
- Body paragraphs (wrapped at 72 chars):
  * What changed and why
  * Technical rationale and architecture considerations
  * Trade-offs, performance implications, or migration notes
  * Related issues/tickets if applicable

Example structure:
```
Refactor GraphQL federation schema composition

Previous approach composed schemas at runtime, introducing 200ms+
overhead on cold starts. New approach pre-composes schemas during
build phase and caches the result.

Key changes:
- Move schema composition to build-time codegen
- Add schema validation in CI pipeline
- Implement cached schema loading with TTL

Trade-offs:
- Requires rebuild to update federated schema
- Increases build time by ~30 seconds
- Reduces runtime composition overhead to zero

Closes #234
```
