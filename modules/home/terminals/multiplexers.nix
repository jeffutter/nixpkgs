{ pkgs, config, ... }:

let
  c = config.lib.stylix.colors.withHashtag;

  # Abbreviate path: ~/.c/h/m/terminals
  shortenPath = pkgs.writeShellScript "shorten-path" ''
    path="$1"
    # Replace $HOME with ~
    path="''${path/#$HOME/\~}"

    # Split into array and process
    IFS='/' read -ra parts <<< "$path"
    len=''${#parts[@]}
    result=""

    for ((i=0; i<len; i++)); do
      part="''${parts[i]}"
      if [[ $i -eq $((len-1)) ]]; then
        # Last part: keep full
        result="$result$part"
      elif [[ "$part" == "~" ]]; then
        result="~/"
      elif [[ -n "$part" ]]; then
        # Abbreviate to first char
        result="$result''${part:0:1}/"
      fi
    done

    echo "$result"
  '';

  # Show kubernetes context with aliases (matching starship patterns)
  kubeContext = pkgs.writeShellScript "kube-context" ''
    KUBECONFIG="''${KUBECONFIG:-$HOME/.kube/config}"

    if [[ ! -f "$KUBECONFIG" ]]; then
      exit 0
    fi

    # Parse current context from kubeconfig
    context=$(${pkgs.yq-go}/bin/yq '.current-context // ""' "$KUBECONFIG" 2>/dev/null)

    if [[ -z "$context" || "$context" == "null" ]]; then
      exit 0
    fi

    # Get namespace for this context
    namespace=$(${pkgs.yq-go}/bin/yq ".contexts[] | select(.name == \"$context\") | .context.namespace // \"\"" "$KUBECONFIG" 2>/dev/null)

    # Apply aliases (matching starship patterns)
    if [[ "$context" =~ ^gke_[a-zA-Z0-9_]+-prod[a-zA-Z0-9_-]+_scorebet-(.+)$ ]]; then
      # Production: show "PROD cluster PROD" in RED
      cluster="''${BASH_REMATCH[1]}"
      ns_display=""
      if [[ -n "$namespace" && "$namespace" != "null" && "$namespace" != "default" ]]; then
        ns_display=" ($namespace)"
      fi
      echo "#[fg=${c.base08},bg=${c.base03},bold] PROD $cluster PROD$ns_display "
    elif [[ "$context" =~ ^gke_s[a-zA-Z0-9_]+-[a-zA-Z0-9_-]+_scorebet-(.+)$ ]]; then
      # Staging: show just cluster name
      display="''${BASH_REMATCH[1]}"
      if [[ -n "$namespace" && "$namespace" != "null" && "$namespace" != "default" ]]; then
        display="$display ($namespace)"
      fi
      echo "#[fg=${c.base05},bg=${c.base03}]  $display "
    else
      # Default: show full context
      display="$context"
      if [[ -n "$namespace" && "$namespace" != "null" && "$namespace" != "default" ]]; then
        display="$display ($namespace)"
      fi
      echo "#[fg=${c.base05},bg=${c.base03}]  $display "
    fi
  '';

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
        clear: "#[fg=default,bg=${c.base01}]"
        state: "#[fg=${c.base08},bg=${c.base01},bold]"
        branch: "#[fg=${c.base05},bg=${c.base01}]"
        remote: "#[fg=${c.base0C},bg=${c.base01}]"
        staged: "#[fg=${c.base0B},bg=${c.base01}]"
        conflict: "#[fg=${c.base08},bg=${c.base01}]"
        modified: "#[fg=${c.base09},bg=${c.base01}]"
        untracked: "#[fg=${c.base0E},bg=${c.base01}]"
        stashed: "#[fg=${c.base0C},bg=${c.base01}]"
        clean: "#[fg=${c.base0B},bg=${c.base01}]"
      layout: [branch, divergence]
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

    extraConfig = ''
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

      set -g status-left "#[fg=${c.base00},bg=${c.base0D},bold] #S #[fg=${c.base0D},bg=${c.base00}]"
      set -g status-right "#[fg=${c.base0D},bg=${c.base00}]#{prefix_highlight}#[fg=${c.base01},bg=${c.base00}]#(gitmux -cfg ${gitmuxConfig} \"#{pane_current_path}\")#[bg=${c.base01}] #[fg=${c.base02},bg=${c.base01}]#[fg=${c.base05},bg=${c.base02}]  #(${shortenPath} \"#{pane_current_path}\") #[fg=${c.base03},bg=${c.base02}]#(${kubeContext})#[fg=${c.base04},bg=${c.base03}]#[fg=${c.base00},bg=${c.base04}] %I:%M %p #[fg=${c.base0D},bg=${c.base04}]#[fg=${c.base00},bg=${c.base0D},bold] #h "

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
