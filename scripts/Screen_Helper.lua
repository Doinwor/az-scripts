-- Скрипт был создан t.me/beavers_best, если вы это читаете файл не был модифицирован
-- Скрипт был создан t.me/beavers_best, если вы это читаете файл не был модифицирован
-- Скрипт был создан t.me/beavers_best, если вы это читаете файл не был модифицирован

local script_authorr = "lua_helpers"
local ffi = require("ffi")
local gta = ffi.load("GTASA")
local imgui = require("mimgui")
local encoding = require("encoding")
encoding.default = "CP1251"
local u8 = encoding.UTF8
local new = imgui.new
local faicons = require("fAwesome6")
local fa = faicons
local new, str = imgui.new, ffi.string
local request = require("requests")
local version = "2.6"
local sampev = require("samp.events")
local monet = require("MoonMonet")
local url = {
	version = "https://pastebin.com/raw/TTLj6b49",
}
local url_result = {
	versionn = request.get(url.version).text,
}

local inicfg = require "inicfg"
local ini = inicfg.load({
    cfg =
    {
		col1 = "{FFFFFF}",
		col2 = "{FFFFFF}",
		toggled_sm = false,
		clean_kol = 15,
		textdraw_status = false,
		toggled_cs = false,
		fov_int = 60,
		activation = "sh"
    },
	theme = {
		theme = "blue",
		selected = 0,
		moonmonet = 759410733,
	}}, "Screen Helper.ini")

local tagg = ""..ini.cfg.col1.."["..ini.cfg.col2.."Screen Helper"..ini.cfg.col1.."]: "

local tab = 1

