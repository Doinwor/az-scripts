script_author('pinokio')

local imgui     = require("mimgui")
local ffi       = require("ffi")
local encoding  = require("encoding")
local inicfg    = require("inicfg")
local sampev    = require("lib.samp.events")

local okFa, fa = pcall(require, "fAwesome6_solid")
if not okFa then fa = setmetatable({}, { __index = function() return "" end }) end
local function ico(name)
    if not okFa then return "" end
    local ok, v = pcall(function() return fa[name] end)
    if ok and type(v) == "string" and v ~= "" then return v end
    return ""
end

encoding.default = "CP1251"
local u8 = encoding.UTF8

local new    = imgui.new
local ImVec2 = imgui.ImVec2
local ImVec4 = imgui.ImVec4
local scale  = MONET_DPI_SCALE or 1.0
local function S(v) return v * scale end

local sep = (MONET_VERSION == nil) and "\\" or "/"
local configDir = getWorkingDirectory() .. sep .. "config"
if not doesDirectoryExist(configDir) then createDirectory(configDir) end
local cfgPath = configDir .. sep .. "probeg_mobile.ini"

local defaultCfg = {
    design = {
        dimming  = 60, bgAlpha = 95,
        farmBtnX = -1, farmBtnY = -1,
        syncInterval = 250,
        circleRadius = 6.0,
        circleSpeed  = 4.0
    },
    settings = {
        showFarmBtn = true
    }
}

local cfg = inicfg.load(defaultCfg, cfgPath)
if type(cfg) ~= "table" then cfg = defaultCfg end
if type(cfg.design)   ~= "table" then cfg.design   = defaultCfg.design end
if type(cfg.settings) ~= "table" then cfg.settings = defaultCfg.settings end
for k, v in pairs(defaultCfg.design)   do if cfg.design[k]   == nil then cfg.design[k]   = v end end
for k, v in pairs(defaultCfg.settings) do if cfg.settings[k] == nil then cfg.settings[k] = v end end

local function saveCfg() pcall(inicfg.save, cfg, cfgPath) end

local isFarming       = false
local lastFarmToggle  = 0
local farmCooldown    = 2.0

local progressKm      = 0
local progressStart   = 0
local lastMileage     = 0
local etaUnix         = 0
local pausedEtaLeft   = nil

local isCefActive     = false
local cefStartTime    = 0
local lastCefState    = false

local screenW, screenH = getScreenResolution()

local toasts          = {}
local toastId         = 0

local isParsingRewards  = false
local parseState        = "idle"
local parseStartTime    = 0
local parseTimeoutSec   = 25
local parseSilent       = false
local parseFoundGlobal  = false
local parseFoundDaily   = false
local currentCarModel   = -1
local lastProgressPoll  = 0
local progressPollEvery = 10

local menuOpen   = false
local menuAlpha  = 0
local currentTab = 1

local colAccent = ImVec4(0.24, 0.42, 0.85, 1)
local colHover  = ImVec4(0.32, 0.52, 0.95, 1)
local colActive = ImVec4(0.18, 0.32, 0.7,  1)

local function applyTheme()
    local c = imgui.GetStyle().Colors
    c[imgui.Col.ButtonHovered] = colHover
    c[imgui.Col.ButtonActive]  = colActive
    c[imgui.Col.SliderGrab]        = colAccent
    c[imgui.Col.SliderGrabActive]  = colHover
    c[imgui.Col.CheckMark]         = colAccent
end

local function showToast(text)
    toastId = toastId + 1
    toasts[#toasts + 1] = {
        id = "Toast_" .. toastId,
        text = tostring(text),
        life = 8, maxLife = 8,
        height = 60, targetY = 0, currY = 0, slideX = 450
    }
end

local function sumFormat(n)
    local ok, res = pcall(function()
        if not n then return "0" end
        local v = math.floor(tonumber(n) or 0)
        local s = tostring(v)
        local changed
        repeat s, changed = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2") until changed == 0
        return s
    end)
    return ok and res or "0"
end

local lastRpcAt = 0
local RPC_THROTTLE = 0.4

local function rpcDialogRaw(id, response, listitem, text)
    if type(sampSendDialogResponse) == "function" then
        local ok = pcall(sampSendDialogResponse, id, response, listitem, text or "")
        if ok then return end
    end
    pcall(function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt16(bs, tonumber(id) or 0)
        raknetBitStreamWriteInt8(bs, tonumber(response) or 0)
        raknetBitStreamWriteInt16(bs, tonumber(listitem) or 0)
        local t = text or ""
        local len = #t
        raknetBitStreamWriteInt16(bs, len)
        if len > 0 then raknetBitStreamWriteString(bs, t) end
        raknetSendRpc(62, bs)
        raknetDeleteBitStream(bs)
    end)
end

