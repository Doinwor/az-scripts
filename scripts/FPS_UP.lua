require("lib.moonloader")
local ev = require("samp.events")
local imgui = require("mimgui")
local faicons = require("fAwesome6")
local encoding = require("encoding")

encoding.default = 'CP1251'
local directIni = 'filename.ini'
local u8 = encoding.UTF8
local delPlayers = imgui.new.bool(false)
local delCars = imgui.new.bool(false)
local delObjects = imgui.new.bool(false)
local Window = imgui.new.bool(false)
local dd1 = false

local logo = "{8a2be2}[FPS UP by]: {FFFFFF}"
local color = "{7cfc00}"

function dd(arg)
	dd1 = not dd1
	if dd1 then
		printStyledString("~n~~n~~n~~n~~n~~n~~n~~n~~w~FPS UP - ~g~activated", 2000, 4)
		alldell()
	else
		printStyledString("~n~~n~~n~~n~~n~~n~~n~~n~~w~FPS UP - ~r~deactivated", 2000, 4)
	end
end

function ev.onVehicleStreamIn()
	if delCars[0] then
		return false
	end
end

function ev.onPlayerStreamIn()
	if delPlayers[0] then
		return false
	end
end

function ev.onCreateObject(objectId, data) 
	if delObjects[0] then
		return false
	end
end

	if delObjects[0] then
		for _, handle in ipairs(getAllObjects()) do
			deleteObject(handle);
		end
	end
	if delPlayers[0] then
		for player = 0, 1000 do
			local _, hPed = sampGetCharHandleBySampPlayerId(player)
			if _ then
				RakNet = raknetNewBitStream()
				raknetBitStreamWriteInt16(RakNet, player)
				raknetEmulRpcReceiveBitStream(163, RakNet)
				raknetDeleteBitStream(RakNet)
			end
		end	
	end
	local cars = getAllVehicles()
	if delCars[0] then
		for c = 1, #cars do
			if doesVehicleExist(cars[c]) and not isCharInCar(PLAYER_PED, cars[c]) then
				local _, cid = sampGetVehicleIdByCarHandle(cars[c])
				if _ then
					RakNet = raknetNewBitStream()
					raknetBitStreamWriteInt16(RakNet, cid)
					raknetEmulRpcReceiveBitStream(165, RakNet)
					raknetDeleteBitStream(RakNet)
				end
			end
		end
	end

local UI = { version = 1, font = {}, tab = 1 }
local Tabs = {u8'Меню', u8'Инф-а'}

function UI.Init()
    local defGlyph = imgui.GetIO().Fonts.ConfigData.Data[0].GlyphRanges
    local font_config = imgui.ImFontConfig()
    font_config.SizePixels = 14.0
    font_config.GlyphExtraSpacing.x = 0.1
    UI.font = {}
    
end

function UI.End()
    imgui.EndChild()
    imgui.End()
    imgui.PopStyleVar()
end

function UI.Begin(title, var, flags, tab_data)
   

    --==[ STYLE ]==--
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 5)
    local Begin = imgui.Begin(title, var, imgui.WindowFlags.NoTitleBar + (flags or 0))
    local size = imgui.GetWindowSize()
    local DL = imgui.GetWindowDrawList()
    local pos = imgui.GetWindowPos()

    --==[ LOGO ]==--
    imgui.PushFont(UI.font[18])
    local LogoSize = imgui.CalcTextSize(title)
    imgui.SetCursorPos(imgui.ImVec2(15, 15))
    imgui.BeginChild('UI_Window='..title..':Child=Logo', LogoSize, false)
    imgui.SetCursorPos(imgui.ImVec2(0, 0))
    imgui.Text(title)
    imgui.PopFont()
    imgui.EndChild()

    DL:AddLine(imgui.ImVec2(pos.x + 15, pos.y + 15 + LogoSize.y + 15), imgui.ImVec2(pos.x + size.x - 15, pos.y + 15 + LogoSize.y + 15), imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button]), 2)

    --==[ TABS ]==--
    if tab_data then
        imgui.SetCursorPos(imgui.ImVec2(LogoSize.x + 30, 15))
        for i = 1, #tab_data do
            imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 5)
            imgui.PushStyleColor(imgui.Col.Button, UI.tab == i and imgui.GetStyle().Colors[imgui.Col.Button] or imgui.GetStyle().Colors[imgui.Col.WindowBg])
            if imgui.Button(tab_data[i]) then UI.tab = i end
            imgui.PopStyleVar()
            imgui.PopStyleColor()
            if i < #tab_data then
                imgui.SameLine()
            end
        end
    end

    --==[ CLOSE BUTTON ]==--
    if var ~= nil then
        imgui.SetCursorPos(imgui.ImVec2(size.x - 15 - 5, 15 + 5))
        if UI.CloseButton(10, 2) then
            var[0] = false
        end
    end

    --==[ CONTENT ]==--
    imgui.SetCursorPos(imgui.ImVec2(15, 15 + LogoSize.y + 15 + 5))
    local CSize = imgui.ImVec2(size.x - 15 - 15, size.y - LogoSize.y - 15 - 15 - 15 - 5)
    imgui.BeginChild('UI_Window='..title..':Child=Content', CSize, false)
    return Begin
