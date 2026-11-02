local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local new = imgui.new
require 'lib.moonloader'
local ffi = require 'ffi'
local sampev = require 'lib.samp.events'
local faicons = require('fAwesome6')
local inicfg = require 'inicfg'

 local ini = inicfg.load({
    cfg ={
        boolGiveaz = 1,
        boolGivemoney = 124000,
        Settings = false,
        moneycfg = false,
        azcfg = false,
        viborts = false,
        autoput = false,
        autoalt = false,
        zarmon = 0,
        azzar = 0,
        skipi = false,
        boshkiini = 0,
        boshkamenu = false,
    },
    knopa = {
        pochinka = false,   
        fillcar = false,   
        dveri = false,   
        key = false,   
        armours = false,   
        maska = false, 
        sportil = false,
    }
}, "OilHelper.ini")

-- Фикс для конфигов
if ini.cfg.autoput == nil then ini.cfg.autoput = false end
if ini.cfg.autoalt == nil then ini.cfg.autoalt = false end

local zarmonsesia = 0
local azzarsesia = 0
local boxhkosesia = 0
local trigger_alt = false -- Переменная для синхронизации пакета

local pochinka = imgui.new.bool(ini.knopa.pochinka)	
local fillcar = imgui.new.bool(ini.knopa.fillcar)
local dveri = imgui.new.bool(ini.knopa.dveri)	
local key = imgui.new.bool(ini.knopa.key)
local armours = imgui.new.bool(ini.knopa.armours)
local maska = imgui.new.bool(ini.knopa.maska)
local sportil = imgui.new.bool(ini.knopa.sportil)

local renderWindow = imgui.new.bool(false)
local Dipiokno = imgui.new.bool(false)
local OilStats = imgui.new.bool(false)
local Settings = imgui.new.bool(ini.cfg.Settings)
local moneycfg = imgui.new.bool(ini.cfg.moneycfg)
local azcfg = imgui.new.bool(ini.cfg.azcfg)
local skipi = imgui.new.bool(ini.cfg.skipi)
local viborts = imgui.new.bool(ini.cfg.viborts)
local autoput = imgui.new.bool(ini.cfg.autoput)
local autoalt = imgui.new.bool(ini.cfg.autoalt)
local boshkamenu = imgui.new.bool(ini.cfg.boshkamenu)
local infobarik = imgui.new.bool(false)
local boolGiveaz = imgui.new.int(ini.cfg.boolGiveaz)
local boolGivemoney = imgui.new.int(ini.cfg.boolGivemoney)

function cfg_save()
    inicfg.save(ini, "OilHelper.ini")
end

function deleteAll()
    azzarsesia, zarmonsesia, boxhkosesia = 0, 0, 0
    ini.cfg.azzar, ini.cfg.zarmon, ini.cfg.boshkiini = 0, 0, 0
    cfg_save()
    sampAddChatMessage('{006600}[Oil Tools]: {FFFFFF}Статистика сброшена', -1)
end

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowWidth()/2-imgui.CalcTextSize(u8(text)).x/2)
    imgui.Text(u8(text))
end

