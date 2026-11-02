script_name("ZametkiPlan")
script_author("ChatGPT")
script_version("1.2")

local mimgui = require 'mimgui'
local sampev = require 'samp.events'
local ffi = require 'ffi'

local showMenu = mimgui.new.bool(false)

local notesText = ffi.new("char[8192]")
local planText = ffi.new("char[4096]")

local hourBuffer = ffi.new("int[1]", 12)
local minuteBuffer = ffi.new("int[1]", 0)

local reminderHour = 12
local reminderMinute = 0

local serverHour = 0
local serverMinute = 0

local notesFile = "zametki.txt"
local planFile = "plan.txt"

function main()

    repeat wait(0) until isSampAvailable()

    loadNotes()
    loadPlan()

    sampRegisterChatCommand("notes", function()
        showMenu[0] = not showMenu[0]
    end)

    while true do
        wait(1000)

        if serverHour == reminderHour and serverMinute == reminderMinute then
            local text = ffi.string(planText)

            if text ~= "" then
                sampAddChatMessage("[НАПОМИНАНИЕ] "..text, -1)
            end
        end
    end

end

function sampev.onServerClock(hour, minute)
    serverHour = hour
    serverMinute = minute
end

function loadNotes()

    local f = io.open(notesFile, "r")

    if f then
        local data = f:read("*a")
        f:close()
        ffi.copy(notesText, data)
    end

end

function saveNotes()

    local f = io.open(notesFile, "w")

    if f then
        f:write(ffi.string(notesText))
        f:close()
    end

end

function loadPlan()

    local f = io.open(planFile, "r")

    if f then
        local data = f:read("*a")
        f:close()
        ffi.copy(planText, data)
    end

end

function savePlan()

    local f = io.open(planFile, "w")

    if f then
        f:write(ffi.string(planText))
        f:close()
    end

end

mimgui.OnFrame(
function() return showMenu[0] end,
function()

    mimgui.SetNextWindowSize(mimgui.ImVec2(600,400), mimgui.Cond.FirstUseEver)
    mimgui.Begin("Заметки и план", showMenu)

    if mimgui.BeginTabBar("tabs") then

        if mimgui.BeginTabItem("Заметки") then

            mimgui.InputTextMultiline(
                "##notes",
                notesText,
                8192,
                mimgui.ImVec2(560,250)
            )

            if mimgui.Button("Сохранить заметки") then
                saveNotes()
                sampAddChatMessage("[ЗАМЕТКИ] сохранено", -1)
            end

            mimgui.EndTabItem()
        end

        if mimgui.BeginTabItem("План действий") then

            mimgui.InputTextMultiline(
                "##plan",
                planText,
                4096,
                mimgui.ImVec2(560,200)
            )

            mimgui.Text("Время напоминания")

            mimgui.InputInt("Час", hourBuffer)
            mimgui.InputInt("Минута", minuteBuffer)

            reminderHour = hourBuffer[0]
            reminderMinute = minuteBuffer[0]

            if mimgui.Button("Сохранить план") then
                savePlan()
                sampAddChatMessage("[ПЛАН] сохранено", -1)
            end

            mimgui.EndTabItem()
        end

        mimgui.EndTabBar()
    end

    mimgui.End()

end
)