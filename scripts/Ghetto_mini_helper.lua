script_name('Ghetto Mini Helper')
script_author('pinokio')
script_version('2')

local imgui    = require 'mimgui'
local encoding = require 'encoding'
local inicfg   = require 'inicfg'
local ffi      = require 'ffi'
local sampev   = require 'lib.samp.events'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

math.randomseed(os.time())

local resX, resY = getScreenResolution()
local cfgFile = 'ghetto_mini_helper.ini'

local default = {
    grafEnabled       = true,
    grafOnlyAvailable = true,
    autoPaint         = true,
    paintSpeed        = 10,
    paintRadius       = 1.5,
    altToClickDelay   = 400,
    paintCooldown     = 100,
    drwhEnabled       = false,
    keyword           = 'Закладка',
    pritonEnabled     = true,
    pritonAutoFarm    = true,
    pritonTracer      = true,
    minDist           = 0,
    maxDist           = 300,
    drawLines         = true,
    showList          = true,
    dropEnabled       = true,
    dropSize          = 75,
    dropSpeed         = 1.0,
    dropThick         = 4,
    espArrows         = true,
    espLineToItem     = true,
    espArrowSize      = 14,
    infoX             = 20,
    infoY             = math.floor(resY / 2 - 80),
    winX              = -1,
    winY              = -1,
    winW              = 869,
    winH              = 669,
    colLineR   = 1.0,  colLineG   = 1.0,  colLineB   = 1.0,  colLineA   = 0.5,
    colGrafR   = 0.12, colGrafG   = 0.78, colGrafB   = 1.0,  colGrafA   = 1.0,
    colDrwhR   = 1.0,  colDrwhG   = 0.80, colDrwhB   = 0.20, colDrwhA   = 1.0,
    colPritonR = 0.29, colPritonG = 0.85, colPritonB = 0.50, colPritonA = 1.0,
}

local range = {
    paintSpeed      = { 1, 10 },
    paintRadius     = { 1.5, 10 },
    altToClickDelay = { 200, 3000 },
    paintCooldown   = { 100, 5000 },
    minDist         = { 0, 50 },
    maxDist         = { 10, 500 },
    dropSize        = { 20, 200 },
    dropSpeed       = { 0.3, 3.0 },
    dropThick       = { 1, 10 },
    espArrowSize    = { 6, 40 },
    infoX           = { 0, resX },
    infoY           = { 0, resY },
    winW            = { 300, resX },
    winH            = { 250, resY },
}

local function makeDefault()
    local main = {}
    for k, v in pairs(default) do main[k] = v end
    return { main = main }
end

