local car_col_act = true
local obj_col_act = true
local players_col_act = true

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand("col", function()
        car_col_act = not car_col_act
        obj_col_act = not obj_col_act
        players_col_act = not players_col_act
        if car_col_act then
            sampAddChatMessage('[Collision]: Включено', -1)
        else
            sampAddChatMessage('[Collision]: Выключено', -1)
        end
    end)
    while true do
        wait(0)
        if car_col_act then
            myPosX, myPosY, myPosZ = getCharCoordinates(PLAYER_PED)
            result, vehHandle = findAllRandomVehiclesInSphere(myPosX, myPosY, myPosZ, 25, true, true)
            if result then
                if vehHandle ~= storeCarCharIsInNoSave(PLAYER_PED) then
                    setCarCollision(vehHandle, false)
                end
            end  
        else
            myPosX, myPosY, myPosZ = getCharCoordinates(PLAYER_PED)
            result, vehHandle = findAllRandomVehiclesInSphere(myPosX, myPosY, myPosZ, 25, true, true)
            if result then
                if vehHandle then
                    setCarCollision(vehHandle, true)
                end
            end
        end

        if players_col_act then
            find_ped_x, find_ped_y, find_ped_z = getCharCoordinates(PLAYER_PED)
            result, pedHandle = findAllRandomCharsInSphere(find_ped_x, find_ped_y, find_ped_z, 25, true, false)
            if result then
                setCharCollision(pedHandle, false)
            end
        else
            find_obj_x, find_obj_y, find_obj_z = getCharCoordinates(PLAYER_PED)
            result, pedHandle = findAllRandomCharsInSphere(find_obj_x, find_obj_y, find_obj_z, 25, true, false)
            if result then
                setCharCollision(pedHandle, true)
            end
        end

        if obj_col_act then
            find_obj_x, find_obj_y, find_obj_z = getCharCoordinates(PLAYER_PED)
            result, objectHandle = findAllRandomObjectsInSphere(find_obj_x, find_obj_y, find_obj_z, 25, true)
            if result then
                setObjectCollision(objectHandle, false)
            end
        else
            find_obj_x, find_obj_y, find_obj_z = getCharCoordinates(PLAYER_PED)
            result, objectHandle = findAllRandomObjectsInSphere(find_obj_x, find_obj_y, find_obj_z, 25, true)
            if result then
                setObjectCollision(objectHandle, true)
            end
        end
    end
end