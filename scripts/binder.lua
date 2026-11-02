script_name("AZ Scripts Test - Binder")
script_author("Твой Ник")

function main()
    while not isSampAvailable() do wait(100) end
    
    sampAddChatMessage("{6a5acd}[AZ Scripts] {ffffff}Скрипт Auto Binder Pro успешно загружен!", -1)
    sampAddChatMessage("{6a5acd}[AZ Scripts] {ffffff}Напиши в чат /binder чтобы проверить его.", -1)

    -- Создаем команду /binder
    sampRegisterChatCommand("binder", function()
        sampAddChatMessage("{6a5acd}[AZ Scripts] {ffffff}Биндер работает! Это тестовый вызов.", -1)
    end)

    while true do
        wait(0)
    end
end