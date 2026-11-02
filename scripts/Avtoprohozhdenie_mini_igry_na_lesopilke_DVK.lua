script_author('pinokio')
script_version('1.2')

local cjson = require("cjson")

local enabled = true
local lastStage, busy

local function sc(iface, id, subid, data)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, iface)
    raknetBitStreamWriteInt32(bs, id)
    raknetBitStreamWriteInt32(bs, subid)
    raknetBitStreamWriteInt16(bs, #(data or ""))
    raknetBitStreamWriteString(bs, data or "")
    raknetSendBitStreamEx(bs, 1, 7, 1)
    raknetDeleteBitStream(bs)
end

local function rs(bs)
    local len = raknetBitStreamReadInt16(bs)
    if not len or len <= 0 then return "" end
    local enc = raknetBitStreamReadInt8(bs)
    if enc ~= 0 then return raknetBitStreamDecodeString(bs, len + enc) end
    return raknetBitStreamReadString(bs, len)
end

local function hit(g)
    local p = math.floor(g.start + g.width / 2 + 0.5)
    local x = math.floor((p - g.start) / g.width * 100 + 0.5)
    wait(400)
    sc(8, 90, 90, "")
    wait(math.floor(p / g.speed + 0.5) * 75)
    sc(8, 91, 91, p .. ', ' .. x)
    busy = false
end

local function hs(s)
    if type(s) ~= 'table' then return end
    if tonumber(s.isMyState) ~= 1 then return end

    local mv, cur = tonumber(s.moving), tonumber(s.currentPosition)
    if mv == nil or cur == nil then
        local u = s.infoUser
        if type(u) == 'table' and u[1] then
            mv  = mv  or tonumber(u[1].moving)
            cur = cur or tonumber(u[1].currentPosition)
        end
    end
    if mv ~= 0 or cur ~= -1 then return end

    local stage = tonumber(s.stage) or 0
    if stage == lastStage then return end
    lastStage, busy = stage, true

    local start = tonumber(s.start)
    local width = tonumber(s.width)
    local speed = tonumber(s.speed)
    if not start or not width or not speed or speed <= 0 or width <= 0 then
        busy = false
        return
    end

    lua_thread.create(function()
        hit({ start = start, width = width, speed = speed })
    end)
end

addEventHandler('onReceivePacket', function(id, bs)
    if id ~= 220 then return end
    pcall(function()
        raknetBitStreamIgnoreBits(bs, 8)
        if raknetBitStreamReadInt8(bs) ~= 84 then return end
        local iface = raknetBitStreamReadInt8(bs)
        local sub   = raknetBitStreamReadInt8(bs)
        local js    = rs(bs)
        if iface ~= 8 then return end

        if sub == 90 then
            lastStage, busy = nil, false
        elseif sub == 91 and enabled and not busy then
            local ok, tbl = pcall(cjson.decode, js)
            if ok and type(tbl) == 'table' and tbl[1] then
                hs(tbl[1])
            end
        end
    end)
end)

function main()
    while not isSampAvailable() do wait(100) end
    while not doesCharExist(PLAYER_PED) do wait(100) end

    sampRegisterChatCommand('rll', function()
        enabled = not enabled
        lastStage, busy = nil, false
        sampAddChatMessage(enabled and "{B0E0E6}[rll]{FFFFFF} вкл" or  "{B0E0E6}[rll]{FFFFFF} выкл", -1)
    end)

    sampAddChatMessage("{B0E0E6}[rll]{FFFFFF} загружен. /rll - вкл/выкл", -1)
    wait(-1)
end