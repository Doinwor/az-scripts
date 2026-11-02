script_name('BarMenu')
script_author('Victor Strand')
script_version('1.2-monet')
script_description('Bar coin-flip menu for Arizona RP')

local imgui = require('mimgui')
local enc   = require('encoding')
local ffi   = require('ffi')
enc.default = 'CP1251'
local u8    = enc.UTF8

local MDS     = MONET_DPI_SCALE
local sw, sh  = getScreenResolution()

local idBuf  = ffi.new('char[8]')
local sumBuf = ffi.new('char[10]')
ffi.copy(idBuf,  '0\0',    2)
ffi.copy(sumBuf, '1000\0', 6)

local curID  = '0'
local curSum = '1000'

local wMenu    = imgui.new.bool(false)
local wVisible = imgui.new.bool(true)

local editMode   = false
local dragTarget = nil

local BW = 82 * MDS
local BH = 32 * MDS

local _BW     = 82  * MDS
local _gap    = 6   * MDS
local _totalW = 5 * _BW + 4 * _gap
local _sx     = sw / 2 - _totalW / 2
local _sy     = sh - 80 * MDS

local BTNS = {
    { id='accept', x=_sx+0*(_BW+_gap), y=_sy,
      colN={0.11,0.50,0.24,1}, colH={0.15,0.63,0.30,1}, colA={0.07,0.36,0.16,1} },
    { id='eagle',  x=_sx+1*(_BW+_gap), y=_sy,
      colN={0.16,0.40,0.72,1}, colH={0.20,0.50,0.86,1}, colA={0.10,0.28,0.55,1} },
    { id='tails',  x=_sx+2*(_BW+_gap), y=_sy,
      colN={0.55,0.36,0.06,1}, colH={0.68,0.46,0.10,1}, colA={0.40,0.26,0.04,1} },
    { id='reject', x=_sx+3*(_BW+_gap), y=_sy,
      colN={0.58,0.13,0.13,1}, colH={0.72,0.18,0.18,1}, colA={0.42,0.08,0.08,1} },
    { id='cfg',    x=_sx+4*(_BW+_gap), y=_sy,
      colN={0.18,0.18,0.22,1}, colH={0.26,0.26,0.32,1}, colA={0.12,0.12,0.16,1} },
}

local function iv4(r,g,b,a) return imgui.ImVec4(r,g,b,a or 1) end
local function iv2(x,y)     return imgui.ImVec2(x,y) end

local function col32(r,g,b,a)
    return imgui.ColorConvertFloat4ToU32(imgui.ImVec4(r,g,b,a or 1))
end

