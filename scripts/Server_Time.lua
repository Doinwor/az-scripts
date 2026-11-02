script_name('Server Time')
script_author('Kalashnikov / port by Charlie_Deep')
script_version('1.00')

local encoding = require 'encoding'
local imgui = require 'mimgui'
local sampev = require 'samp.events'

encoding.default = 'CP1251'
u8 = encoding.UTF8

local BASE_SCREEN_WIDTH = 800.0
local BASE_SCREEN_HEIGHT = 600.0
local BASE_FONT_SIZE = 21.0
local LABEL_TIME_GAP = 14.0
local MIN_FONT_SIZE = 11.0
local SCREEN_PADDING = 12.0
local BOTTOM_OFFSET_RATIO = 0.075
local MAX_OUTLINE_OFFSET = 2.45
local POSITION_EDITOR_PADDING_X = 12.0
local POSITION_EDITOR_PADDING_Y = 8.0

local CONFIG_DIR = getWorkingDirectory() .. '/config'
local CONFIG_PATH = CONFIG_DIR .. '/Server Time.ini'

local LABEL_TEXT = 'SERVER TIME:'
local INITIAL_TIME_TEXT = '00:00:00'

local DIALOG_TIME_MARKER = '\210\229\234\243\249\229\229\32\226\240\229\236\255'
local DIALOG_DATE_LABEL = '\209\229\227\238\228\237\255\248\237\255\255\32\228\224\242\224\58'
local DIALOG_TIME_LABEL = '\210\229\234\243\249\229\229\32\226\240\229\236\255\58'

local LABEL_COLOR = imgui.ImVec4(0.882, 0.882, 0.882, 1.0)
local TIME_COLOR = imgui.ImVec4(1.0, 0.388, 0.278, 1.0)
local OUTLINE_COLOR = imgui.ImVec4(0.0, 0.0, 0.0, 1.0)
local POSITION_EDITOR_BG_COLOR = imgui.ImVec4(0.0, 0.0, 0.0, 0.18)

local is_samp_ready = false
local is_position_edit_mode = false
local server_time_offset = 0
local cached_second = -1
local cached_time_text = INITIAL_TIME_TEXT
local last_config_save_at = 0.0
local edit_window_state = imgui.new.bool(false)
local skip_position_save_once = false
local pending_editor_window_x = -1
local pending_editor_window_y = -1
local overlay_frame = nil
local config = {
    pos_x = -1,
    pos_y = -1
}

local function clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    end

    if value > max_value then
        return max_value
    end

    return value
end

local function get_text_width(text, font_size, ratio)
    return #text * font_size * ratio
end

local function get_render_text_width(font, text, font_size, fallback_ratio)
    if font ~= nil and font.CalcTextSizeA ~= nil then
        local size = font:CalcTextSizeA(font_size, 1000.0, 0.0, text)
        if size ~= nil and size.x ~= nil and size.x > 0 then
            return size.x
        end
    end

    return get_text_width(text, font_size, fallback_ratio)
end

local function get_overlay_size(screen_x, screen_y, font)
    local scale = clamp(math.min(screen_x / BASE_SCREEN_WIDTH, screen_y / BASE_SCREEN_HEIGHT), 0.75, 2.35)
    local font_size = clamp(BASE_FONT_SIZE * scale, 15.0, 40.0)
    local gap = clamp(LABEL_TIME_GAP * scale, 8.0, 24.0)
    local label_width = get_render_text_width(font, LABEL_TEXT, font_size, 0.62)
    local time_width = get_render_text_width(font, INITIAL_TIME_TEXT, font_size, 0.58)
    local time_offset = label_width + gap
    local needed_width = time_offset + time_width
    local max_width = screen_x - SCREEN_PADDING * 2.0

    while needed_width > max_width and font_size > MIN_FONT_SIZE do
        font_size = font_size - 1.0
        label_width = get_render_text_width(font, LABEL_TEXT, font_size, 0.62)
        time_width = get_render_text_width(font, INITIAL_TIME_TEXT, font_size, 0.58)
        time_offset = label_width + gap
        needed_width = time_offset + time_width
    end

    return needed_width, font_size, time_offset
