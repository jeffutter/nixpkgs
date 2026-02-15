---
id: hm-zytq
status: open
deps: []
links: []
created: 2026-02-15T01:37:20Z
type: task
priority: 2
assignee: Jeffery Utter
tags: [planned]
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

## Design

All changes in `hosts/zenbook/home.nix` within the `wayland.windowManager.hyprland.settings` block.

### 1. Add explicit `general` section

Currently no `general {}` block exists. Add:

```nix
general = {
  layout = "dwindle"; # make default explicit for clarity
};
```

The `dwindle` and `master` sections are already configured; this just makes the active layout explicit.

### 2. Evaluate hardware cursor for Intel Meteor Lake

The zenbook uses Intel Meteor Lake iGPU (`i915.force_probe=7d45`). Meteor Lake's Xe LPG graphics can have hardware cursor glitches under Wayland. Add:

```nix
cursor = {
  no_hardware_cursors = true; # Intel Meteor Lake stability
};
```

**Decision needed at implementation time:** Test with hardware cursors enabled first. If no glitches observed, skip this change and add a comment explaining the decision instead.

### 3. Add `dwt` (disable-while-typing) to touchpad

Sway config has `dwt = "enabled"` but Hyprland is missing it. Add inside `input.touchpad`:

```nix
disable_while_typing = true;
```

### 4. Touchpad natural_scroll clarification

Both Hyprland (`natural_scroll = false`) and Sway (unset, defaults to false) agree: natural scroll is OFF at the compositor level. The system-level libinput config in `default.nix` has `naturalScrolling = true`, but compositor settings override it. Add a comment:

```nix
# natural_scroll intentionally false — compositor overrides system libinput default
natural_scroll = false;
```

### 5. Window swallowing — skip

Window swallowing (`misc.enable_swallow` + `swallow_regex`) is a niche feature that hides the terminal when a GUI app is launched from it. Skip unless explicitly requested — it adds complexity and can behave unexpectedly with terminal multiplexers.

### 6. Animation settings — leave as-is

Current minimal animations (workspace fade, window popin at speed 4) are a deliberate choice. Don't add complexity without a specific request.

### Implementation notes

- This ticket should be completed **before** hm-i416 (split home.nix into gui/ modules) since hm-i416 will move the Hyprland config to a new file
- Changes are small and self-contained (~5-10 lines added/modified)
- Requires testing on actual zenbook hardware to verify cursor and touchpad behavior
- Build with `~/bin/rebuild` and test interactively

