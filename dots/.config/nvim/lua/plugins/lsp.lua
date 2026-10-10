return {
  { 'j-hui/fidget.nvim', opts = {} },

  {
    'folke/lazydev.nvim',
    ft   = 'lua',
    opts = { library = { { path = '${3rd}/luv/library', words = { 'vim%.uv' } } } },
  },

  'hrsh7th/cmp-nvim-lsp',

  -- mason-tool-installer must load AFTER mason.setup() has run. Declaring it
  -- both standalone and as a mason dependency made its plugin/ file execute
  -- first, which errored in mason-registry and left the module cache poisoned
  -- ("loop or previous error loading module 'mason-tool-installer'").
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'williamboman/mason.nvim' },
    config = function()
      -- 'vhdl-ls' was in this list and does not exist in mason's registry at
      -- all (only 'vhdl-style-guide'), which threw on every startup:
      --   Cannot find package "vhdl-ls"
      -- Filter against the registry so a package being renamed or dropped
      -- upstream degrades to a warning instead of breaking the config.
      local want = {
        'lua-language-server', 'gopls', 'rust-analyzer', 'pyright',
        'typescript-language-server', 'clangd', 'astro-language-server',
        'tailwindcss-language-server', 'haskell-language-server',
        'stylua', 'prettier', 'clang-format',
      }
      local ok, mr = pcall(require, 'mason-registry')
      local install, missing = {}, {}
      for _, pkg in ipairs(want) do
        if not ok or mr.has_package(pkg) then
          table.insert(install, pkg)
        else
          table.insert(missing, pkg)
        end
      end
      if #missing > 0 then
        vim.notify('mason: unknown package(s) skipped: ' .. table.concat(missing, ', '),
          vim.log.levels.WARN)
      end
      require('mason-tool-installer').setup { ensure_installed = install }
    end,
  },

  {
    'williamboman/mason.nvim',
    build = ':MasonUpdate',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'j-hui/fidget.nvim',
    },
    config = function()
      require('mason').setup()

      vim.lsp.config('*', {
        capabilities = vim.tbl_deep_extend(
          'force',
          vim.lsp.protocol.make_client_capabilities(),
          require('cmp_nvim_lsp').default_capabilities()
        ),
      })

      vim.lsp.config('lua_ls', {
        cmd          = { 'lua-language-server' },
        filetypes    = { 'lua' },
        root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
        settings     = { Lua = {
          completion  = { callSnippet = 'Replace' },
          diagnostics = { disable = { 'missing-fields' } },
        } },
      })

      vim.lsp.config('gopls', {
        cmd          = { 'gopls' },
        filetypes    = { 'go', 'gomod', 'gowork', 'gotmpl' },
        root_markers = { 'go.work', 'go.mod', '.git' },
        settings     = { gopls = {
          completeUnimported = true, usePlaceholders = true,
          staticcheck = true, gofumpt = true,
          analyses = { unusedparams=true, shadow=true, nilness=true,
                       unusedwrite=true, fieldalignment=true },
        } },
        on_attach = function(client, bufnr)
          if client.server_capabilities.documentFormattingProvider then
            vim.api.nvim_create_autocmd('BufWritePre', {
              buffer   = bufnr,
              callback = function() vim.lsp.buf.format { async = false } end,
            })
          end
        end,
      })

      vim.lsp.config('rust_analyzer', {
        cmd          = { 'rust-analyzer' },
        filetypes    = { 'rust' },
        root_markers = { 'Cargo.toml', 'Cargo.lock', '.git' },
        settings     = { ['rust-analyzer'] = {
          cargo = { allFeatures = true },
          checkOnSave = true,
          check = { command = 'clippy' },
        } },
      })

      vim.lsp.config('pyright', {
        cmd          = { 'pyright-langserver', '--stdio' },
        filetypes    = { 'python' },
        root_markers = { '.git', 'setup.py', 'setup.cfg', 'pyproject.toml', 'requirements.txt' },
        settings     = { python = { analysis = {
          typeCheckingMode = 'basic', autoSearchPaths = true, useLibraryCodeForTypes = true,
        } } },
      })

      vim.lsp.config('ts_ls', {
        cmd          = { 'typescript-language-server', '--stdio' },
        filetypes    = { 'javascript', 'javascriptreact', 'javascript.jsx',
                         'typescript', 'typescriptreact', 'typescript.tsx' },
        root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
      })

      vim.lsp.config('clangd', {
        cmd          = { 'clangd' },
        filetypes    = { 'c', 'cpp', 'objc', 'objcpp', 'cuda', 'proto' },
        root_markers = { 'compile_commands.json', 'compile_flags.txt', '.git' },
      })

      vim.lsp.config('astro', {
        cmd          = { 'astro-ls', '--stdio' },
        filetypes    = { 'astro' },
        root_markers = { 'astro.config.mjs', 'astro.config.ts', 'package.json', '.git' },
        init_options = { typescript = {} },
      })

      vim.lsp.config('tailwindcss', {
        cmd          = { 'tailwindcss-language-server', '--stdio' },
        filetypes    = { 'html', 'css', 'scss', 'less', 'javascript', 'javascriptreact',
                         'typescript', 'typescriptreact', 'svelte', 'astro', 'vue' },
        root_markers = { 'tailwind.config.js', 'tailwind.config.ts',
                         'tailwind.config.cjs', 'package.json', '.git' },
      })

      vim.lsp.config('hls', {
        cmd          = { 'haskell-language-server-wrapper', '--lsp' },
        filetypes    = { 'haskell', 'lhaskell', 'cabal' },
        root_markers = { 'hie.yaml', 'stack.yaml', 'cabal.project', '*.cabal', '.git' },
      })

      vim.lsp.config('rust_hdl', {
        cmd          = { 'vhdl_ls' },
        filetypes    = { 'vhd', 'vhdl' },
        root_markers = { 'vhdl_ls.toml' },
      })

      vim.lsp.enable {
        'lua_ls', 'gopls', 'rust_analyzer', 'pyright', 'ts_ls',
        'clangd', 'astro', 'tailwindcss', 'hls', 'rust_hdl',
      }

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            vim.keymap.set(mode or 'n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end
          local tb = require 'telescope.builtin'
          map('gd',         tb.lsp_definitions,               '[G]oto [D]efinition')
          map('gr',         tb.lsp_references,                '[G]oto [R]eferences')
          map('gI',         tb.lsp_implementations,           '[G]oto [I]mplementation')
          map('gD',         vim.lsp.buf.declaration,          '[G]oto [D]eclaration')
          map('<leader>D',  tb.lsp_type_definitions,          'Type [D]efinition')
          map('<leader>ds', tb.lsp_document_symbols,          '[D]ocument [S]ymbols')
          map('<leader>ws', tb.lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
          map('<leader>rn', vim.lsp.buf.rename,               '[R]e[n]ame')
          map('<leader>ca', vim.lsp.buf.code_action,          '[C]ode [A]ction', { 'n', 'x' })
          map('K',          vim.lsp.buf.hover,                'LSP Hover Doc')

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if not client then return end

          if client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local g = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf, group = g, callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf, group = g, callback = vim.lsp.buf.clear_references,
            })
            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
              callback = function(ev)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'lsp-highlight', buffer = ev.buf }
              end,
            })
          end

          if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      vim.diagnostic.config {
        severity_sort = true,
        float     = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs     = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN]  = '󰀪 ',
            [vim.diagnostic.severity.INFO]  = '󰋽 ',
            [vim.diagnostic.severity.HINT]  = '󰌶 ',
          },
        } or {},
        virtual_text = {
          source = 'if_many', spacing = 2,
          format = function(d) return d.message end,
        },
      }
    end,
  },
}
