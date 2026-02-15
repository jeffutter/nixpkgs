{ pkgs, lib, config, ... }:
let
  # macOS-style keybindings: ALT+key sends Ctrl+key to the focused window.
  # Each binding specifies:
  #   mods: modifiers to send (e.g. ["ctrl"] or ["ctrl" "shift"])
  #   key:  the key letter (lowercase)
  macosBindings = [
    { mods = [ "ctrl" ]; key = "x"; }
    { mods = [ "ctrl" ]; key = "c"; }
    { mods = [ "ctrl" "shift" ]; key = "c"; }
    { mods = [ "ctrl" ]; key = "v"; }
    { mods = [ "ctrl" "shift" ]; key = "v"; }
    { mods = [ "ctrl" ]; key = "z"; }
    { mods = [ "ctrl" ]; key = "a"; }
    { mods = [ "ctrl" ]; key = "f"; }
    { mods = [ "ctrl" ]; key = "p"; }
    { mods = [ "ctrl" ]; key = "s"; }
    { mods = [ "ctrl" ]; key = "t"; }
    { mods = [ "ctrl" "shift" ]; key = "t"; }
    { mods = [ "ctrl" ]; key = "w"; }
    { mods = [ "ctrl" ]; key = "r"; }
    { mods = [ "ctrl" ]; key = "l"; }
    { mods = [ "ctrl" ]; key = "y"; }
  ];

  # Linux input event keycodes for ydotool.
  # Every key letter used in macosBindings must have an entry here.
  keycodes = {
    ctrl = 29; shift = 42;
    a = 30; c = 46; f = 33; l = 38; p = 25; r = 19;
    s = 31; t = 20; v = 47; w = 17; x = 45; y = 21; z = 44;
  };

  hasShift = b: builtins.elem "shift" b.mods;

  # Hyprland: produce a bindle entry string.
  # Trigger: ALT[+SHIFT]+key  →  sends Ctrl[+Shift]+letter via ydotool.
  toHyprland = b:
    let
      triggerMods = if hasShift b then "ALT SHIFT" else "ALT";
      triggerKey = lib.toUpper b.key;
      pressCtrl = "${toString keycodes.ctrl}:1";
      pressShift = "${toString keycodes.shift}:1";
      pressKey = "${toString keycodes.${b.key}}:1";
      releaseKey = "${toString keycodes.${b.key}}:0";
      releaseShift = "${toString keycodes.shift}:0";
      releaseCtrl = "${toString keycodes.ctrl}:0";
      keyCodes =
        if hasShift b
        then "${pressCtrl} ${pressShift} ${pressKey} ${releaseKey} ${releaseShift} ${releaseCtrl}"
        else "${pressCtrl} ${pressKey} ${releaseKey} ${releaseCtrl}";
    in
    "${triggerMods}, ${triggerKey}, exec, ${pkgs.ydotool}/bin/ydotool key ${keyCodes}";

  # Sway: produce a { name = "trigger"; value = "command"; } pair for listToAttrs.
  # Trigger: modifier+[Shift+]key  →  sends Ctrl[+Shift]+letter via wtype.
  toSway = modifier: b:
    let
      triggerKey = if hasShift b then "${modifier}+Shift+${b.key}" else "${modifier}+${b.key}";
      wtypeArgs =
        if hasShift b
        then "-M ctrl -M shift -P ${b.key}"
        else "-M ctrl -P ${b.key}";
    in
    { name = triggerKey; value = "exec ${pkgs.wtype}/bin/wtype ${wtypeArgs}"; };

  swayModifier = config.wayland.windowManager.sway.config.modifier;

in
{
  wayland.windowManager.hyprland.settings.bindle =
    map toHyprland macosBindings;

  wayland.windowManager.sway.config.keybindings =
    builtins.listToAttrs (map (toSway swayModifier) macosBindings);
}
