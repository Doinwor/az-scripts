script_name("AltSync")
script_description("—крипт, позвол€ющий отправл€ть на сервер alt. јктиваци€: /alts")
script_author("t.me/lua_helpers")

local alt = false

function main()
	sampRegisterChatCommand("alts", function()
		alt = not alt
		sampAddChatMessage("[AltSync]: Alt успешно отправлен", -1)
	end)
	wait(-1)
end

local sampev = require("samp.events")

function sampev.onSendPlayerSync(data)
	if alt then
		lua_thread.create(function()
			data.keys.unknown_walkSlow = 1
			wait(1)
			data.keys.unknown_walkSlow = 0
			alt = false
		end)
	end
end