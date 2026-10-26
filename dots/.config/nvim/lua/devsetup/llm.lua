-- LLM backend state for minuet: which backend is live, which model each one
-- uses, API keys, and the automatic cloud/local switching.
--
-- Two files outside the repo hold what the panel (devsetup/llm_panel.lua)
-- changes:
--   ~/.config/dev-setup/secrets.zsh  API keys, as `export NAME='...'` lines,
--                                    so shells get them too (mode 600)
--   ~/.config/dev-setup/llm.json     backend pin, models, Ollama host,
--                                    suggestions on/off
--
-- Precedence: llm.json, then MINUET_* env vars, then the defaults below.

local M = {}

local DIR = vim.fn.expand '~/.config/dev-setup'
local SECRETS = DIR .. '/secrets.zsh'
local STATE_FILE = DIR .. '/llm.json'

M.KEY_ENV = { claude = 'ANTHROPIC_API_KEY', openai = 'OPENAI_API_KEY' }
local CLOUD_URL = { claude = 'https://api.anthropic.com', openai = 'https://api.openai.com' }

M.state = {
  pin = 'auto', -- 'auto' | 'claude' | 'openai' | 'local'
  suggest = true,
  ollama_host = vim.env.OLLAMA_HOST or 'localhost:11434',
  models = {
    claude = 'claude-haiku-5-5',
    openai = 'gpt-5.6-luna',
    ['local'] = vim.env.MINUET_LOCAL_MODEL or 'qwen3.8-coder:latest',
  },
}
-- Live facts from the last probe; not persisted.
M.mode = 'none' -- backend actually in use: 'claude' | 'openai' | 'local' | 'none'
M.online = nil
M.ollama_up = nil

