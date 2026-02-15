---
id: hm-zlc3
status: closed
deps: [hm-i416]
links: []
created: 2026-02-15T01:37:38Z
type: task
priority: 3
assignee: Jeffery Utter
tags: [planned]
---
# Simplify window rules with lib.genAttrs

Current window rules (lines 443-454 in home.nix) apply bordersize/rounding to multiple workspace types using manual list mapping:



This can be simplified using `lib.concatMap` and a shared workspace list for cleaner code.

## Design

### Approach

After hm-i416 completes (splitting home.nix into modules), the window rules will live in `hosts/zenbook/gui/hyprland.nix`. This ticket makes two focused changes within that file's `wayland.windowManager.hyprland.settings` block.

**Note:** `lib.genAttrs` (from the original title) produces attribute sets, not lists. The correct tool is `lib.concatMap`, which combines map + flatten into one idiomatic call.

### Changes

In `hosts/zenbook/gui/hyprland.nix` (or `hosts/zenbook/home.nix` if hm-i416 hasn't landed yet), within the Hyprland settings block:

1. **Extract a shared workspace type list** into a `let` binding to DRY up the duplicated list between `workspace` and `windowrulev2`:

```nix
let
  singleWindowWorkspaces = [
    "w[t1]"
    "w[tg1]"
    "f[1]"
  ];
in
```

2. **Rewrite `workspace`** to use the shared list:

```nix
workspace = map (x: "${x}, gapsout:0, gapsin:0") singleWindowWorkspaces;
```

3. **Replace `lib.lists.flatten (map ...)` with `lib.concatMap`** for `windowrulev2`:

```nix
windowrulev2 = lib.concatMap
  (x: [
    "bordersize 0, floating:0, onworkspace:${x}"
    "rounding 0, floating:0, onworkspace:${x}"
  ])
  singleWindowWorkspaces;
```

### What This Achieves

- **DRY**: Workspace type list defined once — adding a new workspace type requires one edit
- **Idiomatic**: `lib.concatMap` is the standard Nix pattern for map-then-flatten
- **No behavior change**: Produces identical output lists

### Verification

1. `nix flake check`
2. Optionally `~/bin/rebuild` on zenbook to confirm runtime behavior

### Risks

- None significant. This is a pure refactor producing identical output.
- If hm-i416 hasn't landed, the `let` binding must nest within the existing file's structure. If it has landed, the `let` block in `hyprland.nix` is the natural home.

## Acceptance Criteria

- Refactor to use lib.genAttrs or similar
- Maintain same functionality (no borders/rounding on specific workspaces)
- Verify with nix flake check

