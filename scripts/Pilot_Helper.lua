local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local new = imgui.new
require 'lib.moonloader'
local ffi = require 'ffi'
local sampev = require 'lib.samp.events'
local ffi = require('ffi')
local gta = ffi.load('GTASA')
local faicons = require('fAwesome6')

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowWidth()/2-imgui.CalcTextSize(u8(text)).x/2)
    imgui.Text(u8(text))
end

local reisik = 0
local larpilor = 0
local award = 0
local tidexx = 0
local moneyreis = 0


local PilotM = new.bool(false)
local PilotStata = new.bool(false)

local inicfg = require 'inicfg'
local ini = inicfg.load({
    stats =
    {
    	time = 0,
        aUCustP = false,
        sekonds = false,
    	moneyzarobotok = false,
        obshzarobotok = false,
        reis = false,
        larespilot = false,
        larespremii = false,
        laresTidex = false,
        Settings = false,
        Settingslarci = false,
        -----------------------------------
        moneyreis = 0,
        reisik = 0,
        larpilor = 0,
        award = 0,
        tidexx = 0,
        ------------------цены ларцы
        cenaTidex = 0,
        cenapilot = 0,
        cenaPremia = 0,
        moneyoh = 0,
    }}, "Pilot Tools.ini")

time = new.int(ini.stats.time)
local timeStatus = false

local infobarik = imgui.new.bool(false)
local Settings = imgui.new.bool(ini.stats.Settings)
local Settingslarci = imgui.new.bool(ini.stats.Settingslarci)
local moneyzarobotok = imgui.new.bool(ini.stats.moneyzarobotok)	
local aUCustP = imgui.new.bool(ini.stats.aUCustP)	
local sekonds = imgui.new.bool(ini.stats.sekonds)	
local obshzarobotok = imgui.new.bool(ini.stats.obshzarobotok)	
local reis = imgui.new.bool(ini.stats.reis)	
local larespilot = imgui.new.bool(ini.stats.larespilot)	
local larespremii = imgui.new.bool(ini.stats.larespremii)	
local laresTidex = imgui.new.bool(ini.stats.laresTidex)	

function deleteAll()
 ini.stats.reisik=0
 ini.stats.award=0
 ini.stats.larpilor = 0
 ini.stats.tidexx=0
 ini.stats.moneyreis =0
 cfg_save()
 sampAddChatMessage('{006600}[Pilot Tools]: {FFFFFF}Статистика сброшена', -1)
end

local cenapilot = imgui.new.int(ini.stats.cenapilot)
local cenaTidex = imgui.new.int(ini.stats.cenaPremia)
local cenaPremia = imgui.new.int(ini.stats.cenaTidex)




-- Weather & Time by MonetLoader
local WeatherAndTime = {
  weather = new.int(0),
  time = new.int(0),
  locked_time = 0,
  new_time = false,
  thread = nil
}


