script_name('RenderObjects')
script_author('Victor Strand')
script_version('2.2-monet')
script_version_number(2)

local imgui  = require('mimgui')
local enc    = require('encoding')
local inicfg = require('inicfg')
local ffi    = require('ffi')

enc.default = 'CP1251'
local u8  = enc.UTF8
local MDS = MONET_DPI_SCALE
local new = imgui.new
local sw, sh = getScreenResolution()

local function bufToStr(buf, maxlen)
    local t = {}
    for i = 0, maxlen - 1 do
        local b = buf[i]
        if not b or b == 0 then break end
        t[#t + 1] = string.char(b)
    end
    return table.concat(t)
end

local function strToBuf(s, buf, maxlen)
    local n = math.min(#s, maxlen - 1)
    for i = 0, n - 1 do buf[i] = s:byte(i + 1) end
    buf[n] = 0
end

local function abgr(r, g, b, a)
    a = a or 1.0
    local function c(x) return math.min(255, math.max(0, math.floor(x*255+0.5))) end
    return bit.bor(bit.lshift(c(a),24), bit.lshift(c(b),16), bit.lshift(c(g),8), c(r))
end

local function vec4abgr(v)
    return abgr(v.x, v.y, v.z, v.w)
end

local function openLink(url)
    pcall(function()
        local gta = ffi.load('GTASA')
        pcall(ffi.cdef, [[ void _Z12AND_OpenLinkPKc(const char* link); ]])
        gta._Z12AND_OpenLinkPKc(url)
    end)
end

local entries  = {}
local winOpen  = new.bool(false)
local scanMode = false
local cfg      = nil

local colLine      = new.float[4](0.85, 0.10, 0.10, 0.90)
local colText      = new.float[4](0.20, 1.00, 0.35, 1.00)
local colInfo      = new.float[4](1.00, 0.85, 0.20, 1.00)
local renderRadius = new.int(50)
local chatAlert    = new.bool(false)

local alertShown = {}
local objCache   = {}
local fMain

local function saveCfg()
    if not cfg then return end
    cfg[1] = cfg[1] or {}
    cfg[1].colLine_r = colLine[0]; cfg[1].colLine_g = colLine[1]
    cfg[1].colLine_b = colLine[2]; cfg[1].colLine_a = colLine[3]
    cfg[1].colText_r = colText[0]; cfg[1].colText_g = colText[1]
    cfg[1].colText_b = colText[2]; cfg[1].colText_a = colText[3]
    cfg[1].colInfo_r = colInfo[0]; cfg[1].colInfo_g = colInfo[1]
    cfg[1].colInfo_b = colInfo[2]; cfg[1].colInfo_a = colInfo[3]
    cfg[1].radius    = renderRadius[0]
    cfg[1].chatAlert = tostring(chatAlert[0])

    while #cfg > #entries + 1 do table.remove(cfg) end
    for i, e in ipairs(entries) do
        local idx = i + 1
        cfg[idx] = cfg[idx] or {}
        cfg[idx].model   = e.model[0]
        cfg[idx].name    = bufToStr(e.name, 64)
        cfg[idx].line    = tostring(e.line[0])
        cfg[idx].enabled = tostring(e.enabled[0])
    end
    inicfg.save(cfg, 'renderobjects')
end

local function addEntry(modelVal, nameUtf8, lineVal, enabledVal)
    local buf = new.char[64]('')
    if nameUtf8 and nameUtf8 ~= '' then
        strToBuf(nameUtf8, buf, 64)
    end
    table.insert(entries, {
        model   = new.int(modelVal or 0),
        name    = buf,
        line    = new.bool(lineVal    or false),
        enabled = new.bool(enabledVal ~= false),
    })
end

local function loadCfg()
    cfg = inicfg.load(nil, 'renderobjects')
    if not cfg then
        cfg = { { marker = 'v2' } }
        inicfg.save(cfg, 'renderobjects')
    end

    local h = cfg[1] or {}
    local function fc(v, def) return tonumber(v) or def end
    colLine[0]=fc(h.colLine_r,0.85); colLine[1]=fc(h.colLine_g,0.10)
    colLine[2]=fc(h.colLine_b,0.10); colLine[3]=fc(h.colLine_a,0.90)
    colText[0]=fc(h.colText_r,0.20); colText[1]=fc(h.colText_g,1.00)
    colText[2]=fc(h.colText_b,0.35); colText[3]=fc(h.colText_a,1.00)
    colInfo[0]=fc(h.colInfo_r,1.00); colInfo[1]=fc(h.colInfo_g,0.85)
    colInfo[2]=fc(h.colInfo_b,0.20); colInfo[3]=fc(h.colInfo_a,1.00)
    renderRadius[0] = fc(h.radius, 50)
    chatAlert[0]    = h.chatAlert == true or h.chatAlert == 'true'

    entries = {}
    for i = 2, #cfg do
        local s = cfg[i]
        if s and s.model ~= nil then
            addEntry(
                tonumber(s.model) or 0,
                tostring(s.name or ''),
                s.line    == true or s.line    == 'true',
                s.enabled == true or s.enabled == 'true'
            )
        end
    end
    if #entries == 0 then
        addEntry(228,  u8('\xca\xe0\xec\xe5\xed\xfc'), false, false)
        addEntry(1337, u8('\xcc\xe5\xf2\xe0\xeb\xeb'), false, false)
        saveCfg()
    end
end

lua_thread.create(function()
    while not isSampAvailable()          do wait(1000) end
    while not sampIsLocalPlayerSpawned() do wait(500)  end
    while true do
        local okP, px, py, pz = pcall(getCharCoordinates, PLAYER_PED)
        if okP and px then
            local radius = renderRadius[0]
            local okO, objs = pcall(getAllObjects)
            local tmp = {}
            if okO and objs then
                for _, handle in ipairs(objs) do
                    local okC, _, ox, oy, oz = pcall(getObjectCoordinates, handle)
                    if okC and ox then
                        local dist = getDistanceBetweenCoords3d(px,py,pz, ox,oy,oz)
                        if dist <= radius then
                            local okM, model = pcall(getObjectModel, handle)
                            if okM and model then
                                local sampId = -1
                                local okS, sid = pcall(sampGetObjectSampIdByHandle, handle)
                                if okS and type(sid)=='number' and sid~=-1 then sampId=sid end
                                tmp[#tmp+1] = {
                                    handle=handle, ox=ox, oy=oy, oz=oz,
                                    model=model, sampId=sampId, dist=dist,
                                }
                            end
                        end
                    end
                end
            end
            local inRange = {}
            for _, o in ipairs(tmp) do inRange[o.handle] = true end
            for h in pairs(alertShown) do
                if not inRange[h] then alertShown[h] = nil end
            end
            objCache = tmp
        end
        wait(500)
    end
end)

imgui.OnFrame(
    function() return isSampAvailable() end,
    function(self)
        self.HideCursor = true

        local okP, px, py, pz = pcall(getCharCoordinates, PLAYER_PED)
        if not okP or not px then return end

        local psx, psy = convert3DCoordsToScreen(px, py, pz)
        local dl = imgui.GetForegroundDrawList()

        local COL_LINE   = vec4abgr(imgui.ImVec4(colLine[0],colLine[1],colLine[2],colLine[3]))
        local COL_TEXT   = vec4abgr(imgui.ImVec4(colText[0],colText[1],colText[2],colText[3]))
        local COL_INFO   = vec4abgr(imgui.ImVec4(colInfo[0],colInfo[1],colInfo[2],colInfo[3]))
        local COL_SHADOW = abgr(0,0,0,0.65)
        local COL_DOT_P  = abgr(1,1,1,0.90)
        local COL_DOT_O  = abgr(colLine[0],colLine[1],colLine[2],1.0)
        local COL_SCAN   = abgr(1,1,1,1)
        local fsz = 13 * MDS

        for _, obj in ipairs(objCache) do
            local okOnScr, onScr = pcall(isObjectOnScreen, obj.handle)
            if not okOnScr or not onScr then goto skipObj end

            local sx, sy = convert3DCoordsToScreen(obj.ox, obj.oy, obj.oz)

            if scanMode then
                local txt = obj.sampId ~= -1
                    and string.format('id:%d model:%d %.1fm', obj.sampId, obj.model, obj.dist)
                    or  string.format('id:- model:%d %.1fm',             obj.model, obj.dist)
                dl:AddText(imgui.ImVec2(sx+4*MDS, sy), COL_SCAN, txt)
                goto skipObj
            end

            for _, e in ipairs(entries) do
                if e.enabled[0] and e.model[0] == obj.model then
                    local nameUtf8 = bufToStr(e.name, 64)
                    local dispName = (nameUtf8 ~= '') and nameUtf8 or ('model:'..obj.model)
                    local idPart   = obj.sampId ~= -1 and ('  id:'..obj.sampId) or ''
                    local infoStr  = string.format('%.1fm', obj.dist)..idPart
                    local nameY    = sy - fsz - 4*MDS

                    if fMain then
                        dl:AddTextFontPtr(fMain, fsz, imgui.ImVec2(sx+6*MDS, nameY+1), COL_SHADOW, dispName)
                        dl:AddTextFontPtr(fMain, fsz, imgui.ImVec2(sx+5*MDS, nameY),   COL_TEXT,   dispName)
                        dl:AddTextFontPtr(fMain, fsz, imgui.ImVec2(sx+6*MDS, sy+1),    COL_SHADOW, infoStr)
                        dl:AddTextFontPtr(fMain, fsz, imgui.ImVec2(sx+5*MDS, sy),      COL_INFO,   infoStr)
                    else
                        dl:AddText(imgui.ImVec2(sx+5*MDS, nameY), COL_TEXT, dispName)
                        dl:AddText(imgui.ImVec2(sx+5*MDS, sy),    COL_INFO, infoStr)
                    end

                    if e.line[0] then
                        dl:AddLine(imgui.ImVec2(psx,psy), imgui.ImVec2(sx,sy), COL_SHADOW, 3.0)
                        dl:AddLine(imgui.ImVec2(psx,psy), imgui.ImVec2(sx,sy), COL_LINE,   1.5)
                        dl:AddCircleFilled(imgui.ImVec2(psx,psy), 4*MDS, COL_DOT_P, 8)
                        dl:AddCircleFilled(imgui.ImVec2(sx, sy),  5*MDS, COL_DOT_O, 8)
                    end

                    if chatAlert[0] and not alertShown[obj.handle] then
                        alertShown[obj.handle] = true
                        local cp1251Name = (nameUtf8 ~= '') and u8:decode(nameUtf8) or ('model:'..obj.model)
                        local idStr = obj.sampId ~= -1 and (' id:'..obj.sampId) or ''
                        sampAddChatMessage(
                            '{FF4444}[RenderObjects]{FFFFFF} '..cp1251Name
                            ..'{AAAAAA} model:'..obj.model..idStr
                            ..' {FFDD44}'..string.format('%.1fm', obj.dist),
                            -1)
                    end

                    break
                end
            end

            ::skipObj::
        end
    end
)

imgui.OnInitialize(function()
    imgui.SwitchContext()
    local io = imgui.GetIO()
    io.IniFilename = nil
    imgui.GetStyle():ScaleAllSizes(MDS)

    local ttf = getWorkingDirectory()..'/lib/mimgui/trebucbd.ttf'
    if not doesFileExist(ttf) then
        ttf = getWorkingDirectory()..'/../trebucbd.ttf'
    end

    if doesFileExist(ttf) then
        local ranges = io.Fonts:GetGlyphRangesCyrillic()
        io.Fonts:AddFontFromFileTTF(ttf, 14*MDS, nil, ranges)
        fMain = io.Fonts:AddFontFromFileTTF(ttf, 13*MDS, nil, ranges)
    end

    local s = imgui.GetStyle()
    local c = s.Colors
    local C = imgui.Col

    s.WindowRounding     = 8*MDS
    s.FrameRounding      = 5*MDS
    s.ChildRounding      = 5*MDS
    s.GrabRounding       = 5*MDS
    s.TabRounding        = 5*MDS
    s.WindowBorderSize   = 1
    s.FrameBorderSize    = 0
    s.ItemSpacing        = imgui.ImVec2(8*MDS, 6*MDS)
    s.WindowPadding      = imgui.ImVec2(12*MDS, 12*MDS)
    s.FramePadding       = imgui.ImVec2(8*MDS, 4*MDS)

    c[C.WindowBg]             = imgui.ImVec4(0.06,0.07,0.10,0.97)
    c[C.TitleBg]              = imgui.ImVec4(0.08,0.08,0.12,1)
    c[C.TitleBgActive]        = imgui.ImVec4(0.10,0.10,0.15,1)
    c[C.FrameBg]              = imgui.ImVec4(0.12,0.13,0.17,1)
    c[C.FrameBgHovered]       = imgui.ImVec4(0.18,0.20,0.26,1)
    c[C.FrameBgActive]        = imgui.ImVec4(0.14,0.16,0.21,1)
    c[C.Button]               = imgui.ImVec4(0.55,0.08,0.08,1)
    c[C.ButtonHovered]        = imgui.ImVec4(0.72,0.12,0.12,1)
    c[C.ButtonActive]         = imgui.ImVec4(0.40,0.05,0.05,1)
    c[C.CheckMark]            = imgui.ImVec4(0.20,0.90,0.45,1)
    c[C.ChildBg]              = imgui.ImVec4(0.08,0.09,0.12,1)
    c[C.ScrollbarBg]          = imgui.ImVec4(0.06,0.07,0.10,1)
    c[C.ScrollbarGrab]        = imgui.ImVec4(0.45,0.07,0.07,1)
    c[C.ScrollbarGrabHovered] = imgui.ImVec4(0.60,0.10,0.10,1)
    c[C.Text]                 = imgui.ImVec4(0.92,0.92,0.93,1)
    c[C.TextDisabled]         = imgui.ImVec4(0.45,0.47,0.52,1)
    c[C.Separator]            = imgui.ImVec4(0.20,0.22,0.28,1)
    c[C.Tab]                  = imgui.ImVec4(0.10,0.10,0.15,1)
    c[C.TabHovered]           = imgui.ImVec4(0.65,0.10,0.10,1)
    c[C.TabActive]            = imgui.ImVec4(0.55,0.08,0.08,1)
    c[C.Header]               = imgui.ImVec4(0.45,0.07,0.07,0.7)
    c[C.HeaderHovered]        = imgui.ImVec4(0.60,0.10,0.10,0.8)
    c[C.SliderGrab]           = imgui.ImVec4(0.55,0.08,0.08,1)
    c[C.SliderGrabActive]     = imgui.ImVec4(0.72,0.12,0.12,1)
    c[C.PopupBg]              = imgui.ImVec4(0.08,0.09,0.12,0.98)
end)

imgui.OnFrame(
    function() return winOpen[0] end,
    function(self)
        self.HideCursor = false

        local winW = 480 * MDS
        imgui.SetNextWindowSize(imgui.ImVec2(winW, 0), imgui.Cond.Always)
        imgui.SetNextWindowPos(
            imgui.ImVec2(sw/2, sh/2),
            imgui.Cond.FirstUseEver,
            imgui.ImVec2(0.5, 0.5))

        if fMain then imgui.PushFont(fMain) end

        local flags = imgui.WindowFlags.NoResize +
                      imgui.WindowFlags.NoCollapse +
                      imgui.WindowFlags.AlwaysAutoResize
        imgui.Begin(u8('\xd0\xe5\xed\xe4\xe5\xf0 \xee\xe1\xfa\xe5\xea\xf2\xee\xe2  v2.2'), winOpen, flags)

        local dl   = imgui.GetWindowDrawList()
        local wpos = imgui.GetWindowPos()
        local ww   = imgui.GetWindowWidth()
        dl:AddRectFilled(
            imgui.ImVec2(wpos.x,    wpos.y+32*MDS),
            imgui.ImVec2(wpos.x+ww, wpos.y+34*MDS),
            abgr(0.80,0.10,0.10,1.0))

        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.10,0.11,0.15,1))
        imgui.BeginChild('##author', imgui.ImVec2(winW-24*MDS, 54*MDS), false)

        imgui.TextDisabled(u8('\xc0\xe2\xf2\xee\xf0:'))
        imgui.SameLine()
        imgui.TextColored(imgui.ImVec4(0.95,0.30,0.30,1), 'Victor Strand')

        local tgBtnW = (winW - 24*MDS - 8*MDS) / 2

        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.10,0.38,0.65,1))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.15,0.52,0.85,1))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.07,0.28,0.50,1))
        if imgui.Button('Telegram: @victor_st0', imgui.ImVec2(tgBtnW, 22*MDS)) then
            openLink('https://t.me/victor_st0')
        end
        imgui.SameLine(0, 8*MDS)
        if imgui.Button('Telegram: @strand_scripts', imgui.ImVec2(tgBtnW, 22*MDS)) then
            openLink('https://t.me/strand_scripts')
        end
        imgui.PopStyleColor(3)

        imgui.EndChild()
        imgui.PopStyleColor()

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        local btnW = winW - 24*MDS
        if scanMode then
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.05,0.60,0.20,1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.08,0.75,0.27,1))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.03,0.45,0.15,1))
            if imgui.Button(
                u8('[  \xd1\xea\xe0\xed\xe5\xf0 \xc2\xcb\xca\xde\xd7\xc5\xcd  |  ')
                ..tostring(renderRadius[0])..
                u8('\xec  |  \xed\xe0\xe6\xec\xe8 \xf7\xf2\xee\xe1\xfb \xe2\xfb\xea\xeb  ]'),
                imgui.ImVec2(btnW, 28*MDS)) then
                scanMode = false
            end
        else
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.15,0.17,0.22,1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.22,0.25,0.32,1))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.10,0.12,0.16,1))
            if imgui.Button(
                u8('[  \xd1\xea\xe0\xed\xe5\xf0 ID (')
                ..tostring(renderRadius[0])..
                u8('\xec)  |  \xed\xe0\xe6\xec\xe8 \xe4\xeb\xff \xe2\xea\xeb  ]'),
                imgui.ImVec2(btnW, 28*MDS)) then
                scanMode = true
            end
        end
        imgui.PopStyleColor(3)

        imgui.Spacing()

        imgui.PushStyleVarFloat(imgui.StyleVar.TabRounding, 4*MDS)
        if imgui.BeginTabBar('##tabs') then

            if imgui.BeginTabItem(u8('  \xd1\xef\xe8\xf1\xee\xea  ')) then
                imgui.Spacing()

                imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.70,0.72,0.80,1))
                imgui.Text(u8('\xc4\xe0\xeb\xfc\xed\xee\xf1\xf2\xfc \xf0\xe5\xed\xe4\xe5\xf0\xe0:'))
                imgui.PopStyleColor()
                imgui.SameLine()
                imgui.PushItemWidth(btnW - 145*MDS)
                if imgui.SliderInt('##radius', renderRadius, 1, 200,
                        tostring(renderRadius[0])..u8(' \xec')) then
                    saveCfg()
                end
                imgui.PopItemWidth()

                if imgui.Checkbox(
                    u8('\xd3\xe2\xe5\xe4\xee\xec\xeb\xe5\xed\xe8\xe5 \xe2 \xf7\xe0\xf2 \xef\xf0\xe8 \xee\xe1\xed\xe0\xf0\xf3\xe6\xe5\xed\xe8\xe8'),
                    chatAlert) then
                    alertShown = {}
                    saveCfg()
                end

                imgui.Spacing()

                imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.55)
                imgui.Text(u8('\xcc\xee\xe4\xe5\xeb\xfc'))
                imgui.SameLine(98*MDS)
                imgui.Text(u8('\xcd\xe0\xe7\xe2\xe0\xed\xe8\xe5'))
                imgui.SameLine(300*MDS)
                imgui.Text(u8('\xcb\xe8\xed'))
                imgui.SameLine(336*MDS)
                imgui.Text(u8('\xc2\xea\xeb'))
                imgui.PopStyleVar()

                imgui.Separator()

                local listH = math.max(math.min(#entries,6)*(24*MDS)+8*MDS, 36*MDS)
                imgui.BeginChild('##elist', imgui.ImVec2(winW-26*MDS, listH), false)
                for i, e in ipairs(entries) do
                    imgui.PushItemWidth(88*MDS)
                    if imgui.InputInt('##m'..i, e.model, 0) then saveCfg() end
                    imgui.PopItemWidth()
                    imgui.SameLine(0,4*MDS)
                    imgui.PushItemWidth(194*MDS)
                    if imgui.InputText('##n'..i, e.name, 64) then saveCfg() end
                    imgui.PopItemWidth()
                    imgui.SameLine(0,8*MDS)
                    if imgui.Checkbox('##l'..i, e.line)    then saveCfg() end
                    imgui.SameLine(0,8*MDS)
                    if imgui.Checkbox('##e'..i, e.enabled) then saveCfg() end
                end
                imgui.EndChild()

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                if imgui.Button(u8('+ \xc4\xee\xe1\xe0\xe2\xe8\xf2\xfc'), imgui.ImVec2(140*MDS,0)) then
                    addEntry(0,'',false,true)
                    table.insert(cfg,{model=0,name='',line='false',enabled='true'})
                    saveCfg()
                end
                if #entries > 0 then
                    imgui.SameLine(0,8*MDS)
                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.28,0.05,0.05,1))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.45,0.08,0.08,1))
                    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.20,0.03,0.03,1))
                    if imgui.Button(u8('- \xd3\xe1\xf0\xe0\xf2\xfc \xef\xee\xf1\xeb\xe5\xe4\xed\xe8\xe9'), imgui.ImVec2(200*MDS,0)) then
                        table.remove(entries)
                        if #cfg > 1 then table.remove(cfg) end
                        saveCfg()
                    end
                    imgui.PopStyleColor(3)
                end
                imgui.Spacing()
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem(u8('  \xd6\xe2\xe5\xf2\xe0  ')) then
                imgui.Spacing()
                local cflags = imgui.ColorEditFlags.AlphaBar +
                               imgui.ColorEditFlags.AlphaPreview +
                               imgui.ColorEditFlags.NoInputs +
                               imgui.ColorEditFlags.PickerHueBar

                imgui.TextColored(imgui.ImVec4(0.6,0.6,0.7,1),
                    u8('\xd6\xe2\xe5\xf2 \xeb\xe8\xed\xe8\xe8 / \xf2\xee\xf7\xe5\xea:'))
                if imgui.ColorEdit4('##cline', colLine, cflags) then saveCfg() end
                imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(0.6,0.6,0.7,1),
                    u8('\xd6\xe2\xe5\xf2 \xed\xe0\xe7\xe2\xe0\xed\xe8\xff:'))
                if imgui.ColorEdit4('##ctext', colText, cflags) then saveCfg() end
                imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(0.6,0.6,0.7,1),
                    u8('\xd6\xe2\xe5\xf2 \xe4\xe8\xf1\xf2\xe0\xed\xf6\xe8\xe8 / ID:'))
                if imgui.ColorEdit4('##cinfo', colInfo, cflags) then saveCfg() end

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                imgui.TextDisabled(u8('\xcf\xf0\xe5\xe2\xfc\xfe:'))
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(colText[0],colText[1],colText[2],colText[3]),
                    u8('\xca\xe0\xec\xe5\xed\xfc'))
                imgui.SameLine(0,16*MDS)
                imgui.TextColored(imgui.ImVec4(colInfo[0],colInfo[1],colInfo[2],colInfo[3]),
                    '3.5m  id:42')
                imgui.Spacing()
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem(u8('  Info  ')) then
                imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(0.80,0.82,0.88,1), u8('\xce \xf1\xea\xf0\xe8\xef\xf2\xe5'))
                imgui.Separator()
                imgui.Spacing()
                local function row(lbl, val, col)
                    imgui.TextDisabled(lbl)
                    imgui.SameLine(110*MDS)
                    imgui.TextColored(col or imgui.ImVec4(0.9,0.9,0.9,1), val)
                end
                row(u8('\xd1\xea\xf0\xe8\xef\xf2:'),             'RenderObjects v2.2')
                row(u8('\xc0\xe2\xf2\xee\xf0:'),                 'Victor Strand',    imgui.ImVec4(0.95,0.30,0.30,1))
                row('Telegram:',                                  '@victor_st0',      imgui.ImVec4(0.30,0.70,1.00,1))
                row(u8('\xca\xe0\xf2\xe0\xeb\xee\xe3:'),         '@strand_scripts',  imgui.ImVec4(0.30,0.70,1.00,1))
                row(u8('\xd0\xe0\xe4\xe8\xf3\xf1:'),
                    tostring(renderRadius[0])..u8(' \xec (1\xe2\xe2\xe5\xe4\xe8 \xe4\xee 200)'))
                row(u8('\xd7\xe0\xf2-\xf3\xe2\xe5\xe4\xee\xec\xeb\xe5\xed\xe8\xff:'),
                    chatAlert[0] and u8('\xc2\xcb\xca') or u8('\xc2\xdb\xca'),
                    chatAlert[0] and imgui.ImVec4(0.20,0.90,0.45,1) or imgui.ImVec4(0.55,0.55,0.60,1))
                row(u8('\xcf\xeb\xe0\xf2\xf4\xee\xf0\xec\xe0:'), 'MonetLoader 3.8.0+')
                row(u8('\xd1\xe5\xf0\xe2\xe5\xf0:'),             'Arizona RP (SA-MP)')
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()
                imgui.BulletText(u8('\xd1\xea\xe0\xed\xe5\xf0: id+model \xe2\xf1\xe5\xf5 \xee\xe1\xfa\xe5\xea\xf2\xee\xe2 \xe2 \xe7\xe0\xe4\xe0\xed\xed\xee\xec \xf0\xe0\xe4\xe8\xf3\xf1\xe5'))
                imgui.BulletText(u8('\xd1\xef\xe8\xf1\xee\xea: ESP \xef\xee model ID'))
                imgui.BulletText(u8('\xcb\xe8\xed\xe8\xff: \xf1\xf2\xf0\xe5\xeb\xea\xe0 \xee\xf2 \xe8\xe3\xf0\xee\xea\xe0 \xea \xee\xe1\xfa\xe5\xea\xf2\xf3'))
                imgui.BulletText(u8('\xca\xe5\xf8 \xee\xe1\xfa\xe5\xea\xf2\xee\xe2: 500\xec\xf1, \xef\xee\xe7\xe8\xf6\xe8\xff \xe8\xe3\xf0\xee\xea\xe0 \xe6\xe8\xe2\xe0\xff'))
                imgui.Spacing()
                imgui.EndTabItem()
            end

            imgui.EndTabBar()
        end
        imgui.PopStyleVar()

        imgui.End()
        if fMain then imgui.PopFont() end
    end
)

function main()
    while not isSampAvailable()          do wait(100) end
    while not sampIsLocalPlayerSpawned() do wait(200) end

    local cfgDir = getWorkingDirectory()..'/config'
    if not doesDirectoryExist(cfgDir) then createDirectory(cfgDir) end

    loadCfg()

    sampRegisterChatCommand('renderob', function()
        winOpen[0] = not winOpen[0]
    end)

    sampRegisterChatCommand('robjscan', function()
        scanMode = not scanMode
        sampAddChatMessage('[RenderObjects] scan: '..(scanMode and '{00FF00}ON' or '{FF4444}OFF'), -1)
    end)

    sampAddChatMessage('{FF4444}[RenderObjects v2.2]{FFFFFF} /renderob', -1)

    while true do wait(0) end
end
