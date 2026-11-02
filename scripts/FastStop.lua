script_name('FastStop')
script_author('TG - @waymlock')
script_description('Fast braking without flip. /flipping toggles flip mode.')

local samem = require 'SAMemory'
samem.require 'CPed'

-- Подключаем библиотеку widgets так же как MikuProjectReborn
local widgets = require 'widgets'

local settings = {
    car = {
        fastbrake = true
    }
}

local flipMode = false
local loaded = false

function main()
    while not isSampAvailable() do wait(0) end
    
    if not loaded then
        sampAddChatMessage("{00FF00}[FastStop] {FFFFFF}Loaded! Author: TG - @waymlock", -1)
        sampAddChatMessage("{FFFF00}/flipping {FFFFFF}- toggle flip mode", -1)
        loaded = true
    end
    
    sampRegisterChatCommand('flipping', function()
        flipMode = not flipMode
        printStringNow(flipMode and "~g~Flip Mode ~w~ON" or "~r~Flip Mode ~w~OFF", 3000)
    end)
    
    while true do
        wait(0)
        
        if settings.car.fastbrake then
            if isCharInAnyCar(PLAYER_PED) then
                if isWidgetPressed(WIDGET_HORN) then
                    local car = storeCarCharIsInNoSave(PLAYER_PED)
                    
                    if flipMode then
                        local posX, posY, posZ = getCarCoordinates(car)
                        setCarCoordinates(car, posX, posY, posZ)
                    else
                        setCarForwardSpeed(car, 0.0)
                    end
                end
            end
        end
    end
end