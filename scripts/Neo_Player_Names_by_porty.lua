script_name('Neo Player Names')
script_author('porty')
script_version('1.4')

local imgui   = require 'mimgui'
local encoding = require 'encoding'
local inicfg  = require 'inicfg'
local ffi     = require 'ffi'

encoding.default = 'CP1251'
-- Исходник сохранён в UTF-8. encoding.UTF8 используется только для строк из SA-MP (CP1251).
local function u8(text)
    if text == nil then return '' end
    return encoding.UTF8(text)
end
local function ui8(text)
    return text
end

local resX, resY = getScreenResolution()
local cfgFile = 'neo_player_names.ini'

local default = {
    enabled = true,
    maxDist = 100,
    showId = true,
    showDistance = true,
    winW = 520,
    winH = 300
}

local range = {
    maxDist = {10, 250},
    winW = {300, resX},
    winH = {200, resY}
}

local function makeDefault()
    local main = {}
    for k, v in pairs(default) do main[k] = v end
    return {main = main}
end

local function normalize(main)
    for k, dv in pairs(default) do
        local v = main[k]
        if type(dv) == 'boolean' then
            main[k] = (v == true or v == 'true' or v == 1 or v == '1')
        elseif type(dv) == 'number' then
            v = tonumber(v) or dv
            local r = range[k]
            if r then v = math.max(r[1], math.min(r[2], v)) end
            main[k] = v
        end
    end
end

local cfg = inicfg.load(makeDefault(), cfgFile)
if type(cfg) ~= 'table' or type(cfg.main) ~= 'table' then
    cfg = makeDefault()
end
normalize(cfg.main)

local dirty, dirtyT = false, 0
local winOpen = imgui.new.bool(false)
local uiBuf = {}

local function markDirty()
    dirty = true
    dirtyT = os.clock()
end

local function flush()
    if not dirty then return end
    dirty = false
    local dir = getWorkingDirectory() .. '/config'
    if not doesDirectoryExist(dir) then createDirectory(dir) end
    pcall(inicfg.save, cfg, cfgFile)
end

imgui.OnInitialize(function()
    local io = imgui.GetIO()
    pcall(function() io.IniFilename = nil end)

    local font = '/system/fonts/Roboto-Regular.ttf'
    if doesFileExist(font) then
        pcall(function()
            io.Fonts:AddFontFromFileTTF(
                font,
                16,
                nil,
                io.Fonts:GetGlyphRangesCyrillic()
            )
        end)
    end

    local s = imgui.GetStyle()
    s.WindowPadding = imgui.ImVec2(12, 12)
    s.FramePadding = imgui.ImVec2(10, 8)
    s.ItemSpacing = imgui.ImVec2(8, 9)
    s.WindowRounding = 8
    s.ChildRounding = 8
    s.FrameRounding = 7
    s.PopupRounding = 7
    s.ScrollbarSize = 20
    s.GrabMinSize = 16
    s.TouchExtraPadding = imgui.ImVec2(5, 5)
end)

local function getPlayerPos(ped)
    if not ped or not doesCharExist(ped) then return nil end
    local ok, x, y, z = pcall(getCharCoordinates, ped)
    if not ok then return nil end
    return x, y, z
end

local function distance3d(x1, y1, z1, x2, y2, z2)
    local dx = x1 - x2
    local dy = y1 - y2
    local dz = z1 - z2
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function drawTextShadow(dl, x, y, text, color)
    dl:AddText(imgui.ImVec2(x + 1, y + 1), 0xDD000000, text)
    dl:AddText(imgui.ImVec2(x, y), color, text)
end

local function getTabPlayerColor(id)
    local ok, c = pcall(sampGetPlayerColor, id)
    if not ok or c == nil then return 0xFFFFFFFF end
    c = tonumber(c) or 0xFFFFFFFF

    -- SA-MP: 0xRRGGBBAA -> ImGui: 0xAABBGGRR
    local r = bit.band(bit.rshift(c, 24), 0xFF)
    local g = bit.band(bit.rshift(c, 16), 0xFF)
    local b = bit.band(bit.rshift(c, 8), 0xFF)
    local a = bit.band(c, 0xFF)
    if a == 0 then a = 255 end

    return bit.bor(
        bit.lshift(a, 24),
        bit.lshift(b, 16),
        bit.lshift(g, 8),
        r
    )
end

