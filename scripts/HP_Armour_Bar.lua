script_author('pinokio')

local imgui  = require('mimgui')
local encoding = require('encoding')

encoding.default = 'CP1251'
local u8 = encoding.UTF8

local defaults = {
    enabled = true,
    hp_enabled = true,
    arm_enabled = true,
    show_shadow = false,
    animate = true,
    anim_speed = 0.08,

    hp_color_r = 0.35, hp_color_g = 1.00, hp_color_b = 0.15,
    hp_bg_r = 0.10, hp_bg_g = 0.10, hp_bg_b = 0.10,
    hp_border_r = 0.00, hp_border_g = 0.00, hp_border_b = 0.00,
    hp_text_r = 1.00, hp_text_g = 1.00, hp_text_b = 1.00,
    hp_border_thick = 1,
    hp_width = 100,
    hp_height = 12,
    hp_font_size = 8,
    hp_show_text = true,
    hp_text_format = 0,

    arm_color_r = 0.20, arm_color_g = 0.55, arm_color_b = 1.00,
    arm_bg_r = 0.10, arm_bg_g = 0.10, arm_bg_b = 0.10,
    arm_border_r = 0.00, arm_border_g = 0.00, arm_border_b = 0.00,
    arm_text_r = 1.00, arm_text_g = 1.00, arm_text_b = 1.00,
    arm_border_thick = 1,
    arm_width = 100,
    arm_height = 12,
    arm_font_size = 8,
    arm_show_text = true,
    arm_text_format = 0,

    offset_x = 0,
    offset_y = -30,
    gap = 5,

    pulse_threshold = 20,
    pulse_speed = 9,
    arm_pulse_enabled = false,

    regen_min_delta = 3,


    heal_float_enabled = true,

    idle_hide_enabled = false,
    idle_hide_time = 5,

    vehicle_hide_enabled = false,

    swap_order = false,

    fade_duration = 1.0,

    menu_x = 277, menu_y = 97,
    menu_w = 844, menu_h = 621,
}

local iniFile = getWorkingDirectory() .. '/config/HPArmourBar.ini'

local function ensureDir(path)
    local dir = path:match('(.+)[/\\][^/\\]+$')
    if dir and not doesDirectoryExist(dir) then
        createDirectory(dir)
    end
end
ensureDir(iniFile)

local cfg = {}

local function cfg_load()
    for k, v in pairs(defaults) do
        cfg[k] = v
    end

    local f = io.open(iniFile, 'r')
    if not f then return end

    for line in f:lines() do
        local key, value = line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
        if key and value ~= nil and defaults[key] ~= nil then
            local t = type(defaults[key])
            if t == 'boolean' then
                cfg[key] = (value:lower() == 'true')
            elseif t == 'number' then
                cfg[key] = tonumber(value) or defaults[key]
            else
                cfg[key] = value
            end
        end
    end

    f:close()
end

local function cfg_save()
    local f = io.open(iniFile, 'w')
    if not f then return end

    for k, v in pairs(cfg) do
        f:write(k .. ' = ' .. tostring(v) .. '\n')
    end

    f:close()
end

cfg_load()

local winState = imgui.new.bool(false)
local curTab   = imgui.new.int(0)

local v_enabled      = imgui.new.bool(cfg.enabled)
local v_hp_enabled   = imgui.new.bool(cfg.hp_enabled)
local v_arm_enabled  = imgui.new.bool(cfg.arm_enabled)
local v_show_shadow  = imgui.new.bool(cfg.show_shadow)
local v_animate      = imgui.new.bool(cfg.animate)
local v_anim_speed   = imgui.new.float(cfg.anim_speed)

local v_hp_color     = imgui.new.float[3](cfg.hp_color_r,  cfg.hp_color_g,  cfg.hp_color_b)
local v_hp_bg        = imgui.new.float[3](cfg.hp_bg_r,     cfg.hp_bg_g,     cfg.hp_bg_b)
local v_hp_border    = imgui.new.float[3](cfg.hp_border_r, cfg.hp_border_g, cfg.hp_border_b)
local v_hp_text_col  = imgui.new.float[3](cfg.hp_text_r,   cfg.hp_text_g,   cfg.hp_text_b)
local v_hp_bthick    = imgui.new.int(cfg.hp_border_thick)
local v_hp_width     = imgui.new.int(cfg.hp_width)
local v_hp_height    = imgui.new.int(cfg.hp_height)
local v_hp_font_size = imgui.new.int(cfg.hp_font_size)
local v_hp_show_text = imgui.new.bool(cfg.hp_show_text)
local v_hp_fmt       = imgui.new.int(cfg.hp_text_format)

local v_arm_color     = imgui.new.float[3](cfg.arm_color_r,  cfg.arm_color_g,  cfg.arm_color_b)
local v_arm_bg        = imgui.new.float[3](cfg.arm_bg_r,     cfg.arm_bg_g,     cfg.arm_bg_b)
local v_arm_border    = imgui.new.float[3](cfg.arm_border_r, cfg.arm_border_g, cfg.arm_border_b)
local v_arm_text_col  = imgui.new.float[3](cfg.arm_text_r,   cfg.arm_text_g,   cfg.arm_text_b)
local v_arm_bthick    = imgui.new.int(cfg.arm_border_thick)
local v_arm_width     = imgui.new.int(cfg.arm_width)
local v_arm_height    = imgui.new.int(cfg.arm_height)
local v_arm_font_size = imgui.new.int(cfg.arm_font_size)
local v_arm_show_text = imgui.new.bool(cfg.arm_show_text)
local v_arm_fmt       = imgui.new.int(cfg.arm_text_format)

local v_offset_x = imgui.new.int(cfg.offset_x)
local v_offset_y = imgui.new.int(cfg.offset_y)
local v_gap      = imgui.new.int(cfg.gap)

local v_pulse_threshold = imgui.new.int(cfg.pulse_threshold)
local v_pulse_speed = imgui.new.float(cfg.pulse_speed)
local v_arm_pulse_enabled = imgui.new.bool(cfg.arm_pulse_enabled)

local v_regen_min_delta = imgui.new.int(cfg.regen_min_delta)


local v_heal_float_enabled = imgui.new.bool(cfg.heal_float_enabled)

local v_general_subtab = imgui.new.int(0)

local previewPulseUntil = 0

local v_idle_hide_enabled = imgui.new.bool(cfg.idle_hide_enabled)
local v_idle_hide_time    = imgui.new.int(cfg.idle_hide_time)

local v_vehicle_hide_enabled = imgui.new.bool(cfg.vehicle_hide_enabled)
local v_swap_order = imgui.new.bool(cfg.swap_order)
local v_fade_duration = imgui.new.float(cfg.fade_duration)

local textFormatItems = {u8'Число', u8'Число/Макс', u8'Проценты'}

local fonts = {}
local function getFont(size)
    if not fonts[size] then
        fonts[size] = renderCreateFont('Verdana', size, 1)
    end
    return fonts[size]
end

local smoothHP  = 100
local smoothArm = 0

local function lerp(a, b, t)
    return a + (b - a) * t
end

local particleCount = 67
local particles      = {}
local lastTime       = os.clock()
local particlesInited = false

local function spawnParticle(p, sw, sh)
    p.x     = math.random() * sw
    p.y     = -math.random(10, 80)
    p.speed = math.random(40, 120)
    p.size  = math.random(3, 7)
    p.phase = math.random() * math.pi * 2
    p.sway  = math.random(15, 40)
    p.alpha = 0.4 + math.random() * 0.5
end

local function initParticles(sw, sh)
    for i = 1, particleCount do
        local p = {}
        spawnParticle(p, sw, sh)
        p.y = math.random() * sh
        particles[i] = p
    end
