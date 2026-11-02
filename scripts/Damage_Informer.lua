script_name('objdmg')
script_author('hells666')
script_description('https://www.youtube.com/c/hells666')

require "lib.moonloader"
local hook = require 'lib.samp.events'

local OBJID = 2768 -- EDIT THIS | OBJECT ID
local OBJTIMER = 150 -- EDIT THIS | TIME

player = {
	id = 0,
	x = 0.0,
	y = 0.0,
	z = 0.0,
	dmgtimer = 0
}

enemy = {
	id = 0,
	x = 0.0,
	y = 0.0,
	z = 0.0,
	dmgtimer = 0
}

function main()
	if not isSampLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(100) end

	sampAddChatMessage("objdmg by HELLS666 loaded.", -1)
	sampAddChatMessage("use - /objdmg objid", -1)
	
	sampRegisterChatCommand("objdmg", CMDCMD)

	obj = createObject(OBJID, 0.0, 0.0, 0.0)
	obj_forenemy = createObject(OBJID, 0.0, 0.0, 0.0)
	while true do
		wait(1)
		if player.dmgtimer > 0 then 
			player.dmgtimer = player.dmgtimer - 1
		end
		if enemy.dmgtimer > 0 then 
			enemy.dmgtimer = enemy.dmgtimer - 1
		end

		if player.dmgtimer > 0 then 
			facang = getCharHeading(PLAYER_PED)
			player.x, player.y, player.z = getCharCoordinates(PLAYER_PED)
			setObjectCoordinates(obj, player.x, player.y, player.z + 1)
			setObjectHeading(obj, facang + 180.0)
		else
			setObjectCoordinates(obj, 0.0, 0.0, 0.0)
		end

		if enemy.dmgtimer > 0 then 
			tryes, enemyped = sampGetCharHandleBySampPlayerId(enemy.id)
			if tryes then 
				enemyfac = getCharHeading(enemyped)
				enemy.x, enemy.y, enemy.z = getCharCoordinates(enemyped)
				setObjectCoordinates(obj_forenemy, enemy.x, enemy.y, enemy.z + 1)
				setObjectHeading(obj_forenemy, enemyfac + 180.0)
			else
				enemy.id = 0
				enemy.dmgtimer = 0
			end
		else
			setObjectCoordinates(obj_forenemy, 0.0, 0.0, 0.0)
		end

	end
	
end

-- playerId = 'int16', damage = 'float', weapon = 'int32', bodypart ='int32'
function hook.onSendGiveDamage(playerId, damage, weapon, bodypart)
	enemy.id = playerId
	enemy.dmgtimer = OBJTIMER
end

-- playerId = 'int16', damage = 'float', weapon = 'int32', bodypart ='int32'
function hook.onSendTakeDamage(playerId, damage, weapon, bodypart)
	_, player.id = sampGetPlayerIdByCharHandle(PLAYER_PED)
	player.dmgtimer = OBJTIMER
end

function CMDCMD( arg )
	OBJID = tonumber(arg)
end
