return {
  { 'github/copilot.vim' },

  {
    'kdheepak/lazygit.nvim',
    lazy = true,
    cmd  = { 'LazyGit', 'LazyGitConfig', 'LazyGitCurrentFile', 'LazyGitFilter', 'LazyGitFilterCurrentFile' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = { { '<leader>lg', '<cmd>LazyGit<cr>', desc = 'LazyGit' } },
  },

  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd   = { 'ConformInfo' },
    keys  = { {
      '<leader>f',
      function() require('conform').format { async = true, lsp_format = 'fallback' } end,
      mode = '', desc = '[F]ormat buffer',
    } },
    opts = {
      notify_on_error  = false,
      formatters_by_ft = {
        lua        = { 'stylua' },
        typescript = { 'prettier' },
        astro      = { 'prettier' },
        c          = { 'clang-format' },
      },
    },
  },

  {
    'folke/todo-comments.nvim',
    event        = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts         = { signs = false },
  },

  {
    'echasnovski/mini.nvim',
    config = function()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.surround').setup()
    end,
  },
}
