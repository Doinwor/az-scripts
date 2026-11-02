local socket_http = require("socket.http")
local ltn12       = require("ltn12")

local dependencies = {
    {
        folder   = "lib/android",
        files    = { "jni-raw.lua", "jnienv.lua", "jnienv-util.lua" },
        base_url = "https://raw.githubusercontent.com/SADISTCORE/samp-browser-lib/refs/heads/main/android/"
    },
    {
        folder   = "lib/webviews",
        files    = { "init.lua", "WebViews.jar" },
        base_url = "https://raw.githubusercontent.com/SADISTCORE/samp-browser-lib/refs/heads/main/webviews/"
    }
}

local function ensureDependencies()
    if not doesDirectoryExist("lib") then
        createDirectory("lib")
    end
    for _, dep in ipairs(dependencies) do
        if not doesDirectoryExist(dep.folder) then
            createDirectory(dep.folder)
        end
        for _, fname in ipairs(dep.files) do
            local path = dep.folder .. "/" .. fname
            if not doesFileExist(path) then
                local body = {}
                local res, code = socket_http.request{
                    url  = dep.base_url .. fname,
                    sink = ltn12.sink.table(body),
                }
                if res and code == 200 then
                    local f = io.open(path, "wb")
                    f:write(table.concat(body))
                    f:close()
                else
                    sampAddChatMessage("Ошибка скачивания " .. fname, 0xFF5555AA)
                end
            end
        end
    end
end

if not doesFileExist("lib/webviews/init.lua") then
    ensureDependencies()
    sampAddChatMessage("Зависимости загружены, перезагружаюсь...", 0xFF00FF00)
    thisScript():reload()
    return
end

local ffi      = require("ffi")
local lib      = require("lib.webviews")
local imgui    = require("mimgui")
local encoding = require("encoding")
local faicons  = require("fAwesome6")

encoding.default = "CP1251"
local u8 = encoding.UTF8

local profileDir = getWorkingDirectory() .. "/browser_profile"
if not doesDirectoryExist(profileDir) then
    createDirectory(profileDir)
end

local browserID = 1
local browserConfig = {
    visible  = imgui.new.bool(false),
    url      = "https://www.google.com",
    initDone = false,
    lastPos  = { x = 0, y = 0 },
    lastSize = { x = 0, y = 0 }
}

local urlBuf = imgui.new.char[512](browserConfig.url)

imgui.OnInitialize(function()
    local io, style = imgui.GetIO(), imgui.GetStyle()
    io.IniFilename = nil
    style.WindowRounding    = 8
    style.FrameRounding     = 6
    style.ScrollbarRounding = 6
    style.GrabRounding      = 6
    style.WindowPadding     = imgui.ImVec2(12,12)
    style.FramePadding      = imgui.ImVec2(6,4)
    style.ItemSpacing       = imgui.ImVec2(6,6)
    style.Colors[imgui.Col.WindowBg]       = imgui.ImVec4(0.12,0.12,0.15,0.95)
    style.Colors[imgui.Col.TitleBg]        = imgui.ImVec4(0.09,0.09,0.12,1.00)
    style.Colors[imgui.Col.TitleBgActive]  = imgui.ImVec4(0.15,0.15,0.20,1.00)
    style.Colors[imgui.Col.Button]         = imgui.ImVec4(0.18,0.18,0.25,1.00)
    style.Colors[imgui.Col.ButtonHovered]  = imgui.ImVec4(0.25,0.25,0.35,1.00)
    style.Colors[imgui.Col.FrameBg]        = imgui.ImVec4(0.15,0.15,0.20,1.00)
    local cfg = imgui.ImFontConfig()
    cfg.MergeMode  = true
    cfg.PixelSnapH = true
    local ranges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    io.Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85("solid"), 14, cfg, ranges)
    io.Fonts:Build()
end)

