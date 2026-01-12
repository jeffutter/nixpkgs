{
  config,
  pkgs,
  theme,
  ...
}:

{
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      extraConfig = ''
        if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
          ZSH_TMUX_AUTOSTART=true
          ZSH_TMUX_AUTOQUIT=false
        fi
      '';
    };
    shellAliases = {
      dc = "docker compose";
      k = "kubectl";
    };
    sessionVariables = {
      AWS_DEFAULT_REGION = "us-east-1";
      AWS_PAGER = "";
      EDITOR = "nvim";
    };
    envExtra = ''
      export LANG="en_US.UTF-8"
      export LC_COLLATE="en_US.UTF-8"
      export LC_CTYPE="en_US.UTF-8"
      export LC_MESSAGES="en_US.UTF-8"
      export LC_MONETARY="en_US.UTF-8"
      export LC_NUMERIC="en_US.UTF-8"
      export LC_TIME="en_US.UTF-8"
      export LC_ALL="en_US.UTF-8"

      export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"
      export ERL_AFLAGS="-kernel shell_history enabled"
      export RUST_SRC_PATH="${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
      export COLORTERM=truecolor
      export GPG_TTY=$(tty)
      export PINENTRY_USER_DATA="USE_CURSES=1"

      path_append() {
        if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
            PATH="''${PATH:+"$PATH:"}$1"
        fi
      }

      path_prepend() {
        if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
            PATH="$1''${PATH:+":$PATH"}"
        fi
      }

      path_prepend "$HOME/bin"
      path_prepend "$HOME/homebrew/bin"
      path_append /Applications/Docker.app/Contents/Resources/bin
      path_append /usr/local/bin

      if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && -z "$NIX_GLOBAL_SOURCED" ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        export NIX_GLOBAL_SOURCED="true"
      fi

      if [[ -e ${config.home.homeDirectory}/.nix-profile/etc/profile.d/nix.sh && -z "$NIX_HOME_SOURCED" ]]; then
        . ${config.home.homeDirectory}/.nix-profile/etc/profile.d/nix.sh
        export NIX_HOME_SOURCED="true"
      fi
    '';
    initContent = ''
      if [ "$(command -v eza)" ]; then
          unalias -m 'll'
          unalias -m 'l'
          unalias -m 'la'
          unalias -m 'ls'
          #alias ls='eza -G  --color auto --icons -a -s type'
          alias ls='eza -G  --color auto -s type'
          alias ll='eza -l --color always --icons -a -s type'
      fi

      if [ "$(command -v bat)" ]; then
        unalias -m 'cat'
        alias cat='bat -pp'
      fi

      if [ "$(command -v duf)" ]; then
        unalias -m 'df'
        alias df='duf'
      fi

      if [ "$(command -v himalaya)" ]; then
        unalias -m 'h'
        alias h='himalaya'
      fi

      printf "\e[?1042l"

      export LS_COLORS="$(vivid generate ${theme.vivid})"
    '';
  };
}
