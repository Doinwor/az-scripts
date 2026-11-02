script_name('MediaCenter')
script_version('1.0')
script_version_number(1)
script_author('The Infinite Lua Team')
script_description('A MediaCenter for SA-MP Android. Use /binderlua to open menu.')
local lfs = require("lfs")
local imgui = require('mimgui')
local inicfg = require('inicfg')
local ffi = require('ffi')
if not lfs.attributes("Music") then
    lfs.mkdir("Music")
end

local ini = inicfg.load({
	theme = {
		moonmonet = 759410733,
	},
}, 'MediaCenter.ini')

function isMonetLoader() return MONET_VERSION ~= nil end
if isMonetLoader then local widgets = require('widgets') end
if isMonetLoader() then
    ffi.cdef[[
        void _Z12AND_OpenLinkPKc(const char* link);
    ]]
    function openLink(link)
        gta._Z12AND_OpenLinkPKc(link)
    end
end
local err, monet = pcall(require, 'MoonMonet')
if not err and isMonetLoader() then
    openLink('https://t.me/infinitelua/131')
end
local function join_argb(a, r, g, b)
    local argb = b  -- b
    argb = bit.bor(argb, bit.lshift(g, 8))  -- g
    argb = bit.bor(argb, bit.lshift(r, 16)) -- r     
    argb = bit.bor(argb, bit.lshift(a, 24)) -- a
    return argb
end
local function explode_argb(argb)
    local a = bit.band(bit.rshift(argb, 24), 0xFF)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return a, r, g, b
end
local function ARGBtoRGB(color)
    return bit.band(color, 0xFFFFFF)
end
function rgb2hex(r, g, b)
    local hex = string.format("#%02X%02X%02X", r, g, b)
    return hex
end
function ColorAccentsAdapter(color)
    local a, r, g, b = explode_argb(color)
    local ret = {a = a, r = r, g = g, b = b}
    function ret:apply_alpha(alpha)
        self.a = alpha
        return self
    end
    function ret:as_u32()
        return join_argb(self.a, self.b, self.g, self.r)
    end
    function ret:as_vec4()
        return imgui.ImVec4(self.r / 255, self.g / 255, self.b / 255, self.a / 255)
    end
    function ret:as_argb()
        return join_argb(self.a, self.r, self.g, self.b)
    end
    function ret:as_rgba()
        return join_argb(self.r, self.g, self.b, self.a)
    end
    function ret:as_chat()
        return string.format("%06X", ARGBtoRGB(join_argb(self.a, self.r, self.g, self.b)))
    end  
    return ret
end

function apply_n_t()
    local gen_color = monet.buildColors(ini.theme.moonmonet, 1.0, true)
	local a, r, g, b = explode_argb(gen_color.accent1.color_300)
    curcolor = '{'..rgb2hex(r, g, b)..'}'
    curcolor1 = '0x'..('%X'):format(gen_color.accent1.color_300)
end

imgui.OnInitialize(function()
	local tmp = imgui.ColorConvertU32ToFloat4(ini.theme['moonmonet'])
	gen_color = monet.buildColors(ini.theme.moonmonet, 1.0, true)
	mmcolor = imgui.new.float[3](tmp.z, tmp.y, tmp.x)
end)

status = false
local Volume = imgui.new.float(1)
local mp3Files = {}

for Music in lfs.dir("Music") do
    if Music:match("%.mp3$") then
        table.insert(mp3Files, Music)
    end
end
table.sort(mp3Files)
  
local renderWindow = imgui.new.bool(false)

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
end)

local newFrame = imgui.OnFrame(
    function() 
        return renderWindow[0] 
    end,
    function(player)
        imgui.SetNextWindowPos(imgui.ImVec2(400, 400), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(400, 400), imgui.Cond.FirstUseEver)
        if imgui.Begin('##Main Window', renderWindow) then
            if status == "Включена" and radio then
                if getAudioStreamState(radio) == -1 then
                    status = "Закончена"
                    setAudioStreamState(radio, 0)
                    releaseAudioStream(radio)
                    radio = nil
                end
            end
            apply_monet()
            if imgui.BeginTabBar('Menu') then
                if imgui.BeginTabItem('Настройки MoonMonet') then
		    		imgui.Text('Цвет MoonMonet  -')
		    		imgui.SameLine()
		    		if imgui.ColorEdit3('## COLOR', mmcolor, imgui.ColorEditFlags.NoInputs) then
				    	local r,g,b = mmcolor[0] * 255, mmcolor[1] * 255, mmcolor[2] * 255
				    	local argb = join_argb(0, r, g, b)
			    		ini.theme.moonmonet = argb
			    		apply_n_t()
		    			inicfg.save(ini, 'MediaCenter.ini')
		    		end
		    	    imgui.EndTabItem()
	    	    end
                if imgui.BeginTabItem('Музыкальный центр') then
                    imgui.BeginChild("##NAME", imgui.ImVec2(200, -1), true)
                    for i, Music in ipairs(mp3Files) do
                        if imgui.Button(Music) then
                            Param = Music
                            if radio then
                                if getAudioStreamState(radio) == -1 then
                                    setAudioStreamState(radio, 0)
                                    releaseAudioStream(radio)
                                    radio = nil
                                end
                            end	
                        end
                    end
                    imgui.EndChild()
                    imgui.SameLine()
                    imgui.BeginChild("##NAMEA", imgui.ImVec2(-1, -1), true) 
                    if imgui.Button('Включить песню / аудиокнигу') then
                        if Param and not radio then
                            status = "Включена"
                            radio = loadAudioStream('Music/'..Param)
                            setAudioStreamState(radio, 1)
                            setAudioStreamVolume(radio, 1)
                        elseif status == "Включена" and radio then
                            return
                        end
                    end
                    if imgui.Button('Возобновить песню / аудиокнигу') then
                        if status == "Пауза" and radio then
                            status = "Включена"
                            setAudioStreamState(radio, 3)
                        end
                    end
                    if imgui.Button('Поставить на паузу песню / аудиокнигу') then
                        if status == "Включена" and radio then
                            status = "Пауза"
                            setAudioStreamState(radio, 2)
                        end
                    end
                    if imgui.Button('Выключить песню / аудиокнигу') then
                        if status == "Включена" and radio then
                            status = nil
                            setAudioStreamState(radio, 0)
                            releaseAudioStream(radio)
                            radio = nil
                        end
                    end
                    if not Param then
                        imgui.TextWrapped('Выбранная песня / аyдиокнига: Не выбрано')
                    else
                        imgui.TextWrapped('Выбранная песня / аудиокнига:' ..Param)
                    end
                    if not status then
                        imgui.TextWrapped('Статус песни / аудиокниги: Не выбрано')
                    else
                        imgui.TextWrapped('Статус песни / аудиокниги:' ..status)
                    end
                    imgui.EndTabItem()
                end
	            imgui.EndTabBar()
	        end
            imgui.End()
        end
    end
)

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('mediacenter', function()
        renderWindow[0] = not renderWindow[0]
    end)
    if isMonetLoader() then
        while true do
            if isWidgetSwipedLeft(WIDGET_RADAR) then
                renderWindow[0] = not renderWindow[0]
            end
            wait(0)
        end
    end
	wait(-1)
