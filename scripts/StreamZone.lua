script_name("StreamZone")
script_author("Theopka")
script_version("2.0")

local sampev = require('lib.samp.events')
local imgui = require('mimgui')
local ffi = require 'ffi'
local sf = require 'sampfuncs'
local gta = ffi.load("GTASA")
local encoding = require("encoding")

encoding.default = 'CP1251'
local u8 = encoding.UTF8
local directIni = 'filename.ini'
local delPlayers = imgui.new.bool(false)
local delCars = imgui.new.bool(false)
local delObjects = imgui.new.bool(false)
local inicfg = require 'inicfg'
local directIni = 'StreamZone.ini'
local ini = inicfg.load(inicfg.load({
	chekbox = {
		delPlayers = false,
		delCars = false,
		delObjects = false,
	}}, directIni))
inicfg.save(ini, directIni)

local Window = imgui.new.bool(false)

local tab = 1 -- в этой переменной будет хранится номер открытой вкладки

function sampev.onVehicleStreamIn()
	if delCars[0] then
		return false
	end
end

function sampev.onPlayerStreamIn()
	if delPlayers[0] then
		return false
	end
end

function sampev.onCreateObject(objectId, data) 
	if delObjects[0] then
		return false
	end
end

if delObjects[0] then
    for _, handle in ipairs(getAllObjects()) do
        deleteObject(handle);
    end
end
if delPlayers[0] then
    for player = 0, 1000 do
        local _, hPed = sampGetCharHandleBySampPlayerId(player)
        if _ then
            RakNet = raknetNewBitStream()
            raknetBitStreamWriteInt16(RakNet, player)
            raknetEmulRpcReceiveBitStream(163, RakNet)
            raknetDeleteBitStream(RakNet)
        end
    end	
end
local cars = getAllVehicles()
if delCars[0] then
    for c = 1, #cars do
        if doesVehicleExist(cars[c]) and not isCharInCar(PLAYER_PED, cars[c]) then
            local _, cid = sampGetVehicleIdByCarHandle(cars[c])
            if _ then
                RakNet = raknetNewBitStream()
                raknetBitStreamWriteInt16(RakNet, cid)
                raknetEmulRpcReceiveBitStream(165, RakNet)
                raknetDeleteBitStream(RakNet)
            end
        end
    end
end



imgui.OnFrame(function() return Window[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500, 500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(400, 120), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'StreamZone || 2.0', Window)
    for numberTab,nameTab in pairs({'Удаление','Инфа'}) do -- создаём и парсим таблицу с названиями будущих вкладок
        if imgui.Button(u8(nameTab), imgui.ImVec2(80,40)) then -- 2ым аргументом настраивается размер кнопок (подробнее в гайде по мимгуи)
            tab = numberTab -- меняем значение переменной tab на номер нажатой кнопки
        end
    end
    imgui.SetCursorPos(imgui.ImVec2(95, 28)) -- [Для декора] Устанавливаем позицию для чайлда ниже
    if imgui.BeginChild('Name##'..tab, imgui.ImVec2(), true) then -- [Для декора] Создаём чайлд в который поместим содержимое
        -- == [Основное] Содержимое вкладок == --
        if tab == 1 then -- если значение tab == 1
            imgui.Checkbox(u8'Убрать игроков', delPlayers)
            imgui.Checkbox(u8'Убрать транспорт', delCars)
            imgui.Checkbox(u8'Убрать объекты', delObjects)
            if delObjects[0] then
                for _, handle in ipairs(getAllObjects()) do
                    deleteObject(handle);
                end
            end
            if delPlayers[0] then
                for player = 0, 1000 do
                    local _, hPed = sampGetCharHandleBySampPlayerId(player)
                    if _ then
                        RakNet = raknetNewBitStream()
                        raknetBitStreamWriteInt16(RakNet, player)
                        raknetEmulRpcReceiveBitStream(163, RakNet)
                        raknetDeleteBitStream(RakNet)
                    end
                end	
            end
            local cars = getAllVehicles()
            if delCars[0] then
                for c = 1, #cars do
                    if doesVehicleExist(cars[c]) and not isCharInCar(PLAYER_PED, cars[c]) then
                        local _, cid = sampGetVehicleIdByCarHandle(cars[c])
                        if _ then
                            RakNet = raknetNewBitStream()
                            raknetBitStreamWriteInt16(RakNet, cid)
                            raknetEmulRpcReceiveBitStream(165, RakNet)
                            raknetDeleteBitStream(RakNet)
                        end
                    end
                end
            end
        elseif tab == 2 then -- если значение tab == 2
            imgui.CenterText(u8"Автор: Theopka")
            imgui.CenterText(u8"Версия: 2.0")
            imgui.CenterText(u8"ТГК: @TheopkaStudio")
            if imgui.Button(u8"Перейти в ТГК", imgui.ImVec2(-1, 25)) then openLink("https://t.me/TheopkaStudio") end
            imgui.Separator()
            imgui.CenterText(u8"История обновления скрипта")
            imgui.CenterText(u8"1.0 - Релиз скрпита")
            imgui.CenterText(u8"1.2 - Фикс вылета сампа")
            imgui.CenterText(u8"2.0 - Добавлено меню")
            imgui.CenterText(u8"Добавлено удаление обьектов")
        end
        -- == [Основное] Содержимое вкладок закончилось == --
        imgui.EndChild()
    end
    imgui.End()
end)
function imgui.CenterText(text)
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX( width / 2 - calc.x / 2 )
    imgui.Text(text)
