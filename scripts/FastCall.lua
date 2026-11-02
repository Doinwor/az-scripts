require("moonloader")
local sampev = require 'lib.samp.events'
local on = false

function main()
	while not isSampAvailable() do wait(0) end
	
	sampRegisterChatCommand('fcall', getNumber) -- call command
	
	wait(-1)
end

function chatMessage(message) -- вместо sampAddChatMessage()
	sampAddChatMessage('{800080}[Fcall by Karen]: {e75480}'.. tostring(message), -1)
end

function getNumber(id)
	id = string.match(id, '(.+)')
	if id == nil then
		chatMessage('Вы ввели пустое поле, введите пожалуйста число после команды /fcall')
	else
		sampSendChat('/number '.. id)
		on = true
	end
end

function sampev.onServerMessage(color, text)
    if text:find('(%w+_%w+)%[(%d+)%]%:    {......}(%d+)') and on then
		lua_thread.create(function()
			wait(1000)
			local nick, number = text:match('(%w+_%w+)%[%d+%]%:    {......}(%d+)')
			chatMessage('Пытаемся дозвониться до '.. nick)
			sampProcessChatInput('/call '.. number)
			on = false
		end)
		return false
    end
end
