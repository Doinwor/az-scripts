local samp = require 'lib.samp.events'

local mode = 0 -- 0: выключен, 1: режим записи, 2: активен (автовыход)
local saved_title = ""
local saved_listbox_id = -1
local current_title = ""

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("rs", function()
        if mode == 0 or mode == 2 then
            -- Включаем режим записи
            mode = 1
            sampAddChatMessage("[RS] {FFFFFF}Режим настройки включен. Подойдите к метке, нажмите Alt и выберите нужный выход.", 0x00FF00)
        elseif mode == 1 then
            -- Сохраняем и активируем
            if saved_listbox_id ~= -1 and saved_title ~= "" then
                mode = 2
                sampAddChatMessage("[RS] {FFFFFF}Сохранено! Теперь при нажатии Alt у этого выхода вы выйдете автоматически.", 0x00FF00)
            else
                mode = 0
                sampAddChatMessage("[RS] {FF0000}Ошибка: вы ничего не выбрали. Скрипт отключен.", 0x00FF00)
            end
        end
    end)

    wait(-1)
end

-- Функция для очистки текста от HEX-цветов Аризоны (например, {FFFFFF})
function stripColors(text)
    return text:gsub("{%x+}", "")
end

-- Перехватываем появление диалога
function samp.onShowDialog(dialogId, style, title, button1, button2, text)
    local clean_title = stripColors(title)

    -- Если мы в режиме настройки, запоминаем название диалога
    if mode == 1 then
        current_title = clean_title
    end

    -- Если скрипт активен и мы видим нужный диалог — моментально выходим
    if mode == 2 and saved_title ~= "" and clean_title == saved_title then
        lua_thread.create(function()
            wait(50) -- Микро-задержка (50 мс), чтобы античит не ругался на слишком быстрый клик
            sampSendDialogResponse(dialogId, 1, saved_listbox_id, "")
        end)
        return false -- Возвращаем false, чтобы диалог даже не появлялся на экране
    end
end

-- Перехватываем клик пользователя в диалоге
function samp.onSendDialogResponse(dialogId, button, listboxId, input)
    if mode == 1 then
        if button == 1 then -- Если нажали первую кнопку (Выбрать/Ок)
            saved_title = current_title
            saved_listbox_id = listboxId
            sampAddChatMessage("[RS] {FFFFFF}Выбран пункт номер " .. (listboxId + 1) .. ". Введите {FFFF00}/rs{FFFFFF} еще раз для сохранения.", 0x00FF00)
            return false -- Блокируем отправку ответа серверу, чтобы ты реально не вышел во время настройки
        end
    end
end