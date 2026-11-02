script_name("ULTRA SUPER SUPER AUTO PIAR")
script_description('ULTRA SUPER SUPER AUTO PIAR')
script_author("@Sashe4ka_ReZoN @MTG MODS")
script_version(1)

local encoding = require("encoding")
encoding.default = "CP1251"
local u8 = encoding.UTF8

local path = getWorkingDirectory():gsub('\\','/') .. "/settings/auto_piar.json"
local settings = {
    enable = false,
    message = "/vr Инвайчу в топ фулл фаму, звоните",
    delay = 180
}
function load()
    if doesFileExist(path) then
        local file, errstr = io.open(path, 'r')
        if file then
            local contents = file:read('*a')
            file:close()
            if #contents ~= 0 then
                local result, loaded = pcall(decodeJson, contents)
                if result then
                    settings = loaded
                end
            end
        end
    end
end
function save()
    local file, errstr = io.open(path, 'w')
    if file then
        local result, encoded = pcall(encodeJson, settings)
        file:write(result and encoded or "")
        file:close()
    end
end
load()

local mimgui = require("mimgui")
local new = mimgui.new
local WinState = new.bool(false)
local enabled = new.bool(settings.enable)
local delay = new.int(settings.delay)
local input = new.char[256](u8(settings.message or ''))

local active = false

function main()
    while not sampIsLocalPlayerSpawned() do wait(0) end

    sampAddChatMessage("{B44EFF}[AutoPiar] Скрипт успешно загружен. Команда: /piar", -1)

    sampRegisterChatCommand("piar", function ()
        WinState[0] = not WinState[0]
    end)

    while true do
        wait(0)
        if settings.enable then
            active = true
            sampSendChat(settings.message)
            wait(100)
            active = false
            wait(1000 * settings.delay)
        end
    end
end

mimgui.OnInitialize(function()
	mimgui.GetIO().IniFilename = nil
    mimgui.SwitchContext()
    mimgui.GetStyle().Colors[mimgui.Col.WindowBg] = mimgui.ImVec4(0.3, 0, 0.5, 1)
    mimgui.GetStyle().Colors[mimgui.Col.TitleBg] = mimgui.ImVec4(0.4, 0, 0.6, 1)
    mimgui.GetStyle().Colors[mimgui.Col.TitleBgActive] = mimgui.ImVec4(0.5, 0, 0.7, 1)
end)

mimgui.OnFrame(function() 
    return WinState[0] end,
    function (player)
        mimgui.Begin(u8("AutoPiar"), WinState, mimgui.WindowFlags.NoCollapse + mimgui.WindowFlags.AlwaysAutoResize)
        mimgui.Text(u8("Настройки автопиара"))
        mimgui.Separator()
        mimgui.Checkbox(u8((settings.enable and 'включено' or 'отключено')), enabled)
        mimgui.PushItemWidth(300)
        mimgui.InputText(u8("Текст рекламы"), input, 256)
        mimgui.InputInt(u8("Задержка (в секундах)"), delay)
        if mimgui.Button(u8('Сохранить настройки')) then
            settings.delay = delay[0]
            settings.message = u8:decode(require('ffi').string(input))
            settings.enable = enabled[0]
            save()
            sampAddChatMessage("{B44EFF}[AutoPiar] Настройки сохранены!", -1)
        end
        mimgui.End()
    end
)

require("samp.events").onShowDialog  = function(id, style, title, button1, button2, text)
	if text:find('Ваше сообщение является рекламой?') and active then
		sampSendDialogResponse(id, 1, 0, 0)
        active = false
		return false
	end
end