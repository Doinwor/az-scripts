script_name('Truck Helper Free')
script_author('Victor Strand')
script_version('2.0')
script_version_number(3)
script_properties('work-in-pause')

local imgui  = require('mimgui')
local enc    = require('encoding')
local inicfg = require('inicfg')
local sampev = require('lib.samp.events')
local faR    = require('fAwesome6')
local fa     = require('fAwesome6_solid')
local ffi    = require('ffi')

enc.default = 'CP1251'
local u8  = enc.UTF8
local MDS = MONET_DPI_SCALE
local sw, sh = getScreenResolution()

local _openLink = nil
pcall(function()
    local gta = ffi.load('GTASA')
    ffi.cdef[[ void _Z12AND_OpenLinkPKc(const char* link); ]]
    _openLink = function(url) gta._Z12AND_OpenLinkPKc(url) end
end)

local function openLink(url)
    if _openLink then
        pcall(_openLink, url)
    else
        sampAddChatMessage('{00B4FF}Link: {FFFFFF}' .. url, -1)
    end
end

local FOLDER     = getWorkingDirectory() .. '/TruckHelper'
local CFG_FILE   = 'TruckHelper.ini'
local SOUND_URL  = 'https://files.catbox.moe/52dk8h.mp3'
local SOUND_PATH = FOLDER .. '/menu.mp3'
local LOGO_URL   = 'https://files.catbox.moe/z8yu0x.png'
local LOGO_PATH  = FOLDER .. '/logo.png'

local TLOG_PATH = FOLDER .. '/chat_log.txt'
local tlog_enabled = false

local function tlog_write(prefix, color, text)
    if not tlog_enabled then return end
    local f = io.open(TLOG_PATH, 'a')
    if not f then return end
    local hex = ''
    for i = 1, #text do
        hex = hex .. string.format('%02X ', text:byte(i))
    end
    f:write(os.date('[%H:%M:%S] ') .. prefix
        .. ' color=' .. tostring(color)
        .. '\nTEXT: ' .. text
        .. '\nHEX:  ' .. hex
        .. '\n---\n')
    f:close()
end

local function readBool(v, def)
    if v == true  or v == 'true'  then return true  end
    if v == false or v == 'false' then return false end
    return def
end

local function notify(msg)
    sampAddChatMessage('{FF4D4D}[Truck Helper]{FFFFFF} ' .. msg, -1)
end

local function toggleNotify(name, state)
    local s = state and '{00FF7F}ON{FFFFFF}' or '{FF4444}OFF{FFFFFF}'
    notify(name .. ': ' .. s)
end

local ini = inicfg.load({
    cfg = {
        anticarskill = 'false',
        autogruz     = 'false',
        gruz_index   = '0',
        autogate     = 'false',
        attach_btn   = 'false',
        atr_x        = tostring(math.floor(sw * 0.82)),
        atr_y        = tostring(math.floor(sh * 0.55)),
        stats_visible= 'false',
        zarp         = '0',
        larec        = '0',
        domkrat_btn  = 'false',
        dk_x         = tostring(math.floor(sw * 0.05)),
        dk_y         = tostring(math.floor(sh * 0.70)),
        gps_line     = 'false',
    }
}, CFG_FILE)

anticarskill  = readBool(ini.cfg.anticarskill,  false)
autogruz      = readBool(ini.cfg.autogruz,      false)
gruz_index    = tonumber(ini.cfg.gruz_index)    or 0
autogate      = readBool(ini.cfg.autogate,      false)
attach_btn    = readBool(ini.cfg.attach_btn,    false)
stats_visible = readBool(ini.cfg.stats_visible, false)
zarp          = tonumber(ini.cfg.zarp)          or 0
larec         = tonumber(ini.cfg.larec)         or 0
domkrat_btn   = readBool(ini.cfg.domkrat_btn,   false)
gpsLine       = readBool(ini.cfg.gps_line,      false)

local atr_posX     = tonumber(ini.cfg.atr_x) or math.floor(sw * 0.82)
local atr_posY     = tonumber(ini.cfg.atr_y) or math.floor(sh * 0.55)
local domkrat_posX = tonumber(ini.cfg.dk_x)  or math.floor(sw * 0.05)
local domkrat_posY = tonumber(ini.cfg.dk_y)  or math.floor(sh * 0.70)

local function saveCfg()
    ini.cfg.anticarskill = tostring(anticarskill)
    ini.cfg.autogruz     = tostring(autogruz)
    ini.cfg.gruz_index   = tostring(gruz_index)
    ini.cfg.autogate     = tostring(autogate)
    ini.cfg.attach_btn   = tostring(attach_btn)
    ini.cfg.atr_x        = tostring(math.floor(atr_posX))
    ini.cfg.atr_y        = tostring(math.floor(atr_posY))
    ini.cfg.stats_visible= tostring(stats_visible)
    ini.cfg.zarp         = tostring(zarp)
    ini.cfg.larec        = tostring(larec)
    ini.cfg.domkrat_btn  = tostring(domkrat_btn)
    ini.cfg.dk_x         = tostring(math.floor(domkrat_posX))
    ini.cfg.dk_y         = tostring(math.floor(domkrat_posY))
    ini.cfg.gps_line     = tostring(gpsLine)
    inicfg.save(ini, CFG_FILE)
end

local bass   = nil
local stream = 0

pcall(function()
    bass = ffi.load('libbass.so')
    ffi.cdef[[
        int           BASS_Init(int device, unsigned long freq,
                                unsigned long flags, void* win, void* clsid);
        unsigned long BASS_StreamCreateFile(int mem, const char* file,
                                            unsigned long long offset,
                                            unsigned long long length,
                                            unsigned long flags);
        int           BASS_ChannelPlay(unsigned long handle, int restart);
        int           BASS_ChannelStop(unsigned long handle);
        int           BASS_StreamFree(unsigned long handle);
        int           BASS_ChannelSetAttribute(unsigned long handle,
                                               unsigned long attrib, float value);
    ]]
    bass.BASS_Init(-1, 44100, 0, nil, nil)
end)

local function playMenuSound()
    if not bass then return end
    if not doesFileExist(SOUND_PATH) then return end
    pcall(function()
        if stream ~= 0 then
            bass.BASS_ChannelStop(stream)
            bass.BASS_StreamFree(stream)
            stream = 0
        end
        stream = bass.BASS_StreamCreateFile(0, SOUND_PATH, 0, 0, 0)
        if stream ~= 0 then
            bass.BASS_ChannelSetAttribute(stream, 2, 0.75)
            bass.BASS_ChannelPlay(stream, 1)
        end
    end)
end

function sampev.onSendVehicleDamaged(...)
    if anticarskill then return false end
end

local BARRIER_MODELS = {
    [968]=true,[975]=true,[1374]=true,[19912]=true,
    [988]=true,[19313]=true,[11327]=true,[980]=true
}

local function doAutoGate()
    if not autogate then return end
    local inCar = isCharInAnyCar(PLAYER_PED)
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    for _, hObj in pairs(getAllObjects()) do
        if doesObjectExist(hObj) then
            local objModel = getObjectModel(hObj)
            if BARRIER_MODELS[objModel] then
                local res, ox, oy, oz = getObjectCoordinates(hObj)
                local dist = getDistanceBetweenCoords3d(px, py, pz, ox, oy, oz)
                if dist < (inCar and 12 or 5) then
                    local bs = raknetNewBitStream()
                    raknetBitStreamWriteInt8(bs, 220)
                    raknetBitStreamWriteInt8(bs, 63)
                    raknetBitStreamWriteInt8(bs, 8)
                    raknetBitStreamWriteInt32(bs, 7)
                    raknetBitStreamWriteInt32(bs, -1)
                    raknetBitStreamWriteInt32(bs, 0)
                    raknetBitStreamWriteString(bs, '')
                    raknetSendBitStreamEx(bs, 1, 7, 1)
                    raknetDeleteBitStream(bs)
                    return
                end
            end
        end
    end
end

