script_name('rhl')
script_author('krvdd')
script_version('2.0')

local imgui  = require 'mimgui'
local sampev = require 'lib.samp.events'
local ffi    = require 'ffi'
local inicfg = require 'inicfg'
local socket = require 'socket'

local dlstatus = require('moonloader').download_status

pcall(ffi.cdef, [[
    void* malloc(size_t size);
    void free(void* ptr);
]])

local ini = inicfg.load({ cfg = {
    skipEnabled=false, pickupSkipEnabled=false,
    realtorEnabled=false,
    captchaTimerEnabled=false, fastMapEnabled=false,
    speedometerEnabled=false, hotButtonsLocked=false, clockLocked=false, styleWinEnabled=false,
    uiAlpha=1.0, speedoPosX=1150, speedoPosY=580,
    accentColorR=0.72, accentColorG=0.15, accentColorB=0.20,
    btnBgColorR=0.09, btnBgColorG=0.03, btnBgColorB=0.04, btnBgColorA=0.92,
    btnBorderColorR=0.55, btnBorderColorG=0.15, btnBorderColorB=0.20, btnBorderColorA=1.0,
    btnTextColorR=1.0,  btnTextColorG=1.0,  btnTextColorB=1.0,  btnTextColorA=1.0,
    btnThickness=2.0, btnOutlineEnabled=true, btnBgEnabled=true,
    btnRounding=6.0,
    mapBtnW=80.0, mapBtnH=35.0, mapBtnPosX=100.0, mapBtnPosY=200.0,
    styleBtnW=100.0, styleBtnH=40.0, styleBtnPosX=200.0, styleBtnPosY=200.0,
    nBtnW=60.0, nBtnH=40.0, nBtnPosX=300.0, nBtnPosY=200.0, nWinEnabled=false,
    pluschatEnabled=false,
    pluschatPosX=400.0, pluschatPosY=900.0, pluschatSize=16,
    pluschatColorR=0.0, pluschatColorG=1.0, pluschatColorB=0.0, pluschatColorA=1.0,
    fmPosX=30.0, fmPosY=20.0,
    clockOutlineR=0.0, clockOutlineG=0.0, clockOutlineB=0.0,
    clockTextR=1.0, clockTextG=1.0, clockTextB=1.0,
    clockOutlineThickness=1.0,
    clockRgbEnabled=false,
    clockFontName="Arial",
    mainWinPosX=-1.0, mainWinPosY=-1.0,
    markerRadius=32.0, markerThickness=3.0, markerArrowSize=28.0,
    markerColorR=1.0, markerColorG=0.85, markerColorB=0.10, markerColorA=1.0,
}}, "config.ini")

local LOGO_FILES = { 'rhl1.png', 'rhl22.png', 'rhl3.png', 'rhl4.png', 'rhl5.png' }

local CAPTCHA_INI = 'captchatime.ini'
local captchaIni = inicfg.load({ main={text="Ответ: {input} | Время: {time}", totalCount=0} }, CAPTCHA_INI)
if type(captchaIni.main.text) ~= "string" or captchaIni.main.text:find("%%s") then
    captchaIni.main.text = "Ответ: {input} | Время: {time}"
end
inicfg.save(captchaIni, CAPTCHA_INI)

local CLOCK_INI = 'clock.ini'
local clockIni = inicfg.load({ clock={
    enabled=false, showMilliseconds=true,
    posX=100, posY=100, width=210, height=75,
    fontSize=22,
}}, CLOCK_INI)
inicfg.save(clockIni, CLOCK_INI)

local DIALOG_SKIP           = 26007
local DIALOG_PICKUP_CONFIRM = 26151
local DIALOG_CAPTCHA_1      = 8869
local DIALOG_CAPTCHA_2      = 8868
local DIALOG_REALTOR        = 26143

local BTN_WIN_PAD   = 40
local BTN_ROUNDING  = 6

local pendingDownloads    = 0   -- сколько файлов ещё не завершили скачивание
local downloadedOK        = 0   -- сколько файлов скачалось успешно
local reloadingScheduled  = false

local windowVisible       = ffi.new("bool[1]", false)
local skipEnabled         = ffi.new("bool[1]", ini.cfg.skipEnabled)
local pickupSkipEnabled   = ffi.new("bool[1]", ini.cfg.pickupSkipEnabled)
local realtorEnabled      = ffi.new("bool[1]", ini.cfg.realtorEnabled)
local realtorArmed        = false
local captchaTimerEnabled = ffi.new("bool[1]", ini.cfg.captchaTimerEnabled)
local fastMapEnabled      = ffi.new("bool[1]", ini.cfg.fastMapEnabled)
local speedometerEnabled  = ffi.new("bool[1]", ini.cfg.speedometerEnabled)
local hotButtonsLocked    = ffi.new("bool[1]", ini.cfg.hotButtonsLocked)
local clockLocked         = ffi.new("bool[1]", ini.cfg.clockLocked)
local styleWinEnabled     = ffi.new("bool[1]", ini.cfg.styleWinEnabled)
local nWinEnabled         = ffi.new("bool[1]", ini.cfg.nWinEnabled)
local btnOutlineEnabled   = ffi.new("bool[1]", ini.cfg.btnOutlineEnabled ~= false)
local btnBgEnabled        = ffi.new("bool[1]", ini.cfg.btnBgEnabled ~= false)
local pluschatEnabled     = ffi.new("bool[1]", ini.cfg.pluschatEnabled)

local nBtnW               = ffi.new("float[1]", ini.cfg.nBtnW  or 60.0)
local nBtnH               = ffi.new("float[1]", ini.cfg.nBtnH  or 40.0)
local nBtnPos             = { x = ini.cfg.nBtnPosX or 300.0, y = ini.cfg.nBtnPosY or 200.0 }
local accentColor         = ffi.new("float[3]", ini.cfg.accentColorR, ini.cfg.accentColorG, ini.cfg.accentColorB)
local uiAlpha             = ffi.new("float[1]", ini.cfg.uiAlpha or 1.0)
local speedoPosX          = ffi.new("float[1]", ini.cfg.speedoPosX or 1150)
local speedoPosY          = ffi.new("float[1]", ini.cfg.speedoPosY or 580)
local btnBgColor          = ffi.new("float[4]", ini.cfg.btnBgColorR,     ini.cfg.btnBgColorG,     ini.cfg.btnBgColorB,     ini.cfg.btnBgColorA)
local btnBorderColor      = ffi.new("float[4]", ini.cfg.btnBorderColorR, ini.cfg.btnBorderColorG, ini.cfg.btnBorderColorB, ini.cfg.btnBorderColorA)
local btnTextColor        = ffi.new("float[4]", ini.cfg.btnTextColorR,   ini.cfg.btnTextColorG,   ini.cfg.btnTextColorB,   ini.cfg.btnTextColorA)
local btnThickness        = ffi.new("float[1]", ini.cfg.btnThickness or 2.0)
local btnRounding         = ffi.new("float[1]", ini.cfg.btnRounding or 6.0)
local mapBtnW             = ffi.new("float[1]", ini.cfg.mapBtnW   or 80.0)
local mapBtnH             = ffi.new("float[1]", ini.cfg.mapBtnH   or 35.0)
local styleBtnW           = ffi.new("float[1]", ini.cfg.styleBtnW or 100.0)
local styleBtnH           = ffi.new("float[1]", ini.cfg.styleBtnH or 40.0)

local markerRadius    = ffi.new("float[1]", ini.cfg.markerRadius    or 32.0)
local markerThickness = ffi.new("float[1]", ini.cfg.markerThickness or 3.0)
local markerArrowSize = ffi.new("float[1]", ini.cfg.markerArrowSize or 28.0)
local markerColor     = ffi.new("float[4]",
    ini.cfg.markerColorR or 1.0,
    ini.cfg.markerColorG or 0.85,
    ini.cfg.markerColorB or 0.10,
    ini.cfg.markerColorA or 1.0)

local clockOutlineColor     = ffi.new("float[3]", ini.cfg.clockOutlineR or 0, ini.cfg.clockOutlineG or 0, ini.cfg.clockOutlineB or 0)
local clockTextColor2       = ffi.new("float[3]", ini.cfg.clockTextR or 1, ini.cfg.clockTextG or 1, ini.cfg.clockTextB or 1)
local clockOutlineThickness = ffi.new("float[1]", ini.cfg.clockOutlineThickness or 1.0)
local clockRgbEnabled       = ffi.new("bool[1]", ini.cfg.clockRgbEnabled or false)

local mapBtnPos   = { x = ini.cfg.mapBtnPosX   or 100.0, y = ini.cfg.mapBtnPosY   or 200.0 }
local styleBtnPos = { x = ini.cfg.styleBtnPosX or 200.0, y = ini.cfg.styleBtnPosY or 200.0 }

local mainWinPos  = { x = tonumber(ini.cfg.mainWinPosX) or -1.0, y = tonumber(ini.cfg.mainWinPosY) or -1.0 }
local saveCounter = 0
local dragState   = { active=false, lastX=0, lastY=0 }

local scrollStates = {
    sidebar = { lastY = nil },
    content = { lastY = nil },
    help    = { lastY = nil },
}

local PLUSCHAT_TARGET_UTF8   = "Негде жить? Арендуйте номер в любом из отелей штата!"
local PLUSCHAT_TARGET_CP1251 = nil
local PLUSCHAT_TTL           = 5.0
local PLUSCHAT_KEYS_UTF8 = {
    "Арендуйте номер в любом из отелей",
    "в любом из отелей штата",
    "Негде жить",
    "Арендуйте номер",
    "из отелей штата",
}
local PLUSCHAT_KEYS_CP1251 = {}
local pluschatPosX      = ffi.new("float[1]", ini.cfg.pluschatPosX or 400.0)
local pluschatPosY      = ffi.new("float[1]", ini.cfg.pluschatPosY or 900.0)
local pluschatSize      = tonumber(ini.cfg.pluschatSize) or 16
local pluschatSizeBuf   = ffi.new("int[1]", pluschatSize)
local pluschatColor     = ffi.new("float[4]",
    ini.cfg.pluschatColorR or 0.0, ini.cfg.pluschatColorG or 1.0,
    ini.cfg.pluschatColorB or 0.0, ini.cfg.pluschatColorA or 1.0)
local pluschatFont        = nil
local pluschatFontDirty   = true
local pluschatActive      = false
local pluschatShowTime    = 0

local captchaTotalCount = tonumber(captchaIni.main.totalCount) or 0
local CAPTCHA_BUF   = 256
local captchaMsgBuf = ffi.new("char[?]", CAPTCHA_BUF)
ffi.copy(captchaMsgBuf, captchaIni.main.text)
local captchaActive   = false
local captchaDialogId = 0
local captchaInput    = ""

local clockEnabled   = ffi.new("bool[1]", clockIni.clock.enabled)
local clockShowMs    = ffi.new("bool[1]", clockIni.clock.showMilliseconds)
local clockPos       = imgui.ImVec2(clockIni.clock.posX, clockIni.clock.posY)
local clockWidth     = clockIni.clock.width
local clockHeight    = clockIni.clock.height
local clockWidthBuf  = ffi.new("int[1]", clockWidth)
local clockHeightBuf = ffi.new("int[1]", clockHeight)

local clockFontSize    = tonumber(clockIni.clock.fontSize) or 22
local clockFontSizeBuf = ffi.new("int[1]", clockFontSize)
local clockFontName    = ini.cfg.clockFontName or "Arial"

local CLOCK_FONTS = {
    { label = "Arial (по умолчанию)", id = "Arial" },
    { label = "Arteks",  id = "resource/ofont.ru_Arteks.ttf" },
    { label = "Aurach",  id = "resource/ofont.ru_Aurach.ttf" },
    { label = "Hemico",  id = "resource/ofont.ru_Hemico.ttf" },
    { label = "Patefon", id = "resource/ofont.ru_Patefon.ttf" },
}

local imguiFonts = {}
local fontReport = {}

local currentTab = nil
local helpOpenFor = nil

