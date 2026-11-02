script_name('AFK Zaplata')
script_description('AFK Zaplata')
script_version('1.0')
script_authors('MrRazrab', 't.me/monetbinder')

local sampev = require "samp.events"
local inicfg = require 'inicfg'


local filename = "afkZP.ini"
local pickupId = -1

local ini = inicfg.load({
    settings = {
        enabled = true
    }
}, filename)
inicfg.save(ini, filename)

function main()
    repeat wait(0) until isSampAvailable()

    wait(-1)
end

sampRegisterChatCommand('afkzp', function()
    ini.settings.enabled = not ini.settings.enabled
    inicfg.save(ini, filename)

    msg(ini.settings.enabled and 'Включено' or 'Выключено')
end)

function msg(message) -- Вывод текста в чат
    local tag = '{0000FF}[NEW afkZP port t.me/monetbinder]: {FFCC00}'
    sampAddChatMessage(tag .. message, -1)
end

function sampev.onServerMessage(color, text)
    if not ini.settings.enabled then return end
    if text:find("На сервере есть инвентарь") then
        print('connected')
        pick()
    end
end

function sampev.onCreatePickup(id, model, pickupType, position)
    if model == 1275 then
        pickupId = id
    end
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if not ini.settings.enabled then return end

    if id == 15330 and text:find('Мы рады видеть вас на проекте Arizona Role Play.') then
        return false
    end

    if id == 581 then
        if text:find('Переодеться') then
            sampSendDialogResponse(id, 1, 0, "")
            return false
        end
    end
    if id == 7551 then
        if text:find('Переодеться в') and text:find('рабочую') then
            sampSendDialogResponse(id, 1, 0, "")
            msg('Переодеться в рабочую одежду')
            return false
        end

        if text:find('Переодеться в ') and text:find('свою') then
            sampSendDialogResponse(id, 0, 0, "")
            msg('Переодеться в свою одежду отменить')
            return false
        end
    end
end

function pick()
    lua_thread.create(function()
        wait(2000)
        print('pick')
        sampSendPickedUpPickup(pickupId)
    end)
end