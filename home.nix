{ config, pkgs, ... }:

let
  my_vim_configurable = pkgs.vim_configurable.override {
    python = pkgs.python3;
    guiSupport = "off";
    rubySupport = false;
  };

  comma = import ( pkgs.fetchFromGitHub {
      owner = "Shopify";
      repo = "comma";
      rev = "4a62ec17e20ce0e738a8e5126b4298a73903b468";
      sha256 = "0n5a3rnv9qnnsrl76kpi6dmaxmwj1mpdd2g0b4n1wfimqfaz6gi1";
  }) {};

  ssh-copy-id = pkgs.runCommand "ssh-copy-id" {} ''
    mkdir -p $out/bin
    ln -s ${pkgs.openssh}/bin/ssh-copy-id $out/bin/ssh-copy-id
  '';

  blueutil = pkgs.callPackage pkgs/blueutil {};
  wrk2 = pkgs.callPackage pkgs/wrk2 {};
  goreleaser = pkgs.callPackage pkgs/goreleaser {};
  usql = pkgs.callPackage pkgs/usql {};
  tmpmail = pkgs.callPackage pkgs/tmpmail {};
  duf = pkgs.callPackage pkgs/duf {};

in

{
  home.packages = with pkgs; [
    _1password
    aspell
    aspellDicts.en
    aspellDicts.en-computers
    autoconf
#    awscli2
#    awslogs
    bandwhich
    bash-completion
    bash_5
    bat
#    blueutil
    borgbackup
    bottom
    broot
    brotli
    bzip2
    comma
    curl
    doctl
    duf
    elixir
    erlang_nox
    exa
    fd
#    fwup
    gawk
    gitAndTools.gh
    gitAndTools.hub
    gnused
    gnupg
    go
    goreleaser
    grex
    htop
    hyperfine
    imagemagick
    ispell
    jq
    k6
    kubectl
#    kubernetes-helm
    lftp
#    luarocks
    mosh
    my_vim_configurable
    ncdu
    neovim
    ngrok
    p7zip
    platinum-searcher
    postgresql
    protobuf
    pstree
    pv
    redis
    ripgrep
    rustc
    saml2aws
    silver-searcher
    ssh-copy-id
    topgrade
    tmate
    tmpmail
#    usql
    vips
    websocat
    wget
#    wrk
#    wrk2
    xz
    yarn
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "p7zip-16.02"
  ];

  nixpkgs.config.allowUnfree = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.file.".SpaceVim" = {
    # don't make the directory read only so that impure melpa can still happen
    # for now
    recursive = true;
    source = pkgs.fetchFromGitHub {
      owner = "SpaceVim";
      repo = "SpaceVim";
      rev = "a9e36e0e1a0837866883a127d005c2bb1963be12";
      sha256 = "0ycirz60wsgxljwd58x3kxp6wl04iyycyfwd4ijrsyw4x968f3h4";
    };
    onChange = "ln -sf $HOME/.SpaceVim $HOME/.vim";
  };
  home.file.".SpaceVim.d/init.toml".source = ./space_vim.toml;

  home.file.".emacs.d" = {
    # don't make the directory read only so that impure melpa can still happen
    # for now
    recursive = true;
    source = pkgs.fetchFromGitHub {
      owner = "syl20bnr";
      repo = "spacemacs";
      rev = "e3b6464649b28f5cc048f78ace825256615814f9";
      sha256 = "0yx25vw2lfkl2pcxm5wixbaximz4xydn00w4aww3i32xv4sg9lvz";
    };
  };
  home.file.".spacemacs".source = ./spacemacs;

  home.file.".config/topgrade.toml".source = ./topgrade.toml;

  home.file."bin/upgrade" = {
    text = ''
      #!env bash
      set -x
      set -eo pipefail

      topgrade
      brew cleanup
      home-manager expire-generations "-1 week"
      nix-collect-garbage --delete-older-than 7d
    '';
    executable = true;
  };

  programs.git = {
    package = pkgs.gitAndTools.gitFull;
    enable = true;
    userName = "Jeffery Utter";
    userEmail = "jeff@jeffutter.com";
    extraConfig = {
      github = {
        user = "jeffutter";
      };
      pull = {
        rebase = false;
      };
    };
    delta = {
      enable = true;
      options = {
        side-by-side = true;
        line-numbers-left-format = "";
        line-numbers-right-format = "│ ";
        syntax-theme = "Nord";
      };
    };
    ignores = [
      "DS_Store"
      ".DS_Store?"
      "._*"
      ".Spotlight-V100"
      ".Trashes"
      "ehthumbs.db"
      "Thumbs.db"
      "project-notes.org"
      "project_notes.org"
      ".elixir_ls"
      ".vscode"
    ];
  };

  programs.alacritty = {
    enable = true;
    settings = {
      live_config_reload = true;
      font = {
        normal = {
          family = "SauceCodePro Nerd Font Mono";
          style = "Regular";
        };
        bold = {
          family = "SauceCodePro Nerd Font Mono";
          style = "Bold";
        };
        italic = {
          family = "SauceCodePro Nerd Font Mono";
          style = "Italic";
        };
        bold_italic = {
          family = "SauceCodePro Nerd Font Mono";
          style = "Bold Italic";
        };
        size = 11.0;
      };
      colors = {
        primary = {
          background = "#2e3440";
          foreground = "#d8dee9";
          dim_foreground = "#a5abb6";
        };
        cursor = {
          text = "#2e3440";
          cursor = "#d8dee9";
        };
        vi_mode_cursor = {
          text = "#2e3440";
          cursor = "#d8dee9";
        };
        selection = {
          text = "CellForeground";
          background = "#4c566a";
        };
        search = {
          matches = {
            foreground = "CellBackground";
            background = "#88c0d0";
          };
          bar = {
            background = "#434c5e";
            foreground = "#d8dee9";
          };
        };
        normal = {
          black = "#3b4252";
          red = "#bf616a";
          green = "#a3be8c";
          yellow = "#ebcb8b";
          blue = "#81a1c1";
          magenta = "#b48ead";
          cyan = "#88c0d0";
          white = "#e5e9f0";
        };
        bright = {
          black = "#4c566a";
          red = "#bf616a";
          green = "#a3be8c";
          yellow = "#ebcb8b";
          blue = "#81a1c1";
          magenta = "#b48ead";
          cyan = "#8fbcbb";
          white = "#eceff4";
        };
        dim = {
          black = "#373e4d";
          red = "#94545d";
          green = "#809575";
          yellow = "#b29e75";
          blue = "#68809a";
          magenta = "#8c738c";
          cyan = "#6d96a5";
          white = "#aeb3bb";
        };
      };
    };
  };

  programs.tmux = {
    enable = true;
    escapeTime = 0;
    newSession = true;
    resizeAmount = 10;
    shortcut = "a";
    terminal = "screen-256color";
    plugins = with pkgs.tmuxPlugins; [
      prefix-highlight
      yank
      nord
    ];
  };

  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = ["git" "docker" "mosh" "kubectl" "emacs" "osx"];
    };
    shellAliases = {
      dc = "docker-compose";
    };
    sessionVariables = {
      AWS_DEFAULT_REGION = "us-east-1";
      AWS_PAGER="";
      EDITOR="vim";
    };
    envExtra = ''
      if [ -e /Users/jeffutter/.nix-profile/etc/profile.d/nix.sh ]; then . /Users/jeffutter/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer
    '';
    initExtra = ''
      setopt completealiases

      if [ -e /Users/jeffutter/.nix-profile/etc/profile.d/nix.sh ]; then . /Users/jeffutter/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

      if [ "$(command -v exa)" ]; then
          unalias -m 'll'
          unalias -m 'l'
          unalias -m 'la'
          unalias -m 'ls'
          #alias ls='exa -G  --color auto --icons -a -s type'
          alias ls='exa -G  --color auto -s type'
          alias ll='exa -l --color always --icons -a -s type'
      fi

      if [ "$(command -v bat)" ]; then
        unalias -m 'cat'
        alias cat='bat -pp --theme="Nord"'
      fi

      if [ "$(command -v duf)" ]; then
        unalias -m 'du'
        alias du='duf'
      fi
    '';
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    changeDirWidgetCommand = "fd --type d";
    defaultCommand = "fd --type f";
    fileWidgetCommand = "fd --type f";
  };

  home.sessionVariables = {
    EDITOR = "vim";
  };

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "jeffutter";
  home.homeDirectory = "/Users/jeffutter";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "20.09";
}
