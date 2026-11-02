local imgui = require 'mimgui' 
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local requests = require "requests"
local new = imgui.new
local menu = new.bool(false)
local infookno = new.bool()
local infokno = new.bool(false)
local oknolog = new.bool(false)
local LogMenu = new.bool()
local calcmenu = new.bool()
local LogOkno = new.bool()
local vigod = new.bool(false)
local ev = require 'lib.samp.events'
local ffi = require 'ffi'
local str = ffi.string
local sf = require 'sampfuncs'
local gta = ffi.load("GTASA")
local faicons = require 'fAwesome6'

script_name('ProductHelper.lua')
script_author('@jskiptymods')
script_description(u8'ProductHelper - многофункциональный хелпер для работы развозчика продуктов. Активация по умолчанию - /product')

local inicfg = require 'inicfg'
local ini = inicfg.load({
	cfg = {
		int = 0,
		int2 = 0,
		zarp = 0,
		reic = 0,
		larec = 0,
		theme = 1,
		skipd = false,
		zpfull = false,
		larecc = false,
		reisi = false,
		timer = false,
		autog = false,
		larecsalary = 0,
		activation = 'product',
		}
	}, "sablo.ini")

function save()
	inicfg.save(ini, "sablo.ini")
end

local WeatherAndTime = {
  weather = new.int(0),
  time = new.int(0),
  locked_time = 0,
  new_time = false,
  thread = nil
}

local input = imgui.new.char[256]("")

local buttons = {
    { "C", "X", "/", "*" },
    { "7", "8", "9", "-" },
    { "4", "5", "6", "+" },
    { "1", "2", "3", "=" },
    { "0" }
}

local buttonSize = imgui.ImVec2(111, 70)

local buffers = {
    larecsalary = new.int(ini.cfg.larecsalary),
}

local zpfull = imgui.new.bool(ini.cfg.zpfull)
local skipd = imgui.new.bool(ini.cfg.skipd)
local autog = imgui.new.bool(ini.cfg.autog)
local skipdi = imgui.new.bool(false)
local autoga = imgui.new.bool(false)
local calculator = imgui.new.bool(false)
local reisi = imgui.new.bool(ini.cfg.reisi)
local larecc = imgui.new.bool(ini.cfg.larecc)
local timer = imgui.new.bool(ini.cfg.timer)
local activation = new.char[255](u8(ini.cfg.activation))
local theme = new.int(ini.cfg.theme)

function emulFrontendMessage(interfaceid, subid, json)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 84)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteInt8(bs, subid)
    raknetBitStreamWriteInt32(bs, #json)
    raknetBitStreamWriteString(bs, json)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

function emulToggleInterface(interfaceid, toggle)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 62)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteBool(bs, toggle)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

NotifType = {
    SUCCESS = 1,
    FAILURE = 2,
    INFO = 3
}

function showArizonaNotification(type, title, text, duration)
    type = type or NotifType.INFO
    duration = duration or 3500
    emulToggleInterface(6, true)
    emulFrontendMessage(6, 0, encodeJson({
        styleInt = type,
        title = title,
        text = text,
        duration = duration
    }))
end

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(text).x / 2)
    imgui.Text(text)
end

function papka()
    local lfs = require "lfs"
    local dir = getWorkingDirectory() .. '/ProductHelper'
    
    if not lfs.attributes(dir) then
        lfs.mkdir(dir)
    end
end

function downloadFile(url, path)
    local response = requests.get(url)

    if response.status_code == 200 then
        local filepath = path
        os.remove(filepath)
        local f = assert(io.open(filepath, 'wb'))
        f:write(response.text)
        f:close()
    else
        print('Ошибка скачивания...')
    end
end

local function numberdel(number)
    local formatted = tostring(number)
    while true do  
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", '%1.%2')
        if (k==0) then
            break
        end
    end
    return formatted
end

imgui.OnInitialize(function()
    papka()
    if ini.cfg.theme == 1 then
    SoftDarkTheme()
    end
    if ini.cfg.theme == 2 then
    SoftLightTheme()
    end
    
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 100)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 25, config, iconRanges)
    imgui.GetIO().IniFilename = nil;
   
    local savePath = getWorkingDirectory() .. '/ProductHelper/productlogo.png'
    downloadFile("https://raw.githubusercontent.com/justskitpy/image/sosal/productlogo.png", savePath)
    image = imgui.CreateTextureFromFile(savePath)
