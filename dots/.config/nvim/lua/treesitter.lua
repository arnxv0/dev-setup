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
      -- get_installed() only exists on the `main` branch. Guard the CALL as well
      -- as the require: a stale clone left on `master` has the module but not
      -- the function, which hard-errors the whole config.
      local ok_cfg, ts = pcall(require, 'nvim-treesitter')
      local installed = {}
      for _, mod in ipairs { 'nvim-treesitter.config', 'nvim-treesitter.install' } do
        local ok_m, m = pcall(require, mod)
        if ok_m and type(m) == 'table' and type(m.get_installed) == 'function' then
          local ok_call, res = pcall(m.get_installed)
          if ok_call and type(res) == 'table' then installed = res end
          break
        end
      end
      if ok_cfg and type(ts.install) == 'function' then
        local to_install = vim.tbl_filter(function(p)
          return not vim.tbl_contains(installed, p)
        end, extra)
        if #to_install > 0 then pcall(ts.install, to_install) end
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
