script_name('TimeOnScreenV2')
script_description('РћС‚РѕР±СЂР°Р¶РµРЅРёРµ РІСЂРµРјРµРЅРё РЅР° СЌРєСЂР°РЅРµ РґР»СЏ Arizona Mobile. РђРєС‚РёРІР°С†РёСЏ: /ctime')
script_author('Meow Brightside, @T23Vladimir + Claude')

require('lib.moonloader')
require('encoding').default = 'CP1251'
local _u8 = require('encoding').UTF8
local imgui = require('mimgui')
local inicfg = require('inicfg')

local u8 = setmetatable({}, {
    __call = function(_, s)
        if s == nil then return '' end
        if type(s) ~= 'string' then s = tostring(s) end
        local ok, result = pcall(_u8, s)
        return ok and result or s
    end,
    __index = _u8,
})

local res, socket = pcall(require, 'socket')
assert(res, 'Lib SOCKET not found')

local ini_name = 'TimeOnScreenV2.ini'

local function toBool(v) return tostring(v) == 'true' end

local cfg = inicfg.load({
    settings = {
        version        = '2.0',
        custom_dpi     = 1.0,
        autofind_dpi   = false,
        activate       = true,
        show_ms        = false,
        show_date      = true,
        outline        = true,
        time_x         = 760,
        time_y         = 345,
        fontsize       = 18,
        ms_fontsize    = 18,
        color_r        = 1.0, color_g = 1.0, color_b = 1.0,
        ms_color_r     = 1.0, ms_color_g = 1.0, ms_color_b = 1.0,
        date_color_r   = 0.0, date_color_g = 1.0, date_color_b = 0.035824775695801,
        locked         = false,
        menu_w         = 393,
        menu_h         = 436,
        menu_x         = -1,
        menu_y         = -1,
        menu_w_saved   = 1,
    }
}, ini_name)

if not doesFileExist('monetloader/config/' .. ini_name) then
    inicfg.save(cfg, ini_name)
end

local function saveCfg()
    inicfg.save(cfg, ini_name)
end

local s = cfg.settings

function isMonetLoader() return MONET_VERSION ~= nil end

if not toBool(s.autofind_dpi) then
    if isMonetLoader() then
        s.custom_dpi = MONET_DPI_SCALE or 1.0
    else
        local bw, bh = 1366, 768; local cw, ch = getScreenResolution()
        s.custom_dpi = ((cw / bw) + (ch / bh)) / 2
    end
    s.autofind_dpi = true; saveCfg()
end

local sizeX, sizeY = getScreenResolution()

local MainWindow = imgui.new.bool(false)
local cb_activate = imgui.new.bool(toBool(s.activate))
local cb_show_ms = imgui.new.bool(toBool(s.show_ms))
local cb_show_date = imgui.new.bool(toBool(s.show_date))
local cb_locked = imgui.new.bool(toBool(s.locked))
local cb_outline = imgui.new.bool(toBool(s.outline))
local frame_count = 0
local force_reposition = {}

local slider_buffers = {}
local color_time = imgui.new.float[3](tonumber(s.color_r) or 1.0, tonumber(s.color_g) or 1.0, tonumber(s.color_b) or 1.0)
local color_ms = imgui.new.float[3](tonumber(s.ms_color_r) or 0.52, tonumber(s.ms_color_g) or 0.52, tonumber(s.ms_color_b) or 0.52)
local color_date = imgui.new.float[3](tonumber(s.date_color_r) or 0.9254901960784314, tonumber(s.date_color_g) or 0.4823529411764706, tonumber(s.date_color_b) or 0.0)

function change_dpi()
    if not isMonetLoader() then imgui.SetWindowFontScale(tonumber(s.custom_dpi)) end
end

local function needForcePos() return frame_count <= 1 end
local function requestReposition(winId) force_reposition[winId] = true end
local function consumeReposition(winId)
    if force_reposition[winId] then force_reposition[winId] = nil; return true end
    return false
end

local function touchSlider(val, step, mn, mx, id)
    local changed = false
    local d = tonumber(s.custom_dpi) or 1.0
    local totalW = imgui.GetWindowContentRegionWidth()
    local frameH = imgui.GetFrameHeight()
    local btn_size = imgui.ImVec2(30 * d, frameH)
    local gap = 6 * d
    local sliderW = totalW - btn_size.x * 2 - gap * 2

    if imgui.Button('-##m' .. id, btn_size) then
        val = val - step; if val < mn then val = mn end; changed = true
    end
    imgui.SameLine(0, gap)

    if not slider_buffers[id] then slider_buffers[id] = imgui.new.int(val) end
    local buf = slider_buffers[id]
    buf[0] = val
    imgui.PushItemWidth(sliderW)
    if imgui.SliderInt('##sl' .. id, buf, mn, mx) then val = buf[0]; changed = true end
    imgui.PopItemWidth()
    imgui.SameLine(0, gap)

    if imgui.Button('+##p' .. id, btn_size) then
        val = val + step; if val > mx then val = mx end; changed = true
    end
    return val, changed
