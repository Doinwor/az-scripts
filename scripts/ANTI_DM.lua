local sampev   = require 'lib.samp.events'
anti = true
function main()
	repeat wait(0) until isSampAvailable()
	wait(50)
 

	sampRegisterChatCommand("antidm", function() anti = not anti sampAddChatMessage(anti and "{009c41}[AntiDM for ARZ FUN] {ffffff} Включено. " or "{009c41}[AntiDM] {ffffff} Выключено.", -1) end)
	sampAddChatMessage("{009c41}[AntiDM for ARZ FUN] {ffffff} Запущено.", -1)
	while true do
		wait(0)
	end
end

function sampev.onShowDialog(id, style, title, b1, b2, text)
	if text:find("запрещено") then
		if anti then
			taskPlayAnim(playerPed, "HANDSUP", "PED", 4.0, false, false, false, false, 4)
			return false
		end
	end  
end