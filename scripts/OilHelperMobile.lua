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
    zarmon = 0,
    azzar = 0,
    skipi = false,
    boshkiini = 0,
    cho = 1,
    boshkamenu = false,
    }   
}, "OilHelper.ini")

local allCases ={
    [569] = "Сундук рулетки", [1637] = "Rare Box Yellow", [1638] = "Rare Box Red", [1639] = "Rare Box Blue", [1766] = "Ящик Marvel", [1767] = "Ящик Джентельменов",
    [1768] = "Ящик Minecraft", [1769] = "Супер мото-ящик", [1770] = "Супер авто-ящик", [1852] = "Super Car Box", [1853] = "Ларец с премией", [1939] = "Ностальгический ящик",
    [2002] = "Одежда из секонд-хенда", [2149] = "Ларец Олигарха", [2187] = "Ларец кастомных аксессуаров", [3559] = "Ларец организации", [3565] = "Ларец крафтера",
    [3623] = "Ларец дальнобойщика", [3920] = "Concept Car Luxury", [3991] = "Ларец Mortal Combat", [3992] = "Ларец Водителя Автобуса", [4242] = "Ларец рыболова",
    [4584] = "Рандомный Ларец", [4792] = "Ларец пилота", [4793] = "Ларец развозчика продуктов", [4794] = "Ларец кладоискателя", [5323] = "Ларец Vice City",
    [5479] = "Ларец Tidex", [6199] = "Ларец семейных охранников", [6234] = "Ларец петуха", [7350] = "Ларец инкассатора", [7418] = "Ящик рыболова",
    [7480] = "Ларец Fortnite", [7759] = "Ларец Arizona", [8095] = "Голубой Ларец Миража", [8096] = "Золотой Ларец Миража", [8552] = "Ларец мусорщика", [8949] = "Рулетка тьмы",
    [8965] = "Рулетка гетто", [9538] = "Кейс Глента", [9764] = "Кейс Нового Сезона",
}

local newLarec = {
    larecCost = new.int()
}

local zarmonsesia = 0
local azzarsesia = 0
local boxhkosesia = 0
local tool = 0
local barrelModels = 3632

function msg(msg)
    sampAddChatMessage('{FF634F}[{FFFFFF}OilHelper{FF634F}] {FFFFFF}'..msg,-1)
end


function json(filePath)
    local filePath = getWorkingDirectory()..'/config/'..(filePath:find('(.+).json') and filePath or filePath..'.json')
    local class = {}
    if not doesDirectoryExist(getWorkingDirectory()..'/config/') then
        createDirectory(getWorkingDirectory()..'/config/')
    end
    function class:Save(tbl)
        if tbl then
            local F = io.open(filePath, 'w')
            F:write(encodeJson(tbl) or {})
            F:close()
            return true, 'ok'
        end
        return false, 'table = nil'
    end
    function class:Load(defaultTable)
        if not doesFileExist(filePath) then
            class:Save(defaultTable or {})
        end
        local F = io.open(filePath, 'r+')
        local TABLE = decodeJson(F:read() or {})
        F:close()
        for def_k, def_v in next, defaultTable do
            if TABLE[def_k] == nil then
                TABLE[def_k] = def_v
            end
        end
        return TABLE
    end
    return class
end
local OilHelperJSON = json('OilHelper.json'):Load({})


function cfg_save()
inicfg.save(ini, "OilHelper.ini")
end
function save()
    json('OilHelper.json'):Save(OilHelperJSON)
end

function Work()
 if ini.cfg.cho == 1 then ini.cfg.cho = 2
 sampAddChatMessage('{006600}[Oil Tools]: {FFFFFF} Разгрузка', -1) else ini.cfg.cho = 1
sampAddChatMessage('{006600}[Oil Tools]: {FFFFFF}Погрузка', -1)
cfg_save()
end
end

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

