script_name("PayDay Notifier")
script_version("1.0")
script_author("tg @STAV_FAST")

local sampev_status, sampev = pcall(require, 'samp.events')
if not sampev_status then
    sampev_status, sampev = pcall(require, 'lib.samp.events')
end

local imgui_status, imgui = pcall(require, 'mimgui')
local inicfg_status, inicfg = pcall(require, 'inicfg')

local WinState, HudState, MoneyHudState
local enabled, soundEnabled, showHud, showMoneyHud
local notifyMinutes, selectedSound, useShortMoney, chatNotify, selectedTheme
local winWidth, winHeight

local function utf8_to_cp1251(str)
    if not str or type(str) ~= "string" then return "" end
    local result = {}
    local i = 1
    local len = #str
    while i <= len do
        local b1 = string.byte(str, i)
        if not b1 then break end
        if b1 < 128 then
            table.insert(result, string.char(b1))
            i = i + 1
        elseif b1 == 208 then
            local b2 = string.byte(str, i + 1)
            if b2 then
                if b2 == 129 then
                    table.insert(result, string.char(168))
                elseif b2 >= 144 and b2 <= 191 then
                    table.insert(result, string.char(b2 + 48))
                else
                    table.insert(result, "?")
                end
                i = i + 2
            else
                i = i + 1
            end
        elseif b1 == 209 then
            local b2 = string.byte(str, i + 1)
            if b2 then
                if b2 == 145 then
                    table.insert(result, string.char(184))
                elseif b2 >= 128 and b2 <= 143 then
                    table.insert(result, string.char(b2 + 112))
                else
                    table.insert(result, "?")
                end
                i = i + 2
            else
                i = i + 1
            end
        else
            table.insert(result, string.char(b1))
            i = i + 1
        end
    end
    return table.concat(result)
end

local function cleanHexColors(str)
    if not str then return "" end
    local cleaned = tostring(str):gsub("{%x%x%x%x%x%x}", ""):gsub("{......}", "")
    cleaned = cleaned:gsub("[\r]", "")
    return cleaned
end

local function chatMsg(text, color)
    if isSampAvailable and isSampAvailable() and sampAddChatMessage then
        pcall(sampAddChatMessage, utf8_to_cp1251(text), color or -1)
    end
end

local function openUrl(url)
    if setClipboardText then pcall(setClipboardText, url) end
    local opened = false
    if openLink then opened = pcall(openLink, url) end
    if not opened then
        pcall(function()
            os.execute('am start -a android.intent.action.VIEW -d "' .. url .. '"')
        end)
    end
    chatMsg("{33AA33}[PayDay Notifier]{FFFFFF} Ссылка: " .. url)
end

local soundDir = getWorkingDirectory() .. "/payday_notifier"

local iniFile = "payday_notifier.ini"
local cfg = {
    main = {
        enabled = true,
        soundEnabled = true,
        showHud = true,
        showMoneyHud = true,
        notifyMinutes = 5,
        selectedSound = 0,
        useShortMoney = true,
        chatNotify = true,
        selectedTheme = 1,
        winWidth = 800,
        winHeight = 450,
        factionName = "Не определена",
        factionSalary = 0,
        dutySalary = 0,
        postSalary = 0,
        questSalary = 0,
        totalSalary = 0
    }
}

if inicfg_status and inicfg then
    pcall(function()
        cfg = inicfg.load(cfg, iniFile)
        inicfg.save(cfg, iniFile)
    end)
end

local enabled_val = cfg.main.enabled
local soundEnabled_val = cfg.main.soundEnabled
local showHud_val = cfg.main.showHud
local showMoneyHud_val = (cfg.main.showMoneyHud == nil) and true or cfg.main.showMoneyHud
local notifyMinutes_val = cfg.main.notifyMinutes
local selectedSound_val = cfg.main.selectedSound or 0
local useShortMoney_val = (cfg.main.useShortMoney == nil) and true or cfg.main.useShortMoney
local chatNotify_val = (cfg.main.chatNotify == nil) and true or cfg.main.chatNotify
local selectedTheme_val = cfg.main.selectedTheme or 1
local winWidth_val = cfg.main.winWidth or 800
local winHeight_val = cfg.main.winHeight or 450

