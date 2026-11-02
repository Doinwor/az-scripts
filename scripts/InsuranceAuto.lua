script_author("@T23Vladimir")

local sampev = require('lib.samp.events')
local imgui = require('mimgui')
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local inicfg = require('inicfg')

local window_settings = imgui.new.bool()
local cfgPath = 'InsuranceAuto.ini'
local defaults = { main = { active = 0, delay = 0, tap = 0, tapDelay = 20, bg = 0, bgDelay = 0, fill = 0, nameDelay = 0, propDelay = 0, ticketDelay = 0, door = 0, delayJitter = 0, tapJitter = 0, bgJitter = 0, nameJitter = 0, propJitter = 0, ticketJitter = 0, timing = 0, filter = 0, minpay = 0, minPayAmount = 750000 } }
local cfg = inicfg.load(defaults, cfgPath)
inicfg.save(cfg, cfgPath)

local function clamp(v, max, min)
    min = min or 0
    return math.max(min, math.min(max, tonumber(v) or min))
end

local function jittered(base, spread)
    return math.max(0, base + math.random(-spread, spread))
end

local checkbox = imgui.new.bool(tonumber(cfg.main.active) == 1)
local tapBox = imgui.new.bool(tonumber(cfg.main.tap) == 1)
local bgBox = imgui.new.bool(tonumber(cfg.main.bg) == 1)
local delay = imgui.new.int(clamp(cfg.main.delay, 2500))
local tapDelay = imgui.new.int(clamp(cfg.main.tapDelay, 200, 20))
local bgDelay = imgui.new.int(clamp(cfg.main.bgDelay, 2500))
local fillBox = imgui.new.bool(tonumber(cfg.main.fill) == 1)
local nameDelay = imgui.new.int(clamp(cfg.main.nameDelay or 0, 4000))
local propDelay = imgui.new.int(clamp(cfg.main.propDelay or 0, 4000))
local ticketDelay = imgui.new.int(clamp(cfg.main.ticketDelay or 0, 4000))
local doorBox = imgui.new.bool(tonumber(cfg.main.door) == 1)
local delayJitter = imgui.new.int(clamp(cfg.main.delayJitter, 500))
local tapJitter = imgui.new.int(clamp(cfg.main.tapJitter, 100))
local bgJitter = imgui.new.int(clamp(cfg.main.bgJitter, 500))
local nameJitter = imgui.new.int(clamp(cfg.main.nameJitter or 0, 2000))
local propJitter = imgui.new.int(clamp(cfg.main.propJitter or 0, 2000))
local ticketJitter = imgui.new.int(clamp(cfg.main.ticketJitter or 0, 2000))
local timingBox = imgui.new.bool(tonumber(cfg.main.timing) == 1)
local typesBox = imgui.new.bool(tonumber(cfg.main.filter) == 1)
local minPayBox = imgui.new.bool(tonumber(cfg.main.minpay) == 1)
local minPay = imgui.new.int(clamp(cfg.main.minPayAmount or 750000, 100000000))

local function nowMs()
    if getGameTimer then return getGameTimer() end
    return math.floor(os.clock() * 1000)
end

local function report(text)
    if timingBox[0] then msg(text) end
end

local function skippedKind(s)
    if not typesBox[0] then return nil end
    if s:find('Дом') or s:find('дом') then return 'дом' end
    if s:find('Бизнес') or s:find('бизнес') then return 'бизнес' end
    return nil
end

local function payOf(text)
    local clean = text:gsub('{%x%x%x%x%x%x}', '')
    local digits = clean:match('Оплата сотруднику[^\n]-:%s*%$?%s*([%d%.,]+)')
    if not digits then return nil end
    digits = digits:gsub('%D', '')
    return tonumber(digits)
end

local spamcheck = false
local expectDetail = false
local busyUntil = 0
local catchOffset = 0
local catchStart = 0
local catchTotal = 0
local catchExpire = 0
local expectUntil = 0
local needNickFix = false
local activate = checkbox[0]
local lovlya_player = 'Dis'

