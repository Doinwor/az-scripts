local BLOCKED = {
	[8] = { [104] = true },
}

function main()
	addEventHandler('onReceivePacket', function(id, bs, ...)
		if id == 220 then
			raknetBitStreamIgnoreBits(bs, 8)
			local packetType = raknetBitStreamReadInt8(bs)

			if packetType == 84 then
				local interfaceid = raknetBitStreamReadInt8(bs)
				local subid = raknetBitStreamReadInt8(bs)

				if BLOCKED[interfaceid] and BLOCKED[interfaceid][subid] then
					return false
				end
			end
		end
	end)
	wait(-1)
end
