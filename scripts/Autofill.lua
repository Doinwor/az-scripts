package.preload['arzmobfrontend'] = function(...)
    local mod = {}

mod.UIElements = {
    VOICE_SETTING = {id = 2, project = "common", rudesc = "Настройки голоса"},
    RODINA_SERVICE_STATION = {id = 31, project = "rodina", rudesc = "Сервисная станция Родины"},
    RODINA_PARK_MENU = {id = 11, project = "rodina", rudesc = "Меню парка в Родине"},
    NEWBIE_BATTLE_PASS = {id = 41, project = "common", rudesc = "Боевой пропуск для новичков"},
    RODINA_JOB_RATING_SCREEN = {id = 23, project = "rodina", rudesc = "Экран рейтинга работ в Родине"},
    ARIZONA_ALCOHOL_STORE = {id = 82, project = "arizona", rudesc = "Магазин алкоголя Аризоны"},
    ARIZONA_OUTFIT = {id = 93, project = "arizona", rudesc = "Одежда Аризоны"},
    COMMAND_BINDER = {id = 1, project = "common", rudesc = "Привязка команд"},
    MAIN_BATTLE_PASS = {id = 40, project = "common", rudesc = "Основной боевой пропуск"},
    ARIZONA_TOUR = {id = 92, project = "arizona", rudesc = "Тур Аризоны"},
    RODINA_EXCAVATION_SCREEN = {id = 28, project = "rodina", rudesc = "Экран раскопок Родины"},
    INPUT_LAYOUT = {id = 62, project = "common", rudesc = "Ввод данных"},
    ARIZONA_LIVING_HOUSE = {id = 94, project = "arizona", rudesc = "Жилой дом Аризоны"},
    RODINA_VEHICLE_LIST = {id = 20, project = "rodina", rudesc = "Список транспортных средств в Родине"},
    ARIZONA_ACTION = {id = 46, project = "arizona", rudesc = "Акция Аризоны"},
    ARIZONA_LAVKA = {id = 61, project = "common", rudesc = "Лавка Аризоны"},
    RODINA_REFERRAL = {id = 14, project = "rodina", rudesc = "Реферальная система Родины"},
    QUESTS_SCREEN = {id = 29, project = "common", rudesc = "Экран квестов"},
    ARIZONA_CONTAINER_REWARDS = {id = 45, project = "arizona", rudesc = "Награды контейнера Аризоны"},
    RODINA_SELECT_CHARACTER = {id = 10, project = "rodina", rudesc = "Выбор персонажа в Родине"},
    ARIZONA_TAXI = {id = 90, project = "arizona", rudesc = "Такси Аризоны"},
    RODINA_METAL_DETECTOR = {id = 21, project = "rodina", rudesc = "Металлоискатель в Родине"},
    ANIMATION_MENU = {id = 7, project = "common", rudesc = "Меню анимаций"},
    TASK_BAR = {id = 71, project = "common", rudesc = "Панель задач"},
    PIE_SELECTOR = {id = 5, project = "common", rudesc = "Селектор пирога"},
    GAME_PASS = {id = 68, project = "common", rudesc = "Игровой пропуск"},
    RODINA_CONTAINER_SCREEN = {id = 26, project = "rodina", rudesc = "Экран контейнеров Родины"},
    ACHIEVEMENTS = {id = 69, project = "common", rudesc = "Достижения"},
    REWARDS_SCREEN = {id = 97, project = "arizona", rudesc = "Экран наград за квесты"},
    RODINA_EMPLOYMENT_CENTER = {id = 18, project = "rodina", rudesc = "Центр занятости Родины"},
    HEALTH = {id = 66, project = "common", rudesc = "Здоровье"},
    ARIZONA_CONCERT_HALL = {id = 96, project = "arizona", rudesc = "Концертный зал Аризоны"},
    REWARD_SCREEN = {id = 67, project = "common", rudesc = "Экран наград"},
    RODINA_REGISTRATION_REFERRAL = {id = 13, project = "rodina", rudesc = "Регистрация по реферальной ссылке в Родине"},
    ARIZONA_CINEMA_EFFECT = {id = 49, project = "arizona", rudesc = "Эффект кинотеатра Аризоны"},
    ARIZONA_CAR_DINNER = {id = 95, project = "arizona", rudesc = "Ресторан при автосервисе Аризоны"},
    ARIZONA_JOB = {id = 91, project = "arizona", rudesc = "Работа Аризоны"},
    RODINA_LATCHKEY_SCREEN = {id = 27, project = "rodina", rudesc = "Экран замков в Родине"},
    ARIZONA_TRANSPORT_DEALERSHIP = {id = 89, project = "arizona", rudesc = "Автосалон Аризоны"},
    AUTHORIZATION = {id = 9, project = "common", rudesc = "Окно авторизации"},
    INVENTORY_WAREHOUSE = {id = 65, project = "common", rudesc = "Склад инвентаря"},
    ARIZONA_FIGHT_CLUB = {id = 88, project = "arizona", rudesc = "Бойцовский клуб Аризоны"},
    ARIZONA_GARAGE = {id = 87, project = "arizona", rudesc = "Гараж Аризоны"},
    RODINA_SHOP_SCREEN = {id = 19, project = "rodina", rudesc = "Экран магазина в Родине"},
    ARIZONA_CURRENT_CONTAINER = {id = 44, project = "arizona", rudesc = "Текущий контейнер Аризоны"},
    ARIZONA_MOBILE_PHONE = {id = 47, project = "arizona", rudesc = "Мобильный телефон Аризоны"},
    ARIZONA_STREET_FOOD = {id = 55, project = "common", rudesc = "Уличная еда Аризоны"},
    RAISE_NOTICE = {id = 77, project = "common", rudesc = "Уведомление о повышении"},
    ARIZONA_NIGHT_CLUB = {id = 83, project = "arizona", rudesc = "Ночной клуб Аризоны"},
    RODINA_MOBILE_PHONE = {id = 32, project = "rodina", rudesc = "Мобильный телефон Родины"},
    ARIZONA_RACE = {id = 81, project = "arizona", rudesc = "Гонка Аризоны"},
    MAIL = {id = 76, project = "common", rudesc = "Почта"},
    ARIZONA_CHEMICAL_PLANT = {id = 80, project = "arizona", rudesc = "Химический завод Аризоны"},
    SKILLS = {id = 79, project = "common", rudesc = "Навыки"},
    WORKSHOP = {id = 59, project = "common", rudesc = "Мастерская"},
    RODINA_JOB_CONTRACTS_SCREEN = {id = 24, project = "rodina", rudesc = "Экран контрактов в Родине"},
    DICE_SCREEN = {id = 33, project = "common", rudesc = "Экран костей"},
    MAIN_MENU = {id = 54, project = "common", rudesc = "Главное меню"},
    OPTIONS = {id = 75, project = "common", rudesc = "Настройки"},
    FINANCE = {id = 78, project = "common", rudesc = "Финансы"},
    CHARACTER_SKIN = {id = 73, project = "common", rudesc = "Скин персонажа"},
    RODINA_CAPTURE = {id = 16, project = "rodina", rudesc = "Захват в Родине"},
    CHARACTER_INFO = {id = 72, project = "common", rudesc = "Информация о персонаже"},
    ARIZONA_PASS_PROMO = {id = 38, project = "arizona", rudesc = "Промо Arizona Pass"},
    RODINA_UNIVERSAL_MENU = {id = 34, project = "rodina", rudesc = "Универсальное меню Родины"},
    INTERACTION_BUTTON = {id = 53, project = "common", rudesc = "Кнопка взаимодействия"},
    MAP = {id = 70, project = "common", rudesc = "Карта"},
    RODINA_VEHICLE_DOCUMENT = {id = 12, project = "rodina", rudesc = "Документы на транспорт Родины"},
    INVENTORY_SECURITY_SCREEN = {id = 64, project = "common", rudesc = "Экран безопасности инвентаря"},
    STREAM_VIDEO = {id = 63, project = "common", rudesc = "Видео-поток"},
    UNIVERSAL_ACTION = {id = 25, project = "common", rudesc = "Универсальное действие"},
    RODINA_CAPTCHA_SCREEN = {id = 37, project = "rodina", rudesc = "Экран капчи Родины"},
    RODINA_DRIFT_SCORE_SCREEN = {id = 35, project = "rodina", rudesc = "Экран дрифта Родины"},
    HUD = {id = 8, project = "common", rudesc = "HUD интерфейс"},
    ARIZONA_GLOVO = {id = 60, project = "common", rudesc = "Glovo Аризоны"},
    UNIVERSAL_ACTION_SCREEN = {id = 74, project = "common", rudesc = "Универсальный экран действий"},
    PERSONAL_PROPERTY = {id = 17, project = "common", rudesc = "Личное имущество"},
    ARIZONA_ZOO = {id = 85, project = "arizona", rudesc = "Зоопарк Аризоны"},
    RODINA_PROPOSAL_SCREEN = {id = 36, project = "rodina", rudesc = "Экран предложений Родины"},
    SNACKBAR = {id = 6, project = "common", rudesc = "Уведомление (Snackbar)"},
    PLAYER_LIST = {id = 56, project = "common", rudesc = "Список игроков"},
    ARIZONA_TRUCK_STOP = {id = 84, project = "arizona", rudesc = "Трак-стоп Аризоны"},
    RODINA_LICENSE_PLATES_SCREEN = {id = 30, project = "rodina", rudesc = "Экран номерных знаков в Родине"},
    INVENTORY = {id = 52, project = "common", rudesc = "Инвентарь"},
    ARIZONA_VEHICLE_PLATE = {id = 51, project = "arizona", rudesc = "Номерной знак Аризоны"},
    DIALOG = {id = 4, project = "common", rudesc = "Диалоговое окно"},
    ARIZONA_GAS_STATION = {id = 48, project = "common", rudesc = "Заправка Аризоны"},
    CRAFT = {id = 58, project = "common", rudesc = "Крафт"},
    RODINA_JOB_MAIN_SCREEN = {id = 22, project = "rodina", rudesc = "Главный экран работы в Родине"},
    ARIZONA_WEAPON_SHOP = {id = 86, project = "arizona", rudesc = "Магазин оружия Аризоны"},
    ARIZONA_CONTAINER = {id = 43, project = "arizona", rudesc = "Контейнер Аризоны"},
    VOICE_PLAYERS_SETTINGS = {id = 3, project = "common", rudesc = "Настройки голосового чата для игроков"},
    USER_BATTLE_PASS = {id = 39, project = "common", rudesc = "Боевой пропуск пользователя"},
    ARIZONA_DONATE_SHOP = {id = 42, project = "arizona", rudesc = "Магазин донатов Аризоны"},
    QUEST_DIALOG = {id = 15, project = "common", rudesc = "Диалог для квестов"},
    TRADE = {id = 57, project = "common", rudesc = "Торговля"},
}

