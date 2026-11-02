script_name("Family Helper")
script_author(" KJ // Likuur")
script_version("1.0")

local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local new = imgui.new
local faicons = require('fAwesome6')
local sampev = require("lib.samp.events")
local inicfg = require 'inicfg'
local monet = require("MoonMonet")
local http = require("socket.http")
----------------
local ffi = require 'ffi'
local new, str = imgui.new, ffi.string

local gta = ffi.load("GTASA")
local request = require("requests")
local FHmenu = new.bool()
local Infamenu = new.bool()
local AI_TOGGLE = {}
local ToU32 = imgui.ColorConvertFloat4ToU32
local cacar = imgui.new.bool()
----------------
local MDS = MONET_DPI_SCALElocal MDS = MONET_DPI_SCALE
----------------

local ini = inicfg.load({
    huki = {
     levl = false,           
kvest = false,           
invitev = false,
farmm = 0,
invradius = false,    
------------------------------------     
piar_text = "Поздравляю!", 
famzadanie = "Спасибо за выполнение задания!", 
faminv = "Привет добро пожаловать в семью!", 
------------------------------------
zadevjkafa = 0,
piarvfam = "",
------------
actfam = false,
    },
    binder = {}, 
    	theme = {
    	moonmonet = (61951)
},
}, "FH")


local VersionV = '2.2'

----------------------
local playerId   = nil
local levl = new.bool(ini.huki.levl)
local invradius = new.bool(ini.huki.invradius)
local kvest = new.bool(ini.huki.kvest)
local invitev = new.bool(ini.huki.invitev)
local checkboxone = new.bool(true)
------------------------------------
local piar_text = new.char[400](u8(ini.huki.piar_text))
local faminv = new.char[400](u8(ini.huki.faminv))
local famzadanie = new.char[400](u8(ini.huki.famzadanie))
-------------------------------------
local piarvfam = new.char[400](u8(ini.huki.piarvfam))
------------------------------------
local zadevjkafa = imgui.new.int(ini.huki.zadevjkafa)
-------------------------------------
local actfam = new.bool(ini.huki.actfam)
------------------------------------
local window     = imgui.new.bool(false)
function cfg_save()
inicfg.save(ini, "FH")
end
local Faminv = 0
local tab = 1
local Invitesmenu = imgui.new.bool(false)	
function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowWidth()/2-imgui.CalcTextSize(u8(text)).x/2)
    imgui.Text(u8(text))
end
-- Теперь переменные доступны напрямую из массивов без глобальной области видимости
-- Например, variables[1].se, variables[1].i, boolVariables[1]
bnd = {
	imgui.new.int(0),
	new.char[100](),
	""
}
local bind_text_size = 256
local bind_time_size = ffi.sizeof('int')
local cmd_text_size = 256
local bind_text = ffi.new('char[?]', bind_text_size)
local bind_time = ffi.new('int[1]')
local cmd_text = ffi.new('char[?]', cmd_text_size)
local search = imgui.new.char[256]()
local namefam = 0
local tipfam = 0
local repfam = 0
local zlovrepfam = 0
local lvlfamu = 0
local playfam = 0
local spawnfam = 0
local moneyd = 0
local monetasklad = 0
local leaderfam = 0
local zam1 = 0
local zam2 = 0
local zam3 = 0
local famfrak = 0

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
  for line in text:gmatch('[^\n]+') do
if line:find('Название семьи: (.*)') then
    namefam = line:gsub('{......}', ''):match('Название семьи: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Тип семьи: (.*)') then
    tipfam = line:gsub('{......}', ''):match('Тип семьи: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Репутация семьи: (.*)') then
    repfam = line:gsub('{......}', ''):match('Репутация семьи: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Зловещая репутация семьи: (.*)') then
    zlovrepfam = line:gsub('{......}', ''):match('Зловещая репутация семьи: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Уровень семьи: (.*)') then
    lvlfamu = line:gsub('{......}', ''):match('Уровень семьи: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Членов в семье: (.*)') then
    playfam = line:gsub('{......}', ''):match('Членов в семье: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Местоположение спавна: (.*)') then
    spawnfam = line:gsub('{......}', ''):match('Местоположение спавна: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Денег в бюджете семьи: (.*)') then
    moneyd = line:gsub('{......}', ''):match('Денег в бюджете семьи: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Семейных монет на складе: (.*)') then
    monetasklad = line:gsub('{......}', ''):match('Семейных монет на складе: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Лидер семьи: (.*)') then
    leaderfam = line:gsub('{......}', ''):match('Лидер семьи: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Заместитель: (.*)') then
    zam1 = line:gsub('{......}', ''):match('Заместитель: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Заместитель 2: (.*)') then
    zam2 = line:gsub('{......}', ''):match('Заместитель 2: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Заместитель 3: (.*)') then
    zam3 = line:gsub('{......}', ''):match('Заместитель 3: (.*)')
