script_name('gyrozxc')
script_author('usercuves')
script_description('Гироскоп')
script_version('2.0')

local ffi = require 'ffi'
local imgui = require 'mimgui'
local inicfg = require 'inicfg'
local samemory = require 'SAMemory'
local faicons = require 'fAwesome6'

pcall(ffi.cdef, [[
typedef struct gyro_ASensorManager gyro_ASensorManager;
typedef struct gyro_ASensor gyro_ASensor;
typedef struct gyro_ASensorEventQueue gyro_ASensorEventQueue;
typedef struct gyro_ALooper gyro_ALooper;
typedef struct gyro_event {
	int32_t version;
	int32_t sensor;
	int32_t type;
	int32_t reserved0;
	int64_t timestamp;
	float data[16];
	int32_t flags;
	int32_t reserved1[3];
} gyro_event;
gyro_ASensorManager* ASensorManager_getInstanceForPackage(const char* packageName);
gyro_ASensorManager* ASensorManager_getInstance(void);
const gyro_ASensor* ASensorManager_getDefaultSensor(gyro_ASensorManager* manager, int type);
gyro_ALooper* ALooper_forThread(void);
gyro_ALooper* ALooper_prepare(int opts);
gyro_ASensorEventQueue* ASensorManager_createEventQueue(gyro_ASensorManager* manager, gyro_ALooper* looper, int ident, void* callback, void* data);
int ASensorManager_destroyEventQueue(gyro_ASensorManager* manager, gyro_ASensorEventQueue* queue);
int ASensorEventQueue_enableSensor(gyro_ASensorEventQueue* queue, const gyro_ASensor* sensor);
int ASensorEventQueue_disableSensor(gyro_ASensorEventQueue* queue, const gyro_ASensor* sensor);
int ASensorEventQueue_setEventRate(gyro_ASensorEventQueue* queue, const gyro_ASensor* sensor, int32_t usec);
long ASensorEventQueue_getEvents(gyro_ASensorEventQueue* queue, gyro_event* events, size_t count);
]])

local lib = ffi.load('android')
local MDS = MONET_DPI_SCALE or 1.0


