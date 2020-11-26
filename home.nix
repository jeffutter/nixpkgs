{ config, pkgs, lib, ... }:

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
  k9s = pkgs.callPackage pkgs/k9s {};
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
    k9s
    kubectl
    kubernetes-helm
    lftp
    lorri
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
      sha256 = "1nmdq5rs6sd21hll3ci31hqxkwqdprwj9yz81ins62r1l2b2vdjk";
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
  home.file.".spacemacs".source = ./spacemacs.el;

  home.file.".config/topgrade.toml".source = ./topgrade.toml;

  home.file."Brewfile".source = ./Brewfile;

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

  home.file."Library/LaunchAgents/com.github.target.lorri.plist" = {
    text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
	  <key>Label</key>
	  <string>com.github.target.lorri</string>
	  <key>ProgramArguments</key>
	  <array>
	      <string>/bin/zsh</string>
	      <string>-i</string>
	      <string>-c</string>
	      <string>${pkgs.lorri}/bin/lorri daemon</string>
	  </array>
	  <key>StandardOutPath</key>
	  <string>/var/tmp/lorri.log</string>
	  <key>StandardErrorPath</key>
	  <string>/var/tmp/lorri.log</string>
	  <key>RunAtLoad</key>
	  <true/>
	  <key>KeepAlive</key>
	  <true/>
      </dict>
      </plist>
    '';
    onChange = "launchctl load ~/Library/LaunchAgents/com.github.target.lorri.plist";
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
      "shell.nix"
      ".envrc"
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
    extraConfig = ''
set-option -g default-command "zsh"
    '';
    plugins = with pkgs.tmuxPlugins; [
      nord
      yank
      prefix-highlight
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
      export LANG="en_US.UTF-8"
      export LC_COLLATE="en_US.UTF-8"
      export LC_CTYPE="en_US.UTF-8"
      export LC_MESSAGES="en_US.UTF-8"
      export LC_MONETARY="en_US.UTF-8"
      export LC_NUMERIC="en_US.UTF-8"
      export LC_TIME="en_US.UTF-8"
      export LC_ALL="en_US.UTF-8"
      if [ -e /Users/jeffutter/.nix-profile/etc/profile.d/nix.sh ]; then . /Users/jeffutter/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer
      export PATH=$HOME/bin:$PATH
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
        unalias -m 'df'
        alias df='duf'
      fi

      export PATH=$HOME/bin:$PATH
    '';
  };

  programs.keychain = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.dircolors = {
    enable = true;
    enableZshIntegration = true;
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
    settings = {
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
        $cmake
        $elixir
        $erlang
        $golang
        $helm
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
      docker.symbol = " ";
      elixir.symbol = " ";
      elm.symbol = " ";
      git_branch.symbol = " ";
      golang.symbol = " ";
      haskell.symbol = " ";
      hg_branch.symbol = " ";
      java.symbol = " ";
      julia.symbol = " ";
      memory_usage.symbol = " ";
      nim.symbol = " ";
      nix_shell.symbol = " ";
      node_js.symbol = " ";
      package.symbol = " ";
      perl.symbol = " ";
      php.symbol = " ";
      python.symbol = " ";
      ruby.symbol = " ";
      rust.symbol = " ";
      swit.symbol = "ﯣ ";
    };
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

  programs.ssh = {
    enable = true;
    extraOptionOverrides = {
      StrictHostKeyChecking = "no";
      userKnownHostsFile = "/dev/null";
      IgnoreUnknown = "UseKeychain";
      UseKeychain = "yes";
      AddKeysToAgent = "yes";
      identityFile = "~/.ssh/id_rsa";
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
