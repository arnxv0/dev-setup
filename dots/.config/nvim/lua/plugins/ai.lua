-- AI inline completion (minuet-ai.nvim), cloud when online, local when not.
--
-- Only loaded when LLM features are enabled on this machine (`./run.sh --llm`,
-- see vim.g.llm_enabled in init.lua). Otherwise this file adds nothing.
--
-- Backend selection, keys and models live in lua/devsetup/llm.lua; the
-- settings panel in lua/devsetup/llm_panel.lua.
--
--   :AI / <leader>L        settings panel (keys, backend, models, Ollama)
--   :AI on|off|toggle      suggestions on/off (remembered)
--
-- Local models go through Ollama's /v1/chat/completions, not the FIM
-- /v1/completions endpoint: the installed qwen3.x MLX builds reject `suffix`
-- ("does not support insert"). Thinking is switched off on every backend; it
-- adds seconds of latency and nothing to a one-line completion.

if not vim.g.llm_enabled then return {} end

return {
  {
    'milanglacier/minuet-ai.nvim',
    event = 'VeryLazy',
    cmd = 'AI',
    keys = { { '<leader>L', '<cmd>AI<cr>', desc = 'LLM settings' } },
    config = function()
      local llm = require 'devsetup.llm'
      require('minuet').setup {
        provider = 'openai_compatible',
        notify = 'warn',
        enable_predicates = { llm.enabled },
        virtualtext = {
          auto_trigger_ft = { '*' },
          auto_trigger_ignore_ft = { 'TelescopePrompt', 'NvimTree', 'lazy', 'mason', 'help', 'gitcommit', 'devsetup-llm' },
          keymap = {
            -- <Tab> also accepts; see plugins/completion.lua
            accept         = '<A-A>', -- whole suggestion
            accept_line    = '<A-a>',
            accept_n_lines = '<A-z>', -- then a count and <CR>
            prev           = '<A-[>', -- cycle, or request one manually
            next           = '<A-]>',
            dismiss        = '<A-e>',
          },
        },
        provider_options = {
          claude = {
            model = llm.state.models.claude,
            max_tokens = 256,
            optional = { thinking = { type = 'disabled' } },
          },
          openai = {
            model = llm.state.models.openai,
            optional = { max_completion_tokens = 128, reasoning_effort = 'none' },
          },
          openai_compatible = {
            name = 'Ollama',
            api_key = 'TERM', -- Ollama needs no key, but minuet needs a non-empty env var
            end_point = llm.ollama_url() .. '/v1/chat/completions',
            model = llm.state.models['local'],
            optional = { max_tokens = 256, reasoning_effort = 'none' },
          },
        },
      }
      llm.setup()

      vim.api.nvim_create_user_command('AI', function(o)
        local arg = o.args
        if arg == '' then return require('devsetup.llm_panel').open() end
        local on = ({ on = true, off = false, toggle = not llm.state.suggest })[arg]
        if on == nil then return vim.notify('usage: :AI [on|off|toggle]', vim.log.levels.ERROR) end
        llm.set_suggest(on)
        if not on then pcall(require('minuet.virtualtext').action.dismiss) end
        vim.notify('AI suggestions ' .. (on and 'on' or 'off'), vim.log.levels.INFO, { title = 'LLM' })
      end, { nargs = '?', complete = function() return { 'on', 'off', 'toggle' } end, desc = 'LLM settings / suggestions on|off' })
    end,
  },

  -- current backend in the statusline
  {
    'nvim-lualine/lualine.nvim',
    optional = true,
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 1, function()
        if not package.loaded['devsetup.llm'] then return '' end
        local llm = require 'devsetup.llm'
        if not llm.state.suggest then return 'AI:off' end
        return 'AI:' .. (llm.state.pin ~= 'auto' and '!' or '') .. (llm.mode or '…')
      end)
    end,
  },
}
