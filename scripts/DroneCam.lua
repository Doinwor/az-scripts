script_name('DroneCam')
script_author('Victor Strand')
script_version('4.0')
script_version_number(40)

local imgui   = require('mimgui')
local fa      = require('fAwesome6_solid')
local widgets = require('widgets')
local ffi     = require('ffi')
local ok_ev, sampev = pcall(require, 'lib.samp.events')
if not ok_ev then ok_ev, sampev = pcall(require, 'samp.events') end

local _gta = nil
pcall(function()
    _gta = ffi.load('GTASA')
    ffi.cdef[[ void _Z12AND_OpenLinkPKc(const char* link); ]]
end)
local function openLink(url) if _gta then pcall(_gta._Z12AND_OpenLinkPKc, url) end end

local MDS    = MONET_DPI_SCALE
local sw, sh = getScreenResolution()

local function cp(text) return monet_utf8_to_cp1251(text) end
local function chat(text)
    sampAddChatMessage(cp('{00D9FF}[Drone]{FFFFFF} '..text), -1)
end

local DIR  = getWorkingDirectory()..'/DroneCam'
local FCFG = DIR..'/config.ini'
if not doesDirectoryExist(DIR) then createDirectory(DIR) end

local C = {

    fL = math.floor(sw*0.21), fT = math.floor(sh*0.07),
    fR = math.floor(sw*0.84), fB = math.floor(sh*0.84),

    showFrame = true, showCross = true, showCtrlUI = true,
    showCarBox = true, showCineBar = true,

    sFwd = 30, sTurn = 30, fov = 60,
    autoSpeed = 20,
    homingDist = 12,

    orbitRadius = 18, orbitSpeed = 12, orbitAlt = 6,
    zoomDist = 18, cineDur = 8,

    joyMode = 1,
    invertY = false,

    camView    = 1,
    droneModel = 1,
    autoStrike = true,
    bombType   = 1,
    hydraWeapon= 1,

    autoBombOn  = false,
    autoBombRPM = 20,

    homingAttack= false,

    sound       = true,
    soundVol    = 0.7,
    camShakeOn  = true,
    fxTrails    = true,
}
local C_BOOL = {
    showFrame=true, showCross=true, showCtrlUI=true, showCarBox=true,
    showCineBar=true, invertY=true, autoStrike=true, autoBombOn=true,
    homingAttack=true, sound=true, camShakeOn=true, fxTrails=true,
}

local function saveC()
    local f = io.open(FCFG, 'w')
    if not f then return end
    f:write('[s]\n')
    for k, v in pairs(C) do
        if C_BOOL[k] then f:write(k..'='..(v and '1' or '0')..'\n')
        else              f:write(k..'='..tostring(v)..'\n') end
    end
    f:close()
end
local function loadC()
    if not doesFileExist(FCFG) then saveC(); return end
    local f = io.open(FCFG, 'r')
    if not f then return end
    for line in f:lines() do
        local k, v = line:match('^([%w]+)=(.+)$')
        if k and C[k] ~= nil then
            if C_BOOL[k] then C[k] = (v == '1')
            else              C[k] = tonumber(v) or C[k] end
        end
    end
    f:close()
end

local SND_SR  = 8000
local SND_SRC = {
    droneHum = DIR..'/drone_hum.wav',
    jetHum   = DIR..'/jet_hum.wav',
    fire     = DIR..'/fire.wav',
    boom     = DIR..'/boom.wav',
}

local function sndWriteWav(path, sr, samples)
    local n = #samples
    local function le16(v) return string.char(v%256, math.floor(v/256)%256) end
    local function le32(v) return string.char(v%256, math.floor(v/256)%256,
        math.floor(v/65536)%256, math.floor(v/16777216)%256) end
    local ok, f = pcall(io.open, path, 'wb')
    if not ok or not f then return false end
    f:write('RIFF'); f:write(le32(36+n)); f:write('WAVE')
    f:write('fmt '); f:write(le32(16)); f:write(le16(1)); f:write(le16(1))
    f:write(le32(sr)); f:write(le32(sr)); f:write(le16(1)); f:write(le16(8))
    f:write('data'); f:write(le32(n))
    local buf = {}
    for i = 1, n do
        local v = math.floor((samples[i]*0.5 + 0.5) * 255 + 0.5)
        buf[i] = string.char(v < 0 and 0 or (v > 255 and 255 or v))
    end
    f:write(table.concat(buf)); f:close()
    return true
end

local function sndGen(kind, sr)
    local s, lp = {}, 0
    if kind == 'hum' then
        local n = sr
        for i = 1, n do
            local t  = i/sr
            local am = 0.85 + 0.15*math.sin(2*math.pi*8*t)
            s[i] = ((0.5*math.sin(2*math.pi*80*t) + 0.28*math.sin(2*math.pi*160*t)
                   + 0.12*math.sin(2*math.pi*240*t)) * am + 0.06*(math.random()*2-1)) * 0.8
        end
    elseif kind == 'jet' then
        local n = sr
        for i = 1, n do
            local t = i/sr
            lp = lp + 0.25*((math.random()*2-1) - lp)
            s[i] = (0.35*math.sin(2*math.pi*180*t) + 0.2*math.sin(2*math.pi*360*t)) * 0.6
                 + lp * 0.55
        end
    elseif kind == 'fire' then
        local n = math.floor(sr*0.35)
        for i = 1, n do
            local t = i/sr
            local env = math.exp(-t*9)
            lp = lp + 0.5*((math.random()*2-1) - lp)
            local chirp = math.sin(2*math.pi*(650 - 520*(t/0.35))*t)
            s[i] = (0.5*lp + 0.5*chirp) * env
        end
    else
        local n = math.floor(sr*1.2)
        for i = 1, n do
            local t = i/sr
            local env = math.exp(-t*3.2)
            lp = lp + 0.15*((math.random()*2-1) - lp)
            local low = math.sin(2*math.pi*(55 - 25*(t/1.2))*t)
            local crack = (t < 0.02) and (math.random()*2-1) or 0
            local v = (0.6*low + 0.55*lp + crack) * env * 1.3
            s[i] = v < -1 and -1 or (v > 1 and 1 or v)
        end
    end
    return s
end

local snd = { hum = nil, humKind = nil, fire = nil, boom = nil, ready = false, gen = false }
local function sndAvailable()
    if type(monet_is_audiostream_available) ~= 'function' then return false end
    local ok, a = pcall(monet_is_audiostream_available)
    return ok and a == true
end

local function sndEnsureFiles()
    if snd.gen then return end
    snd.gen = true
    if not doesFileExist(SND_SRC.droneHum) then pcall(sndWriteWav, SND_SRC.droneHum, SND_SR, sndGen('hum',  SND_SR)) end
    if not doesFileExist(SND_SRC.jetHum)   then pcall(sndWriteWav, SND_SRC.jetHum,   SND_SR, sndGen('jet',  SND_SR)) end
    if not doesFileExist(SND_SRC.fire)     then pcall(sndWriteWav, SND_SRC.fire,     SND_SR, sndGen('fire', SND_SR)) end
    if not doesFileExist(SND_SRC.boom)     then pcall(sndWriteWav, SND_SRC.boom,     SND_SR, sndGen('boom', SND_SR)) end
end
local function sndLoad3d(src)
    if not src or not doesFileExist(src) then return nil end
    local ok, s = pcall(load3dAudioStream, src)
    if ok and s then return s end
    return nil
end

local function sndInit()
    if snd.ready then return end
    if not C.sound or not sndAvailable() then return end
    sndEnsureFiles()
    snd.fire = sndLoad3d(SND_SRC.fire)
    snd.boom = sndLoad3d(SND_SRC.boom)
    snd.ready = true
end

local function sndPlayAt(s, x, y, z, vol)
    if not s or not C.sound then return end
    pcall(setAudioStreamVolume, s, vol or C.soundVol or 0.7)
    pcall(setAudioStreamState, s, 0)
    pcall(setAudioStreamPosition, s, 0)
    pcall(setPlay3dAudioStreamAtCoordinates, s, x, y, z)
    pcall(setAudioStreamState, s, 1)
end

local function sndStartHum(kind)
    if not C.sound or not sndAvailable() then return end
    sndEnsureFiles()
    if snd.hum and snd.humKind == kind then
        pcall(setAudioStreamState, snd.hum, 1); return
    end
    if snd.hum then pcall(releaseAudioStream, snd.hum); snd.hum = nil end
    local src = (kind == 'jet') and SND_SRC.jetHum or SND_SRC.droneHum
    snd.hum = sndLoad3d(src)
    snd.humKind = kind
    if snd.hum then
        pcall(setAudioStreamLooped, snd.hum, true)
        pcall(setAudioStreamVolume, snd.hum, C.soundVol or 0.7)
        pcall(setAudioStreamState, snd.hum, 1)
    end
end
local function sndStopHum()
    if snd.hum then pcall(setAudioStreamState, snd.hum, 0) end
end

local function sndUpdateHum(x, y, z, spd01)
    if not snd.hum or not C.sound then return end
    local s = math.max(0, math.min(1, spd01 or 0))
    pcall(setPlay3dAudioStreamAtCoordinates, snd.hum, x, y, z)
    pcall(setAudioStreamVolume, snd.hum, (0.35 + 0.65*s) * (C.soundVol or 0.7))
end

local active   = false
local fakeNpc  = nil
local sX, sY, sZ = 0, 0, 0
local sAngle   = 0
local sHp      = 100

local camX, camY, camZ = 0, 0, 0
local angZ, angY = 0, 0
local curFov   = 60
local zoomDist = 18

local joy = { x = 0, y = 0 }
local vel = { x = 0, y = 0, z = 0 }
local JOY_DEADZONE = 0.10
local INPUT_SMOOTH = 14
local ACCEL        = 6

local camAlt, camDist, camSpd = 0, 0, 0
local recStart, recBlink = 0, 0

local hold = { au=false, ad=false, cu=false, cd=false, yl=false, yr=false }

local uiStickMute = 0

local autopilot = { fwd=false, back=false, left=false, right=false, up=false, down=false }
local function autopilotSet(dir)
    local was = autopilot[dir]
    for k in pairs(autopilot) do autopilot[k] = false end
    if not was then autopilot[dir] = true end
end
local function autopilotOff()
    for k in pairs(autopilot) do autopilot[k] = false end
end
local function autopilotActive()
    for _, v in pairs(autopilot) do if v then return true end end
    return false
end

local trackMode, trackVeh, trackPed = false, nil, nil
local trackHeightOffset = 0

local orbitTarget = nil
local nearCache   = { vehs = {}, peds = {} }

local hoverTarget = nil

local DRONE_MODELS = {
    { id = nil,   name = 'Стандарт' },
    { id = 14355, name = 'RC Mavic' },
    { id = 12605, name = 'Inspire'  },
}
local body = nil
local spawnedDrones = {}

local function createDroneUnit(modelId, x, y, z)
    if not modelId then return nil end
    if type(requestModel) == 'function' then
        pcall(requestModel, modelId)
        pcall(loadAllModelsNow)
    end
    local okC, car = pcall(createCar, modelId, x, y, z)
    if okC and car and car ~= -1 and doesVehicleExist(car) then
        pcall(freezeCarPosition, car, true)
        return { kind = 'car', handle = car, model = modelId }
    end
    local okO, obj = pcall(createObject, modelId, x, y, z)
    if okO and obj and obj ~= -1 then
        pcall(setObjectCollision, obj, false)
        return { kind = 'obj', handle = obj, model = modelId }
    end
    return nil
end
local function unitExists(u)
    if not u then return false end
    if u.kind == 'car' then return doesVehicleExist(u.handle) end
    local ok, ex = pcall(doesObjectExist, u.handle)
    return ok and ex == true
end
local function unitGetPos(u)
    local ok, x, y, z
    if u.kind == 'car' then ok, x, y, z = pcall(getCarCoordinates, u.handle)
    else ok, x, y, z = pcall(getObjectCoordinates, u.handle) end
    if ok and type(x) == 'number' then return x, y, z end
    return nil
end

local function unitSetPos(u, x, y, z, headDeg, tiltDeg)
    if u.kind == 'car' then
        pcall(setCarCoordinates, u.handle, x, y, z)
        pcall(setCarHeading, u.handle, (-headDeg) % 360)
    else
        pcall(setObjectCoordinates, u.handle, x, y, z)
        pcall(setObjectRotation, u.handle, tiltDeg or 0, 0, (-headDeg) % 360)
    end
end
local function unitDelete(u)
    if not u then return end
    if u.kind == 'car' then pcall(deleteCar, u.handle)
    else pcall(deleteObject, u.handle) end
end
local function modelName(id)
    for _, m in ipairs(DRONE_MODELS) do
        if m.id == id then return m.name end
    end
    return tostring(id)
end

local function clamp(v, mn, mx) return math.max(mn, math.min(mx, v)) end

local function smoothK(rate, dt) return 1 - math.exp(-rate * dt) end

local function fwdVec(aDeg)
    local r = math.rad(aDeg); return math.sin(r), math.cos(r)
end

local function rightVec(aDeg)
    local r = math.rad(aDeg); return math.cos(r), -math.sin(r)
end

local function angDiff(a, b) return ((b - a + 180) % 360) - 180 end

local orbit = { active=false, veh=nil, angle=0, dir=1, look=true }
local function orbitStart(vehHandle, dir)
    if not vehHandle or not doesVehicleExist(vehHandle) then return end
    orbit.veh, orbit.dir, orbit.active = vehHandle, dir or 1, true
    orbit.angle = math.rad(angZ)
    autopilotOff()
    chat('CarOrbit '..(dir==1 and 'по часовой' or 'ПЧС')..' вкл')
end
local function orbitStop()
    if not orbit.active then return end
    orbit.active, orbit.veh = false, nil
    chat('CarOrbit откл')
end

local cine = { active=false, mode=nil, veh=nil, t=0, dir=1, angle=0, baseAng=0 }
local CINE_NAMES = {
    dolly='Наезд (Dolly)', crane='Кран (Crane)', spiral='Спираль (Spiral)',
    flyby='Пролёт (Fly-by)', front='На бампер', rear='На багажник',
}
local CINE_PRESETS = {
    {k='orbit', dir=1,  icon=fa['ROTATE'],                                lbl='Orbit »'},
    {k='orbit', dir=-1, icon=fa['ROTATE'],                                lbl='Orbit «'},
    {k='cine', mode='dolly',  icon=fa['RIGHT_LEFT'] or fa['ARROW_DOWN'],  lbl='Наезд'},
    {k='cine', mode='crane',  icon=fa['ANGLES_UP']  or fa['ARROW_UP'],    lbl='Кран'},
    {k='cine', mode='spiral', icon=fa['ROTATE'],                          lbl='Спираль'},
    {k='cine', mode='flyby',  icon=fa['ARROW_RIGHT'],                     lbl='Пролёт'},
    {k='cine', mode='front',  icon=fa['CAR'],                             lbl='На бампер'},
    {k='cine', mode='rear',   icon=fa['CAR'],                             lbl='На багаж'},
}
local function cineStop()
    if not cine.active then return end
    cine.active, cine.veh, cine.mode = false, nil, nil
    chat('Кино-режим откл')
end
local function cineStart(vehHandle, mode)
    if not vehHandle or not doesVehicleExist(vehHandle) then
        chat('Сначала выберите цель (Таб Цели)'); return
    end
    orbit.active = false
    cine.veh, cine.mode, cine.active = vehHandle, mode, true
    cine.t, cine.dir = 0, 1
    cine.angle   = math.rad(angZ)
    cine.baseAng = cine.angle
    chat('Кино: '..(CINE_NAMES[mode] or mode))
end

local function cineTarget()
    if orbitTarget and doesVehicleExist(orbitTarget) then return orbitTarget end
    if trackVeh    and doesVehicleExist(trackVeh)    then return trackVeh    end
    return nil
end
local function shotActive(p)
    if p.k == 'orbit' then return orbit.active and orbit.dir == p.dir end
    return cine.active and cine.mode == p.mode
end
local function runShot(p)
    local tgt = cineTarget()
    if not tgt then chat('Сначала выбери цель (Таб Цели: Цель/Слеж)'); return end
    if shotActive(p) then orbitStop(); cineStop(); return end
    autopilotOff()
    if p.k == 'orbit' then cineStop(); orbitStart(tgt, p.dir)
    else orbitStop(); cineStart(tgt, p.mode) end
end

local homing = { active = false, struck = false, attack = false,
                 lpx = nil, lpy = nil, lpz = nil, lt = 0, tvx = 0, tvy = 0, tvz = 0 }

local function homingTargetPos()
    if orbitTarget and doesVehicleExist(orbitTarget) then
        local ok, x, y, z = pcall(getCarCoordinates, orbitTarget)
        if ok and type(x) == 'number' then return x, y, z end
    end
    if trackVeh and doesVehicleExist(trackVeh) then
        local ok, x, y, z = pcall(getCarCoordinates, trackVeh)
        if ok and type(x) == 'number' then return x, y, z end
    end
    if trackPed and doesCharExist(trackPed) then
        local ok, x, y, z = pcall(getCharCoordinates, trackPed)
        if ok and type(x) == 'number' then return x, y, z end
    end
    return nil
end
local function homingToggle()
    if homing.active then
        homing.active = false
        chat('Наведение откл')
        return
    end
    if not homingTargetPos() then
        chat('Наведение: сначала выбери цель (Таб Цели)'); return
    end
    autopilotOff(); orbitStop(); cineStop()
    trackMode = false
    homing.active = true
    homing.struck = false
    homing.attack = C.homingAttack
    homing.lpx, homing.lpy, homing.lpz, homing.lt = nil, nil, nil, 0
    homing.tvx, homing.tvy, homing.tvz = 0, 0, 0
    homing.fireT = 0.6
    if homing.attack then
        chat('Наведение ATTACK: дрон держит дистанцию и бьёт по цели'
            ..(C.autoStrike and ' самонаводящимися бомбами' or ' (авто-сброс выкл)'))
    else
        chat('Наведение FOLLOW: дрон держится за целью на '..math.max(4, C.homingDist)..'м')
    end
end

local function homingAttackToggle()
    C.homingAttack = not C.homingAttack
    homing.attack  = C.homingAttack
    if C.homingAttack then homing.struck, homing.fireT = false, 0.4 end
    saveC()
    chat('Наведение: режим '..(C.homingAttack
        and 'ATTACK (огонь по цели самонаводящимися бомбами с дистанции)'
        or  'FOLLOW (эскорт, держим дистанцию)'))
end

local BOMB_MODEL    = 1225
local BOMB_GRAVITY  = 28
local BOMB_LIFETIME = 10
local ROCKET_MODEL  = 345
local MAX_BOMBS     = 40
local bombs   = {}
local impacts = {}
local autoBomb = { nextT = 0 }

local trails = {}
local sparks = {}
local muzzle = 0
local shake  = { t = 0, mag = 0 }
local FW_COLS = { 0x00FF3355, 0x0033FF66, 0x003366FF, 0x00FFCC00, 0x00FF66FF, 0x0000FFEE }