local listeners = {}
function M.on_change(fn) listeners[#listeners + 1] = fn end
local function changed()
  for _, fn in ipairs(listeners) do pcall(fn) end
end

-- ── persistence ──────────────────────────────────────────────────────────────
local function load_state()
  local f = io.open(STATE_FILE, 'r')
  if not f then return end
  local ok, saved = pcall(vim.json.decode, f:read '*a')
  f:close()
  if ok and type(saved) == 'table' then M.state = vim.tbl_deep_extend('force', M.state, saved) end
end

local function save_state()
  vim.fn.mkdir(DIR, 'p')
  local f = io.open(STATE_FILE, 'w')
  if not f then return end
  f:write(vim.json.encode(M.state))
  f:close()
end

function M.ollama_url()
  return 'http://' .. M.state.ollama_host:gsub('^https?://', '')
end

-- ── API keys ─────────────────────────────────────────────────────────────────
function M.has_key(provider) return (vim.env[M.KEY_ENV[provider]] or '') ~= '' end

function M.masked_key(provider)
  local k = vim.env[M.KEY_ENV[provider]] or ''
  if k == '' then return nil end
  return '••••' .. k:sub(-4)
end

-- Rewrites (or appends) the one `export NAME=` line in secrets.zsh, so the key
-- also reaches new shells. value == nil comments the line out instead.
function M.set_key(provider, value)
  local name = M.KEY_ENV[provider]
  local lines = {}
  local f = io.open(SECRETS, 'r')
  if f then
    for l in f:lines() do lines[#lines + 1] = l end
    f:close()
  end
  local new = value and string.format("export %s='%s'", name, value:gsub("'", [['\'']]))
    or string.format("# export %s=''", name)
  local pat = '^%s*#?%s*export%s+' .. name .. '='
  local done = false
  for i, l in ipairs(lines) do
    if l:match(pat) then
      if done then lines[i] = '' else lines[i], done = new, true end
    end
  end
  if not done then lines[#lines + 1] = new end

  vim.fn.mkdir(DIR, 'p')
  local out = assert(io.open(SECRETS, 'w'))
  out:write(table.concat(lines, '\n') .. '\n')
  out:close()
  vim.uv.fs_chmod(SECRETS, tonumber('600', 8))

  vim.env[name] = value
  M.mode = nil -- force apply() to re-run with the new key
  M.refresh()
end

-- ── applying a backend to minuet ─────────────────────────────────────────────
local function warm_local()
  -- Loads the model and keeps it resident, so the first completion does not
  -- spend its whole timeout on a cold load (~8s for an 18GB model).
  vim.system { 'curl', '-s', '-o', '/dev/null', '-m', '120', M.ollama_url() .. '/api/generate',
    '-d', vim.json.encode { model = M.state.models['local'], keep_alive = '30m' } }
end
M.warm_local = warm_local

local announced = false -- stay quiet about the first pick at startup

local function apply(new)
  local cfg = require('minuet').config
  -- models and host can change without the backend changing, so always sync
  cfg.provider_options.claude.model = M.state.models.claude
  cfg.provider_options.openai.model = M.state.models.openai
  cfg.provider_options.openai_compatible.model = M.state.models['local']
  cfg.provider_options.openai_compatible.end_point = M.ollama_url() .. '/v1/chat/completions'

  if new == M.mode then return changed() end
  M.mode = new
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
    vim.notify('AI completion: ' .. (new == 'none' and 'off (no backend reachable)' or new),
      vim.log.levels.INFO, { title = 'minuet' })
  end
  announced = true
  changed()
end

-- Any HTTP status at all means the host answered; curl prints 000 when it
-- could not connect.
local function reachable(url, timeout, cb)
  vim.system({ 'curl', '-s', '-o', '/dev/null', '-m', tostring(timeout), '-w', '%{http_code}', url },
    { text = true }, function(r)
      local ok = r.code == 0 and vim.trim(r.stdout or '') ~= '000'
      vim.schedule(function() cb(ok) end)
    end)
end

local function preferred_cloud()
  local claude, openai = M.has_key 'claude', M.has_key 'openai'
  if claude and openai then return vim.env.MINUET_CLOUD == 'openai' and 'openai' or 'claude' end
  if claude then return 'claude' end
  if openai then return 'openai' end
end

-- Probes what is reachable and picks the backend. A pinned backend is used as
-- long as it is usable; otherwise auto rules apply (cloud > local > none).
function M.refresh()
  reachable(M.ollama_url() .. '/api/tags', 1, function(up)
    M.ollama_up = up
    local pin = M.state.pin
    local cloud = (pin == 'claude' or pin == 'openai') and pin or preferred_cloud()
    local function fallback() apply(up and 'local' or 'none') end
    if pin == 'local' then return fallback() end
    if not cloud or not M.has_key(cloud) then M.online = nil; return fallback() end
    reachable(CLOUD_URL[cloud], 2, function(ok)
      M.online = ok
      if ok then apply(cloud) else fallback() end
    end)
  end)
end

-- ── settings the panel changes ───────────────────────────────────────────────
function M.set_pin(pin)
  M.state.pin = pin
  save_state()
  M.refresh()
end

function M.set_model(backend, model)
  M.state.models[backend] = model
  save_state()
  if backend == 'local' and M.mode == 'local' then warm_local() end
  M.mode = nil
  M.refresh()
end

function M.set_ollama_host(host)
  M.state.ollama_host = host
  save_state()
  M.mode = nil
  M.refresh()
end

function M.set_suggest(on)
  M.state.suggest = on
  save_state()
  changed()
end

function M.enabled() return M.state.suggest and M.mode ~= 'none' and M.mode ~= nil end

-- ── model lists ──────────────────────────────────────────────────────────────
-- Keys go to curl on stdin (-H @-), never in argv, so they do not show up in
-- `ps` for other processes on the machine.
local function get_json(url, headers, cb)
  vim.system({ 'curl', '-s', '-m', '5', '-H', '@-', url },
    { text = true, stdin = table.concat(headers, '\n') .. '\n' }, function(r)
      local ok, data = pcall(vim.json.decode, r.stdout or '')
      vim.schedule(function() cb(ok and type(data) == 'table' and data or nil) end)
    end)
end

-- cb(list_of_model_ids) or cb(nil, error_message)
function M.list_models(backend, cb)
  if backend == 'local' then
    return get_json(M.ollama_url() .. '/api/tags', {}, function(d)
      if not d or not d.models then return cb(nil, 'Ollama not reachable at ' .. M.state.ollama_host) end
      local ids = {}
      for _, m in ipairs(d.models) do ids[#ids + 1] = m.name end
      table.sort(ids)
      cb(ids)
    end)
  end
  if not M.has_key(backend) then return cb(nil, 'set the ' .. backend .. ' API key first') end
  local key = vim.env[M.KEY_ENV[backend]]
  local headers = backend == 'claude'
      and { 'x-api-key: ' .. key, 'anthropic-version: 2023-06-01' }
      or { 'Authorization: Bearer ' .. key }
  get_json(CLOUD_URL[backend] .. '/v1/models?limit=1000', headers, function(d)
    if not d or not d.data then
      local msg = d and d.error and (d.error.message or vim.inspect(d.error)) or 'request failed'
      return cb(nil, msg)
    end
    local ids = {}
    for _, m in ipairs(d.data) do
      -- OpenAI lists embeddings, tts, image models...; keep chat-capable ones
      if backend == 'claude' or m.id:match '^gpt' or m.id:match '^o%d' or m.id:match 'codex' then
        if not (m.id:match 'audio' or m.id:match 'realtime' or m.id:match 'image' or m.id:match 'tts' or m.id:match 'transcribe') then
          ids[#ids + 1] = m.id
        end
      end
    end
    table.sort(ids)
    cb(ids)
  end)
end

function M.setup()
  load_state()
  M.refresh()
  vim.uv.new_timer():start(30000, 30000, vim.schedule_wrap(M.refresh))
  vim.api.nvim_create_autocmd('FocusGained', {
    group = vim.api.nvim_create_augroup('devsetup-llm', { clear = true }),
    callback = M.refresh,
  })
end

return M
