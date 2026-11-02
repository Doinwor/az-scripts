script_name("Friends Checker")
script_description("/FChelp")
script_author("AppleThe")
script_dependencies("SAMPFUNCS & SAMP")
script_version("v1.1.3")

local ffi = require 'ffi'
local imgui = require("mimgui")
local LIP = require("LIP")
require "lib.moonloader"
local fa = require('fAwesome6_solid')

imgui.OnInitialize(function()
	imgui.GetIO().IniFilename = nil
	fa.Init(14 * MONET_DPI_SCALE)
	apply_dark_theme()
end)

function main()
  while not isSampAvailable() do
    wait(1000)
  end
  
  -- Создание директории, если она не существует
  if not doesDirectoryExist("config") then 
    createDirectory("config") 
  end
  
  -- Определение пути к файлу конфигурации
  local configFilePath = "config/FChecker.ini"
  
  -- Создание файла конфигурации, если он не существует
  if not doesFileExist(configFilePath) then
    data = {
        font = {
            name = "Segoe UI",
            size = 9,
            flag = 5,
        },
        options = {
            coordX = 55,
            coordY = 279,
            turn = 1,
        },
        friends = {
            "ANDREY_RINGO",
            "SMART_JACKSON",
        },
    }
    
    local success, err = pcall(function()
      LIP.save(configFilePath, data)
    end)
    
    if not success then
      print("Ошибка сохранения файла: " .. err)
    else
      print("Файл конфигурации успешно создан.")
    end
  end
  
  -- Загрузка данных из файла конфигурации
  local success, data_or_err = pcall(function()
    return LIP.load(configFilePath)
  end)
  if not success then
    print("Ошибка загрузки файла: " .. data_or_err)
    return
  end

  data = data_or_err

  -- Проверка наличия поля friends и его валидности
  if not data.friends or type(data.friends) ~= "table" then
    print("Ошибка: поле 'friends' отсутствует или имеет неверный формат.")
    return
  end

  -- Если всё нормально, выполняем дальнейшую обработку
  for i, friend in ipairs(data.friends) do
    print("Друг №" .. i .. ": " .. friend)
  end

  -- Основной цикл скрипта
  


  sampRegisterChatCommand("fcturn", cmdTurn)
  sampRegisterChatCommand("fcreload", cmdReload)
  sampRegisterChatCommand("fcsize", cmdFontSize)
  sampRegisterChatCommand("fcfont", cmdFontName)
  sampRegisterChatCommand("fcflag", cmdFontFlag)
  sampRegisterChatCommand("fcadd", cmdFriendsAdd)
  sampRegisterChatCommand("fcdelete", cmdFriendsRemove)
  sampRegisterChatCommand("fchelp", cmdScriptInfo)
  sampRegisterChatCommand("fcmenu", cmdMenu)
  font = renderCreateFont(data.font.name, data.font.size, data.font.flag);
  fchecker()
end

function fchecker()
  while true do
    wait(0)
    if data.options.turn == 1 then
      friendsText = " Friends Online:\n"
      for b = 0, 1001 do
        if sampIsPlayerConnected(b) then name = sampGetPlayerNickname(b) end
        for i = 1, #data.friends do
          if sampIsPlayerConnected(b) then
            if data.friends[i] ~= nil then data.friends[i] = string.upper(data.friends[i]) end
            if name ~= nil then regPlayer = string.upper(name) end
            regName = string.match(data.friends[i], regPlayer)
            if regName == data.friends[i] then
              friendStreamed, friendPed = sampGetCharHandleBySampPlayerId(b)
              if friendStreamed then
                friendX, friendY, friendZ = getCharCoordinates(friendPed)
                myX, myY, myZ = getCharCoordinates(PLAYER_PED)
                distance = getDistanceBetweenCoords3d(friendX, friendY, friendZ, myX, myY, myZ)
                distanceInteger = math.floor(distance)
              end
              friendPaused = sampIsPlayerPaused(b)
              color = sampGetPlayerColor(b)
              color = string.format("%X", color)
              if friendPaused then 
                color = string.gsub(color, "..(......)", "66%1") 
              else 
                color = string.gsub(color, "..(......)", "FF%1")
              end
              if friendStreamed then friendList = string.format("{%s}%s[%d] (%dm)", color, name, b, distanceInteger) else friendList = string.format("{%s}%s[%d]", color, name, b) end
              friendsText = string.format("%s %s\n", friendsText, friendList)
            end
          end
        end
      end
      if friendsText ~= " Friends Online:\n" and friendsText ~= "nil" then 
        renderFontDrawText(font, friendsText, data.options.coordX, data.options.coordY, -1) 
      else 
        renderFontDrawText(font, "No one is online", data.options.coordX, data.options.coordY, -1) 
      end
    end
  end
end



function cmdTurn()
  local data = LIP.load('config/FChecker.ini');
  if data.options.turn == 1 then
    data.options.turn = 0
    LIP.save('config/FChecker.ini', data);
    local script = thisScript()
    script:reload()
  else
    data.options.turn = 1
    LIP.save('config/FChecker.ini', data);
    local script = thisScript()
    script:reload()
  end