imgui.OnFrame(function() return renderWindow[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500,500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin('##Main Window', renderWindow, imgui.WindowFlags.NoTitleBar) 
    if imgui.BeginTabBar('Menu') then
        if imgui.BeginTabItem(u8' Основное') then
            if imgui.Checkbox(u8' Статистика', infobarik) then OilStats[0] = not OilStats[0] end		
            if imgui.Checkbox(u8' Настройки', Settings) then ini.cfg.Settings = Settings[0] cfg_save() end
            imgui.Separator()
            if ini.cfg.Settings then
                imgui.CenterText('Настройки:') 
                if imgui.Checkbox(u8' Заработанные вирты', moneycfg) then ini.cfg.moneycfg = moneycfg[0] cfg_save() end
                if imgui.Checkbox(u8' Заработанные AZ-Coins', azcfg) then ini.cfg.azcfg = azcfg[0] cfg_save() end 
                if imgui.Checkbox(u8'Кол-во проданных бочек', boshkamenu) then ini.cfg.boshkamenu = boshkamenu[0] cfg_save() end
                imgui.Text(u8'Другое')         
                if imgui.Checkbox(u8'Авто-покупка (Спам Alt)', autoalt) then ini.cfg.autoalt = autoalt[0] cfg_save() end 
                if imgui.Checkbox(u8'Скрыть диалог покупки', skipi) then ini.cfg.skipi = skipi[0] cfg_save() end
                if imgui.Checkbox(u8'Авто-выгрузка (Забрать)', viborts) then ini.cfg.viborts = viborts[0] cfg_save() end 
                if imgui.Checkbox(u8'Авто-погрузка (Положить)', autoput) then ini.cfg.autoput = autoput[0] cfg_save() end 
            end 
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(u8' Статистика') then
            imgui.Text(u8'За сессию:')
            imgui.Text(u8'AZ: '..azzarsesia..' | Вирт: '..zarmonsesia..' | Бочек: '..boxhkosesia)
            imgui.Separator()
            imgui.Text(u8'За всё время:')
            imgui.Text(u8'AZ: '..ini.cfg.azzar..' | Вирт: '..ini.cfg.zarmon..' | Бочек: '..ini.cfg.boshkiini)
            if imgui.Button(u8' Очистить статистику', imgui.ImVec2(-1, 30)) then deleteAll() end
            imgui.PushItemWidth(150)
            if imgui.InputInt(u8'AZ за бочку', boolGiveaz) then ini.cfg.boolGiveaz = boolGiveaz[0] cfg_save() end
            if imgui.InputInt(u8'$ за бочку', boolGivemoney) then ini.cfg.boolGivemoney = boolGivemoney[0] cfg_save() end
            imgui.PopItemWidth()
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(u8' Дополнительно') then
            imgui.Checkbox(u8' Дополнительное окно кнопок', Dipiokno)
            if imgui.Checkbox(u8'Починка', pochinka) then ini.knopa.pochinka = pochinka[0] cfg_save() end 
            if imgui.Checkbox(u8'Заправка', fillcar) then ini.knopa.fillcar = fillcar[0] cfg_save() end 
            if imgui.Checkbox(u8'Ключи', key) then ini.knopa.key = key[0] cfg_save() end 
            if imgui.Checkbox(u8'Двери', dveri) then ini.knopa.dveri = dveri[0] cfg_save() end 
            if imgui.Checkbox(u8'Броня', armours) then ini.knopa.armours = armours[0] cfg_save() end 
            if imgui.Checkbox(u8'Маска', maska) then ini.knopa.maska = maska[0] cfg_save() end 
            if imgui.Checkbox(u8'Спорт', sportil) then ini.knopa.sportil = sportil[0] cfg_save() end 
            imgui.EndTabItem()
        end
        imgui.EndTabBar()
    end
    imgui.End()
end)

imgui.OnFrame(function() return OilStats[0] end, function(player)
    imgui.Begin('##OilStatsBar', OilStats, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar)
    if ini.cfg.moneycfg then imgui.Text(u8'Вирты: '..ini.cfg.zarmon..'$') end
    if ini.cfg.azcfg then imgui.Text(u8'AZ: '..ini.cfg.azzar) end
    if ini.cfg.boshkamenu then imgui.Text(u8'Бочек: '..ini.cfg.boshkiini) end
    imgui.End()
end)

imgui.OnFrame(function() return Dipiokno[0] end, function(player)
    imgui.Begin('##FastButtons', Dipiokno, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar)
    local btns = {
        {ini.knopa.pochinka, 'Починка', '/repcar'}, {ini.knopa.fillcar, 'Заправка', '/fillcar'},
        {ini.knopa.key, 'Ключи', '/key'}, {ini.knopa.dveri, 'Двери', '/lock'},
        {ini.knopa.maska, 'Маска', '/mask'}, {ini.knopa.armours, 'Броня', '/armour'},
        {ini.knopa.sportil, 'Спорт', '/style'}
    }
    for _, btn in ipairs(btns) do
        if btn[1] then
            if imgui.Button(u8(btn[2]), imgui.ImVec2(100, 30)) then sampSendChat(btn[3]) end
            imgui.SameLine()
        end
    end
    imgui.End()
end)

-- Перехват пакетов синхронизации (Логика ALT из Button Creator)
function sampev.onSendPlayerSync(data)
    if trigger_alt then
        data.keys.unknown_walkSlow = 1 -- Отправляем серверу нажатие ALT
        trigger_alt = false
    end
end

function sampev.onServerMessage(color, text)
    if text:match('Вы успешно продали бочку') then
        ini.cfg.zarmon = ini.cfg.zarmon + boolGivemoney[0]
        zarmonsesia = zarmonsesia + boolGivemoney[0]
        azzarsesia = azzarsesia + 1
        ini.cfg.azzar = ini.cfg.azzar + 1      
        boxhkosesia = boxhkosesia + 1
        ini.cfg.boshkiini = ini.cfg.boshkiini + 1
        cfg_save()
    end
end 

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if skipi[0] and title:find("Покупка бочки") then
        sampSendDialogResponse(id, 1, 0, "")
        return false
    end
    if title:find('Бочки в транспорте') then
        for line in text:gmatch('([^\n\r]+)') do
            local clean = line:gsub('{......}', '')
            local num, status = clean:match('№(%d+)%s+(.+)')
            if num and status then
                if viborts[0] and status:find('Забрать') then
                    sampSendDialogResponse(id, 1, tonumber(num)-1, "")
                    return false
                elseif autoput[0] and status:find('Положить') then
                    sampSendDialogResponse(id, 1, tonumber(num)-1, "")
                    return false
                end
            end
        end 
    end 
end 

imgui.OnInitialize(function()
    theme()
    imgui.GetIO().IniFilename = nil
end)

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('oilh', function() renderWindow[0] = not renderWindow[0] end)
    sampRegisterChatCommand('oil', function() sampSendChat('/oilgroundlist') end)
    
    -- Спам пакета ALT
    while true do
        wait(0) 
        if autoalt[0] then
            trigger_alt = true -- Даем сигнал отправить пакет
            wait(1000)         -- Ждем 1 секунду перед следующим
        end
    end
end

function theme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    style.WindowPadding = imgui.ImVec2(10, 10)
    style.FramePadding = imgui.ImVec2(5, 5)
    style.ItemSpacing = imgui.ImVec2(5, 5)
    style.WindowRounding = 10
    style.FrameRounding = 5
    style.Colors[imgui.Col.WindowBg] = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    style.Colors[imgui.Col.Button] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    style.Colors[imgui.Col.Header] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
end