local factionName_val = cfg.main.factionName or "Не определена"
local factionSalary_val = cfg.main.factionSalary or 0
local dutySalary_val = cfg.main.dutySalary or 0
local postSalary_val = cfg.main.postSalary or 0
local questSalary_val = cfg.main.questSalary or 0
local totalSalary_val = cfg.main.totalSalary or 0

local notifiedThisCycle = false
local currentAudioStream = nil
local activeTab = 1

local soundNames = {
    "Случайный звук (1-10)", "Звук 1", "Звук 2", "Звук 3", "Звук 4",
    "Звук 5", "Звук 6", "Звук 7", "Звук 8", "Звук 9", "Звук 10"
}

local themeNames = {
    "1. Тёмная классика", "2. Аризона Gold", "3. Неоновый синий", "4. Изумрудный", "5. Светлая"
}

local function initImGuiVars()
    if imgui_status and imgui then
        WinState = WinState or imgui.new.bool(false)
        HudState = HudState or imgui.new.bool(true)
        MoneyHudState = MoneyHudState or imgui.new.bool(true)
        enabled = enabled or imgui.new.bool(enabled_val)
        soundEnabled = soundEnabled or imgui.new.bool(soundEnabled_val)
        showHud = showHud or imgui.new.bool(showHud_val)
        showMoneyHud = showMoneyHud or imgui.new.bool(showMoneyHud_val)
        notifyMinutes = notifyMinutes or imgui.new.int(notifyMinutes_val)
        selectedSound = selectedSound or imgui.new.int(selectedSound_val)
        useShortMoney = useShortMoney or imgui.new.bool(useShortMoney_val)
        chatNotify = chatNotify or imgui.new.bool(chatNotify_val)
        selectedTheme = selectedTheme or imgui.new.int(selectedTheme_val)
        winWidth = winWidth or imgui.new.int(winWidth_val)
        winHeight = winHeight or imgui.new.int(winHeight_val)
    end
end

if imgui_status then pcall(initImGuiVars) end

local function getSafePlayerMoney()
    if isSampAvailable and isSampAvailable() then
        local status, result = pcall(function()
            if getPlayerMoney and PLAYER_HANDLE then return getPlayerMoney(PLAYER_HANDLE) end
        end)
        if status and result then return result end
    end
    return totalSalary_val or 0
end

function formatMoney(amount)
    amount = tonumber(amount) or 0
    local isShort = (useShortMoney and useShortMoney[0] ~= nil) and useShortMoney[0] or useShortMoney_val

    if not isShort then
        local formatted = tostring(math.floor(math.abs(amount)))
        local k
        while true do
            formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
            if k == 0 then break end
        end
        return (amount < 0 and "-$" or "$") .. formatted
    end

    local absAmount = math.abs(amount)
    local sign = amount < 0 and "-" or ""

    if absAmount >= 1000000000 then
        return string.format("%s$%.2fM", sign, absAmount / 1000000000):gsub("%.00M", "M")
    elseif absAmount >= 1000000 then
        return string.format("%s$%.2fkk", sign, absAmount / 1000000):gsub("%.00kk", "kk")
    elseif absAmount >= 1000 then
        return string.format("%s$%.1fk", sign, absAmount / 1000):gsub("%.0k", "k")
    else
        return string.format("%s$%d", sign, absAmount)
    end
end

