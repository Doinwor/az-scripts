-- скрипт создан @justluaarz, подпишись!
-- скрипт создан @justluaarz, подпишись!
-- скрипт создан @justluaarz, подпишись!
-- скрипт создан @justluaarz, подпишись!
-- скрипт создан @justluaarz, подпишись!

local sampev = require "samp.events"
local imgui = require 'mimgui'
local encoding = require 'encoding'
local requests = require "requests"
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local new = imgui.new
local lfs = require 'lfs'
local ffi = require("ffi")
local str = ffi.string
local MDS = MONET_DPI_SCALE
local faicons = require 'fAwesome6'
local lfs = require 'lfs'
local requests = require 'requests'

script_name("SCHelper")
script_description (u8"Команда для активации: /sch. SCHelper - SecondHand Helper. Многофункциональный скрипт для ловли одежды Секонд-Хенда")
script_author("TG: @justluaarz")
script_version("1.0")

function ensureFolderExists(path)
    local attr = lfs.attributes(path)
    if not attr then
        lfs.mkdir(path)
    end
end

local folder = getWorkingDirectory() .. '/SCHelper 2.0'
ensureFolderExists(folder)

local configPath = folder .. '/SCHelper.ini'

local inicfg = require 'inicfg'

local f = io.open(configPath, "r")
if f then 
    f:close()
else
    f = io.open(configPath, "w")
    f:write("") 
    f:close()
end

local ini = inicfg.load({
    cfg = {
        odejd = 0,
        odejdsalary = 0,
        activation = 'sch',
        themeindex = 0,
        tracerindex = 0,
        tracer = 8,
    }
}, configPath)

inicfg.save(ini, configPath)

local InfBar = new.bool()
local infbarchik = new.bool(false)
local clothwh = new.bool(false)
local status = new.bool(false)
local autodial = new.bool(false)
local menu = new.bool(false)
local AutoTakeClothes = new.bool(false)
local ClickDelay = { v = 200 }
local txd = {}
local colodejd = new.bool(false)
local zpfull = new.bool(false)
local activation = new.char[255](u8(ini.cfg.activation))
local themeIndex = new.int(ini.cfg.themeindex)
local tracerIndex = new.int(ini.cfg.tracerIndex or 0)
local tracerWidth = new.int(ini.cfg.tracer)

function downloadFile(url, path)
    local folder = path:match("^(.*)/[^/]+$")
    if folder then ensureFolderExists(folder) end

    local response = requests.get(url)
    if response.status_code == 200 then
        os.remove(path)
        local f = assert(io.open(path, 'wb'))
        f:write(response.text)
        f:close()
    else
        print("Ошибка скачивания файла: " .. tostring(url))
    end
end


local buffers = {
    odejdsalary = new.int(ini.cfg.odejdsalary)
}

imgui.OnInitialize(function()
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 100)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('regular'), 25, config, iconRanges)
    imgui.GetIO().IniFilename = nil;
    
    local folder = getWorkingDirectory() .. '/SCHelper 2.0'
    ensureFolderExists(folder)

    local logoPath = folder .. '/schelperlogo.png'

    if not doesFileExist(logoPath) then
        downloadFile("https://raw.githubusercontent.com/justskitpy/image/refs/heads/main/schelperlogo.png", logoPath)
    end

    image = imgui.CreateTextureFromFile(logoPath)
		
	if ini.cfg.themeindex == 0 then
		theme_dark()
	else
		theme_light()
	end
	
end)

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(text).x / 2)
    imgui.Text(text)
end

function save()
	local folder = getWorkingDirectory() .. '/SCHelper 2.0'
	inicfg.save(ini, folder .. '/SCHelper.ini')
end

local buffers = {
    odejdsalary = new.int(ini.cfg.odejdsalary),
    }

-- скрипт создан @justluaarz
-- скрипт создан @justluaarz
-- скрипт создан @justluaarz
-- скрипт создан @justluaarz
-- скрипт создан @justluaarz