local function clamp(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

local function num(v, default)
  return tonumber(v) or default
end

local DEFAULT_INI = {
  gyro = { enabled = true, aim_sx = 1.0, aim_sy = 1.0, inv_x = false, inv_y = false, smooth = 0.6 },
  ui = {
    themeColor = '#14161B', themeAlpha = 0.96, accent = '#3B82F6', uiRound = 12,
    btnSize = 44, btnShape = 100, btnX = 40, btnY = 300, btnLocked = false,
    showButton = true, uiPreset = 'Ночь'
  }
}

local rawIni = inicfg.load(DEFAULT_INI, 'Gyroscope') or DEFAULT_INI
local rawGyro = rawIni.gyro or {}
local rawUi = rawIni.ui or {}

local cfg = {
  enabled = rawGyro.enabled ~= false,
  aim_sx = clamp(num(rawGyro.aim_sx, 1.0), 0.1, 5.0),
  aim_sy = clamp(num(rawGyro.aim_sy, 1.0), 0.1, 5.0),
  inv_x = rawGyro.inv_x == true,
  inv_y = rawGyro.inv_y == true,
  smooth = clamp(num(rawGyro.smooth, 0.6), 0.2, 1.0)
}

local ui = {
  themeColor = tostring(rawUi.themeColor or '#14161B'),
  themeAlpha = clamp(num(rawUi.themeAlpha, 0.96), 0.3, 1.0),
  accent = tostring(rawUi.accent or '#3B82F6'),
  uiRound = clamp(num(rawUi.uiRound, 12), 0, 24),
  btnSize = clamp(num(rawUi.btnSize, 44), 32, 80),
  btnShape = clamp(num(rawUi.btnShape, 100), 0, 100),
  btnX = num(rawUi.btnX, 40),
  btnY = num(rawUi.btnY, 300),
  btnLocked = rawUi.btnLocked == true,
  showButton = rawUi.showButton ~= false,
  uiPreset = tostring(rawUi.uiPreset or 'Ночь')
}

local mgr, gyro, queue = nil, nil, nil
local sensor_ready = false
local sensor_on = false
local dirty = false
local err_text = ''
local last_ts = 0
local pend_x, pend_y = 0.0, 0.0
local cur_g = 0
local apply_failed = false
local ka_x, ka_y = 1.0, 1.0
local OFF_ACTIVE = 0
local EV_MAX = 8
local ev = ffi.new('gyro_event[?]', EV_MAX)

local AIM_MODES = {
	[5] = true, [7] = true, [8] = true, [0x27] = true, [0x28] = true,
	[0x33] = true, [0x34] = true, [0x35] = true, [0x37] = true, [0x41] = true
}


local function gyro_save()
  inicfg.save({
    gyro = {
      enabled = cfg.enabled,
      aim_sx = cfg.aim_sx,
      aim_sy = cfg.aim_sy,
      inv_x = cfg.inv_x,
      inv_y = cfg.inv_y,
      smooth = cfg.smooth
    },
    ui = {
      themeColor = ui.themeColor,
      themeAlpha = ui.themeAlpha,
      accent = ui.accent,
      uiRound = ui.uiRound,
      btnSize = ui.btnSize,
      btnShape = ui.btnShape,
      btnX = ui.btnX,
      btnY = ui.btnY,
      btnLocked = ui.btnLocked,
      showButton = ui.showButton,
      uiPreset = ui.uiPreset
    }
  }, 'Gyroscope')
  dirty = false
end

local dirtyStamp = 0

local function markDirty()
  dirty = true
  dirtyStamp = os.clock()
end

local function gyro_recalc()
	local ix = cfg.inv_x and -1.0 or 1.0
	ka_x = cfg.aim_sx * ix
	ka_y = cfg.aim_sy * (cfg.inv_y and -1.0 or 1.0)
end


local function gyro_init()
	if sensor_ready then return true end
	local pkg = getWorkingDirectory():match('Android/media/([^/]+)')
	if pkg then
		local ok, m = pcall(function() return lib.ASensorManager_getInstanceForPackage(pkg) end)
		if ok and m ~= nil then mgr = m end
	end
	if mgr == nil then
		local ok, m = pcall(function() return lib.ASensorManager_getInstance() end)
		if ok and m ~= nil then mgr = m end
	end
	if mgr == nil then return false, 'no ASensorManager' end

	gyro = lib.ASensorManager_getDefaultSensor(mgr, 4)
	if gyro == nil then return false, 'gyroscope not found' end

	local looper = lib.ALooper_forThread()
	if looper == nil then looper = lib.ALooper_prepare(1) end
	if looper == nil then return false, 'no ALooper' end

	queue = lib.ASensorManager_createEventQueue(mgr, looper, 1, nil, nil)
	if queue == nil then return false, 'event queue failed' end

	local ok, off = pcall(ffi.offsetof, 'CCamera', 'nActiveCam')
	if not ok or not off then return false, 'CCamera.nActiveCam' end
	OFF_ACTIVE = off

	sensor_ready = true
	return true
end

local function gyro_drain()
	while tonumber(lib.ASensorEventQueue_getEvents(queue, ev, EV_MAX)) > 0 do end
end

local function gyro_enable()
	if sensor_on or not sensor_ready then return end
	if lib.ASensorEventQueue_enableSensor(queue, gyro) >= 0 then
		lib.ASensorEventQueue_setEventRate(queue, gyro, 20000)
		gyro_drain()
		last_ts = 0
		sensor_on = true
	end
end

local function gyro_disable()
	if not sensor_on then return end
	lib.ASensorEventQueue_disableSensor(queue, gyro)
	gyro_drain()
	sensor_on = false
	last_ts = 0
	pend_x, pend_y = 0.0, 0.0
	cur_g = 0
end

local function gyro_poll()
	local ax, ay = 0.0, 0.0
	while true do
		local n = tonumber(lib.ASensorEventQueue_getEvents(queue, ev, EV_MAX))
		if n <= 0 then break end
		for i = 0, n - 1 do
			local e = ev[i]
			local ts = tonumber(e.timestamp)
			if last_ts ~= 0 then
				local dt = (ts - last_ts) * 1e-9
				if dt > 0 and dt < 0.1 then
					ax = ax + e.data[0] * dt
					ay = ay - e.data[1] * dt
				end
			end
			last_ts = ts
		end
	end
	pend_x = pend_x + ax
	pend_y = pend_y + ay
end

local function gyro_cam()
	local cam = samemory.camera
	local idx = ffi.cast('uint8_t*', cam)[OFF_ACTIVE]
	if idx > 2 then idx = 0 end
	return cam.aCams[idx]
end

local function gyro_group()
	if samemory.user_pause[0] or samemory.code_pause[0] then return 0, nil end
	local c = gyro_cam()
	if AIM_MODES[c.nMode] then
		return 1, c
	end
	return 0, nil
end


local function gyro_apply(g, c)
	local sm = cfg.smooth
	local dx = pend_x * sm
	local dy = pend_y * sm
	pend_x = pend_x - dx
	pend_y = pend_y - dy
	if dx < 1e-6 and dx > -1e-6 and dy < 1e-6 and dy > -1e-6 then return end
	c.fHorizontalAngle = c.fHorizontalAngle + dx * ka_x
	local v = c.fVerticalAngle + dy * ka_y
	if v > 1.5 then v = 1.5 elseif v < -1.5 then v = -1.5 end
	c.fVerticalAngle = v
end


local window = imgui.new.bool(false)
local m_aim_sx = imgui.new.float(cfg.aim_sx)
local m_aim_sy = imgui.new.float(cfg.aim_sy)
local m_smooth = imgui.new.float(cfg.smooth)
local themeColorPtr = imgui.new.float[3]()
local accentPtr = imgui.new.float[3]()
local themeAlphaPtr = imgui.new.float(ui.themeAlpha)
local uiRoundPtr = imgui.new.int(ui.uiRound)
local btnSizePtr = imgui.new.int(ui.btnSize)
local btnShapePtr = imgui.new.int(ui.btnShape)
local glyphRanges

local function esc(text)
  return (text:gsub('%%', '%%%%'))
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

local function textWidth(text)
  return imgui.CalcTextSize(text).x
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

local ICON_NAMES = {
  'CROSSHAIRS', 'POWER_OFF', 'TRIANGLE_EXCLAMATION', 'CIRCLE_CHECK', 'CHECK',
  'MINUS', 'PLUS', 'SLIDERS', 'PALETTE', 'ROTATE_LEFT', 'LOCK', 'LOCK_OPEN',
  'ARROWS_LEFT_RIGHT', 'ARROWS_UP_DOWN', 'GAUGE_HIGH', 'EYE', 'EYE_SLASH'
}

local ICON_MAIN = faicons('CROSSHAIRS')
local ICON_POWER = faicons('POWER_OFF')
local ICON_WARN = faicons('TRIANGLE_EXCLAMATION')
local ICON_OK = faicons('CIRCLE_CHECK')
local ICON_CHECK = faicons('CHECK')
local ICON_MINUS = faicons('MINUS')
local ICON_PLUS = faicons('PLUS')
local ICON_SLIDERS = faicons('SLIDERS')
local ICON_PALETTE = faicons('PALETTE')
local ICON_RESET = faicons('ROTATE_LEFT')
local ICON_LOCK = faicons('LOCK')
local ICON_UNLOCK = faicons('LOCK_OPEN')
local ICON_X = faicons('ARROWS_LEFT_RIGHT')
local ICON_Y = faicons('ARROWS_UP_DOWN')
local ICON_GAUGE = faicons('GAUGE_HIGH')
local ICON_EYE = faicons('EYE')
local ICON_EYE_OFF = faicons('EYE_SLASH')

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
  local st = imgui.GetStyle()
  local cols = st.Colors
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

  st.WindowPadding = imgui.ImVec2(14 * s, 12 * s)
  st.WindowRounding = r * 1.3 * s
  st.WindowBorderSize = 0
  st.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
  st.ChildRounding = r * s
  st.ChildBorderSize = 0
  st.PopupRounding = r * s
  st.PopupBorderSize = 0
  st.FramePadding = imgui.ImVec2(12 * s, 8 * s)
  st.FrameRounding = r * 0.8 * s
  st.FrameBorderSize = 0
  st.ItemSpacing = imgui.ImVec2(10 * s, 10 * s)
  st.ItemInnerSpacing = imgui.ImVec2(8 * s, 6 * s)
  st.ScrollbarSize = 12 * s
  st.ScrollbarRounding = r * s
  st.GrabMinSize = 18 * s
  st.GrabRounding = r * s
  st.TabRounding = r * 0.8 * s
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

local function wrapPlace(st, w)
  if not st.first and st.used + st.sp + w <= st.availW then
    imgui.SameLine(0, st.sp)
    st.used = st.used + st.sp + w
  else
    st.used = w
  end
  st.first = false
end

local function stepSlider(title, id, ptr, minV, maxV, step, onChange)
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
  if imgui.SliderFloat('##' .. id, ptr, minV, maxV, '%.2f') then
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

local UI_PRESETS = {
  { name = 'Ночь', bg = '#14161B', accent = '#3B82F6' },
  { name = 'AMOLED', bg = '#000000', accent = '#00C2A8' },
  { name = 'Светлая', bg = '#F1F3F8', accent = '#2F7BFF' },
  { name = 'Океан', bg = '#0B1C2B', accent = '#2DD4BF' },
  { name = 'Сакура', bg = '#221019', accent = '#FF6FA5' },
  { name = 'Мята', bg = '#0C1B16', accent = '#4ADE80' },
  { name = 'Аметист', bg = '#171126', accent = '#A78BFA' }
}

local SENS_PRESETS = {
  { name = 'Низкая', v = 0.6 },
  { name = 'Средняя', v = 1.0 },
  { name = 'Высокая', v = 2.0 }
}

local function syncPtrs()
  m_aim_sx[0] = cfg.aim_sx
  m_aim_sy[0] = cfg.aim_sy
  m_smooth[0] = cfg.smooth
  local r, g, b = hexToRgb(ui.themeColor)
  themeColorPtr[0], themeColorPtr[1], themeColorPtr[2] = r, g, b
  local ar, ag, ab = hexToRgb(ui.accent)
  accentPtr[0], accentPtr[1], accentPtr[2] = ar, ag, ab
  themeAlphaPtr[0] = ui.themeAlpha
  uiRoundPtr[0] = ui.uiRound
  btnSizePtr[0] = ui.btnSize
  btnShapePtr[0] = ui.btnShape
end
syncPtrs()

local function applyPreset(p)
  ui.themeColor = p.bg
  ui.accent = p.accent
  ui.uiPreset = p.name
  syncPtrs()
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

local function resetGyro()
  cfg.enabled = true
  cfg.aim_sx = 1.0
  cfg.aim_sy = 1.0
  cfg.inv_x = false
  cfg.inv_y = false
  cfg.smooth = 0.6
  syncPtrs()
  gyro_recalc()
  markDirty()
end

local NO_SCROLL = imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse

local function drawStatusCard()
  local s = MDS
  local h = 84 * s
  local pad = 14 * s
  local chip = 52 * s

  local icon, title, sub, col
  if err_text ~= '' then
    icon, title, sub, col = ICON_WARN, 'Ошибка', err_text, { 0.9, 0.3, 0.32 }
  elseif sensor_on then
    icon, title, sub, col = ICON_OK, 'Датчик работает', 'Камера следует за поворотом телефона', { 0.25, 0.78, 0.45 }
  elseif sensor_ready then
    icon, title, sub, col = ICON_MAIN, 'Датчик готов', 'Включится в режиме прицеливания', P.accent
  else
    icon, title, sub, col = ICON_WARN, 'Запуск датчика', 'Подождите пару секунд', { 0.95, 0.72, 0.25 }
  end

  imgui.BeginChild('##status', imgui.ImVec2(0, h), false, NO_SCROLL)
  local w = imgui.GetWindowWidth()

  imgui.SetCursorPos(imgui.ImVec2(pad, (h - chip) / 2))
  local tc = { hexToRgb(contrastText(rgbToHex(col[1], col[2], col[3]))) }
  imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 16 * s)
  coloredButton(icon .. '##st', imgui.ImVec2(chip, chip), C(col), C(col), C(col), C(tc))
  imgui.PopStyleVar(1)

  local textX = pad + chip + 14 * s
  local textMax = w - textX - pad
  local lineH = imgui.GetTextLineHeight()
  local blockH = lineH * 2 + imgui.GetStyle().ItemSpacing.y
  imgui.SetCursorPos(imgui.ImVec2(textX, (h - blockH) / 2))
  imgui.SetWindowFontScale(1.1)
  imgui.Text(esc(title))
  imgui.SetWindowFontScale(1.0)
  imgui.SetCursorPosX(textX)
  imgui.PushStyleColor(imgui.Col.Text, C(P.muted))
  imgui.Text(esc(ellipsize(sub, textMax)))
  imgui.PopStyleColor(1)

  imgui.EndChild()