function sampev.onShowDialog(id, style, title, btn1, btn2, text)
    if autogruz then
        local isGruz = false
        if title then
            isGruz = title:find('\xc2\xfb\xe1\xee\xf0 \xe3\xf0\xf3\xe7\xe0')
                  or title:find('\xc2\xfb\xe1\xee\xf0\20\xe3\xf0\xf3\xe7\xe0')
                  or title:lower():find('gruz')
                  or title:lower():find('cargo')
                  or title:lower():find('load')
        end
        if not isGruz and text then
            isGruz = text:find('\xe3\xf0\xf3\xe7') or text:lower():find('gruz')
        end
        if isGruz then
            local lines = {}
            if text then
                for line in (text .. '\n'):gmatch('([^\n]*)\n') do
                    if line ~= '' then lines[#lines + 1] = line end
                end
            end
            local lineCount = #lines
            local idx
            if gruz_index == 0 then
                idx = math.max(0, lineCount - 1)
            else
                idx = gruz_index - 1
                if lineCount > 0 and idx >= lineCount then idx = lineCount - 1 end
                if idx < 0 then idx = 0 end
            end
            sampSendDialogResponse(id, 1, idx, '')
            return false
        end
    end
end

local function checkLarecMessage(text)
    if not text then return end
    local hasLarec = text:find('\xeb\xe0\xf0\xe5\xf6')
                  or text:lower():find('larec')
                  or text:lower():find('chest')
    local hasGot   = text:find('\xef\xee\xeb\xf3\xf7\xe8\xeb')
                  or text:find('\xed\xe0\xf8\xeb\xe8')
    if hasLarec and hasGot then
        larec = larec + 1; saveCfg(); return
    end
    local hasAdded  = text:find('\xc4\xee\xe1\xe0\xe2\xeb\xe5\xed') or text:lower():find('added')
    local hasLarec2 = text:find('\xcb\xe0\xf0\xe5\xf6') or text:lower():find('larec')
    if hasAdded and hasLarec2 then
        larec = larec + 1; saveCfg()
    end
end

function sampev.onChatMessage(color, text)
    if not text then return end
    tlog_write('CHAT', color, text)
    checkLarecMessage(text)
end

function sampev.onServerMessage(color, text)
    if not text then return end
    checkLarecMessage(text)
    tlog_write('SERVER', color, text)

    local hasEarned = false
    if text:find('\xe4\xee\xf1\xf2\xe0\xe2\xeb\xe5\xed', 1, true) then hasEarned = true end
    if text:find('\xc4\xee\xf1\xf2\xe0\xe2\xeb\xe5\xed', 1, true) then hasEarned = true end
    if text:find('\xe7\xe0\xf0\xef\xeb\xe0\xf2\xe0',     1, true) then hasEarned = true end
    if text:find('\xe7\xe0\xf0\xe0\xe1\xee\xf2\xe0\xeb', 1, true) then hasEarned = true end
    if text:find('\xe2\xfb\xef\xeb\xe0\xf2\xe0',         1, true) then hasEarned = true end
    if text:find('\xf0\xe5\xe9\xf1',                     1, true) then hasEarned = true end
    if not hasEarned then return end

    local tail = text:match(':[^:]*$') or text
    tail = tail:gsub('[%.!]%s*$', '')

    local earned = 0
    local found  = false

    do
        local mm, rest = tail:match('\xca\xca%s*(%d+)%s+\xca%s*([%d%.]+)')
        if mm and rest then
            earned = (tonumber(mm) or 0) * 1000000 + (tonumber(rest:gsub('%.','')) or 0)
            found  = true
            if tlog_enabled then tlog_write('PARSE КК+К', 0, mm..' + '..rest..' = '..earned) end
        end
    end

    if not found then
        local kval = tail:match('[%s:]\xca%s+([%d%.]+)')
        if not kval then kval = tail:match('\xca%s+(%d[%d%.]+)') end
        if not kval then kval = tail:match('\xca(%d[%d%.]+)')     end
        if kval then
            earned = tonumber(kval:gsub('%.','')) or 0
            found  = true
            if tlog_enabled then tlog_write('PARSE K', 0, kval..' = '..tostring(earned)) end
        end
    end

    if not found then
        local nums = {}
        for n in tail:gmatch('%d[%d%.]+') do
            nums[#nums+1] = n
        end
        if #nums > 0 then
            local last = nums[#nums]
            local clean = last:gsub('%.','')
            local v = tonumber(clean) or 0
            if v > 100 then
                earned = v
                found  = true
                if tlog_enabled then tlog_write('PARSE NUM', 0, last..' = '..earned) end
            end
        end
    end

    if not found then
        local amount = text:match('%$(%d[%d,%.]*)')
        if not amount then amount = text:match('([%d]+)%s*%$') end
        if amount then
            earned = tonumber(amount:gsub('[,%.%s]','')) or 0
            found  = true
            if tlog_enabled then tlog_write('PARSE $', 0, amount..' = '..earned) end
        end
    end

    if found and earned > 0 then
        zarp = zarp + earned
        saveCfg()
        if tlog_enabled then tlog_write('EARNED OK', 0, '+'..earned..' total='..zarp) end
    else
        if tlog_enabled then tlog_write('NOT PARSED', 0, 'tail=['..tail..']') end
    end
end

local atr_selecting = false
local atr_trailer   = nil
local atr_autoMode  = false
local atr_moveMode  = false
local ATR_RADIUS    = 150
local ATR_STEP      = 8 * MDS

local function getNearestTrailer()
    local okC, myCar = pcall(getCarCharIsUsing, PLAYER_PED)
    if not okC or not myCar then return nil end
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    local best, bestV = 9999, nil
    local okV, vehs = pcall(getAllVehicles)
    if not okV or not vehs then return nil end
    for _, v in ipairs(vehs) do
        if v ~= myCar then
            local ok2, vx, vy, vz = pcall(getCarCoordinates, v)
            if ok2 then
                local d = getDistanceBetweenCoords3d(px, py, pz, vx, vy, vz)
                if d < best and d <= 30 then best = d; bestV = v end
            end
        end
    end
    return bestV
end

local function doAttach(veh)
    local okC, myCar = pcall(getCarCharIsUsing, PLAYER_PED)
    if not okC or not myCar then return end
    if not doesVehicleExist(veh) then return end
    local ok2, attached = pcall(isTrailerAttachedToCab, veh, myCar)
    if ok2 and attached then
        pcall(detachTrailerFromCab, veh, myCar)
        notify('\xcf\xf0\xe8\xf6\xe5\xef \xee\xf2\xf6\xe5\xef\xeb\xe5\xed')
    else
        pcall(attachTrailerToCab, veh, myCar)
        notify('\xcf\xf0\xe8\xf6\xe5\xef \xef\xf0\xe8\xf6\xe5\xef\xeb\xe5\xed!')
    end
end

local cpActive = false
local cpX, cpY, cpZ = 0, 0, 0

function sampev.onSetCheckpoint(position, size)
    if position and type(position) == 'table' then
        local x = tonumber(position.x)
        local y = tonumber(position.y)
        local z = tonumber(position.z)
        if x and y and z then
            cpX, cpY, cpZ = x, y, z
            cpActive = true
        end
    end
end

function sampev.onSetRaceCheckpoint(cptype, position, nextPosition, size)
    local x, y, z
    if type(position) == 'table' then
        x = tonumber(position.x); y = tonumber(position.y); z = tonumber(position.z)
    else
        x = tonumber(position); y = tonumber(nextPosition); z = tonumber(size)
    end
    if x and y and z then
        cpX, cpY, cpZ = x, y, z; cpActive = true
    end
end

function sampev.onDisableCheckpoint()
    cpActive = false
end

function sampev.onDisableRaceCheckpoint()
    cpActive = false
end

local fontMain = nil
local fontBig  = nil

imgui.OnInitialize(function()
    imgui.SwitchContext()
    imgui.GetIO().IniFilename = nil
    imgui.GetStyle():ScaleAllSizes(MDS)

    local io2    = imgui.GetIO()
    local ranges = io2.Fonts:GetGlyphRangesCyrillic()
    local fpath  = getWorkingDirectory() .. '/../trebucbd.ttf'

    if doesFileExist(fpath) then
        fontMain = io2.Fonts:AddFontFromFileTTF(fpath, 14 * MDS, nil, ranges)
        fontBig  = io2.Fonts:AddFontFromFileTTF(fpath, 17 * MDS, nil, ranges)
    end

    local cfg2 = imgui.ImFontConfig()
    cfg2.MergeMode  = true
    cfg2.PixelSnapH = true
    local rng = imgui.new.ImWchar[3](faR.min_range, faR.max_range, 0)
    io2.Fonts:AddFontFromMemoryCompressedBase85TTF(
        faR.get_font_data_base85('solid'), 15 * MDS, cfg2, rng)

    local st = imgui.GetStyle()
    st.WindowRounding   = 8  * MDS
    st.FrameRounding    = 4  * MDS
    st.ItemSpacing      = imgui.ImVec2(8 * MDS, 6 * MDS)
    st.WindowBorderSize = 1.0 * MDS

    imgui.PushStyleColor(imgui.Col.WindowBg,        imgui.ImVec4(0.059, 0.059, 0.059, 0.97))
    imgui.PushStyleColor(imgui.Col.Border,          imgui.ImVec4(1.00,  0.30,  0.30,  0.25))
    imgui.PushStyleColor(imgui.Col.FrameBg,         imgui.ImVec4(0.10,  0.10,  0.10,  1.00))
    imgui.PushStyleColor(imgui.Col.FrameBgHovered,  imgui.ImVec4(0.14,  0.14,  0.14,  1.00))
    imgui.PushStyleColor(imgui.Col.TitleBg,         imgui.ImVec4(0.06,  0.06,  0.06,  1.00))
    imgui.PushStyleColor(imgui.Col.TitleBgActive,   imgui.ImVec4(0.06,  0.06,  0.06,  1.00))
    imgui.PushStyleColor(imgui.Col.Button,          imgui.ImVec4(0.14,  0.14,  0.14,  1.00))
    imgui.PushStyleColor(imgui.Col.ButtonHovered,   imgui.ImVec4(0.55,  0.10,  0.10,  1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive,    imgui.ImVec4(0.40,  0.06,  0.06,  1.00))
    imgui.PushStyleColor(imgui.Col.CheckMark,       imgui.ImVec4(1.00,  0.30,  0.30,  1.00))
    imgui.PushStyleColor(imgui.Col.Header,          imgui.ImVec4(0.55,  0.10,  0.10,  0.70))
    imgui.PushStyleColor(imgui.Col.HeaderHovered,   imgui.ImVec4(0.70,  0.12,  0.12,  0.90))
    imgui.PushStyleColor(imgui.Col.Separator,       imgui.ImVec4(1.00,  1.00,  1.00,  0.10))
    imgui.PushStyleColor(imgui.Col.Text,            imgui.ImVec4(0.90,  0.90,  0.90,  1.00))
    imgui.PushStyleColor(imgui.Col.TextDisabled,    imgui.ImVec4(0.45,  0.45,  0.45,  1.00))
    imgui.PushStyleColor(imgui.Col.ScrollbarBg,     imgui.ImVec4(0.05,  0.05,  0.05,  0.50))
    imgui.PushStyleColor(imgui.Col.ScrollbarGrab,   imgui.ImVec4(1.00,  0.30,  0.30,  0.60))
    imgui.PushStyleColor(imgui.Col.ScrollbarGrabHovered, imgui.ImVec4(1.00, 0.30, 0.30, 0.90))
end)

imgui.OnFrame(
    function() return gpsLine and cpActive end,
    function(self)
        self.HideCursor = true
        local dl = imgui.GetForegroundDrawList()
        local ok1, px, py, pz = pcall(getCharCoordinates, PLAYER_PED)
        if not ok1 or type(px) ~= 'number' then return end

        local function inFront(wx, wy, wz)
            local ok, cx, cy, cz, lx, ly, lz = pcall(getCameraMatrix)
            if not ok or not cx then return true end
            return (lx-cx)*(wx-cx) + (ly-cy)*(wy-cy) + (lz-cz)*(wz-cz) > 0
        end
        local function proj(wx, wy, wz)
            if not inFront(wx, wy, wz) then return nil end
            local ok, sx, sy = pcall(convert3DCoordsToScreen, wx, wy, wz)
            if not ok or type(sx) ~= 'number' or type(sy) ~= 'number' then return nil end
            if sx < -200 or sx > sw+200 or sy < -200 or sy > sh+200 then return nil end
            return sx, sy
        end

        local colLine  = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.00, 0.30, 0.30, 0.85))
        local colRed   = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
        local colWhite = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.00, 1.00, 1.00, 1.00))
        local lw = 3.0 * MDS

        local originX, originY
        local okS, spx, spy = pcall(convert3DCoordsToScreen, px, py, pz + 0.5)
        if okS and type(spx) == 'number' then
            originX = spx; originY = spy
        else
            originX = sw * 0.5; originY = sh * 0.78
        end

        local sx2, sy2 = proj(cpX, cpY, cpZ + 1.5)
        if sx2 then
            dl:AddLine(imgui.ImVec2(originX, originY), imgui.ImVec2(sx2, sy2), colLine, lw)
        end
        dl:AddCircle(imgui.ImVec2(originX, originY), 5*MDS, colRed, 16, lw)
        dl:AddCircleFilled(imgui.ImVec2(originX, originY), 2.5*MDS, colRed, 16)
        if sx2 then
            dl:AddCircle(imgui.ImVec2(sx2, sy2), 8*MDS, colWhite, 16, lw)
            dl:AddCircleFilled(imgui.ImVec2(sx2, sy2), 3*MDS, colWhite, 8)
        end
    end
)

