---
id: hm-v8on
status: open
deps: []
links: []
created: 2026-02-15T01:37:30Z
type: task
priority: 3
assignee: Jeffery Utter
tags: [planned]
---
# Clean up unused code and configurations in zenbook

Several items in zenbook config appear unused or need review:

1. Lines 470-661: Sway config is substantial (~190 lines) but Hyprland is primary WM - Remove sway config
2. Line 14: zenbrowser is defined in let but also imported via inputs
3. Check if iio_ambient_brightness properly handles all edge cases

## Design

### Research Findings

Investigation revealed that the original ticket items need revision:

1. **Sway config removal**: More complex than expected. `programs.sway.enable = true` is still active in `hosts/zenbook/default.nix` (line 111), while `programs.hyprland.enable` is commented out (line 112). Sway is actually the registered GDM session. Several Sway-only features (mako notifications, bemoji emoji input, sunset color temperature) are NOT configured for Hyprland, meaning switching fully to Hyprland would lose functionality.

2. **zenbrowser "duplication"**: Not actually duplicated. The let binding (line 14) correctly resolves the flake input to a package — this is standard Nix idiom. No action needed.

3. **iio_ambient_brightness edge cases**: The `$(pkill ...)` subshell wrapping is unnecessary but harmless. No real edge case issues.

### Actual Cleanup Items Found

| Item | File | Lines | Risk | Action |
|------|------|-------|------|--------|
| Commented-out claude-desktop | home.nix | 10, 84 | Very low | Remove dead comments |
| Waybar `sway/mode` widget | home.nix | 118, 145-147 | Very low | Remove (no-op under Hyprland) |
| Commented-out Waybar lines | home.nix | 149, 163, 169-170, 180 | Very low | Remove dead comments |
| Commented-out i3status hueshift | home.nix | 290 | Very low | Remove dead comment |
| swayidle DPMS uses `swaymsg` | home.nix | 686-689 | Low | Replace with `hyprctl dispatch dpms off/on` |

### Approach

This is a focused cleanup of clearly dead code — commented-out lines and Hyprland-incompatible Waybar config. The swayidle DPMS fix is a bug fix (uses `swaymsg` but checks for `hyprlock`).

**Explicitly out of scope:**
- Sway removal — requires a user decision about WM strategy and is entangled with hm-i416's split plan. If Sway should be removed, create a separate ticket.
- Adding missing Hyprland exec-once entries (mako, sunset) — these are enhancements, not cleanup.
- zenbrowser or iab refactoring — neither is actually broken.

### Steps

1. Remove commented-out `claude-desktop` let binding (line 10) and package (line 84)
2. Remove `"sway/mode"` from Waybar `modules-left` (line 118) and its config block (lines 145-147)
3. Remove commented-out Waybar config lines (149, 163, 169-170, 180)
4. Remove commented-out i3status-rust hueshift block (line 290)
5. Fix swayidle DPMS: replace `swaymsg "output * power off/on"` with `hyprctl dispatch dpms off/on` (lines 686-689)
6. Run `nix flake check` to verify
7. Optionally `~/bin/rebuild` on zenbook to confirm

### Risks

- **swayidle DPMS fix**: The fix assumes Hyprland is the primary WM. If user switches to Sway session, `hyprctl` won't work. Since the current code already assumes Hyprland (it checks for `hyprlock`), this is consistent. A proper fix for dual-WM would detect which WM is running, but that's over-engineering for now.

## Acceptance Criteria

- Review Sway configuration
- Remove unused let bindings
- Check for other dead code