imgui.OnFrame(
    function()
        return menu[0]
    end,
    function(pidor)
        local sw, sh = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(650, 500))
        imgui.Begin(u8'SCHelper 2.0 by @justluaarz', menu, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
		
		imgui.SetCursorPos(imgui.ImVec2(15, 45))
        imgui.Image(image, imgui.ImVec2(175, 175))
        
		imgui.SetCursorPos(imgui.ImVec2(10, 230))
        
        if imgui.Button(u8'Главная', imgui.ImVec2(181, 80)) then tab = 1 end
        if imgui.Button(u8'Настройки', imgui.ImVec2(181, 80)) then tab = 2 end
        if imgui.Button(u8'Информация', imgui.ImVec2(181, 80)) then tab = 3 end
        
        imgui.SetCursorPos(imgui.ImVec2(200, 50))

        if imgui.BeginChild('nazvanie', imgui.ImVec2(-1, -1), true) then
        imgui.SetCursorPos(imgui.ImVec2(5, 10))
		
            if tab == 1 then 
            
        imgui.Separator()
        imgui.CenterText(faicons.HOUSE .. u8' Главная')
        imgui.Separator()
		
		if imgui.Checkbox(u8"Вх на одежду", clothwh) then
            if clothwh[0] then
                msg("Вх на одежду включен", -1)
            else
                msg("Вх на одежду выключен", -1)
            end
        end

        if imgui.Checkbox(u8"Скип диалогов", autodial) then
            if autodial[0] then
                msg("Скип диалогов включен", -1)
            else
                msg("Скип диалогов выключен", -1)
            end
        end

        if imgui.Checkbox(u8"Авто-ALT", status) then
            if status[0] then
                msg("Авто-ALT включен", -1)
            else
                msg("Авто-ALT выключен", -1)
            end
        end
        
        if imgui.Checkbox(u8"Авто-выбор грязной одежды", AutoTakeClothes) then
    		if AutoTakeClothes[0] then
 		       msg("Авто-выбор грязной одежды включен", -1)
 		   else
     	   	msg("Авто-выбор грязной одежды выключен", -1)
  	 	 end
		end
	
		if imgui.Checkbox(u8'Информационное окно', infbarchik) then
                    InfBar[0] = not InfBar[0]              
        end                    
		
		if imgui.Checkbox(u8'Считать кол-во одежды', colodejd) then
 		   if colodejd[0] then
      		  msg("Подсчёт одежды включён", -1)
  		  else
   		     msg("Подсчёт одежды выключен", -1)
  		  end
		end
               
               if imgui.Checkbox(u8'Подсчёт прибыли', zpfull) then 
                    if zpfull[0] then 
                 	   msg("Подсчёт прибыли включён", -1)
  		 		 else
   		   		  msg("Подсчёт прибыли выключен", -1)
  				  end
                end
                
                if zpfull[0] then
                
                imgui.SetNextItemWidth(imgui.GetFontSize() * 7)
                    if imgui.InputInt(u8'Цена за одежду', buffers.odejdsalary, 1, 10) then
                        ini.cfg.odejdsalary = buffers.odejdsalary[0]
                        save() 
                    end
                end
                
		elseif tab == 2 then 
		
			imgui.CenterText(faicons.GEAR .. u8' Настройки')
           imgui.Separator()
                if imgui.Button(faicons('ROTATE_RIGHT') .. "", imgui.ImVec2(40 * MONET_DPI_SCALE, 40 * MONET_DPI_SCALE)) then          
                script_reload()
            end
            imgui.SameLine()
            if imgui.Button(faicons('POWER_OFF') .. "", imgui.ImVec2(40 * MONET_DPI_SCALE, 40 * MONET_DPI_SCALE)) then
                script_unload()
            end
            
                       imgui.Separator()
           			imgui.CenterText(faicons.TERMINAL .. u8' Активация')
          			 imgui.Separator()
           
            imgui.SetNextItemWidth(imgui.GetFontSize() * 10)
            
            imgui.InputTextWithHint(u8"Активация", u8"(без слеша)", activation, 256)
	if imgui.Button(faicons('CHECK') .. u8" Сохранить") then
		ini.cfg.activation = u8:decode(str(activation))
		save()
		msg("Сохранено! Активация - /"..ini.cfg.activation)
		script_reload()
	end

    if imgui.RadioButtonIntPtr(u8"Тёмная тема", themeIndex, 0) then
        theme_dark()
        ini.cfg.themeindex = 0
        save()
    end
	imgui.SameLine()
    if imgui.RadioButtonIntPtr(u8"Светлая тема", themeIndex, 1) then
        theme_light()
        ini.cfg.themeindex = 1
        save()
  		  end
  
  imgui.CenterText(u8'Настройки трейсера')
	  imgui.SetNextItemWidth(imgui.GetFontSize() * 7)
		if imgui.SliderInt(u8"Ширина трейсера", tracerWidth, 0, 15) then
		    ini.cfg.tracer = tracerWidth[0] 
		    save()
		end
		
		if imgui.RadioButtonIntPtr(u8"Зелёный", tracerIndex, 0) then
  		  ini.cfg.tracerIndex = 0
   		 save()
		end
			imgui.SameLine()
		if imgui.RadioButtonIntPtr(u8"Синий", tracerIndex, 1) then
  		  ini.cfg.tracerIndex = 1
   		 save()
		end
			imgui.SameLine()
		if imgui.RadioButtonIntPtr(u8"Белый", tracerIndex, 2) then
  		  ini.cfg.tracerIndex = 2
   		 save()
		end

		elseif tab == 3 then 
			
			imgui.Separator()
           			imgui.CenterText(faicons.USERS .. u8' Добро пожаловать ' .. faicons.USERS)
            imgui.Separator()
          	
          imgui.Text(u8"Автор скрипта: TG @justluaarz", -1)
          imgui.Text(u8"За использование этого скрипта ...", -1)
          imgui.CenterText(u8".. Вы можете получить БЛОКИРОВКУ")
          imgui.CenterText(u8"за ЭТО я уже НЕ ручаюсь")
          imgui.Separator()
          if imgui.Button(faicons.CIRCLE_INFO .. u8' Телеграм', imgui.ImVec2(-1, 50)) then
			openLink('https://t.me/justluaarz')
			end
			
					imgui.CenterText(faicons.SHIRT .. ' SCHelper 2.0')
			imgui.BeginChild('dbh', imgui.ImVec2(550, 110), true)
			imgui.Text('    SCHelper - SecondHand Helper')
			imgui.Text(u8'Многофункциональный скрипт для ..')
			imgui.Text(u8'.. ловли одежды Секонд-Хенда')
			
			imgui.EndChild()
			end
		end

        imgui.End()
    end
)