imgui.OnFrame(
    function() return gpsLine and cpActive end,
    function(self)
        self.HideCursor = true
        if fontMain then imgui.PushFont(fontMain) end
        local HW = 88*MDS; local HH = 24*MDS
        imgui.SetNextWindowPos(imgui.ImVec2(6*MDS, sh * 0.73), imgui.Cond.Always)
        imgui.SetNextWindowSize(imgui.ImVec2(HW, HH), imgui.Cond.Always)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.06, 0.03, 0.03, 0.88))
        imgui.PushStyleColor(imgui.Col.Border,   imgui.ImVec4(1.00, 0.30, 0.30, 0.55))
        imgui.Begin('##gpshud', nil,
            imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize +
            imgui.WindowFlags.NoMove     + imgui.WindowFlags.NoScrollbar)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
        imgui.Text('GPS')
        imgui.PopStyleColor()
        imgui.SameLine(0, 5*MDS)
        local ok1, px, py = pcall(getCharCoordinates, PLAYER_PED)
        if ok1 and type(px) == 'number' then
            local dist = math.floor(getDistanceBetweenCoords2d(px, py, cpX, cpY))
            local distStr = dist >= 1000 and string.format('%.1f km', dist/1000) or tostring(dist)..' m'
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 1.00, 0.50, 1.00))
            imgui.Text(distStr)
            imgui.PopStyleColor()
        end
        imgui.End()
        imgui.PopStyleColor(2)
        if fontMain then imgui.PopFont() end
    end
)

imgui.OnFrame(
    function() return stats_visible end,
    function(self)
        self.HideCursor = true
        if fontMain then imgui.PushFont(fontMain) end
        local SW2 = 130*MDS; local SH2 = 46*MDS
        imgui.SetNextWindowPos(imgui.ImVec2(8*MDS, sh*0.58), imgui.Cond.Once)
        imgui.SetNextWindowSize(imgui.ImVec2(SW2, SH2), imgui.Cond.Always)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.06, 0.03, 0.03, 0.90))
        imgui.PushStyleColor(imgui.Col.Border,   imgui.ImVec4(1.00, 0.30, 0.30, 0.45))
        imgui.Begin('##statshud', nil,
            imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize +
            imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoMove)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
        imgui.Text(fa.MONEY_BILL_WAVE)
        imgui.PopStyleColor()
        imgui.SameLine(0, 4*MDS)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.20, 1.00, 0.40, 1.00))
        imgui.Text('$'..tostring(zarp))
        imgui.PopStyleColor()
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
        imgui.Text(fa.BOX)
        imgui.PopStyleColor()
        imgui.SameLine(0, 4*MDS)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.85, 0.20, 1.00))
        imgui.Text(u8('\xcb\xe0\xf0\xf6\xee\xe2: ')..tostring(larec))
        imgui.PopStyleColor()
        imgui.End()
        imgui.PopStyleColor(2)
        if fontMain then imgui.PopFont() end
    end
)

local menuOpen  = imgui.new.bool(false)
local activeTab = 1
local logoTex   = nil
local logoReady = false

local ig_gruz_index = imgui.new.int(gruz_index)

local editWinOpen = imgui.new.bool(false)
local ig_edit_atr_x = imgui.new.int(math.floor(atr_posX))
local ig_edit_atr_y = imgui.new.int(math.floor(atr_posY))
local ig_edit_dk_x  = imgui.new.int(math.floor(domkrat_posX))
local ig_edit_dk_y  = imgui.new.int(math.floor(domkrat_posY))

local function syncEditSliders()
    ig_edit_atr_x[0] = math.floor(atr_posX)
    ig_edit_atr_y[0] = math.floor(atr_posY)
    ig_edit_dk_x[0]  = math.floor(domkrat_posX)
    ig_edit_dk_y[0]  = math.floor(domkrat_posY)
end

local WIN_W    = 440 * MDS
local HEADER_H = 52  * MDS
local TAB_H    = 32  * MDS
local SEP_H    = 6   * MDS
local PADB     = 10  * MDS
local SCROLL_H = 390 * MDS

local function getWinH()
    if activeTab == 1 then
        return HEADER_H + TAB_H + SEP_H + SCROLL_H + PADB
    elseif activeTab == 2 then
        local sp = 7*MDS; local row = 34*MDS
        return HEADER_H + TAB_H + SEP_H + 4*22*MDS + 3*sp + 2*row + sp + PADB
    else
        local sp = 7*MDS; local row = 34*MDS
        return HEADER_H + TAB_H + SEP_H + 6*22*MDS + 4*sp + 3*row + sp + PADB
    end
end

local function toggleBtn(label, enabled, w, h)
    if enabled then
        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.54, 0.10, 0.10, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.75, 0.13, 0.13, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.38, 0.06, 0.06, 1.0))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 0.85, 0.85, 1.0))
    else
        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.14, 0.14, 0.14, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.22, 0.22, 0.22, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.10, 0.10, 0.10, 1.0))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.65, 0.65, 0.65, 1.0))
    end
    local bW = w or ((WIN_W - 22*MDS) * 0.5)
    local bH = h or 34*MDS
    local clicked = imgui.Button(label, imgui.ImVec2(bW, bH))
    imgui.PopStyleColor(4)
    return clicked
end

local function editBtn(label, w, h)
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.12, 0.12, 0.12, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.54, 0.10, 0.10, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.38, 0.06, 0.06, 1.0))
    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.75, 0.75, 0.75, 1.0))
    local clicked = imgui.Button(label, imgui.ImVec2(w, h))
    imgui.PopStyleColor(4)
    return clicked
