script_name('ConnectTools for Arizona Mobile')
script_version('2.0')
script_version_number(2)
script_author('Radare')
script_description('Reconnect to the server and autologin to your account as well auto-registration (fully controllable)')

local sf = require 'sampfuncs'
local sampev = require 'lib.samp.events' 
local imgui = require 'mimgui'
local ffi = require 'ffi'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local jsoncfg = require 'jsoncfg'
local socket = require 'socket'
local copas = require 'copas'
local http = require 'copas.http' -- for download list of names and surnames and server pings
local toolsconfig = jsoncfg.load({
    config = {
        AutoReconnect = false,
        AutoLogin = false,
        AutoReg = false
    },
    autoreconnect = 
    {
        onBanned = false,
        onPassword = false,
        onKicked = false,
        onRejected = false,
        delay = 10.0
    },
    autologin =
    {
        nickname = "Your_Nickname",
        password = "yourpassword",
        spawn = "[{\"id\": 0, \"spawn\": \"Последнее место выхода\" },{\"id\": 1, \"spawn\": \"Стандартный спавн\" }]", 
        spawn_use = 0
    },
    autoreg = 
    {
        password = "123123",
        refferal = "Sam_Mason",
        resetId = false
    }
})
function cfg_save()
    jsoncfg.save(toolsconfig)
end

local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local renderWindow = new.bool()
local NickName, Password = new.char[256](toolsconfig.autologin.nickname), new.char[256](toolsconfig.autologin.password)
local regPassword, refferalName = new.char[256](toolsconfig.autoreg.password), new.char[256](toolsconfig.autoreg.refferal)
local sizeX, sizeY = getScreenResolution()
local item_spawn, items_spawn
local Reconnect = {
  delay = new.float(toolsconfig.autoreconnect.delay),
  remaining = 0,
  active = new.bool(false)
}
local scr_dir = getWorkingDirectory()..'/ConnectTools'
local names_file, surnames_file = scr_dir..'/names.txt', scr_dir..'/surnames.txt'
local connects, nickname, exit, lastNickname, lastPassword = 0, nil, false, "", ""
local item_spawn = {} 
local current_item_spawn = new.int(toolsconfig.autologin.spawn_use)
local AutoReconnect, AutoLogin, AutoReg = new.bool(toolsconfig.config.AutoReconnect), new.bool(toolsconfig.config.AutoLogin), new.bool(toolsconfig.config.AutoReg)
local onBanned, onPassword, onKicked, onRejected, resetId = new.bool(toolsconfig.autoreconnect.onBanned), new.bool(toolsconfig.autoreconnect.onPassword), new.bool(toolsconfig.autoreconnect.onKicked), new.bool(toolsconfig.autoreconnect.onRejected), new.bool(toolsconfig.autoreg.resetId)
 