local function rpcDialog(id, response, listitem, text)
    local now = os.clock()
    local waitFor = RPC_THROTTLE - (now - lastRpcAt)
    if waitFor > 0 then
        lua_thread.create(function()
            wait(math.floor(waitFor * 1000))
            lastRpcAt = os.clock()
            rpcDialogRaw(id, response, listitem, text)
        end)
        return
    end
    lastRpcAt = now
    rpcDialogRaw(id, response, listitem, text)
end

local createSyncFn = nil

local function initSync()
    local ok = pcall(function()
        if type(samp_create_sync_data) == "function" then
            createSyncFn = samp_create_sync_data
            return
        end
        local sampfuncs = require("sampfuncs")
        local raknet    = require("samp.raknet")
        require("samp.synchronization")

        createSyncFn = function(sync_type, copy_from_player)
            copy_from_player = copy_from_player or true
            local traits = {
                player    = {"PlayerSyncData",    raknet.PACKET.PLAYER_SYNC,    sampStorePlayerOnfootData},
                vehicle   = {"VehicleSyncData",   raknet.PACKET.VEHICLE_SYNC,   sampStorePlayerIncarData},
                passenger = {"PassengerSyncData", raknet.PACKET.PASSENGER_SYNC, sampStorePlayerPassengerData},
                aim       = {"AimSyncData",       raknet.PACKET.AIM_SYNC,       sampStorePlayerAimData},
                trailer   = {"TrailerSyncData",   raknet.PACKET.TRAILER_SYNC,   sampStorePlayerTrailerData},
                unoccupied= {"UnoccupiedSyncData",raknet.PACKET.UNOCCUPIED_SYNC,nil},
                bullet    = {"BulletSyncData",    raknet.PACKET.BULLET_SYNC,    nil},
                spectator = {"SpectatorSyncData", raknet.PACKET.SPECTATOR_SYNC, nil}
            }
            local info = traits[sync_type]
            if not info then return nil end
            local dataType = "struct " .. info[1]
            local data = ffi.new(dataType, {})
            local rawPtr = tonumber(ffi.cast("uintptr_t", ffi.new(dataType .. "*", data)))
            if copy_from_player then
                local copyFn = info[3]
                if copyFn then
                    local _, pid
                    if copy_from_player == true then
                        _, pid = sampGetPlayerIdByCharHandle(PLAYER_PED)
                    else
                        pid = tonumber(copy_from_player)
                    end
                    if pid and pid >= 0 then pcall(copyFn, pid, rawPtr) end
                end
            end
            local mt = {
                __index    = function(_, i) return data[i] end,
                __newindex = function(_, i, v) data[i] = v end
            }
            return setmetatable({
                send = function()
                    local bs = raknetNewBitStream()
                    raknetBitStreamWriteInt8(bs, info[2])
                    raknetBitStreamWriteBuffer(bs, rawPtr, ffi.sizeof(data))
                    raknetSendBitStreamEx(bs, 1, 7, 1)
                    raknetDeleteBitStream(bs)
                end,
                _data = data
            }, mt)
        end
    end)
    return ok and createSyncFn ~= nil
end

local syncOk = false
syncOk = initSync()

local farmAngle    = 0
local farmCenter   = { x = 0, y = 0, z = 0 }
local farmLastTick = 0

local function startFarmMotion()
    local x, y, z = getCharCoordinates(PLAYER_PED)
    farmCenter.x, farmCenter.y, farmCenter.z = x, y, z
    farmAngle = 0
    farmLastTick = os.clock()
end

local function stopFarmMotion()
    pcall(function()
        if doesCharExist(PLAYER_PED) and isCharInAnyCar(PLAYER_PED) then
            local veh = storeCarCharIsInNoSave(PLAYER_PED)
            if veh and veh ~= 0 then setCarCollision(veh, true) end
        end
    end)
end

local function stepFarmMotion()
    if not isFarming or not syncOk then return end
    if not doesCharExist(PLAYER_PED) then return end
    if not isCharInAnyCar(PLAYER_PED) then return end

    local now = os.clock()
    local dt = now - farmLastTick
    local interval = (cfg.design.syncInterval or 250) / 1000
    if dt < interval then return end
    farmLastTick = now

    local radius = cfg.design.circleRadius or 6.0
    local speed  = cfg.design.circleSpeed  or 4.0
    local angSpeed = speed / radius

    farmAngle = farmAngle + angSpeed * dt
    if farmAngle > math.pi * 2 then farmAngle = farmAngle - math.pi * 2 end

    local nx = farmCenter.x + math.cos(farmAngle) * radius
    local ny = farmCenter.y + math.sin(farmAngle) * radius
    local nz = farmCenter.z

    local veh = storeCarCharIsInNoSave(PLAYER_PED)
    if not veh or veh == 0 or not doesVehicleExist(veh) then return end

    local heading = math.deg(-(farmAngle + math.pi / 2)) + 90
    while heading < 0 do heading = heading + 360 end
    while heading >= 360 do heading = heading - 360 end

    pcall(setCarCoordinates, veh, nx, ny, nz)
    pcall(setCarHeading, veh, heading)

    pcall(function()
        local sync = createSyncFn("vehicle", true)
        if not sync then return end
        local _, sampId = sampGetVehicleIdByCarHandle(veh)
        if not sampId or sampId == 0 then return end
        sync.vehicleId     = sampId
        sync.position      = { x = nx, y = ny, z = nz }
        sync.moveSpeed     = {
            x = math.sin(-math.rad(heading)) * speed,
            y = math.cos(-math.rad(heading)) * speed,
            z = 0
        }
        sync.quaternion    = { 0, 0, 0, 1 }
        sync.playerHealth  = 100
        sync.vehicleHealth = 1000
        sync.send()
    end)
