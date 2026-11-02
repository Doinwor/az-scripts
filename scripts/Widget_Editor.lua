script_name('Widget Editor')
script_version('1.0')
script_version_number(1)
script_author('Radare (t.me/ryderinc)')
script_description('Widget Editor')

local ffi = require("ffi")
local imgui = require("mimgui")
local jsoncfg = require("jsoncfg")
local memory = require("memory")
local widgets = require("widgets")

local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local settingsWindow = new.bool(false)
local initialPositions = {}
local min_x, min_y, max_x, max_y = -500, -300, getScreenResolution() 
local widgetPairs = {{WIDGET_ENTER_TARGETING, WIDGET_EXIT_TARGETING, WIDGET_ATTACK}, {WIDGET_MISSION_START_VIGILANTE, WIDGET_MISSION_CANCEL_VIGILANTE, WIDGET_MISSION_START, WIDGET_MISSION_CANCEL}, {WIDGET_HANDBRAKE, WIDGET_AIR_GUN}, {WIDGET_BUTTON_SPRINT, WIDGET_BUTTON_SWIM}, {WIDGET_SPRINT, WIDGET_BASKETBALL_JUMP}}

local widgetsConfig = jsoncfg.load({
    positions = {}
})

local editorSettings = {
    isEnabled = false,
    currentWidget = NUM_WIDGETS,
    currentWidgetSize = NUM_WIDGETS,
    initial_x = 0.0,
    initial_y = 0.0,
    initial_scale_x = 0.0,
    initial_scale_y = 0.0,
    start_x = 0.0,
    start_y = 0.0,
    start_scale_x = 0.0,
    start_scale_y = 0.0,
    saved_x = 0.0,
    saved_y = 0.0,
    saved_scale_x = 0.0,
    saved_scale_y = 0.0
}

local min_x, max_x = 0, 640
local min_y, max_y = 0, 448
local min_scale_x, max_scale_x = 20, 640
local min_scale_y, max_scale_y = 20, 448

local font = renderCreateFont("Arial", 12*MONET_DPI_SCALE, 0)

