script_author('Theopka')
script_version('1.1')

local sampev      = require('lib.samp.events')
local ffi         = require ('ffi')
local gta         = ffi.load('GTASA')
local ltn12       = require("ltn12")
local http        = require("socket.http")

-------------------------- jsoncfg --------------------------

local jsoncfg = require 'jsoncfg'
local cfg = jsoncfg.load({
    stata = {
        reis = 0,
        salar = 0,
        larec = 0,
    },
    main = {
        skip = false,
        stats = false,
        arendavu = false,
        mainskelet = false,
        byxanka = false,
        eleksir = false,
    },
}, 'ProductH.json')
jsoncfg.save(cfg, 'ProductH.json')

function save()
    jsoncfg.save(cfg, 'ProductH.json')
end
-------------------------- mimgui --------------------------

local faicons = require('fAwesome6')
local fa = require('Fawesome6_solid')
local widgets = require ('widgets')
local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local MDS = MONET_DPI_SCALE

local UI = { version = 1, font = {}, tab = 1 }
local tab = 1
local activeButton = 1

local Window = imgui.new.bool()
local found_update = imgui.new.bool()

local skipdialog = imgui.new.bool(cfg.main.skip)
local statsmenu = imgui.new.bool(cfg.main.stats)
local arenda = imgui.new.bool(cfg.main.arendavu)
local skelet = imgui.new.bool(cfg.main.mainskelet)
local byxank = imgui.new.bool(cfg.main.byxanka)
local eleksi = imgui.new.bool(cfg.main.eleksir)

