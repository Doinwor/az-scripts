---@diagnostic disable: undefined-global, need-check-nil, lowercase-global, cast-local-type, unused-local
script_name("Button Creator")
script_description("Custom screen buttons for Arizona RP")
script_author("Shinik")
script_version("1.5")

require('lib.moonloader')
require('encoding').default = 'CP1251'
local _u8 = require('encoding').UTF8
local ffi = require('ffi')
local sampev = require('samp.events')

local u8 = setmetatable({}, {
    __call = function(_, s)
        if s == nil then return '' end
        if type(s) ~= 'string' then s = tostring(s) end
        local ok, result = pcall(_u8, s)
        return ok and result or s
    end,
    __index = _u8,
})
local function safe_u8(v) return u8(tostring(v or '')) end

-------------------------------------------- SETTINGS ---------------------------------------------
local settings = {}
local default_settings = {
    general = {
        version = '1.5',
        custom_dpi = 1.0,
        autofind_dpi = false,
    },
    interface = {
        accent_r = 0.2,
        accent_g = 0.55,
        accent_b = 1.0,
        window_alpha = 0.97,
        bg_brightness = 0.13,
    },
    alt = {
        show = true,
        lock = false,
        w = 80,
        h = 50,
        x = -1,
        y = -1,
        rnd = 8,
        alpha = 85,
        color_r = 0.12,
        color_g = 0.14,
        color_b = 0.25,
    },
    keybtns = {
        show_ctrl = false,
        show_2    = false,
        show_h    = false,
        show_n    = false,
        show_y    = false,
        show_spc  = false,
        lock = false,
        w = 80, h = 50, rnd = 8, alpha = 85,
        color_r = 0.20, color_g = 0.14, color_b = 0.25,
        ctrl_x = -1, ctrl_y = -1,
        key2_x = -1, key2_y = -1,
        keyh_x = -1, keyh_y = -1,
        keyn_x = -1, keyn_y = -1,
        keyy_x = -1, keyy_y = -1,
        spc_x  = -1, spc_y  = -1,
    },
    layout = {
        spacing = 10,
        align_y = 0,
    },
    buttons = {},
}

local configDirectory = getWorkingDirectory():gsub('\\\\','/') .. "/Button Creator"
local path = configDirectory .. "/Settings.json"

local function merge_defaults(tbl, defaults)
    for k, v in pairs(defaults) do
        if tbl[k] == nil then tbl[k] = v
        elseif type(v) == 'table' and type(tbl[k]) == 'table' and not v[1] then
            merge_defaults(tbl[k], v)
        end
    end
end

function load_settings()
    if not doesDirectoryExist(configDirectory) then createDirectory(configDirectory) end
    if not doesFileExist(path) then
        settings = default_settings
    else
        local file = io.open(path, 'r')
        if file then
            local contents = file:read('*a'); file:close()
            if #contents == 0 then settings = default_settings
            else
                local ok, loaded = pcall(decodeJson, contents)
                if ok and loaded then
                    settings = loaded
                    merge_defaults(settings, default_settings)
                    if settings.general.version ~= thisScript().version then
                        settings.general.version = thisScript().version
                        save_settings()
                    end
                else settings = default_settings end
            end
        else settings = default_settings end
    end
end

function save_settings()
    if not doesDirectoryExist(configDirectory) then createDirectory(configDirectory) end
    local file = io.open(path, 'w')
    if file then
        local ok, encoded = pcall(encodeJson, settings)
        file:write(ok and encoded or ""); file:close(); return ok
    end
    return false
end

load_settings()

------------------------------------------- MONET --------------------------------------------------
function isMonetLoader() return MONET_VERSION ~= nil end

if not settings.general.autofind_dpi then
    if isMonetLoader() then
        settings.general.custom_dpi = MONET_DPI_SCALE or 1.0
    else
        local bw, bh = 1366, 768; local cw, ch = getScreenResolution()
        settings.general.custom_dpi = ((cw / bw) + (ch / bh)) / 2
    end
    settings.general.autofind_dpi = true; save_settings()
end

---------------------------------------------- VARS -------------------------------------------------
local imgui = require('mimgui')
local sizeX, sizeY = getScreenResolution()

local MainWindow = imgui.new.bool()
local alt_trigger  = false

local new_btn_name = imgui.new.char[64]()
local new_btn_cmd = imgui.new.char[128]()

local edit_btn_name = imgui.new.char[64]()
local edit_btn_cmd = imgui.new.char[128]()
local editing_index = nil

local slider_window_alpha = imgui.new.float(settings.interface.window_alpha or 0.97)
local slider_bg_bright = imgui.new.float(settings.interface.bg_brightness or 0.13)
local accent_color = imgui.new.float[3](settings.interface.accent_r or 0.2, settings.interface.accent_g or 0.55, settings.interface.accent_b or 1.0)

local tmp_int = imgui.new.int(0)
local frame_count = 0
local _btn_press = {}
local force_reposition = {}
local confirm_delete_idx = -1
local reload_script = false

local message_color = 0x2090FF
local message_color_hex = '{2090FF}'

------------------------------------------------- UTILS --------------------------------------------------------
function change_dpi()
    if not isMonetLoader() then imgui.SetWindowFontScale(settings.general.custom_dpi) end
end

local function needForcePos() return frame_count <= 1 end
local function requestReposition(winId) force_reposition[winId] = true end
local function consumeReposition(winId)
    if force_reposition[winId] then force_reposition[winId] = nil; return true end
    return false
end

local function hasUnlocked()
    if settings.alt.show and not settings.alt.lock then return true end
    for _, b in ipairs(settings.buttons) do
        if b.visible and not b.locked then return true end
    end
    return false
end

local function ensureDefaults(b)
    if b.visible == nil then b.visible = true end
    if b.locked == nil then b.locked = false end
    if b.rnd == nil then b.rnd = 8 end
    if b.alpha == nil then b.alpha = 85 end
    if b.w == nil then b.w = 100 end
    if b.h == nil then b.h = 45 end
    if b.color_r == nil then b.color_r = settings.interface.accent_r end
    if b.color_g == nil then b.color_g = settings.interface.accent_g end
    if b.color_b == nil then b.color_b = settings.interface.accent_b end
end


-- Auto-snap: if button Y is within snap_range of another visible button, snap to its Y
local snap_range = 10
local function autoSnapY(btn_index)
    local b = settings.buttons[btn_index]
    if not b or not b.visible then return end
    for i, other in ipairs(settings.buttons) do
        if i ~= btn_index and other.visible and other.y then
            if math.abs((b.y or 0) - other.y) <= snap_range and math.abs((b.y or 0) - other.y) > 0 then
                b.y = other.y
                requestReposition('usrbtn' .. btn_index)
                return true
            end
        end
    end
    -- Also snap to ALT
    if settings.alt.show and settings.alt.y then
        if math.abs((b.y or 0) - settings.alt.y) <= snap_range and math.abs((b.y or 0) - settings.alt.y) > 0 then
            b.y = settings.alt.y
            requestReposition('usrbtn' .. btn_index)
            return true
        end
    end
    return false
end