end

local function tabBtn(label, idx, w)
    if activeTab == idx then
        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.54, 0.10, 0.10, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.70, 0.13, 0.13, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.38, 0.06, 0.06, 1.0))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 1.0))
    else
        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.08, 0.08, 0.08, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.16, 0.16, 0.16, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.06, 0.06, 0.06, 1.0))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.44, 0.44, 0.44, 1.0))
    end
    local clicked = imgui.Button(label, imgui.ImVec2(w, 28*MDS))
    imgui.PopStyleColor(4)
    imgui.SameLine(0, 3*MDS)
    return clicked
end

local function proLockedBtn(label, w, h)
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.10, 0.10, 0.10, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.14, 0.14, 0.14, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.10, 0.10, 0.10, 1.0))
    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.38, 0.38, 0.38, 1.0))
    local bW = w or ((WIN_W - 22*MDS) * 0.5)
    local bH = h or 34*MDS
    imgui.Button(fa.LOCK .. '  ' .. label, imgui.ImVec2(bW, bH))
    imgui.PopStyleColor(4)
end

imgui.OnFrame(
    function() return menuOpen[0] end,
    function(self)
        self.HideCursor = false
        if fontMain then imgui.PushFont(fontMain) end

        local wh = getWinH()
        imgui.SetNextWindowSize(imgui.ImVec2(WIN_W, wh), imgui.Cond.Always)
        imgui.SetNextWindowPos(
            imgui.ImVec2((sw - WIN_W) * 0.5, (sh - wh) * 0.5),
            imgui.Cond.Once)

        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.059, 0.059, 0.059, 0.98))
        imgui.PushStyleColor(imgui.Col.Border,   imgui.ImVec4(1.00,  1.00,  1.00,  0.08))

        imgui.Begin(u8('##TH_FREE'), menuOpen,
            imgui.WindowFlags.NoTitleBar  +
            imgui.WindowFlags.NoScrollbar +
            imgui.WindowFlags.NoResize)

        local dl = imgui.GetWindowDrawList()
        local wp = imgui.GetWindowPos()

        dl:AddRectFilledMultiColor(
            imgui.ImVec2(wp.x,       wp.y),
            imgui.ImVec2(wp.x+WIN_W, wp.y+HEADER_H),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.106, 0.157, 0.220, 1.0)),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.545, 0.176, 0.176, 1.0)),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.545, 0.176, 0.176, 1.0)),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.106, 0.157, 0.220, 1.0)))
        dl:AddLine(
            imgui.ImVec2(wp.x,       wp.y+HEADER_H),
            imgui.ImVec2(wp.x+WIN_W, wp.y+HEADER_H),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.00, 1.00, 1.00, 0.10)), 1.0*MDS)

        if fontBig then imgui.PushFont(fontBig) end
        local title1 = 'TRUCK HELPER'
        local title2 = '  |  FREE'
        local tsz1 = imgui.CalcTextSize(title1)
        local tsz2 = imgui.CalcTextSize(title2)
        local totalW = tsz1.x + tsz2.x
        local startX = (WIN_W - totalW) * 0.5
        local textY  = (HEADER_H - tsz1.y) * 0.5

        imgui.SetCursorPos(imgui.ImVec2(startX, textY))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 1.00, 1.00, 1.00))
        imgui.Text(title1)
        imgui.PopStyleColor()
        if fontBig then imgui.PopFont() end

        imgui.SameLine(0, 0)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
        imgui.Text(title2)
        imgui.PopStyleColor()

        imgui.SetCursorPos(imgui.ImVec2(WIN_W - 34*MDS, (HEADER_H - 22*MDS) * 0.5))
        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(1.00, 1.00, 1.00, 0.08))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.70, 0.10, 0.10, 1.00))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 0.60))
        if imgui.Button(fa.XMARK .. '##close', imgui.ImVec2(22*MDS, 22*MDS)) then
            menuOpen[0] = false
        end
        imgui.PopStyleColor(4)

        imgui.SetCursorPos(imgui.ImVec2(10*MDS, HEADER_H + 4*MDS))
        local tW = (WIN_W - 23*MDS) / 3
        if tabBtn(fa.SLIDERS     .. '  ' .. u8('\xd4\xf3\xed\xea\xf6\xe8\xe8'),             1, tW) then activeTab = 1 end
        if tabBtn(fa.CHART_BAR   .. '  ' .. u8('\xd1\xf2\xe0\xf2\xe8\xf1\xf2\xe8\xea\xe0'), 2, tW) then activeTab = 2 end
        if tabBtn(fa.CIRCLE_INFO .. '  ' .. u8('\xce \xf1\xea\xf0\xe8\xef\xf2\xe5'),         3, tW) then activeTab = 3 end

        imgui.NewLine()
        imgui.SetCursorPos(imgui.ImVec2(10*MDS, HEADER_H + TAB_H + 2*MDS))
        imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(1.0, 1.0, 1.0, 0.08))
        imgui.Separator()
        imgui.PopStyleColor()

        imgui.SetCursorPos(imgui.ImVec2(10*MDS, HEADER_H + TAB_H + SEP_H + 2*MDS))
        local bW2 = (WIN_W - 22*MDS) * 0.5

        if activeTab == 1 then
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0,0,0,0))
            imgui.BeginChild('##tab1scroll', imgui.ImVec2(WIN_W - 10*MDS, SCROLL_H), false,
                imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoTitleBar)

            if toggleBtn(fa.SHIELD .. '  Anti CarSkill ' .. (anticarskill and '[ON]' or '[OFF]'), anticarskill, bW2) then
                anticarskill = not anticarskill
                toggleNotify('Anti CarSkill', anticarskill)
                saveCfg()
            end
            imgui.SameLine(0, 4*MDS)
            if toggleBtn(fa.BOX_OPEN .. '  ' .. u8('\xc0\xe2\xf2\xee-\xe3\xf0\xf3\xe7 ') .. (autogruz and '[ON]' or '[OFF]'), autogruz, bW2) then
                autogruz = not autogruz
                toggleNotify('\xc0\xe2\xf2\xee-\xe3\xf0\xf3\xe7', autogruz)
                saveCfg()
            end

            imgui.Spacing()

            if toggleBtn(fa.ROUTE .. '  GPS ' .. (gpsLine and '[ON]' or '[OFF]'), gpsLine, bW2) then
                gpsLine = not gpsLine
                toggleNotify('GPS', gpsLine)
                saveCfg()
            end
            imgui.SameLine(0, 4*MDS)
            if toggleBtn(fa.TRAFFIC_LIGHT .. '  ' .. u8('\xc0\xe2\xf2\xee-\xf8\xeb\xe0\xe3\xe1 ') .. (autogate and '[ON]' or '[OFF]'), autogate, bW2) then
                autogate = not autogate
                toggleNotify('\xc0\xe2\xf2\xee-\xf8\xeb\xe0\xe3\xe1\xe0\xf3\xec', autogate)
                saveCfg()
            end

            imgui.Spacing()

            if toggleBtn(fa.TRUCK .. '  ' .. u8('\xcf\xf0\xe8\xf6\xe5\xef ') .. (attach_btn and '[ON]' or '[OFF]'), attach_btn, bW2) then
                attach_btn = not attach_btn
                toggleNotify('\xca\xed\xee\xef\xea\xe0 \xef\xf0\xe8\xf6\xe5\xef\xe0', attach_btn)
                saveCfg()
            end
            imgui.SameLine(0, 4*MDS)
            if toggleBtn(fa.CAR_BURST .. '  ' .. u8('\xc4\xce\xcc\xca\xd0\xc0\xd2 ') .. (domkrat_btn and '[ON]' or '[OFF]'), domkrat_btn, bW2) then
                domkrat_btn = not domkrat_btn
                toggleNotify('\xca\xed. \xc4\xce\xcc\xca\xd0\xc0\xd2', domkrat_btn)
                saveCfg()
            end

            imgui.Spacing()

            if editBtn(fa.PENCIL .. '  ' .. u8('\xd0\xe5\xe4. \xef\xee\xe7\xe8\xf6\xe8\xe8 \xea\xed\xee\xef\xee\xea'), WIN_W - 20*MDS, 32*MDS) then
                syncEditSliders()
                editWinOpen[0] = not editWinOpen[0]
            end

            imgui.Spacing()

            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.65, 0.65, 0.65, 1.0))
            imgui.Text(fa.LIST_OL .. '  ' .. u8('\xc3\xf0\xf3\xe7 (#, 0=') .. u8('\xcf\xee\xf1\xeb\xe5\xe4\xed\xe8\xe9') .. '):')
            imgui.PopStyleColor()
            imgui.SameLine()
            imgui.PushItemWidth(80*MDS)
            imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.10, 0.10, 0.10, 1.0))
            if imgui.InputInt(u8('##gi'), ig_gruz_index) then
                if ig_gruz_index[0] < 0 then ig_gruz_index[0] = 0 end
                gruz_index = ig_gruz_index[0]
                saveCfg()
            end
            imgui.PopStyleColor()
            imgui.PopItemWidth()

            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(1.0, 1.0, 1.0, 0.08))
            imgui.Separator()
            imgui.PopStyleColor()
            imgui.Spacing()

            local dl2 = imgui.GetWindowDrawList()
            local cp  = imgui.GetCursorScreenPos()
            local proBlockH = 130 * MDS
            local proBlockW = WIN_W - 20*MDS
            dl2:AddRectFilled(
                imgui.ImVec2(cp.x - 1*MDS, cp.y - 2*MDS),
                imgui.ImVec2(cp.x + proBlockW, cp.y + proBlockH),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.54, 0.10, 0.10, 0.12)), 6*MDS)
            dl2:AddRect(
                imgui.ImVec2(cp.x - 1*MDS, cp.y - 2*MDS),
                imgui.ImVec2(cp.x + proBlockW, cp.y + proBlockH),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.00, 0.30, 0.30, 0.35)), 6*MDS, 0, 1.0*MDS)

            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
            imgui.Text(fa.CROWN .. '  PRO ' .. u8('\xe2\xe5\xf0\xf1\xe8\xff: \xe4\xee\xef\xee\xeb\xed\xe8\xf2\xe5\xeb\xfc\xed\xfb\xe5 \xf4\xf3\xed\xea\xf6\xe8\xe8:'))
            imgui.PopStyleColor()

            imgui.Spacing()
            proLockedBtn(u8('\xc0\xe2\xf2\xee\xef\xe8\xeb\xee\xf2 (A* \xed\xe0\xe2\xec\xe5\xf8)'), bW2)
            imgui.SameLine(0, 4*MDS)
            proLockedBtn(u8('\xc0\xed\xf2\xe8-\xee\xf2\xf6\xe5\xef \xef\xf0\xe8\xf6\xe5\xef\xe0'), bW2)

            imgui.Spacing()
            proLockedBtn(u8('\xce\xf2\xea\xeb. \xea\xee\xeb\xeb\xe8\xe7\xe8\xe8 \xee\xe1\xfa\xe5\xea\xf2\xee\xe2'), WIN_W - 20*MDS, 30*MDS)

            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.54, 0.10, 0.10, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.75, 0.13, 0.13, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.38, 0.06, 0.06, 1.0))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 1.00))
            if imgui.Button(
                fa.PAPER_PLANE .. '  ' .. u8('\xd5\xee\xf7\xf3 PRO: \xed\xe0\xef\xe8\xf1\xe0\xf2\xfc \xe0\xe2\xf2\xee\xf0\xf3'),
                imgui.ImVec2(WIN_W - 20*MDS, 32*MDS)) then
                openLink('https://t.me/victor_st0')
            end
            imgui.PopStyleColor(4)

            imgui.EndChild()
            imgui.PopStyleColor()
        end

        if activeTab == 2 then
            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
            imgui.Text(fa.MONEY_BILL_WAVE)
            imgui.PopStyleColor()
            imgui.SameLine()
            imgui.Text(u8('\xc7\xe0\xf0\xe0\xe1\xee\xf2\xe0\xed\xee:'))
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.20, 1.00, 0.40, 1.00))
            imgui.Text(string.format('$%d', zarp))
            imgui.PopStyleColor()

            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
            imgui.Text(fa.BOX)
            imgui.PopStyleColor()
            imgui.SameLine()
            imgui.Text(u8('\xcb\xe0\xf0\xf6\xee\xe2 \xef\xee\xeb\xf3\xf7\xe5\xed\xee:'))
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.85, 0.20, 1.00))
            imgui.Text(tostring(larec))
            imgui.PopStyleColor()

            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(1.0, 1.0, 1.0, 0.08))
            imgui.Separator()
            imgui.PopStyleColor()
            imgui.Spacing()

            if toggleBtn(
                fa.TABLE_COLUMNS .. '  ' .. u8('\xcc\xe8\xed\xe8-\xee\xea\xed\xee \xf1\xf2\xe0\xf2. ') .. (stats_visible and '[ON]' or '[OFF]'),
                stats_visible, WIN_W - 26*MDS, 34*MDS) then
                stats_visible = not stats_visible
                saveCfg()
            end

            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.26, 0.06, 0.06, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.45, 0.08, 0.08, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.18, 0.03, 0.03, 1.0))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 0.70, 0.70, 1.0))
            if imgui.Button(
                fa.TRASH .. '  ' .. u8('\xd1\xe1\xf0\xee\xf1\xe8\xf2\xfc \xf1\xf2\xe0\xf2\xe8\xf1\xf2\xe8\xea\xf3'),
                imgui.ImVec2(WIN_W - 26*MDS, 34*MDS)) then
                zarp = 0; larec = 0; saveCfg()
                notify('\xd1\xf2\xe0\xf2\xe8\xf1\xf2\xe8\xea\xe0 \xf1\xe1\xf0\xee\xf8\xe5\xed\xe0')
            end
            imgui.PopStyleColor(4)
        end

        if activeTab == 3 then
            imgui.Spacing()

            local dl3 = imgui.GetWindowDrawList()
            local cp3 = imgui.GetCursorScreenPos()
            local freeBlockH = 38 * MDS
            dl3:AddRectFilled(
                imgui.ImVec2(cp3.x - 1*MDS, cp3.y - 2*MDS),
                imgui.ImVec2(cp3.x + WIN_W - 20*MDS, cp3.y + freeBlockH),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.54, 0.10, 0.10, 0.18)), 4*MDS)

            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
            imgui.Text(fa.CIRCLE_INFO .. '  ' .. u8('\xdd\xf2\xee \xe1\xe5\xf1\xef\xeb\xe0\xf2\xed\xe0\xff \xe2\xe5\xf0\xf1\xe8\xff') .. ' (FREE)')
            imgui.PopStyleColor()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.60, 0.60, 0.60, 1.00))
            imgui.Text(u8('   \xcf\xee\xeb\xed\xe0\xff \xcf\xd0\xce-\xe2\xe5\xf0\xf1\xe8\xff \xe4\xee\xf1\xf2\xf3\xef\xed\xe0 \xf3 \xe0\xe2\xf2\xee\xf0\xe0'))
            imgui.PopStyleColor()

            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(1.0, 1.0, 1.0, 0.08))
            imgui.Separator()
            imgui.PopStyleColor()
            imgui.Spacing()

            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.55, 0.55, 0.55, 1.0))
            imgui.Text(fa.USER .. '  ' .. u8('\xc0\xe2\xf2\xee\xf0:'))
            imgui.PopStyleColor()
            imgui.SameLine()
            imgui.Text('Victor Strand')

            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.55, 0.55, 0.55, 1.0))
            imgui.Text(fa.CODE_BRANCH .. '  ' .. u8('\xc2\xe5\xf0\xf1\xe8\xff:'))
            imgui.PopStyleColor()
            imgui.SameLine()
            imgui.Text('2.0 FREE')

            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(1.0, 1.0, 1.0, 0.08))
            imgui.Separator()
            imgui.PopStyleColor()
            imgui.Spacing()

            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.14, 0.14, 0.14, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.54, 0.10, 0.10, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.38, 0.06, 0.06, 1.0))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 1.00))
            if imgui.Button(
                fa.PAPER_PLANE .. '  @victor_st0  (' .. u8('\xcc\xee\xe9 \xe0\xea\xea\xe0\xf3\xed\xf2') .. ')',
                imgui.ImVec2(WIN_W - 26*MDS, 34*MDS)) then
                openLink('https://t.me/victor_st0')
            end
            imgui.PopStyleColor(4)

            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.14, 0.14, 0.14, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.54, 0.10, 0.10, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.38, 0.06, 0.06, 1.0))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 1.00))
            if imgui.Button(
                fa.PAPER_PLANE .. '  @strand_scripts  (' .. u8('\xcc\xee\xe9 \xea\xe0\xed\xe0\xeb') .. ')',
                imgui.ImVec2(WIN_W - 26*MDS, 34*MDS)) then
                openLink('https://t.me/strand_scripts')
            end
            imgui.PopStyleColor(4)

            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.54, 0.10, 0.10, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.75, 0.13, 0.13, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.38, 0.06, 0.06, 1.0))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 1.00))
            if imgui.Button(
                fa.CROWN .. '  ' .. u8('\xcf\xee\xeb\xf3\xf7\xe8\xf2\xfc PRO: \xed\xe0\xef\xe8\xf1\xe0\xf2\xfc \xe0\xe2\xf2\xee\xf0\xf3'),
                imgui.ImVec2(WIN_W - 26*MDS, 36*MDS)) then
                openLink('https://t.me/victor_st0')
            end
            imgui.PopStyleColor(4)
        end

        imgui.End()
        imgui.PopStyleColor(2)
        if fontMain then imgui.PopFont() end
    end
)

