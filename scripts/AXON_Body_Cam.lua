local ffi = require "ffi"
script_author('chapo')
local imgui = require 'mimgui'

local inicfg = require 'inicfg'
local directIni = 'AxonBodyCam.ini'
local ini = inicfg.load(inicfg.load({
    main = {
        enabled = true,
        posX = 500,
        posY = 500,
        rpBodycam = true,
        timeBk = false,
        videoRp = false,
    },
}, directIni))
inicfg.save(ini, directIni)
if ini.main.ID then
    ID = ini.main.ID
else
    ini.main.ID = math.random(100000, 999999)
    inicfg.save(ini, directIni)
end
local encoding = require("encoding")

encoding.default = 'CP1251'
local u8 = encoding.UTF8

local POS = imgui.ImVec2(ini.main.posX, ini.main.posY)
local renderWindow = imgui.new.bool(true)
local Window = imgui.new.bool(false)
local Font = nil
local status = false
local rpBodycam = imgui.new.bool(ini.main.rpBodycam)
local timeBk = imgui.new.bool(ini.main.timeBk)
local videoRp = imgui.new.bool(ini.main.videoRp)
local BkNumber = imgui.new.int(ini.main.ID)
local Image = {
    file = 'AXON_BodyCam.png',
    url = 'https://steamuserimages-a.akamaihd.net/ugc/2259182745988115543/D2479E5CDE47F48C415BF4133DCAAA58452FA7D5/?imw=512&amp;&amp;ima=fit&amp;impolicy=Letterbox&amp;imcolor=%23000000&amp;letterbox=false',
    img = nil
}
function DarkTheme()
    imgui.SwitchContext()
    --==[ STYLE ]==--
    imgui.GetStyle().WindowPadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().FramePadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(2, 2)
    imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(0, 0)
    imgui.GetStyle().IndentSpacing = 0
    imgui.GetStyle().ScrollbarSize = 10
    imgui.GetStyle().GrabMinSize = 10

    --==[ BORDER ]==--
    imgui.GetStyle().WindowBorderSize = 1
    imgui.GetStyle().ChildBorderSize = 1
    imgui.GetStyle().PopupBorderSize = 1
    imgui.GetStyle().FrameBorderSize = 1
    imgui.GetStyle().TabBorderSize = 1

    --==[ ROUNDING ]==--
    imgui.GetStyle().WindowRounding = 5
    imgui.GetStyle().ChildRounding = 5
    imgui.GetStyle().FrameRounding = 5
    imgui.GetStyle().PopupRounding = 5
    imgui.GetStyle().ScrollbarRounding = 5
    imgui.GetStyle().GrabRounding = 5
    imgui.GetStyle().TabRounding = 5

    --==[ ALIGN ]==--
    imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().SelectableTextAlign = imgui.ImVec2(0.5, 0.5)
    
    --==[ COLORS ]==--
    imgui.GetStyle().Colors[imgui.Col.Text]                   = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Border]                 = imgui.ImVec4(0.25, 0.25, 0.26, 0.54)
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.51, 0.51, 0.51, 1.00)
    imgui.GetStyle().Colors[imgui.Col.CheckMark]              = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button]                 = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header]                 = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.47, 0.47, 0.47, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Separator]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(1.00, 1.00, 1.00, 0.67)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(1.00, 1.00, 1.00, 0.95)
    imgui.GetStyle().Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.28, 0.28, 0.28, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocused]           = imgui.ImVec4(0.07, 0.10, 0.15, 0.97)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive]     = imgui.ImVec4(0.14, 0.26, 0.42, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines]              = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]       = imgui.ImVec4(1.00, 0.43, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]          = imgui.ImVec4(0.90, 0.70, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]   = imgui.ImVec4(1.00, 0.60, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(1.00, 0.00, 0.00, 0.35)
    imgui.GetStyle().Colors[imgui.Col.DragDropTarget]         = imgui.ImVec4(1.00, 1.00, 0.00, 0.90)
    imgui.GetStyle().Colors[imgui.Col.NavHighlight]           = imgui.ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight]  = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg]      = imgui.ImVec4(0.80, 0.80, 0.80, 0.20)
    imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.00, 0.00, 0.00, 0.70)
end
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    local defGlyph = imgui.GetIO().Fonts.ConfigData.Data[0].GlyphRanges
    local font_config = imgui.ImFontConfig()
    font_config.SizePixels = 14.0
    font_config.GlyphExtraSpacing.x = 0.1
    Font = imgui.GetIO().Fonts:AddFontFromFileTTF("trebucbd.ttf", 25, font_config, defGlyph)
	DarkTheme()
    if doesFileExist(Image.file) then
        Image.img = imgui.CreateTextureFromFile(Image.file)
    end
end)


