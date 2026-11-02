script_name("MimGui СМИ")
script_author("t.me/lua_arzmod")
script_description("Рекомендуемый доп.скрипт для Police Helper от t.me/beavers_best")
local imgui = require 'mimgui' -- Подключаем саму библиотеку
local sampev = require 'lib.samp.events'
local tab = 1
local arr = os.date("*t")
local window_two = imgui.new.bool()
local window_three = imgui.new.bool()



local encoding = require 'encoding' -- подключаем библиотеку для работы с разными кодировками
encoding.default = 'CP1251' -- задаём кодировку по умолчанию
local u8 = encoding.UTF8 -- это позволит нам писать задавать названия/текст на кириллице
local ffi = require 'ffi'
local samp =  require 'samp.events'
local ids = imgui.new.int(0)  -- Инициализируем переменную ids

local new = imgui.new
local WinState = new.bool() -- создаём буффер для открытия окна
local checkboxone = new.bool()
local inputField = new.char[256]() -- создаём буффер для инпута
local firstWin = new.bool(false)
local secondWin = new.bool(false)
function imgui.CenterText(text)
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX( width / 2 - calc.x / 2 )
    imgui.Text(text)
end

local commands = {'  ',
'2.1 Если человек покупает, то в конце объявления пишем (Бюджет)',
'Если человек продаёт, то в конце объявления пишем (Цена)',
'Если человек арендует/сдаёт в аренду, то в конце объявления пишем (Оплата в час)',
'3.1 Запрещено продавать недвижимость без указания местоположения. Разрешено покупать недвижимость без указания местоположения.',
'4.1 Вы должны четко писать, что за тип транспорта.',
'4.1 Вы должны четко писать, что за тип транспорта.',
'5.1 Разрешено редактировать объявления о предоставлении временных услуг.',
'6.1 Разрешено редактировать объявления без указания места собеседования.',
'6.2. Разрешено редактировать объявления о поиске работы.',
'6.3. При поиске работы обязательно должен присутствовать пункт (О себе), если такого нет в объявлении, то пишем (О себе: при встрече.)',
'7.1. Знакомства - это поиск: друзей, подруг, жен/мужей и т.д.',
'7.2. В редактируемом объявлении обязательно должен быть пункт О себе, если такого нет, то пишите (О себе: при встрече/за чашечкой кофе)',
'7.3. Разрешено искать людей с майкой/кепкой/футболкой и т.д. с надписью Skype/Discord',
'8.1. Разрешено искать/набирать семью.', '8.2. В объявлении про набор в семью галочку, и все улучшения заменяем на нашивки.',
'8.3. Разрешено искать людей.',
'8.4. При наборе в семью, обязательно должно быть название.',
'8.5. Имя и фамилия искомого человека может быть только на русском языке.',
'8.6. Запрещено редактировать объявления с поиском игроков в казино.',
'8.7. Нельзя писать имена администраторов при поиске людей.',
'8.8. Запрещено искать игроков для игры в кс го.',}

local tWeekdays = {[0] = "Воскресенье", [1] = "Понедельник", [2] = "Вторник", [3] = "Среда", [4] = "Четверг", [5] = "Пятница", [6] = "Суббота"}

local search = imgui.new.char[256]() -- создаём буфер для поиска

local inicfg = require 'inicfg'
local iniFile = 'Styles.ini'
local ini = inicfg.load({
	cfg = {
		theme = 0,
		style = 0
	}
}, iniFile)
if not doesDirectoryExist(getWorkingDirectory()..'\\config') then print('Creating the config directory') createDirectory(getWorkingDirectory()..'\\config') end
if not doesFileExist('moonloader/config/'..iniFile) then print('Creating/updating the .ini file') inicfg.save(ini, iniFile) end

local theme = new.int(ini.cfg.theme)
local style = new.int(ini.cfg.style)

local themesList, stylesList = {}, {}

imgui.OnInitialize(function()
	imgui.GetIO().IniFilename = nil
	for i, v in ipairs(themes) do table.insert(themesList, v.name) end
	for i, v in ipairs(styles) do table.insert(stylesList, v.name) end

	themes[theme[0]+1].func()
	styles[style[0]+1].func()
end)

local sizeX, sizeY = getScreenResolution()


imgui.OnFrame(function() return WinState[0] end,
                        
    function() return true end, -- Определяет, выполняется/отображается ли текущий фрейм.
    function(player)            --Сама область, в которой уже будем рисовать элементы.
                               --     В функцию в качестве первой переменной передаются список функций
                               --     для взаимодействия с локальным игроком и рядом нескольких возможностей.]]
                               imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5)) -- Укажем положение окна по центру и выставим оффсет 0.5, чтобы рендер шёл от середины окна
        imgui.SetNextWindowSize(imgui.ImVec2(800, 700), imgui.Cond.FirstUseEver) -- Укажем размер
        imgui.Begin("Helper СМИ by Lua-Scripter. VERSION: 1.00")  -- Создаём новое окно с заголовком 'Main Window'
        if imgui.Button('Примеры объявлений') then tab = 1 end -- это первая кнопка, которая будет отвечать за переключение на раздел 1
imgui.SameLine()
if imgui.Button('Разное') then tab = 2 end -- это вторая кнопка, которая будет отвечать за переключение на раздел 2
imgui.SameLine()
if imgui.Button('Команды') then tab = 3 end -- это вторая кнопка, которая будет отвечать за переключение на раздел 3
imgui.SameLine()
if imgui.Button('Правила') then tab = 4 end -- это вторая кнопка, которая будет отвечать за переключение на раздел 3
imgui.SameLine()
if imgui.Button('Информация') then tab = 5 end -- это вторая кнопка, которая будет отвечать за переключение на раздел 3
if tab == 1 then
    if imgui.CollapsingHeader('Куплю') then
    imgui.TextWrapped('Куплю м/д "Twin-Turbo". Бюджет:')
    imgui.TextWrapped('Куплю р/с "Карта Сокровищ". Бюджет:')
    imgui.TextWrapped('Куплю р/с "Карта Кладов". Бюджет:')
    imgui.TextWrapped('Куплю р/с "Зловещая Монета" в большом кол-ве. Бюджет:')
    imgui.TextWrapped('Куплю р/с "Ларцы с Премией" в большом кол-ве. Бюджет:')
    imgui.Separator()
end
       if imgui.CollapsingHeader('Продам') then
    imgui.TextWrapped('Продам м/д "Twin-Turbo". Цена:')
    imgui.TextWrapped('Продам р/с "Карта Сокровищ". Цена:')
    imgui.TextWrapped('Продам р/с "Карта Кладов". Цена:')
    imgui.TextWrapped('Продам р/с "Зловещая Монета". Цена:')
    imgui.TextWrapped('Продам "Ларец с премией". Цена: ')
    imgui.Separator()
end
      if imgui.CollapsingHeader('Аренда') then
    imgui.TextWrapped('Арендую а/с "Супер кирку". Бюджет:')
    imgui.TextWrapped('Арендую т/с "Фуру". Бюджет:')
    imgui.TextWrapped('Арендую а/с "Супер Грабли" Бюджет:')
    imgui.Separator()
end
     if imgui.CollapsingHeader('Ищу') then
    imgui.TextWrapped('Ищу дальнего родственика с майкой "Name"')
    imgui.Separator()
