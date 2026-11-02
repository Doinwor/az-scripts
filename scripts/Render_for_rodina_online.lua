script_name("Render | Rodina Mobile")
script_author("Theopka")

local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local inicfg = require 'inicfg'
local directIni = 'Render | Rodina.ini'
local ini = inicfg.load({
    render = {
        ruda = false,
        len = false,
        xlopok = false,
        fontsize = (15)
    }
}, directIni)
inicfg.save(ini, directIni)

local fontsize = ini.render.fontsize
local font = renderCreateFont('Arial', fontsize, 26)

local ruda1 = {
	[854] = 'Руда',
}
local  len1 = {
    [865] = 'Лён',
}
local  xlopok1 = {
    [819] = 'Хлопок',
}

function main()
    sampRegisterChatCommand('rrud', function() ini.render.ruda =  not ini.render.ruda end)
    sampRegisterChatCommand('rlen', function() ini.render.len = not ini.render.len end)
    sampRegisterChatCommand('rxlo', function() ini.render.xlopok = not ini.render.xlopok end)
    while true do wait(0)
        if ini.render.ruda then
            for _, obj_hand in pairs(getAllObjects()) do
                local modelid = getObjectModel(obj_hand)
                local _obj = ruda1[modelid]
                if _obj then
                    if isObjectOnScreen(obj_hand) then
                        local x,y,z = getCharCoordinates(PLAYER_PED)
                        local res,x1,y1,z1 = getObjectCoordinates(obj_hand)
                        if res then
                            local dist = math.floor(getDistanceBetweenCoords3d(x,y,z,x1,y1,z1))
                            local c1,c2 = convert3DCoordsToScreen(x,y,z)
                            local o1,o2 = convert3DCoordsToScreen(x1,y1,z1)
                            local text = '{87CEEB}'.._obj..'\n{87CEEB}DIST: '..dist..'m.'
                            renderDrawLine(c1,c2,o1,o2,1, 0xB8B8FCFF)
                            renderFontDrawText(font,text,o1,o2,-1)
                        end
                    end
                end
            end
        end
        if ini.render.len then
            for _, obj_hand in pairs(getAllObjects()) do
                local modelid = getObjectModel(obj_hand)
                local _obj = len1[modelid]
                if _obj then
                    if isObjectOnScreen(obj_hand) then
                        local x,y,z = getCharCoordinates(PLAYER_PED)
                        local res,x1,y1,z1 = getObjectCoordinates(obj_hand)
                        if res then
                            local dist = math.floor(getDistanceBetweenCoords3d(x,y,z,x1,y1,z1))
                            local c1,c2 = convert3DCoordsToScreen(x,y,z)
                            local o1,o2 = convert3DCoordsToScreen(x1,y1,z1)
                            local text = '{87CEEB}'.._obj..'\n{87CEEB}DIST: '..dist..'m.'
                            renderDrawLine(c1,c2,o1,o2,1, 0xB8B8FCFF)
                            renderFontDrawText(font,text,o1,o2,-1)
                        end
                    end
                end
            end
        end
        if ini.render.xlopok then
            for _, obj_hand in pairs(getAllObjects()) do
                local modelid = getObjectModel(obj_hand)
                local _obj = xlopok1[modelid]
                if _obj then
                    if isObjectOnScreen(obj_hand) then
                        local x,y,z = getCharCoordinates(PLAYER_PED)
                        local res,x1,y1,z1 = getObjectCoordinates(obj_hand)
                        if res then
                            local dist = math.floor(getDistanceBetweenCoords3d(x,y,z,x1,y1,z1))
                            local c1,c2 = convert3DCoordsToScreen(x,y,z)
                            local o1,o2 = convert3DCoordsToScreen(x1,y1,z1)
                            local text = '{87CEEB}'.._obj..'\n{87CEEB}DIST: '..dist..'m.'
                            renderDrawLine(c1,c2,o1,o2,1, 0xB8B8FCFF)
                            renderFontDrawText(font,text,o1,o2,-1)
                        end
                    end
                end
            end
        end
    end
end