end

local function updateAndDrawParticles(dt, sw, sh)
    if not particlesInited then
        initParticles(sw, sh)
        particlesInited = true
    end
    local dl = imgui.GetForegroundDrawList()
    for _, p in ipairs(particles) do
        p.y = p.y + p.speed * dt
        local drawX = p.x + math.sin(os.clock() * 1.2 + p.phase) * p.sway
        local drawY = p.y
        if drawY > sh + 20 then
            spawnParticle(p, sw, sh)
        end
        local ai  = math.floor(p.alpha * 255)
        local col = (ai * 0x1000000) + (255 * 0x10000) + (math.floor(0.6 * 255) * 0x100) + math.floor(0.8 * 255)
        dl:AddCircleFilled(imgui.ImVec2(drawX, drawY), p.size,  col, 8)
        local ai2  = math.floor(p.alpha * 0.7 * 255)
        local col2 = (ai2 * 0x1000000) + (255 * 0x10000) + (math.floor(0.9 * 255) * 0x100) + math.floor(0.95 * 255)
        dl:AddCircleFilled(imgui.ImVec2(drawX, drawY), math.floor(p.size * 0.4), col2, 6)
    end
end

local function packColor(r, g, b, a)
    a = a or 1.0
    return  math.floor(a * 255) * 0x1000000
          + math.floor(r * 255) * 0x10000
          + math.floor(g * 255) * 0x100
          + math.floor(b * 255)
end

local function formatValue(value, fmt)
    if fmt == 1 then
        return string.format('%d/100', math.floor(value))
    elseif fmt == 2 then
        return string.format('%d%%',   math.floor(value))
    else
        return string.format('%d',     math.floor(value))
    end
end


local function drawBar(posX, posY, sizeX, sizeY,
    fillCol, bgCol, borderCol, textCol,
    borderThick, fontObj, value, showText, textFmt, showShadow, regenFrom)


    renderDrawBox(posX, posY, sizeX, sizeY, bgCol)

    if borderThick > 0 then
        renderDrawBox(posX - borderThick, posY - borderThick, sizeX + borderThick * 2, borderThick, borderCol)
        renderDrawBox(posX - borderThick, posY + sizeY,       sizeX + borderThick * 2, borderThick, borderCol)
        renderDrawBox(posX - borderThick, posY,               borderThick,             sizeY,       borderCol)
        renderDrawBox(posX + sizeX,       posY,               borderThick,             sizeY,       borderCol)
    end

    local clamped   = math.max(0, math.min(100, value))
    local fillWidth = sizeX / 100 * clamped
    if fillWidth > 0 then
        renderDrawBox(posX, posY, fillWidth, sizeY, fillCol)

        if regenFrom and regenFrom < clamped then
            local regenClamped = math.max(0, math.min(100, regenFrom))
            local regenX = sizeX / 100 * regenClamped
            local regenW = fillWidth - regenX
            if regenW > 0.5 then
                local regenCol = packColor(1, 1, 1, 0.55)
                renderDrawBox(posX + regenX, posY, regenW, sizeY, regenCol)
            end
        end

        local outlineCol = packColor(0, 0, 0, 0.55)
        renderDrawBox(posX, posY, fillWidth, 1, outlineCol)
        renderDrawBox(posX, posY + sizeY - 1, fillWidth, 1, outlineCol)
        renderDrawBox(posX, posY, 1, sizeY, outlineCol)
        if fillWidth > 1 then
            renderDrawBox(posX + fillWidth - 1, posY, 1, sizeY, outlineCol)
        end
    end

    if showText and fontObj then
        local label = formatValue(value, textFmt)
        local tLen  = renderGetFontDrawTextLength(fontObj, label)
        local tH    = renderGetFontDrawHeight(fontObj)
        local tx    = posX + (sizeX / 2) - (tLen / 2)
        local ty    = posY + (sizeY / 2) - (tH  / 2)
        if showShadow then
            renderFontDrawText(fontObj, label, tx + 1, ty + 1, packColor(0, 0, 0, 0.6))
        end
        renderFontDrawText(fontObj, label, tx, ty, textCol)
    end
end

local function pinkTheme()
    local s = imgui.GetStyle()
    s.WindowPadding     = imgui.ImVec2(12, 12)
    s.FramePadding      = imgui.ImVec2(8,  5)
    s.ItemSpacing       = imgui.ImVec2(8,  6)
    s.ScrollbarSize     = 12
    s.GrabMinSize       = 10
    s.WindowBorderSize  = 1
    s.FrameBorderSize   = 0
    s.WindowRounding    = 14
    s.ChildRounding     = 10
    s.FrameRounding     = 10
    s.PopupRounding     = 10
    s.ScrollbarRounding = 10
    s.GrabRounding      = 10
    s.TabRounding       = 10
    s.WindowTitleAlign  = imgui.ImVec2(0.5, 0.5)
    s.ButtonTextAlign   = imgui.ImVec2(0.5, 0.5)

    local C = s.Colors
    C[imgui.Col.Text]                  = imgui.ImVec4(0.30, 0.10, 0.20, 1.00)
    C[imgui.Col.TextDisabled]          = imgui.ImVec4(0.70, 0.55, 0.62, 1.00)
    C[imgui.Col.WindowBg]              = imgui.ImVec4(1.00, 0.93, 0.96, 0.97)
    C[imgui.Col.ChildBg]               = imgui.ImVec4(0.99, 0.88, 0.93, 0.70)
    C[imgui.Col.PopupBg]               = imgui.ImVec4(1.00, 0.93, 0.96, 0.98)
    C[imgui.Col.Border]                = imgui.ImVec4(0.95, 0.72, 0.82, 0.80)
    C[imgui.Col.BorderShadow]          = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    C[imgui.Col.FrameBg]               = imgui.ImVec4(0.99, 0.82, 0.89, 1.00)
    C[imgui.Col.FrameBgHovered]        = imgui.ImVec4(1.00, 0.72, 0.84, 1.00)
    C[imgui.Col.FrameBgActive]         = imgui.ImVec4(0.98, 0.62, 0.78, 1.00)
    C[imgui.Col.TitleBg]               = imgui.ImVec4(0.98, 0.78, 0.88, 1.00)
    C[imgui.Col.TitleBgActive]         = imgui.ImVec4(0.97, 0.68, 0.82, 1.00)
    C[imgui.Col.TitleBgCollapsed]      = imgui.ImVec4(0.98, 0.85, 0.91, 0.80)
    C[imgui.Col.MenuBarBg]             = imgui.ImVec4(0.99, 0.85, 0.91, 1.00)
    C[imgui.Col.ScrollbarBg]           = imgui.ImVec4(0.99, 0.88, 0.93, 0.60)
    C[imgui.Col.ScrollbarGrab]         = imgui.ImVec4(0.95, 0.60, 0.76, 1.00)
    C[imgui.Col.ScrollbarGrabHovered]  = imgui.ImVec4(0.98, 0.50, 0.70, 1.00)
    C[imgui.Col.ScrollbarGrabActive]   = imgui.ImVec4(0.95, 0.38, 0.62, 1.00)
    C[imgui.Col.CheckMark]             = imgui.ImVec4(0.85, 0.25, 0.55, 1.00)
    C[imgui.Col.SliderGrab]            = imgui.ImVec4(0.90, 0.45, 0.68, 1.00)
    C[imgui.Col.SliderGrabActive]      = imgui.ImVec4(0.85, 0.25, 0.52, 1.00)
    C[imgui.Col.Button]                = imgui.ImVec4(0.97, 0.72, 0.84, 1.00)
    C[imgui.Col.ButtonHovered]         = imgui.ImVec4(0.98, 0.55, 0.74, 1.00)
    C[imgui.Col.ButtonActive]          = imgui.ImVec4(0.90, 0.35, 0.60, 1.00)
    C[imgui.Col.Header]                = imgui.ImVec4(0.97, 0.72, 0.84, 0.80)
    C[imgui.Col.HeaderHovered]         = imgui.ImVec4(0.98, 0.55, 0.74, 0.90)
    C[imgui.Col.HeaderActive]          = imgui.ImVec4(0.90, 0.35, 0.60, 1.00)
    C[imgui.Col.Separator]             = imgui.ImVec4(0.95, 0.72, 0.82, 0.80)
    C[imgui.Col.SeparatorHovered]      = imgui.ImVec4(0.92, 0.45, 0.68, 0.90)
    C[imgui.Col.SeparatorActive]       = imgui.ImVec4(0.88, 0.25, 0.55, 1.00)
    C[imgui.Col.ResizeGrip]            = imgui.ImVec4(0.90, 0.55, 0.74, 0.40)
    C[imgui.Col.ResizeGripHovered]     = imgui.ImVec4(0.92, 0.45, 0.68, 0.80)
    C[imgui.Col.ResizeGripActive]      = imgui.ImVec4(0.88, 0.28, 0.55, 1.00)
    C[imgui.Col.Tab]                   = imgui.ImVec4(0.98, 0.80, 0.88, 1.00)
    C[imgui.Col.TabHovered]            = imgui.ImVec4(0.98, 0.55, 0.74, 1.00)
    C[imgui.Col.TabActive]             = imgui.ImVec4(0.94, 0.45, 0.68, 1.00)
    C[imgui.Col.TabUnfocused]          = imgui.ImVec4(0.98, 0.85, 0.91, 0.80)
    C[imgui.Col.TabUnfocusedActive]    = imgui.ImVec4(0.97, 0.72, 0.84, 1.00)
    C[imgui.Col.TextSelectedBg]        = imgui.ImVec4(0.97, 0.60, 0.78, 0.50)
    C[imgui.Col.NavHighlight]          = imgui.ImVec4(0.85, 0.30, 0.55, 1.00)
    C[imgui.Col.ModalWindowDimBg]      = imgui.ImVec4(0.10, 0.00, 0.05, 0.50)