local function normalize(main)
    for k, dv in pairs(default) do
        local v = main[k]
        local t = type(dv)
        if t == 'boolean' then
            if v == true or v == 'true' or v == 1 or v == '1' then
                v = true
            elseif v == false or v == 'false' or v == 0 or v == '0' then
                v = false
            else
                v = dv
            end
        elseif t == 'number' then
            v = tonumber(v) or dv
            local r = range[k]
            if r then v = math.max(r[1], math.min(r[2], v)) end
            if k:find('^col') then v = math.max(0, math.min(1, v)) end
            if k == 'paintSpeed' then v = math.floor(v) end
        else
            v = (v ~= nil) and tostring(v) or dv
        end
        main[k] = v
    end
    local stale = {}
    for k in pairs(main) do
        if default[k] == nil then stale[#stale + 1] = k end
    end
    for _, k in ipairs(stale) do main[k] = nil end
end

local cfg = inicfg.load(makeDefault(), cfgFile)
if type(cfg) ~= 'table' or type(cfg.main) ~= 'table' then cfg = makeDefault() end
normalize(cfg.main)

local dirty, dirtyT = false, 0

local function flush()
    dirty = false
    local dir = getWorkingDirectory() .. '/config'
    if not doesDirectoryExist(dir) then createDirectory(dir) end
    local ok, res = pcall(inicfg.save, cfg, cfgFile)
    if not ok or res == false then
        print('[Ghetto Mini Helper] config save failed: ' .. tostring(res))
    end
end

local function markDirty()
    dirty = true
    dirtyT = os.clock()
end

local winOpen     = imgui.new.bool(false)
local firstCenter = true
local kwLower     = ''
local uiBuf       = {}
local forceWin    = false
local dropTab     = false

local colorKey = { 'colLine', 'colGraf', 'colDrwh', 'colPriton' }

local ref = { keyword = imgui.new.char[64]() }
for _, k in ipairs(colorKey) do ref[k] = imgui.new.float[4]() end

local function lowerCp(s)
    s = s:gsub('[\192-\223]', function(ch) return string.char(ch:byte() + 32) end)
    s = s:gsub('\168', '\184')
    return s:lower()
end

local function setKeyword(str)
    str = tostring(str or '')
    cfg.main.keyword = str
    kwLower = lowerCp(str)
    ffi.fill(ref.keyword, 64)
    ffi.copy(ref.keyword, u8(str):sub(1, 63))
end

local function syncRef()
    local m = cfg.main
    setKeyword(m.keyword)
    for _, k in ipairs(colorKey) do
        ref[k][0], ref[k][1], ref[k][2], ref[k][3] =
            m[k .. 'R'], m[k .. 'G'], m[k .. 'B'], m[k .. 'A']
    end
end
syncRef()

local function resetCfg()
    for k, v in pairs(makeDefault().main) do cfg.main[k] = v end
    syncRef()
    firstCenter = true
    forceWin    = true
    flush()
end

imgui.OnInitialize(function()
    local io = imgui.GetIO()
    pcall(function() io.IniFilename = nil end)
    local font = '/system/fonts/Roboto-Regular.ttf'
    if doesFileExist(font) then
        pcall(function()
            io.Fonts:AddFontFromFileTTF(font, 15, nil, io.Fonts:GetGlyphRangesCyrillic())
        end)
    end
    local s = imgui.GetStyle()
    s.WindowPadding      = imgui.ImVec2(10, 10)
    s.FramePadding       = imgui.ImVec2(10, 8)
    s.ItemSpacing        = imgui.ImVec2(8, 8)
    s.WindowRounding     = 6
    s.ChildRounding      = 6
    s.FrameRounding      = 6
    s.PopupRounding      = 6
    s.ScrollbarSize      = 22
    s.GrabMinSize        = 14
    s.TouchExtraPadding  = imgui.ImVec2(6, 6)
end)

local function dist3(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function coordsOf(fn, h)
    if not h then return nil end
    local ok, a, b, c, d = pcall(fn, h)
    if not ok then return nil end
    if type(a) == 'boolean' then
        if a then return b, c, d end
        return nil
    end
    if type(a) == 'number' then return a, b, c end
    return nil
end

local function playerPos()
    if not doesCharExist(PLAYER_PED) then return nil end
    return coordsOf(getCharCoordinates, PLAYER_PED)
end

local function try(fn, ...)
    if type(fn) ~= 'function' then return false end
    local ok, r = pcall(fn, ...)
    return ok and r
end

local scanCache = { t = -10, list = {} }
local function scanTexts()
    local now = os.clock()
    if now - scanCache.t < 0.2 then return scanCache.list end
    scanCache.t = now
    local list = {}
    for id = 0, 2047 do
        if sampIs3dTextDefined(id) then
            local txt, _, x, y, z = sampGet3dTextInfoById(id)
            if type(txt) == 'string' and type(x) == 'number' then
                list[#list + 1] = { raw = txt, x = x, y = y, z = z }
            end
        end
    end
    scanCache.list = list
    return list
end

local memo, memoN = {}, 0
local function textInfo(raw)
    local e = memo[raw]
    if e then return e end
    local clean = raw:gsub('{.-}', '')
    e = { text = clean, lower = lowerCp(clean) }
    if memoN > 3000 then memo, memoN = {}, 0 end
    memo[raw] = e
    memoN = memoN + 1
    return e
end

local function isPriton(text)
    return text:find('готов к сбору', 1, true) or text:find('Укроп готов', 1, true)
end

local function collectTargets(myX, myY, myZ)
    local out, m = {}, cfg.main
    local pritonTr = m.pritonEnabled and m.pritonTracer
    for _, t in ipairs(scanTexts()) do
        local info = textInfo(t.raw)
        local text = info.text
        local g  = m.grafEnabled and text:find('Банда:', 1, true)
        local d  = m.drwhEnabled and kwLower ~= '' and info.lower:find(kwLower, 1, true)
        local pr = pritonTr and isPriton(text)
        if g or d or pr then
            local valid, tag, disp, kind = true, '', '', ''
            if g then
                if m.grafOnlyAvailable and text:find('Повторно закрасить', 1, true) then
                    valid = false
                else
                    tag, kind = 'Граффити', 'graf'
                    disp = text:match('([^\n]*)\n?') or text
                end
            elseif d then
                tag, kind = 'Закладка', 'drwh'
                disp = text
            else
                tag, kind = 'Укроп', 'priton'
                disp = 'Готов к сбору'
            end
            if valid then
                local dist = dist3(myX, myY, myZ, t.x, t.y, t.z)
                if dist >= m.minDist and dist <= m.maxDist then
                    out[#out + 1] = {
                        dist = dist, tag = tag, kind = kind,
                        text = disp, px = t.x, py = t.y, pz = t.z,
                    }
                end
            end
        end
    end
    return out
end

local function clusterTargets(list)
    table.sort(list, function(a, b) return a.dist < b.dist end)
    local out = {}
    for _, it in ipairs(list) do
        local merged = false
        for _, c in ipairs(out) do
            if c.tag == it.tag and dist3(c.px, c.py, c.pz, it.px, it.py, it.pz) <= 6.0 then
                c.n = c.n + 1
                c.sx, c.sy, c.sz = c.sx + it.px, c.sy + it.py, c.sz + it.pz
                c.px, c.py, c.pz = c.sx / c.n, c.sy / c.n, c.sz / c.n
                merged = true
                break
            end
        end
        if not merged then
            out[#out + 1] = {
                tag = it.tag, kind = it.kind, text = it.text,
                dist = it.dist, n = 1,
                sx = it.px, sy = it.py, sz = it.pz,
                px = it.px, py = it.py, pz = it.pz,
            }
        end
    end
    return out
end

local lastSend = 0
local function sendInteract(asClick, force)
    local now = os.clock()
    if not force and now - lastSend < 0.8 then return end
    lastSend = now
    pcall(function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 220)
        raknetBitStreamWriteInt8(bs, 63)
        raknetBitStreamWriteInt8(bs, 8)
        raknetBitStreamWriteInt32(bs, 7)
        raknetBitStreamWriteInt32(bs, -1)
        if asClick then
            raknetBitStreamWriteInt16(bs, 0)
        else
            raknetBitStreamWriteInt32(bs, 0)
        end
        raknetBitStreamWriteString(bs, '')
        raknetSendBitStreamEx(bs, 1, 7, 1)
        raknetDeleteBitStream(bs)
    end)
end

local spot = {}

local function clickTd(id)
    if sampSendClickTextdraw then
        if pcall(sampSendClickTextdraw, id) then return end
    end
    pcall(function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt16(bs, id)
        raknetSendRpc(83, bs)
        raknetDeleteBitStream(bs)
    end)
end

function sampev.onShowTextDraw(id, data)
    if type(data) == 'table' and data.text == 'particle:bloodpool_64' then
        spot[id] = { progress = 0, sent = 0, last = 0, born = os.clock() }
    end
end

function sampev.onTextDrawSetString(id, text)
    local sp = spot[id - 1]
    if sp and type(text) == 'string' then
        local n = tonumber(text:match('(%d+)%%'))
        if n then sp.progress = n end
    end
end

function sampev.onTextDrawHide(id)
    spot[id] = nil
end

local paintBusy = false
local function autoPaintTick()
    local m = cfg.main
    if not (m.grafEnabled and m.autoPaint) or paintBusy then return end
    if not try(sampIsLocalPlayerSpawned) then return end
    if try(sampIsDialogActive) or try(sampIsChatInputActive) or try(isPauseMenuActive) then return end

    local myX, myY, myZ = playerPos()
    if not myX then return end

    local found = false
    for _, t in ipairs(scanTexts()) do
        local text = textInfo(t.raw).text
        if text:find('Банда:', 1, true)
            and not text:find('Повторно закрасить', 1, true)
            and dist3(myX, myY, myZ, t.x, t.y, t.z) <= m.paintRadius then
            found = true
            break
        end
    end
    if not found then return end

    paintBusy = true
    lua_thread.create(function()
        pcall(function()
            sendInteract(false, true)
            wait(math.floor(m.altToClickDelay))
            sendInteract(true, true)
            local t0 = os.clock()
            while not next(spot) and os.clock() - t0 < 2.5 do wait(50) end
            local t1 = os.clock()
            while next(spot) and os.clock() - t1 < 40 do wait(100) end
            wait(math.floor(m.paintCooldown))
        end)
        paintBusy = false
    end)
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if cfg.main.pritonEnabled and cfg.main.pritonAutoFarm then
        local t1 = tostring(title):gsub('{.-}', '')
        local t2 = tostring(text):gsub('{.-}', '')
        if t1:find('ФЕРМА УКРОПА', 1, true) or t1:find('Ферма укропа', 1, true)
            or t2:find('ФЕРМА УКРОПА', 1, true) or t2:find('ПОСАДИТЬ УКРОП', 1, true)
            or t2:find('Собрать', 1, true) or t2:find('СОБРАТЬ', 1, true) then
            lua_thread.create(function()
                wait(20)
                sampSendDialogResponse(dialogId, 1, 0, '')
                pcall(sampCloseCurrentDialogWithButton, 1)
            end)
            return false
        end
    end
end

function onScriptTerminate(scr, quit)
    if scr == thisScript() then pcall(flush) end
end

local kindCol = { graf = 'colGraf', drwh = 'colDrwh', priton = 'colPriton' }

local function kindColor(m, kind)
    local p = kindCol[kind]
    return m[p .. 'R'], m[p .. 'G'], m[p .. 'B'], m[p .. 'A']
end

local function u32(r, g, b, a)
    return imgui.ColorConvertFloat4ToU32(imgui.ImVec4(r, g, b, a))
end

local function drawDrop(dl, wx, wy, seed, n, r, g, b, m)
    local k = math.min(2.4, 1 + 0.3 * (n - 1))
    local period = 1.5 / m.dropSpeed
    local phase = ((os.clock() + seed * 0.37) % period) / period
    local rad = phase * m.dropSize * k
    local a = 1.0 - phase
    if rad < 1 or a <= 0 then return end
    local center = imgui.ImVec2(wx, wy)
    local thick = m.dropThick * math.min(k, 1.6)
    dl:AddCircle(center, rad, u32(r, g, b, a), 64, thick)
    dl:AddCircle(center, rad * 0.55, u32(r, g, b, a * 0.55), 48, math.max(1, thick * 0.75))
    dl:AddCircleFilled(center, math.max(2, m.dropThick * 0.75) * math.min(k, 1.8), u32(1, 1, 1, a * 0.9), 16)
end

local function drawOffscreenArrow(dl, targetX, targetY, targetZ, color)
    local px, py, pz = coordsOf(getCharCoordinates, PLAYER_PED)
    if not px then return end

    local okh, heading = pcall(getCharHeading, PLAYER_PED)
    if not okh or type(heading) ~= 'number' then return end

    local tgt = getHeadingFromVector2d(targetX - px, targetY - py)
    if type(tgt) ~= 'number' then return end

    local diff = tgt - heading
    while diff > 180 do diff = diff - 360 end
    while diff < -180 do diff = diff + 360 end

    local rad = math.rad(diff)

    local cx, cy = resX / 2, resY / 2
    local margin = 60
    local radiusX = cx - margin
    local radiusY = cy - margin

    local dx = math.sin(rad)
    local dy = -math.cos(rad)

    local scale = math.min(
        dx ~= 0 and math.abs(radiusX / dx) or math.huge,
        dy ~= 0 and math.abs(radiusY / dy) or math.huge
    )
    if scale == math.huge or scale <= 0 then return end

    local ax = cx + dx * scale
    local ay = cy + dy * scale

    local size = cfg.main.espArrowSize or 14
    local p1 = imgui.ImVec2(ax + math.sin(rad) * size,        ay - math.cos(rad) * size)
    local p2 = imgui.ImVec2(ax + math.sin(rad + 2.6) * size * 0.6, ay - math.cos(rad + 2.6) * size * 0.6)
    local p3 = imgui.ImVec2(ax + math.sin(rad - 2.6) * size * 0.6, ay - math.cos(rad - 2.6) * size * 0.6)

    dl:AddTriangleFilled(p1, p2, p3, color)
    dl:AddTriangle(p1, p2, p3, color, 2.0)
end

local function itemLabel(item)
    if item.n > 1 then
        return string.format('[%s] %s x%d (%.1fм)', item.tag, item.text, item.n, item.dist)
    end
    return string.format('[%s] %s (%.1fм)', item.tag, item.text, item.dist)
end

local function drawEsp()
    local m = cfg.main
    local espOn = m.grafEnabled or m.drwhEnabled or (m.pritonEnabled and m.pritonTracer)
    local preview = winOpen[0] and m.showList
    local dropPrev = winOpen[0] and dropTab and m.dropEnabled
    if not espOn and not preview and not dropPrev then return end
    if not try(sampIsLocalPlayerSpawned) or try(sampIsScoreboardOpen) then return end
    local myX, myY, myZ = playerPos()
    if not myX then return end

    local dl = imgui.GetBackgroundDrawList()
    local cx = resX / 2
    local uLine = u32(m.colLineR, m.colLineG, m.colLineB, m.colLineA)
    local found = {}
    if espOn then found = clusterTargets(collectTargets(myX, myY, myZ)) end

    for _, item in ipairs(found) do
        if isPointOnScreen(item.px, item.py, item.pz, 0.0) then
            local wx, wy = convert3DCoordsToScreen(item.px, item.py, item.pz)
            if wx and wy then
                local r, g, b, a = kindColor(m, item.kind)
                if m.dropEnabled then
                    drawDrop(dl, wx, wy + 18, item.px * 3 + item.py, item.n, r, g, b, m)
                end
                if m.drawLines then
                    dl:AddLine(imgui.ImVec2(cx, resY), imgui.ImVec2(wx, wy), uLine, 2.0)
                end
                if m.espLineToItem then
                    local psx, psy = nil, nil
                    local mx, my, mz = coordsOf(getCharCoordinates, PLAYER_PED)
                    if mx then psx, psy = convert3DCoordsToScreen(mx, my, mz) end
                    if psx and psy then
                        dl:AddLine(imgui.ImVec2(psx, psy), imgui.ImVec2(wx, wy),
                                   u32(r, g, b, a), 2.0)
                    end
                end
                local str = u8(itemLabel(item))
                dl:AddText(imgui.ImVec2(wx + 1, wy + 1), 0xAA000000, str)
                dl:AddText(imgui.ImVec2(wx, wy), u32(r, g, b, a), str)
            end
        else
            if m.espArrows then
                drawOffscreenArrow(dl, item.px, item.py, item.pz, u32(1, 1, 1, 1))
            end
        end
    end

    if dropPrev then
        local r, g, b = kindColor(m, 'graf')
        drawDrop(dl, resX * 0.75, resY * 0.45, 0, 1, r, g, b, m)
    end

    if m.showList then
        local sx, sy = m.infoX, m.infoY
        local rows = math.min(#found, 8)
        if rows > 0 then
            for i = 1, rows do
                local item = found[i]
                local r, g, b, a = kindColor(m, item.kind)
                local str = u8(i .. '. ' .. itemLabel(item))
                dl:AddText(imgui.ImVec2(sx + 1, sy + (i - 1) * 20 + 1), 0xAA000000, str)
                dl:AddText(imgui.ImVec2(sx, sy + (i - 1) * 20), u32(r, g, b, a), str)
            end
        elseif winOpen[0] then
            local r, g, b, a = kindColor(m, 'priton')
            local str = u8('1. [Укроп] Готов к сбору x3 (12.3м)')
            dl:AddText(imgui.ImVec2(sx + 1, sy + 1), 0xAA000000, str)
            dl:AddText(imgui.ImVec2(sx, sy), u32(r, g, b, a), str)
        end
    end
end

local function checkBox(label, key)
    local b = uiBuf['cb_' .. key]
    if not b then
        b = imgui.new.bool(cfg.main[key])
        uiBuf['cb_' .. key] = b
    end
    b[0] = cfg.main[key]
    if imgui.Checkbox(label, b) then
        cfg.main[key] = b[0]
        markDirty()
    end
end

local function sliderInt(label, key, mn, mx)
    local b = uiBuf['si_' .. key]
    if not b then
        b = imgui.new.int(math.floor(cfg.main[key]))
        uiBuf['si_' .. key] = b
    end
    b[0] = math.floor(cfg.main[key])
    imgui.Text(label .. ': ' .. tostring(b[0]))
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##' .. key, b, mn, mx, '%d') then
        cfg.main[key] = b[0]
        markDirty()
    end
    imgui.PopItemWidth()
end

local function sliderFloat(label, key, mn, mx)
    local b = uiBuf['sf_' .. key]
    if not b then
        b = imgui.new.float(cfg.main[key])
        uiBuf['sf_' .. key] = b
    end
    b[0] = cfg.main[key]
    imgui.Text(label .. ': ' .. string.format('%.1f', b[0]))
    imgui.PushItemWidth(-1)
    if imgui.SliderFloat('##' .. key, b, mn, mx, '%.1f') then
        cfg.main[key] = b[0]
        markDirty()
    end
    imgui.PopItemWidth()
end

local function colorRow(label, prefix)
    imgui.Text(label)
    local r = ref[prefix]
    if imgui.ColorEdit4('##' .. prefix, r, imgui.ColorEditFlags.NoInputs) then
        local m = cfg.main
        m[prefix .. 'R'], m[prefix .. 'G'], m[prefix .. 'B'], m[prefix .. 'A'] =
            r[0], r[1], r[2], r[3]
        markDirty()
    end
end

local function menuBody()
    local m = cfg.main
    if not imgui.BeginTabBar('##tabs') then return end

    if imgui.BeginTabItem(u8'Граффити') then
        checkBox(u8'Включить граффити', 'grafEnabled')
        checkBox(u8'Только доступные', 'grafOnlyAvailable')
        imgui.Separator()
        checkBox(u8'Авто-краска', 'autoPaint')
        sliderInt(u8'Скорость прохождения (1 медленно, 10 быстро)', 'paintSpeed', 1, 10)
        sliderFloat(u8'Радиус (м)', 'paintRadius', 1.5, 10.0)
        sliderInt(u8'Пауза ALT -> КЛИК (мс)', 'altToClickDelay', 200, 3000)
        sliderInt(u8'Задержка между покрасками (мс)', 'paintCooldown', 100, 5000)
        imgui.Separator()
        imgui.TextWrapped(u8'Скорость задает паузу между кликами по пятнам краски. Если покраска не стартует, увеличь паузу ALT -> КЛИК до 1000-1500 мс.')
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem(u8'Закладки') then
        checkBox(u8'Включить закладки', 'drwhEnabled')
        imgui.Separator()
        imgui.Text(u8'Искомое слово:')
        imgui.PushItemWidth(-1)
        if imgui.InputText('##kw', ref.keyword, 64) then
            m.keyword = u8:decode(ffi.string(ref.keyword))
            kwLower = lowerCp(m.keyword)
            markDirty()
        end
        imgui.PopItemWidth()
        imgui.TextDisabled(u8'Текущее: ' .. u8(m.keyword))
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem(u8'Капля') then
        dropTab = true
        checkBox(u8'Показывать каплю', 'dropEnabled')
        sliderInt(u8'Размер капли', 'dropSize', 20, 200)
        sliderFloat(u8'Скорость капли', 'dropSpeed', 0.3, 3.0)
        sliderInt(u8'Толщина капли', 'dropThick', 1, 10)
        imgui.Separator()
        imgui.TextWrapped(u8'Пока открыта эта вкладка, пример капли показывается справа на экране. Цвет капли меняется во вкладке Настройки.')
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem(u8'Притон') then
        checkBox(u8'Помощник притона', 'pritonEnabled')
        checkBox(u8'Авто-посадка и сбор', 'pritonAutoFarm')
        checkBox(u8'Трейсер на укроп', 'pritonTracer')
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem('ESP') then
        sliderInt(u8'Мин. дистанция (м)', 'minDist', 0, 50)
        sliderInt(u8'Макс. дистанция (м)', 'maxDist', 10, 500)
        checkBox(u8'Линия от низа экрана до цели', 'drawLines')
        checkBox(u8'Линия от игрока до цели', 'espLineToItem')
        checkBox(u8'Стрелки к целям за экраном', 'espArrows')
        if cfg.main.espArrows then
            sliderInt(u8'Размер стрелки', 'espArrowSize', 6, 40)
        end
        checkBox(u8'Инфо-бар (список целей)', 'showList')
        sliderInt(u8'Инфо-бар: позиция X', 'infoX', 0, math.floor(resX))
        sliderInt(u8'Инфо-бар: позиция Y', 'infoY', 0, math.floor(resY))
        imgui.Separator()
        imgui.TextWrapped(u8'Пока меню открыто, инфо-бар показывает пример, чтобы было видно, где он стоит. Цели одного типа рядом друг с другом объединяются в одну большую каплю.')
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem(u8'Настройки') then
        colorRow(u8'Цвет граффити (капля и текст)', 'colGraf')
        colorRow(u8'Цвет закладок (капля и текст)', 'colDrwh')
        colorRow(u8'Цвет укропа (капля и текст)', 'colPriton')
        colorRow(u8'Цвет линии', 'colLine')
        imgui.Separator()
        if imgui.Button(u8'Сброс настроек', imgui.ImVec2(-1, 36)) then resetCfg() end
        if imgui.Button(u8'Выгрузить скрипт', imgui.ImVec2(-1, 36)) then
            flush()
            thisScript():unload()
        end
        imgui.EndTabItem()
    end

    imgui.EndTabBar()
end

local function drawMenu()
    local m = cfg.main
    dropTab = false

    local w, h = m.winW, m.winH
    imgui.SetNextWindowSize(imgui.ImVec2(w, h), imgui.Cond.Always)

    if firstCenter then
        firstCenter = false
        m.winX = math.max(0, math.floor(resX / 2 - w / 2))
        m.winY = math.max(0, math.floor(resY / 2 - h / 2))
        markDirty()
        imgui.SetNextWindowPos(imgui.ImVec2(m.winX, m.winY), imgui.Cond.Always)
    elseif forceWin then
        forceWin = false
        imgui.SetNextWindowPos(
            imgui.ImVec2(math.max(0, resX / 2 - w / 2), math.max(0, resY / 2 - h / 2)),
            imgui.Cond.Always)
    elseif m.winX >= 0 and m.winY >= 0 then
        imgui.SetNextWindowPos(imgui.ImVec2(m.winX, m.winY), imgui.Cond.FirstUseEver)
    end

    if imgui.Begin('Ghetto Mini Helper##menu', winOpen, imgui.WindowFlags.NoCollapse) then
        local p  = imgui.GetWindowPos()
        local sz = imgui.GetWindowSize()
        local changed = false
        if math.abs(p.x - m.winX) > 1 or math.abs(p.y - m.winY) > 1 then
            m.winX, m.winY = math.floor(p.x), math.floor(p.y)
            changed = true
        end
        if math.abs(sz.x - m.winW) > 1 or math.abs(sz.y - m.winH) > 1 then
            m.winW, m.winH = math.floor(sz.x), math.floor(sz.y)
            changed = true
        end
        if changed then markDirty() end
        pcall(menuBody)
    end
    imgui.End()
end

imgui.OnFrame(function()
    local m = cfg.main
    return winOpen[0] or m.grafEnabled or m.drwhEnabled
        or (m.pritonEnabled and m.pritonTracer) or m.autoPaint
end, function()
    if not isSampAvailable() then return end
    pcall(drawEsp)
    if winOpen[0] then drawMenu() end
end)

function main()
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand('gmh', function()
        winOpen[0] = not winOpen[0]
    end)

    sampRegisterChatCommand('darkword', function(arg)
        arg = (arg or ''):gsub('^%s+', ''):gsub('%s+$', '')
        if arg == '' then
            sampAddChatMessage('[Ghetto Mini Helper] /darkword <слово>. Сейчас: '
                .. cfg.main.keyword, 0xFFAA00)
            return
        end
        setKeyword(arg)
        markDirty()
        sampAddChatMessage('[Ghetto Mini Helper] Искомое слово: '
            .. cfg.main.keyword, 0x29D87E)
    end)

    sampAddChatMessage('[Ghetto Mini Helper] Загружен. Меню: /gmh', 0x29D87E)

    lua_thread.create(function()
        while true do
            wait(30)
            if cfg.main.autoPaint then
                local now = os.clock()
                local pick
                for id, sp in pairs(spot) do
                    if now - sp.born > 40 then
                        spot[id] = nil
                    elseif sp.progress < 100 and (sp.sent < 5 or now - sp.last > 0.6) then
                        if not pick or sp.last < spot[pick].last then pick = id end
                    end
                end
                if pick then
                    local lo = 520 - (math.floor(cfg.main.paintSpeed) - 1) * 50
                    wait(math.random(lo, math.floor(lo * 1.4)))
                    local sp = spot[pick]
                    if sp and cfg.main.autoPaint then
                        clickTd(pick)
                        sp.sent = sp.sent + 1
                        sp.last = os.clock()
                    end
                end
            end
        end
    end)

    lua_thread.create(function()
        local lastObjScan, seedNear = -10, false
        while true do
            wait(60)
            if dirty and os.clock() - dirtyT > 0.5 then flush() end

            local m = cfg.main
            if m.pritonEnabled and m.pritonAutoFarm
                and not try(sampIsDialogActive)
                and not try(sampIsChatInputActive)
                and not try(isPauseMenuActive) then

                local myX, myY, myZ = playerPos()
                if myX then
                    local interact = false
                    for _, t in ipairs(scanTexts()) do
                        local text = textInfo(t.raw).text
                        if isPriton(text) or text:find('Грядка', 1, true) then
                            if dist3(myX, myY, myZ, t.x, t.y, t.z) <= 2.0 then
                                interact = true
                                break
                            end
                        end
                    end
                    if not interact then
                        local now = os.clock()
                        if now - lastObjScan >= 0.3 then
                            lastObjScan = now
                            seedNear = false
                            local ok, objs = pcall(getAllObjects)
                            if ok and type(objs) == 'table' then
                                for _, obj in ipairs(objs) do
                                    local okm, model = pcall(getObjectModel, obj)
                                    if okm and model == 859 then
                                        local ox, oy, oz = coordsOf(getObjectCoordinates, obj)
                                        if ox and dist3(myX, myY, myZ, ox, oy, oz) <= 2.0 then
                                            seedNear = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        interact = seedNear
                    end
                    if interact then sendInteract(false, false) end
                end
            end

            pcall(autoPaintTick)
        end
    end)

    wait(-1)
end