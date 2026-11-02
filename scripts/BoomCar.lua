function main()
	repeat wait(0) until isSampAvailable()
	wait(50)
	sampRegisterChatCommand("boomcar", boomc)
	sampAddChatMessage("[BoomCarFix] Запускаем пожилой скрипт", 0xFF0000)
    sampAddChatMessage("[BoomCarFix] Небольшой fix by ВСЕГО ЛИШЬ ЮТУБЕР", 0xFF0000)
	thr = lua_thread.create_suspended(thread_function)
	while true do
		wait(0)
	end
end

function boomc()
	if isCharInAnyCar(PLAYER_PED) then
		thr:run()
	else
		sampAddChatMessage("[BoomCarFix] Вы должны находиться в автомобиле", 0xFF0000)
	end
end
 function thread_function()
	vcar = storeCarCharIsInNoSave(PLAYER_PED)
	setCarHealth(vcar, 100)
 	setCarRoll(vcar, 180)
	wait(1000)
	local x,y,z = getCharCoordinates(playerPed)
	warpCharFromCarToCoord(playerPed, x,y,z)
end