local widgetNames = {
    [0x0] = "WIDGET_POSITION_ENTER_CAR",
    [0x1] = "WIDGET_POSITION_TARGETING_AND_ATTACK",
    [0x2] = "WIDGET_POSITION_ACCELERATE",
    [0x3] = "WIDGET_POSITION_BRAKE",
    [0x4] = "WIDGET_POSITION_HANDBRAKE_AND_AIR_SHOOT",
    [0x5] = "WIDGET_POSITION_VEHICLE_STEER_LEFT",
    [0x6] = "WIDGET_POSITION_VEHICLE_STEER_RIGHT",
    [0x7] = "WIDGET_POSITION_HORN",
    [0x8] = "WIDGET_POSITION_PHONE",
    [0x9] = "WIDGET_POSITION_GIFT",
    [0xA] = "WIDGET_POSITION_KISS",
    [0xB] = "WIDGET_POSITION_CAR_SHOOT",
    [0xC] = "WIDGET_POSITION_HYDRAULICS",
    [0xD] = "WIDGET_POSITION_AUTO_HYDRAULICS",
    [0xE] = "WIDGET_POSITION_DROP_CRANE",
    [0xF] = "WIDGET_POSITION_DROP_ITEM",
    [0x10] = "WIDGET_POSITION_VEHICLE_SHOOT_LEFT",
    [0x11] = "WIDGET_POSITION_VEHICLE_SHOOT_RIGHT",
    [0x12] = "WIDGET_POSITION_CAM_TOGGLE",
    [0x13] = "WIDGET_POSITION_TARGETING_AND_ATTACK",
    [0x14] = "WIDGET_POSITION_TARGETING_AND_ATTACK",
    [0x15] = "WIDGET_POSITION_VC_SHOOT",
    [0x16] = "WIDGET_POSITION_VC_SHOOT_ALT",
    [0x17] = "WIDGET_POSITION_HANDBRAKE_AND_AIR_SHOOT",
    [0x18] = "WIDGET_POSITION_ROCKET",
    [0x19] = "WIDGET_POSITION_VEHICLE_BOMB",
    [0x1A] = "WIDGET_POSITION_VEHICLE_TURRET_LEFT",
    [0x1B] = "WIDGET_POSITION_VEHICLE_TURRET_RIGHT",
    [0x1C] = "WIDGET_POSITION_PURCHASE",
    [0x1D] = "WIDGET_POSITION_SWAP_WEAPONS",
    [0x1E] = "WIDGET_POSITION_NITRO",
    [0x1F] = "WIDGET_POSITION_BUTTON_SPRINT_AND_SWIM",
    [0x20] = "WIDGET_POSITION_BUTTON_CROUCH",
    [0x21] = "WIDGET_POSITION_BUTTON_DIVE",
    [0x22] = "WIDGET_POSITION_BUTTON_SPRINT_AND_SWIM",
    [0x23] = "WIDGET_POSITION_POOL_ENGLISH",
    [0x24] = "WIDGET_POSITION_POOL_BALL_IN_HAND",
    [0x25] = "WIDGET_POSITION_ARCADE_BUTTON",
    [0x26] = "WIDGET_POSITION_ARCADE_POWER_OFF",
    [0x27] = "WIDGET_POSITION_ARCADE_RESET",
    [0x28] = "WIDGET_POSITION_ARCADE_JOYSTICK",
    [0x29] = "WIDGET_POSITION_SKIP_CUTSCENE",
    [0x2A] = "WIDGET_POSITION_TRAIN_NEXT_STATION",
    [0x2B] = "WIDGET_POSITION_TAP_METER_BUTTON",
    [0x2C] = "WIDGET_POSITION_CRANE_UP",
    [0x2D] = "WIDGET_POSITION_CRANE_DOWN",
    [0x2E] = "WIDGET_POSITION_HELICOPTER_MAGNET_UP",
    [0x2F] = "WIDGET_POSITION_HELICOPTER_MAGNET_DOWN",
    [0x30] = "WIDGET_POSITION_GYM_EASIER",
    [0x31] = "WIDGET_POSITION_GYM_HARDER",
    [0x32] = "WIDGET_POSITION_ZOOM_IN",
    [0x33] = "WIDGET_POSITION_ZOOM_OUT",
    [0x34] = "WIDGET_POSITION_RACE_LEFT",
    [0x35] = "WIDGET_POSITION_RACE_RIGHT",
    [0x36] = "WIDGET_POSITION_STORE_ACCEPT",
    [0x37] = "WIDGET_POSITION_STORE_CANCEL",
    [0x38] = "WIDGET_POSITION_STORE_BACK",
    [0x39] = "WIDGET_POSITION_STORE_BUY",
    [0x3A] = "WIDGET_POSITION_ROULETTE_UP",
    [0x3B] = "WIDGET_POSITION_ROULETTE_DOWN",
    [0x3C] = "WIDGET_POSITION_ROULETTE_LEFT",
    [0x3D] = "WIDGET_POSITION_ROULETTE_RIGHT",
    [0x3E] = "WIDGET_POSITION_PLACE_BET",
    [0x3F] = "WIDGET_POSITION_REMOVE_BET",
    [0x40] = "WIDGET_POSITION_STEERING_SELECTION",
    [0x41] = "WIDGET_POSITION_TOUCH_LAYOUT_SELECTION",
    [0x42] = "WIDGET_POSITION_GRAB",
    [0x43] = "WIDGET_POSITION_MAGNET",
    [0x44] = "WIDGET_POSITION_STINGER",
    [0x45] = "WIDGET_POSITION_MISSION_START_AND_MISSION_CANCEL",
    [0x46] = "WIDGET_POSITION_MISSION_START_AND_MISSION_CANCEL",
    [0x47] = "WIDGET_POSITION_MISSION_START_AND_MISSION_CANCEL",
    [0x48] = "WIDGET_POSITION_MISSION_START_AND_MISSION_CANCEL",
    [0x49] = "WIDGET_POSITION_MINIGAME_START",
    [0x4A] = "WIDGET_POSITION_MINIGAME_CANCEL",
    [0x4B] = "WIDGET_POSITION_SCHOOL_EXIT",
    [0x4C] = "WIDGET_POSITION_SCHOOL_LEFT",
    [0x4D] = "WIDGET_POSITION_SCHOOL_RIGHT",
    [0x4E] = "WIDGET_POSITION_SCHOOL_START",
    [0x4F] = "WIDGET_POSITION_SCHOOL_CONTINUE",
    [0x50] = "WIDGET_POSITION_SCHOOL_TITLE_BACKGROUND",
    [0x51] = "WIDGET_POSITION_SCHOOL_AWARD",
    [0x52] = "WIDGET_POSITION_SCHOOL_RESULTS",
    [0x53] = "WIDGET_POSITION_SCHOOL_FRAME_ONE",
    [0x54] = "WIDGET_POSITION_SCHOOL_FRAME_TWO",
    [0x55] = "WIDGET_POSITION_SCHOOL_FRAME_THREE",
    [0x56] = "WIDGET_POSITION_SCHOOL_FRAME_FOUR",
    [0x57] = "WIDGET_POSITION_BASKETBALL_SHOOT",
    [0x58] = "WIDGET_POSITION_BASKETBALL_TRICK",
    [0x59] = "WIDGET_POSITION_GAMBLING_QUIT",
    [0x5A] = "WIDGET_POSITION_GAMBLING_CONTINUE",
    [0x5B] = "WIDGET_POSITION_BLACK_JACK_SPLIT",
    [0x5C] = "WIDGET_POSITION_BLACK_JACK_DOUBLE",
    [0x5D] = "WIDGET_POSITION_BLACK_JACK_HIT",
    [0x5E] = "WIDGET_POSITION_BLACK_JACK_STAND",
    [0x5F] = "WIDGET_POSITION_BLACK_JACK_REGION",
    [0x60] = "WIDGET_POSITION_MENU_SLIDER",
    [0x61] = "WIDGET_POSITION_RHYTHM_UP",
    [0x62] = "WIDGET_POSITION_RHYTHM_DOWN",
    [0x63] = "WIDGET_POSITION_RHYTHM_LEFT",
    [0x64] = "WIDGET_POSITION_RHYTHM_RIGHT",
    [0x65] = "WIDGET_POSITION_RHYTHM_SELECT",
    [0x66] = "WIDGET_POSITION_RHYTHM_EXIT",
    [0x67] = "WIDGET_POSITION_PLAYER_SCORE",
    [0x68] = "WIDGET_POSITION_OPPOSITION_SCORE",
    [0x69] = "WIDGET_POSITION_GANG_REGION",
    [0x6A] = "WIDGET_POSITION_GANG_RECRUIT",
    [0x6B] = "WIDGET_POSITION_GANG_IGNORE",
    [0x6C] = "WIDGET_POSITION_GANG_FOLLOW",
    [0x6D] = "WIDGET_POSITION_GANG_HOLD_POSITION",
    [0x6E] = "WIDGET_POSITION_POSITIVE",
    [0x6F] = "WIDGET_POSITION_NEGATIVE",
    [0x70] = "WIDGET_POSITION_COLOR_PICKER",
    [0x71] = "WIDGET_POSITION_VEHICLE_SLIDER_LEFT_BUTTON",
    [0x72] = "WIDGET_POSITION_VEHICLE_SLIDER_RIGHT_BUTTON",
    [0x73] = "WIDGET_POSITION_WOF_FIRST_BET",
    [0x74] = "WIDGET_POSITION_WOF_SECOND_BET",
    [0x75] = "WIDGET_POSITION_WOF_THIRD_BET",
    [0x76] = "WIDGET_POSITION_WOF_FOURTH_BET",
    [0x77] = "WIDGET_POSITION_WOF_FIFTH_BET",
    [0x78] = "WIDGET_POSITION_WOF_SIXTH_BET",
    [0x79] = "WIDGET_POSITION_VIDEO_POKER_ADD_COIN",
    [0x7A] = "WIDGET_POSITION_VIDEO_POKER_REMOVE_COIN",
    [0x7B] = "WIDGET_POSITION_VIDEO_POKER_DEAL",
    [0x7C] = "WIDGET_POSITION_VIDEO_POKER_HOLD_FIRST_CARD",
    [0x7D] = "WIDGET_POSITION_VIDEO_POKER_HOLD_SECOND_CARD",
    [0x7E] = "WIDGET_POSITION_VIDEO_POKER_HOLD_THIRD_CARD",
    [0x7F] = "WIDGET_POSITION_VIDEO_POKER_HOLD_FOURTH_CARD",
    [0x80] = "WIDGET_POSITION_VIDEO_POKER_HOLD_FIFTH_CARD",
    [0x81] = "WIDGET_POSITION_VIDEO_POKER_HOLD_FIRST_CARD_REGION",
    [0x82] = "WIDGET_POSITION_VIDEO_POKER_HOLD_SECOND_CARD_REGION",
    [0x83] = "WIDGET_POSITION_VIDEO_POKER_HOLD_THIRD_CARD_REGION",
    [0x84] = "WIDGET_POSITION_VIDEO_POKER_HOLD_FOURTH_CARD_REGION",
    [0x85] = "WIDGET_POSITION_VIDEO_POKER_HOLD_FIFTH_CARD_REGION",
    [0x86] = "WIDGET_POSITION_VIDEO_POKER_EXIT",
    [0x87] = "WIDGET_POSITION_ITB_FIRST_HORSE",
    [0x88] = "WIDGET_POSITION_ITB_SECOND_HORSE",
    [0x89] = "WIDGET_POSITION_ITB_THIRD_HORSE",
    [0x8A] = "WIDGET_POSITION_ITB_FOURTH_HORSE",
    [0x8B] = "WIDGET_POSITION_ITB_FIFTH_HORSE",
    [0x8C] = "WIDGET_POSITION_ITB_FIRST_BET",
    [0x8D] = "WIDGET_POSITION_ITB_SECOND_BET",
    [0x8E] = "WIDGET_POSITION_ITB_THIRD_BET",
    [0x8F] = "WIDGET_POSITION_ITB_FOURTH_BET",
    [0x90] = "WIDGET_POSITION_ITB_FIFTH_BET",
    [0x91] = "WIDGET_POSITION_ITB_SIXTH_BET",
    [0x92] = "WIDGET_POSITION_ITB_SEVENTH_BET",
    [0x93] = "WIDGET_POSITION_ITB_EIGHTH_BET",
    [0x94] = "WIDGET_POSITION_ITB_PLACE_BET",
    [0x95] = "WIDGET_POSITION_ITB_EXIT",
    [0x96] = "WIDGET_POSITION_MAP",
    [0x97] = "WIDGET_POSITION_WEAPON_SLOT_CHEATS",
    [0x98] = "WIDGET_POSITION_CAR_CHEATS",
    [0x99] = "WIDGET_POSITION_MISSION_SKIP",
    [0x9A] = "WIDGET_POSITION_CHEATS",
    [0x9B] = "WIDGET_POSITION_CHEAT_MENU",
    [0x9C] = "WIDGET_POSITION_SHOP",
    [0x9D] = "WIDGET_POSITION_RESPONSE",
    [0x9E] = "WIDGET_POSITION_DRIVE_HYBRID",
    [0x9F] = "WIDGET_POSITION_REPLAY",
    [0xA0] = "WIDGET_POSITION_PLAYER_INFO",
    [0xA1] = "WIDGET_POSITION_RADAR",
    [0xA2] = "WIDGET_POSITION_HELP_TEXT",
    [0xA3] = "WIDGET_POSITION_TAP_METER",
    [0xA4] = "WIDGET_POSITION_THUMB_CIRCLE",
    [0xA5] = "WIDGET_POSITION_MENU",
    [0xA6] = "WIDGET_POSITION_SWIPE_RADIO",
    [0xA7] = "WIDGET_POSITION_PED_MOVE",
    [0xA8] = "WIDGET_POSITION_SPRINT_AND_BASKETBALL_JUMP",
    [0xA9] = "WIDGET_POSITION_SPRINT_AND_BASKETBALL_JUMP",
    [0xAA] = "WIDGET_POSITION_SHOOT_LOOK",
    [0xAB] = "WIDGET_POSITION_VEHICLE_LANECORRECTION",
    [0xAC] = "WIDGET_POSITION_VEHICLE_STEER_ANALOG",
    [0xAD] = "WIDGET_POSITION_VEHICLE_FLICK",
    [0xAE] = "WIDGET_POSITION_CHEATS_RECT",
    [0xAF] = "WIDGET_POSITION_LOOK",
    [0xB0] = "WIDGET_POSITION_MISSION_TIMERS",
    [0xB1] = "WIDGET_POSITION_RACING",
    [0xB2] = "WIDGET_POSITION_RACE_RESULTS",
    [0xB3] = "WIDGET_POSITION_HORSE_RESULTS",
    [0xB4] = "WIDGET_POSITION_WAGER",
    [0xB5] = "WIDGET_POSITION_POOL",
    [0xB6] = "WIDGET_POSITION_POKER_PAYOUT",
    [0xB7] = "WIDGET_POSITION_VITAL_STATS",
    [0xB8] = "WIDGET_POSITION_ROULETTE_SPIN",
    [0xB9] = "WIDGET_POSITION_AIRPORT_LEFT",
    [0xBA] = "WIDGET_POSITION_AIRPORT_RIGHT",
    [0xBB] = "WIDGET_POSITION_PARACHUTE",
    [0xBC] = "WIDGET_POSITION_TATTOO_PREVIEW",
    [0xBD] = "WIDGET_POSITION_SAVE_NOTIFICATION",
    [0xBE] = "NUM_WIDGETS",
}


