script_name("AutoDoor")
script_author("MTG MODS")
script_version(9)
script_description('Script for Auto Open doors and other objects...')

require "lib.moonloader"

local active = false
local use_autodoor = true

function isMonetLoader() 
	return MONET_VERSION ~= nil 
end

function main()

    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end

	sampAddChatMessage('{ff0000}[INFO] {ffffff}Скрипт "AutoDoor" загружен и готов к работе! Автор: MTG MODS | Версия: ' .. thisScript().version .. ' | Деактивация: {00ccff}/door',-1)
	
    sampRegisterChatCommand('door', function ()
        use_autodoor = not use_autodoor
        sampAddChatMessage('{ff0000}[INFO] {ffffff}Скрипт "AutoDoor" ' .. (use_autodoor and 'активирован и будет открывать двери/шлагбаумы/кпп! Деактивировать: {00ccff}/door' or 'деактивирован и не будет открывать двери/шлагбаумы/кпп! Активировать: {00ccff}/door'),-1)
    end)

	while true do wait(333) 
		if (use_autodoor and ((isMonetLoader()) or (not sampIsChatInputActive() and not sampIsDialogActive() and not isSampfuncsConsoleActive() and not sampIsCursorActive()))) then
            pcall(AutoDoor) 
		end
	end

end

function sendKeyH()
    if isCharInAnyCar(PLAYER_PED) then
        setGameKeyState(18, 255)
    else
        sendClickKeySync(192)
    end
end

function sendClickKeySync(key)
    local data = allocateMemory(68)
    local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    sampStorePlayerOnfootData(myId, data)

    local weaponId = getCurrentCharWeapon(PLAYER_PED)
    setStructElement(data, 36, 1, weaponId + tonumber(key), true)
    sampSendOnfootData(data)
    freeMemory(data)
end

function AutoDoor()
    for key, hObj in pairs(getAllObjects()) do
        if doesObjectExist(hObj) then
            local objModel = getObjectModel(hObj)
            local res, ox, oy, oz = getObjectCoordinates(hObj)
			local objHeading = getObjectHeading(hObj)
			local px, py, pz = getCharCoordinates(PLAYER_PED)
            local distance = getDistanceBetweenCoords3d(px, py, pz, ox, oy, oz)
            -- двери
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
                            -- setVirtualKeyDown(72, true)
                            -- wait(50)
                            -- setVirtualKeyDown(72, false)
                            sendKeyH()
                        end
                        return
					end
                end
            -- шлагбаумы и заборы
            elseif objModel == 968 or objModel == 975 or objModel == 1374 or objModel == 19912 or objModel == 988 or objModel == 19313 or objModel == 11327 or objModel == 19313 or objModel == 980 then
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
                        -- setVirtualKeyDown(72, true)
                        -- wait(50)
                        -- setVirtualKeyDown(72, false)
                        sendKeyH()
                    end
                    return
                end
            end
        end
    end
end

require("samp.events").onServerMessage = function(color,text)
	if (text:find("У вас нет ключей от данного шлагбаума") or text:find("У вас нет ключей от этого шлагбаума!") or  text:find("У вас нет ключей от этой двери!") or text:find("У вас нет ключей от данной двери")) then
        show_arz_notify('error', 'AutoDoor', 'У вас нет доступа/ключа для этого обьекта!', 1500)
        --return false
	end
end

if not isMonetLoader() then
    function samp_create_sync_data(sync_type, copy_from_player)
        local ffi = require 'ffi'
        local sampfuncs = require 'sampfuncs'

        local raknet = require 'samp.raknet'
        require 'samp.synchronization'

        copy_from_player = copy_from_player or true
        local sync_traits = {
            player = {'PlayerSyncData', raknet.PACKET.PLAYER_SYNC, sampStorePlayerOnfootData},
            vehicle = {'VehicleSyncData', raknet.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData},
            passenger = {'PassengerSyncData', raknet.PACKET.PASSENGER_SYNC, sampStorePlayerPassengerData},
            aim = {'AimSyncData', raknet.PACKET.AIM_SYNC, sampStorePlayerAimData},
            trailer = {'TrailerSyncData', raknet.PACKET.TRAILER_SYNC, sampStorePlayerTrailerData},
            unoccupied = {'UnoccupiedSyncData', raknet.PACKET.UNOCCUPIED_SYNC, nil},
            bullet = {'BulletSyncData', raknet.PACKET.BULLET_SYNC, nil},
            spectator = {'SpectatorSyncData', raknet.PACKET.SPECTATOR_SYNC, nil}
        }
        local sync_info = sync_traits[sync_type]
        local data_type = 'struct ' .. sync_info[1]
        local data = ffi.new(data_type, {})
        local raw_data_ptr = tonumber(ffi.cast('uintptr_t', ffi.new(data_type .. '*', data)))

        if copy_from_player then
            local copy_func = sync_info[3]
            if copy_func then
                local _, player_id
                if copy_from_player == true then
                    _, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
                else
                    player_id = tonumber(copy_from_player)
                end
                copy_func(player_id, raw_data_ptr)
            end
        end

        local func_send = function()
            local bs = raknetNewBitStream()
            raknetBitStreamWriteInt8(bs, sync_info[2])
            raknetBitStreamWriteBuffer(bs, raw_data_ptr, ffi.sizeof(data))
            raknetSendBitStreamEx(bs, sampfuncs.HIGH_PRIORITY, sampfuncs.UNRELIABLE_SEQUENCED, 1)
            raknetDeleteBitStream(bs)
        end

        local mt = {
            __index = function(t, index)
                return data[index]
            end,
            __newindex = function(t, index, value)
                data[index] = value
            end
        }
        return setmetatable({send = func_send}, mt)
    end
end

function show_arz_notify(type, title, text, time)
    -- if MONET_VERSION ~= nil then
    --     if type == 'info' then
    --         type = 3
    --     elseif type == 'error' then
    --         type = 2
    --     elseif type == 'success' then
    --         type = 1
    --     end
    --     local bs = raknetNewBitStream()
    --     raknetBitStreamWriteInt8(bs, 62)
    --     raknetBitStreamWriteInt8(bs, 6)
    --     raknetBitStreamWriteBool(bs, true)
    --     raknetEmulPacketReceiveBitStream(220, bs)
    --     raknetDeleteBitStream(bs)
    --     local json = encodeJson({
    --         styleInt = type,
    --         title = title,
    --         text = text,
    --         duration = time
    --     })
    --     local interfaceid = 6
    --     local subid = 0
    --     local bs = raknetNewBitStream()
    --     raknetBitStreamWriteInt8(bs, 84)
    --     raknetBitStreamWriteInt8(bs, interfaceid)
    --     raknetBitStreamWriteInt8(bs, subid)
    --     raknetBitStreamWriteInt32(bs, #json)
    --     raknetBitStreamWriteString(bs, json)
    --     raknetEmulPacketReceiveBitStream(220, bs)
    --     raknetDeleteBitStream(bs)
    -- else
    --     local str = ('window.executeEvent(\'event.notify.initialize\', \'["%s", "%s", "%s", "%s"]\');'):format(type, title, text, time)
    --     local bs = raknetNewBitStream()
    --     raknetBitStreamWriteInt8(bs, 17)
    --     raknetBitStreamWriteInt32(bs, 0)
    --     raknetBitStreamWriteInt32(bs, #str)
    --     raknetBitStreamWriteString(bs, str)
    --     raknetEmulPacketReceiveBitStream(220, bs)
    --     raknetDeleteBitStream(bs)
    -- end
end