end
     if imgui.CollapsingHeader('Собеседование') then
     imgui.CenterText('Гетто')
    imgui.TextWrapped('Проходит набор в "Groove Street" Всех ждем на респе!')
    imgui.TextWrapped('Проходит набор в "Ballas" Всех ждем на респе!')
    imgui.TextWrapped('Проходит набор в "Rifa" Всех ждем на респе!')
    imgui.TextWrapped('Проходит набор в "Vagos" Всех ждем на респе!')
    imgui.TextWrapped('Проходит набор в "Aztec" Всех ждем на респе!')
    imgui.TextWrapped('Проходит набор в "Night Wolfs" Всех ждем на респе!')
    imgui.CenterText('Мафии')
    imgui.TextWrapped('Проходит собеседование в ТК "Tabacco". (Русская Мафия)')
    imgui.TextWrapped('Проходит собеседование в  бар Бородатая Фея. (Байкеры)')
    imgui.TextWrapped('Проходит собеседование в ТК ЧВК "Карбон". (ЛКН)')
    imgui.TextWrapped('Проходит собеседование в Суши бар "Последний самурай". (Якудза)')
    imgui.Separator()
end
                  if imgui.CollapsingHeader('Тип подачи обьявления') then
        imgui.TextWrapped("м/д - Модификация")
        imgui.TextWrapped("г. - Город")   
        imgui.TextWrapped("а/с - Аксессуар")
        imgui.TextWrapped("р/с - Ресурс")
        imgui.TextWrapped("д/т - Деталь тюнинга")
        imgui.TextWrapped("т/с - Транспорт")
        imgui.TextWrapped("в/с - Велосипед")
        imgui.TextWrapped("в/т - Вертолет")
        imgui.TextWrapped("с/м - Самолёт")
        imgui.TextWrapped("м/ц - Мотоцикл")
        imgui.TextWrapped("а/м - Автомобиль")
        imgui.TextWrapped("л/д - Лодка")
        imgui.TextWrapped("б/з - Бизнес")
        imgui.TextWrapped("н/м - номерной знак")
end
elseif tab == 2 then
    if imgui.Checkbox('Авто-Ловля обьявлений', checkboxone) then
function samp.onServerMessage(clr, msg)
	if msg:find('^Обработку') then
		sampSendChat('/newsredak')
		sampAddChatMessage("{FFFFFF}[{4b8078}Auto Lovlya{FFFFFF}] {257699}Сюда",-1)
	end
end
end
if imgui.Button('Прочекать Members') then
    sampSendChat('/members')
end
if imgui.Button('Прочекать объявления') then
    sampSendChat('/newsredak')
end
if imgui.CollapsingHeader('Биндеры') then
if imgui.Button('Отказ, причина: NRP NICK') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'/b У вас не подходит Nickname, смени его.')
    wait(1000)
    sampSendChat(monet_utf8_to_cp1251'Извините, вы к нам не подходите у вас отпечатка в паспорте.')
    return true
end)
end
if imgui.Button('Вы приняты!') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'Вы приняты! Берите форму, переодевайтесь и за работу!')
    wait(1300)
    sampSendChat(monet_utf8_to_cp1251'/me открыл шкафчик, достал форму и передал человеку напротив')
    return true
end)
end
if imgui.Button(('Приём в организацию (invite)')) then
                    lua_thread.create(function()
                        sampSendChat(monet_utf8_to_cp1251"/do Под стойкой находится Портфель.")
            wait(1500)
            sampSendChat(monet_utf8_to_cp1251"/do Форма в Портфеле...")
            wait(1500)
            sampSendChat(monet_utf8_to_cp1251"/me сунул руку в портфель, после чего взял форму и бейджик в руки")
            wait(1500)
            sampSendChat(monet_utf8_to_cp1251"/me передает форму и бейджик человеку на против")
            wait(1500)
            sampSendChat(monet_utf8_to_cp1251"/todo Идите переоденьтесь*указывая пальцем на дверь раздевалки")
            wait(1500)
            sampSendChat(monet_utf8_to_cp1251'/invite ' .. ids[0])
                    end)
                end
                if imgui.Button("Нет паспорта") then
                       lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251"/todo К сожалению, вы нам не подходите.*с разочарованием на лице")
					wait(2000)
					sampSendChat(monet_utf8_to_cp1251"У вас нет паспорта.")
					wait(2000)
					sampSendChat(monet_utf8_to_cp1251"/b Получите паспорт в мэрии.")
end)
        end
        if imgui.Button("Нет Мед. карты") then
                       lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251"/todo К сожалению, вы нам не подходите.*с разочарованием на лице")
					wait(2000)
					sampSendChat(monet_utf8_to_cp1251"У вас нет мед. карты.")
					wait(2000)
					sampSendChat(monet_utf8_to_cp1251"/b Получите мед. карту в больнице.")
end)
        end
        if imgui.Button("Состоит в орг") then
                       lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251"/todo К сожалению, вы нам не подходите.*с разочарованием на лице")
					wait(2000)
					sampSendChat(monet_utf8_to_cp1251"Вы уже состоите в организации.")
					wait(2000)
					sampSendChat(monet_utf8_to_cp1251"/b Увольтесь из вашей организации.")
end)
        end
        if imgui.Button("Нет РП") then
                       lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251"/do Планшет с базой данных в руках.")
					wait(2000)
					sampSendChat(monet_utf8_to_cp1251"/me нашел человека в базе данных")
					wait(2000)
					sampSendChat(monet_utf8_to_cp1251"/todo К сожалению, вы нам не подходите.*с разочарованием на лице")
					wait(2000)
					sampSendChat(monet_utf8_to_cp1251"Вы проф. не пригодны для нашей работы.")
					wait(2000)
					sampSendChat(monet_utf8_to_cp1251"/b Вы плохо отыграли РП.")
end)
        end
end
if imgui.CollapsingHeader('RP-Отыгровки') then
if imgui.Button('Передача паспорта') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'/me сунул левую руку в карман')
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'/do Рука в кармане.')
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'/me нащупывает паспорт')
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'/me нащупал паспорт')
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'/do Паспорт в руке.')
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'/me вытащил руку с кармана')
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'/me передал паспорт человеку на против')
    wait(1500)
    sampSendChat('/showpass ' .. ids[0])
    wait(1500)
end)
end
if imgui.Button('Передача лицензий') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'/me сунул руку в карман')
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'/do Рука в кармане.')
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'/me ищет пакет лицензий')
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'/me нащупал пакет лицензий')
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'/do Пакет в руке.')
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'/me вытащил руку с кармана')
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'/me передал пакет лицензий человеку на против')
    wait(1500)
    sampSendChat('/showlic ' .. ids[0])
    wait(1500)