end

local function resetDefaults()
    for k, v in pairs(defaults) do cfg[k] = v end

    v_enabled[0]       = cfg.enabled
    v_hp_enabled[0]    = cfg.hp_enabled
    v_arm_enabled[0]   = cfg.arm_enabled
    v_show_shadow[0]   = cfg.show_shadow
    v_animate[0]       = cfg.animate
    v_anim_speed[0]    = cfg.anim_speed

    v_hp_color[0]      = cfg.hp_color_r
    v_hp_color[1]      = cfg.hp_color_g
    v_hp_color[2]      = cfg.hp_color_b
    v_hp_bg[0]         = cfg.hp_bg_r
    v_hp_bg[1]         = cfg.hp_bg_g
    v_hp_bg[2]         = cfg.hp_bg_b
    v_hp_border[0]     = cfg.hp_border_r
    v_hp_border[1]     = cfg.hp_border_g
    v_hp_border[2]     = cfg.hp_border_b
    v_hp_text_col[0]   = cfg.hp_text_r
    v_hp_text_col[1]   = cfg.hp_text_g
    v_hp_text_col[2]   = cfg.hp_text_b
    v_hp_bthick[0]     = cfg.hp_border_thick
    v_hp_width[0]      = cfg.hp_width
    v_hp_height[0]     = cfg.hp_height
    v_hp_font_size[0]  = cfg.hp_font_size
    v_hp_show_text[0]  = cfg.hp_show_text
    v_hp_fmt[0]        = cfg.hp_text_format

    v_arm_color[0]     = cfg.arm_color_r
    v_arm_color[1]     = cfg.arm_color_g
    v_arm_color[2]     = cfg.arm_color_b
    v_arm_bg[0]        = cfg.arm_bg_r
    v_arm_bg[1]        = cfg.arm_bg_g
    v_arm_bg[2]        = cfg.arm_bg_b
    v_arm_border[0]    = cfg.arm_border_r
    v_arm_border[1]    = cfg.arm_border_g
    v_arm_border[2]    = cfg.arm_border_b
    v_arm_text_col[0]  = cfg.arm_text_r
    v_arm_text_col[1]  = cfg.arm_text_g
    v_arm_text_col[2]  = cfg.arm_text_b
    v_arm_bthick[0]    = cfg.arm_border_thick
    v_arm_width[0]     = cfg.arm_width
    v_arm_height[0]    = cfg.arm_height
    v_arm_font_size[0] = cfg.arm_font_size
    v_arm_show_text[0] = cfg.arm_show_text
    v_arm_fmt[0]       = cfg.arm_text_format

    v_offset_x[0]      = cfg.offset_x
    v_offset_y[0]      = cfg.offset_y
    v_gap[0]           = cfg.gap

    v_pulse_threshold[0] = cfg.pulse_threshold
    v_pulse_speed[0]     = cfg.pulse_speed
    v_arm_pulse_enabled[0] = cfg.arm_pulse_enabled

    v_regen_min_delta[0] = cfg.regen_min_delta


    v_heal_float_enabled[0] = cfg.heal_float_enabled

    v_idle_hide_enabled[0] = cfg.idle_hide_enabled
    v_idle_hide_time[0]    = cfg.idle_hide_time

    v_vehicle_hide_enabled[0] = cfg.vehicle_hide_enabled
    v_swap_order[0]           = cfg.swap_order
    v_fade_duration[0]        = cfg.fade_duration

    cfg_save()
end

local function copyHpColorToArm()
    cfg.arm_color_r = cfg.hp_color_r; cfg.arm_color_g = cfg.hp_color_g; cfg.arm_color_b = cfg.hp_color_b
    cfg.arm_bg_r = cfg.hp_bg_r; cfg.arm_bg_g = cfg.hp_bg_g; cfg.arm_bg_b = cfg.hp_bg_b
    cfg.arm_border_r = cfg.hp_border_r; cfg.arm_border_g = cfg.hp_border_g; cfg.arm_border_b = cfg.hp_border_b
    cfg.arm_text_r = cfg.hp_text_r; cfg.arm_text_g = cfg.hp_text_g; cfg.arm_text_b = cfg.hp_text_b

    v_arm_color[0] = cfg.arm_color_r; v_arm_color[1] = cfg.arm_color_g; v_arm_color[2] = cfg.arm_color_b
    v_arm_bg[0] = cfg.arm_bg_r; v_arm_bg[1] = cfg.arm_bg_g; v_arm_bg[2] = cfg.arm_bg_b
    v_arm_border[0] = cfg.arm_border_r; v_arm_border[1] = cfg.arm_border_g; v_arm_border[2] = cfg.arm_border_b
    v_arm_text_col[0] = cfg.arm_text_r; v_arm_text_col[1] = cfg.arm_text_g; v_arm_text_col[2] = cfg.arm_text_b

    cfg_save()
end

