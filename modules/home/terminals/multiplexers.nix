{ pkgs, ... }:

{
  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
  };

  programs.tmux = {
    enable = true;
    escapeTime = 0;
    historyLimit = 5000;
    mouse = false;
    newSession = true;
    resizeAmount = 10;
    shell = "${pkgs.fish}/bin/fish";
    shortcut = "a";
    keyMode = "vi";

    extraConfig = ''
      set-option -g default-command "fish"
      bind-key N swap-window -t +1 \; next-window
      bind-key P swap-window -t -1 \; previous-window
    '';

    plugins = with pkgs.tmuxPlugins; [
      yank
      prefix-highlight
    ];
  };
}