end)
end
if imgui.Button('Передача мед.карты') then
lua_thread.create(function()
sampSendChat(monet_utf8_to_cp1251"/do Мед.Карта в кармане.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/me просунул руку в карман, затем достал мед.карту")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/do Мед.Карта находится в левой руке.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/me передал мед.карту человеку напротив")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"Вот держите, только осматривайте аккуратно пожалуйста, она хрупкая!")
wait(1500)
sampSendChat(monet_utf8_to_cp1251'/showmc '.. ids[0])
end)
end
if imgui.Button('Вся папка с документами') then
lua_thread.create(function()
sampSendChat(monet_utf8_to_cp1251"/do Папка с документами лежит в сумке.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/me достал папку с документами")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/do Папка с документами в левой руке.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/me открыл папку и просмотрел её на наличие всей документации")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/do Вся документация в норме.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/me закрыл папку и передал ее человеку напротив")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"Вот откройте её и щас я вам все подробно покажу.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/showpass " .. ids[0])
wait(2000)
sampSendChat(monet_utf8_to_cp1251"/showlic " .. ids[0])
wait(2000)
sampSendChat(monet_utf8_to_cp1251"/showmc " .. ids[0])
wait(2000)
sampSendChat(monet_utf8_to_cp1251"Всё, это все мои документы!")
end)
end
if imgui.Button('Вся документация БЕЗ РП') then
lua_thread.create(function()
sampSendChat(monet_utf8_to_cp1251"/showpass " .. ids[0])
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/showmc " .. ids[0])
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/showlic " .. ids[0])
end)
end
if imgui.Button('Паспорт в случае остановки копов') then
lua_thread.create(function()
sampSendChat(monet_utf8_to_cp1251"Здравствуйте, секундочку.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/do Паспорт в бардочке.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/me открыл бардочок затем достал паспорт")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/do Паспорт в руке.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/me протянув руку через окно, передал паспорт полицейскому")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/showpass " .. ids[0])
end)
end
if imgui.Button('Начать придератся к полицейскому') then
lua_thread.create(function()
sampSendChat(monet_utf8_to_cp1251"Сэр, по правиду проведения трафик-стопа 10-55...")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"...Вы обязательно должны докоснутся до фары/багажника/бампера машины останавливаемого...")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"...Так-же вы должны были спросить открыто-ли у меня окно, если закрыто попросить открыть")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"Сразу-же после этого предъявить жетон, потом сказать нарушителю причину вашей остановки ")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"После остановки водителя проверьте его местоположение, он должен находиться на обочине.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"Припаркуйте вашу патрульную машину за машиной подозреваемого так, чтобы ваша передняя правая фара была на одном уровне с серединой багажника автомобиля задержанного.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"Расстояние между автомобилями должно быть 5 метров.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"Половину из этого вы не выполнили поэтому я смело могу написать жалобу на увольнение вас на офф.портал")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/do На руке висят часы.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/me поднеся руку к лицу, взглянул на часы ")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/time ")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/do Часы показывают: " ..os.date('%H:%M:%S'))
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/id " .. ids[0])
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/do Часы висят на руке.")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/me поднес руку с часами к лицу и посмотрел на время")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/time")
wait(1500)
sampSendChat(monet_utf8_to_cp1251"/do Часы показывают: " ..os.date('%H:%M:%S'))
end)
end
if imgui.Button('Приветсвие') then
lua_thread.create(function()
    sampSendChat((monet_utf8_to_cp1251"Здравствуйте меня зовут " .. sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))))
    wait(1500)
    sampSendChat(monet_utf8_to_cp1251'Чем могу быть вам полезен?')
    wait(1500)
end)
end
end


if imgui.Button('ПРО') then
    window_three[0] = not window_three[0]


end
local _, changed = imgui.InputInt('ID Игрока', ids)
                if changed then
                    ids = imgui.new.int(ids[0])
                end
elseif tab == 3 then
imgui.Text('КОМАНДЫ СМИ')
if imgui.BeginChild('Команды СМИ', imgui.ImVec2(500, 300), true) then
imgui.Text("• /invite")
imgui.Text("• /exp")
imgui.Text("• /sob")
imgui.Text("• /members")
imgui.Text("• /uninvite")
imgui.Text("• /giverank")
imgui.Text("• /r")
imgui.Text("• /news")
imgui.Text("• /live")
imgui.Text("• /endlive")
imgui.Text("• /newsredak")
imgui.Text("• /fmute")
imgui.Text("• /funmute")
imgui.Text("• /unfwarn")
imgui.Text("• /warn")
imgui.Text("• /unblacklist")
    imgui.EndChild() -- обязательно следите за тем, чтобы каждый чайлд был закрыт
end
elseif tab == 4 then
    imgui.InputTextWithHint('##Search','Поиск',search,256) -- создаём инпут поле в котором будет вводится нужный текст
    imgui.SameLine()
    if imgui.Button('Очистить') then -- создаём кнопку, чтобы быстро очищать инпут
        imgui.StrCopy(search,'') -- задаём в инпут пустоту
        end
    for k,v in pairs(commands) do -- парсим таблицу с текстом
        if (v):find(ffi.string(search)) then -- если значение с таблицы u8(v) совпадает со значением инпута ffi.string(search), то
            imgui.Text(v) -- отображаем текст
 end
    imgui.End()
    end
elseif tab == 5 then
imgui.Text("                           SMI-HELPER BY LUA-SCRIPTER")
imgui.Text("                                    Version: 1.00")
imgui.Text('Текущее Время: '..os.date('%H:%M:%S'))
imgui.Text('Дата: '..arr.day..'.'.. arr.month..'.'..arr.year)
imgui.CenterText(("Ник: " .. sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))))
imgui.CenterText(("Фамилия: " .. sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))):gsub(".+_", "")))
if imgui.Button('Открыть окно с временем') then
    window_two[0] = not window_two[0]
