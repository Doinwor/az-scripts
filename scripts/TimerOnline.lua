script_author('Cosmo & ported by t.me/monetbinder (@osp_x)')
script_description('ShitCode Prodakshen')
local imgui = require 'mimgui'
local inicfg = require 'inicfg'
local se = require 'lib.samp.events'
local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local cfg = inicfg.load({
    statTimers = {
        state = true,
        clock = true,
        sesOnline = true,
        sesAfk = true,
        sesFull = true,
        dayOnline = true,
        dayAfk = true,
        dayFull = true,
        weekOnline = true,
        weekAfk = true,
        weekFull = true,
        server = nil
    },
    onDay = {
        today = os.date("%a"),
        online = 0,
        afk = 0,
        full = 0
    },
    onWeek = {
        week = 1,
        online = 0,
        afk = 0,
        full = 0
    },
    myWeekOnline = {
        [0] = 0,
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
        [5] = 0,
        [6] = 0
    },
    pos = {
        x = 0,
        y = 0
    },
    style = {
        round = 10.0,
        colorW = 4279834905,
        colorT = 4286677377
    }
}, "TimerOnline")

local new = imgui.new

local MDS = MONET_DPI_SCALE

mcx = 0x0087FF
local sX, sY = getScreenResolution()
local tag = '{0087FF}TimerOnline: {FFFFFF}'
local to = new.bool(cfg.statTimers.state)
local nowTime = os.date("%H:%M:%S", os.time())
local settings = new.bool(false)
local myOnline = new.bool(false)
local pos = false
local restart = false
local recon = false

local sesOnline = new.int(0)
local sesAfk = new.int(0)
local sesFull = new.int(0)
local dayFull = new.int(cfg.onDay.full)
local weekFull = new.int(cfg.onWeek.full)
local sRound = new.float(cfg.style.round)

local argbW = cfg.style.colorW
local argbT = cfg.style.colorT

local tmp = imgui.ColorConvertU32ToFloat4(cfg.style.colorW)
local colorW = new.float[4](tmp.x, tmp.y, tmp.z, tmp.w)

local tmp = imgui.ColorConvertU32ToFloat4(cfg.style.colorT)
local colorT = new.float[4](tmp.x, tmp.y, tmp.z, tmp.w)

local posX, posY = cfg.pos.x, cfg.pos.y
local Radio = {
    ['clock'] = cfg.statTimers.clock,
    ['sesOnline'] = cfg.statTimers.sesOnline,
    ['sesAfk'] = cfg.statTimers.sesAfk,
    ['sesFull'] = cfg.statTimers.sesFull,
    ['dayOnline'] = cfg.statTimers.dayOnline,
    ['dayAfk'] = cfg.statTimers.dayAfk,
    ['dayFull'] = cfg.statTimers.dayFull,
    ['weekOnline'] = cfg.statTimers.weekOnline,
    ['weekAfk'] = cfg.statTimers.weekAfk,
    ['weekFull'] = cfg.statTimers.weekFull
}

local tWeekdays = {
    [0] = 'Воскресенье',
    [1] = 'Понедельник',
    [2] = 'Вторник',
    [3] = 'Среда',
    [4] = 'Четверг',
    [5] = 'Пятница',
    [6] = 'Суббота'
}

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end

    if not doesFileExist('config/TimerOnline.ini') then
        if inicfg.save(cfg, 'TimerOnline.ini') then print(tag .. 'Создан файл конфигурации: TimerOnline.ini') end
    end

    if cfg.statTimers.server ~= nil and cfg.statTimers.server ~= sampGetCurrentServerAddress() then
        sampAddChatMessage(tag .. 'Вы зашли на свой не основной сервер. Скрипт отключён!', mcx)
        thisScript():unload()
    end

    if cfg.onDay.today ~= os.date("%a") then
        cfg.onDay.today = os.date("%a")
        cfg.onDay.online = 0
        cfg.onDay.full = 0
        cfg.onDay.afk = 0
        dayFull[0] = 0
        inicfg.save(cfg, 'TimerOnline.ini')
    end

    if cfg.onWeek.week ~= number_week() then
        cfg.onWeek.week = number_week()
        cfg.onWeek.online = 0
        cfg.onWeek.full = 0
        cfg.onWeek.afk = 0
        weekFull[0] = 0
        for _, v in pairs(cfg.myWeekOnline) do v = 0 end
        inicfg.save(cfg, 'TimerOnline.ini')
    end

    sampRegisterChatCommand('toset', function()
        settings[0] = not settings[0]
    end)

    sampRegisterChatCommand('online', function()
        myOnline[0] = not myOnline[0]
    end)

    lua_thread.create(time)
    lua_thread.create(autoSave)

    wait(-1)
