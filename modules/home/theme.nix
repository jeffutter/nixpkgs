{
  inputs,
  ...
}:

let
  tokyonight = inputs.tokyonight;
in

{
  _module.args.theme = {
    name = "tokyonight_moon";
    src = tokyonight;

    # Pre-defined paths for each application
    ghostty = tokyonight + "/extras/ghostty/tokyonight_moon";
    tmux = tokyonight + "/extras/tmux/tokyonight_moon.tmux";
    fish = tokyonight + "/extras/fish/tokyonight_moon.fish";
    bat = tokyonight + "/extras/sublime/tokyonight_moon.tmTheme";
    delta = tokyonight + "/extras/delta/tokyonight_moon.gitconfig";
    vivid = "tokyonight_moon"; # vivid theme name (not a path)
    zellij = "tokyo-night-storm"; # zellij theme name
  };
}
