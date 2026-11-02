script_author('@T23Vladimir', 'Theopka')

local sampev = require('lib.samp.events')
local inicfg = require('inicfg')

local CFG_NAME = 'AutoOpenRouletteV2.ini'
local cfg = inicfg.load({
    settings = {
        delay = 2000,
    }
}, CFG_NAME)

local function saveCfg()
    inicfg.save(cfg, CFG_NAME)
end

local active = false

local delay = tonumber(cfg.settings.delay) or 2000
if delay < 500 or delay > 3000 then delay = 2000 end
local startDelay = 2000

function sendFrontendClick(interfaceid, id, subid, json_str)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteInt32(bs, id)
    raknetBitStreamWriteInt32(bs, subid)
    raknetBitStreamWriteInt32(bs, #json_str)
    raknetBitStreamWriteString(bs, json_str)
    raknetSendBitStreamEx(bs, 1, 10, 1)
    raknetDeleteBitStream(bs)
end

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('rol', function()
        active = not active
        sampAddChatMessage(active and '[AutoRoul]: {FFFFFF}Включено, откройте рулетку и открытие начнется' or '[AutoRoul]: {FFFFFF}Выключено', 0x6E2BCF)
        if active then
            msg('Если меню открытия рулеток закрылось, пробуйте открывать ещё раз(работает не с первого раза)')
        end
    end)

    sampRegisterChatCommand('rold', function(arg)
        local value = tonumber(arg)
        if not value then
            msg('Использование: /rold [мс] (500-3000). Сейчас: ' .. delay .. ' мс')
            return
        end
        value = math.floor(value)
        if value < 500 or value > 3000 then
            msg('Задержка должна быть от 500 до 3000 мс')
            return
        end
        delay = value
        cfg.settings.delay = delay
        saveCfg()
        msg('Задержка установлена: ' .. delay .. ' мс')
    end)

    while not sampIsLocalPlayerSpawned() do wait(0) end
    msg('Скрипт загружен! Команды: /rol, /rold(500-3000)')

    local wasActive = false
    while true do
        wait(0)
        if active then
            if not wasActive then
                wasActive = true
                wait(startDelay)
            end
            if active then
                sendFrontendClick(76, 0, 0, "0")
                wait(delay)
                if active then
                    sendFrontendClick(76, 0, 2, "0")
                    wait(delay)
                end
            end
        else
            wasActive = false
        end
    end
end

function sampev.onShowDialog(did, style, title, button1, button2, text)
    if active then 
        if text:find('Поздравляем с получением') then
            sampSendDialogResponse(did, 1, 0, 0)
            return false
        end
    end
end

function msg(text)
    sampAddChatMessage('[AutoRoul]: {FFFFFF}'..text, 0x6E2BCF)
end