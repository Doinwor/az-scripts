script_name("Neona")
script_description('Script for Neona')
script_author("MTG MODS")
script_version("1")

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
        imgui.SetNextWindowSize(imgui.ImVec2(200 * MONET_DPI_SCALE, 40 * MONET_DPI_SCALE), imgui.Cond.FirstUseEver)
		imgui.Begin("main", MainWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar  )
		if imgui.Button(fa.PILLS .. u8' Хил ',  imgui.ImVec2(imgui.GetMiddleButtonX(2), 25 * MONET_DPI_SCALE)) then
			sampSendChat('/usedrugs 3')
		end
		imgui.SameLine()
		if imgui.Button(fa.SHIELD .. u8' Армор ',  imgui.ImVec2(imgui.GetMiddleButtonX(2), 25 * MONET_DPI_SCALE)) then
			sampSendChat('/armour')
		end
		imgui.End()
    end
)

function imgui.GetMiddleButtonX(count)
    local width = imgui.GetWindowContentRegionWidth() 
    local space = imgui.GetStyle().ItemSpacing.x
    return count == 1 and width or width/count - ((space * (count-1)) / count)
end