end

function path_join(...)
    local path = ''
    local arg = {...}
    for i = 1, #arg do
        path = path .. arg[i]
        if i ~= #arg then
            path = path .. '\\'
        end
    end
    return path
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    if fsClock == nil then
        local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
        local fontpath = path_join(getWorkingDirectory(), "lib", "mimgui", 'trebucbd.ttf')

        fsClock = imgui.GetIO().Fonts:AddFontFromFileTTF(fontpath, 25.0*MDS, nil, glyph_ranges)
    end

    imgui.GetStyle():ScaleAllSizes(MDS)

    grayTheme()
end)

imgui.OnFrame(function() return to[0] and not recon end,
function()
    -- timer window >>
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(colorW[0], colorW[1], colorW[2], colorW[3]))
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(colorT[0], colorT[1], colorT[2], colorT[3]))
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, sRound[0])
    imgui.SetNextWindowPos(imgui.ImVec2(posX, posY), imgui.Cond.FirstUseEver)
    local flags = imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse +
                  imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize
    if not editpos then flags = flags + imgui.WindowFlags.NoMove end

    imgui.Begin(u8 '##timer', to, flags)
    local pos = imgui.GetWindowPos()

    if cfg.statTimers.clock then
        imgui.PushFont(fsClock)
        imgui.CenterTextColoredRGB(nowTime)
        imgui.PopFont()
        imgui.SetCursorPosY(30)
        imgui.CenterTextColoredRGB(getStrDate(os.time()))
        if cfg.statTimers.sesOnline or cfg.statTimers.sesAfk or cfg.statTimers.sesFull or cfg.statTimers.dayOnline or cfg.statTimers.dayAfk or cfg.statTimers.dayFull or cfg.statTimers.weekOnline or cfg.statTimers.weekAfk or cfg.statTimers.weekFull then
            imgui.Separator()
        end
    end

    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(5, 2))
    if not sampIsLocalPlayerSpawned() then
        --imgui.CenterTextColoredRGB("Подключение: " .. get_clock(connectingTime))
    else
        if cfg.statTimers.sesOnline then imgui.CenterTextColoredRGB("Сессия (чистый): " .. get_clock(sesOnline[0])) end
        if cfg.statTimers.sesAfk then imgui.CenterTextColoredRGB("AFK за сессию: " .. get_clock(sesAfk[0])) end
        if cfg.statTimers.sesFull then imgui.CenterTextColoredRGB("Онлайн за сессию: " .. get_clock(sesFull[0])) end
        if cfg.statTimers.dayOnline then
            imgui.CenterTextColoredRGB("За день (чистый): " ..
                get_clock(cfg.onDay.online))
        end
        if cfg.statTimers.dayAfk then imgui.CenterTextColoredRGB("АФК за день: " .. get_clock(cfg.onDay.afk)) end
        if cfg.statTimers.dayFull then imgui.CenterTextColoredRGB("Онлайн за день: " .. get_clock(cfg.onDay.full)) end
        if cfg.statTimers.weekOnline then
            imgui.CenterTextColoredRGB("За неделю (чистый): " ..
                get_clock(cfg.onWeek.online))
        end
        if cfg.statTimers.weekAfk then imgui.CenterTextColoredRGB("АФК за неделю: " .. get_clock(cfg.onWeek.afk)) end
        if cfg.statTimers.weekFull then imgui.CenterTextColoredRGB("Онлайн за неделю: " .. get_clock(cfg.onWeek.full)) end
    end
    imgui.PopStyleVar()
    if editpos and imgui.Button(u8"Закрепить", imgui.ImVec2(-1, 20)) then
        editpos = false
        settings[0] = true
        cfg.pos.x, cfg.pos.y = pos.x, pos.y
        inicfg.save(cfg, 'TimerOnline.ini')
        sampAddChatMessage(tag .. 'Позиция окна сохранена!', mcx)
    end

    imgui.End()
    imgui.PopStyleVar()
    imgui.PopStyleColor(2)
