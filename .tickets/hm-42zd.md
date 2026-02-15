---
id: hm-42zd
status: closed
deps: []
links: []
created: 2026-02-15T01:37:24Z
type: task
priority: 3
assignee: Jeffery Utter
tags: [needs-plan, wontfix]
---
# Add hyprland/window to waybar modules-center

Current Waybar config (lines 104-206 in home.nix) has empty modules-center.

Suggested: Add  to show current window title. This is especially useful on a laptop where screen real estate is limited and you want to know what's focused.

Also verify battery icons are intentionally empty strings (rely on Stylix theming).

## Acceptance Criteria

- Add hyprland/window to modules-center
- Configure max-length to prevent overflow
- Test with various window types
- Verify styling with Tokyo Night theme

