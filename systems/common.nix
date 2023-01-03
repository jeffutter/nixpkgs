{ config, pkgs, lib, mkIf, platforms, ... }:

let
  inherit (pkgs.lib) optional optionals;

  my_vim_configurable = pkgs.vim_configurable.override {
    guiSupport = "off";
    rubySupport = false;
  };

  ssh-copy-id = pkgs.runCommand "ssh-copy-id" {} ''
    mkdir -p $out/bin
    ln -s ${pkgs.openssh}/bin/ssh-copy-id $out/bin/ssh-copy-id
  '';

  mosh = pkgs.mosh.overrideAttrs (old: {
    version = "1.4.0";
    src = pkgs.fetchFromGitHub {
      owner = "mobile-shell";
      repo = "mosh";
      rev = "mosh-1.4.0";
      sha256 = "sha256-tlSsHu7JnXO+sorVuWWubNUNdb9X0/pCaiGG5Y0X/g8=";
    };
    patches = lib.remove 
      (pkgs.fetchpatch {
        url = "https://github.com/mobile-shell/mosh/commit/e5f8a826ef9ff5da4cfce3bb8151f9526ec19db0.patch";
        sha256 = "15518rb0r5w1zn4s6981bf1sz6ins6gpn2saizfzhmr13hw4gmhm";
      })
      old.patches;
    postPatch = ''
      substituteInPlace scripts/mosh.pl \
        --subst-var-by ssh "${pkgs.openssh}/bin/ssh" \
        --subst-var-by mosh-client "$out/bin/mosh-client"
    '';
  });

  gnutar = pkgs.gnutar.overrideAttrs (old: {
    configureFlags = [
      "--with-gzip=pigz"
      "--with-xz=pixz"
      "--with-bzip2=pbzip2"
      "--with-zstd=pzstd"
    ] ++ optionals pkgs.stdenv.isDarwin [
      "gt_cv_func_CFPreferencesCopyAppValue=no"
      "gt_cv_func_CFLocaleCopyCurrent=no"
      "gt_cv_func_CFLocaleCopyPreferredLanguages=no"
    ];
  });

  my_wakeonlan = pkgs.callPackage ../pkgs/wakeonlan {};

  ltex-lsp = pkgs.callPackage ../pkgs/ltex-lsp {}; 

  my_fonts = pkgs.nerdfonts.override {
    fonts = [
      "FantasqueSansMono"
      "FiraCode"
      "Hack"
      "Hasklig"
      "Iosevka"
      "Monoid"
      "JetBrainsMono"
      "SourceCodePro" 
    ];
  };

in

