-- Floating LLM settings panel: :AI or <leader>L.
--
-- A menu: j/k (or arrows) move between rows, <CR> acts on the row. Every row
-- also has a one-key shortcut, shown dimmed on the right. Everything it
-- changes goes through devsetup/llm.lua, which persists it and re-picks the
-- backend.

local llm = require 'devsetup.llm'

local M = {}
local buf, win
local ns = vim.api.nvim_create_namespace 'devsetup-llm-panel'
local WIDTH = 72
local items = {} -- line number (1-based) -> item, for the rows that act
local item_lines = {} -- sorted line numbers of those rows
local cur = 1 -- index into item_lines, kept across re-renders

local NAMES = { claude = 'Claude', openai = 'OpenAI', ['local'] = 'Local (Ollama)', none = 'Nothing', auto = 'Auto' }

-- string.format's %-Ns pads by bytes; bullets and arrows are multi-byte
local function pad(s, w) return s .. string.rep(' ', math.max(1, w - vim.fn.strdisplaywidth(s))) end

-- ── actions ──────────────────────────────────────────────────────────────────
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
  vim.notify('fetching ' .. NAMES[backend] .. ' models…', vim.log.levels.INFO, { title = 'LLM' })
  llm.list_models(backend, function(ids, err)
    if not ids then return vim.notify(err, vim.log.levels.ERROR, { title = 'LLM' }) end
    if #ids == 0 then return vim.notify('no models found', vim.log.levels.WARN, { title = 'LLM' }) end
    vim.ui.select(ids, {
      prompt = NAMES[backend] .. ' model',
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

local function warm()
  llm.warm_local()
  vim.notify('loading ' .. llm.state.models['local'] .. ' into memory…', vim.log.levels.INFO, { title = 'LLM' })
end

local function recheck()
  llm.mode = nil
  llm.refresh()
end

-- ── rendering ────────────────────────────────────────────────────────────────
local function build()
  local s = llm.state
  local lines, hls = {}, {}
  items, item_lines = {}, {}

  local function hl(group, line, from, to) hls[#hls + 1] = { line, from, to, group } end
  local function blank() lines[#lines + 1] = '' end
  local function header(title)
    blank()
    local text = '   ' .. title .. ' ' .. string.rep('─', WIDTH - 6 - vim.fn.strdisplaywidth(title))
    lines[#lines + 1] = text
    hl('Title', #lines, 3, 3 + #title)
    hl('FloatBorder', #lines, 3 + #title, #text)
    blank()
  end
  -- label | value | dimmed shortcut on the right
  local function item(label, value, value_hl, key, action, mark)
    local left = '     ' .. pad(mark or ' ', 3) .. pad(label, 18)
    local text = left .. value
    local key_text = key and ('[' .. key .. ']') or ''
    text = pad(text, WIDTH - 2 - #key_text) .. key_text
    lines[#lines + 1] = text
    local ln = #lines
    items[ln] = { action = action }
    item_lines[#item_lines + 1] = ln
    if mark then hl(mark == '●' and 'DiagnosticOk' or 'Comment', ln, 5, 5 + #mark) end
    if value_hl then hl(value_hl, ln, #left, #left + #value) end
    if key then hl('Comment', ln, #text - #key_text, #text) end
  end

  -- status
  local live = llm.mode or '…'
  local model = s.models[live]
  blank()
  local line = '   ' .. (live == 'none' and '✕' or '●') .. '  ' .. (NAMES[live] or live) .. (model and ('  ·  ' .. model) or '')
  lines[#lines + 1] = line
  hl(live == 'none' and 'DiagnosticError' or 'DiagnosticOk', #lines, 3, #line)
  local sub = '      ' .. (s.pin == 'auto' and 'switching automatically' or ('pinned to ' .. NAMES[s.pin]))
    .. '   ·   suggestions ' .. (s.suggest and 'on' or 'off')
  lines[#lines + 1] = sub
  hl('Comment', #lines, 0, #sub)
  if not s.suggest then hl('DiagnosticWarn', #lines, #sub - 3, #sub) end

  -- backend
  header 'Backend'
  local function reason(b)
    if b == 'auto' then return 'cloud when online, local otherwise', 'Comment' end
    if b == 'local' then
      if llm.ollama_up == nil then return 'checking…', 'Comment' end
      return llm.ollama_up and 'Ollama running' or 'Ollama not running', llm.ollama_up and 'Comment' or 'DiagnosticWarn'
    end
    if not llm.has_key(b) then return 'needs an API key', 'DiagnosticWarn' end
    if llm.mode == b then return 'connected', 'DiagnosticOk' end
    return 'key set', 'Comment'
  end
  for _, b in ipairs { { 'auto', 'a' }, { 'claude', 'c' }, { 'openai', 'o' }, { 'local', 'l' } } do
    local text, group = reason(b[1])
    item(NAMES[b[1]], text, group, b[2], function() llm.set_pin(b[1]) end, s.pin == b[1] and '●' or '○')
  end

  -- providers
  local function provider(name, id, key_key, model_key)
    header(name)
    local masked = llm.masked_key(id)
    item('API key', masked or 'not set', masked and 'Identifier' or 'DiagnosticWarn', key_key, function() prompt_key(id) end)
    item('Model', s.models[id], 'Identifier', model_key, function() pick_model(id) end)
  end
  provider('Claude', 'claude', 'C', 'm')
  provider('OpenAI', 'openai', 'O', 'M')

  header 'Ollama (offline)'
  local up = llm.ollama_up
  item('Host', s.ollama_host .. (up == nil and '' or (up and '   ● running' or '   ✕ not running')),
    up and 'Identifier' or (up == false and 'DiagnosticWarn' or 'Identifier'), 'h', prompt_host)
  item('Model', s.models['local'], 'Identifier', 'L', function() pick_model 'local' end)
  item('Preload model', 'load now for a fast first suggestion', 'Comment', 'w', warm)

  header 'General'
  item('Suggestions', s.suggest and 'on' or 'off', s.suggest and 'DiagnosticOk' or 'DiagnosticWarn', 't',
    function() vim.cmd 'AI toggle' end)
  item('Recheck', 'test internet and Ollama again', 'Comment', 'r', recheck)

  blank()
  blank()
  for _, foot in ipairs { '   j/k move    ⏎ select    q close',
                          '   New keys reach other terminal panes after `exec zsh`.' } do
    lines[#lines + 1] = foot
    hl('Comment', #lines, 0, #foot)
  end
  blank()
  return lines, hls
end

local function render()
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
  local lines, hls = build()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(hls) do
    vim.api.nvim_buf_set_extmark(buf, ns, h[1] - 1, h[2], { end_col = math.min(h[3], #lines[h[1]]), hl_group = h[4] })
  end
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_config(win, {
      relative = 'editor', height = math.min(#lines, vim.o.lines - 4),
      row = math.max(0, math.floor((vim.o.lines - #lines) / 2) - 1),
      col = math.floor((vim.o.columns - WIDTH) / 2),
    })
    cur = math.max(1, math.min(cur, #item_lines))
    vim.api.nvim_win_set_cursor(win, { item_lines[cur], 5 })
  end
end

local function move(delta)
  cur = math.max(1, math.min(#item_lines, cur + delta))
  vim.api.nvim_win_set_cursor(win, { item_lines[cur], 5 })
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
    title = '  LLM settings  ', title_pos = 'center',
    width = WIDTH, height = 10, row = 2, col = math.floor((vim.o.columns - WIDTH) / 2),
  })
  vim.wo[win].cursorline = true
  vim.wo[win].winhighlight = 'CursorLine:Visual'

  local map = function(lhs, fn)
    vim.keymap.set('n', lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
  for _, k in ipairs { 'j', '<Down>', '<Tab>' } do map(k, function() move(1) end) end
  for _, k in ipairs { 'k', '<Up>', '<S-Tab>' } do map(k, function() move(-1) end) end
  map('gg', function() move(-#item_lines) end)
  map('G', function() move(#item_lines) end)
  local function act()
    local it = items[vim.api.nvim_win_get_cursor(win)[1]]
    if it then it.action() end
  end
  map('<CR>', act)
  map('<Space>', act)

  -- one-key shortcuts; j/k stay movement, so the key prompts are C and O
  map('a', function() llm.set_pin 'auto' end)
  map('c', function() llm.set_pin 'claude' end)
  map('o', function() llm.set_pin 'openai' end)
  map('l', function() llm.set_pin 'local' end)
  map('C', function() prompt_key 'claude' end)
  map('O', function() prompt_key 'openai' end)
  map('m', function() pick_model 'claude' end)
  map('M', function() pick_model 'openai' end)
  map('L', function() pick_model 'local' end)
  map('h', prompt_host)
  map('w', warm)
  map('t', function() vim.cmd 'AI toggle' end)
  map('r', recheck)
  map('q', M.close)
  map('<Esc>', M.close)

  -- mouse clicks or stray motions land on a non-row: snap to the nearest row
  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = buf,
    callback = function()
      local ln = vim.api.nvim_win_get_cursor(win)[1]
      if items[ln] then
        for i, l in ipairs(item_lines) do if l == ln then cur = i end end
        return
      end
      local best, dist = cur, math.huge
      for i, l in ipairs(item_lines) do
        if math.abs(l - ln) < dist then best, dist = i, math.abs(l - ln) end
      end
      cur = best
      vim.api.nvim_win_set_cursor(win, { item_lines[cur], 5 })
    end,
  })

  render()
  llm.refresh()
end

llm.on_change(render)

return M