function mod.sendInterfaceState(interfaceid, state)
	local bs = raknetNewBitStream()
	raknetBitStreamWriteInt8(bs, 220)
	raknetBitStreamWriteInt8(bs, 66)
	raknetBitStreamWriteInt8(bs, interfaceid)
	raknetBitStreamWriteBool(bs, state)
	raknetSendBitStreamEx(bs, 1, 10, 1)
	raknetDeleteBitStream(bs)
end

function mod.sendFrontendClick(interfaceid, id, subid, json)
	local bs = raknetNewBitStream()
	raknetBitStreamWriteInt8(bs, 220)
	raknetBitStreamWriteInt8(bs, 63)
	raknetBitStreamWriteInt8(bs, interfaceid)
	raknetBitStreamWriteInt32(bs, id)
	raknetBitStreamWriteInt32(bs, subid)
	raknetBitStreamWriteInt16(bs, #json)
	raknetBitStreamWriteString(bs, json)
	raknetSendBitStreamEx(bs, 1, 10, 1)
	raknetDeleteBitStream(bs)
end

function mod.sendInteraction()
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, 8)
    raknetBitStreamWriteInt32(bs, 7)
    raknetBitStreamWriteInt32(bs, -1)
    raknetBitStreamWriteInt16(bs, 0)
    raknetBitStreamWriteString(bs, "")
    raknetSendBitStreamEx(bs, 1, 7, 1)
    raknetDeleteBitStream(bs)
