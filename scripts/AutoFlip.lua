script_name('AutoFlip.lua')
script_author('fsrxvdd (blast hack), @T23Vladimir')

local inicfg = require 'inicfg'

local DEFAULT_DELAY = 0.75
local MIN_DELAY = 0.1
local MAX_DELAY = 3

local cfg = inicfg.load({
    settings = {
        enabled = true,
        delay   = DEFAULT_DELAY,
        mode    = 'arizona',
    }
}, 'autoflip.ini')

local function saveCfg()
    inicfg.save(cfg, 'autoflip.ini')
end

local JACK_CMD = {
    arizona = '/domkrat',
    rodina  = '/jack',
}

local mode = tostring(cfg.settings.mode) == 'rodina' and 'rodina' or 'arizona'

local enabled = tostring(cfg.settings.enabled) ~= 'false'
local flipDelay = tonumber(cfg.settings.delay) or DEFAULT_DELAY
if flipDelay < MIN_DELAY or flipDelay > MAX_DELAY then flipDelay = DEFAULT_DELAY end

local flipped = false
local flipStartTime = nil

function quaternion_multiply(a, b, c, d,    w, x, y, z)
    return a * w - b * x - c * y - d * z,    a * x + b * w + c * z - d * y,    a * y - b * z + c * w + d * x,    a * z + b * y - c * x + d * w
end

function rotate_vector_on_quaternion(x, y, z,    a, b, c, d)
    local a1, b1, c1, d1 = quaternion_multiply(a, b, c, d,    0, x, y, z)
    local a2, b2, c2, d2 = quaternion_multiply(a1, b1, c1, d1,    a, -b, -c, -d)
    return b2, c2, d2
end

function main()
    while not isSampAvailable() do wait(0) end

    sampRegisterChatCommand('dm', function()
        enabled = not enabled
        flipStartTime = nil
        flipped = false
        cfg.settings.enabled = enabled
        saveCfg()
        if enabled then
            sampAddChatMessage("[AutoFlip] \xd1\xea\xf0\xe8\xef\xf2 \xe2\xea\xeb\xfe\xf7\xb8\xed", 0xFF00FF00)
        else
            sampAddChatMessage("[AutoFlip] \xd1\xea\xf0\xe8\xef\xf2 \xe2\xfb\xea\xeb\xfe\xf7\xe5\xed", 0xFFFF0000)
        end
    end)

    sampRegisterChatCommand('dmd', function(arg)
        local v = tonumber(((arg or ''):gsub(',', '.')))
        if not v or v < MIN_DELAY or v > MAX_DELAY then
            sampAddChatMessage("[AutoFlip] \xc8\xf1\xef\xee\xeb\xfc\xe7\xee\xe2\xe0\xed\xe8\xe5: /dmd [0.1-3], \xed\xe0\xef\xf0\xe8\xec\xe5\xf0 /dmd 1.5", 0xFFFF0000)
            return
        end
        flipDelay = v
        cfg.settings.delay = v
        saveCfg()
        sampAddChatMessage(string.format("[AutoFlip] \xc7\xe0\xe4\xe5\xf0\xe6\xea\xe0 \xf3\xf1\xf2\xe0\xed\xee\xe2\xeb\xe5\xed\xe0: %.2f \xf1\xe5\xea", flipDelay), 0xFF00FF00)
    end)

    sampRegisterChatCommand('dmm', function()
        mode = (mode == 'arizona') and 'rodina' or 'arizona'
        cfg.settings.mode = mode
        saveCfg()
        flipStartTime = nil
        flipped = false
        if mode == 'arizona' then
            sampAddChatMessage("[AutoFlip] \xd0\xe5\xe6\xe8\xec: Arizona (/domkrat)", 0xFF00FF00)
        else
            sampAddChatMessage("[AutoFlip] \xd0\xe5\xe6\xe8\xec: \xd0\xee\xe4\xe8\xed\xe0 (/jack)", 0xFF00FF00)
        end
    end)

    while true do
        wait(0)
        local upsideDown = false
        if enabled and isCharInAnyCar(PLAYER_PED) then
            local car = storeCarCharIsInNoSave(PLAYER_PED)
            local ok, result = pcall(function()
                local x, y, z, w = getVehicleQuaternion(car)
                if x and y and z and w then
                    local vx, vy, vz = rotate_vector_on_quaternion(0, 0, 1, w, x, y, z)
                    return vz < 0
                end
                return isCarUpsidedown(car)
            end)
            upsideDown = ok and result == true
        end

        if upsideDown then
            if not flipStartTime then
                flipStartTime = os.clock()
            end
            if not flipped and os.clock() - flipStartTime >= flipDelay then
                flipped = true
                sampSendChat(JACK_CMD[mode])
            end
        else
            flipStartTime = nil
            flipped = false
        end
    end
end
