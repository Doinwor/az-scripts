local ev = require "samp.events"

local stage = 0
local mode = nil
local req = ""

function main()
	sampRegisterChatCommand("gps", gps)
	while true do wait(0)
	
	end
end

function gps(args)
	if #args == 0 then
		stage = 0
		mode = nil
	elseif args == "search" or args == "s" or args == "ы" or args == "ыуфкср" then
		stage = 1
		mode = "search"
	
	elseif args == "off" or args == "o" or args == "щ" or args == "щаа" then
		stage = 1
		mode = "off"
	else
		stage = 1
		mode = "search_specific"
		req = args
	end
	
	sampSendChat("/gps")
end

function ev.onShowDialog(id, style, title, left, right, content)
	--print(id, style, title, content)
	if stage == 1 and mode == "search" and title:find("GPS Навигатор") then
		sampSendDialogResponse(id, 1, 1, "")
		stage = 0
		return false
	end
	if stage == 1 and mode == "off" and title:find("GPS Навигатор") then
		local c = 0
		for i in string.gmatch(content, "\n") do c = c + 1 end
		sampSendDialogResponse(id, 1, c, "")
		stage = 0
		return false
	end
	if stage == 1 and mode == "search_specific" and title:find("GPS Навигатор") then
		sampSendDialogResponse(id, 1, 1, "")
		stage = 2
		return false
	end
	if stage == 2 and mode == "search_specific" and style == 1 and title:find("Поиск по навигатору") then
		sampSendDialogResponse(id, 1, 0, req)
		stage = 3
		return false
	end
	if stage == 3 and mode == "search_specific" and style == 5 and title:find("Поиск в навигаторе") then
		local c = 0
		for i in string.gmatch(content, "\n") do c = c + 1 end
		stage = 0
		if c == 2 then
			sampSendDialogResponse(id, 1, 0, "")
			return false
		end
	end
	return true
end
