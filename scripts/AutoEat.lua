script_name('AutoEat by Theopka')
script_author('Theopka')
script_version('1.1')

local sampev = require('lib.samp.events')

-------------------------- android v0.1 --------------------------

local success, jniUtil = pcall(require, "android.jnienv-util")
local success2, env = pcall(require, "android.jnienv")

-------------------------- json --------------------------

local jsoncfg = require 'jsoncfg'
local cfg = jsoncfg.load({
    main = {
        kd = 120000,
        eat = false,
        activeat = tonumber(25),
        hungry = 0,
        wateriv = 0,
        water = false,
        kdwat = 120000,
    }
}, 'AutoEat.json')

function save()
    jsoncfg.save(cfg, 'AutoEat.json')
end

-------------------------- mimgui --------------------------

local fa = require('Fawesome6_solid')
local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local method = { fa.STROOPWAFEL..u8' Чипсы', fa.FISH..u8' Рыба', fa.BACON..u8' Мясо', fa.BAG_SHOPPING..u8' Мешок с мясом' }
local wathod = { fa.BEER_MUG_EMPTY..u8' Пиво', fa.BOTTLE_WATER..u8' Спрайт' }

local autowat = imgui.new.bool(cfg.main.water)
local waterhod = imgui.new.int(cfg.main.wateriv)
local watw = imgui.new["const char*"][#wathod](wathod)
local kddw_min = imgui.new.int(math.floor(cfg.main.kdwat / 60000))

local autoeat = imgui.new.bool(cfg.main.eat)
local eatmethod = imgui.new.int(cfg.main.hungry)
local eatl = imgui.new["const char*"][#method](method)
local eatp = imgui.new.int(cfg.main.activeat)
local kdd_min = imgui.new.int(math.floor(cfg.main.kd / 60000))

local win = imgui.new.bool()
local mds = MONET_DPI_SCALE

imgui.OnFrame(
    function() return win[0] end,
    function(self)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 550 * mds, 320 * mds
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        if imgui.Begin('Main Window', win, imgui.WindowFlags.NoTitleBar) then
            if imgui.BeginChild('Title##', imgui.ImVec2(0, 45 * mds), true) then
                imgui.SetCursorPos(imgui.ImVec2(0, 12 * mds))
                imgui.CenterText(fa.BOLT..' AutoEat || By Theopka')
                imgui.SameLine()
                imgui.SetCursorPos(imgui.ImVec2(0, 5 * mds))
                imgui.RightText(fa.USER..' Author: Theopka', 15 * mds)
                imgui.RightText(fa.FIRE..' Version: '..thisScript().version, 15 * mds)
                imgui.SameLine()
                imgui.SetCursorPos(imgui.ImVec2(5 * mds, 5 * mds))
                if imgui.Button(fa.XMARK..'', imgui.ImVec2(30 * mds, 30 * mds)) then
                    win[0] = false
                end

                imgui.EndChild()
            end
            if imgui.BeginChild('Main##', imgui.ImVec2(), true) then
                if imgui.Checkbox(fa.BURGER..u8' Включить автоеду', autoeat) then
                    cfg.main.eat = autoeat[0]
                    save()
                end
                if cfg.main.eat then 
                    if imgui.Combo(u8'Выбор способа еды', eatmethod, eatl, #method) then
                        cfg.main.hungry = eatmethod[0]
                        save()
                    end
                    if imgui.SliderInt(u8'При скольки единиц хавать', eatp, 1, 99) then
                        cfg.main.activeat = eatp[0]
                        save()
                    end
                    imgui.Text(u8'Задержка проверки ед голода(в минутах) '..fa.ARROW_DOWN)
                    if imgui.SliderInt(u8'', kdd_min, 1, 30) then
                        cfg.main.kd = min(kdd_min[0])
                        save()
                    end
                end
                imgui.Text('')
                imgui.Separator()
                if imgui.Checkbox(fa.WINE_GLASS..u8' Включить автопитьё', autowat) then
                    cfg.main.water = autowat[0]
                    save()
                end
                if cfg.main.water then
                    if imgui.Combo(u8'Выбор способа питья', waterhod, watw, #wathod) then
                        cfg.main.wateriv = waterhod[0]
                        save()
                    end
                    if imgui.SliderInt(u8'Автопитьё (в минутах)', kddw_min, 1, 15) then
                        cfg.main.kdwat = min(kddw_min[0])
                        save()
                    end
                end
                imgui.EndChild()
            end

            imgui.End()
        end
    end
)

imgui.OnInitialize(function()
    SoftDarkTheme()
    imgui.GetIO().IniFilename = nil
    fa.Init(15 * mds)
end)

function imgui.RightText(text, padding)
    padding = padding or 0
    imgui.SetCursorPosX(imgui.GetWindowSize().x - imgui.CalcTextSize(text).x - padding)
    imgui.Text(text)
end

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(text).x / 2)
    imgui.Text(text)
end


-------------------------- main --------------------------

local findeat = nil

local http = require("socket.http")
local ltn12 = require("ltn12")

function downloadFile(url, path)
    local response = {}
    local _, status_code, _ = http.request{
    url = url,
    method = "GET",
    sink = ltn12.sink.file(io.open(path, "w")),
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0;Win64) AppleWebkit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.82 Safari/537.36",
        },
    }
    if status_code == 200 then
        return true
    else
        return false
    end
end


function main()
    while not isSampAvailable() do wait(0) end

    downloadLibraries()

    sampRegisterChatCommand('aeat', function()
        win[0] = not win[0]
    end)

    while not sampIsLocalPlayerSpawned() do wait(0) end

    msg('Активация: /aeat')
    jniUtil.Toast(u8"AutoEat by Theopka: загружен! Активация: /aeat", jniUtil.ToastFlag.LENGTH_SHORT):show()

    local lastEatTime = 0
    local lastWaterTime = 0

    while true do
        local now = os.time() * 1000  -- миллисекунды

        if cfg.main.eat and now - lastEatTime >= cfg.main.kd then
            lastEatTime = now
            if cfg.main.eat then
                sampSendChat('/satiety')
            end
        end

        if cfg.main.water and now - lastWaterTime >= cfg.main.kdwat then
            lastWaterTime = now
            if cfg.main.water then
                if cfg.main.wateriv == 0 then
                    sampSendChat('/beer')
                elseif cfg.main.wateriv == 1 then
                    sampSendChat('/sprunk')
                end
            end
        end

        wait(100)
    end
end

function downloadLibraries()
    local path = getWorkingDirectory().."/lib/android"

    local allLibsExist = doesFileExist(path.."/jnienv-util.lua")
        and doesFileExist(path.."/jnienv.lua")
        and doesFileExist(path.."/jni-raw.lua")
        and doesFileExist(path.."/arizona.lua")
        and doesFileExist(path.."/jar/arzapi.jar")

    if not doesDirectoryExist(path) or not allLibsExist then
        createDirectory(path)
        createDirectory(path.."/jar")

        downloadFile("https://github.com/MikuImpulse/Miku-Lua-AutoUpdates/raw/refs/heads/main/arizona.lua", path.."/arizona.lua")
        downloadFile("https://github.com/MikuImpulse/Miku-Lua-AutoUpdates/raw/refs/heads/main/jni-raw.lua", path.."/jni-raw.lua")
        downloadFile("https://github.com/MikuImpulse/Miku-Lua-AutoUpdates/raw/refs/heads/main/jnienv-util.lua", path.."/jnienv-util.lua")
        downloadFile("https://github.com/MikuImpulse/Miku-Lua-AutoUpdates/raw/refs/heads/main/jnienv.lua", path.."/jnienv.lua")
        downloadFile("https://github.com/MikuImpulse/Miku-Lua-AutoUpdates/raw/refs/heads/main/arzapi.jar", path.."/jar/arzapi.jar")

        thisScript():reload()
    else
        if jniUtil and type(jniUtil.LooperPrepare) == "function" then
            jniUtil.LooperPrepare()
        else
            sampAddChatMessage("Ошибка: jniUtil.LooperPrepare() не найден", -1)
        end
    end
end

function sampev.onShowDialog(did, style, title, button1, button2, text)
    if string.find(text, 'Пополнить сытость можно в любой закусочной штата') then
        findeat = tonumber(string.match(text, "(%d+)%."))
        sampSendDialogResponse(did, 1, 0, nil)
        if findeat and findeat <= eatp[0] then
            if cfg.main.hungry == 0 then
                sampSendChat('/cheeps')
            elseif cfg.main.hungry == 1 then
                sampSendChat('/jfish')
            elseif cfg.main.hungry == 2 then
                sampSendChat('/jmeat')
            elseif cfg.main.hungry == 3 then
                sampSendChat('/meatbag')
            end
        end
        return false
    end
end

function min(minutes)
    return minutes * 60 * 1000
end


function msg(text)
    sampAddChatMessage('[AutoEat By Theopka]: {FFFFFF}'..text, 0xB36000)
end

----------------------------------------------------

function SoftDarkTheme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
  
    style.WindowPadding = imgui.ImVec2(15, 15)
    style.WindowRounding = 20.0
    style.ChildRounding = 20.0
    style.FramePadding = imgui.ImVec2(8, 7)
    style.FrameRounding = 20.0
    style.ItemSpacing = imgui.ImVec2(8, 8)
    style.ItemInnerSpacing = imgui.ImVec2(10, 6)
    style.IndentSpacing = 25.0
    style.ScrollbarSize = 30.0
    style.ScrollbarRounding = 20.0
    style.GrabMinSize = 10.0
    style.GrabRounding = 6.0
    style.PopupRounding = 20
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    style.Colors[imgui.Col.Text]                   = imgui.ImVec4(0.90, 0.90, 0.93, 1.00)
    style.Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    style.Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.18, 0.20, 0.22, 0.30)
    style.Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.13, 0.13, 0.15, 1.00)
    style.Colors[imgui.Col.Border]                 = imgui.ImVec4(0.30, 0.30, 0.35, 1.00)
    style.Colors[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    style.Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.18, 0.18, 0.20, 1.00)
    style.Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.25, 0.25, 0.28, 1.00)
    style.Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.TitleBg]                = imgui.ImVec4(0.15, 0.15, 0.17, 1.00)
    style.Colors[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.10, 0.10, 0.12, 1.00)
    style.Colors[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.15, 0.15, 0.17, 1.00)
    style.Colors[imgui.Col.MenuBarBg]              = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    style.Colors[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    style.Colors[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.30, 0.30, 0.35, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.50, 0.50, 0.55, 1.00)
    style.Colors[imgui.Col.CheckMark]              = imgui.ImVec4(0.70, 0.70, 0.90, 1.00)
    style.Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.70, 0.70, 0.90, 1.00)
    style.Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.80, 0.80, 0.90, 1.00)
    style.Colors[imgui.Col.Button]                 = imgui.ImVec4(0.18, 0.18, 0.20, 1.00)
    style.Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.60, 0.60, 0.90, 1.00)
    style.Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.60, 0.60, 0.90, 1.00)
    style.Colors[imgui.Col.Header]                 = imgui.ImVec4(0.20, 0.20, 0.23, 1.00)
    style.Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.25, 0.25, 0.28, 1.00)
    style.Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.Separator]              = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.50, 0.50, 0.55, 1.00)
    style.Colors[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.60, 0.60, 0.65, 1.00)
    style.Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(0.20, 0.20, 0.23, 1.00)
    style.Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(0.25, 0.25, 0.28, 1.00)
    style.Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.PlotLines]              = imgui.ImVec4(0.61, 0.61, 0.64, 1.00)
    style.Colors[imgui.Col.PlotLinesHovered]       = imgui.ImVec4(0.70, 0.70, 0.75, 1.00)
    style.Colors[imgui.Col.PlotHistogram]          = imgui.ImVec4(0.61, 0.61, 0.64, 1.00)
    style.Colors[imgui.Col.PlotHistogramHovered]   = imgui.ImVec4(0.70, 0.70, 0.75, 1.00)
    style.Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.10, 0.10, 0.12, 0.80)
    style.Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.18, 0.20, 0.22, 1.00)
    style.Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.60, 0.60, 0.90, 1.00)
    style.Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.28, 0.56, 0.96, 1.00)
end