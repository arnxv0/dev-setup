-- Floating LLM settings panel: :AI or <leader>L.
--
-- Single-key actions, shown in the panel itself. Everything it changes goes
-- through devsetup/llm.lua, which persists it and re-picks the backend.

local llm = require 'devsetup.llm'

local M = {}
local buf, win
local ns = vim.api.nvim_create_namespace 'devsetup-llm-panel'
local WIDTH = 64

-- string.format's %-10s pads by bytes; the masked key's bullets are 3 bytes each
local function pad(str, w) return str .. string.rep(' ', math.max(1, w - vim.fn.strdisplaywidth(str))) end

local function dot(ok)
  if ok == nil then return '○' end
  return ok and '●' or '✕'
end

local function render()
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
  local s = llm.state
  local hl = {} -- { line, col_start, col_end, group }
  local lines = {}
  local function add(text, groups)
    lines[#lines + 1] = text
    for _, g in ipairs(groups or {}) do
      local a, b = text:find(g[1], 1, true)
      if a then hl[#hl + 1] = { #lines - 1, a - 1, b, g[2] } end
    end
  end

  local live = llm.mode or '…'
  local model = ({ claude = s.models.claude, openai = s.models.openai, ['local'] = s.models['local'] })[live]
  add('')
  add(string.format('  Now using   %s %s%s', live, model and ('· ' .. model) or '',
    s.suggest and '' or '   (suggestions off)'),
    { { live, live == 'none' and 'DiagnosticError' or 'DiagnosticOk' }, { '(suggestions off)', 'DiagnosticWarn' } })
  add('')

  local pins = { { 'auto', 'a' }, { 'claude', 'c' }, { 'openai', 'o' }, { 'local', 'l' } }
  local parts, groups = {}, {}
  for _, p in ipairs(pins) do
    local label = string.format('[%s] %s', p[2], p[1])
    if s.pin == p[1] then
      label = label .. ' ✓'
      groups[#groups + 1] = { label, 'DiagnosticOk' }
    end
    parts[#parts + 1] = label
  end
  add('  Backend     ' .. table.concat(parts, '  '), groups)
  add('')

  local claude_key = llm.masked_key 'claude' or 'no key'
  add('  Claude      ' .. pad(claude_key, 11) .. s.models.claude,
    { { 'no key', 'DiagnosticWarn' }, { s.models.claude, 'Identifier' } })
  add('              [k] set key   [m] pick model', { { '[k]', 'Special' }, { '[m]', 'Special' } })

  local openai_key = llm.masked_key 'openai' or 'no key'
  add('  OpenAI      ' .. pad(openai_key, 11) .. s.models.openai,
    { { 'no key', 'DiagnosticWarn' }, { s.models.openai, 'Identifier' } })
  add('              [K] set key   [M] pick model', { { '[K]', 'Special' }, { '[M]', 'Special' } })

  local up = llm.ollama_up
  add(string.format('  Ollama      %s %-16s %s', dot(up), s.ollama_host, s.models['local']),
    { { dot(up), up and 'DiagnosticOk' or 'DiagnosticError' }, { s.models['local'], 'Identifier' } })
  add('              [L] pick model   [h] host   [w] warm up', { { '[L]', 'Special' }, { '[h]', 'Special' }, { '[w]', 'Special' } })
  add('')
  add(string.format('  Internet    %s   %s', dot(llm.online),
    llm.online == nil and '(not checked: no cloud key or pinned local)' or (llm.online and 'reachable' or 'unreachable')),
    { { dot(llm.online), llm.online and 'DiagnosticOk' or 'Comment' }, { '(not checked', 'Comment' } })
  add('')
  add('  [t] suggestions on/off   [r] recheck   [q] close', { { '[t]', 'Special' }, { '[r]', 'Special' }, { '[q]', 'Special' } })
  add('  Keys apply here at once; other shells need `exec zsh`.', { { 'Keys apply', 'Comment' } })

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(hl) do
    vim.api.nvim_buf_set_extmark(buf, ns, h[1], h[2], { end_col = h[3], hl_group = h[4] })
  end
  for i, l in ipairs(lines) do
    for a, b in l:gmatch '()%[%a%]()' do
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, a - 1, { end_col = b - 1, hl_group = 'Special' })
    end
  end
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_height(win, #lines)
  end
end

local function prompt_key(provider)
  local name = provider == 'claude' and 'Anthropic' or 'OpenAI'
  local v = vim.fn.inputsecret(name .. ' API key (empty = cancel, "-" = remove): ')
  if v == '' then return end
  if v == '-' then
    llm.set_key(provider, nil)
    vim.notify(name .. ' key removed', vim.log.levels.INFO, { title = 'LLM' })
  else
    llm.set_key(provider, vim.trim(v))
    vim.notify(name .. ' key saved to ~/.config/dev-setup/secrets.zsh', vim.log.levels.INFO, { title = 'LLM' })
  end
end

local function pick_model(backend)
  vim.notify('fetching ' .. backend .. ' models…', vim.log.levels.INFO, { title = 'LLM' })
  llm.list_models(backend, function(ids, err)
    if not ids then return vim.notify(err, vim.log.levels.ERROR, { title = 'LLM' }) end
    if #ids == 0 then return vim.notify('no models found', vim.log.levels.WARN, { title = 'LLM' }) end
    vim.ui.select(ids, {
      prompt = backend .. ' model',
      format_item = function(id) return id == llm.state.models[backend] and (id .. '  ✓') or id end,
    }, function(choice)
      if choice then llm.set_model(backend, choice) end
    end)
  end)
end

local function prompt_host()
  vim.ui.input({ prompt = 'Ollama host: ', default = llm.state.ollama_host }, function(v)
    if v and vim.trim(v) ~= '' then llm.set_ollama_host(vim.trim(v)) end
  end)
end

function M.close()
  if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  win = nil
end

function M.open()
  if win and vim.api.nvim_win_is_valid(win) then return vim.api.nvim_set_current_win(win) end
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'devsetup-llm'
  win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor', style = 'minimal', border = 'rounded',
    title = ' LLM settings ', title_pos = 'center',
    width = WIDTH, height = 18,
    row = math.floor((vim.o.lines - 18) / 2) - 1,
    col = math.floor((vim.o.columns - WIDTH) / 2),
  })
  vim.wo[win].cursorline = false

  local map = function(lhs, fn)
    vim.keymap.set('n', lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
  map('a', function() llm.set_pin 'auto' end)
  map('c', function() llm.set_pin 'claude' end)
  map('o', function() llm.set_pin 'openai' end)
  map('l', function() llm.set_pin 'local' end)
  map('k', function() prompt_key 'claude' end)
  map('K', function() prompt_key 'openai' end)
  map('m', function() pick_model 'claude' end)
  map('M', function() pick_model 'openai' end)
  map('L', function() pick_model 'local' end)
  map('h', prompt_host)
  map('w', function()
    llm.warm_local()
    vim.notify('loading ' .. llm.state.models['local'] .. ' into memory…', vim.log.levels.INFO, { title = 'LLM' })
  end)
  map('t', function() vim.cmd 'AI toggle' end)
  map('r', function() llm.mode = nil; llm.refresh() end)
  map('q', M.close)
  map('<Esc>', M.close)

  render()
  llm.refresh()
end

llm.on_change(render)

return M