end

local function drawGyroTab()
  local s = MDS
  local avail = imgui.GetContentRegionAvail().x
  local sp = imgui.GetStyle().ItemSpacing.x

  drawStatusCard()
  sectionLabel('Пока меню открыто, гироскоп приостановлен')

  local powerLabel = ICON_POWER .. (cfg.enabled and '  Гироскоп включён' or '  Гироскоп выключен')
  if chipButton(powerLabel, imgui.ImVec2(avail, 54 * s), cfg.enabled) then
    cfg.enabled = not cfg.enabled
    markDirty()
  end

  sectionLabel('Быстрая настройка чувствительности')
  local third = (avail - sp * 2) / 3
  for i, p in ipairs(SENS_PRESETS) do
    if i > 1 then imgui.SameLine(0, sp) end
    local active = math.abs(cfg.aim_sx - p.v) < 0.001 and math.abs(cfg.aim_sy - p.v) < 0.001
    if chipButton(p.name .. '##sens' .. i, imgui.ImVec2(third, 44 * s), active) then
      cfg.aim_sx = p.v
      cfg.aim_sy = p.v
      syncPtrs()
      gyro_recalc()
      markDirty()
    end
  end

  stepSlider('Горизонталь (X)', 'ax', m_aim_sx, 0.1, 5.0, 0.05, function(v)
    cfg.aim_sx = v
    gyro_recalc()
    markDirty()
  end)

  stepSlider('Вертикаль (Y)', 'ay', m_aim_sy, 0.1, 5.0, 0.05, function(v)
    cfg.aim_sy = v
    gyro_recalc()
    markDirty()
  end)

  stepSlider('Плавность', 'sm', m_smooth, 0.2, 1.0, 0.05, function(v)
    cfg.smooth = v
    markDirty()
  end)

  sectionLabel('Направление')
  local half = (avail - sp) / 2
  if chipButton(ICON_X .. '  Инверсия X##ix', imgui.ImVec2(half, 46 * s), cfg.inv_x) then
    cfg.inv_x = not cfg.inv_x
    gyro_recalc()
    markDirty()
  end
  imgui.SameLine(0, sp)
  if chipButton(ICON_Y .. '  Инверсия Y##iy', imgui.ImVec2(half, 46 * s), cfg.inv_y) then
    cfg.inv_y = not cfg.inv_y
    gyro_recalc()
    markDirty()
  end

  imgui.Separator()
  if ghostButton(ICON_RESET .. '  Сбросить настройки гироскопа', imgui.ImVec2(avail, 0), true) then
    resetGyro()
  end