end
end
for line in text:gmatch('[^\n]+') do
if line:find('Семейная частная фракция: (.*)') then
    famfrak = line:gsub('{......}', ''):match('Семейная частная фракция: (.*)')
end
end
end

local lmPath = "Family Helper - KJ mods.lua"
local lmUrl = "https://github.com/KJLikuur/Family-Helper.lua/raw/refs/heads/main/Family%20Helper%20-%20KJ%20mods.lua"
function downloadFile(url, path)

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
  
function check_update()
    msg("Проверка наличия обновлений...")
    local currentVersionFile = io.open(lmPath, "r")
    local currentVersion = currentVersionFile:read("*a")
    currentVersionFile:close()
    local response = http.request(lmUrl)
    if response and response ~= currentVersion then
        msg("У вас не актуальная версия! Для обновления перейдите во вкладку: Информация")
    else
        msg("У вас актуальная версия скрипта.")
    end
end
local function updateScript(scriptUrl, scriptPath)
    msg("Проверка наличия обновлений...")
    local response = http.request(scriptUrl)
    if response and response ~= currentVersion then
        msg("Доступна новая версия скрипта! Обновление...")
        
        local success = downloadFile(scriptUrl, scriptPath)
        if success then
            msg("Скрипт успешно обновлен.")
            thisScript():reload()
        else
            msg("Не удалось обновить скрипт.")
        end
    else
        msg("Скрипт уже обновлён до последней версией.")
    end
end

	
imgui.OnInitialize(function()
    local tmp = imgui.ColorConvertU32ToFloat4(ini.theme['moonmonet'])
  gen_color = monet.buildColors(ini.theme.moonmonet, 1.0, true)
  mmcolor = imgui.new.float[3](tmp.z, tmp.y, tmp.x)
  apply_n_t()
end)