function superbusya(n)
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)', '%1.'):reverse())..right
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if autodial[0] and id == 15338 then
        sampSendDialogResponse(id, 1, 0, "")
        return false
    end
    if autodial[0] and id == 0 then
        sampSendDialogResponse(id, 1, 0, "")
        return false
    end
end

function sampev.onServerMessage(color, text)
    if colodejd[0] then
        if text:match("Вы купили одежду из") then
            txd = {}
            ini.cfg.odejd = ini.cfg.odejd + 1
        end
    end
end

-- скрипт создан @justluaarz
-- скрипт создан @justluaarz
-- скрипт создан @justluaarz
-- скрипт создан @justluaarz
-- скрипт создан @justluaarz

function main()
        if not isSampfuncsLoaded() or not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
    while not sampIsLocalPlayerSpawned() do wait(0) end
    msg('Привет, пользователь')
    wait(0)
    msg('Хелпер на Секонд-Хенд успешно загружен! Активация - /' ..ini.cfg.activation)
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
    
    msg('Автор скрипта - TG @justluaarz')

    lua_thread.create(clotheswh)

    while true do
        wait(450)
        if status[0] then
            local x, y, z = getCharCoordinates(PLAYER_PED)
            local result = Search3Dtext(x, y, z, 3, "Одежда из секонд")
            if result then
                sendAlt()
                wait(300)
                sendAlt()
            end
        end
    end