function main()
    wait(3000)

    local fixPositions = {}
    for k, v in pairs(widgetsConfig.positions) do
        fixPositions[tostring(k)] = v
    end
    widgetsConfig.positions = fixPositions

    for i = 0, NUM_WIDGETS-1 do
        local pos_x, pos_y, scale_x, scale_y = getWidgetPosition(i)
        initialPositions[i] = {x = pos_x, y = pos_y, w = scale_x, h = scale_y}
    end
    for id, positions in pairs(widgetsConfig.positions) do
        if positions.set then
            setWidgetPosition(tonumber(id) , positions.x, positions.y, positions.w, positions.h)
        end
    end
    sampRegisterChatCommand("adjustable", function() settingsWindow[0] = not settingsWindow[0] end)
    lua_thread.create(renderThread)
	wait(-1)
end

function renderThread()
    while true do
        wait(0)
        local sw, sh = getScreenResolution()
        if editorSettings.isEnabled then
            for i = 0, NUM_WIDGETS-1 do
                if isEnabled(i) then
                    local pos_x, pos_y, scale_x, scale_y = getWidgetTouchZone(i)
                    renderDrawBoxWithBorder(pos_x, pos_y, scale_x, scale_y, 0x00FFFFFF, 3, 0x90000000)
                end
            end
            if editorSettings.currentWidget ~= NUM_WIDGETS then
                renderFontDrawText(font, widgetNames[editorSettings.currentWidget], sw/2-renderGetFontDrawTextLength(font, widgetNames[editorSettings.currentWidget])/2, sh-renderGetFontDrawHeight(font)-10, 0xFFFFFFFF)
            end
        end
    end