local selected_theme = imgui.new.int(ini.theme.selected)
local theme_a = {u8"Красная", u8"Зелёная",u8"Синяя", u8"Темная", u8"Фиолетовая", u8"Фиолетовая #2", u8"Красная #2", 'MoonMonet'}
local theme_t = {u8'red', u8'green', u8'blue', u8'black', 'purple', 'purple2', 'red2', 'moonmonet'}
local items = imgui.new['const char*'][#theme_a](theme_a)

function apply_n_t()
	if ini.theme.theme == 'blue' then
    	ini.cfg.col1 = "{7575FF}"
        ini.cfg.col2 = "{2E2EFF}"
        cfg_save()
		bluetheme()
	elseif ini.theme.theme == 'green' then
 	   ini.cfg.col1 = "{BFFF7E}"
        ini.cfg.col2 = "{9FFF3E}"
        cfg_save()
	    greentheme()
	elseif ini.theme.theme == 'red' then
    	ini.cfg.col1 = "{FF8383}"
        ini.cfg.col2 = "{FF3333}"
        cfg_save()
		redtheme()
	elseif ini.theme.theme == 'purple' then
	    ini.cfg.col1 = "{AE67FF}"
        ini.cfg.col2 = "{973BFF}"
        cfg_save()
		purpletheme()
	elseif ini.theme.theme == 'black' then
	    ini.cfg.col1 = "{A4A4A4}"
        ini.cfg.col2 = "{666666}"
        cfg_save()
		blacktheme()
	elseif ini.theme.theme == 'purple2' then
	   ini.cfg.col1 = "{6C36AA}"
       ini.cfg.col2 = "{0E1C84}"
       cfg_save()
	   purpletheme2()
	elseif ini.theme.theme == 'red2' then
	   ini.cfg.col1 = "{950200}"
       ini.cfg.col2 = "{5B0100}"
       cfg_save()
	   redtheme2()
	elseif ini.theme.theme == 'moonmonet' then
		gen_color = monet.buildColors(ini.theme.moonmonet, 1.0, true)
		local a, r, g, b = explode_argb(gen_color.accent1.color_300)
		ini.cfg.col1 = '{'..rgb2hex(r, g, b)..'}'
		ini.cfg.col2 = '{'..rgb2hex(r, g, b)..'}'
		curcolor1 = '0x'..('%X'):format(gen_color.accent1.color_300)
		apply_monet()
		cfg_save()
		ini.cfg.col1 = ini.cfg.col1:gsub("#", "")
		ini.cfg.col2 = ini.cfg.col2:gsub("#", "")
		cfg_save()
	end
end


local toggled_sm = new.bool(ini.cfg.toggled_sm)
local clean_kol = new.int(ini.cfg.clean_kol)
local hud_status = new.bool()
local textdraw_status = new.bool(ini.cfg.textdraw_status)
local toggled_cs = new.bool(ini.cfg.toggled_cs)
local fov_int = new.int(ini.cfg.fov_int)

local activation = new.char[256](u8(ini.cfg.activation))

local WinState = new.bool()

local toggled = true
EXPORTS = {
	canToggle = function() return true end,
	getToggle = function() return toggled end,
	toggle = function()
		toggled = not toggled
		WinState[0] = not WinState[0]
	end
}


imgui.OnFrame(function()
    return WinState[0]
end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500, 700), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    moonmonet()
    imgui.Begin(u8"Screen Helper by "..fa("paper_plane").." lua_helpers", WinState, imgui.WindowFlags.NoResize)

	apply_n_t()

	if imgui.Button(fa("user")..u8" Основное", imgui.ImVec2(170, 60)) then tab = 1 end
	if imgui.Button(fa("gear")..u8" Настройки", imgui.ImVec2(170, 60)) then tab = 2 end
	if imgui.Button(fa("info")..u8" О скрипте", imgui.ImVec2(170, 60)) then tab = 3 end
	if imgui.InvisibleButton(u8"Пасхалка", imgui.ImVec2(165, 50)) then tab = "secret" end

    imgui.SetCursorPos(imgui.ImVec2(175, 33))
    if imgui.BeginChild("Пасхалочка"..tab, imgui.ImVec2(700, 550), true) then

if tab == 1 then
	if imgui.Button(u8"Блокировка сообщений в чат", imgui.ImVec2(-1, 40)) then tab = 4 end
	imgui.Separator()
	if imgui.Button(u8"Очистка чата", imgui.ImVec2(-1, 40)) then tab = 5 end
	imgui.Separator()
	imgui.Text(u8"Может багаться из-за CEF радара")
	if imgui.Button(u8"Показывать радар", imgui.ImVec2(-1, 40)) then displayRadar(true) end
	if imgui.Button(u8"Не показывать радар", imgui.ImVec2(-1, 40)) then displayRadar(false) end
	imgui.Separator()
	imgui.Text(u8"Может багаться из-за CEF худа")
	if imgui.Button(u8"Показывать худ", imgui.ImVec2(-1, 40)) then displayHud(true) end
	if imgui.Button(u8"Не показывать худ", imgui.ImVec2(-1, 40)) then displayHud(false) end
	imgui.Separator()
	if imgui.Button(u8"SpeedShake", imgui.ImVec2(-1, 40)) then tab = 6 end
	if imgui.Button(u8"FovChange", imgui.ImVec2(-1, 40)) then tab = 7 end
	imgui.Separator()
	imgui.TextWrapped(u8"Советуем использовать: /timestamp - Для убирания времени в чате | /fontsize 0.1 - Для лучшего результата")
end

if tab == 2 then
	if imgui.Combo(u8'##theme', selected_theme, items, #theme_a) then
    	themeta = theme_t[selected_theme[0]+1]
		ini.theme.theme = themeta
		ini.theme.selected = selected_theme[0]
		cfg_save()
	end
	imgui.TextWrapped(u8'Цвет MoonMonet [ Вызывает лаги ] -')
	imgui.SameLine()
	if imgui.ColorEdit3('## COLOR', mmcolor, imgui.ColorEditFlags.NoInputs) then
		local r,g,b = mmcolor[0] * 255, mmcolor[1] * 255, mmcolor[2] * 255
		local argb = join_argb(0, r, g, b)
		ini.theme.moonmonet = argb
		apply_n_t()
		cfg_save()
	end
	if string.find(ini.cfg.activation, "%s", 1, true) then
		sampAddChatMessage(""..tagg.."В активации обнаружены пробелы. Активация изменена на /sh", -1)
		ini.cfg.activation = "sh"
		cfg_save()
	end
	imgui.InputTextWithHint(u8"Активация", u8"Без слеша!", activation, 256)
	if imgui.Button(fa("play")..u8" Сохранить") then
		ini.cfg.activation = u8:decode(str(activation))
		cfg_save()
		sampAddChatMessage(""..tagg.."Сохранено! Активация - "..ini.cfg.activation, -1)
		script_reload()
	end
	if imgui.Button(fa("rotate_right") .. u8" Перезагрузить") then script_reload() end
	if imgui.Button(fa("trash") .. u8" Выгрузить") then script_unload() end
end

if tab == 3 then
	if imgui.CollapsingHeader(fa("users")..u8" Авторы") then
		imgui.Text(u8"t.me/lua_helpers - ТГК разработчика")
		imgui.Text(u8"t.me/beavers_best - Разработчик")
		imgui.TextWrapped(u8"Сделано при поддержке Arizona FUN <3")
	end
	if imgui.CollapsingHeader(fa("arrow_up")..u8" Переход") then
		if imgui.Button(u8"Перейти в ТГК") then openLink("https://t.me/lua_helpers") end
		if imgui.Button(u8"Перейти к разработчику") then openLink("https://t.me/beavers_best") end
		if imgui.Button(u8"Перейти к Arizona Fun") then openLink("https://t.me/ArizonamobileFun") end
	end
	if imgui.CollapsingHeader(fa("file_pen")..u8" Обновление") then
		if imgui.Button(u8"Проверить обновления", imgui.ImVec2(280, 40)) then
			check_version()
			if version == url_result.versionn then
			sampAddChatMessage(""..tagg.."Обновлений не найдено", -1)
			end
		end
	end
end

if tab == "secret" then
	imgui.TextWrapped(u8"Вы нашли пасхалку от Даркича")
	imgui.TextWrapped(u8"Спасибо Пацохе за предложение сотрудничать с аризона фан")
end

if tab == 4 then
	imgui.Checkbox(u8"Блокировка сообщений в чате", toggled_sm)
	ini.cfg.toggled_sm = toggled_sm[0]
	cfg_save()
	if imgui.Button(fa("arrow_left")..u8" Назад", imgui.ImVec2(170, 60)) then tab = 1 end
end

if tab == 5 then
	if imgui.Button(u8"Очистить чат") then for i = 1, ini.cfg.clean_kol do sampAddChatMessage("", -1) end end
	imgui.InputInt(u8"Сколько строк ...", clean_kol)
	if clean_kol[0] < 1 then
		clean_kol[0] = 1
	else
		ini.cfg.clean_kol = clean_kol[0]
		cfg_save()
	end
	imgui.Text(u8"... очищать")
	if imgui.Button(fa("arrow_left")..u8" Назад", imgui.ImVec2(170, 60)) then tab = 1 end
end

if tab == 6 then
	imgui.Checkbox(u8"Тряска на большой скорости", toggled_cs)
	ini.cfg.toggled_cs = toggled_cs[0]
	cfg_save()
	if imgui.Button(fa("arrow_left")..u8" Назад", imgui.ImVec2(170, 60)) then tab = 1 end
end

if tab == 7 then
	imgui.SliderInt(u8"Fov", fov_int, 10, 135)
	ini.cfg.fov_int = fov_int[0]
	cfg_save()
	if imgui.Button(u8"Сбросить", imgui.ImVec2(170, 60)) then fov_int[0] = 60 end
	if imgui.Button(fa("arrow_left")..u8" Назад", imgui.ImVec2(170, 60)) then tab = 1 end
end

        imgui.EndChild()
    end

    imgui.End()
end)

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85("duotune"), 17, config, iconRanges)
	local tmp = imgui.ColorConvertU32ToFloat4(ini.theme.moonmonet)
	gen_color = monet.buildColors(ini.theme.moonmonet, 1.0, true)
	mmcolor = new.float[3](tmp.z, tmp.y, tmp.x)
	decor()
