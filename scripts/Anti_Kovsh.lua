script_author('FunnyRofl')
script_description(' //www.blast.hk/members/507661 ')
local ExtraMode = true
local CeaselessWork = false
local sampev = require('lib.samp.events')
local Kovsch = {}
function sampev.onCreateObject(id, data)
  if (data.attachToVehicleId ~= 65535) then
    Kovsch[id] = {true, data.attachToVehicleId}
  end
end
local WorkAllowed = true
function sampev.onSetInterior(interiorId)
  if ExtraMode then
    WorkAllowed = (interiorId == 0)
  end
end
local MyCarId = false
function sampev.onSendVehicleSync(data)
  if not MyCarId then
    MyCarId = data.vehicleId
  end
end
function sampev.onSendPlayerSync()
  if MyCarId then
    MyCarId = false
  end
end
function sampev.onDestroyObject(objectId)
  if Kovsch[objectId] then
    Kovsch[objectId] = nil
  end
end
function main()
  if not isSampLoaded() or not isSampfuncsLoaded() then return end
  while not isSampAvailable() do wait(567)
  end
  if ExtraMode then
    lua_thread.create(function()
    while true do
      wait(1000)
      local bs = raknetNewBitStream()
      raknetBitStreamWriteBool(bs, true)
      raknetEmulRpcReceiveBitStream(167, bs)
      raknetDeleteBitStream(bs)
      if not CeaselessWork and WorkAllowed then
        SwitchOffGigaKovsch()
      end
    end
    end)
  end
  while true do
    wait(0)
    for i, _ in pairs(Kovsch) do
      if Kovsch[i][1] then
        local Result, ObjectHandle = pcall(sampGetObjectHandleBySampId, i)
        if Result and select(2, pcall(doesObjectExist, ObjectHandle)) then
          if (MyCarId and (Kovsch[i][2] ~= MyCarId) or true) then
            setObjectCollision(ObjectHandle, false)
            Kovsch[i][1] = false
          else
            Kovsch[i][1] = false
          end
        end
      end
    end

    if ExtraMode and CeaselessWork and WorkAllowed then
      SwitchOffGigaKovsch()
    end

  end
end
function SwitchOffGigaKovsch()
  if (isCharOnFoot(playerPed) or (not MyCarId)) then
    local AllObjects = getAllObjects()
    for _, ObjectHandle2 in pairs(AllObjects) do
      if isObjectAttached(ObjectHandle2) then
        setObjectCollision(ObjectHandle2, false)
      end
    end
  else
    local AllObjects = getAllObjects()
    for _, ObjectHandle2 in pairs(AllObjects) do
      if isObjectAttached(ObjectHandle2) then
        local PcallResult, Object_ID = pcall(sampGetObjectSampIdByHandle, ObjectHandle2)
        if PcallResult then
          local KovshOnMyCar = (Kovsch[Object_ID] and (Kovsch[Object_ID][2] == MyCarId) or false)
          setObjectCollision(ObjectHandle2, KovshOnMyCar )
        end
      end
    end
  end
end