end


function onTouch(type, id, x, y)
    if type == 2 and editorSettings.isEnabled then
        if id == 0 then
            editorSettings.start_x, editorSettings.start_y = x, y
            for i = 0, NUM_WIDGETS-1 do
                if isEnabled(i) then
                    local pos_x, pos_y, scale_x, scale_y = getWidgetTouchZone(i)
                    if x >= pos_x and x <= pos_x + scale_x and y >= pos_y and y <= pos_y + scale_y then
                        editorSettings.currentWidget = i 
                        editorSettings.initial_x, editorSettings.initial_y, editorSettings.initial_scale_x, editorSettings.initial_scale_y = getWidgetPosition(i)
                        editorSettings.saved_scale_x, editorSettings.saved_scale_y = editorSettings.initial_scale_x, editorSettings.initial_scale_y
                        break 
                    end
                end
            end
        end
        if editorSettings.currentWidget ~= NUM_WIDGETS then
            if id == 1 then
                local wx, wy, ww, wh = getWidgetPosition(editorSettings.currentWidget)
                editorSettings.start_scale_x, editorSettings.start_scale_y = x, y
                editorSettings.initial_scale_x, editorSettings.initial_scale_y = ww, wh
                editorSettings.currentWidgetSize = editorSettings.currentWidget
            elseif id == 2 then
                editorSettings.saved_x = editorSettings.initial_x
                editorSettings.saved_y = editorSettings.initial_y
                editorSettings.saved_scale_x = editorSettings.initial_scale_x
                editorSettings.saved_scale_y = editorSettings.initial_scale_y
                setWidgetPosition(editorSettings.currentWidget, editorSettings.saved_x, editorSettings.saved_y, editorSettings.saved_scale_x, editorSettings.saved_scale_y)
                editorSettings.currentWidgetSize = NUM_WIDGETS
                editorSettings.currentWidget = NUM_WIDGETS
            end
        end
    end
    if editorSettings.isEnabled and editorSettings.currentWidget ~= NUM_WIDGETS then
        local sw, sh = getScreenResolution()
        if id == 0 then
            local new_x = editorSettings.initial_x - (editorSettings.start_x - x) * (640 / sw)
            local new_y = editorSettings.initial_y - (editorSettings.start_y - y) * (448 / sh)

            if new_x >= min_x and new_x <= max_x then
                editorSettings.saved_x = new_x
            end
            if new_y >= min_y and new_y <= max_y then
                editorSettings.saved_y = new_y
            end
        elseif id == 1 and editorSettings.currentWidgetSize ~= NUM_WIDGETS then
            local new_scale_x = editorSettings.initial_scale_x + (x - editorSettings.start_scale_x) * (640 / sw)
            local new_scale_y = editorSettings.initial_scale_y + (y - editorSettings.start_scale_y) * (448 / sh)

            if new_scale_x >= min_scale_x and new_scale_x <= max_scale_x then
                editorSettings.saved_scale_x = new_scale_x
            end
            if new_scale_y >= min_scale_y and new_scale_y <= max_scale_y then
                editorSettings.saved_scale_y = new_scale_y
            end
        end

        if type == 1 then
            changeWidgetPosition(editorSettings.currentWidget, editorSettings.saved_x, editorSettings.saved_y, editorSettings.saved_scale_x, editorSettings.saved_scale_y)
            if id == 0 then
                widgetsConfig.positions[tostring(editorSettings.currentWidget)] = {x = editorSettings.saved_x, y = editorSettings.saved_y, w = editorSettings.saved_scale_x, h = editorSettings.saved_scale_y, set = true}
                for _, widgetId in ipairs(getWidgetPair(editorSettings.currentWidget)) do 
                    widgetsConfig.positions[tostring(widgetId)] = {x = editorSettings.saved_x, y = editorSettings.saved_y, w = editorSettings.saved_scale_x, h = editorSettings.saved_scale_y, set = true}
                end
                jsoncfg.save(widgetsConfig)
                editorSettings.currentWidget = NUM_WIDGETS
            elseif id == 1 then
                editorSettings.currentWidgetSize = NUM_WIDGETS
            end
        elseif type == 3 then
            changeWidgetPosition(editorSettings.currentWidget, editorSettings.saved_x, editorSettings.saved_y, editorSettings.saved_scale_x, editorSettings.saved_scale_y)
        end
        return false
    end
