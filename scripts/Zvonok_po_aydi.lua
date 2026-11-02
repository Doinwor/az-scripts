local sampev = require "lib.samp.events"

function main()
	if not isSampLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(100) end
	_, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
	sampRegisterChatCommand('cid', getnumber)
end

function getnumber(id)
	sampSendChat("/number " .. id)
end

function sampev.onServerMessage(color, msg)
	if msg:match("^{......}%a+_%a+%[%d+%]:    {......}%d+$") then 
		local number = msg:match("^{......}%a+_%a+%[%d+%]:    {......}(%d+)$")
		lua_thread.create(function()
			sampAddChatMessage('Calling: {aa0000}'..number, -1)
			wait(500)
			sampSendChat("/call " .. number)
		end)
		return false
	end
end