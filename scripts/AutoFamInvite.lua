script_name('АвтоПринятие в семью')
script_author('Chorty && ported by ospx')

local inicfg = require 'inicfg'
local directIni = 'AutoFamInvite.ini'
local ini = inicfg.load(inicfg.load({
    settings = {
        dist = 15,
        delay = 4000
    },
}, directIni))
inicfg.save(ini, directIni)


local rpc = require("samp.raknet").RPC
local sampev = require('lib.samp.events')

local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local inputWindow = imgui.new.int(ini.settings.dist)
local inputDelay = imgui.new.int(ini.settings.delay)
local renderWindow = imgui.new.bool(false)
local state_script = imgui.new.bool(false)

local show_author = false

local players = {}
local famPlayers = {}

imgui.OnInitialize(function()
	imgui.GetIO().IniFilename = nil
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
   	--imgui.GetIO().Fonts:Clear()
   	--imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 15.0, nil, glyph_ranges)
        style()
end)

local newFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 215, 245
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('Main Window', renderWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoTitleBar)
        if show_author then imgui.PushItemWidth(255) else imgui.PushItemWidth(175) end
        imgui.PushFont(iFont30)
		imgui.CenterText(u8'Auto Fam Invite')
		imgui.PopFont()
        imgui.PushFont(iFont18)
		imgui.Text(u8'Лимит дистанции')
		imgui.PopFont()
        if imgui.SliderInt("##distInt", inputWindow, 1,  15, u8("Лимит - %d")) then
            rusTextdraw('Дистанция изменина на: '..inputWindow[0])
            ini.settings.dist = inputWindow[0]
            inicfg.save(ini, directIni)
        end
        imgui.SameLine()
        imgui.Question("DistanseInvite", u8"Радиус поиска людей, для приглашения в семью")
        imgui.PushFont(iFont18)
		imgui.Text(u8'Задержка принятия')
		imgui.PopFont()
        if imgui.InputInt("##Delay123123", inputDelay, 100) then
            rusTextdraw('Задержка изменена на: ~g~'..tonumber(inputDelay[0]/1000).." сек.")
            ini.settings.delay = inputDelay[0]
            inicfg.save(ini, directIni)
        end
        imgui.SameLine()
        imgui.Question("DelayInvite", u8"Задержка принятия в семью (Кидается /faminvite раз в "..inputDelay[0]..u8" милисекунд).\n1000 милисекунд = 1сек.")
        if imgui.ToggleButton(u8("Включить/Выключить"), state_script) then
            rusTextdraw("Автопринятие в семью: "..string.format("%s",state_script[0]):gsub("true", "~g~Включено"):gsub("false", "~b~Выключено"), 1000)
        end
        imgui.SameLine()
        imgui.Question("StateScript", u8"Состояние скрипта - Включить/Выключить")
        imgui.PopItemWidth()
        imgui.NewLine()
        
        if imgui.Button(u8("Подгрузить инфу про ЛВЛа")) then
            sendUpdateScoresRPC()
        end
        imgui.SetCursorPosY(imgui.GetWindowSize().y - 38)
		if imgui.Button(u8'Закрыть', imgui.ImVec2(-1, 30)) then
			renderWindow[0] = false
		end
        imgui.End()
    end
)

function sampev.onCreate3DText(id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, text)
    if attachedPlayerId and text:find('{.-}©(.+)') then
        local family = text:match('{.-}©(.+)')
        famPlayers[attachedPlayerId] = family
    end
end

function getNearestPlayerByCoordinates(x,y,z)
    