end)

local int = new.int(ini.cfg.int)
local int2 = new.int(ini.cfg.int2)
local result = 0

imgui.OnFrame(function() return menu[0] end,
	function()
	local sw, sh = getScreenResolution()
	imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.SetNextWindowSize(imgui.ImVec2(800, 550))
	imgui.Begin('okno', menu, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
	
	imgui.SetCursorPos(imgui.ImVec2(15, 30))
	imgui.SetWindowFontScale(0.65)
	if imgui.BeginChild('sosal?', imgui.ImVec2(250, 100), true) then
		imgui.Text(u8'Привет, пользователь ' .. faicons.USER)
		imgui.Text(u8'Версия: v1.0 ' .. faicons.FLOPPY_DISK)
		imgui.Text(u8'Автор скрипта: ')
		imgui.SetCursorPos(imgui.ImVec2(135, 55))
		if imgui.Button(u8'ссылка', imgui.ImVec2(80, 30)) then
		openLink('https://t.me/jskiptymods')
		end
		imgui.EndChild()
	end
	imgui.SetWindowFontScale(1)
	
	imgui.SetCursorPos(imgui.ImVec2(280, -30))
	if ini.cfg.theme == 2 then
        imgui.Image(image, imgui.ImVec2(220, 220), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), imgui.ImVec4(0, 0, 0, 1))
    end
    
	imgui.Image(image, imgui.ImVec2(220, 220))
	imgui.SetCursorPos(imgui.ImVec2(15, 150))
	if imgui.Button(u8'Главная ' .. faicons.HOUSE, imgui.ImVec2(250, 60)) then tab = 1 end
	imgui.SameLine()
	if imgui.Button(u8'Настройки ' .. faicons.GEAR, imgui.ImVec2(250, 60)) then tab = 2 end
	imgui.SameLine()
	if imgui.Button(u8'Информация ' .. faicons.CIRCLE_INFO, imgui.ImVec2(250, 60)) then tab = 3 end
	
	imgui.SetCursorPos(imgui.ImVec2(630, 30))
	if imgui.Button(u8'Закрыть ' .. faicons.CIRCLE_XMARK, imgui.ImVec2(150, 60)) then menu[0] = false end
	
	imgui.SetCursorPos(imgui.ImVec2(15, 235))
	if imgui.BeginChild('nazvanie', imgui.ImVec2(765, -1), true) then
	
	if tab == 1 then
	
	imgui.CenterText(u8'Статистика')
	
	imgui.Separator()
	
	if imgui.ToggleButton(u8'Информационное окно', infokno) then
	infookno[0] = not infookno[0]
	end
	if infookno[0] then
	
	if imgui.ToggleButton(u8'Считать заработанную сумму', zpfull) then
	ini.cfg.zpfull = zpfull[0]
	end
	
	if zpfull[0] then
                    if imgui.InputInt(u8'Цена за ларец', buffers.larecsalary, 1, 10) then
                        ini.cfg.larecsalary = buffers.larecsalary[0]
                    end
    end
                    
	if imgui.ToggleButton(u8'Считать выпавшие ларцы', larecc) then
	ini.cfg.larecc = larecc[0]
	end
	
	if imgui.ToggleButton(u8'Считать выполненные рейсы', reisi) then
	ini.cfg.reisi = reisi[0]
	end
	
	if imgui.ToggleButton(u8'Время (не серверное)', timer) then
	ini.cfg.timer = timer[0]
	end
	
	end
	
	imgui.Text('')
	
	imgui.Separator()
	
	imgui.CenterText(u8'Выгодность рейсов')
	
	imgui.Separator()
	
	if imgui.ToggleButton(u8'Рассчёт выгодности рейса', vigod) then
	end
	
	if vigod[0] then
	
	imgui.Separator()
	if imgui.InputInt(u8'Масса', int) then
	ini.cfg.int = int[0]
	save()
	end
	
	if imgui.InputInt(u8'Расстояние', int2) then
	ini.cfg.int2 = int2[0]
	save()
	end
	
	if imgui.Button(u8'Рассчитать') then
		result = (ini.cfg.int / ini.cfg.int2) * 10
	end
	
	imgui.Separator()
	
	imgui.Text(u8'Возможный процент выгодности: ' .. result)
	
	imgui.Separator()
	
	imgui.Text(u8'Если процент больше 100-200 - рейс выгоден')
	
	imgui.Separator()
	end
	
	imgui.Text('')
	
	imgui.Separator()
	
	imgui.CenterText(u8'Вспомогательные функции')
	
	imgui.Separator()
	
	if imgui.ToggleButton(u8'Пропускать лишние диалоги', skipdi) then
	imgui.OpenPopup(u8'Предупреждение!')
	skipd[0] = not skipd[0]
	end
	
	
	if imgui.ToggleButton(u8'Авто-гудок на выбор заказов', autoga) then
	imgui.OpenPopup(u8'Предупреждение!')
	autog[0] = not autog[0]
	end
	
	imgui.SetNextWindowSize(imgui.ImVec2(500, 300), imgui.Cond.FirstUseEver)
        if imgui.BeginPopupModal(u8'Предупреждение!', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
        
        imgui.CenterText(u8'Данная функция может быть запрещена')
        imgui.CenterText(u8'на многих серверах!')
        imgui.CenterText(u8'Рекомендуем отключить функцию!')
        imgui.Separator()
        if imgui.Button(u8"Отключить функцию", imgui.ImVec2(-1, 50)) then
        autog[0] = false
        skipd[0] = false
        autoga[0] = false
        skipdi[0] = false
        save()
        imgui.CloseCurrentPopup()
        end
        if imgui.Button(u8'Закрыть', imgui.ImVec2(-1, 50)) then
        imgui.CloseCurrentPopup()
        end
        
        imgui.EndPopup()
        end
        
	
	imgui.Text('')
	
	imgui.Separator()
	
	imgui.CenterText(u8'Логирование')
	
	imgui.Separator()
	
	if imgui.ToggleButton(u8'Окно с логами', oknolog) then
	LogOkno[0] = not LogOkno[0]
	end
	
	
	imgui.Text('')
	
	imgui.Separator()
	
	imgui.CenterText(u8'Сменить погоду и время')
	
	imgui.Separator()
	
	if imgui.Button(u8'Сменить', imgui.ImVec2(-1, 50)) then
	imgui.OpenPopup(u8'Смена погоды и времени')
	end
	
	imgui.SetNextWindowSize(imgui.ImVec2(500, 230), imgui.Cond.FirstUseEver)
        if imgui.BeginPopupModal(u8'Смена погоды и времени', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
        
        if imgui.Button(u8'Установить погоду') then
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

        if imgui.Button(u8'Установить время') then
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
        
        if imgui.Button(u8'Закрыть', imgui.ImVec2(-1, 50)) then
        imgui.CloseCurrentPopup()
        end
        
        imgui.EndPopup()
        end
        
        imgui.Text("")
        
        imgui.Separator()
        imgui.CenterText(u8'Калькулятор')
        imgui.Separator()
        
        if imgui.ToggleButton(u8'Калькулятор', calculator) then
        calcmenu[0] = not calcmenu[0]
        end
       
	elseif tab == 2 then
	
	imgui.CenterText(u8'Настройки')
	
	imgui.Separator()
	
	if imgui.Button(faicons('ROTATE_RIGHT') .. "", imgui.ImVec2(40 * MONET_DPI_SCALE, 40 * MONET_DPI_SCALE)) then          
                script_reload()
            end
            imgui.SameLine()
            if imgui.Button(faicons('POWER_OFF') .. "", imgui.ImVec2(40 * MONET_DPI_SCALE, 40 * MONET_DPI_SCALE)) then
                script_unload()
            end
            
            imgui.Text('')
            imgui.Separator()
            imgui.CenterText(u8'Своя активация')
            imgui.Separator()
            imgui.InputTextWithHint(u8"Активация", u8"(без слеша)", activation, 256)
	if imgui.Button(faicons('CHECK') .. u8" Сохранить") then
		ini.cfg.activation = u8:decode(str(activation))
		save()
		msg("Сохранено! Активация - /"..ini.cfg.activation)
		script_reload()
	end
		imgui.Text('')
		
		imgui.Separator()
        imgui.CenterText(u8'Тема хелпера')
        imgui.Separator()
	if imgui.RadioButtonIntPtr(u8'Тёмная тема', theme, 1) then
		SoftDarkTheme()
		ini.cfg.theme = 1
		save()
	end
	
	if imgui.RadioButtonIntPtr(u8'Белая тема', theme, 2) then
		ini.cfg.theme = 2
		SoftLightTheme()
		save()
	end
	
	elseif tab == 3 then
	
	imgui.CenterText(u8'Информация')
	
	imgui.BeginChild('scriptinfo', imgui.ImVec2(-1, -1), true)
			imgui.Text(faicons.USER .. u8' Разработчик скрипта: JustSkipty ')
			
			if imgui.Button(faicons.CIRCLE_INFO .. u8' Телеграм', imgui.ImVec2(-1, 50)) then
			openLink('https://t.me/jskiptymods')
			end
			imgui.Separator()
			imgui.Text(faicons.GLOBE .. u8' Тема на BlastHack: ')
			if imgui.Button(faicons.CLOCK .. u8' Скоро!', imgui.ImVec2(-1, 50)) then
			msg('Темы на BlastHack ещё нет, но будет!')
			end
			imgui.EndChild()
			
			imgui.CenterText(faicons.TRUCK .. ' ProductHelper')
			imgui.BeginChild('idk', imgui.ImVec2(-1, 100), true)
			imgui.CenterText(u8'Много функциональный скрипт-помощник')
			imgui.CenterText(u8'для работы Развозчика Продуктов')
	end
            
		imgui.EndChild()
		end
	
	imgui.End()
end)

imgui.OnFrame(function() return LogOkno[0] end, function(oknoochko)
    	local sw, sh = getScreenResolution()
    	local logsFiles = {}
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(600, 450))
  	  imgui.Begin(u8'oknologs', LogOkno, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
  		
  		local filter = imgui.ImGuiTextFilter()
    
    if imgui.Button(u8'Выбрать день для просмотра лога', imgui.ImVec2(430, 50)) then
        LogMenu[0] = not LogMenu[0]
    end
	
	imgui.SameLine()
	if imgui.Button(u8'Закрыть', imgui.ImVec2(130, 50)) then
	LogOkno[0] = false
	oknolog[0] = false
	end

    if Param then
        imgui.CenterText(u8'Лог за день номер: ' .. Param)
        imgui.Separator()
		
		imgui.SetWindowFontScale(0.6)
        
        local logFilePath = string.format("ProductHelper/%d.log", Param)
		
        
        local logFile = io.open(logFilePath, "r")

        if logFile then

            local logContent = logFile:read("*all")
            logFile:close()

            
            local commands = {}
            for line in logContent:gmatch("[^\r\n]+") do
                table.insert(commands, line)
            end

            
            for i, line in ipairs(commands) do
                if filter:PassFilter(u8(line)) then
                    imgui.Text(u8(line))
                end
            end
        else
            imgui.CenterText(u8"Лог за этот день не найден!")
            
        end
    end
		imgui.SetWindowFontScale(1)
		
  	imgui.End()
end)

imgui.OnFrame(function() return LogMenu[0] end, function(oknoochko)
    	local sw, sh = getScreenResolution()
    	local logsFiles = {}
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(200, -1))
  	  imgui.Begin(u8'chooselogokno', LogMenu, imgui.WindowFlags.NoTitleBar)
		
		if imgui.Button(u8"Закрыть", imgui.ImVec2(-1, 50)) then
		LogMenu[0] = false
		end
		
for i = 1, 31 do
    if imgui.Button(u8"Логи дня " .. i) then
    
        Param = i
        local filePath = getWorkingDirectory() .. "/ProductHelper/" .. i .. ".log"
        
        local openlog = io.open(filePath, 'r')
        
        if not openlog then
            print(u8"Не удалось открыть файл: " .. filePath)
            return
        end
        
        local textlog = openlog:read("*a")
        
        if not textlog or textlog == "" then
        	
            msg("Файл пустой или нет содержимого")
            openlog:close()
            return
        end
        
        commands = {textlog}
        
        openlog:close()
        LogMenu[0] = false
    end
end
		
        imgui.End()
    end)

imgui.OnFrame(function() return infookno[0] end,
	function()
	local sw, sh = getScreenResolution()
	imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.SetNextWindowSize(imgui.ImVec2(400, 300))
	imgui.Begin('pidor', infookno, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
	
			
	local zpfully = ini.cfg.zarp + ini.cfg.larec * ini.cfg.larecsalary
    if reisi[0] then imgui.CenterText(u8'Сделано рейсов: '..superbusya(ini.cfg.reic)) end
    imgui.Separator()
    if larecc[0] then imgui.CenterText(u8'Выпало ларцов: '..superbusya(ini.cfg.larec)) end   
    imgui.Separator()
    if zpfull[0] then imgui.CenterText(u8'Заработано: '..superbusya(zpfully)..'$') end
    imgui.Separator()
    if timer[0] then imgui.CenterText(os.date("%H:%M:%S")) end
    imgui.Separator()
    
    imgui.SetCursorPos(imgui.ImVec2(15, 210))
    if imgui.Button(u8'Очистить', imgui.ImVec2(-1, 70)) then
        ini.cfg.larec = 0
        ini.cfg.reic = 0
        ini.cfg.zarp = 0
        save()
    end
    
	imgui.End()
end)

imgui.OnFrame(function() return calcmenu[0] end,
	function()
	local sw, sh = getScreenResolution()
	imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.SetNextWindowSize(imgui.ImVec2(500, 510))
	imgui.Begin(u8'Калькулятор', calcmenu, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
	
	imgui.SetNextItemWidth(imgui.GetFontSize() * 17)
	        imgui.InputText(u8'##input', input, 256, imgui.InputTextFlags.ReadOnly)

            for i = 1, #buttons do
                for j = 1, #buttons[i] do
                    if imgui.Button(u8(buttons[i][j]), buttonSize) then
                        local tekyshznachenie = ffi.string(input)
                        if buttons[i][j] == "=" then
                            local func, err = load("return " .. tekyshznachenie:gsub('%.', ''))
                            if func then
                                local success, res = pcall(func)
                                if success then
                                    input = imgui.new.char[256](tostring(numberdel(res)))
                                else
                                    input = imgui.new.char[256](u8"Ошибка")
                                end
                            else
                                input = imgui.new.char[256](u8"Ошибка")
                            end
                        elseif buttons[i][j] == "C" then
                            input = imgui.new.char[256]("")
                        elseif buttons[i][j] == "X" then
                            tekyshznachenie = tekyshznachenie:sub(1, -2)
                            input = imgui.new.char[256](numberdel(tekyshznachenie:gsub('%.', '')))
                        else
                            if #tekyshznachenie < 255 then
                                tekyshznachenie = tekyshznachenie .. buttons[i][j]
                                input = imgui.new.char[256](numberdel(tekyshznachenie:gsub('%.', '')))
                            end
                        end
                    end
                    if j < #buttons[i] then imgui.SameLine() end
                end
            end
    
	imgui.End()
end)

function create_logs_for_month()
    local lfs = require("lfs")
    
    if not lfs.attributes("ProductHelper") then
        lfs.mkdir("ProductHelper")
    end
    
    for day = 1, 31 do
        local filename = string.format("%d.log", day)
        local file_path = "ProductHelper/" .. filename
        
        local file = io.open(file_path, "r")
        if not file then
            file = io.open(file_path, "w")
            if file then
                print(u8"Создан новый лог: " .. filename)
                file:close()
            else
                print(u8"Не удалось создать файл: " .. filename)
            end
        else
            file:close()
        end
    end
end

function save_log(logtext)
    local current_day = tonumber(os.date("%d"))
    
    local filename = string.format("%d.log", current_day)
    local file_path = "ProductHelper/" .. filename
    
    local file = io.open(file_path, "a")
    
    if file then
        local current_time = os.date("%Y-%m-%d %H:%M:%S")
        file:write(current_time .. " [" .. logtext .. "] \n")
        file:close()
    else
        print(u8"Ошибка при открытии файла для записи:", file_path)
    end
end

create_logs_for_month()

function ev.onShowDialog(id, style, title, button1, button2, text)
    if skipd[0] and (id == 0 and text:find("Вы успешно")) then
        sampSendDialogResponse(0, 1, 0, 0)
        return false
    end    
end

function ev.onServerMessage(color, text)
	if text:find('премия за доставку' and '- $(%d+)') then	
	local salary = text:match('премия за доставку' and '- $(%d+)')
        ini.cfg.zarp = ini.cfg.zarp + tonumber(salary)
        ini.cfg.reic = ini.cfg.reic + 1
    save_log("Рейс номер " .. ini.cfg.reic .. " окончен! Ваша зарплата: $" .. salary)
    save_log("Заработано в общем: $" .. ini.cfg.zarp)
    end
    
    if text:find("Вам был добавлен предмет 'Ларец") then	
    ini.cfg.larec = ini.cfg.larec + 1
    save_log("Вам выпал ларец, поздравляю! Ларец по счёту: " .. ini.cfg.larec)
    end
end

function superbusya(n)
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)', '%1.'):reverse())..right
end

function main()
	if not isSampfuncsLoaded() or not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
    while not sampIsLocalPlayerSpawned() do wait(0) end
    showArizonaNotification(NotifType.SUCCESS, "ProductHelper", "Хелпер Развозчика Продуктов успешно загружен! Активация - /" ..ini.cfg.activation, 3000)
    wait(3500)
    showArizonaNotification(NotifType.INFO, "ProductHelper", "Автор скрипта - @JSkiptyMods! Подпишись!", 3000)
    sampRegisterChatCommand(ini.cfg.activation, function() 
			lua_thread.create(function()
            if menu[0] then
                msg('Выключаем...')
                wait(1000)
                menu[0] = false
            else
                msg('Запускаем!')
                wait(1000)
                menu[0] = true
            end
        end)
    end)
    
    while true do
	wait(0)
	
	local SPECIAL_KEYS = {
    Y = 1,
    N = 2,
    H = 3
}
		
		if autog[0] and isCharInAnyCar(PLAYER_PED) then
            for id = 0, 2048 do
                local result = sampIs3dTextDefined(id)
                if result then
                    local text, color, posX, posY, posZ, distance, ignoreWalls, playerId, vehicleId = sampGet3dTextInfoById(id)
                    local xf, yf, zf = getCharCoordinates(PLAYER_PED)
                    local dist = getDistanceBetweenCoords3d(xf, yf, zf, posX, posY, posZ)
                    if text:find('Загрузка товаров') then
                        if dist < 5 then
    local dataa = samp_create_sync_data(isCharOnFoot(PLAYER_PED) and 'player' or 'vehicle')
    local x, y, z = getCharCoordinates(PLAYER_PED)

    wait(2)
    dataa.specialKey = isCharOnFoot(PLAYER_PED) and SPECIAL_KEYS.H or dataa.specialKey
    dataa.keysData = isCharOnFoot(PLAYER_PED) and dataa.keysData or 2
    dataa.position = { x, y, z }
    dataa.send()
end
end
end
end
end
end
end

function samp_create_sync_data(sync_type, copy_from_player)
    local ffi = require 'ffi'
    local sampfuncs = require 'sampfuncs'
    local raknet = require 'samp.raknet'
    require 'samp.synchronization'

    copy_from_player = copy_from_player or true
    local sync_traits = {
        player = { 'PlayerSyncData', raknet.PACKET.PLAYER_SYNC, sampStorePlayerOnfootData },
        vehicle = { 'VehicleSyncData', raknet.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData },
        passenger = { 'PassengerSyncData', raknet.PACKET.PASSENGER_SYNC, sampStorePlayerPassengerData },
        aim = { 'AimSyncData', raknet.PACKET.AIM_SYNC, sampStorePlayerAimData },
        trailer = { 'TrailerSyncData', raknet.PACKET.TRAILER_SYNC, nil },
        unoccupied = { 'UnoccupiedSyncData', raknet.PACKET.UNOCCUPIED_SYNC, nil },
        bullet = { 'BulletSyncData', raknet.PACKET.BULLET_SYNC, nil },
        spectator = { 'SpectatorSyncData', raknet.PACKET.SPECTATOR_SYNC, nil }
    }
    local sync_info = sync_traits[sync_type]
    local data_type = 'struct ' .. sync_info[1]
    local data = ffi.new(data_type, {})
    local raw_data_ptr = tonumber(ffi.cast('uintptr_t', ffi.new(data_type .. '*', data)))

    if copy_from_player then
        local copy_func = sync_info[3]
        if copy_func then
            local _, player_id
            if copy_from_player == true then
                _, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            else
                player_id = tonumber(copy_from_player)
            end
            copy_func(player_id, raw_data_ptr)
        end
    end

    local func_send = function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, sync_info[2])
        raknetBitStreamWriteBuffer(bs, raw_data_ptr, ffi.sizeof(data))
        raknetSendBitStreamEx(bs, sampfuncs.HIGH_PRIORITY, sampfuncs.UNRELIABLE_SEQUENCED, 1)
        raknetDeleteBitStream(bs)
    end

    local mt = {
        __index = function(t, index)
            return data[index]
        end,
        __newindex = function(t, index, value)
            data[index] = value
        end
    }
    return setmetatable({ send = func_send }, mt)
end

function isMonetLoader() return MONET_VERSION ~= nil end
if isMonetLoader() then
gta = ffi.load('GTASA') 
ffi.cdef[[
    void _Z12AND_OpenLinkPKc(const char* link);
]] end

function openLink(link)
    gta._Z12AND_OpenLinkPKc(link)
end

function imgui.ToggleButton(str_id, bool)
    local rBool = false

    if LastActiveTime == nil then
        LastActiveTime = {}
    end
    if LastActive == nil then
        LastActive = {}
    end

    local function ImSaturate(f)
        return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
    end

    local p = imgui.GetCursorScreenPos()
    local dl = imgui.GetWindowDrawList()

    local height = imgui.GetTextLineHeightWithSpacing()
    local width = height * 1.70
    local radius = height * 0.50
    local ANIM_SPEED = type == 2 and 0.10 or 0.15
    local butPos = imgui.GetCursorPos()

    if imgui.InvisibleButton(str_id, imgui.ImVec2(width, height)) then
        bool[0] = not bool[0]
        rBool = true
        LastActiveTime[tostring(str_id)] = os.clock()
        LastActive[tostring(str_id)] = true
    end

    imgui.SetCursorPos(imgui.ImVec2(butPos.x + width + 8, butPos.y + 2.5))
    imgui.Text( str_id:gsub('##.+', '') )

    local t = bool[0] and 1.0 or 0.0

    if LastActive[tostring(str_id)] then
        local time = os.clock() - LastActiveTime[tostring(str_id)]
        if time <= ANIM_SPEED then
            local t_anim = ImSaturate(time / ANIM_SPEED)
            t = bool[0] and t_anim or 1.0 - t_anim
        else
            LastActive[tostring(str_id)] = false
        end
    end

    local col_circle = bool[0] and imgui.ColorConvertFloat4ToU32(imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.ButtonActive])) or imgui.ColorConvertFloat4ToU32(imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.TextDisabled]))
    dl:AddRectFilled(p, imgui.ImVec2(p.x + width, p.y + height), imgui.ColorConvertFloat4ToU32(imgui.GetStyle().Colors[imgui.Col.FrameBg]), height * 0.5)
    dl:AddCircleFilled(imgui.ImVec2(p.x + radius + t * (width - radius * 2.0), p.y + radius), radius - 1.5, col_circle)
    return rBool
