script_author("@T23Vladimir, t.me/sadistded")

local imgui = require "mimgui"
local ffi = require "ffi"
local sampev = require "lib.samp.events"
local encoding = require "encoding"
encoding.default = "CP1251"
local u8 = encoding.UTF8
local new = imgui.new
local ChatLog = {}
local inicfg = require "inicfg"
local settings = 
    inicfg.load(
    {
        head = {
            on = true
        }
    },
    "ChatCopy_LogV2.ini"
)
settings.log = nil
local on_standart = new.bool(settings.head.on)
local WinState = imgui.new.bool()
local findhead = new.char[256]()

local LOG_LIMIT = 5000
local LOG_TRIM_EXTRA = 500
local logDir = getWorkingDirectory() .. "/config"
local logPath = logDir .. "/ChatCopy_LogV2.json"
local logFile = nil
local logLines = 0

pcall(function()
    if not doesDirectoryExist(logDir) then
        createDirectory(logDir)
    end
end)

local function stripColors(s)
    return (s:gsub("{%x%x%x%x%x%x%x?%x?}", ""))
end

local function cleanField(s)
    return (tostring(s):gsub("[\r\n\t]", " "))
end

local function makeLine(now, nick, id, content)
    return now .. "\t" .. cleanField(nick) .. "\t" .. cleanField(id) .. "\t" .. cleanField(content)
end

local function openLogAppend()
    if logFile then pcall(function() logFile:close() end) end
    logFile = io.open(logPath, "ab")
end

local function rewriteLogFile()
    if logFile then pcall(function() logFile:close() end) logFile = nil end
    while #ChatLog > LOG_LIMIT do
        table.remove(ChatLog)
    end
    local f = io.open(logPath, "wb")
    if f then
        for i = #ChatLog, 1, -1 do
            local v = ChatLog[i]
            f:write(makeLine(v[4], v[1], v[2], v[3]), "\n")
        end
        f:close()
    end
    logLines = #ChatLog
    openLogAppend()
end

local function saveLogLine(now, nick, id, content)
    if not logFile then openLogAppend() end
    if logFile then
        logFile:write(makeLine(now, nick, id, content), "\n")
        logFile:flush()
        logLines = logLines + 1
        if logLines > LOG_LIMIT + LOG_TRIM_EXTRA then
            rewriteLogFile()
        end
    end
end

local function clearLogFile()
    if logFile then pcall(function() logFile:close() end) logFile = nil end
    local f = io.open(logPath, "wb")
    if f then f:close() end
    logLines = 0
    openLogAppend()
end