local function spawnFireworks(x, y, z)
    pcall(addExplosion, x, y, z + 3, 8)
    pcall(addExplosion, x, y, z + 8, 8)

    for burst = 1, 3 do
        local col = FW_COLS[math.random(#FW_COLS)]
        local cz  = z + 2 + burst * 3
        for i = 1, 34 do
            local a  = math.random() * math.pi * 2
            local el = math.random() * math.pi * 0.5
            local sp = 10 + math.random() * 16
            sparks[#sparks+1] = { x = x, y = y, z = cz,
                vx = math.cos(a)*math.cos(el)*sp, vy = math.sin(a)*math.cos(el)*sp,
                vz = math.sin(el)*sp + 10, t = 0, life = 1.6 + math.random()*0.9,
                col = col, big = true }
        end
    end
end

local function addShake(mag, dur)
    if not C.camShakeOn then return end
    if mag > shake.mag or shake.t <= 0 then shake.mag = mag end
    shake.t = math.max(shake.t, dur)
end

local function shakeOffset()
    if shake.t <= 0 then return 0, 0, 0 end
    local m = shake.mag * shake.t
    return (math.random()-0.5)*2*m, (math.random()-0.5)*2*m, (math.random()-0.5)*2*m
end

local function fxUpdate(dt)
    for i = #trails, 1, -1 do
        trails[i].t = trails[i].t + dt
        if trails[i].t > 1.2 then table.remove(trails, i) end
    end
    for i = #sparks, 1, -1 do
        local s = sparks[i]
        s.t  = s.t + dt
        s.vz = s.vz - 12 * dt
        s.x, s.y, s.z = s.x + s.vx*dt, s.y + s.vy*dt, s.z + s.vz*dt
        if s.t > s.life then table.remove(sparks, i) end
    end
    if muzzle  > 0 then muzzle  = math.max(0, muzzle  - dt) end
    if shake.t > 0 then shake.t = math.max(0, shake.t - dt) end
end

local BOMB_TYPES = {
    { name='Фугас',     model=1225, expl=2, grav=28, cluster=0, fire=false, radius=1.0 },
    { name='Тяжёлая',   model=345,  expl=7, grav=36, cluster=0, fire=false, radius=1.7 },
    { name='Напалм',    model=344,  expl=1, grav=24, cluster=0, fire=true,  radius=1.3 },
    { name='Кассетная', model=342,  expl=0, grav=26, cluster=6, fire=false, radius=1.4 },
    { name='Дымовая',   model=343,  expl=0, grav=20, cluster=0, fire=false, radius=0.8, smoke=true },
    { name='Салют',     model=342,  expl=0, grav=18, cluster=0, fire=false, radius=1.0, firework=true },
    { name='Ядерная',   model=345,  expl=7, grav=22, cluster=0, fire=false, radius=3.0, nuke=true },
}
local function bombType() return BOMB_TYPES[C.bombType] or BOMB_TYPES[1] end

local HYDRA_WEAPONS = {
    { name='Ракета',      model=345, cd=0.45, speed=85,  expl=2, life=3.0, burst=1, spread=0.0 },
    { name='Миниган',     model=345, cd=0.08, speed=140, expl=0, life=1.6, burst=1, spread=0.04 },
    { name='Тяж. ракета', model=345, cd=0.80, speed=70,  expl=7, life=3.5, burst=1, spread=0.0 },
}
local function hydraWeapon() return HYDRA_WEAPONS[C.hydraWeapon] or HYDRA_WEAPONS[1] end

local function bombDrop(aimX, aimY, aimZ, silent)
    if type(aimX) ~= 'number' then aimX, aimY, aimZ = nil, nil, nil end
    if not active then chat('Бомбы: сначала включи дрон'); return end
    if #bombs >= MAX_BOMBS then return end
    local bt = bombType()
    local b = {
        x = camX, y = camY, z = camZ - 1.0,
        vx = vel.x * 0.5, vy = vel.y * 0.5, vz = math.min(vel.z, 0),
        t = 0, obj = nil, groundZ = nil,
        g = bt.grav, expl = bt.expl, cluster = bt.cluster, fire = bt.fire,
        smoke = bt.smoke, radius = bt.radius, firework = bt.firework, nuke = bt.nuke,
    }
    local okG, gz = pcall(getGroundZFor3dCoord, b.x, b.y, b.z)
    if okG and type(gz) == 'number' then b.groundZ = gz end
    if aimX then

        local h     = math.max(2, b.z - (aimZ or b.groundZ or (b.z - 30)))
        local tFall = math.sqrt(2 * h / (bt.grav or BOMB_GRAVITY))
        b.vx = clamp((aimX - b.x) / tFall, -45, 45)
        b.vy = clamp((aimY - b.y) / tFall, -45, 45)
    end

    if homing.active and homing.attack and homingTargetPos() then
        b.homingT = true
    end
    if type(requestModel) == 'function' then
        pcall(requestModel, bt.model or BOMB_MODEL)
        pcall(loadAllModelsNow)
    end
    local okO, obj = pcall(createObject, bt.model or BOMB_MODEL, b.x, b.y, b.z)
    if okO and obj and obj ~= -1 then
        b.obj = obj
        pcall(setObjectCollision, obj, false)
    end
    bombs[#bombs+1] = b
    if not silent then
        chat((aimX and 'Сброс по цели: ' or 'Сброс: ')..bt.name)
    end
end

local function autoBombUpdate(dt)
    if not C.autoBombOn then return end
    if not active then return end
    local rpm = clamp(C.autoBombRPM or 20, 1, 200)
    local interval = 60 / rpm
    autoBomb.nextT = autoBomb.nextT - dt

    local guard = 0
    while autoBomb.nextT <= 0 and guard < 8 do
        autoBomb.nextT = autoBomb.nextT + interval
        guard = guard + 1

        if homing.active and homing.attack then
            local tx, ty, tz = homingTargetPos()
            bombDrop(tx, ty, tz, true)
        else
            bombDrop(nil, nil, nil, true)
        end
        if #bombs >= MAX_BOMBS then break end
    end
end

local function applyBlastDamage(x, y, z, killR, hurtR)
    local okV, allV = pcall(getAllVehicles)
    if okV and allV then
        for _, vh in ipairs(allV) do
            local isBody = body and body.kind == 'car' and body.handle == vh
            if doesVehicleExist(vh) and not isBody then
                local okC, vx, vy, vz = pcall(getCarCoordinates, vh)
                if okC and type(vx) == 'number' then
                    local d = getDistanceBetweenCoords3d(x, y, z, vx, vy, vz)
                    if d < killR then
                        pcall(setCarHealth, vh, 0)
                    elseif d < hurtR then
                        local okH, h = pcall(getCarHealth, vh)
                        if okH and type(h) == 'number' then
                            pcall(setCarHealth, vh, math.max(120, h - 450))
                        end
                    end
                end
            end
        end
    end
    local okP, allP = pcall(getAllChars)
    if okP and allP then
        for _, ped in ipairs(allP) do
            if doesCharExist(ped) and ped ~= PLAYER_PED and ped ~= fakeNpc then
                local okC, px, py, pz = pcall(getCharCoordinates, ped)
                if okC and type(px) == 'number' then
                    local d = getDistanceBetweenCoords3d(x, y, z, px, py, pz)
                    if d < killR + 1 then
                        pcall(setCharHealth, ped, 0)
                    elseif d < hurtR then
                        local okH, h = pcall(getCharHealth, ped)
                        if okH and type(h) == 'number' then
                            pcall(setCharHealth, ped, math.max(0, h - 70))
                        end
                    end
                end
            end
        end
    end
end

local function spawnNuke(x, y, z)
    pcall(addExplosion, x, y, z, 7)
    for i = 1, 12 do
        local a = math.random()*math.pi*2
        local r = math.random()*20
        pcall(addExplosion, x + math.cos(a)*r, y + math.sin(a)*r, z, 7)
    end
    for k = 1, 7 do pcall(addExplosion, x, y, z + k*6, 2) end
    applyBlastDamage(x, y, z, 32, 60)
    addShake(3.2, 1.3)
    sndPlayAt(snd.boom, x, y, z, 1.0)
    impacts[#impacts+1] = { x=x, y=y, z=z, t=os.clock(), r=3.0, nuke=true }

    for i = 1, 44 do
        local a  = math.random()*math.pi*2
        local el = math.random()*math.pi*0.5
        local sp = 8 + math.random()*16
        sparks[#sparks+1] = { x=x, y=y, z=z+2, vx=math.cos(a)*math.cos(el)*sp,
            vy=math.sin(a)*math.cos(el)*sp, vz=math.sin(el)*sp + 10, t=0,
            life=1.6 + math.random()*0.9, big=true,
            col=(math.random()<0.5 and 0x00FF8800 or 0x00FFDD44) }
    end
end

local function bombExplode(b)
    if b.obj then pcall(deleteObject, b.obj); b.obj = nil end
    if b.nuke then
        spawnNuke(b.x, b.y, b.z)
        return
    end
    if b.firework then

        spawnFireworks(b.x, b.y, b.z)
        sndPlayAt(snd.boom, b.x, b.y, b.z, (C.soundVol or 0.7) * 0.6)
        impacts[#impacts+1] = { x=b.x, y=b.y, z=b.z, t=os.clock(), r=0.6 }
        return
    end
    if b.smoke then

        pcall(addExplosion, b.x, b.y, b.z, 8)
    else
        pcall(addExplosion, b.x, b.y, b.z, b.expl or 2)

        local rad = b.radius or 1.0
        applyBlastDamage(b.x, b.y, b.z, 5*rad, 12*rad)
    end

    if b.fire then
        for i = 1, 3 do
            local a = math.random() * math.pi * 2
            local r = math.random() * 3
            pcall(addExplosion, b.x + math.cos(a)*r, b.y + math.sin(a)*r, b.z, 1)
        end
    end

    if b.cluster and b.cluster > 0 then
        for i = 1, b.cluster do
            local a = (i / b.cluster) * math.pi * 2 + math.random()
            local r = 4 + math.random() * 5
            pcall(addExplosion, b.x + math.cos(a)*r, b.y + math.sin(a)*r, b.z, 0)
        end
    end

    if not b.smoke then
        sndPlayAt(snd.boom, b.x, b.y, b.z)
        local dCam = getDistanceBetweenCoords3d(camX, camY, camZ, b.x, b.y, b.z)
        if dCam < 70 then
            addShake((1 - dCam/70) * 1.5 * (b.radius or 1), 0.4)
        end
    end
    impacts[#impacts+1] = { x=b.x, y=b.y, z=b.z, t=os.clock(),
                            r=b.radius or 1.0, smoke=b.smoke }
end
local function bombsUpdate(dt)

    local htx, hty, htz
    if homing.active and homing.attack then htx, hty, htz = homingTargetPos() end
    for i = #bombs, 1, -1 do
        local b = bombs[i]
        b.t  = b.t + dt

        if (b.homingT or b.homingR) and htx then
            local dx, dy, dz = htx - b.x, hty - b.y, (htz + 0.5) - b.z
            local dl = math.sqrt(dx*dx + dy*dy + dz*dz)
            if dl > 0.5 then
                local sp   = math.sqrt(b.vx*b.vx + b.vy*b.vy + b.vz*b.vz)
                if sp < 1 then sp = b.homingR and 60 or 20 end

                local k = smoothK(b.homingR and 3.5 or 2.2, dt)
                b.vx = b.vx + ((dx/dl)*sp - b.vx) * k
                b.vy = b.vy + ((dy/dl)*sp - b.vy) * k
                b.vz = b.vz + ((dz/dl)*sp - b.vz) * k
            end
        end
        b.vz = b.vz - (b.g or BOMB_GRAVITY) * dt
        b.x  = b.x + b.vx * dt
        b.y  = b.y + b.vy * dt
        b.z  = b.z + b.vz * dt
        if b.obj then
            pcall(setObjectCoordinates, b.obj, b.x, b.y, b.z)

            if not b.rocket then
                b.rot = (b.rot or 0) + dt * 260
                pcall(setObjectRotation, b.obj, b.rot, b.rot * 0.6, b.rot * 0.3)
            end
        end
        if b.rocket then

            local okG, gz = pcall(getGroundZFor3dCoord, b.x, b.y, b.z + 1)
            if okG and type(gz) == 'number' then b.groundZ = gz end

            if C.fxTrails then
                b.trailT = (b.trailT or 0) + dt
                if b.trailT > 0.03 then
                    b.trailT = 0
                    if #trails < 140 then trails[#trails+1] = { x=b.x, y=b.y, z=b.z, t=0 } end
                end
            end
        end
        local hitGround = b.groundZ and (b.z <= b.groundZ + 0.4)
        if hitGround or b.t > (b.life or BOMB_LIFETIME) then
            if hitGround then b.z = b.groundZ + 0.3 end
            bombExplode(b)
            table.remove(bombs, i)
        end
    end

    for i = #impacts, 1, -1 do
        local ttl = impacts[i].nuke and 9.0 or (impacts[i].smoke and 7.0 or 1.4)
        if os.clock() - impacts[i].t > ttl then table.remove(impacts, i) end
    end
    fxUpdate(dt)
end
local function bombsClear()
    for _, b in ipairs(bombs) do
        if b.obj then pcall(deleteObject, b.obj) end
    end
    bombs, impacts, trails, sparks = {}, {}, {}, {}
end

local HYDRA_MODEL = 520
local hydra = { fireHeld = false, native = false, hookGun = nil, hookJust = nil,
                justSent = false, lastEmu = 0 }

pcall(function()
    if not _gta then error('no gta lib') end
    local hookLib = require('monethook')
    ffi.cdef[[
        int16_t _ZN4CPad14GetCarGunFiredEv(void* thiz);
        int16_t _ZNK4CPad14GetCarGunFiredEv(void* thiz);
        int16_t _ZN4CPad14CarGunJustDownEv(void* thiz);
        int16_t _ZNK4CPad14CarGunJustDownEv(void* thiz);
    ]]
    local function sym(name)
        local ok, addr = pcall(function()
            return ffi.cast('uintptr_t', ffi.cast('void*', _gta[name]))
        end)
        if ok and addr and tonumber(addr) ~= 0 then return addr end
        return nil
    end
    local aGun  = sym('_ZN4CPad14GetCarGunFiredEv')  or sym('_ZNK4CPad14GetCarGunFiredEv')
    local aJust = sym('_ZN4CPad14CarGunJustDownEv')  or sym('_ZNK4CPad14CarGunJustDownEv')
    if aGun then
        local ok, h = pcall(hookLib.new, 'int16_t(*)(void*)', function(thiz)
            if hydra.fireHeld then return 255 end
            if hydra.hookGun then return hydra.hookGun.call(thiz) end
            return 0
        end, aGun)
        if ok then hydra.hookGun = h end
    end
    if aJust then
        local ok, h = pcall(hookLib.new, 'int16_t(*)(void*)', function(thiz)
            if hydra.fireHeld then
                if not hydra.justSent then hydra.justSent = true; return 255 end
                return 0
            end
            hydra.justSent = false
            if hydra.hookJust then return hydra.hookJust.call(thiz) end
            return 0
        end, aJust)
        if ok then hydra.hookJust = h end
    end
    hydra.native = (hydra.hookGun ~= nil)
end)

local hydraMode = false

local function simHydraFire()
    local now = os.clock()
    local w = hydraWeapon()
    if now - hydra.lastEmu < (w.cd or 0.45) then return end
    if #bombs >= MAX_BOMBS then return end
    hydra.lastEmu = now
    muzzle = 0.06
    sndPlayAt(snd.fire, camX, camY, camZ)
    local rZ, rY = math.rad(angZ), math.rad(angY)

    local homeR = (homing.active and homing.attack and homingTargetPos()) and true or false
    for _ = 1, (w.burst or 1) do
        local spd = w.spread or 0
        local dx = math.sin(rZ) * math.cos(rY) + (math.random()-0.5)*2*spd
        local dy = math.cos(rZ) * math.cos(rY) + (math.random()-0.5)*2*spd
        local dz = math.sin(rY)               + (math.random()-0.5)*2*spd
        local v  = w.speed or 85
        local b = { x = camX + dx*6, y = camY + dy*6, z = camZ + dz*6 - 0.5,
                    vx = dx*v + vel.x, vy = dy*v + vel.y, vz = dz*v,
                    g = 2.5, t = 0, life = w.life or 3.0, rocket = true,
                    expl = w.expl or 2, homingR = homeR }
        if type(requestModel) == 'function' then
            pcall(requestModel, w.model or ROCKET_MODEL)
            pcall(loadAllModelsNow)
        end
        local okO, obj = pcall(createObject, w.model or ROCKET_MODEL, b.x, b.y, b.z)
        if okO and obj and obj ~= -1 then
            b.obj = obj
            pcall(setObjectCollision, obj, false)
            pcall(setObjectRotation, obj, 0, 0, (-angZ) % 360)
        end
        bombs[#bombs+1] = b
    end
end

local function hydraCanFire()
    if active then return false end
    local okIn, inCar = pcall(isCharInAnyCar, PLAYER_PED)
    if not okIn or not inCar then return false end
    local okC, car = pcall(storeCarCharIsInNoSave, PLAYER_PED)
    if not okC or not car then return false end
    local okM, m = pcall(getCarModel, car)
    return okM and m == HYDRA_MODEL
end

local function hydraEmulatedFire()
    local now = os.clock()
    local w = hydraWeapon()
    if now - hydra.lastEmu < (w.cd or 0.45) then return end
    local okC, car = pcall(storeCarCharIsInNoSave, PLAYER_PED)
    if not okC or not car then return end
    local okP, x, y, z = pcall(getCarCoordinates, car)
    local okH, h = pcall(getCarHeading, car)
    if not (okP and okH and type(x) == 'number' and type(h) == 'number') then return end
    hydra.lastEmu = now
    muzzle = 0.06
    sndPlayAt(snd.fire, x, y, z)
    local hd = math.rad(h)
    local dx, dy = -math.sin(hd), math.cos(hd)
    local v = w.speed or 85
    for _ = 1, (w.burst or 1) do
        local sp = w.spread or 0
        local ex = dx + (math.random()-0.5)*2*sp
        local ey = dy + (math.random()-0.5)*2*sp
        local b = { x = x + dx*7, y = y + dy*7, z = z + 0.2,
                    vx = ex*v, vy = ey*v, vz = (math.random()-0.5)*2*sp*v,
                    g = 2.5, t = 0, life = w.life or 3.0, rocket = true,
                    expl = w.expl or 2 }
        if type(requestModel) == 'function' then
            pcall(requestModel, w.model or ROCKET_MODEL)
            pcall(loadAllModelsNow)
        end
        local okO, obj = pcall(createObject, w.model or ROCKET_MODEL, b.x, b.y, b.z)
        if okO and obj and obj ~= -1 then
            b.obj = obj
            pcall(setObjectCollision, obj, false)
            pcall(setObjectRotation, obj, 0, 0, (-math.deg(math.atan2(dx, dy))) % 360)
        end
        bombs[#bombs+1] = b
    end
end

local function readStick()
    if os.clock() < uiStickMute then return 0, 0 end
    local inCar = isCharInAnyCar(PLAYER_PED)
    local wid = inCar and WIDGET_VEHICLE_STEER_ANALOG or WIDGET_PED_MOVE
    if wid == nil then wid = inCar and WIDGET_PED_MOVE or WIDGET_VEHICLE_STEER_ANALOG end
    local x, y = 0, 0
    if wid ~= nil then
        local ok, rx, ry = isWidgetPressedEx(wid, 0)
        if ok and type(rx) == 'number' and type(ry) == 'number' then
            x, y = rx / 127.0, ry / 127.0
        end
    end
    local mag = math.sqrt(x*x + y*y)
    if mag < JOY_DEADZONE then return 0, 0 end
    local scale = math.min(1, (mag - JOY_DEADZONE) / (1 - JOY_DEADZONE)) / mag
    x, y = x * scale, y * scale
    if C.invertY then y = -y end
    return x, y
end

local function applyFov()

    if type(cameraSetLerpFov) == 'function' then
        pcall(cameraSetLerpFov, curFov, curFov, 0, false)
    end
end
local function resetFov()
    if type(cameraResetNewFov) == 'function' then pcall(cameraResetNewFov) end
end

local function camUpdate(dt)
    dt = dt or 0.016

    if orbit.active and orbit.veh and doesVehicleExist(orbit.veh) then
        local ok, vx, vy, vz = pcall(getCarCoordinates, orbit.veh)
        if ok and type(vx) == 'number' then
            local r = C.orbitRadius
            camX = vx + math.sin(orbit.angle) * r
            camY = vy + math.cos(orbit.angle) * r
            camZ = vz + C.orbitAlt
            setFixedCameraPosition(camX, camY, camZ, 0, 0, 0)
            if orbit.look then
                pointCameraAtPoint(vx, vy, vz + 1.2, 2)
            else
                local dx, dy = fwdVec(angZ)
                local rY = math.rad(angY)
                local ld = 8
                pointCameraAtPoint(
                    camX + dx*math.cos(rY)*ld, camY + dy*math.cos(rY)*ld,
                    camZ + math.sin(rY)*ld, 2)
            end
            return
        end
        orbitStop()
    end

    if cine.active and cine.veh and doesVehicleExist(cine.veh) then
        local ok, vx, vy, vz = pcall(getCarCoordinates, cine.veh)
        if ok and type(vx) == 'number' then
            local R = C.orbitRadius
            local e = cine.t * cine.t * (3 - 2*cine.t)
            local hd = 0
            local okH, h = pcall(getCarHeading, cine.veh)
            if okH and type(h) == 'number' then hd = math.rad(h) end
            local ax, ay = -math.sin(hd), math.cos(hd)
            local rx, ry =  math.cos(hd), math.sin(hd)
            local cx, cy, cz
            local lx, ly, lz = vx, vy, vz + 1.0
            if cine.mode == 'dolly' then
                local dist = R*1.8 + (math.max(4, R*0.4) - R*1.8) * e
                cx = vx + math.sin(cine.baseAng)*dist
                cy = vy + math.cos(cine.baseAng)*dist
                cz = vz + C.orbitAlt
            elseif cine.mode == 'crane' then
                cx = vx + math.sin(cine.baseAng)*R
                cy = vy + math.cos(cine.baseAng)*R
                cz = (vz+1.5) + ((vz+C.orbitAlt+12) - (vz+1.5)) * e
            elseif cine.mode == 'spiral' then
                cx = vx + math.sin(cine.angle)*R
                cy = vy + math.cos(cine.angle)*R
                cz = (vz+2.0) + ((vz+C.orbitAlt+14) - (vz+2.0)) * e
            elseif cine.mode == 'front' or cine.mode == 'rear' then
                local s    = (cine.mode == 'front') and 1 or -1
                local dist = R*1.6 + (math.max(2.5, R*0.18) - R*1.6) * e
                local altH = vz + math.max(2.0, C.orbitAlt*0.7)
                cx = vx + s*ax*dist
                cy = vy + s*ay*dist
                cz = altH + ((vz+0.7) - altH) * e
                lx, ly, lz = vx + s*ax*1.2, vy + s*ay*1.2, vz + 0.6
            else
                local p = cine.t*2 - 1
                cx = vx + ax*(p*R*2.0) + rx*(R*0.8)
                cy = vy + ay*(p*R*2.0) + ry*(R*0.8)
                cz = vz + math.max(1.5, C.orbitAlt*0.5)
                lz = vz + 0.8
            end
            camX, camY, camZ = cx, cy, cz
            setFixedCameraPosition(cx, cy, cz, 0, 0, 0)
            pointCameraAtPoint(lx, ly, lz, 2)
            return
        end
        cineStop()
    end

    if trackMode then
        local tx, ty, tz = nil, nil, nil
        if trackVeh and doesVehicleExist(trackVeh) then
            local ok, x, y, z = pcall(getCarCoordinates, trackVeh)
            if ok and type(x) == 'number' then tx, ty, tz = x, y, z + 0.7 end
        elseif trackPed and doesCharExist(trackPed) then
            local ok, x, y, z = pcall(getCharCoordinates, trackPed)
            if ok and type(x) == 'number' then tx, ty, tz = x, y, z + 0.85 end
        else
            trackMode = false
        end
        if tx then
            local k = smoothK(6, dt)
            local dx, dy = fwdVec(angZ)
            camX = camX + (tx - dx*zoomDist - camX) * k
            camY = camY + (ty - dy*zoomDist - camY) * k
            camZ = camZ + (tz - 1 + 10 + trackHeightOffset - camZ) * k
            setFixedCameraPosition(camX, camY, camZ, 0, 0, 0)
            pointCameraAtPoint(tx, ty, tz + math.tan(math.rad(angY)) * zoomDist, 2)
            return
        end
    end

    local rZ, rY = math.rad(angZ), math.rad(angY)
    local dx = math.sin(rZ) * math.cos(rY)
    local dy = math.cos(rZ) * math.cos(rY)
    local dz = math.sin(rY)
    local ox, oy, oz = shakeOffset()
    if C.camView == 2 then

        local nose = hydraMode and 7.5 or (body and 1.4 or 0.2)
        setFixedCameraPosition(camX + dx*nose + ox, camY + dy*nose + oy, camZ + dz*nose + oz, 0, 0, 0)
        pointCameraAtPoint(camX + dx*15, camY + dy*15, camZ + dz*15, 2)
    else

        setFixedCameraPosition(camX - dx*zoomDist + ox, camY - dy*zoomDist + oy, camZ - dz*zoomDist + oz, 0, 0, 0)
        pointCameraAtPoint(camX, camY, camZ, 2)
    end
end

local function droneOn()
    if active then return end
    local inCar = isCharInAnyCar(PLAYER_PED)
    sX, sY, sZ = getCharCoordinates(PLAYER_PED)
    sAngle     = getCharHeading(PLAYER_PED)
    local okH, hp = pcall(getCharHealth, PLAYER_PED); sHp = okH and hp or 100
    curFov, zoomDist = C.fov, C.zoomDist
    joy.x, joy.y = 0, 0
    vel.x, vel.y, vel.z = 0, 0, 0
    local rad = math.rad(sAngle)
    local aimDist = math.min(zoomDist * 0.5, 8)
    camX = sX + math.sin(rad)*aimDist
    camY = sY + math.cos(rad)*aimDist
    camZ = sZ + 3
    angZ, angY = sAngle, -10

    body = nil
    if hydraMode then
        body = createDroneUnit(HYDRA_MODEL, camX, camY, camZ)
        if not body then chat('Модель Hydra не создалась — имитация без корпуса') end
    end
    for i, u in ipairs(spawnedDrones) do
        if hydraMode then break end
        if unitExists(u) then
            local ux, uy, uz = unitGetPos(u)
            if ux and getDistanceBetweenCoords3d(ux, uy, uz, sX, sY, sZ) < 10 then
                body = u
                body.adopted = true
                table.remove(spawnedDrones, i)
                camX, camY, camZ = ux, uy, uz + 1.5
                chat('Взлёт на '..modelName(u.model))
                break
            end
        end
    end
    if not body and not hydraMode then
        local m = DRONE_MODELS[C.droneModel or 1]
        if m and m.id then
            body = createDroneUnit(m.id, camX, camY, camZ)
            if not body then
                chat('Модель '..m.name..' недоступна в этой сборке — лечу без корпуса')
            end
        end
    end
    if not inCar then

        local ok2, fp = pcall(createChar, 0, getCharModel(PLAYER_PED), sX, sY, sZ - 0.5)
        if ok2 and fp then
            fakeNpc = fp
            pcall(setCharProofs,    fp, true, true, true, true, true)
            pcall(setCharCollision, fp, false)
            pcall(setCharVisible,   fp, false)
        end
        pcall(freezeCharPosition, PLAYER_PED, true)
    else
        chat('Запуск из транспорта: стик управляет дроном, руль отключён')
    end
    setFixedCameraPosition(camX, camY, camZ, 0, 0, 0)
    camUpdate()
    applyFov()
    displayRadar(false)
    recStart = os.clock()
    active = true
    sndInit()
    sndStartHum(hydraMode and 'jet' or 'drone')
    chat('Дрон включён  |  /dmenu  |  /dbomb  |  /dfly')
end

local function droneOff()
    if not active then return end
    active = false
    sndStopHum()
    trackMode, trackVeh, trackPed, trackHeightOffset = false, nil, nil, 0
    for k in pairs(hold) do hold[k] = false end
    autopilotOff(); orbitStop(); cineStop()
    homing.active = false
    hoverTarget = nil
    bombsClear()

    if body then
        if body.adopted and unitExists(body) then
            local gz = camZ - 1
            local okG, g = pcall(getGroundZFor3dCoord, camX, camY, camZ)
            if okG and type(g) == 'number' then gz = g end
            unitSetPos(body, camX, camY, gz + 0.8, angZ, 0)
            spawnedDrones[#spawnedDrones+1] = body
            chat(modelName(body.model)..' посажен')
        else
            unitDelete(body)
        end
        body = nil
    end
    hydraMode = false
    hydra.fireHeld = false
    restoreCameraJumpcut()
    setCameraBehindPlayer()
    resetFov()
    displayRadar(true)
    pcall(freezeCharPosition, PLAYER_PED, false)
    if not isCharInAnyCar(PLAYER_PED) then
        pcall(setCharCoordinates, PLAYER_PED, sX, sY, sZ)
        pcall(setCharHeading,     PLAYER_PED, sAngle)
    end
    pcall(setCharHealth, PLAYER_PED, sHp)
    if fakeNpc and doesCharExist(fakeNpc) then pcall(deleteChar, fakeNpc) end
    fakeNpc = nil
    chat('Дрон выключен')
end

if ok_ev then
    function sampev.onSendPlayerSync(data)
        if active then
            data.position = { x = sX, y = sY, z = sZ }
            if data.moveSpeed then
                data.moveSpeed.x = 0.001; data.moveSpeed.y = 0; data.moveSpeed.z = 0
            end
            data.leftRightKeys = 0; data.upDownKeys = 0
        end
    end
end

local function simulate(dt)

    setGameKeyState(0, 0); setGameKeyState(1, 0)

    local inCar = isCharInAnyCar(PLAYER_PED)

    local rawX, rawY = readStick()
    local kIn = smoothK(INPUT_SMOOTH, dt)
    joy.x = joy.x + (rawX - joy.x) * kIn
    joy.y = joy.y + (rawY - joy.y) * kIn

    if not inCar and WIDGET_ACCELERATE ~= nil and isWidgetPressed(WIDGET_ACCELERATE) then
        joy.y = math.min(joy.y, -0.8)
    end

    local MOVE_SPD = C.sFwd  * 0.18
    if hydraMode then MOVE_SPD = MOVE_SPD * 2.5 end
    local TURN_SPD = C.sTurn * 7.2
    local AUTO_SPD = C.autoSpeed * 0.12

    if hydraMode and hydra.fireHeld then simHydraFire() end

    if cine.active then
        local dur = math.max(1, C.cineDur)
        cine.t = cine.t + cine.dir * (dt / dur)
        if     cine.t >= 1 then cine.t, cine.dir = 1, -1
        elseif cine.t <= 0 then cine.t, cine.dir = 0,  1 end
        if cine.mode == 'spiral' then
            cine.angle = cine.angle + math.rad(C.orbitSpeed) * dt
        end
    elseif orbit.active then
        if math.abs(joy.x) > 0.05 then
            orbit.angle = orbit.angle + joy.x * math.rad(C.orbitSpeed) * 3 * dt
        else
            orbit.angle = orbit.angle + math.rad(C.orbitSpeed) * dt * orbit.dir
        end
    end

    local tvx, tvy, tvz = 0, 0, 0
    local freeFlight = not (orbit.active or cine.active or trackMode)

    if freeFlight and homing.active then

        local tx, ty, tz = homingTargetPos()
        if not tx then
            homing.active = false
            chat('Наведение: цель потеряна')
        else

            local now = os.clock()
            if homing.lpx and now > homing.lt then
                local d = now - homing.lt
                if d > 0.01 then
                    homing.tvx = clamp((tx - homing.lpx) / d, -40, 40)
                    homing.tvy = clamp((ty - homing.lpy) / d, -40, 40)
                    homing.tvz = clamp((tz - homing.lpz) / d, -20, 20)
                end
            end
            homing.lpx, homing.lpy, homing.lpz, homing.lt = tx, ty, tz, now

            local dx, dy = tx - camX, ty - camY
            local dist2d = math.sqrt(dx*dx + dy*dy)
            local nx = (dist2d > 0.1) and (dx/dist2d) or 0
            local ny = (dist2d > 0.1) and (dy/dist2d) or 0

            local bearing = math.deg(math.atan2(dx, dy))
            local diff    = angDiff(angZ, bearing)
            local maxTurn = TURN_SPD * dt
            angZ = (angZ + clamp(diff, -maxTurn, maxTurn)) % 360

            local standoff = math.max(4, C.homingDist)
            local err = dist2d - standoff

            local approach
            if math.abs(err) < 1.5 then approach = 0
            else approach = clamp(err * 0.6, -MOVE_SPD*0.8, MOVE_SPD*0.8) end

            tvx = nx * approach + homing.tvx
            tvy = ny * approach + homing.tvy

            if homing.attack and C.autoStrike then
                homing.fireT = (homing.fireT or 0) - dt
                if homing.fireT <= 0 then
                    homing.fireT = 1.3
                    bombDrop(tx, ty, tz)
                end
            end

            local wantZ = tz + C.orbitAlt
            tvz = clamp((wantZ - camZ) * 0.8, -MOVE_SPD, MOVE_SPD) + homing.tvz

            local dz = (tz + 1.0) - camZ
            local wantPitch = math.deg(math.atan2(dz, math.max(dist2d, 1)))
            angY = angY + angDiff(angY, wantPitch) * smoothK(4, dt)
        end
    elseif freeFlight and autopilotActive() then

        local fx, fy = fwdVec(angZ)
        local rx, ry = rightVec(angZ)
        if autopilot.fwd   then tvx, tvy = tvx + fx*AUTO_SPD, tvy + fy*AUTO_SPD end
        if autopilot.back  then tvx, tvy = tvx - fx*AUTO_SPD, tvy - fy*AUTO_SPD end
        if autopilot.left  then tvx, tvy = tvx - rx*AUTO_SPD, tvy - ry*AUTO_SPD end
        if autopilot.right then tvx, tvy = tvx + rx*AUTO_SPD, tvy + ry*AUTO_SPD end
        if autopilot.up    then tvz = tvz + AUTO_SPD end
        if autopilot.down  then tvz = tvz - AUTO_SPD end
    elseif freeFlight then

        if C.joyMode == 2 then

            angZ = (angZ + joy.x * TURN_SPD * dt) % 360
            local fx, fy = fwdVec(angZ)
            tvx, tvy = fx * (-joy.y) * MOVE_SPD, fy * (-joy.y) * MOVE_SPD
        else

            local fx, fy = fwdVec(angZ)
            local rx, ry = rightVec(angZ)
            tvx = (fx * (-joy.y) + rx * joy.x) * MOVE_SPD
            tvy = (fy * (-joy.y) + ry * joy.x) * MOVE_SPD
        end
    end

    if trackMode and not (orbit.active or cine.active) then
        angZ = (angZ + joy.x * TURN_SPD * dt) % 360
        zoomDist = clamp(zoomDist + joy.y * math.max(10, MOVE_SPD) * dt, 3, 80)
    end

    if not (orbit.active or cine.active or homing.active) then
        if hold.yl then angZ = (angZ - TURN_SPD * dt) % 360 end
        if hold.yr then angZ = (angZ + TURN_SPD * dt) % 360 end
    end
    if hold.au then
        if trackMode then trackHeightOffset = trackHeightOffset + MOVE_SPD * dt
        else tvz = tvz + MOVE_SPD end
    end
    if hold.ad then
        if trackMode then trackHeightOffset = trackHeightOffset - MOVE_SPD * dt
        else tvz = tvz - MOVE_SPD end
    end
    if not (orbit.active and orbit.look) and not cine.active and not homing.active then
        if hold.cu then angY = clamp(angY - 72 * dt, -85, 85) end
        if hold.cd then angY = clamp(angY + 72 * dt, -85, 85) end
    end

    if freeFlight then
        local kV = smoothK(ACCEL, dt)
        vel.x = vel.x + (tvx - vel.x) * kV
        vel.y = vel.y + (tvy - vel.y) * kV
        vel.z = vel.z + (tvz - vel.z) * kV
        camX = camX + vel.x * dt
        camY = camY + vel.y * dt
        camZ = camZ + vel.z * dt
    else
        vel.x, vel.y, vel.z = 0, 0, 0
    end

    bombsUpdate(dt)
    autoBombUpdate(dt)

    if body then
        if unitExists(body) then
            local hspd = math.sqrt(vel.x^2 + vel.y^2)
            local drop = hydraMode and 1.0 or 1.5
            unitSetPos(body, camX, camY, camZ - drop, angZ, -clamp(hspd * 1.5, 0, 20))
        else
            body = nil
        end
    end

    camAlt  = math.floor(camZ - sZ)
    camDist = math.floor(getDistanceBetweenCoords2d(camX, camY, sX, sY))
    camSpd  = math.floor(math.sqrt(vel.x^2 + vel.y^2 + vel.z^2) * 3.6)

    sndUpdateHum(camX, camY, camZ, camSpd / (hydraMode and 200 or 90))
    camUpdate(dt)
end

local fL, fM, fS
local function initF()
    if fS then return end

    local ok1, f1 = pcall(renderCreateFont, 'Arial', 15, 5)
    local ok2, f2 = pcall(renderCreateFont, 'Arial', 12, 5)
    local ok3, f3 = pcall(renderCreateFont, 'Arial', 9,  5)
    if ok1 then fL = f1 end
    if ok2 then fM = f2 end
    if ok3 then fS = f3 end
end
local function ts(f, t, x, y, c)
    renderFontDrawText(f, t, x+1, y+1, 0xBB000000)
    renderFontDrawText(f, t, x,   y,   c)
end
local function fmtT(s)
    s = math.max(0, math.floor(s))
    return string.format('%02d:%02d:%02d', math.floor(s/3600), math.floor((s%3600)/60), s%60)
end

local drawAviationHUD

local function drawBracket(x, y, r, w, col, cross)
    local cr = r * 0.45
    renderDrawLine(x-r, y-r, x-r+cr, y-r, w, col)
    renderDrawLine(x-r, y-r, x-r, y-r+cr, w, col)
    renderDrawLine(x+r, y-r, x+r-cr, y-r, w, col)
    renderDrawLine(x+r, y-r, x+r, y-r+cr, w, col)
    renderDrawLine(x-r, y+r, x-r+cr, y+r, w, col)
    renderDrawLine(x-r, y+r, x-r, y+r-cr, w, col)
    renderDrawLine(x+r, y+r, x+r-cr, y+r, w, col)
    renderDrawLine(x+r, y+r, x+r, y+r-cr, w, col)
    if cross then
        renderDrawLine(x-3*MDS, y, x+3*MDS, y, 1.5, col)
        renderDrawLine(x, y-3*MDS, x, y+3*MDS, 1.5, col)
    end
end

local function drawChip(text, x, y, col, alpha)
    local w = renderGetFontDrawTextLength(fM, text)
    renderDrawBox(x - w - 10*MDS, y - 2*MDS, w + 8*MDS, 16*MDS, 0x66000000)
    ts(fM, text, x - w - 6*MDS, y, math.floor(alpha)*0x1000000 + (col % 0x1000000))
    return y + 18*MDS
end

local function pedNameCP(ped)
    local okId, res, pid = pcall(sampGetPlayerIdByCharHandle, ped)
    if okId and res then
        local okN, n = pcall(sampGetPlayerNickname, pid)
        if okN and n and n ~= '' then return n, true end
    end
    return 'NPC', false
end

local function vehNameCP(veh)
    local okD, drv = pcall(getDriverOfCar, veh)
    if okD and drv and drv ~= -1 and doesCharExist(drv) then
        local nm, isPlayer = pedNameCP(drv)
        if isPlayer then return nm, true end
    end
    local okM, m = pcall(getCarModel, veh)
    return 'VEH '..(okM and tostring(m) or '?'), false
end

local function resolveTargetInfo()
    local kind, h
    if trackPed and doesCharExist(trackPed) then kind, h = 'ped', trackPed
    elseif trackVeh and doesVehicleExist(trackVeh) then kind, h = 'veh', trackVeh
    elseif orbitTarget and doesVehicleExist(orbitTarget) then kind, h = 'veh', orbitTarget
    else return nil end
    local ok, x, y, z, name, kindLbl, spd
    if kind == 'veh' then
        ok, x, y, z = pcall(getCarCoordinates, h)
        if not (ok and type(x) == 'number') then return nil end
        local nm, isDriver = vehNameCP(h)
        name, kindLbl = nm, (isDriver and 'DRIVER' or 'VEHICLE')
        local okS, s = pcall(getCarSpeed, h)
        spd = (okS and type(s) == 'number') and math.floor(s) or 0
    else
        ok, x, y, z = pcall(getCharCoordinates, h)
        if not (ok and type(x) == 'number') then return nil end
        local nm, isPlayer = pedNameCP(h)
        name, kindLbl, spd = nm, (isPlayer and 'PLAYER' or 'NPC'), 0
    end
    return {
        kind = kind, handle = h, x = x, y = y, z = z,
        name = name, kindLbl = kindLbl, spd = spd,
        dist = math.floor(getDistanceBetweenCoords3d(camX, camY, camZ, x, y, z)),
    }
end

local function drawHUD()
    if not fS then initF(); return end
    local elapsed = os.clock() - recStart
    recBlink = recBlink + 0.05
    local blink = math.abs(math.sin(recBlink * 2.5))
    local RL, RT, RR, RB = C.fL, C.fT, C.fR, C.fB
    local cx, cy = (RL+RR)/2, (RT+RB)/2

    local axp, ayp = sw/2, sh/2

    hoverTarget = nil
    local hoverR2 = (36*MDS)^2
    do
        local okA, allV = pcall(getAllVehicles)
        if okA and allV then
            for _, vh in ipairs(allV) do
                local isBody = body and body.kind == 'car' and body.handle == vh
                if doesVehicleExist(vh) and not isBody then
                    local okC, vx, vy, vz = pcall(getCarCoordinates, vh)
                    if okC and type(vx) == 'number' then
                        local dd = getDistanceBetweenCoords3d(camX, camY, camZ, vx, vy, vz)
                        if dd < 100 then
                            local okS, sx, sy = pcall(convert3DCoordsToScreen, vx, vy, vz)
                            if okS and sx and sx > RL and sx < RR and sy > RT and sy < RB then

                                local d2 = (sx-axp)^2 + (sy-ayp)^2
                                if d2 < hoverR2 and vh ~= trackVeh then
                                    hoverR2 = d2
                                    hoverTarget = { kind='veh', handle=vh, sx=sx, sy=sy, dist=math.floor(dd) }
                                end
                                if C.showCarBox and not trackMode and dd < 80 then
                                    local okT, _, syT = pcall(convert3DCoordsToScreen, vx, vy, vz + 2.5)
                                    local boxH = okT and syT and math.abs(sy - syT) or 18*MDS
                                    local vr = clamp(boxH * 0.6, 8*MDS, 30*MDS)
                                    if vh == orbitTarget then
                                        drawBracket(sx, sy, vr, 2.5, 0xFFFF8800, true)
                                        ts(fS, 'TARGET', sx - renderGetFontDrawTextLength(fS,'TARGET')/2,
                                            sy - vr - 13*MDS, 0xFFFF8800)
                                    else
                                        local al = math.floor((1 - dd/80) * 130) + 20
                                        local vc = al*0x1000000 + 0x0000D9FF
                                        renderDrawLine(sx-vr, sy-vr, sx+vr, sy-vr, 1.2, vc)
                                        renderDrawLine(sx+vr, sy-vr, sx+vr, sy+vr, 1.2, vc)
                                        renderDrawLine(sx+vr, sy+vr, sx-vr, sy+vr, 1.2, vc)
                                        renderDrawLine(sx-vr, sy+vr, sx-vr, sy-vr, 1.2, vc)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local okP, allP = pcall(getAllChars)
        if okP and allP then
            for _, ped in ipairs(allP) do
                if doesCharExist(ped) and ped ~= PLAYER_PED and ped ~= fakeNpc and ped ~= trackPed then
                    local okC, px2, py2, pz2 = pcall(getCharCoordinates, ped)
                    if okC and type(px2) == 'number' then
                        local dd = getDistanceBetweenCoords3d(camX, camY, camZ, px2, py2, pz2)
                        if dd < 80 then
                            local okS, sx, sy = pcall(convert3DCoordsToScreen, px2, py2, pz2 + 0.5)
                            if okS and sx and sx > RL and sx < RR and sy > RT and sy < RB then
                                local d2 = (sx-axp)^2 + (sy-ayp)^2
                                if d2 < hoverR2 then
                                    hoverR2 = d2
                                    hoverTarget = { kind='ped', handle=ped, sx=sx, sy=sy, dist=math.floor(dd) }
                                end
                            end
                        end
                    end
                end
            end
        end
        if hoverTarget then

            if hoverTarget.kind == 'ped' then
                local nm = pedNameCP(hoverTarget.handle)
                hoverTarget.name  = nm
                hoverTarget.uname = monet_cp1251_to_utf8(nm)
            else
                local nm = vehNameCP(hoverTarget.handle)
                hoverTarget.name  = nm
                hoverTarget.uname = monet_cp1251_to_utf8(nm)
            end

            local hp = math.abs(math.sin(recBlink*4))*0.5 + 0.5
            local hc = math.floor(hp*255)*0x1000000 + 0x0088FF00
            drawBracket(hoverTarget.sx, hoverTarget.sy, 16*MDS, 2.2, hc, false)
            ts(fS, hoverTarget.name,
                hoverTarget.sx - renderGetFontDrawTextLength(fS, hoverTarget.name)/2,
                hoverTarget.sy - 16*MDS - 13*MDS, 0xFF88FF00)
            ts(fS, 'LOCK >', hoverTarget.sx + 18*MDS, hoverTarget.sy + 8*MDS, 0xCC88FF00)
        end
    end

    if C.showCarBox and trackMode then
        local tx, ty, tz, lbl, col
        if trackVeh and doesVehicleExist(trackVeh) then
            local ok, x, y, z = pcall(getCarCoordinates, trackVeh)
            if ok and type(x)=='number' then
                tx, ty, tz = x, y, z
                lbl, col = vehNameCP(trackVeh), 0xFFFF8822
            end
        elseif trackPed and doesCharExist(trackPed) then
            local ok, x, y, z = pcall(getCharCoordinates, trackPed)
            if ok and type(x)=='number' then
                tx, ty, tz = x, y, z + 0.9
                lbl, col = pedNameCP(trackPed), 0xFF00CCFF
            end
        end
        if tx then
            local okS, sx, sy = pcall(convert3DCoordsToScreen, tx, ty, tz)
            if okS and sx then
                local pb = math.abs(math.sin(recBlink*3))*0.7 + 0.3
                local pc = math.floor(pb*255)*0x1000000 + (col % 0x1000000)
                drawBracket(sx, sy, 18*MDS, 2.5, pc, true)
                ts(fS, lbl, sx - renderGetFontDrawTextLength(fS,lbl)/2, sy - 18*MDS - 14*MDS, col)
            end
        end
    end

    local ti = resolveTargetInfo()
    if ti then
        local pX, pY = RL + 4*MDS, RT + 26*MDS
        renderDrawBox(pX, pY, 156*MDS, 48*MDS, 0x66000000)
        renderDrawLine(pX + 1.5*MDS, pY, pX + 1.5*MDS, pY + 48*MDS, 3*MDS, 0xFFFF8800)
        ts(fM, ti.name, pX + 8*MDS, pY + 3*MDS, 0xFFFFAA00)
        ts(fS, string.format('%s  DST %dm', ti.kindLbl, ti.dist), pX + 8*MDS, pY + 21*MDS, 0xCCFFFFFF)
        ts(fS, (homing.active and (homing.attack and 'ATTACK' or 'FOLLOW')
                or (trackMode and 'TRACKING' or 'SELECTED'))
            ..(ti.spd > 0 and ('  SPD '..ti.spd) or ''), pX + 8*MDS, pY + 33*MDS, 0x9900D9FF)

        local okS, sx, sy = pcall(convert3DCoordsToScreen, ti.x, ti.y, ti.z)
        if okS and sx then
            local ox, oy = sx - axp, sy - ayp
            local olen = math.sqrt(ox*ox + oy*oy)
            if olen > 60*MDS then
                local nx, ny = ox/olen, oy/olen
                renderDrawLine(axp + nx*16*MDS, ayp + ny*16*MDS,
                               axp + nx*34*MDS, ayp + ny*34*MDS, 2, 0xCCFF8800)
                renderDrawLine(axp + nx*34*MDS, ayp + ny*34*MDS,
                               axp + nx*28*MDS - ny*4*MDS, ayp + ny*28*MDS + nx*4*MDS, 2, 0xCCFF8800)
                renderDrawLine(axp + nx*34*MDS, ayp + ny*34*MDS,
                               axp + nx*28*MDS + ny*4*MDS, ayp + ny*28*MDS - nx*4*MDS, 2, 0xCCFF8800)
            end
        end
    end

    for _, b in ipairs(bombs) do
        local okS, sx, sy = pcall(convert3DCoordsToScreen, b.x, b.y, b.z)
        if okS and sx and sx > RL and sx < RR and sy > RT and sy < RB then
            local r = 5*MDS
            renderDrawLine(sx-r, sy, sx, sy-r, 2, 0xFFFFCC00)
            renderDrawLine(sx, sy-r, sx+r, sy, 2, 0xFFFFCC00)
            renderDrawLine(sx+r, sy, sx, sy+r, 2, 0xFFFFCC00)
            renderDrawLine(sx, sy+r, sx-r, sy, 2, 0xFFFFCC00)
            if b.groundZ then
                local okG, gx, gy = pcall(convert3DCoordsToScreen, b.x, b.y, b.groundZ)
                if okG and gx then
                    renderDrawLine(sx, sy, gx, gy, 1, 0x66FFCC00)
                    renderDrawLine(gx-4*MDS, gy, gx+4*MDS, gy, 1.5, 0xAAFF4400)
                end
            end
        end
    end

    for _, tr in ipairs(trails) do
        local okS, sx, sy = pcall(convert3DCoordsToScreen, tr.x, tr.y, tr.z)
        if okS and sx then
            local p  = tr.t / 1.2
            local al = math.floor((1 - p) * 150)
            local sz = (1.5 + p * 5) * MDS
            renderDrawBox(sx - sz/2, sy - sz/2, sz, sz, al*0x1000000 + 0x00999999)
        end
    end

    for _, sp in ipairs(sparks) do
        local okS, sx, sy = pcall(convert3DCoordsToScreen, sp.x, sp.y, sp.z)
        if okS and sx then
            local p  = sp.t / sp.life
            local al = math.floor((1 - p) * 255)
            local sz = (sp.big and 6 or 3) * MDS
            local cc = sp.col % 0x1000000

            renderDrawBox(sx - sz, sy - sz, sz*2, sz*2, math.floor(al*0.35)*0x1000000 + cc)
            renderDrawBox(sx - sz/2, sy - sz/2, sz, sz, al*0x1000000 + cc)
        end
    end

    for _, im in ipairs(impacts) do
        local age = os.clock() - im.t
        if im.nuke then

            local p    = age / 9.0
            local topZ = im.z + p * 55

            for k = 0, 9 do
                local zz = im.z + (k/9) * (topZ - im.z)
                local okS, sx, sy = pcall(convert3DCoordsToScreen, im.x, im.y, zz)
                if okS and sx then
                    local sz  = (18 + p*40 + k*3) * MDS
                    local al  = math.floor((1 - p) * 175)
                    local col = (k < 3) and 0x00FF5500 or 0x00999090
                    renderDrawBox(sx - sz/2, sy - sz/2, sz, sz, al*0x1000000 + col)
                end
            end

            for j = 0, 11 do
                local a  = j/11 * math.pi*2
                local rr = 10 + p*26
                local okS, sx, sy = pcall(convert3DCoordsToScreen,
                    im.x + math.cos(a)*rr, im.y + math.sin(a)*rr, topZ)
                if okS and sx then
                    local sz = (28 + p*70) * MDS
                    local al = math.floor((1 - p) * 160)
                    renderDrawBox(sx - sz/2, sy - sz/2, sz, sz, al*0x1000000 + 0x00A09890)
                end
            end

            if p < 0.14 then
                local okF, fx, fy = pcall(convert3DCoordsToScreen, im.x, im.y, im.z + 3)
                if okF and fx then
                    local fsz = (80 + p*400) * MDS
                    renderDrawBox(fx - fsz/2, fy - fsz/2, fsz, fsz,
                        math.floor((1 - p/0.14) * 245)*0x1000000 + 0x00FFFFDD)
                end
            end
        elseif im.smoke then

            local p = age / 7.0
            for k = 0, 10 do
                local rise = p * 12 + k * 1.1
                local spread = (1.5 + p*4)
                local okS, sx, sy = pcall(convert3DCoordsToScreen,
                    im.x + math.sin(k*1.3 + p*3)*spread, im.y + math.cos(k*2.1 + p*2)*spread,
                    im.z + rise)
                if okS and sx then
                    local sz = (22 + p*95 + k*4) * MDS
                    local al = math.floor((1 - p) * 150)
                    local g  = 0x00999999 - k*0x00050505
                    renderDrawBox(sx - sz/2, sy - sz/2, sz, sz, al*0x1000000 + (g % 0x1000000))
                end
            end
        else

            local p = age / 1.4
            local okS, sx, sy = pcall(convert3DCoordsToScreen, im.x, im.y, im.z)
            if okS and sx then
                if p < 0.18 then
                    local fsz = (10 + p*120) * MDS * (im.r or 1)
                    local fa2 = math.floor((1 - p/0.18) * 235)
                    renderDrawBox(sx - fsz/2, sy - fsz/2, fsz, fsz, fa2*0x1000000 + 0x00FFEE88)
                end
                local r   = (6 + p * 46) * MDS * (im.r or 1)
                local al  = math.floor((1 - p) * 220)
                local col = al*0x1000000 + 0x00FF5500
                local seg = 14
                for i = 1, seg do
                    local a1 = (i-1)/seg * math.pi*2
                    local a2 =  i   /seg * math.pi*2
                    renderDrawLine(sx+math.cos(a1)*r, sy+math.sin(a1)*r,
                                   sx+math.cos(a2)*r, sy+math.sin(a2)*r, 2, col)
                end
            end
        end
    end

    if muzzle > 0 and hydraMode then
        local fp = muzzle / 0.06
        local msz = (14 + fp*22) * MDS
        renderDrawBox(sw/2 - msz/2, sh/2 - msz/2, msz, msz,
            math.floor(fp*220)*0x1000000 + 0x00FFDD66)
    end

    if C.showCross and not hydraMode then
        local col = trackMode and 0xFFFF8800
            or (orbit.active and 0xFFAA88FF)
            or (homing.active and 0xFFFFCC00)
            or 0xFF00D9FF
        local r2, gap = 11*MDS, 4*MDS
        renderDrawLine(axp-r2,  ayp, axp-gap, ayp, 2, col)
        renderDrawLine(axp+gap, ayp, axp+r2,  ayp, 2, col)
        renderDrawLine(axp, ayp-r2,  axp, ayp-gap, 2, col)
        renderDrawLine(axp, ayp+gap, axp, ayp+r2,  2, col)
        renderDrawLine(axp-1.5*MDS, ayp, axp+1.5*MDS, ayp, 1.5, col)
        renderDrawLine(axp, ayp-1.5*MDS, axp, ayp+1.5*MDS, 1.5, col)
    end

    if hydraMode then
        local agl = 0
        local okG, g = pcall(getGroundZFor3dCoord, camX, camY, camZ)
        if okG and type(g) == 'number' then agl = math.floor(camZ - g) end
        drawAviationHUD(camSpd, math.floor(camZ), agl, math.floor(angZ % 360), 1,
            'HYDRA // SIM', 'IMITATION - ONLY YOU SEE IT')
        ts(fS, 'REC '..fmtT(elapsed), sw*0.06, sh*0.12 + 30*MDS, 0x9966FF44)
        return
    end

    if not C.showFrame then return end
    local CC, CLen = 0xEEFFFFFF, 22*MDS
    renderDrawLine(RL, RT, RR, RT, 0.8, 0x22FFFFFF)
    renderDrawLine(RL, RB, RR, RB, 0.8, 0x22FFFFFF)
    renderDrawLine(RL, RT, RL, RB, 0.8, 0x22FFFFFF)
    renderDrawLine(RR, RT, RR, RB, 0.8, 0x22FFFFFF)
    renderDrawLine(RL, RT, RL+CLen, RT, 3.5, CC); renderDrawLine(RL, RT, RL, RT+CLen, 3.5, CC)
    renderDrawLine(RR, RT, RR-CLen, RT, 3.5, CC); renderDrawLine(RR, RT, RR, RT+CLen, 3.5, CC)
    renderDrawLine(RL, RB, RL+CLen, RB, 3.5, CC); renderDrawLine(RL, RB, RL, RB-CLen, 3.5, CC)
    renderDrawLine(RR, RB, RR-CLen, RB, 3.5, CC); renderDrawLine(RR, RB, RR, RB-CLen, 3.5, CC)

    local rA = math.floor(blink*220) + 35
    renderDrawBox(RL+4*MDS, RT+4*MDS, 86*MDS, 18*MDS, 0x55000000)
    renderDrawLine(RL+9*MDS, RT+13*MDS, RL+15*MDS, RT+13*MDS, 8*MDS, rA*0x1000000 + 0x00FF2222)
    ts(fM, 'REC '..fmtT(elapsed), RL+19*MDS, RT+6*MDS, 0xFFFFFFFF)

    local chipY = RT + 5*MDS
    if homing.active then
        chipY = drawChip(homing.attack and 'ATTACK' or 'FOLLOW', RR-4*MDS, chipY,
            homing.attack and 0xFFFF4444 or 0xFF44CCFF,
            math.abs(math.sin(recBlink*4))*180 + 75)
    end
    if autopilotActive() then
        chipY = drawChip('AUTO', RR-4*MDS, chipY, 0xFFFFAA00,
            math.abs(math.sin(recBlink*4))*180 + 75)
    end
    if orbit.active then
        chipY = drawChip('ORBIT', RR-4*MDS, chipY, 0xFFAA88FF,
            math.abs(math.sin(recBlink*3))*180 + 75)
    end
    if cine.active then
        chipY = drawChip('CINE '..string.upper(cine.mode or ''), RR-4*MDS, chipY,
            0xFF44DDFF, math.abs(math.sin(recBlink*3))*180 + 75)
    end
    if trackMode then
        chipY = drawChip('TRACK', RR-4*MDS, chipY, 0xFFFF8822, 255)
    end
    if #bombs > 0 then
        chipY = drawChip('BOMB x'..#bombs, RR-4*MDS, chipY, 0xFFFF5500, 255)
    end

    local sig = clamp(1 - camDist/400, 0, 1)
    local sigBars = math.floor(sig*4 + 0.5)
    local sbx = RL + 96*MDS
    for i = 1, 4 do
        local bh = (3 + i*2.6) * MDS
        local col = (i <= sigBars) and 0xFF00D9FF or 0x44FFFFFF
        renderDrawLine(sbx + i*5*MDS, RT+18*MDS, sbx + i*5*MDS, RT+18*MDS - bh, 3*MDS, col)
    end
    local batt = clamp(100 - elapsed/6, 5, 100)
    local bx = sbx + 30*MDS
    renderDrawLine(bx, RT+8*MDS, bx+22*MDS, RT+8*MDS, 1.2, 0x99FFFFFF)
    renderDrawLine(bx, RT+17*MDS, bx+22*MDS, RT+17*MDS, 1.2, 0x99FFFFFF)
    renderDrawLine(bx, RT+8*MDS, bx, RT+17*MDS, 1.2, 0x99FFFFFF)
    renderDrawLine(bx+22*MDS, RT+8*MDS, bx+22*MDS, RT+17*MDS, 1.2, 0x99FFFFFF)
    renderDrawLine(bx+23*MDS, RT+10.5*MDS, bx+23*MDS, RT+14.5*MDS, 2*MDS, 0x99FFFFFF)
    local bcol = batt > 30 and 0xFF44FF88 or 0xFFFF4444
    renderDrawLine(bx+1.5*MDS, RT+12.5*MDS, bx+1.5*MDS + 19*MDS*(batt/100), RT+12.5*MDS, 7*MDS, bcol)
    ts(fS, string.format('%d%%', math.floor(batt)), bx+27*MDS, RT+8*MDS, 0xAAFFFFFF)

    local compY, compW = RT+30*MDS, 50*MDS
    renderDrawLine(cx-compW, compY, cx+compW, compY, 0.8, 0x22FFFFFF)
    local compDirs = {
        {a=0,'N'},{a=90,'E'},{a=180,'S'},{a=270,'W'},
        {a=45,'NE'},{a=135,'SE'},{a=225,'SW'},{a=315,'NW'},
    }
    for _, d in ipairs(compDirs) do
        local da = angDiff(angZ, d.a)
        if math.abs(da) < 50 then
            local ox = da/50 * compW
            local ah = (#d[1] == 1) and 4*MDS or 2.5*MDS
            renderDrawLine(cx+ox, compY-ah, cx+ox, compY+ah, 1.2, 0x88FFFFFF)
            if math.abs(da) < 15 then
                ts(fS, d[1], cx+ox - renderGetFontDrawTextLength(fS, d[1])/2, compY-14*MDS,
                    math.abs(da) < 5 and 0xFFFFFFFF or 0x88FFFFFF)
            end
        end
    end
    renderDrawLine(cx, compY-6*MDS, cx-3*MDS, compY, 1, 0xCCFFFFFF)
    renderDrawLine(cx, compY-6*MDS, cx+3*MDS, compY, 1, 0xCCFFFFFF)

    local lineH, hudBY = 14*MDS, RB - 8*MDS
    ts(fS, string.format('ALT  %dm',  camAlt),  RL+6*MDS, hudBY - lineH*3, 0xAAFFFFFF)
    ts(fS, string.format('DIST %dm',  camDist), RL+6*MDS, hudBY - lineH*2, 0xAAFFFFFF)
    ts(fS, string.format('SPD  %d',   camSpd),  RL+6*MDS, hudBY - lineH,   0xAA00D9FF)
    local zoomStr = string.format('ZOOM %dm', math.floor(zoomDist))
    local angStr  = string.format('PITCH %+.0f', angY)
    local fovStr  = string.format('FOV %.0f', curFov)
    ts(fS, zoomStr, RR - renderGetFontDrawTextLength(fS, zoomStr) - 6*MDS, hudBY - lineH*3, 0xAAFFAA44)
    ts(fS, angStr,  RR - renderGetFontDrawTextLength(fS, angStr)  - 6*MDS, hudBY - lineH*2, 0xAAFFFFFF)
    ts(fS, fovStr,  RR - renderGetFontDrawTextLength(fS, fovStr)  - 6*MDS, hudBY - lineH,   0xAAFFFFFF)
    if fL then
        local timStr = fmtT(elapsed)
        ts(fL, timStr, cx - renderGetFontDrawTextLength(fL, timStr)/2, RB-20*MDS, 0xCCFFFFFF)
    end
    renderDrawLine(cx-40*MDS, RB-7*MDS, cx+40*MDS, RB-7*MDS, 1, 0x33FFFFFF)

    local scX = RR - 4*MDS
    renderDrawLine(scX, RT+CLen, scX, RB-CLen, 0.8, 0x22FFFFFF)
    local altNorm = clamp((camZ - sZ + 50) / 100, 0, 1)
    local scY = RT+CLen + ((RB-RT) - CLen*2) * (1 - altNorm)
    renderDrawLine(scX-4*MDS, scY, scX+4*MDS, scY, 2, 0xCC00D9FF)
end

drawAviationHUD = function(spd, alt, agl, hdg, hull01, label, sub)
    if not fS then initF(); return end
    recBlink = recBlink + 0.05
    local G1, G2, G3 = 0xFF66FF44, 0x9966FF44, 0x3866FF44
    local cx, cy = sw/2, sh/2

    local r = 26*MDS
    local seg = 16
    for i = 1, seg do
        local a1 = (i-1)/seg * math.pi*2
        local a2 =  i   /seg * math.pi*2
        renderDrawLine(cx+math.cos(a1)*r, cy+math.sin(a1)*r,
                       cx+math.cos(a2)*r, cy+math.sin(a2)*r, 1.5, G2)
    end
    renderDrawLine(cx-r-14*MDS, cy, cx-r+4*MDS, cy, 2, G1)
    renderDrawLine(cx+r-4*MDS,  cy, cx+r+14*MDS, cy, 2, G1)
    renderDrawLine(cx, cy-r-10*MDS, cx, cy-r+4*MDS, 2, G1)
    renderDrawLine(cx-2*MDS, cy, cx+2*MDS, cy, 2, G1)
    renderDrawLine(cx-70*MDS, cy, cx-40*MDS, cy, 2.5, G2)
    renderDrawLine(cx-40*MDS, cy, cx-34*MDS, cy+8*MDS, 2.5, G2)
    renderDrawLine(cx+40*MDS, cy, cx+70*MDS, cy, 2.5, G2)
    renderDrawLine(cx+40*MDS, cy, cx+34*MDS, cy+8*MDS, 2.5, G2)

    local bw, bh = 86*MDS, 30*MDS
    renderDrawBox(cx-190*MDS-bw, cy-bh/2, bw, bh, 0x66001400)
    renderDrawLine(cx-190*MDS-bw, cy-bh/2, cx-190*MDS-bw, cy+bh/2, 2, G1)
    ts(fM, string.format('SPD %d', spd), cx-190*MDS-bw+8*MDS, cy-8*MDS, G1)
    renderDrawBox(cx+190*MDS, cy-bh/2, bw, bh, 0x66001400)
    renderDrawLine(cx+190*MDS+bw, cy-bh/2, cx+190*MDS+bw, cy+bh/2, 2, G1)
    ts(fM, string.format('ALT %d', alt), cx+190*MDS+8*MDS, cy-8*MDS, G1)
    ts(fS, string.format('AGL %d', agl), cx+190*MDS+8*MDS, cy+10*MDS, G2)

    ts(fM, string.format('HDG %03d', hdg), cx - renderGetFontDrawTextLength(fM, 'HDG 000')/2,
        sh*0.12, G1)
    local compW = 60*MDS
    local compY = sh*0.12 + 20*MDS
    renderDrawLine(cx-compW, compY, cx+compW, compY, 1, G3)
    for _, d in ipairs({ {0,'N'}, {90,'E'}, {180,'S'}, {270,'W'},
                         {45,'NE'}, {135,'SE'}, {225,'SW'}, {315,'NW'} }) do
        local da = ((d[1] - hdg + 180) % 360) - 180
        if math.abs(da) < 55 then
            local ox = da/55 * compW
            renderDrawLine(cx+ox, compY-3*MDS, cx+ox, compY+3*MDS, 1.2, G2)
            if math.abs(da) < 18 then
                ts(fS, d[2], cx+ox - renderGetFontDrawTextLength(fS, d[2])/2, compY+5*MDS, G2)
            end
        end
    end
    renderDrawLine(cx, compY-6*MDS, cx-3*MDS, compY-1*MDS, 1.2, G1)
    renderDrawLine(cx, compY-6*MDS, cx+3*MDS, compY-1*MDS, 1.2, G1)

    ts(fM, label, sw*0.06, sh*0.12, G1)
    if sub then
        ts(fS, sub, sw*0.06, sh*0.12 + 16*MDS, G3)
    end

    local hbW = 150*MDS
    local hbX, hbY = cx - hbW/2, sh*0.86
    local hp01 = clamp(hull01, 0, 1)
    renderDrawLine(hbX, hbY, hbX + hbW, hbY, 5*MDS, 0x44223322)
    renderDrawLine(hbX, hbY, hbX + hbW*hp01, hbY, 5*MDS,
        hp01 > 0.35 and G1 or 0xFFFF4444)
    ts(fS, string.format('HULL %d%%', math.floor(hp01*100)),
        hbX, hbY - 14*MDS, G2)
    local wpn = hydra.native and 'WPN NATIVE  RKT READY' or 'WPN EMU  RKT READY'
    if hydra.fireHeld then
        local fb = math.floor(math.abs(math.sin(recBlink*5))*255)
        ts(fM, '>> FIRING <<', cx - renderGetFontDrawTextLength(fM, '>> FIRING <<')/2,
            hbY + 8*MDS, fb*0x1000000 + 0x00FF4444)
    else
        ts(fS, wpn, cx - renderGetFontDrawTextLength(fS, wpn)/2, hbY + 8*MDS, G2)
    end
end

local function drawHydraHUD()
    if not fS then initF(); return end
    local okC, car = pcall(storeCarCharIsInNoSave, PLAYER_PED)
    if not okC or not car then return end
    local spd = 0
    local okS, s = pcall(getCarSpeed, car)
    if okS and type(s) == 'number' then spd = math.floor(s) end
    local alt, ralt = 0, 0
    local okP, x, y, z = pcall(getCarCoordinates, car)
    if okP and type(x) == 'number' then
        alt = math.floor(z)
        local okG, g = pcall(getGroundZFor3dCoord, x, y, z)
        if okG and type(g) == 'number' then ralt = math.floor(z - g) end
    end
    local hdg = 0
    local okH, h = pcall(getCarHeading, car)
    if okH and type(h) == 'number' then hdg = math.floor((360 - h) % 360) end
    local hull01 = 1
    local okHl, hl = pcall(getCarHealth, car)
    if okHl and type(hl) == 'number' then hull01 = hl/1000 end
    drawAviationHUD(spd, alt, ralt, hdg, hull01, 'HYDRA', nil)
end

lua_thread.create(function()
    while not isSampAvailable() do wait(500) end
    while true do
        wait(2000)
        if showMenuOpen and showMenuOpen() then
            local px, py = active and camX or sX, active and camY or sY
            local nv, np = {}, {}
            local okA, allV = pcall(getAllVehicles)
            if okA and allV then
                for _, vh in ipairs(allV) do
                    if doesVehicleExist(vh) then
                        local okC, vx, vy = pcall(getCarCoordinates, vh)
                        if okC and type(vx) == 'number' then
                            local dd = getDistanceBetweenCoords2d(px, py, vx, vy)
                            if dd < 120 then nv[#nv+1] = { h=vh, d=math.floor(dd) } end
                        end
                    end
                end
                table.sort(nv, function(a, b) return a.d < b.d end)
            end
            local okC2, allChars = pcall(getAllChars)
            if okC2 and allChars then
                for _, ped in ipairs(allChars) do
                    if doesCharExist(ped) and ped ~= PLAYER_PED then
                        local okX, x, y = pcall(getCharCoordinates, ped)
                        if okX and type(x) == 'number' then
                            local dd = getDistanceBetweenCoords2d(px, py, x, y)
                            if dd < 100 then
                                local nm = 'NPC'
                                local okId, res, pid = pcall(sampGetPlayerIdByCharHandle, ped)
                                if okId and res then
                                    local okN, n = pcall(sampGetPlayerNickname, pid)
                                    if okN and n and n ~= '' then nm = monet_cp1251_to_utf8(n) end
                                end
                                np[#np+1] = { ped=ped, d=math.floor(dd), name=nm }
                            end
                        end
                    end
                end
                table.sort(np, function(a, b) return a.d < b.d end)
            end
            nearCache.vehs, nearCache.peds = nv, np
        end
    end
end)

lua_thread.create(function()
    while not isSampAvailable()          do wait(500) end
    while not sampIsLocalPlayerSpawned() do wait(500) end
    initF()
    local lastTick = os.clock()
    while true do
        wait(0)
        local now = os.clock()
        local dt  = math.min(now - lastTick, 0.05)
        lastTick  = now
        if active then
            simulate(dt)
            drawHUD()
        else

            if hydra.fireHeld and not hydraCanFire() then hydra.fireHeld = false end
            if hydra.fireHeld and not hydra.native then hydraEmulatedFire() end
            if #bombs > 0 or #impacts > 0 or #trails > 0 or #sparks > 0 then bombsUpdate(dt) end

            if hydraCanFire() and not (showMenuOpen and showMenuOpen()) then
                drawHydraHUD()
            end
        end
    end
end)

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.GetStyle():ScaleAllSizes(MDS)
    fa.Init(16*MDS)
end)

local showMenu = imgui.new.bool(false)
function showMenuOpen() return showMenu[0] end
local mTab = 0

local sl = {
    fL=imgui.new.int(0), fT=imgui.new.int(0), fR=imgui.new.int(0), fB=imgui.new.int(0),
    sFwd=imgui.new.int(30), sTurn=imgui.new.int(30), fov=imgui.new.int(60),
    autoSpeed=imgui.new.int(20), homingDist=imgui.new.int(12),
    orbitRadius=imgui.new.int(18), orbitSpeed=imgui.new.int(12), orbitAlt=imgui.new.int(6),
    zoomDist=imgui.new.int(18), camHeight=imgui.new.int(0), cineDur=imgui.new.int(8),
    autoBombRPM=imgui.new.int(20), soundVol=imgui.new.int(70),
}
local function syncSl()
    sl.fL[0]=math.floor(C.fL/MDS); sl.fT[0]=math.floor(C.fT/MDS)
    sl.fR[0]=math.floor(C.fR/MDS); sl.fB[0]=math.floor(C.fB/MDS)
    sl.sFwd[0]=C.sFwd; sl.sTurn[0]=C.sTurn; sl.fov[0]=C.fov
    sl.autoSpeed[0]=C.autoSpeed; sl.homingDist[0]=C.homingDist
    sl.orbitRadius[0]=C.orbitRadius; sl.orbitSpeed[0]=C.orbitSpeed
    sl.orbitAlt[0]=C.orbitAlt
    sl.zoomDist[0]=math.floor(C.zoomDist); sl.cineDur[0]=math.floor(C.cineDur)
    sl.autoBombRPM[0]=C.autoBombRPM
    sl.soundVol[0]=math.floor((C.soundVol or 0.7)*100)
end

local touch = { held = false, sx = -1, sy = -1 }
local function touchUpdate(mp, mdn)
    if mdn and not touch.held then
        touch.held = true; touch.sx, touch.sy = mp.x, mp.y
    elseif not mdn then
        touch.held = false
    end
end
local function pressOriginIn(x, y, w, h)
    return touch.held and touch.sx >= x and touch.sx <= x+w
                      and touch.sy >= y and touch.sy <= y+h
end

local btnPrev = {}
local function touchBtn(id, x, y, w, h, mp, mdn, opts)
    imgui.SetNextWindowPos(imgui.ImVec2(x, y), imgui.Cond.Always)
    imgui.SetNextWindowSize(imgui.ImVec2(w, h), imgui.Cond.Always)
    imgui.Begin(id, nil,
        imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize +
        imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoMove +
        imgui.WindowFlags.NoBackground)
    local dl, wp = imgui.GetWindowDrawList(), imgui.GetWindowPos()
    local p1 = imgui.ImVec2(wp.x + 2*MDS, wp.y + 2*MDS)
    local p2 = imgui.ImVec2(wp.x + w - 2*MDS, wp.y + h - 2*MDS)
    local inside = mp.x >= wp.x and mp.x <= wp.x+w and mp.y >= wp.y and mp.y <= wp.y+h
    local held = inside and mdn and pressOriginIn(wp.x, wp.y, w, h)
    local on = opts.on or held
    local r = (opts.round or 9) * MDS
    dl:AddRectFilled(imgui.ImVec2(p1.x+1, p1.y+2), imgui.ImVec2(p2.x+1, p2.y+2), 0x55000000, r)
    dl:AddRectFilled(p1, p2, on and (opts.bgOn or 0xE6004866) or (opts.bg or 0xCC0A1622), r)
    if on then
        local pulse = math.abs(math.sin(os.clock()*3)) * 0.15
        dl:AddRectFilled(p1, imgui.ImVec2(p2.x, p1.y + (p2.y-p1.y)*0.5),
            math.floor(pulse*255)*0x1000000 + 0x0033CCFF, r)
    end
    dl:AddRect(p1, p2, on and (opts.borderOn or 0xFF33CCFF) or (opts.border or 0x55335566),
        r, 0, on and 2 or 1.2)
    local icon = opts.icon or '?'
    local isz = imgui.CalcTextSize(icon)
    local iconY = wp.y + h/2 - isz.y/2 - (opts.label and 5*MDS or 0)
    dl:AddText(imgui.ImVec2(wp.x + w/2 - isz.x/2, iconY),
        on and (opts.iconColOn or 0xFF99E6FF) or (opts.iconCol or 0xCCDDEEFF), icon)
    if opts.label then
        local lsz = imgui.CalcTextSize(opts.label)
        dl:AddText(imgui.ImVec2(wp.x + w/2 - lsz.x/2, iconY + isz.y + 1*MDS),
            on and 0xFF99E6FF or 0x99CCDDEE, opts.label)
    end
    imgui.End()
    local tap = held and not btnPrev[id]
    btnPrev[id] = held
    return held, tap
end

local function toggleBtn(lbl, state, w, h)
    imgui.PushStyleColor(imgui.Col.Button,
        state and imgui.ImVec4(0.00,0.32,0.22,0.90) or imgui.ImVec4(0.09,0.11,0.18,0.85))
    imgui.PushStyleColor(imgui.Col.ButtonHovered,
        state and imgui.ImVec4(0.00,0.46,0.32,0.95) or imgui.ImVec4(0.12,0.18,0.28,0.90))
    imgui.PushStyleColor(imgui.Col.Text,
        state and imgui.ImVec4(0.0,1.0,0.7,1.0) or imgui.ImVec4(0.45,0.55,0.70,0.80))
    local clicked = imgui.Button(lbl, imgui.ImVec2(w, h))
    imgui.PopStyleColor(3)
    return clicked
end

local function setDroneModel(i)
    C.droneModel = i
    saveC()
    if not active then return end
    if body and body.adopted then
        chat('Корпус сменится после посадки (/drone)')
        return
    end
    if body then unitDelete(body); body = nil end
    local m = DRONE_MODELS[i]
    if m and m.id then
        body = createDroneUnit(m.id, camX, camY, camZ)
        if not body then chat('Модель '..m.name..' недоступна в этой сборке') end
    end
end

local function lockHover()
    local hv = hoverTarget
    if not hv then return end
    if hv.kind == 'veh' then
        trackVeh, trackPed, trackMode = hv.handle, nil, true
        orbitTarget = hv.handle
    else
        trackPed, trackVeh, trackMode = hv.handle, nil, true
    end
    homing.struck = false
    chat('Захват цели: '..(hv.uname or '?'))
end

local function clearTarget()
    trackMode, trackVeh, trackPed, trackHeightOffset = false, nil, nil, 0
    orbitTarget = nil
    homing.active = false
    orbitStop()
    chat('Цель сброшена')
end

local function drawTabHome(iW, contentH, wpC, dlC)
            local stY = imgui.GetCursorPosY()
            dlC:AddRectFilled(imgui.ImVec2(wpC.x+5*MDS, wpC.y+stY-2*MDS),
                imgui.ImVec2(wpC.x+iW+5*MDS, wpC.y+stY+78*MDS),
                active and 0xCC120C00 or 0xCC140606, 10*MDS)
            dlC:AddRect(imgui.ImVec2(wpC.x+5*MDS, wpC.y+stY-2*MDS),
                imgui.ImVec2(wpC.x+iW+5*MDS, wpC.y+stY+78*MDS),
                active and 0x55FFAA00 or 0x44FF3333, 10*MDS, 0, 1)
            if active then
                imgui.SetCursorPos(imgui.ImVec2(12*MDS, stY + 6*MDS))
                imgui.TextColored(imgui.ImVec4(1.0,0.72,0.0,1.0), fa['CIRCLE_DOT']..'  ДРОН АКТИВЕН')
                imgui.SetCursorPosX(12*MDS)
                imgui.TextColored(imgui.ImVec4(0.85,0.72,0.35,0.85),
                    string.format('ALT %dm  DIST %dm  SPD %d', camAlt, camDist, camSpd))
                imgui.SameLine(0, 10*MDS)
                imgui.TextColored(imgui.ImVec4(0.75,0.65,0.30,0.75),
                    string.format('FOV %.0f  PITCH %+.0f', curFov, angY))
                imgui.SetCursorPosX(12*MDS)
                if homing.active then
                    imgui.TextColored(imgui.ImVec4(1.0,0.85,0.0,0.9),
                        (fa['LOCATION_CROSSHAIRS'] or fa['CROSSHAIRS'])..' НАВЕДЕНИЕ: '
                        ..(homing.attack and 'ATTACK — в цель' or 'FOLLOW — эскорт'))
                elseif orbit.active then
                    imgui.TextColored(imgui.ImVec4(1.0,0.60,0.1,0.9),
                        fa['ROTATE']..' ORBIT '..(orbit.dir==1 and 'По час' or 'ПЧС')
                        ..'  R='..C.orbitRadius..'m  '..C.orbitSpeed..' u/s')
                elseif autopilotActive() then
                    local dirNames = { fwd='Вперёд', back='Назад', left='Влево',
                                       right='Вправо', up='Вверх', down='Вниз' }
                    local curDir = '?'
                    for k, v in pairs(autopilot) do if v then curDir = dirNames[k] or '?' end end
                    imgui.TextColored(imgui.ImVec4(1.0,0.75,0.0,0.9),
                        fa['ROBOT']..' AUTO: '..curDir..'  '..C.autoSpeed..' u/s')
                else
                    imgui.TextColored(imgui.ImVec4(0.4,0.38,0.28,0.6),
                        fa['ROBOT']..'  Автопилот: откл')
                end
            else
                imgui.SetCursorPos(imgui.ImVec2(12*MDS, stY + 6*MDS))
                imgui.TextColored(imgui.ImVec4(0.7,0.3,0.35,1.0), fa['CIRCLE']..'  ДРОН ОФФЛАЙН')
                imgui.Spacing(); imgui.Spacing()
            end
            imgui.SetCursorPosY(stY + 84*MDS)
            if active then
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.40,0.05,0.05,0.90))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.62,0.08,0.08,0.95))
                imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.80,0.10,0.10,1.00))
                if imgui.Button(fa['VIDEO_SLASH']..'  Остановить##stop', imgui.ImVec2(iW, 40*MDS)) then
                    droneOff(); showMenu[0] = false
                end
                imgui.PopStyleColor(3)
            else
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.30,0.20,0.00,0.90))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.52,0.36,0.00,0.95))
                imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.75,0.55,0.00,1.00))
                if imgui.Button(fa['CAMERA']..'  Запустить##start', imgui.ImVec2(iW, 40*MDS)) then
                    droneOn(); showMenu[0] = false
                end
                imgui.PopStyleColor(3)
            end
            imgui.Spacing()
            local hw = (iW - 8*MDS) / 2
            if toggleBtn(fa['EYE']..'  HUD##hud', C.showFrame, hw, 34*MDS) then
                C.showFrame = not C.showFrame; saveC()
            end
            imgui.SameLine(0, 8*MDS)
            if toggleBtn(fa['CROSSHAIRS']..'  AIM##aim', C.showCross, hw, 34*MDS) then
                C.showCross = not C.showCross; saveC()
            end
            imgui.Spacing()
            if toggleBtn(fa['GAMEPAD']..'  Кнопки##ctrlui', C.showCtrlUI, hw, 34*MDS) then
                C.showCtrlUI = not C.showCtrlUI; saveC()
                chat('Кнопки '..(C.showCtrlUI and 'показаны' or 'скрыты'))
            end
            imgui.SameLine(0, 8*MDS)
            if toggleBtn(fa['SQUARE']..'  Квадрат авто##carbox', C.showCarBox, hw, 34*MDS) then
                C.showCarBox = not C.showCarBox; saveC()
            end
            imgui.Spacing()
            if toggleBtn((fa['FILM'] or fa['VIDEO'] or fa['ROTATE'])..'  Кино-бар снизу##cinebar',
                    C.showCineBar, hw, 34*MDS) then
                C.showCineBar = not C.showCineBar; saveC()
            end
            imgui.SameLine(0, 8*MDS)
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.10,0.10,0.24,0.88))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.16,0.16,0.38,0.95))
            if imgui.Button((fa['BOMB'] or fa['CIRCLE_DOT'] or '?')..'  Сброс бомбы##dropb',
                    imgui.ImVec2(hw, 34*MDS)) then
                bombDrop()
            end
            imgui.PopStyleColor(2)
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.88,0.72,0.30,0.90), 'Модель дрона   /dspawn — поставить на землю')
            local dmW = (iW - 10*MDS) / #DRONE_MODELS
            for i, m in ipairs(DRONE_MODELS) do
                if i > 1 then imgui.SameLine(0, 5*MDS) end
                local on = (C.droneModel == i)
                imgui.PushStyleColor(imgui.Col.Button,
                    on and imgui.ImVec4(0.00,0.32,0.22,0.92) or imgui.ImVec4(0.09,0.11,0.18,0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00,0.46,0.32,0.95))
                imgui.PushStyleColor(imgui.Col.Text,
                    on and imgui.ImVec4(0.0,1.0,0.7,1.0) or imgui.ImVec4(0.50,0.60,0.72,0.85))
                if imgui.Button(m.name..'##dm'..i, imgui.ImVec2(dmW, 30*MDS)) then
                    setDroneModel(i)
                end
                imgui.PopStyleColor(3)
            end
            imgui.Spacing()

            local hydraOn = active and hydraMode
            imgui.PushStyleColor(imgui.Col.Button,
                hydraOn and imgui.ImVec4(0.30,0.10,0.06,0.90) or imgui.ImVec4(0.08,0.18,0.10,0.90))
            imgui.PushStyleColor(imgui.Col.ButtonHovered,
                hydraOn and imgui.ImVec4(0.45,0.14,0.08,0.95) or imgui.ImVec4(0.10,0.28,0.14,0.95))
            imgui.PushStyleColor(imgui.Col.Text,
                hydraOn and imgui.ImVec4(1.0,0.55,0.4,1.0) or imgui.ImVec4(0.5,1.0,0.55,1.0))
            if imgui.Button((fa['JET_FIGHTER'] or fa['PLANE'] or fa['PAPER_PLANE'])
                    ..(hydraOn and '  Выключить режим Hydra' or '  Режим Hydra (имитация + ракеты)')..'##hyd',
                    imgui.ImVec2(iW, 34*MDS)) then
                if hydraOn then
                    droneOff()
                elseif active then
                    chat('Сначала останови дрон, затем включай режим Hydra')
                else
                    hydraMode = true
                    droneOn()
                end
                showMenu[0] = false
            end
            imgui.PopStyleColor(3)
            imgui.Spacing()
            local tgW = (iW - 8*MDS) / 2
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.06,0.33,0.65,0.88))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.10,0.46,0.82,0.95))
            if imgui.Button(fa['PAPER_PLANE']..'  Канал##tgch', imgui.ImVec2(tgW, 34*MDS)) then
                openLink('https://t.me/strand_scripts')
            end
            imgui.PopStyleColor(2)
            imgui.SameLine(0, 8*MDS)
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.05,0.25,0.52,0.85))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.08,0.38,0.70,0.95))
            if imgui.Button(fa['USER']..'  Victor Strand##tgacc', imgui.ImVec2(tgW, 34*MDS)) then
                openLink('https://t.me/victor_st0')
            end
            imgui.PopStyleColor(2)

