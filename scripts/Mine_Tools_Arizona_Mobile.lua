script_name('Mine Tools')
script_author('Victor Strand')
script_description('special edition - MonetLoader Android')
script_version('1.0-monet')
script_properties('work-in-pause')
require('lib.samp.events')
local imgui   = require('mimgui')
local ffi     = require('ffi')
local enc     = require('encoding')
enc.default   = 'CP1251'
local u8      = enc.UTF8
local inicfg  = require('inicfg')
local jsoncfg = require('jsoncfg')
local requests= require('requests')
local lfs     = require('lfs')
local sampev  = require('lib.samp.events')
local mem     = require('memory')
local MDS = MONET_DPI_SCALE
local new = imgui.new
local SOUND_URL  = 'https://raw.githubusercontent.com/victorstrand250-cpu/Photo-Katalog/b4d2477ff14db881184baa85def75fa6a9fa146c/faaah.mp3'
local SOUND_DIR  = getWorkingDirectory()..'/MineTools'
local SOUND_FILE = SOUND_DIR..'/ore_pickup.mp3'
local bass            = nil
local oreStream       = 0
local oreSoundEnabled = new.bool(true)
pcall(function()
    bass = ffi.load('libbass.so')
    ffi.cdef[[
        int           BASS_Init(int device, unsigned long freq, unsigned long flags, void* win, void* clsid);
        unsigned long BASS_StreamCreateFile(int mem, const char* file, unsigned long long offset, unsigned long long length, unsigned long flags);
        unsigned long BASS_StreamCreateURL(const char* url, unsigned long offset, unsigned long flags, void* proc, void* user);
        int           BASS_ChannelPlay(unsigned long handle, int restart);
        int           BASS_ChannelStop(unsigned long handle);
        int           BASS_ChannelSetAttribute(unsigned long handle, unsigned long attrib, float value);
        int           BASS_StreamFree(unsigned long handle);
    ]]
    pcall(function() bass.BASS_Init(-1, 44100, 0, nil, nil) end)
end)
local effil = nil
pcall(function() effil = require('effil') end)
local function asyncDownloadFile(url, path, onDone)
    local function finish(ok) if onDone then pcall(onDone, ok) end end
    if not (url and url ~= '' and path and path ~= '') then finish(false); return end
    if effil then
        local runner = effil.thread(function(u)
            local ok_h, https = pcall(require, 'ssl.https')
            if not ok_h or not https then return {false} end
            local ok_r, body, code = pcall(https.request, u)
            if ok_r and type(body) == 'string' then return {body, code} end
            return {false}
        end)
        local ok_run, handle = pcall(runner, url)
        if not ok_run or not handle then finish(false); return end
        lua_thread.create(function()
            local startT = os.clock()
            local r = handle:get(0)
            while not r do
                local st = handle:status()
                if st == 'failed' or st == 'cancelled' or st == 'canceled' then break end
                if os.clock() - startT > 60 then break end
                wait(0)
                r = handle:get(0)
            end
            pcall(function() handle:cancel(0) end)
            local body = r and r[1]
            if type(body) == 'string' and #body > 100 then
                local f = io.open(path, 'wb')
                if f then f:write(body); f:close(); finish(true); return end
            end
            finish(false)
        end)
    else
        lua_thread.create(function()
            local ok, resp = pcall(requests.get, url)
            if ok and resp and resp.status_code == 200 and resp.text and #resp.text > 100 then
                local f = io.open(path, 'wb')
                if f then f:write(resp.text); f:close(); finish(true); return end
            end
            finish(false)
        end)
    end
end
local function playOreSound()
    if not bass or not oreSoundEnabled[0] then return end
    lua_thread.create(function()
        if not doesFileExist(SOUND_FILE) then return end
        pcall(function()
            if oreStream ~= 0 then
                bass.BASS_ChannelStop(oreStream)
                bass.BASS_StreamFree(oreStream)
                oreStream = 0
            end
            oreStream = bass.BASS_StreamCreateFile(0, SOUND_FILE, 0, 0, 0)
            if oreStream ~= 0 then
                bass.BASS_ChannelSetAttribute(oreStream, 2, 0.8)
                bass.BASS_ChannelPlay(oreStream, 1)
            end
        end)
    end)
end
local function downloadOreSound()
    lua_thread.create(function()
        while not isSampAvailable() do wait(500) end
        pcall(function()
            if not doesDirectoryExist(SOUND_DIR) then
                createDirectory(SOUND_DIR)
            end
        end)
        if doesFileExist(SOUND_FILE) then return end
        asyncDownloadFile(SOUND_URL, SOUND_FILE)
    end)
end
local AUTHOR_TG  = 'https://t.me/victor_st0'
local CHANNEL_TG = 'https://t.me/strand_scripts'
local CAT_CFG    = 'catalog_scripts'
local CAT_FOLDER = getWorkingDirectory()..'/MineTools'
local CAT_IMAGES = CAT_FOLDER..'/images'
local DEFAULT_SCRIPTS = {
    {
        name        = u8('\xc1\xee\xf2 \xed\xe0 \xd8\xe0\xf5\xf2\xf3'),
        short       = u8('\xd1\xf2\xe0\xe1\xe8\xeb\xfc\xed\xfb\xe9 \xe8 \xe1\xe5\xe7\xee\xef\xe0\xf1\xed\xfb\xe9 \xe1\xee\xf2 \xe4\xeb\xff \xf8\xe0\xf5\xf2\xfb. \xc1\xe5\xe7\xee\xef\xe0\xf1\xed\xee\xf1\xf2\xfc \xef\xee\xeb\xed\xee\xf1\xf2\xfc\xfe \xe0\xe2\xf2\xee\xec\xe0\xf2\xe8\xe7\xe8\xf0\xee\xe2\xe0\xed\xe0!'),
        vip         = true,
        featured    = true,
        price_text  = u8('\xd6\xe5\xed\xe0: 400 \xf0\xf3\xe1 / 200 \xe3\xf0\xed \xe2 \xec\xe5\xf1\xff\xf6'),
        tg_link     = 'https://t.me/strand_scripts/265',
        img_url     = 'https://raw.githubusercontent.com/victorstrand250-cpu/Photo-Katalog/refs/heads/main/file_00000000be8c720a8804ceec0c4c3957.png',
        img_file    = 'mine_bot_v2.png',
        img_ratio   = 9/16,
    },
    {
        name        = u8('\xc1\xee\xf2 \xd4\xe5\xf0\xec\xe0 \xd5\xeb\xee\xef\xea\xe0/\xcb\xfc\xed\xe0'),
        short       = u8('\xc0\xe2\xf2\xee\xec\xe0\xf2\xe8\xf7\xe5\xf1\xea\xe8\xe9 \xe1\xee\xf2 \xe4\xeb\xff \xf1\xe1\xee\xf0\xe0 \xf5\xeb\xee\xef\xea\xe0 \xe8 \xeb\xfc\xed\xe0 \xed\xe0 \xf1\xe5\xf0\xe2\xe5\xf0\xe5 Arizona RP.'),
        vip         = true,
        price_month = '3$',
        price_year  = '28$',
        tg_link     = AUTHOR_TG,
        img_url     = 'https://raw.githubusercontent.com/victorstrand250-cpu/Photo-Katalog/refs/heads/main/file_0000000036a0720abc49af32cb501c9a.png',
        img_file    = 'farm_bot.png',
    },
    {
        name        = u8('\xc1\xee\xf2 \xd2\xd0\xc0\xcc\xc2\xc0\xc9'),
        short       = u8('\xc0\xe2\xf2\xee\xec\xe0\xf2\xe8\xf7\xe5\xf1\xea\xe8\xe9 \xe1\xee\xf2 \xe2\xee\xe4\xe8\xf2\xe5\xeb\xff \xf2\xf0\xe0\xec\xe2\xe0\xff. \xc1\xe5\xf1\xef\xeb\xe0\xf2\xed\xee \xe4\xeb\xff \xea\xe0\xe6\xe4\xee\xe3\xee!'),
        vip         = false,
        price_month = nil,
        price_year  = nil,
        tg_link     = CHANNEL_TG,
        img_url     = 'https://raw.githubusercontent.com/victorstrand250-cpu/Photo-Katalog/refs/heads/main/1775526101667.png',
        img_file    = 'tram_bot.png',
    },
    {
        name        = u8('Track Helper'),
        short       = u8('\xd5\xe5\xeb\xef\xe5\xf0 \xe4\xeb\xff \xf0\xe0\xe1\xee\xf2\xfb \xe4\xe0\xeb\xfc\xed\xee\xe1\xee\xe9\xf9\xe8\xea\xe0 \xed\xe0 Arizona RP. \xd3\xef\xf0\xee\xf9\xe0\xe5\xf2 \xe4\xee\xf1\xf2\xe0\xe2\xea\xf3 \xe3\xf0\xf3\xe7\xee\xe2.'),
        vip         = false,
        price_month = nil,
        price_year  = nil,
        tg_link     = CHANNEL_TG,
        img_url     = 'https://raw.githubusercontent.com/victorstrand250-cpu/Photo-Katalog/refs/heads/main/1776333245763.png',
        img_file    = 'track_helper.png',
    },
    {
        name        = u8('Object Menu'),
        short       = u8('\xcc\xe5\xed\xfe \xe4\xeb\xff \xf1\xee\xe7\xe4\xe0\xed\xe8\xff \xe2\xe8\xe7\xf3\xe0\xeb\xfc\xed\xfb\xf5 \xee\xe1\xfa\xe5\xea\xf2\xee\xe2 \xe8 \xf0\xe5\xe4\xe0\xea\xf2\xe8\xf0\xee\xe2\xe0\xed\xe8\xff \xef\xee\xe7\xe8\xf6\xe8\xe9.'),
        vip         = false,
        price_month = nil,
        price_year  = nil,
        tg_link     = CHANNEL_TG,
        img_url     = 'https://raw.githubusercontent.com/victorstrand250-cpu/Photo-Katalog/refs/heads/main/file_00000000041c71f48308c9fdf10ef1f0.png',
        img_file    = 'object_menu.png',
    },
}
local catScripts  = {}
local catTextures = {}
local catPending  = {}
local function u32c(r,g,b,a)
    a = a or 1.0
    return bit.bor(
        bit.lshift(math.min(255,math.floor(a*255+.5)),24),
        bit.lshift(math.min(255,math.floor(b*255+.5)),16),
        bit.lshift(math.min(255,math.floor(g*255+.5)), 8),
                   math.min(255,math.floor(r*255+.5)))
end
local function safeNum(v)
    return tonumber(v) or 0
end
local function safeDist3d(x1,y1,z1,x2,y2,z2)
    x1=tonumber(x1) or 0; y1=tonumber(y1) or 0; z1=tonumber(z1) or 0
    x2=tonumber(x2) or 0; y2=tonumber(y2) or 0; z2=tonumber(z2) or 0
    local dx,dy,dz = x1-x2, y1-y2, z1-z2
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end
local function openLink(url)
    pcall(function()
        local gta = ffi.load('GTASA')
        pcall(ffi.cdef, [[ void _Z12AND_OpenLinkPKc(const char* link); ]])
        gta._Z12AND_OpenLinkPKc(url)
    end)
end
local function catEnsureDirs()
    pcall(function() lfs.mkdir(CAT_FOLDER) end)
    pcall(function() lfs.mkdir(CAT_IMAGES) end)
end
local function catLoadScripts()
    local saved = jsoncfg.load({scripts={}}, CAT_CFG)
    local result = {}
    for _,s in ipairs(DEFAULT_SCRIPTS) do table.insert(result,s) end
    if saved and saved.scripts then
        for _,s in ipairs(saved.scripts) do table.insert(result,s) end
    end
    return result
