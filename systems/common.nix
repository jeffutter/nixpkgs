{
  config,
  pkgs,
  lib,
  mkIf,
  platforms,
  ...
}:

let
  inherit (pkgs.lib) optional optionals;

  nixGL = import ./nixGL.nix { inherit pkgs config; };

  # Temporary until 0.10 is released
  neovim-nightly-overlay = (
    import (
      builtins.fetchTarball {
        url = "https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz";
      }
    )
  );

  ssh-copy-id = pkgs.runCommand "ssh-copy-id" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.openssh}/bin/ssh-copy-id $out/bin/ssh-copy-id
  '';

  gnutar = pkgs.gnutar.overrideAttrs (old: {
    configureFlags =
      [
        "--with-gzip=pigz"
        "--with-xz=pixz"
        "--with-bzip2=pbzip2"
        "--with-zstd=pzstd"
      ]
      ++ optionals pkgs.stdenv.isDarwin [
        "gt_cv_func_CFPreferencesCopyAppValue=no"
        "gt_cv_func_CFLocaleCopyCurrent=no"
        "gt_cv_func_CFLocaleCopyPreferredLanguages=no"
      ];
  });

  my_wakeonlan = pkgs.callPackage ../pkgs/wakeonlan { };

  ltex-lsp = pkgs.callPackage ../pkgs/ltex-lsp { };

  my_fonts = pkgs.nerdfonts.override {
    fonts = [
      "CommitMono"
      "FantasqueSansMono"
      "FiraCode"
      "Hack"
      "Hasklig"
      "Iosevka"
      "Monaspace"
      "Monoid"
      "JetBrainsMono"
      "SourceCodePro"
    ];
  };

  fromYaml =
    path:
    let
      jsonOutputDrv = pkgs.runCommand "from-yaml" {
        nativeBuildInputs = [ pkgs.remarshal ];
      } ''remarshal -if yaml -i "${path}" -of json -o "$out"'';
    in
    builtins.fromJSON (builtins.readFile jsonOutputDrv);

  tokyonights = pkgs.fetchFromGitHub {
    owner = "folke";
    repo = "tokyonight.nvim";
    rev = "v3.0.1";
    sha256 = "sha256-Hgp4mN7uVTWzr3qTozeM6zHcxxe1wkC3xGBnrogsJ4g=";
  };
in