function applyCustomStyle(themeIdx)
    if not imgui_status or not imgui then return end
    local style = imgui.GetStyle()
    local colors = style.Colors
    style.WindowRounding = 8.0
    style.FrameRounding = 5.0
    style.ItemSpacing = imgui.ImVec2(10, 10)
    style.WindowPadding = imgui.ImVec2(12, 12)

    local c = themeIdx or selectedTheme_val
    if c == 1 then
        colors[imgui.Col.Text] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
        colors[imgui.Col.WindowBg] = imgui.ImVec4(0.09, 0.09, 0.11, 0.95)
        colors[imgui.Col.Header] = imgui.ImVec4(0.18, 0.18, 0.22, 1.00)
        colors[imgui.Col.Button] = imgui.ImVec4(0.15, 0.15, 0.18, 1.00)
        colors[imgui.Col.FrameBg] = imgui.ImVec4(0.14, 0.14, 0.16, 1.00)
        colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.20, 0.65, 0.32, 1.00)
        colors[imgui.Col.CheckMark] = imgui.ImVec4(0.20, 0.65, 0.32, 1.00)
    elseif c == 2 then
        colors[imgui.Col.Text] = imgui.ImVec4(1.00, 0.95, 0.85, 1.00)
        colors[imgui.Col.WindowBg] = imgui.ImVec4(0.12, 0.10, 0.08, 0.95)
        colors[imgui.Col.Header] = imgui.ImVec4(0.40, 0.30, 0.10, 1.00)
        colors[imgui.Col.Button] = imgui.ImVec4(0.30, 0.22, 0.08, 1.00)
        colors[imgui.Col.FrameBg] = imgui.ImVec4(0.20, 0.16, 0.10, 1.00)
        colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.90, 0.70, 0.20, 1.00)
        colors[imgui.Col.CheckMark] = imgui.ImVec4(0.90, 0.70, 0.20, 1.00)
    elseif c == 3 then
        colors[imgui.Col.Text] = imgui.ImVec4(0.90, 0.95, 1.00, 1.00)
        colors[imgui.Col.WindowBg] = imgui.ImVec4(0.05, 0.08, 0.15, 0.95)
        colors[imgui.Col.Header] = imgui.ImVec4(0.10, 0.30, 0.60, 1.00)
        colors[imgui.Col.Button] = imgui.ImVec4(0.10, 0.25, 0.45, 1.00)
        colors[imgui.Col.FrameBg] = imgui.ImVec4(0.08, 0.15, 0.25, 1.00)
        colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.20, 0.60, 1.00, 1.00)
        colors[imgui.Col.CheckMark] = imgui.ImVec4(0.20, 0.60, 1.00, 1.00)
    elseif c == 4 then
        colors[imgui.Col.Text] = imgui.ImVec4(0.90, 1.00, 0.92, 1.00)
        colors[imgui.Col.WindowBg] = imgui.ImVec4(0.06, 0.12, 0.08, 0.95)
        colors[imgui.Col.Header] = imgui.ImVec4(0.12, 0.40, 0.22, 1.00)
        colors[imgui.Col.Button] = imgui.ImVec4(0.10, 0.30, 0.18, 1.00)
        colors[imgui.Col.FrameBg] = imgui.ImVec4(0.08, 0.20, 0.12, 1.00)
        colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.25, 0.85, 0.45, 1.00)
        colors[imgui.Col.CheckMark] = imgui.ImVec4(0.25, 0.85, 0.45, 1.00)
    elseif c == 5 then
        colors[imgui.Col.Text] = imgui.ImVec4(0.10, 0.10, 0.12, 1.00)
        colors[imgui.Col.WindowBg] = imgui.ImVec4(0.92, 0.92, 0.94, 0.98)
        colors[imgui.Col.Header] = imgui.ImVec4(0.75, 0.78, 0.82, 1.00)
        colors[imgui.Col.Button] = imgui.ImVec4(0.80, 0.82, 0.85, 1.00)
        colors[imgui.Col.FrameBg] = imgui.ImVec4(0.98, 0.98, 0.98, 1.00)
        colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.20, 0.50, 0.80, 1.00)
        colors[imgui.Col.CheckMark] = imgui.ImVec4(0.20, 0.50, 0.80, 1.00)
    end
end

