return {
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      {
        'L3MON4D3/LuaSnip',
        build = (function()
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then return end
          return 'make install_jsregexp'
        end)(),
      },
      'saadparwaiz1/cmp_luasnip',
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-nvim-lsp-signature-help',
    },
    config = function()
      local cmp     = require 'cmp'
      local luasnip = require 'luasnip'
      luasnip.config.setup {}
      cmp.setup {
        snippet  = { expand = function(a) luasnip.lsp_expand(a.body) end },
        completion = { completeopt = 'menu,menuone,noinsert' },
        mapping  = cmp.mapping.preset.insert {
          ['<C-n>']     = cmp.mapping.select_next_item(),
          ['<C-p>']     = cmp.mapping.select_prev_item(),
          ['<C-b>']     = cmp.mapping.scroll_docs(-4),
          ['<CR>']      = cmp.mapping.confirm { select = true },
          -- Copilot-style: Tab accepts the AI ghost text when one is showing
          -- (minuet, plugins/ai.lua), otherwise it is cmp's next item / a
          -- plain Tab. package.loaded, not require: requiring would load
          -- minuet on a machine where LLM features are off.
          ['<Tab>'] = cmp.mapping(function(fallback)
            local vt = package.loaded['minuet.virtualtext']
            if vt and vt.action.is_visible() then
              vt.action.accept()
            elseif cmp.visible() then
              cmp.select_next_item()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<C-Space>'] = cmp.mapping.complete {},
          ['<C-l>'] = cmp.mapping(function()
            if luasnip.expand_or_locally_jumpable() then luasnip.expand_or_jump() end
          end, { 'i', 's' }),
          ['<C-h>'] = cmp.mapping(function()
            if luasnip.locally_jumpable(-1) then luasnip.jump(-1) end
          end, { 'i', 's' }),
        },
        sources = {
          { name = 'lazydev', group_index = 0 },
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'path' },
          { name = 'nvim_lsp_signature_help' },
        },
      }
    end,
  },
}
