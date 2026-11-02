function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('piss', function()
        sampSetSpecialAction(68)
       end)
    sampRegisterChatCommand('pissof', function()
    sampSetSpecialAction(0)
    end)
    while true do
        wait(0)
    end
end