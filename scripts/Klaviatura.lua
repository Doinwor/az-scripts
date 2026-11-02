script_name('GKB')
script_author('cuves and DeepSeek')
script_version('2.0')
script_description('Играю на сервер Mobile 2. Ник: Luma_Warrior')

local imgui = require('mimgui')
local ffi = require('ffi')
local inicfg = require('inicfg')
local faicons = require('fAwesome6')
local sampev = require('samp.events')

local MDS = MONET_DPI_SCALE or 1.0

local function clamp(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

local function copyTable(t)
  local r = {}
  for k, v in pairs(t) do
    r[k] = v
  end
  return r
end

local function toCp1251(text)
  return monet_utf8_to_cp1251(text)
end

local function toUtf8(text)
  return monet_cp1251_to_utf8(text)
end

local function trim(text)
  return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function esc(text)
  return (text:gsub('%%', '%%%%'))
end

local function safeLabel(text)
  while text:find('##', 1, true) do
    text = text:gsub('##', '# #')
  end
  return text
end

local function stripColors(text)
  return (text:gsub('{%x%x%x%x%x%x}', ''))
end

local function hexToRgb(hex)
  hex = (hex or '#3B82F6'):gsub('#', '')
  local r = tonumber(hex:sub(1, 2), 16) or 59
  local g = tonumber(hex:sub(3, 4), 16) or 130
  local b = tonumber(hex:sub(5, 6), 16) or 246
  return r / 255, g / 255, b / 255
end

local function rgbToHex(r, g, b)
  return ('#%02X%02X%02X'):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function contrastText(hex)
  local r, g, b = hexToRgb(hex)
  if r * 0.299 + g * 0.587 + b * 0.114 > 0.6 then return '#111111' end
  return '#FFFFFF'
end

local UTF8_CHAR = '[%z\1-\127\194-\244][\128-\191]*'

local function utf8chars(text)
  local out = {}
  for c in text:gmatch(UTF8_CHAR) do
    out[#out + 1] = c
  end
  return out
end

local KB_THEMES = {
  { name = 'Ночь', bg = '#15171C', key = '#2B303B', special = '#3C4454', accent = '#3399FF', text = '#F2F4F8' },
  { name = 'AMOLED', bg = '#000000', key = '#1A1A1A', special = '#2A2A2A', accent = '#00C2A8', text = '#FFFFFF' },
  { name = 'Светлая', bg = '#E6E9EF', key = '#FFFFFF', special = '#C9CFDB', accent = '#2F7BFF', text = '#1B1F27' },
  { name = 'Океан', bg = '#0E2233', key = '#17405E', special = '#1F567D', accent = '#2DD4BF', text = '#EAF6FF' },
  { name = 'Сакура', bg = '#2A1620', key = '#4A2636', special = '#63344A', accent = '#FF6FA5', text = '#FFEFF5' },
  { name = 'Мята', bg = '#10231D', key = '#1C4033', special = '#28594A', accent = '#4ADE80', text = '#EAFFF4' },
  { name = 'Аметист', bg = '#1D1530', key = '#352657', special = '#48347A', accent = '#A78BFA', text = '#F3EEFF' }
}

local KB_DEFAULT = {
  enabled = true, theme = 'Ночь', lang = 'RU',
  bg = '#15171C', key = '#2B303B', special = '#3C4454', accent = '#3399FF', text = '#F2F4F8',
  alpha = 0.97, keyAlpha = 1.0, keyHeight = 46, spacing = 5, rounding = 10, width = 72, fontScale = 1.1
}

local KB_LIMITS = {
  alpha = { 0.3, 1.0 }, keyAlpha = { 0.3, 1.0 }, keyHeight = { 32, 72 }, spacing = { 2, 14 },
  rounding = { 0, 24 }, width = { 40, 100 }, fontScale = { 0.8, 1.8 }
}

local G_DEFAULTS = {
  catch_input = true, close_after_send = true, show_phrases = true, hist_max = 30,
  cap_enabled = true, cap_x = 18, cap_y = 0, cap_w = 50, cap_h = 30,
  auto_caps = true, key_preview = true, alt_keys = true, swipe_space = true
}

local G_LIMITS = {
  hist_max = { 5, 100 },
  cap_x = { 0, 95 }, cap_y = { 0, 95 }, cap_w = { 5, 100 }, cap_h = { 5, 100 }
}

local UI_DEFAULTS = {
  themeColor = '#14161B', themeAlpha = 0.96, accent = '#3B82F6', uiRound = 12,
  btnSize = 44, btnShape = 100, btnX = 40, btnY = 300, btnLocked = false,
  showButton = true, uiPreset = 'Ночь'
}

local UI_LIMITS = {
  themeAlpha = { 0.3, 1.0 }, uiRound = { 0, 24 }, btnSize = { 32, 80 }, btnShape = { 0, 100 }
}

local DEFAULT_INI = {
  keyboard = copyTable(KB_DEFAULT),
  main = copyTable(G_DEFAULTS),
  ui = copyTable(UI_DEFAULTS)
}

local function readTable(raw, defaults, limits)
  local out = {}
  for k, d in pairs(defaults) do
    local v = raw and raw[k]
    if v == nil then
      out[k] = d
    elseif type(d) == 'boolean' then
      out[k] = v == true
    elseif type(d) == 'number' then
      local n = tonumber(v) or d
      local lim = limits and limits[k]
      if lim then n = clamp(n, lim[1], lim[2]) end
      out[k] = n
    else
      out[k] = tostring(v)
    end
  end
  return out
end

local rawIni = inicfg.load(DEFAULT_INI, 'GameKeyboard') or DEFAULT_INI
local kb = readTable(rawIni.keyboard, KB_DEFAULT, KB_LIMITS)
local cfg = readTable(rawIni.main, G_DEFAULTS, G_LIMITS)
local ui = readTable(rawIni.ui, UI_DEFAULTS, UI_LIMITS)

local function readList(section, prefix, limit)
  local out = {}
  if type(section) ~= 'table' then return out end
  for i = 1, limit do
    local v = section[prefix .. i]
    if v == nil then break end
    out[#out + 1] = tostring(v)
  end
  return out
end

local history = readList(rawIni.history, 'h', 100)
local phrases = readList(rawIni.phrases, 'p', 24)

local dirty = false
local dirtyStamp = 0

local function markDirty()
  dirty = true
  dirtyStamp = os.clock()
end

local function saveAll()
  local data = { keyboard = copyTable(kb), main = copyTable(cfg), ui = copyTable(ui), history = {}, phrases = {} }
  for i, text in ipairs(history) do
    data.history['h' .. i] = text
  end
  for i, text in ipairs(phrases) do
    data.phrases['p' .. i] = text
  end
  inicfg.save(data, 'GameKeyboard')
  dirty = false
end

local ICON_NAMES = {
  'COMMENT', 'PAPER_PLANE', 'CLOCK_ROTATE_LEFT', 'ANGLE_UP', 'ANGLE_DOWN', 'ANGLE_LEFT',
  'ANGLE_RIGHT', 'GEAR', 'EYE', 'EYE_SLASH', 'CHECK', 'TRASH', 'PLUS', 'MINUS', 'PASTE',
  'XMARK', 'CHEVRON_DOWN', 'ARROW_UP', 'CIRCLE_ARROW_UP', 'DELETE_LEFT', 'GLOBE',
  'KEYBOARD', 'PALETTE', 'ROTATE_LEFT', 'LOCK', 'LOCK_OPEN', 'BOLT', 'BULLSEYE',
  'HAND_POINTER'
}

local ICON_COMMENT = faicons('COMMENT')
local ICON_SEND = faicons('PAPER_PLANE')
local ICON_HIST = faicons('CLOCK_ROTATE_LEFT')
local ICON_UP = faicons('ANGLE_UP')
local ICON_DOWN = faicons('ANGLE_DOWN')
local ICON_LEFT = faicons('ANGLE_LEFT')
local ICON_RIGHT = faicons('ANGLE_RIGHT')
local ICON_GEAR = faicons('GEAR')
local ICON_EYE = faicons('EYE')
local ICON_EYE_OFF = faicons('EYE_SLASH')
local ICON_CHECK = faicons('CHECK')
local ICON_TRASH = faicons('TRASH')
local ICON_PLUS = faicons('PLUS')
local ICON_MINUS = faicons('MINUS')
local ICON_PASTE = faicons('PASTE')
local ICON_X = faicons('XMARK')
local ICON_HIDE = faicons('CHEVRON_DOWN')
local ICON_KB = faicons('KEYBOARD')
local ICON_PALETTE = faicons('PALETTE')
local ICON_RESET = faicons('ROTATE_LEFT')
local ICON_LOCK = faicons('LOCK')
local ICON_UNLOCK = faicons('LOCK_OPEN')
local ICON_TARGET = faicons('BULLSEYE')
local ICON_SHIFT = faicons('ARROW_UP')
local ICON_CAPS = faicons('CIRCLE_ARROW_UP')
local ICON_BKSP = faicons('DELETE_LEFT')
local ICON_GLOBE = faicons('GLOBE')


local V2 = imgui.ImVec2

local function textWidth(text)
  return imgui.CalcTextSize(text).x
end

local function measure(text)
  if text == '' then return 0 end
  return textWidth(text .. '|') - textWidth('|')
end

local function fitHead(chars, first, last, maxW)
  if last < first or maxW <= 0 then return first - 1 end
  local lo, hi = first - 1, last
  while lo < hi do
    local mid = math.ceil((lo + hi) / 2)
    if textWidth(table.concat(chars, '', first, mid)) <= maxW then
      lo = mid
    else
      hi = mid - 1
    end
  end
  return lo
end

local function ellipsize(text, maxW)
  if textWidth(text) <= maxW then return text end
  local chars = utf8chars(text)
  local n = fitHead(chars, 1, #chars, maxW - textWidth('...'))
  return table.concat(chars, '', 1, n) .. '...'
end

local fieldUid = 0

local function newField(id, hint, maxLen, title)
  fieldUid = fieldUid + 1
  return {
    id = id, uid = fieldUid, hint = hint, title = title or hint, maxLen = maxLen,
    text = '', caret = 0, scroll = 0, buf = imgui.new.char[maxLen * 3 + 1]()
  }
end

local function setFieldText(f, text)
  f.text = text
  f.caret = #utf8chars(text)
  f.scroll = 0
  imgui.StrCopy(f.buf, text)
end

local Keyboard = { visible = false, field = nil, symbols = false, shift = 0, shiftT = 0, lastEdit = 0 }

local function autoShift()
  if not cfg.auto_caps then return end
  local f = Keyboard.field
  if not f or f.mask or Keyboard.symbols or Keyboard.shift ~= 0 then return end
  if f.text:sub(1, 1) == '/' then return end
  local before = table.concat(utf8chars(f.text), '', 1, f.caret)
  if before == '' or before:match('[%.!?]%s+$') then
    Keyboard.shift = 1
  end
end

function Keyboard.open(f)
  Keyboard.field = f
  Keyboard.visible = true
  f.caret = #utf8chars(f.text)
  Keyboard.lastEdit = os.clock()
  autoShift()
end

function Keyboard.close()
  Keyboard.visible = false
  Keyboard.field = nil
  Keyboard.shift = 0
end

local function kbHeight()
  local keyH = kb.keyHeight
  return MDS * 16 + (keyH * 0.85 + keyH * 5) * MDS + 5 * kb.spacing * MDS
end

local function kbReserved()
  if Keyboard.visible and kb.enabled then
    return kbHeight() + 14 * MDS
  end
  return 0
end

local function kbInsert(text)
  local f = Keyboard.field
  if not f then return end
  local chars = utf8chars(f.text)
  local add = utf8chars(text)
  local room = f.maxLen - #chars
  if room <= 0 then return end
  while #add > room do
    table.remove(add)
  end
  local c = clamp(f.caret, 0, #chars)
  for i = #add, 1, -1 do
    table.insert(chars, c + 1, add[i])
  end
  f.text = table.concat(chars)
  f.caret = c + #add
  imgui.StrCopy(f.buf, f.text)
  Keyboard.lastEdit = os.clock()
end

local function kbBackspace()
  local f = Keyboard.field
  if not f then return end
  local chars = utf8chars(f.text)
  local c = clamp(f.caret, 0, #chars)
  if c > 0 then
    table.remove(chars, c)
    f.text = table.concat(chars)
    f.caret = c - 1
    imgui.StrCopy(f.buf, f.text)
  end
  Keyboard.lastEdit = os.clock()
  autoShift()
end

local function kbMove(delta)
  local f = Keyboard.field
  if not f then return end
  f.caret = clamp(f.caret + delta, 0, #utf8chars(f.text))
  Keyboard.lastEdit = os.clock()
end

local function kbClear()
  local f = Keyboard.field
  if f then
    setFieldText(f, '')
    Keyboard.lastEdit = os.clock()
    autoShift()
  end
end

local function kbPaste()
  local ok, text = pcall(getClipboardText)
  if ok and type(text) == 'string' and text ~= '' then
    kbInsert((text:gsub('[\r\n\t]+', ' ')))
  end
end

local function kbEnter()
  local f = Keyboard.field
  if not f then return end
  if f.onEnter then
    f.onEnter()
  elseif f.next then
    Keyboard.open(f.next)
  else
    Keyboard.close()
  end
end

local function charRow(lower, upper)
  local ups = {}
  for c in upper:gmatch('%S+') do
    ups[#ups + 1] = c
  end
  local row = {}
  for c in lower:gmatch('%S+') do
    row[#row + 1] = { kind = 'char', w = 1, lower = c, upper = ups[#row + 1] or c }
  end
  return row
end

local function special(kind, w)
  return { kind = kind, w = w }
end

local LAYOUTS = {
  EN = {
    charRow('q w e r t y u i o p', 'Q W E R T Y U I O P'),
    charRow('a s d f g h j k l', 'A S D F G H J K L'),
    charRow('z x c v b n m', 'Z X C V B N M')
  },
  RU = {
    charRow('й ц у к е н г ш щ з х ъ', 'Й Ц У К Е Н Г Ш Щ З Х Ъ'),
    charRow('ф ы в а п р о л д ж э', 'Ф Ы В А П Р О Л Д Ж Э'),
    charRow('я ч с м и т ь б ю', 'Я Ч С М И Т Ь Б Ю')
  }
}

local ALT_KEYS = {
  ['е'] = 'ё', ['Е'] = 'Ё', ['.'] = '?', [','] = '!', ['/'] = '\\',
  ['-'] = '_', ['('] = '[', [')'] = ']'
}

local function buildRows()
  local rows = { { fill = true, keys = charRow('1 2 3 4 5 6 7 8 9 0', '1 2 3 4 5 6 7 8 9 0') } }
  if Keyboard.symbols then
    rows[2] = { keys = charRow('@ # $ % & * - + = /', '@ # $ % & * - + = /') }
    rows[3] = { keys = charRow('( ) [ ] { } < > ! ?', '( ) [ ] { } < > ! ?') }
    local r4 = charRow([[_ : ; " ' , . ~ |]], [[_ : ; " ' , . ~ |]])
    r4[#r4 + 1] = special('bksp', 1.5)
    rows[4] = { keys = r4 }
    rows[5] = { fill = true, keys = { special('sym', 1.6), special('lang', 1.3), special('space', 5), special('enter', 1.8) } }
  else
    local lay = LAYOUTS[kb.lang] or LAYOUTS.EN
    rows[2] = { keys = lay[1] }
    rows[3] = { keys = lay[2] }
    local r4 = { special('shift', 1.5) }
    for _, k in ipairs(lay[3]) do
      r4[#r4 + 1] = k
    end
    r4[#r4 + 1] = special('bksp', 1.5)
    rows[4] = { keys = r4 }
    rows[5] = {
      fill = true,
      keys = {
        special('sym', 1.6), special('lang', 1.3),
        { kind = 'char', w = 1, lower = '/', upper = '/' },
        { kind = 'char', w = 1, lower = ',', upper = ',' },
        special('space', 3.5),
        { kind = 'char', w = 1, lower = '.', upper = '.' },
        special('enter', 1.8)
      }
    }
  end
  for _, row in ipairs(rows) do
    local sum = 0
    for _, k in ipairs(row.keys) do
      sum = sum + k.w
    end
    row.sum = sum
  end
  return rows
end


local P = {}

local function mixTbl(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

local function C(t, a)
  return imgui.ImVec4(t[1], t[2], t[3], a or 1)
end

local function computePalette()
  local bg = { hexToRgb(ui.themeColor) }
  local text = { hexToRgb(contrastText(ui.themeColor)) }
  P.bg = bg
  P.text = text
  P.accent = { hexToRgb(ui.accent) }
  P.onAccent = { hexToRgb(contrastText(ui.accent)) }
  P.card = mixTbl(bg, text, 0.05)
  P.frame = mixTbl(bg, text, 0.09)
  P.frameHover = mixTbl(bg, text, 0.14)
  P.btn = mixTbl(bg, text, 0.11)
  P.btnHover = mixTbl(bg, text, 0.19)
  P.line = mixTbl(bg, text, 0.13)
  P.muted = mixTbl(bg, text, 0.55)
end
computePalette()

local function applyStyle()
  computePalette()
  local s = MDS
  local r = ui.uiRound
  local style = imgui.GetStyle()
  local cols = style.Colors
  local Col = imgui.Col
  local clear = imgui.ImVec4(0, 0, 0, 0)

  cols[Col.Text] = C(P.text)
  cols[Col.TextDisabled] = C(P.muted)
  cols[Col.WindowBg] = C(P.bg, ui.themeAlpha)
  cols[Col.ChildBg] = C(P.card)
  cols[Col.PopupBg] = C(P.bg, math.max(ui.themeAlpha, 0.92))
  cols[Col.Border] = C(P.line)
  cols[Col.FrameBg] = C(P.frame)
  cols[Col.FrameBgHovered] = C(P.frameHover)
  cols[Col.FrameBgActive] = C(P.frameHover)
  cols[Col.TitleBg] = C(P.card)
  cols[Col.TitleBgActive] = C(P.card)
  cols[Col.TitleBgCollapsed] = C(P.card)
  cols[Col.ScrollbarBg] = clear
  cols[Col.ScrollbarGrab] = C(P.line)
  cols[Col.ScrollbarGrabHovered] = C(P.btnHover)
  cols[Col.ScrollbarGrabActive] = C(P.accent)
  cols[Col.CheckMark] = C(P.accent)
  cols[Col.SliderGrab] = C(P.accent)
  cols[Col.SliderGrabActive] = C(mixTbl(P.accent, P.text, 0.25))
  cols[Col.Button] = C(P.btn)
  cols[Col.ButtonHovered] = C(P.btnHover)
  cols[Col.ButtonActive] = C(P.accent)
  cols[Col.Header] = C(P.btn)
  cols[Col.HeaderHovered] = C(P.btnHover)
  cols[Col.HeaderActive] = C(P.accent, 0.85)
  cols[Col.Separator] = C(P.line)
  cols[Col.Tab] = C(P.card)
  cols[Col.TabHovered] = C(P.accent, 0.6)
  cols[Col.TabActive] = C(P.accent, 0.85)
  cols[Col.TabUnfocused] = C(P.card)
  cols[Col.TabUnfocusedActive] = C(P.accent, 0.6)
  cols[Col.PlotHistogram] = C(P.accent)

  style.WindowPadding = imgui.ImVec2(14 * s, 12 * s)
  style.WindowRounding = r * 1.3 * s
  style.WindowBorderSize = 0
  style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
  style.ChildRounding = r * s
  style.ChildBorderSize = 0
  style.PopupRounding = r * s
  style.PopupBorderSize = 0
  style.FramePadding = imgui.ImVec2(12 * s, 8 * s)
  style.FrameRounding = r * 0.8 * s
  style.FrameBorderSize = 0
  style.ItemSpacing = imgui.ImVec2(10 * s, 10 * s)
  style.ItemInnerSpacing = imgui.ImVec2(8 * s, 6 * s)
  style.ScrollbarSize = 12 * s
  style.ScrollbarRounding = r * s
  style.GrabMinSize = 18 * s
  style.GrabRounding = r * s
  style.TabRounding = r * 0.8 * s
end

local function sectionLabel(text)
  imgui.PushStyleColor(imgui.Col.Text, C(P.muted))
  imgui.Text(esc(text))
  imgui.PopStyleColor(1)
end

local function coloredButton(label, size, base, hover, active, text)
  imgui.PushStyleColor(imgui.Col.Button, base)
  imgui.PushStyleColor(imgui.Col.ButtonHovered, hover)
  imgui.PushStyleColor(imgui.Col.ButtonActive, active)
  imgui.PushStyleColor(imgui.Col.Text, text)
  local pressed = imgui.Button(label, size)
  imgui.PopStyleColor(4)
  return pressed
end

local function primaryButton(label, size)
  return coloredButton(label, size or imgui.ImVec2(0, 0), C(P.accent), C(mixTbl(P.accent, P.text, 0.15)), C(mixTbl(P.accent, P.bg, 0.3)), C(P.onAccent))
end

local function ghostButton(label, size, danger)
  local active = danger and imgui.ImVec4(0.86, 0.25, 0.27, 1) or C(P.accent)
  local text = danger and imgui.ImVec4(0.96, 0.45, 0.46, 1) or C(P.text)
  return coloredButton(label, size, C(P.btn, 0), C(P.btnHover), active, text)
end

local function chipButton(label, size, on)
  if on then
    return coloredButton(label, size, C(P.accent), C(mixTbl(P.accent, P.text, 0.15)), C(mixTbl(P.accent, P.bg, 0.3)), C(P.onAccent))
  end
  return coloredButton(label, size, C(P.btn), C(P.btnHover), C(P.accent), C(P.text))
end

local function wrapStart()
  return { used = 0, first = true, availW = imgui.GetContentRegionAvail().x, sp = imgui.GetStyle().ItemSpacing.x }
end

local function wrapPlace(w, state)
  if not state.first and state.used + state.sp + w <= state.availW then
    imgui.SameLine(0, state.sp)
    state.used = state.used + state.sp + w
  else
    state.used = w
  end
  state.first = false
end

local function stepSlider(title, id, ptr, minV, maxV, step, fmt, onChange)
  local s = MDS
  sectionLabel(title)
  local sp = imgui.GetStyle().ItemSpacing.x
  local bs = 42 * s
  local avail = imgui.GetContentRegionAvail().x

  local function apply(v)
    v = clamp(v, minV, maxV)
    ptr[0] = v
    onChange(v)
  end

  if ghostButton(ICON_MINUS .. '##m_' .. id, imgui.ImVec2(bs, bs), false) then
    apply(ptr[0] - step)
  end
  imgui.SameLine(0, sp)
  imgui.SetNextItemWidth(avail - bs * 2 - sp * 2)
  if imgui.SliderFloat('##' .. id, ptr, minV, maxV, fmt or '%.2f') then
    onChange(ptr[0])
  end
  imgui.SameLine(0, sp)
  if ghostButton(ICON_PLUS .. '##p_' .. id, imgui.ImVec2(bs, bs), false) then
    apply(ptr[0] + step)
  end
end

local function sliderRow(title, id, ptr, minV, maxV, isFloat, onChange)
  sectionLabel(title)
  imgui.SetNextItemWidth(imgui.GetContentRegionAvail().x)
  local changed
  if isFloat then
    changed = imgui.SliderFloat('##' .. id, ptr, minV, maxV, '%.2f')
  else
    changed = imgui.SliderInt('##' .. id, ptr, minV, maxV, '%d')
  end
  if changed then onChange(ptr[0]) end
end

local function toggleRow(title, key, hint)
  local avail = imgui.GetContentRegionAvail().x
  local label = (cfg[key] and (ICON_CHECK .. '  ') or '') .. title
  if chipButton(label .. '##tg_' .. key, imgui.ImVec2(avail, 46 * MDS), cfg[key]) then
    cfg[key] = not cfg[key]
    markDirty()
  end
  if hint then sectionLabel(hint) end
end


local fields = {
  chat = newField('chat', 'Сообщение или команда', 144, 'Чат'),
  dialog = newField('dialog', 'Введите текст', 128, 'Диалог'),
  phrase = newField('phrase', 'Новая быстрая фраза', 100, 'Быстрая фраза'),
  test = newField('test', 'Нажмите, чтобы проверить клавиатуру', 64, 'Проверка')
}

local chat = { open = false, histPos = 1, draft = '' }
local dlg = nil
local dlgWin = imgui.new.bool(false)
local settingsWin = imgui.new.bool(false)
local revealPassword = false

local function pushHistory(text)
  if history[#history] == text then return end
  for i = #history, 1, -1 do
    if history[i] == text then table.remove(history, i) end
  end
  history[#history + 1] = text
  while #history > cfg.hist_max do
    table.remove(history, 1)
  end
  markDirty()
end

local function histNav(delta)
  if #history == 0 then return end
  if chat.histPos > #history then chat.draft = fields.chat.text end
  chat.histPos = clamp(chat.histPos + delta, 1, #history + 1)
  if chat.histPos > #history then
    setFieldText(fields.chat, chat.draft)
  else
    setFieldText(fields.chat, history[chat.histPos])
  end
end

local function closeChat()
  chat.open = false
  if Keyboard.field == fields.chat then Keyboard.close() end
end

local function chatSend()
  local text = trim(fields.chat.text)
  if text == '' then
    if cfg.close_after_send then closeChat() end
    return
  end
  local raw = toCp1251(text)
  if #raw > 144 then raw = raw:sub(1, 144) end
  pcall(sampProcessChatInput, raw)
  pushHistory(text)
  setFieldText(fields.chat, '')
  chat.histPos = #history + 1
  chat.draft = ''
  if cfg.close_after_send then closeChat() end
end

local function openChat()
  if not kb.enabled then return end
  chat.open = true
  chat.histPos = #history + 1
  local f = fields.chat
  f.onEnter = chatSend
  f.title = 'Чат'
  f.enterLabel = 'Отправить'
  f.enterIcon = ICON_SEND
  Keyboard.open(f)
end

local function toggleChat()
  if chat.open then closeChat() else openChat() end
end

local function splitLines(text)
  local lines = {}
  text = text:gsub('\r', ''):gsub('\t', '    ')
  for line in (text .. '\n'):gmatch('([^\n]*)\n') do
    lines[#lines + 1] = line
  end
  while #lines > 0 and lines[#lines] == '' do
    table.remove(lines)
  end
  return lines
end

local function closeDialog()
  dlg = nil
  dlgWin[0] = false
  revealPassword = false
  if Keyboard.field == fields.dialog then Keyboard.close() end
end

local function dialogRespond(button)
  local d = dlg
  if not d then return end
  local raw = toCp1251(fields.dialog.text)
  if #raw > 255 then raw = raw:sub(1, 255) end
  if d.test then
    sampAddChatMessage('{20b2aa}[GameKeyboard] {FFFFFF}test dialog, button ' .. button .. ', text: ' .. raw, -1)
  else
    pcall(sampSendDialogResponse, d.id, button, -1, raw)
  end
  closeDialog()
end

local function openDialog(id, style, title, b1, b2, text, test)
  dlg = {
    id = id,
    style = style,
    test = test or false,
    title = safeLabel(stripColors(title)),
    b1 = stripColors(b1),
    b2 = stripColors(b2),
    lines = splitLines(text)
  }
  local f = fields.dialog
  f.mask = style == 3
  f.title = dlg.title
  f.hint = style == 3 and 'Введите пароль' or 'Введите текст'
  f.enterLabel = dlg.b1 ~= '' and dlg.b1 or 'OK'
  f.enterIcon = ICON_CHECK
  f.onEnter = function() dialogRespond(1) end
  revealPassword = false
  setFieldText(f, '')
  dlgWin[0] = true
  Keyboard.open(f)
end

local function addPhrase(text)
  text = trim(text)
  if text == '' or #phrases >= 24 then return end
  for _, p in ipairs(phrases) do
    if p == text then return end
  end
  phrases[#phrases + 1] = text
  markDirty()
end

local function removePhrase(index)
  table.remove(phrases, index)
  markDirty()
end


local KC = {}

local function U32t(t, a)
  return imgui.U32(t[1], t[2], t[3], a or 1)
end

local function computeKbPalette()
  KC.bg = { hexToRgb(kb.bg) }
  KC.key = { hexToRgb(kb.key) }
  KC.special = { hexToRgb(kb.special) }
  KC.accent = { hexToRgb(kb.accent) }
  KC.text = { hexToRgb(kb.text) }
  KC.onAccent = { hexToRgb(contrastText(kb.accent)) }
  KC.frame = mixTbl(KC.bg, KC.text, 0.12)
  KC.muted = mixTbl(KC.bg, KC.text, 0.55)
end
computeKbPalette()

local function charIndexAt(src, relX)
  local chars = utf8chars(src)
  local best, bestDist = 0, math.huge
  local acc = ''
  for i = 0, #chars do
    if i > 0 then acc = acc .. chars[i] end
    local d = math.abs(measure(acc) - relX)
    if d < bestDist then
      best, bestDist = i, d
    elseif d > bestDist + 40 then
      break
    end
  end
  return best
end

local function drawField(f, width, height, onKb)
  local s = MDS
  local avail = width or imgui.GetContentRegionAvail().x
  local h = height or 42 * s

  if not kb.enabled then
    imgui.SetNextItemWidth(avail)
    if imgui.InputTextWithHint('##fld_' .. f.id, f.hint, f.buf, ffi.sizeof(f.buf)) then
      f.text = ffi.string(f.buf)
      f.caret = #utf8chars(f.text)
    end
    return
  end

  local active = Keyboard.visible and Keyboard.field == f
  local frame, accent, textc, muted, rounding
  if onKb then
    frame, accent, textc, muted = KC.frame, KC.accent, KC.text, KC.muted
    rounding = kb.rounding * s
  else
    frame, accent, textc, muted = P.frame, P.accent, P.text, P.muted
    rounding = ui.uiRound * 0.8 * s
  end

  local p = imgui.GetCursorScreenPos()
  imgui.PushIDInt(f.uid)
  imgui.InvisibleButton('##field', V2(avail, h))
  imgui.PopID()
  local pressed = imgui.IsItemActivated()

  local pad = 12 * s
  local innerW = avail - pad * 2
  local src = f.text
  if f.mask and not revealPassword then
    src = string.rep('*', #utf8chars(f.text))
  end

  if pressed then
    Keyboard.open(f)
    active = true
    if src ~= '' then
      local mx = imgui.GetIO().MousePos.x
      f.caret = charIndexAt(src, mx - (p.x + pad) + f.scroll)
    end
  end

  local chars = utf8chars(src)
  local caret = clamp(f.caret, 0, #chars)
  local caretX = measure(table.concat(chars, '', 1, caret))
  local totalW = measure(src)

  if active then
    if caretX - f.scroll > innerW - 4 * s then f.scroll = caretX - innerW + 4 * s end
    if caretX - f.scroll < 0 then f.scroll = caretX end
    f.scroll = clamp(f.scroll, 0, math.max(0, totalW - innerW + 8 * s))
  else
    f.scroll = 0
  end

  local dl = imgui.GetWindowDrawList()
  local a, b = V2(p.x, p.y), V2(p.x + avail, p.y + h)
  local fill = active and mixTbl(frame, accent, 0.18) or frame
  dl:AddRectFilled(a, b, U32t(fill), rounding)
  if active then
    dl:AddRect(a, b, U32t(accent), rounding, nil, 1.6 * s)
  end

  local ty = p.y + (h - imgui.GetTextLineHeight()) / 2
  dl:PushClipRect(V2(p.x + pad, p.y), V2(p.x + avail - pad, p.y + h), true)
  if src == '' then
    dl:AddText(V2(p.x + pad, ty), U32t(muted), f.hint)
  else
    dl:AddText(V2(p.x + pad - f.scroll, ty), U32t(textc), src)
  end
  if active then
    local now = os.clock()
    if now - Keyboard.lastEdit < 0.7 or math.floor(now * 1.8) % 2 == 0 then
      local cx = p.x + pad + caretX - f.scroll
      dl:AddLine(V2(cx, p.y + h * 0.2), V2(cx, p.y + h * 0.8), U32t(accent), 2 * s)
    end
  end
  dl:PopClipRect()
end

local function keyBtn(uid, label, w, h, kind, o)
  o = o or {}
  local s = MDS
  local face = KC.key
  local textCol = KC.text
  if kind == 'special' then
    face = KC.special
  elseif kind == 'accent' or kind == 'on' then
    face = KC.accent
    textCol = KC.onAccent
  end

  imgui.PushIDInt(uid)
  local p = imgui.GetCursorScreenPos()
  imgui.InvisibleButton('##k', V2(w, h))
  imgui.PopID()
  local activated = imgui.IsItemActivated()
  local active = imgui.IsItemActive()
  local released = imgui.IsItemDeactivated()

  local dl = imgui.GetWindowDrawList()
  local depth = math.max(2 * s, h * 0.07)
  local r = kb.rounding * s
  local y0 = p.y + (active and depth * 0.8 or 0)
  local fill = active and mixTbl(face, KC.accent, 0.4) or face
  dl:AddRectFilled(V2(p.x, p.y + depth), V2(p.x + w, p.y + h), U32t(mixTbl(face, { 0, 0, 0 }, 0.5), kb.keyAlpha), r)
  dl:AddRectFilled(V2(p.x, y0), V2(p.x + w, y0 + h - depth), U32t(fill, kb.keyAlpha), r)

  local font = imgui.GetFont()
  local k = o.scale or 1
  local fs = imgui.GetFontSize() * k
  local ts = imgui.CalcTextSize(label)
  dl:AddTextFontPtr(font, fs, V2(p.x + (w - ts.x * k) / 2, y0 + (h - depth - ts.y * k) / 2), U32t(textCol), label)

  if o.hint then
    local hk = 0.62
    local hw = imgui.CalcTextSize(o.hint).x * hk
    dl:AddTextFontPtr(font, imgui.GetFontSize() * hk, V2(p.x + w - hw - 5 * s, y0 + 3 * s), U32t(textCol, 0.45), o.hint)
  end

  return activated, active, released, p
end

local repeatId, repeatStart, repeatLast = nil, 0, 0

local function holdRepeat(id, activated, active, action)
  local now = imgui.GetTime()
  if activated then
    action()
    repeatId, repeatStart, repeatLast = id, now, now
  elseif active and repeatId == id then
    if now - repeatStart > 0.4 and now - repeatLast > 0.05 then
      repeatLast = now
      action()
    end
  elseif repeatId == id then
    repeatId = nil
  end
end

local KB_COLORS = {
  { key = 'bg', title = 'Фон клавиатуры' },
  { key = 'key', title = 'Клавиши' },
  { key = 'special', title = 'Служебные клавиши' },
  { key = 'accent', title = 'Акцент' },
  { key = 'text', title = 'Текст' }
}

local kbColorPtrs = {}
for _, spec in ipairs(KB_COLORS) do
  kbColorPtrs[spec.key] = imgui.new.float[3]()
end

local function syncKbPtrs()
  for key, ptr in pairs(kbColorPtrs) do
    local r, g, b = hexToRgb(kb[key])
    ptr[0], ptr[1], ptr[2] = r, g, b
  end
end
syncKbPtrs()

local KB_SLIDERS = {
  { key = 'alpha', title = 'Прозрачность клавиатуры', min = 0.3, max = 1.0, float = true },
  { key = 'keyAlpha', title = 'Прозрачность клавиш', min = 0.3, max = 1.0, float = true },
  { key = 'fontScale', title = 'Размер текста', min = 0.8, max = 1.8, float = true },
  { key = 'keyHeight', title = 'Высота клавиш', min = 32, max = 72 },
  { key = 'spacing', title = 'Расстояние между клавишами', min = 2, max = 14 },
  { key = 'rounding', title = 'Скругление', min = 0, max = 24 },
  { key = 'width', title = 'Ширина клавиатуры (проценты экрана)', min = 40, max = 100 }
}

for _, spec in ipairs(KB_SLIDERS) do
  if spec.float then
    spec.ptr = imgui.new.float(kb[spec.key])
  else
    spec.ptr = imgui.new.int(kb[spec.key])
  end
end

local histPtr = imgui.new.float(cfg.hist_max)
local capPtrs = {}
for _, k in ipairs({ 'cap_x', 'cap_y', 'cap_w', 'cap_h' }) do
  capPtrs[k] = imgui.new.int(cfg[k])
end
local capPreviewUntil = 0
local themeColorPtr = imgui.new.float[3]()
local accentPtr = imgui.new.float[3]()
local themeAlphaPtr = imgui.new.float(ui.themeAlpha)
local uiRoundPtr = imgui.new.int(ui.uiRound)
local btnSizePtr = imgui.new.int(ui.btnSize)
local btnShapePtr = imgui.new.int(ui.btnShape)
local glyphRanges

local function syncAppearancePtrs()
  local r, g, b = hexToRgb(ui.themeColor)
  themeColorPtr[0], themeColorPtr[1], themeColorPtr[2] = r, g, b
  local ar, ag, ab = hexToRgb(ui.accent)
  accentPtr[0], accentPtr[1], accentPtr[2] = ar, ag, ab
  themeAlphaPtr[0] = ui.themeAlpha
  uiRoundPtr[0] = ui.uiRound
  btnSizePtr[0] = ui.btnSize
  btnShapePtr[0] = ui.btnShape
end
syncAppearancePtrs()

local UI_PRESETS = {
  { name = 'Ночь', bg = '#14161B', accent = '#3B82F6' },
  { name = 'AMOLED', bg = '#000000', accent = '#00C2A8' },
  { name = 'Светлая', bg = '#F1F3F8', accent = '#2F7BFF' },
  { name = 'Океан', bg = '#0B1C2B', accent = '#2DD4BF' },
  { name = 'Сакура', bg = '#221019', accent = '#FF6FA5' },
  { name = 'Мята', bg = '#0C1B16', accent = '#4ADE80' },
  { name = 'Аметист', bg = '#171126', accent = '#A78BFA' }
}

local function applyKbTheme(theme)
  kb.bg, kb.key, kb.special, kb.accent, kb.text = theme.bg, theme.key, theme.special, theme.accent, theme.text
  kb.theme = theme.name
  syncKbPtrs()
  markDirty()
end

local function applyPreset(p)
  ui.themeColor = p.bg
  ui.accent = p.accent
  ui.uiPreset = p.name
  for _, th in ipairs(KB_THEMES) do
    if th.name == p.name then applyKbTheme(th) end
  end
  syncAppearancePtrs()
  applyStyle()
  markDirty()
end

local function resetAppearance()
  ui.themeAlpha = 0.96
  ui.uiRound = 12
  ui.btnSize = 44
  ui.btnShape = 100
  applyPreset(UI_PRESETS[1])
end

local DRAG_THRESHOLD = 8
local drag = {}
local FLOAT_FLAGS = imgui.WindowFlags.NoTitleBar
  + imgui.WindowFlags.NoResize
  + imgui.WindowFlags.NoScrollbar
  + imgui.WindowFlags.NoScrollWithMouse
  + imgui.WindowFlags.NoBackground
  + imgui.WindowFlags.NoSavedSettings
  + imgui.WindowFlags.AlwaysAutoResize
  + imgui.WindowFlags.NoMove

local function drawFloat(id, icon, sizeDp, kx, ky, lit)
  local s = MDS
  local size = sizeDp * s
  local d = drag[id]
  if not d then
    d = { moved = false }
    drag[id] = d
  end

  imgui.SetNextWindowPos(imgui.ImVec2(ui[kx], ui[ky]), imgui.Cond.Always)
  imgui.Begin('##' .. id, nil, FLOAT_FLAGS)
  imgui.SetWindowFontScale(clamp(sizeDp / 36, 1.0, 2.4))

  local ar, ag, ab = P.accent[1], P.accent[2], P.accent[3]
  local fill, hover, act, txt
  if lit then
    fill = imgui.ImVec4(ar, ag, ab, 1)
    hover = imgui.ImVec4(math.min(ar + 0.06, 1), math.min(ag + 0.06, 1), math.min(ab + 0.06, 1), 1)
    act = imgui.ImVec4(ar * 0.8, ag * 0.8, ab * 0.8, 1)
    txt = C(P.onAccent)
  else
    local base = mixTbl(P.bg, P.text, 0.1)
    fill = C(base, 0.92)
    hover = C(mixTbl(base, P.text, 0.1), 0.95)
    act = C(P.accent)
    txt = C(P.accent)
  end

  imgui.PushStyleColor(imgui.Col.Button, fill)
  imgui.PushStyleColor(imgui.Col.ButtonHovered, hover)
  imgui.PushStyleColor(imgui.Col.ButtonActive, act)
  imgui.PushStyleColor(imgui.Col.Text, txt)
  imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(math.min(ar + 0.3, 1), math.min(ag + 0.3, 1), math.min(ab + 0.3, 1), 0.6))
  imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, (size / 2) * (ui.btnShape / 100))
  imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, 2 * s)
  local clicked = imgui.Button(icon, imgui.ImVec2(size, size))
  imgui.PopStyleVar(2)
  imgui.PopStyleColor(5)

  local down = imgui.IsItemActive()
  if ui.btnLocked then
    d.moved = false
    d.mx = nil
  elseif down then
    local mp = imgui.GetIO().MousePos
    if d.mx == nil then
      d.mx, d.my = mp.x, mp.y
      d.bx, d.by = ui[kx], ui[ky]
      d.moved = false
    else
      local dx = mp.x - d.mx
      local dy = mp.y - d.my
      if d.moved or math.abs(dx) > DRAG_THRESHOLD * s or math.abs(dy) > DRAG_THRESHOLD * s then
        d.moved = true
        ui[kx] = d.bx + dx
        ui[ky] = d.by + dy
      end
    end
  elseif d.mx ~= nil then
    if d.moved then markDirty() end
    d.mx = nil
  end

  imgui.End()
  return clicked and not d.moved
end

local function parseColorLine(line)
  local segs = {}
  local pos = 1
  local color = nil
  while true do
    local a, b, hex = line:find('{(%x%x%x%x%x%x)}', pos)
    if not a then
      if pos <= #line then segs[#segs + 1] = { text = line:sub(pos), color = color } end
      break
    end
    if a > pos then segs[#segs + 1] = { text = line:sub(pos, a - 1), color = color } end
    color = hex
    pos = b + 1
  end
  return segs
end

local function drawDialogLine(line)
  if line == '' then
    imgui.Dummy(imgui.ImVec2(1, imgui.GetTextLineHeight() * 0.6))
    return
  end
  local segs = parseColorLine(line)
  if #segs == 0 then return end
  local avail = imgui.GetContentRegionAvail().x
  local total = 0
  for _, sg in ipairs(segs) do
    total = total + textWidth(sg.text)
  end
  if #segs == 1 or total > avail then
    local color = #segs == 1 and segs[1].color or nil
    if color then
      local r, g, b = hexToRgb('#' .. color)
      imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(r, g, b, 1))
    end
    imgui.TextWrapped(esc(stripColors(line)))
    if color then imgui.PopStyleColor(1) end
  else
    for i, sg in ipairs(segs) do
      if i > 1 then imgui.SameLine(0, 0) end
      if sg.color then
        local r, g, b = hexToRgb('#' .. sg.color)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(r, g, b, 1))
      end
      imgui.Text(esc(sg.text))
      if sg.color then imgui.PopStyleColor(1) end
    end
  end
end

local function kbAwareWindow(defW, defH)
  local s = MDS
  local io = imgui.GetIO()
  local sw, sh = io.DisplaySize.x, io.DisplaySize.y
  local reserved = kbReserved()
  if reserved > 0 then
    local w = math.min(defW * s, sw - 16 * s)
    imgui.SetNextWindowPos(imgui.ImVec2((sw - w) / 2, 8 * s), imgui.Cond.Always)
    imgui.SetNextWindowSize(imgui.ImVec2(w, math.max(sh - reserved - 16 * s, 160 * s)), imgui.Cond.Always)
  else
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(defW * s, defH * s), imgui.Cond.FirstUseEver)
  end
end


local function setCapPreview()
  capPreviewUntil = os.clock() + 5
end

local function drawKeyboardTab()
  local s = MDS
  local avail = imgui.GetContentRegionAvail().x

  local masterLabel = (kb.enabled and (ICON_CHECK .. '  ') or '') .. 'Своя клавиатура включена'
  if chipButton(masterLabel .. '##kbmaster', imgui.ImVec2(avail, 50 * s), kb.enabled) then
    kb.enabled = not kb.enabled
    if not kb.enabled then
      chat.open = false
      Keyboard.close()
    end
    markDirty()
  end
  sectionLabel('Если выключить, чат и диалоги вернутся к стандартному вводу игры')

  sectionLabel('Проверка')
  drawField(fields.test)

  imgui.Separator()
  sectionLabel('Удобство ввода')
  toggleRow('Заглавная буква в начале фразы', 'auto_caps')
  toggleRow('Крупная подсказка над нажатой клавишей', 'key_preview')
  toggleRow('Долгое нажатие: ё ? ! и другие символы', 'alt_keys', 'Маленькая подсказка в углу клавиши показывает, что будет при удержании')
  toggleRow('Курсор свайпом по пробелу', 'swipe_space')

  if imgui.CollapsingHeader('Тема и цвета') then
    sectionLabel('Тема клавиатуры')
    local ws = wrapStart()
    for i, th in ipairs(KB_THEMES) do
      local label = (kb.theme == th.name and (ICON_CHECK .. ' ') or '') .. th.name
      local w = textWidth(label) + 30 * s
      wrapPlace(w, ws)
      local kr, kg, kbb = hexToRgb(th.key)
      local xr, xg, xb = hexToRgb(th.text)
      local ar, ag, ab = hexToRgb(th.accent)
      imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(kr, kg, kbb, 1))
      imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(kr, kg, kbb, 0.85))
      imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(ar, ag, ab, 1))
      imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(xr, xg, xb, 1))
      imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(ar, ag, ab, 1))
      imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, 2 * s)
      if imgui.Button(label .. '##th' .. i, imgui.ImVec2(w, 0)) then
        applyKbTheme(th)
        computeKbPalette()
      end
      imgui.PopStyleVar(1)
      imgui.PopStyleColor(5)
    end

    for _, spec in ipairs(KB_COLORS) do
      sectionLabel(spec.title)
      if imgui.ColorEdit3('##kbc_' .. spec.key, kbColorPtrs[spec.key]) then
        local p = kbColorPtrs[spec.key]
        kb[spec.key] = rgbToHex(p[0], p[1], p[2])
        kb.theme = 'Своя'
        computeKbPalette()
        markDirty()
      end
    end
  end

  if imgui.CollapsingHeader('Размеры и вид') then
    for _, spec in ipairs(KB_SLIDERS) do
      sliderRow(spec.title, 'kbs_' .. spec.key, spec.ptr, spec.min, spec.max, spec.float, function(v)
        kb[spec.key] = v
        markDirty()
      end)
    end
  end
end

local function drawChatTab()
  local s = MDS
  local avail = imgui.GetContentRegionAvail().x

  sectionLabel('Нажатие на чат SAMP')
  toggleRow('Открывать мою клавиатуру при нажатии на чат', 'cap_enabled', 'Касание в выбранной области не доходит до игры, поэтому системная клавиатура не появляется')

  if imgui.CollapsingHeader('Область нажатия на чат') then
    sectionLabel('Подгоните прямоугольник под чат. Он подсвечивается, пока вы двигаете ползунки')
    for _, spec in ipairs({
      { 'cap_x', 'Левый край (проценты экрана)' },
      { 'cap_y', 'Верхний край (проценты экрана)' },
      { 'cap_w', 'Ширина (проценты экрана)' },
      { 'cap_h', 'Высота (проценты экрана)' }
    }) do
      local key = spec[1]
      sliderRow(spec[2], 'cap_' .. key, capPtrs[key], G_LIMITS[key][1], G_LIMITS[key][2], false, function(v)
        cfg[key] = v
        setCapPreview()
        markDirty()
      end)
    end
    if ghostButton(ICON_TARGET .. '  Показать область##capshow', imgui.ImVec2(avail, 0), false) then
      setCapPreview()
    end
  end

  imgui.Separator()
  toggleRow('Закрывать чат после отправки', 'close_after_send')
  toggleRow('Быстрые фразы над полем ввода', 'show_phrases')

  stepSlider('Размер истории (сообщений)', 'hist', histPtr, 5, 100, 5, '%.0f', function(v)
    cfg.hist_max = math.floor(v)
    while #history > cfg.hist_max do
      table.remove(history, 1)
    end
    markDirty()
  end)

  if ghostButton(ICON_TRASH .. '  Очистить историю (' .. #history .. ')##clearhist', imgui.ImVec2(avail, 0), true) then
    history = {}
    chat.histPos = 1
    markDirty()
  end

  imgui.Separator()
  sectionLabel(('Быстрые фразы: %d из 24'):format(#phrases))

  for i, p in ipairs(phrases) do
    local x0 = imgui.GetCursorPosX()
    local w = imgui.GetContentRegionAvail().x
    imgui.AlignTextToFramePadding()
    imgui.Text(esc(ellipsize(p, w - 56 * s)))
    imgui.SameLine(x0 + w - 44 * s)
    if ghostButton(ICON_TRASH .. '##ph' .. i, imgui.ImVec2(44 * s, 0), true) then
      removePhrase(i)
      break
    end
  end

  drawField(fields.phrase)
  if primaryButton(ICON_PLUS .. '  Добавить фразу', imgui.ImVec2(avail, 46 * s)) then
    addPhrase(fields.phrase.text)
    setFieldText(fields.phrase, '')
  end
end

local function drawDialogsTab()
  local s = MDS
  local avail = imgui.GetContentRegionAvail().x

  toggleRow('Перехватывать диалоги с вводом текста', 'catch_input', 'Окна ввода и пароля заменяются на ваши, с этой клавиатурой')
  sectionLabel('Диалоги со списками и сообщениями остаются стандартными')

  imgui.Separator()
  sectionLabel('Проверка без сервера')
  if chipButton('Тест диалога ввода##testdlg1', imgui.ImVec2(avail, 46 * s), false) then
    openDialog(0, 1, 'Проверка ввода', 'Готово', 'Отмена', 'Это тестовый диалог.\n{FFD54A}Цветной текст{FFFFFF} и обычный.\nВведите что-нибудь ниже.', true)
  end
  if chipButton('Тест диалога пароля##testdlg3', imgui.ImVec2(avail, 46 * s), false) then
    openDialog(0, 3, 'Проверка пароля', 'Войти', 'Отмена', 'Введите пароль.\n{FF6B6B}Символы скрыты звёздочками.', true)
  end
end

local function drawStyleTab()
  local s = MDS
  local avail = imgui.GetContentRegionAvail().x

  sectionLabel('Готовые темы (меню и клавиатура)')
  local ws = wrapStart()
  for i, p in ipairs(UI_PRESETS) do
    local label = (ui.uiPreset == p.name and (ICON_CHECK .. ' ') or '') .. p.name
    local w = textWidth(label) + 30 * s
    wrapPlace(w, ws)
    local br, bg, bb = hexToRgb(p.bg)
    local ar, ag, ab = hexToRgb(p.accent)
    local tr, tg, tb = hexToRgb(contrastText(p.bg))
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(br, bg, bb, 1))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(math.min(br + 0.05, 1), math.min(bg + 0.05, 1), math.min(bb + 0.05, 1), 1))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(ar, ag, ab, 1))
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(tr, tg, tb, 1))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(ar, ag, ab, 1))
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, 2 * s)
    if imgui.Button(label .. '##ps' .. i, imgui.ImVec2(w, 0)) then
      applyPreset(p)
      computeKbPalette()
    end
    imgui.PopStyleVar(1)
    imgui.PopStyleColor(5)
  end

  sectionLabel('Акцентный цвет')
  if imgui.ColorEdit3('##accent', accentPtr) then
    ui.accent = rgbToHex(accentPtr[0], accentPtr[1], accentPtr[2])
    ui.uiPreset = 'Своя'
    applyStyle()
    markDirty()
  end

  sectionLabel('Цвет фона')
  if imgui.ColorEdit3('##bgcolor', themeColorPtr) then
    ui.themeColor = rgbToHex(themeColorPtr[0], themeColorPtr[1], themeColorPtr[2])
    ui.uiPreset = 'Своя'
    applyStyle()
    markDirty()
  end

  sliderRow('Прозрачность окон', 'alpha', themeAlphaPtr, 0.3, 1.0, true, function(v)
    ui.themeAlpha = v
    applyStyle()
    markDirty()
  end)

  sliderRow('Скругление интерфейса', 'round', uiRoundPtr, 0, 24, false, function(v)
    ui.uiRound = v
    applyStyle()
    markDirty()
  end)

  imgui.Separator()
  sectionLabel('Плавающая кнопка чата')

  local showLabel = (ui.showButton and ICON_EYE or ICON_EYE_OFF) .. (ui.showButton and '  Кнопка показана' or '  Кнопка скрыта (чат: /gkchat)')
  if chipButton(showLabel .. '##showbtn', imgui.ImVec2(avail, 46 * s), ui.showButton) then
    ui.showButton = not ui.showButton
    markDirty()
  end

  local lockLabel = (ui.btnLocked and ICON_LOCK or ICON_UNLOCK) .. (ui.btnLocked and '  Позиция закреплена' or '  Позицию можно менять')
  if chipButton(lockLabel .. '##lockbtn', imgui.ImVec2(avail, 46 * s), ui.btnLocked) then
    ui.btnLocked = not ui.btnLocked
    markDirty()
  end

  sliderRow('Размер кнопки', 'btnsize', btnSizePtr, 32, 80, false, function(v)
    ui.btnSize = v
    markDirty()
  end)

  sliderRow('Форма кнопки (0 - квадрат, 100 - круг)', 'btnshape', btnShapePtr, 0, 100, false, function(v)
    ui.btnShape = v
    markDirty()
  end)

  imgui.Separator()
  if ghostButton(ICON_RESET .. '  Сбросить оформление##resetui', imgui.ImVec2(avail, 0), true) then
    resetAppearance()
    computeKbPalette()
  end
end


imgui.OnInitialize(function()
  imgui.GetIO().IniFilename = nil

  local fontConfig = imgui.ImFontConfig()
  fontConfig.MergeMode = true
  fontConfig.PixelSnapH = true

  local builder = imgui.ImFontGlyphRangesBuilder()
  for _, name in ipairs(ICON_NAMES) do
    builder:AddText(faicons(name))
  end

  glyphRanges = imgui.ImVector_ImWchar()
  builder:BuildRanges(glyphRanges)
  imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 14 * MDS, fontConfig, glyphRanges[0].Data)

  imgui.GetStyle():ScaleAllSizes(MDS)
  applyStyle()
end)

local pendingOpenChat = false

imgui.OnFrame(
  function()
    if pendingOpenChat then
      pendingOpenChat = false
      if not chat.open then openChat() end
    end
    return false
  end,
  function() end
)

imgui.OnFrame(
  function() return kb.enabled and ui.showButton end,
  function()
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(3 * MDS, 3 * MDS))
    if drawFloat('GKChatBtn', ICON_COMMENT, ui.btnSize, 'btnX', 'btnY', chat.open) then
      toggleChat()
    end
    imgui.PopStyleVar(1)
  end
)

imgui.OnFrame(
  function() return chat.open and kb.enabled end,
  function()
    computeKbPalette()
    local s = MDS
    local io = imgui.GetIO()
    local sw, sh = io.DisplaySize.x, io.DisplaySize.y
    local width = clamp(sw * kb.width / 100, math.min(320 * s, sw), sw)
    local top = Keyboard.visible and (sh - kbHeight() - 6 * s) or (sh - 6 * s)
    local pad = 8 * s
    local sp = kb.spacing * s
    local bh = math.min(kb.keyHeight, 46) * s

    imgui.SetNextWindowPos(V2(sw / 2, top - 8 * s), imgui.Cond.Always, V2(0.5, 1))
    imgui.SetNextWindowSize(V2(width, 0), imgui.Cond.Always)

    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(KC.bg[1], KC.bg[2], KC.bg[3], kb.alpha))
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(pad, pad))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, V2(sp, sp))
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, (kb.rounding + 4) * s)

    local flags = imgui.WindowFlags.NoTitleBar
      + imgui.WindowFlags.NoResize
      + imgui.WindowFlags.NoMove
      + imgui.WindowFlags.NoScrollbar
      + imgui.WindowFlags.NoScrollWithMouse
      + imgui.WindowFlags.NoCollapse
      + imgui.WindowFlags.NoSavedSettings

    imgui.Begin('##GKChatBar', nil, flags)
    imgui.SetWindowFontScale(kb.fontScale)

    local inner = width - pad * 2

    if cfg.show_phrases and #phrases > 0 then
      local ws = { used = 0, first = true, availW = inner, sp = sp }
      for i, ph in ipairs(phrases) do
        if i > 10 then break end
        local label = ellipsize(ph, 220 * s)
        local w = textWidth(label) + 28 * s
        wrapPlace(w, ws)
        local act = keyBtn(300 + i, label, w, 34 * s, 'special')
        if act then
          if Keyboard.field ~= fields.chat then Keyboard.open(fields.chat) end
          kbInsert(ph)
          autoShift()
        end
      end
    end

    local sendW = 76 * s
    local fieldW = inner - bh * 3 - sendW - sp * 4

    local act = keyBtn(401, ICON_GEAR, bh, bh, 'special')
    if act then settingsWin[0] = true end
    imgui.SameLine(0, sp)
    act = keyBtn(402, ICON_UP, bh, bh, 'special')
    if act then histNav(-1) end
    imgui.SameLine(0, sp)
    act = keyBtn(403, ICON_DOWN, bh, bh, 'special')
    if act then histNav(1) end
    imgui.SameLine(0, sp)
    drawField(fields.chat, fieldW, bh, true)
    imgui.SameLine(0, sp)
    act = keyBtn(404, ICON_SEND, sendW, bh, 'accent')
    if act then chatSend() end

    imgui.End()
    imgui.PopStyleVar(3)
    imgui.PopStyleColor(1)
  end
)

imgui.OnFrame(
  function() return dlgWin[0] and dlg ~= nil end,
  function()
    local d = dlg
    if not d then return end
    local s = MDS
    local io = imgui.GetIO()
    local sw, sh = io.DisplaySize.x, io.DisplaySize.y
    local w = math.min(540 * s, sw - 24 * s)
    local reserved = kbReserved()

    if reserved > 0 then
      imgui.SetNextWindowPos(V2((sw - w) / 2, 8 * s), imgui.Cond.Always)
      imgui.SetNextWindowSize(V2(w, math.max(sh - reserved - 16 * s, 240 * s)), imgui.Cond.Always)
    else
      imgui.SetNextWindowPos(V2(sw / 2, sh * 0.42), imgui.Cond.Always, V2(0.5, 0.5))
      imgui.SetNextWindowSize(V2(w, 0), imgui.Cond.Always)
    end

    imgui.Begin(d.title .. '###gkdialog', nil, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoResize)

    local textH
    if reserved > 0 then
      textH = math.max(imgui.GetContentRegionAvail().y - 150 * s, 60 * s)
    else
      textH = clamp(#d.lines * (imgui.GetTextLineHeight() + 6 * s) + 20 * s, 70 * s, 260 * s)
    end

    imgui.BeginChild('##gkdtext', V2(0, textH), false)
    for _, line in ipairs(d.lines) do
      drawDialogLine(line)
    end
    imgui.EndChild()

    local avail = imgui.GetContentRegionAvail().x
    local sp = imgui.GetStyle().ItemSpacing.x
    local eyeW = 46 * s

    if d.style == 3 then
      drawField(fields.dialog, avail - eyeW - sp, 46 * s)
      imgui.SameLine(0, sp)
      if ghostButton((revealPassword and ICON_EYE_OFF or ICON_EYE) .. '##reveal', V2(eyeW, 46 * s), false) then
        revealPassword = not revealPassword
      end
    else
      drawField(fields.dialog, avail, 46 * s)
    end

    local has2 = d.b2 ~= ''
    local bw = has2 and (avail - sp) / 2 or avail
    if primaryButton(safeLabel(d.b1 ~= '' and d.b1 or 'OK') .. '##db1', V2(bw, 50 * s)) then
      dialogRespond(1)
    end
    if has2 then
      imgui.SameLine(0, sp)
      if chipButton(safeLabel(d.b2) .. '##db2', V2(bw, 50 * s), false) then
        dialogRespond(0)
      end
    end

    imgui.End()
  end
)

imgui.OnFrame(
  function() return settingsWin[0] end,
  function()
    kbAwareWindow(430, 620)
    imgui.Begin('Игровая клавиатура', settingsWin, imgui.WindowFlags.NoCollapse)

    if imgui.BeginTabBar('##gktabs') then
      if imgui.BeginTabItem(ICON_KB .. ' Клавиатура') then
        drawKeyboardTab()
        imgui.EndTabItem()
      end
      if imgui.BeginTabItem(ICON_COMMENT .. ' Чат') then
        drawChatTab()
        imgui.EndTabItem()
      end
      if imgui.BeginTabItem(ICON_CHECK .. ' Диалоги') then
        drawDialogsTab()
        imgui.EndTabItem()
      end
      if imgui.BeginTabItem(ICON_PALETTE .. ' Стиль') then
        drawStyleTab()
        imgui.EndTabItem()
      end
      imgui.EndTabBar()
    end

    imgui.End()
  end
)

imgui.OnFrame(
  function() return os.clock() < capPreviewUntil end,
  function()
    local s = MDS
    local io = imgui.GetIO()
    local sw, sh = io.DisplaySize.x, io.DisplaySize.y
    local x0, y0 = sw * cfg.cap_x / 100, sh * cfg.cap_y / 100
    local x1, y1 = math.min(sw, x0 + sw * cfg.cap_w / 100), math.min(sh, y0 + sh * cfg.cap_h / 100)
    local dl = imgui.GetBackgroundDrawList()
    local ar, ag, ab = P.accent[1], P.accent[2], P.accent[3]
    dl:AddRectFilled(V2(x0, y0), V2(x1, y1), imgui.U32(ar, ag, ab, 0.16), 12 * s)
    dl:AddRect(V2(x0, y0), V2(x1, y1), imgui.U32(ar, ag, ab, 0.9), 12 * s, nil, 3 * s)
    dl:AddText(V2(x0 + 12 * s, y0 + 10 * s), imgui.U32(1, 1, 1, 0.9), 'Область нажатия на чат')
  end
)

local altKey, altStart, altFired = nil, 0, false
local spaceDrag = nil

imgui.OnFrame(
  function()
    if Keyboard.visible and not (chat.open or dlgWin[0] or settingsWin[0]) then
      Keyboard.close()
    end
    return Keyboard.visible and kb.enabled
  end,
  function()
    computeKbPalette()
    local s = MDS
    local io = imgui.GetIO()
    local sw, sh = io.DisplaySize.x, io.DisplaySize.y

    local pad = 8 * s
    local sp = kb.spacing * s
    local keyH = kb.keyHeight * s
    local toolH = keyH * 0.85
    local width = clamp(sw * kb.width / 100, math.min(320 * s, sw), sw)
    local height = kbHeight()
    local innerW = width - pad * 2

    imgui.SetNextWindowPos(V2((sw - width) / 2, sh - height - 6 * s), imgui.Cond.Always)
    imgui.SetNextWindowSize(V2(width, height), imgui.Cond.Always)

    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(KC.bg[1], KC.bg[2], KC.bg[3], kb.alpha))
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(pad, pad))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, V2(sp, sp))
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, (kb.rounding + 4) * s)

    local flags = imgui.WindowFlags.NoTitleBar
      + imgui.WindowFlags.NoResize
      + imgui.WindowFlags.NoMove
      + imgui.WindowFlags.NoScrollbar
      + imgui.WindowFlags.NoScrollWithMouse
      + imgui.WindowFlags.NoCollapse
      + imgui.WindowFlags.NoSavedSettings

    imgui.Begin('##GKKeyboard', nil, flags)
    imgui.SetWindowFontScale(kb.fontScale)

    local field = Keyboard.field
    local btnW = toolH * 1.3
    local btnsW = btnW * 5 + sp * 4

    imgui.SetCursorPos(V2(pad + innerW - btnsW, pad))
    local act = keyBtn(1, ICON_PASTE, btnW, toolH, 'special')
    if act then kbPaste() end
    imgui.SameLine(0, sp)
    local a2, ac2 = keyBtn(2, ICON_LEFT, btnW, toolH, 'special')
    holdRepeat(2, a2, ac2, function() kbMove(-1) end)
    imgui.SameLine(0, sp)
    local a3, ac3 = keyBtn(3, ICON_RIGHT, btnW, toolH, 'special')
    holdRepeat(3, a3, ac3, function() kbMove(1) end)
    imgui.SameLine(0, sp)
    act = keyBtn(4, ICON_X, btnW, toolH, 'special')
    if act then kbClear() end
    imgui.SameLine(0, sp)
    act = keyBtn(5, ICON_HIDE, btnW, toolH, 'special')
    if act then Keyboard.close() end

    if field then
      local room = innerW - btnsW - sp * 3
      local title = ellipsize(field.title or field.hint, room)
      imgui.SetCursorPos(V2(pad + 4 * s, pad + (toolH - imgui.GetTextLineHeight()) / 2))
      imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(KC.muted[1], KC.muted[2], KC.muted[3], 1))
      imgui.Text(esc(title))
      imgui.PopStyleColor(1)
    end

    imgui.SetCursorPos(V2(pad, pad + toolH + sp))

    local rows = buildRows()
    local maxSum = 0
    for _, row in ipairs(rows) do
      if row.sum > maxSum then maxSum = row.sum end
    end
    local unit = (innerW - sp * (maxSum - 1)) / maxSum

    local preview = nil
    local uid = 100
    for _, row in ipairs(rows) do
      local scale = row.fill and (maxSum / row.sum) or 1
      local rowSum = row.sum * scale
      local rowW = rowSum * unit + sp * (rowSum - 1)
      imgui.SetCursorPosX(pad + (innerW - rowW) / 2)

      for i, key in ipairs(row.keys) do
        if i > 1 then imgui.SameLine(0, sp) end
        local w = key.w * scale
        local px = w * unit + (w - 1) * sp
        uid = uid + 1
        local kind = key.kind

        if kind == 'char' then
          local label = Keyboard.shift > 0 and key.upper or key.lower
          local alt = cfg.alt_keys and ALT_KEYS[label] or nil
          local act1, active1, released1, p1 = keyBtn(uid, label, px, keyH, 'key', { scale = 1.12, hint = alt })
          if active1 and cfg.key_preview then
            preview = { label = label, x = p1.x, y = p1.y, w = px, h = keyH }
          end
          if alt then
            local now = imgui.GetTime()
            if act1 then altKey, altStart, altFired = uid, now, false end
            if active1 and altKey == uid and not altFired and now - altStart > 0.38 then
              kbInsert(alt)
              altFired = true
              if Keyboard.shift == 1 then Keyboard.shift = 0 end
              autoShift()
            end
            if released1 and altKey == uid then
              if not altFired then
                kbInsert(label)
                if Keyboard.shift == 1 then Keyboard.shift = 0 end
                autoShift()
              end
              altKey = nil
            end
          elseif act1 then
            kbInsert(label)
            if Keyboard.shift == 1 then Keyboard.shift = 0 end
            autoShift()
          end
        elseif kind == 'space' then
          local act1, active1, released1 = keyBtn(uid, kb.lang == 'RU' and 'Русский' or 'English', px, keyH, 'key')
          if cfg.swipe_space then
            if act1 then spaceDrag = { x = io.MousePos.x, moved = false } end
            if active1 and spaceDrag then
              local step = 16 * s
              local dx = io.MousePos.x - spaceDrag.x
              local steps = dx >= 0 and math.floor(dx / step) or math.ceil(dx / step)
              if steps ~= 0 then
                kbMove(steps)
                spaceDrag.x = spaceDrag.x + steps * step
                spaceDrag.moved = true
              end
            end
            if released1 and spaceDrag then
              if not spaceDrag.moved then
                kbInsert(' ')
                autoShift()
              end
              spaceDrag = nil
            end
          elseif act1 then
            kbInsert(' ')
            autoShift()
          end
        elseif kind == 'shift' then
          local act1 = keyBtn(uid, Keyboard.shift == 2 and ICON_CAPS or ICON_SHIFT, px, keyH, Keyboard.shift > 0 and 'on' or 'special')
          if act1 then
            local t = imgui.GetTime()
            if Keyboard.shift == 0 then
              Keyboard.shift = 1
            elseif Keyboard.shift == 1 then
              Keyboard.shift = (t - Keyboard.shiftT < 0.4) and 2 or 0
            else
              Keyboard.shift = 0
            end
            Keyboard.shiftT = t
          end
        elseif kind == 'bksp' then
          local act1, active1 = keyBtn(uid, ICON_BKSP, px, keyH, 'special')
          holdRepeat(uid, act1, active1, kbBackspace)
        elseif kind == 'sym' then
          local act1 = keyBtn(uid, Keyboard.symbols and 'ABC' or '123', px, keyH, 'special')
          if act1 then Keyboard.symbols = not Keyboard.symbols end
        elseif kind == 'lang' then
          local act1 = keyBtn(uid, ICON_GLOBE .. ' ' .. kb.lang, px, keyH, 'special')
          if act1 then
            kb.lang = kb.lang == 'RU' and 'EN' or 'RU'
            markDirty()
          end
        elseif kind == 'enter' then
          local label
          if field and field.onEnter then
            label = (field.enterIcon or ICON_CHECK) .. ' ' .. ellipsize(field.enterLabel or 'OK', px - 44 * s)
          elseif field and field.next then
            label = ICON_RIGHT .. ' Далее'
          else
            label = ICON_CHECK .. ' Готово'
          end
          local act1 = keyBtn(uid, label, px, keyH, 'accent')
          if act1 then kbEnter() end
        end
      end
    end

    imgui.End()
    imgui.PopStyleVar(3)
    imgui.PopStyleColor(1)

    if preview then
      local fg = imgui.GetForegroundDrawList()
      local bw = math.max(preview.w * 1.4, 56 * s)
      local bh = preview.h * 1.6
      local bx = clamp(preview.x + preview.w / 2 - bw / 2, 4 * s, sw - bw - 4 * s)
      local by = preview.y - bh - 6 * s
      local rr = kb.rounding * s * 1.4
      fg:AddRectFilled(V2(bx, by), V2(bx + bw, by + bh), U32t(mixTbl(KC.key, KC.text, 0.14)), rr)
      fg:AddRect(V2(bx, by), V2(bx + bw, by + bh), U32t(KC.accent), rr, nil, 2 * s)
      local k = 1.9
      local ts = imgui.CalcTextSize(preview.label)
      fg:AddTextFontPtr(imgui.GetFont(), imgui.GetFontSize() * k, V2(bx + (bw - ts.x * k) / 2, by + (bh - ts.y * k) / 2), U32t(KC.text), preview.label)
    end
  end
)