end

function sendAlt()
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, 8)
    raknetBitStreamWriteInt32(bs, 7)
    raknetBitStreamWriteInt32(bs, -1)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteString(bs, "")
    raknetSendBitStreamEx(bs, 1, 7, 1)
    raknetDeleteBitStream(bs)
end

function Search3Dtext(x, y, z, radius, patern)
    for id = 0, 2048 do
        if sampIs3dTextDefined(id) then
            local text2, _, posX2, posY2, posZ2 = sampGet3dTextInfoById(id)
            if getDistanceBetweenCoords3d(x, y, z, posX2, posY2, posZ2) < radius then
                if string.match(text2, patern) then
                    return true
                end
            end
        end
    end
    return false
end

local objs = {
    [2401] = "ODEJDA",
    [2402] = "ODEJDA",
    [2403] = "ODEJDA",
    [2404] = "ODEJDA",
    [2405] = "ODEJDA",
    [2406] = "ODEJDA",
}

local objs = {
    [2401] = true,
    [2402] = true,
    [2403] = true,
    [2404] = true,
    [2405] = true,
    [2406] = true,
}

function clotheswh()
    local font = renderCreateFont("Arial", 16, 5)
    while true do
        wait(0)
        if clothwh[0] then
            local px, py, pz = getCharCoordinates(PLAYER_PED)
            local psx, psy = convert3DCoordsToScreen(px, py, pz)
            
            for _, obj in pairs(getAllObjects()) do
                if isObjectOnScreen(obj) then
                    local model = getObjectModel(obj)
                    if objs[model] then
                        local x, y, z = getCharCoordinates(PLAYER_PED)
                        local success, ox, oy, oz = getObjectCoordinates(obj)
                        if success then
                            local dist = math.floor(getDistanceBetweenCoords3d(x, y, z, ox, oy, oz))
                            if dist < 60 then
                                local sx, sy = convert3DCoordsToScreen(ox, oy, oz)
                                if sx and sy and psx and psy then
                                    local colortracer = 0xFF00FF00
                                    if tracerIndex[0] == 1 then
                                        colortracer = 0xFF0000FF
                                    elseif tracerIndex[0] == 2 then
                                        colortracer = 0xFFFFFFFF
                                    end
                                    
                                    renderDrawLine(psx, psy, sx, sy, tracerWidth[0], colortracer)
                                    renderFontDrawText(font, "{FFFFFF}Одежда из секонд-хенда | " .. dist .. "м", sx, sy, -1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function sampev.onShowTextDraw(id, data)
    if AutoTakeClothes[0] then
        if data.modelId == 2845 or data.modelId == 2844 or data.modelId == 2846 then
            table.insert(txd, id)
        end
    end
end

lua_thread.create(function()
    while true do
        wait(100)
        if AutoTakeClothes[0] and #txd > 0 then
            for i, v in ipairs(txd) do
                sampSendClickTextdraw(v)
                wait(ClickDelay.v)
            end
            txd = {}
        end
    end
end)

imgui.OnFrame(function() return InfBar[0] end, function(pidor)
	local sw, sh = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(300, 200), imgui.Cond.FirstUseEver)
	local kaka = imgui.WindowFlags.NoTitleBar
    kaka = kaka + imgui.WindowFlags.NoResize
    
    imgui.Begin('loxlox', InfBar, kaka)
    
    local zpfully = ini.cfg.odejd * ini.cfg.odejdsalary

    if colodejd[0] then imgui.CenterText(u8'Собрано одежды: '..superbusya(ini.cfg.odejd)) end
    if zpfull[0] then imgui.CenterText(u8'Получите: '..superbusya(zpfully)..'$') end
    
    imgui.SetCursorPos(imgui.ImVec2(6, 145))
    save()
    if imgui.Button(u8'Очистить', imgui.ImVec2(-1, 50)) then
        ini.cfg.odejd = 0
        save()
    end
    imgui.End()
end)