end

local tWeekdays = {[0] = 'Воскресенье', [1] = 'Понедельник', [2] = 'Вторник', [3] = 'Среда', [4] = 'Четверг', [5] = 'Пятница', [6] = 'Суббота'}
local tMonths = {'Января', 'Февраля', 'Марта', 'Апреля', 'Мая', 'Июня', 'Июля', 'Августа', 'Сентября', 'Октября', 'Ноября', 'Декабря'}

local function getStrDate(date_table)
    local weekday = tWeekdays[date_table.wday - 1]
    local month = tMonths[date_table.month]
    return string.format('%s, %d %s', weekday, date_table.day, month)
end

local function rgbInputs(id, color_arr, cfg_r_key, cfg_g_key, cfg_b_key)
    local swatch_flags = imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel
    if imgui.ColorEdit3('##swatch' .. id, color_arr, swatch_flags) then
        s[cfg_r_key] = color_arr[0]; s[cfg_g_key] = color_arr[1]; s[cfg_b_key] = color_arr[2]
        saveCfg()
    end
end

local OUTLINE_COL = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0, 0, 0, 1))
local OUTLINE_OFFSETS = {
    {-1, -1}, {0, -1}, {1, -1},
    {-1,  0},          {1,  0},
    {-1,  1}, {0,  1}, {1,  1},
}

local function addTextOutlined(dl, pos, col, text, use_outline)
    if use_outline then
        for _, off in ipairs(OUTLINE_OFFSETS) do
            dl:AddText(imgui.ImVec2(pos.x + off[1], pos.y + off[2]), OUTLINE_COL, text)
        end
    end
    dl:AddText(pos, col, text)
end

local function drawTimeWindow(winId, tx, ty, locked)
    local force = needForcePos() or consumeReposition(winId)
    local cond = force and imgui.Cond.Always or imgui.Cond.FirstUseEver
    imgui.SetNextWindowPos(imgui.ImVec2(tx, ty), cond)
    local fl = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoBackground + imgui.WindowFlags.AlwaysAutoResize
    if locked then fl = fl + imgui.WindowFlags.NoMove end
    imgui.Begin('##' .. winId, nil, fl)
    change_dpi()

    local date_table = os.date('*t')
    local ms = tostring(math.ceil(socket.gettime() * 1000))
    ms = tonumber(string.sub(ms, #ms - 2, #ms))
    local hour, minute, second = date_table.hour, date_table.min, date_table.sec

    local col_time = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(tonumber(s.color_r), tonumber(s.color_g), tonumber(s.color_b), 1))

    local text_main = string.format('%02d:%02d:%02d', hour, minute, second)

    local scale = tonumber(s.fontsize) / 16
    local ms_scale = tonumber(s.ms_fontsize) / 16

    local use_outline = toBool(s.outline)
    local dl = imgui.GetWindowDrawList()
    local wp = imgui.GetCursorScreenPos()

    imgui.SetWindowFontScale(scale)
    local ts_main = imgui.CalcTextSize(text_main)
    addTextOutlined(dl, wp, col_time, text_main, use_outline)

    local total_w = ts_main.x
    local max_h = ts_main.y

    if toBool(s.show_ms) then
        local col_ms = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(tonumber(s.ms_color_r), tonumber(s.ms_color_g), tonumber(s.ms_color_b), 1))
        local text_dot = '.'
        local text_digits = string.format('%03d', ms)

        -- dot uses the main time scale so it doesn't move/resize with the ms slider
        imgui.SetWindowFontScale(scale)
        local ts_dot = imgui.CalcTextSize(text_dot)
        local dot_y = wp.y + (ts_main.y - ts_dot.y)
        addTextOutlined(dl, imgui.ImVec2(wp.x + ts_main.x, dot_y), col_ms, text_dot, use_outline)

        -- ms digits use their own independent scale
        imgui.SetWindowFontScale(ms_scale)
        local ts_digits = imgui.CalcTextSize(text_digits)
        local digits_y = wp.y + (ts_main.y - ts_digits.y)
        addTextOutlined(dl, imgui.ImVec2(wp.x + ts_main.x + ts_dot.x, digits_y), col_ms, text_digits, use_outline)

        local ts_ms_h = math.max(ts_dot.y, ts_digits.y)
        total_w = total_w + ts_dot.x + ts_digits.x
        if ts_ms_h > max_h then max_h = ts_ms_h end
    end

    local total_h = max_h

    if toBool(s.show_date) then
        imgui.SetWindowFontScale(scale)
        local col_date = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(tonumber(s.date_color_r), tonumber(s.date_color_g), tonumber(s.date_color_b), 1))
        local text_date = u8(getStrDate(date_table))
        local ts_date = imgui.CalcTextSize(text_date)
        addTextOutlined(dl, imgui.ImVec2(wp.x, wp.y + max_h), col_date, text_date, use_outline)
        total_h = total_h + ts_date.y
        if ts_date.x > total_w then total_w = ts_date.x end
    end

    imgui.Dummy(imgui.ImVec2(total_w, total_h))
    imgui.SetWindowFontScale(1.0)

    local wpos = imgui.GetWindowPos()
    imgui.End()
    return wpos.x, wpos.y
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end
    while not sampIsLocalPlayerSpawned() do wait(0) end

    sampAddChatMessage('[TimeOnScreen] {ffffff}Скрипт загружен! Активация: {2090FF}/ctime', 0x2090FF)

    sampRegisterChatCommand('ctime', function()
        MainWindow[0] = not MainWindow[0]
    end)

    while true do wait(0) end
