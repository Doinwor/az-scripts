script_name('Visual GM')

local cmd_visual = 'vgm'

--settings
----------------------------------------------------
local author = 'Chapo'
local color = '{ab0062}' --основной цвет текста(-ов)
----------------------------------------------------

local inicfg = require 'inicfg'

local directIni = 'VisualGM.ini'
local ini = inicfg.load({
    main = {
        enabled_visual = false
    }
}, directIni)
inicfg.save(ini, directIni)

local enabled_visual = ini.main.enabled_visual

local function loadConfig()
    ini = inicfg.load({
        main = {
            enabled_visual = false
        }
    }, directIni)
    enabled_visual = ini.main.enabled_visual
end

local function saveConfig()
    ini.main.enabled_visual = enabled_visual
    inicfg.save(ini, directIni)
end

local function safeCall(fn, ...)
    if type(_G[fn]) ~= 'function' then return nil end
    local ok, result = pcall(_G[fn], ...)
    if ok then return result end
    return nil
end

local function isRegularCar()
    if safeCall('isCharInAnyBoat', PLAYER_PED) == true then return false end
    if safeCall('isCharOnAnyBike', PLAYER_PED) == true then return false end
    if safeCall('isCharOnAnyMotorbike', PLAYER_PED) == true then return false end
    if safeCall('isCharInAnyPlane', PLAYER_PED) == true then return false end
    if safeCall('isCharInAnyHeli', PLAYER_PED) == true then return false end
    return true
end

function main()
    while not isSampAvailable() do wait(0) end

    loadConfig()

    sampRegisterChatCommand(cmd_visual, cmd_visual_f)

    while true do
        wait(0)
        if enabled_visual and isCharInAnyCar(PLAYER_PED) and isRegularCar() then
            local v = storeCarCharIsInNoSave(PLAYER_PED)
            if v ~= nil and v ~= 0 and doesVehicleExist(v) then
                for i = 0, 5 do pcall(fixCarDoor, v, i) end
                for i = 0, 6 do pcall(fixCarPanel, v, i) end
            end
        end
    end
end

function cmd_visual_f()
    enabled_visual = not enabled_visual
    saveConfig()

    if enabled_visual then
        msg('включен!')
    else
        msg('выключен!')
    end
end


function msg(text)
    if text ~= nil then
        sampAddChatMessage(color..'['..thisScript().name..']: {ffffff} '..text, -1)
    else
        print(color..'['..thisScript().name..']: {ffffff} chapoMessageError: no text!'..text)
    end
end