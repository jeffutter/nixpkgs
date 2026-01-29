{ pkgs, config, ... }:

let
  c = config.lib.stylix.colors.withHashtag;

  gitmuxConfig = pkgs.writeText "gitmux.conf" ''
    tmux:
      symbols:
        branch: " "
        hashprefix: ":"
        ahead: "↑"
        behind: "↓"
        staged: "●"
        conflict: ""
        modified: ""
        untracked: ""
        stashed: ""
        clean: ""
      styles:
        clear: "#[fg=default]"
        state: "#[fg=${c.base08},bold]"
        branch: "#[fg=${c.base05}]"
        remote: "#[fg=${c.base0C}]"
        staged: "#[fg=${c.base0B}]"
        conflict: "#[fg=${c.base08}]"
        modified: "#[fg=${c.base09}]"
        untracked: "#[fg=${c.base0E}]"
        stashed: "#[fg=${c.base0C}]"
        clean: "#[fg=${c.base0B}]"
      layout: [branch, divergence, " ", flags]
      options:
        branch_max_len: 20
        hide_clean: true
  '';
in
{
  home.packages = [ pkgs.gitmux ];

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
    terminal = "tmux-256color";

    extraConfig =
      ''
        set-option -g default-command "fish"
        bind-key N swap-window -t +1 \; next-window
        bind-key P swap-window -t -1 \; previous-window

        # Enable italic and true color passthrough
        set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'  # undercurl support
        set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'  # underscore colors
        set -as terminal-overrides ',xterm*:Tc'
        set -as terminal-overrides ',*:sitm=\E[3m'  # italic

        # Status bar theme (colors from Stylix)
        set -g mode-style "fg=${c.base0D},bg=${c.base02}"
        set -g message-style "fg=${c.base0D},bg=${c.base02}"
        set -g message-command-style "fg=${c.base0D},bg=${c.base02}"

        set -g pane-border-style "fg=${c.base02}"
        set -g pane-active-border-style "fg=${c.base0D}"

        set -g status "on"
        set -g status-justify "left"
        set -g status-style "fg=${c.base0D},bg=${c.base00}"

        set -g status-left-length "100"
        set -g status-right-length "100"
        set -g status-left-style NONE
        set -g status-right-style NONE

        set -g status-left "#[fg=${c.base00},bg=${c.base0D},bold] #S #[fg=${c.base0D},bg=${c.base02}]#[fg=${c.base05},bg=${c.base02}]  #{b:pane_current_path} #[fg=${c.base02},bg=${c.base00}]#(gitmux -cfg ${gitmuxConfig} \"#{pane_current_path}\")"
        set -g status-right "#[fg=${c.base0D},bg=${c.base00}] #{prefix_highlight} #[fg=${c.base02},bg=${c.base00}]#[fg=${c.base0D},bg=${c.base02}] %Y-%m-%d  %I:%M %p #[fg=${c.base0D},bg=${c.base02}]#[fg=${c.base00},bg=${c.base0D},bold] #h "

        setw -g window-status-activity-style "underscore,fg=${c.base04},bg=${c.base00}"
        setw -g window-status-separator ""
        setw -g window-status-style "NONE,fg=${c.base04},bg=${c.base00}"
        setw -g window-status-format "#[fg=${c.base00},bg=${c.base00}]#[fg=${c.base04},bg=${c.base00}] #I  #W #F #[fg=${c.base00},bg=${c.base00}]"
        setw -g window-status-current-format "#[fg=${c.base00},bg=${c.base02}]#[fg=${c.base0D},bg=${c.base02},bold] #I  #W #F #[fg=${c.base02},bg=${c.base00}]"

        # tmux-prefix-highlight settings
        set -g @prefix_highlight_output_prefix "#[fg=${c.base0A}]#[bg=${c.base00}]#[fg=${c.base00}]#[bg=${c.base0A}]"
        set -g @prefix_highlight_output_suffix ""
      '';

    plugins = with pkgs.tmuxPlugins; [
      yank
      prefix-highlight
    ];
  };
}