local function saveCfg()
    cfg.main.active = checkbox[0] and 1 or 0
    cfg.main.delay = delay[0]
    cfg.main.tap = tapBox[0] and 1 or 0
    cfg.main.tapDelay = tapDelay[0]
    cfg.main.bg = bgBox[0] and 1 or 0
    cfg.main.bgDelay = bgDelay[0]
    cfg.main.fill = fillBox[0] and 1 or 0
    cfg.main.nameDelay = nameDelay[0]
    cfg.main.propDelay = propDelay[0]
    cfg.main.ticketDelay = ticketDelay[0]
    cfg.main.door = doorBox[0] and 1 or 0
    cfg.main.delayJitter = delayJitter[0]
    cfg.main.tapJitter = tapJitter[0]
    cfg.main.bgJitter = bgJitter[0]
    cfg.main.nameJitter = nameJitter[0]
    cfg.main.propJitter = propJitter[0]
    cfg.main.ticketJitter = ticketJitter[0]
    cfg.main.timing = timingBox[0] and 1 or 0
    cfg.main.filter = typesBox[0] and 1 or 0
    cfg.main.minpay = minPayBox[0] and 1 or 0
    cfg.main.minPayAmount = minPay[0]
    inicfg.save(cfg, cfgPath)
end

local function waitUntil(part)
    local remain = catchStart + math.floor(catchTotal * part / 3) - nowMs()
    if remain > 0 then wait(remain) end
end

function sendFrontendClick(interfaceid, id, subid, json_str)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteInt32(bs, id)
    raknetBitStreamWriteInt32(bs, subid)
    raknetBitStreamWriteInt16(bs, #json_str)
    raknetBitStreamWriteString(bs, json_str)
    raknetSendBitStreamEx(bs, 1, 10, 1)
    raknetDeleteBitStream(bs)
end

local function frontendClicks(interfaceid, subid, wait_ms, spread)
    lua_thread.create(function()
        local started = nowMs()
        for i = 1, 4 do
            local d = jittered(wait_ms, spread)
            if d > 0 then wait(d) end
            sendFrontendClick(interfaceid, 0, subid, '{}')
            if i == 1 then
                report(string.format('Автокапча: %d мс (задержка %d, разброс +-%d, выпало %+d)', nowMs() - started, wait_ms, spread, d - wait_ms))
            end
        end
    end)
end

local tapping = false

local function startTapping()
    if tapping or not tapBox[0] then return end
    tapping = true
    lua_thread.create(function()
        local started = os.clock()
        local first, last, count = nil, nil, 0
        while tapping and tapBox[0] and os.clock() - started < 30 do
            sendFrontendClick(25, 0, -1, '{}')
            local now = nowMs()
            count = count + 1
            if not first then first = now end
            last = now
            wait(math.max(10, jittered(tapDelay[0], tapJitter[0])))
        end
        if count > 1 then
            report(string.format('Автонажатия: %d нажатий, средний интервал %d мс', count, math.floor((last - first) / (count - 1))))
        end
        tapping = false
    end)
end

local cjson = select(2, pcall(require, 'cjson'))
local doorPatterns = { '[Оо]ткрыть', u8('Открыть') }
local doorActive = false
local doorShownAt = 0
local doorLastSent = 0

local function sendDoorInteract()
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, 8)
    raknetBitStreamWriteInt32(bs, 7)
    raknetBitStreamWriteInt32(bs, -1)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteString(bs, '')
    raknetSendBitStreamEx(bs, 1, 7, 1)
    raknetDeleteBitStream(bs)
end

local function readDoorButton(bs)
    local subId = raknetBitStreamReadInt8(bs)
    if subId ~= 15 then return end
    local len = raknetBitStreamReadInt16(bs)
    local encoded = raknetBitStreamReadInt8(bs)
    local str = (encoded ~= 0) and raknetBitStreamDecodeString(bs, len + encoded) or raknetBitStreamReadString(bs, len)
    local ok, data = pcall(cjson.decode, str)
    doorActive = false
    if not ok or type(data) ~= 'table' or data.type == 0 then return end
    local title = tostring(data.title or '')
    for _, pat in ipairs(doorPatterns) do
        if title:find(pat) then
            doorActive = true
            doorShownAt = os.clock()
            return
        end
    end
end

local function doorInteract()
    if not doorActive then return end
    local now = os.clock()
    if now - doorShownAt > 2.0 then
        doorActive = false
        return
    end
    if now - doorLastSent < 0.1 then return end
    doorLastSent = now
    sendDoorInteract()
end

addEventHandler('onReceivePacket', function(id, bs)
    if id ~= 220 then return end
    raknetBitStreamIgnoreBits(bs, 8)
    local packetType = raknetBitStreamReadInt8(bs)
    if packetType ~= 84 and packetType ~= 62 then return end
    local interfaceid = raknetBitStreamReadInt8(bs)
    if interfaceid == 25 then
        if packetType == 84 or raknetBitStreamReadBool(bs) then
            startTapping()
        else
            tapping = false
        end
    elseif interfaceid == 81 and packetType == 84 and bgBox[0] then
        frontendClicks(81, 0, bgDelay[0], bgJitter[0])
    elseif interfaceid == 8 and packetType == 84 and doorBox[0] then
        pcall(readDoorButton, bs)
    end
end)

