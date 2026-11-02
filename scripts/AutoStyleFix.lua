script_name('AutoStyle')
script_author('Theopka')

local sampev = require('lib.samp.events')
local active = false

function sampev.onShowDialog(did, style, title, button1, button2, text)
    if active then
        if string.find(title, '\xcc\xe5\xed\xfe \xf2\xf0\xe0\xed\xf1\xef\xee\xf0\xf2\xe0') then
            if string.find(text, 'COMFORT') then
                sampSendDialogResponse(did, 1, 0, 0)
            elseif string.find(text, 'SPORT') then
                sampSendDialogResponse(did, 0, -1, '')
                active = false
            end
            return false
        end
    end
end

function sampev.onServerMessage(color, text)
    -- Личное авто
    if text:find('\xdd\xf2\xee\xf2 \xf2\xf0\xe0\xed\xf1\xef\xee\xf0\xf2 \xe7\xe0\xf0\xe5\xe3\xe8\xf1\xf2\xf0\xe8\xf0\xee\xe2\xe0\xed \xed\xe0 \xe6\xe8\xf2\xe5\xeb\xff') then
        active = true
        sampSendChat('/style')
    end
    -- Арендное авто
    if text:find('\xc0\xf0\xe5\xed\xe4\xe0 \xfd\xf2\xee\xe3\xee \xf2\xf0\xe0\xed\xf1\xef\xee\xf0\xf2\xe0 \xe7\xe0\xe2\xe5\xf0\xf8\xe8\xf2\xf1\xff \xf7\xe5\xf0\xe5\xe7') then
        active = true
        sampSendChat('/style')
    end
    -- Семейное авто (взял сам или уже сидишь)
    if text:find('\xdd\xf2\xee\xf2 \xf2\xf0\xe0\xed\xf1\xef\xee\xf0\xf2 \xef\xf0\xe8\xed\xe0\xe4\xeb\xe5\xe6\xe8\xf2 \xf1\xe5\xec\xfc\xe5') then
        active = true
        lua_thread.create(function()
            wait(500)
            sampSendChat('/style')
        end)
    end
    -- Ошибка - нет модов
    if text:find('\xc8\xe7\xec\xe5\xed\xe8\xf2\xfc \xf1\xf2\xe8\xeb\xfc \xe5\xe7\xe4\xfb \xec\xee\xe6\xed\xee \xf2\xee\xeb\xfc\xea\xee') then
        active = false
    end
end

function main()
    if not isSampAvailable() then return end
    
    while true do
        wait(0)
    end
end
