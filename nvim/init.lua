-- stylua: ignore start

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

require("lazy").setup("plugins")

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
      if notifier then notifier(cmd, exit_code) end

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
    vim.fn.system(string.format([[terminal-notifier -title "Neovim" -subtitle "%s" -message "Success!"]], cmd))
  else
    print("Failure!")
    vim.fn.system(string.format([[terminal-notifier -title "Neovim" -subtitle "%s" -message "Fail!"]], cmd))
  end
end

vim.g["test#custom_strategies"] = {
  motch = function(cmd)
    local winnr = vim.fn.winnr()
    Motch.open(cmd, winnr, terminal_notifier_notfier)
  end,
}
vim.g["test#strategy"] = "motch"

-- [[ Setting options ]]
-- See `:help vim.o`

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.g.traces_abolish_integration = 1

-- Set highlight on search
vim.o.hlsearch = false

-- Make line numbers default
vim.wo.number = true

-- Enable mouse mode
vim.o.mouse = 'a'

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Decrease update time
vim.o.updatetime = 250
vim.wo.signcolumn = 'yes'

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

vim.o.timeoutlen = 500
vim.o.ttimeoutlen = 5

vim.opt.spell = true
vim.opt.spelllang = { 'en_us' }

-- [[ Basic Keymaps ]]

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)

vim.keymap.set('n', '<leader>mts', function()
  vim.cmd.TestNearest()
end, { desc = '[T]est [S]ingle' })

vim.keymap.set('n', '<leader>mta', function()
  vim.cmd.TestSuite()
end, { desc = '[T]est [A]ll' })

vim.keymap.set('n', '<leader>mtl', function()
  vim.cmd.TestLast()
end, { desc = '[T]est [L]ast' })

vim.keymap.set('n', '<leader>mtr', function()
  vim.cmd.TestLast()
end, { desc = '[T]est [R]ecent' })

vim.keymap.set('n', '<leader>mtf', function()
  vim.cmd.TestFile()
end, { desc = '[T]est [F]ile' })

vim.keymap.set('n', '<leader>ft', function()
  vim.cmd.NvimTreeToggle()
end, { desc = '[F]ile [T]ree' })

vim.keymap.set("n", "<leader>xx", "<cmd>TroubleToggle<cr>",
  { silent = true, noremap = true }
)
vim.keymap.set("n", "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>",
  { silent = true, noremap = true }
)
vim.keymap.set("n", "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>",
  { silent = true, noremap = true }
)
vim.keymap.set("n", "<leader>xl", "<cmd>TroubleToggle loclist<cr>",
  { silent = true, noremap = true }
)
vim.keymap.set("n", "<leader>xq", "<cmd>TroubleToggle quickfix<cr>",
  { silent = true, noremap = true }
)
vim.keymap.set("n", "gR", "<cmd>TroubleToggle lsp_references<cr>",
  { silent = true, noremap = true }
)

vim.keymap.set("n", '<leader>cy', function()
  require('telescope').extensions.neoclip.default()
end, { desc = '[C]lipboard [Y]ank' })

vim.keymap.set("n", '<leader>S', function()
  require('spectre').open()
end, { desc = '[S]pectre' })

vim.keymap.set("n", '<leader>sw', function()
  require('spectre').open_visual({ select_word = true })
end, { desc = '[S]pectre [W]ord' })

vim.keymap.set("n", '<leader>sp', function()
  require('spectre').open_file_search()
end, { desc = '[S]pectre p[F]ile' })

vim.cmd [[autocmd BufWritePre * lua vim.lsp.buf.format()]]

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

vim.api.nvim_create_user_command('Browse', [[silent execute "!open " .. shellescape(<q-args>,1)]], { nargs = 1 })

vim.diagnostic.config({
  virtual_text = false,
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