end

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('faminv', function()
        renderWindow[0] = not renderWindow[0]
    end)
    sampRegisterChatCommand('finv', function()
        state_script[0] = not state_script[0]
    end)
    while true do
        wait(0)
        
        if string.format("%s",state_script[0]):find("true") then
            for k, ped in pairs(getAllChars()) do
                local x, y, z = getCharCoordinates(ped)
                local x2, y2, z2 = getCharCoordinates(PLAYER_PED)
                local dist = getDistanceBetweenCoords3d(x, y, z, x2, y2, z2)
                if dist ~= 0 and dist <= inputWindow[0] then
                    local res, id = sampGetPlayerIdByCharHandle(ped)
                    if res then
                        local score = sampGetPlayerScore(id)
                        if (score == 0 or score >= 3) and famPlayers[id] == nil then
                            if players[id] == nil then
                                sampSendChat('/faminvite '..id)
                                players[id] = os.time()
                            elseif players[id] ~= nil then
                                if os.time() - players[id] >= inputDelay[0]/1000 then
                                    sampSendChat('/faminvite '..id)
                                    players[id] = os.time()
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function sendUpdateScoresRPC()
    local bs = raknetNewBitStream()
    raknetSendRpc(rpc.UPDATESCORESPINGSIPS, bs)
    raknetDeleteBitStream(bs)
end

function imgui.Link(link, text, isCopy)
    text = text or link
    local tSize = imgui.CalcTextSize(text)
    local p = imgui.GetCursorScreenPos()
    local DL = imgui.GetWindowDrawList()
    local col = { 0xFFFF7700, 0xFFFF9900 }
    imgui.InvisibleButton("##" .. link, tSize)
    if imgui.IsItemClicked() then
        if isCopy ~= nil then
            setClipboardText(link)
        else
            print(123)
            os.execute("explorer "..link)
        end
    end
    local color = imgui.IsItemHovered() and col[1] or col[2]
    DL:AddText(p, color, text)
    DL:AddLine(imgui.ImVec2(p.x, p.y + tSize.y), imgui.ImVec2(p.x + tSize.x, p.y + tSize.y), color)
end

function rusTextdraw(arg)
    arg = arg:gsub('Я', '•');    arg = arg:gsub('я', '¬');    arg = arg:gsub('Ю', '”')
    arg = arg:gsub('ю', '«');    arg = arg:gsub('Э', '“');    arg = arg:gsub('э', 'Є')
    arg = arg:gsub('Ы', '‘');    arg = arg:gsub('ы', '‘');    arg = arg:gsub('Ъ', '§')
    arg = arg:gsub('ъ', 'ђ');    arg = arg:gsub('Ь', '’');    arg = arg:gsub('ь', '©')
    arg = arg:gsub('Щ', 'Љ');    arg = arg:gsub('щ', 'Ў');    arg = arg:gsub('Ш', 'Ћ')
    arg = arg:gsub('ш', 'Ґ');    arg = arg:gsub('Ч', 'Ч');    arg = arg:gsub('ч', '¤')
    arg = arg:gsub('Ц', '‰');    arg = arg:gsub('ц', '‰');    arg = arg:gsub('Х', 'X')
    arg = arg:gsub('х', 'x');    arg = arg:gsub('Ф', 'Ѓ');    arg = arg:gsub('ф', 'Ѓ')
    arg = arg:gsub('У', 'Y');    arg = arg:gsub('у', 'y');    arg = arg:gsub('Т', 'Џ')
    arg = arg:gsub('т', '¦');    arg = arg:gsub('С', 'C');    arg = arg:gsub('Р', 'P')
    arg = arg:gsub('р', 'p');    arg = arg:gsub('П', 'Њ');    arg = arg:gsub('п', 'Ј')
    arg = arg:gsub('О', 'O');    arg = arg:gsub('о', 'o');    arg = arg:gsub('Н', 'H')
    arg = arg:gsub('н', '®');    arg = arg:gsub('М', 'M');    arg = arg:gsub('м', 'Ї')
    arg = arg:gsub('Л', '‡');    arg = arg:gsub('л', 'ћ');    arg = arg:gsub('К', 'K')
    arg = arg:gsub('к', 'k');    arg = arg:gsub('Й', '…');    arg = arg:gsub('й', 'ќ')
    arg = arg:gsub('И', '…');    arg = arg:gsub('и', 'њ');    arg = arg:gsub('З', '€')
    arg = arg:gsub('з', 'џ');    arg = arg:gsub('Ж', '„');    arg = arg:gsub('ж', '›')
    arg = arg:gsub('Ё', 'E');    arg = arg:gsub('ё', 'e');    arg = arg:gsub('Е', 'E')
    arg = arg:gsub('е', 'e');    arg = arg:gsub('Д', 'ѓ');    arg = arg:gsub('д', 'љ')
    arg = arg:gsub('Г', '‚');    arg = arg:gsub('г', '™');    arg = arg:gsub('В', '‹')
    arg = arg:gsub('в', 'ў');    arg = arg:gsub('а', 'a');    arg = arg:gsub('А', 'A')
    arg = arg:gsub('б', '—');    arg = arg:gsub('Б', 'Ђ');    arg = arg:gsub('с', 'c');
	printStringNow(arg, 1000)
