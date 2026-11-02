function main()
    while not isSampAvailable() do wait(0) end
        
    sampRegisterChatCommand("ree", recone)
    sampRegisterChatCommand("reeoff", reconeOff)
    while true do
        wait(0)
    
    end
end

function recone(id)
    if not id then
        sampAddChatMessage("Введите id игрока! Пример: /recone 52")
    else
        if not (select(1,sampGetCharHandleBySampPlayerId(id))) then
			sampAddChatMessage("Игрок не в зоне стрима!", -1)
        else
            freezeCharPosition(PLAYER_PED, true)
            sampAddChatMessage("Вы зашли в слежку за игроком " .. sampGetPlayerNickname(id), -1)
            setCameraInFrontOfChar(select(2,sampGetCharHandleBySampPlayerId(id)))
        end
    end
end

function reconeOff()
    restoreCamera()
    setCameraBehindPlayer()
    sampAddChatMessage("Вы вышли из слежки", -1)
    freezeCharPosition(PLAYER_PED, false)
end