function msg(text)
    sampAddChatMessage("{BFBFBF}[SCHelper]{FFFFFF} " .. text, -1)
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

local fontSide = renderCreateFont("Arial", 18, 5)
local sideStatus = new.bool(true)

function drawSideStatus()
    if sideStatus[0] then
        local sw, sh = getScreenResolution()
        local x = 10
        local y = sh / 2 - 30

        local isAnyOn = clothwh[0] or autodial[0] or status[0] or AutoTakeClothes[0]

        renderFontDrawText(fontSide, "SCHelper 2.0", x, y, 0xFFFFFFFF)
        local statusText = isAnyOn and "Status: On" or "Status: Off"
        local color = isAnyOn and 0xFF00FF00 or 0xFFFF0000
        renderFontDrawText(fontSide, statusText, x, y + 35, color)
    end
end

lua_thread.create(function()
    while true do
        wait(0)
        drawSideStatus()
    end
end)

function isMonetLoader() return MONET_VERSION ~= nil end
if isMonetLoader() then
gta = ffi.load('GTASA') 
ffi.cdef[[
    void _Z12AND_OpenLinkPKc(const char* link);
]] end

function openLink(link)
    gta._Z12AND_OpenLinkPKc(link)
end

function theme_dark()

    local style  = imgui.GetStyle()
    local colors = style.Colors
    local clr    = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2
  
    style.WindowRounding         = 4.0
    style.WindowTitleAlign       = ImVec2(0.5, 0.5)
    style.FrameRounding          = 4.0
    style.ItemSpacing            = ImVec2(10, 5)
    style.ScrollbarSize          = 15
    style.ScrollbarRounding      = 0
    style.GrabMinSize            = 9.6
    style.GrabRounding           = 1.0
    style.WindowPadding          = ImVec2(10, 10)
    style.AntiAliasedLines       = true
    style.FramePadding           = ImVec2(5, 4)
    style.DisplayWindowPadding   = ImVec2(27, 27)
    style.DisplaySafeAreaPadding = ImVec2(5, 5)
    style.ButtonTextAlign        = ImVec2(0.5, 0.5)
    style.IndentSpacing          = 12.0
    style.Alpha                  = 1.0
  
      colors[clr.Text]                 = ImVec4(1.00, 1.00, 1.00, 1.00)
      colors[clr.TextDisabled]         = ImVec4(0.50, 0.50, 0.50, 1.00)
      colors[clr.WindowBg]             = ImVec4(0.06, 0.06, 0.06, 0.94)
      colors[clr.PopupBg]              = ImVec4(0.08, 0.08, 0.08, 0.94)
      colors[clr.Border]               = ImVec4(0.43, 0.43, 0.50, 0.50)
      colors[clr.BorderShadow]         = ImVec4(0.00, 0.00, 0.00, 0.00)
      colors[clr.FrameBg]              = ImVec4(0.44, 0.44, 0.44, 0.60)
      colors[clr.FrameBgHovered]       = ImVec4(0.57, 0.57, 0.57, 0.70)
      colors[clr.FrameBgActive]        = ImVec4(0.76, 0.76, 0.76, 0.80)
      colors[clr.TitleBg]              = ImVec4(0.04, 0.04, 0.04, 1.00)
      colors[clr.TitleBgActive]        = ImVec4(0.16, 0.16, 0.16, 1.00)
      colors[clr.TitleBgCollapsed]     = ImVec4(0.00, 0.00, 0.00, 0.60)
      colors[clr.MenuBarBg]            = ImVec4(0.14, 0.14, 0.14, 1.00)
      colors[clr.ScrollbarBg]          = ImVec4(0.02, 0.02, 0.02, 0.53)
      colors[clr.ScrollbarGrab]        = ImVec4(0.31, 0.31, 0.31, 1.00)
      colors[clr.ScrollbarGrabHovered] = ImVec4(0.41, 0.41, 0.41, 1.00)
      colors[clr.ScrollbarGrabActive]  = ImVec4(0.51, 0.51, 0.51, 1.00)
      colors[clr.CheckMark]            = ImVec4(0.13, 0.75, 0.55, 0.80)
      colors[clr.SliderGrab]           = ImVec4(0.13, 0.75, 0.75, 0.80)
      colors[clr.SliderGrabActive]     = ImVec4(0.13, 0.75, 1.00, 0.80)
      colors[clr.Button]               = ImVec4(0.13, 0.75, 0.55, 0.40)
      colors[clr.ButtonHovered]        = ImVec4(0.13, 0.75, 0.75, 0.60)
      colors[clr.ButtonActive]         = ImVec4(0.13, 0.75, 1.00, 0.80)
      colors[clr.Header]               = ImVec4(0.13, 0.75, 0.55, 0.40)
      colors[clr.HeaderHovered]        = ImVec4(0.13, 0.75, 0.75, 0.60)
      colors[clr.HeaderActive]         = ImVec4(0.13, 0.75, 1.00, 0.80)
      colors[clr.Separator]            = ImVec4(0.13, 0.75, 0.55, 0.40)
      colors[clr.SeparatorHovered]     = ImVec4(0.13, 0.75, 0.75, 0.60)
      colors[clr.SeparatorActive]      = ImVec4(0.13, 0.75, 1.00, 0.80)
      colors[clr.ResizeGrip]           = ImVec4(0.13, 0.75, 0.55, 0.40)
      colors[clr.ResizeGripHovered]    = ImVec4(0.13, 0.75, 0.75, 0.60)
      colors[clr.ResizeGripActive]     = ImVec4(0.13, 0.75, 1.00, 0.80)
      colors[clr.PlotLines]            = ImVec4(0.61, 0.61, 0.61, 1.00)
      colors[clr.PlotLinesHovered]     = ImVec4(1.00, 0.43, 0.35, 1.00)
      colors[clr.PlotHistogram]        = ImVec4(0.90, 0.70, 0.00, 1.00)
      colors[clr.PlotHistogramHovered] = ImVec4(1.00, 0.60, 0.00, 1.00)
      colors[clr.TextSelectedBg]       = ImVec4(0.26, 0.59, 0.98, 0.35)
      end