end

function cmdReload()
  local script = thisScript()
  script:reload()
end

function cmdFontSize(newSize)
  local data = LIP.load('config/FChecker.ini');
  data.font.size = newSize
  LIP.save('config/FChecker.ini', data);
  local script = thisScript()
  script:reload()
end

function cmdFontName(newName)
  local data = LIP.load('config/FChecker.ini');
  data.font.name = newName
  LIP.save('config/FChecker.ini', data);
  local script = thisScript()
  script:reload()
end

function cmdFontFlag(newFlag)
  local data = LIP.load('config/FChecker.ini');
  data.font.flag = newFlag
  LIP.save('config/FChecker.ini', data);
  local script = thisScript()
  script:reload()
end



function cmdFriendsAdd(newFriend)
  print("cmdFriendsAdd вызвана с аргументом:", newFriend) -- Для отладки
  newFriendN = tonumber(newFriend)
  
  if newFriendN ~= nil then
    if sampIsPlayerConnected(newFriendN) then
      newFriend = sampGetPlayerNickname(newFriendN)
      print("Полученный ник:", newFriend) -- Для отладки
    else
      print("Игрок не подключен") -- Для отладки
    end
  end
  
  if newFriend ~= nil then
    newFriend = string.upper(newFriend)
  else
    print("Ник игрока пуст") -- Для отладки
    return
  end
  
  local data = LIP.load('config/FChecker.ini')
  myIndex = 0
  abc = 1
  
  while abc == 1 do
    myIndex = myIndex + 1
    if data.friends[myIndex] == nil then abc = 2 end
  end

  data.friends[myIndex] = newFriend
  if data.friends[myIndex] ~= nil then
    data.friends[myIndex] = string.upper(data.friends[myIndex])
  end
  
  LIP.save('config/FChecker.ini', data)
  print("Добавлен друг:", newFriend) -- Для отладки
  
  local script = thisScript()
  script:reload()
end

function cmdFriendsRemove(delFriend)
    -- Пробуем преобразовать введенное значение в числовой формат
    local delFriendN = tonumber(delFriend)
    
    -- Если введенное значение - это число, проверим, подключен ли игрок
    if delFriendN ~= nil then
        if sampIsPlayerConnected(delFriendN) then 
            -- Получаем ник игрока
            delFriend = sampGetPlayerNickname(delFriendN)
        end
    end

    -- Приводим ник к верхнему регистру для унификации
    if delFriend ~= nil then
        delFriend = string.upper(delFriend)
    else
        print("Ошибка: Ник игрока не найден.")
        return
    end

    -- Загружаем данные из ini файла
    local data = LIP.load('config/FChecker.ini')
    
    -- Ищем игрока в списке друзей и удаляем его
    local found = false
    for k, v in pairs(data.friends) do
        if v == delFriend then
            data.friends[k] = nil
            found = true
            break
        end
    end

    -- Если друга не найдено, выводим сообщение и выходим из функции
    if not found then
        print("Ошибка: Ник игрока не найден в списке друзей.")
        return
    end

    -- Создаем новый список, чтобы перенумеровать оставшихся друзей
    local newFriends = {}
    local number = 1
    for _, v in pairs(data.friends) do
        if v ~= nil then
            newFriends[number] = v
            number = number + 1
        end
    end

    -- Обновляем старый список новым
    data.friends = newFriends

    -- Сохраняем данные обратно в ini файл
    LIP.save('config/FChecker.ini', data)

    -- Перезагружаем скрипт
    local script = thisScript()
    script:reload()
    sampAddChatMessage("Игрок " .. delFriend .. " успешно удалён из списка друзей.", -1)
end

function cmdScriptInfo()
  sampShowDialog(118, "{ffbf00}Friends Checker Info", "{ffcc00}/FCturn {ffffff}- включить/выключить отображение чекера\n{ffcc00}/FCreload {ffffff}- перезапустить скрипт\n{ffcc00}/FCsize [int] {ffffff}- изменить размер шрифта\n{ffcc00}/FCfont [string] {ffffff}- изменить сам шрифт\n{ffcc00}/FCflag [int] {ffffff}- изменить флаг текста\n{ffcc00}/FCmove {ffffff}- изменить координаты чекера (курсором)\n{ffcc00}/FCadd [string] {ffffff}- добавить нового друга в чекер\n{ffcc00}/FCdelete [string] {ffffff}- удалить друга из чекера\n{ffcc00}/fcmenu {ffffff}- открыть меню\nВсё это также можно настроить в config/FChecker.ini", "Okey")
end

function isKeyDown (arg)
	return 1
end
local renderWindow = imgui.new.bool(false)
function cmdMenu()
  	renderWindow [0] = not renderWindow [0]
end


