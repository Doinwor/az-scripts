script_name("Arizona Mobile Stream Chat")
script_author("Chaposcripts x BrauniStd x Modded")
script_description("Arizona Stream chat Modded")
script_version("1.5.0")

require 'lib.moonloader'
local bit = require('bit')
local ffi = require('ffi')
local sampev = require 'lib.samp.events'
local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8
local inicfg = require 'inicfg'
local directIni = 'StreamChat.ini'

local resX, resY = getScreenResolution()

local ini = inicfg.load({
    main = {
        enabled = true,
        mode = 0,
        lines = 5,
        line_space = 18,
        auto_align = false,
        sound_alert = true,
        log_enabled = false,
        fade_enabled = false,
        fade_time = 10,
        menu_width = 560,
        menu_height = 420,
        show_timestamp = false,
        text_outline = true,
        chat_bg = false,
        chat_bg_alpha = 150,
        msg_box = true,
        msg_box_gradient = true,
        msg_box_alpha = 180,
        msg_box_padding = 4,
        msg_box_shadow = true,
        msg_box_shadow_alpha = 130,
        msg_box_shadow_size = 2,
        msg_box_border = false
    },
    pos = {
        x = resX - 350,
        y = resY - 400
    },
    appearance = {
        accent_r = 0.20, accent_g = 0.45, accent_b = 0.85,
        bg_r = 0.08, bg_g = 0.09, bg_b = 0.13,
        text_r = 0.92, text_g = 0.94, text_b = 0.98,
        plate_r = 0.05, plate_g = 0.05, plate_b = 0.08,
        border_r = 0.20, border_g = 0.45, border_b = 0.85,
        rounding = 8.0,
        window_alpha = 0.98,
        font_scale = 1.0,
        scrollbar_size = 14.0,
        grab_min_size = 10.0,
        argb_enabled = false,
        argb_speed = 1.0,
        argb_menu_border = true,
        argb_chat_border = true,
        argb_chat_text = false
    }
}, directIni)
inicfg.save(ini, directIni)

local mode_str1 = u8'Ник, текст'
local mode_str2 = u8'Текст, ник'
local mode_list = ffi.new('const char *[2]', {mode_str1, mode_str2})

local current_tab = imgui.new.int(0)

local s = {
    auto_align = imgui.new.bool(ini.main.auto_align == true),
    mode = imgui.new.int(ini.main.mode or 0),
    enabled = imgui.new.bool(ini.main.enabled ~= false),
    lines = imgui.new.int(ini.main.lines or 5),
    line_space = imgui.new.int(ini.main.line_space or 18),
    pos_x = imgui.new.int(ini.pos.x or (resX - 350)),
    pos_y = imgui.new.int(ini.pos.y or (resY - 400)),
    sound_alert = imgui.new.bool(ini.main.sound_alert ~= false),
    log_enabled = imgui.new.bool(ini.main.log_enabled == true),
    fade_enabled = imgui.new.bool(ini.main.fade_enabled == true),
    fade_time = imgui.new.int(ini.main.fade_time or 10),
    menu_width = imgui.new.int(ini.main.menu_width or 560),
    menu_height = imgui.new.int(ini.main.menu_height or 420),
    show_timestamp = imgui.new.bool(ini.main.show_timestamp == true),
    text_outline = imgui.new.bool(ini.main.text_outline ~= false),
    chat_bg = imgui.new.bool(ini.main.chat_bg == true),
    chat_bg_alpha = imgui.new.int(ini.main.chat_bg_alpha or 150),
    msg_box = imgui.new.bool(ini.main.msg_box == true),
    msg_box_gradient = imgui.new.bool(ini.main.msg_box_gradient == true),
    msg_box_alpha = imgui.new.int(ini.main.msg_box_alpha or 180),
    msg_box_padding = imgui.new.int(ini.main.msg_box_padding or 4),
    msg_box_shadow = imgui.new.bool(ini.main.msg_box_shadow == true),
    msg_box_shadow_alpha = imgui.new.int(ini.main.msg_box_shadow_alpha or 130),
    msg_box_shadow_size = imgui.new.int(ini.main.msg_box_shadow_size or 2),
    msg_box_border = imgui.new.bool(ini.main.msg_box_border == true),
    argb_enabled = imgui.new.bool(ini.appearance.argb_enabled == true),
    argb_speed = imgui.new.float[1](ini.appearance.argb_speed or 1.0),
    argb_menu_border = imgui.new.bool(ini.appearance.argb_menu_border ~= false),
    argb_chat_border = imgui.new.bool(ini.appearance.argb_chat_border ~= false),
    argb_chat_text = imgui.new.bool(ini.appearance.argb_chat_text == true)
}

local pos = {
    x = ini.pos.x or (resX - 350),
    y = ini.pos.y or (resY - 400)
}

local vid_accent_col    = imgui.new.float[3](ini.appearance.accent_r or 0.20, ini.appearance.accent_g or 0.45, ini.appearance.accent_b or 0.85)
local vid_bg_col        = imgui.new.float[3](ini.appearance.bg_r or 0.08, ini.appearance.bg_g or 0.09, ini.appearance.bg_b or 0.13)
local vid_text_col      = imgui.new.float[3](ini.appearance.text_r or 0.92, ini.appearance.text_g or 0.94, ini.appearance.text_b or 0.98)
local vid_plate_col     = imgui.new.float[3](ini.appearance.plate_r or 0.05, ini.appearance.plate_g or 0.05, ini.appearance.plate_b or 0.08)
local vid_border_col    = imgui.new.float[3](ini.appearance.border_r or 0.20, ini.appearance.border_g or 0.45, ini.appearance.border_b or 0.85)
local sl_rounding       = imgui.new.float[1](ini.appearance.rounding or 8.0)
local sl_window_alpha   = imgui.new.float[1](ini.appearance.window_alpha or 0.98)
local sl_font_scale     = imgui.new.float[1](ini.appearance.font_scale or 1.0)
local sl_scrollbar_size = imgui.new.float[1](ini.appearance.scrollbar_size or 14.0)
local sl_grab_min_size  = imgui.new.float[1](ini.appearance.grab_min_size or 10.0)