end
local function catScheduleDownload(imgFile, imgUrl)
    if not imgFile or imgFile == '' or not imgUrl or imgUrl == '' then return end
    if catTextures[imgFile] then return end
    catTextures[imgFile] = 'loading'
    local path = CAT_IMAGES..'/'..imgFile
    if doesFileExist(path) then
        local f = io.open(path,'rb')
        if f then
            local hdr = f:read(8); f:close()
            local valid = false
            if hdr then
                if hdr:byte(1)==0x89 and hdr:byte(2)==0x50 then valid=true end
                if hdr:byte(1)==0xFF and hdr:byte(2)==0xD8 then valid=true end
            end
            if not valid then os.remove(path) end
        else os.remove(path) end
    end
    if doesFileExist(path) then
        table.insert(catPending, {file=imgFile, path=path})
        return
    end
    asyncDownloadFile(imgUrl, path, function(ok)
        if ok then
            table.insert(catPending, {file=imgFile, path=path})
        else
            catTextures[imgFile] = 'failed'
        end
    end)
end
local CFG_FILE = 'minetools.ini'
local cfgDir   = getWorkingDirectory()..'/config'
if not doesDirectoryExist(cfgDir) then createDirectory(cfgDir) end
local settings = inicfg.load({
    main = {
        renderOre           = false,
        renderStone         = false,
        renderMetal         = false,
        renderSilver        = false,
        renderBronze        = false,
        renderGold          = false,
        showOreName         = false,
        showOreLine         = false,
        showOreDistance     = false,
        cjSkin              = false,
        autoDig             = false,
        fastRun             = false,
        teleportToMine      = false,
        antiBhop            = false,
        wallHack            = false,
        statisticsWindow    = false,
        statisticsStone     = false,
        statisticsMetal     = false,
        statisticsSilver    = false,
        statisticsBronze    = false,
        statisticsGold      = false,
        statisticsCoal      = false,
        totalPrice          = false,
        oreTimer            = false,
        oreTimerDistance    = false,
        oreTimerLine        = false,
        colorStone          = 0xFFffffff,
        colorMetal          = 0x808080FF,
        colorSilver         = 0x00008BFF,
        colorBronze         = 0x8B4513FF,
        colorGold           = 0xFFFF00FF,
        colorOreTimer       = 0xFFFFFFFF,
        selectedPage        = 2,
        renderRadius        = 100,
        renderSize          = 21,
        renderOreTimerSize  = 21,
        statisticsPosX      = 300,
        statisticsPosY      = 300,
        priceStone          = 20000,
        priceMetal          = 45000,
        priceSilver         = 25000,
        priceBronze         = 70000,
        priceGold           = 50000,
        priceCoal           = 15000,
        countStone          = 0,
        countMetal          = 0,
        countSilver         = 0,
        countBronze         = 0,
        countGold           = 0,
        countCoal           = 0,
        commandOpenMenu     = 'mt',
        defoltSkin          = 0,
        oreSoundEnabled     = true,
        subscribed          = false,
    },
}, CFG_FILE)
inicfg.load(settings, CFG_FILE)
if not doesFileExist(getWorkingDirectory()..'/config/'..CFG_FILE) then
    inicfg.save(settings, CFG_FILE)
end
local prefix = '{696969}[{DCDCDC}MineTools{696969}]{696969}: '
local str     = ffi.string
local oreTextures = {
    ['cs_rockdetail2'] = 1,
    ['ab_flakeywall']  = 2,
    ['metalic128']     = 3,
    ['Strip_Gold']     = 4,
    ['gold128']        = 5
}
local resources    = {}
local textsTable   = {}
local tp           = false
local tp_dist      = 175
local waiting      = 1300
local percent, packets = 0, 0
local incar        = false
local a            = 0
local oreTimerList = {}
local oreObjCache   = {}
local ore3dCache    = {}
local oreColorCache = {}
local function cachedColor(argb)
    argb = tonumber(argb) or 0xFFFFFFFF
    if not oreColorCache[argb] then
        local aa = bit.band(bit.rshift(argb,24),0xFF)/255
        local rr = bit.band(bit.rshift(argb,16),0xFF)/255
        local gg = bit.band(bit.rshift(argb, 8),0xFF)/255
        local bb = bit.band(argb,0xFF)/255
        oreColorCache[argb] = imgui.GetColorU32Vec4(imgui.ImVec4(rr,gg,bb,aa))
    end
    return oreColorCache[argb]
end
local function argbToVec4(argb)
    argb = tonumber(argb) or 0xFFFFFFFF
    return imgui.ImVec4(
        bit.band(bit.rshift(argb,16),0xFF)/255,
        bit.band(bit.rshift(argb, 8),0xFF)/255,
        bit.band(argb,0xFF)/255,
        bit.band(bit.rshift(argb,24),0xFF)/255)
end
local font = {}
local pages = {
    u8('\xcf\xee\xe8\xf1\xea \xf0\xf3\xe4\xfb'),
    u8('\xd1\xf2\xe0\xf2\xe8\xf1\xf2\xe8\xea\xe0'),
    u8('\xcd\xe0\xf1\xf2\xf0\xee\xe9\xea\xe8'),
    u8('\xca\xe0\xf2\xe0\xeb\xee\xe3'),
}
local ORE_LABEL   = u8('\xd0\xf3\xe4\xe0')
local ORE_REMAIN  = u8('\xce\xf1\xf2\xe0\xeb\xee\xf1\xfc ')
local STAT_TITLE  = u8('\xd1\xf2\xe0\xf2\xe8\xf1\xf2\xe8\xea\xe0')
local STAT_PROFIT = u8('\xcf\xf0\xe8\xe1\xfb\xeb\xfc: ')
local STAT_NAMES  = {
    u8('\xca\xe0\xec\xe5\xed\xfc'),
    u8('\xcc\xe5\xf2\xe0\xeb\xeb'),
    u8('\xd1\xe5\xf0\xe5\xe1\xf0\xee'),
    u8('\xc1\xf0\xee\xed\xe7\xe0'),
    u8('\xc7\xee\xeb\xee\xf2\xee'),
    u8('\xd3\xe3\xee\xeb\xfc'),
}
local BANNER_NEW  = u8('\xcd\xce\xc2\xc8\xcd\xca\xc0! \xc1\xce\xd2 \xcd\xc0 \xd8\xc0\xd5\xd2\xd3')
local BANNER_NEW_URL = 'https://t.me/strand_scripts/265'
local mainWindow       = new.bool(false)
local subscribeWindow  = new.bool(false)
local subYtClicked     = false
local subTgClicked     = false
local render           = new.bool(true)
local renderOre        = new.bool(settings.main.renderOre)
local renderStone      = new.bool(settings.main.renderStone)
local renderMetal      = new.bool(settings.main.renderMetal)
local renderSilver     = new.bool(settings.main.renderSilver)
local renderBronze     = new.bool(settings.main.renderBronze)
local renderGold       = new.bool(settings.main.renderGold)
local showOreName      = new.bool(settings.main.showOreName)
local showOreLine      = new.bool(settings.main.showOreLine)
local showOreDistance  = new.bool(settings.main.showOreDistance)
local cjSkin           = new.bool(settings.main.cjSkin)
local autoDig          = new.bool(settings.main.autoDig)
local fastRun          = new.bool(settings.main.fastRun)
local teleportToMine   = new.bool(settings.main.teleportToMine)
local antiBhop         = new.bool(settings.main.antiBhop)
local wallHack         = new.bool(settings.main.wallHack)
local statisticsWindow = new.bool(settings.main.statisticsWindow)
local statisticsStone  = new.bool(settings.main.statisticsStone)
local statisticsMetal  = new.bool(settings.main.statisticsMetal)
local statisticsSilver = new.bool(settings.main.statisticsSilver)
local statisticsBronze = new.bool(settings.main.statisticsBronze)
local statisticsGold   = new.bool(settings.main.statisticsGold)
local statisticsCoal   = new.bool(settings.main.statisticsCoal)
local totalPrice       = new.bool(settings.main.totalPrice)
local oreTimer         = new.bool(settings.main.oreTimer)
local oreTimerDistance = new.bool(settings.main.oreTimerDistance)
local oreTimerLine     = new.bool(settings.main.oreTimerLine)
local renderRadius      = new.int(settings.main.renderRadius)
local renderSize        = new.int(settings.main.renderSize)
local priceStone        = new.int(settings.main.priceStone)
local priceMetal        = new.int(settings.main.priceMetal)
local priceSilver       = new.int(settings.main.priceSilver)
local priceBronze       = new.int(settings.main.priceBronze)
local priceGold         = new.int(settings.main.priceGold)
local priceCoal         = new.int(settings.main.priceCoal)
local renderOreTimerSize= new.int(settings.main.renderOreTimerSize)
local commandOpenMenu  = new.char[256](u8(settings.main.commandOpenMenu))
local function isSubscribed()
    return settings.main.subscribed == true or settings.main.subscribed == 'true'
end
local function toggleMainMenu()
    if not isSubscribed() then
        subscribeWindow[0] = true
        return
    end
    mainWindow[0] = not mainWindow[0]
end
imgui.OnInitialize(function()
    imgui.SwitchContext()
    local io = imgui.GetIO()
    io.IniFilename = nil
    imgui.GetStyle():ScaleAllSizes(MDS)
    local ranges = io.Fonts:GetGlyphRangesCyrillic()
    local ttf    = getWorkingDirectory()..'/lib/mimgui/trebucbd.ttf'
    if not doesFileExist(ttf) then
        ttf = getWorkingDirectory()..'/../trebucbd.ttf'
    end
    io.Fonts:AddFontFromFileTTF(ttf, 14*MDS, nil, ranges)
    for size = 10, 27 do
        font[size] = io.Fonts:AddFontFromFileTTF(ttf, size*MDS, nil, ranges)
    end
    minetools_theme()
end)
function join_argb(a, r, g, b)
    local argb = b
    argb = bit.bor(argb, bit.lshift(g,  8))
    argb = bit.bor(argb, bit.lshift(r, 16))
    argb = bit.bor(argb, bit.lshift(a, 24))
    return argb
end
function convertToPriceFormat(num)
    num = tostring(num)
    if num ~= nil and #num > 3 then
        local b, e = ('%d'):format(num):gsub('^%-', '')
        local c = b:reverse():gsub('%d%d%d', '%1.')
        local d = c:reverse():gsub('^%.', '')
        return '$'..(e == 1 and '-' or '')..d
    end
    return '$'..num
end
function math.calculate(MinInt, MaxInt, MinFloat, MaxFloat, CurrentFloat)
    local res2 = MaxFloat - MinFloat
    if res2 == 0 then return MinInt end
    local res3 = (CurrentFloat - MinFloat) / res2
    return res3 * (MaxInt - MinInt) + MinInt
end
function imgui.CenterHeader(text, color)
    local width = imgui.GetWindowWidth()
    local calc  = imgui.CalcTextSize(text)
    imgui.SetCursorPosX(width / 2 - calc.x / 2)
    imgui.TextColored(color, text)
end
local allHints = {}
function imgui.Hint(str_id, hint, delay)
    local hovered  = imgui.IsItemHovered()
    local animTime = 0.2
    delay = delay or 0.0
    local show = true
    if not allHints[str_id] then
        allHints[str_id] = { status = false, timer = 0 }
    end
    if hovered then
        for k, v in pairs(allHints) do
            if k ~= str_id and os.clock() - v.timer <= animTime then
                show = false
            end
        end
    end
    if show and allHints[str_id].status ~= hovered then
        allHints[str_id].status = hovered
        allHints[str_id].timer  = os.clock() + delay
    end
    if show then
        local between = os.clock() - allHints[str_id].timer
        if between <= animTime then
            local function clamp01(f) return f<0 and 0 or (f>1 and 1 or f) end
            local alpha = hovered and clamp01(between/animTime) or clamp01(1-between/animTime)
            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
            imgui.SetTooltip(hint)
            imgui.PopStyleVar()
        elseif hovered then
            imgui.SetTooltip(hint)
        end
    end
