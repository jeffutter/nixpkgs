---
id: hm-dob9
status: open
deps: []
links: []
created: 2026-02-15T01:37:26Z
type: task
priority: 2
assignee: Jeffery Utter
tags: [needs-plan]
---
# Document DPI scaling variables in default.nix

The environment variables in hosts/zenbook/default.nix (lines 188-194) for DPI scaling appear tuned for the OLED display:
- GDK_SCALE=2.2
- GDK_DPI_SCALE=0.4  
- _JAVA_OPTIONS=-Dsun.java2d.uiScale=2.2
- QT_AUTO_SCREEN_SCALE_FACTOR=1
- XCURSOR_SIZE=48

These values should be documented with comments explaining:
1. Why these specific values were chosen
2. Relationship to display resolution
3. How to adjust if needed

## Acceptance Criteria

- Add comments explaining each scaling variable
- Document display resolution that these target
- Note any trade-offs or issues with other values