local vid_presets = {
    {u8'Синий',  0.20, 0.45, 0.85},
    {u8'Зелёный',0.20, 0.75, 0.35},
    {u8'Красный',0.85, 0.20, 0.20},
    {u8'Фиолет', 0.55, 0.30, 0.90},
    {u8'Оранж',  0.90, 0.55, 0.10},
    {u8'Белый',  0.85, 0.85, 0.85},
}

local font = renderCreateFont('Arial', 10, 5)
local renderWindow = imgui.new.bool(false)
local chat = {}

local BLACKLIST_ADD_TEXT = imgui.new.char[128]('')
local BLACKLIST_ADD_NICK = imgui.new.char[128]('')
local BLACKLIST_SELECTED = 0
local BLACKLIST_NICK_SELECTED = 0

local json_file = getWorkingDirectory()..'/config/StreamChat.json'
local list = {}
local nick_list = {}

local function getRainbowRGB(speed, offset)
    offset = offset or 0
    local t = (os.clock() * (speed or 1.0) + offset) % 1.0
    local r, g, b = 0, 0, 0
    local i = math.floor(t * 6)
    local f = t * 6 - i
    local q = 1 - f
    if i % 6 == 0 then r, g, b = 1, f, 0
    elseif i % 6 == 1 then r, g, b = q, 1, 0
    elseif i % 6 == 2 then r, g, b = 0, 1, f
    elseif i % 6 == 3 then r, g, b = 0, q, 1
    elseif i % 6 == 4 then r, g, b = f, 0, 1
    elseif i % 6 == 5 then r, g, b = 1, 0, q
    end
    return r, g, b
end

function json(filePath)
    local f = {}
    function f:read()
        local file = io.open(filePath, "r")
        if not file then return {} end
        local jsonInString = file:read("*a")
        file:close()
        local jsonTable = decodeJson(jsonInString) or {}
        return jsonTable
    end
    function f:write(t)
        local file = io.open(filePath, "w")
        if file then
            file:write(encodeJson(t))
            file:flush()
            file:close()
        end
    end
    return f
end

function safeU8(str)
    if type(str) ~= 'string' then return '' end
    local ok, res = pcall(function() return u8(str) end)
    if ok then return res end
    return str
end

function save()
    ini.main.mode = s.mode[0]
    ini.main.enabled = s.enabled[0]
    ini.main.lines = s.lines[0]
    ini.main.line_space = s.line_space[0]
    ini.pos.x = s.pos_x[0]
    ini.pos.y = s.pos_y[0]
    pos.x = s.pos_x[0]
    pos.y = s.pos_y[0]
    ini.main.auto_align = s.auto_align[0]
    ini.main.sound_alert = s.sound_alert[0]
    ini.main.log_enabled = s.log_enabled[0]
    ini.main.fade_enabled = s.fade_enabled[0]
    ini.main.fade_time = s.fade_time[0]
    ini.main.menu_width = s.menu_width[0]
    ini.main.menu_height = s.menu_height[0]
    ini.main.show_timestamp = s.show_timestamp[0]
    ini.main.text_outline = s.text_outline[0]
    ini.main.chat_bg = s.chat_bg[0]
    ini.main.chat_bg_alpha = s.chat_bg_alpha[0]
    ini.main.msg_box = s.msg_box[0]
    ini.main.msg_box_gradient = s.msg_box_gradient[0]
    ini.main.msg_box_alpha = s.msg_box_alpha[0]
    ini.main.msg_box_padding = s.msg_box_padding[0]
    ini.main.msg_box_shadow = s.msg_box_shadow[0]
    ini.main.msg_box_shadow_alpha = s.msg_box_shadow_alpha[0]
    ini.main.msg_box_shadow_size = s.msg_box_shadow_size[0]
    ini.main.msg_box_border = s.msg_box_border[0]

    ini.appearance.accent_r = vid_accent_col[0]
    ini.appearance.accent_g = vid_accent_col[1]
    ini.appearance.accent_b = vid_accent_col[2]
    ini.appearance.bg_r = vid_bg_col[0]
    ini.appearance.bg_g = vid_bg_col[1]
    ini.appearance.bg_b = vid_bg_col[2]
    ini.appearance.text_r = vid_text_col[0]
    ini.appearance.text_g = vid_text_col[1]
    ini.appearance.text_b = vid_text_col[2]
    ini.appearance.plate_r = vid_plate_col[0]
    ini.appearance.plate_g = vid_plate_col[1]
    ini.appearance.plate_b = vid_plate_col[2]
    ini.appearance.border_r = vid_border_col[0]
    ini.appearance.border_g = vid_border_col[1]
    ini.appearance.border_b = vid_border_col[2]
    ini.appearance.rounding = sl_rounding[0]
    ini.appearance.window_alpha = sl_window_alpha[0]
    ini.appearance.font_scale = sl_font_scale[0]
    ini.appearance.scrollbar_size = sl_scrollbar_size[0]
    ini.appearance.grab_min_size = sl_grab_min_size[0]
    ini.appearance.argb_enabled = s.argb_enabled[0]
    ini.appearance.argb_speed = s.argb_speed[0]
    ini.appearance.argb_menu_border = s.argb_menu_border[0]
    ini.appearance.argb_chat_border = s.argb_chat_border[0]
    ini.appearance.argb_chat_text = s.argb_chat_text[0]

    json(json_file):write({words = list, nicks = nick_list})
    inicfg.save(ini, directIni)
end

function save_appearance()
    stream_chat_theme()
    save()
end

function isBlacklisted(text, playerNick, playerId)
    for i = 1, #list do
        if list[i] then
            local t = string.rlower(list[i])
            if string.rlower(text):find(t, 1, true) then return true end
        end
    end
    for i = 1, #nick_list do
        if nick_list[i] then
            local target = string.rlower(nick_list[i])
            if string.rlower(playerNick):find(target, 1, true) or tostring(playerId) == target then return true end
        end
    end
    return false
end