end
imgui.CloseButton = function(size, thickness)
    size      = size      or (13*MDS)
    thickness = thickness or (2.5*MDS)
    local p  = imgui.GetCursorScreenPos()
    local DL = imgui.GetWindowDrawList()
    local isHov = imgui.IsMouseHoveringRect(
        imgui.ImVec2(p.x, p.y),
        imgui.ImVec2(p.x + size*2, p.y + size*2)
    )
    local col = isHov
        and imgui.GetColorU32Vec4(imgui.ImVec4(1.0, 0.35, 0.25, 1.0))
        or  imgui.GetColorU32Vec4(imgui.ImVec4(0.75, 0.55, 0.20, 0.85))
    local cx  = p.x + size
    local cy  = p.y + size
    local arm = size * 0.55
    DL:AddLine(imgui.ImVec2(cx-arm, cy-arm), imgui.ImVec2(cx+arm, cy+arm), col, thickness)
    DL:AddLine(imgui.ImVec2(cx+arm, cy-arm), imgui.ImVec2(cx-arm, cy+arm), col, thickness)
    return imgui.InvisibleButton('##close', imgui.ImVec2(size*2, size*2))
end
function nameTagOn()
    local ok, pStSet = pcall(sampGetServerSettingsPtr)
    if not ok or not pStSet or pStSet == 0 then return end
    NTdist  = mem.getfloat(pStSet + 39)
    NTwalls = mem.getint8(pStSet + 47)
    NTshow  = mem.getint8(pStSet + 56)
    mem.setfloat(pStSet + 39, 1488.0)
    mem.setint8(pStSet + 47, 0)
    mem.setint8(pStSet + 56, 1)
end
function nameTagOff()
    local ok, pStSet = pcall(sampGetServerSettingsPtr)
    if not ok or not pStSet or pStSet == 0 then return end
    if NTdist  then mem.setfloat(pStSet + 39, NTdist)  end
    if NTwalls then mem.setint8(pStSet + 47, NTwalls)  end
    if NTshow  then mem.setint8(pStSet + 56, NTshow)   end
end
function set_player_skin(id, skin)
    local BS = raknetNewBitStream()
    raknetBitStreamWriteInt32(BS, id)
    raknetBitStreamWriteInt32(BS, skin)
    raknetEmulRpcReceiveBitStream(153, BS)
    raknetDeleteBitStream(BS)
end
function readFloatArray(ptr, idx)
    return representIntAsFloat(readMemory(ptr + idx*4, 4, false))
end
function writeFloatArray(ptr, idx, value)
    writeMemory(ptr + idx*4, 4, representFloatAsInt(value), false)
end
function getVehicleRotationMatrix(car)
    local ok, entityPtr = pcall(getCarPointer, car)
    if not ok or not entityPtr or entityPtr == 0 then return end
    local mat = readMemory(entityPtr + 0x14, 4, false)
    if mat ~= 0 then
        local rx=readFloatArray(mat,0); local ry=readFloatArray(mat,1); local rz=readFloatArray(mat,2)
        local fx=readFloatArray(mat,4); local fy=readFloatArray(mat,5); local fz=readFloatArray(mat,6)
        local ux=readFloatArray(mat,8); local uy=readFloatArray(mat,9); local uz=readFloatArray(mat,10)
        return rx,ry,rz,fx,fy,fz,ux,uy,uz
    end
end
function setVehicleRotationMatrix(car, rx,ry,rz,fx,fy,fz,ux,uy,uz)
    local ok, entityPtr = pcall(getCarPointer, car)
    if not ok or not entityPtr or entityPtr == 0 then return end
    local mat = readMemory(entityPtr + 0x14, 4, false)
    if mat ~= 0 then
        writeFloatArray(mat,0,rx); writeFloatArray(mat,1,ry); writeFloatArray(mat,2,rz)
        writeFloatArray(mat,4,fx); writeFloatArray(mat,5,fy); writeFloatArray(mat,6,fz)
        writeFloatArray(mat,8,ux); writeFloatArray(mat,9,uy); writeFloatArray(mat,10,uz)
    end
end
function samp_create_sync_data(sync_type, copy_from_player)
    copy_from_player = copy_from_player == nil and true or copy_from_player
    local sync_traits = {
        player     = {'PlayerSyncData',    207, sampStorePlayerOnfootData},
        vehicle    = {'VehicleSyncData',   200, sampStorePlayerIncarData},
        passenger  = {'PassengerSyncData', 211, sampStorePlayerPassengerData},
        aim        = {'AimSyncData',       203, sampStorePlayerAimData},
        trailer    = {'TrailerSyncData',   210, sampStorePlayerTrailerData},
        unoccupied = {'UnoccupiedSyncData',209, nil},
        bullet     = {'BulletSyncData',    206, nil},
        spectator  = {'SpectatorSyncData', 212, nil},
    }
    local sync_info  = sync_traits[sync_type]
    local data_type  = 'struct '..sync_info[1]
    local data       = ffi.new(data_type, {})
    local raw_ptr    = tonumber(ffi.cast('uintptr_t', ffi.new(data_type..'*', data)))
    if copy_from_player then
        local copy_func = sync_info[3]
        if copy_func then
            local player_id
            if copy_from_player == true then
                local ok, pid = pcall(function()
                    return select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
                end)
                player_id = ok and pid or 0
            else
                player_id = tonumber(copy_from_player)
            end
            pcall(copy_func, player_id, raw_ptr)
        end
    end
    local func_send = function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, sync_info[2])
        raknetBitStreamWriteBuffer(bs, raw_ptr, ffi.sizeof(data))
        raknetSendBitStreamEx(bs, 1, 10, 1)
        raknetDeleteBitStream(bs)
    end
    local mt = {
        __index    = function(t, k) return data[k] end,
        __newindex = function(t, k, v) data[k] = v end,
    }
    return setmetatable({send = func_send}, mt)
end
function teleport_to_mine()
    lua_thread.create(function()
        local bx, by, bz = 527.45422363281, 866.03076171875, -42.206398010254
        if tp then
            sampAddChatMessage(prefix..'\xce\xf8\xe8\xe1\xea\xe0. {DCDCDC}\xd3\xe6\xe5 \xf2\xe5\xeb\xe5\xef\xee\xf0\xf2\xe8\xf0\xf3\xe5\xec\xf1\xff.', -1)
            return
        end
        percent = 0; packets = 0; tp = true
        local ok_car, car = pcall(function()
            return storeCarCharIsInNoSave(PLAYER_PED)
        end)
        if incar and ok_car then pcall(freezeCarPosition, car, true)
        else pcall(freezeCharPosition, PLAYER_PED, true) end
        local ok, x, y, z = pcall(getCharCoordinates, PLAYER_PED)
        if not ok then tp = false; return end
        local nx, ny, nz = x, y, z
        local dist  = getDistanceBetweenCoords2d(x, y, bx, by)
        local angle = -math.rad(getHeadingFromVector2d(bx - x, by - y))
        local data  = samp_create_sync_data(incar and 'vehicle' or 'player')
        if dist > tp_dist then
            for ds = dist - tp_dist, 0, -tp_dist do
                data.moveSpeed = {0, 0, incar and -0.1 or -1}
                for i = nz, -125, -25 do
                    data.position = {nx, ny, i}
                    data.send()
                end
                data.moveSpeed = {0, 0, 0}
                nx = nx + math.sin(angle) * tp_dist
                ny = ny + math.cos(angle) * tp_dist
                nz = -60
                data.position = {nx, ny, nz}
                data.send()
                sampAddChatMessage(prefix..'{DCDCDC}Wait{696969}!', -1)
                percent  = math.calculate(0, 100, dist, 0, ds)
                pcall(setCharCoordinates, PLAYER_PED, nx, ny, nz)
                packets  = packets + 1
                wait(waiting)
            end
        end
        data.moveSpeed = {0, 0, incar and -0.1 or -1}
        for i = nz, -125, -25 do
            data.position = {nx, ny, i}
            data.send()
        end
        data.position = {bx, by, bz}
        data.send()
        pcall(setCharCoordinates, PLAYER_PED, bx, by, bz)
        wait(1500)
        if incar and ok_car then pcall(freezeCarPosition, car, false)
        else pcall(freezeCharPosition, PLAYER_PED, false) end
        tp = false
    end)
end
function main()
    while not isSampAvailable() do wait(100) end
    while not sampIsLocalPlayerSpawned() do wait(200) end
    local function cbool(v) return v == true or v == 'true' end
    oreSoundEnabled[0] = cbool(settings.main.oreSoundEnabled)
    downloadOreSound()
    catEnsureDirs()
    catScripts = catLoadScripts()
    lua_thread.create(function()
        wait(500)
        for _, sc in ipairs(catScripts) do
            if sc.img_url and sc.img_url ~= '' and sc.img_file and sc.img_file ~= '' then
                catScheduleDownload(sc.img_file, sc.img_url)
                wait(200)
            end
        end
    end)
    sampRegisterChatCommand(settings.main.commandOpenMenu, toggleMainMenu)
    sampRegisterChatCommand('mtore', function()
        renderOre[0] = not renderOre[0]
        settings.main.renderOre = renderOre[0]
        inicfg.save(settings, CFG_FILE)
        sampAddChatMessage(prefix..('\xd0\xf3\xe4\xe0: '..(renderOre[0] and '{00FF00}\xc2\xca\xcb' or '{FF4444}\xc2\xdb\xca\xcb')), -1)
    end)
    sampRegisterChatCommand('mttimer', function()
        oreTimer[0] = not oreTimer[0]
        settings.main.oreTimer = oreTimer[0]
        inicfg.save(settings, CFG_FILE)
        sampAddChatMessage(prefix..('\xd2\xe0\xe9\xec\xe5\xf0: '..(oreTimer[0] and '{00FF00}\xc2\xca\xcb' or '{FF4444}\xc2\xdb\xca\xcb')), -1)
    end)
    if wallHack[0] then nameTagOn() end
    lua_thread.create(function()
        while true do
            wait(1500)
            if not (renderOre[0] and (showOreLine[0] or showOreDistance[0])) and not autoDig[0] then
                ore3dCache = {}
            else
                local tmp = {}
                for tid = 0, 2048 do
                    if tid % 256 == 0 then wait(0) end
                    local ok_t, defined = pcall(sampIs3dTextDefined, tid)
                    if ok_t and defined then
                        local ok_i, ttext, _, ox, oy, oz = pcall(function()
                            local t,c,x,y,z = sampGet3dTextInfoById(tid)
                            return t,c,x,y,z
                        end)
                        if ok_i and ttext and ttext:find('\xcc\xe5\xf1\xf2\xee\xf0\xee\xe6\xe4\xe5\xed\xe8\xe5') then
                            local nx2,ny2,nz2 = tonumber(ox),tonumber(oy),tonumber(oz)
                            if nx2 and ny2 and nz2 then
                                table.insert(tmp, {nx2, ny2, nz2})
                            end
                        end
                    end
                end
                ore3dCache = tmp
            end
        end
    end)
    wait(99)
    sampAddChatMessage('{FF8C00}> {FFCC00}Mine Tools {FF8C00}| {FFFFFF}\xc0\xe2\xf2\xee\xf0: {FFD700}Victor Strand', -1)
    sampAddChatMessage('{FF8C00}> {AAAAAA}\xcc\xe5\xed\xfe: {FFFFFF}/'..settings.main.commandOpenMenu..'{AAAAAA} | \xd0\xf3\xe4\xe0: {FFFFFF}/mtore{AAAAAA} | \xd2\xe0\xe9\xec\xe5\xf0: {FFFFFF}/mttimer', -1)
    sampAddChatMessage('{FF8C00}> {00CC66}\xd8\xe0\xf5\xf2\xb8\xf0\xf1\xea\xe8\xe9 \xea\xe0\xf0\xfc\xe5\xf0 \xed\xe0\xf7\xe8\xed\xe0\xe5\xf2\xf1\xff. \xd3\xe4\xe0\xf7\xe8!', -1)
    while true do
        wait(0)
        if fastRun[0] then
            local ok, onFoot = pcall(isCharOnFoot, PLAYER_PED)
            if ok and onFoot then
                setGameKeyState(16, 1)
                wait(10)
                setGameKeyState(16, 0)
            end
        end
        local ok2, ic = pcall(isCharInAnyCar, PLAYER_PED)
        if ok2 then incar = ic end
    end