local StateFrame = imgui.OnFrame(
    function() return Window[0] end, 
    function(self)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 540 * MDS, 340 * MDS
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)

        imgui.Begin('dlc', Window, imgui.WindowFlags.NoTitleBar)
        
        imgui.SetCursorPos(imgui.ImVec2(4 * MDS, 4 * MDS))
        if imgui.Button(fa.XMARK..'', imgui.ImVec2(50, 50)) then
            Window[0] = false
        end
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.Text(u8'Закрыть меню')
            imgui.EndTooltip()
        end
        imgui.SetCursorPos(imgui.ImVec2(20 * MDS, 30 * MDS))
        imgui.PushFont(big)
        imgui.Text(fa.TRUCK..' Product')
        imgui.SetCursorPos(imgui.ImVec2(44 * MDS, 45 * MDS))
        imgui.Text('Helper')
        imgui.PopFont()

        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 1.0, 1.0, 0.0))
        imgui.SetCursorPos(imgui.ImVec2(115 * MDS, 10 * MDS)) 
    if imgui.BeginChild('Name##'..tab, imgui.ImVec2(), true) then -- меню
        
        if tab == 1 then 
            imgui.CenterText(fa.MONEY_CHECK..u8' Заработано с рейсов: '..sep(cfg.stata.salar)..'$')
            imgui.Text('')
            imgui.CenterText(fa.TRUCK_FAST..u8' Количество рейсов: '..cfg.stata.reis)
            imgui.CenterText(fa.BOX..u8' Количество ларцов: '..cfg.stata.larec)
            imgui.Text('')
            imgui.CenterText(fa.ROUTE..u8' Проехал за: '..clock(getTripTime()))

            imgui.SetCursorPosY(imgui.GetWindowSize().y - (30*2) * MDS - imgui.GetStyle().FramePadding.y * 2)
            if imgui.Button(fa.TRASH..u8' Сбросить всё', imgui.ImVec2(imgui.GetMiddleButtonX(1), 30 * MDS)) then
                imgui.OpenPopup(fa.CIRCLE_EXCLAMATION..u8' Предупреждения! ')
            end
            imgui.SetNextWindowSize(imgui.ImVec2(200* MDS, 72 * MDS), imgui.Cond.FirstUseEver)
            if imgui.BeginPopupModal(fa.CIRCLE_EXCLAMATION..u8' Предупреждения! ', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
                imgui.CenterText(u8'Вы уверены?')
                if imgui.Button(fa.CHECK..u8'Да', imgui.ImVec2(imgui.GetMiddleButtonX(2), 30 * MDS)) then
                    cfg.stata.salar = 0
                    cfg.stata.reis = 0
                    cfg.stata.larec = 0
                    save()
                    imgui.CloseCurrentPopup()
                end
                imgui.SameLine()
                if imgui.Button(fa.XMARK..u8' Нет', imgui.ImVec2(imgui.GetMiddleButtonX(2), 30 * MDS)) then
                    imgui.CloseCurrentPopup()
                end
                
                imgui.EndPopup()
            end

            if imgui.Button(fa.DELETE_LEFT..u8' Сбросить заработок', imgui.ImVec2(imgui.GetMiddleButtonX(2), 30 * MDS)) then
                imgui.OpenPopup(fa.CIRCLE_EXCLAMATION..u8' Предупреждения!  ')
            end
            imgui.SetNextWindowSize(imgui.ImVec2(200* MDS, 72 * MDS), imgui.Cond.FirstUseEver)
            if imgui.BeginPopupModal(fa.CIRCLE_EXCLAMATION..u8' Предупреждения!  ', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
                imgui.CenterText(u8'Вы уверены?')
                if imgui.Button(fa.CHECK..u8'Да', imgui.ImVec2(imgui.GetMiddleButtonX(2), 30 * MDS)) then
                    cfg.stata.salar = 0
                    save()
                    imgui.CloseCurrentPopup()
                end
                imgui.SameLine()
                if imgui.Button(fa.XMARK..u8' Нет', imgui.ImVec2(imgui.GetMiddleButtonX(2), 30 * MDS)) then
                    imgui.CloseCurrentPopup()
                end
                
                imgui.EndPopup()
            end
            imgui.SameLine()
            if imgui.Button(fa.DELETE_LEFT..u8' Сбросить количество', imgui.ImVec2(imgui.GetMiddleButtonX(2), 30 * MDS)) then
                imgui.OpenPopup(fa.CIRCLE_EXCLAMATION..u8' Предупреждения!   ')
            end
            imgui.SetNextWindowSize(imgui.ImVec2(200* MDS, 72 * MDS), imgui.Cond.FirstUseEver)
            if imgui.BeginPopupModal(fa.CIRCLE_EXCLAMATION..u8' Предупреждения!   ', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
                imgui.CenterText(u8'Вы уверены?')
                if imgui.Button(fa.CHECK..u8'Да', imgui.ImVec2(imgui.GetMiddleButtonX(2), 30 * MDS)) then
                    cfg.stata.reis = 0
                    cfg.stata.larec = 0
                    save()
                    imgui.CloseCurrentPopup()
                end
                imgui.SameLine()
                if imgui.Button(fa.XMARK..u8' Нет', imgui.ImVec2(imgui.GetMiddleButtonX(2), 30 * MDS)) then
                    imgui.CloseCurrentPopup()
                end
                
                imgui.EndPopup()
            end
        end

        if tab == 2 then 
            if imgui.ButtonB(fa.BOLT..u8' Включить скип диалогов', fa.BOLT..u8' Выключить скип диалогов', skipdialog, imgui.ImVec2(imgui.GetMiddleButtonX(2), 30 * MDS)) then
                cfg.main.skip = skipdialog[0]
                save()
            end
            imgui.SameLine()

            if imgui.ButtonB(fa.GIFT..u8' Включить вычет аренды', fa.GIFT..u8' Выключить вычет аренды ', arenda, imgui.ImVec2(imgui.GetMiddleButtonX(2), 30 * MDS)) then
                cfg.main.arenda = arenda[0]
                save()
            end
            if imgui.Button(fa.WINDOW_RESTORE..u8' Статистика меню', imgui.ImVec2(imgui.GetMiddleButtonX(1), 30 * MDS)) then
                imgui.OpenPopup(fa.GEAR..u8' Настроить меню')
            end
            if imgui.BeginPopupModal(fa.GEAR..u8' Настроить меню', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
                if imgui.ToggleButton(u8' Включить статистику', u8'Выключить статистику', statsmenu) then
                    cfg.main.stats = statsmenu[0]
                    save()
                end
                if imgui.Button(fa.XMARK..u8' Закрыть', imgui.ImVec2(180 * MDS, 20 * MDS)) then
                    imgui.CloseCurrentPopup()
                end
                imgui.EndPopup()
            end
            if imgui.Button(fa.WALLET..u8' Прибавка к зп', imgui.ImVec2(imgui.GetMiddleButtonX(1), 30 * MDS)) then
                imgui.OpenPopup(fa.GEAR..u8' Настроить процент к зп')
            end
            if imgui.BeginPopupModal(fa.GEAR..u8' Настроить процент к зп', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
                if imgui.ToggleButton(u8' Включить прибавку майнскелета (+45%)', u8'Выключить прибавку майнскелета (+45%)', skelet) then
                    cfg.main.mainskelet = skelet[0]
                    save()
                end
                if imgui.ToggleButton(u8' Включить прибавку буханки (+30%)', u8'Выключить прибавку буханки (+30%)', byxank) then
                    cfg.main.byxanka = byxank[0]
                    save()
                end
                if imgui.ToggleButton(u8' Включить прибавку элексира (+25%)', u8'Выключить прибавку элексира (+25%)', eleksi) then
                    cfg.main.eleksir = eleksi[0]
                    save()
                end
                if imgui.Button(fa.XMARK..u8' Закрыть', imgui.ImVec2(300 * MDS, 20 * MDS)) then
                    imgui.CloseCurrentPopup()
                end
                imgui.EndPopup()
            end


        end
        if tab == 3 then 
            imgui.CenterText(fa.USER..u8' Author: Theopka')
            imgui.CenterText(fa.FIRE..u8' Version: '..thisScript().version)
            imgui.CenterText('')
            if imgui.Button(fa.PAPER_PLANE..u8" Перейти в ТГК", imgui.ImVec2(imgui.GetMiddleButtonX(1), 25 * MDS)) then 
                openLink("https://t.me/TheopkaStudio") 
            end
            if imgui.CollapsingHeader(fa.FIRE..u8' Список обновленний') then
                if imgui.CollapsingHeader(u8'1.0(16.08.2025)') then
                    imgui.CenterText(u8'Релиз скрипта')
                end
                if imgui.CollapsingHeader(u8'1.1(01.11.2025)') then
                    imgui.CenterText(u8'Добавлена прибавка к зп от элексира')
                end
            end
        end
        imgui.EndChild()
       end

       
imgui.SetCursorPos(imgui.ImVec2(10 * MDS, 70 * MDS))
if imgui.BeginChild('Buttons##', imgui.ImVec2(100 * MDS, 260 * MDS), true) then -- TAB 
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(1.0, 1.0, 1.0, 0.0))
    if activeButton == 1 then
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 0.0, 0.0, 1.0))
    end
    imgui.SetCursorPos(imgui.ImVec2(2, imgui.GetCursorPosY())) 
        imgui.PushFont(texte)
    if imgui.Button(faicons('circle_info')..u8" Статистика", imgui.ImVec2(95 * MDS, 83 * MDS)) then
        tab = 1
        activeButton = 1
    end
    if activeButton == 1 then
        imgui.PopStyleColor()
        local drawlist = imgui.GetForegroundDrawList()
        local buttonPos = imgui.GetItemRectMax() 
        drawlist:AddLine(buttonPos, buttonPos - imgui.ImVec2(0, 83 * MDS), imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0, 0.0, 0.0, 1.0)), 4.0)
    end

    if activeButton == 2 then
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 0.0, 0.0, 1.0)) 
    end
    imgui.SetCursorPos(imgui.ImVec2(2, imgui.GetCursorPosY()))  
    if imgui.Button(faicons('gear')..u8" Настройки", imgui.ImVec2(95 * MDS, 83 * MDS)) then
        tab = 2
        activeButton = 2
    end
    if activeButton == 2 then
        imgui.PopStyleColor()
        local drawlist = imgui.GetForegroundDrawList()
        local buttonPos = imgui.GetItemRectMax() 
        drawlist:AddLine(buttonPos, buttonPos - imgui.ImVec2(0, 83 * MDS), imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0, 0.0, 0.0, 1.0)), 4.0)
    end

    if activeButton == 3 then
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 0.0, 0.0, 1.0)) 
    end
    imgui.SetCursorPos(imgui.ImVec2(2, imgui.GetCursorPosY())) 
    if imgui.Button(faicons('user')..u8" Информация", imgui.ImVec2(95 * MDS, 83 * MDS)) then
        tab = 3
        activeButton = 3
    end
    if activeButton == 3 then
        imgui.PopStyleColor()
        local drawlist = imgui.GetForegroundDrawList()
        local buttonPos = imgui.GetItemRectMax()
        drawlist:AddLine(buttonPos, buttonPos - imgui.ImVec2(0, 83 * MDS), imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0, 0.0, 0.0, 1.0)), 4.0) 
    end