imgui.OnFrame(function() return FHmenu[0] end, function(player)
    local resX, resY = getScreenResolution()
        local sizeX, sizeY = 875 * MDS, 400 * MDS
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
    imgui.Begin('##Window', FHmenu, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoBackground + imgui.WindowFlags.NoTitleBar)
    --Начало кода mimgui 
    if imgui.BeginChild('usernsnr', imgui.ImVec2(350, -1), true) then
   
     
         
         
         if imgui.Button(faicons('user') .. u8' Главная', imgui.ImVec2(-1, 70)) then
            tab = 1
        end
        
        if imgui.Button(faicons('user') .. u8' Биндер', imgui.ImVec2(-1, 70)) then
            tab = 2
        end

        if imgui.Button(faicons('gears') .. u8' МП', imgui.ImVec2(-1, 70)) then
            tab = 3
        end
        
        if imgui.Button(faicons('gears') .. u8' Доп. функции', imgui.ImVec2(-1, 70)) then
            tab = 4
        end
        
        if imgui.Button(faicons('gears') .. u8' Команды', imgui.ImVec2(-1, 70)) then
            tab = 5
        end
        
        if imgui.Button(faicons('gears') .. u8' Инвайты', imgui.ImVec2(-1, 70)) then
            tab = 6
        end
        
        if imgui.Button(faicons('gears') .. u8' Спавн транспорта', imgui.ImVec2(-1, 70)) then
            tab = 7
        end
        
        if imgui.Button(faicons('gears') .. u8' Настройки', imgui.ImVec2(-1, 70)) then
            tab = 8
        end  
    imgui.CenterText("версия: 1.0.0")
    imgui.CenterText("FH - KJ mods")
        imgui.EndChild() 
        end 
       
        imgui.SameLine()
        if imgui.BeginChild('Name', imgui.ImVec2(-1, -1), true) then

        if tab == 1 then
        imgui.CenterText("Главная")
		imgui.SetCursorPosY(5)
		imgui.SetCursorPosX(1350)

		if imgui.Button("X", imgui.ImVec2(40, 40)) then
		FHmenu[0] = false
		end
		imgui.Separator()
	
        imgui.Text(u8"Название семьи: " ..u8(namefam))
        imgui.Text(u8"Тип семьи: " ..u8(tipfam))
        imgui.Text(u8"Репутация семьи: " ..u8(repfam))
        imgui.Text(u8"Зловещая репутация семьи: " ..u8(zlovrepfam))
        imgui.Text(u8"Уровень семьи: " ..u8(lvlfamu))
        imgui.Text(u8"Членов в семье: " ..u8(playfam))
        imgui.Text(u8"Местоположение спавна: " ..u8(spawnfam))
        imgui.Text(u8"Денег в бюджете семьи: " ..u8(moneyd))
        imgui.Text(u8"Семейных монет на складе: " ..u8(monetasklad))
        imgui.Text(u8" ")
        imgui.Text(u8" ")
        imgui.Text(u8"Лидер семьи: " ..u8(leaderfam))
        imgui.Text(u8"Заместитель: " ..u8(zam1))
        imgui.Text(u8"Заместитель 2: " ..u8(zam2))
        imgui.Text(u8"Заместитель 3: " ..u8(zam3))
        imgui.Text(u8" ")
        imgui.Text(u8" ")
        imgui.Text(u8"Семейная частная фракция: " ..u8(famfrak))
        imgui.Separator()
        if imgui.Button(u8"Обновление информации", imgui.ImVec2(-1, 45)) then
     sampSendChat  ("/fammenu") 
sampSendClickTextdraw(2067)
        sampSendDialogResponse(27087, 1, 0, nil)	
        end
        elseif tab == 2 then
	imgui.CenterText("Биндер")
		imgui.SetCursorPosY(5)
		imgui.SetCursorPosX(1350)

		if imgui.Button("X", imgui.ImVec2(40, 40)) then
		FHmenu[0] = false
		end
		imgui.Separator()
		imgui.BeginChild("", imgui.ImVec2(115 * MONET_DPI_SCALE, -1), true)
			    	for number = 1, 50, 1 do
			    		if ini.binder[number .. '_cmd'] ~= nil and ini.binder[number .. '_cmd'] ~= '' then
				    		title_binder_test = '/' .. ini.binder[number .. '_cmd']
			    		else
					    	title_binder_test = u8'Слот №' .. number
				    	end
				    	if imgui.Selectable(title_binder_test) then
					    	for bind_n = 1, 50, 1 do
						    	if ini.binder[bind_n .. "_text"] == "" and bind_n ~= number then
							    	ini.binder[bind_n .. "_text"] = ""
								    ini.binder[bind_n .. "_time"] = ""
						    		ini.binder[bind_n .. "_cmd"] = ""
					    		end
					    	end
					    	if ini.binder[number .. "_text"] == nil then
					    		ini.binder[number .. "_text"] = ""
						    	ini.binder[number .. "_time"] = 1
					    		ini.binder[number .. "_cmd"] = ""
					    	end
				    		inicfg.save(ini, 'FH')
				    		imgui.StrCopy(bind_text, string.gsub(tostring(ini.binder[number .. "_text"]), "&", "\n"), bind_text_size)
					    	imgui.StrCopy(bind_time, tostring(ini.binder[number .. "_time"]), bind_time_size)
					    	imgui.StrCopy(cmd_text, tostring(ini.binder[number .. "_cmd"]), cmd_text_size)
				    		bnd[1] = 1
				    		ttax = number
			    		end
			     	end
		     		imgui.EndChild()
			     	imgui.SameLine()
		    	 	imgui.BeginChild("##фы", imgui.ImVec2(-1, -1), true)
		     		if bnd[1] == 1 then
				    	imgui.Text(u8("Введите команду: /"))
				    	imgui.SameLine()
				    	imgui.PushItemWidth(100 * MONET_DPI_SCALE)
				    	if imgui.InputText("", cmd_text, cmd_text_size) then
				    		ini.binder[ttax .. "_cmd"] = ffi.string(cmd_text)
				    		inicfg.save(ini, 'FH')
				    	end
			    		imgui.PopItemWidth()
				    	imgui.Text(u8("Задержка"))
			    		imgui.SameLine()
			    		imgui.PushItemWidth(70 * MONET_DPI_SCALE)
			    		if imgui.InputInt(u8'секунд(а)', bind_time) then
				    		ini.binder[ttax .. "_time"] = bind_time[0]
				    		inicfg.save(ini, 'FH')
			    		end
			    		imgui.PopItemWidth()
			    		imgui.Text(u8("Введите текст:"))
			    		if imgui.InputTextMultiline("	 ", bind_text, bind_text_size, imgui.ImVec2(-1, -1)) then
				    		ini.binder[ttax .. "_text"] = string.gsub(ffi.string(bind_text), "\n", "&")
				    		inicfg.save(ini, 'FH')
				    	end
		    		end
			    	imgui.EndChild()
        elseif tab == 3 then 
        imgui.CenterText("МП")
		imgui.SetCursorPosY(5)
		imgui.SetCursorPosX(1350)

		if imgui.Button("X", imgui.ImVec2(40, 40)) then
		FHmenu[0] = false
		end
		imgui.Separator()
        elseif tab == 4 then
        imgui.CenterText("Доп. функции")
		imgui.SetCursorPosY(5)
		imgui.SetCursorPosX(1350)

		if imgui.Button("X", imgui.ImVec2(40, 40)) then
		FHmenu[0] = false
		end
		imgui.Separator()
        if imgui.ToggleButton(u8' Поздравлять с новым уровнем',levl) then
ini.huki.levl = levl[0]
 cfg_save() end
imgui.InputText(u8"Текст поздравления", piar_text, 400)
	ini.huki.piar_text = u8:decode(str(piar_text))
	cfg_save()
if imgui.ToggleButton(u8' Приветствие при инвайте',invitev) then
ini.huki.invitev = invitev[0]
 cfg_save() end 
imgui.InputText(u8"Текст приветствия", faminv, 400)
	ini.huki.faminv = u8:decode(str(faminv))
	cfg_save()
if imgui.ToggleButton(u8'+реп за квест',kvest) then
ini.huki.kvest = kvest[0]
 cfg_save() end 
imgui.InputText(u8"Благодарство  за выполнение квеста", famzadanie, 400)
	ini.huki.famzadanie = u8:decode(str(famzadanie))
	cfg_save()
	imgui.Separator()
	imgui.CenterText("Авто инвайт")
        imgui.Text(u8"Инвайт на слово [ инв ]")
                imgui. SameLine()
        if imgui.ToggleButton(u8' ##вклвыкл',invradius) then
        ini.huki.invradius = invradius[0]
 cfg_save() end 
 imgui.Separator()
        elseif tab == 5 then
        imgui.CenterText("Команды")
		imgui.SetCursorPosY(5)
		imgui.SetCursorPosX(1350)

		if imgui.Button("X", imgui.ImVec2(40, 40)) then
		FHmenu[0] = false
		end
		imgui.Separator()
        imgui.Text(u8"/fi [ID] - добавление игрока в семью.")
        elseif tab == 6 then
        imgui.CenterText("Инвайты")
		imgui.SetCursorPosY(5)
		imgui.SetCursorPosX(1350)

		if imgui.Button("X", imgui.ImVec2(40, 40)) then
		FHmenu[0] = false
		end
		imgui.Separator()
		
        if imgui.ToggleButton(u8"Меню с информацией про инвайты", Invitesmenu) then 
        Infamenu[0]= not Infamenu[0]
        end
        imgui.SameLine(0,0)
        imgui.Text(Invitesmenu[0] and u8' активно' or u8' неактивно')
        imgui.CenterText("Настройки меню")        
        
        imgui.Separator()
        imgui.CenterText("Информация: ")
        imgui.Text(u8"Принято игроков за сессию : " ..Faminv)
        imgui.SameLine()
        if imgui.Button(faicons('TRASH') .. '', imgui.ImVec2(50, 40)) then
        delete()
        end
        imgui.Text(u8"Принято игроков за все время :" ..ini.huki.farmm)
      
        
        imgui.Separator()
        elseif tab == 7 then
        	imgui.SetCursorPosY(10)
		imgui.CenterText("Спавн транспорта")
		imgui.SetCursorPosY(5)
		imgui.SetCursorPosX(1350)

		if imgui.Button("X", imgui.ImVec2(40, 40)) then
		FHmenu[0] = false
		end
		imgui.Separator()
imgui.Text(u8"Через сколько сек спавн транспорта")
        if imgui.Button(faicons('POWER_OFF') .. u8"30", imgui.ImVec2(25 * MONET_DPI_SCALE, 25 * MONET_DPI_SCALE)) then
        lua_thread.create(function()
        sampSendChat("/fam Внимание через 30 секунд произойдет спавн семейного транспорт!")
        wait(30000)
        sampSendChat("/famspawn")
					wait(100)
					sampSendChat("/fam Семейный транспорт успешно заспавнен!")
        end)
        end
        imgui.SameLine()
                if imgui.Button(faicons('POWER_OFF') .. u8"20", imgui.ImVec2(25 * MONET_DPI_SCALE, 25 * MONET_DPI_SCALE)) then
                lua_thread.create(function()
                sampSendChat("/fam Внимание через 20 секунд произойдет спавн семейного транспорт!")
                wait(20000)
                sampSendChat("/famspawn")
					wait(100)
					sampSendChat("/fam Семейный транспорт успешно заспавнен!")
                end)
                end
                
                        if imgui.Button(faicons('POWER_OFF') .. u8"60", imgui.ImVec2(25 * MONET_DPI_SCALE, 25 * MONET_DPI_SCALE)) then
                        lua_thread.create(function()
                        sampSendChat("/fam Внимание через 60 секунд произойдет спавн семейного транспорт!")
                        wait(60000)
                        sampSendChat("/famspawn")
					wait(100)
					sampSendChat("/fam Семейный транспорт успешно заспавнен!")
                        end)
                        end
                        imgui.SameLine()
                                if imgui.Button(faicons('POWER_OFF') .. u8"10", imgui.ImVec2(25 * MONET_DPI_SCALE, 25 * MONET_DPI_SCALE)) then
                                lua_thread.create(function()
                                sampSendChat("/fam Внимание через 10 секунд произойдет спавн семейного транспорт!")
                                wait(10000)
                                sampSendChat("/famspawn")
					wait(100)
					sampSendChat("/fam Семейный транспорт успешно заспавнен!")
                                end)
                                end
                                      if imgui.Button(faicons('POWER_OFF') .. u8" спавн сейчас", imgui.ImVec2(90 * MONET_DPI_SCALE, 40 * MONET_DPI_SCALE)) then   
            sampSendChat("/famspawn")
end           
        elseif tab == 8 then
                	imgui.SetCursorPosY(10)
		imgui.CenterText("Настройки")
		imgui.SetCursorPosY(5)
		imgui.SetCursorPosX(1350)

		if imgui.Button("X", imgui.ImVec2(40, 40)) then
		FHmenu[0] = false
		end
		imgui.Separator()
        if imgui.Button(faicons('POWER_OFF') .. "", imgui.ImVec2(40 * MONET_DPI_SCALE, 40 * MONET_DPI_SCALE)) then
                thisScript():unload()
            end
            imgui.SameLine()
            if imgui.Button(faicons('ROTATE_RIGHT') .. "", imgui.ImVec2(40 * MONET_DPI_SCALE, 40 * MONET_DPI_SCALE)) then          
                thisScript():reload()
            end         
				imgui.Separator()
				imgui.Text(u8' Установленная версия хелпера ' .. thisScript().version)
				imgui.SameLine()
			if imgui.SmallButton(u8' Обновить') then
    updateScript(lmUrl, lmPath)
end
				imgui.Separator()
				imgui.CenterText(' Цветовая тема хелпера:')
				if imgui.ColorEdit3('## COLOR', mmcolor, imgui.ColorEditFlags.NoInputs) then
                r,g,b = mmcolor[0] * 255, mmcolor[1] * 255, mmcolor[2] * 255
              argb = join_argb(0, r, g, b)
                ini.theme.moonmonet = argb
                cfg_save()
          apply_n_t()
            end
            imgui.SameLine()
            imgui.Text(u8' Цвет MoonMonet') 
            
imgui.Separator()
imgui.Link("https://t.me/Flizzy_YT", u8("Автор скрипта"))
imgui.Link("https://t.me/K_Jmods", u8("ТГК автора скрипта"))
        end
        imgui.EndChild() 
        end 
        imgui.End()
    end)
  
