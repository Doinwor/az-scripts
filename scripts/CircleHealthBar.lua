local imgui = require("mimgui")
local ev = require("samp.events")
local ffi = require ("ffi")
local new = imgui.new


local renderWindow = new.bool(true)

local newFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 1, 1
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('Main Window', renderWindow, imgui.WindowFlags.NoBackground + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoDecoration)
        
        local dl = imgui.GetBackgroundDrawList();
        
        local player_pos = {getCharCoordinates(PLAYER_PED)}
        player_pos[3] = player_pos[3] - 0.030
        local startX, startY = convert3DCoordsToScreen(player_pos[1], player_pos[2] , player_pos[3] + 1)
        drawHealthCircle(imgui.ImVec2(startX, startY), getCharHealth(PLAYER_PED), 100, 40.0);   
        for k, v in pairs(getAllChars()) do
    	
    local px, py, pz = getCharCoordinates(v)
    local inStream = isCharOnScreen(v)
    local xzcho = isLineOfSightClear(player_pos[1], player_pos[2] , player_pos[3], px, py, pz, true, false, false, true, false)
    local distance = getDistanceBetweenCoords3d(player_pos[1], player_pos[2] , player_pos[3], px, py, pz)
    -- Проверяем, находится ли персонаж в зоне стрима
    if inStream and xzcho and distance <= 100 and v ~= PLAYER_PED then
        local ex, ey = convert3DCoordsToScreen(px, py, pz)
        drawHealthCircle(imgui.ImVec2(ex, ey +10), getCharHealth(v), 100, 40.0);   
    end
end
        imgui.End()
    end
)

function main()
    sampRegisterChatCommand('mimgui', function()
        renderWindow[0] = not renderWindow[0]
    end)
end

 function drawHealthCircle(position, health, max_health, radius)
    local health_text = tostring(health)
    local a_max = (math.pi * 2.0)
    local v1 = health / max_health
    local difference = v1 - 1.0
    imgui.GetForegroundDrawList():PathArcTo(position, radius, (-(a_max / 4.0)) + (a_max / max_health) * (max_health - health), a_max - (a_max / 4.0), 200 - 1)
    imgui.GetForegroundDrawList():PathStroke(imgui.ColorConvertFloat4ToU32({math.abs(v1 - difference), v1, v1, 1.0}), 0, 2.0)
    imgui.GetForegroundDrawList():AddText({position.x - imgui.CalcTextSize(health_text).x / 2.0, position.y - imgui.CalcTextSize(health_text).y / 2.0}, imgui.ColorConvertFloat4ToU32({1, 1, 1, 1.0}), health_text)
end