function sampev.onPlayerChatBubble(playerId, color, dist, duration, text)
    if not s.enabled[0] then return end
    
    local playerNick = sampGetPlayerNickname(playerId) or ""
    if isBlacklisted(text, playerNick, playerId) then return end
    
    local myId = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
    local myNick = sampGetPlayerNickname(myId) or ""
    
    if myNick ~= "" then
        if string.rlower(text):find(string.rlower(myNick), 1, true) or (myId and text:find(tostring(myId), 1, true)) then
            if s.sound_alert[0] then addOneOffSound(0, 0, 0, 1052) end
        end
    end

    local pColorHex = string.sub(bit.tohex(sampGetPlayerColor(playerId) or 0xFFFFFF, 8), 3, 8)
    local msgColorHex = string.sub(bit.tohex(color or 0xFFFFFF, 8), 3, 8)

    local chatEntry = {
        name = '{'..pColorHex..'}'..playerNick..' ['..playerId..']', 
        text = '{'..msgColorHex..'}'..text,
        time = os.time(),
        time_str = os.date('[%H:%M:%S] ', os.time()),
        spawn_time = os.clock(),
        fading_out = false
    }
    
    table.insert(chat, chatEntry)
    while #chat > 50 do table.remove(chat, 1) end
    
    if s.log_enabled[0] then
        local logFile = io.open(getWorkingDirectory()..'/config/StreamChat_history.log', 'a+')
        if logFile then
            logFile:write(os.date('[%H:%M:%S] ')..playerNick..'['..playerId..']: '..text..'\n')
            logFile:close()
        end
    end
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil

    local cyrillicFontCandidates = {
        '/system/fonts/Roboto-Regular.ttf',
        '/system/fonts/DroidSans.ttf',
        '/system/fonts/NotoSans-Regular.ttf',
        getWorkingDirectory()..'/resource/fonts/Roboto-Regular.ttf',
        getWorkingDirectory()..'/resource/Roboto-Regular.ttf',
    }
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    for _, path in ipairs(cyrillicFontCandidates) do
        if doesFileExist(path) then
            imgui.GetIO().Fonts:AddFontFromFileTTF(path, 16, nil, glyph_ranges)
            break
        end
    end

    stream_chat_theme()
end)

local function drawNavButton(id, label, targetTab)
    local isSelected = (current_tab[0] == targetTab)

    local base_r, base_g, base_b   = vid_bg_col[0]+0.04, vid_bg_col[1]+0.05, vid_bg_col[2]+0.07
    local base_hr, base_hg, base_hb = vid_bg_col[0]+0.08, vid_bg_col[1]+0.10, vid_bg_col[2]+0.14
    local acc_r, acc_g, acc_b   = vid_accent_col[0], vid_accent_col[1], vid_accent_col[2]
    local acc_hr = math.min(acc_r+0.05, 1); local acc_hg = math.min(acc_g+0.05, 1); local acc_hb = math.min(acc_b+0.05, 1)

    local btn_r = isSelected and acc_r or base_r
    local btn_g = isSelected and acc_g or base_g
    local btn_b = isSelected and acc_b or base_b
    local hov_r = isSelected and acc_hr or base_hr
    local hov_g = isSelected and acc_hg or base_hg
    local hov_b = isSelected and acc_hb or base_hb

    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(btn_r, btn_g, btn_b, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(hov_r, hov_g, hov_b, 1.00))
    if imgui.Button(u8(label)..'##'..id, imgui.ImVec2(130, 32)) then
        current_tab[0] = targetTab
    end
    imgui.PopStyleColor(2)
end

local newFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(player)
        if s.argb_enabled[0] then
            local r, g, b = getRainbowRGB(s.argb_speed[0], 0.0)
            if s.argb_menu_border[0] then
                vid_accent_col[0], vid_accent_col[1], vid_accent_col[2] = r, g, b
            end
        end

        stream_chat_theme()

        local sizeX, sizeY = s.menu_width[0], s.menu_height[0]
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.Always)
        imgui.Begin(u8'Stream Chat || Настройки', renderWindow, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
       
        imgui.BeginChild('##SidebarNav', imgui.ImVec2(140, sizeY - 60), true)
        drawNavButton('gen', 'Основные', 0)
        imgui.Spacing()
        drawNavButton('black', 'Черный список', 1)
        imgui.Spacing()
        drawNavButton('time', 'Таймер строк', 2)
        imgui.Spacing()
        drawNavButton('snd', 'Звуки', 3)
        imgui.Spacing()
        drawNavButton('log', 'Логирование', 4)
        imgui.Spacing()
        drawNavButton('vid', 'Вид', 5)
        imgui.Spacing()
        drawNavButton('about', 'О скрипте', 6)
        imgui.EndChild()

        imgui.SameLine()

        imgui.BeginChild('##MainContentArea', imgui.ImVec2(sizeX - 170, sizeY - 60), true)

        local avail_w = imgui.GetContentRegionAvail().x

        if current_tab[0] == 0 then
            imgui.TextDisabled(u8"Основные настройки отображения:")
            if imgui.Checkbox(u8'Включить чат в зоне стрима', s.enabled) then save() end
            imgui.Spacing()
            
            imgui.TextDisabled(u8"Параметры вывода:")
            imgui.PushItemWidth(avail_w)
            if imgui.SliderInt(u8'Кол-во строк', s.lines, 1, 30) then save() end
            if imgui.SliderInt(u8'Отступ строк', s.line_space, 10, 50) then save() end
            if imgui.SliderInt(u8'Позиция X', s.pos_x, 0, resX) then save() end
            if imgui.SliderInt(u8'Позиция Y', s.pos_y, 0, resY) then save() end
            if imgui.Combo(u8'Формат', s.mode, mode_list, 2) then save() end
            imgui.PopItemWidth()
            imgui.Spacing()
            if imgui.Checkbox(u8'Авто-выравнивание текста', s.auto_align) then save() end
            if imgui.Checkbox(u8'Показывать время (Таймстамп)', s.show_timestamp) then save() end
            if imgui.Checkbox(u8'Обводка текста (Тень)', s.text_outline) then save() end
            
            imgui.Spacing()
            if imgui.Checkbox(u8'Общий статичный фон под чатом', s.chat_bg) then save() end
            if s.chat_bg[0] then
                imgui.PushItemWidth(avail_w)
                if imgui.SliderInt(u8'Прозрачность общего фона', s.chat_bg_alpha, 0, 255) then save() end
                imgui.PopItemWidth()
            end

        elseif current_tab[0] == 1 then
            imgui.TextDisabled(u8"Черный список слов:")
            imgui.PushItemWidth(avail_w - 130)
            imgui.InputText(u8'##AddWordInput', BLACKLIST_ADD_TEXT, 128)
            imgui.PopItemWidth()
            imgui.SameLine()
            if imgui.Button(u8'Добавить слово', imgui.ImVec2(120, 24)) then
                local tStr = ffi.string(BLACKLIST_ADD_TEXT)
                if tStr ~= "" then
                    table.insert(list, tStr)
                    save()
                    BLACKLIST_ADD_TEXT[0] = 0
                end
            end
            
            imgui.BeginChild('##BlacklistWordsChild', imgui.ImVec2(avail_w, 80), true)
            for i = 1, #list do
                if list[i] then
                    if imgui.Selectable(safeU8(list[i])..'##w_'..i, BLACKLIST_SELECTED == i) then BLACKLIST_SELECTED = i end
                end
            end
            imgui.EndChild()
            if imgui.Button(u8'Удалить слово', imgui.ImVec2(120, 22)) then
                if BLACKLIST_SELECTED > 0 and list[BLACKLIST_SELECTED] then
                    table.remove(list, BLACKLIST_SELECTED)
                    BLACKLIST_SELECTED = 0
                    save()
                end
            end

            imgui.Separator()
            imgui.TextDisabled(u8"Черный список Ников / ID:")
            imgui.PushItemWidth(avail_w - 130)
            imgui.InputText(u8'##AddNickInput', BLACKLIST_ADD_NICK, 128)
            imgui.PopItemWidth()
            imgui.SameLine()
            if imgui.Button(u8'Добавить Ник/ID', imgui.ImVec2(120, 24)) then
                local nStr = ffi.string(BLACKLIST_ADD_NICK)
                if nStr ~= "" then
                    table.insert(nick_list, nStr)
                    save()
                    BLACKLIST_ADD_NICK[0] = 0
                end
            end
            imgui.BeginChild('##BlacklistNicksChild', imgui.ImVec2(avail_w, 80), true)
            for i = 1, #nick_list do
                if nick_list[i] then
                    if imgui.Selectable(safeU8(nick_list[i])..'##n_'..i, BLACKLIST_NICK_SELECTED == i) then BLACKLIST_NICK_SELECTED = i end
                end
            end
            imgui.EndChild()
            if imgui.Button(u8'Удалить Ник/ID', imgui.ImVec2(120, 22)) then
                if BLACKLIST_NICK_SELECTED > 0 and nick_list[BLACKLIST_NICK_SELECTED] then
                    table.remove(nick_list, BLACKLIST_NICK_SELECTED)
                    BLACKLIST_NICK_SELECTED = 0
                    save()
                end
            end

        elseif current_tab[0] == 2 then
            imgui.TextDisabled(u8"Время жизни сообщений:")
            imgui.Spacing()
            if imgui.Checkbox(u8'Авто-удаление сообщений по таймеру', s.fade_enabled) then save() end
            imgui.PushItemWidth(avail_w)
            if imgui.SliderInt(u8'Секунд на экране', s.fade_time, 3, 60) then save() end
            imgui.PopItemWidth()

        elseif current_tab[0] == 3 then
            imgui.TextDisabled(u8"Звуковые оповещения:")
            imgui.Spacing()
            if imgui.Checkbox(u8'Звук при упоминании вашего Ника или ID', s.sound_alert) then save() end

        elseif current_tab[0] == 4 then
            imgui.TextDisabled(u8"Сохранение истории чата:")
            imgui.Spacing()
            if imgui.Checkbox(u8'Записывать сообщения в StreamChat_history.log', s.log_enabled) then save() end
            imgui.Spacing()
            if imgui.Button(u8'Очистить историю чата на экране', imgui.ImVec2(220, 28)) then
                chat = {}
            end

        elseif current_tab[0] == 5 then
            imgui.TextColored(imgui.ImVec4(vid_accent_col[0], vid_accent_col[1], vid_accent_col[2], 1), u8' ARGB (RGB) ПОДСВЕТКА')
            imgui.Separator(); imgui.Spacing()

            if imgui.Checkbox(u8'Включить ARGB переливание цветов(для геев)', s.argb_enabled) then save() end
            if s.argb_enabled[0] then
                imgui.PushItemWidth(avail_w)
                if imgui.SliderFloat(u8'Скорость переливания', s.argb_speed, 0.1, 5.0, '%.1f') then save() end
                imgui.PopItemWidth()
                if imgui.Checkbox(u8'ARGB подсветка бордера и элементов меню', s.argb_menu_border) then save() end
                if imgui.Checkbox(u8'ARGB подсветка бордера плашек чата', s.argb_chat_border) then save() end
                if imgui.Checkbox(u8'ARGB подсветка текста чата', s.argb_chat_text) then save() end
            end
            imgui.Spacing(); imgui.Separator(); imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(vid_accent_col[0], vid_accent_col[1], vid_accent_col[2], 1), u8' СТИЛЬ И НАСТРОЙКА ПЛАШЕК')
            imgui.Separator(); imgui.Spacing()

            if imgui.Checkbox(u8'Включить стильные плашки под сообщениями', s.msg_box) then save() end
            if s.msg_box[0] then
                imgui.PushItemWidth(avail_w)
                imgui.TextDisabled(u8' Цвет фона плашки:')
                if imgui.ColorEdit3('##vid_plate', vid_plate_col) then save_appearance() end
                
                if imgui.SliderInt(u8'Прозрачность плашки', s.msg_box_alpha, 10, 255) then save() end
                if imgui.SliderInt(u8'Отступ плашки (высота)', s.msg_box_padding, 0, 10) then save() end
                imgui.Spacing()

                if imgui.Checkbox(u8'Плавный градиент', s.msg_box_gradient) then save() end
                
                if imgui.Checkbox(u8'Добавить тень под плашку', s.msg_box_shadow) then save() end
                if s.msg_box_shadow[0] then
                    if imgui.SliderInt(u8'Прозрачность тени', s.msg_box_shadow_alpha, 10, 255) then save() end
                    if imgui.SliderInt(u8'Смещение тени (размер)', s.msg_box_shadow_size, 1, 6) then save() end
                end

                if imgui.Checkbox(u8'Включить цветную обводку плашки (Border)', s.msg_box_border) then save() end
                if s.msg_box_border[0] then
                    imgui.TextDisabled(u8' Цвет обводки:')
                    if imgui.ColorEdit3('##vid_border', vid_border_col) then save_appearance() end
                end
                imgui.PopItemWidth()
            end
            imgui.Spacing(); imgui.Separator(); imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(vid_accent_col[0], vid_accent_col[1], vid_accent_col[2], 1), u8' РАЗМЕР ОКНА')
            imgui.Separator(); imgui.Spacing()

            imgui.TextDisabled(u8' Размеры меню:')
            imgui.PushItemWidth(avail_w)
            if imgui.SliderInt(u8'Ширина меню', s.menu_width, 400, 1200) then save() end
            if imgui.SliderInt(u8'Высота меню', s.menu_height, 350, 900) then save() end
            imgui.PopItemWidth(); imgui.Spacing()

            imgui.Separator(); imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(vid_accent_col[0], vid_accent_col[1], vid_accent_col[2], 1), u8' ЦВЕТА ИНТЕРФЕЙСА')
            imgui.Separator(); imgui.Spacing()

            imgui.TextDisabled(u8' Акцентный цвет:')
            imgui.PushItemWidth(avail_w)
            if imgui.ColorEdit3('##vid_accent', vid_accent_col) then save_appearance() end
            imgui.PopItemWidth(); imgui.Spacing()

            imgui.TextDisabled(u8' Цвет фона окна:')
            imgui.PushItemWidth(avail_w)
            if imgui.ColorEdit3('##vid_bg', vid_bg_col) then save_appearance() end
            imgui.PopItemWidth(); imgui.Spacing()

            imgui.TextDisabled(u8' Цвет текста:')
            imgui.PushItemWidth(avail_w)
            if imgui.ColorEdit3('##vid_text', vid_text_col) then save_appearance() end
            imgui.PopItemWidth(); imgui.Spacing()

            imgui.Separator(); imgui.Spacing()
            imgui.TextDisabled(u8' Готовые цветовые акценты:')
            imgui.Spacing()
            local _pw = (avail_w - 5 * (#vid_presets - 1)) / #vid_presets
            for pi, pr in ipairs(vid_presets) do
                if pi > 1 then imgui.SameLine(0, 5) end
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(pr[2]*0.5, pr[3]*0.5, pr[4]*0.5, 1))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(pr[2]*0.7, pr[3]*0.7, pr[4]*0.7, 1))
                imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(pr[2], pr[3], pr[4], 1))
                if imgui.Button(pr[1]..'##vidpreset'..pi, imgui.ImVec2(_pw, 24)) then
                    vid_accent_col[0] = pr[2]; vid_accent_col[1] = pr[3]; vid_accent_col[2] = pr[4]
                    save_appearance()
                end
                imgui.PopStyleColor(3)
            end
            imgui.Spacing()

            imgui.Separator(); imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(vid_accent_col[0], vid_accent_col[1], vid_accent_col[2], 1), u8' ПАРАМЕТРЫ И ИНТЕРФЕЙС')
            imgui.Separator(); imgui.Spacing()

            imgui.PushItemWidth(avail_w)
            imgui.TextDisabled(u8' Скругление углов:')
            if imgui.SliderFloat('##vid_rounding', sl_rounding, 0.0, 16.0, '%.1f') then save_appearance() end

            imgui.TextDisabled(u8' Прозрачность окна:')
            if imgui.SliderFloat('##vid_alpha', sl_window_alpha, 0.3, 1.0, '%.2f') then save_appearance() end

            imgui.TextDisabled(u8' Размер шрифта:')
            if imgui.SliderFloat('##vid_font', sl_font_scale, 0.7, 1.5, '%.2f') then save_appearance() end

            imgui.TextDisabled(u8' Ширина скроллбара:')
            if imgui.SliderFloat('##vid_scrollsize', sl_scrollbar_size, 6.0, 24.0, '%.1f') then save_appearance() end

            imgui.TextDisabled(u8' Мин. длина ползунка скролла:')
            if imgui.SliderFloat('##vid_grabminsize', sl_grab_min_size, 5.0, 30.0, '%.1f') then save_appearance() end
            imgui.PopItemWidth()
            imgui.Spacing()

            imgui.Separator(); imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.45, 0.12, 0.10, 1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.16, 0.12, 1))
            if imgui.Button(u8'Сбросить дизайн', imgui.ImVec2(avail_w, 28)) then
                vid_accent_col[0], vid_accent_col[1], vid_accent_col[2] = 0.20, 0.45, 0.85
                vid_bg_col[0], vid_bg_col[1], vid_bg_col[2] = 0.08, 0.09, 0.13
                vid_text_col[0], vid_text_col[1], vid_text_col[2] = 0.92, 0.94, 0.98
                vid_plate_col[0], vid_plate_col[1], vid_plate_col[2] = 0.05, 0.05, 0.08
                vid_border_col[0], vid_border_col[1], vid_border_col[2] = 0.20, 0.45, 0.85
                sl_rounding[0] = 8.0
                sl_window_alpha[0] = 0.98
                sl_font_scale[0] = 1.0
                sl_scrollbar_size[0] = 14.0
                sl_grab_min_size[0] = 10.0
                s.argb_enabled[0] = false
                s.argb_speed[0] = 1.0
                s.argb_menu_border[0] = true
                s.argb_chat_border[0] = true
                s.argb_chat_text[0] = false
                save_appearance()
            end
            imgui.PopStyleColor(2)

        elseif current_tab[0] == 6 then
            imgui.TextColored(imgui.ImVec4(vid_accent_col[0], vid_accent_col[1], vid_accent_col[2], 1), u8' О СКРИПТЕ')
            imgui.Separator(); imgui.Spacing()

            imgui.TextDisabled(u8'Название:')
            imgui.Text(u8'Arizona Mobile Stream Chat')
            imgui.Spacing()

            imgui.TextDisabled(u8'Версия скрипта:')
            imgui.Text(u8'1.5.0')
            imgui.Spacing()

            imgui.TextDisabled(u8'Авторы:')
            imgui.Text(u8'Оригинал: chapo')
            imgui.Text(u8'Модификация и поддержка: BrauniStd')
            imgui.Spacing()

            imgui.Separator(); imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(vid_accent_col[0], vid_accent_col[1], vid_accent_col[2], 1), u8' ИЗМЕНЕНИЯ')
            imgui.Separator(); imgui.Spacing()

            imgui.BeginChild('##ChangelogChild', imgui.ImVec2(avail_w, sizeY - 240), true)

            imgui.TextColored(imgui.ImVec4(vid_accent_col[0], vid_accent_col[1], vid_accent_col[2], 1), u8'глобальная обнова с редизайном и фиксами! v1.5.0')
            imgui.BulletText(u8'Добавлена лгбт подсветка для меню(для геев), бордеров плашек и текста')
            imgui.BulletText(u8'Исправлены баги неравномерного затухания и появления меню')
            imgui.BulletText(u8'Исправлен баг перекрытия интерфейса скроллбаром во всех вкладках')
            imgui.BulletText(u8'Исправлен баг динамического редактирования размеров скроллбара')
            imgui.BulletText(u8'Полностью переработаны плашки: теперь они гладкие')
            imgui.BulletText(u8'Добавлена палитра для выбора цвета плашки и цвета её обводки')
            imgui.BulletText(u8'Добавлены тени с регулировкой прозрачности и размера')
            imgui.Spacing(); imgui.Separator(); imgui.Spacing()

            imgui.EndChild()
        end

        imgui.EndChild()
        
        imgui.SetCursorPos(imgui.ImVec2(10, sizeY - 25))
        imgui.Separator()
        local CREDITS_TEXT = 'by chapo | Fix by BrauniStd | Modified Stream Chat v1.5.0'
        imgui.SetCursorPosX(sizeX / 2 - imgui.CalcTextSize(CREDITS_TEXT).x / 2)
        imgui.TextDisabled(CREDITS_TEXT) 
        
        imgui.End()
    end
)