end

function getWidgetPair(id)
    local result = {}
    for _, pair in ipairs(widgetPairs) do
        for _, widget in ipairs(pair) do
            if widget == id then
                for _, widgetId in ipairs(pair) do
                    if widgetId ~= id then
                        table.insert(result, widgetId)
                    end
                end
            end
        end
    end
    return result
end

function changeWidgetPosition(id, x, y, w, h)
    setWidgetPosition(id, x, y, w, h)
    for _, widgetId in ipairs(getWidgetPair(id)) do 
        setWidgetPosition(widgetId, x, y, w, h)
    end
end


local currentLang = "en"

local lang = {
    en = {
        title = "Widget Editor",
        toggle_on  = "ENABLE EDITOR",
        toggle_off = "DISABLE EDITOR",
        reset = "RESET TO DEFAULTS",
        dump  = "EXPORT TO ADJUSTABLE.CFG",
        hint1 = "Enable editor and drag widget area to move it",
        hint2 = "Touch with second finger and drag to resize widget",
        hint3 = "Tap with third finger to undo current widget changes",
        lang_btn = "RU",
        status_on  = "ACTIVE",
        status_off = "INACTIVE",
    },
    ru = {
        title = "Редактор виджетов",
        toggle_on  = "ВКЛЮЧИТЬ РЕДАКТОР",
        toggle_off = "ВЫКЛЮЧИТЬ РЕДАКТОР",
        reset = "СБРОСИТЬ ДО СТАНДАРТНЫХ",
        dump  = "ЭКСПОРТ В ADJUSTABLE.CFG",
        hint1 = "Включите редактор и перемещайте виджет касанием его зоны",
        hint2 = "Коснитесь вторым пальцем и перетащите для изменения размера",
        hint3 = "Коснитесь третьим пальцем чтобы отменить изменение виджета",
        lang_btn = "EN",
        status_on  = "АКТИВЕН",
        status_off = "ВЫКЛЮЧЕН",
    }
}

