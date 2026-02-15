---
id: hm-grgg
status: closed
deps: []
links: []
created: 2026-02-15T01:37:22Z
type: task
priority: 2
assignee: Jeffery Utter
tags: [planned]
---
# Add dim before lock in swayidle configuration

Current swayidle (lines 664-691 in home.nix) goes directly from screen active to locked after 120s.

Suggested improvement: Add a dim step before locking for smoother UX:
- At 110s: dim screen to 10% brightness
- At 120s: lock screen (existing)
- Resume: restore brightness

This provides visual feedback that idle timeout is approaching.

## Design

### Overview

Add a new 110s timeout entry to the `services.swayidle.timeouts` list in `hosts/zenbook/home.nix` that dims the screen before the 120s lock fires. This interacts with the existing `iio_ambient_brightness` daemon that manages backlight based on the ambient light sensor.

### Key Context

- **File**: `hosts/zenbook/home.nix`, `services.swayidle.timeouts` block (~line 674)
- **Two brightness systems in play**:
  - `iio_ambient_brightness` (custom daemon, `-i` inhibits, `-a` allows)
  - `brightnessctl` (direct kernel backlight control, already in packages)
- The existing 60s timeout already calls `iio_ambient_brightness -i` (inhibit) with `-a` on resume
- `brightnessctl` is already in `home.packages`

### Implementation

Insert a new timeout entry **before** the existing 120s lock entry:

```nix
{
  timeout = 110;
  command = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10%";
  resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
}
```

Key details:
- **`-s` flag on set**: Saves current brightness state before changing, so `-r` (restore) can return to the exact previous level
- **`-r` on resume**: Restores the saved brightness level; the iio daemon (re-enabled by the 60s resume at `-a`) will then take over from there
- This is simpler and more correct than manually setting 100% and re-enabling the daemon, since the user may have had brightness at any level before dimming

### Interaction with existing timeouts

| Timeout | Action | Resume |
|---------|--------|--------|
| 60s | `iio_ambient_brightness -i` (inhibit daemon) | `iio_ambient_brightness -a` (re-enable) |
| **110s** | **`brightnessctl -s set 10%` (save & dim)** | **`brightnessctl -r` (restore)** |
| 120s | `hyprlock` (lock screen) | — |
| 180s | Power off display (if locked) | Power on display |
| 300s | Suspend (if on battery) | — |

The 60s inhibit fires first, stopping the ambient daemon from fighting the 110s dim. On resume, swayidle fires all resume commands, so both brightness restore and daemon re-enable happen.

### Verification

1. `home-manager switch` builds without errors
2. Manual test: wait for 110s idle → screen dims to ~10%
3. Move mouse before 120s → brightness restores to previous level
4. Let it reach 120s → lock screen appears (brightness already dim)
5. Unlock → brightness restores, ambient daemon resumes

## Acceptance Criteria

- Add dim timeout step before lock
- Add brightness restore on resume
- Verify brightnessctl commands work with iio_ambient_brightness