local function initializeBrowser(x, y, w, h)
    if not browserConfig.initDone then
        lib.setSetting(browserID, "userDataPath", profileDir)
        lib.createBrowser(browserID, browserConfig.url)
        browserConfig.initDone = true
    end
    if x ~= browserConfig.lastPos.x or y ~= browserConfig.lastPos.y or w ~= browserConfig.lastSize.x or h ~= browserConfig.lastSize.y then
        lib.setPos(browserID, x, y)
        lib.setSize(browserID, w, h)
        browserConfig.lastPos.x, browserConfig.lastPos.y = x, y
        browserConfig.lastSize.x, browserConfig.lastSize.y = w, h
    end
    lib.setClickable(browserID, true)
    lib.setSetting(browserID, "setJavaScriptEnabled", true)
    lib.setVisible(browserID, browserConfig.visible[0])
end

imgui.OnFrame(function() return browserConfig.visible[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(800,600), imgui.Cond.FirstUseEver)
    imgui.Begin(u8"Браузер", browserConfig.visible)
    imgui.PushItemWidth(-1)
    local hint = faicons("magnifying-glass") .. " Введите URL"
    if imgui.InputTextWithHint("##url", hint, urlBuf, imgui.InputTextFlags.EnterReturnsTrue) then
        local newUrl = ffi.string(urlBuf)
        if not newUrl:find("^https?://") then
            newUrl = "https://" .. newUrl
        end
        browserConfig.url = newUrl
        urlBuf = imgui.new.char[512](newUrl)
        lib.changeUrl(browserID, newUrl)
    end
    imgui.PopItemWidth()
    imgui.Separator()
    imgui.Columns(2, "cols", false)
    imgui.SetColumnWidth(0, 50)
    if imgui.Button(faicons("left"), imgui.ImVec2(40,40)) and lib.canGoBack(browserID) then
        lib.goBack(browserID)
    end
    if imgui.Button(faicons("right"), imgui.ImVec2(40,40)) and lib.canGoForward(browserID) then
        lib.goForward(browserID)
    end
    if imgui.Button(faicons("rotate"), imgui.ImVec2(40,40)) then
        lib.changeUrl(browserID, browserConfig.url)
    end
    if imgui.Button(faicons("xmark"), imgui.ImVec2(40,40)) then
        browserConfig.visible[0] = false
        lib.setVisible(browserID, false)
    end
    imgui.NextColumn()
    do
        local avail = imgui.GetContentRegionAvail()
        imgui.BeginChild("view", avail, false, imgui.WindowFlags.NoScrollWithMouse)
        local pos, size = imgui.GetWindowPos(), imgui.GetWindowSize()
        initializeBrowser(pos.x, pos.y, size.x, size.y)
        imgui.EndChild()
    end
    imgui.End()
end)

imgui.OnFrame(function() return true end, function()
    local io = imgui.GetIO()
    local margin, btnSize = 10, 50
    local x = io.DisplaySize.x - btnSize - margin
    local y = (io.DisplaySize.y - btnSize) * 0.5
    imgui.SetNextWindowPos(imgui.ImVec2(x, y), imgui.Cond.Always)
    imgui.Begin("Launcher", imgui.new.bool(true),
                imgui.WindowFlags.NoDecoration + imgui.WindowFlags.NoBackground + imgui.WindowFlags.NoMove)
    if imgui.Button(faicons("globe"), imgui.ImVec2(btnSize, btnSize)) then
        browserConfig.visible[0] = not browserConfig.visible[0]
        if not browserConfig.visible[0] then
            lib.setVisible(browserID, false)
        end
    end
    imgui.End()
end)

function lib.onAction(data)
    if data.type == "WV_LOADED" then
        browserConfig.url = data.msg
        urlBuf = imgui.new.char[512](data.msg)
    elseif data.type == "WV_CLOSE" then
        browserConfig.visible[0] = false
        lib.setVisible(browserID, false)
    end
end

local function init()
    if lib.getVersion() and imgui and faicons then
        initializeBrowser(0,0,0,0)
        lib.setVisible(browserID, false)
    else
        sampAddChatMessage("Ошибка загрузки!", 0xFF5555AA)
    end
end

init()
