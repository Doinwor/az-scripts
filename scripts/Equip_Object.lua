function slotApply(objid)
	
	
	
    local itemData = {
    [4] = 0.0,    -- offset x
    [5] = -0.13,    -- offset y
    [6] = 0.0,    -- offset z (небольшое положительное значение по оси Z для размещения на груди)
    [7] = 0.0,    -- rotation x
    [8] = 0.0,    -- rotation y
    [9] = 00.0,    -- rotation z
    [10] = 1.0,   -- scale x (масштаб по оси X)
    [11] = 1.0,   -- scale y (масштаб по оси Y)
    [12] = 1.0    -- scale z (масштаб по оси Z)
}
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt16(bs, select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) -- playerId
    raknetBitStreamWriteInt32(bs, 1) -- index
    raknetBitStreamWriteBool(bs,  true) -- create
    raknetBitStreamWriteInt32(bs, objid) -- modelId
    raknetBitStreamWriteInt32(bs, 1) -- bone
    raknetBitStreamWriteFloat(bs, itemData[4]) -- offset x
    raknetBitStreamWriteFloat(bs, itemData[5]) -- offset y
    raknetBitStreamWriteFloat(bs, itemData[6]) -- offset z
    raknetBitStreamWriteFloat(bs, itemData[7]) -- rotation x
    raknetBitStreamWriteFloat(bs, itemData[8]) -- rotation y
    raknetBitStreamWriteFloat(bs, itemData[9])  -- rotation z
    raknetBitStreamWriteFloat(bs, itemData[10]) -- scale x
    raknetBitStreamWriteFloat(bs, itemData[11]) -- scale y
    raknetBitStreamWriteFloat(bs, itemData[12]) -- scale z
    
        
    
        raknetBitStreamWriteInt32(bs, -1) -- color1
        raknetBitStreamWriteInt32(bs, -1) -- color2
    
    raknetEmulRpcReceiveBitStream(113, bs)
    raknetDeleteBitStream(bs)
end
function main()
sampRegisterChatCommand ("obj", slotApply)
wait (-1)
end