----------------
function sampev.onSendCommand(cmd)
	for number = 1, 50, 1 do
		if ini.binder[number .. "_text"] ~= nil and ini.binder[number .. "_text"] ~= "" and ini.binder[number .. "_time"] ~= "" and cmd == '/' .. ini.binder[number .. "_cmd"] then
			lua_thread.create(function()
				sampSendChat(u8:decode(string.match(ini.binder[number .. "_text"], "([^&]+)")))

				for ttext in string.gmatch(ini.binder[number .. "_text"], "&([^&]+)") do
					wait(tonumber(ini.binder[number .. "_time"]) * 1000)
					sampSendChat(u8:decode(ttext))
				end
			end)

			return false
		end
	end
end

function imgui.Link(link, text)
    text = text or link
    local tSize = imgui.CalcTextSize(text)
    local p = imgui.GetCursorScreenPos()
    local DL = imgui.GetWindowDrawList()
    local col = { 0xFFFF7700, 0xFFFF9900 }
    if imgui.InvisibleButton("##" .. link, tSize) then os.execute("explorer " .. link) end
    local color = imgui.IsItemHovered() and col[1] or col[2]
    DL:AddText(p, color, text)
    DL:AddLine(imgui.ImVec2(p.x, p.y + tSize.y), imgui.ImVec2(p.x + tSize.x, p.y + tSize.y), color)
