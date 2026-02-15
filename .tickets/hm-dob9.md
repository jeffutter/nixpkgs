---
id: hm-dob9
status: closed
deps: []
links: []
created: 2026-02-15T01:37:26Z
type: task
priority: 2
assignee: Jeffery Utter
tags: [planned]
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

## Design

### Approach
Documentation-only change. Add inline comments to the `environment.variables` block in `hosts/zenbook/default.nix` explaining each DPI scaling variable.

### Target File
`hosts/zenbook/default.nix` lines 188-194

### Current State
```nix
environment.variables = {
  GDK_SCALE = "2.2"; # default 1 I think
  GDK_DPI_SCALE = "0.4"; # default 1 I think
  _JAVA_OPTIONS = "-Dsun.java2d.uiScale=2.2"; # default 1 I think
  QT_AUTO_SCREEN_SCALE_FACTOR = "1";
  XCURSOR_SIZE = "48";
};
```

### What to Document

Add a block comment above the `environment.variables` block explaining:
- These are tuned for the Zenbook OLED display (2880x1800, ~255 DPI based on existing X11 DPI setting on line 95)
- The 2.2x scaling factor rationale

Then document each variable inline:
1. **GDK_SCALE = "2.2"** — Scales GTK3/4 application UI by 2.2x for the high-DPI OLED panel. Default is 1.
2. **GDK_DPI_SCALE = "0.4"** — Compensates for GDK_SCALE on font rendering. GDK_SCALE * GDK_DPI_SCALE ≈ 0.88, preventing double-scaling of text. Default is 1.
3. **_JAVA_OPTIONS = "-Dsun.java2d.uiScale=2.2"** — Java/AWT/Swing UI scaling to match GTK scale factor. Default is 1.
4. **QT_AUTO_SCREEN_SCALE_FACTOR = "1"** — Enables Qt's automatic DPI detection; Qt calculates its own scale from system DPI. Default is 0 (disabled).
5. **XCURSOR_SIZE = "48"** — Cursor size in pixels; 2x the standard 24px default to remain visible at high DPI.

### Important Finding: GDK_SCALE Conflict

Research revealed that `hosts/zenbook/home.nix` (Hyprland env config, ~line 318) sets `GDK_SCALE,1`, which overrides the system-level `GDK_SCALE=2.2` from default.nix within the Hyprland session. This should be noted in the documentation comment — the system-level GDK_SCALE may only affect non-Hyprland sessions (e.g., Sway, or TTY-launched GTK apps). Consider adding a comment noting this override.

### Verification
- `nix flake check` (comments shouldn't affect build, but verify no syntax errors)
- Visual review of the comments for accuracy

## Acceptance Criteria

- Add comments explaining each scaling variable
- Document display resolution that these target
- Note any trade-offs or issues with other values

