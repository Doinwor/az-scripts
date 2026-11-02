local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local new = imgui.new
local requests = require "requests"
local mainmenu = new.bool()
local InfBar = new.bool()
local faicons = require 'fAwesome6'
local ev = require 'lib.samp.events'
local inicfg = require 'inicfg'
local monet = require ('MoonMonet')
local MDS = MONET_DPI_SCALE
local ffi = require("ffi")
local str = ffi.string

script_name('Lesopilka Helper')
script_author('@justskipty')
script_description(u8'LesopilkaHelper - очень удобный хелпер на лесопилку! Команда для активации - /lesopilka')

local ini = inicfg.load({
	cfg = {
		derevo = 0,
		derevosalary = 0,
		zpfull = false,
		schitat = false,
		alt = false,
		zarp = 0,
 	   }
	}, "lesopilka.ini")

function save()
    inicfg.save(ini, "lesopilka.ini")
end

local buffers = {
    derevosalary = new.int(ini.cfg.derevosalary),
}

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(text).x / 2)
    imgui.Text(text)
end

local window_state = imgui.new.bool(false)
local alt = imgui.new.bool(ini.cfg.alt)   
local infbarchik = imgui.new.bool(false)
local zpfull = imgui.new.bool(ini.cfg.zpfull)    
local schitat = imgui.new.bool(ini.cfg.schitat)

function papka()
    local lfs = require "lfs"
    local dir = getWorkingDirectory() .. '/lesopilka'
    
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

imgui.OnInitialize(function()
SoftDarkTheme()
papka()
	local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 100)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 25, config, iconRanges) -- solid - С‚РёРї РёРєРѕРЅРѕРє, С‚Р°Рє Р¶Рµ РµСЃС‚СЊ thin, regular, light Рё duotone
    imgui.GetIO().IniFilename = nil;

	local savePath = getWorkingDirectory() .. '/lesopilka/chainsaw.png'
    downloadFile("https://raw.githubusercontent.com/Skipty1234/image/main/chainsaw.png", savePath)
    image = imgui.CreateTextureFromFile(savePath)
end)

imgui.OnFrame(function() return mainmenu[0] end,
    function(oknoochko)
    	local sw, sh = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(500, 400))
        local kaka = imgui.WindowFlags.NoTitleBar
        kaka = kaka + imgui.WindowFlags.NoResize
        imgui.Begin("okoshko", mainmenu, kaka)
        
        imgui.SetWindowFontScale(0.6)
        imgui.Text(u8'Версия: 1.0')
        
        imgui.Text(u8'Автор: @justskipty')
        
        imgui.SetWindowFontScale(1)
        
        imgui.SetCursorPos(imgui.ImVec2(150, -40))
        imgui.Image(image, imgui.ImVec2(200, 200))
        
        imgui.SetCursorPos(imgui.ImVec2(420, 10))
        if imgui.Button(u8'' .. faicons.CIRCLE_XMARK, imgui.ImVec2(70, 70)) then mainmenu[0] = false end
        
        imgui.SetCursorPos(imgui.ImVec2(15, 100))
        if imgui.Checkbox(u8'Информационное окно ' .. faicons.CALCULATOR, infbarchik) then 
                    InfBar[0] = not InfBar[0]              
                    save()
               end
               
               if imgui.Checkbox(u8'Считать количество дерева ' .. faicons.CALCULATOR, schitat) then 
                    ini.cfg.schitat = schitat[0]
                    save()
        	end
        
        if imgui.Checkbox(u8'Считать прибыль ' .. faicons.DOLLAR_SIGN, zpfull) then 
                    ini.cfg.zpfull = zpfull[0]
                    save() 
                end
              
         if zpfull[0] then
                imgui.SetNextItemWidth(imgui.GetFontSize() * 8)
                    if imgui.InputInt(u8'Цена за дерево ' .. faicons.DOLLAR_SIGN, buffers.derevosalary, 1, 10) then
                        ini.cfg.derevosalary = buffers.derevosalary[0]
                        save() 
                    end
                end
                
                if imgui.Checkbox(u8'Кнопка ALT ' .. faicons.TABLET_BUTTON, alt) then
                    window_state[0] = not window_state[0]
                end
                
                if imgui.Button(faicons('ROTATE_RIGHT') .. "", imgui.ImVec2(40 * MONET_DPI_SCALE, 40 * MONET_DPI_SCALE)) then          
                script_reload()
            end
            imgui.SameLine()
            if imgui.Button(faicons('POWER_OFF') .. "", imgui.ImVec2(40 * MONET_DPI_SCALE, 40 * MONET_DPI_SCALE)) then
                script_unload()
            end
        
        imgui.End()
