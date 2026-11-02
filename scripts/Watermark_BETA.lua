local imgui = require 'mimgui'
local encoding = require 'encoding'
local inicfg = require 'inicfg'
local ffi = require 'ffi'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Цвета
local c_grey = "{D3D3D3}"
local c_red = "{8B0000}"

-- Пути
local configPath = getWorkingDirectory().."/config/"
local iniFile = configPath .. "watermark_cnfg.ini"
local workDir = getWorkingDirectory() .. "/WatermarkPhoto/"

if not doesDirectoryExist(configPath) then createDirectory(configPath) end
if not doesDirectoryExist(workDir) then createDirectory(workDir) end

local default_config = {
    main = {
        posX = 50.0,
        posY = 50.0,
        updateMS = 500,
        textSize = 1.0,
        imageSize = 45.0,
        showBg = true,
        style = 0
    }
}

local mainIni = inicfg.load(default_config, iniFile)

-- ПЕРЕМЕННЫЕ
local menuWindow = imgui.new.bool(false)
local posX = imgui.new.float(mainIni.main.posX)
local posY = imgui.new.float(mainIni.main.posY)
local updateMS = imgui.new.int(mainIni.main.updateMS)
local textSize = imgui.new.float(mainIni.main.textSize)
local imageSize = imgui.new.float(mainIni.main.imageSize)
local showBg = imgui.new.bool(mainIni.main.showBg)
local currentStyle = imgui.new.int(mainIni.main.style)

local styles_names = {u8"Стиль 1", u8"Стиль 2"}

local myTexture = nil
local curFps, curPing = 0, 0
local lastServer = u8"RODINA RP"
local lastUpdate = os.clock() * 1000

-- Функция определения сервера с кэшированием (чтобы не пропадало на x64)
local function getServerName()
    if isSampAvailable() then
        local ip, port = sampGetCurrentServerAddress()
        if ip and ip ~= "" then
            local servers = {
                ["185.169.134.61"] = u8"ЦЕНТРАЛЬНЫЙ ОКРУГ",
                ["185.169.134.62"] = u8"ЮЖНЫЙ ОКРУГ",
                ["185.169.134.107"] = u8"СЕВЕРНЫЙ ОКРУГ",
                ["185.169.134.109"] = u8"ВОСТОЧНЫЙ ОКРУГ",
                ["185.169.134.110"] = u8"ЗАПАДНЫЙ ОКРУГ",
                ["185.169.134.111"] = u8"ПРИМОРСКИЙ ОКРУГ"
            }
            if servers[ip] then 
                lastServer = servers[ip]
            end
        end
    end
    return lastServer
end

local function getBattery()
    local success, jni = pcall(require, "android.jnienv-util")
    if success then
        local batteryManager = jni.GetSystemService(jni.SystemService.BATTERY_SERVICE)
        if batteryManager then
            return jni.CallIntMethod(batteryManager, "getIntProperty", "(I)I", ffi.new("jint", 4))
        end
    end
    return 100
end

function setupPhoto()
    myTexture = nil 
    local paths = {"WatermarkPhoto.png", "WatermarkPhoto.jpg", "WatermarkPhoto.jpeg"}
    for _, name in ipairs(paths) do
        if doesFileExist(workDir .. name) then
            local status, res = pcall(imgui.CreateTextureFromFile, workDir .. name)
            if status then myTexture = res end
            break
        end
    end
end

imgui.OnInitialize(function()
    setupPhoto()
end)