end

function script_unload()
lua_thread.create(function()
msg("Скрипт будет отключен через 3 секунды!")
wait(1000)
msg("1...")
wait(1000)
msg("2...")
wait(1000)
msg("3...")
wait(200)
msg("Отключение...")
wait(500)
thisScript():unload()
end)
end

function script_reload()
lua_thread.create(function()
msg("Скрипт будет перезагружен через 3 секунды!")
wait(1000)
msg("1...")
wait(1000)
msg("2...")
wait(1000)
msg("3...")
wait(200)
msg("Перезагрузка...")
wait(500)
thisScript():reload()
end)
end

function msg(text)
    sampAddChatMessage("[ProductHelper]: {FFFFFF}" .. text, 0x808080)
end

function SoftDarkTheme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
  
    style.WindowPadding = imgui.ImVec2(15, 15)
    style.WindowRounding = 20.0
    style.ChildRounding = 20.0
    style.FramePadding = imgui.ImVec2(8, 7)
    style.FrameRounding = 20.0
    style.ItemSpacing = imgui.ImVec2(8, 8)
    style.ItemInnerSpacing = imgui.ImVec2(10, 6)
    style.IndentSpacing = 25.0
    style.ScrollbarSize = 30.0
    style.ScrollbarRounding = 20.0
    style.GrabMinSize = 10.0
    style.GrabRounding = 6.0
    style.PopupRounding = 20
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    style.Colors[imgui.Col.Text]                   = imgui.ImVec4(0.90, 0.90, 0.93, 1.00)
    style.Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    style.Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.18, 0.20, 0.22, 0.30)
    style.Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.13, 0.13, 0.15, 1.00)
    style.Colors[imgui.Col.Border]                 = imgui.ImVec4(0.30, 0.30, 0.35, 1.00)
    style.Colors[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    style.Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.18, 0.18, 0.20, 1.00)
    style.Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.25, 0.25, 0.28, 1.00)
    style.Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.TitleBg]                = imgui.ImVec4(0.15, 0.15, 0.17, 1.00)
    style.Colors[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.10, 0.10, 0.12, 1.00)
    style.Colors[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.15, 0.15, 0.17, 1.00)
    style.Colors[imgui.Col.MenuBarBg]              = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    style.Colors[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    style.Colors[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.30, 0.30, 0.35, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.50, 0.50, 0.55, 1.00)
    style.Colors[imgui.Col.CheckMark]              = imgui.ImVec4(0.70, 0.70, 0.90, 1.00)
    style.Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.70, 0.70, 0.90, 1.00)
    style.Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.80, 0.80, 0.90, 1.00)
    style.Colors[imgui.Col.Button]                 = imgui.ImVec4(0.18, 0.18, 0.20, 1.00)
    style.Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.60, 0.60, 0.90, 1.00)
    style.Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.60, 0.60, 0.90, 1.00)
    style.Colors[imgui.Col.Header]                 = imgui.ImVec4(0.20, 0.20, 0.23, 1.00)
    style.Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.25, 0.25, 0.28, 1.00)
    style.Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.Separator]              = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.50, 0.50, 0.55, 1.00)
    style.Colors[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.60, 0.60, 0.65, 1.00)
    style.Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(0.20, 0.20, 0.23, 1.00)
    style.Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(0.25, 0.25, 0.28, 1.00)
    style.Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.PlotLines]              = imgui.ImVec4(0.61, 0.61, 0.64, 1.00)
    style.Colors[imgui.Col.PlotLinesHovered]       = imgui.ImVec4(0.70, 0.70, 0.75, 1.00)
    style.Colors[imgui.Col.PlotHistogram]          = imgui.ImVec4(0.61, 0.61, 0.64, 1.00)
    style.Colors[imgui.Col.PlotHistogramHovered]   = imgui.ImVec4(0.70, 0.70, 0.75, 1.00)
    style.Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.10, 0.10, 0.12, 0.80)
    style.Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.18, 0.20, 0.22, 1.00)
    style.Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.60, 0.60, 0.90, 1.00)
    style.Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.28, 0.56, 0.96, 1.00)
