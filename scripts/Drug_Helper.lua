-- ну и как тебе код?


local imgui = require 'mimgui'
local inicfg = require 'inicfg'
local ffi = require 'ffi'
local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local directIni = 'DrugByLanger.ini'
local ini = inicfg.load({
    main = {
        tag = "сосо",
        autod = false,
        health = 30,
        sbiv = false,
        autoh = false,
        armour = false,
        drug = false,
    },
}, directIni)
inicfg.save(ini, directIni)
require 'widgets'

local new = imgui.new
local sbiv = new.bool(ini.main.sbiv)
local tag = new.char[64](ini.main.tag)
local health = new.bool(ini.main.health)
local autod = new.bool(ini.main.autod)
local autoh = new.int(ini.main.autoh)
local armour = new.bool(ini.main.armour)
local drug = new.bool(ini.main.drug)

function savecfg()
    ini.main.sbiv = sbiv[0]
    ini.main.tag = tag[0]
    ini.main.health = health[0]
    ini.main.autod = autod[0]
    ini.main.autoh = autoh[0]
    ini.main.armour = armour[0]
    ini.main.drug = drug[0]
    inicfg.save(ini, directIni)
end

local renderWindow = imgui.new.bool(false)

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    violet()
end)

local newFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(580, 360), imgui.Cond.FirstUseEver)
        if imgui.Begin('Drug helper', renderWindow) then
            if imgui.Checkbox(u8"Исп. наркотиков на кнопку", drug) then
                if drug[0] then
                    ddrug()
                end
            end
            if drug[0] then
                imgui.Checkbox(u8"Сбив анимаций", sbiv)
                if sbiv[0] then
                    imgui.InputText(u8"Фраза для сбива", tag, ffi.sizeof(tag))
                end
            end
            imgui.Separator()
            imgui.Checkbox(u8"Автоматически пополнение хп", health)
            if health[0] then
                imgui.InputInt("", autoh)
                imgui.Text(u8"Выберите при каких кол.во хп использовать")
            end
            imgui.Separator()
            --imgui.Checkbox(u8"", autod)
            if imgui.Checkbox(u8"Исп. армора на кнопку", armour) then
                if armour[0] then
                    armourr()
                end
            end
            imgui.Separator()
            if imgui.Button(u8"Сохранить") then
                savecfg()
            end
            imgui.Text(u8"Автор: Langerv")
        end     
    imgui.End()
end)

function main()
    while not isSampAvailable() do wait(0) end
    if drug[0] then
                    ddrug()
                end
                if armour[0] then
                    armourr()
                end
    sampRegisterChatCommand('drmenu', function()
        renderWindow[0] = not renderWindow[0]
    end)
    while true do
        wait(0)
        local healthh = getCharHealth(PLAYER_PED)
        if health[0] and healthh < autoh[0] then
            sampSendChat("/usedrugs 3")
        end
    end
end

function ddrug()
    lua_thread.create(function()
        while drug[0] do
            wait(0)
            local pressed_menu = isWidgetPressed(WIDGET_SWAP_WEAPONS)
            if drug[0] and pressed_menu and not was_pressed_menu then
                sampSendChat("/usedrugs 3")
                wait(500)
                if sbiv[0] then
                    sampSendChat(u8:decode(ffi.string(tag)))
                end
            end
        end
    end)
end

function armourr()
    lua_thread.create(function()
        while armour[0] do
            wait(0)
            local pressed_menuu = isWidgetPressed(WIDGET_KISS)
            if armour and pressed_menuu and not was_pressed_menuu then
                sampSendChat("/armour")
            end
        end
    end)
end