end

local function get_default_overlay_pos(screen_x, screen_y, overlay_width, font_size)
    local x = (screen_x - overlay_width) * 0.5
    local bottom_offset = math.max(18.0, screen_y * BOTTOM_OFFSET_RATIO)
    local y = screen_y - bottom_offset - font_size

    x = clamp(x, SCREEN_PADDING, screen_x - SCREEN_PADDING - overlay_width)
    y = clamp(y, SCREEN_PADDING, screen_y - SCREEN_PADDING - font_size)

    return x, y
end

local function get_overlay_metrics(screen_x, screen_y, font)
    local overlay_width, font_size, time_offset = get_overlay_size(screen_x, screen_y, font)
    local x, y

    if config.pos_x >= 0 and config.pos_y >= 0 then
        x = clamp(config.pos_x, SCREEN_PADDING, screen_x - SCREEN_PADDING - overlay_width)
        y = clamp(config.pos_y, SCREEN_PADDING, screen_y - SCREEN_PADDING - font_size)
    else
        x, y = get_default_overlay_pos(screen_x, screen_y, overlay_width, font_size)
    end

    return x, x + time_offset, y, font_size, overlay_width
end

local function color_to_u32(color)
    return imgui.ColorConvertFloat4ToU32(color)
end

local function ensure_config_dir()
    if not doesDirectoryExist(CONFIG_DIR) then
        createDirectory(CONFIG_DIR)
    end
end

local function save_config()
    ensure_config_dir()

    local file = io.open(CONFIG_PATH, 'w')
    if file == nil then
        return
    end

    file:write('[window]\n')
    file:write('pos_x=' .. tostring(config.pos_x) .. '\n')
    file:write('pos_y=' .. tostring(config.pos_y) .. '\n')
    file:close()
end

local function load_config()
    ensure_config_dir()

    local file = io.open(CONFIG_PATH, 'r')
    if file == nil then
        save_config()
        return
    end

    local section = ''
    for line in file:lines() do
        line = line:match('^%s*(.-)%s*$')
        local next_section = line:match('^%[(.+)%]$')
        if next_section ~= nil then
            section = next_section
        else
            local key, value = line:match('^([%w_]+)=(.*)$')
            if section == 'window' and key == 'pos_x' then
                config.pos_x = tonumber(value) or -1
            elseif section == 'window' and key == 'pos_y' then
                config.pos_y = tonumber(value) or -1
            end
        end
    end

    file:close()
end

local function save_position_if_changed(x, y)
    if math.abs(config.pos_x - x) < 0.5 and math.abs(config.pos_y - y) < 0.5 then
        return
    end

    config.pos_x = x
    config.pos_y = y

    local now = os.clock()
    if now - last_config_save_at >= 0.25 then
        save_config()
        last_config_save_at = now
    end
end

local function draw_text(draw_list, font, font_size, x, y, color, text)
    local outline_color = color_to_u32(OUTLINE_COLOR)
    local text_color = color_to_u32(color)
    local outline_offset = clamp(font_size * 0.060, 1.35, MAX_OUTLINE_OFFSET)

    draw_list:AddTextFontPtr(font, font_size, imgui.ImVec2(x - outline_offset, y), outline_color, text)
    draw_list:AddTextFontPtr(font, font_size, imgui.ImVec2(x + outline_offset, y), outline_color, text)
    draw_list:AddTextFontPtr(font, font_size, imgui.ImVec2(x, y - outline_offset), outline_color, text)
    draw_list:AddTextFontPtr(font, font_size, imgui.ImVec2(x, y + outline_offset), outline_color, text)
    draw_list:AddTextFontPtr(font, font_size, imgui.ImVec2(x, y), text_color, text)
end

local function get_time_text()
    local timestamp = os.time() + server_time_offset
    if timestamp ~= cached_second then
        cached_second = timestamp
        cached_time_text = os.date('%H:%M:%S', timestamp)
    end

    return cached_time_text