imgui.PopFont()

    imgui.EndChild()
end

        imgui.PopStyleColor()
        imgui.End()
    end
)

imgui.OnFrame(
    function() return statsmenu[0] end,
    function(player)
        imgui.Begin('stats_window', statsmenu, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize)
        
        imgui.CenterText(fa.MONEY_CHECK..u8' Заработано с рейсов: '..sep(cfg.stata.salar)..'$')
        imgui.Text('')
        imgui.CenterText(fa.TRUCK_FAST..u8' Количество рейсов: '..cfg.stata.reis)
        imgui.CenterText(fa.BOX..u8' Количество ларцов: '..cfg.stata.larec)
        imgui.Text('')
        imgui.CenterText(fa.ROUTE..u8' Проехал за: '..clock(getTripTime()))

        imgui.End()
    end
)

local lmPath = "ProductHelper.lua"
local lmUrl = "https://github.com/Theopochka/ProductHelper_update/raw/refs/heads/main/ProductHelper.lua"

imgui.OnFrame(function() return found_update[0] end, function(player)
    local scrx, scry = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(scrx / 2, scry / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(u8'', found_update, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoMove)
    imgui.CenterText('')
    imgui.CenterText(fa.TRUCK..' Product helper')
    imgui.CenterText(fa.USER..' Credits: @Theopka | TheopkaStudio')
    imgui.CenterText('')
    imgui.CenterText(u8'Найдено новое обновление!')
    imgui.CenterText('')
    imgui.CenterText(u8'Было найдено новое обновление скрипта.')
    imgui.CenterText(u8'Для продолжения работы')
    imgui.CenterText(u8'Вам необходимо выбрать одну из двух кнопок ниже')
    imgui.CenterText('')
    imgui.CenterText(u8'О новых изменениях почитайте в пункте "Информация"')
    imgui.CenterText('')
    if imgui.Button(faicons("DOWNLOAD") .. u8' ОБНОВИТЬ', imgui.ImVec2(imgui.GetMiddleButtonX(1), 30 * MDS)) then
        updateScript(lmUrl, lmPath)
    end
    if imgui.Button(faicons("FORWARD") .. u8' ПРОПУСТИТЬ', imgui.ImVec2(imgui.GetMiddleButtonX(1), 30 * MDS)) then
        found_update[0] = not found_update[0]
        msg('Обновление скрипта пропущено')
    end
    imgui.End()
end
)

-------------------------- main --------------------------

local isRunning = false
local startTime = 0
local tripTime = 0

function main()
    while not isSampAvailable() do wait(0) end
        sampRegisterChatCommand('pr', function(arg)
            Window[0] = not Window[0]
        end)
        check_update()
    while true do
        wait(0)
    end
end


function sampev.onServerMessage(color, text)

    if text:find('премия за доставку' and '- $(%d+)') then	
        local salary = text:match('премия за доставку' and '- $(%d+)')

            if cfg.main.mainskelet then
                procs = math.floor(salary * 1.45)
            end
            if cfg.main.byxanka then
                procs = math.floor(salary * 1.30)
            end
            if cfg.main.eleksir then
                procs = math.floor(salary * 1.25)
            end

            cfg.stata.salar = cfg.stata.salar + procs
            cfg.stata.reis = cfg.stata.reis + 1
            save()
    end
        
    if text:find("Вам был добавлен предмет 'Ларец" or "Вам был добавлен предмет 'Ящик" or "Вам был добавлен предмет 'Concept" or "Вам был добавлен предмет 'Super" or "Вам был добавлен предмет 'Rare" or "Вам был добавлен предмет 'Супер" or "Вам был добавлен предмет 'Пасхальный") then
        cfg.stata.larec = cfg.stata.larec + 1
        save()
    end
    if text:find('(.+)%[ID: %d+%] передал вам в аренду (.+) на (%d+)ч за (%d+)') then
        local nick,truck,time,money = text:match('(.+)%[ID: %d+%] передал вам в аренду (.+) на (%d+)ч за (%d+)')
        if cfg.main.arendavu then
            cfg.stata.salar = cfg.stata.salar - money
            save()
        end
    end
    if text:find('Вы арендовали транспорт (.+) на (%d+)ч за (%d+)') then
        local truck,time,money = text:match('Вы арендовали транспорт (.+) на (%d+)ч за (%d+)')
        if cfg.main.arendavu then
            cfg.stata.salar = cfg.stata.salar - money
            save()
        end
    end
    if text:find('%[Аренда%] Вы успешно взяли предмет (.+) в аренду на (%d+) часов за (%d+)') then
        local name, time, money = text:match('%[Аренда%] Вы успешно взяли предмет (.+) в аренду на (%d+) часов за (%d+)')
        if cfg.main.arendavu then
            cfg.stata.salar = cfg.stata.salar - money
            save()
        end
    end
    if text:find('Вы арендовали аксессуар в киоске: (.+) на (%d+)ч за (%d+)') then
        local name, time, money = text:match('Вы арендовали аксессуар в киоске: (.+) на (%d+)ч за (%d+)')
        if cfg.main.arendavu then
            cfg.stata.salar = cfg.stata.salar - money
            save()
        end
    end
    if text:find('Вы успешно приехали к месту назначения') then
        stopTimer()
    end
end

function sampev.onShowDialog(did, style, title, button1, button2, text)
    if title:find('Развозчик продуктов') then
        if text:find('Вы успешно взяли заказ') then
            startTimer()
        end
    end
    if cfg.main.skip then
        if title:find('Развозчик продуктов') then
            if not text:find('Склад') then
                sampSendDialogResponse(did, 1, 0, 0)
                return false
            end
        end
    end
end

function startTimer()
    if not isRunning then
        startTime = os.time()
        isRunning = true
        tripTime = 0
    end
end

function stopTimer()
    if isRunning then
        tripTime = os.time() - startTime
        isRunning = false
    end
end

function getTripTime()
    if isRunning then
        return os.time() - startTime
    else
        return tripTime
    end
end

function clock(sec)
    return os.date('%M:%S',sec)
end

function msg(text)
    sampAddChatMessage('[ProductHelper]: {FFFFFF}'..text, 0xC7A92E)
end


ffi.cdef[[
    void _Z12AND_OpenLinkPKc(const char* link);
]]
function openLink(link)
    gta._Z12AND_OpenLinkPKc(link)
end

function downloadFile(url, path)
    local response = {}
    local _, status_code, _ = http.request{
    url = url,
    method = "GET",
    sink = ltn12.sink.file(io.open(path, "w")),
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0;Win64) AppleWebkit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.82 Safari/537.36",
        },
    }
    if status_code == 200 then
        return true
    else
        return false
    end