{
  home.packages = with pkgs; [
    aspell
    aspellDicts.en
    aspellDicts.en-computers
    autoconf
    bandwhich
    bash-completion
    bash
    bat
    borgbackup
    bottom
    broot
    brotli
    bzip2
    comma
    curl
    docker
    doctl
    du-dust
    duf
    exa
    fd
    gawk
    gitAndTools.gh
    git-absorb
    git-lfs
    gnused
    gnupg
    grex
    htop
    hyperfine
    ijq
    imagemagick
    ispell
    jq
    just
    k6
    k9s
    kubectl
    kubectx
    kubernetes-helm
    kubeseal
    lftp
    ltex-lsp
    mosh
    my_vim_configurable
    ncdu
    ngrok
    nodePackages.bash-language-server
    p7zip
    pigz
    pixz
    pbzip2
    postgresql
    protobuf
    pstree
    pv
    ripgrep
    rnix-lsp
    rsync
    ruplacer
    shellcheck
    sqls
    ssh-copy-id
    gnutar
    #tlaplus
    tmate
    unzip
    unixtools.watch
    vale
    viddy
    vimPlugins.vimproc-vim
    vips
    my_wakeonlan
    wavpack
    wget
    xz
    yarn
    yq
    zstd

    # Fonts
    my_fonts
    roboto
    roboto-mono
    input-fonts

    # Elixir
    elixir
    elixir_ls
    erlang_nox

    # Rust
    cargo
    cargo-bloat
    cargo-criterion
    cargo-cross
    cargo-expand
    cargo-flamegraph
    cargo-llvm-lines
    cargo-outdated
    cargo-udeps
    clippy
    evcxr
    rust-analyzer
    rustc
    rustfmt
    sqlx-cli

    # Go
    go
    gocode
    gore
    goreleaser
    gotest
  ]
  ++ optional stdenv.isLinux inotify-tools
  ++ optionals stdenv.isDarwin [ skhd ]
  ++ optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [ CoreFoundation CoreServices ])
  ;

  nixpkgs.config.permittedInsecurePackages = [
    "p7zip-16.02"
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.input-fonts.acceptLicense = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  #manual.manpages.enable = false;

  home.file.".zfunc" = {
    source = ../zfunc;
    recursive = true;
  };

  home.file."Applications" =
    let
      apps = pkgs.buildEnv {
        name = "home-manager-applications";
        paths = config.home.packages;
        pathsToLink = "/Applications";
      };
    in
      lib.mkIf pkgs.stdenv.targetPlatform.isDarwin {
        source = "${apps}/Applications";
        recursive = true;
      };

  home.file."bin/upgrade" = {
    source = ../bin/upgrade;
    executable = true;
  };

  home.file.".amethyst.yml" = lib.mkIf pkgs.stdenv.targetPlatform.isDarwin {
    text = ''
      layouts:
          - fullscreen
          - middle-wide
          - tall
          - wide
          - widescreen-tall
          - column
          - bsp

      mod1:
          - option
          - shift
      mod2:
          - option
          - shift
          - control

      window-margins: true
      window-margin-size: 10
      smart-window-margins: true
      mouse-follows-focus: true
      focus-follows-mouse: false
    '';
  };

  home.file.".config/skhd/skhdrc" = lib.mkIf pkgs.stdenv.targetPlatform.isDarwin {
    text = ''
      cmd + alt - b ; launcher
      launcher < b : open -a 'Brave Browser'
      launcher < m : open -a 'Messages'
      launcher < o : open -a 'Obsidian'
      launcher < a : open -a 'Alacritty'
      launcher < l : open -a 'Mail'
      launcher < c : open -a 'Calendar'
      ctrl + alt + shift - b : open -a 'Brave Browser'
      ctrl + alt + shift - m : open -a 'Messages'
      ctrl + alt + shift - o : open -a 'Obsidian'
      ctrl + alt + shift - a : open -a 'Alacritty'
      ctrl + alt + shift - l : open -a 'Mail'
      ctrl + alt + shift - c : open -a 'Calendar'
      cmd - return : open -a 'Alacritty'
    '';
  };

  launchd.agents.skhd = lib.mkIf pkgs.stdenv.targetPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.skhd}/bin/skhd"
        "-c"
        "${config.xdg.configHome}/skhd/skhdrc"
      ];
      KeepAlive = true;
      ProcessType = "Interactive";
      EnvironmentVariables = {
        PATH = lib.concatStringsSep ":" [
          "${config.home.homeDirectory}/.nix-profile/bin"
          "/run/current-system/sw/bin"
          "/nix/var/nix/profiles/default/"
          "/usr/bin"
        ];
      };
      StandardOutPath = "${config.xdg.cacheHome}/skhd.out.log";
      StandardErrorPath = "${config.xdg.cacheHome}/skhd.err.log";
    };
  };

  home.file.".config/warpd/config" = {
    text = ''
      up:f
      down:s
      left:r
      right:t

      grid_activation_key:A-M-g
      activation_key:A-M-c
      hint_activation_key:A-M-x
      grid:b

      grid_up:f
      grid_down:s
      grid_left:r
      grid_right:t

      grid_keys:g j d h

      scroll_up:p
      scroll_down:v

      start:^
      end:$

      cursor_size:10

      exit:z

      indicator: bottomleft
      #indicator: Specifies an optional visual indicator to be displayed while normal mode is active, must be one of: topright, topleft, bottomright, bottomleft, none (default: none).
      #indicator_color: The color of the visual indicator color. (default: #00ff00).
      #indicator_size: The size of the visual indicator in pixels. (default: 12).


      #speed: Pointer speed in pixels/second. (default: 220).
      #speed: 500
      #acceleration: Pointer acceleration in pixels/second^2. (default: 700).
      #acceleration:900

      buttons: m , .
      #buttons: k m .
    '';
  };

  accounts.email.accounts = {
    sadclown = {
      primary = true;
      realName = "Jeffery Utter";
      address = "jeffutter@sadclown.net";
      aliases = "jeff@jeffutter.com";
      flavor = "fastmail.com";
      himalaya = {
        enable = true;
        backend = "imap";
        sender = "smtp";
      };
      imap = {
        port = 993;
        host = "imap.fastmail.com";
        tls.enable = true;
      };
      smtp = {
        port = 587;
        host = "smtp.fastmail.com";
        tls.enable = true;
        tls.useStartTls = true;
      };
      userName = "jeffutter@sadclown.net";
      passwordCommand = [ "op" "item" "get" "Fastmail Himalaya" "--fields" "password"];
    };
    work = {
      primary = false;
      realName = "Jeffery Utter";
      address = "jeffery.utter@thescore.com";
      flavor = "gmail.com";
      himalaya = {
        enable = true;
        backend = "imap";
        sender = "smtp";
      };
      imap = {
        port = 993;
        host = "imap.gmail.com";
        tls.enable = true;
      };
      smtp = {
        port = 587;
        host = "smtp.gmail.com";
        tls.enable = true;
        tls.useStartTls = true;
      };
      folders = {
        sent = "[Gmail]/Sent Mail";
        drafts = "[Gmail]/Drafts";
      };
      userName = "jeffery.utter@thescore.com";
      passwordCommand = [ "op" "item" "get" "Gmail (theScore) (Himalaya)" "--fields" "password"];
    };
  };

  programs.himalaya = {
    enable = true;
    settings = {
      name = "Jeffery Utter";
      default-page-size = 50;
    };
  };

  programs.neovim = {
    enable = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
      packer-nvim
    ];
  };

  home.file.".config/nvim/init.lua" = {
    source = ../nvim/init.lua;
  };

  programs.git = {
    package = pkgs.gitAndTools.gitFull;
    enable = true;
    userName = "Jeffery Utter";
    extraConfig = {
      github = {
        user = "jeffutter";
      };
      fetch = {
        prune = true;
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
      "shell.nix"
      ".envrc"
      ".direnv"
      "hs_err*"
    ];
  };

  programs.alacritty = {
    enable = true;
    settings = {
      live_config_reload = true;
      window = {
        decorations = "full";
      };
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
          footer_bar = {
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

  programs.kitty = {
    enable = true;
    theme = "Nord";
    font = {
      package = my_fonts;
      name = "SauceCodePro Nerd Font Mono";
    };
    settings = {
      macos_titlebar_color = "background";
      tab_bar_style = "powerline";
      macos_colorspace = "default";
    };
  };

  programs.tmux = {
    enable = true;
    escapeTime = 0;
    newSession = true;
    resizeAmount = 10;
    shortcut = "a";
    terminal = "screen-256color";
    extraConfig = ''
set -ga terminal-overrides ",*256col*:Tc"
set-option -g mouse off
set-option -g default-command "fish"
    '';
    plugins = with pkgs.tmuxPlugins; [
      nord
      yank
      prefix-highlight
    ];
  };

  programs.fish = {
    enable = true;
    shellAbbrs = {
      "gcan!" = "git commit -v -a --no-edit --amend";
      dc = "docker compose";
      g = "git";
      gpf = "git push --force";
      h = "himalaya";
      k = "kubectl";
      kctx = "kubectx";
      kns = "kubens";
    };
    shellAliases = {
      bzip2 = "pbzip2";
      cat = "bat -pp --theme=\"Nord\"";
      df = "duf";
      gunzip = "pigz -d";
      gz = "pigz";
      ll = "exa -l --color always --icons -a -s type";
      ls = "exa -G --color auto -s type";
      xz = "pxz";
    };
    functions = {
      kca = "kubectl $argv --all-namespaces";
    };
    plugins = [
      {
        name = "fenv";
        src = pkgs.fetchFromGitHub {
          owner = "oh-my-fish";
          repo = "plugin-foreign-env";
          rev = "b3dd471bcc885b597c3922e4de836e06415e52dd";
          sha256 = "sha256-3h03WQrBZmTXZLkQh1oVyhv6zlyYsSDS7HTHr+7WjY8=";
        };
      }
      {
        name = "autopair";
        src = pkgs.fetchFromGitHub {
          owner = "jorgebucaran";
          repo = "autopair.fish";
          rev = "1.0.4";
          sha256 = "sha256-s1o188TlwpUQEN3X5MxUlD/2CFCpEkWu83U9O+wg3VU=";
        };
      }
    ];
    shellInit = ''
      set fish_greeting

      set -x LANG "en_US.UTF-8"
      set -x LC_COLLATE "en_US.UTF-8"
      set -x LC_CTYPE "en_US.UTF-8"
      set -x LC_MESSAGES "en_US.UTF-8"
      set -x LC_MONETARY "en_US.UTF-8"
      set -x LC_NUMERIC "en_US.UTF-8"
      set -x LC_TIME "en_US.UTF-8"
      set -x LC_ALL "en_US.UTF-8"

      if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] && ! set -q NIX_GLOBAL_SOURCED
        fenv source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        set -x  NIX_GLOBAL_SOURCED "true"
      end
      if [ -e ${config.home.homeDirectory}/.nix-profile/etc/profile.d/nix.sh ] && ! set -q NIX_HOME_SOURCED
        fenv source ${config.home.homeDirectory}/.nix-profile/etc/profile.d/nix.sh
        set -x NIX_HOME_SOURCED "true"
      end

      fish_add_path -p "$HOME/bin"
      fish_add_path -p "$HOME/homebrew/bin"
      fish_add_path -a /usr/local/bin
      fish_add_path -a /Applications/Docker.app/Contents/Resources/bin

      set -x HOMEBREW_CASK_OPTS "--appdir=$HOME/Applications"
      set -x ERL_AFLAGS "-kernel shell_history enabled"

      set -gx ATUIN_NOBIND "true"
      set -x RUST_SRC_PATH "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
    '';
    interactiveShellInit = ''
      fish_vi_key_bindings
      bind -M default vv edit_command_buffer

      bind \cr _atuin_search
      bind -M insert \cr _atuin_search

      source ${pkgs.docker}/share/fish/vendor_completions.d/docker.fish

      set -x GPG_TTY (tty)
      set -x PINENTRY_USER_DATA "USE_CURSES=1"
      set -x COLORTERM truecolor
      set -x AWS_DEFAULT_REGION "us-east-1";
      set -x AWS_PAGER "";
      set -x EDITOR "vim";
    '';
  };

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
      AWS_PAGER="";
      EDITOR="vim";
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

      if [ -n "$(find ~/.zfunc -prune -empty)" ]; then
        export fpath=( ~/.zfunc "''${fpath[@]}" )
        autoload -U $fpath[1]/*(:t)
      fi
    '';
    initExtra = ''
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
        unalias -m 'df'
        alias df='duf'
      fi

      if [ "$(command -v himalaya)" ]; then
        unalias -m 'h'
        alias h='himalaya'
      fi
      
      printf "\e[?1042l"
    '';
  };

  programs.topgrade = {
    enable = true;
    settings = {
      ignore_failures = ["containers"];
      disable = ["yadm" "node" "gem" "nix" "gcloud" "opam"];
      cleanup = true;
      commands = {
        "Expire old home-manager configs" = "home-manager expire-generations '-1 week'";
        "Run garbage collection on Nix store" = "nix-collect-garbage --delete-older-than 7d";
      };
    };
  };

  programs.keychain = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    inheritType = "any";
  };

  programs.dircolors = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    settings = {
      COLOR = "tty";

      #+-----------------+
      #+ Global Defaults +
      #+-----------------+
      NORMAL = "00";
      RESET = "0";

      FILE = "00";
      DIR = "01;34";
      LINK = "36";
      MULTIHARDLINK = "04;36";

      FIFO = "04;01;36";
      SOCK = "04;33";
      DOOR = "04;01;36";
      BLK = "01;33";
      CHR = "33";

      ORPHAN = "31";
      MISSING = "01;37;41";

      EXEC = "01;36";

      SETUID = "01;04;37";
      SETGID = "01;04;37";
      CAPABILITY = "01;37";

      STICKY_OTHER_WRITABLE = "01;37;44";
      OTHER_WRITABLE = "01;04;34";
      STICKY = "04;37;44";

      #+-------------------+
      #+ Extension Pattern = "+";
      #+-------------------+
      #+--- Archives = "---+";
      ".7z" = "01;32";
      ".ace" = "01;32";
      ".alz" = "01;32";
      ".arc" = "01;32";
      ".arj" = "01;32";
      ".bz" = "01;32";
      ".bz2" = "01;32";
      ".cab" = "01;32";
      ".cpio" = "01;32";
      ".deb" = "01;32";
      ".dz" = "01;32";
      ".ear" = "01;32";
      ".gz" = "01;32";
      ".jar" = "01;32";
      ".lha" = "01;32";
      ".lrz" = "01;32";
      ".lz" = "01;32";
      ".lz4" = "01;32";
      ".lzh" = "01;32";
      ".lzma" = "01;32";
      ".lzo" = "01;32";
      ".rar" = "01;32";
      ".rpm" = "01;32";
      ".rz" = "01;32";
      ".sar" = "01;32";
      ".t7z" = "01;32";
      ".tar" = "01;32";
      ".taz" = "01;32";
      ".tbz" = "01;32";
      ".tbz2" = "01;32";
      ".tgz" = "01;32";
      ".tlz" = "01;32";
      ".txz" = "01;32";
      ".tz" = "01;32";
      ".tzo" = "01;32";
      ".tzst" = "01;32";
      ".war" = "01;32";
      ".xz" = "01;32";
      ".z" = "01;32";
      ".Z" = "01;32";
      ".zip" = "01;32";
      ".zoo" = "01;32";
      ".zst" = "01;32";

      #+--- Audio = "---+";
      ".aac" = "32";
      ".au" = "32";
      ".flac" = "32";
      ".m4a" = "32";
      ".mid" = "32";
      ".midi" = "32";
      ".mka" = "32";
      ".mp3" = "32";
      ".mpa" = "32";
      ".ogg" = "32";
      ".opus" = "32";
      ".ra" = "32";
      ".wav" = "32";

      #+--- Customs = "---+";
      ".3des" = "01;35";
      ".aes" = "01;35";
      ".gpg" = "01;35";
      ".pgp" = "01;35";

      #+--- Documents = "---+";
      ".doc" = "32";
      ".docx" = "32";
      ".dot" = "32";
      ".odg" = "32";
      ".odp" = "32";
      ".ods" = "32";
      ".odt" = "32";
      ".otg" = "32";
      ".otp" = "32";
      ".ots" = "32";
      ".ott" = "32";
      ".pdf" = "32";
      ".ppt" = "32";
      ".pptx" = "32";
      ".xls" = "32";
      ".xlsx" = "32";

      #+--- Executables = "---+";
      ".app" = "01;36";
      ".bat" = "01;36";
      ".btm" = "01;36";
      ".cmd" = "01;36";
      ".com" = "01;36";
      ".exe" = "01;36";
      ".reg" = "01;36";

      #+--- Ignores = "---+";
      "*~" = "02;37";
      ".bak" = "02;37";
      ".BAK" = "02;37";
      ".log" = "02;37";
      ".old" = "02;37";
      ".OLD" = "02;37";
      ".orig" = "02;37";
      ".ORIG" = "02;37";
      ".swo" = "02;37";
      ".swp" = "02;37";

      #+--- Images = "---+";
      ".bmp" = "32";
      ".cgm" = "32";
      ".dl" = "32";
      ".dvi" = "32";
      ".emf" = "32";
      ".eps" = "32";
      ".gif" = "32";
      ".jpeg" = "32";
      ".jpg" = "32";
      ".JPG" = "32";
      ".mng" = "32";
      ".pbm" = "32";
      ".pcx" = "32";
      ".pgm" = "32";
      ".png" = "32";
      ".PNG" = "32";
      ".ppm" = "32";
      ".pps" = "32";
      ".ppsx" = "32";
      ".ps" = "32";
      ".svg" = "32";
      ".svgz" = "32";
      ".tga" = "32";
      ".tif" = "32";
      ".tiff" = "32";
      ".xbm" = "32";
      ".xcf" = "32";
      ".xpm" = "32";
      ".xwd" = "32";
      ".yuv" = "32";

      #+--- Video = "---+";
      ".anx" = "32";
      ".asf" = "32";
      ".avi" = "32";
      ".axv" = "32";
      ".flc" = "32";
      ".fli" = "32";
      ".flv" = "32";
      ".gl" = "32";
      ".m2v" = "32";
      ".m4v" = "32";
      ".mkv" = "32";
      ".mov" = "32";
      ".MOV" = "32";
      ".mp4" = "32";
      ".mpeg" = "32";
      ".mpg" = "32";
      ".nuv" = "32";
      ".ogm" = "32";
      ".ogv" = "32";
      ".ogx" = "32";
      ".qt" = "32";
      ".rm" = "32";
      ".rmvb" = "32";
      ".swf" = "32";
        ".vob" = "32";
      ".webm" = "32";
      ".wmv" = "32";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    settings = {
      kubernetes.context_aliases = {
        "gke_[\\\\w]+-prod[\\\\w-]+_scorebet-(?P<cluster>[\\\\w-]+)" = "🔥PROD $cluster PROD🔥";
        "gke_s[\\\\w]+-[\\\\w-]+_scorebet-(?P<cluster>[\\\\w-]+)" = "$cluster";
      };
      format = lib.strings.replaceStrings [ "\n" ] [ "" ] ''
        $username
        $hostname
        $shlvl
        $kubernetes
        $directory
        $git_branch
        $git_commit
        $git_state
        $git_status
        $hg_branch
        $docker_context
        $buf
        $c
        $cmake
        $elixir
        $erlang
        $golang
        $helm
        $java
        $kotlin 
        $nim
        $nodejs
        $ocaml
        $ruby
        $rust
        $terraform
        $zig
        $nix_shell
        $conda
        $memory_usage
        $env_var
        $cmd_duration
        $custom
        $line_break
        $lua
        $jobs
        $battery
        $time
        $status
        $character
      '';
      aws.symbol = " ";
      battery.full_symbol = "";
      battery.charging_symbol = "";
      battery.discharging_symbol = "";
      conda.symbol = " ";
      dart.symbol = " ";
      docker_context.symbol = " ";
      elixir.symbol = " ";
      elm.symbol = " ";
      git_branch.symbol = " ";
      golang.symbol = " ";
      # haskell.symbol = " ";
      hg_branch.symbol = " ";
      kubernetes.disabled = false;
      java.symbol = " ";
      julia.symbol = " ";
      memory_usage.symbol = " ";
      nim.symbol = " ";
      nix_shell.symbol = " ";
      nodejs.symbol = " ";
      package.symbol = " ";
      perl.symbol = " ";
      php.symbol = " ";
      python.symbol = " ";
      ruby.symbol = " ";
      rust.symbol = " ";
      swift.symbol = "ﯣ ";
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv = {
      enable = true;
    };
    config = {
      global = {
        load_dotenv = false;
      };
    };
  };
  
  
  programs.atuin= {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    settings = {
      sync_address = "https://atuin.home.jeffutter.com";
      search_mode = "fuzzy";
      update_check = false;
    };
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
    enableFishIntegration = false;
    changeDirWidgetCommand = "fd --type d";
    defaultCommand = "fd --type f";
    fileWidgetCommand = "fd --type f";
  };

  programs.ssh = {
    enable = true;
    extraOptionOverrides = {
      StrictHostKeyChecking = "no";
      userKnownHostsFile = "/dev/null";
      IgnoreUnknown = "UseKeychain";
      UseKeychain = "yes";
      AddKeysToAgent = "yes";
    };
    matchBlocks = {
      "borg" = {
        host = "borg";
        hostname = "192.168.10.8";
        user = "borg-backup";
        extraOptions = {
          Ciphers = "3des-cbc";
        };
      };
      "k3s" = {
        host = "k3s";
        hostname = "192.168.10.4";
        user = "jeffutter";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "workstation" = {
        host = "workstation";
        hostname = "192.168.10.5";
        user = "jeffutter";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "laptop" = {
        host = "laptop";
        hostname = "192.168.10.9";
        user = "jeffutter";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "old-laptop" = {
        host = "old-laptop";
        hostname = "192.168.10.7";
        user = "jeffutter";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "work" = {
        host = "work";
        hostname = "192.168.10.6";
        user = "Jeffery.Utter";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
    };
  };

  home.sessionVariables = {
    EDITOR = "vim";
  };

  home.language = {
    base = "en_US.UTF-8";
    collate = "en_US.UTF-8";
    ctype = "en_US.UTF-8";
    messages = "en_US.UTF-8";
    monetary = "en_US.UTF-8";
    numeric = "en_US.UTF-8";
    time = "en_US.UTF-8";
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.05";
}
