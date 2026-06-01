return {
  'tpope/vim-sleuth',
  'nvim-lua/plenary.nvim',
  { 'nvim-tree/nvim-web-devicons' },

  {
    'ThePrimeagen/harpoon',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('harpoon').setup { menu = { width = vim.api.nvim_win_get_width(0) - 4 } }
      local mark = require 'harpoon.mark'
      local ui   = require 'harpoon.ui'
      vim.keymap.set('n', '<leader>aa', mark.add_file,        { desc = 'Add to harpoon list' })
      vim.keymap.set('n', '<leader>ah', ui.toggle_quick_menu, { desc = 'Open harpoon menu' })
      vim.keymap.set('n', '<leader>a7', function() ui.nav_file(1) end, { desc = 'Harpoon file 1' })
      vim.keymap.set('n', '<leader>a8', function() ui.nav_file(2) end, { desc = 'Harpoon file 2' })
      vim.keymap.set('n', '<leader>a9', function() ui.nav_file(3) end, { desc = 'Harpoon file 3' })
      vim.keymap.set('n', '<leader>a0', function() ui.nav_file(4) end, { desc = 'Harpoon file 4' })
    end,
  },

  {
    'kevinhwang91/nvim-ufo',
    dependencies = { 'kevinhwang91/promise-async' },
    opts = {
      provider_selector = function(_, _, _) return { 'lsp', 'indent' } end,
    },
  },

  {
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {
      delay = 0,
      icons = {
        mappings = vim.g.have_nerd_font,
        keys = vim.g.have_nerd_font and {} or {
          Up='<Up> ',Down='<Down> ',Left='<Left> ',Right='<Right> ',
          C='<C-…> ',M='<M-…> ',D='<D-…> ',S='<S-…> ',
          CR='<CR> ',Esc='<Esc> ',Space='<Space> ',Tab='<Tab> ',
          NL='<NL> ',BS='<BS> ',
          ScrollWheelDown='<ScrollWheelDown> ',ScrollWheelUp='<ScrollWheelUp> ',
          F1='<F1>',F2='<F2>',F3='<F3>',F4='<F4>',F5='<F5>',F6='<F6>',
          F7='<F7>',F8='<F8>',F9='<F9>',F10='<F10>',F11='<F11>',F12='<F12>',
        },
      },
      spec = {
        { '<leader>c', group = '[C]ode',     mode = { 'n', 'x' } },
        { '<leader>d', group = '[D]ocument' },
        { '<leader>r', group = '[R]ename' },
        { '<leader>s', group = '[S]earch' },
        { '<leader>w', group = '[W]orkspace' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
      },
    },
  },

  {
    'lewis6991/gitsigns.nvim',
    opts = {
      on_attach = function(bufnr)
        local gs = require 'gitsigns'
        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end
        map('n', ']c', function()
          if vim.wo.diff then vim.cmd.normal { ']c', bang = true } else gs.nav_hunk 'next' end
        end, { desc = 'Jump to next git [c]hange' })
        map('n', '[c', function()
          if vim.wo.diff then vim.cmd.normal { '[c', bang = true } else gs.nav_hunk 'prev' end
        end, { desc = 'Jump to previous git [c]hange' })
        map('v', '<leader>hs', function() gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [s]tage hunk' })
        map('v', '<leader>hr', function() gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [r]eset hunk' })
        map('n', '<leader>hs', gs.stage_hunk,   { desc = 'git [s]tage hunk' })
        map('n', '<leader>hr', gs.reset_hunk,   { desc = 'git [r]eset hunk' })
        map('n', '<leader>hS', gs.stage_buffer, { desc = 'git [S]tage buffer' })
        map('n', '<leader>hu', gs.stage_hunk,   { desc = 'git [u]ndo stage hunk' })
        map('n', '<leader>hR', gs.reset_buffer, { desc = 'git [R]eset buffer' })
        map('n', '<leader>hp', gs.preview_hunk, { desc = 'git [p]review hunk' })
        map('n', '<leader>hb', gs.blame_line,   { desc = 'git [b]lame line' })
        map('n', '<leader>hd', gs.diffthis,     { desc = 'git [d]iff against index' })
        map('n', '<leader>hD', function() gs.diffthis '@' end, { desc = 'git [D]iff against last commit' })
        map('n', '<leader>tb', gs.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
        map('n', '<leader>tD', gs.preview_hunk_inline,       { desc = '[T]oggle git show [D]eleted' })
      end,
    },
  },
}