end
function minetools_theme()
    local s   = imgui.GetStyle()
    local c   = s.Colors
    local C   = imgui.Col
    local IV4 = imgui.ImVec4
    local IV2 = imgui.ImVec2
    s.WindowTitleAlign  = IV2(0.5, 0.5)
    s.ButtonTextAlign   = IV2(0.5, 0.5)
    s.WindowPadding     = IV2(8*MDS,  8*MDS)
    s.FramePadding      = IV2(6*MDS,  5*MDS)
    s.ItemSpacing       = IV2(7*MDS,  6*MDS)
    s.ItemInnerSpacing  = IV2(4*MDS,  4*MDS)
    s.TouchExtraPadding = IV2(4*MDS,  4*MDS)
    s.IndentSpacing     = 14*MDS
    s.WindowBorderSize  = 1
    s.ChildBorderSize   = 1
    s.PopupBorderSize   = 1
    s.FrameBorderSize   = 0
    s.TabBorderSize     = 0
    s.ScrollbarSize     = 8*MDS
    s.GrabMinSize       = 10*MDS
    s.WindowRounding    = 6*MDS
    s.ChildRounding     = 4*MDS
    s.FrameRounding     = 4*MDS
    s.PopupRounding     = 5*MDS
    s.ScrollbarRounding = 4*MDS
    s.GrabRounding      = 3*MDS
    s.TabRounding       = 4*MDS
    c[C.Text]                = IV4(0.92, 0.88, 0.76, 1.00)
    c[C.TextDisabled]        = IV4(0.48, 0.44, 0.36, 1.00)
    c[C.WindowBg]            = IV4(0.07, 0.06, 0.04, 0.98)
    c[C.ChildBg]             = IV4(0.10, 0.09, 0.06, 0.95)
    c[C.PopupBg]             = IV4(0.09, 0.08, 0.05, 0.98)
    c[C.Border]              = IV4(0.45, 0.32, 0.12, 0.70)
    c[C.BorderShadow]        = IV4(0.00, 0.00, 0.00, 0.30)
    c[C.FrameBg]             = IV4(0.14, 0.12, 0.08, 1.00)
    c[C.FrameBgHovered]      = IV4(0.20, 0.17, 0.10, 1.00)
    c[C.FrameBgActive]       = IV4(0.26, 0.21, 0.11, 1.00)
    c[C.TitleBg]             = IV4(0.08, 0.07, 0.04, 1.00)
    c[C.TitleBgActive]       = IV4(0.52, 0.20, 0.05, 1.00)
    c[C.TitleBgCollapsed]    = IV4(0.07, 0.06, 0.04, 1.00)
    c[C.MenuBarBg]           = IV4(0.10, 0.09, 0.06, 1.00)
    c[C.ScrollbarBg]         = IV4(0.07, 0.06, 0.04, 1.00)
    c[C.ScrollbarGrab]       = IV4(0.38, 0.28, 0.12, 1.00)
    c[C.ScrollbarGrabHovered]= IV4(0.52, 0.38, 0.16, 1.00)
    c[C.ScrollbarGrabActive] = IV4(0.64, 0.26, 0.07, 1.00)
    c[C.CheckMark]           = IV4(0.88, 0.68, 0.18, 1.00)
    c[C.SliderGrab]          = IV4(0.60, 0.44, 0.14, 1.00)
    c[C.SliderGrabActive]    = IV4(0.78, 0.30, 0.07, 1.00)
    c[C.Button]              = IV4(0.20, 0.16, 0.09, 1.00)
    c[C.ButtonHovered]       = IV4(0.52, 0.22, 0.06, 0.95)
    c[C.ButtonActive]        = IV4(0.68, 0.17, 0.04, 1.00)
    c[C.Header]              = IV4(0.32, 0.18, 0.06, 0.85)
    c[C.HeaderHovered]       = IV4(0.50, 0.24, 0.07, 0.95)
    c[C.HeaderActive]        = IV4(0.62, 0.20, 0.05, 1.00)
    c[C.Tab]                 = IV4(0.12, 0.10, 0.06, 1.00)
    c[C.TabHovered]          = IV4(0.48, 0.21, 0.06, 1.00)
    c[C.TabActive]           = IV4(0.58, 0.23, 0.06, 1.00)
    c[C.Separator]           = IV4(0.38, 0.28, 0.10, 0.75)
    c[C.SeparatorHovered]    = IV4(0.58, 0.30, 0.08, 1.00)
    c[C.SeparatorActive]     = IV4(0.70, 0.24, 0.06, 1.00)
    c[C.ResizeGrip]          = IV4(0.42, 0.30, 0.10, 0.50)
    c[C.ResizeGripHovered]   = IV4(0.60, 0.38, 0.12, 0.80)
    c[C.ResizeGripActive]    = IV4(0.75, 0.28, 0.07, 1.00)
    c[C.PlotLines]           = IV4(0.85, 0.65, 0.20, 1.00)
    c[C.PlotHistogram]       = IV4(0.80, 0.50, 0.10, 1.00)
    c[C.TextSelectedBg]      = IV4(0.55, 0.22, 0.07, 0.45)
    c[C.NavHighlight]        = IV4(0.75, 0.55, 0.15, 1.00)
