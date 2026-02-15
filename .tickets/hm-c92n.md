---
id: hm-c92n
status: open
deps: [hm-i416]
links: []
created: 2026-02-15T01:37:36Z
type: task
priority: 2
assignee: Jeffery Utter
tags: [needs-plan]
---
# Extract common keybindings between Hyprland and Sway

Both Hyprland and Sway configurations define identical macOS-style keybindings using different tools (ydotool vs wtype):
- Copy: Alt+X/C/V
- Select All: Alt+A
- Find: Alt+F
- Print: Alt+P
- Save: Alt+S
- Chrome tabs: Alt+T/W
- Reload: Alt+R
- History: Alt+Y

Currently these are duplicated and maintained separately in both WM configs.

Create a shared attrset of bindings that generates both Hyprland and Sway configurations.

## Acceptance Criteria

- Define shared keybinding configuration
- Generate Hyprland bindings from shared config
- Generate Sway bindings from shared config
- Document the binding mapping

