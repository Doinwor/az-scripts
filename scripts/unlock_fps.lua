script_name("AZ Scripts Test - FPS")
script_author("Твой Ник")

function main()
    -- Ждем загрузки игры
    while not isSampAvailable() do wait(100) end
    
    -- Выводим сообщение в чат
    sampAddChatMessage("{6a5acd}[AZ Scripts] {ffffff}Скрипт [x32] Unlock 60+ fps успешно загружен!", -1)
    sampAddChatMessage("{6a5acd}[AZ Scripts] {ffffff}Установка через приложение работает отлично!", -1)
    
    -- Скрипт продолжает работать в фоне
    while true do
        wait(0)
    end
end