end)

function cfg_save()
inicfg.save(ini, "Screen Helper.ini")
end

function redtheme()
    local ImVec4 = imgui.ImVec4
    imgui.SwitchContext()
    imgui.GetStyle().Colors[imgui.Col.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.94)
    imgui.GetStyle().Colors[imgui.Col.ChildBg]                = ImVec4(1.00, 1.00, 1.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
    imgui.GetStyle().Colors[imgui.Col.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50)
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]                = ImVec4(0.48, 0.16, 0.16, 0.54)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = ImVec4(0.98, 0.26, 0.26, 0.40)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = ImVec4(0.98, 0.26, 0.26, 0.67)
    imgui.GetStyle().Colors[imgui.Col.TitleBg]                = ImVec4(0.04, 0.04, 0.04, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]          = ImVec4(0.48, 0.16, 0.16, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
    imgui.GetStyle().Colors[imgui.Col.CheckMark]              = ImVec4(0.98, 0.26, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]             = ImVec4(0.88, 0.26, 0.24, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]       = ImVec4(0.98, 0.26, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button]                 = ImVec4(0.98, 0.26, 0.26, 0.40)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = ImVec4(0.98, 0.26, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = ImVec4(0.98, 0.06, 0.06, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header]                 = ImVec4(0.98, 0.26, 0.26, 0.31)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = ImVec4(0.98, 0.26, 0.26, 0.80)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = ImVec4(0.98, 0.26, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Separator]              = ImVec4(0.43, 0.43, 0.50, 0.50)
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]       = ImVec4(0.75, 0.10, 0.10, 0.78)
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]        = ImVec4(0.75, 0.10, 0.10, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]             = ImVec4(0.98, 0.26, 0.26, 0.25)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]      = ImVec4(0.98, 0.26, 0.26, 0.67)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]       = ImVec4(0.98, 0.26, 0.26, 0.95)
    imgui.GetStyle().Colors[imgui.Col.Tab]                    = ImVec4(0.98, 0.26, 0.26, 0.40)
    imgui.GetStyle().Colors[imgui.Col.TabHovered]             = ImVec4(0.98, 0.26, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabActive]              = ImVec4(0.98, 0.06, 0.06, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocused]           = ImVec4(0.98, 0.26, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive]     = ImVec4(0.98, 0.26, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]         = ImVec4(0.98, 0.26, 0.26, 0.35)
