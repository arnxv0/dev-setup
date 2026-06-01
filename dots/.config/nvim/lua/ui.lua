return {
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      require('tokyonight').setup {
        styles = { comments = { italic = false } },
        on_colors = function(c)
          c.bg         = '#16161e'
          c.bg_sidebar = '#1a1b26'
        end,
      }
      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },

  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      options = {
        icons_enabled = true, theme = 'auto',
        component_separators = { left = '', right = '' },
        section_separators   = { left = '', right = '' },
        always_divide_middle = true, always_show_tabline = true,
        globalstatus = false,
        refresh = { statusline = 100, tabline = 100, winbar = 100 },
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { {
          'filename', file_status = true, path = 3, shorting_target = 40,
          symbols = { modified = '[+]', readonly = '[-]', unnamed = '[No Name]', newfile = '[New]' },
        } },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
      inactive_sections = {
        lualine_a = {}, lualine_b = {},
        lualine_c = { 'filename' }, lualine_x = { 'location' },
        lualine_y = {}, lualine_z = {},
      },
    },
  },

  {
    'nvim-tree/nvim-tree.lua',
    version = '*',
    lazy = false,
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('nvim-tree').setup { update_focused_file = { enable = true } }
    end,
  },

  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {
      indent = { char = '┊' },
      scope  = { show_start = false, show_end = false },
    },
  },
}
