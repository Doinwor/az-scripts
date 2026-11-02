local ffi = require('ffi')
local hook = require('monethook')

local gta = ffi.load('GTASA')
ffi.cdef[[
    void* _ZN4CPad6GetPadEi(int num);
    uint8_t _ZN4CPad9GetSprintEi(void* thiz, int playerid);
]]

local inicfg = require('inicfg')

local ini_name = 'AutoBeg.ini'

local function toBool(v) return tostring(v) == 'true' end

local cfg = inicfg.load({
    settings = {
        autorun = false, -- состояние автобега (вкл/выкл)
    }
}, ini_name)

local function saveCfg()
    inicfg.save(cfg, ini_name)
end

local isRunning = toBool(cfg.settings.autorun)
local original_sprint = nil

local function sprint_hook(thiz, playerid)
    if isRunning and playerid == 0 then
        return 1
    end
    return original_sprint(thiz, playerid)
end

local localPad = gta._ZN4CPad6GetPadEi(0)

original_sprint = hook.new('uint8_t(*)(void*, int)', sprint_hook,
                           ffi.cast('uintptr_t', ffi.cast('void*', gta._ZN4CPad9GetSprintEi)))

local function toggleRun()
    isRunning = not isRunning
    cfg.settings.autorun = isRunning
    saveCfg()
    if isRunning then
        sampAddChatMessage("Автобег включен!", -1)
    else
        sampAddChatMessage("Автобег выключен!", -1)
    end
end

sampRegisterChatCommand("run", toggleRun)

function main()
    wait(-1)
end

function onScriptTerminate(scr, q)
    if scr == thisScript() then saveCfg() end
end 