local function copyArmColorToHp()
    cfg.hp_color_r = cfg.arm_color_r; cfg.hp_color_g = cfg.arm_color_g; cfg.hp_color_b = cfg.arm_color_b
    cfg.hp_bg_r = cfg.arm_bg_r; cfg.hp_bg_g = cfg.arm_bg_g; cfg.hp_bg_b = cfg.arm_bg_b
    cfg.hp_border_r = cfg.arm_border_r; cfg.hp_border_g = cfg.arm_border_g; cfg.hp_border_b = cfg.arm_border_b
    cfg.hp_text_r = cfg.arm_text_r; cfg.hp_text_g = cfg.arm_text_g; cfg.hp_text_b = cfg.arm_text_b

    v_hp_color[0] = cfg.hp_color_r; v_hp_color[1] = cfg.hp_color_g; v_hp_color[2] = cfg.hp_color_b
    v_hp_bg[0] = cfg.hp_bg_r; v_hp_bg[1] = cfg.hp_bg_g; v_hp_bg[2] = cfg.hp_bg_b
    v_hp_border[0] = cfg.hp_border_r; v_hp_border[1] = cfg.hp_border_g; v_hp_border[2] = cfg.hp_border_b
    v_hp_text_col[0] = cfg.hp_text_r; v_hp_text_col[1] = cfg.hp_text_g; v_hp_text_col[2] = cfg.hp_text_b

    cfg_save()
end

local function copyHpSizeToArm()
    cfg.arm_width = cfg.hp_width; cfg.arm_height = cfg.hp_height
    cfg.arm_border_thick = cfg.hp_border_thick; cfg.arm_font_size = cfg.hp_font_size

    v_arm_width[0] = cfg.arm_width; v_arm_height[0] = cfg.arm_height
    v_arm_bthick[0] = cfg.arm_border_thick; v_arm_font_size[0] = cfg.arm_font_size
    getFont(cfg.arm_font_size)

    cfg_save()
end

local function copyArmSizeToHp()
    cfg.hp_width = cfg.arm_width; cfg.hp_height = cfg.arm_height
    cfg.hp_border_thick = cfg.arm_border_thick; cfg.hp_font_size = cfg.arm_font_size

    v_hp_width[0] = cfg.hp_width; v_hp_height[0] = cfg.hp_height
    v_hp_bthick[0] = cfg.hp_border_thick; v_hp_font_size[0] = cfg.hp_font_size
    getFont(cfg.hp_font_size)

    cfg_save()
end

local function drawOverlay(sw, sh)
    local dl  = imgui.GetBackgroundDrawList()
    local col = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.18, 0.02, 0.10, 0.38))
    dl:AddRectFilled(imgui.ImVec2(0, 0), imgui.ImVec2(sw, sh), col)
end

local function sectionHeader(label)
    imgui.Spacing()
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.75, 0.18, 0.45, 1.0))
    imgui.Text(label)
    imgui.PopStyleColor()
    imgui.Separator()
    imgui.Spacing()
end

local tabFadeStart = os.clock()
local tabFadeDuration = 0.35
local tabSlideDistance = 24

local tabScaleTargetIdx = nil
local tabScaleStart = 0

local function tabButton(label, idx, width)
    local active = (curTab[0] == idx)

    local scale = 1.0
    if tabScaleTargetIdx == idx then
        local dt = os.clock() - tabScaleStart
        if dt < 0.15 then
            local t = dt / 0.15
            scale = 1.0 + math.sin(t * math.pi) * 0.08
        end
    end

    if active then
        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.88, 0.28, 0.58, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.90, 0.38, 0.65, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.82, 0.20, 0.50, 1.0))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 1.0))
    end
    local clicked = imgui.Button(label, imgui.ImVec2(width * scale, 28 * scale))
    if active then imgui.PopStyleColor(4) end
    if clicked and curTab[0] ~= idx then
        curTab[0] = idx
        tabFadeStart = os.clock()
        tabScaleTargetIdx = idx
        tabScaleStart = os.clock()
    end
end

local function easeOut(t)
    local f = t - 1
    return f * f * f + 1
end

local function tabFadeAlpha()
    local dt = os.clock() - tabFadeStart
    if dt >= tabFadeDuration then return 1.0 end
    return easeOut(dt / tabFadeDuration)
end

local function tabSlideOffset()
    local dt = os.clock() - tabFadeStart
    if dt >= tabFadeDuration then return 0 end
    local t = dt / tabFadeDuration
    return (1.0 - easeOut(t)) * tabSlideDistance
end

local tipTextColor = imgui.ImVec4(0.30, 0.10, 0.20, 1.00)

local function sliderTip(text)
    if imgui.IsItemHovered() and not imgui.IsWindowCollapsed() then
        imgui.BeginTooltip()
        imgui.PushStyleColor(imgui.Col.Text, tipTextColor)
        imgui.Text(text)
        imgui.PopStyleColor()
        imgui.EndTooltip()
    end
end

local holdTipDelay = 0.35
local holdTipStarts = {}

local function holdTip(id, text)
    local active = imgui.IsItemActive() and not imgui.IsWindowCollapsed()

    if active then
        if not holdTipStarts[id] then
            holdTipStarts[id] = os.clock()
        end

        local heldFor = os.clock() - holdTipStarts[id]
        if heldFor >= holdTipDelay then
            local mp = imgui.GetIO().MousePos
            local tw = imgui.CalcTextSize(text).x

            imgui.SetNextWindowPos(imgui.ImVec2(mp.x - tw / 2, mp.y - 46), imgui.Cond.Always)
            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, math.min((heldFor - holdTipDelay) / 0.15, 1.0))
            imgui.Begin('##holdtip_' .. id, nil,
                imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize +
                imgui.WindowFlags.NoMove + imgui.WindowFlags.NoInputs +
                imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoFocusOnAppearing +
                imgui.WindowFlags.NoSavedSettings)
            imgui.PushStyleColor(imgui.Col.Text, tipTextColor)
            imgui.Text(text)
            imgui.PopStyleColor()
            imgui.End()
            imgui.PopStyleVar()
        end
    else
        holdTipStarts[id] = nil
    end
end

local function comboRadio(label, v_idx, items)
    local changed = false
    local count = #items
    local spacing = imgui.GetStyle().ItemSpacing.x
    local availWidth = imgui.GetContentRegionAvail().x
    local itemWidth = (availWidth - spacing * (count - 1)) / count

    for i, item in ipairs(items) do
        local isSelected = (v_idx[0] == (i - 1))
        if isSelected then
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.88, 0.28, 0.58, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.90, 0.38, 0.65, 1.0))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.82, 0.20, 0.50, 1.0))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 1.0))
        end
        if imgui.Button(item .. '##' .. label .. i, imgui.ImVec2(itemWidth, 0)) then
            v_idx[0] = i - 1
            changed  = true
        end
        if isSelected then
            imgui.PopStyleColor(4)
        end
        if i < #items then imgui.SameLine() end
    end
    return changed
end

