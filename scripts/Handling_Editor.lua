script_name('HandlingEditor')
script_author('lkmoj')
script_version('5.0')
script_properties('work-in-pause')

local imgui    = require 'mimgui'
local ffi      = require 'ffi'
local bit      = require 'bit'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local SAMemory = require 'SAMemory'

ffi.cdef[[
    void _Z12AND_OpenLinkPKc(const char* link);
]]
local gta = ffi.load('GTASA')

local function openLink(link)
    pcall(function() gta._Z12AND_OpenLinkPKc(link) end)
end

require 'SAMemory.game.CVehicle'
require 'SAMemory.game.tHandlingData'
require 'SAMemory.game.CPool'
require 'SAMemory.game.CPhysical'

local VEHICLES_IDE = '/storage/emulated/0/Android/data/com.arizona.game/files/data/vehicles.ide'
local HANDLING_CFG = '/storage/emulated/0/Android/data/com.arizona.game/files/data/handling.cfg'

local modelToHandling = {}

local function parseVehiclesIde()
    local f = io.open(VEHICLES_IDE, 'r')
    if not f then sampAddChatMessage('[Handling] vehicles.ide \xed\xe5 \xed\xe0\xe9\xe4\xe5\xed!', -1); return end
    for line in f:lines() do
        line = line:gsub('\r', ''):match('^%s*(.-)%s*$')
        if line ~= '' and not line:match('^#') then
            local tokens = {}
            for tok in line:gmatch('[^,]+') do tokens[#tokens+1] = tok:match('^%s*(.-)%s*$') end
            local id  = tonumber(tokens[1])
            local hid = tokens[5]
            if id and hid and hid ~= '' then modelToHandling[id] = hid:upper() end
        end
    end
    f:close()
end

local EDIT_FIELDS = {
    { label=u8('\xcc\xe0\xf1\xf1\xe0'),                                                         hnd='fMass',                                phys='fMass', min=1,   max=50000, fmt='%.1f'  },
    { label=u8('\xc8\xed\xe5\xf0\xf6\xe8\xff \xef\xee\xe2\xee\xf0\xee\xf2\xe0'),               hnd='fTurnMass',                            phys=nil,     min=1,   max=50000, fmt='%.1f'  },
    { label=u8('\xd1\xee\xef\xf0\xee\xf2\xe8\xe2\xeb\xe5\xed\xe8\xe5'),                         hnd='fDragMult',                            phys=nil,     min=0,   max=20,    fmt='%.4f'  },
    { label=u8('\xd1\xf6\xe5\xef\xeb\xe5\xed\xe8\xe5'),                                         hnd='fTractionMultiplier',                  phys=nil,     min=0,   max=5,     fmt='%.4f'  },
    { label=u8('\xcf\xee\xf2\xe5\xf0\xff \xf1\xf6\xe5\xef\xeb\xe5\xed\xe8\xff'),               hnd='fTractionLoss',                        phys=nil,     min=0,   max=1,     fmt='%.4f'  },
    { label=u8('\xc1\xe0\xeb\xe0\xed\xf1 \xf1\xf6\xe5\xef\xeb\xe5\xed\xe8\xff'),               hnd='fTractionBias',                        phys=nil,     min=0,   max=1,     fmt='%.4f'  },
    { label=u8('\xcc\xe0\xea\xf1 \xf1\xea\xee\xf0\xee\xf1\xf2\xfc'),                           hnd='transmissionData.fMaxGearVelocity',    phys=nil,     min=0,   max=2.5,   fmt='%.4f'  },
    { label=u8('\xf3\xf1\xea\xee\xf0\xe5\xed\xe8\xe5'),                                         hnd='transmissionData.fEngineAcceleration', phys=nil,     min=0,   max=0.2,   fmt='%.6f'  },
    { label=u8('\xc8\xed\xe5\xf0\xf6\xe8\xff \xe4\xe2\xe8\xe3\xea\xe0'),                       hnd='transmissionData.fEngineInertia',      phys=nil,     min=0,   max=50,    fmt='%.4f'  },
    { label=u8('\xd2\xee\xf0\xec\xee\xe7'),                                                     hnd='fBrakeDeceleration',                   phys=nil,     min=0,   max=0.05,  fmt='%.6f'  },
    { label=u8('\xc1\xe0\xeb\xe0\xed\xf1 \xf2\xee\xf0\xec\xee\xe7\xee\xe2'),                   hnd='fBrakeBias',                           phys=nil,     min=0,   max=1,     fmt='%.4f'  },
    { label=u8('\xf3\xe3\xee\xeb \xf0\xf3\xeb\xff'),                                            hnd='fSteeringLock',                        phys=nil,     min=0,   max=55,    fmt='%.2f'  },
    { label=u8('\xe6\xb8\xf1\xf2\xea\xee\xf1\xf2\xfc \xef\xee\xe4\xe2\xe5\xf1\xea\xe8'),       hnd='fSuspensionForceLevel',                phys=nil,     min=0,   max=5,     fmt='%.4f'  },
    { label=u8('\xc4\xe5\xec\xef\xf4\xe5\xf0'),                                                 hnd='fSuspensionDampingLevel',              phys=nil,     min=0,   max=5,     fmt='%.4f'  },
    { label=u8('\xc2\xe5\xf0\xf5 \xef\xee\xe4\xe2\xe5\xf1\xea\xe8'),                           hnd='fSuspensionUpperLimit',                phys=nil,     min=-1,  max=1,     fmt='%.4f'  },
    { label=u8('\xcd\xe8\xe7 \xef\xee\xe4\xe2\xe5\xf1\xea\xe8'),                               hnd='fSuspensionLowerLimit',                phys=nil,     min=-1,  max=1,     fmt='%.4f'  },
    { label=u8('\xc1\xe0\xeb\xe0\xed\xf1 \xef\xee\xe4\xe2\xe5\xf1\xea\xe8'),                   hnd='fSuspensionBiasBetweenFrontAndRear',   phys=nil,     min=0,   max=1,     fmt='%.4f'  },
    { label=u8('\xc0\xed\xf2\xe8\xea\xeb\xe5\xe2\xee\xea'),                                     hnd='fSuspensionAntiDiveMultiplier',        phys=nil,     min=0,   max=1,     fmt='%.4f'  },
    { label=u8('\xf3\xf0\xee\xed \xee\xf2 \xf1\xf2\xee\xeb\xea\xed\xee\xe2\xe5\xed\xe8\xe9'), hnd='fCollisionDamageMultiplier',           phys=nil,     min=0,   max=10,    fmt='%.4f'  },
    { label=u8('\xf1\xec\xe5\xf9\xe5\xed\xe8\xe5 \xf1\xe8\xe4\xe5\xed\xfc\xff'),               hnd='fSeatOffsetDistance',                  phys=nil,     min=0,   max=1,     fmt='%.4f'  },
}

local function getVehicleAndHnd()
    local ok, inCar = pcall(isCharInAnyCar, PLAYER_PED)
    if not ok or not inCar then return nil, nil end
    local ok2, veh_handle = pcall(storeCarCharIsInNoSave, PLAYER_PED)
    if not ok2 or not veh_handle or veh_handle == 0 then return nil, nil end
    local ok3, veh, hnd = pcall(function()
        local pool = SAMemory.vehicle_pool[0]
        if not pool then return nil, nil end
        local v = pool:get_ptr('CVehicle', veh_handle)
        if not v or ffi.cast('uintptr_t', v) == 0 then return nil, nil end
        local h = v.pHandlingData
        if ffi.cast('uintptr_t', h) == 0 then return v, nil end
        return v, h
    end)
    if ok3 then return veh, hnd end
    return nil, nil
end

local function setHndField(hnd, path, val)
    local parts = {}
    for p in path:gmatch('[^.]+') do parts[#parts+1] = p end
    local obj = hnd
    for i = 1, #parts - 1 do obj = obj[parts[i]] end
    obj[parts[#parts]] = val
end

local function getHndField(hnd, path)
    local parts = {}
    for p in path:gmatch('[^.]+') do parts[#parts+1] = p end
    local obj = hnd
    for i = 1, #parts - 1 do obj = obj[parts[i]] end
    return obj[parts[#parts]]
end

local function readMemorySnapshot()
    local cveh, hnd = getVehicleAndHnd()
    if not hnd then return nil end
    local snap = {}
    for i, ef in ipairs(EDIT_FIELDS) do
        local ok, v = pcall(getHndField, hnd, ef.hnd)
        if ef.phys and cveh then
            local ok2, pv = pcall(function() return cveh[ef.phys] end)
            if ok2 and pv ~= nil and pv == pv then v = pv end
        end
        snap[i] = (ok and v ~= nil and v == v) and v or 0
    end
    return snap
end

local function applySnapshot(snap)
    local cveh, hnd = getVehicleAndHnd()
    if not hnd then return false end
    for i, ef in ipairs(EDIT_FIELDS) do
        local val = snap[i]
        pcall(setHndField, hnd, ef.hnd, val)
        if ef.phys and cveh then
            pcall(function() cveh[ef.phys] = val end)
        end
    end
    return true
end

local showMenu   = imgui.new.bool(false)
local curName    = nil
local curModelId = nil
local origSnap   = nil
local sliders    = {}
for i = 1, #EDIT_FIELDS do sliders[i] = imgui.new.float(0) end

local function snapToSliders(snap)
    for i = 1, #EDIT_FIELDS do sliders[i][0] = snap[i] or 0 end
end

local function slidersToSnap()
    local snap = {}
    for i = 1, #EDIT_FIELDS do snap[i] = sliders[i][0] end
    return snap
end

local function getCurrentVeh()
    local ok, inCar = pcall(isCharInAnyCar, PLAYER_PED)
    if not ok or not inCar then return nil end
    local ok2, veh = pcall(storeCarCharIsInNoSave, PLAYER_PED)
    if not ok2 or not veh or veh == 0 then return nil end
    return veh
end

local function runDiag()
    local ok, inCar = pcall(isCharInAnyCar, PLAYER_PED)
    if not ok or not inCar then sampAddChatMessage('[Diag] Not in vehicle', -1); return end
    local ok2, veh_handle = pcall(storeCarCharIsInNoSave, PLAYER_PED)
    if not ok2 then return end
    sampAddChatMessage(string.format('[Diag] handle=0x%X', veh_handle), -1)
    local pool = SAMemory.vehicle_pool[0]
    local veh = pool:get_ptr('CVehicle', veh_handle)
    if not veh or ffi.cast('uintptr_t', veh) == 0 then
        sampAddChatMessage('[Diag] CVehicle=nil', -1); return
    end
    sampAddChatMessage(string.format('[Diag] CVehicle*=0x%X', tonumber(ffi.cast('uintptr_t', veh))), -1)
    sampAddChatMessage(string.format('[Diag] CPhysical.fMass=%.2f fTurnMass=%.6f fAirRes=%.4f',
        veh.fMass, veh.fTurnMass, veh.fAirResistance), -1)
    local hnd = veh.pHandlingData
    if ffi.cast('uintptr_t', hnd) == 0 then sampAddChatMessage('[Diag] pHandlingData=nil', -1); return end
    sampAddChatMessage(string.format('[Diag] hnd.fMass=%.2f fBrake=%.6f fSteer=%.4f',
        hnd.fMass, hnd.fBrakeDeceleration, hnd.fSteeringLock), -1)
    sampAddChatMessage(string.format('[Diag] hnd.MaxGearVel=%.4f hnd.EngineAcc=%.6f',
        hnd.transmissionData.fMaxGearVelocity, hnd.transmissionData.fEngineAcceleration), -1)
end

local rgbKeyframes = {
    {  0/255, 255/255, 127/255},
    {  0/255, 250/255, 154/255},
    { 46/255, 139/255,  87/255},
    {238/255, 130/255, 238/255},
    {255/255,   0/255, 255/255},
    {218/255, 112/255, 214/255},
}

local function toImU32(r, g, b, a)
    return bit.bor(
        bit.lshift(math.floor((a or 1.0) * 255), 24),
        bit.lshift(math.floor(b * 255), 16),
        bit.lshift(math.floor(g * 255), 8),
        math.floor(r * 255)
    )
end

local RGB_SPEED = 0.12

local function samplePalette(phase)
    local t = phase % 1
    local n = #rgbKeyframes
    local idx = math.floor(t * n) + 1
    local nxt = (idx % n) + 1
    local frac = (t * n) % 1
    local a, b = rgbKeyframes[idx], rgbKeyframes[nxt]
    return
        a[1] + (b[1]-a[1]) * frac,
        a[2] + (b[2]-a[2]) * frac,
        a[3] + (b[3]-a[3]) * frac
end

local function getSweepColors(alpha)
    local t = os.clock() * RGB_SPEED
    local sweep = (math.sin(t * math.pi * 2) + 1) / 2
    local r1, g1, b1 = samplePalette(t)
    local r2, g2, b2 = samplePalette(t + 0.5)
    return
        toImU32(r1*(1-sweep)+r2*sweep, g1*(1-sweep)+g2*sweep, b1*(1-sweep)+b2*sweep, alpha),
        toImU32(r2*(1-sweep)+r1*sweep, g2*(1-sweep)+g1*sweep, b2*(1-sweep)+b1*sweep, alpha)
end

local function getRgbVec4(offset, alpha)
    local r, g, b = samplePalette(os.clock() * RGB_SPEED + (offset or 0))
    return imgui.ImVec4(r, g, b, alpha or 1.0)
end

local C_ACCENT = imgui.ImVec4(0.20, 0.55, 1.00, 1.0)
local C_SUBTLE = imgui.ImVec4(0.50, 0.50, 0.60, 1.0)

imgui.OnInitialize(function()
    local s = imgui.GetStyle()
    s.WindowRounding = 8; s.FrameRounding = 5; s.GrabRounding = 5
    s.ItemSpacing    = imgui.ImVec2(8, 6)
    s.FramePadding   = imgui.ImVec2(8, 4)
    s.WindowPadding  = imgui.ImVec2(12, 10)
    s.ScrollbarSize  = 20
    local c = s.Colors
    c[imgui.Col.WindowBg]         = imgui.ImVec4(0.08, 0.08, 0.10, 0.97)
    c[imgui.Col.TitleBg]          = imgui.ImVec4(0.13, 0.13, 0.17, 1.0)
    c[imgui.Col.TitleBgActive]    = imgui.ImVec4(0.13, 0.13, 0.17, 1.0)
    c[imgui.Col.FrameBg]          = imgui.ImVec4(0.14, 0.14, 0.18, 1.0)
    c[imgui.Col.FrameBgHovered]   = imgui.ImVec4(0.18, 0.18, 0.24, 1.0)
    c[imgui.Col.SliderGrab]       = C_ACCENT
    c[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.30, 0.65, 1.00, 1.0)
    c[imgui.Col.Button]           = imgui.ImVec4(0.18, 0.45, 0.90, 1.0)
    c[imgui.Col.ButtonHovered]    = imgui.ImVec4(0.30, 0.55, 1.00, 1.0)
    c[imgui.Col.Text]             = imgui.ImVec4(0.90, 0.90, 0.95, 1.0)
    c[imgui.Col.Separator]        = imgui.ImVec4(0.20, 0.20, 0.28, 1.0)
end)

local frame = imgui.OnFrame(
    function() return showMenu[0] end,
    function()
        imgui.PushStyleColor(imgui.Col.TitleBg,       getRgbVec4(0.5, 0.60))
        imgui.PushStyleColor(imgui.Col.TitleBgActive, getRgbVec4(0,   0.85))
        imgui.PushStyleColor(imgui.Col.WindowBg,      imgui.ImVec4(0.04, 0.04, 0.06, 0.97))
        imgui.SetNextWindowSize(imgui.ImVec2(500, 620), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(imgui.ImVec2(80, 60),    imgui.Cond.FirstUseEver)
        imgui.Begin(u8('\xd5\xe5\xed\xe4\xeb\xe8\xed\xe3 \xf0\xe5\xe4\xe0\xea\xf2\xee\xf0'), showMenu)
        imgui.PopStyleColor(3)

        local dl = imgui.GetWindowDrawList()
        local wp = imgui.GetWindowPos()
        local ws = imgui.GetWindowSize()
        local colL, colR = getSweepColors(0.15)
        dl:AddRectFilledMultiColor(
            wp,
            imgui.ImVec2(wp.x + ws.x, wp.y + ws.y),
            colL, colR, colR, colL
        )

        if curName then
            imgui.TextColored(C_ACCENT, curName)
            imgui.SameLine()
            imgui.TextColored(C_SUBTLE, '(ID: ' .. tostring(curModelId) .. ')')
            imgui.SameLine()
            if imgui.SmallButton('t.me/lkmojii') then
                openLink('https://t.me/lkmojii')
            end
        else
            imgui.TextColored(C_SUBTLE, u8('\xd1\xff\xe4\xfc \xe2 \xec\xe0\xf8\xe8\xed\xf3'))
        end

        imgui.Separator(); imgui.Spacing()

        if curName then
            local bw  = imgui.GetContentRegionAvail().x
            local bw2 = (bw - 6) / 2

            if imgui.Button(u8('\xcf\xf0\xe8\xec\xe5\xed\xe8\xf2\xfc'), imgui.ImVec2(bw2, 32)) then
                if applySnapshot(slidersToSnap()) then
                    sampAddChatMessage('[Handling] \xcf\xf0\xe8\xec\xe5\xed\xe5\xed\xee: ' .. curName, -1)
                end
            end
            imgui.SameLine()
            if imgui.Button(u8('\xd7\xe8\xf2\xe0\xf2\xfc \xe8\xe7 \xef\xe0\xec\xff\xf2\xe8'), imgui.ImVec2(bw2, 32)) then
                local snap = readMemorySnapshot()
                if snap then snapToSliders(snap)
                else sampAddChatMessage('[Handling] \xce\xf8\xe8\xe1\xea\xe0 \xf7\xf2\xe5\xed\xe8\xff', -1) end
            end

            imgui.Spacing()

            if imgui.Button(u8('\xd1\xe1\xf0\xee\xf1\xe8\xf2\xfc'), imgui.ImVec2(bw2, 32)) then
                if origSnap then
                    snapToSliders(origSnap)
                    if applySnapshot(origSnap) then
                        sampAddChatMessage('[Handling] \xd1\xe1\xf0\xee\xf8\xe5\xed\xee: ' .. curName, -1)
                    end
                else
                    sampAddChatMessage('[Handling] \xcd\xe5\xf2 \xf1\xed\xe8\xec\xea\xe0!', -1)
                end
            end
            imgui.SameLine()
            if imgui.Button(u8('\xc4\xe8\xe0\xe3\xed\xee\xf1\xf2\xe8\xea\xe0'), imgui.ImVec2(bw2, 32)) then runDiag() end

            imgui.Spacing(); imgui.Separator(); imgui.Spacing()

            imgui.BeginChild('sliders', imgui.ImVec2(0, 0), false)
            local avail    = imgui.GetContentRegionAvail().x
            local slider_w = avail * 0.68
            local input_w  = avail * 0.30
            for i, ef in ipairs(EDIT_FIELDS) do
                imgui.TextColored(C_SUBTLE, ef.label)
                imgui.PushItemWidth(slider_w)
                local s_changed = imgui.SliderFloat('##s'..i, sliders[i], ef.min, ef.max, ef.fmt)
                imgui.PopItemWidth()
                imgui.SameLine()
                imgui.PushItemWidth(input_w)
                local d_changed = imgui.InputFloat('##d'..i, sliders[i], 0, 0, ef.fmt)
                imgui.PopItemWidth()
                if s_changed or d_changed then
                    local lo = s_changed and ef.min or -10000
                    local hi = s_changed and ef.max or  10000
                    if sliders[i][0] < lo then sliders[i][0] = lo end
                    if sliders[i][0] > hi then sliders[i][0] = hi end
                    local cveh, hnd = getVehicleAndHnd()
                    if hnd then
                        pcall(setHndField, hnd, ef.hnd, sliders[i][0])
                        if ef.phys and cveh then
                            pcall(function() cveh[ef.phys] = sliders[i][0] end)
                        end
                    end
                end
                imgui.Spacing()
            end
            imgui.EndChild()
        end

        imgui.End()
    end
)
frame.LockPlayer = false
frame.HideCursor = false

function main()
    while not isSampAvailable() do wait(100) end
    while not sampIsLocalPlayerSpawned() do wait(200) end

    parseVehiclesIde()

    sampRegisterChatCommand('handling', function()
        showMenu[0] = not showMenu[0]
    end)
    sampRegisterChatCommand('hdiag', function() runDiag() end)

    sampAddChatMessage('[Handling] \xc3\xee\xf2\xee\xe2 v5.0. /handling | /hdiag', -1)

    while true do
        wait(500)
        if showMenu[0] then
            local veh = getCurrentVeh()
            if veh then
                local ok, mid = pcall(getCarModel, veh)
                if ok and mid and mid ~= curModelId then
                    local hname = modelToHandling[mid] or ('Model_' .. mid)
                    curModelId = mid
                    curName    = hname
                    local snap = readMemorySnapshot()
                    if snap then
                        origSnap = snap
                        snapToSliders(snap)
                        sampAddChatMessage('[Handling] \xc7\xe0\xe3\xf0\xf3\xe6\xe5\xed\xee \xe8\xe7 \xef\xe0\xec\xff\xf2\xe8: ' .. hname, -1)
                    else
                        origSnap = nil
                        sampAddChatMessage('[Handling] \xcf\xe0\xec\xff\xf2\xfc \xed\xe5\xe4\xee\xf1\xf2\xf3\xef\xed\xe0: ' .. hname, -1)
                    end
                end
            else
                if curModelId then
                    curModelId = nil
                    curName    = nil
                    origSnap   = nil
                end
            end
        end
    end
end