function saveConfig()
    if inicfg_status and inicfg then
        pcall(function()
            cfg.main.enabled = enabled_val
            cfg.main.soundEnabled = soundEnabled_val
            cfg.main.showHud = showHud_val
            cfg.main.showMoneyHud = showMoneyHud_val
            cfg.main.notifyMinutes = notifyMinutes_val
            cfg.main.selectedSound = selectedSound_val
            cfg.main.useShortMoney = useShortMoney_val
            cfg.main.chatNotify = chatNotify_val
            cfg.main.selectedTheme = selectedTheme_val
            cfg.main.winWidth = winWidth_val
            cfg.main.winHeight = winHeight_val
            cfg.main.factionName = factionName_val
            cfg.main.factionSalary = factionSalary_val
            cfg.main.dutySalary = dutySalary_val
            cfg.main.postSalary = postSalary_val
            cfg.main.questSalary = questSalary_val
            cfg.main.totalSalary = totalSalary_val
            inicfg.save(cfg, iniFile)
        end)
    end
end

function getSoundPath(index)
    return soundDir .. "/payday_sound_" .. tostring(index) .. ".mp3"
end

function playCustomSound()
    local targetIdx = selectedSound_val
    if targetIdx == 0 then targetIdx = math.random(1, 10) end
    local path = getSoundPath(targetIdx)
    if doesFileExist and doesFileExist(path) then
        if loadAudioStream and setAudioStreamState then
            pcall(function()
                if currentAudioStream then setAudioStreamState(currentAudioStream, 0) end
                currentAudioStream = loadAudioStream(path)
                if currentAudioStream then setAudioStreamState(currentAudioStream, 1) end
            end)
        end
    else
        chatMsg("{FF9900}[PayDay Sound]{FFFFFF} Файл " .. path .. " не найден!")
    end
end

function getTimeToNextPayday()
    local t = os.date("*t")
    local next_min = (t.min < 30) and 30 or 60
    local diff_sec = (next_min - t.min - 1) * 60 + (60 - t.sec)
    if diff_sec < 0 then diff_sec = 0 end
    return math.floor(diff_sec / 60), diff_sec % 60
end

if sampev_status and sampev then
    function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
        if not isSampAvailable or not isSampAvailable() then return end

        local status, err = pcall(function()
            local cleanText = cleanHexColors(text)

            local faction = cleanText:match("Организация:%s*([^\n\r]+)") or cleanText:match("Фракция:%s*([^\n\r]+)")
            if faction then
                factionName_val = faction:gsub("^%s*(.-)%s*$", "%1")
                saveConfig()
            end
        end)
    end
end

function main()
    while not isSampAvailable() do wait(100) end

    initImGuiVars()

    sampRegisterChatCommand("payday", function()
        if not imgui_status or not imgui then
            chatMsg("{FF3333}[PayDay Notifier]{FFFFFF} Ошибка: mimgui не найден!")
            return
        end
        if WinState then WinState[0] = not WinState[0] end
    end)

    sampRegisterChatCommand("pday", function()
        if sampProcessChatInput then sampProcessChatInput("/payday") end
    end)

    chatMsg("{33AA33}[PayDay Notifier v1.0]{FFFFFF} Запущен! Команды: {FF9900}/payday{FFFFFF} или {FF9900}/pday{FFFFFF}")

    while true do
        wait(1000)
        local rem_m, rem_s = getTimeToNextPayday()
        if rem_m >= 28 and notifiedThisCycle then notifiedThisCycle = false end

        if enabled_val and rem_m == notifyMinutes_val and not notifiedThisCycle then
            notifiedThisCycle = true
            if chatNotify_val then chatMsg("{FF9900}[PayDay]{FFFFFF} До PayDay осталось {FF3333}" .. notifyMinutes_val .. " мин.{FFFFFF}!") end
            if soundEnabled_val then playCustomSound() end
        end
    end
end