end

function check_update()
    msg('Проверка наличия обновлений...')
    local currentVersionFile = io.open(lmPath, "r")
    local currentVersion = currentVersionFile:read("*a")
    currentVersionFile:close()
    local response = http.request(lmUrl)
    if response and response ~= currentVersion then
        msg("Найдено новое обновление! Вывожу окно для загрузки...")
        found_update[0] = not found_update[0]
    else
        msg("У вас актуальная версия скрипта.")
    end
end

function updateScript(scriptUrl, scriptPath)
    msg("Проверка наличия обновлений...")
    local response = http.request(scriptUrl)
    if response and response ~= currentVersion then
        msg("Обновление...")
        local success = downloadFile(scriptUrl, scriptPath)
        if success then
            msg("Скрипт успешно обновлен. Перезагрузка..")
            thisScript():reload()
        else
            msg("Неизвестная ошибка, не удалось обновить скрипт.")
        end
    else
        msg("Скрипт уже является последней версией.")
    end
end

-------------------------- mimgui decoration --------------------------

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(text).x / 2)
    imgui.Text(text)
end

function sep(n)
    if not n or type(n) ~= "number" then 
        return "0"  
    end
    
    local left, num, right = string.match(tostring(n), '^([^%d]*%d)(%d*)(.-)$')
    if not left then
        return tostring(n)
    end

    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

