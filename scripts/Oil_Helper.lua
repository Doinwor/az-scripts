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
local inicfg = require 'inicfg'
 local ini = inicfg.load({
    cfg ={
        boolGiveaz = 1,
  boolGivemoney =124000,
    Settings = false,
    moneycfg = false,
    azcfg = false,
    viborts = false,
    aytoH = false,
    autoalt = false,
    zarmon = 0,
    azzar = 0,
    skipi = false,
    boshkiini = 0,
    boshkamenu = false,
    },
    knopa = {
        pochinka = false,   
        fillcar = false,   
        dveri = false,   
        key = false,   
        armours = false,   
        maska = false, 
        sportil = false,
    }
}, "OilHelper.ini")

local zarmonsesia = 0
local azzarsesia = 0
local boxhkosesia = 0

local pochinka = imgui.new.bool(ini.knopa.pochinka)	
local fillcar = imgui.new.bool(ini.knopa.fillcar)
local dveri = imgui.new.bool(ini.knopa.dveri)	
local key = imgui.new.bool(ini.knopa.key)
local armours = imgui.new.bool(ini.knopa.armours)
local maska = imgui.new.bool(ini.knopa.maska)
local sportil = imgui.new.bool(ini.knopa.sportil)



function deleteAll()
 azzarsesia=0
 zarmonsesia=0
 ini.cfg.azzar = 0
 ini.cfg.zarmon=0
 ini.cfg.boshkiini=0
 boxhkosesia=0
 cfg_save()
 sampAddChatMessage('{006600}[Oil Tools]: {FFFFFF}Статистика сброшена', -1)
end

local renderWindow = imgui.new.bool(false)
local Dipiokno = imgui.new.bool(false)
local OilStats = imgui.new.bool(false)
local dopokno = imgui.new.bool(false)
local Settings = imgui.new.bool(ini.cfg.Settings)
local moneycfg = imgui.new.bool(ini.cfg.moneycfg)
local azcfg = imgui.new.bool(ini.cfg.azcfg)
local aytoH = imgui.new.bool(ini.cfg.aytoH)
local skipi = imgui.new.bool(ini.cfg.skipi)
local autoalt = imgui.new.bool(ini.cfg.autoalt)
local viborts = imgui.new.bool(ini.cfg.viborts)
local boshkamenu = imgui.new.bool(ini.cfg.boshkamenu)


function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowWidth()/2-imgui.CalcTextSize(u8(text)).x/2)
    imgui.Text(u8(text))
end

local boolGiveaz = imgui.new.int(ini.cfg.boolGiveaz)
local boolGivemoney = imgui.new.int(ini.cfg.boolGivemoney)
local infobarik = imgui.new.bool(false)