end


imgui.OnFrame(function() return Infamenu[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500,500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
       imgui.Begin('##Main Infamenu.', Infamenu, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar)
       imgui.Text(u8"Принято игроков за все время :" ..ini.huki.farmm)
       imgui.Text(u8"Принято игроков за сессию : " ..Faminv)
       imgui.End()
      end)

imgui.OnFrame(function() return window[0] end, function(self)
    local sizeX, sizeY = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(450, 250), imgui.Cond.FirstUseEver)
    imgui.Begin("&:__", window, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar)
imgui.CenterText(sampGetPlayerNickname(playerId).."["..playerId.."]")
if imgui.Button(u8' Принять', imgui.ImVec2(-1, 45)) then 
        lua_thread.create(function()
        sampSendChat('/faminvite '..playerId)
        window[0] = false
        end)
        end
        if imgui.Button(u8' Выгнать', imgui.ImVec2(-1, 45)) then 
        lua_thread.create(function()
        sampSendChat('/famuninvite '..playerId..' ПСЖ')
        window[0] = false
        end)
        end
imgui.CenterText("Выдача ранга")
        if imgui.Button(u8' 1', imgui.ImVec2(80, 80)) then  
        lua_thread.create(function()
        sampSendChat('/setfrank '..playerId..' 1')
        window[0] = false
        end)
        end  
imgui.SameLine()   
        if imgui.Button(u8' 2', imgui.ImVec2(80, 80)) then  
        lua_thread.create(function()
        sampSendChat('/setfrank '..playerId..' 2')
        window[0] = false
        end)
        end 
imgui.SameLine()    
        if imgui.Button(u8' 3', imgui.ImVec2(80, 80)) then  
        lua_thread.create(function()
        sampSendChat('/setfrank '..playerId..' 3')
        window[0] = false
        end)
        end  
imgui.SameLine()      
        if imgui.Button(u8' 4', imgui.ImVec2(80, 80)) then  
        lua_thread.create(function()
        sampSendChat('/setfrank '..playerId..' 4')
        window[0] = false
        end)
        end
        imgui.SameLine()
        if imgui.Button(u8' 5', imgui.ImVec2(80, 80)) then 
        lua_thread.create(function()
        sampSendChat('/setfrank '..playerId..' 5')
        window[0] = false
        end)
        end  
        if imgui.Button(u8' 6', imgui.ImVec2(80, 80)) then  
        lua_thread.create(function()
        sampSendChat('/setfrank '..playerId..' 6')
        window[0] = false
        end)
        end 
imgui.SameLine()      
        if imgui.Button(u8' 7', imgui.ImVec2(80, 80)) then  
        lua_thread.create(function()
        sampSendChat('/setfrank '..playerId..' 7')
        window[0] = false
        end)
        end   
imgui.SameLine()   
        if imgui.Button(u8' 8', imgui.ImVec2(80, 80)) then  
        lua_thread.create(function()
        sampSendChat('/setfrank '..playerId..' 8')
        window[0] = false
        end)
        end  
imgui.SameLine()      
        if imgui.Button(u8' 9', imgui.ImVec2(80, 80)) then  
        lua_thread.create(function()
        sampSendChat('/setfrank '..playerId..' 9')
        window[0] = false
        end)
        end  
imgui.SameLine()      
        if imgui.Button(u8' 10', imgui.ImVec2(80, 80)) then 
        lua_thread.create(function()
        sampSendChat('/setfrank '..playerId..' 10')
        window[0] = false
        end)
        end 
    imgui.End()
end)

     
imgui.OnInitialize(function()
decor()


    imgui.GetIO().IniFilename = nil
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 14, config, iconRanges)
end)