local TAB_HELP = {
    skip = {
        title = "СКИП — пропуск диалогов и сохранение выхода",
        body = {
            "Раздел управляет автозакрытием серверных диалогов",
            "и сохранением выхода из риэлторского агентства.",
            "",
            "● Скип диалога семей (ID 26007)",
            "  Моментально отправляет «Принять» и диалог не появляется.",
            "",
            "● Скип выбора вертолёта (ID 26151)",
            "  Автоматически нажимает кнопку подтверждения.",
            "",
            "● Сохранение выхода из риэлторского агентства",
            "  Позволяет выходить всегда на нужном вам выходе.",
            "",
            "▸ Как использовать",
            "  1. Включите «Сохранение выхода».",
            "  2. Выйдите на нужном выходе.",
            "  3. Введите /ex",
            "  4. Откройте диалог выбора входа в агентство.",
            "  5. НЕ нажимайте ничего — скрипт сам выберет выход.",
            "  6. После телепорта закройте диалог.",
            "  7. При следующем входе ваш выход сохранён — жмите «Принять».",
        },
    },
    captcha = {
        title = "КАПЧА — таймер и формат",
        body = {
            "Раздел для работы с капчей на сервере.",
            "",
            "● Таймер капчи",
            "  Замеряет время от появления диалога капчи до ответа.",
            "  Результат выводится в чат.",
            "",
            "● Формат сообщения",
            "  Шаблон текста после ввода капчи.",
            "  Доступны: {input} — что ввели, {time} — время в секундах.",
            "  Пример: «Ответ: {input} | Время: {time}»",
            "",
            "● Счётчик",
            "  Общее число введённых капч. Кнопка «Сбросить» обнуляет.",
        },
    },
    catch = {
        title = "ЛОВЛЯ — маркер, поиск, автоматизация",
        body = {
            "Раздел для ловли и автоматизации в игре.",
            "",
            "● Маркер пикапа (команда /metka)",
            "  Ставит прицел с точкой, крестиками и компас снизу.",
            "  Если маркер в кадре — показывается прицел.",
            "  Если вне кадра — только компас снизу показывает",
            "  куда бежать. Дополнительно ставит жёлтый блип.",
            "",
            "● Настройки маркера",
            "  Радиус, толщина линий, размер стрелки, цвет (RGBA).",
            "  Превью в этом же разделе.",
            "",
            "● ПОИСК ДОМА /fh <номер>",
            "  Аналог /findihouse. Отправляет команду на сервер.",
            "  Сервер сам ставит маркер и/или блип на карте.",
            "",
            "● ПОИСК БИЗНЕСА /fb <номер>",
            "  Аналог /findibiz. Работает так же.",
            "",
            "● FastMap",
            "  Полноэкранная карта без паузы. Команда /mapset — двигать.",
            "",
            "● PLUSCHAT — оповещение об отеле",
            "  Скрипт отслеживает фразу:",
            "  «Негде жить? Арендуйте номер в любом из отелей штата!»",
            "  Когда она появится — скрипт покажет её крупно",
            "  на указанной позиции в течение 5 секунд.",
            "  Команда /pctest — принудительно показать (тест).",
        },
    },
    visual = {
        title = "ВИЗУАЛ — часы, спидометр, карта",
        body = {
            "Настройка визуальных элементов на экране.",
            "",
            "● ЧАСЫ",
            "  Включение, миллисекунды, шрифт, размер,",
            "  цвета текста и обводки, толщина обводки,",
            "  RGB-переливание, область перетаскивания.",
            "",
            "▸ /fixwatch — зафиксировать/разморозить часы.",
            "",
            "● СПИДОМЕТР",
            "  Скорость (км/ч) и HP авто. Позиция X/Y.",
            "",
            "● КАРТА (FASTMAP)",
            "  Позиция карты. Команда /mapset — двигать пальцем.",
            "  Второй /mapset — сохранить позицию.",
        },
    },
    buttons = {
        title = "КНОПКИ — внешний вид и размеры",
        body = {
            "Настройка трёх кастомных кнопок: MAP, STYLE, N.",
            "",
            "● РЕЖИМ КНОПОК",
            "  «Зафиксировать кнопки» — клики работают.",
            "  Без фиксации — можно перетаскивать пальцем,",
            "  клики тоже работают.",
            "  Команда /fixbut — переключить из чата.",
            "",
            "● ВНЕШНИЙ ВИД",
            "  Радиус скругления, цвета фона/рамки/текста,",
            "  толщина обводки, ширина и высота каждой кнопки.",
            "",
            "● ПОКАЗ КНОПОК",
            "  MAP — /cstyle (вкл/выкл Style)",
            "  STYLE — /cstyle (вкл/выкл Style)",
            "  N — /nn (вкл/выкл)",
        },
    },
    about = {
        title = "О СКРИПТЕ — все команды",
        body = {
            "rhl  v1.530 beta",
            "Автор: krvdd",
            "",
            "● КОМАНДЫ",
            "  /rhl             — открыть или закрыть меню",
            "  /metka           — поставить метку на текущей позиции",
            "  /fh <номер>      — найти дом (аналог /findihouse)",
            "  /fb <номер>      — найти бизнес (аналог /findibiz)",
            "  /ex              — активировать сохранение выхода риэлтора",
            "  /mapset          — двигать карту (режим FastMap)",
            "  /fixbut          — зафиксировать/разморозить кнопки",
            "  /fixwatch        — зафиксировать/разморозить часы",
            "  /pctest          — тестовый показ pluschat-фразы",
            "  /cstyle          — вкл/выкл кнопку Style",
            "  /nn              — вкл/выкл кнопку N",
            "  /cpc             — инфо про отключённую открывашку дверей",
            "  /fontreload      — перезагрузить ресурсы (шрифты, логотипы)",
            "  /reload          — принудительно перезагрузить скрипт",
            "",
            "● АВТО-ПЕРЕЗАГРУЗКА",
            "  При первом запуске скрипт скачивает ресурсы с GitHub.",
            "  После завершения загрузки он автоматически",
            "  перезапускается — файлы подхватываются корректно.",
            "",
            "● ПЕРЕТАСКИВАНИЕ ОКНА",
            "  Зажмите верхнюю полоску окна и тяните.",
            "",
            "● СКРОЛЛ ПАЛЬЦЕМ",
            "  Свайп вверх/вниз по контенту — листает меню.",
        },
    },
}

local function clockSetFont(name)
    if not name or name == "" then name = "Arial" end
    if clockFontName == name then return end
    clockFontName = name
    ini.cfg.clockFontName = name
    inicfg.save(ini, "config.ini")
end

    local resDir = getWorkingDirectory() .. '/resource'
local function ensureResource(url, fileName)
    local path   = resDir .. '/' .. fileName
    local f = io.open(path, 'rb')
    if f then f:close(); return false end
    os.execute('mkdir -p "' .. resDir .. '"')
    if type(downloadUrlToFile) ~= 'function' then return false end
    pendingDownloads = pendingDownloads + 1
    pcall(downloadUrlToFile, url, path, function(id, status, p1, p2)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            downloadedOK = downloadedOK + 1
            pendingDownloads = pendingDownloads - 1
        elseif status == dlstatus.STATUS_ENDDOWNLOADERROR then
            pendingDownloads = pendingDownloads - 1
        end
    end)
    return true
end
local UTF8_TO_CP1251 = {
    [0x410]=192,[0x411]=193,[0x412]=194,[0x413]=195,[0x414]=196,[0x415]=197,
    [0x416]=198,[0x417]=199,[0x418]=200,[0x419]=201,[0x41A]=202,[0x41B]=203,
    [0x41C]=204,[0x41D]=205,[0x41E]=206,[0x41F]=207,[0x420]=208,[0x421]=209,
    [0x422]=210,[0x423]=211,[0x424]=212,[0x425]=213,[0x426]=214,[0x427]=215,
    [0x428]=216,[0x429]=217,[0x42A]=218,[0x42B]=219,[0x42C]=220,[0x42D]=221,
    [0x42E]=222,[0x42F]=223,
    [0x430]=224,[0x431]=225,[0x432]=226,[0x433]=227,[0x434]=228,[0x435]=229,
    [0x436]=230,[0x437]=231,[0x438]=232,[0x439]=233,[0x43A]=234,[0x43B]=235,
    [0x43C]=236,[0x43D]=237,[0x43E]=238,[0x43F]=239,[0x440]=240,[0x441]=241,
    [0x442]=242,[0x443]=243,[0x444]=244,[0x445]=245,[0x446]=246,[0x447]=247,
    [0x448]=248,[0x449]=249,[0x44A]=250,[0x44B]=251,[0x44C]=252,[0x44D]=253,
    [0x44E]=254,[0x44F]=255,
    [0x401]=168,[0x451]=184,
}

local function utf8_to_cp1251(s)
    if not s or s == "" then return s end
    local result = {}
    local i = 1
    local len = #s
    while i <= len do
        local c = s:byte(i)
        if c < 0x80 then
            table.insert(result, string.char(c)); i = i + 1
        elseif c >= 0xC0 and c < 0xE0 then
            local c2 = s:byte(i+1) or 0
            local cp = (c - 0xC0) * 64 + (c2 - 0x80)
            local b = UTF8_TO_CP1251[cp]
            table.insert(result, b and string.char(b) or "?"); i = i + 2
        elseif c >= 0xE0 then
            local c2 = s:byte(i+1) or 0
            local c3 = s:byte(i+2) or 0
            local cp = (c - 0xE0) * 4096 + (c2 - 0x80) * 64 + (c3 - 0x80)
            local b = UTF8_TO_CP1251[cp]
            table.insert(result, b and string.char(b) or "?"); i = i + 3
        else
            table.insert(result, string.char(c)); i = i + 1
        end
    end
    return table.concat(result)
end

PLUSCHAT_TARGET_CP1251 = utf8_to_cp1251(PLUSCHAT_TARGET_UTF8)
for i, k in ipairs(PLUSCHAT_KEYS_UTF8) do
    PLUSCHAT_KEYS_CP1251[i] = utf8_to_cp1251(k)
end

local function stripSampColors(s)
    if not s or s == "" then return "" end
    local out = s:gsub("{%x%x%x%x%x%x}", "")
    out = out:gsub("{%x%x%x%x%x%x%x%x}", "")
    out = out:gsub("~%a~", "")
    return out
end

local function pluschatMatch(text)
    if not text or text == "" then return false end
    local clean = stripSampColors(text)
    if clean:find(PLUSCHAT_TARGET_UTF8, 1, true) then return true end
    if PLUSCHAT_TARGET_CP1251 and clean:find(PLUSCHAT_TARGET_CP1251, 1, true) then return true end
    for i, k in ipairs(PLUSCHAT_KEYS_UTF8) do
        if clean:find(k, 1, true) then return true end
        if PLUSCHAT_KEYS_CP1251[i] and clean:find(PLUSCHAT_KEYS_CP1251[i], 1, true) then return true end
    end
    return false
end

local function pluschatEnsureFont()
    if pluschatFontDirty then
        pluschatFont = renderCreateFont("Arial", pluschatSize, 4, 5)
        pluschatFontDirty = false
    end
end

local function pluschatColorARGB()
    local r = math.floor(pluschatColor[0] * 255)
    local g = math.floor(pluschatColor[1] * 255)
    local b = math.floor(pluschatColor[2] * 255)
    local a = math.floor(pluschatColor[3] * 255)
    return bit.bor(bit.lshift(a,24), bit.lshift(r,16), bit.lshift(g,8), b)
end

local function pluschatRender()
    pluschatEnsureFont()
    if not pluschatFont then return end
    local now = os.clock()
    local showReal = pluschatEnabled[0] and pluschatActive and (now - pluschatShowTime) < PLUSCHAT_TTL
    local showPreview = (windowVisible[0]==true) and (currentTab == "catch")
    if not (showReal or showPreview) then return end
    local txt = PLUSCHAT_TARGET_CP1251 or PLUSCHAT_TARGET_UTF8
    renderFontDrawText(pluschatFont, txt, pluschatPosX[0], pluschatPosY[0], pluschatColorARGB())
end

local fastMapOpen = ffi.new("bool[1]", false)
local fastMapTex  = nil
local fmCheckX, fmCheckY = nil, nil
local FM_DW, FM_DH = 1280, 1280
local FM_XMIN, FM_XMAX = -3000, 3000
local FM_YMIN, FM_YMAX = -3000, 3000
local fmPosX = ffi.new("float[1]", ini.cfg.fmPosX or 30.0)
local fmPosY = ffi.new("float[1]", ini.cfg.fmPosY or 20.0)
local fmEditMode = ffi.new("bool[1]", false)
local cursorTex = nil
local markerTex = nil
local rhl2Tex = nil

local logoTex        = {}
local logoIdx        = 1
local logoTime       = 0
local LOGO_INTERVAL  = 0.5

local styleDialogInfo = { id=nil, state=false, dialoged=false }

local cachedBtnBg, cachedBtnBorder, cachedBtnText
local btnColorsDirty = true
local function refreshBtnColors()
    cachedBtnBg     = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(btnBgColor[0],     btnBgColor[1],     btnBgColor[2],     btnBgColor[3]))
    cachedBtnBorder = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(btnBorderColor[0], btnBorderColor[1], btnBorderColor[2], btnBorderColor[3]))
    cachedBtnText   = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(btnTextColor[0],   btnTextColor[1],   btnTextColor[2],   btnTextColor[3]))
    btnColorsDirty  = false
end

local BOOL_CFG = {
    {skipEnabled,"skipEnabled"},
    {pickupSkipEnabled,"pickupSkipEnabled"},{captchaTimerEnabled,"captchaTimerEnabled"},
    {fastMapEnabled,"fastMapEnabled"},
    {speedometerEnabled,"speedometerEnabled"},{hotButtonsLocked,"hotButtonsLocked"},
    {clockLocked,"clockLocked"},
    {styleWinEnabled,"styleWinEnabled"},{nWinEnabled,"nWinEnabled"},
    {btnOutlineEnabled,"btnOutlineEnabled"},{btnBgEnabled,"btnBgEnabled"},{pluschatEnabled,"pluschatEnabled"},
    {clockRgbEnabled,"clockRgbEnabled"},{realtorEnabled,"realtorEnabled"},
}

local function cfg_save()
    for _,s in ipairs(BOOL_CFG) do ini.cfg[s[2]]=(s[1][0]==true) end
    ini.cfg.accentColorR=accentColor[0]; ini.cfg.accentColorG=accentColor[1]; ini.cfg.accentColorB=accentColor[2]
    ini.cfg.uiAlpha=uiAlpha[0]
    ini.cfg.speedoPosX=speedoPosX[0]; ini.cfg.speedoPosY=speedoPosY[0]
    ini.cfg.btnBgColorR=btnBgColor[0];     ini.cfg.btnBgColorG=btnBgColor[1];     ini.cfg.btnBgColorB=btnBgColor[2];     ini.cfg.btnBgColorA=btnBgColor[3]
    ini.cfg.btnBorderColorR=btnBorderColor[0]; ini.cfg.btnBorderColorG=btnBorderColor[1]; ini.cfg.btnBorderColorB=btnBorderColor[2]; ini.cfg.btnBorderColorA=btnBorderColor[3]
    ini.cfg.btnTextColorR=btnTextColor[0]; ini.cfg.btnTextColorG=btnTextColor[1]; ini.cfg.btnTextColorB=btnTextColor[2]; ini.cfg.btnTextColorA=btnTextColor[3]
    ini.cfg.btnThickness=btnThickness[0]
    ini.cfg.btnRounding=btnRounding[0]
    ini.cfg.mapBtnW=mapBtnW[0];   ini.cfg.mapBtnH=mapBtnH[0]
    ini.cfg.mapBtnPosX=mapBtnPos.x; ini.cfg.mapBtnPosY=mapBtnPos.y
    ini.cfg.styleBtnW=styleBtnW[0]; ini.cfg.styleBtnH=styleBtnH[0]
    ini.cfg.styleBtnPosX=styleBtnPos.x; ini.cfg.styleBtnPosY=styleBtnPos.y
    ini.cfg.nBtnW=nBtnW[0]; ini.cfg.nBtnH=nBtnH[0]
    ini.cfg.nBtnPosX=nBtnPos.x; ini.cfg.nBtnPosY=nBtnPos.y
    ini.cfg.fmPosX=fmPosX[0]; ini.cfg.fmPosY=fmPosY[0]
    ini.cfg.pluschatPosX=pluschatPosX[0]; ini.cfg.pluschatPosY=pluschatPosY[0]
    ini.cfg.pluschatSize=pluschatSize
    ini.cfg.pluschatColorR=pluschatColor[0]; ini.cfg.pluschatColorG=pluschatColor[1]
    ini.cfg.pluschatColorB=pluschatColor[2]; ini.cfg.pluschatColorA=pluschatColor[3]
    ini.cfg.clockOutlineR=clockOutlineColor[0]; ini.cfg.clockOutlineG=clockOutlineColor[1]; ini.cfg.clockOutlineB=clockOutlineColor[2]
    ini.cfg.clockTextR=clockTextColor2[0]; ini.cfg.clockTextG=clockTextColor2[1]; ini.cfg.clockTextB=clockTextColor2[2]
    ini.cfg.clockOutlineThickness=clockOutlineThickness[0]
    ini.cfg.clockFontName=clockFontName
    ini.cfg.mainWinPosX = mainWinPos.x
    ini.cfg.mainWinPosY = mainWinPos.y
    ini.cfg.markerRadius    = markerRadius[0]
    ini.cfg.markerThickness = markerThickness[0]
    ini.cfg.markerArrowSize = markerArrowSize[0]
    ini.cfg.markerColorR    = markerColor[0]
    ini.cfg.markerColorG    = markerColor[1]
    ini.cfg.markerColorB    = markerColor[2]
    ini.cfg.markerColorA    = markerColor[3]
    inicfg.save(ini,"config.ini")
    btnColorsDirty = true