imgui.OnFrame(
    function() return editWinOpen[0] end,
    function(self)
        self.HideCursor = false
        if fontMain then imgui.PushFont(fontMain) end

        local EW = 400*MDS; local EH = 280*MDS
        imgui.SetNextWindowSize(imgui.ImVec2(EW, EH), imgui.Cond.Always)
        imgui.SetNextWindowPos(
            imgui.ImVec2((sw-EW)*0.5, (sh-EH)*0.5), imgui.Cond.Once)

        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.059, 0.059, 0.059, 0.98))
        imgui.PushStyleColor(imgui.Col.Border,   imgui.ImVec4(1.00,  1.00,  1.00,  0.08))

        imgui.Begin(u8('##editpos'), editWinOpen,
            imgui.WindowFlags.NoTitleBar  +
            imgui.WindowFlags.NoScrollbar +
            imgui.WindowFlags.NoResize)

        local dl2 = imgui.GetWindowDrawList()
        local wp2 = imgui.GetWindowPos()
        dl2:AddRectFilledMultiColor(
            imgui.ImVec2(wp2.x, wp2.y),
            imgui.ImVec2(wp2.x+EW, wp2.y+36*MDS),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.106, 0.157, 0.220, 1.0)),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.545, 0.176, 0.176, 1.0)),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.545, 0.176, 0.176, 1.0)),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.106, 0.157, 0.220, 1.0)))
        dl2:AddLine(
            imgui.ImVec2(wp2.x, wp2.y+36*MDS),
            imgui.ImVec2(wp2.x+EW, wp2.y+36*MDS),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.00, 1.00, 1.00, 0.10)), 1.0*MDS)

        if fontBig then imgui.PushFont(fontBig) end
        local titleT = fa.UP_DOWN_LEFT_RIGHT .. '  ' .. u8('\xd0\xe5\xe4\xe0\xea\xf2\xee\xf0 \xef\xee\xe7\xe8\xf6\xe8\xe9')
        local titleSz = imgui.CalcTextSize(titleT)
        imgui.SetCursorPos(imgui.ImVec2((EW-titleSz.x)*0.5, (36*MDS-titleSz.y)*0.5))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 1.00, 1.00, 1.00))
        imgui.Text(titleT)
        imgui.PopStyleColor()
        if fontBig then imgui.PopFont() end

        imgui.SetCursorPos(imgui.ImVec2(EW-30*MDS, 7*MDS))
        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(1.00, 1.00, 1.00, 0.08))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.70, 0.10, 0.10, 1.00))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 0.60))
        if imgui.Button(fa.XMARK..'##ew', imgui.ImVec2(22*MDS, 22*MDS)) then
            editWinOpen[0] = false
        end
        imgui.PopStyleColor(4)

        imgui.SetCursorPos(imgui.ImVec2(12*MDS, 44*MDS))
        local slW = EW - 24*MDS

        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
        imgui.Text(fa.TRUCK .. '  ' .. u8('\xca\xed\xee\xef\xea\xe0 \xcf\xd0\xc8\xd6\xc5\xcf'))
        imgui.PopStyleColor()
        imgui.SetCursorPosX(12*MDS)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.55, 0.55, 0.55, 1.0))
        imgui.Text('X:')
        imgui.PopStyleColor()
        imgui.SameLine()
        imgui.PushItemWidth(slW - 20*MDS)
        imgui.PushStyleColor(imgui.Col.FrameBg,          imgui.ImVec4(0.10, 0.10, 0.10, 1.0))
        imgui.PushStyleColor(imgui.Col.SliderGrab,       imgui.ImVec4(1.00, 0.30, 0.30, 1.0))
        imgui.PushStyleColor(imgui.Col.SliderGrabActive, imgui.ImVec4(0.80, 0.10, 0.10, 1.0))
        if imgui.SliderInt('##atrx', ig_edit_atr_x, 0, math.floor(sw-180*MDS)) then
            atr_posX = ig_edit_atr_x[0]; saveCfg()
        end
        imgui.PopStyleColor(3); imgui.PopItemWidth()
        imgui.SetCursorPosX(12*MDS)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.55, 0.55, 0.55, 1.0))
        imgui.Text('Y:')
        imgui.PopStyleColor()
        imgui.SameLine()
        imgui.PushItemWidth(slW - 20*MDS)
        imgui.PushStyleColor(imgui.Col.FrameBg,          imgui.ImVec4(0.10, 0.10, 0.10, 1.0))
        imgui.PushStyleColor(imgui.Col.SliderGrab,       imgui.ImVec4(1.00, 0.30, 0.30, 1.0))
        imgui.PushStyleColor(imgui.Col.SliderGrabActive, imgui.ImVec4(0.80, 0.10, 0.10, 1.0))
        if imgui.SliderInt('##atry', ig_edit_atr_y, 0, math.floor(sh-60*MDS)) then
            atr_posY = ig_edit_atr_y[0]; saveCfg()
        end
        imgui.PopStyleColor(3); imgui.PopItemWidth()

        imgui.Spacing()
        imgui.SetCursorPosX(12*MDS)
        imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(1.0, 1.0, 1.0, 0.08))
        imgui.Separator()
        imgui.PopStyleColor()
        imgui.Spacing()
        imgui.SetCursorPosX(12*MDS)

        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.30, 0.30, 1.00))
        imgui.Text(fa.CAR_BURST .. '  ' .. u8('\xca\xed\xee\xef\xea\xe0 \xc4\xce\xcc\xca\xd0\xc0\xd2'))
        imgui.PopStyleColor()
        imgui.SetCursorPosX(12*MDS)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.55, 0.55, 0.55, 1.0))
        imgui.Text('X:')
        imgui.PopStyleColor()
        imgui.SameLine()
        imgui.PushItemWidth(slW - 20*MDS)
        imgui.PushStyleColor(imgui.Col.FrameBg,          imgui.ImVec4(0.10, 0.10, 0.10, 1.0))
        imgui.PushStyleColor(imgui.Col.SliderGrab,       imgui.ImVec4(1.00, 0.30, 0.30, 1.0))
        imgui.PushStyleColor(imgui.Col.SliderGrabActive, imgui.ImVec4(0.80, 0.10, 0.10, 1.0))
        if imgui.SliderInt('##dkx', ig_edit_dk_x, 0, math.floor(sw-130*MDS)) then
            domkrat_posX = ig_edit_dk_x[0]; saveCfg()
        end
        imgui.PopStyleColor(3); imgui.PopItemWidth()
        imgui.SetCursorPosX(12*MDS)
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.55, 0.55, 0.55, 1.0))
        imgui.Text('Y:')
        imgui.PopStyleColor()
        imgui.SameLine()
        imgui.PushItemWidth(slW - 20*MDS)
        imgui.PushStyleColor(imgui.Col.FrameBg,          imgui.ImVec4(0.10, 0.10, 0.10, 1.0))
        imgui.PushStyleColor(imgui.Col.SliderGrab,       imgui.ImVec4(1.00, 0.30, 0.30, 1.0))
        imgui.PushStyleColor(imgui.Col.SliderGrabActive, imgui.ImVec4(0.80, 0.10, 0.10, 1.0))
        if imgui.SliderInt('##dky', ig_edit_dk_y, 0, math.floor(sh-60*MDS)) then
            domkrat_posY = ig_edit_dk_y[0]; saveCfg()
        end
        imgui.PopStyleColor(3); imgui.PopItemWidth()

        imgui.End()
        imgui.PopStyleColor(2)
        if fontMain then imgui.PopFont() end
    end
)