end

function UI.CloseButton(size, thickness, textColor, color, colorHovered, colorClicked)
    local col = {
        text = textColor or imgui.GetStyle().Colors[imgui.Col.Button],
        color = color or imgui.GetStyle().Colors[imgui.Col.Button],
        colorHovered = colorHovered or imgui.GetStyle().Colors[imgui.Col.ButtonHovered],
        colorClicked = colorClicked or imgui.GetStyle().Colors[imgui.Col.ButtonActive],
    }
    local c = imgui.GetCursorPos()
    local p = imgui.GetCursorScreenPos()
    local DL = imgui.GetWindowDrawList()
    local tx = imgui.CalcTextSize('X')
    
    DL:AddCircle(p, size, imgui.GetColorU32Vec4(col.color), 100, thickness)
    
    imgui.SetCursorPos(imgui.ImVec2(c.x - size, c.y - size))
    return imgui.InvisibleButton('CLOSEBUTTONBEBRA', imgui.ImVec2(size * 2, size * 2))
end

imgui.OnInitialize(function()
    UI.Init()
end)
local inicfg = require 'inicfg'
local directIni = 'fpsup.ini'
local ini = inicfg.load(inicfg.load({
	chekbox = {
		delPlayers = false,
		delCars = false,
		delObjects = false,
		custom_dist_text_enable = false,
		custom_dist_bubble_enable = false,
	},
	Sliders = {
		text3d = 0,
		ChatBubble = 0,
	}
}, directIni))
inicfg.save(ini, directIni)


local text3d = imgui.new.int(ini.Sliders.text3d)
local ChatBubble = imgui.new.int(ini.Sliders.ChatBubble)
local custom_dist_text_enable = imgui.new.bool(ini.chekbox.custom_dist_text_enable)
local custom_dist_bubble_enable = imgui.new.bool(ini.chekbox.custom_dist_bubble_enable)
local WindowFrame = imgui.OnFrame(
    function() return Window[0] end,
    function(self)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 300, 300
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        if UI.Begin('FPS UP', Window, 0, Tabs) then

            if UI.tab == 1 then
                imgui.Checkbox(u8'Убрать игроков', delPlayers)
				imgui.Checkbox(u8'Убрать транспорт', delCars)
				imgui.Checkbox(u8'Убрать объекты', delObjects)
				imgui.Checkbox(u8'Изменение прорисовки 3д текста', custom_dist_text_enable)
				imgui.Checkbox(u8'Изменение прорисовки текста над головой у игрока', custom_dist_text_enable)
				if imgui.SliderInt(u8"Дальность прорисовки 3д текстов", text3d, 0, 150) then
					ini.Sliders.text3d = text3d[0]
					inicfg.save(ini, directIni)
				end
				if imgui.SliderInt(u8"Дальность текста над головой у игрока", ChatBubble, 0, 150) then
					ini.Sliders.ChatBubble = ChatBubble[0]
					inicfg.save(ini, directIni)
				end
				
				if imgui.Button(u8"Убрать/вернуть худ") then
					sampSendChat("/hidehud")
				end
				if delObjects[0] then
					for _, handle in ipairs(getAllObjects()) do
						deleteObject(handle);
					end
				end
				if delPlayers[0] then
					for player = 0, 1000 do
						local _, hPed = sampGetCharHandleBySampPlayerId(player)
						if _ then
							RakNet = raknetNewBitStream()
							raknetBitStreamWriteInt16(RakNet, player)
							raknetEmulRpcReceiveBitStream(163, RakNet)
							raknetDeleteBitStream(RakNet)
						end
					end	
				end
				local cars = getAllVehicles()
				if delCars[0] then
					for c = 1, #cars do
						if doesVehicleExist(cars[c]) and not isCharInCar(PLAYER_PED, cars[c]) then
							local _, cid = sampGetVehicleIdByCarHandle(cars[c])
							if _ then
								RakNet = raknetNewBitStream()
								raknetBitStreamWriteInt16(RakNet, cid)
								raknetEmulRpcReceiveBitStream(165, RakNet)
								raknetDeleteBitStream(RakNet)
							end
						end
					end
				end
            end

			if UI.tab == 2 then
                imgui.Text(u8'FPS UP\n!!!Что бы вернуть все что вы должны выйти из инты и зайти обратно,\nперед этим выключив ВСЕ функции\nСделанно при поддержке Arizona FUN')
            end

            UI.End()
        end
    end
)

function ev.onCreate3DText(id, col, pos, allowed_dist, los, plid, vehid, text)
	local custom_dist = ini.Sliders.text3d
	if custom_dist_text_enable[0] and custom_dist < allowed_dist then
		return {id, col, pos, custom_dist, los, plid, vehid, text}
	end
end

function ev.onPlayerChatBubble(id, col, allowed_dist, dur, text)
	local custom_dist = ini.Sliders.ChatBubble
	if custom_dist_bubble_enable[0] and custom_dist < allowed_dist then
		return {id, col, custom_dist, dur, text}
	end
end



function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('del', function()
        Window[0] = not Window[0]
    end)
	sampAddChatMessage("{7B68EE}[FPS UP] {ffffff}Активация /del", -1)
    wait(-1)
end