imgui.OnFrame(function() return not isPauseMenuActive() end, function()
    local now = os.clock() * 1000
    local diff = now - lastUpdate
    if diff >= tonumber(updateMS[0]) or diff < 0 then
        curFps = math.floor(imgui.GetIO().Framerate)
        if isSampAvailable() then
            local result, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            if result and id ~= -1 then
                local p = sampGetPlayerPing(id)
                if p and p >= 0 then curPing = p end
            end
        end
        lastUpdate = now
    end

    local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + 
                  imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoMove + 
                  imgui.WindowFlags.NoInputs
    
    if not showBg[0] then flags = flags + imgui.WindowFlags.NoBackground end

    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 12.0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(12, 8))
    
    imgui.SetNextWindowPos(imgui.ImVec2(posX[0], posY[0]), imgui.Cond.Always)
    
    if imgui.Begin("##WtmrkDraw", nil, flags) then
        imgui.SetWindowFontScale(textSize[0])
        
        if currentStyle[0] == 0 then
            if myTexture then
                imgui.Image(myTexture, imgui.ImVec2(imageSize[0], imageSize[0])) 
                imgui.SameLine(nil, 10)
            end
            imgui.BeginGroup()
            imgui.TextColored(imgui.ImVec4(0, 1, 0, 1), string.format("FPS: %d", curFps))
            imgui.TextColored(imgui.ImVec4(1, 1, 1, 1), string.format("PING: %d", curPing))
            imgui.EndGroup()
        else
            local draw = imgui.GetWindowDrawList()
            local p = imgui.GetWindowPos()
            local s = imgui.GetWindowSize()
            
            draw:AddRectFilled(imgui.ImVec2(p.x + 12, p.y), imgui.ImVec2(p.x + s.x - 12, p.y + 3), imgui.GetColorU32(imgui.Col.CheckMark), 10)
            
            imgui.TextColored(imgui.ImVec4(0.40, 0.60, 1.00, 1.00), getServerName())
            imgui.SameLine(); imgui.TextDisabled("|")
            imgui.SameLine(); imgui.Text("t.me/Size1338")
            imgui.SameLine(); imgui.TextDisabled("|")
            
            -- ТЕКСТОВЫЕ ОБОЗНАЧЕНИЯ БЕЗ СИМВОЛОВ
            imgui.SameLine(); imgui.TextColored(imgui.ImVec4(0.40, 1.00, 0.40, 1.00), "BATT:")
            imgui.SameLine(nil, 3); imgui.Text(string.format("%d%%", getBattery()))
            
            imgui.SameLine(); imgui.TextColored(imgui.ImVec4(1.00, 0.40, 0.40, 1.00), "FPS:")
            imgui.SameLine(nil, 3); imgui.Text(string.format("%d", curFps))
            
            imgui.SameLine(); imgui.TextColored(imgui.ImVec4(0.40, 0.60, 1.00, 1.00), "PING:")
            imgui.SameLine(nil, 3); imgui.Text(string.format("%d", curPing))
        end

        imgui.SetWindowFontScale(1.0)
        imgui.End()
    end
    imgui.PopStyleVar(2)
end)

imgui.OnFrame(function() return menuWindow[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(500, 480), imgui.Cond.FirstUseEver)
    if imgui.Begin(u8"Watermark | tgk: t.me/Size1338.", menuWindow) then
        
        local changed = false
        if imgui.SliderFloat(u8"Позиция X", posX, 0, 2500) then changed = true end
        if imgui.SliderFloat(u8"Позиция Y", posY, 0, 1200) then changed = true end
        if imgui.SliderInt(u8"Обновление (мс)", updateMS, 100, 5000) then changed = true end
        if imgui.SliderFloat(u8"Размер текста", textSize, 0.5, 3.0) then changed = true end
        
        if currentStyle[0] == 0 then
            if imgui.SliderFloat(u8"Размер фото", imageSize, 10, 200) then changed = true end
        end

        imgui.Separator()
        if imgui.Checkbox(u8"Включить/выключить бекграунд", showBg) then changed = true end
        
        if imgui.BeginCombo(u8"Стиль отображения", styles_names[currentStyle[0] + 1]) then
            for i, name in ipairs(styles_names) do
                if imgui.Selectable(name, (i - 1) == currentStyle[0]) then
                    currentStyle[0] = i - 1
                    changed = true
                end
            end
            imgui.EndCombo()
        end

        if changed then
            mainIni.main = {
                posX = math.floor(posX[0]), 
                posY = math.floor(posY[0]),
                updateMS = math.floor(updateMS[0]), 
                textSize = tonumber(string.format("%.1f", textSize[0])),
                imageSize = math.floor(imageSize[0]), 
                showBg = showBg[0],
                style = tonumber(currentStyle[0])
            }
            inicfg.save(mainIni, iniFile)
        end
        
        imgui.Separator()
        if imgui.Button(u8"Обновить картинку.", imgui.ImVec2(-1, 40)) then setupPhoto() end
        imgui.TextDisabled(u8"Закиньте изображение по пути Android/media/com.rodina.game/WatermarkPhoto. Изображение должно быть формата png/jpg/jpeg.")
        imgui.TextDisabled(u8"Автор скрипта: @GENOZED, тгк: t.me/Size1338, сабайтесь.")
        imgui.End()
    end
end)

function main()
    while not isSampAvailable() do wait(100) end
    sampRegisterChatCommand("wtmrk", function() menuWindow[0] = not menuWindow[0] end)
    sampAddChatMessage(c_grey .. "[Watermark] " .. c_red .. "Загружен! " .. c_grey .. "/wtmrk", -1)
    wait(-1)
end
