local sampev = require'lib.samp.events'
local mask = false

function main()
    if not isSampfuncsLoaded() or not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
			  sampAddChatMessage(string.format("[Shawty Auto-Mask]: {FFFFFF} Успешно загружен!"), 0x8A5EB6 )
	
	sampRegisterChatCommand("mk", cmd_mk)
	
	 while true do
    wait(0)
	
	  end
	
	end
	
	function cmd_mk()
	
	mask = not mask
	
	if mask == true then sampAddChatMessage("Теперь маска автоматически обновляется",0x00FF00)
	else sampAddChatMessage("Маска больше обновляться не будет",0xFF0000)
	end
	end
	
	function sampev.onServerMessage(color, msg)
    if (mask == true) and (msg:find('Время действия маски истекло, вам пришлось ее выбросить')) then
	sampAddChatMessage('Ваша маска обновилась!',0x00FF00)
	sampSendChat('/mask')
    end
	end