function imgui.Theme()
  imgui.SwitchContext()
  style = imgui.GetStyle()

  style.WindowPadding = imgui.ImVec2(5, 5)
  style.FramePadding = imgui.ImVec2(10, 10)
  style.ItemSpacing = imgui.ImVec2(10, 10)
  style.ItemInnerSpacing = imgui.ImVec2(5, 5)
  style.TouchExtraPadding = imgui.ImVec2(5 * MONET_DPI_SCALE, 5 * MONET_DPI_SCALE)
  style.IndentSpacing = 0
  style.ScrollbarSize = 20 * MONET_DPI_SCALE
  style.GrabMinSize = 20 * MONET_DPI_SCALE

  style.WindowBorderSize = 1
  style.ChildBorderSize = 1
  style.PopupBorderSize = 1
  style.FrameBorderSize = 1
  style.TabBorderSize = 1

  style.WindowRounding = 5
  style.ChildRounding = 5
  style.FrameRounding = 5
  style.PopupRounding = 5
  style.ScrollbarRounding = 5
  style.GrabRounding = 5
  style.TabRounding = 5

  style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
  style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
  style.SelectableTextAlign = imgui.ImVec2(0.5, 0.5)
  
  style.Colors[imgui.Col.Text]                   = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
  style.Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
  style.Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
  style.Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
  style.Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
  style.Colors[imgui.Col.Border]                 = imgui.ImVec4(0.25, 0.25, 0.26, 0.54)
  style.Colors[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
  style.Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
  style.Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
  style.Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
  style.Colors[imgui.Col.TitleBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
  style.Colors[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
  style.Colors[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
  style.Colors[imgui.Col.MenuBarBg]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
  style.Colors[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
  style.Colors[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
  style.Colors[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
  style.Colors[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.51, 0.51, 0.51, 1.00)
  style.Colors[imgui.Col.CheckMark]              = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
  style.Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
  style.Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
  style.Colors[imgui.Col.Button]                 = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
  style.Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
  style.Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
  style.Colors[imgui.Col.Header]                 = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
  style.Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
  style.Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.47, 0.47, 0.47, 1.00)
  style.Colors[imgui.Col.Separator]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
  style.Colors[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
  style.Colors[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
  style.Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
  style.Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(1.00, 1.00, 1.00, 0.67)
  style.Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(1.00, 1.00, 1.00, 0.95)
  style.Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
  style.Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.28, 0.28, 0.28, 1.00)
  style.Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
  style.Colors[imgui.Col.TabUnfocused]           = imgui.ImVec4(0.07, 0.10, 0.15, 0.97)
  style.Colors[imgui.Col.TabUnfocusedActive]     = imgui.ImVec4(0.14, 0.26, 0.42, 1.00)
  style.Colors[imgui.Col.PlotLines]              = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
  style.Colors[imgui.Col.PlotLinesHovered]       = imgui.ImVec4(1.00, 0.43, 0.35, 1.00)
  style.Colors[imgui.Col.PlotHistogram]          = imgui.ImVec4(0.90, 0.70, 0.00, 1.00)
  style.Colors[imgui.Col.PlotHistogramHovered]   = imgui.ImVec4(1.00, 0.60, 0.00, 1.00)
  style.Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(1.00, 0.00, 0.00, 0.35)
  style.Colors[imgui.Col.DragDropTarget]         = imgui.ImVec4(1.00, 1.00, 0.00, 0.90)
  style.Colors[imgui.Col.NavHighlight]           = imgui.ImVec4(0.26, 0.59, 0.98, 1.00)
  style.Colors[imgui.Col.NavWindowingHighlight]  = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
  style.Colors[imgui.Col.NavWindowingDimBg]      = imgui.ImVec4(0.80, 0.80, 0.80, 0.20)
  style.Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.00, 0.00, 0.00, 0.70)
end

imgui.OnInitialize(function()
  imgui.Theme()
end)

imgui.OnFrame(function() return renderWindow[0] end,
  function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(200, 150), imgui.Cond.FirstUseEver)
    imgui.Begin(thisScript().name .. " " .. thisScript().version .. " by Radare (t.me/ryderinc)", renderWindow)
    
    if imgui.BeginTabBar('Tabs') then
      if imgui.BeginTabItem(u8'Автореконнект') then 
        if imgui.Checkbox(u8'Автореконнект', AutoReconnect) then     
            msg("Вы "..(AutoReconnect[0] and "включили" or "выключили") .. " автореконнект") 
            if AutoReconnect[0] then msg("Помните, что на некоторых серверах за это вас могут заблокировать") end
            toolsconfig.config.AutoReconnect = AutoReconnect[0]
            cfg_save()
        end
        imgui.SameLine()
        if imgui.Button(u8'Реконнект') then
            msg("Реконнектимся..")
            main_reconnect(0)
        end
        if Reconnect.active[0] then 
            imgui.SameLine()
            if imgui.Button(u8'Отмена') then
                msg("Реконнект отменен.")
                Reconnect.active[0] = false
            end
        end
        if AutoReconnect[0] then
            if imgui.Checkbox(u8'Автореконнект при "You banned from this server"', onBanned) then
                msg("Вы "..(onBanned[0] and "включили" or "выключили") .. " автореконнект при забаненом подключении")      
                toolsconfig.autoreconnect.onBanned = onBanned[0]
                cfg_save()
            end
            if imgui.Checkbox(u8'Автореконнект при пароле сервера', onPassword) then
                msg("Вы "..(onPassword[0] and "включили" or "выключили") .. " автореконнект при пароле сервера")  
                toolsconfig.autoreconnect.onPassword = onPassword[0] 
                cfg_save()
            end
            if imgui.Checkbox(u8'Автореконнект при закрытии соединения с сервером', onKicked) then
                msg("Вы "..(onKicked[0] and "включили" or "выключили") .. " автореконнект при закрытии соединения")          
                toolsconfig.autoreconnect.onKicked = onKicked[0]
                cfg_save()
            end
            if imgui.Checkbox(u8'Автореконнект при занятом/неверном нике', onRejected) then
                msg("Вы "..(onRejected[0] and "включили" or "выключили") .. " автореконнект при занятом/неверном нике")
                toolsconfig.autoreconnect.onRejected = onRejected[0] 
                cfg_save()
            end
            if imgui.SliderFloat(u8'Задержка автореконнекта (в секундах)', Reconnect.delay, 0.0, 1000.0) then
                toolsconfig.autoreconnect.delay = Reconnect.delay[0]
                cfg_save()
            end
        end
       imgui.EndTabItem()
      end
      if imgui.BeginTabItem(u8'Автологин') then
        if imgui.Checkbox(u8'Автологин', AutoLogin) then
            if AutoReg[0] then 
                msg("У вас уже включена авторегистрация. Отключите её, чтобы включить автологин")
                AutoLogin[0] = not AutoLogin[0]
            else
                msg("Вы "..(AutoLogin[0] and "включили" or "выключили") .. " автологин") 
                toolsconfig.config.AutoLogin = AutoLogin[0]
                cfg_save()
            end
        end
        if AutoLogin[0] then
            if imgui.InputText(u8"Никнейм", NickName, sizeof(NickName)) then
                toolsconfig.autologin.nickname = str(NickName)
                cfg_save()
            end
            if imgui.InputText(u8"Пароль", Password, sizeof(Password)) then
                toolsconfig.autologin.password = str(Password)
                cfg_save()
            end
            if imgui.Button(u8"Очистить поля") then
                imgui.StrCopy(NickName, '')
                imgui.StrCopy(Password, '')
                msg("Поля очищены")
            end
            imgui.SameLine()
            if imgui.Button(u8"Вставить последние введеные данные") then
                if #lastNickname > 0 and #lastPassword > 0 then
                    toolsconfig.autologin.nickname = lastNickname
                    toolsconfig.autologin.password = lastPassword
                    imgui.StrCopy(NickName, lastNickname)
                    imgui.StrCopy(Password, lastPassword)
                    cfg_save()
                    msg("Данные вставлены")
                else msg("Данных для вставки нет") end
            end
            if imgui.Combo(u8"Место спавна", current_item_spawn, items_spawn, #item_spawn) then
                toolsconfig.autologin.spawn_use = current_item_spawn[0]
                cfg_save()
            end   
        end     
        imgui.EndTabItem()
      end
      if imgui.BeginTabItem(u8'Авторегистрация') then
        if imgui.Checkbox(u8'Авторегистрация', AutoReg) then
            if AutoLogin[0] then 
                msg("У вас уже включен автологин. Отключите его, чтобы включить авторегистрацию")
                AutoReg[0] = not AutoReg[0]
            else
                if AutoReg[0] then 
                  if not doesFileExist(surnames_file) or not doesFileExist(names_file) then 
                    msg("Скачиваем базу для генерации никнеймов")
                    download_file("https://raw.githubusercontent.com/zeraye/names-surnames-list/master/surnames-list.txt", surnames_file)
                    download_file("https://raw.githubusercontent.com/zeraye/names-surnames-list/master/male-names-list.txt", names_file)
                  end
                end
                msg("Вы "..(AutoReg[0] and "включили" or "выключили") .. " авторегистрацию") 
                toolsconfig.config.AutoReg = AutoReg[0]
                cfg_save()
            end
        end 
        if AutoReg[0] then
            if imgui.Button(u8"Обновить базу никнеймов (raw.githubusercontent.com)") then
                msg("Обновляем...")
                download_file("https://raw.githubusercontent.com/zeraye/names-surnames-list/master/surnames-list.txt", surnames_file)
                download_file("https://raw.githubusercontent.com/zeraye/names-surnames-list/master/male-names-list.txt", names_file) 
            end
            if imgui.InputText(u8"Реферал (никнейм)", refferalName, sizeof(refferalName)) then
                toolsconfig.autoreg.refferal = str(refferalName)
                cfg_save()
            end
            if imgui.InputText(u8"Пароль создаваемых аккаунтов", regPassword, sizeof(regPassword)) then
                toolsconfig.autoreg.password = str(regPassword)
                cfg_save()
            end
            if imgui.Button(u8"Очистить поля") then
                msg("Поля очищены")
                imgui.StrCopy(refferalName, '')
                imgui.StrCopy(regPassword, '')
            end
            if imgui.Checkbox(u8'Автореконнект при регистрации (сброс ID)', resetId) then
                msg("Вы "..(resetId[0] and "включили" or "выключили") .. " автореконнект при регистрации")  
                toolsconfig.autoreg.resetId = resetId[0] 
                cfg_save()
            end
        end
        imgui.EndTabItem()
      end
      imgui.EndTabBar() 
    end
    imgui.End()
  end
)

function main()
  repeat wait(0) until isSampAvailable()
  msg(thisScript().name .. " " .. thisScript().version .. " by Radare (t.me/ryderinc) loaded!")
  sampRegisterChatCommand('rec', function() main_reconnect(0) end)
  sampRegisterChatCommand('rectool', function() 
    update_splist()
    renderWindow[0] = not renderWindow[0] 
  end)
  if not doesDirectoryExist(scr_dir) then createDirectory(scr_dir) end
  addEventHandler('onReceivePacket', function(id, bs, ...) 
    if id == 220 then 
        raknetBitStreamIgnoreBits(bs, 8) 
        if raknetBitStreamReadInt8(bs) == 84 then 
            interfaceid = raknetBitStreamReadInt8(bs)
            subid = raknetBitStreamReadInt8(bs)
            json = readArzString(bs)
            if toolsconfig.config.AutoLogin then
                if interfaceid == 9 then 
                    if subid == 3 then
                        if json == "spawn" then
                            lua_thread.create(function()
                                wait(200)
                                showToolTip("Выбираем место спавна - "..u8:decode(item_spawn[toolsconfig.autologin.spawn_use+1]))
                                sendFrontendClick(9, 6, 0, tostring(toolsconfig.autologin.spawn_use))
                            end) 
                        end
                        if json == "user_already_game" then
                            lua_thread.create(function()
                                wait(2000)
                                showToolTip("Пробуем авторизоваться под ником - " .. toolsconfig.autologin.nickname)
                                sendAuth(toolsconfig.autologin.nickname, toolsconfig.autologin.password)
                            end) 
                        end
                    end
                    if subid == 0 then
                        lua_thread.create(function()
                            wait(200) 
                            showToolTip("Пробуем авторизоваться под ником - " .. toolsconfig.autologin.nickname)
                            sendAuth(toolsconfig.autologin.nickname, toolsconfig.autologin.password)
                        end) 
                    end
                    if subid == 8 then
                        toolsconfig.autologin.spawn = json
                        print(toolsconfig.autologin.spawn)
                        update_splist()
                        cfg_save()
                    end
                end  
            end
            if toolsconfig.config.AutoReg then
                if interfaceid == 9 then 
                    if subid == 4 then
                        if json == "user_exist" then
                          sendReg()
                        end
                    end
                    if subid == 3 then
                        if json == "spawn" then
                            lua_thread.create(function()
                                wait(200)
                                sendFrontendClick(9, 6, 0, "1")
                            end) 
                        end
                        if json == "user_already_game" then
                            if nickname ~= nil then 
                                lua_thread.create(function()
                                    wait(200)
                                    sendAuth(nickname, toolsconfig.autoreg.password)
                                end) 
                            else sendReg() end
                        end
                    end
                    if subid == 0  then
                        if nickname ~= nil then
                            lua_thread.create(function()
                                wait(200)
                                sendAuth(nickname, toolsconfig.autoreg.password)
                            end) 
                        else sendReg() end
                    end
                end 
            else
                if interfaceid == 9 and subid == 3 then 
                    if json == "loading" then
                        if not toolsconfig.config.AutoLogin then showToolTip("Загрузка...") end
                        return false
                    end
                    if json == "error" then
                        if toolsconfig.config.AutoLogin then
                            AutoLogin[0] = false
                            toolsconfig.config.AutoLogin = false
                            cfg_save()
                            showToolTip("Неправильный логин или пароль. Автологин отключен.")
                        else
                            showToolTip("Неправильный логин или пароль. Попробуйте еще!")
                        end
                        return false
                    end
                end
            end
        end
    end
  end) 
  addEventHandler('onSendPacket', function(id, bs, ...) 
    if id == 220 then 
        raknetBitStreamIgnoreBits(bs, 8) 
        if raknetBitStreamReadInt8(bs) == 63 then
            interfaceid = raknetBitStreamReadInt8(bs)
            id = raknetBitStreamReadInt32(bs)
            subid = raknetBitStreamReadInt32(bs)
            len = raknetBitStreamReadInt16(bs) 
            json = raknetBitStreamReadString(bs, len)
            if interfaceid == 9 and (id == 0 or id == 1) and subid == 0 then
                local data = decodeJson(json)
                lastNickname = data['username']
                lastPassword = data['password']
            end
        end
    end
  end) 
end

function sendPingPacket(ip_address)
    local client = assert(socket.tcp())
    client:settimeout(5)
    local ok, err = client:connect(ip_address, 80)
    if not ok then
        print("Ошибка соединения:", err)
        return
    end

    local bytes, send_err = client:send("GET / HTTP/1.1\r\nHost: " .. ip_address .. "\r\nConnection: close\r\n\r\n")
    if not bytes then print("Ошибка отправки:", send_err) end
    client:close()
end

function readArzString(bs)
    length = raknetBitStreamReadInt16(bs)
    encoded = raknetBitStreamReadInt8(bs)
    arzstring = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or raknetBitStreamReadString(bs, length)
    return arzstring
end

function sendAuth(nickname, password)
    sendFrontendClick(9, 0, 0, '{"password":"'..password..'","username":"'..nickname..'"}')
end

function sendReg()
    msg("Автоматически регестрируемся")
    nickname = generateNickName() 
    lua_thread.create(function()
        wait(200)
        sendFrontendClick(9, 1, 0, '{"password":"'..toolsconfig.autoreg.password..'","referralUsername":"'..toolsconfig.autoreg.refferal..'","username":"'..nickname..'"}')
        wait(200)
        sendFrontendClick(9, 3, 1, '{"clothes":0,"gender":0,"skin":0}')
        wait(200)
        sendFrontendClick(9, 3, 0, '')
    end)
end

function showToolTip(msg)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 143)
    raknetBitStreamWriteBool(bs, true)
    raknetBitStreamWriteInt16(bs, #msg)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteString(bs, msg)
    raknetEmulPacketReceiveBitStream(220, bs) 
    raknetDeleteBitStream(bs)
end

function sendFrontendClick(interfaceid, id, subid, json)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteInt32(bs, id)
    raknetBitStreamWriteInt32(bs, subid)
    raknetBitStreamWriteInt16(bs, #json)
    raknetBitStreamWriteString(bs, json)
    raknetSendBitStreamEx(bs, 1, 7, 1)
    raknetDeleteBitStream(bs)
end


function generateNickName()
    local names, surnames
    if doesFileExist(names_file) then
        names = fileMassive(names_file)
    else
        names = {"Johns", "Emma", "Michael", "Olivia", "William", "Ava", "James", "Sophia", "Benjamin", "Isabella", "Ethan", "Mia", "Alexander", "Charlotte", "Daniel", "Amelia", "Matthew", "Harper", "Joseph", "Evelyn", "David", "Abigail", "Andrew", "Emily", "Jackson", "Elizabeth", "Christopher", "Sofia", "Samuel", "Avery", "Gabriel", "Ella", "Ryan", "Scarlett", "Nicholas", "Grace", "Joshua", "Chloe", "Jacob", "Victoria", "Nathan", "Lily", "Jonathan", "Hannah", "Christian", "Natalie", "Elijah", "Zoe", "Benjamin", "Addison"}
    end
    if doesFileExist(surnames_file) then
        surnames = fileMassive(surnames_file)
    else
        surnames = {"Smith", "Johnson", "Brown", "Taylor", "Miller", "Davis", "Garcia", "Wilson", "Anderson", "Thomas", "Martinez", "Jones", "Clark", "Lewis", "Walker", "Hall", "Young", "Lee", "Allen", "Adams", "Harris", "White", "Martin", "Thompson", "Wright", "Jackson", "Turner", "Hill", "Moore", "Harris", "Scott", "Cooper", "King", "Green", "Baker", "Nelson", "Murphy", "Bailey", "Reed", "Brooks", "Morgan", "Ross", "Parker", "Rogers", "Gray", "Roberts", "Cook", "Murray", "Powell", "Perez", "Barnes", "Carter", "Morris", "Wood", "Ortega", "Mitchell", "Watson", "Collins", "Stewart", "Sanchez", "Morales", "Ramos", "Reyes", "Bennett", "Rivera", "Long", "Foster", "Gonzalez", "Howard", "Ward", "Cox", "Diaz", "Hayes", "Peterson", "Price", "Gray", "Butler", "Simmons", "Fisher", "Henderson", "Coleman", "Lopez", "Berry", "Sanders", "Bryant", "Perry", "George", "Rice", "Harrison", "Reid", "Mendoza", "Hamilton", "Woods", "Murray", "Bishop", "Knight", "Burton", "Gomez"}
    end
    math.randomseed(os.time())
    local name = names[math.random(#names)]
    local surname = surnames[math.random(#surnames)]
    local nickName = name .. "_" .. surname
    return nickName
end

function httpRequest(request, body, handler)
    if not copas.running then
        copas.running = true
        lua_thread.create(function()
            wait(0)
            while not copas.finished() do
                local ok, err = copas.step(0)
                if ok == nil then error(err) end
                wait(0)
            end
            copas.running = false
        end)
    end
    if handler then
        return copas.addthread(function(r, b, h)
            copas.setErrorHandler(function(err) h(nil, err) end)
            h(http.request(r, b))
        end, request, body, handler)
    else
        local results
        local thread = copas.addthread(function(r, b)
            copas.setErrorHandler(function(err) results = {nil, err} end)
            results = table.pack(http.request(r, b))
        end, request, body)
        while coroutine.status(thread) ~= 'dead' do wait(0) end
        return table.unpack(results)
    end
end


function download_file(url, path)
    msg("Скачиваем файл с URL: "..url)
    print("Download with URL: "..url)
    local headers = {
      ["accept"] = "*/*",
      ["user-agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:67.0) Gecko/20100101 Firefox/67.0",
      ["Upgrade-Insecure-Requests"] = "1"
    }
    httpRequest(url, nil, function(response, code, headers, status)
      if response and code >= 200 and code < 300 then
        local f = assert(io.open(path, 'wb'))
        f:write(response)
        f:close()
        msg("Файл успешно записан по пути: ".. string.gsub(path, "/storage/emulated/0/Android/media/", ""))
      else
        msg('(http) Response error. URL: '..url..' CODE: '..code..' STATUS: '..status)
      end
    end)
end

function fileMassive(path)
    local file = io.open(path, "r")
    if file then
        local massive = {}
        for line in file:lines() do
            local formattedLine = line:sub(1, 1):upper() .. line:sub(2):lower()
            table.insert(massive, formattedLine)
        end
        file:close()
        return massive
    else
        msg("Не удалось открыть файл: "..path)
        return nil
    end
end

function readFile(p)
   local f = io.open(p)
   local t = f:read()
   f:close()
   return t
end

function update_splist()
    item_spawn = {}
    for i, item in ipairs(decodeJson(toolsconfig.autologin.spawn)) do
      table.insert(item_spawn, u8(item.id .. ". " .. item.spawn))
    end 
    items_spawn = new['const char*'][#item_spawn](item_spawn) 
end
 

function msg(message)
    sampAddChatMessage("[ConnectTools] {ffffff}".. message, 0xD2691E)
end

function main_reconnect(type)
    if type == 0 then
      local bs = raknetNewBitStream()
      raknetBitStreamWriteInt8(bs, sf.PACKET_DISCONNECTION_NOTIFICATION)
      raknetSendBitStreamEx(bs, sf.SYSTEM_PRIORITY, sf.RELIABLE, 0)
      raknetDeleteBitStream(bs)

      bs = raknetNewBitStream()
      raknetEmulPacketReceiveBitStream(sf.PACKET_CONNECTION_LOST, bs)
      raknetDeleteBitStream(bs)
    end 
    if type == 1 then
        lua_thread.create(function()
            if Reconnect.active[0] then 
                msg("Попытка реконнекта была отменена т.к. уже есть существующая")
                return
             end
            Reconnect.active[0] = true
            local ms = 500 + Reconnect.delay[0] * 1000
            if ms <= 0 then
              ms = 100
            end

            while ms > 0 and Reconnect.active[0] do
              if ms <= 500 then
                main_reconnect(0)
                printStringNow("~g~reconnect", 3000)
                ms = 0
                Reconnect.active[0] = false
              end

              printStringNow(string.format('reconnect wait %.2f sec...', ms / 1000), 100)
              wait(100)
              ms = ms - 100
            end
        end)
    end
end

function sampev.onAuthenticationRequest()
  msg("Пытаемся подключиться к серверу.. Попытка: " .. connects)
end

function sampev.onConnectionRequestAccepted()
  msg("Подключились. Входим в игру.")
end

function sampev.onConnectionAttemptFailed()
  sendPingPacket(select(1, sampGetCurrentServerAddress()))
  msg("Сервер не отвечает.. Попытка: " .. connects)
  connects = connects + 1
end

function sampev.onConnectionNoFreeSlot()
  msg("Сервер полон.. Попытка: " .. connects)
  connects = connects + 1
end

function sampev.onConnectionBanned()
    msg("Вы забанены на данном сервере")
    if exit then
       msg("Реконнектимся.. (авторегистрация)")
       main_reconnect(1)
    end
    if toolsconfig.autoreconnect.onBanned and toolsconfig.config.AutoReconnect then
      msg("Реконнектимся..")
      main_reconnect(1)
    end
end
 
function sampev.onConnectionPasswordInvalid()
    msg("Неверный пароль сервера")
    if toolsconfig.autoreconnect.onPassword and toolsconfig.config.AutoReconnect then
      msg("Реконнектимся..")
      main_reconnect(1)
    end
end

function sampev.onConnectionClosed()
    msg("Сервер закрыл соединение")
    if toolsconfig.autoreconnect.onKicked and toolsconfig.config.AutoReconnect then
      msg("Реконнектимся..")
      main_reconnect(1)
    end
end

function sampev.onConnectionRejected()
    msg("Недопустимый ник или ник занят.")
    if exit then
       msg("Реконнектимся.. (авторегистрация)")
       main_reconnect(0)
    end
    if toolsconfig.autoreconnect.onRejected and toolsconfig.config.AutoReconnect then
      msg("Реконнектимся..")
      main_reconnect(1)
    end
end

function sampev.onSendSpawn()
    if not toolsconfig.config.AutoReg then return true end
    if not toolsconfig.autoreg.resetId then 
        nickname = nil
        return true 
    end
    if not exit then
        lua_thread.create(function()
            showToolTip("Перезаходим для сбрасывания айди (защита от лога у админов)")
            sampSendEnterVehicle(65535, false)
            wait(2000)
            main_reconnect(0)
            exit = true
        end)
    else
        nickname = nil
        exit = false
    end
end

function onScriptTerminate(s, quitGame) if s == thisScript() then cfg_save() end end