end

local function drawStyleTab()
  local s = MDS
  local avail = imgui.GetContentRegionAvail().x
  local sp = imgui.GetStyle().ItemSpacing.x

  sectionLabel('Готовые темы')
  local st = wrapStart()
  for i, p in ipairs(UI_PRESETS) do
    local label = (ui.uiPreset == p.name and (ICON_CHECK .. ' ') or '') .. p.name
    local w = textWidth(label) + 30 * s
    wrapPlace(st, w)
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

  sliderRow('Прозрачность окна', 'alpha', themeAlphaPtr, 0.3, 1.0, true, function(v)
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
  sectionLabel('Плавающая кнопка')

  local showLabel = (ui.showButton and ICON_EYE or ICON_EYE_OFF) .. (ui.showButton and '  Кнопка показана' or '  Кнопка скрыта (меню: /gyro)')
  if chipButton(showLabel, imgui.ImVec2(avail, 46 * s), ui.showButton) then
    ui.showButton = not ui.showButton
    markDirty()
  end

  local lockLabel = (ui.btnLocked and ICON_LOCK or ICON_UNLOCK) .. (ui.btnLocked and '  Позиция закреплена' or '  Позицию можно менять')
  if chipButton(lockLabel, imgui.ImVec2(avail, 46 * s), ui.btnLocked) then
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
  if ghostButton(ICON_RESET .. '  Сбросить оформление', imgui.ImVec2(avail, 0), true) then
    resetAppearance()
  end
end

local DRAG_THRESHOLD = 8
local dragX, dragY, dragBx, dragBy
local dragMoved = false

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

imgui.OnFrame(function() return ui.showButton end, function()
  local s = MDS
  local flags = imgui.WindowFlags.NoTitleBar
    + imgui.WindowFlags.NoResize
    + imgui.WindowFlags.NoScrollbar
    + imgui.WindowFlags.NoScrollWithMouse
    + imgui.WindowFlags.NoBackground
    + imgui.WindowFlags.NoSavedSettings
    + imgui.WindowFlags.AlwaysAutoResize
    + imgui.WindowFlags.NoMove

  imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(3 * s, 3 * s))
  imgui.SetNextWindowPos(imgui.ImVec2(ui.btnX, ui.btnY), imgui.Cond.Always)
  imgui.Begin('##GyroButton', nil, flags)
  imgui.SetWindowFontScale(clamp(ui.btnSize / 36, 1.0, 2.4))

  local size = ui.btnSize * s
  local ar, ag, ab = P.accent[1], P.accent[2], P.accent[3]
  imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(ar, ag, ab, 1))
  imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(math.min(ar + 0.06, 1), math.min(ag + 0.06, 1), math.min(ab + 0.06, 1), 1))
  imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(ar * 0.8, ag * 0.8, ab * 0.8, 1))
  imgui.PushStyleColor(imgui.Col.Text, C(P.onAccent))
  imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(math.min(ar + 0.3, 1), math.min(ag + 0.3, 1), math.min(ab + 0.3, 1), 0.6))
  imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, (size / 2) * (ui.btnShape / 100))
  imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, 2 * s)
  local clicked = imgui.Button(ICON_MAIN, imgui.ImVec2(size, size))
  imgui.PopStyleVar(2)
  imgui.PopStyleColor(5)

  if not ui.btnLocked and imgui.IsItemActive() then
    local mp = imgui.GetIO().MousePos
    if dragX == nil then
      dragX, dragY = mp.x, mp.y
      dragBx, dragBy = ui.btnX, ui.btnY
      dragMoved = false
    else
      local dx = mp.x - dragX
      local dy = mp.y - dragY
      if dragMoved or math.abs(dx) > DRAG_THRESHOLD * s or math.abs(dy) > DRAG_THRESHOLD * s then
        dragMoved = true
        ui.btnX = dragBx + dx
        ui.btnY = dragBy + dy
      end
    end
  elseif dragX ~= nil then
    if dragMoved then markDirty() end
    dragX = nil
  end

  if clicked and not dragMoved then
    window[0] = not window[0]
  end

  imgui.End()
  imgui.PopStyleVar(1)
