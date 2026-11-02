local sampev = require 'lib.samp.events'

function sampev.onSendEnterVehicle(id, pass)
    lua_thread.create(function()
        while not isCharInAnyCar(PLAYER_PED) do wait(0) end
        wait(250)
        sampSendChat('/lock')
        wait(500)
        sampSendChat('/key')
        wait(500)
        sampSendChat('/engine')
    end)
end

function sampev.onSendExitVehicle(id)
    lua_thread.create(function()
        result, carHandle = sampGetCarHandleBySampVehicleId(id)
        if result then
            doorStatus = getCarDoorLockStatus(carHandle)
            if doorStatus == 0 then
                sampSendChat('/lock')
            end
        end

        wait(500)
        if isCharInAnyCar(PLAYER_PED) then 
            sampSendChat('/key') 
        else 
            sampAddChatMessage('not in car', -1) 
        end
    end)
end

--[[
local sampev = require 'lib.samp.events'
local inicfg = require 'inicfg'

local directIni = 'AutoCarByChapo.ini'
local ini = inicfg.load(inicfg.load({
    main = {
        autolock = true,
        autokey = true,
        autostyle = true,
    },
}, directIni))
inicfg.save(ini, directIni)

local commands = {
    ['lock'] = '/lock',
    ['key'] = '/key',
    ['style'] = '/style'
}

local rp = {
    ['car_unlock'] = '/me достал ключи от машины и нажал на кнопку UNLOCK',
    ['car_lock'] = '/me достал ключи от машины и нажал на кнопку LOCK',
}

local ch_autolock = true
local ch_autokey = true
local testmode = true



function main()
    while not isSampAvailable() do wait(200) end
    while not sampIsLocalPlayerSpawned() do wait(0) end
    --sampSendChat('/cars')
    while true do
        wait(0)
        if testCheat('F') then
            for k, v in ipairs(getAllVehicles()) do
                result, id = sampGetVehicleIdByCarHandle(v)
                if result and not isCharInAnyCar(PLAYER_PED) then
                    x, y, z = getCharCoordinates(PLAYER_PED)
                    cx, cy, cz = getCarCoordinates(v)
                    if getDistanceBetweenCoords3d(x, y, z, cx, cy, cz) < 3 then
                        sampSendEnterVehicle(id, false)
                        doorStatus = getCarDoorLockStatus(v)
                        --sampAddChatMessage(doorStatus, -1)
                        if doorStatus ~= 0 then
                            sampSendChat(commands['lock'])
                            if testmode then sampAddChatMessage('', -1) end
                        end
                    end
                end
            end
        end
    end
end

function sampev.onSendEnterVehicle(vehid, pass)
    sampAddChatMessage('enter sended, vehid: '..vehid, -1)
    result, car = sampGetCarHandleBySampVehicleId(vehid)
    if result then
        doorStatus = getCarDoorLockStatus(car)
        if doorStatus == 0 then
            lua_thread.create(function()
                while not isCharInAnyCar(PLAYER_PED) do wait(100) end
                sampSendChat(commands['lock'])
                if testmode then sampAddChatMessage('enter veh, lock', -1) end
                if ch_autokey then
                    sampSendChat(commands['key'])
                    if testmode then sampAddChatMessage('enter veh, key', -1) end
                    wait(250)

                    sampSendChat(commands['style'])
                    if testmode then sampAddChatMessage('enter veh, style', -1) end
                end
            end)  
        end
    end

end

function sampev.onSendExitVehicle(vehid1)
    if isCharInAnyCar(PLAYER_PED) then sampSendChat('key') end
    if testmode then sampAddChatMessage('exit veh, key', -1) end
    
    result1, car1 = sampGetCarHandleBySampVehicleId(vehid1)
    if result1 then
        doorStatus1 = getCarDoorLockStatus(car1)
        if doorStatus1 == 0 then
            lua_thread.create(function()
                while isCharInAnyCar(PLAYER_PED) do wait(100) end
                sampSendChat('lock')
                if testmode then sampAddChatMessage('exit veh, lock', -1) end
            end)
            
            
        end
    end
end



function sampev.onDisplayGameText(style, time, text)
    if text:find('Comfort!') then sampSendChat(commands['style']) end
end
]]