script_name("Parovozov MultiTools")
script_author("Parovoz")
script_version("1.1")

-- =========================================================
-- Parovozov MultiTools: единый центр управления
-- Модули: оптимизация, время и погода, анимации, экран/HUD,
-- заметки, профили, автовход и автореконнект, тема, кнопки-команды,
-- фильтр чата, метки со стрелкой, таймер маски, обмен настройками.
-- Меню: /hub либо кнопка HUB на экране.
-- Файл в UTF-8.
-- =========================================================

local imgui    = require 'mimgui'
local encoding = require 'encoding'
local sampev   = require 'samp.events'
local cjson    = require 'cjson'
local ffi      = require 'ffi'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Контейнер модулей 1.2. Всё новое лежит в его полях: у Lua ограничено число локальных
-- переменных на файл (200), а у LuaJIT ещё и число замыканий на функцию (60).
local X = {
    chatSinks = {}, dialogSinks = {},      -- подписчики на строки чата и диалоги сервера
    pk = {mem = {}, n = 0, queue = nil, restored = 0, failed = 0, last = false},
    pos = {t = -1},                        -- кэш позиции игрока
    perf = {loop = 0, clean = 0, frame = 0, snap = {loop = 0, clean = 0, frame = 0}, at = 0},
    ui = {},
    initHooks = {},                        -- что выполнить при инициализации mimgui (шрифты, стиль)
    tickers = {}, stoppers = {},           -- периодические задачи встроенных модулей и их остановка
}

