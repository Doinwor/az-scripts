script_name('\xd2\xf0\xe0\xed\xf1\xf4\xee\xf0\xec\xe0\xf6\xe8\xff')
script_author('transform')
script_version('1.3')
script_version_number(1)
script_properties('work-in-pause')

local imgui   = require('mimgui')
local encoding= require('encoding')
local inicfg  = require('inicfg')
local sampev  = require('lib.samp.events')
local faicons = require('fAwesome6')
local fa      = require('fAwesome6_solid')

encoding.default = 'CP1251'
local u8  = encoding.UTF8
local MDS = MONET_DPI_SCALE
local sw, sh = getScreenResolution()
local ffi = require('ffi')

local SOUND_URL  = 'https://files.catbox.moe/9ru4ij.mp3'
local SOUND_DIR  = getWorkingDirectory() .. '/transform_btn'
local SOUND_PATH = SOUND_DIR .. '/transform.mp3'

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

local function playSound()
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
            bass.BASS_ChannelSetAttribute(stream, 2, 1.0)
            bass.BASS_ChannelPlay(stream, 1)
        end
    end)
end

local CFG = 'transform_btn.ini'
local ini = inicfg.load({
    btn = {
        x            = math.floor(sw * 0.25),
        y            = math.floor(sh * 0.78),
        visible      = true,
        move_mode    = false,
        anticarskill = false,
    }
}, CFG)
inicfg.save(ini, CFG)

local showBtn    = ini.btn.visible      == true
local moveMode   = ini.btn.move_mode    == true
local acsEnabled = ini.btn.anticarskill == true

local cooldown   = false
local flashTime  = 0
local posX       = ini.btn.x + 0.0
local posY       = ini.btn.y + 0.0

local prevDragH  = 0
local prevDragV  = 0

local function savePos()
    ini.btn.x            = math.floor(posX)
    ini.btn.y            = math.floor(posY)
    ini.btn.move_mode    = moveMode
    ini.btn.anticarskill = acsEnabled
    ini.btn.visible      = showBtn
    inicfg.save(ini, CFG)
end

function sampev.onSendVehicleDamaged(...)
    if acsEnabled then return false end
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.GetStyle():ScaleAllSizes(MDS)
    local io2 = imgui.GetIO()
    local cfg = imgui.ImFontConfig()
    cfg.MergeMode  = true
    cfg.PixelSnapH = true
    local range = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    io2.Fonts:AddFontFromMemoryCompressedBase85TTF(
        faicons.get_font_data_base85('solid'), 18*MDS, cfg, range)
end)

