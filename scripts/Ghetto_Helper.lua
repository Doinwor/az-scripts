local imgui = require 'mimgui' -- Подключаем саму библиотеку
local sampev = require 'lib.samp.events'
local tab = 1
local arr = os.date("*t")



local encoding = require 'encoding' -- подключаем библиотеку для работы с разными кодировками
encoding.default = 'CP1251' -- задаём кодировку по умолчанию
local u8 = encoding.UTF8 -- это позволит нам писать задавать названия/текст на кириллице
local ffi = require 'ffi'
local samp =  require 'samp.events'
local ids = imgui.new.int(0)  -- Инициализируем переменную ids
local rank = imgui.new.int(0)
local fm = imgui.new.int(0)

local int_item = imgui.new.int(0)
local item_list = {"Не указано", "Grove", "Rifa", "Ballas", "Aztec", "Night Wolf", "Vagos",}
local ImItems = imgui.new['const char*'][#item_list](item_list)

local new = imgui.new
local WinState = new.bool() -- создаём буффер для открытия окна
function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowWidth()/2-imgui.CalcTextSize(u8(text)).x/2)
    imgui.Text(text)
end

imgui.OnFrame(function() return WinState[0] end,
    function() return true end, -- Определяет, выполняется/отображается ли текущий фрейм.
    function(player)            --Сама область, в которой уже будем рисовать элементы.
                               --     В функцию в качестве первой переменной передаются список функций
                               --     для взаимодействия с локальным игроком и рядом нескольких возможностей.]]
        imgui.Begin("GHETTO HELPER LuaScripter 2.00")
        if imgui.CollapsingHeader('Автор') then
        imgui.CenterText('Автор: LuaScripter')
        imgui.CenterText('TELEGRAM: lua_arzmod')
        imgui.CenterText('VERSION: 2.00')
        
end
        if imgui.CollapsingHeader('Основное') then
        local _, changed = imgui.InputInt('ID Игрока', ids)
                if changed then
                    ids = imgui.new.int(ids[0])
                end
                local _, changed = imgui.InputInt('Ранг', rank)
                if changed then
                    rank = imgui.new.int(rank[0])
                end
                local _, changed = imgui.InputInt('Выдать мут (Минуты)', fm)
                if changed then
                    fm = imgui.new.int(fm[0])
                end
         if imgui.Button('Инвайт') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251"/invite " .. ids[0])
    wait(1500)
end)
end
if imgui.Button('Авто принятие в банду') then 
                lua_thread.create(function()
        local mx, my, mz = getCharCoordinates(playerPed)
            for id = 0,1000 do
                _, handle = sampGetCharHandleBySampPlayerId(id)
                if _ then
                    local x, y, z = getCharCoordinates(handle)
                    if getDistanceBetweenCoords3d(x,y,z,mx,my,mz) <= 10 then
                        sampSendChat('/invite '..id)
                        wait(1000) --задержка
                    end
                end
            end
        end)
    end
    if imgui.Button('Авто принятие в семью') then 
                lua_thread.create(function()
        local mx, my, mz = getCharCoordinates(playerPed)
            for id = 0,1000 do
                _, handle = sampGetCharHandleBySampPlayerId(id)
                if _ then
                    local x, y, z = getCharCoordinates(handle)
                    if getDistanceBetweenCoords3d(x,y,z,mx,my,mz) <= 10 then
                        sampSendChat('/faminvite '..id)
                        wait(1000) --задержка
                    end
                end
            end
        end)
    end
if imgui.Button('Выдать ранг') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251"/giverank " .. rank[0])
    wait(1500)
end)
end
if imgui.Button('Выдать игроку мут') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251"/fmute " .. ids[0] .. fm[0])
    wait(1500)
end)
end
if imgui.Button('Выгнать игрока') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251"/uninvite " .. ids[0])
    wait(1500)
end)
end
if imgui.Button('Capture') then
lua_thread.create(function()
    sampSendChat("/capture")
    wait(1500)
end)
end
        end
         if imgui.CollapsingHeader('Наборы') then
        if imgui.Button('Набор в Grove') then
        lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'/fam Проходит набор в Grove Всех ждем на респе!')
                    wait(2500)
end)
        end
        if imgui.Button('Набор в Ballas') then
        lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'/fam Проходит набор в Ballas Всех ждем на респе!')
                    wait(2500)
end)
        end
        if imgui.Button('Набор в Rifa') then
        lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'/fam Проходит набор в Rifa Всех ждем на респе!')
                    wait(2500)
end)
        end
        if imgui.Button('Набор в Aztec') then
        lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'/fam Проходит набор в Aztec Всех ждем на респе!')
                    wait(2500)
end)
        end
        if imgui.Button('Набор в Vagos') then
        lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'/fam Проходит набор в Vagos Всех ждем на респе!')
                    wait(2500)
end)
        end
        if imgui.Button('Набор в Night Wolfs') then
        lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'/fam Проходит набор в Night Wolfs на 5-7 майку, ждем вас на респе!')
                    wait(2500)
end)
        end
        if imgui.Button('Как работает Набор?') then
        lua_thread.create(function()
   sampAddChatMessage(monet_utf8_to_cp1251"{00FF00}[GHETTO-LuaScripter]: {FF0000}Сообщение отправляется в /fam", -1)
                    wait(2500)
end)
        end
        end
        imgui.End()
    end
)

function main()
sampRegisterChatCommand('gh', function() WinState[0] = not WinState[0] end) -- 
    wait(-1)
end