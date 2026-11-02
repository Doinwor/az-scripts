script_author('@daniel2903_pon')

local sampev = require ("samp.events")
local effil = require("effil")
local encoding = require("encoding")
encoding.default = 'CP1251'
u8 = encoding.UTF8

chat_id = '' -- чат ID юзера
token = '' -- токен бота

local updateid -- ID последнего сообщения для того чтобы не было флуда

function threadHandle(runner, url, args, resolve, reject)
    if not resolve or type(resolve) ~= "function" then
        error("The 'resolve' parameter must be a valid function.")
    end

    if not reject or type(reject) ~= "function" then
        error("The 'reject' parameter must be a valid function.")
    end

    local t = runner(url, args)
    if not t then
        reject("Failed to create runner thread")
        return
    end

    local get_result = function()
        local r = t:get(0)
        while not r do
            r = t:get(0)
            wait(0)
        end
        return r
    end

    local status = t:status()
    local r = get_result()
    
    if status == 'completed' then
        local ok, result = r[1], r[2]
        if ok then 
            resolve(result)
        else 
            reject(result)
        end
    elseif status == 'canceled' then
        reject("Operation was canceled.")
    else
        reject("Unexpected error: " .. tostring(status))
    end
    
    t:cancel(0)
end

function requestRunner()
    return effil.thread(function(u, a)
        local https = require 'ssl.https'
        local ok, result = pcall(https.request, u, a)
        if ok then
            return {true, result}
        else
            return {false, result}
        end
    end)
end

function async_http_request(url, args, resolve, reject)
    local runner = requestRunner()
    if not reject then reject = function() end end
    lua_thread.create(function()
        threadHandle(runner, url, args, resolve, reject)
    end)
end

function encodeUrl(str)
    str = str:gsub(' ', '%+')
    str = str:gsub('\n', '%%0A')
    return u8:encode(str, 'CP1251')
end

function sendTelegramNotification(msg) -- функция для отправки сообщения юзеру
    msg = msg:gsub('{......}', '') --тут типо убираем цвет
    msg = encodeUrl(msg) -- ну тут мы закодируем строку
    async_http_request('https://api.telegram.org/bot' .. token .. '/sendMessage?chat_id=' .. chat_id .. '&text='..msg,'', function(result) end) -- а тут уже отправка
end

function get_telegram_updates() -- функция получения сообщений от юзера
    while not updateid do wait(1) end -- ждем пока не узнаем последний ID
    local runner = requestRunner()
    local reject = function() end
    local args = ''
    while true do
        url = 'https://api.telegram.org/bot'..token..'/getUpdates?chat_id='..chat_id..'&offset=-1' -- создаем ссылку
        threadHandle(runner, url, args, processing_telegram_messages, reject)
        wait(0)
    end
end

function getLastUpdate() -- тут мы получаем последний ID сообщения, если же у вас в коде будет настройка токена и chat_id, вызовите эту функцию для того чтоб получить последнее сообщение
    async_http_request('https://api.telegram.org/bot'..token..'/getUpdates?chat_id='..chat_id..'&offset=-1','',function(result)
        if result then
            local proc_table = decodeJson(result)
            if proc_table.ok then
                if #proc_table.result > 0 then
                    local res_table = proc_table.result[1]
                    if res_table then
                        updateid = res_table.update_id
                    end
                else
                    updateid = 1 -- тут зададим значение 1, если таблица будет пустая
                end
            end
        end
    end)
end

function main()
    while not isSampAvailable() do
        wait(0)
    end
    getLastUpdate() -- вызываем функцию получения последнего ID сообщения
    sampRegisterChatCommand('telegram',function() -- тестовая команда
        sampAddChatMessage('[Telegram] Отправляю тестовое сообщение',-1)
        sendTelegramNotification('Тестовое сообщение от '..sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))) -- отправляем сообщение юзеру
    end)
    lua_thread.create(get_telegram_updates) -- создаем нашу функцию получения сообщений от юзера
    while true do
        wait(0)
    end
end

function sampev.onServerMessage(color, text)
	getLastUpdate()
     sendTelegramNotification('[' .. os.date("%x") .. ']  ' .. text)
 	lua_thread.create(get_telegram_updates)
end