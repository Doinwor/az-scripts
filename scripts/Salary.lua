local inicfg = require 'inicfg'
fontName="Verdana"
tag = "Salary_Menu[231] говорит: {B3AAB8}"
color = 0xF3FAFD
moving = false

-- Lol, доебаться не до чего. Я просто портировал его на мобайл

function chatmsg(text) sampAddChatMessage(tag .. text,color) end

function main()
	while not isSampAvailable() do wait(100) end
	repeat wait(0) until sampIsLocalPlayerSpawned()
		sampRegisterChatCommand("m",functionMonth)
		sampRegisterChatCommand("addmoney",addMoney)
		sampRegisterChatCommand("salary",salaryCmd)
		
		date = tonumber(os.date("%d") .. os.date("%m") .. os.date("%y"))
		dayEst = tonumber(os.date("%d")) - 1
		
		dateEst = formatDate(dayEst)
		directIni="moonloader\\salary.ini"
		mainIni=inicfg.load(nil,directIni)
		checkingIni()
		
		textFont = renderCreateFont(fontName,mainIni.settings.fontsize / 2,5)
		salaryFont = renderCreateFont(fontName,mainIni.settings.fontsize,5)
		
		salary=mainIni[date].salary
		salaryEst=mainIni[dateEst].salary
		
		chatmsg("Я запустился")
		
		balancePlayer = getPlayerMoney(PLAYER_HANDLE)
		dtextWeek = countWeekSalary()
		dtextAll = tableSalary()
	while true do
		if moving then
			movingTable()
          end
		if sampIsLocalPlayerSpawned() then  
			if balancePlayer ~= getPlayerMoney(PLAYER_HANDLE) then
			countingSalary()
			end
			dialogObrabotka()
			tableMoney()
		end

	wait(0)
	end
end

function movingTable()

                sampToggleCursor(true)
                local x, y = getCursorPos()
                mainIni.settings.x = x
                mainIni.settings.y = y
                if isKeyJustPressed(0x02) then
                    moving = false
                    sampToggleCursor(false)
                    inicfg.save(mainIni,directIni)
                end

end

function countingSalary()


				if balancePlayer < getPlayerMoney(PLAYER_HANDLE) then 
					diffBalance = math.abs(balancePlayer - getPlayerMoney(PLAYER_HANDLE))
					salary = salary + diffBalance
					mainIni[date].salary=salary
					inicfg.save(mainIni,directIni)
					balancePlayer = getPlayerMoney(PLAYER_HANDLE)
				elseif balancePlayer > getPlayerMoney(PLAYER_HANDLE) then
					diffBalance = -balancePlayer + getPlayerMoney(PLAYER_HANDLE)
					salary = salary + diffBalance
					mainIni[date].salary=salary
					inicfg.save(mainIni,directIni)
					chatmsg(sep(diffBalance) .. "$",3)
					balancePlayer = getPlayerMoney(PLAYER_HANDLE)
				end


end