if imgui_status and imgui then
    imgui.OnFrame(function()
        return imgui_status and HudState ~= nil and showHud ~= nil and showHud[0] and isSampAvailable() and not isPauseMenuActive()
    end, function(player)
        applyCustomStyle(selectedTheme_val)
        imgui.SetNextWindowPos(imgui.ImVec2(10, 350), imgui.Cond.FirstUseEver)
        imgui.Begin("##PayDayHUD", HudState, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize)
        local rem_m, rem_s = getTimeToNextPayday()
        imgui.TextColored(imgui.ImVec4(0.20, 0.85, 0.40, 1.0), string.format("PayDay через: %02d:%02d", rem_m, rem_s))
        imgui.End()
    end)

    imgui.OnFrame(function()
        return imgui_status and MoneyHudState ~= nil and showMoneyHud ~= nil and showMoneyHud[0] and isSampAvailable() and not isPauseMenuActive()
    end, function(player)
        applyCustomStyle(selectedTheme_val)
        imgui.SetNextWindowPos(imgui.ImVec2(800, 80), imgui.Cond.FirstUseEver)
        imgui.Begin("##MoneyHUD", MoneyHudState, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize)
        local playerMoney = getSafePlayerMoney()
        imgui.TextColored(imgui.ImVec4(0.20, 0.90, 0.30, 1.0), "Баланс: " .. formatMoney(playerMoney))
        imgui.End()
    end)

    imgui.OnFrame(function()
        return imgui_status and WinState ~= nil and WinState[0] and isSampAvailable()
    end, function(player)
        applyCustomStyle(selectedTheme_val)

        imgui.SetNextWindowSize(imgui.ImVec2(winWidth_val, winHeight_val), imgui.Cond.FirstUseEver)
        imgui.Begin("PAYDAY NOTIFIER | v1.0", WinState, imgui.WindowFlags.NoCollapse)

        local btnW = (winWidth_val - 60) / 4
        if imgui.Button("ГЛАВНАЯ", imgui.ImVec2(btnW, 38)) then activeTab = 1 end
        imgui.SameLine()
        if imgui.Button("НАСТРОЙКИ", imgui.ImVec2(btnW, 38)) then activeTab = 2 end
        imgui.SameLine()
        if imgui.Button("ВИД И ТЕМЫ", imgui.ImVec2(btnW, 38)) then activeTab = 3 end
        imgui.SameLine()
        if imgui.Button("О СКРИПТЕ", imgui.ImVec2(btnW, 38)) then activeTab = 4 end

        imgui.Separator()
        imgui.Spacing()

        if activeTab == 1 then
            imgui.BeginChild("MainTab", imgui.ImVec2(0, 0), true)
            if enabled and imgui.Checkbox("Напоминания PayDay", enabled) then enabled_val = enabled[0]; saveConfig() end
            if soundEnabled and imgui.Checkbox("Звуковой сигнал", soundEnabled) then soundEnabled_val = soundEnabled[0]; saveConfig() end
            if showHud and imgui.Checkbox("Таймер на экране (HUD)", showHud) then showHud_val = showHud[0]; saveConfig() end
            if showMoneyHud and imgui.Checkbox("Виджет денег на экране ($kk HUD)", showMoneyHud) then showMoneyHud_val = showMoneyHud[0]; saveConfig() end

            imgui.Separator()
            local rem_m, rem_s = getTimeToNextPayday()
            imgui.TextColored(imgui.ImVec4(0.2, 0.8, 0.4, 1.0), "[>] До PayDay: " .. string.format("%02d мин. %02d сек.", rem_m, rem_s))
            imgui.TextColored(imgui.ImVec4(0.9, 0.7, 0.3, 1.0), "[i] Фракция: [" .. tostring(factionName_val) .. "]")
            imgui.Separator()

            imgui.Text("• [1] Фракция и PayDay: " .. formatMoney(factionSalary_val))
            imgui.Text("• [2] Вызовы и Обязанности: " .. formatMoney(dutySalary_val))
            imgui.Text("• [3] Посты и Дежурства: " .. formatMoney(postSalary_val))
            imgui.Text("• [4] Премии и Квесты: " .. formatMoney(questSalary_val))
            imgui.TextColored(imgui.ImVec4(0.2, 0.9, 0.3, 1.0), "• [$] Всего заработано: " .. formatMoney(totalSalary_val))

            imgui.Spacing()
            imgui.Separator()

            if imgui.Button("Сбросить статистику доходов", imgui.ImVec2(-1, 35)) then
                factionSalary_val = 0; dutySalary_val = 0; postSalary_val = 0; questSalary_val = 0; totalSalary_val = 0
                saveConfig()
                chatMsg("{33AA33}[PayDay Notifier]{FFFFFF} Статистика успешно сброшена!")
            end
            imgui.EndChild()

        elseif activeTab == 2 then
            imgui.BeginChild("SettingsTab", imgui.ImVec2(0, 0), true)
            if notifyMinutes and imgui.SliderInt("За сколько минут до PayDay", notifyMinutes, 1, 29) then notifyMinutes_val = notifyMinutes[0]; saveConfig() end
            if chatNotify and imgui.Checkbox("Уведомления в чат", chatNotify) then chatNotify_val = chatNotify[0]; saveConfig() end

            imgui.Separator()
            imgui.TextColored(imgui.ImVec4(0.9, 0.7, 0.2, 1.0), "Выбор аудиосигнала:")
            local currentSoundIdx = (selectedSound and selectedSound[0] or 0) + 1
            if imgui.BeginCombo("Звуковое оповещение", soundNames[currentSoundIdx] or soundNames[1]) then
                for i, name in ipairs(soundNames) do
                    if selectedSound and imgui.Selectable(name, selectedSound[0] == (i - 1)) then
                        selectedSound[0] = i - 1
                        selectedSound_val = i - 1
                        saveConfig()
                    end
                end
                imgui.EndCombo()
            end

            if imgui.Button("Прослушать выбранный звук", imgui.ImVec2(-1, 32)) then
                playCustomSound()
            end

            imgui.Separator()
            imgui.TextColored(imgui.ImVec4(0.9, 0.7, 0.2, 1.0), "Размер окна меню:")
            if winWidth and imgui.SliderInt("Ширина (px)", winWidth, 600, 1400) then
                winWidth_val = winWidth[0]
                imgui.SetWindowSize(imgui.ImVec2(winWidth_val, winHeight_val))
                saveConfig()
            end
            if winHeight and imgui.SliderInt("Высота (px)", winHeight, 350, 900) then
                winHeight_val = winHeight[0]
                imgui.SetWindowSize(imgui.ImVec2(winWidth_val, winHeight_val))
                saveConfig()
            end
            imgui.EndChild()

        elseif activeTab == 3 then
            imgui.BeginChild("ViewTab", imgui.ImVec2(0, 0), true)
            if useShortMoney and imgui.Checkbox("Сокращенный формат денег (k / kk / M)", useShortMoney) then useShortMoney_val = useShortMoney[0]; saveConfig() end

            imgui.Separator()
            local currentThemeIdx = (selectedTheme and selectedTheme[0] or 0) + 1
            if imgui.BeginCombo("Тема меню", themeNames[currentThemeIdx] or themeNames[1]) then
                for i, name in ipairs(themeNames) do
                    if selectedTheme and imgui.Selectable(name, selectedTheme[0] == (i - 1)) then
                        selectedTheme[0] = i - 1
                        selectedTheme_val = i
                        saveConfig()
                    end
                end
                imgui.EndCombo()
            end

            imgui.Separator()
            imgui.TextColored(imgui.ImVec4(0.2, 0.8, 1.0, 1.0), "[Превью отображения сумм]:")
            imgui.Text("• $501,102,859 ==> " .. formatMoney(501102859))
            imgui.EndChild()

        elseif activeTab == 4 then
            imgui.BeginChild("AboutTab", imgui.ImVec2(0, 0), true)
            imgui.Text("PayDay Notifier | v1.0")
            imgui.Text("Разработчик: @STAV_FAST")
            imgui.Spacing()

            if imgui.Button("Открыть Telegram канал автора", imgui.ImVec2(-1, 38)) then
                openUrl("https://t.me/Torn_tuz_lua")
            end
            imgui.EndChild()
        end

        imgui.End()
    end)
end