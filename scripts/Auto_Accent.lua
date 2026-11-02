local inicfg = require 'inicfg'
local mainIni = inicfg.load(nil, "AutoAccent")

local ev = require "lib.samp.events"

function main()
while not isSampAvailable() do wait(100) end
sampRegisterChatCommand('accent',offon)
wait(-1)
end

function ev.onSendChat(message)
    if not aacent then
    return{mainIni.Text.accent..' '..message}
    end
end

function offon()
    aacent = not aacent
    if not aacent then 
    printStringNow('AutoAccent ~g~activated',1000)
        else
    printStringNow('AutoAccent ~r~deactivated', 1000)
    end
end