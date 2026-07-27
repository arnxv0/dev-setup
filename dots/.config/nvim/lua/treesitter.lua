return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build  = ':TSUpdate',
    lazy   = false,
    config = function()
      local extra = {
        -- base parsers (parity with the previous kickstart ensure_installed set)
        'bash', 'c', 'diff', 'lua', 'luadoc',
        'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc',
        -- languages
        'dart', 'rust', 'haskell', 'go', 'gomod', 'gosum',
        'typescript', 'javascript', 'tsx', 'astro',
        'css', 'html', 'json', 'toml', 'yaml', 'dockerfile',
      }
      local ok, install_mod = pcall(require, 'nvim-treesitter.install')
      if ok then
        local installed  = install_mod.get_installed()
        local to_install = vim.tbl_filter(function(p)
          return not vim.tbl_contains(installed, p)
        end, extra)
        if #to_install > 0 then require('nvim-treesitter').install(to_install) end
      end

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('nvim-treesitter', { clear = true }),
        callback = function(ev)
          if pcall(vim.treesitter.start, ev.buf) then
            if vim.treesitter.get_parser(ev.buf) then
              vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          end
        end,
      })
    end,
  },
}
