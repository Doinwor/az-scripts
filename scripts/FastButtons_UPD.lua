script_name("FastAction")
script_description('Script for ARZ MODS / Most part taken from mtg mods')
script_author("Lua-Scripter")

require('lib.moonloader')
require ('encoding').default = 'CP1251'
local u8 = require('encoding').UTF8

if MONET_DPI_SCALE == nil then MONET_DPI_SCALE = 1.0 end

local imgui = require('mimgui')
local fa = require('fAwesome6_solid')
local sizeX, sizeY = getScreenResolution()

local MainWindow = imgui.new.bool()

function main()

	if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end 

    MainWindow[0] = true

    wait(-1)

end

imgui.OnInitialize(function()
	imgui.GetIO().IniFilename = ni
	fa.Init(14 * MONET_DPI_SCALE)
end)

imgui.OnFrame(
    function() return MainWindow[0] end,
    function(player)
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 8.5, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(320 * MONET_DPI_SCALE, 80 * MONET_DPI_SCALE), imgui.Cond.FirstUseEver)

        local bg = imgui.ImVec4(0.4, 0.1, 0.1, 0.8)
        local red = imgui.ImVec4(0.8, 0.1, 0.1, 1.0)
        local red_hover = imgui.ImVec4(1.0, 0.2, 0.2, 1.0)
        local red_active = imgui.ImVec4(0.6, 0.05, 0.05, 1.0)
        local white = imgui.ImVec4(1, 1, 1, 1)

        imgui.PushStyleColor(imgui.Col.WindowBg, bg)
        imgui.PushStyleColor(imgui.Col.Button, red)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, red_hover)
        imgui.PushStyleColor(imgui.Col.ButtonActive, red_active)
        imgui.PushStyleColor(imgui.Col.Text, white)

        imgui.Begin("main", MainWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize)

        if imgui.Button(fa.PILLS .. u8' Нарко', imgui.ImVec2(150 * MONET_DPI_SCALE, 25 * MONET_DPI_SCALE)) then
            sampSendChat('/usedrugs 3')
        end
        imgui.SameLine()
        if imgui.Button(fa.SHIELD .. u8' Броник', imgui.ImVec2(150 * MONET_DPI_SCALE, 25 * MONET_DPI_SCALE)) then
            sampSendChat('/armour')
        end

        if imgui.Button(fa.MOTORCYCLE .. u8' NRG (/plveh)', imgui.ImVec2(150 * MONET_DPI_SCALE, 25 * MONET_DPI_SCALE)) then
            sampSendChat('/plveh 522 1 1')
        end
        imgui.SameLine()
        if imgui.Button(fa.CAR .. u8' Infernus (/plveh)', imgui.ImVec2(150 * MONET_DPI_SCALE, 25 * MONET_DPI_SCALE)) then
            sampSendChat('/plveh 411 1 1')
        end

        imgui.End()
        imgui.PopStyleColor(5)
    end
)

function imgui.GetMiddleButtonX(count)
    local width = imgui.GetWindowContentRegionWidth() 
    local space = imgui.GetStyle().ItemSpacing.x
    return count == 1 and width or width/count - ((space * (count-1)) / count)
end