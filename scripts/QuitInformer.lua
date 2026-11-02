-- не надо говорить что есть клео от дапо во-первых дапо пидорас, во-вторых клео хуйня :////
script_name('Quit Informer')
script_author('ronnyscripts')

local sampev = require("lib.samp.events")

local in_stream = true
local state = true

reasons = {
    [0] = 'потеря связи/краш',
    [1] = '/q',
    [2] = 'кикнул сервер/забанил'
}

function notf(text)
    sampAddChatMessage('[Quit Informer] {ffffff}'..text,0xFF9C00)
end
function main()
    while not isSampAvailable() do
        wait(0)
    end
    sampRegisterChatCommand('qinf',function(set)
        if set:len() > 0 then 
            local set_f = set:match('(%a+)')
            if set_f == 'enable' then
                state = not state
                notf('Скрипт ' .. (state and '{FF9C00}включен' or '{FF9C00}выключен')) 
            elseif set_f == 'stream' then
                in_stream = not in_stream
                notf('Оповещение в зоне стрима ' .. (in_stream and '{FF9C00}включено' or '{FF9C00}выключено')) 
            end
        else
            notf('Состояние скрипта: ' .. (in_stream and '{FF9C00}включен' or '{FF9C00}выключен') .. '{ffffff}, В зоне стрима: '.. (in_stream and '{FF9C00}включено' or '{FF9C00}выключено'))
            notf('{FF9C00}/qinf enable {ffffff}- включить/выключить скрипт')
            notf('{FF9C00}/qinf stream {ffffff}- оповещение в зоне стрима')
        end
    end)
    notf('Скрипт загружен! Управление - {FF9C00}/qinf{ffffff}, Автор: {FF9C00}ronnyscripts')
    wait(-1)
end

function sampev.onPlayerQuit(playerid,reason) -- 0 краш, 1 вышел /q, 2 кикнуло
    if state then
        local textadd = 'Игрок {FF9C00}'..sampGetPlayerNickname(playerid)..'['..playerid..'] {ffffff}вышел с сервера. {FF9C00}Причина: {ffffff}'..reasons[reason]
        if in_stream then
            if select(1, sampGetCharHandleBySampPlayerId(playerid)) then
                notf(textadd)
            end
        else
            notf(textadd)
        end
    end
end