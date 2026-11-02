local url = "https://api.arizona-five.com/launcher/servers"

local sampev = require 'samp.events'

-- защита от спама запросов
local isRequestActive = false

function main()
    while not isSampAvailable() do wait(0) end

    sampRegisterChatCommand('vc', function()
        getVcServer()
    end)

    sampAddChatMessage("{00FFAA}[VC]{FFFFFF} Загружен. Используй /vc", -1)

    while true do wait(0) end
end

-- ================= API =================

function getVcServer()
    if isRequestActive then
        sampAddChatMessage("{FF4444}[VC]{FFFFFF} Подожди...", -1)
        return
    end

    isRequestActive = true

    local requests = require('requests')
    if not requests then
        sampAddChatMessage("{FF4444}[VC]{FFFFFF} Нет requests", -1)
        isRequestActive = false
        return
    end

    lua_thread.create(function()
        local res = requests.get(url)

        if res and res.status_code == 200 then
            local data = res.json()

            if data and data.vc then
                for _, po in pairs(data.vc) do
                    
                    local msg = ('[VC] %s :palm_tree: | Онлайн: %s/%s :u1f465: | Очередь: %s :u23f3:'):format(
                        po.name or "Vice City",
                        po.online or 0,
                        po.maxplayers or 0,
                        po.queue or 0
                    )

                    sampAddChatMessage("{00FFAA}" .. msg, -1)
                end
            else
                sampAddChatMessage("{FF4444}[VC]{FFFFFF} Нет данных", -1)
            end
        else
            sampAddChatMessage("{FF4444}[VC]{FFFFFF} Ошибка API", -1)
        end

        isRequestActive = false
    end)
end