----------------
function main()
if not isSampfuncsLoaded() or not isSampLoaded() then return end
	while not isSampAvailable() do wait(100) end
	while not sampIsLocalPlayerSpawned() do wait(0) end
check_update()
msg('Загрузка хелпера прошла успешно! Активация: /fh')
    sampRegisterChatCommand('fh', function() FHmenu[0] = not FHmenu[0] end)
    sampRegisterChatCommand('fi', function(arg)
        sampSendChat('/faminvite '..arg)
    end)
    sampRegisterChatCommand("vz", function(id)
        if tonumber(id) ~= nil and sampIsPlayerConnected(tonumber(id)) then
            playerId = tonumber(id)
            window[0] = true
            else 
            msg("Введите: /vz [ID]")
        end
        end)
    wait(-1)
end
function imgui.ToggleButton(str_id, value)
	local duration = 0.3
	local p = imgui.GetCursorScreenPos()
    local DL = imgui.GetWindowDrawList()
	local size = imgui.ImVec2(60, 40)
    local title = str_id:gsub('##.*$', '')
    local ts = imgui.CalcTextSize(title)
    local cols = {
    	enable = imgui.GetStyle().Colors[imgui.Col.ButtonActive],
    	disable = imgui.GetStyle().Colors[imgui.Col.TextDisabled]	
    }
    local radius = 6
    local o = {
    	x = 4,
    	y = p.y + (size.y / 2)
    }
    local A = imgui.ImVec2(p.x + radius + o.x, o.y)
    local B = imgui.ImVec2(p.x + size.x - radius - o.x, o.y)

    if AI_TOGGLE[str_id] == nil then
        AI_TOGGLE[str_id] = {
        	clock = nil,
        	color = value[0] and cols.enable or cols.disable,
        	pos = value[0] and B or A
        }
    end
    local pool = AI_TOGGLE[str_id]
    
    imgui.BeginGroup()
	    local pos = imgui.GetCursorPos()
	    local result = imgui.InvisibleButton(str_id, imgui.ImVec2(size.x, size.y))
	    if result then
	        value[0] = not value[0]
	        pool.clock = os.clock()
	    end
	    if #title > 0 then
		    local spc = imgui.GetStyle().ItemSpacing
		    imgui.SetCursorPos(imgui.ImVec2(pos.x + size.x + spc.x, pos.y + ((size.y - ts.y) / 2)))
	    	imgui.Text(title)
    	end
    imgui.EndGroup()

 	if pool.clock and os.clock() - pool.clock <= duration then
        pool.color = bringVec4To(
            imgui.ImVec4(pool.color),
            value[0] and cols.enable or cols.disable,
            pool.clock,
            duration
        )

        pool.pos = bringVec2To(
        	imgui.ImVec2(pool.pos),
        	value[0] and B or A,
        	pool.clock,
            duration
        )
    else
        pool.color = value[0] and cols.enable or cols.disable
        pool.pos = value[0] and B or A
    end

	DL:AddRect(p, imgui.ImVec2(p.x + size.x, p.y + size.y), ToU32(pool.color), 10, 15, 1)
	DL:AddCircleFilled(pool.pos, radius, ToU32(pool.color))

    return result