end
if imgui.Combo('Тема', theme, new['const char*'][#themesList](themesList), #themesList) then 
			themes[theme[0]+1].func() 
			iniSave() 
		end
		if imgui.Combo('Стиль', style, new['const char*'][#stylesList](stylesList), #stylesList) then 
			styles[style[0]+1].func() 
			iniSave() 
		end
		end
	imgui.End()
end)

function iniSave()
	ini.cfg.theme = theme[0]
	ini.cfg.style = style[0]
	inicfg.save(ini, iniFile)
end

styles = {
	{
		name = 'Строгий',
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			style.WindowRounding = 0
			style.ChildRounding = 0
			style.FrameRounding = 0
			style.ItemSpacing = imgui.ImVec2(3.0, 3.0)
			style.ItemInnerSpacing = imgui.ImVec2(3.0, 3.0)
			style.FramePadding = imgui.ImVec2(4.0, 3.0)
			style.IndentSpacing = 21
			style.ScrollbarSize = 10.0
			style.ScrollbarRounding = 0
			style.GrabMinSize = 17.0
			style.GrabRounding = 0
			style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
			style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
		end
	},
	{
		name = 'Мягкий',
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			style.WindowRounding = 10
			style.ChildRounding = 10
			style.FrameRounding = 6.0
			style.ItemSpacing = imgui.ImVec2(3.0, 3.0)
			style.ItemInnerSpacing = imgui.ImVec2(3.0, 3.0)
			style.FramePadding = imgui.ImVec2(4.0, 3.0)
			style.IndentSpacing = 21
			style.ScrollbarSize = 10.0
			style.ScrollbarRounding = 13
			style.GrabMinSize = 17.0
			style.GrabRounding = 16.0
			style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
			style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
		end
	}
}

themes = {
	{
		name = 'Зелёная',
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.Text]				   = ImVec4(0.90, 0.90, 0.90, 1.00)
			colors[clr.TextDisabled]		   = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.WindowBg]			   = ImVec4(0.08, 0.08, 0.08, 1.00)
			colors[clr.ChildBg]		  = ImVec4(0.10, 0.10, 0.10, 0.40)
			colors[clr.PopupBg]				= ImVec4(0.08, 0.08, 0.08, 1.00)
			colors[clr.Border]				 = ImVec4(0.70, 0.70, 0.70, 0.40)
			colors[clr.BorderShadow]		   = ImVec4(0.00, 0.00, 0.00, 0.00)
			colors[clr.FrameBg]				= ImVec4(0.15, 0.15, 0.15, 1.00)
			colors[clr.FrameBgHovered]		 = ImVec4(0.19, 0.19, 0.19, 0.71)
			colors[clr.FrameBgActive]		  = ImVec4(0.34, 0.34, 0.34, 0.79)
			colors[clr.TitleBg]				= ImVec4(0.00, 0.69, 0.33, 0.80)
			colors[clr.TitleBgActive]		  = ImVec4(0.00, 0.74, 0.36, 1.00)
			colors[clr.TitleBgCollapsed]	   = ImVec4(0.00, 0.69, 0.33, 0.50)
			colors[clr.MenuBarBg]			  = ImVec4(0.00, 0.80, 0.38, 1.00)
			colors[clr.ScrollbarBg]			= ImVec4(0.16, 0.16, 0.16, 1.00)
			colors[clr.ScrollbarGrab]		  = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.ScrollbarGrabHovered]   = ImVec4(0.00, 0.82, 0.39, 1.00)
			colors[clr.ScrollbarGrabActive]	= ImVec4(0.00, 1.00, 0.48, 1.00)
			colors[clr.CheckMark]			  = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.SliderGrab]			 = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.SliderGrabActive]	   = ImVec4(0.00, 0.77, 0.37, 1.00)
			colors[clr.Button]				 = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.ButtonHovered]		  = ImVec4(0.00, 0.82, 0.39, 1.00)
			colors[clr.ButtonActive]		   = ImVec4(0.00, 0.87, 0.42, 1.00)
			colors[clr.Header]				 = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.HeaderHovered]		  = ImVec4(0.00, 0.76, 0.37, 0.57)
			colors[clr.HeaderActive]		   = ImVec4(0.00, 0.88, 0.42, 0.89)
			colors[clr.Separator]			  = ImVec4(1.00, 1.00, 1.00, 0.40)
			colors[clr.SeparatorHovered]	   = ImVec4(1.00, 1.00, 1.00, 0.60)
			colors[clr.SeparatorActive]		= ImVec4(1.00, 1.00, 1.00, 0.80)
			colors[clr.ResizeGrip]			 = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.ResizeGripHovered]	  = ImVec4(0.00, 0.76, 0.37, 1.00)
			colors[clr.ResizeGripActive]	   = ImVec4(0.00, 0.86, 0.41, 1.00)
			colors[clr.PlotLines]			  = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.PlotLinesHovered]	   = ImVec4(0.00, 0.74, 0.36, 1.00)
			colors[clr.PlotHistogram]		  = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.PlotHistogramHovered]   = ImVec4(0.00, 0.80, 0.38, 1.00)
			colors[clr.TextSelectedBg]		 = ImVec4(0.00, 0.69, 0.33, 0.72)
			colors[clr.ModalWindowDimBg]   = ImVec4(0.17, 0.17, 0.17, 0.48)
		end
	},
	{
		name = 'Красная',
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.Text]				   = ImVec4(0.95, 0.96, 0.98, 1.00)
			colors[clr.TextDisabled]		   = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.WindowBg]			   = ImVec4(0.14, 0.14, 0.14, 1.00)
			colors[clr.ChildBg]		  = ImVec4(0.12, 0.12, 0.12, 0.40)
			colors[clr.PopupBg]				= ImVec4(0.08, 0.08, 0.08, 0.94)
			colors[clr.Border]				 = ImVec4(0.14, 0.14, 0.14, 1.00)
			colors[clr.BorderShadow]		   = ImVec4(1.00, 1.00, 1.00, 0.00)
			colors[clr.FrameBg]				= ImVec4(0.22, 0.22, 0.22, 1.00)
			colors[clr.FrameBgHovered]		 = ImVec4(0.18, 0.18, 0.18, 1.00)
			colors[clr.FrameBgActive]		  = ImVec4(0.09, 0.12, 0.14, 1.00)
			colors[clr.TitleBg]				= ImVec4(0.14, 0.14, 0.14, 0.81)
			colors[clr.TitleBgActive]		  = ImVec4(0.14, 0.14, 0.14, 1.00)
			colors[clr.TitleBgCollapsed]	   = ImVec4(0.00, 0.00, 0.00, 0.51)
			colors[clr.MenuBarBg]			  = ImVec4(0.20, 0.20, 0.20, 1.00)
			colors[clr.ScrollbarBg]			= ImVec4(0.02, 0.02, 0.02, 0.39)
			colors[clr.ScrollbarGrab]		  = ImVec4(0.36, 0.36, 0.36, 1.00)
			colors[clr.ScrollbarGrabHovered]   = ImVec4(0.18, 0.22, 0.25, 1.00)
			colors[clr.ScrollbarGrabActive]	= ImVec4(0.24, 0.24, 0.24, 1.00)
			colors[clr.CheckMark]			  = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.SliderGrab]			 = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.SliderGrabActive]	   = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.Button]				 = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.ButtonHovered]		  = ImVec4(1.00, 0.39, 0.39, 1.00)
			colors[clr.ButtonActive]		   = ImVec4(1.00, 0.21, 0.21, 1.00)
			colors[clr.Header]				 = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.HeaderHovered]		  = ImVec4(1.00, 0.39, 0.39, 1.00)
			colors[clr.HeaderActive]		   = ImVec4(1.00, 0.21, 0.21, 1.00)
			colors[clr.ResizeGrip]			 = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.ResizeGripHovered]	  = ImVec4(1.00, 0.39, 0.39, 1.00)
			colors[clr.PlotLines]			  = ImVec4(0.61, 0.61, 0.61, 1.00)
			colors[clr.PlotLinesHovered]	   = ImVec4(1.00, 0.43, 0.35, 1.00)
			colors[clr.PlotHistogram]		  = ImVec4(1.00, 0.21, 0.21, 1.00)
			colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.18, 0.18, 1.00)
			colors[clr.TextSelectedBg]		 = ImVec4(1.00, 0.32, 0.32, 1.00)
			colors[clr.ModalWindowDimBg]   = ImVec4(0.26, 0.26, 0.26, 0.60)
		end
	},
	{
		name = 'Пурпурная',
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.FrameBg]				= ImVec4(0.46, 0.11, 0.29, 1.00)
			colors[clr.FrameBgHovered]		 = ImVec4(0.69, 0.16, 0.43, 1.00)
			colors[clr.FrameBgActive]		  = ImVec4(0.58, 0.10, 0.35, 1.00)
			colors[clr.TitleBg]				= ImVec4(0.00, 0.00, 0.00, 1.00)
			colors[clr.TitleBgActive]		  = ImVec4(0.61, 0.16, 0.39, 1.00)
			colors[clr.TitleBgCollapsed]	   = ImVec4(0.00, 0.00, 0.00, 0.51)
			colors[clr.CheckMark]			  = ImVec4(0.94, 0.30, 0.63, 1.00)
			colors[clr.SliderGrab]			 = ImVec4(0.85, 0.11, 0.49, 1.00)
			colors[clr.SliderGrabActive]	   = ImVec4(0.89, 0.24, 0.58, 1.00)
			colors[clr.Button]				 = ImVec4(0.46, 0.11, 0.29, 1.00)
			colors[clr.ButtonHovered]		  = ImVec4(0.69, 0.17, 0.43, 1.00)
			colors[clr.ButtonActive]		   = ImVec4(0.59, 0.10, 0.35, 1.00)
			colors[clr.Header]				 = ImVec4(0.46, 0.11, 0.29, 1.00)
			colors[clr.HeaderHovered]		  = ImVec4(0.69, 0.16, 0.43, 1.00)
			colors[clr.HeaderActive]		   = ImVec4(0.58, 0.10, 0.35, 1.00)
			colors[clr.Separator]			  = ImVec4(0.69, 0.16, 0.43, 1.00)
			colors[clr.SeparatorHovered]	   = ImVec4(0.58, 0.10, 0.35, 1.00)
			colors[clr.SeparatorActive]		= ImVec4(0.58, 0.10, 0.35, 1.00)
			colors[clr.ResizeGrip]			 = ImVec4(0.46, 0.11, 0.29, 0.70)
			colors[clr.ResizeGripHovered]	  = ImVec4(0.69, 0.16, 0.43, 0.67)
			colors[clr.ResizeGripActive]	   = ImVec4(0.70, 0.13, 0.42, 1.00)
			colors[clr.TextSelectedBg]		 = ImVec4(1.00, 0.78, 0.90, 0.35)
			colors[clr.Text]				   = ImVec4(1.00, 1.00, 1.00, 1.00)
			colors[clr.TextDisabled]		   = ImVec4(0.60, 0.19, 0.40, 1.00)
			colors[clr.WindowBg]			   = ImVec4(0.06, 0.06, 0.06, 0.94)
			colors[clr.ChildBg]		  = ImVec4(0.00, 0.00, 0.00, 0.40)
			colors[clr.PopupBg]				= ImVec4(0.08, 0.08, 0.08, 0.94)
			colors[clr.Border]				 = ImVec4(0.49, 0.14, 0.31, 1.00)
			colors[clr.BorderShadow]		   = ImVec4(0.49, 0.14, 0.31, 0.00)
			colors[clr.MenuBarBg]			  = ImVec4(0.15, 0.15, 0.15, 1.00)
			colors[clr.ScrollbarBg]			= ImVec4(0.02, 0.02, 0.02, 0.53)
			colors[clr.ScrollbarGrab]		  = ImVec4(0.31, 0.31, 0.31, 1.00)
			colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
			colors[clr.ScrollbarGrabActive]	= ImVec4(0.51, 0.51, 0.51, 1.00)
			colors[clr.ModalWindowDimBg]   = ImVec4(0.80, 0.80, 0.80, 0.35)
		end
	},
	{
		name = 'Фиолетовая',
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.WindowBg]			  = ImVec4(0.14, 0.12, 0.16, 1.00)
			colors[clr.ChildBg]		 = ImVec4(0.30, 0.20, 0.39, 0.40)
			colors[clr.PopupBg]			   = ImVec4(0.05, 0.05, 0.10, 0.90)
			colors[clr.Border]				= ImVec4(0.89, 0.85, 0.92, 0.30)
			colors[clr.BorderShadow]		  = ImVec4(0.00, 0.00, 0.00, 0.00)
			colors[clr.FrameBg]			   = ImVec4(0.30, 0.20, 0.39, 1.00)
			colors[clr.FrameBgHovered]		= ImVec4(0.41, 0.19, 0.63, 0.68)
			colors[clr.FrameBgActive]		 = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.TitleBg]			   = ImVec4(0.41, 0.19, 0.63, 0.45)
			colors[clr.TitleBgCollapsed]	  = ImVec4(0.41, 0.19, 0.63, 0.35)
			colors[clr.TitleBgActive]		 = ImVec4(0.41, 0.19, 0.63, 0.78)
			colors[clr.MenuBarBg]			 = ImVec4(0.30, 0.20, 0.39, 0.57)
			colors[clr.ScrollbarBg]		   = ImVec4(0.30, 0.20, 0.39, 1.00)
			colors[clr.ScrollbarGrab]		 = ImVec4(0.41, 0.19, 0.63, 0.31)
			colors[clr.ScrollbarGrabHovered]  = ImVec4(0.41, 0.19, 0.63, 0.78)
			colors[clr.ScrollbarGrabActive]   = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.CheckMark]			 = ImVec4(0.56, 0.61, 1.00, 1.00)
			colors[clr.SliderGrab]			= ImVec4(0.41, 0.19, 0.63, 0.24)
			colors[clr.SliderGrabActive]	  = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.Button]				= ImVec4(0.41, 0.19, 0.63, 0.44)
			colors[clr.ButtonHovered]		 = ImVec4(0.41, 0.19, 0.63, 0.86)
			colors[clr.ButtonActive]		  = ImVec4(0.64, 0.33, 0.94, 1.00)
			colors[clr.Header]				= ImVec4(0.41, 0.19, 0.63, 0.76)
			colors[clr.HeaderHovered]		 = ImVec4(0.41, 0.19, 0.63, 0.86)
			colors[clr.HeaderActive]		  = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.ResizeGrip]			= ImVec4(0.41, 0.19, 0.63, 0.20)
			colors[clr.ResizeGripHovered]	 = ImVec4(0.41, 0.19, 0.63, 0.78)
			colors[clr.ResizeGripActive]	  = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.PlotLines]			 = ImVec4(0.89, 0.85, 0.92, 0.63)
			colors[clr.PlotLinesHovered]	  = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.PlotHistogram]		 = ImVec4(0.89, 0.85, 0.92, 0.63)
			colors[clr.PlotHistogramHovered]  = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.TextSelectedBg]		= ImVec4(0.41, 0.19, 0.63, 0.43)
			colors[clr.TextDisabled]		  = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.ModalWindowDimBg]  = ImVec4(0.20, 0.20, 0.20, 0.35)
		end
	},
	{
		name = 'Вишнёвая',
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.Text]				  = ImVec4(0.86, 0.93, 0.89, 0.78)
			colors[clr.TextDisabled]		  = ImVec4(0.71, 0.22, 0.27, 1.00)
			colors[clr.WindowBg]			  = ImVec4(0.13, 0.14, 0.17, 1.00)
			colors[clr.ChildBg]		 = ImVec4(0.20, 0.22, 0.27, 0.58)
			colors[clr.PopupBg]			   = ImVec4(0.20, 0.22, 0.27, 0.90)
			colors[clr.Border]				= ImVec4(0.31, 0.31, 1.00, 0.00)
			colors[clr.BorderShadow]		  = ImVec4(0.00, 0.00, 0.00, 0.00)
			colors[clr.FrameBg]			   = ImVec4(0.20, 0.22, 0.27, 1.00)
			colors[clr.FrameBgHovered]		= ImVec4(0.46, 0.20, 0.30, 0.78)
			colors[clr.FrameBgActive]		 = ImVec4(0.46, 0.20, 0.30, 1.00)
			colors[clr.TitleBg]			   = ImVec4(0.23, 0.20, 0.27, 1.00)
			colors[clr.TitleBgActive]		 = ImVec4(0.50, 0.08, 0.26, 1.00)
			colors[clr.TitleBgCollapsed]	  = ImVec4(0.20, 0.20, 0.27, 0.75)
			colors[clr.MenuBarBg]			 = ImVec4(0.20, 0.22, 0.27, 0.47)
			colors[clr.ScrollbarBg]		   = ImVec4(0.20, 0.22, 0.27, 1.00)
			colors[clr.ScrollbarGrab]		 = ImVec4(0.09, 0.15, 0.10, 1.00)
			colors[clr.ScrollbarGrabHovered]  = ImVec4(0.46, 0.20, 0.30, 0.78)
			colors[clr.ScrollbarGrabActive]   = ImVec4(0.46, 0.20, 0.30, 1.00)
			colors[clr.CheckMark]			 = ImVec4(0.71, 0.22, 0.27, 1.00)
			colors[clr.SliderGrab]			= ImVec4(0.47, 0.77, 0.83, 0.14)
			colors[clr.SliderGrabActive]	  = ImVec4(0.71, 0.22, 0.27, 1.00)
			colors[clr.Button]				= ImVec4(0.47, 0.77, 0.83, 0.14)
			colors[clr.ButtonHovered]		 = ImVec4(0.46, 0.20, 0.30, 0.86)
			colors[clr.ButtonActive]		  = ImVec4(0.46, 0.20, 0.30, 1.00)
			colors[clr.Header]				= ImVec4(0.46, 0.20, 0.30, 0.76)
			colors[clr.HeaderHovered]		 = ImVec4(0.46, 0.20, 0.30, 0.86)
			colors[clr.HeaderActive]		  = ImVec4(0.50, 0.08, 0.26, 1.00)
			colors[clr.ResizeGrip]			= ImVec4(0.47, 0.77, 0.83, 0.04)
			colors[clr.ResizeGripHovered]	 = ImVec4(0.46, 0.20, 0.30, 0.78)
			colors[clr.ResizeGripActive]	  = ImVec4(0.46, 0.20, 0.30, 1.00)
			colors[clr.PlotLines]			 = ImVec4(0.86, 0.93, 0.89, 0.63)
			colors[clr.PlotLinesHovered]	  = ImVec4(0.46, 0.20, 0.30, 1.00)
			colors[clr.PlotHistogram]		 = ImVec4(0.86, 0.93, 0.89, 0.63)
			colors[clr.PlotHistogramHovered]  = ImVec4(0.46, 0.20, 0.30, 1.00)
			colors[clr.TextSelectedBg]		= ImVec4(0.46, 0.20, 0.30, 0.43)
			colors[clr.ModalWindowDimBg]  = ImVec4(0.20, 0.22, 0.27, 0.73)
		end
	},
	{
		name = 'Жёлтая',
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.Text]				 = ImVec4(0.92, 0.92, 0.92, 1.00)
			colors[clr.TextDisabled]		 = ImVec4(0.78, 0.55, 0.21, 1.00)
			colors[clr.WindowBg]			 = ImVec4(0.06, 0.06, 0.06, 1.00)
			colors[clr.ChildBg]		= ImVec4(0.00, 0.00, 0.00, 0.40)
			colors[clr.PopupBg]			  = ImVec4(0.08, 0.08, 0.08, 0.94)
			colors[clr.Border]			   = ImVec4(0.51, 0.36, 0.15, 1.00)
			colors[clr.BorderShadow]		 = ImVec4(0.00, 0.00, 0.00, 0.00)
			colors[clr.FrameBg]			  = ImVec4(0.11, 0.11, 0.11, 1.00)
			colors[clr.FrameBgHovered]	   = ImVec4(0.51, 0.36, 0.15, 1.00)
			colors[clr.FrameBgActive]		= ImVec4(0.78, 0.55, 0.21, 1.00)
			colors[clr.TitleBg]			  = ImVec4(0.51, 0.36, 0.15, 1.00)
			colors[clr.TitleBgActive]		= ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.TitleBgCollapsed]	 = ImVec4(0.00, 0.00, 0.00, 0.51)
			colors[clr.MenuBarBg]			= ImVec4(0.11, 0.11, 0.11, 1.00)
			colors[clr.ScrollbarBg]		  = ImVec4(0.06, 0.06, 0.06, 0.53)
			colors[clr.ScrollbarGrab]		= ImVec4(0.21, 0.21, 0.21, 1.00)
			colors[clr.ScrollbarGrabHovered] = ImVec4(0.47, 0.47, 0.47, 1.00)
			colors[clr.ScrollbarGrabActive]  = ImVec4(0.81, 0.83, 0.81, 1.00)
			colors[clr.CheckMark]			= ImVec4(0.78, 0.55, 0.21, 1.00)
			colors[clr.SliderGrab]		   = ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.SliderGrabActive]	 = ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.Button]			   = ImVec4(0.51, 0.36, 0.15, 1.00)
			colors[clr.ButtonHovered]		= ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.ButtonActive]		 = ImVec4(0.78, 0.55, 0.21, 1.00)
			colors[clr.Header]			   = ImVec4(0.51, 0.36, 0.15, 1.00)
			colors[clr.HeaderHovered]		= ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.HeaderActive]		 = ImVec4(0.93, 0.65, 0.14, 1.00)
			colors[clr.Separator]			= ImVec4(0.21, 0.21, 0.21, 1.00)
			colors[clr.SeparatorHovered]	 = ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.SeparatorActive]	  = ImVec4(0.78, 0.55, 0.21, 1.00)
			colors[clr.ResizeGrip]		   = ImVec4(0.21, 0.21, 0.21, 1.00)
			colors[clr.ResizeGripHovered]	= ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.ResizeGripActive]	 = ImVec4(0.78, 0.55, 0.21, 1.00)
			colors[clr.PlotLines]			= ImVec4(0.61, 0.61, 0.61, 1.00)
			colors[clr.PlotLinesHovered]	 = ImVec4(1.00, 0.43, 0.35, 1.00)
			colors[clr.PlotHistogram]		= ImVec4(0.90, 0.70, 0.00, 1.00)
			colors[clr.PlotHistogramHovered] = ImVec4(1.00, 0.60, 0.00, 1.00)
			colors[clr.TextSelectedBg]	   = ImVec4(0.26, 0.59, 0.98, 0.35)
			colors[clr.ModalWindowDimBg] = ImVec4(0.80, 0.80, 0.80, 0.35)
		end
	},
	{
		name = 'Темная',
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
  style.WindowPadding = imgui.ImVec2(5, 5)
  style.FramePadding = imgui.ImVec2(10, 10)
  style.ItemSpacing = imgui.ImVec2(10, 10)
  style.ItemInnerSpacing = imgui.ImVec2(5, 5)
  style.TouchExtraPadding = imgui.ImVec2(5 * MONET_DPI_SCALE, 5 * MONET_DPI_SCALE)
  style.IndentSpacing = 0
  style.ScrollbarSize = 20 * MONET_DPI_SCALE
  style.GrabMinSize = 20 * MONET_DPI_SCALE

  --==[ BORDER ]==--
  style.WindowBorderSize = 1
  style.ChildBorderSize = 1
  style.PopupBorderSize = 1
  style.FrameBorderSize = 1
  style.TabBorderSize = 1

  --==[ ROUNDING ]==--
  style.WindowRounding = 5
  style.ChildRounding = 5
  style.FrameRounding = 5
  style.PopupRounding = 5
  style.ScrollbarRounding = 5
  style.GrabRounding = 5
  style.TabRounding = 5

  --==[ ALIGN ]==--
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
	},
	{
		name = 'Кровавая',
		func = function()
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

    imgui.GetStyle().Colors[imgui.Col.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]           = ImVec4(1.00, 1.00, 1.00, 0.43);
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = ImVec4(0.00, 0.00, 0.00, 0.90);
    imgui.GetStyle().Colors[imgui.Col.ChildBg]                = ImVec4(1.00, 1.00, 1.00, 0.07);
    imgui.GetStyle().Colors[imgui.Col.PopupBg]                = ImVec4(0.00, 0.00, 0.00, 0.94);
    imgui.GetStyle().Colors[imgui.Col.Border]                 = ImVec4(1.00, 1.00, 1.00, 0.00);
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]           = ImVec4(1.00, 0.00, 0.00, 0.32);
    imgui.GetStyle().Colors[imgui.Col.FrameBg]                = ImVec4(1.00, 1.00, 1.00, 0.09);
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = ImVec4(1.00, 1.00, 1.00, 0.17);
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = ImVec4(1.00, 1.00, 1.00, 0.26);
    imgui.GetStyle().Colors[imgui.Col.TitleBg]                = ImVec4(0.19, 0.00, 0.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]          = ImVec4(0.46, 0.00, 0.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]       = ImVec4(0.20, 0.00, 0.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]              = ImVec4(0.14, 0.03, 0.03, 1.00);
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]            = ImVec4(0.19, 0.00, 0.00, 0.53);
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]          = ImVec4(1.00, 1.00, 1.00, 0.11);
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]   = ImVec4(1.00, 1.00, 1.00, 0.24);
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]    = ImVec4(1.00, 1.00, 1.00, 0.35);
    imgui.GetStyle().Colors[imgui.Col.CheckMark]              = ImVec4(1.00, 1.00, 1.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]             = ImVec4(1.00, 0.00, 0.00, 0.34);
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]       = ImVec4(1.00, 0.00, 0.00, 0.51);
    imgui.GetStyle().Colors[imgui.Col.Button]                 = ImVec4(1.00, 0.00, 0.00, 0.19);
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = ImVec4(1.00, 0.00, 0.00, 0.31);
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = ImVec4(1.00, 0.00, 0.00, 0.46);
    imgui.GetStyle().Colors[imgui.Col.Header]                 = ImVec4(1.00, 0.00, 0.00, 0.19);
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = ImVec4(1.00, 0.00, 0.00, 0.30);
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = ImVec4(1.00, 0.00, 0.00, 0.50);
    imgui.GetStyle().Colors[imgui.Col.Separator]              = ImVec4(1.00, 0.00, 0.00, 0.41);
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]       = ImVec4(1.00, 1.00, 1.00, 0.78);
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]        = ImVec4(1.00, 1.00, 1.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]             = ImVec4(0.19, 0.00, 0.00, 0.53);
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]      = ImVec4(0.43, 0.00, 0.00, 0.75);
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]       = ImVec4(0.53, 0.00, 0.00, 0.95);
    imgui.GetStyle().Colors[imgui.Col.Tab]                    = ImVec4(1.00, 0.00, 0.00, 0.27);
    imgui.GetStyle().Colors[imgui.Col.TabHovered]             = ImVec4(1.00, 0.00, 0.00, 0.48);
    imgui.GetStyle().Colors[imgui.Col.TabActive]              = ImVec4(1.00, 0.00, 0.00, 0.60);
    imgui.GetStyle().Colors[imgui.Col.TabUnfocused]           = ImVec4(1.00, 0.00, 0.00, 0.27);
    imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive]     = ImVec4(1.00, 0.00, 0.00, 0.54);
    imgui.GetStyle().Colors[imgui.Col.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00);
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00);
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00);
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]         = ImVec4(1.00, 1.00, 1.00, 0.35);
    imgui.GetStyle().Colors[imgui.Col.DragDropTarget]         = ImVec4(1.00, 1.00, 0.00, 0.90);
    imgui.GetStyle().Colors[imgui.Col.NavHighlight]           = ImVec4(0.26, 0.59, 0.98, 1.00);
    imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight]  = ImVec4(1.00, 1.00, 1.00, 0.70);
    imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg]      = ImVec4(0.80, 0.80, 0.80, 0.20);
    imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg]       = ImVec4(0.80, 0.80, 0.80, 0.35);
