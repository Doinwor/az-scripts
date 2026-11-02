script_name("Click Warp Mobile")
script_authors("FYP", "we_sux team", "Radare")
script_version_number(1)
script_description("Click and swipe, teleport!")

local Vector3D = require "vector3d"
local widgets = require "widgets"
local chooseActive, pointMarker, renderInfo

function onTouch(type, id, x, y)
    if chooseActive then
      local sx, sy = x, y
      local sw, sh = getScreenResolution()
      if sx >= 0 and sy >= 0 and sx < sw and sy < sh and id == 0 then
        local posX, posY, posZ = convertScreenCoordsToWorld3D(sx, sy, 700.0)
        local camX, camY, camZ = getActiveCameraCoordinates()
        local result, colpoint = processLineOfSight(camX, camY, camZ, posX, posY, posZ, true, true, false, true, false, false, false)
        if result and colpoint.entity ~= 0 then
          local normal = colpoint.normal
          local pos = Vector3D(colpoint.pos[1], colpoint.pos[2], colpoint.pos[3]) - (Vector3D(normal[1], normal[2], normal[3]) * 0.1)
          local zOffset = 300
          if normal[3] >= 0.5 then zOffset = 1 end
          local result, colpoint2 = processLineOfSight(pos.x, pos.y, pos.z + zOffset, pos.x, pos.y, pos.z - 0.3, true, true, false, true, false, false, false)
          if result then
            pos = Vector3D(colpoint2.pos[1], colpoint2.pos[2], colpoint2.pos[3] + 1)

            local curX, curY, curZ  = getCharCoordinates(playerPed)
            local dist              = getDistanceBetweenCoords3d(curX, curY, curZ, pos.x, pos.y, pos.z)
            local hoffs             = renderGetFontDrawHeight(font)
            local color              = 0xAAFFFFFF  
           
            sy = sy - 2
            sx = sx - 2
            renderInfo = {rsx = sx, rsy = sy, rhoffs = hoffs, rdist = dist, rcar = 0, rcolor = 0xAAFFFFFF}
            tpIntoCar = nil
            if colpoint.entityType == 2 then
              local car = getVehiclePointerHandle(colpoint.entity)
              if doesVehicleExist(car) and (not isCharInAnyCar(playerPed) or storeCarCharIsInNoSave(playerPed) ~= car) then
                tpIntoCar = car
                color = 0xFFFFFFFF
                renderInfo = {rsx = renderInfo.rsx, rsy = renderInfo.rsy, rhoffs = renderInfo.rhoffs, rdist = renderInfo.rdist, rcar = car, rcolor = color}
                end
              end
            end
            createPointMarker(pos.x, pos.y, pos.z)
            
             if type == 1 then
              if tpIntoCar then
                if not jumpIntoCar(tpIntoCar) then
                  teleportPlayer(pos.x, pos.y, pos.z)
                end
              else
                teleportPlayer(pos.x, pos.y, pos.z)
              end
              removePointMarker()
              renderInfo.rcar = 0
              chooseActive = false
            end
          end
        end
      end
end

function initializeRender()
  font = renderCreateFont("Arial", 17, 4)
  lua_thread.create(function()
      while true do
          wait(0)
          if chooseActive and pointMarker then
              renderFontDrawText(font, "Left your finger from the screen to teleport", renderInfo.rsx, renderInfo.rsy - (renderInfo.rhoffs * 3) - 150, renderInfo.rcolor) 
              renderFontDrawText(font, string.format("%0.2fm", renderInfo.rdist), renderInfo.rsx, renderInfo.rsy - (renderInfo.rhoffs*2) - 150, 0xEEEEEEEE)		  
  			if renderInfo.rcar ~= 0 then renderFontDrawText(font, string.format("%s", findCarName(getCarModel(renderInfo.rcar))), renderInfo.rsx, renderInfo.rsy - renderInfo.rhoffs - 150, 0xEEEEEEEE) end 
          end
      end
  end)
end

function getCarFreeSeat(car)
  if doesCharExist(getDriverOfCar(car)) then
    local maxPassengers = getMaximumNumberOfPassengers(car)
    for i = 0, maxPassengers do
      if isCarPassengerSeatFree(car, i) then
        return i + 1
      end
    end
    return nil 
  else
    return 0
  end
end

function jumpIntoCar(car)
  local seat = getCarFreeSeat(car)
  if not seat then return false end
  if seat == 0 then warpCharIntoCar(playerPed, car)
  else warpCharIntoCarAsPassenger(playerPed, car, seat - 1)
  end
  restoreCameraJumpcut()
  return true
end

function teleportPlayer(x, y, z)
    if isCharInAnyCar(PLAYER_PED) then
        setCarCoordinates(storeCarCharIsInNoSave(PLAYER_PED), x, y, z)
    else
        setCharCoordinates(PLAYER_PED, x, y, z)
    end
end
    
function main()
    initializeRender()
    while true do
        wait(0)
        local pressed_menu = isWidgetPressed(WIDGET_KISS)
        if pressed_menu and not was_pressed_menu then
             if not chooseActive then wait(200) 
             else removePointMarker() end
             chooseActive = not chooseActive
             printStringNow(chooseActive and "Choose position" or "You canceled choice", 3000)
        end
        was_pressed_menu = pressed_menu
    end
end

function createPointMarker(x, y, z)
  if pointMarker then removePointMarker() end
  pointMarker = createUser3dMarker(x, y, z + 0.3, 4)
end

function removePointMarker()
  if pointMarker then
    removeUser3dMarker(pointMarker)
    pointMarker = nil
  end
end

function findCarName(id)
    local input_text = readFile(getGameDirectory() .."/data/vehicles.ide")
    local lines = {}
    for line in input_text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    for _, line in ipairs(lines) do
        local parts = {}
        for part in line:gmatch("([^,]+)") do
            table.insert(parts, part)
        end

        local current_id = parts[1]:gsub("%s", "")
        if tonumber(current_id) == id then
            local second_value = parts[2]:gsub("%s", "")
            return second_value
        end
    end
    return nil
end

function readFile(path)
    local lines = {}
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    for line in f:lines() do
        if not line:match("^%s*#") then
            table.insert(lines, line)
        end
    end
    f:close()
    return table.concat(lines, "\n")
end