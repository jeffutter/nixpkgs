{ pkgs, ... }:

{
  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
    # Stylix handles theming
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
    terminal = "tmux-256color";
    extraConfig = ''
      set-option -g default-command "fish"
      set -ga terminal-overrides ",*256col*:Tc"
      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'  # undercurl support
      set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'  # underscore colours - needs tmux-3.0
      set -g status-keys vi
      set -g mode-keys   vi
      bind-key N swap-window -t +1 \; next-window
      bind-key P swap-window -t -1 \; previous-window
    '';
    # Stylix handles theming
    plugins = with pkgs.tmuxPlugins; [
      yank
      prefix-highlight
    ];
  };
}