{
  imports = [ ./options.nix ];

  home.packages =
    with pkgs;
    [
      aspell
      aspellDicts.en
      aspellDicts.en-computers
      autoconf
      bandwhich
      bash-completion
      bash
      # borgbackup
      bottom
      broot
      brotli
      bzip2
      comma
      curl
      difftastic
      dive
      docker
      doctl
      du-dust
      duf
      eza
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
      (pkgs.kubectl-node-shell.overrideAttrs (
        {
          meta ? { },
          ...
        }:
        {
          meta = meta // {
            platforms = pkgs.lib.platforms.unix;
          };
        }
      ))
      lftp
      ltex-lsp
      mprocs
      mosh
      ncdu_1
      nixfmt-rfc-style
      nodejs
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
      nil
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
      vivid
      my_wakeonlan
      wavpack
      wget
      xz
      yarn
      yq-go
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
      # cargo-criterion
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
      gopls
      gore
      goreleaser
      gotest
    ]
    ++ optional stdenv.isLinux inotify-tools
    ++ optionals stdenv.isDarwin [ skhd ]
    ++ optionals stdenv.isDarwin (
      with darwin.apple_sdk.frameworks;
      [
        CoreFoundation
        CoreServices
      ]
    );

  nixpkgs.overlays = [ neovim-nightly-overlay ];
  nixpkgs.config.permittedInsecurePackages = [ "p7zip-16.02" ];

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

  home.file.".config/vivid" = {
    source = ../vivid;
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
        settings = {
          backend = "imap";
          sender = "smtp";
        };
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
      passwordCommand = [
        "op"
        "item"
        "get"
        "Fastmail Himalaya"
        "--fields"
        "password"
      ];
    };
    work = {
      primary = false;
      realName = "Jeffery Utter";
      address = "jeffery.utter@thescore.com";
      flavor = "gmail.com";
      himalaya = {
        enable = true;
        settings = {
          backend = "imap";
          sender = "smtp";
        };
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
      passwordCommand = [
        "op"
        "item"
        "get"
        "Gmail (theScore) (Himalaya)"
        "--fields"
        "password"
      ];
    };
  };

  programs.himalaya = {
    enable = false;
    settings = {
      name = "Jeffery Utter";
      default-page-size = 50;
    };
  };

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.neovim = {
    package = pkgs.neovim-nightly;
    enable = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [ ];
  };

  home.file.".config/nvim/init.lua" = {
    source = ../nvim/init.lua;
  };

  home.file.".config/nvim/lua" = {
    source = ../nvim/lua;
    recursive = true;
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
      init = {
        defaultBranch = "main";
      };
    };
    aliases = {
      dft = "difftool";
      diffp = "--no-ext-diff";
    };
    delta = {
      enable = false;
      options = {
        side-by-side = true;
        line-numbers-left-format = "";
        line-numbers-right-format = "│ ";
      };
    };
    difftastic = {
      enable = true;
    };
    includes = [ { path = (tokyonights + "/extras/delta/tokyonight_moon.gitconfig"); } ];
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
    package = (nixGL pkgs.alacritty);
    settings = {
      live_config_reload = true;
      window = {
        decorations = "none";
      };
      font = {
        normal = {
          family = "MonaspiceNe Nerd Font Mono";
          style = "Regular";
        };
        bold = {
          family = "MonaspiceNe Nerd Font Mono";
          style = "Bold";
        };
        italic = {
          family = "MonaspiceRn Nerd Font Mono";
          style = "Regular";
        };
        bold_italic = {
          family = "MonaspiceRn Nerd Font Mono";
          style = "Bold";
        };
        size = 11.0;
      };
      colors = (fromYaml (tokyonights + "/extras/alacritty/tokyonight_moon.yml")).colors;
    };
  };

  programs.kitty = {
    enable = true;
    package = (nixGL pkgs.kitty);
    extraConfig =
      ''
        font_features MonoLisaNerdFont-Italic +ss02
        font_features MonoLisaNerdFont-Bold-Italic +ss02
        font_features MonaspiceRnNFM-Italic +ss02
        font_features MonaspiceRnNFM-BoldItalic +ss02
      ''
      + builtins.readFile (tokyonights + "/extras/kitty/tokyonight_moon.conf");
    settings = {
      font_family = "MonaspiceNe Nerd Font Mono";
      bold_font = "MonaspiceNe Nerd Font Mono Bold";
      bold_italic_font = "MonaspiceRn Nerd Font Mono Bold";
      italic_font = "MonaspiceRn Nerd Font Mono Regular";

      macos_titlebar_color = "background";
      tab_bar_style = "powerline";
      macos_colorspace = "default";
      draw_minimal_borders = "yes";
      hide_window_decorations = "titlebar-and-corners";

      dynamic_background_opacity = "yes";
      background_blur = "33";
    };
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
    extraConfig =
      ''
        set-option -g default-command "fish"
        set -ga terminal-overrides ",*256col*:Tc"
        set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'  # undercurl support
        set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'  # underscore colours - needs tmux-3.0
        set -g status-keys vi
        set -g mode-keys   vi
        bind-key N swap-window -t +1 \; next-window
        bind-key P swap-window -t -1 \; previous-window
      ''
      + builtins.readFile (tokyonights + "/extras/tmux/tokyonight_moon.tmux");
    plugins = with pkgs.tmuxPlugins; [
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
      gco = "git checkout";
      gpf = "git push --force";
      h = "himalaya";
      k = "kubectl";
      kctx = "kubectx";
      kns = "kubens";
    };
    shellAliases = {
      bzip2 = "pbzip2";
      cat = "bat -pp";
      df = "duf";
      gunzip = "pigz -d";
      gz = "pigz";
      ll = "eza -l --color always --icons -a -s type";
      ls = "eza -G --color auto -s type";
      xz = "pixz";
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
    interactiveShellInit =
      ''
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
        set -x EDITOR "nvim";

        set -x LS_COLORS "$(vivid generate tokyonight_moon)"
      ''
      + builtins.readFile (tokyonights + "/extras/fish/tokyonight_moon.fish");
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

      if [ -n "$(find ~/.zfunc -prune -empty)" ]; then
        export fpath=( ~/.zfunc "''${fpath[@]}" )
        autoload -U $fpath[1]/*(:t)
      fi
    '';
    initExtra = ''
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

      export LS_COLORS="$(vivid generate tokyonight_moon)"
    '';
  };

  programs.topgrade = {
    enable = true;
    settings = {
      misc = {
        disable = [
          "yadm"
          "node"
          "gem"
          "nix"
          "gcloud"
          "opam"
        ];
        ignore_failures = [ "containers" ];
        cleanup = true;
      };
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

  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    settings = {
      sync_address = "https://atuin.home.jeffutter.com";
      search_mode = "fuzzy";
      update_check = false;
      # https://github.com/atuinsh/atuin/issues/1749
      timezone = "-6";
    };
  };

  programs.bat = {
    enable = true;
    themes = {
      tokyonight = {
        src = (tokyonights + "/extras/sublime/tokyonight_moon.tmTheme");
      };
    };
    config = {
      theme = "tokyonight";
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
      "uconsole" = {
        host = "uconsole";
        hostname = "192.168.10.16";
        user = "jeffutter";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
    };
  };

  home.sessionVariables = {
    EDITOR = "nvim";
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

  nix = {
    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
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