function renderFontDrawTextAutoAlign(font, text, x, y, color, flag)
    local sw, sh = getScreenResolution()
    if x <= sw/3 then renderFontDrawText(font, text, x, y, color, flag)
    elseif x <= sw/1.5 then renderFontDrawText(font, text, x - renderGetFontDrawTextLength(font, text) / 2, y, color, flag)
    else renderFontDrawText(font, text, x - renderGetFontDrawTextLength(font, text), y, color, flag)
    end
end


function drawMessagePlate(x, y, w, h, base_alpha, is_gradient, auto_align_mode)
    local sw, sh = getScreenResolution()
    local draw_x = x - 4
    if auto_align_mode then
        if x > sw/1.5 then draw_x = x - w - 4
        elseif x > sw/3 then draw_x = x - w/2 - 4 end
    end
    
    local pad = s.msg_box_padding[0]
    local box_y = y - pad
    local box_h = h + pad * 2
    local box_w = w + 8

    local pr = math.floor(vid_plate_col[0] * 255)
    local pg = math.floor(vid_plate_col[1] * 255)
    local pb = math.floor(vid_plate_col[2] * 255)

    if s.msg_box_shadow[0] then
        local sh_size = s.msg_box_shadow_size[0]
        local sh_alpha = math.floor((s.msg_box_shadow_alpha[0] / 255) * base_alpha)
        if sh_alpha > 0 then
            local sh_col = bit.bor(bit.lshift(sh_alpha, 24), 0x000000)
            renderDrawBox(draw_x + sh_size, box_y + sh_size, box_w, box_h, sh_col)
        end
    end

    if not is_gradient then
        local col = bit.bor(bit.lshift(base_alpha, 24), bit.lshift(pr, 16), bit.lshift(pg, 8), pb)
        renderDrawBox(draw_x + 1, box_y, box_w - 2, box_h, col)
        renderDrawBox(draw_x, box_y + 1, box_w, box_h - 2, col)
    else
        local steps = 8
        local step_w = box_w / steps
        for i = 0, steps - 1 do
            local progress = i / (steps - 1)
            local fade = math.cos(progress * math.pi * 0.5) 
            local step_alpha = math.floor(base_alpha * fade)
            if step_alpha > 0 then
                local col = bit.bor(bit.lshift(step_alpha, 24), bit.lshift(pr, 16), bit.lshift(pg, 8), pb)
                renderDrawBox(draw_x + i * step_w, box_y, math.ceil(step_w) + 1, box_h, col)
            end
        end
    end

    if s.msg_box_border[0] then
        local br, bg, bb
        if s.argb_enabled[0] and s.argb_chat_border[0] then
            local ar, ag, ab = getRainbowRGB(s.argb_speed[0], 0.33)
            br, bg, bb = math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255)
        else
            br = math.floor(vid_border_col[0] * 255)
            bg = math.floor(vid_border_col[1] * 255)
            bb = math.floor(vid_border_col[2] * 255)
        end
        local border_col = bit.bor(bit.lshift(base_alpha, 24), bit.lshift(br, 16), bit.lshift(bg, 8), bb)
        
        renderDrawBox(draw_x - 1, box_y - 1, box_w + 2, 1, border_col)
        renderDrawBox(draw_x - 1, box_y + box_h, box_w + 2, 1, border_col)
        renderDrawBox(draw_x - 1, box_y, 1, box_h, border_col)
        renderDrawBox(draw_x + box_w, box_y, 1, box_h, border_col)
    end