function imgui.CircleCheckbox(label, boolRef)
    local pressed = imgui.RadioButtonBool(label, boolRef[0])
    if pressed then
        boolRef[0] = not boolRef[0]
    end
    return pressed
end

local function extractAnswer(text)
    local answer = text:match('\n{[Ff][Ff][Ff][Ff]00}([^\n]+)')
    if not answer then return nil end
    answer = answer:gsub('%z', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if answer == '' then return nil end
    return answer
end

local fillNames = { [15111] = 'Никнейм', [15112] = 'Тип', [15113] = 'Номер' }

local function fillDialog(did, answer, wait_ms, spread)
    lua_thread.create(function()
        local started = nowMs()
        local planned = jittered(wait_ms, spread)
        wait(planned)
        if did == 15111 and needNickFix then
            answer = answer:gsub('l', 'I')
            needNickFix = false
        end
        pcall(sampSendDialogResponse, did, 1, 0, answer)
        report(string.format('Автозаполнение (%s): %d мс (задержка %d, разброс +-%d, выпало %+d)', fillNames[did], nowMs() - started, wait_ms, spread, planned - wait_ms))
    end)
end

local tab = 1

local function sliderRow(id, ref, min, max, label)
    imgui.PushItemWidth(180)
    if imgui.SliderInt('##' .. id, ref, min, max) then
        saveCfg()
    end
    imgui.PopItemWidth()
    imgui.SameLine()
    imgui.Text(u8(label))
end

local function option(id, ref, title)
    local pressed = imgui.CircleCheckbox('##' .. id, ref)
    if pressed then
        saveCfg()
    end
    imgui.SameLine()
    imgui.Text(u8(title))
    return pressed
end

local function tabButton(index, title)
    local base = tab == index and imgui.ImVec4(0.18, 0.44, 0.78, 1) or imgui.ImVec4(0.2, 0.25, 0.33, 1)
    imgui.PushStyleColor(imgui.Col.Button, base)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.25, 0.52, 0.88, 1))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.18, 0.44, 0.78, 1))
    if imgui.Button(u8(title) .. '##tab' .. index) then
        tab = index
    end
    imgui.PopStyleColor(3)
end

local function sectionTitle(title)
    imgui.TextColored(imgui.ImVec4(0.45, 0.7, 1, 1), u8(title))
end

local fillColumns = {
    { 'name', nameDelay, nameJitter, 'Никнейм' },
    { 'prop', propDelay, propJitter, 'Тип' },
    { 'ticket', ticketDelay, ticketJitter, 'Номер' }
}

local function centerText(text, width)
    local w = imgui.CalcTextSize(text).x
    imgui.SetCursorPosX(imgui.GetCursorPosX() + (width - w) / 2)
    imgui.Text(text)
end

local function fillRow(kind, max)
    for i, col in ipairs(fillColumns) do
        local ref = kind == 'delay' and col[2] or col[3]
        if i > 1 then imgui.SameLine() end
        imgui.BeginGroup()
        if kind == 'delay' then centerText(u8(col[4]), 100) end
        imgui.PushItemWidth(100)
        if imgui.SliderInt('##' .. col[1] .. kind, ref, 0, max) then
            saveCfg()
        end
        imgui.PopItemWidth()
        imgui.EndGroup()
    end
end

imgui.OnInitialize(function()
    local style = imgui.GetStyle()
    style.FrameRounding = 12
    style.GrabRounding = 12
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    local colors = style.Colors
    colors[imgui.Col.TitleBg] = colors[imgui.Col.TitleBgActive]
    colors[imgui.Col.TitleBgCollapsed] = colors[imgui.Col.TitleBgActive]
end)