function imgui.GetMiddleButtonX(count)
    local width = imgui.GetWindowContentRegionWidth() -- ширины контекста окно
    local space = imgui.GetStyle().ItemSpacing.x
    return count == 1 and width or width/count - ((space * (count-1)) / count) -- вернется средние ширины по количеству
end

function DarkTheme()
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

    --==[ BORDER ]==--
    imgui.GetStyle().WindowBorderSize = 1
    imgui.GetStyle().ChildBorderSize = 1
    imgui.GetStyle().PopupBorderSize = 1
    imgui.GetStyle().FrameBorderSize = 1
    imgui.GetStyle().TabBorderSize = 1

    --==[ ROUNDING ]==--
    imgui.GetStyle().WindowRounding = 15
    imgui.GetStyle().ChildRounding = 9
    imgui.GetStyle().FrameRounding = 5
    imgui.GetStyle().PopupRounding = 5
    imgui.GetStyle().ScrollbarRounding = 5
    imgui.GetStyle().GrabRounding = 5
    imgui.GetStyle().TabRounding = 5

    --==[ ALIGN ]==--
    imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().SelectableTextAlign = imgui.ImVec2(0.5, 0.5)
    
    --==[ COLORS ]==--
    imgui.GetStyle().Colors[imgui.Col.Text]                   = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.13, 0.13, 0.13, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Border]                 = imgui.ImVec4(0.25, 0.25, 0.26, 0.54)
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]           = imgui.ImVec4(1, 1, 1, 0.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.51, 0.51, 0.51, 1.00)
    imgui.GetStyle().Colors[imgui.Col.CheckMark]              = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button]                 = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header]                 = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.47, 0.47, 0.47, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Separator]              = imgui.ImVec4(0.13, 0.13, 0.13, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(1.00, 1.00, 1.00, 0.67)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(1.00, 1.00, 1.00, 0.95)
    imgui.GetStyle().Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.28, 0.28, 0.28, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocused]           = imgui.ImVec4(0.07, 0.10, 0.15, 0.97)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive]     = imgui.ImVec4(0.14, 0.26, 0.42, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines]              = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]       = imgui.ImVec4(1.00, 0.43, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]          = imgui.ImVec4(0.90, 0.70, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]   = imgui.ImVec4(1.00, 0.60, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(1.00, 0.00, 0.00, 0.35)
    imgui.GetStyle().Colors[imgui.Col.DragDropTarget]         = imgui.ImVec4(1.00, 1.00, 0.00, 0.90)
    imgui.GetStyle().Colors[imgui.Col.NavHighlight]           = imgui.ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight]  = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg]      = imgui.ImVec4(0.80, 0.80, 0.80, 0.20)
    imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.00, 0.00, 0.00, 0.70)