imgui.OnFrame(
    function() return showBtn end,
    function(self)
        self.HideCursor = false

        local BW       = 130 * MDS
        local SW_      = 34  * MDS
        local BH       = 48  * MDS
        local TOTAL_W  = SW_ + BW + SW_
        local STAB_H   = 28  * MDS
        local STAB_GAP = 4   * MDS
        local MOVE_EXTRA = moveMode and (STAB_GAP + STAB_H + STAB_GAP + STAB_H + STAB_GAP) or 0
        local WIN_W  = TOTAL_W
        local WIN_H  = BH + MOVE_EXTRA

        posX = math.max(0, math.min(sw - WIN_W, posX))
        posY = math.max(0, math.min(sh - WIN_H, posY))

        imgui.SetNextWindowPos(imgui.ImVec2(posX, posY), imgui.Cond.Always)
        imgui.SetNextWindowSize(imgui.ImVec2(WIN_W, WIN_H), imgui.Cond.Always)

        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0,0,0,0))
        imgui.PushStyleColor(imgui.Col.Border,   imgui.ImVec4(0,0,0,0))

        imgui.Begin('##bb_win', nil,
            imgui.WindowFlags.NoTitleBar  +
            imgui.WindowFlags.NoResize    +
            imgui.WindowFlags.NoMove      +
            imgui.WindowFlags.NoScrollbar +
            imgui.WindowFlags.NoBackground)

        local dl = imgui.GetWindowDrawList()
        local wp = imgui.GetWindowPos()

        local elapsed = os.clock() - flashTime
        local isFlash = elapsed < 0.25
        local prog    = math.min(elapsed / 0.25, 1.0)

        dl:AddRectFilled(
            imgui.ImVec2(wp.x, wp.y),
            imgui.ImVec2(wp.x + TOTAL_W, wp.y + BH),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.06, 0.06, 0.06, 0.92)),
            10 * MDS)

        dl:AddRect(
            imgui.ImVec2(wp.x, wp.y),
            imgui.ImVec2(wp.x + TOTAL_W, wp.y + BH),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0, 1.0, 1.0, 0.10)),
            10 * MDS, 0, 1 * MDS)

        dl:AddRectFilled(
            imgui.ImVec2(wp.x + 3*MDS, wp.y + 6*MDS),
            imgui.ImVec2(wp.x + TOTAL_W - 3*MDS, wp.y + BH + 6*MDS),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0, 0, 0, 0.4)),
            10 * MDS)

        local cx0 = wp.x + SW_
        local cx1 = wp.x + SW_ + BW
        local cy0 = wp.y
        local cy1 = wp.y + BH

        dl:AddRectFilledMultiColor(
            imgui.ImVec2(cx0, cy0),
            imgui.ImVec2(cx0 + BW * 0.5, cy1),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.106, 0.157, 0.220, 1.0)),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.086, 0.102, 0.129, 1.0)),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.086, 0.102, 0.129, 1.0)),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.106, 0.157, 0.220, 1.0)))

        dl:AddRectFilledMultiColor(
            imgui.ImVec2(cx0 + BW * 0.5, cy0),
            imgui.ImVec2(cx1, cy1),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.086, 0.102, 0.129, 1.0)),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.545, 0.176, 0.176, 1.0)),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.545, 0.176, 0.176, 1.0)),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.086, 0.102, 0.129, 1.0)))

        if isFlash then
            local alpha = 0.25 * (1.0 - prog)
            dl:AddRectFilled(
                imgui.ImVec2(cx0, cy0),
                imgui.ImVec2(cx1, cy1),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0, 0.82, 0.0, alpha)),
                0)
        end

        dl:AddLine(
            imgui.ImVec2(wp.x + SW_, wp.y + 6*MDS),
            imgui.ImVec2(wp.x + SW_, wp.y + BH - 6*MDS),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0, 1.0, 1.0, 0.10)),
            1 * MDS)

        dl:AddLine(
            imgui.ImVec2(wp.x + SW_ + BW, wp.y + 6*MDS),
            imgui.ImVec2(wp.x + SW_ + BW, wp.y + BH - 6*MDS),
            imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0, 1.0, 1.0, 0.10)),
            1 * MDS)

        if cooldown then
            local p    = math.min((os.clock() - flashTime) / 1.5, 1.0)
            local barW = BW * (1.0 - p)
            dl:AddRectFilled(
                imgui.ImVec2(cx0, wp.y + BH - 3*MDS),
                imgui.ImVec2(cx0 + barW, wp.y + BH - 1*MDS),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0, 0.82, 0.0, 1.0)),
                1 * MDS)
        end

        imgui.GetStyle().FrameRounding   = 0
        imgui.GetStyle().FrameBorderSize = 0

        if acsEnabled then
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.26, 1.0, 0.26, 0.10))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.26, 1.0, 0.26, 0.20))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.26, 1.0, 0.26, 0.30))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.26, 1.0, 0.26, 1.0))
        else
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0, 0, 0, 0))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1, 1, 1, 0.05))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(1, 1, 1, 0.10))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.0, 1.0, 1.0, acsEnabled and 1.0 or 0.35))
        end
        imgui.SetCursorPos(imgui.ImVec2(0, 0))
        if imgui.Button(fa.SHIELD, imgui.ImVec2(SW_, BH)) then
            acsEnabled = not acsEnabled
            savePos()
        end
        imgui.PopStyleColor(4)

        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0, 0, 0, 0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1.0, 1.0, 1.0, 0.06))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0, 0, 0, 0.3))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.0, 1.0, 1.0, 1.0))
        imgui.GetStyle().ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
        imgui.SetCursorPos(imgui.ImVec2(SW_, 0))
        local label = fa.BOLT .. '  ' .. u8('\xd2\xd0\xc0\xcd\xd1\xd4\xce\xd0\xcc')
        local clicked = imgui.Button(label, imgui.ImVec2(BW, BH))
        imgui.PopStyleColor(4)

        if clicked and not cooldown then
            cooldown  = true
            flashTime = os.clock()
            playSound()
            sampSendChat('/anims 1')
            lua_thread.create(function()
                wait(1500)
                cooldown = false
            end)
        end

        if moveMode then
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.99, 0.84, 0.0, 0.15))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.99, 0.84, 0.0, 0.28))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.99, 0.84, 0.0, 0.40))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.99, 0.84, 0.0, 1.0))
        else
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0, 0, 0, 0))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.99, 0.84, 0.0, 0.10))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.99, 0.84, 0.0, 0.20))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.99, 0.84, 0.0, 1.0))
        end
        imgui.SetCursorPos(imgui.ImVec2(SW_ + BW, 0))
        if imgui.Button(fa.ARROWS_UP_DOWN_LEFT_RIGHT, imgui.ImVec2(SW_, BH)) then
            moveMode = not moveMode
            if not moveMode then savePos() end
        end
        imgui.PopStyleColor(4)

        if moveMode then
            local tabY0   = BH + STAB_GAP
            local tabY1   = BH + STAB_GAP + STAB_H + STAB_GAP
            local PAD     = 8  * MDS
            local LABEL_W = 22 * MDS
            local slW     = TOTAL_W - PAD * 2 - LABEL_W

            dl:AddRectFilled(
                imgui.ImVec2(wp.x, wp.y + BH + STAB_GAP * 0.5),
                imgui.ImVec2(wp.x + TOTAL_W, wp.y + WIN_H),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.06, 0.06, 0.06, 0.88)),
                8 * MDS)

            dl:AddRect(
                imgui.ImVec2(wp.x, wp.y + BH + STAB_GAP * 0.5),
                imgui.ImVec2(wp.x + TOTAL_W, wp.y + WIN_H),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.99, 0.84, 0.0, 0.30)),
                8 * MDS, 0, 1 * MDS)

            imgui.PushStyleColor(imgui.Col.FrameBg,          imgui.ImVec4(0.15, 0.12, 0.0, 0.9))
            imgui.PushStyleColor(imgui.Col.FrameBgHovered,   imgui.ImVec4(0.22, 0.18, 0.0, 1.0))
            imgui.PushStyleColor(imgui.Col.FrameBgActive,    imgui.ImVec4(0.28, 0.22, 0.0, 1.0))
            imgui.PushStyleColor(imgui.Col.SliderGrab,       imgui.ImVec4(0.99, 0.84, 0.0, 1.0))
            imgui.PushStyleColor(imgui.Col.SliderGrabActive, imgui.ImVec4(1.0,  0.92, 0.2, 1.0))
            imgui.PushStyleColor(imgui.Col.Text,             imgui.ImVec4(0.99, 0.84, 0.0, 0.80))
            imgui.GetStyle().FrameRounding = 6 * MDS
            imgui.GetStyle().GrabRounding  = 4 * MDS
            imgui.GetStyle().GrabMinSize   = 20 * MDS

            imgui.SetCursorPos(imgui.ImVec2(PAD, tabY0))
            imgui.Text(fa.LEFT_RIGHT)
            imgui.SameLine()
            local hSP  = imgui.GetCursorScreenPos()
            local maxX = math.max(1, sw - WIN_W)
            dl:AddRectFilled(
                imgui.ImVec2(hSP.x, hSP.y),
                imgui.ImVec2(hSP.x + slW, hSP.y + STAB_H),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.15, 0.12, 0.0, 0.9)),
                6 * MDS)
            local hFrac  = math.max(0, math.min(1, posX / maxX))
            local hGrabW = 20 * MDS
            local hGrabX = hSP.x + hFrac * (slW - hGrabW)
            dl:AddRectFilled(
                imgui.ImVec2(hGrabX, hSP.y + 2*MDS),
                imgui.ImVec2(hGrabX + hGrabW, hSP.y + STAB_H - 2*MDS),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.99, 0.84, 0.0, 1.0)),
                4 * MDS)
            imgui.SetCursorPos(imgui.ImVec2(PAD + LABEL_W, tabY0))
            imgui.InvisibleButton('##hdrag', imgui.ImVec2(slW, STAB_H))
            if imgui.IsItemActive() then
                local drag = imgui.GetMouseDragDelta(0, 0)
                local dx   = drag.x - prevDragH
                prevDragH  = drag.x
                posX = math.max(0, math.min(maxX, posX + dx))
                savePos()
            else
                prevDragH = 0
            end

            local scrollV = imgui.new.int(math.floor(posY / math.max(1, sh - WIN_H) * 1000))
            imgui.SetCursorPos(imgui.ImVec2(PAD, tabY1))
            imgui.Text(fa.UP_DOWN)
            imgui.SameLine()
            imgui.SetNextItemWidth(slW)
            if imgui.SliderInt('##vscroll', scrollV, 0, 1000, '') then
                local maxY = math.max(1, sh - WIN_H)
                posY = math.floor(scrollV[0] / 1000.0 * maxY)
                savePos()
            end

            imgui.PopStyleColor(6)
        end

        imgui.End()
        imgui.PopStyleColor(2)
    end
)