end
        
function greentheme()
    local ImVec4 = imgui.ImVec4
    imgui.SwitchContext()
    imgui.GetStyle().Colors[imgui.Col.Text]                   = ImVec4(0.90, 0.90, 0.90, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]           = ImVec4(0.60, 0.60, 0.60, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = ImVec4(0.08, 0.08, 0.08, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ChildBg]                = ImVec4(0.10, 0.10, 0.10, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Border]                 = ImVec4(0.70, 0.70, 0.70, 0.40)
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]                = ImVec4(0.15, 0.15, 0.15, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = ImVec4(0.19, 0.19, 0.19, 0.71)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = ImVec4(0.34, 0.34, 0.34, 0.79)
    imgui.GetStyle().Colors[imgui.Col.TitleBg]                = ImVec4(0.00, 0.69, 0.33, 0.80)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]          = ImVec4(0.00, 0.74, 0.36, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]       = ImVec4(0.00, 0.69, 0.33, 0.50)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]              = ImVec4(0.00, 0.80, 0.38, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]            = ImVec4(0.16, 0.16, 0.16, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]          = ImVec4(0.00, 0.69, 0.33, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]   = ImVec4(0.00, 0.82, 0.39, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]    = ImVec4(0.00, 1.00, 0.48, 1.00)
    imgui.GetStyle().Colors[imgui.Col.CheckMark]              = ImVec4(0.00, 0.69, 0.33, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]             = ImVec4(0.00, 0.69, 0.33, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]       = ImVec4(0.00, 0.77, 0.37, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button]                 = ImVec4(0.00, 0.69, 0.33, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = ImVec4(0.00, 0.82, 0.39, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = ImVec4(0.00, 0.87, 0.42, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header]                 = ImVec4(0.00, 0.69, 0.33, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = ImVec4(0.00, 0.76, 0.37, 0.57)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = ImVec4(0.00, 0.88, 0.42, 0.89)
    imgui.GetStyle().Colors[imgui.Col.Separator]              = ImVec4(1.00, 1.00, 1.00, 0.40)
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]       = ImVec4(1.00, 1.00, 1.00, 0.60)
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]        = ImVec4(1.00, 1.00, 1.00, 0.80)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]             = ImVec4(0.00, 0.69, 0.33, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]      = ImVec4(0.00, 0.76, 0.37, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]       = ImVec4(0.00, 0.86, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines]              = ImVec4(0.00, 0.69, 0.33, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]       = ImVec4(0.00, 0.74, 0.36, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]          = ImVec4(0.00, 0.69, 0.33, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]   = ImVec4(0.00, 0.80, 0.38, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]         = ImVec4(0.00, 0.69, 0.33, 0.72)
end
function bluetheme()
    local ImVec4 = imgui.ImVec4
    imgui.SwitchContext()
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = ImVec4(0.08, 0.08, 0.08, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]                = ImVec4(0.16, 0.29, 0.48, 0.54)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = ImVec4(0.26, 0.59, 0.98, 0.40)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = ImVec4(0.26, 0.59, 0.98, 0.67)
    imgui.GetStyle().Colors[imgui.Col.TitleBg]                = ImVec4(0.04, 0.04, 0.04, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]          = ImVec4(0.16, 0.29, 0.48, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
    imgui.GetStyle().Colors[imgui.Col.CheckMark]              = ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]             = ImVec4(0.24, 0.52, 0.88, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]       = ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button]                 = ImVec4(0.26, 0.59, 0.98, 0.40)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = ImVec4(0.06, 0.53, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header]                 = ImVec4(0.26, 0.59, 0.98, 0.31)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = ImVec4(0.26, 0.59, 0.98, 0.80)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Separator]              = ImVec4(0.43, 0.43, 0.50, 0.50)
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]       = ImVec4(0.26, 0.59, 0.98, 0.78)
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]        = ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]             = ImVec4(0.26, 0.59, 0.98, 0.25)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]      = ImVec4(0.26, 0.59, 0.98, 0.67)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]       = ImVec4(0.26, 0.59, 0.98, 0.95)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]         = ImVec4(0.26, 0.59, 0.98, 0.35)
    imgui.GetStyle().Colors[imgui.Col.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = ImVec4(0.06, 0.53, 0.98, 0.70)
    imgui.GetStyle().Colors[imgui.Col.ChildBg]                = ImVec4(0.10, 0.10, 0.10, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg]                = ImVec4(0.06, 0.53, 0.98, 0.70)
    imgui.GetStyle().Colors[imgui.Col.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50)
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
end

function blacktheme()
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

function purpletheme()
    local ImVec4 = imgui.ImVec4
    imgui.GetStyle().FramePadding = imgui.ImVec2(3.5, 3.5)
    imgui.GetStyle().FrameRounding = 3
    imgui.GetStyle().ChildRounding = 2
    imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().WindowRounding = 2
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(5.0, 4.0)
    imgui.GetStyle().ScrollbarSize = 13.0
    imgui.GetStyle().ScrollbarRounding = 0
    imgui.GetStyle().GrabMinSize = 8.0
    imgui.GetStyle().GrabRounding = 1.0
    imgui.GetStyle().WindowPadding = imgui.ImVec2(4.0, 4.0)
    imgui.GetStyle().ButtonTextAlign = imgui.ImVec2(0.0, 0.5)

    imgui.GetStyle().Colors[imgui.Col.WindowBg] = imgui.ImVec4(0.14, 0.12, 0.16, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ChildBg] = imgui.ImVec4(0.30, 0.20, 0.39, 0.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg] = imgui.ImVec4(0.05, 0.05, 0.10, 0.90)
    imgui.GetStyle().Colors[imgui.Col.Border] = imgui.ImVec4(0.89, 0.85, 0.92, 0.30)
    imgui.GetStyle().Colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg] = imgui.ImVec4(0.30, 0.20, 0.39, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.41, 0.19, 0.63, 0.68)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.41, 0.19, 0.63, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBg] = imgui.ImVec4(0.41, 0.19, 0.63, 0.45)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.41, 0.19, 0.63, 0.35)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.41, 0.19, 0.63, 0.78)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.30, 0.20, 0.39, 0.57)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.30, 0.20, 0.39, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.41, 0.19, 0.63, 0.31)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.41, 0.19, 0.63, 0.78)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.41, 0.19, 0.63, 1.00)
    imgui.GetStyle().Colors[imgui.Col.CheckMark] = imgui.ImVec4(0.56, 0.61, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.41, 0.19, 0.63, 0.24)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.41, 0.19, 0.63, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button] = imgui.ImVec4(0.41, 0.19, 0.63, 0.44)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.41, 0.19, 0.63, 0.86)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.64, 0.33, 0.94, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header] = imgui.ImVec4(0.41, 0.19, 0.63, 0.76)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.41, 0.19, 0.63, 0.86)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.41, 0.19, 0.63, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip] = imgui.ImVec4(0.41, 0.19, 0.63, 0.20)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.41, 0.19, 0.63, 0.78)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.41, 0.19, 0.63, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines] = imgui.ImVec4(0.89, 0.85, 0.92, 0.63)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered] = imgui.ImVec4(0.41, 0.19, 0.63, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram] = imgui.ImVec4(0.89, 0.85, 0.92, 0.63)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered] = imgui.ImVec4(0.41, 0.19, 0.63, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(0.41, 0.19, 0.63, 0.43)
end

function purpletheme2()
    local ImVec4 = imgui.ImVec4
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    imgui.GetStyle().WindowPadding = imgui.ImVec2(4, 4)
    imgui.GetStyle().FramePadding = imgui.ImVec2(4, 3)
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(8, 4)
    imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(4, 4)
    imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(0, 0)

    imgui.GetStyle().IndentSpacing = 21
    imgui.GetStyle().ScrollbarSize = 14
    imgui.GetStyle().GrabMinSize = 10

    imgui.GetStyle().WindowBorderSize = 0
    imgui.GetStyle().ChildBorderSize = 1
    imgui.GetStyle().PopupBorderSize = 1
    imgui.GetStyle().FrameBorderSize = 1
    imgui.GetStyle().TabBorderSize = 0

    imgui.GetStyle().WindowRounding = 5
    imgui.GetStyle().ChildRounding = 5
    imgui.GetStyle().PopupRounding = 5
    imgui.GetStyle().FrameRounding = 5
    imgui.GetStyle().ScrollbarRounding = 2.5
    imgui.GetStyle().GrabRounding = 5
    imgui.GetStyle().TabRounding = 5

    imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.50, 0.50)

    -->> Colors
    colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[clr.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)

    colors[clr.WindowBg]               = ImVec4(0.15, 0.16, 0.37, 1.00)
    colors[clr.ChildBg]                = ImVec4(0.17, 0.18, 0.43, 1.00)
    colors[clr.PopupBg]                = colors[clr.WindowBg]

    colors[clr.Border]                 = ImVec4(0.33, 0.34, 0.62, 1.00)
    colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)

    colors[clr.TitleBg]                = ImVec4(0.18, 0.20, 0.46, 1.00)
    colors[clr.TitleBgActive]          = ImVec4(0.18, 0.20, 0.46, 1.00)
    colors[clr.TitleBgCollapsed]       = ImVec4(0.18, 0.20, 0.46, 1.00)
    colors[clr.MenuBarBg]              = colors[clr.ChildBg]

    colors[clr.ScrollbarBg]            = ImVec4(0.14, 0.14, 0.36, 1.00)
    colors[clr.ScrollbarGrab]          = ImVec4(0.22, 0.22, 0.53, 1.00)
    colors[clr.ScrollbarGrabHovered]   = ImVec4(0.20, 0.21, 0.53, 1.00)
    colors[clr.ScrollbarGrabActive]    = ImVec4(0.25, 0.25, 0.58, 1.00)

    colors[clr.Button]                 = ImVec4(0.25, 0.25, 0.58, 1.00)
    colors[clr.ButtonHovered]          = ImVec4(0.23, 0.23, 0.55, 1.00)
    colors[clr.ButtonActive]           = ImVec4(0.27, 0.27, 0.62, 1.00)

    colors[clr.CheckMark]              = ImVec4(0.39, 0.39, 0.83, 1.00)
    colors[clr.SliderGrab]             = ImVec4(0.39, 0.39, 0.83, 1.00)
    colors[clr.SliderGrabActive]       = ImVec4(0.48, 0.48, 0.96, 1.00)

    colors[clr.FrameBg]                = colors[clr.Button]
    colors[clr.FrameBgHovered]         = colors[clr.ButtonHovered]
    colors[clr.FrameBgActive]          = colors[clr.ButtonActive]

    colors[clr.Header]                 = colors[clr.Button]
    colors[clr.HeaderHovered]          = colors[clr.ButtonHovered]
    colors[clr.HeaderActive]           = colors[clr.ButtonActive]

    colors[clr.Separator]              = ImVec4(0.43, 0.43, 0.50, 0.50)
    colors[clr.SeparatorHovered]       = colors[clr.SliderGrabActive]
    colors[clr.SeparatorActive]        = colors[clr.SliderGrabActive]

    colors[clr.ResizeGrip]             = colors[clr.Button]
    colors[clr.ResizeGripHovered]      = colors[clr.ButtonHovered]
    colors[clr.ResizeGripActive]       = colors[clr.ButtonActive]

    colors[clr.Tab]                    = colors[clr.Button]
    colors[clr.TabHovered]             = colors[clr.ButtonHovered]
    colors[clr.TabActive]              = colors[clr.ButtonActive]
    colors[clr.TabUnfocused]           = colors[clr.Button]
    colors[clr.TabUnfocusedActive]     = colors[clr.Button]

    colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
    colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
    colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
    colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)

    colors[clr.TextSelectedBg]         = ImVec4(0.33, 0.33, 0.57, 1.00)
    colors[clr.DragDropTarget]         = ImVec4(1.00, 1.00, 0.00, 0.90)

    colors[clr.NavHighlight]           = ImVec4(0.26, 0.59, 0.98, 1.00)
    colors[clr.NavWindowingHighlight]  = ImVec4(1.00, 1.00, 1.00, 0.70)
    colors[clr.NavWindowingDimBg]      = ImVec4(0.80, 0.80, 0.80, 0.20)

    colors[clr.ModalWindowDimBg]       = ImVec4(0.00, 0.00, 0.00, 0.90)