end

function onScriptTerminate(scr, q)
    if scr == thisScript() then saveCfg() end
end

imgui.OnInitialize(function() imgui.GetIO().IniFilename = nil; apply_theme() end)

imgui.OnFrame(function() return isSampAvailable() end, function()
    if frame_count <= 2 then frame_count = frame_count + 1 end
end)

imgui.OnFrame(
    function() return toBool(s.activate) and isSampAvailable() and not isPauseMenuActive() end,
    function(self)
        self.HideCursor = not MainWindow[0]
        if tonumber(s.time_x) < 0 then s.time_x = sizeX / 2 - 60 end
        if tonumber(s.time_y) < 0 then s.time_y = sizeY / 2 - 15 end
        local nx, ny = drawTimeWindow('cTimeWindow', tonumber(s.time_x), tonumber(s.time_y), toBool(s.locked))
        if nx ~= tonumber(s.time_x) or ny ~= tonumber(s.time_y) then
            s.time_x = nx; s.time_y = ny
            saveCfg()
        end
    end
)

local menu_open_frame = 0
imgui.OnFrame(function() return not MainWindow[0] end, function()
    menu_open_frame = 0
end)

imgui.OnFrame(function() return MainWindow[0] and not isPauseMenuActive() end, function(self)
    self.HideCursor = false
    local d = tonumber(s.custom_dpi)

    local menu_has_saved_size = tonumber(s.menu_w_saved) == 1
    if tonumber(s.menu_x) < 0 or tonumber(s.menu_y) < 0 then
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    else
        imgui.SetNextWindowPos(imgui.ImVec2(tonumber(s.menu_x), tonumber(s.menu_y)), imgui.Cond.FirstUseEver)
    end
    if menu_has_saved_size then
        imgui.SetNextWindowSize(imgui.ImVec2(tonumber(s.menu_w), tonumber(s.menu_h)), imgui.Cond.FirstUseEver)
    else
        imgui.SetNextWindowSize(imgui.ImVec2(tonumber(s.menu_w) * d, tonumber(s.menu_h) * d), imgui.Cond.FirstUseEver)
    end

    imgui.Begin(u8' TimeOnScreenV2', MainWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
    change_dpi()

    menu_open_frame = menu_open_frame + 1
    if menu_open_frame > 3 then
        local wPos = imgui.GetWindowPos()
        local wSize = imgui.GetWindowSize()
        if math.abs(wPos.x - tonumber(s.menu_x)) > 1 or math.abs(wPos.y - tonumber(s.menu_y)) > 1 or
           math.abs(wSize.x - tonumber(s.menu_w)) > 1 or math.abs(wSize.y - tonumber(s.menu_h)) > 1 then
            s.menu_x = wPos.x; s.menu_y = wPos.y
            s.menu_w = wSize.x; s.menu_h = wSize.y
            s.menu_w_saved = 1
            saveCfg()
        end
    end

    local col1_x = imgui.GetCursorPosX()
    if imgui.Checkbox(u8'Показывать время', cb_activate) then
        s.activate = cb_activate[0]
        saveCfg()
    end
    local col2_x = col1_x + imgui.GetItemRectSize().x + imgui.GetStyle().ItemSpacing.x
    imgui.SameLine(col2_x)
    if imgui.Checkbox(u8'Показывать мс', cb_show_ms) then
        s.show_ms = cb_show_ms[0]
        saveCfg()
    end

    imgui.SetCursorPosX(col1_x)
    if imgui.Checkbox(u8'Показывать дату', cb_show_date) then
        s.show_date = cb_show_date[0]
        saveCfg()
    end
    imgui.SameLine(col2_x)
    if imgui.Checkbox(u8'Заблок. положение', cb_locked) then
        s.locked = cb_locked[0]
        saveCfg()
    end
    imgui.SetCursorPosX(col1_x)
    if imgui.Checkbox(u8'Включить обводку', cb_outline) then
        s.outline = cb_outline[0]
        saveCfg()
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing()

    imgui.Text(u8'Размер времени:')
    local fs, fc = touchSlider(math.min(tonumber(s.fontsize), 35), 1, 8, 35, 'fsz')
    if fc then s.fontsize = fs; saveCfg() end

    imgui.Text(u8'Размер мс:')
    local ms_fs, ms_fc = touchSlider(math.min(tonumber(s.ms_fontsize), 23), 1, 8, 23, 'msfsz')
    if ms_fc then s.ms_fontsize = ms_fs; saveCfg() end

    imgui.Spacing()

    do
        local full_w = imgui.GetWindowContentRegionWidth()
        local title = u8'Настройка цветов'
        local title_w = imgui.CalcTextSize(title).x
        imgui.SetCursorPosX(imgui.GetCursorPosX() + (full_w - title_w) / 2)
        imgui.Text(title)
        imgui.Spacing()

        local col_w = full_w / 3
        local start_x = imgui.GetCursorPosX()

        local function centered(x0, w, text)
            local tw = imgui.CalcTextSize(text).x
            imgui.SetCursorPosX(x0 + (w - tw) / 2)
            imgui.Text(text)
        end

        local labels = {u8'Время', u8'Мс', u8'Дата'}
        for i, lbl in ipairs(labels) do
            local x0 = start_x + col_w * (i - 1)
            if i > 1 then imgui.SameLine() end
            centered(x0, col_w, lbl)
        end

        local swatches = {
            {id = 'ctcolor', arr = color_time, rk = 'color_r', gk = 'color_g', bk = 'color_b'},
            {id = 'mscolor', arr = color_ms, rk = 'ms_color_r', gk = 'ms_color_g', bk = 'ms_color_b'},
            {id = 'datecolor', arr = color_date, rk = 'date_color_r', gk = 'date_color_g', bk = 'date_color_b'},
        }
        local swatch_w = imgui.GetFrameHeight()
        for i, sw in ipairs(swatches) do
            local x0 = start_x + col_w * (i - 1)
            if i > 1 then imgui.SameLine() end
            imgui.SetCursorPosX(x0 + (col_w - swatch_w) / 2)
            rgbInputs(sw.id, sw.arr, sw.rk, sw.gk, sw.bk)
        end
    end

    imgui.End()
end)

function apply_theme()
    imgui.SwitchContext()
    local style = imgui.GetStyle(); local d = tonumber(s.custom_dpi)
    style.WindowPadding = imgui.ImVec2(8*d,8*d); style.FramePadding = imgui.ImVec2(6*d,6*d)
    style.ItemSpacing = imgui.ImVec2(6*d,6*d)
    style.WindowRounding = 8*d; style.FrameRounding = 6*d; style.GrabRounding = 6*d
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.Colors[imgui.Col.WindowBg] = imgui.ImVec4(0.10, 0.10, 0.11, 0.97)
    style.Colors[imgui.Col.FrameBg] = imgui.ImVec4(0.18, 0.18, 0.20, 1)
    style.Colors[imgui.Col.Button] = imgui.ImVec4(0.20, 0.45, 0.85, 1)
    style.Colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.25, 0.55, 0.95, 1)
    style.Colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.15, 0.35, 0.70, 1)
    style.Colors[imgui.Col.TitleBg] = imgui.ImVec4(0.20, 0.45, 0.85, 1)
    style.Colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.20, 0.45, 0.85, 1)
    style.Colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.20, 0.45, 0.85, 1)
end