function violet()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    style.WindowRounding = 10
    style.ChildRounding = 10
    style.FrameRounding = 6.0
    style.ItemSpacing = imgui.ImVec2(3.0, 3.0)
    style.ItemInnerSpacing = imgui.ImVec2(3.0, 3.0)
    style.FramePadding = imgui.ImVec2(4.0, 3.0)
    style.IndentSpacing = 21
    style.ScrollbarSize = 17.0
    style.ScrollbarRounding = 13
    style.GrabMinSize = 17.0
    style.GrabRounding = 16.0
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    colors[clr.WindowBg]			  = ImVec4(0.14, 0.12, 0.16, 1.00)
    colors[clr.ChildBg]		 = ImVec4(0.30, 0.20, 0.39, 0.40)
    colors[clr.PopupBg]			   = ImVec4(0.05, 0.05, 0.10, 0.90)
    colors[clr.Border]				= ImVec4(0.89, 0.85, 0.92, 0.30)
    colors[clr.BorderShadow]		  = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.FrameBg]			   = ImVec4(0.30, 0.20, 0.39, 1.00)
    colors[clr.FrameBgHovered]		= ImVec4(0.41, 0.19, 0.63, 0.68)
    colors[clr.FrameBgActive]		 = ImVec4(0.41, 0.19, 0.63, 1.00)
    colors[clr.TitleBg]			   = ImVec4(0.41, 0.19, 0.63, 0.45)
    colors[clr.TitleBgCollapsed]	  = ImVec4(0.41, 0.19, 0.63, 0.35)
    colors[clr.TitleBgActive]		 = ImVec4(0.41, 0.19, 0.63, 0.78)
    colors[clr.MenuBarBg]			 = ImVec4(0.30, 0.20, 0.39, 0.57)
    colors[clr.ScrollbarBg]		   = ImVec4(0.30, 0.20, 0.39, 1.00)
    colors[clr.ScrollbarGrab]		 = ImVec4(0.41, 0.19, 0.63, 0.31)
    colors[clr.ScrollbarGrabHovered]  = ImVec4(0.41, 0.19, 0.63, 0.78)
    colors[clr.ScrollbarGrabActive]   = ImVec4(0.41, 0.19, 0.63, 1.00)
    colors[clr.CheckMark]			 = ImVec4(0.56, 0.61, 1.00, 1.00)
    colors[clr.SliderGrab]			= ImVec4(0.41, 0.19, 0.63, 0.24)
    colors[clr.SliderGrabActive]	  = ImVec4(0.41, 0.19, 0.63, 1.00)
    colors[clr.Button]				= ImVec4(0.41, 0.19, 0.63, 0.44)
    colors[clr.ButtonHovered]		 = ImVec4(0.41, 0.19, 0.63, 0.86)
    colors[clr.ButtonActive]		  = ImVec4(0.64, 0.33, 0.94, 1.00)
    colors[clr.Header]				= ImVec4(0.41, 0.19, 0.63, 0.76)
    colors[clr.HeaderHovered]		 = ImVec4(0.41, 0.19, 0.63, 0.86)
    colors[clr.HeaderActive]		  = ImVec4(0.41, 0.19, 0.63, 1.00)
    colors[clr.ResizeGrip]			= ImVec4(0.41, 0.19, 0.63, 0.20)
    colors[clr.ResizeGripHovered]	 = ImVec4(0.41, 0.19, 0.63, 0.78)
    colors[clr.ResizeGripActive]	  = ImVec4(0.41, 0.19, 0.63, 1.00)
    colors[clr.PlotLines]			 = ImVec4(0.89, 0.85, 0.92, 0.63)
    colors[clr.PlotLinesHovered]	  = ImVec4(0.41, 0.19, 0.63, 1.00)
    colors[clr.PlotHistogram]		 = ImVec4(0.89, 0.85, 0.92, 0.63)
    colors[clr.PlotHistogramHovered]  = ImVec4(0.41, 0.19, 0.63, 1.00)
    colors[clr.TextSelectedBg]		= ImVec4(0.41, 0.19, 0.63, 0.43)
    colors[clr.TextDisabled]		  = ImVec4(0.41, 0.19, 0.63, 1.00)
    colors[clr.ModalWindowDimBg]  = ImVec4(0.20, 0.20, 0.20, 0.35)
end