end
local function drawTabTargets(iW, contentH, wpC, dlC)
            imgui.TextColored(imgui.ImVec4(1.0,0.75,0.0,0.9),
                fa['LOCATION_DOT']..'  Ближайшие цели')
            imgui.Spacing()
            if trackMode then
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.45,0.08,0.10,0.90))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.65,0.10,0.13,0.95))
                if imgui.Button(fa['LOCK_OPEN']..'  Слежение выключить##trkoff', imgui.ImVec2(iW, 36*MDS)) then
                    trackMode, trackVeh, trackPed = false, nil, nil
                    chat('Слежение отключено')
                end
                imgui.PopStyleColor(2); imgui.Spacing()
            end
            local np, nv = nearCache.peds, nearCache.vehs

            local function pedCard(p, i, cW)
                local isActive = (trackMode and trackPed == p.ped)
                imgui.PushStyleColor(imgui.Col.ChildBg,
                    isActive and imgui.ImVec4(0.03,0.12,0.08,0.92) or imgui.ImVec4(0.04,0.06,0.11,0.88))
                imgui.PushStyleColor(imgui.Col.Border,
                    isActive and imgui.ImVec4(0.0,1.0,0.55,0.60) or imgui.ImVec4(0.15,0.35,0.70,0.40))
                imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 7*MDS)
                imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(6*MDS, 5*MDS))
                imgui.BeginChild('##pc'..i, imgui.ImVec2(cW, 42*MDS), true, imgui.WindowFlags.NoScrollbar)
                imgui.TextColored(imgui.ImVec4(0.4,0.7,1.0,0.85), fa['PERSON'])
                imgui.SameLine(0, 4*MDS)
                imgui.TextColored(imgui.ImVec4(0.9,0.97,1.0,1.0), p.name)
                imgui.SameLine(0, 0); imgui.SetCursorPosX(cW - 34*MDS)
                imgui.TextColored(imgui.ImVec4(0.0,0.85,0.55,0.85), tostring(p.d)..'m')
                imgui.PushStyleColor(imgui.Col.Button,
                    isActive and imgui.ImVec4(0.00,0.30,0.20,0.70) or imgui.ImVec4(0,0,0,0))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00,0.38,0.65,0.5))
                imgui.PushStyleColor(imgui.Col.Text,
                    isActive and imgui.ImVec4(0.0,1.0,0.6,1.0) or imgui.ImVec4(0.35,0.60,1.0,0.80))
                local tLbl = isActive and (fa['LOCK']..' ON') or (fa['BULLSEYE']..' Слеж')
                if imgui.Button(tLbl..'##tp'..i, imgui.ImVec2(cW-12*MDS, 16*MDS)) then
                    if isActive then trackMode, trackPed, trackVeh = false, nil, nil
                    else
                        trackPed, trackVeh, trackMode = p.ped, nil, true
                        chat('Слежу -> '..p.name)
                    end
                end
                imgui.PopStyleColor(3)
                imgui.EndChild()
                imgui.PopStyleVar(2)
                imgui.PopStyleColor(2)
                imgui.SetCursorPosY(imgui.GetCursorPosY() + 3*MDS)
            end

            local function vehCard(v, i, cW)
                local isOrb = (orbitTarget == v.h)
                local isTrk = (trackMode and trackVeh == v.h)
                local okM, mdl = pcall(getCarModel, v.h)
                local vName = okM and tostring(mdl) or '?'
                imgui.PushStyleColor(imgui.Col.ChildBg,
                    isTrk and imgui.ImVec4(0.03,0.12,0.08,0.92)
                    or (isOrb and imgui.ImVec4(0.10,0.07,0.02,0.92) or imgui.ImVec4(0.04,0.08,0.05,0.88)))
                imgui.PushStyleColor(imgui.Col.Border,
                    isTrk and imgui.ImVec4(0.0,1.0,0.55,0.60)
                    or (isOrb and imgui.ImVec4(1.0,0.55,0.10,0.70) or imgui.ImVec4(0.10,0.55,0.30,0.40)))
                imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 7*MDS)
                imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(6*MDS, 5*MDS))
                imgui.BeginChild('##vc'..i, imgui.ImVec2(cW, 52*MDS), true, imgui.WindowFlags.NoScrollbar)
                imgui.TextColored(imgui.ImVec4(0.3,0.9,0.6,0.85), fa['CAR'])
                imgui.SameLine(0, 4*MDS)
                imgui.TextColored(imgui.ImVec4(0.9,0.97,1.0,1.0), 'ID:'..vName)
                imgui.SameLine(0, 0); imgui.SetCursorPosX(cW - 34*MDS)
                imgui.TextColored(imgui.ImVec4(0.0,0.85,0.55,0.85), tostring(v.d)..'m')
                local btnW2 = (cW - 16*MDS) / 2
                imgui.PushStyleColor(imgui.Col.Button,
                    isTrk and imgui.ImVec4(0.00,0.30,0.20,0.70) or imgui.ImVec4(0,0,0,0))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00,0.40,0.25,0.5))
                imgui.PushStyleColor(imgui.Col.Text,
                    isTrk and imgui.ImVec4(0.0,1.0,0.6,1.0) or imgui.ImVec4(0.25,0.75,0.5,0.85))
                local tLbl2 = isTrk and (fa['LOCK']..' ON') or (fa['BULLSEYE']..' Слеж')
                if imgui.Button(tLbl2..'##tv'..i, imgui.ImVec2(btnW2, 16*MDS)) then
                    if isTrk then trackMode, trackVeh, trackPed = false, nil, nil
                    else
                        trackVeh, trackPed, trackMode = v.h, nil, true
                        orbitTarget = v.h
                        chat('Слежу -> авто')
                    end
                end
                imgui.PopStyleColor(3)
                imgui.SameLine(0, 4*MDS)
                imgui.PushStyleColor(imgui.Col.Button,
                    isOrb and imgui.ImVec4(0.28,0.14,0.00,0.80) or imgui.ImVec4(0,0,0,0))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.30,0.18,0.00,0.5))
                imgui.PushStyleColor(imgui.Col.Text,
                    isOrb and imgui.ImVec4(1.0,0.6,0.1,1.0) or imgui.ImVec4(0.55,0.45,0.25,0.80))
                local oLbl = fa['CROSSHAIRS']..(isOrb and ' Цель' or ' Выбор')
                if imgui.Button(oLbl..'##ot'..i, imgui.ImVec2(btnW2, 16*MDS)) then
                    orbitTarget = isOrb and nil or v.h
                    if not isOrb then chat('Цель выбрана (кино/наведение/орбита)') end
                end
                imgui.PopStyleColor(3)
                imgui.EndChild()
                imgui.PopStyleVar(2)
                imgui.PopStyleColor(2)
                imgui.SetCursorPosY(imgui.GetCursorPosY() + 3*MDS)
            end

            local colW = (iW - 6*MDS) / 2
            local colH = contentH - imgui.GetCursorPosY() - 4*MDS
            imgui.PushStyleColor(imgui.Col.ChildBg,              imgui.ImVec4(0,0,0,0))
            imgui.PushStyleColor(imgui.Col.ScrollbarBg,          imgui.ImVec4(0.03,0.05,0.10,0.50))
            imgui.PushStyleColor(imgui.Col.ScrollbarGrab,        imgui.ImVec4(0.25,0.45,0.80,0.70))
            imgui.PushStyleColor(imgui.Col.ScrollbarGrabHovered, imgui.ImVec4(0.35,0.60,1.0,0.90))
            imgui.BeginChild('##col_peds', imgui.ImVec2(colW, colH), false, 0)
            imgui.TextColored(imgui.ImVec4(0.55,0.78,1.0,0.85), fa['PERSON']..'  NPC  ('..#np..')')
            imgui.Spacing()
            if #np == 0 then
                imgui.TextColored(imgui.ImVec4(0.35,0.45,0.60,0.55), '  Пусто')
            else
                for i = 1, #np do pedCard(np[i], i, colW - 4*MDS) end
            end
            imgui.EndChild()
            imgui.PopStyleColor(4)
            imgui.SameLine(0, 6*MDS)
            imgui.PushStyleColor(imgui.Col.ChildBg,              imgui.ImVec4(0,0,0,0))
            imgui.PushStyleColor(imgui.Col.ScrollbarBg,          imgui.ImVec4(0.03,0.07,0.04,0.50))
            imgui.PushStyleColor(imgui.Col.ScrollbarGrab,        imgui.ImVec4(0.15,0.65,0.35,0.70))
            imgui.PushStyleColor(imgui.Col.ScrollbarGrabHovered, imgui.ImVec4(0.20,0.85,0.45,0.90))
            imgui.BeginChild('##col_vehs', imgui.ImVec2(colW, colH), false, 0)
            imgui.TextColored(imgui.ImVec4(0.30,0.95,0.55,0.85), fa['CAR']..'  ТРАНС  ('..#nv..')')
            imgui.Spacing()
            if #nv == 0 then
                imgui.TextColored(imgui.ImVec4(0.35,0.45,0.60,0.55), '  Пусто')
            else
                for i = 1, #nv do vehCard(nv[i], i, colW - 4*MDS) end
            end
            imgui.EndChild()
            imgui.PopStyleColor(4)

end
local function drawTabAuto(iW, contentH, wpC, dlC)
            imgui.BeginChild('##autoscroll', imgui.ImVec2(0, 0), false, 0)
            imgui.TextColored(imgui.ImVec4(1.0,0.75,0.0,0.9), fa['ROBOT']..'  Автопилот')
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.88,0.72,0.30,0.90), 'Скорость')
            imgui.SameLine(0, 8*MDS); imgui.SetNextItemWidth(iW - 100*MDS)
            if imgui.SliderInt('##aspd', sl.autoSpeed, 0, 100) then
                C.autoSpeed = sl.autoSpeed[0]; saveC()
            end
            imgui.SameLine(0, 4*MDS)
            imgui.TextColored(imgui.ImVec4(0.0,0.85,0.55,0.9), tostring(C.autoSpeed)..' u/s')
            imgui.Spacing()
            local dirBtns = {
                { key='up',    icon=fa['ANGLES_UP'],   lbl='UP'    },
                { key='fwd',   icon=fa['ARROW_UP'],    lbl='FWD'   },
                { key='down',  icon=fa['ANGLES_DOWN'], lbl='DOWN'  },
                { key='left',  icon=fa['ARROW_LEFT'],  lbl='LEFT'  },
                { key='back',  icon=fa['ARROW_DOWN'],  lbl='BACK'  },
                { key='right', icon=fa['ARROW_RIGHT'], lbl='RIGHT' },
            }
            local btnW, btnH = (iW - 10*MDS)/3, 50*MDS
            for idx = 1, #dirBtns do
                local d = dirBtns[idx]
                local isOn = autopilot[d.key]
                if (idx-1) % 3 ~= 0 then imgui.SameLine(0, 5*MDS) end
                imgui.PushStyleColor(imgui.Col.Button,
                    isOn and imgui.ImVec4(0.32,0.22,0.00,0.92) or imgui.ImVec4(0.12,0.10,0.06,0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered,
                    isOn and imgui.ImVec4(0.48,0.34,0.00,0.98) or imgui.ImVec4(0.22,0.18,0.06,0.90))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.70,0.50,0.00,1.00))
                imgui.PushStyleColor(imgui.Col.Text,
                    isOn and imgui.ImVec4(1.0,0.75,0.0,1.0) or imgui.ImVec4(0.65,0.60,0.45,0.85))
                if imgui.Button(d.icon..'\n'..d.lbl..'##ab'..d.key, imgui.ImVec2(btnW, btnH)) then
                    autopilotSet(d.key)
                end
                imgui.PopStyleColor(4)
            end
            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Button,
                autopilotActive() and imgui.ImVec4(0.45,0.06,0.06,0.90) or imgui.ImVec4(0.14,0.10,0.06,0.70))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.65,0.08,0.08,0.95))
            imgui.PushStyleColor(imgui.Col.Text,
                autopilotActive() and imgui.ImVec4(1.0,0.4,0.4,1.0) or imgui.ImVec4(0.4,0.38,0.30,0.70))
            if imgui.Button(fa['STOP']..'  STOP##apstopbtn', imgui.ImVec2(iW, 34*MDS)) then
                autopilotOff()
            end
            imgui.PopStyleColor(3)
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(1.0,0.85,0.0,0.9),
                (fa['LOCATION_CROSSHAIRS'] or fa['CROSSHAIRS'])..'  Наведение на цель')
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.88,0.72,0.30,0.90), 'Дистанция')
            imgui.SameLine(0, 8*MDS); imgui.SetNextItemWidth(iW - 130*MDS)
            if imgui.SliderInt('##hdst', sl.homingDist, 4, 60) then
                C.homingDist = sl.homingDist[0]; saveC()
            end
            imgui.SameLine(0, 4*MDS)
            imgui.TextColored(imgui.ImVec4(0.0,0.85,0.55,0.9), tostring(C.homingDist)..'m')
            local hasTgt = homingTargetPos() ~= nil
            imgui.PushStyleColor(imgui.Col.Button,
                homing.active and imgui.ImVec4(0.00,0.32,0.42,0.95)
                or (hasTgt and imgui.ImVec4(0.10,0.18,0.28,0.90) or imgui.ImVec4(0.10,0.10,0.12,0.70)))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.05,0.40,0.55,0.97))
            imgui.PushStyleColor(imgui.Col.Text,
                homing.active and imgui.ImVec4(0.35,0.92,1.0,1.0) or imgui.ImVec4(0.60,0.70,0.80,0.90))
            local modeLbl = C.homingAttack and 'ATTACK' or 'FOLLOW'
            local hLbl = homing.active and ('  Наведение ВКЛ ('..modeLbl..') — откл')
                or (hasTgt and ('  Лететь к цели ('..modeLbl..')') or '  Нет цели (Таб Цели)')
            if imgui.Button((fa['LOCATION_CROSSHAIRS'] or fa['CROSSHAIRS'])..hLbl..'##hmg',
                    imgui.ImVec2(iW, 36*MDS)) then
                homingToggle()
            end
            imgui.PopStyleColor(3)
            imgui.Spacing()

            if toggleBtn((C.homingAttack and (fa['CROSSHAIRS'] or '?')..'  Режим: ATTACK (огонь по цели с дистанции)'
                    or (fa['CAMERA'] or '?')..'  Режим: FOLLOW (эскорт на дистанции)')..'##hmode',
                    C.homingAttack, iW, 32*MDS) then
                homingAttackToggle()
            end
            imgui.Spacing()
            if toggleBtn((fa['BOMB'] or fa['CIRCLE_DOT'] or '?')..'  Авто-сброс бомбы по прибытии##astrike',
                    C.autoStrike, iW, 32*MDS) then
                C.autoStrike = not C.autoStrike; saveC()
            end
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(1.0,0.85,0.0,0.9),
                (fa['BOMB'] or fa['CIRCLE_DOT'] or '?')..'  Автосброс бомбы (по частоте)')
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.88,0.72,0.30,0.90), 'Частота')
            imgui.SameLine(0, 8*MDS); imgui.SetNextItemWidth(iW - 130*MDS)
            if imgui.SliderInt('##abrpm', sl.autoBombRPM, 1, 200) then
                C.autoBombRPM = sl.autoBombRPM[0]; saveC()
            end
            imgui.SameLine(0, 4*MDS)
            imgui.TextColored(imgui.ImVec4(0.0,0.85,0.55,0.9), tostring(sl.autoBombRPM[0])..'/мин')
            if toggleBtn((fa['BOMB'] or fa['CIRCLE_DOT'] or '?')..
                    (C.autoBombOn and '  Автосброс ВКЛ — отключить' or '  Автосброс выключен')..'##abon',
                    C.autoBombOn, iW, 32*MDS) then
                C.autoBombOn = not C.autoBombOn; saveC()
                autoBomb.nextT = 0
            end
            imgui.EndChild()

