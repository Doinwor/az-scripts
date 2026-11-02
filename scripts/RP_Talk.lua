require('encoding').default = 'CP1251'
local u8 = require('encoding').UTF8
local inicfg = require('inicfg')
local sampev = require("lib.samp.events")

script_name("RolePlay Talk")
script_author("justskipty")
script_description(u8"С заглавной буквы - /rptalk, с заглавной буквы и с точкой - /rptalkdot")

local cfg_file = "rptalk_config"
local cfg = inicfg.load({
    settings = {
        enabled = false,
        add_dot = false
    }
}, cfg_file)

local russian_characters = {
    [168] = 'Ё', [184] = 'ё', [192] = 'А', [193] = 'Б', [194] = 'В', [195] = 'Г', [196] = 'Д', [197] = 'Е', [198] = 'Ж', [199] = 'З',
    [200] = 'И', [201] = 'Й', [202] = 'К', [203] = 'Л', [204] = 'М', [205] = 'Н', [206] = 'О', [207] = 'П', [208] = 'Р', [209] = 'С',
    [210] = 'Т', [211] = 'У', [212] = 'Ф', [213] = 'Х', [214] = 'Ц', [215] = 'Ч', [216] = 'Ш', [217] = 'Щ', [218] = 'Ъ', [219] = 'Ы',
    [220] = 'Ь', [221] = 'Э', [222] = 'Ю', [223] = 'Я', [224] = 'а', [225] = 'б', [226] = 'в', [227] = 'г', [228] = 'д', [229] = 'е',
    [230] = 'ж', [231] = 'з', [232] = 'и', [233] = 'й', [234] = 'к', [235] = 'л', [236] = 'м', [237] = 'н', [238] = 'о', [239] = 'п',
    [240] = 'р', [241] = 'с', [242] = 'т', [243] = 'у', [244] = 'ф', [245] = 'х', [246] = 'ц', [247] = 'ч', [248] = 'ш', [249] = 'щ',
    [250] = 'ъ', [251] = 'ы', [252] = 'ь', [253] = 'э', [254] = 'ю', [255] = 'я'
}

function main()
    repeat wait(0) until isSampAvailable()

    sampRegisterChatCommand("rptalk", function()
        cfg.settings.enabled = not cfg.settings.enabled
        cfg.settings.add_dot = false
        inicfg.save(cfg, cfg_file)

        if cfg.settings.enabled then
            sampAddChatMessage("[RpTalk] Включён. Сообщения начинаются с заглавной буквы (без точки).", 0x00FF00)
        else
            sampAddChatMessage("[RpTalk] Отключён. RP-режим выключен.", 0xAAAAAA)
        end
    end)

    sampRegisterChatCommand("rptalkdot", function()
        cfg.settings.enabled = not cfg.settings.enabled
        cfg.settings.add_dot = cfg.settings.enabled
        inicfg.save(cfg, cfg_file)

        if cfg.settings.enabled then
            sampAddChatMessage("[RpTalk] Включён. Сообщения начинаются с заглавной буквы и заканчиваются точкой.", 0x00FF00)
        else
            sampAddChatMessage("[RpTalk] Отключён. RP-режим выключен.", 0xAAAAAA)
        end
    end)

    if cfg.settings.enabled then
        if cfg.settings.add_dot then
            sampAddChatMessage("[RpTalk] Активен режим: заглавная + точка.", 0x00FF00)
        else
            sampAddChatMessage("[RpTalk] Активен режим: заглавная без точки.", 0x00FF00)
        end
    else
        sampAddChatMessage("[RpTalk] Скрипт загружен. RP-режим отключён.", 0xAAAAAA)
    end

    wait(-1)
end

function sampev.onSendChat(text)
    if cfg.settings.enabled and text:len() > 0 then
        text = text:sub(1, 1):rupper() .. text:sub(2)
        if cfg.settings.add_dot and not text:find('[%.%!%?]$') then
            text = text .. '.'
        end
        return {text}
    end
end

function string.rupper(s)
    local strlen = s:len()
    if strlen == 0 then return s end
    local output = ''
    for i = 1, strlen do
        local ch = s:byte(i)
        if ch >= 224 and ch <= 255 then
            output = output .. russian_characters[ch - 32]
        elseif ch == 184 then
            output = output .. russian_characters[168]
        else
            output = output .. string.char(ch)
        end
    end
    return output
end