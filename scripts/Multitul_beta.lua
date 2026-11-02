script_name("Arizona Myltityl - Полный пак")
script_author("SkriptNaArz")
script_version("5.0")

local imgui = require 'mimgui'
local ffi = require 'ffi'
local new = imgui.new
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local inicfg = require 'inicfg'
local sampev = require "samp.events"

local base_path = "/storage/emulated/0/Android/media/com.arizona.game/monetloader/"

local autodoor_enabled = true

local function isMonetLoader()
    return MONET_VERSION ~= nil
end

local function sendKeyH()
    if isCharInAnyCar(PLAYER_PED) then
        setGameKeyState(18, 255)
    else
        local data = allocateMemory(68)
        local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        sampStorePlayerOnfootData(myId, data)
        local weaponId = getCurrentCharWeapon(PLAYER_PED)
        setStructElement(data, 36, 1, weaponId + 192, true)
        sampSendOnfootData(data)
        freeMemory(data)
    end
end

local function autodoor_process()
    for key, hObj in pairs(getAllObjects()) do
        if doesObjectExist(hObj) then
            local objModel = getObjectModel(hObj)
            local res, ox, oy, oz = getObjectCoordinates(hObj)
            local objHeading = getObjectHeading(hObj)
            local px, py, pz = getCharCoordinates(PLAYER_PED)
            local distance = getDistanceBetweenCoords3d(px, py, pz, ox, oy, oz)
            
            if objModel == 1495 or objModel == 3089 or objModel == 1561 or objModel == 19938 or objModel == 1557 or objModel == 1808 or objModel == 19857 or objModel == 19302 or objModel == 2634 or objModel == 19303 then
                if (objHeading > 179 and objHeading < 181) or (objHeading > 89 and objHeading < 91) or (objHeading > -1 and objHeading < 1) or (objHeading > 269 and objHeading < 271) then
                    if distance <= 2 then
                        if isMonetLoader() then
                            local bs = raknetNewBitStream()
                            raknetBitStreamWriteInt8(bs, 220)
                            raknetBitStreamWriteInt8(bs, 63)
                            raknetBitStreamWriteInt8(bs, 8)
                            raknetBitStreamWriteInt32(bs, 7)
                            raknetBitStreamWriteInt32(bs, -1)
                            raknetBitStreamWriteInt32(bs, 0)
                            raknetBitStreamWriteString(bs, "")
                            raknetSendBitStreamEx(bs, 1, 7, 1)
                            raknetDeleteBitStream(bs)
                        else
                            sendKeyH()
                        end
                        return
                    end
                end
            elseif objModel == 968 or objModel == 975 or objModel == 1374 or objModel == 19912 or objModel == 988 or objModel == 19313 or objModel == 11327 or objModel == 980 then
                if distance < (isCharInAnyCar(PLAYER_PED) and 12 or 5) then
                    if isMonetLoader() then
                        local bs = raknetNewBitStream()
                        raknetBitStreamWriteInt8(bs, 220)
                        raknetBitStreamWriteInt8(bs, 63)
                        raknetBitStreamWriteInt8(bs, 8)
                        raknetBitStreamWriteInt32(bs, 7)
                        raknetBitStreamWriteInt32(bs, -1)
                        raknetBitStreamWriteInt32(bs, 0)
                        raknetBitStreamWriteString(bs, "")
                        raknetSendBitStreamEx(bs, 1, 7, 1)
                        raknetDeleteBitStream(bs)
                    else
                        sendKeyH()
                    end
                    return
                end
            end
        end
    end
end

local autoform_settings = {
    enabled = true
}
local autoform_filename = base_path .. "afkZP.ini"
local autoform_pickupId = -1

local function autoform_load_settings()
    local file = io.open(autoform_filename, "r")
    if file then
        local content = file:read("*a")
        file:close()
        if content and #content > 0 then
            local enabled = content:match("enabled=(true|false)")
            if enabled == "true" then autoform_settings.enabled = true
            elseif enabled == "false" then autoform_settings.enabled = false end
        end
    end
end

local function autoform_save_settings()
    local file = io.open(autoform_filename, "w")
    if file then
        file:write("enabled=" .. tostring(autoform_settings.enabled))
        file:close()
    end
end

local function autoform_pick()
    lua_thread.create(function()
        wait(2000)
        sampSendPickedUpPickup(autoform_pickupId)
    end)
end

local ctime_config_path = base_path .. "time_config.ini"
local ctime_config = {
    activate = true,
    x = 120,
    y = 400,
    color = "FFFFFF",
    msColor = "FFFFFF",
    fontsize = 19,
    showMilliseconds = false
}
local ctime_font = nil