local function autoSnapYAlt()
    local a = settings.alt
    if not a.show then return end
    for _, b in ipairs(settings.buttons) do
        if b.visible and b.y then
            if math.abs((a.y or 0) - b.y) <= snap_range and math.abs((a.y or 0) - b.y) > 0 then
                a.y = b.y
                requestReposition('altkey')
                return true
            end
        end
    end
    return false
end

local function touchSlider(val, step, mn, mx, id)
    local changed = false
    local totalW = imgui.GetWindowContentRegionWidth()
    local btnW = 36
    local gap = 4
    local sliderW = totalW - btnW * 2 - gap * 2
    if imgui.Button("-##m" .. id, imgui.ImVec2(btnW, 26)) then
        val = val - step; if val < mn then val = mn end; changed = true
    end
    imgui.SameLine(0, gap)
    tmp_int[0] = val
    imgui.PushItemWidth(sliderW)
    if imgui.SliderInt("##sl" .. id, tmp_int, mn, mx) then val = tmp_int[0]; changed = true end
    imgui.SameLine(0, gap)
    if imgui.Button("+##p" .. id, imgui.ImVec2(btnW, 26)) then
        val = val + step; if val > mx then val = mx end; changed = true
    end
    return val, changed
end

local function drawBtnVisual(dl, x, y, w, h, r, text, alpha, cr, cg, cb, hovered, active, locked)
    local a = (alpha or 85) / 100
    local col_bg, col_border
    if active then
        col_bg = imgui.ImVec4(cr * 1.5, cg * 1.5, cb * 1.5, a)
        col_border = imgui.ImVec4(cr * 2, cg * 2, cb * 2, a)
    elseif hovered then
        col_bg = imgui.ImVec4(cr * 1.2, cg * 1.2, cb * 1.2, a * 0.9)
        col_border = imgui.ImVec4(cr * 1.6, cg * 1.6, cb * 1.6, a * 0.85)
    else
        col_bg = imgui.ImVec4(cr, cg, cb, a)
        col_border = imgui.ImVec4(cr * 2.5, cg * 2.5, cb * 2.5, a * 0.6)
    end
    local p1 = imgui.ImVec2(x, y)
    local p2 = imgui.ImVec2(x + w, y + h)
    dl:AddRectFilled(p1, p2, imgui.ColorConvertFloat4ToU32(col_bg), r)
    dl:AddRect(p1, p2, imgui.ColorConvertFloat4ToU32(col_border), r, 15, 1.5)
    local ts = imgui.CalcTextSize(text)
    local white = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1, 1, 1, a))
    dl:AddText(imgui.ImVec2(x + (w - ts.x) * 0.5, y + (h - ts.y) * 0.5), white, text)
    -- Lock indicator dot (top-right corner)
    local dot_r = 4
    local dot_x = x + w - dot_r - 3
    local dot_y = y + dot_r + 3
    if locked then
        dl:AddCircleFilled(imgui.ImVec2(dot_x, dot_y), dot_r, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.9, 0.15, 0.15, a)), 12)
    else
        dl:AddCircleFilled(imgui.ImVec2(dot_x, dot_y), dot_r, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.15, 0.9, 0.15, a)), 12)
    end
end

local function drawScreenButton(winId, bx, by, bw, bh, r, text, alpha, cr, cg, cb, locked, onClick)
    local grab = 30
    local force = needForcePos() or consumeReposition(winId)
    local cond = force and imgui.Cond.Always or imgui.Cond.FirstUseEver
    imgui.SetNextWindowPos(imgui.ImVec2(bx, by), cond)
    imgui.SetNextWindowSize(imgui.ImVec2(bw + grab, bh + grab))
    local fl = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoBackground
    if locked then fl = fl + imgui.WindowFlags.NoMove end
    imgui.Begin("##" .. winId, nil, fl)
    local wp = imgui.GetWindowPos()
    local dl = imgui.GetWindowDrawList()
    local cx = wp.x + grab / 2
    local cy = wp.y + grab / 2
    local hovered = imgui.IsWindowHovered()
    local active = imgui.IsMouseDown(0) and hovered
    local released = imgui.IsMouseReleased(0) and hovered
    local mp = imgui.GetMousePos()
    if imgui.IsMouseClicked(0) and hovered then
        _btn_press[winId] = {x = mp.x, y = mp.y}
    end
    local _bp = _btn_press[winId]
    local dragged = _bp and (math.abs(mp.x - _bp.x) > 4 or math.abs(mp.y - _bp.y) > 4)
    local clicked = released and not dragged
    if released then _btn_press[winId] = nil end
    drawBtnVisual(dl, cx, cy, bw, bh, r, text, alpha, cr, cg, cb, hovered, active, locked)
    if clicked and onClick then onClick() end
    imgui.End()
    return wp.x, wp.y
end

------------------------------------------------- MAIN --------------------------------------------------------
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end
    while not sampIsLocalPlayerSpawned() do wait(0) end

    sampAddChatMessage('[Button Creator] {ffffff}v' .. settings.general.version .. ' | ' .. message_color_hex .. '/but', message_color)

    sampRegisterChatCommand("but", function()
        MainWindow[0] = not MainWindow[0]
    end)

    sampRegisterChatCommand("butlock", function()
        for _, b in ipairs(settings.buttons) do b.locked = true end
        settings.alt.lock = true; save_settings()
        sampAddChatMessage('[Button Creator] {ffffff}Все заблокировано!', message_color)
    end)

    sampRegisterChatCommand("butunlock", function()
        for _, b in ipairs(settings.buttons) do b.locked = false end
        settings.alt.lock = false; save_settings()
        sampAddChatMessage('[Button Creator] {ffffff}Все разблокировано!', message_color)
    end)

    sampRegisterChatCommand("buthide", function()
        for _, b in ipairs(settings.buttons) do b.visible = false end
        settings.alt.show = false; save_settings()
        sampAddChatMessage('[Button Creator] {ffffff}Все скрыто!', message_color)
    end)

    sampRegisterChatCommand("butshow", function()
        for _, b in ipairs(settings.buttons) do b.visible = true end
        settings.alt.show = true; save_settings()
        sampAddChatMessage('[Button Creator] {ffffff}Все показано!', message_color)
    end)

    while true do wait(0) end
end

function onScriptTerminate(s, q)
    if s == thisScript() and not reload_script then
        sampAddChatMessage('[Button Creator] {ffffff}Скрипт остановлен!', message_color)
    end
    if s == thisScript() then save_settings() end
end

function sampev.onSendPlayerSync(data)
    if alt_trigger then data.keys.unknown_walkSlow = 1; alt_trigger = false end
end

local function samp_create_sync_data(sync_type)
    local ffi2 = require('ffi')
    local sampfuncs2 = require('sampfuncs')
    local raknet2 = require('samp.raknet')
    require('samp.synchronization')
    local sync_traits = {
        player  = {'PlayerSyncData',  raknet2.PACKET.PLAYER_SYNC,  sampStorePlayerOnfootData},
        vehicle = {'VehicleSyncData', raknet2.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData},
    }
    local info = sync_traits[sync_type]
    local data = ffi2.new('struct ' .. info[1], {})
    local ptr  = tonumber(ffi2.cast('uintptr_t', ffi2.new('struct ' .. info[1] .. '*', data)))
    local _, pid = sampGetPlayerIdByCharHandle(PLAYER_PED)
    info[3](pid, ptr)
    local func_send = function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, info[2])
        raknetBitStreamWriteBuffer(bs, ptr, ffi2.sizeof(data))
        raknetSendBitStreamEx(bs, sampfuncs2.HIGH_PRIORITY, sampfuncs2.UNRELIABLE_SEQUENCED, 1)
        raknetDeleteBitStream(bs)
    end
    local mt = {
        __index    = function(t, k) return data[k] end,
        __newindex = function(t, k, v) data[k] = v end,
    }
    return setmetatable({send = func_send}, mt)
