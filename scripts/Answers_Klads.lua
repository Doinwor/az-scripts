local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local imgui = require 'mimgui'
local new = imgui.new
local main_window_state = new.bool()
local findfield = new.char[256]()
local ffi = require("ffi")

local ans = {
["Сколько раз в день можно поблагодарить адм (/thanks) если у вас 30+ уровень ?"] = "3",
["Какую сумму нужно заплатить, что бы зарегестрироваться PUBG ?"] = "50000",
["Укажите порядковый номер бизнеса казино 4 дракона ?"] = "229",
["Какое макс. количество литров бензина можно загрузить в эвакуатор механика ?"] = "1000",
["Как зовут персонажа у кого можно купить инструменты для собирания льна и хлопка ?"] = "Эмилио",
["Как зовут квест персонажа, который стоит рядом с сгоревшим домом возле деревни Монтгомери?"] = "Орест",
["Какой уровень нужен на работу водителя трамвая "] = "8",
["Сколько BP COINS Дается за убийство игрока в PUBG ?"] = "100",
["Укажите точное кол-во гетто территорий на сервере? "] = "130",
["Укажите стоимость покупки улучшения *Домашний кинотеатр* "] = "50000000",
["Какой уровень необходим для устройства на работу *Водитель погрузчика* на острове Vice-City? "] = "10",
["С какого уровня на работу *Развозчик багажа в аэропорту* ? "] = "3",
["Какой игровой уровень необходим для участия в мероприятии Безумная охота ? "] = "3",
["Какую сумму штрафа нужно заплатить, если вас аррестуют с 7-м уровнем розыска ? "] = "8000000",
["Сколько единиц надо для работы кукурузника на ферме ? "] = "7000",
["Какой уровень нужен для ограбления ?"] = "3",
["Сколько звезд у отеля Casa Tela ?"] = "3",
["Укажите доступные ячейки у фермы №5"] = "61",
["Сколько нужно заплатить, чтобы войти на DM-Areny, находясь в деморгане ?"] = "150000",
["Как зовут квест. персонажа банды, который стоит на Groove Street ?"] = "Джон",
["Сколько стоит проезд по платной дороге рядом с автосалоном эконом класса? "] = "1000",
["В каком году появилась первая капча при ловле имущества ? "] = "2017",
["Какой уровень требуется на работу дальнобойщик ?"] = "12",
["Укажите гос стоимость складского помещения"] = "50000000",
["Какую сумму нужно заплатить, чтобы развестись в церкви ?"] = "$200000",
["Как зовут персонажа у которого можно купить билет на мероприятие Собиратели?"] = "Мартин",
["Укажите гос. стоимость самого дешевого дома "] = "150000",
["Когда вышел пилотный выпуск Arizona Show с ютубером Ричи ? Дата в xx.xx.xx "] = "15.09.17",
["Укажите дату открытия сервера №23 HoliDay "] = "03.11.22",
["До какого уровня можно получить деньги при раздаче для малоимущих в центре занятости ? "] = "6",
["Как зовут квест персонажа в страховой компании ? "] = "Дэвид",
["Какой порядковый номер у бизнеса Аукцион контейнеров ? "] = "227",
["Укажите максильно возможное количество навыка на работе развозчика продуктов "] = "4000",
["Укажите стоимость аренды грузовика RoadTrain на базе дальнобойщиков "] = "50000",
["Укажите дата открытия 22 сервера Sedona"] = "30.06.22",
["Укажите дату открытия №19 сервера Page"] = "05.11.22",
["Сколько всего фонов доступно к выбору при аренде Билборда?"] = "33",
["Как зовут персонажа, у которого можно закать убийство на другого игрока ? "] = "Перис",
["Укажите порядковый номер бизнеса казино 4 дракона ?"] = "229",
["Сколько АЗ можно гарантированно получить с мероприятия Безумная охота "] = "15",
["Как зовут персонажа который всегда встречает новых игроков на вокзале? "] = "Джереми",
["Укажите стоимость арнеды концертного зала за 1 час"] = "50000",
["Как зовут квестового персонажа фракции который стоит в больнице Лос Сантоса?"] = "Керри",
["Укажите количество ячеек у фермы №2 "] = "42",
["Укажите количество ячеек у фермы №3 "] = "46",
["Укажите количество ячеек у фермы №4  "] = "35",
["С какого уровня можно арендовать газонокосилку ? "] = "10",   -- тут  мне надоело пишите сами
["Сколько стоит пролететь на парошуте над Los Santos ?  "] = "900",
["Укажите минимальную сумму, которую нужно заплатить для получения гос. номер на авто "] = "10000",
["Укажите точную дату выхода анонса обновления Arizona 3.0 в формате xx.xx.xx "] = "21.06.22",
["Как зовут квестового персонажа который стоит рядом со входом в Мэрию? "] = "Билли",
["Максимальное количество плодов на яблочном дереве ? "] = "10",
["Укажите дату открытия №21 сервера Queen Creek "] = "29.04.22",
["Какой уровень необходим для устройства на работу Пляжный спасатель на острове Vice City? "] = "30",
["Сколько часов строиться подвал с вентиляцией ? "] = "12",
["Сколько всего ставок можно одновременно поставить в букмейкерской конторе? "] = "10",
["Сколько раз в день проводиться распродажа в Секонд-Хендах? "] = "4",
["Как зовут квестового персонажа который стоит в офисе радиостанции Сан Фиерро?"] = "Фредди",
["ККакок минимальное количество часов аренды билборда ? "] = "10",
["Как зовут квестого персонажа который стоит на спавне в деверне Форт Карсон?"] = "Мартин",
["Сколько можно заработать за перенос 1 мешка на работе грузчика в городе Лос Сантос?"] = "250",
["Укажите дату открытия №20 Sun-Sity сервера "] = "13.03.22",
["Укажите дату открытия №1 Phoenix сервера "] = "29.08.14",
["Укажите дату открытия №2 Tucson сервера  "] = "29.12.14",
["КУкажите дату открытия №3 Scottdale сервера "] = "01.03.15",
["Укажите дату открытия №4 Chandler сервера ? "] = "01.05.15",
["Укажите дату открытия №5 Brainburg сервера "] = "10.10.15",
["Укажите дату открытия №6 Saint Rose сервера  "] = "27.08.17",
["Укажите дату открытия №7 Mesa сервера  "] = "06.01.18",
["Укажите дату открытия №8 Red-Rock сервера "] = "26.07.18",
["Укажите дату открытия №9 Yuma сервера "] = "06.01.19",
["Укажите дату открытия №10 Surprise сервера "] = "25.07.19",
["Укажите дату открытия №11 Prescott сервера "] = "05.01.20",
["Укажите дату открытия №12 Glendale сервера "] = "02.04.20 ",
["Укажите дату открытия №13 Kingman сервера  "] = "28.04.20",
["Укажите дату открытия №14 Winslow сервера "] = "04.11.20",
["Укажите дату открытия №15 Payson сервера "] = "04.01.21",
["Укажите дату открытия №16 Gilbert сервера "] = "09.05.21",
["Укажите дату открытия №17 Show-Low сервера "] = "24.08.21",
["Укажите дату открытия №18 Casa-Grande сервера "] = "06.11.21",
["Укажите дату открытия №24 Wednesday сервера "] = "04.01.21",
["Укажите дату открытия БЕТА тестирования Arizona Mobile в формате хх.хх.хх "] = "24.04.20",
["Как зовут лесного персонажа у которого можно обменять шкуры оленей на другие товары?  "] = "Джозеф",
["В каком году была добавлена работа машинист электропоезда? "] = "2019",
["Сколько всего существует классов такси ?  "] = "4",
["Сколько AZ-Coins стоит улучшение Халявщик ?  "] = "800",
["Как зовут квестового персонажа стоящего во фракции Центральный Банк ? "] = "Эдуард",
["Укажите точное количество ячеек доступных в мусорке  "] = "150",
["Сколько AZ-coins стоит смена названии семьи ? "] = "2000",
["Какое количество звезд имеет отель Inter Continental Hotel(Пирамида)? "] = "5",
["Укажите точное количество квартир в апартаментах The Signature "] = "35",
["Какую максимальную ставку можно сделать на быстрый забег в конных скачках? "] = "2000000",
["Как зовут квестового персонажа который стоит в офисе полиции Лас Вентурас ? "] = "Алексей",
["Какой минимальный уровень должна иметь семья, чтобы купить частную фракцию ? "] = "10",
["Какой порядковый номер имеет АЗС, находящаяся рядом с Автобазаром? "] = "287",
["Сколько можно иметь бизнесов без купленных улучшений?"] = "2",
["Укажите количество ячеек у фермы №1 ?"] = "24",
["Какой уровень требуется для работы Пожарного ?  "] = "14",
["Какой уровень требуется для работы Пилота гражданской авиации ?  "] = "19",
["Какой уровень необходим для устройства на работу Развозчик металлолома ? "] = "4",
["Укажите стоимость аренды концертного зала за 1 час  "] = "50000",   -- тут  мне надоело пишите сами
["Укажите гос. стоимость в AZ-Coins бизнес Ломбард ?  "] = "60000",
["Как зовут менеджера, который стоит на аукционе контейнеров в порту Сан Фиееро? "] = "Магнус",
["УС какого уровня можно заниматься торговлей на центральном рынке? "] = "6",
["Сколько можно заработать за перенос 1 куста пшеницы на государственной ферме? "] = "200",
["Сколько минут длится битва за семейную территорию? "] = "10",
["Сколько стоит билет на канатную дорогу к вершине Чилиада? "] = "500",
}