local function ctime_loadConfig()
    local file = io.open(ctime_config_path, "r")
    if file then
        for line in file:lines() do
            local key, value = line:match("([^=]+)=(.+)")
            if key and value then
                key = key:gsub("^%s*(.-)%s*$", "%1")
                value = value:gsub("^%s*(.-)%s*$", "%1")
                
                if key == "activate" then ctime_config.activate = (value == "true")
                elseif key == "x" then ctime_config.x = tonumber(value) or ctime_config.x
                elseif key == "y" then ctime_config.y = tonumber(value) or ctime_config.y
                elseif key == "color" then ctime_config.color = value
                elseif key == "msColor" then ctime_config.msColor = value
                elseif key == "fontsize" then ctime_config.fontsize = tonumber(value) or ctime_config.fontsize
                elseif key == "showMilliseconds" then ctime_config.showMilliseconds = (value == "true")
                end
            end
        end
        file:close()
    end
end

local function ctime_saveConfig()
    local file = io.open(ctime_config_path, "w")
    if file then
        file:write("activate=" .. tostring(ctime_config.activate) .. "\n")
        file:write("x=" .. ctime_config.x .. "\n")
        file:write("y=" .. ctime_config.y .. "\n")
        file:write("color=" .. ctime_config.color .. "\n")
        file:write("msColor=" .. ctime_config.msColor .. "\n")
        file:write("fontsize=" .. ctime_config.fontsize .. "\n")
        file:write("showMilliseconds=" .. tostring(ctime_config.showMilliseconds) .. "\n")
        file:close()
        return true
    end
    return false
end

local function ctime_chatmsg(text)
    sampAddChatMessage("{FFC93E}[cTime]: {FFFFFF}" .. text, -1)
end

