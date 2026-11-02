script_name('Weather Changer')
script_version('1.0')
script_author('Eytomik Mavlyanov')

local imgui_ok, imgui   = pcall(require, 'mimgui')
local enc_ok,  encoding = pcall(require, 'encoding')
if enc_ok then encoding.default = 'CP1251' end
local u8 = enc_ok and encoding.UTF8 or setmetatable({}, {__index=function(_,k) return function(s) return s end end})

local function msg(text) sampAddChatMessage(text, -1) end

local function cp(text)
    local result = ''
    for c in text:gmatch('.') do
        local ok, b = pcall(function() return c:byte() end)
        if ok then result = result .. string.char(b) end
    end
    return result
end

-- Spisok pogod
local WEATHERS = {
    {id=0,  name='Solnechno (Extra Sunny)'},
    {id=1,  name='Yasnо (Clear)'},
    {id=2,  name='Oblachno (Cloudy)'},
    {id=3,  name='Dozhdlivо (Rainy)'},
    {id=4,  name='Tuman (Foggy)'},
    {id=8,  name='Groza (Thunderstorm)'},
    {id=9,  name='Vetreno (Windy)'},
    {id=11, name='Peschanaya burya'},
    {id=16, name='Oblachno 2'},
    {id=17, name='Mrachno'},
    {id=18, name='Solnechno 2'},
    {id=19, name='Yarkoe solntse'},
    {id=20, name='Vechniy den'},
}

local currentWeather = 0
local autoWeather = false
local showMenu = imgui_ok and imgui.new.bool(false) or nil
local selectedIdx = 1

local function applyWeather(id)
    local ok = pcall(setWeather, id)
    if not ok then
        pcall(forceWeatherNow, id)
    end
    currentWeather = id
    msg('{87CEEB}[Weather] Pogoda: ' .. id)
end

-- Avto-podderzhka pogody
lua_thread.create(function()
    while true do
        wait(5000)
        if autoWeather then
            pcall(setWeather, currentWeather)
            pcall(forceWeatherNow, currentWeather)
        end
    end
end)

-- IMGUI MENU
if imgui_ok then
    imgui.OnFrame(function() return showMenu[0] end, function()
        local sw, sh = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.Once, imgui.ImVec2(0.5,0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(380, 480), imgui.Cond.Once)
        imgui.PushStyleColor(imgui.Col.WindowBg,      imgui.ImVec4(0.07,0.09,0.12,0.97))
        imgui.PushStyleColor(imgui.Col.TitleBgActive, imgui.ImVec4(0.1,0.4,0.7,1))
        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.12,0.15,0.20,1))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.1,0.4,0.7,0.9))
        imgui.PushStyleColor(imgui.Col.CheckMark,     imgui.ImVec4(0.1,0.6,1.0,1))
        imgui.PushStyleColor(imgui.Col.FrameBg,       imgui.ImVec4(0.10,0.13,0.17,1))
        imgui.PushStyleColor(imgui.Col.Header,        imgui.ImVec4(0.1,0.4,0.7,0.7))
        imgui.PushStyleColor(imgui.Col.HeaderHovered, imgui.ImVec4(0.1,0.5,0.8,0.9))

        local flags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize
        if imgui.Begin(u8"Weather Changer | Eytomik Mavlyanov", showMenu, flags) then

            imgui.SetCursorPosX(70)
            imgui.TextColored(imgui.ImVec4(0.3,0.7,1.0,1), u8"=== SMENA POGODY ===")
            imgui.Separator()
            imgui.Spacing()

            -- Tekushchaya pogoda
            imgui.Text(u8"Tekushchaya pogoda ID: " .. currentWeather)
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            -- Список погод
            imgui.Text(u8"Vyberi pogodu:")
            imgui.Spacing()

            local bW = 340
            local bH = 30

            for i, w in ipairs(WEATHERS) do
                local isActive = currentWeather == w.id
                if isActive then
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.1,0.5,0.2,1))
                end
                local label = (isActive and "[OK] " or "     ") .. w.name .. " (ID:" .. w.id .. ")"
                if imgui.Button(u8(label), imgui.ImVec2(bW, bH)) then
                    applyWeather(w.id)
                    autoWeather = true
                end
                if isActive then
                    imgui.PopStyleColor()
                end
            end

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            -- Auto toggle
            local auto_b = imgui.new.bool(autoWeather)
            if imgui.Checkbox(u8"Auto (derzhat pogodu postoyanno)", auto_b) then
                autoWeather = auto_b[0]
            end
            imgui.Spacing()

            -- Sbros
            if imgui.Button(u8"Sbrosit (serverная погода)", imgui.ImVec2(bW, 35)) then
                autoWeather = false
                pcall(releaseWeather)
                msg('{87CEEB}[Weather] Sbros na servernuyu pogodu')
            end
        end
        imgui.End()
        imgui.PopStyleColor(8)
    end)
end

sampRegisterChatCommand('weather', function()
    if showMenu then
        showMenu[0] = not showMenu[0]
    else
        -- Bez imgui - cherez chat
        msg('{87CEEB}[Weather] Komandy:')
        for _, w in ipairs(WEATHERS) do
            msg('{FFFF00}/setw ' .. w.id .. ' {FFFFFF}- ' .. w.name)
        end
    end
end)

sampRegisterChatCommand('setw', function(arg)
    local id = tonumber(arg)
    if not id then
        msg('{FF4444}/setw ID  (0-21)')
        return
    end
    applyWeather(id)
    autoWeather = true
    msg('{33FF33}[Weather] Pogoda ' .. id .. ' primenena!')
end)

sampRegisterChatCommand('weatherreset', function()
    autoWeather = false
    pcall(releaseWeather)
    msg('{FF4444}[Weather] Sbros!')
end)

lua_thread.create(function()
    wait(3000)
    msg('{87CEEB}[Weather Changer] Zagruzhen!')
    msg('{AAAAAA}/weather - otkryt menyu | /setw ID - pogoda | /weatherreset - sbros')
end)