imgui.OnFrame(function() return main_window_state[0] end,
	function(player)
        imgui.SetNextWindowSize(imgui.ImVec2(400, 380), imgui.Cond.FirstUseEver)
		imgui.Begin('Answer on klads', main_window_state)
		imgui.PushItemWidth(380)
        imgui.Text("Хорошего поиска!")
		imgui.InputTextWithHint(u8'', u8'Find', findfield, 256)
		imgui.Separator()
		if imgui.CollapsingHeader('Связь с автором') then
        imgui.TextWrapped('ВК - vk.com/mrkuroko')
        imgui.TextWrapped('TELEGRAM - t.me/darkd3rk')
        imgui.TextWrapped('TGK - t.me/twizzsquad')
        imgui.TextWrapped('Моральная поддержка при написании говнокода - vk.com/dd.didd')
        imgui.Separator()
        end     
		local findedtext = (ffi.string(findfield)):gsub('[%(%[%%]', '')
		for car, cost in pairs(ans) do
			car = car:lower()
			local costfind = string.gsub(cost,"[.]", "")
			costfind = string.gsub(costfind,"[$]", "")
			if car:find(findedtext) or costfind:find(findedtext) then
				if imgui.Button(car) then setClipboardText(car) end
				imgui.SameLine()
				if imgui.IsItemHovered() then
					imgui.BeginTooltip()
					imgui.Text("Copy vopr")
					imgui.EndTooltip()
				end
				local costtocopy = string.gsub(cost,"[.]", "")
				costtocopy = string.gsub(costtocopy,"[$]", "")
				if imgui.Button(cost) then setClipboardText(costtocopy) end
				if imgui.IsItemHovered() then
					imgui.BeginTooltip()
					imgui.Text("Copy answer")
					imgui.EndTooltip()
				end
			end
		end
		imgui.End()
	end
)
imgui.OnInitialize(function()
    theme()
end)
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    sampAddChatMessage("{FF8282}Create by .deagle, {FA3535}command /ka", -1)
    sampRegisterChatCommand('ka', function() main_window_state[0] = not main_window_state[0] end)
    wait(-1)
end

function theme()
    imgui.SwitchContext()
    local ImVec4 = imgui.ImVec4
    imgui.GetStyle().WindowPadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().FramePadding = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(2, 2)
    imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(0, 0)
    imgui.GetStyle().IndentSpacing = 0
    imgui.GetStyle().ScrollbarSize = 20
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