local function ctime_draw()
    if not ctime_config.activate then return end
    
    if not ctime_font then
        ctime_font = renderCreateFont("Arial", ctime_config.fontsize, 5)
    end
    
    local date_table = os.date("*t")
    local hour, minute, second = date_table.hour, date_table.min, date_table.sec
    
    local result
    if ctime_config.showMilliseconds then
        local ms = tostring(math.ceil(socket.gettime()*1000))
        local ms = tonumber(string.sub(ms, #ms-2, #ms))
        result = string.format("%02d:%02d:%02d{%s}.%03d", hour, minute, second, ctime_config.msColor, ms)
    else
        result = string.format("%02d:%02d:%02d", hour, minute, second)
    end

    if ctime_font and ctime_config.x and ctime_config.y then
        renderFontDrawText(ctime_font, result, ctime_config.x, ctime_config.y, "0xFF" .. ctime_config.color)
    end
end

local timeweather_ini = base_path .. "Time & Weather.ini"
local timeweather_settings = {
    my_time = 12,
    my_weather = 1,
    block_time = false,
    block_weather = false
}
local timeweather_current_time = -1
local timeweather_current_weather = -1

local function timeweather_load()
    local file = io.open(timeweather_ini, "r")
    if file then
        for line in file:lines() do
            local key, value = line:match("([^=]+)=(.+)")
            if key and value then
                key = key:gsub("^%s*(.-)%s*$", "%1")
                value = value:gsub("^%s*(.-)%s*$", "%1")
                
                if key == "my_time" then timeweather_settings.my_time = tonumber(value) or 12
                elseif key == "my_weather" then timeweather_settings.my_weather = tonumber(value) or 1
                elseif key == "block_time" then timeweather_settings.block_time = (value == "true")
                elseif key == "block_weather" then timeweather_settings.block_weather = (value == "true")
                end
            end
        end
        file:close()
    end
end

local function timeweather_save()
    local file = io.open(timeweather_ini, "w")
    if file then
        file:write("my_time=" .. timeweather_settings.my_time .. "\n")
        file:write("my_weather=" .. timeweather_settings.my_weather .. "\n")
        file:write("block_time=" .. tostring(timeweather_settings.block_time) .. "\n")
        file:write("block_weather=" .. tostring(timeweather_settings.block_weather) .. "\n")
        file:close()
    end
end

function sampev.onServerMessage(color, text)
    if not autoform_settings.enabled then return end
    if text:find("На сервере есть инвентарь") then
        autoform_pick()
    end
    
    if text:find("У вас нет ключей от данного шлагбаума") or 
       text:find("У вас нет ключей от этого шлагбаума!") or 
       text:find("У вас нет ключей от этой двери!") or 
       text:find("У вас нет ключей от данной двери") then
        sampAddChatMessage("{ff0000}[AutoDoor] У вас нет доступа/ключа для этого обьекта!", -1)
    end
end

function sampev.onCreatePickup(id, model, pickupType, position)
    if model == 1275 then
        autoform_pickupId = id
    end
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if not autoform_settings.enabled then return end

    if id == 15330 and text:find('Мы рады видеть вас на проекте Arizona Role Play.') then
        return false
    end

    if id == 581 then
        if text:find('Переодеться') then
            sampSendDialogResponse(id, 1, 0, "")
            return false
        end
    end
    if id == 7551 then
        if text:find('Переодеться в') and text:find('рабочую') then
            sampSendDialogResponse(id, 1, 0, "")
            sampAddChatMessage("{0000FF}[AFK Zarplata]: {FFCC00}Переодеться в рабочую одежду", -1)
            return false
        end

        if text:find('Переодеться в ') and text:find('свою') then
            sampSendDialogResponse(id, 0, 0, "")
            sampAddChatMessage("{0000FF}[AFK Zarplata]: {FFCC00}Переодеться в свою одежду отменить", -1)
            return false
        end
    end
end

function sampev.onSetWorldTime(hour)
    if not timeweather_settings.block_time then
        timeweather_current_time = hour
    end
end

function sampev.onSetWeather(weatherId)
    if not timeweather_settings.block_weather then
        timeweather_current_weather = weatherId
    end
end

function main()
    while not isSampAvailable() do wait(100) end
    
    autoform_load_settings()
    ctime_loadConfig()
    timeweather_load()
    
    ctime_font = renderCreateFont("Arial", ctime_config.fontsize, 5)
    
    sampRegisterChatCommand("door", function()
        autodoor_enabled = not autodoor_enabled
        sampAddChatMessage("{ff0000}[AutoDoor] {ffffff}Скрипт " .. (autodoor_enabled and "активирован" or "деактивирован"), -1)
    end)
    
    sampRegisterChatCommand("afkzp", function()
        autoform_settings.enabled = not autoform_settings.enabled
        autoform_save_settings()
        sampAddChatMessage("{0000FF}[AFK Zarplata]: {FFCC00}" .. (autoform_settings.enabled and "Включено" or "Выключено"), -1)
    end)
    
    sampRegisterChatCommand("ctime", function()
        lua_thread.create(function()
            local dtext = "Show time on screen\t" .. (ctime_config.activate and "{45d900}ON" or "{ff0000}OFF") 
            dtext = dtext .. "\nFont size:\t" .. ctime_config.fontsize 
            dtext = dtext .. "\nTime color:\t{" .. ctime_config.color .. "}■■■■■■■■■■"
            dtext = dtext .. "\nMS color:\t{" .. ctime_config.msColor .. "}■■■■■■■■■■"
            dtext = dtext .. "\nShow milliseconds\t" .. (ctime_config.showMilliseconds and "{45d900}ON" or "{ff0000}OFF")
            dtext = dtext .. "\nChange position\t x:" .. ctime_config.x .. " y:" .. ctime_config.y
            
            sampShowDialog(10, "cTime Settings", dtext, "OK", "Cancel", 2)
            while sampIsDialogActive(10) do wait(0) end
            local result, button, list, input = sampHasDialogRespond(10)

            if result and button == 1 then
                if list == 0 then
                    ctime_config.activate = not ctime_config.activate
                    ctime_saveConfig()
                    return
                end

                if list == 1 then
                    sampShowDialog(11, "Font Size", "Enter font size:", "OK", "Cancel", 1)
                    while sampIsDialogActive(11) do wait(0) end
                    local result, button, list, input = sampHasDialogRespond(11)
                    if result then
                        if tonumber(input) then
                            ctime_config.fontsize = tonumber(input)
                            ctime_font = renderCreateFont('Arial', ctime_config.fontsize, 5)
                            ctime_saveConfig()
                            return
                        else
                            ctime_chatmsg("Must be number!")
                            return
                        end
                    else
                        return
                    end
                end

                if list == 2 then
                    local color_text = "{FFFFFF}Available colors:\n"
                    color_text = color_text .. "{FF0000}FF0000 {FFFFFF}- Red\n"
                    color_text = color_text .. "{00FF00}00FF00 {FFFFFF}- Green\n"
                    color_text = color_text .. "{0000FF}0000FF {FFFFFF}- Blue\n"
                    color_text = color_text .. "{FFFF00}FFFF00 {FFFFFF}- Yellow\n"
                    color_text = color_text .. "{FF00FF}FF00FF {FFFFFF}- Pink\n"
                    color_text = color_text .. "{00FFFF}00FFFF {FFFFFF}- Cyan\n"
                    color_text = color_text .. "{FFFFFF}FFFFFF {FFFFFF}- White\n"
                    color_text = color_text .. "{FF8800}FF8800 {FFFFFF}- Orange\n"
                    color_text = color_text .. "{8800FF}8800FF {FFFFFF}- Purple\n"
                    color_text = color_text .. "{FF4444}FF4444 {FFFFFF}- Light Red\n"
                    color_text = color_text .. "{44FF44}44FF44 {FFFFFF}- Light Green\n"
                    color_text = color_text .. "{4444FF}4444FF {FFFFFF}- Light Blue\n"
                    color_text = color_text .. "{888888}888888 {FFFFFF}- Gray\n"
                    color_text = color_text .. "{AAAAAA}AAAAAA {FFFFFF}- Light Gray\n"
                    color_text = color_text .. "{666666}666666 {FFFFFF}- Dark Gray\n\n"
                    color_text = color_text .. "{FFFFFF}Current time color: {" .. ctime_config.color .. "}" .. ctime_config.color .. "\n"
                    color_text = color_text .. "{FFFFFF}Enter HEX color (6 symbols):"
                    
                    sampShowDialog(11, "Time Color", color_text, "OK", "Cancel", 1)
                    while sampIsDialogActive(11) do wait(0) end
                    local result, button, list, input = sampHasDialogRespond(11)
                    if result then
                        if input and #input == 6 and not input:match("[^0-9A-Fa-f]") then
                            ctime_config.color = input:upper()
                            ctime_saveConfig()
                            ctime_chatmsg("Time color set to: {" .. input:upper() .. "}" .. input:upper())
                            return
                        else
                            ctime_chatmsg("Wrong HEX format! Use 6 symbols (0-9, A-F)")
                            return
                        end
                    else
                        return
                    end
                end

                if list == 3 then
                    local color_text = "{FFFFFF}Available colors:\n"
                    color_text = color_text .. "{FF0000}FF0000 {FFFFFF}- Red\n"
                    color_text = color_text .. "{00FF00}00FF00 {FFFFFF}- Green\n"
                    color_text = color_text .. "{0000FF}0000FF {FFFFFF}- Blue\n"
                    color_text = color_text .. "{FFFF00}FFFF00 {FFFFFF}- Yellow\n"
                    color_text = color_text .. "{FF00FF}FF00FF {FFFFFF}- Pink\n"
                    color_text = color_text .. "{00FFFF}00FFFF {FFFFFF}- Cyan\n"
                    color_text = color_text .. "{FFFFFF}FFFFFF {FFFFFF}- White\n"
                    color_text = color_text .. "{FF8800}FF8800 {FFFFFF}- Orange\n"
                    color_text = color_text .. "{8800FF}8800FF {FFFFFF}- Purple\n"
                    color_text = color_text .. "{FF4444}FF4444 {FFFFFF}- Light Red\n"
                    color_text = color_text .. "{44FF44}44FF44 {FFFFFF}- Light Green\n"
                    color_text = color_text .. "{4444FF}4444FF {FFFFFF}- Light Blue\n"
                    color_text = color_text .. "{888888}888888 {FFFFFF}- Gray\n"
                    color_text = color_text .. "{AAAAAA}AAAAAA {FFFFFF}- Light Gray\n"
                    color_text = color_text .. "{666666}666666 {FFFFFF}- Dark Gray\n\n"
                    color_text = color_text .. "{FFFFFF}Current MS color: {" .. ctime_config.msColor .. "}" .. ctime_config.msColor .. "\n"
                    color_text = color_text .. "{FFFFFF}Enter HEX color (6 symbols):"
                    
                    sampShowDialog(11, "MS Color", color_text, "OK", "Cancel", 1)
                    while sampIsDialogActive(11) do wait(0) end
                    local result, button, list, input = sampHasDialogRespond(11)
                    if result then
                        if input and #input == 6 and not input:match("[^0-9A-Fa-f]") then
                            ctime_config.msColor = input:upper()
                            ctime_saveConfig()
                            ctime_chatmsg("MS color set to: {" .. input:upper() .. "}" .. input:upper())
                            return
                        else
                            ctime_chatmsg("Wrong HEX format! Use 6 symbols (0-9, A-F)")
                            return
                        end
                    else
                        return
                    end
                end

                if list == 4 then
                    ctime_config.showMilliseconds = not ctime_config.showMilliseconds
                    ctime_saveConfig()
                    ctime_chatmsg("Milliseconds " .. (ctime_config.showMilliseconds and "enabled" or "disabled"))
                    return
                end

                if list == 5 then
                    ctime_chatmsg("Use /ctimepos [x] [y] to set position")
                    ctime_chatmsg("Example: /ctimepos 200 150")
                    ctime_chatmsg("Current position: X=" .. ctime_config.x .. " Y=" .. ctime_config.y)
                end
            end
        end)
    end)
    
    sampRegisterChatCommand("ctimepos", function(param)
        if param then
            local x, y = param:match("(%d+)%s+(%d+)")
            if x and y then
                local newX = tonumber(x)
                local newY = tonumber(y)
                if newX and newY then
                    ctime_config.x = newX
                    ctime_config.y = newY
                    if ctime_saveConfig() then
                        ctime_chatmsg("Position saved! X=" .. newX .. " Y=" .. newY)
                    else
                        ctime_chatmsg("Error saving position!")
                    end
                    return
                end
            end
        end
        ctime_chatmsg("Usage: /ctimepos [x] [y]")
        ctime_chatmsg("Example: /ctimepos 200 150")
        ctime_chatmsg("Current position: X=" .. ctime_config.x .. " Y=" .. ctime_config.y)
    end)
    
    sampRegisterChatCommand("st", function(arg)
        if arg and tonumber(arg) and tonumber(arg) >= 0 and tonumber(arg) <= 23 then
            timeweather_settings.my_time = tonumber(arg)
            timeweather_save()
            sampAddChatMessage("{ff0000}[Time & Weather] {ffffff}Время установлено: " .. arg, -1)
        else
            sampAddChatMessage("{ff0000}[Time & Weather] {ffffff}Используйте /st [0-23]", -1)
        end
    end)
    
    sampRegisterChatCommand("bt", function()
        timeweather_settings.block_time = not timeweather_settings.block_time
        timeweather_save()
        if timeweather_settings.block_time then
            timeweather_current_time = -1
            sampAddChatMessage("{ff0000}[Time & Weather] {ffffff}Сервер не сможет изменить ваше время!", -1)
        else
            sampAddChatMessage("{ff0000}[Time & Weather] {ffffff}Сервер будет изменять вам время!", -1)
        end
    end)
    
    sampRegisterChatCommand("sw", function(arg)
        if arg and tonumber(arg) and tonumber(arg) >= 0 and tonumber(arg) <= 45 then
            timeweather_settings.my_weather = tonumber(arg)
            timeweather_save()
            sampAddChatMessage("{ff0000}[Time & Weather] {ffffff}Погода установлена: " .. arg, -1)
        else
            sampAddChatMessage("{ff0000}[Time & Weather] {ffffff}Используйте /sw [0-45]", -1)
        end
    end)
    
    sampRegisterChatCommand("bw", function()
        timeweather_settings.block_weather = not timeweather_settings.block_weather
        timeweather_save()
        if timeweather_settings.block_weather then
            timeweather_current_weather = -1
            sampAddChatMessage("{ff0000}[Time & Weather] {ffffff}Сервер не сможет изменить вашу погоду!", -1)
        else
            sampAddChatMessage("{ff0000}[Time & Weather] {ffffff}Сервер будет изменять вам погоду!", -1)
        end
    end)
    
    sampRegisterChatCommand("shelp", function()
        sampShowDialog(999999, "Time & Weather", 
            "Установить время: /st [0-23]\n" ..
            "Запретить серверу менять время: /bt\n\n" ..
            "Установить погоду: /sw [0-45]\n" ..
            "Запретить серверу менять погоду: /bw", 
            "Закрыть", '', 0)
    end)
    
    sampAddChatMessage("{00FF00}Все 4 скрипта объединены и загружены!", -1)
    sampAddChatMessage("{FFFF00}Команды: /door, /afkzp, /ctime, /ctimepos, /st, /sw, /bt, /bw, /shelp", -1)
    
    while true do
        wait(0)
        
        if autodoor_enabled and (isMonetLoader() or (not sampIsChatInputActive() and not sampIsDialogActive() and not sampIsCursorActive())) then
            pcall(autodoor_process)
        end
        
        pcall(ctime_draw)
        
        if getActiveInterior() == 0 or getActiveInterior() == 20 then
            if timeweather_current_weather == -1 then
                forceWeatherNow(timeweather_settings.my_weather)
            end
            if timeweather_current_time == -1 then
                setTimeOfDay(timeweather_settings.my_time, 0)
            end
        end
    end
end