end

function UI.Init()
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory(0x14) .. '\\lib\\mimgui\\trebucbd.ttf', 16.0, nil, glyph_ranges)
    big = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory(0x14) .. '\\lib\\mimgui\\trebucbd.ttf', 29.0, _, glyph_ranges)
    texte = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory(0x14) .. '\\lib\\mimgui\\trebucbd.ttf', 19.0, _, glyph_ranges)
end

function imgui.ColSeparator(hex,trans)
    local r,g,b = tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
    if tonumber(trans) ~= nil and tonumber(trans) < 101 and tonumber(trans) > 0 then a = trans else a = 100 end
    imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(r/255, g/255, b/255, a/10))
    local colsep = imgui.Separator()
    imgui.PopStyleColor(1)
    return colsep
end

function imgui.TextColoredRGB(text)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local ImVec4 = imgui.ImVec4
    local explode_argb = function(argb)
        local a = bit.band(bit.rshift(argb, 24), 0xFF)
        local r = bit.band(bit.rshift(argb, 16), 0xFF)
        local g = bit.band(bit.rshift(argb, 8), 0xFF)
        local b = bit.band(argb, 0xFF)
        return a, r, g, b
    end
    local getcolor = function(color)
        if color:sub(1, 6):upper() == 'SSSSSS' then
            local r, g, b = colors[1].x, colors[1].y, colors[1].z
            local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
            return ImVec4(r, g, b, a / 255)
        end
        local color = type(color) == 'string' and tonumber(color, 16) or color
        if type(color) ~= 'number' then return end
        local r, g, b, a = explode_argb(color)
        return imgui.ImVec4(r/255, g/255, b/255, a/255)
    end
    local render_text = function(text_)
        for w in text_:gmatch('[^\r\n]+') do
            local text, colors_, m = {}, {}, 1
            w = w:gsub('{(......)}', '{%1FF}')
            while w:find('{........}') do
                local n, k = w:find('{........}')
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end
                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end
            if text[0] then
                for i = 0, #text do
                    imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else imgui.Text(u8(w)) end
        end
    end
    render_text(text)