end

function main()
    while not isSampAvailable() do wait(0) end
    
    if not doesFileExist(json_file) then
        local defaultData = {
            words = {'Отошел', 'Смотрит на', 'Кашляет', 'Кашлянул', 'На часы', 'Вышел', 'рации', 'карман', 'кушает', 'улицу'},
            nicks = {}
        }
        json(json_file):write(defaultData)
    end
    
    local loadedData = json(json_file):read()
    if loadedData.words then list = loadedData.words else list = loadedData or {} end
    if loadedData.nicks then nick_list = loadedData.nicks else nick_list = {} end

    sampRegisterChatCommand('strc', function()
        renderWindow[0] = not renderWindow[0]
    end)
    
    local last_clock = os.clock()
    while true do
        wait(0)
        
        local cur_clock = os.clock()
        local dt = cur_clock - last_clock
        if dt <= 0 then dt = 0.001 end
        if dt > 0.1 then dt = 0.1 end
        last_clock = cur_clock

        if s.enabled[0] then
            local x = pos.x
            local max_visible_lines = s.lines[0]
            local line_height = s.line_space[0]
            local title_y = pos.y

            local active_count = 0
            for i = 1, #chat do
                if not chat[i].fading_out then
                    active_count = active_count + 1
                end
            end

            if s.fade_enabled[0] then
                for i = 1, #chat do
                    local entry = chat[i]
                    if not entry.fading_out then
                        if (cur_clock - entry.spawn_time) >= s.fade_time[0] then
                            entry.fading_out = true
                            entry.fade_out_start = cur_clock
                        end
                    end
                end
            end

            local current_active_idx = 0
            for i = 1, #chat do
                local entry = chat[i]
                if not entry.fading_out then
                    current_active_idx = current_active_idx + 1
                    local slot = max_visible_lines - (active_count - current_active_idx)
                    if slot < 1 then
                        entry.fading_out = true
                        entry.fade_out_start = cur_clock
                        entry.target_slot = 0
                    else
                        entry.target_slot = slot
                    end
                else
                    entry.target_slot = (entry.target_slot or 1) - dt * 2.0
                end
            end

            local font_flag_title = s.text_outline[0] and 0x90000000 or 0
            if s.auto_align[0] then
                renderFontDrawTextAutoAlign(font, 'Чат в зоне стрима:', x, title_y, 0x80FFFFFF, font_flag_title)
            else
                renderFontDrawText(font, 'Чат в зоне стрима:', x, title_y, 0x80FFFFFF, font_flag_title)
            end

            if s.chat_bg[0] then
                local box_width = 450
                local box_height = (max_visible_lines + 1) * line_height + 10
                renderDrawBox(x - 10, title_y - 5, box_width, box_height, bit.bor(bit.lshift(s.chat_bg_alpha[0], 24), 0x000000))
            end

            local tr, tg, tb
            if s.argb_enabled[0] and s.argb_chat_text[0] then
                tr, tg, tb = getRainbowRGB(s.argb_speed[0], 0.0)
            end

            for i = #chat, 1, -1 do
                local entry = chat[i]
                if entry then
                    local target_y = title_y + (entry.target_slot or 1) * line_height

                    if not entry.anim_y then
                        entry.anim_y = target_y + 20
                    end

                    local lerp_factor = 1.0 - math.exp(-14.0 * dt)
                    entry.anim_y = entry.anim_y + (target_y - entry.anim_y) * lerp_factor

                    local age = cur_clock - entry.spawn_time
                    local alpha_in = math.min(1.0, math.max(0.0, age / 0.35))

                    local alpha_out = 1.0
                    if entry.fading_out then
                        local out_age = cur_clock - (entry.fade_out_start or cur_clock)
                        alpha_out = 1.0 - math.min(1.0, math.max(0.0, out_age / 0.5))
                        
                        entry.anim_y = entry.anim_y - (dt * 25.0)

                        if alpha_out <= 0 then
                            entry.to_delete = true
                        end
                    end

                    local final_alpha = alpha_in * alpha_out
                    local alpha_byte = math.floor(final_alpha * 255)

                    if alpha_byte > 0 and not entry.to_delete then
                        local cur_draw_y = entry.anim_y
                        local text_color_argb
                        if s.argb_enabled[0] and s.argb_chat_text[0] then
                            local ir, ig, ib = math.floor(tr * 255), math.floor(tg * 255), math.floor(tb * 255)
                            text_color_argb = bit.bor(bit.lshift(alpha_byte, 24), bit.lshift(ir, 16), bit.lshift(ig, 8), ib)
                        else
                            text_color_argb = bit.bor(bit.lshift(alpha_byte, 24), 0x00FFFFFF)
                        end

                        local shadow_alpha = math.floor((s.text_outline[0] and 0x90 or 0) * final_alpha)
                        local current_font_flag = bit.lshift(shadow_alpha, 24)

                        local time_prefix = s.show_timestamp[0] and entry.time_str or ""
                        local prefix_text = ""
                        local suffix_text = ""

                        if s.mode[0] == 0 then
                            prefix_text = time_prefix
                            suffix_text = entry.name .. ': ' .. entry.text
                        else
                            prefix_text = time_prefix .. entry.text .. ' :'
                            suffix_text = entry.name
                        end

                        local full_text = prefix_text .. suffix_text
                        
                        if s.msg_box[0] then
                            local text_len = renderGetFontDrawTextLength(font, full_text)
                            local font_h = renderGetFontDrawHeight(font)
                            local plate_alpha = math.floor((s.msg_box_alpha[0] / 255) * alpha_byte)
                            if plate_alpha > 0 then
                                drawMessagePlate(x, cur_draw_y, text_len, font_h, plate_alpha, s.msg_box_gradient[0], s.auto_align[0])
                            end
                        end

                        if s.auto_align[0] then
                            renderFontDrawTextAutoAlign(font, full_text, x, cur_draw_y, text_color_argb, current_font_flag)
                        else
                            renderFontDrawText(font, full_text, x, cur_draw_y, text_color_argb, current_font_flag)
                        end
                    end
                end
            end

            for i = #chat, 1, -1 do
                if chat[i] and chat[i].to_delete then
                    table.remove(chat, i)
                end
            end
        end
    end
