script_author('FOREZIT')
script_name('DillBot')

local imgui    = require 'mimgui'
local encoding = require 'encoding'
local sampev   = require 'lib.samp.events'

encoding.default = 'CP1251'
local U8 = encoding.UTF8
local function cp(s) return U8:decode(s) end

local READY     = cp('готов к сбору')
local BED       = cp('Грядка')
local SKIP      = cp('растет')
local SEED_WORD = cp('семена укропа')
local SEED_PAT  = SEED_WORD .. '[^%d]*(%d+)'
local LEFT_WORD = cp('Осталось:?%s*(.*)')
local P_MIN     = cp('(%d+)%s*м')
local P_SEC     = cp('(%d+)%s*с')

local RADIUS      = 10
local STOP_DIST   = 0.5
local READ_RADIUS = 1.0
local PRESS_GAP   = 0.15
local WAIT_FROM   = 59
local STUCK_AFTER = 6
local SKIP_TIME   = 5

local botActive = false
local noSeeds   = false
local status    = ''
local lastRaw   = ''
local font

local function setStatus(raw)
    if raw == lastRaw then return end
    lastRaw = raw
    status = cp(raw)
end

local gameTimer = getGameTimer
local function clock()
    if gameTimer then return gameTimer() / 1000 end
    return os.clock()
end