end

function mod.onFrontendMessage(interfaceid, subid, json) end
function mod.onToggleInterface(interfaceid, state) end

addEventHandler('onReceivePacket', function(id, bs) 
    if id == 220 then
        raknetBitStreamIgnoreBits(bs, 8) 
        local type = raknetBitStreamReadInt8(bs)
        if type == 84 then
            local interfaceid = raknetBitStreamReadInt8(bs)
            local subid = raknetBitStreamReadInt8(bs)
            local len = raknetBitStreamReadInt16(bs) 
            local encoded = raknetBitStreamReadInt8(bs)
            local json = (encoded ~= 0) and raknetBitStreamDecodeString(bs, len + encoded) or raknetBitStreamReadString(bs, len)
            
            return mod.onFrontendMessage(interfaceid, subid, json)
       end
       if type == 62 then
            local interfaceid = raknetBitStreamReadInt8(bs)
            local toggle = raknetBitStreamReadBool(bs)

            return mod.onToggleInterface(interfaceid, toggle)
        end
    end
end)

return mod
end

script_name("AutoFill")
script_author("t.me/ospxdev")

local amob = require 'arzmobfrontend'
local inicfg = require 'inicfg'

local cfg = inicfg.load({
    main = {
        enabled = true
    }
}, thisScript().name .. '.ini')