end

local function normalize_dialog_text(text)
    return tostring(text or ''):gsub('{......}', '')
end

local function is_valid_datetime(datetime)
    if type(datetime.year) ~= 'number'
        or type(datetime.month) ~= 'number'
        or type(datetime.day) ~= 'number'
        or type(datetime.hour) ~= 'number'
        or type(datetime.min) ~= 'number'
        or type(datetime.sec) ~= 'number' then
        return false
    end

    local is_time_valid, timestamp = pcall(os.time, datetime)
    if not is_time_valid or type(timestamp) ~= 'number' then
        return false
    end

    local normalized = os.date('*t', timestamp)

    return normalized.year == datetime.year
        and normalized.month == datetime.month
        and normalized.day == datetime.day
        and normalized.hour == datetime.hour
        and normalized.min == datetime.min
        and normalized.sec == datetime.sec
end

local function parse_server_timestamp(text)
    if type(text) ~= 'string' or not text:find(DIALOG_TIME_MARKER, 1, true) then
        return nil
    end

    local normalized = normalize_dialog_text(text)
    local day, month, year = normalized:match(DIALOG_DATE_LABEL .. '%s*(%d+):(%d+):(%d+)')
    local hour, minute, second = normalized:match(DIALOG_TIME_LABEL .. '%s*(%d+):(%d+):(%d+)')

    if not day or not hour then
        return nil
    end

    local datetime = {
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(minute),
        sec = tonumber(second)
    }

    if not is_valid_datetime(datetime) then
        return nil
    end

    return os.time(datetime)
end

local function update_server_time_offset(text)
    local server_timestamp = parse_server_timestamp(text)
    if server_timestamp == nil then
        return
    end

    server_time_offset = server_timestamp - os.time()
    cached_second = -1
end

local function draw_server_time()
    local screen_x, screen_y = getScreenResolution()
    local draw_list = imgui.GetForegroundDrawList()
    local font = imgui.GetFont()
    local label_x, time_x, y, font_size = get_overlay_metrics(screen_x, screen_y, font)

    draw_text(draw_list, font, font_size, label_x, y, LABEL_COLOR, LABEL_TEXT)
    draw_text(draw_list, font, font_size, time_x, y, TIME_COLOR, get_time_text())
end

local function get_position_editor_window_metrics(screen_x, screen_y, font)
    local label_x, time_x, y, font_size, overlay_width = get_overlay_metrics(screen_x, screen_y, font)
    local scale = clamp(math.min(screen_x / BASE_SCREEN_WIDTH, screen_y / BASE_SCREEN_HEIGHT), 0.75, 2.35)
    local padding_x = clamp(POSITION_EDITOR_PADDING_X * scale, 9.0, 22.0)
    local padding_y = clamp(POSITION_EDITOR_PADDING_Y * scale, 6.0, 18.0)
    local window_width = overlay_width + padding_x * 2.0
    local window_height = font_size + padding_y * 2.0
    local window_x = clamp(label_x - padding_x, 0.0, math.max(0.0, screen_x - window_width))
    local window_y = clamp(y - padding_y, 0.0, math.max(0.0, screen_y - window_height))

    return {
        label_x = label_x,
        time_x = time_x,
        y = y,
        font_size = font_size,
        padding_x = padding_x,
        padding_y = padding_y,
        window_x = window_x,
        window_y = window_y,
        window_width = window_width,
        window_height = window_height
    }
end

local function prepare_position_editor()
    local screen_x, screen_y = getScreenResolution()

    if screen_x <= 0 or screen_y <= 0 then
        return false
    end

    local font = imgui.GetFont()
    local metrics = get_position_editor_window_metrics(screen_x, screen_y, font)

    pending_editor_window_x = metrics.window_x
    pending_editor_window_y = metrics.window_y
    skip_position_save_once = true

    return true
end

local function is_pending_editor_position_applied(pos)
    return pending_editor_window_x < 0
        or pending_editor_window_y < 0
        or (math.abs(pos.x - pending_editor_window_x) < 1.0
            and math.abs(pos.y - pending_editor_window_y) < 1.0)