local function drawGeneralTab()
    comboRadio('generalsubtab', v_general_subtab, { u8'Основное', u8'Пульс и реген', u8'Прочее' })
    imgui.Spacing()

    if v_general_subtab[0] == 0 then
        sectionHeader(u8'Переключатели')

        if imgui.Checkbox(u8'Включить оверлей', v_enabled) then
            cfg.enabled = v_enabled[0]; cfg_save()
        end
        holdTip('enabled', u8'Полностью вкл/выкл отображение баров')
        imgui.Spacing()
        if imgui.Checkbox(u8'Показывать HP', v_hp_enabled) then
            cfg.hp_enabled = v_hp_enabled[0]; cfg_save()
        end
        holdTip('hp_enabled', u8'Показывать полоску здоровья отдельно')
        if imgui.Checkbox(u8'Показывать броню', v_arm_enabled) then
            cfg.arm_enabled = v_arm_enabled[0]; cfg_save()
        end
        holdTip('arm_enabled', u8'Показывать полоску брони отдельно')

        sectionHeader(u8'Эффекты')

        if imgui.Checkbox(u8'Анимация заполнения', v_animate) then
            cfg.animate = v_animate[0]; cfg_save()
        end
        holdTip('animate', u8'Плавный переход бара вместо мгновенного скачка')
        if v_animate[0] then
            imgui.Text(u8'Скорость анимации')
            imgui.PushItemWidth(-1)
            if imgui.SliderFloat('##aspd', v_anim_speed, 0.01, 0.30) then
                cfg.anim_speed = v_anim_speed[0]; cfg_save()
            end
            sliderTip(u8'Скорость сглаживания изменений HP и брони')
            imgui.PopItemWidth()
        end
        imgui.Spacing()
        if imgui.Checkbox(u8'Тень текста', v_show_shadow) then
            cfg.show_shadow = v_show_shadow[0]; cfg_save()
        end
        holdTip('show_shadow', u8'Тёмная подложка под текстом для читаемости')
    end

    if v_general_subtab[0] == 1 then
        sectionHeader(u8'Порог пульсации HP (%)')
        imgui.PushItemWidth(-1)
        if imgui.SliderInt('##pulsethr', v_pulse_threshold, 1, 99) then
            cfg.pulse_threshold = v_pulse_threshold[0]; cfg_save()
        end
        sliderTip(u8'При каком проценте бар начнёт привлекать внимание')
        imgui.PopItemWidth()

        imgui.Text(u8'Скорость мигания')
        imgui.PushItemWidth(-1)
        if imgui.SliderFloat('##pulsespeed', v_pulse_speed, 1.0, 20.0) then
            cfg.pulse_speed = v_pulse_speed[0]; cfg_save()
        end
        sliderTip(u8'Как быстро мигает бар при низком значении')
        imgui.PopItemWidth()

        imgui.Spacing()
        if imgui.Checkbox(u8'Пульсация брони тоже', v_arm_pulse_enabled) then
            cfg.arm_pulse_enabled = v_arm_pulse_enabled[0]; cfg_save()
        end
        holdTip('arm_pulse', u8'Применить тот же порог/скорость мигания к бару брони')

        imgui.Spacing()
        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.85, 0.20, 0.45, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.90, 0.30, 0.55, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.80, 0.15, 0.40, 1.0))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 1.0))
        if imgui.Button(u8'Предпросмотр пульсации (3 сек)', imgui.ImVec2(-1, 32)) then
            previewPulseUntil = os.clock() + 3
        end
        holdTip('preview_pulse', u8'Показывает эффект пульсации на 3 секунды без реального урона')
        imgui.PopStyleColor(4)

        sectionHeader(u8'Фильтр регенерации')
        imgui.Text(u8'Не показывать регенерацию, если рост меньше')
        imgui.PushItemWidth(-1)
        if imgui.SliderInt('##regenmin', v_regen_min_delta, 0, 50) then
            cfg.regen_min_delta = v_regen_min_delta[0]; cfg_save()
        end
        sliderTip(u8'Мелкие приросты HP/брони (например от еды) не будут подсвечиваться как регенерация')
        imgui.PopItemWidth()

        sectionHeader(u8'Плавающий текст лечения')
        if imgui.Checkbox(u8'Показывать "+N" при лечении вне машины', v_heal_float_enabled) then
            cfg.heal_float_enabled = v_heal_float_enabled[0]; cfg_save()
        end
        holdTip('heal_float', u8'Плавающая цифра прироста HP/брони появляется и пешком, не только в машине')
    end

    if v_general_subtab[0] == 2 then
        sectionHeader(u8'Авто-скрытие при бездействии')
        if imgui.Checkbox(u8'Включить авто-скрытие', v_idle_hide_enabled) then
            cfg.idle_hide_enabled = v_idle_hide_enabled[0]; cfg_save()
        end
        holdTip('idle_hide', u8'Скрыть бар, если HP и броня долго не менялись')
        if v_idle_hide_enabled[0] then
            imgui.Text(u8'Время бездействия (сек)')
            imgui.PushItemWidth(-1)
            if imgui.SliderInt('##idletime', v_idle_hide_time, 1, 60) then
                cfg.idle_hide_time = v_idle_hide_time[0]; cfg_save()
            end
            sliderTip(u8'Через сколько секунд без изменений бар исчезнет')
            imgui.PopItemWidth()
        end

        sectionHeader(u8'Бар в транспорте')
        if imgui.Checkbox(u8'Скрывать бар в машине', v_vehicle_hide_enabled) then
            cfg.vehicle_hide_enabled = v_vehicle_hide_enabled[0]; cfg_save()
        end
        holdTip('vehicle_hide', u8'В машине бар прячется, показываясь на 5 сек при изменениях')
        if v_vehicle_hide_enabled[0] then
            imgui.TextWrapped(u8'При изменении HP или брони в машине бар кратко появится и покажет разницу.')
        end

        sectionHeader(u8'Сброс настроек')
        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.85, 0.20, 0.45, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.90, 0.30, 0.55, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.80, 0.15, 0.40, 1.0))
        imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 1.0))
        if imgui.Button(u8'Сбросить все настройки', imgui.ImVec2(-1, 32)) then
            resetDefaults()
        end
        holdTip('reset_all', u8'Вернуть все параметры к значениям по умолчанию (включая порядок HP/брони)')
        imgui.PopStyleColor(4)
    end
end

local function drawHpTab()
    sectionHeader(u8'Цвета HP')

    imgui.Text(u8'Цвет заливки')
    imgui.PushItemWidth(-1)
    if imgui.ColorEdit3('##hpcol', v_hp_color) then
        cfg.hp_color_r = v_hp_color[0]
        cfg.hp_color_g = v_hp_color[1]
        cfg.hp_color_b = v_hp_color[2]; cfg_save()
    end
    imgui.PopItemWidth()

    imgui.Text(u8'Цвет фона')
    imgui.PushItemWidth(-1)
    if imgui.ColorEdit3('##hpbg', v_hp_bg) then
        cfg.hp_bg_r = v_hp_bg[0]; cfg.hp_bg_g = v_hp_bg[1]; cfg.hp_bg_b = v_hp_bg[2]; cfg_save()
    end
    imgui.PopItemWidth()

    imgui.Text(u8'Цвет рамки')
    imgui.PushItemWidth(-1)
    if imgui.ColorEdit3('##hpbrd', v_hp_border) then
        cfg.hp_border_r = v_hp_border[0]; cfg.hp_border_g = v_hp_border[1]; cfg.hp_border_b = v_hp_border[2]; cfg_save()
    end
    imgui.PopItemWidth()

    imgui.Text(u8'Цвет текста')
    imgui.PushItemWidth(-1)
    if imgui.ColorEdit3('##hptc', v_hp_text_col) then
        cfg.hp_text_r = v_hp_text_col[0]; cfg.hp_text_g = v_hp_text_col[1]; cfg.hp_text_b = v_hp_text_col[2]; cfg_save()
    end
    imgui.PopItemWidth()

    sectionHeader(u8'Размеры HP')

    imgui.Text(u8'Ширина')
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##hpw', v_hp_width, 40, 300) then
        cfg.hp_width = v_hp_width[0]; cfg_save()
    end
    sliderTip(u8'Ширина полоски HP в пикселях')
    imgui.PopItemWidth()

    imgui.Text(u8'Высота')
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##hph', v_hp_height, 4, 40) then
        cfg.hp_height = v_hp_height[0]; cfg_save()
    end
    sliderTip(u8'Высота полоски HP в пикселях')
    imgui.PopItemWidth()

    imgui.Text(u8'Толщина рамки')
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##hpbt', v_hp_bthick, 0, 10) then
        cfg.hp_border_thick = v_hp_bthick[0]; cfg_save()
    end
    sliderTip(u8'Толщина рамки вокруг полоски HP')
    imgui.PopItemWidth()

    sectionHeader(u8'Текст HP')

    if imgui.Checkbox(u8'Показывать значение##hp', v_hp_show_text) then
        cfg.hp_show_text = v_hp_show_text[0]; cfg_save()
    end
    holdTip('hp_show_text', u8'Выводить число HP поверх полоски')

    imgui.Text(u8'Размер шрифта')
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##hpfs', v_hp_font_size, 6, 24) then
        cfg.hp_font_size = v_hp_font_size[0]
        getFont(cfg.hp_font_size); cfg_save()
    end
    sliderTip(u8'Размер шрифта текста на полоске HP')
    imgui.PopItemWidth()

    imgui.Text(u8'Формат текста')
    if comboRadio('hpfmt', v_hp_fmt, textFormatItems) then
        cfg.hp_text_format = v_hp_fmt[0]; cfg_save()
    end

    sectionHeader(u8'Копирование в броню')
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.85, 0.20, 0.45, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.90, 0.30, 0.55, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.80, 0.15, 0.40, 1.0))
    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 1.0))
    if imgui.Button(u8'Скопировать цвет##hp2arm', imgui.ImVec2(-1, 30)) then
        copyHpColorToArm()
    end
    holdTip('copy_hp2arm_color', u8'Применить цвета HP-бара к бару брони')
    if imgui.Button(u8'Скопировать размер##hp2arm', imgui.ImVec2(-1, 30)) then
        copyHpSizeToArm()
    end
    holdTip('copy_hp2arm_size', u8'Применить размеры HP-бара к бару брони')
    imgui.PopStyleColor(4)