end

local function captcha_save()
    captchaIni.main.totalCount=captchaTotalCount
    captchaIni.main.text=ffi.string(captchaMsgBuf)
    inicfg.save(captchaIni,CAPTCHA_INI)
end

local function clock_save()
    clockIni.clock.enabled=(clockEnabled[0]==true)
    clockIni.clock.showMilliseconds=(clockShowMs[0]==true)
    clockIni.clock.posX=math.floor(clockPos.x); clockIni.clock.posY=math.floor(clockPos.y)
    clockIni.clock.width=math.floor(clockWidth); clockIni.clock.height=math.floor(clockHeight)
    clockIni.clock.fontSize=clockFontSize
    ini.cfg.clockFontName = clockFontName
    inicfg.save(clockIni,CLOCK_INI)
    inicfg.save(ini,"config.ini")
end

local function clamp01(v) return v<0 and 0 or v>1 and 1 or v end

local function captcha_format(template, input, time)
    local s = template
    s = s:gsub("{input}", input or "")
    s = s:gsub("{time}",  time or "")
    return s
end

local function rgb_wheel(t)
    t = t or 0
    local h = (t * 0.15) % 1.0
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local q = 1 - f
    i = i % 6
    if i == 0 then return 1, f, 0
    elseif i == 1 then return q, 1, 0
    elseif i == 2 then return 0, 1, f
    elseif i == 3 then return 0, q, 1
    elseif i == 4 then return f, 0, 1
    else return 1, 0, q end
end

local TEXT_OUTLINE_DIRS = {
    {-1, 0}, {1, 0}, {0, -1}, {0, 1},
    {-1,-1}, {1,-1}, {-1, 1}, {1, 1},
}

local function drawOutlinedAt(x, y, t, colU32)
    local dl = imgui.GetWindowDrawList()
    local black = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0,0,0,0.9))
    for _, d in ipairs(TEXT_OUTLINE_DIRS) do dl:AddText(imgui.ImVec2(x+d[1], y+d[2]), black, t) end
    dl:AddText(imgui.ImVec2(x, y), colU32, t)
end

local function txt(s)
    local col = imgui.GetStyle().Colors[imgui.Col.Text]
    local colU32 = imgui.ColorConvertFloat4ToU32(col)
    local p = imgui.GetCursorScreenPos()
    drawOutlinedAt(p.x, p.y, s, colU32)
    local ts = imgui.CalcTextSize(s)
    imgui.Dummy(imgui.ImVec2(ts.x, ts.y))
end

local function txtDim(s)
    local col = imgui.GetStyle().Colors[imgui.Col.TextDisabled]
    local colU32 = imgui.ColorConvertFloat4ToU32(col)
    local p = imgui.GetCursorScreenPos()
    drawOutlinedAt(p.x, p.y, s, colU32)
    local ts = imgui.CalcTextSize(s)
    imgui.Dummy(imgui.ImVec2(ts.x, ts.y))
end

local function drawBtnStyle(p1, p2, label, highlight)
    if btnColorsDirty then refreshBtnColors() end
    local dl = imgui.GetWindowDrawList()
    local w = p2.x - p1.x
    local h = p2.y - p1.y
    local rnd = math.max(0, math.min(btnRounding[0], w * 0.5, h * 0.5))
    local t   = math.max(0, btnThickness[0])
    local borderCol = cachedBtnBorder
    if highlight then
        local pulse = 0.55 + 0.45 * math.abs(math.sin(os.clock() * 3.2))
        borderCol = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(accentColor[0], accentColor[1], accentColor[2], pulse))
    end
    local drawBorder = highlight or (btnOutlineEnabled[0] and t > 0.1)
    if btnBgEnabled[0] then
        if drawBorder then dl:AddRectFilled(p1, p2, borderCol, rnd) end
        local innerP1, innerP2, innerRnd = p1, p2, rnd
        if drawBorder and t > 0.1 then
            innerP1  = imgui.ImVec2(p1.x + t, p1.y + t)
            innerP2  = imgui.ImVec2(p2.x - t, p2.y - t)
            innerRnd = math.max(0, rnd - t)
        end
        dl:AddRectFilled(innerP1, innerP2, cachedBtnBg, innerRnd)
    else
        if drawBorder then
            local innerRnd = math.max(0, rnd - t)
            if rnd < 0.5 then
                dl:AddRectFilled(p1, imgui.ImVec2(p2.x, p1.y + t), borderCol)
                dl:AddRectFilled(imgui.ImVec2(p1.x, p2.y - t), p2, borderCol)
                dl:AddRectFilled(imgui.ImVec2(p1.x, p1.y + t), imgui.ImVec2(p1.x + t, p2.y - t), borderCol)
                dl:AddRectFilled(imgui.ImVec2(p2.x - t, p1.y + t), imgui.ImVec2(p2.x, p2.y - t), borderCol)
            else
                dl:AddRectFilled(imgui.ImVec2(p1.x + rnd, p1.y), imgui.ImVec2(p2.x - rnd, p1.y + t), borderCol)
                dl:AddRectFilled(imgui.ImVec2(p1.x + rnd, p2.y - t), imgui.ImVec2(p2.x - rnd, p2.y), borderCol)
                dl:AddRectFilled(imgui.ImVec2(p1.x, p1.y + rnd), imgui.ImVec2(p1.x + t, p2.y - rnd), borderCol)
                dl:AddRectFilled(imgui.ImVec2(p2.x - t, p1.y + rnd), imgui.ImVec2(p2.x, p2.y - rnd), borderCol)
                local steps = 12
                local function cornerRing(cx, cy, a0, a1)
                    for i = 0, steps - 1 do
                        local aa = a0 + (a1 - a0) * (i / steps)
                        local ab = a0 + (a1 - a0) * ((i + 1) / steps)
                        local pA = imgui.ImVec2(cx + math.cos(aa) * rnd,      cy + math.sin(aa) * rnd)
                        local pB = imgui.ImVec2(cx + math.cos(ab) * rnd,      cy + math.sin(ab) * rnd)
                        local pC = imgui.ImVec2(cx + math.cos(ab) * innerRnd, cy + math.sin(ab) * innerRnd)
                        local pD = imgui.ImVec2(cx + math.cos(aa) * innerRnd, cy + math.sin(aa) * innerRnd)
                        dl:AddTriangleFilled(pA, pB, pC, borderCol)
                        dl:AddTriangleFilled(pA, pC, pD, borderCol)
                    end
                end
                cornerRing(p1.x + rnd, p1.y + rnd, math.pi,       math.pi * 1.5)
                cornerRing(p2.x - rnd, p1.y + rnd, math.pi * 1.5, math.pi * 2.0)
                cornerRing(p2.x - rnd, p2.y - rnd, 0,             math.pi * 0.5)
                cornerRing(p1.x + rnd, p2.y - rnd, math.pi * 0.5, math.pi)
            end
        end
    end
    local ts = imgui.CalcTextSize(label)
    local cx = p1.x + (w - ts.x) * 0.5
    local cy = p1.y + (h - ts.y) * 0.5
    drawOutlinedAt(cx, cy, label, cachedBtnText)
end

local function applyTheme()
    local style=imgui.GetStyle(); local colors=style.Colors
    local ar,ag,ab=accentColor[0],accentColor[1],accentColor[2]; local a=uiAlpha[0]
    colors[imgui.Col.WindowBg]             = imgui.ImVec4(0.09,0.03,0.04,0.98*a)
    colors[imgui.Col.ChildBg]              = imgui.ImVec4(0.07,0.02,0.03,1.0*a)
    colors[imgui.Col.PopupBg]              = imgui.ImVec4(0.09,0.03,0.04,0.98*a)
    colors[imgui.Col.Border]               = imgui.ImVec4(ar,ag,ab,0.35*a)
    colors[imgui.Col.BorderShadow]         = imgui.ImVec4(0,0,0,0)
    colors[imgui.Col.Text]                 = imgui.ImVec4(0.93,0.88,0.88,1.0*a)
    colors[imgui.Col.TextDisabled]         = imgui.ImVec4(0.62,0.50,0.52,1.0*a)
    colors[imgui.Col.TitleBg]              = imgui.ImVec4(0.06,0.02,0.03,1.0*a)
    colors[imgui.Col.TitleBgActive]        = imgui.ImVec4(ar*0.25,ag*0.25,ab*0.25,1.0*a)
    colors[imgui.Col.TitleBgCollapsed]     = imgui.ImVec4(0.06,0.02,0.03,0.7*a)
    colors[imgui.Col.FrameBg]              = imgui.ImVec4(0.14,0.05,0.07,1.0*a)
    colors[imgui.Col.FrameBgHovered]       = imgui.ImVec4(ar*0.25,ag*0.25,ab*0.25,1.0*a)
    colors[imgui.Col.FrameBgActive]        = imgui.ImVec4(ar*0.40,ag*0.40,ab*0.40,1.0*a)
    colors[imgui.Col.Button]               = imgui.ImVec4(ar*0.28,ag*0.28,ab*0.28,0.85*a)
    colors[imgui.Col.ButtonHovered]        = imgui.ImVec4(ar*0.45,ag*0.45,ab*0.45,1.0*a)
    colors[imgui.Col.ButtonActive]         = imgui.ImVec4(ar*0.65,ag*0.65,ab*0.65,1.0*a)
    colors[imgui.Col.Header]               = imgui.ImVec4(ar*0.20,ag*0.20,ab*0.20,0.8*a)
    colors[imgui.Col.HeaderHovered]        = imgui.ImVec4(ar*0.35,ag*0.35,ab*0.35,1.0*a)
    colors[imgui.Col.HeaderActive]         = imgui.ImVec4(ar*0.50,ag*0.50,ab*0.50,1.0*a)
    colors[imgui.Col.CheckMark]            = imgui.ImVec4(ar,ag,ab,1.0*a)
    colors[imgui.Col.SliderGrab]           = imgui.ImVec4(ar*0.75,ag*0.75,ab*0.75,1.0*a)
    colors[imgui.Col.SliderGrabActive]     = imgui.ImVec4(ar,ag,ab,1.0*a)
    colors[imgui.Col.ScrollbarBg]          = imgui.ImVec4(0.05,0.01,0.02,1.0*a)
    colors[imgui.Col.ScrollbarGrab]        = imgui.ImVec4(ar*0.35,ag*0.35,ab*0.35,1.0*a)
    colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(ar*0.55,ag*0.55,ab*0.55,1.0*a)
    colors[imgui.Col.ScrollbarGrabActive]  = imgui.ImVec4(ar*0.75,ag*0.75,ab*0.75,1.0*a)
    colors[imgui.Col.Separator]            = imgui.ImVec4(ar,ag,ab,0.20*a)
    style.WindowRounding=12.0; style.ChildRounding=10.0; style.FrameRounding=6.0
    style.GrabRounding=6.0; style.PopupRounding=8.0; style.ScrollbarRounding=10.0
    style.WindowPadding=imgui.ImVec2(14,14); style.FramePadding=imgui.ImVec2(10,6)
    style.ItemSpacing=imgui.ImVec2(10,10); style.ItemInnerSpacing=imgui.ImVec2(8,6)
    style.IndentSpacing=20.0; style.WindowMinSize=imgui.ImVec2(200,100)
end
imgui.OnFrame(function() return true end, applyTheme)

local function applyTouchScrollInChild(state)
    local io = imgui.GetIO()
    if not io then state.lastY = nil; return end
    if not io.MouseDown[0] then state.lastY = nil; return end
    if dragState.active then state.lastY = nil; return end
    local mp = io.MousePos
    local wp = imgui.GetWindowPos()
    local ws = imgui.GetWindowSize()
    if mp.x < wp.x or mp.x > wp.x + ws.x or mp.y < wp.y or mp.y > wp.y + ws.y then
        state.lastY = nil; return
    end
    if imgui.IsAnyItemHovered() then state.lastY = nil; return end
    if not state.lastY then state.lastY = mp.y; return end
    local dy = mp.y - state.lastY
    state.lastY = mp.y
    if math.abs(dy) > 0.3 then
        pcall(function() imgui.SetScrollY(imgui.GetScrollY() - dy) end)
    end
end