end
imgui.OnFrame(
    function() return subscribeWindow[0] end,
    function(self)
        self.HideCursor = false
        local sw, sh = getScreenResolution()
        local winW = math.min(sw * 0.72, 560 * MDS)
        local winH = 320 * MDS
        imgui.SetNextWindowPos(imgui.ImVec2(sw*0.5, sh*0.5), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(winW, winH), imgui.Cond.Always)
        local flags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize
                    + imgui.WindowFlags.NoTitleBar  + imgui.WindowFlags.NoScrollbar
                    + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoMove
        imgui.Begin('##subscribe', subscribeWindow, flags)
        local DLs = imgui.GetWindowDrawList()
        local wp  = imgui.GetWindowPos()
        local ww  = imgui.GetWindowWidth()
        local thH = 44 * MDS
        DLs:AddRectFilledMultiColor(
            imgui.ImVec2(wp.x, wp.y),
            imgui.ImVec2(wp.x+ww, wp.y+thH),
            u32c(0.60,0.22,0.06,1), u32c(0.42,0.14,0.04,1),
            u32c(0.42,0.14,0.04,1), u32c(0.60,0.22,0.06,1))
        DLs:AddLine(imgui.ImVec2(wp.x, wp.y+thH), imgui.ImVec2(wp.x+ww, wp.y+thH),
            u32c(0.88,0.68,0.18,1), 2*MDS)
        imgui.SetCursorPosY(thH * 0.15)
        if font[16] then imgui.PushFont(font[16]) end
        imgui.CenterHeader(u8('\xc4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc \xe2 Mine Tools!'), imgui.ImVec4(1.0,0.95,0.80,1.0))
        if font[16] then imgui.PopFont() end
        imgui.SetCursorPosY(thH + 14*MDS)
        if font[14] then imgui.PushFont(font[14]) end
        imgui.CenterHeader(u8('\xcf\xee\xe4\xef\xe8\xf8\xe8\xf1\xfc, \xf7\xf2\xee\xe1\xfb \xed\xe5 \xef\xf0\xee\xef\xf3\xf1\xf2\xe8\xf2\xfc \xed\xee\xe2\xfb\xe5 \xf1\xea\xf0\xe8\xef\xf2\xfb \xe8 \xee\xe1\xed\xee\xe2\xeb\xe5\xed\xe8\xff!'), imgui.ImVec4(0.78,0.74,0.64,1.0))
        if font[14] then imgui.PopFont() end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        local btnW = (winW - 36*MDS) * 0.5
        local ytColor = subYtClicked and imgui.ImVec4(0.18,0.55,0.18,1) or imgui.ImVec4(0.75,0.10,0.10,1)
        local ytHov   = subYtClicked and imgui.ImVec4(0.22,0.65,0.22,1) or imgui.ImVec4(0.85,0.15,0.10,1)
        local ytAct   = subYtClicked and imgui.ImVec4(0.15,0.45,0.15,1) or imgui.ImVec4(0.65,0.08,0.08,1)
        imgui.PushStyleColor(imgui.Col.Button,        ytColor)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, ytHov)
        imgui.PushStyleColor(imgui.Col.ButtonActive,  ytAct)
        if font[15] then imgui.PushFont(font[15]) end
        if imgui.Button(subYtClicked and u8('\xe2 YouTube') or u8('YouTube'), imgui.ImVec2(btnW, 46*MDS)) then
            openLink('https://youtube.com/@strand_samp?si=A291kCAs1SM2yoZm')
            subYtClicked = true
        end
        if font[15] then imgui.PopFont() end
        imgui.PopStyleColor(3)
        imgui.SameLine()
        local tgColor = subTgClicked and imgui.ImVec4(0.18,0.55,0.18,1) or imgui.ImVec4(0.10,0.35,0.65,1)
        local tgHov   = subTgClicked and imgui.ImVec4(0.22,0.65,0.22,1) or imgui.ImVec4(0.12,0.42,0.78,1)
        local tgAct   = subTgClicked and imgui.ImVec4(0.15,0.45,0.15,1) or imgui.ImVec4(0.08,0.28,0.55,1)
        imgui.PushStyleColor(imgui.Col.Button,        tgColor)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, tgHov)
        imgui.PushStyleColor(imgui.Col.ButtonActive,  tgAct)
        if font[15] then imgui.PushFont(font[15]) end
        if imgui.Button(subTgClicked and u8('\xe2 Telegram') or u8('Telegram'), imgui.ImVec2(btnW, 46*MDS)) then
            openLink('https://t.me/strand_scripts')
            subTgClicked = true
        end
        if font[15] then imgui.PopFont() end
        imgui.PopStyleColor(3)
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        local bothClicked = subYtClicked and subTgClicked
        if not bothClicked then
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.16,0.14,0.09,1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.16,0.14,0.09,1))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.16,0.14,0.09,1))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.42,0.38,0.28,1))
        else
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.26,0.50,0.14,1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.34,0.60,0.17,1))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.20,0.42,0.11,1))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.0,1.0,1.0,1.0))
        end
        if font[15] then imgui.PushFont(font[15]) end
        if imgui.Button(u8('\xcf\xee\xe4\xef\xe8\xf1\xe0\xeb\xf1\xff \xe8 \xe3\xee\xf2\xee\xe2!'), imgui.ImVec2(winW-24*MDS, 44*MDS)) then
            if bothClicked then
                settings.main.subscribed = true
                inicfg.save(settings, CFG_FILE)
                subscribeWindow[0] = false
                mainWindow[0] = true
            end
        end
        if font[15] then imgui.PopFont() end
        imgui.PopStyleColor(4)
        if not bothClicked then
            imgui.Spacing()
            if font[13] then imgui.PushFont(font[13]) end
            imgui.CenterHeader(
                u8('\xd1\xed\xe0\xf7\xe0\xeb\xe0 \xed\xe0\xe6\xec\xe8 \xea\xed\xee\xef\xea\xe8 YouTube \xe8 Telegram'),
                imgui.ImVec4(0.88,0.68,0.18,1)
            )
            if font[13] then imgui.PopFont() end
        end
        imgui.End()
    end
)
imgui.OnFrame(
    function() return mainWindow[0] end,
    function(self)
        self.HideCursor = false
        local sw, sh = getScreenResolution()
        local winW = math.min(sw * 0.68, 640 * MDS)
        local winH = sh * 0.68
        imgui.SetNextWindowPos(imgui.ImVec2(sw*0.5, sh*0.5), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(winW, winH), imgui.Cond.Always)
        local flags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize
                    + imgui.WindowFlags.NoTitleBar  + imgui.WindowFlags.NoScrollbar
                    + imgui.WindowFlags.NoScrollWithMouse
        imgui.Begin(u8('Mine Tools'), mainWindow, flags)
        local titleH = 40 * MDS
        imgui.BeginChild('##title', imgui.ImVec2(-1, titleH), false)
            local DLt = imgui.GetWindowDrawList()
            local tp2 = imgui.GetWindowPos()
            local tw2 = imgui.GetWindowWidth()
            DLt:AddRectFilledMultiColor(
                imgui.ImVec2(tp2.x, tp2.y),
                imgui.ImVec2(tp2.x+tw2, tp2.y+titleH),
                u32c(0.58,0.22,0.06,1), u32c(0.30,0.10,0.03,1),
                u32c(0.30,0.10,0.03,1), u32c(0.58,0.22,0.06,1))
            DLt:AddLine(
                imgui.ImVec2(tp2.x, tp2.y+titleH-1),
                imgui.ImVec2(tp2.x+tw2, tp2.y+titleH-1),
                u32c(0.88,0.68,0.18,1), 1.5*MDS)
            if font[18] then imgui.PushFont(font[18]) end
            imgui.SetCursorPosY((titleH - imgui.GetTextLineHeight()) * 0.5)
            imgui.CenterHeader(u8('\xd8\xe0\xf5\xf2\xe0  |  Mine Tools'), imgui.ImVec4(1.0,0.90,0.70,1.0))
            if font[18] then imgui.PopFont() end
            local btnR = 11 * MDS
            imgui.SetCursorScreenPos(imgui.ImVec2(
                tp2.x + tw2 - btnR*2 - 6*MDS,
                tp2.y + titleH*0.5 - btnR
            ))
            if imgui.CloseButton(btnR, 2.5*MDS) then mainWindow[0] = false end
        imgui.EndChild()
        local contentH = winH - titleH - 16*MDS
        imgui.BeginChild('##content', imgui.ImVec2(-1, contentH), false)
        if imgui.BeginTabBar('##tabs') then
            if imgui.BeginTabItem(pages[1]) then
                imgui.Spacing()
                local bW = (winW - 32*MDS) * 0.5
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.85,0.62,0.08,1.0))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.97,0.74,0.13,1.0))
                imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.72,0.50,0.05,1.0))
                imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.10,0.07,0.02,1.0))
                if font[16] then imgui.PushFont(font[16]) end
                if imgui.Button(BANNER_NEW, imgui.ImVec2(winW - 32*MDS, 40*MDS)) then
                    openLink(BANNER_NEW_URL)
                end
                if font[16] then imgui.PopFont() end
                imgui.PopStyleColor(4)
                imgui.Hint('bannerNew', u8('\xce\xf2\xea\xf0\xfb\xf2\xfc \xef\xee\xf1\xf2 \xee \xe1\xee\xf2\xe5 \xed\xe0 \xf8\xe0\xf5\xf2\xf3 \xe2 Telegram'))
                imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                if imgui.Checkbox(u8('\xcf\xee\xe8\xf1\xea \xf0\xf3\xe4\xfb'), renderOre) then
                    settings.main.renderOre = renderOre[0]; inicfg.save(settings, CFG_FILE)
                end
                imgui.Hint('renderOre', u8('\xd4\xf3\xed\xea\xf6\xe8\xff \xe2\xea\xeb\xfe\xf7\xe0\xe5\xf2 \xef\xee\xe8\xf1\xea \xf0\xf3\xe4\xfb. \xd2\xe0\xea\xe6\xe5: /mtore'))
                if imgui.Checkbox(u8('\xc0\xe2\xf2\xee \xe2\xfb\xea\xe0\xef\xfb\xe2\xe0\xed\xe8\xe5 \xf0\xf3\xe4\xfb'), autoDig) then
                    settings.main.autoDig = autoDig[0]; inicfg.save(settings, CFG_FILE)
                end
                imgui.Hint('autoDig', u8('\xc0\xe2\xf2\xee\xec\xe0\xf2\xe8\xf7\xe5\xf1\xea\xee\xe5 \xe2\xfb\xea\xe0\xef\xfb\xe2\xe0\xed\xe8\xe5 \xf0\xf3\xe4\xfb \xed\xe0 \xf8\xe0\xf5\xf2\xe5.'))
                imgui.Separator()
                if imgui.Checkbox(u8('\xcf\xee\xea\xe0\xe7\xfb\xe2\xe0\xf2\xfc \xeb\xe8\xed\xe8\xfe'), showOreLine) then
                    settings.main.showOreLine = showOreLine[0]; inicfg.save(settings, CFG_FILE)
                end
                if imgui.Checkbox(u8('\xcf\xee\xea\xe0\xe7\xfb\xe2\xe0\xf2\xfc \xe4\xe8\xf1\xf2\xe0\xed\xf6\xe8\xfe'), showOreDistance) then
                    settings.main.showOreDistance = showOreDistance[0]; inicfg.save(settings, CFG_FILE)
                end
                imgui.Spacing()
                imgui.PushItemWidth(bW)
                if imgui.SliderInt(u8('\xd0\xe0\xe4\xe8\xf3\xf1 \xef\xee\xe8\xf1\xea\xe0'), renderRadius, 1, 600) then
                    settings.main.renderRadius = renderRadius[0]; inicfg.save(settings, CFG_FILE)
                end
                if imgui.SliderInt(u8('\xd0\xe0\xe7\xec\xe5\xf0 \xf8\xf0\xe8\xf4\xf2\xe0'), renderSize, 10, 27) then
                    settings.main.renderSize = renderSize[0]; inicfg.save(settings, CFG_FILE)
                end
                imgui.PopItemWidth()
                imgui.Separator()
                do
                    local argb = tonumber(settings.main.colorOreTimer) or 0xFFFFFFFF
                    local ct = new.float[4](
                        bit.band(bit.rshift(argb,16),0xFF)/255,
                        bit.band(bit.rshift(argb, 8),0xFF)/255,
                        bit.band(argb,0xFF)/255,
                        bit.band(bit.rshift(argb,24),0xFF)/255)
                    if imgui.ColorEdit4('##ct', ct, imgui.ColorEditFlags.NoInputs) then
                        settings.main.colorOreTimer = '0x'..bit.tohex(join_argb(ct[3]*255,ct[0]*255,ct[1]*255,ct[2]*255))
                        inicfg.save(settings, CFG_FILE)
                        oreColorCache = {}
                    end
                    imgui.SameLine()
                    if imgui.Checkbox(u8('\xd2\xe0\xe9\xec\xe5\xf0 \xf0\xf3\xe4\xfb'), oreTimer) then
                        settings.main.oreTimer = oreTimer[0]; inicfg.save(settings, CFG_FILE)
                    end
                    imgui.Hint('oreTimer', u8('\xd4\xf3\xed\xea\xf6\xe8\xff \xf2\xe0\xe9\xec\xe5\xf0\xe0. \xd2\xe0\xea\xe6\xe5: /mttimer'))
                end
                if imgui.Checkbox(u8('\xcf\xee\xea\xe0\xe7. \xe4\xe8\xf1\xf2\xe0\xed\xf6\xe8\xfe \xe4\xee \xf0\xf3\xe4\xfb'), oreTimerDistance) then
                    settings.main.oreTimerDistance = oreTimerDistance[0]; inicfg.save(settings, CFG_FILE)
                end
                if imgui.Checkbox(u8('\xcf\xee\xea\xe0\xe7. \xeb\xe8\xed\xe8\xfe \xe4\xee \xf2\xe0\xe9\xec\xe5\xf0\xe0'), oreTimerLine) then
                    settings.main.oreTimerLine = oreTimerLine[0]; inicfg.save(settings, CFG_FILE)
                end
                imgui.PushItemWidth(bW)
                if imgui.SliderInt(u8('\xd0\xe0\xe7\xec\xe5\xf0 \xf8\xf0\xe8\xf4\xf2\xe0 \xf2\xe0\xe9\xec\xe5\xf0\xe0'), renderOreTimerSize, 10, 27) then
                    settings.main.renderOreTimerSize = renderOreTimerSize[0]; inicfg.save(settings, CFG_FILE)
                end
                imgui.PopItemWidth()
                imgui.EndTabItem()
            end
            if imgui.BeginTabItem(pages[2]) then
                imgui.Spacing()
                if imgui.Checkbox(u8('\xd1\xf2\xe0\xf2\xe8\xf1\xf2\xe8\xea\xe0 HUD'), statisticsWindow) then
                    settings.main.statisticsWindow = statisticsWindow[0]; inicfg.save(settings, CFG_FILE)
                end
                imgui.SameLine()
                if imgui.Button(u8('\xd1\xe1\xf0\xee\xf1\xe8\xf2\xfc'), imgui.ImVec2(90*MDS, 28*MDS)) then
                    settings.main.countStone=0; settings.main.countMetal=0
                    settings.main.countSilver=0; settings.main.countBronze=0
                    settings.main.countGold=0; settings.main.countCoal=0
                    inicfg.save(settings, CFG_FILE)
                end
                imgui.Separator()
                imgui.BeginGroup()
                    local function resCB(lbl, cbool, key)
                        if imgui.Checkbox(lbl, cbool) then
                            settings.main[key] = cbool[0]; inicfg.save(settings, CFG_FILE)
                        end
                    end
                    resCB(u8('\xca\xe0\xec\xe5\xed\xfc'),    statisticsStone,  'statisticsStone')
                    resCB(u8('\xcc\xe5\xf2\xe0\xeb\xeb'),    statisticsMetal,  'statisticsMetal')
                    resCB(u8('\xd1\xe5\xf0\xe5\xe1\xf0\xee'),statisticsSilver, 'statisticsSilver')
                    resCB(u8('\xc1\xf0\xee\xed\xe7\xe0'),    statisticsBronze, 'statisticsBronze')
                    resCB(u8('\xc7\xee\xeb\xee\xf2\xee'),    statisticsGold,   'statisticsGold')
                    resCB(u8('\xd3\xe3\xee\xeb\xfc'),        statisticsCoal,   'statisticsCoal')
                imgui.EndGroup()
                imgui.SameLine()
                imgui.BeginGroup()
                    local iW = 130*MDS
                    imgui.PushItemWidth(iW)
                    local priceFields = {
                        {u8('\xd6\xe5\xed\xe0 \xea\xe0\xec\xed\xff'),       priceStone,  'priceStone'},
                        {u8('\xd6\xe5\xed\xe0 \xec\xe5\xf2\xe0\xeb\xeb\xe0'),priceMetal,  'priceMetal'},
                        {u8('\xd6\xe5\xed\xe0 \xf1\xe5\xf0\xe5\xe1\xf0\xe0'),priceSilver, 'priceSilver'},
                        {u8('\xd6\xe5\xed\xe0 \xe1\xf0\xee\xed\xe7\xfb'),    priceBronze, 'priceBronze'},
                        {u8('\xd6\xe5\xed\xe0 \xe7\xee\xeb\xee\xf2\xe0'),    priceGold,   'priceGold'},
                        {u8('\xd6\xe5\xed\xe0 \xf3\xe3\xeb\xff'),            priceCoal,   'priceCoal'},
                    }
                    for _, pf in ipairs(priceFields) do
                        if imgui.InputInt(pf[1], pf[2], 1000, 1) then
                            settings.main[pf[3]] = pf[2][0]; inicfg.save(settings, CFG_FILE)
                        end
                    end
                    imgui.PopItemWidth()
                imgui.EndGroup()
                if imgui.Checkbox(u8('\xce\xe1\xf9\xe0\xff \xf6\xe5\xed\xe0'), totalPrice) then
                    settings.main.totalPrice = totalPrice[0]; inicfg.save(settings, CFG_FILE)
                end
                imgui.Separator()
                imgui.Columns(4, 'stats_tbl', true)
                imgui.SetColumnWidth(-1, 70*MDS); imgui.Text(u8('\xd0\xe5\xf1.')); imgui.NextColumn()
                imgui.SetColumnWidth(-1, 55*MDS); imgui.Text(u8('\xca\xee\xeb.')); imgui.NextColumn()
                imgui.Text(u8('\xd6\xe5\xed\xe0')); imgui.NextColumn()
                imgui.Text(u8('\xd1\xf3\xec\xec\xe0')); imgui.NextColumn()
                imgui.Separator()
                local oreStats = {
                    {u8('\xca\xe0\xec\xe5\xed\xfc'),    settings.main.countStone,  settings.main.priceStone,  statisticsStone[0]},
                    {u8('\xcc\xe5\xf2\xe0\xeb\xeb'),    settings.main.countMetal,  settings.main.priceMetal,  statisticsMetal[0]},
                    {u8('\xd1\xe5\xf0\xe5\xe1\xf0\xee'),settings.main.countSilver, settings.main.priceSilver, statisticsSilver[0]},
                    {u8('\xc1\xf0\xee\xed\xe7\xe0'),    settings.main.countBronze, settings.main.priceBronze, statisticsBronze[0]},
                    {u8('\xc7\xee\xeb\xee\xf2\xee'),    settings.main.countGold,   settings.main.priceGold,   statisticsGold[0]},
                    {u8('\xd3\xe3\xee\xeb\xfc'),        settings.main.countCoal,   settings.main.priceCoal,   statisticsCoal[0]},
                }
                local totalCnt, totalSum = 0, 0
                for _, row in ipairs(oreStats) do
                    if row[4] then
                        local nm,cnt,prc = row[1],row[2],row[3]
                        imgui.SetColumnWidth(-1, 70*MDS); imgui.Text(nm); imgui.NextColumn()
                        imgui.SetColumnWidth(-1, 55*MDS); imgui.Text(tostring(cnt)); imgui.NextColumn()
                        imgui.Text(convertToPriceFormat(prc)); imgui.NextColumn()
                        imgui.Text(convertToPriceFormat(cnt*prc)); imgui.NextColumn()
                        imgui.Separator()
                        totalCnt = totalCnt + cnt
                        totalSum = totalSum + cnt*prc
                    end
                end
                imgui.SetColumnWidth(-1, 70*MDS); imgui.Text(u8('\xc8\xf2\xee\xe3')); imgui.NextColumn()
                imgui.SetColumnWidth(-1, 55*MDS); imgui.Text(tostring(totalCnt)); imgui.NextColumn()
                imgui.Text('~'); imgui.NextColumn()
                imgui.Text(convertToPriceFormat(totalSum)); imgui.NextColumn()
                imgui.Separator()
                imgui.Columns(1)
                imgui.EndTabItem()
            end
            if imgui.BeginTabItem(pages[3]) then
                imgui.BeginChild('##settings_noscroll', imgui.ImVec2(-1, -1), false,
                    imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
                imgui.Spacing()
                imgui.Text(u8('\xca\xee\xec\xe0\xed\xe4\xe0 \xee\xf2\xea\xf0\xfb\xf2\xe8\xff:'))
                imgui.PushItemWidth(160*MDS)
                if imgui.InputTextWithHint('##cmd',
                    u8('\xc2\xe2\xe5\xe4\xe8\xf2\xe5 \xea\xee\xec\xe0\xed\xe4\xf3'),
                    commandOpenMenu, 256)
                then
                    local decoded = u8:decode(ffi.string(commandOpenMenu))
                    if decoded and decoded ~= '' then
                        local clean = decoded:gsub('%A', '')
                        if clean ~= '' then
                            sampUnregisterChatCommand(settings.main.commandOpenMenu)
                            settings.main.commandOpenMenu = clean
                            inicfg.save(settings, CFG_FILE)
                            sampRegisterChatCommand(clean, toggleMainMenu)
                            commandOpenMenu = new.char[256](u8(clean))
                        end
                    else
                        sampUnregisterChatCommand(settings.main.commandOpenMenu)
                        settings.main.commandOpenMenu = 'mt'
                        inicfg.save(settings, CFG_FILE)
                        sampRegisterChatCommand('mt', toggleMainMenu)
                        commandOpenMenu = new.char[256]('mt')
                    end
                end
                imgui.PopItemWidth()
                imgui.Separator(); imgui.Spacing()
                if font[13] then imgui.PushFont(font[13]) end
                imgui.Text(u8('\xc1\xfb\xf1\xf2\xfb\xe5 \xea\xee\xec\xe0\xed\xe4\xfb:'))
                imgui.BulletText(u8('/'..settings.main.commandOpenMenu..' - \xec\xe5\xed\xfe'))
                imgui.BulletText(u8('/mtore - \xef\xee\xe8\xf1\xea \xf0\xf3\xe4\xfb'))
                imgui.BulletText(u8('/mttimer - \xf2\xe0\xe9\xec\xe5\xf0'))
                if font[13] then imgui.PopFont() end
                imgui.Separator(); imgui.Spacing()
                if imgui.Checkbox(u8('\xc7\xe2\xf3\xea \xef\xf0\xe8 \xe4\xee\xe1\xfb\xf7\xe5 \xf0\xf3\xe4\xfb'), oreSoundEnabled) then
                    settings.main.oreSoundEnabled = oreSoundEnabled[0]; inicfg.save(settings, CFG_FILE)
                end
                if not doesFileExist(SOUND_FILE) then
                    if font[11] then imgui.PushFont(font[11]) end
                    imgui.TextColored(imgui.ImVec4(0.8,0.6,0.1,1), u8('\xc7\xe2\xf3\xea \xef\xee\xe4\xea\xe0\xf7\xe8\xe2\xe0\xe5\xf2\xf1\xff...'))
                    if font[11] then imgui.PopFont() end
                end
                imgui.Separator(); imgui.Spacing()
                if font[15] then imgui.PushFont(font[15]) end
                imgui.TextColored(imgui.ImVec4(0.88,0.68,0.18,1), u8('\xc0\xe2\xf2\xee\xf0: Victor Strand'))
                if font[15] then imgui.PopFont() end
                imgui.Spacing()
                local btnW2 = 200*MDS
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.10,0.50,0.90,1))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.15,0.65,1.00,1))
                imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.07,0.38,0.70,1))
                if imgui.Button(u8('\xca\xe0\xed\xe0\xeb: @strand_scripts'), imgui.ImVec2(btnW2, 30*MDS)) then
                    openLink('https://t.me/strand_scripts')
                end
                imgui.PopStyleColor(3)
                imgui.SameLine()
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.10,0.28,0.55,1))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18,0.42,0.72,1))
                imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.07,0.20,0.42,1))
                if imgui.Button(u8('\xc0\xe2\xf2\xee\xf0: @victor_st0'), imgui.ImVec2(btnW2, 30*MDS)) then
                    openLink('https://t.me/victor_st0')
                end
                imgui.PopStyleColor(3)
                imgui.EndChild()
                imgui.EndTabItem()
            end
            if imgui.BeginTabItem(pages[4]) then
                imgui.Spacing()
                local CARD_W  = winW - 28*MDS
                local BADGE_W = 36*MDS
                local BADGE_H = 16*MDS
                local function drawBadge(isVip)
                    local dl2 = imgui.GetWindowDrawList()
                    local bp  = imgui.GetCursorScreenPos()
                    local bgCol = isVip and u32c(1.0,0.75,0.05,1) or u32c(0.10,0.80,0.35,1)
                    local txCol = isVip and u32c(0.04,0.04,0.04,1) or u32c(0.02,0.02,0.02,1)
                    local lbl   = isVip and 'VIP' or 'FREE'
                    dl2:AddRectFilled(imgui.ImVec2(bp.x,bp.y), imgui.ImVec2(bp.x+BADGE_W,bp.y+BADGE_H), bgCol, 3*MDS)
                    if font[10] then imgui.PushFont(font[10]) end
                    local lsz = imgui.CalcTextSize(lbl)
                    dl2:AddText(imgui.ImVec2(bp.x+BADGE_W/2-lsz.x/2, bp.y+BADGE_H/2-lsz.y/2), txCol, lbl)
                    if font[10] then imgui.PopFont() end
                    imgui.Dummy(imgui.ImVec2(BADGE_W, BADGE_H))
                end
                imgui.BeginChild('##catalog_scroll', imgui.ImVec2(-1,-1), false)
                local dl_cat = imgui.GetWindowDrawList()
                for i, sc in ipairs(catScripts) do
                    local portrait = sc.img_ratio and sc.img_ratio < 1
                    local IMG_W, IMG_H
                    if portrait then
                        IMG_H = 124*MDS
                        IMG_W = IMG_H * sc.img_ratio
                    else
                        IMG_W = 95*MDS
                        IMG_H = 62*MDS
                    end
                    local CARD_H = IMG_H + 14*MDS
                    local startPos = imgui.GetCursorScreenPos()
                    if sc.featured then
                        local pulse = 0.65 + 0.35 * math.abs(math.sin(os.clock() * 2.2))
                        dl_cat:AddRectFilledMultiColor(
                            imgui.ImVec2(startPos.x,        startPos.y),
                            imgui.ImVec2(startPos.x+CARD_W, startPos.y+CARD_H),
                            u32c(0.34,0.24,0.05,1), u32c(0.24,0.16,0.04,1),
                            u32c(0.20,0.13,0.03,1), u32c(0.30,0.21,0.05,1))
                        dl_cat:AddRect(
                            imgui.ImVec2(startPos.x-1,        startPos.y-1),
                            imgui.ImVec2(startPos.x+CARD_W+1, startPos.y+CARD_H+1),
                            u32c(1.0,0.78,0.12,pulse), 5*MDS)
                        dl_cat:AddRect(
                            imgui.ImVec2(startPos.x,        startPos.y),
                            imgui.ImVec2(startPos.x+CARD_W, startPos.y+CARD_H),
                            u32c(1.0,0.78,0.12,pulse), 4*MDS)
                    else
                        dl_cat:AddRectFilledMultiColor(
                            imgui.ImVec2(startPos.x,        startPos.y),
                            imgui.ImVec2(startPos.x+CARD_W, startPos.y+CARD_H),
                            u32c(0.16,0.13,0.08,1), u32c(0.12,0.10,0.06,1),
                            u32c(0.10,0.08,0.05,1), u32c(0.13,0.11,0.07,1))
                        dl_cat:AddRect(
                            imgui.ImVec2(startPos.x,        startPos.y),
                            imgui.ImVec2(startPos.x+CARD_W, startPos.y+CARD_H),
                            u32c(0.45,0.26,0.09,0.75), 4*MDS)
                    end
                    local imgX = startPos.x + 6*MDS
                    local imgY = startPos.y + (CARD_H-IMG_H)*0.5
                    dl_cat:AddRectFilled(imgui.ImVec2(imgX,imgY), imgui.ImVec2(imgX+IMG_W,imgY+IMG_H), u32c(0.07,0.06,0.04,1), 3*MDS)
                    local tex = sc.img_file and sc.img_file ~= '' and catTextures[sc.img_file] or nil
                    if tex and type(tex) ~= 'string' then
                        local ratio   = sc.img_ratio or (IMG_W / IMG_H)
                        local boxR    = IMG_W / IMG_H
                        local drawW, drawH
                        if ratio > boxR then
                            drawW = IMG_W; drawH = IMG_W / ratio
                        else
                            drawH = IMG_H; drawW = IMG_H * ratio
                        end
                        local drawX = imgX + (IMG_W - drawW) * 0.5
                        local drawY = imgY + (IMG_H - drawH) * 0.5
                        imgui.SetCursorScreenPos(imgui.ImVec2(drawX, drawY))
                        imgui.Image(tex, imgui.ImVec2(drawW, drawH))
                    else
                        local ph = (tex=='loading') and u8('\xc7\xe0\xe3\xf0\xf3\xe7\xea\xe0...') or u8('\xcd\xe5\xf2 \xf4\xee\xf2\xee')
                        if font[11] then imgui.PushFont(font[11]) end
                        local tsz = imgui.CalcTextSize(ph)
                        dl_cat:AddText(imgui.ImVec2(imgX+IMG_W/2-tsz.x/2, imgY+IMG_H/2-tsz.y/2), u32c(0.42,0.42,0.42,1), ph)
                        if font[11] then imgui.PopFont() end
                    end
                    local BTN_W = 88*MDS; local BTN_H = 30*MDS
                    local btnX  = startPos.x + CARD_W - BTN_W - 8*MDS
                    local btnY  = startPos.y + (CARD_H-BTN_H)*0.5
                    imgui.SetCursorScreenPos(imgui.ImVec2(btnX, btnY))
                    local btnLabel, bR, bG, bB
                    if sc.featured then
                        btnLabel = u8('\xca\xf3\xef\xe8\xf2\xfc')
                        bR,bG,bB = 0.96,0.72,0.06
                    elseif sc.vip then
                        btnLabel = u8('\xca\xf3\xef\xe8\xf2\xfc')
                        bR,bG,bB = 0.72,0.58,0.05
                    else
                        btnLabel = u8('\xd1\xea\xe0\xf7\xe0\xf2\xfc')
                        bR,bG,bB = 0.05,0.60,0.22
                    end
                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(bR,      bG,      bB,      1))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(bR+0.12, bG+0.10, bB+0.05, 1))
                    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(bR-0.10, bG-0.10, bB-0.03, 1))
                    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.05,0.05,0.05,1))
                    if font[13] then imgui.PushFont(font[13]) end
                    local clicked = imgui.Button(btnLabel..'##btn'..i, imgui.ImVec2(BTN_W, BTN_H))
                    if font[13] then imgui.PopFont() end
                    imgui.PopStyleColor(4)
                    local textGap  = portrait and 18*MDS or 10*MDS
                    local textX    = imgX + IMG_W + textGap
                    local textY    = imgY
                    local maxDescW = CARD_W - IMG_W - BTN_W - textGap - 20*MDS
                    imgui.SetCursorScreenPos(imgui.ImVec2(textX, textY))
                    imgui.BeginGroup()
                    if font[14] then imgui.PushFont(font[14]) end
                    imgui.TextColored(imgui.ImVec4(0.96,0.92,0.80,1), sc.name)
                    if font[14] then imgui.PopFont() end
                    imgui.SameLine(0, 6*MDS)
                    imgui.SetCursorPosY(imgui.GetCursorPosY() + 1*MDS)
                    drawBadge(sc.vip)
                    if sc.featured then
                        imgui.SameLine(0, 5*MDS)
                        local dlf  = imgui.GetWindowDrawList()
                        local fp   = imgui.GetCursorScreenPos()
                        if font[10] then imgui.PushFont(font[10]) end
                        local flbl = u8('\xcd\xce\xc2\xc8\xcd\xca\xc0')
                        local fsz  = imgui.CalcTextSize(flbl)
                        local padx = 6*MDS
                        local fw   = fsz.x + padx*2
                        dlf:AddRectFilled(imgui.ImVec2(fp.x,fp.y), imgui.ImVec2(fp.x+fw,fp.y+BADGE_H), u32c(0.90,0.16,0.10,1), 3*MDS)
                        dlf:AddText(imgui.ImVec2(fp.x+padx, fp.y+BADGE_H/2-fsz.y/2), u32c(1,1,1,1), flbl)
                        if font[10] then imgui.PopFont() end
                        imgui.Dummy(imgui.ImVec2(fw, BADGE_H))
                    end
                    if font[12] then imgui.PushFont(font[12]) end
                    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.65,0.60,0.50,1))
                    imgui.PushTextWrapPos(imgui.GetCursorPosX() + maxDescW)
                    imgui.TextUnformatted(sc.short)
                    imgui.PopTextWrapPos()
                    imgui.PopStyleColor(1)
                    if font[12] then imgui.PopFont() end
                    if sc.vip and (sc.price_text or sc.price_month) then
                        if font[11] then imgui.PushFont(font[11]) end
                        local priceLine = sc.price_text or
                            (u8('\xd6\xe5\xed\xe0: ')..sc.price_month..
                             u8('/\xec\xe5\xf1 \xe8\xeb\xe8 ')..(sc.price_year or '?')..u8('/\xe3\xee\xe4'))
                        imgui.TextColored(imgui.ImVec4(1.0,0.82,0.10,1), priceLine)
                        if font[11] then imgui.PopFont() end
                    end
                    imgui.EndGroup()
                    imgui.SetCursorScreenPos(imgui.ImVec2(startPos.x, startPos.y+CARD_H+6*MDS))
                    imgui.Dummy(imgui.ImVec2(CARD_W, 0))
                    if clicked and sc.tg_link then openLink(sc.tg_link) end
                end
                imgui.EndChild()
                imgui.EndTabItem()
            end
            imgui.EndTabBar()
        end
        imgui.EndChild()
        imgui.End()
    end
)
imgui.OnFrame(
    function() return render[0] end,
    function(self)
        self.HideCursor = true
        local DL = imgui.GetBackgroundDrawList()
        if renderOre[0] and
           (renderStone[0] or renderMetal[0] or renderSilver[0] or renderBronze[0] or renderGold[0]) and
           (showOreLine[0] or showOreDistance[0])
        then
            local oreNameAndColor = {
                {STAT_NAMES[1], settings.main.colorStone,  renderStone[0]},
                {STAT_NAMES[2], settings.main.colorMetal,  renderMetal[0]},
                {STAT_NAMES[3], settings.main.colorSilver, renderSilver[0]},
                {STAT_NAMES[4], settings.main.colorBronze, renderBronze[0]},
                {STAT_NAMES[5], settings.main.colorGold,   renderGold[0]},
            }
            local ok_p, mx, my, mz = pcall(getCharCoordinates, PLAYER_PED)
            if ok_p and mx then
                local cx, cy  = convert3DCoordsToScreen(mx, my, mz)
                local radius  = renderRadius[0]
                for k, entry in pairs(oreObjCache) do
                    local ox,oy,oz,v = entry[1],entry[2],entry[3],entry[4]
                    local nc = oreNameAndColor[v]
                    if nc and nc[3] then
                        local dist = safeDist3d(ox,oy,oz,mx,my,mz)
                        if dist <= radius and isPointOnScreen(ox, oy, oz, 0) then
                            local ok3, tx, ty = pcall(convert3DCoordsToScreen, ox, oy, oz)
                            if ok3 and tx and ty then
                                local col = cachedColor(nc[2])
                                if showOreLine[0] then
                                    DL:AddLine(imgui.ImVec2(tx,ty), imgui.ImVec2(cx,cy), u32c(0,0,0,0.35), 3.5*MDS)
                                    DL:AddLine(imgui.ImVec2(tx,ty), imgui.ImVec2(cx,cy), col, 1.8*MDS)
                                end
                                local text = ORE_LABEL
                                if showOreDistance[0] then text = text..' ['..math.floor(dist)..']' end
                                local fnt = font[renderSize[0]]
                                local fsz = renderSize[0] * MDS
                                local tsz = imgui.CalcTextSize(text)
                                local tx2 = tx - tsz.x*.5
                                local ty2 = ty - fsz - 2*MDS
                                if fnt then
                                    DL:AddTextFontPtr(fnt, fsz, imgui.ImVec2(tx2,ty2), col, text)
                                else
                                    DL:AddText(imgui.ImVec2(tx2,ty2), col, text)
                                end
                            end
                        end
                    end
                end
            end
        end
        if renderOre[0] and (showOreLine[0] or showOreDistance[0]) then
            local ok_p, px, py, pz = pcall(getCharCoordinates, PLAYER_PED)
            if ok_p and px and #ore3dCache > 0 then
                local cx, cy  = convert3DCoordsToScreen(px, py, pz)
                local radius  = renderRadius[0]
                local col3d   = cachedColor(settings.main.colorStone)
                local lineCol = imgui.GetColorU32Vec4(imgui.ImVec4(0.45,0.72,0.30,0.90))
                local lineShadow = u32c(0,0,0,0.35)
                for _, entry in ipairs(ore3dCache) do
                    local ox,oy,oz = entry[1],entry[2],entry[3]
                    local dist = safeDist3d(ox,oy,oz,px,py,pz)
                    if dist <= radius and isPointOnScreen(ox, oy, oz, 0) then
                        local ok_s, sx, sy = pcall(convert3DCoordsToScreen, ox, oy, oz)
                        if ok_s and sx and sy then
                            if showOreLine[0] then
                                DL:AddLine(imgui.ImVec2(cx,cy), imgui.ImVec2(sx,sy), lineShadow, 3.5*MDS)
                                DL:AddLine(imgui.ImVec2(cx,cy), imgui.ImVec2(sx,sy), lineCol, 1.8*MDS)
                            end
                            local lbl = ORE_LABEL
                            if showOreDistance[0] then lbl = lbl..' ['..math.floor(dist)..']' end
                            local fnt = font[renderSize[0]]
                            local fsz = renderSize[0] * MDS
                            local tsz = imgui.CalcTextSize(lbl)
                            local lx = sx - tsz.x*.5
                            local ly = sy - fsz - 2*MDS
                            if fnt then
                                DL:AddTextFontPtr(fnt, fsz, imgui.ImVec2(lx,ly), col3d, lbl)
                            else
                                DL:AddText(imgui.ImVec2(lx,ly), col3d, lbl)
                            end
                        end
                    end
                end
            end
        end
        if oreTimer[0] then
            local ok0, mx, my, mz = pcall(getCharCoordinates, PLAYER_PED)
            if ok0 and mx then
                local cx, cy = convert3DCoordsToScreen(mx, my, mz)
                for k = #oreTimerList, 1, -1 do
                    local v    = oreTimerList[k]
                    local diff = v[4] - os.time()
                    if diff < 0 then
                        table.remove(oreTimerList, k)
                    else
                        local ok_s, tx, ty = pcall(convert3DCoordsToScreen, v[1], v[2], v[3])
                        if ok_s and tx and ty then
                            local dist    = math.floor(safeDist3d(v[1],v[2],v[3],mx,my,mz))
                            local timeStr = os.date('%M:%S', diff)
                            local text
                            if diff < 60 then
                                text = ORE_REMAIN..timeStr..'!'
                                    ..(oreTimerDistance[0] and (' ['..dist..']') or '')
                            else
                                text = timeStr..(oreTimerDistance[0] and (' ['..dist..']') or '')
                            end
                            if isPointOnScreen(v[1], v[2], v[3], 0) then
                                imgui.SetNextWindowPos(imgui.ImVec2(tx,ty), imgui.Cond.Always, imgui.ImVec2(0.5,1))
                                imgui.SetNextWindowBgAlpha(0)
                                imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0)
                                imgui.Begin(tostring(k)..'t', oreTimer,
                                    imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoCollapse +
                                    imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoTitleBar)
                                if font[renderOreTimerSize[0]] then imgui.PushFont(font[renderOreTimerSize[0]]) end
                                imgui.CenterHeader(text, argbToVec4(settings.main.colorOreTimer))
                                if font[renderOreTimerSize[0]] then imgui.PopFont() end
                                imgui.End()
                                imgui.PopStyleVar()
                                if oreTimerLine[0] then
                                    DL:AddLine(imgui.ImVec2(tx,ty), imgui.ImVec2(cx,cy),
                                        cachedColor(settings.main.colorOreTimer))
                                end
                            end
                        end
                    end
                end
            end
        end
        if #catPending > 0 then
            local item = table.remove(catPending, 1)
            if doesFileExist(item.path) then
                local ok_tex, tex = pcall(imgui.CreateTextureFromFile, item.path)
                catTextures[item.file] = (ok_tex and tex) or 'failed'
            else
                catTextures[item.file] = 'failed'
            end
        end
    end
)
imgui.OnFrame(
    function()
        return statisticsWindow[0] and
               (statisticsStone[0] or statisticsMetal[0] or statisticsSilver[0] or
                statisticsBronze[0] or statisticsGold[0] or statisticsCoal[0] or totalPrice[0])
    end,
    function(self)
        self.HideCursor = false
        if statisticsWindow[0] and
           (statisticsStone[0] or statisticsMetal[0] or statisticsSilver[0] or
            statisticsBronze[0] or statisticsGold[0] or statisticsCoal[0] or totalPrice[0])
        then
            local oreRows = {
                {STAT_NAMES[1], settings.main.countStone,  settings.main.priceStone,  statisticsStone[0],  0.85,0.85,0.85},
                {STAT_NAMES[2], settings.main.countMetal,  settings.main.priceMetal,  statisticsMetal[0],  0.65,0.65,0.70},
                {STAT_NAMES[3], settings.main.countSilver, settings.main.priceSilver, statisticsSilver[0], 0.72,0.80,0.95},
                {STAT_NAMES[4], settings.main.countBronze, settings.main.priceBronze, statisticsBronze[0], 0.82,0.52,0.22},
                {STAT_NAMES[5], settings.main.countGold,   settings.main.priceGold,   statisticsGold[0],   0.98,0.82,0.10},
                {STAT_NAMES[6], settings.main.countCoal,   settings.main.priceCoal,   statisticsCoal[0],   0.40,0.40,0.42},
            }
            local visRows = {}
            local totalEarned = 0
            for _, row in ipairs(oreRows) do
                if row[4] then
                    table.insert(visRows, row)
                    totalEarned = totalEarned + row[2] * row[3]
                end
            end
            local fntS   = font[13] or font[14]
            local fntH   = font[15] or font[14]
            local rowH   = 22*MDS
            local padX   = 10*MDS
            local padTop = 34*MDS
            local padBot = totalPrice[0] and (rowH + 8*MDS) or 6*MDS
            local hudW   = 175*MDS
            local hudH   = padTop + #visRows * rowH + padBot
            imgui.SetNextWindowPos(
                imgui.ImVec2(settings.main.statisticsPosX, settings.main.statisticsPosY),
                imgui.Cond.FirstUseEver)
            imgui.SetNextWindowSize(imgui.ImVec2(hudW, hudH), imgui.Cond.Always)
            imgui.SetNextWindowBgAlpha(0)
            local hudFlags = imgui.WindowFlags.NoTitleBar
                           + imgui.WindowFlags.NoResize
                           + imgui.WindowFlags.NoScrollbar
                           + imgui.WindowFlags.NoScrollWithMouse
                           + imgui.WindowFlags.NoCollapse
                           + imgui.WindowFlags.NoSavedSettings
            imgui.Begin('##stats_hud', statisticsWindow, hudFlags)
            local sp = imgui.GetWindowPos()
            settings.main.statisticsPosX = sp.x
            settings.main.statisticsPosY = sp.y
            local DLh = imgui.GetWindowDrawList()
            local wx  = sp.x
            local wy  = sp.y
            DLh:AddRectFilled(
                imgui.ImVec2(wx, wy),
                imgui.ImVec2(wx+hudW, wy+hudH),
                u32c(0.05,0.04,0.03,0.93), 6*MDS)
            DLh:AddRect(
                imgui.ImVec2(wx, wy),
                imgui.ImVec2(wx+hudW, wy+hudH),
                u32c(0.50,0.35,0.12,0.70), 6*MDS)
            DLh:AddRectFilledMultiColor(
                imgui.ImVec2(wx, wy),
                imgui.ImVec2(wx+hudW, wy+padTop-4*MDS),
                u32c(0.55,0.20,0.05,1), u32c(0.30,0.10,0.02,1),
                u32c(0.30,0.10,0.02,1), u32c(0.55,0.20,0.05,1))
            DLh:AddLine(
                imgui.ImVec2(wx, wy+padTop-4*MDS),
                imgui.ImVec2(wx+hudW, wy+padTop-4*MDS),
                u32c(0.88,0.68,0.18,0.9), 1.5*MDS)
            local titleTxt = STAT_TITLE
            if fntH then
                local tszH = imgui.CalcTextSize(titleTxt)
                DLh:AddTextFontPtr(fntH, 15*MDS,
                    imgui.ImVec2(wx + hudW/2 - tszH.x/2, wy + (padTop-4*MDS)/2 - tszH.y/2),
                    u32c(1.0,0.92,0.75,1), titleTxt)
            end
            for i, row in ipairs(visRows) do
                local ry = wy + padTop + (i-1)*rowH
                if i > 1 then
                    DLh:AddLine(
                        imgui.ImVec2(wx+padX, ry),
                        imgui.ImVec2(wx+hudW-padX, ry),
                        u32c(1,1,1,0.06), 1)
                end
                local nameCol = u32c(row[5],row[6],row[7],0.95)
                if fntS then
                    DLh:AddTextFontPtr(fntS, 13*MDS,
                        imgui.ImVec2(wx+padX, ry+3*MDS), nameCol, row[1])
                end
                local cntTxt = tostring(row[2])
                local cntSz  = fntS and imgui.CalcTextSize(cntTxt) or imgui.ImVec2(30*MDS,0)
                local cntCol = row[2] > 0 and u32c(0.55,0.95,0.45,1) or u32c(0.50,0.50,0.50,1)
                if fntS then
                    DLh:AddTextFontPtr(fntS, 13*MDS,
                        imgui.ImVec2(wx+hudW-padX-cntSz.x, ry+3*MDS), cntCol, cntTxt)
                end
            end
            if totalPrice[0] then
                local sepY = wy + padTop + #visRows * rowH + 2*MDS
                DLh:AddLine(
                    imgui.ImVec2(wx+padX, sepY),
                    imgui.ImVec2(wx+hudW-padX, sepY),
                    u32c(0.88,0.68,0.18,0.5), 1*MDS)
                local prTxt = STAT_PROFIT..convertToPriceFormat(totalEarned)
                if fntS then
                    local prSz = imgui.CalcTextSize(prTxt)
                    DLh:AddTextFontPtr(fntS, 13*MDS,
                        imgui.ImVec2(wx + hudW/2 - prSz.x/2, sepY + 5*MDS),
                        u32c(0.98,0.82,0.10,1), prTxt)
                end
            end
            imgui.End()
        end
    end
)
function sampev.onSetObjectMaterial(id, data)
    local ok, object = pcall(sampGetObjectHandleBySampId, id)
    if not ok or not object then return end
    local ok2, model = pcall(getObjectModel, object)
    if not ok2 then return end
    if doesObjectExist(object) and model == 3930 then
        if oreTextures[data.textureName] then
            local ok_c, ox, oy, oz = pcall(getObjectCoordinates, object)
            local x = ok_c and tonumber(ox) or nil
            local y = ok_c and tonumber(oy) or nil
            local z = ok_c and tonumber(oz) or nil
            if not (x and y and z) then return end
            local bool = true
            for k, v in pairs(resources) do
                local ok3, oh = pcall(sampGetObjectHandleBySampId, k)
                if ok3 and oh then
                    local ok4, ex, ey, ez = pcall(getObjectCoordinates, oh)
                    if ok4 then
                        local nx2,ny2,nz2 = tonumber(ex),tonumber(ey),tonumber(ez)
                        if nx2 and ny2 and nz2 then
                            if safeDist3d(x,y,z,nx2,ny2,nz2) < 1 then
                                bool = false
                                if oreTextures[data.textureName] > v then
                                    resources[k] = nil
                                    oreObjCache[k] = nil
                                    bool = true
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if bool then
                resources[id] = oreTextures[data.textureName]
                oreObjCache[id] = {x, y, z, oreTextures[data.textureName]}
            end
        end
    end
