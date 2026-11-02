local imgui = require("mimgui")
local sampev = require("samp.events")

local inicfg = require "inicfg"
local ini = inicfg.load({
	cfg =
	{
		toggled = false
	}}, "AltBB.ini")

local winstatus = imgui.new.bool(ini.cfg.toggled)
local alt = false

function main()
	sampRegisterChatCommand("altbb", function()
		winstatus[0] = not winstatus[0]
		ini.cfg.toggled = winstatus[0]
		inicfg.save(ini, "AltBB.ini")
	end)
	wait(-1)
end

imgui.OnFrame(function() return winstatus[0] end, function(player)
	imgui.SetNextWindowPos(imgui.ImVec2(500,500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.Begin("AltByButton by t.me/lua_helpers")
	if imgui.Button("Alt", imgui.ImVec2(-1, -1)) then alt = true end
	imgui.End()
end)

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