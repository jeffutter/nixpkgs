---
id: hm-grgg
status: open
deps: []
links: []
created: 2026-02-15T01:37:22Z
type: task
priority: 2
assignee: Jeffery Utter
tags: [needs-plan]
---
# Add dim before lock in swayidle configuration

Current swayidle (lines 664-691 in home.nix) goes directly from screen active to locked after 120s.

Suggested improvement: Add a dim step before locking for smoother UX:
- At 110s: dim screen to 10% brightness
- At 120s: lock screen (existing)
- Resume: restore brightness

This provides visual feedback that idle timeout is approaching.

## Acceptance Criteria

- Add dim timeout step before lock
- Add brightness restore on resume
- Verify brightnessctl commands work with iio_ambient_brightness