end

local function drawArmorTab()
    sectionHeader(u8'Цвета брони')

    imgui.Text(u8'Цвет заливки')
    imgui.PushItemWidth(-1)
    if imgui.ColorEdit3('##armcol', v_arm_color) then
        cfg.arm_color_r = v_arm_color[0]; cfg.arm_color_g = v_arm_color[1]; cfg.arm_color_b = v_arm_color[2]; cfg_save()
    end
    imgui.PopItemWidth()

    imgui.Text(u8'Цвет фона')
    imgui.PushItemWidth(-1)
    if imgui.ColorEdit3('##armbg', v_arm_bg) then
        cfg.arm_bg_r = v_arm_bg[0]; cfg.arm_bg_g = v_arm_bg[1]; cfg.arm_bg_b = v_arm_bg[2]; cfg_save()
    end
    imgui.PopItemWidth()

    imgui.Text(u8'Цвет рамки')
    imgui.PushItemWidth(-1)
    if imgui.ColorEdit3('##armbrd', v_arm_border) then
        cfg.arm_border_r = v_arm_border[0]; cfg.arm_border_g = v_arm_border[1]; cfg.arm_border_b = v_arm_border[2]; cfg_save()
    end
    imgui.PopItemWidth()

    imgui.Text(u8'Цвет текста')
    imgui.PushItemWidth(-1)
    if imgui.ColorEdit3('##armtc', v_arm_text_col) then
        cfg.arm_text_r = v_arm_text_col[0]; cfg.arm_text_g = v_arm_text_col[1]; cfg.arm_text_b = v_arm_text_col[2]; cfg_save()
    end
    imgui.PopItemWidth()

    sectionHeader(u8'Размеры брони')

    imgui.Text(u8'Ширина')
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##armw', v_arm_width, 40, 300) then
        cfg.arm_width = v_arm_width[0]; cfg_save()
    end
    sliderTip(u8'Ширина полоски брони в пикселях')
    imgui.PopItemWidth()

    imgui.Text(u8'Высота')
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##armh', v_arm_height, 4, 40) then
        cfg.arm_height = v_arm_height[0]; cfg_save()
    end
    sliderTip(u8'Высота полоски брони в пикселях')
    imgui.PopItemWidth()

    imgui.Text(u8'Толщина рамки')
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##armbt', v_arm_bthick, 0, 10) then
        cfg.arm_border_thick = v_arm_bthick[0]; cfg_save()
    end
    sliderTip(u8'Толщина рамки вокруг полоски брони')
    imgui.PopItemWidth()

    sectionHeader(u8'Текст брони')

    if imgui.Checkbox(u8'Показывать значение##arm', v_arm_show_text) then
        cfg.arm_show_text = v_arm_show_text[0]; cfg_save()
    end
    holdTip('arm_show_text', u8'Выводить число брони поверх полоски')

    imgui.Text(u8'Размер шрифта')
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##armfs', v_arm_font_size, 6, 24) then
        cfg.arm_font_size = v_arm_font_size[0]
        getFont(cfg.arm_font_size); cfg_save()
    end
    sliderTip(u8'Размер шрифта текста на полоске брони')
    imgui.PopItemWidth()

    imgui.Text(u8'Формат текста')
    if comboRadio('armfmt', v_arm_fmt, textFormatItems) then
        cfg.arm_text_format = v_arm_fmt[0]; cfg_save()
    end

    sectionHeader(u8'Копирование в HP')
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.85, 0.20, 0.45, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.90, 0.30, 0.55, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.80, 0.15, 0.40, 1.0))
    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 1.0))
    if imgui.Button(u8'Скопировать цвет##arm2hp', imgui.ImVec2(-1, 30)) then
        copyArmColorToHp()
    end
    holdTip('copy_arm2hp_color', u8'Применить цвета бара брони к HP-бару')
    if imgui.Button(u8'Скопировать размер##arm2hp', imgui.ImVec2(-1, 30)) then
        copyArmSizeToHp()
    end
    holdTip('copy_arm2hp_size', u8'Применить размеры бара брони к HP-бару')
    imgui.PopStyleColor(4)
end

local function drawPositionTab()
    sectionHeader(u8'Смещение от персонажа')

    imgui.Text(u8'Смещение по X')
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##offx', v_offset_x, -500, 500) then
        cfg.offset_x = v_offset_x[0]; cfg_save()
    end
    sliderTip(u8'Сдвиг баров влево/вправо от головы персонажа')
    imgui.PopItemWidth()

    imgui.Text(u8'Смещение по Y')
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##offy', v_offset_y, -500, 500) then
        cfg.offset_y = v_offset_y[0]; cfg_save()
    end
    sliderTip(u8'Сдвиг баров вверх/вниз от головы персонажа')
    imgui.PopItemWidth()

    sectionHeader(u8'Порядок баров')
    if imgui.Checkbox(u8'Поменять HP и броню местами', v_swap_order) then
        cfg.swap_order = v_swap_order[0]; cfg_save()
    end
    holdTip('swap_order', u8'Броня сверху, HP снизу вместо обычного порядка')

    sectionHeader(u8'Пресеты позиции')
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.85, 0.20, 0.45, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.90, 0.30, 0.55, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.80, 0.15, 0.40, 1.0))
    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(1.00, 1.00, 1.00, 1.0))
    if imgui.Button(u8'Над головой##presetTop', imgui.ImVec2(-1, 30)) then
        v_offset_x[0] = 0; v_offset_y[0] = -30
        cfg.offset_x = 0; cfg.offset_y = -30; cfg_save()
    end
    holdTip('preset_top', u8'Классическое положение баров над головой')
    if imgui.Button(u8'Снизу экрана##presetBottom', imgui.ImVec2(-1, 30)) then
        v_offset_x[0] = 0; v_offset_y[0] = 300
        cfg.offset_x = 0; cfg.offset_y = 300; cfg_save()
    end
    holdTip('preset_bottom', u8'Перенести бары в нижнюю часть экрана, как HUD')
    if imgui.Button(u8'Сбоку##presetSide', imgui.ImVec2(-1, 30)) then
        v_offset_x[0] = 150; v_offset_y[0] = 0
        cfg.offset_x = 150; cfg.offset_y = 0; cfg_save()
    end
    holdTip('preset_side', u8'Сдвинуть бары вбок от персонажа')
    imgui.PopStyleColor(4)

    sectionHeader(u8'Зазор между барами')

    imgui.Text(u8'Расстояние (px)')
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##gap', v_gap, 0, 30) then
        cfg.gap = v_gap[0]; cfg_save()
    end
    sliderTip(u8'Расстояние между баром HP и баром брони')
    imgui.PopItemWidth()

    imgui.Spacing()
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.55, 0.20, 0.38, 1.0))
    imgui.Text(u8'Y < 0 = выше головы, Y > 0 = ниже')
    imgui.Text(u8'X < 0 = левее,       X > 0 = правее')
    imgui.PopStyleColor()
