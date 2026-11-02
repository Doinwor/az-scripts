script_author("major")
script_name("arzset")

local imgui = require 'mimgui'
local encoding = require 'encoding'
local cjson = require 'cjson'
local ffi = require 'ffi'
local hook = require 'monethook'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

local gta = ffi.load('GTASA')
ffi.cdef[[
    void* _ZN4CPad6GetPadEi(int num);
    uint8_t _ZN4CPad9GetSprintEi(void* thiz, int playerid);
]]

local isRunning = false
local original_sprint = nil

local function sprint_hook(thiz, playerid)
    if isRunning and playerid == 0 then
        return 1
    end
    return original_sprint(thiz, playerid)
end

local localPad = gta._ZN4CPad6GetPadEi(0)
original_sprint = hook.new('uint8_t(*)(void*, int)', sprint_hook, ffi.cast('uintptr_t', ffi.cast('void*', gta._ZN4CPad9GetSprintEi)))

local renderWindow = imgui.new.bool(false)

local configDir = getWorkingDirectory() .. '/config'
local configPath = configDir .. '/setanim.json'

local default_sets_count = 10
local defaultConfig = {
    isAnimEnabled = false,
    infRunEnabled = false,
    autoRunEnabled = false,
    activeSetIdx = 1,
    sets = {
        {name = "Дефолт",  group = "man",      lib = nil},
        {name = "CJ",      group = "PLAYER",   lib = nil},
        {name = "Берсерк", group = "berserk",  lib = "berserk"},
        {name = "Фрирен",  group = "friren1",  lib = "friren1"},
        {name = "Друид",   group = "druid",    lib = "druid"},
        {name = "Личь",    group = "lich1",    lib = "lich1"},
        {name = "Викинг",  group = "viking1",  lib = "viking1"},
        {name = "Обратень",group = "werewolf1",lib = "werewolf1"},
        {name = "Ведьма",  group = "witch1",   lib = "witch1"},
        {name = "Роллер",  group = "skatef",   lib = "skatef"},
    }
}

local config = {}

local function saveConfig()
    if not doesDirectoryExist(configDir) then createDirectory(configDir) end
    local f = io.open(configPath, 'w')
    if f then
        f:write(cjson.encode(config))
        f:close()
    end
end

local function loadConfig()
    if doesFileExist(configPath) then
        local f = io.open(configPath, 'r')
        if f then
            local content = f:read('*a')
            f:close()
            local status, result = pcall(cjson.decode, content)
            if status and type(result) == "table" then
                config = result
                if config.isAnimEnabled == nil then config.isAnimEnabled = defaultConfig.isAnimEnabled end
                if config.infRunEnabled == nil then config.infRunEnabled = defaultConfig.infRunEnabled end
                if config.autoRunEnabled == nil then config.autoRunEnabled = defaultConfig.autoRunEnabled end
                if config.activeSetIdx == nil then config.activeSetIdx = defaultConfig.activeSetIdx end
                if not config.sets then config.sets = defaultConfig.sets end
                isRunning = config.autoRunEnabled
                return
            end
        end
    end
    config = defaultConfig
    isRunning = config.autoRunEnabled
    saveConfig()
end

loadConfig()

local isAnimEnabled = imgui.new.bool(config.isAnimEnabled)
local infRunEnabled = imgui.new.bool(config.infRunEnabled)
local autoRunEnabled = imgui.new.bool(config.autoRunEnabled)
local activeSetIdx = config.activeSetIdx

local function applyAnimState()
    lua_thread.create(function()
        if config.isAnimEnabled then
            local set = config.sets[activeSetIdx]
            if set then
                if set.lib and set.lib ~= "" then
                    requestAnimation(set.lib)
                    while not hasAnimationLoaded(set.lib) do wait(10) end
                end
                if set.group and set.group ~= "" then
                    setAnimGroupForChar(PLAYER_PED, set.group)
                end
            end
        else
            setAnimGroupForChar(PLAYER_PED, "man")
        end
        clearCharTasksImmediately(PLAYER_PED)
    end)
end

local function activateSet(idx)
    if not config.sets[idx] then idx = 1 end
    activeSetIdx = idx
    config.activeSetIdx = idx
    saveConfig()
    
    if config.isAnimEnabled then
        applyAnimState()
    end
end

imgui.OnFrame(function() return renderWindow[0] end,
    function(player)
        imgui.SetNextWindowPos(imgui.ImVec2(500, 350), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.Begin("ArzSet", renderWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize)

        if imgui.Checkbox(u8"Включить подмену", isAnimEnabled) then
            config.isAnimEnabled = isAnimEnabled[0]
            saveConfig()
            applyAnimState()
        end
        
        if imgui.Checkbox(u8"Бесконечный бег", infRunEnabled) then
            config.infRunEnabled = infRunEnabled[0]
            saveConfig()
            setPlayerNeverGetsTired(PLAYER_HANDLE, config.infRunEnabled)
        end

        if imgui.Checkbox(u8"Автобег", autoRunEnabled) then
            config.autoRunEnabled = autoRunEnabled[0]
            isRunning = autoRunEnabled[0]
            saveConfig()
        end

        imgui.Separator()

        for i, set in ipairs(config.sets) do
            if imgui.RadioButtonBool(u8(set.name) .. "##rb" .. i, activeSetIdx == i) then
                activateSet(i)
            end

            if i > default_sets_count then
                imgui.SameLine(180) 
                if imgui.Button("X##del" .. i) then
                    table.remove(config.sets, i)
                    if activeSetIdx == i then
                        activateSet(1)
                    elseif activeSetIdx > i then
                        activeSetIdx = activeSetIdx - 1
                        config.activeSetIdx = activeSetIdx
                        saveConfig()
                    else
                        saveConfig()
                    end
                end
            end
        end

        imgui.End()
    end
)

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("arzset", function()
        renderWindow[0] = not renderWindow[0]
    end)
    
    if sampIsLocalPlayerSpawned() then
        setPlayerNeverGetsTired(PLAYER_HANDLE, config.infRunEnabled)
        if config.isAnimEnabled then applyAnimState() end
    end

    local wasSpawned = false
    local wasInCar = false

    while true do
        wait(0)
        local isSpawned = sampIsLocalPlayerSpawned()
        
        if isSpawned then
            if not wasSpawned then
                lua_thread.create(function()
                    wait(1000) 
                    if config.isAnimEnabled then
                        applyAnimState()
                    end
                    setPlayerNeverGetsTired(PLAYER_HANDLE, config.infRunEnabled)
                end)
            end

            local inCar = isCharInAnyCar(PLAYER_PED)
            if wasInCar and not inCar then
                lua_thread.create(function()
                    wait(150)
                    if config.isAnimEnabled then
                        applyAnimState()
                    end
                end)
            end
            wasInCar = inCar
        else
            wasInCar = false
        end
        
        wasSpawned = isSpawned
    end
end