local function loadLog()
    local lines = {}
    local f = io.open(logPath, "rb")
    if f then
        for line in f:lines() do
            lines[#lines + 1] = (line:gsub("\r$", ""))
        end
        f:close()
    end

    local first = math.max(1, #lines - LOG_LIMIT + 1)
    for i = #lines, first, -1 do
        local t, nick, id, content = stripColors(lines[i]):match("^(%d+)\t([^\t]*)\t([^\t]*)\t(.*)$")
        if t then
            local now = tonumber(t)
            ChatLog[#ChatLog + 1] = {nick, id, content, now, string.nlower(nick), string.nlower(content), string.nlower(id), os.date("%X", now)}
        end
    end

    if #ChatLog ~= #lines then
        rewriteLogFile()
    else
        logLines = #lines
        openLogAppend()
    end
end

function onScriptTerminate()
    if logFile then pcall(function() logFile:close() end) end
end

imgui.OnFrame(
    function()
        return WinState[0]
    end,
    function()
        imgui.SetNextWindowPos(imgui.ImVec2(500, 500), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(950, 450), imgui.Cond.FirstUseEver)
        imgui.Begin("Chat Logger", WinState)
            if imgui.Checkbox(u8 "Включить", on_standart) then
                inicfg.save(settings, "ChatCopy_LogV2.ini")
            end
            imgui.Text(u8'Поиск:')
            imgui.InputTextWithHint("", u8'NickName | ID | Часть сообщения', findhead, 256)
            imgui.SameLine()
            if imgui.Button("X##clearsearch") then
                ffi.fill(findhead, 256)
            end
            imgui.SameLine(nil, 60)
            if imgui.Button(u8'Очистить лог') then
                ChatLog = {}
                clearLogFile()
            end
            imgui.Dummy(imgui.ImVec2(0,2))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0,2))
            local searchQuery = string.nlower(u8:decode(ffi.string(findhead)))
            local hasQuery = #searchQuery > 0

            local filtered = ChatLog
            if hasQuery then
                filtered = {}
                for idx = 1, #ChatLog do
                    local v = ChatLog[idx]
                    if v[5]:find(searchQuery, 1, true) or v[6]:find(searchQuery, 1, true) or v[7]:find(searchQuery, 1, true) then
                        filtered[#filtered + 1] = v
                    end
                end
            end

            imgui.BeginChild("##loglist")
            local clipper = imgui.ImGuiListClipper(#filtered)
            while clipper:Step() do
                for row = clipper.DisplayStart + 1, clipper.DisplayEnd do
                    local v = filtered[row]
                    local i = row
                    local playernick, playerid, content, times, timeStr = v[1], v[2], v[3], v[4], v[8]

                    imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1), u8("[" .. timeStr .. "]"))
                    if imgui.IsItemHovered() then
                        imgui.BeginTooltip()
                        imgui.Text(u8(formatTime(os.time() - times)))
                        imgui.EndTooltip()
                    end
                    imgui.SameLine()

                    if imgui.Button(u8"Скопировать##"..i) then
                        local textToCopy = content
                        if playernick ~= "" and playerid ~= "" then
                            textToCopy = playernick .. '[' .. playerid .. ']: ' .. content
                        end
                        local utf8Text = u8:encode(textToCopy)
                        setClipboardText(utf8Text)
                    end
                    imgui.SameLine()

                    if playernick ~= "" and playerid ~= "" then
                        if imgui.NickName(u8(playernick .. "[" .. playerid .. "]:"), nil, i) then
                            imgui.StrCopy(findhead, u8(playernick))
                        end
                        imgui.SameLine()
                    end

                    imgui.Text(u8(content))

                    imgui.Dummy(imgui.ImVec2(0,2))
                    imgui.Separator()
                    imgui.Dummy(imgui.ImVec2(0,2))
                end
            end
            imgui.EndChild()
        imgui.End()
    end
)
 
local ul_rus = {} 
for i = 192, 223 do 
    local A, a = string.char(i), string.char(i + 32) 
    ul_rus[A] = a 
end 
local E, e = string.char(168), string.char(184) 
ul_rus[E] = e 
 
function string.nlower(s) 
    s = string.lower(tostring(s)) 
    local len, res = #s, {} 
    for i = 1, len do 
        local ch = string.sub(s, i, i) 
        res[i] = ul_rus[ch] or ch 
    end 
    return table.concat(res) 
end 
 
function imgui.NickName(label, description, specialid) 
    local size = imgui.CalcTextSize(label) 
    local p = imgui.GetCursorScreenPos() 
    local p2 = imgui.GetCursorPos() 
    local result = imgui.InvisibleButton(label .. "##" .. specialid, size) 
 
    imgui.SetCursorPos(p2) 
 
    if imgui.IsItemHovered() then 
        if description then 
            imgui.BeginTooltip() 
            imgui.PushTextWrapPos(600) 
            imgui.TextUnformatted(description) 
            imgui.PopTextWrapPos() 
            imgui.EndTooltip() 
        end 
 
        imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), label) 
        imgui.GetWindowDrawList():AddLine( 
            imgui.ImVec2(p.x, p.y + size.y), 
            imgui.ImVec2(p.x + size.x, p.y + size.y), 
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.87, 0.18, 0.22, 1.00))
) 
    else 
        imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), label) 
    end 
 
    return result 
end 
 
