-- MonetLoader for Android 2.0.0
-- Reference script: AirBrake
script_name('AirBrake')
script_version('1.0')
script_version_number(1)
script_author('The MonetLoader Team')
script_description('Allows you to "fly" through the map. Doubletap fist icon to enable or disable. Make sure to use analog vehicle controls!')

local sampev = require('samp.events') -- for spoofing sync
local widgets = require('widgets') -- for WIDGET_(...)


local was_doubletapped = false
local enabled = false
local speed = 0.3
local was_in_car = false
local last_car

function getMoveSpeed(heading, speed)
  return math.sin(-math.rad(heading)) * speed, math.cos(-math.rad(heading)) * speed
end

function setPlayerCarCoordinatesFixed(x, y, z)
  local ox, oy, oz = getCharCoordinates(PLAYER_PED)
  setCharCoordinates(PLAYER_PED, ox, oy, oz)
  local nx, ny, nz = getCharCoordinates(PLAYER_PED)
  local xoff = nx - ox
  local yoff = ny - oy
  local zoff = nz - oz

  setCharCoordinates(PLAYER_PED, x - xoff, y - yoff, z - zoff)
end

function sampev.onSendPlayerSync(data)
  if enabled then
    local mx, my = getMoveSpeed(getCharHeading(PLAYER_PED), speed > 1 and 1 or speed)
    data.moveSpeed.x = mx
    data.moveSpeed.y = my
  end
end

function sampev.onSendVehicleSync(data)
  if enabled then
    local mx, my = getMoveSpeed(getCharHeading(PLAYER_PED), speed > 2 and 2 or speed)
    data.moveSpeed.x = mx
    data.moveSpeed.y = my
  end
end

function processSpecialWidgets()
  local delta = 0
  if isWidgetPressed(WIDGET_ZOOM_IN) then
    delta = delta + speed / 2
  end
  if isWidgetPressed(WIDGET_ZOOM_OUT) then
    delta = delta - speed / 2
  end
  if isWidgetPressed(WIDGET_VIDEO_POKER_ADD_COIN) then
    speed = speed + 0.01
    if speed > 3.5 then speed = 3.5 end
    printStringNow('Speed: ' .. string.format("%.2f", speed), 500)
  end
  if isWidgetPressed(WIDGET_VIDEO_POKER_REMOVE_COIN) then
    speed = speed - 0.01
    if speed < 0.1 then speed = 0.1 end
    printStringNow('Speed: ' .. string.format("%.2f", speed), 500)
  end

  return delta
end

function processAirBrake()
  local x1, y1, z1 = getActiveCameraCoordinates()
  local x, y, z = getActiveCameraPointAt()
  local angle = -math.rad(getHeadingFromVector2d(x - x1, y - y1))

  if isCharInAnyCar(PLAYER_PED) then
    local car = storeCarCharIsInNoSave(PLAYER_PED)
    if car ~= last_car and last_car ~= nil and doesVehicleExist(last_car) and was_in_car then
      freezeCarPosition(last_car, false)
      setCarCollision(last_car, true)
    end
    was_in_car = true
    last_car = car
    freezeCarPosition(car, true)
    setCarCollision(car, false)

    local result, var_1, var_2 = isWidgetPressedEx(WIDGET_VEHICLE_STEER_ANALOG, 0)
    if not result then
      var_1 = 0
      var_2 = 0
    end
    local intensity_x = var_1 / 127
    local intensity_y = var_2 / 127

    local cx, cy, cz = getCharCoordinates(PLAYER_PED)
    cx = cx - (math.sin(angle) * speed * intensity_y)
    cy = cy - (math.cos(angle) * speed * intensity_y)
    cx = cx + (math.cos(angle) * speed * intensity_x)
    cy = cy - (math.sin(angle) * speed * intensity_x)
    cz = cz + processSpecialWidgets()

    setPlayerCarCoordinatesFixed(cx, cy, cz)
    setCarHeading(car, math.deg(-angle))

    if intensity_x ~= 0 then
      restoreCameraJumpcut()
    end
  else
    if was_in_car and last_car ~= nil and doesVehicleExist(last_car) then
      freezeCarPosition(last_car, false)
      setCarCollision(last_car, true)
    end
    was_in_car = false
    freezeCharPosition(PLAYER_PED, true)
    setCharCollision(PLAYER_PED, false)

    local result, var_1, var_2 = isWidgetPressedEx(WIDGET_PED_MOVE, 0)
    if not result then
      var_1 = 0
      var_2 = 0
    end
    local intensity_x = var_1 / 127
    local intensity_y = var_2 / 127

    local cx, cy, cz = getCharCoordinates(PLAYER_PED)
    cx = cx - (math.sin(angle) * speed * intensity_y)
    cy = cy - (math.cos(angle) * speed * intensity_y)
    cx = cx + (math.cos(angle) * speed * intensity_x)
    cy = cy - (math.sin(angle) * speed * intensity_x)
    cz = cz + processSpecialWidgets()

    setCharCoordinatesNoOffset(PLAYER_PED, cx, cy, cz)
    setCharHeading(PLAYER_PED, math.deg(-angle))

    if intensity_x ~= 0 then
      restoreCameraJumpcut()
    end
  end
end

function main()
  while true do
    wait(0)

    if enabled then
      processAirBrake()
    end

    if isWidgetDoubletapped(WIDGET_PLAYER_INFO) then
      if not was_doubletapped then
        enabled = not enabled
        if not enabled then
          if last_car ~= nil and doesVehicleExist(last_car) and was_in_car then
            freezeCarPosition(last_car, false)
            setCarCollision(last_car, true)
          end
          if not was_in_car then
            freezeCharPosition(PLAYER_PED, false)
            setCharCollision(PLAYER_PED, true)
          end

          was_in_car = false
        end

        if enabled then
          printStringNow('~g~on', 1000)
        else
          printStringNow('~r~off', 1000)
        end
        was_doubletapped = true
      end
    else
      was_doubletapped = false
    end
  end
end