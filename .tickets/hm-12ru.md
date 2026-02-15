---
id: hm-12ru
status: closed
deps: []
links: []
created: 2026-02-15T01:37:28Z
type: task
priority: 3
assignee: Jeffery Utter
tags: [planned]
---
# Create waylandWrapper helper for Electron app wrappers

Current home.nix (lines 737-752) has two nearly identical Electron app wrapper scripts:
- bin/discord
- bin/obsidian

Both set Ozone/Wayland flags. Create a reusable  function to reduce duplication and make it easier to add more wrapped apps.

Example pattern:


## Design

### Approach: `let`-bound helper function returning `home.file` attrset

Define `waylandWrapper` in the existing `let` block of `hosts/zenbook/home.nix` (alongside `my_zoom`, `my_bemoji`, `my_todoist`). The helper returns the `{ text = ...; executable = true; }` attrset that `home.file."bin/<name>"` expects.

### Why shell-script wrapper (not `symlinkJoin`/`wrapProgram`)

The discord and obsidian wrappers both call `~/bin/systemGL` at runtime for GPU interop. This is a runtime path, not a Nix store path, so `wrapProgram --add-flags` can't handle it. A shell script is the right pattern here (consistent with current approach).

### Helper function signature

```nix
waylandWrapper = { pkg, bin ? null, extraFlags ? "", extraEnv ? "" }:
  let
    binName = if bin != null then bin else pkg.pname or pkg.name;
  in {
    text = ''
      #!${pkgs.bash}/bin/bash
      ${extraEnv}
      exec -a "$0" ~/bin/systemGL ${pkg}/bin/${binName} --ozone-platform=wayland --ozone-platform-hint=auto --enable-features=UseOzonePlatform,WaylandWindowDecorations ${extraFlags} "$@"
    '';
    executable = true;
  };
```

Parameters:
- `pkg` (required): The Nix package (e.g., `pkgs.discord`)
- `bin` (optional): Binary name override, defaults to `pkg.pname`
- `extraFlags` (optional): Additional CLI flags appended after defaults
- `extraEnv` (optional): Environment variable exports prepended to exec line

### Refactored call sites

```nix
home.file."bin/discord" = waylandWrapper { pkg = pkgs.discord; };

home.file."bin/obsidian" = waylandWrapper {
  pkg = pkgs.obsidian;
  extraEnv = "export OBSIDIAN_USE_WAYLAND=1";
};
```

### Default flags rationale

Unify on the superset of Ozone flags (`--ozone-platform=wayland --ozone-platform-hint=auto --enable-features=UseOzonePlatform,WaylandWindowDecorations`). Discord's current flags are a subset; the additional flags are harmless and ensure consistent behavior.

### Implementation steps

1. Add `waylandWrapper` function to `let` block (after `my_todoist`, before `in`)
2. Replace `home.file."bin/discord"` definition with `waylandWrapper { pkg = pkgs.discord; }`
3. Replace `home.file."bin/obsidian"` definition with `waylandWrapper { pkg = pkgs.obsidian; extraEnv = "export OBSIDIAN_USE_WAYLAND=1"; }`
4. Verify `pname` resolves correctly for both packages (check with `nix eval`)
5. Build and test: `nix build .#homeConfigurations.zenbook.activationPackage` or equivalent

### Notes

- `my_todoist` already uses `symlinkJoin`/`wrapProgram` pattern (no `systemGL`), so it stays as-is
- If `hm-i416` (split home.nix into modules) is done first, the helper would live in the new `gui/apps.nix`. Either order works; the helper moves cleanly.

## Acceptance Criteria

- Create waylandWrapper helper function
- Refactor discord wrapper to use helper
- Refactor obsidian wrapper to use helper
