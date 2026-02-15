---
id: hm-zlc3
status: open
deps: [hm-i416]
links: []
created: 2026-02-15T01:37:38Z
type: task
priority: 3
assignee: Jeffery Utter
tags: [needs-plan]
---
# Simplify window rules with lib.genAttrs

Current window rules (lines 443-454 in home.nix) apply bordersize/rounding to multiple workspace types using manual list mapping:



This can be simplified using  for cleaner code.

## Acceptance Criteria

- Refactor to use lib.genAttrs or similar
- Maintain same functionality (no borders/rounding on specific workspaces)
- Verify with nix flake check