end

local but_orig = imgui.Button
function imgui.Button(str_id, size, bool)
	if bool == nil then bool = true end
	if bool then
		imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.07, 0.07, 0.09, 1.00))
		imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.90, 0.90, 0.90, 1.00))
	    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.80, 0.80, 0.80, 1.00))
	    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.70, 0.70, 0.70, 1.00))
	    local result = but_orig(str_id, size)
	    imgui.PopStyleColor(4)
	    return result
	else
		imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 1.00, 1.00, 1.00))
		imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20, 0.20, 0.20, 1.00))
	    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.15, 0.15, 0.15, 1.00))
	    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.10, 0.10, 0.10, 1.00))
	    local result = but_orig(str_id, size)
	    imgui.PopStyleColor(4)
	    return result
	end
end

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(text).x / 2)
    imgui.Text(text)
end

function imgui.Hint(str_id, hint_text)
    local p_orig = imgui.GetCursorPos()
    local hovered = imgui.IsItemHovered()
    imgui.SameLine(nil, 0)
    local animTime = 0.2
    local show = true
    if not allHints then allHints = {} end
    if not allHints[str_id] then
        allHints[str_id] = {
            status = false,
            timer = 0
        }
    end
    if hovered then
        for k, v in pairs(allHints) do
            if k ~= str_id and os.clock() - v.timer <= animTime  then
                show = false
            end
        end
    end
    if show and allHints[str_id].status ~= hovered then
        allHints[str_id].status = hovered
        allHints[str_id].timer = os.clock()
    end
    local rend_window = function(alpha)
	    local size = imgui.GetItemRectSize()
	    local scrPos = imgui.GetCursorScreenPos()
	    local DL = imgui.GetWindowDrawList()
	    local center = imgui.ImVec2( scrPos.x - (size.x / 2), scrPos.y + (size.y / 2) - (alpha * 4) )
        local a = imgui.ImVec2( center.x - 8, center.y - size.y - 1 )
        local b = imgui.ImVec2( center.x + 8, center.y - size.y - 1)
        local c = imgui.ImVec2( center.x, center.y - size.y + 7 )

        DL:AddTriangleFilled(a, b, c, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.00, 1.00, 1.00, alpha)))
        imgui.SetNextWindowPos(imgui.ImVec2(center.x, center.y - size.y - 3), imgui.Cond.Always, imgui.ImVec2(0.5, 1.0))
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 6)
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)

        imgui.Begin('##' .. str_id, _, imgui.WindowFlags.Tooltip + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoTitleBar)
            for line in hint_text:gmatch('[^\r\n]+') do
                imgui.TextUnformatted(line)
            end
        imgui.End()

        imgui.PopStyleVar(2)
    end

    if show then
        local between = os.clock() - allHints[str_id].timer
        if between <= animTime then
            local s = function(f) 
                return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
            end
            local alpha = hovered and s(between / animTime) or s(1.00 - between / animTime)
            rend_window(alpha)
        elseif hovered then
        	rend_window(1.00)
        end
    end

    imgui.SetCursorPos(p_orig)
end

function imgui.Question(...)
	imgui.SameLine()
	imgui.TextColored(imgui.ImVec4(1, 1, 1, 0.3), '(?)')
	imgui.Hint(...)
end

