script_name('CaptchaTraining')
script_author('Marcus Devil')

require "lib.moonloader"
require "lib.sampfuncs"

local tag = "{8b00ff}[CAPTCHA TRAINING]:{FFFFFF} "
local font_flag = require('moonloader').font_flag
local fast = 0
local tt = 0
local customcaptchas = 0
local degenerat = 0
local wx, wy = getScreenResolution()
local my_font = renderCreateFont('Verdana', wx / 19, font_flag.BOLD)

function main()
	if not isSampLoaded() or not isSampfuncsLoaded() then return end
	    while not isSampAvailable() do wait(100) end
			sampRegisterChatCommand("captcha", dialog)
			sampRegisterChatCommand("captchafast", faster)
			sampAddChatMessage(tag.."Скрипт активирован! Автор {ff2400}Marcus{8a2be2} Devil{FFFFFF}, специально для канала {ffd700}REVAZZ", 0xFFFFFF)
			while true do
				wait(0)
				local result, button, list, input = sampHasDialogRespond(11217)
			 		if result then
					if button == 0 then dialog() else
						if input:match(customcaptchas) then
							nt = os.clock()
							local kpch = nt - tt
							sampAddChatMessage(tag.."{19ff19}Вы ввели капчу за "..("%.2f"):format(kpch).." секунд!", -1)
							degenerat = 0
							if fast == 1 then dialog() end
						else sampAddChatMessage(tag.."{FF0000}Вы неправильно ввели капчу!", -1) degenerat = 0 if fast == 1 then dialog() end end
					end
					end
			end
end

function txdrw()
	lua_thread.create(function()
		while true do
			wait(0)
			if degenerat == 1 then
		renderDrawBoxWithBorder(wx / 2.65, wy / 3.65, wx / 3.90, wy / 8, 0xFF76A4AB, 7, 0xFF121624)
		renderFontDrawText(my_font, customcaptchas, wx / 1.5, wy / 3.825, 0xFF121624)
	end
	end
	end)
end

function dialog()
	tt = os.clock()
	math.randomseed(os.time())
	customcaptchas = math.random(10000,99999)
	degenerat = 1
	txdrw()
	sampShowDialog(76753, "{8b00ff}Тренировка капчи", "{ffffff}Введите капчу", "Тык", "Тык", 1)
end

function faster()
	if fast == 0 then
		fast = 1
		sampAddChatMessage("Включена быстрая практика!", 0xFF00FF)
	 else
		 fast = 0
		 sampAddChatMessage("Быстрая практика выключена!", 0xFF0000)
	 end
end
