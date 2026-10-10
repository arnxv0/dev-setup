vim.g.mapleader      = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true
vim.g.loaded_netrw       = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.mouse          = 'a'
vim.opt.showmode       = false
vim.schedule(function() vim.opt.clipboard = 'unnamedplus' end)
vim.opt.breakindent    = true
vim.opt.undofile       = true
vim.opt.ignorecase     = true
vim.opt.smartcase      = true
vim.opt.signcolumn     = 'yes'
vim.opt.updatetime     = 250
vim.opt.timeoutlen     = 300
vim.opt.splitright     = true
vim.opt.splitbelow     = true
vim.opt.list           = true
vim.opt.listchars      = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.inccommand     = 'split'
vim.opt.cursorline     = true
vim.opt.scrolloff      = 10
vim.opt.confirm        = true
vim.opt.foldcolumn     = '1'
vim.opt.foldlevel      = 99
vim.opt.foldlevelstart = 99
vim.opt.foldenable     = true

vim.keymap.set('n', '<Esc>',      '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>q',  vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>',             { desc = 'Exit terminal mode' })
vim.keymap.set('n', '<C-h>',      '<C-w><C-h>',              { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>',      '<C-w><C-l>',              { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>',      '<C-w><C-j>',              { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>',      '<C-w><C-k>',              { desc = 'Move focus to the upper window' })
vim.keymap.set('n', '<C-f>',      '<cmd>silent !tmux neww tmux-sessionizer<CR>')

vim.api.nvim_create_autocmd('TextYankPost', {
  desc     = 'Highlight when yanking',
  group    = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function() vim.highlight.on_yank() end,
})

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system {
    'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazypath,
  }
  if vim.v.shell_error ~= 0 then error('Error cloning lazy.nvim:\n' .. out) end
end
vim.opt.rtp:prepend(lazypath)

-- Specs live in lua/plugins/ deliberately. With them directly in lua/, a file
-- like lua/telescope.lua SHADOWS the plugin module: require('telescope') then
-- returned the lazy spec table (no .setup), breaking the config with
-- "attempt to call field 'setup' (a nil value)".
require('lazy').setup({
  { import = 'plugins.editor' },
  { import = 'plugins.ui' },
  { import = 'plugins.treesitter' },
  { import = 'plugins.lsp' },
  { import = 'plugins.completion' },
  { import = 'plugins.telescope' },
  { import = 'plugins.flutter' },
  { import = 'plugins.extras' },
  { import = 'plugins.custom' },
}, {
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘', config = '🛠', event = '📅', ft = '📂', init = '⚙',
      keys = '🗝', plugin = '🔌', runtime = '💻', require = '🌙',
      source = '📄', start = '🚀', task = '📌', lazy = '💤 ',
    },
  },
})