end

function imgui.ButtonB(label_false, label_true, bool, size)
    local text = bool[0] and label_true or label_false
    
    local clicked
    if size then
        clicked = imgui.Button(text, size)
    else
        clicked = imgui.Button(text)
    end

    if clicked then
        bool[0] = not bool[0]
        return true
    end
    return false
end
--[[
label      - Текст при значении переменной false (Опционально)
label_true - Текст при значении переменной true (Опционально)
bool       - Переменная, которую будет менять кнопка (Требуется)
a_speed    - Скорость анимации (Опционально)
--]]
function imgui.ToggleButton(label, label_true, bool, a_speed)
    local p  = imgui.GetCursorScreenPos()
    local dl = imgui.GetWindowDrawList()
 
    local bebrochka = false

    local label      = label or ""                          -- Текст false
    local label_true = label_true or ""                     -- Текст true
    local h          = imgui.GetTextLineHeightWithSpacing() -- Высота кнопки
    local w          = h * 1.7                              -- Ширина кнопки
    local r          = h / 2                                -- Радиус кружка
    local s          = a_speed or 0.2                       -- Скорость анимации
 
    local function ImSaturate(f)
        return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
    end
 
    local x_begin = bool[0] and 1.0 or 0.0
    local t_begin = bool[0] and 0.0 or 1.0
 
    if LastTime == nil then
        LastTime = {}
    end
    if LastActive == nil then
        LastActive = {}
    end
 
    if imgui.InvisibleButton(label, imgui.ImVec2(w, h)) then
        bool[0] = not bool[0]
        LastTime[label] = os.clock()
        LastActive[label] = true
        bebrochka = true
    end

    if LastActive[label] then
        local time = os.clock() - LastTime[label]
        if time <= s then
            local anim = ImSaturate(time / s)
            x_begin = bool[0] and anim or 1.0 - anim
            t_begin = bool[0] and 1.0 - anim or anim
        else
            LastActive[label] = false
        end
    end
 
    local bg_color = imgui.ImVec4(x_begin * 0.13, x_begin * 0.9, x_begin * 0.13, imgui.IsItemHovered(0) and 0.7 or 0.9) -- Цвет прямоугольника
    local t_color  = imgui.ImVec4(1, 1, 1, x_begin) -- Цвет текста при false
    local t2_color = imgui.ImVec4(1, 1, 1, t_begin) -- Цвет текста при true
 
    dl:AddRectFilled(imgui.ImVec2(p.x, p.y), imgui.ImVec2(p.x + w, p.y + h), imgui.GetColorU32Vec4(bg_color), r)
    dl:AddCircleFilled(imgui.ImVec2(p.x + r + x_begin * (w - r * 2), p.y + r), t_begin < 0.5 and x_begin * r or t_begin * r, imgui.GetColorU32Vec4(imgui.ImVec4(0.9, 0.9, 0.9, 1.0)), r + 5)
    dl:AddText(imgui.ImVec2(p.x + w + r, p.y + r - (r / 2) - (imgui.CalcTextSize(label).y / 4)), imgui.GetColorU32Vec4(t_color), label_true)
    dl:AddText(imgui.ImVec2(p.x + w + r, p.y + r - (r / 2) - (imgui.CalcTextSize(label).y / 4)), imgui.GetColorU32Vec4(t2_color), label)
    return bebrochka