end
	},
	{
		name = 'Синяя',
		func = function()
			local ImVec4 = imgui.ImVec4
            imgui.SwitchContext()
            imgui.GetStyle().Colors[imgui.Col.WindowBg]               = ImVec4(0.08, 0.08, 0.08, 1.00)
            imgui.GetStyle().Colors[imgui.Col.FrameBg]                = ImVec4(0.16, 0.29, 0.48, 0.54)
            imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = ImVec4(0.26, 0.59, 0.98, 0.40)
            imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = ImVec4(0.26, 0.59, 0.98, 0.67)
            imgui.GetStyle().Colors[imgui.Col.TitleBg]                = ImVec4(0.04, 0.04, 0.04, 1.00)
            imgui.GetStyle().Colors[imgui.Col.TitleBgActive]          = ImVec4(0.16, 0.29, 0.48, 1.00)
            imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
            imgui.GetStyle().Colors[imgui.Col.CheckMark]              = ImVec4(0.26, 0.59, 0.98, 1.00)
            imgui.GetStyle().Colors[imgui.Col.SliderGrab]             = ImVec4(0.24, 0.52, 0.88, 1.00)
            imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]       = ImVec4(0.26, 0.59, 0.98, 1.00)
            imgui.GetStyle().Colors[imgui.Col.Button]                 = ImVec4(0.26, 0.59, 0.98, 0.40)
            imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = ImVec4(0.26, 0.59, 0.98, 1.00)
            imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = ImVec4(0.06, 0.53, 0.98, 1.00)
            imgui.GetStyle().Colors[imgui.Col.Header]                 = ImVec4(0.26, 0.59, 0.98, 0.31)
            imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = ImVec4(0.26, 0.59, 0.98, 0.80)
            imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = ImVec4(0.26, 0.59, 0.98, 1.00)
            imgui.GetStyle().Colors[imgui.Col.Separator]              = ImVec4(0.43, 0.43, 0.50, 0.50)
            imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]       = ImVec4(0.26, 0.59, 0.98, 0.78)
            imgui.GetStyle().Colors[imgui.Col.SeparatorActive]        = ImVec4(0.26, 0.59, 0.98, 1.00)
            imgui.GetStyle().Colors[imgui.Col.ResizeGrip]             = ImVec4(0.26, 0.59, 0.98, 0.25)
            imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]      = ImVec4(0.26, 0.59, 0.98, 0.67)
            imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]       = ImVec4(0.26, 0.59, 0.98, 0.95)
            imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]         = ImVec4(0.26, 0.59, 0.98, 0.35)
            imgui.GetStyle().Colors[imgui.Col.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
            imgui.GetStyle().Colors[imgui.Col.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
            imgui.GetStyle().Colors[imgui.Col.WindowBg]               = ImVec4(0.06, 0.53, 0.98, 0.70)
            imgui.GetStyle().Colors[imgui.Col.ChildBg]                = ImVec4(0.10, 0.10, 0.10, 1.00)
            imgui.GetStyle().Colors[imgui.Col.PopupBg]                = ImVec4(0.06, 0.53, 0.98, 0.70)
            imgui.GetStyle().Colors[imgui.Col.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50)
            imgui.GetStyle().Colors[imgui.Col.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
            imgui.GetStyle().Colors[imgui.Col.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
            imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
            imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
            imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
            imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
            imgui.GetStyle().Colors[imgui.Col.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
            imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
            imgui.GetStyle().Colors[imgui.Col.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
            imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
        end
	},
	{
		name = 'Красная',
		func = function()
			local ImVec4 = imgui.ImVec4
            imgui.SwitchContext()
            imgui.GetStyle().Colors[imgui.Col.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
            imgui.GetStyle().Colors[imgui.Col.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
            imgui.GetStyle().Colors[imgui.Col.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.94)
            imgui.GetStyle().Colors[imgui.Col.ChildBg]                = ImVec4(1.00, 1.00, 1.00, 0.00)
            imgui.GetStyle().Colors[imgui.Col.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
            imgui.GetStyle().Colors[imgui.Col.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50)
            imgui.GetStyle().Colors[imgui.Col.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
            imgui.GetStyle().Colors[imgui.Col.FrameBg]                = ImVec4(0.48, 0.16, 0.16, 0.54)
            imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = ImVec4(0.98, 0.26, 0.26, 0.40)
            imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = ImVec4(0.98, 0.26, 0.26, 0.67)
            imgui.GetStyle().Colors[imgui.Col.TitleBg]                = ImVec4(0.04, 0.04, 0.04, 1.00)
            imgui.GetStyle().Colors[imgui.Col.TitleBgActive]          = ImVec4(0.48, 0.16, 0.16, 1.00)
            imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
            imgui.GetStyle().Colors[imgui.Col.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
            imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
            imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
            imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
            imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
            imgui.GetStyle().Colors[imgui.Col.CheckMark]              = ImVec4(0.98, 0.26, 0.26, 1.00)
            imgui.GetStyle().Colors[imgui.Col.SliderGrab]             = ImVec4(0.88, 0.26, 0.24, 1.00)
            imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]       = ImVec4(0.98, 0.26, 0.26, 1.00)
            imgui.GetStyle().Colors[imgui.Col.Button]                 = ImVec4(0.98, 0.26, 0.26, 0.40)
            imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = ImVec4(0.98, 0.26, 0.26, 1.00)
            imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = ImVec4(0.98, 0.06, 0.06, 1.00)
            imgui.GetStyle().Colors[imgui.Col.Header]                 = ImVec4(0.98, 0.26, 0.26, 0.31)
            imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = ImVec4(0.98, 0.26, 0.26, 0.80)
            imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = ImVec4(0.98, 0.26, 0.26, 1.00)
            imgui.GetStyle().Colors[imgui.Col.Separator]              = ImVec4(0.43, 0.43, 0.50, 0.50)
            imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]       = ImVec4(0.75, 0.10, 0.10, 0.78)
            imgui.GetStyle().Colors[imgui.Col.SeparatorActive]        = ImVec4(0.75, 0.10, 0.10, 1.00)
            imgui.GetStyle().Colors[imgui.Col.ResizeGrip]             = ImVec4(0.98, 0.26, 0.26, 0.25)
            imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]      = ImVec4(0.98, 0.26, 0.26, 0.67)
            imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]       = ImVec4(0.98, 0.26, 0.26, 0.95)
            imgui.GetStyle().Colors[imgui.Col.Tab]                    = ImVec4(0.98, 0.26, 0.26, 0.40)
            imgui.GetStyle().Colors[imgui.Col.TabHovered]             = ImVec4(0.98, 0.26, 0.26, 1.00)
            imgui.GetStyle().Colors[imgui.Col.TabActive]              = ImVec4(0.98, 0.06, 0.06, 1.00)
            imgui.GetStyle().Colors[imgui.Col.TabUnfocused]           = ImVec4(0.98, 0.26, 0.26, 1.00)
            imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive]     = ImVec4(0.98, 0.26, 0.26, 1.00)
            imgui.GetStyle().Colors[imgui.Col.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
            imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
            imgui.GetStyle().Colors[imgui.Col.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
            imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
            imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]         = ImVec4(0.98, 0.26, 0.26, 0.35)
        end
	},
}

local newFrame2 = imgui.OnFrame(
    function() return window_two[0] end,
    function(player)
        imgui.Begin("Время:", window_two)
        imgui.Text('Текущее Время: '..os.date('%H:%M:%S'))
imgui.Text('Дата: '..arr.day..'.'.. arr.month..'.'..arr.year)
imgui.Text('Месяц: '..os.date('%B'))
    end
)

local newFrame3 = imgui.OnFrame(
    function() return window_three[0] end,
    function(player)
        imgui.Begin("Сдача ПРО", window_three)
        if imgui.Button("Предложить сдачу ПРО") then
        sampSendChat(monet_utf8_to_cp1251'Здравствуйте, вы хотите сдать ПРО?')
        end
        if imgui.Button("Сдал экзамен") then
        sampSendChat(monet_utf8_to_cp1251'/todo Поздравляю, вы сдали ПРО!*с улыбкой на лице')
        end
                if imgui.Button("Не сдал экзамен") then
                       lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'/todo К сожалению вы не сдали ПРО.*с разочарованием на лице')
						wait(2000)
						sampSendChat(monet_utf8_to_cp1251'Советую вам подучить ПРО и прийти на пересдачу через 10 минут.')
end)
        end
        if imgui.CollapsingHeader('Вопросы(для лидеров)') then
if imgui.Button('Куплю дом в лс') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'Куплю дом В ЛС')
    return true
end)
end
imgui.Text('#1 Ответ: Куплю дом в г.Лос Сантос. Бюджет: Свободный')
if imgui.Button('Куплю закуску в лв') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'Куплю закуску в лв')
    return true
end)
end
imgui.TextWrapped('#2 Ответ: Куплю б/з "Закусочная" в г.Лас Вентурас. Бюджет: Свободный')
if imgui.Button('Продам наркоту') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'Продам наркотики')
    return true