local capTouch = nil

local function inCapZone(x, y)
  local sw, sh = getScreenResolution()
  local zx, zy = sw * cfg.cap_x / 100, sh * cfg.cap_y / 100
  return x >= zx and x <= zx + sw * cfg.cap_w / 100 and y >= zy and y <= zy + sh * cfg.cap_h / 100
end

function onTouch(kind, id, x, y)
  if not (kb.enabled and cfg.cap_enabled) then return end

  if capTouch and capTouch.id == id then
    if kind == 3 then
      if math.abs(x - capTouch.x) + math.abs(y - capTouch.y) > 28 * MDS then capTouch.moved = true end
    elseif kind == 1 then
      local tap = not capTouch.moved and os.clock() - capTouch.t < 0.8
      capTouch = nil
      if tap then pendingOpenChat = true end
    end
    return false
  end

  if kind == 2 then
    if capTouch and os.clock() - capTouch.t > 5 then capTouch = nil end
    if capTouch == nil and not chat.open and not dlgWin[0] and not settingsWin[0] and inCapZone(x, y) then
      capTouch = { id = id, x = x, y = y, t = os.clock(), moved = false }
      return false
    end
  end
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
  if dlg and not dlg.test then
    pcall(closeDialog)
  end
  if not (kb.enabled and cfg.catch_input) then return end
  if style ~= 1 and style ~= 3 then return end
  local ok = pcall(openDialog, id, style, toUtf8(title), toUtf8(button1), toUtf8(button2), toUtf8(text), false)
  if ok then return false end
end

function onScriptTerminate(scr, quitGame)
  if scr ~= thisScript() then return end
  if dirty then saveAll() end
  Keyboard.close()
  sampUnregisterChatCommand('gk')
  sampUnregisterChatCommand('gkchat')
end

function main()
  while not isSampAvailable() do wait(0) end

  sampRegisterChatCommand('gk', function()
    settingsWin[0] = not settingsWin[0]
  end)

  sampRegisterChatCommand('gkchat', function()
    pendingOpenChat = not chat.open
    if chat.open then closeChat() end
  end)

  while true do
    wait(250)
    if dirty and os.clock() - dirtyStamp > 0.8 then saveAll() end
  end
end
