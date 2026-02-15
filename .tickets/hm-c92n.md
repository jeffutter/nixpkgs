---
id: hm-c92n
status: closed
deps: [hm-i416]
links: []
created: 2026-02-15T01:37:36Z
type: task
priority: 2
assignee: Jeffery Utter
tags: [planned]
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

## Design

### Approach

Create a new `hosts/zenbook/gui/keybindings.nix` module that defines a shared keybinding data structure and provides two generator functions — one for Hyprland format (ydotool) and one for Sway format (wtype). Both `gui/hyprland.nix` and `gui/sway.nix` import and use the generated lists directly.

This runs after hm-i416 splits home.nix into gui/ modules.

### Shared Data Structure

Define keybindings as a list of attrsets in a `let` block:

```nix
# Each binding: { mods, key, action }
# mods: list of modifier strings, e.g. ["ctrl"] or ["ctrl" "shift"]
# key: the key name as a lowercase letter, e.g. "x", "c", "v"
macosBindings = [
  { mods = ["ctrl"]; key = "x"; description = "Cut"; }
  { mods = ["ctrl"]; key = "c"; description = "Copy"; }
  { mods = ["ctrl" "shift"]; key = "c"; description = "Copy (shift)"; }
  { mods = ["ctrl"]; key = "v"; description = "Paste"; }
  { mods = ["ctrl" "shift"]; key = "v"; description = "Paste (shift)"; }
  { mods = ["ctrl"]; key = "z"; description = "Undo"; }
  { mods = ["ctrl"]; key = "a"; description = "Select All"; }
  { mods = ["ctrl"]; key = "f"; description = "Find"; }
  { mods = ["ctrl"]; key = "p"; description = "Print"; }
  { mods = ["ctrl"]; key = "s"; description = "Save"; }
  { mods = ["ctrl"]; key = "t"; description = "New Tab"; }
  { mods = ["ctrl" "shift"]; key = "t"; description = "Reopen Tab"; }
  { mods = ["ctrl"]; key = "w"; description = "Close Tab"; }
  { mods = ["ctrl"]; key = "r"; description = "Reload"; }
  { mods = ["ctrl"]; key = "l"; description = "Select URL"; }
  { mods = ["ctrl"]; key = "y"; description = "History"; }
];
```

The `mods` field describes what the binding *sends* (ctrl, ctrl+shift), not the trigger key. The trigger is always ALT (+ SHIFT if shift is in mods) plus the `key`.

### Generator Functions

**ydotool keycode map** — a lookup attrset mapping key names to Linux input event codes:

```nix
keycodes = {
  ctrl = 29; shift = 42;
  a = 30; c = 46; f = 33; l = 38; p = 25; r = 19;
  s = 31; t = 20; v = 47; w = 17; x = 45; y = 21; z = 44;
};
```

**`toHyprland`**: Takes a binding and produces a Hyprland `bind` string. The trigger modifier is `"ALT"` (plus `" SHIFT"` if `shift` is in mods). The command uses ydotool with keycode press/release pairs.

**`toSway`**: Takes a binding and produces a `{ name = "..."; value = "..."; }` pair for `builtins.listToAttrs`. Trigger is `"${modifier}+key"` (plus `"+Shift"` if shift is in mods). Command uses wtype with `-M`/`-P` flags.

### Module Structure

`hosts/zenbook/gui/keybindings.nix` exports via the Nix module system:

```nix
{ lib, pkgs, config, ... }:
let
  # shared data + generators defined here
in {
  # Provide generated bindings as options or config
  wayland.windowManager.hyprland.settings.bind =
    map toHyprland macosBindings;

  wayland.windowManager.sway.config.keybindings =
    lib.mkOptionDefault (builtins.listToAttrs (map toSway macosBindings));
}
```

This keeps it as a single home-manager module that sets both WM configs. Both `hyprland.nix` and `sway.nix` no longer define these bindings — the module system merges them.

### Bug Fix

The current Sway History binding sends `wtype -M ctrl -P h` but should send `wtype -M ctrl -P y` to match the Hyprland binding. The shared definition fixes this by generating both from the same source.

### Files Changed

| File | Change |
|---|---|
| `hosts/zenbook/gui/keybindings.nix` | **New** — shared binding definitions + generators |
| `hosts/zenbook/home.nix` | Add `./gui/keybindings.nix` to imports |
| `hosts/zenbook/gui/hyprland.nix` | Remove 16 macOS-style `bind` entries (ydotool lines) |
| `hosts/zenbook/gui/sway.nix` | Remove 16 macOS-style keybinding entries (wtype lines) |

### Non-Goals

- Workspace switching, focus movement, window movement, media keys, and screenshot bindings are NOT extracted. These have different semantics between WMs (different dispatcher names, different argument formats) and aren't simple key-remapping. They share intent but not structure.
- Only the macOS-style "Alt triggers Ctrl+letter" bindings are unified, since these follow an identical pattern differing only in the typing tool.

### Verification

1. `nix flake check` — confirms no syntax errors
2. Compare generated output: temporarily add `builtins.trace` to verify the generated binding lists match the originals
3. `~/bin/rebuild` on zenbook to confirm runtime behavior

### Risks

- **ydotool keycode correctness**: The keycode map must be verified against current values. Source of truth is the existing working bindings in home.nix.
- **Module merge order**: home-manager merges list options (bind) by concatenation and attrset options (keybindings) by merging. Both are safe for additive-only changes.

## Acceptance Criteria

- Define shared keybinding configuration
- Generate Hyprland bindings from shared config
- Generate Sway bindings from shared config
- Document the binding mapping


## Notes

**2026-02-15T21:28:45Z**

Preserved original bindle (repeating) binding type from Hyprland config — code reviewer suggested bind instead, but original intentionally used bindle. Also fixed Sway History binding bug (was -P h, now -P y) and used plain attrset (not mkOptionDefault) for Sway keybindings to match style in sway.nix.
