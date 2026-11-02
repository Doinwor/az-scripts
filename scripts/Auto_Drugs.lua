local sampev = require 'samp.events'

script_name("Auto-Drugs")
script_author('https://t.me/lua_arzmod')

sampAddChatMessage("{00ff00}[Auto-Drugs]{ffffff}: Скрипт успешно загружен! {ff0000}By {ffffff}@lua_arzmod", -1)

function sampev.onServerMessage(color, text)
	if string.find(text,'У вас началась сильная ломка') or text:find('Вашему персонажу нужно принять') then 
        sampSendChat("/usedrugs 3")
    end
    if string.find(text,'У вас нет столько укропа!') then
        sampAddChatMessage('{ff0000}[Auto-Drugs]: {ffffff}У вас нет {ffffff}столько укропа.', -1)
    end
end