end)

imgui.OnFrame(function() return window[0] end, function()
  local s = MDS
  local resX, resY = getScreenResolution()
  imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
  imgui.SetNextWindowSize(imgui.ImVec2(400 * s, 560 * s), imgui.Cond.FirstUseEver)
  imgui.Begin('Гироскоп', window, imgui.WindowFlags.NoCollapse)

  if imgui.BeginTabBar('##gyrotabs') then
    if imgui.BeginTabItem(ICON_SLIDERS .. ' Настройки') then
      drawGyroTab()
      imgui.EndTabItem()
    end
    if imgui.BeginTabItem(ICON_PALETTE .. ' Стиль') then
      drawStyleTab()
      imgui.EndTabItem()
    end
    imgui.EndTabBar()
  end

  imgui.End()
end)

function main()
	while not isSampAvailable() do wait(0) end
	wait(1000)

	gyro_recalc()
	local ok, err = gyro_init()
	if ok then
		local ok2, err2 = pcall(gyro_group)
		if not ok2 then
			sensor_ready = false
			ok, err = false, 'camera: ' .. tostring(err2)
		end
	end
	if not ok then
		err_text = tostring(err)
		sampAddChatMessage('{20b2aa}[Gyroscope] {FF0000}\xCD\xE5 \xE7\xE0\xEF\xF3\xF9\xE5\xED: {FFFFFF}' .. err_text, -1)
	else
		sampAddChatMessage('{20b2aa}[Gyroscope] {FFFFFF}\xC3\xEE\xF2\xEE\xE2. \xCC\xE5\xED\xFE: /gyro', -1)
	end

	sampRegisterChatCommand('gyro', function() window[0] = not window[0] end)

	local idle = 0
	while true do
		if dirty and os.clock() - dirtyStamp > 0.6 then gyro_save() end
		if sensor_ready and cfg.enabled then
			local g, c = 0, nil
			if not window[0] then g, c = gyro_group() end
			if g > 0 then
				idle = 0
				if not sensor_on then gyro_enable() end
				if g ~= cur_g then
					pend_x, pend_y = 0.0, 0.0
					cur_g = g
				end
				gyro_poll()
				if not apply_failed then
					local okp, errp = pcall(gyro_apply, g, c)
					if not okp then
						apply_failed = true
						sampAddChatMessage('{20b2aa}[Gyroscope] {FF0000}Error: {FFFFFF}' .. tostring(errp), -1)
					end
				end
				wait(0)
			else
				idle = idle + 1
				pend_x, pend_y = 0.0, 0.0
				cur_g = 0
				if sensor_on and idle > 30 then gyro_disable() end
				wait(sensor_on and 16 or 100)
			end
		else
			if sensor_on then gyro_disable() end
			wait(250)
		end
	end
end

function onScriptTerminate(scr, quitGame)
	if scr ~= thisScript() then return end
	if sensor_ready then
		gyro_disable()
		lib.ASensorManager_destroyEventQueue(mgr, queue)
	end
	if dirty then gyro_save() end
end
