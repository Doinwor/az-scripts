script_name("F7")
script_author("Gravitos")

--[[
Paste the following code in your script to enable f7 support:

local f7 = import "f7.lua"
if not f7 then f7 = {getToggle = function() return false end} end

Now, use `f7.getToggle()` to check if the interface is hidden (true = no interface should be visible)
This will ensure that if f7 is on, your script also hides its interface
]]

local enabled = false
local ffi = require("ffi")
local inicfg = require("inicfg")
local env = require("android.jnienv")
local envu = require("android.jnienv-util")
local memory = require("memory")
local settings = inicfg.load({
    pos = {
        x = 400.0,
        y = 0.0
    }
}, "chatpos.ini")
function saveCfg() inicfg.save(settings, 'chatpos.ini') end

local str, sizeof = ffi.string, ffi.sizeof

widgets = require "widgets"

function setChatPosition(x, y)
    local contextClass = envu.FindClass("com/arzmod/radare/InitGamePatch")
    if not contextClass then
        print("Failed to find InitGamePatch class")
        return
    end

    envu.CallStaticVoidMethod(contextClass, "setChatPosition", "(FF)V", ffi.cast('jfloat', x), ffi.cast('jfloat', y))
    env.DeleteLocalRef(jstr)
end

function main()
    sampRegisterChatCommand("f7", enable)
    sampRegisterChatCommand("f7_o", disable)
    while true do wait(0)
        if enabled then
            displayHud(false)
            displayRadar(false)
            for i=0,NUM_WIDGETS-1 do
                if isEnabled(i) then
                    setWidgetValue(i, 76, 0x10100, false)
                end
            end
        end
    end
end

function enable()
    enabled = true
    displayHud(false)
    displayRadar(false)
    --setPlayerControl(PLAYER_HANDLE, false)
    local x, y = getScreenResolution()
    setChatPosition(x, y)
    --switchWidescreen(true)
end

function disable()
    enabled = false
    displayHud(true)
    displayRadar(true)
    --setPlayerControl(PLAYER_HANDLE, true)
    settings = inicfg.load({ pos = { x = 400.0, y = 0.0 } }, "chatpos.ini")
    setChatPosition(settings.pos.x, settings.pos.y)
    --switchWidescreen(false)
    --for i=0,NUM_WIDGETS-1 do
--        setWidgetValue(i, 76, 0x101ff, true)
    --end
end

function onScriptTerminate(scr,quit)
    if scr == thisScript() then
        disable()
    end
end

function onTouch(type, id, x, y)
    if enabled then
        --printStringNow(type .. " " .. id .. " " .. x .. " " .. y,1000)
        local sx, sy = getScreenResolution()
        if x > sx / 3 * 2 and y < sy / 3 then disable() end
    end
    return true
end

local m_pWidgets = jit.arch == "arm" and memory.getuint32(MONET_GTASA_BASE + 0x67947C) or memory.getuint64(MONET_GTASA_BASE + 0x850910)

function getWidget(id)
    if jit.arch == "arm64" then
        return memory.getuint64(m_pWidgets + id * 8)
    else
        return memory.getuint32(m_pWidgets + id * 4)
    end
end

function isEnabled(id)
    if id == WIDGET_LOOK then return false end
    local ptr = getWidget(id)
    if ptr == 0 then return false end
    return memory.getuint8(ptr + (jit.arch == "arm" and 78 or 90)) == 1
end

function setWidgetValue(widgetId, offset, value, isInt)
    local ptr = getWidget(widgetId)
    if ptr == 0 then return "" end
    if isInt then 
        memory.setint32(ptr + offset, value)
    else
        memory.setfloat(ptr + offset, value)
    end
end

function getWidgetValue(widgetId, offset, isInt)
    local ptr = getWidget(widgetId)
    if ptr == 0 then return 0 end
    local ret = 0
    if isInt then 
        ret = memory.getint32(ptr + offset)
    else
        ret = memory.getfloat(ptr + offset)
    end
    return ret
end

EXPORTS = {
    canToggle = function() return true end,
    getToggle = function() return enabled end,
    toggle = function()
        if enabled then disable() else enable() end
    end
}