local Frame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(self)
        self.HideCursor = not posedit
        imgui.SetNextWindowPos(POS, imgui.Cond.FirstUseEver, imgui.ImVec2(0, 0))
        imgui.SetNextWindowSize(imgui.ImVec2(385, 120), imgui.Cond.Always)
        if imgui.Begin('AXON Body Cam (by chapo)', renderWindow, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + (posedit and 0 or imgui.WindowFlags.NoMove + imgui.WindowFlags.NoBackground)) then
            POS = imgui.GetWindowPos()
            imgui.SetCursorPos(imgui.ImVec2(10, 35))
            imgui.PushFont(Font)
            imgui.OutlineText(os.date('%Y-%m-%d T%H:%M:%S')..'\nAXON BODY 2 X'..tostring(ID), 2, imgui.ImVec4(1, 1, 1, 1), imgui.ImVec4(0, 0, 0, 1))
            imgui.PopFont()

            imgui.SetCursorPos(imgui.ImVec2(270, 10))
            imgui.Image(Image.img, imgui.ImVec2(100, 100))
            imgui.End()
        end
    end
)
local http = require("socket.http")
local ltn12 = require("ltn12")
local function downloadUrlToFile(url, path)

  local response = {}
  local _, status_code, _ = http.request{
    url = url,
    method = "GET",
    sink = ltn12.sink.file(io.open(path, "w")),
    headers = {
      ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0;Win64) AppleWebkit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.82 Safari/537.36",

    },
  }

  if status_code == 200 then
    return true
  else
    return false
  end
end
function main()
    while not isSampAvailable() do wait(0) end
    sampAddChatMessage('{ffd700}[AXON]:{ffffff} Loaded, use {ffd700}/axon', 0xFFffd700)
    if not doesFileExist(Image.file) then
        local dlstatus = require('moonloader').download_status
        downloadUrlToFile(Image.url, Image.file, function (id, status, p1, p2)
            if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                sampAddChatMessage('{ffd700}[AXON]:{ffffff} Body cam logo loaded, restarting...', 0xFFffd700)
                thisScript():reload()
            end
        end)
    end
    sampRegisterChatCommand('axon.m', function()
        Window[0] = not Window[0]
    end)
    sampRegisterChatCommand('axon', bk)
    sampRegisterChatCommand('axon.set', function()
        renderWindow[0] = not renderWindow[0]
        ini.main.enabled = renderWindow[0]
        inicfg.save(ini, directIni)
        sampAddChatMessage('{ffd700}[AXON]:{ffffff} Body camera '..(renderWindow[0] and '{6eff72}on' or '{ff6e6e}off'), 0xFFffd700)
    end)
    sampRegisterChatCommand('axon.pos', function()
        if renderWindow[0] then
            posedit = not posedit
            if posedit then
                sampAddChatMessage('{ffd700}[AXON]:{ffffff} Use /axon.pos to save!', 0xFFffd700)
            else
                sampAddChatMessage('{ffd700}[AXON]:{ffffff} Position '..POS.x..', '..POS.y..' saved!', 0xFFffd700)
                ini.main.posX, ini.main.posY = POS.x, POS.y
                inicfg.save(ini, directIni)
            end
        else
            sampAddChatMessage('{ffd700}[AXON]:{ffffff} Enable body cam to change position!', 0xFFffd700)
        end
    end)
    wait(-1)
end

function imgui.OutlineText(text, outlineSize, textColor, outlineColor)
    local outlineSize = outlineSize or 1
    local c = imgui.GetCursorPos()
    imgui.SetCursorPos(imgui.ImVec2(c.x - outlineSize, c.y)) -- left
    imgui.TextColored(outlineColor or imgui.ImVec4(0, 0, 0, 0.3), text)
    imgui.SetCursorPos(imgui.ImVec2(c.x + outlineSize, c.y)) -- right
    imgui.TextColored(outlineColor or imgui.ImVec4(0, 0, 0, 0.3), text)
    imgui.SetCursorPos(imgui.ImVec2(c.x, c.y - outlineSize)) -- bottom
    imgui.TextColored(outlineColor or imgui.ImVec4(0, 0, 0, 0.3), text)
    imgui.SetCursorPos(imgui.ImVec2(c.x, c.y + outlineSize)) -- upper
    imgui.TextColored(outlineColor or imgui.ImVec4(0, 0, 0, 0.3), text)
    imgui.SetCursorPos(imgui.ImVec2(c.x - outlineSize, c.y + outlineSize)) -- upper-left
    imgui.TextColored(outlineColor or imgui.ImVec4(0, 0, 0, 0.3), text)
    imgui.SetCursorPos(imgui.ImVec2(c.x + outlineSize, c.y + outlineSize)) -- upper-right
    imgui.TextColored(outlineColor or imgui.ImVec4(0, 0, 0, 0.3), text)
    imgui.SetCursorPos(imgui.ImVec2(c.x - outlineSize, c.y - outlineSize)) -- bottom-left
    imgui.TextColored(outlineColor or imgui.ImVec4(0, 0, 0, 0.3), text)
    imgui.SetCursorPos(imgui.ImVec2(c.x + outlineSize, c.y - outlineSize)) -- bottom-right
    imgui.TextColored(outlineColor or imgui.ImVec4(0, 0, 0, 0.3), text)
    imgui.SetCursorPos(c)
    imgui.TextColored(textColor or imgui.ImVec4(1, 1, 1, 1), text)
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