end
local function drawTabCine(iW, contentH, wpC, dlC)
            imgui.TextColored(imgui.ImVec4(1.0,0.75,0.0,0.9),
                (fa['FILM'] or fa['VIDEO'] or fa['ROTATE'])..'  КИНО-РЕЖИМЫ')
            imgui.SameLine(0, 8*MDS)
            local ct = cineTarget()
            local ctStr = 'нет цели · отметь во вкл. Цели'
            if ct then
                local okM, m = pcall(getCarModel, ct)
                ctStr = 'ID:'..(okM and tostring(m) or '?')
            end
            imgui.TextColored(ct and imgui.ImVec4(0.3,0.9,0.55,0.9) or imgui.ImVec4(0.8,0.4,0.35,0.9),
                fa['CAR']..'  '..ctStr)
            imgui.Spacing()
            local pbW, pbH = (iW - 12*MDS)/4, 50*MDS
            for pi = 1, #CINE_PRESETS do
                local p = CINE_PRESETS[pi]
                local on = shotActive(p)
                if (pi-1) % 4 ~= 0 then imgui.SameLine(0, 4*MDS) end
                imgui.PushStyleColor(imgui.Col.Button,
                    on and imgui.ImVec4(0.00,0.28,0.42,0.95) or imgui.ImVec4(0.07,0.11,0.17,0.88))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.05,0.36,0.54,0.97))
                imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.06,0.46,0.66,1.00))
                imgui.PushStyleColor(imgui.Col.Text,
                    on and imgui.ImVec4(0.35,0.92,1.0,1.0) or imgui.ImVec4(0.62,0.74,0.86,0.90))
                if imgui.Button((p.icon or '?')..'\n'..p.lbl..'##preset'..pi, imgui.ImVec2(pbW, pbH)) then
                    runShot(p)
                end
                imgui.PopStyleColor(4)
            end
            imgui.Spacing()
            local function sR(lbl, ptr, mn, mx, fn)
                imgui.TextColored(imgui.ImVec4(0.88,0.72,0.30,0.90), lbl)
                imgui.SameLine(120*MDS); imgui.SetNextItemWidth(iW - 170*MDS)
                if imgui.SliderInt('##or'..lbl, ptr, mn, mx) then fn() end
                imgui.SameLine(0, 4*MDS)
                imgui.TextColored(imgui.ImVec4(1.0,0.72,0.0,0.9), tostring(ptr[0]))
            end
            sR('Радиус/дист (m)', sl.orbitRadius, 5, 60, function() C.orbitRadius=sl.orbitRadius[0]; saveC() end)
            sR('Скорость',        sl.orbitSpeed,  1, 60, function() C.orbitSpeed=sl.orbitSpeed[0];   saveC() end)
            sR('Высота (m)',      sl.orbitAlt,    1, 40, function() C.orbitAlt=sl.orbitAlt[0];       saveC() end)
            sR('Длит-ность (с)',  sl.cineDur,     2, 40, function() C.cineDur=sl.cineDur[0];         saveC() end)
            imgui.Spacing()
            local hwc = (iW - 8*MDS) / 2
            if toggleBtn(fa['EYE']..'  Смотр на авто##orblook', orbit.look, hwc, 32*MDS) then
                orbit.look = not orbit.look
            end
            imgui.SameLine(0, 8*MDS)
            local stopActive = orbit.active or cine.active
            imgui.PushStyleColor(imgui.Col.Button,
                stopActive and imgui.ImVec4(0.45,0.06,0.10,0.90) or imgui.ImVec4(0.16,0.10,0.10,0.70))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.65,0.08,0.12,0.95))
            imgui.PushStyleColor(imgui.Col.Text,
                stopActive and imgui.ImVec4(1.0,0.45,0.45,1.0) or imgui.ImVec4(0.45,0.35,0.35,0.70))
            if imgui.Button(fa['STOP']..'  Стоп##cinestopbtn', imgui.ImVec2(hwc, 32*MDS)) then
                orbitStop(); cineStop()
            end
            imgui.PopStyleColor(3)

