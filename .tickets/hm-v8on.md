---
id: hm-v8on
status: open
deps: []
links: []
created: 2026-02-15T01:37:30Z
type: task
priority: 3
assignee: Jeffery Utter
tags: [needs-plan]
---
# Clean up unused code and configurations in zenbook

Several items in zenbook config appear unused or need review:

1. Lines 470-661: Sway config is substantial (~190 lines) but Hyprland is primary WM - Remove sway config
2. Line 14: zenbrowser is defined in let but also imported via inputs
3. Check if iio_ambient_brightness properly handles all edge cases

## Acceptance Criteria

- Review Sway configuration
- Remove unused let bindings
- Check for other dead code

