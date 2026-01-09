{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  inherit (pkgs.lib) optional optionals;

  ssh-copy-id = pkgs.runCommand "ssh-copy-id" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.openssh}/bin/ssh-copy-id $out/bin/ssh-copy-id
  '';

  gnutar = pkgs.gnutar.overrideAttrs (old: {
    configureFlags = [
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

  tokyonights = inputs.tokyonight;

  expert = inputs.expert.packages.${pkgs.system}.default;
in

{
  imports = [ inputs.nixvim.homeModules.nixvim ];

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
      btop
      broot
      brotli
      bun
      bzip2
      cachix
      colmena
      comma
      curl
      difftastic
      dive
      docker
      doctl
      duckdb
      dust
      duf
      eza
      fd
      gawk
      gh
      git-absorb
      git-lfs
      gnused
      gnupg
      grex
      htop
      hyperfine
      hunspell
      hunspellDicts.en_US
      ijq
      imagemagick
      ispell
      jq
      jujutsu
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
      # luajitPackages.lua-lsp
      lua-language-server
      # ltex-lsp
      mprocs
      mosh
      ncdu_1
      nixfmt
      nodejs
      nodePackages.bash-language-server
      ollama
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
      restic
      rsync
      ruplacer
      shellcheck
      sshfs
      sqls
      ssh-copy-id
      telegram-desktop
      gnutar
      #tlaplus
      tmate
      unzip
      unixtools.watch
      vale
      viddy
      # vimPlugins.vimproc-vim
      vips
      vivid
      # (builtins.getFlake "github:jeffutter/wakeonlan-rust/v0.1.1")
      wavpack
      wget
      xz
      yarn
      yq-go
      zstd

      # Fonts
      roboto
      roboto-mono
      input-fonts
      font-awesome

      # Elixir
      beamMinimalPackages.elixir
      # beamMinimalPackages.elixir-ls
      beamMinimalPackages.erlang

      # Rust
      cargo
      cargo-bloat
      # cargo-criterion
      cargo-cross
      cargo-expand
      cargo-flamegraph
      cargo-generate
      cargo-llvm-lines
      cargo-outdated
      cargo-workspaces
      cargo-udeps
      clippy
      rust-analyzer
      rustc
      rustfmt
      sqlx-cli

      # Ai
      claude-code
      (llm.withPlugins {
        llm-cmd = true;
        llm-jq = true;
      })
      shell-gpt

      (python3Packages.python.withPackages (
        ps: with ps; [
          pandas
          pyarrow
        ]
      ))

      # Go
      delve
      go
      gofumpt
      gomodifytags
      #gopls
      gore
      goreleaser
      gotest
      gotools
      impl

      # Fonts
      nerd-fonts.commit-mono
      nerd-fonts.fantasque-sans-mono
      nerd-fonts.fira-code
      nerd-fonts.hack
      nerd-fonts.hasklug
      nerd-fonts.iosevka
      nerd-fonts.monaspace
      nerd-fonts.monoid
      nerd-fonts.jetbrains-mono
      nerd-fonts.sauce-code-pro
    ]
    ++ optionals stdenv.isLinux [
      inotify-tools
    ]
    ++ optionals stdenv.isDarwin [
      aerospace
      fastmail-desktop
      telegram-desktop
    ]
    ++ optionals stdenv.isDarwin (
      with darwin.apple_sdk.frameworks;
      [
      ]
    );

  # nixpkgs.config is set at the NixOS/flake level when using useGlobalPkgs

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  #manual.manpages.enable = false;

  home.file.".zfunc" = {
    source = ../../zfunc;
    recursive = true;
  };

  home.file."Applications" =
    let
      apps = pkgs.buildEnv {
        name = "home-manager-applications";
        paths = config.home.packages;
        pathsToLink = [ "/Applications" ];
      };
    in
    lib.mkIf pkgs.stdenv.targetPlatform.isDarwin {
      source = "${apps}/Applications";
      recursive = true;
    };

  home.file."bin/upgrade" = {
    source = ../../bin/upgrade;
    executable = true;
  };

  home.file.".config/vivid" = {
    source = ../../vivid;
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
        "--account"
        "my.1password.com"
        "'Fastmail (Himalaya)'"
        "--fields"
        "password"
      ];
    };
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        email = "jeff@jeffutter.com";
        name = "Jeffery Utter";
      };
      ui = {
        default-command = "log";
      };
    };
  };

  programs.himalaya = {
    enable = true;
    settings = {
      name = "Jeffery Utter";
    };
  };

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.nixvim = {
    enable = true;

    globals.mapleader = " ";

    globalOpts = {
      termguicolors = true;
      encoding = "utf-8";
      fileencoding = "utf-8";
    };

    opts = {
      foldenable = true;
      foldexpr = "v:lua.vim.treesitter.foldexpr()";
      foldlevel = 5;
      foldlevelstart = 99;
      foldmethod = "expr";
      number = true;
      spell = true;
      spelllang = "en_us";
    };

    colorschemes.tokyonight = {
      enable = true;
      style = "moon";
    };

    lsp = {
      enable = true;
      inlayHints.enable = true;

      # lazyLoad = {
      #   enable = true;
      #   settings = {
      #     event = "User FilePost";
      #     cmd = [
      #       "LspRestart"
      #       "LspLog"
      #       "LspInfo"
      #       "LspStart"
      #       "LspStop"
      #     ];
      #   };
      # };

      servers = {
        lua_ls.enable = true;
        nixd = {
          enable = true;
          config = {
            formatting.command = [ "nixpkgs-fmt" ];
            options = {
              home-manager = {
                expr = "(import <home-manager/modules> { configuration = ~/.config/home-manager/home.nix; pkgs = import <nixpkgs> {}; }).options";
              };
            };
          };
        };
        expert = {
          enable = true;
          package = expert;
        };
        rust_analyzer = {
          enable = true;
        };
      };

      keymaps = [
        {
          key = "grr";
          action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.picker.lsp_references() end";
          options.desc = "Lsp References";
        }
        {
          key = "gd";
          action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.picker.lsp_definitions() end";
          options.desc = "Lsp Definitions";
        }
        {
          key = "gry";
          action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.picker.lsp_type_definitions() end";
          options.desc = "Lsp T[y]pe Definitions";
        }
        {
          key = "<leader>ss";
          action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.picker.lsp_symbols() end";
          options.desc = "Lsp Symbols";
        }
        {
          key = "<leader>sS";
          action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.picker.lsp_workspace_symbols() end";
          options.desc = "Lsp Workspace Symbols";
        }

        {
          key = "<leader>ca";
          lspBufAction = "code_action";
          options.desc = "[C]ode [Action]";
        }

        {
          mode = "n";
          key = "<leader>Rr";
          action = "<cmd>RustLsp runnables<CR>";
          options.desc = "Rust Runnables";
        }
        {
          mode = "n";
          key = "<leader>dR";
          action = "<cmd>RustLsp debuggables<CR>";
          options.desc = "Rust Debuggables";
        }
        {
          mode = "n";
          key = "<leader>Ra";
          action = "<cmd>RustLsp codeAction<CR>";
          options.desc = "Code Action (Rust)";
        }
        {
          mode = "n";
          key = "<leader>Rh";
          action = "<cmd>RustLsp hover actions<CR>";
          options.desc = "Hover Actions (Rust)";
        }
        {
          mode = "n";
          key = "<leader>Rm";
          action = "<cmd>RustLsp expandMacro<CR>";
          options.desc = "Expand Macro";
        }
        {
          mode = "n";
          key = "<leader>RM";
          action = "<cmd>RustLsp rebuildProcMacros<CR>";
          options.desc = "Rebuild Proc Macros";
        }
        {
          mode = "n";
          key = "<leader>Rd";
          action = "<cmd>RustLsp openDocs<CR>";
          options.desc = "Open Docs";
        }
        {
          mode = "n";
          key = "<leader>Rc";
          action = "<cmd>RustLsp openCargo<CR>";
          options.desc = "Open Cargo.toml";
        }
        {
          mode = "n";
          key = "<leader>Rg";
          action = "<cmd>RustLsp crateGraph<CR>";
          options.desc = "Crate Graph";
        }
      ];
    };

    plugins = {
      actions-preview.enable = true;
      blink-emoji.enable = true;
      blink-ripgrep.enable = true;
      blink-cmp-spell.enable = true;
      comment.enable = true;
      cursorline.enable = true;
      fidget.enable = true;
      gitsigns.enable = true;
      lastplace.enable = true;
      lspconfig.enable = true;
      lualine.enable = true;
      luasnip.enable = true;
      nix.enable = true;
      nvim-surround.enable = true;
      nvim-autopairse.enable = true;
      rustaceanvim.enable = true;
      sleuth.enable = true;
      todo-comments.enable = true;
      trouble.enable = true;
      web-devicons.enable = true;
      which-key.enable = true;
      spectre.enable = true;

      blink-cmp = {
        enable = true;

        settings = {

          keymap.preset = "super-tab";

          completion = {
            documentation = {
              auto_show = true;
              auto_show_delay_ms = 500;
            };
            ghost_text = {
              enabled = true;
            };
            accept.auto_brackets.enabled = true;
          };

          sources = {
            default = [
              "lsp"
              "path"
              "snippets"
              "emoji"
              "buffer"
              "ripgrep"
              "spell"
            ];
            providers = {
              lsp = {
                fallbacks = [ ];
                score_offset = 10;
              };
              emoji = {
                module = "blink-emoji";
                name = "Emoji";
                score_offset = 15;
                opts = {
                  insert = true;
                };
              };
              spell = {
                module = "blink-cmp-spell";
                name = "Spell";
                opts = {
                  spell = false;
                  spelllang = "en_us";
                };
              };
              ripgrep = {
                async = true;
                module = "blink-ripgrep";
                name = "Ripgrep";
                score_offset = -5;
                opts = {
                  prefix_min_len = 3;
                  backend = {
                    context_size = 5;
                    max_filesize = "2M";
                    search_casing = "--smart-case";
                  };
                };
              };
            };
          };

          snippets = {
            preset = "luasnip";
          };

          signature = {
            enabled = true;
          };
        };
      };

      conform-nvim = {
        enable = true;
        settings = {
          format_on_save = {
            timeout_ms = 5000;
            lsp_fallback = true;
          };
        };
      };

      flash = {
        enable = true;
        settings = {
          continue = true;
          modes.char.jump_labels = true; # `f` `t` `F` and `T` with labels
        };
      };

      neotest = {
        enable = true;
        adapters = {
          elixir.enable = true;
          rust.enable = true;
        };
      };

      snacks = {
        enable = true;
        settings = {
          bigfile.enabled = true;
          explorer.enabled = true;
          indent.enable = true;
          picker = {
            enabled = true;
            ui_select = true;
          };
          notifier.enabled = true;
          statuscolumn.enabled = true;
          words.enabled = true;
        };
      };

      treesitter = {
        enable = true;
        autoLoad = true;

        nixvimInjections = true;

        settings = {
          folding.enable = true;
          highlight.enable = true;
          indent.enable = true;
        };

        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          bash
          elixir
          erlang
          json
          graphql
          lua
          make
          markdown
          nix
          regex
          rust
          toml
          yaml
        ];
      };
    };

    keymaps = [
      {
        key = "<leader>sf";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.picker.files() end";
        options.desc = "[S]earch [F]iles";
      }
      {
        key = "<leader><leader>";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.picker.buffers() end";
        options.desc = "Search Buffers";
      }
      {
        key = "<leader>sr";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.picker.recent() end";
        options.desc = "[S]earch [R]ecent";
      }

      {
        key = "<leader>sg";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.picker.grep() end";
        options.desc = "[S]earch [G]rep";
      }

      {
        key = "<leader>hk";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.picker.keymaps() end";
        options.desc = "Search [H]elp [K]eymaps";
      }
      {
        key = "<leader>hC";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.picker.commands() end";
        options.desc = "Search [H]elp [C]ommands";
      }
      {
        key = "<leader>ht";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.picker.help() end";
        options.desc = "Search [H]elp [T]ags";
      }

      {
        key = "<leader>ft";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() Snacks.explorer() end";
        options.desc = "[F]ile [T]ree";
      }

      {
        key = "<leader>xx";
        mode = [ "n" ];
        action = "<cmd>Trouble diagnostics toggle<CR>";
        options.desc = "Diagnostics";
      }
      {
        key = "<leader>xX";
        mode = [ "n" ];
        action = "<cmd>Trouble diagnostics toggle filter.buf=0<CR>";
        options.desc = "Buffer Diagnostics";
      }

      {
        key = "<leader>S";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() require(\"spectre\").open() end";
        options.desc = "[S]pectre";
      }
      {
        key = "<leader>sw";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() require(\"spectre\").open_visual({ select_word = true }) end";
        options.desc = "[S]pectre [W]ord";
      }
      {
        key = "<leader>sp";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() require(\"spectre\").open_file_search() end";
        options.desc = "[S]pectre [p]File";
      }

      {
        key = "<leader>mta";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() require(\"neotest\").run.run({suite=true}) end";
        options.desc = "[T]est [A]ll";
      }
      {
        key = "<leader>mts";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() require(\"neotest\").run.run() end";
        options.desc = "[T]est [S]ingle";
      }
      {
        key = "<leader>mtf";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() require(\"neotest\").run.run(vim.fn.expand(\"%\")) end";
        options.desc = "[T]est [F]ile";
      }
      {
        key = "<leader>mtr";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() require(\"neotest\").run.run_last() end";
        options.desc = "[T]est [R]erun [L]ast";
      }
      {
        key = "<leader>mtS";
        mode = [ "n" ];
        action = inputs.nixvim.lib.nixvim.mkRaw "function() require(\"neotest\").summary.toggle() end";
        options.desc = "[T]est [S]ummary";
      }
    ];
  };

  programs.difftastic = {
    enable = true;
    git = {
      enable = true;
    };
  };

  programs.delta = {
    enable = false;
    options = {
      side-by-side = true;
      line-numbers-left-format = "";
      line-numbers-right-format = "│ ";
    };

  };

  programs.git = {
    enable = true;
    settings = {
      aliases = {
        dft = "difftool";
        diffp = "--no-ext-diff";
      };
      user = {
        name = "Jeffery Utter";
        email = "jeff@jeffutter.com";
      };
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
    includes = [ { path = (tokyonights + "/extras/delta/tokyonight_moon.gitconfig"); } ];
    ignores = [
      ".DS_Store?"
      ".Spotlight-V100"
      ".Trashes"
      "._*"
      ".aider*"
      ".direnv"
      ".elixir_ls"
      ".envrc"
      ".vscode"
      "DS_Store"
      "Thumbs.db"
      "ehthumbs.db"
      "hs_err*"
      "project-notes.org"
      "project_notes.org"
      "shell.nix"
    ];
  };

  programs.kitty = {
    enable = true;
    extraConfig = ''
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

  programs.ghostty = {
    package = lib.mkIf pkgs.stdenv.targetPlatform.isDarwin (
      pkgs.runCommandLocal "empty" { } "mkdir $out"
    );
    installBatSyntax = lib.mkIf pkgs.stdenv.targetPlatform.isDarwin false; # Fix in master
    settings = {
      shell-integration-features = "no-cursor";
      font-family = "MonaspiceNe NFM";
      font-family-bold = "MonaspiceNe NFM Bold";
      font-family-italic = "MonaspiceRn NFM Italic";
      font-family-bold-italic = "MonaspiceRn NFM Bold Italic";
      font-thicken = false;
      font-size = 11;
      font-feature = [
        "ss01"
        "ss02"
        "ss03"
        "ss04"
        "ss05"
        "ss06"
        "ss07"
        "ss08"
        "ss09"
        "calt"
        "liga"
      ];
      window-decoration = false;
      macos-titlebar-style = "hidden";

      cursor-style-blink = false;

      theme = (tokyonights + "/extras/ghostty/tokyonight_moon");
    };
  };

  programs.zellij = {
    enable = true;
    enableZshIntegration = false;
    enableFishIntegration = false;
    settings = {
      theme = "tokyo-night-storm";
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
    extraConfig = ''
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
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    settings = {
      kubernetes.context_aliases = {
        "gke_[\\\\w]+-prod[\\\\w-]+_scorebet-(?P<cluster>[\\\\w-]+)" = "PROD $cluster PROD";
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
      aws.symbol = " ";
      battery.full_symbol = "";
      battery.charging_symbol = "";
      battery.discharging_symbol = "";
      conda.symbol = " ";
      dart.symbol = " ";
      docker_context.symbol = " ";
      elixir.symbol = " ";
      elm.symbol = " ";
      git_branch.symbol = " ";
      golang.symbol = " ";
      # haskell.symbol = " ";
      hg_branch.symbol = " ";
      kubernetes.disabled = false;
      java.symbol = " ";
      julia.symbol = " ";
      memory_usage.symbol = " ";
      nim.symbol = " ";
      nix_shell.symbol = " ";
      nodejs.symbol = " ";
      package.symbol = " ";
      perl.symbol = " ";
      php.symbol = " ";
      python.symbol = " ";
      ruby.symbol = " ";
      rust.symbol = " ";
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
    enableDefaultConfig = false;
    extraOptionOverrides = {
      StrictHostKeyChecking = "no";
      userKnownHostsFile = "/dev/null";
      IgnoreUnknown = "UseKeychain";
      UseKeychain = "yes";
      AddKeysToAgent = "yes";
    };
    matchBlocks = {
      "homelab" = {
        host = "homelab";
        hostname = "192.168.10.4";
        user = "root";
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
      "work" = {
        host = "work";
        hostname = "192.168.10.6";
        user = "Jeffery.Utter";
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
      "borg" = {
        host = "borg";
        hostname = "192.168.10.8";
        user = "borg-backup";
        extraOptions = {
          Ciphers = "3des-cbc";
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
      "ns1" = {
        host = "ns1";
        hostname = "192.168.10.11";
        user = "root";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "zenbook" = {
        host = "zenbook";
        hostname = "192.168.10.12";
        user = "jeffutter";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "llm" = {
        host = "llm";
        hostname = "192.168.10.17";
        user = "root";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "* !github.com-penn-interactive" = {
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  }
  // lib.optionalAttrs (builtins.compareVersions lib.trivial.release "25.05" <= 0) {
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        forwardAgent = false;
        compression = true;
        addKeysToAgent = "no";
        hashKnownHosts = true;
        userKnownHostsFile = "~/.ssh/known_hosts";
        identityFile = "~/.ssh/id_ed25519";
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

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";
}
