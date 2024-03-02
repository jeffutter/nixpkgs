return {
	"LnL7/vim-nix",
	"direnv/direnv.vim",
	"farmergreg/vim-lastplace",
	"markonm/traces.vim",
	"tpope/vim-abolish",
	"tpope/vim-fugitive", -- Git commands in nvim
	"tpope/vim-repeat",
	"tpope/vim-rhubarb", -- Fugitive-companion to interact with github
	"tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically
	{ "cappyzawa/trim.nvim", config = true },

	{
		"lewis6991/gitsigns.nvim", -- Add git related info in the signs columns and popups
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			signs = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
			},
		},
	},

	{ "numToStr/Comment.nvim", config = true }, -- "gc" to comment visual regions/lines

	{
		"hrsh7th/nvim-cmp", -- Autocompletion
		dependencies = {
			"f3fora/cmp-spell",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-cmdline",
			"hrsh7th/cmp-emoji",
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-vsnip",
			"saadparwaiz1/cmp_luasnip",
		},
		config = function()
			-- nvim-cmp setup
			local cmp = require("cmp")
			local luasnip = require("luasnip")

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				mapping = cmp.mapping.preset.insert({
					["<C-d>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.complete(),
					["<CR>"] = cmp.mapping.confirm({
						behavior = cmp.ConfirmBehavior.Replace,
						select = true,
					}),
					["<Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_next_item()
						elseif luasnip.expand_or_jumpable() then
							luasnip.expand_or_jump()
						else
							fallback()
						end
					end, { "i", "s" }),
					["<S-Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_prev_item()
						elseif luasnip.jumpable(-1) then
							luasnip.jump(-1)
						else
							fallback()
						end
					end, { "i", "s" }),
				}),
				sources = {
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "buffer" },
					-- { name = 'emoji' },
					{ name = "path" },
					{ name = "vsnip" },
					{ name = "spell" },
				},
			})

			cmp.setup.cmdline(":", {
				mapping = cmp.mapping.preset.cmdline(),
				sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline", keyword_length = 2 } }),
			})
		end,
	},

	{ "L3MON4D3/LuaSnip", dependencies = { "saadparwaiz1/cmp_luasnip" } }, -- Snippet Engine and Snippet Expansion

	{
		"nvim-lualine/lualine.nvim", -- Fancier statusline
		opts = {
			options = {
				icons_enabled = false,
				theme = "tokyonight",
				component_separators = "|",
				section_separators = "",
			},
		},
	},

	-- indent guides for Neovim
	{ "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },

	{
		"folke/flash.nvim",
		event = "VeryLazy",
		---@type Flash.Config
		opts = {},
		-- stylua: ignore
		keys = {
		  { "s", mode = { "n", "o", "x" }, function() require("flash").jump() end, desc = "Flash" },
		  { "S", mode = { "n", "o", "x" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
		  { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
		  { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
		  { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
		},
	},

	{
		"rcarriga/nvim-notify",
		config = function()
			vim.notify = require("notify")
		end,
	},

	{
		"levouh/tint.nvim",
		config = true,
	},

	{
		"yamatsum/nvim-cursorline",
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
			},
		},
	},

	{
		"windwp/nvim-spectre",
		dependencies = { "nvim-lua/plenary.nvim" },
		keys = {
			{
				"<leader>S",
				function()
					require("spectre").open()
				end,
				desc = "[S]pectre",
			},
			{
				"<leader>sw",
				function()
					require("spectre").open_visual({ select_word = true })
				end,
				desc = "[S]pectre [W]ord",
			},
			{
				"<leader>sp",
				function()
					require("spectre").open_file_search()
				end,
				desc = "[S]pectre p[F]ile",
			},
		},
		opts = {
			replace_engine = {
				["sed"] = {
					cmd = "sed",
					args = nil,
					options = {
						["ignore-case"] = {
							value = "--ignore-case",
							icon = "[I]",
							desc = "ignore case",
						},
					},
				},
			},
		},
	},

	-- Fuzzy Finder (files, lsp, etc)
	{
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			defaults = {
				mappings = {
					i = {
						["<C-u>"] = false,
						["<C-d>"] = false,
					},
				},
			},
		},
		keys = {
			{
				"<leader>?",
				function()
					require("telescope.builtin").oldfiles()
				end,
				desc = "[?] Find recently opened files",
			},
			{
				"<leader><space>",
				function()
					require("telescope.builtin").buffers()
				end,
				desc = "[ ] Find existing buffers",
			},
			{
				"<leader>/",
				function()
					-- You can pass additional configuration to telescope to change theme, layout, etc.
					require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
						winblend = 10,
						previewer = false,
					}))
				end,
				desc = "[/] Fuzzily search in current buffer]",
			},

			{
				"<leader>sf",
				function()
					require("telescope.builtin").find_files()
				end,
				desc = "[S]earch [F]iles",
			},
			{
				"<leader>sh",
				function()
					require("telescope.builtin").help_tags()
				end,
				desc = "[S]earch [H]elp",
			},
			{
				"<leader>sw",
				function()
					require("telescope.builtin").grep_string()
				end,
				desc = "[S]earch current [W]ord",
			},
			{
				"<leader>sg",
				function()
					require("telescope.builtin").live_grep()
				end,
				desc = "[S]earch by [G]rep",
			},
			{
				"<leader>sd",
				function()
					require("telescope.builtin").diagnostics()
				end,
				desc = "[S]earch [D]iagnostics",
			},
		},
		config = function()
			-- Enable telescope fzf native, if installed
			pcall(require("telescope").load_extension, "fzf")
			pcall(require("telescope").load_extension, "notify")
			pcall(require("telescope").load_extension, "neoclip")
		end,
	},

	-- Fuzzy Finder Algorithm which requires local dependencies to be built. Only load if `make` is available
	{ "nvim-telescope/telescope-fzf-native.nvim", run = "make", cond = vim.fn.executable("make") == 1 },

	-- Visualize lsp progress
	{
		"j-hui/fidget.nvim",
		config = true,
		tag = "legacy",
	},

	{
		"folke/which-key.nvim",
		config = true,
	},

	{
		"hrsh7th/cmp-nvim-lsp",
		enable = true,
		config = true,
	},

	{
		"elixir-tools/elixir-tools.nvim",
		ft = "elixir",
		version = "*",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"nvim-lua/plenary.nvim",
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			local elixir = require("elixir")

			elixir.setup({
				nextls = {
					enable = true,
					init_options = {
						experimental = { completions = { enable = true } },
					},
				},
				credo = { enable = true },
				elixirls = { enable = false },
				capabilities = require("cmp_nvim_lsp").default_capabilities(),
				on_attach = require("lazyvim.util").on_attach(function(client, buffer)
					require("plugins.lsp.format").on_attach(client, buffer)
					require("plugins.lsp.keymaps").on_attach(client, buffer)
				end),
			})
		end,
	},

	{
		"folke/tokyonight.nvim",
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
			vim.cmd([[colorscheme tokyonight]])
		end,
	},

	{
		"nvim-tree/nvim-tree.lua",
		dependencies = {
			"nvim-tree/nvim-web-devicons", -- optional, for file icons
		},
		tag = "nightly", -- optional, updated every week. (see issue #1193)
		config = true,
		keys = {
			{
				"<leader>ft",
				function()
					vim.cmd.NvimTreeToggle()
				end,
				desc = "[F]ile [T]ree",
			},
		},
	},

	{
		"folke/trouble.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		keys = {
			{ "<leader>xx", "<cmd>TroubleToggle<cr>", desc = "Trouble Toggle" },
			{ "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", desc = "Trouble Workspace" },
			{ "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>", desc = "Trouble Document" },
			{ "<leader>xl", "<cmd>TroubleToggle loclist<cr>", desc = "Trouble LocList" },
			{ "<leader>xq", "<cmd>TroubleToggle quickfix<cr>", desc = "Trouble Quickfix" },
			{ "gR", "<cmd>TroubleToggle lsp_references<cr>", desc = "Trouble LSP References" },
		},
	},

	{
		"vim-test/vim-test",
		keys = {
			{
				"<leader>mts",
				function()
					vim.cmd.TestNearest()
				end,
				desc = "[T]est [S]ingle",
			},
			{
				"<leader>mta",
				function()
					vim.cmd.TestSuite()
				end,
				desc = "[T]est [A]ll",
			},
			{
				"<leader>mtl",
				function()
					vim.cmd.TestLast()
				end,
				desc = "[T]est [L]ast",
			},
			{
				"<leader>mtr",
				function()
					vim.cmd.TestLast()
				end,
				desc = "[T]est [R]ecent",
			},
			{
				"<leader>mtf",
				function()
					vim.cmd.TestFile()
				end,
				desc = "[T]est [F]ile",
			},
		},
		config = function()
			local Motch = {}

			local nil_buf_id = 999999
			local term_buf_id = nil_buf_id

			function Motch.open(cmd, winnr, notifier)
				-- delete the current buffer if it's still open
				if vim.api.nvim_buf_is_valid(term_buf_id) then
					vim.api.nvim_buf_delete(term_buf_id, { force = true })
					term_buf_id = nil_buf_id
				end

				vim.cmd("botright new | lua vim.api.nvim_win_set_height(0, 15)")
				term_buf_id = vim.api.nvim_get_current_buf()
				vim.opt_local.number = false
				vim.opt_local.cursorline = false

				vim.fn.termopen(cmd, {
					on_exit = function(_jobid, exit_code, _event)
						if notifier then
							notifier(cmd, exit_code)
						end

						if exit_code == 0 then
							vim.api.nvim_buf_delete(term_buf_id, { force = true })
							term_buf_id = nil_buf_id
						end
					end,
				})

				print(cmd)

				vim.cmd([[normal! G]])
				vim.cmd(winnr .. [[wincmd w]])
			end

			local terminal_notifier_notfier = function(cmd, exit)
				if exit == 0 then
					print("Success!")
					vim.fn.system(
						string.format([[terminal-notifier -title "Neovim" -subtitle "%s" -message "Success!"]], cmd)
					)
				else
					print("Failure!")
					vim.fn.system(
						string.format([[terminal-notifier -title "Neovim" -subtitle "%s" -message "Fail!"]], cmd)
					)
				end
			end

			vim.g["test#custom_strategies"] = {
				motch = function(cmd)
					local winnr = vim.fn.winnr()
					Motch.open(cmd, winnr, terminal_notifier_notfier)
				end,
			}
			vim.g["test#strategy"] = "motch"
		end,
	},

	{
		"folke/todo-comments.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = true,
	},

	{
		"windwp/nvim-autopairs",
		config = true,
	},

	{
		"simrat39/rust-tools.nvim",
		ft = "rust",
		config = function()
			local rt = require("rust-tools")

			rt.setup({
				tools = {
					inlay_hints = {
						auto = false,
					},
				},
				server = {
					on_attach = require("lazyvim.util").on_attach(function(client, buffer)
						require("plugins.lsp.format").on_attach(client, buffer)
						require("plugins.lsp.keymaps").on_attach(client, buffer)
						-- Hover actions
						vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, { buffer = buffer })
						-- Code action groups
						vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, { buffer = buffer })
					end),
				},
			})
		end,
	},

	{
		"lvimuser/lsp-inlayhints.nvim",
		config = function()
			require("lsp-inlayhints").setup()
			vim.api.nvim_create_augroup("LspAttach_inlayhints", {})
			vim.api.nvim_create_autocmd("LspAttach", {
				group = "LspAttach_inlayhints",
				callback = function(args)
					if not (args.data and args.data.client_id) then
						return
					end

					local bufnr = args.buf
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					require("lsp-inlayhints").on_attach(client, bufnr)
				end,
			})
		end,
	},

	{
		"pwntester/octo.nvim",
		cmd = "Octo",
		config = true,
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
			"nvim-tree/nvim-web-devicons",
		},
	},

	{
		"https://git.sr.ht/~whynothugo/lsp_lines.nvim",
		config = function()
			require("lsp_lines").setup()
			vim.diagnostic.config({
				virtual_text = false,
			})
		end,
	},

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
		end,
	},

	{
		"AckslD/nvim-neoclip.lua",
		dependencies = {
			"nvim-telescope/telescope.nvim",
		},
		keys = {
			{
				"<leader>cy",
				function()
					require("telescope").extensions.neoclip.default()
				end,
				desc = "[C]lipboard [Y]ank",
			},
		},
		config = true,
	},

	{
		"luukvbaal/statuscol.nvim",
		config = function()
			local builtin = require("statuscol.builtin")
			require("statuscol").setup({
				setopt = true,
				foldfunc = "builtin",
				segments = {
					{ text = { builtin.lnumfunc }, click = "v:lua.ScLa" },
					{ text = { "%s" }, click = "v:lua.ScSa" },
					{ text = { builtin.foldfunc, " " }, condition = { true, builtin.not_empty }, click = "v:lua.ScFa" },
				},
			})
		end,
		dependencies = {
			"lewis6991/gitsigns.nvim",
		},
	},

	{
		"aznhe21/actions-preview.nvim",
		config = function()
			vim.keymap.set({ "v", "n" }, "gf", require("actions-preview").code_actions)

			require("actions-preview").setup({
				telescope = {
					sorting_strategy = "ascending",
					layout_strategy = "vertical",
					layout_config = {
						width = 0.8,
						height = 0.9,
						prompt_position = "top",
						preview_cutoff = 20,
						preview_height = function(_, _, max_lines)
							return max_lines - 15
						end,
					},
				},
			})
		end,
	},
}

-- vim: ts=2 sts=2 sw=2 et
