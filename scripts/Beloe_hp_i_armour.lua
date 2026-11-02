script_name("White Hp Hud + Car")
script_author("Krutoi pocik + rework")

require "lib.moonloader"

local imgui = require 'mimgui'
local encoding = require 'encoding'

encoding.default = 'CP1251'
u8 = encoding.UTF8

local hpAnim = 100.0
local armorAnim = 100.0
local vehHpAnim = 1000.0
local speedAnim = 0.0

local barWidth = 220
local barHeight = 30
local spacingY = 5

local function clamp(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

function main()
    repeat wait(0) until isSampAvailable()

    while true do
        wait(0)

        if doesCharExist(PLAYER_PED) then

            -- ================= PLAYER =================

            local hp = getCharHealth(PLAYER_PED)
            local armor = getCharArmour(PLAYER_PED)

            hpAnim = hpAnim + (hp - hpAnim) * 0.12
            armorAnim = armorAnim + (armor - armorAnim) * 0.12

            -- ================= VEHICLE =================

            if isCharInAnyCar(PLAYER_PED) then

                local car = storeCarCharIsInNoSave(PLAYER_PED)

                -- HP машины
                local vehHp = getCarHealth(car)
                vehHpAnim = vehHpAnim + (vehHp - vehHpAnim) * 0.10

                -- Скорость
                local speed = getCarSpeed(car) * 3.6

                -- Плавность
                if speed > speedAnim then
                    speedAnim = speedAnim + (speed - speedAnim) * 0.05
                else
                    speedAnim = speedAnim + (speed - speedAnim) * 0.15
                end

                if speedAnim > speed then
                    speedAnim = speed
                end
            else
                speedAnim = speedAnim * 0.90
            end
        end
    end
end

imgui.OnFrame(
function() return true end,
function()

    if not doesCharExist(PLAYER_PED) then
        return
    end

    local draw = imgui.GetForegroundDrawList()

    local hpFill = clamp(hpAnim / 100)
    local armorFill = clamp(armorAnim / 100)

    -- Координаты игрока
    local pX, pY, pZ = getCharCoordinates(PLAYER_PED)
    local ppX, ppY = convert3DCoordsToScreen(pX, pY, pZ)

    if not ppX or not ppY then
        return
    end

    local x = ppX - barWidth / 2
    local y = ppY

    local h = barHeight

    local bgColor = 0x60000000
    local fillColor = 0xB0CFCFCF
    local textColor = 0xCCFFFFFF
    local outlineColor = 0x20FFFFFF

    local function drawOutline(px, py, w, hh, col)
        draw:AddLine(imgui.ImVec2(px, py), imgui.ImVec2(px + w, py), col, 1.0)
        draw:AddLine(imgui.ImVec2(px, py + hh), imgui.ImVec2(px + w, py + hh), col, 1.0)
        draw:AddLine(imgui.ImVec2(px, py), imgui.ImVec2(px, py + hh), col, 1.0)
        draw:AddLine(imgui.ImVec2(px + w, py), imgui.ImVec2(px + w, py + hh), col, 1.0)
    end

    -- ================= SPEED =================

    if isCharInAnyCar(PLAYER_PED) then

        local speedText = math.floor(speedAnim + 0.5)

local speedText = math.floor(speedAnim + 0.5)

local t = math.min(speedText / 700, 1)

local r = 255
local g = math.floor(255 * (1 - t))
local b = math.floor(255 * (1 - t))

local speedColor =
    0xFF000000 +
    (r * 0x10000) +
    (g * 0x100) +
    b

        draw:AddText(
            imgui.ImVec2(x + 5, y - 20),
            speedColor,
            string.format("SPEED: %d KM/H", speedText)
        )
    end

    -- ================= PLAYER HP =================

    if hpAnim < 100 then
        draw:AddRectFilled(
            imgui.ImVec2(x, y),
            imgui.ImVec2(x + barWidth, y + h),
            bgColor,
            0
        )
    end

    draw:AddRectFilled(
        imgui.ImVec2(x, y),
        imgui.ImVec2(x + barWidth * hpFill, y + h),
        fillColor,
        0
    )

    drawOutline(x, y, barWidth, h, outlineColor)

    draw:AddText(
        imgui.ImVec2(x + 8, y + 6),
        textColor,
        string.format("HP: %d", math.floor(hpAnim))
    )

    -- ================= ARMOR =================

    local y2 = y + barHeight + spacingY

    if armorAnim < 100 then
        draw:AddRectFilled(
            imgui.ImVec2(x, y2),
            imgui.ImVec2(x + barWidth, y2 + h),
            bgColor,
            0
        )
    end

    draw:AddRectFilled(
        imgui.ImVec2(x, y2),
        imgui.ImVec2(x + barWidth * armorFill, y2 + h),
        fillColor,
        0
    )

    drawOutline(x, y2, barWidth, h, outlineColor)

    draw:AddText(
        imgui.ImVec2(x + 8, y2 + 6),
        textColor,
        string.format("AR: %d", math.floor(armorAnim))
    )

    -- ================= CAR HP =================

    if isCharInAnyCar(PLAYER_PED) then

        local vehFill = clamp(vehHpAnim / 1000)

        -- Под ARMOR с маленьким зазором
        local y3 = y2 + barHeight + 4

        if vehHpAnim < 1000 then
            draw:AddRectFilled(
                imgui.ImVec2(x, y3),
                imgui.ImVec2(x + barWidth, y3 + h),
                bgColor,
                0
            )
        end

        draw:AddRectFilled(
            imgui.ImVec2(x, y3),
            imgui.ImVec2(x + barWidth * vehFill, y3 + h),
            fillColor,
            0
        )

        drawOutline(x, y3, barWidth, h, outlineColor)

        draw:AddText(
            imgui.ImVec2(x + 8, y3 + 6),
            textColor,
            string.format("CAR HP: %d", math.floor(vehHpAnim))
        )
    end
end
)