local function save()
    inicfg.save(cfg, thisScript().name .. '.ini')
end

local chat = {
    colors = {
        prefix = "{8A2BE2}",
        main = "{DDA0DD}",
        error = "{9400D3}"
    },
    prefixText = string.format("[%s by %s] ", thisScript().name, thisScript().authors[1]),
}

setmetatable(chat, {
    __call = function(self, msg, ...)
        self:info(msg, ...)
    end
})

function chat:info(msg, ...)
    local formattedMsg = self.colors.prefix .. self.prefixText .. self.colors.main .. string.format(msg, ...)
    sampAddChatMessage(formattedMsg, -1)
    print(self.prefixText .. string.format(msg, ...))
end

function chat:error(msg, ...)
    local formattedMsg = self.colors.prefix .. self.prefixText .. self.colors.error .. string.format(msg, ...)
    sampAddChatMessage(formattedMsg, -1)
    print(self.prefixText .. string.format(msg, ...))
end

local GAS = amob.UIElements.ARIZONA_GAS_STATION

---@class GasType
---@field title string
---@field available number
---@field price number
---@field id number

local gstate = {
    availGasType = nil, ---@type GasType
    maxGas = nil, ---@type number
    currentGas = nil, ---@type number
}

local function fill()
    if not gstate.availGasType or not gstate.maxGas or not gstate.currentGas then
        print(string.format('Something wrong! Gas type: %s, max: %s, current: %s', gstate.availGasType and gstate.availGasType.title or 'nil', gstate.maxGas, gstate.currentGas))
        chat:error("Во время заправки произошла ошибка, отправьте monetloader.log в наш канал.")
        return
    end
    local tofill = gstate.maxGas - gstate.currentGas
    chat:info("Заправляемся: тип топлива - %s, объем - %s литров, стоимость - %s$",
        gstate.availGasType.title,
        tofill,
        gstate.availGasType.price * tofill
    )

    amob.sendFrontendClick(GAS.id, -1, 0, string.format('%d,%d', gstate.availGasType.id, gstate.maxGas - gstate.currentGas))

    gstate = {}
end

amob.onFrontendMessage = function(iid, subid, json)
    if cfg.main.enabled and iid == GAS.id then
        if subid == 0 then
            local json = decodeJson(json) ---@type GasType[]

            for i, gtype in ipairs(json) do
                if gtype.available == 1 then
                    gstate.availGasType = gtype
                    break
                end
            end
        elseif subid == 2 then
            gstate.maxGas = tonumber(json)
        elseif subid == 3 then
            gstate.currentGas = tonumber(json)

            lua_thread.create(function()
                wait(100)
                fill()
            end)
        end

        return false
    elseif cfg.main.enabled and iid == amob.UIElements.HUD.id and subid == 15 then
        local json = decodeJson(json)
        
        if json.title:find"Заправиться" then
            lua_thread.create(function()
                wait(50)
                amob.sendInteraction()
            end)
        end
    end
end
amob.onToggleInterface = function(iid, state)
    if cfg.main.enabled and iid == GAS.id then
        amob.sendInterfaceState(iid, state)
        return false
    end
end

function main()
    sampRegisterChatCommand('af', function()
        cfg.main.enabled = not cfg.main.enabled
        save()

        chat:info(cfg.main.enabled and 'Включено' or 'Выключено')
    end)

    wait(-1)
end