end
local function drawTabFrame(iW, contentH, wpC, dlC)
            imgui.TextColored(imgui.ImVec4(1.0,0.75,0.0,0.9), fa['BORDER_NONE']..'  ГРАНИЦЫ РАМКИ')
            imgui.Spacing()
            local W2, H2 = math.floor(sw/MDS), math.floor(sh/MDS)
            local function fRow(lbl, ptr, mn, mx, fn)
                imgui.TextColored(imgui.ImVec4(0.88,0.72,0.30,0.90), lbl)
                imgui.SameLine(80*MDS); imgui.SetNextItemWidth(iW - 140*MDS)
                if imgui.SliderInt('##fr'..lbl, ptr, mn, mx) then fn() end
                imgui.SameLine(0, 4*MDS)
                if imgui.Button('-##'..lbl..'m', imgui.ImVec2(24*MDS, 24*MDS)) then
                    ptr[0] = math.max(mn, ptr[0]-2); fn()
                end
                imgui.SameLine(0, 2*MDS)
                if imgui.Button('+##'..lbl..'p', imgui.ImVec2(24*MDS, 24*MDS)) then
                    ptr[0] = math.min(mx, ptr[0]+2); fn()
                end
            end
            fRow('Лево',   sl.fL, 0, W2-50, function()
                C.fL = math.floor(sl.fL[0]*MDS)
                if C.fL >= C.fR - 50*MDS then C.fL = C.fR - 50*MDS end; saveC()
            end)
            fRow('Сверх',  sl.fT, 0, H2-50, function()
                C.fT = math.floor(sl.fT[0]*MDS)
                if C.fT >= C.fB - 50*MDS then C.fT = C.fB - 50*MDS end; saveC()
            end)
            fRow('Справа', sl.fR, 50, W2, function()
                C.fR = math.floor(sl.fR[0]*MDS)
                if C.fR <= C.fL + 50*MDS then C.fR = C.fL + 50*MDS end; saveC()
            end)
            fRow('Снизу',  sl.fB, 50, H2, function()
                C.fB = math.floor(sl.fB[0]*MDS)
                if C.fB <= C.fT + 50*MDS then C.fB = C.fT + 50*MDS end; saveC()
            end)
            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.20,0.14,0.04,0.85))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.36,0.26,0.06,0.95))
            if imgui.Button(fa['ROTATE']..'  Reset##rst', imgui.ImVec2(iW, 34*MDS)) then
                C.fL = math.floor(sw*0.21); C.fT = math.floor(sh*0.07)
                C.fR = math.floor(sw*0.84); C.fB = math.floor(sh*0.84)
                saveC(); syncSl()
            end
            imgui.PopStyleColor(2)