end)
imgui.OnFrame(function() return settings[0] end,
function()
     -- settings menu >>
    imgui.SetNextWindowSize(imgui.ImVec2(500*MDS, 315*MDS), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(sX / 2, sY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(u8 '#Settings', settings,
        imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse +
        imgui.WindowFlags.NoTitleBar)
    imgui.PushFont(fsClock)
    imgui.CenterTextColoredRGB('Timer Online')
    imgui.PopFont()
    imgui.BeginChild('##RadioButtons', imgui.ImVec2(190*MDS, 245*MDS), true)

    if imgui.RadioButtonBool(u8 'Текущее дата и время', Radio['clock']) then
        Radio['clock'] = not Radio['clock']; cfg.statTimers.clock = Radio['clock']
    end
    if imgui.RadioButtonBool(u8 'Онлайн сессию', Radio['sesOnline']) then
        Radio['sesOnline'] = not Radio['sesOnline']; cfg.statTimers.sesOnline = Radio['sesOnline']
    end
    imgui.Hint(u8 'Без учёта АФК (Чистый онлайн)')
    if imgui.RadioButtonBool(u8 'AFK за сессию', Radio['sesAfk']) then
        Radio['sesAfk'] = not Radio['sesAfk']; cfg.statTimers.sesAfk = Radio['sesAfk']
    end
    if imgui.RadioButtonBool(u8 'Общий за сессию', Radio['sesFull']) then
        Radio['sesFull'] = not Radio['sesFull']; cfg.statTimers.sesFull = Radio['sesFull']
    end
    if imgui.RadioButtonBool(u8 'Онлайн за день', Radio['dayOnline']) then
        Radio['dayOnline'] = not Radio['dayOnline']; cfg.statTimers.dayOnline = Radio['dayOnline']
    end
    imgui.Hint(u8 'Без учёта АФК (Чистый онлайн)')
    if imgui.RadioButtonBool(u8 'АФК за день', Radio['dayAfk']) then
        Radio['dayAfk'] = not Radio['dayAfk']; cfg.statTimers.dayAfk = Radio['dayAfk']
    end
    if imgui.RadioButtonBool(u8 'Общий за день', Radio['dayFull']) then
        Radio['dayFull'] = not Radio['dayFull']; cfg.statTimers.dayFull = Radio['dayFull']
    end
    if imgui.RadioButtonBool(u8 'Онлайн за неделю', Radio['weekOnline']) then
        Radio['weekOnline'] = not Radio['weekOnline']; cfg.statTimers.weekOnline = Radio['weekOnline']
    end
    imgui.Hint(u8 'Без учёта АФК (Чистый онлайн)')
    if imgui.RadioButtonBool(u8 'АФК за неделю', Radio['weekAfk']) then
        Radio['weekAfk'] = not Radio['weekAfk']; cfg.statTimers.weekAfk = Radio['weekAfk']
    end
    if imgui.RadioButtonBool(u8 'Общий за неделю', Radio['weekFull']) then
        Radio['weekFull'] = not Radio['weekFull']; cfg.statTimers.weekFull = Radio['weekFull']
    end
    imgui.EndChild()
    imgui.SameLine()
    imgui.BeginChild('##Customisation', imgui.ImVec2(-1, 245*MDS), true)
    if imgui.Checkbox(u8('##State'), to) then
        cfg.statTimers.state = to[0]
        inicfg.save(cfg, 'TimerOnline.ini')
    end
    imgui.SameLine()
    if to[0] then
        imgui.TextColored(imgui.ImVec4(0.00, 0.53, 0.76, 1.00), u8 'Включено')
    else
        imgui.TextDisabled(u8 'Выключено')
    end
    if imgui.Button(u8 'Местоположение', imgui.ImVec2(-1, 20*MDS)) then
        editpos = true
        settings[0] = false
        sampAddChatMessage(tag .. 'Перемещайте окно', mcx)
    end
    if cfg.statTimers.server == sampGetCurrentServerAddress() then
        if imgui.Button(u8(sampGetCurrentServerName()), imgui.ImVec2(-1, 20*MDS)) then
            cfg.statTimers.server = nil
            sampAddChatMessage(tag .. 'Теперь этот сервер не считается основным!', mcx)
        end
    else
        if imgui.Button(u8 'Установить этот сервер основным', imgui.ImVec2(-1, 20*MDS)) then
            cfg.statTimers.server = sampGetCurrentServerAddress()
            sampAddChatMessage(tag .. 'Теперь онлайн будет считаться только на этом сервере!', mcx)
        end
        imgui.Hint(u8 'Скрипт будет запускаться только на этом сервере!')
    end
    imgui.PushItemWidth(-1)
    if imgui.SliderFloat('##Round', sRound, 0.0, 10.0, u8 "Скругление краёв: %.2f") then
        cfg.style.round = sRound[0]
    end
    imgui.PopItemWidth()

    if imgui.ColorEdit4(u8 'Цвет фона', colorW, imgui.ColorEditFlags.NoInputs) then
        argbW = imgui.ColorConvertFloat4ToU32(
            imgui.ImVec4( colorW[0], colorW[1], colorW[2], colorW[3] )
        )
        cfg.style.colorW = argbW
    end
    if imgui.ColorEdit4(u8 'Цвет текста', colorT, imgui.ColorEditFlags.NoInputs) then
        argbT = imgui.ColorConvertFloat4ToU32(
            imgui.ImVec4( colorT[0], colorT[1], colorT[2], colorT[3] )
        )
        cfg.style.colorT = argbT
    end

    imgui.SetCursorPosY(imgui.GetWindowHeight() - 20*MDS)
    imgui.CenterTextColoredRGB('{707070}Сбросить все настройки')
    if imgui.IsItemHovered() and imgui.IsMouseDoubleClicked(0) then
        restart = true
        os.remove(getWorkingDirectory() .. 'config/TimerOnline.ini')
        thisScript():reload()
    else
        imgui.Hint(u8 'Двойной клик что-бы\nсбросить все настройки и таймеры')
    end

    imgui.EndChild()
    if imgui.Button(u8 'Сохранить и закрыть', imgui.ImVec2(-1, 20*MDS)) then
        if inicfg.save(cfg, 'TimerOnline.ini') then
            sampAddChatMessage(tag .. 'Настройки сохранены!', mcx)
            settings[0] = false
        end
    end
    imgui.End()
end)
imgui.OnFrame(function() return myOnline[0] end,
function()
    imgui.SetNextWindowSize(imgui.ImVec2(400*MDS, 230*MDS), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(sX / 2, sY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(u8 '#WeekOnline', _,
        imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + 
        imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize)
    imgui.SetCursorPos(imgui.ImVec2(15*MDS, 10*MDS))
    imgui.PushFont(fsClock)
    imgui.CenterTextColoredRGB('Онлайн за неделю')
    imgui.PopFont()
    imgui.CenterTextColoredRGB('{0087FF}Всего отыграно: ' .. get_clock(cfg.onWeek.full))
    imgui.NewLine()
    for day = 1, 6 do -- ПН -> СБ
        imgui.Text(u8(tWeekdays[day])); imgui.SameLine(250*MDS)
        imgui.Text(get_clock(cfg.myWeekOnline[day]))
    end
    --> ВС
    imgui.Text(u8(tWeekdays[0])); imgui.SameLine(250*MDS)
    imgui.Text(get_clock(cfg.myWeekOnline[0]))

    imgui.SetCursorPosX((imgui.GetWindowWidth() - 200*MDS) / 2)
    if imgui.Button(u8 'Закрыть', imgui.ImVec2(200*MDS, 25*MDS)) then myOnline[0] = false end
    imgui.End()
end)

function se.onTogglePlayerSpectating(state) recon = state end -- если вы админ, то в реконе скрипт будет отключать табличку, сделал чисто для себя, если надо - удалите

function time()
    startTime = os.time() -- "Точка отсчёта"
    connectingTime = 0
    while true do
        wait(1000)
        nowTime = os.date("%H:%M:%S", os.time())
        if sampIsLocalPlayerSpawned() then                          -- Игровой статус равен "Подключён к серверу" (Что бы онлайн считало только, когда, мы подключены к серверу)
            sesOnline[0] = sesOnline[0] + 1                        -- Онлайн за сессию без учёта АФК
            sesFull[0] = os.time() - startTime                    -- Общий онлайн за сессию
            sesAfk[0] = sesFull[0] - sesOnline[0]                 -- АФК за сессию

            cfg.onDay.online = cfg.onDay.online + 1              -- Онлайн за день без учёта АФК
            cfg.onDay.full = dayFull[0] + sesFull[0]               -- Общий онлайн за день
            cfg.onDay.afk = cfg.onDay.full - cfg.onDay.online    -- АФК за день

            cfg.onWeek.online = cfg.onWeek.online + 1            -- Онлайн за неделю без учёта АФК
            cfg.onWeek.full = weekFull[0] + sesFull[0]             -- Общий онлайн за неделю
            cfg.onWeek.afk = cfg.onWeek.full - cfg.onWeek.online -- АФК за неделю

            local today = tonumber(os.date('%w', os.time()))
            cfg.myWeekOnline[today] = cfg.onDay.full

            connectingTime = 0
        else
            connectingTime = connectingTime + 1 -- Вермя подключения к серверу
            startTime = startTime + 1           -- Смещение начала отсчета таймеров
        end
    end
end

function autoSave()
    while true do
        wait(60000) -- сохранение каждые 60 секунд
        inicfg.save(cfg, "TimerOnline")
    end
end

function onScriptTerminate(script, quitGame)
    if script == thisScript() and not restart then
        if inicfg.save(cfg, 'TimerOnline.ini') then print('{00FF00}TimerOnline: {FFFFFF}Ваш онлайн сохранён!') end
    end
end

function number_week() -- получение номера недели в году
    local current_time = os.date '*t'
    local start_year = os.time { year = current_time.year, day = 1, month = 1 }
    local week_day = (os.date('%w', start_year) - 1) % 7
    return math.ceil((current_time.yday + week_day) / 7)
end

function getStrDate(unixTime)
    local tMonths = { 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября',
        'ноября', 'декабря' }
    local day = tonumber(os.date('%d', unixTime))
    local month = tMonths[tonumber(os.date('%m', unixTime))]
    local weekday = tWeekdays[tonumber(os.date('%w', unixTime))]
    return string.format('%s, %s %s', weekday, day, month)
end

function get_clock(time)
    local timezone_offset = 86400 - os.date('%H', 0) * 3600
    if tonumber(time) >= 86400 then onDay = true else onDay = false end
    return os.date((onDay and math.floor(time / 86400) .. 'д ' or '') .. '%H:%M:%S', time + timezone_offset)
end

function imgui.CenterTextColoredRGB(text)
    text = u8(text)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local col = imgui.Col
    
    local designText = function(text__)
        local pos = imgui.GetCursorPos()
        if false then
            for i = 1, 1 --[[Степень тени]] do
                imgui.SetCursorPos(imgui.ImVec2(pos.x + i, pos.y))
                imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text__) -- shadow
                imgui.SetCursorPos(imgui.ImVec2(pos.x - i, pos.y))
                imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text__) -- shadow
                imgui.SetCursorPos(imgui.ImVec2(pos.x, pos.y + i))
                imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text__) -- shadow
                imgui.SetCursorPos(imgui.ImVec2(pos.x, pos.y - i))
                imgui.TextColored(imgui.ImVec4(0, 0, 0, 1), text__) -- shadow
            end
        end
        imgui.SetCursorPos(pos)
    end
    
    
    
    local text = text:gsub('{(%x%x%x%x%x%x)}', '{%1FF}')

    local color = colors[col.Text]
    local start = 1
    local a, b = text:find('{........}', start)   
    
    while a do
        local t = text:sub(start, a - 1)
        if #t > 0 then
            designText(t)
            imgui.TextColored(color, t)
            imgui.SameLine(nil, 0)
        end

        local clr = text:sub(a + 1, b - 1)
        if clr:upper() == 'STANDART' then color = colors[col.Text]
        else
            clr = tonumber(clr, 16)
            if clr then
                local r = bit.band(bit.rshift(clr, 24), 0xFF)
                local g = bit.band(bit.rshift(clr, 16), 0xFF)
                local b = bit.band(bit.rshift(clr, 8), 0xFF)
                local a = bit.band(clr, 0xFF)
                color = imgui.ImVec4(r / 255, g / 255, b / 255, a / 255)
            end
        end

        start = b + 1
        a, b = text:find('{........}', start)
    end
    imgui.NewLine()
    if #text >= start then
        imgui.SameLine(nil, 0)
        designText(text:sub(start))
        imgui.TextColored(color, text:sub(start))
    end
end

function imgui.Hint(text, delay)
    if imgui.IsItemHovered() then
        if go_hint == nil then go_hint = os.clock() + (delay and delay or 0.0) end
        local alpha = (os.clock() - go_hint) * 5 -- скорость появления
        if os.clock() >= go_hint then
            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, (alpha <= 1.0 and alpha or 1.0))
            imgui.PushStyleColor(imgui.Col.PopupBg, imgui.GetStyle().Colors[imgui.Col.ButtonHovered])
            imgui.BeginTooltip()
            imgui.PushTextWrapPos(450)
            imgui.TextUnformatted(text)
            if not imgui.IsItemVisible() and imgui.GetStyle().Alpha == 1.0 then go_hint = nil end
            imgui.PopTextWrapPos()
            imgui.EndTooltip()
            imgui.PopStyleColor()
            imgui.PopStyleVar()
        end
    end