end

function redtheme2()
    local ImVec4 = imgui.ImVec4
    imgui.GetStyle().WindowPadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().FramePadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(2, 2)
    imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(0, 0)
    imgui.GetStyle().IndentSpacing = 0
    imgui.GetStyle().ScrollbarSize = 10
    imgui.GetStyle().GrabMinSize = 10
    imgui.GetStyle().WindowBorderSize = 1
    imgui.GetStyle().ChildBorderSize = 1

    imgui.GetStyle().PopupBorderSize = 1
    imgui.GetStyle().FrameBorderSize = 1
    imgui.GetStyle().TabBorderSize = 1
    imgui.GetStyle().WindowRounding = 8
    imgui.GetStyle().ChildRounding = 8
    imgui.GetStyle().FrameRounding = 8
    imgui.GetStyle().PopupRounding = 8
    imgui.GetStyle().ScrollbarRounding = 8
    imgui.GetStyle().GrabRounding = 8
    imgui.GetStyle().TabRounding = 8

    imgui.GetStyle().Colors[imgui.Col.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]           = ImVec4(1.00, 1.00, 1.00, 0.43);
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = ImVec4(0.00, 0.00, 0.00, 0.90);
    imgui.GetStyle().Colors[imgui.Col.ChildBg]                = ImVec4(1.00, 1.00, 1.00, 0.07);
    imgui.GetStyle().Colors[imgui.Col.PopupBg]                = ImVec4(0.00, 0.00, 0.00, 0.94);
    imgui.GetStyle().Colors[imgui.Col.Border]                 = ImVec4(1.00, 1.00, 1.00, 0.00);
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]           = ImVec4(1.00, 0.00, 0.00, 0.32);
    imgui.GetStyle().Colors[imgui.Col.FrameBg]                = ImVec4(1.00, 1.00, 1.00, 0.09);
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = ImVec4(1.00, 1.00, 1.00, 0.17);
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = ImVec4(1.00, 1.00, 1.00, 0.26);
    imgui.GetStyle().Colors[imgui.Col.TitleBg]                = ImVec4(0.19, 0.00, 0.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]          = ImVec4(0.46, 0.00, 0.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]       = ImVec4(0.20, 0.00, 0.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]              = ImVec4(0.14, 0.03, 0.03, 1.00);
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]            = ImVec4(0.19, 0.00, 0.00, 0.53);
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]          = ImVec4(1.00, 1.00, 1.00, 0.11);
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]   = ImVec4(1.00, 1.00, 1.00, 0.24);
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]    = ImVec4(1.00, 1.00, 1.00, 0.35);
    imgui.GetStyle().Colors[imgui.Col.CheckMark]              = ImVec4(1.00, 1.00, 1.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]             = ImVec4(1.00, 0.00, 0.00, 0.34);
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]       = ImVec4(1.00, 0.00, 0.00, 0.51);
    imgui.GetStyle().Colors[imgui.Col.Button]                 = ImVec4(1.00, 0.00, 0.00, 0.19);
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = ImVec4(1.00, 0.00, 0.00, 0.31);
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = ImVec4(1.00, 0.00, 0.00, 0.46);
    imgui.GetStyle().Colors[imgui.Col.Header]                 = ImVec4(1.00, 0.00, 0.00, 0.19);
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = ImVec4(1.00, 0.00, 0.00, 0.30);
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = ImVec4(1.00, 0.00, 0.00, 0.50);
    imgui.GetStyle().Colors[imgui.Col.Separator]              = ImVec4(1.00, 0.00, 0.00, 0.41);
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]       = ImVec4(1.00, 1.00, 1.00, 0.78);
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]        = ImVec4(1.00, 1.00, 1.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]             = ImVec4(0.19, 0.00, 0.00, 0.53);
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]      = ImVec4(0.43, 0.00, 0.00, 0.75);
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]       = ImVec4(0.53, 0.00, 0.00, 0.95);
    imgui.GetStyle().Colors[imgui.Col.Tab]                    = ImVec4(1.00, 0.00, 0.00, 0.27);
    imgui.GetStyle().Colors[imgui.Col.TabHovered]             = ImVec4(1.00, 0.00, 0.00, 0.48);
    imgui.GetStyle().Colors[imgui.Col.TabActive]              = ImVec4(1.00, 0.00, 0.00, 0.60);
    imgui.GetStyle().Colors[imgui.Col.TabUnfocused]           = ImVec4(1.00, 0.00, 0.00, 0.27);
    imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive]     = ImVec4(1.00, 0.00, 0.00, 0.54);
    imgui.GetStyle().Colors[imgui.Col.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00);
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00);
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]         = ImVec4(1.00, 1.00, 1.00, 0.35);
    imgui.GetStyle().Colors[imgui.Col.DragDropTarget]         = ImVec4(1.00, 1.00, 0.00, 0.90);
    imgui.GetStyle().Colors[imgui.Col.NavHighlight]           = ImVec4(0.26, 0.59, 0.98, 1.00);
    imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight]  = ImVec4(1.00, 1.00, 1.00, 0.70);
    imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg]      = ImVec4(0.80, 0.80, 0.80, 0.20);
    imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg]       = ImVec4(0.80, 0.80, 0.80, 0.35);