end

local function stopFarm(reason)
    if not isFarming then return end
    isFarming = false
    stopFarmMotion()
    lastMileage, pausedEtaLeft = 0, nil
    isCefActive = false
    isParsingRewards = false
    parseState = "idle"
    printStringNow("~w~De-Activated", 2000)
    if reason then showToast(u8"Фарм остановлен: " .. reason) end
end

local function startParsing()
    currentCarModel = -1
    if doesCharExist(PLAYER_PED) and isCharInAnyCar(PLAYER_PED) then
        currentCarModel = getCarModel(storeCarCharIsInNoSave(PLAYER_PED))
    end
    parseFoundGlobal = false
    parseFoundDaily  = false
    parseStartTime   = os.clock()
    isParsingRewards = true
    parseState       = "waiting_menu_global"
    if sampIsDialogActive() then pcall(sampCloseCurrentDialogWithButton, 0) end
    pcall(sampSendChat, "/rewards")
end

local function goFarm()
    if os.clock() - lastFarmToggle < farmCooldown then
        local left = farmCooldown - (os.clock() - lastFarmToggle)
        showToast(string.format(u8"Подождите %.1f сек.", left))
        return
    end

    if not syncOk then
        showToast(u8"Фарм недоступен: ошибка синхронизации")
        return
    end

    local min = tonumber(os.date("%M"))
    local sec = tonumber(os.date("%S"))
    if (min == 59 or min == 29) and sec >= 40 then
        showToast(u8"Запуск запрещён: скоро PayDay.")
        return
    end

    if progressKm >= 2000 and not isFarming then
        showToast(u8"Достижение выполнено (2000/2000). Сбрось талоном.")
        return
    end

    if not isFarming then
        if not doesCharExist(PLAYER_PED) or not isCharInAnyCar(PLAYER_PED) then
            showToast(u8"Ошибка: вы не в транспорте!")
            return
        end
        local model = getCarModel(storeCarCharIsInNoSave(PLAYER_PED))
        if model ~= 12687 and model ~= 14954 then
            showToast(u8"Ошибка: неподходящий транспорт!")
            return
        end
    end

    lastFarmToggle = os.clock()

    if isFarming then
        stopFarm(nil)
    else
        isFarming = true
        startFarmMotion()
        lastProgressPoll = os.clock()

        parseSilent = false
        startParsing()
        showToast(u8"Читаю /rewards...")

        pcall(function()
            local veh = storeCarCharIsInNoSave(PLAYER_PED)
            if veh and veh ~= 0 then setCarCollision(veh, false) end
        end)

        printStringNow("~g~Activated", 2000)
        showToast(u8"Фарм запущен.")
    end
end