function main()
    lua_thread.create(function()
        if not doesFileExist(SOUND_PATH) then
            if not doesDirectoryExist(SOUND_DIR) then
                createDirectory(SOUND_DIR)
            end
            local ok, requests = pcall(require, 'requests')
            if ok and requests then
                local r_ok, resp = pcall(requests.get, SOUND_URL)
                if r_ok and resp and resp.status_code == 200 then
                    local f = io.open(SOUND_PATH, 'wb')
                    if f then f:write(resp.text); f:close() end
                end
            end
        end
    end)

    while not isSampAvailable() do wait(100) end
    while not sampIsLocalPlayerSpawned() do wait(0) end

    sampRegisterChatCommand('tform', function()
        showBtn = not showBtn
        savePos()
        sampAddChatMessage(
            '{FFD200}[\xd2\xd0\xc0\xcd\xd1\xd4\xce\xd0\xcc]{FFFFFF} ' ..
            (showBtn
                and '\xef\xee\xea\xe0\xe7\xe0\xed\xe0'
                or  '\xf1\xea\xf0\xfb\xf2\xe0'),
            -1)
    end)

    sampAddChatMessage(
        '{FFD200}[\xd2\xd0\xc0\xcd\xd1\xd4\xce\xd0\xcc]{FFFFFF} ' ..
        '\xe7\xe0\xe3\xf0\xf3\xe6\xe5\xed\xe0! /tform \xe2\xea\xeb/\xe2\xfb\xea\xeb',
        -1)

    while true do
        if WIDGET_RADAR ~= nil and isWidgetDoubletapped(WIDGET_RADAR) then
            showBtn = not showBtn
            savePos()
        end
        wait(0)
    end
end