local function toggle(id, boolPtr, onChange)
    local TW,TH = 46,26
    local R = TH*0.5
    local val = (boolPtr[0]==true)
    local ar,ag,ab = accentColor[0],accentColor[1],accentColor[2]
    local p = imgui.GetCursorScreenPos()
    local dl = imgui.GetWindowDrawList()
    local p2 = imgui.ImVec2(p.x+TW, p.y+TH)
    local bgCol = val
        and imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar,ag,ab,1.0))
        or  imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.22,0.15,0.17,1.0))
    dl:AddRectFilled(p, p2, bgCol, R)
    dl:AddRect(p, p2, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0,0,0,0.85)), R, 16, 1.5)
    local cx = val and (p.x+TW-R) or (p.x+R)
    local cy = p.y+R
    dl:AddCircleFilled(imgui.ImVec2(cx, cy), R-3, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1,1,1,1)), 16)
    dl:AddCircle(imgui.ImVec2(cx, cy), R-3, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0,0,0,0.85)), 16, 1.5)
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,1,1,0.07))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(1,1,1,0.14))
    imgui.PushStyleColor(imgui.Col.Border,        imgui.ImVec4(0,0,0,0))
    local clicked = imgui.Button(id, imgui.ImVec2(TW,TH))
    imgui.PopStyleColor(4)
    if clicked then boolPtr[0]=not val; if onChange then onChange() end end
end

local function toggleRow(label, hint, boolPtr, onChange)
    local TW, TH = 46, 26
    local startY = imgui.GetCursorPosY()
    local startX = imgui.GetCursorPosX()
    txt(label)
    if hint ~= "" then txtDim(hint) end
    local endY   = imgui.GetCursorPosY()
    local blockH = endY - startY
    local labelW = imgui.CalcTextSize(label).x
    local hintW  = hint ~= "" and imgui.CalcTextSize(hint).x or 0
    local toggleX = startX + math.max(labelW, hintW) + 10
    imgui.SameLine(); imgui.SetCursorPosX(toggleX)
    imgui.SetCursorPosY(startY + (blockH - TH) * 0.5)
    toggle("##tg"..label, boolPtr, onChange)
    imgui.SetCursorPosY(endY)
end

local function btn(label, size)
    if btnColorsDirty then refreshBtnColors() end
    local display = label:match("^(.-)##") or label
    local ts = imgui.CalcTextSize(display)
    local w  = (size and size.x>0) and size.x or (ts.x+30)
    local h  = (size and size.y>0) and size.y or (ts.y+14)
    local p1 = imgui.GetCursorScreenPos()
    local p2 = imgui.ImVec2(p1.x+w,p1.y+h)
    drawBtnStyle(p1, p2, display, false)
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,1,1,0.06))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(1,1,1,0.12))
    imgui.PushStyleColor(imgui.Col.Border,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0,0,0,0))
    local clicked = imgui.Button(label, imgui.ImVec2(w,h))
    imgui.PopStyleColor(5)
    return clicked
end

local markerPos  = nil
local markerBlip = nil
local markerSX, markerSY = nil, nil
local markerLastSeen     = 0
local MARKER_HOLD        = 0.12

local MARKER_OUTLINE_DIRS = {
    {-1, 0}, {1, 0}, {0, -1}, {0, 1},
    {-1,-1}, {1,-1}, {-1, 1}, {1, 1},
}

local function removeMarker()
    if markerBlip then pcall(removeBlip, markerBlip); markerBlip = nil end
    markerPos    = nil
    markerSX, markerSY = nil, nil
    markerLastSeen = 0
end

local function setMarkerAtPlayer()
    local x, y, z = getCharCoordinates(PLAYER_PED)
    if not x then
        sampAddChatMessage("[rhl] маркер: ошибка координат", -1)
        return
    end
    removeMarker()
    markerPos = { x = x, y = y, z = z }
    local ok, bl = pcall(addBlipForCoord, x, y, z)
    if ok and bl and bl ~= 0 then
        markerBlip = bl
        pcall(changeBlipColour, markerBlip, 1)
    end
    sampAddChatMessage(string.format(
        "[rhl] метка установлена: X=%.1f Y=%.1f Z=%.1f", x, y, z), -1)
end

imgui.OnFrame(
    function() return markerPos ~= nil end,
    function()
        if not markerPos then return end
        local sw, sh = getScreenResolution()
        if not sw or sw <= 0 then return end

        local px, py, pz = getCharCoordinates(PLAYER_PED)
        if not px then return end

        local mx, my, mz = markerPos.x, markerPos.y, markerPos.z
        local dx, dy, dz = mx - px, my - py, mz - pz
        local distH = math.sqrt(dx*dx + dy*dy)
        local dist  = math.sqrt(dx*dx + dy*dy + dz*dz)
        local label = string.format("%.0f м", dist)

        local camX, camY, camZ = getActiveCameraCoordinates()
        local camTX, camTY, camTZ = getActiveCameraPointAt()
        if not camX or not camTX then return end

        local camFwdX = camTX - camX
        local camFwdY = camTY - camY
        local camFwdZ = camTZ - camZ

        local camFwdXYLen = math.sqrt(camFwdX*camFwdX + camFwdY*camFwdY)
        local camFwdX2D, camFwdY2D
        if camFwdXYLen > 0.001 then
            camFwdX2D = camFwdX / camFwdXYLen
            camFwdY2D = camFwdY / camFwdXYLen
        else
            camFwdX2D, camFwdY2D = 0, 1
        end

        local camFwdLen = math.sqrt(camFwdX*camFwdX + camFwdY*camFwdY + camFwdZ*camFwdZ)
        local toMX, toMY, toMZ = mx - camX, my - camY, mz - camZ
        local toMLen = math.sqrt(toMX*toMX + toMY*toMY + toMZ*toMZ)
        local camDot = 0
        if camFwdLen > 0.001 and toMLen > 0.001 then
            camDot = (toMX*camFwdX + toMY*camFwdY + toMZ*camFwdZ) / (camFwdLen * toMLen)
        end

        local relAngle = math.atan2(
            camFwdY2D * dx - camFwdX2D * dy,
            camFwdX2D * dx + camFwdY2D * dy
        )

        local sx, sy
        local okProj = pcall(function()
            sx, sy = convert3DCoordsToScreen(mx, my, mz)
        end)
        local validProj = okProj
            and type(sx) == "number" and type(sy) == "number"
            and sx == sx and sy == sy
        if validProj and sw > 100 and math.abs(sx) <= 1.0 and math.abs(sy) <= 1.0 then
            sx = sx * sw
            sy = sy * sh
        end

        local onScreen = validProj
            and camDot > 0.1
            and distH > 1.0
            and sx >= 40 and sx <= sw - 40
            and sy >= 40 and sy <= sh - 40

        local now = os.clock()
        if onScreen then
            markerSX, markerSY = sx, sy
            markerLastSeen = now
        end

        local showMarker = markerSX ~= nil and markerSY ~= nil
            and (now - markerLastSeen) < MARKER_HOLD

        local dl = imgui.GetForegroundDrawList()
        local mr, mg, mb = markerColor[0], markerColor[1], markerColor[2]
        local ma = markerColor[3]
        local pulse = 0.55 + 0.45 * math.abs(math.sin(os.clock() * 2.5))

        local mainCol  = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(mr, mg, mb, ma))
        local dimCol   = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(mr, mg, mb, ma * 0.35))
        local glowCol  = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(mr, mg, mb, ma * (0.12 + 0.20 * pulse)))
        local blackCol = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.00, 0.00, 0.00, 0.90))

        local function outlinedText(x, y, t, col)
            for _, d in ipairs(MARKER_OUTLINE_DIRS) do
                dl:AddText(imgui.ImVec2(x + d[1], y + d[2]), blackCol, t)
            end
            dl:AddText(imgui.ImVec2(x, y), col, t)
        end

        local R = markerRadius[0]
        local T = markerThickness[0]

        if showMarker then
            local mx2, my2 = markerSX, markerSY
            dl:AddCircleFilled(imgui.ImVec2(mx2, my2), R + 14, glowCol, 48)
            dl:AddCircle(imgui.ImVec2(mx2, my2), R + 6, dimCol, 48, 1.5)
            dl:AddCircle(imgui.ImVec2(mx2, my2), R + 1.5, blackCol, 48, 2.5)
            dl:AddCircle(imgui.ImVec2(mx2, my2), R, mainCol, 48, T)
            dl:AddCircleFilled(imgui.ImVec2(mx2, my2), math.max(4, R * 0.18), blackCol, 16)
            dl:AddCircleFilled(imgui.ImVec2(mx2, my2), math.max(3, R * 0.15), mainCol, 16)

            local cl = math.max(8, R * 0.45)
            local ct = math.max(2, T)
            dl:AddLine(imgui.ImVec2(mx2 - R - cl, my2), imgui.ImVec2(mx2 - R + 2, my2), blackCol, ct + 1.5)
            dl:AddLine(imgui.ImVec2(mx2 + R - 2, my2), imgui.ImVec2(mx2 + R + cl, my2), blackCol, ct + 1.5)
            dl:AddLine(imgui.ImVec2(mx2, my2 - R - cl), imgui.ImVec2(mx2, my2 - R + 2), blackCol, ct + 1.5)
            dl:AddLine(imgui.ImVec2(mx2, my2 + R - 2), imgui.ImVec2(mx2, my2 + R + cl), blackCol, ct + 1.5)
            dl:AddLine(imgui.ImVec2(mx2 - R - cl, my2), imgui.ImVec2(mx2 - R + 2, my2), mainCol, ct)
            dl:AddLine(imgui.ImVec2(mx2 + R - 2, my2), imgui.ImVec2(mx2 + R + cl, my2), mainCol, ct)
            dl:AddLine(imgui.ImVec2(mx2, my2 - R - cl), imgui.ImVec2(mx2, my2 - R + 2), mainCol, ct)
            dl:AddLine(imgui.ImVec2(mx2, my2 + R - 2), imgui.ImVec2(mx2, my2 + R + cl), mainCol, ct)

            local ts = imgui.CalcTextSize(label)
            outlinedText(mx2 - ts.x * 0.5, my2 + R + 16, label, mainCol)
        end

        if distH > 1.0 then
            local arrowCX = sw * 0.5
            local arrowCY = sh - 90
            local arrowR  = math.max(20, math.min(markerArrowSize[0], sh * 0.04))

            local ux = math.sin(relAngle)
            local uy = -math.cos(relAngle)

            dl:AddCircleFilled(imgui.ImVec2(arrowCX, arrowCY), arrowR + 12,
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0, 0, 0, 0.90)), 32)
            dl:AddCircle(imgui.ImVec2(arrowCX, arrowCY), arrowR + 12,
                mainCol, 32, 2)

            local tipX = arrowCX + ux * arrowR
            local tipY = arrowCY + uy * arrowR
            local perpX, perpY = -uy, ux
            local baseOffset = arrowR * 0.4
            local halfBase = arrowR * 0.55
            local b1X = arrowCX - ux * baseOffset + perpX * halfBase
            local b1Y = arrowCY - uy * baseOffset + perpY * halfBase
            local b2X = arrowCX - ux * baseOffset - perpX * halfBase
            local b2Y = arrowCY - uy * baseOffset - perpY * halfBase

            dl:AddTriangleFilled(
                imgui.ImVec2(tipX + 1, tipY + 1),
                imgui.ImVec2(b1X  + 1, b1Y  + 1),
                imgui.ImVec2(b2X  + 1, b2Y  + 1), blackCol)
            dl:AddTriangleFilled(
                imgui.ImVec2(tipX, tipY),
                imgui.ImVec2(b1X,  b1Y),
                imgui.ImVec2(b2X,  b2Y), mainCol)

            local ts = imgui.CalcTextSize(label)
            outlinedText(arrowCX - ts.x * 0.5, arrowCY - arrowR - 28, label, mainCol)
        end
    end
)

local function getVehicle()
    if not isCharInAnyCar(PLAYER_PED) then return nil end
    local ok,veh=pcall(storeCarCharIsInNoSave,PLAYER_PED)
    return (ok and veh and veh~=0) and veh or nil
end

local SPD_OUTLINE_DIRS = { {-1, 0}, {1, 0}, {0, -1}, {0, 1}, {-1,-1}, {1,-1}, {-1, 1}, {1, 1} }

imgui.OnFrame(
    function() return (speedometerEnabled[0]==true) and isCharInAnyCar(PLAYER_PED) end,
    function()
        local veh=getVehicle(); if not veh then return end
        local okS,rawS=pcall(getCarSpeed,veh); local okH,rawH=pcall(getCarHealth,veh)
        local kmh=(okS and rawS) and math.floor((rawS*180)/50.25+0.5) or 0
        local hp=(okH and rawH) and math.floor(rawH/10) or 0
        imgui.SetNextWindowPos(imgui.ImVec2(speedoPosX[0],speedoPosY[0]),imgui.Cond.Always)
        imgui.SetNextWindowBgAlpha(0)
        imgui.Begin('##spd',nil,bit.bor(imgui.WindowFlags.NoMove,imgui.WindowFlags.NoResize,
            imgui.WindowFlags.NoTitleBar,imgui.WindowFlags.NoScrollbar,
            imgui.WindowFlags.NoBackground,imgui.WindowFlags.NoInputs,imgui.WindowFlags.NoSavedSettings))
        local dl = imgui.GetWindowDrawList()
        local p  = imgui.GetCursorScreenPos()
        local lineH = imgui.GetTextLineHeight()
        local colOutline = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0,0,0,1))
        local colText    = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1,1,1,1))
        local function outlinedText(x, y, t)
            for _, d in ipairs(SPD_OUTLINE_DIRS) do dl:AddText(imgui.ImVec2(x+d[1], y+d[2]), colOutline, t) end
            dl:AddText(imgui.ImVec2(x, y), colText, t)
        end
        outlinedText(p.x, p.y, tostring(kmh).." км/ч")
        outlinedText(p.x, p.y + lineH, tostring(hp))
        imgui.Dummy(imgui.ImVec2(140, lineH*2))
        imgui.End()
    end)