local function handleRewardsPage(id, text, state)
    local isGlobal = (state == "reading_global")
    local pattern = isGlobal and "из 2000" or "из 100"

    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        lines[#lines + 1] = line:gsub("{.-}", "")
    end

    local nextPageIdx = -1
    local foundLine   = nil

    for lineIdx, clean in ipairs(lines) do
        local isGiga = clean:find("Gigahorse", 1, true) ~= nil
        local isMac  = clean:find("Mclaren", 1, true) ~= nil
                       or clean:find("McLaren", 1, true) ~= nil
        local hasPattern = clean:find(pattern, 1, true) ~= nil

        if isGiga and hasPattern then
            if currentCarModel == 12687 then foundLine = clean end
        elseif isMac and hasPattern then
            if currentCarModel == 14954 then foundLine = clean end
        end

        if clean:find("Следующая страница", 1, true) then
            nextPageIdx = lineIdx - 2
        end
    end

    if foundLine then
        local val = tonumber(foundLine:match("(%d+)%s+из"))
        if val then
            progressKm    = val
            progressStart = val
            if val < 2000 then
                etaUnix = os.time() + (2000 - val)
            else
                etaUnix = os.time()
            end
            if isGlobal then parseFoundGlobal = true else parseFoundDaily = true end
        end
    end

    local foundMine = foundLine ~= nil

    if nextPageIdx >= 0 and not foundMine then
        rpcDialog(id, 1, nextPageIdx, "")
        return false
    end

    if isGlobal then
        lua_thread.create(function()
            rpcDialog(id, 0, 0, "")
            wait(1200)
            parseState = "waiting_menu_daily"
            sampSendChat("/rewards")
        end)
        return false
    else
        lua_thread.create(function()
            rpcDialog(id, 0, 0, "")
            wait(600)
            isParsingRewards = false
            parseState = "idle"
            if not parseSilent then
                showToast(u8"Прогресс: " .. sumFormat(progressKm) .. u8" / 2000")
            end
        end)
        return false
    end
end

function sampev.onConnectionClosed()   stopFarm(u8"Сервер закрыл соединение") end
function sampev.onConnectionLost()     stopFarm(u8"Соединение потеряно") end
function sampev.onConnectionRejected() stopFarm(u8"Отклонено сервером") end

function sampev.onServerMessage(color, text)
    local clean = tostring(text):gsub("{.-}", "")
    if clean:find("Сервер закрыл соединение", 1, true) or clean:find("Disconnect:", 1, true) then
        stopFarm(u8"Отключение")
    end
end

function sampev.onShowDialog(id, style, title, b1, b2, text)
    local cleanTitle = tostring(title):gsub("{.-}", "")

    if isParsingRewards then
        if cleanTitle == "Все достижения" then
            if parseState == "waiting_menu_global" then
                rpcDialog(id, 1, 1, "")
                parseState = "reading_global"
                return false
            elseif parseState == "waiting_menu_daily" then
                rpcDialog(id, 1, 0, "")
                parseState = "reading_daily"
                return false
            end
        elseif cleanTitle == "Достижения" then
            if parseState == "reading_global" or parseState == "reading_daily" then
                return handleRewardsPage(id, text, parseState)
            end
        end
    end
end

local farmBtn       = new.bool(true)
local farmDragStart = 0
local farmHolding   = false
local farmDragOn    = false
local farmDragMoved = false
local farmOffX      = 0
local farmOffY      = 0
local lastBtnSave   = 0

local function getBtnPos()
    if cfg.design.farmBtnX < 0 or cfg.design.farmBtnY < 0 then
        return screenW - S(90), screenH - S(160)
    end
    return cfg.design.farmBtnX, cfg.design.farmBtnY
end

local HOLD_TIME = 1.5

local function processFarmButton()
    if not cfg.settings.showFarmBtn then
        farmHolding = false
        farmDragOn = false
        return
    end

    local io = imgui.GetIO()
    local mp = io.MousePos
    if not mp then return end

    local mdown = io.MouseDown and io.MouseDown[0] or false
    local bx, by = getBtnPos()
    local bsize  = S(64)
    local pad    = S(10)

    if menuOpen then
        farmHolding = false
        farmDragOn = false
        return
    end

    local overBtn = mp.x >= bx - pad and mp.x <= bx + bsize + pad
                 and mp.y >= by - pad and mp.y <= by + bsize + pad

    local cx = bx + bsize / 2
    local cy = by + bsize / 2

    if mdown and not farmHolding then
        if overBtn then
            farmHolding   = true
            farmDragStart = os.clock()
            farmOffX = mp.x - cx
            farmOffY = mp.y - cy
            farmDragMoved = false
            farmDragOn = false
        end
    elseif mdown and farmHolding then
        if not farmDragOn and (os.clock() - farmDragStart) >= HOLD_TIME then
            farmDragOn = true
        end
        if farmDragOn then
            local newCx = mp.x - farmOffX
            local newCy = mp.y - farmOffY
            local nx = newCx - bsize / 2
            local ny = newCy - bsize / 2
            nx = math.max(S(2), math.min(screenW - bsize - S(2), nx))
            ny = math.max(S(2), math.min(screenH - bsize - S(2), ny))
            cfg.design.farmBtnX = nx
            cfg.design.farmBtnY = ny
            farmDragMoved = true
            if os.clock() - lastBtnSave > 0.4 then
                saveCfg()
                lastBtnSave = os.clock()
            end
        end
    elseif not mdown and farmHolding then
        farmHolding = false
        if farmDragMoved then
            saveCfg()
        elseif not farmDragOn then
            goFarm()
        end
        farmDragOn = false
        farmDragMoved = false
    end
end

local function drawFarmButton()
    if not cfg.settings.showFarmBtn then return end

    local bx, by = getBtnPos()
    local bsize  = S(64)
    local dl = imgui.GetBackgroundDrawList()

    local center = ImVec2(bx + bsize / 2, by + bsize / 2)
    local r = bsize / 2

    local io = imgui.GetIO()
    local overBtn = false
    if io.MousePos then
        local mx, my = io.MousePos.x, io.MousePos.y
        overBtn = mx >= bx - S(10) and mx <= bx + bsize + S(10)
              and my >= by - S(10) and my <= by + bsize + S(10)
    end

    local bg
    if farmDragOn then
        bg = ImVec4(0.85, 0.65, 0.2, 0.9)
    elseif isFarming then
        bg = ImVec4(0.2, 0.75, 0.3, 0.85)
    elseif farmHolding then
        bg = ImVec4(0.3, 0.45, 0.7, 0.9)
    elseif overBtn then
        bg = ImVec4(0.28, 0.4, 0.6, 0.9)
    else
        bg = ImVec4(0.15, 0.15, 0.18, 0.85)
    end

    local borderCol
    if farmDragOn then
        borderCol = ImVec4(1, 0.85, 0.4, 1)
    elseif isFarming then
        borderCol = ImVec4(0.4, 1, 0.5, 1)
    else
        borderCol = ImVec4(0.35, 0.55, 0.9, 0.9)
    end

    dl:AddCircleFilled(center, r + S(2), imgui.ColorConvertFloat4ToU32(ImVec4(0, 0, 0, 0.35)), 48)
    dl:AddCircleFilled(center, r, imgui.ColorConvertFloat4ToU32(bg), 48)
    dl:AddCircle(center, r, imgui.ColorConvertFloat4ToU32(borderCol), 48, S(2))

    if farmDragOn then
        local holdProgress = 1.0
        local elapsed = os.clock() - farmDragStart
        if elapsed < HOLD_TIME then
            holdProgress = elapsed / HOLD_TIME
        end
        local arcEnd = holdProgress * math.pi * 2
        dl:PathClear()
        for i = 0, 32 do
            local a = (i / 32) * arcEnd - math.pi / 2
            dl:PathLineTo(ImVec2(center.x + math.cos(a) * (r + S(4)),
                                  center.y + math.sin(a) * (r + S(4))))
        end
        dl:PathStroke(imgui.ColorConvertFloat4ToU32(ImVec4(1, 0.85, 0.4, 1)), false, S(3))
    elseif farmHolding then
        local holdProgress = (os.clock() - farmDragStart) / HOLD_TIME
        if holdProgress > 1 then holdProgress = 1 end
        local arcEnd = holdProgress * math.pi * 2
        dl:PathClear()
        for i = 0, 32 do
            local a = (i / 32) * arcEnd - math.pi / 2
            dl:PathLineTo(ImVec2(center.x + math.cos(a) * (r + S(4)),
                                  center.y + math.sin(a) * (r + S(4))))
        end
        dl:PathStroke(imgui.ColorConvertFloat4ToU32(ImVec4(0.6, 0.85, 1, 0.9)), false, S(3))
    end

    local iconTxt = isFarming and ico("STOP") or ico("PLAY")
    if iconTxt ~= "" then
        local ts = imgui.CalcTextSize(iconTxt)
        dl:AddText(ImVec2(center.x - ts.x / 2, center.y - ts.y / 2 - S(6)),
            imgui.ColorConvertFloat4ToU32(ImVec4(1, 1, 1, 1)), iconTxt)
    end
    local label = isFarming and u8"STOP" or u8"FARM"
    local ls = imgui.CalcTextSize(label)
    dl:AddText(ImVec2(center.x - ls.x / 2, center.y + S(10)),
        imgui.ColorConvertFloat4ToU32(ImVec4(1, 1, 1, 0.9)), label)
end

local sliderBgAlpha = new.int(cfg.design.bgAlpha)
local sliderDimming = new.int(cfg.design.dimming)
local sliderSyncInt = new.int(cfg.design.syncInterval)
local sliderRadius  = new.float(cfg.design.circleRadius)
local sliderSpeed   = new.float(cfg.design.circleSpeed)

local function tabButton(label, icon, id)
    local active = (currentTab == id)
    local w = imgui.GetContentRegionAvail().x
    local h = S(36)
    local pos = imgui.GetCursorScreenPos()

    if imgui.InvisibleButton("##tab" .. id, ImVec2(w, h)) then
        if not active then currentTab = id end
    end
    local hovered = imgui.IsItemHovered()
    local pressed = imgui.IsItemActive()
    local dl = imgui.GetWindowDrawList()

    if active then
        dl:AddRectFilled(pos, ImVec2(pos.x + w, pos.y + h),
            imgui.ColorConvertFloat4ToU32(ImVec4(colAccent.x, colAccent.y, colAccent.z, 0.25)), S(4))
        dl:AddRectFilled(pos, ImVec2(pos.x + S(3), pos.y + h),
            imgui.ColorConvertFloat4ToU32(ImVec4(0.85, 0.85, 0.9, 1)), S(2))
    elseif pressed then
        dl:AddRectFilled(pos, ImVec2(pos.x + w, pos.y + h),
            imgui.ColorConvertFloat4ToU32(ImVec4(1, 1, 1, 0.12)), S(4))
    elseif hovered then
        dl:AddRectFilled(pos, ImVec2(pos.x + w, pos.y + h),
            imgui.ColorConvertFloat4ToU32(ImVec4(1, 1, 1, 0.06)), S(4))
    end

    local col = active and 0xFFFFFFFF or 0xFF999999
    local xOff = S(12)
    if icon ~= "" then
        dl:AddText(ImVec2(pos.x + xOff, pos.y + h / 2 - S(7)), col, icon)
        xOff = xOff + S(24)
    end
    dl:AddText(ImVec2(pos.x + xOff, pos.y + h / 2 - S(7)), col, label)
end

local function centeredHeader(text)
    local avail = imgui.GetContentRegionAvail().x
    local size = imgui.CalcTextSize(text).x
    imgui.SetCursorPosX(imgui.GetCursorPosX() + (avail - size) / 2)
    imgui.TextUnformatted(text)
    imgui.Separator()
    imgui.Spacing()
end

imgui.OnInitialize(function()
    if okFa and type(fa.Init) == "function" then pcall(fa.Init) end
    applyTheme()
    local io = imgui.GetIO()
    pcall(function() io.IniFilename = nil end)

    local s = imgui.GetStyle()
    s.ScrollbarSize = S(10); s.GrabMinSize = S(12)
    s.WindowRounding = S(8); s.ChildRounding = S(6); s.FrameRounding = S(4)
    s.WindowBorderSize = 0; s.ChildBorderSize = 1
    s.WindowPadding = ImVec2(S(12), S(12))
    s.FramePadding  = ImVec2(S(8), S(6))
    s.ItemSpacing   = ImVec2(S(8), S(6))
    s.TouchExtraPadding = ImVec2(S(4), S(4))

    local c = s.Colors
    c[imgui.Col.WindowBg]       = ImVec4(0.08, 0.08, 0.09, cfg.design.bgAlpha / 100)
    c[imgui.Col.ChildBg]        = ImVec4(0.12, 0.12, 0.13, 1)
    c[imgui.Col.Button]         = ImVec4(0.16, 0.16, 0.18, 1)
    c[imgui.Col.FrameBg]        = ImVec4(0.15, 0.15, 0.16, 1)
    c[imgui.Col.FrameBgHovered] = ImVec4(0.2, 0.2, 0.22, 1)
    c[imgui.Col.FrameBgActive]  = ImVec4(0.2, 0.2, 0.22, 1)
    c[imgui.Col.Text]           = ImVec4(0.9, 0.9, 0.9, 1)
    c[imgui.Col.Separator]      = ImVec4(0.2, 0.2, 0.22, 1)

    local fontPath = "/system/fonts/Roboto-Regular.ttf"
    if doesFileExist(fontPath) then
        pcall(function()
            io.Fonts:AddFontFromFileTTF(fontPath, S(15), nil, io.Fonts:GetGlyphRangesCyrillic())
        end)
    end
end)

imgui.OnFrame(function()
    return menuOpen or menuAlpha > 0.01 or #toasts > 0 or cfg.settings.showFarmBtn
end, function(player)
    local sw, sh = getScreenResolution()
    local dt = imgui.GetIO().DeltaTime
    if dt > 0.05 then dt = 0.05 end

    processFarmButton()

    if isFarming then
        local left = (isCefActive and pausedEtaLeft) or (etaUnix - os.time())
        if left < 0 then left = 0 end
        local shown = progressKm
        if shown < progressStart then shown = progressStart end
        if shown > 2000 then shown = 2000 end

        if progressStart ~= 0 and progressKm >= 2000 then
            stopFarm(nil)
            showToast(u8"Достижение выполнено (2000/2000 км)!")
        end

        local t = os.date("!*t", left)
        local dl = imgui.GetBackgroundDrawList()
        local bx, by = S(15), S(250)
        dl:AddRectFilled(ImVec2(bx, by), ImVec2(bx + S(240), by + S(88)),
            imgui.ColorConvertFloat4ToU32(ImVec4(0, 0, 0, 0.55)), S(6))
        local status = isCefActive and u8"Пауза" or (isParsingRewards and u8"Чтение /rewards" or u8"В процессе")
        dl:AddText(ImVec2(bx + S(12), by + S(10)), 0xFFFFFFFF, u8"Фарм: " .. status)
        dl:AddText(ImVec2(bx + S(12), by + S(34)), 0xFF32CD32, u8"Пробег: " .. sumFormat(shown) .. " / 2.000")
        dl:AddText(ImVec2(bx + S(12), by + S(58)), 0xFFFF634F,
            u8"Осталось: " .. string.format("%02d:%02d", t.min or 0, t.sec or 0))
    end

    drawFarmButton()

    local stackY = 0
    for i = #toasts, 1, -1 do
        local tt = toasts[i]
        tt.life = tt.life - dt
        local appear, fade = 0.3, 0.4
        local alpha = 1
        if stackY > sh / 2.5 and fade < tt.life then tt.life = fade end
        if appear > tt.maxLife - tt.life then
            local p = (tt.maxLife - tt.life) / appear
            tt.slideX = 450 * (1 - p); alpha = p
        elseif fade > tt.life then
            local p = 1 - tt.life / fade
            if p > 1 then p = 1 end; if p < 0 then p = 0 end
            tt.slideX = 450 * p; alpha = 1 - p
        else
            tt.slideX = tt.slideX + (0 - tt.slideX) * dt * 15
        end
        tt.targetY = stackY
        tt.currY = tt.currY + (tt.targetY - tt.currY) * dt * 10
        local y = sh - 25 - tt.currY

        if tt.life <= 0 and tt.slideX >= 440 then
            table.remove(toasts, i)
        else
            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
            imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, S(8))
            imgui.PushStyleColor(imgui.Col.WindowBg, ImVec4(0.12, 0.12, 0.13, 0.95))
            imgui.PushStyleColor(imgui.Col.Border, colAccent)
            imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1)
            imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, ImVec2(S(15), S(12)))
            imgui.SetNextWindowPos(ImVec2(sw - 25 + tt.slideX, y), imgui.Cond.Always, ImVec2(1, 1))
            imgui.Begin(tt.id, nil,
                imgui.WindowFlags.NoDecoration + imgui.WindowFlags.AlwaysAutoResize +
                imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.NoFocusOnAppearing +
                imgui.WindowFlags.NoNav + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoInputs)
            imgui.TextColored(ImVec4(1, 0.85, 0, 1), ico("BELL") .. " " .. u8"Уведомление")
            imgui.Separator()
            imgui.TextUnformatted(tt.text)
            tt.height = imgui.GetWindowHeight()
            imgui.End()
            imgui.PopStyleVar(4); imgui.PopStyleColor(2)
            stackY = stackY + tt.height + 10
        end
    end

    if menuOpen then
        if menuAlpha < 1 then menuAlpha = math.min(1, menuAlpha + dt * 6) end
    else
        if menuAlpha > 0 then menuAlpha = math.max(0, menuAlpha - dt * 6) end
    end
    if menuAlpha <= 0.01 then return end

    if cfg.design.dimming > 0 then
        imgui.GetBackgroundDrawList():AddRectFilled(ImVec2(0, 0), ImVec2(sw, sh),
            imgui.ColorConvertFloat4ToU32(ImVec4(0, 0, 0, cfg.design.dimming / 100 * menuAlpha)))
    end

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, menuAlpha)

    local flags = imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse
                + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoTitleBar
    if not menuOpen then flags = flags + imgui.WindowFlags.NoInputs end

    local winW = math.min(S(700), sw - S(40))
    local winH = math.min(S(450), sh - S(80))

    imgui.SetNextWindowSize(ImVec2(winW, winH), imgui.Cond.Always)
    imgui.SetNextWindowPos(ImVec2(sw / 2, sh / 2), imgui.Cond.Always, ImVec2(0.5, 0.5))
    imgui.Begin(u8"Probeg Auto-Farm by pinokio##MainWindow", nil, flags)

    imgui.SetCursorPosY(S(12))
    local title = ico("CAR") .. " " .. u8"Probeg Auto-Farm"
    imgui.SetCursorPosX((winW - imgui.CalcTextSize(title).x) / 2 - S(20))
    imgui.TextColored(ImVec4(0.85, 0.85, 0.85, 1), title)

    imgui.SetCursorPos(ImVec2(winW - S(48), S(12)))
    imgui.PushStyleColor(imgui.Col.Button, ImVec4(0.5, 0.15, 0.15, 0.85))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, ImVec4(0.85, 0.25, 0.25, 1))
    imgui.PushStyleColor(imgui.Col.ButtonActive, ImVec4(0.7, 0.1, 0.1, 1))
    if imgui.Button(ico("XMARK") .. "##closeMenu", ImVec2(S(36), S(30))) then
        menuOpen = false
    end
    imgui.PopStyleColor(3)

    imgui.SetCursorPosY(S(50))
    imgui.Separator()
    imgui.SetCursorPosY(S(60))

    local sideW = S(190)
    imgui.BeginChild("Sidebar", ImVec2(sideW, 0), true,
        imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
    imgui.SetCursorPosY(S(8))
    tabButton(u8"Инструкция", ico("BOOK"),       1); imgui.Spacing()
    tabButton(u8"Настройки",  ico("GEARS"),      2); imgui.Spacing()
    tabButton(u8"Дизайн",     ico("PALETTE"),    3)
    imgui.EndChild()
    imgui.SameLine()

    imgui.BeginChild("Content", ImVec2(0, 0), true)

    if currentTab == 1 then
        centeredHeader(u8"Инструкция")
        imgui.TextColored(ImVec4(0.9, 0.4, 0.4, 1), u8"Gigahorse MadMax")
        imgui.Separator()
        imgui.BulletText(u8"TwinTurbo 2 + бак на 160л")
        imgui.BulletText(u8"Встань в гараже или паркинге")
        imgui.BulletText(u8"Sport режим")
        imgui.BulletText(u8"Запусти через /probeg или кнопку FARM")
        imgui.Spacing()
        imgui.TextColored(ImVec4(0.9, 0.4, 0.4, 1), u8"McLaren 570s")
        imgui.Separator()
        imgui.BulletText(u8"TwinTurbo 2 + бак 160л + алмазные запчасти")
        imgui.BulletText(u8"Остальное — как на Gigahorse")

    elseif currentTab == 2 then
        centeredHeader(u8"Настройки")
        imgui.Spacing()
        if imgui.Checkbox(u8"Показывать кнопку FARM на экране", farmBtn) then
            cfg.settings.showFarmBtn = farmBtn[0]; saveCfg()
        end
        imgui.Spacing()
        imgui.TextWrapped(u8"Удерживай кнопку 1.5 секунды — включится перемещение.")
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        imgui.TextWrapped(u8"Сброс позиции кнопки FARM:")
        if imgui.Button(u8"Сбросить позицию", ImVec2(-1, S(32))) then
            cfg.design.farmBtnX = -1
            cfg.design.farmBtnY = -1
            saveCfg()
            showToast(u8"Позиция кнопки сброшена")
        end
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        imgui.TextWrapped(u8"Тонкая настройка синхронизации:")
        imgui.Spacing()

        imgui.Text(u8"Интервал sync: " .. tostring(cfg.design.syncInterval) .. u8" мс")
        imgui.PushItemWidth(-1)
        imgui.SliderInt("##syncInt", sliderSyncInt, 100, 500, "%d")
        if imgui.IsItemDeactivatedAfterEdit() then
            cfg.design.syncInterval = sliderSyncInt[0]
            saveCfg()
        end
        imgui.PopItemWidth()

        imgui.Text(u8"Радиус: " .. string.format("%.1f", cfg.design.circleRadius) .. u8" м")
        imgui.PushItemWidth(-1)
        imgui.SliderFloat("##circleR", sliderRadius, 4.0, 20.0, "%.1f")
        if imgui.IsItemDeactivatedAfterEdit() then
            cfg.design.circleRadius = sliderRadius[0]
            saveCfg()
        end
        imgui.PopItemWidth()

        imgui.Text(u8"Скорость: " .. string.format("%.1f", cfg.design.circleSpeed) .. u8" м/с")
        imgui.PushItemWidth(-1)
        imgui.SliderFloat("##circleS", sliderSpeed, 2.0, 15.0, "%.1f")
        if imgui.IsItemDeactivatedAfterEdit() then
            cfg.design.circleSpeed = sliderSpeed[0]
            saveCfg()
        end
        imgui.PopItemWidth()

    elseif currentTab == 3 then
        centeredHeader(u8"Дизайн")
        imgui.Spacing()
        imgui.Text(u8"Затемнение фона: " .. tostring(cfg.design.dimming) .. "%")
        imgui.PushItemWidth(-1)
        imgui.SliderInt("##Dim", sliderDimming, 0, 100, "%d")
        if imgui.IsItemDeactivatedAfterEdit() then
            cfg.design.dimming = sliderDimming[0]
            saveCfg()
        end
        imgui.PopItemWidth()
        imgui.Spacing()
        imgui.Text(u8"Прозрачность окна: " .. tostring(cfg.design.bgAlpha) .. "%")
        imgui.PushItemWidth(-1)
        imgui.SliderInt("##Alpha", sliderBgAlpha, 50, 100, "%d")
        if imgui.IsItemDeactivatedAfterEdit() then
            cfg.design.bgAlpha = sliderBgAlpha[0]
            saveCfg()
            imgui.GetStyle().Colors[imgui.Col.WindowBg] =
                ImVec4(0.08, 0.08, 0.09, sliderBgAlpha[0] / 100)
        end
        imgui.PopItemWidth()
    end

    imgui.EndChild()
    imgui.End()
    imgui.PopStyleVar()
end)