function caseSet(mode, caseParam)
    -- 0 сумма ларцов, 1 обнуление, 2 добавление нового, 3 кол-во ларцов
    if mode == 0 then
        local costs = 0
        for index, data in pairs(OilHelperJSON) do
            if data.type == 'Case' and data.larecCost then
                costs = data.larecCost*data.larecKolvo + costs
            end
        end
        return costs
    elseif mode == 1 then
        for index, data in pairs(OilHelperJSON) do
            if data.type == 'Case' then
                data.larecKolvo = 0
            end
        end
        save()
    elseif mode == 2 then
        if not allCases[caseParam] then
            return false
        end
        local addStatus = true
        for index, data in pairs(OilHelperJSON) do
            if data.larecID and data.larecID == caseParam and data.type == 'Case' then
                data.larecKolvo = data.larecKolvo + 1
                save()
                addStatus = false
            end
        end
        if addStatus then
            table.insert(OilHelperJSON, {
                type = 'Case',
                larecName = tostring(allCases[caseParam]),
                larecID = caseParam,
                larecCost = 0,
                larecKolvo = 1,
            }) save()
            msg('Новый ларец{FF634F}:{ffffff} '..allCases[caseParam]..'{FF634F}.{ffffff} Укажите его стоимость в /oilh')
        end
    elseif mode == 3 then
        local count = 0
        for index, data in pairs(OilHelperJSON) do
            if data.type == 'Case' and data.larecKolvo then
                count = data.larecKolvo + count
            end
        end
        return count
    end
end


