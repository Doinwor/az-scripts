-- =====================================================================================================================
--                                                          Header
-- =====================================================================================================================

script_authors('Sand / Rodina fork: rozovscam')
script_name('MMT | Mining Tool')
script_description('Rodina fork: @rozovscam | Original MMT: @Mister_Sand')
script_version("1.0")

-- =====================================================================================================================
--                                                          Import
-- =====================================================================================================================

-- Runtime log path. The file itself is created only when DEBUG is enabled in settings.
local MMT_RUNTIME_LOG_PATH = "MMT_runtime.log"
do
    local gameRoot = "."
    if type(getWorkingDirectory) == "function" then
        local ok, value = pcall(getWorkingDirectory)
        if ok and value and tostring(value) ~= "" then
            gameRoot = tostring(value)
        end
    end

    if tostring(gameRoot):sub(1, 1) == "/" then
        -- Android/Neo: keep Unix path separators. Backslashes become part of
        -- the filename on Android and make the debug log hard to locate.
        local androidRoot = tostring(gameRoot):gsub("\\", "/")
        local parentRoot = androidRoot:match("^(.-)/moonloader$")
        gameRoot = (parentRoot and parentRoot ~= "") and parentRoot or androidRoot
        MMT_RUNTIME_LOG_PATH = gameRoot .. "/MMT_runtime.log"
    else
        local normalizedRoot = tostring(gameRoot):gsub("/", "\\")
        local parentRoot = normalizedRoot:match("^(.-)\\moonloader$")
        gameRoot = (parentRoot and parentRoot ~= "") and parentRoot or normalizedRoot
        MMT_RUNTIME_LOG_PATH = gameRoot .. "\\MMT_runtime.log"
    end
end

local function CheckLibrary(libName)
    local success, lib = pcall(require, libName)
    if not success then
        print("Библиотека " .. libName .. " не найдена!")
    end
    return success, lib
end

local imguiSuccess,     imgui       = CheckLibrary('mimgui')
local encodingSuccess,  encoding    = CheckLibrary('encoding')
local sampevSuccess,    sampev      = CheckLibrary('lib.samp.events')
local jsonSuccess,      json        = CheckLibrary('cjson')
local lfsSuccess,       lfs         = CheckLibrary('lfs')
local faSuccess,        fa          = CheckLibrary('fAwesome6_solid')
local keysSuccess,      vkeys       = CheckLibrary('vkeys')
local ffiSuccess,       ffi         = CheckLibrary('ffi')
local notifySuccess,    notify      = pcall(require, 'session_notifications')

encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Runtime diagnostics. Controlled by Settings -> DEBUG.
local RuntimeLog = {
    enabled = false,
    file = nil,
    path = nil,
    sessionId = os.date("%Y%m%d-%H%M%S"),
    seq = 0,
    writesSinceSizeCheck = 0,
    maxFileBytes = 50 * 1024 * 1024,
    maxPayloadBytes = 24000,
}

function RuntimeLog.ResolveGameRoot()
    local path = tostring(MMT_RUNTIME_LOG_PATH or "MMT_runtime.log")
    return path:match("^(.*)[/\\][^/\\]+$") or "."
end

function RuntimeLog.ResolvePath()
    if RuntimeLog.path then return RuntimeLog.path end
    RuntimeLog.path = tostring(MMT_RUNTIME_LOG_PATH or "MMT_runtime.log")
    return RuntimeLog.path
end

function RuntimeLog.SetEnabled(value, resetFile)
    local enabled = value == true
    if not enabled then
        RuntimeLog.enabled = false
        RuntimeLog.Close()
        return
    end

    RuntimeLog.enabled = true
    if resetFile then
        RuntimeLog.Close()
        pcall(function()
            local fh = io.open(RuntimeLog.ResolvePath(), "wb")
            if fh then
                fh:write(string.format(
                    "MMT DEBUG LOG ENABLED | %s | path=%s\r\n",
                    os.date("%d.%m.%Y %H:%M:%S"), RuntimeLog.ResolvePath()
                ))
                fh:close()
            end
        end)
    end
    RuntimeLog.Open()
end

function RuntimeLog.Open()
    if not RuntimeLog.enabled then return false end
    if RuntimeLog.file then return true end

    local ok, fh = pcall(io.open, RuntimeLog.ResolvePath(), "ab")
    if not ok or not fh then
        RuntimeLog.file = nil
        return false
    end

    RuntimeLog.file = fh
    return true
end

function RuntimeLog.Close()
    if RuntimeLog.file then
        pcall(function()
            RuntimeLog.file:flush()
            RuntimeLog.file:close()
        end)
    end
    RuntimeLog.file = nil
end

function RuntimeLog.RotateIfNeeded()
    RuntimeLog.writesSinceSizeCheck = (RuntimeLog.writesSinceSizeCheck or 0) + 1
    if RuntimeLog.writesSinceSizeCheck < 250 or not RuntimeLog.file then return end
    RuntimeLog.writesSinceSizeCheck = 0

    local okPos, size = pcall(function()
        return RuntimeLog.file:seek("end")
    end)
    if not okPos or not size or size < RuntimeLog.maxFileBytes then return end

    local current = RuntimeLog.ResolvePath()
    local previous = current:gsub("%.log$", ".prev.log")

    RuntimeLog.Close()
    pcall(os.remove, previous)
    pcall(os.rename, current, previous)
    RuntimeLog.Open()

    if RuntimeLog.file then
        RuntimeLog.file:write(string.format(
            "\r\n---------------- LOG ROTATED | session=%s | %s ----------------\r\n",
            tostring(RuntimeLog.sessionId), os.date("%d.%m.%Y %H:%M:%S")
        ))
        RuntimeLog.file:flush()
    end
end

function RuntimeLog.OneLine(value)
    local s = tostring(value == nil and "nil" or value)
    s = s:gsub("%z", "\\0")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\n", "\\n")
    return s
end

function RuntimeLog.Write(category, message)
    if not RuntimeLog.enabled or not RuntimeLog.Open() then return end

    RuntimeLog.seq = (RuntimeLog.seq or 0) + 1
    local line = string.format(
        "[%s] #%06d [%s] %s\r\n",
        os.date("%d.%m.%Y %H:%M:%S"),
        RuntimeLog.seq,
        tostring(category or "INFO"),
        RuntimeLog.OneLine(message)
    )

    pcall(function()
        RuntimeLog.file:write(line)
        RuntimeLog.file:flush()
    end)

    RuntimeLog.RotateIfNeeded()
end

function RuntimeLog.Payload(category, header, payload)
    if not RuntimeLog.enabled then return end
    local body = tostring(payload or ""):gsub("%z", "\\0")
    body = body:gsub('(\"token\"%s*:%s*\")[^\"]+(\")', '%1[REDACTED]%2')
    body = body:gsub('(\"password\"%s*:%s*\")[^\"]*(\")', '%1[REDACTED]%2')
    local originalLen = #body
    if originalLen > RuntimeLog.maxPayloadBytes then
        body = body:sub(1, RuntimeLog.maxPayloadBytes)
            .. string.format("\r\n...[TRUNCATED %d BYTES]...", originalLen - RuntimeLog.maxPayloadBytes)
    end

    RuntimeLog.Write(category, tostring(header or "") .. string.format(" | payload_len=%d", originalLen))

    if not RuntimeLog.enabled or not RuntimeLog.Open() then return end
    pcall(function()
        RuntimeLog.file:write("----- PAYLOAD BEGIN -----\r\n")
        RuntimeLog.file:write(body)
        RuntimeLog.file:write("\r\n----- PAYLOAD END -----\r\n")
        RuntimeLog.file:flush()
    end)
end

function RuntimeLog.StartSession()
    if not RuntimeLog.Open() then return end
    pcall(function()
        RuntimeLog.file:write("\r\n")
        RuntimeLog.file:write(string.rep("=", 100) .. "\r\n")
        RuntimeLog.file:write(string.format(
            "MMT SESSION START | id=%s | %s | script=%s\r\n",
            tostring(RuntimeLog.sessionId),
            os.date("%d.%m.%Y %H:%M:%S"),
            tostring((thisScript() and thisScript().filename) or "?")
        ))
        RuntimeLog.file:write("log=" .. RuntimeLog.ResolvePath() .. "\r\n")
        RuntimeLog.file:write(string.rep("=", 100) .. "\r\n")
        RuntimeLog.file:flush()
    end)
end

-- Four permanent reusable workers. Jobs may call wait(); the worker itself stays alive.
local WorkerPool = {
    SIZE = 4,
    queue = {},
    workers = {},
    started = false,
    nextTaskId = 0,
    completed = 0,
    busy = 0,
}
local mmtDedicatedThreadHandles = {}

local function MMTCreateDedicatedThread(fn, ...)
    local handle = lua_thread.create(fn, ...)
    mmtDedicatedThreadHandles[#mmtDedicatedThreadHandles + 1] = handle
    RuntimeLog.Write("THREAD", string.format(
        "dedicated create | retained=%d | handle=%s",
        #mmtDedicatedThreadHandles, tostring(handle)
    ))
    return handle
end

function WorkerPool.Submit(fn, ...)
    if type(fn) ~= "function" then return nil end
    WorkerPool.nextTaskId = WorkerPool.nextTaskId + 1
    local task = {
        id = WorkerPool.nextTaskId,
        fn = fn,
        args = { n = select('#', ...), ... },
        status = "queued",
        queuedAt = os.clock(),
        worker = nil,
    }
    WorkerPool.queue[#WorkerPool.queue + 1] = task
    RuntimeLog.Write("WORKER", string.format(
        "queue | task=%d pending=%d busy=%d",
        task.id, #WorkerPool.queue, WorkerPool.busy
    ))
    return task
end

local function WorkerPoolLoop(index)
    RuntimeLog.Write("WORKER", string.format("worker=%d started", index))
    while true do
        local task = table.remove(WorkerPool.queue, 1)
        if not task then
            wait(10)
        else
            task.status = "running"
            task.worker = index
            WorkerPool.busy = WorkerPool.busy + 1
            RuntimeLog.Write("WORKER", string.format(
                "worker=%d start task=%d queued_for_ms=%.0f pending=%d",
                index, task.id, (os.clock() - (task.queuedAt or os.clock())) * 1000,
                #WorkerPool.queue
            ))

            -- Do not wrap yielding jobs in pcall/xpcall on Lua 5.1/MoonLoader.
            task.fn(unpack(task.args, 1, task.args.n or #task.args))

            WorkerPool.busy = math.max(0, WorkerPool.busy - 1)
            WorkerPool.completed = WorkerPool.completed + 1
            task.status = "done"
            task.fn = nil
            task.args = nil
            RuntimeLog.Write("WORKER", string.format(
                "worker=%d done task=%d completed=%d pending=%d",
                index, task.id, WorkerPool.completed, #WorkerPool.queue
            ))
        end
    end
end

function WorkerPool.Start()
    if WorkerPool.started then return end
    WorkerPool.started = true
    for i = 1, WorkerPool.SIZE do
        WorkerPool.workers[i] = MMTCreateDedicatedThread(function()
            WorkerPoolLoop(i)
        end)
    end
    RuntimeLog.Write("WORKER", string.format("pool started | workers=%d", WorkerPool.SIZE))
end

function WorkerPool.State(reason)
    local states = {}
    for i = 1, WorkerPool.SIZE do
        local h = WorkerPool.workers[i]
        local st = "nil"
        if h and type(h.status) == "function" then
            local ok, value = pcall(function() return h:status() end)
            if ok then st = tostring(value) end
        end
        states[#states + 1] = tostring(i) .. ":" .. st
    end
    RuntimeLog.Write("WORKER", string.format(
        "%s | pending=%d busy=%d completed=%d workers=[%s]",
        tostring(reason or "state"), #WorkerPool.queue, WorkerPool.busy,
        WorkerPool.completed, table.concat(states, ",")
    ))
end

-- Compatibility: old short-lived thread calls now enqueue a reusable worker job.
local function MMTCreateThread(fn, ...)
    return WorkerPool.Submit(fn, ...)
end

if not imguiSuccess     or not encodingSuccess  or not sampevSuccess or
   not jsonSuccess      or not lfsSuccess       or not faSuccess     or
   not ffiSuccess then
    print("Некоторые библиотеки не были загружены. Пожалуйста, установите недостающие библиотеки.")
end

local VK_RETURN = (keysSuccess and vkeys.VK_RETURN) or 0x0D
local VK_UP     = (keysSuccess and vkeys.VK_UP)     or 0x26
local VK_DOWN   = (keysSuccess and vkeys.VK_DOWN)   or 0x28

local REQUIRED_NOTIFY_VERSION = '1.0'
local NOTIFY_MANAGER_REPO_URL = 'https://github.com/Mister-Sand/session_notifications'
local NOTIFY_MANAGER_RAW_URL = 'https://raw.githubusercontent.com/Mister-Sand/session_notifications/main/NotificationManager.lua'
local NOTIFY_LIBRARY_RAW_URL = 'https://raw.githubusercontent.com/Mister-Sand/session_notifications/main/lib/session_notifications.lua'

-- =====================================================================================================================
--                                                          GLOBAL VARIABLES
-- =====================================================================================================================

-- --------------------------------------------------------
--                           Constants
-- --------------------------------------------------------

-- NeoMLoader ships its own mimgui backend. Detect it separately so we can
-- keep Monet-compatible mobile CEF logic while disabling touch helpers that
-- currently hit a native NeoMLoader 0.1.6 crash.
local ISNEOMLOADER = false
if ffiSuccess then
    local okNeo, neoFn = pcall(function()
        return ffi.C.neom_mimgui_get_dpi_scale
    end)
    ISNEOMLOADER = okNeo and neoFn ~= nil
end

ISMONETLOADER = true
SEPORATORPATCH = "/"
if MONET_DPI_SCALE == nil then MONET_DPI_SCALE = 1.0 ISMONETLOADER = false SEPORATORPATCH = "\\" end
local ISMOBILELOADER = ISMONETLOADER or ISNEOMLOADER

-- Hard Windows-positive selection: if Neo/Monet detection fails on Android,
-- NEVER fall into the Windows-only BTC dialog handlers.
-- Both LuaJIT jit.os and ffi.os report Windows for MoonLoader on Windows.
local IS_WINDOWS_MOONLOADER = (
    (type(jit) == 'table' and jit.os == 'Windows')
    or (ffiSuccess and ffi and ffi.os == 'Windows')
) == true

local folderConfig = 'config'..SEPORATORPATCH
local PATCHCONFIG = folderConfig..'MMT CFGs'..SEPORATORPATCH

-- === Логи / статистика заточки видеокарт ===
local IMPROVE_LOGS_DIR   = PATCHCONFIG .. 'logs' .. SEPORATORPATCH     -- папка для текстовых логов
local IMPROVE_STATS_FILE = PATCHCONFIG .. 'ImproveStats.json'          -- файл со сводной статистикой
local COLLECT_STATS_FILE = PATCHCONFIG .. 'CollectStats.json'          -- лог сбора криптовалюты по датам / домам


local CARD_LEVELS_FILE = PATCHCONFIG .. 'CardLevels.json'             -- запомненные уровни видеокарт по слотам

local COLORS = {
    WHITE = "FFFFFF",
    RED = "FF3333",
    YELLOW = "FFE133",
    GREEN = "33FF33",
}

-- Типы сообщений скрипта
local TYPECHATMESSAGES = {
    SUCCESS = 1,
    SECONDARY = 2,
    WARNING = 6,
    CRITICAL = 8,
    DEBUG = 10
}

-- Доходность видеокарт по уровням в час: Rodina RP
local GPU_HOURLY_BY_LEVEL = {
    [1]=0.039999, [2]=0.079999, [3]=0.115, [4]=0.15, [5]=0.185,
    [6]=0.224999, [7]=0.254999, [8]=0.284999, [9]=0.314999, [10]=0.349999,
}
local function GetGpuHourlyTable()
    return GPU_HOURLY_BY_LEVEL
end

local function GetGpuHourlyRate(level)
    local rates = GetGpuHourlyTable()
    return rates[tonumber(level) or 1] or 0
end

-- Сколько часов видеокарта отработает за полный цикл при 100% охлаждения
local GPU_CYCLE_HOURS = 224

function math.maxEx(a, b)
    return a > b and a or b
end

function math.minEx(a, b)
    return a < b and a or b
end

-- --------------------------------------------------------
--                           Settings
-- --------------------------------------------------------

-- Заводские настройки скрипта
local defaultSettings = {
    main = {
        -- Заменять диалог майнинга на окно скрипат
        replaceDialog = true,
        -- Заливать с числа. Если залито 49.9 - то будем заливать, если 50.1 - то уже не заливаем
        fillFrom = 50.0,
        -- С какой накопленной крипты подсвечивать дом красным (хранилище скоро переполнится)
        maxCollectAlert = 9.0,
        -- Типы сообщений в чат игры
        typeChatMessage = {
            messages = true,
            debug    = false,
        },
        -- Черный список домов, которые нужно скрыть
        blackListHouses = {},
        -- Закрывать ли на ESC
        closeOnESC = true,
        -- Перемещаться стрелками
        arrowsMove = true,
        -- Скрывать текст полученной крипты
        hideMessagesCollect = true,
    -- Общая сводка в чат по завершению сбора (уровни видеокарт, суммы, время)
    showCollectSummary = true,
        -- автозаливка
        autoFillEnabled = false,
        -- автоматически включать видеокарты после сбора
        autoEnableCards = false,
        -- Панель статуса
        showStatusPanel = false,
        -- Напоминание, если давно не было сбора крипты (в минутах, 0 = выкл)
        collectNotifyMinutes = 0,
        collectLogsView = "list",
        collectLogsPeriod = 7,
        collectLogMaxItemsPerHouseDay = 300,
        -- Отображение доходности (что показывать в списке полок)
        income = {
            showPerHour             = true,  -- "/ч"
            showPer24h              = true,  -- "/24ч"
            showPerCycle            = true,  -- "/цикл"
            showTillThresholdHours  = true,  -- "до доливки" (часы и прибыль)
            showTillThresholdProfit = true,  -- "до доливки" (часы и прибыль)
            houseBonuses            = {},
            rtx4090                 = false, -- глобальный множитель майнинга x1.25
        },
    },
    notifications = {
        -- Версия формата: до 2 была одна общая галочка Telegram
        version = 2,
        -- Через какого бота: 1 = свой бот, 2 = MCR Notification
        methodBot = 1,
        -- Свой бот: токен и ID чата
        botToken = "",
        chatId = "",
        -- ID пользователя в боте MCR Notification
        mcrChatId = "",
        -- Ключ MCR (пусто = взять из MCR ПК или MLoader)
        mcrKey = "",
        -- Напоминания в Telegram по событиям
        tg = {
            crypto = false,
        },
        -- Напоминания в игре (менеджер уведомлений, без него - сообщение в чат)
        game = {
            crypto = true,
        },
        -- [вид] = время сбора, о котором уже напомнили (повторно не шлём)
        sent = {},
    },
    improve = {
        -- true: улучшать все карты; false: только выбранную
        menuAll = true,
        -- Rodina-only: видеокарта item 3206
        typeCards = 1,
        -- Новый стиль CEF - основной режим инвентаря
        inventoryMode = 2,
        -- 1 = Последовательное (сначала низкий уровень), 2 = Поочередное (как на экране)
        mode = 1,
        -- Целевой уровень (не улучшать если уже >= этого уровня)
        maxLevel = 2,
        -- Проверять наличие смазки при старте заточки через CEF-инвентарь
        checkOilsOnStart = true,
        -- Сколько часов считать запомненный уровень видеокарты актуальным (0 = бессрочно)
        levelCacheHours = 0,
        -- Сколько повторов делать, если слот не ответил при проверке уровня
        probeRetries = 2,
        -- Быстрая проверка: не переоткрывать /invent между картами
        fastProbe = true,
        -- Rodina: инвентарь/уровни читаются из CEF-пакетов; неизвестный уровень уточняется диалогом карты
        packetLevels = true,
    },
    deley = {
        timeoutDialog = 10,
        waitInterval = 10,
        timeoutShelf = 10,
        -- Ждать перед отправкой ответа на диалог
        waitRun = 0,
        -- Повторов, если сервер не ответил на открытие полки
        shelfRetries = 2,
        -- Повторов дома, который не отработал целиком
        houseRetries = 1,
        -- Пуза после получения результата
        improve_waitResult = 500,
        -- Пуза перед нажатием на видеокарту в инвентаре
        improve_waitTryClick = 500,
        -- Пауза после /invent, пока инвентарь открывается
        improve_waitInventory = 1500,
        -- Интервал автоповтора CEF-клика на шаге подтверждения
        improve_retryUseDelay = 1200,
        -- Таймаут ожидания сообщения о старте улучшения
        improve_waitStartTimeout = 8,
        -- Таймаут ожидания итогового результата улучшения
        improve_waitResultTimeout = 20,
    },
    style = {
        -- Скрол пальцем
        swipeScroll = ISMONETLOADER,
        -- масштаб интерфейса
        scaleUI = 1.0,
        -- Цвет в тексте
        colorChat = '8cbf91',
        -- Цвет текста
        colorMessage = 0xFF8cbf91,
        -- Размер скроллбара
        scrollbarSizeStyle = 10,
        -- Стартовый размер основного окна скрипта
        sizeWindow = { x = 600, y = 400 },
        -- Цвета интерфейса
        mainColor   = { r = 0.25, g = 0.45, b = 0.28, a = 1.00},
        textColor   = { r = 0.80, g = 0.85, b = 0.80, a = 1.00},
        bgColor     = { r = 0.10, g = 0.15, b = 0.14, a = 0.98},
        accentColor = { r = 0.27, g = 0.25, b = 0.45, a = 1.00},
        -- Цвет префикса скрипта в чате
        chatColor   = { r = 0.55, g = 0.75, b = 0.57, a = 1.00},
        -- Смысловые цвета текста в окне
        okColor     = { r = 0.20, g = 1.00, b = 0.20, a = 1.00},
        warnColor   = { r = 1.00, g = 0.8824, b = 0.20, a = 1.00},
        badColor    = { r = 1.00, g = 0.20, b = 0.20, a = 1.00},
        -- Полосы заполнения: свободно / наполовину / почти полная
        barFreeColor = { r = 0.34, g = 0.56, b = 0.40, a = 0.85},
        barHalfColor = { r = 0.70, g = 0.60, b = 0.32, a = 0.85},
        barFullColor = { r = 0.68, g = 0.36, b = 0.34, a = 0.85},
        -- Столбики графиков в логах: обычный / выбранный / подложка
        graphBarColor    = { r = 0.34, g = 0.70, b = 0.42, a = 1.00},
        graphActiveColor = { r = 0.78, g = 0.68, b = 0.32, a = 1.00},
        graphBgColor     = { r = 0.16, g = 0.20, b = 0.18, a = 1.00},
    }
}

-- Настрокйи скрипта
local settings = defaultSettings

-- --------------------------------------------------------
--                           Imgui
-- --------------------------------------------------------

-- Разрешение экрана пользователя
local sizeScreanX, sizeScreanY = getScreenResolution()

local new = imgui.new

local imguiWindows = {
    -- Основное окно скрипта
    main = new.bool(false),
}
-- Текущая позиция основного окна
local windowPos = nil

-- Активный раздел в скрипте
local activeTabScript = "main"

local inputBlackHouse = new.int()
local inputIncomeHouse = new.int()

-- Состояния для элеметов в ui
local ui_state = {
    -- Состояние свайпа списка
    swipe = { active = false, DRAG_THRESHOLD = 6 },
    -- Состояние перетаскивания окна
    drag = {
        active = false,
        mx = 0, my = 0,       -- координаты мыши в момент начала перетаскивания
        wx = 0, wy = 0,       -- позиция окна в момент начала перетаскивания
    },
    collectLogs = {
        selectedDay = nil,
    },
    -- цвет меняли в этом кадре, сохранить настройки когда отпустят элемент
    colorsDirty = false,
}

-- --------------------------------------------------------
--                           State
-- --------------------------------------------------------

local processInteractingThread

local idDialogs = {
    selectVideoCard = 0,
    selectHouse = 0,
    mobileImproveStatus = 24680,
}

local stateCrypto = {
    -- Запущен ли процесс взаимодействия
    work = false,
    -- Ожидаме заливки видяхи
    waitFill = false,
    -- Количество, которое снимаем крипты
    takeCount = 0,
    -- Прогресс домов
    progressHouses = 0,
    -- Список домов в очереди
    queueHouses = {},
    -- Прогресс полок
    progressShelves = 0,
    -- Счётчик всех показанных диалогов и номер последнего списка полок.
    -- По ним видно, открыт ли список сейчас и прислал ли сервер его заново
    dialogSerial = 0,
    shelfListSerial = 0,
    -- Сколько полок пропущено из-за зависших диалогов
    shelvesSkipped = 0,
    -- Список полок в очереди
    queueShelves = {},
    -- Идентификатор текущего дома (номер) и валюта текущего take
    currentHouseId = nil,
    takeCurrency = nil,
    fillLiquidType = nil,
    fillLiquidLabel = nil,
    fillLiquidBefore = 0,
    fillLiquidAfter = 0,
    activeHouseID = "-1"
}

local processes = {
    -- собираем
    take = false,
    -- заливаем
    fill = false,
    -- включаем
    on = false,
    -- выключаем
    off = false,
}

local haveLiquid = {
    btc = 0,
}

-- Rodina cooling liquid: item 3205 from CEF inventory updates.
local RodinaCooling = {
    ITEM_ID = 3205,
    inventoryKnown = false,
    inventorySlot = nil,
    pendingDialogId = nil,
    pendingFillLine = nil,
    pendingOnLine = nil,
    pendingStartedAt = 0,
    cefPacketsSeen = 0,
    lastCefAt = 0,
    lastCefPreview = "",
    lastHookError = "",
    lastCefSource = "none",
    notificationPacketsSeen = 0,
    lastNotificationPreview = "",

    -- После успешной заливки диалог полки на Rodina остаётся открытым,
    -- но его данные уже устарели. Выходим кнопкой "Назад" в список карт
    -- и принимаем решение только по свежему диалогу "Выберите видеокарту".
    refreshPending = false,
    refreshShelfNumber = nil,
    refreshSampLine = nil,
    refreshStartedAt = 0,
    refreshToken = 0,
    fillStartListSerial = 0,
    guardBackSent = false,
}

local RodinaCollect = {
    pending = false,
    refreshPending = false,
    expectedAmount = 0,
    pendingShelfNumber = nil,
    pendingQueueIndex = 0,
    pendingStartedAt = 0,
    refreshStartedAt = 0,
    sourceShelfDialogId = nil,
    confirmDialogId = nil,
    lastAmount = 0,
    lastRemaining = nil,
    lastSource = "none",
}

-- Rodina: привязка подвала с вентиляцией к реальному ID дома.
-- Триггер - пользователь сам выбирает пункт "Войти в подвал с вентиляцией".
-- После этого MMT скрытно перебирает /home и ищет тот "Дом №N",
-- в меню которого доступны локальные хранилища текущего дома.
local RodinaHouseBind = {
    active = false,
    currentHouseId = nil,

    entryDialogId = nil,
    basementListIndex = nil,
    outsideListIndex = nil,

    phase = "idle",
    candidates = {},
    candidateIndex = 0,
    resolverDialogId = nil,
    startedAt = 0,
    serial = 0,

    foundHouseId = nil,
    pendingAbortReason = nil,

    attempt = 0,
    maxAttempts = 5,
    expectedDeadline = 0,

    retryPending = false,
    retryNotBefore = 0,
    lastDialogAt = 0,
    retryReason = nil,

    -- Короткое окно только для подавления запоздалых ответов старого resolver-а.
    -- На нормальном пути никакой задержки действий нет.
    suppressUntil = 0,
}

-- Статистика по сбору
local collectStats = {
    total = { BTC = 0 },
    house = {}  -- [house_number] = { BTC = 0 }
}
local collectLogStore = { days = {}, meta = {} }
local collectLogSave = { dirty = false, lastAt = 0, minInterval = 2 }
local collectReminder = {
    lastTickAt = 0,
    game = {},               -- [событие] = { notifiedAt, retryAt, pending } - напоминания в игре
    managerEnsurePending = false,
    managerDownloadPending = false,
    managerStatusMessage = "",
}
local collectReminderAction = nil

function RuntimeLog.State(reason)
    local proc = processes or {}
    local sc = stateCrypto or {}
    local rc = RodinaCooling or {}
    local rcollect = RodinaCollect or {}
    local rh = RodinaHouseBind or {}

    RuntimeLog.Write("STATE", string.format(
        "%s | project=%s server=%s | work=%s proc[take=%s fill=%s on=%s off=%s] | house=%s boundHouse=%s | progress[shelf=%s/%s house=%s/%s] | wait[fill=%s] | cooling[pending=%s refresh=%s shelf=%s line=%s] | collect[pending=%s refresh=%s shelf=%s] | bind[active=%s phase=%s attempt=%s]",
        tostring(reason or "snapshot"),
        "rodina",
        "Rodina-only",
        tostring(sc.work),
        tostring(proc.take), tostring(proc.fill), tostring(proc.on), tostring(proc.off),
        tostring(sc.currentHouseId),
        tostring(rh.currentHouseId),
        tostring(sc.progressShelves), tostring(#(sc.queueShelves or {})),
        tostring(sc.progressHouses), tostring(#(sc.queueHouses or {})),
        tostring(sc.waitFill),
        tostring(rc.pendingDialogId ~= nil), tostring(rc.refreshPending),
        tostring(rc.refreshShelfNumber), tostring(rc.refreshSampLine),
        tostring(rcollect.pending), tostring(rcollect.refreshPending),
        tostring(rcollect.pendingShelfNumber),
        tostring(rh.active), tostring(rh.phase), tostring(rh.attempt)
    ))
end

-- Доступные полки
local shelves = {}

local houses = {}
-- Дома с информацией о полках
--[id_house <string>] = { work_vc = <int> количество рабочих видеокарт, max_collect = <int> макс крипты в доме, min_liquid = <number> минимально охлаждайки в доме}
local housesData = {}

local Storage = {}
local Collect = {}
local Parser = {}
local Draw = {}
local Interacting = {}
local Chat = {}
local UI = {}
local Util = {}
function Util.EnsureDirectoryExists(path)
    local currentPath = ""
    for folder in string.gmatch(path, "[^/\\]+") do
        currentPath = currentPath .. folder .. "/"
        if not lfs.attributes(currentPath, "mode") then
            lfs.mkdir(currentPath)
        end
    end
end

local lastIDDialog = 0

local lastOpenHouse = 1
local lastOpenShelves = 1

function Util.StripColors(s)
    return tostring(s or ""):gsub("{%x+}", "")
end

-- --------------------------------------------------------
--                           Improve
-- --------------------------------------------------------
local Improve = {}
Improve.STEP = {
    STOPPED = 0,
    SELECT_CARD = 1, -- выбрать подходящую карту и кликнуть CEF-слот
    CONFIRM = 3,     -- обработать диалоги выбора/подтверждения улучшения
    WAIT_RESULT = 4, -- дождаться результата от сервера
}

local improve = {
    isOn = false,
    step = Improve.STEP.STOPPED,

    -- Кэш видеокарт из CEF-инвентаря
    videoCards   = {},     -- { { slot = <int>, level = <int> } ... }
    select       = 0,      -- индекс выбранной карты (UI)
    selectSlot   = 0,      -- выбранный slot для режима одной карты
    currentIndex = 0,      -- индекс текущей карты в актуальном списке
    currentSlot  = 0,      -- стабильная identity текущей карты (не ломается при сортировке)

    oils = { -- Rodina: смазка item 3204
        classic = 0,
        known = false,
        slot = nil,
        lastAt = '-',
        busy = false,
    },
    needCheckOils   = false,   -- флаг: после старта надо проверить инвентарь
    waitOils        = false,   -- ждём завершения обновления CEF-инвентаря
    consumedThisTry = false,   -- на текущую попытку уже учли 2 смазки в статистике
    resultHandled   = false,   -- защита от двойного результата (CEF + чат)
    waitStart       = false,   -- legacy-флаг; Rodina после подтверждения сразу ждёт результат
    waitStartAt     = 0,
    waitResultAt    = 0,
    lastUseAt       = 0,

    -- Логи и статистика заточки
    logs = {
        items      = {},   -- { { ts="дата-время", type="INFO", text="...", step=Improve.STEP.SELECT_CARD } ... }
        max        = 300,  -- макс. количество записей
        autoScroll = true, -- автопрокрутка вниз в UI
    },
    stats = {
        sessionId  = 0,
        active     = false,
        startedAt  = 0,
        finishedAt = 0,
        attempts   = 0,
        success    = 0,
        fail       = 0,
        oilsUsed   = 0,
        byLevel    = {},
        lastReason = "",
    },
    cef = {
        stubNotified = false,
        lastPacketId = 0,
        lastPacket = '',
        cards = {},
        inventoryFresh = false,   -- инвентарь уже открыт, можно кликать без /invent
        inventoryOpen = false,    -- мы открывали инвентарь и ещё не закрывали его
        inventoryBlockedUntil = 0,-- сервер попросил подождать перед следующим /invent
        unknownCount = 0,         -- сколько карт выбранного типа остались без уровня
        probing = false,
        probeDone = false,
        probed = false,
        pendingSlot = nil,
        pendingIndex = 0,
        needInventoryRefresh = true,
        waitInventory = false,
        probeAbort = false,
        probeAbortReason = '',
        probeProgress = 0,
        probeTotal = 0,
        watchdogMark = '',      -- слепок прогресса проверки для сторожа
        watchdogAt = 0,
        pktLevels = {},         -- уровни карт из пакетов инвентаря: [слот] = { level, cardType, at }
        pktInvAt = 0,           -- когда в последний раз приходил инвентарь пакетом
        inventorySlots = {},    -- merge CEF-инвентаря по slot
        inventorySerial = 0,    -- растёт на каждом пакете type=1 с items
        inventoryLastAt = 0,
    },
}

Improve.stepNames = {
    [Improve.STEP.STOPPED] = 'Улучшение выключено',
    [Improve.STEP.SELECT_CARD] = 'Выбор карты и CEF-слота',
    [Improve.STEP.CONFIRM] = 'Подтверждение улучшения',
    [Improve.STEP.WAIT_RESULT] = 'Ожидание результата'
}

function Improve.Say(msg)
    Chat.Add("Улучшение: "..tostring(msg), TYPECHATMESSAGES.SECONDARY)
end

local mobileImproveDialog = {
    lastShowAt = 0,
    suppressUntil = 0,
    closing = false,
    lastText = '',
    wasActive = false,
    -- true, пока скрипт сам открывает/закрывает диалоги: исчезновение статуса
    -- в этот момент не считается нажатием "Остановить"
    scriptBusy = false,
}

-- Запомненные уровни видеокарт: { slots = { ["<slot>"] = { name, level, cardType, at } } }
local cardLevels = { slots = {}, dirty = false, lastSaveAt = 0 }

function Improve.IsMobileStatusDialogActive()
    if type(sampIsDialogActive) ~= 'function' or type(sampGetCurrentDialogId) ~= 'function' then
        return false
    end

    local okActive, active = pcall(sampIsDialogActive)
    if not okActive or not active then return false end

    local okId, currentId = pcall(sampGetCurrentDialogId)
    return okId and tonumber(currentId) == idDialogs.mobileImproveStatus
end

function Improve.CloseMobileStatusDialog(suppressMs)
    if not ISMONETLOADER then return end

    mobileImproveDialog.suppressUntil = os.clock() + ((tonumber(suppressMs or 0) or 0) / 1000)
    if not Improve.IsMobileStatusDialogActive() then return end
    if type(sampCloseCurrentDialogWithButton) ~= 'function' then return end

    mobileImproveDialog.closing = true
    pcall(sampCloseCurrentDialogWithButton, 1)
end

-- Статус-диалог обновляется только пока идёт заточка или проверка уровней.
-- Когда всё закончилось, закрыть его больше некому - делаем это сами.
-- Повтор не чаще раза в 3 секунды: CloseMobileStatusDialog двигает suppressUntil.
function Improve.FinishProbeUI()
    if not ISMONETLOADER then return end
    if improve.isOn or improve.cef.probing then return end
    if not Improve.IsMobileStatusDialogActive() then return end
    if os.clock() < (mobileImproveDialog.suppressUntil or 0) then return end

    mobileImproveDialog.wasActive = false
    Improve.CloseMobileStatusDialog(3000)
end

-- Инвентарь закрывается кликом по несуществующему текстдраву:
-- отдельного CEF-пакета на закрытие у iface 52 нет.
function Improve.CloseInventory()
    if type(sampSendClickTextdraw) ~= 'function' then return end
    pcall(sampSendClickTextdraw, 65535)
    improve.cef.inventoryFresh = false
    improve.cef.inventoryOpen = false
    -- сразу после закрытия сервер не даёт открыть инвентарь снова
    improve.cef.inventoryBlockedUntil = os.clock() + 1.2
end

-- Сервер отвечает "Нельзя так быстро открывать инвентарь": ждём, пока он снова разрешит
function Improve.WaitInventoryCooldown()
    local guard = os.clock() + 6
    while os.clock() < (improve.cef.inventoryBlockedUntil or 0) do
        if os.clock() > guard then break end
        wait(100)
    end
end

-- =====================================================================================================================
--                        Rodina CEF-инвентарь: видеокарты + смазка
-- =====================================================================================================================
local RODINA_GPU_ITEM_ID = 3206
local RODINA_OIL_ITEM_ID = 3204
local CEF_CARD_ITEMS = { [RODINA_GPU_ITEM_ID] = 1 }

function Improve.UsePacketLevels()
    return true
end

function Improve.LevelFromSlotData(itemData)
    if type(itemData) ~= 'table' then return nil end
    local level = tonumber(itemData.unic_id)
    if not level and type(itemData.text) == 'string' then
        level = tonumber(itemData.text:match('^%s*(%d+)%s*lvl%s*$'))
    end
    if not level then
        local income = tonumber(itemData.plus_btc)
        if income then
            for lvl, hourly in pairs(GetGpuHourlyTable()) do
                if math.abs(hourly - income) < 0.0005 then
                    level = lvl
                    break
                end
            end
        end
    end
    if not level or level < 1 or level > 10 then return nil end
    return level
end

function Improve.PacketLevelForSlot(slot, cardType)
    local entry = improve.cef.pktLevels[tonumber(slot) or 0]
    if type(entry) ~= 'table' then return nil end
    return tonumber(entry.level)
end

function Improve.ForgetPacketLevels()
    improve.cef.pktLevels = {}
    improve.cef.pktInvAt = 0
end

function Improve.ApplyPacketCardSlot(slot, itemId, itemData)
    if tonumber(itemId) ~= RODINA_GPU_ITEM_ID then return false end
    slot = tonumber(slot)
    if not slot then return false end
    local level = Improve.LevelFromSlotData(itemData)
    if level then
        improve.cef.pktLevels[slot] = { level = level, cardType = 1, at = os.time() }
    end
    for _, c in ipairs(improve.cef.cards or {}) do
        if tonumber(c.slot) == slot then
            if level then
                c.level = level
                c.levelKnown = true
                c.levelGuessed = false
                c.probeFailed = false
                Improve.CardCacheSet(c.slot, c.name, level, 1)
            end
            return true
        end
    end
    return level ~= nil
end

function Improve.MergeInventorySlot(itemData)
    if type(itemData) ~= 'table' then return end
    local slot = tonumber(itemData.slot)
    if slot == nil then return end
    if itemData.item == nil then
        improve.cef.inventorySlots[slot] = nil
        improve.cef.pktLevels[slot] = nil
        if tonumber(improve.oils.slot) == slot then
            improve.oils.classic = 0
            improve.oils.known = true
            improve.oils.slot = nil
        end
        return
    end
    local itemId = tonumber(itemData.item)
    local old = improve.cef.inventorySlots[slot]
    local merged = {}
    if type(old) == 'table' and tonumber(old.item) == itemId then
        for k, v in pairs(old) do merged[k] = v end
    end
    for k, v in pairs(itemData) do merged[k] = v end
    improve.cef.inventorySlots[slot] = merged
end

function Improve.RebuildRodinaInventoryFromSlots()
    local seenCards = {}
    local oilCount = nil
    local oilSlot = nil
    for slot, data in pairs(improve.cef.inventorySlots or {}) do
        local itemId = tonumber(data and data.item)
        if itemId == RODINA_GPU_ITEM_ID then
            seenCards[tonumber(slot)] = true
            Improve.AddCefCardSlot(slot, 'Rodina Video Card', 1)
            local level = Improve.LevelFromSlotData(data) or Improve.PacketLevelForSlot(slot, 1)
            if level then Improve.ApplyPacketCardSlot(slot, itemId, data) end
        elseif itemId == RODINA_OIL_ITEM_ID then
            oilSlot = tonumber(slot)
            oilCount = tonumber(data.amount)
            if oilCount == nil and type(data.text) == 'string' then
                oilCount = tonumber(data.text:match('(%d+)'))
            end
        end
    end
    for i = #(improve.cef.cards or {}), 1, -1 do
        local c = improve.cef.cards[i]
        if not seenCards[tonumber(c.slot)] then
            Improve.CardCacheForget(c.slot)
            table.remove(improve.cef.cards, i)
        end
    end
    if oilSlot then improve.oils.slot = oilSlot end
    if oilCount ~= nil then
        improve.oils.classic = math.maxEx(0, math.floor(oilCount))
        improve.oils.known = true
    end
    Improve.SyncVideoCardsFromCef()
end

function Improve.ApplyPacketInventoryPage(page)
    if type(page) ~= 'table' then return end
    local body = (type(page.data) == 'table') and page.data or page
    if type(body.items) ~= 'table' then return end
    if (tonumber(body.type) or 1) ~= 1 then return end
    local action = tonumber(page.action) or tonumber(body.action)
    if action ~= nil and action ~= 0 and action ~= 2 then return end
    for _, itemData in ipairs(body.items) do
        Improve.MergeInventorySlot(itemData)
        if type(itemData) == 'table' then
            local slot = tonumber(itemData.slot)
            local itemId = tonumber(itemData.item)
            if slot and itemId == RODINA_GPU_ITEM_ID then
                Improve.ApplyPacketCardSlot(slot, itemId, itemData)
            end
        end
    end
    improve.cef.inventorySerial = (tonumber(improve.cef.inventorySerial) or 0) + 1
    improve.cef.inventoryLastAt = os.clock()
    improve.cef.pktInvAt = os.clock()
    Improve.RebuildRodinaInventoryFromSlots()
end

-- Чтение CEF-пакета: ПК шлёт тип 17, мобильный клиент - тип 84 с iface/sub
function Improve.CefPayloadLooksText(payload)
    if type(payload) ~= 'string' or payload == '' then return false end

    local text = payload:gsub('%z', '')
    if text:find('window.', 1, true)
        or text:find('event.', 1, true)
        or text:find('cef.', 1, true)
        or text:find('JSON.stringify', 1, true)
    then
        return true
    end

    local first = text:sub(1, 1)
    if first == '{' or first == '[' then return true end

    return text:match('^[%w_%.%-]+[|%(]') ~= nil
end

function Improve.ReadCefPacket17Candidate(bs, withEncodedByte)
    local ok, payload = pcall(function()
        raknetBitStreamResetReadPointer(bs)
        raknetBitStreamIgnoreBits(bs, 8)
        if raknetBitStreamReadInt8(bs) ~= 17 then return nil end

        raknetBitStreamIgnoreBits(bs, 32)
        local len = raknetBitStreamReadInt16(bs)
        if not len or len <= 0 or len > 200000 then return nil end

        if withEncodedByte then
            local encoded = raknetBitStreamReadInt8(bs)
            if encoded == nil then return nil end
            if encoded ~= 0 then
                return raknetBitStreamDecodeString(bs, len + encoded)
            end
            return raknetBitStreamReadString(bs, len)
        end

        return raknetBitStreamReadString(bs, len)
    end)

    pcall(raknetBitStreamResetReadPointer, bs)
    if not ok or type(payload) ~= 'string' or payload == '' then return nil end
    return payload
end

-- Чтение CEF-пакета. У PC type 17 встречаются два варианта оболочки:
-- с байтом encoded после длины и без него. Старый Improve умел только первый,
-- поэтому часть обычных window.executeEvent на Rodina могла теряться.
function Improve.ReadCefPacket(id, bs)
    if id ~= 220 or not bs then return nil end

    pcall(raknetBitStreamResetReadPointer, bs)
    local okType, packetType = pcall(function()
        raknetBitStreamIgnoreBits(bs, 8)
        return raknetBitStreamReadInt8(bs)
    end)
    pcall(raknetBitStreamResetReadPointer, bs)

    if not okType then return nil end

    if packetType == 17 then
        local encodedPayload = Improve.ReadCefPacket17Candidate(bs, true)
        local rawPayload = Improve.ReadCefPacket17Candidate(bs, false)

        local encodedLooks = Improve.CefPayloadLooksText(encodedPayload)
        local rawLooks = Improve.CefPayloadLooksText(rawPayload)

        -- Если один вариант явно похож на CEF-текст, берём его.
        -- При равенстве сохраняем старое поведение Improve и предпочитаем encoded.
        if rawLooks and not encodedLooks then
            improve.cef.lastDecodeMode = '17-raw'
            return nil, nil, rawPayload
        end
        if encodedLooks then
            improve.cef.lastDecodeMode = '17-encoded'
            return nil, nil, encodedPayload
        end
        if rawLooks then
            improve.cef.lastDecodeMode = '17-raw'
            return nil, nil, rawPayload
        end

        local fallback = encodedPayload or rawPayload
        if fallback then
            improve.cef.lastDecodeMode = encodedPayload and '17-encoded-fallback' or '17-raw-fallback'
            return nil, nil, fallback
        end
        return nil
    end

    if packetType == 84 then
        local ok, iface, sub, payload = pcall(function()
            raknetBitStreamResetReadPointer(bs)
            raknetBitStreamIgnoreBits(bs, 8)
            if raknetBitStreamReadInt8(bs) ~= 84 then return nil end

            local ifaceId = raknetBitStreamReadInt8(bs)
            local subId = raknetBitStreamReadInt8(bs)
            local len = raknetBitStreamReadInt16(bs)
            local encoded = raknetBitStreamReadInt8(bs)
            if not len or len <= 0 or len > 200000 or encoded == nil then return nil end

            if encoded ~= 0 then
                return ifaceId, subId, raknetBitStreamDecodeString(bs, len + 1)
            end
            return ifaceId, subId, raknetBitStreamReadString(bs, len)
        end)

        pcall(raknetBitStreamResetReadPointer, bs)
        if not ok or type(payload) ~= 'string' or payload == '' then return nil end
        improve.cef.lastDecodeMode = '84'
        return iface, sub, payload
    end

    return nil
end

-- Ловим пакеты инвентаря игрока и достаём из них уровни видеокарт
function Improve.ProcessInventoryCefPayload(_iface, _sub, _payload)
    if type(_payload) ~= 'string' or _payload == '' then return end

    -- On mobile inventory packets use iface 52: sub 0 is the full inventory, sub 2 is an update.
    if _iface ~= nil and (_iface ~= 52 or (_sub ~= 0 and _sub ~= 2)) then return end

    -- Cheap filter: shop interfaces (type 13 and 28) are not the player's inventory.
    if not _payload:find('"items"', 1, true) then return end
    if _payload:find('"type":13', 1, true) or _payload:find('"type":28', 1, true) then return end

    local _text = _payload:gsub('%z', '')
    local _first = _text:sub(1, 1)
    if _first ~= '{' and _first ~= '[' then
        _text = _text:match('(%b[])') or _text:match('(%b{})') or ''
    end
    if _text == '' then return end

    local _okJson, _data = pcall(json.decode, _text)
    if not _okJson or type(_data) ~= 'table' then return end

    if type(_data.data) == 'table' or type(_data.items) == 'table' then
        Improve.ApplyPacketInventoryPage(_data)
        return
    end

    for _, page in ipairs(_data) do
        Improve.ApplyPacketInventoryPage(page)
    end
end

function Improve.PayloadHasText(payload, text)
    if type(payload) ~= 'string' or type(text) ~= 'string' then return false end
    if payload:find(text, 1, true) then return true end
    local utf = u8(text)
    return type(utf) == 'string' and payload:find(utf, 1, true) ~= nil
end

function Improve.ScheduleNextAfterResult()
    MMTCreateThread(function()
        wait(settings.deley.improve_waitResult or 500)
        if not improve.isOn then return end
        improve.waitResultAt = 0
        improve.lastUseAt = 0
        improve.step = Improve.STEP.SELECT_CARD
        improve.currentSlot = 0
        improve.consumedThisTry = false
        improve.resultHandled = false
    end)
end

function Improve.HandleUpgradeResult(success, message, forcedLevel, source)
    if not (improve.isOn and improve.step == Improve.STEP.WAIT_RESULT) then return false end
    if improve.resultHandled then return true end
    improve.resultHandled = true
    Improve.LogAdd('INFO', string.format('Результат улучшения получен через %s: %s.', tostring(source or '?'), success and 'успех' or 'ошибка'))
    Improve.OnResult(success == true, message, forcedLevel)
    Improve.ScheduleNextAfterResult()
    return true
end

function Improve.HandleRodinaImproveCefPayload(payload)
    if type(payload) ~= 'string' or payload == '' then return end
    if payload:find('event.setActiveView', 1, true) then
        if payload:find('["Inventory"]', 1, true) then
            improve.cef.inventoryOpen = true
            improve.cef.inventoryFresh = true
        elseif payload:find('[ null ]', 1, true) or payload:find('[null]', 1, true) then
            improve.cef.inventoryOpen = false
            improve.cef.inventoryFresh = false
        end
    end
    if not (improve.isOn and improve.step == Improve.STEP.WAIT_RESULT) then return end
    if improve.resultHandled then return end
    if not payload:find('cef.addNotification', 1, true) then return end
    local isSuccess = payload:find('"type":"succeeded"', 1, true) ~= nil
        and Improve.PayloadHasText(payload, 'успешно улучшили выбранную видеокарту')
    local isFail = payload:find('"type":"error"', 1, true) ~= nil
        and Improve.PayloadHasText(payload, 'техническую ошибку')
    if not isSuccess and not isFail then return end
    local forcedLevel = nil
    if isSuccess then
        local utfPattern = u8('до%s+(%d+)%-го%s+уровня')
        forcedLevel = tonumber(payload:match(utfPattern) or payload:match('до%s+(%d+)%-го%s+уровня'))
    end
    Improve.HandleUpgradeResult(isSuccess, payload, forcedLevel, 'CEF')
end

-- Compatibility wrapper for old calls: decode with the same Improve CEF reader and process inventory data.
function Improve.CaptureInventoryPacket(id, bs)
    local _iface, _sub, _payload = Improve.ReadCefPacket(id, bs)
    if not _payload then return end
    Improve.ProcessInventoryCefPayload(_iface, _sub, _payload)
end

-- One CEF router for the whole MMT. The packet is decoded once by the same reader
-- that the GPU improve module already uses. Consumers receive the already decoded payload.
function Improve.RouteCefPacket(id, bs)
    local _iface, _sub, _payload = Improve.ReadCefPacket(id, bs)
    if not _payload then return end

    RuntimeLog.Payload("CEF", string.format(
        "packet=%s iface=%s sub=%s decode=%s",
        tostring(id), tostring(_iface), tostring(_sub), tostring(improve.cef.lastDecodeMode or "?")
    ), _payload)

    -- Existing MMT functionality: inventory/GPU levels for Improve.
    local okInventory, errInventory = pcall(Improve.ProcessInventoryCefPayload, _iface, _sub, _payload)
    if not okInventory then
        print('[MMT] CEF inventory route error: ' .. tostring(errInventory))
    end

    local okImprove, errImprove = pcall(Improve.HandleRodinaImproveCefPayload, _payload)
    if not okImprove then
        print('[MMT] Rodina improve CEF route error: ' .. tostring(errImprove))
    end

    -- Rodina-specific consumer reuses exactly the same decoded payload.
    if type(RodinaCooling.HandleCefPayload) == 'function' then
        local okCooling, errCooling = pcall(RodinaCooling.HandleCefPayload, _payload, 'Improve.ReadCefPacket:' .. tostring(improve.cef.lastDecodeMode or '?'))
        if not okCooling then
            RodinaCooling.lastHookError = tostring(errCooling or 'CEF cooling route error')
        end
    end

    if type(RodinaCollect.HandleCefPayload) == 'function' then
        local okTake, errTake = pcall(RodinaCollect.HandleCefPayload, _payload, 'Improve.ReadCefPacket:' .. tostring(improve.cef.lastDecodeMode or '?'))
        if not okTake then
            print('[MMT] Rodina collect CEF route error: ' .. tostring(errTake))
        end
    end
end

addEventHandler('onReceivePacket', function(id, bs)
    local ok, err = pcall(Improve.RouteCefPacket, id, bs)
    if not ok then
        RodinaCooling.lastHookError = tostring(err or 'CEF router error')
        print('[MMT] CEF router error: ' .. tostring(err))
    end
end)

-- Попросить сервер прислать инвентарь целиком: один такой запрос заменяет
-- поштучную проверку карт. Вызывать только из потока - внутри есть wait
function Improve.RequestInventoryDump(timeoutSec)
    local mark = tonumber(improve.cef.inventorySerial) or 0
    if ISMONETLOADER then
        Improve.CloseMobileStatusDialog(((tonumber(timeoutSec) or 5) * 1000) + 1000)
    end

    if improve.cef.inventoryOpen then
        Improve.CloseInventory()
        wait(150)
    end

    Improve.WaitInventoryCooldown()
    improve.cef.inventoryOpen = false
    improve.cef.inventoryFresh = false

    -- MonetLoader/Rodina: у мобильного инвентаря отдельный CEF-интерфейс 52.
    -- sub=0 запрашивает полный инвентарь. На ПК оставляем обычный /invent.
    if ISMONETLOADER then
        improve.cef.inventoryOpen = true
        local sent = Improve.SendCefMobile(52, 0, 4294967295, '""')
        RuntimeLog.Write('IMPROVE_MOBILE', string.format(
            'inventory dump request | iface=52 sub=0 sent=%s serial=%s',
            tostring(sent), tostring(mark)
        ))
        if not sent then
            improve.cef.inventoryOpen = false
            return false
        end
    else
        sampSendChat('/invent')
    end

    local deadline = os.clock() + (tonumber(timeoutSec) or 5)
    local got = false
    while os.clock() < deadline do
        wait(25)
        if (tonumber(improve.cef.inventorySerial) or 0) > mark then
            got = true
            break
        end
    end

    -- Полный инвентарь приходит несколькими страницами подряд.
    if got then wait(ISMONETLOADER and 400 or 350) end

    Improve.RebuildRodinaInventoryFromSlots()
    Improve.CloseInventory()
    improve.cef.inventoryOpen = false
    improve.cef.inventoryFresh = false

    if ISMONETLOADER then
        RuntimeLog.Write('IMPROVE_MOBILE', string.format(
            'inventory dump result | got=%s serialNow=%s cards=%s oilKnown=%s oil=%s',
            tostring(got), tostring(improve.cef.inventorySerial),
            tostring(#(improve.cef.cards or {})), tostring(improve.oils.known),
            tostring(improve.oils.classic)
        ))
    end

    return got
end

-- Завершение проверки уровней: убираем за собой статус и инвентарь.
-- Только когда заточка не идёт - в автоматическом цикле инвентарь ещё нужен.
function Improve.FinishProbe()
    if improve.isOn or improve.cef.probing then return end
    Improve.FinishProbeUI()
    Improve.CloseInventory()
end

-- Проверка уровней крутится в отдельном потоке. Если он оборвётся, probing
-- останется true навсегда: статус будет висеть, а закрыть его будет некому.
-- Поэтому следим за прогрессом и при полном застое сбрасываем состояние.
function Improve.ProbeWatchdogTick()
    if not improve.cef.probing then
        improve.cef.watchdogMark = ''
        return
    end

    local mark = string.format('%s|%s|%s|%s',
        tostring(improve.cef.pendingIndex or 0),
        tostring(improve.cef.pendingSlot or '-'),
        tostring(improve.cef.probeProgress or 0),
        tostring(improve.cef.probeDone))

    local now = os.clock()
    if mark ~= improve.cef.watchdogMark then
        improve.cef.watchdogMark = mark
        improve.cef.watchdogAt = now
        return
    end

    -- запас: полный цикл попыток по одной карте плюс 30 секунд
    local timeoutDialog = tonumber(settings.deley.timeoutDialog) or 10
    local retries = math.maxEx(0, tonumber(settings.improve.probeRetries) or 2)
    local limit = math.maxEx(60, timeoutDialog * (retries + 1) + 30)
    if (now - (improve.cef.watchdogAt or 0)) < limit then return end

    improve.cef.watchdogMark = ''
    -- probeAbort будит поток проверки, если он всё же жив: он выйдет сам
    improve.cef.probeAbort = true
    improve.cef.probeAbortReason = 'проверка зависла'
    improve.cef.probeDone = true
    improve.cef.probing = false
    improve.cef.pendingSlot = nil
    improve.cef.pendingIndex = 0
    mobileImproveDialog.scriptBusy = false

    Improve.LogAdd('WARN', string.format('Проверка уровней зависла (%d сек без прогресса) - состояние сброшено.', math.floor(limit)))
    Improve.Say('Проверка уровней зависла - состояние сброшено.')
    Improve.FinishProbe()
end

function Improve.GetMobileStatusText()
    local lines = {}
    -- ручная проверка уровней идёт при выключенной заточке (improve.isOn = false),
    -- поэтому её состояние показываем отдельно, иначе статус врёт про 'остановлено'
    local probingOnly = improve.cef.probing and not improve.isOn
    local stepName = probingOnly and 'Проверка уровней видеокарт'
        or (Improve.stepNames[improve.step] or '?')
    local statusName = improve.isOn and 'работает'
        or (probingOnly and 'проверка уровней' or 'остановлено')
    table.insert(lines, string.format('Статус: %s', statusName))
    table.insert(lines, string.format('Этап: %s', stepName))

    if improve.waitOils or improve.oils.busy then
        table.insert(lines, 'Инвентарь: обновляется')
    else
        local count, name = Improve.GetOilCountByType()
        table.insert(lines, string.format('Смазка: %d шт. (%s)', count or 0, name or '-'))
    end

    if improve.cef.probing then
        local done = math.maxEx(0, tonumber(improve.cef.pendingIndex or 0) or 0)
        local total = math.maxEx(1, tonumber(improve.cef.probeTotal or 0) or 0)
        table.insert(lines, string.format('Проверка уровней: %d/%d', done, total))
        if improve.cef.pendingSlot then
            table.insert(lines, string.format('Проверяется слот: %s', tostring(improve.cef.pendingSlot)))
        end
    elseif improve.cef.probed and (tonumber(improve.cef.probeTotal or 0) or 0) > 0 then
        table.insert(lines, string.format('Проверка уровней: завершена (%d/%d)', improve.cef.probeProgress or 0, improve.cef.probeTotal or 0))
    elseif (improve.cef.probeAbortReason or '') ~= '' then
        table.insert(lines, 'Проверка уровней: остановлена - ' .. tostring(improve.cef.probeAbortReason))
    end

    local idx = tonumber(improve.currentIndex or 0) or 0
    local card = nil
    local wantedSlot = tonumber(improve.currentSlot or 0) or 0
    if wantedSlot > 0 then
        for i, v in ipairs(improve.videoCards or {}) do
            if tonumber(v.slot or 0) == wantedSlot then card = v; idx = i; break end
        end
    else
        card = improve.videoCards[idx]
    end
    if card then
        table.insert(lines, string.format('Текущая карта: #%d, слот %d, уровень %d', idx, tonumber(card.slot or 0) or 0, tonumber(card.level or 0) or 0))
    end

    local s = improve.stats
    if s and (s.sessionId or 0) > 0 then
        table.insert(lines, string.format('Сессия #%d: попыток %d, успехов %d, ошибок %d', s.sessionId or 0, s.attempts or 0, s.success or 0, s.fail or 0))
        table.insert(lines, string.format('Потрачено смазки: %d', s.oilsUsed or 0))
    end

    table.insert(lines, '')
    table.insert(lines, 'Статус обновляется автоматически.')
    table.insert(lines, 'Кнопка - остановить процесс.')
    return table.concat(lines, '\n')
end

function Improve.ShowMobileStatusDialog(force)
    if not ISMONETLOADER then return end
    if not (improve.isOn or improve.cef.probing) then return end
    if improve.step == Improve.STEP.CONFIRM or improve.oils.busy then return end
    if os.clock() < (mobileImproveDialog.suppressUntil or 0) then return end
    if type(sampShowDialog) ~= 'function' then return end

    local currentIsStatus = Improve.IsMobileStatusDialogActive()
    if type(sampIsDialogActive) == 'function' and type(sampGetCurrentDialogId) == 'function' then
        local okActive, active = pcall(sampIsDialogActive)
        if okActive and active and not currentIsStatus then return end
    end

    local now = os.clock()
    local minUpdateDelay = improve.cef.probing and 0.25 or 1.0
    if not force and currentIsStatus and (now - (mobileImproveDialog.lastShowAt or 0)) < minUpdateDelay then return end

    local text = Improve.GetMobileStatusText()
    if not force and currentIsStatus and text == mobileImproveDialog.lastText then return end

    mobileImproveDialog.lastText = text
    mobileImproveDialog.lastShowAt = now
    sampShowDialog(idDialogs.mobileImproveStatus, '{33CCFF}MMT | Заточка видеокарт', text, 'Остановить', '', 0)
    mobileImproveDialog.wasActive = true
end

function Improve.StopFromMobileStatus()
    if improve.cef.probing and not improve.isOn then
        improve.cef.probeAbort = true
        improve.cef.probeAbortReason = 'остановлено через мобильный статус'
        improve.cef.probeDone = true
    elseif improve.isOn then
        Improve.Stop('Остановлено через мобильный статус')
    end
    mobileImproveDialog.suppressUntil = os.clock() + 3600
    mobileImproveDialog.wasActive = false
end

function Improve.MobileStatusTick()
    if not ISMONETLOADER then return end

    if not (improve.isOn or improve.cef.probing) then
        mobileImproveDialog.wasActive = false
        Improve.FinishProbeUI()
        return
    end

    local active = Improve.IsMobileStatusDialogActive()
    if mobileImproveDialog.wasActive and not active then
        mobileImproveDialog.wasActive = false
        if mobileImproveDialog.closing then
            mobileImproveDialog.closing = false
            return
        end
        -- Пока скрипт сам работает с диалогами (проверка уровней, открытие карты),
        -- пропавший статус - это наш же диалог, а не нажатие игрока
        if mobileImproveDialog.scriptBusy or improve.cef.probing then
            return
        end
        if os.clock() < (mobileImproveDialog.suppressUntil or 0) then
            return
        end
        Improve.StopFromMobileStatus()
        return
    end

    if active then
        mobileImproveDialog.wasActive = true
    end

    Improve.ShowMobileStatusDialog(false)
end

function Improve.HandleMobileStatusDialogResponse(btn)
    if not ISMONETLOADER then return false end

    if mobileImproveDialog.closing then
        mobileImproveDialog.closing = false
        mobileImproveDialog.wasActive = false
        return false
    end

    Improve.StopFromMobileStatus()
    return false
end

function Improve.IsNewStyleMode()
    return true
end


function Improve.GetInventoryModeName()
    return "CEF-инвентарь Rodina"
end

function Improve.SendCef(payload)
    if not payload or payload == '' then return false end
    local bs = raknetNewBitStream()
    if not bs then return false end
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #payload)
    raknetBitStreamWriteString(bs, payload)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
    return true
end

function Improve.SendCefMobile(iface, sub, reqid, payload)
    iface = tonumber(iface or 0) or 0
    sub = tonumber(sub or 0) or 0
    reqid = tonumber(reqid or -1) or -1
    if reqid > 2147483647 then reqid = reqid - 4294967296 end
    payload = payload ~= nil and tostring(payload) or ''

    local bs = raknetNewBitStream()
    if not bs then return false end

    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 0x3F)
    raknetBitStreamWriteInt8(bs, iface)
    raknetBitStreamWriteInt32(bs, reqid)
    raknetBitStreamWriteInt32(bs, sub)

    if payload ~= '' then
        raknetBitStreamWriteInt16(bs, #payload)
        raknetBitStreamWriteString(bs, payload)
    else
        raknetBitStreamWriteInt16(bs, 0)
    end

    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
    return true
end

function Improve.SendCefClickOnSlot(slot, action, clickType)
    slot = tonumber(slot or 0) or 0
    action = tonumber(action or 1) or 1
    clickType = tonumber(clickType or 1) or 1
    if slot <= 0 then return false end

    local packet = string.format('clickOnButton|{"type": %d,"slot": %d, "action": %d}', clickType, slot, action)
    improve.cef.lastPacketId = 220
    improve.cef.lastPacket = packet
    return Improve.SendCef(packet)
end

-- skipInvent = инвентарь уже открыт, хватит одного CEF-клика
function Improve.OpenCardDialog(slot, action, clickType, skipInvent)
    slot = tonumber(slot or 0) or 0
    if slot <= 0 then return false end

    local inventWait = tonumber(settings.deley.improve_waitInventory) or 1500

    if ISMONETLOADER then
        -- Мобильный статус сам является SA-MP диалогом и не должен мешать
        -- серверному диалогу улучшения видеокарты.
        Improve.CloseMobileStatusDialog(improve.cef.probing and (inventWait + 1000) or 3000)
    end

    if not (skipInvent and improve.cef.inventoryOpen) then
        if improve.cef.inventoryOpen then
            Improve.CloseInventory()
            wait(150)
        end

        Improve.WaitInventoryCooldown()
        improve.cef.inventoryOpen = false
        improve.cef.inventoryFresh = false

        if ISMONETLOADER then
            -- В оригинальной mobile-ветке предмет используется через iface 52/sub 3.
            -- Перед этим запрашиваем iface 52/sub 0, чтобы сервер создал актуальный
            -- контекст мобильного инвентаря и прислал свежие слоты.
            local mark = tonumber(improve.cef.inventorySerial) or 0
            improve.cef.inventoryOpen = true
            local opened = Improve.SendCefMobile(52, 0, 4294967295, '""')
            RuntimeLog.Write('IMPROVE_MOBILE', string.format(
                'open inventory context | slot=%d sent=%s serial=%s',
                slot, tostring(opened), tostring(mark)
            ))

            if opened then
                local deadline = os.clock() + math.maxEx(1.0, inventWait / 1000 + 1.0)
                while os.clock() < deadline do
                    wait(25)
                    if (tonumber(improve.cef.inventorySerial) or 0) > mark then
                        break
                    end
                end
                wait(120)
            else
                improve.cef.inventoryOpen = false
                return false
            end
        else
            sampSendChat('/invent')
            local deadline = os.clock() + math.maxEx(1.0, inventWait / 1000 + 1.0)
            while not improve.cef.inventoryOpen and os.clock() < deadline do
                wait(25)
            end
            if not improve.cef.inventoryOpen then wait(150) end
        end
    else
        wait(ISMONETLOADER and 120 or 80)
    end

    if ISMONETLOADER then
        -- MonetLoader protocol: use item from player inventory.
        -- This is the mobile equivalent of PC inventory.moveItemForce.
        local payload = string.format('{"action":1,"id":0,"slot":%d,"type":1}', slot)
        improve.cef.lastPacketId = 220
        improve.cef.lastPacket = payload
        local sent = Improve.SendCefMobile(52, 3, 4294967295, payload)

        RuntimeLog.Write('IMPROVE_MOBILE', string.format(
            'use GPU | slot=%d iface=52 sub=3 sent=%s payload=%s',
            slot, tostring(sent), payload
        ))

        if sent then
            improve.cef.inventoryOpen = false
            improve.cef.inventoryFresh = false
        end
        return sent
    end

    local packet = string.format('inventory.moveItemForce|{"slot": %d, "type": 1, "amount": 1}', slot)
    improve.cef.lastPacketId = 220
    improve.cef.lastPacket = packet
    local sent = Improve.SendCef(packet)
    if sent then
        RuntimeLog.Write('IMPROVE', string.format('Rodina use GPU | slot=%d packet=inventory.moveItemForce', slot))
        improve.cef.inventoryOpen = false
        improve.cef.inventoryFresh = false
    end
    return sent
end

-- ===== Кэш уровней видеокарт =====

-- Запись из кэша для слота, если в нём тот же предмет и запись не протухла
function Improve.CardCacheGet(slot, name)
    local entry = cardLevels.slots[tostring(tonumber(slot) or 0)]
    if type(entry) ~= 'table' then return nil end
    if Improve.GetCardNameNorm(entry.name) ~= Improve.GetCardNameNorm(name) then return nil end

    local hours = tonumber(settings.improve.levelCacheHours) or 0
    if hours > 0 and (os.time() - (tonumber(entry.at) or 0)) > hours * 3600 then
        return nil
    end
    return entry
end

function Improve.CardCacheSet(slot, name, level, cardType)
    slot = tonumber(slot or 0) or 0
    if slot <= 0 then return end
    cardLevels.slots[tostring(slot)] = {
        name = Improve.GetCardNameNorm(name),
        level = math.maxEx(0, math.minEx(10, tonumber(level) or 0)),
        cardType = tonumber(cardType or 0) or 0,
        at = os.time(),
    }
    Storage.RequestSaveCardLevels(false)
end

function Improve.CardCacheForget(slot)
    cardLevels.slots[tostring(tonumber(slot) or 0)] = nil
    Storage.RequestSaveCardLevels(false)
end

-- Очистка кэша: целиком или только по одному типу карт
function Improve.CardCacheClear(cardType)
    cardType = tonumber(cardType or 0) or 0
    if cardType == 0 then
        cardLevels.slots = {}
    else
        for key, entry in pairs(cardLevels.slots) do
            if type(entry) == 'table' and (tonumber(entry.cardType or 0) or 0) == cardType then
                cardLevels.slots[key] = nil
            end
        end
    end
    Storage.RequestSaveCardLevels(true)
end

-- Актуальный уровень пишем и в список CEF, и в кэш на диске
function Improve.UpdateCefCardLevel(slot, level)
    slot = tonumber(slot or 0) or 0
    if slot <= 0 then return end
    for _, c in ipairs(improve.cef.cards or {}) do
        if tonumber(c.slot or 0) == slot then
            if level ~= nil then
                c.level = level
                c.levelKnown = true
                c.probeFailed = false
            end
            Improve.CardCacheSet(c.slot, c.name, c.level, c.cardType)
            return
        end
    end
end

-- Сколько карт выбранного типа с известным/неизвестным уровнем
function Improve.CountKnownLevels()
    local selectedType = tonumber(settings.improve.typeCards or 1) or 1
    local known, unknown = 0, 0
    for _, c in ipairs(improve.cef.cards or {}) do
        if tonumber(c.cardType or 0) == selectedType then
            if c.levelKnown then known = known + 1 else unknown = unknown + 1 end
        end
    end
    return known, unknown
end

function Improve.ResetCefInventory()
    improve.cef.cards = {}
    improve.cef.inventoryFresh = false
    improve.cef.inventoryOpen = false
    improve.cef.inventoryBlockedUntil = 0
    improve.cef.unknownCount = 0
    improve.cef.probing = false
    improve.cef.probeDone = false
    improve.cef.probed = false
    improve.cef.pendingSlot = nil
    improve.cef.pendingIndex = 0
    improve.cef.probeAbort = false
    improve.cef.probeAbortReason = ''
    improve.cef.probeProgress = 0
    improve.cef.probeTotal = 0
    Improve.RebuildRodinaInventoryFromSlots()
end

function Improve.GetCardNameNorm(name)
    local s = tostring(name or '')
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    s = s:gsub('%s+%(%+1%)', '(+1)')
    return s
end

function Improve.ParseCardMetaFromName(name)
    local n = Improve.GetCardNameNorm(name)
    if n == 'Видеокарта' or n == 'Rodina Video Card' then return 1 end
    return nil
end

function Improve.AddCefCardSlot(slot, itemName, cardType)
    slot = tonumber(slot or 0) or 0
    if slot <= 0 then return end

    local parsedType = Improve.ParseCardMetaFromName(itemName)
    local ctype = tonumber(cardType or parsedType or 0) or 0
    if ctype ~= 1 then return end

    local nameNorm = Improve.GetCardNameNorm(itemName)

    for _, c in ipairs(improve.cef.cards) do
        if c.slot == slot then
            -- в слоте сменился предмет - прежний уровень больше не про него
            if Improve.GetCardNameNorm(c.name) ~= nameNorm then
                c.level = 0
                c.levelKnown = false
                c.probeFailed = false
                Improve.CardCacheForget(slot)
            end
            c.name = tostring(itemName or c.name or '')
            c.cardType = ctype
            local _pktLevel = Improve.PacketLevelForSlot(slot, ctype)
            if _pktLevel then
                c.level = _pktLevel
                c.levelKnown = true
                c.levelGuessed = false
                c.probeFailed = false
            end
            return
        end
    end

    -- уровень берём из кэша, если он про этот же предмет и ещё не протух
    -- пакет инвентаря знает уровень точно, кеш - только по памяти прошлых проверок
    local level, known = 0, false
    local pktLevel = Improve.PacketLevelForSlot(slot, ctype)
    local cached = Improve.CardCacheGet(slot, itemName)

    if pktLevel then
        level = pktLevel
        known = true
    elseif cached and (tonumber(cached.cardType or 0) or 0) == ctype then
        level = tonumber(cached.level) or 0
        known = true
    end

    table.insert(improve.cef.cards, {
        slot = slot,
        name = tostring(itemName or ''),
        cardType = ctype,
        level = level,
        levelKnown = known,
        levelGuessed = false,
        probeFailed = false,
    })
end

function Improve.MoveMaxLevelCardsToEnd(cards)
    if type(cards) ~= "table" or #cards <= 1 then return cards end

    local activeCards = {}
    local maxLevelCards = {}

    for _, card in ipairs(cards) do
        if tonumber(card.level or 0) >= 10 then
            table.insert(maxLevelCards, card)
        else
            table.insert(activeCards, card)
        end
    end

    if #maxLevelCards == 0 or #activeCards == 0 then
        return cards
    end

    for _, card in ipairs(maxLevelCards) do
        table.insert(activeCards, card)
    end

    return activeCards
end

function Improve.SyncVideoCardsFromCef()
    local cards = {}
    local selectedType = tonumber(settings.improve.typeCards or 1) or 1

    for _, c in ipairs(improve.cef.cards or {}) do
        -- карты, которые не удалось проверить, в работу не берём:
        -- их реальный уровень неизвестен, попытки улучшения были бы вслепую
        if tonumber(c.cardType or 0) == selectedType and not (c.probeFailed and not c.levelKnown) then
            table.insert(cards, {
                slot = c.slot,
                name = c.name,
                cardType = tonumber(c.cardType or 0) or 0,
                level = tonumber(c.level or 0) or 0,
                levelKnown = c.levelKnown == true,
            })
        end
    end

    if settings.improve.mode == 1 and settings.improve.menuAll then
        table.sort(cards, function(a, b)
            return (a.level or 0) < (b.level or 0)
        end)
    end

    cards = Improve.MoveMaxLevelCardsToEnd(cards)
    improve.videoCards = cards
end
function Improve.ParseCardLevelFromDialog(text)
    local dialogText = tostring(text or '')

    local currentLvl = dialogText:match('Сейчас%s+уровень%s+производительности%s+видеокарты:%s*(%d+)%s*из%s*10')
    if currentLvl then
        return math.maxEx(0, tonumber(currentLvl) or 0)
    end

    for line in dialogText:gmatch('[^\r\n]+') do
        if line:find('Улучшить производительность видео-карты', 1, true) then
            local maxLvl = tonumber(line:match('до%s+(%d+)%s+уровн'))
            if maxLvl then
                return math.maxEx(0, maxLvl - 1)
            end
        end
    end

    return nil
end

-- Проверка уровней видеокарт.
-- Замеряются только карты с неизвестным уровнем, известные берутся из кэша;
-- при обрыве прогресс сохраняется и следующий запуск добирает остаток.
function Improve.RunNewStyleProbeLoop(allowWhenStopped, rescanAll)
    improve.cef.probing = true
    improve.cef.probeDone = false
    improve.cef.probed = false
    improve.cef.probeAbort = false
    improve.cef.probeAbortReason = ''
    improve.cef.inventoryFresh = false

    local selectedType = tonumber(settings.improve.typeCards or 1) or 1

    -- Уровни приходят в пакете инвентаря. Если с запуска скрипта такого пакета
    -- ещё не было, просим инвентарь один раз - это дешевле, чем диалог по каждой карте
    if Improve.UsePacketLevels() then
        if rescanAll then Improve.ForgetPacketLevels() end

        if (improve.cef.pktInvAt or 0) == 0 then
            local _hasUnknown = false
            for _, c in ipairs(improve.cef.cards or {}) do
                if tonumber(c.cardType or 0) == selectedType and (rescanAll or not c.levelKnown) then
                    _hasUnknown = true
                    break
                end
            end

            if _hasUnknown then
                Improve.LogAdd('INFO', 'Оценка карт: запрашиваем инвентарь, уровни должны прийти пакетом.')
                if not Improve.RequestInventoryDump(6) then
                    Improve.LogAdd('WARN', 'Оценка карт: инвентарь пакетом не пришёл, проверяем карты по старинке.')
                end
            end
        end
    end

    local typeCards, probeCards, knownCount = {}, {}, 0
    for _, c in ipairs(improve.cef.cards or {}) do
        if tonumber(c.cardType or 0) == selectedType then
            if rescanAll then
                c.levelKnown = false
                c.probeFailed = false
                c.levelGuessed = false

                local _pktLevel = Improve.PacketLevelForSlot(c.slot, c.cardType)
                if _pktLevel then
                    c.level = _pktLevel
                    c.levelKnown = true
                end
            end
            table.insert(typeCards, c)
            if c.levelKnown then
                knownCount = knownCount + 1
            elseif not c.probeFailed then
                table.insert(probeCards, c)
            end
        end
    end

    improve.cef.probeTotal = #typeCards
    improve.cef.probeProgress = knownCount

    -- нечего проверять
    if #typeCards == 0 then
        improve.cef.probing = false
        improve.cef.probeAbort = true
        improve.cef.probeAbortReason = 'в инвентаре нет карт выбранного типа'
        Improve.SyncVideoCardsFromCef()
        Improve.LogAdd('WARN', 'Новый стиль: в инвентаре нет карт выбранного типа.')
        if improve.isOn and not allowWhenStopped then
            Improve.Stop('Новый стиль: в инвентаре нет карт выбранного типа')
        end
        Improve.FinishProbe()
        return
    end

    -- всё уже известно из кэша
    if #probeCards == 0 then
        improve.cef.probing = false
        improve.cef.probed = true
        improve.cef.unknownCount = 0
        Improve.SyncVideoCardsFromCef()
        Improve.LogAdd('INFO', string.format('Новый стиль: уровни всех %d карт уже известны, проверка не нужна.', #typeCards))
        if allowWhenStopped then
            Improve.Say(string.format('Уровни всех %d карт уже известны.', #typeCards))
        end
        Improve.FinishProbe()
        return
    end

    Improve.LogAdd('INFO', string.format('Новый стиль: проверяю %d карт из %d (остальные уже известны).', #probeCards, #typeCards))
    Improve.ShowMobileStatusDialog(true)

    local timeoutDialog = tonumber(settings.deley.timeoutDialog) or 10
    local maxRetries = math.maxEx(0, tonumber(settings.improve.probeRetries) or 2)
    local fastProbe = settings.improve.fastProbe ~= false
    local fastFails, failStreak, stopped = 0, 0, false

    for idx, card in ipairs(probeCards) do
        if ((not improve.isOn) and (not allowWhenStopped)) or improve.cef.probeAbort then
            stopped = true
            break
        end

        improve.cef.pendingIndex = knownCount + idx
        improve.cef.pendingSlot = card.slot
        Improve.ShowMobileStatusDialog(true)

        local measured = false
        for attempt = 1, maxRetries + 1 do
            if ((not improve.isOn) and (not allowWhenStopped)) or improve.cef.probeAbort then
                stopped = true
                break
            end

            -- первая попытка может обойтись без /invent, если инвентарь уже открыт
            local useFast = fastProbe and improve.cef.inventoryFresh and attempt == 1
            local stepTimeout = useFast and math.minEx(4, timeoutDialog) or timeoutDialog

            improve.cef.probeDone = false
            mobileImproveDialog.scriptBusy = true
            Improve.OpenCardDialog(card.slot, 1, 1, useFast)

            local timeoutAt = os.clock() + stepTimeout
            while (improve.isOn or allowWhenStopped)
                and not improve.cef.probeDone
                and not improve.cef.probeAbort
                and os.clock() < timeoutAt do
                wait(25)
            end
            mobileImproveDialog.scriptBusy = false

            -- HandleProbeServerMessage ставит probeDone вместе с probeAbort,
            -- чтобы разбудить ожидание: это не замер, а аварийный выход
            if improve.cef.probeDone and not improve.cef.probeAbort then
                measured = true
                break
            end
            if improve.cef.probeAbort then
                stopped = true
                break
            end

            improve.cef.inventoryFresh = false
            if useFast then
                fastFails = fastFails + 1
                if fastFails >= 2 then
                    fastProbe = false
                    Improve.LogAdd('INFO', 'Новый стиль: быстрая проверка не срабатывает, переоткрываю инвентарь для каждой карты.')
                end
            elseif attempt <= maxRetries then
                Improve.LogAdd('WARN', string.format('Новый стиль: слот %d не ответил, повтор %d из %d.', card.slot, attempt, maxRetries))
                wait(500)
            end
        end

        if stopped or improve.cef.probeAbort then
            stopped = true
            break
        end

        if measured then
            failStreak = 0
            card.levelKnown = true
            card.probeFailed = false
            improve.cef.inventoryFresh = true
            improve.cef.probeProgress = knownCount + idx
            -- уровень, который не удалось прочитать из диалога, запоминать нельзя
            if not card.levelGuessed then
                Improve.CardCacheSet(card.slot, card.name, card.level, card.cardType)
            end
        else
            -- одна неотвечающая карта не должна рушить весь проход
            failStreak = failStreak + 1
            card.levelKnown = false
            card.probeFailed = true
            Improve.LogAdd('WARN', string.format('Новый стиль: слот %d проверить не удалось, пропускаю.', card.slot))
            if failStreak >= 3 then
                improve.cef.probeAbort = true
                improve.cef.probeAbortReason = 'подряд не открылось окно у 3 карт (стойте у стола, закройте инвентарь, MMT должен быть запущен один раз)'
                break
            end
        end

        Improve.ShowMobileStatusDialog(true)
        wait(settings.deley.improve_waitTryClick or 300)
    end

    local aborted = improve.cef.probeAbort == true
    local abortReason = improve.cef.probeAbortReason or ''

    improve.cef.probing = false
    improve.cef.pendingSlot = nil
    improve.cef.pendingIndex = 0
    improve.cef.probeDone = false
    mobileImproveDialog.scriptBusy = false

    local known, unknown = Improve.CountKnownLevels()
    improve.cef.probeProgress = known
    improve.cef.unknownCount = unknown
    improve.cef.probeTotal = known + unknown

    Improve.SyncVideoCardsFromCef()
    Storage.RequestSaveCardLevels(true)

    if aborted or stopped then
        improve.cef.probed = false
        local reason = (abortReason ~= '') and abortReason or 'остановлено'
        Improve.LogAdd('WARN', string.format('Новый стиль: проверка прервана (%s). Известно уровней %d из %d, при следующем запуске доберу остальные.', reason, known, known + unknown))
        Improve.Say(string.format('Проверка прервана: %s. Известно %d/%d, прогресс сохранён.', reason, known, known + unknown))
        if improve.isOn and not allowWhenStopped then
            Improve.Stop('Новый стиль: ' .. reason)
        end
    else
        improve.cef.probed = true
        if unknown > 0 then
            Improve.LogAdd('WARN', string.format('Новый стиль: проверка завершена, %d карт проверить не удалось - в работу они не пойдут.', unknown))
        else
            Improve.LogAdd('INFO', string.format('Новый стиль: проверка завершена, уровни известны у всех %d карт.', known))
        end
        if allowWhenStopped then
            Improve.Say(string.format('Проверка уровней завершена: известно %d из %d.', known, known + unknown))
        end
    end

    Improve.FinishProbe()
end

function Improve.StartNewStyleProbe(allowWhenStopped, rescanAll)
    if improve.cef.probing then return end

    if #(improve.cef.cards or {}) == 0 then
        Improve.SyncVideoCardsFromCef()
        improve.cef.probed = true
        return
    end

    Improve.RunNewStyleProbeLoop(allowWhenStopped, rescanAll)
end

-- rescanAll = забыть запомненные уровни и промерить всё заново
function Improve.ManualCheckCardLevels(rescanAll)
    if improve.oils.busy then
        Improve.Say('Дождитесь завершения обновления инвентаря.')
        return
    end

    if improve.cef.probing then
        Improve.Say('Проверка уровней уже выполняется.')
        return
    end

    MMTCreateThread(function()
        if rescanAll then
            Improve.CardCacheClear(tonumber(settings.improve.typeCards or 1) or 1)
        end

        Improve.RefreshOils(false)

        if #(improve.cef.cards or {}) == 0 then
            Improve.Say('Видеокарты в инвентаре не найдены.')
            return
        end

        Improve.SyncVideoCardsFromCef()
        improve.cef.probed = false
        Improve.StartNewStyleProbe(true, rescanAll)
    end)
end

function Improve.HandleNewStyleChooseDialog(dialogId, title, text)
    if not Improve.IsNewStyleMode() then return false end
    local dialogTitle = Util.StripColors(tostring(title or ''))
    if not dialogTitle:find('Улучшение видеокарты', 1, true) then return false end
    local dialogText = tostring(text or '')
    local level = Improve.ParseCardLevelFromDialog(dialogText)
    local card = nil
    if improve.cef.probing and improve.cef.pendingSlot then
        for _, c in ipairs(improve.cef.cards or {}) do
            if tonumber(c.slot) == tonumber(improve.cef.pendingSlot) then card = c break end
        end
    elseif improve.isOn then
        local wantedSlot = tonumber(improve.currentSlot or 0) or 0
        if wantedSlot > 0 then
            for i, v in ipairs(improve.videoCards or {}) do
                if tonumber(v.slot or 0) == wantedSlot then
                    card = v
                    improve.currentIndex = i
                    break
                end
            end
        elseif improve.currentIndex and improve.currentIndex > 0 then
            card = improve.videoCards[improve.currentIndex]
        end
    end
    if card and level then
        card.level = level
        card.levelKnown = true
        card.levelGuessed = false
        card.probeFailed = false
        Improve.UpdateCefCardLevel(card.slot, level)
    end
    if improve.cef.probing and improve.cef.pendingSlot then
        if not level then
            Improve.LogAdd('WARN', string.format('Rodina: не удалось распарсить уровень карты slot %s.', tostring(improve.cef.pendingSlot)))
            if card then
                card.level = 10
                card.levelKnown = true
                card.levelGuessed = true
            end
        end
        improve.cef.probeDone = true
        sampSendDialogResponse(dialogId, 0, 0, '')
        return true
    end
    if not (improve.isOn and improve.step == Improve.STEP.CONFIRM) then return false end
    if not card then
        Improve.LogAdd('ERROR', 'Rodina: открыт диалог улучшения, но текущая карта не найдена.')
        sampSendDialogResponse(dialogId, 0, 0, '')
        Improve.Stop('Rodina: потеряна текущая видеокарта')
        return true
    end
    local targetLevel = tonumber(settings.improve.maxLevel) or 2
    if level and level >= targetLevel then
        Improve.LogAdd('INFO', string.format('Rodina: slot %d уже %d LVL, цель %d - пропускаю.', tonumber(card.slot) or 0, level, targetLevel))
        sampSendDialogResponse(dialogId, 0, 0, '')
        MMTCreateThread(function()
            wait(120)
            if improve.isOn then
                improve.step = Improve.STEP.SELECT_CARD
                improve.lastUseAt = 0
                improve.consumedThisTry = false
            end
        end)
        return true
    end
    if not Improve.HasRequiredOils(2) then
        Improve.Say('Недостаточно смазки (нужно 2). Отключаюсь.')
        Improve.LogAdd('WARN', 'Rodina: недостаточно смазки. Сессия остановлена.')
        sampSendDialogResponse(dialogId, 0, 0, '')
        Improve.Stop('Недостаточно смазки Rodina')
        return true
    end
    if not improve.consumedThisTry then
        Improve.ConsumeOils(2)
        improve.consumedThisTry = true
    end
    improve.resultHandled = false
    improve.waitStart = false
    improve.waitStartAt = 0
    improve.waitResultAt = os.clock()
    improve.step = Improve.STEP.WAIT_RESULT
    Improve.AttemptStart()
    sampSendDialogResponse(dialogId, 1, 0, '')
    Improve.LogAdd('INFO', string.format('Rodina: подтверждено улучшение slot %d с %d LVL.', tonumber(card.slot) or 0, tonumber(card.level) or 0))
    return true
end

function Improve.HandleNewStyleConfirmDialog(dialogId, title)
    return false
end

function Improve.TickNewStyle()
    if improve.step ~= Improve.STEP.SELECT_CARD then return end

    if not Improve.HasRequiredOils(2) then
        Improve.Say('Смазка закончилась. Отключаюсь.')
        Improve.LogAdd('WARN', 'Новый стиль: смазка закончилась. Сессия остановлена.')
        Improve.Stop('Закончилась смазка в процессе (новый стиль)')
        return
    end

    if improve.cef.needInventoryRefresh then
        if not improve.oils.busy then
            Improve.RefreshOils(true)
            improve.cef.needInventoryRefresh = false
            improve.cef.waitInventory = true
            Improve.LogAdd('INFO', 'Новый стиль: обновляю инвентарь перед началом заточки.')
        end
        return
    end

    if improve.cef.waitInventory then
        if improve.oils.busy then return end
        improve.cef.waitInventory = false

        Improve.SyncVideoCardsFromCef()
        if #improve.videoCards == 0 then
            Improve.Say('Новый стиль: видеокарты в инвентаре не найдены.')
            Improve.Stop('Новый стиль: не найдены слоты видеокарт')
            return
        end

        improve.cef.probed = false
        Improve.StartNewStyleProbe()
        return
    end

    if improve.cef.probing then return end

    if not improve.cef.probed then
        Improve.StartNewStyleProbe()
        return
    end

    local targetLevel = settings.improve.maxLevel or 2
    local candidate, idxCandidate

    if settings.improve.menuAll then
        for idx, v in ipairs(improve.videoCards) do
            if (v.level or 0) < targetLevel then
                candidate = v
                idxCandidate = idx
                break
            end
        end
    else
        local wantedSlot = tonumber(improve.selectSlot or 0) or 0
        if wantedSlot <= 0 and improve.select > 0 and improve.videoCards[improve.select] then
            wantedSlot = tonumber(improve.videoCards[improve.select].slot or 0) or 0
            improve.selectSlot = wantedSlot
        end
        if wantedSlot <= 0 then
            Improve.Say('Выбери видеокарту внизу списка.')
            Improve.Stop('Новый стиль: не выбрана видеокарта')
            return
        end
        for i, v in ipairs(improve.videoCards or {}) do
            if tonumber(v.slot or 0) == wantedSlot then
                improve.select = i
                if (v.level or 0) < targetLevel then
                    candidate = v
                    idxCandidate = i
                end
                break
            end
        end
    end

    if not candidate then
        local minLevel, maxCurrentLevel = nil, nil
        for _, v in ipairs(improve.videoCards or {}) do
            local lvl = tonumber(v.level)
            if lvl then
                minLevel = (minLevel == nil) and lvl or math.min(minLevel, lvl)
                maxCurrentLevel = (maxCurrentLevel == nil) and lvl or math.max(maxCurrentLevel, lvl)
            end
        end

        local rangeText
        if minLevel ~= nil and maxCurrentLevel ~= nil then
            rangeText = (minLevel == maxCurrentLevel)
                and string.format("%d LVL", minLevel)
                or string.format("%d-%d LVL", minLevel, maxCurrentLevel)
        else
            rangeText = "неизвестный уровень"
        end

        Improve.Say(string.format(
            "Заточка не началась: цель %d LVL, а найденные карты уже %s. Поставьте целевой уровень выше текущего.",
            tonumber(targetLevel) or 0, rangeText
        ))
        Improve.LogAdd('INFO', string.format(
            'Новый стиль: нет карты ниже цели %d LVL; текущий диапазон: %s.',
            tonumber(targetLevel) or 0, rangeText
        ))
        Improve.Stop('Новый стиль: все видеокарты достигли целевого уровня')
        return
    end

    local slot = tonumber(candidate.slot or 0) or 0
    if slot <= 0 then
        Improve.LogAdd('ERROR', 'Новый стиль: у выбранной видеокарты отсутствует slot.')
        Improve.Stop('Новый стиль: некорректный slot у видеокарты')
        return
    end

    improve.currentIndex = idxCandidate
    improve.currentSlot = tonumber(candidate.slot or 0) or 0
    improve.consumedThisTry = false
    Improve.OpenCardDialog(slot, 1, 1)
    improve.lastUseAt = os.clock()
    improve.step = Improve.STEP.CONFIRM
end

-- --------------------------------------------------------
--                           Class
-- --------------------------------------------------------

-- Утилиты для работы с диалогами в Interacting
local DialogUtils = {}

-- Класс для обработки домов
local HouseProcessor = {}

-- Класс для обработки полок
local ShelfProcessor = {}

-- =====================================================================================================================
--                                                          MAIN
-- =====================================================================================================================

imgui.OnInitialize(function()
    if not ISMONETLOADER then
        UI.SetScale()
    end

    UI.SetStyle(ISMONETLOADER)

    if ISMONETLOADER then
        fa.Init(14*MONET_DPI_SCALE)
    else
        fa.Init(14)
    end
end)

-- ALT / mobile-interaction probe.
-- Goal: capture what Neo/Rodina actually sends when the player taps the real
-- mobile interaction button. We only observe; the probe never modifies packets.
local AltProbe = {
    active = false,
    startedAt = 0,
    deadlineAt = 0,
    lastSync = nil,
    packetCounts = {},
    rpcCounts = {},
    phase = "idle",
    phaseCounts = { idle = {}, press = {} },
    lastRaw207Keys = nil,
    decodeUnavailableReported = false,
    logPath = nil,
    -- Captured only in volatile RAM; never written to the log.
    capturedAlt = nil,
    replayUsed = false,
    testPending = nil,
    -- A manual mobile ALT press must be followed by the actual card-list dialog
    -- before its session-specific request ID is approved for automatic reuse.
    liveCandidate = nil,
    confirmedAlt = false,
    autoReplaySending = false,
}

function AltProbe.NowMs()
    if type(getGameTimer) == "function" then
        local ok, value = pcall(getGameTimer)
        if ok and tonumber(value) then return tonumber(value) end
    end
    return math.floor(os.clock() * 1000)
end

function AltProbe.ResolvePath()
    local base = "."
    if type(getWorkingDirectory) == "function" then
        local ok, value = pcall(getWorkingDirectory)
        if ok and type(value) == "string" and value ~= "" then
            base = value
        end
    end
    local sep = tostring(SEPORATORPATCH or "/")
    if base:sub(-1) == "/" or base:sub(-1) == "\\" then
        return base .. "MMT_alt_probe.log"
    end
    return base .. sep .. "MMT_alt_probe.log"
end

function AltProbe.Write(line)
    line = tostring(line or "")
    local prefix = string.format("[%dms] ", math.max(0, AltProbe.NowMs() - (AltProbe.startedAt or 0)))
    local full = prefix .. "[phase=" .. tostring(AltProbe.phase or "-") .. "] " .. line

    print("[MMT-R][ALTPROBE] " .. full)

    local path = AltProbe.logPath or AltProbe.ResolvePath()
    AltProbe.logPath = path
    local f = io.open(path, "a")
    if f then
        f:write(full, "\n")
        f:close()
    end
end

function AltProbe.Start()
    if not ISNEOMLOADER then
        Chat.Add("ALT probe нужен только на NeoMLoader.", TYPECHATMESSAGES.WARNING)
        return
    end

    imguiWindows.main[0] = false

    AltProbe.active = true
    AltProbe.startedAt = AltProbe.NowMs()
    AltProbe.deadlineAt = AltProbe.startedAt + 5000
    AltProbe.phase = "idle"
    AltProbe.lastRaw207Keys = nil
    AltProbe.decodeUnavailableReported = false
    AltProbe.capturedAlt = nil
    AltProbe.confirmedAlt = false
    AltProbe.liveCandidate = nil
    AltProbe.replayUsed = false
    AltProbe.testPending = nil
    AltProbe.phaseCounts = { idle = {}, press = {} }
    AltProbe.lastSync = nil
    AltProbe.packetCounts = {}
    AltProbe.rpcCounts = {}
    AltProbe.logPath = AltProbe.ResolvePath()

    local f = io.open(AltProbe.logPath, "w")
    if f then
        f:write("MMT-R Neo ALT probe\n")
        f:write("Comparison: 5s IDLE (do not touch), followed by 8s PRESS (tap real mobile ALT once).\n")
        f:write("Only safe packet headers and limited sync keys are recorded; no CEF contents or credentials.\n")
        f:close()
    end

    AltProbe.Write("START | Neo=" .. tostring(ISNEOMLOADER))
    AltProbe.Write("BASELINE | 5 seconds NO INPUT")
    Chat.Add("ALT PROBE: 5 секунд НЕ НАЖИМАЙ ничего и стой на месте. Потом будет сигнал нажать ALT.", TYPECHATMESSAGES.WARNING)
end

function AltProbe.Stop(reason)
    if not AltProbe.active then return end
    AltProbe.Write("STOP | reason=" .. tostring(reason or "done"))

    local packetParts = {}
    for id, count in pairs(AltProbe.packetCounts or {}) do
        packetParts[#packetParts + 1] = tostring(id) .. "=" .. tostring(count)
    end
    table.sort(packetParts)

    local rpcParts = {}
    for id, count in pairs(AltProbe.rpcCounts or {}) do
        rpcParts[#rpcParts + 1] = tostring(id) .. "=" .. tostring(count)
    end
    table.sort(rpcParts)

    AltProbe.Write("PACKETS | " .. table.concat(packetParts, ","))
    AltProbe.Write("RPCS | " .. table.concat(rpcParts, ","))

    for _, phase in ipairs({ "idle", "press" }) do
        local parts = {}
        for id, count in pairs(AltProbe.phaseCounts[phase] or {}) do
            parts[#parts + 1] = tostring(id) .. "=" .. tostring(count)
        end
        table.sort(parts)
        AltProbe.Write(string.format("PHASE_COUNTS | %s: %s", phase, table.concat(parts, ",")))
    end

    AltProbe.active = false
    Chat.Add("ALT PROBE завершён. Файл: " .. tostring(AltProbe.logPath), TYPECHATMESSAGES.SECONDARY)
    if AltProbe.capturedAlt ~= nil then
        AltProbe.Write("CAPTURE_READY | valid iface=8/sub=1024/len=0 (request ID retained in memory only)")
        Chat.Add("ALT пойман! Закрой открытый список видеокарт, затем введи /mmtalttest — проверим повторение.", TYPECHATMESSAGES.WARNING)
    else
        AltProbe.Write("CAPTURE_MISSING | expected 220/0x3F/iface8/sub1024/len0 not seen")
        Chat.Add("ALT пакет не удалось поймать. Запусти /mmtaltprobe ещё раз.", TYPECHATMESSAGES.WARNING)
    end
end

function AltProbe.Tick()
    -- Completion of a single controlled replay. This routine only observes
    -- the server reply; it never injects gameplay keys or extra packets.
    if AltProbe.testPending and AltProbe.NowMs() - AltProbe.testPending.startedAt >= 3500 then
        AltProbe.Write("REPLAY_RESULT | TIMEOUT: no matching fresh video-card dialog after 3500ms")
        Chat.Add("ALT TEST: сервер не открыл новый список. Скинь MMT_alt_probe.log.", TYPECHATMESSAGES.WARNING)
        AltProbe.testPending = nil
    end

    if not AltProbe.active then return end
    if AltProbe.NowMs() < (AltProbe.deadlineAt or 0) then return end

    if AltProbe.phase == "idle" then
        AltProbe.Write("END BASELINE | now enter press phase")
        AltProbe.phase = "press"
        AltProbe.deadlineAt = AltProbe.NowMs() + 8000
        AltProbe.lastRaw207Keys = nil
        AltProbe.Write("PRESS PHASE | tap REAL mobile interaction/ALT ONCE during next 8 seconds")
        Chat.Add("ALT PROBE: ТЕПЕРЬ нажми настоящую кнопку ALT/взаимодействия ОДИН раз. Затем не трогай телефон 8 секунд.", TYPECHATMESSAGES.WARNING)
    else
        AltProbe.Stop("comparison complete")
    end
end

function AltProbe.TryReplay()
    if not ISNEOMLOADER then
        Chat.Add("ALT replay доступен только на NeoMLoader.", TYPECHATMESSAGES.WARNING)
        return false
    end
    if AltProbe.active then
        Chat.Add("Дождись окончания /mmtaltprobe перед /mmtalttest.", TYPECHATMESSAGES.WARNING)
        return false
    end
    local captured = AltProbe.capturedAlt
    if type(captured) ~= "table" then
        Chat.Add("Сначала запусти /mmtaltprobe и нажми настоящий ALT.", TYPECHATMESSAGES.WARNING)
        return false
    end
    if AltProbe.replayUsed then
        Chat.Add("Один пробный пакет уже отправлен. Для повторения заново запусти /mmtaltprobe.", TYPECHATMESSAGES.WARNING)
        return false
    end
    if stateCrypto.work or Interacting.IsActive() then
        Chat.Add("Останови сбор/действия MMT перед тестом ALT.", TYPECHATMESSAGES.WARNING)
        return false
    end
    if type(sampIsDialogActive) == "function" then
        local ok, active = pcall(sampIsDialogActive)
        if ok and active then
            Chat.Add("Закрой список видеокарт/другие диалоги перед /mmtalttest.", TYPECHATMESSAGES.WARNING)
            return false
        end
    end

    -- The user must dismiss the real card-list dialog before entering this
    -- command. We do not send any stale dialog-response packets here.
    imguiWindows.main[0] = false
    AltProbe.replayUsed = true
    AltProbe.phase = "test"
    AltProbe.testPending = { startedAt = AltProbe.NowMs() }

    -- Request ID is taken directly from the real mobile ALT packet in this
    -- session; it is not logged or persisted. The exact same envelope is sent.
    local sent = Improve.SendCefMobile(captured.iface, captured.sub, captured.reqid, '')
    AltProbe.Write(string.format(
        "REPLAY_SEND | sent=%s id=220 type=63 iface=%s sub=%s payload_len=0 bits=104 (request ID hidden)",
        tostring(sent), tostring(captured.iface), tostring(captured.sub)
    ))
    if not sent then
        AltProbe.testPending = nil
        Chat.Add("ALT TEST: не удалось отправить тестовый пакет.", TYPECHATMESSAGES.WARNING)
        return false
    end
    Chat.Add("ALT TEST: отправлен один тестовый пакет. Не трогай экран 4 секунды.", TYPECHATMESSAGES.SECONDARY)
    return true
end

function AltProbe.RecordSync(data)
    if not AltProbe.active or type(data) ~= "table" then return end

    local snap = {
        keysData = tonumber(data.keysData),
        leftRightKeys = tonumber(data.leftRightKeys),
        upDownKeys = tonumber(data.upDownKeys),
        specialAction = tonumber(data.specialAction),
        weapon = tonumber(data.weapon),
    }

    local prev = AltProbe.lastSync
    if not prev
        or snap.keysData ~= prev.keysData
        or snap.leftRightKeys ~= prev.leftRightKeys
        or snap.upDownKeys ~= prev.upDownKeys
        or snap.specialAction ~= prev.specialAction
    then
        AltProbe.Write(string.format(
            "PLAYER_SYNC | keysData=%s leftRight=%s upDown=%s special=%s weapon=%s",
            tostring(snap.keysData), tostring(snap.leftRightKeys), tostring(snap.upDownKeys),
            tostring(snap.specialAction), tostring(snap.weapon)
        ))
    end

    AltProbe.lastSync = snap
end

-- Shared MMT command handlers.
local NeoCommandBridge = {
    pending = nil,
}

local function MMTCommandRuntimeLog()
    if not RuntimeLog.enabled then
        Chat.Add("Дебаг выключен. Включите его в /mmt -> Настройки -> Основное.", TYPECHATMESSAGES.SECONDARY)
        return
    end
    RuntimeLog.State("manual_mmtlog_command")
    WorkerPool.State("manual_mmtlog_command")
    Chat.Add("Runtime log: " .. tostring(RuntimeLog.ResolvePath()), TYPECHATMESSAGES.SECONDARY)
end

local function MMTCommandCefDebug()
    if not (settings.main.typeChatMessage and settings.main.typeChatMessage.debug) then
        Chat.Add("CEF-дебаг выключен. Включите дебаг в /mmt -> Настройки -> Основное.", TYPECHATMESSAGES.SECONDARY)
        return
    end

    local seen = tonumber(RodinaCooling.cefPacketsSeen) or 0
    local age = RodinaCooling.lastCefAt > 0 and (os.clock() - RodinaCooling.lastCefAt) or -1
    Chat.Add(string.format(
        "CEF debug: seen=%d, notifications=%d, last=%s, source=%s, hookError=%s",
        seen,
        tonumber(RodinaCooling.notificationPacketsSeen) or 0,
        age >= 0 and string.format("%.1fs ago", age) or "never",
        tostring(RodinaCooling.lastCefSource or "none"),
        RodinaCooling.lastHookError ~= "" and RodinaCooling.lastHookError or "none"
    ), TYPECHATMESSAGES.SECONDARY)

    if RodinaCooling.lastCefPreview ~= "" then
        print("[MMT CEF] " .. RodinaCooling.lastCefPreview)
    end
    if RodinaCooling.lastNotificationPreview ~= "" then
        print("[MMT CEF NOTIFY] " .. RodinaCooling.lastNotificationPreview)
    end
end

local function MMTCommandReload(resetScale)
    if resetScale then
        settings.style.scaleUI = 1.0
        settings.style.sizeWindow = defaultSettings.style.sizeWindow
        Storage.SaveSettings()
    end

    if ISNEOMLOADER then
        -- Do not reload while Neo is still finishing the chat ACTION_UP or while
        -- our ImGui window/action state is active. Close/reset first, give the
        -- immortal workers a short chance to observe work=false, then reload.
        imguiWindows.main[0] = false
        neoInteractionPending = nil
        neoUiTogglePending = nil

        if stateCrypto.work or Interacting.IsActive() then
            Interacting.Deactivate("Neo safe reload")
        end

        improve.isOn = false
        improve.needCheckOils = false
        improve.waitOils = false
        improve.waitStart = false

        print("[MMT-R][NEOCMD] safe reload: state closed, waiting before reload")
        wait(250)
        print("[MMT-R][NEOCMD] safe reload: executing thisScript():reload()")
    end

    thisScript():reload()
end

function UI.RequestNeoCommand(action)
    if not ISNEOMLOADER then return false end

    NeoCommandBridge.pending = {
        action = tostring(action or ""),
        requestedAt = UI.NeoNowMs(),
        chatWasActive = false,
    }

    print("[MMT-R][NEOCMD] queued /" .. tostring(action))
    return true
end

function UI.ProcessPendingNeoCommand()
    local req = NeoCommandBridge.pending
    if not req then return end

    local now = UI.NeoNowMs()
    local chatActive = false
    if type(sampIsChatInputActive) == "function" then
        local ok, active = pcall(sampIsChatInputActive)
        chatActive = ok and active == true
    end

    if chatActive then
        req.chatWasActive = true
        return
    end

    -- Same reason as /mmt: wait until the Android Send-button ACTION_UP and
    -- Neo's chat dispatcher have completely unwound before doing anything.
    local minDelay = req.chatWasActive and 300 or 450
    if (now - (tonumber(req.requestedAt) or now)) < minDelay then return end

    NeoCommandBridge.pending = nil
    print("[MMT-R][NEOCMD] executing /" .. tostring(req.action))

    if req.action == "mmtlog" then
        MMTCommandRuntimeLog()
    elseif req.action == "mmtcef" then
        MMTCommandCefDebug()
    elseif req.action == "mmtr" then
        MMTCommandReload(false)
    elseif req.action == "mmtsr" then
        MMTCommandReload(true)
    elseif req.action == "mmtaltprobe" then
        AltProbe.Start()
    elseif req.action == "mmtalttest" then
        AltProbe.TryReplay()
    end
end

-- NeoMLoader command bridge.
-- Avoids sampRegisterChatCommand("mmt", ...) on Neo 0.1.6 because the native
-- dispatcher crashes before the Lua callback gets control.
local _mmtPrevOnSendCommand = sampev and sampev.onSendCommand or nil
if sampev then
    function sampev.onSendCommand(command)
        local raw = tostring(command or "")
        local normalized = raw:match("^%s*(.-)%s*$") or raw
        normalized = normalized:lower()

        if ISNEOMLOADER then
            if normalized == "/mmt" or normalized == "mmt" then
                print("[MMT-R][NEOCMD] /mmt intercepted via sampev.onSendCommand")
                UI.RequestMainWindowToggle("sampev_onSendCommand")
                return false
            elseif normalized == "/mmtlog" or normalized == "mmtlog" then
                UI.RequestNeoCommand("mmtlog")
                return false
            elseif normalized == "/mmtcef" or normalized == "mmtcef" then
                UI.RequestNeoCommand("mmtcef")
                return false
            elseif normalized == "/mmtr" or normalized == "mmtr" then
                UI.RequestNeoCommand("mmtr")
                return false
            elseif normalized == "/mmtsr" or normalized == "mmtsr" then
                UI.RequestNeoCommand("mmtsr")
                return false
            elseif normalized == "/mmtaltprobe" or normalized == "mmtaltprobe" then
                UI.RequestNeoCommand("mmtaltprobe")
                return false
            elseif normalized == "/mmtalttest" or normalized == "mmtalttest" then
                UI.RequestNeoCommand("mmtalttest")
                return false
            end
        end

        if type(_mmtPrevOnSendCommand) == "function" then
            return _mmtPrevOnSendCommand(command)
        end
    end
end

-- Read-only RakNet headers. Restoring the exact original bitstream read offset is
-- mandatory: Neo/SAMP.Lua may consume the same bitstream after this callback.
-- Never inspect the full CEF payload or capture tokens, inventory, or credentials.
function AltProbe.SafelyInspectPacket(id, bs)
    local getOffset = raknetBitStreamGetReadOffset
    local setOffset = raknetBitStreamSetReadOffset
    local getSize = raknetBitStreamGetNumberOfBitsUsed
    if type(getOffset) ~= "function" or type(setOffset) ~= "function"
        or type(getSize) ~= "function" then
        if not AltProbe.decodeUnavailableReported then
            AltProbe.decodeUnavailableReported = true
            AltProbe.Write("PACKET_DECODE_UNAVAILABLE | required bitstream offset API missing")
        end
        return
    end

    local offsetOk, savedOffset = pcall(getOffset, bs)
    if not offsetOk or type(savedOffset) ~= "number" then
        if not AltProbe.decodeUnavailableReported then
            AltProbe.decodeUnavailableReported = true
            AltProbe.Write("PACKET_DECODE_UNAVAILABLE | read offset inaccessible")
        end
        return
    end

    local ok, msg = pcall(function()
        local bits = tonumber(getSize(bs)) or 0
        if id == 207 and bits >= 56 then
            -- Standard SA:MP on-foot: ID(8), LR(16), UD(16), keys(16).
            setOffset(bs, 8)
            local lr = raknetBitStreamReadInt16(bs)
            local ud = raknetBitStreamReadInt16(bs)
            local keys = raknetBitStreamReadInt16(bs)
            if type(keys) ~= "number" then return nil end
            if keys < 0 then keys = keys + 65536 end
            local prev = AltProbe.lastRaw207Keys
            AltProbe.lastRaw207Keys = keys
            if keys ~= prev then
                return string.format("RAW_207_KEYS | keys=%d lr=%s ud=%s bits=%d",
                    keys, tostring(lr), tostring(ud), bits)
            end
            return nil
        end

        if id == 220 and bits >= 16 then
            setOffset(bs, 8)
            local typ = raknetBitStreamReadInt8(bs)
            if typ < 0 then typ = typ + 256 end
            if typ == 63 and bits >= 104 then
                local iface = raknetBitStreamReadInt8(bs)
                local reqid = raknetBitStreamReadInt32(bs)
                local sub = raknetBitStreamReadInt32(bs)
                local length = raknetBitStreamReadInt16(bs)
                -- Capture only the exact no-payload mobile ALT event, only
                -- during the human press phase. Request ID is kept in RAM.
                if AltProbe.phase == "press" and AltProbe.capturedAlt == nil
                    and tonumber(iface) == 8 and tonumber(sub) == 1024
                    and tonumber(length) == 0 and bits == 104
                    and type(reqid) == "number" then
                    AltProbe.capturedAlt = { iface = 8, sub = 1024, reqid = reqid }
                end
                -- Never log reqid: it can contain session-specific identifiers.
                return string.format("CEF_220 | type=63 iface=%s sub=%s payload_len=%s bits=%d",
                    tostring(iface), tostring(sub), tostring(length), bits)
            elseif typ == 18 and bits >= 32 then
                local len = raknetBitStreamReadInt16(bs)
                -- Safely log only envelope size, not the event payload (may contain secrets).
                return string.format("CEF_220 | type=18 payload_len=%s bits=%d", tostring(len), bits)
            else
                return string.format("CEF_220 | type=%s bits=%d", tostring(typ), bits)
            end
        end
        return nil
    end)
    -- Even if decoding fails, always restore the original pointer.
    local restored = pcall(setOffset, bs, savedOffset)
    if not restored then
        AltProbe.Write("WARN | could not restore outgoing bitstream read pointer")
    end
    if ok and type(msg) == "string" then
        AltProbe.Write(msg)
    elseif not ok then
        AltProbe.Write("HEADER_DECODE_ERROR | packet=" .. tostring(id) .. " (payload omitted)")
    end
end

-- Capture the real, outgoing ALT envelope during normal play, including when
-- the user opens the rig the first time (without running /mmtaltprobe).
-- No incoming inventory/account/CEF payload is logged or stored; only 13 bytes
-- of the known ALT header are read and the request ID remains RAM-only.
function AltProbe.ObserveLiveAltPacket(bs)
    if not ISNEOMLOADER or AltProbe.active or AltProbe.autoReplaySending
        or AltProbe.testPending then
        return
    end

    local getOffset, setOffset = raknetBitStreamGetReadOffset, raknetBitStreamSetReadOffset
    if type(getOffset) ~= "function" or type(setOffset) ~= "function"
        or type(raknetBitStreamGetNumberOfBitsUsed) ~= "function" then return end

    local savedOk, saved = pcall(getOffset, bs)
    if not savedOk or type(saved) ~= "number" then return end

    local ok, header = pcall(function()
        if tonumber(raknetBitStreamGetNumberOfBitsUsed(bs)) ~= 104 then return nil end
        setOffset(bs, 8)
        local typ = raknetBitStreamReadInt8(bs)
        if typ ~= 63 then return nil end
        local iface = raknetBitStreamReadInt8(bs)
        local reqid = raknetBitStreamReadInt32(bs)
        local sub = raknetBitStreamReadInt32(bs)
        local length = raknetBitStreamReadInt16(bs)
        if iface == 8 and sub == 1024 and length == 0
            and type(reqid) == "number" then
            return { iface = iface, sub = sub, reqid = reqid,
                     at = AltProbe.NowMs() }
        end
        return nil
    end)
    pcall(setOffset, bs, saved)
    if ok and header then
        -- This is just a candidate until a matching *server* dialog arrives.
        AltProbe.liveCandidate = header
    end
end

function AltProbe.ConfirmRealAltByDialog(title)
    if not ISNEOMLOADER then return end
    local plain = Util.StripColors(tostring(title or ""))
    if not plain:find("Выберите видеокарту", 1, true) then return end

    if AltProbe.active and type(AltProbe.capturedAlt) == "table" then
        AltProbe.confirmedAlt = true
    end

    local candidate = AltProbe.liveCandidate
    AltProbe.liveCandidate = nil
    if not candidate then return end
    local age = AltProbe.NowMs() - (tonumber(candidate.at) or 0)
    if age < 0 or age > 2500 then return end

    AltProbe.capturedAlt = {
        iface = 8, sub = 1024, reqid = candidate.reqid
    }
    AltProbe.confirmedAlt = true
    print(string.format(
        "[MMT-R][NEOALT] real ALT confirmed by card list | delay=%dms | auto reuse ready",
        age
    ))
end

addEventHandler("onSendPacket", function(id, bs, priority, reliability, orderingChannel)
    if id == 220 then
        AltProbe.ObserveLiveAltPacket(bs)
    end
    if AltProbe.active then
        local n = (AltProbe.packetCounts[id] or 0) + 1
        AltProbe.packetCounts[id] = n
        local phaseCounts = AltProbe.phaseCounts[AltProbe.phase] or {}
        AltProbe.phaseCounts[AltProbe.phase] = phaseCounts
        phaseCounts[id] = (phaseCounts[id] or 0) + 1
        if n == 1 then
            AltProbe.Write("RAW_PACKET_FIRST | id=" .. tostring(id))
        end
        if id == 207 or id == 220 then
            AltProbe.SafelyInspectPacket(id, bs)
        end
    end
end)

addEventHandler("onSendRpc", function(id, bs, priority, reliability, orderingChannel, shiftTs)
    if AltProbe.active then
        local n = (AltProbe.rpcCounts[id] or 0) + 1
        AltProbe.rpcCounts[id] = n
        if n == 1 then
            AltProbe.Write("RAW_RPC_FIRST | id=" .. tostring(id))
        end
    end
end)

function main()
    while not isSampAvailable() do wait(0) end

    RuntimeLog.StartSession()
    RuntimeLog.Write("MAIN", "SAMP available; starting Rodina MMT")
    WorkerPool.Start()
    WorkerPool.State("main_start")
    RuntimeLog.State("main_start")


    -- цвет префикса в чате и смысловые цвета берём из настроек до первого сообщения
    UI.RefreshSemanticColors()
    settings.improve.typeCards = 1
    settings.improve.inventoryMode = 2
    settings.improve.packetLevels = true

    -- два экземпляра MMT шлют /invent одновременно: инвентарь открывается
    -- и тут же закрывается, проверка уровней видеокарт не срабатывает
    local okList, scriptList = pcall(script.list)
    if okList and type(scriptList) == 'table' then
        local me = thisScript()
        for _, s in ipairs(scriptList) do
            if s.id ~= me.id and s.name == me.name then
                Chat.Add(string.format('MMT запущен дважды (%s). Оставьте один файл, иначе проверка уровней видеокарт не сработает.', tostring(s.filename)), TYPECHATMESSAGES.WARNING)
            end
        end
    end

    -- NeoMLoader 0.1.6 can crash in its native sampRegisterChatCommand
    -- dispatcher before a Lua callback starts. Route ALL MMT commands through
    -- sampev.onSendCommand on Neo; keep native commands on PC/Monet.
    if ISNEOMLOADER then
        print("[MMT-R][NEOCMD] native MMT command registration skipped; using onSendCommand bridge")
    else
        sampRegisterChatCommand("mmt", function ()
            UI.SwitchMainWindow()
        end)
        sampRegisterChatCommand("mmtlog", MMTCommandRuntimeLog)
        sampRegisterChatCommand("mmtcef", MMTCommandCefDebug)
        sampRegisterChatCommand("mmtr", function ()
            MMTCommandReload(false)
        end)
        sampRegisterChatCommand("mmtsr", function ()
            MMTCommandReload(true)
        end)
    end
    -- Постоянный фоновый поток: один native-thread на всю сессию.
    MMTCreateDedicatedThread(function()
        while true do
            wait(10)

            -- Neo: finish /mmt opening only after the mobile chat input and
            -- the touch that submitted the command are fully gone.
            if ISNEOMLOADER and type(UI.ProcessPendingMainWindowToggle) == 'function' then
                UI.ProcessPendingMainWindowToggle()
            end
            if ISNEOMLOADER and type(UI.ProcessPendingInteraction) == 'function' then
                UI.ProcessPendingInteraction()
            end
            if ISNEOMLOADER and type(UI.ProcessPendingNeoCommand) == 'function' then
                UI.ProcessPendingNeoCommand()
            end
            if ISNEOMLOADER and type(AltProbe.Tick) == 'function' then
                AltProbe.Tick()
            end

            if notifySuccess and type(notify) == 'table' and type(notify.process_actions) == 'function' then
                -- ошибка внутри библиотеки не должна убивать весь фоновый поток
                local okActions, errActions = pcall(notify.process_actions)
                if not okActions then
                    print("[MMT] notify.process_actions: " .. tostring(errActions))
                end
            end

            -- автообновление инвентаря при старте заточки (если включено)
            if improve.isOn and improve.needCheckOils then
                improve.needCheckOils = false

                if settings.improve.checkOilsOnStart or Improve.IsNewStyleMode() then
                    Improve.RefreshOils(true)  -- асинхронно через CEF-инвентарь
                    improve.waitOils = true
                    if settings.improve.checkOilsOnStart then
                        Improve.Say("Проверяю наличие смазки.")
                    else
                        Improve.Say("Новый стиль: обновляю инвентарь перед стартом.")
                    end
                else
                    -- проверка отключена - сразу переходим к выбору карты
                    improve.step = Improve.STEP.SELECT_CARD
                end
            end

            -- ждём завершения обновления CEF-инвентаря и принимаем решение
            if improve.isOn and improve.waitOils and not improve.oils.busy then
                improve.waitOils = false
                local count, name = Improve.GetOilCountByType()
                if settings.improve.checkOilsOnStart and improve.oils.known and count < 2 then
                    Improve.Say(("Смазки нет (%s). Нужно минимум 2 - остановлено."):format(name))
                    Improve.LogAdd("WARN", string.format(
                        "Проверка CEF-инвентаря: смазки недостаточно (%s). Сессия не запущена.",
                        name
                    ))
                    Improve.Stop("Недостаточно смазки при старте")
                else
                    if settings.improve.checkOilsOnStart and not improve.oils.known then
                        Improve.LogAdd("WARN", "CEF-инвентарь нашёл смазку item 3204, но packet не дал amount; не считаю это нулём, продолжу до первой серверной дельты.")
                    else
                        Improve.LogAdd("INFO", string.format(
                            "Проверка CEF-инвентаря завершена (%s: %d шт.).",
                            name, count
                        ))
                    end
                    improve.step = Improve.STEP.SELECT_CARD
                end
            end


            Improve.Tick()
            Improve.ProbeWatchdogTick()
            Improve.MobileStatusTick()
            Collect.ReminderTick()
            Collect.TgTick()
        end
    end)

    Chat.Add('Скрипт загружен. Команда активации: {'..settings.style.colorChat..'}/mmt{FFFFFF}.')

    -- предупреждения о повреждённых файлах, найденных при загрузке
    Storage.FlushBrokenFilesNotice()

    -- На Neo действия идут через уже созданный WorkerPool: не создаём лишний
    -- LuaThreadInterface вообще. На PC/Monet оставляем исходный suspended-thread.
    if not ISNEOMLOADER then
        processInteractingThread = lua_thread.create_suspended(Interacting.Process)
    end
end

-- =====================================================================================================================
--                                                          SAMP EVENTS
-- =====================================================================================================================

-- --------------------------------------------------------
--                           onServerMessage
-- --------------------------------------------------------

local function HandleStateCryptoServerMessage(color, text)
    if not stateCrypto.work then
        return nil
    end

    if text:find("Вы залили") and text:find("охлаждающей жидкости в видеокарту") and color == 1941201407 then
        local nowFillLiquid = text:match("восстановлено до ([%d%.]+)%%")

        if nowFillLiquid then
            stateCrypto.queueShelves[stateCrypto.progressShelves].fill = tonumber(nowFillLiquid)
            stateCrypto.waitFill = false
            stateCrypto.fillLiquidType = nil
            stateCrypto.fillLiquidLabel = nil
            stateCrypto.fillLiquidBefore = 0
            stateCrypto.fillLiquidAfter = 0
        end
    end

    if text:find("Чтобы запустить видеокарту в работу, необходимо вывести всю прибыль этой видеокарты") and color == -1104335361 then
        Interacting.Deactivate("сначала нужно вывести прибыль видеокарты")
    end


    if text:find("В этом доме нет подвала с вентиляцией или он еще не достроен") and color == -1104335361 then
        Interacting.Deactivate("в доме нет подвала с вентиляцией")
        Chat.Add("Вы можете добавить данный дом в чёрный список, чтобы его скрыть", TYPECHATMESSAGES.SECONDARY)
    end

    if text:find("У Вас недостаточно денежных средств!") and color == -1104335361 then
        Interacting.Deactivate("недостаточно денег")
    end

    -- Rodina: подтверждение сбора обычно приходит CEF-уведомлением. Эта строка чата
    -- служит резервным подтверждением, если CEF по какой-либо причине пришёл позже или потерялся.
    if processes.take then
        local cleanRodinaTake = text:gsub("{%x%x%x%x%x%x}", "")
        local rodinaAdded = cleanRodinaTake:match('Добавлено в инвентарь: предмет "Bitcoin %(BTC%)" %((%d+) шт%)')
        if rodinaAdded and type(RodinaCollect.OnSuccess) == "function" then
            RodinaCollect.OnSuccess(tonumber(rodinaAdded), nil, "chat")
            if settings.main.hideMessagesCollect then
                return false
            end
        end
    end

    -- Фактический вывод прибыли: сервер присылает точную сумму, которую реально выдал.
    -- "Вы вывели {ffffff}9 BTC{ffff00}, осталось на счету видеокарты: {ffffff}0.043804 BTC{ffff00}."
    if processes.take and text:find("осталось на счету видеокарты:") then
        local clean = text:gsub("{%x%x%x%x%x%x}", "")
        local rawAmount, currency = clean:match("Вы вывели%s*([%d%.]+)%s*(%u+)")
        local amount = tonumber(rawAmount) or 0

        if amount > 0 and currency == "BTC" then
            local hid = stateCrypto.currentHouseId or 0
            local queueShelf = stateCrypto.queueShelves[stateCrypto.progressShelves]

            collectStats.total.BTC = (collectStats.total.BTC or 0) + amount
            collectStats.house[hid] = collectStats.house[hid] or { BTC = 0 }
            collectStats.house[hid].BTC = (collectStats.house[hid].BTC or 0) + amount

            Collect.AddLogEntry(hid, "BTC", amount)
            Collect.SummaryTake(queueShelf, "BTC", amount)

            Chat.Add(string.format("Сбор DEBUG: сервер выдал %s BTC (дом %s)",
                tostring(amount), tostring(hid)), TYPECHATMESSAGES.DEBUG)
        end
    end

    if processes.take and (
            text:find("осталось на счету видеокарты:") or (
                text:find("Вам был добавлен предмет") and (
                    text:find("Bitcoin (BTC)", nil, true)
                )
            )
        ) and color == -65281 and settings.main.hideMessagesCollect then
        return false
    end

    if processes.take and settings.main.hideMessagesCollect
        and text:find("инвентарь добавлен предмет", 1, true)
        and (
            text:find("Bitcoin (BTC)", 1, true)
        )
    then
        return false
    end

    return nil
end


function Improve.HandleUseRetryServerMessage(text)
    if not (improve.isOn and improve.step == Improve.STEP.CONFIRM) then
        return
    end

    if text:find('Подождите немного') then
        Improve.LogAdd("WARN", "Сервер ответил \"Подождите немного.\" - повторяем CEF-клик по текущему слоту.")
        MMTCreateThread(function ()
            wait(1000)
            if improve.isOn and improve.step == Improve.STEP.CONFIRM then
                local slot = tonumber(improve.currentSlot or 0) or 0
                if slot <= 0 then
                    local idx = tonumber(improve.currentIndex or 0) or 0
                    local card = improve.videoCards[idx]
                    slot = card and tonumber(card.slot or 0) or 0
                end
                if slot > 0 then
                    Improve.OpenCardDialog(slot, 1, 1)
                    improve.lastUseAt = os.clock()
                end
            end
        end)
    end
end


function Improve.HandleResultServerMessage(text)
    if not (improve.isOn and improve.step == Improve.STEP.WAIT_RESULT) then return end
    if improve.resultHandled then return end
    local isFail = text:find('При улучшении выбранной видеокарты вы допустили техническую ошибку', 1, true)
    local isSuccess = text:find('Вы успешно улучшили выбранную', 1, true)
    if isFail or isSuccess then
        Improve.HandleUpgradeResult(isSuccess ~= nil and isSuccess ~= false, text, nil, 'chat')
    end
end

function Improve.HandleProbeServerMessage(text)
    -- "Нельзя так быстро открывать инвентарь, подождите еще 1 сек." - команда не сработала
    local blockSeconds = text:match('Нельзя так быстро открывать инвентарь, подождите еще (%d+)')
    if blockSeconds then
        improve.cef.inventoryOpen = false
        improve.cef.inventoryFresh = false
        improve.cef.inventoryBlockedUntil = os.clock() + (tonumber(blockSeconds) or 1) + 0.5
    end

    if improve.cef.probing and text:find('Чтобы установить видеокарту, вы должны находиться в подвале возле одной из специальных стоек') then
        improve.cef.probeAbort = true
        improve.cef.probeAbortReason = 'нужно находиться в подвале возле стойки'
        improve.cef.probeDone = true
    end
end

function Improve.HandleInvalidPlaceServerMessage(text)
    if improve.isOn and text:find('Чтобы установить видеокарту, вы должны находиться в подвале возле одной из специальных стоек') then
        Improve.Say("Недопустимое место заточки!")
        Improve.LogAdd("ERROR", "Получено сообщение о неверном месте заточки. Сессия остановлена.")
        Improve.Stop("Неподходящее место заточки")
    end
end

local _mmtPrevOnSendPlayerSync = sampev.onSendPlayerSync
function sampev.onSendPlayerSync(data)
    AltProbe.RecordSync(data)
    if type(_mmtPrevOnSendPlayerSync) == "function" then
        return _mmtPrevOnSendPlayerSync(data)
    end
end

local _mmtPrevOnSendClickTextDraw = sampev.onSendClickTextDraw
function sampev.onSendClickTextDraw(textdrawId)
    if AltProbe.active then
        AltProbe.Write("CLICK_TEXTDRAW | id=" .. tostring(textdrawId))
    end
    if type(_mmtPrevOnSendClickTextDraw) == "function" then
        return _mmtPrevOnSendClickTextDraw(textdrawId)
    end
end

function sampev.onServerMessage(color, text)

    local handled = HandleStateCryptoServerMessage(color, text)
    if handled ~= nil then
        return handled
    end

    Improve.HandleUseRetryServerMessage(text)
    Improve.HandleResultServerMessage(text)
    Improve.HandleProbeServerMessage(text)
    Improve.HandleInvalidPlaceServerMessage(text)
end


-- --------------------------------------------------------
--                           onShowDialog
-- --------------------------------------------------------

local function DialogReturnVisibility()
    return not settings.main.replaceDialog
end

local function HandleTakeProfitDialog(dialogId, title, text)
    if not (stateCrypto.work and processes.take and title:find("Вывод прибыли видеокарты")) then
        return nil
    end

    local cleanTakeDialog = (text or ""):gsub("{%x%x%x%x%x%x}", "")
    local available = tonumber(cleanTakeDialog:match("Вам доступно для вывода:%s*(%d+)%s*BTC"))
        or tonumber(stateCrypto.takeCount)
        or 0
    RodinaCollect.Begin(available, dialogId)

    -- Rodina: result is confirmed via CEF/chat. Windows must close the LOCAL
    -- confirmation dialog, not only transmit a response RPC. The Neo/Monet
    -- execution path is intentionally bit-for-bit equivalent to Build 29.
    if IS_WINDOWS_MOONLOADER then
        MMTCreateThread(function()
            wait(0)
            if stateCrypto.work and processes.take and RodinaCollect.pending
                and tonumber(RodinaCollect.confirmDialogId) == tonumber(dialogId) then
                RodinaCollect.PCSendKnownDialog(dialogId, 1, "submit_confirmation")
            end
        end)
    else
        DialogUtils.waitAndSendDialogResponse(dialogId, 1, 0, "")
    end

    stateCrypto.takeCount = 0
    stateCrypto.takeCurrency = nil
    stateCrypto.fillLiquidType = nil
    stateCrypto.fillLiquidLabel = nil
    stateCrypto.fillLiquidBefore = 0
    stateCrypto.fillLiquidAfter = 0
    return DialogReturnVisibility()
end

local function HandleShelfDialog(dialogId, title, text)
    if not (stateCrypto.work and title:find("Стойка") and title:find("Полка")) then
        return nil
    end

    -- Rodina race guard:
    -- after a successful cooling fill the server immediately sends this same
    -- shelf dialog again. The queued shelf still contains the OLD cooling value,
    -- so processing "fill" here would instantly spend another liquid.
    -- While refreshPending=true this dialog is ONLY a bridge back to the fresh list.
    if processes.fill
        and RodinaCooling.refreshPending
    then
        RuntimeLog.Write("COOLING", string.format(
            "refresh guard | shelf dialog id=%s -> Button2/Back; do NOT refill | wantedShelf=%s wantedLine=%s progress=%s",
            tostring(dialogId),
            tostring(RodinaCooling.refreshShelfNumber),
            tostring(RodinaCooling.refreshSampLine),
            tostring(stateCrypto.progressShelves)
        ))
        RodinaCooling.guardBackSent = true
        pcall(sampSendDialogResponse, dialogId, 0, 0, "")
        return DialogReturnVisibility()
    end

    -- PC only: on Rodina, the server may send shelf details again after BTC withdrawal.
    -- The stock client dialog can be hidden by MMT's own ImGui window, so
    -- sampIsDialogActive() is not a reliable indication of server dialog state.
    -- IMPORTANT: Neo/Monet routing remains completely unchanged.
    if IS_WINDOWS_MOONLOADER and processes.take and RodinaCollect.refreshPending then
        local queueIndex = tonumber(RodinaCollect.pendingQueueIndex) or tonumber(stateCrypto.progressShelves) or 0
        local activeShelf = stateCrypto.queueShelves[queueIndex]
        local fromTitle = tonumber(Util.StripColors(title):match("Полка%s*[^%d]*(%d+)"))
        local expectedShelf = activeShelf and tonumber(activeShelf.shelf_number)
        if expectedShelf and fromTitle == expectedShelf
            and (RodinaCollect.pcBackCount or 0) < 2 then
            RodinaCollect.pcBackCount = (RodinaCollect.pcBackCount or 0) + 1
            RuntimeLog.Write("COLLECT_PC", string.format(
                "received confirmed shelf details -> Back | dialog=%s shelf=%s count=%d",
                tostring(dialogId), tostring(fromTitle), RodinaCollect.pcBackCount))
            MMTCreateThread(function()
                wait(0)
                if IS_WINDOWS_MOONLOADER and RodinaCollect.refreshPending
                    and tonumber(lastIDDialog) == tonumber(dialogId)
                    and stateCrypto.lastDialogKind == "shelf" then
                    RodinaCollect.PCSendKnownDialog(dialogId, 0, "shelf_to_list")
                end
            end)
        else
            RuntimeLog.Write("COLLECT_PC", string.format(
                "shelf reply guarded | dialog=%s from=%s expected=%s sent=%s",
                tostring(dialogId), tostring(fromTitle), tostring(expectedShelf),
                tostring(RodinaCollect.pcBackCount or 0)))
        end
        return DialogReturnVisibility()
    end
    if IS_WINDOWS_MOONLOADER and processes.take and RodinaCollect.pending then
        -- A duplicate shelf dialog while waiting for BTC confirmation must NOT
        -- trigger the same withdrawal a second time.
        RuntimeLog.Write("COLLECT_PC", "shelf dialog while withdrawal pending: ignore duplicate")
        return DialogReturnVisibility()
    end

    local actions = Parser.ShelfVideoCardData(text)
    local queueShelf = stateCrypto.queueShelves[stateCrypto.progressShelves]
    local onAction = nil
    local hasCollectableTakeAction = false
    local actionDebug = {}

    for _, value in ipairs(actions) do
        table.insert(actionDebug, string.format("%s(count=%s,line=%s)",
            tostring(value.action), tostring(value.count or 0), tostring(value.samp_line or "?")))
    end
    Chat.Add(string.format("Сбор DEBUG: диалог %s, take=%s, действий=[%s]",
        tostring(dialogId), tostring(processes.take), table.concat(actionDebug, ", ")), TYPECHATMESSAGES.DEBUG)

    local hasBtcTake, isVideoCard = false, false
    for _, value in ipairs(actions) do
        if value.action == "take_btc" then hasBtcTake = true end
        if value.action == "take_video_card" then isVideoCard = true end
    end
    Chat.Add(string.format("Сбор DEBUG: BTC=%s, video=%s",
        tostring(hasBtcTake), tostring(isVideoCard)), TYPECHATMESSAGES.DEBUG)

    for _, value in ipairs(actions) do
        if value.action == "on" and not onAction then
            onAction = value
            RodinaCooling.pendingOnLine = value.samp_line
        end

        if processes.take then
            if value.count > 0 and value.action == "take_btc" then
                hasCollectableTakeAction = true
                stateCrypto.takeCount = value.count
                stateCrypto.takeCurrency = "BTC"
                Chat.Add(string.format("Сбор DEBUG: отправляю действие %s, сумма=%s, строка=%s",
                    tostring(value.action), tostring(value.count), tostring(value.samp_line)), TYPECHATMESSAGES.DEBUG)
                if value.action == "take_btc" then
                    RodinaCollect.sourceShelfDialogId = dialogId
                end
                DialogUtils.waitAndSendDialogResponse(dialogId, 1, value.samp_line, "")
                return DialogReturnVisibility()
            end
        end

        if processes.fill and value.action == "fill" then
            if queueShelf and (queueShelf.fill or 0) > settings.main.fillFrom then
                if settings.main.autoEnableCards and not queueShelf.work and (queueShelf.fill or 0) > 0 and onAction then
                    queueShelf.work = true
                    DialogUtils.waitAndSendDialogResponse(dialogId, 1, onAction.samp_line, "")
                    return DialogReturnVisibility()
                end

                stateCrypto.progressShelves = stateCrypto.progressShelves + 1
                DialogUtils.waitAndSendDialogResponse(dialogId, 0, 0, "")
                return DialogReturnVisibility()
            end
            RodinaCooling.pendingDialogId = dialogId
            RodinaCooling.pendingFillLine = value.samp_line
            RodinaCooling.pendingOnLine = onAction and onAction.samp_line or RodinaCooling.pendingOnLine

            if stateCrypto.waitFill then
                return DialogReturnVisibility()
            end

            if not RodinaCooling.BeginFill(dialogId, value.samp_line, onAction and onAction.samp_line or nil) then
                return DialogReturnVisibility()
            end

            DialogUtils.waitAndSendDialogResponse(dialogId, 1, value.samp_line, "")
            return DialogReturnVisibility()
        end

        if processes.on and value.action == "on" then
            DialogUtils.waitAndSendDialogResponse(dialogId, 1, value.samp_line, "")
            return DialogReturnVisibility()
        elseif processes.on and value.action == "off" then
            if queueShelf then
                queueShelf.work = true
            end
            stateCrypto.progressShelves = stateCrypto.progressShelves + 1
            DialogUtils.waitAndSendDialogResponse(dialogId, 0, 0, "")
            return DialogReturnVisibility()
        end

        if processes.off and value.action == "off" then
            DialogUtils.waitAndSendDialogResponse(dialogId, 1, value.samp_line, "")
            return DialogReturnVisibility()
        elseif processes.off and value.action == "on" then
            if queueShelf then
                queueShelf.work = false
            end
            stateCrypto.progressShelves = stateCrypto.progressShelves + 1
            DialogUtils.waitAndSendDialogResponse(dialogId, 0, 0, "")
            return DialogReturnVisibility()
        end
    end

    if processes.take and queueShelf and not hasCollectableTakeAction then
        Chat.Add("Сбор DEBUG: подходящее действие забора не найдено, закрываю диалог", TYPECHATMESSAGES.DEBUG)
        if settings.main.autoEnableCards and not queueShelf.work and (queueShelf.fill or 0) > 0 and onAction then
            queueShelf.work = true
            Collect.SummaryCardEnabled()
            DialogUtils.waitAndSendDialogResponse(dialogId, 1, onAction.samp_line, "")
            return DialogReturnVisibility()
        end

        stateCrypto.progressShelves = stateCrypto.progressShelves + 1
        DialogUtils.waitAndSendDialogResponse(dialogId, 0, 0, "")
        return DialogReturnVisibility()
    end

    return DialogReturnVisibility()
end


local function HandleVideoCardSelectionDialog(dialogId, title, text)
    if not title:find("Выберите видеокарту") then
        return nil
    end

    if title:find("дом") then
        stateCrypto.activeHouseID = title:match("дом №(%d+)") or "-1"
    end
    idDialogs.selectVideoCard = dialogId
    -- номер дома в заголовке есть не всегда: в подвале его нет
    stateCrypto.shelfListHouse = title:match("дом №(%d+)")
    if RodinaHouseBind.currentHouseId then
        stateCrypto.shelfListHouse = RodinaHouseBind.currentHouseId
        if stateCrypto.work then
            stateCrypto.currentHouseId = RodinaHouseBind.currentHouseId
        end
    end
    -- запоминаем, каким по счёту диалогом пришёл список: по этому номеру
    -- процесс сбора понимает, что вернулся к списку, а не завис на карточке
    stateCrypto.shelfListSerial = stateCrypto.dialogSerial or 0

    -- Rodina: список видеокарт открывает основное окно MMT.
    imguiWindows.main[0] = true
    RuntimeLog.Write("UI", string.format(
        "video card list -> main window opened | dialog=%s replaceDialog=%s",
        tostring(dialogId), tostring(settings.main.replaceDialog)
    ))

    houses = {}
    shelves = Parser.ShelfData(text)

    RuntimeLog.Write("SHELVES", string.format(
        "parsed list | dialog=%s house=%s count=%d",
        tostring(dialogId), tostring(stateCrypto.shelfListHouse), #shelves
    ))
    for i, s in ipairs(shelves) do
        RuntimeLog.Write("SHELF", string.format(
            "i=%d shelf=%s samp_line=%s status=%s profit=%s level=%s cooling=%s card=%s",
            i, tostring(s.shelf_number), tostring(s.samp_line), tostring(s.status),
            tostring(s.profit), tostring(s.level), tostring(s.percentage), tostring(s.card_type)
        ))
    end

    -- Rodina: после каждой успешной заливки возвращаемся сюда через Button2 "Назад".
    -- Этот список является источником истины для нового процента охлаждения.
    if RodinaCooling.refreshPending
        and stateCrypto.work and processes.fill then
        if RodinaCooling.HandleRefreshedShelfList(dialogId) then
            return DialogReturnVisibility()
        end
    end

    -- Rodina: после подтверждённого вывода сервер закрывает диалог полностью.
    -- Мы открываем меню через Alt и завершаем текущую полку только после свежего списка.
    if RodinaCollect.refreshPending
        and stateCrypto.work and processes.take then
        if RodinaCollect.HandleRefreshedShelfList(dialogId) then
            return DialogReturnVisibility()
        end
    end

    if settings.main.autoFillEnabled and not stateCrypto.work then
        local needFill = false
        for _, s in ipairs(shelves) do
            if (s.percentage or 0) <= (settings.main.fillFrom or 50.0) then
                needFill = true
                break
            end
        end

        if needFill then
            MMTCreateThread(function()
                wait(50)
                Interacting.Start("fill", "auto_fill")
            end)
        end
    end

    return DialogReturnVisibility()
end

local function HandleHouseSelectionDialog(dialogId, title, text)
    if not title:find("Выбор дома") then
        return nil
    end

    shelves = {}
    houses = {}

    if text:find("Энергия") then
        houses = Parser.HouseData(text)
    else
        return true
    end

    idDialogs.selectHouse = dialogId
    return DialogReturnVisibility()
end

local function HandleStatsInventoryDialog(dialogId, style, title, text)
    return nil
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)

    -- Verify a genuine real-mobile-ALT request from the preceding 2.5 seconds
    -- using dialog title/text, NEVER a hardcoded numeric dialog ID.
    AltProbe.ConfirmRealAltByDialog(title)

    if AltProbe.testPending then
        local plainTitle = Util.StripColors(title)
        if plainTitle:find("Выберите видеокарту", 1, true) then
            local elapsedMs = AltProbe.NowMs() - AltProbe.testPending.startedAt
            AltProbe.Write(string.format(
                "REPLAY_RESULT | SUCCESS dialog title matched in %dms (dialog ID not used for identification)",
                elapsedMs
            ))
            Chat.Add("ALT TEST: УСПЕХ! Настоящий список видеокарт открылся от пакета 220.", TYPECHATMESSAGES.WARNING)
            AltProbe.testPending = nil
        end
    end

    if AltProbe.active then
        local safeTitle = tostring(title or ""):gsub("{%x%x%x%x%x%x}", "")
        safeTitle = safeTitle:gsub("[%c]", " "):sub(1, 72)
        AltProbe.Write(string.format("DIALOG_OPEN | id=%s title=%s", tostring(dialogId), safeTitle))
    end

    RuntimeLog.Payload("DIALOG_IN", string.format(
        "id=%s style=%s title=%s button1=%s button2=%s",
        tostring(dialogId), tostring(style), tostring(title), tostring(button1), tostring(button2)
    ), text)
    lastIDDialog = dialogId
    stateCrypto.dialogSerial = (stateCrypto.dialogSerial or 0) + 1
    local plainDialogTitle = Util.StripColors(tostring(title or ""))
    if plainDialogTitle:find("Стойка", 1, true)
        and plainDialogTitle:find("Полка", 1, true) then
        stateCrypto.lastDialogKind = "shelf"
    elseif plainDialogTitle:find("Выберите видеокарту", 1, true) then
        stateCrypto.lastDialogKind = "list"
    else
        stateCrypto.lastDialogKind = "other"
    end

    if type(RodinaHouseBind.HandleShowDialog) == "function" then
        local bindHandled = RodinaHouseBind.HandleShowDialog(dialogId, style, title, button1, button2, text)
        if bindHandled ~= nil then
            return bindHandled
        end
    end

    local handled = nil

    handled = HandleTakeProfitDialog(dialogId, title, text)
    if handled ~= nil then
        return handled
    end

    handled = HandleShelfDialog(dialogId, title, text)
    if handled ~= nil then
        return handled
    end

    handled = HandleVideoCardSelectionDialog(dialogId, title, text)
    if handled ~= nil then
        return handled
    end

    handled = HandleHouseSelectionDialog(dialogId, title, text)
    if handled ~= nil then
        return handled
    end

    if Improve.HandleNewStyleChooseDialog(dialogId, title, text) then
        return DialogReturnVisibility()
    end

    if Improve.HandleNewStyleConfirmDialog(dialogId, title) then
        return DialogReturnVisibility()
    end

    handled = HandleStatsInventoryDialog(dialogId, style, title, text)
    if handled ~= nil then
        return handled
    end

    -- if not stateCrypto.work then
    --     imguiWindows.main[0] = false
    -- end
end

function onDialogResponse(dialogId, button, listboxId, input)
    if tonumber(dialogId or -1) == idDialogs.mobileImproveStatus then
        return Improve.HandleMobileStatusDialogResponse(button)
    end
    if ISMONETLOADER and mobileImproveDialog.wasActive and not mobileImproveDialog.closing
        and not (mobileImproveDialog.scriptBusy or improve.cef.probing)
        and os.clock() >= (mobileImproveDialog.suppressUntil or 0) then
        return Improve.HandleMobileStatusDialogResponse(button)
    end
end
function sampev.onDialogResponse(dialogId, button, listboxId, input)
    if tonumber(dialogId or -1) == idDialogs.mobileImproveStatus then
        return Improve.HandleMobileStatusDialogResponse(button)
    end
    if ISMONETLOADER and mobileImproveDialog.wasActive and not mobileImproveDialog.closing
        and not (mobileImproveDialog.scriptBusy or improve.cef.probing)
        and os.clock() >= (mobileImproveDialog.suppressUntil or 0) then
        return Improve.HandleMobileStatusDialogResponse(button)
    end
end
-- --------------------------------------------------------
--                           onSendDialogResponse
-- --------------------------------------------------------

-- Срабатывание на отправку диалога
function sampev.onSendDialogResponse(id, btn, list, input)
    if AltProbe.active then
        AltProbe.Write(string.format(
            "DIALOG_RESPONSE | id=%s button=%s list=%s input=%s",
            tostring(id), tostring(btn), tostring(list), tostring(input or "")
        ))
    end

    RuntimeLog.Write("DIALOG_OUT", string.format(
        "id=%s button=%s list=%s input=%s",
        tostring(id), tostring(btn), tostring(list), RuntimeLog.OneLine(input or "")
    ))
    RuntimeLog.State("dialog_response_out")
    if type(RodinaHouseBind.HandleSendDialogResponse) == "function" then
        RodinaHouseBind.HandleSendDialogResponse(id, btn, list, input)
    end

    if id == idDialogs.mobileImproveStatus then
        return Improve.HandleMobileStatusDialogResponse(btn)
    end

    if id == idDialogs.selectHouse then
        imguiWindows.main[0] = false
        houses = {}
        end

    if id == idDialogs.selectVideoCard then
        imguiWindows.main[0] = false
    end

end

-- --------------------------------------------------------
--                           onWindowMessage
-- --------------------------------------------------------

function IsArrowNavigationAvailable()
    if activeTabScript ~= "main" then
        return false
    end
    if #houses > 0 then
        return true
    end
    return #shelves > 0
end
function onWindowMessage(msg, wparam, lparam)
    if ISMONETLOADER and (msg == 0x0101 or msg == 0x101) and wparam == VK_RETURN and Improve.IsMobileStatusDialogActive() then
        consumeWindowMessage(true, false)
        Improve.StopFromMobileStatus()
        return
    end

    if not keysSuccess then return end

    local isMainWindowActive = imguiWindows.main[0]
    local isPauseInactive    = not isPauseMenuActive()

    if (msg == 0x0100 or msg == 0x0101)
       and isMainWindowActive and isPauseInactive
       and settings.main.arrowsMove
       and IsArrowNavigationAvailable()
    then
        local io = imgui.GetIO()
        local wantkbd = io and io.WantCaptureKeyboard
        if not wantkbd and (
            wparam == vkeys.VK_UP or
            wparam == vkeys.VK_DOWN
        ) then
            consumeWindowMessage(true, false)
            return
        end
    end

    -- =========================================================================
    local isEscapePressed   = (wparam == vkeys.VK_ESCAPE)
    local shouldCloseOnEsc  = settings.main.closeOnESC

    if (msg == 0x100 or msg == 0x101) and isEscapePressed and isMainWindowActive and isPauseInactive and shouldCloseOnEsc then
        consumeWindowMessage(true, false)
        if msg == 0x101 then
            UI.SwitchMainWindow()
            Interacting.Deactivate()
            sampSendDialogResponse(lastIDDialog, 0, 0, "")
            shelves = {}
            houses = {}
                end
    end
end

-- =====================================================================================================================
--                                                          FUNCTIONS
-- =====================================================================================================================

-- hex "RRGGBB" -> imgui.ImVec4
function HexToVec4(hex, alpha)
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return imgui.ImVec4(r, g, b, alpha or 1.0)
end

-- изменить яркость: factor > 1 — светлее, < 1 — темнее
function Shade(vec, factor, alpha)
    return imgui.ImVec4(
        math.min(vec.x * factor, 1.0),
        math.min(vec.y * factor, 1.0),
        math.min(vec.z * factor, 1.0),
        alpha or vec.w
    )
end

function CheckHouseInBlackList(number)
    for index, value in ipairs(settings.main.blackListHouses) do
        if tonumber(number) == value then return true end
    end
    return false
end

-- level            : уровень видеокарты (целое)
-- cool_percent_opt : (опц.) остаток охлаждения в процентах [0..100]
-- min_percent_opt  : (опц.) порог доливки, если задан - "время" до доливки,
--                    иначе - до полного нуля
-- Возвращает:
--   per_hour, per_24h, per_cycle, hours_to_show, income_to_end
-- где:
--   hours_to_show  - время до доливки (если выше порога) ИЛИ до конца работы (если порог уже пройден)
--   income_to_end  - прибыль до полного окончания охлаждайки (всегда до нуля)
local function CalcGpuIncome(level, cool_percent_opt, min_percent_opt, bonus_percent_opt)
    level = tonumber(level) or 1
    local per_hour  = GetGpuHourlyRate(level)
    local bonus_percent = tonumber(bonus_percent_opt) or 0
    if bonus_percent < 0 then
        bonus_percent = 0
    end
    per_hour = per_hour * (1 + bonus_percent / 100)
    local per_24h   = per_hour * 24
    local per_cycle = per_hour * GPU_CYCLE_HOURS

    local hours_to_show  = 0
    local income_to_end  = 0

    if cool_percent_opt ~= nil then
        -- нормализуем проценты
        local p = tonumber(cool_percent_opt) or 0
        if p < 0 then p = 0 elseif p > 100 then p = 100 end

        -- Всегда считаем "до нуля"
        local hours_until_zero = (p / 100) * GPU_CYCLE_HOURS
        income_to_end = per_hour * hours_until_zero

        -- Логика показа "времени":
        -- если выше порога - показываем до доливки,
        -- если на/ниже порога - показываем до конца работы (до нуля)
        local threshold = tonumber(min_percent_opt)
        if threshold ~= nil then
            if threshold < 0 then threshold = 0 elseif threshold > 100 then threshold = 100 end
            if p > threshold then
                hours_to_show = ((p - threshold) / 100) * GPU_CYCLE_HOURS
            else
                hours_to_show = hours_until_zero
            end
        else
            -- порога нет - просто до конца работы
            hours_to_show = hours_until_zero
        end
    end

    return per_hour, per_24h, per_cycle, hours_to_show, income_to_end
end

local function GetIncomeSettings()
    settings.main.income = settings.main.income or {}
    settings.main.income.houseBonuses = settings.main.income.houseBonuses or {}
    settings.main.income.rtx4090 = settings.main.income.rtx4090 == true
    return settings.main.income
end

local function NormalizeIncomeHouseBonusConfig(config)
    config = (type(config) == "table") and config or {}
    config.creativitySet = config.creativitySet == true
    config.customPercent = math.maxEx(0, tonumber(config.customPercent) or 0)
    config.onlineHours = nil
    return config
end

local function GetIncomeHouseBonusConfig(houseId)
    local numericHouseId = tonumber(houseId)
    if not numericHouseId or numericHouseId < 0 then
        return nil, nil
    end

    local houseKey = tostring(math.floor(numericHouseId))
    local houseBonuses = GetIncomeSettings().houseBonuses
    local config = houseBonuses[houseKey]
    if type(config) ~= "table" then
        return nil, houseKey
    end

    config = NormalizeIncomeHouseBonusConfig(config)
    houseBonuses[houseKey] = config
    return config, houseKey
end

local function CalcHouseIncomeBonusPercent(houseId)
    local inc = GetIncomeSettings()
    local config = GetIncomeHouseBonusConfig(houseId)
    local baseBonusPercent = config and (tonumber(config.customPercent) or 0) or 0

    -- "Свой процент" применяется к базовому доходу. Предметные бонусы
    -- являются отдельными множителями и перемножаются независимо.
    local multiplier = 1 + baseBonusPercent / 100
    if config and config.creativitySet then
        multiplier = multiplier * 1.25
    end
    if inc.rtx4090 then
        multiplier = multiplier * 1.25
    end

    return (multiplier - 1) * 100
end

local function GetSortedIncomeHouseBonusKeys()
    local keys = {}
    for houseKey in pairs(GetIncomeSettings().houseBonuses) do
        table.insert(keys, tostring(houseKey))
    end

    table.sort(keys, function(a, b)
        return (tonumber(a) or 0) < (tonumber(b) or 0)
    end)

    return keys
end

-- --------------------------------------------------------
--                           Dialog Utils
-- --------------------------------------------------------

function DialogUtils.waitForDialog(expectedDialogId, timeoutSeconds)
    local timeout = os.clock() + (timeoutSeconds or settings.deley.timeoutDialog)

    while lastIDDialog ~= expectedDialogId do
        wait(settings.deley.waitInterval)

        if os.clock() > timeout then
            return false, string.format("диалог %s не пришёл за %d сек.",
                tostring(expectedDialogId), math.floor(timeoutSeconds or settings.deley.timeoutDialog))
        end

        if not Interacting.IsActive() then
            return false, "процесс остановлен"
        end
    end

    return true
end

function DialogUtils.waitForAnyDialog(expectedDialogIds, timeoutSeconds)
    local timeout = os.clock() + (timeoutSeconds or settings.deley.timeoutDialog)

    while true do
        for _, dialogId in ipairs(expectedDialogIds) do
            if lastIDDialog == dialogId then
                return true, dialogId
            end
        end

        wait(settings.deley.waitInterval)

        if os.clock() > timeout then
            local dialogNames = table.concat(expectedDialogIds, ", ")
            return false, string.format("ни один из диалогов (%s) не пришёл за %d сек.",
                dialogNames, math.floor(timeoutSeconds or settings.deley.timeoutDialog))
        end

        if not Interacting.IsActive() then
            return false, "процесс остановлен"
        end
    end
end

function DialogUtils.sendResponseAndWait(dialogId, button, listitem, input, waitCondition)
    sampSendDialogResponse(dialogId, button, listitem, input or "")

    if waitCondition then
        local timeout = os.clock() + settings.deley.timeoutDialog
        while not waitCondition() do
            wait(settings.deley.waitInterval)
            if os.clock() > timeout then
                return false, string.format("сервер не ответил за %d сек.",
                    math.floor(settings.deley.timeoutDialog))
            end
            if not Interacting.IsActive() then
                return false, "процесс остановлен"
            end
        end
    end

    return true
end

-- Запускает поток, в котором ждем время на ответ и отвечаем
function DialogUtils.waitAndSendDialogResponse(dialogId, button, listitem, input, waitRun)
    MMTCreateThread(function ()
        waitRun = waitRun or settings.deley.waitRun

        local timeout = os.clock() + waitRun/1000
        while os.clock() < timeout do
            wait(settings.deley.waitInterval)
        end

        sampSendDialogResponse(dialogId, button, listitem, input or "")
    end)
end

-- --------------------------------------------------------
--                           Shelf Processor
-- --------------------------------------------------------

function ShelfProcessor.filterShelves()
    local filtered = {}

    for _, shelf in ipairs(shelves) do
        local shouldProcess = (
            (shelf.status == "Работает" and processes.off) or
            (shelf.status ~= "Работает" and processes.on and shelf.percentage > 0) or
            (shelf.profit >= 1.0 and processes.take) or
            (shelf.percentage <= settings.main.fillFrom and processes.fill)
        )

        if shouldProcess then
            table.insert(filtered, {
                samp_line = shelf.samp_line,
                fill = shelf.percentage,
                work = shelf.status == "Работает",
                count = (shelf.profit_primary or shelf.profit or 0) + (shelf.profit2 or 0),
                card_type = shelf.card_type,
                level = tonumber(shelf.level) or 0,
                shelf_number = shelf.shelf_number
            })
        end
    end

    RuntimeLog.Write("SHELVES", string.format(
        "filter | source=%d selected=%d | proc[take=%s fill=%s on=%s off=%s]",
        #(shelves or {}), #filtered,
        tostring(processes.take), tostring(processes.fill), tostring(processes.on), tostring(processes.off)
    ))
    for i, s in ipairs(filtered) do
        RuntimeLog.Write("SHELF_QUEUE", string.format(
            "i=%d shelf=%s samp_line=%s fill=%s count=%s work=%s level=%s",
            i, tostring(s.shelf_number), tostring(s.samp_line), tostring(s.fill),
            tostring(s.count), tostring(s.work), tostring(s.level)
        ))
    end
    return filtered
end

--- Сколько раз перезаходить на полку, если сервер не ответил
function ShelfProcessor.MaxRetries()
    return math.minEx(5, math.maxEx(0, tonumber(settings.deley.shelfRetries) or 2))
end

--- Список полок сейчас на экране (последним пришёл именно он)
function ShelfProcessor.IsShelfListOpen()
    local listSerial = stateCrypto.shelfListSerial or 0
    return listSerial > 0 and listSerial == (stateCrypto.dialogSerial or 0)
end

--- Возврат к списку полок: закрываем всё, что сервер оставил открытым, пока он не
--- пришлёт список заново. Заодно обновляются данные полок дома, поэтому повторная
--- попытка идёт уже по свежему состоянию, а не по устаревшему.
--- @return boolean recovered Список полок снова на экране
function ShelfProcessor.BackToShelfList()
    if ShelfProcessor.IsShelfListOpen() then return true end

    local startSerial = stateCrypto.shelfListSerial or 0
    local deadline = os.clock() + settings.deley.timeoutDialog

    while (stateCrypto.shelfListSerial or 0) <= startSerial do
        if not Interacting.IsActive() then return false end
        if os.clock() > deadline then return false end

        sampSendDialogResponse(lastIDDialog, 0, 0, "")
        wait(300)
    end

    return true
end

--- Одна полка: открыть, дождаться результата, при зависании вернуться к списку и повторить.
--- @return string outcome "done" | "skipped" | "lost" | "cancelled"
function ShelfProcessor.RunShelf(shelfData, index)
    local attempts = ShelfProcessor.MaxRetries() + 1
    RuntimeLog.Write("SHELF_RUN", string.format(
        "begin | index=%s shelf=%s samp_line=%s fill=%s count=%s work=%s attempts=%s",
        tostring(index), tostring(shelfData and shelfData.shelf_number),
        tostring(shelfData and shelfData.samp_line), tostring(shelfData and shelfData.fill),
        tostring(shelfData and shelfData.count), tostring(shelfData and shelfData.work),
        tostring(attempts)
    ))

    for attempt = 1, attempts do
        RuntimeLog.Write("SHELF_RUN", string.format(
            "attempt | index=%s attempt=%s/%s progress=%s dialog=%s",
            tostring(index), tostring(attempt), tostring(attempts),
            tostring(stateCrypto.progressShelves), tostring(lastIDDialog)
        ))
        local listReady, listError = DialogUtils.waitForAnyDialog({
            idDialogs.selectVideoCard
        })
        local responseDialogId = lastIDDialog

        if not listReady then
            if not Interacting.IsActive() then return "cancelled" end

            Chat.Add(string.format("Полка %d: %s", index, tostring(listError)), TYPECHATMESSAGES.WARNING)
            if not ShelfProcessor.BackToShelfList() then return "lost" end
        else
            if ISNEOMLOADER and processes.take
                and (type(shelfData.samp_line) ~= "number" or shelfData.samp_line < 0) then
                Chat.Add(string.format(
                    "Сбор Neo: нет однозначной строки для полки %s в новом списке — останавливаю сбор, чтобы не выбрать чужую карту",
                    tostring(shelfData.shelf_number or "?")
                ), TYPECHATMESSAGES.WARNING)
                Interacting.Deactivate("неоднозначный номер полки / строка списка")
                return "cancelled"
            end
            if IS_WINDOWS_MOONLOADER and processes.take
                and (type(shelfData.samp_line) ~= "number" or shelfData.samp_line < 0) then
                RuntimeLog.Write("COLLECT_PC", string.format(
                    "stopping: invalid next list row | index=%d shelf=%s line=%s",
                    index, tostring(shelfData.shelf_number), tostring(shelfData.samp_line)))
                Chat.Add("Сбор ПК остановлен: не удалось определить строку видеокарты.",
                    TYPECHATMESSAGES.WARNING)
                Interacting.Deactivate("PC: ambiguous GPU list row")
                return "cancelled"
            end
            local startProgress = stateCrypto.progressShelves
            local shelfDone = function()
                return stateCrypto.progressShelves ~= startProgress
            end

            local ok, sendError = DialogUtils.sendResponseAndWait(
                responseDialogId, 1, shelfData.samp_line, "", shelfDone
            )

            if ok then return "done" end
            if not Interacting.IsActive() then return "cancelled" end

            Chat.Add(string.format("Полка %d: %s Возвращаюсь и пробую снова (%d из %d)",
                index, tostring(sendError), attempt, attempts), TYPECHATMESSAGES.WARNING)

            if stateCrypto.waitFill then
                RodinaCooling.CancelPending()
            end
            if RodinaCollect.pending or RodinaCollect.refreshPending then
                RodinaCollect.CancelPending()
            end

            -- карточка видеокарты осталась открытой: закрываем её и берём свежий список
            if not ShelfProcessor.BackToShelfList() then return "lost" end
        end
    end

    return "skipped"
end

--- @return string outcome "done" | "lost" | "cancelled"
function ShelfProcessor.process()
    stateCrypto.progressShelves = 1
    stateCrypto.queueShelves = ShelfProcessor.filterShelves()
    stateCrypto.shelvesSkipped = 0

    if #stateCrypto.queueShelves == 0 then
        Chat.Add("Отсутствуют полки для работы", TYPECHATMESSAGES.WARNING)
        return "done"
    end

    for index, shelfData in ipairs(stateCrypto.queueShelves) do
        -- пропущенные полки двигают прогресс сами, иначе обработчики диалогов
        -- будут смотреть не на ту позицию очереди, что и цикл
        if (stateCrypto.progressShelves or 0) < index then
            stateCrypto.progressShelves = index
        end

        Collect.SummaryVisit(shelfData)

        local outcome = ShelfProcessor.RunShelf(shelfData, index)

        if outcome == "cancelled" then
            return "cancelled"
        elseif outcome == "lost" then
            Chat.Add(string.format("Полка %d: не удалось вернуться к списку полок", index),
                TYPECHATMESSAGES.WARNING)
            return "lost"
        elseif outcome == "skipped" then
            stateCrypto.shelvesSkipped = (stateCrypto.shelvesSkipped or 0) + 1
            stateCrypto.progressShelves = index + 1
            Chat.Add(string.format("Полка %d пропущена: сервер так и не ответил", index),
                TYPECHATMESSAGES.WARNING)
        end
    end

    if (stateCrypto.shelvesSkipped or 0) > 0 then
        Chat.Add(string.format("Пропущено полок из-за зависших диалогов: %d", stateCrypto.shelvesSkipped),
            TYPECHATMESSAGES.WARNING)
    end

    return "done"
end

-- --------------------------------------------------------
--                           Rodina Cooling
-- --------------------------------------------------------

function RodinaCooling.ResetPending()
    stateCrypto.waitFill = false
    stateCrypto.fillLiquidType = nil
    stateCrypto.fillLiquidLabel = nil
    stateCrypto.fillLiquidBefore = 0
    stateCrypto.fillLiquidAfter = 0
    RodinaCooling.pendingDialogId = nil
    RodinaCooling.pendingFillLine = nil
    RodinaCooling.pendingOnLine = nil
    RodinaCooling.pendingStartedAt = 0
    RodinaCooling.refreshPending = false
    RodinaCooling.refreshShelfNumber = nil
    RodinaCooling.refreshSampLine = nil
    RodinaCooling.refreshStartedAt = 0
    RodinaCooling.fillStartListSerial = 0
    RodinaCooling.guardBackSent = false
    -- Keep refreshToken monotonic: old worker jobs must never affect a newer fill.
    RodinaCooling.refreshToken = (RodinaCooling.refreshToken or 0) + 1
end

function RodinaCooling.CancelPending()
    RodinaCooling.ResetPending()
end

function RodinaCooling.BeginFill(dialogId, fillLine, onLine)
    if not (stateCrypto.work and processes.fill) then return false end

    stateCrypto.waitFill = true
    stateCrypto.fillLiquidType = "btc"
    stateCrypto.fillLiquidLabel = "охлаждающей жидкости"
    stateCrypto.fillLiquidBefore = RodinaCooling.inventoryKnown and (tonumber(haveLiquid.btc) or 0) or 0
    stateCrypto.fillLiquidAfter = stateCrypto.fillLiquidBefore

    RodinaCooling.pendingDialogId = dialogId
    RodinaCooling.pendingFillLine = fillLine
    RodinaCooling.pendingOnLine = onLine or RodinaCooling.pendingOnLine
    RodinaCooling.pendingStartedAt = os.clock()
    RodinaCooling.fillStartListSerial = tonumber(stateCrypto.shelfListSerial) or 0
    RodinaCooling.guardBackSent = false

    local current = stateCrypto.queueShelves[stateCrypto.progressShelves]
    RuntimeLog.Write("COOLING", string.format(
        "BeginFill | dialog=%s fillActionLine=%s queueIndex=%s shelf=%s samp_line=%s currentFill=%s",
        tostring(dialogId), tostring(fillLine), tostring(stateCrypto.progressShelves),
        tostring(current and current.shelf_number), tostring(current and current.samp_line),
        tostring(current and current.fill)
    ))
    RuntimeLog.State("cooling_begin_fill")
    return true
end

function RodinaCooling.DialogActive(dialogId)
    if type(sampIsDialogActive) ~= "function" or type(sampGetCurrentDialogId) ~= "function" then
        return false
    end

    local okActive, active = pcall(sampIsDialogActive)
    if not okActive or not active then return false end

    local okId, currentId = pcall(sampGetCurrentDialogId)
    return okId and tonumber(currentId) == tonumber(dialogId)
end

function RodinaCooling.ClearActionWait()
    stateCrypto.waitFill = false
    stateCrypto.fillLiquidType = nil
    stateCrypto.fillLiquidLabel = nil
    stateCrypto.fillLiquidBefore = 0
    stateCrypto.fillLiquidAfter = 0
    RodinaCooling.pendingStartedAt = 0
end

-- После success-уведомления от Rodina не используем процент из CEF как состояние полки.
-- Отказываемся от текущего диалога полки, сервер возвращает главный список,
-- а уже из него получаем реальный актуальный процент.
-- Wait only for a genuinely refreshed video-card list, or for the refresh
-- handler to clear the current generation. Never use a stale shelf dialog.
function RodinaCooling.WaitNeoFreshList(startSerial, refreshToken, timeoutMs)
    local deadline = RodinaCollect.NowMs() + math.max(0, tonumber(timeoutMs) or 0)
    while stateCrypto.work and processes.fill
        and RodinaCooling.refreshPending
        and RodinaCooling.refreshToken == refreshToken do
        -- A list may have arrived *before* the CEF notification. In that case
        -- onShowDialog missed refreshPending, but shelves[] has fresh data.
        if (tonumber(stateCrypto.shelfListSerial) or 0) > startSerial
            and ShelfProcessor.IsShelfListOpen() then
            RodinaCooling.HandleRefreshedShelfList(idDialogs.selectVideoCard)
            return true
        end
        if RodinaCollect.NowMs() >= deadline then break end
        wait(15)
    end
    return not RodinaCooling.refreshPending
        or RodinaCooling.refreshToken ~= refreshToken
        or not (stateCrypto.work and processes.fill)
end

-- Neo: refresh from live dialogs and/or the same verified 220/iface8/sub1024
-- packet as the successful BTC auto-ALT. No fake GTA controls, no stale list.
function RodinaCooling.ReturnToFreshShelfList(dialogId, refreshToken)
    if not (stateCrypto.work and processes.fill) then return end

    if ISNEOMLOADER then
        local token = tonumber(refreshToken) or RodinaCooling.refreshToken
        local startSerial = tonumber(RodinaCooling.fillStartListSerial) or 0
        local startedMs = RodinaCollect.NowMs()
        local function isCurrent()
            return stateCrypto.work and processes.fill
                and RodinaCooling.refreshPending
                and RodinaCooling.refreshToken == token
        end
        local function received(waitMs)
            return RodinaCooling.WaitNeoFreshList(startSerial, token, waitMs)
        end

        if received(120) then
            print('[MMT-R][NEOCOOL] fresh list arrived naturally')
            return
        end
        if not isCurrent() then return end

        -- The server normally leaves a shelf-detail dialog open after fill.
        -- Neo's sampIsDialogActive() may be false for intercepted dialogs; use
        -- the last *received matching shelf title* instead, then Back only once.
        local target = tonumber(dialogId) or tonumber(RodinaCooling.pendingDialogId)
        if not RodinaCooling.guardBackSent and target
            and tonumber(lastIDDialog) == target
            and stateCrypto.lastDialogKind == 'shelf' then
            RodinaCooling.guardBackSent = true
            pcall(sampSendDialogResponse, target, 0, 0, '')
            print('[MMT-R][NEOCOOL] sent safe Back from known shelf dialog')
            RuntimeLog.Write('COOLING_NEO', 'known shelf Back after confirmed fill')
        end
        if received(340) then
            print(string.format('[MMT-R][NEOCOOL] refreshed via Back in %dms',
                RodinaCollect.NowMs() - startedMs))
            return
        end
        if not isCurrent() then return end

        -- Fallback: confirmed ALT frame from this very client session. No
        -- guessing request IDs and no WALK/game-key injection (anti-cheat).
        local captured = AltProbe.capturedAlt
        local usable = AltProbe.confirmedAlt and type(captured) == 'table'
            and captured.iface == 8 and captured.sub == 1024
            and type(captured.reqid) == 'number'

        if usable then
            AltProbe.autoReplaySending = true
            local ok, sent = pcall(Improve.SendCefMobile,
                captured.iface, captured.sub, captured.reqid, '')
            AltProbe.autoReplaySending = false
            sent = ok and sent == true
            print('[MMT-R][NEOCOOL] verified mobile ALT replay | sent=' .. tostring(sent))
            RuntimeLog.Write('COOLING_NEO', 'verified ALT replay | sent=' .. tostring(sent))
            if sent and received(1400) then
                print(string.format('[MMT-R][NEOCOOL] refreshed via ALT in %dms',
                    RodinaCollect.NowMs() - startedMs))
                return
            end
        else
            print('[MMT-R][NEOCOOL] ALT not learned: requires one real mobile ALT press')
        end
        if not isCurrent() then return end

        Chat.Add('Охлаждение: список не открылся автоматически. Нажмите настоящий мобильный ALT один раз.',
            TYPECHATMESSAGES.WARNING)
        print('[MMT-R][NEOCOOL] waiting for one real interaction press')
        if received(7000) then
            print('[MMT-R][NEOCOOL] refreshed after manual ALT')
            return
        end
        if not isCurrent() then return end

        local reason = 'Neo: после заливки не пришёл свежий список карт'
        RuntimeLog.Write('COOLING_NEO', 'refresh timeout -> stopped safely')
        Interacting.Deactivate(reason)
        Chat.Add('Охлаждение остановлено: ' .. reason, TYPECHATMESSAGES.WARNING)
        return
    end

    -- PC/Monet behavior unchanged.
    local deadline = os.clock() + math.maxEx(2, tonumber(settings.deley.timeoutDialog) or 10)
    local sentBack = false

    while stateCrypto.work and processes.fill and RodinaCooling.refreshPending and os.clock() < deadline do
        if ShelfProcessor.IsShelfListOpen() then
            return
        end

        if not sentBack then
            local targetDialogId = tonumber(dialogId) or tonumber(RodinaCooling.pendingDialogId)
            if targetDialogId and RodinaCooling.DialogActive(targetDialogId) then
                pcall(sampSendDialogResponse, targetDialogId, 0, 0, '')
                sentBack = true
            end
        end

        wait(25)
    end

    if RodinaCooling.refreshPending and stateCrypto.work and processes.fill then
        Chat.Add('Охлаждение: не дождался свежего списка видеокарт после заливки', TYPECHATMESSAGES.WARNING)
    end
end

function RodinaCooling.HandleRefreshedShelfList(dialogId)
    RuntimeLog.Write("COOLING", string.format(
        "HandleRefreshedShelfList | dialog=%s refreshPending=%s wantedShelf=%s wantedLine=%s progress=%s",
        tostring(dialogId), tostring(RodinaCooling.refreshPending),
        tostring(RodinaCooling.refreshShelfNumber),
        tostring(RodinaCooling.refreshSampLine),
        tostring(stateCrypto.progressShelves)
    ))
    if not RodinaCooling.refreshPending then return false end
    if not (stateCrypto.work and processes.fill) then
        RodinaCooling.ResetPending()
        return false
    end

    local queueIndex = tonumber(stateCrypto.progressShelves) or 1
    local current = stateCrypto.queueShelves[queueIndex]
    if not current then
        RodinaCooling.ResetPending()
        return false
    end

    local wantedShelf = tonumber(RodinaCooling.refreshShelfNumber) or tonumber(current.shelf_number)
    local wantedLine = tonumber(RodinaCooling.refreshSampLine) or tonumber(current.samp_line)
    local fresh = nil
    local matchMethod = "none"

    -- samp_line is unique inside one "Выберите видеокарту" list.
    -- shelf_number is NOT unique: every rack has shelves 1..4.
    if wantedLine ~= nil then
        for _, shelf in ipairs(shelves or {}) do
            if tonumber(shelf.samp_line) == wantedLine then
                fresh = shelf
                matchMethod = "samp_line"
                break
            end
        end
    end

    -- Falling back to shelf_number is safe only when it is unique in this list.
    if not fresh and wantedShelf ~= nil then
        local candidates = {}
        for _, shelf in ipairs(shelves or {}) do
            if tonumber(shelf.shelf_number) == wantedShelf then
                candidates[#candidates + 1] = shelf
            end
        end
        if #candidates == 1 then
            fresh = candidates[1]
            matchMethod = "unique_shelf_number"
        elseif #candidates > 1 then
            RuntimeLog.Write("COOLING", string.format(
                "refresh identity ambiguous | wantedShelf=%s wantedLine=%s | candidates=%d",
                tostring(wantedShelf), tostring(wantedLine), #candidates
            ))
        end
    end

    if not fresh then
        Chat.Add(string.format(
            "Охлаждение: после заливки не удалось однозначно найти полку %s (строка %s). Повторную заливку пропускаю.",
            tostring(wantedShelf or "?"), tostring(wantedLine or "?")
        ), TYPECHATMESSAGES.WARNING)
        RuntimeLog.Write("COOLING", string.format(
            "refresh identity failed -> skip shelf | queueIndex=%s wantedShelf=%s wantedLine=%s parsedShelves=%d",
            tostring(queueIndex), tostring(wantedShelf), tostring(wantedLine), #(shelves or {})
        ))
        RodinaCooling.ResetPending()
        stateCrypto.progressShelves = queueIndex + 1
        RuntimeLog.State("cooling_refresh_identity_failed_skip")
        return true
    end

    RuntimeLog.Write("COOLING", string.format(
        "refresh identity matched | method=%s queueIndex=%s wantedShelf=%s wantedLine=%s -> freshShelf=%s freshLine=%s freshFill=%s",
        tostring(matchMethod), tostring(queueIndex), tostring(wantedShelf), tostring(wantedLine),
        tostring(fresh.shelf_number), tostring(fresh.samp_line), tostring(fresh.percentage)
    ))

    current.samp_line = fresh.samp_line
    current.fill = tonumber(fresh.percentage) or 0
    current.work = fresh.status == "Работает"
    current.count = (fresh.profit_primary or fresh.profit or 0) + (fresh.profit2 or 0)
    current.card_type = fresh.card_type
    current.level = tonumber(fresh.level) or current.level or 0
    current.shelf_number = fresh.shelf_number or current.shelf_number

    local freshPercent = tonumber(current.fill) or 0
    local threshold = tonumber(settings.main.fillFrom) or 50
    local needFillAgain = freshPercent <= threshold
    local needEnable = settings.main.autoEnableCards and not current.work and freshPercent > 0

    Chat.Add(string.format("Охлаждение: свежая полка %s, %.2f%%",
        tostring(current.shelf_number or "?"), freshPercent), TYPECHATMESSAGES.DEBUG)
    RuntimeLog.Write("COOLING", string.format(
        "refresh decision | shelf=%s line=%s fill=%.4f threshold=%.4f needFillAgain=%s needEnable=%s",
        tostring(current.shelf_number), tostring(current.samp_line),
        freshPercent, threshold, tostring(needFillAgain), tostring(needEnable)
    ))

    RodinaCooling.refreshPending = false
    RodinaCooling.refreshShelfNumber = nil
    RodinaCooling.refreshSampLine = nil
    RodinaCooling.refreshStartedAt = 0
    RodinaCooling.pendingDialogId = nil
    RodinaCooling.pendingFillLine = nil
    RodinaCooling.pendingOnLine = nil

    if needFillAgain or needEnable then
        local line = current.samp_line
        MMTCreateThread(function()
            wait(50)
            if not (stateCrypto.work and processes.fill) then return end
            if not ShelfProcessor.IsShelfListOpen() then return end
            sampSendDialogResponse(dialogId, 1, line, "")
        end)
        return true
    end

    stateCrypto.progressShelves = queueIndex + 1
    return true
end

function RodinaCooling.OnNoLiquid()
    if not (stateCrypto.work and processes.fill and stateCrypto.waitFill) then return end

    local dialogId = RodinaCooling.pendingDialogId
    RodinaCooling.inventoryKnown = true
    haveLiquid.btc = 0

    RodinaCooling.ResetPending()
    Chat.Add("Охлаждение: в инвентаре нет охлаждающей жидкости", TYPECHATMESSAGES.CRITICAL)

    if dialogId and RodinaCooling.DialogActive(dialogId) then
        pcall(sampSendDialogResponse, dialogId, 0, 0, "")
    end

    Interacting.Deactivate("нет охлаждающей жидкости")
end

function RodinaCooling.OnSuccess(percent)
    if not (stateCrypto.work and processes.fill and stateCrypto.waitFill) then return end

    local dialogId = RodinaCooling.pendingDialogId
    local current = stateCrypto.queueShelves[stateCrypto.progressShelves]

    RodinaCooling.ClearActionWait()
    RodinaCooling.refreshToken = (RodinaCooling.refreshToken or 0) + 1
    local currentRefreshToken = RodinaCooling.refreshToken
    RodinaCooling.guardBackSent = false

    -- Процент из CEF используем только для диагностики. Реальное состояние
    -- перечитываем из свежего главного списка после Button2 "Назад".
    RodinaCooling.refreshPending = true
    RodinaCooling.refreshShelfNumber = current and current.shelf_number or nil
    RodinaCooling.refreshSampLine = current and current.samp_line or nil
    RodinaCooling.refreshStartedAt = os.clock()

    RuntimeLog.Write("COOLING", string.format(
        "OnSuccess | cefPercent=%s queueIndex=%s shelf=%s samp_line=%s oldFill=%s -> refresh",
        tostring(percent), tostring(stateCrypto.progressShelves),
        tostring(current and current.shelf_number), tostring(current and current.samp_line),
        tostring(current and current.fill)
    ))
    RuntimeLog.State("cooling_success_before_refresh")

    Chat.Add(string.format("Охлаждение: Rodina подтвердила заливку%s, обновляю список",
        tonumber(percent) and string.format(" до %.1f%%", tonumber(percent)) or ""), TYPECHATMESSAGES.DEBUG)

    MMTCreateThread(function()
        wait(ISNEOMLOADER and 35 or 75)
        if RodinaCooling.refreshToken ~= currentRefreshToken then return end
        RodinaCooling.ReturnToFreshShelfList(dialogId, currentRefreshToken)
    end)
end

function RodinaCooling.UpdateInventoryFromPayload(payload)
    if not payload:find("event.inventory.playerInventory", 1, true) then return end

    local jsonText = payload:match("`(%b[])`")
    if not jsonText then return end

    local ok, pages = pcall(json.decode, jsonText)
    if not ok or type(pages) ~= "table" then return end

    for _, page in ipairs(pages) do
        if type(page) == "table" then
            local body = type(page.data) == "table" and page.data or page
            if tonumber(body.type) == 1 and type(body.items) == "table" then
                local action = tonumber(page.action) or tonumber(body.action)
                local found = false

                for _, item in ipairs(body.items) do
                    if type(item) == "table" then
                        local slot = tonumber(item.slot)
                        local itemId = tonumber(item.item)

                        if itemId == RodinaCooling.ITEM_ID then
                            RodinaCooling.inventorySlot = slot or RodinaCooling.inventorySlot
                            RodinaCooling.inventoryKnown = true
                            haveLiquid.btc = math.maxEx(0, tonumber(item.amount) or tonumber(item.text) or 0)
                            found = true
                        elseif RodinaCooling.inventorySlot and slot == RodinaCooling.inventorySlot
                            and (item.available == 0 or item.item == nil) then
                            RodinaCooling.inventoryKnown = true
                            haveLiquid.btc = 0
                            found = true
                        end
                    end
                end

                -- action 0 is a full inventory page. If the known coolant slot vanished, coolant count is zero.
                if action == 0 and RodinaCooling.inventorySlot and not found then
                    RodinaCooling.inventoryKnown = true
                    haveLiquid.btc = 0
                end
            end
        end
    end
end

function RodinaCooling.HandleNotificationPayload(payload)
    -- Build 28: Neo/Rodina sends CEF notification directly as {"styleInt":...,"text":...}.
    -- Build 27 only accepted the old cef.addNotification wrapper and missed ALL fills.
    -- Keep legacy notifications, but also recognize the direct Neo JSON payload.
    local isWrappedNotification = payload:find("cef.addNotification", 1, true) ~= nil
    local isDirectNeoNotification = payload:match("^%s*%{") ~= nil
        and payload:find('"styleInt"', 1, true) ~= nil
        and payload:find('"text"', 1, true) ~= nil
    if not isWrappedNotification and not isDirectNeoNotification then return end

    RodinaCooling.notificationPacketsSeen = (tonumber(RodinaCooling.notificationPacketsSeen) or 0) + 1
    RodinaCooling.lastNotificationPreview = payload:gsub("[%c]", " "):sub(1, 300)

    -- Сначала ловим нужные уведомления прямо в сыром CEF-тексте.
    -- Это не зависит от того, удалось ли cjson разобрать обёртку JSON.stringify.
    local noLiquidCp = "В инвентаре нет охлаждающей жидкости"
    local noLiquidUtf8 = u8(noLiquidCp)
    if payload:find(noLiquidUtf8, 1, true) or payload:find(noLiquidCp, 1, true) then
        RodinaCooling.OnNoLiquid()
        return
    end

    local successCp = "Вы залили охлаждающую жидкость!"
    local successUtf8 = u8(successCp)
    if payload:find(successUtf8, 1, true) or payload:find(successCp, 1, true) then
        local percent = payload:match("([%d%.]+)%%")
        RuntimeLog.Write("COOLING_NOTIFY", string.format(
            "fill success received | source=%s percent=%s waitFill=%s queueIndex=%s",
            isDirectNeoNotification and "direct_neo" or "wrapped",
            tostring(percent), tostring(stateCrypto.waitFill), tostring(stateCrypto.progressShelves)
        ))
        RodinaCooling.OnSuccess(percent)
        return
    end

    -- Fallback: штатный разбор JSON. Нужен, например, если сервер начнёт
    -- присылать русские строки как unicode escape-последовательности.
    local jsonText = payload:match("JSON%.stringify%((%b[])%)")
    if not jsonText then return end

    local ok, notifications = pcall(json.decode, jsonText)
    if not ok or type(notifications) ~= "table" then return end

    for _, notification in ipairs(notifications) do
        if type(notification) == "table" then
            local description = tostring(notification.description or "")

            if description:find(noLiquidUtf8, 1, true) or description:find(noLiquidCp, 1, true) then
                RodinaCooling.OnNoLiquid()
                return
            end

            if description:find(successUtf8, 1, true) or description:find(successCp, 1, true) then
                local percent = description:match("([%d%.]+)%%")
                RodinaCooling.OnSuccess(percent)
                return
            end
        end
    end
end

function RodinaCooling.HandleCefPayload(payload, source)
    if type(payload) ~= "string" or payload == "" then return end

    RodinaCooling.cefPacketsSeen = (tonumber(RodinaCooling.cefPacketsSeen) or 0) + 1
    RodinaCooling.lastCefAt = os.clock()
    RodinaCooling.lastCefPreview = payload:gsub("[%c]", " "):sub(1, 220)
    RodinaCooling.lastCefSource = tostring(source or "unknown")
    RodinaCooling.lastHookError = ""

    RodinaCooling.UpdateInventoryFromPayload(payload)
    RodinaCooling.HandleNotificationPayload(payload)
end

-- --------------------------------------------------------
--                           Rodina House Bind
-- --------------------------------------------------------

function RodinaHouseBind.CleanText(value)
    return tostring(value or ""):gsub("{%x%x%x%x%x%x}", "")
end

function RodinaHouseBind.CleanTitle(value)
    return RodinaHouseBind.CleanText(value):gsub("^%s+", ""):gsub("%s+$", "")
end

function RodinaHouseBind.IsHomeListTitle(title)
    return RodinaHouseBind.CleanTitle(title):find("^Мои дома") ~= nil
end

function RodinaHouseBind.GetHouseIdFromTitle(title)
    return tonumber(RodinaHouseBind.CleanTitle(title):match("^Дом%s*№(%d+)$"))
end

function RodinaHouseBind.IsResolverDialog(title)
    return RodinaHouseBind.IsHomeListTitle(title)
        or RodinaHouseBind.GetHouseIdFromTitle(title) ~= nil
end

function RodinaHouseBind.ResetAttemptState()
    RodinaHouseBind.phase = "idle"
    RodinaHouseBind.candidates = {}
    RodinaHouseBind.candidateIndex = 0
    RodinaHouseBind.resolverDialogId = nil
    RodinaHouseBind.foundHouseId = nil
    RodinaHouseBind.pendingAbortReason = nil
    RodinaHouseBind.expectedDeadline = 0
end

function RodinaHouseBind.ResetResolverState(keepHouse)
    RodinaHouseBind.active = false
    RodinaHouseBind.ResetAttemptState()
    RodinaHouseBind.startedAt = 0
    RodinaHouseBind.retryPending = false
    RodinaHouseBind.retryNotBefore = 0
    RodinaHouseBind.lastDialogAt = 0
    RodinaHouseBind.retryReason = nil
    RodinaHouseBind.attempt = 0

    if not keepHouse then
        RodinaHouseBind.currentHouseId = nil
        stateCrypto.currentHouseId = nil
        stateCrypto.shelfListHouse = nil
    end
end

function RodinaHouseBind.ClearCurrentHouse()
    RodinaHouseBind.ResetResolverState(false)
end

function RodinaHouseBind.Abort(reason)
    if not RodinaHouseBind.active then return end

    local message = tostring(reason or "определение прервано")
    RodinaHouseBind.ResetResolverState(false)
    RodinaHouseBind.suppressUntil = os.clock() + 2.2

    Chat.Add("Не удалось привязать подвал к дому: " .. message .. ".", TYPECHATMESSAGES.WARNING)
    Chat.Add("Войдите в подвал повторно, MMT попробует определить ID дома ещё раз.", TYPECHATMESSAGES.SECONDARY)
end

function RodinaHouseBind.Finish(houseId)
    local id = tonumber(houseId)
    if not id or id <= 0 then
        RodinaHouseBind.Abort("сервер вернул некорректный ID")
        return
    end

    RodinaHouseBind.currentHouseId = math.floor(id)
    stateCrypto.currentHouseId = RodinaHouseBind.currentHouseId
    stateCrypto.shelfListHouse = RodinaHouseBind.currentHouseId

    RodinaHouseBind.active = false
    RodinaHouseBind.ResetAttemptState()
    RodinaHouseBind.startedAt = 0
    RodinaHouseBind.retryPending = false
    RodinaHouseBind.retryNotBefore = 0
    RodinaHouseBind.lastDialogAt = 0
    RodinaHouseBind.retryReason = nil
    RodinaHouseBind.attempt = 0

    -- Если сервер после финального "Закрыть" пришлёт старый resolver-диалог,
    -- он будет скрыт/закрыт и не всплывёт пользователю.
    RodinaHouseBind.suppressUntil = os.clock() + 2.2

    Chat.Add("Подвал успешно привязан к дому " .. tostring(RodinaHouseBind.currentHouseId) .. ".", TYPECHATMESSAGES.SUCCESS)
end

function RodinaHouseBind.FindEntryLineIndexes(text)
    local basementIndex = nil
    local outsideIndex = nil
    local listIndex = -1

    for rawLine in tostring(text or ""):gmatch("[^\r\n]+") do
        local line = RodinaHouseBind.CleanText(rawLine):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            listIndex = listIndex + 1
            if line == "Войти в подвал с вентиляцией" then
                basementIndex = listIndex
            elseif line == "Выйти на улицу" then
                outsideIndex = listIndex
            end
        end
    end

    return basementIndex, outsideIndex
end

function RodinaHouseBind.IsEntryDialog(text)
    local clean = RodinaHouseBind.CleanText(text)
    return clean:find("Выйти на улицу", 1, true) ~= nil
        and clean:find("Войти в подвал с вентиляцией", 1, true) ~= nil
end

-- Полностью как в NeRMarket по смыслу:
-- берём только "Номер N", трейлеры/Sprinter не попадают в кандидаты,
-- а открытые дома проверяем раньше закрытых.
function RodinaHouseBind.ParseHomeCandidates(text)
    local opened = {}
    local closed = {}
    local lineIndex = 0

    for rawLine in tostring(text or ""):gmatch("[^\r\n]+") do
        lineIndex = lineIndex + 1
        local line = RodinaHouseBind.CleanText(rawLine)
        local houseId = line:match("^%s*%d+%.%s*Номер%s+(%d+)")
        if houseId then
            local candidate = {
                houseId = tonumber(houseId),
                sampLine = lineIndex - 2, -- Style 5: строка заголовка не является selectable item
                isOpen = line:find("%[Открыт%]") ~= nil,
            }

            if candidate.isOpen then
                table.insert(opened, candidate)
            else
                table.insert(closed, candidate)
            end
        end
    end

    for _, candidate in ipairs(closed) do
        table.insert(opened, candidate)
    end

    return opened
end

-- Критерий текущего ФИЗИЧЕСКОГО дома из NeRMarket:
-- в /home-меню этого дома появляются локальные действия хранилищ.
function RodinaHouseBind.IsCurrentPhysicalHouseMenu(text)
    local clean = RodinaHouseBind.CleanText(text)
    return clean:find("Шкаф", 1, true) ~= nil
        or clean:find("Холодильник", 1, true) ~= nil
        or clean:find("Мини-бар", 1, true) ~= nil
end

function RodinaHouseBind.RespondNow(dialogId, button, listIndex)
    if not dialogId then return false end
    local ok = pcall(sampSendDialogResponse, dialogId, button, listIndex or 0, "")
    return ok
end

function RodinaHouseBind.SetExpectedPhase(phase)
    RodinaHouseBind.phase = phase
    RodinaHouseBind.expectedDeadline = os.clock() + 2.2
end

function RodinaHouseBind.StartAttempt()
    if not RodinaHouseBind.active then return end

    RodinaHouseBind.attempt = (tonumber(RodinaHouseBind.attempt) or 0) + 1
    if RodinaHouseBind.attempt > RodinaHouseBind.maxAttempts then
        RodinaHouseBind.Abort(RodinaHouseBind.retryReason or "сервер несколько раз не ответил на /home")
        return
    end

    RodinaHouseBind.candidates = {}
    RodinaHouseBind.candidateIndex = 0
    RodinaHouseBind.resolverDialogId = nil
    RodinaHouseBind.foundHouseId = nil
    RodinaHouseBind.pendingAbortReason = nil
    RodinaHouseBind.retryPending = false
    RodinaHouseBind.retryReason = nil

    RodinaHouseBind.SetExpectedPhase("wait_home")
    sampSendChat("/home")
end

-- Это не задержка между нормальными действиями.
-- Используется только после сбоя/чужого диалога: NeRMarket ждёт минимум 1с
-- и 2с тишины по диалогам перед повторным /home.
function RodinaHouseBind.ScheduleRetry(reason)
    if not RodinaHouseBind.active then return end

    RodinaHouseBind.retryPending = true
    RodinaHouseBind.retryReason = tostring(reason or "resolver прерван")
    RodinaHouseBind.retryNotBefore = os.clock() + 1.0
    RodinaHouseBind.lastDialogAt = os.clock()
    RodinaHouseBind.phase = "retry_wait"
    RodinaHouseBind.expectedDeadline = 0

    Chat.Add("Привязка дома прервана: " .. RodinaHouseBind.retryReason .. ". Повторю автоматически.", TYPECHATMESSAGES.WARNING)
end

function RodinaHouseBind.SelectCurrentCandidate(dialogId)
    local candidate = RodinaHouseBind.candidates[RodinaHouseBind.candidateIndex]
    if not candidate then
        RodinaHouseBind.pendingAbortReason = "ни один из домов в /home не совпал с текущим физическим домом"
        RodinaHouseBind.SetExpectedPhase("wait_abort_home")
        RodinaHouseBind.RespondNow(dialogId, 0, 0)
        return
    end

    RodinaHouseBind.resolverDialogId = dialogId
    RodinaHouseBind.SetExpectedPhase("wait_house")
    RodinaHouseBind.RespondNow(dialogId, 1, candidate.sampLine)
end

function RodinaHouseBind.HandleHomeList(dialogId, title, text)
    RodinaHouseBind.lastDialogAt = os.clock()
    RodinaHouseBind.resolverDialogId = dialogId

    -- Финальный возврат после найденного дома: закрываем /home и только затем finish.
    if RodinaHouseBind.phase == "wait_final_home" then
        local found = RodinaHouseBind.foundHouseId
        RodinaHouseBind.RespondNow(dialogId, 0, 0)
        RodinaHouseBind.Finish(found)
        return true
    end

    -- Чистое завершение неуспешного перебора: сначала закрыть /home, потом сообщить ошибку.
    if RodinaHouseBind.phase == "wait_abort_home" then
        local reason = RodinaHouseBind.pendingAbortReason or "не удалось определить текущий дом"
        RodinaHouseBind.RespondNow(dialogId, 0, 0)
        RodinaHouseBind.Abort(reason)
        return true
    end

    -- Возврат "Назад" после проверки очередного дома:
    -- список уже есть, сразу кликаем следующего кандидата.
    if RodinaHouseBind.phase == "wait_back_home" then
        RodinaHouseBind.SelectCurrentCandidate(dialogId)
        return true
    end

    -- Первый /home текущей попытки.
    if RodinaHouseBind.phase == "wait_home" then
        RodinaHouseBind.candidates = RodinaHouseBind.ParseHomeCandidates(text)
        RodinaHouseBind.candidateIndex = 1

        if #RodinaHouseBind.candidates == 0 then
            RodinaHouseBind.RespondNow(dialogId, 0, 0)
            RodinaHouseBind.Abort("в /home не найдено ни одного обычного дома")
            return true
        end

        RodinaHouseBind.SelectCurrentCandidate(dialogId)
        return true
    end

    return false
end

function RodinaHouseBind.HandleHouseMenu(dialogId, title, text)
    RodinaHouseBind.lastDialogAt = os.clock()
    RodinaHouseBind.resolverDialogId = dialogId

    local titleHouseId = RodinaHouseBind.GetHouseIdFromTitle(title)
    if not titleHouseId then
        return false
    end

    if RodinaHouseBind.phase ~= "wait_house" then
        return false
    end

    local candidate = RodinaHouseBind.candidates[RodinaHouseBind.candidateIndex]
    if not candidate then
        RodinaHouseBind.ScheduleRetry("сервер открыл меню дома без ожидаемого кандидата")
        RodinaHouseBind.RespondNow(dialogId, 0, 0)
        return true
    end

    if tonumber(candidate.houseId) ~= tonumber(titleHouseId) then
        RodinaHouseBind.ScheduleRetry("сервер открыл неожиданный дом " .. tostring(titleHouseId))
        RodinaHouseBind.RespondNow(dialogId, 0, 0)
        return true
    end

    if RodinaHouseBind.IsCurrentPhysicalHouseMenu(text) then
        -- Нужный дом найден. НЕ завершаем здесь:
        -- жмём "Назад", ждём возврат в "Мои дома", жмём "Закрыть",
        -- и только после этого фиксируем houseID.
        RodinaHouseBind.foundHouseId = titleHouseId
        RodinaHouseBind.SetExpectedPhase("wait_final_home")
        RodinaHouseBind.RespondNow(dialogId, 0, 0)
        return true
    end

    RodinaHouseBind.candidateIndex = RodinaHouseBind.candidateIndex + 1

    if RodinaHouseBind.candidateIndex > #RodinaHouseBind.candidates then
        RodinaHouseBind.pendingAbortReason = "ни в одном доме из /home не появились пункты текущего физического дома"
        RodinaHouseBind.SetExpectedPhase("wait_abort_home")
        RodinaHouseBind.RespondNow(dialogId, 0, 0)
        return true
    end

    -- Обычный NeRMarket-flow: Назад -> сервер возвращает "Мои дома"
    -- -> немедленно выбираем следующего кандидата.
    RodinaHouseBind.SetExpectedPhase("wait_back_home")
    RodinaHouseBind.RespondNow(dialogId, 0, 0)
    return true
end

function RodinaHouseBind.Begin()

    RodinaHouseBind.serial = (RodinaHouseBind.serial or 0) + 1
    local mySerial = RodinaHouseBind.serial

    -- Новый подвал всегда должен получить новую привязку.
    RodinaHouseBind.ResetResolverState(false)
    RodinaHouseBind.active = true
    RodinaHouseBind.startedAt = os.clock()
    RodinaHouseBind.lastDialogAt = os.clock()
    RodinaHouseBind.attempt = 0
    RodinaHouseBind.suppressUntil = 0

    Chat.Add("Привязываю подвал к дому. Прошу не взаимодействовать с полками, пока не закончу.", TYPECHATMESSAGES.SECONDARY)

    -- В нормальном flow НЕТ wait(700), wait(25), wait(1000) между действиями.
    -- Сразу запускаем тот же событийный resolver, что и NeRMarket.
    RodinaHouseBind.StartAttempt()

    -- Единственный thread здесь - watchdog таймаутов/авторетрая.
    -- Он не замедляет нормальный путь ни на кадр.
    MMTCreateThread(function()
        while RodinaHouseBind.active and RodinaHouseBind.serial == mySerial do
            local now = os.clock()

            if RodinaHouseBind.retryPending then
                local dialogActive = false
                if type(sampIsDialogActive) == "function" then
                    local ok, active = pcall(sampIsDialogActive)
                    dialogActive = ok and active or false
                end

                -- Пока любой диалог открыт, тишины ещё нет.
                -- Отсчёт 2 секунд начинается именно после его фактического закрытия.
                if dialogActive then
                    RodinaHouseBind.lastDialogAt = now
                end

                local minWaitPassed = now >= (tonumber(RodinaHouseBind.retryNotBefore) or 0)
                local silencePassed = (now - (tonumber(RodinaHouseBind.lastDialogAt) or 0)) >= 2.0

                if minWaitPassed and silencePassed and not dialogActive then
                    RodinaHouseBind.StartAttempt()
                end
            elseif RodinaHouseBind.expectedDeadline > 0 and now >= RodinaHouseBind.expectedDeadline then
                RodinaHouseBind.ScheduleRetry("сервер не ответил на ожидаемый диалог за 2.2 сек")
            end

            wait(25)
        end
    end)
end

function RodinaHouseBind.HandleShowDialog(dialogId, style, title, button1, button2, text)

    local now = os.clock()
    local isHomeList = RodinaHouseBind.IsHomeListTitle(title)
    local houseMenuId = RodinaHouseBind.GetHouseIdFromTitle(title)

    -- Подавляем только запоздалые resolver-диалоги после finish/abort.
    if not RodinaHouseBind.active
        and now < (tonumber(RodinaHouseBind.suppressUntil) or 0)
        and (isHomeList or houseMenuId)
    then
        RodinaHouseBind.RespondNow(dialogId, 0, 0)
        return false
    end

    -- Всегда запоминаем диалог входа/выхода по ТЕКСТУ, а не по ID.
    if RodinaHouseBind.IsEntryDialog(text) then
        local basementIndex, outsideIndex = RodinaHouseBind.FindEntryLineIndexes(text)
        RodinaHouseBind.entryDialogId = dialogId
        RodinaHouseBind.basementListIndex = basementIndex
        RodinaHouseBind.outsideListIndex = outsideIndex

        if RodinaHouseBind.active then
            RodinaHouseBind.ScheduleRetry("во время определения открыт другой пользовательский диалог")
        end
        return nil
    end

    if not RodinaHouseBind.active then
        return nil
    end

    RodinaHouseBind.lastDialogAt = now

    -- Во время retry скрываем и закрываем запоздалые resolver-диалоги старой попытки.
    if RodinaHouseBind.retryPending then
        if isHomeList or houseMenuId then
            RodinaHouseBind.RespondNow(dialogId, 0, 0)
            return false
        end

        -- Посторонний пользовательский диалог не крадём: просто ждём его закрытия
        -- и 2 секунды тишины, после чего автоматически повторим /home.
        return nil
    end

    if isHomeList then
        local handled = RodinaHouseBind.HandleHomeList(dialogId, title, text)
        if handled then return false end
    end

    if houseMenuId then
        local handled = RodinaHouseBind.HandleHouseMenu(dialogId, title, text)
        if handled then return false end
    end

    -- Неожиданный пользовательский диалог: как в NeRMarket, текущую попытку
    -- считаем испорченной и повторяем после минимальной паузы + dialog silence.
    RodinaHouseBind.ScheduleRetry("определение было прервано пользовательским диалогом")
    return nil
end

function RodinaHouseBind.HandleSendDialogResponse(id, btn, list, input)
    if tonumber(id or -1) ~= tonumber(RodinaHouseBind.entryDialogId or -2) then return end

    local selected = tonumber(list)

    if tonumber(btn or 0) == 1 and selected == tonumber(RodinaHouseBind.basementListIndex) then
        -- Даём серверу 200 мс обработать сам вход в подвал,
        -- после чего запускаем старый быстрый NeRMarket-style resolver.
        MMTCreateThread(function()
            wait(200)
            RodinaHouseBind.Begin()
        end)
        return
    end

    if tonumber(btn or 0) == 1 and selected == tonumber(RodinaHouseBind.outsideListIndex) then
        RodinaHouseBind.ClearCurrentHouse()
    end
end

-- --------------------------------------------------------
--                           Rodina Collect
-- --------------------------------------------------------

function RodinaCollect.Reset()
    RodinaCollect.pending = false
    RodinaCollect.refreshPending = false
    RodinaCollect.expectedAmount = 0
    RodinaCollect.pendingShelfNumber = nil
    RodinaCollect.pendingQueueIndex = 0
    RodinaCollect.pendingStartedAt = 0
    RodinaCollect.refreshStartedAt = 0
    RodinaCollect.sourceShelfDialogId = nil
    RodinaCollect.confirmDialogId = nil
end

function RodinaCollect.CancelPending()
    RodinaCollect.Reset()
end

function RodinaCollect.Begin(availableAmount, confirmDialogId)
    RuntimeLog.Write("COLLECT", string.format(
        "Begin | available=%s confirmDialog=%s sourceShelfDialog=%s",
        tostring(availableAmount), tostring(confirmDialogId), tostring(RodinaCollect.sourceShelfDialogId)
    ))
    if not (stateCrypto.work and processes.take) then return false end

    local current = stateCrypto.queueShelves[stateCrypto.progressShelves]
    RodinaCollect.pending = true
    RodinaCollect.refreshPending = false
    RodinaCollect.expectedAmount = math.maxEx(0, math.floor(tonumber(availableAmount) or 0))
    RodinaCollect.pendingShelfNumber = current and current.shelf_number or nil
    RodinaCollect.pendingQueueIndex = tonumber(stateCrypto.progressShelves) or 0
    RodinaCollect.pendingStartedAt = os.clock()
    RodinaCollect.refreshStartedAt = 0
    RodinaCollect.confirmDialogId = tonumber(confirmDialogId)
    return true
end

function RodinaCollect.RecordTake(amount, remaining)
    amount = math.maxEx(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then return false end

    local hid = stateCrypto.currentHouseId or 0
    local queueIndex = tonumber(RodinaCollect.pendingQueueIndex) or tonumber(stateCrypto.progressShelves) or 0
    local queueShelf = stateCrypto.queueShelves[queueIndex]

    collectStats.total.BTC = (collectStats.total.BTC or 0) + amount
    collectStats.house[hid] = collectStats.house[hid] or { BTC = 0 }
    collectStats.house[hid].BTC = (collectStats.house[hid].BTC or 0) + amount

    Collect.AddLogEntry(hid, "BTC", amount)
    Collect.SummaryTake(queueShelf, "BTC", amount)

    if queueShelf and remaining ~= nil then
        queueShelf.count = math.maxEx(0, tonumber(remaining) or 0)
    end

    RodinaCollect.lastAmount = amount
    RodinaCollect.lastRemaining = tonumber(remaining)
    return true
end

function RodinaCollect.PressAlt()
    -- IMPORTANT: never use setGameKeyState() for this on Neo. Build 19 proved
    -- that changing GTA control state is sent/seen as player sync and Rodina's
    -- anti-cheat kicks with "Fly Hack - Пешком".
    --
    -- A virtual keyboard ALT pulse does not alter movement/player sync. If Neo
    -- does not map it to the mobile interaction button, the safe manual fallback
    -- in OpenFreshShelfListViaAlt() takes over.
    if type(setVirtualKeyDown) ~= "function" then
        if ISNEOMLOADER then
            print("[MMT-R][NEOCOLLECT] VK_ALT unavailable")
        end
        return false
    end

    local okDown = pcall(setVirtualKeyDown, 0x12, true)
    wait(70)
    local okUp = pcall(setVirtualKeyDown, 0x12, false)

    if ISNEOMLOADER then
        print(string.format(
            "[MMT-R][NEOCOLLECT] VK_ALT pulse | down=%s up=%s",
            tostring(okDown), tostring(okUp)
        ))
    end

    return okDown and okUp
end

-- Wall/game-time timer for short Rodina UI waits.
-- os.clock() measures process CPU time and can stretch a "1.5 sec" timeout into
-- several real seconds while the coroutine is yielding.
function RodinaCollect.NowMs()
    if type(getGameTimer) == "function" then
        local ok, value = pcall(getGameTimer)
        if ok and tonumber(value) then
            return tonumber(value)
        end
    end
    return math.floor(os.clock() * 1000)
end

function RodinaCollect.IsFreshShelfList(startSerial)
    return (tonumber(stateCrypto.shelfListSerial) or 0) > (tonumber(startSerial) or 0)
        and ShelfProcessor.IsShelfListOpen()
end

function RodinaCollect.WaitFreshShelfList(startSerial, timeoutMs)
    local deadline = RodinaCollect.NowMs() + math.max(0, tonumber(timeoutMs) or 0)

    while RodinaCollect.refreshPending and stateCrypto.work and processes.take do
        if RodinaCollect.IsFreshShelfList(startSerial) then
            return true
        end
        if RodinaCollect.NowMs() >= deadline then
            break
        end
        wait(15)
    end

    return RodinaCollect.IsFreshShelfList(startSerial)
end

function RodinaCollect.ActiveDialogId()
    if type(sampIsDialogActive) ~= "function" or type(sampGetCurrentDialogId) ~= "function" then
        return nil
    end

    local okActive, active = pcall(sampIsDialogActive)
    if not okActive or not active then return nil end

    local okId, dialogId = pcall(sampGetCurrentDialogId)
    if not okId then return nil end
    return tonumber(dialogId)
end

-- After the server has already CONFIRMED the BTC withdrawal, only these two
-- dialogs belong to the completed operation and are safe to back out of:
-- 1) the withdrawal confirmation, 2) the source shelf details.
function RodinaCollect.BackOutKnownDialog()
    local currentId = RodinaCollect.ActiveDialogId()
    if not currentId then return false end

    local confirmId = tonumber(RodinaCollect.confirmDialogId)
    local shelfId = tonumber(RodinaCollect.sourceShelfDialogId)
    if currentId ~= confirmId and currentId ~= shelfId then
        RuntimeLog.Write("COLLECT_REFRESH", string.format(
            "known-back skipped | active=%s confirm=%s shelf=%s",
            tostring(currentId), tostring(confirmId), tostring(shelfId)
        ))
        return false
    end

    RuntimeLog.Write("COLLECT_REFRESH", string.format(
        "known-back | active=%s confirm=%s shelf=%s",
        tostring(currentId), tostring(confirmId), tostring(shelfId)
    ))
    pcall(sampSendDialogResponse, currentId, 0, 0, "")
    return true
end

function RodinaCollect.OpenFreshShelfListViaAlt()
    if not (stateCrypto.work and processes.take) then return end

    local startSerial = tonumber(stateCrypto.shelfListSerial) or 0
    local startedMs = RodinaCollect.NowMs()

    RuntimeLog.Write("COLLECT_REFRESH", string.format(
        "begin | serial=%s confirm=%s shelfDialog=%s activeDialog=%s",
        tostring(startSerial), tostring(RodinaCollect.confirmDialogId),
        tostring(RodinaCollect.sourceShelfDialogId), tostring(RodinaCollect.ActiveDialogId())
    ))

    -- Neo: build 25 confirmed genuine mobile ALT is CEF 220/0x3F iface=8
    -- sub=1024 with an empty payload. The request ID is session-specific:
    -- learn it only from an actual ALT press (validated by a card-list dialog).
    -- NO VK_ALT, no WALK/game keys, no stale dialog IDs, no packet loops.
    if ISNEOMLOADER then
        if RodinaCollect.WaitFreshShelfList(startSerial, 180) then
            return
        end

        local captured = AltProbe.capturedAlt
        local usable = AltProbe.confirmedAlt and type(captured) == "table"
            and captured.iface == 8 and captured.sub == 1024
            and type(captured.reqid) == "number"

        if usable and RodinaCollect.refreshPending and stateCrypto.work and processes.take then
            -- One verified replay per confirmed withdrawal, not a flood.
            AltProbe.autoReplaySending = true
            local callOk, sent = pcall(Improve.SendCefMobile,
                captured.iface, captured.sub, captured.reqid, '')
            AltProbe.autoReplaySending = false
            sent = callOk and sent == true

            print("[MMT-R][NEOCOLLECT] native ALT packet replay | sent=" .. tostring(sent))
            RuntimeLog.Write("COLLECT_NEO", string.format(
                "native ALT replay | sent=%s startSerial=%s", tostring(sent), tostring(startSerial)
            ))

            if sent and RodinaCollect.WaitFreshShelfList(startSerial, 3000) then
                print(string.format(
                    "[MMT-R][NEOCOLLECT] fresh list from native ALT | elapsed=%dms serial=%s",
                    RodinaCollect.NowMs() - startedMs, tostring(stateCrypto.shelfListSerial)
                ))
                return
            end
        else
            print("[MMT-R][NEOCOLLECT] no validated mobile ALT packet yet")
        end

        if RodinaCollect.IsFreshShelfList(startSerial) then return end
        Chat.Add(
            "Neo: автоматический ALT не открыл список. Нажмите настоящую кнопку взаимодействия один раз — MMT продолжит сбор.",
            TYPECHATMESSAGES.WARNING
        )
        print("[MMT-R][NEOCOLLECT] waiting for manual interaction (max 10s)")
        if RodinaCollect.WaitFreshShelfList(startSerial, 10000) then
            print("[MMT-R][NEOCOLLECT] fresh list after manual mobile ALT")
            return
        end

        -- Don't let the outer shelf worker hang forever or send responses to
        -- dialogs the server has already consumed. Cancel action cleanly.
        local reason = "Neo: не пришёл свежий список видеокарт после вывода BTC"
        RuntimeLog.Write("COLLECT_NEO", "reopen timeout; safely stopping collect")
        Interacting.Deactivate(reason)
        Chat.Add("Сбор остановлен: " .. reason, TYPECHATMESSAGES.WARNING)
        return
    end

    -- Most withdrawals already transition naturally. Give the server a tiny window
    -- before touching anything.
    if RodinaCollect.WaitFreshShelfList(startSerial, 90) then
        RuntimeLog.Write("COLLECT_REFRESH", string.format(
            "fresh list arrived naturally | elapsed=%dms",
            RodinaCollect.NowMs() - startedMs
        ))
        return
    end

    -- If the completed confirmation or the old shelf is still locally active,
    -- back out immediately instead of waiting up to 1.5 CPU-seconds.
    for step = 1, 2 do
        if RodinaCollect.BackOutKnownDialog() then
            if RodinaCollect.WaitFreshShelfList(startSerial, 140) then
                RuntimeLog.Write("COLLECT_REFRESH", string.format(
                    "fresh list after known-back step=%d | elapsed=%dms",
                    step, RodinaCollect.NowMs() - startedMs
                ))
                return
            end
        else
            break
        end
    end

    -- No known dialog is blocking us: open the interaction menu directly.
    if RodinaCollect.ActiveDialogId() == nil then
        RuntimeLog.Write("COLLECT_REFRESH", "press Alt #1")
        RodinaCollect.PressAlt()
        if RodinaCollect.WaitFreshShelfList(startSerial, 650) then
            RuntimeLog.Write("COLLECT_REFRESH", string.format(
                "fresh list after Alt #1 | elapsed=%dms",
                RodinaCollect.NowMs() - startedMs
            ))
            return
        end
    end

    -- One conservative recovery pass. Never click an unrelated dialog.
    if RodinaCollect.BackOutKnownDialog() then
        RodinaCollect.WaitFreshShelfList(startSerial, 180)
    end

    if not RodinaCollect.IsFreshShelfList(startSerial) and RodinaCollect.ActiveDialogId() == nil then
        RuntimeLog.Write("COLLECT_REFRESH", "press Alt #2")
        RodinaCollect.PressAlt()
        if RodinaCollect.WaitFreshShelfList(startSerial, 900) then
            RuntimeLog.Write("COLLECT_REFRESH", string.format(
                "fresh list after Alt #2 | elapsed=%dms",
                RodinaCollect.NowMs() - startedMs
            ))
            return
        end
    end

    if RodinaCollect.refreshPending then
        RuntimeLog.Write("COLLECT_REFRESH", string.format(
            "timeout | elapsed=%dms activeDialog=%s serialNow=%s startSerial=%s",
            RodinaCollect.NowMs() - startedMs, tostring(RodinaCollect.ActiveDialogId()),
            tostring(stateCrypto.shelfListSerial), tostring(startSerial)
        ))
        Chat.Add("Сбор: после вывода BTC не дождался свежего списка видеокарт", TYPECHATMESSAGES.WARNING)
    end
end

-- Windows-only verified dialog-response helper. Do not use for mobile.
-- The ordinary sampSendDialogResponse function only transmits the RPC; it does
-- not guarantee that a visible native SA-MP modal is dismissed on the PC.
function RodinaCollect.PCSendKnownDialog(dialogId, button, context)
    if not IS_WINDOWS_MOONLOADER then return false end
    dialogId = tonumber(dialogId)
    if not dialogId then return false end

    local confirm = tonumber(RodinaCollect.confirmDialogId)
    local source = tonumber(RodinaCollect.sourceShelfDialogId)
    if dialogId ~= confirm and dialogId ~= source then
        RuntimeLog.Write("COLLECT_PC", string.format(
            "unverified dialog; refusing response | id=%s context=%s",
            tostring(dialogId), tostring(context)))
        return false
    end

    local active = RodinaCollect.ActiveDialogId()
    if active == dialogId and type(sampCloseCurrentDialogWithButton) == "function" then
        -- Closes the actual native modal AND sends the chosen dialog button.
        -- Never send a duplicate RPC after this succeeds.
        local ok, err = pcall(sampCloseCurrentDialogWithButton, button)
        RuntimeLog.Write("COLLECT_PC", string.format(
            "native modal close | id=%s button=%s context=%s ok=%s err=%s",
            dialogId, button, tostring(context), tostring(ok), tostring(err)))
        if ok then return true end
    end

    -- MMT may have hidden the incoming SA-MP dialog with replaceDialog=true.
    -- Only then send the already-confirmed dialog's response directly.
    local ok, err = pcall(sampSendDialogResponse, dialogId, button, 0, "")
    RuntimeLog.Write("COLLECT_PC", string.format(
        "RPC response | id=%s button=%s context=%s active=%s ok=%s err=%s",
        dialogId, button, tostring(context), tostring(active),
        tostring(ok), tostring(err)))
    return ok
end

-- Windows MoonLoader only. Neo/Monet uses the untouched mobile path.
function RodinaCollect.OpenFreshShelfListPC()
    if not IS_WINDOWS_MOONLOADER or not (stateCrypto.work and processes.take and RodinaCollect.refreshPending) then
        return false
    end

    local startSerial = tonumber(stateCrypto.shelfListSerial) or 0
    local startedMs = RodinaCollect.NowMs()
    RuntimeLog.Write("COLLECT_PC", string.format(
        "refresh start | serial=%s active=%s lastDialog=%s kind=%s shelf=%s confirm=%s",
        tostring(startSerial), tostring(RodinaCollect.ActiveDialogId()),
        tostring(lastIDDialog), tostring(stateCrypto.lastDialogKind),
        tostring(RodinaCollect.sourceShelfDialogId), tostring(RodinaCollect.confirmDialogId)))

    if RodinaCollect.WaitFreshShelfList(startSerial, 160) then return true end

    -- A visible confirmation modal must be closed LOCALLY before ALT can work.
    -- The screen shown by the user still displayed this modal after the BTC
    -- success message, even though Build 29 had sent an RPC back to the server.
    local active = RodinaCollect.ActiveDialogId()
    local confirm = tonumber(RodinaCollect.confirmDialogId)
    local source = tonumber(RodinaCollect.sourceShelfDialogId)
    if active and (active == confirm or active == source) then
        RodinaCollect.PCSendKnownDialog(active, 0, "post_withdrawal_back")
        if RodinaCollect.WaitFreshShelfList(startSerial, 900) then return true end
    end

    -- If the server returned a shelf dialog, its onShowDialog handler sends
    -- Button2/Back. Allow time for that automatic two-step transition.
    if RodinaCollect.WaitFreshShelfList(startSerial, 350) then return true end

    -- A virtual ALT is strictly the final fully AUTOMATIC recovery step.
    -- Never ask the player to intervene mid-batch.
    if not RodinaCollect.IsFreshShelfList(startSerial)
        and RodinaCollect.ActiveDialogId() == nil then
        RuntimeLog.Write("COLLECT_PC", "automatic ALT after local modal was dismissed")
        local sent = RodinaCollect.PressAlt()
        RuntimeLog.Write("COLLECT_PC", "automatic ALT sent=" .. tostring(sent))
        if RodinaCollect.WaitFreshShelfList(startSerial, 1500) then return true end
    end

    -- If a known modal reappeared, close it locally once (no blind RPC spam).
    active = RodinaCollect.ActiveDialogId()
    if not RodinaCollect.IsFreshShelfList(startSerial)
        and active and (active == confirm or active == source) then
        RodinaCollect.PCSendKnownDialog(active, 0, "final_verified_back")
        if RodinaCollect.WaitFreshShelfList(startSerial, 900) then return true end
    end

    if RodinaCollect.refreshPending and not RodinaCollect.IsFreshShelfList(startSerial) then
        RuntimeLog.Write("COLLECT_PC", string.format(
            "auto refresh failed | elapsed_ms=%s active=%s lastDialog=%s kind=%s serialNow=%s",
            tostring(RodinaCollect.NowMs() - startedMs),
            tostring(RodinaCollect.ActiveDialogId()), tostring(lastIDDialog),
            tostring(stateCrypto.lastDialogKind), tostring(stateCrypto.shelfListSerial)))
        Interacting.Deactivate("PC BTC: no fresh GPU list after confirmed withdrawal")
        Chat.Add("Сбор ПК остановлен: не получен новый список. Отправьте MMT_runtime.log.",
            TYPECHATMESSAGES.WARNING)
    end
    return false
end

function RodinaCollect.OnSuccess(amount, remaining, source)
    RuntimeLog.Write("COLLECT", string.format(
        "OnSuccess | amount=%s remaining=%s source=%s pending=%s",
        tostring(amount), tostring(remaining), tostring(source), tostring(RodinaCollect.pending)
    ))
    if not (stateCrypto.work and processes.take and RodinaCollect.pending) then return false end

    amount = math.maxEx(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then return false end

    local expected = tonumber(RodinaCollect.expectedAmount) or 0
    if expected > 0 and amount ~= expected then
        Chat.Add(string.format("Сбор DEBUG: Rodina ожидала %d BTC, сервер подтвердил %d BTC",
            expected, amount), TYPECHATMESSAGES.DEBUG)
    end

    RodinaCollect.RecordTake(amount, remaining)
    RodinaCollect.pending = false
    RodinaCollect.refreshPending = true
    RodinaCollect.refreshStartedAt = os.clock()
    RodinaCollect.lastSource = tostring(source or "unknown")

    if ISNEOMLOADER then
        -- A stale list-dialog ID cannot be reused after the first card: the server
        -- already consumed that dialog response. Re-open the mining interaction
        -- exactly like a real Alt/WALK press and wait for a NEW card list.
        Chat.Add(string.format("Сбор: Rodina подтвердила вывод %d BTC%s, безопасно открываю свежий список",
            amount,
            remaining ~= nil and string.format(" (остаток %.6f BTC)", tonumber(remaining) or 0) or ""),
            TYPECHATMESSAGES.DEBUG)

        RuntimeLog.Write("COLLECT_NEO", string.format(
            "confirmed -> reopen list | queueIndex=%s serial=%s",
            tostring(RodinaCollect.pendingQueueIndex), tostring(stateCrypto.shelfListSerial)
        ))
        print(string.format(
            "[MMT-R][NEOCOLLECT] confirmed %d BTC -> safe reopen fresh list",
            amount
        ))

        MMTCreateThread(function()
            wait(120)
            RodinaCollect.OpenFreshShelfListViaAlt()
        end)
        return true
    end

    if IS_WINDOWS_MOONLOADER then
        -- The old PC path trusted sampIsDialogActive() even when the dialog
        -- was hidden by MMT's ImGui replacement; that prevented Back handling.
        RodinaCollect.pcBackCount = 0
        RuntimeLog.Write("COLLECT_PC", "BTC confirmed -> PC dialog refresh")
        MMTCreateThread(function()
            wait(40)
            RodinaCollect.OpenFreshShelfListPC()
        end)
        return true
    end

    Chat.Add(string.format("Сбор: Rodina подтвердила вывод %d BTC%s, обновляю список",
        amount,
        remaining ~= nil and string.format(" (остаток %.6f BTC)", tonumber(remaining) or 0) or ""),
        TYPECHATMESSAGES.DEBUG)

    MMTCreateThread(function()
        wait(40)
        RodinaCollect.OpenFreshShelfListViaAlt()
    end)
    return true
end

function RodinaCollect.HandleRefreshedShelfList(dialogId)
    if not RodinaCollect.refreshPending then return false end
    if not (stateCrypto.work and processes.take) then
        RodinaCollect.Reset()
        return false
    end

    local queueIndex = tonumber(RodinaCollect.pendingQueueIndex) or tonumber(stateCrypto.progressShelves) or 0
    local current = stateCrypto.queueShelves[queueIndex]
    local wantedShelf = tonumber(RodinaCollect.pendingShelfNumber) or (current and tonumber(current.shelf_number))
    local fresh = nil

    for _, shelf in ipairs(shelves or {}) do
        if wantedShelf and tonumber(shelf.shelf_number) == wantedShelf then
            fresh = shelf
            break
        end
    end

    if IS_WINDOWS_MOONLOADER then
        local function matchQueueShelf(queued)
            if not queued then return nil, "missing_queue" end
            local oldLine, number = tonumber(queued.samp_line), tonumber(queued.shelf_number)
            if oldLine ~= nil then
                for _, candidate in ipairs(shelves or {}) do
                    if tonumber(candidate.samp_line) == oldLine
                        and tonumber(candidate.shelf_number) == number then
                        return candidate, "same_line_and_number"
                    end
                end
            end
            -- Number-only fallback is permitted only if uniquely identifiable.
            local found, count = nil, 0
            for _, candidate in ipairs(shelves or {}) do
                if number and tonumber(candidate.shelf_number) == number then
                    found, count = candidate, count + 1
                end
            end
            if count == 1 then return found, "unique_number" end
            return nil, "ambiguous_or_missing"
        end

        for i = queueIndex + 1, #(stateCrypto.queueShelves or {}) do
            local queued = stateCrypto.queueShelves[i]
            local match, method = matchQueueShelf(queued)
            if match then
                queued.samp_line = match.samp_line
                queued.fill = tonumber(match.percentage) or queued.fill
                queued.count = (match.profit_primary or match.profit or 0) + (match.profit2 or 0)
                queued.work = match.status == "Работает"
                queued.level = tonumber(match.level) or queued.level
            else
                if queued then queued.samp_line = nil end
                RuntimeLog.Write("COLLECT_PC", string.format(
                    "no verified row for queued shelf | idx=%d number=%s method=%s",
                    i, tostring(queued and queued.shelf_number), tostring(method)))
            end
        end
        local activeMatch, method = matchQueueShelf(current)
        if activeMatch and current then
            current.samp_line = activeMatch.samp_line
            current.fill = tonumber(activeMatch.percentage) or current.fill
            current.work = activeMatch.status == "Работает"
            current.count = (activeMatch.profit_primary or activeMatch.profit or 0)
                + (activeMatch.profit2 or 0)
        end
        RuntimeLog.Write("COLLECT_PC", string.format(
            "fresh list confirmed | dialog=%s completed_queue=%s matched=%s method=%s",
            tostring(dialogId), tostring(queueIndex), tostring(activeMatch ~= nil), tostring(method)))
        RodinaCollect.Reset()
        stateCrypto.progressShelves = queueIndex + 1
        return true
    end

    -- A fresh list may have different row positions. Never reuse old samp_line
    -- for the next card; bind each remaining queued card to an unambiguous shelf.
    local freshByShelf, freshDuplicates = {}, {}
    for _, item in ipairs(shelves or {}) do
        local number = tonumber(item.shelf_number)
        if number then
            if freshByShelf[number] then freshDuplicates[number] = true end
            freshByShelf[number] = item
        end
    end
    for i = queueIndex + 1, #(stateCrypto.queueShelves or {}) do
        local queued = stateCrypto.queueShelves[i]
        local number = queued and tonumber(queued.shelf_number)
        local updated = number and freshByShelf[number]
        if updated and not freshDuplicates[number] then
            queued.samp_line = updated.samp_line
            queued.count = (updated.profit_primary or updated.profit or 0) + (updated.profit2 or 0)
            queued.fill = tonumber(updated.percentage) or queued.fill
            queued.work = updated.status == "Работает"
            queued.level = tonumber(updated.level) or queued.level
        else
            -- Fail closed: avoid selecting the wrong GPU if the shelf is missing
            -- or the list contains duplicate shelf numbers (multiple racks).
            if queued then queued.samp_line = nil end
            RuntimeLog.Write("COLLECT_NEO", string.format(
                "ambiguous/missing next shelf | queue=%d shelf=%s", i, tostring(number)
            ))
        end
    end

    if current and fresh then
        current.samp_line = fresh.samp_line
        current.fill = tonumber(fresh.percentage) or current.fill or 0
        current.work = fresh.status == "Работает"
        current.count = (fresh.profit_primary or fresh.profit or 0) + (fresh.profit2 or 0)
        current.card_type = fresh.card_type
        current.level = tonumber(fresh.level) or current.level or 0
        current.shelf_number = fresh.shelf_number or current.shelf_number
    elseif not fresh then
        Chat.Add(string.format("Сбор: после вывода не нашёл полку %s в свежем списке",
            tostring(wantedShelf or "?")), TYPECHATMESSAGES.WARNING)
    end

    RodinaCollect.Reset()
    stateCrypto.progressShelves = queueIndex + 1
    return true
end

function RodinaCollect.HandleCefPayload(payload, source)
    if type(payload) ~= "string" or payload == "" then return end
    if not RodinaCollect.pending then return end

    -- Neo sends the BTC confirmation as a DIRECT CEF notification object:
    -- {"styleInt":1,"title":"","text":"Вы вывели 1 BTC, осталось на счету видеокарты: ... BTC"}
    -- Old code accepted only the cef.addNotification wrapper and silently lost
    -- this real server success, causing a 10-second timeout instead of ALT.
    -- Keep the original wrapped format on every platform. Direct-JSON support
    -- is Neo-only; PC and Monet dispatch retain their Build31 behavior.
    local wrapped = payload:find("cef.addNotification", 1, true) ~= nil
    local directNeo = ISNEOMLOADER
        and payload:find('"styleInt"', 1, true) ~= nil
        and payload:find('"text"', 1, true) ~= nil
    if not wrapped and not directNeo then return end

    local cpPattern = "Вы вывели%s*([%d%.]+)%s*BTC,%s*осталось на счету видеокарты:%s*([%d%.]+)%s*BTC"
    local utfPattern = u8(cpPattern)
    local amount, remaining = payload:match(utfPattern)
    if not amount then
        amount, remaining = payload:match(cpPattern)
    end

    if amount then
        RuntimeLog.Write("COLLECT_NOTIFY", string.format(
            "BTC success in CEF | format=%s amount=%s remaining=%s source=%s",
            directNeo and "neo_direct" or "wrapped", tostring(amount),
            tostring(remaining), tostring(source)))
        RodinaCollect.OnSuccess(tonumber(amount), tonumber(remaining), source or "cef")
    end
end


-- --------------------------------------------------------
--                           House Processor
-- --------------------------------------------------------


--- Сколько раз перезаходить в дом, который не отработал целиком
function HouseProcessor.MaxRetries()
    return math.minEx(3, math.maxEx(0, tonumber(settings.deley.houseRetries) or 1))
end

--- Возврат к списку домов: закрываем всё, что осталось открытым.
--- Раньше этот цикл был без таймаута и слал ответы каждые 10 мс - если сервер
--- список так и не присылал, сбор вис намертво.
--- @return boolean recovered Список домов снова на экране
function HouseProcessor.BackToHouseList()
    local deadline = os.clock() + settings.deley.timeoutDialog

    while lastIDDialog ~= idDialogs.selectHouse do
        if not Interacting.IsActive() then return false end
        if os.clock() > deadline then return false end

        sampSendDialogResponse(lastIDDialog, 0, 0, "")
        wait(300)
    end

    return true
end

--- Один дом: открыть, дождаться полок, обойти их.
--- @return string outcome "done" | "retry" | "cancelled"
function HouseProcessor.RunHouse(houseData, index)
    local listReady, listError = DialogUtils.waitForDialog(idDialogs.selectHouse)
    if not listReady then
        if not Interacting.IsActive() then return "cancelled" end
        Chat.Add("Список домов: " .. tostring(listError), TYPECHATMESSAGES.WARNING)
        return "retry"
    end

    -- Очищаем данные полок для нового дома
    shelves = {}
    stateCrypto.queueShelves = {}

    sampSendDialogResponse(lastIDDialog, 1, houseData.samp_line, "")
    lastOpenHouse = index
    stateCrypto.currentHouseId = houses[index] and houses[index].house_number or nil
    if stateCrypto.currentHouseId and not collectStats.house[stateCrypto.currentHouseId] then
        collectStats.house[stateCrypto.currentHouseId] = { BTC = 0 }
    end

    -- Ждем загрузки полок с таймаутом
    local timeout = os.clock() + settings.deley.timeoutShelf
    while #shelves == 0 do
        wait(50)

        if not Interacting.IsActive() then return "cancelled" end

        if os.clock() > timeout then
            Chat.Add("Не смог получить полки для дома " .. index, TYPECHATMESSAGES.WARNING)
            return "retry"
        end
    end

    local outcome = ShelfProcessor.process()
    if outcome == "cancelled" then return "cancelled" end
    if outcome == "lost" then return "retry" end

    return "done"
end

function HouseProcessor.processRegularHouses()
    stateCrypto.progressHouses = 1
    stateCrypto.queueHouses = {}

    for _, house in ipairs(houses) do
        table.insert(stateCrypto.queueHouses, {
            samp_line = house.samp_line,
        })
    end

    for index, houseData in ipairs(stateCrypto.queueHouses) do
        local attempts = HouseProcessor.MaxRetries() + 1
        local houseDone = false

        for attempt = 1, attempts do
            local outcome = HouseProcessor.RunHouse(houseData, index)

            if outcome == "cancelled" then return false end
            if outcome == "done" then
                houseDone = true
                break
            end

            -- дом не отработал: возвращаемся к списку домов и заходим заново
            if not HouseProcessor.BackToHouseList() then
                Chat.Add("Не удалось вернуться к списку домов, сбор остановлен", TYPECHATMESSAGES.CRITICAL)
                stateCrypto.stopReason = "не удалось вернуться к списку домов"
                return false
            end

            if attempt < attempts then
                Chat.Add(string.format("Дом %d: перепроверяю (попытка %d из %d)",
                    index, attempt + 1, attempts), TYPECHATMESSAGES.WARNING)
            else
                Chat.Add(string.format("Дом %d пропущен после %d попыток, иду к следующему",
                    index, attempts), TYPECHATMESSAGES.WARNING)
            end
        end

        -- Закрываем диалог дома
        if not HouseProcessor.BackToHouseList() then
            Chat.Add("Не удалось вернуться к списку домов, сбор остановлен", TYPECHATMESSAGES.CRITICAL)
            stateCrypto.stopReason = "не удалось вернуться к списку домов"
            return false
        end

        stateCrypto.progressHouses = stateCrypto.progressHouses + 1

        if processes.take and stateCrypto.currentHouseId and collectStats.house[stateCrypto.currentHouseId] then
            local s = collectStats.house[stateCrypto.currentHouseId]
            Chat.Add(string.format(
                "Дом %s: собрано %s",
                tostring(stateCrypto.currentHouseId), string.format("%s BTC", tostring(s.BTC or 0))
            ), TYPECHATMESSAGES.SECONDARY)
        end
        stateCrypto.currentHouseId = nil
    end

    return true
end

function Interacting.Start(action, source)
    RuntimeLog.Write("ACTION", string.format(
        "Interacting.Start | action=%s source=%s", tostring(action), tostring(source)
    ))
    RuntimeLog.State("interacting_start_requested")

    if RodinaHouseBind.active then
        Chat.Add("Идёт определение ID дома. Подождите завершения привязки подвала.", TYPECHATMESSAGES.WARNING)
        return false
    end

    -- Не трогаем существующий рабочий поток. Старый код только писал предупреждение,
    -- а затем мог terminate/run его прямо посреди обработки.
    if stateCrypto.work or Interacting.IsActive() then
        Chat.Add("Процесс уже запущен", TYPECHATMESSAGES.WARNING)
        return false
    end

    local boundRodinaHouseId = RodinaHouseBind.currentHouseId
    Interacting.Deactivate()

    collectStats = { total = { BTC = 0 }, house = {}, summary = Collect.NewSummary(source) }
    stateCrypto.currentHouseId = boundRodinaHouseId

    if action == "fill" then
        processes.fill = true
    elseif action == "take" then
        processes.take = true
        collectStats = { total = { BTC = 0 }, house = {}, summary = Collect.NewSummary(source) }
        stateCrypto.currentHouseId = boundRodinaHouseId
    elseif action == "on" then
        processes.on = true
    elseif action == "off" then
        processes.off = true
    else
        Chat.Add("Нет действий", TYPECHATMESSAGES.CRITICAL)
        return false
    end

    -- NeoMLoader 0.1.6: динамический lua_thread.create_suspended() после уже
    -- завершившегося действия падает внутри libneomloader.so ещё до возврата в Lua.
    -- Поэтому на Neo вообще не создаём interaction-thread на лету: Interacting.Process
    -- выполняется как задача в одном из четырёх бессмертных WorkerPool-потоков,
    -- которые были созданы один раз при старте скрипта.
    if ISNEOMLOADER then
        print("[MMT-R][NEOACT] submit to worker pool | action=" .. tostring(action))
        local task = MMTCreateThread(Interacting.Process)
        if task then
            return true
        end
        Interacting.Deactivate("не удалось поставить действие в WorkerPool")
        Chat.Add("Не удалось запустить процесс: WorkerPool не принял задачу", TYPECHATMESSAGES.WARNING)
        return false
    end

    -- PC/Monet: сохраняем прежнюю схему отдельного suspended-потока.
    local status = "dead"
    if processInteractingThread then
        local okStatus, value = pcall(function() return processInteractingThread:status() end)
        if okStatus and value then status = tostring(value) end
    end

    if not processInteractingThread or status == "dead" then
        processInteractingThread = lua_thread.create_suspended(Interacting.Process)
        status = "suspended"
    end

    if status == "suspended" then
        processInteractingThread:run()
        return true
    end

    Chat.Add("Не удалось запустить процесс: поток занят (" .. tostring(status) .. ")", TYPECHATMESSAGES.WARNING)
    return false
end

function Interacting.Process()
    -- Инициализация
    stateCrypto.work = true
    RuntimeLog.Write("ACTION", "Interacting.Process entered")
    RuntimeLog.State("interacting_process_begin")

    local success = true


    -- Обрабатываем обычные дома или полки напрямую
    if #houses > 0 then
        success = HouseProcessor.processRegularHouses()
    else
        local outcome = ShelfProcessor.process()
        success = outcome ~= "cancelled"
    end

    if not success then
        Interacting.Deactivate(stateCrypto.stopReason)
        return
    end

    -- Итоги по всем домам (если больше одного дома или просто удобно видеть общий итог)
    if (collectStats.total.BTC or 0) > 0 and processes.take then
        Chat.Add("Итого за сессию: " .. tostring(Collect.NormalizeCryptoAmount(collectStats.total.BTC or 0)) .. " BTC", TYPECHATMESSAGES.SUCCESS)
    end

    if processes.take then
        Collect.PrintSummary()
    end

    Interacting.Deactivate()
    Chat.Add("Обработка завершена успешно", TYPECHATMESSAGES.SUCCESS)
end

function Interacting.IsActive()
    return processes.take or processes.fill or processes.on or processes.off
end

function Interacting.Deactivate(reason)
    RuntimeLog.Write("ACTION", "Interacting.Deactivate | reason=" .. tostring(reason or stateCrypto.stopReason or ""))
    RuntimeLog.State("interacting_deactivate_before_reset")
    stateCrypto.stopReason = nil
    Storage.FlushCollectLogStore()
    stateCrypto.work = false
    stateCrypto.waitFill = false
    stateCrypto.takeCount = 0
    stateCrypto.takeCurrency = nil
    stateCrypto.fillLiquidType = nil
    stateCrypto.fillLiquidLabel = nil
    stateCrypto.fillLiquidBefore = 0
    stateCrypto.fillLiquidAfter = 0
    RodinaCooling.ResetPending()
    RodinaCollect.Reset()
    stateCrypto.currentHouseId = nil
    stateCrypto.progressHouses = 0
    stateCrypto.queueHouses = {}
    stateCrypto.progressShelves = 0
    stateCrypto.queueShelves = {}
    processes.on = false
    processes.off = false
    processes.take = false
    processes.fill = false
    RuntimeLog.State("interacting_deactivate_after_reset")
end

-- --------------------------------------------------------
--                           Improve
-- --------------------------------------------------------

-- ===== ЛОГИ ЗАТОЧКИ / СТАТИСТИКА =====

-- запись одной строки в файл лога за текущий день: logs/YYYY-MM-DD.log
function Improve.WriteLogLine(line)
    if not (settings.main.typeChatMessage and settings.main.typeChatMessage.debug) then return end
    if not IMPROVE_LOGS_DIR or not line or line == "" then return end

    local filename = os.date('%Y-%m-%d') .. ".log"
    local fullPath = IMPROVE_LOGS_DIR .. filename

    local folderPath = fullPath:match("^(.*[/\\])")
    if folderPath then
        pcall(Util.EnsureDirectoryExists, folderPath)
    end

    local ok, fh = pcall(io.open, fullPath, "a")
    if ok and fh then
        fh:write(line, "\n")
        fh:close()
    end
end

-- загрузка/инициализация общей статистики из JSON
function Improve.GetStatsStore()
    if not IMPROVE_STATS_FILE then return nil end

    if not improve.statsStore then
        local ok, data = pcall(Storage.LoadJSON, IMPROVE_STATS_FILE)
        if not ok or type(data) ~= 'table' then
            data = {}
        end
        data.days = data.days or {}
        data.total = data.total or {
            sessions  = 0,
            attempts  = 0,
            success   = 0,
            fail      = 0,
            oilsUsed  = 0,
            byLevel   = {},
            time      = 0,
        }
        improve.statsStore = data
    end

    return improve.statsStore
end

-- сохранение статистики в JSON
function Improve.SaveStatsStore()
    if not IMPROVE_STATS_FILE or not improve.statsStore then return end
    pcall(Storage.SaveJSON, IMPROVE_STATS_FILE, improve.statsStore)
end

-- внутренняя функция добавления записи в лог
function Improve.GetLevelStatsTemplate()
    local t = {}
    for lvl = 1, 9 do
        t[lvl] = {
            attempts = 0,
            success = 0,
            fail = 0,
        }
    end
    return t
end

function Improve.EnsureLevelStats(statsObj)
    if type(statsObj) ~= 'table' then return end
    if type(statsObj.byLevel) ~= 'table' then
        statsObj.byLevel = Improve.GetLevelStatsTemplate()
    end
    for lvl = 1, 9 do
        local row = statsObj.byLevel[lvl]
        if type(row) ~= 'table' then
            statsObj.byLevel[lvl] = { attempts = 0, success = 0, fail = 0 }
        else
            row.attempts = tonumber(row.attempts or 0) or 0
            row.success  = tonumber(row.success  or 0) or 0
            row.fail     = tonumber(row.fail     or 0) or 0
        end
    end
end


function Improve.LogAdd(evType, text)
    if not improve.logs then
        improve.logs = { items = {}, max = 300, autoScroll = true }
    end

    local ts    = os.date('%d.%m.%Y %H:%M:%S')
    local ttype = evType or "INFO"
    local msg   = text or ""

    local line = string.format("[%s] [%s] %s", ts, ttype, msg)

    -- в память (для UI)
    table.insert(improve.logs.items, {
        ts   = ts,
        type = ttype,
        text = msg,
        step = improve.step,
    })

    local maxCount = improve.logs.max or 300
    while #improve.logs.items > maxCount do
        table.remove(improve.logs.items, 1)
    end

    -- опционально в консоль, если включён debug
    if settings.main.typeChatMessage and settings.main.typeChatMessage.debug then
        print("[IMPROVE] " .. line)
    end

    -- в файл по дате
    Improve.WriteLogLine(line)
end

-- старт сессии заточки
function Improve.SessionStart()
    Improve.GetStatsStore()

    local s = improve.stats or {}
    s.sessionId  = (s.sessionId or 0) + 1
    s.active     = true
    s.startedAt  = os.time()
    s.finishedAt = 0
    s.attempts   = 0
    s.success    = 0
    s.fail       = 0
    s.oilsUsed   = 0
    s.byLevel    = Improve.GetLevelStatsTemplate()
    s.lastAttempt = nil
    s.lastReason = ""
    improve.stats = s

    local modeName  = (settings.improve.mode == 1) and "Последовательное" or "Поочередное"
    local cardsName = "Rodina"
    local maxLevel  = settings.improve.maxLevel or 2
    local checkOils = settings.improve.checkOilsOnStart and "Да" or "Нет"
    local invMode   = Improve.GetInventoryModeName()

    Improve.LogAdd("INFO", string.format(
        "Старт сессии #%d. Карты: %s, режим: %s, инвентарь: %s, целевой уровень: %d, проверять смазку: %s.",
        s.sessionId, cardsName, modeName, invMode, maxLevel, checkOils
    ))
end

-- завершение сессии заточки + обновление суточной и общей статистики
function Improve.SessionStop(reason)
    local s = improve.stats
    if not s or not s.active then return end

    s.active     = false
    s.finishedAt = os.time()
    s.lastReason = reason or s.lastReason or "не указано"

    local duration = 0
    if s.startedAt and s.startedAt > 0 then
        duration = math.maxEx(0, s.finishedAt - s.startedAt)
    end

    -- Обновляем статистику по дням и общую
    local store = Improve.GetStatsStore()
    if store then
        Improve.EnsureLevelStats(store.total)
    end
    if store then
        local dayKey
        if s.startedAt and s.startedAt > 0 then
            dayKey = os.date('%Y-%m-%d', s.startedAt)
        else
            dayKey = os.date('%Y-%m-%d')
        end

        store.days = store.days or {}
        local day = store.days[dayKey] or {
            sessions  = 0,
            attempts  = 0,
            success   = 0,
            fail      = 0,
            oilsUsed  = 0,
            byLevel   = {},
            time      = 0,
        }
        Improve.EnsureLevelStats(day)

        day.sessions  = (day.sessions  or 0) + 1
        day.attempts  = (day.attempts  or 0) + (s.attempts or 0)
        day.success   = (day.success   or 0) + (s.success  or 0)
        day.fail      = (day.fail      or 0) + (s.fail     or 0)
        day.oilsUsed  = (day.oilsUsed  or 0) + (s.oilsUsed or 0)
        day.time      = (day.time      or 0) + duration
        Improve.EnsureLevelStats(s)
        for lvl = 1, 9 do
            local src = s.byLevel[lvl] or {}
            local dst = day.byLevel[lvl] or { attempts = 0, success = 0, fail = 0 }
            dst.attempts = (dst.attempts or 0) + (src.attempts or 0)
            dst.success  = (dst.success  or 0) + (src.success  or 0)
            dst.fail     = (dst.fail     or 0) + (src.fail     or 0)
            day.byLevel[lvl] = dst
        end

        store.days[dayKey] = day

        local total = store.total or {
            sessions  = 0,
            attempts  = 0,
            success   = 0,
            fail      = 0,
            oilsUsed  = 0,
            byLevel   = {},
            time      = 0,
        }
        Improve.EnsureLevelStats(total)

        total.sessions  = (total.sessions  or 0) + 1
        total.attempts  = (total.attempts  or 0) + (s.attempts or 0)
        total.success   = (total.success   or 0) + (s.success  or 0)
        total.fail      = (total.fail      or 0) + (s.fail     or 0)
        total.oilsUsed  = (total.oilsUsed  or 0) + (s.oilsUsed or 0)
        total.time      = (total.time      or 0) + duration
        for lvl = 1, 9 do
            local src = s.byLevel[lvl] or {}
            local dst = total.byLevel[lvl] or { attempts = 0, success = 0, fail = 0 }
            dst.attempts = (dst.attempts or 0) + (src.attempts or 0)
            dst.success  = (dst.success  or 0) + (src.success  or 0)
            dst.fail     = (dst.fail     or 0) + (src.fail     or 0)
            total.byLevel[lvl] = dst
        end

        store.total = total

        Improve.SaveStatsStore()
    end

    Improve.LogAdd("INFO", string.format(
        "Окончание сессии #%d (%s). Попыток: %d, успешных: %d, неудачных: %d, смазки потрачено: %d, длительность: %d сек.",
        s.sessionId or 0,
        s.lastReason,
        s.attempts or 0,
        s.success  or 0,
        s.fail     or 0,
        s.oilsUsed or 0,
        duration
    ))
end

function Improve.Stop(reason)
    Improve.CloseMobileStatusDialog(3600000)

    -- сначала аккуратно закрываем сессию
    Improve.SessionStop(reason or "остановлено вручную")

    -- потом чистим флаги автомата
    improve.isOn          = false
    improve.step          = Improve.STEP.STOPPED
    improve.needCheckOils = false
    improve.waitOils      = false
    improve.waitStart     = false
    improve.waitStartAt   = 0
    improve.waitResultAt  = 0
    improve.lastUseAt     = 0
    improve.consumedThisTry = false
    improve.resultHandled = false
    improve.currentIndex  = 0
    improve.currentSlot   = 0
    improve.cef.stubNotified = false
    improve.cef.needInventoryRefresh = true
    improve.cef.waitInventory = false
    improve.cef.probing = false
    improve.cef.probed = false
    improve.cef.pendingSlot = nil
    improve.cef.pendingIndex = 0
    improve.cef.probeAbort = false
    improve.cef.probeAbortReason = ''
    improve.cef.probeProgress = 0
    improve.cef.probeTotal = 0
end

function Improve.AttemptStart()
    improve.resultHandled = false
    local s = improve.stats
    if not (s and s.active) then return end

    s.attempts = (s.attempts or 0) + 1

    local idx = improve.currentIndex or 0
    local card = nil
    local wantedSlot = tonumber(improve.currentSlot or 0) or 0
    if wantedSlot > 0 then
        for i, v in ipairs(improve.videoCards or {}) do
            if tonumber(v.slot or 0) == wantedSlot then card = v; idx = i; improve.currentIndex = i; break end
        end
    else
        card = improve.videoCards[idx]
    end
    local level     = card and card.level or 0
    local fromLevel = tonumber(level or 0) or 0
    local toLevel   = fromLevel + 1

    s.lastAttempt = {
        fromLevel = fromLevel,
        toLevel = toLevel,
    }

    if fromLevel >= 1 and fromLevel <= 9 then
        Improve.EnsureLevelStats(s)
        local row = s.byLevel[fromLevel] or { attempts = 0, success = 0, fail = 0 }
        row.attempts = (row.attempts or 0) + 1
        s.byLevel[fromLevel] = row
    end

    Improve.LogAdd("INFO", string.format(
        "Попытка #%d: карта #%d, уровень %d.",
        s.attempts, idx, level
    ))
end

-- ===== БАЗОВАЯ ЛОГИКА =====

function Improve.GetOilCountByType()
    local count = tonumber(improve.oils.classic) or 0
    local name = improve.oils.known and 'Смазка для видеокарты' or 'Смазка для видеокарты (количество ещё не известно)'
    return count, name
end

function Improve.HasRequiredOils(n)
    -- Неизвестное количество не считаем нулём: sparse-пакет Rodina может прислать item без amount.
    -- Но как только точное количество известно, каждая реальная попытка обязана требовать 2 смазки
    -- независимо от чекбокса "Проверять смазку при старте".
    if not improve.oils.known then return true end
    return (tonumber(improve.oils.classic) or 0) >= (tonumber(n) or 2)
end

function Improve.ConsumeOils(n)
    n = tonumber(n) or 2
    if improve.stats and improve.stats.active then
        improve.stats.oilsUsed = (improve.stats.oilsUsed or 0) + n
    end
    Improve.LogAdd('INFO', string.format('Попытка потребует %d смазки; жду точное обновление item 3204 от сервера.', n))
end

function Improve.ResetOilCounters()
    improve.oils.classic = 0
    improve.oils.known = false
    improve.oils.slot = nil
end

function Improve.ParseInventoryDialogPage(text)
end

function Improve.RefreshOils(async)
    if improve.oils.busy then return false end
    improve.oils.busy = true
    Improve.LogAdd('INFO', 'Обновляю видеокарты и смазку через CEF-инвентарь Rodina.')
    local function run()
        local got = Improve.RequestInventoryDump(6)
        Improve.RebuildRodinaInventoryFromSlots()
        improve.oils.lastAt = os.date('%H:%M')
        improve.oils.busy = false
        Improve.LogOilsResult()
        if not got then
            Improve.LogAdd('WARN', 'CEF-инвентарь не прислал свежий пакет за таймаут; использую последний известный кэш.')
        end
    end
    if async then
        MMTCreateThread(run)
        return true
    end
    run()
    return true
end

function Improve.OilsWaitProcess()
    while improve.oils.busy do wait(10) end
end

function Improve.LogOilsResult()
    local oilText = improve.oils.known and tostring(improve.oils.classic or 0) or '?'
    Improve.LogAdd('INFO', string.format('CEF-инвентарь обновлён: смазка=%s, видеокарты=%d.', oilText, #(improve.cef.cards or {})))
    Improve.SyncVideoCardsFromCef()
    improve.cef.probed = false
end

-- Результат заточки (успех/ошибка) - обновляем уровень в кэше
function Improve.OnResult(success, serverMsg, forcedLevel)
    if not improve.currentIndex or improve.currentIndex <= 0 then return end

    local card = nil
    local wantedSlot = tonumber(improve.currentSlot or 0) or 0
    if wantedSlot > 0 then
        for i, v in ipairs(improve.videoCards or {}) do
            if tonumber(v.slot or 0) == wantedSlot then
                card = v
                improve.currentIndex = i
                break
            end
        end
    else
        card = improve.videoCards[improve.currentIndex]
    end
    if not card then return end
    local s = improve.stats

    local attemptedFrom = s and s.lastAttempt and tonumber(s.lastAttempt.fromLevel) or nil
        local oldLvl = attemptedFrom or tonumber(card.level) or 0
        local newLvl = oldLvl

        if success then
            local parsedLvl = tonumber(forcedLevel)
            if not parsedLvl and serverMsg then
                local lvlText = serverMsg:match("до%s+(%d+)%D+уров") or serverMsg:match("до%s+(%d+)%s+уровн")
                if lvlText then parsedLvl = tonumber(lvlText) end
            end
            local packetLvl = Improve.PacketLevelForSlot(card.slot, 1)
            if packetLvl and packetLvl > oldLvl then parsedLvl = packetLvl end
            if tonumber(card.level) and tonumber(card.level) > oldLvl then parsedLvl = tonumber(card.level) end
            newLvl = parsedLvl or (oldLvl + 1)
            if newLvl > 10 then newLvl = 10 end
            card.level = newLvl
            card.levelKnown = true
            Improve.UpdateCefCardLevel(card.slot, newLvl)
        end

        if s and s.active then
            if success then
                s.success = (s.success or 0) + 1
            else
                s.fail    = (s.fail or 0) + 1
            end

            local fromLevel = s.lastAttempt and tonumber(s.lastAttempt.fromLevel or 0) or 0
            if fromLevel >= 1 and fromLevel <= 9 then
                Improve.EnsureLevelStats(s)
                local row = s.byLevel[fromLevel] or { attempts = 0, success = 0, fail = 0 }
                if success then
                    row.success = (row.success or 0) + 1
                else
                    row.fail = (row.fail or 0) + 1
                end
                s.byLevel[fromLevel] = row
            end
            s.lastAttempt = nil
        end

        local attemptNo = s and s.attempts or 0
        if success then
            Improve.LogAdd("SUCCESS", string.format(
                "Попытка #%d: УСПЕХ. Карта #%d, уровень %d -> %d.",
                attemptNo, improve.currentIndex or 0, oldLvl, newLvl
            ))
        else
            Improve.LogAdd("WARN", string.format(
                "Попытка #%d: ОШИБКА. Карта #%d, уровень %d (без изменений).",
                attemptNo, improve.currentIndex or 0, oldLvl
            ))
        end

        -- Для режима "Последовательное" пересортируем по уровню
        if settings.improve.menuAll and settings.improve.mode == 1 then
            table.sort(improve.videoCards, function(a, b)
                return (a.level or 0) < (b.level or 0)
            end)
        end
        improve.videoCards = Improve.MoveMaxLevelCardsToEnd(improve.videoCards)
end

function Improve.MarkAttemptTimedOut()
    local s = improve.stats
    if not (s and s.active) then return end

    s.fail = (s.fail or 0) + 1

    local fromLevel = s.lastAttempt and tonumber(s.lastAttempt.fromLevel or 0) or 0
    if fromLevel >= 1 and fromLevel <= 9 then
        Improve.EnsureLevelStats(s)
        local row = s.byLevel[fromLevel] or { attempts = 0, success = 0, fail = 0 }
        row.fail = (row.fail or 0) + 1
        s.byLevel[fromLevel] = row
    end

    s.lastAttempt = nil
end

function Improve.TickWaitWatchdogs()
    if not improve.isOn then return end

    local now = os.clock()

    if improve.step == Improve.STEP.CONFIRM then
        local retryMs = tonumber(settings.deley.improve_retryUseDelay or 1200) or 1200
        if retryMs < 200 then retryMs = 200 end

        if not improve.waitStart then
            if (improve.lastUseAt or 0) <= 0 then
                improve.lastUseAt = now
            elseif (now - improve.lastUseAt) * 1000 >= retryMs then
                local idx = tonumber(improve.currentIndex or 0) or 0
                local card = improve.videoCards[idx]
                local slot = card and tonumber(card.slot or 0) or 0
                if slot > 0 then
                    Improve.OpenCardDialog(slot, 1, 1)
                    improve.lastUseAt = now
                else
                    improve.step = Improve.STEP.SELECT_CARD
                    improve.consumedThisTry = false
                    improve.lastUseAt = 0
                end
            end
        else
            local waitStartTimeout = tonumber(settings.deley.improve_waitStartTimeout or 8) or 8
            if waitStartTimeout < 1 then waitStartTimeout = 1 end
            local startedAt = tonumber(improve.waitStartAt or 0) or 0
            if startedAt > 0 and (now - startedAt) >= waitStartTimeout then
                Improve.LogAdd("WARN", string.format(
                    "Таймаут ожидания старта улучшения (%d сек). Возвращаюсь к выбору карты.",
                    waitStartTimeout
                ))
                improve.waitStart = false
                improve.waitStartAt = 0
                improve.step = Improve.STEP.SELECT_CARD
                improve.consumedThisTry = false
            end
        end
    elseif improve.step == Improve.STEP.WAIT_RESULT then
        local waitResultTimeout = tonumber(settings.deley.improve_waitResultTimeout or 20) or 20
        if waitResultTimeout < 1 then waitResultTimeout = 1 end
        local startedAt = tonumber(improve.waitResultAt or 0) or 0
        if startedAt > 0 and (now - startedAt) >= waitResultTimeout then
            Improve.LogAdd("WARN", string.format(
                "Таймаут ожидания результата улучшения (%d сек). Фиксирую попытку как неудачную и продолжаю.",
                waitResultTimeout
            ))
            Improve.MarkAttemptTimedOut()
            improve.waitResultAt = 0
            improve.step = Improve.STEP.SELECT_CARD
            improve.consumedThisTry = false
        end
    end
end

-- Шаговая машина состояний
function Improve.Tick()
    if not improve.isOn then return end

    Improve.TickWaitWatchdogs()
    if improve.waitOils then return end -- Ждем смазки

    Improve.TickNewStyle()
end


-- --------------------------------------------------------
--                           Load
-- --------------------------------------------------------

-- Сообщения о повреждённых файлах копятся до старта main(): Chat.Add работает
-- только после загрузки настроек, а Settings.json читается самым первым
Storage.brokenFilesNotice = {}

function Storage.NoticeBrokenFile(message)
    print("[MMT] "..tostring(message))
    table.insert(Storage.brokenFilesNotice, tostring(message))
end

--- Выводит накопленные предупреждения в чат. Вызывается из main()
function Storage.FlushBrokenFilesNotice()
    if #Storage.brokenFilesNotice == 0 then return end

    for _, message in ipairs(Storage.brokenFilesNotice) do
        Chat.Add(message, TYPECHATMESSAGES.WARNING)
    end
    Storage.brokenFilesNotice = {}
end

--- Убирает нечитаемый файл в сторону, чтобы скрипт стартовал с чистого листа,
--- а сам файл остался для разбора
function Storage.QuarantineBrokenFile(filePatch, reason)
    local _broken = filePatch..".broken"
    os.remove(_broken)

    if not os.rename(filePatch, _broken) then
        os.remove(filePatch)
        _broken = nil
    end

    Storage.NoticeBrokenFile(string.format("Файл %s повреждён (%s).%s",
        filePatch, tostring(reason),
        _broken and (" Копия для разбора: ".._broken) or " Файл удалён."))
end

--- Читает и разбирает JSON.
--- @return table|nil data Данные файла
--- @return string|nil reason Причина, если файл есть, но не читается.
---         nil в обоих значениях - файла просто нет или он пустой, это не ошибка
function Storage.ReadJSONFile(filePatch)
    local _file = io.open(filePatch, "rb")
    if not _file then return nil, nil end

    local _content = _file:read("*a")
    _file:close()

    if not _content or not _content:match("%S") then return nil, nil end

    -- блокнот и подобные редакторы дописывают BOM, cjson на нём падает
    if _content:sub(1, 3) == "\239\187\191" then
        _content = _content:sub(4)
        if not _content:match("%S") then return nil, nil end
    end

    local _ok, _data = pcall(json.decode, _content)

    if not _ok then
        -- из "MMT.lua:4040: текст ошибки" оставляем только текст
        local _reason = tostring(_data)
        _reason = _reason:gsub("^.-:%d+:%s*", "")
        return nil, _reason
    end

    if type(_data) ~= "table" then return nil, "внутри не объект JSON" end

    return _data, nil
end

--- Битый файл не должен ронять весь скрипт. Обычно он получается, когда игра падает
--- во время записи: размер файла Windows уже увеличила, а данные сбросить не успела,
--- и внутри остаются нули - cjson отвечает на них
--- "JSON parser does not support UTF-16 or UTF-32" и бросает ошибку наружу.
function Storage.LoadJSON(filePatch)
    local _data, _reason = Storage.ReadJSONFile(filePatch)
    if _data then return _data end
    if not _reason then return {} end

    Storage.QuarantineBrokenFile(filePatch, _reason)

    -- рядом лежит предыдущее удачное сохранение - шанс не потерять логи
    local _backup = Storage.ReadJSONFile(filePatch..".bak")
    if _backup then
        Storage.NoticeBrokenFile(string.format("Данные восстановлены из %s.bak", filePatch))
        return _backup
    end

    return {}
end

function Storage.LoadSettings()
    local _settings = Storage.LoadJSON(PATCHCONFIG..'Settings.json')
    if not _settings then
        _settings = {}
    end
    -- до версии 2 Telegram включался одной общей галочкой и списком config
    local oldNotify = type(_settings.notifications) == 'table' and _settings.notifications.version == nil
        and _settings.notifications or nil
    local oldEnabled = oldNotify and oldNotify.enabled == true
    local oldConfig = oldNotify and type(oldNotify.config) == 'table' and oldNotify.config or nil

    -- сливаем настройки с дефолтными
    Storage.MergeSettings(_settings, defaultSettings)

    if oldNotify then
        for kind in pairs(_settings.notifications.tg) do
            _settings.notifications.tg[kind] = oldEnabled and (oldConfig == nil or oldConfig[kind] ~= false)
        end
        _settings.notifications.enabled = nil
        _settings.notifications.config = nil
    end

    -- Rodina-only: оставляем только ключи, которые существуют в текущей схеме настроек.
    -- Пустые таблицы в defaults считаются динамическими контейнерами и сохраняются целиком.
    local function pruneUnknown(dest, schema)
        if type(dest) ~= 'table' or type(schema) ~= 'table' then return end
        for key, value in pairs(dest) do
            local schemaValue = schema[key]
            if schemaValue == nil then
                dest[key] = nil
            elseif type(value) == 'table' and type(schemaValue) == 'table' and next(schemaValue) ~= nil then
                pruneUnknown(value, schemaValue)
            end
        end
    end
    pruneUnknown(_settings, defaultSettings)

    -- Rodina: хранилище видеокарт максимум 9 BTC, поэтому порог выше 9 бессмысленен.
    _settings.main.maxCollectAlert = math.minEx(9, math.maxEx(1, tonumber(_settings.main.maxCollectAlert) or 9))

    settings = _settings
    return _settings
end

function Storage.MergeSettings(dest, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if not dest[key] then
                dest[key] = {}
            end
            Storage.MergeSettings(dest[key], value)
        else
            if dest[key] == nil then
                dest[key] = value
            end
        end
    end
end

Storage.LoadSettings()

-- NeoMLoader 0.1.6: window dragging stays disabled, but finger scrolling is
-- enabled again experimentally. Previous native crashes were later traced to
-- command dispatch / LuaThreadInterface handling, not to the scroll routine.
if ISNEOMLOADER then
    settings.style.swipeScroll = true
    ui_state.swipe.active = false
    ui_state.swipe.is_gesture = false
    ui_state.swipe.start_x = nil
    ui_state.swipe.start_y = nil
    ui_state.drag.active = false
    print("[MMT-R] NeoMLoader detected: finger scroll enabled; window drag disabled")
end

RuntimeLog.SetEnabled(settings.main.typeChatMessage and settings.main.typeChatMessage.debug == true, true)

if ISMONETLOADER and settings.style.scaleUI ~= 1.0 then
    MONET_DPI_SCALE = settings.style.scaleUI
elseif ISMONETLOADER then
    settings.style.scaleUI = MONET_DPI_SCALE
end

-- --------------------------------------------------------
--                           Save
-- --------------------------------------------------------

--- Пишет JSON через временный файл и подменяет им основной. Прямая запись в основной
--- файл оставляла после падения игры обрезанный или забитый нулями JSON, из-за чего
--- скрипт потом не стартовал. Предыдущее сохранение остаётся рядом как .bak.
function Storage.SaveJSON(filePatch, data)
    local folderPath = string.match(filePatch, "^(.*[/\\])")
    if folderPath then
        Util.EnsureDirectoryExists(folderPath)
    end

    -- кодируем до открытия файла: ошибка кодирования не должна обнулять то,
    -- что уже лежит на диске
    local _ok, _encoded = pcall(json.encode, data)
    if not _ok or type(_encoded) ~= "string" then
        print("[MMT] Не удалось закодировать "..filePatch..": "..tostring(_encoded))
        return false
    end

    local _tempPatch = filePatch..".tmp"
    local _file = io.open(_tempPatch, "wb")
    if not _file then return false end

    local _written = pcall(_file.write, _file, _encoded)
    _file:close()

    if not _written then
        os.remove(_tempPatch)
        return false
    end

    -- прошлую версию не удаляем, а отводим в .bak: если игра упадёт между
    -- переименованиями, данные останутся хотя бы в одном из двух файлов
    local _backupPatch = filePatch..".bak"
    os.remove(_backupPatch)
    os.rename(filePatch, _backupPatch)

    if not os.rename(_tempPatch, filePatch) then
        -- подменить не вышло: возвращаем прошлую версию на место
        os.rename(_backupPatch, filePatch)
        os.remove(_tempPatch)
        print("[MMT] Не удалось заменить "..filePatch.." новой версией")
        return false
    end

    return true
end

function Storage.SaveSettings()
    local success = Storage.SaveJSON(PATCHCONFIG .. 'Settings.json', settings)
    if not success then
        print("Ошибка: Не удалось сохранить настройки!")
    end
end

function Storage.LoadCollectLogStore()
    local data = Storage.LoadJSON(COLLECT_STATS_FILE)
    if type(data) ~= "table" then
        collectLogStore = {
            days = {},
            meta = {}
        }
        return
    end

    data.days = type(data.days) == "table" and data.days or {}
    data.meta = type(data.meta) == "table" and data.meta or {}

    if type(data.meta.lastCollect) ~= "table" then
        data.meta.lastCollect = nil
    end

    collectLogStore = data

    if Collect.TrimLogStoreDetails() then
        Storage.SaveCollectLogStore()
    end
end

function Storage.SaveCollectLogStore()
    collectLogStore.days = collectLogStore.days or {}
    collectLogStore.meta = collectLogStore.meta or {}
    local success = Storage.SaveJSON(COLLECT_STATS_FILE, collectLogStore)
    if success then
        collectLogSave.dirty = false
        collectLogSave.lastAt = os.clock()
    end
    return success
end

function Storage.RequestSaveCollectLogStore(force)
    collectLogSave.dirty = true
    local now = os.clock()
    if force or (now - (collectLogSave.lastAt or 0)) >= (collectLogSave.minInterval or 2) then
        return Storage.SaveCollectLogStore()
    end
    return false
end

function Storage.FlushCollectLogStore()
    if collectLogSave.dirty then
        return Storage.SaveCollectLogStore()
    end
    return true
end

function Collect.GetMaxLogItemsPerHouseDay()
    local value = tonumber(settings.main and settings.main.collectLogMaxItemsPerHouseDay or 300) or 300
    return math.maxEx(0, math.floor(value))
end

function Collect.TrimHouseLogItems(houseData, maxItems)
    if type(houseData) ~= 'table' or type(houseData.items) ~= 'table' then
        return false
    end

    local items = houseData.items
    maxItems = tonumber(maxItems) or 0
    if maxItems <= 0 then
        local removed = #items
        if removed <= 0 then return false end
        houseData.items = {}
        houseData.itemsTrimmed = (tonumber(houseData.itemsTrimmed) or 0) + removed
        return true
    end

    local count = #items
    if count <= maxItems then
        return false
    end

    local removed = count - maxItems
    local trimmedItems = {}
    local startIndex = removed + 1
    for i = startIndex, count do
        table.insert(trimmedItems, items[i])
    end
    houseData.items = trimmedItems
    houseData.itemsTrimmed = (tonumber(houseData.itemsTrimmed) or 0) + removed
    return true
end

function Collect.TrimLogStoreDetails()
    local maxItems = Collect.GetMaxLogItemsPerHouseDay()
    local changed = false
    for _, dayData in pairs(collectLogStore.days or {}) do
        for _, houseData in pairs((dayData and dayData.houses) or {}) do
            if Collect.TrimHouseLogItems(houseData, maxItems) then
                changed = true
            end
        end
    end
    return changed
end

function Collect.NormalizeCryptoAmount(amount)
    amount = tonumber(amount) or 0
    return math.floor(amount * 1000 + 0.5) / 1000
end

function Collect.GetLastCollectInfo()
    local meta = collectLogStore.meta or {}
    local info = meta.lastCollect
    if type(info) ~= "table" then return nil end

    local timestamp = tonumber(info.timestamp or 0) or 0
    if timestamp <= 0 then return nil end

    info.timestamp = timestamp
    info.amount = Collect.NormalizeCryptoAmount(info.amount)
    info.houseId = tostring(info.houseId or "0")
    info.currency = tostring(info.currency or "BTC")
    return info
end

function Collect.UpdateLastCollectInfo(houseId, currency, amount)
    collectLogStore.meta = collectLogStore.meta or {}
    collectLogStore.meta.lastCollect = {
        timestamp = os.time(),
        houseId = tostring(houseId or 0),
        currency = tostring(currency or "BTC"),
        amount = Collect.NormalizeCryptoAmount(amount),
    }
    Collect.GameState('crypto').retryAt = 0
end

function Collect.GetReminderThresholdSeconds()
    local minutes = tonumber(settings.main and settings.main.collectNotifyMinutes or 0) or 0
    if minutes <= 0 then
        return 0
    end
    return math.floor(minutes * 60)
end

function Collect.FormatDuration(seconds)
    seconds = math.maxEx(0, math.floor(tonumber(seconds) or 0))
    local days = math.floor(seconds / 86400)
    seconds = seconds % 86400
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60

    if days > 0 then
        return string.format("%d д. %02d:%02d:%02d", days, hours, minutes, secs)
    end
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%02d:%02d", minutes, secs)
end

function Collect.FormatLastCollectText(info)
    if type(info) ~= "table" then
        return "ещё не зафиксирован"
    end

    local timestamp = tonumber(info.timestamp or 0) or 0
    if timestamp <= 0 then
        return "ещё не зафиксирован"
    end

    return os.date('%d.%m.%Y %H:%M:%S', timestamp)
end

function Collect.GetNotifySystemState()
    local state = {
        available = false,
        ready = false,
        installed = false,
        running = false,
        compatible = false,
        canInstall = false,
        message = "Система уведомлений недоступна.",
    }

    if not notifySuccess or type(notify) ~= 'table' then
        state.message = "Библиотека session_notifications не установлена."
        return state
    end

    state.available = true
    state.canInstall = type(notify.ensure_manager) == 'function'

    if type(notify.status) == 'function' then
        local ok, status = pcall(notify.status, REQUIRED_NOTIFY_VERSION)
        if ok and type(status) == 'table' then
            state.installed = not not status.installed
            state.running = not not status.running
            state.compatible = not not status.compatible
            state.ready = state.installed and state.running and state.compatible and type(notify.send) == 'function'

            if not state.installed then
                state.message = "Система уведомлений не установлена."
            elseif not state.running then
                state.message = "Менеджер уведомлений найден, но не запущен."
            elseif not state.compatible then
                state.message = "Менеджер уведомлений требует обновления."
            else
                state.message = "Система уведомлений готова."
            end

            return state
        end
    end

    state.ready = type(notify.send) == 'function'
    state.installed = state.ready
    state.running = state.ready
    state.compatible = state.ready
    state.message = state.ready and "Система уведомлений готова." or "Система уведомлений недоступна."
    return state
end

function Collect.GetNotifyInstallButtonText(state)
    if type(state) ~= 'table' then
        return "Открыть страницу установки"
    end
    if not state.available then
        return "Открыть страницу установки"
    end
    if not state.installed then
        return "Установить менеджер уведомлений"
    end
    if not state.running then
        return "Запустить менеджер уведомлений"
    end
    if not state.compatible then
        return "Обновить менеджер уведомлений"
    end
    return "Подготовить менеджер уведомлений"
end

function Collect.DownloadNotificationSystem()
    if collectReminder.managerDownloadPending or collectReminder.managerEnsurePending then
        return false
    end

    collectReminder.managerDownloadPending = true
    collectReminder.managerStatusMessage = "Скачиваю менеджер уведомлений и библиотеку..."

    MMTCreateThread(function()
        local function fail(message, debugInfo)
            collectReminder.managerDownloadPending = false
            collectReminder.managerStatusMessage = message
            Chat.Add(message, TYPECHATMESSAGES.WARNING)
            if debugInfo and debugInfo ~= "" then
                Chat.Add('Уведомления: ' .. tostring(debugInfo), TYPECHATMESSAGES.DEBUG)
            end
        end

        local okRequests, requests = pcall(require, 'requests')
        if not okRequests or type(requests) ~= 'table' or type(requests.get) ~= 'function' then
            fail("Не удалось скачать систему уведомлений.", okRequests and 'requests.get недоступен' or requests)
            return
        end

        local function download_text(url)
            local ok, response = pcall(function()
                return requests.get(url, {
                    headers = {
                        ['Accept-Encoding'] = 'identity',
                        ['Connection'] = 'close'
                    },
                    timeout = 20
                })
            end)

            if not ok or type(response) ~= 'table' then
                return nil, tostring(response or 'ошибка requests')
            end
            if not tonumber(response.status_code) or response.status_code < 200 or response.status_code >= 300 then
                return nil, 'HTTP ' .. tostring(response.status_code or 'unknown')
            end
            return tostring(response.text or ''), nil
        end

        local managerText, managerErr = download_text(NOTIFY_MANAGER_RAW_URL)
        if not managerText or managerText == '' then
            fail("Не удалось скачать менеджер уведомлений.", managerErr)
            return
        end

        local libraryText, libraryErr = download_text(NOTIFY_LIBRARY_RAW_URL)
        if not libraryText or libraryText == '' then
            fail("Не удалось скачать библиотеку уведомлений.", libraryErr)
            return
        end

        local managerPath = getWorkingDirectory() .. SEPORATORPATCH .. 'NotificationManager.lua'
        local libraryPath = getWorkingDirectory() .. SEPORATORPATCH .. 'lib' .. SEPORATORPATCH .. 'session_notifications.lua'

        local okSaveManager, saveManagerErr = pcall(function()
            local file = assert(io.open(managerPath, 'w'))
            file:write(managerText)
            file:close()
        end)
        if not okSaveManager then
            fail("Не удалось сохранить менеджер уведомлений.", saveManagerErr)
            return
        end

        local okSaveLibrary, saveLibraryErr = pcall(function()
            Util.EnsureDirectoryExists(getWorkingDirectory() .. SEPORATORPATCH .. 'lib')
            local file = assert(io.open(libraryPath, 'w'))
            file:write(libraryText)
            file:close()
        end)
        if not okSaveLibrary then
            fail("Не удалось сохранить библиотеку уведомлений.", saveLibraryErr)
            return
        end

        collectReminder.managerDownloadPending = false
        collectReminder.managerStatusMessage = "Система уведомлений скачана. Перезагружаю скрипт..."
        Chat.Add("Менеджер уведомлений и библиотека скачаны. Перезагружаю скрипт", TYPECHATMESSAGES.SUCCESS)

        wait(300)
        thisScript():reload()
    end)

    return true
end

function Collect.EnsureNotificationManager()
    if collectReminder.managerEnsurePending or collectReminder.managerDownloadPending then
        return false
    end

    local state = Collect.GetNotifySystemState()
    if not state.available or type(notify) ~= 'table' or type(notify.ensure_manager) ~= 'function' then
        collectReminder.managerStatusMessage = "Открыта страница установки менеджера уведомлений."
        Util.OpenUrl(NOTIFY_MANAGER_REPO_URL)
        Chat.Add("Открыта страница установки менеджера уведомлений", TYPECHATMESSAGES.SECONDARY)
        return true
    end

    collectReminder.managerEnsurePending = true
    collectReminder.managerStatusMessage = "Подготавливаю менеджер уведомлений..."

    notify.ensure_manager({ required_version = REQUIRED_NOTIFY_VERSION }, function(success, info)
        collectReminder.managerEnsurePending = false
        if success then
            collectReminder.managerStatusMessage = "Менеджер уведомлений готов к работе."
            Chat.Add("Менеджер уведомлений готов к работе", TYPECHATMESSAGES.SUCCESS)
            return
        end

        collectReminder.managerStatusMessage = "Не удалось подготовить менеджер уведомлений. Перезапустите игру или перезагрузите все скрипты."
        Chat.Add("Не удалось подготовить менеджер уведомлений. Перезапустите игру или перезагрузите все скрипты.", TYPECHATMESSAGES.WARNING)
        Chat.Add(
            'Менеджер уведомлений: ' .. tostring(info and info.message or 'неизвестная ошибка'),
            TYPECHATMESSAGES.DEBUG
        )
    end)

    return true
end

-- Состояние напоминаний в игре по событиям
function Collect.GameState(kind)
    collectReminder.game = collectReminder.game or {}
    local st = collectReminder.game[kind]
    if not st then
        st = { notifiedAt = 0, retryAt = 0, pending = false }
        collectReminder.game[kind] = st
    end
    return st
end

Collect.GAME_TITLES = {
    crypto = 'Пора собирать крипту',
}

-- Напоминание в игре: всплывающее окно менеджера уведомлений, без него - сообщение в чат
function Collect.SendReminderNotification(kind, lastAt, elapsedSeconds)
    local st = Collect.GameState(kind)
    local title = Collect.GAME_TITLES[kind] or 'Пора собирать'
    local text = 'С последнего сбора прошло ' .. Collect.FormatDuration(elapsedSeconds) .. '.'
    local description = 'Последний сбор: ' .. os.date('%d.%m.%Y %H:%M:%S', lastAt)

    local function toChat()
        st.notifiedAt = lastAt
        Chat.Add(title .. '. ' .. text .. ' ' .. description, TYPECHATMESSAGES.WARNING)
    end

    if not (notifySuccess and type(notify) == 'table' and type(notify.send) == 'function') then
        toChat()
        return
    end

    st.pending = true
    notify.send(REQUIRED_NOTIFY_VERSION, {
        script_id = 'MMT',
        title = u8(title),
        text = u8(text),
        description = u8(description),
        sticky = true,
        theme = 'emerald',
        action = nil,
    }, function(success, notifyInfo)
        st.pending = false
        if success then
            st.notifiedAt = lastAt
            st.retryAt = 0
            return
        end
        -- менеджер уведомлений не принял - напоминание всё равно не теряем
        toChat()
        Chat.Add('Менеджер уведомлений: ' .. tostring(notifyInfo and notifyInfo.message or 'неизвестная ошибка'),
            TYPECHATMESSAGES.DEBUG)
    end)
end

function Collect.KindEnabled(kind)
    return kind == 'crypto'
end

function Collect.ReminderTick()
    local nowClock = os.clock()
    if (nowClock - (collectReminder.lastTickAt or 0)) < 1 then
        return
    end
    collectReminder.lastTickAt = nowClock

    local now = os.time()
    for _, kind in ipairs(Collect.TG_KINDS) do
        local id = kind.id
        if Collect.KindEnabled(id) and settings.notifications.game[id] then
            local st = Collect.GameState(id)
            local lastAt, minutes = Collect.TgReminderSource(id)
            if not st.pending and now >= st.retryAt and minutes > 0 and lastAt > 0
                and st.notifiedAt ~= lastAt
                and (now - lastAt) >= minutes * 60
                and not Collect.TgKindBusy(id)
            then
                Collect.SendReminderNotification(id, lastAt, now - lastAt)
            end
        end
    end
end

-- ===== Уведомления в Telegram =====
-- Два способа, как в MCR ПК: свой бот (api.telegram.org) или бот MCR Notification
-- (API MCR, нужен ключ MCR). Запросы уходят из отдельного effil-потока, чтобы игра
-- не подвисала; ответы забирает фоновый цикл через Collect.TgTick().

collectReminder.tg = {
    worker = nil,
    reqCh = nil,
    resCh = nil,
    initError = nil,
    pending = 0,
    tickAt = -1000,
    retryAt = {},              -- [вид] = os.time(), раньше которого не повторяем
    keyCache = nil,
    keySource = '',
    keyCheckedAt = -1000,
    keyEdit = false,
    buf = {},
    lastResult = '',
}

Collect.TG_KINDS = {
    { id = 'crypto', label = 'Пора собирать крипту', short = 'Крипта' },
}

-- Где лежит интервал напоминания для события
Collect.REMINDER_MINUTES = {
    crypto = { 'main', 'collectNotifyMinutes' },
}

Collect.TG_MCR_URLS = {
    'https://api.arz-mcr.ru/v1/bot/notifications',
    'https://api.arz-mcr.top/v1/bot/notifications',
}

function Collect.TgTrim(s)
    local r = tostring(s or ''):gsub('^%s+', '')
    r = r:gsub('%s+$', '')
    return r
end

function Collect.TgReadFile(path)
    local ok, fh = pcall(io.open, path, 'rb')
    if not ok or not fh then return nil end
    local data = fh:read('*a')
    fh:close()
    return data
end

-- Ключ MCR: свой из настроек MMT, иначе из MCR ПК, иначе из MLoader
function Collect.TgGetKey()
    local tg = collectReminder.tg
    local own = Collect.TgTrim(settings.notifications.mcrKey)
    if own ~= '' then
        return own, 'MMT'
    end

    if (os.clock() - tg.keyCheckedAt) < 30 and tg.keyCache ~= nil then
        return tg.keyCache, tg.keySource
    end
    tg.keyCheckedAt = os.clock()
    tg.keyCache, tg.keySource = '', ''

    local base = getWorkingDirectory() .. SEPORATORPATCH
    local mcrKey = Collect.TgTrim(Collect.TgReadFile(base .. 'MCR' .. SEPORATORPATCH .. 'config' .. SEPORATORPATCH .. 'UserKey-DontShare.key'))
    if #mcrKey >= 16 then
        tg.keyCache, tg.keySource = mcrKey, 'MCR ПК'
        return tg.keyCache, tg.keySource
    end

    local ini = Collect.TgReadFile(base .. 'config' .. SEPORATORPATCH .. 'mloader.ini') or ''
    local loaderKey = ''
    for line in ini:gmatch('[^\r\n]+') do
        local v = line:match('^%s*key%s*=%s*(.-)%s*$')
        if v then
            local unquoted = v:gsub('^"(.*)"$', '%1')
            loaderKey = Collect.TgTrim(unquoted)
            break
        end
    end
    if #loaderKey >= 16 then
        tg.keyCache, tg.keySource = loaderKey, 'MLoader'
    end
    return tg.keyCache, tg.keySource
end

-- Ключ целиком не показываем: только первые и последние два символа
function Collect.TgMaskKey(key)
    key = tostring(key or '')
    if #key <= 4 then return string.rep('*', #key) end
    return key:sub(1, 2) .. string.rep('*', #key - 4) .. key:sub(-2)
end

-- Почему отправка сейчас невозможна (nil - всё заполнено)
function Collect.TgConfigProblem()
    local cfg = settings.notifications
    if tonumber(cfg.methodBot) == 2 then
        if Collect.TgTrim(cfg.mcrChatId) == '' then return 'не указан ваш ID для бота MCR Notification' end
        if Collect.TgGetKey() == '' then return 'не найден ключ MCR' end
        return nil
    end
    if Collect.TgTrim(cfg.botToken) == '' then return 'не указан токен своего бота' end
    if Collect.TgTrim(cfg.chatId) == '' then return 'не указан ID чата' end
    return nil
end

function Collect.TgInitWorker()
    local tg = collectReminder.tg
    if tg.worker then return true end
    if tg.initError then return false end

    local ok, err = pcall(function()
        local effil = require('effil')
        tg.reqCh = effil.channel()
        tg.resCh = effil.channel()
        tg.worker = effil.thread(function(reqCh, resCh)
            local requests = require('requests')
            while true do
                local id, method, url, body, isJson = reqCh:pop()
                if id == nil then return end
                local headers = { ['User-Agent'] = 'mmt' }
                if isJson then
                    headers['Content-Type'] = 'application/json'
                    headers['Content-Length'] = tostring(#body)
                end
                local okReq, res = pcall(requests.request, method, url, {
                    headers = headers,
                    data = (body ~= '') and body or nil,
                    timeout = 15,
                })
                if okReq and type(res) == 'table' then
                    resCh:push(id, tonumber(res.status_code) or 0, tostring(res.text or ''))
                else
                    resCh:push(id, 0, tostring(res))
                end
            end
        end)(tg.reqCh, tg.resCh)
    end)

    if not ok then
        tg.worker = nil
        tg.initError = tostring(err)
        Chat.Add('Telegram: не удалось запустить отправку (' .. tg.initError .. ')', TYPECHATMESSAGES.WARNING)
        return false
    end
    return true
end

-- Отправить текст. kind - вид уведомления ('test' для тестового сообщения)
function Collect.TgSend(text, kind)
    local problem = Collect.TgConfigProblem()
    if problem then
        return false, problem
    end
    if not Collect.TgInitWorker() then
        return false, 'нет библиотеки effil/requests'
    end

    local cfg = settings.notifications
    local plain = tostring(text or ''):gsub('{%x%x%x%x%x%x}', '')
    local clean = u8(plain)

    local task = { kind = kind or 'test', text = clean, urlIndex = 1 }
    if tonumber(cfg.methodBot) == 2 then
        local key = Collect.TgGetKey()
        task.isJson = true
        task.body = json.encode({
            telegram_id = Collect.TgTrim(cfg.mcrChatId),
            key_user = key,
            message = clean,
        })
    else
        local encoded = clean:gsub('([^%w%-_%.~])', function(c)
            return string.format('%%%02X', string.byte(c))
        end)
        task.url = string.format('https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s',
            Collect.TgTrim(cfg.botToken), Collect.TgTrim(cfg.chatId), encoded)
    end

    Collect.TgPush(task)
    return true
end

function Collect.TgPush(task)
    local tg = collectReminder.tg
    tg.tasks = tg.tasks or {}
    tg.seq = (tg.seq or 0) + 1
    tg.tasks[tg.seq] = task
    tg.pending = tg.pending + 1
    local url = task.url or (task.urls or Collect.TG_MCR_URLS)[task.urlIndex]
    tg.reqCh:push(tg.seq, 'POST', url, task.body or '', task.isJson == true)
end

function Collect.TgHandleResult(id, status, text)
    local tg = collectReminder.tg
    local task = tg.tasks and tg.tasks[id]
    if not task then return end
    tg.tasks[id] = nil
    tg.pending = math.maxEx(0, tg.pending - 1)

    -- сеть или сервер MCR недоступны - пробуем зеркало
    local urls = task.urls or Collect.TG_MCR_URLS
    if task.isJson and (status == 0 or status >= 500) and task.urlIndex < #urls then
        task.urlIndex = task.urlIndex + 1
        Collect.TgPush(task)
        return
    end

    if status >= 200 and status < 300 then
        tg.lastResult = os.date('%H:%M:%S') .. ' - сообщение отправлено'
        return
    end

    local raw = tostring(text or ''):sub(1, 150)
    local okDecode, detail = pcall(u8.decode, u8, raw)
    if not okDecode then detail = raw end
    local reason = (status == 0) and ('нет связи: ' .. detail) or string.format('ошибка %d: %s', status, detail)
    tg.lastResult = os.date('%H:%M:%S') .. ' - не отправлено, ' .. reason

    if task.kind ~= 'test' then
        -- напоминание не дошло: разрешаем повторить его позже
        settings.notifications.sent[task.kind] = nil
        -- ошибка настроек (4xx) сама не пройдёт - не шумим каждые 5 минут
        tg.retryAt[task.kind] = os.time() + ((status >= 400 and status < 500) and 1800 or 300)
        Chat.Add('Telegram: уведомление не отправлено (' .. reason .. ')', TYPECHATMESSAGES.WARNING)
    end
end

-- Время последнего сбора и порог напоминания (в минутах) для вида уведомления
function Collect.TgReminderSource(kind)
    if kind ~= 'crypto' then return 0, 0 end
    local info = Collect.GetLastCollectInfo()
    return info and info.timestamp or 0, tonumber(settings.main.collectNotifyMinutes) or 0
end

function Collect.TgKindBusy(kind)
    if kind ~= 'crypto' then return false end
    return stateCrypto.work and processes.take
end

function Collect.TgNickname()
    local ok, res, id = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
    if not (ok and res) then return '' end
    local okNick, nick = pcall(sampGetPlayerNickname, id)
    return (okNick and nick) and tostring(nick) or ''
end

function Collect.TgReminderText(kind, lastAt, elapsed)
    local head = '[MMT-R]'
    local passed = Collect.FormatDuration(elapsed)
    local lastText = os.date('%d.%m.%Y %H:%M', lastAt)
    return string.format('%s\nПора собирать крипту: с последнего сбора прошло %s.\nПоследний сбор: %s', head, passed, lastText)
end

-- Состояние таймера для окна настроек
function Collect.TgReminderStatus(kind)
    local cfg = settings.notifications
    if not (cfg.game[kind] or cfg.tg[kind]) then return 'выключено' end
    local lastAt, minutes = Collect.TgReminderSource(kind)
    if minutes <= 0 then return 'интервал 0 - выключено' end
    if lastAt <= 0 then return 'после первого сбора' end
    local remain = minutes * 60 - (os.time() - lastAt)
    if remain > 0 then return 'через ' .. Collect.FormatDuration(remain) end
    local sentGame = cfg.game[kind] and Collect.GameState(kind).notifiedAt == lastAt
    local sentTg = cfg.tg[kind] and tonumber(cfg.sent[kind]) == lastAt
    if sentGame or sentTg then return 'отправлено' end
    return 'время истекло'
end

-- Вызывается из фонового цикла
function Collect.TgTick()
    local tg = collectReminder.tg
    if tg.resCh then
        local id, status, text = tg.resCh:pop(0)
        while id ~= nil do
            Collect.TgHandleResult(id, tonumber(status) or 0, text)
            id, status, text = tg.resCh:pop(0)
        end
    end

    local nowClock = os.clock()
    if (nowClock - tg.tickAt) < 5 then return end
    tg.tickAt = nowClock

    local cfg = settings.notifications
    local anyOn = false
    for _, kind in ipairs(Collect.TG_KINDS) do
        if Collect.KindEnabled(kind.id) and cfg.tg[kind.id] then anyOn = true end
    end
    if not anyOn or tg.initError or Collect.TgConfigProblem() then return end

    local now = os.time()
    for _, kind in ipairs(Collect.TG_KINDS) do
        local id = kind.id
        local lastAt, minutes = Collect.TgReminderSource(id)
        if Collect.KindEnabled(id) and cfg.tg[id] and minutes > 0 and lastAt > 0
            and tonumber(cfg.sent[id]) ~= lastAt
            and (now - lastAt) >= minutes * 60
            and now >= (tg.retryAt[id] or 0)
            and not Collect.TgKindBusy(id)
        then
            cfg.sent[id] = lastAt
            Storage.SaveSettings()
            Collect.TgSend(Collect.TgReminderText(id, lastAt, now - lastAt), id)
        end
    end
end

-- Поток отправки живёт вне скрипта: при выгрузке MMT его нужно погасить,
-- иначе после каждого /mmtr остаётся лишний поток
function Collect.TgShutdown()
    local tg = collectReminder.tg
    if tg.worker then
        pcall(function() tg.worker:cancel(0) end)
        tg.worker = nil
    end
end

function onScriptTerminate(scr)
    if scr == thisScript() then
        Collect.TgShutdown()
    end
end

-- Старые логи без lastCollectAt: берём последний день, в котором что-то собрано
function Collect.LastCollectFromDays(days)
    local best = 0
    for _, d in pairs(days or {}) do
        if type(d) == 'table' and type(d.collected) == 'table' and next(d.collected) ~= nil then
            best = math.maxEx(best, tonumber(d.updatedAt) or 0)
        end
    end
    return best
end

-- ===== Расширенная сводка сбора =====

-- Читаемые названия оборудования на полке
Collect.CARD_TYPE_LABELS = {
    BTC = "Видеокарты",
}

function Collect.NewSummary(source)
    return {
        source = source or "manual",
        startedAt = os.time(),
        finishedAt = 0,
        houses = {},
        houseCount = 0,
        shelvesVisited = 0,
        shelvesCollected = 0,
        cardsEnabled = 0,
        byLevel = {},
        byType = {},
        typeOrder = {},
        lastCollectedKey = nil,
        maxTake = { count = 0, currency = nil, level = 0, house = nil },
    }
end

-- Ячейка статистики по уровню видеокарты (0 = уровень не распознан)
function Collect.LevelBucket(summary, level)
    level = math.maxEx(0, math.floor(tonumber(level) or 0))
    local bucket = summary.byLevel[level]
    if not bucket then
        bucket = { visited = 0, collected = 0, BTC = 0 }
        summary.byLevel[level] = bucket
    end
    return bucket
end

-- Ячейка статистики по типу оборудования
function Collect.TypeBucket(summary, cardType)
    cardType = tostring(cardType or "BTC")
    local bucket = summary.byType[cardType]
    if not bucket then
        bucket = { visited = 0, collected = 0, BTC = 0 }
        summary.byType[cardType] = bucket
        table.insert(summary.typeOrder, cardType)
    end
    return bucket
end

-- Полка, которую скрипт взял в обработку
function Collect.SummaryVisit(shelfData)
    local summary = collectStats.summary
    if not (summary and processes.take and type(shelfData) == 'table') then return end

    local level = tonumber(shelfData.level) or 0
    summary.shelvesVisited = summary.shelvesVisited + 1

    local lvlBucket = Collect.LevelBucket(summary, level)
    lvlBucket.visited = lvlBucket.visited + 1

    local typeBucket = Collect.TypeBucket(summary, shelfData.card_type)
    typeBucket.visited = typeBucket.visited + 1

    local hid = stateCrypto.currentHouseId
    if hid ~= nil and not summary.houses[tostring(hid)] then
        summary.houses[tostring(hid)] = true
        summary.houseCount = summary.houseCount + 1
    end
end

-- Фактическая BTC-выплата с полки
function Collect.SummaryTake(shelfData, currency, amount)
    local summary = collectStats.summary
    if not summary then return end

    amount = tonumber(amount) or 0
    if amount <= 0 or currency ~= "BTC" then return end

    local level = (type(shelfData) == 'table') and shelfData.level or 0
    local cardType = (type(shelfData) == 'table') and shelfData.card_type or nil
    local lvlBucket = Collect.LevelBucket(summary, level)
    local typeBucket = Collect.TypeBucket(summary, cardType)

    lvlBucket[currency] = (lvlBucket[currency] or 0) + amount
    typeBucket[currency] = (typeBucket[currency] or 0) + amount

    local key = tostring(stateCrypto.currentHouseId) .. "#" .. tostring(stateCrypto.progressShelves)
    if summary.lastCollectedKey ~= key then
        summary.lastCollectedKey = key
        summary.shelvesCollected = summary.shelvesCollected + 1
        lvlBucket.collected = lvlBucket.collected + 1
        typeBucket.collected = typeBucket.collected + 1
    end

    if amount > (summary.maxTake.count or 0) then
        summary.maxTake = {
            count = amount,
            currency = currency,
            level = tonumber(level) or 0,
            house = stateCrypto.currentHouseId,
        }
    end
end

-- Скрипт сам включил простаивавшую видеокарту
function Collect.SummaryCardEnabled()
    local summary = collectStats.summary
    if summary and processes.take then
        summary.cardsEnabled = summary.cardsEnabled + 1
    end
end

-- Длинные перечисления бьём на строки, чтобы чат не резал текст
function Collect.PrintChunks(prefix, parts, perLine, chatType)
    local buffer = {}
    for _, part in ipairs(parts) do
        table.insert(buffer, part)
        if #buffer >= perLine then
            Chat.Add(prefix .. table.concat(buffer, "; "), chatType)
            buffer = {}
            prefix = string.rep(" ", 0)
        end
    end
    if #buffer > 0 then
        Chat.Add(prefix .. table.concat(buffer, "; "), chatType)
    end
end

function Collect.PrintSummary()
    local summary = collectStats.summary
    if not summary then return end
    if not settings.main.showCollectSummary then return end
    if summary.shelvesVisited <= 0 then return end

    summary.finishedAt = os.time()

    local btc = Collect.NormalizeCryptoAmount(collectStats.total.BTC or 0)
    local duration = Collect.FormatDuration(summary.finishedAt - summary.startedAt)
    local sourceLabel = "ручной запуск"

    Chat.Add(string.format(
        "Сводка сбора (%s): домов %d, видеокарт %d, время %s",
        sourceLabel, summary.houseCount, summary.shelvesVisited, duration
    ), TYPECHATMESSAGES.SUCCESS)

    Chat.Add(string.format(
        "Собрано: %s | с выплатой %d из %d полок",
        tostring(btc) .. " BTC", summary.shelvesCollected, summary.shelvesVisited
    ), TYPECHATMESSAGES.SECONDARY)

    -- Уровни видеокарт: сколько обработано и сколько с них снято
    local levels = {}
    for level in pairs(summary.byLevel) do table.insert(levels, level) end
    table.sort(levels, function(a, b) return a > b end)

    local levelParts = {}
    for _, level in ipairs(levels) do
        local bucket = summary.byLevel[level]
        local gains = {}
        if (bucket.BTC or 0) > 0 then
            table.insert(gains, Collect.NormalizeCryptoAmount(bucket.BTC) .. " BTC")
        end
        table.insert(levelParts, string.format(
            "%s - %d шт%s",
            (level > 0) and (level .. " ур.") or "ур. ?",
            bucket.visited,
            (#gains > 0) and (" (" .. table.concat(gains, ", ") .. ")") or ""
        ))
    end
    if #levelParts > 0 then
        Collect.PrintChunks("Уровни видеокарт: ", levelParts, 3, TYPECHATMESSAGES.SECONDARY)
    end

    -- Типы оборудования
    local typeParts = {}
    for _, cardType in ipairs(summary.typeOrder) do
        local bucket = summary.byType[cardType]
        table.insert(typeParts, string.format(
            "%s - %d шт",
            Collect.CARD_TYPE_LABELS[cardType] or cardType,
            bucket.visited
        ))
    end
    if #typeParts > 1 then
        Collect.PrintChunks("Типы: ", typeParts, 3, TYPECHATMESSAGES.SECONDARY)
    end

    -- Дома, по убыванию собранного
    local houseIds = {}
    for houseId in pairs(collectStats.house or {}) do table.insert(houseIds, houseId) end
    table.sort(houseIds, function(a, b)
        local sa = collectStats.house[a] or {}
        local sb = collectStats.house[b] or {}
        return (sa.BTC or 0) > (sb.BTC or 0)
    end)
    local houseParts = {}
    for _, houseId in ipairs(houseIds) do
        local st = collectStats.house[houseId]
        if (st.BTC or 0) > 0 then
            table.insert(houseParts, string.format("дом %s: %s BTC", tostring(houseId), Collect.NormalizeCryptoAmount(st.BTC)))
        end
    end
    if #houseParts > 0 then
        Collect.PrintChunks("По домам: ", houseParts, 3, TYPECHATMESSAGES.SECONDARY)
    end

    local extra = {}
    local skipped = summary.shelvesVisited - summary.shelvesCollected
    if skipped > 0 then
        table.insert(extra, string.format("без выплаты: %d", skipped))
    end
    if summary.cardsEnabled > 0 then
        table.insert(extra, string.format("включено видеокарт: %d", summary.cardsEnabled))
    end
    if (summary.maxTake.count or 0) > 0 then
        table.insert(extra, string.format(
            "лучшая полка: %s %s%s",
            tostring(Collect.NormalizeCryptoAmount(summary.maxTake.count)),
            tostring(summary.maxTake.currency or ""),
            ((summary.maxTake.level or 0) > 0) and (" / " .. summary.maxTake.level .. " ур.") or ""
        ))
    end
    if #extra > 0 then
        Collect.PrintChunks("Детали: ", extra, 2, TYPECHATMESSAGES.SECONDARY)
    end
end

function Collect.AddLogEntry(houseId, currency, amount)
    houseId = tostring(houseId or 0)
    currency = tostring(currency or "BTC")
    amount = Collect.NormalizeCryptoAmount(amount)
    if amount <= 0 then return end

    local dateKey = os.date('%Y-%m-%d')
    local timeKey = os.date('%H:%M:%S')

    collectLogStore.days[dateKey] = collectLogStore.days[dateKey] or {
        total = { BTC = 0 },
        houses = {}
    }

    local dayData = collectLogStore.days[dateKey]
    dayData.total[currency] = (dayData.total[currency] or 0) + amount
    dayData.houses[houseId] = dayData.houses[houseId] or {
        total = { BTC = 0 },
        items = {}
    }

    local houseData = dayData.houses[houseId]
    houseData.total[currency] = (houseData.total[currency] or 0) + amount
    table.insert(houseData.items, {
        time = timeKey,
        currency = currency,
        amount = amount,
    })
    Collect.TrimHouseLogItems(houseData, Collect.GetMaxLogItemsPerHouseDay())

    Collect.UpdateLastCollectInfo(houseId, currency, amount)
    Storage.RequestSaveCollectLogStore(false)
end

Storage.LoadCollectLogStore()


-- --------------------------------------------------------
--                           Parsers
-- --------------------------------------------------------

-- Хранилище запомненных уровней видеокарт
function Storage.LoadCardLevels()
    local ok, data = pcall(Storage.LoadJSON, CARD_LEVELS_FILE)
    if not ok or type(data) ~= "table" then data = {} end
    cardLevels.slots = (type(data.slots) == "table") and data.slots or {}
end

function Storage.SaveCardLevels()
    local ok, res = pcall(Storage.SaveJSON, CARD_LEVELS_FILE, { slots = cardLevels.slots })
    if ok and res then
        cardLevels.dirty = false
        cardLevels.lastSaveAt = os.clock()
        return true
    end
    return false
end

function Storage.RequestSaveCardLevels(force)
    cardLevels.dirty = true
    local now = os.clock()
    if force or (now - (cardLevels.lastSaveAt or 0)) >= 2 then
        return Storage.SaveCardLevels()
    end
    return false
end

Storage.LoadCardLevels()


function Parser.HouseData(text)
    houses = {}
    local results = {}

    local function trim(value)
        local result = tostring(value or ""):gsub("^%s+", "")
        result = result:gsub("%s+$", "")
        return result
    end

    local function splitTabs(line)
        local parts = {}
        for part in tostring(line or ""):gmatch("[^\t]+") do
            table.insert(parts, trim(part))
        end
        return parts
    end

    local lineIndex = 0
    for line in text:gmatch("[^\r\n]+") do
        lineIndex = lineIndex + 1
        local cols = splitTabs(line)
        if #cols >= 4 and cols[1]:find("%[") then
            local firstCol = cols[1]
            local city = trim(cols[#cols - 2] or "")
            local tax = tonumber((tostring(cols[#cols - 1] or ""):match("(%d+)%D*$")))
            local energyCol = trim(cols[#cols] or "")
            local houseNum = firstCol:match("(%d+)%s*$")
            local cycles = tonumber((energyCol:match("(%d+)") or ""))

            if houseNum and city ~= "" and cycles and not CheckHouseInBlackList(houseNum) then
                table.insert(results, {
                    samp_line = lineIndex - 2,
                    house_number = tonumber(houseNum),
                    city = city,
                    tax = tax or 0,
                    cycles = cycles,
                    raw_line = line
                })
            end
        end
    end
    return results
end
function Parser.ShelfData(text)
    shelves = {}
    housesData[stateCrypto.activeHouseID] = { work_vc = 0, max_collect = 0, min_liquid = 0 }
    local house_data = housesData[tostring(stateCrypto.activeHouseID)]
    local results = {}
    local lines = {}

    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local pattern = "Полка №(%d+)%s*|%s*{(%w+)}([^%d]+)([%d%.]+)%s+BTC%s+(%d+)%s+уровень%s+([%d%.]+)"
    for lineIndex, line in ipairs(lines) do
        for shelfNum, colorCode, status, profit, level, percentage in string.gmatch(line, pattern) do
            local p = tonumber(profit) or 0
            local fill = tonumber(percentage) or 0
            local cleanStatus = status:gsub("^%s+", ""):gsub("%s+$", "")
            table.insert(results, {
                shelf_number = tonumber(shelfNum),
                samp_line = lineIndex - 2,
                status = cleanStatus,
                color_code = colorCode,
                profit = p,
                profit_primary = p,
                currency = "BTC",
                level = tonumber(level),
                percentage = fill,
                card_type = "BTC",
                raw_line = line
            })
            house_data = {
                work_vc = house_data.work_vc + ((cleanStatus:find("Работает") and 1) or 0),
                max_collect = p > house_data.max_collect and p or house_data.max_collect,
                min_liquid = house_data.min_liquid == 0 and fill or (fill < house_data.min_liquid and fill or house_data.min_liquid),
            }
        end
    end
    housesData[stateCrypto.activeHouseID] = house_data
    return results
end
function Parser.ShelfVideoCardData(text)
    local results = {}
    local lines = {}

    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local patterns = {
        {pater = "Запустить видеокарту", action = "on"},
        {pater = "Остановить видеокарту", action = "off"},
        {pater = "Забрать прибыль %(([%d%.]+) BTC%)", action = "take_btc"},
        {pater = "Залить охлаждающую жидкость", action = "fill"},
        {pater = "Достать видеокарту", action = "take_video_card"},
    }

    -- Проходим по каждой строке и ищем полки
    for lineIndex, line in ipairs(lines) do
        for _, pattern in ipairs(patterns) do
            for countCrypto in string.gmatch(line, pattern.pater) do
                local _countInt = math.floor(tonumber(countCrypto) or 0)
                table.insert(results, {
                    action = pattern.action,
                    count = _countInt,
                    samp_line = lineIndex - 1
                })
            end
        end
    end

    return results
end


-- --------------------------------------------------------
--                           Message
-- --------------------------------------------------------

function Chat.Add(message, type)
    RuntimeLog.Write("CHAT", string.format("type=%s | %s", tostring(type), tostring(message)))
    local _scriptName = "MMT"
    local _pref = "[ ".._scriptName.." ]"
    if type then
        if type == TYPECHATMESSAGES.SUCCESS then _pref = "[ :true: ".._scriptName.." ]" end
        if type == TYPECHATMESSAGES.SECONDARY then _pref = "[ :paperclip: ".._scriptName.." ]" end
        if type == TYPECHATMESSAGES.WARNING then _pref = "[ :warning: ".._scriptName.." ]" end
        if type == TYPECHATMESSAGES.CRITICAL then _pref = "[ :sos: ".._scriptName.." ]" end

        if type == TYPECHATMESSAGES.DEBUG then _pref = "[ :symbols: ".._scriptName.." ]"
            if not settings.main.typeChatMessage.debug then return end end
    end

    if settings.main.typeChatMessage.messages then
        sampAddChatMessage(_pref..': {FFFFFF}'..tostring(message), settings.style.colorMessage)
    end
    if settings.main.typeChatMessage.debug then
        print("["..Util.GetTimeNow().."]: "..message)
    end
end

-- --------------------------------------------------------
--                           Imgui
-- --------------------------------------------------------

local neoUiTogglePending = nil
local neoUiTraceFrames = 0
local neoInteractionPending = nil

function UI.NeoNowMs()
    if type(getGameTimer) == 'function' then
        local ok, value = pcall(getGameTimer)
        if ok and tonumber(value) then return tonumber(value) end
    end
    return math.floor(os.clock() * 1000)
end

function UI.NeoTrace(stage)
    if not ISNEOMLOADER or (tonumber(neoUiTraceFrames) or 0) <= 0 then return end
    print("[MMT-R][NEOUI] " .. tostring(stage))
end

function UI.SwitchMainWindow()
    imguiWindows.main[0] = not imguiWindows.main[0]
end

function UI.RequestMainWindowToggle(source)
    if not ISNEOMLOADER then
        UI.SwitchMainWindow()
        return
    end

    neoUiTogglePending = {
        target = not imguiWindows.main[0],
        requestedAt = UI.NeoNowMs(),
        source = tostring(source or 'unknown'),
        chatWasActive = false,
    }
    print(string.format(
        "[MMT-R][NEOUI] toggle queued | source=%s target=%s",
        neoUiTogglePending.source, tostring(neoUiTogglePending.target)
    ))
end

function UI.ProcessPendingMainWindowToggle()
    local req = neoUiTogglePending
    if not req then return end

    local now = UI.NeoNowMs()
    local chatActive = false
    if type(sampIsChatInputActive) == 'function' then
        local ok, active = pcall(sampIsChatInputActive)
        chatActive = ok and active == true
    end

    if chatActive then
        req.chatWasActive = true
        return
    end

    -- Give Android/Neo one extra beat after chat closes. In the crash reports
    -- the last event is ACTION_UP from submitting /mmt, so no ImGui state is
    -- changed until that native input path has finished.
    local minDelay = req.chatWasActive and 250 or 450
    if (now - (tonumber(req.requestedAt) or now)) < minDelay then return end

    imguiWindows.main[0] = req.target == true
    neoUiTogglePending = nil
    neoUiTraceFrames = imguiWindows.main[0] and 3 or 0

    print(string.format(
        "[MMT-R][NEOUI] toggle applied | open=%s delay=%dms",
        tostring(imguiWindows.main[0]), math.max(0, now - (tonumber(req.requestedAt) or now))
    ))
end

function UI.StartInteractionSafe(action, source)
    if not ISNEOMLOADER then
        return Interacting.Start(action, source)
    end

    if neoInteractionPending or stateCrypto.work or Interacting.IsActive() then
        Chat.Add("Процесс уже запущен", TYPECHATMESSAGES.WARNING)
        return false
    end

    neoInteractionPending = {
        action = tostring(action or ""),
        source = tostring(source or "neo_ui"),
        requestedAt = UI.NeoNowMs(),
    }
    print("[MMT-R][NEOACT] queued | action=" .. tostring(action))
    return true
end

function UI.ProcessPendingInteraction()
    local req = neoInteractionPending
    if not req then return end

    -- Не запускаем/создаём Lua thread внутри кадра ImGui и в том же ACTION_UP,
    -- которым была нажата кнопка.
    local now = UI.NeoNowMs()
    if (now - (tonumber(req.requestedAt) or now)) < 180 then return end

    neoInteractionPending = nil
    print("[MMT-R][NEOACT] starting | action=" .. tostring(req.action))
    Interacting.Start(req.action, req.source)
end

function UI.Scale(num)
    return ISMONETLOADER and num*MONET_DPI_SCALE or num*imgui.GetIO().FontGlobalScale
end

-- Устанавливаем масштаб UI
function UI.SetScale()
    local _scale = settings.style.scaleUI
    imgui.GetIO().FontGlobalScale = 1.0*_scale  -- Увеличит UI
    imgui.GetStyle().ScrollbarSize = settings.style.scrollbarSizeStyle  -- Установить размер скроллбара
    imgui.GetIO().DisplayFramebufferScale = imgui.ImVec2(1.0*_scale, 1.0*_scale)  -- Увеличение для HD экранов
end

-- Буфер для строк
local function buf_set(buf, str)
    str = tostring(str or "")
    local n = math.minEx(#str, ffi.sizeof(buf) - 1)
    ffi.copy(buf, str, n)
    buf[n] = 0
end

-- Формат «10,000,000»


function imgui.GetMiddleButtonX(count)
    local width = imgui.GetWindowContentRegionWidth()
    local space = imgui.GetStyle().ItemSpacing.x
    return (count == 1) and width or (width / count - ((space * (count - 1)) / count))
end

-- =====================================================================================================================
--                                                          UTLITES
-- =====================================================================================================================

-- Получить текущее время в формате %H:%M:%S
function Util.GetTimeNow()
    return os.date('%H:%M:%S')
end

function Util.OpenUrl(url)
    if MONET_VERSION then
        local gta = ffi.load('GTASA')
        ffi.cdef[[
            void _Z12AND_OpenLinkPKc(const char* link);
        ]]
    	gta._Z12AND_OpenLinkPKc(url)
	else
		os.execute("explorer " .. url)
	end
end

function Util.GetCommaValue(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

-- Округление до n знаков (по умолчанию 2)
function Util.Round(x, n)
    n = n or 2
    local m = 10^n
    return math.floor((x or 0) * m + 0.5) / m
end

function UI.ImGuiKeyPressed(keyConst)
    local ok, pressed = pcall(function() return imgui.IsKeyPressed(keyConst, false) end)
    return ok and pressed
end

function UI.IsEnterPressed()
    -- пробуем ImGui Enter
    if UI.ImGuiKeyPressed(imgui.Key.Enter) then return true end
    -- системная клавиша Enter
    if isKeyJustPressed then
        local ok, pressed = pcall(isKeyJustPressed, VK_RETURN)
        if ok and pressed then return true end
    end
    return false
end

-- current  - текущий индекс (1..max)
-- max      - количество элементов
-- onEnter  - при нажатии Enter на текущем элементе
function UI.HandleListNavigation(current, max, onEnter)
    if max <= 0 or not settings.main.arrowsMove or not IsArrowNavigationAvailable() then return current end

    if imgui.IsWindowFocused(imgui.FocusedFlags.RootAndChildWindows)
       and not imgui.IsAnyItemActive() then

        local newIndex = current

        -- Вверх: ImGui или фолбэк через VK_UP
        if UI.ImGuiKeyPressed(imgui.Key.UpArrow) or (isKeyJustPressed and isKeyJustPressed(VK_UP)) then
            newIndex = (current > 1) and (current - 1) or max
        end

        -- Вниз: ImGui или фолбэк через VK_DOWN
        if UI.ImGuiKeyPressed(imgui.Key.DownArrow) or (isKeyJustPressed and isKeyJustPressed(VK_DOWN)) then
            newIndex = (current < max) and (current + 1) or 1
        end

        current = newIndex

        -- Enter (без KeypadEnter)
        if UI.IsEnterPressed() and onEnter then
            onEnter(current)
        end
    end

    return current
end

-- =====================================================================================================================
--                                                          INGUI FRAMES
-- =====================================================================================================================

local mainFrame = imgui.OnFrame( function() return imguiWindows.main[0] end, function(player)
    UI.NeoTrace("frame_enter")

    if settings.main.replaceDialog then
        imgui.SetNextWindowPos(imgui.ImVec2(sizeScreanX/ 2, sizeScreanY / 2), imgui.Cond.Appearing, imgui.ImVec2(0.5, 0.5))
    else
        imgui.SetNextWindowPos(imgui.ImVec2(sizeScreanX, sizeScreanY / 2), imgui.Cond.Appearing, imgui.ImVec2(1, 0.5))
    end
    UI.NeoTrace("after_next_pos")

    -- если мы уже когда-то двигали окно - задаём позицию на этот кадр
    if windowPos then
        imgui.SetNextWindowPos(windowPos, imgui.Cond_Always)
    end

    imgui.SetNextWindowSize(imgui.ImVec2(settings.style.sizeWindow.x, settings.style.sizeWindow.y), imgui.Cond.Appearing)
    UI.NeoTrace("after_next_size")

    local mainWindowFlags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar
    if ISNEOMLOADER or settings.style.swipeScroll then
        -- Neo: finger scrolling is allowed, but moving the whole window by touch
        -- stays disabled. This isolates scrolling from the old window-drag path.
        mainWindowFlags = mainWindowFlags + imgui.WindowFlags.NoMove
    end

    UI.NeoTrace("before_begin")
    imgui.Begin(u8("Main Window"), imguiWindows.main, mainWindowFlags)
    UI.NeoTrace("after_begin")

        imgui.MoveOnTitleBar()
        UI.NeoTrace("after_move_helper")

        if settings.style.sizeWindow.x ~= imgui.GetWindowSize().x or settings.style.sizeWindow.y ~= imgui.GetWindowSize().y then
            settings.style.sizeWindow.x = imgui.GetWindowSize().x
            settings.style.sizeWindow.y = imgui.GetWindowSize().y
            Storage.SaveSettings()
        end

        UI.NeoTrace("before_header")
        if imgui.Button("Boosty") then
            Util.OpenUrl("https://boosty.to/sand-mcr")
        end
        UI.NeoTrace("after_boosty")
        imgui.SameLine()
        imgui.CenterText("[MMT Rodina] Mining Tool v"..thisScript().version)
        UI.NeoTrace("after_center_title")
        imgui.SameLine()

        local _icon = fa.CIRCLE_XMARK
        if imgui.RightButton("\t".._icon.."\t") then
            UI.SwitchMainWindow()
            Interacting.Deactivate()
            sampSendDialogResponse(lastIDDialog, 0, 0, "")
            shelves = {}
            houses = {}
        end

        UI.NeoTrace("after_close_button")
        imgui.Separator()

        UI.NeoTrace("before_tabs")
        local _widthButtons = (imgui.GetWindowWidth() - UI.Scale(36)) / 4
        if imgui.ButtonClickable(activeTabScript ~= "main", u8"Основное", imgui.ImVec2(_widthButtons, 0)) then activeTabScript = "main" end
        imgui.SameLine()
        if imgui.ButtonClickable(activeTabScript ~= "logs", u8"Логи", imgui.ImVec2(_widthButtons, 0)) then
            activeTabScript = "logs"
            Storage.LoadCollectLogStore()
        end
        imgui.SameLine()
        if imgui.ButtonClickable(activeTabScript ~= "improve", u8"Улучшить", imgui.ImVec2(_widthButtons, 0)) then activeTabScript = "improve" end
        imgui.SameLine()
        if imgui.ButtonClickable(activeTabScript ~= "settings", u8"Настройки", imgui.ImVec2(-1, 0)) then activeTabScript = "settings" end

        UI.NeoTrace("after_tabs")
        imgui.Separator()

        UI.NeoTrace("before_content_" .. tostring(activeTabScript))
        if activeTabScript == "main" then
            Draw.MainMenu()
        elseif activeTabScript == "logs" then
            Draw.CollectLogs()
        elseif activeTabScript == "improve" then
            Draw.ImproveSharp()
        elseif activeTabScript == "settings" then
            Draw.Settings()
        end
        UI.NeoTrace("after_content_" .. tostring(activeTabScript))
    imgui.End()
    UI.NeoTrace("after_end")

    if ISNEOMLOADER and (tonumber(neoUiTraceFrames) or 0) > 0 then
        neoUiTraceFrames = neoUiTraceFrames - 1
    end
end)


-- =====================================================================================================================
--                                                          DRAWS
-- =====================================================================================================================

-- =====================================================================================================================
--                                                          COMMON UI HELPERS
-- =====================================================================================================================

-- Цвет заполнения по настройкам: свободно / наполовину / почти полная
function Draw.FillColor(now, max)
    local pct = ((tonumber(max) or 0) > 0) and (now / max * 100) or 0
    if pct >= 90 then return UI.Vec4('barFullColor') end
    if pct >= 50 then return UI.Vec4('barHalfColor') end
    return UI.Vec4('barFreeColor')
end

-- Палитра столбиков графика в логах
function Draw.GraphColors()
    return imgui.GetColorU32Vec4(UI.Vec4('graphBgColor')),
           imgui.GetColorU32Vec4(UI.Vec4('graphBarColor')),
           imgui.GetColorU32Vec4(UI.Vec4('graphActiveColor')),
           imgui.GetColorU32Vec4(UI.Vec4('textColor'))
end

-- Подпись слева, полоса заполнения "N / M" справа - в одну строку
function Draw.FillBar(label, labelWidth, now, max, color)
    now, max = tonumber(now) or 0, tonumber(max) or 0
    local frac = (max > 0) and math.minEx(1.0, now / max) or 0
    local startX = imgui.GetCursorPosX()
    imgui.Text(u8(tostring(label)))
    imgui.SameLine()
    imgui.SetCursorPosX(startX + labelWidth)
    imgui.PushStyleColor(imgui.Col.PlotHistogram, color or Draw.FillColor(now, max))
    imgui.ProgressBar(frac, imgui.ImVec2(-1, imgui.GetTextLineHeight()), u8(string.format("%d / %d", now, max)))
    imgui.PopStyleColor()
end

-- Строка склада: название слева, количество справа (чётные строки подсвечены)
function Draw.WareRow(index, name, count, hexColor)
    local value = Util.GetCommaValue(math.floor(tonumber(count) or 0))
    local startX = imgui.GetCursorPosX()
    local width = imgui.GetWindowContentRegionWidth()
    local pos = imgui.GetCursorScreenPos()

    if (index % 2) == 0 then
        local h = imgui.GetTextLineHeightWithSpacing()
        imgui.GetWindowDrawList():AddRectFilled(
            imgui.ImVec2(pos.x - UI.Scale(3), pos.y - UI.Scale(1)),
            imgui.ImVec2(pos.x + width + UI.Scale(3), pos.y + h - UI.Scale(2)),
            imgui.GetColorU32Vec4(imgui.ImVec4(1.0, 1.0, 1.0, 0.04)))
    end

    local col = hexColor and HexToVec4(hexColor) or nil
    local gap = UI.Scale(6)
    local valueW = imgui.CalcTextSize(value).x
    local avail = math.maxEx(UI.Scale(20), width - valueW - gap * 2)

    -- Длинные названия (например, "Вода для полива грядок") режем, чтобы не сталкиваться с числом
    local label = tostring(name)
    local labelU = u8(label)
    local labelW = imgui.CalcTextSize(labelU).x
    local truncated = labelW > avail
    if truncated then
        while #label > 1 and imgui.CalcTextSize(u8(label .. "...")).x > avail do
            label = label:sub(1, #label - 1)
        end
        labelU = u8(label .. "...")
        labelW = imgui.CalcTextSize(labelU).x
    end

    if col then imgui.TextColored(col, labelU) else imgui.Text(labelU) end
    if truncated and imgui.IsItemHovered() then imgui.SetTooltip(u8(tostring(name))) end

    -- Соединяем название и количество тонкой линией, чтобы глаз не терял строку
    local leaderFrom = pos.x + labelW + gap
    local leaderTo = pos.x + width - valueW - gap
    if leaderTo - leaderFrom > UI.Scale(8) then
        local y = pos.y + imgui.GetTextLineHeight() * 0.65
        imgui.GetWindowDrawList():AddLine(
            imgui.ImVec2(leaderFrom, y), imgui.ImVec2(leaderTo, y),
            imgui.GetColorU32Vec4(imgui.ImVec4(1.0, 1.0, 1.0, 0.14)), UI.Scale(1))
    end

    imgui.SameLine()
    imgui.SetCursorPosX(startX + width - valueW)
    if col then imgui.TextColored(col, value) else imgui.Text(value) end
end

-- Заголовок блока склада с отметкой, когда данные были получены
function Draw.WareTitle(wareAt)
    wareAt = tonumber(wareAt) or 0
    if wareAt <= 0 then
        return "Содержимое склада"
    end
    return string.format("Содержимое склада (на %s)", os.date('%H:%M:%S', wareAt))
end

-- Заголовок списка по центру + разделитель
-- Строка настройки цвета: свотч + название, изменение применяется сразу
function Draw.ColorEditRow(label, key, withAlpha)
    local color = settings.style[key]
    if type(color) ~= 'table' then return end

    local buf = new.float[4]({ color.r or 0, color.g or 0, color.b or 0, color.a or 1.0 })
    local changed
    if withAlpha then
        changed = imgui.ColorEdit4(u8(label) .. "##style_" .. key, buf,
            imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.AlphaPreview)
    else
        changed = imgui.ColorEdit3(u8(label) .. "##style_" .. key, buf)
    end

    if changed then
        color.r, color.g, color.b = buf[0], buf[1], buf[2]
        if withAlpha then color.a = buf[3] end
        UI.ApplyColors()
        ui_state.colorsDirty = true
    end
end

function Draw.SectionTitle(text)
    local label = u8(tostring(text))
    local startX = imgui.GetCursorPosX()
    imgui.SetCursorPosX(startX + math.maxEx(0, (imgui.GetWindowContentRegionWidth() - imgui.CalcTextSize(label).x) / 2))
    imgui.Text(label)
    imgui.Separator()
end

-- Список "имя -> количество" с устойчивым порядком (по убыванию количества)
function Draw.AmountList(map, emptyText, hexColor)
    local names = {}
    for name, value in pairs(map or {}) do
        if (tonumber(value) or 0) > 0 then table.insert(names, name) end
    end
    if #names == 0 then
        imgui.TextDisabled(u8(emptyText))
        return
    end
    table.sort(names, function(a, b)
        local va, vb = tonumber(map[a]) or 0, tonumber(map[b]) or 0
        if va ~= vb then return va > vb end
        return tostring(a) < tostring(b)
    end)
    for i, name in ipairs(names) do
        Draw.WareRow(i, name, map[name], hexColor)
    end
end

-- Журнал действий под сворачиваемым заголовком
function Draw.Journal(id, logs)
    logs = logs or {}
    if #logs == 0 then return end
    imgui.Spacing()
    if imgui.CollapsingHeader(u8(string.format("Журнал действий (%d)", #logs)) .. "##" .. id .. "_journal") then
        -- занимаем всю оставшуюся высоту, но не меньше 100 px
        local height = math.maxEx(UI.Scale(100), imgui.GetContentRegionAvail().y)
        imgui.BeginChild(id .. "_journal_body", imgui.ImVec2(-1, height), true)
        imgui.ScrollMouse()
        for _, entry in ipairs(logs) do
            if type(entry) == "table" then
                imgui.TextDisabled(u8(tostring(entry.time or "")))
                imgui.SameLine()
                imgui.Text(u8(tostring(entry.text or "")))
            else
                imgui.Text(u8(tostring(entry)))
            end
        end
        imgui.EndChild()
    end
end

function Draw.MainMenu()
    local lastCollectInfo = Collect.GetLastCollectInfo()
    if lastCollectInfo then
        imgui.Text(u8("Последний сбор: " .. Collect.FormatLastCollectText(lastCollectInfo)))
    else
        imgui.TextDisabled(u8"Последний сбор: ещё не зафиксирован.")
    end

    imgui.SameLine()

    local thresholdSeconds = Collect.GetReminderThresholdSeconds()
    if thresholdSeconds > 0 then
        if lastCollectInfo then
            local elapsedSeconds = math.maxEx(0, os.time() - (lastCollectInfo.timestamp or 0))
            local remainSeconds = thresholdSeconds - elapsedSeconds
            if remainSeconds > 0 then
                imgui.Text(u8("Напоминание через: " .. Collect.FormatDuration(remainSeconds)))
            elseif Collect.GameState('crypto').notifiedAt == (lastCollectInfo.timestamp or 0) then
                imgui.Text(u8("Напоминание: уведомление уже отправлено"))
            else
                imgui.Text(u8("Напоминание: время ожидания истекло"))
            end
        else
            imgui.TextDisabled(u8"Напоминание: таймер начнется после первого сбора.")
        end
    else
        imgui.TextDisabled(u8"Напоминание о долгом отсутствии сбора выключено.")
    end
    imgui.Separator()
    if #houses > 0 then
        Draw.Houses()
    else
        Draw.Shelves()
    end
end

local function CollectLogCompareDesc(a, b)
    return tostring(a or '') > tostring(b or '')
end

local function CollectLogSortedKeys(map)
    local keys = {}
    for key in pairs(map or {}) do
        table.insert(keys, key)
    end
    table.sort(keys, CollectLogCompareDesc)
    return keys
end

local function FormatCryptoAmount(value)
    return tostring(math.floor(tonumber(value) or 0))
end

local function CollectLogDayTotalValue(dayData)
    local total = (dayData and dayData.total) or {}
    return tonumber(total.BTC) or 0
end

local function CollectLogFilterKeys(dayKeys, periodDays)
    periodDays = tonumber(periodDays) or 0
    if periodDays <= 0 then
        return dayKeys
    end

    local fromKey = os.date('%Y-%m-%d', os.time() - (math.maxEx(1, periodDays) - 1) * 86400)
    local keys = {}
    for _, dayKey in ipairs(dayKeys or {}) do
        if tostring(dayKey) >= fromKey then
            table.insert(keys, dayKey)
        end
    end
    return keys
end

local function CollectLogGraphKeys(dayKeys, width)
    width = math.maxEx(1, tonumber(width) or imgui.GetWindowContentRegionWidth())
    local maxVisible = math.maxEx(1, math.floor(width / UI.Scale(46)))
    local count = math.minEx(#dayKeys, maxVisible)
    local keys = {}
    for i = count, 1, -1 do
        table.insert(keys, dayKeys[i])
    end
    return keys
end

function Draw.CollectLogsList(days, dayKeys)
    imgui.BeginChild('collect_logs_list', imgui.ImVec2(-1, -1), true)
    imgui.ScrollMouse()

    if #dayKeys == 0 then
        imgui.TextDisabled(u8'Логи сбора пока пустые.')
        imgui.EndChild()
        return
    end

    for _, dayKey in ipairs(dayKeys) do
        local dayData = days[dayKey] or {}
        local dayTotal = dayData.total or {}
        local dayLabel
        dayLabel = string.format('%s | BTC: %s', dayKey, FormatCryptoAmount(dayTotal.BTC))

        if imgui.TreeNode(u8(dayLabel .. '##collect_day_' .. tostring(dayKey))) then
            local houseKeys = CollectLogSortedKeys(dayData.houses or {})

            if #houseKeys == 0 then
                imgui.TextDisabled(u8'Нет данных по домам.')
            else
                for _, houseId in ipairs(houseKeys) do
                    local houseData = dayData.houses[houseId] or {}
                    local houseTotal = houseData.total or {}
                    local houseLabel
                    houseLabel = string.format('Дом %s | BTC: %s', tostring(houseId), FormatCryptoAmount(houseTotal.BTC))

                    if imgui.TreeNode(u8(houseLabel .. '##collect_house_' .. tostring(dayKey) .. '_' .. tostring(houseId))) then
                        local items = houseData.items or {}
                        local trimmed = tonumber(houseData.itemsTrimmed or 0) or 0
                        if trimmed > 0 then
                            imgui.TextDisabled(u8(string.format('Скрыто старых записей: %d', trimmed)))
                        end
                        if #items == 0 then
                            imgui.TextDisabled(u8'Нет детальных записей.')
                        else
                            for _, item in ipairs(items) do
                                local line = string.format('%s | %s | %s', tostring(item.time or '--:--:--'), tostring(item.currency or '-'), FormatCryptoAmount(item.amount))
                                imgui.BulletText(u8(line))
                            end
                        end
                        imgui.TreePop()
                    end
                end
            end

            imgui.TreePop()
        end
    end
    imgui.EndChild()
end

function Draw.CollectLogsGraph(days, dayKeys)
    if #dayKeys == 0 then
        imgui.BeginChild('collect_logs_graph_empty', imgui.ImVec2(-1, -1), true)
        imgui.TextDisabled(u8'Логи сбора пока пустые.')
        imgui.EndChild()
        return
    end

    ui_state.collectLogs.selectedDay = ui_state.collectLogs.selectedDay or dayKeys[1]
    local selectedInFilter = false
    for _, dayKey in ipairs(dayKeys) do
        if dayKey == ui_state.collectLogs.selectedDay then
            selectedInFilter = true
            break
        end
    end
    if not selectedInFilter or not days[ui_state.collectLogs.selectedDay] then
        ui_state.collectLogs.selectedDay = dayKeys[1]
    end

    imgui.BeginChild('collect_logs_graph', imgui.ImVec2(-1, -1), true)
    imgui.ScrollMouse()
    imgui.Text(u8'Прибыль за день')
    imgui.SameLine()
    imgui.TextDisabled(u8'Кликните по столбцу, чтобы увидеть дома.')
    imgui.Spacing()

    local graphW = math.maxEx(UI.Scale(160), imgui.GetWindowContentRegionWidth())
    local graphKeys = CollectLogGraphKeys(dayKeys, graphW)
    local maxTotal = 1
    for _, dayKey in ipairs(graphKeys) do
        maxTotal = math.maxEx(maxTotal, CollectLogDayTotalValue(days[dayKey]))
    end

    local gap = UI.Scale(5)
    local barW = math.maxEx(UI.Scale(28), (graphW - gap * (#graphKeys - 1)) / math.maxEx(1, #graphKeys))
    local graphH = UI.Scale(150)
    local drawList = imgui.GetWindowDrawList()
    local colBg, colBar, colBarActive, colText = Draw.GraphColors()

    for i, dayKey in ipairs(graphKeys) do
        if i > 1 then imgui.SameLine(nil, gap) end
        local totalValue = CollectLogDayTotalValue(days[dayKey])
        local pos = imgui.GetCursorScreenPos()
        if imgui.InvisibleButton('##collect_graph_bar_' .. tostring(dayKey), imgui.ImVec2(barW, graphH)) then
            ui_state.collectLogs.selectedDay = dayKey
        end
        local ratio = totalValue / maxTotal
        local filledH = math.maxEx(UI.Scale(3), (graphH - UI.Scale(28)) * ratio)
        local x1, y1 = pos.x, pos.y
        local x2, y2 = pos.x + barW, pos.y + graphH
        drawList:AddRectFilled(imgui.ImVec2(x1, y1), imgui.ImVec2(x2, y2), colBg, UI.Scale(4), 15)
        local barColor = (ui_state.collectLogs.selectedDay == dayKey) and colBarActive or colBar
        drawList:AddRectFilled(imgui.ImVec2(x1 + UI.Scale(4), y2 - filledH - UI.Scale(20)), imgui.ImVec2(x2 - UI.Scale(4), y2 - UI.Scale(20)), barColor, UI.Scale(3), 15)
        local label = tostring(dayKey):sub(6)
        drawList:AddText(imgui.ImVec2(x1 + UI.Scale(4), y2 - UI.Scale(17)), colText, label)
        if imgui.IsItemHovered() then
            local total = (days[dayKey] and days[dayKey].total) or {}
            imgui.SetTooltip(u8(string.format('%s\nВсего: BTC %s', dayKey, FormatCryptoAmount(total.BTC))))
        end
    end

    imgui.Spacing()
    imgui.Separator()

    local selectedDay = ui_state.collectLogs.selectedDay
    local dayData = days[selectedDay] or {}
    local dayTotal = dayData.total or {}
    imgui.Text(u8(string.format('Выбран день: %s | BTC: %s', tostring(selectedDay), FormatCryptoAmount(dayTotal.BTC))))
    imgui.Text(u8'Доход по домам за выбранный день:')

    local houseKeys = CollectLogSortedKeys(dayData.houses or {})
    if #houseKeys == 0 then
        imgui.TextDisabled(u8'Нет данных по домам.')
    else
        for _, houseId in ipairs(houseKeys) do
            local houseData = dayData.houses[houseId] or {}
            local houseTotal = houseData.total or {}
            imgui.BulletText(u8(string.format('Дом %s | BTC: %s', tostring(houseId), FormatCryptoAmount(houseTotal.BTC))))
        end
    end

    imgui.EndChild()
end

function Draw.CollectLogs()
    local days = collectLogStore.days or {}
    local allDayKeys = CollectLogSortedKeys(days)
    local periodDays = tonumber(settings.main.collectLogsPeriod or 7) or 7
    local dayKeys = CollectLogFilterKeys(allDayKeys, periodDays)

    if imgui.Button(u8'Обновить') then
        Storage.FlushCollectLogStore()
        Storage.LoadCollectLogStore()
        days = collectLogStore.days or {}
        allDayKeys = CollectLogSortedKeys(days)
        dayKeys = CollectLogFilterKeys(allDayKeys, periodDays)
    end
    imgui.SameLine()
    imgui.Text(u8(string.format('Дней с логами: %d/%d', #dayKeys, #allDayKeys)))

    local periodOptions = {
        { days = 3, label = '3 дня' },
        { days = 7, label = '7 дней' },
        { days = 14, label = '14 дней' },
        { days = 30, label = '30 дней' },
        { days = 0, label = 'Всё время' },
    }
    local periodW = (imgui.GetWindowContentRegionWidth() - imgui.GetStyle().ItemSpacing.x * (#periodOptions - 1)) / #periodOptions
    for i, option in ipairs(periodOptions) do
        if i > 1 then imgui.SameLine() end
        if imgui.ButtonClickable(periodDays ~= option.days, u8(option.label), imgui.ImVec2(i == #periodOptions and -1 or periodW, 0)) then
            settings.main.collectLogsPeriod = option.days
            Storage.SaveSettings()
            periodDays = option.days
            dayKeys = CollectLogFilterKeys(allDayKeys, periodDays)
        end
    end

    imgui.Separator()

    local w = (imgui.GetWindowContentRegionWidth() - imgui.GetStyle().ItemSpacing.x) / 2
    if imgui.ButtonClickable(settings.main.collectLogsView ~= 'list', u8'Список', imgui.ImVec2(w, 0)) then
        settings.main.collectLogsView = 'list'
        Storage.SaveSettings()
    end
    imgui.SameLine()
    if imgui.ButtonClickable(settings.main.collectLogsView ~= 'graph', u8'График', imgui.ImVec2(-1, 0)) then
        settings.main.collectLogsView = 'graph'
        Storage.SaveSettings()
    end

    if settings.main.collectLogsView == 'graph' then
        Draw.CollectLogsGraph(days, dayKeys)
    else
        Draw.CollectLogsList(days, dayKeys)
    end
end
function Draw.ImproveSharp()
    if imgui.BeginTabBar("ImproveTabs") then

        if imgui.BeginTabItem(u8"Процесс") then
            Draw.ImproveProcessTab()
            imgui.EndTabItem()
        end

        if imgui.BeginTabItem(u8"Настройки") then
            Draw.ImproveSettingsTab()
            imgui.EndTabItem()
        end

        if imgui.BeginTabItem(u8"Логи") then
            Draw.ImproveLogsTab()
            imgui.EndTabItem()
        end

        imgui.EndTabBar()
    end
end

function Draw.ImproveProcessTab()
    imgui.Columns(2, nil, false)
        imgui.Text(u8('Смазка:'))
        imgui.SameLine()
        local oilText = improve.oils.known and tostring(improve.oils.classic or 0) or '?'
        imgui.TextColored(imgui.ImVec4(0.8,0.9,1,1), u8(oilText))
    imgui.NextColumn()
        imgui.Text(u8('Видеокарты:'))
        imgui.SameLine()
        imgui.TextColored(imgui.ImVec4(0.8,0.9,1,1), u8(tostring(#(improve.cef.cards or {}))))
    imgui.Columns(1)
    imgui.Spacing()

    if imgui.AccentButton(u8(improve.oils.busy and 'Сканирую…' or 'Обновить CEF-инвентарь'), imgui.ImVec2(-1, UI.Scale(26))) then
        Improve.RefreshOils(true)
    end

    if Improve.IsNewStyleMode() then
        local known, unknown = Improve.CountKnownLevels()
        local pTotal = known + unknown
        local halfW = (imgui.GetWindowContentRegionWidth() - imgui.GetStyle().ItemSpacing.x) / 2
        if imgui.AccentButtonClickable(not improve.cef.probing, u8(improve.cef.probing and 'Проверяю уровни…' or 'Проверить уровни'), imgui.ImVec2(halfW, UI.Scale(26))) then
            Improve.ManualCheckCardLevels(false)
        end
        imgui.SameLine()
        if imgui.ButtonClickable(not improve.cef.probing, u8'Сканировать заново', imgui.ImVec2(-1, UI.Scale(26))) then
            Improve.ManualCheckCardLevels(true)
        end
        local status
        if improve.cef.probing then
            status = string.format('Проверяю уровни: %d из %d', math.maxEx(0, improve.cef.pendingIndex or 0), math.maxEx(1, tonumber(improve.cef.probeTotal or pTotal) or pTotal))
        elseif pTotal == 0 then
            status = 'Видеокарты не найдены - обновите CEF-инвентарь'
        elseif unknown == 0 then
            status = string.format('Уровни известны у всех %d карт', pTotal)
        elseif (improve.cef.probeAbortReason or '') ~= '' then
            status = string.format('Прервано (%s). Известно %d из %d', tostring(improve.cef.probeAbortReason), known, pTotal)
        else
            status = string.format('Известно уровней: %d из %d', known, pTotal)
        end
        imgui.TextDisabled(u8(status))
        local frac = (pTotal > 0) and math.maxEx(0.0, math.minEx(1.0, known / pTotal)) or 0.0
        imgui.ProgressBar(frac, imgui.ImVec2(-1, UI.Scale(16)))
    end

    imgui.Separator()
    imgui.CenterText(u8('Этап: ' .. (Improve.stepNames[improve.step] or '?')))
    local stat = improve.stats
    if stat and (stat.sessionId or 0) > 0 then
        local status = stat.active and 'идёт' or 'завершена'
        imgui.Text(u8(string.format('Сессия #%d (%s). Попыток: %d, успехов: %d, ошибок: %d, смазки: %d', stat.sessionId or 0, status, stat.attempts or 0, stat.success or 0, stat.fail or 0, stat.oilsUsed or 0)))
    else
        imgui.TextDisabled(u8'Сессия заточки ещё не запускалась.')
    end

    if imgui.AccentButton(u8(improve.isOn and 'Выключить' or 'Включить'), imgui.ImVec2(-1, UI.Scale(30))) then
        if improve.isOn then
            Improve.Stop('Остановлено вручную через UI')
            Improve.Say('Заточка остановлена вручную.')
        else
            if ISMONETLOADER then
                mobileImproveDialog.suppressUntil = 0
                mobileImproveDialog.lastShowAt = 0
                mobileImproveDialog.lastText = ''
                mobileImproveDialog.wasActive = false
            end
            improve.isOn = true
                    improve.consumedThisTry = false
            improve.resultHandled = false
            improve.waitStartAt = 0
            improve.waitResultAt = 0
            improve.lastUseAt = 0
            improve.cef.needInventoryRefresh = false
            improve.cef.waitInventory = false
            improve.cef.probed = false
            improve.cef.probing = false
            improve.cef.stubNotified = false
            improve.step = Improve.STEP.STOPPED
            improve.needCheckOils = true
            improve.waitOils = false
            Improve.SessionStart()
            Improve.Say('Заточка видеокарт Rodina запущена.')
        end
    end
    imgui.TextDisabled(u8'Источник: CEF-инвентарь Rodina (GPU 3206, смазка 3204)')
    imgui.Spacing()

    imgui.BeginChild("improve_bottom_proc", imgui.ImVec2(-1, -1), true)
        imgui.ScrollMouse()
        imgui.CenterText(u8("Найденные видеокарты:"))

        for i, v in ipairs(improve.videoCards) do
            local btnW  = imgui.GetMiddleButtonX(4)
            local label = (Improve.IsNewStyleMode() and v.slot)
                and string.format("%d LVL [slot %d]##%d", v.level, v.slot, i)
                or string.format("%d LVL##%d", v.level, i)
            local canClick = (v.level < (settings.improve.maxLevel or 2))
            if imgui.ButtonClickable(canClick, label, imgui.ImVec2(btnW, 0)) then
                if not settings.improve.menuAll then
                    improve.select = i
                    improve.selectSlot = tonumber(v.slot or 0) or 0
                    Improve.Say("Выбрана видеокарта #" .. i .. " (slot " .. tostring(improve.selectSlot) .. ", ур. " .. v.level .. ")")
                end
            end
            if i % 4 ~= 0 and i ~= #improve.videoCards then imgui.SameLine() end
        end
    imgui.EndChild()
end

function Draw.ImproveSettingsTab()
    imgui.CenterText(u8("Режим работы:"))
    if imgui.Button(u8(settings.improve.menuAll and "Улучшение всех видеокарт" or "Улучшение определенной видеокарты"), imgui.ImVec2(-1, UI.Scale(30))) then
        settings.improve.menuAll = not settings.improve.menuAll
        Storage.SaveSettings()
        if settings.improve.menuAll then improve.select = 0; improve.selectSlot = 0 end
    end

    imgui.Separator()

    imgui.CenterText(u8('Видеокарты: Rodina (item 3206)'))
    imgui.TextDisabled(u8'Тип карты определяется напрямую по CEF-инвентарю.')

    imgui.Separator()
    settings.improve.inventoryMode = 2
    settings.improve.typeCards = 1
    settings.improve.packetLevels = true
    imgui.CenterText(u8('Источник инвентаря: CEF Rodina'))
    imgui.TextDisabled(u8'Смазка: item 3204. Уровень карты читается из inventory-пакета или прямого диалога.')

    imgui.Separator()
    imgui.CenterText(u8('Режим улучшения: производительность'))
    imgui.TextDisabled(u8'На Rodina используется прямой диалог "Улучшение видеокарты".')

    imgui.Separator()
    imgui.CenterText(u8('Порядок улучшения:'))
    local w = (imgui.GetWindowWidth() - UI.Scale(6)) / 2
    if imgui.ButtonClickable(settings.improve.mode ~= 1, u8('Последовательное'), imgui.ImVec2(w, 0)) then
        settings.improve.mode = 1; Storage.SaveSettings()
    end
    imgui.SameLine()
    if imgui.ButtonClickable(settings.improve.mode ~= 2, u8('Поочередное'), imgui.ImVec2(-1, 0)) then
        settings.improve.mode = 2; Storage.SaveSettings()
    end
    imgui.TextDisabled(u8'Последовательное: сначала карты меньшего уровня. Поочередное: порядок слотов.')

    imgui.Separator()

    imgui.CenterText(u8("Уровень улучшения видеокарт:"))
    imgui.PushItemWidth(-1)
    local _maxLevel = imgui.new.int(settings.improve.maxLevel or 2)
    if imgui.SliderInt("##maximumValueLevel", _maxLevel, 2, 10, u8("%d ур.")) then
        settings.improve.maxLevel = _maxLevel[0]; Storage.SaveSettings()
    end
    imgui.PopItemWidth()

    do
        local minLevel, maxLevel = nil, nil
        for _, card in ipairs(improve.videoCards or {}) do
            local lvl = tonumber(card.level)
            if lvl then
                minLevel = (minLevel == nil) and lvl or math.min(minLevel, lvl)
                maxLevel = (maxLevel == nil) and lvl or math.max(maxLevel, lvl)
            end
        end
        if minLevel ~= nil and maxLevel ~= nil then
            local currentText = (minLevel == maxLevel)
                and string.format("Сейчас карты: %d LVL", minLevel)
                or string.format("Сейчас карты: %d-%d LVL", minLevel, maxLevel)
            imgui.TextDisabled(u8(currentText))
        end
    end

    imgui.Separator()

    -- проверять ли смазку при старте заточки
    local _checkOils = imgui.new.bool(settings.improve.checkOilsOnStart)
    if imgui.Checkbox(u8"Проверять смазку при старте заточки", _checkOils) then
        settings.improve.checkOilsOnStart = not settings.improve.checkOilsOnStart
        Storage.SaveSettings()
    end
    imgui.TextDisabled(u8"Если выключено, заточка стартует без принудительной проверки")

    imgui.Separator()

    imgui.CenterText(u8("Память уровней видеокарт:"))
    imgui.TextDisabled(u8"Уровни запоминаются по слотам и переживают перезапуск скрипта,\nпоэтому после обрыва сканирование продолжается, а не начинается заново.")

    settings.improve.packetLevels = true
    imgui.TextDisabled(u8'CEF-инвентарь используется всегда; неизвестные уровни MMT уточняет через диалог карты.')

    local _fast = imgui.new.bool(settings.improve.fastProbe ~= false)
    if imgui.Checkbox(u8"Быстрая проверка (не переоткрывать инвентарь между картами)", _fast) then
        settings.improve.fastProbe = not (settings.improve.fastProbe ~= false)
        Storage.SaveSettings()
    end

    imgui.Text(u8"Срок актуальности запомненного уровня (часов, 0 = бессрочно):")
    imgui.PushItemWidth(UI.Scale(120))
    local _ttl = imgui.new.int(tonumber(settings.improve.levelCacheHours) or 0)
    if imgui.InputInt("##levelCacheHours", _ttl, 0, 0) then
        settings.improve.levelCacheHours = math.maxEx(0, _ttl[0])
        Storage.SaveSettings()
    end
    imgui.PopItemWidth()

    imgui.Text(u8"Повторов при неответившем слоте:")
    imgui.PushItemWidth(-1)
    local _retries = imgui.new.int(tonumber(settings.improve.probeRetries) or 2)
    if imgui.SliderInt("##probeRetries", _retries, 0, 5, u8"%d") then
        settings.improve.probeRetries = math.maxEx(0, _retries[0])
        Storage.SaveSettings()
    end
    imgui.PopItemWidth()

    if imgui.ButtonClickable(not improve.cef.probing, u8"Забыть запомненные уровни", imgui.ImVec2(-1, UI.Scale(26))) then
        Improve.CardCacheClear(0)
        Improve.ForgetPacketLevels()
        for _, c in ipairs(improve.cef.cards or {}) do
            c.levelKnown = false
            c.probeFailed = false
            c.level = 0
        end
        improve.cef.probed = false
        Improve.SyncVideoCardsFromCef()
        Improve.Say('Запомненные уровни видеокарт очищены.')
    end
end

function Draw.ImproveLogsTab()
    local store = Improve.GetStatsStore()
    local todayKey = os.date('%Y-%m-%d')

    local today = store and store.days and store.days[todayKey] or {
        sessions  = 0,
        attempts  = 0,
        success   = 0,
        fail      = 0,
        oilsUsed  = 0,
        byLevel   = {},
        time      = 0,
    }
    Improve.EnsureLevelStats(today)

    local total = store and store.total or {
        sessions  = 0,
        attempts  = 0,
        success   = 0,
        fail      = 0,
        oilsUsed  = 0,
        byLevel   = {},
        time      = 0,
    }
    Improve.EnsureLevelStats(total)

    local s = improve.stats

    if imgui.BeginTabBar("ImproveLogsSegments") then
        if imgui.BeginTabItem(u8"Сводка") then
            imgui.Columns(2, nil, false)
                imgui.Text(u8(string.format("Сегодня (%s):", todayKey)))
                imgui.Text(u8(string.format("  Сессий:   %d", today.sessions or 0)))
                imgui.Text(u8(string.format("  Попыток:  %d (успехов: %d, ошибок: %d)", today.attempts or 0, today.success or 0, today.fail or 0)))
                imgui.Text(u8(string.format("  Смазки:   %d", today.oilsUsed or 0)))
                imgui.Text(u8(string.format("  Время:    %d сек.", today.time or 0)))
            imgui.NextColumn()
                imgui.Text(u8("За всё время:"))
                imgui.Text(u8(string.format("  Сессий:   %d", total.sessions or 0)))
                imgui.Text(u8(string.format("  Попыток:  %d (успехов: %d, ошибок: %d)", total.attempts or 0, total.success or 0, total.fail or 0)))
                imgui.Text(u8(string.format("  Смазки:   %d", total.oilsUsed or 0)))
                imgui.Text(u8(string.format("  Время:    %d сек.", total.time or 0)))
            imgui.Columns(1)

            imgui.Separator()
            imgui.Text(u8("По уровням (с N на N+1):"))
            imgui.Columns(2, nil, false)
                imgui.Text(u8("Сегодня"))
                for lvl = 1, 9 do
                    local row = today.byLevel[lvl] or {}
                    local attempts = row.attempts or 0
                    local success = row.success or 0
                    local chance = (attempts > 0) and (success * 100.0 / attempts) or 0
                    imgui.Text(u8(string.format(
                        "  %d->%d: попыток %d, шанс %.1f%%",
                        lvl, lvl + 1, attempts, chance
                    )))
                end
            imgui.NextColumn()
                imgui.Text(u8("За всё время"))
                for lvl = 1, 9 do
                    local row = total.byLevel[lvl] or {}
                    local attempts = row.attempts or 0
                    local success = row.success or 0
                    local chance = (attempts > 0) and (success * 100.0 / attempts) or 0
                    imgui.Text(u8(string.format(
                        "  %d->%d: попыток %d, шанс %.1f%%",
                        lvl, lvl + 1, attempts, chance
                    )))
                end
            imgui.Columns(1)
            imgui.EndTabItem()
        end

        if imgui.BeginTabItem(u8"Сессия") then
            if s and (s.sessionId or 0) > 0 then
                local startedStr  = (s.startedAt  and s.startedAt  > 0) and os.date('%d.%m.%Y %H:%M:%S', s.startedAt)  or "-"
                local finishedStr = (s.finishedAt and s.finishedAt > 0) and os.date('%d.%m.%Y %H:%M:%S', s.finishedAt) or (s.active and "идёт…" or "-")

                imgui.Text(u8(string.format("Последняя сессия #%d:", s.sessionId)))
                imgui.Text(u8("  Старт:      " .. startedStr))
                imgui.Text(u8("  Завершение: " .. finishedStr))
                imgui.Text(u8(string.format("  Попыток:    %d (успехов: %d, ошибок: %d)", s.attempts or 0, s.success or 0, s.fail or 0)))
                imgui.Text(u8(string.format("  Смазки потрачено: %d", s.oilsUsed or 0)))
                if s.lastReason and s.lastReason ~= "" then
                    imgui.Text(u8("  Причина завершения: " .. s.lastReason))
                end
            else
                imgui.TextDisabled(u8"Сессий заточки ещё не было.")
            end
            imgui.EndTabItem()
        end

        if imgui.BeginTabItem(u8"Лента") then
            if imgui.Button(u8"Очистить лог", imgui.ImVec2(UI.Scale(120), 0)) then
                improve.logs.items = {}
            end
            imgui.SameLine()
            local autoScrollPtr = imgui.new.bool(improve.logs.autoScroll ~= false)
            if imgui.Checkbox(u8"Автопрокрутка вниз", autoScrollPtr) then
                improve.logs.autoScroll = autoScrollPtr[0]
            end

            imgui.Separator()
            imgui.BeginChild("improve_logs_scroll", imgui.ImVec2(-1, -1), true)
                imgui.ScrollMouse()
                for i, entry in ipairs(improve.logs.items or {}) do
                    local line = string.format("[%s] [%s] %s", entry.ts or "?", entry.type or "INFO", entry.text or "")
                    local etype = entry.type or "INFO"
                    if etype == "ERROR" or etype == "WARN" then
                        imgui.TextColored(imgui.ImVec4(1, 0.4, 0.4, 1), u8(line))
                    elseif etype == "SUCCESS" then
                        imgui.TextColored(imgui.ImVec4(0.6, 1.0, 0.6, 1), u8(line))
                    else
                        imgui.Text(u8(line))
                    end
                end

                if improve.logs.autoScroll ~= false then
                    imgui.SetScrollHereY(1.0)
                end
            imgui.EndChild()
            imgui.EndTabItem()
        end

        if imgui.BeginTabItem(u8"Сервис") then
            imgui.TextWrapped(u8"Сброс удаляет накопленную статистику по дням и за всё время.")
            if imgui.Button(u8"Сбросить статистику", imgui.ImVec2(UI.Scale(180), 0)) then
                improve.statsStore = {
                    days = {},
                    total = {
                        sessions  = 0,
                        attempts  = 0,
                        success   = 0,
                        fail      = 0,
                        oilsUsed  = 0,
                        byLevel   = {},
                        time      = 0,
                    }
                }
                Improve.EnsureLevelStats(improve.statsStore.total)
                Improve.SaveStatsStore()
            end
            imgui.EndTabItem()
        end

        imgui.EndTabBar()
    end
end


-- Поле ввода настройки уведомлений. Буфер живёт между кадрами, иначе ввод сбрасывается
function Draw.TgInput(id, field, flags)
    local tg = collectReminder.tg
    local buf = tg.buf[field]
    if not buf then
        buf = new.char[256]()
        buf_set(buf, u8(tostring(settings.notifications[field] or '')))
        tg.buf[field] = buf
    end
    imgui.PushItemWidth(-1)
    if imgui.InputText(id, buf, 256, flags or 0) then
        settings.notifications[field] = Collect.TgTrim(u8:decode(ffi.string(buf)))
        Storage.SaveSettings()
    end
    imgui.PopItemWidth()
end

-- Таблица событий: галочки "В игре" и "Telegram", интервал и когда придёт напоминание
function Draw.ReminderTable()
    local cfg = settings.notifications
    Draw.SectionTitle("Напоминания о сборе")

    local x0 = imgui.GetCursorPosX()
    local colGame = x0 + UI.Scale(130)
    local colTg = colGame + UI.Scale(70)
    local colMin = colTg + UI.Scale(80)
    local colStatus = colMin + UI.Scale(80)

    imgui.TextDisabled(u8"Событие")
    imgui.SameLine(colGame)
    imgui.TextDisabled(u8"В игре")
    imgui.SameLine(colTg)
    imgui.TextDisabled(u8"Telegram")
    imgui.SameLine(colMin)
    imgui.TextDisabled(u8"Через, мин")
    imgui.SameLine(colStatus)
    imgui.TextDisabled(u8"Когда")

    for _, kind in ipairs(Collect.TG_KINDS) do
        local id = kind.id
        if Collect.KindEnabled(id) then
        imgui.AlignTextToFramePadding()
        imgui.Text(u8(kind.short))

        imgui.SameLine(colGame)
        if imgui.Checkbox("##reminderGame" .. id, new.bool(cfg.game[id] == true)) then
            cfg.game[id] = not cfg.game[id]
            Storage.SaveSettings()
        end

        imgui.SameLine(colTg)
        if imgui.Checkbox("##reminderTg" .. id, new.bool(cfg.tg[id] == true)) then
            cfg.tg[id] = not cfg.tg[id]
            Storage.SaveSettings()
        end

        local where = Collect.REMINDER_MINUTES[id]
        imgui.SameLine(colMin)
        imgui.PushItemWidth(UI.Scale(70))
        local ptr = new.int(tonumber(settings[where[1]][where[2]]) or 0)
        if imgui.InputInt("##reminderMin" .. id, ptr, 0, 0) then
            settings[where[1]][where[2]] = math.maxEx(0, ptr[0])
            Storage.SaveSettings()
        end
        imgui.PopItemWidth()

        imgui.SameLine(colStatus)
        imgui.TextDisabled(u8(Collect.TgReminderStatus(id)))
        end
    end

    imgui.TextDisabled(u8"Напоминание приходит через заданное число минут после последнего сбора, одно на каждый сбор.\n0 минут - напоминание выключено. Интервал крипты общий с вкладкой \"Видеокарты\".")

    local problem = Collect.TgConfigProblem()
    local anyTg = false
    for _, kind in ipairs(Collect.TG_KINDS) do
        if Collect.KindEnabled(kind.id) and cfg.tg[kind.id] then anyTg = true end
    end
    if anyTg and problem then
        imgui.TextColored(UI.Vec4('warnColor'), u8("Telegram не настроен: " .. problem .. " (ниже)"))
    end
end

-- Состояние менеджера уведомлений: без него напоминания в игре приходят сообщением в чат
function Draw.NotifyManagerBlock()
    local notifyState = Collect.GetNotifySystemState()
    if not notifyState.ready then
        imgui.TextDisabled(u8(notifyState.message))
        if collectReminder.managerEnsurePending then
            imgui.TextDisabled(u8"Подготовка менеджера уведомлений...")
        else
            if imgui.Button(u8(Collect.GetNotifyInstallButtonText(notifyState)), imgui.ImVec2(-1, 0)) then
                Collect.EnsureNotificationManager()
            end
            if not notifyState.available then
                if collectReminder.managerDownloadPending then
                    imgui.TextDisabled(u8"Скачивание менеджера уведомлений и библиотеки...")
                elseif imgui.Button(u8"Скачать менеджер и библиотеку", imgui.ImVec2(-1, 0)) then
                    Collect.DownloadNotificationSystem()
                end
            end
        end
        imgui.TextDisabled(u8("GitHub: " .. NOTIFY_MANAGER_REPO_URL))
        if collectReminder.managerStatusMessage ~= "" then
            imgui.TextDisabled(u8(collectReminder.managerStatusMessage))
        end
    end
    if notifyState.ready then
        imgui.TextDisabled(u8"Менеджер уведомлений работает: напоминания появятся всплывающим окном.")
    else
        imgui.TextDisabled(u8"Пока менеджер не установлен, напоминания в игре приходят сообщением в чат.")
    end
end

function Draw.SettingsNotifications()
    local cfg = settings.notifications
    local tg = collectReminder.tg
    imgui.Spacing()

    Draw.ReminderTable()

    imgui.Spacing()
    Draw.SectionTitle("Telegram")
    imgui.Text(u8"Через какого бота:")
    local half = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x) / 2
    local own = tonumber(cfg.methodBot) ~= 2
    if (own and imgui.AccentButton or imgui.Button)(u8"Свой бот", imgui.ImVec2(half, 0)) then
        cfg.methodBot = 1
        Storage.SaveSettings()
    end
    imgui.SameLine()
    if ((not own) and imgui.AccentButton or imgui.Button)(u8"Бот MCR Notification", imgui.ImVec2(-1, 0)) then
        cfg.methodBot = 2
        Storage.SaveSettings()
    end

    imgui.Spacing()
    if own then
        imgui.Text(u8"Токен бота:")
        Draw.TgInput("##tgToken", "botToken", imgui.InputTextFlags.Password)
        imgui.Text(u8"ID чата:")
        Draw.TgInput("##tgChatId", "chatId")
        imgui.TextDisabled(u8"Бота создайте в @BotFather, свой ID узнайте в @getmyid_bot и напишите своему боту /start.")
        if imgui.Button(u8"Инструкция по созданию бота", imgui.ImVec2(-1, 0)) then
            Util.OpenUrl("https://docs.arz-mcr.ru/create-tg-bot/")
        end
    else
        imgui.Text(u8"Ваш ID в боте MCR Notification:")
        Draw.TgInput("##tgMcrChatId", "mcrChatId")
        if imgui.Button(u8"Открыть @MCR_NotificationBot", imgui.ImVec2(-1, 0)) then
            Util.OpenUrl("https://t.me/MCR_NotificationBot")
        end
        imgui.TextDisabled(u8"В боте отправьте /start и следуйте инструкции - бот пришлёт ваш ID.")

        imgui.Spacing()
        Draw.McrKeyBlock()
    end

    local problem = Collect.TgConfigProblem()
    if problem then
        imgui.TextColored(UI.Vec4('badColor'), u8("Не заполнено: " .. problem))
    end

    if imgui.ButtonClickable(problem == nil, u8"Тестовое сообщение", imgui.ImVec2(-1, 0)) then
        local ok, err = Collect.TgSend("[MMT-R] Тестовое сообщение. Уведомления работают.", 'test')
        tg.lastResult = ok and (os.date('%H:%M:%S') .. " - отправляю...") or ("не отправлено: " .. tostring(err))
    end
    if tg.initError then
        imgui.TextColored(UI.Vec4('badColor'), u8("Отправка недоступна: " .. tg.initError))
    elseif tg.lastResult ~= '' then
        imgui.TextDisabled(u8(tg.lastResult))
    end

    imgui.Spacing()
    Draw.SectionTitle("Уведомления в игре")
    Draw.NotifyManagerBlock()
end

-- Ключ MCR для бота MCR Notification
function Draw.McrKeyBlock()
    local cfg = settings.notifications
    local tg = collectReminder.tg
    local key, source = Collect.TgGetKey()
    if key ~= '' and not tg.keyEdit then
        imgui.Text(u8(string.format("Ключ MCR: %s (%s)", Collect.TgMaskKey(key), source)))
        if source == 'MMT' then
            if imgui.Button(u8"Очистить ключ##mcrKey", imgui.ImVec2(-1, 0)) then
                cfg.mcrKey = ''
                tg.keyCheckedAt = -1000
                Storage.SaveSettings()
            end
        elseif imgui.Button(u8"Указать другой ключ##mcrKey", imgui.ImVec2(-1, 0)) then
            tg.keyEdit = true
        end
        return
    end

    imgui.Text(u8"Ключ MCR:")
    imgui.TextDisabled(u8"Ключ не найден в MCR ПК и MLoader - введите его и нажмите Enter.")
    local buf = tg.buf.mcrKey
    if not buf then
        buf = new.char[64]()
        tg.buf.mcrKey = buf
    end
    imgui.PushItemWidth(-1)
    if imgui.InputText("##tgMcrKey", buf, 64, imgui.InputTextFlags.Password + imgui.InputTextFlags.EnterReturnsTrue) then
        cfg.mcrKey = Collect.TgTrim(ffi.string(buf))
        buf_set(buf, '')
        tg.keyEdit = false
        Storage.SaveSettings()
    end
    imgui.PopItemWidth()
    if tg.keyEdit and imgui.Button(u8"Отмена##mcrKey", imgui.ImVec2(-1, 0)) then
        buf_set(buf, '')
        tg.keyEdit = false
    end
end

-- Настройки майнинга крипты: сбор, заливка, напоминание, заточка
function Draw.CryptoSettings()
    imgui.Spacing()
    if imgui.Checkbox(u8"Скрыть текст получения крипты в чате", new.bool(settings.main.hideMessagesCollect)) then
        settings.main.hideMessagesCollect = not settings.main.hideMessagesCollect 
        Storage.SaveSettings()
    end

    if imgui.Checkbox(u8"Общая сводка в чат после сбора", new.bool(settings.main.showCollectSummary)) then
        settings.main.showCollectSummary = not settings.main.showCollectSummary
        Storage.SaveSettings()
    end
    imgui.TextDisabled(u8"Уровни видеокарт, суммы по домам, время и детали сбора")

    if imgui.Checkbox(u8"Проверять смазку при старте заточки", new.bool(settings.improve.checkOilsOnStart)) then
        settings.improve.checkOilsOnStart = not settings.improve.checkOilsOnStart
        Storage.SaveSettings()
    end
    imgui.TextDisabled(u8"Если выключено, заточка стартует без принудительной проверки")

    imgui.Text(u8"Напомнить, если не было сбора:")
    imgui.PushItemWidth(UI.Scale(120))
    local collectNotifyMinutesPtr = imgui.new.int(tonumber(settings.main.collectNotifyMinutes) or 0)
    if imgui.InputInt("##collectNotifyMinutes", collectNotifyMinutesPtr, 0, 0) then
        settings.main.collectNotifyMinutes = math.maxEx(0, collectNotifyMinutesPtr[0])
        Storage.SaveSettings()
    end
    imgui.PopItemWidth()
    imgui.SameLine()
    imgui.TextDisabled(u8"мин (0 = выкл)")
    imgui.TextDisabled(u8"Куда присылать напоминания - в игру или в Telegram - вкладка \"Уведомления\".")

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    imgui.Text(u8(string.format("Заливать при %.0f%%%% или ниже:", settings.main.fillFrom)))
    imgui.PushItemWidth(-1)
    local _fillFrom = new.float(settings.main.fillFrom)
    if imgui.SliderFloat("##fillFrom", _fillFrom, 0, 99, "%.0f%%") then
        settings.main.fillFrom = Util.Round(_fillFrom[0], 2)
        Storage.SaveSettings()
    end
    imgui.PopItemWidth()

    imgui.Text(u8(string.format("Подсвечивать дом красным от %.0f крипты:", settings.main.maxCollectAlert)))
    imgui.PushItemWidth(-1)
    local _maxCollectAlert = new.float(math.minEx(9, math.maxEx(1, tonumber(settings.main.maxCollectAlert) or 9.0)))
    if imgui.SliderFloat("##maxCollectAlert", _maxCollectAlert, 1, 9, "%.0f") then
        settings.main.maxCollectAlert = math.minEx(9, math.maxEx(1, Util.Round(_maxCollectAlert[0], 2)))
        Storage.SaveSettings()
    end
    imgui.PopItemWidth()
    imgui.TextDisabled(u8"Столбец \"Мкс. крипты\" в списке домов: выше порога - хранилище пора разгружать")
end

function Draw.Settings()
    -- Верхняя панель статуса (если включена)
    if settings.main.showStatusPanel then
        imgui.BeginChild("status_panel", imgui.ImVec2(-1, 60), true)
        imgui.Text(u8(string.format("Работаю: %s | Заливаю: %s | Собираю: %s | Вкл/выкл: %s", 
            stateCrypto.work, processes.fill, processes.take, (processes.on or processes.off))))

        if stateCrypto.work then
            imgui.Spacing()
            if imgui.Button(u8"Отменить процесс", imgui.ImVec2(-1, 0)) then
                Interacting.Deactivate()
            end
        end
        imgui.EndChild()

        imgui.Spacing()
    end

    -- Основная область с табами
    imgui.BeginChild("settings_tabs", imgui.ImVec2(-1, -1))

    if imgui.BeginTabBar("SettingsTabs") then

        -- ТАБ 1: Основное
        if imgui.BeginTabItem(u8"Основное") then
            imgui.BeginChild("tab_main", imgui.ImVec2(-1, -1))
            imgui.ScrollMouse()
            imgui.Spacing()

            if imgui.Checkbox(u8"Заменять окно диалога на окно скрипта", new.bool(settings.main.replaceDialog)) then
                settings.main.replaceDialog = not settings.main.replaceDialog 
                Storage.SaveSettings()
            end

            if imgui.Checkbox(u8"Закрывать скрипт на ESC", new.bool(settings.main.closeOnESC)) then
                settings.main.closeOnESC = not settings.main.closeOnESC 
                Storage.SaveSettings()
            end

            if imgui.Checkbox(u8"Перемещаться стрелочками в списке", new.bool(settings.main.arrowsMove)) then
                settings.main.arrowsMove = not settings.main.arrowsMove 
                Storage.SaveSettings()
            end

            if imgui.Checkbox(u8"Отображать панель статуса (дебаг информация)", new.bool(settings.main.showStatusPanel)) then
                settings.main.showStatusPanel = not settings.main.showStatusPanel
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Отображать информацию о работающих процессах вверху окна")

            local debugEnabled = settings.main.typeChatMessage and settings.main.typeChatMessage.debug == true
            if imgui.Checkbox(u8"Дебаг (чат + MMT_runtime.log)", new.bool(debugEnabled)) then
                settings.main.typeChatMessage.debug = not debugEnabled
                RuntimeLog.SetEnabled(settings.main.typeChatMessage.debug, settings.main.typeChatMessage.debug)
                Storage.SaveSettings()
                if settings.main.typeChatMessage.debug then
                    RuntimeLog.StartSession()
                    RuntimeLog.Write("DEBUG", "debug logging enabled from settings")
                end
            end
            imgui.TextDisabled(u8"Когда выключено, runtime/CEF-логи на диск не пишутся. Личные токены в DEBUG-логе маскируются.")

            imgui.Spacing()

            imgui.EndChild()
            imgui.EndTabItem()
        end

        -- ТАБ 2: Доходность
        if imgui.BeginTabItem(u8"Доходность") then
            imgui.BeginChild("tab_income", imgui.ImVec2(-1, -1))
            imgui.ScrollMouse()
            imgui.Spacing()

            local inc = GetIncomeSettings()

            imgui.TextWrapped(u8"Выберите, какие показатели доходности отображать:")
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            if imgui.Checkbox(u8"Показывать доход за час", imgui.new.bool(inc.showPerHour)) then
                inc.showPerHour = not inc.showPerHour
                Storage.SaveSettings()
            end
            imgui.SameLine()
            imgui.TextDisabled(u8"(/час)")

            if imgui.Checkbox(u8"Показывать доход за 24 часа", imgui.new.bool(inc.showPer24h)) then
                inc.showPer24h = not inc.showPer24h
                Storage.SaveSettings()
            end
            imgui.SameLine()
            imgui.TextDisabled(u8"(/24ч)")

            if imgui.Checkbox(u8"Показывать доход за цикл", imgui.new.bool(inc.showPerCycle)) then
                inc.showPerCycle = not inc.showPerCycle
                Storage.SaveSettings()
            end
            imgui.SameLine()
            imgui.TextDisabled(u8"(/цикл)")

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            if imgui.Checkbox(u8"Показывать текущую прибыль", imgui.new.bool(inc.showTillThresholdProfit)) then
                inc.showTillThresholdProfit = not inc.showTillThresholdProfit
                Storage.SaveSettings()
            end

            if imgui.Checkbox(u8"Показывать время до доливки", imgui.new.bool(inc.showTillThresholdHours)) then
                inc.showTillThresholdHours = not inc.showTillThresholdHours
                Storage.SaveSettings()
            end

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextWrapped(u8"Бонусы доходности по домам:")
            imgui.Spacing()

            local rtx4090Ptr = imgui.new.bool(inc.rtx4090 == true)
            if imgui.Checkbox(u8"RTX 4090", rtx4090Ptr) then
                inc.rtx4090 = rtx4090Ptr[0]
                Storage.SaveSettings()
            end
            imgui.SameLine()
            imgui.TextDisabled(u8"x1.25 к майнингу для всех домов")
            imgui.Spacing()

            imgui.Text(u8"Номер дома:")
            imgui.PushItemWidth(UI.Scale(140))
            imgui.InputInt("##incomeHouseNumber", inputIncomeHouse, 0, 0)
            imgui.PopItemWidth()
            imgui.SameLine()

            if imgui.Button(u8"Добавить дом", imgui.ImVec2(UI.Scale(160), 0)) then
                local houseNumber = math.maxEx(0, inputIncomeHouse[0])
                if houseNumber >= 0 then
                    local houseKey = tostring(houseNumber)
                    if type(inc.houseBonuses[houseKey]) ~= "table" then
                        inc.houseBonuses[houseKey] = {
                            creativitySet = false,
                            customPercent = 0,
                        }
                        Storage.SaveSettings()
                    end
                    inputIncomeHouse[0] = 0
                end
            end
            imgui.TextDisabled(u8"Набор творчества даёт x1.25 к майнингу для дома")

            imgui.Spacing()

            local houseKeys = GetSortedIncomeHouseBonusKeys()
            if #houseKeys == 0 then
                imgui.TextDisabled(u8"Список домов пуст. Добавьте дом выше.")
            else
                imgui.BeginChild("income_house_bonus_list", imgui.ImVec2(-1, UI.Scale(220)), true)
                imgui.ScrollMouse()

                local removedHouse = false
                for _, houseKey in ipairs(houseKeys) do
                    local houseConfig = NormalizeIncomeHouseBonusConfig(inc.houseBonuses[houseKey])
                    inc.houseBonuses[houseKey] = houseConfig
                    local totalBonus = CalcHouseIncomeBonusPercent(houseKey)

                    imgui.Separator()
                    imgui.Text(u8(string.format("Дом №%s | Итоговый бонус: +%.2f%%", houseKey, totalBonus)))

                    imgui.SameLine()
                    if imgui.RightButton(u8("Удалить##income_remove_" .. houseKey), imgui.ImVec2(UI.Scale(120), 0)) then
                        inc.houseBonuses[houseKey] = nil
                        Storage.SaveSettings()
                        removedHouse = true
                        break
                    end

                    local creativityPtr = imgui.new.bool(houseConfig.creativitySet == true)
                    if imgui.Checkbox(u8("Набор творчества##income_creativity_" .. houseKey), creativityPtr) then
                        houseConfig.creativitySet = creativityPtr[0]
                        Storage.SaveSettings()
                    end

                    imgui.SameLine()
                    imgui.Text("\t|\t")
                    imgui.SameLine()

                    imgui.Text(u8"Свой процент:")
                    imgui.SameLine()
                    imgui.PushItemWidth(UI.Scale(120))
                    local customPercentPtr = imgui.new.int(tonumber(houseConfig.customPercent) or 0)
                    if imgui.InputInt("##income_custom_percent_" .. houseKey, customPercentPtr, 0, 0) then
                        houseConfig.customPercent = math.maxEx(0, customPercentPtr[0])
                        Storage.SaveSettings()
                    end
                    imgui.PopItemWidth()
                    imgui.SameLine()
                    imgui.TextDisabled(u8"%%")

                    imgui.Spacing()
                end

                if not removedHouse and #houseKeys > 0 then
                    imgui.Separator()
                end
                imgui.EndChild()
            end

            imgui.EndChild()
            imgui.EndTabItem()
        end
        -- ТАБ 3: Задержки
        if imgui.BeginTabItem(u8"Задержки") then
            imgui.BeginChild("tab_delays", imgui.ImVec2(-1, -1))
            imgui.ScrollMouse()

            imgui.Spacing()

            imgui.TextWrapped(u8"Настройка временных интервалов для стабильной работы скрипта:")
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.PushItemWidth(-1)

            imgui.CenterText(u8"Для работы с полками")

            imgui.Spacing()

            imgui.Text(u8"Ожидание ответа диалога:")
            local _timeoutDialog = new.int(settings.deley.timeoutDialog)
            if imgui.SliderInt("##timeoutDialog", _timeoutDialog, 1, 30, u8"%d сек") then
                settings.deley.timeoutDialog = _timeoutDialog[0]
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Максимальное время ожидания открытия диалога")

            imgui.Spacing()

            imgui.Text(u8"Интервал проверки:")
            local _waitInterval = new.int(settings.deley.waitInterval)
            if imgui.SliderInt("##waitInterval", _waitInterval, 1, 100, u8"%d мс") then
                settings.deley.waitInterval = _waitInterval[0]
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Частота проверки состояния (миллисекунды)")

            imgui.Spacing()

            imgui.Text(u8"Ожидание ответа от полок:")
            local _timeoutShelf = new.int(settings.deley.timeoutShelf)
            if imgui.SliderInt("##timeoutShelf", _timeoutShelf, 1, 30, u8"%d сек") then
                settings.deley.timeoutShelf = _timeoutShelf[0]
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Максимальное время ожидания ответа от полок")

            imgui.Spacing()

            imgui.Text(u8"Задержка перед ответом на диалог:")
            local _waitRun = new.int(settings.deley.waitRun)
            if imgui.SliderInt("##waitRun", _waitRun, 1, 100, u8"%d мс") then
                settings.deley.waitRun = _waitRun[0]
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Пауза перед отправкой ответа в диалог")

            imgui.Spacing()

            imgui.Text(u8"Повторов при зависшей полке:")
            local _shelfRetries = new.int(tonumber(settings.deley.shelfRetries) or 2)
            if imgui.SliderInt("##shelfRetries", _shelfRetries, 0, 5, u8"%d") then
                settings.deley.shelfRetries = _shelfRetries[0]
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Если сервер не ответил на открытие полки, скрипт закроет\nкарточку видеокарты, вернётся к списку и попробует снова")

            imgui.Text(u8"Повторов при зависшем доме:")
            local _houseRetries = new.int(tonumber(settings.deley.houseRetries) or 1)
            if imgui.SliderInt("##houseRetries", _houseRetries, 0, 3, u8"%d") then
                settings.deley.houseRetries = _houseRetries[0]
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Сколько раз перезайти в дом, если он не отработал целиком.\nПосле этого дом пропускается, а сбор идёт дальше")

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.CenterText(u8"Для улучшения видеокарт")

            imgui.Spacing()

            imgui.Text(u8"Задержка после получения результата улучшения:")
            local _improve_waitResult = new.int(settings.deley.improve_waitResult)
            if imgui.SliderInt("##improve_waitResult", _improve_waitResult, 10, 1000, u8"%d мс") then
                settings.deley.improve_waitResult = _improve_waitResult[0]
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Пауза после получения результата улучшения")

            imgui.Text(u8"Ожидание перед нажатием на видеокарту:")
            local _improve_waitTryClick = new.int(settings.deley.improve_waitTryClick)
            if imgui.SliderInt("##improve_waitTryClick", _improve_waitTryClick, 10, 1000, u8"%d мс") then
                settings.deley.improve_waitTryClick = _improve_waitTryClick[0]
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Пауза перед тем, как нажать на видеокарту")

            imgui.Text(u8"Интервал автоповтора CEF-клика:")
            local _improve_retryUseDelay = new.int(settings.deley.improve_retryUseDelay or 1200)
            if imgui.SliderInt("##improve_retryUseDelay", _improve_retryUseDelay, 200, 5000, u8"%d мс") then
                settings.deley.improve_retryUseDelay = _improve_retryUseDelay[0]
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Если сервер не подтверждает старт, скрипт нажмёт слот снова")

            imgui.Text(u8"Таймаут ожидания старта улучшения:")
            local _improve_waitStartTimeout = new.int(settings.deley.improve_waitStartTimeout or 8)
            if imgui.SliderInt("##improve_waitStartTimeout", _improve_waitStartTimeout, 2, 30, u8"%d сек") then
                settings.deley.improve_waitStartTimeout = _improve_waitStartTimeout[0]
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Если старт не подтверждён сервером, попытка перезапускается")

            imgui.Text(u8"Таймаут ожидания результата улучшения:")
            local _improve_waitResultTimeout = new.int(settings.deley.improve_waitResultTimeout or 20)
            if imgui.SliderInt("##improve_waitResultTimeout", _improve_waitResultTimeout, 3, 60, u8"%d сек") then
                settings.deley.improve_waitResultTimeout = _improve_waitResultTimeout[0]
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Если нет результата, попытка считается ошибкой и цикл продолжается")

            imgui.PopItemWidth()

            imgui.EndChild()
            imgui.EndTabItem()
        end

        -- ТАБ 5: Черный список
        if imgui.BeginTabItem(u8"Черный список") then
            imgui.BeginChild("tab_blacklist", imgui.ImVec2(-1, -1))
            imgui.Spacing()

            imgui.TextWrapped(u8"Добавьте номера домов, которые нужно исключить из обработки:")
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.Text(u8"Номер дома:")
            imgui.PushItemWidth(200)
            imgui.InputInt("##numberHouse", inputBlackHouse, 0, 0)
            imgui.PopItemWidth()
            imgui.SameLine()
            if imgui.Button(u8"Добавить в список", imgui.ImVec2(UI.Scale(150), 0)) then
                if inputBlackHouse[0] >= 0 then
                    table.insert(settings.main.blackListHouses, inputBlackHouse[0])
                    Storage.SaveSettings()
                    inputBlackHouse[0] = 0
                end
            end

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            if #settings.main.blackListHouses > 0 then
                imgui.Text(u8(string.format("Домов в черном списке: %d", #settings.main.blackListHouses)))
                imgui.Spacing()
                imgui.BeginChild("blacklist_scroll", imgui.ImVec2(-1, -1), true)
                imgui.ScrollMouse()
                for index, blackHouse in ipairs(settings.main.blackListHouses) do
                    if imgui.Button(u8"Удалить##"..index, imgui.ImVec2(UI.Scale(80), 0)) then
                        table.remove(settings.main.blackListHouses, index)
                        Storage.SaveSettings()
                    end
                    imgui.SameLine()
                    imgui.Text(u8(string.format("Дом №%d", blackHouse)))
                    if index < #settings.main.blackListHouses then
                        imgui.Spacing()
                    end
                end
                imgui.EndChild()
            else
                imgui.TextDisabled(u8"Список пуст. Добавьте первый дом.")
            end

            imgui.EndChild()
            imgui.EndTabItem()
        end

        -- ТАБ: Видеокарты (майнинг крипты)
        if imgui.BeginTabItem(u8"Видеокарты") then
            imgui.BeginChild("tab_crypto", imgui.ImVec2(-1, -1))
            imgui.ScrollMouse()
            Draw.CryptoSettings()
            imgui.EndChild()
            imgui.EndTabItem()
        end


        -- ТАБ: Уведомления в Telegram
        if imgui.BeginTabItem(u8"Уведомления") then
            imgui.BeginChild("tab_notifications", imgui.ImVec2(-1, -1))
            imgui.ScrollMouse()
            Draw.SettingsNotifications()
            imgui.EndChild()
            imgui.EndTabItem()
        end

        -- ТАБ 6: Интерфейс
        if imgui.BeginTabItem(u8"Интерфейс") then
            imgui.BeginChild("tab_interface", imgui.ImVec2(-1, -1))
            imgui.ScrollMouse()
            imgui.Spacing()

            if imgui.Checkbox(u8"Скролл пальцем", imgui.new.bool(settings.style.swipeScroll)) then
                settings.style.swipeScroll = not settings.style.swipeScroll
                Storage.SaveSettings()
            end
            if ISNEOMLOADER then
                imgui.TextDisabled(u8"NeoMLoader: скролл пальцем включён экспериментально. Перемещение самого окна пальцем отключено.")
            else
                imgui.TextDisabled(u8"Если включено - списки можно прокручивать свайпом.\nПеремещение окна доступно только за заголовок скрипта.")
            end

            imgui.Spacing()

            imgui.PushItemWidth(-1)

            imgui.Text(u8"Размер полосы прокрутки:")
            local _scrollbarSizeStyle = new.int(settings.style.scrollbarSizeStyle)
            if imgui.SliderInt("##scrollbarSize", _scrollbarSizeStyle, 10, 50, "%d px") then
                settings.style.scrollbarSizeStyle = _scrollbarSizeStyle[0] 
                Storage.SaveSettings()
                imgui.GetStyle().ScrollbarSize = settings.style.scrollbarSizeStyle
            end

            imgui.Spacing()

            imgui.Text(u8"Масштаб интерфейса (DPI):")
            local _MONET_DPI_SCALE = new.float(settings.style.scaleUI)
            if imgui.SliderFloat("##scaleUI", _MONET_DPI_SCALE, 0.5, 3.0, "%.2f") then
                settings.style.scaleUI = _MONET_DPI_SCALE[0]
                Storage.SaveSettings()
            end
            imgui.TextDisabled(u8"Рекомендуемые значения: 1.0 - 2.0")

            imgui.PopItemWidth()

            imgui.Spacing()
            imgui.Separator()
            imgui.CenterText(u8"Цвета интерфейса")
            imgui.Spacing()

            -- Готовые темы
            local spacingX = imgui.GetStyle().ItemSpacing.x
            local presetW = (imgui.GetWindowContentRegionWidth() - spacingX * 2) / 3
            for i, preset in ipairs(UI.COLOR_PRESETS) do
                if (i % 3) ~= 1 then imgui.SameLine() end
                if imgui.Button(u8(preset.name) .. "##colorPreset" .. i, imgui.ImVec2((i % 3 == 0) and -1 or presetW, 0)) then
                    UI.ApplyPreset(i)
                end
            end

            imgui.Spacing()

            Draw.ColorEditRow("Основной цвет", "mainColor", true)
            Draw.ColorEditRow("Цвет текста", "textColor", false)
            Draw.ColorEditRow("Цвет фона", "bgColor", true)
            Draw.ColorEditRow("Акцент", "accentColor", false)
            Draw.ColorEditRow("Префикс скрипта в чате", "chatColor", false)

            imgui.Spacing()
            imgui.Text(u8"Смысловые цвета:")
            Draw.ColorEditRow("Успех / готово", "okColor", false)
            Draw.ColorEditRow("Предупреждение", "warnColor", false)
            Draw.ColorEditRow("Ошибка / опасность", "badColor", false)

            imgui.Spacing()
            imgui.Text(u8"Полосы заполнения:")
            Draw.ColorEditRow("Свободно", "barFreeColor", true)
            Draw.ColorEditRow("Заполнено наполовину", "barHalfColor", true)
            Draw.ColorEditRow("Почти полная", "barFullColor", true)

            imgui.Spacing()
            imgui.Text(u8"Графики в логах:")
            Draw.ColorEditRow("Столбик", "graphBarColor", false)
            Draw.ColorEditRow("Выбранный столбик", "graphActiveColor", false)
            Draw.ColorEditRow("Подложка столбика", "graphBgColor", false)

            imgui.Spacing()
            if imgui.Button(u8"Сбросить цвета к стандартным", imgui.ImVec2(-1, UI.Scale(26))) then
                UI.ResetColors()
                ui_state.colorsDirty = false
            end

            -- настройки пишем на диск только когда пользователь отпустил элемент
            if ui_state.colorsDirty and not imgui.IsAnyItemActive() then
                ui_state.colorsDirty = false
                Storage.SaveSettings()
            end

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            if imgui.Button(u8"Перезапустить скрипт", imgui.ImVec2(-1, UI.Scale(40))) then
                thisScript():reload()
            end

            imgui.Spacing()
            imgui.TextWrapped(u8"Для применения изменения масштаба необходимо перезапустить скрипт.")
            imgui.Spacing()
            imgui.Text(u8"Полезные команды:")
            imgui.BulletText(u8"/mmtr - перезапустить скрипт")
            imgui.BulletText(u8"/mmtsr - сбросить масштаб к значению по умолчанию")

            imgui.EndChild()
            imgui.EndTabItem()
        end

        -- ТАБ 7: Автор
        if imgui.BeginTabItem(u8"Автор") then
            imgui.BeginChild("tab_author", imgui.ImVec2(-1, -1))
            imgui.ScrollMouse()
            imgui.Spacing()

            imgui.Text(u8"Канал автора оригинального MMT: ") imgui.SameLine()
            if imgui.ClickableText("MR.Sand | ARZ MCR & Mobile") then
                Util.OpenUrl("https://t.me/arz_mcr")
            end

            imgui.Text(u8"Автор оригинального MMT: ") imgui.SameLine()
            if imgui.ClickableText("@Mister_Sand") then
                Util.OpenUrl("https://t.me/Mister_Sand")
            end

            imgui.Text(u8"Автор форка под Rodina: ") imgui.SameLine()
            if imgui.ClickableText("@rozovscam") then
                Util.OpenUrl("https://t.me/rozovscam")
            end
            imgui.TextWrapped(u8"По всем вопросам, багам и предложениям по Rodina-версии пишите автору форка.")

            imgui.Spacing()
            imgui.Text(u8"Поддержать автора оригинального MMT: ") imgui.SameLine()
            if imgui.ClickableText("Boosty") then
                Util.OpenUrl("https://boosty.to/sand-mcr")
            end
            imgui.Text(u8"Тема оригинального MMT на Blast.hk: ") imgui.SameLine()
            if imgui.ClickableText("MMT | Mining Tool") then
                Util.OpenUrl("https://www.blast.hk/threads/242059/")
            end


            imgui.Spacing()
            imgui.Separator()

            imgui.EndChild()
            imgui.EndTabItem()
        end

        -- ТАБ 8: Техническая информация (только если есть данные)
        if #stateCrypto.queueShelves > 0 then
            if imgui.BeginTabItem(u8"Тех. состояние") then
                imgui.BeginChild("tab_techstate", imgui.ImVec2(-1, -1))
                imgui.Spacing()

                imgui.Text(u8(string.format("Количество активных полок: %d", #stateCrypto.queueShelves)))
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                imgui.BeginChild("tech_state_scroll", imgui.ImVec2(-1, -1), true)
                imgui.ScrollMouse()

                imgui.Columns(4, "tech_columns", true)
                imgui.SetColumnWidth(0, 100)
                imgui.SetColumnWidth(1, 100)
                imgui.SetColumnWidth(2, 100)
                imgui.SetColumnWidth(3, 150)

                imgui.Text(u8"Строка")
                imgui.NextColumn()
                imgui.Text(u8"Заливка")
                imgui.NextColumn()
                imgui.Text(u8"Крипты")
                imgui.NextColumn()
                imgui.Text(u8"Состояние")
                imgui.NextColumn()
                imgui.Separator()

                -- Данные
                for index, value in ipairs(stateCrypto.queueShelves) do
                    imgui.Text(u8(tostring(value.samp_line)))
                    imgui.NextColumn()
                    imgui.Text(u8(tostring(value.fill)))
                    imgui.NextColumn()
                    imgui.Text(u8(tostring(value.count)))
                    imgui.NextColumn()
                    imgui.Text(u8(tostring(value.work)))
                    imgui.NextColumn()
                    if index < #stateCrypto.queueShelves then
                        imgui.Separator()
                    end
                end

                imgui.Columns(1)
                imgui.EndChild()

                imgui.EndChild()
                imgui.EndTabItem()
            end
        end

        imgui.EndTabBar()
    end

    imgui.EndChild()
end


function Draw.Houses()
    local totalHouse = #houses
    local lowCycles = 0
    for i, house in ipairs(houses) do
        if house.cycles < 100 then
            lowCycles = lowCycles + 1
        end
    end

    -- Отображение статистики
    imgui.Text(u8(string.format("Найдено домов: %d", totalHouse)))
    imgui.SameLine()
    imgui.TextColoredRGB(string.format("  Мало циклов:{%s} %d", COLORS.RED, lowCycles))

    imgui.Separator()

    local button_width = (imgui.GetWindowWidth() - UI.Scale(30)) / 2
    if imgui.ButtonClickable(not stateCrypto.work, fa.HAND_HOLDING_DOLLAR .. u8"\tСобрать всю прибыль", imgui.ImVec2(button_width, 0)) then
        UI.StartInteractionSafe("take", "ui")
    end
    imgui.SameLine()
    if imgui.ButtonClickable(not stateCrypto.work, fa.PLAY .. u8"\tВключить все видеокарты", imgui.ImVec2(-1, 0)) then
        UI.StartInteractionSafe("on", "ui")
    end

    if stateCrypto.work then
        imgui.ProgressBar(stateCrypto.progressHouses/#stateCrypto.queueHouses,imgui.ImVec2(-1,0), u8"Дом "..stateCrypto.progressHouses.."/"..#stateCrypto.queueHouses)
    end
    if stateCrypto.work then
        imgui.ProgressBar(stateCrypto.progressShelves/#stateCrypto.queueShelves,imgui.ImVec2(-1,0), u8"Полка "..stateCrypto.progressShelves.."/"..#stateCrypto.queueShelves)
    end

    imgui.Separator()

    imgui.BeginChild("list", imgui.ImVec2(-1, -1))
    imgui.ScrollMouse()
    lastOpenHouse = UI.HandleListNavigation(
         math.maxEx(1, math.minEx(lastOpenHouse, #houses)),
        #houses,
        function(idx)
            local house = houses[idx]
            if house then
                sampSendDialogResponse(idDialogs.selectHouse, 1, house.samp_line, "")
                houses = {}
            end
        end
    )
    for i, house in ipairs(houses) do
        -- Определяем цвет по оставшимся циклам
        local cycles_color = house.cycles < 100 and COLORS.RED or COLORS.WHITE -- красный если < 100, белый если >= 100


        local house_data = housesData[tostring(house.house_number)]
        local house_data_str = house_data and string.format("Раб. вид-карт: %s  Мкс. крипты: {%s}%d{%s}  Мин. охлада: {%s}%d{%s}",
            house_data.work_vc,
            house_data.max_collect >= math.minEx(9, math.maxEx(1, tonumber(settings.main.maxCollectAlert) or 9)) and COLORS.RED or house_data.max_collect > 1 and COLORS.GREEN or COLORS.WHITE,
            tonumber(house_data.max_collect),
            COLORS.WHITE,
            house_data.min_liquid == 0 and COLORS.RED or house_data.min_liquid < settings.main.fillFrom and COLORS.YELLOW or COLORS.WHITE,
            house_data.min_liquid,
            COLORS.WHITE
        ) or "-"

        local house_text = string.format("Дом %s  {%s}%s  Налог: %s  {%s}Циклов: {%s}%s",
            house.house_number,
            COLORS.WHITE,
            house_data_str,
            house.tax,
            COLORS.WHITE,
            cycles_color,
            Util.GetCommaValue(house.cycles)
        )

        if imgui.SelectableEx(i, house_text, lastOpenHouse == i, imgui.SelectableFlags.SpanAllColumns) and UI.IsClick() then
            lastOpenHouse = i
            sampSendDialogResponse(idDialogs.selectHouse, 1, house.samp_line, "")
            houses = {}
        end

        -- небольшой отступ между домами
        if i < #houses then
            imgui.Spacing()
        end
    end
    imgui.EndChild()
end

function Draw.Shelves()
    -- Подсчет статистики полок
    local total_shelves = #shelves
    local working_shelves = 0
    local not_working_shelves = 0
    local low_liauid = 0

    for _, shelf in ipairs(shelves) do
        if shelf.status:find("Работает") then
            working_shelves = working_shelves + 1
        else
            not_working_shelves = not_working_shelves + 1
        end

        if shelf.percentage <= settings.main.fillFrom then
            low_liauid = low_liauid + 1
        end
    end

    -- Отображение статистики
    imgui.Text(u8(string.format("Найдено полок: %d", total_shelves)))
    imgui.SameLine()
    imgui.TextColoredRGB(string.format("  Работают:{%s} %d",
        working_shelves > 0 and COLORS.GREEN or COLORS.RED,
        working_shelves))
    imgui.SameLine()
    imgui.TextColoredRGB(string.format("  Не работают:{%s} %d", COLORS.RED, not_working_shelves))
    imgui.TextColoredRGB(string.format("Нет или мало охлаждайки:{%s} %d", COLORS.YELLOW, low_liauid))
    local rodinaLiquidCount = RodinaCooling.inventoryKnown and tostring(haveLiquid.btc) or "?"
    imgui.Text(u8(string.format("Охлаждающей жидкости в инвентаре: %s", rodinaLiquidCount)))

    imgui.Spacing()

    local totalWidth = (imgui.GetWindowWidth() - UI.Scale(30))
    local half    = totalWidth / 2
    local quarter = (totalWidth / 4) - (imgui.GetStyle().ItemSpacing.x / 2)

    if imgui.ButtonClickable(not stateCrypto.work, fa.HAND_HOLDING_DOLLAR .. u8"\tСобрать", imgui.ImVec2(half, 0)) then
        UI.StartInteractionSafe("take", "ui")
    end
    imgui.SameLine()
    if imgui.ButtonClickable(not stateCrypto.work, fa.FILL_DRIP .. u8"\tЗалить", imgui.ImVec2(quarter, 0)) then
        UI.StartInteractionSafe("fill", "ui")
    end

    imgui.SameLine()

    local autoIcon  = settings.main.autoFillEnabled and fa.TOGGLE_ON or fa.TOGGLE_OFF
    local autoTitle = settings.main.autoFillEnabled and u8"Автозаливка: вкл" or u8"Автозаливка: выкл"
    if imgui.Button(autoIcon .. "\t" .. autoTitle, imgui.ImVec2(-1, 0)) then
        settings.main.autoFillEnabled = not settings.main.autoFillEnabled
        Storage.SaveSettings()
        Chat.Add("Автозаливка: " .. (settings.main.autoFillEnabled and "включена" or "выключена"), TYPECHATMESSAGES.SECONDARY)
    end

    local toggleEnableIcon  = settings.main.autoEnableCards and fa.TOGGLE_ON or fa.TOGGLE_OFF
    local toggleEnableTitle = settings.main.autoEnableCards and u8"Автовкл: вкл" or u8"Автовкл: выкл"

    if imgui.ButtonClickable(not stateCrypto.work, fa.PLAY .. u8"\tВключить карты", imgui.ImVec2(quarter, 0)) then
        UI.StartInteractionSafe("on", "ui")
    end
    imgui.SameLine()
    if imgui.Button(toggleEnableIcon .. "\t" .. toggleEnableTitle, imgui.ImVec2(quarter, 0)) then
        settings.main.autoEnableCards = not settings.main.autoEnableCards
        Storage.SaveSettings()
        Chat.Add("Автовключение карт после сбора: " .. (settings.main.autoEnableCards and "включено" or "выключено"), TYPECHATMESSAGES.SECONDARY)
    end
    imgui.SameLine()
    if imgui.ButtonClickable(not stateCrypto.work, fa.PAUSE .. u8"\tОтключить карты", imgui.ImVec2(-1, 0)) then
        UI.StartInteractionSafe("off", "ui")
    end
    if stateCrypto.work then
        imgui.ProgressBar(stateCrypto.progressShelves/#stateCrypto.queueShelves,imgui.ImVec2(-1,0), stateCrypto.progressShelves.."/"..#stateCrypto.queueShelves)
    end

    local currentHouseNumber = tonumber(stateCrypto.activeHouseID)
    local currentHouseBonusPercent = CalcHouseIncomeBonusPercent(currentHouseNumber)
    local inc = GetIncomeSettings()
    if currentHouseNumber and currentHouseNumber >= 0 then
        imgui.Text(u8(string.format("Дом №%d | Бонус доходности: +%.2f%%", currentHouseNumber, currentHouseBonusPercent)))
    end

    imgui.Separator()

    imgui.BeginChild("list", imgui.ImVec2(-1, -1))
    imgui.ScrollMouse()
    lastOpenShelves = UI.HandleListNavigation(
         math.maxEx(1, math.minEx(lastOpenShelves, #shelves)),
        #shelves,
        function(idx)
            local shelf = shelves[idx]
            if shelf then
                sampSendDialogResponse(lastIDDialog, 1, shelf.samp_line, "")
                imguiWindows.main[0] = false
            end
        end
    )
    for i, shelf in ipairs(shelves) do
        local shelf_in_rack = math.floor(i / 4) + 1

        -- Показываем заголовок стойки только для первой полки в стойке
        if shelf.shelf_number == 1 and #shelves > 4 then
            if i > 1 then imgui.Spacing() end
            imgui.Text(u8(string.format("=== Стойка №%d ===", shelf_in_rack)))
        end

        local cooling_color = COLORS.WHITE
        if shelf.percentage == 0 then
            cooling_color = COLORS.RED
        elseif shelf.percentage <= settings.main.fillFrom then
            cooling_color = COLORS.YELLOW
        end

        local gpu_color = COLORS.RED
        if shelf.status:find("Работает") then
            gpu_color = COLORS.GREEN
        end

        local profit_color = (shelf.profit or 0) >= 1 and COLORS.GREEN or COLORS.WHITE -- зеленый если можно собрать, белый если нельзя

        -- Расчёт ожидаемой выработки по уровню + остаток до доливки
        local per_h, per_24h, per_cycle, hours_left, income_left =
            CalcGpuIncome(shelf.level, shelf.percentage, settings.main.fillFrom, currentHouseBonusPercent)

        -- Собираем суффикс по настройкам
        local parts = {}

        if inc.showPerHour  then table.insert(parts, string.format("%.2f/ч",   per_h))     end
        if inc.showPer24h   then table.insert(parts, string.format("%.2f/24ч", per_24h))   end
        if inc.showPerCycle then table.insert(parts, string.format("%.2f/цикл", per_cycle)) end

        local income_suffix = ""
        if #parts > 0 then
            income_suffix = " | Доход: " .. table.concat(parts, " | ")
        end

        -- Доп. блок "до доливки": часы и прибыль, если есть запас > 0
        if inc.showTillThresholdHours then -- and hours_left > 0
            local hh = math.floor(hours_left)
            local mm = math.floor((hours_left - hh) * 60 + 0.5)
            income_suffix = income_suffix .. string.format(" | До %s: %dч:%02dм",
                shelf.percentage > settings.main.fillFrom and "доливки" or "заливки", hh, mm)
        end
        if inc.showTillThresholdProfit then -- and hours_left > 0
            income_suffix = income_suffix .. string.format(" | Принесет: %.2f %s", income_left, shelf.currency)
        end

        -- Итоговая строка
        local _text = ""
        if shelf.profit2 then
            _text = string.format(
                "№%d Ур.%d {%s}%s {%s}%.6f %s | %.6f %s {%s}%.1f%%%s",
                shelf.shelf_number,
                shelf.level,
                gpu_color, shelf.status,
                profit_color, shelf.profit_primary or shelf.profit, shelf.currency, shelf.profit2, shelf.currency2,
                cooling_color, shelf.percentage,
                income_suffix
            )
        else
            _text = string.format(
                "№%d Ур.%d {%s}%s {%s}%.6f %s {%s}%.1f%%%s",
                shelf.shelf_number,
                shelf.level,
                gpu_color, shelf.status,
                profit_color, shelf.profit, shelf.currency,
                cooling_color, shelf.percentage,
                income_suffix
            )
        end

        if imgui.SelectableEx(i, _text, lastOpenShelves == i, imgui.SelectableFlags.SpanAllColumns) and UI.IsClick() then
            lastOpenShelves = i
            sampSendDialogResponse(lastIDDialog, 1, shelf.samp_line, "")
            imguiWindows.main[0] = false
        end
    end
    imgui.EndChild()
end

-- --------------------------------------------------------
--                           Extension
-- --------------------------------------------------------

function UI.IsClick()
    return not ui_state.swipe.is_gesture
end

function imgui.MoveOnTitleBar()
    if ISNEOMLOADER or not settings.style.swipeScroll then return end

    local io = imgui.GetIO()
    local win_pos = imgui.GetWindowPos()
    local win_sz  = imgui.GetWindowSize()

    local grab_height = UI.Scale(28)
    local grab_offset = 6

    -- Новый ЛКМ-клик -> сбрасываем информацию о свайпе и запоминаем
    -- стартовую позицию сами. NeoMLoader mimgui не содержит поля
    -- ImGuiIO.MouseDragMaxDistanceAbs, которое есть в части Monet-сборок.
    if io.MouseClicked[0] then
        ui_state.swipe.is_gesture = false
        ui_state.swipe.start_x = io.MousePos.x
        ui_state.swipe.start_y = io.MousePos.y
    end

    -- Не полагаемся на внутреннее поле ImGuiIO: считаем расстояние от точки
    -- нажатия вручную. Это одинаково работает на MonetLoader и NeoMLoader.
    if io.MouseDown[0] then
        local start_x = ui_state.swipe.start_x or io.MousePos.x
        local start_y = ui_state.swipe.start_y or io.MousePos.y
        local dx = math.abs(io.MousePos.x - start_x)
        local dy = math.abs(io.MousePos.y - start_y)
        if dx > ui_state.swipe.DRAG_THRESHOLD or dy > ui_state.swipe.DRAG_THRESHOLD then
            ui_state.swipe.is_gesture = true
        end
    else
        ui_state.swipe.start_x = nil
        ui_state.swipe.start_y = nil
    end

    local mouse_over_grab =
        imgui.IsWindowHovered() and
        io.MousePos.x >= win_pos.x and
        io.MousePos.x <= win_pos.x + win_sz.x and
        io.MousePos.y >= win_pos.y + grab_offset and
        io.MousePos.y <= win_pos.y + grab_offset + grab_height

    if mouse_over_grab and io.MouseClicked[0] then
        ui_state.drag.active = true
        ui_state.drag.mx, ui_state.drag.my = io.MousePos.x, io.MousePos.y

        -- стартовая позиция окна - либо текущая, либо последняя сохранённая
        ui_state.drag.wx = windowPos and windowPos.x or win_pos.x
        ui_state.drag.wy = windowPos and windowPos.y or win_pos.y
    end

    if ui_state.drag.active then
        if not io.MouseDown[0] then
            ui_state.drag.active = false
        else
            local dx = io.MousePos.x - ui_state.drag.mx
            local dy = io.MousePos.y - ui_state.drag.my

            -- обновляем желаемую позицию окна; применится в следующем кадре через SetNextWindowPos
            windowPos = imgui.ImVec2(ui_state.drag.wx + dx, ui_state.drag.wy + dy)
        end
    end
end

function imgui.ScrollMouse()
    if not settings.style.swipeScroll then return end

    local io = imgui.GetIO()
    -- Ховер именно по текущему дочернему окну.
    local hovered = imgui.IsWindowHovered()

    -- Начало нового касания. Gesture-state сбрасываем только здесь, чтобы на
    -- кадре отпускания после свайпа UI.IsClick() всё ещё мог заблокировать
    -- случайное нажатие кнопки/строки под пальцем.
    if hovered and io.MouseClicked[0] then
        ui_state.swipe.active = true
        ui_state.swipe.is_gesture = false
        ui_state.swipe.start_x = io.MousePos.x
        ui_state.swipe.start_y = io.MousePos.y
    end

    if ui_state.swipe.active and io.MouseDown[0] then
        local start_x = ui_state.swipe.start_x or io.MousePos.x
        local start_y = ui_state.swipe.start_y or io.MousePos.y
        local dx = math.abs(io.MousePos.x - start_x)
        local dy = math.abs(io.MousePos.y - start_y)

        if dx > ui_state.swipe.DRAG_THRESHOLD or dy > ui_state.swipe.DRAG_THRESHOLD then
            ui_state.swipe.is_gesture = true
        end

        -- Прокручиваем по фактической дельте пальца/мыши.
        local current = imgui.GetScrollY()
        local maxy = imgui.GetScrollMaxY()
        local newY = current - io.MouseDelta.y

        if newY < 0 then newY = 0 end
        if newY > maxy then newY = maxy end

        imgui.SetScrollY(newY)
    end

    if not io.MouseDown[0] then
        ui_state.swipe.active = false
        ui_state.swipe.start_x = nil
        ui_state.swipe.start_y = nil
        -- is_gesture намеренно не сбрасываем здесь; он сбросится на следующем
        -- MouseClicked и защищает от клика по элементу в конце свайпа.
    end
end

-- Кнопка акцентным цветом: для главных действий (запуск, обновление, сбор)
function imgui.AccentButton(label, size)
    local col = UI.Vec4('accentColor')
    -- на светлом акценте белый текст не читается - берём тёмный
    local lum = col.x * 0.299 + col.y * 0.587 + col.z * 0.114
    local darkText = lum > 0.6

    imgui.PushStyleColor(imgui.Col.Button, col)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, Shade(col, 1.18))
    imgui.PushStyleColor(imgui.Col.ButtonActive, Shade(col, 0.85))
    if darkText then
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.10, 0.10, 0.10, 1.0))
    end

    local pressed = imgui.Button(label, size)

    imgui.PopStyleColor(darkText and 4 or 3)
    return pressed
end

function imgui.AccentButtonClickable(clickable, label, size)
    if clickable then
        return imgui.AccentButton(label, size)
    end
    return imgui.ButtonClickable(false, label, size)
end

function imgui.ButtonClickable(clickable, ...)
    if clickable then
        return imgui.Button(...)
    else
        local rcol = (imgui.GetStyle().Colors[imgui.Col.Button])
		local r, g, b, a = rcol.x, rcol.y, rcol.z, rcol.w
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(r, g, b, a/2) )
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(r, g, b, a/2))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(r, g, b, a/2))
        imgui.PushStyleColor(imgui.Col.Text, imgui.GetStyle().Colors[imgui.Col.TextDisabled])
            imgui.Button(...)
        imgui.PopStyleColor(4)
    end
end

-- Функция для создания кнопки, выровненной по правому краю
function imgui.RightButton(label)
    local _clearLabel = label:gsub("##.*$", "")
    imgui.SetItemRight(_clearLabel)

    if imgui.Button(label) then
        return true
    end
end

function imgui.SetItemRight(label)
    local window_size = imgui.GetWindowSize()

    local button_size = imgui.CalcTextSize(label)
    button_size.x = button_size.x + imgui.GetStyle().FramePadding.x * 2
    button_size.y = button_size.y + imgui.GetStyle().FramePadding.y * 2

    local _offsetScroll = imgui.GetScrollMaxY() > 0 and imgui.GetStyle().ScrollbarSize or 0
    local new_cursor_pos_x = window_size.x - button_size.x - imgui.GetStyle().WindowPadding.x - _offsetScroll
    imgui.SetCursorPosX(new_cursor_pos_x)
end

function imgui.CenterText(text, size)
	local _size = size or imgui.GetWindowWidth()
	imgui.SetCursorPosX((_size - imgui.CalcTextSize(tostring(text)).x) / 2)
	imgui.Text(tostring(text))
end

function imgui.TextColoredRGB(text)
    local style = imgui.GetStyle()
    local colors = style.Colors[imgui.Col.Text]
    local ImVec4 = imgui.ImVec4
    local explode_argb = function(argb)
        local a = bit.band(bit.rshift(argb, 24), 0xFF)
        local r = bit.band(bit.rshift(argb, 16), 0xFF)
        local g = bit.band(bit.rshift(argb, 8), 0xFF)
        local b = bit.band(argb, 0xFF)
        return a, r, g, b
    end
    local getcolor = function(color)
        if color:sub(1, 6):upper() == 'SSSSSS' then
            local r, g, b = colors.x, colors.y, colors.z
            local a = tonumber(color:sub(7, 8), 16) or colors.w * 255
            return ImVec4(r, g, b, a / 255)
        end
        local color = type(color) == 'string' and tonumber(color, 16) or color
        if type(color) ~= 'number' then return end
        local r, g, b, a = explode_argb(color)
        return imgui.ImVec4(r/255, g/255, b/255, a/255)
    end
    local render_text = function(text_)
        for w in text_:gmatch('[^\r\n]+') do
            local text, colors_, m = {}, {}, 1
            w = w:gsub('{(......)}', '{%1FF}')
            while w:find('{........}') do
                local n, k = w:find('{........}')
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end
                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end
            if text[0] then
                for i = 0, #text do
                    imgui.TextColored(colors_[i] or colors, u8(text[i]))
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else imgui.Text(u8(w)) end
        end
    end
    render_text(text)
end

function imgui.SelectableEx(id, label, selected, flags, imVecSize)
    if imgui.Selectable("##"..id.."-"..label, selected, flags, imVecSize) then
        return true
    end
    imgui.SameLine()
    imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetStyle().ItemInnerSpacing.x)
    imgui.TextColoredRGB(label)
end

function imgui.ClickableText(text, url)
    -- Цвет ссылки
    local linkColor = imgui.ImVec4(0.4, 0.7, 1.0, 1.0)
    local hoverColor = imgui.ImVec4(0.6, 0.85, 1.0, 1.0)

    local isHovered = false

    -- Определяем цвет в зависимости от состояния
    imgui.PushStyleColor(imgui.Col.Text, linkColor)

    -- Добавляем иконку ссылки перед текстом
    imgui.Text(text)

    isHovered = imgui.IsItemHovered()

    if isHovered then
        imgui.SetMouseCursor(imgui.MouseCursor.Hand)

        -- Подчёркивание
        local min = imgui.GetItemRectMin()
        local max = imgui.GetItemRectMax()
        imgui.GetWindowDrawList():AddLine(
            imgui.ImVec2(min.x, max.y),
            imgui.ImVec2(max.x, max.y),
            imgui.GetColorU32Vec4(hoverColor),
            1.0
        )

        imgui.PopStyleColor(1)

        -- Всплывающая подсказка с URL
        if url then
            imgui.SetTooltip(u8"Нажмите, чтобы открыть:\n" .. url)
        else
            imgui.SetTooltip(u8"Нажмите для перехода")
        end
    else
        imgui.PopStyleColor(1)
    end

    if imgui.IsItemClicked() then
        return true
    end
    return false
end

-- --------------------------------------------------------
--                           Style
-- --------------------------------------------------------

local function MainStyle()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2
    style.WindowPadding = ImVec2(8, 8)
    style.WindowRounding = 10
    style.ChildRounding = 8
    style.FramePadding = ImVec2(6, 4)
    style.FrameRounding = 8
    style.ItemSpacing = ImVec2(6, 6)
    style.ItemInnerSpacing = ImVec2(4, 4)
    style.IndentSpacing = 21
    style.ScrollbarSize = settings.style.scrollbarSizeStyle
    style.ScrollbarRounding = 13
    style.GrabMinSize = 8
    style.GrabRounding = 1
    style.WindowTitleAlign = ImVec2(0.5, 0.5)
    style.ButtonTextAlign = ImVec2(0.5, 0.5)
    return colors, clr, ImVec4
end

local function MainStyleMobile()
    if imgui.IsInitialized() then
        imgui.SwitchContext()
    end
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2
    style.WindowPadding = ImVec2(8, 8)
    style.WindowRounding = 10*MONET_DPI_SCALE
    style.ChildRounding = 8*MONET_DPI_SCALE
    style.FramePadding = ImVec2(6, 4)
    style.FrameRounding = 8*MONET_DPI_SCALE
    style.ItemSpacing = ImVec2(6*MONET_DPI_SCALE, 6*MONET_DPI_SCALE)
    style.ItemInnerSpacing = ImVec2(4, 4)
    style.IndentSpacing = 21
    style.ScrollbarSize = settings.style.scrollbarSizeStyle
    style.ScrollbarRounding = 13*MONET_DPI_SCALE
    style.GrabMinSize = 8
    style.GrabRounding = 1*MONET_DPI_SCALE
    style.WindowTitleAlign = ImVec2(0.5, 0.5)
    style.ButtonTextAlign = ImVec2(0.5, 0.5)
    return colors, clr, ImVec4
end

-- Цвет из настроек как ImVec4
function UI.Vec4(key, alphaOverride)
    local c = settings.style[key] or {}
    return imgui.ImVec4(c.r or 0, c.g or 0, c.b or 0, alphaOverride or c.a or 1.0)
end

-- Цвет { r, g, b } -> строка "RRGGBB" для чата и {цветовых} вставок
function UI.ColorToHex(color)
    local function byte(v)
        return math.floor(math.maxEx(0, math.minEx(1, tonumber(v) or 0)) * 255 + 0.5)
    end
    color = color or {}
    return string.format('%02X%02X%02X', byte(color.r), byte(color.g), byte(color.b))
end

-- Смысловые цвета текста и цвет префикса в чате
function UI.RefreshSemanticColors()
    local st = settings.style
    COLORS.WHITE  = UI.ColorToHex(st.textColor)
    COLORS.GREEN  = UI.ColorToHex(st.okColor)
    COLORS.YELLOW = UI.ColorToHex(st.warnColor)
    COLORS.RED    = UI.ColorToHex(st.badColor)

    local chatHex = UI.ColorToHex(st.chatColor)
    st.colorChat = chatHex
    st.colorMessage = tonumber('FF' .. chatHex, 16) or 0xFF8cbf91
end

-- Применение цветов к текущему стилю imgui (безопасно вызывать прямо в кадре)
function UI.ApplyStyleColors()
    local colors = imgui.GetStyle().Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4

    local mainColor = settings.style.mainColor
    local textColor = settings.style.textColor
    local bgColor = settings.style.bgColor

    colors[clr.Text] = ImVec4(textColor.r, textColor.g, textColor.b, textColor.a)
    colors[clr.TextDisabled] = ImVec4(textColor.r * 0.5, textColor.g * 0.5, textColor.b * 0.5, textColor.a)
    colors[clr.WindowBg] = ImVec4(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    colors[clr.PopupBg] = ImVec4(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    colors[clr.Border] = ImVec4(mainColor.r, mainColor.g, mainColor.b, 1)
    colors[clr.BorderShadow] = ImVec4(mainColor.r + 0.1, mainColor.g + 0.1, mainColor.b + 0.1, 0.1)
    colors[clr.FrameBg] = ImVec4(mainColor.r, mainColor.g, mainColor.b, mainColor.a)
    colors[clr.FrameBgHovered] = ImVec4(mainColor.r + 0.05, mainColor.g + 0.05, mainColor.b + 0.05, mainColor.a)
    colors[clr.FrameBgActive] = ImVec4(mainColor.r + 0.1, mainColor.g + 0.1, mainColor.b + 0.1, mainColor.a)
    colors[clr.Button] = ImVec4(mainColor.r, mainColor.g, mainColor.b, mainColor.a * 0.83)
    colors[clr.ButtonHovered] = ImVec4(mainColor.r * 0.8, mainColor.g * 0.8, mainColor.b * 0.8, mainColor.a * 0.83)
    colors[clr.ButtonActive] = ImVec4(mainColor.r + 0.05, mainColor.g + 0.05, mainColor.b + 0.05, mainColor.a * 0.83)
    colors[clr.Header] = ImVec4(mainColor.r, mainColor.g, mainColor.b, mainColor.a * 0.83)
    colors[clr.HeaderHovered] = ImVec4(mainColor.r * 0.8, mainColor.g * 0.8, mainColor.b * 0.8, mainColor.a * 0.83)
    colors[clr.HeaderActive] = ImVec4(mainColor.r + 0.05, mainColor.g + 0.05, mainColor.b + 0.05, mainColor.a * 0.83)
    colors[clr.Separator] = ImVec4(mainColor.r, mainColor.g, mainColor.b, 1)
    colors[clr.SeparatorHovered] = ImVec4(mainColor.r + 0.05, mainColor.g + 0.05, mainColor.b + 0.05, 1)
    colors[clr.SeparatorActive] = ImVec4(mainColor.r + 0.1, mainColor.g + 0.1, mainColor.b + 0.1, 1)
    colors[clr.ResizeGrip] = ImVec4(mainColor.r * 1.2, mainColor.g * 1.3, mainColor.b * 1.4, 1)
    colors[clr.ResizeGripHovered] = ImVec4(mainColor.r * 1.1, mainColor.g * 1.2, mainColor.b * 1.3, 1)
    colors[clr.ResizeGripActive] = ImVec4(mainColor.r * 1.3, mainColor.g * 1.4, mainColor.b * 1.5, 1)
    colors[clr.PlotLines] = ImVec4(mainColor.r * 0.8, mainColor.g * 0.9, mainColor.b, 1)
    colors[clr.PlotLinesHovered] = ImVec4(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    colors[clr.PlotHistogram] = ImVec4(mainColor.r + 0.1, mainColor.g + 0.1, mainColor.b + 0.1, 1)
    colors[clr.PlotHistogramHovered] = ImVec4(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    colors[clr.TextSelectedBg] = ImVec4(mainColor.r * 0.7, mainColor.g * 0.8, mainColor.b * 0.9, 1)
    colors[clr.ModalWindowDimBg] = ImVec4(0, 0, 0, 0.7)

    -- Продолжение с настройками для остальных элементов
    colors[clr.TitleBg] = ImVec4(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    colors[clr.TitleBgActive] = ImVec4(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    colors[clr.TitleBgCollapsed] = ImVec4(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    colors[clr.MenuBarBg] = ImVec4(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    colors[clr.ScrollbarBg] = ImVec4(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    colors[clr.ScrollbarGrab] = ImVec4(mainColor.r * 2, mainColor.g * 2, mainColor.b * 2, 1)
    colors[clr.ScrollbarGrabHovered] = ImVec4(mainColor.r * 2.4, mainColor.g * 2.4, mainColor.b * 2.4, 1)
    colors[clr.ScrollbarGrabActive] = ImVec4(mainColor.r * 2.2, mainColor.g * 2.2, mainColor.b * 2.2, 1)
    colors[clr.CheckMark] = ImVec4(mainColor.r * 1.2, mainColor.g * 1.4, mainColor.b * 1.6, 1)
    colors[clr.SliderGrab] = ImVec4(mainColor.r * 1.2, mainColor.g * 1.3, mainColor.b * 1.4, 1)
    colors[clr.SliderGrabActive] = ImVec4(mainColor.r, mainColor.g, mainColor.b, 1)

    colors[clr.Tab]                    = colors[clr.WindowBg]
    colors[clr.TabHovered]             = colors[clr.ButtonHovered]
    colors[clr.TabActive]              = colors[clr.FrameBg]
end

-- Цвета целиком: стиль окна + смысловые цвета текста + чат
function UI.ApplyColors()
    UI.ApplyStyleColors()
    UI.RefreshSemanticColors()
end

-- Полная установка стиля: отступы/скругления (зависят от платформы) + цвета
function UI.SetStyle(mobile)
    if mobile == nil then mobile = ISMONETLOADER end
    if mobile then
        MainStyleMobile()
    else
        MainStyle()
    end
    UI.ApplyColors()
end

-- Готовые темы
UI.COLOR_PRESETS = {
    { name = 'Зелёная',    main = { 0.25, 0.45, 0.28 }, bg = { 0.10, 0.15, 0.14 }, text = { 0.80, 0.85, 0.80 }, accent = { 0.27, 0.25, 0.45 }, chat = { 0.55, 0.75, 0.57 } },
    { name = 'Синяя',      main = { 0.20, 0.35, 0.55 }, bg = { 0.09, 0.12, 0.17 }, text = { 0.82, 0.86, 0.92 }, accent = { 0.30, 0.55, 0.80 }, chat = { 0.55, 0.72, 0.95 } },
    { name = 'Фиолетовая', main = { 0.35, 0.27, 0.52 }, bg = { 0.12, 0.10, 0.17 }, text = { 0.86, 0.83, 0.92 }, accent = { 0.55, 0.45, 0.80 }, chat = { 0.72, 0.62, 0.95 } },
    { name = 'Оранжевая',  main = { 0.50, 0.33, 0.16 }, bg = { 0.15, 0.12, 0.09 }, text = { 0.92, 0.87, 0.80 }, accent = { 0.85, 0.55, 0.25 }, chat = { 0.95, 0.72, 0.42 } },
    { name = 'Вишнёвая',   main = { 0.46, 0.20, 0.26 }, bg = { 0.15, 0.09, 0.11 }, text = { 0.92, 0.83, 0.85 }, accent = { 0.80, 0.35, 0.42 }, chat = { 0.95, 0.58, 0.62 } },
    { name = 'Графит',     main = { 0.27, 0.29, 0.32 }, bg = { 0.11, 0.12, 0.13 }, text = { 0.85, 0.86, 0.88 }, accent = { 0.45, 0.48, 0.52 }, chat = { 0.75, 0.78, 0.82 } },
}

function UI.ApplyPreset(index)
    local preset = UI.COLOR_PRESETS[tonumber(index) or 0]
    if not preset then return end

    local st = settings.style
    local function set(target, rgb, alpha)
        target.r, target.g, target.b = rgb[1], rgb[2], rgb[3]
        target.a = alpha or 1.00
    end

    set(st.mainColor, preset.main)
    set(st.bgColor, preset.bg, 0.98)
    set(st.textColor, preset.text)
    set(st.accentColor, preset.accent)
    set(st.chatColor, preset.chat)

    UI.ApplyColors()
    Storage.SaveSettings()
end

-- Сброс всех цветов к значениям по умолчанию
function UI.ResetColors()
    local st = settings.style
    for _, key in ipairs({ 'mainColor', 'textColor', 'bgColor', 'accentColor', 'chatColor',
                           'okColor', 'warnColor', 'badColor',
                           'barFreeColor', 'barHalfColor', 'barFullColor',
                           'graphBarColor', 'graphActiveColor', 'graphBgColor' }) do
        local src = defaultSettings.style[key]
        if src then
            st[key] = { r = src.r, g = src.g, b = src.b, a = src.a }
        end
    end
    UI.ApplyColors()
    Storage.SaveSettings()
end