end

function grayTheme()
	imgui.SwitchContext()
    --==[ STYLE ]==--
    imgui.GetStyle().WindowPadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().FramePadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(2, 2)
    imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(0, 0)
    imgui.GetStyle().IndentSpacing = 0
    imgui.GetStyle().ScrollbarSize = 10
    imgui.GetStyle().GrabMinSize = 10
    local scsize = imgui.GetStyle().ScrollbarSize
    imgui.GetStyle().ScrollbarSize = scsize + scsize / 2

    --==[ BORDER ]==--
    imgui.GetStyle().WindowBorderSize = 1
    imgui.GetStyle().ChildBorderSize = 1
    imgui.GetStyle().PopupBorderSize = 1
    imgui.GetStyle().FrameBorderSize = 1
    imgui.GetStyle().TabBorderSize = 1

    --==[ ROUNDING ]==--
    imgui.GetStyle().WindowRounding = 8
    imgui.GetStyle().ChildRounding = 8
    imgui.GetStyle().FrameRounding = 8
    imgui.GetStyle().PopupRounding = 8
    imgui.GetStyle().ScrollbarRounding = 8
    imgui.GetStyle().GrabRounding = 8
    imgui.GetStyle().TabRounding = 8

    --==[ ALIGN ]==--
    imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().SelectableTextAlign = imgui.ImVec2(0.5, 0.5)

    --==[ COLORS ]==--
    imgui.GetStyle().Colors[imgui.Col.Text] = imgui.ImVec4(0.90, 0.90, 0.90, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.70, 0.70, 0.70, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg] = imgui.ImVec4(0.15, 0.20, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ChildBg] = imgui.ImVec4(0.15, 0.20, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg] = imgui.ImVec4(0.15, 0.20, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Border] = imgui.ImVec4(5, 39, 29, 0.2) -- серый цвет для бордеров
    imgui.GetStyle().Colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg] = imgui.ImVec4(0.20, 0.25, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.25, 0.30, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.30, 0.35, 0.40, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBg] = imgui.ImVec4(0.15, 0.20, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.20, 0.25, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.15, 0.20, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.15, 0.20, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.20, 0.25, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.40, 0.45, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.45, 0.50, 0.55, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.50, 0.55, 0.60, 1.00)
    imgui.GetStyle().Colors[imgui.Col.CheckMark] = imgui.ImVec4(0.90, 0.90, 0.90, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.40, 0.45, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.50, 0.55, 0.60, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button] = imgui.ImVec4(0.20, 0.25, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.25, 0.30, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.30, 0.35, 0.40, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header] = imgui.ImVec4(0.20, 0.25, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.25, 0.30, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.30, 0.35, 0.40, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Separator] = imgui.ImVec4(5, 39, 29, 0.2)
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(5, 39, 29, 0.2)
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive] = imgui.ImVec4(5, 39, 29, 0.2)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip] = imgui.ImVec4(0.40, 0.45, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.45, 0.50, 0.55, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.50, 0.55, 0.60, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Tab] = imgui.ImVec4(0.15, 0.20, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabHovered] = imgui.ImVec4(0.25, 0.30, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabActive] = imgui.ImVec4(0.30, 0.35, 0.40, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocused] = imgui.ImVec4(0.15, 0.20, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive] = imgui.ImVec4(0.20, 0.25, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines] = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered] = imgui.ImVec4(1.00, 0.43, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram] = imgui.ImVec4(0.90, 0.70, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered] = imgui.ImVec4(1.00, 0.60, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(0.80, 0.95, 0.87, 0.35)
    imgui.GetStyle().Colors[imgui.Col.DragDropTarget] = imgui.ImVec4(0.80, 0.95, 0.87, 0.90)
    imgui.GetStyle().Colors[imgui.Col.NavHighlight] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.20)
    imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.70)
end