end
function sampev.onDestroyObject(id)
    if resources[id] then
        resources[id]   = nil
        oreObjCache[id] = nil
    end
end
function sampev.onSendSpawn()
    local ok, skin = pcall(getCharModel, PLAYER_PED)
    if ok then
        settings.main.defoltSkin = skin
        inicfg.save(settings, CFG_FILE)
        if cjSkin[0] and skin ~= 74 then
            local ok2, pid = pcall(function() return select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) end)
            if ok2 then set_player_skin(pid, 74) end
        end
    end
end
function sampev.onCreate3DText(id, color, position, dist, testLOS, player, vehicle, text)
    if type(text) ~= 'string' then return end
    if text:find('\xcc\xe5\xf1\xf2\xee\xf0\xee\xe6\xe4\xe5\xed\xe8\xe5') then
        local px = tonumber(type(position)=='table' and position.x or nil)
        local py = tonumber(type(position)=='table' and position.y or nil)
        local pz = tonumber(type(position)=='table' and position.z or nil)
        if px and py and pz then
            textsTable[id] = {x=px, y=py, z=pz}
        end
    end
    if text:find('\xcc\xe5\xf1\xf2\xee\xf0\xee\xe6\xe4\xe5\xed\xe8\xe5 \xf0\xe5\xf1\xf3\xf0\xf1\xee\xe2') then
        local px = tonumber(type(position)=='table' and position.x or nil)
        local py = tonumber(type(position)=='table' and position.y or nil)
        local pz = tonumber(type(position)=='table' and position.z or nil)
        if not (px and py and pz) then return end
        for k, v in ipairs(oreTimerList) do
            if v[1]==px and v[2]==py and v[3]==pz then
                table.remove(oreTimerList, k); break
            end
        end
    end