local function drawPlayerNames()
    if not isSampAvailable() then return end
    if not cfg.main.enabled then return end
    if not pcall(sampIsLocalPlayerSpawned) or not sampIsLocalPlayerSpawned() then return end
    if pcall(sampIsScoreboardOpen) and sampIsScoreboardOpen() then return end

    local mx, my, mz = getPlayerPos(PLAYER_PED)
    if not mx then return end

    local dl = imgui.GetBackgroundDrawList()
    local maxId = sampGetMaxPlayerId(false)

    -- Получаем именно свой SA-MP ID. Это защищает от бага NeoMLoader,
    -- когда чужой ID получает координаты нашего PLAYER_PED.
    local myId = -1
    pcall(function()
        local a, b = sampGetPlayerIdByCharHandle(PLAYER_PED)
        if type(b) == 'number' then
            myId = b
        elseif type(a) == 'number' then
            myId = a
        end
    end)

    for id = 0, maxId do
        if sampIsPlayerConnected(id) and id ~= myId then
            local ok, ped = sampGetCharHandleBySampPlayerId(id)
            if ok and ped and ped ~= PLAYER_PED and doesCharExist(ped) and not isCharDead(ped) then
                local px, py, pz = getPlayerPos(ped)
                if px then
                    local dist = distance3d(mx, my, mz, px, py, pz)
                    if dist > 0.35 and dist <= cfg.main.maxDist and isCharOnScreen(ped) then
                        local sx, sy = convert3DCoordsToScreen(px, py, pz + 1.0)
                        if sx and sy then
                            local nickname = sampGetPlayerNickname(id) or ('Player_' .. id)
                            local nickText = nickname
                            local suffix = ''

                            if cfg.main.showId then
                                suffix = suffix .. ' [' .. id .. ']'
                            end
                            if cfg.main.showDistance then
                                suffix = suffix .. string.format('  %.0fм', dist)
                            end

                            local nickUtf8 = u8(nickText)
                            local suffixUtf8 = suffix
                            local nickColor = getTabPlayerColor(id)
                            local white = 0xFFFFFFFF

                            local nickW = imgui.CalcTextSize(nickUtf8).x
                            local suffixW = imgui.CalcTextSize(suffixUtf8).x
                            local x = sx - (nickW + suffixW) / 2

                            drawTextShadow(dl, x, sy, nickUtf8, nickColor)
                            drawTextShadow(dl, x + nickW, sy, suffixUtf8, white)
                        end
                    end
                end
            end
        end
    end
end

local function checkBox(label, key)
    local name = 'cb_' .. key
    if not uiBuf[name] then
        uiBuf[name] = imgui.new.bool(cfg.main[key])
    end

    local b = uiBuf[name]
    b[0] = cfg.main[key]

    if imgui.Checkbox(label, b) then
        cfg.main[key] = b[0]
        markDirty()
    end
end

local function sliderInt(label, key, mn, mx)
    local name = 'sl_' .. key
    if not uiBuf[name] then
        uiBuf[name] = imgui.new.int(math.floor(cfg.main[key]))
    end

    local b = uiBuf[name]
    b[0] = math.floor(cfg.main[key])

    imgui.Text(label .. ': ' .. tostring(b[0]) .. ' м')
    imgui.PushItemWidth(-1)

    if imgui.SliderInt('##' .. key, b, mn, mx, '%d м') then
        cfg.main[key] = b[0]
        markDirty()
    end

    imgui.PopItemWidth()
end

local function resetConfig()
    cfg = makeDefault()
    uiBuf = {}
    markDirty()
    flush()
end

local function drawMenu()
    imgui.SetNextWindowSize(
        imgui.ImVec2(cfg.main.winW, cfg.main.winH),
        imgui.Cond.FirstUseEver
    )

    if imgui.Begin(
        ui8'Neo Player Names',
        winOpen,
        imgui.WindowFlags.NoCollapse
    ) then

        imgui.Text(ui8'PLAYER NAMES')
        imgui.SameLine()
        imgui.TextDisabled(ui8'Автор: porty')
        imgui.SameLine()
        imgui.TextDisabled(ui8'• NeoMLoader')

        imgui.Separator()
        imgui.Spacing()

        checkBox(ui8'Включить отображение ников', 'enabled')

        imgui.Spacing()
        imgui.Text(ui8'Дальность отображения')
        imgui.TextColored(
            imgui.ImVec4(0.3, 0.8, 1.0, 1.0),
            string.format('%d метров', cfg.main.maxDist)
        )

        imgui.PushItemWidth(-1)
        local b = uiBuf.distance
        if not b then
            b = imgui.new.int(cfg.main.maxDist)
            uiBuf.distance = b
        end

        b[0] = cfg.main.maxDist

        if imgui.SliderInt(
            '##distance',
            b,
            10,
            250,
            '%d м'
        ) then
            cfg.main.maxDist = b[0]
            markDirty()
        end
        imgui.PopItemWidth()

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        checkBox(ui8'Показывать ID игрока', 'showId')
        checkBox(ui8'Показывать расстояние', 'showDistance')

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        imgui.TextWrapped(
            ui8'Ники игроков отображаются над персонажами только в выбранном радиусе от 10 до 250 метров.'
        )

        imgui.Spacing()

        if imgui.Button(
            ui8'Сбросить настройки',
            imgui.ImVec2(-1, 38)
        ) then
            resetConfig()
        end

        imgui.End()
    end
end

imgui.OnFrame(
    function()
        return winOpen[0] or cfg.main.enabled
    end,
    function()
        if not isSampAvailable() then return end

        drawPlayerNames()

        if winOpen[0] then
            drawMenu()
        end
    end
)

function main()
    while not isSampAvailable() do
        wait(100)
    end

    sampRegisterChatCommand('names', function()
        winOpen[0] = not winOpen[0]
    end)

    sampAddChatMessage(
        '[Neo Player Names] Loaded. Menu: /names',
        0x55DD88
    )

    while true do
        wait(100)

        if dirty and os.clock() - dirtyT > 0.5 then
            flush()
        end
    end
end

function onScriptTerminate(scr)
    if scr == thisScript() then
        flush()
    end
end