end

local function drawInfoTab()
    sectionHeader(u8'О скрипте')
    imgui.Spacing()

    local function cText(t)
        local tw = imgui.CalcTextSize(t).x
        imgui.SetCursorPosX((imgui.GetWindowWidth() - tw) * 0.5)
        imgui.Text(t)
    end

    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.75, 0.18, 0.45, 1.0))
    cText('HP & Armour Bar')
    imgui.PopStyleColor()
    imgui.Spacing()
    cText(u8'Бары здоровья и брони над головой')
    imgui.Spacing()

    local statusColor = cfg.enabled and imgui.ImVec4(0.20, 0.75, 0.35, 1.0) or imgui.ImVec4(0.75, 0.20, 0.20, 1.0)
    local statusLabel = cfg.enabled and u8'Включен' or u8'Выключен'
    imgui.PushStyleColor(imgui.Col.Text, statusColor)
    cText(u8'Статус: ' .. statusLabel)
    imgui.PopStyleColor()
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    sectionHeader(u8'Отображение')
    imgui.BulletText(u8'Отдельные цвета, размеры и шрифт для HP и брони')
    imgui.BulletText(u8'Плавная анимация изменения значений')
    imgui.BulletText(u8'Настраиваемое смещение баров над головой')
    imgui.BulletText(u8'Опциональная тень текста для читаемости')

    sectionHeader(u8'Умное поведение')
    imgui.BulletText(u8'Бар брони не занимает место, когда брони нет')
    imgui.BulletText(u8'HP-бар привлекает внимание при низком здоровье')
    imgui.BulletText(u8'Авто-скрытие бара в простое, если включено')
    imgui.BulletText(u8'Отдельная логика поведения в транспорте')

    sectionHeader(u8'Удобство')
    imgui.BulletText(u8'Все позиции и размер окна сохраняются')
    imgui.BulletText(u8'Подсказки при наведении на каждый параметр')
    imgui.BulletText(u8'Быстрое копирование настроек между HP и бронёй')
    imgui.BulletText(u8'Сброс к заводским настройкам одной кнопкой')

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    sectionHeader(u8'Команды')
    imgui.Text(u8'/hpbar')
    imgui.SameLine()
    imgui.TextDisabled(u8'- открыть / закрыть меню')

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.55, 0.55, 0.55, 1.0))
    cText(u8'Все настройки применяются мгновенно и сохраняются автоматически')
    imgui.PopStyleColor()
    imgui.Spacing()
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    pinkTheme()
    getFont(cfg.hp_font_size)
    getFont(cfg.arm_font_size)
end)

imgui.OnFrame(function() return winState[0] end, function()
    local sw, sh = getScreenResolution()

    drawOverlay(sw, sh)

    local now = os.clock()
    local dt  = math.min(now - lastTime, 0.05)
    lastTime  = now
    updateAndDrawParticles(dt, sw, sh)

    imgui.SetNextWindowPos(imgui.ImVec2(cfg.menu_x, cfg.menu_y), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(imgui.ImVec2(cfg.menu_w, cfg.menu_h), imgui.Cond.FirstUseEver)

    imgui.Begin('HP', winState)

    local wPos  = imgui.GetWindowPos()
    local wSize = imgui.GetWindowSize()
    if wPos.x ~= cfg.menu_x or wPos.y ~= cfg.menu_y then
        cfg.menu_x = wPos.x; cfg.menu_y = wPos.y; cfg_save()
    end
    if wSize.x ~= cfg.menu_w or wSize.y ~= cfg.menu_h then
        cfg.menu_w = wSize.x; cfg.menu_h = wSize.y; cfg_save()
    end

    local tabCount = 5
    local tabSpacing = imgui.GetStyle().ItemSpacing.x
    local tabAreaWidth = imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x * 2
    local tabWidth = (tabAreaWidth - tabSpacing * (tabCount - 1)) / tabCount

  tabButton(u8'Общие', 0, tabWidth); imgui.SameLine()
  tabButton('HP', 1, tabWidth); imgui.SameLine()
  tabButton(u8'Броня', 2, tabWidth); imgui.SameLine()
  tabButton(u8'Позиция', 3, tabWidth); imgui.SameLine()
  tabButton(u8'Инфо', 4, tabWidth)

    imgui.Separator()
    imgui.Spacing()

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, tabFadeAlpha())
    imgui.SetCursorPosY(imgui.GetCursorPosY() + tabSlideOffset())

    if curTab[0] == 0 then drawGeneralTab() end

    if curTab[0] == 1 then drawHpTab() end

    if curTab[0] == 2 then drawArmorTab() end

    if curTab[0] == 3 then drawPositionTab() end

    if curTab[0] == 4 then drawInfoTab() end


    imgui.PopStyleVar()

    imgui.End()
end)

local prefixColored = '{FF69B4}[HPBar]{FFFFFF} ' .. 'Загружен! /hpbar - открыть меню'

