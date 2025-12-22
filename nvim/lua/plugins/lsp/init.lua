return {
	-- lspconfig
	{
		"neovim/nvim-lspconfig",
		event = "BufReadPre",
		dependencies = {
			{ "folke/neoconf.nvim", cmd = "Neoconf", config = true },
			{ "folke/neodev.nvim", opts = { experimental = { pathStrict = true } } },
			"mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"hrsh7th/cmp-nvim-lsp",
		},
		---@class PluginLspOpts
		opts = {
			-- options for vim.diagnostic.config()
			diagnostics = {
				underline = true,
				update_in_insert = false,
				virtual_text = { spacing = 4, prefix = "●" },
				severity_sort = true,
			},
			-- Automatically format on save
			autoformat = true,
			inlayHints = {
				enabled = true,
			},
			-- options for vim.lsp.buf.format
			-- `bufnr` and `filter` is handled by the LazyVim formatter,
			-- but can be also overriden when specified
			format = {
				formatting_options = nil,
				timeout_ms = nil,
			},
			-- LSP Server Settings
			---@type lspconfig.options
			servers = {
				bashls = {
					mason = false,
				},
				clangd = {},
				cssls = {},
				gopls = {},
				helm_ls = {},
				html = {},
				jsonls = {},
				ltex = {
					cmd = { "ltex-ls" },
					filetypes = { "text", "plaintex", "tex", "markdown" },
					settings = {
						ltex = {
							language = "en",
						},
					},
					flags = { debounce_text_changes = 300 },
				},
				lua_ls = {
					mason = false, -- set to false if you don't want this server to be installed with mason
					settings = {
						Lua = {
							workspace = {
								checkThirdParty = false,
							},
							completion = {
								callSnippet = "Replace",
							},
						},
					},
				},
				nil_ls = {
					mason = false,
					settings = {
						["nil"] = {
							formatting = {
								command = { "nixfmt" },
							},
						},
					},
				},
				rust_analyzer = {
					mason = false,
				},
				svelte = {},
				tailwindcss = {},
				ts_ls = {},
				yamlls = {},
			},
			-- you can do any additional lsp server setup here
			-- return true if you don't want this server to be setup with lspconfig
			---@type table<string, fun(server:string, opts:_.lspconfig.options):boolean?>
			setup = {
				rust_analyzer = function()
					return true
				end,
				-- example to setup with typescript.nvim
				-- tsserver = function(_, opts)
				--   require("typescript").setup({ server = opts })
				--   return true
				-- end,
				-- Specify * to use this function as a fallback for any server
				-- ["*"] = function(server, opts) end,
			},
		},
		---@param opts PluginLspOpts
		config = function(plugin, opts)
			-- setup autoformat
			require("plugins.lsp.format").autoformat = opts.autoformat
			-- setup formatting and keymaps
			require("lazyvim.util").on_attach(function(client, buffer)
				require("plugins.lsp.format").on_attach(client, buffer)
				require("plugins.lsp.keymaps").on_attach(client, buffer)
			end)

			-- diagnostics
			for name, icon in pairs(require("config").icons.diagnostics) do
				name = "DiagnosticSign" .. name
				vim.fn.sign_define(name, { text = icon, texthl = name, numhl = "" })
			end
			vim.diagnostic.config(opts.diagnostics)

			local servers = opts.servers
			local capabilities =
				require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities())
			-- capabilities.workspace = {
			-- 	didChangeWatchedFiles = {
			-- 		-- dynamicRegistration = true
			-- 		dynamicRegistration = false,
			-- 		relativePatternSupport = false,
			-- 	},
			-- }

			local function setup(server)
				local server_opts = servers[server] or {}
				server_opts.capabilities = capabilities
				if opts.setup[server] then
					if opts.setup[server](server, server_opts) then
						return
					end
				elseif opts.setup["*"] then
					if opts.setup["*"](server, server_opts) then
						return
					end
				end
				-- require("lspconfig")[server].setup(server_opts)
				vim.lsp.enable(server)
				vim.lsp.config(server, server_opts)
			end

			local mlsp = require("mason-lspconfig")
			local available = mlsp.get_available_servers()

			local ensure_installed = {} ---@type string[]
			for server, server_opts in pairs(servers) do
				if server_opts then
					server_opts = server_opts == true and {} or server_opts
					-- run manual setup if mason=false or if this is a server that cannot be installed with mason-lspconfig
					if server_opts.mason == false or not vim.tbl_contains(available, server) then
						setup(server)
					else
						ensure_installed[#ensure_installed + 1] = server
					end
				end
			end
		end,
	},

	-- formatters
	{
		"nvimtools/none-ls.nvim",
		opts = function(_, opts)
			local nls = require("null-ls")
			opts.sources = vim.list_extend(opts.sources or {}, {
				nls.builtins.code_actions.gitsigns,
				-- go
				nls.builtins.code_actions.gomodifytags,
				nls.builtins.code_actions.impl,
				nls.builtins.diagnostics.golangci_lint,
				-- ts
				nls.builtins.formatting.biome,
				-- require('typescript.extensions.null-ls.code-actions'),
				-- other
				nls.builtins.formatting.stylua,
				nls.builtins.formatting.shfmt,
			})
			return opts
		end,
	},

	-- cmdline tools and lsp servers
	{
		"williamboman/mason.nvim",
		build = ":MasonUpdate",
		cmd = "Mason",
		keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
		opts = {
			PATH = "append",
			ensure_installed = {
				"stylua",
				"shellcheck",
				"shfmt",
			},
		},
		---@param opts MasonSettings | {ensure_installed: string[]}
		config = function(plugin, opts)
			require("mason").setup(opts)
			local mr = require("mason-registry")
			for _, tool in ipairs(opts.ensure_installed) do
				local p = mr.get_package(tool)
				if not p:is_installed() then
					p:install()
				end
			end
		end,
	},

	{
		"mfussenegger/nvim-jdtls",
		lazy = true,
		ft = "java",
		config = function()
			local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")

			local workspace_dir = "/Users/jeffery.utter/.cache/jdtls/workspace/" .. project_name
			local config = {
				cmd = { "jdt-language-server", "-data", workspace_dir },
				root_dir = vim.fs.dirname(vim.fs.find({ "gradlew", ".git", "mvnw" }, { upward = true })[1]),
			}
			require("jdtls").start_or_attach(config)
		end,
	},
}

-- vim: ts=2 sts=2 sw=2 et
