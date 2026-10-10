return {
  { 'github/copilot.vim' },

  -- Writes Session.vim in the cwd and keeps it updated, so a restored pane can
  -- reopen with `nvim -S` instead of an empty editor. Both tmux-resurrect's
  -- nvim_session strategy and our own tmux-restore look for ./Session.vim.
  --
  -- :Obsess is NOT automatic, so start it on entry when nvim was opened on a
  -- directory (which is how tmux-sessionizer launches it).
  {
    'tpope/vim-obsession',
    lazy = false,
    config = function()
      -- Capture argv NOW, at startup: by the time VimEnter fires, nvim-tree has
      -- rewritten argv(0) to "NvimTree_1" and the directory test would fail.
      local argc, arg0 = vim.fn.argc(), vim.fn.argv(0)
      -- Must not use event='VimEnter' on this spec: lazy would load the plugin
      -- ON VimEnter, so an autocmd registered here would be too late to fire.
      vim.schedule(function()
        if vim.v.this_session ~= '' then return end     -- already tracking
        if vim.fn.exists(':Obsess') == 0 then return end
        -- only when launched on a directory (how tmux-sessionizer starts nvim)
        local on_dir = (argc == 0)
            or (argc == 1 and arg0 ~= '' and vim.fn.isdirectory(arg0) == 1)
        if not on_dir then return end
        pcall(vim.cmd, 'Obsess')
      end)
    end,
  },

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