imgui.OnFrame(function() return PilotM[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500,500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(faicons('PLANE_ARRIVAL')..u8' Pilot Tools - Arizona Mobile', PilotM, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar)
if imgui.Button(faicons('XMARK'), imgui.ImVec2(35, 35)) then PilotM[0] = false end
imgui.CenterText('Autor: t.me/TelReMODS')
    if imgui.Checkbox(u8'Статистика',infobarik) then
                    PilotStata[0]= not PilotStata[0]              
                end
                                		if imgui.Checkbox(u8' Настройки', Settings) then ini.stats.Settings = Settings[0] end
                                                                		if imgui.Checkbox(u8' Ларцы', Settingslarci) then ini.stats.Settingslarci = Settingslarci[0] end
                		if imgui.Checkbox(u8'Авто-выбор частного самолёта', aUCustP) then ini.stats.aUCustP = aUCustP[0] end
                imgui.Separator()
                if imgui.Button(faicons('POWER_OFF')..u8'##Установить погоду') then
          forceWeatherNow(WeatherAndTime.weather[0])
        end
        imgui.SameLine()
        imgui.SetNextItemWidth(imgui.GetFontSize() * 5)
        if imgui.InputInt(u8'Погода', WeatherAndTime.weather, 1, 10) then
          if WeatherAndTime.weather[0] < 0 then
            WeatherAndTime.weather[0] = 0
          end
          if WeatherAndTime.weather[0] > 45 then
            WeatherAndTime.weather[0] = 45
          end
        end

        if imgui.Button(faicons('POWER_OFF')..u8'##Установить время') then
          if WeatherAndTime.thread ~= nil then
            WeatherAndTime.thread:terminate()
          end

          WeatherAndTime.locked_time = WeatherAndTime.time[0]
          WeatherAndTime.thread = lua_thread.create(function()
            WeatherAndTime.new_time = false
            while not WeatherAndTime.new_time do
              setTimeOfDay(WeatherAndTime.locked_time, 0)
              wait(0)
            end
            WeatherAndTime.new_time = false
          end)
        end
        imgui.SameLine()
        imgui.SetNextItemWidth(imgui.GetFontSize() * 5)
        if imgui.InputInt(u8'Время', WeatherAndTime.time, 1, 5) then
          if WeatherAndTime.time[0] < 0 then
            WeatherAndTime.time[0] = 0
          end
          if WeatherAndTime.time[0] > 23 then
            WeatherAndTime.time[0] = 23
          end
        end

                imgui.Separator()
               
        if imgui.Button(u8' Секундомер вкл/выкл', imgui.ImVec2(200, 30)) then
            tstate()
            sampAddChatMessage('{006600}[Pilot Tools]: {FFFFFF}Вы воспользовались секундомером', -1)
        end   
        imgui.SameLine() 
        if imgui.Button(u8' Очистить секундомер', imgui.ImVec2(200, 30)) then
resetCounter()
sampAddChatMessage('{006600}[Pilot Tools]: {FFFFFF}Вы очистили секундомер', -1)
end
        if imgui.Button(u8' Очистить статистику', imgui.ImVec2(400, 30)) then
deleteAll()
end
imgui.Separator()
if ini.stats.Settingslarci then 
imgui.CenterText('Цены на ларцы')
if imgui.InputInt(u8"Пилот", cenapilot, 0, 0) then 
ini.stats.cenapilot = cenapilot[0]
cfg_save() 
                end    
if imgui.InputInt(u8"Tidex", cenaTidex, 0, 0) then 
ini.stats.cenaTidex = cenaTidex[0]
cfg_save() 
                end    
if imgui.InputInt(u8"Премии", cenaPremia, 0, 0) then 
ini.stats.cenaPremia = cenaPremia[0]
cfg_save() 
                end    
imgui.Separator()
end

if ini.stats.Settings then 

        if imgui.Checkbox(u8' Отображение секундомера',sekonds) then
        ini.stats.sekonds = sekonds[0]
                    cfg_save() 
                end    
        if imgui.Checkbox(u8' Отображение денежного зароботка',moneyzarobotok) then
        ini.stats.moneyzarobotok = moneyzarobotok[0]
                    cfg_save() 
                end 
                
                        if imgui.Checkbox(u8' Отображение общего зароботка',obshzarobotok) then
        ini.stats.obshzarobotok = obshzarobotok[0]
                    cfg_save() 
                end 
                
                                        if imgui.Checkbox(u8' Отображение кол-во рейсов',reis) then
        ini.stats.reis = reis[0]
                    cfg_save() 
                end 
                                                        if imgui.Checkbox(u8' Отображение ларцов пилота',larespilot) then
        ini.stats.larespilot = larespilot[0]
                    cfg_save() 
                end 
                
                                                        if imgui.Checkbox(u8' Отображение ларцов премии',larespremii) then
        ini.stats.larespremii = larespremii[0]
                    cfg_save() 
                end 
                
                                                                        if imgui.Checkbox(u8' Отображение ларцов Tidex',laresTidex) then
        ini.stats.laresTidex = laresTidex[0]
                    cfg_save() 
                end 
        end        
    imgui.End()
end)

function cfg_save()
    inicfg.save(ini, "Pilot Tools.ini")
end

imgui.OnFrame(function() return PilotStata[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500,500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin('##Window', PilotStata, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize) 
if ini.stats.sekonds then
imgui.CenterText(get_clock(time[0]))
end
 if ini.stats.moneyzarobotok then
   imgui.Text(faicons('DOLLAR_SIGN')..u8'Денежный зароботок: $' ..separator(ini.stats.moneyreis))
   end
   if ini.stats.obshzarobotok then 
    imgui.Text(faicons('DOLLAR_SIGN')..u8'Общий зароботок: $' ..separator(ini.stats.moneyreis))
    end 
    if ini.stats.reis then 
    imgui.Text(faicons('PLANE_ARRIVAL')..u8'Кол-во рейсов: ' ..ini.stats.reisik)
    end
    if ini.stats.larespilot then 
    imgui.Text(faicons('PLANE_TAIL')..u8'Выпало лароцов пилота: ' ..ini.stats.larpilor)
    end 
    if ini.stats.larespremii then 
    imgui.Text(faicons('BOX_DOLLAR')..u8'Выпало лароцов премии: ' ..ini.stats.award)
    end
    if ini.stats.laresTidex then 
    imgui.Text(faicons('BOX')..u8'Выпало лароцов Tidex: ' ..ini.stats.tidexx)
    end 
    imgui.End()
end)

function main()
while not isSampAvailable() do wait(0) end
    lua_thread.create(counter)
    sampRegisterChatCommand('pilot', function() PilotM[0] = not PilotM[0] end)
    sampRegisterChatCommand('timer', function()
    tstate()
    sampAddChatMessage('{006600}[Pilot Tools]: {FFFFFF}Вы воспользовались секундомером', -1)
    end )
    wait(-1)
end

function sampev.onServerMessage(color, text)
		if text:find('%[Подсказка] {ffffff}Рейс успешно завершен! Заработано за рейс: ') then
			local money = text:match('Заработано за рейс: $(%d+)')
			ini.stats.moneyreis = ini.stats.moneyreis + money
ini.stats.reisik = ini.stats.reisik + 1
  end
		if text:find('Благодаря улучшениям вашей семьи вы получаете дополнительную зарплату: $(%d+)') then
			local bablo = text:match('дополнительную зарплату: $(%d+)')
			ini.stats.moneyreis = ini.stats.moneyreis + bablo

 end
		if text:find('За работу в рабочее время вашей организации вы получаете прибавку к зарплате: $(%d+)') then
			local orgzp = text:match('прибавку к зарплате: $(%d+)')
			ini.stats.moneyreis = ini.stats.moneyreis + orgzp end
		if text:find("Вам был добавлен предмет 'Ларец с премией'") then
        ini.stats.award = ini.stats.award + 1

    end
    if text:find("Вам был добавлен предмет 'Ларец пилота'") then
     ini.stats.larpilor = ini.stats.larpilor + 1 
end
if text:find("Вам был добавлен предмет 'Ларец Tidex'") then
ini.stats.tidexx = ini.stats.tidexx + 1
 end
end


function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
	if title:find('Выберите самолет') and dialogId == 1421 and aUCustP[0] then
		lua_thread.create(function()
			wait(0)
			local tLines = split(text, '\n')
			sampSendDialogResponse(dialogId, 1, #tLines-2 , nil)
			wait(1)
			
		end)
	end
end 	

function split(str, delim, plain)
	local tokens, pos, plain = {}, 1, not (plain == false)
	repeat
		local npos, epos = string.find(str, delim, pos, plain)
		table.insert(tokens, string.sub(str, pos, npos and npos - 1))
		pos = epos and epos + 1
	until not pos
	return tokens
end

imgui.OnInitialize(function()
    theme()
    
    imgui.GetIO().IniFilename = nil
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solmyID'), 14, config, iconRanges)

end)

function sampev.onSendSpawn()

sampAddChatMessage('{006600}[Pilot Tools]: {FFFFFF}Скрипт запущен | Открыть меню: /pilot | Автор: t.me/TelefonRedmi12c ', -1)

end

function counter()
    while true do
        wait(1000)
		if timeStatus then
            time[0] = time[0] + 1
            ini.stats.time = time[0]
            cfg_save()
        end
    end
end     

function tstate()
    timeStatus = not timeStatus
end

function resetCounter()
	ini.stats.time = 0
	timeStatus = false
    cfg_save()
    time[0] = ini.stats.time
end

function separator(n)
  local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
  return left..(num:reverse():gsub('(%d%d%d)','%1.'):reverse())..right
end

function get_clock(time)
    local timezone_offset = 86400 - os.date('%H', 0) * 3600
    if tonumber(time) >= 86400 then onDay = true else onDay = false end
    return os.date((onDay and math.floor(time / 86400)..'д ' or '')..'%H:%M:%S', time + timezone_offset)
end

function theme()
    imgui.SwitchContext()
    --==[ STYLE ]==--
    imgui.GetStyle().WindowPadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().FramePadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(2, 2)
    imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(0, 0)
    imgui.GetStyle().IndentSpacing = 0
    imgui.GetStyle().ScrollbarSize = 0
    imgui.GetStyle().GrabMinSize = 10

    --==[ BORDER ]==--
    imgui.GetStyle().WindowBorderSize = 1
    imgui.GetStyle().ChildBorderSize = 1
    imgui.GetStyle().PopupBorderSize = 1
    imgui.GetStyle().FrameBorderSize = 1
    imgui.GetStyle().TabBorderSize = 1

    --==[ ROUNDING ]==--
    imgui.GetStyle().WindowRounding = 10
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