local ATR_SW   = 36  * MDS
local ATR_MW   = 130 * MDS
local ATR_BH   = 45  * MDS
local ATR_R    = 8   * MDS
local ATR_WW   = ATR_SW + ATR_MW
local ARR_SZ   = 26  * MDS
local ARR_GAP  = 4   * MDS

imgui.OnFrame(
    function() return attach_btn end,
    function(self)
        self.HideCursor = false

        local totalW = atr_moveMode and (ARR_SZ + ARR_GAP + ATR_WW + ARR_GAP + ARR_SZ) or ATR_WW
        local totalH = atr_moveMode and (ARR_SZ + ARR_GAP + ATR_BH + ARR_GAP + ARR_SZ) or ATR_BH

        atr_posX = math.max(0, math.min(sw - totalW, atr_posX))
        atr_posY = math.max(0, math.min(sh - totalH, atr_posY))

        imgui.SetNextWindowPos(imgui.ImVec2(atr_posX, atr_posY), imgui.Cond.Always)
        imgui.SetNextWindowSize(imgui.ImVec2(totalW, totalH), imgui.Cond.Always)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0,0,0,0))
        imgui.PushStyleColor(imgui.Col.Border,   imgui.ImVec4(0,0,0,0))

        imgui.Begin('##atr', nil,
            imgui.WindowFlags.NoTitleBar  + imgui.WindowFlags.NoResize  +
            imgui.WindowFlags.NoMove      + imgui.WindowFlags.NoScrollbar +
            imgui.WindowFlags.NoBackground)

        local dl = imgui.GetWindowDrawList()
        local wp = imgui.GetWindowPos()

        local bX = atr_moveMode and (ARR_SZ + ARR_GAP) or 0
        local bY = atr_moveMode and (ARR_SZ + ARR_GAP) or 0

        if atr_moveMode then
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.28,0.06,0.06,0.92))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.54,0.10,0.10,1.00))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.18,0.03,0.03,1.00))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00,0.30,0.30,1.00))
            imgui.GetStyle().FrameRounding = 6*MDS

            imgui.SetCursorPos(imgui.ImVec2(bX + ATR_WW/2 - ARR_SZ/2, 0))
            if imgui.Button(fa.ANGLE_UP, imgui.ImVec2(ARR_SZ, ARR_SZ)) then
                atr_posY = atr_posY - ATR_STEP; saveCfg()
            end
            imgui.SetCursorPos(imgui.ImVec2(bX + ATR_WW/2 - ARR_SZ/2, bY + ATR_BH + ARR_GAP))
            if imgui.Button(fa.ANGLE_DOWN, imgui.ImVec2(ARR_SZ, ARR_SZ)) then
                atr_posY = atr_posY + ATR_STEP; saveCfg()
            end
            imgui.SetCursorPos(imgui.ImVec2(0, bY + ATR_BH/2 - ARR_SZ/2))
            if imgui.Button(fa.ANGLE_LEFT, imgui.ImVec2(ARR_SZ, ARR_SZ)) then
                atr_posX = atr_posX - ATR_STEP; saveCfg()
            end
            imgui.SetCursorPos(imgui.ImVec2(bX + ATR_WW + ARR_GAP, bY + ATR_BH/2 - ARR_SZ/2))
            if imgui.Button(fa.ANGLE_RIGHT, imgui.ImVec2(ARR_SZ, ARR_SZ)) then
                atr_posX = atr_posX + ATR_STEP; saveCfg()
            end

            dl:AddRect(
                imgui.ImVec2(wp.x+bX-2*MDS, wp.y+bY-2*MDS),
                imgui.ImVec2(wp.x+bX+ATR_WW+2*MDS, wp.y+bY+ATR_BH+2*MDS),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.00,0.30,0.30,0.65)),
                ATR_R, 0, 2*MDS)
            imgui.PopStyleColor(4)
        end

        dl:AddRectFilled(
            imgui.ImVec2(wp.x+bX+3*MDS, wp.y+bY+5*MDS),
            imgui.ImVec2(wp.x+bX+ATR_WW+3*MDS, wp.y+bY+ATR_BH+3*MDS),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0,0,0,0.45)), ATR_R)

        local lh = imgui.IsMouseHoveringRect(
            imgui.ImVec2(wp.x+bX, wp.y+bY),
            imgui.ImVec2(wp.x+bX+ATR_SW, wp.y+bY+ATR_BH))
        local lbg = lh
            and imgui.ImVec4(0.42,0.10,0.10,1.0)
            or  imgui.ImVec4(0.22,0.05,0.05,1.0)
        dl:AddRectFilled(
            imgui.ImVec2(wp.x+bX, wp.y+bY),
            imgui.ImVec2(wp.x+bX+ATR_SW, wp.y+bY+ATR_BH),
            imgui.ColorConvertFloat4ToU32(lbg), ATR_R)
        dl:AddRectFilled(
            imgui.ImVec2(wp.x+bX+ATR_SW-ATR_R, wp.y+bY),
            imgui.ImVec2(wp.x+bX+ATR_SW, wp.y+bY+ATR_BH),
            imgui.ColorConvertFloat4ToU32(lbg), 0)
        dl:AddLine(
            imgui.ImVec2(wp.x+bX+ATR_SW, wp.y+bY+6*MDS),
            imgui.ImVec2(wp.x+bX+ATR_SW, wp.y+bY+ATR_BH-6*MDS),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1,1,1,0.10)), 1)

        local rh = imgui.IsMouseHoveringRect(
            imgui.ImVec2(wp.x+bX+ATR_SW, wp.y+bY),
            imgui.ImVec2(wp.x+bX+ATR_WW, wp.y+bY+ATR_BH))
        local rbg
        if atr_selecting     then rbg = imgui.ImVec4(0.20,0.05,0.05,1.0)
        elseif rh            then rbg = imgui.ImVec4(0.65,0.12,0.12,1.0)
        else                      rbg = imgui.ImVec4(0.50,0.10,0.10,1.0) end
        dl:AddRectFilled(
            imgui.ImVec2(wp.x+bX+ATR_SW,  wp.y+bY),
            imgui.ImVec2(wp.x+bX+ATR_WW,  wp.y+bY+ATR_BH),
            imgui.ColorConvertFloat4ToU32(rbg), ATR_R)
        dl:AddRectFilled(
            imgui.ImVec2(wp.x+bX+ATR_SW,       wp.y+bY),
            imgui.ImVec2(wp.x+bX+ATR_SW+ATR_R, wp.y+bY+ATR_BH),
            imgui.ColorConvertFloat4ToU32(rbg), 0)

        if fontMain then imgui.PushFont(fontMain) end
        local hi = fa.HAND_POINTER
        local hs = imgui.CalcTextSize(hi)
        imgui.SetCursorPos(imgui.ImVec2(bX+(ATR_SW-hs.x)*0.5, bY+(ATR_BH-hs.y)*0.5))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00,0.30,0.30,1.0))
        imgui.Text(hi)
        imgui.PopStyleColor()

        local ti  = fa.TRUCK
        local bt  = u8('\xcf\xd0\xc8\xd6\xc5\xcf\xc8\xd2\xdc')
        local ts  = imgui.CalcTextSize(ti)
        local bs2 = imgui.CalcTextSize(bt)
        local gp  = 8*MDS
        local tw  = ts.x + gp + bs2.x
        local sx  = bX + ATR_SW + (ATR_MW-tw)*0.5
        local sy  = bY + (ATR_BH-ts.y)*0.5
        imgui.SetCursorPos(imgui.ImVec2(sx, sy))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1,1,1,1))
        imgui.Text(ti)
        imgui.SetCursorPos(imgui.ImVec2(sx+ts.x+gp, sy))
        imgui.Text(bt)
        imgui.PopStyleColor()
        if fontMain then imgui.PopFont() end

        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,1,1,0))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(1,1,1,0))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0,0,0,0))
        imgui.GetStyle().FrameRounding = ATR_R

        imgui.SetCursorPos(imgui.ImVec2(bX, bY))
        if imgui.Button('##al', imgui.ImVec2(ATR_SW, ATR_BH)) then
            if atr_moveMode then
                atr_moveMode = false; saveCfg()
            else
                atr_autoMode = not atr_autoMode
            end
        end

        imgui.SetCursorPos(imgui.ImVec2(bX+ATR_SW, bY))
        if imgui.Button('##am', imgui.ImVec2(ATR_MW, ATR_BH)) then
            if not atr_moveMode then
                if atr_autoMode then
                    local v = getNearestTrailer()
                    if v then doAttach(v) end
                elseif atr_trailer ~= nil then
                    doAttach(atr_trailer)
                    atr_trailer = nil
                end
            end
        end
        atr_selecting = imgui.IsItemActive()
        imgui.PopStyleColor(4)

        if atr_autoMode then
            dl:AddCircleFilled(
                imgui.ImVec2(wp.x+bX+ATR_SW-7*MDS, wp.y+bY+ATR_BH-7*MDS),
                3.5*MDS,
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.3,1.0,0.5,1.0)), 8)
        end
        if atr_moveMode then
            dl:AddCircleFilled(
                imgui.ImVec2(wp.x+bX+7*MDS, wp.y+bY+7*MDS),
                3.5*MDS,
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0,0.30,0.30,1.0)), 8)
        end

        imgui.End()
        imgui.PopStyleColor(2)

        if atr_selecting and not atr_autoMode and not atr_moveMode then
            local ox = sw/2 - ATR_RADIUS/2
            local oy = sh/3.3 - ATR_RADIUS/2
            local dlf = imgui.GetForegroundDrawList()
            local cc  = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1,1,1,0.85))
            local tk  = 2.5*MDS
            dlf:AddLine(imgui.ImVec2(ox,           oy),            imgui.ImVec2(ox+ATR_RADIUS,oy),            cc,tk)
            dlf:AddLine(imgui.ImVec2(ox,           oy),            imgui.ImVec2(ox,           oy+ATR_RADIUS), cc,tk)
            dlf:AddLine(imgui.ImVec2(ox,           oy+ATR_RADIUS), imgui.ImVec2(ox+ATR_RADIUS,oy+ATR_RADIUS), cc,tk)
            dlf:AddLine(imgui.ImVec2(ox+ATR_RADIUS,oy),            imgui.ImVec2(ox+ATR_RADIUS,oy+ATR_RADIUS), cc,tk)
            if atr_trailer ~= nil and doesVehicleExist(atr_trailer) then
                local ok3,vx3,vy3,vz3 = pcall(getCarCoordinates, atr_trailer)
                if ok3 then
                    local ok4,sx3,sy3 = pcall(convert3DCoordsToScreen,vx3,vy3,vz3)
                    if ok4 and sx3 and sy3 then
                        local cy2 = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.00,0.30,0.30,0.95))
                        dlf:AddLine(imgui.ImVec2(sx3,sy3), imgui.ImVec2(ox+ATR_RADIUS/2,oy+ATR_RADIUS/2), cy2,2*MDS)
                        dlf:AddCircle(imgui.ImVec2(sx3,sy3),9*MDS,cy2,16,2*MDS)
                    end
                end
            end
        end
    end
)

