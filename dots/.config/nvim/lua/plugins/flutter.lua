return {
  {
    'nvim-flutter/flutter-tools.nvim',
    lazy = false,
    dependencies = {
      'nvim-lua/plenary.nvim',
      'stevearc/dressing.nvim',
      'hrsh7th/cmp-nvim-lsp',
    },
    config = true,
    opts = {
      ui = { border = 'rounded', notification_style = 'native' },
      decorations = { statusline = { app_version = false, device = false, project_config = false } },
      debugger    = { enabled = false, exception_breakpoints = {}, evaluate_to_string_in_debug_views = true },
      root_patterns = { '.git', 'pubspec.yaml' },
      fvm = true,
      widget_guides = { enabled = false },
      closing_tags  = { highlight = 'ErrorMsg', prefix = '>', priority = 10, enabled = true },
      dev_log  = { enabled = true, filter = nil, notify_errors = false, open_cmd = '15split', focus_on_open = true },
      dev_tools = { autostart = false, auto_open_browser = false },
      outline   = { open_cmd = '30vnew', auto_open = false },
      lsp = {
        capabilities = function(config)
          local ok, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
          if ok then config = vim.tbl_deep_extend('force', config, cmp_lsp.default_capabilities()) end
          config.textDocument.codeAction = {
            dynamicRegistration = false,
            codeActionLiteralSupport = { codeActionKind = { valueSet = {
              '', 'quickfix', 'refactor', 'refactor.extract', 'refactor.inline',
              'refactor.rewrite', 'source', 'source.organizeImports',
            } } },
          }
          return config
        end,
        color    = { enabled = false, background = false, foreground = false, virtual_text = true, virtual_text_str = '■' },
        settings = {
          showTodos = true, completeFunctionCalls = true,
          renameFilesWithClasses = 'prompt', enableSnippets = true, updateImportsOnRename = true,
        },
      },
    },
  },
}