function main()
    while not isSampAvailable() do wait(100) end
    while not doesCharExist(PLAYER_PED) do wait(100) end
    wait(500)

    sampRegisterChatCommand("fs", function()
        menuOpen = not menuOpen
    end)
    sampRegisterChatCommand("probeg", function()
        goFarm()
    end)

    if not syncOk then
        showToast(u8"Sync не инициализирован. Фарм выключен.")
    else
        showToast(u8"/probeg — фарм, /fs — меню")
    end

    while true do
        wait(0)

        if isFarming then stepFarmMotion() end

        if isFarming and not isParsingRewards then
            if os.clock() - lastProgressPoll >= progressPollEvery then
                lastProgressPoll = os.clock()
                parseSilent = true
                startParsing()
            end
        end

        if isParsingRewards and parseStartTime > 0 then
            if os.clock() - parseStartTime > parseTimeoutSec then
                isParsingRewards = false
                parseState = "idle"
                if sampIsDialogActive() then pcall(sampCloseCurrentDialogWithButton, 0) end
            end
        end

        local min = tonumber(os.date("%M"))
        local sec = tonumber(os.date("%S"))
        if not isCefActive and (min == 29 or min == 59) and sec >= 40 then
            isCefActive = true
            cefStartTime = os.clock()
            if etaUnix ~= 0 then pausedEtaLeft = etaUnix - os.time() end
        end
        if isCefActive and cefStartTime > 0 and os.clock() - cefStartTime > 30 then
            isCefActive = false
            cefStartTime = 0
            if pausedEtaLeft then
                etaUnix = os.time() + pausedEtaLeft
                pausedEtaLeft = nil
            end
        end
    end
end

function onScriptTerminate(s, q)
    if s == thisScript() then
        saveCfg()
        stopFarm(nil)
    end
end