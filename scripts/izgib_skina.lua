local state = false

function main()
    repeat wait(0) until isSampAvailable()
    sampRegisterChatCommand("crv", function() 
        state = not state
        if not state then
            clearCharTasks(PLAYER_PED)
        end
    end)
    while true do
        wait(0)
        if state then
            requestAnimation("PARACHUTE")
            if hasAnimationLoaded("PARACHUTE") then
                taskPlayAnim(PLAYER_PED, "PARA_RIP_LOOP_O", "PARACHUTE", 4.0, true, false, true, false, -1)
                removeAnimation("PARACHUTE")
            end
        end
    end
end