function theme_light()

    local style  = imgui.GetStyle()
    local colors = style.Colors
    local clr    = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2
  
    style.WindowRounding         = 4.0
    style.WindowTitleAlign       = ImVec2(0.5, 0.5)
    style.FrameRounding          = 4.0
    style.ItemSpacing            = ImVec2(10, 5)
    style.ScrollbarSize          = 15
    style.ScrollbarRounding      = 0
    style.GrabMinSize            = 9.6
    style.GrabRounding           = 1.0
    style.WindowPadding          = ImVec2(10, 10)
    style.AntiAliasedLines       = true
    style.FramePadding           = ImVec2(5, 4)
    style.DisplayWindowPadding   = ImVec2(27, 27)
    style.DisplaySafeAreaPadding = ImVec2(5, 5)
    style.ButtonTextAlign        = ImVec2(0.5, 0.5)
    style.IndentSpacing          = 12.0
    style.Alpha                  = 0.9

    colors[clr.Text]                 = ImVec4(0.05, 0.05, 0.05, 1.00)
    colors[clr.TextDisabled]         = ImVec4(0.60, 0.60, 0.60, 1.00)
    colors[clr.WindowBg]             = ImVec4(0.96, 0.96, 0.96, 1.00)
    colors[clr.PopupBg]              = ImVec4(0.97, 0.97, 0.97, 1.00)
    colors[clr.Border]               = ImVec4(0.70, 0.70, 0.70, 0.60)
    colors[clr.BorderShadow]         = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.FrameBg]              = ImVec4(0.13, 0.75, 0.55, 0.30)
    colors[clr.FrameBgHovered]       = ImVec4(0.13, 0.75, 0.55, 0.30)
    colors[clr.FrameBgActive]        = ImVec4(0.13, 0.75, 0.55, 0.30)
    colors[clr.TitleBg]              = ImVec4(0.88, 0.88, 0.88, 1.00)
    colors[clr.TitleBgActive]        = ImVec4(0.80, 0.80, 0.80, 1.00)
    colors[clr.TitleBgCollapsed]     = ImVec4(0.93, 0.93, 0.93, 0.60)
    colors[clr.MenuBarBg]            = ImVec4(0.92, 0.92, 0.92, 1.00)
    colors[clr.ScrollbarBg]          = ImVec4(0.96, 0.96, 0.96, 0.53)
    colors[clr.ScrollbarGrab]        = ImVec4(0.75, 0.75, 0.75, 1.00)
    colors[clr.ScrollbarGrabHovered] = ImVec4(0.65, 0.65, 0.65, 1.00)
    colors[clr.ScrollbarGrabActive]  = ImVec4(0.55, 0.55, 0.55, 1.00)
    colors[clr.CheckMark]            = ImVec4(0.13, 0.75, 0.55, 1.00)
    colors[clr.SliderGrab]           = ImVec4(0.13, 0.75, 0.55, 0.80)
    colors[clr.SliderGrabActive]     = ImVec4(0.13, 0.75, 1.00, 0.80)
    colors[clr.Button]               = ImVec4(0.13, 0.75, 0.55, 0.30)
    colors[clr.ButtonHovered]        = ImVec4(0.13, 0.75, 0.55, 0.45)
    colors[clr.ButtonActive]         = ImVec4(0.13, 0.75, 0.55, 0.70)
    colors[clr.Header]               = ImVec4(0.13, 0.75, 0.55, 0.35)
    colors[clr.HeaderHovered]        = ImVec4(0.13, 0.75, 0.55, 0.55)
    colors[clr.HeaderActive]         = ImVec4(0.13, 0.75, 0.55, 0.75)
    colors[clr.Separator]            = ImVec4(0.80, 0.80, 0.80, 0.65)
    colors[clr.SeparatorHovered]     = ImVec4(0.13, 0.75, 0.75, 0.60)
    colors[clr.SeparatorActive]      = ImVec4(0.13, 0.75, 1.00, 0.80)
    colors[clr.ResizeGrip]           = ImVec4(0.80, 0.80, 0.80, 0.50)
    colors[clr.ResizeGripHovered]    = ImVec4(0.13, 0.75, 0.75, 0.60)
    colors[clr.ResizeGripActive]     = ImVec4(0.13, 0.75, 1.00, 0.80)
    colors[clr.PlotLines]            = ImVec4(0.40, 0.40, 0.40, 1.00)
    colors[clr.PlotLinesHovered]     = ImVec4(0.80, 0.25, 0.25, 1.00)
    colors[clr.PlotHistogram]        = ImVec4(0.90, 0.70, 0.00, 1.00)
    colors[clr.PlotHistogramHovered] = ImVec4(1.00, 0.60, 0.00, 1.00)
    colors[clr.TextSelectedBg]       = ImVec4(0.26, 0.59, 0.98, 0.35)
end

-- скрипт создан @justluaarz
-- скрипт создан @justluaarz
-- скрипт создан @justluaarz
-- скрипт создан @justluaarz
-- скрипт создан @justluaarz