end
function UI.Init()
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory(0x14) .. '\\lib\\mimgui\\trebucbd.ttf', 16.0, nil, glyph_ranges)
    big = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory(0x14) .. '\\lib\\mimgui\\trebucbd.ttf', 29.0, _, glyph_ranges)
    texte = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory(0x14) .. '\\lib\\mimgui\\trebucbd.ttf', 19.0, _, glyph_ranges)
end

function imgui.ColSeparator(hex,trans)
    local r,g,b = tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
    if tonumber(trans) ~= nil and tonumber(trans) < 101 and tonumber(trans) > 0 then a = trans else a = 100 end
    imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(r/255, g/255, b/255, a/10))
    local colsep = imgui.Separator()
    imgui.PopStyleColor(1)
    return colsep
end

function imgui.TextColoredRGB(text)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local ImVec4 = imgui.ImVec4
    local explode_argb = function(argb)
        local a = bit.band(bit.rshift(argb, 24), 0xFF)
        local r = bit.band(bit.rshift(argb, 16), 0xFF)
        local g = bit.band(bit.rshift(argb, 8), 0xFF)
        local b = bit.band(argb, 0xFF)
        return a, r, g, b
    end
    local getcolor = function(color)
        if color:sub(1, 6):upper() == 'SSSSSS' then
            local r, g, b = colors[1].x, colors[1].y, colors[1].z
            local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
            return ImVec4(r, g, b, a / 255)
        end
        local color = type(color) == 'string' and tonumber(color, 16) or color
        if type(color) ~= 'number' then return end
        local r, g, b, a = explode_argb(color)
        return imgui.ImVec4(r/255, g/255, b/255, a/255)
    end
    local render_text = function(text_)
        for w in text_:gmatch('[^\r\n]+') do
            local text, colors_, m = {}, {}, 1
            w = w:gsub('{(......)}', '{%1FF}')
            while w:find('{........}') do
                local n, k = w:find('{........}')
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end
                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end
            if text[0] then
                for i = 0, #text do
                    imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else imgui.Text(u8(w)) end
        end
    end
    render_text(text)
end
imgui.OnInitialize(function()
    DarkTheme()
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 30, config, iconRanges)
    fa.Init()
    UI.Init()
end)