---
id: hm-zytq
status: open
deps: []
links: []
created: 2026-02-15T01:37:20Z
type: task
priority: 2
assignee: Jeffery Utter
tags: [needs-plan]
---
# Hyprland configuration refinements

Review and improve Hyprland settings in hosts/zenbook/home.nix:

Suggested improvements:
1. Add explicit  for clarity
2. Add  for Intel GPU stability (Meteor Lake)
3. Review animation settings - currently minimal
4. Consider adding window swallowing for terminal apps
5. Review touchpad settings - natural_scroll is false but GNOME setting has it true

Current Hyprland config spans lines 302-468 in home.nix.

## Acceptance Criteria

- Add explicit layout setting
- Evaluate hardware cursor setting for stability
- Review and document touchpad configuration choices
- Test changes on actual hardware