end

local function apply_pending_editor_position(pos)
    if is_pending_editor_position_applied(pos) then
        return pos
    end

    if imgui.SetWindowPos ~= nil then
        local is_set, _ = pcall(imgui.SetWindowPos, imgui.ImVec2(pending_editor_window_x, pending_editor_window_y))
        if is_set then
            return imgui.GetWindowPos()
        end
    end

    return pos
end

local function draw_position_editor()
    local screen_x, screen_y = getScreenResolution()

    if screen_x <= 0 or screen_y <= 0 then
        return
    end

    local font = imgui.GetFont()
    local metrics = get_position_editor_window_metrics(screen_x, screen_y, font)

    if pending_editor_window_x >= 0 and pending_editor_window_y >= 0 then
        imgui.SetNextWindowPos(imgui.ImVec2(pending_editor_window_x, pending_editor_window_y), imgui.Cond.Always)
    end

    imgui.SetNextWindowSize(imgui.ImVec2(metrics.window_width, metrics.window_height), imgui.Cond.Always)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
    imgui.PushStyleColor(imgui.Col.WindowBg, POSITION_EDITOR_BG_COLOR)

    local flags = bit.bor(
        imgui.WindowFlags.NoTitleBar,
        imgui.WindowFlags.NoResize,
        imgui.WindowFlags.NoScrollbar,
        imgui.WindowFlags.NoScrollWithMouse,
        imgui.WindowFlags.NoCollapse,
        imgui.WindowFlags.NoSavedSettings
    )

    edit_window_state[0] = true
    if imgui.Begin('##stimepos', edit_window_state, flags) then
        local pos = apply_pending_editor_position(imgui.GetWindowPos())
        local text_x = pos.x + metrics.padding_x
        local text_y = pos.y + metrics.padding_y
        local edit_draw_list = imgui.GetWindowDrawList()

        draw_text(edit_draw_list, font, metrics.font_size, text_x, text_y, LABEL_COLOR, LABEL_TEXT)
        draw_text(edit_draw_list, font, metrics.font_size, text_x + (metrics.time_x - metrics.label_x), text_y, TIME_COLOR, get_time_text())

        if not is_pending_editor_position_applied(pos) then
            skip_position_save_once = true
        elseif skip_position_save_once then
            skip_position_save_once = false
            pending_editor_window_x = -1
            pending_editor_window_y = -1
        else
            save_position_if_changed(text_x, text_y)
        end

        imgui.End()
    end

    imgui.PopStyleColor()
    imgui.PopStyleVar()
end

local function set_position_edit_mode(enabled)
    if enabled then
        prepare_position_editor()
    else
        pending_editor_window_x = -1
        pending_editor_window_y = -1
        skip_position_save_once = false
    end

    is_position_edit_mode = enabled
    edit_window_state[0] = enabled
    overlay_frame.HideCursor = not enabled
    overlay_frame.LockPlayer = enabled

    if not enabled then
        save_config()
    end
end

local function reset_overlay_position()
    config.pos_x = -1
    config.pos_y = -1

    if is_position_edit_mode then
        set_position_edit_mode(false)
    else
        save_config()
    end
end

local function handle_position_command(params)
    local normalized_params = tostring(params or ''):match('^%s*(.-)%s*$')

    if normalized_params == '0' then
        reset_overlay_position()
        return
    end

    set_position_edit_mode(not is_position_edit_mode)
end

overlay_frame = imgui.OnFrame(function()
    return is_samp_ready
end, function()
    if is_position_edit_mode then
        draw_position_editor()
    else
        draw_server_time()
    end
end)

overlay_frame.HideCursor = true

function sampev.onShowDialog(dialog_id, style, title, button1, button2, text)
    update_server_time_offset(text)
end

function main()
    repeat
        wait(100)
    until isSampAvailable()

    load_config()
    sampRegisterChatCommand('stimepos', handle_position_command)

    is_samp_ready = true

    while true do
        wait(500)
    end
end