local DK_W  = 120 * MDS
local DK_H  = 44  * MDS
local DK_R  = 9   * MDS

imgui.OnFrame(
    function() return domkrat_btn end,
    function(self)
        self.HideCursor = false

        domkrat_posX = math.max(0, math.min(sw - DK_W, domkrat_posX))
        domkrat_posY = math.max(0, math.min(sh - DK_H, domkrat_posY))

        imgui.SetNextWindowPos(imgui.ImVec2(domkrat_posX, domkrat_posY), imgui.Cond.Always)
        imgui.SetNextWindowSize(imgui.ImVec2(DK_W, DK_H), imgui.Cond.Always)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0,0,0,0))
        imgui.PushStyleColor(imgui.Col.Border,   imgui.ImVec4(0,0,0,0))

        imgui.Begin('##domkrat', nil,
            imgui.WindowFlags.NoTitleBar  + imgui.WindowFlags.NoResize  +
            imgui.WindowFlags.NoMove      + imgui.WindowFlags.NoScrollbar +
            imgui.WindowFlags.NoBackground)

        local dl  = imgui.GetWindowDrawList()
        local wp  = imgui.GetWindowPos()
        local hov = imgui.IsMouseHoveringRect(
            imgui.ImVec2(wp.x, wp.y),
            imgui.ImVec2(wp.x + DK_W, wp.y + DK_H))

        dl:AddRectFilled(
            imgui.ImVec2(wp.x+3*MDS, wp.y+4*MDS),
            imgui.ImVec2(wp.x+DK_W+2*MDS, wp.y+DK_H+3*MDS),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0,0,0,0.40)), DK_R)

        local bgCol = hov
            and imgui.ImVec4(0.65, 0.12, 0.12, 1.0)
            or  imgui.ImVec4(0.50, 0.10, 0.10, 1.0)
        dl:AddRectFilled(
            imgui.ImVec2(wp.x, wp.y),
            imgui.ImVec2(wp.x+DK_W, wp.y+DK_H),
            imgui.ColorConvertFloat4ToU32(bgCol), DK_R)
        dl:AddRect(
            imgui.ImVec2(wp.x, wp.y),
            imgui.ImVec2(wp.x+DK_W, wp.y+DK_H),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.00, 0.30, 0.30, 0.75)),
            DK_R, 0, 1.5*MDS)

        if fontMain then imgui.PushFont(fontMain) end
        local lbl  = fa.CAR_BURST .. '  ' .. u8('\xc4\xce\xcc\xca\xd0\xc0\xd2')
        local lsz  = imgui.CalcTextSize(lbl)
        imgui.SetCursorPos(imgui.ImVec2((DK_W - lsz.x)*0.5, (DK_H - lsz.y)*0.5))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.00, 0.85, 0.85, 1.0))
        imgui.Text(lbl)
        imgui.PopStyleColor()
        if fontMain then imgui.PopFont() end

        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,1,1,0))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(1,1,1,0))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0,0,0,0))
        imgui.SetCursorPos(imgui.ImVec2(0, 0))
        if imgui.Button('##dk', imgui.ImVec2(DK_W, DK_H)) then
            if isCharInAnyCar(PLAYER_PED) then
                local ok, car = pcall(storeCarCharIsInNoSave, PLAYER_PED)
                if ok and car and doesVehicleExist(car) then
                    local px, py, pz = getCharCoordinates(PLAYER_PED)
                    pcall(setCarCoordinates, car, px, py, pz + 0.5)
                    notify('\xc4\xee\xec\xea\xf0\xe0\xf2!')
                end
            end
        end
        imgui.PopStyleColor(4)

        imgui.End()
        imgui.PopStyleColor(2)
    end
)