function sep(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1.'):reverse())..right
end
function sepDate(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d)','%1.'):reverse())..right
end

function tableMoney()
						renderDrawBox(mainIni.settings.x, mainIni.settings.y - mainIni.settings.fontsize, mainIni.settings.fontsize * 12, mainIni.settings.fontsize * 6, 0xAAC0D5FE)
						renderFontDrawText(textFont, "Заработок за сегодня", mainIni.settings.x + mainIni.settings.fontsize/1.2, mainIni.settings.y - mainIni.settings.fontsize/1.3, 0xFFFFFFFF)
						-- рисуем цифры под текстом
						if salary > 0 then 
						renderFontDrawText(salaryFont, "+".. sep(salary) .. "$", mainIni.settings.x+ mainIni.settings.fontsize/1.2, mainIni.settings.y + mainIni.settings.fontsize/4, 0xFF1BC500)
						elseif salary < 0 then 
						renderFontDrawText(salaryFont, sep(salary) .. "$", mainIni.settings.x+ mainIni.settings.fontsize/1.2, mainIni.settings.y +mainIni.settings.fontsize/4, 0xFFf55442)
						else 
						renderFontDrawText(salaryFont, sep(salary) .. "$", mainIni.settings.x+ mainIni.settings.fontsize/1.2, mainIni.settings.y +mainIni.settings.fontsize/4, 0xFFc2c2c2)
						end	
						-- Вчера
						renderFontDrawText(textFont, "Заработок за вчера", mainIni.settings.x+ mainIni.settings.fontsize/1.2, mainIni.settings.y + mainIni.settings.fontsize*2, 0xFFFFFFFF)
						if salaryEst > 0 then 
						renderFontDrawText(salaryFont, "+".. sep(salaryEst) .. "$", mainIni.settings.x+ mainIni.settings.fontsize/1.2, mainIni.settings.y  + mainIni.settings.fontsize*3, 0xFF1BC500)
						elseif salaryEst < 0 then 
						renderFontDrawText(salaryFont, sep(salaryEst) .. "$", mainIni.settings.x+ mainIni.settings.fontsize/1.2, mainIni.settings.y + mainIni.settings.fontsize * 3, 0xFFf55442)
						else 
						renderFontDrawText(salaryFont, sep(salaryEst) .. "$", mainIni.settings.x+ mainIni.settings.fontsize/1.2, mainIni.settings.y +mainIni.settings.fontsize * 3, 0xFFc2c2c2)
						end	

end

function addMoney(arg)
	givePlayerMoney(Player,arg)
end

function checkingIni()

	if mainIni == nil then
	mainIni={[date]={salary=0}}
	end
	
	if mainIni[date]==nil then
	mainIni[date]={}
	mainIni[date].salary=0
	end
	
	if mainIni[dateEst]==nil then
	mainIni[dateEst]={}
	mainIni[dateEst].salary=0
	end
	
	if mainIni.settings == nil then
	mainIni.settings = {}
	mainIni.settings.notf=false
	mainIni.settings.x=0
	mainIni.settings.y=0
	mainIni.settings.fontsize=20
	end
	
	inicfg.save(mainIni,directIni)
end

function formatDate(arg) 

	local day = arg
	local month = tonumber(os.date("%m"))
	local year = tonumber(os.date("%y"))
	if day == 0 then 
		month = tonumber(os.date("%m")) - 1
		if month == 0 then 
		year = tonumber(os.date("%y")) - 1
		month = 12
		end
		if month == 01 or month == 03 or month == 05 or month == 07 or month == 08 or month == 10 or month == 12 then 
		day = 31 
		elseif month == 02 then 
		day = 28
		elseif month == 04 or month == 06 or month == 09 or month == 11 then 
		day = 30 
		end

		oldDate = day .. month .. year
	end
	if month == 1 or month == 2 or month == 3 or month == 4 or month == 5 or month == 6 or month == 7 or month == 8 or month == 9 then
	oldDate = day .. "0" .. month .. year
	else 
	oldDate = day .. month .. year
	end
	return tonumber(oldDate)
end

function tableSalary()
	countTableSalary = 0
	booli = true
	count = -1
	local dtext = ""
	forlastday1 = tonumber(os.date("%d"))
	for i = 1,14 do
		forlastday = formatDate(forlastday1)
		if mainIni[forlastday] ~= nil then
			salaryDati = mainIni[forlastday].salary
			if salaryDati > 0 then 
			dtext = dtext .. sepDate(forlastday) .. "\t" .. "{1BC500}+" .. sep(salaryDati).. "$" .. "\n"
			elseif salaryDati < 0 then
			dtext = dtext .. sepDate(forlastday) .. "\t" .. "{f55442}" .. sep(salaryDati).. "$" .. "\n"
			else 
			dtext = dtext .. sepDate(forlastday) .. "\t " .. sep(salaryDati) .. "$ \n" 
			end
		
		
		else dtext = dtext .. sepDate(forlastday) .. "\t 0$ \n" end					
		forlastday1 = forlastday1 - 1
	end
	return dtext
end



function dialogObrabotka()
		while sampIsDialogActive(111) do wait(0) end
		local result, button, list, input = sampHasDialogRespond(111)
		if result and button == 0 then
		salaryCmd()
		end
		while sampIsDialogActive(121) do wait(0) end
		local result, button, list, input = sampHasDialogRespond(121)
		if result and button == 0 then
		salaryCmd()
		end
		while sampIsDialogActive(101) do wait(0) end
        local result, button, list, input = sampHasDialogRespond(101)
        if result and button == 1 then
            if list == 0 then	
			sampShowDialog(111, "{1BC500}Доход {f55442}последние 14 дней", tableSalary(), "OK", "Отмена", 4)
		  end
		  if list == 1 then 
			sampShowDialog(121, "{1BC500}Недельный {f55442}доход", countWeekSalary(), "OK", "Отмена", 4)
		  end
		    if list == 3 then
                sampShowDialog(111, "{1BC500}Salary {f55442}Menu", "{FFFFFF}Введите новое значение шрифта:", "OK", "Отмена", 1)
                while sampIsDialogActive(111) do wait(0) end
                local result, button, list, input = sampHasDialogRespond(111)
                if result then
                    if tonumber(input) then
                        mainIni.settings.fontsize = tonumber(input)
                        textFont = renderCreateFont(fontName,mainIni.settings.fontsize / 2,5)
				    salaryFont = renderCreateFont(fontName,mainIni.settings.fontsize,5)
                        inicfg.save(mainIni, directIni)
                        return true
                    else
                        chatmsg("Значение должно быть числом!")
                        return true
                    end
                else
                    return true
                end
            end
		  if list == 4 then
                moving = true
			 chatmsg("Нажмите ПКМ для сохранения положения.")
            end
	end
end


function countWeekSalary()
	local date = os.date("%d") .. os.date("%m") .. os.date("%y")
	date = tonumber(date)
	local dayWeek = tonumber(os.date("%w"))
	dayInWeek  = tonumber(os.date("%d"))
	local dtext = ""
	if dayWeek == 0 then 
	dayWeek = 7 
	end
	
	salaryWeek = 0
	
	for i = 1,dayWeek do 
		t = {"Понедельник ","Вторник ","Среда ","Четверг ","Пятница ","Суббота ","Воскресенье "}
		n = dayWeek + 1
		dateDayInWeek = formatDate(dayInWeek)
		if mainIni[dateDayInWeek] ~= nil then
		salaryDayInWeek = mainIni[dateDayInWeek].salary
		salaryWeek = salaryWeek + salaryDayInWeek
			if salaryDayInWeek > 0 then 
				dtext = dtext .. t[n - i] .. sepDate(dateDayInWeek) .. "\t" .. "{1BC500}+" .. sep(salaryDayInWeek).. "$" .. "\n" 
				elseif salaryDayInWeek < 0 then
				dtext = dtext .. t[n - i] .. sepDate(dateDayInWeek) .. "\t" .. "{f55442}" .. sep(salaryDayInWeek).. "$" .. "\n" 
				else 
				dtext = dtext .. t[n - i] .. sepDate(dateDayInWeek) .. "\t" .. sep(salaryDayInWeek) .. "$" .. "\n" 					
			end
		else 
		dtext = dtext .. t[n - i] .. sepDate(dateDayInWeek) .. "\t" .. "0$" .. "\n" 		
		end

	dayInWeek = dayInWeek - 1 
	end
		return dtext
end

function salaryCmd()
	local dtextTable = ""
	if salaryWeek > 0 then 
		dtextTable = "Доход за последние 14 дней\t\n" .. "Доход за неделю\t" .. "{1BC500}+" .. sep(salaryWeek) .. "$\n" .. "Доход за месяц\t{DC143C}В разработке\n" .. "  \n" .. "Уведомления\t" .. (mainIni.settings.notf and "{45d900}ON\n" or "{ff0000}OFF\n") .. "Размер шрифта\t" .. mainIni.settings.fontsize .. "\n" .. "Изменить положение\t|||||\n"
	elseif salaryWeek < 0 then
	dtextTable = "Доход за последние 14 дней\t\n" .. "Доход за неделю\t" .. "{f55442}" .. sep(salaryWeek).. "$\n" .."  \n\t" .. "Размер шрифта\t" .. mainIni.settings.fontsize .. "\n" .. "Изменить положение\t|||||\n"
	else 
	dtextTable = "Доход за последние 14 дней\t\n" ..
	"Доход за неделю\t" .. sep(salaryWeek).. "$\n" ..
	"Доход за месяц\t{DC143C}В разработке\n" ..
	"  \n" .. 
	"Уведомления\t" .. (mainIni.settings.notf and "{45d900}ON\n" or "{ff0000}OFF\n") .. 
	"Размер шрифта\t" .. mainIni.settings.fontsize .. "\n" .. 
	"Изменить положение\t|||||\n"
	end
	sampShowDialog(101, "{1BC500}Salary {f55442}Menu", dtextTable, "OK", "Отмена", 4)

end

function testing()

	sampAddChatMessage(tostring(mainIni),-1)

end
