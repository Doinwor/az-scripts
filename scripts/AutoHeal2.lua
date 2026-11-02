script_name("AutoHeal Lite")
script_author("KirdmiMods")

local enabled = false
local hp = 20
local mode = "heal"

function main()
    repeat wait(100) until isSampAvailable()

    sampAddChatMessage("AutoHeal loaded! Commands: /ah /ahhp /ahmode", -1)

    sampRegisterChatCommand("ah", function()
        enabled = not enabled
        sampAddChatMessage("AutoHeal: "..tostring(enabled), -1)
    end)

    sampRegisterChatCommand("ahhp", function(arg)
        local num = tonumber(arg)
        if num then
            hp = num
            sampAddChatMessage("HP set: "..hp, -1)
        else
            sampAddChatMessage("Example: /ahhp 20", -1)
        end
    end)

    sampRegisterChatCommand("ahmode", function(arg)
        if arg == "heal" or arg == "drug" then
            mode = arg
            sampAddChatMessage("Mode: "..mode, -1)
        else
            sampAddChatMessage("Use: /ahmode heal or drug", -1)
        end
    end)

    while true do
        wait(500)

        if enabled then
            if getCharHealth(PLAYER_PED) <= hp then
                if mode == "heal" then
                    sampSendChat("/usemed")
                else
                    sampSendChat("/usedrugs 1")
                end
                wait(5000)
            end
        end
    end
end