end

function onScriptTerminate(scr, quitGame)
    if scr == thisScript() then
        if lradio then
            status = nil
            setAudioStreamState(radio, 0)
            releaseAudioStream(radio)
            radio = nil
        end
    end
end

function apply_monet()
	imgui.SwitchContext()
	local style = imgui.GetStyle()
	local colors = style.Colors
	local clr = imgui.Col
	local ImVec4 = imgui.ImVec4
	local generated_color = monet.buildColors(ini.theme['moonmonet'], 1.0, true)
	colors[clr.Text] = ColorAccentsAdapter(generated_color.accent2.color_50):as_vec4()
	colors[clr.TextDisabled] = ColorAccentsAdapter(generated_color.neutral1.color_600):as_vec4()
	colors[clr.WindowBg] = ColorAccentsAdapter(generated_color.accent2.color_900):as_vec4()
	colors[clr.ChildBg] = ColorAccentsAdapter(generated_color.accent2.color_800):as_vec4()
	colors[clr.PopupBg] = ColorAccentsAdapter(generated_color.accent2.color_700):as_vec4()
	colors[clr.Border] = ColorAccentsAdapter(generated_color.accent1.color_200):apply_alpha(0xcc):as_vec4()
	colors[clr.Separator] = ColorAccentsAdapter(generated_color.accent1.color_200):apply_alpha(0xcc):as_vec4()
	colors[clr.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[clr.FrameBg] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x60):as_vec4()
	colors[clr.FrameBgHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x70):as_vec4()
	colors[clr.FrameBgActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x50):as_vec4()
	colors[clr.TitleBg] = ColorAccentsAdapter(generated_color.accent2.color_700):apply_alpha(0xcc):as_vec4()
	colors[clr.TitleBgCollapsed] = ColorAccentsAdapter(generated_color.accent2.color_700):apply_alpha(0x7f):as_vec4()
	colors[clr.TitleBgActive] = ColorAccentsAdapter(generated_color.accent2.color_700):as_vec4()
	colors[clr.MenuBarBg] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x91):as_vec4()
	colors[clr.ScrollbarBg] = imgui.ImVec4(0,0,0,0)
	colors[clr.ScrollbarGrab] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x85):as_vec4()
	colors[clr.ScrollbarGrabHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.ScrollbarGrabActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xb3):as_vec4()
	colors[clr.CheckMark] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
	colors[clr.SliderGrab] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
	colors[clr.SliderGrabActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x80):as_vec4()
	colors[clr.Button] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
	colors[clr.ButtonHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.ButtonActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xb3):as_vec4()
	colors[clr.Tab] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
	colors[clr.TabActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xb3):as_vec4()
	colors[clr.TabHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.Header] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
	colors[clr.HeaderHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.HeaderActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xb3):as_vec4()
	colors[clr.ResizeGrip] = ColorAccentsAdapter(generated_color.accent2.color_700):apply_alpha(0xcc):as_vec4()
	colors[clr.ResizeGripHovered] = ColorAccentsAdapter(generated_color.accent2.color_700):as_vec4()
	colors[clr.ResizeGripActive] = ColorAccentsAdapter(generated_color.accent2.color_700):apply_alpha(0xb3):as_vec4()
	colors[clr.PlotLines] = ColorAccentsAdapter(generated_color.accent2.color_600):as_vec4()
	colors[clr.PlotLinesHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.PlotHistogram] = ColorAccentsAdapter(generated_color.accent2.color_600):as_vec4()
	colors[clr.PlotHistogramHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.TextSelectedBg] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.ModalWindowDimBg] = ColorAccentsAdapter(generated_color.accent1.color_200):apply_alpha(0x26):as_vec4()
end