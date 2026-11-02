function main()
	while not isSampAvailable() do wait(0) end
		
	while true do
		wait(0)
		cameraSetLerpFov(60.0, 101.0, 1000, true)
	end
end