local function ffiStr(buf, maxlen)
    local t = {}
    for i = 0, maxlen-1 do
        local b = buf[i]
        if not b or b == 0 then break end
        t[#t+1] = string.char(b)
    end
    return table.concat(t)
end

local L = {
    accept   = u8('\xcf\xf0\xe8\xed\xff\xf2\xfc'),
    eagle    = u8('\xce\xf0\xb8\xeb'),
    tails    = u8('\xd0\xe5\xf8\xea\xe0'),
    reject   = u8('\xce\xf2\xea\xe0\xe7'),
    cfg      = u8('\xcd\xe0\xf1\xf2\xf0'),
    settings = u8('\xcd\xe0\xf1\xf2\xf0\xee\xe9\xea\xe8'),
    idlabel  = u8('\x49\x44\x20\xe8\xe3\xf0\xee\xea\xe0\x3a'),
    sumlabel = u8('\xd1\xf3\xec\xec\xe0\x20\x28\x24\x29\x3a'),
    close    = u8('\xc7\xe0\xea\xf0\xfb\xf2\xfc'),
    editpos  = u8('\xd0\xe5\xe4\x2e\xef\xee\xe7'),
    save     = u8('\xd1\xee\xf5\xf0\xe0\xed\xe8\xf2\xfc'),
    tapfix   = u8('\xd2\xe0\xef \xe4\xeb\xff \xf4\xe8\xea\xf1\xe0\xf6\xe8\xe8'),
}

local LABELS = {
    accept = L.accept,
    eagle  = L.eagle,
    tails  = L.tails,
    reject = L.reject,
    cfg    = L.cfg,
}

local function getAction(id)
    if id == 'accept' then return function() sampSendChat('/oyes') end
    elseif id == 'eagle'  then return function() sampSendChat('/orel '..curID..' '..curSum) end
    elseif id == 'tails'  then return function() sampSendChat('/reshka '..curID..' '..curSum) end
    elseif id == 'reject' then return function() sampSendChat('/ono') end
    elseif id == 'cfg'    then return function() wMenu[0] = not wMenu[0] end
    end
end

local fMain

imgui.OnInitialize(function()
    imgui.SwitchContext()
    local io = imgui.GetIO()
    io.IniFilename = nil
    imgui.GetStyle():ScaleAllSizes(MDS)

    local s   = imgui.GetStyle()
    s.WindowRounding   = 6*MDS
    s.FrameRounding    = 5*MDS
    s.GrabRounding     = 5*MDS
    s.WindowBorderSize = 1
    s.FrameBorderSize  = 0
    s.ItemSpacing      = iv2(5*MDS, 4*MDS)
    s.FramePadding     = iv2(6*MDS, 4*MDS)
    s.WindowPadding    = iv2(8*MDS, 6*MDS)

    local c   = s.Colors
    local Col = imgui.Col
    c[Col.WindowBg]        = iv4(0.07,0.07,0.09,0.95)
    c[Col.TitleBg]         = iv4(0.09,0.09,0.11,1)
    c[Col.TitleBgActive]   = iv4(0.11,0.11,0.14,1)
    c[Col.FrameBg]         = iv4(0.13,0.13,0.16,1)
    c[Col.FrameBgHovered]  = iv4(0.17,0.17,0.21,1)
    c[Col.FrameBgActive]   = iv4(0.21,0.21,0.27,1)
    c[Col.Button]          = iv4(0.16,0.16,0.20,1)
    c[Col.ButtonHovered]   = iv4(0.23,0.23,0.28,1)
    c[Col.ButtonActive]    = iv4(0.10,0.10,0.14,1)
    c[Col.Text]            = iv4(0.94,0.92,0.86,1)
    c[Col.TextDisabled]    = iv4(0.44,0.44,0.49,1)
    c[Col.Border]          = iv4(0.20,0.20,0.26,1)
    c[Col.Separator]       = iv4(0.20,0.20,0.26,1)
    c[Col.Header]          = iv4(0.19,0.19,0.25,1)
    c[Col.HeaderHovered]   = iv4(0.24,0.24,0.31,1)

    local ttf    = getWorkingDirectory()..'/lib/mimgui/trebucbd.ttf'
    local ranges = io.Fonts:GetGlyphRangesCyrillic()
    fMain = io.Fonts:AddFontFromFileTTF(ttf, 14*MDS, nil, ranges)
end)

local noWinFlags =
    imgui.WindowFlags.NoTitleBar   + imgui.WindowFlags.NoResize     +
    imgui.WindowFlags.NoMove       + imgui.WindowFlags.NoScrollbar   +
    imgui.WindowFlags.NoBackground + imgui.WindowFlags.NoNav         +
    imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.AlwaysAutoResize

imgui.OnFrame(
    function() return wVisible[0] end,
    function(self)
        self.HideCursor = false
        self.LockPlayer = false

        local io  = imgui.GetIO()
        local mx  = io.MousePos.x
        local my  = io.MousePos.y
        local dl  = imgui.GetForegroundDrawList()

        if fMain then imgui.PushFont(fMain) end

        for _, btn in ipairs(BTNS) do
            local bx = btn.x
            local by = btn.y

            if editMode then
                if dragTarget == btn.id then
                    if io.MouseDown[0] then
                        btn.x = math.max(0, math.min(sw - BW, mx - BW/2))
                        btn.y = math.max(0, math.min(sh - BH, my - BH/2))
                        bx = btn.x
                        by = btn.y
                    else
                        dragTarget = nil
                    end
                end

                local pulse = 0.50 + 0.50 * math.abs(math.sin(os.clock() * 3.5))
                dl:AddRect(iv2(bx-2, by-2), iv2(bx+BW+2, by+BH+2),
                    col32(0.95,0.75,0.20, pulse), 6*MDS, 15, 2)
            end

            imgui.SetNextWindowPos(iv2(bx, by), imgui.Cond.Always)
            imgui.SetNextWindowSize(iv2(BW, BH), imgui.Cond.Always)
            imgui.PushStyleColor(imgui.Col.WindowBg, iv4(0,0,0,0))
            imgui.PushStyleColor(imgui.Col.Border,   iv4(0,0,0,0))

            if imgui.Begin('##bm_'..btn.id, nil, noWinFlags) then
                imgui.SetCursorPos(iv2(0,0))
                imgui.InvisibleButton('##ib_'..btn.id, iv2(BW, BH))

                local isHov     = imgui.IsItemHovered()
                local isActive  = imgui.IsItemActive()
                local isClicked = imgui.IsItemClicked()

                if editMode and isClicked and dragTarget == nil then
                    dragTarget = btn.id
                end

                local c
                if isActive and not editMode then
                    c = btn.colA
                elseif isHov then
                    c = btn.colH
                else
                    c = btn.colN
                end

                dl:AddRectFilled(iv2(bx+2, by+3), iv2(bx+BW+2, by+BH+3),
                    col32(0,0,0,0.40), 5*MDS)
                dl:AddRectFilled(iv2(bx, by), iv2(bx+BW, by+BH),
                    col32(c[1],c[2],c[3],c[4]), 5*MDS)
                dl:AddRect(iv2(bx, by), iv2(bx+BW, by+BH),
                    col32(1,1,1,0.08), 5*MDS, 15, 1)

                if fMain then
                    local label = LABELS[btn.id] or ''
                    local ts    = imgui.CalcTextSize(label)
                    local tx    = bx + (BW - ts.x) * 0.5
                    local ty    = by + (BH - ts.y) * 0.5
                    dl:AddTextFontPtr(fMain, 14*MDS, iv2(tx, ty), col32(1,1,1,1), label)
                end

                if isClicked and not editMode then
                    local action = getAction(btn.id)
                    if action then action() end
                end
            end
            imgui.End()
            imgui.PopStyleColor(2)

            if editMode and dragTarget == btn.id and fMain then
                local hint = L.tapfix
                local ts   = imgui.CalcTextSize(hint)
                local hx   = btn.x + (BW - ts.x) * 0.5
                local hy   = btn.y + BH + 6*MDS
                dl:AddRectFilled(iv2(hx-5, hy-2), iv2(hx+ts.x+5, hy+ts.y+2),
                    col32(0,0,0,0.80), 3*MDS)
                dl:AddTextFontPtr(fMain, 14*MDS, iv2(hx, hy),
                    col32(0.95,0.75,0.20,1), hint)
            end
        end

        if editMode and fMain then
            local SW2  = 110 * MDS
            local SH2  = 34  * MDS
            local sx2  = sw / 2 - SW2 / 2
            local sy2  = 20 * MDS
            local mpos = imgui.GetIO().MousePos
            local inSave = mpos.x >= sx2 and mpos.x <= sx2+SW2
                        and mpos.y >= sy2 and mpos.y <= sy2+SH2

            dl:AddRectFilled(iv2(sx2+2, sy2+3), iv2(sx2+SW2+2, sy2+SH2+3),
                col32(0,0,0,0.45), 6*MDS)
            local bgA = inSave and 1.0 or 0.88
            dl:AddRectFilled(iv2(sx2, sy2), iv2(sx2+SW2, sy2+SH2),
                col32(0.72, 0.50, 0.05, bgA), 6*MDS)
            dl:AddRect(iv2(sx2, sy2), iv2(sx2+SW2, sy2+SH2),
                col32(1,1,1, 0.15), 6*MDS, 15, 1)

            local lbl = L.save
            local ts  = imgui.CalcTextSize(lbl)
            dl:AddTextFontPtr(fMain, 14*MDS,
                iv2(sx2 + (SW2-ts.x)*0.5, sy2 + (SH2-ts.y)*0.5),
                col32(0.05,0.04,0.02,1), lbl)

            local noWF2 = imgui.WindowFlags.NoTitleBar  + imgui.WindowFlags.NoResize  +
                          imgui.WindowFlags.NoMove       + imgui.WindowFlags.NoScrollbar +
                          imgui.WindowFlags.NoBackground + imgui.WindowFlags.NoNav      +
                          imgui.WindowFlags.NoSavedSettings
            imgui.SetNextWindowPos(iv2(sx2, sy2), imgui.Cond.Always)
            imgui.SetNextWindowSize(iv2(SW2, SH2), imgui.Cond.Always)
            imgui.PushStyleColor(imgui.Col.WindowBg, iv4(0,0,0,0))
            imgui.PushStyleColor(imgui.Col.Border,   iv4(0,0,0,0))
            if imgui.Begin('##bm_save', nil, noWF2) then
                imgui.SetCursorPos(iv2(0,0))
                imgui.InvisibleButton('##ib_save', iv2(SW2, SH2))
                if imgui.IsItemClicked() then
                    editMode   = false
                    dragTarget = nil
                end
            end
            imgui.End()
            imgui.PopStyleColor(2)
        end

        if fMain then imgui.PopFont() end
    end
)

imgui.OnFrame(
    function() return wMenu[0] end,
    function(self)
        self.HideCursor = false
        self.LockPlayer = false

        local MW    = 220*MDS
        local WF    = imgui.WindowFlags
        local flags = WF.NoTitleBar + WF.NoResize + WF.NoScrollbar +
                      WF.NoCollapse + WF.NoSavedSettings + WF.AlwaysAutoResize

        imgui.SetNextWindowPos(iv2(sw/2 - MW/2, sh/2 - 90*MDS), imgui.Cond.Always)
        imgui.SetNextWindowSize(iv2(MW, 0), imgui.Cond.Always)

        if imgui.Begin('##barmenu', wMenu, flags) then
            if fMain then imgui.PushFont(fMain) end

            local dl = imgui.GetWindowDrawList()
            local wp = imgui.GetWindowPos()
            local ws = imgui.GetWindowSize()

            dl:AddRectFilled(iv2(wp.x+1, wp.y+1), iv2(wp.x+ws.x-1, wp.y+24*MDS),
                col32(0.90,0.70,0.15,1), 5*MDS, 3)
            dl:AddRect(iv2(wp.x, wp.y), iv2(wp.x+ws.x, wp.y+ws.y),
                col32(0.90,0.70,0.15,0.5), 5*MDS, 15, 1)

            imgui.SetCursorPos(iv2(ws.x/2 - 32*MDS, 4*MDS))
            imgui.TextColored(iv4(0.05,0.04,0.03,1), L.settings)

            imgui.Dummy(iv2(0, 8*MDS))

            imgui.TextColored(iv4(0.60,0.60,0.65,1), L.idlabel)
            imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 4*MDS)
            imgui.SetNextItemWidth(MW - 16*MDS)
            if imgui.InputText('##pid', idBuf, 8, imgui.InputTextFlags.CharsDecimal) then
                local s = ffiStr(idBuf, 8)
                if s ~= '' then curID = s end
            end
            imgui.PopStyleVar()

            imgui.Spacing()

            imgui.TextColored(iv4(0.60,0.60,0.65,1), L.sumlabel)
            imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 4*MDS)
            imgui.SetNextItemWidth(MW - 16*MDS)
            if imgui.InputText('##psum', sumBuf, 10, imgui.InputTextFlags.CharsDecimal) then
                local s = ffiStr(sumBuf, 10)
                if s ~= '' then curSum = s end
            end
            imgui.PopStyleVar()

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            local HBW = (MW - 16*MDS - 4*MDS) / 2
            local HBH = 26*MDS

            if editMode then
                imgui.PushStyleColor(imgui.Col.Button,        iv4(0.55,0.36,0.06,1))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, iv4(0.68,0.46,0.10,1))
                imgui.PushStyleColor(imgui.Col.ButtonActive,  iv4(0.40,0.26,0.04,1))
                if imgui.Button(L.save..'##svp', iv2(HBW, HBH)) then
                    editMode   = false
                    dragTarget = nil
                end
                imgui.PopStyleColor(3)
            else
                imgui.PushStyleColor(imgui.Col.Button,        iv4(0.16,0.16,0.20,1))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, iv4(0.23,0.23,0.28,1))
                imgui.PushStyleColor(imgui.Col.ButtonActive,  iv4(0.10,0.10,0.14,1))
                if imgui.Button(L.editpos..'##edp', iv2(HBW, HBH)) then
                    editMode   = true
                    dragTarget = nil
                    wMenu[0]   = false
                end
                imgui.PopStyleColor(3)
            end

            imgui.SameLine(0, 4*MDS)

            imgui.PushStyleColor(imgui.Col.Button,        iv4(0.36,0.10,0.10,1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, iv4(0.48,0.14,0.14,1))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  iv4(0.26,0.07,0.07,1))
            if imgui.Button(L.close..'##cls', iv2(HBW, HBH)) then
                wMenu[0] = false
            end
            imgui.PopStyleColor(3)

            if fMain then imgui.PopFont() end
            imgui.End()
        end
    end
)

function main()
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand('barm', function()
        if editMode then
            editMode   = false
            dragTarget = nil
        else
            wMenu[0] = not wMenu[0]
        end
    end)

    wait(2000)
    sampAddChatMessage('[BarMenu] \xce\xf2\xea\xf0\xfb\xf2\xfc\x3a /barm', 0x00CCFF)

    while true do
        local s1 = ffiStr(idBuf, 8)
        local s2 = ffiStr(sumBuf, 10)
        if s1 ~= '' then curID  = s1 end
        if s2 ~= '' then curSum = s2 end
        wait(150)
    end
end