end

local function sendKey(foot_bit, veh_bit)
    if isCharInAnyCar(PLAYER_PED) then
        if veh_bit then
            local d = samp_create_sync_data('vehicle')
            d.keysData = d.keysData + veh_bit
            d.send()
        end
    else
        local d = samp_create_sync_data('player')
        d.keysData = d.keysData + foot_bit
        d.send()
    end
end

local function sendVehicleKey(bit)
    local d = samp_create_sync_data('vehicle')
    d.keysData = d.keysData + bit
    d.send()
end

local function sendKeyCoords(sync_type, bit, quat4)
    local d = samp_create_sync_data(sync_type)
    local x, y, z = getCharCoordinates(PLAYER_PED)
    d.position = {x, y, z}
    if bit then d.keysData = d.keysData + bit end
    if quat4 then d.quaternion[4] = quat4 end
    d.send()
end

----------------------------------------------- IMGUI ---------------------------------------------------------
imgui.OnInitialize(function() imgui.GetIO().IniFilename = nil; apply_theme() end)

imgui.OnFrame(function() return isSampAvailable() end, function()
    if frame_count <= 2 then frame_count = frame_count + 1 end
end)

-- ========== ALT BUTTON ==========
imgui.OnFrame(
    function() return settings.alt.show and isSampAvailable() and not isPauseMenuActive() end,
    function(self)
        self.HideCursor = not MainWindow[0] and not hasUnlocked()
        local a = settings.alt
        if a.x < 0 then a.x = sizeX / 2 - a.w / 2 end
        if a.y < 0 then a.y = sizeY / 2 - a.h / 2 end
        local nx, ny = drawScreenButton(
            "altkey", a.x, a.y, a.w, a.h, a.rnd, "ALT", a.alpha,
            a.color_r or 0.12, a.color_g or 0.14, a.color_b or 0.25,
            a.lock,
            function()
                if isCharOnFoot(PLAYER_PED) then
                    sendKeyCoords('player', 1024)
                else
                    sendKeyCoords('vehicle', 4)
                end
            end
        )
        if nx ~= a.x or ny ~= a.y then a.x = nx; a.y = ny; autoSnapYAlt(); save_settings() end
    end
)

-- ========== KEY BUTTONS ==========
local key_btn_defs = {
    { id = 'kb_ctrl', xk = 'ctrl_x', yk = 'ctrl_y', label = 'CTR', show = 'show_ctrl', trigger = function()
        if isCharOnFoot(PLAYER_PED) then sendKeyCoords('player', 8)
        else sendKeyCoords('vehicle', 1) end
    end },
    { id = 'kb_2',    xk = 'key2_x', yk = 'key2_y', label = '2',   show = 'show_2',    trigger = function()
        if isCharInAnyCar(PLAYER_PED) then sendKeyCoords('vehicle', 512) end
    end },
    { id = 'kb_h',    xk = 'keyh_x', yk = 'keyh_y', label = 'H',   show = 'show_h',    trigger = function()
        if isCharOnFoot(PLAYER_PED) then sendKeyCoords('player', nil, 1.7632555392181e-38)
        else sendKeyCoords('vehicle', 2) end
    end },
    { id = 'kb_n',    xk = 'keyn_x', yk = 'keyn_y', label = 'N',   show = 'show_n',    trigger = function()
        if isCharOnFoot(PLAYER_PED) then sendKeyCoords('player', nil, 1.1755083638069e-38)
        else sampSendChat('/engine') end
    end },
    { id = 'kb_y',    xk = 'keyy_x', yk = 'keyy_y', label = 'Y',   show = 'show_y',    trigger = function() sampSendChat('/invent') end },
    { id = 'kb_spc',  xk = 'spc_x',  yk = 'spc_y',  label = 'SPC', show = 'show_spc',  trigger = function()
        if isCharOnFoot(PLAYER_PED) then sendKeyCoords('player', 32)
        else sendKeyCoords('vehicle', 128) end
    end },
}

imgui.OnFrame(
    function()
        local kb = settings.keybtns
        if not kb then return false end
        local any = kb.show_ctrl or kb.show_2 or kb.show_h or kb.show_n or kb.show_y or kb.show_spc
        return any and isSampAvailable() and not isPauseMenuActive()
    end,
    function(self)
        self.HideCursor = not MainWindow[0] and not hasUnlocked()
        local kb = settings.keybtns
        for _, def in ipairs(key_btn_defs) do
            if kb[def.show] then
                if kb[def.xk] < 0 then kb[def.xk] = sizeX / 2 end
                if kb[def.yk] < 0 then kb[def.yk] = sizeY / 2 - kb.h / 2 end
                local nx, ny = drawScreenButton(
                    def.id, kb[def.xk], kb[def.yk], kb.w, kb.h, kb.rnd, def.label, kb.alpha,
                    kb.color_r, kb.color_g, kb.color_b,
                    kb.lock,
                    def.trigger
                )
                if nx ~= kb[def.xk] or ny ~= kb[def.yk] then
                    kb[def.xk] = nx; kb[def.yk] = ny
                    -- auto-snap Y to user buttons and ALT
                    local snapped = false
                    for _, ob in ipairs(settings.buttons) do
                        if ob.visible and ob.y and math.abs(kb[def.yk] - ob.y) <= snap_range and math.abs(kb[def.yk] - ob.y) > 0 then
                            kb[def.yk] = ob.y; requestReposition(def.id); snapped = true; break
                        end
                    end
                    if not snapped and settings.alt.show and settings.alt.y then
                        if math.abs(kb[def.yk] - settings.alt.y) <= snap_range and math.abs(kb[def.yk] - settings.alt.y) > 0 then
                            kb[def.yk] = settings.alt.y; requestReposition(def.id)
                        end
                    end
                    save_settings()
                end
            end
        end
    end
)

-- ========== USER BUTTONS ==========
imgui.OnFrame(
    function() return #settings.buttons > 0 and isSampAvailable() and not isPauseMenuActive() end,
    function(self)
        self.HideCursor = not MainWindow[0] and not hasUnlocked()
        for i, b in ipairs(settings.buttons) do
            ensureDefaults(b)
            if b.visible then
                local bx = b.x or (sizeX / 2 + (i - 1) * 120)
                local by = b.y or (sizeY - 120)
                local nx, ny = drawScreenButton(
                    "usrbtn" .. i, bx, by, b.w, b.h, b.rnd,
                    safe_u8(b.name or "btn"), b.alpha,
                    b.color_r, b.color_g, b.color_b,
                    b.locked,
                    function()
                        if b.cmd and #b.cmd > 0 then
                            if b.cmd:sub(1,1) == '/' then
                                sampProcessChatInput(b.cmd)
                            else
                                sampSendChat(b.cmd)
                            end
                        end
                    end
                )
                if nx ~= b.x or ny ~= b.y then
                    b.x = nx; b.y = ny
                    if autoSnapY(i) then save_settings()
                    else save_settings() end
                end
            end
        end
    end
)