local function loadImguiFontsFromMemory()
    local io_fonts = imgui.GetIO().Fonts
    if not io_fonts then
        fontReport[#fontReport+1] = "io.Fonts = nil"
        return 0
    end
    local wd = getWorkingDirectory() or "."
    local loaded = 0
    local function tryOne(id, data)
        if not data or #data == 0 then return nil, "пустой файл" end
        local ok_m, buf = pcall(function() return ffi.C.malloc(#data) end)
        if not ok_m then return nil, "ошибка malloc: "..tostring(buf) end
        if buf == nil then return nil, "malloc вернул null" end
        ffi.copy(buf, data, #data)
        local ok, res = pcall(function()
            return io_fonts:AddFontFromMemoryTTF(buf, #data, 32)
        end)
        if ok and res then return res, "загружен" end
        pcall(function() ffi.C.free(buf) end)
        return nil, "ошибка AddFont: "..tostring(res)
    end
    for _, f in ipairs(CLOCK_FONTS) do
        if f.id:match("%.ttf$") then
            local abs = wd .. "/" .. f.id
            local fh = io.open(abs, "rb")
            if not fh then
                fontReport[#fontReport+1] = f.id..": файл не найден"
            else
                local data = fh:read("*a"); fh:close()
                local font, why = tryOne(f.id, data)
                if font then
                    imguiFonts[f.id] = font
                    loaded = loaded + 1
                else
                    fontReport[#fontReport+1] = f.id..": "..tostring(why)
                end
            end
        end
    end
    local sysPaths = {"/system/fonts/Roboto-Regular.ttf", "/system/fonts/DroidSans.ttf", "/system/fonts/Roboto.ttf"}
    for _, p in ipairs(sysPaths) do
        local fh = io.open(p, "rb")
        if fh then
            local data = fh:read("*a"); fh:close()
            local font = tryOne("Arial", data)
            if font then
                imguiFonts["Arial"] = font
                loaded = loaded + 1
                break
            end
        end
    end
    if not imguiFonts["Arial"] then
        fontReport[#fontReport+1] = "Arial: системный не найден"
    end
    return loaded
end

local function loadLogoTextures()
    logoTex = {}
    for _, name in ipairs(LOGO_FILES) do
        local path = 'resource/' .. name
        local fh = io.open(path, 'rb')
        if fh then
            fh:close()
            local ok, tex = pcall(imgui.CreateTextureFromFile, path)
            if ok and tex then
                table.insert(logoTex, tex)
            end
        end
    end
    if #logoTex == 0 and rhl2Tex then
        table.insert(logoTex, rhl2Tex)
    end
    logoIdx = 1
    logoTime = 0
    return #logoTex
end

local function reportResources(fontsLoaded, logosLoaded)
    if #fontReport == 0 and logosLoaded > 0 then
        sampAddChatMessage('[rhl] все файлы загружены', -1)
    else
        sampAddChatMessage(string.format(
            '[rhl] загружено: шрифтов %d, логотипов %d',
            fontsLoaded or 0, logosLoaded or 0), -1)
        for _, e in ipairs(fontReport) do
            sampAddChatMessage('[rhl] ' .. e, -1)
        end
    end
end

imgui.OnInitialize(function()
    local baseUrl = 'https://raw.githubusercontent.com/mozaevm13-coder/rhl-resources/refs/heads/main/'
    local files = {
        {name='map.png', url=baseUrl..'map.png'},
        {name='cursor.png', url=baseUrl..'cursor.png'},
        {name='marker.png', url=baseUrl..'marker.png'},
        {name='rhl2.png', url=baseUrl..'rhl2.png'},
        {name='ofont.ru_Arteks.ttf',  url=baseUrl..'ofont.ru_Arteks.ttf'},
        {name='ofont.ru_Aurach.ttf',  url=baseUrl..'ofont.ru_Aurach.ttf'},
        {name='ofont.ru_Hemico.ttf',  url=baseUrl..'ofont.ru_Hemico.ttf'},
        {name='ofont.ru_Patefon.ttf', url=baseUrl..'ofont.ru_Patefon.ttf'},
    }
    for _, name in ipairs(LOGO_FILES) do
        table.insert(files, {name=name, url=baseUrl..name})
    end
    for _, f in ipairs(files) do ensureResource(f.url, f.name) end
    local ok,tex=pcall(imgui.CreateTextureFromFile,'resource/map.png'); fastMapTex=ok and tex or nil
    local ok2,tex2=pcall(imgui.CreateTextureFromFile,'resource/cursor.png'); cursorTex=ok2 and tex2 or nil
    local ok3,tex3=pcall(imgui.CreateTextureFromFile,'resource/marker.png'); markerTex=ok3 and tex3 or nil
    local ok4,tex4=pcall(imgui.CreateTextureFromFile,'resource/rhl2.png'); rhl2Tex=ok4 and tex4 or nil
    pluschatFont = renderCreateFont("Arial", pluschatSize, 4, 5)
    pluschatFontDirty = false
    local fontsLoaded = loadImguiFontsFromMemory()
    local logosLoaded = loadLogoTextures()
    if pendingDownloads == 0 then
        reportResources(fontsLoaded, logosLoaded)
    end
end)

local function drawClockTextImgui()
    if not clockEnabled[0] then return end
    if isPauseMenuActive() then return end
    local t = clockShowMs[0]
        and (os.date("%H:%M:%S")..string.format(".%03d",math.floor((os.clock()%1)*1000)))
        or  os.date("%H:%M:%S")
    local charW = clockFontSize * 0.55
    local tw_px = #t * charW
    local rx = math.floor(clockPos.x + clockWidth * 0.5 - tw_px * 0.5)
    local ry = math.floor(clockPos.y + clockHeight * 0.5 - clockFontSize * 0.5)
    local or_, og, ob = clockOutlineColor[0], clockOutlineColor[1], clockOutlineColor[2]
    local tr_, tg, tb
    if clockRgbEnabled[0] then tr_, tg, tb = rgb_wheel(os.clock())
    else tr_, tg, tb = clockTextColor2[0], clockTextColor2[1], clockTextColor2[2] end
    local outCol = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(or_, og, ob, 1))
    local txtCol = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(tr_, tg, tb, 1))
    local outline = clockOutlineThickness[0]
    if outline < 0 then outline = 0 end
    local fontSize = clockFontSize
    local font = imguiFonts[clockFontName]
    if not font then for _, f in pairs(imguiFonts) do font = f; break end end
    local dl = imgui.GetForegroundDrawList()
    if font then
        if outline > 0.05 then
            local steps = math.max(8, math.floor(outline * 6))
            for i = 1, steps do
                local angle = (i / steps) * math.pi * 2
                local dx = math.cos(angle) * outline
                local dy = math.sin(angle) * outline
                dl:AddText(font, fontSize, imgui.ImVec2(rx + dx, ry + dy), outCol, t)
            end
        end
        dl:AddText(font, fontSize, imgui.ImVec2(rx, ry), txtCol, t)
    else
        local scale = fontSize / math.max(8, imgui.GetFontSize())
        if scale ~= 1 then imgui.SetWindowFontScale(scale) end
        for _, d in ipairs(TEXT_OUTLINE_DIRS) do
            dl:AddText(imgui.ImVec2(rx + d[1]*outline, ry + d[2]*outline), outCol, t)
        end
        dl:AddText(imgui.ImVec2(rx, ry), txtCol, t)
        if scale ~= 1 then imgui.SetWindowFontScale(1.0) end
    end
end

imgui.OnFrame(function() return clockEnabled[0] end, drawClockTextImgui)

imgui.OnFrame(function() return clockEnabled[0] end, function()
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.Border,   imgui.ImVec4(0,0,0,0))
    imgui.SetNextWindowPos(clockPos, imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(imgui.ImVec2(clockWidth,clockHeight), imgui.Cond.Always)
    local flags = bit.bor(imgui.WindowFlags.NoResize,imgui.WindowFlags.NoCollapse,imgui.WindowFlags.NoTitleBar,
                         imgui.WindowFlags.NoBackground,imgui.WindowFlags.NoSavedSettings)
    if clockLocked[0] then flags = bit.bor(flags, imgui.WindowFlags.NoMove) end
    imgui.Begin('##clockDrag',nil,flags)
    local pos=imgui.GetWindowPos()
    if pos.x~=clockPos.x or pos.y~=clockPos.y then clockPos.x,clockPos.y=pos.x,pos.y; clock_save() end
    imgui.End(); imgui.PopStyleColor(2)
end)

local function fmToImg(x,y)
    return ((x-FM_XMIN)/(FM_XMAX-FM_XMIN))*FM_DW, ((FM_YMAX-y)/(FM_YMAX-FM_YMIN))*FM_DH
end

imgui.OnFrame(function() return fastMapOpen[0] end, function()
    if not fastMapOpen[0] then return end
    imgui.SetNextWindowBgAlpha(0)
    if not fmEditMode[0] then imgui.SetNextWindowPos(imgui.ImVec2(fmPosX[0], fmPosY[0]), imgui.Cond.Always) end
    imgui.SetNextWindowSize(imgui.ImVec2(FM_DW, FM_DH), imgui.Cond.Always)
    local flags = bit.bor(
        imgui.WindowFlags.NoResize, imgui.WindowFlags.NoScrollbar,
        imgui.WindowFlags.NoScrollWithMouse, imgui.WindowFlags.NoBackground,
        imgui.WindowFlags.NoTitleBar, imgui.WindowFlags.NoCollapse,
        imgui.WindowFlags.NoSavedSettings
    )
    if not fmEditMode[0] then
        flags = bit.bor(flags, imgui.WindowFlags.NoMove, imgui.WindowFlags.NoInputs)
    end
    imgui.Begin('##fastmap', nil, flags)
    if fmEditMode[0] then
        local wp = imgui.GetWindowPos()
        fmPosX[0] = wp.x; fmPosY[0] = wp.y
    end
    if not fastMapTex then
        txt("resource/map.png не найден")
    else
        local mp = imgui.GetCursorScreenPos()
        local dl = imgui.GetWindowDrawList()
        imgui.Image(fastMapTex, imgui.ImVec2(FM_DW, FM_DH))
        local function drawIcon(tex, x, y, size)
            local ix,iy = fmToImg(x,y)
            local sx,sy = mp.x+ix, mp.y+iy
            if tex then
                local half = size*0.5
                dl:AddImage(tex, imgui.ImVec2(sx-half, sy-half), imgui.ImVec2(sx+half, sy+half))
            else
                dl:AddCircleFilled(imgui.ImVec2(sx,sy), size*0.5, 0xFFFFFFFF, 16)
            end
        end
        local px,py = getCharCoordinates(PLAYER_PED)
        if px then drawIcon(cursorTex, px, py, 24) end
        if fmCheckX then
            local pulse = 0.5 + 0.5 * math.abs(math.sin(os.clock() * 3))
            local msize = 24 + 24 * pulse
            local ix,iy = fmToImg(fmCheckX, fmCheckY)
            local sx,sy = mp.x + ix, mp.y + iy
            local auraAlpha = 0.25 + 0.35 * (1.0 - pulse)
            local auraCol = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0, 0.85, 0.1, auraAlpha))
            dl:AddCircleFilled(imgui.ImVec2(sx, sy), msize * 0.9, auraCol, 24)
            drawIcon(markerTex, fmCheckX, fmCheckY, msize)
        end
        if fmEditMode[0] then
            local wp = imgui.GetWindowPos()
            local pulse = 0.6 + 0.4 * math.abs(math.sin(os.clock() * 4))
            local col = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0, 0.85, 0.1, pulse))
            dl:AddRect(imgui.ImVec2(wp.x - 2, wp.y - 2),
                imgui.ImVec2(wp.x + FM_DW + 2, wp.y + FM_DH + 2), col, 0, 0, 4)
        end
    end
    imgui.End()
end)

imgui.OnFrame(function() return fastMapEnabled[0] end, function()
    local locked = (hotButtonsLocked[0]==true)
    local flags = bit.bor(imgui.WindowFlags.NoCollapse,imgui.WindowFlags.NoTitleBar,
                           imgui.WindowFlags.NoBackground,imgui.WindowFlags.NoResize,
                           imgui.WindowFlags.NoScrollbar)
    if locked then flags=bit.bor(flags,imgui.WindowFlags.NoMove) end
    imgui.SetNextWindowPos(imgui.ImVec2(mapBtnPos.x,mapBtnPos.y),
        locked and imgui.Cond.Always or imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(imgui.ImVec2(mapBtnW[0]+BTN_WIN_PAD, mapBtnH[0]+BTN_WIN_PAD),imgui.Cond.Always)
    imgui.Begin('##fmbtn',nil,flags)
    local p  = imgui.GetCursorScreenPos()
    local w,h = mapBtnW[0], mapBtnH[0]
    drawBtnStyle(p, imgui.ImVec2(p.x+w, p.y+h), "Map", not locked)
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,1,1,0.06))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(1,1,1,0.12))
    imgui.PushStyleColor(imgui.Col.Border,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0,0,0,0))
    local clicked = imgui.Button("##map_btn_click", imgui.ImVec2(w,h))
    imgui.PopStyleColor(5)
    if clicked then
        fastMapOpen[0] = not (fastMapOpen[0]==true)
        if not fastMapOpen[0] then fmEditMode[0] = false end
    end
    if not locked then
        local pos = imgui.GetWindowPos()
        mapBtnPos.x = pos.x; mapBtnPos.y = pos.y
    end
    imgui.End()
end)

imgui.OnFrame(function() return styleWinEnabled[0] end, function()
    local locked = (hotButtonsLocked[0]==true)
    local flags = bit.bor(imgui.WindowFlags.NoCollapse,imgui.WindowFlags.NoTitleBar,
                           imgui.WindowFlags.NoBackground,imgui.WindowFlags.NoResize,
                           imgui.WindowFlags.NoScrollbar)
    if locked then flags=bit.bor(flags,imgui.WindowFlags.NoMove) end
    imgui.SetNextWindowPos(imgui.ImVec2(styleBtnPos.x,styleBtnPos.y),
        locked and imgui.Cond.Always or imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(imgui.ImVec2(styleBtnW[0]+BTN_WIN_PAD, styleBtnH[0]+BTN_WIN_PAD),imgui.Cond.Always)
    imgui.Begin('##stylebtn',nil,flags)
    local p  = imgui.GetCursorScreenPos()
    local w,h = styleBtnW[0], styleBtnH[0]
    drawBtnStyle(p, imgui.ImVec2(p.x+w, p.y+h), "Style", not locked)
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,1,1,0.06))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(1,1,1,0.12))
    imgui.PushStyleColor(imgui.Col.Border,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0,0,0,0))
    local clicked = imgui.Button("##style_btn_click", imgui.ImVec2(w,h))
    imgui.PopStyleColor(5)
    if clicked then
        lua_thread.create(function()
            sampSendChat("/style")
            styleDialogInfo.state=true
            repeat wait(0) until styleDialogInfo.dialoged
            styleDialogInfo.dialoged=false
            sampSendDialogResponse(styleDialogInfo.id,1,0,"")
            wait(400)
            sampSendDialogResponse(styleDialogInfo.id,0,65534,"")
            styleDialogInfo.state=false
        end)
    end
    if not locked then
        local pos = imgui.GetWindowPos()
        styleBtnPos.x = pos.x; styleBtnPos.y = pos.y
    end
    imgui.End()