end
function bringVec4To(from, to, start_time, duration)
    local timer = os.clock() - start_time
    if timer >= 0.00 and timer <= duration then
        local count = timer / (duration / 100)
        return imgui.ImVec4(
            from.x + (count * (to.x - from.x) / 100),
            from.y + (count * (to.y - from.y) / 100),
            from.z + (count * (to.z - from.z) / 100),
            from.w + (count * (to.w - from.w) / 100)
        ), true
    end
    return (timer > duration) and to or from, false
end

function bringVec2To(from, to, start_time, duration)
    local timer = os.clock() - start_time
    if timer >= 0.00 and timer <= duration then
        local count = timer / (duration / 100)
        return imgui.ImVec2(
            from.x + (count * (to.x - from.x) / 100),
            from.y + (count * (to.y - from.y) / 100)
        ), true
    end
    return (timer > duration) and to or from, false
end

function delete()
   Faminv = 0
end

----------------
 

	function dekoe()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    style.WindowPadding = imgui.ImVec2(15, 15)
    style.WindowRounding = 10.0
    style.ChildRounding = 25.0
    style.FramePadding = imgui.ImVec2(8, 7)
    style.FrameRounding = 8.0
    style.ItemSpacing = imgui.ImVec2(8, 8)
    style.ItemInnerSpacing = imgui.ImVec2(10, 6)
    style.IndentSpacing = 25.0
    style.ScrollbarSize = 20.0
    style.ScrollbarRounding = 12.0
    style.GrabMinSize = 10.0
    style.GrabRounding = 6.0
    style.PopupRounding = 8
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    style.ChildBorderSize = 1.0
end