local function T(key) return lang[currentLang][key] end

local COL = {
    bg          = imgui.ImVec4(0.08, 0.09, 0.12, 1.00),
    bg_dark     = imgui.ImVec4(0.05, 0.06, 0.08, 1.00),
    accent      = imgui.ImVec4(0.20, 0.60, 1.00, 1.00),
    accent_dim  = imgui.ImVec4(0.20, 0.60, 1.00, 0.15),
    accent_hov  = imgui.ImVec4(0.30, 0.70, 1.00, 1.00),
    accent_act  = imgui.ImVec4(0.10, 0.45, 0.85, 1.00),
    danger      = imgui.ImVec4(1.00, 0.30, 0.30, 1.00),
    danger_dim  = imgui.ImVec4(1.00, 0.30, 0.30, 0.15),
    danger_hov  = imgui.ImVec4(1.00, 0.45, 0.45, 1.00),
    danger_act  = imgui.ImVec4(0.85, 0.15, 0.15, 1.00),
    success     = imgui.ImVec4(0.20, 0.85, 0.50, 1.00),
    success_dim = imgui.ImVec4(0.20, 0.85, 0.50, 0.15),
    success_hov = imgui.ImVec4(0.30, 0.95, 0.60, 1.00),
    success_act = imgui.ImVec4(0.10, 0.65, 0.35, 1.00),
    export_col  = imgui.ImVec4(0.80, 0.55, 0.10, 1.00),
    export_dim  = imgui.ImVec4(0.80, 0.55, 0.10, 0.15),
    export_hov  = imgui.ImVec4(0.95, 0.68, 0.20, 1.00),
    export_act  = imgui.ImVec4(0.65, 0.42, 0.05, 1.00),
    text        = imgui.ImVec4(0.88, 0.90, 0.95, 1.00),
    text_dim    = imgui.ImVec4(0.50, 0.55, 0.65, 1.00),
    separator   = imgui.ImVec4(0.18, 0.22, 0.30, 1.00),
    hint_bg     = imgui.ImVec4(0.10, 0.12, 0.17, 1.00),
}