end

function decor()
    imgui.SwitchContext()
    local ImVec4 = imgui.ImVec4
    imgui.GetStyle().WindowPadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().FramePadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(2, 2)
    imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(0, 0)
    imgui.GetStyle().IndentSpacing = 0
    imgui.GetStyle().ScrollbarSize = 10
    imgui.GetStyle().GrabMinSize = 10
    imgui.GetStyle().WindowBorderSize = 1
    imgui.GetStyle().ChildBorderSize = 1
    imgui.GetStyle().PopupBorderSize = 1
    imgui.GetStyle().FrameBorderSize = 1
    imgui.GetStyle().TabBorderSize = 1
    imgui.GetStyle().WindowRounding = 8
    imgui.GetStyle().ChildRounding = 8
    imgui.GetStyle().FrameRounding = 8
    imgui.GetStyle().PopupRounding = 8
    imgui.GetStyle().ScrollbarRounding = 8
    imgui.GetStyle().GrabRounding = 8
    imgui.GetStyle().TabRounding = 8
end

function moonmonet()
	local au = script_authorr
	if au ~= "lua_helpers" then
		WinState[0] = false
		WinNotif[0] = false
		sampSendChat("Автор скрипта изменен! Отписыватесь от канала, откуда качали!")
		sampSendChat("/s Оригинальный автор @lua_helpers")
	end
