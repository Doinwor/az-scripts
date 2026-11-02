script_name("Anti Blocked Player")
script_author("wD.Dl59")
script_url("vk.com/id153724009")

-- РЎРєСЂРёРїС‚ РЅРµ РґР°СЃС‚ Р’Р°Рј Р·Р°СЃС‚СЂСЏС‚СЊ РІ СЃРєРёРЅРµ РґСЂСѓРіРѕРіРѕ РёРіСЂРѕРєР°.

function main()
	if not isSampLoaded() then return end
	while not isSampAvailable() do wait(100) end
	while true do wait(0)
		for i = 0, sampGetMaxPlayerId(false) do
			if sampIsPlayerConnected(i) then
				local result, id = sampGetCharHandleBySampPlayerId(i)
				if result then
					if doesCharExist(id) then
						local x, y, z = getCharCoordinates(id)
						local mX, mY, mZ = getCharCoordinates(playerPed)
						if 0.4 > getDistanceBetweenCoords3d(x, y, z, mX, mY, mZ) then
							setCharCollision(id, false)
						end
					end
				end
			end
        end
	end
end