function formatTime(seconds) 
    local minutes = math.floor(seconds / 60) 
    local remainingSeconds = seconds % 60 
    local hours = math.floor(minutes / 60) 
    local remainingMinutes = minutes % 60 
 
    local formattedTime = "" 
 
    if hours > 0 then 
        formattedTime = formattedTime .. hours .. " час " 
    end 
 
    if remainingMinutes > 0 then 
        formattedTime = formattedTime .. remainingMinutes .. " минут " 
    end 
 
    if remainingSeconds > 0 or formattedTime == "" then 
        formattedTime = formattedTime .. remainingSeconds .. " сек " 
    end 
 
    formattedTime = formattedTime .. "назад" 
 
    return formattedTime 
end 
 
 
function imgui.CrimsonTheme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    style.WindowPadding = imgui.ImVec2(10, 10)
    style.FramePadding = imgui.ImVec2(8, 6)
    style.ItemSpacing = imgui.ImVec2(8, 6)
    style.WindowRounding = 6
    style.FrameRounding = 4
    style.ScrollbarRounding = 6
    style.GrabRounding = 4
    style.TabRounding = 4

    local colors = style.Colors
    local col = imgui.Col
    local crimson = imgui.ImVec4(0.86, 0.08, 0.24, 1.00)
    local dark = imgui.ImVec4(0.09, 0.09, 0.09, 1.00)
    local darker = imgui.ImVec4(0.05, 0.05, 0.05, 1.00)
    local accent = imgui.ImVec4(0.86, 0.08, 0.24, 0.25)

    colors[col.Text] = imgui.ImVec4(0.95, 0.95, 0.95, 1.00)
    colors[col.WindowBg] = darker
    colors[col.ChildBg] = dark
    colors[col.PopupBg] = darker
    colors[col.Border] = imgui.ImVec4(0.15, 0.15, 0.15, 1.00)
    colors[col.FrameBg] = dark
    colors[col.FrameBgHovered] = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    colors[col.FrameBgActive] = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    colors[col.TitleBg] = dark
    colors[col.TitleBgActive] = crimson
    colors[col.CheckMark] = crimson
    colors[col.SliderGrab] = crimson
    colors[col.SliderGrabActive] = imgui.ImVec4(0.92, 0.18, 0.29, 1.00)
    colors[col.Button] = imgui.ImVec4(0.86, 0.08, 0.24, 0.40)
    colors[col.ButtonHovered] = imgui.ImVec4(0.86, 0.08, 0.24, 0.60)
    colors[col.ButtonActive] = imgui.ImVec4(0.86, 0.08, 0.24, 0.80)
    colors[col.Header] = crimson
    colors[col.HeaderHovered] = imgui.ImVec4(0.92, 0.18, 0.29, 1.00)
    colors[col.HeaderActive] = imgui.ImVec4(0.86, 0.08, 0.24, 1.00)
    colors[col.Separator] = imgui.ImVec4(0.15, 0.15, 0.15, 1.00)
    colors[col.ResizeGrip] = imgui.ImVec4(0.86, 0.08, 0.24, 0.25)
    colors[col.ResizeGripHovered] = imgui.ImVec4(0.86, 0.08, 0.24, 0.67)
    colors[col.ResizeGripActive] = imgui.ImVec4(0.86, 0.08, 0.24, 0.95)
    colors[col.Tab] = dark
    colors[col.TabHovered] = imgui.ImVec4(0.86, 0.08, 0.24, 0.60)
    colors[col.TabActive] = crimson
    colors[col.TextSelectedBg] = imgui.ImVec4(0.86, 0.08, 0.24, 0.35)
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.CrimsonTheme()
end)

 
function sampev.onServerMessage(color, text)
    if on_standart[0] == true then
        text = stripColors(text)
        if text == "" then return end
        local now = os.time()
        local playernick, playerid, content = text:match("(.+)%[(%d+)%]: (.+)")
        if playernick and playerid and content then
            table.insert(ChatLog, 1, {playernick, playerid, content, now, string.nlower(playernick), string.nlower(content), string.nlower(playerid), os.date("%X", now)})
            saveLogLine(now, playernick, playerid, content)
        else
            table.insert(ChatLog, 1, {"", "", text, now, "", string.nlower(text), "", os.date("%X", now)})
            saveLogLine(now, "", "", text)
        end
    end
end

loadLog()

function main()
    sampRegisterChatCommand("mlog", function()
        WinState[0] = not WinState[0]
    end)
    wait(-1)
end