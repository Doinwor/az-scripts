function main()
    sampRegisterChatCommand('calc', function(arg) 
        if #arg == 0 or not arg:find('%d+') then return sampAddChatMessage('[Калькулятор]: {DE9F00}Ошибка, введите /calc [пример]', 0x08A351) end
        sampAddChatMessage('[Калькулятор]: {DE9F00}'..arg..' = '..assert(load("return " .. arg))(), 0x08A351)
    end)
    wait(-1)
end
function onScriptTerminate(script, quit)
    if script == thisScript() and not quit then 
        sampAddChatMessage('[Калькулятор]: {DE9F00}Произошла ошибка, скрипт перезагружен', 0x08A351) 
        thisScript():reload()
    end
end