local sizeX, sizeY = getScreenResolution()
encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local ffi = require('ffi')
function isMonetLoader() return MONET_VERSION ~= nil end
if isMonetLoader() then
	gta = ffi.load('GTASA')
	ffi.cdef[[ void _Z12AND_OpenLinkPKc(const char* link); ]] -- функция для открытия ссылок
end
if MONET_DPI_SCALE == nil then MONET_DPI_SCALE = 1.0 end

addFriendInput = imgui.new.char(20)


imgui.OnFrame(
  function() return renderWindow[0] end,
  function()
      return true
  end,
  function(player)
      imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
      imgui.SetNextWindowSize(imgui.ImVec2(1700, 700), imgui.Cond.FirstUseEver)
      imgui.Begin(u8"Friends Checker Menu", renderWindow)
      if imgui.BeginTabBar('Tabs') then
        if imgui.BeginTabItem(u8'Основная вкладка') then
          

          local w = {
            first = 250,
            second = 150,
          }
    
          imgui.Columns(3)
          imgui.Text(u8'Ник') imgui.SetColumnWidth(-1, w.first) -- первый столбик
          imgui.NextColumn()
          imgui.Text(u8'Номер') imgui.SetColumnWidth(-1, w.second) -- второй столбик
          imgui.NextColumn()
          imgui.Text(u8'Удаление') imgui.SetColumnWidth(-1, 200) -- либо можете самостоятельно вписывать
          imgui.Columns(1)
          imgui.Separator()
          local keysToDelete = {}

          for key, value in pairs(data.friends) do
            imgui.Columns(3)
            imgui.Text(u8(value)) 
            imgui.SetColumnWidth(-1, w.first)
            imgui.NextColumn()
            imgui.Text(u8(key)) 
            imgui.SetColumnWidth(-1, w.second)
            imgui.NextColumn()
            if imgui.Button(u8'Удалить ' .. key) then cmdFriendsRemove(value)end
            imgui.Columns(1)
            imgui.Separator()
          end
          imgui.EndTabItem()
        end
        if imgui.BeginTabItem(u8'Инф-а') then
          imgui.BeginChild('##1', imgui.ImVec2(589 * MONET_DPI_SCALE, 170 * MONET_DPI_SCALE), true)
          imgui.CenterText(fa.CIRCLE_INFO .. u8' Дополнительная информация про хелпер')
          imgui.Separator()
          imgui.Text(fa.CIRCLE_USER..u8" Разработчик данного хелпера: @daniel_pon. Скрипт портирован.")
          imgui.Text(fa.GLOBE..u8" Тема хелпера на форуме BlastHack:")
          imgui.SameLine()
          if imgui.SmallButton(u8'Жмяк') then
            openLink('https://www.blast.hk/threads/14008/')
          end
          if imgui.Button(u8('Telegram')) then
						openLink('https://t.me/daniel2903_pon')
					end
					imgui.SameLine()
					if imgui.Button(u8('VK')) then
						openLink('https://vk.com/daniel_pon')
					end
          imgui.SameLine()
					if imgui.Button(u8('ТГ канал скриптов на мобилку')) then
						openLink('https://vk.com/lua_arz')
					end
          imgui.EndTabItem()
        end
        imgui.EndTabBar()
    end
      imgui.End()
  
end
)

function openLink(link)
	if isMonetLoader() then
		gta._Z12AND_OpenLinkPKc(link)
	else
		os.execute("explorer " .. link)
	end
end

function imgui.CenterText(text)
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX( width / 2 - calc.x / 2 )
    imgui.Text(text)
end

function apply_dark_theme()
	imgui.SwitchContext()
    imgui.GetStyle().WindowPadding = imgui.ImVec2(5 * MONET_DPI_SCALE, 5 * MONET_DPI_SCALE)
    imgui.GetStyle().FramePadding = imgui.ImVec2(5 * MONET_DPI_SCALE, 5 * MONET_DPI_SCALE)
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(5 * MONET_DPI_SCALE, 5 * MONET_DPI_SCALE)
    imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(2 * MONET_DPI_SCALE, 2 * MONET_DPI_SCALE)
    imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(0, 0)
    imgui.GetStyle().IndentSpacing = 0
    imgui.GetStyle().ScrollbarSize = 10 * MONET_DPI_SCALE
    imgui.GetStyle().GrabMinSize = 10 * MONET_DPI_SCALE
    imgui.GetStyle().WindowBorderSize = 1 * MONET_DPI_SCALE
    imgui.GetStyle().ChildBorderSize = 1 * MONET_DPI_SCALE
    imgui.GetStyle().PopupBorderSize = 1 * MONET_DPI_SCALE
    imgui.GetStyle().FrameBorderSize = 1 * MONET_DPI_SCALE
    imgui.GetStyle().TabBorderSize = 1 * MONET_DPI_SCALE
	imgui.GetStyle().WindowRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().ChildRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().FrameRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().PopupRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().ScrollbarRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().GrabRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().TabRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().SelectableTextAlign = imgui.ImVec2(0.5, 0.5)
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
    imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.12, 0.12, 0.12, 0.95)
end