function imgui.ToggleButton(str_id, bool)
    local rBool = false
    if LastActiveTime == nil then
        LastActiveTime = {}
    end
    if LastActive == nil then
        LastActive = {}
    end
    local function ImSaturate(f)
        return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
    end
    local p = imgui.GetCursorScreenPos()
    local draw_list = imgui.GetWindowDrawList()
    local height = imgui.GetTextLineHeightWithSpacing()
    local width = height * 1.70
    local radius = height * 0.50
    local ANIM_SPEED = 0.15
    local butPos = imgui.GetCursorPos()
    if imgui.InvisibleButton(str_id, imgui.ImVec2(width, height)) then
        bool[0] = not bool[0]
        rBool = true
        LastActiveTime[tostring(str_id)] = os.clock()
        LastActive[tostring(str_id)] = true
    end

    imgui.SetCursorPos(imgui.ImVec2(butPos.x + width + 8, butPos.y + 2.5))
    imgui.Text( str_id:gsub('##.+', '') )

    local t = bool[0] and 1.0 or 0.0

    if LastActive[tostring(str_id)] then
        local time = os.clock() - LastActiveTime[tostring(str_id)]
        if time <= ANIM_SPEED then
            local t_anim = ImSaturate(time / ANIM_SPEED)
            t = bool[0] and t_anim or 1.0 - t_anim
        else
            LastActive[tostring(str_id)] = false
        end
    end
    
    local col_static = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.07, 0.07, 0.09, 1.00))
    local col = bool[0] and 0xFFFFFFFF or 0xAAAAAAAA

    draw_list:AddRectFilled(imgui.ImVec2(p.x, p.y + (height / 6)), imgui.ImVec2(p.x + width - 1.0, p.y + (height - (height / 6))), col, 5.0)
    draw_list:AddCircleFilled(imgui.ImVec2(p.x + radius + t * (width - radius * 2.0), p.y + radius), radius - 0.75, col_static)
    draw_list:AddCircle(imgui.ImVec2(p.x + radius + t * (width - radius * 2.0), p.y + radius), radius - 0.75, col, 32, 2)

    return rBool
end

function style()
	imgui.SwitchContext()
    imgui.GetStyle().WindowRounding		= 7.0
    imgui.GetStyle().ChildRounding		= 7.0
    imgui.GetStyle().FrameRounding		= 10.0
    imgui.GetStyle().FramePadding		= imgui.ImVec2(5, 3)
    imgui.GetStyle().WindowPadding		= imgui.ImVec2(8, 8)
    imgui.GetStyle().ButtonTextAlign	= imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().GrabMinSize		= 7
    imgui.GetStyle().GrabRounding		= 15
	imgui.GetStyle().Colors[imgui.Col.Text]					= imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
	imgui.GetStyle().Colors[imgui.Col.TextDisabled]			= imgui.ImVec4(0.55, 0.55, 0.55, 0.20)
	imgui.GetStyle().Colors[imgui.Col.WindowBg]				= imgui.ImVec4(0.07, 0.07, 0.09, 1.00)
	imgui.GetStyle().Colors[imgui.Col.PopupBg]				= imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
	imgui.GetStyle().Colors[imgui.Col.Border]				= imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
	imgui.GetStyle().Colors[imgui.Col.SliderGrab]			= imgui.ImVec4(0.90, 0.90, 0.90, 1.00)
	imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]		= imgui.ImVec4(0.70, 0.70, 0.70, 1.00)
	imgui.GetStyle().Colors[imgui.Col.BorderShadow]			= imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
	imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]			= imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]		= imgui.ImVec4(0.90, 0.90, 0.90, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]	= imgui.ImVec4(0.80, 0.80, 0.80, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]	= imgui.ImVec4(0.70, 0.70, 0.70, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]				= imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
	imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]		= imgui.ImVec4(0.20, 0.20, 0.20, 0.80)
	imgui.GetStyle().Colors[imgui.Col.FrameBgActive]		= imgui.ImVec4(0.20, 0.20, 0.20, 0.60)
	imgui.GetStyle().Colors[imgui.Col.CheckMark]			= imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
	imgui.GetStyle().Colors[imgui.Col.Button]				= imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
	imgui.GetStyle().Colors[imgui.Col.ButtonHovered]		= imgui.ImVec4(0.15, 0.15, 0.15, 1.00)
	imgui.GetStyle().Colors[imgui.Col.ButtonActive]			= imgui.ImVec4(0.10, 0.10, 0.10, 1.00)
	imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]		= imgui.ImVec4(0.80, 0.80, 0.80, 0.80)
end