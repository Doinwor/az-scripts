script_name("Straboacopes")
script_author("t.me/lua_helpers")
script_description("Activation - /strab")

local active = false

function main()
	sampRegisterChatCommand("strab", function()
		active = not active
		sampAddChatMessage("[Straboscopes]: Вы "..(active and "включили" or "выключили").." страбоскопы", -1)
	end)
	while true do
		local car = storeCarCharIsInNoSave(PLAYER_PED)
		if isCharInCar(PLAYER_PED,car) then
			if active then
				sampSendChat("/lights")
				wait(1000)
			end
		end
		wait(1)
	end
end