end
local function drawTabSettings(iW, contentH, wpC, dlC)
            imgui.TextColored(imgui.ImVec4(1.0,0.75,0.0,0.9), fa['SLIDERS']..'  НАСТРОЙКИ КАМЕРЫ')
            imgui.Spacing()
            local function sRow(lbl, ptr, mn, mx, fn)
                imgui.TextColored(imgui.ImVec4(0.88,0.72,0.30,0.90), lbl)
                imgui.SameLine(110*MDS); imgui.SetNextItemWidth(iW - 160*MDS)
                if imgui.SliderInt('##ss'..lbl, ptr, mn, mx) then fn() end
                imgui.SameLine(0, 4*MDS)
                imgui.TextColored(imgui.ImVec4(1.0,0.72,0.0,0.9), tostring(ptr[0]))
            end
            sRow('Скорость', sl.sFwd,  5, 100, function() C.sFwd=sl.sFwd[0];   saveC() end)
            sRow('Рулевой',  sl.sTurn, 5, 80,  function() C.sTurn=sl.sTurn[0]; saveC() end)
            sRow('FOV',      sl.fov,   5, 120, function()
                C.fov=sl.fov[0]; curFov=C.fov; if active then applyFov() end; saveC()
            end)
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.88,0.72,0.30,0.90), 'Высота cam')
            imgui.SameLine(110*MDS); imgui.SetNextItemWidth(iW - 160*MDS)
            local liveH = trackMode and math.floor(camZ + trackHeightOffset) or math.floor(camZ)
            sl.camHeight[0] = liveH
            if imgui.SliderInt('##sscamz', sl.camHeight, -50, 200) then
                local delta = sl.camHeight[0] - liveH
                if trackMode then trackHeightOffset = trackHeightOffset + delta
                else camZ = sl.camHeight[0] end
            end
            imgui.SameLine(0, 4*MDS)
            imgui.TextColored(imgui.ImVec4(1.0,0.72,0.0,0.9), tostring(sl.camHeight[0])..'m')
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.88,0.72,0.30,0.90), 'Зум (m)')
            imgui.SameLine(110*MDS); imgui.SetNextItemWidth(iW - 160*MDS)
            if imgui.SliderInt('##sszoom', sl.zoomDist, 1, 80) then
                C.zoomDist = sl.zoomDist[0]; zoomDist = C.zoomDist; saveC()
            end
            imgui.SameLine(0, 4*MDS)
            imgui.TextColored(imgui.ImVec4(1.0,0.72,0.0,0.9), tostring(sl.zoomDist[0])..'m')
            imgui.Spacing(); imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.88,0.72,0.30,0.90), 'Режим джойстика')
            imgui.Spacing()
            local jmW = (iW - 8*MDS) / 2
            local jmIcon = fa['UP_DOWN_LEFT_RIGHT'] or fa['ARROWS_UP_DOWN'] or ''
            if jmIcon ~= '' then jmIcon = jmIcon..'  ' end
            imgui.PushStyleColor(imgui.Col.Button,
                C.joyMode==1 and imgui.ImVec4(0.00,0.32,0.22,0.92) or imgui.ImVec4(0.09,0.11,0.18,0.85))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00,0.46,0.32,0.95))
            imgui.PushStyleColor(imgui.Col.Text,
                C.joyMode==1 and imgui.ImVec4(0.0,1.0,0.7,1.0) or imgui.ImVec4(0.50,0.60,0.72,0.85))
            if imgui.Button(jmIcon..'Move (летит куда)##jmove', imgui.ImVec2(jmW, 32*MDS)) then
                C.joyMode = 1; saveC()
            end
            imgui.PopStyleColor(3)
            imgui.SameLine(0, 8*MDS)
            local jtIcon = fa['ROTATE'] or ''
            if jtIcon ~= '' then jtIcon = jtIcon..'  ' end
            imgui.PushStyleColor(imgui.Col.Button,
                C.joyMode==2 and imgui.ImVec4(0.00,0.32,0.22,0.92) or imgui.ImVec4(0.09,0.11,0.18,0.85))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00,0.46,0.32,0.95))
            imgui.PushStyleColor(imgui.Col.Text,
                C.joyMode==2 and imgui.ImVec4(0.0,1.0,0.7,1.0) or imgui.ImVec4(0.50,0.60,0.72,0.85))
            if imgui.Button(jtIcon..'Turn (поворот)##jturn', imgui.ImVec2(jmW, 32*MDS)) then
                C.joyMode = 2; saveC()
            end
            imgui.PopStyleColor(3)
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.88,0.72,0.30,0.90), 'Вид камеры (только дрон)')
            imgui.Spacing()
            local cvW = (iW - 8*MDS) / 2
            for i, cv in ipairs({ {1, '3-е лицо'}, {2, 'FPV'} }) do
                if i > 1 then imgui.SameLine(0, 8*MDS) end
                local on = (C.camView == cv[1])
                imgui.PushStyleColor(imgui.Col.Button,
                    on and imgui.ImVec4(0.00,0.32,0.22,0.92) or imgui.ImVec4(0.09,0.11,0.18,0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00,0.46,0.32,0.95))
                imgui.PushStyleColor(imgui.Col.Text,
                    on and imgui.ImVec4(0.0,1.0,0.7,1.0) or imgui.ImVec4(0.50,0.60,0.72,0.85))
                if imgui.Button((fa['VIDEO'] or fa['CAMERA'] or '')..'  '..cv[2]..'##cv'..i,
                        imgui.ImVec2(cvW, 32*MDS)) then
                    C.camView = cv[1]; saveC()
                end
                imgui.PopStyleColor(3)
            end
            imgui.Spacing()
            local invIcon = fa['ARROWS_UP_DOWN'] or ''
            if invIcon ~= '' then invIcon = invIcon..'  ' end
            if toggleBtn(invIcon..'Инверт ось Y##invy', C.invertY, iW, 30*MDS) then
                C.invertY = not C.invertY; saveC()
            end
            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.04,0.10,0.18,0.80))
            imgui.BeginChild('##anginfo', imgui.ImVec2(iW, 30*MDS), false, imgui.WindowFlags.NoScrollbar)
            imgui.SetCursorPos(imgui.ImVec2(8*MDS, 7*MDS))
            imgui.TextColored(imgui.ImVec4(0.5,0.65,0.8,0.7),
                string.format('Угол камеры: %+.0f°   Поворот: %.0f°', angY, angZ))
            imgui.EndChild()
            imgui.PopStyleColor()