end)
end
imgui.Text('#3 Ответ: Удаление обьявления')
if imgui.Button('Продам дом в лв') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'Продам дом в ЛВ')
    return true
end)
end
imgui.Text('#4 Ответ: Продам "Дом" в г. Лас-Вентурас. Цена: Договорная')
if imgui.Button('Куплю лен') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'куплю лен')
    return true
end)
end
imgui.Text('#5 Ответ: Куплю р/с "Лен". Бюджет: свободный')
if imgui.Button('Куплю салфетки') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'куплю салфетки сухие')
    return true
end)
end
imgui.Text('#6 Ответ: Удаляем обьявления')
if imgui.Button('Продам ларец кладоискателя (50шт)') then
lua_thread.create(function()
    sampSendChat(monet_utf8_to_cp1251'продам ларцы кладоискателя 50 шт')
    return true
end)
end
imgui.Text('Продам Ларцы "Кладоискателя" в кол-ве 50 шт. Цена: Договорная')
end
    end
)


function main()
sampAddChatMessage(monet_utf8_to_cp1251'{00BFFF}[SMI-HELPER]: {FFFFFF}Успешно загружен! Открыть меню: {FF8C00}/sh. {FFFFFF}Автор: {00BFFF}Lua-Scripter', -1)
sampRegisterChatCommand('sh', function() WinState[0] = not WinState[0] end) -- команда по которой будет вызываться
sampRegisterChatCommand('times', function() window_two[0] = not window_two[0] end)
    wait(-1)
end