-- imgui принимает строки как есть (UTF-8), в чат отдаём через перекодировку
local function chat(text)
    sampAddChatMessage(u8:decode("{8A2BE2}[MultiTools] {FFFFFF}" .. text), -1)
    -- если родной чат скрыт своим окном чата, служебная строка должна появиться и там
    if X.noticeSink then
        local line = "{FFFFFF}[MultiTools] " .. text
        local tag = text:match("^({%x%x%x%x%x%x})")
        if tag then line = tag .. "[MultiTools] " .. text:sub(#tag + 1) end
        pcall(X.noticeSink, line)
    end
end
X.say = chat

-- =========================================================
-- ОБЩИЕ ПОМОЩНИКИ (текст и числа)
-- =========================================================

-- строчные русские буквы для сравнения слов без учёта регистра
local function lowerRu(s)
    s = s:lower()
    return (s:gsub("[\208\209][\128-\191]", function(ch)
        local cp = (ch:byte(1) - 192) * 64 + (ch:byte(2) - 128)
        if cp >= 0x410 and cp <= 0x42F then
            cp = cp + 32
        elseif cp == 0x401 then
            cp = 0x451
        else
            return nil
        end
        return string.char(192 + math.floor(cp / 64), 128 + cp % 64)
    end))
end

local function wordsList(s, max)
    max = max or 20
    local out = {}
    for w in tostring(s or ""):gmatch("[^,;\r\n]+") do
        w = lowerRu(w:match("^%s*(.-)%s*$"))
        if w ~= "" and #out < max then out[#out + 1] = w end
    end
    return out
end

local function hasAny(hay, list)
    for _, w in ipairs(list) do
        if hay:find(w, 1, true) then return true end
    end
    return false
end

-- обрезка по границе символа UTF-8, чтобы не получить битую букву
local function cutUtf8(s, maxBytes)
    if #s <= maxBytes then return s end
    local cut = maxBytes
    while cut > 0 do
        local b = s:byte(cut + 1)
        if b and b >= 128 and b < 192 then cut = cut - 1 else break end
    end
    return s:sub(1, cut)
end

local function toUtf(s)
    local ok, r = pcall(function() return u8(s or "") end)
    if ok and type(r) == 'string' then return r end
    return tostring(s or "")
end

local function finite(v)
    return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

-- число в пределах [a, b]; не число и NaN дают значение по умолчанию d
local function num(v, a, b, d)
    v = tonumber(v)
    if not finite(v) then v = d end
    if v < a then return a end
    if v > b then return b end
    return v
end

-- целое в пределах [a, b]
local function ci(v, a, b, d)
    return math.floor(num(v, a, b, d))
end

-- одна строка без управляющих символов и пробелов по краям, не длиннее maxBytes
local function cleanStr(s, maxBytes)
    if type(s) ~= 'string' then return "" end
    s = s:gsub("%c", "")
    s = s:match("^%s*(.-)%s*$")
    return cutUtf8(s, maxBytes)
end

-- math.atan2 есть в LuaJIT, а в новых Lua его заменяет math.atan с двумя аргументами
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- окна mimgui, у которых замеряется время работы Lua-кода (для счётчика нагрузки)
-- перечитать поля ввода модулей 1.2 из настроек (после импорта); модули дописывают сюда себя
X.refreshers = {}
function X.refresh12()
    for _, f in ipairs(X.refreshers) do pcall(f) end
end

function X.frame(cond, fn)
    return imgui.OnFrame(cond, function(self)
        local t0 = os.clock()
        fn(self)
        X.perf.frame = X.perf.frame + (os.clock() - t0)
    end)
end

-- =========================================================
-- КОНФИГ
-- =========================================================

local configDir  = getWorkingDirectory() .. '/config'
local configPath = configDir .. '/rodina_hub.json'

local function deepcopy(v)
    if type(v) ~= 'table' then return v end
    local r = {}
    for k, x in pairs(v) do r[k] = deepcopy(x) end
    return r
end

local function defaultOpt()
    return {
        players = false, vehicles = false, objects = false,
        distP = 0, distV = 0, distO = 0,
        autoCrowd = false, crowdP = 25, crowdV = 15,
        noPickups = false, noBubbles = false,
        accOthers = false, accMe = false,
        text3d = false, text3dDist = 80,
        whitelist = "",
    }
end

local function defaultSets()
    return {
        {name = "Дефолт",    group = "man",       lib = ""},
        {name = "CJ",        group = "PLAYER",    lib = ""},
        {name = "Берсерк",   group = "berserk",   lib = "berserk"},
        {name = "Фрирен",    group = "friren1",   lib = "friren1"},
        {name = "Друид",     group = "druid",     lib = "druid"},
        {name = "Личь",      group = "lich1",     lib = "lich1"},
        {name = "Викинг",    group = "viking1",   lib = "viking1"},
        {name = "Оборотень", group = "werewolf1", lib = "werewolf1"},
        {name = "Ведьма",    group = "witch1",    lib = "witch1"},
        {name = "Роллер",    group = "skatef",    lib = "skatef"},
    }
end

local function defaultCfg()
    return {
        theme = {0.54, 0.20, 0.85},
        opt = defaultOpt(),
        tw = {timeLock = false, weatherLock = false, hour = 12, minute = 0, weather = 1,
              flow = false, flowSpeed = 1},
        anim = {enabled = false, active = 1, sets = defaultSets()},
        hud = {hideHud = true, hideRadar = true, hideChat = true},
        -- положение новых окон хранится в процентах экрана (xp, yp), чтобы не зависеть от телефона
        ui = {launcher = true, lScale = 100, lAlpha = 100, lxp = 1, lyp = 14,
              -- тема из вкладки «Темы»: включена сама, если раньше стоял отдельный Parovozov Themes
              useTheme = doesFileExist(configDir .. '/parovozov_themes.json'),
              winW = 38, winH = 48},
        overlay = {enabled = false, fps = true, ping = true, clock = true, counts = true, x = 10, y = 300,
                   scale = 100, alpha = 45},
        btn = {on = false, scale = 100, alpha = 40, cols = 1, xp = 1, yp = 30, list = {}},
        chatf = {
            enabled = false, hide = "", protectNick = true,
            hlNick = true, hlWords = "", hlColor = {1.0, 0.85, 0.2},
        },
        marks = {
            list = {}, target = 0,
            on = true, scale = 100, alpha = 45, xp = 40, yp = 12, arrive = 15, autoClear = true,
        },
        mask = {
            minutes = 30, warn = 5, cooldown = 0,
            auto = false, trigger = "", stopTrigger = "",
            show = true, showIdle = false, scale = 100, alpha = 45, xp = 40, yp = 22,
            endAt = 0, coolEnd = 0,
        },
        log = {enabled = true},
        dlg = {enabled = true},
        alert = {
            enabled = false, nick = true, words = "", ignoreOwn = true,
            seconds = 3, thick = 10, banner = true, color = {1.0, 0.3, 0.3},
        },
        timers = {list = {}, show = true, scale = 100, alpha = 45, xp = 40, yp = 32},
        tpl = {list = {
            {name = "Шапка для жалобы", text = "Мой ник: {nick}\nДата и время: {date} {time}\nСуть: "},
            {name = "Ник и ID", text = "{nick} [{id}]"},
        }},
        graph = {enabled = true, lowFps = 45},
        income = {enabled = true},
        view = {
            hudOn = false, hpOn = true, armorOn = true, moneyOn = true, clockOn = true,
            hudScale = 100, hudXp = 2, hudYp = 35,
            speedOn = false, carHpOn = true, speedScale = 100, speedXp = 80, speedYp = 78, speedCalib = 100,
            crossOn = false, crossOnlyArmed = true, crossDot = true,
            crossSize = 8, crossGap = 4, crossThick = 2, crossColor = {1.0, 0.2, 0.2},
            crossXp = 50, crossYp = 50,
            tintOn = false, tintColor = {1.0, 0.6, 0.2}, tintAlpha = 0, brightness = 0, vignette = 0,
        },
        notes = {{title = "Заметка", text = ""}},
        profiles = {},
        login = {
            reconnect = false, rcDelay = 8, rcMax = 5,
            autologin = false, password = "",
            dialogWords = "авториз, парол, login, password",
            skipWords = "придума, повтор, подтверд, новый пароль, смена пароля",
            allowInput = false,
            accounts = {}, active = 0, useActive = true,
        },
    }
end

local function isArray(t) return t[1] ~= nil end

local function merge(dst, def)
    for k, v in pairs(def) do
        if dst[k] == nil then
            dst[k] = deepcopy(v)
        elseif type(v) == 'table' and type(dst[k]) == 'table' and not isArray(v) then
            merge(dst[k], v)
        end
    end
end

local function clamp(v, a, b)
    v = tonumber(v) or a
    if v ~= v then return a end
    if v < a then return a end
    if v > b then return b end
    return math.floor(v)
end

local cfg = {}
local dirty = false

local function markDirty() dirty = true end

local function saveConfig()
    if not doesDirectoryExist(configDir) then createDirectory(configDir) end
    local ok, enc = pcall(cjson.encode, cfg)
    if ok then
        local f = io.open(configPath, 'w')
        if f then
            f:write(enc)
            f:close()
        end
    end
    dirty = false
end

-- ---------- проверка разделов, появившихся в 1.1 ----------

local function fixBools(tbl, spec)
    for k, d in pairs(spec) do
        if type(tbl[k]) ~= 'boolean' then tbl[k] = d end
    end
end

-- spec: ключ -> {мин, макс, по умолчанию}; целые
local function fixInts(tbl, spec)
    for k, r in pairs(spec) do tbl[k] = ci(tbl[k], r[1], r[2], r[3]) end
end

-- spec: ключ -> {мин, макс, по умолчанию}; дробные
local function fixNums(tbl, spec)
    for k, r in pairs(spec) do tbl[k] = num(tbl[k], r[1], r[2], r[3]) end
end

local function fixStrs(tbl, spec)
    for k, maxBytes in pairs(spec) do tbl[k] = cleanStr(tbl[k], maxBytes) end
end

local function fixColor(c, d)
    if type(c) ~= 'table' then return {d[1], d[2], d[3]} end
    return {num(c[1], 0, 1, d[1]), num(c[2], 0, 1, d[2]), num(c[3], 0, 1, d[3])}
end

local function sanitizeButtons(list)
    local out = {}
    if type(list) == 'table' then
        for _, b in ipairs(list) do
            if type(b) == 'table' and #out < 12 then
                local name, cmd = cleanStr(b.name, 24), cleanStr(b.cmd, 100)
                if name ~= "" or cmd ~= "" then out[#out + 1] = {name = name, cmd = cmd} end
            end
        end
    end
    return out
end

local function sanitizeMarks(list)
    local out = {}
    if type(list) == 'table' then
        for _, m in ipairs(list) do
            if type(m) == 'table' and #out < 40 then
                local x, y, z = tonumber(m.x), tonumber(m.y), tonumber(m.z)
                if finite(x) and finite(y) and finite(z) and math.abs(x) < 100000
                    and math.abs(y) < 100000 and math.abs(z) < 100000 then
                    out[#out + 1] = {name = cleanStr(m.name, 40), x = x, y = y, z = z,
                                     int = ci(m.int, 0, 255, 0)}
                end
            end
        end
    end
    return out
end

-- текст в несколько строк: переводы строк оставляем, остальное управляющее убираем
function X.cleanText(s, maxBytes)
    if type(s) ~= 'string' then return "" end
    s = s:gsub("[%c]", function(c) if c == "\n" then return c end return "" end)
    return cutUtf8(s, maxBytes)
end

function X.sanitizeTimers(list)
    local out = {}
    if type(list) == 'table' then
        local now = os.time()
        for _, t in ipairs(list) do
            if type(t) == 'table' and #out < 8 then
                local name = cleanStr(t.name, 24)
                if name == "" then name = "Таймер " .. (#out + 1) end
                -- окончание в прошлом или дальше 12 часов вперёд: таймер не запущен
                local endAt = tonumber(t.endAt)
                if not finite(endAt) or endAt <= now or endAt > now + 721 * 60 then endAt = 0 end
                out[#out + 1] = {name = name, minutes = ci(t.minutes, 1, 720, 15),
                                 warn = ci(t.warn, 0, 60, 1), endAt = endAt}
            end
        end
    end
    return out
end

function X.sanitizeTpl(list)
    local out = {}
    if type(list) == 'table' then
        for _, t in ipairs(list) do
            if type(t) == 'table' and #out < 20 then
                local name = cleanStr(t.name, 24)
                if name == "" then name = "Шаблон " .. (#out + 1) end
                out[#out + 1] = {name = name, text = X.cleanText(t.text, 600)}
            end
        end
    end
    return out
end

function X.sanitizeAccounts(list)
    local out = {}
    if type(list) == 'table' then
        for _, a in ipairs(list) do
            if type(a) == 'table' and #out < 10 then
                local nick = cleanStr(a.nick, 32)
                if nick ~= "" then
                    local pw = type(a.password) == 'string' and a.password:gsub("[\r\n]", ""):sub(1, 63) or ""
                    out[#out + 1] = {nick = nick, password = pw}
                end
            end
        end
    end
    return out
end

function X.sanitize12()
    fixBools(cfg.log, {enabled = true})
    fixBools(cfg.dlg, {enabled = true})
    fixBools(cfg.income, {enabled = true})

    local a = cfg.alert
    fixBools(a, {enabled = false, nick = true, ignoreOwn = true, banner = true})
    fixInts(a, {seconds = {1, 10, 3}, thick = {2, 40, 10}})
    fixStrs(a, {words = 255})
    a.color = fixColor(a.color, {1.0, 0.3, 0.3})

    local t = cfg.timers
    fixBools(t, {show = true})
    fixInts(t, {scale = {50, 300, 100}, alpha = {0, 100, 45}})
    fixNums(t, {xp = {0, 100, 40}, yp = {0, 100, 32}})
    t.list = X.sanitizeTimers(t.list)

    cfg.tpl.list = X.sanitizeTpl(cfg.tpl.list)

    local g = cfg.graph
    fixBools(g, {enabled = true})
    fixInts(g, {lowFps = {10, 200, 45}})

    local lg = cfg.login
    lg.accounts = X.sanitizeAccounts(lg.accounts)
    lg.active = ci(lg.active, 0, #lg.accounts, 0)
    fixBools(lg, {useActive = true})
end

local function sanitize11()
    local u = cfg.ui
    fixBools(u, {launcher = true, useTheme = false})
    fixInts(u, {lScale = {50, 300, 100}, lAlpha = {10, 100, 100}, winW = {30, 100, 38}, winH = {25, 100, 48}})
    fixNums(u, {lxp = {0, 100, 1}, lyp = {0, 100, 14}})

    local o = cfg.overlay
    fixInts(o, {scale = {50, 300, 100}, alpha = {0, 100, 45}})

    local b = cfg.btn
    fixBools(b, {on = false})
    fixInts(b, {scale = {50, 250, 100}, alpha = {0, 100, 40}, cols = {1, 4, 1}})
    fixNums(b, {xp = {0, 100, 1}, yp = {0, 100, 30}})
    b.list = sanitizeButtons(b.list)

    local f = cfg.chatf
    fixBools(f, {enabled = false, protectNick = true, hlNick = true})
    fixStrs(f, {hide = 255, hlWords = 255})
    f.hlColor = fixColor(f.hlColor, {1.0, 0.85, 0.2})

    local m = cfg.marks
    fixBools(m, {on = true, autoClear = true})
    fixInts(m, {scale = {50, 300, 100}, alpha = {0, 100, 45}, arrive = {3, 200, 15}})
    fixNums(m, {xp = {0, 100, 40}, yp = {0, 100, 12}})
    m.list = sanitizeMarks(m.list)
    local tgt = tonumber(m.target)
    if not finite(tgt) or tgt < 1 or tgt > #m.list then tgt = 0 end
    m.target = math.floor(tgt)

    local k = cfg.mask
    fixBools(k, {auto = false, show = true, showIdle = false})
    fixInts(k, {minutes = {1, 180, 30}, warn = {0, 60, 5}, cooldown = {0, 240, 0},
                scale = {50, 300, 100}, alpha = {0, 100, 45}})
    fixNums(k, {xp = {0, 100, 40}, yp = {0, 100, 22}})
    fixStrs(k, {trigger = 100, stopTrigger = 100})
    -- время окончания хранится как метка os.time(); нелепые значения отбрасываем
    local now = os.time()
    local function futureTime(v, maxAheadMin)
        v = tonumber(v)
        if not finite(v) or v <= now or v > now + maxAheadMin * 60 then return 0 end
        return v
    end
    k.endAt = futureTime(k.endAt, 181)
    k.coolEnd = futureTime(k.coolEnd, 180 + 240 + 1)

    -- цвета: каждая составляющая от 0 до 1
    cfg.view.crossColor = fixColor(cfg.view.crossColor, {1.0, 0.2, 0.2})
    cfg.view.tintColor = fixColor(cfg.view.tintColor, {1.0, 0.6, 0.2})
    cfg.theme = fixColor(cfg.theme, {0.54, 0.20, 0.85})
end

-- пределы для настроек FPS и сцены; нужны и конфигу, и профилям из чужого кода
local function fixOpt(o)
    for _, k in ipairs({'distP', 'distV', 'distO'}) do o[k] = clamp(o[k], 0, 500) end
    o.crowdP = clamp(o.crowdP, 1, 200)
    o.crowdV = clamp(o.crowdV, 1, 200)
    o.text3dDist = clamp(o.text3dDist, 0, 100)
    if type(o.whitelist) ~= 'string' then o.whitelist = "" end
end

local function fixTw(t)
    t.hour = clamp(t.hour, 0, 23)
    t.minute = clamp(t.minute, 0, 59)
    t.weather = clamp(t.weather, 0, 45)
    t.flowSpeed = clamp(t.flowSpeed, 1, 120)
end

local function sanitize()
    fixOpt(cfg.opt)
    fixTw(cfg.tw)

    if type(cfg.anim.sets) ~= 'table' or #cfg.anim.sets == 0 then cfg.anim.sets = defaultSets() end
    cfg.anim.active = clamp(cfg.anim.active, 1, #cfg.anim.sets)

    if type(cfg.theme) ~= 'table' or #cfg.theme < 3 then cfg.theme = {0.54, 0.20, 0.85} end

    if type(cfg.notes) ~= 'table' or #cfg.notes == 0 then cfg.notes = {{title = "Заметка", text = ""}} end
    for _, n in ipairs(cfg.notes) do
        if type(n.title) ~= 'string' then n.title = "" end
        if type(n.text) ~= 'string' then n.text = "" end
    end
    if type(cfg.profiles) ~= 'table' then cfg.profiles = {} end

    local def = defaultCfg().login
    if type(cfg.login) ~= 'table' then cfg.login = deepcopy(def) end
    local lg = cfg.login
    for _, k in ipairs({'reconnect', 'autologin', 'allowInput'}) do
        if type(lg[k]) ~= 'boolean' then lg[k] = false end
    end
    lg.rcDelay = clamp(lg.rcDelay, 3, 60)
    lg.rcMax = clamp(lg.rcMax, 1, 30)
    if type(lg.password) ~= 'string' then lg.password = "" end
    lg.password = lg.password:gsub("[\r\n]", ""):sub(1, 63)
    for _, k in ipairs({'dialogWords', 'skipWords'}) do
        if type(lg[k]) ~= 'string' then lg[k] = def[k] end
        lg[k] = lg[k]:sub(1, 255)
    end

    local v = cfg.view
    local ranges = {
        hudScale = {50, 200}, hudXp = {0, 95}, hudYp = {0, 95},
        speedScale = {50, 200}, speedXp = {0, 95}, speedYp = {0, 95}, speedCalib = {50, 200},
        crossSize = {1, 60}, crossGap = {0, 30}, crossThick = {1, 6}, crossXp = {0, 100}, crossYp = {0, 100},
        tintAlpha = {0, 60}, brightness = {-50, 50}, vignette = {0, 80},
    }
    for k, r in pairs(ranges) do v[k] = clamp(v[k], r[1], r[2]) end
    if type(v.crossColor) ~= 'table' or #v.crossColor < 3 then v.crossColor = {1.0, 0.2, 0.2} end
    if type(v.tintColor) ~= 'table' or #v.tintColor < 3 then v.tintColor = {1.0, 0.6, 0.2} end

    sanitize11()
    X.sanitize12()
end

local function loadConfig()
    cfg = {}
    if doesFileExist(configPath) then
        local f = io.open(configPath, 'r')
        if f then
            local content = f:read('*a')
            f:close()
            local ok, res = pcall(cjson.decode, content)
            if ok and type(res) == 'table' then cfg = res end
        end
    end
    merge(cfg, defaultCfg())
    sanitize()
    saveConfig()
end

loadConfig()

-- =========================================================
-- СОСТОЯНИЕ
-- =========================================================

local window = imgui.new.bool(false)
local currentTab = 1
local myId = -1
local hudHidden = false

-- связь со встроенными модулями «Свой чат» и «Темы»
function X.chatHidden() return hudHidden and cfg.hud.hideChat end
function X.themeOn() return cfg.ui.useTheme end
function X.themeTouched()
    if not cfg.ui.useTheme then
        cfg.ui.useTheme = true
        markDirty()
    end
end
-- запущен ли отдельный скрипт с таким именем (MoonLoader: script.find); если API нет, считаем, что нет
function X.standalone(name)
    local ok, found = pcall(function()
        if type(script) ~= 'table' or type(script.find) ~= 'function' then return false end
        return script.find(name) ~= nil
    end)
    return ok and found == true
end
local prevChatMode = nil
local requestClean = false

local live = {p = 0, v = 0, o = 0}
local removed = {players = 0, vehicles = 0, objects = 0}
local crowd = {p = false, v = false}
local optError = ""

-- Статистика сессии: сбрасывается при перезапуске скрипта или кнопкой
local stats = {}
local function resetStats()
    stats = {
        onlineSec = 0, distance = 0, lastPos = nil, active = false,
        peakFps = 0, fpsSum = 0, fpsCount = 0, lastFpsSample = 0,
        peakPing = 0, pingSum = 0, pingCount = 0, lastSample = 0,
    }
end
resetStats()

-- заполняется в модуле автовхода и автореконнекта ниже
local loginOnInit = function() end

local function fmtTime(sec)
    sec = math.floor(sec)
    return string.format("%d:%02d:%02d", math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60)
end

-- =========================================================
-- МОДУЛЬ: ОПТИМИЗАЦИЯ
-- =========================================================

local streamedP, streamedV = {}, {}
local emulating = false

local function countKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function myPos()
    local ok, x, y, z = pcall(getCharCoordinates, PLAYER_PED)
    if ok then return x, y, z end
end

-- позиция игрока с кэшем: при стриме десятков объектов подряд не дёргаем игру каждый раз
function X.myPosCached(maxAge)
    local c, now = X.pos, os.clock()
    if c.t < 0 or now - c.t > maxAge then
        c.x, c.y, c.z = myPos()
        c.t = now
    end
    return c.x, c.y, c.z
end

local function dist3(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function effectiveOn(kind)
    if cfg.opt[kind] then return true end
    if cfg.opt.autoCrowd then
        if kind == 'players' and crowd.p then return true end
        if kind == 'vehicles' and crowd.v then return true end
    end
    return false
end

local distKey = {players = 'distP', vehicles = 'distV', objects = 'distO'}

-- true, если сущность нужно скрыть по радиусу (0 = скрывать всех)
local function beyondRadius(kind, x, y, z)
    local r = cfg.opt[distKey[kind]] or 0
    if r <= 0 then return true end
    local mx, my, mz = X.myPosCached(0.5)
    if not mx then return true end
    return dist3(x, y, z, mx, my, mz) >= r
end

local wlText, wlSet = nil, {}
local function whitelisted(id)
    local s = cfg.opt.whitelist or ""
    if s ~= wlText then
        wlText = s
        wlSet = {}
        for n in s:gmatch("%d+") do wlSet[tonumber(n)] = true end
    end
    return wlSet[id] == true
end

-- RPC "удаления из зоны стрима" в SA-MP
local RPC_REMOVE_PLAYER  = 163
local RPC_REMOVE_VEHICLE = 165
local RPC_DESTROY_OBJECT = 47

local function emulRemove(rpc, id)
    local bs = raknetNewBitStream()
    if not bs then return false end
    emulating = true
    raknetBitStreamWriteInt16(bs, id)
    local ok = pcall(raknetEmulRpcReceiveBitStream, rpc, bs)
    emulating = false
    raknetDeleteBitStream(bs)
    return ok
end

-- Перехват новых сущностей ---------------------------------

function sampev.onInitGame(playerId)
    streamedP, streamedV = {}, {}
    myId = type(playerId) == 'number' and playerId or -1
    X.pk.mem, X.pk.n, X.pk.queue = {}, 0, nil
    if X.incomeReset then X.incomeReset() end
    loginOnInit()
end

function sampev.onPlayerStreamIn(id, team, model, pos)
    streamedP[id] = true
    if effectiveOn('players') and not whitelisted(id) then
        local hide = true
        if pos and pos.x then hide = beyondRadius('players', pos.x, pos.y, pos.z) end
        if hide then return false end
    end
end

function sampev.onPlayerStreamOut(id)
    if not emulating then streamedP[id] = nil end
end

function sampev.onVehicleStreamIn(id, data)
    streamedV[id] = true
    if effectiveOn('vehicles') then
        local hide = true
        local p = data and data.position
        if p and p.x then hide = beyondRadius('vehicles', p.x, p.y, p.z) end
        if hide then return false end
    end
end

function sampev.onVehicleStreamOut(id)
    if not emulating then streamedV[id] = nil end
end

function sampev.onCreateObject(id, data)
    if effectiveOn('objects') then
        local hide = true
        local p = data and data.position
        if p and p.x then hide = beyondRadius('objects', p.x, p.y, p.z) end
        if hide then return false end
    end
end

-- Пикапы, которые мы не дали создать, запоминаем: когда скрытие выключат, вернём их
-- (RPC CreatePickup = 95: id, модель, тип, три координаты).
local RPC_CREATE_PICKUP = 95
local PICKUP_MEMORY = 3000

function sampev.onCreatePickup(id, model, pickupType, position)
    if not cfg.opt.noPickups then return end
    local pk = X.pk
    if position then
        if pk.mem[id] ~= nil then
            pk.mem[id] = {model, pickupType, position.x, position.y, position.z}
        elseif pk.n < PICKUP_MEMORY then
            pk.n = pk.n + 1
            pk.mem[id] = {model, pickupType, position.x, position.y, position.z}
        end
    end
    return false
end

function sampev.onDestroyPickup(id)
    local pk = X.pk
    if pk.mem[id] ~= nil then
        pk.mem[id] = nil
        pk.n = pk.n - 1
    end
end

-- запустить возврат запомненных пикапов (порциями, чтобы не было рывка)
function X.startPickupRestore()
    local ids = {}
    for id in pairs(X.pk.mem) do ids[#ids + 1] = id end
    table.sort(ids)
    X.pk.queue = ids
    X.pk.restored, X.pk.failed = 0, 0
end

local function emulPickup(id, p)
    local bs = raknetNewBitStream()
    if not bs then return false end
    raknetBitStreamWriteInt32(bs, id)
    raknetBitStreamWriteInt32(bs, p[1])
    raknetBitStreamWriteInt32(bs, p[2])
    raknetBitStreamWriteFloat(bs, p[3])
    raknetBitStreamWriteFloat(bs, p[4])
    raknetBitStreamWriteFloat(bs, p[5])
    local ok = pcall(raknetEmulRpcReceiveBitStream, RPC_CREATE_PICKUP, bs)
    raknetDeleteBitStream(bs)
    return ok
end

-- вызывается раз в четверть секунды; до 100 пикапов за раз
function X.pickupTick()
    local pk = X.pk
    local want = cfg.opt.noPickups
    if pk.last and not want then X.startPickupRestore() end
    pk.last = want
    if not pk.queue then return end
    if want then
        pk.queue = nil   -- скрытие включили снова: останавливаемся
        return
    end
    for _ = 1, 100 do
        local id = table.remove(pk.queue)
        if id == nil then
            pk.queue = nil
            return
        end
        local p = pk.mem[id]
        if p then
            if emulPickup(id, p) then pk.restored = pk.restored + 1 else pk.failed = pk.failed + 1 end
            pk.mem[id] = nil
            pk.n = pk.n - 1
        end
    end
end

function sampev.onPlayerChatBubble(playerId, color, distance, duration, message)
    if cfg.opt.noBubbles then return false end
end

function sampev.onCreate3DText(id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, text)
    if not cfg.opt.text3d then return end
    local d = cfg.opt.text3dDist
    if distance and distance > 0 then d = math.min(d, distance) end
    return {id, color, position, d, testLOS, attachedPlayerId, attachedVehicleId, text}
end

function sampev.onSetPlayerAttachedObject(playerId, index, create, object)
    if not create or myId < 0 then return end
    if playerId == myId then
        if cfg.opt.accMe then return false end
    elseif cfg.opt.accOthers then
        return false
    end
end

-- Удаление уже загруженных ---------------------------------

local function removePlayers(peds)
    local n = 0
    for _, ped in ipairs(peds or getAllChars()) do
        if ped ~= PLAYER_PED then
            local ok, id = sampGetPlayerIdByCharHandle(ped)
            if ok and not sampIsPlayerNpc(id) and not whitelisted(id) then
                local x, y, z = getCharCoordinates(ped)
                if beyondRadius('players', x, y, z) and emulRemove(RPC_REMOVE_PLAYER, id) then
                    n = n + 1
                end
            end
        end
    end
    return n
end

local function removeVehicles(cars)
    local n = 0
    local myCar
    if isCharInAnyCar(PLAYER_PED) then myCar = storeCarCharIsInNoSave(PLAYER_PED) end
    for _, car in ipairs(cars or getAllVehicles()) do
        if car ~= myCar then
            local ok, id = sampGetVehicleIdByCarHandle(car)
            if ok then
                local x, y, z = getCarCoordinates(car)
                if beyondRadius('vehicles', x, y, z) and emulRemove(RPC_REMOVE_VEHICLE, id) then
                    n = n + 1
                end
            end
        end
    end
    return n
end

local function objectSampId(obj)
    local a, b = sampGetObjectSampIdByHandle(obj)
    if type(a) == 'boolean' then
        if a then return b end
        return nil
    end
    if type(a) == 'number' and a >= 0 then return a end
    return nil
end

local function removeObjects(objs)
    local n = 0
    for _, obj in ipairs(objs or getAllObjects()) do
        local x, y, z = getObjectCoordinates(obj)
        if beyondRadius('objects', x, y, z) then
            local id = objectSampId(obj)
            if id then
                if emulRemove(RPC_DESTROY_OBJECT, id) then n = n + 1 end
            else
                pcall(setObjectVisible, obj, false)
            end
        end
    end
    return n
end

local function updateCrowd()
    local nP = math.max(countKeys(streamedP), live.p)
    local nV = math.max(countKeys(streamedV), live.v)
    local tp, tv = cfg.opt.crowdP, cfg.opt.crowdV
    crowd.p = (nP >= tp) or (crowd.p and nP >= tp - 3) or false
    crowd.v = (nV >= tv) or (crowd.v and nV >= tv - 3) or false
end

local function guarded(name, fn, key)
    local ok, res = pcall(fn)
    if ok then
        removed[key] = removed[key] + (res or 0)
    else
        optError = name .. ": " .. tostring(res)
    end
    return ok
end

-- что нужно считать: getAll* дорогие (особенно getAllObjects), без нужды их не зовём
local function wantCounts()
    local o = cfg.overlay
    return cfg.opt.autoCrowd or (o.enabled and o.counts)
end

-- Уже загруженное сканируем, когда это нужно: по запросу, пока скрытие идёт по радиусу
-- (сущности выходят за радиус) и один раз после включения (дальше новое ловят хуки стрима).
X.scanned = {players = false, vehicles = false, objects = false}

local function needScan(kind, on, force)
    if not on then
        X.scanned[kind] = false
        return false
    end
    return force or (cfg.opt[distKey[kind]] or 0) > 0 or not X.scanned[kind]
end

-- если включили или выключили скрытие (в меню, пресетом, командой или толпой), чистим сразу
X.watch = {false, false, false}
function X.optWatch()
    local w = X.watch
    local a, b, c = effectiveOn('players'), effectiveOn('vehicles'), effectiveOn('objects')
    if a ~= w[1] or b ~= w[2] or c ~= w[3] then
        w[1], w[2], w[3] = a, b, c
        requestClean = true
    end
end

-- как часто звать cleanTick
function X.cleanInterval()
    for _, kind in ipairs({'players', 'vehicles', 'objects'}) do
        if effectiveOn(kind) and (cfg.opt[distKey[kind]] or 0) > 0 then return 1.5 end
    end
    if wantCounts() or window[0] then return 2 end
    return 5
end

local function cleanTick(force)
    local t0 = os.clock()
    X.pos.t = -1
    local ok, res, id = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
    if ok and res and type(id) == 'number' then myId = id end

    local onP, onV, onO = effectiveOn('players'), effectiveOn('vehicles'), effectiveOn('objects')
    local scanP, scanV = needScan('players', onP, force), needScan('vehicles', onV, force)
    local scanO = needScan('objects', onO, force)
    local counts = wantCounts() or window[0]

    local peds, cars, objs
    pcall(function()
        if counts or scanP then
            peds = getAllChars()
            live.p = math.max(0, #peds - 1)
        end
        if counts or scanV then
            cars = getAllVehicles()
            live.v = #cars
        end
        -- объекты считаем, только если открыта вкладка FPS (там их число видно) или идёт скрытие
        if scanO or (window[0] and currentTab == 1) then
            objs = getAllObjects()
            live.o = #objs
        end
    end)

    updateCrowd()

    if scanP and peds and guarded("игроки", function() return removePlayers(peds) end, 'players') then
        X.scanned.players = true
    end
    if scanV and cars and guarded("транспорт", function() return removeVehicles(cars) end, 'vehicles') then
        X.scanned.vehicles = true
    end
    if scanO and objs and guarded("объекты", function() return removeObjects(objs) end, 'objects') then
        X.scanned.objects = true
    end
    X.perf.clean = X.perf.clean + (os.clock() - t0)
end

-- =========================================================
-- МОДУЛЬ: ВРЕМЯ И ПОГОДА
-- =========================================================

function sampev.onSetWeather(id)
    if cfg.tw.weatherLock then return false end
end

function sampev.onSetPlayerTime(hour, minute)
    if cfg.tw.timeLock then return false end
end

function sampev.onSetWorldTime(hour)
    if cfg.tw.timeLock then return false end
end

-- =========================================================
-- МОДУЛЬ: АНИМАЦИИ
-- =========================================================

local function applyAnim()
    lua_thread.create(function()
        local a = cfg.anim
        if a.enabled then
            local set = a.sets[a.active]
            if set then
                if set.lib and set.lib ~= "" then
                    requestAnimation(set.lib)
                    local tries = 0
                    while not hasAnimationLoaded(set.lib) and tries < 500 do
                        wait(10)
                        tries = tries + 1
                    end
                end
                if set.group and set.group ~= "" then
                    setAnimGroupForChar(PLAYER_PED, set.group)
                end
            end
        else
            setAnimGroupForChar(PLAYER_PED, "man")
        end
        clearCharTasksImmediately(PLAYER_PED)
    end)
end

-- =========================================================
-- МОДУЛЬ: ЭКРАН (скрытие интерфейса)
-- =========================================================

local function applyHud()
    pcall(displayHud, not (hudHidden and cfg.hud.hideHud))
    pcall(displayRadar, not (hudHidden and cfg.hud.hideRadar))

    if hudHidden and cfg.hud.hideChat then
        if prevChatMode == nil then
            local ok, mode = pcall(sampGetChatDisplayMode)
            prevChatMode = (ok and mode) or 2
        end
        pcall(sampSetChatDisplayMode, 0)
    elseif prevChatMode ~= nil then
        pcall(sampSetChatDisplayMode, prevChatMode)
        prevChatMode = nil
    end
end

local function setHudHidden(state)
    hudHidden = state
    applyHud()
end

-- =========================================================
-- ПРОФИЛИ
-- =========================================================

local PRESETS = {
    {name = "Макс. FPS", opt = {
        players = true, vehicles = true, objects = true,
        noPickups = true, noBubbles = true, text3d = true, text3dDist = 30}},
    {name = "Баланс", opt = {
        players = true, distP = 50, vehicles = true, distV = 80,
        autoCrowd = true, crowdP = 25, crowdV = 15,
        noBubbles = true, text3d = true, text3dDist = 60}},
    {name = "Как обычно", opt = {}},
}

-- Сцены: только время и погода (настройки FPS не трогают)
local SCENES = {
    {name = "Вечерний туман", tw = {timeLock = true, hour = 19, minute = 30, weatherLock = true, weather = 9, flow = false}},
    {name = "Ясный день", tw = {timeLock = true, hour = 12, minute = 0, weatherLock = true, weather = 1, flow = false}},
    {name = "Закат", tw = {timeLock = true, hour = 20, minute = 0, weatherLock = true, weather = 4, flow = false}},
    {name = "Ночной дождь", tw = {timeLock = true, hour = 1, minute = 0, weatherLock = true, weather = 8, flow = false}},
    {name = "Смена дня и ночи", tw = {timeLock = true, hour = 8, minute = 0, weatherLock = true, weather = 1, flow = true, flowSpeed = 10}},
    {name = "Серверные время и погода", tw = {timeLock = false, weatherLock = false, flow = false}},
}

local wlBuf = imgui.new.char[128]()
local profNameBuf = imgui.new.char[48]()

local function setBuf(buf, str)
    ffi.fill(buf, ffi.sizeof(buf))
    ffi.copy(buf, str:sub(1, ffi.sizeof(buf) - 1))
end

local function refreshBuffers()
    setBuf(wlBuf, cfg.opt.whitelist or "")
end
refreshBuffers()

-- =========================================================
-- МОДУЛЬ: АВТОВХОД И АВТОРЕКОННЕКТ
-- =========================================================

local pwBuf   = imgui.new.char[64]()
local dlgBuf  = imgui.new.char[256]()
local skipBuf = imgui.new.char[256]()
local showPw  = imgui.new.bool(false)

local function refreshLoginBuffers()
    setBuf(pwBuf, cfg.login.password)
    setBuf(dlgBuf, cfg.login.dialogWords)
    setBuf(skipBuf, cfg.login.skipWords)
end
refreshLoginBuffers()

-- ---------- автореконнект ----------

local auth = {sent = 0, lastId = nil, lastTitle = nil, status = "ждёт окно входа", lastDialog = nil}

local net = {
    ip = nil, port = nil,
    state = nil, okState = nil,   -- состояние соединения: запоминаем, пока игрок в игре
    seenInGame = false,
    badSince = nil, lossEvent = false,
    banned = false, userQuit = false,
    attempts = 0, nextTry = 0,
    status = "ждёт входа в игру",
}

local function readAddress()
    if type(sampGetCurrentServerAddress) ~= 'function' then return nil end
    local ok, ip, port = pcall(sampGetCurrentServerAddress)
    port = tonumber(port)
    if ok and type(ip) == 'string' and ip ~= "" and port and port > 0 then return ip, port end
end

local function readState()
    if type(sampGetGamestate) ~= 'function' then return nil end
    local ok, s = pcall(sampGetGamestate)
    if ok and type(s) == 'number' then return s end
end

local function startReconnect()
    if not net.ip then
        net.status = "адрес сервера ещё не запомнен"
        return false
    end
    if type(sampConnectToServer) ~= 'function' then
        net.status = "функция sampConnectToServer недоступна"
        return false
    end
    local ip, port = net.ip, net.port
    lua_thread.create(function()
        if type(sampDisconnectWithReason) == 'function' then pcall(sampDisconnectWithReason, false) end
        wait(700)
        local ok, err = pcall(sampConnectToServer, ip, port)
        if not ok then net.status = "ошибка подключения: " .. tostring(err) end
    end)
    return true
end

-- проверка соединения (дважды в секунду)
local function netTick(now, spawned)
    local L = cfg.login
    local ip, port = readAddress()
    local state = readState()
    net.state = state

    if spawned then
        if ip then net.ip, net.port = ip, port end
        if state then net.okState = state end
        net.seenInGame = true
        net.badSince, net.lossEvent = nil, false
        net.attempts, net.userQuit = 0, false
        auth.sent, auth.lastId, auth.lastTitle = 0, nil, nil   -- вход удался: счётчик попыток сбрасываем
        net.status = L.reconnect and "соединение есть, слежу" or "выключен"
        return
    end

    if not net.seenInGame then
        if ip then net.ip, net.port = ip, port end
        net.status = "ждёт входа в игру"
        return
    end

    -- игрок уже был в игре, сейчас не заспавнен: соединение жив?
    local lost
    if state and net.okState then
        lost = state ~= net.okState
    else
        lost = net.lossEvent
    end

    if not lost then
        net.badSince = nil
        if ip then net.ip, net.port = ip, port end
        if type(sampGetGamestate) == 'function' then
            net.status = L.reconnect and "соединение есть, слежу" or "выключен"
        else
            net.status = "нет sampGetGamestate: разрыв определяется только по событиям"
        end
        return
    end

    if not net.badSince then net.badSince = now end
    if not L.reconnect then
        net.status = "соединение потеряно (автореконнект выключен)"
        return
    end
    if net.userQuit then
        net.status = "вы вышли сами, реконнект пропущен"
        return
    end
    if net.banned then
        net.status = "получен бан: реконнект остановлен"
        return
    end
    if net.attempts >= L.rcMax then
        net.status = "лимит попыток исчерпан (" .. L.rcMax .. ")"
        return
    end

    local left = math.max(net.badSince + L.rcDelay - now, net.nextTry - now, 0)
    if left > 0 then
        net.status = string.format("соединение потеряно, попытка через %d с", math.ceil(left))
        return
    end

    net.attempts = net.attempts + 1
    net.nextTry = now + math.min(60, L.rcDelay * (1 + net.attempts * 0.5))
    net.status = string.format("попытка %d из %d", net.attempts, L.rcMax)
    if startReconnect() then
        chat(string.format("Соединение потеряно, переподключаюсь (попытка %d из %d)", net.attempts, L.rcMax))
    else
        chat("Не удалось переподключиться: " .. net.status)
    end
end

-- события разрыва (если такие есть в версии samp.events; лишние имена безвредны)
for _, name in ipairs({"onConnectionLost", "onConnectionClosed", "onConnectionRejected", "onConnectionAttemptFailed"}) do
    sampev[name] = function()
        if net.seenInGame then net.lossEvent = true end
    end
end

function sampev.onConnectionBanned()
    net.banned = true
end

function sampev.onSendCommand(cmd)
    local c = tostring(cmd or ""):lower():match("^%s*(/%S+)")
    if c == "/q" or c == "/quit" then net.userQuit = true end
end

-- ---------- автовход ----------

-- подходит ли диалог под окно входа: (да/нет, причина)
local function loginDialogMatches(style, title, text)
    local L = cfg.login
    if style ~= 3 and not (style == 1 and L.allowInput) then
        return false, "стиль " .. tostring(style) .. " не подходит"
    end
    local plain = text:gsub("{%x%x%x%x%x%x}", "")
    local hay = lowerRu(title .. "\n" .. plain)
    if not hasAny(hay, wordsList(L.dialogWords)) then return false, "нет ключевых слов" end
    if hasAny(hay, wordsList(L.skipWords)) then return false, "сработало слово-исключение" end
    return true
end

-- ник игрока в UTF-8 или nil, если скрипт его пока не знает
function X.currentNick()
    if myId < 0 then return nil end
    local ok, n = pcall(sampGetPlayerNickname, myId)
    if ok and type(n) == 'string' and n ~= "" then return toUtf(n) end
    return nil
end

-- Какой пароль вводить: сначала аккаунт с совпавшим ником. Если ник известен, но в списке его
-- нет, остаётся только общий пароль: чужой пароль к этому нику не подойдёт. Если ник неизвестен,
-- берётся выбранный по умолчанию аккаунт, затем общий пароль.
function X.pickPassword()
    local L = cfg.login
    local nick = X.currentNick()
    if nick then
        local ln = lowerRu(nick)
        for _, a in ipairs(L.accounts) do
            if a.password ~= "" and lowerRu(a.nick) == ln then return a.password, a.nick end
        end
    elseif L.useActive then
        local a = L.accounts[L.active]
        if a and a.password ~= "" then return a.password, a.nick end
    end
    if L.password ~= "" then return L.password, nil end
    return nil
end

function sampev.onShowDialog(id, style, title, b1, b2, text)
    local t = toUtf(title)
    auth.lastDialog = {id = id, style = style, title = cutUtf8(t, 80)}

    if #X.dialogSinks > 0 then
        local body = toUtf(text)
        for _, f in ipairs(X.dialogSinks) do pcall(f, id, style, t, body) end
    end

    local L = cfg.login
    if not L.autologin or (L.password == "" and #L.accounts == 0) then return end

    local okSp, sp = pcall(sampIsLocalPlayerSpawned)
    if okSp and sp then
        auth.status = "диалог после входа в игру пропущен"
        return
    end
    if type(sampSendDialogResponse) ~= 'function' then
        auth.status = "функция sampSendDialogResponse недоступна"
        return
    end

    local match, why = loginDialogMatches(style, t, toUtf(text))
    if not match then
        auth.status = "диалог пропущен: " .. why
        return
    end

    local pw, who = X.pickPassword()
    if not pw then
        auth.status = "нет пароля для этого ника: введите вручную"
        return
    end

    if auth.sent >= 2 then
        auth.status = "лимит попыток (2): введите пароль вручную"
        return
    end
    if auth.sent >= 1 and (auth.lastId ~= id or auth.lastTitle ~= t) then
        auth.status = "другой диалог после входа: пропущен"
        return
    end

    auth.sent = auth.sent + 1
    auth.lastId, auth.lastTitle = id, t
    auth.status = string.format("отправляю пароль (попытка %d)", auth.sent)
    local attempt = auth.sent

    lua_thread.create(function()
        wait(700)
        local ok, err = pcall(sampSendDialogResponse, id, 1, 0, u8:decode(pw))
        if ok then
            auth.status = string.format("пароль отправлен (попытка %d%s)", attempt,
                who and (", аккаунт " .. who) or "")
        else
            -- не вышло: возвращаем окно, чтобы можно было ввести пароль руками
            auth.status = "не удалось отправить пароль: " .. tostring(err)
            if type(sampShowDialog) == 'function' then pcall(sampShowDialog, id, title, text, b1, b2, style) end
        end
    end)
    return false
end

loginOnInit = function()
    net.badSince, net.lossEvent, net.banned = nil, false, false
    net.attempts = 0
end

local function applyOptProfile(p)
    local d = defaultOpt()
    for k, v in pairs(d) do
        local nv = p[k]
        if nv == nil then nv = v end
        cfg.opt[k] = nv
    end
    sanitize()
    refreshBuffers()
    requestClean = true
    markDirty()
end

local function applyScene(s)
    local d = {
        timeLock = false, weatherLock = false,
        hour = cfg.tw.hour, minute = cfg.tw.minute, weather = cfg.tw.weather,
        flow = false, flowSpeed = cfg.tw.flowSpeed,
    }
    for k, def in pairs(d) do
        local v = s[k]
        if v == nil then v = def end
        cfg.tw[k] = v
    end
    if not cfg.tw.weatherLock then pcall(releaseWeather) end
    sanitize()
    markDirty()
end

-- Профиль может содержать настройки FPS (opt), сцену (tw) или и то и другое
local function applyProfile(p)
    if type(p.opt) == 'table' then applyOptProfile(p.opt) end
    if type(p.tw) == 'table' then applyScene(p.tw) end
    chat("Профиль применён: " .. tostring(p.name))
end

-- =========================================================
-- ЗАМЕТКИ
-- =========================================================

local noteSel = 1
local noteTitleBuf = imgui.new.char[96]()
local noteTextBuf = imgui.new.char[4096]()

local function loadNoteToBuf()
    local n = cfg.notes[noteSel]
    setBuf(noteTitleBuf, n and n.title or "")
    setBuf(noteTextBuf, n and n.text or "")
end
loadNoteToBuf()

-- =========================================================
-- МОДУЛИ 1.1: ТАЙМЕР МАСКИ, ФИЛЬТР ЧАТА, МЕТКИ, КНОПКИ-КОМАНДЫ
-- =========================================================

-- окна, которые нужно принудительно переставить на сохранённое место (см. winPos)
local movePending = {}

-- буферы полей ввода этих вкладок и выбранные строки
local ui11 = {
    btnName = imgui.new.char[26](), btnCmd = imgui.new.char[102](),
    hide = imgui.new.char[256](), hl = imgui.new.char[256](),
    trig = imgui.new.char[102](), trig2 = imgui.new.char[102](),
    markName = imgui.new.char[42](),
    exportBuf = imgui.new.char[16384](), importBuf = imgui.new.char[16384](),
    btnSel = 1, markSel = 0,
}

local function fmtClock(sec)
    sec = math.max(0, math.floor(sec))
    if sec >= 3600 then
        return string.format("%d:%02d:%02d", math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60)
    end
    return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

local function fmtDist(d)
    if d >= 1000 then return string.format("%.1f км", d / 1000) end
    return string.format("%d м", math.floor(d + 0.5))
end

-- ---------- таймер маски ----------
-- Скрипт не знает, сколько действует маска на сервере: время задаёт сам игрок.

local mask = {warned = false, wasActive = false, flashUntil = 0, total = 0}

-- фаза таймера: 'active' (маска идёт), 'cooldown' (пауза после неё) или 'idle'
function mask.phase(now)
    local M = cfg.mask
    if M.endAt > now then return 'active', M.endAt - now end
    if M.coolEnd > now then return 'cooldown', M.coolEnd - now end
    return 'idle', 0
end

function mask.start(minutes)
    local M = cfg.mask
    minutes = ci(minutes, 1, 180, M.minutes)
    local now = os.time()
    M.endAt = now + minutes * 60
    M.coolEnd = M.cooldown > 0 and (M.endAt + M.cooldown * 60) or 0
    mask.total = minutes * 60
    mask.warned = M.warn * 60 >= mask.total
    mask.wasActive = true
    mask.flashUntil = 0
    markDirty()
    chat(string.format("Маска: таймер запущен на %d мин", minutes))
end

function mask.stop(why)
    local M = cfg.mask
    local now = os.time()
    local was = M.endAt > now or M.coolEnd > now
    M.endAt, M.coolEnd = 0, 0
    mask.wasActive, mask.flashUntil, mask.total = false, 0, 0
    markDirty()
    if was then chat("Маска: таймер сброшен" .. (why and (" (" .. why .. ")") or "")) end
    return was
end

function mask.tick()
    local M = cfg.mask
    local phase, left = mask.phase(os.time())
    if phase == 'active' then
        mask.wasActive = true
        if mask.total <= 0 then mask.total = M.minutes * 60 end -- скрипт перезапустили посреди таймера
        if not mask.warned and M.warn > 0 and left <= M.warn * 60 then
            mask.warned = true
            chat(string.format("{FFAA00}Маска: осталось около %d мин", math.max(1, math.ceil(left / 60))))
        end
    elseif mask.wasActive then
        mask.wasActive = false
        mask.flashUntil = os.clock() + 12
        chat("{FF4444}Маска: время вышло")
    end
end

-- ---------- фильтр чата ----------

local chatf = {
    recent = {}, hidden = {}, hiddenN = 0, hlN = 0, err = "",
    nickId = nil, nick = {},
    srcW = {}, lists = {}, srcL = {}, lows = {},
}

-- списки слов пересобираем, только когда поменялся исходный текст
local function cachedWords(key, s)
    if chatf.srcW[key] ~= s then
        chatf.srcW[key] = s
        chatf.lists[key] = wordsList(s, 30)
    end
    return chatf.lists[key]
end

local function cachedLow(key, s)
    if chatf.srcL[key] ~= s then
        chatf.srcL[key] = s
        chatf.lows[key] = lowerRu(cleanStr(s, 100))
    end
    return chatf.lows[key]
end

-- ник игрока в двух видах: Name_Surname и «Name Surname», как его пишет чат
local function nickPatterns()
    if chatf.nickId ~= myId then
        chatf.nickId = myId
        chatf.nick = {}
        if myId >= 0 then
            local ok, n = pcall(sampGetPlayerNickname, myId)
            if ok and type(n) == 'string' and n ~= "" then
                local low = lowerRu(toUtf(n))
                chatf.nick[1] = low
                local spaced = low:gsub("_", " ")
                if spaced ~= low then chatf.nick[2] = spaced end
            end
        end
    end
    return chatf.nick
end

local function colorTag(c)
    local function b(v) return math.floor(num(v, 0, 1, 1) * 255 + 0.5) end
    return string.format("{%02X%02X%02X}", b(c[1]), b(c[2]), b(c[3]))
end

local function pushLine(list, plain, max)
    table.insert(list, 1, {t = os.date("%H:%M:%S"), text = cutUtf8(plain, 160)})
    while #list > max do table.remove(list) end
end

-- возвращает false (скрыть), либо новый цвет и текст, либо ничего
local function chatHook(color, text)
    if type(text) ~= 'string' then return end
    local plain = (toUtf(text):gsub("{%x%x%x%x%x%x}", ""))
    pushLine(chatf.recent, plain, 12)
    local low = lowerRu(plain)

    -- запуск и сброс таймера маски по фразам из чата
    local M = cfg.mask
    if M.auto then
        local stopT, startT = cachedLow('stop', M.stopTrigger), cachedLow('start', M.trigger)
        if stopT ~= "" and low:find(stopT, 1, true) then
            mask.stop("по фразе из чата")
        elseif startT ~= "" and low:find(startT, 1, true) then
            if mask.phase(os.time()) ~= 'active' then mask.start() end
        end
    end

    local F = cfg.chatf
    local hide, newColor, newText = false, nil, nil
    if F.enabled then
        local mine = (F.protectNick or F.hlNick) and hasAny(low, nickPatterns())
        local hideList = cachedWords('hide', F.hide)
        if #hideList > 0 and hasAny(low, hideList) and not (F.protectNick and mine) then
            chatf.hiddenN = chatf.hiddenN + 1
            pushLine(chatf.hidden, plain, 15)
            hide = true
        elseif (F.hlNick and mine) or hasAny(low, cachedWords('hl', F.hlWords)) then
            chatf.hlN = chatf.hlN + 1
            newColor, newText = color, colorTag(F.hlColor) .. text
        end
    end

    -- журнал чата и уведомления (модули 1.2) смотрят на строку после решения фильтра
    for _, f in ipairs(X.chatSinks) do pcall(f, plain, low, hide) end
    -- своё окно чата получает строку после решения фильтра, с подсветкой
    if not hide and X.rawSink then pcall(X.rawSink, newColor or color, newText or text) end

    if hide then return false end
    if newText then return newColor, newText end
end

function sampev.onServerMessage(color, text)
    local ok, c, t = pcall(chatHook, color, text)
    if not ok then
        chatf.err = tostring(c)
        return
    end
    if c == false then return false end
    if c ~= nil then return {c, t} end
end

-- ---------- метки мест ----------

local marks = {nav = {active = false}, arrivedFor = nil}

local function curInterior()
    if type(getActiveInterior) == 'function' then
        local ok, v = pcall(getActiveInterior)
        if ok and finite(v) then return math.floor(v) end
    end
    return 0
end

-- направление взгляда в градусах по часовой стрелке от севера
local function viewHeading()
    if type(getActiveCameraCoordinates) == 'function' and type(getActiveCameraPointAt) == 'function' then
        local ok1, cx, cy = pcall(getActiveCameraCoordinates)
        local ok2, px, py = pcall(getActiveCameraPointAt)
        if ok1 and ok2 and finite(cx) and finite(cy) and finite(px) and finite(py)
            and (px ~= cx or py ~= cy) then
            return math.deg(atan2(px - cx, py - cy))
        end
    end
    -- запасной вариант: курс персонажа (в игре он растёт против часовой стрелки)
    if type(getCharHeading) == 'function' then
        local ok, h = pcall(getCharHeading, PLAYER_PED)
        if ok and finite(h) then return -h end
    end
    return nil
end

local COMPASS = {"С", "СВ", "В", "ЮВ", "Ю", "ЮЗ", "З", "СЗ"}
local function compassName(bearing)
    return COMPASS[math.floor(((bearing % 360) + 22.5) / 45) % 8 + 1]
end

function marks.add(name)
    local M = cfg.marks
    if #M.list >= 40 then return nil, "лимит 40 меток" end
    local x, y, z = myPos()
    if not finite(x) or not finite(y) or not finite(z) then return nil, "не удалось определить позицию" end
    name = cleanStr(name or "", 40)
    if name == "" then name = "Метка " .. (#M.list + 1) end
    local function r1(v) return math.floor(v * 10 + 0.5) / 10 end
    M.list[#M.list + 1] = {name = name, x = r1(x), y = r1(y), z = r1(z), int = curInterior()}
    markDirty()
    return #M.list
end

function marks.setTarget(i)
    local M = cfg.marks
    i = ci(i, 0, #M.list, 0)
    M.target = i
    marks.arrivedFor = nil
    if i > 0 then M.on = true end
    marks.nav = {active = false}
    markDirty()
end

function marks.remove(i)
    local M = cfg.marks
    if not M.list[i] then return end
    table.remove(M.list, i)
    if M.target == i then
        M.target = 0
        marks.nav = {active = false}
    elseif M.target > i then
        M.target = M.target - 1
    end
    markDirty()
end

-- по номеру или по части названия
function marks.find(arg)
    local M = cfg.marks
    arg = cleanStr(arg or "", 60)
    if arg == "" then return nil end
    local n = tonumber(arg)
    if n and M.list[math.floor(n)] then return math.floor(n) end
    local q = lowerRu(arg)
    for i, m in ipairs(M.list) do
        if lowerRu(m.name):find(q, 1, true) then return i end
    end
    return nil
end

function marks.tick()
    local M = cfg.marks
    local m = M.list[M.target]
    if not m then
        marks.nav = {active = false}
        return
    end
    local nav = {active = true, name = m.name}
    marks.nav = nav
    local x, y, z = myPos()
    if not finite(x) or not finite(y) or not finite(z) then return end
    if m.int ~= curInterior() then
        nav.other = true
        return
    end
    nav.dist = dist3(x, y, z, m.x, m.y, m.z)
    local bearing = math.deg(atan2(m.x - x, m.y - y))
    nav.compass = compassName(bearing)
    local h = viewHeading()
    if h then nav.rel = ((bearing - h + 180) % 360) - 180 end

    if nav.dist <= M.arrive and marks.arrivedFor ~= M.target then
        marks.arrivedFor = M.target
        chat("{00FF00}Вы пришли: " .. m.name)
        if M.autoClear then
            M.target = 0
            markDirty()
        end
    end
end

-- ---------- кнопки-команды ----------
-- Одна кнопка отправляет одну строку. Серий и повторов нет, чтобы не получить флуд-кик.

local btns = {last = 0, status = ""}

function btns.send(cmd)
    cmd = cleanStr(cmd, 100)
    if cmd == "" then return false, "у кнопки нет команды" end
    local now = os.clock()
    if now - btns.last < 0.6 then return false, "слишком часто" end
    btns.last = now
    local ok, err = pcall(sampSendChat, u8:decode(cmd))
    if not ok then return false, tostring(err) end
    return true
end

local function loadBtnToBuf()
    local b = cfg.btn.list[ui11.btnSel]
    setBuf(ui11.btnName, b and b.name or "")
    setBuf(ui11.btnCmd, b and b.cmd or "")
end

local function loadMarkToBuf()
    local m = cfg.marks.list[ui11.markSel]
    setBuf(ui11.markName, m and m.name or "")
end

-- заполнить поля ввода из настроек (при запуске и после импорта)
local function refreshBuffers11()
    ui11.btnSel = math.max(1, math.min(ui11.btnSel, math.max(#cfg.btn.list, 1)))
    loadBtnToBuf()
    setBuf(ui11.hide, cfg.chatf.hide)
    setBuf(ui11.hl, cfg.chatf.hlWords)
    setBuf(ui11.trig, cfg.mask.trigger)
    setBuf(ui11.trig2, cfg.mask.stopTrigger)
    ui11.markSel = math.min(ui11.markSel, #cfg.marks.list)
    loadMarkToBuf()
end
refreshBuffers11()

-- ---------- команды чата ----------
-- Имена выбраны так, чтобы не перекрывать серверные команды (у сервера есть свой /mask).

local function registerCommands11()
    sampRegisterChatCommand("maskt", function(arg)
        arg = tostring(arg or ""):match("^%s*(.-)%s*$")
        local low = arg:lower()
        if low == "stop" or low == "off" or low == "reset" then
            if not mask.stop() then chat("Таймер маски не запущен") end
            return
        end
        local phase, left = mask.phase(os.time())
        if arg == "" then
            if phase == 'active' then
                chat("Маска: осталось " .. fmtClock(left))
            elseif phase == 'cooldown' then
                chat("Маска: можно снова через " .. fmtClock(left))
            else
                mask.start()
            end
            return
        end
        local n = tonumber(arg)
        if n and n >= 1 and n <= 180 then
            mask.start(n)
        else
            chat("Использование: /maskt [минуты] или /maskt stop")
        end
    end)

    sampRegisterChatCommand("pnt", function(arg)
        local i, err = marks.add(toUtf(tostring(arg or "")))
        if i then
            chat("Метка сохранена: " .. cfg.marks.list[i].name .. " (№" .. i .. ")")
        else
            chat("Не удалось сохранить метку: " .. tostring(err))
        end
    end)

    sampRegisterChatCommand("pgo", function(arg)
        arg = toUtf(tostring(arg or ""))
        if cleanStr(arg, 60) == "" then
            marks.setTarget(0)
            chat("Навигация к метке выключена")
            return
        end
        local i = marks.find(arg)
        if not i then
            chat("Метка не найдена. Список: /hub, вкладка Метки")
            return
        end
        marks.setTarget(i)
        chat("Веду к метке: " .. cfg.marks.list[i].name)
    end)
end

-- раз в четверть секунды из главного цикла
local function modulesTick()
    pcall(mask.tick)
    pcall(X.optWatch)
    pcall(X.pickupTick)
    if X.modTick then pcall(X.modTick) end
    for _, f in ipairs(X.tickers) do pcall(f) end
    if cfg.marks.target > 0 then
        pcall(marks.tick)
    else
        marks.nav = {active = false}
    end
end

-- =========================================================
-- СТИЛЬ И ВИДЖЕТЫ
-- =========================================================

local uiTheme = imgui.new.float[3](cfg.theme[1], cfg.theme[2], cfg.theme[3])
local uiCross = imgui.new.float[3](cfg.view.crossColor[1], cfg.view.crossColor[2], cfg.view.crossColor[3])
local uiTint  = imgui.new.float[3](cfg.view.tintColor[1], cfg.view.tintColor[2], cfg.view.tintColor[3])

-- ---------- данные для своего HUD ----------
local viewState = {
    hp = 0, maxHp = 100, armor = 0, money = nil,
    inCar = false, speed = 0, carHp = 1000, armed = false,
}
local viewError = ""

local function col(r, g, b, a)
    return imgui.ColorConvertFloat4ToU32(imgui.ImVec4(r, g, b, a))
end

local function fmtMoney(n)
    n = math.floor(n)
    local digits = tostring(math.abs(n))
    local rev = digits:reverse()
    rev = rev:gsub("(%d%d%d)", "%1 ")
    local out = rev:reverse()
    out = out:gsub("^%s+", "")
    return (n < 0 and "-" or "") .. out
end

local function readMoney()
    if type(storeScore) == 'function' then
        local ok, v = pcall(storeScore, PLAYER_HANDLE)
        if ok and type(v) == 'number' then return v end
    end
    return nil
end

local function updateViewState()
    local ok, err = pcall(function()
        local hp = getCharHealth(PLAYER_PED)
        viewState.hp = hp
        viewState.maxHp = math.max(100, hp)
        viewState.armor = getCharArmour(PLAYER_PED)
        viewState.money = readMoney()

        local w = getCurrentCharWeapon(PLAYER_PED)
        viewState.armed = type(w) == 'number' and w > 0

        if isCharInAnyCar(PLAYER_PED) then
            local car = storeCarCharIsInNoSave(PLAYER_PED)
            viewState.inCar = true
            viewState.speed = getCarSpeed(car) * 3.6 * cfg.view.speedCalib / 100
            viewState.carHp = getCarHealth(car)
        else
            viewState.inCar = false
            viewState.speed = 0
        end
    end)
    if ok then viewError = "" else viewError = tostring(err) end
end

local function applyStyle()
    -- без своей темы начинаем с обычного тёмного стиля: так сброс после отключения темы чистый
    if not cfg.ui.useTheme and imgui.StyleColorsDark then pcall(imgui.StyleColorsDark) end
    local style = imgui.GetStyle()
    style.WindowRounding = 12
    style.ChildRounding = 10
    style.FrameRounding = 8
    style.PopupRounding = 8
    style.GrabRounding = 8
    style.ScrollbarRounding = 8
    style.WindowPadding = imgui.ImVec2(14, 14)
    style.FramePadding = imgui.ImVec2(10, 7)
    style.ItemSpacing = imgui.ImVec2(8, 8)
    style.ScrollbarSize = 14

    local r, g, b = uiTheme[0], uiTheme[1], uiTheme[2]
    local C = style.Colors
    local V = imgui.ImVec4

    C[imgui.Col.WindowBg]             = V(0.055, 0.055, 0.070, 0.98)
    C[imgui.Col.ChildBg]              = V(0.040, 0.040, 0.052, 0.90)
    C[imgui.Col.TitleBg]              = V(r * 0.40, g * 0.40, b * 0.40, 0.90)
    C[imgui.Col.TitleBgActive]        = V(r * 0.75, g * 0.75, b * 0.75, 1.00)
    C[imgui.Col.TitleBgCollapsed]     = V(r * 0.25, g * 0.25, b * 0.25, 0.70)
    C[imgui.Col.FrameBg]              = V(r * 0.25, g * 0.25, b * 0.25, 0.60)
    C[imgui.Col.FrameBgHovered]       = V(r * 0.40, g * 0.40, b * 0.40, 0.70)
    C[imgui.Col.FrameBgActive]        = V(r * 0.55, g * 0.55, b * 0.55, 0.80)
    C[imgui.Col.Button]               = V(r * 0.70, g * 0.70, b * 0.70, 0.85)
    C[imgui.Col.ButtonHovered]        = V(r, g, b, 0.95)
    C[imgui.Col.ButtonActive]         = V(r * 0.60, g * 0.60, b * 0.60, 1.00)
    C[imgui.Col.CheckMark]            = V(r, g, b, 1.00)
    C[imgui.Col.SliderGrab]           = V(r * 0.85, g * 0.85, b * 0.85, 1.00)
    C[imgui.Col.SliderGrabActive]     = V(r, g, b, 1.00)
    C[imgui.Col.Header]               = V(r * 0.50, g * 0.50, b * 0.50, 0.70)
    C[imgui.Col.HeaderHovered]        = V(r * 0.75, g * 0.75, b * 0.75, 0.85)
    C[imgui.Col.HeaderActive]         = V(r, g, b, 1.00)
    C[imgui.Col.Separator]            = V(r * 0.60, g * 0.60, b * 0.60, 0.60)
    C[imgui.Col.SeparatorHovered]     = V(r * 0.80, g * 0.80, b * 0.80, 0.80)
    C[imgui.Col.SeparatorActive]      = V(r, g, b, 1.00)

    -- тема из вкладки «Темы» ложится поверх, если включена
    if cfg.ui.useTheme and X.afterStyle then pcall(X.afterStyle) end
end

-- =========================================================
-- ОБМЕН НАСТРОЙКАМИ: код PRH1-<контрольная сумма>-<данные>
-- В код не попадают пароль, заметки, метки и таймер маски.
-- =========================================================

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local B64IDX = {}
for i = 1, #B64 do B64IDX[B64:byte(i)] = i - 1 end

local function b64enc(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        local piece = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
        if b then piece = piece .. B64:sub(c3 + 1, c3 + 1) end
        if c then piece = piece .. B64:sub(c4 + 1, c4 + 1) end
        out[#out + 1] = piece
    end
    return table.concat(out)
end

local function b64dec(s)
    if #s % 4 == 1 then return nil end
    local out = {}
    for i = 1, #s, 4 do
        local chunk = s:sub(i, i + 3)
        local v = {}
        for j = 1, #chunk do
            local x = B64IDX[chunk:byte(j)]
            if not x then return nil end
            v[j] = x
        end
        local acc = v[1] * 262144 + v[2] * 4096 + (v[3] or 0) * 64 + (v[4] or 0)
        out[#out + 1] = string.char(math.floor(acc / 65536) % 256)
        if #chunk >= 3 then out[#out + 1] = string.char(math.floor(acc / 256) % 256) end
        if #chunk == 4 then out[#out + 1] = string.char(acc % 256) end
    end
    return table.concat(out)
end

local function checksum(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return string.format("%04x", (b * 31 + a) % 65536)
end

local SHARE_SECTIONS = {
    {key = 'opt',      label = "Настройки FPS"},
    {key = 'tw',       label = "Время и погода"},
    {key = 'view',     label = "Вид: HUD, спидометр, прицел, тонировка"},
    {key = 'theme',    label = "Цвет интерфейса"},
    {key = 'panels',   label = "Панель FPS и кнопка HUB (размер, прозрачность)"},
    {key = 'btn',      label = "Кнопки-команды"},
    {key = 'chatf',    label = "Фильтр чата"},
    {key = 'anim',     label = "Наборы анимаций"},
    {key = 'mask',     label = "Таймер маски (время и вид)"},
    {key = 'profiles', label = "Мои профили FPS и сцены"},
    {key = 'alert',    label = "Уведомление о нике и словах"},
    {key = 'timers',   label = "Свои таймеры (названия и время)"},
    {key = 'tpl',      label = "Шаблоны текстов"},
}

local share = {inc = {}, code = "", msg = "", preview = nil}
for _, sec in ipairs(SHARE_SECTIONS) do share.inc[sec.key] = true end

local OVERLAY_KEYS = {'enabled', 'fps', 'ping', 'clock', 'counts', 'scale', 'alpha'}
local UI_KEYS = {'launcher', 'lScale', 'lAlpha', 'lxp', 'lyp'}

local function pick(tbl, keys)
    local out = {}
    for _, k in ipairs(keys) do out[k] = deepcopy(tbl[k]) end
    return out
end

-- приводит чужие данные к форме шаблона: лишние ключи отбрасываются,
-- значения не того типа и нечисловые NaN заменяются значениями по умолчанию
local function coerceLike(src, def)
    if type(def) ~= 'table' then
        if type(src) == type(def) and (type(def) ~= 'number' or finite(src)) then return src end
        return def
    end
    if isArray(def) then
        local out = {}
        for i = 1, #def do
            out[i] = coerceLike(type(src) == 'table' and src[i] or nil, def[i])
        end
        return out
    end
    local out = {}
    for k, dv in pairs(def) do
        local sv = nil
        if type(src) == 'table' then sv = src[k] end
        out[k] = coerceLike(sv, dv)
    end
    return out
end

-- названия групп и библиотек анимаций: только латиница, цифры и подчёркивание
local function animName(s, maxBytes)
    s = cleanStr(s, maxBytes)
    if not s:match("^[%w_]*$") then return "" end
    return s
end

function share.build()
    local inc, s = share.inc, {}
    if inc.opt then
        s.opt = deepcopy(cfg.opt)
        s.opt.whitelist = nil
    end
    if inc.tw then s.tw = deepcopy(cfg.tw) end
    if inc.view then s.view = deepcopy(cfg.view) end
    if inc.theme then s.theme = deepcopy(cfg.theme) end
    if inc.panels then
        s.panels = {overlay = pick(cfg.overlay, OVERLAY_KEYS), ui = pick(cfg.ui, UI_KEYS)}
    end
    if inc.btn then s.btn = deepcopy(cfg.btn) end
    if inc.chatf then s.chatf = deepcopy(cfg.chatf) end
    if inc.anim then s.anim = {sets = deepcopy(cfg.anim.sets)} end
    if inc.mask then
        s.mask = deepcopy(cfg.mask)
        s.mask.endAt, s.mask.coolEnd = nil, nil
    end
    if inc.profiles then
        local list = {}
        for _, p in ipairs(cfg.profiles) do
            local item = {name = p.name, opt = deepcopy(p.opt), tw = deepcopy(p.tw)}
            if item.opt then item.opt.whitelist = nil end
            list[#list + 1] = item
        end
        s.profiles = list
    end
    if inc.alert then s.alert = deepcopy(cfg.alert) end
    if inc.timers then
        local t = deepcopy(cfg.timers)
        for _, item in ipairs(t.list) do item.endAt = nil end   -- что запущено у меня, чужим не нужно
        s.timers = t
    end
    if inc.tpl then s.tpl = {list = deepcopy(cfg.tpl.list)} end
    if next(s) == nil then return nil, "Ничего не выбрано" end

    local ok, js = pcall(cjson.encode, {v = 1, hub = "1.1", s = s})
    if not ok then return nil, "Не удалось собрать код" end
    local code = "PRH1-" .. checksum(js) .. "-" .. b64enc(js)
    if #code > 15000 then return nil, "Код слишком большой: снимите часть разделов" end
    return code
end

-- разбор кода: payload, nil, список найденных разделов  или  nil, причина
function share.parse(text)
    text = (tostring(text or ""):gsub("%s", ""))
    local chk, body = text:match("PRH1%-(%x%x%x%x)%-([%w%-_]+)")
    if not body then return nil, "Не похоже на код MultiTools: он начинается с PRH1-" end
    local js = b64dec(body)
    if not js then return nil, "Код повреждён: лишние или пропущенные символы" end
    if checksum(js) ~= chk:lower() then
        return nil, "Контрольная сумма не сошлась: код скопирован не полностью"
    end
    local ok, p = pcall(cjson.decode, js)
    if not ok or type(p) ~= 'table' or type(p.s) ~= 'table' then return nil, "Код не читается" end
    if p.v ~= 1 then return nil, "Код другого формата (версия " .. tostring(p.v) .. ")" end
    local found = {}
    for _, sec in ipairs(SHARE_SECTIONS) do
        if type(p.s[sec.key]) == 'table' then found[#found + 1] = sec end
    end
    if #found == 0 then return nil, "В коде нет известных разделов" end
    return p, nil, found
end

local function sectionNote(key, data)
    if key == 'btn' and type(data.list) == 'table' then return "кнопок: " .. #data.list end
    if key == 'anim' and type(data.sets) == 'table' then return "наборов: " .. #data.sets end
    if key == 'profiles' then return "профилей: " .. #data end
    if key == 'timers' and type(data.list) == 'table' then return "таймеров: " .. #data.list end
    if key == 'tpl' and type(data.list) == 'table' then return "шаблонов: " .. #data.list end
    return nil
end

-- применяет разобранный код; возвращает названия применённых разделов
function share.apply(p)
    local S, D = p.s, defaultCfg()
    local done = {}
    local function mark(key) done[#done + 1] = key end

    if type(S.opt) == 'table' then
        local o = coerceLike(S.opt, D.opt)
        o.whitelist = cfg.opt.whitelist
        applyOptProfile(o)
        mark('opt')
    end
    if type(S.tw) == 'table' then
        applyScene(coerceLike(S.tw, D.tw))
        mark('tw')
    end
    if type(S.view) == 'table' then
        cfg.view = coerceLike(S.view, D.view)
        for i = 1, 3 do
            uiCross[i - 1] = num(cfg.view.crossColor[i], 0, 1, 1)
            uiTint[i - 1] = num(cfg.view.tintColor[i], 0, 1, 1)
        end
        mark('view')
    end
    if type(S.theme) == 'table' then
        cfg.theme = fixColor(S.theme, D.theme)
        for i = 1, 3 do uiTheme[i - 1] = cfg.theme[i] end
        cfg.ui.useTheme = false
        applyStyle()
        mark('theme')
    end
    if type(S.panels) == 'table' then
        if type(S.panels.overlay) == 'table' then
            local o = coerceLike(S.panels.overlay, pick(D.overlay, OVERLAY_KEYS))
            for k, v in pairs(o) do cfg.overlay[k] = v end
        end
        if type(S.panels.ui) == 'table' then
            local u = coerceLike(S.panels.ui, pick(D.ui, UI_KEYS))
            for k, v in pairs(u) do cfg.ui[k] = v end
            movePending.launcher = true
        end
        mark('panels')
    end
    if type(S.btn) == 'table' then
        local def = deepcopy(D.btn)
        def.list = nil
        local b = coerceLike(S.btn, def)
        b.list = sanitizeButtons(S.btn.list)
        cfg.btn = b
        movePending.btn = true
        mark('btn')
    end
    if type(S.chatf) == 'table' then
        cfg.chatf = coerceLike(S.chatf, D.chatf)
        mark('chatf')
    end
    if type(S.anim) == 'table' and type(S.anim.sets) == 'table' then
        local sets = {}
        for _, st in ipairs(S.anim.sets) do
            if type(st) == 'table' and #sets < 30 then
                local name = cleanStr(st.name, 40)
                if name ~= "" then
                    sets[#sets + 1] = {name = name, group = animName(st.group, 40), lib = animName(st.lib, 40)}
                end
            end
        end
        if #sets > 0 then
            cfg.anim.sets = sets
            mark('anim')
        end
    end
    if type(S.mask) == 'table' then
        local def = deepcopy(D.mask)
        def.endAt, def.coolEnd = nil, nil
        local m = coerceLike(S.mask, def)
        m.endAt, m.coolEnd = cfg.mask.endAt, cfg.mask.coolEnd
        cfg.mask = m
        mark('mask')
    end
    if type(S.profiles) == 'table' then
        for _, pr in ipairs(S.profiles) do
            if type(pr) == 'table' and #cfg.profiles < 30 then
                local name = cleanStr(pr.name, 40)
                local item = {name = name ~= "" and name or "Профиль"}
                if type(pr.opt) == 'table' then
                    item.opt = coerceLike(pr.opt, D.opt)
                    item.opt.whitelist = ""
                    fixOpt(item.opt)
                end
                if type(pr.tw) == 'table' then
                    item.tw = coerceLike(pr.tw, D.tw)
                    fixTw(item.tw)
                end
                if item.opt or item.tw then table.insert(cfg.profiles, item) end
            end
        end
        mark('profiles')
    end

    if type(S.alert) == 'table' then
        cfg.alert = coerceLike(S.alert, D.alert)
        mark('alert')
    end
    if type(S.timers) == 'table' then
        local def = deepcopy(D.timers)
        def.list = nil
        local t = coerceLike(S.timers, def)
        t.list = X.sanitizeTimers(S.timers.list)
        for _, item in ipairs(t.list) do item.endAt = 0 end
        cfg.timers = t
        mark('timers')
    end
    if type(S.tpl) == 'table' then
        local list = X.sanitizeTpl(S.tpl.list)
        if #list > 0 then
            cfg.tpl.list = list
            mark('tpl')
        end
    end

    sanitize()
    for i = 1, 3 do
        uiCross[i - 1] = cfg.view.crossColor[i]
        uiTint[i - 1] = cfg.view.tintColor[i]
        uiTheme[i - 1] = cfg.theme[i]
    end
    applyStyle()
    refreshBuffers11()
    X.refresh12()
    markDirty()
    return done
end

local exportPath = configDir .. '/rodina_hub_export.txt'
local importPath = configDir .. '/rodina_hub_import.txt'

function share.saveFile(code)
    if not doesDirectoryExist(configDir) then createDirectory(configDir) end
    local f = io.open(exportPath, 'w')
    if not f then return false end
    f:write(code)
    f:close()
    return true
end

function share.readFile()
    local f = io.open(importPath, 'r')
    if not f then return nil end
    local t = f:read('*a')
    f:close()
    return t and t:sub(1, 16000) or nil
end

local function clipboardGet()
    local ok, t = pcall(imgui.GetClipboardText)
    if not ok or t == nil then return "" end
    if type(t) == 'string' then return t end
    local ok2, str = pcall(ffi.string, t)
    return ok2 and str or ""
end

-- проверить текст из поля импорта и показать, что внутри
function share.check()
    local text = ffi.string(ui11.importBuf)
    local p, err, found = share.parse(text)
    if not p then
        share.preview = nil
        share.msg = err
        return
    end
    local lines = {}
    for _, sec in ipairs(found) do
        local note = sectionNote(sec.key, p.s[sec.key])
        lines[#lines + 1] = sec.label .. (note and (" (" .. note .. ")") or "")
    end
    share.preview = {payload = p, lines = lines}
    share.msg = "Код прочитан. Проверьте список и нажмите «Применить»."
end

local boolCache, intCache = {}, {}

local function checkbox(label, tbl, key)
    local id = tostring(tbl) .. key
    local b = boolCache[id]
    if not b then
        b = imgui.new.bool(false)
        boolCache[id] = b
    end
    b[0] = tbl[key] and true or false
    if imgui.Checkbox(label, b) then
        tbl[key] = b[0]
        markDirty()
        return true
    end
    return false
end

local function sliderInt(label, tbl, key, a, b)
    local id = tostring(tbl) .. key
    local i = intCache[id]
    if not i then
        i = imgui.new.int(0)
        intCache[id] = i
    end
    i[0] = tbl[key] or a
    if imgui.SliderInt(label, i, a, b) then
        tbl[key] = i[0]
        markDirty()
        return true
    end
    return false
end

local function header(text)
    imgui.TextColored(imgui.ImVec4(uiTheme[0], uiTheme[1], uiTheme[2], 1.0), text)
    imgui.Dummy(imgui.ImVec2(0, 3))
end

-- текст без printf-разбора: для строк с сервера и со знаком процента
local function plainText(s)
    imgui.PushTextWrapPos(0.0)
    imgui.TextUnformatted(tostring(s))
    imgui.PopTextWrapPos()
end

local function sep()
    imgui.Dummy(imgui.ImVec2(0, 3))
    imgui.Separator()
    imgui.Dummy(imgui.ImVec2(0, 3))
end

local function fullWidthSlider(title, tbl, key, a, b)
    imgui.Text(title)
    imgui.PushItemWidth(-1)
    local changed = sliderInt('##' .. key, tbl, key, a, b)
    imgui.PopItemWidth()
    return changed
end

-- Положение окон, которые двигаются пальцем: в cfg хранятся проценты экрана.
-- Из конфига окно ставится при первом показе; дальше его можно тащить, а новое
-- место запоминается. Ползунок положения принудительно переставляет окно.
local function winPos(id, tbl, kx, ky)
    local sw, sh = getScreenResolution()
    local x = math.max(0, math.min(sw * tbl[kx] / 100, sw - 40))
    local y = math.max(0, math.min(sh * tbl[ky] / 100, sh - 40))
    local cond = movePending[id] and imgui.Cond.Always or imgui.Cond.FirstUseEver
    movePending[id] = nil
    imgui.SetNextWindowPos(imgui.ImVec2(x, y), cond)
end

local function winSave(tbl, kx, ky)
    local sw, sh = getScreenResolution()
    if sw <= 0 or sh <= 0 then return end
    local p = imgui.GetWindowPos()
    if not p then return end
    local xp = math.max(0, math.min(100, p.x / sw * 100))
    local yp = math.max(0, math.min(100, p.y / sh * 100))
    if math.abs(xp - tbl[kx]) * sw / 100 >= 2 or math.abs(yp - tbl[ky]) * sh / 100 >= 2 then
        tbl[kx] = math.floor(xp * 100) / 100
        tbl[ky] = math.floor(yp * 100) / 100
        markDirty()
    end
end

local function tabButton(label, idx, width)
    local active = currentTab == idx
    local r, g, b = uiTheme[0], uiTheme[1], uiTheme[2]
    if active then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(r, g, b, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(math.min(r * 1.15, 1), math.min(g * 1.15, 1), math.min(b * 1.15, 1), 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(r * 0.8, g * 0.8, b * 0.8, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 1, 1, 1))
    end
    local clicked = imgui.Button(label .. '##tab' .. idx, imgui.ImVec2(width, 38))
    if active then imgui.PopStyleColor(4) end
    if clicked then currentTab = idx end
end

-- =========================================================
-- ВКЛАДКИ
-- =========================================================

local T = {}

function T.drawOptTab()
    header("Скрытие объектов мира")

    checkbox("Скрывать игроков##optP", cfg.opt, 'players')
    fullWidthSlider("Игроков дальше N м (0 = всех)", cfg.opt, 'distP', 0, 300)

    sep()
    checkbox("Скрывать транспорт##optV", cfg.opt, 'vehicles')
    fullWidthSlider("Транспорта дальше N м (0 = всего)", cfg.opt, 'distV', 0, 300)

    sep()
    checkbox("Скрывать объекты (дома, бизнесы)##optO", cfg.opt, 'objects')
    fullWidthSlider("Объектов дальше N м (0 = всех)", cfg.opt, 'distO', 0, 300)

    sep()
    imgui.Text("Не скрывать игроков с ID (через запятую):")
    imgui.PushItemWidth(-1)
    if imgui.InputText("##wl", wlBuf, ffi.sizeof(wlBuf)) then
        cfg.opt.whitelist = ffi.string(wlBuf)
        markDirty()
    end
    imgui.PopItemWidth()

    sep()
    header("Автоматически в толпе")
    checkbox("Включать скрытие при большом онлайне рядом##auto", cfg.opt, 'autoCrowd')
    fullWidthSlider("Игроков рядом от:", cfg.opt, 'crowdP', 1, 100)
    fullWidthSlider("Транспорта рядом от:", cfg.opt, 'crowdV', 1, 100)
    imgui.Text(string.format("Сейчас: толпа игроков - %s, транспорта - %s",
        crowd.p and "да" or "нет", crowd.v and "да" or "нет"))

    sep()
    header("Лишние элементы")
    checkbox("Убрать пикапы##pick", cfg.opt, 'noPickups')
    do
        local pk = X.pk
        imgui.TextWrapped("Убираются пикапы, которые сервер создаёт после включения. Когда галочку снимете, запомненные вернутся сами.")
        imgui.Text(string.format("Пикапов запомнено: %d", pk.n))
        if pk.queue then
            imgui.Text(string.format("Возвращаю, осталось: %d", #pk.queue))
        elseif pk.restored > 0 or pk.failed > 0 then
            imgui.Text(string.format("Возвращено: %d, не вышло: %d", pk.restored, pk.failed))
        end
    end
    checkbox("Убрать облачка чата над головами##bub", cfg.opt, 'noBubbles')
    checkbox("Урезать дальность 3D-текстов##t3d", cfg.opt, 'text3d')
    fullWidthSlider("Дальность 3D-текстов, м:", cfg.opt, 'text3dDist', 0, 100)
    checkbox("Убрать аксессуары у других##accO", cfg.opt, 'accOthers')
    checkbox("Убрать аксессуары у меня##accM", cfg.opt, 'accMe')

    sep()
    header("Статистика")
    imgui.Text(string.format("Рядом: игроков %d, транспорта %d, объектов %d", live.p, live.v, live.o))
    imgui.Text(string.format("Убрано за сессию: %d / %d / %d", removed.players, removed.vehicles, removed.objects))

    sep()
    header("Статистика сессии")
    local avgFps = stats.fpsCount > 0 and stats.fpsSum / stats.fpsCount or 0
    local avgPing = stats.pingCount > 0 and stats.pingSum / stats.pingCount or 0
    local dist = stats.distance >= 1000
        and string.format("%.2f км", stats.distance / 1000)
        or string.format("%d м", math.floor(stats.distance))
    imgui.Text("Время на сервере: " .. fmtTime(stats.onlineSec))
    imgui.Text("Пройдено (пешком и на машине): " .. dist)
    imgui.Text(string.format("FPS: пик %d, средний %d", math.floor(stats.peakFps), math.floor(avgFps)))
    imgui.Text(string.format("Пинг: пик %d, средний %d", math.floor(stats.peakPing), math.floor(avgPing)))
    if imgui.Button("Сбросить статистику##sreset", imgui.ImVec2(-1, 36)) then
        resetStats()
    end
    sep()
    header("Нагрузка скрипта")
    do
        local pf = X.perf.snap
        local total = pf.loop + pf.clean + pf.frame
        plainText(string.format("Сейчас: %.1f мс в секунду (%.2f%% времени)", total, total / 10))
        plainText(string.format("Цикл %.1f, очистка мира %.1f, окна %.1f мс/с", pf.loop, pf.clean, pf.frame))
        imgui.TextWrapped("Считается только работа Lua-кода скрипта, без отрисовки окон самим mimgui и игрой. Если здесь единицы мс/с, а FPS просел, дело не в логике скрипта: попробуйте выключить панели на вкладках «Экран» и «Вид».")
    end

    sep()
    if optError ~= "" then
        imgui.TextColored(imgui.ImVec4(1, 0.4, 0.4, 1), "Ошибка: " .. optError)
    end
    if imgui.Button("Очистить сейчас##clean", imgui.ImVec2(-1, 36)) then
        requestClean = true
    end
    imgui.TextWrapped("Скрытых игроков, транспорт и объекты клиент не показывает заново, пока сервер сам не загрузит их снова. Отойдите и вернитесь. Пикапы возвращаются сразу.")
end

local timePresets = {{"Утро", 6, 0}, {"День", 12, 0}, {"Вечер", 19, 0}, {"Ночь", 0, 0}}
local weatherPresets = {{"Ясно", 1}, {"Облачно", 4}, {"Дождь", 8}, {"Туман", 9}}

function T.drawWorldTab()
    header("Время")
    checkbox("Своё время##tl", cfg.tw, 'timeLock')
    fullWidthSlider("Час:", cfg.tw, 'hour', 0, 23)
    fullWidthSlider("Минута:", cfg.tw, 'minute', 0, 59)
    for i, p in ipairs(timePresets) do
        if i > 1 then imgui.SameLine() end
        if imgui.Button(p[1] .. "##tp" .. i) then
            cfg.tw.hour, cfg.tw.minute, cfg.tw.timeLock = p[2], p[3], true
            markDirty()
        end
    end

    imgui.Dummy(imgui.ImVec2(0, 4))
    if checkbox("Течение времени (день и ночь сменяются сами)##flow", cfg.tw, 'flow') and cfg.tw.flow then
        cfg.tw.timeLock = true
    end
    fullWidthSlider("Скорость: игровых минут в секунду (1 = как в GTA SA)", cfg.tw, 'flowSpeed', 1, 120)

    sep()
    header("Погода")
    if checkbox("Своя погода##wl", cfg.tw, 'weatherLock') and not cfg.tw.weatherLock then
        pcall(releaseWeather)
    end
    fullWidthSlider("ID погоды:", cfg.tw, 'weather', 0, 45)
    for i, p in ipairs(weatherPresets) do
        if i > 1 then imgui.SameLine() end
        if imgui.Button(p[1] .. "##wp" .. i) then
            cfg.tw.weather, cfg.tw.weatherLock = p[2], true
            markDirty()
        end
    end
    imgui.Dummy(imgui.ImVec2(0, 6))
    imgui.TextWrapped("Это только на вашем экране, другие игроки не видят. Пока галочки включены, сервер не сбросит выбранные значения.")
end

local aName, aGroup, aLib = imgui.new.char[64](), imgui.new.char[64](), imgui.new.char[64]()

function T.drawAnimTab()
    header("Подмена анимаций ходьбы")
    if checkbox("Включить подмену##ae", cfg.anim, 'enabled') then
        applyAnim()
    end
    sep()

    local removeIdx
    for i, set in ipairs(cfg.anim.sets) do
        if imgui.RadioButtonBool(set.name .. "##set" .. i, cfg.anim.active == i) then
            cfg.anim.active = i
            markDirty()
            if cfg.anim.enabled then applyAnim() end
        end
        if set.custom then
            imgui.SameLine()
            if imgui.Button("X##adel" .. i) then removeIdx = i end
        end
    end
    if removeIdx then
        table.remove(cfg.anim.sets, removeIdx)
        if cfg.anim.active >= removeIdx then
            cfg.anim.active = math.max(1, cfg.anim.active - 1)
        end
        markDirty()
        if cfg.anim.enabled then applyAnim() end
    end

    sep()
    header("Добавить свой набор")
    imgui.InputText("Название##an", aName, ffi.sizeof(aName))
    imgui.InputText("Группа##ag", aGroup, ffi.sizeof(aGroup))
    imgui.InputText("Библиотека (необязательно)##al", aLib, ffi.sizeof(aLib))
    if imgui.Button("Добавить##aadd", imgui.ImVec2(-1, 36)) then
        local name, group, lib = ffi.string(aName), ffi.string(aGroup), ffi.string(aLib)
        if name ~= "" and group ~= "" then
            table.insert(cfg.anim.sets, {name = name, group = group, lib = lib, custom = true})
            ffi.fill(aName, ffi.sizeof(aName))
            ffi.fill(aGroup, ffi.sizeof(aGroup))
            ffi.fill(aLib, ffi.sizeof(aLib))
            markDirty()
        end
    end
end

function T.drawScreenTab()
    header("Размер окна меню")
    if fullWidthSlider("Ширина, % экрана:", cfg.ui, 'winW', 30, 100) then X.win.apply = true; X.win.full = false end
    if fullWidthSlider("Высота, % экрана:", cfg.ui, 'winH', 25, 100) then X.win.apply = true; X.win.full = false end
    imgui.TextWrapped("То же делают кнопки внизу окна. Окно можно и тянуть за правый нижний угол: размер запомнится.")

    sep()
    header("Скрыть интерфейс (для скриншотов и видео)")
    checkbox("Скрывать HUD##hh", cfg.hud, 'hideHud')
    checkbox("Скрывать радар##hr", cfg.hud, 'hideRadar')
    checkbox("Скрывать чат##hc", cfg.hud, 'hideChat')
    if imgui.Button(hudHidden and "Показать интерфейс##hb" or "Скрыть интерфейс##hb", imgui.ImVec2(-1, 36)) then
        setHudHidden(not hudHidden)
    end
    imgui.TextWrapped("Пока интерфейс скрыт, в углу висит кнопка «Показать». Свои панели Родины (здоровье, деньги, кнопки) могут не скрыться: они рисуются самой игрой.")

    sep()
    header("Информационная панель")
    checkbox("Показывать панель##ove", cfg.overlay, 'enabled')
    checkbox("FPS##ovf", cfg.overlay, 'fps')
    checkbox("Пинг##ovp", cfg.overlay, 'ping')
    checkbox("Время##ovc", cfg.overlay, 'clock')
    checkbox("Игроки и транспорт рядом##ovn", cfg.overlay, 'counts')
    local sw, sh = getScreenResolution()
    fullWidthSlider("Позиция X:", cfg.overlay, 'x', 0, math.max(sw, 100))
    fullWidthSlider("Позиция Y:", cfg.overlay, 'y', 0, math.max(sh, 100))
    fullWidthSlider("Размер панели, %:", cfg.overlay, 'scale', 50, 300)
    fullWidthSlider("Прозрачность фона, %:", cfg.overlay, 'alpha', 0, 100)

    sep()
    header("Кнопка HUB на экране")
    checkbox("Показывать кнопку HUB##lau", cfg.ui, 'launcher')
    fullWidthSlider("Размер кнопки, %:", cfg.ui, 'lScale', 50, 300)
    fullWidthSlider("Непрозрачность кнопки, %:", cfg.ui, 'lAlpha', 10, 100)
    if fullWidthSlider("Позиция X, %:", cfg.ui, 'lxp', 0, 100) then movePending.launcher = true end
    if fullWidthSlider("Позиция Y, %:", cfg.ui, 'lyp', 0, 100) then movePending.launcher = true end
    imgui.TextWrapped("Кнопку можно ещё и перетащить пальцем: новое место запомнится.")
end

function T.drawNotesTab()
    header("Заметки")
    for i, n in ipairs(cfg.notes) do
        local title = (n.title ~= "" and n.title or "Без названия") .. "##note" .. i
        if imgui.RadioButtonBool(title, noteSel == i) then
            noteSel = i
            loadNoteToBuf()
        end
    end

    if imgui.Button("Новая##nadd") then
        table.insert(cfg.notes, {title = "Новая заметка", text = ""})
        noteSel = #cfg.notes
        loadNoteToBuf()
        markDirty()
    end
    imgui.SameLine()
    if imgui.Button("Удалить##ndel") then
        table.remove(cfg.notes, noteSel)
        if #cfg.notes == 0 then cfg.notes = {{title = "Заметка", text = ""}} end
        noteSel = math.min(noteSel, #cfg.notes)
        loadNoteToBuf()
        markDirty()
    end

    sep()
    local n = cfg.notes[noteSel]
    if n then
        imgui.PushItemWidth(-1)
        if imgui.InputText("##ntitle", noteTitleBuf, ffi.sizeof(noteTitleBuf)) then
            n.title = ffi.string(noteTitleBuf)
            markDirty()
        end
        if imgui.InputTextMultiline("##ntext", noteTextBuf, ffi.sizeof(noteTextBuf), imgui.ImVec2(-1, 220)) then
            n.text = ffi.string(noteTextBuf)
            markDirty()
        end
        imgui.PopItemWidth()
    end
end

local function profileLabel(p)
    local tag = "[Сцена] "
    if p.opt and p.tw then tag = "[FPS+сцена] "
    elseif p.opt then tag = "[FPS] " end
    return tag .. tostring(p.name)
end

function T.drawProfilesTab()
    header("Профили FPS")
    for i, p in ipairs(PRESETS) do
        if imgui.Button(p.name .. "##pre" .. i, imgui.ImVec2(-1, 36)) then
            applyProfile(p)
        end
    end

    sep()
    header("Сцены: время и погода")
    for i, p in ipairs(SCENES) do
        if imgui.Button(p.name .. "##scn" .. i, imgui.ImVec2(-1, 36)) then
            applyProfile(p)
        end
    end

    sep()
    header("Мои профили")
    local removeIdx
    for i, p in ipairs(cfg.profiles) do
        if imgui.Button(profileLabel(p) .. "##usr" .. i, imgui.ImVec2(-60, 36)) then
            applyProfile(p)
        end
        imgui.SameLine()
        if imgui.Button("X##pdel" .. i, imgui.ImVec2(-1, 36)) then removeIdx = i end
    end
    if removeIdx then
        table.remove(cfg.profiles, removeIdx)
        markDirty()
    end

    sep()
    imgui.Text("Название нового профиля:")
    imgui.PushItemWidth(-1)
    imgui.InputText("##pname", profNameBuf, ffi.sizeof(profNameBuf))
    imgui.PopItemWidth()

    if imgui.Button("Сохранить настройки FPS##psave", imgui.ImVec2(-1, 36)) then
        local name = ffi.string(profNameBuf)
        if name ~= "" then
            table.insert(cfg.profiles, {name = name, opt = deepcopy(cfg.opt)})
            ffi.fill(profNameBuf, ffi.sizeof(profNameBuf))
            markDirty()
        end
    end
    if imgui.Button("Сохранить время и погоду (сцену)##ssave", imgui.ImVec2(-1, 36)) then
        local name = ffi.string(profNameBuf)
        if name ~= "" then
            table.insert(cfg.profiles, {name = name, tw = deepcopy(cfg.tw)})
            ffi.fill(profNameBuf, ffi.sizeof(profNameBuf))
            markDirty()
        end
    end
    if imgui.Button("Сохранить всё вместе##asave", imgui.ImVec2(-1, 36)) then
        local name = ffi.string(profNameBuf)
        if name ~= "" then
            table.insert(cfg.profiles, {name = name, opt = deepcopy(cfg.opt), tw = deepcopy(cfg.tw)})
            ffi.fill(profNameBuf, ffi.sizeof(profNameBuf))
            markDirty()
        end
    end
end

local function drawThemeSection()
    header("Цвет интерфейса")
    imgui.PushItemWidth(-1)
    if imgui.ColorEdit3("##themecolor", uiTheme) then
        cfg.theme = {uiTheme[0], uiTheme[1], uiTheme[2]}
        cfg.ui.useTheme = false   -- выбран цвет здесь: он главнее темы из вкладки «Темы»
        applyStyle()
        markDirty()
    end
    imgui.PopItemWidth()
    imgui.TextWrapped("Выбор цвета здесь выключает тему из вкладки «Темы»: что-то одно.")

    sep()
    header("О скрипте")
    imgui.Text("Parovozov MultiTools v1.1")
    imgui.Text("Автор: Parovoz")
    imgui.Dummy(imgui.ImVec2(0, 4))
    imgui.TextWrapped("Команды: /hub - меню, /hp /hv /ho - быстро скрыть игроков, транспорт, объекты, /nohud - скрыть интерфейс, /settime [час] [мин], /setweather [id], /rc - автореконнект (вкл/выкл), /rc now - переподключиться, /al - автовход (вкл/выкл), /maskt [минуты] - таймер маски (/maskt stop - сброс), /pnt [название] - сохранить метку здесь, /pgo [номер или название] - вести к метке (без аргумента - выключить), /tmr [номер или название] [минуты] - свои таймеры (/tmr без аргументов - список, /tmr stop [номер] - сбросить), /pchat - свой чат (вкл/выкл), /pchatset - настройки своего чата, /themes - темы.")
    imgui.Dummy(imgui.ImVec2(0, 4))
    imgui.TextWrapped("Настройки хранятся в config/rodina_hub.json. Свой чат хранит их в parovozov_chat.json, темы в parovozov_themes.json.")
    sep()
    header("Что нового в 1.1")
    imgui.TextWrapped("- Свой чат и Темы встроены в хаб (вкладки Свой чат и Темы). Отдельные Parovozov_chat.lua и Parovozov_themes.lua больше не нужны.")
    imgui.TextWrapped("- Размер окна меню: кнопки Выше, Ниже, Шире, Уже, Весь экран внизу окна и ползунки на вкладке Экран.")
    imgui.TextWrapped("- Журнал чата на 300 строк с поиском и сохранением в файл, история последних 20 окон сервера (вкладка Журнал).")
    imgui.TextWrapped("- Мигающая рамка и строка сверху, когда в чате ваш ник или заданное слово (вкладка Чат).")
    imgui.TextWrapped("- Свои таймеры с названиями и командой /tmr (вкладка Таймеры), таймер маски (вкладка Маска).")
    imgui.TextWrapped("- Шаблоны текстов с подстановкой ника, ID, времени и даты (вкладка Шаблоны).")
    imgui.TextWrapped("- Несколько аккаунтов в автовходе: пароль для каждого ника (вкладка Вход).")
    imgui.TextWrapped("- График FPS и пинга за сессию и подсчёт дохода (вкладка График).")
    imgui.TextWrapped("- Свои кнопки-команды (вкладка Кнопки), фильтр чата (вкладка Чат), метки со стрелкой (вкладка Метки).")
    imgui.TextWrapped("- Обмен настройками одним кодом (вкладка Обмен), размер и прозрачность панели FPS и кнопки HUB (вкладка Экран).")
    imgui.TextWrapped("- Меньше нагрузки на FPS, счётчик нагрузки скрипта и возврат пикапов при выключении скрытия (вкладка FPS).")
end

local TINTS = {
    {"Тёплый",   {1.0, 0.55, 0.20}, 14, 0, 25},
    {"Холодный", {0.30, 0.55, 1.0}, 14, 0, 25},
    {"Кино",     {0.10, 0.45, 0.50}, 10, -10, 45},
    {"Яркий",    {1.0, 1.0, 1.0}, 0, 15, 0},
}

local function drawViewSections()
    local v = cfg.view

    header("Свой HUD (рядом с родным интерфейсом)")
    checkbox("Панель статуса##vhud", v, 'hudOn')
    checkbox("Здоровье##vhp", v, 'hpOn')
    checkbox("Броня##var", v, 'armorOn')
    checkbox("Деньги##vmn", v, 'moneyOn')
    checkbox("Часы##vck", v, 'clockOn')
    fullWidthSlider("Размер, %:", v, 'hudScale', 50, 200)
    fullWidthSlider("Положение X, % экрана:", v, 'hudXp', 0, 95)
    fullWidthSlider("Положение Y, % экрана:", v, 'hudYp', 0, 95)
    imgui.TextWrapped("Родной HUD Родины скрыть нельзя, эта панель появляется рядом. Деньги берутся из игры: если Родина хранит их на сервере, будет «нет данных».")

    sep()
    header("Спидометр (в машине)")
    checkbox("Показывать спидометр##vsp", v, 'speedOn')
    checkbox("Полоска прочности авто##vch", v, 'carHpOn')
    fullWidthSlider("Размер, %:", v, 'speedScale', 50, 200)
    fullWidthSlider("Положение X, % экрана:", v, 'speedXp', 0, 95)
    fullWidthSlider("Положение Y, % экрана:", v, 'speedYp', 0, 95)
    fullWidthSlider("Поправка скорости, %:", v, 'speedCalib', 50, 200)
    imgui.TextWrapped("Сверьте цифру с родным спидометром и подстройте поправку. Топливо показать нельзя: его считает сервер.")

    sep()
    header("Свой прицел")
    checkbox("Показывать прицел##vcr", v, 'crossOn')
    checkbox("Только с оружием в руках##vco", v, 'crossOnlyArmed')
    checkbox("Точка в центре##vcd", v, 'crossDot')
    fullWidthSlider("Длина линий:", v, 'crossSize', 1, 60)
    fullWidthSlider("Зазор в центре:", v, 'crossGap', 0, 30)
    fullWidthSlider("Толщина:", v, 'crossThick', 1, 6)
    fullWidthSlider("Положение X, % экрана (50 = центр):", v, 'crossXp', 0, 100)
    fullWidthSlider("Положение Y, % экрана (50 = центр):", v, 'crossYp', 0, 100)
    if imgui.Button("Вернуть в центр##crosscenter", imgui.ImVec2(-1, 34)) then
        v.crossXp, v.crossYp = 50, 50
        markDirty()
    end
    imgui.Text("Цвет прицела:")
    imgui.PushItemWidth(-1)
    if imgui.ColorEdit3("##crosscolor", uiCross) then
        v.crossColor = {uiCross[0], uiCross[1], uiCross[2]}
        markDirty()
    end
    imgui.PopItemWidth()
    imgui.TextWrapped("Пока меню открыто, прицел виден всегда, чтобы вы могли его подвинуть. В режиме от третьего лица точка попадания игры может не совпадать с центром экрана.")

    sep()
    header("Тонировка экрана")
    checkbox("Включить тонировку##vtn", v, 'tintOn')
    for i, t in ipairs(TINTS) do
        if i > 1 then imgui.SameLine() end
        if imgui.Button(t[1] .. "##tint" .. i) then
            v.tintColor = {t[2][1], t[2][2], t[2][3]}
            v.tintAlpha, v.brightness, v.vignette = t[3], t[4], t[5]
            v.tintOn = true
            uiTint[0], uiTint[1], uiTint[2] = t[2][1], t[2][2], t[2][3]
            markDirty()
        end
    end
    imgui.SameLine()
    if imgui.Button("Сброс##tintoff") then
        v.tintOn, v.tintAlpha, v.brightness, v.vignette = false, 0, 0, 0
        markDirty()
    end
    imgui.Text("Цвет тонировки:")
    imgui.PushItemWidth(-1)
    if imgui.ColorEdit3("##tintcolor", uiTint) then
        v.tintColor = {uiTint[0], uiTint[1], uiTint[2]}
        markDirty()
    end
    imgui.PopItemWidth()
    fullWidthSlider("Сила тонировки, %:", v, 'tintAlpha', 0, 60)
    fullWidthSlider("Яркость (минус темнее, плюс светлее):", v, 'brightness', -50, 50)
    fullWidthSlider("Затемнение по краям (виньетка), %:", v, 'vignette', 0, 80)
    imgui.TextWrapped("Это цветная плёнка поверх картинки, а не настоящая цветокоррекция. Дальность прорисовки и резкость скриптом изменить нельзя.")

    if viewError ~= "" then
        imgui.TextColored(imgui.ImVec4(1, 0.4, 0.4, 1), "Ошибка: " .. viewError)
    end
    sep()
end

function T.drawViewTab()
    drawViewSections()
    drawThemeSection()
end

function T.drawLoginTab()
    local L = cfg.login

    header("Автореконнект")
    checkbox("Переподключаться при потере соединения##rc", L, 'reconnect')
    fullWidthSlider("Ждать перед попыткой, сек:", L, 'rcDelay', 3, 60)
    fullWidthSlider("Сколько попыток подряд:", L, 'rcMax', 1, 30)
    if imgui.Button("Переподключиться сейчас##rcnow", imgui.ImVec2(-1, 36)) then
        net.userQuit = false
        if startReconnect() then chat("Переподключаюсь к " .. tostring(net.ip) .. ":" .. tostring(net.port)) end
    end
    plainText("Сервер: " .. (net.ip and (net.ip .. ":" .. tostring(net.port)) or "пока не запомнен (запомню после входа в игру)"))
    plainText("Состояние: " .. net.status)
    plainText("Код соединения: " .. (net.state ~= nil and tostring(net.state) or "недоступен")
        .. (net.okState ~= nil and (", в игре было: " .. tostring(net.okState)) or ""))
    imgui.TextWrapped("Скрипт запоминает состояние соединения, пока вы в игре. Если оно меняется и не возвращается за заданное время, он переподключается к тому же серверу. Если выходите из игры сами, выключите автореконнект командой /rc: скрипт не отличает ваш выход от обрыва.")

    sep()
    header("Автовход")
    checkbox("Вводить пароль автоматически##al", L, 'autologin')
    imgui.Text("Пароль:")
    imgui.PushItemWidth(-1)
    local pwFlags = 0
    if not showPw[0] and imgui.InputTextFlags and imgui.InputTextFlags.Password then
        pwFlags = imgui.InputTextFlags.Password
    end
    if imgui.InputText("##alpw", pwBuf, ffi.sizeof(pwBuf), pwFlags) then
        L.password = (ffi.string(pwBuf):gsub("[\r\n]", ""))
        markDirty()
    end
    imgui.PopItemWidth()
    imgui.Checkbox("Показать пароль##alshow", showPw)

    imgui.Text("Слова окна входа (через запятую):")
    imgui.PushItemWidth(-1)
    if imgui.InputText("##aldw", dlgBuf, ffi.sizeof(dlgBuf)) then
        L.dialogWords = ffi.string(dlgBuf)
        markDirty()
    end
    imgui.Text("Не вводить, если есть слова:")
    if imgui.InputText("##alsw", skipBuf, ffi.sizeof(skipBuf)) then
        L.skipWords = ffi.string(skipBuf)
        markDirty()
    end
    imgui.PopItemWidth()
    checkbox("Разрешить и для обычного поля ввода (не только для пароля)##alin", L, 'allowInput')

    plainText("Состояние: " .. auth.status)
    if auth.lastDialog then
        plainText(string.format("Последний диалог: id %s, стиль %s, заголовок: %s",
            tostring(auth.lastDialog.id), tostring(auth.lastDialog.style), auth.lastDialog.title))
    else
        plainText("Последний диалог: пока не было")
    end
    if imgui.Button("Сбросить счётчик попыток входа##alreset", imgui.ImVec2(-1, 34)) then
        auth.sent, auth.lastId, auth.lastTitle = 0, nil, nil
        auth.status = "счётчик сброшен"
    end
    imgui.TextWrapped("Пароль вводится только в окно со стилем «пароль» и ключевыми словами, до входа в игру, не более 2 раз. Если окно входа у Родины другое, посмотрите строку «Последний диалог» при входе и подберите слова.")
    imgui.TextWrapped("Внимание: пароль хранится в config/rodina_hub.json открытым текстом. Не отправляйте этот файл другим людям.")

    sep()
    X.drawAccounts()
end

-- ---------- вкладки 1.1 ----------

ui11.hlCol = imgui.new.float[3](cfg.chatf.hlColor[1], cfg.chatf.hlColor[2], cfg.chatf.hlColor[3])
ui11.markNew = imgui.new.char[42]()

-- строки чата с кнопками: actions = {{подпись, функция(текст)}, ...}
local function drawRecent(idp, actions)
    local list = chatf.recent
    if #list == 0 then
        imgui.TextWrapped("Пока нет строк: они появятся, как только в чат придёт сообщение.")
        return
    end
    for i = 1, math.min(#list, 8) do
        plainText(list[i].t .. "  " .. list[i].text)
        for j, a in ipairs(actions) do
            if j > 1 then imgui.SameLine() end
            if imgui.Button(a[1] .. "##" .. idp .. i .. "_" .. j, imgui.ImVec2(0, 30)) then a[2](list[i].text) end
        end
        imgui.Dummy(imgui.ImVec2(0, 2))
    end
end

-- ---------- Кнопки ----------

function T.drawButtonsTab()
    local B = cfg.btn
    header("Свои кнопки-команды")
    imgui.TextWrapped("Каждая кнопка отправляет одну команду или одну строку в чат, например /time. Серий и повторов нет.")
    checkbox("Показывать панель кнопок на экране##btnon", B, 'on')
    fullWidthSlider("Размер, %:", B, 'scale', 50, 250)
    fullWidthSlider("Прозрачность фона, %:", B, 'alpha', 0, 100)
    fullWidthSlider("Кнопок в ряду:", B, 'cols', 1, 4)
    if fullWidthSlider("Позиция X, %:", B, 'xp', 0, 100) then movePending.btn = true end
    if fullWidthSlider("Позиция Y, %:", B, 'yp', 0, 100) then movePending.btn = true end
    imgui.TextWrapped("Панель можно перетащить пальцем: новое место запомнится.")

    sep()
    header("Список кнопок (до 12)")
    if #B.list == 0 then imgui.TextWrapped("Пока пусто. Нажмите «Новая» и заполните поля ниже.") end
    for i, b in ipairs(B.list) do
        local title = ((b.name ~= "" and b.name or "Без названия") .. "  " .. b.cmd):gsub("#", "")
        if imgui.RadioButtonBool(title .. "##btn" .. i, ui11.btnSel == i) then
            ui11.btnSel = i
            loadBtnToBuf()
        end
    end

    if #B.list < 12 and imgui.Button("Новая##btnadd", imgui.ImVec2(0, 34)) then
        table.insert(B.list, {name = "Кнопка", cmd = ""})
        ui11.btnSel = #B.list
        loadBtnToBuf()
        markDirty()
    end

    local b = B.list[ui11.btnSel]
    if b then
        sep()
        imgui.Text("Название на кнопке:")
        imgui.PushItemWidth(-1)
        if imgui.InputText("##btnname", ui11.btnName, ffi.sizeof(ui11.btnName)) then
            b.name = ffi.string(ui11.btnName)
            markDirty()
        end
        imgui.Text("Команда (с символом / в начале):")
        if imgui.InputText("##btncmd", ui11.btnCmd, ffi.sizeof(ui11.btnCmd)) then
            b.cmd = ffi.string(ui11.btnCmd)
            markDirty()
        end
        imgui.PopItemWidth()

        if imgui.Button("Нажать для проверки##btntest", imgui.ImVec2(0, 34)) then
            local ok, err = btns.send(b.cmd)
            btns.status = ok and "Отправлено" or ("Не отправлено: " .. tostring(err))
        end
        imgui.SameLine()
        if imgui.Button("Вверх##btnup", imgui.ImVec2(0, 34)) and B.list[ui11.btnSel - 1] then
            local i = ui11.btnSel
            B.list[i], B.list[i - 1] = B.list[i - 1], B.list[i]
            ui11.btnSel = i - 1
            markDirty()
        end
        imgui.SameLine()
        if imgui.Button("Вниз##btndn", imgui.ImVec2(0, 34)) and B.list[ui11.btnSel + 1] then
            local i = ui11.btnSel
            B.list[i], B.list[i + 1] = B.list[i + 1], B.list[i]
            ui11.btnSel = i + 1
            markDirty()
        end
        imgui.SameLine()
        if imgui.Button("Удалить##btndel", imgui.ImVec2(0, 34)) then
            table.remove(B.list, ui11.btnSel)
            ui11.btnSel = math.max(1, math.min(ui11.btnSel, #B.list))
            loadBtnToBuf()
            markDirty()
        end
        if btns.status ~= "" then plainText("Состояние: " .. btns.status) end
    end
end

-- ---------- Чат ----------

local function addHideWord(line)
    local F = cfg.chatf
    local w = cleanStr(line, 40)
    w = w:gsub("[,;]", " ")
    if w == "" then return end
    local new = F.hide == "" and w or (F.hide .. ", " .. w)
    if #new > 255 then
        chat("Список скрытия переполнен: удалите лишнее")
        return
    end
    F.hide = new
    setBuf(ui11.hide, new)
    markDirty()
end

function T.drawChatTab()
    local F = cfg.chatf
    header("Фильтр чата")
    imgui.TextWrapped("Скрывает строки с заданными словами и подсвечивает строки с вашим ником. Видит обычные сообщения сервера в чат. То, что Родина показывает своими окнами и уведомлениями, фильтр не трогает.")
    checkbox("Включить фильтр##cfon", F, 'enabled')

    sep()
    imgui.Text("Скрывать строки со словами (через запятую):")
    imgui.PushItemWidth(-1)
    if imgui.InputText("##cfhide", ui11.hide, ffi.sizeof(ui11.hide)) then
        F.hide = ffi.string(ui11.hide)
        markDirty()
    end
    imgui.PopItemWidth()
    checkbox("Никогда не скрывать строки с моим ником##cfprot", F, 'protectNick')

    sep()
    checkbox("Подсвечивать строки с моим ником##cfhn", F, 'hlNick')
    imgui.Text("И ещё подсвечивать слова (через запятую):")
    imgui.PushItemWidth(-1)
    if imgui.InputText("##cfhl", ui11.hl, ffi.sizeof(ui11.hl)) then
        F.hlWords = ffi.string(ui11.hl)
        markDirty()
    end
    local hc = ui11.hlCol
    hc[0], hc[1], hc[2] = F.hlColor[1], F.hlColor[2], F.hlColor[3]
    if imgui.ColorEdit3("##cfcol", hc) then
        F.hlColor = {hc[0], hc[1], hc[2]}
        markDirty()
    end
    imgui.PopItemWidth()

    sep()
    header("Что сделал фильтр")
    plainText(string.format("Скрыто за сессию: %d. Подсвечено: %d.", chatf.hiddenN, chatf.hlN))
    if chatf.err ~= "" then plainText("Ошибка фильтра: " .. chatf.err) end
    if imgui.Button("Сбросить счётчики и список##cfreset", imgui.ImVec2(-1, 32)) then
        chatf.hiddenN, chatf.hlN, chatf.hidden, chatf.err = 0, 0, {}, ""
    end
    if #chatf.hidden == 0 then
        imgui.TextWrapped("Скрытых строк пока нет. Когда фильтр что-то скроет, строка появится здесь: можно проверить, что не пропало лишнее.")
    else
        imgui.Text("Последние скрытые строки:")
        for _, r in ipairs(chatf.hidden) do plainText(r.t .. "  " .. r.text) end
    end

    sep()
    header("Последние строки чата")
    imgui.TextWrapped("Кнопка добавляет строку в список скрытия. Потом оставьте в поле только нужное слово.")
    drawRecent("cfr", {{"В список скрытия", addHideWord}})

    sep()
    X.drawAlertSection()
end

-- ---------- Метки ----------

function T.drawMarksTab()
    local M = cfg.marks
    header("Метки мест")
    imgui.TextWrapped("Сохраните место, где стоите, и выберите его целью: на экране появятся стрелка и расстояние. Это только ваши точки, ничего в мире скрипт не ищет. Метка в другом интерьере показывает только название.")
    checkbox("Показывать стрелку и расстояние##mkon", M, 'on')
    checkbox("Снимать цель, когда пришли##mkclr", M, 'autoClear')
    fullWidthSlider("Пришли, если ближе, м:", M, 'arrive', 3, 200)
    fullWidthSlider("Размер, %:", M, 'scale', 50, 300)
    fullWidthSlider("Прозрачность фона, %:", M, 'alpha', 0, 100)
    fullWidthSlider("Позиция X, %:", M, 'xp', 0, 100)
    fullWidthSlider("Позиция Y, %:", M, 'yp', 0, 100)

    sep()
    header("Новая метка")
    imgui.PushItemWidth(-1)
    imgui.InputText("##mknew", ui11.markNew, ffi.sizeof(ui11.markNew))
    imgui.PopItemWidth()
    if imgui.Button("Сохранить мою позицию##mkadd", imgui.ImVec2(-1, 36)) then
        local i, err = marks.add(ffi.string(ui11.markNew))
        if i then
            ffi.fill(ui11.markNew, ffi.sizeof(ui11.markNew))
            ui11.markSel = i
            loadMarkToBuf()
            chat("Метка сохранена: " .. M.list[i].name)
        else
            chat("Не удалось сохранить метку: " .. tostring(err))
        end
    end

    sep()
    header("Мои метки (до 40)")
    if #M.list == 0 then imgui.TextWrapped("Пока пусто.") end
    local mx, my, mz = myPos()
    local here = curInterior()
    for i, m in ipairs(M.list) do
        local d = ""
        if finite(mx) then
            d = (m.int ~= here) and "  (другой интерьер)" or ("  " .. fmtDist(dist3(mx, my, mz, m.x, m.y, m.z)))
        end
        local name = (m.name ~= "" and m.name or "Без названия"):gsub("#", "")
        local title = string.format("%d. %s%s%s", i, name, d, M.target == i and "  <- цель" or "")
        if imgui.RadioButtonBool(title .. "##mk" .. i, ui11.markSel == i) then
            ui11.markSel = i
            loadMarkToBuf()
        end
    end

    local sel = M.list[ui11.markSel]
    if sel then
        sep()
        if imgui.Button("Вести к метке##mkgo", imgui.ImVec2(0, 34)) then marks.setTarget(ui11.markSel) end
        imgui.SameLine()
        if imgui.Button("Сбросить цель##mkstop", imgui.ImVec2(0, 34)) then marks.setTarget(0) end
        imgui.SameLine()
        if imgui.Button("Удалить##mkdel", imgui.ImVec2(0, 34)) then
            marks.remove(ui11.markSel)
            ui11.markSel = math.min(ui11.markSel, #M.list)
            loadMarkToBuf()
        end
        imgui.Text("Название выбранной метки:")
        imgui.PushItemWidth(-1)
        if imgui.InputText("##mkname", ui11.markName, ffi.sizeof(ui11.markName)) then
            local cur = M.list[ui11.markSel]
            if cur then
                cur.name = ffi.string(ui11.markName)
                markDirty()
            end
        end
        imgui.PopItemWidth()
    end
    if M.target > 0 and not M.on then
        imgui.TextWrapped("Цель выбрана, но показ стрелки выключен: включите его в начале вкладки.")
    end
end

-- ---------- Маска ----------

function T.drawMaskTab()
    local M = cfg.mask
    header("Таймер маски")
    local phase, left = mask.phase(os.time())
    if phase == 'active' then
        plainText("Маска идёт, осталось: " .. fmtClock(left))
    elseif phase == 'cooldown' then
        plainText("Пауза после маски, можно снова через: " .. fmtClock(left))
    else
        plainText("Таймер не запущен")
    end
    if imgui.Button("Запустить на " .. M.minutes .. " мин##mkstart", imgui.ImVec2(-1, 38)) then mask.start() end
    if imgui.Button("Сбросить таймер##mkreset", imgui.ImVec2(-1, 34)) then
        if not mask.stop() then chat("Таймер маски не запущен") end
    end
    fullWidthSlider("Сколько действует маска, мин:", M, 'minutes', 1, 180)
    fullWidthSlider("Предупредить за, мин (0 = не надо):", M, 'warn', 0, 60)
    fullWidthSlider("Пауза после маски, мин (0 = нет):", M, 'cooldown', 0, 240)
    imgui.TextWrapped("Скрипт не знает, сколько маска действует на Родине: поставьте своё время. Таймер считает по часам телефона и переживает перезапуск скрипта. Команда: /maskt.")

    sep()
    header("Запуск по фразе из чата")
    checkbox("Запускать и сбрасывать таймер по фразам##mkauto", M, 'auto')
    imgui.Text("Фраза, когда надели маску:")
    imgui.PushItemWidth(-1)
    if imgui.InputText("##mktrig", ui11.trig, ffi.sizeof(ui11.trig)) then
        M.trigger = ffi.string(ui11.trig)
        markDirty()
    end
    imgui.Text("Фраза, когда сняли маску (можно пустой):")
    if imgui.InputText("##mktrig2", ui11.trig2, ffi.sizeof(ui11.trig2)) then
        M.stopTrigger = ffi.string(ui11.trig2)
        markDirty()
    end
    imgui.PopItemWidth()
    imgui.TextWrapped("Подойдёт любая часть строки. Выбирайте строку, которую сервер пишет только вам: чужие сообщения со словами из фразы тоже запустят таймер. Пока маска идёт, повторный запуск по фразе игнорируется.")
    imgui.Text("Наденьте маску и выберите её строку из последних:")
    drawRecent("mkr", {
        {"Это запуск", function(text)
            M.trigger = cleanStr(text, 100)
            setBuf(ui11.trig, M.trigger)
            markDirty()
        end},
        {"Это снятие", function(text)
            M.stopTrigger = cleanStr(text, 100)
            setBuf(ui11.trig2, M.stopTrigger)
            markDirty()
        end},
    })

    sep()
    header("Вид таймера на экране")
    checkbox("Показывать таймер на экране##mkshow", M, 'show')
    checkbox("Показывать, даже когда таймер не идёт##mkidle", M, 'showIdle')
    fullWidthSlider("Размер, %:", M, 'scale', 50, 300)
    fullWidthSlider("Прозрачность фона, %:", M, 'alpha', 0, 100)
    fullWidthSlider("Позиция X, %:", M, 'xp', 0, 100)
    fullWidthSlider("Позиция Y, %:", M, 'yp', 0, 100)
end

-- ---------- Обмен ----------

function T.drawShareTab()
    header("Обмен настройками")
    imgui.TextWrapped("Соберите код и отправьте его в Telegram или выложите на arzmods. Пароли автовхода и аккаунтов, заметки, метки, запущенные таймеры и журнал в код не входят.")
    imgui.Text("Что включить в код:")
    for _, sec in ipairs(SHARE_SECTIONS) do
        checkbox(sec.label .. "##shi" .. sec.key, share.inc, sec.key)
    end
    if imgui.Button("Создать код##shbuild", imgui.ImVec2(-1, 36)) then
        local code, err = share.build()
        if code then
            share.code = code
            setBuf(ui11.exportBuf, code)
            share.msg = "Код создан, символов: " .. #code
        else
            share.code = ""
            setBuf(ui11.exportBuf, "")
            share.msg = err
        end
    end
    if share.code ~= "" then
        local ro = (imgui.InputTextFlags and imgui.InputTextFlags.ReadOnly) or 0
        imgui.InputTextMultiline("##shexp", ui11.exportBuf, ffi.sizeof(ui11.exportBuf), imgui.ImVec2(-1, 100), ro)
        if imgui.Button("Копировать в буфер##shcopy", imgui.ImVec2(0, 34)) then
            local ok = pcall(imgui.SetClipboardText, share.code)
            share.msg = ok and "Код скопирован в буфер обмена" or "Не удалось скопировать: сохраните в файл"
        end
        imgui.SameLine()
        if imgui.Button("Сохранить в файл##shsave", imgui.ImVec2(0, 34)) then
            share.msg = share.saveFile(share.code) and "Сохранено: config/rodina_hub_export.txt"
                or "Не удалось записать файл"
        end
    end
    if share.msg ~= "" then plainText(share.msg) end

    sep()
    header("Загрузить чужой код")
    imgui.InputTextMultiline("##shimp", ui11.importBuf, ffi.sizeof(ui11.importBuf), imgui.ImVec2(-1, 100))
    if imgui.Button("Вставить из буфера##shpaste", imgui.ImVec2(0, 34)) then
        setBuf(ui11.importBuf, clipboardGet():sub(1, 16000))
        share.check()
    end
    imgui.SameLine()
    if imgui.Button("Прочитать из файла##shfile", imgui.ImVec2(0, 34)) then
        local t = share.readFile()
        if t then
            setBuf(ui11.importBuf, t)
            share.check()
        else
            share.preview = nil
            share.msg = "Файл config/rodina_hub_import.txt не найден"
        end
    end
    imgui.SameLine()
    if imgui.Button("Проверить##shcheck", imgui.ImVec2(0, 34)) then share.check() end

    if share.preview then
        imgui.Text("В коде есть:")
        for _, line in ipairs(share.preview.lines) do plainText("- " .. line) end
        imgui.TextWrapped("Применение заменит ваши текущие настройки этих разделов. Профили добавятся к вашим.")
        if imgui.Button("Применить##shapply", imgui.ImVec2(0, 36)) then
            local done = share.apply(share.preview.payload)
            share.preview = nil
            share.msg = "Применено разделов: " .. #done
            chat("Настройки из кода применены, разделов: " .. #done)
        end
        imgui.SameLine()
        if imgui.Button("Отмена##shcancel", imgui.ImVec2(0, 36)) then
            share.preview = nil
            share.msg = "Отменено"
        end
    end
end

-- =========================================================
-- МОДУЛИ 1.2: ЖУРНАЛ, УВЕДОМЛЕНИЯ, ТАЙМЕРЫ, ШАБЛОНЫ, ГРАФИК, ДОХОД, АККАУНТЫ
-- Каждый модуль в своём блоке do ... end: наружу выходят только поля X и T.
-- =========================================================

-- ---------- журнал чата и история окон сервера ----------
do
    local MAXLOG, MAXDLG = 300, 20
    local log = {list = {}, status = "", q = ""}
    local dlg = {list = {}, sel = 0, status = ""}
    X.log, X.dlg = log, dlg
    local qBuf = imgui.new.char[64]()

    table.insert(X.chatSinks, function(plain, low, hidden)
        if not cfg.log.enabled then return end
        local L = log.list
        L[#L + 1] = {t = os.date("%H:%M:%S"), text = cutUtf8(plain, 220), low = cutUtf8(low, 220), hid = hidden or false}
        if #L > MAXLOG then table.remove(L, 1) end
    end)

    table.insert(X.dialogSinks, function(id, style, title, text)
        if not cfg.dlg.enabled or style == 3 then return end   -- окна с вводом пароля не храним
        local ttl = (title:gsub("{%x%x%x%x%x%x}", ""))
        local body = cutUtf8((text:gsub("{%x%x%x%x%x%x}", "")), 2000)
        local top = dlg.list[1]
        if top and top.id == id and top.title == cutUtf8(ttl, 80) and top.text == body then return end
        table.insert(dlg.list, 1, {t = os.date("%H:%M:%S"), id = id, style = style, title = cutUtf8(ttl, 80), text = body})
        while #dlg.list > MAXDLG do table.remove(dlg.list) end
        if dlg.sel > 0 then dlg.sel = dlg.sel + 1 end
        if dlg.sel > #dlg.list then dlg.sel = 0 end
    end)

    local function matches()
        local q = lowerRu(cleanStr(log.q, 64))
        local out = {}
        for i = #log.list, 1, -1 do
            local e = log.list[i]
            if q == "" or e.low:find(q, 1, true) then out[#out + 1] = e end
        end
        return out
    end

    -- строки от старых к новым в текстовый файл; возвращает путь или nil
    local function saveLines(newestFirst)
        if not doesDirectoryExist(configDir) then createDirectory(configDir) end
        local path = string.format("%s/rodina_chatlog_%s.txt", configDir, os.date("%Y%m%d_%H%M%S"))
        local f = io.open(path, 'w')
        if not f then return nil end
        for i = #newestFirst, 1, -1 do
            local e = newestFirst[i]
            f:write("[", e.t, "] ", e.text, e.hid and "  [скрыто фильтром]" or "", "\n")
        end
        f:close()
        return path
    end

    local function reportSave(lines)
        if #lines == 0 then
            log.status = "Нечего сохранять"
            return
        end
        local path = saveLines(lines)
        log.status = path and string.format("Сохранено строк: %d, файл %s", #lines, path:match("[^/\\]+$"))
            or "Не удалось записать файл"
    end

    function T.drawLogTab()
        header("Журнал чата")
        imgui.TextWrapped("Хранит последние 300 строк, которые сервер прислал в чат. Помогает найти пропущенное сообщение или сохранить строки как доказательство для жалобы. Журнал лежит в памяти и пропадает при перезапуске скрипта, если не сохранить его в файл (папка config).")
        checkbox("Записывать чат в журнал##lgon", cfg.log, 'enabled')
        imgui.Text("Поиск по журналу:")
        imgui.PushItemWidth(-1)
        if imgui.InputText("##lgq", qBuf, ffi.sizeof(qBuf)) then log.q = ffi.string(qBuf) end
        imgui.PopItemWidth()
        local found = matches()
        plainText(string.format("Строк в журнале: %d. Найдено: %d.", #log.list, #found))
        if imgui.Button("Сохранить всё##lgall", imgui.ImVec2(0, 34)) then
            local all = {}
            for i = #log.list, 1, -1 do all[#all + 1] = log.list[i] end
            reportSave(all)
        end
        imgui.SameLine()
        if imgui.Button("Сохранить найденное##lgfound", imgui.ImVec2(0, 34)) then reportSave(found) end
        imgui.SameLine()
        if imgui.Button("Очистить##lgclear", imgui.ImVec2(0, 34)) then
            log.list = {}
            log.status = "Журнал очищен"
        end
        if log.status ~= "" then plainText(log.status) end

        sep()
        if #found == 0 then imgui.TextWrapped("Ничего нет. Журнал наполняется по мере прихода сообщений.") end
        for i = 1, math.min(#found, 50) do
            local e = found[i]
            plainText(e.t .. "  " .. e.text .. (e.hid and "  [скрыто фильтром]" or ""))
        end
        if #found > 50 then
            plainText(string.format("... и ещё %d строк. Уточните поиск или сохраните в файл.", #found - 50))
        end

        sep()
        header("Окна сервера (последние 20)")
        imgui.TextWrapped("Тексты диалогов, которые показал сервер (банк, магазины, списки). Можно перечитать окно, которое уже закрыли. Вводимые вами ответы и пароли здесь не хранятся.")
        checkbox("Запоминать окна сервера##dgon", cfg.dlg, 'enabled')
        if #dlg.list == 0 then imgui.TextWrapped("Пока пусто.") end
        for i, d in ipairs(dlg.list) do
            local title = ((d.t .. "  " .. (d.title ~= "" and d.title or "без заголовка")):gsub("#", ""))
            if imgui.RadioButtonBool(title .. "##dg" .. i, dlg.sel == i) then dlg.sel = i end
        end
        local d = dlg.list[dlg.sel]
        if d then
            sep()
            plainText(d.text ~= "" and d.text or "(в окне нет текста)")
            if imgui.Button("Копировать текст##dgcopy", imgui.ImVec2(0, 34)) then
                dlg.status = pcall(imgui.SetClipboardText, d.text) and "Текст скопирован" or "Не удалось скопировать"
            end
        end
        if #dlg.list > 0 then
            if imgui.Button("Очистить окна##dgclear", imgui.ImVec2(0, 34)) then
                dlg.list, dlg.sel, dlg.status = {}, 0, "Список очищен"
            end
        end
        if dlg.status ~= "" then plainText(dlg.status) end
    end
end

-- ---------- уведомления: мигающая рамка при упоминании ----------
do
    local alert = {untilT = 0, text = ""}
    X.alert = alert
    local wordsBuf = imgui.new.char[256]()
    X.ui.alertCol = imgui.new.float[3](1.0, 0.3, 0.3)

    -- запустить рамку и надпись; text пустой = только рамка
    function X.flash(text, seconds)
        alert.untilT = os.clock() + (seconds or cfg.alert.seconds)
        alert.text = cutUtf8(tostring(text or ""), 100)
    end

    -- строка самого игрока: его ник в начале и двоеточие сразу после ника
    local function isOwnLine(low, pats)
        for _, p in ipairs(pats) do
            local s, e = low:find(p, 1, true)
            if s and s <= 16 and not low:sub(1, s - 1):find(":", 1, true)
                and low:sub(e + 1, e + 8):find(":", 1, true) then return true end
        end
        return false
    end

    table.insert(X.chatSinks, function(plain, low, hidden)
        local A = cfg.alert
        if not A.enabled or hidden then return end
        local hit = false
        if A.nick then
            local pats = nickPatterns()
            if #pats > 0 and hasAny(low, pats) and not (A.ignoreOwn and isOwnLine(low, pats)) then hit = true end
        end
        if not hit and hasAny(low, cachedWords('alert', A.words)) then hit = true end
        if hit then X.flash(plain, A.seconds) end
    end)

    function X.refreshAlert() setBuf(wordsBuf, cfg.alert.words) end
    X.refreshAlert()
    X.refreshers[#X.refreshers + 1] = X.refreshAlert

    local function addAlertWord(line)
        local A = cfg.alert
        local w = cleanStr(line, 40)
        w = w:gsub("[,;]", " ")
        if w == "" then return end
        local new = A.words == "" and w or (A.words .. ", " .. w)
        if #new > 255 then
            chat("Список уведомлений переполнен: удалите лишнее")
            return
        end
        A.words = new
        setBuf(wordsBuf, new)
        markDirty()
    end

    function X.drawAlertSection()
        local A = cfg.alert
        header("Уведомление о важной строке")
        imgui.TextWrapped("Когда в чате появляется ваш ник или заданное слово, по краям экрана мигает рамка, а сверху показывается строка. Скрытые фильтром строки уведомление не вызывают.")
        imgui.TextWrapped("Чтобы ловить личные сообщения, добавьте в слова то, чем они начинаются в вашем чате: возьмите такую строку из списка внизу.")
        checkbox("Включить уведомление##alon", A, 'enabled')
        checkbox("Реагировать на мой ник##alnick", A, 'nick')
        checkbox("Не реагировать на мои собственные реплики##alown", A, 'ignoreOwn')
        imgui.Text("И на слова (через запятую):")
        imgui.PushItemWidth(-1)
        if imgui.InputText("##alwords", wordsBuf, ffi.sizeof(wordsBuf)) then
            A.words = ffi.string(wordsBuf)
            markDirty()
        end
        local ac = X.ui.alertCol
        ac[0], ac[1], ac[2] = A.color[1], A.color[2], A.color[3]
        if imgui.ColorEdit3("##alcol", ac) then
            A.color = {ac[0], ac[1], ac[2]}
            markDirty()
        end
        imgui.PopItemWidth()
        checkbox("Показывать строку сверху##albanner", A, 'banner')
        fullWidthSlider("Сколько секунд мигает:", A, 'seconds', 1, 10)
        fullWidthSlider("Толщина рамки:", A, 'thick', 2, 40)
        if imgui.Button("Проверить уведомление##altest", imgui.ImVec2(-1, 34)) then
            X.flash("Так выглядит уведомление", A.seconds)
        end
        imgui.Text("Последние строки чата (кнопка добавляет строку в слова):")
        drawRecent("alr", {{"В уведомления", addAlertWord}})
    end
end

-- ---------- свои таймеры ----------
do
    local tm = {}
    X.timers = tm
    local rt = setmetatable({}, {__mode = 'k'})   -- служебное состояние таймера, в конфиг не пишется
    local selT = 1
    local nameBuf = imgui.new.char[26]()

    local function st(t)
        local s = rt[t]
        if not s then
            s = {warned = false, total = nil}
            rt[t] = s
        end
        return s
    end

    function tm.running()
        local n, now = 0, os.time()
        for _, t in ipairs(cfg.timers.list) do
            if t.endAt > now then n = n + 1 end
        end
        return n
    end

    function tm.start(t, minutes)
        minutes = ci(minutes, 1, 720, t.minutes)
        local s = st(t)
        t.endAt = os.time() + minutes * 60
        s.total = minutes * 60
        s.warned = t.warn * 60 >= s.total
        markDirty()
        chat(string.format("Таймер «%s»: запущен на %d мин", t.name, minutes))
    end

    function tm.stop(t)
        local was = t.endAt > os.time()
        t.endAt = 0
        st(t).total = nil
        markDirty()
        return was
    end

    function tm.total(t, left)
        local s = st(t)
        if not s.total or s.total < left then s.total = math.max(t.minutes * 60, left) end
        return s.total
    end

    function tm.tick()
        local now = os.time()
        for _, t in ipairs(cfg.timers.list) do
            if t.endAt > 0 then
                local left = t.endAt - now
                local s = st(t)
                if left > 0 then
                    if not s.warned and t.warn > 0 and left <= t.warn * 60 then
                        s.warned = true
                        chat(string.format("{FFAA00}Таймер «%s»: осталось около %d мин", t.name, math.max(1, math.ceil(left / 60))))
                    end
                else
                    t.endAt = 0
                    s.total = nil
                    markDirty()
                    chat("{FF4444}Таймер «" .. t.name .. "»: время вышло")
                    X.flash("Таймер: " .. t.name, 4)
                end
            end
        end
    end

    local function loadT()
        local t = cfg.timers.list[selT]
        setBuf(nameBuf, t and t.name or "")
    end
    function X.refreshTimers()
        selT = math.max(1, math.min(selT, math.max(#cfg.timers.list, 1)))
        loadT()
    end
    X.refreshTimers()
    X.refreshers[#X.refreshers + 1] = X.refreshTimers

    -- по номеру или по части названия
    function tm.find(arg)
        local L = cfg.timers.list
        arg = cleanStr(arg or "", 40)
        if arg == "" then return nil end
        local n = tonumber(arg)
        if n and L[math.floor(n)] then return math.floor(n) end
        local q = lowerRu(arg)
        for i, t in ipairs(L) do
            if lowerRu(t.name):find(q, 1, true) then return i end
        end
        return nil
    end

    function T.drawTimersTab()
        local C = cfg.timers
        header("Свои таймеры")
        imgui.TextWrapped("До 8 именованных таймеров: зарплата, кулдаун, отдых. Считают по часам телефона и переживают перезапуск скрипта. Команда: /tmr [номер или название] [минуты], /tmr stop [номер].")
        checkbox("Показывать запущенные на экране##tmshow", C, 'show')
        fullWidthSlider("Размер, %:", C, 'scale', 50, 300)
        fullWidthSlider("Прозрачность фона, %:", C, 'alpha', 0, 100)
        fullWidthSlider("Позиция X, %:", C, 'xp', 0, 100)
        fullWidthSlider("Позиция Y, %:", C, 'yp', 0, 100)

        sep()
        header("Список (до 8)")
        local now = os.time()
        if #C.list == 0 then imgui.TextWrapped("Пока пусто. Нажмите «Новый».") end
        for i, t in ipairs(C.list) do
            local left = t.endAt - now
            local title = ((t.name .. (left > 0 and ("  " .. fmtClock(left)) or "")):gsub("#", ""))
            if imgui.RadioButtonBool(title .. "##tm" .. i, selT == i) then
                selT = i
                loadT()
            end
        end
        if #C.list < 8 and imgui.Button("Новый##tmadd", imgui.ImVec2(0, 34)) then
            table.insert(C.list, {name = "Таймер " .. (#C.list + 1), minutes = 15, warn = 1, endAt = 0})
            selT = #C.list
            loadT()
            markDirty()
        end

        local t = C.list[selT]
        if t then
            sep()
            imgui.Text("Название:")
            imgui.PushItemWidth(-1)
            if imgui.InputText("##tmname", nameBuf, ffi.sizeof(nameBuf)) then
                t.name = ffi.string(nameBuf)
                markDirty()
            end
            imgui.PopItemWidth()
            fullWidthSlider("Сколько минут:", t, 'minutes', 1, 720)
            fullWidthSlider("Предупредить за, мин (0 = нет):", t, 'warn', 0, 60)
            if imgui.Button("Запустить##tmstart", imgui.ImVec2(0, 36)) then tm.start(t) end
            imgui.SameLine()
            if imgui.Button("Сбросить##tmstop", imgui.ImVec2(0, 36)) then tm.stop(t) end
            imgui.SameLine()
            if imgui.Button("Удалить##tmdel", imgui.ImVec2(0, 36)) then
                table.remove(C.list, selT)
                selT = math.max(1, math.min(selT, #C.list))
                loadT()
                markDirty()
            end
        end
    end

    function X.regTimerCmd()
        sampRegisterChatCommand("tmr", function(arg)
            arg = toUtf(tostring(arg or ""))
            local L = cfg.timers.list
            local first, rest = arg:match("^%s*(%S*)%s*(.-)%s*$")
            local now = os.time()
            if first == "" then
                if #L == 0 then
                    chat("Таймеров нет. Создайте их: /hub, вкладка Таймеры")
                    return
                end
                for i, t in ipairs(L) do
                    local left = t.endAt - now
                    chat(string.format("%d. %s: %s", i, t.name, left > 0 and fmtClock(left) or "свободен"))
                end
                return
            end
            if first:lower() == "stop" then
                local i = tm.find(rest)
                if i and tm.stop(L[i]) then
                    chat("Таймер остановлен: " .. L[i].name)
                else
                    chat("Использование: /tmr stop [номер]; такой таймер не запущен")
                end
                return
            end
            local i = tm.find(first)
            if not i then
                chat("Таймер не найден. Список: /tmr")
                return
            end
            local mins = tonumber(rest)
            if mins and (mins < 1 or mins > 720) then
                chat("Минут может быть от 1 до 720")
                return
            end
            tm.start(L[i], mins)
        end)
    end
end

-- ---------- шаблоны текстов ----------
do
    local sel = 1
    local nameB, textB = imgui.new.char[26](), imgui.new.char[640]()
    local status = ""

    local function load()
        local t = cfg.tpl.list[sel]
        setBuf(nameB, t and t.name or "")
        setBuf(textB, t and t.text or "")
    end
    function X.refreshTpl()
        sel = math.max(1, math.min(sel, math.max(#cfg.tpl.list, 1)))
        load()
    end
    X.refreshTpl()
    X.refreshers[#X.refreshers + 1] = X.refreshTpl

    -- подставляет {nick}, {id}, {time}, {date}; незнакомые {слова} остаются как есть
    function X.tplFill(text)
        local vals = {
            nick = X.currentNick() or "?",
            id = myId >= 0 and tostring(myId) or "?",
            time = os.date("%H:%M"), date = os.date("%d.%m.%Y"),
        }
        return (text:gsub("{(%a+)}", function(k) return vals[k] end))
    end

    function T.drawTplTab()
        local L = cfg.tpl.list
        header("Шаблоны текстов")
        imgui.TextWrapped("Готовые тексты для жалоб, объявлений, ответов. В тексте можно писать {nick} (ваш ник), {id} (ваш ID), {time} (время), {date} (дата): они подставятся при копировании.")
        if #L == 0 then imgui.TextWrapped("Пока пусто. Нажмите «Новый».") end
        for i, t in ipairs(L) do
            local title = (t.name):gsub("#", "")
            if imgui.RadioButtonBool(title .. "##tp" .. i, sel == i) then
                sel = i
                load()
            end
        end
        if #L < 20 and imgui.Button("Новый##tpadd", imgui.ImVec2(0, 34)) then
            table.insert(L, {name = "Шаблон " .. (#L + 1), text = ""})
            sel = #L
            load()
            markDirty()
        end

        local t = L[sel]
        if t then
            sep()
            imgui.Text("Название:")
            imgui.PushItemWidth(-1)
            if imgui.InputText("##tpname", nameB, ffi.sizeof(nameB)) then
                t.name = ffi.string(nameB)
                markDirty()
            end
            imgui.Text("Текст:")
            if imgui.InputTextMultiline("##tptext", textB, ffi.sizeof(textB), imgui.ImVec2(-1, 130)) then
                t.text = X.cleanText(ffi.string(textB), 600)
                markDirty()
            end
            imgui.PopItemWidth()

            local filled = X.tplFill(t.text)
            imgui.Text("Так будет выглядеть:")
            plainText(filled ~= "" and filled or "(пусто)")

            if imgui.Button("Копировать##tpcopy", imgui.ImVec2(0, 36)) then
                status = pcall(imgui.SetClipboardText, filled) and "Скопировано в буфер обмена" or "Не удалось скопировать"
            end
            imgui.SameLine()
            if imgui.Button("Отправить в чат##tpsend", imgui.ImVec2(0, 36)) then
                if filled:find("\n", 1, true) then
                    status = "В несколько строк в чат не отправляю: скопируйте текст"
                else
                    local ok, err = btns.send(filled)
                    status = ok and "Отправлено" or ("Не отправлено: " .. tostring(err))
                end
            end
            imgui.SameLine()
            if imgui.Button("Удалить##tpdel", imgui.ImVec2(0, 36)) then
                table.remove(L, sel)
                sel = math.max(1, math.min(sel, #L))
                load()
                markDirty()
            end
            if status ~= "" then plainText(status) end
        end
    end
end

-- ---------- график FPS и пинга, доход за сессию ----------
do
    local MAXS = 300
    local g = {fps = {}, ping = {}, last = 0}
    X.graph = g

    function X.graphPush(fps)
        local ping = 0
        if myId >= 0 then
            local ok, p = pcall(sampGetPlayerPing, myId)
            if ok and type(p) == 'number' and p > 0 then ping = p end
        end
        g.fps[#g.fps + 1] = fps
        g.ping[#g.ping + 1] = ping
        if #g.fps > MAXS then
            table.remove(g.fps, 1)
            table.remove(g.ping, 1)
        end
    end

    local function summary(data)
        local n, lo, hi, sum = 0, nil, 0, 0
        for _, v in ipairs(data) do
            if v > 0 then
                n = n + 1
                sum = sum + v
                if not lo or v < lo then lo = v end
                if v > hi then hi = v end
            end
        end
        return n, lo or 0, n > 0 and sum / n or 0, hi
    end

    -- график ломаной; segColor(v) выбирает цвет отрезка по значению
    local function plot(data, hi, w, h, segColor, markLine)
        local dl = imgui.GetWindowDrawList()
        local p = imgui.GetCursorScreenPos()
        if not dl or not p then
            imgui.Dummy(imgui.ImVec2(w, h))
            return
        end
        dl:AddRectFilled(p, imgui.ImVec2(p.x + w, p.y + h), col(0, 0, 0, 0.35))
        if markLine then
            local y = p.y + h - h * math.min(markLine / hi, 1)
            dl:AddLine(imgui.ImVec2(p.x, y), imgui.ImVec2(p.x + w, y), col(1, 0.4, 0.3, 0.6), 1)
        end
        local n, px, py = #data, nil, nil
        for i = 1, n do
            local x = p.x + w * (i - 1) / math.max(n - 1, 1)
            local y = p.y + h - h * math.min(data[i] / hi, 1)
            if px then dl:AddLine(imgui.ImVec2(px, py), imgui.ImVec2(x, y), segColor(data[i]), 2) end
            px, py = x, y
        end
        imgui.Dummy(imgui.ImVec2(w, h))
    end

    local inc = {start = nil, last = nil, earned = 0, spent = 0, events = {}, avail = false, sec = 0, at = 0}
    X.income = inc

    function X.incomeReset()
        inc.start, inc.last, inc.earned, inc.spent, inc.events, inc.sec = nil, nil, 0, 0, {}, 0
        inc.avail = false
    end

    -- раз в секунду; баланс читаем только в игре
    function X.incomeTick()
        if not cfg.income.enabled then return end
        local now = os.clock()
        if now - inc.at < 1 then return end
        local dt = inc.at > 0 and math.min(now - inc.at, 5) or 0
        inc.at = now
        local okS, spawned = pcall(sampIsLocalPlayerSpawned)
        if not (okS and spawned) then
            inc.avail = false
            return
        end
        local m = readMoney()
        if not finite(m) then
            inc.avail = false
            return
        end
        inc.avail = true
        inc.sec = inc.sec + dt
        if not inc.start then
            inc.start, inc.last = m, m
            return
        end
        local d = m - inc.last
        if d ~= 0 then
            if d > 0 then inc.earned = inc.earned + d else inc.spent = inc.spent - d end
            table.insert(inc.events, 1, {t = os.date("%H:%M:%S"), d = d})
            if #inc.events > 15 then table.remove(inc.events) end
            inc.last = m
        end
    end

    function X.modTick()
        X.timers.tick()
        X.incomeTick()
    end

    function T.drawGraphTab()
        header("График FPS и пинга")
        checkbox("Записывать график (раз в секунду, последние 5 минут)##grn", cfg.graph, 'enabled')
        fullWidthSlider("Считать просадкой FPS ниже:", cfg.graph, 'lowFps', 10, 200)
        local avail = imgui.GetContentRegionAvail()
        local w = math.max(200, (avail and avail.x or 600) - 8)
        local fpsMax = 60
        for _, v in ipairs(g.fps) do if v > fpsMax then fpsMax = v end end
        fpsMax = math.ceil(fpsMax / 10) * 10
        local low = cfg.graph.lowFps

        imgui.Text("FPS")
        plot(g.fps, fpsMax, w, 110, function(v)
            return v < low and col(1.0, 0.35, 0.3, 1) or col(0.35, 0.9, 0.5, 1)
        end, low)
        local n, lo, av, hi = summary(g.fps)
        if n == 0 then
            imgui.TextWrapped("Данных пока нет: они появятся через несколько секунд.")
        else
            local dips = 0
            for _, v in ipairs(g.fps) do if v > 0 and v < low then dips = dips + 1 end end
            plainText(string.format("FPS: мин %d, средний %d, макс %d. Ниже %d: %d с из %d (%d%%).",
                math.floor(lo), math.floor(av), math.floor(hi), low, dips, n, math.floor(dips / n * 100 + 0.5)))
        end

        local pingMax = 100
        for _, v in ipairs(g.ping) do if v > pingMax then pingMax = v end end
        pingMax = math.ceil(pingMax / 50) * 50
        imgui.Text("Пинг")
        plot(g.ping, pingMax, w, 90, function() return col(0.45, 0.7, 1.0, 1) end, nil)
        local pn, plo, pav, phi = summary(g.ping)
        if pn > 0 then
            plainText(string.format("Пинг: мин %d, средний %d, макс %d.", math.floor(plo), math.floor(pav), math.floor(phi)))
        end
        if imgui.Button("Очистить график##grclear", imgui.ImVec2(-1, 34)) then
            g.fps, g.ping = {}, {}
        end

        sep()
        header("Доход за сессию")
        imgui.TextWrapped("Считает изменение денег по данным игры, пока вы в игре. Покупки и штрафы учитываются как расход.")
        checkbox("Считать доход##incon", cfg.income, 'enabled')
        if not cfg.income.enabled then
            imgui.TextWrapped("Подсчёт выключен.")
        elseif not inc.avail then
            imgui.TextWrapped("Данных о деньгах нет: вы ещё не в игре или Родина не отдаёт баланс скрипту. Тогда считать нечего.")
        elseif not inc.start then
            imgui.TextWrapped("Запоминаю баланс, цифры появятся через секунду.")
        else
            local total = inc.last - inc.start
            plainText("Сейчас на руках: " .. fmtMoney(inc.last))
            plainText("За сессию: " .. (total >= 0 and "+" or "") .. fmtMoney(total))
            plainText("Получено: " .. fmtMoney(inc.earned) .. ". Потрачено: " .. fmtMoney(inc.spent))
            if inc.sec >= 60 then
                local perHour = total / (inc.sec / 3600)
                plainText("В среднем за час: " .. (perHour >= 0 and "+" or "") .. fmtMoney(perHour))
            else
                plainText("В среднем за час: появится через минуту в игре")
            end
            if #inc.events > 0 then
                imgui.Text("Последние изменения:")
                for _, e in ipairs(inc.events) do
                    plainText(e.t .. "  " .. (e.d >= 0 and "+" or "") .. fmtMoney(e.d))
                end
            end
        end
        if imgui.Button("Сбросить доход##increset", imgui.ImVec2(-1, 34)) then X.incomeReset() end
    end
end

-- ---------- аккаунты автовхода ----------
do
    local sel = 1
    local nickB, pwB = imgui.new.char[34](), imgui.new.char[64]()

    local function load()
        local a = cfg.login.accounts[sel]
        setBuf(nickB, a and a.nick or "")
        setBuf(pwB, a and a.password or "")
    end
    function X.refreshAccounts()
        sel = math.max(1, math.min(sel, math.max(#cfg.login.accounts, 1)))
        load()
    end
    X.refreshAccounts()
    X.refreshers[#X.refreshers + 1] = X.refreshAccounts

    function X.drawAccounts()
        local L = cfg.login
        header("Аккаунты по нику")
        imgui.TextWrapped("Если ник игрока совпал с одним из списка, вводится его пароль. Если ника скрипт не знает, берётся аккаунт «по умолчанию». Если и его нет, используется общий пароль выше. Чужой пароль к известному нику не подставляется.")
        checkbox("Если ник неизвестен, брать аккаунт по умолчанию##alu", L, 'useActive')
        plainText("Текущий ник: " .. (X.currentNick() or "пока не определён"))
        if #L.accounts == 0 then imgui.TextWrapped("Список пуст.") end
        for i, a in ipairs(L.accounts) do
            local title = ((a.nick .. (a.password ~= "" and "  (пароль есть)" or "  (без пароля)")
                .. (L.active == i and "  <- по умолчанию" or "")):gsub("#", ""))
            if imgui.RadioButtonBool(title .. "##acc" .. i, sel == i) then
                sel = i
                load()
            end
        end
        if #L.accounts < 10 and imgui.Button("Добавить##accadd", imgui.ImVec2(0, 34)) then
            table.insert(L.accounts, {nick = "Nick_Name", password = ""})
            sel = #L.accounts
            load()
            markDirty()
        end
        local cur = X.currentNick()
        if cur and #L.accounts < 10 then
            imgui.SameLine()
            if imgui.Button("Добавить текущий ник##acccur", imgui.ImVec2(0, 34)) then
                table.insert(L.accounts, {nick = cleanStr(cur, 32), password = ""})
                sel = #L.accounts
                load()
                markDirty()
            end
        end

        local a = L.accounts[sel]
        if a then
            sep()
            imgui.Text("Ник:")
            imgui.PushItemWidth(-1)
            if imgui.InputText("##accnick", nickB, ffi.sizeof(nickB)) then
                a.nick = ffi.string(nickB)
                markDirty()
            end
            imgui.Text("Пароль этого аккаунта:")
            local pwFlags = 0
            if not showPw[0] and imgui.InputTextFlags and imgui.InputTextFlags.Password then
                pwFlags = imgui.InputTextFlags.Password
            end
            if imgui.InputText("##accpw", pwB, ffi.sizeof(pwB), pwFlags) then
                a.password = (ffi.string(pwB):gsub("[\r\n]", ""))
                markDirty()
            end
            imgui.PopItemWidth()
            if imgui.Button("По умолчанию##accdef", imgui.ImVec2(0, 34)) then
                L.active = sel
                markDirty()
            end
            imgui.SameLine()
            if imgui.Button("Удалить##accdel", imgui.ImVec2(0, 34)) then
                table.remove(L.accounts, sel)
                if L.active == sel then L.active = 0 elseif L.active > sel then L.active = L.active - 1 end
                sel = math.max(1, math.min(sel, #L.accounts))
                load()
                markDirty()
            end
        end
        imgui.TextWrapped("Пароли хранятся в config/rodina_hub.json открытым текстом и в код обмена настройками не попадают.")
    end
end

-- BEGIN EMBEDDED MODULES
-- ---------- встроенный модуль: Parovozov Chat (свой чат вместо родного) ----------
X.chatMod = (function()
local imgui    = require 'mimgui'
local encoding = require 'encoding'
local sampev   = require 'samp.events'
local cjson    = require 'cjson'
local ffi      = require 'ffi'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

local dupState = false   -- отдельный Parovozov_chat.lua тоже запущен: встроенный чат молчит

-- =========================================================
-- КОНФИГ
-- =========================================================

local configDir  = getWorkingDirectory() .. '/config'
local configPath = configDir .. '/parovozov_chat.json'
local fontsDir   = getWorkingDirectory() .. '/resource/fonts'
local logPath    = configDir .. '/parovozov_chat_log.txt'

local function deepcopy(v)
    if type(v) ~= 'table' then return v end
    local r = {}
    for k, x in pairs(v) do r[k] = deepcopy(x) end
    return r
end

local function defaultCfg()
    return {
        enabled = true, hideNative = true, locked = true,
        bgAlpha = 70, textAlpha = 100, fontScale = 100, fontSize = 20, fontFile = "",
        timestamps = false, serverColors = true, swapRB = false, showSearch = false,
        maxMessages = 300,
        posXp = 18, posYp = 2, wp = 50, hp = 30,
        fontFiles = {},
        rules = {
            personal = {"PM от", "PM to", "[ЛС]", "[SMS]", "SMS от", "Сообщение от"},
            system = {"[Подсказка]", "[Информация]", "[Система]", "[Ошибка]", "[Rodina", "|____", "Обучение:"},
        },
    }
end

local function isArray(t) return t[1] ~= nil end

local function merge(dst, def)
    for k, v in pairs(def) do
        if dst[k] == nil then
            dst[k] = deepcopy(v)
        elseif type(v) == 'table' and type(dst[k]) == 'table' and not isArray(v) then
            merge(dst[k], v)
        end
    end
end

-- def: значение для мусора и NaN (по умолчанию нижняя граница)
local function clamp(v, a, b, def)
    v = tonumber(v)
    if not v or v ~= v then v = def or a end
    if v < a then return a end
    if v > b then return b end
    return math.floor(v)
end

local cfg = {}
local dirty = false
local function markDirty() dirty = true end

local function saveConfig()
    if not doesDirectoryExist(configDir) then createDirectory(configDir) end
    local ok, enc = pcall(cjson.encode, cfg)
    if ok then
        local f = io.open(configPath, 'w')
        if f then
            f:write(enc)
            f:close()
        end
    end
    dirty = false
end

local function cleanStringList(list)
    local out = {}
    if type(list) == 'table' then
        for _, s in ipairs(list) do
            if type(s) == 'string' and s ~= "" then out[#out + 1] = s end
        end
    end
    return out
end

-- безопасное имя файла шрифта: только буквы, цифры, точка, минус, подчёркивание
local function safeFileName(s)
    if type(s) ~= 'string' or #s == 0 or #s > 64 then return nil end
    if not s:match("^[%w%._%-]+$") or s:find("..", 1, true) then return nil end
    return s
end

local BOOL_KEYS = {"enabled", "hideNative", "locked", "timestamps", "serverColors", "swapRB", "showSearch"}

local function sanitize()
    local def = defaultCfg()
    for _, k in ipairs(BOOL_KEYS) do
        if type(cfg[k]) ~= 'boolean' then cfg[k] = def[k] end
    end
    cfg.bgAlpha = clamp(cfg.bgAlpha, 0, 100, def.bgAlpha)
    cfg.textAlpha = clamp(cfg.textAlpha, 20, 100, def.textAlpha)
    cfg.fontScale = clamp(cfg.fontScale, 50, 200, def.fontScale)
    cfg.fontSize = clamp(cfg.fontSize, 12, 40, def.fontSize)
    cfg.maxMessages = clamp(cfg.maxMessages, 50, 1000, def.maxMessages)
    cfg.posXp = clamp(cfg.posXp, 0, 95, def.posXp)
    cfg.posYp = clamp(cfg.posYp, 0, 95, def.posYp)
    cfg.wp = clamp(cfg.wp, 20, 100, def.wp)
    cfg.hp = clamp(cfg.hp, 10, 100, def.hp)
    if type(cfg.fontFile) ~= 'string' or (cfg.fontFile ~= "" and not safeFileName(cfg.fontFile)) then
        cfg.fontFile = ""
    end
    local files = {}
    if type(cfg.fontFiles) == 'table' then
        for _, f in ipairs(cfg.fontFiles) do
            if safeFileName(f) then files[#files + 1] = f end
        end
    end
    cfg.fontFiles = files
    cfg.rules.personal = cleanStringList(cfg.rules.personal)
    cfg.rules.system = cleanStringList(cfg.rules.system)
end

local function loadConfig()
    cfg = {}
    if doesFileExist(configPath) then
        local f = io.open(configPath, 'r')
        if f then
            local content = f:read('*a')
            f:close()
            local ok, res = pcall(cjson.decode, content)
            if ok and type(res) == 'table' then cfg = res end
        end
    end
    if type(cfg.rules) ~= 'table' then cfg.rules = nil end
    merge(cfg, defaultCfg())
    sanitize()
    saveConfig()
end

loadConfig()

-- =========================================================
-- СООБЩЕНИЯ
-- =========================================================

local TAB_NAMES = {"Все", "Общий", "Личные", "Система"}
local TAB_CATS  = {"all", "general", "personal", "system"}

local messages = {}
local unread = {general = 0, personal = 0, system = 0}
local currentTab = 1
local needScroll = true
local forceBottom = false

local function matchAny(text, list)
    for _, pat in ipairs(list) do
        if pat ~= "" and text:find(pat, 1, true) then return true end
    end
    return false
end

local function classify(text)
    if matchAny(text, cfg.rules.personal) then return 'personal' end
    if matchAny(text, cfg.rules.system) then return 'system' end
    return 'general'
end

-- цвет сервера приходит как RGBA (0xRRGGBBAA), без bit-библиотеки
local function decodeColor(c)
    c = (tonumber(c) or -1) % 4294967296
    local r = math.floor(c / 16777216) % 256
    local g = math.floor(c / 65536) % 256
    local b = math.floor(c / 256) % 256
    if cfg.swapRB then r, b = b, r end
    return r / 255, g / 255, b / 255
end

local function addMessage(text, colorInt, isLocal)
    if type(text) ~= 'string' then return end
    local utf = text
    if not isLocal then
        local ok, conv = pcall(function() return u8(text) end)
        if ok and type(conv) == 'string' then utf = conv end
    end

    local r, g, b = 1, 1, 1
    if cfg.serverColors and colorInt then r, g, b = decodeColor(colorInt) end

    local hex = utf:match("{(%x%x%x%x%x%x)}")
    if hex then
        r = tonumber(hex:sub(1, 2), 16) / 255
        g = tonumber(hex:sub(3, 4), 16) / 255
        b = tonumber(hex:sub(5, 6), 16) / 255
    end
    utf = (utf:gsub("{%x%x%x%x%x%x}", ""))
    if utf:match("^%s*$") then return end

    local cat = isLocal and 'system' or classify(utf)
    messages[#messages + 1] = {t = os.time(), text = utf, r = r, g = g, b = b, cat = cat}
    while #messages > cfg.maxMessages do table.remove(messages, 1) end

    -- собственные уведомления скрипта не считаем непрочитанными
    local tabCat = TAB_CATS[currentTab]
    if not isLocal and tabCat ~= 'all' and tabCat ~= cat then
        unread[cat] = unread[cat] + 1
    end
    needScroll = true
end

-- собственные уведомления скрипта
local prevMode = nil
local lastNotice = ""
local function notice(text)
    lastNotice = text
    addMessage(text, nil, true)
    if not (cfg.enabled and cfg.hideNative) then
        sampAddChatMessage(u8:decode("{8A2BE2}[Parovozov Chat] {FFFFFF}" .. text), -1)
    end
end

-- строки сервера приходят из хаба после фильтра чата; служебные строки хаба тоже
X.rawSink = function(color, text)
    if dupState then return end
    addMessage(text, color, false)
end
X.noticeSink = function(line)
    if dupState then return end
    addMessage(line, nil, true)
end

function sampev.onChatMessage(playerId, text)
    if dupState then return end
    local name = "?"
    local ok, n = pcall(sampGetPlayerNickname, playerId)
    if ok and type(n) == 'string' then name = n end
    addMessage(string.format("%s[%d]: %s", name, playerId, text), nil, false)
end

-- =========================================================
-- ШРИФТЫ
-- =========================================================

local fonts = {}
local fontNames = {}

local function listFontFiles()
    local list, seen = {}, {}
    local function add(f)
        if safeFileName(f) and not seen[f] then
            seen[f] = true
            list[#list + 1] = f
        end
    end

    local okLfs, lfs = pcall(require, 'lfs')
    if okLfs and type(lfs) == 'table' and doesDirectoryExist(fontsDir) then
        local names = {}
        pcall(function()
            for f in lfs.dir(fontsDir) do
                local low = f:lower()
                if low:match("%.ttf$") or low:match("%.otf$") then names[#names + 1] = f end
            end
        end)
        table.sort(names)
        for _, f in ipairs(names) do add(f) end
    end
    for _, f in ipairs(cfg.fontFiles) do add(f) end
    return list
end

X.initHooks[#X.initHooks + 1] = function()
    local io = imgui.GetIO()

    if not doesDirectoryExist(getWorkingDirectory() .. '/resource') then
        createDirectory(getWorkingDirectory() .. '/resource')
    end
    if not doesDirectoryExist(fontsDir) then createDirectory(fontsDir) end

    local ranges = io.Fonts:GetGlyphRangesCyrillic()
    for _, file in ipairs(listFontFiles()) do
        local path = fontsDir .. '/' .. file
        if #fontNames < 6 and doesFileExist(path) then
            local ok, font = pcall(function()
                return io.Fonts:AddFontFromFileTTF(path, cfg.fontSize, nil, ranges)
            end)
            if ok and font then
                fonts[file] = font
                fontNames[#fontNames + 1] = file
            end
        end
    end
end

-- =========================================================
-- ЭЛЕМЕНТЫ ИНТЕРФЕЙСА
-- =========================================================

local boolCache, intCache = {}, {}

local function checkbox(label, tbl, key)
    local id = tostring(tbl) .. key
    local b = boolCache[id]
    if not b then
        b = imgui.new.bool(false)
        boolCache[id] = b
    end
    b[0] = tbl[key] and true or false
    if imgui.Checkbox(label, b) then
        tbl[key] = b[0]
        markDirty()
        return true
    end
    return false
end

local function sliderInt(label, tbl, key, a, b)
    local id = tostring(tbl) .. key
    local i = intCache[id]
    if not i then
        i = imgui.new.int(0)
        intCache[id] = i
    end
    i[0] = tbl[key] or a
    if imgui.SliderInt(label, i, a, b) then
        tbl[key] = i[0]
        markDirty()
        return true
    end
    return false
end

-- текст без printf-разбора: в заголовках бывает знак процента
local function plainText(s)
    imgui.PushTextWrapPos(0.0)
    imgui.TextUnformatted(s)
    imgui.PopTextWrapPos()
end

local function fullSlider(title, tbl, key, a, b)
    plainText(title)
    imgui.PushItemWidth(-1)
    local changed = sliderInt('##' .. key, tbl, key, a, b)
    imgui.PopItemWidth()
    return changed
end

local function setBuf(buf, str)
    ffi.fill(buf, ffi.sizeof(buf))
    ffi.copy(buf, str:sub(1, ffi.sizeof(buf) - 1))
end

local function linesToList(text)
    local list = {}
    for line in text:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then list[#list + 1] = line end
    end
    return list
end

local inBuf      = imgui.new.char[256]()
local searchBuf  = imgui.new.char[64]()
local persBuf    = imgui.new.char[1024]()
local sysBuf     = imgui.new.char[1024]()
local fontAddBuf = imgui.new.char[64]()

local function refreshRuleBuffers()
    setBuf(persBuf, table.concat(cfg.rules.personal, "\n"))
    setBuf(sysBuf, table.concat(cfg.rules.system, "\n"))
end
refreshRuleBuffers()

local showSettings = false
local layoutForce = true

local function scrollToBottom()
    pcall(function()
        if imgui.SetScrollHereY then
            imgui.SetScrollHereY(1.0)
        elseif imgui.SetScrollHere then
            imgui.SetScrollHere(1.0)
        end
    end)
end

local function sendInput()
    local text = ffi.string(inBuf)
    if text ~= "" then
        pcall(sampSendChat, u8:decode(text))
        ffi.fill(inBuf, ffi.sizeof(inBuf))
    end
end

local function saveLog()
    if not doesDirectoryExist(configDir) then createDirectory(configDir) end
    local f = io.open(logPath, 'w')
    if not f then
        notice("Не удалось сохранить лог")
        return
    end
    for _, m in ipairs(messages) do
        f:write(os.date("[%H:%M:%S] ", m.t), m.text, "\n")
    end
    f:close()
    notice("Лог сохранён: config/parovozov_chat_log.txt")
end

-- =========================================================
-- НАСТРОЙКИ
-- =========================================================

local function drawSettings()
    imgui.TextColored(imgui.ImVec4(0.7, 0.5, 1.0, 1.0), "Окно чата")
    checkbox("Скрывать родной чат##hn", cfg, 'hideNative')
    checkbox("Закрепить окно (убрать заголовок)##lk", cfg, 'locked')
    fullSlider("Прозрачность фона, %:", cfg, 'bgAlpha', 0, 100)
    fullSlider("Прозрачность текста, %:", cfg, 'textAlpha', 20, 100)
    if fullSlider("Положение X, % экрана:", cfg, 'posXp', 0, 95) then layoutForce = true end
    if fullSlider("Положение Y, % экрана:", cfg, 'posYp', 0, 95) then layoutForce = true end
    if fullSlider("Ширина, % экрана:", cfg, 'wp', 20, 100) then layoutForce = true end
    if fullSlider("Высота, % экрана:", cfg, 'hp', 10, 100) then layoutForce = true end

    imgui.Separator()
    imgui.TextColored(imgui.ImVec4(0.7, 0.5, 1.0, 1.0), "Текст")
    fullSlider("Размер текста, %:", cfg, 'fontScale', 50, 200)
    checkbox("Показывать время сообщений##ts", cfg, 'timestamps')
    checkbox("Цвета сервера##sc", cfg, 'serverColors')
    checkbox("Поменять красный и синий местами##rb", cfg, 'swapRB')
    checkbox("Строка поиска##ss", cfg, 'showSearch')
    fullSlider("Сколько сообщений хранить:", cfg, 'maxMessages', 50, 1000)

    imgui.Separator()
    imgui.TextColored(imgui.ImVec4(0.7, 0.5, 1.0, 1.0), "Шрифт")
    if imgui.RadioButtonBool("Стандартный##font0", cfg.fontFile == "") then
        cfg.fontFile = ""
        markDirty()
    end
    for i, name in ipairs(fontNames) do
        if imgui.RadioButtonBool(name .. "##font" .. i, cfg.fontFile == name) then
            cfg.fontFile = name
            markDirty()
        end
    end
    imgui.TextWrapped("Положите файл .ttf в папку moonloader/resource/fonts, впишите его имя ниже и перезапустите игру: новые шрифты подхватываются только при запуске.")
    imgui.PushItemWidth(-1)
    imgui.InputText("##fontadd", fontAddBuf, ffi.sizeof(fontAddBuf))
    imgui.PopItemWidth()
    if imgui.Button("Добавить шрифт по имени файла##fadd", imgui.ImVec2(-1, 34)) then
        local name = ffi.string(fontAddBuf)
        if safeFileName(name) then
            table.insert(cfg.fontFiles, name)
            ffi.fill(fontAddBuf, ffi.sizeof(fontAddBuf))
            markDirty()
            notice("Шрифт добавлен в список, перезапустите игру")
        else
            notice("Имя файла должно состоять из латинских букв, цифр, точки, минуса или подчёркивания")
        end
    end
    fullSlider("Размер шрифта при загрузке, px (нужен перезапуск):", cfg, 'fontSize', 12, 40)

    imgui.Separator()
    imgui.TextColored(imgui.ImVec4(0.7, 0.5, 1.0, 1.0), "Вкладки: правила")
    imgui.TextWrapped("Сообщение попадает в «Личные» или «Система», если содержит одну из строк (по одной на строку). Всё остальное идёт в «Общий».")
    imgui.Text("Личные:")
    if imgui.InputTextMultiline("##persrules", persBuf, ffi.sizeof(persBuf), imgui.ImVec2(-1, 90)) then
        cfg.rules.personal = linesToList(ffi.string(persBuf))
        markDirty()
    end
    imgui.Text("Система:")
    if imgui.InputTextMultiline("##sysrules", sysBuf, ffi.sizeof(sysBuf), imgui.ImVec2(-1, 90)) then
        cfg.rules.system = linesToList(ffi.string(sysBuf))
        markDirty()
    end
    imgui.TextWrapped("Регистр важен. Строки MultiTools показываются и в этом чате. Сообщения других скриптов сюда не попадают, пока родной чат скрыт.")

    imgui.Separator()
    if imgui.Button("Очистить чат##clr", imgui.ImVec2(-1, 34)) then
        messages = {}
        unread.general, unread.personal, unread.system = 0, 0, 0
    end
    if imgui.Button("Сохранить лог в файл##log", imgui.ImVec2(-1, 34)) then
        saveLog()
    end
    if lastNotice ~= "" then
        imgui.Separator()
        plainText(lastNotice)
    end
end

-- =========================================================
-- ОКНО ЧАТА
-- =========================================================

local function drawMessage(m)
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(m.r, m.g, m.b, cfg.textAlpha / 100))
    imgui.PushTextWrapPos(0.0)
    local line = m.text
    if cfg.timestamps then line = os.date("[%H:%M:%S] ", m.t) .. line end
    imgui.TextUnformatted(line)
    imgui.PopTextWrapPos()
    imgui.PopStyleColor(1)
end

local function tabButton(i)
    local cat = TAB_CATS[i]
    local label = TAB_NAMES[i]
    if cat ~= 'all' and unread[cat] > 0 then label = label .. " (" .. unread[cat] .. ")" end

    local active = (currentTab == i) and not showSettings
    if active then
        local c = imgui.GetStyle().Colors[imgui.Col.ButtonHovered] or imgui.ImVec4(0.5, 0.3, 0.9, 1.0)
        imgui.PushStyleColor(imgui.Col.Button, c)
    end
    local clicked = imgui.Button(label .. "###ptab" .. i)
    if active then imgui.PopStyleColor(1) end

    if clicked then
        currentTab = i
        showSettings = false
        if cat ~= 'all' then unread[cat] = 0 end
        needScroll = true
        forceBottom = true
    end
end

local function windowFlags()
    local f = imgui.WindowFlags.NoSavedSettings
    if cfg.locked then
        f = f + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoResize
    end
    return f
end

X.frame(
    function() return cfg.enabled and not dupState and not X.chatHidden() end,
    function(self)
        local sw, sh = getScreenResolution()

        local cond = cfg.locked and imgui.Cond.Always or imgui.Cond.FirstUseEver
        if layoutForce then
            cond = imgui.Cond.Always
            layoutForce = false
        end
        imgui.SetNextWindowPos(imgui.ImVec2(sw * cfg.posXp / 100, sh * cfg.posYp / 100), cond)
        imgui.SetNextWindowSize(imgui.ImVec2(sw * cfg.wp / 100, sh * cfg.hp / 100), cond)
        imgui.SetNextWindowBgAlpha(cfg.bgAlpha / 100)

        local font = fonts[cfg.fontFile]
        if font then imgui.PushFont(font) end

        if imgui.Begin("Parovozov Chat##pchat", nil, windowFlags()) then
            imgui.SetWindowFontScale(cfg.fontScale / 100)

            for i = 1, #TAB_NAMES do
                if i > 1 then imgui.SameLine() end
                tabButton(i)
            end
            imgui.SameLine()
            if imgui.Button((showSettings and "Назад" or "Настр.") .. "###pset") then
                showSettings = not showSettings
            end

            if cfg.showSearch and not showSettings then
                imgui.PushItemWidth(-1)
                imgui.InputText("##psearch", searchBuf, ffi.sizeof(searchBuf))
                imgui.PopItemWidth()
            end

            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0, 0, 0, 0))
            imgui.BeginChild("##pmsgs", imgui.ImVec2(0, showSettings and -5 or -40), false)
            if showSettings then
                drawSettings()
            else
                local atBottom = true
                local okS, y = pcall(imgui.GetScrollY)
                local okM, maxY = pcall(imgui.GetScrollMaxY)
                if okS and okM and type(y) == 'number' and type(maxY) == 'number' then
                    atBottom = y >= maxY - 3
                end

                local cat = TAB_CATS[currentTab]
                local q = ffi.string(searchBuf)
                for _, m in ipairs(messages) do
                    if (cat == 'all' or m.cat == cat) and (q == "" or m.text:find(q, 1, true)) then
                        drawMessage(m)
                    end
                end

                if needScroll and (atBottom or forceBottom) then scrollToBottom() end
                needScroll = false
                forceBottom = false
            end
            imgui.EndChild()
            imgui.PopStyleColor(1)

            if not showSettings then
                imgui.PushItemWidth(-90)
                local enter = imgui.InputText("##pin", inBuf, ffi.sizeof(inBuf), imgui.InputTextFlags.EnterReturnsTrue)
                imgui.PopItemWidth()
                imgui.SameLine()
                local send = imgui.Button("Отправить##psend")
                if enter or send then sendInput() end
            end

            -- запоминаем положение и размер, если окно двигали вручную
            if not cfg.locked then
                local pos, size = imgui.GetWindowPos(), imgui.GetWindowSize()
                if pos and size and sw > 0 and sh > 0 then
                    local nx, ny = clamp(pos.x / sw * 100, 0, 95), clamp(pos.y / sh * 100, 0, 95)
                    local nw, nh = clamp(size.x / sw * 100, 20, 100), clamp(size.y / sh * 100, 10, 100)
                    if math.abs(nx - cfg.posXp) >= 1 or math.abs(ny - cfg.posYp) >= 1
                        or math.abs(nw - cfg.wp) >= 1 or math.abs(nh - cfg.hp) >= 1 then
                        cfg.posXp, cfg.posYp, cfg.wp, cfg.hp = nx, ny, nw, nh
                        markDirty()
                    end
                end
            end
        end
        imgui.End()
        if font then imgui.PopFont() end
    end
)


-- =========================================================
-- ЖИЗНЬ МОДУЛЯ: запуск, периодические задачи, остановка
-- =========================================================

local function restoreNative()
    if prevMode ~= nil then
        pcall(sampSetChatDisplayMode, prevMode)
        prevMode = nil
    end
end

local lastSave, lastHide, lastDup = os.clock(), 0, 0

local function init()
    dupState = X.standalone("Parovozov Chat")
    if dupState then return end

    sampRegisterChatCommand("pchat", function()
        cfg.enabled = not cfg.enabled
        markDirty()
        if not cfg.enabled then restoreNative() end
        notice(cfg.enabled and "Чат включён" or "Чат выключен, родной чат возвращён")
    end)

    sampRegisterChatCommand("pchatset", function()
        cfg.enabled = true
        showSettings = not showSettings
        markDirty()
    end)

    notice("Загружен. Команды: /pchat (включить или выключить), /pchatset (настройки)")
end

local function tick()
    local now = os.clock()

    -- раз в несколько секунд смотрим, не запущен ли отдельный Parovozov_chat.lua
    if now - lastDup >= 3 then
        lastDup = now
        local d = X.standalone("Parovozov Chat")
        if d and not dupState then restoreNative() end
        dupState = d
    end
    if dupState then return end

    -- прячем родной чат
    if now - lastHide >= 0.5 then
        lastHide = now
        if cfg.enabled and cfg.hideNative then
            if prevMode == nil then
                local ok, mode = pcall(sampGetChatDisplayMode)
                prevMode = (ok and type(mode) == 'number' and mode > 0) and mode or 2
            end
            pcall(sampSetChatDisplayMode, 0)
        else
            restoreNative()
        end
    end

    if dirty and now - lastSave > 2 then
        saveConfig()
        lastSave = now
    end
end

local function stop()
    restoreNative()
    if dirty then saveConfig() end
end

X.tickers[#X.tickers + 1] = tick
X.stoppers[#X.stoppers + 1] = stop

return {
    init = init, drawSettings = drawSettings, cfg = cfg,
    isDup = function() return dupState end,
    enabled = function() return cfg.enabled end,
    setEnabled = function(v)
        cfg.enabled = v and true or false
        markDirty()
        if not cfg.enabled then restoreNative() end
    end,
}
end)()

-- ---------- встроенный модуль: Parovozov Themes (темы и шрифты) ----------
X.themeMod = (function()
local imgui    = require 'mimgui'
local encoding = require 'encoding'
local cjson    = require 'cjson'
local ffi      = require 'ffi'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

local function chat(text)
    X.say("Темы: " .. text)
end

local configDir  = getWorkingDirectory() .. '/config'
local configPath = configDir .. '/parovozov_themes.json'
local themesDir  = configDir .. '/parovozov_themes'
local fontsDir   = getWorkingDirectory() .. '/resource/fonts'

-- =========================================================
-- ДАННЫЕ ТЕМЫ
-- =========================================================

local COLOR_KEYS = {
    {"Text", "Текст"}, {"TextDisabled", "Текст (неактивный)"},
    {"WindowBg", "Фон окна"}, {"ChildBg", "Фон панелей"}, {"PopupBg", "Фон выпадающих меню"},
    {"Border", "Рамка"},
    {"FrameBg", "Поле ввода"}, {"FrameBgHovered", "Поле ввода (наведение)"}, {"FrameBgActive", "Поле ввода (нажато)"},
    {"TitleBg", "Заголовок"}, {"TitleBgActive", "Заголовок (активное окно)"}, {"TitleBgCollapsed", "Заголовок (свёрнуто)"},
    {"ScrollbarBg", "Прокрутка: фон"}, {"ScrollbarGrab", "Прокрутка: ползунок"},
    {"ScrollbarGrabHovered", "Прокрутка: наведение"}, {"ScrollbarGrabActive", "Прокрутка: нажато"},
    {"CheckMark", "Галочка"}, {"SliderGrab", "Ползунок"}, {"SliderGrabActive", "Ползунок (нажато)"},
    {"Button", "Кнопка"}, {"ButtonHovered", "Кнопка (наведение)"}, {"ButtonActive", "Кнопка (нажата)"},
    {"Header", "Выделение"}, {"HeaderHovered", "Выделение (наведение)"}, {"HeaderActive", "Выделение (нажато)"},
    {"Separator", "Разделитель"}, {"SeparatorHovered", "Разделитель (наведение)"}, {"SeparatorActive", "Разделитель (нажато)"},
}

local SIZE_LIST = {
    {"windowRounding", "Скругление окон", 0, 24},
    {"childRounding", "Скругление панелей", 0, 24},
    {"frameRounding", "Скругление кнопок и полей", 0, 20},
    {"grabRounding", "Скругление ползунков", 0, 20},
    {"scrollbarRounding", "Скругление прокрутки", 0, 20},
    {"popupRounding", "Скругление выпадающих меню", 0, 20},
    {"windowPadX", "Отступ окна по X", 0, 30},
    {"windowPadY", "Отступ окна по Y", 0, 30},
    {"framePadX", "Отступ в кнопках по X", 0, 24},
    {"framePadY", "Отступ в кнопках по Y", 0, 20},
    {"itemSpacingX", "Расстояние между элементами по X", 0, 24},
    {"itemSpacingY", "Расстояние между элементами по Y", 0, 24},
    {"scrollbarSize", "Ширина прокрутки", 6, 30},
}

local SIZE_DEFAULTS = {
    windowRounding = 12, childRounding = 10, frameRounding = 8, grabRounding = 8,
    scrollbarRounding = 8, popupRounding = 8,
    windowPadX = 14, windowPadY = 14, framePadX = 10, framePadY = 7,
    itemSpacingX = 8, itemSpacingY = 8, scrollbarSize = 14,
}

local function mix(a, b, t)
    return {a[1] * (1 - t) + b[1] * t, a[2] * (1 - t) + b[2] * t, a[3] * (1 - t) + b[3] * t}
end

-- строим все цвета из акцента и фона
local function buildColors(acc, bg, light)
    local C = {}
    local function put(key, c, a) C[key] = {c[1], c[2], c[3], a} end

    local text = light and {0.09, 0.09, 0.12} or {0.93, 0.93, 0.96}
    local dim  = light and {0.42, 0.42, 0.47} or {0.50, 0.50, 0.56}

    put("Text", text, 1.0)
    put("TextDisabled", dim, 1.0)
    put("WindowBg", bg, 0.98)
    put("ChildBg", mix(bg, light and {1, 1, 1} or {0, 0, 0}, 0.25), 0.90)
    put("PopupBg", bg, 0.98)
    put("Border", mix(bg, acc, 0.35), 0.50)

    put("FrameBg", mix(bg, acc, 0.25), 0.60)
    put("FrameBgHovered", mix(bg, acc, 0.40), 0.70)
    put("FrameBgActive", mix(bg, acc, 0.55), 0.80)

    put("TitleBg", mix(bg, acc, 0.40), 0.90)
    put("TitleBgActive", mix(bg, acc, 0.75), 1.0)
    put("TitleBgCollapsed", mix(bg, acc, 0.25), 0.70)

    put("ScrollbarBg", bg, 0.60)
    put("ScrollbarGrab", mix(bg, acc, 0.50), 1.0)
    put("ScrollbarGrabHovered", mix(bg, acc, 0.70), 1.0)
    put("ScrollbarGrabActive", mix(bg, acc, 0.90), 1.0)

    put("CheckMark", acc, 1.0)
    put("SliderGrab", mix(bg, acc, 0.85), 1.0)
    put("SliderGrabActive", acc, 1.0)

    put("Button", mix(bg, acc, 0.70), 0.85)
    put("ButtonHovered", acc, 0.95)
    put("ButtonActive", mix(bg, acc, 0.60), 1.0)

    put("Header", mix(bg, acc, 0.50), 0.70)
    put("HeaderHovered", mix(bg, acc, 0.75), 0.85)
    put("HeaderActive", acc, 1.0)

    put("Separator", mix(bg, acc, 0.60), 0.60)
    put("SeparatorHovered", mix(bg, acc, 0.80), 0.80)
    put("SeparatorActive", acc, 1.0)
    return C
end

local function copyTable(t)
    local r = {}
    for k, v in pairs(t) do r[k] = v end
    return r
end

local function newTheme(name, acc, bg, light)
    return {
        name = name,
        accent = {acc[1], acc[2], acc[3]},
        bg = {bg[1], bg[2], bg[3]},
        light = light and true or false,
        colors = buildColors(acc, bg, light),
        sizes = copyTable(SIZE_DEFAULTS),
        font = "",
        fontScale = 100,
    }
end

local PRESET_DEFS = {
    {"Фиолетовая ночь", {0.54, 0.20, 0.85}, {0.055, 0.055, 0.070}, false},
    {"Океан",           {0.15, 0.55, 0.90}, {0.040, 0.065, 0.095}, false},
    {"Лес",             {0.20, 0.70, 0.35}, {0.040, 0.075, 0.050}, false},
    {"Закат",           {0.95, 0.45, 0.20}, {0.090, 0.055, 0.050}, false},
    {"Роза",            {0.90, 0.30, 0.60}, {0.085, 0.050, 0.070}, false},
    {"Графит",          {0.70, 0.70, 0.75}, {0.075, 0.075, 0.080}, false},
    {"Светлая",         {0.20, 0.45, 0.90}, {0.94, 0.94, 0.96},   true},
}

-- =========================================================
-- ПРОВЕРКА ДАННЫХ (то же для конфига и для импорта)
-- =========================================================

-- def: значение для мусора и NaN (по умолчанию нижняя граница)
local function clamp(v, a, b, def)
    v = tonumber(v)
    if not v or v ~= v then v = def or a end
    if v < a then return a end
    if v > b then return b end
    return math.floor(v)
end

local function clampF(v, a, b, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    if v < a then return a end
    if v > b then return b end
    return v
end

local function safeFileName(s)
    if type(s) ~= 'string' or #s == 0 or #s > 64 then return nil end
    if not s:match("^[%w%._%-]+$") or s:find("..", 1, true) then return nil end
    return s
end

-- обрезка по границе символа UTF-8, чтобы не получить битую букву
local function cutUtf8(s, maxBytes)
    if #s <= maxBytes then return s end
    local cut = maxBytes
    while cut > 0 do
        local b = s:byte(cut + 1)
        if b and b >= 128 and b < 192 then cut = cut - 1 else break end
    end
    return s:sub(1, cut)
end

local function cleanName(s)
    if type(s) ~= 'string' then return "Тема" end
    s = s:gsub("[%c]", " "):match("^%s*(.-)%s*$")
    if s == "" then return "Тема" end
    return cutUtf8(s, 40)
end

-- русские буквы латиницей для имён файлов
local LAT = {"a", "b", "v", "g", "d", "e", "zh", "z", "i", "y", "k", "l", "m", "n", "o", "p", "r", "s", "t", "u",
    "f", "h", "ts", "ch", "sh", "sch", "", "y", "", "e", "yu", "ya"}

local function translit(s)
    return (s:gsub("[\208\209][\128-\191]", function(ch)
        local cp = (ch:byte(1) - 192) * 64 + (ch:byte(2) - 128)
        if cp >= 0x410 and cp <= 0x42F then cp = cp + 32 end
        if cp == 0x401 or cp == 0x451 then return "e" end
        if cp >= 0x430 and cp <= 0x44F then return LAT[cp - 0x42F] end
        return "_"
    end))
end

local function color3(t, def)
    if type(t) ~= 'table' then return {def[1], def[2], def[3]} end
    return {clampF(t[1], 0, 1, def[1]), clampF(t[2], 0, 1, def[2]), clampF(t[3], 0, 1, def[3])}
end

-- возвращает очищенную тему; чужие данные никогда не выполняются как код
local function sanitizeTheme(t)
    if type(t) ~= 'table' then return nil, "это не тема" end

    local out = {}
    out.name = cleanName(t.name)
    out.accent = color3(t.accent, {0.54, 0.20, 0.85})
    out.bg = color3(t.bg, {0.055, 0.055, 0.070})
    out.light = t.light == true

    local base = buildColors(out.accent, out.bg, out.light)
    out.colors = {}
    local given = type(t.colors) == 'table' and t.colors or {}
    for _, kv in ipairs(COLOR_KEYS) do
        local k = kv[1]
        local c = given[k]
        local def = base[k]
        if type(c) == 'table' then
            out.colors[k] = {
                clampF(c[1], 0, 1, def[1]), clampF(c[2], 0, 1, def[2]),
                clampF(c[3], 0, 1, def[3]), clampF(c[4], 0, 1, def[4]),
            }
        else
            out.colors[k] = def
        end
    end

    out.sizes = {}
    local gs = type(t.sizes) == 'table' and t.sizes or {}
    for _, s in ipairs(SIZE_LIST) do
        out.sizes[s[1]] = clamp(gs[s[1]], s[3], s[4], SIZE_DEFAULTS[s[1]])
    end

    out.font = safeFileName(t.font) or ""
    out.fontScale = clamp(t.fontScale, 50, 200, 100)
    return out
end

-- =========================================================
-- КОНФИГ
-- =========================================================

local cfg = {}
local dirty = false
local function markDirty() dirty = true end

local function saveConfig()
    if not doesDirectoryExist(configDir) then createDirectory(configDir) end
    local ok, enc = pcall(cjson.encode, cfg)
    if ok then
        local f = io.open(configPath, 'w')
        if f then
            f:write(enc)
            f:close()
        end
    end
    dirty = false
end

local function loadConfig()
    local data = {}
    if doesFileExist(configPath) then
        local f = io.open(configPath, 'r')
        if f then
            local content = f:read('*a')
            f:close()
            local ok, res = pcall(cjson.decode, content)
            if ok and type(res) == 'table' then data = res end
        end
    end

    local p = PRESET_DEFS[1]
    cfg.theme = sanitizeTheme(data.theme) or newTheme(p[1], p[2], p[3], p[4])

    cfg.userThemes = {}
    if type(data.userThemes) == 'table' then
        for _, t in ipairs(data.userThemes) do
            local clean = sanitizeTheme(t)
            if clean and #cfg.userThemes < 30 then cfg.userThemes[#cfg.userThemes + 1] = clean end
        end
    end

    cfg.fontFiles = {}
    if type(data.fontFiles) == 'table' then
        for _, f in ipairs(data.fontFiles) do
            if safeFileName(f) then cfg.fontFiles[#cfg.fontFiles + 1] = f end
        end
    end
    cfg.fontSize = clamp(data.fontSize, 12, 40, 20)
    cfg.launcher = data.launcher == true
    saveConfig()
end

loadConfig()

-- =========================================================
-- ШРИФТЫ И ПРИМЕНЕНИЕ ТЕМЫ
-- =========================================================

local fonts = {}
local fontNames = {}

local function listFontFiles()
    local list, seen = {}, {}
    local function add(f)
        if safeFileName(f) and not seen[f] then
            seen[f] = true
            list[#list + 1] = f
        end
    end

    local okLfs, lfs = pcall(require, 'lfs')
    if okLfs and type(lfs) == 'table' and doesDirectoryExist(fontsDir) then
        local names = {}
        pcall(function()
            for f in lfs.dir(fontsDir) do
                local low = f:lower()
                if low:match("%.ttf$") or low:match("%.otf$") then names[#names + 1] = f end
            end
        end)
        table.sort(names)
        for _, f in ipairs(names) do add(f) end
    end
    for _, f in ipairs(cfg.fontFiles) do add(f) end
    return list
end

local function applyTheme()
    local t = cfg.theme
    local style = imgui.GetStyle()

    for _, kv in ipairs(COLOR_KEYS) do
        local c = t.colors[kv[1]]
        local idx = imgui.Col[kv[1]]
        if c and idx then style.Colors[idx] = imgui.ImVec4(c[1], c[2], c[3], c[4]) end
    end

    local s = t.sizes
    style.WindowRounding = s.windowRounding
    style.ChildRounding = s.childRounding
    style.FrameRounding = s.frameRounding
    style.GrabRounding = s.grabRounding
    style.ScrollbarRounding = s.scrollbarRounding
    style.PopupRounding = s.popupRounding
    style.ScrollbarSize = s.scrollbarSize
    style.WindowPadding = imgui.ImVec2(s.windowPadX, s.windowPadY)
    style.FramePadding = imgui.ImVec2(s.framePadX, s.framePadY)
    style.ItemSpacing = imgui.ImVec2(s.itemSpacingX, s.itemSpacingY)

    pcall(function()
        local io = imgui.GetIO()
        io.FontGlobalScale = t.fontScale / 100
        io.FontDefault = fonts[t.font]
    end)
end

local function themeChanged()
    X.themeTouched()   -- правка темы сама включает её применение
    applyTheme()
    markDirty()
end

X.initHooks[#X.initHooks + 1] = function()
    local io = imgui.GetIO()

    if not doesDirectoryExist(getWorkingDirectory() .. '/resource') then
        createDirectory(getWorkingDirectory() .. '/resource')
    end
    if not doesDirectoryExist(fontsDir) then createDirectory(fontsDir) end

    local ranges = io.Fonts:GetGlyphRangesCyrillic()
    for _, file in ipairs(listFontFiles()) do
        local path = fontsDir .. '/' .. file
        if #fontNames < 6 and doesFileExist(path) then
            local ok, font = pcall(function()
                return io.Fonts:AddFontFromFileTTF(path, cfg.fontSize, nil, ranges)
            end)
            if ok and font then
                fonts[file] = font
                fontNames[#fontNames + 1] = file
            end
        end
    end

    if X.themeOn() then applyTheme() end
end

-- =========================================================
-- ОБМЕН ТЕМАМИ
-- =========================================================

local function round3(x) return math.floor(x * 1000 + 0.5) / 1000 end

local function exportCode(theme)
    local out = {v = 1, name = theme.name, light = theme.light,
        accent = {}, bg = {}, colors = {}, sizes = copyTable(theme.sizes),
        font = theme.font, fontScale = theme.fontScale}
    for i = 1, 3 do
        out.accent[i] = round3(theme.accent[i])
        out.bg[i] = round3(theme.bg[i])
    end
    for _, kv in ipairs(COLOR_KEYS) do
        local c = theme.colors[kv[1]]
        out.colors[kv[1]] = {round3(c[1]), round3(c[2]), round3(c[3]), round3(c[4])}
    end
    local ok, enc = pcall(cjson.encode, out)
    if ok then return enc end
    return nil
end

local function importCode(text)
    text = tostring(text or ""):match("^%s*(.-)%s*$")
    if text == "" then return nil, "поле пустое" end
    if #text > 16000 then return nil, "слишком длинный текст" end
    local ok, data = pcall(cjson.decode, text)
    if not ok or type(data) ~= 'table' then return nil, "это не код темы" end
    if type(data.colors) ~= 'table' and type(data.accent) ~= 'table' and type(data.bg) ~= 'table' then
        return nil, "в коде нет данных темы"
    end
    return sanitizeTheme(data)
end

-- имя файла: только латиница, цифры, минус и подчёркивание (выйти из папки тем нельзя)
local function themeFilePath(name)
    local safe = translit(name)
    safe = safe:gsub("[^%w_%-]", "_")
    safe = safe:sub(1, 40)
    if safe:match("^_*$") then safe = "theme" end
    return themesDir .. '/' .. safe .. '.json', safe
end

-- =========================================================
-- ЭЛЕМЕНТЫ ИНТЕРФЕЙСА
-- =========================================================

local boolCache, intCache = {}, {}

local function sliderInt(label, tbl, key, a, b)
    local id = tostring(tbl) .. key
    local i = intCache[id]
    if not i then
        i = imgui.new.int(0)
        intCache[id] = i
    end
    i[0] = tbl[key] or a
    if imgui.SliderInt(label, i, a, b) then
        tbl[key] = i[0]
        return true
    end
    return false
end

local function setBuf(buf, str)
    ffi.fill(buf, ffi.sizeof(buf))
    ffi.copy(buf, str:sub(1, ffi.sizeof(buf) - 1))
end

local window = imgui.new.bool(false)
local currentTab = 1
local status = ""

local uiAccent = imgui.new.float[3](0, 0, 0)
local uiBg     = imgui.new.float[3](0, 0, 0)
local uiLight  = imgui.new.bool(false)
local uiColors = {}
for _, kv in ipairs(COLOR_KEYS) do uiColors[kv[1]] = imgui.new.float[4](0, 0, 0, 1) end

local nameBuf     = imgui.new.char[48]()
local codeBuf     = imgui.new.char[16384]()
local fileBuf     = imgui.new.char[48]()
local fontAddBuf  = imgui.new.char[64]()

local function header(text)
    imgui.TextColored(imgui.ImVec4(0.7, 0.5, 1.0, 1.0), text)
end

-- текст без printf-разбора: имена тем приходят из чужого кода и могут содержать %
local function plainText(s)
    imgui.PushTextWrapPos(0.0)
    imgui.TextUnformatted(tostring(s))
    imgui.PopTextWrapPos()
end

-- =========================================================
-- ВКЛАДКИ
-- =========================================================

local function rebuildFromBase()
    local t = cfg.theme
    t.colors = buildColors(t.accent, t.bg, t.light)
    themeChanged()
end

local function drawThemesTab()
    local t = cfg.theme

    plainText("Текущая тема: " .. t.name)
    imgui.Separator()
    header("Быстрая настройка: акцент и фон")
    uiAccent[0], uiAccent[1], uiAccent[2] = t.accent[1], t.accent[2], t.accent[3]
    uiBg[0], uiBg[1], uiBg[2] = t.bg[1], t.bg[2], t.bg[3]
    uiLight[0] = t.light

    imgui.Text("Акцентный цвет (кнопки, галочки, заголовки):")
    imgui.PushItemWidth(-1)
    if imgui.ColorEdit3("##accent", uiAccent) then
        t.accent = {uiAccent[0], uiAccent[1], uiAccent[2]}
        rebuildFromBase()
    end
    imgui.Text("Цвет фона:")
    if imgui.ColorEdit3("##bg", uiBg) then
        t.bg = {uiBg[0], uiBg[1], uiBg[2]}
        rebuildFromBase()
    end
    imgui.PopItemWidth()
    if imgui.Checkbox("Светлая тема (тёмный текст)##light", uiLight) then
        t.light = uiLight[0]
        rebuildFromBase()
    end
    imgui.TextWrapped("Изменение акцента или фона пересчитывает все цвета темы. Точная настройка отдельных цветов находится во вкладке «Цвета».")

    imgui.Separator()
    header("Готовые стили")
    for i, d in ipairs(PRESET_DEFS) do
        if (i - 1) % 3 ~= 0 then imgui.SameLine() end
        if imgui.Button(d[1] .. "##preset" .. i) then
            t.name = d[1]
            t.accent = {d[2][1], d[2][2], d[2][3]}
            t.bg = {d[3][1], d[3][2], d[3][3]}
            t.light = d[4]
            rebuildFromBase()
        end
    end

    imgui.Separator()
    header("Мои темы")
    imgui.PushItemWidth(-1)
    imgui.InputText("##themename", nameBuf, ffi.sizeof(nameBuf))
    imgui.PopItemWidth()
    if imgui.Button("Сохранить текущую тему под этим именем##savetheme", imgui.ImVec2(-1, 34)) then
        local name = ffi.string(nameBuf)
        if name ~= "" and #cfg.userThemes < 30 then
            local copy = sanitizeTheme(t)
            copy.name = cleanName(name)
            table.insert(cfg.userThemes, copy)
            ffi.fill(nameBuf, ffi.sizeof(nameBuf))
            markDirty()
        end
    end

    local removeIdx
    for i, ut in ipairs(cfg.userThemes) do
        if imgui.Button(ut.name .. "##ut" .. i, imgui.ImVec2(-60, 34)) then
            cfg.theme = sanitizeTheme(ut)
            themeChanged()
        end
        imgui.SameLine()
        if imgui.Button("X##utdel" .. i, imgui.ImVec2(-1, 34)) then removeIdx = i end
    end
    if removeIdx then
        table.remove(cfg.userThemes, removeIdx)
        markDirty()
    end
end

local function drawColorsTab()
    local t = cfg.theme
    header("Все цвета темы")
    imgui.TextWrapped("Нажмите на цветной квадрат, чтобы изменить цвет. Последний ползунок отвечает за прозрачность.")
    imgui.Separator()
    for _, kv in ipairs(COLOR_KEYS) do
        local k = kv[1]
        local c = t.colors[k]
        local buf = uiColors[k]
        buf[0], buf[1], buf[2], buf[3] = c[1], c[2], c[3], c[4]
        if imgui.ColorEdit4(kv[2] .. "##col" .. k, buf) then
            t.colors[k] = {buf[0], buf[1], buf[2], buf[3]}
            themeChanged()
        end
    end
end

local function drawShapesTab()
    local t = cfg.theme
    header("Форма элементов")
    for _, s in ipairs(SIZE_LIST) do
        imgui.Text(s[2] .. ":")
        imgui.PushItemWidth(-1)
        if sliderInt("##size" .. s[1], t.sizes, s[1], s[3], s[4]) then themeChanged() end
        imgui.PopItemWidth()
    end
    if imgui.Button("Сбросить форму##shapereset", imgui.ImVec2(-1, 34)) then
        t.sizes = copyTable(SIZE_DEFAULTS)
        themeChanged()
    end
end

local function drawFontsTab()
    local t = cfg.theme
    header("Шрифт меню")
    if imgui.RadioButtonBool("Стандартный##fnt0", t.font == "") then
        t.font = ""
        themeChanged()
    end
    for i, name in ipairs(fontNames) do
        if imgui.RadioButtonBool(name .. "##fnt" .. i, t.font == name) then
            t.font = name
            themeChanged()
        end
    end
    if t.font ~= "" and not fonts[t.font] then
        imgui.TextColored(imgui.ImVec4(1, 0.6, 0.3, 1), "Выбранный шрифт ещё не загружен: перезапустите игру")
    end

    imgui.Separator()
    plainText("Масштаб текста, %:")
    imgui.PushItemWidth(-1)
    if sliderInt("##fscale", t, 'fontScale', 50, 200) then themeChanged() end
    imgui.PopItemWidth()

    imgui.Separator()
    header("Свои шрифты")
    imgui.TextWrapped("1. Положите файл .ttf в папку moonloader/resource/fonts.\n2. Впишите имя файла ниже (например MyFont.ttf) и нажмите «Добавить».\n3. Перезапустите игру: новые шрифты подхватываются только при запуске.")
    imgui.PushItemWidth(-1)
    imgui.InputText("##fontadd", fontAddBuf, ffi.sizeof(fontAddBuf))
    imgui.PopItemWidth()
    if imgui.Button("Добавить шрифт##fadd", imgui.ImVec2(-1, 34)) then
        local name = ffi.string(fontAddBuf)
        if safeFileName(name) then
            table.insert(cfg.fontFiles, name)
            ffi.fill(fontAddBuf, ffi.sizeof(fontAddBuf))
            markDirty()
            status = "Шрифт добавлен в список. Перезапустите игру."
        else
            status = "Имя файла: только латинские буквы, цифры, точка, минус и подчёркивание."
        end
    end
    imgui.Text("Размер шрифта при загрузке, px (нужен перезапуск):")
    imgui.PushItemWidth(-1)
    if sliderInt("##fsize", cfg, 'fontSize', 12, 40) then markDirty() end
    imgui.PopItemWidth()
    imgui.TextWrapped("Шрифт должен содержать русские буквы, иначе вместо них будут квадраты.")
    if status ~= "" then plainText(status) end
end

local function drawShareTab()
    local t = cfg.theme

    header("Обмен кодом (текстом)")
    imgui.TextWrapped("Нажмите «Показать код текущей темы», выделите и скопируйте текст из поля ниже и отправьте другу. Чтобы получить чужую тему, вставьте её код в поле и нажмите «Применить код».")
    if imgui.InputTextMultiline("##code", codeBuf, ffi.sizeof(codeBuf), imgui.ImVec2(-1, 130)) then
        status = ""
    end
    if imgui.Button("Показать код текущей темы##showcode", imgui.ImVec2(-1, 34)) then
        local code = exportCode(t)
        if code then
            setBuf(codeBuf, code)
            status = "Код готов. Скопируйте его из поля."
        else
            status = "Не удалось собрать код."
        end
    end
    if imgui.Button("Скопировать в буфер обмена##copycode", imgui.ImVec2(-1, 34)) then
        local ok = pcall(imgui.SetClipboardText, ffi.string(codeBuf))
        status = ok and "Скопировано (если буфер не сработал, выделите текст вручную)." or "Буфер обмена недоступен, скопируйте вручную."
    end
    if imgui.Button("Вставить из буфера обмена##pastecode", imgui.ImVec2(-1, 34)) then
        local ok, txt = pcall(imgui.GetClipboardText)
        if ok and type(txt) == 'string' then
            setBuf(codeBuf, txt)
            status = "Вставлено из буфера."
        else
            status = "Буфер обмена недоступен, вставьте текст в поле вручную."
        end
    end
    if imgui.Button("Применить код##applycode", imgui.ImVec2(-1, 34)) then
        local imported, err = importCode(ffi.string(codeBuf))
        if imported then
            cfg.theme = imported
            themeChanged()
            status = "Тема «" .. imported.name .. "» применена."
        else
            status = "Ошибка: " .. tostring(err)
        end
    end

    imgui.Separator()
    header("Обмен файлом")
    imgui.TextWrapped("Файлы тем лежат в папке config/parovozov_themes. Для обмена отправьте файл .json, а получателю положите его в такую же папку.")
    imgui.PushItemWidth(-1)
    imgui.InputText("##filename", fileBuf, ffi.sizeof(fileBuf))
    imgui.PopItemWidth()
    if imgui.Button("Сохранить тему в файл##tofile", imgui.ImVec2(-1, 34)) then
        local name = ffi.string(fileBuf)
        if name == "" then name = t.name end
        local path, safe = themeFilePath(name)
        local code = exportCode(t)
        if not doesDirectoryExist(themesDir) then createDirectory(themesDir) end
        local f = code and io.open(path, 'w')
        if f then
            f:write(code)
            f:close()
            status = "Сохранено: config/parovozov_themes/" .. safe .. ".json"
        else
            status = "Не удалось сохранить файл."
        end
    end
    if imgui.Button("Загрузить тему из файла##fromfile", imgui.ImVec2(-1, 34)) then
        local name = ffi.string(fileBuf)
        local path, safe = themeFilePath(name)
        if name == "" then
            status = "Впишите имя файла (без .json)."
        elseif not doesFileExist(path) then
            status = "Файл не найден: config/parovozov_themes/" .. safe .. ".json"
        else
            local f = io.open(path, 'r')
            local content = f and f:read('*a')
            if f then f:close() end
            local imported, err = importCode(content)
            if imported then
                cfg.theme = imported
                themeChanged()
                status = "Тема «" .. imported.name .. "» загружена."
            else
                status = "Ошибка: " .. tostring(err)
            end
        end
    end

    local okLfs, lfs = pcall(require, 'lfs')
    if okLfs and type(lfs) == 'table' and doesDirectoryExist(themesDir) then
        imgui.Text("Найденные файлы:")
        pcall(function()
            for f in lfs.dir(themesDir) do
                if f:lower():match("%.json$") then
                    if imgui.Button(f .. "##tf" .. f) then
                        setBuf(fileBuf, (f:gsub("%.json$", "")))
                    end
                end
            end
        end)
    end

    if status ~= "" then plainText(status) end
end

local TABS = {
    {"Темы", drawThemesTab},
    {"Цвета", drawColorsTab},
    {"Форма", drawShapesTab},
    {"Шрифты", drawFontsTab},
    {"Обмен", drawShareTab},
}

-- =========================================================
-- ВКЛАДКА В ХАБЕ И ЖИЗНЬ МОДУЛЯ
-- =========================================================

-- пять внутренних вкладок: кнопки переносятся на новую строку, если не помещаются
local function drawTab()
    local avail = imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x * 2
    local spacing = imgui.GetStyle().ItemSpacing.x
    local perRow = math.max(1, math.floor((avail + spacing) / (110 + spacing)))
    for i, tab in ipairs(TABS) do
        if i > 1 and (i - 1) % perRow ~= 0 then imgui.SameLine() end
        local active = currentTab == i
        if active then
            local c = imgui.GetStyle().Colors[imgui.Col.ButtonHovered] or imgui.ImVec4(0.5, 0.3, 0.9, 1.0)
            imgui.PushStyleColor(imgui.Col.Button, c)
        end
        if imgui.Button(tab[1] .. "###ttab" .. i, imgui.ImVec2(110, 36)) then
            currentTab = i
            status = ""
        end
        if active then imgui.PopStyleColor(1) end
    end
    imgui.Separator()

    local tab = TABS[currentTab]
    if tab then tab[2]() end
end

local lastSave, applyAt = os.clock(), nil

local function init()
    sampRegisterChatCommand("themes", function() X.openTab("Темы") end)
    -- другие скрипты могли выставить свой стиль при запуске, поэтому применяем тему ещё раз
    applyAt = os.clock() + 1.5
end

local function tick()
    if applyAt and os.clock() >= applyAt then
        applyAt = nil
        if X.themeOn() then applyTheme() end
    end
    if dirty and os.clock() - lastSave > 2 then
        saveConfig()
        lastSave = os.clock()
    end
end

local function stop()
    if dirty then saveConfig() end
end

-- вернуть шрифт и масштаб по умолчанию, когда тема выключена
local function revert()
    pcall(function()
        local io = imgui.GetIO()
        io.FontGlobalScale = 1.0
        io.FontDefault = nil
    end)
end

X.afterStyle = applyTheme
X.tickers[#X.tickers + 1] = tick
X.stoppers[#X.stoppers + 1] = stop

return {init = init, drawTab = drawTab, apply = applyTheme, revert = revert, cfg = cfg}
end)()

-- ---------- вкладки встроенных модулей ----------

-- отдельные файлы старых скриптов: подсказка, что их надо убрать
function X.standaloneNote(name, file)
    if X.standalone(name) then
        imgui.TextColored(imgui.ImVec4(1, 0.4, 0.4, 1), "Отдельный " .. file .. " тоже запущен.")
        imgui.TextWrapped("Встроенный модуль пока отключён, чтобы не было двух копий. Удалите " .. file .. " из папки moonloader и перезапустите игру.")
    else
        imgui.TextWrapped("Теперь модуль встроен в хаб. Если отдельный файл " .. file .. " ещё лежит в папке moonloader, удалите его.")
    end
end

function T.drawChatWinTab()
    local mod = X.chatMod
    header("Свой чат")
    imgui.TextWrapped("Отдельное окно чата вместо родного: вкладки Все, Общий, Личные, Система, поиск, лог в файл. Строки MultiTools тоже показываются в нём. Те же настройки есть в самом окне по кнопке «Настр.».")
    X.standaloneNote("Parovozov Chat", "Parovozov_chat.lua")
    if mod.isDup() then return end
    local proxy = X.ui.chatProxy
    if not proxy then
        proxy = {}
        X.ui.chatProxy = proxy
    end
    proxy.enabled = mod.enabled()
    if checkbox("Свой чат включён##pcen", proxy, 'enabled') then mod.setEnabled(proxy.enabled) end
    imgui.TextWrapped("Команды: /pchat включает и выключает чат, /pchatset открывает настройки в самом окне чата.")
    sep()
    mod.drawSettings()
end

function T.drawThemesTab()
    local mod = X.themeMod
    header("Темы и шрифты")
    if checkbox("Применять тему из этой вкладки##usetheme", cfg.ui, 'useTheme') then
        if cfg.ui.useTheme then mod.apply() else mod.revert() end
        applyStyle()
    end
    imgui.TextWrapped("Выключено: окна красятся цветом из вкладки «Вид». Любая правка темы здесь включает её сама. Тема действует на все скрипты с mimgui, у которых нет своей.")
    X.standaloneNote("Parovozov Themes", "Parovozov_themes.lua")
    sep()
    mod.drawTab()
end

-- END EMBEDDED MODULES

local TABS = {
    {"FPS", T.drawOptTab},
    {"Мир", T.drawWorldTab},
    {"Анимации", T.drawAnimTab},
    {"Экран", T.drawScreenTab},
    {"Заметки", T.drawNotesTab},
    {"Профили", T.drawProfilesTab},
    {"Вход", T.drawLoginTab},
    {"Вид", T.drawViewTab},
    {"Кнопки", T.drawButtonsTab},
    {"Чат", T.drawChatTab},
    {"Метки", T.drawMarksTab},
    {"Маска", T.drawMaskTab},
    {"Обмен", T.drawShareTab},
    {"Журнал", T.drawLogTab},
    {"Таймеры", T.drawTimersTab},
    {"Шаблоны", T.drawTplTab},
    {"График", T.drawGraphTab},
    {"Свой чат", T.drawChatWinTab},
    {"Темы", T.drawThemesTab},
}

-- открыть меню сразу на нужной вкладке (команда /themes)
function X.openTab(name)
    for i, tb in ipairs(TABS) do
        if tb[1] == name then currentTab = i end
    end
    window[0] = true
end

-- =========================================================
-- ОКНА
-- =========================================================

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    applyStyle()
    for _, f in ipairs(X.initHooks) do pcall(f) end
end)

-- размер окна меню: в процентах экрана, кнопки внизу и ползунки на вкладке «Экран»
X.win = {apply = false, px = nil, py = nil, full = false, prevW = 38, prevH = 48}

function X.winResize(dw, dh)
    local U = cfg.ui
    U.winW = math.max(30, math.min(100, U.winW + dw))
    U.winH = math.max(25, math.min(100, U.winH + dh))
    X.win.full = false
    X.win.apply = true
    markDirty()
end

function X.winFullToggle()
    local U, W = cfg.ui, X.win
    if U.winW >= 99 and U.winH >= 99 then
        U.winW, U.winH = W.prevW, W.prevH
        W.full = false
    else
        W.prevW, W.prevH = U.winW, U.winH
        U.winW, U.winH = 100, 100
        W.full = true
    end
    W.apply = true
    markDirty()
end

X.frame(
    function() return window[0] end,
    function()
        local sw, sh = getScreenResolution()
        local U, W = cfg.ui, X.win
        local wpx, hpx = sw * U.winW / 100, sh * U.winH / 100
        if W.apply then
            -- размер изменили кнопкой или ползунком: ставим принудительно и держим окно на экране
            local px = W.px or (sw - wpx) / 2
            local py = W.py or (sh - hpx) / 2
            px = math.max(0, math.min(px, math.max(0, sw - wpx)))
            py = math.max(0, math.min(py, math.max(0, sh - hpx)))
            if W.full then px, py = 0, 0 end
            imgui.SetNextWindowPos(imgui.ImVec2(px, py), imgui.Cond.Always)
            imgui.SetNextWindowSize(imgui.ImVec2(wpx, hpx), imgui.Cond.Always)
            W.apply = false
        else
            imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
            imgui.SetNextWindowSize(imgui.ImVec2(wpx, hpx), imgui.Cond.FirstUseEver)
        end

        if imgui.Begin("Parovozov MultiTools | v1.1", window) then
            -- вкладки в несколько рядов, чтобы подписи помещались
            local count = #TABS
            local rows = math.ceil(count / 7)
            local perRow = math.ceil(count / rows)
            local spacing = imgui.GetStyle().ItemSpacing.x
            local area = imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x * 2

            for r = 0, rows - 1 do
                local first = r * perRow + 1
                local last = math.min(count, first + perRow - 1)
                local w = (area - spacing * (last - first)) / (last - first + 1)
                for i = first, last do
                    if i > first then imgui.SameLine() end
                    tabButton(TABS[i][1], i, w)
                end
            end

            sep()

            imgui.BeginChild('HubContent', imgui.ImVec2(0, -46), true)
            local tab = TABS[currentTab]
            if tab then tab[2]() end
            imgui.EndChild()

            -- полоса размера окна: крупные кнопки под палец
            local bw = (imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x * 2
                - imgui.GetStyle().ItemSpacing.x * 4) / 5
            if imgui.Button("Выше##winh+", imgui.ImVec2(bw, 34)) then X.winResize(0, 8) end
            imgui.SameLine()
            if imgui.Button("Ниже##winh-", imgui.ImVec2(bw, 34)) then X.winResize(0, -8) end
            imgui.SameLine()
            if imgui.Button("Шире##winw+", imgui.ImVec2(bw, 34)) then X.winResize(8, 0) end
            imgui.SameLine()
            if imgui.Button("Уже##winw-", imgui.ImVec2(bw, 34)) then X.winResize(-8, 0) end
            imgui.SameLine()
            local full = U.winW >= 99 and U.winH >= 99
            if imgui.Button((full and "Обычный" or "Весь экран") .. "##winfull", imgui.ImVec2(bw, 34)) then
                X.winFullToggle()
            end

            -- запоминаем положение и размер, если окно двигали или тянули вручную
            local pos, size = imgui.GetWindowPos(), imgui.GetWindowSize()
            if pos and size and sw > 0 and sh > 0 and not W.apply then
                W.px, W.py = pos.x, pos.y
                local nw = math.max(30, math.min(100, size.x / sw * 100))
                local nh = math.max(25, math.min(100, size.y / sh * 100))
                if math.abs(nw - U.winW) >= 1 or math.abs(nh - U.winH) >= 1 then
                    U.winW, U.winH = math.floor(nw + 0.5), math.floor(nh + 0.5)
                    markDirty()
                end
            end
        end
        imgui.End()
    end
)

-- Информационная панель
X.frame(
    function() return cfg.overlay.enabled and not hudHidden end,
    function(self)
        self.HideCursor = true

        local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize
            + imgui.WindowFlags.NoSavedSettings
        if imgui.WindowFlags.NoInputs then flags = flags + imgui.WindowFlags.NoInputs end

        imgui.SetNextWindowPos(imgui.ImVec2(cfg.overlay.x, cfg.overlay.y))
        imgui.SetNextWindowBgAlpha(cfg.overlay.alpha / 100)
        imgui.Begin("##hubstats", nil, flags)
        imgui.SetWindowFontScale(cfg.overlay.scale / 100)

        if cfg.overlay.fps then
            imgui.Text(string.format("FPS: %d", math.floor(imgui.GetIO().Framerate)))
        end
        if cfg.overlay.ping then
            local ping = -1
            if myId >= 0 then
                local ok, p = pcall(sampGetPlayerPing, myId)
                if ok and p then ping = p end
            end
            imgui.Text(string.format("Ping: %d", ping))
        end
        if cfg.overlay.clock then
            imgui.Text(os.date("%H:%M:%S"))
        end
        if cfg.overlay.counts then
            imgui.Text(string.format("Рядом: %d игр., %d тр.", live.p, live.v))
        end

        imgui.End()
    end
)

-- ---------- Свой HUD, спидометр, прицел, тонировка ----------

local function overlayFlags()
    local f = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove
        + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoSavedSettings
        + imgui.WindowFlags.AlwaysAutoResize
    if imgui.WindowFlags.NoInputs then f = f + imgui.WindowFlags.NoInputs end
    return f
end

local function drawBar(dl, x, y, w, h, frac, fill, label)
    frac = math.max(0, math.min(1, frac or 0))
    dl:AddRectFilled(imgui.ImVec2(x, y), imgui.ImVec2(x + w, y + h), col(0, 0, 0, 0.55), h / 2)
    if frac > 0 then
        dl:AddRectFilled(imgui.ImVec2(x, y), imgui.ImVec2(x + w * frac, y + h), fill, h / 2)
    end
    if label then
        local ts = imgui.CalcTextSize(label)
        dl:AddText(imgui.ImVec2(x + (w - ts.x) / 2, y + (h - ts.y) / 2), col(1, 1, 1, 1), label)
    end
end

-- Панель статуса: здоровье, броня, деньги, часы
X.frame(
    function() return cfg.view.hudOn and not hudHidden end,
    function(self)
        self.HideCursor = true
        local v = cfg.view
        local rows = (v.hpOn and 1 or 0) + (v.armorOn and 1 or 0) + ((v.moneyOn or v.clockOn) and 1 or 0)
        if rows == 0 then return end

        local sw, sh = getScreenResolution()
        local s = v.hudScale / 100
        local w, h = 230 * s, 22 * s

        imgui.SetNextWindowPos(imgui.ImVec2(sw * v.hudXp / 100, sh * v.hudYp / 100))
        imgui.SetNextWindowBgAlpha(0.35)
        imgui.Begin("##hubhud", nil, overlayFlags())
        local dl = imgui.GetWindowDrawList()

        if v.hpOn then
            local p = imgui.GetCursorScreenPos()
            drawBar(dl, p.x, p.y, w, h, viewState.hp / viewState.maxHp,
                col(0.90, 0.20, 0.25, 1), string.format("%d", math.floor(viewState.hp)))
            imgui.Dummy(imgui.ImVec2(w, h + 4))
        end
        if v.armorOn then
            local p = imgui.GetCursorScreenPos()
            drawBar(dl, p.x, p.y, w, h, viewState.armor / 100,
                col(0.25, 0.55, 0.95, 1), string.format("%d", math.floor(viewState.armor)))
            imgui.Dummy(imgui.ImVec2(w, h + 4))
        end
        if v.moneyOn or v.clockOn then
            local p = imgui.GetCursorScreenPos()
            local white = col(1, 1, 1, 1)
            if v.moneyOn then
                local text = viewState.money and ("Деньги: " .. fmtMoney(viewState.money)) or "Деньги: нет данных"
                dl:AddText(imgui.ImVec2(p.x, p.y), white, text)
            end
            if v.clockOn then
                local t = os.date("%H:%M")
                local ts = imgui.CalcTextSize(t)
                dl:AddText(imgui.ImVec2(p.x + w - ts.x, p.y), white, t)
            end
            imgui.Dummy(imgui.ImVec2(w, 20 * s))
        end

        imgui.End()
    end
)

-- Спидометр (виден только в машине)
X.frame(
    function() return cfg.view.speedOn and viewState.inCar and not hudHidden end,
    function(self)
        self.HideCursor = true
        local v = cfg.view
        local sw, sh = getScreenResolution()
        local s = v.speedScale / 100
        local w, h = 180 * s, 16 * s

        imgui.SetNextWindowPos(imgui.ImVec2(sw * v.speedXp / 100, sh * v.speedYp / 100))
        imgui.SetNextWindowBgAlpha(0.35)
        imgui.Begin("##hubspeed", nil, overlayFlags())

        imgui.SetWindowFontScale(2.0 * s)
        imgui.Text(string.format("%d", math.floor(viewState.speed)))
        imgui.SetWindowFontScale(1.0)
        imgui.SameLine()
        imgui.Text("км/ч")

        local dl = imgui.GetWindowDrawList()
        local p = imgui.GetCursorScreenPos()
        local frac = viewState.speed / 200
        local fill = col(0.30 + 0.65 * math.min(frac, 1), 0.85 - 0.55 * math.min(frac, 1), 0.35, 1)
        drawBar(dl, p.x, p.y, w, h, frac, fill, nil)
        imgui.Dummy(imgui.ImVec2(w, h + 4))

        if v.carHpOn then
            local pp = imgui.GetCursorScreenPos()
            local carFrac = viewState.carHp / 1000
            drawBar(dl, pp.x, pp.y, w, h, carFrac,
                col(0.95 - 0.7 * carFrac, 0.30 + 0.55 * carFrac, 0.25, 1),
                string.format("Авто: %d%%", math.floor(math.max(0, math.min(carFrac, 1)) * 100)))
            imgui.Dummy(imgui.ImVec2(w, h + 4))
        end

        imgui.End()
    end
)

-- Стрелка к выбранной метке и расстояние
X.frame(
    function() return cfg.marks.on and cfg.marks.target > 0 and marks.nav.active and not hudHidden end,
    function(self)
        self.HideCursor = true
        local M, nav = cfg.marks, marks.nav
        local sw, sh = getScreenResolution()
        local s = M.scale / 100
        imgui.SetNextWindowPos(imgui.ImVec2(sw * M.xp / 100, sh * M.yp / 100))
        imgui.SetNextWindowBgAlpha(M.alpha / 100)
        imgui.Begin("##hubmarks", nil, overlayFlags())
        imgui.SetWindowFontScale(s)

        local R = 22 * s
        local p = imgui.GetCursorScreenPos()
        if nav.rel then
            local cx, cy = p.x + R, p.y + R
            local a = math.rad(nav.rel)
            local function pt(ang, rad) return imgui.ImVec2(cx + math.sin(ang) * rad, cy - math.cos(ang) * rad) end
            local c = col(uiTheme[0], uiTheme[1], uiTheme[2], 1.0)
            imgui.GetWindowDrawList():AddTriangleFilled(pt(a, R), pt(a + math.rad(145), R * 0.8),
                pt(a - math.rad(145), R * 0.8), c)
        end
        imgui.Dummy(imgui.ImVec2(2 * R, 2 * R))
        imgui.SameLine()
        imgui.BeginGroup()
        imgui.TextUnformatted(nav.name ~= "" and nav.name or "Метка")
        if nav.other then
            imgui.TextUnformatted("другой интерьер")
        elseif nav.dist then
            imgui.TextUnformatted(fmtDist(nav.dist) .. (nav.compass and ("  " .. nav.compass) or ""))
        else
            imgui.TextUnformatted("нет данных")
        end
        imgui.EndGroup()
        imgui.End()
    end
)

-- Таймер маски
X.frame(
    function()
        if hudHidden or not cfg.mask.show then return false end
        if cfg.mask.showIdle or os.clock() < mask.flashUntil then return true end
        return (mask.phase(os.time())) ~= 'idle'
    end,
    function(self)
        self.HideCursor = true
        local M = cfg.mask
        local sw, sh = getScreenResolution()
        local s = M.scale / 100
        imgui.SetNextWindowPos(imgui.ImVec2(sw * M.xp / 100, sh * M.yp / 100))
        imgui.SetNextWindowBgAlpha(M.alpha / 100)
        imgui.Begin("##hubmask", nil, overlayFlags())
        imgui.SetWindowFontScale(s)

        local phase, left = mask.phase(os.time())
        local white = imgui.ImVec4(1, 1, 1, 1)
        if phase == 'active' then
            local total = math.max(mask.total, left, 1)
            local frac = math.max(0, math.min(1, left / total))
            local red = M.warn > 0 and left <= M.warn * 60
            local color = red and imgui.ImVec4(1.0, 0.3, 0.3, 1)
                or (frac < 0.5 and imgui.ImVec4(1.0, 0.8, 0.2, 1) or imgui.ImVec4(0.4, 1.0, 0.5, 1))
            imgui.TextUnformatted("Маска")
            imgui.SetWindowFontScale(s * 1.8)
            imgui.TextColored(color, fmtClock(left))
            imgui.SetWindowFontScale(s)
            local w = 150 * s
            local p = imgui.GetCursorScreenPos()
            drawBar(imgui.GetWindowDrawList(), p.x, p.y, w, 8 * s, frac,
                col(color.x, color.y, color.z, 1), nil)
            imgui.Dummy(imgui.ImVec2(w, 12 * s))
        elseif phase == 'cooldown' then
            imgui.TextUnformatted("Маска: пауза")
            imgui.SetWindowFontScale(s * 1.8)
            imgui.TextColored(imgui.ImVec4(0.6, 0.75, 1.0, 1), fmtClock(left))
            imgui.SetWindowFontScale(s)
        elseif os.clock() < mask.flashUntil then
            local on = math.floor(os.clock() * 2) % 2 == 0
            imgui.TextColored(on and imgui.ImVec4(1.0, 0.3, 0.3, 1) or white, "Маска закончилась")
        else
            imgui.TextUnformatted("Маска: таймер не запущен")
        end
        imgui.End()
    end
)

-- ---------- 1.2: рамка уведомления, окно таймеров, сбор графика ----------

-- мигающая рамка по краям экрана и строка сверху
X.frame(
    function() return os.clock() < X.alert.untilT end,
    function(self)
        self.HideCursor = true
        local A, al = cfg.alert, X.alert
        local sw, sh = getScreenResolution()
        local left = al.untilT - os.clock()
        -- мигаем два раза в секунду, в последнюю четверть секунды плавно гаснем
        local on = math.floor(os.clock() * 4) % 2 == 0
        local fade = math.min(1, left * 4)
        local a = (on and 0.9 or 0.35) * fade
        local c = col(A.color[1], A.color[2], A.color[3], a)
        local dl = imgui.GetForegroundDrawList()
        local t = A.thick
        dl:AddRectFilled(imgui.ImVec2(0, 0), imgui.ImVec2(sw, t), c)
        dl:AddRectFilled(imgui.ImVec2(0, sh - t), imgui.ImVec2(sw, sh), c)
        dl:AddRectFilled(imgui.ImVec2(0, t), imgui.ImVec2(t, sh - t), c)
        dl:AddRectFilled(imgui.ImVec2(sw - t, t), imgui.ImVec2(sw, sh - t), c)

        if A.banner and al.text ~= "" and not hudHidden then
            imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, t + 8), imgui.Cond.Always, imgui.ImVec2(0.5, 0))
            imgui.SetNextWindowBgAlpha(0.75 * fade)
            imgui.Begin("##hubalert", nil, overlayFlags())
            imgui.TextColored(imgui.ImVec4(A.color[1], A.color[2], A.color[3], 1), "!")
            imgui.SameLine()
            imgui.TextUnformatted(al.text)
            imgui.End()
        end
    end
)

-- запущенные таймеры
X.frame(
    function()
        if hudHidden or not cfg.timers.show then return false end
        return X.timers.running() > 0
    end,
    function(self)
        self.HideCursor = true
        local C = cfg.timers
        local sw, sh = getScreenResolution()
        local s = C.scale / 100
        imgui.SetNextWindowPos(imgui.ImVec2(sw * C.xp / 100, sh * C.yp / 100))
        imgui.SetNextWindowBgAlpha(C.alpha / 100)
        imgui.Begin("##hubtimers", nil, overlayFlags())
        imgui.SetWindowFontScale(s)
        local now = os.time()
        for _, t in ipairs(C.list) do
            local left = t.endAt - now
            if left > 0 then
                local red = t.warn > 0 and left <= t.warn * 60
                local color = red and imgui.ImVec4(1.0, 0.3, 0.3, 1) or imgui.ImVec4(0.55, 0.95, 0.6, 1)
                imgui.TextUnformatted(t.name)
                imgui.SameLine()
                imgui.TextColored(color, fmtClock(left))
                local w = 150 * s
                local p = imgui.GetCursorScreenPos()
                local frac = math.max(0, math.min(1, left / X.timers.total(t, left)))
                drawBar(imgui.GetWindowDrawList(), p.x, p.y, w, 5 * s, frac, col(color.x, color.y, color.z, 1), nil)
                imgui.Dummy(imgui.ImVec2(w, 8 * s))
            end
        end
        imgui.End()
    end
)

-- раз в секунду записывает FPS и пинг для графика (рисовать ничего не нужно)
do
    local lastSample = 0
    X.frame(
        function() return cfg.graph.enabled end,
        function(self)
            local now = os.clock()
            if now - lastSample < 1 then return end
            lastSample = now
            X.graphPush(math.floor(imgui.GetIO().Framerate + 0.5))
        end
    )
end

-- Свой прицел по центру экрана
X.frame(
    function()
        return cfg.view.crossOn and not hudHidden
            and (not cfg.view.crossOnlyArmed or viewState.armed or window[0])
    end,
    function(self)
        self.HideCursor = true
        local v = cfg.view
        local sw, sh = getScreenResolution()
        local cx, cy = sw * v.crossXp / 100, sh * v.crossYp / 100
        local c = col(v.crossColor[1], v.crossColor[2], v.crossColor[3], 1.0)
        local g, sz, t = v.crossGap, v.crossSize, v.crossThick
        local dl = imgui.GetForegroundDrawList()
        dl:AddLine(imgui.ImVec2(cx - g - sz, cy), imgui.ImVec2(cx - g, cy), c, t)
        dl:AddLine(imgui.ImVec2(cx + g, cy), imgui.ImVec2(cx + g + sz, cy), c, t)
        dl:AddLine(imgui.ImVec2(cx, cy - g - sz), imgui.ImVec2(cx, cy - g), c, t)
        dl:AddLine(imgui.ImVec2(cx, cy + g), imgui.ImVec2(cx, cy + g + sz), c, t)
        if v.crossDot then dl:AddCircleFilled(imgui.ImVec2(cx, cy), t, c, 12) end
    end
)

-- Тонировка экрана: цвет, яркость, виньетка (поверх картинки)
local function drawVignette(dl, sw, sh, strength)
    local edge, clear = col(0, 0, 0, strength), col(0, 0, 0, 0)
    local tw, th = sw * 0.22, sh * 0.28
    dl:AddRectFilledMultiColor(imgui.ImVec2(0, 0), imgui.ImVec2(sw, th), edge, edge, clear, clear)
    dl:AddRectFilledMultiColor(imgui.ImVec2(0, sh - th), imgui.ImVec2(sw, sh), clear, clear, edge, edge)
    dl:AddRectFilledMultiColor(imgui.ImVec2(0, 0), imgui.ImVec2(tw, sh), edge, clear, clear, edge)
    dl:AddRectFilledMultiColor(imgui.ImVec2(sw - tw, 0), imgui.ImVec2(sw, sh), clear, edge, edge, clear)
end

X.frame(
    function() return cfg.view.tintOn end,
    function(self)
        self.HideCursor = true
        local v = cfg.view
        local sw, sh = getScreenResolution()
        local dl = imgui.GetBackgroundDrawList()
        local p1, p2 = imgui.ImVec2(0, 0), imgui.ImVec2(sw, sh)
        if v.tintAlpha > 0 then
            dl:AddRectFilled(p1, p2, col(v.tintColor[1], v.tintColor[2], v.tintColor[3], v.tintAlpha / 100))
        end
        if v.brightness < 0 then
            dl:AddRectFilled(p1, p2, col(0, 0, 0, -v.brightness / 100))
        elseif v.brightness > 0 then
            dl:AddRectFilled(p1, p2, col(1, 1, 1, v.brightness / 200))
        end
        if v.vignette > 0 then pcall(drawVignette, dl, sw, sh, v.vignette / 100) end
    end
)

-- Сэмплер FPS для статистики (ничего не рисует)
X.frame(
    function() return true end,
    function(self)
        self.HideCursor = true
        if not stats.active then return end
        local now = os.clock()
        if now - stats.lastFpsSample >= 1 then
            stats.lastFpsSample = now
            local fps = imgui.GetIO().Framerate or 0
            if fps > stats.peakFps then stats.peakFps = fps end
            stats.fpsSum = stats.fpsSum + fps
            stats.fpsCount = stats.fpsCount + 1
        end
    end
)

-- Кнопка HUB (и кнопка «Показать», пока интерфейс скрыт)
X.frame(
    function() return cfg.ui.launcher or hudHidden end,
    function()
        local U = cfg.ui
        local s, a = U.lScale / 100, U.lAlpha / 100
        winPos('launcher', U, 'lxp', 'lyp')
        imgui.SetNextWindowBgAlpha(0.30 * a)
        imgui.Begin("##hublauncher", nil,
            imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize +
            imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoSavedSettings)
        winSave(U, 'lxp', 'lyp')
        imgui.SetWindowFontScale(s)

        -- прозрачность кнопки: тот же цвет темы, но с заданной непрозрачностью
        local r, g, b = uiTheme[0], uiTheme[1], uiTheme[2]
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(r * 0.85, g * 0.85, b * 0.85, a))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(r, g, b, a))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(r * 0.6, g * 0.6, b * 0.6, a))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 1, 1, a))
        if hudHidden then
            if imgui.Button("Показать##restore", imgui.ImVec2(0, 34 * s)) then setHudHidden(false) end
        else
            if imgui.Button("HUB##open", imgui.ImVec2(64 * s, 34 * s)) then window[0] = not window[0] end
        end
        imgui.PopStyleColor(4)
        imgui.End()
    end
)

-- Панель своих кнопок-команд
X.frame(
    function() return cfg.btn.on and #cfg.btn.list > 0 and not hudHidden end,
    function()
        local B = cfg.btn
        local s = B.scale / 100
        winPos('btn', B, 'xp', 'yp')
        imgui.SetNextWindowBgAlpha(B.alpha / 100)
        imgui.Begin("##hubbtns", nil,
            imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize +
            imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoSavedSettings)
        winSave(B, 'xp', 'yp')
        imgui.SetWindowFontScale(s)
        local shown = 0
        for i, b in ipairs(B.list) do
            if b.cmd ~= "" then
                if shown % B.cols ~= 0 then imgui.SameLine() end
                local caption = ((b.name ~= "" and b.name or b.cmd):gsub("#", ""))
                if imgui.Button(caption .. "##hbtn" .. i, imgui.ImVec2(100 * s, 38 * s)) then
                    local ok, err = btns.send(b.cmd)
                    if not ok then btns.status = "Не отправлено: " .. tostring(err) end
                end
                shown = shown + 1
            end
        end
        imgui.End()
    end
)

-- =========================================================
-- ГЛАВНАЯ ФУНКЦИЯ
-- =========================================================

local function quickToggle(key, label)
    cfg.opt[key] = not cfg.opt[key]
    requestClean = true
    markDirty()
    chat(label .. ": " .. (cfg.opt[key] and "{00FF00}скрыты" or "{FF4444}показаны"))
end

function main()
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("hub", function() window[0] = not window[0] end)
    sampRegisterChatCommand("hp", function() quickToggle('players', "Игроки") end)
    sampRegisterChatCommand("hv", function() quickToggle('vehicles', "Транспорт") end)
    sampRegisterChatCommand("ho", function() quickToggle('objects', "Объекты") end)

    sampRegisterChatCommand("nohud", function()
        setHudHidden(not hudHidden)
        chat(hudHidden and "Интерфейс скрыт, верните кнопкой «Показать» или /nohud" or "Интерфейс показан")
    end)

    sampRegisterChatCommand("settime", function(arg)
        local h, m = tostring(arg or ""):match("^(%d+)%s*(%d*)$")
        if not h then chat("Использование: /settime [час] [минута]") return end
        cfg.tw.hour = clamp(h, 0, 23)
        cfg.tw.minute = clamp(m ~= "" and m or 0, 0, 59)
        cfg.tw.timeLock = true
        markDirty()
        chat(string.format("Время: %02d:%02d", cfg.tw.hour, cfg.tw.minute))
    end)

    sampRegisterChatCommand("setweather", function(arg)
        local id = tostring(arg or ""):match("^(%d+)$")
        if not id then chat("Использование: /setweather [id 0-45]") return end
        cfg.tw.weather = clamp(id, 0, 45)
        cfg.tw.weatherLock = true
        markDirty()
        chat("Погода: " .. cfg.tw.weather)
    end)

    sampRegisterChatCommand("rc", function(arg)
        if tostring(arg or ""):lower():match("^%s*now") then
            net.userQuit = false
            if startReconnect() then
                chat("Переподключаюсь к " .. tostring(net.ip) .. ":" .. tostring(net.port))
            else
                chat("Не удалось: " .. net.status)
            end
            return
        end
        cfg.login.reconnect = not cfg.login.reconnect
        net.userQuit = false
        markDirty()
        chat("Автореконнект: " .. (cfg.login.reconnect and "{00FF00}включён" or "{FF4444}выключен"))
    end)

    sampRegisterChatCommand("al", function()
        if cfg.login.password == "" and #cfg.login.accounts == 0 then
            chat("Сначала впишите пароль: /hub, вкладка Вход")
            return
        end
        cfg.login.autologin = not cfg.login.autologin
        markDirty()
        chat("Автовход: " .. (cfg.login.autologin and "{00FF00}включён" or "{FF4444}выключен"))
    end)

    registerCommands11()
    X.regTimerCmd()
    pcall(X.chatMod.init)
    pcall(X.themeMod.init)

    chat("Загружен. Меню: {AAAAAA}/hub {FFFFFF}или кнопка HUB на экране")

    local lastNet = 0
    local lastClean, lastSave = 0, os.clock()
    local wasSpawned, wasInCar = false, false
    local timeClock, lastFrame = nil, os.clock()
    local lastView = 0
    local lastMod = 0
    local lastPosSample = 0
    X.perf.at = os.clock()

    while true do
        -- каждый кадр нужен только пока держим время и погоду; иначе хватает 30 раз в секунду
        wait((cfg.tw.timeLock or cfg.tw.weatherLock) and 0 or 30)
        local now = os.clock()
        local loopStart, cleanBefore = now, X.perf.clean

        -- Течение времени: двигаем часы и минуты сами
        local dt = math.min(now - lastFrame, 0.2)
        lastFrame = now
        if cfg.tw.timeLock and cfg.tw.flow then
            local curH = math.floor((timeClock or -1) / 60) % 24
            local curM = math.floor((timeClock or -1) % 60)
            -- если часы или минуты поменяли вручную, подхватываем новое значение
            if not timeClock or curH ~= cfg.tw.hour or curM ~= cfg.tw.minute then
                timeClock = cfg.tw.hour * 60 + cfg.tw.minute
            end
            timeClock = (timeClock + dt * cfg.tw.flowSpeed) % 1440
            cfg.tw.hour = math.floor(timeClock / 60) % 24
            cfg.tw.minute = math.floor(timeClock % 60)
        else
            timeClock = nil
        end

        -- Время и погода
        if cfg.tw.timeLock then pcall(setTimeOfDay, cfg.tw.hour, cfg.tw.minute) end
        if cfg.tw.weatherLock then pcall(forceWeatherNow, cfg.tw.weather) end

        -- Оптимизация: периодическая и по запросу
        if requestClean or now - lastClean > X.cleanInterval() then
            local force = requestClean
            requestClean = false
            lastClean = now
            local ok, err = pcall(cleanTick, force)
            if not ok then optError = tostring(err) end
        end

        -- Анимации: после спавна и выхода из машины
        local spawned = sampIsLocalPlayerSpawned()
        if spawned then
            if not wasSpawned and cfg.anim.enabled then
                lua_thread.create(function()
                    wait(1000)
                    applyAnim()
                end)
            end
            if cfg.anim.enabled then
                local inCar = isCharInAnyCar(PLAYER_PED)
                if wasInCar and not inCar then
                    lua_thread.create(function()
                        wait(150)
                        applyAnim()
                    end)
                end
                wasInCar = inCar
            else
                wasInCar = false
            end
        else
            wasInCar = false
        end
        wasSpawned = spawned

        -- Автореконнект: проверка соединения дважды в секунду
        if now - lastNet >= 0.5 then
            lastNet = now
            local okN, errN = pcall(netTick, now, spawned)
            if not okN then net.status = "ошибка: " .. tostring(errN) end
        end

        -- Таймер маски и навигация по меткам: четыре раза в секунду
        if now - lastMod >= 0.25 then
            lastMod = now
            modulesTick()
        end

        -- Статистика сессии: время, пинг и путь (телепорты отсекаются)
        stats.active = spawned
        if spawned then
            stats.onlineSec = stats.onlineSec + dt
            -- путь считаем пять раз в секунду: этого хватает, а нативов меньше
            if now - lastPosSample >= 0.2 then
                lastPosSample = now
                local okPos, x, y, z = pcall(getCharCoordinates, PLAYER_PED)
                if okPos and x then
                    if stats.lastPos then
                        local d = dist3(x, y, z, stats.lastPos[1], stats.lastPos[2], stats.lastPos[3])
                        if d < 30 then stats.distance = stats.distance + d end
                    end
                    stats.lastPos = {x, y, z}
                end
            end
            if myId >= 0 and now - stats.lastSample >= 1 then
                stats.lastSample = now
                local okP, p = pcall(sampGetPlayerPing, myId)
                if okP and type(p) == 'number' and p > 0 then
                    if p > stats.peakPing then stats.peakPing = p end
                    stats.pingSum = stats.pingSum + p
                    stats.pingCount = stats.pingCount + 1
                end
            end
        else
            stats.lastPos = nil
        end

        -- Данные для своего HUD, спидометра и прицела (10 раз в секунду)
        if (cfg.view.hudOn or cfg.view.speedOn or cfg.view.crossOn) and now - lastView >= 0.1 then
            lastView = now
            updateViewState()
        end

        -- Сохранение настроек не чаще раза в 2 секунды
        if dirty and now - lastSave > 2 then
            saveConfig()
            lastSave = now
        end

        -- Счётчик нагрузки: сколько времени за секунду съел сам Lua-код скрипта
        local pf = X.perf
        pf.loop = pf.loop + math.max(0, (os.clock() - loopStart) - (X.perf.clean - cleanBefore))
        if now - pf.at >= 1 then
            local el = now - pf.at
            pf.snap.loop, pf.snap.clean, pf.snap.frame = pf.loop / el * 1000, pf.clean / el * 1000, pf.frame / el * 1000
            pf.loop, pf.clean, pf.frame, pf.at = 0, 0, 0, now
        end
    end
end

function onScriptTerminate(scr, quitGame)
    if scr == thisScript() then
        for _, f in ipairs(X.stoppers) do pcall(f) end
        if hudHidden then
            hudHidden = false
            applyHud()
        end
        if dirty or cfg.tw.flow then saveConfig() end
    end
end