local renderWindow = imgui.new.bool(false)
local OilStats = imgui.new.bool(false)
local Settings = imgui.new.bool(ini.cfg.Settings)
local moneycfg = imgui.new.bool(ini.cfg.moneycfg)
local azcfg = imgui.new.bool(ini.cfg.azcfg)
local skipi = imgui.new.bool(ini.cfg.skipi)
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
    imgui.SetNextWindowPos(imgui.ImVec2(800,500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
       imgui.Begin('##Main Window', renderWindow, imgui.WindowFlags.NoTitleBar) 
  if imgui.BeginTabBar('Menu') then
			if imgui.BeginTabItem(u8' Основное') then
		      if imgui.Checkbox(u8' Статистика/Выбор Режима',infobarik) then
                    OilStats[0]= not OilStats[0]              
          end

  if imgui.Checkbox(u8' Настройки', Settings) then ini.cfg.Settings = Settings[0] 
 end
		imgui.Separator()
 if ini.cfg.Settings then
imgui.CenterText('Настройки:') 
imgui.Text('Infobar')

            if imgui.Checkbox(u8' Заработанные вирты', moneycfg) then ini.cfg.moneycfg = moneycfg[0] cfg_save()  end

            if imgui.Checkbox(u8' Заработанные AZ-Coins', azcfg) then ini.cfg.azcfg = azcfg[0]  
cfg_save() end 

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
                end 	
                imgui.Separator()		    		
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

if imgui.Button(u8'Обнулить кол-во всех',imgui.ImVec2(imgui.GetWindowWidth()-9, 44)) then caseSet(1) end 
imgui.Separator()
            for index, data in pairs(OilHelperJSON) do
                if data.type == 'Case' then
                    if imgui.CollapsingHeader(u8(string.format("%s (%s)##%s", data.larecName, data.larecKolvo,index))) then
                        imgui.PushItemWidth(75)
                        if imgui.InputInt('##'..index,newLarec.larecCost,0,100000000) then
                            if newLarec.larecCost[0] >= 0 then
                                data.larecCost = newLarec.larecCost[0]
                                save()
                            else newLarec.larecCost[0] = 0 end
                        end 
                        imgui.PopItemWidth()
                        imgui.SameLine()
                        imgui.Text(u8('Текущая стоимость: ' ..data.larecCost.."$"))
                        if imgui.Button(u8'Обнулить кол-во##'..index,imgui.ImVec2(152, 44)) then
                            data.larecKolvo = 0 save()
                        end imgui.SameLine()
             if imgui.Button(u8'Удалить##'..index,imgui.ImVec2(132, 44)) then
                            table.remove(OilHelperJSON, index) save()
                        end
                    end
                    imgui.Separator()
                end
            end

				 end 
	    	    imgui.EndTabBar()
	    	end
        imgui.End()
   end)
  
  imgui.OnFrame(function() return OilStats[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500,500), imgui.Cond.FirstUseEver, imgui.ImVec2(1.5, 1.5))
      
imgui.Begin('##Main OilStats', OilStats, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar) 
    if imgui.Button(u8'Выбор Режима', imgui.ImVec2(-1, 30)) then
Work()
end

if ini.cfg.cho ==  2 then tool = 'Разгрузка' else tool ='Погрузка' 
end

imgui.CenterText('Режим: '..tool..'')



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
          
  

function sampev.onServerMessage(color, text)

 local newLarecCode = text:match("Вам был добавлен предмет.+:item(%d+):")
    if newLarecCode then caseSet(2, tonumber(newLarecCode)) end
    -- ларцы текстом
    local newLarecWord = text:match("Получено вознаграждение: (.+)(%.?)")
    if newLarecWord then
        for k, v in pairs(allCases) do
            if (newLarecWord:gsub("%p","")):find(v:gsub("%p","")) then
                caseSet(2, tonumber(k))
            end
        end
    end


local WBarrel = text:match('Вы успешно продали бочку с .+ литров нефти и получили %$(.+)')
if WBarrel then
local newMoney = WBarrel and WBarrel:gsub('%p','')
    local nMoney = tonumber(newMoney)
        ini.cfg.zarmon = ini.cfg.zarmon+nMoney
        zarmonsesia = zarmonsesia+nMoney
        azzarsesia = azzarsesia + 1
        ini.cfg.azzar = ini.cfg.azzar + 1      
        boxhkosesia = boxhkosesia + 1
        ini.cfg.boshkiini = ini.cfg.boshkiini + 1
        cfg_save()
end
end -- Энд функции онСервер
     

function sampev.onSetPlayerAttachedObject(playerId, index, create, data)
    -- Проверяем только для себя (свой ID)
    local _, myId = sampGetPlayerIdByCharHandle(playerPed) 
    if playerId == myId then
print(data.modelId)
            if data.modelId == barrelModels then
                has_barrel = true else has_barrel = false
                -- Здесь ваш код (например, включение бега или уведомление)
              return false
            end
        end
 end



function sampev.onShowDialog(id, style, title, button1, button2, text)
-- Если вкл. скрытие покупки и открыто окно покупки
 if skipi[0] == true and id == 978 then
       sampSendDialogResponse(978, 1, 0, 0)
 -- покупаем
        return false
 end
if skipi[0] == true and id == 25382 then
       sampSendDialogResponse(25382, 1, 0, 0)
 -- покупаем
        return false
 end

-- Авто Погрузка
      if viborts[0] and id == 27255 then
        for line in text:gmatch('([^\n\r]+)') do
            line = line:gsub('{......}', ' ')
            local num, status = line:match('%№(%d+) (.+)')
            if status:find('Положить') and ini.cfg.cho == 1 and     has_barrel == true then
             sampSendDialogResponse(id,1,num-1,'')
             has_barrel = false
       elseif status:find('Положить') and ini.cfg.cho == 1.  and has_barrel == false then
sampSendDialogResponse(id,0,0,'')
                return false
            end
-- Авто Разгрузка Транспорта
            if status:find('Забрать') and ini.cfg.cho == 2 and has_barrel == false then
                sampSendDialogResponse(id,1,num-1,'')
has_barrel = true 
elseif status:find('Забрать') and ini.cfg.cho == 2 and has_barrel == true then
sampSendDialogResponse(id,0,0,'')
                return false
            end
        end
    end

if viborts[0] and id == 26123 then
        for line in text:gmatch('([^\n\r]+)') do
            line = line:gsub('{......}', ' ')
            local num, status = line:match('%№(%d+) (.+)')
           if status ~= nil and num ~= nil then
            if status:find('Положить') and ini.cfg.cho == 1 and     has_barrel == true then
             sampSendDialogResponse(id,1,num-1,'')
             has_barrel = false
       elseif status:find('Положить') and ini.cfg.cho == 1.  and has_barrel == false then
sampSendDialogResponse(id,0,0,'')
                return false
            end
end
-- Авто Разгрузка Транспорта
            if status ~= nil and num ~= nil then
            if status:find('Забрать') and ini.cfg.cho == 2 and has_barrel == false then
                sampSendDialogResponse(id,1,num-1,'')
has_barrel = true 
elseif status:find('Забрать') and ini.cfg.cho == 2 and has_barrel == true then
sampSendDialogResponse(id,0,0,'')
                return false
            end
end
        end
    end


 end --конец онсшов


   
   imgui.OnInitialize(function()
    theme()
    
    imgui.GetIO().IniFilename = nil
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solmyID'), 14, config, iconRanges)

end)

-- Основной Маин

 function main()
while not isSampAvailable() do wait(0) end
    
    sampRegisterChatCommand('oilh', function() renderWindow[0] = not renderWindow[0] end)
    
sampRegisterChatCommand('oil',function()
sampSendChat('/oilgroundlist')
        
    end)
    wait(-1)
end

 -- Тема
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