end)

function sampev.onSetRaceCheckpoint(type,position) fmCheckX,fmCheckY=position.x,position.y end

local function samp_create_sync_data(sync_type, copy_from_player)
    local ffi       = require 'ffi'
    local sampfuncs = require 'sampfuncs'
    local raknet    = require 'samp.raknet'
    require 'samp.synchronization'
    copy_from_player = copy_from_player or true
    local sync_traits = {
        player    = {'PlayerSyncData',    raknet.PACKET.PLAYER_SYNC,    sampStorePlayerOnfootData},
        vehicle   = {'VehicleSyncData',   raknet.PACKET.VEHICLE_SYNC,   sampStorePlayerIncarData},
        passenger = {'PassengerSyncData', raknet.PACKET.PASSENGER_SYNC, sampStorePlayerPassengerData},
        aim       = {'AimSyncData',       raknet.PACKET.AIM_SYNC,       sampStorePlayerAimData},
        trailer   = {'TrailerSyncData',   raknet.PACKET.TRAILER_SYNC,   sampStorePlayerTrailerData},
        unoccupied= {'UnoccupiedSyncData',raknet.PACKET.UNOCCUPIED_SYNC,nil},
        bullet    = {'BulletSyncData',    raknet.PACKET.BULLET_SYNC,    nil},
        spectator = {'SpectatorSyncData', raknet.PACKET.SPECTATOR_SYNC, nil},
    }
    local sync_info = sync_traits[sync_type]
    local data_type = 'struct ' .. sync_info[1]
    local data = ffi.new(data_type, {})
    local raw_data_ptr = tonumber(ffi.cast('uintptr_t', ffi.new(data_type .. '*', data)))
    if copy_from_player then
        local copy_func = sync_info[3]
        if copy_func then
            local _, player_id
            if copy_from_player == true then _, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            else player_id = tonumber(copy_from_player) end
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
        __index    = function(t, index) return data[index] end,
        __newindex = function(t, index, value) data[index] = value end,
    }
    return setmetatable({send = func_send}, mt)
end

local nCooldown = false
local function nBtnPress()
    if nCooldown then return end
    nCooldown = true
    if isCharOnFoot(PLAYER_PED) then
        local d = samp_create_sync_data("player")
        local x, y, z = getCharCoordinates(PLAYER_PED)
        d.position = {x, y, z}
        d.quaternion[4] = 1.1755083638069e-38
        d.send()
    else
        sampSendChat("/engine")
    end
    lua_thread.create(function() wait(543); nCooldown = false end)
end

imgui.OnFrame(function() return nWinEnabled[0] end, function()
    local locked = (hotButtonsLocked[0]==true)
    local flags  = bit.bor(imgui.WindowFlags.NoCollapse,imgui.WindowFlags.NoTitleBar,
                            imgui.WindowFlags.NoBackground,imgui.WindowFlags.NoResize,
                            imgui.WindowFlags.NoScrollbar)
    if locked then flags=bit.bor(flags,imgui.WindowFlags.NoMove) end
    imgui.SetNextWindowPos(imgui.ImVec2(nBtnPos.x,nBtnPos.y),
        locked and imgui.Cond.Always or imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(imgui.ImVec2(nBtnW[0]+BTN_WIN_PAD, nBtnH[0]+BTN_WIN_PAD),imgui.Cond.Always)
    imgui.Begin('##nbtn',nil,flags)
    local p  = imgui.GetCursorScreenPos()
    local w,h = nBtnW[0], nBtnH[0]
    drawBtnStyle(p, imgui.ImVec2(p.x+w, p.y+h), "N", not locked)
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,1,1,0.06))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(1,1,1,0.12))
    imgui.PushStyleColor(imgui.Col.Border,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0,0,0,0))
    local clicked = imgui.Button("##n_btn_click", imgui.ImVec2(w,h))
    imgui.PopStyleColor(5)
    if clicked then nBtnPress() end
    if not locked then
        local pos = imgui.GetWindowPos()
        nBtnPos.x = pos.x; nBtnPos.y = pos.y
    end
    imgui.End()
end)

local SIDEBAR_W = 240
local TABS = {
    {id="skip",    label="СКИП",        hint="Автоматический скип диалогов"},
    {id="captcha", label="КАПЧА",       hint="Работа с капчей и её счётчиком"},
    {id="catch",   label="ЛОВЛЯ",       hint="Маркер, поиск, pluschat"},
    {id="visual",  label="ВИЗУАЛ",      hint="Часы, спидометр"},
    {id="buttons", label="КНОПКИ",      hint="Внешний вид кастомных кнопок"},
    {id="about",   label="О СКРИПТЕ",   hint="Команды, тема, диагностика"},
}
currentTab = TABS[1].id

local function currentTabData()
    for _,t in ipairs(TABS) do if t.id == currentTab then return t end end
    return TABS[1]
end

local function sep()
    imgui.Spacing()
    local dl=imgui.GetWindowDrawList(); local p=imgui.GetCursorScreenPos()
    local w=imgui.GetContentRegionAvail().x
    dl:AddLine(p,imgui.ImVec2(p.x+w,p.y),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(accentColor[0],accentColor[1],accentColor[2],0.35)),1)
    imgui.Spacing()
end

local function sectionHeader(title)
    imgui.Spacing(); imgui.Spacing()
    local dl = imgui.GetWindowDrawList()
    local ar,ag,ab = accentColor[0],accentColor[1],accentColor[2]
    local p = imgui.GetCursorScreenPos()
    local w = imgui.GetContentRegionAvail().x
    dl:AddRectFilled(p, imgui.ImVec2(p.x + w, p.y + 1),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar, ag, ab, 0.35)), 0)
    imgui.Spacing()
    local cur = imgui.GetCursorScreenPos()
    dl:AddRectFilled(cur, imgui.ImVec2(cur.x + 4, cur.y + 20),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar, ag, ab, 1.0)), 2)
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 12)
    local pTxt = imgui.GetCursorScreenPos()
    local colU32 = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar, ag, ab, 1.0))
    drawOutlinedAt(pTxt.x, pTxt.y, title, colU32)
    local ts = imgui.CalcTextSize(title)
    imgui.Dummy(imgui.ImVec2(ts.x, ts.y))
    imgui.Spacing()
end

local function infoButton(tabId)
    local size = 44
    local p  = imgui.GetCursorScreenPos()
    local ar,ag,ab = accentColor[0], accentColor[1], accentColor[2]
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.Border,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0,0,0,0))
    local clicked = imgui.Button("##info_"..tabId, imgui.ImVec2(size, size))
    local hovered = imgui.IsItemHovered()
    imgui.PopStyleColor(5)
    local dl = imgui.GetWindowDrawList()
    local cx = p.x + size/2; local cy = p.y + size/2; local r  = size/2 - 2
    if hovered then
        dl:AddCircleFilled(imgui.ImVec2(cx, cy), r + 6,
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar,ag,ab,0.22)), 32)
    end
    dl:AddCircleFilled(imgui.ImVec2(cx, cy), r,
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.05, 0.02, 0.03, 0.95)), 32)
    local fillAlpha = hovered and 0.95 or 0.75
    dl:AddCircleFilled(imgui.ImVec2(cx, cy), r - 2,
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar, ag, ab, fillAlpha)), 32)
    dl:AddCircle(imgui.ImVec2(cx, cy), r,
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar, ag, ab, 1.0)), 32, 2.5)
    dl:AddCircle(imgui.ImVec2(cx, cy), r + 1,
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0,0,0,0.6)), 32, 1.0)
    local white = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1,1,1,1))
    local stem_w = 4.5; local stem_h = size * 0.30; local dot_r  = 3.2
    dl:AddCircleFilled(imgui.ImVec2(cx, cy - stem_h * 0.95), dot_r, white, 12)
    dl:AddRectFilled(imgui.ImVec2(cx - stem_w/2, cy - stem_h*0.40),
        imgui.ImVec2(cx + stem_w/2, cy + stem_h*0.85), white, stem_w/2)
    if hovered then imgui.SetTooltip("Справка по разделу") end
    if clicked then helpOpenFor = tabId end
end

local function tabHeader()
    local t = currentTabData()
    local baseX, baseY = imgui.GetCursorPosX(), imgui.GetCursorPosY()
    local labelSize = imgui.CalcTextSize(t.label)
    local lineH = imgui.GetTextLineHeight()
    txt(t.label)
    local afterTextY = imgui.GetCursorPosY()
    local btnSize = 44
    local offsetY = baseY + (lineH - btnSize) * 0.5
    imgui.SetCursorPos(imgui.ImVec2(baseX + labelSize.x + 14, offsetY))
    infoButton(t.id)
    local newY = math.max(afterTextY, baseY + btnSize + 4)
    imgui.SetCursorPos(imgui.ImVec2(baseX, newY))
    txtDim(t.hint)
    sep()
end

local function drawSkipTab()
    tabHeader()
    sectionHeader("АВТО-ПРОПУСК ДИАЛОГОВ")
    toggleRow("Скип диалога семей","ID 26007 — автопропуск при появлении",skipEnabled,cfg_save)
    toggleRow("Скип выбора вертолёта","ID 26151 — авто-«Принять»",pickupSkipEnabled,cfg_save)
    sectionHeader("СОХРАНЕНИЕ ВЫХОДА — РИЭЛТОР")
    toggleRow("Включить сохранение выхода","Работает после команды /ex",realtorEnabled, cfg_save)
end

local function drawCaptchaTab()
    tabHeader()
    sectionHeader("ТАЙМЕР")
    toggleRow("Таймер капчи","Замеряет время ввода и отправляет в чат",captchaTimerEnabled,cfg_save)
    sectionHeader("ФОРМАТ СООБЩЕНИЯ")
    txtDim("Доступны: {input} — что ввёл, {time} — время в секундах")
    imgui.Spacing()
    imgui.SetNextItemWidth(-1)
    if imgui.InputText("##captchaMsg",captchaMsgBuf,CAPTCHA_BUF) then
        captchaIni.main.text=ffi.string(captchaMsgBuf); captcha_save()
    end
    imgui.Spacing()
    txt("Предпросмотр:")
    txtDim(captcha_format(ffi.string(captchaMsgBuf), "7293", "3.42"))
    sectionHeader("СЧЁТЧИК")
    txt("Введено капч: "..tostring(captchaTotalCount))
    imgui.Spacing()
    if btn("Сбросить счётчик##captchaReset") then captchaTotalCount = 0; captcha_save() end
end

local function drawCatchTab()
    tabHeader()

    sectionHeader("МАРКЕР ПИКАПА")
    imgui.Spacing()
    if btn("Поставить##setmark") then setMarkerAtPlayer() end
    imgui.SameLine()
    if btn("Убрать##delmark") then removeMarker(); sampAddChatMessage("[rhl] маркер снят",-1) end

    imgui.Spacing()
    txt("Радиус метки"); imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("##markRadius", markerRadius, 15, 90) then cfg_save() end
    imgui.SameLine(); txtDim(string.format("%.0f px", markerRadius[0]))

    txt("Толщина линий"); imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("##markThick", markerThickness, 1.0, 10.0) then cfg_save() end
    imgui.SameLine(); txtDim(string.format("%.1f", markerThickness[0]))

    txt("Размер стрелки (компас)"); imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("##markArrow", markerArrowSize, 12, 60) then cfg_save() end
    imgui.SameLine(); txtDim(string.format("%.0f px", markerArrowSize[0]))

    txt("Цвет метки")
    if imgui.ColorEdit4("##markColor", markerColor) then cfg_save() end

    txtDim("Превью:")
    local prevSize = math.max(120, markerRadius[0] * 2 + 60)
    local pp = imgui.GetCursorScreenPos()
    local pdl = imgui.GetWindowDrawList()
    local mcx, mcy = pp.x + prevSize * 0.5, pp.y + prevSize * 0.5
    local mcol = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(markerColor[0], markerColor[1], markerColor[2], markerColor[3]))
    local mdim = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(markerColor[0], markerColor[1], markerColor[2], markerColor[3] * 0.35))
    local mglow = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(markerColor[0], markerColor[1], markerColor[2], markerColor[3] * 0.20))
    local mblk = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0, 0, 0, 0.9))
    pdl:AddCircleFilled(imgui.ImVec2(mcx, mcy), markerRadius[0] + 14, mglow, 48)
    pdl:AddCircle(imgui.ImVec2(mcx, mcy), markerRadius[0] + 6, mdim, 48, 1.5)
    pdl:AddCircle(imgui.ImVec2(mcx, mcy), markerRadius[0] + 1.5, mblk, 48, 2.5)
    pdl:AddCircle(imgui.ImVec2(mcx, mcy), markerRadius[0], mcol, 48, markerThickness[0])
    pdl:AddCircleFilled(imgui.ImVec2(mcx, mcy), math.max(4, markerRadius[0] * 0.18), mblk, 16)
    pdl:AddCircleFilled(imgui.ImVec2(mcx, mcy), math.max(3, markerRadius[0] * 0.15), mcol, 16)
    local cl2 = math.max(8, markerRadius[0] * 0.45)
    local ct2 = math.max(2, markerThickness[0])
    pdl:AddLine(imgui.ImVec2(mcx - markerRadius[0] - cl2, mcy), imgui.ImVec2(mcx - markerRadius[0] + 2, mcy), mcol, ct2)
    pdl:AddLine(imgui.ImVec2(mcx + markerRadius[0] - 2, mcy), imgui.ImVec2(mcx + markerRadius[0] + cl2, mcy), mcol, ct2)
    pdl:AddLine(imgui.ImVec2(mcx, mcy - markerRadius[0] - cl2), imgui.ImVec2(mcx, mcy - markerRadius[0] + 2), mcol, ct2)
    pdl:AddLine(imgui.ImVec2(mcx, mcy + markerRadius[0] - 2), imgui.ImVec2(mcx, mcy + markerRadius[0] + cl2), mcol, ct2)
    imgui.Dummy(imgui.ImVec2(prevSize, prevSize))

    sectionHeader("АВТОМАТИЗАЦИЯ")
    toggleRow("FastMap","/mapset — переместить",fastMapEnabled,function()
        cfg_save(); if not (fastMapEnabled[0]==true) then fastMapOpen[0]=false; fmEditMode[0]=false end
    end)

    sectionHeader("PLUSCHAT — ОПОВЕЩЕНИЕ ОБ ОТЕЛЕ")
    txtDim("Отслеживает фразу:")
    txtDim(PLUSCHAT_TARGET_UTF8)
    imgui.Spacing()
    toggleRow("Включить pluschat","Показывать фразу крупно при появлении",pluschatEnabled,cfg_save)
    imgui.Spacing()
    txt("Позиция X"); imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("##pcX", pluschatPosX, 0, 1920) then cfg_save() end
    txt("Позиция Y"); imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("##pcY", pluschatPosY, 0, 1080) then cfg_save() end
    txt("Размер шрифта"); imgui.SetNextItemWidth(-1)
    if imgui.SliderInt("##pcSize", pluschatSizeBuf, 8, 48) then
        pluschatSize = pluschatSizeBuf[0]; pluschatFontDirty = true; cfg_save()
    end
    txt("Цвет текста")
    if imgui.ColorEdit4("##pcColor", pluschatColor) then cfg_save() end