function main()
    while not isSampAvailable() do wait(100) end

    local lastChangeTime = os.clock()
    local globalAlpha    = 1.0

    sampRegisterChatCommand('hpbar', function()
        winState[0] = not winState[0]
        if not winState[0] then
            particlesInited = false
        else
            lastChangeTime = os.clock()
        end
    end)

    sampAddChatMessage(prefixColored, -1)

    local lastHP  = getCharHealth(PLAYER_PED) or 100
    local lastArm = getCharArmour(PLAYER_PED) or 0

    local vehicleFlashUntil = 0
    local vehicleFlashHPDelta  = 0
    local vehicleFlashArmDelta = 0

    local regenFromHP, regenUntilHP = nil, 0
    local regenFromArm, regenUntilArm = nil, 0

    local healFloatDeltaHP, healFloatUntilHP = 0, 0
    local healFloatDeltaArm, healFloatUntilArm = 0, 0

    while true do
        wait(0)

        if not cfg.enabled then goto continue end
        if not doesCharExist(PLAYER_PED) then goto continue end

        local hp  = getCharHealth(PLAYER_PED)
        local arm = getCharArmour(PLAYER_PED)

        local hpChanged  = math.abs(hp - lastHP) > 0.05
        local armChanged = math.abs(arm - lastArm) > 0.05

        local inVehicle = isCharInAnyCar and isCharInAnyCar(PLAYER_PED) or false

        if inVehicle and cfg.vehicle_hide_enabled and (hpChanged or armChanged) then
            vehicleFlashUntil     = os.clock() + 5
            vehicleFlashHPDelta   = hp  - lastHP
            vehicleFlashArmDelta  = arm - lastArm
        end

        if hpChanged and hp > lastHP and (hp - lastHP) >= cfg.regen_min_delta then
            regenFromHP = lastHP
            regenUntilHP = os.clock() + 1.5
            if cfg.heal_float_enabled then
                healFloatDeltaHP = hp - lastHP
                healFloatUntilHP = os.clock() + 1.5
            end
        end
        if armChanged and arm > lastArm and (arm - lastArm) >= cfg.regen_min_delta then
            regenFromArm = lastArm
            regenUntilArm = os.clock() + 1.5
            if cfg.heal_float_enabled then
                healFloatDeltaArm = arm - lastArm
                healFloatUntilArm = os.clock() + 1.5
            end
        end

        if hpChanged or armChanged then
            lastChangeTime = os.clock()
        end
        lastHP  = hp
        lastArm = arm

        if cfg.animate then
            smoothHP  = lerp(smoothHP,  hp,  cfg.anim_speed)
            smoothArm = lerp(smoothArm, arm, cfg.anim_speed)
        else
            smoothHP  = hp
            smoothArm = arm
        end

        local vehicleFlashActive = (os.clock() < vehicleFlashUntil)
        local previewActive = os.clock() < previewPulseUntil

        local targetAlpha = 1.0

        if inVehicle and cfg.vehicle_hide_enabled and not vehicleFlashActive and not previewActive then
            targetAlpha = 0.0
        end

        if cfg.idle_hide_enabled and not vehicleFlashActive and not previewActive then
            local idleFor = os.clock() - lastChangeTime
            if idleFor > cfg.idle_hide_time then
                targetAlpha = 0.0
            end
        end

        local fadeStep = (1.0 / math.max(cfg.fade_duration, 0.05)) / 60.0
        if targetAlpha > globalAlpha then
            globalAlpha = math.min(globalAlpha + fadeStep * 3.5, targetAlpha)
        else
            globalAlpha = math.max(globalAlpha - fadeStep, targetAlpha)
        end

        if globalAlpha < 0.01 then goto continue end

        local px, py, pz = getCharCoordinates(PLAYER_PED)

        local sx, sy, onScreen
        local ok = pcall(function()
            sx, sy, onScreen = convert3DCoordsToScreen(px, py, pz + 1.1)
        end)
        if not ok then goto continue end

        local screenW, screenH = getScreenResolution()
        if onScreen == false                    then goto continue end
        if sx == nil or sy == nil               then goto continue end
        if sx < -300 or sx > screenW + 300      then goto continue end
        if sy < -300 or sy > screenH + 300      then goto continue end

        sx = sx + cfg.offset_x
        sy = sy + cfg.offset_y

        local fontHP  = getFont(cfg.hp_font_size)
        local fontArm = getFont(cfg.arm_font_size)

        local hpPulseAlpha = 1.0
        local hpPulseScale = 1.0
        if smoothHP < cfg.pulse_threshold or previewActive then
            local pulse = math.abs(math.sin(os.clock() * cfg.pulse_speed))
            hpPulseAlpha = 0.25 + pulse * 0.75
            hpPulseScale = 1.0 + pulse * 0.12
        end

        local armPulseAlpha = 1.0
        local armPulseScale = 1.0
        if cfg.arm_pulse_enabled and (smoothArm < cfg.pulse_threshold or previewActive) then
            local pulse = math.abs(math.sin(os.clock() * cfg.pulse_speed))
            armPulseAlpha = 0.25 + pulse * 0.75
            armPulseScale = 1.0 + pulse * 0.12
        end

        local hpFill   = packColor(cfg.hp_color_r,  cfg.hp_color_g,  cfg.hp_color_b, hpPulseAlpha * globalAlpha)
        local hpBg     = packColor(cfg.hp_bg_r,     cfg.hp_bg_g,     cfg.hp_bg_b,    globalAlpha)
        local hpBorder = packColor(cfg.hp_border_r, cfg.hp_border_g, cfg.hp_border_b,globalAlpha)
        local hpText   = packColor(cfg.hp_text_r,   cfg.hp_text_g,   cfg.hp_text_b,  globalAlpha)

        local armFill   = packColor(cfg.arm_color_r,  cfg.arm_color_g,  cfg.arm_color_b, armPulseAlpha * globalAlpha)
        local armBg     = packColor(cfg.arm_bg_r,     cfg.arm_bg_g,     cfg.arm_bg_b,    globalAlpha)
        local armBorder = packColor(cfg.arm_border_r, cfg.arm_border_g, cfg.arm_border_b,globalAlpha)
        local armText   = packColor(cfg.arm_text_r,   cfg.arm_text_g,   cfg.arm_text_b,  globalAlpha)

        local hpX, hpY, armX, armY
        if cfg.swap_order then
            armX = sx - cfg.arm_width / 2
            armY = sy
            hpX  = sx - cfg.hp_width / 2
            hpY  = sy + cfg.arm_height + cfg.gap + cfg.arm_border_thick * 2
        else
            hpX  = sx - cfg.hp_width  / 2
            hpY  = sy
            armX = sx - cfg.arm_width  / 2
            armY = sy + cfg.hp_height + cfg.gap + cfg.hp_border_thick * 2
        end

        if cfg.hp_enabled then
            local pulsedW = cfg.hp_width  * hpPulseScale
            local pulsedH = cfg.hp_height * hpPulseScale
            local pulsedX = hpX - (pulsedW - cfg.hp_width) / 2
            local pulsedY = hpY - (pulsedH - cfg.hp_height) / 2

            local activeRegenFromHP = (os.clock() < regenUntilHP) and regenFromHP or nil

            drawBar(pulsedX, pulsedY, pulsedW, pulsedH,
                hpFill, hpBg, hpBorder, hpText,
                cfg.hp_border_thick, fontHP,
                smoothHP, cfg.hp_show_text, cfg.hp_text_format, cfg.show_shadow, activeRegenFromHP)

            if vehicleFlashActive and math.abs(vehicleFlashHPDelta) > 0.05 then
                local sign = vehicleFlashHPDelta > 0 and '+' or ''
                local deltaLabel = sign .. tostring(math.floor(vehicleFlashHPDelta))
                renderFontDrawText(fontHP, deltaLabel, hpX + cfg.hp_width + 6, hpY, hpText)
            elseif not vehicleFlashActive and os.clock() < healFloatUntilHP then
                local deltaLabel = '+' .. tostring(math.floor(healFloatDeltaHP))
                renderFontDrawText(fontHP, deltaLabel, hpX + cfg.hp_width + 6, hpY, hpText)
            end
        end

        if cfg.arm_enabled and smoothArm > 0.5 then
            local pulsedArmW = cfg.arm_width  * armPulseScale
            local pulsedArmH = cfg.arm_height * armPulseScale
            local pulsedArmX = armX - (pulsedArmW - cfg.arm_width) / 2
            local pulsedArmY = armY - (pulsedArmH - cfg.arm_height) / 2

            local activeRegenFromArm = (os.clock() < regenUntilArm) and regenFromArm or nil

            drawBar(pulsedArmX, pulsedArmY, pulsedArmW, pulsedArmH,
                armFill, armBg, armBorder, armText,
                cfg.arm_border_thick, fontArm,
                smoothArm, cfg.arm_show_text, cfg.arm_text_format, cfg.show_shadow, activeRegenFromArm)

            if vehicleFlashActive and math.abs(vehicleFlashArmDelta) > 0.05 then
                local sign = vehicleFlashArmDelta > 0 and '+' or ''
                local deltaLabel = sign .. tostring(math.floor(vehicleFlashArmDelta))
                renderFontDrawText(fontArm, deltaLabel, armX + cfg.arm_width + 6, armY, armText)
            elseif not vehicleFlashActive and os.clock() < healFloatUntilArm then
                local deltaLabel = '+' .. tostring(math.floor(healFloatDeltaArm))
                renderFontDrawText(fontArm, deltaLabel, armX + cfg.arm_width + 6, armY, armText)
            end
        end

        ::continue::
    end
end