end

function SoftLightTheme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()

    style.WindowPadding = imgui.ImVec2(15, 15)
    style.WindowRounding = 20.0
    style.ChildRounding = 20.0
    style.FramePadding = imgui.ImVec2(8, 7)
    style.FrameRounding = 20.0
    style.ItemSpacing = imgui.ImVec2(8, 8)
    style.ItemInnerSpacing = imgui.ImVec2(10, 6)
    style.IndentSpacing = 25.0
    style.ScrollbarSize = 30.0
    style.ScrollbarRounding = 20.0
    style.GrabMinSize = 10.0
    style.GrabRounding = 6.0
    style.PopupRounding = 20
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    style.Colors[imgui.Col.Text]                   = imgui.ImVec4(0.10, 0.10, 0.10, 1.00)
    style.Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.60, 0.60, 0.60, 1.00)
    style.Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.95, 0.95, 0.90, 1.00)
    style.Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.90, 0.90, 0.85, 1.00)
    style.Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.95, 0.90, 0.85, 1.00)
    style.Colors[imgui.Col.Border]                 = imgui.ImVec4(0.80, 0.70, 0.60, 1.00)

    style.Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.95, 0.80, 0.70, 1.00)
    style.Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.98, 0.85, 0.75, 1.00)
    style.Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.90, 0.75, 0.60, 1.00)

    style.Colors[imgui.Col.Button]                 = imgui.ImVec4(0.95, 0.80, 0.70, 1.00)
    style.Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.98, 0.85, 0.75, 1.00)
    style.Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.90, 0.75, 0.60, 1.00)

    style.Colors[imgui.Col.CheckMark]              = imgui.ImVec4(0.85, 0.60, 0.35, 1.00)
    style.Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.85, 0.60, 0.35, 1.00)
    style.Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.95, 0.70, 0.45, 1.00)

    style.Colors[imgui.Col.Header]                 = imgui.ImVec4(0.95, 0.80, 0.70, 1.00)
    style.Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.98, 0.85, 0.75, 1.00)
    style.Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.90, 0.75, 0.60, 1.00)

    style.Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.90, 0.75, 0.60, 1.00)
    style.Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.98, 0.85, 0.75, 1.00)
    style.Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.95, 0.80, 0.70, 1.00)

    style.Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(0.85, 0.60, 0.35, 1.00)
    style.Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(0.95, 0.70, 0.45, 1.00)
    style.Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(0.90, 0.75, 0.60, 1.00)

    style.Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(0.95, 0.80, 0.70, 1.00)
end