end

local function drawVisualTab()
    tabHeader()
    sectionHeader("ЧАСЫ — ВКЛЮЧЕНИЕ")
    toggleRow("Серверное время","Показывать часы на экране",clockEnabled,clock_save)
    toggleRow("Миллисекунды","Добавляет .000 к времени",clockShowMs,clock_save)
    sectionHeader("ЧАСЫ — ШРИФТ")
    txt("Шрифт"); imgui.SetNextItemWidth(-1)
    local curLabel = clockFontName
    for _, f in ipairs(CLOCK_FONTS) do
        if f.id == clockFontName then curLabel = f.label; break end
    end
    if imgui.BeginCombo("##clock_font", curLabel) then
        for _, f in ipairs(CLOCK_FONTS) do
            local selected = (f.id == clockFontName)
            local isLoaded = (f.id == "Arial") or (imguiFonts[f.id] ~= nil)
            local display = f.label
            if not isLoaded then display = f.label .. "  [не загружен]" end
            if imgui.Selectable(display, selected) then clockSetFont(f.id) end
            if selected then imgui.SetItemDefaultFocus() end
        end
        imgui.EndCombo()
    end
    imgui.Spacing()
    txt("Размер шрифта"); imgui.SetNextItemWidth(-1)
    if imgui.SliderInt("##clockFontSize", clockFontSizeBuf, 10, 120) then
        clockFontSize = clockFontSizeBuf[0]; clock_save()
    end
    sectionHeader("ЧАСЫ — РАЗМЕР ОБЛАСТИ")
    imgui.SetNextItemWidth(-1)
    if imgui.SliderInt("Ширина##cw", clockWidthBuf, 50, 600) then
        clockWidth = clockWidthBuf[0]; clock_save()
    end
    imgui.SetNextItemWidth(-1)
    if imgui.SliderInt("Высота##ch", clockHeightBuf, 30, 400) then
        clockHeight = clockHeightBuf[0]; clock_save()
    end
    sectionHeader("ЧАСЫ — ЦВЕТА")
    txt("Цвет текста")
    if imgui.ColorEdit3("##clockTxt2", clockTextColor2) then cfg_save() end
    txt("Цвет обводки")
    if imgui.ColorEdit3("##clockOut2", clockOutlineColor) then cfg_save() end
    sectionHeader("ЧАСЫ — ОБВОДКА")
    txt("Толщина обводки"); imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("##clockOutThick", clockOutlineThickness, 0, 10) then cfg_save() end
    sectionHeader("ЧАСЫ — RGB")
    toggleRow("RGB часы","Плавное переливание цветами текста",clockRgbEnabled,cfg_save)
    sectionHeader("СПИДОМЕТР")
    toggleRow("Включить","Скорость (км/ч) и HP авто",speedometerEnabled,cfg_save)
    txt("Позиция спидометра")
    imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("X##spdX",speedoPosX,0,1920) then cfg_save() end
    imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("Y##spdY",speedoPosY,0,1080) then cfg_save() end
    sectionHeader("КАРТА (FASTMAP)")
    imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("X##fmX", fmPosX, -1000, 1920) then cfg_save() end
    imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("Y##fmY", fmPosY, -1000, 1080) then cfg_save() end
end

local function drawButtonsTab()
    tabHeader()
    sectionHeader("РЕЖИМ КНОПОК")
    toggleRow("Зафиксировать кнопки",
        "Вкл — клики работают; Выкл — можно таскать пальцем",
        hotButtonsLocked, cfg_save)
    imgui.Spacing()
    if hotButtonsLocked[0] then
        txtDim("Сейчас: кнопки зафиксированы — клики работают.")
    else
        txtDim("Сейчас: кнопки можно перетаскивать, клики тоже работают.")
    end
    sectionHeader("СКРУГЛЕНИЕ УГЛОВ")
    txt("Радиус скругления кнопок")
    imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("##btnRounding", btnRounding, 0, 30) then cfg_save() end
    imgui.SameLine(); txtDim(string.format("%.0f px", btnRounding[0]))
    sectionHeader("ОБЩИЕ НАСТРОЙКИ")
    toggleRow("Обводка кнопок","Рамка вокруг кнопок",btnOutlineEnabled,cfg_save)
    toggleRow("Фон кнопок","Фон внутри кнопок",btnBgEnabled,cfg_save)
    sectionHeader("ЦВЕТА И ТОЛЩИНА")
    if imgui.ColorEdit4("Фон##btnBg",      btnBgColor)     then cfg_save() end
    if imgui.ColorEdit4("Рамка##btnBorder",btnBorderColor) then cfg_save() end
    if imgui.ColorEdit4("Текст##btnText",  btnTextColor)   then cfg_save() end
    txt("Толщина обводки"); imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("##btnThick",btnThickness,0.5,8.0) then cfg_save() end
    imgui.SameLine(); txtDim(string.format("%.1f", btnThickness[0]))
    sectionHeader("КНОПКА MAP")
    imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("Ширина##mapW",mapBtnW,20.0,1000.0) then cfg_save() end
    imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("Высота##mapH",mapBtnH,15.0,1000.0) then cfg_save() end
    txtDim("Предпросмотр:"); btn("Map",imgui.ImVec2(mapBtnW[0],mapBtnH[0]))
    sectionHeader("КНОПКА STYLE")
    toggleRow("Показывать","/cstyle",styleWinEnabled,cfg_save)
    imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("Ширина##styleW",styleBtnW,20.0,1000.0) then cfg_save() end
    imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("Высота##styleH",styleBtnH,15.0,1000.0) then cfg_save() end
    txtDim("Предпросмотр:"); btn("Style",imgui.ImVec2(styleBtnW[0],styleBtnH[0]))
    sectionHeader("КНОПКА N")
    toggleRow("Показывать","/nn",nWinEnabled,function()
        ini.cfg.nWinEnabled=(nWinEnabled[0]==true); inicfg.save(ini,"config.ini")
    end)
    imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("Ширина##nW",nBtnW,20.0,1000.0) then cfg_save() end
    imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("Высота##nH",nBtnH,15.0,1000.0) then cfg_save() end
    txtDim("Предпросмотр:"); btn("N",imgui.ImVec2(nBtnW[0],nBtnH[0]))
end

local function drawAboutTab()
    tabHeader()
    sectionHeader("О СКРИПТЕ")
    txt("rhl  v1.530 beta")
    txtDim("Автор: krvdd")

    sectionHeader("КОМАНДЫ")
    local cmds = {
        {"/rhl",         "открыть или закрыть меню скрипта"},
        {"/metka",       "поставить метку-прицел на текущей позиции"},
        {"/fh <номер>",  "найти дом (аналог /findihouse)"},
        {"/fb <номер>",  "найти бизнес (аналог /findibiz)"},
        {"/ex",          "активировать сохранение выхода риэлтора"},
        {"/mapset",      "двигать карту (режим FastMap)"},
        {"/fixbut",      "зафиксировать или разморозить кнопки"},
        {"/fixwatch",    "зафиксировать или разморозить часы"},
        {"/pctest",      "тестовый показ pluschat-фразы"},
        {"/cstyle",      "включить или скрыть кнопку Style"},
        {"/nn",          "включить или скрыть кнопку N"},
        {"/cpc",         "инфо про отключённую открывашку дверей"},
        {"/fontreload",  "перезагрузить ресурсы (шрифты, логотипы)"},
        {"/reload",      "принудительно перезагрузить скрипт"},
    }
    for _, c in ipairs(cmds) do
        txt(c[1])
        imgui.SameLine()
        imgui.SetCursorPosX(imgui.GetCursorPosX() + 4)
        txtDim("— " .. c[2])
    end

    sectionHeader("АВТО-ПЕРЕЗАГРУЗКА")
    txtDim("При первом запуске скрипт скачивает ресурсы с GitHub.")
    txtDim("После завершения загрузки он автоматически")
    txtDim("перезапускается — файлы подхватываются корректно.")
    txtDim("Если ресурсы уже есть — перезагрузка не происходит.")

    sectionHeader("ВНЕШНИЙ ВИД МЕНЮ")
    txt("Прозрачность"); imgui.SetNextItemWidth(-1)
    if imgui.SliderFloat("##alpha",uiAlpha,0.1,1.0) then cfg_save() end
    txt("Акцентный цвет")
    if imgui.ColorEdit3("##accent",accentColor) then cfg_save() end
end

local TAB_DRAW={
    skip=drawSkipTab,captcha=drawCaptchaTab,catch=drawCatchTab,
    visual=drawVisualTab,buttons=drawButtonsTab,about=drawAboutTab,
}

local function drawSidebar()
    imgui.PushStyleColor(imgui.Col.ChildBg,imgui.ImVec4(0.03,0.03,0.03,1.0))
    imgui.BeginChild("##sb",imgui.ImVec2(SIDEBAR_W,0),false)
    imgui.Spacing()
    imgui.SetCursorPosX(14); txt("Respowns")
    imgui.SetCursorPosX(14); txt("Helper")
    imgui.SetCursorPosX(14); txt("Lolvya")
    imgui.Spacing()
    if #logoTex > 0 then
        local now = os.clock()
        if now - logoTime >= LOGO_INTERVAL then
            logoTime = now
            logoIdx = logoIdx + 1
            if logoIdx > #logoTex then logoIdx = 1 end
        end
        local avail = SIDEBAR_W - 28
        imgui.SetCursorPosX(14)
        imgui.Image(logoTex[logoIdx], imgui.ImVec2(avail, avail))
    end
    imgui.Spacing(); imgui.Spacing()
    local rnd = BTN_ROUNDING
    for _,t in ipairs(TABS) do
        local active = (currentTab == t.id)
        imgui.SetCursorPosX(14)
        local p = imgui.GetCursorScreenPos()
        local w = SIDEBAR_W - 28
        local h = 58
        local dl = imgui.GetWindowDrawList()
        local bgCol = active
            and imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.92,0.92,0.92,1.0))
            or  imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.06,0.06,0.06,0.95))
        dl:AddRectFilled(p, imgui.ImVec2(p.x+w, p.y+h), bgCol, rnd)
        if not active then
            dl:AddRect(p, imgui.ImVec2(p.x+w, p.y+h),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.18,0.18,0.18,0.7)), rnd, 15, 1.0)
        end
        local markCol = active
            and imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.15,0.15,0.15,1.0))
            or  imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.60,0.60,0.60,1.0))
        dl:AddCircleFilled(imgui.ImVec2(p.x+22, p.y+h*0.5), 3.5, markCol, 12)
        local label = t.label
        local ts = imgui.CalcTextSize(label)
        local cx = p.x+42; local cy = p.y+(h-ts.y)*0.5
        local txtCol = active
            and imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.10,0.10,0.10,1.0))
            or  imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.85,0.85,0.85,1.0))
        if active then dl:AddText(imgui.ImVec2(cx, cy), txtCol, label)
        else drawOutlinedAt(cx, cy, label, txtCol) end
        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,1,1, active and 0.10 or 0.05))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(1,1,1,0.15))
        imgui.PushStyleColor(imgui.Col.Border,        imgui.ImVec4(0,0,0,0))
        if imgui.Button("##tab_"..t.id, imgui.ImVec2(w, h)) then currentTab = t.id end
        imgui.PopStyleColor(4)
        imgui.Spacing()
    end
    applyTouchScrollInChild(scrollStates.sidebar)
    imgui.EndChild(); imgui.PopStyleColor(1)
end