function sampev.onServerMessage(color, text)
if  ini.huki.levl then
    if text:find('уровня. В семью начислен опыт.') then
sampSendChat("/fam " ..ini.huki.piar_text)
end
end
  if ini.huki.invradius then
    for _, word in ipairs({"инв", "инвайт","Инвайт", "инвайт пж", "Инвайт пж", "можно в фам", "Можно в фам", "Прими", "прими", "инв в фаму", "Инв в фаму", "Прими в семью"}) do
      id = string.match(string.gsub(text, '{%x+}', ''), ('%[(%d+)%].*: %s*' .. word))
      if id then
        sampSendChat('/faminvite ' .. id)
        break
      end
    end
  end
   
if  ini.huki.kvest then
    if text:find('выполнил ежедневное задание, семья получила') then
sampSendChat("/fam " ..ini.huki.famzadanie)
end
end
if  ini.huki.invitev then
    if text:find('пригласил в семью нового члена: ') then
sampSendChat("/fam " ..ini.huki.faminv)
end
end
if text:find('принял ваше предложение вступить в семью') then
Faminv = Faminv +1
ini.huki.farmm = ini.huki.farmm + 1
cfg_save()
 end
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
 
function msg(text)
    gen_color = monet.buildColors(ini.theme.moonmonet, 1.0, true)
    local a, r, g, b = explode_argb(gen_color.accent1.color_300)
    curcolor = '{' .. rgb2hex(r, g, b) .. '}'
    curcolor1 = '0x' .. ('%X'):format(gen_color.accent1.color_300)
    sampAddChatMessage("[FH - KJ mods]: {FFFFFF}" .. text, curcolor1)
end

function apply_monet()
  imgui.SwitchContext()
  local style = imgui.GetStyle()
  local colors = style.Colors
  local clr = imgui.Col
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

function apply_n_t()
    gen_color = monet.buildColors(ini.theme.moonmonet, 1.0, true)
    local a, r, g, b = explode_argb(gen_color.accent1.color_300)
  curcolor = '{'..rgb2hex(r, g, b)..'}'
    curcolor1 = '0x'..('%X'):format(gen_color.accent1.color_300)
    apply_monet()
end

function explode_argb(argb)
    local a = bit.band(bit.rshift(argb, 24), 0xFF)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return a, r, g, b
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

function join_argb(a, r, g, b)
    local argb = b  -- b
    argb = bit.bor(argb, bit.lshift(g, 8))  -- g
    argb = bit.bor(argb, bit.lshift(r, 16)) -- r
    argb = bit.bor(argb, bit.lshift(a, 24)) -- a
    return argb
end

local function ARGBtoRGB(color)
    return bit.band(color, 0xFFFFFF)
end