local WIN_W, WIN_H = 940, 370

local function pushBtn(fg, dim, hov, act)
    imgui.PushStyleColor(imgui.Col.Button,        dim)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, hov)
    imgui.PushStyleColor(imgui.Col.ButtonActive,  act)
end

local function popBtn()
    imgui.PopStyleColor(3)
end

local function hintRow(icon, text)
    imgui.PushStyleColor(imgui.Col.ChildBg, COL.hint_bg)
    imgui.BeginChild("##h"..icon, imgui.ImVec2(-1, 42), false)
        imgui.SetCursorPos(imgui.ImVec2(8, 8))
        imgui.PushStyleColor(imgui.Col.Text, COL.accent)
        imgui.Text(icon)
        imgui.PopStyleColor()
        imgui.SameLine()
        imgui.PushStyleColor(imgui.Col.Text, COL.text_dim)
        imgui.TextWrapped(text)
        imgui.PopStyleColor()
    imgui.EndChild()
    imgui.PopStyleColor()
    imgui.Dummy(imgui.ImVec2(0, 2))
end

imgui.OnFrame(
    function() return settingsWindow[0] end,
    function(player)
        imgui.PushStyleColor(imgui.Col.WindowBg,      COL.bg)
        imgui.PushStyleColor(imgui.Col.TitleBg,       COL.bg_dark)
        imgui.PushStyleColor(imgui.Col.TitleBgActive, COL.bg_dark)
        imgui.PushStyleColor(imgui.Col.Border,        COL.separator)
        imgui.PushStyleColor(imgui.Col.Text,          COL.text)
        imgui.PushStyleColor(imgui.Col.Separator,     COL.separator)

        local x, y = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(x / 2, y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(WIN_W, WIN_H), imgui.Cond.Always)

        imgui.Begin(T("title") .. "###WE", settingsWindow,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)

        local statusColor = editorSettings.isEnabled and COL.success or COL.text_dim
        imgui.PushStyleColor(imgui.Col.Text, statusColor)
        imgui.Text(editorSettings.isEnabled and T("status_on") or T("status_off"))
        imgui.PopStyleColor()

        imgui.SameLine()
        imgui.SetCursorPosX(WIN_W - 60)
        pushBtn(COL.accent, COL.accent_dim, COL.accent_hov, COL.accent_act)
        if imgui.Button(T("lang_btn"), imgui.ImVec2(38, 36)) then
            currentLang = (currentLang == "ru") and "en" or "ru"
        end
        popBtn()

        imgui.Separator()
        imgui.Dummy(imgui.ImVec2(0, 2))

        local btnW = (WIN_W - 50) / 2
        local btnH = 40

        if editorSettings.isEnabled then
            pushBtn(COL.danger, COL.danger_dim, COL.danger_hov, COL.danger_act)
        else
            pushBtn(COL.success, COL.success_dim, COL.success_hov, COL.success_act)
        end
        if imgui.Button(editorSettings.isEnabled and T("toggle_off") or T("toggle_on"), imgui.ImVec2(btnW, btnH)) then
            editorSettings.isEnabled = not editorSettings.isEnabled
        end
        popBtn()

        imgui.SameLine()

        pushBtn(COL.accent, COL.accent_dim, COL.accent_hov, COL.accent_act)
        if imgui.Button(T("reset"), imgui.ImVec2(btnW, btnH)) then
            for id, positions in ipairs(initialPositions) do
                setWidgetPosition(id, positions.x, positions.y, positions.w, positions.h)
            end
            widgetsConfig.positions = {}
            jsoncfg.save(widgetsConfig)
        end
        popBtn()

        imgui.Dummy(imgui.ImVec2(0, 4))

        pushBtn(COL.export_col, COL.export_dim, COL.export_hov, COL.export_act)
        if imgui.Button(T("dump"), imgui.ImVec2(-1, btnH)) then
            dumpToAdjustableCFG()
        end
        popBtn()

        imgui.Dummy(imgui.ImVec2(0, 4))
        imgui.Separator()
        imgui.Dummy(imgui.ImVec2(0, 4))

        hintRow("[~]", T("hint1"))
        hintRow("[+]", T("hint2"))
        hintRow("[x]", T("hint3"))

        imgui.End()
        imgui.PopStyleColor(6)
    end
)

