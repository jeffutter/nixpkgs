{
  pkgs,
  inputs,
  ...
}:

{
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

    lsp = {
      enable = true;
      inlayHints.enable = true;

      servers = {
        bashls.enable = true;
        lua_ls.enable = true;
        sqls.enable = true;
        vale_ls.enable = true;
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
      ];
    };

    plugins = {
      actions-preview.enable = true;
      blink-cmp-spell.enable = true;
      blink-emoji.enable = true;
      blink-ripgrep.enable = true;
      comment.enable = true;
      cursorline.enable = true;
      fidget.enable = true;
      gitsigns.enable = true;
      lastplace.enable = true;
      lspconfig.enable = true;
      lualine.enable = true;
      luasnip.enable = true;
      nix.enable = true;
      nvim-autopairse.enable = true;
      nvim-surround.enable = true;
      render-markdown.enable = true;
      sleuth.enable = true;
      spectre.enable = true;
      todo-comments.enable = true;
      trouble.enable = true;
      web-devicons.enable = true;
      which-key.enable = true;

      neotest.enable = true;

      blink-cmp = {
        enable = true;

        settings = {

          keymap.preset = "enter";

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
            providers =
              let
                dedupeTransform = inputs.nixvim.lib.nixvim.mkRaw ''
                  function(ctx, items)
                    if not ctx.seen then ctx.seen = {} end
                    return vim.iter(items):filter(function(item)
                      if item.label and ctx.seen[item.label] then return false end
                      ctx.seen[item.label] = true
                      return true
                    end):totable()
                  end
                '';
              in
              {
                lsp = {
                  fallbacks = [ ];
                  score_offset = 10;
                  transform_items = dedupeTransform;
                };
                buffer = {
                  transform_items = dedupeTransform;
                };
                path = {
                  transform_items = dedupeTransform;
                };
                snippets = {
                  transform_items = dedupeTransform;
                };
                emoji = {
                  module = "blink-emoji";
                  name = "Emoji";
                  score_offset = 15;
                  transform_items = dedupeTransform;
                  opts = {
                    insert = true;
                  };
                };
                spell = {
                  module = "blink-cmp-spell";
                  name = "Spell";
                  transform_items = dedupeTransform;
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
                  transform_items = dedupeTransform;
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

      obsidian = {
        enable = true;
        settings = {
          workspaces = [
            {
              name = "Jeffery Utter";
              path = "~/obsidian/Jeffery Utter";
            }
          ];
          daily_notes = {
            folder = "0. PeriodicNotes";
            date_format = "%Y/Daily/%m/%Y-%m-%d";
            workdays_only = false;
          };
          picker.name = "snacks.pick";
          completion.blink = true;
          legacy_commands = false;
        };

        keymaps = [
          {
            action = "<cmd>Obsidian quick_switch<CR>";
            key = "<leader>nf";
            options = {
              silent = true;
              desc = "Find Notes";
            };
          }
          {
            action = "<cmd>Obsidian search<CR>";
            key = "<leader>ns";
            options = {
              silent = true;
              desc = "Search Note Contents";
            };
          }
          {
            action = "<cmd>Obsidian new<CR>";
            key = "<leader>nn";
            options = {
              silent = true;
              desc = "Create New Note";
            };
          }
          {
            action = "<cmd>Obsidian link_new<CR>";
            key = "<leader>nn";
            mode = [ "v" ];
            options = {
              silent = true;
              desc = "Create New Note from selection";
            };
          }
          {
            action = "<cmd>Obsidian template<CR>";
            key = "<leader>nc";
            options = {
              silent = true;
              desc = "Insert Template";
            };
          }
          {
            action = "<cmd>Obsidian open<CR>";
            key = "<leader>no";
            options = {
              silent = true;
              desc = "Open in Obsidian";
            };
          }
          {
            action = "<cmd>Obsidian backlinks<CR>";
            key = "<leader>nb";
            options = {
              silent = true;
              desc = "Show Backlinks";
            };
          }
          {
            action = "<cmd>Obsidian today<CR>";
            key = "<leader>nT";
            options = {
              silent = true;
              desc = "Open Todays Note";
            };
          }
          {
            action = "<cmd>Obsidian tags<CR>";
            key = "<leader>nt";
            options = {
              silent = true;
              desc = "Show Tags";
            };
          }
        ];
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

        # Base grammars - language-specific ones added by language modules
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          bash
          json
          graphql
          lua
          make
          markdown
          nix
          regex
          yaml
        ];
      };
    };

    extraPlugins = [
      pkgs.vimPlugins.csvview-nvim
    ];

    extraConfigLua = ''
      require('csvview').setup()
    '';

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
}