end

function script_reload()
	lua_thread.create(function()
		sampAddChatMessage(""..tagg.."Скрипт будет перезагружен через 2 секунды!", -1)
		wait(2000)
		sampAddChatMessage(""..tagg.."Перезагрузка...", -1)
		thisScript():reload()
	end)
end

function script_unload()
	lua_thread.create(function()
		sampAddChatMessage(""..tagg.."Скрипт будет выгружен через 2 секунды!", -1)
		wait(2000)
		sampAddChatMessage("Выгрузка...", -1)
		thisScript():unload()
	end)
end

function main()
    sampRegisterChatCommand(ini.cfg.activation, ws_toggle)
	while true do
		cameraSetLerpFov(ini.cfg.fov_int, 101.0, 1000, true)
		local car = storeCarCharIsInNoSave(PLAYER_PED)
		if isCharInCar(PLAYER_PED,car) then
			if ini.cfg.toggled_cs == true then
				local speed = getCarSpeed(car)
				if speed > 25.0 then
					shakeCam(math.ceil(speed) / 2)
				end
			else
			end
		end
		wait(1)
	end
end

function ws_toggle()
	if toggled then
		WinState[0] = not WinState[0]
		moonmonet()
	else
		sampAddChatMessage(""..tagg.."Скрипт выключен", -1)
	end