function dumpToAdjustableCFG()
    local file = io.open(getGameDirectory().."/Adjustable.cfg", "w")
    if not file then
        print("Failed to open file for writing:", filename)
        return
    end

    file:write("; Dump generated from Widgets Edtor Script maded by t.me/ryderinc\n")
    for id, positions in pairs(widgetsConfig.positions) do
        if positions.set then
            file:write(string.format("PositionAndScale %d, %d, %d, %d ; %s\n", math.floor(positions.x), math.floor(positions.y), math.floor(positions.w), math.floor(positions.h), widgetNames[tonumber(id)]))
        end
    end
    file:close()
end


function onScriptTerminate(script, q)
    if script == thisScript() then
        for id, positions in ipairs(initialPositions) do
            setWidgetPosition(id, positions.x, positions.y, positions.w, positions.h)
        end
    end
end



local m_pWidgets = jit.arch == "arm" and memory.getuint32(MONET_GTASA_BASE + 0x67947C) or memory.getuint64(MONET_GTASA_BASE + 0x850910)

function getWidget(id)
    if jit.arch == "arm64" then
        return memory.getuint64(m_pWidgets + id * 8)
    else
        return memory.getuint32(m_pWidgets + id * 4)
    end
end

function setWidgetPosition(id, x, y, w, h)
    local widgetPtr = getWidget(id)
    if widgetPtr == 0 then
        return
    end

    memory.setfloat(widgetPtr + (jit.arch == "arm" and 12 or 24),  x, true)
    memory.setfloat(widgetPtr + (jit.arch == "arm" and 16 or 28), y, true)
    memory.setfloat(widgetPtr + (jit.arch == "arm" and 20 or 32), w, true)
    memory.setfloat(widgetPtr + (jit.arch == "arm" and 24 or 36), h, true)
end

function isEnabled(id)
    if id == WIDGET_LOOK then return false end
    local ptr = getWidget(id)
    if ptr == 0 then return false end
    return memory.getuint8(ptr + (jit.arch == "arm" and 78 or 90)) == 1
end


function getWidgetTouchZone(widgetId)
    local ptr = getWidget(widgetId)
    if ptr == 0 then return 0, 0, 0, 0 end
    local x1 = memory.getfloat(ptr + (jit.arch == "arm" and 32 or 44))
    local x2 = memory.getfloat(ptr + (jit.arch == "arm" and 40 or 52))
    local y1 = memory.getfloat(ptr + (jit.arch == "arm" and 44 or 56))
    local y2 = memory.getfloat(ptr + (jit.arch == "arm" and 36 or 48))
    return x1, y1, x2 - x1, y2 - y1
end

EXPORTS = {
   canToggle = function() return true end,
   getToggle = function() return settingsWindow[0] end,
   toggle = function() settingsWindow[0] = not settingsWindow[0] end
}