end
local function drawTabWeapon(iW, contentH, wpC, dlC)
            imgui.BeginChild('##wpnscroll', imgui.ImVec2(0, 0), false, 0)

            imgui.TextColored(imgui.ImVec4(1.0,0.75,0.0,0.9),
                (fa['BOMB'] or fa['CIRCLE_DOT'] or '?')..'  ВИДЫ БОМБ')
            imgui.Spacing()
            for i = 1, #BOMB_TYPES do
                local bt = BOMB_TYPES[i]
                local on = (C.bombType == i)
                imgui.PushStyleColor(imgui.Col.Button,
                    on and imgui.ImVec4(0.32,0.14,0.02,0.92) or imgui.ImVec4(0.10,0.09,0.13,0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.50,0.24,0.04,0.95))
                imgui.PushStyleColor(imgui.Col.Text,
                    on and imgui.ImVec4(1.0,0.70,0.2,1.0) or imgui.ImVec4(0.60,0.60,0.68,0.85))
                if imgui.Button((on and (fa['CIRCLE_DOT']..'  ') or '')..bt.name..'##bt'..i,
                        imgui.ImVec2(iW, 30*MDS)) then
                    C.bombType = i; saveC(); chat('Бомба: '..bt.name)
                end
                imgui.PopStyleColor(3)
            end
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(1.0,0.75,0.0,0.9),
                (fa['JET_FIGHTER'] or fa['PLANE'] or fa['PAPER_PLANE'] or '?')..'  СНАРЯДЫ HYDRA')
            imgui.Spacing()
            local ww = (iW - (#HYDRA_WEAPONS-1)*4*MDS) / #HYDRA_WEAPONS
            for i = 1, #HYDRA_WEAPONS do
                local w = HYDRA_WEAPONS[i]
                if i > 1 then imgui.SameLine(0, 4*MDS) end
                local on = (C.hydraWeapon == i)
                imgui.PushStyleColor(imgui.Col.Button,
                    on and imgui.ImVec4(0.30,0.16,0.02,0.92) or imgui.ImVec4(0.10,0.09,0.13,0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.50,0.28,0.04,0.95))
                imgui.PushStyleColor(imgui.Col.Text,
                    on and imgui.ImVec4(1.0,0.72,0.2,1.0) or imgui.ImVec4(0.60,0.60,0.68,0.85))
                if imgui.Button(w.name..'##hw'..i, imgui.ImVec2(ww, 42*MDS)) then
                    C.hydraWeapon = i; saveC(); chat('Снаряд: '..w.name)
                end
                imgui.PopStyleColor(3)
            end
            imgui.Spacing(); imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(1.0,0.75,0.0,0.9), (fa['FIRE'] or '?')..'  БОЕВИК')
            imgui.Spacing()
            local atk = C.homingAttack
            imgui.PushStyleColor(imgui.Col.Button,
                atk and imgui.ImVec4(0.42,0.06,0.06,0.92) or imgui.ImVec4(0.06,0.20,0.28,0.90))
            imgui.PushStyleColor(imgui.Col.ButtonHovered,
                atk and imgui.ImVec4(0.60,0.08,0.08,0.95) or imgui.ImVec4(0.08,0.30,0.42,0.95))
            imgui.PushStyleColor(imgui.Col.Text,
                atk and imgui.ImVec4(1.0,0.5,0.5,1.0) or imgui.ImVec4(0.4,0.85,1.0,1.0))
            local aLbl = atk and ((fa['CROSSHAIRS'] or '?')..'  Наведение: ATTACK (в цель)')
                or ((fa['CAMERA'] or '?')..'  Наведение: FOLLOW (эскорт)')
            if imgui.Button(aLbl..'##atkmode', imgui.ImVec2(iW, 36*MDS)) then
                homingAttackToggle()
            end
            imgui.PopStyleColor(3)
            imgui.TextColored(imgui.ImVec4(0.55,0.60,0.70,0.75),
                'FOLLOW — дрон держится за целью на дистанции, не врезается.')
            imgui.TextColored(imgui.ImVec4(0.55,0.60,0.70,0.75),
                'ATTACK — держит ту же дистанцию и бьёт по цели')
            imgui.TextColored(imgui.ImVec4(0.55,0.60,0.70,0.75),
                'самонаводящимися бомбами/снарядами (без камикадзе).')
            imgui.Spacing(); imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(1.0,0.75,0.0,0.9),
                (fa['VOLUME_HIGH'] or fa['MUSIC'] or '?')..'  ЗВУК И ЭФФЕКТЫ')
            imgui.Spacing()
            if toggleBtn((fa['VOLUME_HIGH'] or '?')..'  Звуки полёта/оружия##snd',
                    C.sound, iW, 32*MDS) then
                C.sound = not C.sound; saveC()
                if not C.sound then sndStopHum() end
            end
            imgui.TextColored(imgui.ImVec4(0.55,0.60,0.70,0.65),
                'Файлы: DroneCam/drone_hum.ogg, jet_hum.ogg, fire.ogg, boom.ogg')
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.88,0.72,0.30,0.90), 'Громкость')
            imgui.SameLine(0, 8*MDS); imgui.SetNextItemWidth(iW - 130*MDS)
            if imgui.SliderInt('##svol', sl.soundVol, 0, 100) then
                C.soundVol = sl.soundVol[0] / 100; saveC()
            end
            imgui.SameLine(0, 4*MDS)
            imgui.TextColored(imgui.ImVec4(0.0,0.85,0.55,0.9), tostring(sl.soundVol[0])..'%')
            imgui.Spacing()
            local hwf = (iW - 8*MDS) / 2
            if toggleBtn((fa['WAVE_SQUARE'] or '?')..' Тряска##shk', C.camShakeOn, hwf, 30*MDS) then
                C.camShakeOn = not C.camShakeOn; saveC()
            end
            imgui.SameLine(0, 8*MDS)
            if toggleBtn((fa['FIRE'] or '?')..' След/вспышки##fx', C.fxTrails, hwf, 30*MDS) then
                C.fxTrails = not C.fxTrails; saveC()
            end
            imgui.EndChild()
end