end)

imgui.OnFrame(function() return InfBar[0] end, function(oknoochko)
    	local sw, sh = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(300, 210))
        local kaka = imgui.WindowFlags.NoTitleBar
        kaka = kaka + imgui.WindowFlags.NoResize
        imgui.Begin("sosal", InfBar, kaka)
        
        
        local zpfully = ini.cfg.zarp + ini.cfg.derevo * ini.cfg.derevosalary
        if schitat[0] then imgui.Text(u8'Срублено дерева: '..superbusya(ini.cfg.derevo)) end
        
        if zpfull[0] then imgui.Text(u8'Заработано: '..superbusya(zpfully)..'$') end
    imgui.SetCursorPos(imgui.ImVec2(13, 145))
    if imgui.Button(u8'Очистить', imgui.ImVec2(-1, 50)) then
        ini.cfg.derevo = 0
        ini.cfg.zarp = 0
        save()
    end
    
        imgui.End()
end)

imgui.OnFrame(function() 
    return window_state[0] 
end, function() 
	local sw, sh = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(150, 150), imgui.Cond.FirstUseEver)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(0, 0))

    local flags = imgui.WindowFlags.NoCollapse
    local topOffset = imgui.GetFrameHeight()

    if is_locked then
        flags = bit.bor(flags, imgui.WindowFlags.NoResize, imgui.WindowFlags.NoMove, imgui.WindowFlags.NoTitleBar)
        topOffset = 0
    end

    if imgui.Begin("Button ALT##main", window_state, flags) then
        local windowWidth = imgui.GetWindowSize().x
        local windowHeight = imgui.GetWindowSize().y - topOffset

        local lockButtonHeight = 15 * MDS

        buttonHeight = windowHeight - lockButtonHeight

        imgui.SameLine()
        if imgui.Button("Alt", imgui.ImVec2(windowWidth, buttonHeight)) then
            lua_thread.create(function() ALT() end)
        end
        
        if imgui.Button(is_locked and u8"Откреп" or u8"Закреп", imgui.ImVec2(windowWidth, lockButtonHeight)) then
            is_locked = not is_locked
        end

        imgui.End()
    end

    imgui.PopStyleVar(2)
end)

function press(sync_type, keysData)
    local dataa = samp_create_sync_data(sync_type)
    local x, y, z = getCharCoordinates(PLAYER_PED)

    wait(2)
    dataa.keysData = keysData
    dataa.position = { x, y, z }
    dataa.send()
end

function ALT()
    press('player', 1024)
end

local SPECIAL_KEYS = {
    Y = 1,
    N = 2,
    H = 3
}

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
        trailer = { 'TrailerSyncData', raknet.PACKET.TRAILER_SYNC, sampStorePlayerTrailerData },
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

function ev.onServerMessage(color, text)
	if text:find("Всего спилено") then
	ini.cfg.derevo = ini.cfg.derevo + 2
        save()
	end
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
sampAddChatMessage("[Lesopilka]: {FFFFFF}" .. text, 0x808080)
end

function main()
    if not isSampfuncsLoaded() or not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
    while not sampIsLocalPlayerSpawned() do wait(0) end
    msg('Хелпер для лесопилки успешно загружен! /lesopilka')
    msg('Автор хелпера - @justskipty')
    sampRegisterChatCommand("lesopilka", function() mainmenu[0] = not mainmenu[0] end)
    wait(0)
end

function superbusya(n)
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)', '%1.'):reverse())..right
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

-- автор скрипта: @justskipty (ранее @waitingfornewseven/justskiptymods)