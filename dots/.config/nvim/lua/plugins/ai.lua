-- AI inline completion (minuet-ai.nvim), cloud when online, local when not.
--
-- Only loaded when LLM features are enabled on this machine (`./run.sh --llm`,
-- see vim.g.llm_enabled in init.lua). Otherwise this file adds nothing.
--
-- Backend is picked automatically and re-checked every 30s and on FocusGained:
--   key set + cloud reachable  -> Claude (ANTHROPIC_API_KEY) or OpenAI
--                                 (OPENAI_API_KEY); MINUET_CLOUD=openai prefers
--                                 OpenAI when both keys exist
--   otherwise, Ollama running  -> local model (MINUET_LOCAL_MODEL, default
--                                 qwen3.8-coder:latest)
--   neither                    -> completion pauses instead of erroring on
--                                 every keystroke
--
-- Keys come from the environment, never from this repo. Put them in
-- ~/.config/dev-setup/secrets.zsh (created by setup-dots.sh, chmod 600).
--
-- Local models go through Ollama's /v1/chat/completions, not the FIM
-- /v1/completions endpoint: the installed qwen3.x MLX builds reject `suffix`
-- ("does not support insert"). Thinking is switched off on every backend; it
-- adds seconds of latency and nothing to a one-line completion.
--
-- :MinuetAuto toggles the automatic switching, so a manual
-- `:Minuet change_provider ...` sticks.

local LOCAL_MODEL = vim.env.MINUET_LOCAL_MODEL or 'qwen3.8-coder:latest'
local OLLAMA = vim.env.OLLAMA_HOST and ('http://' .. vim.env.OLLAMA_HOST:gsub('^https?://', '')) or 'http://localhost:11434'

-- 'claude' | 'openai' | 'local' | 'none'
local mode = 'none'
local auto = true
local announced = false -- stay quiet about the first pick at startup

local function has_env(name) return (vim.env[name] or '') ~= '' end

local function cloud_choice()
  local claude, openai = has_env 'ANTHROPIC_API_KEY', has_env 'OPENAI_API_KEY'
  if claude and openai then return vim.env.MINUET_CLOUD == 'openai' and 'openai' or 'claude' end
  if claude then return 'claude' end
  if openai then return 'openai' end
end

local CLOUD_URL = { claude = 'https://api.anthropic.com', openai = 'https://api.openai.com' }

-- Any HTTP status at all means the host answered; curl prints 000 when it
-- could not connect.
local function reachable(url, timeout, cb)
  vim.system({ 'curl', '-s', '-o', '/dev/null', '-m', tostring(timeout), '-w', '%{http_code}', url },
    { text = true }, function(r) cb(r.code == 0 and vim.trim(r.stdout or '') ~= '000') end)
end

local function warm_local()
  -- Loads the model and keeps it resident, so the first completion does not
  -- spend its whole timeout on a cold load (~8s for an 18GB model).
  vim.system { 'curl', '-s', '-o', '/dev/null', '-m', '120', OLLAMA .. '/api/generate',
    '-d', vim.json.encode { model = LOCAL_MODEL, keep_alive = '30m' } }
end

local function apply(new)
  if new == mode then return end
  mode = new
  local cfg = require('minuet').config
  if new == 'local' then
    cfg.provider = 'openai_compatible'
    cfg.context_window = 4000
    cfg.n_completions = 1
    cfg.request_timeout = 5
    cfg.throttle, cfg.debounce = 400, 150
    warm_local()
  elseif new ~= 'none' then
    cfg.provider = new
    cfg.context_window = 16000
    cfg.n_completions = 2
    cfg.request_timeout = 3
    cfg.throttle, cfg.debounce = 1000, 400
  end
  if announced then
    vim.notify('AI completion: ' .. (new == 'none' and 'off (no network, no ollama)' or new),
      vim.log.levels.INFO, { title = 'minuet' })
  end
  announced = true
end

local function refresh()
  if not auto then return end
  local cloud = cloud_choice()
  local function try_local()
    reachable(OLLAMA .. '/api/tags', 1, function(ok)
      vim.schedule(function() apply(ok and 'local' or 'none') end)
    end)
  end
  if not cloud then return try_local() end
  reachable(CLOUD_URL[cloud], 2, function(ok)
    if ok then vim.schedule(function() apply(cloud) end) else try_local() end
  end)
end

if not vim.g.llm_enabled then return {} end

return {
  {
    'milanglacier/minuet-ai.nvim',
    event = 'VeryLazy',
    config = function()
      require('minuet').setup {
        provider = 'openai_compatible',
        notify = 'warn',
        enable_predicates = { function() return mode ~= 'none' end },
        virtualtext = {
          auto_trigger_ft = { '*' },
          auto_trigger_ignore_ft = { 'TelescopePrompt', 'NvimTree', 'lazy', 'mason', 'help', 'gitcommit' },
          keymap = {
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
            model = 'claude-haiku-5-5',
            max_tokens = 256,
            optional = { thinking = { type = 'disabled' } },
          },
          openai = {
            model = 'gpt-5.6-luna',
            optional = { max_completion_tokens = 128, reasoning_effort = 'none' },
          },
          openai_compatible = {
            name = 'Ollama',
            api_key = 'TERM', -- Ollama needs no key, but minuet needs a non-empty env var
            end_point = OLLAMA .. '/v1/chat/completions',
            model = LOCAL_MODEL,
            optional = { max_tokens = 256, reasoning_effort = 'none' },
          },
        },
      }

      refresh()
      vim.uv.new_timer():start(30000, 30000, vim.schedule_wrap(refresh))
      vim.api.nvim_create_autocmd('FocusGained', {
        group = vim.api.nvim_create_augroup('minuet-auto', { clear = true }),
        callback = refresh,
      })
      vim.api.nvim_create_user_command('MinuetAuto', function()
        auto = not auto
        vim.notify('AI backend auto-switch ' .. (auto and 'on' or 'off'), vim.log.levels.INFO, { title = 'minuet' })
        if auto then mode = nil; refresh() end
      end, { desc = 'Toggle automatic cloud/local switching for minuet' })
    end,
  },

  -- current backend in the statusline
  {
    'nvim-lualine/lualine.nvim',
    optional = true,
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 1, function()
        return package.loaded['minuet'] and ('AI:' .. (auto and '' or '!') .. (mode or '…')) or ''
      end)
    end,
  },
}