local function dist2(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

local function dist3(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function try(fn, ...)
    if type(fn) ~= 'function' then return false end
    local ok, r = pcall(fn, ...)
    return ok and r
end

local pkLog, pkOwn, pkLast = false, false, 0

local function dumpBs(bs)
    local off = raknetBitStreamGetReadOffset(bs)
    raknetBitStreamResetReadPointer(bs)
    local n = raknetBitStreamGetNumberOfBytesUsed(bs)
    local t = {}
    for i = 1, math.min(n, 40) do
        t[i] = string.format('%02X', raknetBitStreamReadInt8(bs) % 256)
    end
    raknetBitStreamSetReadOffset(bs, off)
    return n, table.concat(t, ' ')
end

function onSendPacket(id, bs)
    if not pkLog or pkOwn or id ~= 220 then return end
    pcall(function()
        local n, hex = dumpBs(bs)
        sampAddChatMessage(string.format('{FFAA00}[PKT REAL] id=%d n=%d: %s', id, n, hex), -1)
    end)
end

local function sendInteract(click)
    pcall(function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 220)
        raknetBitStreamWriteInt8(bs, 63)
        raknetBitStreamWriteInt8(bs, 8)
        raknetBitStreamWriteInt32(bs, 7)
        raknetBitStreamWriteInt32(bs, -1)
        if click then raknetBitStreamWriteInt16(bs, 0) else raknetBitStreamWriteInt32(bs, 0) end
        raknetBitStreamWriteString(bs, '')
        if pkLog and clock() - pkLast > 1 then
            pkLast = clock()
            local n, hex = dumpBs(bs)
            sampAddChatMessage(string.format('{00FFAA}[PKT BOT] n=%d: %s', n, hex), -1)
        end
        pkOwn = true
        raknetSendBitStreamEx(bs, 1, 7, 1)
        pkOwn = false
        raknetDeleteBitStream(bs)
    end)
end

local function readBed(id)
    if not sampIs3dTextDefined(id) then return nil end
    local txt, _, x, y, z = sampGet3dTextInfoById(id)
    if type(txt) == 'string' and type(x) == 'number' and txt:find(BED, 1, true) then
        return { t = (txt:gsub('{%x%x%x%x%x%x}', '')), x = x, y = y, z = z }
    end
end

local scanCache, scanTime = {}, -1
local knownIds, idsTime = {}, -1
local function scan()
    local now = clock()
    if now - scanTime < 0.005 then return scanCache end
    scanTime = now

    local list, stale = {}, now - idsTime > 0.5
    if not stale then
        for _, id in ipairs(knownIds) do
            local l = readBed(id)
            if not l then stale = true; break end
            list[#list + 1] = l
        end
    end

    if stale then
        idsTime = now
        knownIds, list = {}, {}
        for id = 0, 2047 do
            local l = readBed(id)
            if l then
                knownIds[#knownIds + 1] = id
                list[#list + 1] = l
            end
        end
    end

    scanCache = list
    return list
end

local skip = {}
local function key(x, y) return math.floor(x) .. ':' .. math.floor(y) end

local function findTarget()
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    local best
    local now = clock()
    for _, l in ipairs(scan()) do
        local kind
        if l.t:find(READY, 1, true) then
            kind = 1
        elseif not noSeeds and not l.t:find(SKIP, 1, true) then
            kind = 2
        end
        if kind and (skip[key(l.x, l.y)] or 0) < now then
            local d = dist3(px, py, pz, l.x, l.y, l.z)
            if d <= RADIUS and (not best or kind < best.kind or (kind == best.kind and d < best.d)) then
                best = { kind = kind, d = d, x = l.x, y = l.y }
            end
        end
    end
    return best
end

local function hasGrowing()
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    for _, l in ipairs(scan()) do
        if l.t:find(SKIP, 1, true) and dist3(px, py, pz, l.x, l.y, l.z) <= RADIUS then
            return true
        end
    end
    return false
end

local function parseLeft(t)
    t = t:match(LEFT_WORD) or t
    local m, s = tonumber(t:match(P_MIN)), tonumber(t:match(P_SEC))
    if m or s then return (m or 0) * 60 + (s or 0) end
end

local function findSoonest()
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    local best
    for _, l in ipairs(scan()) do
        if l.t:find(SKIP, 1, true) then
            local d = dist3(px, py, pz, l.x, l.y, l.z)
            if d <= RADIUS then
                local left = parseLeft(l.t) or math.huge
                if left <= WAIT_FROM and (not best or left < best.left or (left == best.left and d < best.d)) then
                    best = { left = left, d = d, x = l.x, y = l.y }
                end
            end
        end
    end
    return best
end

local function minLeft()
    local best
    for _, l in ipairs(scan()) do
        if l.t:find(SKIP, 1, true) then
            local left = parseLeft(l.t)
            if left and (not best or left < best) then best = left end
        end
    end
    return best
end

local function bedTextAt(x, y)
    local best, bd = nil, READ_RADIUS
    for _, l in ipairs(scan()) do
        local d = dist2(x, y, l.x, l.y)
        if d < bd then best, bd = l.t, d end
    end
    return best
end

local function isNearest(x, y, px, py)
    local d0 = dist2(px, py, x, y)
    for _, l in ipairs(scan()) do
        if (l.x ~= x or l.y ~= y) and dist2(px, py, l.x, l.y) < d0 then return false end
    end
    return true
end

local function runTo(x, y, waiting)
    local closest = math.huge
    local lx, ly, lt = nil, nil, clock()
    while botActive do
        local px, py = getCharCoordinates(PLAYER_PED)
        local d = dist2(px, py, x, y)
        if d <= STOP_DIST then return true end
        if d < closest then
            closest = d
        elseif closest < 1.5 and d > closest + 0.25 and isNearest(x, y, px, py) then
            return true
        end

        if clock() - lt > 0.4 then
            if lx and d < 2.0 and dist2(px, py, lx, ly) < 0.1 and isNearest(x, y, px, py) then return true end
            lx, ly, lt = px, py, clock()
        end

        if waiting then
            if findTarget() then return false end
            local s = findSoonest()
            if not s or dist2(s.x, s.y, x, y) > 1 then return false end
        else
            local t = bedTextAt(x, y)
            if t and t:find(SKIP, 1, true) then return false end
        end

        local ang = getHeadingFromVector2d(x - px, y - py)
        setCameraPositionUnfixed(0, math.rad(ang - 90))
        setGameKeyState(1, -255)
        wait(0)
    end
    return false
end

local function workBed(x, y)
    local sent, lastT, since = -1, nil, clock()
    while botActive do
        local px, py = getCharCoordinates(PLAYER_PED)
        if not isNearest(x, y, px, py) then return end
        local t = bedTextAt(x, y)
        if not t or t:find(SKIP, 1, true) then return end
        if noSeeds and not t:find(READY, 1, true) then return end

        if t ~= lastT then lastT, since = t, clock() end
        local idle = clock() - since
        if idle > STUCK_AFTER then
            skip[key(x, y)] = clock() + SKIP_TIME
            return
        end

        setStatus((t:find(READY, 1, true) and 'Собираю' or 'Сажаю')
            .. (idle >= 1 and (' (' .. math.floor(idle) .. ' с)') or ''))

        if clock() - sent >= PRESS_GAP then
            sendInteract(idle >= 2 and math.floor(idle) % 2 == 0)
            sent = clock()
        end
        wait(0)
    end
end

local function counts()
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    local n, e, r, g, near = 0, 0, 0, 0, math.huge
    for _, l in ipairs(scan()) do
        n = n + 1
        if l.t:find(READY, 1, true) then r = r + 1
        elseif l.t:find(SKIP, 1, true) then g = g + 1
        else e = e + 1 end
        local d = dist3(px, py, pz, l.x, l.y, l.z)
        if d < near then near = d end
    end
    return n, e, r, g, near
end

local function step()
    if not botActive then return end

    if not try(isSampAvailable) or not try(sampIsLocalPlayerSpawned) then setStatus('Пауза: нет спавна'); return end
    if try(isCharInAnyCar, PLAYER_PED) then setStatus('Пауза: в машине'); return end
    if try(sampIsChatInputActive) or try(isPauseMenuActive) then setStatus('Пауза: чат или меню паузы'); return end

    local tg = findTarget()
    if not tg then
        if noSeeds and not hasGrowing() then
            botActive = false
            noSeeds = false
            sampAddChatMessage(cp('{4089ff}[DillBot]{FFFFFF} Весь укроп собран, семян нет - бот остановлен'), -1)
            return
        end
        local n, e, r, g, near = counts()
        local left = minLeft()
        setStatus(string.format('%s: грядок %d (пустых %d, готовых %d, растет %d), ближайшая %.0f м%s',
            noSeeds and 'Нет семян' or 'Нет целей', n, e, r, g, near, left and (', ' .. left .. ' сек') or ''))
        local w = findSoonest()
        if w then
            local px, py = getCharCoordinates(PLAYER_PED)
            if dist2(px, py, w.x, w.y) > STOP_DIST then runTo(w.x, w.y, true) end
        end
        return
    end

    setStatus(tg.kind == 1 and 'Бегу собирать' or 'Бегу сажать')
    if runTo(tg.x, tg.y) then workBed(tg.x, tg.y) end
end

local function botLoop()
    while true do
        wait(0)
        local ok, err = pcall(step)
        if not ok then
            print('[DillBot] ' .. tostring(err))
            lastRaw = ''
            status = 'ERROR: ' .. tostring(err):sub(1, 90)
            wait(500)
        end
    end
end

function sampev.onShowDialog(id, style, title, b1, b2, text)
    if not botActive then return end
    local all = ((tostring(title) .. '\n' .. tostring(text)):gsub('{%x%x%x%x%x%x}', ''))
    if not all:find(SEED_WORD, 1, true) then return end

    local seeds = tonumber(all:match(SEED_PAT))
    if seeds and seeds <= 0 then
        local first = not noSeeds
        noSeeds = true
        lua_thread.create(function()
            sampSendDialogResponse(id, 0, 0, '')
            if first then
                sampAddChatMessage(cp('{4089ff}[DillBot]{FFFFFF} Семена закончились, добираю весь укроп'), -1)
            end
        end)
        return false
    end

    lua_thread.create(function()
        wait(0)
        sampSendDialogResponse(id, 1, 0, '')
    end)
    return false
end

local win = imgui.new.bool(false)

imgui.OnInitialize(function()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    style.WindowPadding   = imgui.ImVec2(15, 15)
    style.WindowRounding  = 2.0
    style.FrameRounding   = 20.0
    style.ItemSpacing     = imgui.ImVec2(8, 8)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    local c = style.Colors
    c[imgui.Col.Text]          = imgui.ImVec4(0.90, 0.90, 0.93, 1.00)
    c[imgui.Col.WindowBg]      = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    c[imgui.Col.Border]        = imgui.ImVec4(0.30, 0.30, 0.35, 1.00)
    c[imgui.Col.BorderShadow]  = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    c[imgui.Col.ButtonHovered] = imgui.ImVec4(0.60, 0.60, 0.90, 1.00)
    c[imgui.Col.ButtonActive]  = imgui.ImVec4(0.60, 0.60, 0.90, 1.00)
    c[imgui.Col.Separator]     = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
end)

imgui.OnFrame(function() return win[0] end, function()
    local sw, sh = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(imgui.ImVec2(400, 100))
    imgui.Begin('DillBotMenu', win, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize)

    local col = botActive and imgui.ImVec4(0.8, 0.1, 0.1, 1.0) or imgui.ImVec4(0.1, 0.8, 0.1, 1.0)
    imgui.PushStyleColor(imgui.Col.Button, col)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(col.x + 0.1, col.y + 0.1, col.z + 0.1, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, col)
    if imgui.Button(botActive and 'STOP BOT' or 'START BOT', imgui.ImVec2(-1, 60)) then
        noSeeds = false
        skip = {}
        botActive = not botActive
    end
    imgui.PopStyleColor(3)

    imgui.End()
end)

function main()
    while not isSampAvailable() do wait(100) end
    sampRegisterChatCommand('dill', function() win[0] = not win[0] end)
    sampRegisterChatCommand('dillpk', function()
        pkLog = not pkLog
        sampAddChatMessage(cp('{4089ff}[DillBot]{FFFFFF} Лог пакетов: ') .. (pkLog and 'ON' or 'OFF'), -1)
    end)
    font = renderCreateFont('Arial', 12, 5)
    lua_thread.create(botLoop)
    while true do
        wait(0)
        if botActive then renderFontDrawText(font, 'DillBot v27: ' .. status, 20, 20, 0xFF4089FF, false) end
    end
end