imgui.OnFrame(function() return window_settings[0] end, function()
    local displaySize = imgui.GetIO().DisplaySize
    imgui.SetNextWindowPos(imgui.ImVec2(displaySize.x / 2, displaySize.y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(400, 520), imgui.Cond.FirstUseEver)
    imgui.Begin(u8('InsuranceAuto | СТК помощник'), window_settings)
    tabButton(1, 'Основное')
    imgui.SameLine()
    tabButton(2, 'Доп.функции')
    imgui.SameLine()
    tabButton(3, 'Настройки')
    imgui.Separator()
    if tab == 1 then
        if option('act', checkbox, 'Автоловля') then
            activate = checkbox[0]
            busyUntil = 0
            spamcheck = false
            expectDetail = false
        end
        option('types', typesBox, 'Скипать страховки на дома и бизнесы')
        option('minpay', minPayBox, 'Ловить от указанной суммы')
        option('door', doorBox, 'Автооткрытие дверей')
    elseif tab == 2 then
        option('tap', tapBox, 'Автонажатия в 1-м кабинете')
        option('bg', bgBox, 'Автокапча во 2-м кабинете')
        option('fill', fillBox, 'Автозаполнение в 3-м кабинете')
        option('timing', timingBox, 'Вывод в чат пройденного времени')
    else
        local shown = false
        local function section(title)
            if shown then imgui.Separator() end
            shown = true
            sectionTitle(title)
        end
        if checkbox[0] then
            section('Автоловля')
            sliderRow('actDelay', delay, 0, 2500, 'Задержка (мс)')
            sliderRow('actJitter', delayJitter, 0, 500, 'Разброс ± (мс)')
        end
        if minPayBox[0] then
            section('Не ловить страховки ниже')
            imgui.SameLine()
            imgui.PushItemWidth(90)
            if imgui.InputInt('##minPay', minPay, 0, 0) then
                if minPay[0] < 0 then minPay[0] = 0 end
                saveCfg()
            end
            imgui.PopItemWidth()
            imgui.SameLine()
            imgui.Text(u8('$'))
        end
        if tapBox[0] then
            section('Автонажатия в 1-м кабинете')
            sliderRow('tapDelay', tapDelay, 20, 200, 'Задержка (мс)')
            sliderRow('tapJitter', tapJitter, 0, 100, 'Разброс ± (мс)')
        end
        if bgBox[0] then
            section('Автокапча во 2-м кабинете')
            sliderRow('bgDelay', bgDelay, 0, 2500, 'Задержка (мс)')
            sliderRow('bgJitter', bgJitter, 0, 500, 'Разброс ± (мс)')
        end
        if fillBox[0] then
            section('Автозаполнение в 3-м кабинете')
            local width = 300 + 2 * imgui.GetStyle().ItemSpacing.x
            centerText(u8('Задержка (мс)'), width)
            fillRow('delay', 4000)
            centerText(u8('Разброс ± (мс)'), width)
            fillRow('jitter', 2000)
        end
        if not shown then
            imgui.TextWrapped(u8('Включите функции на вкладках «Основное» и «Доп.функции»'))
        end
    end
    imgui.End()
end)

function main()
    while not isSampAvailable() do wait(0) end
    math.randomseed(os.time())
    sampRegisterChatCommand("stk", function()
        activate = not activate
        checkbox[0] = activate
        busyUntil = 0
        spamcheck = false
        expectDetail = false
        saveCfg()
        sampAddChatMessage(activate and "[InsuranceAuto]: {FFFFFF}Автоловля включена!" or "[InsuranceAuto]: {FFFFFF}Автоловля выключена!", 0x2568BE)
    end)
    
    sampRegisterChatCommand("stkm", function() window_settings[0] = not window_settings[0] end)

    repeat wait(0) until sampIsLocalPlayerSpawned()
    while true do
        wait(50)
        if doorBox[0] and isCharOnFoot(PLAYER_PED) then
            pcall(doorInteract)
        end
    end
end  
function sampev.onServerMessage(color, text)
    if text:find('Вы приняли заявление') then
        busyUntil = os.time() + 900
    elseif text:find('Вы закончили оформление страховки') then
        busyUntil = 0
    end
    if fillBox[0] and text:find('неправильный ник клиента') then
        needNickFix = true
    end
    if activate then    
        if os.time() >= busyUntil and text:find('(.+) подал заявление на страхование имущества') then
            spamcheck = true
            catchOffset = math.random(-delayJitter[0], delayJitter[0])
            catchStart = nowMs()
            catchTotal = math.max(0, delay[0] + catchOffset)
            catchExpire = catchStart + catchTotal + 2000
            local nick = text:match('(.+) подал заявление на страхование имущества.')
            lovlya_player = nick
            lua_thread.create(function()
                waitUntil(1)
                if activate then ALT() end
            end)
        end
        if text:find("Ошибка") then
            spamcheck = false
            expectDetail = false
        end
    end
end
function sampev.onShowDialog(did, style, title, button1, button2, text)
    if spamcheck and nowMs() > catchExpire then spamcheck = false end
    if expectDetail and nowMs() > expectUntil then expectDetail = false end
    if string.find(title, 'Заявки на страхование') then
        if string.find(text, 'На данный момент нет заявок на страхование') then
            sampSendDialogResponse(did, 1, 0, nil)
            msg('Заявок на страхование нету')
            return false
        end
        if activate and spamcheck then
            spamcheck = false
            local index, free, mine, skippedMine
            local idx = -1
            for line in (text .. '\n'):gmatch('(.-)\n') do
                if idx >= 0 then
                    local clean = line:gsub('{%x%x%x%x%x%x}', '')
                    if clean:find('%S') and not clean:find('На данный момент нет заявок на страхование', 1, true) then
                        local isMine = lovlya_player and clean:find(lovlya_player, 1, true)
                        if skippedKind(clean) then
                            if isMine then skippedMine = true end
                        else
                            local taken = clean:find('|%s*%S+%s*$') ~= nil
                            if isMine and not taken then
                                index = idx
                                break
                            end
                            if isMine then mine = mine or idx end
                            if not taken then free = free or idx end
                        end
                    end
                end
                idx = idx + 1
            end
            index = index or free or mine
            if skippedMine then msg('Страховка пропущена, т.к. она на дом/бизнес') end
            local finded = index ~= nil
			if finded then
				expectDetail = true
				expectUntil = nowMs() + 5000
				lua_thread.create(function()
					waitUntil(2)
					sampSendDialogResponse(did, 1, index, nil)
				end)
				return false
			end
        end
    end 
    if expectDetail then
        if string.find(title, 'Заявление') then
            expectDetail = false
            local skipMsg
            local pay = payOf(text)
            if minPayBox[0] and pay and pay < minPay[0] then
                skipMsg = string.format('Страховка пропущена, т.к. оплата ниже %d$ (%d тыс$)', minPay[0], math.floor(pay / 1000))
            end
            lua_thread.create(function()
                waitUntil(3)
                if skipMsg then
                    sampSendDialogResponse(did, 0, 0, 0)
                    msg(skipMsg)
                    return
                end
                sampSendDialogResponse(did, 1, 0, 0)
                report(string.format('Автоловля: %d мс (задержка %d, разброс +-%d, выпало %+d)', nowMs() - catchStart, delay[0], delayJitter[0], catchOffset))
            end)
            return false
        end
    end
    if fillBox[0] then
        if did == 15111 or did == 15112 or did == 15113 then
            local answer = extractAnswer(text)
            if answer then
                local delays = { [15111] = nameDelay, [15112] = propDelay, [15113] = ticketDelay }
                local spreads = { [15111] = nameJitter, [15112] = propJitter, [15113] = ticketJitter }
                fillDialog(did, answer, delays[did][0], spreads[did][0])
                return false
            end
        end
    end
end

function msg(text)
    sampAddChatMessage('[InsuranceAuto]: {FFFFFF}'..text, 0x2568BE)
end

function ALT()
    local x, y, z = getCharCoordinates(PLAYER_PED)
    if isCharOnFoot(PLAYER_PED) then
        local data = samp_create_sync_data('player')
        data.keysData = data.keysData + 1024
        data.position = { x, y, z }
        data.send()
    else
        local data = samp_create_sync_data('vehicle')
        data.keysData = data.keysData + 4
        data.position = { x, y, z }
        data.send()
    end
end

function samp_create_sync_data(sync_type, copy_from_player)
    local ffi = require 'ffi'
    local sampfuncs = require 'sampfuncs'
    local raknet = require 'samp.raknet'
    require 'samp.synchronization'

    copy_from_player = copy_from_player or true
    local sync_traits = {
        player = { 'PlayerSyncData', raknet.PACKET.PLAYER_SYNC, sampStorePlayerOnfootData },
        vehicle = { 'VehicleSyncData', raknet.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData }
    }
    local sync_info = sync_traits[sync_type]
    local data_type = 'struct ' .. sync_info[1]
    local data = ffi.new(data_type, {})
    local raw_data_ptr = tonumber(ffi.cast('uintptr_t', ffi.new(data_type .. '*', data)))
    if copy_from_player then
        local copy_func = sync_info[3]
        if copy_func then
            local _, player_id
            if copy_from_player == true then
                _, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            else
                player_id = tonumber(copy_from_player)
            end
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
        __index = function(t, index)
            return data[index]
        end,
        __newindex = function(t, index, value)
            data[index] = value
        end
    }
    return setmetatable({ send = func_send }, mt)
end