imgui.OnFrame(function() return windowVisible[0] end, function()
    if mainWinPos.x > 0 and mainWinPos.y > 0 then
        imgui.SetNextWindowPos(imgui.ImVec2(mainWinPos.x, mainWinPos.y), imgui.Cond.FirstUseEver)
    end
    imgui.SetNextWindowSize(imgui.ImVec2(700, 560), imgui.Cond.FirstUseEver)
    if imgui.Begin("##rhlmain", windowVisible, bit.bor(
            imgui.WindowFlags.NoCollapse,
            imgui.WindowFlags.NoTitleBar,
            imgui.WindowFlags.NoMove,
            imgui.WindowFlags.NoSavedSettings)) then
        local io = imgui.GetIO()
        local wp = imgui.GetWindowPos()
        local ws = imgui.GetWindowSize()
        local dl = imgui.GetWindowDrawList()
        local ar,ag,ab = accentColor[0], accentColor[1], accentColor[2]
        local mp = io.MousePos
        local isDown = io.MouseDown[0]
        local TOP_BAR_H = 30
        local inTopBar = isDown and
            mp.x >= wp.x and mp.x <= wp.x + ws.x and
            mp.y >= wp.y and mp.y <= wp.y + TOP_BAR_H
        if dragState.active and isDown then
            local dx = mp.x - dragState.lastX
            local dy = mp.y - dragState.lastY
            if dx ~= 0 or dy ~= 0 then
                imgui.SetWindowPos(imgui.ImVec2(wp.x + dx, wp.y + dy))
            end
            dragState.lastX = mp.x
            dragState.lastY = mp.y
        elseif not isDown then
            dragState.active = false
        end
        if not dragState.active and isDown and inTopBar and not imgui.IsAnyItemActive() then
            dragState.active = true
            dragState.lastX = mp.x
            dragState.lastY = mp.y
        end
        dl:AddRectFilled(wp, imgui.ImVec2(wp.x + ws.x, wp.y + 2),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar,ag,ab,0.85)))
        if inTopBar and not dragState.active then
            dl:AddRectFilled(
                imgui.ImVec2(wp.x + ws.x*0.35, wp.y + 6),
                imgui.ImVec2(wp.x + ws.x*0.65, wp.y + 10),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar,ag,ab,0.35)), 2)
        end
        if math.abs(mainWinPos.x - wp.x) > 0.5 or math.abs(mainWinPos.y - wp.y) > 0.5 then
            mainWinPos.x = wp.x
            mainWinPos.y = wp.y
            ini.cfg.mainWinPosX = wp.x
            ini.cfg.mainWinPosY = wp.y
            saveCounter = saveCounter + 1
            if saveCounter >= 30 then
                pcall(function() inicfg.save(ini, "config.ini") end)
                saveCounter = 0
            end
        end
        local xSize = 26
        local xPos = imgui.ImVec2(wp.x + ws.x - xSize - 10, wp.y + 8)
        dl:AddText(imgui.ImVec2(xPos.x + 7, xPos.y + 3),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.85,0.55,0.55,1.0)), "X")
        imgui.SetCursorScreenPos(xPos)
        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(ar,ag,ab,0.30))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(ar,ag,ab,0.50))
        imgui.PushStyleColor(imgui.Col.Border,        imgui.ImVec4(0,0,0,0))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0,0,0,0))
        if imgui.Button("##close", imgui.ImVec2(xSize, xSize)) then windowVisible[0] = false end
        imgui.PopStyleColor(5)
        imgui.SetCursorPos(imgui.ImVec2(0, TOP_BAR_H + 4))
        drawSidebar()
        imgui.SameLine()
        imgui.BeginChild("##content", imgui.ImVec2(0, 0), false)
        TAB_DRAW[currentTab]()
        applyTouchScrollInChild(scrollStates.content)
        imgui.EndChild()
    end
    imgui.End()
end)

imgui.OnFrame(function() return helpOpenFor ~= nil end, function()
    if not helpOpenFor then return end
    local help = TAB_HELP[helpOpenFor]
    if not help then helpOpenFor = nil; return end
    local io_size = imgui.GetIO().DisplaySize
    local bg = imgui.GetBackgroundDrawList()
    bg:AddRectFilled(imgui.ImVec2(0,0), imgui.ImVec2(io_size.x, io_size.y),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0, 0, 0, 0.72)))
    local winW = math.max(720, math.min(1600, io_size.x * 0.90))
    local winH = math.min(780, io_size.y * 0.90)
    imgui.SetNextWindowSize(imgui.ImVec2(winW, winH), imgui.Cond.Always)
    imgui.SetNextWindowPos(imgui.ImVec2(io_size.x/2, io_size.y/2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowFocus()
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.05, 0.02, 0.03, 0.99))
    imgui.PushStyleColor(imgui.Col.Border,   imgui.ImVec4(accentColor[0], accentColor[1], accentColor[2], 0.9))
    local flags = bit.bor(imgui.WindowFlags.NoResize, imgui.WindowFlags.NoCollapse,
                          imgui.WindowFlags.NoTitleBar, imgui.WindowFlags.NoSavedSettings)
    imgui.Begin("##helpwin", nil, flags)
    local ar,ag,ab = accentColor[0], accentColor[1], accentColor[2]
    local wp = imgui.GetWindowPos()
    local ws = imgui.GetWindowSize()
    local dl = imgui.GetWindowDrawList()
    dl:AddRectFilled(wp, imgui.ImVec2(wp.x + ws.x, wp.y + 4),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar,ag,ab,0.95)))
    local xSize = 36
    local xPos = imgui.ImVec2(wp.x + ws.x - xSize - 14, wp.y + 14)
    dl:AddText(imgui.ImVec2(xPos.x + 11, xPos.y + 6),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.85,0.55,0.55,1.0)), "X")
    imgui.SetCursorScreenPos(xPos)
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(ar,ag,ab,0.40))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(ar,ag,ab,0.60))
    imgui.PushStyleColor(imgui.Col.Border,        imgui.ImVec4(0,0,0,0))
    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0,0,0,0))
    if imgui.Button("##helpclose", imgui.ImVec2(xSize, xSize)) then helpOpenFor = nil end
    imgui.PopStyleColor(5)
    imgui.SetCursorPosY(imgui.GetCursorPosY() + 28)
    local pBar = imgui.GetCursorScreenPos()
    dl:AddRectFilled(imgui.ImVec2(pBar.x + 6, pBar.y + 4), imgui.ImVec2(pBar.x + 13, pBar.y + 34),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar,ag,ab,1.0)), 3)
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 24)
    local pTxt = imgui.GetCursorScreenPos()
    drawOutlinedAt(pTxt.x, pTxt.y, help.title, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar,ag,ab,1.0)))
    local tsT = imgui.CalcTextSize(help.title)
    imgui.Dummy(imgui.ImVec2(tsT.x, tsT.y))
    imgui.Spacing()
    local lp = imgui.GetCursorScreenPos()
    local lw = imgui.GetContentRegionAvail().x
    dl:AddLine(lp, imgui.ImVec2(lp.x+lw, lp.y),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar,ag,ab,0.45)), 2)
    imgui.Spacing()
    imgui.BeginChild("##helpbody", imgui.ImVec2(0, -68), false)
    for _, line in ipairs(help.body) do
        if line == "" then imgui.Spacing()
        elseif line:sub(1, #"● ") == "● " then
            imgui.Spacing()
            local pS = imgui.GetCursorScreenPos()
            drawOutlinedAt(pS.x, pS.y, line, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(ar,ag,ab,1.0)))
            local ts2 = imgui.CalcTextSize(line)
            imgui.Dummy(imgui.ImVec2(ts2.x, ts2.y))
        elseif line:sub(1, #"▸ ") == "▸ " then imgui.Spacing(); txt(line)
        elseif line:sub(1, 2) == "  " then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 16); txtDim(line)
        else txtDim(line) end
    end
    applyTouchScrollInChild(scrollStates.help)
    imgui.EndChild()
    imgui.SetCursorPosY(ws.y - 58)
    local btnW = 280
    local baseCX = imgui.GetCursorPosX()
    local regionW = imgui.GetContentRegionAvail().x
    imgui.SetCursorPosX(baseCX + (regionW - btnW) / 2)
    if btn("Понятно##helpok", imgui.ImVec2(btnW, 44)) then helpOpenFor = nil end
    imgui.End()
    imgui.PopStyleColor(2)
end)

function main()
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("rhl", function() windowVisible[0]=not windowVisible[0] end)

    sampRegisterChatCommand("metka",  setMarkerAtPlayer)
    sampRegisterChatCommand("cpc", function()
        sampAddChatMessage("[rhl] Открывашка дверей временно отключена из-за бага лаунчера (сброс колёс).", -1)
    end)
    sampRegisterChatCommand("cstyle", function() styleWinEnabled[0]=not (styleWinEnabled[0]==true); cfg_save() end)
    sampRegisterChatCommand("nn", function()
        nWinEnabled[0] = not (nWinEnabled[0]==true)
        ini.cfg.nWinEnabled = (nWinEnabled[0]==true)
        inicfg.save(ini,"config.ini")
    end)

    sampRegisterChatCommand("fh", function(args)
        if not args or args == "" then
            sampAddChatMessage("[rhl] /fh <номер> — найти дом по номеру (аналог /findihouse)", -1)
            return
        end
        local num = tonumber(args)
        if not num then
            sampAddChatMessage("[rhl] /fh <номер> — номер должен быть числом", -1)
            return
        end
        sampSendChat("/findihouse " .. num)
    end)

    sampRegisterChatCommand("fb", function(args)
        if not args or args == "" then
            sampAddChatMessage("[rhl] /fb <номер> — найти бизнес по номеру (аналог /findibiz)", -1)
            return
        end
        local num = tonumber(args)
        if not num then
            sampAddChatMessage("[rhl] /fb <номер> — номер должен быть числом", -1)
            return
        end
        sampSendChat("/findibiz " .. num)
    end)

    sampRegisterChatCommand("mapset", function()
        if fastMapEnabled[0]~=true then
            sampAddChatMessage("[rhl] включи FastMap в разделе Ловля", -1); return
        end
        fmEditMode[0] = not (fmEditMode[0]==true)
        if fmEditMode[0] then
            fastMapOpen[0] = true
            sampAddChatMessage("[rhl] перемести карту пальцем и снова введи /mapset", -1)
        else
            cfg_save()
            sampAddChatMessage(string.format("[rhl] позиция сохранена: X=%.0f Y=%.0f", fmPosX[0], fmPosY[0]), -1)
        end
    end)
    sampRegisterChatCommand("fixbut", function()
        hotButtonsLocked[0] = not (hotButtonsLocked[0]==true)
        if hotButtonsLocked[0] then
            ini.cfg.mapBtnPosX=mapBtnPos.x;   ini.cfg.mapBtnPosY=mapBtnPos.y
            ini.cfg.styleBtnPosX=styleBtnPos.x; ini.cfg.styleBtnPosY=styleBtnPos.y
            ini.cfg.nBtnPosX=nBtnPos.x; ini.cfg.nBtnPosY=nBtnPos.y
        end
        cfg_save()
        sampAddChatMessage(hotButtonsLocked[0] and "[rhl] кнопки зафиксированы" or "[rhl] кнопки разморожены", -1)
    end)
    sampRegisterChatCommand("fixwatch", function()
        clockLocked[0] = not (clockLocked[0]==true)
        clock_save(); cfg_save()
        sampAddChatMessage(clockLocked[0] and "[rhl] часы зафиксированы" or "[rhl] часы разморожены", -1)
    end)
    sampRegisterChatCommand("pctest", function()
        pluschatActive   = true
        pluschatShowTime = os.clock()
        sampAddChatMessage("[rhl] pluschat: ручной триггер (тест)", -1)
    end)
    sampRegisterChatCommand("ex", function()
        if not realtorEnabled[0] then
            sampAddChatMessage("[rhl] Включи «Сохранение выхода» в разделе Скип", -1); return
        end
        realtorArmed = true
        sampAddChatMessage("[rhl] /ex: готово. Открой диалог входа в агентство.", -1)
    end)
    sampRegisterChatCommand("fontreload", function()
        sampAddChatMessage("[rhl] перезагрузка ресурсов...", -1)
        imguiFonts = {}
        fontReport = {}
        local fontsLoaded = loadImguiFontsFromMemory()
        local logosLoaded = loadLogoTextures()
        reportResources(fontsLoaded, logosLoaded)
    end)

    sampRegisterChatCommand("reload", function()
        sampAddChatMessage("[rhl] принудительная перезагрузка скрипта...", -1)
        lua_thread.create(function()
            wait(300)
            thisScript():reload()
        end)
    end)

    lua_thread.create(function()
        -- ждём пока OnInitialize посчитает pendingDownloads
        wait(500)
        if pendingDownloads > 0 and not reloadingScheduled then
            reloadingScheduled = true
            sampAddChatMessage("[rhl] загрузка ресурсов...", -1)
            local start = os.clock()
            while pendingDownloads > 0 and (os.clock() - start) < 60 do
                wait(200)
            end
            if downloadedOK > 0 then
                sampAddChatMessage("[rhl] ресурсы загружены, перезапуск скрипта...", -1)
                wait(500)
                thisScript():reload()
            else
                sampAddChatMessage("[rhl] не удалось загрузить ресурсы", -1)
            end
        end
    end)

    while true do
        wait(0)
        if captchaTimerEnabled[0]==true and captchaActive
            and (captchaDialogId==DIALOG_CAPTCHA_1 or captchaDialogId==DIALOG_CAPTCHA_2) then
            local t0 = socket.gettime()
            while captchaActive do wait(0) end
            local ts  = string.format("%.2f", socket.gettime() - t0)
            local msg = captcha_format(ffi.string(captchaMsgBuf), captchaInput, ts)
            local msg_cp = utf8_to_cp1251(msg)
            sampAddChatMessage("{fffafa}"..msg_cp, -1)
            sampSendChat(msg_cp)
        end
        pluschatRender()
    end
end

function sampev.onServerMessage(color, text)
    if pluschatEnabled[0] and pluschatMatch(text) then
        pluschatActive = true
        pluschatShowTime = os.clock()
    end
end

function sampev.onShowDialog(dialogId,style,title,button1,button2,text)
    if dialogId == DIALOG_REALTOR and realtorEnabled[0] and realtorArmed then
        realtorArmed = false
        lua_thread.create(function()
            wait(200)
            if sampIsDialogActive() then
                pcall(sampSetDialogListIndex, 0)
                wait(120)
            end
            if sampIsDialogActive() then
                sampSendDialogResponse(DIALOG_REALTOR, 1, 0, "")
            end
        end)
        sampAddChatMessage("[rhl] /ex: автовыбор выполнен, жди телепорт и закрой диалог.", -1)
    end
    if styleDialogInfo.state then
        styleDialogInfo.id=dialogId; styleDialogInfo.dialoged=true; return false
    end
    captchaActive=true; captchaDialogId=dialogId
    if dialogId==DIALOG_SKIP and skipEnabled[0]==true then
        lua_thread.create(function() sampSendDialogResponse(dialogId,1,0,"") end); return false
    end
    if pickupSkipEnabled[0]==true and dialogId==DIALOG_PICKUP_CONFIRM then
        lua_thread.create(function() sampSendDialogResponse(dialogId,1,0,"") end); return false
    end
    return true
end

function sampev.onSendDialogResponse(dialogId,button,listboxId,input)
    captchaActive=false; captchaInput=input
    if dialogId==DIALOG_CAPTCHA_1 or dialogId==DIALOG_CAPTCHA_2 then
        captchaTotalCount=captchaTotalCount+1; captcha_save()
    end
end

function onScriptTerminate(s) if s==thisScript() then removeMarker() end end