local WindowFrame = imgui.OnFrame(
    function() return Window[0] end,
    function(self)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 300, 300
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        if UI.Begin('Axon Bodycam', Window, 0, Tabs) then

            if UI.tab == 1 then
                imgui.Checkbox(u8"РП отыгровка б-к при вводе /axon", rpBodycam)
                imgui.Checkbox(u8"/time в начале и в конце", timeBk)
                imgui.Checkbox(u8"Отыгрывать РП видео регистратора если в авто", videoRp)
                imgui.InputInt(u8"Номер вашей б-к", BkNumber, 10)
                
                if imgui.Button(u8"Сохранить") then
                    ini.main.rpBodycam = rpBodycam[0]
                    ini.main.timeBk = timeBk[0]
                    ini.main.videoRp = videoRp[0]
                    if BkNumber[0] ~= ID then
                        ini.main.ID = BkNumber[0]
                    end
                    inicfg.save(ini, directIni)
                end

            end 
			if UI.tab == 2 then
                imgui.Text(u8'AxonBodyCam\nСкрипт эмулирует боли камеру.\n Активация /axon. \nАвтор: @daniel2903_pon\n Версия 2.0')
            end

            UI.End()
        end
    end
)


function bk()
    if status == false then
        status = true
        if ini.main.rpBodycam then
            if isCharInAnyCar(PLAYER_PED) and ini.main.videoRp then
                if ini.main.timeBk then
                    lua_thread.create(function ()
                        sampSendChat("/time")
                        wait(1500)
                        sampSendChat("/do На лобовом стекле висит видеорегистратор с доступом в интернет.")
                        wait(1500)
                        sampSendChat("/me незаметным движением руки нажимает на сенсерную панель видеорегистратора")
                        wait(1500)
                        sampSendChat("/do видеорегистратор включен, ведёт онлайн видеофиксацию на сервер офиса.")
                    end)
                else
                    lua_thread.create(function ()
                        sampSendChat("/do На лобовом стекле висит видеорегистратор с доступом в интернет.")
                        wait(1500)
                        sampSendChat("/me незаметным движением руки нажимает на сенсерную панель видеорегистратора")
                        wait(1500)
                        sampSendChat("/do видеорегистратор включен, ведёт онлайн видеофиксацию на сервер офиса.")
                    end)
                end 
            else
                if ini.main.timeBk then
                    lua_thread.create(function ()
                        sampSendChat("/time")
                        wait(1500)
                        sampSendChat("/do На груди висит скрыта боди-камера с доступом в интернет.")
                        wait(1500)
                        sampSendChat("/me незаметным движением руки нажимает на сенсерную панель боди-камеры")
                        wait(1500)
                        sampSendChat("/do Боди-камера включена, ведёт онлайн видеофиксацию на сервер офиса.")
                    end)
                else
                    lua_thread.create(function ()
                        sampSendChat("/do На груди висит скрыта боди-камера с доступом в интернет.")
                        wait(1500)
                        sampSendChat("/me незаметным движением руки нажимает на сенсерную панель боди-камеры")
                        wait(1500)
                        sampSendChat("/do Боди-камера включена, ведёт онлайн видеофиксацию на сервер офиса.")
                    end)
                end 
            end
        end
    else
        status = true
        if ini.main.rpBodycam then
            if isCharInAnyCar(PLAYER_PED) and ini.main.videoRp then
                if ini.main.timeBk then
                    lua_thread.create(function ()
                        sampSendChat("/time")
                        wait(1500)
                        sampSendChat("/do На лобовом стекле висит видеорегистратор с доступом в интернет.")
                        wait(1500)
                        sampSendChat("/me незаметным движением руки нажимает на сенсерную панель видеорегистратора")
                        wait(1500)
                        sampSendChat("/do видеорегистратор выключен, запись сохранена на сервер офиса.")
                    end)
                else
                    lua_thread.create(function ()
                        sampSendChat("/do На лобовом стекле висит видеорегистратор с доступом в интернет.")
                        wait(1500)
                        sampSendChat("/me незаметным движением руки нажимает на сенсерную панель видеорегистратора")
                        wait(1500)
                        sampSendChat("/do видеорегистратор выключен, запись сохранена на сервер офиса.")
                    end)
                end 
            else
                if ini.main.timeBk then
                    lua_thread.create(function ()
                        sampSendChat("/time")
                        wait(1500)
                        sampSendChat("/do На груди висит скрыта боди-камера с доступом в интернет.")
                        wait(1500)
                        sampSendChat("/me незаметным движением руки нажимает на сенсерную панель боди-камеры")
                        wait(1500)
                        sampSendChat("/do Боди камера выключена, запись сохранилась на сервер офиса.")
                    end)
                else
                    lua_thread.create(function ()
                        sampSendChat("/do На груди висит скрыта боди-камера с доступом в интернет.")
                        wait(1500)
                        sampSendChat("/me незаметным движением руки нажимает на сенсерную панель боди-камеры")
                        wait(1500)
                        sampSendChat("/do Боди камера выключена, запись сохранилась на сервер офиса.")
                    end)
                end 
            end
        end
    end
end