imgui.OnFrame(
    function() return active or showMenu[0] or hydraCanFire() end,
    function(self)
        self.HideCursor = not showMenu[0]
        self.LockPlayer = showMenu[0]
        local mp  = imgui.GetIO().MousePos
        local mdn = imgui.GetIO().MouseDown[0]
        touchUpdate(mp, mdn)

        if active and C.showCtrlUI and not showMenu[0] then
            local BSZ, BGAP = 62*MDS, 6*MDS
            local slW = 36*MDS

            local bx2 = sw - BSZ*2 - BGAP - slW - 18*MDS
            local by  = sh - BSZ*2 - BGAP - 120*MDS
            local byY = by - BSZ - BGAP
            local blue  = { bg=0xCC0A1829, bgOn=0xCC1A5080, border=0xAA2288CC, borderOn=0xAA2288CC }
            local green = { bg=0xCC0A1E14, bgOn=0xCC0E5030, border=0xAA22AA66, borderOn=0xAA22AA66 }
            local amber = { bg=0xCC18120A, bgOn=0xCC503010, border=0xAACC8822, borderOn=0xAACC8822 }
            hold.yl = touchBtn('##yl', bx2, byY, BSZ, BSZ, mp, mdn,
                { icon=fa['ROTATE_LEFT'] or fa['ARROW_LEFT'], bg=amber.bg, bgOn=amber.bgOn,
                  border=amber.border, borderOn=amber.borderOn, round=10 })
            hold.yr = touchBtn('##yr', bx2+BSZ+BGAP, byY, BSZ, BSZ, mp, mdn,
                { icon=fa['ROTATE_RIGHT'] or fa['ARROW_RIGHT'], bg=amber.bg, bgOn=amber.bgOn,
                  border=amber.border, borderOn=amber.borderOn, round=10 })
            hold.au = touchBtn('##au', bx2, by, BSZ, BSZ, mp, mdn,
                { icon=fa['ARROW_UP'], bg=blue.bg, bgOn=blue.bgOn,
                  border=blue.border, borderOn=blue.borderOn, round=10 })
            hold.ad = touchBtn('##ad', bx2, by+BSZ+BGAP, BSZ, BSZ, mp, mdn,
                { icon=fa['ARROW_DOWN'], bg=blue.bg, bgOn=blue.bgOn,
                  border=blue.border, borderOn=blue.borderOn, round=10 })
            hold.cu = touchBtn('##cu', bx2+BSZ+BGAP, by, BSZ, BSZ, mp, mdn,
                { icon=fa['CHEVRON_UP'], bg=green.bg, bgOn=green.bgOn,
                  border=green.border, borderOn=green.borderOn, round=10 })
            hold.cd = touchBtn('##cd', bx2+BSZ+BGAP, by+BSZ+BGAP, BSZ, BSZ, mp, mdn,
                { icon=fa['CHEVRON_DOWN'], bg=green.bg, bgOn=green.bgOn,
                  border=green.border, borderOn=green.borderOn, round=10 })

            do
                local slH = BSZ*2 + BGAP
                local slX = bx2 + BSZ*2 + BGAP*2 + 4*MDS
                imgui.SetNextWindowPos(imgui.ImVec2(slX, by), imgui.Cond.Always)
                imgui.SetNextWindowSize(imgui.ImVec2(slW, slH + 24*MDS), imgui.Cond.Always)
                imgui.Begin('##zmslwin', nil,
                    imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize +
                    imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoMove +
                    imgui.WindowFlags.NoBackground)
                local dlZ, wpZ = imgui.GetWindowDrawList(), imgui.GetWindowPos()
                dlZ:AddRectFilled(
                    imgui.ImVec2(wpZ.x + slW/2 - 3*MDS, wpZ.y + 4*MDS),
                    imgui.ImVec2(wpZ.x + slW/2 + 3*MDS, wpZ.y + slH - 4*MDS), 0x55334400, 3)
                local norm  = (zoomDist - 1) / 79
                local knobY = wpZ.y + 4*MDS + norm*(slH - 8*MDS)
                dlZ:AddCircleFilled(imgui.ImVec2(wpZ.x + slW/2, knobY), 8*MDS, 0xDDFFAA00)
                dlZ:AddCircle(imgui.ImVec2(wpZ.x + slW/2, knobY), 8*MDS, 0xFFFFCC44, 16, 1.5)
                local zStr = tostring(math.floor(zoomDist))..'m'
                local zSz  = imgui.CalcTextSize(zStr)
                dlZ:AddText(imgui.ImVec2(wpZ.x + slW/2 - zSz.x/2, wpZ.y + slH + 2*MDS), 0xCCFFAA00, zStr)
                if mdn and pressOriginIn(wpZ.x, wpZ.y, slW, slH) then
                    local t = clamp((mp.y - (wpZ.y + 4*MDS)) / (slH - 8*MDS), 0, 1)
                    zoomDist = 1 + t*79
                    C.zoomDist = zoomDist
                    sl.zoomDist[0] = math.floor(zoomDist)
                end
                imgui.End()
            end

            local _, tapCam = touchBtn('##camview', bx2-BSZ-BGAP, byY, BSZ, BSZ, mp, mdn,
                { icon=fa['VIDEO'] or fa['CAMERA'], label=(C.camView==2 and 'FPV' or '3RD'),
                  on=C.camView==2, bg=0xCC141414, bgOn=0xDD004858,
                  border=0x55668899, borderOn=0xFFFFD900, iconColOn=0xFFFFD900, round=10 })
            if tapCam then
                C.camView = (C.camView == 2) and 1 or 2
                saveC()
            end

            local abW, abH, abGap = 58*MDS, 52*MDS, 5*MDS
            local abX = 8*MDS
            local abY = sh - abH*2 - abGap - 110*MDS
            local apStyle = { bg=0xD9181008, bgOn=0xEE584800, border=0x66FFD900,
                              borderOn=0xFFFFD900, iconCol=0xBBEEDDCC, iconColOn=0xFFFFD900 }
            local apBtns = {
                {'##apup',   fa['ANGLES_UP'],   'UP',    'up',    abX,                 abY},
                {'##apfwd',  fa['ARROW_UP'],    'FWD',   'fwd',   abX+abW+abGap,       abY},
                {'##apdown', fa['ANGLES_DOWN'], 'DOWN',  'down',  abX+(abW+abGap)*2,   abY},
                {'##apleft', fa['ARROW_LEFT'],  'LEFT',  'left',  abX,                 abY+abH+abGap},
                {'##apback', fa['ARROW_DOWN'],  'BACK',  'back',  abX+abW+abGap,       abY+abH+abGap},
                {'##apright',fa['ARROW_RIGHT'], 'RIGHT', 'right', abX+(abW+abGap)*2,   abY+abH+abGap},
            }
            for _, b in ipairs(apBtns) do
                local _, tap = touchBtn(b[1], b[5], b[6], abW, abH, mp, mdn,
                    { icon=b[2], label=b[3], on=autopilot[b[4]],
                      bg=apStyle.bg, bgOn=apStyle.bgOn, border=apStyle.border,
                      borderOn=apStyle.borderOn, iconCol=apStyle.iconCol,
                      iconColOn=apStyle.iconColOn, round=12 })
                if tap then
                    autopilotSet(b[4])
                    uiStickMute = os.clock() + 0.30
                end
            end

            local rowY = abY - abH - abGap
            local _, tapFly = touchBtn('##homing', abX, rowY, abW, abH, mp, mdn,
                { icon=fa['LOCATION_CROSSHAIRS'] or fa['CROSSHAIRS'], label='FLY',
                  on=homing.active, bg=0xD9181008, bgOn=0xEE5A4800,
                  border=0x66FFD900, borderOn=0xFFFFD900, iconColOn=0xFFFFD900, round=12 })
            if tapFly then homingToggle(); uiStickMute = os.clock() + 0.30 end
            if autopilotActive() or homing.active then
                local _, tapStop = touchBtn('##apstop', abX+abW+abGap, rowY, abW, abH, mp, mdn,
                    { icon=fa['STOP'], label='STOP', on=true, bgOn=0xE608083A,
                      borderOn=0xFF3333FF, iconColOn=0xFF5555FF, round=12 })
                if tapStop then
                    autopilotOff()
                    homing.active = false
                    uiStickMute = os.clock() + 0.30
                end
            end
            local _, tapBomb = touchBtn('##bomb', abX+(abW+abGap)*2, rowY, abW, abH, mp, mdn,
                { icon=fa['BOMB'] or fa['CIRCLE_DOT'] or fa['CIRCLE'], label='BOMB',
                  bg=0xD9181008, bgOn=0xEE30188A, border=0x66AA88FF,
                  borderOn=0xFF8866FF, iconCol=0xCCFFCCAA, round=12 })
            if tapBomb then bombDrop(); uiStickMute = os.clock() + 0.30 end

            local _, tapAutoB = touchBtn('##autobomb', abX+(abW+abGap)*2, rowY - abH - abGap, abW, abH, mp, mdn,
                { icon=fa['CLOCK'] or fa['REPEAT'] or fa['BOMB'] or '?', label='AUTO',
                  on=C.autoBombOn, bg=0xD9181008, bgOn=0xEE8A5A18,
                  border=0x66AA88FF, borderOn=0xFFFFAA33, iconCol=0xCCFFCCAA,
                  iconColOn=0xFFFFE0AA, round=12 })
            if tapAutoB then
                C.autoBombOn = not C.autoBombOn; saveC()
                autoBomb.nextT = 0
                uiStickMute = os.clock() + 0.30
            end

            local _, tapAtk = touchBtn('##atk', abX, rowY - abH - abGap, abW, abH, mp, mdn,
                { icon=(C.homingAttack and (fa['CROSSHAIRS'] or '?')) or (fa['CAMERA'] or '?'),
                  label=(C.homingAttack and 'ATK' or 'FOLLOW'), on=C.homingAttack,
                  bg=0xD9101820, bgOn=0xEE7A1010, border=0x6633CCFF,
                  borderOn=0xFFFF4444, iconCol=0xCC99E6FF, iconColOn=0xFFFF8888, round=12 })
            if tapAtk then homingAttackToggle(); uiStickMute = os.clock() + 0.30 end
            if orbit.active then
                local _, tapOrb = touchBtn('##orstop', bx2-BSZ-BGAP, by, BSZ, BSZ, mp, mdn,
                    { icon=fa['ROTATE'], on=true, bgOn=0xCC30180A, borderOn=0xFFAA88FF,
                      iconColOn=0xFFAA88FF, round=10 })
                if tapOrb then orbitStop() end
            end
        else

            for k in pairs(hold) do hold[k] = false end
        end

        if active and not showMenu[0] then

            local axm, aym = sw/2, sh/2
            if hoverTarget then
                local _, tapL = touchBtn('##lockbtn', axm + 34*MDS, aym + 30*MDS, 96*MDS, 42*MDS, mp, mdn,
                    { icon=fa['LOCK'] or fa['BULLSEYE'] or '?', label='ЗАХВАТ',
                      bg=0xD9101E08, bgOn=0xEE207A20, border=0x8800FF88,
                      borderOn=0xFF00FF88, iconCol=0xDD88FFAA, round=10 })
                if tapL then lockHover() end
            end

            if trackMode or orbitTarget or trackVeh or trackPed then
                local _, tapU = touchBtn('##unlockbtn', axm - 34*MDS - 96*MDS, aym + 30*MDS,
                        96*MDS, 42*MDS, mp, mdn,
                    { icon=fa['LOCK_OPEN'] or fa['XMARK'] or 'X', label='СБРОС',
                      bg=0xD908081E, bgOn=0xEE10107A, border=0x883333FF,
                      borderOn=0xFF5555FF, iconCol=0xDDAAAAFF, round=10 })
                if tapU then clearTarget() end
            end
        end

        local fireAvail = not showMenu[0]
            and ((active and hydraMode) or (not active and hydraCanFire()))
        if fireAvail then
            local fw, fh = 104*MDS, 68*MDS
            hydra.fireHeld = touchBtn('##hydrafire', sw - fw - 34*MDS, math.floor(sh*0.30), fw, fh, mp, mdn,
                { icon=fa['CROSSHAIRS'] or '?', label='FIRE', on=hydra.fireHeld,
                  bg=0xCC1E1006, bgOn=0xEEB8560A, border=0x88FF8822,
                  borderOn=0xFFFFAA33, iconCol=0xDDFFC066, iconColOn=0xFFFFE0AA, round=16 })
        else
            hydra.fireHeld = false
        end

        if active and C.showCineBar and not showMenu[0] then
            local n = #CINE_PRESETS
            local cbw, cbh, cbg = 64*MDS, 46*MDS, 4*MDS
            local totalW = n*cbw + (n-1)*cbg
            if totalW > sw - 20*MDS then
                cbw = (sw - 20*MDS - (n-1)*cbg) / n
                totalW = n*cbw + (n-1)*cbg
            end
            local startX, yb = sw/2 - totalW/2, sh - cbh - 10*MDS
            for i = 1, n do
                local p = CINE_PRESETS[i]
                local _, tap = touchBtn('##cbar'..i, startX + (i-1)*(cbw+cbg), yb, cbw, cbh, mp, mdn,
                    { icon=p.icon or '?', label=p.lbl, on=shotActive(p), round=8 })
                if tap then runShot(p) end
            end
        end

        if not showMenu[0] then return end
        sl.zoomDist[0] = math.floor(zoomDist)
        local mW, mH = 640*MDS, 420*MDS
        local st = imgui.GetStyle()
        st.WindowRounding    = 0
        st.WindowBorderSize  = 0
        st.ItemSpacing       = imgui.ImVec2(6*MDS, 5*MDS)
        st.FrameRounding     = 8*MDS
        st.ScrollbarSize     = 7*MDS
        st.TouchExtraPadding = imgui.ImVec2(5*MDS, 5*MDS)
        st.Colors[imgui.Col.WindowBg]         = imgui.ImVec4(0.04,0.04,0.06,0.97)
        st.Colors[imgui.Col.ChildBg]          = imgui.ImVec4(0.07,0.07,0.10,0.85)
        st.Colors[imgui.Col.SliderGrab]       = imgui.ImVec4(1.0,0.72,0.0,1.0)
        st.Colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(1.0,0.85,0.2,1.0)
        st.Colors[imgui.Col.FrameBg]          = imgui.ImVec4(0.10,0.09,0.14,0.90)
        st.Colors[imgui.Col.FrameBgHovered]   = imgui.ImVec4(0.18,0.16,0.24,0.95)
        st.Colors[imgui.Col.Button]           = imgui.ImVec4(0.18,0.14,0.06,0.88)
        st.Colors[imgui.Col.ButtonHovered]    = imgui.ImVec4(0.36,0.26,0.06,0.95)
        st.Colors[imgui.Col.ButtonActive]     = imgui.ImVec4(0.70,0.50,0.00,1.00)
        st.Colors[imgui.Col.Text]             = imgui.ImVec4(0.95,0.92,0.82,1.0)
        st.Colors[imgui.Col.ScrollbarBg]      = imgui.ImVec4(0,0,0,0)
        st.Colors[imgui.Col.ScrollbarGrab]    = imgui.ImVec4(0.50,0.38,0.08,0.80)
        imgui.SetNextWindowPos(imgui.ImVec2(sw/2-mW/2, sh/2-mH/2), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowSize(imgui.ImVec2(mW, mH), imgui.Cond.Always)
        imgui.Begin('##dmc', showMenu,
            imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize +
            imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoCollapse)
        local dl2, wp2 = imgui.GetWindowDrawList(), imgui.GetWindowPos()

        dl2:AddRectFilledMultiColor(wp2, imgui.ImVec2(wp2.x+mW, wp2.y+52*MDS),
            0xFF0E0A02, 0xFF120C02, 0xFF0E0B03, 0xFF0A0802)
        dl2:AddLine(imgui.ImVec2(wp2.x+12*MDS, wp2.y+52*MDS),
            imgui.ImVec2(wp2.x+mW-12*MDS, wp2.y+52*MDS), 0x66FFAA00, 1)
        dl2:AddRectFilled(imgui.ImVec2(wp2.x, wp2.y+14*MDS),
            imgui.ImVec2(wp2.x+3*MDS, wp2.y+38*MDS), 0xFFFFAA00, 2)
        imgui.SetCursorPos(imgui.ImVec2(14*MDS, 13*MDS))
        imgui.TextColored(imgui.ImVec4(1.0,0.70,0.0,1.0), fa['CAMERA'])
        imgui.SameLine(0,7*MDS)
        imgui.TextColored(imgui.ImVec4(0.98,0.95,0.88,1.0), 'DRONE CAM')
        imgui.SameLine(0,6*MDS)
        imgui.TextColored(imgui.ImVec4(1.0,0.70,0.0,0.85), 'v4.0')
        imgui.SameLine(0,6*MDS)
        imgui.TextColored(imgui.ImVec4(0.55,0.50,0.38,0.60), 'Victor Strand')

        local xp1 = imgui.ImVec2(wp2.x+mW-30*MDS, wp2.y+10*MDS)
        local xp2 = imgui.ImVec2(wp2.x+mW-8*MDS,  wp2.y+32*MDS)
        local xhov = mp.x>=xp1.x and mp.x<=xp2.x and mp.y>=xp1.y and mp.y<=xp2.y
        dl2:AddRectFilled(xp1, xp2, xhov and 0xCC6B1010 or 0x88300808, 6*MDS)
        dl2:AddLine(imgui.ImVec2(xp1.x+6*MDS,xp1.y+6*MDS), imgui.ImVec2(xp2.x-6*MDS,xp2.y-6*MDS), 0xCCFF4444, 1.8)
        dl2:AddLine(imgui.ImVec2(xp2.x-6*MDS,xp1.y+6*MDS), imgui.ImVec2(xp1.x+6*MDS,xp2.y-6*MDS), 0xCCFF4444, 1.8)
        imgui.SetCursorPos(imgui.ImVec2(mW-30*MDS, 10*MDS))
        imgui.InvisibleButton('##xbtn', imgui.ImVec2(22*MDS, 22*MDS))
        if imgui.IsItemClicked() then showMenu[0] = false end

        local sideW    = 90*MDS
        local contentX = sideW + 2*MDS
        local contentW = mW - contentX - 8*MDS
        local contentY = 54*MDS
        local contentH = mH - contentY - 8*MDS
        dl2:AddRectFilled(imgui.ImVec2(wp2.x, wp2.y+54*MDS), imgui.ImVec2(wp2.x+sideW, wp2.y+mH), 0xCC060503, 0)
        dl2:AddLine(imgui.ImVec2(wp2.x+sideW, wp2.y+54*MDS), imgui.ImVec2(wp2.x+sideW, wp2.y+mH), 0x33FFAA00, 1)
        local tabs = {
            { fa['HOUSE'],        'Главн' },
            { fa['LOCATION_DOT'], 'Цели'  },
            { fa['ROBOT'],        'Авто'  },
            { fa['FILM'] or fa['VIDEO'] or fa['ROTATE'], 'Кино' },
            { fa['CROSSHAIRS'],   'Рамка' },
            { fa['GEAR'],         'Наст'  },
            { fa['BOMB'] or fa['FIRE'] or fa['CIRCLE_DOT'], 'Оруж' },
        }
        local tabH = (mH - 54*MDS) / #tabs
        for i, t in ipairs(tabs) do
            local act = (mTab == i-1)
            imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 0)
            if act then
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.28,0.18,0.00,0.95))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.42,0.28,0.00,1.00))
                imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.0,0.72,0.0,1.0))
                dl2:AddRectFilled(imgui.ImVec2(wp2.x, wp2.y+54*MDS+(i-1)*tabH),
                    imgui.ImVec2(wp2.x+3*MDS, wp2.y+54*MDS+i*tabH), 0xFFFFAA00, 0)
            else
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18,0.14,0.04,0.80))
                imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.55,0.50,0.35,0.80))
            end
            imgui.SetCursorPos(imgui.ImVec2(0, 54*MDS+(i-1)*tabH))
            if imgui.Button(t[1]..'\n'..t[2]..'##tt'..i, imgui.ImVec2(sideW, tabH)) then
                if mTab ~= i-1 then syncSl() end
                mTab = i-1
            end
            imgui.PopStyleColor(3)
            imgui.PopStyleVar()
        end

        imgui.SetCursorPos(imgui.ImVec2(contentX, contentY))
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0,0,0,0))
        imgui.BeginChild('##mcontent', imgui.ImVec2(contentW, contentH), false,
            imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
        imgui.PopStyleColor()
        local iW = contentW - 10*MDS
        imgui.SetCursorPos(imgui.ImVec2(5*MDS, 4*MDS))
        local wpC = imgui.GetWindowPos()
        local dlC = imgui.GetWindowDrawList()

        if mTab == 0 then drawTabHome(iW, contentH, wpC, dlC)
        elseif mTab == 1 then drawTabTargets(iW, contentH, wpC, dlC)
        elseif mTab == 2 then drawTabAuto(iW, contentH, wpC, dlC)
        elseif mTab == 3 then drawTabCine(iW, contentH, wpC, dlC)
        elseif mTab == 4 then drawTabFrame(iW, contentH, wpC, dlC)
        elseif mTab == 5 then drawTabSettings(iW, contentH, wpC, dlC)
        else drawTabWeapon(iW, contentH, wpC, dlC) end
        imgui.EndChild()
        imgui.End()
    end
)

function main()
    if not isSampLoaded() then return end
    while not isSampAvailable()          do wait(100) end
    while not sampIsLocalPlayerSpawned() do wait(100) end
    wait(500)
    initF()
    loadC()
    sampRegisterChatCommand('drone', function()
        if active then droneOff() else droneOn() end
    end)
    sampRegisterChatCommand('dmenu', function()
        syncSl(); showMenu[0] = not showMenu[0]
    end)
    sampRegisterChatCommand('dhide', function()
        C.showCtrlUI = not C.showCtrlUI; saveC()
        chat('Кнопки '..(C.showCtrlUI and 'показаны' or 'СКРЫТЫ · хорошей съёмки!'))
    end)
    sampRegisterChatCommand('droneedit', function()
        syncSl(); showMenu[0] = true; mTab = 4
    end)
    sampRegisterChatCommand('dbar', function()
        C.showCineBar = not C.showCineBar; saveC()
        chat('Кино-бар '..(C.showCineBar and 'показан' or 'скрыт'))
    end)
    sampRegisterChatCommand('dfly',  homingToggle)
    sampRegisterChatCommand('dbomb', function() bombDrop() end)
    sampRegisterChatCommand('dview', function()
        C.camView = (C.camView == 2) and 1 or 2
        saveC()
        chat('Камера дрона: '..(C.camView == 2 and 'FPV' or '3-е лицо'))
    end)

    sampRegisterChatCommand('dspawn', function()
        local m = DRONE_MODELS[C.droneModel or 1]
        if not m or not m.id then chat('Выбери модель дрона в /dmenu (Главная)'); return end
        local px, py, pz = getCharCoordinates(PLAYER_PED)
        local h = math.rad(getCharHeading(PLAYER_PED))

        local x, y = px - math.sin(h)*3, py + math.cos(h)*3
        local gz = pz
        local okG, g = pcall(getGroundZFor3dCoord, x, y, pz + 2)
        if okG and type(g) == 'number' then gz = g end
        local u = createDroneUnit(m.id, x, y, gz + 0.8)
        if u then
            spawnedDrones[#spawnedDrones+1] = u
            chat(m.name..' заспавнен — подойди и введи /drone для взлёта')
        else
            chat('Не удалось создать '..m.name..' (ID '..m.id..') — модели нет в сборке')
        end
    end)
    sampRegisterChatCommand('dclear', function()
        for _, u in ipairs(spawnedDrones) do unitDelete(u) end
        spawnedDrones = {}
        chat('Заспавненные дроны удалены')
    end)

    sampRegisterChatCommand('dhydra', function()
        if active and hydraMode then droneOff(); return end
        if active then chat('Сначала останови дрон (/drone), затем /dhydra'); return end
        hydraMode = true
        droneOn()
    end)
    sampRegisterChatCommand('dunlock', clearTarget)

    sampRegisterChatCommand('datk', homingAttackToggle)

    sampRegisterChatCommand('dbombtype', function(arg)
        local n = tonumber(arg)
        if n and BOMB_TYPES[n] then C.bombType = n
        else C.bombType = (C.bombType % #BOMB_TYPES) + 1 end
        saveC(); chat('Бомба: '..bombType().name)
    end)

    sampRegisterChatCommand('dgun', function(arg)
        local n = tonumber(arg)
        if n and HYDRA_WEAPONS[n] then C.hydraWeapon = n
        else C.hydraWeapon = (C.hydraWeapon % #HYDRA_WEAPONS) + 1 end
        saveC(); chat('Снаряд: '..hydraWeapon().name)
    end)

    sampRegisterChatCommand('dsound', function()
        C.sound = not C.sound; saveC()
        if not C.sound then sndStopHum()
        elseif active then sndInit(); sndStartHum(hydraMode and 'jet' or 'drone') end
        chat('Звук '..(C.sound and 'ВКЛ' or 'выкл'))
    end)
    if hydra.native then
        chat('Hydra: нативный огонь доступен (кнопка FIRE в кабине)')
    end
    chat('v4.0  |  /dmenu  /drone  /dfly  /dbomb  /dview  /dspawn  /dhydra')
    chat('Боевик:  /datk  /dbombtype  /dgun  /dsound  /dunlock')
    while true do
        wait(500)
    end
end