function main()
    pcall(function()
        local lfs = require('lfs')
        lfs.mkdir(FOLDER)
    end)

    lua_thread.create(function()
        if not doesFileExist(SOUND_PATH) then
            local ok, req = pcall(require, 'requests')
            if ok and req then
                local r, resp = pcall(req.get, SOUND_URL)
                if r and resp and resp.status_code == 200 then
                    local d = resp.content or resp.text
                    if d then
                        local f = io.open(SOUND_PATH, 'wb')
                        if f then f:write(d); f:close() end
                    end
                end
            end
        end
    end)

    lua_thread.create(function()
        if not doesFileExist(LOGO_PATH) then
            local ok2, req2 = pcall(require, 'requests')
            if ok2 and req2 then
                local r2, resp2 = pcall(req2.get, LOGO_URL)
                if r2 and resp2 and resp2.status_code == 200 then
                    local d2 = resp2.content or resp2.text
                    if d2 and d2:sub(1,4) == '\x89PNG' then
                        local f2 = io.open(LOGO_PATH, 'wb')
                        if f2 then f2:write(d2); f2:close() end
                    end
                end
            end
        end
        logoReady = true
    end)

    imgui.OnFrame(
        function() return logoReady and not logoTex end,
        function()
            if doesFileExist(LOGO_PATH) then
                logoTex = imgui.CreateTextureFromFile(LOGO_PATH)
            end
            logoReady = false
        end
    )

    while not isSampAvailable()          do wait(100) end
    while not sampIsLocalPlayerSpawned() do wait(100) end

    sampRegisterChatCommand('tlog', function()
        tlog_enabled = not tlog_enabled
        if tlog_enabled then
            local f = io.open(TLOG_PATH, 'w')
            if f then
                f:write('=== Truck Helper chat log ===\n')
                f:write(os.date('%Y-%m-%d %H:%M:%S') .. '\n\n')
                f:close()
            end
            notify('\xcb\xee\xe3 \xc2\xcb\xae\xd7\xc5\xcd: ' .. TLOG_PATH)
        else
            notify('\xcb\xee\xe3 \xc2\xdb\xcb\xd7\xc5\xcd')
        end
    end)

    sampRegisterChatCommand('truck', function()
        menuOpen[0] = not menuOpen[0]
        if menuOpen[0] then playMenuSound() end
    end)

    sampRegisterChatCommand('atrmove', function()
        if not attach_btn then
            notify('\xca\xed\xee\xef\xea\xe0 \xef\xf0\xe8\xf6\xe5\xef\xe0 \xe2\xfb\xea\xeb\xfe\xf7\xe5\xed\xe0!')
            return
        end
        atr_moveMode = not atr_moveMode
        if atr_moveMode then
            notify('\xd0\xe5\xe6\xe8\xec \xef\xe5\xf0\xe5\xec\xe5\xf9\xe5\xed\xe8\xff \xc2\xcb\xae\xd7\xc5\xcd')
        else
            notify('\xcf\xee\xe7\xe8\xf6\xe8\xff \xf1\xee\xf5\xf0\xe0\xed\xe5\xed\xe0')
            saveCfg()
        end
    end)

    lua_thread.create(function()
        while true do
            wait(333)
            if autogate then pcall(doAutoGate) end
        end
    end)

    notify('v2.0 FREE \xe7\xe0\xe3\xf0\xf3\xe6\xe5\xed! /truck - \xec\xe5\xed\xfe')

    while true do
        if attach_btn and atr_selecting and not atr_autoMode and not atr_moveMode then
            local okC2, myCar2 = pcall(getCarCharIsUsing, PLAYER_PED)
            if okC2 and myCar2 and isCharInAnyCar(PLAYER_PED) then
                local ox2 = sw/2 - ATR_RADIUS/2
                local oy2 = sh/3.3 - ATR_RADIUS/2
                local okV2, vehs2 = pcall(getAllVehicles)
                if okV2 and vehs2 then
                    local found2 = false
                    for _, v2 in ipairs(vehs2) do
                        if v2 ~= myCar2 then
                            local ok5,vx5,vy5,vz5 = pcall(getCarCoordinates, v2)
                            if ok5 then
                                local px3,py3,pz3 = getCharCoordinates(PLAYER_PED)
                                local d2 = getDistanceBetweenCoords3d(px3,py3,pz3,vx5,vy5,vz5)
                                if d2 <= 20 then
                                    local ok6,sx5,sy5 = pcall(convert3DCoordsToScreen,vx5,vy5,vz5)
                                    if ok6 and sx5 and sy5 then
                                        local ok7, onS = pcall(isCarOnScreen, v2)
                                        if ok7 and onS then
                                            if sx5>=ox2 and sx5<=ox2+ATR_RADIUS
                                            and sy5>=oy2 and sy5<=oy2+ATR_RADIUS then
                                                atr_trailer = v2
                                                found2 = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if not found2 then atr_trailer = nil end
                end
            else
                atr_selecting = false
                atr_trailer   = nil
            end
        end

        if WIDGET_RADAR ~= nil and isWidgetSwipedLeft(WIDGET_RADAR) then
            menuOpen[0] = not menuOpen[0]
            if menuOpen[0] then playMenuSound() end
            wait(250)
        end

        wait(10)
    end
end