end


function SoftBlueTheme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    style.WindowRounding = 10.0
    style.ChildRounding = 6.0
    style.FramePadding = imgui.ImVec2(8, 3)
    style.FrameRounding = 8.0
    style.ItemSpacing = imgui.ImVec2(8, 8)
    style.ItemInnerSpacing = imgui.ImVec2(10, 6)
    style.IndentSpacing = 25.0
    style.ScrollbarSize = 13.0
    style.ScrollbarRounding = 12.0
    style.GrabMinSize = 10.0
    style.GrabRounding = 6.0
    style.PopupRounding = 8
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    style.Colors[imgui.Col.Text]                   = imgui.ImVec4(0.90, 0.90, 0.93, 1.00)
    style.Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    style.Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.18, 0.20, 0.22, 0.30)
    style.Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.13, 0.13, 0.15, 1.00)
    style.Colors[imgui.Col.Border]                 = imgui.ImVec4(0.30, 0.30, 0.35, 1.00)
    style.Colors[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    style.Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.18, 0.18, 0.20, 1.00)
    style.Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.25, 0.25, 0.28, 1.00)
    style.Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.TitleBg]                = imgui.ImVec4(0.15, 0.15, 0.17, 1.00)
    style.Colors[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.10, 0.10, 0.12, 1.00)
    style.Colors[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.15, 0.15, 0.17, 1.00)
    style.Colors[imgui.Col.MenuBarBg]              = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    style.Colors[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    style.Colors[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.30, 0.30, 0.35, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.50, 0.50, 0.55, 1.00)
    style.Colors[imgui.Col.CheckMark]              = imgui.ImVec4(0.70, 0.70, 0.90, 1.00)
    style.Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.70, 0.70, 0.90, 1.00)
    style.Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.80, 0.80, 0.90, 1.00)
    style.Colors[imgui.Col.Button]                 = imgui.ImVec4(0.18, 0.18, 0.20, 1.00)
    style.Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.60, 0.60, 0.90, 1.00)
    style.Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.28, 0.56, 0.96, 1.00)
    style.Colors[imgui.Col.Header]                 = imgui.ImVec4(0.20, 0.20, 0.23, 1.00)
    style.Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.25, 0.25, 0.28, 1.00)
    style.Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.Separator]              = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.50, 0.50, 0.55, 1.00)
    style.Colors[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.60, 0.60, 0.65, 1.00)
    style.Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(0.20, 0.20, 0.23, 1.00)
    style.Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(0.25, 0.25, 0.28, 1.00)
    style.Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.PlotLines]              = imgui.ImVec4(0.61, 0.61, 0.64, 1.00)
    style.Colors[imgui.Col.PlotLinesHovered]       = imgui.ImVec4(0.70, 0.70, 0.75, 1.00)
    style.Colors[imgui.Col.PlotHistogram]          = imgui.ImVec4(0.61, 0.61, 0.64, 1.00)
    style.Colors[imgui.Col.PlotHistogramHovered]   = imgui.ImVec4(0.70, 0.70, 0.75, 1.00)
    style.Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.10, 0.10, 0.12, 0.80)
    style.Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.18, 0.20, 0.22, 1.00)
    style.Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.60, 0.60, 0.90, 1.00)
    style.Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.28, 0.56, 0.96, 1.00)
end

imgui.OnInitialize(function()
    SoftBlueTheme()
    imgui.GetIO().IniFilename = nil
end)

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('sz', function()
        Window[0] = not Window[0]
    end)
    repeat wait(0) until sampIsLocalPlayerSpawned()
    show_arz_notify('success', 'StreamZone', 'Активация: /sz', 9000)
    wait(-1)
end
ffi.cdef[[
    void _Z12AND_OpenLinkPKc(const char* link);
]]

function openLink(link)
    gta._Z12AND_OpenLinkPKc(link)
end

function show_arz_notify(type, title, text, time)
    if MONET_VERSION ~= nil then
        if type == 'info' then
            type = 3
        elseif type == 'error' then
            type = 2
        elseif type == 'success' then
            type = 1
        end
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 62)
        raknetBitStreamWriteInt8(bs, 6)
        raknetBitStreamWriteBool(bs, true)
        raknetEmulPacketReceiveBitStream(220, bs)
        raknetDeleteBitStream(bs)
        local json = encodeJson({
            styleInt = type,
            title = title,
            text = text,
            duration = time
        })
        local interfaceid = 6
        local subid = 0
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 84)
        raknetBitStreamWriteInt8(bs, interfaceid)
        raknetBitStreamWriteInt8(bs, subid)
        raknetBitStreamWriteInt32(bs, #json)
        raknetBitStreamWriteString(bs, json)
        raknetEmulPacketReceiveBitStream(220, bs)
        raknetDeleteBitStream(bs)
    else
        local str = ('window.executeEvent(\'event.notify.initialize\', \'["%s", "%s", "%s", "%s"]\');'):format(type, title, text, time)
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 17)
        raknetBitStreamWriteInt32(bs, 0)
        raknetBitStreamWriteInt32(bs, #str)
        raknetBitStreamWriteString(bs, str)
        raknetEmulPacketReceiveBitStream(220, bs)
        raknetDeleteBitStream(bs)
    end
end