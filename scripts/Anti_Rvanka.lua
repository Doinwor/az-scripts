require "lib.moonloader"
local sampev = require 'lib.samp.events'
local widgets = require 'widgets'

local player_id = {}
local infnpc = {}
local current_id

local function send_player_stream(id, i)
	if i then
		local bs = raknetNewBitStream()
		raknetBitStreamWriteInt16(bs, id)
		raknetBitStreamWriteInt8(bs, i[1])
		raknetBitStreamWriteInt32(bs, i[2])
		raknetBitStreamWriteFloat(bs, i[3].x)
		raknetBitStreamWriteFloat(bs, i[3].y)
		raknetBitStreamWriteFloat(bs, i[3].z)
		raknetBitStreamWriteFloat(bs, i[4])
		raknetBitStreamWriteInt32(bs, i[5])
		raknetBitStreamWriteInt8(bs, i[6])
		raknetEmulRpcReceiveBitStream(32, bs)
	end
end

function main()
	while not isSampAvailable() do wait(0) end
	sampAddChatMessage("[AntiRvanka] {d5dedd}Скрипт был успешно загружен. Автор: {01A0E9}Sad_Flores.", 0x01A0E9)

	sampRegisterChatCommand("return", returnCallBack)

	while true do
		wait(0)
		if isWidgetSwipedLeft(WIDGET_PLAYER_INFO) and current_id ~= 0 then
			send_player_stream(player_id[current_id], infnpc[player_id[current_id]])
			player_id[current_id] = nil
			sampAddChatMessage(string.format("[AntiRvanka] {d5dedd}Игрок с ID: {01A0E9}%s {d5dedd}был успешно восстановлен.", current_id), 0x01A0E9)
		end
	end
end

function returnCallBack(arg)
	if #arg == 0 then
		sampAddChatMessage("[AntiRvanka] {d5dedd}Неправильный синтаксис команды: {01A0E9}/return [PlayerID]", 0x01A0E9)
	else
		send_player_stream(player_id[#arg], infnpc[player_id[#arg]])
		player_id[#arg] = nil
		sampAddChatMessage(string.format("[AntiRvanka] {d5dedd}Игрок с ID: {01A0E9}%s {d5dedd}был успешно восстановлен.", current_id), 0x01A0E9)
	end
end

function sampev.onPlayerSync(id, data)
	local x, y, z = getCharCoordinates(PLAYER_PED)
	if x - data.position.x > -1.5 and x - data.position.x < 1.5 then
		if (data.moveSpeed.x >= 1.5 or data.moveSpeed.x <= -1.5) or (data.moveSpeed.y >= 1.5 or data.moveSpeed.y <= -1.5) or (data.moveSpeed.z >= 0.5 or data.moveSpeed.z <= -0.5) then
			if #player_id ~= id then
				player_id[#player_id + 1] = id
				current_id = id
				sampAddChatMessage(string.format("[AntiRvanka] {d5dedd}Пидарас с рванкой был удален, ID: {01A0E9}%s", id), 0x01A0E9)
				sampAddChatMessage(string.format("[AntiRvanka] {d5dedd}Если это произошло ложно, то вы можете восстановить игрока: {01A0E9}/return %s", id), 0x01A0E9)
				sampAddChatMessage(string.format("[AntiRvanka] {d5dedd}Или же сделайте свайп фиста влево.", id), 0x01A0E9)
				deletePlayer(id)
			end
		end
	end
end

function sampev.onVehicleSync(id, vehid, data)
	local x, y, z = getCharCoordinates(PLAYER_PED)
	if x - data.position.x > -1.5 and x - data.position.x < 1.5 then
		if (data.moveSpeed.x >= 1.5 or data.moveSpeed.x <= -1.5) or (data.moveSpeed.y >= 1.5 or data.moveSpeed.y <= -1.5) or (data.moveSpeed.z >= 0.5 or data.moveSpeed.z <= -0.5) then
			if #player_id ~= id then
				player_id[#player_id + 1] = id
				current_id = id
				sampAddChatMessage(string.format("[AntiRvanka] {d5dedd}Пидарас с рванкой был удален, ID: {01A0E9}%s", id), 0x01A0E9)
				sampAddChatMessage(string.format("[AntiRvanka] {d5dedd}Если это произошло ложно, то вы можете восстановить игрока: {01A0E9}//return %s", id), 0x01A0E9)
				sampAddChatMessage(string.format("[AntiRvanka] {d5dedd}Или же нажмите клавишу: Ins(Insert).", id), 0x01A0E9)
				deletePlayer(id)
			end
		end
	end
end

function sampev.onPlayerQuit(id, reason)
	if #player_id == id then
		for i = 1, #player_id do
			player_id[i] = nil
		end
	end
end

-- ‘пасибо Musaigen
function deletePlayer(id)
    local bitStream = raknetNewBitStream()
    raknetBitStreamWriteInt16(bitStream, id)
    raknetEmulRpcReceiveBitStream(163, bitStream)
    raknetDeleteBitStream(bitStream)
end

function sampev.onPlayerStreamIn(playerId, team, model, position, rotation, color, fightingStyle)
	infnpc[playerId] = { team, model, position, rotation, color, fightingStyle }
end