-- ========== MAIN MENU ==========
imgui.OnFrame(function() return MainWindow[0] and not isPauseMenuActive() end, function(self)
    self.HideCursor = false
    local d = settings.general.custom_dpi
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(420*d, 500*d), imgui.Cond.FirstUseEver)
    imgui.Begin(u8(' Button Creator v' .. settings.general.version), MainWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
    change_dpi()

    if imgui.BeginTabBar('MT') then

        -- ===== КНОПКИ =====
        if imgui.BeginTabItem(u8' Кнопки') then
            if imgui.BeginChild('##btnlist', imgui.ImVec2(-1, 280*d), true) then
                local delete_idx = nil
                for i, b in ipairs(settings.buttons) do
                    ensureDefaults(b)
                    imgui.PushStyleColor(imgui.Col.Header, imgui.ImVec4(b.color_r*0.3, b.color_g*0.3, b.color_b*0.3, 1))
                    imgui.PushStyleColor(imgui.Col.HeaderHovered, imgui.ImVec4(b.color_r*0.5, b.color_g*0.5, b.color_b*0.5, 1))
                    imgui.PushStyleColor(imgui.Col.HeaderActive, imgui.ImVec4(b.color_r*0.7, b.color_g*0.7, b.color_b*0.7, 1))
                    local status = ''
                    if not b.visible then status = status .. ' [H]' end
                    if b.locked then status = status .. ' [L]' end
                    local is_open = imgui.CollapsingHeader(safe_u8(i .. '. ' .. (b.name or '?') .. status .. '##bh' .. i))
                    imgui.PopStyleColor(3)

                    if is_open then
                        if editing_index ~= i then
                            editing_index = i
                            ffi.fill(edit_btn_name, ffi.sizeof(edit_btn_name), 0)
                            ffi.fill(edit_btn_cmd, ffi.sizeof(edit_btn_cmd), 0)
                            ffi.copy(edit_btn_name, b.name or "")
                            ffi.copy(edit_btn_cmd, b.cmd or "")
                        end

                        imgui.Text(u8'Имя:'); imgui.PushItemWidth(-1)
                        imgui.InputText('##en' .. i, edit_btn_name, ffi.sizeof(edit_btn_name))
                        imgui.Text(u8'Команда:'); imgui.PushItemWidth(-1)
                        imgui.InputText('##ec' .. i, edit_btn_cmd, ffi.sizeof(edit_btn_cmd))

                        imgui.Spacing()
                        local v, c
                        imgui.Text(u8'Ширина:')
                        v, c = touchSlider(b.w, 10, 30, 300, 'bw' .. i)
                        if c then b.w = v; save_settings() end
                        imgui.Text(u8'Высота:')
                        v, c = touchSlider(b.h, 5, 20, 200, 'bh' .. i)
                        if c then b.h = v; save_settings() end
                        imgui.Text(u8'Скругление:')
                        v, c = touchSlider(b.rnd, 1, 0, 25, 'br' .. i)
                        if c then b.rnd = v; save_settings() end
                        imgui.Text(u8'Прозрачность:')
                        v, c = touchSlider(b.alpha, 5, 10, 100, 'ba' .. i)
                        if c then b.alpha = v; save_settings() end

                        imgui.Spacing()
                        imgui.Text(u8'Цвет:')
                        local bc = imgui.new.float[3](b.color_r, b.color_g, b.color_b)
                        if imgui.ColorEdit3('##bc' .. i, bc) then
                            b.color_r = bc[0]; b.color_g = bc[1]; b.color_b = bc[2]; save_settings()
                        end

                        imgui.Spacing()
                        if imgui.Button(u8'Применить##ap' .. i, imgui.ImVec2(-1, 28*d)) then
                            b.name = u8:decode(ffi.string(edit_btn_name))
                            b.cmd = u8:decode(ffi.string(edit_btn_cmd))
                            save_settings()
                        end

                        local hw = (imgui.GetWindowContentRegionWidth() - 8) / 2
                        if imgui.Button(b.visible and u8'Скрыть##vs' .. i or u8'Показать##vs' .. i, imgui.ImVec2(hw, 28*d)) then
                            b.visible = not b.visible; save_settings()
                        end
                        imgui.SameLine()
                        if imgui.Button(b.locked and u8'Разблок.##lk' .. i or u8'Заблок.##lk' .. i, imgui.ImVec2(hw, 28*d)) then
                            b.locked = not b.locked; save_settings()
                        end

                        -- Точная подстройка позиции (±1 пиксель)
                        imgui.Text(u8'Позиция:')
                        local pw = (imgui.GetWindowContentRegionWidth() - 16) / 4
                        if imgui.Button(u8'X-1##xl' .. i, imgui.ImVec2(pw, 26*d)) then
                            b.x = (b.x or 0) - 1; requestReposition('usrbtn' .. i); save_settings()
                        end
                        imgui.SameLine()
                        if imgui.Button(u8'X+1##xr' .. i, imgui.ImVec2(pw, 26*d)) then
                            b.x = (b.x or 0) + 1; requestReposition('usrbtn' .. i); save_settings()
                        end
                        imgui.SameLine()
                        if imgui.Button(u8'Y-1##yu' .. i, imgui.ImVec2(pw, 26*d)) then
                            b.y = (b.y or 0) - 1; requestReposition('usrbtn' .. i); save_settings()
                        end
                        imgui.SameLine()
                        if imgui.Button(u8'Y+1##yd' .. i, imgui.ImVec2(pw, 26*d)) then
                            b.y = (b.y or 0) + 1; requestReposition('usrbtn' .. i); save_settings()
                        end
                        imgui.Text(safe_u8('  X: ' .. math.floor(b.x or 0) .. '  Y: ' .. math.floor(b.y or 0)))

                        imgui.Spacing()
                        if imgui.Button(u8'Копия##cp' .. i, imgui.ImVec2(hw, 28*d)) then
                            local nb = {}
                            for k, vv in pairs(b) do nb[k] = vv end
                            nb.name = (b.name or 'btn') .. ' (2)'
                            nb.x = (b.x or sizeX/2) + 30
                            nb.y = (b.y or sizeY/2) + 30
                            nb.locked = false
                            table.insert(settings.buttons, i + 1, nb)
                            save_settings()
                        end
                        imgui.SameLine()
                        if imgui.Button(u8'Сброс поз.##rp' .. i, imgui.ImVec2(hw, 28*d)) then
                            b.x = sizeX / 2; b.y = sizeY / 2
                            requestReposition('usrbtn' .. i); save_settings()
                        end

                        if i > 1 and imgui.Button(u8'Вверх##mu' .. i, imgui.ImVec2(hw, 28*d)) then
                            settings.buttons[i], settings.buttons[i-1] = settings.buttons[i-1], settings.buttons[i]; save_settings()
                        end
                        if i > 1 and i < #settings.buttons then imgui.SameLine() end
                        if i < #settings.buttons and imgui.Button(u8'Вниз##md' .. i, imgui.ImVec2(hw, 28*d)) then
                            settings.buttons[i], settings.buttons[i+1] = settings.buttons[i+1], settings.buttons[i]; save_settings()
                        end

                        imgui.Spacing()
                        if confirm_delete_idx == i then
                            if imgui.Button(u8'ДА, УДАЛИТЬ##yd' .. i, imgui.ImVec2(hw, 28*d)) then
                                delete_idx = i; confirm_delete_idx = -1
                            end
                            imgui.SameLine()
                            if imgui.Button(u8'Отмена##cn' .. i, imgui.ImVec2(hw, 28*d)) then confirm_delete_idx = -1 end
                        else
                            if imgui.Button(u8'Удалить##dl' .. i, imgui.ImVec2(-1, 28*d)) then confirm_delete_idx = i end
                        end
                        imgui.Separator()
                    end
                end
                if delete_idx then table.remove(settings.buttons, delete_idx); save_settings() end
                imgui.EndChild()
            end

            imgui.Separator()
            imgui.Text(u8'Добавить кнопку:')
            local aw = imgui.GetWindowContentRegionWidth()
            imgui.PushItemWidth(aw * 0.48)
            imgui.InputText(u8'##nn', new_btn_name, ffi.sizeof(new_btn_name))
            imgui.SameLine()
            imgui.PushItemWidth(-1)
            imgui.InputText(u8'##nc', new_btn_cmd, ffi.sizeof(new_btn_cmd))
            if imgui.Button(u8' + Добавить', imgui.ImVec2(-1, 30*d)) then
                local nm = u8:decode(ffi.string(new_btn_name))
                local cm = u8:decode(ffi.string(new_btn_cmd))
                if #nm > 0 then
                    table.insert(settings.buttons, {
                        name = nm, cmd = cm, w = 100, h = 45, rnd = 8, alpha = 85,
                        color_r = settings.interface.accent_r, color_g = settings.interface.accent_g, color_b = settings.interface.accent_b,
                        x = sizeX / 2, y = sizeY / 2, visible = true, locked = false,
                    })
                    save_settings()
                    ffi.fill(new_btn_name, ffi.sizeof(new_btn_name), 0)
                    ffi.fill(new_btn_cmd, ffi.sizeof(new_btn_cmd), 0)
                end
            end
            imgui.EndTabItem()
        end

        -- ===== КноПки (ALT + клавишные) =====
        if imgui.BeginTabItem(u8' Клавиши') then
            if imgui.BeginChild('##kbtabscroll', imgui.ImVec2(-1, -1), false) then

            imgui.Text(u8'--- ALT ---')
            local a = settings.alt
            local show_alt = imgui.new.bool(a.show)
            if imgui.Checkbox(u8'\xcf\xee\xea\xe0\xe7\xfb\xe2\xe0\xf2\xfc ALT', show_alt) then a.show = show_alt[0]; save_settings() end
            local lock_alt = imgui.new.bool(a.lock)
            if imgui.Checkbox(u8'\xc7\xe0\xe1\xeb\xee\xea\xe8\xf0\xee\xe2\xe0\xf2\xfc ALT', lock_alt) then a.lock = lock_alt[0]; save_settings() end
            imgui.Separator()
            local v, c
            imgui.Text(u8'\xd8\xe8\xf0\xe8\xed\xe0:')
            v, c = touchSlider(a.w, 5, 30, 200, 'aw')
            if c then a.w = v; save_settings() end
            imgui.Text(u8'\xc2\xfb\xf1\xee\xf2\xe0:')
            v, c = touchSlider(a.h, 5, 30, 200, 'ah')
            if c then a.h = v; save_settings() end
            imgui.Text(u8'\xd1\xea\xf0\xf3\xe3\xeb\xe5\xed\xe8\xe5:')
            v, c = touchSlider(a.rnd, 1, 0, 25, 'ar')
            if c then a.rnd = v; save_settings() end
            imgui.Text(u8'\xcf\xf0\xee\xe7\xf0\xe0\xf7\xed\xee\xf1\xf2\xfc:')
            v, c = touchSlider(a.alpha, 5, 10, 100, 'aa')
            if c then a.alpha = v; save_settings() end
            imgui.Spacing()
            imgui.Text(u8'\xd6\xe2\xe5\xf2:')
            local ac = imgui.new.float[3](a.color_r or 0.12, a.color_g or 0.14, a.color_b or 0.25)
            if imgui.ColorEdit3('##altc', ac) then
                a.color_r = ac[0]; a.color_g = ac[1]; a.color_b = ac[2]; save_settings()
            end
            imgui.Spacing()
            if imgui.Button(u8'\xd1\xe1\xf0\xee\xf1 \xef\xee\xe7. ALT##altrp', imgui.ImVec2(-1, 28*d)) then
                a.x = sizeX / 2 - a.w / 2; a.y = sizeY / 2 - a.h / 2
                requestReposition("altkey"); save_settings()
            end

            imgui.Spacing(); imgui.Separator(); imgui.Spacing()

            imgui.Text(u8'--- CTR / 2 / H / N / Y / SPC ---')
            imgui.Spacing()
            local kb = settings.keybtns
            local kb_labels2 = {
                { show = 'show_ctrl', name = 'CTR', xk = 'ctrl_x', yk = 'ctrl_y' },
                { show = 'show_2',    name = '2',   xk = 'key2_x', yk = 'key2_y' },
                { show = 'show_h',    name = 'H',   xk = 'keyh_x', yk = 'keyh_y' },
                { show = 'show_n',    name = 'N',   xk = 'keyn_x', yk = 'keyn_y' },
                { show = 'show_y',    name = 'Y',   xk = 'keyy_x', yk = 'keyy_y' },
                { show = 'show_spc',  name = 'SPC', xk = 'spc_x',  yk = 'spc_y'  },
            }
            for _, kd in ipairs(kb_labels2) do
                local cb = imgui.new.bool(kb[kd.show])
                if imgui.Checkbox(u8'\xcf\xee\xea\xe0\xe7\xfb\xe2\xe0\xf2\xfc ' .. kd.name .. '##chk' .. kd.show, cb) then
                    kb[kd.show] = cb[0]; save_settings()
                end
            end

            imgui.Separator(); imgui.Spacing()
            local lock_kb = imgui.new.bool(kb.lock)
            if imgui.Checkbox(u8'\xc7\xe0\xe1\xeb\xee\xea\xe8\xf0\xee\xe2\xe0\xf2\xfc \xea\xeb\xe0\xe2\xe8\xf8\xed\xfb\xe5##kblock', lock_kb) then
                kb.lock = lock_kb[0]; save_settings()
            end

            imgui.Separator(); imgui.Spacing()
            imgui.Text(u8'\xd0\xe0\xe7\xec\xe5\xf0 \xea\xeb\xe0\xe2\xe8\xf8\xed\xfb\xf5 \xea\xed\xee\xcf\xee\xea:')
            local kv, kc
            imgui.Text(u8'\xd8\xe8\xf0\xe8\xed\xe0:')
            kv, kc = touchSlider(kb.w, 5, 30, 200, 'kbw')
            if kc then kb.w = kv; save_settings() end
            imgui.Text(u8'\xc2\xfb\xf1\xee\xf2\xe0:')
            kv, kc = touchSlider(kb.h, 5, 20, 200, 'kbh')
            if kc then kb.h = kv; save_settings() end
            imgui.Text(u8'\xd1\xea\xf0\xf3\xe3\xeb\xe5\xed\xe8\xe5:')
            kv, kc = touchSlider(kb.rnd, 1, 0, 25, 'kbr')
            if kc then kb.rnd = kv; save_settings() end
            imgui.Text(u8'\xcf\xf0\xee\xe7\xf0\xe0\xf7\xed\xee\xf1\xf2\xfc:')
            kv, kc = touchSlider(kb.alpha, 5, 10, 100, 'kba')
            if kc then kb.alpha = kv; save_settings() end
            imgui.Spacing()
            imgui.Text(u8'\xd6\xe2\xe5\xf2:')
            local kbc = imgui.new.float[3](kb.color_r or 0.20, kb.color_g or 0.14, kb.color_b or 0.25)
            if imgui.ColorEdit3('##kbcol', kbc) then
                kb.color_r = kbc[0]; kb.color_g = kbc[1]; kb.color_b = kbc[2]; save_settings()
            end
            imgui.Spacing()
            if imgui.Button(u8'\xd1\xe1\xf0\xee\xf1 \xef\xee\xe7. \xea\xeb\xe0\xe2\xe8\xf8\xed\xfb\xf5##kbrp', imgui.ImVec2(-1, 28*d)) then
                for _, kd in ipairs(kb_labels2) do kb[kd.xk] = -1; kb[kd.yk] = -1 end
                save_settings()
            end

            imgui.EndChild()
            end
            imgui.EndTabItem()
        end

        -- ===== РАСКЛАДКА =====
        if imgui.BeginTabItem(u8' Раскладка') then
            if imgui.BeginChild('##layoutscroll', imgui.ImVec2(-1, -1), false) then
            imgui.Text(u8'--- Точная подстройка (по 1 пикселю) ---')
            imgui.Separator(); imgui.Spacing()

            imgui.Text(u8'Сдвинуть ВСЕ видимые по Y:')
            local hw = (imgui.GetWindowContentRegionWidth() - 8) / 2
            if imgui.Button(u8'Y - 1##yup', imgui.ImVec2(hw, 30*d)) then
                for i, b in ipairs(settings.buttons) do
                    if b.visible then b.y = (b.y or 0) - 1; requestReposition('usrbtn' .. i) end
                end
                save_settings()
            end
            imgui.SameLine()
            if imgui.Button(u8'Y + 1##ydn', imgui.ImVec2(hw, 30*d)) then
                for i, b in ipairs(settings.buttons) do
                    if b.visible then b.y = (b.y or 0) + 1; requestReposition('usrbtn' .. i) end
                end
                save_settings()
            end

            imgui.Text(u8'Сдвинуть ВСЕ видимые по X:')
            if imgui.Button(u8'X - 1##xlf', imgui.ImVec2(hw, 30*d)) then
                for i, b in ipairs(settings.buttons) do
                    if b.visible then b.x = (b.x or 0) - 1; requestReposition('usrbtn' .. i) end
                end
                save_settings()
            end
            imgui.SameLine()
            if imgui.Button(u8'X + 1##xrt', imgui.ImVec2(hw, 30*d)) then
                for i, b in ipairs(settings.buttons) do
                    if b.visible then b.x = (b.x or 0) + 1; requestReposition('usrbtn' .. i) end
                end
                save_settings()
            end

            imgui.Spacing()
            imgui.Text(u8'Выровнять Y всех по первой кнопке:')
            if imgui.Button(u8'Один горизонт##alignfirst', imgui.ImVec2(-1, 34*d)) then
                local first_y = nil
                for i, b in ipairs(settings.buttons) do
                    ensureDefaults(b)
                    if b.visible then
                        if not first_y then first_y = b.y or 0 end
                        b.y = first_y
                        requestReposition('usrbtn' .. i)
                    end
                end
                if first_y then save_settings() end
            end

            imgui.Spacing(); imgui.Separator(); imgui.Spacing()
            imgui.Text(u8'--- Авто-раскладка ---')
            imgui.Spacing()

            imgui.Text(u8'Отступ между кнопками:')
            local sv, sc = touchSlider(settings.layout.spacing, 5, 0, 100, 'ls')
            if sc then settings.layout.spacing = sv; save_settings() end

            imgui.Text(u8'Позиция Y (от верха):')
            local yv, yc = touchSlider(settings.layout.align_y, 10, 0, sizeY - 60, 'ly')
            if yc then settings.layout.align_y = yv; save_settings() end

            imgui.Spacing()

            if imgui.Button(u8' В ряд (горизонтально)', imgui.ImVec2(-1, 34*d)) then
                local visible = {}
                for i, b in ipairs(settings.buttons) do
                    ensureDefaults(b)
                    if b.visible then table.insert(visible, {idx = i, btn = b}) end
                end
                if #visible > 0 then
                    local totalW = 0
                    for _, vv in ipairs(visible) do totalW = totalW + vv.btn.w end
                    totalW = totalW + settings.layout.spacing * (#visible - 1)
                    local startX = (sizeX - totalW) / 2
                    local ay = settings.layout.align_y
                    if ay <= 0 then ay = sizeY - 120 end
                    local cx = startX
                    for _, vv in ipairs(visible) do
                        vv.btn.x = cx; vv.btn.y = ay
                        requestReposition('usrbtn' .. vv.idx)
                        cx = cx + vv.btn.w + settings.layout.spacing
                    end
                    save_settings()
                end
            end

            if imgui.Button(u8' В столбец (вертикально)', imgui.ImVec2(-1, 34*d)) then
                local visible = {}
                for i, b in ipairs(settings.buttons) do
                    ensureDefaults(b)
                    if b.visible then table.insert(visible, {idx = i, btn = b}) end
                end
                if #visible > 0 then
                    local totalH = 0
                    for _, vv in ipairs(visible) do totalH = totalH + vv.btn.h end
                    totalH = totalH + settings.layout.spacing * (#visible - 1)
                    local startY = (sizeY - totalH) / 2
                    local cy = startY
                    for _, vv in ipairs(visible) do
                        vv.btn.x = sizeX - 120; vv.btn.y = cy
                        requestReposition('usrbtn' .. vv.idx)
                        cy = cy + vv.btn.h + settings.layout.spacing
                    end
                    save_settings()
                end
            end

            if imgui.Button(u8' В два ряда (сетка)', imgui.ImVec2(-1, 34*d)) then
                local visible = {}
                for i, b in ipairs(settings.buttons) do
                    ensureDefaults(b)
                    if b.visible then table.insert(visible, {idx = i, btn = b}) end
                end
                if #visible > 0 then
                    local cols = math.ceil(#visible / 2)
                    local ay = settings.layout.align_y
                    if ay <= 0 then ay = sizeY - 180 end
                    local maxW = 0
                    for _, vv in ipairs(visible) do if vv.btn.w > maxW then maxW = vv.btn.w end end
                    local totalW = maxW * cols + settings.layout.spacing * (cols - 1)
                    local startX = (sizeX - totalW) / 2
                    for idx, vv in ipairs(visible) do
                        local col = (idx - 1) % cols
                        local row = math.floor((idx - 1) / cols)
                        vv.btn.x = startX + col * (maxW + settings.layout.spacing)
                        vv.btn.y = ay + row * (vv.btn.h + settings.layout.spacing)
                        requestReposition('usrbtn' .. vv.idx)
                    end
                    save_settings()
                end
            end

            imgui.Spacing(); imgui.Separator(); imgui.Spacing()
            imgui.Text(u8'--- Управление ---')

            if imgui.Button(u8'Заблок. все', imgui.ImVec2(hw, 30*d)) then
                for _, b in ipairs(settings.buttons) do b.locked = true end
                settings.alt.lock = true; settings.keybtns.lock = true; save_settings()
            end
            imgui.SameLine()
            if imgui.Button(u8'Разблок. все', imgui.ImVec2(hw, 30*d)) then
                for _, b in ipairs(settings.buttons) do b.locked = false end
                settings.alt.lock = false; settings.keybtns.lock = false; save_settings()
            end
            if imgui.Button(u8'Показать все', imgui.ImVec2(hw, 30*d)) then
                for _, b in ipairs(settings.buttons) do b.visible = true end
                settings.alt.show = true
                for _, kd in ipairs({{'show_ctrl'},{'show_2'},{'show_h'},{'show_n'},{'show_y'},{'show_spc'}}) do settings.keybtns[kd[1]] = true end
                save_settings()
            end
            imgui.SameLine()
            if imgui.Button(u8'Скрыть все', imgui.ImVec2(hw, 30*d)) then
                for _, b in ipairs(settings.buttons) do b.visible = false end
                settings.alt.show = false
                for _, kd in ipairs({{'show_ctrl'},{'show_2'},{'show_h'},{'show_n'},{'show_y'},{'show_spc'}}) do settings.keybtns[kd[1]] = false end
                save_settings()
            end

            imgui.Spacing(); imgui.Separator(); imgui.Spacing()
            imgui.Text(u8'--- Общие настройки для всех ---')
            imgui.Spacing()
            imgui.Text(u8'Скругление:')
            local gr, gc = touchSlider(8, 1, 0, 25, 'grd')
            if gc then
                for _, b in ipairs(settings.buttons) do b.rnd = gr end
                settings.alt.rnd = gr; settings.keybtns.rnd = gr; save_settings()
            end
            imgui.Text(u8'Прозрачность:')
            local ga, gac = touchSlider(85, 5, 10, 100, 'gal')
            if gac then
                for _, b in ipairs(settings.buttons) do b.alpha = ga end
                settings.alt.alpha = ga; settings.keybtns.alpha = ga; save_settings()
            end
            imgui.Text(u8'Ширина:')
            local gw, gwc = touchSlider(100, 5, 30, 300, 'gwi')
            if gwc then
                for _, b in ipairs(settings.buttons) do b.w = gw end
                settings.alt.w = gw; settings.keybtns.w = gw; save_settings()
            end
            imgui.Text(u8'Высота:')
            local gh, ghc = touchSlider(45, 5, 20, 200, 'ghe')
            if ghc then
                for _, b in ipairs(settings.buttons) do b.h = gh end
                settings.alt.h = gh; settings.keybtns.h = gh; save_settings()
            end
            imgui.Spacing()
            imgui.Text(u8'Цвет для всех кнопок (+ALT):')
            local gc_col = imgui.new.float[3](settings.interface.accent_r, settings.interface.accent_g, settings.interface.accent_b)
            if imgui.ColorEdit3('##gcol', gc_col) then
                for _, b in ipairs(settings.buttons) do
                    b.color_r = gc_col[0]; b.color_g = gc_col[1]; b.color_b = gc_col[2]
                end
                settings.alt.color_r = gc_col[0]; settings.alt.color_g = gc_col[1]; settings.alt.color_b = gc_col[2]
                settings.keybtns.color_r = gc_col[0]; settings.keybtns.color_g = gc_col[1]; settings.keybtns.color_b = gc_col[2]
                save_settings()
            end

            imgui.EndChild()
            end
            imgui.EndTabItem()
        end

        -- ===== СТИЛЬ =====
        if imgui.BeginTabItem(u8' Стиль') then
            imgui.Text(u8'Акцентный цвет меню:')
            if imgui.ColorEdit3('##macc', accent_color) then
                settings.interface.accent_r = accent_color[0]; settings.interface.accent_g = accent_color[1]
                settings.interface.accent_b = accent_color[2]; save_settings(); apply_theme()
            end
            imgui.Spacing()
            imgui.Text(u8'Пресеты:')
            local presets = {
                {u8'Синий', .2, .55, 1}, {u8'Оранж', 1, .65, 0}, {u8'Зелён', .2, .8, .3},
                {u8'Красн', .9, .2, .2}, {u8'Фиол', .6, .3, .9}, {u8'Белый', .85, .85, .85}
            }
            for pi, pr in ipairs(presets) do
                if pi > 1 then imgui.SameLine() end
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(pr[2]*.4, pr[3]*.4, pr[4]*.4, 1))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(pr[2]*.6, pr[3]*.6, pr[4]*.6, 1))
                if imgui.Button(pr[1] .. '##pr' .. pi, imgui.ImVec2(60*d, 22*d)) then
                    settings.interface.accent_r = pr[2]; settings.interface.accent_g = pr[3]; settings.interface.accent_b = pr[4]
                    accent_color[0] = pr[2]; accent_color[1] = pr[3]; accent_color[2] = pr[4]
                    save_settings(); apply_theme()
                end
                imgui.PopStyleColor(2)
            end
            imgui.Separator()
            imgui.Text(u8'Яркость фона:'); imgui.PushItemWidth(-1)
            if imgui.SliderFloat('##bgb', slider_bg_bright, 0.05, 0.30) then
                settings.interface.bg_brightness = slider_bg_bright[0]; save_settings(); apply_theme()
            end
            imgui.Text(u8'Прозрачность окна:'); imgui.PushItemWidth(-1)
            if imgui.SliderFloat('##wa', slider_window_alpha, 0.5, 1.0) then
                settings.interface.window_alpha = slider_window_alpha[0]; save_settings(); apply_theme()
            end
            imgui.EndTabItem()
        end

        -- ===== ИНФО =====
        if imgui.BeginTabItem(u8' Инфо') then
            if imgui.BeginChild('##info', imgui.ImVec2(-1, -40*d), true) then
                imgui.Text(u8'=== Button Creator v1.5 ===')
                imgui.Spacing()
                imgui.Text(u8'Команды:')
                imgui.Text(u8'  /but - открыть/закрыть меню')
                imgui.Text(u8'  /butlock - заблокировать все')
                imgui.Text(u8'  /butunlock - разблокировать все')
                imgui.Text(u8'  /butshow - показать все')
                imgui.Text(u8'  /buthide - скрыть все')
                imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                imgui.Text(u8'Как пользоваться:')
                imgui.Spacing()
                imgui.Text(u8'1. "Кнопки" - создавайте кнопки')
                imgui.Text(u8'   введя имя и команду.')
                imgui.Text(u8'   Команда - что отправится в чат')
                imgui.Text(u8'   при нажатии (/cmd или текст).')
                imgui.Spacing()
                imgui.Text(u8'2. Перетаскивайте кнопки по экрану')
                imgui.Text(u8'   когда они разблокированы.')
                imgui.Text(u8'   Заблокируйте после настройки!')
                imgui.Spacing()
                imgui.Text(u8'3. "Раскладка" - точная подстройка')
                imgui.Text(u8'   по 1 пикселю (Y+1, Y-1, X+1, X-1)')
                imgui.Text(u8'   для идеального горизонта.')
                imgui.Text(u8'   "Один горизонт" - все кнопки на')
                imgui.Text(u8'   один Y как у первой видимой.')
                imgui.Spacing()
                imgui.Text(u8'4. ALT - эмулирует медленную ходьбу')
                imgui.Text(u8'   через onSendPlayerSync.')
                imgui.Spacing()
                imgui.Text(u8'5. Индикатор на кнопках:')
                imgui.Text(u8'   Зелёная точка = разблокирована')
                imgui.Text(u8'   Красная точка = заблокирована')
                imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                imgui.Text(u8'Советы:')
                imgui.Text(u8'- Сначала грубо расставьте пальцем')
                imgui.Text(u8'- Авто-снап: кнопка сама прилипнет')
                imgui.Text(u8'  к горизонту другой (в пределах 5px)')
                imgui.Text(u8'- Точная подстройка: +1/-1 пиксель')
                imgui.Text(u8'- "Один горизонт" выровняет Y')
                imgui.Text(u8'- Общие настройки включают ALT')
                imgui.Text(u8'- Заблокируйте когда готово')
                imgui.Text(u8'- Настройки сохраняются авто')
                imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                imgui.Text(u8'Автор: Shinik')
                imgui.EndChild()
            end
            if imgui.Button(u8'Перезагрузка', imgui.ImVec2(-1, 30*d)) then
                reload_script = true; thisScript():reload()
            end
            imgui.EndTabItem()
        end

        imgui.EndTabBar()
    end
    imgui.End()
end)

----------------------------------------------- THEME ---------------------------------------------------
function apply_theme()
    imgui.SwitchContext()
    local s = imgui.GetStyle(); local d = settings.general.custom_dpi
    local bg = settings.interface.bg_brightness or 0.13
    local wa = settings.interface.window_alpha or 0.97
    local ar = settings.interface.accent_r or .2; local ag = settings.interface.accent_g or .55; local ab = settings.interface.accent_b or 1
    s.WindowPadding = imgui.ImVec2(5*d,5*d); s.FramePadding = imgui.ImVec2(5*d,5*d)
    s.ItemSpacing = imgui.ImVec2(5*d,5*d); s.ItemInnerSpacing = imgui.ImVec2(2*d,2*d)
    s.ScrollbarSize = 10*d; s.GrabMinSize = 10*d
    s.WindowBorderSize = 1*d; s.ChildBorderSize = 1*d; s.PopupBorderSize = 1*d; s.FrameBorderSize = 1*d; s.TabBorderSize = 1*d
    s.WindowRounding = 8*d; s.ChildRounding = 8*d; s.FrameRounding = 8*d; s.PopupRounding = 8*d
    s.ScrollbarRounding = 8*d; s.GrabRounding = 8*d; s.TabRounding = 8*d
    s.WindowTitleAlign = imgui.ImVec2(.5,.5); s.ButtonTextAlign = imgui.ImVec2(.5,.5); s.SelectableTextAlign = imgui.ImVec2(.5,.5)
    s.Colors[imgui.Col.Text] = imgui.ImVec4(.92,.92,.92,1)
    s.Colors[imgui.Col.TextDisabled] = imgui.ImVec4(.55,.55,.55,1)
    s.Colors[imgui.Col.WindowBg] = imgui.ImVec4(bg,bg,bg+.01,wa)
    s.Colors[imgui.Col.ChildBg] = imgui.ImVec4(bg+.02,bg+.02,bg+.03,wa)
    s.Colors[imgui.Col.PopupBg] = imgui.ImVec4(bg+.01,bg+.01,bg+.02,wa)
    s.Colors[imgui.Col.Border] = imgui.ImVec4(bg+.17,bg+.17,bg+.19,.65)
    s.Colors[imgui.Col.BorderShadow] = imgui.ImVec4(0,0,0,0)
    s.Colors[imgui.Col.FrameBg] = imgui.ImVec4(bg+.05,bg+.05,bg+.07,1)
    s.Colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(bg+.13,bg+.13,bg+.15,1)
    s.Colors[imgui.Col.FrameBgActive] = imgui.ImVec4(bg+.17,bg+.17,bg+.20,1)
    s.Colors[imgui.Col.TitleBg] = imgui.ImVec4(bg-.01,bg-.01,bg,1)
    s.Colors[imgui.Col.TitleBgActive] = imgui.ImVec4(ar*.25,ag*.25,ab*.25,1)
    s.Colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(bg-.01,bg-.01,bg,1)
    s.Colors[imgui.Col.MenuBarBg] = imgui.ImVec4(bg+.03,bg+.03,bg+.05,1)
    s.Colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(bg+.01,bg+.01,bg+.02,1)
    s.Colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(bg+.15,bg+.15,bg+.17,1)
    s.Colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(bg+.25,bg+.25,bg+.27,1)
    s.Colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(bg+.35,bg+.35,bg+.37,1)
    s.Colors[imgui.Col.CheckMark] = imgui.ImVec4(ar,ag,ab,1)
    s.Colors[imgui.Col.SliderGrab] = imgui.ImVec4(ar*.5,ag*.5,ab*.5,1)
    s.Colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(ar*.7,ag*.7,ab*.7,1)
    s.Colors[imgui.Col.Button] = imgui.ImVec4(bg+.07,bg+.07,bg+.09,1)
    s.Colors[imgui.Col.ButtonHovered] = imgui.ImVec4(ar*.35,ag*.35,ab*.35,1)
    s.Colors[imgui.Col.ButtonActive] = imgui.ImVec4(ar*.5,ag*.5,ab*.5,1)
    s.Colors[imgui.Col.Header] = imgui.ImVec4(ar*.2,ag*.2,ab*.2,1)
    s.Colors[imgui.Col.HeaderHovered] = imgui.ImVec4(ar*.35,ag*.35,ab*.35,1)
    s.Colors[imgui.Col.HeaderActive] = imgui.ImVec4(ar*.5,ag*.5,ab*.5,1)
    s.Colors[imgui.Col.Separator] = imgui.ImVec4(bg+.12,bg+.12,bg+.14,1)
    s.Colors[imgui.Col.Tab] = imgui.ImVec4(bg+.03,bg+.03,bg+.05,1)
    s.Colors[imgui.Col.TabHovered] = imgui.ImVec4(ar*.4,ag*.4,ab*.4,1)
    s.Colors[imgui.Col.TabActive] = imgui.ImVec4(ar*.3,ag*.3,ab*.3,1)
    s.Colors[imgui.Col.ModalWindowDimBg] = imgui.ImVec4(.1,.1,.1,.85)
end
