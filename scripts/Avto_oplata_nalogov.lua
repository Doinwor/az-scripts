script_name("Авто плата Налогов")
script_author("Dijer")
script_version("1.0")

local sampev = require("lib.samp.events")
local imgui = require('mimgui')
local encoding = require('encoding')
encoding.default = 'CP1251'
u8 = encoding.UTF8

local worked = false
local scriptEnabled = true

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if not scriptEnabled or worked then return end

    if dialogId == 6565 then
        lua_thread.create(function()
            wait(100)
            sampSendDialogResponse(dialogId, 1, 4, "")
        end)
        return
    end

    if dialogId == 15252 then
        worked = true
        lua_thread.create(function()
            wait(100)
            sampSendDialogResponse(dialogId, 1, -1, "")
        end)
        return
    end

    if dialogId == 0 then
        lua_thread.create(function()
            wait(100)
            sampSendDialogResponse(0, 0, -1, "")
        end)
        return
    end
end

addEventHandler('onReceivePacket', function(id, bs, ...)
    if not scriptEnabled or worked then return end

    if id == 220 then
        raknetBitStreamIgnoreBits(bs, 8)
        local packetType = raknetBitStreamReadInt8(bs)

        if packetType == 84 then
            local interfaceid = raknetBitStreamReadInt8(bs)
            local subid = raknetBitStreamReadInt8(bs)
            local len = raknetBitStreamReadInt16(bs)
            local encoded = raknetBitStreamReadInt8(bs)
            local json = (encoded ~= 0) and raknetBitStreamDecodeString(bs, len + encoded) or raknetBitStreamReadString(bs, len)

            if tonumber(interfaceid) == 47 then
                lua_thread.create(function()
                    wait(100)
                    sendFrontendClick(47, 24, 0, "{}")
                end)
            end
        end

        if packetType == 62 then
            local interfaceid = raknetBitStreamReadInt8(bs)
            local toggle = raknetBitStreamReadBool(bs)

            if tonumber(interfaceid) == 47 then
                lua_thread.create(function()
                    wait(100)
                    sendFrontendClick(47, 24, 0, "{}")
                end)
            end
        end
    end
end)

function sendFrontendClick(interfaceid, id, subid, json_str)
    if not scriptEnabled then return end
    
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteInt32(bs, id)
    raknetBitStreamWriteInt32(bs, subid)
    raknetBitStreamWriteInt16(bs, #json_str)
    raknetBitStreamWriteString(bs, json_str)
    raknetSendBitStreamEx(bs, 1, 10, 1)
    raknetDeleteBitStream(bs)
end

function sampev.onSendCommand(cmd)
    if cmd:lower() == "/nal" then
        scriptEnabled = not scriptEnabled
        local state = scriptEnabled and "включен" or "выключен"
        sampAddChatMessage(string.format("{FFFFFF}[Dijer] {00FF00}Скрипт %s", state), 0x00FF00)
        return false
    end
end

function main()
    while not isSampAvailable() do wait(100) end
    wait(-1)
end
