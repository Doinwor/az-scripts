script_name("FDeath for Arizona RP")
script_author("Fn4tylqrd")

local vkeys = require 'vkeys'

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("spose1", function()
        local playerPed = PLAYER_PED
        requestAnimation("ped")
        while not hasAnimationLoaded("ped") do wait(0) end
        taskPlayAnim(playerPed, "KO_shot_front", "ped", 4.0, false, true, true, true, -1)
        
        sampAddChatMessage("{3498db}[TPose]{ffffff} Активирована T-поза. Чтобы выйти, нажмите {f1c40f}Пробел{ffffff} и {f1c40f}Sprint{ffffff}.", -1)
    end)

    wait(-1)
end

function requestAnimation(lib)
    if not hasAnimationLoaded(lib) then
        requestAnimDict(lib)
        while not hasAnimationLoaded(lib) do wait(0) end
    end
end