imgui.OnFrame(function() return renderWindow[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500,500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
       imgui.Begin('##Main Window', renderWindow, imgui.WindowFlags.NoTitleBar) 
       		    if imgui.BeginTabBar('Menu') then
			    if imgui.BeginTabItem(u8' Основное') then
		          if imgui.Checkbox(u8' Статистика',infobarik) then
                    OilStats[0]= not OilStats[0]              
                end		
		    	if imgui.Checkbox(u8' Настройки', Settings) then ini.cfg.Settings = Settings[0] end
		imgui.Separator()
	                if ini.cfg.Settings then
imgui.CenterText('Настройки:') 
imgui.Text('Infobar')

      if imgui.Checkbox(u8' Заработанные вирты', moneycfg) then ini.cfg.moneycfg = moneycfg[0] cfg_save()  end
            if imgui.Checkbox(u8' Заработанные AZ-Coins', azcfg) then ini.cfg.azcfg = azcfg[0]  cfg_save() end 
                        if imgui.Checkbox(u8'Кол-во проданных бочек', boshkamenu) then ini.cfg.boshkamenu = boshkamenu[0]  cfg_save() end
            
   imgui.Text(u8'Другое')         
                if imgui.Checkbox(u8'Скрыть диалог покупки', skipi) then
                    ini.cfg.skipi = skipi[0]
                    cfg_save() 
                end
                if imgui.Checkbox(u8'АвтоВыбор занятого слота', viborts) then
                    ini.cfg.viborts = viborts[0]
                    cfg_save() 
                end 
                 
               end 
		    	    imgui.EndTabItem()
	    	    end
	if imgui.BeginTabItem(u8' Статистика') then
		    		imgui.CenterText('Заработано AZ-coins за всё время: '..ini.cfg.azzar.. 'шт.')
				    		imgui.CenterText('Заработано AZ-coins за сессию: '..azzarsesia.. 'шт.')
		imgui.CenterText('Заработано вирт за сессию: ' ..zarmonsesia.. '$.')
		imgui.CenterText('Заработано вирт за всё время: ' ..ini.cfg.zarmon.. '$.')
	imgui.CenterText('Продано бочек за сессию: '..boxhkosesia.. 'шт.')
	imgui.CenterText('Продано бочек за всё время: '..ini.cfg.boshkiini.. 'шт.')
	
		        if imgui.Button(u8' Очистить статистику', imgui.ImVec2(-1, 30)) then
deleteAll()
end
                imgui.CenterText('Кол-во  АЗ за 1 бочку:')
             
                if imgui.InputInt('##test',boolGiveaz,1,15) then
                ini.cfg.boolGiveaz = boolGiveaz[0]
                cfg_save() 
                end 	imgui.Separator()
                imgui.CenterText('Кол-во  $ за 1 бочку:')
             
                if imgui.InputInt('##test',boolGivemoney,0,0) then
                ini.cfg.boolGivemoney = boolGivemoney[0]
                cfg_save() 
                end 
                imgui.Separator()		    		
		    	    imgui.EndTabItem()
	    	    end
				    if imgui.BeginTabItem(u8' Дополнительно') then
						          if imgui.Checkbox(u8' Дополнительное окно',dopokn) then
                    Dipiokno[0]= not Dipiokno[0]              
                end	
                                if imgui.Checkbox(u8'Отображение кнопки [ Починка ] ',pochinka) then
                    ini.knopa.pochinka = pochinka[0]
                    cfg_save() 
                end 
                
                if imgui.Checkbox(u8'Отображение кнопки [ Заправка ] ',fillcar) then
                    ini.knopa.fillcar = fillcar[0]
                    cfg_save() 
                end 
                
                if imgui.Checkbox(u8'Отображение кнопки [ Ключи ] ',key) then
                    ini.knopa.key = key[0]
                    cfg_save() 
                end 

                if imgui.Checkbox(u8'Отображение кнопки [ Двери ] ',dveri) then
                    ini.knopa.dveri = dveri[0]
                    cfg_save() 
                end 
                                if imgui.Checkbox(u8'Отображение кнопки [ Бронижилет ] ',armours) then
                    ini.knopa.armours = armours[0]
                    cfg_save() 
                end 
                
                                if imgui.Checkbox(u8'Отображение кнопки [ Маска ] ',maska) then
                    ini.knopa.maska = maska[0]
                    cfg_save() 
                end 
                                                if imgui.Checkbox(u8'Отображение кнопки [ Спорт ] ',sportil) then
                    ini.knopa.sportil = sportil[0]
                    cfg_save() 
                end 
                
				imgui.EndTabItem()
				end
				if imgui.BeginTabItem(u8' Информация') then
				imgui.CenterText('Команды:')
				imgui.Text(u8'1) /oilh Главное меню')
				imgui.Text(u8'2) /oil Меню нефтивишек')
				imgui.EndTabItem()
				 end 
								    if imgui.BeginTabItem(u8' Ларцы') then
				imgui.EndTabItem()
				 end 
	    	    imgui.EndTabBar()
	    	end
        imgui.End()
   end)
  
  imgui.OnFrame(function() return OilStats[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500,500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
      
       imgui.Begin('##Main OilStats', OilStats, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar) 
      if ini.cfg.moneycfg then 
      imgui.CenterText('Заработано вирт: ' ..ini.cfg.zarmon.. '$.')
      end 
      if ini.cfg.azcfg then 
      imgui.CenterText('Заработано AZ-coins:  '..ini.cfg.azzar.. 'шт.')
      if ini.cfg.boshkamenu then 
      imgui.CenterText('Продано бочек: '..ini.cfg.boshkiini.. 'шт.')
      end 
      end
      imgui.End()
      end)
      
      imgui.OnFrame(function() return Dipiokno[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500,500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
      
       imgui.Begin('##1Main OilStats', Dipiokno, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar) 
        if ini.knopa.pochinka then
            if imgui.Button(u8'Починка', imgui.ImVec2(120, 30)) then
                sampSendChat('/repcar')
            end
        end 
        imgui.SameLine()
        if ini.knopa.fillcar then
            if imgui.Button(u8'Заправка', imgui.ImVec2(120, 30)) then 
                sampSendChat('/fillcar')
            end
        end
        imgui.SameLine() 
        if ini.knopa.key then
            if imgui.Button(u8'Ключи', imgui.ImVec2(120, 30)) then 
                sampSendChat('/key')
            end
        end 
        imgui.SameLine()
        if ini.knopa.dveri then
            if imgui.Button(u8'Двери', imgui.ImVec2(120, 30)) then 
                sampSendChat('/lock')
            end
        end

        imgui.SameLine()
        if ini.knopa.maska then
            if imgui.Button(u8'Маска', imgui.ImVec2(120, 30)) then 
                sampSendChat('/mask')
            end
        end
        imgui.SameLine()
        if ini.knopa.armours then
            if imgui.Button(u8'Бронижилет', imgui.ImVec2(120, 30)) then 
                sampSendChat('/armour')
            end
        end
                imgui.SameLine()
        if ini.knopa.sportil then
            if imgui.Button(u8'Спорт', imgui.ImVec2(120, 30)) then 
                sampSendChat('/style')
            end
        end

      imgui.End()
      end)
      
      function cfg_save()
    inicfg.save(ini, "OilHelper.ini")
end

      function sampev.onServerMessage(color, text)
if text:match('Вы успешно продали бочку') then
        ini.cfg.zarmon = ini.cfg.zarmon+boolGivemoney[0]
        zarmonsesia = zarmonsesia+boolGivemoney[0]
        azzarsesia = azzarsesia + 1
        ini.cfg.azzar = ini.cfg.azzar + 1      
                boxhkosesia = boxhkosesia + 1
        ini.cfg.boshkiini = ini.cfg.boshkiini + 1
        cfg_save()
        end
end 
      
      function sampev.onShowDialog(id, style, title, button1, button2, text)
      if skipi[0] == true and title:find("Покупка бочки") then
        sampSendDialogResponse(id, 1, nil, nil)
        return false
    end
      if viborts[0] and title:find('Бочки в транспорте') then
        for line in text:gmatch('([^\n\r]+)') do
            line = line:gsub('{......}', ' ')
            local num, status = line:match('%№(%d+) (.+)')           
            if status:find('Забрать') and viborts[0] and not objectcheck then
                sampSendDialogResponse(id,1,num-1,'')
                return false
            end
       end 
end 
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

   function main()
while not isSampAvailable() do wait(0) end
    
    sampRegisterChatCommand('oilh', function() renderWindow[0] = not renderWindow[0] end)
    
sampRegisterChatCommand('oil',function()
sampSendChat('/oilgroundlist')
        
    end)
    wait(-1)
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