end

function stream_chat_theme()
    local ar, ag, ab = vid_accent_col[0], vid_accent_col[1], vid_accent_col[2]
    local br, bgc, bb = vid_bg_col[0], vid_bg_col[1], vid_bg_col[2]
    local tr, tg, tb = vid_text_col[0], vid_text_col[1], vid_text_col[2]
    local alpha = sl_window_alpha[0]
    local clamp = function(v) return math.max(0, math.min(1, v)) end

    local stl = imgui.GetStyle()
    stl.WindowRounding        = sl_rounding[0]
    stl.ChildRounding         = sl_rounding[0] * 0.75
    stl.FrameRounding         = sl_rounding[0] * 0.6
    stl.ScrollbarSize         = sl_scrollbar_size[0]
    stl.GrabMinSize           = sl_grab_min_size[0]
    stl.ItemSpacing           = imgui.ImVec2(8, 6)
    stl.FramePadding          = imgui.ImVec2(8, 6)
    stl.WindowPadding         = imgui.ImVec2(10, 10)
    stl.WindowTitleAlign      = imgui.ImVec2(0.5, 0.5)

    local clr = stl.Colors
    clr[imgui.Col.WindowBg]             = imgui.ImVec4(br, bgc, bb, alpha)
    clr[imgui.Col.ChildBg]              = imgui.ImVec4(clamp(br+0.04), clamp(bgc+0.05), clamp(bb+0.07), 1.00)
    clr[imgui.Col.PopupBg]              = imgui.ImVec4(clamp(br+0.01), clamp(bgc+0.01), clamp(bb+0.02), 1.00)
    clr[imgui.Col.Border]               = imgui.ImVec4(ar, ag, ab, 0.70)
    clr[imgui.Col.Text]                 = imgui.ImVec4(tr, tg, tb, 1.00)
    clr[imgui.Col.TextDisabled]         = imgui.ImVec4(clamp(tr*0.55), clamp(tg*0.58), clamp(tb*0.68), 1.00)
    clr[imgui.Col.FrameBg]              = imgui.ImVec4(clamp(br+0.07), clamp(bgc+0.09), clamp(bb+0.13), 1.00)
    clr[imgui.Col.FrameBgHovered]       = imgui.ImVec4(clamp(br+0.12), clamp(bgc+0.15), clamp(bb+0.21), 1.00)
    clr[imgui.Col.FrameBgActive]        = imgui.ImVec4(clamp(br+0.17), clamp(bgc+0.21), clamp(bb+0.29), 1.00)
    clr[imgui.Col.TitleBg]              = imgui.ImVec4(clamp(br+0.02), clamp(bgc+0.03), clamp(bb+0.05), 1.00)
    clr[imgui.Col.TitleBgActive]        = imgui.ImVec4(clamp(br+0.05), clamp(bgc+0.06), clamp(bb+0.09), 1.00)
    clr[imgui.Col.Button]               = imgui.ImVec4(clamp(br+0.08), clamp(bgc+0.11), clamp(bb+0.16), 1.00)
    clr[imgui.Col.ButtonHovered]        = imgui.ImVec4(clamp(br+0.14), clamp(bgc+0.19), clamp(bb+0.27), 1.00)
    clr[imgui.Col.ButtonActive]         = imgui.ImVec4(ar, ag, ab, 1.00)
    clr[imgui.Col.SliderGrab]           = imgui.ImVec4(clamp(ar+0.05), clamp(ag+0.05), clamp(ab+0.05), 1.00)
    clr[imgui.Col.SliderGrabActive]     = imgui.ImVec4(clamp(ar+0.15), clamp(ag+0.15), clamp(ab+0.15), 1.00)
    clr[imgui.Col.CheckMark]            = imgui.ImVec4(clamp(ar+0.10), clamp(ag+0.20), clamp(ab+0.15), 1.00)
    clr[imgui.Col.Header]               = imgui.ImVec4(clamp(br+0.10), clamp(bgc+0.13), clamp(bb+0.19), 1.00)
    clr[imgui.Col.HeaderHovered]        = imgui.ImVec4(clamp(br+0.17), clamp(bgc+0.21), clamp(bb+0.29), 1.00)
    clr[imgui.Col.HeaderActive]         = imgui.ImVec4(ar, ag, ab, 1.00)
    clr[imgui.Col.ScrollbarBg]          = imgui.ImVec4(br, bgc, bb, 0.50)
    clr[imgui.Col.ScrollbarGrab]        = imgui.ImVec4(clamp(br+0.12), clamp(bgc+0.16), clamp(bb+0.22), 1.00)
    clr[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(clamp(br+0.20), clamp(bgc+0.26), clamp(bb+0.35), 1.00)
    clr[imgui.Col.ScrollbarGrabActive]  = imgui.ImVec4(ar, ag, ab, 1.00)

    imgui.GetIO().FontGlobalScale = sl_font_scale[0]
end

local russian_characters = {
    [168] = 'Ё', [184] = 'ё', [192] = 'А', [193] = 'Б', [194] = 'В', [195] = 'Г', [196] = 'Д', [197] = 'Е', [198] = 'Ж', [199] = 'З', [200] = 'И', [201] = 'Й', [202] = 'К', [203] = 'Л', [204] = 'М', [205] = 'Н', [206] = 'О', [207] = 'П', [208] = 'Р', [209] = 'С', [210] = 'Т', [211] = 'У', [212] = 'Ф', [213] = 'Х', [214] = 'Ц', [215] = 'Ч', [216] = 'Ш', [217] = 'Щ', [218] = 'Ъ', [219] = 'Ы', [220] = 'Ь', [221] = 'Э', [222] = 'Ю', [223] = 'Я', [224] = 'а', [225] = 'б', [226] = 'в', [227] = 'г', [228] = 'д', [229] = 'е', [230] = 'ж', [231] = 'з', [232] = 'и', [233] = 'й', [234] = 'к', [235] = 'л', [236] = 'м', [237] = 'н', [238] = 'о', [239] = 'п', [240] = 'р', [241] = 'с', [242] = 'т', [243] = 'у', [244] = 'ф', [245] = 'х', [246] = 'ц', [247] = 'ч', [248] = 'ш', [249] = 'щ', [250] = 'ъ', [251] = 'ы', [252] = 'ь', [253] = 'э', [254] = 'ю', [255] = 'я',
}

function string.rlower(s)
    if not s or type(s) ~= 'string' then return '' end
    s = s:lower()
    local strlen = s:len()
    if strlen == 0 then return s end
    local output = ''
    for i = 1, strlen do
        local ch = s:byte(i)
        if ch >= 192 and ch <= 223 then
            output = output .. russian_characters[ch + 32]
        elseif ch == 168 then
            output = output .. russian_characters[184]
        else
            output = output .. string.char(ch)
        end
    end
    return output
end