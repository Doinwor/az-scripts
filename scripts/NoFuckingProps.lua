local props = {
	[625] = true, [626] = true, [627] = true, [628] = true, [629] = true, [630] = true, [631] = true,
	[632] = true, [633] = true, [642] = true, [643] = true, [644] = true, [646] = true, [650] = true,
	[716] = true, [717] = true, [733] = true, [737] = true, [738] = true, [765] = true, [781] = true,
	[792] = true, [858] = true, [881] = true, [882] = true, [883] = true, [884] = true, [885] = true,
	[886] = true, [887] = true, [888] = true, [889] = true, [890] = true, [891] = true, [892] = true,
	[893] = true, [894] = true, [895] = true, [904] = true, [905] = true, [926] = true, [928] = true,
	[941] = true, [955] = true, [956] = true, [959] = true, [961] = true, [990] = true, [993] = true,
	[996] = true, [1209] = true, [1211] = true, [1214] = true, [1215] = true, [1216] = true, [1219] = true,
	[1220] = true, [1221] = true, [1223] = true, [1224] = true, [1226] = true, [1227] = true, [1228] = true,
	[1229] = true, [1230] = true, [1231] = true, [1232] = true, [1233] = true, [1235] = true, [1238] = true,
	[1244] = true, [1251] = true, [1255] = true, [1257] = true, [1258] = true, [1264] = true, [1265] = true,
	[1270] = true, [1278] = true, [1280] = true, [1281] = true, [1282] = true, [1283] = true, [1284] = true,
	[1285] = true, [1286] = true, [1287] = true, [1288] = true, [1289] = true, [1290] = true, [1291] = true,
	[1293] = true, [1294] = true, [1295] = true, [1296] = true, [1297] = true, [1298] = true, [1299] = true,
	[1300] = true, [1302] = true, [1315] = true, [1319] = true, [1320] = true, [1321] = true, [1322] = true,
	[1323] = true, [1328] = true, [1329] = true, [1330] = true, [1331] = true, [1332] = true, [1333] = true,
	[1334] = true, [1337] = true, [1338] = true, [1341] = true, [1349] = true, [1350] = true, [1351] = true,
	[1352] = true, [1363] = true, [1370] = true, [1372] = true, [1373] = true, [1374] = true, [1375] = true,
	[1407] = true, [1408] = true, [1409] = true, [1410] = true, [1411] = true, [1412] = true, [1413] = true,
	[1414] = true, [1415] = true, [1418] = true, [1419] = true, [1420] = true, [1421] = true, [1422] = true,
	[1423] = true, [1424] = true, [1425] = true, [1426] = true, [1427] = true, [1428] = true, [1430] = true,
	[1431] = true, [1432] = true, [1434] = true, [1435] = true, [1436] = true, [1437] = true, [1438] = true,
	[1440] = true, [1441] = true, [1443] = true, [1444] = true, [1445] = true, [1446] = true, [1447] = true,
	[1448] = true, [1449] = true, [1450] = true, [1451] = true, [1452] = true, [1456] = true, [1457] = true,
	[1458] = true, [1459] = true, [1460] = true, [1461] = true, [1462] = true, [1463] = true, [1464] = true,
	[1465] = true, [1466] = true, [1467] = true, [1468] = true, [1469] = true, [1470] = true, [1471] = true,
	[1472] = true, [1473] = true, [1474] = true, [1475] = true, [1476] = true, [1477] = true, [1478] = true,
	[1479] = true, [1480] = true, [1481] = true, [1482] = true, [1483] = true, [1534] = true, [1553] = true,
	[1554] = true, [1558] = true, [1568] = true, [1645] = true, [1646] = true, [1647] = true, [1649] = true,
	[1676] = true, [1684] = true, [1686] = true, [1775] = true, [1776] = true, [2885] = true, [2887] = true,
	[2900] = true, [2907] = true, [2918] = true, [2920] = true, [2925] = true, [2932] = true, [2933] = true,
	[2942] = true, [2943] = true, [2945] = true, [2968] = true, [2971] = true, [2977] = true, [2987] = true,
	[2988] = true, [2991] = true, [2994] = true, [3006] = true, [3032] = true, [3036] = true, [3058] = true,
	[3059] = true, [3067] = true, [3083] = true, [3091] = true, [3221] = true, [3260] = true, [3261] = true,
	[3262] = true, [3263] = true, [3264] = true, [3265] = true, [3267] = true, [3275] = true, [3276] = true,
	[3278] = true, [3281] = true, [3282] = true, [3302] = true, [3374] = true, [3379] = true, [3398] = true,
	[3460] = true, [3463] = true, [3516] = true, [3593] = true, [3594] = true, [3666] = true, [3794] = true,
	[3795] = true, [3797] = true, [3851] = true, [3853] = true, [3855] = true, [3864] = true, [3884] = true,
	[11103] = true, [16627] = true, [16628] = true, [16629] = true, [16630] = true, [16631] = true, [16632] = true,
	[16633] = true, [16634] = true, [16635] = true, [16636] = true, [17968] = true, [19868] = true, [19869] = true
}

function getCarDrivenByPlayer(ped)
	if isCharInAnyCar(ped) then
		local car = storeCarCharIsInNoSave(ped)
		return (getDriverOfCar(car) == ped), car
	end
	return false
end

function main()
	while true do
		local isDriver, car = getCarDrivenByPlayer(PLAYER_PED)
		if isDriver and car and doesVehicleExist(car) and getCarSpeed(car) >= 1 then
			for i, object in ipairs(getAllObjects()) do
				local model = getObjectModel(object)
				if props[model] then
					sortOutObjectCollisionWithCar(object, car)
					if isVehicleTouchingObject(car, object) then
						breakObject(object, 0)
						break
					end
				end
			end
		end
		wait(0)
	end
end
