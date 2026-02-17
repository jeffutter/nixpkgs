{ pkgs, lib, ... }:
let
  # macOS-style keybindings: ALT+key sends Ctrl+key to the focused window.
  # Each binding specifies:
  #   mods: modifiers to send (e.g. ["ctrl"] or ["ctrl" "shift"])
  #   key:  the key letter (lowercase)
  macosBindings = [
    {
      mods = [ "ctrl" ];
      key = "x";
    }
    {
      mods = [ "ctrl" ];
      key = "c";
    }
    {
      mods = [
        "ctrl"
        "shift"
      ];
      key = "c";
    }
    {
      mods = [ "ctrl" ];
      key = "v";
    }
    {
      mods = [
        "ctrl"
        "shift"
      ];
      key = "v";
    }
    {
      mods = [ "ctrl" ];
      key = "z";
    }
    {
      mods = [ "ctrl" ];
      key = "a";
    }
    {
      mods = [ "ctrl" ];
      key = "f";
    }
    {
      mods = [ "ctrl" ];
      key = "p";
    }
    {
      mods = [ "ctrl" ];
      key = "s";
    }
    {
      mods = [ "ctrl" ];
      key = "t";
    }
    {
      mods = [
        "ctrl"
        "shift"
      ];
      key = "t";
    }
    {
      mods = [ "ctrl" ];
      key = "w";
    }
    {
      mods = [ "ctrl" ];
      key = "r";
    }
    {
      mods = [ "ctrl" ];
      key = "l";
    }
    {
      mods = [ "ctrl" ];
      key = "y";
    }
  ];

  hasShift = b: builtins.elem "shift" b.mods;

  # Hyprland: produce a bind entry string.
  # Trigger: ALT[+SHIFT]+key  →  sends Ctrl[+Shift]+letter via wtype.
  # wtype sends through the Wayland virtual keyboard protocol, so the
  # physical ALT modifier does not bleed into the injected keystrokes.
  toHyprland =
    b:
    let
      triggerMods = if hasShift b then "ALT SHIFT" else "ALT";
      triggerKey = lib.toUpper b.key;
      wtypeMods =
        if hasShift b then
          "-M ctrl -M shift -k ${b.key} -m shift -m ctrl"
        else
          "-M ctrl -k ${b.key} -m ctrl";
    in
    "${triggerMods}, ${triggerKey}, exec, sh -c 'sleep 0.05 && ${pkgs.wtype}/bin/wtype ${wtypeMods}'";

in
{
  wayland.windowManager.hyprland.settings.bindr = map toHyprland macosBindings;
}
