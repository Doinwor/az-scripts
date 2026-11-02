--Head


script_name("Pad Bindings")
script_author("gravitos")

function isMonetLoader() return MONET_VERSION ~= nil end

if not isMonetLoader() then print("Script only works on MonetLoader. Here be dragons!") end

local sampev = require "samp.events"
ffi = require('ffi')
widgets = require('widgets')
gta = ffi.load('GTASA') 
ffi.cdef[[ void _Z12AND_OpenLinkPKc(const char* link); ]]

local active = true

--Ебанутые RPC махинации
  function samp_create_sync_data(sync_type, copy_from_player)
    local ffi = require 'ffi'
    local sampfuncs = require 'sampfuncs'
    -- from SAMP.Lua
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
    -- copy player's sync data to the allocated memory
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
    -- function to send packet
    local func_send = function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, sync_info[2])
        raknetBitStreamWriteBuffer(bs, raw_data_ptr, ffi.sizeof(data))
        raknetSendBitStreamEx(bs, sampfuncs.HIGH_PRIORITY, sampfuncs.UNRELIABLE_SEQUENCED, 1)
        raknetDeleteBitStream(bs)
    end
    -- metatable to access sync data and 'send' function
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



function main()
	while true do
		wait(0)
		if active then
			if isWidgetPressed(WIDGET_ROULETTE_RIGHT) then
				sampSendChat("/invent")
                wait(1000)
			end
			if isWidgetPressed(WIDGET_PHONE) then
                sampSendChat("/phone")
                wait(1000)
			end
			if isWidgetPressed(WIDGET_ROULETTE_UP) then
                --sampSendChat(")")
                if isCharOnFoot(PLAYER_PED) then
                  local data = samp_create_sync_data("player")
                  data.keysData = data.keysData + 1024
                  data.send()
                else
                  local data = samp_create_sync_data("vehicle")
                  data.keysData = data.keysData + 4
                  data.send()
                end
			end
            if isWidgetPressed(WIDGET_ROULETTE_LEFT) then
                if isCharOnFoot(PLAYER_PED) then
                    local data = samp_create_sync_data("player")
                    data.quaternion[4] = 1.7632555392181e-38
                    data.send()
                else
                    local data = samp_create_sync_data("vehicle")
                    data.keysData = data.keysData + 512
                    data.send()
                end
            end
			if isWidgetPressed(WIDGET_ROULETTE_DOWN) then
				if isCharOnFoot(PLAYER_PED) then
					local data = samp_create_sync_data("player")
					data.quaternion[4] = 1.1755083638069e-38
					data.send()

				else
					sampSendChat("/engine")
                    wait(1000)
				end
                
			end
		end
	end
end
