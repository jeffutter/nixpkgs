-- LSP settings.
--  This function gets run when an LSP connects to a particular buffer.
local on_attach = function(_, bufnr)
  -- NOTE: Remember that lua is a real programming language, and as such it is possible
  -- to define small helper and utility functions so you don't have to repeat yourself
  -- many times.
  --
  -- In this case, we create a function that lets us more easily define mappings specific
  -- for LSP related items. It sets the mode, buffer and description for us each time.
  local nmap = function(keys, func, desc)
    if desc then
      desc = 'LSP: ' .. desc
    end

    vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
  end

  nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
  nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

  nmap('gd', vim.lsp.buf.definition, '[G]oto [D]efinition')
  nmap('gi', vim.lsp.buf.implementation, '[G]oto [I]mplementation')
  nmap('gr', require('telescope.builtin').lsp_references)
  nmap('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
  nmap('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

  -- See `:help K` for why this keymap
  nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
  nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')

  -- Lesser used LSP functionality
  nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
  nmap('<leader>D', vim.lsp.buf.type_definition, 'Type [D]efinition')
  nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
  nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
  nmap('<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, '[W]orkspace [L]ist Folders')

  -- Create a command `:Format` local to the LSP buffer
  vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
    if vim.lsp.buf.format then
      vim.lsp.buf.format()
    elseif vim.lsp.buf.formatting then
      vim.lsp.buf.formatting()
    end
  end, { desc = 'Format current buffer with LSP' })
end

return {
  'tpope/vim-fugitive', -- Git commands in nvim
  'tpope/vim-rhubarb', -- Fugitive-companion to interact with github
  'tpope/vim-repeat',
  {
    'lewis6991/gitsigns.nvim', -- Add git related info in the signs columns and popups
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    }
  },
  { 'numToStr/Comment.nvim', config = true }, -- "gc" to comment visual regions/lines
  {
    'nvim-treesitter/nvim-treesitter', -- Highlight, edit, and navigate code
    config = function()
      -- See `:help telescope.builtin`
      vim.keymap.set('n', '<leader>?', require('telescope.builtin').oldfiles, { desc = '[?] Find recently opened files' })
      vim.keymap.set('n', '<leader><space>', require('telescope.builtin').buffers, { desc = '[ ] Find existing buffers' })
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to telescope to change theme, layout, etc.
        require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer]' })

      vim.keymap.set('n', '<leader>sf', require('telescope.builtin').find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>sh', require('telescope.builtin').help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sw', require('telescope.builtin').grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', require('telescope.builtin').live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = '[S]earch [D]iagnostics' })

    end
  },
  { 'nvim-treesitter/nvim-treesitter-textobjects', dependencies = { 'nvim-treesitter' } }, -- Additional textobjects for treesitter
  'p00f/nvim-ts-rainbow',
  {
    'neovim/nvim-lspconfig', -- Collection of configurations for built-in LSP client
    event = "BufReadPre",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      -- nvim-cmp supports additional completion capabilities
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- Enable the following language servers
      local servers = { 'clangd', 'rust_analyzer', 'sumneko_lua', 'tsserver', 'cssls', 'svelte', 'tailwindcss', 'html' }

      -- Ensure the servers above are installed
      require('mason-lspconfig').setup {
        ensure_installed = servers,
      }

      for _, lsp in ipairs(servers) do
        require('lspconfig')[lsp].setup {
          on_attach = on_attach,
          capabilities = capabilities,
        }
      end

      local installed_servers = { 'bashls' }
      for _, lsp in ipairs(installed_servers) do
        require('lspconfig')[lsp].setup {
          on_attach = on_attach,
          capabilities = capabilities,
        }
      end

      require('lspconfig')['ltex'].setup {
        on_attach = on_attach,
        cmd = { "ltex-ls" },
        filetypes = { "text", "plaintex", "tex", "markdown" },
        settings = {
          ltex = {
            language = "en"
          },
        },
        flags = { debounce_text_changes = 300 },
      }

      -- Example custom configuration for lua
      --
      -- Make runtime files discoverable to the server
      local runtime_path = vim.split(package.path, ';')
      table.insert(runtime_path, 'lua/?.lua')
      table.insert(runtime_path, 'lua/?/init.lua')

      require('lspconfig').sumneko_lua.setup {
        on_attach = on_attach,
        capabilities = capabilities,
        settings = {
          Lua = {
            runtime = {
              -- Tell the language server which version of Lua you're using (most likely LuaJIT)
              version = 'LuaJIT',
              -- Setup your lua path
              path = runtime_path,
            },
            diagnostics = {
              globals = { 'vim' },
              unusedLocalExclude = { "_*" },
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file('', true),
              checkThirdParty = false
            },
            -- Do not send telemetry data containing a randomized but unique identifier
            telemetry = { enable = false },
          },
        },
      }
    end
  },
  {
    'williamboman/mason.nvim', -- Manage external editor tooling i.e LSP servers
    config = true,
  },
  'williamboman/mason-lspconfig.nvim', -- Automatically install language servers to stdpath
  {
    'hrsh7th/nvim-cmp', -- Autocompletion
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'f3fora/cmp-spell',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-emoji',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-vsnip',
      'hrsh7th/cmp-cmdline',
      'saadparwaiz1/cmp_luasnip',
    },
    config = function()
      -- nvim-cmp setup
      local cmp = require 'cmp'
      local luasnip = require 'luasnip'

      cmp.setup {
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert {
          ['<C-d>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          },
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'buffer' },
          -- { name = 'emoji' },
          { name = 'path' },
          { name = 'vsnip' },
          { name = 'spell' },
        },
      }

      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline", keyword_length = 2 } }),
      })
    end
  },
  { 'L3MON4D3/LuaSnip', dependencies = { 'saadparwaiz1/cmp_luasnip' } }, -- Snippet Engine and Snippet Expansion
  'farmergreg/vim-lastplace',
  {
    'nvim-lualine/lualine.nvim', -- Fancier statusline
    opts = {
      options = {
        icons_enabled = false,
        theme = 'tokyonight',
        component_separators = '|',
        section_separators = '',
      },
    }
  },
  {
    'lukas-reineke/indent-blankline.nvim', -- Add indentation guides even on blank lines
    opts = {
      char = '┊',
      show_trailing_blankline_indent = false,
    }
  },
  'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically
  {
    'ggandor/leap.nvim',
    config = function()
      require('leap').add_default_mappings()
    end
  },
  {
    'rcarriga/nvim-notify',
    config = function()
      vim.notify = require("notify")
    end,
  },
  {
    'sunjon/shade.nvim',
    config = true,
    opts = {
      overlay_opacity = 85,
      opacity_step = 1,
      keys = {
        brightness_up   = '<C-Up>',
        brightness_down = '<C-Down>',
        toggle          = '<Leader>s',
      }
    }
  },
  {
    'yamatsum/nvim-cursorline',
    config = true,
    opts = {
      cursorline = {
        enable = true,
        timeout = 1000,
        number = false,
      },
      cursorword = {
        enable = false,
        min_length = 3,
        hl = { underline = true },
      }
    }
  },
  {
    'windwp/nvim-spectre',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      replace_engine = {
        ['sed'] = {
          cmd = "sed",
          args = nil,
          options = {
            ['ignore-case'] = {
              value = "--ignore-case",
              icon = "[I]",
              desc = "ignore case"
            },
          }
        },
      }
    }
  },

  -- Fuzzy Finder (files, lsp, etc)
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      defaults = {
        mappings = {
          i = {
            ['<C-u>'] = false,
            ['<C-d>'] = false,
          },
        },
      },
    },
    config = function()
      -- Enable telescope fzf native, if installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'notify')
      pcall(require('telescope').load_extension, 'neoclip')

      -- See `:help telescope.builtin`
      vim.keymap.set('n', '<leader>?', require('telescope.builtin').oldfiles, { desc = '[?] Find recently opened files' })
      vim.keymap.set('n', '<leader><space>', require('telescope.builtin').buffers, { desc = '[ ] Find existing buffers' })
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to telescope to change theme, layout, etc.
        require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer]' })

      vim.keymap.set('n', '<leader>sf', require('telescope.builtin').find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>sh', require('telescope.builtin').help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sw', require('telescope.builtin').grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', require('telescope.builtin').live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = '[S]earch [D]iagnostics' })

    end,
  },

  -- Fuzzy Finder Algorithm which requires local dependencies to be built. Only load if `make` is available
  { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make', cond = vim.fn.executable "make" == 1 },

  -- Visualize lsp progress
  {
    "j-hui/fidget.nvim",
    config = true,
  },

  {
    "folke/which-key.nvim",
    config = true,
  },
  {
    "mhanberg/elixir.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("elixir").setup {
        on_attach = on_attach,
      }
    end
  },
  { 'folke/tokyonight.nvim',
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      style = "moon", -- The theme comes in three styles, `storm`, `moon`, a darker variant `night` and `day`
      light_style = "day", -- The theme is used when the background is set to light
      transparent = false, -- Enable this to disable setting the background color
      terminal_colors = true, -- Configure the colors used when opening a `:terminal` in Neovim
      styles = {
        -- Style to be applied to different syntax groups
        -- Value is any valid attr-list value for `:help nvim_set_hl`
        comments = { italic = true },
        keywords = { italic = true },
        functions = {},
        variables = {},
        -- Background styles. Can be "dark", "transparent" or "normal"
        sidebars = "dark", -- style for sidebars, see below
        floats = "dark", -- style for floating windows
      },
      sidebars = { "qf", "help" }, -- Set a darker background on sidebar-like windows. For example: `["qf", "vista_kind", "terminal", "packer"]`
      day_brightness = 0.3, -- Adjusts the brightness of the colors of the **Day** style. Number between 0 and 1, from dull to vibrant colors
      hide_inactive_statusline = false, -- Enabling this option, will hide inactive statuslines and replace them with a thin border instead. Should work with the standard **StatusLine** and **LuaLine**.
      dim_inactive = false, -- dims inactive windows
      lualine_bold = false, -- When `true`, section headers in the lualine theme will be bold
    },
    config = function()
      -- Set colorscheme
      vim.o.termguicolors = true
      vim.cmd [[colorscheme tokyonight]]
    end,
  },
  'LnL7/vim-nix',

  {
    'nvim-tree/nvim-tree.lua',
    dependencies = {
      'nvim-tree/nvim-web-devicons', -- optional, for file icons
    },
    tag = 'nightly', -- optional, updated every week. (see issue #1193)
    config = true,
  },

  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = true,
  },

  'vim-test/vim-test',

  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = true,
  },

  'direnv/direnv.vim',

  {
    "windwp/nvim-autopairs",
    config = true,
  },

  {
    'simrat39/rust-tools.nvim',
    config = function()
      local rt = require("rust-tools")

      rt.setup({
        tools = {
          inlay_hints = {
            auto = false
          }
        },
        server = {
          on_attach = function(x, bufnr)
            on_attach(x, bufnr)
            -- Hover actions
            vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, { buffer = bufnr })
            -- Code action groups
            vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, { buffer = bufnr })
          end,
        },
      })
    end
  },
  {
    'lvimuser/lsp-inlayhints.nvim',
    config = true,
  },

  {
    'pwntester/octo.nvim',
    config = true,
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-tree/nvim-web-devicons',
    },
  },

  {
    "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    config = true,
  },

  'tpope/vim-abolish',
  'markonm/traces.vim',

  {
    "andrewferrier/debugprint.nvim",
    config = function()
      require("debugprint").setup()
      require("debugprint").add_custom_filetypes({
        ["rust"] = {
          left = 'println!("',
          right = '");',
          mid_var = '{:?}", ',
          right_var = ");",
        },
      })
    end
  },

  {
    "AckslD/nvim-neoclip.lua",
    dependencies = {
      'nvim-telescope/telescope.nvim',
    },
    config = true,
  },
}