end

function onScriptTerminate(script, game_quit) 
	if script == thisScript() and not game_quit then thisScript():reload() end 
end

function check_version()
	url_result.versionn = request.get(""..url.version.."").text
	if version ~= url_result.versionn then
		sampShowDialog(776600, "Обновление", ""..tagg.."Обнаружено обновление, для скачивания перейдите в ТГК: "..script_authorr.."\nВаша версия: "..version.."\nАктуальная версия: "..url_result.versionn.."", "Отмена", "Отмена", 0)
	end
end

function sampev.onSendSpawn()
  check_version()
end

function sampev.onServerMessage(color, text)
	if ini.cfg.toggled_sm then return false end
end

function join_argb(a, r, g, b)
    local argb = b  -- b
    argb = bit.bor(argb, bit.lshift(g, 8))  -- g
    argb = bit.bor(argb, bit.lshift(r, 16)) -- r     
    argb = bit.bor(argb, bit.lshift(a, 24)) -- a
    return argb
end
function explode_argb(argb)
    local a = bit.band(bit.rshift(argb, 24), 0xFF)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return a, r, g, b
end
function ARGBtoRGB(color)
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

function apply_monet()
	imgui.SwitchContext()
	local style = imgui.GetStyle()
	local colors = style.Colors
	local clr = imgui.Col
	local ImVec4 = imgui.ImVec4
	local generated_color = monet.buildColors(ini.theme.moonmonet, 1.0, true)
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


ffi.cdef[[
    void _Z12AND_OpenLinkPKc(const char* link);
]]

function openLink(link)
    gta._Z12AND_OpenLinkPKc(link)
end