end
function sampev.onRemove3DTextLabel(id)
    if textsTable[id] then
        local info = textsTable[id]
        local ok, text2 = pcall(function()
            local t = sampGet3dTextInfoById(id)
            return t
        end)
        if ok and text2 and text2:find('\xcc\xe5\xf1\xf2\xee\xf0\xee\xe6\xe4\xe5\xed\xe8\xe5 \xf0\xe5\xf1\xf3\xf0\xf1\xee\xe2') then
            if info.x and info.y and info.z then
                table.insert(oreTimerList, {info.x, info.y, info.z, os.time()+375})
            end
        end
        textsTable[id] = nil
    end
end
function sampev.onSendPlayerSync(data)
    if tp then return false end
    if autoDig[0] then
        a = a + 1
        if a >= 3 then
            a = 0
            local px = safeNum(data.position and data.position.x)
            local py = safeNum(data.position and data.position.y)
            local pz = safeNum(data.position and data.position.z)
            local near = false
            for _, v in pairs(textsTable) do
                if safeDist3d(px,py,pz, v.x,v.y,v.z) < 3.0 then near = true; break end
            end
            if not near then
                for _, v in ipairs(ore3dCache) do
                    if safeDist3d(px,py,pz, v[1],v[2],v[3]) < 3.0 then near = true; break end
                end
            end
            if near then data.keysData = 1024 end
        end
    end
    if bit.band(data.keysData, 0x28) == 0x28 and antiBhop[0] then
        data.keysData = bit.bxor(data.keysData, 0x20)
    end
end
function sampev.onSendVehicleSync(data)
    if tp then return false end
end
function sampev.onDisplayGameText(style, time, text)
    if type(text) ~= 'string' then return end
    local oreKey = nil
    local lower = text:lower()
    if lower:find('^stone') then oreKey = 'countStone'
    elseif lower:find('^metal') then oreKey = 'countMetal'
    elseif lower:find('^bronze') then oreKey = 'countBronze'
    elseif lower:find('^silver') then oreKey = 'countSilver'
    elseif lower:find('^gold') then oreKey = 'countGold'
    end
    if oreKey then
        local num = tonumber(text:match('%+%s*(%d+)'))
        if num and num >= 1 and num <= 10 then
            settings.main[oreKey] = (settings.main[oreKey] or 0) + num
            inicfg.save(settings, CFG_FILE)
            playOreSound()
        end
    end
end
function sampev.onServerMessage(color, text)
    if type(text) ~= 'string' then return end
    local clean = text:gsub('{%x%x%x%x%x%x}', '')
    if clean:find('\xd3\xe3\xee\xeb\xfc') then
        local amt = tonumber(clean:match('%((%d+)%s*\xf8\xf2%)'))
        if amt and amt >= 1 and amt <= 10 then
            settings.main.countCoal = (settings.main.countCoal or 0) + amt
            inicfg.save(settings, CFG_FILE)
            playOreSound()
        end
    end
end
addEventHandler('onScriptTerminate', function(scr)
    if scr == script.this then
        if wallHack[0] then pcall(nameTagOff) end
        setGameKeyState(16, 0)
        pcall(function()
            if bass then
                if oreStream ~= 0 then bass.BASS_ChannelStop(oreStream); bass.BASS_StreamFree(oreStream) end
            end
        end)
    end
end)
