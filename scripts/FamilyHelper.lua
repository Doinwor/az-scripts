script_name("Family Helper")
script_description('Helper for Family management in Arizona RP')
script_author("Shinik_Pupckin")
script_version("4.0")

require('lib.moonloader')
require('encoding').default = 'CP1251'
local _u8 = require('encoding').UTF8
local ffi = require('ffi')
local sampev = require('samp.events')

-- –ö—ç—à –ø–æ–∑–∏—Ü–∏–π –∏–≥—Ä–æ–∫–æ–≤: –æ–±–Ω–æ–≤–ª—è–µ—Ç—Å—è —Å–æ–±—ã—Ç–∏–π–Ω–æ –∏–∑ onPlayerSync,
-- –∞ –Ω–µ –ø–µ—Ä–∏–æ–¥–∏—á–µ—Å–∫–∏–º —Å–∫–∞–Ω–æ–º. –ö–ª—é—á pid -> {x,y,z,t}.
_G.fh_player_positions = _G.fh_player_positions or {}
-- TTL –∫—ç—à–∞ –ø–æ–∑–∏—Ü–∏–π (—Å–µ–∫). –ó–∞–ø–∏—Å–∏ —Å—Ç–∞—Ä—à–µ —ç—Ç–æ–≥–æ –≤–æ–∑—Ä–∞—Å—Ç–∞ —Å—á–∏—Ç–∞—é—Ç—Å—è
-- —É—Å—Ç–∞—Ä–µ–≤—à–∏–º–∏ –∏ –Ω–µ —É—á–∞—Å—Ç–≤—É—é—Ç –≤ —Å–∫–∞–Ω–µ, –∞ —Ç–∞–∫–∂–µ –ø–æ–¥—á–∏—â–∞—é—Ç—Å—è —Ü–µ–ª–∏–∫–æ–º.
local FH_POS_TTL = 8
-- –ö–∞–∫ —á–∞—Å—Ç–æ –≤—ã–ø–æ–ª–Ω—è—Ç—å –ø–æ–ª–Ω—É—é –æ—á–∏—Å—Ç–∫—É —É—Å—Ç–∞—Ä–µ–≤—à–∏—Ö –∑–∞–ø–∏—Å–µ–π (—Å–µ–∫),
-- —á—Ç–æ–±—ã –Ω–µ —Ä–∞–∑—Ä–∞—Å—Ç–∞—Ç—å—Å—è –±–µ—Å–∫–æ–Ω–µ—á–Ω–æ, –¥–∞–∂–µ –µ—Å–ª–∏ –∏–≥—Ä–æ–∫ —É—à—ë–ª –∏–∑ —Ä–∞–¥–∏—É—Å–∞
-- —Å—Ç—Ä–∏–º–∞ –∏ –±–æ–ª—å—à–µ –Ω–µ —à–ª—ë—Ç onPlayerSync.
local FH_POS_CLEANUP_INTERVAL = 10
local _fh_last_pos_cleanup = 0

-- –ö—ç—à –≤—Ä–µ–º–µ–Ω–∏, –æ–±–Ω–æ–≤–ª—è–µ–º—ã–π –æ—Ç–¥–µ–ª—å–Ω—ã–º –ª—ë–≥–∫–∏–º –ø–æ—Ç–æ–∫–æ–º (—Å–º. –Ω–∏–∂–µ), –∞ –Ω–µ
-- –≤—ã–∑–æ–≤–æ–º os.time() –Ω–∞ –∫–∞–∂–¥—ã–π onPlayerSync. –í —Ç–æ–ª–ø–µ onPlayerSync –º–æ–∂–µ—Ç
-- –ø—Ä–∏–ª–µ—Ç–∞—Ç—å —Å–æ—Ç–Ω–∏ —Ä–∞–∑ –≤ —Å–µ–∫—É–Ω–¥—É –æ—Ç —Ä–∞–∑–Ω—ã—Ö –∏–≥—Ä–æ–∫–æ–≤ ‚Äî os.time() –Ω–∞ –∫–∞–∂–¥—ã–π
-- —Ç–∞–∫–æ–π –ø–∞–∫–µ—Ç —Å–∫–ª–∞–¥—ã–≤–∞–µ—Ç—Å—è –≤ –∑–∞–º–µ—Ç–Ω—ã–µ –Ω–∞–∫–ª–∞–¥–Ω—ã–µ —Ä–∞—Å—Ö–æ–¥—ã; –ø—Ä–∏ TTL=8 —Å–µ–∫
-- —Ä–∞–∑–±—Ä–æ—Å –≤ –¥–æ–ª–∏ —Å–µ–∫—É–Ω–¥—ã –∏–∑-–∑–∞ –∫—ç—à–∞ –Ω–µ –∫—Ä–∏—Ç–∏—á–µ–Ω –¥–ª—è —Ç–æ—á–Ω–æ—Å—Ç–∏ –æ—Ç—Å–µ–≤–∞.
_G.fh_cached_time = os.time()
lua_thread.create(function()
    while true do
        _G.fh_cached_time = os.time()
        wait(0)
    end
end)

-- –ë–µ–∑–æ–ø–∞—Å–Ω–∞—è —Ä–µ–≥–∏—Å—Ç—Ä–∞—Ü–∏—è: –µ—Å–ª–∏ –¥–æ –Ω–∞—Å —É–∂–µ –±—ã–ª –æ–±—Ä–∞–±–æ—Ç—á–∏–∫ onPlayerSync
-- (—Å–≤–æ–π –∏–ª–∏ –æ—Ç –¥—Ä—É–≥–æ–≥–æ —Å–∫—Ä–∏–ø—Ç–∞), —Å–æ—Ö—Ä–∞–Ω—è–µ–º –∏ –≤—ã–∑—ã–≤–∞–µ–º –µ–≥–æ —Ç–æ–∂–µ,
-- –≤–º–µ—Å—Ç–æ –º–æ–ª—á–∞–ª–∏–≤–æ–π –ø–µ—Ä–µ–∑–∞–ø–∏—Å–∏.
local _fh_prev_onPlayerSync = sampev.onPlayerSync
function sampev.onPlayerSync(playerId, data)
    if data and data.position then
        _G.fh_player_positions[playerId] = { x = data.position.x, y = data.position.y, z = data.position.z, t = _G.fh_cached_time }
    end
    if _fh_prev_onPlayerSync then
        local ok, err = pcall(_fh_prev_onPlayerSync, playerId, data)
        if not ok then
            print('[Family Helper] \xee\xf8\xe8\xe1\xea\xe0 \xe2 \xf6\xe5\xef\xee\xf7\xea\xe5 onPlayerSync: ' .. tostring(err))
        end
    end
end

-- –ü–µ—Ä–∏–æ–¥–∏—á–µ—Å–∫–∞—è TTL-–æ—á–∏—Å—Ç–∫–∞ —É—Å—Ç–∞—Ä–µ–≤—à–∏—Ö –ø–æ–∑–∏—Ü–∏–π. –í—ã–∑—ã–≤–∞–µ—Ç—Å—è –∏–∑
-- –≥–ª–∞–≤–Ω–æ–≥–æ —Ü–∏–∫–ª–∞ (–Ω–µ —á–∞—â–µ FH_POS_CLEANUP_INTERVAL), –∞ –Ω–µ –ø—Ä–∏ –∫–∞–∂–¥–æ–º
-- —Å–∫–∞–Ω–µ —Ä–∞–¥–∏—É—Å–∞, —á—Ç–æ–±—ã –Ω–µ –ø–ª–∞—Ç–∏—Ç—å –∑–∞ —É–±–æ—Ä–∫—É –º—É—Å–æ—Ä–∞ –Ω–∞ –∫–∞–∂–¥—ã–π —Ç–∏–∫.
function fh_cleanup_player_positions()
    local now = _G.fh_cached_time
    if now - _fh_last_pos_cleanup < FH_POS_CLEANUP_INTERVAL then return end
    _fh_last_pos_cleanup = now
    for pid, pos in pairs(_G.fh_player_positions) do
        if now - (pos.t or 0) > FH_POS_TTL then
            _G.fh_player_positions[pid] = nil
        end
    end
end

-- –°–∫–∞–Ω —Ä–∞–¥–∏—É—Å–∞. –°–∞–º–∞ —Ñ—É–Ω–∫—Ü–∏—è –æ—Å—Ç–∞–ª–∞—Å—å O(n) –ø–æ –∑–∞–∫—ç—à–∏—Ä–æ–≤–∞–Ω–Ω—ã–º –ø–æ–∑–∏—Ü–∏—è–º
-- (–∏–Ω–∞—á–µ –Ω–µ –ø–æ–ª—É—á–∏—Ç—å —Å–ø–∏—Å–æ–∫, –æ—Ç—Å–æ—Ä—Ç–∏—Ä–æ–≤–∞–Ω–Ω—ã–π –ø–æ –¥–∏—Å—Ç–∞–Ω—Ü–∏–∏), –Ω–æ —Ç–µ–ø–µ—Ä—å:
-- 1) –∫—ç—à –∂–∏–≤—ë—Ç –ø–æ TTL –∏ –Ω–µ —Ä–∞—Å—Ç—ë—Ç –±–µ—Å–∫–æ–Ω–µ—á–Ω–æ, 2) —ç—Ç–∞ —Ñ—É–Ω–∫—Ü–∏—è –≤—ã–∑—ã–≤–∞–µ—Ç—Å—è
-- –Ω–µ –Ω–∞ –∫–∞–∂–¥—ã–π —Ç–∏–∫ –≤—Å–ª–µ–ø—É—é, –∞ –ø–æ —Ç–∞–π–º–µ—Ä—É –Ω–µ —á–∞—â–µ 1 —Ä–∞–∑–∞/—Å–µ–∫ (—Å–º. –≥–ª–∞–≤–Ω—ã–π
-- —Ü–∏–∫–ª), –∏ 3) —É—Å—Ç–∞—Ä–µ–≤—à–∏–µ (>TTL) –∑–∞–ø–∏—Å–∏ —É–∂–µ –æ—Ç—Ñ–∏–ª—å—Ç—Ä–æ–≤–∞–Ω—ã –ø–æ –≤—Ä–µ–º–µ–Ω–∏, —Ç–∞–∫
-- —á—Ç–æ pcall –Ω–∞ sampIsPlayerConnected –¥–ª—è –∫–∞–∂–¥–æ–≥–æ –±–æ–ª—å—à–µ –Ω–µ –Ω—É–∂–µ–Ω.
function fh_get_players_in_radius_sync(radius)
    local result = {}
    local mx, my, mz = getCharCoordinates(PLAYER_PED)
    local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    local now = os.time()
    for pid, pos in pairs(_G.fh_player_positions) do
        if pid ~= myId and now - pos.t <= FH_POS_TTL then
            if sampIsPlayerConnected(pid) then
                local dist = getDistanceBetweenCoords3d(mx, my, mz, pos.x, pos.y, pos.z)
                if dist <= radius then
                    table.insert(result, { id = pid, dist = dist })
                end
            end
        end
    end
    table.sort(result, function(a, b) return a.dist < b.dist end)
    local ids = {}
    for _, v in ipairs(result) do table.insert(ids, v.id) end
    return ids
end

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

local function fh_num_fmt(n)
    if n == nil then return '-' end
    local num = tonumber(n)
    if not num then return tostring(n) end
    local s = tostring(math.floor(num))
    return s:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
end

local function fh_num_short(n)
    if n == nil then return '-' end
    local num = tonumber(n)
    if not num then return '-' end
    if num >= 1000000000 then return string.format('%.1fB', num/1000000000)
    elseif num >= 1000000 then return string.format('%.1fM', num/1000000)
    elseif num >= 1000 then return string.format('%.1fK', num/1000)
    else return tostring(math.floor(num)) end
end

local fh_sex = 'ÃÛÊ˜ËÌ‡'
local fh_gun_names = {
    [0]='ÍÛÎ‡ÍË',[1]='Í‡ÒÚÂÚ˚',[2]='ÍÎ˛¯ÍÛ ‰Îˇ „ÓÎ¸Ù‡',[3]='‰Û·ËÌÍÛ',
    [4]='ÓÒÚ˚È ÌÓÊ',[5]='·ËÚÛ',[6]='ÎÓÔ‡ÚÛ',[7]='ÍËÈ',[8]='Í‡Ú‡ÌÛ',[9]='·ÂÌÁÓÔËÎÛ',
    [16]='ÓÒÍÓÎÓ˜ÌÛ˛ „‡Ì‡ÚÛ',[17]='‰˚ÏÓ‚Û˛ „‡Ì‡ÚÛ',[18]='ÍÓÍÚÂÈÎ¸ ÃÓÎÓÚÓ‚‡',
    [22]='ÔËÒÚÓÎÂÚ Colt45',[23]='˝ÎÂÍÚÓ¯ÓÍÂ Taser',[24]='ÔËÒÚÓÎÂÚ Desert Eagle',
    [25]='‰Ó·Ó‚ËÍ',[26]='Ó·ÂÁ',[27]='ÛÎÛ˜¯ÂÌÌ˚È Ó·ÂÁ',
    [28]='ÔËÒÚ-ÔÛÎ∏Ï∏Ú Micro Uzi',[29]='ÔËÒÚ-ÔÛÎ∏Ï∏Ú MP5',
    [30]='‡‚ÚÓÏ‡Ú AK-47',[31]='‡‚ÚÓÏ‡Ú M4',[32]='ÔËÒÚ-ÔÛÎ∏Ï∏Ú Tec-9',
    [33]='‚ËÌÚÓ‚ÍÛ Rifle',[34]='ÒÌ‡ÈÔ ‚ËÌÚÓ‚ÍÛ Rifle',
    [35]='ÍÒ ÔÓÚ ‡ÍÂÚÛ',[37]='Ó„ÌÂÏ∏Ú',[38]='ÏËÌË„‡Ì',
    [39]='‰ËÌ‡ÏËÚ',[41]='ÔÂˆÓ‚˚È ·‡ÎÎÓÌ˜ËÍ',[42]='Ó„ÌÂÚÛ¯ËÚÂÎ¸',
    [71]='ÔËÒÚÓÎÂÚ Desert Eagle Steel',[72]='ÔËÒÚÓÎÂÚ Desert Eagle Gold',
    [73]='ÔËÒÚÓÎÂÚ Glock',[74]='ÔËÒÚÓÎÂÚ Desert Eagle Flame',
    [75]='ÔËÒÚÓÎÂÚ Colt Python',[76]='ÔËÒÚÓÎÂÚ Colt Python Silver',
    [77]='‡‚ÚÓÏ‡Ú AK-47 Roses',[78]='‡‚ÚÓÏ‡Ú AK-47 Gold',
    [79]='ÔÛÎÂÏ∏Ú M249 Graffiti',[80]='ÁÓÎÓÚÛ˛ —‡È„Û',
    [81]='ÔËÒÚ-ÔÛÎ∏Ï∏Ú PPSH',[82]='ÔÛÎÂÏ∏Ú M249',[83]='ÔËÒÚ-ÔÛÎ∏Ï∏Ú Skorp',
    [84]='‡‚ÚÓÏ‡Ú AKS-74 Í‡ÏÛÙ',[85]='‡‚ÚÓÏ‡Ú AK-47 Í‡ÏÛÙ',
    [86]='‰Ó·Ó‚ËÍ Rebecca',[88]='ÎÂ‰ˇÌÓÈ ÏÂ˜',[89]='ÔÓÚ‡Î¸ÌÛ˛ ÔÛ¯ÍÛ',[92]='ÒÌ‡ÈÔ ‚ËÌÚ McMillian TAC-50',
}
local fh_take_from = {'ËÁ-Á‡ ÒÔËÌ˚','ËÁ ÍÓ·Û˚','ËÁ Í‡Ï‡Ì‡','Ì‡·ÓÒËÎ'}
local fh_take_to   = {'Á‡ ÒÔËÌÛ','‚ ÍÓ·ÛÛ','‚ Í‡Ï‡Ì','Ì‡ ÔÓˇÒ'}
local fh_rp_take_slot = {
    [1]=2,[2]=1,[3]=2,[4]=2,[5]=1,[6]=1,[7]=1,[8]=1,[9]=1,
    [16]=3,[17]=3,[18]=3,[22]=2,[23]=2,[24]=2,[25]=1,[26]=1,[27]=1,
    [28]=1,[29]=1,[30]=1,[31]=1,[32]=1,[33]=1,[34]=1,[35]=1,[37]=1,[38]=1,
    [39]=3,[41]=3,[42]=1,[71]=2,[72]=2,[73]=2,[74]=2,[75]=2,[76]=2,
    [77]=1,[78]=1,[79]=1,[80]=1,[81]=1,[82]=1,[83]=1,[84]=1,[85]=1,[86]=1,
    [88]=1,[89]=2,[92]=1,
}
local fh_gun_now = 0
local fh_gun_old = 0

local settings = {}
local default_settings = {

      blacklist = {},
      quests_stats = {},
      auto_tags = {
          { rank = "1", tag = "\xcd\xee\xe2\xe8\xf7\xee\xea" },
          { rank = "2", tag = "\xd3\xf7\xe0\xf1\xf2\xed\xe8\xea" },
          { rank = "3", tag = "\xd1\xf2\xe0\xf0\xf8\xe8\xe9" },
          { rank = "4", tag = "\xc2\xe5\xf2\xe5\xf0\xe0\xed" },
          { rank = "5", tag = "\xce\xf4\xe8\xf6\xe5\xf0" },
          { rank = "6", tag = "\xd1\xf2\xe0\xf0\xf8\xe8\xe9 \xee\xf4\xe8\xf6\xe5\xf0" },
          { rank = "7", tag = "\xca\xe0\xef\xe8\xf2\xe0\xed" },
          { rank = "8", tag = "\xc7\xe0\xec\xe5\xf1\xf2\xe8\xf2\xe5\xeb\xfc" },
          { rank = "9", tag = "\xd1\xee-\xeb\xe8\xe4\xe5\xf0" },
          { rank = "10", tag = "\xcb\xe8\xe4\xe5\xf0" },
      },
      offline_kick_days = 7,
      quest_reward_amount = 1000000,
  general = {
        version = thisScript().version,
        rp_chat = true,
        auto_invite = false,
        auto_invite_radius = 5,
        auto_invite_delay = 3.0,
        auto_welcome = true,
        auto_congrats = true,
        custom_dpi = 1.50,
        custom_font_scale = 0.85,
        autofind_dpi = true,
        main_win_w = 0,
        main_win_h = 0,
        main_win_x = -1,
        main_win_y = -1,
        float_btn_x = 40,
        float_btn_y = 300,
        float_btn_radius = 15,
        float_btn_size = 1.0,
        float_btn_enable = true,
        auto_ad_confirm = false,
        auto_storage_collect = false,
        auto_rp_guns = false,
        auto_ad_station_idx = 2,
        auto_ad_type = 0,
                auto_mute_insults = false,
        auto_mute_insults_time = 60,
        auto_mute_spam = false,
        auto_mute_spam_time = 30,
        auto_mute_flood = false,

        auto_mute_flood_time = 30,

        auto_keyword_invite = true,
        auto_quest_congrats = true,
        famspawn_delay = 30,
        invite_total = 0,
        invite_price_normal = 2000000,
        invite_price_bonus = 4000000,
        invite_bonus_threshold = 50,
        keyword_invite_list = {'\xe8\xed\xe2', '\xe8\xed\xe2\xe0\xe9\xf2', '\xe8\xed\xe2\xe0\xe9\xf2 \xef\xe6', '\xec\xee\xe6\xed\xee \xe2 \xf4\xe0\xec', '\xef\xf0\xe8\xec\xe8', '\xe8\xed\xe2 \xe2 \xf4\xe0\xec\xf3', '\xef\xf0\xe8\xec\xe8 \xe2 \xf1\xe5\xec\xfc\xfe', '\xf5\xee\xf7\xf3 \xe2 \xf4\xe0\xec', '\xe2\xee\xe7\xfc\xec\xe8 \xe2 \xf1\xe5\xec\xfc\xfe'},
    },
    reward = {
        use_fam = true,
        items = {
            { text = '\xc4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc, {player_name}! \xd1\xef\xe0\xf1\xe8\xe1\xee \xe7\xe0 \xea\xe2\xe5\xf1\xf2!', waiting = 1.5 },
        }
    },
    interface = {
        accent_r = 0.6,
        accent_g = 0.302,
        accent_b = 0.902,
        window_alpha = 1.0,
        bg_brightness = 0.05,
    },
    family_info = {
        family_name = 'Grozzy',
        family_tag = '[Grozzy]',
        leader_name = '',
        my_name = '',
        my_rank = '',
        my_rank_number = 1,
    },
    reconnect = {
        enabled       = false,
        auto_login    = false,
        on_kicked     = true,
        on_banned     = false,
        on_rejected   = true,
        on_password   = false,
        delay         = 5.0,
        login         = '',
        password      = '',
        spawn_json    = '',
        spawn_use     = 0,
    },
    tg = {
        enabled = false,
        token = '',
        channel_id = '',
        chat_id = '',
        bot_username = '',
        my_chat_id = '',
        last_update_offset = 0,
        pending = {},
        relay_ids = {},
        ev_invite = true,
        ev_join = true,
        ev_leave = true,
        ev_level = true,
        ev_quest = true,
        ev_mute = true,
        ev_coins = true,
        ev_bank = true,
        auto_role = false,
        auto_inv_report = false,
    },
    rp_invite = {
        text = '/me \xe4\xee\xf1\xf2\xe0\xb8\xf2 \xe8\xe7 \xea\xe0\xf0\xec\xe0\xed\xe0 \xf2\xe5\xeb\xe5\xf4\xee\xed \xe8 \xee\xf2\xea\xf0\xfb\xe2\xe0\xe5\xf2 \xe1\xe0\xe7\xf3 \xe4\xe0\xed\xed\xfb\xf5 \xf1\xe5\xec\xfc\xe8&/me \xef\xf0\xee\xe2\xe5\xf0\xff\xe5\xf2 \xe8\xed\xf4\xee\xf0\xec\xe0\xf6\xe8\xfe \xee \xf7\xe5\xeb\xee\xe2\xe5\xea\xe5 \xed\xe0\xef\xf0\xee\xf2\xe8\xe2&/do \xc8\xed\xf4\xee\xf0\xec\xe0\xf6\xe8\xff \xef\xf0\xee\xe2\xe5\xf0\xe5\xed\xe0.&/todo \xc4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc \xe2 \xed\xe0\xf8\xf3 \xf1\xe5\xec\xfc\xfe!*\xf3\xeb\xfb\xe1\xe0\xff\xf1\xfc&/faminvite {arg_id}',
        waiting = 1.5,
    },
    welcome = {
        use_fam = true,
        items = {
            { text = '\xc4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc \xe2 \xf1\xe5\xec\xfc\xfe {family_name}, {player_name}!', waiting = 1.5 },
            { text = '\xce\xe7\xed\xe0\xea\xee\xec\xfc\xf1\xff \xf1 \xef\xf0\xe0\xe2\xe8\xeb\xe0\xec\xe8 \xe8 \xf7\xf3\xe2\xf1\xf2\xe2\xf3\xe9 \xf1\xe5\xe1\xff \xea\xe0\xea \xe4\xee\xec\xe0.', waiting = 1.5 },
            { text = '\xcf\xee \xe2\xee\xef\xf0\xee\xf1\xe0\xec \xef\xe8\xf8\xe8 \xe2 /fam, \xef\xee\xec\xee\xe6\xe5\xec!', waiting = 1.5 },
        }
    },
    congrats = {
        use_fam = true,
        items = {
            { text = '\xcf\xee\xe7\xe4\xf0\xe0\xe2\xeb\xff\xfe \xf1 \xed\xee\xe2\xfb\xec \xf3\xf0\xee\xe2\xed\xe5\xec, {player_name}!', waiting = 2.0 },
            { text = '\xd2\xe0\xea \xe4\xe5\xf0\xe6\xe0\xf2\xfc!', waiting = 1.5 },
        }
    },
    interactions = {
        { name = '1. \xcf\xf0\xe8\xe2\xe5\xf2\xf1\xf2\xe2\xe8\xe5', lines = {
            '/me \xef\xee\xe4\xf5\xee\xe4\xe8\xf2 \xea {get_ru_nick} \xe8 \xef\xf0\xe8\xe2\xe5\xf2\xeb\xe8\xe2\xee \xec\xe0\xf8\xe5\xf2 \xf0\xf3\xea\xee\xe9',
            '\xcf\xf0\xe8\xe2\xe5\xf2, {get_ru_nick}! \xcc\xee\xe3\xf3 \xe7\xe0\xe4\xe0\xf2\xfc \xf2\xe5\xe1\xe5 \xef\xe0\xf0\xf3 \xe2\xee\xef\xf0\xee\xf1\xee\xe2?',
        }, waiting = 2.5 },
        { name = '2. \xcf\xf0\xe5\xe4\xeb\xee\xe6\xe5\xed\xe8\xe5', lines = {
            '\xd1\xec\xee\xf2\xf0\xfe, \xf2\xfb \xef\xee\xea\xe0 \xe1\xe5\xe7 \xf1\xe5\xec\xfc\xe8 - \xec\xee\xe3\xf3 \xf0\xe0\xf1\xf1\xea\xe0\xe7\xe0\xf2\xfc \xef\xf0\xee {family_name}, \xe5\xf1\xeb\xe8 \xe8\xed\xf2\xe5\xf0\xe5\xf1\xed\xee.',
            '{pause}',
            '\xd0\xe0\xf1\xf1\xea\xe0\xe6\xf3 \xef\xee \xf4\xe0\xea\xf2\xe0\xec: \xf7\xf2\xee \xe4\xe0\xb8\xec, \xea\xe0\xea\xe8\xe5 \xef\xeb\xfe\xf1\xfb, \xe8 \xf7\xf2\xee \xed\xf3\xe6\xed\xee \xee\xf2 \xf2\xe5\xe1\xff - \xe1\xe5\xe7 \xe2\xee\xe4\xfb.',
        }, waiting = 2.5 },
        { name = '3. \xc0\xe2\xf2\xee\xef\xe0\xf0\xea', lines = {
            '\xc2 {family_name} \xf1\xe2\xee\xe9 \xe0\xe2\xf2\xee\xef\xe0\xf0\xea - \xe1\xe5\xf0\xb8\xf8\xfc \xf2\xe0\xf7\xea\xf3 \xf1 \xf1\xe5\xec\xe5\xe9\xed\xee\xe9 \xef\xe0\xf0\xea\xee\xe2\xea\xe8 \xe2 \xeb\xfe\xe1\xee\xe9 \xec\xee\xec\xe5\xed\xf2, \xed\xe5 \xed\xf3\xe6\xed\xee \xea\xee\xef\xe8\xf2\xfc \xed\xe0 \xef\xe5\xf0\xe2\xf3\xfe \xec\xe0\xf8\xe8\xed\xf3.',
            '{pause}',
            '\xcf\xeb\xfe\xf1 \xe2 \xe3\xe0\xf0\xe0\xe6\xe5 \xeb\xe8\xec\xe8\xf2\xea\xe8 - \xed\xe5 \xef\xe5\xf0\xe5\xe2\xee\xf0\xe0\xf7\xe8\xe2\xe0\xfe\xf2\xf1\xff, \xed\xe5 \xeb\xee\xec\xe0\xfe\xf2\xf1\xff, \xe8 \xf1\xf2\xee\xff\xf2 \xef\xee 10 \xec\xe8\xeb\xeb\xe8\xe0\xf0\xe4\xee\xe2 - \xf2\xe0\xea\xee\xe5 \xed\xe5 \xe2 \xea\xe0\xe6\xe4\xee\xe9 \xf1\xe5\xec\xfc\xe5 \xf3\xe2\xe8\xe4\xe8\xf8\xfc.',
        }, waiting = 2.5 },
        { name = '4. \xc6\xca / \xea\xe2\xe0\xf0\xf2\xe8\xf0\xe0', lines = {
            '\xc5\xf9\xb8 \xf3 \xed\xe0\xf1 \xf1\xe5\xec\xe5\xe9\xed\xe0\xff \xea\xe2\xe0\xf0\xf2\xe8\xf0\xe0 \xe2 Arizona Tower - \xfd\xf2\xee \xed\xe5 \xef\xf0\xee\xf1\xf2\xee \xea\xf0\xfb\xf8\xe0 \xed\xe0\xe4 \xe3\xee\xeb\xee\xe2\xee\xe9.',
            '{pause}',
            '\xce\xf2\xf2\xf3\xe4\xe0 \xe8\xe4\xb8\xf2 \xe2\xf1\xff \xe4\xe2\xe8\xe6\xf3\xf5\xe0: \xe2\xee\xe9\xed\xfb \xe7\xe0 \xf2\xe5\xf0\xf0\xe8\xf2\xee\xf0\xe8\xe8, \xe4\xee\xf5\xee\xe4 \xf1 \xe7\xe0\xf5\xe2\xe0\xf7\xe5\xed\xed\xfb\xf5 \xf2\xee\xf7\xe5\xea, \xf1\xe2\xee\xe8 \xf4\xf3\xf0\xe3\xee\xed\xfb. \xc0 \xe5\xf9\xb8 \xc6\xca \xef\xf0\xff\xec\xee \xf0\xff\xe4\xee\xec \xf1 \xd6\xe5\xed\xf2\xf0\xe0\xeb\xfc\xed\xfb\xec \xf0\xfb\xed\xea\xee\xec - \xee\xf7\xe5\xed\xfc \xf3\xe4\xee\xe1\xed\xee, \xe5\xf1\xeb\xe8 \xeb\xfe\xe1\xe8\xf8\xfc \xf2\xee\xf0\xe3\xee\xe2\xe0\xf2\xfc.',
        }, waiting = 2.5 },
        { name = '5. \xcf\xf0\xee\xea\xe0\xf7\xea\xe0 \xed\xe0 \xf0\xe0\xe1\xee\xf2\xe0\xf5', lines = {
            '\xd3 \xed\xe0\xf1 \xe5\xf9\xb8 \xef\xf0\xee\xea\xe0\xf7\xe0\xed\xfb \xe7\xe0\xf0\xef\xeb\xe0\xf2\xfb \xed\xe0 \xf0\xe0\xe1\xee\xf2\xe0\xf5 - \xe4\xe0\xeb\xfc\xed\xee\xe1\xee\xe9\xf9\xe8\xea, \xef\xe8\xeb\xee\xf2, \xef\xee\xe6\xe0\xf0\xed\xfb\xe9 \xe8 \xe4\xf0\xf3\xe3\xe8\xe5, \xeb\xe8\xe4\xe5\xf0 \xe2\xea\xeb\xe0\xe4\xfb\xe2\xe0\xe5\xf2\xf1\xff \xe2 \xfd\xf2\xee \xee\xf2\xe4\xe5\xeb\xfc\xed\xee.',
            '{pause}',
            '\xd2\xee \xe5\xf1\xf2\xfc \xf1 \xee\xe4\xed\xee\xe9 \xe8 \xf2\xee\xe9 \xe6\xe5 \xf0\xe0\xe1\xee\xf2\xfb \xe2 \xed\xe0\xf8\xe5\xe9 \xf1\xe5\xec\xfc\xe5 \xe7\xe0\xf0\xe0\xe1\xee\xf2\xe0\xe5\xf8\xfc \xe1\xee\xeb\xfc\xf8\xe5, \xf7\xe5\xec \xf1\xe0\xec \xef\xee \xf1\xe5\xe1\xe5.',
        }, waiting = 2.5 },
        { name = '6. \xcf\xeb\xfe\xf1\xfb (\xe3\xe0\xeb\xee\xf7\xea\xe0/\xe1\xf0\xe5\xed\xe4/\xf4\xeb\xe0\xe3)', lines = {
            '\xd3 \xed\xe0\xf1 \xe2\xf1\xb8 \xef\xf0\xee\xea\xe0\xf7\xe0\xed\xee - \xe3\xe0\xeb\xee\xf7\xea\xe0, \xe1\xf0\xe5\xed\xe4 \xe8 \xf4\xeb\xe0\xe3, \xf1\xe5\xec\xfc\xff \xee\xf4\xe8\xf6\xe8\xe0\xeb\xfc\xed\xee \xed\xe0 \xf1\xe5\xf0\xfc\xb8\xe7\xed\xee\xec \xf3\xf0\xee\xe2\xed\xe5.',
            '{pause}',
            '\xc8\xe7 \xef\xee\xeb\xe5\xe7\xed\xee\xe3\xee \xeb\xe8\xf7\xed\xee \xf2\xe5\xe1\xe5: \xf4\xeb\xe0\xe3 \xe4\xe0\xb8\xf2 +7% \xea \xe7\xe0\xf0\xef\xeb\xe0\xf2\xe5 \xe2 \xee\xf0\xe3\xe0\xed\xe8\xe7\xe0\xf6\xe8\xe8 \xe8 \xe1\xee\xed\xf3\xf1\xfb \xed\xe0 \xf0\xe0\xe1\xee\xf2\xe0\xf5, \xe3\xe0\xeb\xee\xf7\xea\xe0 \xe7\xe0\xf9\xe8\xf9\xe0\xe5\xf2 \xee\xf2 \xea\xee\xef\xe8\xf0\xee\xe2\xe0\xed\xe8\xff \xe8 \xf1\xed\xe8\xe6\xe0\xe5\xf2 \xef\xee\xf2\xe5\xf0\xe8 \xf0\xe5\xef\xf3\xf2\xe0\xf6\xe8\xe8 \xef\xf0\xe8 \xed\xe0\xea\xe0\xe7\xe0\xed\xe8\xff\xf5, \xe0 \xe1\xf0\xe5\xed\xe4 \xe4\xe0\xb8\xf2 \xeb\xe8\xf8\xed\xe8\xe9 \xe4\xee\xec \xe8 \xef\xee\xe2\xfb\xf8\xe5\xed\xed\xfb\xe5 \xf8\xe0\xed\xf1\xfb \xed\xe0 \xf0\xf3\xeb\xe5\xf2\xea\xe8.',
        }, waiting = 2.5 },
        { name = '7. \xc2\xee\xe7\xf0\xe0\xe6\xe5\xed\xe8\xe5 - \xed\xe5 \xed\xe0\xe4\xee \xec\xed\xe5 \xfd\xf2\xee', lines = {
            '\xcf\xee\xed\xe8\xec\xe0\xfe, \xe4\xe5\xeb\xee \xf2\xe2\xee\xb8 - \xf2\xee\xeb\xfc\xea\xee \xf3\xf7\xf2\xe8, \xf7\xf2\xee \xef\xee \xf1\xf2\xe0\xf0\xf2\xee\xe2\xfb\xec \xea\xe2\xe5\xf1\xf2\xe0\xec \xe2\xf1\xf2\xf3\xef\xeb\xe5\xed\xe8\xe5 \xe2 \xf1\xe5\xec\xfc\xfe \xe2\xf1\xb8 \xf0\xe0\xe2\xed\xee \xef\xee\xed\xe0\xe4\xee\xe1\xe8\xf2\xf1\xff, \xe1\xe5\xe7 \xfd\xf2\xee\xe3\xee \xe4\xe0\xeb\xfc\xf8\xe5 \xed\xe5 \xef\xf0\xee\xe4\xe2\xe8\xed\xe5\xf8\xfc\xf1\xff.',
            '{pause}',
            '\xd2\xe0\xea \xf7\xf2\xee \xf1\xec\xfb\xf1\xeb\xe0 \xf2\xff\xed\xf3\xf2\xfc \xee\xf1\xee\xe1\xee \xed\xe5\xf2 - \xeb\xf3\xf7\xf8\xe5 \xf1\xf0\xe0\xe7\xf3 \xea \xf2\xe5\xec, \xf3 \xea\xee\xe3\xee \xe5\xf1\xf2\xfc \xf7\xe5\xec \xef\xee\xec\xee\xf7\xfc: \xe0\xe2\xf2\xee\xef\xe0\xf0\xea, \xea\xe2\xe0\xf0\xf2\xe8\xf0\xe0, \xef\xf0\xee\xea\xe0\xf7\xe0\xed\xed\xfb\xe5 \xe7\xe0\xf0\xef\xeb\xe0\xf2\xfb. \xce\xe1\xfb\xf7\xed\xee \xef\xee\xf2\xee\xec \xf1\xe0\xec\xe8 \xf1\xe5\xec\xfc\xfe \xe8\xf9\xf3\xf2, \xef\xf0\xee\xf1\xf2\xee \xe2\xf0\xe5\xec\xff \xf2\xe5\xf0\xff\xfe\xf2.',
        }, waiting = 2.5 },
        { name = '8. \xc2\xee\xe7\xf0\xe0\xe6\xe5\xed\xe8\xe5 - \xe2\xf1\xf2\xf3\xef\xeb\xfe \xef\xee\xe7\xe6\xe5', lines = {
            '\xcd\xe5 \xe2\xee\xef\xf0\xee\xf1, \xf1\xef\xe5\xf8\xe8\xf2\xfc \xed\xe5\xea\xf3\xe4\xe0 - \xed\xee \xf1\xec\xfb\xf1\xeb \xf2\xff\xed\xf3\xf2\xfc, \xe5\xf1\xeb\xe8 \xef\xee \xea\xe2\xe5\xf1\xf2\xf3 \xe2\xf1\xb8 \xf0\xe0\xe2\xed\xee \xef\xee\xed\xe0\xe4\xee\xe1\xe8\xf2\xf1\xff?',
            '{pause}',
            '\xc7\xe0\xee\xe4\xed\xee \xf1 \xea\xe2\xe5\xf1\xf2\xee\xec \xf1\xf0\xe0\xe7\xf3 \xe7\xe0\xea\xf0\xee\xe5\xf8\xfc \xe8 \xe0\xe2\xf2\xee\xef\xe0\xf0\xea, \xe8 \xea\xe2\xe0\xf0\xf2\xe8\xf0\xf3, \xe8 \xef\xf0\xee\xea\xe0\xf7\xe0\xed\xed\xfb\xe5 \xe7\xe0\xf0\xef\xeb\xe0\xf2\xfb - \xe0 \xed\xe5 \xe1\xf3\xe4\xe5\xf8\xfc \xef\xee\xf2\xee\xec \xe8\xf1\xea\xe0\xf2\xfc \xfd\xf2\xee \xee\xf2\xe4\xe5\xeb\xfc\xed\xee.',
        }, waiting = 2.5 },
        { name = '9. \xc2\xee\xe7\xf0\xe0\xe6\xe5\xed\xe8\xe5 - \xf7\xf2\xee \xe2\xee\xee\xe1\xf9\xe5 \xe4\xe5\xeb\xe0\xf2\xfc \xe2 \xf1\xe5\xec\xfc\xe5', lines = {
            '\xcd\xe8\xf7\xe5\xe3\xee \xf1\xe2\xe5\xf0\xf5\xfa\xe5\xf1\xf2\xe5\xf1\xf2\xe2\xe5\xed\xed\xee\xe3\xee - \xee\xe1\xfb\xf7\xed\xe0\xff \xe8\xe3\xf0\xe0, \xf2\xee\xeb\xfc\xea\xee \xf1 \xe1\xee\xed\xf3\xf1\xe0\xec\xe8 \xe8 \xef\xee\xe4\xe4\xe5\xf0\xe6\xea\xee\xe9 \xf0\xff\xe4\xee\xec.',
            '{pause}',
            '\xc0\xea\xf2\xe8\xe2\xed\xee\xf1\xf2\xfc \xef\xee \xe6\xe5\xeb\xe0\xed\xe8\xfe: \xea\xf2\xee-\xf2\xee \xf4\xe0\xf0\xec\xe8\xf2 \xf1 \xf1\xe5\xec\xfc\xb8\xe9, \xea\xf2\xee-\xf2\xee \xef\xf0\xee\xf1\xf2\xee \xf7\xe8\xf1\xeb\xe8\xf2\xf1\xff \xe8 \xef\xee\xeb\xfc\xe7\xf3\xe5\xf2\xf1\xff \xe0\xe2\xf2\xee\xef\xe0\xf0\xea\xee\xec \xf1 \xea\xe2\xe0\xf0\xf2\xe8\xf0\xee\xe9 - \xed\xe8\xea\xf2\xee \xed\xe8\xea\xee\xe3\xee \xed\xe5 \xe7\xe0\xf1\xf2\xe0\xe2\xeb\xff\xe5\xf2.',
        }, waiting = 2.5 },
        { name = '10. \xd3\xf1\xeb\xee\xe2\xe8\xff', lines = {
            '\xd3\xf1\xeb\xee\xe2\xe8\xff \xef\xf0\xee\xf1\xf2\xfb\xe5 - \xe1\xf3\xe4\xfc \xed\xe0 \xf1\xe2\xff\xe7\xe8, \xef\xee\xec\xee\xe3\xe0\xe9 \xf1\xe2\xee\xe8\xec \xe8 \xf1\xee\xe1\xeb\xfe\xe4\xe0\xe9 \xef\xf0\xe0\xe2\xe8\xeb\xe0 \xf1\xe5\xec\xfc\xe8.',
            '\xcb\xe8\xe4\xe5\xf0 - {my_name}, \xe2\xf1\xe5\xe3\xe4\xe0 \xed\xe0 \xf1\xe2\xff\xe7\xe8 \xe8 \xef\xee\xec\xee\xe6\xe5\xf2 \xee\xf1\xe2\xee\xe8\xf2\xfc\xf1\xff \xf1 \xef\xe5\xf0\xe2\xee\xe3\xee \xe4\xed\xff.',
        }, waiting = 2.5 },
        { name = '11. \xc8\xed\xe2\xe0\xe9\xf2 (\xd0\xcf)', lines = {
            '/me \xe4\xee\xf1\xf2\xe0\xb8\xf2 \xf2\xe5\xeb\xe5\xf4\xee\xed \xe8 \xee\xf2\xea\xf0\xfb\xe2\xe0\xe5\xf2 \xef\xf0\xe8\xeb\xee\xe6\xe5\xed\xe8\xe5 \xf1\xe5\xec\xfc\xe8',
            '/do \xcd\xe0 \xfd\xea\xf0\xe0\xed\xe5 \xef\xee\xff\xe2\xeb\xff\xe5\xf2\xf1\xff \xf4\xee\xf0\xec\xe0 \xef\xf0\xe8\xe3\xeb\xe0\xf8\xe5\xed\xe8\xff \xe2 \xf1\xe5\xec\xfc\xfe.',
            '\xce\xf2\xef\xf0\xe0\xe2\xeb\xff\xfe \xf2\xe5\xe1\xe5 \xef\xf0\xe8\xe3\xeb\xe0\xf8\xe5\xed\xe8\xe5 - \xe6\xe4\xe8 \xe2 \xea\xee\xec\xe0\xed\xe4\xe5.',
            '/faminvite {arg_id}',
            '/b \xcf\xf0\xe8\xe3\xeb\xe0\xf8\xe5\xed\xe8\xe5 \xee\xf2\xef\xf0\xe0\xe2\xeb\xe5\xed\xee, \xef\xf0\xe8\xec\xe8 \xea\xee\xec\xe0\xed\xe4\xee\xe9 /offer.',
        }, waiting = 2.0 },
        { name = '12. \xcd\xe0\xef\xee\xec\xed\xe8\xf2\xfc /offer', lines = {
            '/b \xcf\xf0\xe8\xe3\xeb\xe0\xf8\xe5\xed\xe8\xe5 \xf3\xe6\xe5 \xf3 \xf2\xe5\xe1\xff, \xef\xf0\xe8\xec\xe8 \xea\xee\xec\xe0\xed\xe4\xee\xe9 /offer.',
        }, waiting = 2.0 },
        { name = '13. \xcf\xf0\xee\xf9\xe0\xed\xe8\xe5 (\xef\xf0\xe8\xed\xff\xeb)', lines = {
            '/me \xf2\xe5\xef\xeb\xee \xf3\xeb\xfb\xe1\xe0\xe5\xf2\xf1\xff \xed\xee\xe2\xee\xec\xf3 \xf3\xf7\xe0\xf1\xf2\xed\xe8\xea\xf3 \xf1\xe5\xec\xfc\xe8',
            '\xce\xf2\xeb\xe8\xf7\xed\xee, \xe4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc \xe2 {family_name}! \xc5\xf1\xeb\xe8 \xf7\xf2\xee-\xf2\xee \xe1\xf3\xe4\xe5\xf2 \xed\xe5\xef\xee\xed\xff\xf2\xed\xee - \xef\xe8\xf8\xe8 \xe2 \xf1\xe5\xec\xe5\xe9\xed\xfb\xe9 \xf7\xe0\xf2, \xef\xee\xe4\xf1\xea\xe0\xe6\xe5\xec \xe8 \xef\xee\xec\xee\xe6\xe5\xec.',
        }, waiting = 2.5 },
        { name = '14. \xce\xf2\xea\xe0\xe7 (\xed\xe5 \xf5\xee\xf7\xe5\xf2)', lines = {
            '/me \xef\xee\xed\xe8\xec\xe0\xfe\xf9\xe5 \xea\xe8\xe2\xe0\xe5\xf2',
            '\xc1\xe5\xe7 \xef\xf0\xee\xe1\xeb\xe5\xec. \xc5\xf1\xeb\xe8 \xef\xe5\xf0\xe5\xe4\xf3\xec\xe0\xe5\xf8\xfc - \xef\xe8\xf8\xe8 \xe2 \xeb\xfe\xe1\xee\xe5 \xe2\xf0\xe5\xec\xff, \xe1\xf3\xe4\xe5\xec \xf0\xe0\xe4\xfb. \xd3\xe4\xe0\xf7\xe8 \xf2\xe5\xe1\xe5!',
        }, waiting = 2.5 },
    },
    piar_templates = {
        { name = '\xcf\xe8\xe0\xf0 /s', enable = true, auto = false, auto_interval = 300, auto_interval_max = 0, waiting = 1.5, lines = {
            '/s \xc2\xed\xe8\xec\xe0\xed\xe8\xe5! \xcd\xe0\xe1\xee\xf0 \xe2 \xf1\xe5\xec\xfc\xfe {family_name}!',
            '/s \xcf\xee\xeb\xed\xe0\xff \xef\xf0\xee\xea\xe0\xf7\xea\xe0, \xea\xe2\xe0\xf0\xf2\xe8\xf0\xe0, \xf2\xee\xef \xe0\xe2\xf2\xee\xef\xe0\xf0\xea!',
            '/s \xcf\xee\xe4\xee\xe9\xe4\xe8\xf2\xe5 \xea\xee \xec\xed\xe5 \xe8\xeb\xe8 \xed\xe0\xef\xe8\xf8\xe8\xf2\xe5 \xe2 \xeb\xf1!',
        }, last_time = 0, },
        { name = '\xcf\xe8\xe0\xf0 /vr', enable = true, auto = false, auto_interval = 600, auto_interval_max = 0, waiting = 1.5, lines = {
            '/vr \xd1\xe5\xec\xfc\xff {family_name} \xef\xf0\xe8\xe3\xeb\xe0\xf8\xe0\xe5\xf2 \xe0\xea\xf2\xe8\xe2\xed\xfb\xf5 \xe8\xe3\xf0\xee\xea\xee\xe2!',
            '/vr \xd4\xf3\xeb \xef\xf0\xee\xea\xe0\xf7\xea\xe0, \xe4\xf0\xf3\xe6\xed\xfb\xe9 \xea\xee\xeb\xeb\xe5\xea\xf2\xe8\xe2! \xcf\xee\xe4\xf5\xee\xe4\xe8\xf2\xe5!',
        }, last_time = 0, },
        { name = '\xc0\xed\xee\xed\xf1 \xe2 /fam', enable = true, auto = false, auto_interval = 0, auto_interval_max = 0, waiting = 2.5, lines = {
            '/fam \x95 ================================ \x95',
            '/fam        \xcf\xf0\xe8\xe2\xe5\xf2\xf1\xf2\xe2\xf3\xfe \xf1\xe5\xec\xfc\xfe Grozzy!',
            '/fam \x95 ================================ \x95',
            '/fam  \xa7 \xc1\xee\xed\xf3\xf1\xfb \xe7\xe0 \xe0\xea\xf2\xe8\xe2\xed\xee\xf1\xf2\xfc:',
            '/fam  --------------------------------',
            '/fam  \x95 Telegram: t.me/FamaGrozzy',
            '/fam    \xc2\xf1\xf2\xf3\xef\xe8 \xe2 \xe3\xf0\xf3\xef\xef\xf3 = +1 \xf0\xe0\xed\xe3',
            '/fam  --------------------------------',
            '/fam  \x95 \xd1\xec\xe5\xed\xe8 \xf4\xe0\xec\xe8\xeb\xe8\xfe \xed\xe0 _Grozzy',
            '/fam    \xcf\xf0\xe8\xec\xe5\xf0: Vasya_Grozzy = +1 \xf0\xe0\xed\xe3',
            '/fam  --------------------------------',
            '/fam  \x95 \xca\xf3\xef\xe8 +1 \xf0\xe0\xed\xe3: \xe2\xe7\xed\xee\xf1 5kk \xed\xe0 \xf1\xea\xeb\xe0\xe4',
            '/fam \x95 ================================ \x95',
            '/fam    \xc2\xee\xef\xf0\xee\xf1\xfb >> {my_name}',
        }, last_time = 0, },
    },
    commands = {
        { cmd = 'fzd', description = '\xcf\xf0\xe8\xe2\xe5\xf2\xf1\xf2\xe2\xe8\xe5', text = '\xc7\xe4\xf0\xe0\xe2\xf1\xf2\xe2\xf3\xe9, {get_ru_nick}! \xdf {my_name} \xe8\xe7 \xf1\xe5\xec\xfc\xe8 {family_name}. \xd0\xe0\xf1\xf1\xea\xe0\xe6\xf3 \xef\xe0\xf0\xf3 \xf1\xeb\xee\xe2 \xee \xed\xe0\xf1, \xe5\xf1\xeb\xe8 \xe8\xed\xf2\xe5\xf0\xe5\xf1\xed\xee.', arg = '{arg_id}', enable = true, waiting = '1.500', deleted = false },
        { cmd = 'finv', description = '\xc8\xed\xe2\xe0\xe9\xf2 (\xd0\xcf)', text = '/me \xe4\xee\xf1\xf2\xe0\xb8\xf2 \xf2\xe5\xeb\xe5\xf4\xee\xed \xe8 \xee\xf2\xea\xf0\xfb\xe2\xe0\xe5\xf2 \xef\xf0\xe8\xeb\xee\xe6\xe5\xed\xe8\xe5 \xf1\xe5\xec\xfc\xe8&/me \xe1\xfb\xf1\xf2\xf0\xee \xef\xf0\xee\xe1\xe8\xe2\xe0\xe5\xf2 \xe4\xe0\xed\xed\xfb\xe5 \xef\xee \xf1\xee\xe1\xe5\xf1\xe5\xe4\xed\xe8\xea\xf3&/do \xc2\xf1\xb8 \xf7\xe8\xf1\xf2\xee, \xe2\xee\xef\xf0\xee\xf1\xee\xe2 \xed\xe5\xf2.&/todo \xc4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc \xea \xed\xe0\xec!*\xf2\xe5\xef\xeb\xee \xf3\xeb\xfb\xe1\xe0\xff\xf1\xfc&/faminvite {arg_id}', arg = '{arg_id}', enable = true, waiting = '1.500', deleted = false },
        { cmd = 'fkik', description = '\xca\xe8\xea\xed\xf3\xf2\xfc (\xd0\xcf)', text = '/me \xee\xf2\xea\xf0\xfb\xe2\xe0\xe5\xf2 \xef\xf0\xe8\xeb\xee\xe6\xe5\xed\xe8\xe5 \xf1\xe5\xec\xfc\xe8 \xed\xe0 \xf2\xe5\xeb\xe5\xf4\xee\xed\xe5&/me \xf3\xe1\xe8\xf0\xe0\xe5\xf2 \xf3\xf7\xe0\xf1\xf2\xed\xe8\xea\xe0 \xe8\xe7 \xf1\xef\xe8\xf1\xea\xe0&/famuninvite {arg_id}', arg = '{arg_id}', enable = true, waiting = '1.500', deleted = false },
        { cmd = 'fpr', description = '\xd0\xf3\xf7\xed\xee\xe9 \xef\xe8\xe0\xf0', text = '/s \xc8\xf9\xe5\xec \xe0\xea\xf2\xe8\xe2\xed\xfb\xf5 \xe8\xe3\xf0\xee\xea\xee\xe2 \xe2 \xf1\xe5\xec\xfc\xfe {family_name}!&/s \xcc\xe0\xea\xf1\xe8\xec\xe0\xeb\xfc\xed\xe0\xff \xef\xf0\xee\xea\xe0\xf7\xea\xe0, \xf2\xee\xef\xee\xe2\xfb\xe9 \xe0\xe2\xf2\xee\xef\xe0\xf0\xea \xf1 \xeb\xe8\xec\xe8\xf2\xea\xe0\xec\xe8, \xfd\xeb\xe8\xf2\xea\xe0 \xe2 Arizona Tower!&/s \xcf\xee\xe4\xf5\xee\xe4\xe8 \x97 \xef\xee\xee\xe1\xf9\xe0\xe5\xec\xf1\xff!', arg = '', enable = true, waiting = '1.500', deleted = false },
        { cmd = 'frul', description = '\xcf\xf0\xe0\xe2\xe8\xeb\xe0', text = '/fam === \xcf\xd0\xc0\xc2\xc8\xcb\xc0 \xd1\xc5\xcc\xdc\xc8 ===&/fam 1. \xd3\xe2\xe0\xe6\xe0\xe9\xf2\xe5 \xe4\xf0\xf3\xe3 \xe4\xf0\xf3\xe3\xe0&/fam 2. \xd1\xee\xe1\xeb\xfe\xe4\xe0\xe9\xf2\xe5 \xef\xf0\xe0\xe2\xe8\xeb\xe0 \xf1\xe5\xf0\xe2\xe5\xf0\xe0&/fam 3. \xc1\xf3\xe4\xfc\xf2\xe5 \xed\xe0 \xf1\xe2\xff\xe7\xe8 \xe8 \xe0\xea\xf2\xe8\xe2\xed\xfb&/fam 4. \xcf\xee\xec\xee\xe3\xe0\xe9\xf2\xe5 \xed\xee\xe2\xe8\xf7\xea\xe0\xec \xee\xf1\xe2\xee\xe8\xf2\xfc\xf1\xff&/fam =====================', arg = '', enable = true, waiting = '1.300', deleted = false },
        { cmd = 'fsob', description = '\xd1\xee\xe1\xe5\xf1\xe5\xe4\xee\xe2\xe0\xed\xe8\xe5', text = '\xcf\xf0\xe8\xe2\xe5\xf2, {get_ru_nick}! \xdf {my_name}, {my_rank} \xf1\xe5\xec\xfc\xe8 {family_name}. \xd5\xee\xf7\xe5\xf8\xfc \xea \xed\xe0\xec? \xd0\xe0\xf1\xf1\xea\xe0\xe6\xe8 \xed\xe5\xec\xed\xee\xe3\xee \xee \xf1\xe5\xe1\xe5.', arg = '{arg_id}', enable = true, waiting = '1.500', deleted = false },
        { cmd = 'fwel', description = '\xc2\xe5\xeb\xea\xee\xec \xe2 /fam', text = '/fam \xc4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc \xe2 \xf1\xe5\xec\xfc\xfe, {get_ru_nick}!&/fam \xce\xf1\xec\xee\xf2\xf0\xe8\xf1\xfc, \xf3 \xed\xe0\xf1 \xf2\xf3\xf2 \xe2\xf1\xb8 \xef\xee-\xf1\xe5\xf0\xfc\xb8\xe7\xed\xee\xec\xf3: \xf2\xee\xef \xe0\xe2\xf2\xee\xef\xe0\xf0\xea, \xec\xe0\xea\xf1\xe8\xec\xe0\xeb\xfc\xed\xfb\xe5 \xe7\xe0\xf0\xef\xeb\xe0\xf2\xfb \xe8 \xfd\xeb\xe8\xf2\xea\xe0 \xe2 Arizona Tower.&/fam \xc2\xee\xef\xf0\xee\xf1\xfb \x97 \xef\xe8\xf8\xe8 \xf1\xf2\xe0\xf0\xf8\xe8\xec, \xef\xee\xec\xee\xe6\xe5\xec.', arg = '{arg_id}', enable = true, waiting = '1.500', deleted = false },
        { cmd = 'fcong', description = '\xcf\xee\xe7\xe4\xf0\xe0\xe2\xe8\xf2\xfc', text = '/fam \xcf\xee\xe7\xe4\xf0\xe0\xe2\xeb\xff\xe5\xec {get_ru_nick} \xf1 \xe4\xee\xf1\xf2\xe8\xe6\xe5\xed\xe8\xe5\xec!&/fam \xd2\xe0\xea \xe4\xe5\xf0\xe6\xe0\xf2\xfc, \xe3\xee\xf0\xe6\xf3\xf1\xfc \xf2\xee\xe1\xee\xe9!', arg = '{arg_id}', enable = true, waiting = '1.500', deleted = false },
        { cmd = 'fobj', description = '\xce\xe1\xf9\xe8\xe9 \xf1\xe1\xee\xf0', text = '/fam \xc2\xf1\xe5 \xf1\xe2\xee\xe1\xee\xe4\xed\xfb\xe5 \x97 \xef\xee\xe4\xf2\xff\xe3\xe8\xe2\xe0\xe9\xf2\xe5\xf1\xfc \xea\xee \xec\xed\xe5, \xe5\xf1\xf2\xfc \xf0\xe0\xe7\xe3\xee\xe2\xee\xf0!&/fam \xc4\xe5\xeb\xee \xe2\xe0\xe6\xed\xee\xe5, \xed\xe5 \xe7\xe0\xe4\xe5\xf0\xe6\xf3 \xed\xe0\xe4\xee\xeb\xe3\xee.', arg = '', enable = true, waiting = '1.300', deleted = false },
        { cmd = 'fon', description = '\xce\xed\xeb\xe0\xe9\xed', text = '/fam \xca\xf2\xee \xf1\xe5\xe9\xf7\xe0\xf1 \xed\xe0 \xf1\xe2\xff\xe7\xe8? \xce\xf2\xec\xe5\xf2\xfc\xf2\xe5\xf1\xfc \xef\xeb\xfe\xf1\xe8\xea\xee\xec.', arg = '', enable = true, waiting = '1.500', deleted = false },
        { cmd = 'frank', description = '\xcf\xee\xe2\xfb\xf1\xe8\xf2\xfc (\xd0\xcf)', text = '/me \xee\xf2\xea\xf0\xfb\xe2\xe0\xe5\xf2 \xe1\xe0\xe7\xf3 \xf1\xe5\xec\xfc\xe8 \xed\xe0 \xf2\xe5\xeb\xe5\xf4\xee\xed\xe5&/me \xe2\xed\xee\xf1\xe8\xf2 \xe8\xe7\xec\xe5\xed\xe5\xed\xe8\xff \xef\xee \xf0\xe0\xed\xe3\xf3&/do \xc3\xee\xf2\xee\xe2\xee, \xe2\xf1\xb8 \xf1\xee\xf5\xf0\xe0\xed\xe5\xed\xee.&/famrankedit {arg_id}', arg = '{arg_id}', enable = true, waiting = '1.500', deleted = false },
        { cmd = 'fwarn', description = '\xc2\xfb\xe3\xee\xe2\xee\xf0', text = '/fam {get_ru_nick}, \xfd\xf2\xee \xef\xf0\xe5\xe4\xf3\xef\xf0\xe5\xe6\xe4\xe5\xed\xe8\xe5 \x97 \xee\xf2\xed\xe5\xf1\xe8\xf1\xfc \xf1\xe5\xf0\xfc\xb8\xe7\xed\xe5\xe5 \xea \xef\xf0\xe0\xe2\xe8\xeb\xe0\xec.&/fam \xcf\xee\xe2\xf2\xee\xf0\xe8\xf2\xf1\xff \x97 \xef\xf0\xe8\xe4\xb8\xf2\xf1\xff \xf0\xe0\xf1\xf1\xf2\xe0\xf2\xfc\xf1\xff.', arg = '{arg_id}', enable = true, waiting = '1.500', deleted = false },
        { cmd = 'foffer', description = '\xcd\xe0\xef\xee\xec\xed\xe8\xf2\xfc /offer', text = '\xcd\xe5 \xe7\xe0\xe1\xf3\xe4\xfc \xed\xe0\xef\xe8\xf1\xe0\xf2\xfc /offer \xe2 \xf7\xe0\xf2, \xf7\xf2\xee\xe1\xfb \xef\xf0\xe8\xed\xff\xf2\xfc \xef\xf0\xe8\xe3\xeb\xe0\xf8\xe5\xed\xe8\xe5 \xe2 \xf1\xe5\xec\xfc\xfe!', arg = '{arg_id}', enable = true, waiting = '1.000', deleted = false },
    },
    note = {
        { note_name = '\xcf\xf0\xe0\xe2\xe8\xeb\xe0 \xf1\xe5\xec\xfc\xe8', note_text = '1. \xd3\xe2\xe0\xe6\xe0\xe9 \xe4\xf0\xf3\xe3 \xe4\xf0\xf3\xe3\xe0&2. \xcd\xe5 \xed\xe0\xf0\xf3\xf8\xe0\xe9 \xef\xf0\xe0\xe2\xe8\xeb\xe0 \xf1\xe5\xf0\xe2\xe5\xf0\xe0&3. \xc1\xf3\xe4\xfc \xe0\xea\xf2\xe8\xe2\xe5\xed&4. \xcf\xee\xec\xee\xe3\xe0\xe9 \xed\xee\xe2\xe8\xf7\xea\xe0\xec&5. \xd1\xeb\xf3\xf8\xe0\xe9 \xf1\xf2\xe0\xf0\xf8\xe8\xf5 \xef\xee \xf0\xe0\xed\xe3\xf3&6. \xd3\xf7\xe0\xf1\xf2\xe2\xf3\xe9 \xe2 \xec\xe5\xf0\xee\xef\xf0\xe8\xff\xf2\xe8\xff\xf5', deleted = false },
        { note_name = '\xd0\xe0\xed\xe3\xe8', note_text = '1. \xcd\xee\xe2\xe8\xf7\xee\xea&2. \xd3\xf7\xe0\xf1\xf2\xed\xe8\xea&3. \xd1\xf2\xe0\xf0\xf8\xe8\xe9&4. \xc2\xe5\xf2\xe5\xf0\xe0\xed&5. \xce\xf4\xe8\xf6\xe5\xf0&6. \xd1\xf2\xe0\xf0\xf8\xe8\xe9 \xee\xf4\xe8\xf6\xe5\xf0&7. \xca\xe0\xef\xe8\xf2\xe0\xed&8. \xc7\xe0\xec\xe5\xf1\xf2\xe8\xf2\xe5\xeb\xfc&9. \xd1\xee-\xeb\xe8\xe4\xe5\xf0&10. \xcb\xe8\xe4\xe5\xf0', deleted = false },
    },
}

local configDirectory = getWorkingDirectory():gsub('\\','/') .. "/Family Helper"
local path     = configDirectory .. "/Settings.json"
local log_path = configDirectory .. "/FamilyLog.json"

local famlog = {
    news    = {},
    chat    = {},
    bank    = {},
    coins   = {},
    mute    = {},
    invite  = {},
    level   = {},
    quest   = {},
    rank    = {},
}
local function save_log()
    local file = io.open(log_path, 'w')
    if file then
        local ok, encoded = pcall(encodeJson, famlog)
        file:write(ok and encoded or '{}'); file:close()
    end
end

local function load_log()
    if not doesFileExist(log_path) then return end
    local file = io.open(log_path, 'r')
    if file then
        local contents = file:read('*a'); file:close()
        if contents and contents ~= '' then
            local ok, data = pcall(decodeJson, contents)
            if ok and type(data) == 'table' then
                for k, v in pairs(data) do
                    if famlog[k] and type(v) == 'table' then
                        famlog[k] = v
                    end
                end
            end
        end
    end
end

local function merge_defaults(tbl, defaults)
    for k, v in pairs(defaults) do
        if tbl[k] == nil then tbl[k] = v
        elseif type(v) == 'table' and type(tbl[k]) == 'table' and not v[1] then merge_defaults(tbl[k], v) end
    end
end

local function validate_settings()

      settings.blacklist = settings.blacklist or {}
      settings.quests_stats = settings.quests_stats or {}
      settings.auto_tags = settings.auto_tags or {}
      settings.offline_kick_days = settings.offline_kick_days or 7
      settings.quest_reward_amount = settings.quest_reward_amount or 1000000
    settings.coins_stats = settings.coins_stats or {}
    settings.coin_reward_amount = settings.coin_reward_amount or 10000
    settings.talons_stats = settings.talons_stats or {}
    settings.talon_reward_amount = settings.talon_reward_amount or 30000
  settings.general = settings.general or {}
    settings.interface = settings.interface or {}
    settings.family_info = settings.family_info or {}
    settings.welcome = settings.welcome or {}
    settings.congrats = settings.congrats or {}
    settings.rp_invite = settings.rp_invite or {}
    for _, t in ipairs(settings.piar_templates or {}) do
        t.name=t.name or''; t.lines=t.lines or{}; t.waiting=t.waiting or 1.5; t.auto_interval=t.auto_interval or 300; t.last_time=t.last_time or 0
        if t.enable==nil then t.enable=true end; if t.auto==nil then t.auto=false end
    end
    for _, c in ipairs(settings.commands or {}) do
        c.cmd=c.cmd or''; c.description=c.description or''; c.text=c.text or''; c.arg=c.arg or''; c.waiting=c.waiting or'1.500'
        if c.enable==nil then c.enable=true end; if c.deleted==nil then c.deleted=false end
    end
    for _, n in ipairs(settings.note or {}) do
        n.note_name=n.note_name or''; n.note_text=n.note_text or''; if n.deleted==nil then n.deleted=false end
    end
    for _, i in ipairs(settings.interactions or {}) do
        i.name=i.name or''; i.lines=i.lines or{}; i.waiting=i.waiting or 1.5
    end
    settings.member_action_buttons = settings.member_action_buttons or {}
    for _, b in ipairs(settings.member_action_buttons) do
        b.cmd = b.cmd or ''; b.label = b.label or ''
    end

    if settings.welcome.items and not settings.welcome.variants then
        settings.welcome.variants = {
            { items = settings.welcome.items },
            { items = {
                { text = '{player_name}, \xf0\xe0\xe4\xfb \xe2\xe8\xe4\xe5\xf2\xfc \xf2\xe5\xe1\xff \xf1\xf0\xe5\xe4\xe8 \xed\xe0\xf1!', waiting = 1.5 },
                { text = '\xd1\xe5\xec\xfc\xff {family_name} \x97 \xfd\xf2\xee \xed\xe5 \xef\xf0\xee\xf1\xf2\xee \xf2\xe5\xe3, \xfd\xf2\xee \xea\xee\xec\xe0\xed\xe4\xe0. \xc4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc!', waiting = 2.0 },
                { text = '\xc5\xf1\xeb\xe8 \xf7\xf2\xee-\xf2\xee \xed\xe5\xef\xee\xed\xff\xf2\xed\xee \x97 \xee\xe1\xf0\xe0\xf9\xe0\xe9\xf1\xff, \xf0\xe0\xe7\xe1\xe5\xf0\xb8\xec\xf1\xff \xe2\xec\xe5\xf1\xf2\xe5.', waiting = 1.5 },
            }},
            { items = {
                { text = '\xcd\xee\xe2\xfb\xe9 \xf3\xf7\xe0\xf1\xf2\xed\xe8\xea \xe2 \xf0\xff\xe4\xe0\xf5 {family_name} \x97 {player_name}!', waiting = 1.5 },
                { text = '\xc1\xf3\xe4\xfc \xe0\xea\xf2\xe8\xe2\xe5\xed, \xef\xee\xec\xee\xe3\xe0\xe9 \xf1\xe2\xee\xe8\xec, \xe8 \xe2\xf1\xb8 \xe1\xf3\xe4\xe5\xf2 \xee\xf2\xeb\xe8\xf7\xed\xee.', waiting = 2.0 },
                { text = '\xc4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc \xe4\xee\xec\xee\xe9!', waiting = 1.5 },
            }},
        }
        settings.welcome.items = nil
    end
    if not settings.welcome.variants then
        settings.welcome.variants = {
            { items = {
                { text = '\xc4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc \xe2 \xf1\xe5\xec\xfc\xfe {family_name}, {player_name}!', waiting = 1.5 },
                { text = '\xce\xe7\xed\xe0\xea\xee\xec\xfc\xf1\xff \xf1 \xef\xf0\xe0\xe2\xe8\xeb\xe0\xec\xe8 \xe8 \xf7\xf3\xe2\xf1\xf2\xe2\xf3\xe9 \xf1\xe5\xe1\xff \xea\xe0\xea \xe4\xee\xec\xe0.', waiting = 1.5 },
                { text = '\xcf\xee \xe2\xee\xef\xf0\xee\xf1\xe0\xec \xef\xe8\xf8\xe8 \xe2 /fam, \xe2\xf1\xe5\xe3\xe4\xe0 \xef\xee\xec\xee\xe6\xe5\xec!', waiting = 1.5 },
            }},
            { items = {
                { text = '{player_name}, \xf0\xe0\xe4\xfb \xe2\xe8\xe4\xe5\xf2\xfc \xf2\xe5\xe1\xff \xf1\xf0\xe5\xe4\xe8 \xed\xe0\xf1!', waiting = 1.5 },
                { text = '\xd1\xe5\xec\xfc\xff {family_name} \x97 \xfd\xf2\xee \xed\xe5 \xef\xf0\xee\xf1\xf2\xee \xf2\xe5\xe3, \xfd\xf2\xee \xea\xee\xec\xe0\xed\xe4\xe0. \xc4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc!', waiting = 2.0 },
                { text = '\xc5\xf1\xeb\xe8 \xf7\xf2\xee-\xf2\xee \xed\xe5\xef\xee\xed\xff\xf2\xed\xee \x97 \xee\xe1\xf0\xe0\xf9\xe0\xe9\xf1\xff, \xf0\xe0\xe7\xe1\xe5\xf0\xb8\xec\xf1\xff \xe2\xec\xe5\xf1\xf2\xe5.', waiting = 1.5 },
            }},
            { items = {
                { text = '\xcd\xee\xe2\xfb\xe9 \xf3\xf7\xe0\xf1\xf2\xed\xe8\xea \xe2 \xf0\xff\xe4\xe0\xf5 {family_name} \x97 {player_name}!', waiting = 1.5 },
                { text = '\xc1\xf3\xe4\xfc \xe0\xea\xf2\xe8\xe2\xe5\xed, \xef\xee\xec\xee\xe3\xe0\xe9 \xf1\xe2\xee\xe8\xec, \xe8 \xe2\xf1\xb8 \xe1\xf3\xe4\xe5\xf2 \xee\xf2\xeb\xe8\xf7\xed\xee.', waiting = 2.0 },
                { text = '\xc4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc \xe4\xee\xec\xee\xe9!', waiting = 1.5 },
            }},
        }
    end
    if settings.welcome.variant_idx == nil then settings.welcome.variant_idx = 0 end
    while #settings.welcome.variants < 3 do
        table.insert(settings.welcome.variants, { items = {{text='\xc4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc, {player_name}!', waiting=1.5}} })
    end
    for _, v in ipairs(settings.welcome.variants) do v.items = v.items or {} end

    if settings.congrats.items and not settings.congrats.variants then
        settings.congrats.variants = {
            { items = settings.congrats.items },
            { items = {
                { text = '{player_name}, \xef\xee\xe7\xe4\xf0\xe0\xe2\xeb\xff\xfe \xf1 \xed\xee\xe2\xfb\xec \xf3\xf0\xee\xe2\xed\xe5\xec!', waiting = 1.5 },
                { text = '\xcf\xf0\xee\xea\xe0\xf7\xea\xe0 \xe8\xe4\xb8\xf2 \xef\xee\xeb\xed\xfb\xec \xf5\xee\xe4\xee\xec, \xef\xf0\xee\xe4\xee\xeb\xe6\xe0\xe9 \xe2 \xf2\xee\xec \xe6\xe5 \xe4\xf3\xf5\xe5!', waiting = 2.0 },
            }},
            { items = {
                { text = '\xce, {player_name} \xef\xee\xe4\xed\xff\xeb \xf3\xf0\xee\xe2\xe5\xed\xfc!', waiting = 1.5 },
                { text = '\xd0\xe0\xf1\xf2\xb8\xf8\xfc \xed\xe5 \xef\xee \xe4\xed\xff\xec, \xe0 \xef\xee \xf7\xe0\xf1\xe0\xec. \xd2\xe0\xea \xe4\xe5\xf0\xe6\xe0\xf2\xfc!', waiting = 2.0 },
            }},
        }
        settings.congrats.items = nil
    end
    if not settings.congrats.variants then
        settings.congrats.variants = {
            { items = {
                { text = '\xcf\xee\xe7\xe4\xf0\xe0\xe2\xeb\xff\xfe \xf1 \xed\xee\xe2\xfb\xec \xf3\xf0\xee\xe2\xed\xe5\xec, {player_name}!', waiting = 1.5 },
                { text = '\xd5\xee\xf0\xee\xf8\xe8\xe9 \xf0\xe5\xe7\xf3\xeb\xfc\xf2\xe0\xf2, \xf2\xe0\xea \xe4\xe5\xf0\xe6\xe0\xf2\xfc!', waiting = 2.0 },
            }},
            { items = {
                { text = '{player_name}, \xef\xee\xe7\xe4\xf0\xe0\xe2\xeb\xff\xfe \xf1 \xed\xee\xe2\xfb\xec \xf3\xf0\xee\xe2\xed\xe5\xec!', waiting = 1.5 },
                { text = '\xcf\xf0\xee\xea\xe0\xf7\xea\xe0 \xe8\xe4\xb8\xf2 \xef\xee\xeb\xed\xfb\xec \xf5\xee\xe4\xee\xec, \xef\xf0\xee\xe4\xee\xeb\xe6\xe0\xe9 \xe2 \xf2\xee\xec \xe6\xe5 \xe4\xf3\xf5\xe5!', waiting = 2.0 },
            }},
            { items = {
                { text = '\xce, {player_name} \xef\xee\xe4\xed\xff\xeb \xf3\xf0\xee\xe2\xe5\xed\xfc!', waiting = 1.5 },
                { text = '\xd0\xe0\xf1\xf2\xb8\xf8\xfc \xed\xe5 \xef\xee \xe4\xed\xff\xec, \xe0 \xef\xee \xf7\xe0\xf1\xe0\xec. \xd2\xe0\xea \xe4\xe5\xf0\xe6\xe0\xf2\xfc!', waiting = 2.0 },
            }},
        }
    end
    if settings.congrats.variant_idx == nil then settings.congrats.variant_idx = 0 end
    while #settings.congrats.variants < 3 do
        table.insert(settings.congrats.variants, { items = {{text='\xcf\xee\xe7\xe4\xf0\xe0\xe2\xeb\xff\xfe \xf1 \xf3\xf0\xee\xe2\xed\xe5\xec, {player_name}!', waiting=2.0}} })
    end
    for _, v in ipairs(settings.congrats.variants) do v.items = v.items or {} end
    settings.rp_invite.text=settings.rp_invite.text or''; settings.rp_invite.waiting=settings.rp_invite.waiting or 1.5
    settings.family_info.family_name=settings.family_info.family_name or''; settings.family_info.my_name=settings.family_info.my_name or''
    settings.family_info.my_rank=settings.family_info.my_rank or''; settings.family_info.family_tag=settings.family_info.family_tag or''
    settings.family_info.leader_name=settings.family_info.leader_name or''; settings.family_info.my_rank_number=settings.family_info.my_rank_number or 1
    settings.general.float_btn_x=settings.general.float_btn_x or 40; settings.general.float_btn_y=settings.general.float_btn_y or 300
    settings.general.float_btn_radius=settings.general.float_btn_radius or 15; settings.general.float_btn_size=settings.general.float_btn_size or 1.0
    settings.general.auto_mute_spam_time = settings.general.auto_mute_spam_time or 30
    settings.general.auto_mute_flood_time = settings.general.auto_mute_flood_time or 30
    settings.general.invite_unpaid = settings.general.invite_unpaid or 0
    settings.general.invite_price_normal = settings.general.invite_price_normal or 2000000
    settings.general.invite_price_bonus = settings.general.invite_price_bonus or 4000000
    settings.general.invite_bonus_threshold = settings.general.invite_bonus_threshold or 50
    if not settings.coins_thanks then
        settings.coins_thanks = {
            items = {{ text = '/b \xd1\xef\xe0\xf1\xe8\xe1\xee, {player_name}! \xcc\xee\xed\xe5\xf2\xfb \xef\xf0\xe8\xed\xff\xf2\xfb!', waiting = 1.0 }},
            use_fam = false, enabled = true
        }
    end
    if not settings.tg then
        settings.tg = {
            token    = '',
            chat_id  = '',
            enabled  = false,
            role     = 'main',
            auto_role = true,
            ev_invite  = true,
            ev_join    = true,
            ev_leave   = true,
            ev_level   = true,
            ev_quest   = true,
            ev_mute    = true,
            ev_coins   = true,
            ev_bank    = true,
            last_update_id = 0,
            last_group_msg_id = 0,
            bot_username = 'FamilyGrozzybot',
            my_chat_id = '',
            relay_chat_id = '',
            relay_ids = {},
            registered = false,
        }
    end
    if settings.tg and settings.tg.role == nil then
        settings.tg.role = 'main'; save_settings()
    end
    if settings.tg and settings.tg.auto_role == nil then
        settings.tg.auto_role = true; save_settings()
    end
    if not settings.log_enabled then
        settings.log_enabled = {
            news   = true,
            chat   = false,
            bank   = true,
            coins  = true,
            mute   = true,
            invite = true,
            level  = true,
            quest  = true,
            rank   = true,
        }
    end
    if settings.log_enabled and settings.log_enabled.news == nil then
        settings.log_enabled.news = true; save_settings()
    end
    if settings.log_enabled and settings.log_enabled.chat == nil then
        settings.log_enabled.chat = false; save_settings()
    end
    if not settings.reconnect then
        settings.reconnect = { enabled=false, auto_login=false, on_kicked=true, on_banned=false,
            on_rejected=true, on_password=false, delay=5.0, login='', password='', spawn_json='', spawn_use=0 }
    end
    if settings.reconnect.delay == nil then settings.reconnect.delay = 5.0 end
    if settings.reconnect.spawn_json == nil then settings.reconnect.spawn_json = '' end
    if settings.reconnect.spawn_use == nil then settings.reconnect.spawn_use = 0 end
    if settings.reconnect.login == nil then settings.reconnect.login = '' end
    if settings.reconnect.password == nil then settings.reconnect.password = '' end
    if not settings.invite_stats then
        settings.invite_stats = {}
    end
    if not settings.quest_congrats then settings.quest_congrats = { use_fam = true, enabled = true } end

    if settings.quest_congrats.items and not settings.quest_congrats.variants then
        settings.quest_congrats.variants = {
            { items = settings.quest_congrats.items },
            { items = {
                { text = '{player_name}, \xea\xe2\xe5\xf1\xf2 \xf1\xe4\xe0\xed \x97 \xec\xee\xeb\xee\xe4\xe5\xf6, \xed\xe5 \xeb\xe5\xed\xe8\xf8\xfc\xf1\xff!', waiting = 1.5 },
                { text = '\xcf\xf0\xee\xe4\xee\xeb\xe6\xe0\xe9 \xe2 \xf2\xee\xec \xe6\xe5 \xe4\xf3\xf5\xe5, \xf1\xe5\xec\xfc\xff \xfd\xf2\xee \xf6\xe5\xed\xe8\xf2.', waiting = 2.0 },
            }},
            { items = {
                { text = '\xd5\xee\xf0\xee\xf8\xe0\xff \xf0\xe0\xe1\xee\xf2\xe0, {player_name}!', waiting = 1.5 },
                { text = '\xca\xe2\xe5\xf1\xf2 \xe2\xfb\xef\xee\xeb\xed\xe5\xed, \xf1\xe5\xec\xfc\xff \xf0\xe0\xf1\xf2\xb8\xf2. \xd2\xe0\xea \xe4\xe5\xf0\xe6\xe0\xf2\xfc!', waiting = 2.0 },
            }},
        }
        settings.quest_congrats.items = nil
    end
    if not settings.quest_congrats.variants then
        settings.quest_congrats.variants = {
            { items = {
                { text = '{player_name}, \xee\xf2\xeb\xe8\xf7\xed\xe0\xff \xf0\xe0\xe1\xee\xf2\xe0! \xca\xe2\xe5\xf1\xf2 \xe2\xfb\xef\xee\xeb\xed\xe5\xed!', waiting = 1.5 },
                { text = '\xd2\xe0\xea \xe4\xe5\xf0\xe6\xe0\xf2\xfc, \xef\xf0\xee\xe4\xee\xeb\xe6\xe0\xe9 \xe2 \xf2\xee\xec \xe6\xe5 \xe4\xf3\xf5\xe5!', waiting = 2.0 },
            }},
            { items = {
                { text = '{player_name}, \xea\xe2\xe5\xf1\xf2 \xf1\xe4\xe0\xed \x97 \xec\xee\xeb\xee\xe4\xe5\xf6, \xed\xe5 \xeb\xe5\xed\xe8\xf8\xfc\xf1\xff!', waiting = 1.5 },
                { text = '\xcf\xf0\xee\xe4\xee\xeb\xe6\xe0\xe9 \xe2 \xf2\xee\xec \xe6\xe5 \xe4\xf3\xf5\xe5, \xf1\xe5\xec\xfc\xff \xfd\xf2\xee \xf6\xe5\xed\xe8\xf2.', waiting = 2.0 },
            }},
            { items = {
                { text = '\xd5\xee\xf0\xee\xf8\xe0\xff \xf0\xe0\xe1\xee\xf2\xe0, {player_name}!', waiting = 1.5 },
                { text = '\xca\xe2\xe5\xf1\xf2 \xe2\xfb\xef\xee\xeb\xed\xe5\xed, \xf1\xe5\xec\xfc\xff \xf0\xe0\xf1\xf2\xb8\xf2. \xd2\xe0\xea \xe4\xe5\xf0\xe6\xe0\xf2\xfc!', waiting = 2.0 },
            }},
        }
    end
    if settings.quest_congrats.variant_idx == nil then settings.quest_congrats.variant_idx = 0 end
    while #settings.quest_congrats.variants < 3 do
        table.insert(settings.quest_congrats.variants, { items = {{text='{player_name}, \xea\xe2\xe5\xf1\xf2 \xe2\xfb\xef\xee\xeb\xed\xe5\xed!', waiting=1.5}} })
    end
    for _, v in ipairs(settings.quest_congrats.variants) do v.items = v.items or {} end

    local function def_bool(tbl, key, default)
        if tbl[key] == nil then tbl[key] = default end
    end
    def_bool(settings.quest_congrats, 'enabled', true)
    if not settings.general.keyword_invite_list or #settings.general.keyword_invite_list == 0 then
        settings.general.keyword_invite_list = {'\xe8\xed\xe2', '\xe8\xed\xe2\xe0\xe9\xf2', '\xe8\xed\xe2\xe0\xe9\xf2 \xef\xe6', '\xec\xee\xe6\xed\xee \xe2 \xf4\xe0\xec', '\xef\xf0\xe8\xec\xe8', '\xe8\xed\xe2 \xe2 \xf4\xe0\xec\xf3', '\xef\xf0\xe8\xec\xe8 \xe2 \xf1\xe5\xec\xfc\xfe', '\xf5\xee\xf7\xf3 \xe2 \xf4\xe0\xec', '\xe2\xee\xe7\xfc\xec\xe8 \xe2 \xf1\xe5\xec\xfc\xfe'}
    end
    def_bool(settings.general, 'auto_welcome',        true)
    def_bool(settings.general, 'auto_congrats',       true)
    def_bool(settings.general, 'auto_quest_congrats', true)
    def_bool(settings.general, 'auto_keyword_invite', true)
    def_bool(settings.general, 'auto_invite',         false)
    def_bool(settings.general, 'rp_chat',             true)
    def_bool(settings.general, 'auto_ad_confirm', false)
    def_bool(settings.general, 'auto_storage_collect', false)
    def_bool(settings.general, 'auto_rp_guns', false)
    if settings.general.auto_ad_station_idx == nil then settings.general.auto_ad_station_idx = 2 end
    if settings.general.auto_ad_type        == nil then settings.general.auto_ad_type        = 0 end
    def_bool(settings.general, 'auto_mute_insults',   false)
    def_bool(settings.general, 'auto_mute_spam',      false)
    def_bool(settings.general, 'auto_mute_flood',     false)
    def_bool(settings.general, 'float_btn_enable',    true)
    def_bool(settings.general, 'auto_nearby_poll',    true)

    if settings.general.flood_msg_count == nil then settings.general.flood_msg_count = 5 end
    if settings.general.flood_interval  == nil then settings.general.flood_interval  = 15 end
    settings.invite_history = settings.invite_history or {}
    if settings.general.float_btn_enable==nil then settings.general.float_btn_enable=true end
    settings.interface.accent_r=settings.interface.accent_r or 0.6; settings.interface.accent_g=settings.interface.accent_g or 0.302
    settings.interface.accent_b=settings.interface.accent_b or 0.902; settings.interface.window_alpha=settings.interface.window_alpha or 1.0
    settings.interface.bg_brightness=settings.interface.bg_brightness or 0.05
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
                    settings = loaded; merge_defaults(settings, default_settings); validate_settings()
                    if settings.general.version ~= thisScript().version then settings.general.version = thisScript().version; save_settings() end
                else settings = default_settings end
            end
        else settings = default_settings end
    end
    validate_settings()
end

function save_settings()
    local file = io.open(path, 'w')
    if file then
        local ok, encoded = pcall(encodeJson, settings)
        file:write(ok and encoded or ""); file:close(); return ok
    end
    return false
end

load_settings()
load_log()

function isMonetLoader() return MONET_VERSION ~= nil end

if isMonetLoader() then
    gta = ffi.load('GTASA')
    pcall(ffi.cdef, [[ void _Z12AND_OpenLinkPKc(const char* link); ]])
end

if not settings.general.autofind_dpi then
    if isMonetLoader() then
        settings.general.custom_dpi = MONET_DPI_SCALE or 1.0
    else
        local bw, bh = 1366, 768; local cw, ch = getScreenResolution()
        settings.general.custom_dpi = ((cw / bw) + (ch / bh)) / 2
    end
    settings.general.autofind_dpi = true; save_settings()
end

local imgui = require('mimgui')
local sizeX, sizeY = getScreenResolution()

local fa_icon = require('lib.fAwesome6_solid')
local fa_font_src = require('lib.fAwesome6')
imgui.OnInitialize(function()
    local io = imgui.GetIO()
    local icon_ranges = imgui.new.ImWchar[3](fa_icon.min_range, fa_icon.max_range, 0)

    local icon_cfg = imgui.ImFontConfig()
    icon_cfg.MergeMode = true
    icon_cfg.PixelSnapH = true
    icon_cfg.GlyphMinAdvanceX = 15 * MONET_DPI_SCALE
    io.Fonts:AddFontFromMemoryCompressedBase85TTF(
        fa_font_src.get_font_data_base85('solid'),
        15 * MONET_DPI_SCALE,
        icon_cfg,
        icon_ranges
    )
end)

if not settings.general.float_btn_pos_init then
    settings.general.float_btn_x = sizeX - 190
    settings.general.float_btn_y = math.floor(sizeY * 0.42)
    settings.general.float_btn_pos_init = true
    save_settings()
end

local function fh_labeled_inputs_row(fields, on_change)
    local d = (settings and settings.general and settings.general.custom_dpi) or 1
    local n = #fields
    local win_w = imgui.GetWindowContentRegionWidth()
    local gap = 16*d
    local labels_w = 0
    for _, f in ipairs(fields) do
        labels_w = labels_w + imgui.CalcTextSize(f.label).x + 6*d
    end
    local min_field_w = 70*d
    local avail_for_fields = win_w - labels_w - gap*(n-1)
    local field_w = math.max(min_field_w, avail_for_fields / n)
    local fits_row = avail_for_fields >= (min_field_w * n)
    for i, f in ipairs(fields) do
        if i > 1 then
            if fits_row then imgui.SameLine(0, gap) else imgui.Spacing() end
        end
        imgui.PushItemWidth(field_w)
        f.buf[0] = f.value
        if imgui.InputInt('##'..f.id, f.buf, 0) then end
        if imgui.IsItemDeactivatedAfterEdit() and on_change then on_change(i, f.buf[0]) end
        imgui.PopItemWidth()
        imgui.SameLine()
        imgui.Text(f.label)
    end
end

local _fh_scroll_state = {}
local function fh_touch_scroll(child_id)
    local down = imgui.IsMouseDown(0)

    if _fh_scroll_state[child_id] then
        if not down then
            _fh_scroll_state[child_id] = nil
            return
        end
        local io = imgui.GetIO()
        local dy = io.MouseDelta.y
        if dy ~= 0 then
            imgui.SetScrollY(imgui.GetScrollY() - dy)
        end
        return
    end

    if not down then return end

    local hovered = imgui.IsWindowHovered(imgui.HoveredFlags.ChildWindows
        + imgui.HoveredFlags.AllowWhenBlockedByActiveItem
        + imgui.HoveredFlags.AllowWhenOverlapped
        + imgui.HoveredFlags.AllowWhenBlockedByPopup)
    if not hovered then return end

    local io = imgui.GetIO()
    if math.abs(io.MouseDelta.y) > 0.5 and math.abs(io.MouseDelta.y) >= math.abs(io.MouseDelta.x) then
        _fh_scroll_state[child_id] = true
        imgui.SetScrollY(imgui.GetScrollY() - io.MouseDelta.y)
    end
end

local function fh_toggle(id, is_on, w, h)
    local d = (settings and settings.general and settings.general.custom_dpi) or 1
    w = w or 44*d
    h = h or 24*d
    local draw_list = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    local clicked = false

    imgui.InvisibleButton(id, imgui.ImVec2(w, h))
    if imgui.IsItemClicked() then clicked = true end
    local hovered = imgui.IsItemHovered()

    local radius = h / 2
    local col_on_bg     = imgui.ImVec4(0.16, 0.56, 0.20, 1)
    local col_on_bg_hov = imgui.ImVec4(0.20, 0.66, 0.24, 1)
    local col_off_bg     = imgui.ImVec4(0.30, 0.30, 0.32, 1)
    local col_off_bg_hov = imgui.ImVec4(0.38, 0.38, 0.40, 1)
    local bg = is_on and (hovered and col_on_bg_hov or col_on_bg) or (hovered and col_off_bg_hov or col_off_bg)
    local bg_u32 = imgui.GetColorU32Vec4(bg)

    local p_min = imgui.ImVec2(pos.x, pos.y)
    local p_max = imgui.ImVec2(pos.x + w, pos.y + h)
    draw_list:AddRectFilled(p_min, p_max, bg_u32, radius)

    local pad = 2*d
    local knob_r = radius - pad
    local knob_x = is_on and (pos.x + w - radius) or (pos.x + radius)
    local knob_y = pos.y + radius
    local knob_col = imgui.GetColorU32Vec4(imgui.ImVec4(1, 1, 1, 1))
    draw_list:AddCircleFilled(imgui.ImVec2(knob_x, knob_y), knob_r, knob_col, 20)

    return clicked
end

local function fh_toggle_row(label, id, is_on, row_w)
    local d = (settings and settings.general and settings.general.custom_dpi) or 1
    local tw = 40*d
    local th = 20*d
    imgui.AlignTextToFramePadding()
    if row_w then
        imgui.Text(label)
        imgui.SameLine(row_w - tw - 6*d)
    else
        imgui.Text(label)
        imgui.SameLine()
    end
    local changed = fh_toggle(id, is_on, tw, th)
    return changed
end
local MainWindow = imgui.new.bool()
local fh_side_tab = 1
local fh_side_tabs = {
    { id = 1,  label = u8'\xc3\xeb\xe0\xe2\xed\xee\xe5',        icon = fa_icon.HOUSE,           icon_color = imgui.ImVec4(0.36, 0.68, 1.00, 1) },
    { id = 2,  label = u8'\xca\xee\xec\xe0\xed\xe4\xfb',        icon = fa_icon.TERMINAL,        icon_color = imgui.ImVec4(0.60, 0.60, 0.65, 1) },
    { id = 3,  label = u8'\xc0\xe2\xf2\xee\xef\xe8\xe0\xf0',   icon = fa_icon.BULLHORN,        icon_color = imgui.ImVec4(1.00, 0.65, 0.20, 1) },
    { id = 4,  label = u8'\xd3\xf7\xe0\xf1\xf2\xed\xe8\xea\xe8', icon = fa_icon.USERS,        icon_color = imgui.ImVec4(0.30, 0.75, 0.95, 1) },
    { id = 5,  label = u8'\xcf\xf0\xe5\xec\xe8\xe8',            icon = fa_icon.MONEY_BILL_WAVE, icon_color = imgui.ImVec4(0.30, 0.85, 0.40, 1) },
    { id = 6,  label = u8'\xc8\xed\xe2\xe0\xe9\xf2\xfb',        icon = fa_icon.USER_PLUS,       icon_color = imgui.ImVec4(0.55, 0.75, 1.00, 1) },
    { id = 7,  label = u8'\xcb\xee\xe3',                            icon = fa_icon.CLIPBOARD_LIST,  icon_color = imgui.ImVec4(0.85, 0.85, 0.30, 1) },
    { id = 8,  label = u8'\xd0\xe5\xea\xee\xed\xed\xe5\xea\xf2', icon = fa_icon.GEAR, icon_color = imgui.ImVec4(0.65, 0.65, 0.70, 1) },
    { id = 9,  label = u8'Telegram',                                   icon = fa_icon.PAPER_PLANE,     icon_color = imgui.ImVec4(0.20, 0.65, 1.00, 1) },
    { id = 10, label = u8'\xc2\xe8\xe4',                            icon = fa_icon.EYE,             icon_color = imgui.ImVec4(0.80, 0.55, 1.00, 1) },
    { id = 11, label = u8'Wiki',                                       icon = fa_icon.BOOK,            icon_color = imgui.ImVec4(0.95, 0.75, 0.35, 1) },
}
local InteractMenu = imgui.new.bool()

  local qa = {
    bl_name       = imgui.new.char[256](""),
    bl_reason     = imgui.new.char[256](""),
    offline_days  = imgui.new.int(7),
    reward_amount = imgui.new.int(50000),
    tag_rank      = imgui.new.char[32](""),
    tag_text      = imgui.new.char[128](""),

    mute_id       = imgui.new.char[32](""),
    mute_time     = imgui.new.char[32](""),
    mute_reason   = imgui.new.char[128](""),
    rank_id       = imgui.new.char[32](""),
    rank_val      = imgui.new.char[32](""),
    kick_id       = imgui.new.char[32](""),
    kick_reason   = imgui.new.char[128](""),
    warn_id       = imgui.new.char[32](""),
    warn_reason   = imgui.new.char[128](""),
    invite_id     = imgui.new.char[32](""),
    unmute_id     = imgui.new.char[32](""),
    offkick_nick  = imgui.new.char[64](""),
  }

local InteractSelectPlayer = imgui.new.bool()
local FastMenu = imgui.new.bool()
local NoteWindow = imgui.new.bool()
local BinderWindow = imgui.new.bool()
local CommandStopWindow = imgui.new.bool()
local CommandPauseWindow = imgui.new.bool()
local PiarEditWindow = imgui.new.bool()
local InteractEditWindow = imgui.new.bool()
local piar_edit_index = nil
local interact_edit_index = nil

local input_family_name = imgui.new.char[256](u8(settings.family_info.family_name))
local input_family_tag = imgui.new.char[256](u8(settings.family_info.family_tag))
local input_my_name = imgui.new.char[256](u8(settings.family_info.my_name))
local input_my_rank = imgui.new.char[256](u8(settings.family_info.my_rank))
local sl = {
  dpi          = imgui.new.float(tonumber(settings.general.custom_dpi) or 1),
  font_scale   = imgui.new.float(tonumber(settings.general.custom_font_scale) or 1),
  invite_radius = imgui.new.float(settings.general.auto_invite_radius),
  invite_delay  = imgui.new.float(settings.general.auto_invite_delay),
  float_size    = imgui.new.float(settings.general.float_btn_size or 1.0),
  float_radius  = imgui.new.float(settings.general.float_btn_radius or 15),
  window_alpha  = imgui.new.float(settings.interface.window_alpha or 0.97),
  bg_bright     = imgui.new.float(settings.interface.bg_brightness or 0.13),
    auto_mute_time = imgui.new.int(settings.general.auto_mute_insults_time or 60),
  auto_mute_spam_time = imgui.new.int(settings.general.auto_mute_spam_time or 30),
  auto_mute_flood_time = imgui.new.int(settings.general.auto_mute_flood_time or 30),
}
local accent_color = imgui.new.float[3](settings.interface.accent_r or 1.0, settings.interface.accent_g or 0.65, settings.interface.accent_b or 0.0)
local waiting_slider = imgui.new.float(0)
local ComboTags = imgui.new.int()
local item_list = {u8'\xc1\xe5\xe7 \xe0\xf0\xe3\xf3\xec\xe5\xed\xf2\xe0', u8'{arg} - \xeb\xfe\xe1\xee\xe9', u8'{arg_id} - ID', u8'{arg_id} {arg2} - ID+\xf2\xe5\xea\xf1\xf2'}
local ImItems
do
    local _ok, _result = pcall(function()
        return imgui.new['const char*'][#item_list](item_list)
    end)
    if _ok and _result then
        ImItems = _result
    else
        local _tmp = imgui.new['const char*'][#item_list]()
        for _i = 0, #item_list - 1 do _tmp[_i] = item_list[_i + 1] end
        ImItems = _tmp
    end
end
local change_waiting, change_cmd, change_description, change_text, change_arg
local kw_input = imgui.new.char[128]("")
local event_log = {}
local congrats_batch = {}
local congrats_batch_timer = nil
local CONGRATS_BATCH_WINDOW = 2
local CONGRATS_BATCH_SINGLE = 2
local CONGRATS_BATCH_MSG = '\xd0\xe5\xe1\xff\xf2\xe0, \xec\xee\xeb\xee\xe4\xf6\xfb! {names} \xef\xee\xe2\xfb\xf1\xe8\xeb\xe8 \xf3\xf0\xee\xe2\xe5\xed\xfc! \xd2\xe0\xea \xe4\xe5\xf0\xe6\xe0\xf2\xfc!'
local CONGRATS_BATCH_MSGS = {
    '\xd0\xe5\xe1\xff\xf2\xe0, \xec\xee\xeb\xee\xe4\xf6\xfb! {names} \xef\xee\xe2\xfb\xf1\xe8\xeb\xe8 \xf3\xf0\xee\xe2\xe5\xed\xfc! \xd2\xe0\xea \xe4\xe5\xf0\xe6\xe0\xf2\xfc!',
    '{names} \x97 \xef\xee\xe7\xe4\xf0\xe0\xe2\xeb\xff\xfe \xf1 \xed\xee\xe2\xfb\xec \xf3\xf0\xee\xe2\xed\xe5\xec! \xcf\xf0\xee\xea\xe0\xf7\xea\xe0 \xe8\xe4\xb8\xf2!',
    '\xce\xf2\xeb\xe8\xf7\xed\xe0\xff \xf0\xe0\xe1\xee\xf2\xe0, {names}! \xd3\xf0\xee\xe2\xe5\xed\xfc \xef\xee\xe4\xed\xff\xf2, \xef\xf0\xee\xe4\xee\xeb\xe6\xe0\xe9\xf2\xe5 \xe2 \xf2\xee\xec \xe6\xe5 \xe4\xf3\xf5\xe5!',
}
local CONGRATS_BATCH_MSG_IDX = 0
local fmembers_online = {}
local fmembers_offline = {}
local debug_dialog = false
local FAMLOG_MAX = 999999
local fmembers_last_update = 0
local fh_fammenu_data = nil
local fh_fammenu_last_update = 0
local fmember_ctx_nick = nil
local pending_call_nick = nil
local pending_sms_nick = nil
local pending_sms_text = ''

local tg_token_buf  = nil
local tg_chatid_buf = nil
local fmember_ctx_open = false
local MemberCtxWindow = imgui.new.bool(false)
local ctx_rank_input = imgui.new.int(1)
local ctx_reason_buf = imgui.new.char[128]('')
local ctx_mute_min   = imgui.new.int(10)
local ctx_tag_buf    = imgui.new.char[64]('')

local AddActionBtnWindow = imgui.new.bool(false)
local aab_label_buf = imgui.new.char[64]('')
local aab_cmd_selected_idx = imgui.new.int(0)
local function log_event(msg)
    table.insert(event_log, 1, os.date('[%H:%M] ') .. msg)
    if #event_log > 20 then table.remove(event_log) end
end
local interact_player_id = nil
local player_id = nil
local isActiveCommand = false
local command_stop = false
local command_pause = false
local reload_script = false
local edit_note_index = nil
local note_name_buf = imgui.new.char[128]('')
local note_text_buf = imgui.new.char[4096]('')
local invited_players = {}
local invite_price_normal_input = imgui.new.int(settings.general.invite_price_normal or 2000000)
local invite_price_bonus_input  = imgui.new.int(settings.general.invite_price_bonus or 4000000)
local invite_bonus_thresh_input = imgui.new.int(settings.general.invite_bonus_threshold or 50)
local message_color = 0xFFA500
local message_color_hex = '{FFA500}'
local nearby_players = {}
local invite_session = 0
local nearby_time = 0

function TranslateNick(name)
    if not name or name == '' then return '' end
    if name:match('%a+') then
        for k, v in pairs({['ph']='\xf4',['Ph']='\xd4',['Ch']='\xd7',['ch']='\xf7',['Th']='\xd2',['th']='\xf2',['Sh']='\xd8',['sh']='\xf8',['Ck']='\xca',['ck']='\xea',['Kh']='\xd5',['kh']='\xf5',['Zh']='\xc6',['zh']='\xe6',['Yu']='\xde',['yu']='\xfe',['Yo']='\xa8',['yo']='\xb8',['Ya']='\xdf',['ya']='\xff',['oo']='\xf3',['ee']='\xe8'}) do name = name:gsub(k, v) end
        for k, v in pairs({['B']='\xc1',['Z']='\xc7',['T']='\xd2',['Y']='\xc9',['P']='\xcf',['J']='\xc4\xe6',['X']='\xca\xf1',['G']='\xc3',['V']='\xc2',['H']='\xd5',['N']='\xcd',['E']='\xc5',['I']='\xc8',['D']='\xc4',['O']='\xce',['K']='\xca',['F']='\xd4',['A']='\xc0',['C']='\xca',['L']='\xcb',['M']='\xcc',['W']='\xc2',['Q']='\xca',['U']='\xc0',['R']='\xd0',['S']='\xd1',['h']='\xf5',['q']='\xea',['y']='\xe8',['a']='\xe0',['w']='\xe2',['b']='\xe1',['v']='\xe2',['g']='\xe3',['d']='\xe4',['e']='\xe5',['z']='\xe7',['i']='\xe8',['j']='\xe6',['k']='\xea',['l']='\xeb',['m']='\xec',['n']='\xed',['o']='\xee',['p']='\xef',['r']='\xf0',['s']='\xf1',['t']='\xf2',['u']='\xf3',['f']='\xf4',['x']='\xea\xf1',['c']='\xea',['_']=' '}) do name = name:gsub(k, v) end
    end
    return name
end

function string.rupper(s)
    if not s or #s == 0 then return s or '' end
    local b = s:byte(1)
    if b and b >= 224 and b <= 255 then return string.char(b - 32) .. s:sub(2) end
    return s:sub(1,1):upper() .. s:sub(2)
end

function isParamSampID(id)
    id = tonumber(id)
    if id and id >= 0 and id <= 999 then return id == select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) or sampIsPlayerConnected(id) end
    return false
end

function get_players_in_radius(radius)
    local result = {}
    local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    local mx, my, mz = getCharCoordinates(PLAYER_PED)
    for _, h in pairs(getAllChars()) do
        if h ~= PLAYER_PED and doesCharExist(h) then
            local res, id = sampGetPlayerIdByCharHandle(h)
            if res and id ~= -1 and sampIsPlayerConnected(id) then
                local x, y, z = getCharCoordinates(h)
                if getDistanceBetweenCoords3d(mx, my, mz, x, y, z) <= radius then
                    table.insert(result, id)
                end
            end
        end
    end
    return result
end

function processText(text, target_id)
    if not text then return '' end
    if target_id then
        local nick = sampGetPlayerNickname(target_id) or ''
        local ru_nick = TranslateNick(nick)
        local rp_nick = nick:gsub('_', ' ')
        text = text:gsub('%{get_ru_nick%(%{arg_id%}%)%}', ru_nick)
        text = text:gsub('%{get_rp_nick%(%{arg_id%}%)%}', rp_nick)
        text = text:gsub('%{get_nick%(%{arg_id%}%)%}', nick)
        text = text:gsub('{get_ru_nick}', ru_nick)
        text = text:gsub('{get_rp_nick}', rp_nick)
        text = text:gsub('{get_nick}', nick)
        text = text:gsub('{arg_id}', tostring(target_id))
    end
    text = text:gsub('{my_name}', settings.family_info.my_name or '')
    text = text:gsub('{my_rank}', settings.family_info.my_rank or '')
    text = text:gsub('{family_name}', settings.family_info.family_name or '')
    text = text:gsub('{family_tag}', settings.family_info.family_tag or '')
    text = text:gsub('{leader_name}', settings.family_info.leader_name or '')
    text = text:gsub('{my_id}', tostring(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))))
    text = text:gsub('{my_nick}', sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) or '')
    text = text:gsub('{get_time}', os.date("%H:%M:%S"))
    text = text:gsub('{get_date}', os.date("%d.%m.%Y"))
    return text
end

function fh_apply_dpi_style()
end

function change_dpi()

    if not isMonetLoader() then imgui.SetWindowFontScale(settings.general.custom_dpi) end

    local fs = tonumber(settings.general.custom_font_scale) or 1
    imgui.GetIO().FontGlobalScale = math.max(0.3, math.min(3.0, fs))
end

function send_lines(text, waiting, target_id, callback)
    if isActiveCommand then sampAddChatMessage('[Family Helper] {ffffff}\xc4\xee\xe6\xe4\xe8\xf2\xe5\xf1\xfc \xe7\xe0\xe2\xe5\xf0\xf8\xe5\xed\xe8\xff!', message_color) return end
    text = processText(text, target_id)
    lua_thread.create(function()
        isActiveCommand = true; CommandStopWindow[0] = true
        local lines = {}
        for line in text:gmatch("[^&]+") do table.insert(lines, line) end
        for i, line in ipairs(lines) do
            if command_stop then command_stop = false; break end
            if line == "{pause}" then
                command_pause = true; CommandPauseWindow[0] = true
                while command_pause do wait(0) end
                if command_stop then command_stop = false; break end
            else
                if i > 1 then wait((waiting or 1.5) * 1000) end
                if not command_stop then sampSendChat(line) end
            end
        end
        isActiveCommand = false; CommandStopWindow[0] = false
        if callback then callback() end
    end)
end

function send_interaction(index, target_id)
    local inter = settings.interactions[index]
    if not inter then return end
    send_lines(table.concat(inter.lines, '&'), inter.waiting, target_id)
end

local _fh_piar_vr_active = false
function send_piar(index)
    local t = settings.piar_templates[index]
    if not t or not t.enable then return end
    if isActiveCommand then return end
    local _lines = t.lines or {}
    local _to_send
    if t.random_line and #_lines > 1 then
        _to_send = _lines[math.random(1, #_lines)]
    else
        _to_send = table.concat(_lines, '&')
    end
    _fh_piar_vr_active = true
    send_lines(_to_send, t.waiting, nil, function()
        _fh_piar_vr_active = false
        t.last_time = os.time()
        if (t.auto_limit or 0) > 0 then
            t.auto_count = (t.auto_count or 0) + 1
            if t.auto_count >= t.auto_limit then
                t.auto = false
                t.auto_count = 0
                sampAddChatMessage('[Family Helper] {ffaa00}\xcf\xe8\xe0\xf0 \xab' .. (t.name or '?') .. '\xbb {ffffff}\x97 \xeb\xe8\xec\xe8\xf2 ' .. t.auto_limit .. ' \xee\xf2\xef\xf0\xe0\xe2\xee\xea \xe4\xee\xf1\xf2\xe8\xe3\xed\xf3\xf2, \xe0\xe2\xf2\xee \xe2\xfb\xea\xeb\xfe\xf7\xe5\xed.', message_color)
            end
        end
        save_settings()
    end)
end

local function fh_find_pid_by_nick(nick)
    for ci = 0, 999 do
        if sampIsPlayerConnected(ci) and sampGetPlayerNickname(ci) == nick then return ci end
    end
    return nil
end

imgui.OnFrame(function() return MemberCtxWindow[0] end, function()
    if not fmember_ctx_nick then MemberCtxWindow[0] = false; return end
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(560*d, 0), imgui.Cond.FirstUseEver)
    imgui.Begin(safe_u8(' \xc4\xe5\xe9\xf1\xf2\xe2\xe8\xff: ' .. fmember_ctx_nick), MemberCtxWindow,
        imgui.WindowFlags.NoCollapse)
    change_dpi()

    local mctx_h = math.min(sizeY * 0.7, 560*d)
    if imgui.BeginChild('##mctx_scroll', imgui.ImVec2(-1, mctx_h), false) then
    fh_touch_scroll('##mctx_scroll')

    local nick = fmember_ctx_nick
    local bw = (imgui.GetWindowContentRegionWidth() - 8*d) / 2

    imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), safe_u8(' \xc8\xe3\xf0\xee\xea: ' .. nick))
    imgui.Separator(); imgui.Spacing()

    if imgui.Button(fa_icon.PHONE .. '  ' .. u8'\xcf\xee\xe7\xe2\xee\xed\xe8\xf2\xfc ', imgui.ImVec2(-1, 28*d)) then
        local pid = fh_find_pid_by_nick(nick)
        if pid then
            pending_call_nick = nick
            sampSendChat('/number ' .. pid)
        else
            sampAddChatMessage('[Family Helper] {ff4444}\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xed\xe5 \xed\xe0\xe9\xe4\xe5\xed \xe2 \xf1\xe5\xf2\xe8', 0xFFA500)
        end
        MemberCtxWindow[0] = false
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing()

    imgui.Text(u8' \xcd\xee\xe2\xfb\xe9 \xf0\xe0\xed\xe3:'); imgui.SameLine()
    if imgui.Button(fa_icon.MINUS .. '##rnm', imgui.ImVec2(26*d, 0)) then ctx_rank_input[0] = math.max(1, ctx_rank_input[0]-1) end
    imgui.SameLine()
    imgui.PushItemWidth(50*d)
    imgui.InputInt(u8'##rni', ctx_rank_input, 0)
    ctx_rank_input[0] = math.max(1, math.min(10, ctx_rank_input[0]))
    imgui.PopItemWidth(); imgui.SameLine()
    if imgui.Button(fa_icon.CIRCLE_PLUS .. '##rnp', imgui.ImVec2(26*d, 0)) then ctx_rank_input[0] = math.min(10, ctx_rank_input[0]+1) end
    imgui.SameLine()
    if imgui.Button(fa_icon.CROWN .. '  ' .. u8'\xd3\xf1\xf2\xe0\xed\xee\xe2\xe8\xf2\xfc \xf0\xe0\xed\xe3 ##setrk', imgui.ImVec2(-1, 0)) then
        sampSendChat('/setfrank ' .. nick .. ' ' .. ctx_rank_input[0])
        MemberCtxWindow[0] = false
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing()

    imgui.PushItemWidth(imgui.GetWindowContentRegionWidth())
    imgui.InputText(u8'##tag_buf', ctx_tag_buf, 64)
    imgui.PopItemWidth()
    if imgui.Button(fa_icon.TAG .. '  ' .. u8'\xd3\xf1\xf2\xe0\xed\xee\xe2\xe8\xf2\xfc \xf2\xe5\xe3 ##settag', imgui.ImVec2(bw, 28*d)) then
        local tag = u8:decode(ffi.string(ctx_tag_buf)):match('^%s*(.-)%s*$')
        if tag ~= '' then
            sampSendChat('/famtag ' .. nick .. ' ' .. tag)
            MemberCtxWindow[0] = false
        end
    end
    imgui.SameLine()
    if imgui.Button(fa_icon.TAG .. '  ' .. u8'\xd1\xed\xff\xf2\xfc \xf2\xe5\xe3 ##famuntag', imgui.ImVec2(bw, 28*d)) then
        local pid = fh_find_pid_by_nick(nick)
        if pid then
            sampSendChat('/famuntag ' .. pid)
        else
            sampAddChatMessage('[Family Helper] {ff4444}\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xed\xe5 \xed\xe0\xe9\xe4\xe5\xed \xe2 \xf1\xe5\xf2\xe8 (\xed\xf3\xe6\xe5\xed ID)', 0xFFA500)
        end
        MemberCtxWindow[0] = false
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing()

    imgui.PushItemWidth(imgui.GetWindowContentRegionWidth())
    imgui.InputTextWithHint(u8'##reason', u8'\xcf\xf0\xe8\xf7\xe8\xed\xe0...', ctx_reason_buf, 128)
    imgui.PopItemWidth()
    local reason = u8:decode(ffi.string(ctx_reason_buf)):match('^%s*(.-)%s*$')
    if reason == '' then reason = '\xcd\xe0\xf0\xf3\xf8\xe5\xed\xe8\xe5 \xef\xf0\xe0\xe2\xe8\xeb' end

    imgui.Spacing()
    imgui.Text(u8' \xcc\xe8\xed\xf3\xf2:'); imgui.SameLine()
    if imgui.Button(fa_icon.MINUS .. '##mnm', imgui.ImVec2(26*d, 0)) then ctx_mute_min[0] = math.max(1, ctx_mute_min[0]-1) end
    imgui.SameLine()
    imgui.PushItemWidth(60*d)
    imgui.InputInt(u8'##mni', ctx_mute_min, 0)
    ctx_mute_min[0] = math.max(1, math.min(1440, ctx_mute_min[0]))
    imgui.PopItemWidth(); imgui.SameLine()
    if imgui.Button(fa_icon.CIRCLE_PLUS .. '##mnp', imgui.ImVec2(26*d, 0)) then ctx_mute_min[0] = math.min(1440, ctx_mute_min[0]+1) end
    imgui.Spacing()
    if imgui.Button(fa_icon.MICROPHONE_SLASH .. '  ' .. u8'\xc2\xfb\xe4\xe0\xf2\xfc \xec\xf3\xf2 ##fmu', imgui.ImVec2(bw, 28*d)) then
        local pid = fh_find_pid_by_nick(nick)
        if pid then
            sampSendChat(string.format('/fammute %d %d %s', pid, ctx_mute_min[0], reason))
        else
            sampAddChatMessage('[Family Helper] {ff4444}\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xed\xe5 \xed\xe0\xe9\xe4\xe5\xed \xe2 \xf1\xe5\xf2\xe8 (\xed\xf3\xe6\xe5\xed ID)', 0xFFA500)
        end
        MemberCtxWindow[0] = false
    end
    imgui.SameLine()
    if imgui.Button(fa_icon.MICROPHONE .. '  ' .. u8'\xd1\xed\xff\xf2\xfc \xec\xf3\xf2 ##fumu', imgui.ImVec2(bw, 28*d)) then
        local pid = fh_find_pid_by_nick(nick)
        if pid then
            sampSendChat('/famunmute ' .. pid)
        else
            sampAddChatMessage('[Family Helper] {ff4444}\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xed\xe5 \xed\xe0\xe9\xe4\xe5\xed \xe2 \xf1\xe5\xf2\xe8 (\xed\xf3\xe6\xe5\xed ID)', 0xFFA500)
        end
        MemberCtxWindow[0] = false
    end

    imgui.Spacing()
    if imgui.Button(fa_icon.TRIANGLE_EXCLAMATION .. '  ' .. u8'\xc2\xfb\xe3\xee\xe2\xee\xf0 ##fwarn', imgui.ImVec2(bw, 28*d)) then
        local pid = fh_find_pid_by_nick(nick)
        if pid then
            sampSendChat(string.format('/famwarn %d %s', pid, reason))
        else
            sampAddChatMessage('[Family Helper] {ff4444}\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xed\xe5 \xed\xe0\xe9\xe4\xe5\xed \xe2 \xf1\xe5\xf2\xe8 (\xed\xf3\xe6\xe5\xed ID)', 0xFFA500)
        end
        MemberCtxWindow[0] = false
    end
    imgui.SameLine()
    if imgui.Button(fa_icon.TRIANGLE_EXCLAMATION .. '  ' .. u8'\xd1\xed\xff\xf2\xfc \xe2\xfb\xe3\xee\xe2\xee\xf0 ##unfamwarn', imgui.ImVec2(bw, 28*d)) then
        local pid = fh_find_pid_by_nick(nick)
        if pid then
            sampSendChat('/unfamwarn ' .. pid)
        else
            sampAddChatMessage('[Family Helper] {ff4444}\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xed\xe5 \xed\xe0\xe9\xe4\xe5\xed \xe2 \xf1\xe5\xf2\xe8 (\xed\xf3\xe6\xe5\xed ID)', 0xFFA500)
        end
        MemberCtxWindow[0] = false
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing()

    if imgui.Button(fa_icon.THUMBS_UP .. '  ' .. u8'\xcf\xee\xf5\xe2\xe0\xeb\xe0 ##prais', imgui.ImVec2(bw, 28*d)) then
        sampSendChat('/praise ' .. nick)
        MemberCtxWindow[0] = false
    end
    imgui.SameLine()
    if imgui.Button(fa_icon.USER_XMARK .. '  ' .. u8'\xca\xe8\xea \xe8\xe7 \xf1\xe5\xec\xfc\xe8 ##funinv', imgui.ImVec2(bw, 28*d)) then
        sampSendChat('/famuninvite ' .. nick .. ' ' .. reason)
        MemberCtxWindow[0] = false
    end

    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
    imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd1\xe2\xee\xe8 \xea\xee\xec\xe0\xed\xe4\xfb')
    imgui.Separator()
    local btn_count = #settings.member_action_buttons
    local del_idx = nil
    for i, b in ipairs(settings.member_action_buttons) do
        local cmd_def = nil
        for _, c in ipairs(settings.commands or {}) do
            if c.cmd == b.cmd and not c.deleted then cmd_def = c; break end
        end
        if cmd_def then
            if imgui.Button(safe_u8(b.label ~= '' and b.label or (cmd_def.description or cmd_def.cmd)), imgui.ImVec2(bw - 26*d, 28*d)) then
                local pid = fh_find_pid_by_nick(nick)
                if pid then
                    local mt = cmd_def.text or ''
                    if cmd_def.arg == '{arg_id} {arg2}' then mt = mt:gsub('{arg2}', reason) end
                    send_lines(mt, tonumber(cmd_def.waiting), pid)
                else
                    sampAddChatMessage('[Family Helper] {ff4444}\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xed\xe5 \xed\xe0\xe9\xe4\xe5\xed \xe2 \xf1\xe5\xf2\xe8 (\xed\xf3\xe6\xe5\xed ID)', 0xFFA500)
                end
                MemberCtxWindow[0] = false
            end
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.4,0.1,0.1,1))
            if imgui.SmallButton(fa_icon.TRASH .. '##delab'..i) then del_idx = i end
            imgui.PopStyleColor()
            if i % 2 ~= 0 and i < btn_count then imgui.SameLine() end
        end
    end
    if del_idx then table.remove(settings.member_action_buttons, del_idx); save_settings() end
    imgui.Spacing()
    if imgui.Button(fa_icon.CIRCLE_PLUS .. '  ' .. u8'\xc4\xee\xe1\xe0\xe2\xe8\xf2\xfc \xea\xed\xee\xef\xea\xf3', imgui.ImVec2(-1, 0)) then
        ffi.copy(aab_label_buf, ''); aab_cmd_selected_idx[0] = 0
        AddActionBtnWindow[0] = true
    end
    imgui.EndChild()
    end

    imgui.Spacing()
    if imgui.Button(fa_icon.XMARK .. '  ' .. u8'\xc7\xe0\xea\xf0\xfb\xf2\xfc ', imgui.ImVec2(-1, 28*d)) then MemberCtxWindow[0] = false end
    imgui.End()
end)

imgui.OnFrame(function() return AddActionBtnWindow[0] end, function()
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0

    local avail = {}
    for _, c in ipairs(settings.commands or {}) do
        if not c.deleted and (c.arg == '{arg_id}' or c.arg == '{arg_id} {arg2}') and (c.text or ''):match('^%s*/fam') then
            table.insert(avail, c)
        end
    end
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(360*d, 0), imgui.Cond.Always)
    imgui.Begin(u8' \xc4\xee\xe1\xe0\xe2\xe8\xf2\xfc \xea\xed\xee\xef\xea\xf3##aab', AddActionBtnWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize)
    change_dpi()
    if #avail == 0 then
        imgui.TextDisabled(u8' \xcd\xe5\xf2 \xef\xee\xe4\xf5\xee\xe4\xff\xf9\xe8\xf5 \xea\xee\xec\xe0\xed\xe4.')
        imgui.TextDisabled(u8' \xd1\xee\xe7\xe4\xe0\xe9\xf2\xe5 \xea\xee\xec\xe0\xed\xe4\xf3 \xed\xe0 \xe2\xea\xeb\xe0\xe4\xea\xe5 "\xca\xee\xec\xe0\xed\xe4\xfb"')
        imgui.TextDisabled(u8' \xf1 \xe0\xf0\xe3\xf3\xec\xe5\xed\xf2\xee\xec {arg_id} \xe8 \xf2\xe5\xea\xf1\xf2\xee\xec, \xed\xe0\xf7\xe8\xed\xe0\xfe\xf9\xe8\xec\xf1\xff \xed\xe0 "/fam"')
    else
        imgui.Text(u8' \xca\xee\xec\xe0\xed\xe4\xe0:')
        if aab_cmd_selected_idx[0] > #avail - 1 then aab_cmd_selected_idx[0] = 0 end
        local cur = avail[aab_cmd_selected_idx[0] + 1]
        if imgui.BeginChild('##aab_cmd_list', imgui.ImVec2(-1, math.min(#avail, 5) * 26*d), true) then
            fh_touch_scroll('##aab_cmd_list')
            for i, c in ipairs(avail) do
                local label = safe_u8('/' .. (c.cmd or '') .. ' \x97 ' .. (c.description or ''))
                local sel = (i - 1 == aab_cmd_selected_idx[0])
                if sel then imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(ar*0.5, ag*0.5, ab*0.5, 1)) end
                if imgui.Button(label, imgui.ImVec2(-1, 22*d)) then aab_cmd_selected_idx[0] = i - 1 end
                if sel then imgui.PopStyleColor() end
            end
            imgui.EndChild()
        end
        imgui.Spacing()
        imgui.Text(u8' \xcd\xe0\xe7\xe2\xe0\xed\xe8\xe5 \xea\xed\xee\xef\xea\xe8:')
        imgui.PushItemWidth(-1)
        imgui.InputText('##aab_label', aab_label_buf, 64)
        imgui.PopItemWidth()
        imgui.TextDisabled(u8'  \xe5\xf1\xeb\xe8 \xef\xf3\xf1\xf2\xee \x97 \xe1\xf3\xe4\xe5\xf2 \xe8\xf1\xef\xee\xeb\xfc\xe7\xee\xe2\xe0\xed\xee \xee\xef\xe8\xf1\xe0\xed\xe8\xe5 \xea\xee\xec\xe0\xed\xe4\xfb')
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        local bw2 = (imgui.GetWindowContentRegionWidth() - 8*d) / 2
        if imgui.Button(fa_icon.CIRCLE_PLUS .. '  ' .. u8'\xc4\xee\xe1\xe0\xe2\xe8\xf2\xfc', imgui.ImVec2(bw2, 28*d)) then
            local label = u8:decode(ffi.string(aab_label_buf)):match('^%s*(.-)%s*$')
            table.insert(settings.member_action_buttons, {cmd = cur.cmd, label = label})
            save_settings()
            AddActionBtnWindow[0] = false
        end
        imgui.SameLine()
        if imgui.Button(fa_icon.XMARK .. '  ' .. u8'\xce\xf2\xec\xe5\xed\xe0', imgui.ImVec2(bw2, 28*d)) then AddActionBtnWindow[0] = false end
    end
    if #avail == 0 then
        imgui.Spacing()
        if imgui.Button(fa_icon.CHECK .. '  ' .. u8'\xce\xea', imgui.ImVec2(-1, 28*d)) then AddActionBtnWindow[0] = false end
    end
    imgui.End()
end)

local function flog(category, entry)
    entry.time = entry.time or os.date('%H:%M:%S')
    entry.date = entry.date or os.date('%d.%m.%Y')
    local t = famlog[category]
    if not t then return end
    table.insert(t, 1, entry)
    if #t > 200 then t[#t] = nil end

    local now = os.time()
    if not _G.log_last_save or now - _G.log_last_save >= 10 then
        _G.log_last_save = now
        save_log()
    end
end

local function my_nick()
    local ok, pid = pcall(select, 2, sampGetPlayerIdByCharHandle(PLAYER_PED))
    if ok and pid then return sampGetPlayerNickname(pid) end
    return ''
end

local fh_online = {}
local FH_MARKER        = '\xE2\x80\x8B[FH:'
local FH_PING_INTERVAL = 180
local FH_TIMEOUT       = 420
local fh_last_ping     = os.time()
local fh_joined        = os.time()

local function fh_my_rank_num()
    return tonumber(settings.family_info.my_rank_number) or 1
end

local function fh_update_self()
    local me = my_nick()
    if me and me ~= '' then
        fh_online[me] = {rank=fh_my_rank_num(), joined=fh_joined, last_seen=os.time()}
    end
end

-- —ÚÓËÚ URL Í Telegram Bot API, ÔË ÌÂÓ·ıÓ‰ËÏÓÒÚË ÔÓ„ÓÌˇˇ Á‡ÔÓÒ ˜ÂÂÁ
-- ÔÓÍÒË-ÒÂ‚Â FH (‡Ì‡ÎÓ„Ë˜ÌÓ ÔÓÍÒË ‚ MarketHelper) - ‡ÍÚÛ‡Î¸ÌÓ, ÍÓ„‰‡
-- api.telegram.org Á‡·ÎÓÍËÓ‚‡Ì Û ÔÓ‚‡È‰Â‡/ÒÚ‡Ì˚ ÔÓÎ¸ÁÓ‚‡ÚÂÎˇ.
-- method - ËÏˇ ÏÂÚÓ‰‡ API (sendMessage, getUpdates, ...), query - ÛÊÂ
-- ÒÙÓÏËÓ‚‡ÌÌ‡ˇ ÒÚÓÍ‡ Ô‡‡ÏÂÚÓ‚ ·ÂÁ ‚Â‰Û˘Â„Ó '?'.
local function fh_tg_url(token, method, query, use_proxy)
    if use_proxy == nil then
        use_proxy = settings and settings.tg and settings.tg.use_proxy
    end
    local base = use_proxy
        and 'https://va-ta.com/tg_proxy/%s/%s?%s'
        or  'https://api.telegram.org/bot%s/%s?%s'
    return base:format(token, method, query)
end

local FH_PING_PHRASES = {
    '\xc2\xf1\xe5\xec \xef\xf0\xe8\xe2\xe5\xf2!',
    '\xc2\xf1\xe5\xec \xe4\xee\xe1\xf0\xe0!',
    '\xc4\xee\xe1\xf0\xee\xe3\xee \xe2\xf1\xe5\xec!',
    '\xcf\xf0\xe8\xe2\xe5\xf2 \xe2\xf1\xe5\xec!',
    '\xc2\xf1\xe5\xec \xf3\xe4\xe0\xf7\xe8!',
    '\xcd\xe0 \xf1\xe2\xff\xe7\xe8!',
    '\xc2\xf1\xe5\xec \xf5\xee\xf0\xee\xf8\xe5\xe3\xee \xe4\xed\xff!',
    '\xc1\xf3\xe4\xfc\xf2\xe5 \xe0\xea\xf2\xe8\xe2\xed\xfb!',
}

local function fh_send_ping()
    if not settings.tg or not settings.tg.enabled or not settings.tg.auto_role then return end
    local me = my_nick()
    if not me or me == '' then return end
    fh_update_self()
    fh_last_ping = os.time()
    local token      = settings.tg.token      or ''
    local channel_id = settings.tg.channel_id or ''

    if token == '' or channel_id == '' then return end
    if not tg_effil then
        local ok, lib = pcall(require, 'effil')
        if ok and lib then tg_effil = lib end
    end
    if not tg_effil then return end
    local rank   = fh_my_rank_num()
    local joined = fh_joined
    local _pt = '[FH_PING:' .. rank .. ':' .. joined .. ':' .. me .. ']'
    local ping_text = _pt:gsub('([^%w%-_%.~])', function(c) return string.format('%%%02X', string.byte(c)) end)
    local ping_url = fh_tg_url(token, 'sendMessage', 'chat_id=' .. channel_id .. '&text=' .. ping_text)
    tg_effil.thread(function(u)
        local ok_r, req = pcall(require, 'requests')
        if not ok_r then return end
        pcall(req.request, 'POST', u, nil)
    end)(ping_url)
end

local function fh_cleanup()
    local now = os.time()
    for nick, data in pairs(fh_online) do
        if now - data.last_seen > FH_TIMEOUT then fh_online[nick] = nil end
    end
end

local fh_start_time = os.time()

local function am_i_senior()
    if not settings.tg or not settings.tg.auto_role then return true end

    if os.time() - fh_start_time < 20 then return false end
    fh_cleanup()
    local me = my_nick()
    if not me or me == '' then return true end
    fh_update_self()
    local my_rank   = fh_my_rank_num()
    local my_joined = fh_joined
    for nick, data in pairs(fh_online) do
        if nick ~= me then
            if data.rank > my_rank then return false end
            if data.rank == my_rank and (data.joined or 0) < my_joined then return false end
        end
    end
    return true
end

local function tg_encode(str)
    str = tostring(str or ''):gsub('{%x%x%x%x%x%x}', '')
    return (str:gsub('([^%w%-_%.~])', function(c)
        return string.format('%%%02X', string.byte(c))
    end))
end

local tg_effil = nil

local function tg_url_encode(s)
    local result = string.gsub(s, '([^%w%-_ %.~=])', function(c)
        return string.format('%%%02X', string.byte(c))
    end)
    return string.gsub(result, ' ', '+')
end



local tg_fetch_missed

local function tg_http_get(url, timeout)

    timeout = timeout or 20
    if not tg_effil then return '', 'no_effil' end
    local t = tg_effil.thread(function(u, sock_timeout)
        local ok_r, req = pcall(require, 'requests')
        if not ok_r then return '\1no_requests\1' .. tostring(req) end
        local ok_s, resp = pcall(req.request, 'GET', u, {timeout = sock_timeout})
        if not ok_s then return '\1request_failed\1' .. tostring(resp) end
        if not resp then return '\1request_failed\1empty response' end
        return tostring(resp.text or '')
    end)(url, math.min(timeout, 25))
    local deadline = os.clock() + timeout
    while os.clock() < deadline do
        local st, err = t:status()
        if err or st == 'canceled' then return '', 'request_failed' end
        if st == 'completed' then
            local ok_g, raw = pcall(function() return t:get() end)
            if not ok_g then return '', 'request_failed' end
            raw = raw or ''
            local marker = raw:match('^\1(%a+)\1')
            if marker then return '', marker end
            return raw, nil
        end
        wait(100)
    end
    return '', 'timeout'
end

local function tg_fetch_my_chat_id_sync()
    local tg = settings and settings.tg
    if not tg or not tg.enabled then return nil end
    if tg.my_chat_id and tg.my_chat_id ~= '' then return tg.my_chat_id end
    local token = tg.token or ''
    if token == '' then return nil end

    local url = fh_tg_url(token, 'getUpdates', 'limit=100&allowed_updates=%5B%22message%22%2C%22channel_post%22%5D')
    local raw, err = tg_http_get(url)
    if err then
        if err == 'no_requests' then
            sampAddChatMessage('[Family Helper] “√: ÌÂ Ì‡È‰ÂÌ‡ ·Ë·ÎËÓÚÂÍ‡ requests (ÌÛÊÌ‡ Ô‡ÔÍ‡ lib/requests.lua Ë Â∏ Á‡‚ËÒËÏÓÒÚË)', 0xFF4444)
        elseif err == 'timeout' then
            sampAddChatMessage('[Family Helper] “√: ÌÂ ÓÚ‚Â˜‡ÂÚ ÒÂ‚Â Telegram (Ú‡ÈÏ‡ÛÚ). œÓ‚Â¸ÚÂ ËÌÚÂÌÂÚ/VPN.', 0xFF6600)
        else
            sampAddChatMessage('[Family Helper] “√: Ó¯Ë·Í‡ ÒÂÚË ÔË ÔÓÎÛ˜ÂÌËË chat_id', 0xFF6600)
        end
        return nil
    end
    if raw == '' then return nil end

    for cid, rest in raw:gmatch('"chat":%s*{%s*"id":(%-?%d+)([^}]*)') do
        if rest:find('"type":"private"') then

            local from_is_bot = raw:find('"from":%s*{[^}]*"id":' .. cid .. '[^}]*"is_bot":true')
            if not from_is_bot then
                settings.tg.my_chat_id = cid
                save_settings()
                sampAddChatMessage('[Family Helper] \xd2\xc3 \xeb\xe8\xf7\xea\xe0 \xef\xf0\xe8\xe2\xff\xe7\xe0\xed\xe0 ?', 0x00CC00)
                return cid
            end
        end
    end
    return nil
end

local function tg_autoregister()
    local tg = settings and settings.tg
    if not tg or not tg.enabled then return end
    if not tg_effil then
        local ok, lib = pcall(require, 'effil')
        if ok and lib then tg_effil = lib end
    end
    if not tg_effil then return end

    lua_thread.create(function()
        wait(5000)
        tg_fetch_missed()
    end)
end

local function tg_send(msg)
    local tg = settings and settings.tg
    if not tg or not tg.enabled then return end
    local token      = tg.token      or ''
    local chat_id    = tg.chat_id    or ''
    local channel_id = tg.channel_id or ''
    if token == '' or chat_id == '' then return end
    msg = msg:gsub('%[FH%]', '[' .. os.date('%d.%m.%Y') .. ' | ' .. os.date('%H:%M') .. ']')
    msg = msg:gsub('(\xc8\xe3\xf0\xee\xea [%a_]+ )([%a%d])', function(prefix, ch) return prefix .. ch:upper() end)
    if #msg > 4000 then msg = msg:sub(1, 4000) end

    local ok_enc, enc = pcall(require, 'encoding')
    if ok_enc and enc then
        local ok_u, utf_msg = pcall(function()
            return enc.UTF8:encode(enc.CP1251:decode(msg))
        end)
        if ok_u and utf_msg then msg = utf_msg end
    else
        local ok_u, utf_msg = pcall(function() return u8(msg) end)
        if ok_u and utf_msg then msg = utf_msg end
    end

    local encoded = tg_url_encode(msg)
    local url = fh_tg_url(token, 'sendMessage', 'chat_id=' .. chat_id .. '&text=' .. encoded)
    local url_chan = channel_id ~= '' and
                fh_tg_url(token, 'sendMessage', 'chat_id=' .. channel_id .. '&text=' .. encoded) or nil

    if not tg_effil then
        local ok, lib = pcall(require, 'effil')
        if ok and lib then tg_effil = lib end
    end

    if tg_effil then

        local function _tg_post_retrying(method, req_url, body, attempts_left)
            local t = tg_effil.thread(function(m, u, b)
                local ok_r, req = pcall(require, 'requests')
                if not ok_r then return 'no_requests|' .. tostring(req) end
                local ok_s, resp = pcall(req.request, m, u, {timeout = 15})
                if not ok_s then

                    local raw_err = tostring(resp)
                    local net_reason = raw_err:match('error in %a+ request:%s*(.+)$') or raw_err
                    return 'net_err|' .. net_reason
                end
                local status = tostring(resp and resp.status_code or '?')
                local body_text = tostring(resp and resp.text or ''):sub(1, 300)
                return status .. '|' .. body_text
            end)(method, req_url, body)
            lua_thread.create(function()
                local deadline = os.clock() + 20
                while os.clock() < deadline do
                    local st, err = t:status()
                    if err then return end
                    if st == 'completed' then
                        local ok_g, res = pcall(function() return t:get() end)
                        local r = tostring((ok_g and res) or '?')
                        if r:find('^200') then
                            if not settings.tg.pending then settings.tg.pending = {} end
                        elseif (r:find('^net_err|') or r:find('^%?$')) and attempts_left > 0 then
                            wait(1200)
                            _tg_post_retrying(method, req_url, body, attempts_left - 1)
                        else
                            local kind, detail = r:match('^(%a+)|(.*)$')
                            if kind == 'no_requests' then
                                sampAddChatMessage('TG: ·Ë·ÎËÓÚÂÍ‡ requests ÌÂ‰ÓÒÚÛÔÌ‡ (ÔÓ‚Â¸ÚÂ lib/requests.lua)', 0xFF4444)
                            elseif kind == 'net_err' then
                                sampAddChatMessage('TG: ÌÂÚ Ò‚ˇÁË Ò ÒÂ‚ÂÓÏ (' .. tostring(detail):sub(1,80) .. ')', 0xFF6600)
                            else
                                sampAddChatMessage('TG: Ó¯Ë·Í‡ (' .. r:sub(1, 80) .. ')', 0xFF6600)
                            end
                        end
                        return
                    end
                    if st == 'canceled' then return end
                    wait(100)
                end
            end)
        end
        _tg_post_retrying('POST', url, nil, 2)
        if url_chan then
            tg_effil.thread(function(method, req_url, body)
                local ok_r, req = pcall(require, 'requests')
                if not ok_r then return end
                pcall(req.request, method, req_url, {timeout = 15})
            end)('POST', url_chan, nil)
        end
    else
        lua_thread.create(function()
            local ok_h, https = pcall(require, 'ssl.https')
            local ok_l, ltn12 = pcall(require, 'ltn12')
            if ok_h and https and ok_l and ltn12 then
                local resp = {}
                pcall(https.request, {url=url, method='GET', sink=ltn12.sink.table(resp)})
            end
        end)
    end

end

local _tg_dedup = {}
local function tg_is_dup(msg)
    local now = os.time()
    for k, t in pairs(_tg_dedup) do
        if now - t > 90 then _tg_dedup[k] = nil end
    end
    local key = msg:sub(1, 80) .. os.date('%d%H%M')
    if _tg_dedup[key] then return true end
    _tg_dedup[key] = now
    return false
end

local function tg_send_if(nick_in_event, msg)
    if not settings.tg or not settings.tg.enabled then return end

    if settings.tg.auto_role then
        if am_i_senior() and not tg_is_dup(msg) then
            tg_send(msg)
        end
        return
    end

    if tg_is_dup(msg) then return end
    local role = settings.tg.role or 'main'
    if role == 'main' then
        tg_send(msg)
    elseif role == 'deputy' then
        if nick_in_event and nick_in_event == my_nick() then
            tg_send(msg)
        end
    end
end

local function decode_unicode_cp1251(s)
    return s:gsub('\\u(%x%x%x%x)', function(h)
        local cp = tonumber(h, 16)
        if not cp then return '' end
        local t = {
            [0x410]='\xc0',[0x411]='\xc1',[0x412]='\xc2',[0x413]='\xc3',
            [0x414]='\xc4',[0x415]='\xc5',[0x416]='\xc6',[0x417]='\xc7',
            [0x418]='\xc8',[0x419]='\xc9',[0x41a]='\xca',[0x41b]='\xcb',
            [0x41c]='\xcc',[0x41d]='\xcd',[0x41e]='\xce',[0x41f]='\xcf',
            [0x420]='\xd0',[0x421]='\xd1',[0x422]='\xd2',[0x423]='\xd3',
            [0x424]='\xd4',[0x425]='\xd5',[0x426]='\xd6',[0x427]='\xd7',
            [0x428]='\xd8',[0x429]='\xd9',[0x42a]='\xda',[0x42b]='\xdb',
            [0x42c]='\xdc',[0x42d]='\xdd',[0x42e]='\xde',[0x42f]='\xdf',
            [0x430]='\xe0',[0x431]='\xe1',[0x432]='\xe2',[0x433]='\xe3',
            [0x434]='\xe4',[0x435]='\xe5',[0x436]='\xe6',[0x437]='\xe7',
            [0x438]='\xe8',[0x439]='\xe9',[0x43a]='\xea',[0x43b]='\xeb',
            [0x43c]='\xec',[0x43d]='\xed',[0x43e]='\xee',[0x43f]='\xef',
            [0x440]='\xf0',[0x441]='\xf1',[0x442]='\xf2',[0x443]='\xf3',
            [0x444]='\xf4',[0x445]='\xf5',[0x446]='\xf6',[0x447]='\xf7',
            [0x448]='\xf8',[0x449]='\xf9',[0x44a]='\xfa',[0x44b]='\xfb',
            [0x44c]='\xfc',[0x44d]='\xfd',[0x44e]='\xfe',[0x44f]='\xff',
            [0x401]='\xa8',[0x451]='\xb8',
        }
        return t[cp] or ''
    end)
end
local function utf8_to_cp1251(s)

    return (s:gsub('([–—])([Ä-ø])', function(b1, b2)
        local hi = b1:byte()
        local lo = b2:byte()
        local cp
        if hi == 0xd0 then
            if lo == 0x81 then return '®' end
            if lo >= 0x90 and lo <= 0xbf then cp = lo - 0x90 + 0xc0 end
        elseif hi == 0xd1 then
            if lo == 0x91 then return '∏' end
            if lo >= 0x80 and lo <= 0x8f then cp = lo - 0x80 + 0xe0 end
        end
        return cp and string.char(cp) or ''
    end))
end

local function tg_sync_invites(done_cb)
    if not settings.tg or not settings.tg.enabled then
        if done_cb then done_cb() end; return
    end
    local token = settings.tg.token or ''
    if token == '' then if done_cb then done_cb() end; return end
    if not tg_effil then
        local ok, lib = pcall(require, 'effil')
        if ok and lib then tg_effil = lib end
    end
    if not tg_effil then if done_cb then done_cb() end; return end

    local bot_username = settings.tg.bot_username or 'FamilyGrozzybot'

    lua_thread.create(function()
        local offset = 0
        local total_inv = 0
        local pages = 0
        local max_pages = 20

        while pages < max_pages do
            pages = pages + 1
            local url = fh_tg_url(token, 'getUpdates', 'offset=' .. offset .. '&limit=100&allowed_updates=%5B%22message%22%2C%22channel_post%22%5D')

            local t = tg_effil.thread(function(req_url)
                local ok_r, req = pcall(require, 'requests')
                if not ok_r then return '' end
                local ok_s, resp = pcall(req.request, 'GET', req_url, nil)
                if not ok_s or not resp then return '' end
                return tostring(resp.text or '')
            end)(url)

            local raw = ''
            local deadline = os.clock() + 15
            while os.clock() < deadline do
                local st, err = t:status()
                if err or st == 'canceled' then break end
                if st == 'completed' then
                    local ok_g, res = pcall(function() return t:get() end)
                    if ok_g and res then raw = res end
                    break
                end
                wait(100)
            end

            if raw == '' then break end

            local new_last = offset
            local found = false

            for update_id_s, from_block, msg_text in raw:gmatch('"update_id":(%d+).-"from":({.-}).-"text":"(.-)"') do
                local uid = tonumber(update_id_s) or 0
                found = true
                if uid > new_last then new_last = uid end

                local is_bot     = from_block:find('"is_bot":true') ~= nil
                local is_our_bot = from_block:find('"username":"' .. bot_username .. '"') ~= nil
                if not (is_bot and is_our_bot) then goto continue end

                local day, mon, year = msg_text:match('%[(%d+)%.(%d+)%.(%d+) |')
                if not day then goto continue end

                local decoded = decode_unicode_cp1251(msg_text)
                decoded = decoded:gsub('%[%d+%.%d+%.%d+ | %d+:%d+%]%s*', '')

                local inv_by = decoded:match('\xc8\xe3\xf0\xee\xea ([%a%d_]+) \xef\xf0\xe8\xe3\xeb\xe0\xf1\xe8\xeb [%a%d_]+ \xe2 \xf1\xe5\xec\xfc\xfe')
                if inv_by then
                    if not settings.invite_stats then settings.invite_stats = {} end
                    local st2 = settings.invite_stats[inv_by] or
                        {total=0, today=0, week=0, month=0, day_key='', week_key='', month_key=''}

                    local dk = day .. '.' .. mon .. '.' .. year
                    local mk = mon .. '.' .. year
                    local wk = tostring(math.floor((tonumber(day) or 1) / 7)) .. '.' .. mon .. '.' .. year

                    if st2.day_key   ~= dk then st2.today = 0; st2.day_key   = dk end
                    if st2.week_key  ~= wk then st2.week  = 0; st2.week_key  = wk end
                    if st2.month_key ~= mk then st2.month = 0; st2.month_key = mk end

                    st2.total = (st2.total or 0) + 1
                    st2.today = (st2.today or 0) + 1
                    st2.week  = (st2.week  or 0) + 1
                    st2.month = (st2.month or 0) + 1
                    settings.invite_stats[inv_by] = st2
                    total_inv = total_inv + 1
                end

                ::continue::
            end

            if not found or new_last <= offset then break end
            offset = new_last + 1
            wait(200)
        end

        save_settings()
        if done_cb then done_cb(total_inv) end
    end)
end

tg_fetch_missed = function()
    if not settings.tg or not settings.tg.enabled then return end
    local token      = settings.tg.token      or ''
    local token2     = settings.tg.token2     or ''
    local channel_id = settings.tg.channel_id or ''
    if token == '' then
        sampAddChatMessage('[FH] TG: “ÓÍÂÌ 1 ÌÂ Á‡ÔÓÎÌÂÌ', 0xFF4444); return
    end
    if channel_id == '' then
        sampAddChatMessage('[FH] TG: ID Í‡Ì‡Î‡ ÌÂ Á‡ÔÓÎÌÂÌ', 0xFF6600); return
    end
    local read_token = (token2 ~= '' and token2 or token)
    if not tg_effil then
        local ok2, lib = pcall(require, 'effil')
        if ok2 and lib then tg_effil = lib end
    end
    if not tg_effil then
        sampAddChatMessage('[FH] TG: effil ÌÂ Á‡„ÛÁËÎÒˇ', 0xFF4444); return
    end

    lua_thread.create(function()
        local offset = tonumber(settings.tg.last_update_offset) or 0
        sampAddChatMessage('[FH] TG: ÒÚ‡Ú, offset=' .. offset, 0x00FFFF)

        if offset == 0 or offset < 1000000 then
            sampAddChatMessage('[FH] TG: ÒËÌıÓÌËÁ‡ˆËˇ...', 0xFFAA00)

            local r0, err0 = tg_http_get(fh_tg_url(read_token, 'getUpdates', 'limit=1&timeout=0&allowed_updates=%5B%22channel_post%22%5D'), 20)
            if err0 then
                if err0 == 'no_requests' then
                    sampAddChatMessage('[FH] TG: ·Ë·ÎËÓÚÂÍ‡ requests ÌÂ Á‡„ÛÁËÎ‡Ò¸ (ÔÓ‚Â¸ÚÂ lib/requests.lua)', 0xFF4444)
                elseif err0 == 'timeout' then
                    sampAddChatMessage('[FH] TG: ÌÂÚ ÓÚ‚ÂÚ‡ ÓÚ Telegram (Ú‡ÈÏ‡ÛÚ ÒÂÚË)', 0xFF6600)
                else
                    sampAddChatMessage('[FH] TG: Ó¯Ë·Í‡ ÒÂÚË (' .. tostring(err0) .. ')', 0xFF6600)
                end
                return
            end
            sampAddChatMessage('[FH] TG ÒËÌı: ' .. r0:sub(1,80), 0xAAAAAA)
            local uid0 = tonumber(r0:match('"update_id"%s*:%s*(%d+)')) or 0
            if uid0 > 0 then
                settings.tg.last_update_offset = uid0
                save_settings()
                sampAddChatMessage('[FH] TG: ÒËÌı OK, ˜ËÚ‡˛ Ò ' .. uid0, 0x00CC00)
                offset = uid0
            else
                settings.tg.last_update_offset = 1
                save_settings()
                sampAddChatMessage('[FH] TG: Í‡Ì‡Î ÔÛÒÚ', 0xFF6600)
                return
            end
        end

        local seen = {}
        local function do_log(msg, d, t)
            local clean = msg:gsub('%[%d+%.%d+%.%d+%s*|%s*%d+:%d+%]%s*', '')
                              :gsub('%[FH%]%s*', '')
                              :match('^%s*(.-)%s*$') or msg
            if clean == '' then return end
            local key = d .. t .. clean
            if seen[key] then return end
            seen[key] = true

            local ib, inew = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) ÔË„Î‡ÒËÎ ([%a%d_%.]+)')
            if ib and inew then
                flog('invite',{type='œË„Î‡¯∏Ì',nick=inew,by=ib,date=d,time=t})
                if not settings.invite_stats then settings.invite_stats = {} end
                local _st = settings.invite_stats[ib] or {total=0,today=0,week=0,month=0,day_key='',week_key='',month_key=''}
                local _dm,_dy = d:match('%d+%.(%d+)%.(%d+)')
                local _mk = (_dm or '')..'.'..((_dy or ''))
                local _wk = tostring(math.floor((tonumber(d:match('^(%d+)')) or 1)/7))..'.'.. _mk
                if _st.day_key   ~= d   then _st.today=0; _st.day_key=d     end
                if _st.week_key  ~= _wk then _st.week=0;  _st.week_key=_wk  end
                if _st.month_key ~= _mk then _st.month=0; _st.month_key=_mk end
                _st.total=(_st.total or 0)+1; _st.today=(_st.today or 0)+1
                _st.week=(_st.week or 0)+1;   _st.month=(_st.month or 0)+1
                settings.invite_stats[ib] = _st
                save_settings(); return
            end

            local ib2, inew2 = clean:match('([%a%d_%.]+) œËÌˇÎ Ë„ÓÍ‡ ([%a%d_%.]+)')
            if ib2 and inew2 then
                flog('invite',{type='œË„Î‡¯∏Ì',nick=inew2,by=ib2,date=d,time=t})
                if not settings.invite_stats then settings.invite_stats = {} end
                local _st = settings.invite_stats[ib2] or {total=0,today=0,week=0,month=0,day_key='',week_key='',month_key=''}
                local _dm,_dy = d:match('%d+%.(%d+)%.(%d+)')
                local _mk = (_dm or '')..'.'..((_dy or ''))
                local _wk = tostring(math.floor((tonumber(d:match('^(%d+)')) or 1)/7))..'.'.. _mk
                if _st.day_key   ~= d   then _st.today=0; _st.day_key=d     end
                if _st.week_key  ~= _wk then _st.week=0;  _st.week_key=_wk  end
                if _st.month_key ~= _mk then _st.month=0; _st.month_key=_mk end
                local cnt_msg = tonumber(clean:match('%(»Ì‚‡ÈÚÓ‚: (%d+)%)')) or 0
                if cnt_msg > (_st.total or 0) then _st.total = cnt_msg
                else _st.total = (_st.total or 0) + 1 end
                _st.today=(_st.today or 0)+1; _st.week=(_st.week or 0)+1; _st.month=(_st.month or 0)+1
                settings.invite_stats[ib2] = _st
                save_settings(); return
            end

            local n = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) ‚ÒÚÛÔËÎ ‚ ÒÂÏ¸˛')
            if n then flog('invite',{type='¬ÒÚÛÔËÎ',nick=n,date=d,time=t}); return end

            n = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) Ò‡ÏÓÒÚÓˇÚÂÎ¸ÌÓ ÔÓÍËÌÛÎ')
            if n then flog('invite',{type='œÓÍËÌÛÎ',nick=n,date=d,time=t}); return end

            local b2, kd
            b2, kd = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) ‚ ÓÙÙÎ‡ÈÌÂ ‚˚„Ì‡Î Ë„ÓÍ‡ ([%a%d_%.]+)')
            if not kd then b2, kd = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) ‚˚„Ì‡Î Ë„ÓÍ‡ ([%a%d_%.]+)') end
            if not kd then b2, kd = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) ËÒÍÎ˛˜ËÎ ([%a%d_%.]+)') end
            if kd then flog('invite',{type=' ËÍ',nick=kd,by=b2 or '?',date=d,time=t}); return end

            local nn, lv = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) ‰ÓÒÚË„ (%d+) ÛÓ‚Ìˇ')
            if not nn then nn = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) ÔÓ‰ÌˇÎ ÛÓ‚ÂÌ¸'); lv = '?' end
            if nn then flog('level',{nick=nn,lvl=lv or '?',date=d,time=t}); return end

            n = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) ‚˚ÔÓÎÌËÎ')
            if n then
                if not settings.quests_stats then settings.quests_stats = {} end
                settings.quests_stats[n] = (settings.quests_stats[n] or 0) + 1
                flog('quest',{nick=n,date=d,time=t})
                save_settings(); return
            end

            local b3   = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) ‚˚‰‡Î ÏÛÚ')
            local wh   = clean:match('ÏÛÚ Ë„ÓÍÛ ([%a%d_%.]+)')
            local dur  = clean:match('Ì‡ (%d+) ÏËÌ')
            local reas = clean:match('œË˜ËÌ‡: (.+)')
            if wh then flog('mute',{nick=wh,by=b3 or '?',duration=dur or '?',reason=reas or '',date=d,time=t}); return end

            local who, amt = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) ÔÓÔÓÎÌËÎ ÒÍÎ‡‰ ÒÂÏ¸Ë Ì‡ %$([%.%d]+)')
            if not who then who, amt = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) [œÔ]ÓÔÓÎÌËÎ ÒÍÎ‡‰ ÒÂÏ¸Ë Ì‡ :%a+:([%.%d]+)') end
            if not who then who, amt = clean:match('([%a%d_%.]+)%[%d+%] [œÔ]ÓÔÓÎÌËÎ ÒÍÎ‡‰ ÒÂÏ¸Ë Ì‡ :%a+:([%.%d]+)') end
            if who then flog('bank',{nick=who,id='?',op='œÓÔÓÎÌËÎ',sum=amt,date=d,time=t}); return end

            local who2, amt2 = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) ÒÌˇÎ ÒÓ ÒÍÎ‡‰‡ ÒÂÏ¸Ë %$([%.%d]+)')
            if not who2 then who2, amt2 = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) [—Ò]ÌˇÎ ÒÓ ÒÍÎ‡‰‡ ÒÂÏ¸Ë :%a+:([%.%d]+)') end
            if not who2 then who2, amt2 = clean:match('([%a%d_%.]+)%[%d+%] [—Ò]ÌˇÎ ÒÓ ÒÍÎ‡‰‡ ÒÂÏ¸Ë :%a+:([%.%d]+)') end
            if who2 then flog('bank',{nick=who2,id='?',op='—ÌˇÎ',sum=amt2,date=d,time=t}); return end

            local wco, tal, rep = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) Ó·ÏÂÌˇÎ (%d+) Ú‡ÎÓÌÓ‚ Ì‡ %+?(%d+)')
            if wco then
                if not settings.talons_stats then settings.talons_stats = {} end
                settings.talons_stats[wco] = (settings.talons_stats[wco] or 0) + (tonumber(tal) or 0)
                flog('coins',{nick=wco,msg=tal..' Ú‡Î -> +'..rep..' ÂÔ˚',date=d,time=t})
                save_settings(); return
            end

            local wco2 = clean:match('[»Ë]„ÓÍ ([%a%d_%.]+) Ò‰‡Î ÒÂÏÂÈÌ˚Â ÏÓÌÂÚ˚')
            if wco2 then
                if not settings.coins_stats then settings.coins_stats = {} end
                settings.coins_stats[wco2] = (settings.coins_stats[wco2] or 0) + 1
                flog('coins',{nick=wco2,msg='—‰‡Î ÏÓÌÂÚ˚',date=d,time=t})
                save_settings(); return
            end

            flog('news', {nick='[TG]', msg=clean, date=d, time=t})
        end

        local count, max_uid = 0, offset
        local retries_left = 2
        while true do
            local _stop, _retry = false, false
            local url = fh_tg_url(read_token, 'getUpdates', 'offset=' .. max_uid .. '&limit=100&timeout=0&allowed_updates=%5B%22channel_post%22%5D')

            local raw, err = tg_http_get(url, 20)
            if err then
                if err == 'no_requests' then
                    sampAddChatMessage('[FH] TG: ·Ë·ÎËÓÚÂÍ‡ requests ÌÂ Á‡„ÛÁËÎ‡Ò¸ (ÔÓ‚Â¸ÚÂ lib/requests.lua)', 0xFF4444)
                    _stop = true
                elseif (err == 'timeout' or err == 'request_failed') and retries_left > 0 then
                    retries_left = retries_left - 1
                    sampAddChatMessage('[FH] TG: Ò·ÓÈ ÒÂÚË, ÔÓ‚ÚÓ...', 0xFFA500)
                    wait(1500)
                    _retry = true
                else
                    sampAddChatMessage('[FH] TG: Ó¯Ë·Í‡ ÒÂÚË (' .. tostring(err) .. '), ÔÂ˚‚‡˛', 0xFF6600)
                    _stop = true
                end
            end
            if _stop then break end
            if not _retry then
                sampAddChatMessage('[FH] TG getUpdates: ' .. #raw .. '·', 0xAAAAAA)
                if raw == '' or raw:find('"result":%[%]') then
                    sampAddChatMessage('[FH] TG: ÔÓÔÛ˘ÂÌÌ˚ı ÌÂÚ', 0xFFA500); break
                end
                local found_any, pos = false, 1
                while true do
                    local uid_s = raw:find('"update_id"%s*:%s*%d+', pos)
                    if not uid_s then break end
                    local uid = tonumber(raw:match('"update_id"%s*:%s*(%d+)', uid_s)) or 0
                    if uid + 1 > max_uid then max_uid = uid + 1 end
                    found_any = true; pos = uid_s + 1
                    local nxt = raw:find('"update_id"', pos) or #raw
                    local block = raw:sub(uid_s, nxt)
                    local txt = block:match('"text"%s*:%s*"([^"]*)"')
                    if txt then
                        local had_u_escapes = txt:find('\\u%x%x%x%x') ~= nil
                        txt = decode_unicode_cp1251(txt)
                        if not had_u_escapes then txt = utf8_to_cp1251(txt) end
                        txt = txt:gsub('\\n', ' '):gsub('\\r', '')
                        sampAddChatMessage('[FH] TG ÒÓÓ·: ' .. txt:sub(1,60), 0x00FF00)

                        local fp_rank,fp_joined,fp_nick = txt:match('%[FH_PING:(%d+):(%d+):([%a%d_]+)%]')
                        if fp_nick then
                            fh_online[fp_nick] = {rank=tonumber(fp_rank) or 1,joined=tonumber(fp_joined) or 0,last_seen=os.time()}
                            count = count + 1
                        else
                            local d,m,y,hh,mm = txt:match('%[(%d+)%.(%d+)%.(%d+)%s*|%s*(%d+):(%d+)%]')
                            local id = d and (d..'.'..m..'.'..y) or os.date('%d.%m.%Y')
                            local it = hh and (hh..':'..mm..':00') or os.date('%H:%M:%S')
                            do_log(txt, id, it); count = count + 1
                        end
                    end
                end
                if not found_any then break end
                wait(300)
            end
        end
        settings.tg.last_update_offset = max_uid; save_settings()
        sampAddChatMessage('[FH] TG: Á‡„ÛÊÂÌÓ ' .. count .. ' ÒÓ·.', count > 0 and 0x00CC00 or 0xFFA500)
    end)
end

local fh_reconnect_active = false
local fh_reconnect_delay_ms = 0

local function fh_do_reconnect()
    local sf = require 'sampfuncs'
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, sf.PACKET_DISCONNECTION_NOTIFICATION)
    raknetSendBitStreamEx(bs, sf.SYSTEM_PRIORITY, sf.RELIABLE, 0)
    raknetDeleteBitStream(bs)
    bs = raknetNewBitStream()
    raknetEmulPacketReceiveBitStream(sf.PACKET_CONNECTION_LOST, bs)
    raknetDeleteBitStream(bs)
end

local function fh_reconnect_delayed()
    if fh_reconnect_active then return end
    fh_reconnect_active = true
    local delay_ms = math.max(100, (settings.reconnect.delay or 5.0) * 1000)
    lua_thread.create(function()
        local ms = delay_ms
        while ms > 0 and fh_reconnect_active do
            printStringNow(string.format('–ÂÍÓÌÌÂÍÚ ˜ÂÂÁ %.1f ÒÂÍ...', ms/1000), 1000)
            wait(500)
            ms = ms - 500
        end
        if fh_reconnect_active then
            fh_do_reconnect()
        end
        fh_reconnect_active = false
    end)
end

local function fh_readArzString(bs)
    local length  = raknetBitStreamReadInt16(bs)
    local encoded = raknetBitStreamReadInt8(bs)
    return (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded)
                           or  raknetBitStreamReadString(bs, length)
end

local function fh_showToolTip(text)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 143)
    raknetBitStreamWriteBool(bs, true)
    raknetBitStreamWriteInt16(bs, #text)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteString(bs, text)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

local function fh_sendFrontendClick(interfaceid, id, subid, json)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteInt32(bs, id)
    raknetBitStreamWriteInt32(bs, subid)
    raknetBitStreamWriteInt16(bs, #json)
    raknetBitStreamWriteString(bs, json)
    raknetSendBitStreamEx(bs, 1, 7, 1)
    raknetDeleteBitStream(bs)
end

local function fh_send_auth()

end

local function fh_update_spawn_list()
    settings._spawn_items = {}
    if settings.reconnect.spawn_json and settings.reconnect.spawn_json ~= '' then
        local ok, list = pcall(decodeJson, settings.reconnect.spawn_json)
        if ok and type(list) == 'table' then
            for _, item in ipairs(list) do
                table.insert(settings._spawn_items, tostring(item.id) .. '. ' .. tostring(item.spawn))
            end
        end
    end
end

local function fh_decode_cp1251_tree(v)
    -- –í–ê–ñ–ù–û: decodeJson(json) —É–∂–µ –æ—Ç–¥–∞—ë—Ç —Å—Ç—Ä–æ–∫–∏ –≤ UTF-8 (—Å–µ—Ä–≤–µ—Ä —à–ª—ë—Ç –ø–∞–∫–µ—Ç
    -- interfaceid=115/subid=1 –≤ UTF-8, –Ω–µ –≤ CP1251). –†–∞–Ω—å—à–µ –∑–¥–µ—Å—å –∫–∞–∂–¥–∞—è
    -- —Å—Ç—Ä–æ–∫–∞ –¥–µ—Ä–µ–≤–∞ –¥–æ–ø–æ–ª–Ω–∏—Ç–µ–ª—å–Ω–æ –ø—Ä–æ–≥–æ–Ω—è–ª–∞—Å—å —á–µ—Ä–µ–∑ u8:decode (CP1251 -> UTF-8),
    -- —á—Ç–æ –ø–æ—Ä—Ç–∏–ª–æ —É–∂–µ –∫–æ—Ä—Ä–µ–∫—Ç–Ω—ã–π UTF-8 —Ç–µ–∫—Å—Ç –≤ "???" ‚Äî –æ—Ç—Å—é–¥–∞ –±—ã–ª–∞ –æ–±—Ä–µ–∑–∞–Ω–Ω–∞—è/
    -- –±–∏—Ç–∞—è –∫–∏—Ä–∏–ª–ª–∏—Ü–∞ –≤ "–ù–∞—á–∏—Å–ª–µ–Ω–∏—è —Å –¥–µ–ø–æ–∑–∏—Ç–∞", "–§–ª–∞–≥", "–ö–≤–∞—Ä—Ç–∏—Ä–∞" –∏
    -- "–°–æ–≤–µ—Ç —Å–µ–º—å–∏". u8:decode –Ω—É–∂–µ–Ω —Ç–æ–ª—å–∫–æ –¥–ª—è —Å—ã—Ä—ã—Ö –±—É—Ñ–µ—Ä–æ–≤ ImGui InputText
    -- (ffi.string(buf)), –∫–æ—Ç–æ—Ä—ã–µ —Ä–µ–∞–ª—å–Ω–æ –≤ CP1251 ‚Äî —Å—é–¥–∞ –æ–Ω –Ω–µ –æ—Ç–Ω–æ—Å–∏—Ç—Å—è.
    -- –§—É–Ω–∫—Ü–∏—è –æ—Å—Ç–∞–≤–ª–µ–Ω–∞ (–ø—Ä–æ—Å—Ç–æ –ø—Ä–æ–≥–æ–Ω—è–µ—Ç –¥–µ—Ä–µ–≤–æ –∫–∞–∫ –µ—Å—Ç—å) –Ω–∞ —Å–ª—É—á–∞–π, –µ—Å–ª–∏
    -- –≥–¥–µ-—Ç–æ –µ—â—ë –≤ –∫–æ–¥–µ –∏—Å–ø–æ–ª—å–∑—É–µ—Ç—Å—è –µ—ë –∏–º—è/—Å–∏–≥–Ω–∞—Ç—É—Ä–∞.
    return v
end

local function fh_setup_autologin_handler()

    addEventHandler('onReceivePacket', function(id, bs)
        if id ~= 220 then return end
        raknetBitStreamIgnoreBits(bs, 8)
        if raknetBitStreamReadInt8(bs) ~= 84 then return end
        local interfaceid = raknetBitStreamReadInt8(bs)
        local subid       = raknetBitStreamReadInt8(bs)
        local json        = fh_readArzString(bs)

        if _G.fh_pkt_debug then
            local ok_w, err_w = pcall(function()
                local dbg_path = configDirectory .. "/FH_pkt_debug.log"
                local dbg_file = io.open(dbg_path, 'a')
                if dbg_file then
                    dbg_file:write('[' .. os.date('%H:%M:%S') .. '] interfaceid=' .. tostring(interfaceid) .. ' subid=' .. tostring(subid) .. ' json=' .. tostring(json) .. '\r\n')
                    dbg_file:close()
                end
            end)
        end

        if interfaceid == 9 and subid == 8 then
            settings.reconnect.spawn_json = json
            fh_update_spawn_list()
            save_settings()
        end

        if interfaceid == 115 and subid == 1 then
            local ok_p, parsed = pcall(decodeJson, json)
            if ok_p and type(parsed) == 'table' then
                fh_fammenu_data = fh_decode_cp1251_tree(parsed)
                fh_fammenu_last_update = os.time()

                -- –î–∏–∞–≥–Ω–æ—Å—Ç–∏–∫–∞: –ø–∏—à–µ–º flag/apart –≤ hex, —á—Ç–æ–±—ã –ø–æ–Ω—è—Ç—å, —á—Ç–æ
                -- —Ä–µ–∞–ª—å–Ω–æ –ø—Ä–∏—Ö–æ–¥–∏—Ç –æ—Ç —Å–µ—Ä–≤–µ—Ä–∞ –≤ —ç—Ç–∏—Ö –¥–≤—É—Ö –ø–æ–ª—è—Ö (–≤ –æ—Ç–ª–∏—á–∏–µ
                -- –æ—Ç message/leaders, –∫–æ—Ç–æ—Ä—ã–µ —Ç–µ–ø–µ—Ä—å –æ—Ç–æ–±—Ä–∞–∂–∞—é—Ç—Å—è –≤–µ—Ä–Ω–æ).
                if _G.fh_pkt_debug then
                    local ok_w2 = pcall(function()
                        local dbg_path = configDirectory .. "/FH_pkt_debug.log"
                        local dbg_file = io.open(dbg_path, 'a')
                        if dbg_file then
                            local function to_hex(s)
                                if type(s) ~= 'string' then return tostring(s) end
                                return (s:gsub('.', function(c) return string.format('%02X ', c:byte()) end))
                            end
                            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] flag_raw=' .. tostring(parsed.flag)
                                .. ' hex=' .. to_hex(parsed.flag) .. '\r\n')
                            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] apart_raw=' .. tostring(parsed.apart)
                                .. ' hex=' .. to_hex(parsed.apart) .. '\r\n')
                            dbg_file:close()
                        end
                    end)
                end
            end
        end

        if not settings.reconnect.auto_login then return end

        if interfaceid == 9 then
            if subid == 0 then
                lua_thread.create(function()
                    wait(300)
                    local login = settings.reconnect.login or ''
                    local pass  = settings.reconnect.password or ''
                    if login ~= '' and pass ~= '' then
                        fh_showToolTip('[FH] ¿‚ÚÓÎÓ„ËÌ: ' .. login)
                        fh_sendFrontendClick(9, 0, 0, '{"password":"'..pass..'","username":"'..login..'"}')
                    end
                end)
            end
            if subid == 3 then
                if json == 'spawn' then
                    lua_thread.create(function()
                        wait(300)
                        fh_showToolTip('[FH] ¿‚ÚÓÒÔ‡‚Ì...')
                        fh_sendFrontendClick(9, 6, 0, tostring(settings.reconnect.spawn_use or 0))
                    end)
                end
                if json == 'user_already_game' then
                    lua_thread.create(function()
                        wait(2000)
                        local login = settings.reconnect.login or ''
                        local pass  = settings.reconnect.password or ''
                        if login ~= '' and pass ~= '' then
                            fh_showToolTip('[FH] œÓ‚ÚÓ ÎÓ„ËÌ‡: ' .. login)
                            fh_sendFrontendClick(9, 0, 0, '{"password":"'..pass..'","username":"'..login..'"}')
                        end
                    end)
                end
                if json == 'error' then
                    sampAddChatMessage('[FH] {ff4444}ÕÂ‚ÂÌ˚È ÎÓ„ËÌ ËÎË Ô‡ÓÎ¸', 0xFF6600)
                end
            end
        end
    end)
end

function sampev.onConnectionBanned()
    if settings.reconnect.enabled and settings.reconnect.on_banned then
        sampAddChatMessage('[FH] «‡·‡Ì, ÂÍÓÌÌÂÍÚ...', 0xFF6600)
        fh_reconnect_delayed()
    end
end

function sampev.onConnectionClosed()
    if settings.reconnect.enabled and settings.reconnect.on_kicked then
        sampAddChatMessage('[FH] —ÓÂ‰ËÌÂÌËÂ Á‡Í˚ÚÓ, ÂÍÓÌÌÂÍÚ...', 0xFF6600)
        fh_reconnect_delayed()
    end
end

function sampev.onConnectionRejected()
    if settings.reconnect.enabled and settings.reconnect.on_rejected then
        sampAddChatMessage('[FH] ÕËÍ Á‡ÌˇÚ/ÌÂ‚ÂÌ˚È, ÂÍÓÌÌÂÍÚ...', 0xFF6600)
        fh_reconnect_delayed()
    end
end

function sampev.onConnectionPasswordInvalid()
    if settings.reconnect.enabled and settings.reconnect.on_password then
        sampAddChatMessage('[FH] ÕÂ‚ÂÌ˚È Ô‡ÓÎ¸ ÒÂ‚Â‡, ÂÍÓÌÌÂÍÚ...', 0xFF6600)
        fh_reconnect_delayed()
    end
end

function sampev.onConnectionRequestAccepted()
    fh_reconnect_active = false

end
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end
    fh_setup_autologin_handler()
    while not sampIsLocalPlayerSpawned() do wait(0) end

    do
        local dbg_path = configDirectory .. "/FH_debug.log"
        local dbg_file = io.open(dbg_path, 'w')
        if dbg_file then
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] === \xed\xee\xe2\xfb\xe9 \xf1\xe5\xe0\xed\xf1 (\xea\xf1\xea\xf0\xe8\xef\xf2 \xef\xe5\xf0\xe5\xe7\xe0\xef\xf3\xf9\xe5\xed) ===\r\n')
            dbg_file:close()
        end
    end

    sampAddChatMessage('[Family Helper] {ffffff}v' .. thisScript().version .. ' | ' .. message_color_hex .. '/fh {ffffff}| /fhstats | /fspawn', message_color)
    init_commands()
    fh_update_spawn_list()

    if settings.tg and settings.tg.auto_role then
        lua_thread.create(function()
            wait(8000)
            if sampIsLocalPlayerSpawned() then
                fh_update_self()
                fh_send_ping()
            end
        end)
    end

    if settings.tg and settings.tg.enabled then
        tg_autoregister()
    end

    if (settings.family_info.my_name or '') == '' then
        sampAddChatMessage('[Family Helper] {ffffff}\xcd\xe0\xf1\xf2\xf0\xee\xe9\xf2\xe5 \xe8\xec\xff \xe2 ' .. message_color_hex .. '/fh', message_color)
    end

    local _autosave_timer   = os.time()
    while true do
        wait(1000)

        if nearby_time > 0 and os.time() - nearby_time > 15 then
            nearby_players = {}
        end

        fh_cleanup_player_positions()

        if settings.general.float_btn_enable and settings.general.auto_nearby_poll then
            if not _G.fh_next_nearby_poll then _G.fh_next_nearby_poll = 0 end
            if os.time() >= _G.fh_next_nearby_poll then
                _G.fh_next_nearby_poll = os.time() + 1
                local radius = settings.general.float_btn_radius or 15
                local ok_list, list = pcall(fh_get_players_in_radius_sync, radius)
                if ok_list and list then
                    nearby_players = list
                    if #list > 0 then nearby_time = os.time() end
                end
                if debug_dialog then
                    local dbg_path = configDirectory .. "/FH_debug.log"
                    local dbg_file = io.open(dbg_path, 'a')
                    if dbg_file then
                        local cache_size = 0
                        for _ in pairs(_G.fh_player_positions) do cache_size = cache_size + 1 end
                        dbg_file:write('[' .. os.date('%H:%M:%S') .. '] --- \xf2\xe8\xea \xf1\xe8\xed\xf5-\xee\xef\xf0\xee\xf1\xe0: \xed\xe0\xe9\xe4\xe5\xed\xee_\xf0\xff\xe4\xee\xec=' .. tostring(ok_list and #list or 0) .. ' \xea\xdd\xf8_\xef\xee\xe7\xe8\xf6\xe8\xe9=' .. cache_size .. '\r\n')
                        dbg_file:close()
                    end
                end
            end
        end
        if settings.tg and settings.tg.auto_role then
            if os.time() - fh_last_ping >= FH_PING_INTERVAL then
                fh_send_ping()
            end

            if not _G.fh_last_read   then _G.fh_last_read   = 0 end
            if not _G.fh_ping_offset then _G.fh_ping_offset = 0 end
            if os.time() - _G.fh_last_read >= 300 and not _G.fh_ping_reader_busy then
                _G.fh_last_read = os.time()
                local _tok  = (settings.tg.token2 ~= '' and settings.tg.token2 or settings.tg.token) or ''
                local _chan = settings.tg.channel_id or ''
                if _tok ~= '' and _chan ~= '' then
                    if not tg_effil then
                        local ok, lib = pcall(require, 'effil')
                        if ok and lib then tg_effil = lib end
                    end
                    if tg_effil then

                        _G.fh_ping_reader_busy = true
                        lua_thread.create(function()
                            local off = _G.fh_ping_offset
                            local url = fh_tg_url(_tok, 'getUpdates', 'offset=' .. off .. '&limit=100&timeout=0&allowed_updates=%5B%22channel_post%22%5D')

                            local raw2, err2 = tg_http_get(url, 20)
                            _G.fh_ping_reader_busy = false
                            if err2 then
                                if not _G.fh_ping_err_count then _G.fh_ping_err_count = 0 end
                                _G.fh_ping_err_count = _G.fh_ping_err_count + 1

                                if _G.fh_ping_err_count >= 3 then
                                    if err2 == 'no_requests' then
                                        sampAddChatMessage('[FH] TG: ·Ë·ÎËÓÚÂÍ‡ requests ÌÂ‰ÓÒÚÛÔÌ‡ - ÔËÌ„Ë/Û‚Â‰ÓÏÎÂÌËˇ ËÁ “√ ÌÂ ˜ËÚ‡˛ÚÒˇ', 0xFF4444)
                                    else
                                        sampAddChatMessage('[FH] TG: ÌÂ Û‰‡∏ÚÒˇ Ò‚ˇÁ‡Ú¸Òˇ Ò ÒÂ‚ÂÓÏ (' .. tostring(err2) .. ') - ÔÓ‚Â¸ÚÂ ËÌÚÂÌÂÚ', 0xFF6600)
                                    end
                                    _G.fh_ping_err_count = 0
                                end
                                return
                            end
                            _G.fh_ping_err_count = 0
                            if raw2 == '' or raw2:find('"result":%[%]') then return end
                            local max_uid = off
                            local pos = 1
                            while true do
                                local uid_s = raw2:find('"update_id"%s*:%s*%d+', pos)
                                if not uid_s then break end
                                local uid = tonumber(raw2:match('"update_id"%s*:%s*(%d+)', uid_s)) or 0
                                if uid + 1 > max_uid then max_uid = uid + 1 end
                                local nxt = raw2:find('"update_id"', uid_s + 1) or #raw2
                                local block = raw2:sub(uid_s, nxt)
                                local txt = block:match('"text"%s*:%s*"([^"]*)"')
                                if txt then
                                    local had_u_escapes = txt:find('\\u%x%x%x%x') ~= nil
                                    txt = decode_unicode_cp1251(txt)
                                    if not had_u_escapes then txt = utf8_to_cp1251(txt) end
                                    txt = txt:gsub('\\n', ' '):gsub('\\r', '')
                                    local fp_r, fp_j, fp_n = txt:match('%[FH_PING:(%d+):(%d+):([%a%d_]+)%]')
                                    if fp_n then
                                        fh_online[fp_n] = {rank=tonumber(fp_r) or 1, joined=tonumber(fp_j) or 0, last_seen=os.time()}
                                    end
                                end
                                pos = uid_s + 1
                            end
                            if max_uid > off then _G.fh_ping_offset = max_uid end
                        end)
                    end
                end
            end
        end

        local _now = os.time()
        if _now - _autosave_timer >= 60 then
            _autosave_timer = _now
            save_log()
            save_settings()
        end

        if settings.tg and settings.tg.enabled and settings.tg.auto_inv_report then
            local auto_h = tonumber(settings.tg.auto_inv_hour) or 23
            local auto_m = tonumber(settings.tg.auto_inv_min)  or 59
            local cur_h  = tonumber(os.date('%H'))
            local cur_m  = tonumber(os.date('%M'))
            local today_key = os.date('%d.%m.%Y')
            if cur_h == auto_h and cur_m == auto_m then
                if (settings.tg.auto_inv_last_date or '') ~= today_key then
                    settings.tg.auto_inv_last_date = today_key
                    save_settings()

                    local self_nick = my_nick()
                    local stats = settings.invite_stats or {}
                    local s = stats[self_nick] or {}
                    local lines = {
                        '[FH] \xc4\xed\xe5\xe2\xed\xee\xe9 \xee\xf2\xf7\xb8\xf2 \xef\xee \xe8\xed\xe2\xe0\xe9\xf2\xe0\xec \x97 ' .. self_nick,
                        string.rep('-', 25),
                        '\xd1\xe5\xe3\xee\xe4\xed\xff:   ' .. (s.today or 0),
                        '\xcd\xe5\xe4\xe5\xeb\xff:    ' .. (s.week  or 0),
                        '\xcc\xe5\xf1\xff\xf6:     ' .. (s.month or 0),
                        '\xc2\xf1\xb8 \xe2\xf0\xe5\xec\xff: ' .. (s.total or 0),
                    }
                    tg_send(table.concat(lines, '\n'))
                    sampAddChatMessage('[Family Helper] {00cc00}\xc0\xe2\xf2\xee-\xee\xf2\xf7\xb8\xf2 \xef\xee \xe8\xed\xe2\xe0\xe9\xf2\xe0\xec \xee\xf2\xef\xf0\xe0\xe2\xeb\xe5\xed \xe2 \xd2\xc3!', 0xFFFFFF)
                end
            end
        end

        if settings.general.auto_invite and not isActiveCommand then
            local inv_players = fh_get_players_in_radius_sync(settings.general.auto_invite_radius)
            local tag = settings.family_info.family_tag or ''
            for _, pid in ipairs(inv_players) do
                if not invited_players[pid] and not isActiveCommand then

                    local their_nick = sampGetPlayerNickname(pid) or ''
                    -- –°–Ω–∞—á–∞–ª–∞ —Å–≤–µ—Ä—è–µ–º –ø–æ —Ç–æ—á–Ω–æ–º—É —Å–ø–∏—Å–∫—É —É—á–∞—Å—Ç–Ω–∏–∫–æ–≤ –∏–∑ /fmembers
                    -- (fmembers_online ‚Äî —Ä–µ–∞–ª—å–Ω—ã–µ –Ω–∏–∫–∏ —Ç–µ—Ö, –∫—Ç–æ —Å–µ–π—á–∞—Å –≤ —Å–µ–º—å–µ).
                    -- –†–∞–Ω—å—à–µ –ø—Ä–æ–≤–µ—Ä—è–ª–æ—Å—å —Ç–æ–ª—å–∫–æ –Ω–∞–ª–∏—á–∏–µ–º —Ç–µ–≥–∞ —Å–µ–º—å–∏ –≤ –Ω–∏–∫–µ ‚Äî
                    -- —ç—Ç–æ –¥–∞–≤–∞–ª–æ –ª–æ–∂–Ω–æ–µ "–Ω–µ –≤ —Å–µ–º—å–µ", –µ—Å–ª–∏ –∏–≥—Ä–æ–∫—É –µ—â—ë –Ω–µ
                    -- –≤—ã—Å—Ç–∞–≤–∏–ª–∏ —Ç–µ–≥ —á–µ—Ä–µ–∑ /famtag, –∏ –±–æ—Ç —Å–ª–∞–ª –ø–æ–≤—Ç–æ—Ä–Ω—ã–π –∏–Ω–≤–∞–π—Ç
                    -- —Ç–µ–º, –∫—Ç–æ —É–∂–µ —Å–æ—Å—Ç–æ–∏—Ç –≤ —Å–µ–º—å–µ.
                    local already_member = fmembers_online[their_nick] ~= nil
                    if not already_member then
                        already_member = tag ~= '' and their_nick:find(tag, 1, true)
                    end
                    if not already_member then
                        invited_players[pid] = os.time()
                        send_lines(settings.rp_invite.text or '', settings.rp_invite.waiting, pid)
                        break
                    end
                end
            end
        end

        for pid, ts in pairs(invited_players) do
            if os.time() - ts > 300 then invited_players[pid] = nil end
        end

        if not isActiveCommand then
            for idx, t in ipairs(settings.piar_templates) do
                local _piar_iv = t.auto_interval or 300
                    if (t.auto_interval_max or 0) > _piar_iv then
                        if not t._next_interval then t._next_interval = _piar_iv + math.random(0, t.auto_interval_max - _piar_iv) end
                        _piar_iv = t._next_interval
                    end
                    if t.enable and t.auto and os.time() - (t.last_time or 0) >= _piar_iv then
                        t._next_interval = nil
                    send_piar(idx); break
                end
            end
        end

        if congrats_batch_timer and not isActiveCommand then
            local elapsed = os.difftime(os.time(), congrats_batch_timer)
            if elapsed >= CONGRATS_BATCH_WINDOW and #congrats_batch > 0 then
                local batch = congrats_batch
                congrats_batch = {}
                congrats_batch_timer = nil
                local p = settings.congrats.use_fam and '/fam ' or ''
                local vars = settings.congrats.variants or {}
                local idx = (#vars > 0) and ((settings.congrats.variant_idx or 0) % #vars + 1) or 1
                settings.congrats.variant_idx = idx
                save_settings()
                local chosen = (vars[idx] or vars[1] or {}).items or {}
                lua_thread.create(function()
                    if #batch < CONGRATS_BATCH_SINGLE then
                        for _, nick in ipairs(batch) do
                            for _, item in ipairs(chosen) do
                                if item.text and item.text ~= '' then
                                    wait((item.waiting or 1.5) * 1000)
                                    sampSendChat(p .. processText(item.text, nil):gsub('{player_name}', nick))
                                end
                            end
                        end
                    else
                        local names = table.concat(batch, ', ')
                        CONGRATS_BATCH_MSG_IDX = CONGRATS_BATCH_MSG_IDX % #CONGRATS_BATCH_MSGS + 1
                        local bmsg = CONGRATS_BATCH_MSGS[CONGRATS_BATCH_MSG_IDX]:gsub('{names}', names)
                        wait(1500)
                        sampSendChat(p .. bmsg)
                    end
                end)
            elseif elapsed >= CONGRATS_BATCH_WINDOW then

                congrats_batch_timer = nil
            end
        end

        if settings.general.auto_rp_guns and sampIsLocalPlayerSpawned() then
            local cur_gun = getCurrentCharWeapon(PLAYER_PED)
            if cur_gun ~= fh_gun_now then
                fh_gun_old = fh_gun_now
                fh_gun_now = cur_gun
                local nm_new = fh_gun_names[fh_gun_now]
                local nm_old = fh_gun_names[fh_gun_old]
                local sl_new = fh_rp_take_slot[fh_gun_now] or 1
                local sl_old = fh_rp_take_slot[fh_gun_old] or 1
                local is_f   = (fh_sex == "∆ÂÌ˘ËÌ‡")

                local function is_hang(id) return id==3 or (id>=16 and id<=18) or id==39 or id==40 or id==90 or id==91 end
                local von  = is_hang(fh_gun_now) and (is_f and "ÒÌˇÎ‡" or "ÒÌˇÎ")   or (is_f and "‰ÓÒÚ‡Î‡" or "‰ÓÒÚ‡Î")
                local voff = is_hang(fh_gun_old) and (is_f and "ÔÓ‚ÂÒËÎ‡" or "ÔÓ‚ÂÒËÎ") or (is_f and "Û·‡Î‡" or "Û·‡Î")
                if fh_gun_old == 0 and nm_new then
                    sampSendChat("/me " .. von  .. " " .. nm_new .. " " .. fh_take_from[sl_new])
                elseif fh_gun_now == 0 and nm_old then
                    sampSendChat("/me " .. voff .. " " .. nm_old .. " " .. fh_take_to[sl_old])
                elseif nm_old and nm_new then
                    sampSendChat("/me " .. voff .. " " .. nm_old .. " " .. fh_take_to[sl_old] .. ", ÔÓÒÎÂ ˜Â„Ó " .. von .. " " .. nm_new .. " " .. fh_take_from[sl_new])
                end
            end
        end

    end
end

function init_commands()
    sampRegisterChatCommand("fh", function()
        MainWindow[0] = not MainWindow[0]
        if MainWindow[0] and not _G.fmembers_collecting then
            lua_thread.create(function() wait(400); _G.fmembers_requested = true; sampSendChat('/fmembers') end)
        end
    end)
    sampRegisterChatCommand("fi", function(a)
        if isParamSampID(a) then interact_player_id = tonumber(a); InteractMenu[0] = true
        else sampAddChatMessage('[Family Helper] {ffffff}/fi [ID]', message_color) end
    end)
    sampRegisterChatCommand("fm", function(a)
        if isParamSampID(a) then player_id = tonumber(a); FastMenu[0] = true
        else sampAddChatMessage('[Family Helper] {ffffff}/fm [ID]', message_color) end
    end)
    sampRegisterChatCommand("stop", function()
        if isActiveCommand then command_stop = true
        else sampAddChatMessage('[Family Helper] {ffffff}\xcd\xe5\xf2 \xe0\xea\xf2\xe8\xe2\xed\xee\xe9 \xee\xf2\xfb\xe3\xf0\xee\xe2\xea\xe8.', message_color) end
    end)
    sampRegisterChatCommand("fai", function()
        settings.general.auto_invite = not settings.general.auto_invite; save_settings(); invited_players = {}
        sampAddChatMessage('[Family Helper] {ffffff}\xc0\xe2\xf2\xee-\xe8\xed\xe2\xe0\xe9\xf2: ' .. message_color_hex .. (settings.general.auto_invite and '\xc2\xca\xcb' or '\xc2\xdb\xca\xcb'), message_color)
    end)
    sampRegisterChatCommand("fhdebug", function()
        local dbg_path = configDirectory .. "/FH_debug.log"
        local dbg_file = io.open(dbg_path, 'a')
        local function dbg_write(line)
            if dbg_file then dbg_file:write('[' .. os.date('%H:%M:%S') .. '] ' .. line .. '\r\n') end
        end
        dbg_write('=== fhdebug \xe7\xe0\xef\xf3\xf1\xea (\xf0\xe0\xf1\xf8\xe8\xf0\xe5\xed\xed\xe0\xff \xe2\xe5\xf0\xf1\xe8\xff) ===')

        dbg_write('--- \xef\xee\xe8\xf1\xea API \xf4\xf3\xed\xea\xf6\xe8\xe9 (samp*) ---')
        local api_count = 0
        local samp_names = {}
        for k, v in pairs(_G) do
            if type(v) == 'function' and type(k) == 'string' and k:sub(1,4) == 'samp' then
                table.insert(samp_names, k)
            end
        end
        table.sort(samp_names)
        for _, k in ipairs(samp_names) do
            dbg_write('samp*: ' .. k)
            api_count = api_count + 1
        end
        dbg_write('\xc2\xf1\xe5\xe3\xee samp* \xf4\xf3\xed\xea\xf6\xe8\xe9: ' .. api_count)
        dbg_write('---')

        dbg_write('--- sampev \xd0\x92\xd0\xa1\xd0\x95 \xf1\xee\xe1\xfb\xf2\xe8\xff ---')
        local ev_count = 0
        local ev_names = {}
        for k, v in pairs(sampev) do
            if type(k) == 'string' then table.insert(ev_names, k) end
        end
        table.sort(ev_names)
        for _, k in ipairs(ev_names) do
            dbg_write('sampev: ' .. k)
            ev_count = ev_count + 1
        end
        dbg_write('\xc2\xf1\xe5\xe3\xee sampev \xf1\xee\xe1\xfb\xf2\xe8\xe9: ' .. ev_count)
        dbg_write('---')

        dbg_write('--- \xf2\xe5\xf1\xf2 sampStorePlayerOnfootData ---')
        if type(sampStorePlayerOnfootData) == 'function' then
            local ok_t, res = pcall(sampStorePlayerOnfootData, 0)
            dbg_write('sampStorePlayerOnfootData(0) ok=' .. tostring(ok_t) .. ' res=' .. tostring(res))
            if ok_t and type(res) == 'table' then
                for kk, vv in pairs(res) do
                    dbg_write('  field: ' .. tostring(kk) .. ' = ' .. tostring(vv))
                end
            end
        else
            dbg_write('sampStorePlayerOnfootData \xed\xe5 \xe4\xee\xf1\xf2\xf3\xef\xed\xe0')
        end
        dbg_write('---')

        local max_id_ok, max_id = pcall(sampGetMaxPlayerId, false)
        dbg_write('sampGetMaxPlayerId: ' .. tostring(max_id_ok) .. ' / ' .. tostring(max_id))
        local net_found = 0
        if max_id_ok and max_id then
            for pid = 0, max_id do
                local ok_c, connected = pcall(sampIsPlayerConnected, pid)
                if ok_c and connected then
                    local nick = sampGetPlayerNickname(pid) or '???'
                    local exists_h = (type(sampGetCharHandleBySampPlayerId) == 'function')
                    local ok_h, hres, handle = pcall(sampGetCharHandleBySampPlayerId, pid)
                    local exists_p = (type(sampGetPlayerPosition) == 'function' or type(sampGetCharCoordinates) == 'function')
                    local ok_p, pxr, px, py, pz
                    if type(sampGetPlayerPosition) == 'function' then
                        ok_p, pxr, px, py, pz = pcall(sampGetPlayerPosition, pid)
                    end
                    dbg_write('[NET] ' .. nick .. '[' .. pid .. '] has_sampGetCharHandleBySampPlayerId=' .. tostring(exists_h)
                        .. ' handle_ok=' .. tostring(ok_h and hres) .. ' handle=' .. tostring(handle)
                        .. ' has_sampGetPlayerPosition=' .. tostring(type(sampGetPlayerPosition) == 'function')
                        .. ' pos_ok=' .. tostring(ok_p) .. ' pos=' .. tostring(px) .. ',' .. tostring(py) .. ',' .. tostring(pz))
                    net_found = net_found + 1
                    if net_found >= 15 then dbg_write('...\xee\xe1\xf0\xe5\xe7\xe0\xed\xee \xef\xee\xf1\xeb\xe5 15'); break end
                end
            end
        end
        dbg_write('\xc8\xf2\xee\xe3\xee \xef\xee \xf1\xe5\xf2\xe8 (NET): ' .. net_found .. ' \xe8\xe3\xf0\xee\xea\xee\xe2 \xef\xee\xe4\xea\xeb\xfe\xf7\xe5\xed\xee')

        local allchars = getAllChars()
        local char_count = 0
        for _ in pairs(allchars) do char_count = char_count + 1 end
        dbg_write('getAllChars: ' .. char_count .. ' \xf7\xe0\xf0\xee\xe2')
        local mx, my, mz = getCharCoordinates(PLAYER_PED)
        dbg_write('\xcf\xee\xe7\xe8\xf6\xe8\xff: ' .. string.format('%.1f %.1f %.1f', mx, my, mz))
        local found = 0
        local checked = 0
        local exist_fail = 0
        local res_fail = 0
        for _, h in pairs(allchars) do
            if h ~= PLAYER_PED then
                checked = checked + 1
                local ok_e, ex = pcall(doesCharExist, h)
                if ok_e and ex then
                    local ok_r, res, pid = pcall(sampGetPlayerIdByCharHandle, h)
                    if ok_r and res then
                        local x, y, z = getCharCoordinates(h)
                        local dist = getDistanceBetweenCoords3d(mx, my, mz, x, y, z)
                        local nick = sampGetPlayerNickname(pid) or '???'
                        dbg_write('[CHAR] ' .. nick .. '[' .. pid .. '] \xf0\xe0\xf1\xf1\xf2: ' .. string.format('%.1f', dist) .. ' handle=' .. tostring(h))
                        found = found + 1
                    else
                        res_fail = res_fail + 1
                    end
                else
                    exist_fail = exist_fail + 1
                end
            end
            if checked >= 200 then dbg_write('...\xee\xe1\xf0\xe5\xe7\xe0\xed\xee \xef\xee\xf1\xeb\xe5 200 char'); break end
        end
        dbg_write('\xc8\xf2\xee\xe3\xee \xef\xee CHAR: \xef\xf0\xee\xe2\xe5\xf0\xe5\xed\xee=' .. checked .. ' doesCharExist_fail=' .. exist_fail .. ' sampGetPlayerIdByCharHandle_fail=' .. res_fail .. ' \xed\xe0\xe9\xe4\xe5\xed\xee_\xe8\xe3\xf0\xee\xea\xee\xe2=' .. found)

        sampAddChatMessage('[FH Debug] {ffffff}NET=' .. message_color_hex .. net_found .. ' {ffffff}CHAR=' .. message_color_hex .. found .. ' {ffffff}/ ' .. char_count .. ' {ffffff}handles', message_color)

        dbg_write('\xd0\xe0\xe4\xe8\xf3\xf1: ' .. (settings.general.float_btn_radius or 15) .. ' | \xca\xed\xee\xef\xea\xe0: ' .. (settings.general.float_btn_enable and 'ON' or 'OFF'))
        dbg_write('\xca\xee\xeb-\xe2\xee \xe8\xe3\xf0\xee\xea\xee\xe2 \xe2 \xf0\xe0\xe4\xe8\xf3\xf1\xe5 (nearby_players): ' .. #nearby_players)
        dbg_write('')
        if dbg_file then dbg_file:close() end
        sampAddChatMessage('[FH Debug] {ffffff}\xc7\xe0\xef\xe8\xf1\xe0\xed\xee \xe2: FH_debug.log', message_color)
    end)

        sampRegisterChatCommand("fhpkt", function()
        _G.fh_pkt_debug = not _G.fh_pkt_debug
        local state = _G.fh_pkt_debug and '{00FF00}¬ À' or '{FF4444}¬€ À'
        sampAddChatMessage('[Family Helper] {ffffff}‘–ŒÕ“›Õƒ-Ô‡ÍÂÚ˚ (220) Í Ù‡ÈÎ: ' .. state, 0xFFA500)
        if _G.fh_pkt_debug then
            sampAddChatMessage('[Family Helper] {aaaaaa}ŒÚÍÓÈÚÂ /fammenu, ÔÓıÓ‰ËÚÂ ÔÓ ‚ÍÎ‡‰Í‡Ï, ÍÎËÍ‡ÈÚÂ "œÓ‰Ó·ÌÂÂ". ƒ‡ÏÔ ‚ FH_pkt_debug.log', 0xFFA500)
        end
    end)
        sampRegisterChatCommand("fhdlg", function()
        debug_dialog = not debug_dialog
        local state = debug_dialog and '{00FF00}\xc2\xca\xcb' or '{FF4444}\xc2\xdb\xca\xcb'
        sampAddChatMessage('[Family Helper] {ffffff}\xc4\xe5\xe1\xe0\xe3 \xd4\xc0\xcc\xcc\xc5\xcd\xde: ' .. state, 0xFFA500)
        if debug_dialog then
            sampAddChatMessage('[Family Helper] {aaaaaa}\xce\xf2\xea\xf0\xee\xe9\xf2\xe5 /fammenu \xe8 \xf1\xec\xee\xf2\xf0\xe8\xf2\xe5 \xf7\xf2\xee \xef\xf0\xe8\xf5\xee\xe4\xe8\xf2 \xe2 \xf7\xe0\xf2', 0xFFA500)
            sampAddChatMessage('[Family Helper] {aaaaaa}\xc4\xeb\xff \xea\xed\xee\xef\xea\xe8 \xe2\xe7\xe0\xe8\xec\xee\xe4\xe5\xe9\xf1\xf2\xe2\xe8\xff: \xef\xee\xe4\xee\xe9\xe4\xe8 \xea \xe6\xe8\xe2\xee\xec\xf3 \xe8\xe3\xf0\xee\xea\xf3, \xed\xe0\xe6\xec\xe8 \xea\xeb\xe0\xe2\xe8\xf8\xe8 \xe2\xe7\xe0\xe8\xec\xee\xe4\xe5\xe9\xf1\xf2\xe2\xe8\xff \xf1\xe0\xec \xe2\xf0\xf3\xf7\xed\xf3\xfe. \xc4\xe0\xec\xef \xf3\xe9\xe4\xe5\xf2 \xe2 FH_debug.log', 0xFFA500)
        end
    end)
    sampRegisterChatCommand("fhclick", function(a)
        local _, my_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        local target = tonumber(a)
        if not target then
            target = nearby_players[1] or my_id
        end
        if not target or not sampIsPlayerConnected(target) then
            sampAddChatMessage('[FH Debug] {ffffff}\xd6\xe5\xeb\xfc \xed\xe5 \xed\xe0\xe9\xe4\xe5\xed\xe0. \xd3\xea\xe0\xe6\xe8: /fhclick [ID]', message_color)
            return
        end
        sampAddChatMessage('[FH Debug] {ffffff}\xce\xf2\xef\xf0\xe0\xe2\xeb\xff\xfe sampSendClickPlayer(' .. target .. ')...', message_color)
        local dbg_path = configDirectory .. "/FH_debug.log"
        local dbg_file = io.open(dbg_path, 'a')
        if dbg_file then
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] === /fhclick \xf2\xe5\xf1\xf2: sampSendClickPlayer(' .. target .. ', 1) ===\r\n')
            dbg_file:close()
        end
        debug_dialog = true
        sampSendClickPlayer(target, 1)
    end)
    sampRegisterChatCommand("fhauto", function()
        settings.general.auto_nearby_poll = not settings.general.auto_nearby_poll; save_settings()
        local state = settings.general.auto_nearby_poll and '{00FF00}\xc2\xca\xcb' or '{FF4444}\xc2\xdb\xca\xcb'
        sampAddChatMessage('[Family Helper] {ffffff}\xc0\xe2\xf2\xee\xee\xef\xf0\xee\xf1 \xf1\xf3\xf9\xed\xee\xf1\xf2\xe5\xe9 \xf0\xff\xe4\xee\xec: ' .. state, message_color)
        if settings.general.auto_nearby_poll then
            sampAddChatMessage('[Family Helper] {aaaaaa}\xd1\xea\xf0\xe8\xef\xf2 \xe1\xf3\xe4\xe5\xf2 \xf1\xe0\xec \xef\xee\xe4\xe0\xe2\xe0\xf2\xfc sampSendClickPlayer \xea\xe0\xe6\xe4\xfb\xe5 ' .. (settings.general.auto_nearby_interval or 6) .. ' \xf1\xe5\xea. \xdd\xf2\xee \xfd\xea\xf1\xef\xe5\xf0\xe8\xec\xe5\xed\xf2\xe0\xeb\xfc\xed\xee -- \xf1\xeb\xe5\xe4\xe8 \xeb\xee\xe3 \xe8 \xef\xf0\xee\xe2\xe5\xf0\xfc \xf7\xf2\xee \xed\xe5 \xf2\xf0\xe8\xe3\xe3\xe5\xf0\xe8\xf2 \xe0\xed\xf2\xe8\xf7\xe8\xf2', message_color)
        end
    end)
    sampRegisterChatCommand("fspawn", function(a)
        local delay = tonumber(a) or settings.general.famspawn_delay or 30
        lua_thread.create(function()
            sampSendChat('/fam \xc2\xed\xe8\xec\xe0\xed\xe8\xe5! \xd7\xe5\xf0\xe5\xe7 ' .. delay .. ' \xf1\xe5\xea \xef\xf0\xee\xe8\xe7\xee\xe9\xe4\xb8\xf2 \xf1\xef\xe0\xe2\xed \xf1\xe5\xec\xe5\xe9\xed\xee\xe3\xee \xf2\xf0\xe0\xed\xf1\xef\xee\xf0\xf2\xe0!')
            wait(delay * 1000)
            sampSendChat('/famspawn')
            wait(200)
            sampSendChat('/fam \xd1\xe5\xec\xe5\xe9\xed\xfb\xe9 \xf2\xf0\xe0\xed\xf1\xef\xee\xf0\xf2 \xf3\xf1\xef\xe5\xf8\xed\xee \xe7\xe0\xf1\xef\xe0\xe2\xed\xe5\xed!')
        end)
    end)

    sampRegisterChatCommand("fhreset", function()
        invite_session = 0
        sampAddChatMessage('[Family Helper] {ffffff}\xd1\xf7\xb8\xf2\xf7\xe8\xea \xf1\xe5\xf1\xf1\xe8\xe8 \xf1\xe1\xf0\xee\xf8\xe5\xed!', message_color)
    end)

    sampRegisterChatCommand("fhstats", function()
        local total = 0
        local tag = settings.family_info.family_tag or ''
        if tag ~= '' then
            for i = 0, 999 do
                if sampIsPlayerConnected(i) then
                    local nick = sampGetPlayerNickname(i) or ''
                    if nick:find(tag, 1, true) then total = total + 1 end
                end
            end
            sampAddChatMessage('[Family Helper] {ffffff}\xce\xed\xeb\xe0\xe9\xed \xf1 \xf2\xe5\xe3\xee\xec ' .. message_color_hex .. tag .. '{ffffff}: ' .. message_color_hex .. total, message_color)
        else
            sampAddChatMessage('[Family Helper] {ffffff}\xd3\xea\xe0\xe6\xe8\xf2\xe5 \xf2\xe5\xe3 \xf1\xe5\xec\xfc\xe8 \xe2 \xed\xe0\xf1\xf2\xf0\xee\xe9\xea\xe0\xf5!', message_color)
        end
        sampAddChatMessage('[Family Helper] {ffffff}\xc8\xed\xe2\xe0\xe9\xf2\xee\xe2 \xe7\xe0 \xf1\xe5\xf1\xf1\xe8\xfe: ' .. message_color_hex .. invite_session .. ' {ffffff}| \xc2\xf1\xe5\xe3\xee: ' .. message_color_hex .. (settings.general.invite_total or 0), message_color)
    end)

    sampRegisterChatCommand("fp", function(a)
        local idx = tonumber(a)
        if idx and settings.piar_templates[idx] then send_piar(idx)
        else
            sampAddChatMessage('[Family Helper] {ffffff}/fp [1-' .. #settings.piar_templates .. ']', message_color)
            for i, t in ipairs(settings.piar_templates) do
                sampAddChatMessage(message_color_hex .. i .. '. {ffffff}' .. (t.name or ''), message_color)
            end
        end
    end)

    for _, c in ipairs(settings.commands) do
        if c.enable and not c.deleted and (c.cmd or '') ~= '' then
            reg_cmd(c.cmd, c.arg, c.text, tonumber(c.waiting))
        end
    end
end

function reg_cmd(cmd, arg, text, w)
    if not cmd or cmd == '' then return end
    sampRegisterChatCommand(cmd, function(a)
        if isActiveCommand then sampAddChatMessage('[Family Helper] {ffffff}\xc4\xee\xe6\xe4\xe8\xf2\xe5\xf1\xfc \xe7\xe0\xe2\xe5\xf0\xf8\xe5\xed\xe8\xff!', message_color); return end
        local ok, mt = false, text or ''
        if (arg or '') == '' then ok = true
        elseif arg == '{arg}' then
            if a and a ~= '' then mt = mt:gsub('{arg}', a); ok = true
            else sampAddChatMessage('[Family Helper] {ffffff}/' .. cmd .. ' [\xe0\xf0\xe3]', message_color) end
        elseif arg == '{arg_id}' then
            if isParamSampID(a) then ok = true; send_lines(mt, w, tonumber(a)); return
            else sampAddChatMessage('[Family Helper] {ffffff}/' .. cmd .. ' [ID]', message_color) end
        elseif arg == '{arg_id} {arg2}' then
            if a and a ~= '' then
                local a1, a2 = a:match('(%d+) (.+)')
                if isParamSampID(a1) and a2 then mt = mt:gsub('{arg2}', a2); ok = true
                    send_lines(mt, w, tonumber(a1)); return
                else sampAddChatMessage('[Family Helper] {ffffff}/' .. cmd .. ' [ID] [\xf2\xe5\xea\xf1\xf2]', message_color) end
            else sampAddChatMessage('[Family Helper] {ffffff}/' .. cmd .. ' [ID] [\xf2\xe5\xea\xf1\xf2]', message_color) end
        end
        if ok then send_lines(mt, w, nil) end
    end)
end

function sampev.onSendClickPlayer(playerId, source)
    if debug_dialog then
        local dbg_path = configDirectory .. "/FH_debug.log"
        local dbg_file = io.open(dbg_path, 'a')
        if dbg_file then
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] === onSendClickPlayer === playerId=' .. tostring(playerId) .. ' source=' .. tostring(source) .. '\r\n')
            dbg_file:close()
        end
        sampAddChatMessage('[FH DEBUG] {00FF00}ClickPlayer: {ffffff}playerId=' .. tostring(playerId) .. ' source=' .. tostring(source), 0xFFFFFF)
    end
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    fh_last_dlg_title = title and title:gsub('{%x+}',''):match('^%s*(.-)%s*$') or ''

    local _is_auto_poll = false
    if _G.fh_auto_poll_pending then
        _is_auto_poll = true
        _G.fh_auto_poll_pending = nil
        local dbg_path = configDirectory .. "/FH_debug.log"
        local dbg_file = io.open(dbg_path, 'a')
        if dbg_file then
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] === \xf0\xe5\xe7\xf3\xeb\xfc\xf2\xe0\xf2 \xe0\xe2\xf2\xee\xee\xef\xf0\xee\xf1\xe0 (\xea\xeb\xe8\xea \xef\xee \xf1\xe5\xe1\xe5): dialogId=' .. tostring(dialogId) .. ' style=' .. tostring(style) .. ' title=' .. tostring(title) .. '\r\n')
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] --- \xf2\xe5\xea\xf1\xf2 \xe0\xe2\xf2\xee\xee\xef\xf0\xee\xf1\xe0 \xed\xe0\xf7\xe0\xeb\xee ---\r\n')
            dbg_file:write(tostring(text) .. '\r\n')
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] --- \xf2\xe5\xea\xf1\xf2 \xe0\xe2\xf2\xee\xee\xef\xf0\xee\xf1\xe0 \xea\xee\xed\xe5\xf6 ---\r\n')
            dbg_file:close()
        end
    end

    if fh_last_dlg_title:find('\xd1\xf3\xf9\xed\xee\xf1\xf2\xe8', 1, true) and text then
        local found = {}

        for line in text:gmatch('[^\n]+') do
            local pid, dist = line:match('%[ID:%s*(%d+)%]\t?[^%d]*([%d%.]*)')
            if not pid then
                pid = line:match('%[ID:%s*(%d+)%]')
            end
            if pid then
                pid = tonumber(pid)
                if pid and sampIsPlayerConnected(pid) then
                    table.insert(found, pid)
                end
            end
        end
        if #found > 0 then
            nearby_players = found
            nearby_time = os.time()
            if debug_dialog then
                local dbg_path = configDirectory .. "/FH_debug.log"
                local dbg_file = io.open(dbg_path, 'a')
                if dbg_file then
                    dbg_file:write('[' .. os.date('%H:%M:%S') .. '] === \xef\xe5\xf0\xe5\xf5\xe2\xe0\xf7\xe5\xed \xf1\xef\xe8\xf1\xee\xea \xd1\xf3\xf9\xed\xee\xf1\xf2\xe8_\xf0\xff\xe4\xee\xec, \xed\xe0\xe9\xe4\xe5\xed\xee=' .. #found .. ' ids=' .. table.concat(found, ',') .. ' auto=' .. tostring(_is_auto_poll) .. '\r\n')
                    dbg_file:close()
                end
            end

            if not _is_auto_poll then
                if #found == 1 then
                    interact_player_id = found[1]; InteractMenu[0] = true
                else
                    InteractSelectPlayer[0] = true
                end
            end
        end
        return false
    end

    if debug_dialog then
        sampAddChatMessage('[FH DEBUG] {00FFFF}Dialog ID: {ffffff}' .. tostring(dialogId) .. ' {00FFFF}style: {ffffff}' .. tostring(style), 0xFFFFFF)
        sampAddChatMessage('[FH DEBUG] {00FFFF}Title: {ffffff}' .. tostring(title), 0xFFFFFF)
        sampAddChatMessage('[FH DEBUG] {00FFFF}Btn1: {ffffff}' .. tostring(button1) .. ' {00FFFF}Btn2: {ffffff}' .. tostring(button2), 0xFFFFFF)
        if text then
            local lines = {}
            local n = 0
            for line in text:gmatch('[^\n]+') do
                n = n + 1
                if n <= 8 then
                    local clean = line:gsub('{%x%x%x%x%x%x}',''):match('^%s*(.-)%s*$') or ''
                    sampAddChatMessage('[FH DEBUG] {aaaaaa}[' .. n .. '] {ffffff}' .. clean, 0xFFFFFF)
                end
            end
            sampAddChatMessage('[FH DEBUG] {666666}... \xc2\xf1\xe5\xe3\xee \xf1\xf2\xf0\xee\xea: {ffffff}' .. n, 0xFFFFFF)
        end

        local dbg_path = configDirectory .. "/FH_debug.log"
        local dbg_file = io.open(dbg_path, 'a')
        if dbg_file then
            local mx, my, mz = getCharCoordinates(PLAYER_PED)
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] === onShowDialog ===\r\n')
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] dialogId=' .. tostring(dialogId) .. ' style=' .. tostring(style) .. '\r\n')
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] title=' .. tostring(title) .. '\r\n')
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] button1=' .. tostring(button1) .. ' button2=' .. tostring(button2) .. '\r\n')
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] my_pos=' .. string.format('%.2f %.2f %.2f', mx, my, mz) .. '\r\n')
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] --- \xef\xee\xeb\xed\xfb\xe9 \xf2\xe5\xea\xf1\xf2 \xed\xe0\xf7\xe0\xeb\xee ---\r\n')
            dbg_file:write(tostring(text) .. '\r\n')
            dbg_file:write('[' .. os.date('%H:%M:%S') .. '] --- \xef\xee\xeb\xed\xfb\xe9 \xf2\xe5\xea\xf1\xf2 \xea\xee\xed\xe5\xf6 ---\r\n')
            dbg_file:write('\r\n')
            dbg_file:close()
        end
    end

    if settings.general.auto_storage_collect then
        local ct = title and title:gsub('{%x+}',''):match('^%s*(.-)%s*$') or ''
        if ct == '’‡ÌËÎË˘Â ÔÂ‰ÏÂÚÓ‚' then
            lua_thread.create(function() wait(300)
                sampSendDialogResponse(dialogId, 1, 0, '') end)
            return false
        end
        if ct == '’‡ÌËÎË˘Â' and (style == 4 or style == 5) then

            local item_count = 0
            if text then
                for _ in text:gmatch('[^\n]+') do item_count = item_count + 1 end
            end
            if item_count > 0 then
                lua_thread.create(function() wait(300)
                    sampSendDialogResponse(dialogId, 1, 0, '') end)
            else
                lua_thread.create(function() wait(300)
                    sampSendDialogResponse(dialogId, 0, 0, '') end)
            end
            return false
        end
        if ct == '’‡ÌËÎË˘Â' and style == 2 and text then
            local pick_all = nil
            local pick_one = nil
            local idx = 0
            for line_t in text:gmatch('[^\n]+') do
                local cl = line_t:gsub('{%x+}',''):match('^%s*(.-)%s*$') or ''

                if cl:find('«‡·‡Ú¸ ‚ÒÂ') then
                    pick_all = idx
                elseif cl:find('«‡·‡Ú¸ ÔÂ‰ÏÂÚ') and not cl:find('¬ÒÂ') then
                    if pick_one == nil then pick_one = idx end
                end
                idx = idx + 1
            end

            local chosen = pick_all or pick_one
            if chosen then
                lua_thread.create(function() wait(300)
                    sampSendDialogResponse(dialogId, 1, chosen, '') end)
                return false
            end
        end

        if ct:find('’‡ÌËÎË˘Â') and style == 0 and text then
            local cl = text:gsub('{%x+}',''):lower()
            if cl:find('Á‡·‡Ú¸') or cl:find('Á‡·Ë‡') then
                lua_thread.create(function() wait(200)
                    sampSendDialogResponse(dialogId, 1, 0, '') end)
                return false
            end
        end
    end

    if text ~= nil and _fh_piar_vr_active then
        if string.find(text, "\xc2\xe0\xf8\xe5 \xf1\xee\xee\xe1\xf9\xe5\xed\xe8\xe5 \xff\xe2\xeb\xff\xe5\xf2\xf1\xff \xf0\xe5\xea\xeb\xe0\xec\xee\xe9?") then
            sampSendDialogResponse(dialogId, 1, "", "")
            return false
        end
    end

    if title and settings.general.auto_ad_confirm then
        local ct = title:gsub('{%x+}',''):match('^%s*(.-)%s*$') or ''
        if ct:find('\xcf\xee\xe4\xe0\xf7\xe0') and not ct:find('\xcf\xee\xe4\xf2\xe2') then
            lua_thread.create(function() wait(400)
                sampSendDialogResponse(dialogId, 1, 0, text and text:match('^%s*(.-)%s*$') or '') end)
            return false
        end
        if ct:find('\xf0\xe0\xe4\xe8\xee') or ct:find('\xd0\xe0\xe4\xe8\xee') then
            lua_thread.create(function() wait(400)
                sampSendDialogResponse(dialogId, 1, settings.general.auto_ad_station_idx or 2, '') end)
            return false
        end
        if ct:find('\xf2\xe8\xef') or ct:find('\xd2\xe8\xef') then
            lua_thread.create(function() wait(400)
                sampSendDialogResponse(dialogId, 1, settings.general.auto_ad_type or 0, '') end)
            return false
        end
        if ct:find('\xcf\xee\xe4\xf2\xe2') then
            lua_thread.create(function() wait(400)
                sampSendDialogResponse(dialogId, 1, -1, '') end)
            return false
        end
    end

    if _G.fmembers_collecting and _G.fmembers_collect_start and os.time() - _G.fmembers_collect_start > 60 then
        _G.fmembers_collecting = false
        _G.fmembers_collect_start = nil
        _G.fmembers_last_dlg_time = nil
        sampAddChatMessage('[Family Helper] {ff4444}\xd1\xe1\xee\xf0 \xf3\xf7\xe0\xf1\xf2\xed\xe8\xea\xee\xe2 \xe7\xe0\xe2\xe8\xf1 \x97 \xf1\xe1\xf0\xee\xf8\xe5\xed.', 0xFFFFFF)
    end
    local clean_title = title and title:gsub('{%x%x%x%x%x%x}', '') or ''
    local is_fmembers_dialog = _G.fmembers_requested and (clean_title:find('| \xd1\xe5\xec\xfc\xff') or clean_title:find('\xc2 \xf1\xe5\xf2\xe8:'))
    if not is_fmembers_dialog and _G.fmembers_collecting and style == 5 then
        is_fmembers_dialog = true
    end
    if is_fmembers_dialog then

        local now_ms = os.clock() * 1000
        if _G.fmembers_last_dlg_time and (now_ms - _G.fmembers_last_dlg_time) < 300 then
            return false
        end
        _G.fmembers_last_dlg_time = now_ms

        if not _G.fmembers_collecting then
            fmembers_online = {}
            _G.fmembers_collecting = true
            _G.fmembers_collect_start = os.time()
        end

        local has_prev = false
        local item_idx = -1
        local next_page_idx = nil
        for line in text:gmatch('[^\n]+') do
            local clean = line:gsub('{%x%x%x%x%x%x}', ''):match('^%s*(.-)%s*$')
            item_idx = item_idx + 1
            if clean and clean ~= '' then
                local rank_num = clean:match('^%((%d+)%)')
                local nick     = clean:match('^%(%d+%)%s+([%a_][%a%d_]*)%(')
                if nick then
                    fmembers_online[nick] = rank_num and ('\xd0\xe0\xed\xe3 ' .. rank_num) or '\xd3\xf7\xe0\xf1\xf2\xed\xe8\xea'
                elseif clean:find('\xd1\xeb\xe5\xe4\xf3\xfe\xf9\xe0\xff') or clean:find('>>') or clean:find('\xbb') then
                    next_page_idx = item_idx
                elseif clean:find('\xef\xf0\xe5\xe4\xfb\xe4\xf3\xf9\xe5\xe9') or clean:find('<<') or clean:find('\xab') then
                    has_prev = true
                end
            end
        end

        local cnt = 0; for _ in pairs(fmembers_online) do cnt = cnt + 1 end

        if next_page_idx ~= nil then
            local saved_id = dialogId
            local click_idx = has_prev and (next_page_idx - 1) or next_page_idx
            lua_thread.create(function()
                wait(100)
                sampSendDialogResponse(saved_id, 1, click_idx, '')
            end)
            return false
        else
            _G.fmembers_collecting = false
            _G.fmembers_collect_start = nil
            _G.fmembers_requested = false
            _G.fmembers_last_dlg_time = nil
            fmembers_last_update = os.time()

            do
                local my_nick_ok, my_nick_raw = pcall(function()
                    return sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) or ''
                end)
                if my_nick_ok and my_nick_raw and my_nick_raw ~= '' and fmembers_online[my_nick_raw] then
                    if settings.family_info.my_name == '' then
                        settings.family_info.my_name = TranslateNick(my_nick_raw)
                    end
                    local my_rank_str = fmembers_online[my_nick_raw]
                    local my_rank_num = my_rank_str:match('(%d+)')
                    if my_rank_num then
                        settings.family_info.my_rank = my_rank_num
                        settings.family_info.my_rank_number = math.max(1, math.min(10, tonumber(my_rank_num)))
                    end
                    save_settings()
                end
            end
            lua_thread.create(function()
                wait(100)
                sampSendDialogResponse(dialogId, 0, 0, '')
            end)
            sampAddChatMessage('[Family Helper] {ffffff}\xce\xed\xeb\xe0\xe9\xed \xee\xe1\xed\xee\xe2\xeb\xb8\xed: ' .. cnt .. ' \xf7\xe5\xeb.', 0xFFA500)
            return false
        end
    end
end

function sampev.onServerMessage(color, text)

    if not text then return end

    local fh_rank_s, fh_joined_s, fh_nick = text:match('\xE2\x80\x8B%[FH:(%d+):(%d+):([%a%d_%.]+)%]')
    if fh_nick then

        fh_online[fh_nick] = {
            rank      = tonumber(fh_rank_s)  or 1,
            joined    = tonumber(fh_joined_s) or 0,
            last_seen = os.time()
        }

        local stripped = text:gsub(' ?\xE2\x80\x8B%[FH:%d+:%d+:[%a%d_%.]+%]', '')

        local clean = stripped:gsub('{%x+}', ''):gsub('%[.-%]%s*[%a%d_%.]+%[%d+%]:%s*', ''):match('^%s*(.-)%s*$') or ''
        local is_ping = (clean == '')
        if not is_ping then
            for _, phrase in ipairs(FH_PING_PHRASES) do
                if clean == phrase then is_ping = true; break end
            end
        end
        if is_ping then
            return false
        end
        return {color, stripped}
    end

        if text:find('\xef\xf0\xe8\xed\xff\xeb \xe2\xe0\xf8\xe5 \xef\xf0\xe5\xe4\xeb\xee\xe6\xe5\xed\xe8\xe5 \xe2\xf1\xf2\xf3\xef\xe8\xf2\xfc \xe2 \xf1\xe5\xec\xfc\xfe') then
        invite_session = invite_session + 1
        settings.general.invite_total = (settings.general.invite_total or 0) + 1
        settings.general.invite_unpaid = (settings.general.invite_unpaid or 0) + 1
        save_settings()
        log_event('\xcf\xf0\xe8\xed\xff\xeb \xe8\xed\xe2\xe0\xe9\xf2: +1 (\xe2\xf1\xe5\xe3\xee ' .. (settings.general.invite_total) .. ')')
        if settings.log_enabled and settings.log_enabled.invite then flog('invite', {type='\xc8\xed\xe2\xe0\xe9\xf2 \xef\xf0\xe8\xed\xff\xf2', nick='(\xe2\xe0\xf8 \xe8\xed\xe2\xe0\xe9\xf2)', total=tostring(settings.general.invite_total or 0)}) end
    end

    if pending_call_nick then
        local phone = text:match('^{%x+}[%a_]+%[%d+%]:%s+{%x+}(%d+)$')
        if phone then
            local captured_nick = pending_call_nick
            pending_call_nick = nil
            lua_thread.create(function()
                wait(300)
                sampSendChat('/call ' .. phone)
                sampAddChatMessage('[Family Helper] {ffffff}\xc7\xe2\xee\xed\xe8\xec ' .. captured_nick .. ': ' .. phone, 0xFFA500)
            end)
            return false
        end
    end

    if pending_sms_nick then
        local phone = text:match('^{%x+}[%a_]+%[%d+%]:%s+{%x+}(%d+)$')
        if phone then
            local captured_nick = pending_sms_nick
            local captured_txt  = pending_sms_text
            pending_sms_nick = nil
            pending_sms_text = ''
            lua_thread.create(function()
                wait(300)
                sampSendChat('/sms ' .. phone .. ' ' .. captured_txt)
                sampAddChatMessage('[Family Helper] {ffffff}SMS -> ' .. captured_nick .. ' (' .. phone .. '): ' .. captured_txt, 0xFFA500)
            end)
            return false
        end
    end

    local ct = text:gsub('{%x%x%x%x%x%x}', '')

    if ct:find('%[\xd1\xe5\xec\xfc') and ct:find('%(\xcd\xee\xe2\xee\xf1\xf2\xe8%)') then

        local n, id, sum = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[(%d+)%]:? *[\xcf\xef]\xee\xef\xee\xeb\xed\xe8\xeb \xf1\xea\xeb\xe0\xe4.-%$(%d[%d%.]*)')
        if not n then
            n, id, sum = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[(%d+)%]:? *[\xcf\xef]\xee\xef\xee\xeb\xed\xe8\xeb \xf1\xea\xeb\xe0\xe4.-:%a+:(%d[%d%.]*)')
        end
        if n then
            if settings.log_enabled and settings.log_enabled.bank then flog('bank', {nick=n, id=id or '?', op='\xcf\xee\xef\xee\xeb\xed\xe8\xeb', sum=sum}) end
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=n, msg='\xcf\xee\xef\xee\xeb\xed\xe8\xeb \xf1\xea\xeb\xe0\xe4 \xf1\xe5\xec\xfc\xe8 \xed\xe0 $'..sum}) end
            if settings.tg and settings.tg.enabled and settings.tg.ev_bank then
                tg_send_if(n, '[FH] \xc8\xe3\xf0\xee\xea '..n..' \xef\xee\xef\xee\xeb\xed\xe8\xeb \xf1\xea\xeb\xe0\xe4 \xf1\xe5\xec\xfc\xe8 \xed\xe0 $'..sum..'.') end
        end

        local n2, id2, sum2 = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[(%d+)%]:? *[\xc2\xe2]\xe7\xff\xeb?.-%$(%d[%d%.]*) \xf1\xee \xf1\xea\xeb\xe0\xe4\xe0')
        if not n2 then
            n2, id2, sum2 = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[(%d+)%]:? *[\xc2\xe2]\xe7\xff\xeb?.-:%a+:(%d[%d%.]*) \xf1\xee \xf1\xea\xeb\xe0\xe4\xe0')
        end
        if not n2 then
            n2, id2, sum2 = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[(%d+)%]:? *[\xd1\xf1]\xed\xff\xeb?.-%$(%d[%d%.]*) \xf1\xee \xf1\xea\xeb\xe0\xe4\xe0')
        end
        if not n2 then
            n2, id2, sum2 = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[(%d+)%]:? *[\xd1\xf1]\xed\xff\xeb?.-:%a+:(%d[%d%.]*) \xf1\xee \xf1\xea\xeb\xe0\xe4\xe0')
        end
        if n2 then
            if settings.log_enabled and settings.log_enabled.bank then flog('bank', {nick=n2, id=id2 or '?', op='\xc2\xe7\xff\xeb', sum=sum2}) end
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=n2, msg='\xc2\xe7\xff\xeb \xf1\xee \xf1\xea\xeb\xe0\xe4\xe0 $'..sum2}) end
            if settings.tg and settings.tg.enabled and settings.tg.ev_bank then
                tg_send_if(n2, '[FH] \xc8\xe3\xf0\xee\xea '..n2..' \xf1\xed\xff\xeb \xf1\xee \xf1\xea\xeb\xe0\xe4\xe0 \xf1\xe5\xec\xfc\xe8 $'..sum2..'.') end
        end

        local nt, talons, repa = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]:? *\xee\xe1\xec\xe5\xed\xff\xeb (%d+) \xf2\xe0\xeb\xee\xed\xee\xe2 \xed\xe0 (%d+) \xee\xf7\xea\xee\xe2 \xf0\xe5\xef\xf3\xf2\xe0\xf6\xe8\xe8')
        if nt then
            if settings.log_enabled and settings.log_enabled.coins then flog('coins', {nick=nt, msg='\xee\xe1\xec\xe5\xed\xff\xeb '..talons..' \xf2\xe0\xeb\xee\xed\xee\xe2 -> +'..repa..' \xf0\xe5\xef\xfb'}) end
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=nt, msg='\xee\xe1\xec\xe5\xed\xff\xeb '..talons..' \xf2\xe0\xeb\xee\xed\xee\xe2 \xed\xe0 '..repa..' \xf0\xe5\xef\xf3\xf2\xe0\xf6\xe8\xe8'}) end
            if settings.tg and settings.tg.enabled and settings.tg.ev_coins then
                tg_send_if(nt, '[FH] \xc8\xe3\xf0\xee\xea '..nt..' \xee\xe1\xec\xe5\xed\xff\xeb '..talons..' \xf2\xe0\xeb\xee\xed\xee\xe2 \xed\xe0 +'..repa..' \xf0\xe5\xef\xf3\xf2\xe0\xf6\xe8\xe8.') end

            if not settings.talons_stats then settings.talons_stats = {} end
            local talon_count = tonumber(talons) or 0
            settings.talons_stats[nt] = (settings.talons_stats[nt] or 0) + talon_count
            save_settings()

            if settings.talon_congrats and settings.talon_congrats.enabled then
                local tlcitems = settings.talon_congrats.items or {}
                local use_fam_tlc = settings.talon_congrats.use_fam
                if #tlcitems > 0 then
                    lua_thread.create(function()
                        local p = use_fam_tlc and '/fam ' or ''
                        for _, tlcitem in ipairs(tlcitems) do
                            local msg = tlcitem.text:gsub('{player_name}', nt)
                            sampSendChat(p .. msg)
                            wait((tlcitem.waiting or 1.5) * 1000)
                        end
                    end)
                end
            end
        end

        local nq, exp, repa2 = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]: *\xe2\xfb\xef\xee\xeb\xed\xe8\xeb \xe5\xe6\xe5\xe4\xed\xe5\xe2\xed\xee\xe5 \xe7\xe0\xe4\xe0\xed\xe8\xe5.+ \xef\xee\xeb\xf3\xf7\xe8\xeb\xe0 (%d+) \xc5\xd5\xd0 \xe8 (%d+) \xf0\xe5\xef\xf3\xf2\xe0\xf6\xe8\xe8')
        if nq then
            if settings.log_enabled and settings.log_enabled.quest then flog('quest', {nick=nq, msg='\xea\xe2\xe5\xf1\xf2: +'..exp..' XP, +'..repa2..' \xf0\xe5\xef\xfb'}) end
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=nq, msg='\xe2\xfb\xef\xee\xeb\xed\xe8\xeb \xea\xe2\xe5\xf1\xf2: +'..exp..' XP +'..repa2..' \xf0\xe5\xef\xfb'}) end
            if settings.tg and settings.tg.enabled and settings.tg.ev_quest then
                tg_send_if(nq, '[FH] \xc8\xe3\xf0\xee\xea '..nq..' \xe2\xfb\xef\xee\xeb\xed\xe8\xeb \xe5\xe6\xe5\xe4\xed\xe5\xe2\xed\xfb\xe9 \xea\xe2\xe5\xf1\xf2. +'..exp..' XP, +'..repa2..' \xf0\xe5\xef\xfb.') end
        end

        local nc, cert_pts = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]: *\xe8\xf1\xef\xee\xeb\xfc\xe7\xee\xe2\xe0\xeb \xf1\xe5\xf0\xf2\xe8\xf4\xe8\xea\xe0\xf2.+%(+(%d+)%)')
        if nc then
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=nc, msg='\xe8\xf1\xef\xee\xeb\xfc\xe7\xee\xe2\xe0\xeb \xf1\xe5\xf0\xf2\xe8\xf4\xe8\xea\xe0\xf2 \xf0\xe5\xef\xf3\xf2\xe0\xf6\xe8\xe8 (+'..cert_pts..')'}) end
        end

        local n_inv, n_new = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]: *\xef\xf0\xe8\xe3\xeb\xe0\xf1\xe8\xeb.+ \xed\xee\xe2\xee\xe3\xee \xf7\xeb\xe5\xed\xe0: ([%a_]+)')
        if n_new then
            if settings.log_enabled and settings.log_enabled.invite then flog('invite', {type='\xcf\xf0\xe8\xe3\xeb\xe0\xf8\xb8\xed', nick=n_new, by=n_inv or ''}) end
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=n_inv or '', msg='\xef\xf0\xe8\xe3\xeb\xe0\xf1\xe8\xeb '..n_new}) end

            if n_inv and n_inv ~= '' then
                if not settings.invite_stats then settings.invite_stats = {} end
                local st = settings.invite_stats[n_inv]
                if not st then st = {total=0, today=0, week=0, month=0, day_key='', week_key='', month_key=''} end
                local dk = os.date('%d.%m.%Y')
                local wk = os.date('%V.%G')
                local mk = os.date('%m.%Y')
                if st.day_key   ~= dk then st.today = 0; st.day_key   = dk end
                if st.week_key  ~= wk then st.week  = 0; st.week_key  = wk end
                if st.month_key ~= mk then st.month = 0; st.month_key = mk end
                st.total = (st.total or 0) + 1
                st.today = (st.today or 0) + 1
                st.week  = (st.week  or 0) + 1
                st.month = (st.month or 0) + 1
                settings.invite_stats[n_inv] = st
                save_settings()

                if settings.tg and settings.tg.enabled then
                    if n_inv == my_nick() then

                        local lines = {
                            '[FH] ' .. n_inv .. ' \xcf\xf0\xe8\xed\xff\xeb \xe8\xe3\xf0\xee\xea\xe0 ' .. n_new .. ' (\xe8\xed\xe2\xe0\xe9\xf2\xee\xe2: ' .. (st.total or 0) .. ')',
                            string.rep('-', 25),
                            '\xd1\xe5\xe3\xee\xe4\xed\xff:   ' .. (st.today or 0),
                            '\xcd\xe5\xe4\xe5\xeb\xff:    ' .. (st.week  or 0),
                            '\xcc\xe5\xf1\xff\xf6:     ' .. (st.month or 0),
                            '\xc2\xf1\xb8 \xe2\xf0\xe5\xec\xff: ' .. (st.total or 0),
                        }
                        tg_send(table.concat(lines, '\n'))
                    elseif settings.tg.ev_invite then

                        tg_send_if(n_inv, '[FH] \xc8\xe3\xf0\xee\xea '..n_inv..' \xef\xf0\xe8\xe3\xeb\xe0\xf1\xe8\xeb '..n_new..' \xe2 \xf1\xe5\xec\xfc\xfe.')
                    end
                end
            end
        end

        local n_join = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]: *\xe2\xf1\xf2\xf3\xef\xe8\xeb')
        if n_join then
            if settings.log_enabled and settings.log_enabled.invite then flog('invite', {type='\xc2\xf1\xf2\xf3\xef\xe8\xeb', nick=n_join}) end
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=n_join, msg='\xe2\xf1\xf2\xf3\xef\xe8\xeb \xe2 \xf1\xe5\xec\xfc\xfe'}) end
            if settings.tg and settings.tg.enabled and settings.tg.ev_join then
                tg_send_if(n_inv or '', '[FH] \xc8\xe3\xf0\xee\xea '..n_join..' \xe2\xf1\xf2\xf3\xef\xe8\xeb \xe2 \xf1\xe5\xec\xfc\xfe.') end
        end

        local n_left = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]: *\xf1\xe0\xec\xee\xf1\xf2\xee\xff\xf2\xe5\xeb\xfc\xed\xee \xef\xee\xea\xe8\xed\xf3\xeb')
        if n_left then
            if settings.log_enabled and settings.log_enabled.invite then flog('invite', {type='\xcf\xee\xea\xe8\xed\xf3\xeb', nick=n_left}) end
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=n_left, msg='\xf1\xe0\xec\xee\xf1\xf2\xee\xff\xf2\xe5\xeb\xfc\xed\xee \xef\xee\xea\xe8\xed\xf3\xeb \xf1\xe5\xec\xfc\xfe'}) end
            if settings.tg and settings.tg.enabled and settings.tg.ev_leave then
                tg_send_if('', '[FH] \xc8\xe3\xf0\xee\xea '..n_left..' \xf1\xe0\xec\xee\xf1\xf2\xee\xff\xf2\xe5\xeb\xfc\xed\xee \xef\xee\xea\xe8\xed\xf3\xeb \xf1\xe5\xec\xfc\xfe!') end
        end

        local n_kicker, n_kicked = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]: *\xe2 \xee\xf4\xf4\xeb\xe0\xe9\xed\xe5 \xe2\xfb\xe3\xed\xe0\xeb \xe8\xe3\xf0\xee\xea\xe0 ([%a_]+)')
        local kick_offline = n_kicked ~= nil
        if not n_kicked then
            n_kicker, n_kicked = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]: *\xe2\xfb\xe3\xed\xe0\xeb \xe8\xe3\xf0\xee\xea\xe0 ([%a_]+)')
        end
        if n_kicked then
            if settings.log_enabled and settings.log_enabled.invite then flog('invite', {type='\xca\xe8\xea', nick=n_kicked, by=n_kicker or ''}) end
            if settings.log_enabled and settings.log_enabled.news then
                local kick_msg = kick_offline and ('\xe2 \xee\xf4\xf4\xeb\xe0\xe9\xed\xe5 \xea\xe8\xea\xed\xf3\xeb '..n_kicked..' \xe8\xe7 \xf1\xe5\xec\xfc\xe8') or ('\xea\xe8\xea\xed\xf3\xeb '..n_kicked..' \xe8\xe7 \xf1\xe5\xec\xfc\xe8')
                flog('news', {nick=n_kicker or '', msg=kick_msg})
            end
            if settings.tg and settings.tg.enabled and settings.tg.ev_leave then
                local tg_kick_msg = kick_offline
                    and ('[FH] \xc8\xe3\xf0\xee\xea '..(n_kicker or '?')..' \xe2 \xee\xf4\xf4\xeb\xe0\xe9\xed\xe5 \xe2\xfb\xe3\xed\xe0\xeb \xe8\xe3\xf0\xee\xea\xe0 '..n_kicked..' \xe8\xe7 \xf1\xe5\xec\xfc\xe8!')
                    or  ('[FH] \xc8\xe3\xf0\xee\xea '..(n_kicker or '?')..' \xe2\xfb\xe3\xed\xe0\xeb \xe8\xe3\xf0\xee\xea\xe0 '..n_kicked..' \xe8\xe7 \xf1\xe5\xec\xfc\xe8!')
                tg_send_if(n_kicker or '', tg_kick_msg)
            end
        end

        local n_muter, n_muted, dur, reason =
            ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]: *\xe2\xfb\xe4\xe0\xeb \xe1\xe0\xed \xf1\xe5\xec\xe5\xe9\xed\xee\xe3\xee \xf7\xe0\xf2\xe0 ([%a_]+)%[%d+%], \xed\xe0 (%d+)\xec\xe8\xed, \xef\xf0\xe8\xf7\xe8\xed\xe0: (.*)')
        if n_muted then
            if settings.log_enabled and settings.log_enabled.mute then flog('mute', {nick=n_muted, by=n_muter or '?', duration=dur or '?', reason=reason or ''}) end
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=n_muter or '', msg='\xec\xf3\xf2 '..n_muted..' \xed\xe0 '..dur..'\xec\xe8\xed: '..(reason or '')}) end
            if settings.tg and settings.tg.enabled and settings.tg.ev_mute then
                tg_send_if(n_muter or '', '[FH] \xc8\xe3\xf0\xee\xea '..(n_muter or '?')..' \xe2\xfb\xe4\xe0\xeb \xec\xf3\xf2 \xe8\xe3\xf0\xee\xea\xf3 '..n_muted..' \xed\xe0 '..(dur or '?')..' \xec\xe8\xed. \xcf\xf0\xe8\xf7\xe8\xed\xe0: '..(reason or '\x97')) end
        end

        local n_ldr, n_zam = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]: *\xed\xe0\xe7\xed\xe0\xf7\xe8\xeb ([%a_]+)%[%d+%] \xe7\xe0\xec\xe5\xf1\xf2\xe8\xf2\xe5\xeb\xe5\xec')
        if n_zam then
            if settings.log_enabled and settings.log_enabled.rank then flog('rank', {nick=n_zam, rank='\xe7\xe0\xec', by=n_ldr or ''}) end
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=n_ldr or '', msg=n_zam..' \xed\xe0\xe7\xed\xe0\xf7\xe5\xed \xe7\xe0\xec\xe5\xf1\xf2\xe8\xf2\xe5\xeb\xe5\xec'}) end
        end

        local n_ldr2, n_zam2 = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]: *\xf1\xed\xff\xeb ([%a_]+) \xf1 \xef\xee\xf1\xf2\xe0 \xe7\xe0\xec\xe5\xf1\xf2\xe8\xf2\xe5\xeb\xff')
        if n_zam2 then
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=n_ldr2 or '', msg=n_zam2..' \xf1\xed\xff\xf2 \xf1 \xef\xee\xf1\xf2\xe0 \xe7\xe0\xec\xe0'}) end
        end

        local n_admin_r, n_rank_num = ct:match('%[.+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]: *\xf3\xf1\xf2\xe0\xed\xee\xe2\xe8\xeb \xf0\xe0\xed\xe3 (%d+)')
        local n_rank_target = ct:match('\xe8\xe3\xf0\xee\xea\xf3 ([%a_]+)%[')
        if n_admin_r and n_rank_num and n_rank_target then
            if settings.log_enabled and settings.log_enabled.rank then flog('rank', {nick=n_rank_target, rank=n_rank_num, by=n_admin_r}) end
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=n_admin_r, msg='\xf0\xe0\xed\xe3 '..n_rank_num..' -> '..n_rank_target}) end
        end

    elseif ct:find('%[\xcd\xee\xe2\xee\xf1\xf2\xe8 \xd1\xe5\xec\xfc\xe8%]') then
        local n_lvl, lvl = ct:match('%[\xcd\xee\xe2\xee\xf1\xf2\xe8 \xd1\xe5\xec\xfc\xe8%] \xd7\xeb\xe5\xed \xf1\xe5\xec\xfc\xe8: ([%a_]+)%[%d+%] \xe4\xee\xf1\xf2\xe8\xe3 (%d+) \xf3\xf0\xee\xe2\xed\xff')
        if n_lvl then
            if settings.log_enabled and settings.log_enabled.level then flog('level', {nick=n_lvl, lvl=lvl}) end
            if settings.log_enabled and settings.log_enabled.news then flog('news', {nick=n_lvl, msg='\xe4\xee\xf1\xf2\xe8\xe3 '..lvl..' \xf3\xf0\xee\xe2\xed\xff'}) end
            if settings.tg and settings.tg.enabled and settings.tg.ev_level then
                tg_send_if('', '[FH] \xc8\xe3\xf0\xee\xea '..n_lvl..' \xe4\xee\xf1\xf2\xe8\xe3 '..lvl..' \xf3\xf0\xee\xe2\xed\xff.') end

            if settings.general.auto_congrats then
                local already = false
                for _, n in ipairs(congrats_batch) do
                    if n == n_lvl then already = true; break end
                end
                if not already then table.insert(congrats_batch, n_lvl) end
                if not congrats_batch_timer then congrats_batch_timer = os.time() end
            end
        end

    elseif ct:find('%[\xd1\xe5\xec\xfc') then
        local chat_nick = ct:match('([%a_][%a%d_]+)%[%d+%]:%s*.+')
        local chat_msg  = ct:match('[%a_][%a%d_]+%[%d+%]:%s*(.*)')
        if chat_nick and chat_msg and chat_msg ~= '' then
            chat_msg = chat_msg:match('^%s*(.-)%s*$')
            if settings.log_enabled and settings.log_enabled.chat then
                flog('chat', {nick=chat_nick, msg=chat_msg})
            end
        end
    end

    local coins_nick = nil
    coins_nick = coins_nick or text:match('([%a_]+) \xee\xe1\xec\xe5\xed\xff\xeb %d+ \xf1\xe5\xec\xe5\xe9\xed')
    coins_nick = coins_nick or text:match('([%a_]+) \xef\xe5\xf0\xe5\xe4\xe0\xeb %d+ \xf1\xe5\xec\xe5\xe9\xed')
    coins_nick = coins_nick or text:match('([%a_]+) \xf1\xe4\xe0\xeb %d+ \xf1\xe5\xec\xe5\xe9\xed')
    coins_nick = coins_nick or text:match('([%a_]+) \xe2\xed\xb8\xf1 %d+ \xec\xee\xed\xe5\xf2 \xe2 \xf1\xe5\xec\xe5\xe9\xed\xfb\xe9')
    if coins_nick and (settings.coins_thanks and settings.coins_thanks.enabled) then
        local items = settings.coins_thanks and settings.coins_thanks.items or {}
        if #items > 0 then
            local use_fam = settings.coins_thanks.use_fam
            lua_thread.create(function()
                for _, item in ipairs(items) do
                    wait(math.floor((item.waiting or 1.0) * 1000))
                    local msg = (item.text or ''):gsub('{player_name}', coins_nick)
                    msg = msg:gsub('{my_name}', settings.family_info.my_name or '')
                    msg = msg:gsub('{family_name}', settings.family_info.family_name or '')
                    if msg ~= '' then
                        if use_fam then msg = '/fam ' .. msg end
                        sampSendChat(msg)
                    end
                end
            end)
            log_event('\xcc\xee\xed\xe5\xf2\xfb \xee\xf2: ' .. coins_nick)
            if settings.log_enabled and settings.log_enabled.coins then flog('coins', {nick=coins_nick}) end
            if not settings.coins_stats then settings.coins_stats = {} end
            settings.coins_stats[coins_nick] = (settings.coins_stats[coins_nick] or 0) + 1
            save_settings()
            if settings.tg and settings.tg.enabled and settings.tg.ev_coins then
                tg_send_if(coins_nick, '[FH] \xc8\xe3\xf0\xee\xea ' .. coins_nick .. ' \xf1\xe4\xe0\xeb \xf1\xe5\xec\xe5\xe9\xed\xfb\xe5 \xec\xee\xed\xe5\xf2\xfb.')
            end
        end
    end

    if settings.general.auto_welcome then
        local nm = text:match('([%a][%w_]+) \xe2\xf1\xf2\xf3\xef\xe8\xeb%(\xe0%) \xe2 \xe2\xe0\xf8\xf3 \xf1\xe5\xec\xfc\xfe')
            or text:match('([%a][%w_]+)%[%d+%] \xef\xf0\xe8\xed\xff\xf2%(\xe0%) \xe2 \xf1\xe5\xec\xfc\xfe')
            or text:match('\xef\xf0\xe8\xe3\xeb\xe0\xf1\xe8\xeb \xe2 \xf1\xe5\xec\xfc\xfe \xed\xee\xe2\xee\xe3\xee \xf7\xeb\xe5\xed\xe0: ([%a][%w_]+)')
            or text:match('(.+) \xef\xf0\xe8\xed\xff\xf2%(\xe0%) \xe2 \xf1\xe5\xec\xfc\xfe')
            or text:match('(.+) \xc2\xf1\xf2\xf3\xef\xe8\xeb%(\xe0%) \xe2 \xe2\xe0\xf8\xf3 \xf1\xe5\xec\xfc\xfe')
            or text:match('\xef\xf0\xe8\xe3\xeb\xe0\xf1\xe8\xeb \xe2 \xf1\xe5\xec\xfc\xfe \xed\xee\xe2\xee\xe3\xee \xf7\xeb\xe5\xed\xe0: (.+)')
        if nm then
            nm = nm:gsub('{%x+}', ''):gsub('%[%d+%]', ''):gsub('%s+', ''):match('^%s*(.-)%s*$') or ''
            lua_thread.create(function()
                local p = settings.welcome.use_fam and '/fam ' or ''
                local vars = settings.welcome.variants or {}
                local idx = (settings.welcome.variant_idx or 0) % #vars + 1
                settings.welcome.variant_idx = idx
                save_settings()
                local chosen = vars[idx] or vars[1] or {}

                if settings.tg and settings.tg.auto_role then
                    fh_update_self()
                    fh_send_ping()
                end
                for _, item in ipairs(chosen.items or {}) do
                    if item.text and item.text ~= '' then
                        wait((item.waiting or 1.5) * 1000)
                        local msg_text = p .. processText(item.text, nil):gsub('{player_name}', nm)
                        sampSendChat(msg_text)
                    end
                end
            end)
        end
    end

    if settings.general.auto_congrats then
        local lp = nil
        local lp_lvl = nil

        if not lp then lp, lp_lvl = text:match('(.+) \xef\xee\xe2\xfb\xf1\xe8\xeb%(\xe0%) \xf1\xe2\xee\xe9 \xf3\xf0\xee\xe2\xe5\xed\xfc \xe4\xee (%d+)') end
        if not lp then lp, lp_lvl = text:match('(.+) \xef\xee\xe2\xfb\xf1\xe8\xeb \xf1\xe2\xee\xe9 \xf3\xf0\xee\xe2\xe5\xed\xfc \xe4\xee (%d+)') end
        if not lp then lp, lp_lvl = text:match('(.+) \xef\xee\xeb\xf3\xf7\xe8\xeb%(\xe0%) \xed\xee\xe2\xfb\xe9 \xf3\xf0\xee\xe2\xe5\xed\xfc[%s%-]*(%d*)') end
        if not lp then lp, lp_lvl = text:match('(.+) \xef\xee\xeb\xf3\xf7\xe8\xeb \xed\xee\xe2\xfb\xe9 \xf3\xf0\xee\xe2\xe5\xed\xfc[%s%-]*(%d*)') end
        if not lp then lp = text:match('(.+) \xe4\xee\xf1\xf2\xe8\xe3%(\xeb\xe0%) \xed\xee\xe2\xee\xe3\xee \xf3\xf0\xee\xe2\xed\xff') end
        if not lp then lp = text:match('(.+) \xe4\xee\xf1\xf2\xe8\xe3 \xed\xee\xe2\xee\xe3\xee \xf3\xf0\xee\xe2\xed\xff') end

        if lp then
            lp = lp:gsub('{%x+}', ''):gsub('%[%d+%]', ''):match('^%s*(.-)%s*$') or lp
        end
        if lp_lvl == '' then lp_lvl = nil end
        local family_xp = text:find('\xc2 \xf1\xe5\xec\xfc\xfe \xed\xe0\xf7\xe8\xf1\xeb\xe5\xed \xee\xef\xfb\xf2')
        if (lp and lp ~= '') or family_xp then
            local send_nick = lp or ''
            if send_nick ~= '' then
                if settings.log_enabled and settings.log_enabled.level then flog('level', {nick=send_nick, lvl=lp_lvl}) end
                if settings.tg and settings.tg.enabled and settings.tg.ev_level then
                    if settings.tg.auto_role then
                        fh_update_self(); fh_send_ping()
                        lua_thread.create(function()
                            wait(8000)
                            if am_i_senior() then
                                tg_send('[FH] \xc8\xe3\xf0\xee\xea ' .. send_nick .. (lp_lvl and (' \xe4\xee\xf1\xf2\xe8\xe3 ' .. lp_lvl .. ' \xf3\xf0\xee\xe2\xed\xff.') or ' \xef\xee\xe4\xed\xff\xeb \xf3\xf0\xee\xe2\xe5\xed\xfc.'))
                            end
                        end)
                    else
                        tg_send('[FH] \xc8\xe3\xf0\xee\xea ' .. send_nick .. (lp_lvl and (' \xe4\xee\xf1\xf2\xe8\xe3 ' .. lp_lvl .. ' \xf3\xf0\xee\xe2\xed\xff.') or ' \xef\xee\xe4\xed\xff\xeb \xf3\xf0\xee\xe2\xe5\xed\xfc.'))
                    end
                end

                local already = false
                for _, n in ipairs(congrats_batch) do
                    if n == send_nick then already = true; break end
                end
                if not already then
                    table.insert(congrats_batch, send_nick)
                end
            end

            if not congrats_batch_timer then
                congrats_batch_timer = os.time()
            end
        end
    end

    local q_name = nil
    q_name = q_name or text:match('\xd7\xeb\xe5\xed \xf1\xe5\xec\xfc\xe8 (.-)%s+\xe2\xfb\xef\xee\xeb\xed\xe8\xeb \xe5\xe6\xe5\xe4\xed\xe5\xe2\xed\xee\xe5 \xe7\xe0\xe4\xe0\xed\xe8\xe5')
    q_name = q_name or text:match('^(.-)%s+\xe2\xfb\xef\xee\xeb\xed\xe8\xeb%b()%s+\xe5\xe6\xe5\xe4\xed\xe5\xe2\xed\xee\xe5 \xe7\xe0\xe4\xe0\xed\xe8\xe5')
    q_name = q_name or text:match('^(.-)%s+\xe2\xfb\xef\xee\xeb\xed\xe8\xeb \xf1\xe5\xec\xe5\xe9\xed\xfb\xe9 \xea\xe2\xe5\xf1\xf2')
    q_name = q_name or text:match('^(.-)%s+\xf1\xe4\xe0\xeb \xf1\xe5\xec\xe5\xe9\xed\xfb\xe9 \xea\xe2\xe5\xf1\xf2')
    if q_name then
        q_name = q_name:gsub('{%x%x%x%x%x%x}', ''):match('^%s*(.-)%s*$')
        settings.quests_stats[q_name] = (settings.quests_stats[q_name] or 0) + 1
        save_settings()
        if settings.log_enabled and settings.log_enabled.quest then flog('quest', {nick=q_name}) end
        if settings.tg and settings.tg.enabled and settings.tg.ev_quest then
            if settings.tg.auto_role then
                fh_update_self(); fh_send_ping()
                local _qn = q_name
                lua_thread.create(function()
                    wait(8000)
                    if am_i_senior() then
                        tg_send('[FH] \xc8\xe3\xf0\xee\xea ' .. _qn .. ' \xe2\xfb\xef\xee\xeb\xed\xe8\xeb \xf1\xe5\xec\xe5\xe9\xed\xfb\xe9 \xea\xe2\xe5\xf1\xf2.')
                    end
                end)
            else
                tg_send('[FH] \xc8\xe3\xf0\xee\xea ' .. q_name .. ' \xe2\xfb\xef\xee\xeb\xed\xe8\xeb \xf1\xe5\xec\xe5\xe9\xed\xfb\xe9 \xea\xe2\xe5\xf1\xf2.')
            end
        end

        if settings.quest_congrats and settings.quest_congrats.enabled then
            local vars = settings.quest_congrats.variants or {}
            local idx = (#vars > 0) and ((settings.quest_congrats.variant_idx or 0) % #vars + 1) or 1
            settings.quest_congrats.variant_idx = idx
            save_settings()
            local chosen = (vars[idx] or vars[1] or {}).items or {}
            local use_fam_q = settings.quest_congrats.use_fam
            if #chosen > 0 then
                lua_thread.create(function()
                    local p = use_fam_q and '/fam ' or ''
                    for _, qitem in ipairs(chosen) do
                        if qitem.text and qitem.text ~= '' then
                            wait((qitem.waiting or 1.5) * 1000)
                            sampSendChat(p .. processText(qitem.text, nil):gsub('{player_name}', q_name))
                        end
                    end
                end)
            end
        end
    end

    local rank_admin, rank_nick, rank_new =
        text:match('%[%S+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[%d+%]:.+ (\xe8\xe7\xec\xe5\xed\xe8\xeb \xf0\xe0\xed\xe3|\xe2\xfb\xe4\xe0\xeb \xf0\xe0\xed\xe3|\xf3\xf1\xf2\xe0\xed\xee\xe2\xe8\xeb \xf0\xe0\xed\xe3).-([%a_]+)%[%d+%]')
    if not rank_nick then

        rank_admin = text:match('%[%S+ %(\xcd\xee\xe2\xee\xf1\xf2\xe8%)%] ([%a_]+)%[')
        rank_nick  = text:match('\xe8\xe3\xf0\xee\xea\xf3 ([%a_]+)%[%d+%]')
        rank_new   = text:match('\xf0\xe0\xed\xe3 (%d+)')
    end
    if rank_nick and rank_new then
        if settings.log_enabled and settings.log_enabled.rank then
            flog('rank', {nick=rank_nick:gsub('{%x%x%x%x%x%x}',''), rank=rank_new,
                          by=(rank_admin or ''):gsub('{%x%x%x%x%x%x}','')})
        end
    end

    local joined_name = text:match('(.+) \xe2\xf1\xf2\xf3\xef\xe8\xeb%(\xe0%) \xe2 \xe2\xe0\xf8\xf3 \xf1\xe5\xec\xfc\xfe') or text:match('(.+) \xef\xf0\xe8\xed\xff\xeb \xe2\xe0\xf8\xe5 \xef\xf0\xe5\xe4\xeb\xee\xe6\xe5\xed\xe8\xe5')
 or text:match('\xef\xf0\xe8\xe3\xeb\xe0\xf1\xe8\xeb \xe2 \xf1\xe5\xec\xfc\xfe \xed\xee\xe2\xee\xe3\xee \xf7\xeb\xe5\xed\xe0: (.+)')
    if joined_name then
        joined_name = joined_name:gsub('{%x+}', '')
        for _, bl_user in ipairs(settings.blacklist) do
            if bl_user.name == joined_name then
                lua_thread.create(function()
                    wait(1000)
                    sampSendChat("/fam [\xc2\xcd\xc8\xcc\xc0\xcd\xc8\xc5] \xc8\xe3\xf0\xee\xea " .. joined_name .. " \xed\xe0\xf5\xee\xe4\xe8\xf2\xf1\xff \xe2 \xd7\xd1 \xf1\xe5\xec\xfc\xe8! \xcf\xf0\xe8\xf7\xe8\xed\xe0: " .. tostring(bl_user.reason))
                end)
            end
        end
    end

    if settings.general.auto_mute_insults or settings.general.auto_mute_spam or settings.general.auto_mute_flood then
        local clean_text = text:gsub('{%x%x%x%x%x%x}', '')
        local fm_name, fm_id, fm_text = nil, nil, nil

        if clean_text:find('^%[.-%]') then

            fm_name, fm_id, fm_text = clean_text:match('^%[.-%]%s+(.-)%s*%[(%d+)%]%s*:%s*(.+)')
            if not fm_id then

                local nm, tx = clean_text:match('^%[.-%]%s+(.-)%s*:%s*(.+)')
                if nm and tx then
                    fm_name = nm
                    fm_text = tx

                    local ok, pid = pcall(sampGetPlayerIdByNickname, nm)
                    if ok and pid and pid >= 0 then fm_id = tostring(pid) end
                end
            end
        end

        if fm_id and fm_text then

            local my_name = settings.family_info and settings.family_info.my_name or ''
            if fm_name and my_name ~= '' and fm_name:lower() == my_name:lower() then
                fm_id = nil
            end
        end

        if fm_id and fm_text then
            if not mute_tracker then mute_tracker = {} end
            if not mute_tracker[fm_id] then
                mute_tracker[fm_id] = { last_mute = 0, msgs = {}, spam_text = '', spam_count = 0, spam_time = 0 }
            end
            local tr = mute_tracker[fm_id]
            local now = os.time()

            local function do_mute(reason, mute_min)
                if os.difftime(now, tr.last_mute) < 300 then return end
                tr.last_mute = now
                lua_thread.create(function()
                    wait(600)
                    sampSendChat(string.format('/fammute %s %d %s', fm_id, mute_min, reason))
                    log_event(reason .. ' -> ID ' .. fm_id)
                end)
            end

            if settings.general.auto_mute_insults then
                local lt = ' ' .. fm_text:lower() .. ' '

                local insults = {
                    '\xf1\xf3\xea\xe0','\xf1\xf3\xea\xf3','\xf1\xf3\xea\xe8','\xf1\xf3\xea\xe5','\xf1\xf3\xea\xe0\xf0',
                    '\xe1\xeb\xff\xf2\xfc','\xe1\xeb\xff\xe4\xfc','\xe1\xeb\xff\xe4\xf1\xea',
                    '\xef\xe8\xe4\xee\xf0','\xef\xe8\xe4\xf0\xe8\xeb\xe0','\xef\xe8\xe4\xee\xf0\xe0\xf1',
                    '\xf5\xf3\xe9','\xf5\xf3\xe9\xeb\xee','\xf5\xf3\xe9\xed\xff',
                    '\xf8\xeb\xfe\xf5\xe0','\xf8\xe0\xeb\xe0\xe2\xe0',
                    '\xef\xe8\xe7\xe4\xe5\xf6','\xef\xe8\xe7\xe4\xe0','\xef\xe8\xe7\xe4\xe0\xe1\xee\xeb',
                    '\xe5\xe1\xeb\xe0\xed','\xf3\xe5\xe1\xe8\xf9\xe5',
                    '\xb8\xe1\xe0\xed\xfb\xe9','\xb8\xe1\xe0\xf2\xfc','\xe4\xee\xeb\xe1\xee\xb8\xe1',
                    '\xe3\xe0\xed\xe4\xee\xed','\xec\xf3\xe4\xe0\xea','\xe7\xe0\xeb\xf3\xef\xe0','\xf1\xf3\xf7\xea\xe0','\xf3\xe1\xeb\xfe\xe4\xee\xea',
                    '\xef\xee\xf1\xf1\xfb\xf8\xfc','\xef\xee\xf1\xf1\xfb',
                    '\xee\xf1\xeb\xe0\xe5\xe1\xe8\xed\xe0','\xee\xf1\xeb\xe0\xe5\xe1',
                    '\xe1\xf0\xe0\xea\xee\xe2\xe0\xed',
                    '\xee\xf1\xea\xe0\xe5\xf8\xfc','\xee\xf1\xea\xe0\xe5\xf2',
                    '\xe4\xfb\xe8\xe6',
                    '\xf2\xf3\xef\xe0\xff','\xf2\xf3\xef\xee\xe9','\xf2\xf3\xef\xfb\xe5',
                    '\xe8\xe4\xe8\xee\xf2','\xe4\xe5\xe1\xe8\xeb','\xea\xf0\xe5\xf2\xe8\xed','\xf3\xf0\xee\xe4',
                    '\xeb\xee\xf5'
                }
                for _, w in ipairs(insults) do
                    if lt:find(w, 1, true) then
                        do_mute('\xc0\xe2\xf2\xee-\xec\xf3\xf2: \xce\xf1\xea\xee\xf0\xe1\xeb\xe5\xed\xe8\xff', settings.general.auto_mute_insults_time or 60)
                        break
                    end
                end
            end

            if settings.general.auto_mute_spam then
                if tr.spam_text == fm_text and os.difftime(now, tr.spam_time) < 90 then
                    tr.spam_count = tr.spam_count + 1
                else
                    tr.spam_text  = fm_text
                    tr.spam_count = 1
                    tr.spam_time  = now
                end
                if tr.spam_count >= 3 then
                    tr.spam_count = 0
                    do_mute('\xc0\xe2\xf2\xee-\xec\xf3\xf2: \xd1\xef\xe0\xec', settings.general.auto_mute_spam_time or 30)
                end
            end

            if settings.general.auto_mute_flood then
                local flood_n   = settings.general.flood_msg_count or 5
                local flood_sec = settings.general.flood_interval  or 15
                table.insert(tr.msgs, now)

                local i = 1
                while i <= #tr.msgs do
                    if os.difftime(now, tr.msgs[i]) > flood_sec then
                        table.remove(tr.msgs, i)
                    else
                        i = i + 1
                    end
                end
                if #tr.msgs >= flood_n then
                    tr.msgs = {}
                    do_mute('\xc0\xe2\xf2\xee-\xec\xf3\xf2: \xd4\xeb\xf3\xe4', settings.general.auto_mute_flood_time or 30)
                end
            end
        end
    end

    if settings.general.auto_quest_congrats then
        if text:find('\xe2\xfb\xef\xee\xeb\xed\xe8\xeb \xe5\xe6\xe5\xe4\xed\xe5\xe2\xed\xee\xe5 \xe7\xe0\xe4\xe0\xed\xe8\xe5, \xf1\xe5\xec\xfc\xff \xef\xee\xeb\xf3\xf7\xe8\xeb\xe0') then
            lua_thread.create(function()
                wait(1500)
                sampSendChat('/fam \xd1\xef\xe0\xf1\xe8\xe1\xee \xe7\xe0 \xe2\xfb\xef\xee\xeb\xed\xe5\xed\xe8\xe5 \xe7\xe0\xe4\xe0\xed\xe8\xff! \xd2\xe0\xea \xe4\xe5\xf0\xe6\xe0\xf2\xfc!')
            end)
        end
    end

    if settings.general.auto_keyword_invite then
        local clean = text:gsub('{%x+}', ''):lower()

        local kid, msg = clean:match('^.-%[(%d+)%]%s*:%s*(.+)$')
        if kid and msg then
            local myid = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
            local tid = tonumber(kid)

            if tid and tid ~= myid and not invited_players[tid] then

                local their_nick = sampGetPlayerNickname(tid) or ''
                local tag = settings.family_info.family_tag or ''
                -- –¢–∞ –∂–µ –ª–æ–≥–∏–∫–∞, —á—Ç–æ –∏ –≤ –∞–≤—Ç–æ-–∏–Ω–≤–∞–π—Ç–µ –ø–æ —Ä–∞–¥–∏—É—Å—É: —Å–Ω–∞—á–∞–ª–∞
                -- —Ç–æ—á–Ω—ã–π —Å–ø–∏—Å–æ–∫ /fmembers, —Ç–µ–≥ –≤ –Ω–∏–∫–µ ‚Äî fallback.
                local already_member = fmembers_online[their_nick] ~= nil
                if not already_member then
                    already_member = tag ~= '' and their_nick:find(tag, 1, true)
                end
                if not already_member then
                    local msg_trim = msg:match('^%s*(.-)%s*$')
                    local keywords = settings.general.keyword_invite_list or {'\xe8\xed\xe2', '\xe8\xed\xe2\xe0\xe9\xf2', '\xef\xf0\xe8\xec\xe8'}
                    for _, word in ipairs(keywords) do
                        if msg_trim == word or msg_trim:find('^' .. word) then
                            invited_players[tid] = os.time()
                            sampSendChat('/faminvite ' .. kid)
                            log_event('\xc0\xe2\xf2\xee-\xe8\xed\xe2\xe0\xe9\xf2: ' .. their_nick)
                            break
                        end
                    end
                end
            end
        end
    end
end

function sampev.onSendChat(text)
    if not text then return end
    if settings.general.rp_chat then
        local orig = text
        text = text:sub(1,1):rupper() .. text:sub(2)
        if not text:find('[%.%!%?]$') then text = text .. '.' end
        if text ~= orig then return {text} end
    end
end

function sampev.onSendCommand(text)
    if not text then return end

    if text:find('\xE2\x80\x8B%[FH:', 1, false) then return {text} end
    if settings.general.rp_chat then
        local orig = text
        for _, c in ipairs({'/fam','/vr','/al','/s','/b','/n','/r','/rb','/f','/fb','/do','/me'}) do
            if text:find('^' .. c .. ' ') then
                local ct = text:match('^' .. c .. ' (.+)')
                if ct then ct = ct:sub(1,1):rupper() .. ct:sub(2); text = c .. ' ' .. ct
                    if not text:find('[%.%!%?]$') then text = text .. '.' end
                end
            end
        end
        if text ~= orig then return {text} end
    end
end

function sampev.onPlayerDisconnect(playerId, reason)
    local ok, nick = pcall(sampGetPlayerNickname, playerId)
    if ok and nick and fh_online[nick] then
        fh_online[nick] = nil

    end
end
imgui.OnInitialize(function() imgui.GetIO().IniFilename = nil; apply_theme() end)

imgui.OnFrame(
    function() return settings.general.float_btn_enable and #nearby_players > 0 and not InteractMenu[0] and not InteractSelectPlayer[0] end,
    function()
        local d = settings.general.custom_dpi
        local bs = settings.general.float_btn_size or 1.0
        local bw = 110 * d * bs
        local bh = 36 * d * bs
        local ar = settings.interface.accent_r or 1.0
        local ag = settings.interface.accent_g or 0.65
        local ab = settings.interface.accent_b or 0.0

        if settings.general.float_btn_x < 0 or settings.general.float_btn_x > (sizeX - 30)
        or settings.general.float_btn_y < 0 or settings.general.float_btn_y > (sizeY - 30) then
            settings.general.float_btn_x = sizeX - 190; settings.general.float_btn_y = math.floor(sizeY * 0.42); save_settings()
        end
        imgui.SetNextWindowPos(imgui.ImVec2(settings.general.float_btn_x, settings.general.float_btn_y), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowSize(imgui.ImVec2(120 * d * bs, 46 * d * bs), imgui.Cond.FirstUseEver)
        local dummy = imgui.new.bool(true)
        imgui.Begin("##fbtn", dummy, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoTitleBar)
        if not isMonetLoader() then imgui.SetWindowFontScale(d * bs) end
        local pos = imgui.GetWindowPos()
        if pos.x ~= settings.general.float_btn_x or pos.y ~= settings.general.float_btn_y then
            settings.general.float_btn_x = pos.x; settings.general.float_btn_y = pos.y; save_settings()
        end

        local wsz = imgui.GetWindowSize()
        local new_bs = wsz.y / (46 * d)
        if new_bs < 0.5 then new_bs = 0.5 elseif new_bs > 2.0 then new_bs = 2.0 end
        if math.abs(new_bs - bs) > 0.02 then
            settings.general.float_btn_size = new_bs; save_settings()
        end
        local cnt = #nearby_players
        local function ru_plural(n, one, few, many)

            local n10, n100 = n % 10, n % 100
            if n10 == 1 and n100 ~= 11 then return one
            elseif n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14) then return few
            else return many end
        end
        local fcount_icon = cnt == 1 and fa_icon.USER or (cnt == 2 and fa_icon.USER_GROUP or fa_icon.USERS)
        local flabel = fcount_icon .. '  ' .. safe_u8(cnt .. ' ' .. ru_plural(cnt,
            '\xe8\xe3\xf0\xee\xea',
            '\xe8\xe3\xf0\xee\xea\xe0',
            '\xe8\xe3\xf0\xee\xea\xee\xe2'))
        if imgui.Button(flabel, imgui.ImVec2(-1, -1)) then
            if cnt == 1 then interact_player_id = nearby_players[1]; InteractMenu[0] = true
            elseif cnt > 1 then InteractSelectPlayer[0] = true end
        end
        imgui.End()
    end
)

imgui.OnFrame(function() return InteractSelectPlayer[0] end, function()
    local d = settings.general.custom_dpi
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))

    imgui.SetNextWindowSizeConstraints(imgui.ImVec2(200*d, 80*d), imgui.ImVec2(math.min(400*d, sizeX - 20), sizeY - 40))
    imgui.Begin(u8' \xc8\xe3\xf0\xee\xea\xe8 \xf0\xff\xe4\xee\xec##isp', InteractSelectPlayer, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize)
    change_dpi()
    local pl = nearby_players
    if #pl == 0 then imgui.Text(u8'\xcd\xe8\xea\xee\xe3\xee \xed\xe5\xf2')
    else

        local _list_h = math.min(#pl * 30*d, sizeY - 160*d)
        if imgui.BeginChild('##isp_list', imgui.ImVec2(240*d, _list_h), false) then
            fh_touch_scroll('##isp_list')
            for _, pid in ipairs(pl) do
                local ru = TranslateNick(sampGetPlayerNickname(pid) or '')
                if imgui.Button(safe_u8(ru .. ' [' .. pid .. ']'), imgui.ImVec2(240*d, 26*d)) then
                    interact_player_id = pid; InteractMenu[0] = true; InteractSelectPlayer[0] = false
                end
            end
            imgui.EndChild()
        end
    end
    imgui.Spacing()
    if imgui.Button(fa_icon.XMARK .. '  ' .. u8'\xc7\xe0\xea\xf0\xfb\xf2\xfc##isp', imgui.ImVec2(-1, 0)) then InteractSelectPlayer[0] = false end
    imgui.End()
end)

imgui.OnFrame(function() return InteractMenu[0] end, function()
    if not interact_player_id or not sampIsPlayerConnected(interact_player_id) then InteractMenu[0] = false; return end
    local d = settings.general.custom_dpi
    local nick = sampGetPlayerNickname(interact_player_id) or '???'
    local ru = TranslateNick(nick)
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(safe_u8(' ' .. ru .. ' [' .. interact_player_id .. ']'), InteractMenu, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize)
    change_dpi()

    local gap_x = 8*d
    local gap_y = 6*d
    imgui.Spacing()
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(ar*0.3, ag*0.3, ab*0.3, 1))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(ar*0.5, ag*0.5, ab*0.5, 1))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(ar*0.7, ag*0.7, ab*0.7, 1))

    local min_bw = 130 * d
    local max_text_w = 0
    for _, inter in ipairs(settings.interactions) do
        local tw = imgui.CalcTextSize(safe_u8(inter.name or '')).x
        if tw > max_text_w then max_text_w = tw end
    end
    local bw = math.max(min_bw, max_text_w + 24*d)
    local bh = 28 * d
    local cols = 2
    local count = #settings.interactions
    if isActiveCommand then imgui.TextDisabled(u8'\xc2\xfb\xef\xee\xeb\xed\xff\xe5\xf2\xf1\xff...')
    else
        for i, inter in ipairs(settings.interactions) do
            if imgui.Button(safe_u8(inter.name or ''), imgui.ImVec2(bw, bh)) then
                send_interaction(i, interact_player_id)
            end
            if i % cols ~= 0 and i < count then
                imgui.SameLine(0, gap_x)
            elseif i < count then
                imgui.Dummy(imgui.ImVec2(1, gap_y))
            end
        end
    end
    imgui.PopStyleColor(3)
    imgui.Spacing()
    imgui.End()
end)

-- –ï–¥–∏–Ω–∞—è –∫–∞—Ä—Ç–æ—á–∫–∞ —Å—Ç–∞—Ç–∏—Å—Ç–∏–∫–∏ –¥–ª—è –î–∞—à–±–æ—Ä–¥–∞: –∏–∫–æ–Ω–∫–∞ + –ø–æ–¥–ø–∏—Å—å + –∑–Ω–∞—á–µ–Ω–∏–µ,
-- –≤–∏–∑—É–∞–ª—å–Ω–æ –≤ –¥—É—Ö–µ –∏–≥—Ä–æ–≤–æ–≥–æ –æ–∫–Ω–∞ "–°–µ–º–µ–π–Ω—ã–π —Ñ–ª–∞–≥ / –£—Ä–æ–≤–µ–Ω—å —Å–µ–º—å–∏" –∏ —Ç.–ø.
-- –†–∏—Å—É–µ—Ç—Å—è –∫–∞–∫ –ø—Ä—è–º–æ—É–≥–æ–ª—å–Ω—ã–π child —Å —Ñ–æ–Ω–æ–º —á—É—Ç—å —Å–≤–µ—Ç–ª–µ–µ –æ–∫–Ω–∞ –∏ —Ç–æ–Ω–∫–æ–π
-- —Ä–∞–º–∫–æ–π –≤ –∞–∫—Ü–µ–Ω—Ç–Ω–æ–º —Ü–≤–µ—Ç–µ, —á—Ç–æ–±—ã –∫–∞—Ä—Ç–æ—á–∫–∏ –±—ã–ª–∏ –æ–¥–∏–Ω–∞–∫–æ–≤—ã–º–∏ –ø–æ —Ä–∞–∑–º–µ—Ä—É
-- –∏ —Ä–æ–≤–Ω–æ –≤—ã—Å—Ç—Ä–∞–∏–≤–∞–ª–∏—Å—å –≤ —Å–µ—Ç–∫—É (—Å–∏–º–º–µ—Ç—Ä–∏—á–Ω–æ), –∞ –Ω–µ ¬´–ø–ª—ã–ª–∏¬ª –∫–∞–∫ –æ–±—ã—á–Ω—ã–π
-- —Ç–µ–∫—Å—Ç –≤ –∫–æ–ª–æ–Ω–∫–∞—Ö.
-- –ó–∞—â–∏—Ç–Ω—ã–π –∫–æ–Ω—Å—Ç—Ä—É–∫—Ç–æ—Ä —Ü–≤–µ—Ç–∞: –µ—Å–ª–∏ –ø–æ –∫–∞–∫–æ–π-—Ç–æ –ø—Ä–∏—á–∏–Ω–µ imgui.ImVec4
-- –Ω–∞ —É—Å—Ç—Ä–æ–π—Å—Ç–≤–µ –ø–æ–ª—å–∑–æ–≤–∞—Ç–µ–ª—è –Ω–µ –≤–µ—Ä–Ω—É–ª –≤–∞–ª–∏–¥–Ω—É—é FFI-—Å—Ç—Ä—É–∫—Ç—É—Ä—É
-- (–∫–æ–Ω—Ñ–ª–∏–∫—Ç –≤–µ—Ä—Å–∏–π mimgui –º–µ–∂–¥—É —Å–∫—Ä–∏–ø—Ç–∞–º–∏ / –¥—Ä—É–≥–∞—è —Å–±–æ—Ä–∫–∞ –±–∏–±–ª–∏–æ—Ç–µ–∫–∏),
-- fh_safe_color() –æ—Ç–ª–æ–≤–∏—Ç —ç—Ç–æ —á–µ—Ä–µ–∑ pcall –∏ –≤–µ—Ä–Ω—ë—Ç –±–µ–∑–æ–ø–∞—Å–Ω—ã–π –¥–µ—Ñ–æ–ª—Ç,
-- –≤–º–µ—Å—Ç–æ –Ω–µ–æ–±—Ä–∞–±–æ—Ç–∞–Ω–Ω–æ–≥–æ –∫—Ä–∞—à–∞ –≤—Å–µ–≥–æ —Å–∫—Ä–∏–ø—Ç–∞ –≤ TextColored.
local function fh_safe_color(r, g, b, a)
    local ok, col = pcall(imgui.ImVec4, r, g, b, a)
    if ok and type(col) == 'cdata' then return col end
    -- –§–æ–ª–ª–±—ç–∫: –ø—Ä–æ–±—É–µ–º —Å–æ–∑–¥–∞—Ç—å –Ω–µ–π—Ç—Ä–∞–ª—å–Ω—ã–π –±–µ–ª—ã–π —Ü–≤–µ—Ç —Ç–µ–º –∂–µ –ø—É—Ç—ë–º;
    -- –µ—Å–ª–∏ –∏ —ç—Ç–æ –Ω–µ 'cdata' ‚Äî –∑–Ω–∞—á–∏—Ç imgui.ImVec4 –±–∏—Ç—ã–π –≤ –ø—Ä–∏–Ω—Ü–∏–ø–µ,
    -- –¥–∞–ª—å—à–µ –∫–∞—Ä—Ç–æ—á–∫–∏ –ø—Ä–æ—Å—Ç–æ –Ω–µ –∫—Ä–∞—Å—è—Ç—Å—è, –Ω–æ –∏ –Ω–µ –∫—Ä–∞—à–∞—Ç —Å–∫—Ä–∏–ø—Ç.
    local ok2, fallback = pcall(imgui.ImVec4, 1, 1, 1, 1)
    if ok2 and type(fallback) == 'cdata' then return fallback end
    return nil
end

local function fh_stat_card(id, icon, label, value, w, h, value_color, icon_color)
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0

    -- value_color/icon_color –º–æ–≥–ª–∏ –ø—Ä–∏–π—Ç–∏ –∫–∞–∫ nil (–æ–±—ã—á–Ω—ã–π —Å–ª—É—á–∞–π) –ò–õ–ò
    -- –∫–∞–∫ —á—Ç–æ-—Ç–æ –Ω–µ-cdata, –µ—Å–ª–∏ –≤—ã–∑—ã–≤–∞—é—â–∏–π –∫–æ–¥ –∫–æ–≥–¥–∞-–Ω–∏–±—É–¥—å –ø–µ—Ä–µ–¥–∞—Å—Ç
    -- —á–∏—Å–ª–æ/—Å—Ç—Ä–æ–∫—É –ø–æ –æ—à–∏–±–∫–µ ‚Äî —Ä–∞–Ω—å—à–µ —ç—Ç–æ –ø–∞–¥–∞–ª–æ –ø—Ä—è–º–æ –≤ TextColored.
    if type(value_color) ~= 'cdata' then value_color = nil end
    if type(icon_color) ~= 'cdata' then icon_color = nil end

    icon_color = icon_color or fh_safe_color(ar, ag, ab, 1)
    value_color = value_color or fh_safe_color(0.92, 0.92, 0.92, 1)
    local label_color = fh_safe_color(.62, .62, .65, 1)

    imgui.PushStyleColor(imgui.Col.ChildBg, fh_safe_color(1,1,1,0.035))
    imgui.PushStyleColor(imgui.Col.Border, fh_safe_color(ar, ag, ab, 0.35))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8*d)
    if imgui.BeginChild(id, imgui.ImVec2(w, h), true) then
        imgui.Indent(2*d)
        if icon_color then imgui.TextColored(icon_color, icon) else imgui.Text(icon) end
        imgui.SameLine(0, 6*d)
        -- –ü–µ—Ä–µ–Ω–æ—Å –ø–æ —Å–ª–æ–≤–∞–º –≤–º–µ—Å—Ç–æ –æ–±—Ä–µ–∑–∫–∏: —Ä–∞–Ω—å—à–µ label/value —Ä–∏—Å–æ–≤–∞–ª–∏—Å—å
        -- —á–µ—Ä–µ–∑ imgui.Text/TextColored, –∫–æ—Ç–æ—Ä—ã–µ –Ω–µ –ø–µ—Ä–µ–Ω–æ—Å—è—Ç —Å—Ç—Ä–æ–∫—É –∏ —Ä–µ–∂—É—Ç
        -- –¥–ª–∏–Ω–Ω—ã–π —Ç–µ–∫—Å—Ç ("–ù–∞—á–∏—Å–ª–µ–Ω–∏—è —Å –¥–µ–ø–æ–∑–∏—Ç–∞", "–°–æ–¥–µ—Ä–∂–∞–Ω–∏–µ –≤ PayDay",
        -- –∑–Ω–∞—á–µ–Ω–∏—è —Ñ–ª–∞–≥–∞/–∫–≤–∞—Ä—Ç–∏—Ä—ã) –ø–æ —à–∏—Ä–∏–Ω–µ –∫–∞—Ä—Ç–æ—á–∫–∏. PushTextWrapPos —Å
        -- –ø–æ–∑–∏—Ü–∏–µ–π "–¥–æ –ø—Ä–∞–≤–æ–≥–æ –∫—Ä–∞—è child-–æ–∫–Ω–∞" –≤–∫–ª—é—á–∞–µ—Ç –ø–µ—Ä–µ–Ω–æ—Å –∏–º–µ–Ω–Ω–æ
        -- –≤–Ω—É—Ç—Ä–∏ –∫–∞—Ä—Ç–æ—á–∫–∏, –∞ –Ω–µ –ø–æ –≤—Å–µ–π —à–∏—Ä–∏–Ω–µ –æ–∫–Ω–∞ –ø–ª–∞–≥–∏–Ω–∞.
        imgui.PushTextWrapPos(imgui.GetCursorPos().x + w - 10*d)
        if label_color then imgui.TextColored(label_color, tostring(label)) else imgui.Text(tostring(label)) end
        imgui.PopTextWrapPos()
        imgui.Spacing()
        imgui.PushTextWrapPos(imgui.GetCursorPos().x + w - 10*d)
        if value_color then imgui.TextColored(value_color, tostring(value)) else imgui.Text(tostring(value)) end
        imgui.PopTextWrapPos()
        imgui.Unindent(2*d)
    end
    imgui.EndChild()
    imgui.PopStyleVar(1)
    imgui.PopStyleColor(2)
end

-- –†—è–¥ –∏–∑ N –æ–¥–∏–Ω–∞–∫–æ–≤—ã—Ö –∫–∞—Ä—Ç–æ—á–µ–∫ —Å —Ä–∞–≤–Ω—ã–º–∏ –æ—Ç—Å—Ç—É–ø–∞–º–∏ –º–µ–∂–¥—É –Ω–∏–º–∏ (—Å–∏–º–º–µ—Ç—Ä–∏—á–Ω–æ).
-- cards = { {id, icon, label, value, value_color, icon_color}, ... }
local function fh_stat_row(cards, h, gap)
    local d = settings.general.custom_dpi
    gap = gap or 8*d
    local total_w = imgui.GetWindowContentRegionWidth()
    local n = #cards
    local w = (total_w - gap * (n - 1)) / n
    for i, c in ipairs(cards) do
        if i > 1 then imgui.SameLine(0, gap) end
        fh_stat_card(c[1], c[2], c[3], c[4], w, h, c[5], c[6])
    end
end

-- –Â‰‡ÍÚËÓ‚‡ÌËÂ Ì‡Á‚‡ÌËˇ Ë ÚÂ„‡ ÒÂÏ¸Ë (‚ÍÎ‡‰Í‡ ´ƒ‡¯·Ó‰ª)
function fh_render_family_edit()
    if imgui.SmallButton(fa_icon.PEN_TO_SQUARE .. '  ' .. u8'»ÁÏÂÌËÚ¸ Ì‡Á‚‡ÌËÂ ÒÂÏ¸Ë##fam_edit_toggle') then
        _G.fh_fam_edit = not _G.fh_fam_edit
        if _G.fh_fam_edit then
            _G.fh_fam_name_buf = imgui.new.char[256](u8(settings.family_info.family_name or ''))
            _G.fh_fam_tag_buf  = imgui.new.char[256](u8(settings.family_info.family_tag or ''))
        end
    end
    if not _G.fh_fam_edit or not _G.fh_fam_name_buf then return end
    imgui.Text(u8' Õ‡Á‚‡ÌËÂ ÒÂÏ¸Ë:')
    imgui.PushItemWidth(-1)
    if imgui.InputText('##fam_name_in', _G.fh_fam_name_buf, 256) then
        settings.family_info.family_name = u8:decode(ffi.string(_G.fh_fam_name_buf)):match('^%s*(.-)%s*$')
        save_settings()
    end
    imgui.PopItemWidth()
    imgui.Text(u8' “Â„ ÒÂÏ¸Ë:')
    imgui.PushItemWidth(-1)
    if imgui.InputText('##fam_tag_in', _G.fh_fam_tag_buf, 256) then
        settings.family_info.family_tag = u8:decode(ffi.string(_G.fh_fam_tag_buf)):match('^%s*(.-)%s*$')
        save_settings()
    end
    imgui.PopItemWidth()
    imgui.TextDisabled(u8'  œÓ‰ÒÚ‡‚ÎˇÂÚÒˇ ‚ ÚÂÍÒÚ˚ ‚ÏÂÒÚÓ {family_name} Ë {family_tag}')
end

local function fh_render_tab1()
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
            local main_h = imgui.GetContentRegionAvail().y
            if imgui.BeginTabBar('##maintabs') then
                if imgui.BeginTabItem(fa_icon.GAUGE .. '  ' .. u8'\xc4\xe0\xf8\xe1\xee\xf0\xe4') then
                    if imgui.BeginChild('##info', imgui.ImVec2(-1, -1), false) then
                        fh_touch_scroll('##info')
                        imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xc8\xed\xf4\xee\xf0\xec\xe0\xf6\xe8\xff \xee \xf1\xe5\xec\xfc\xe5'); imgui.Separator()
                        imgui.Spacing()
                        local online_count = 0
                        for _ in pairs(fmembers_online) do online_count = online_count + 1 end
                        local online_text, online_color
                        if online_count > 0 then
                            online_text, online_color = online_count .. u8' \xf7\xe5\xeb.', imgui.ImVec4(0.2,1.0,0.3,1.0)
                        elseif fmembers_last_update > 0 then
                            online_text, online_color = '0', imgui.ImVec4(1.0,0.6,0.2,1.0)
                        else
                            online_text, online_color = '\x97', imgui.ImVec4(.55,.55,.55,1)
                        end
                        -- settings.family_info.* —Ö—Ä–∞–Ω–∏—Ç—Å—è –≤ cp1251 (—Ç–∞–∫ –∏—Ö —Å–æ—Ö—Ä–∞–Ω—è–µ—Ç
                        -- TranslateNick/—Ä—É—á–Ω–æ–π –≤–≤–æ–¥), –ø–æ—ç—Ç–æ–º—É –ø–µ—Ä–µ–¥ –≤—ã–≤–æ–¥–æ–º –≤ imgui
                        -- (–∫–æ—Ç–æ—Ä—ã–π –æ–∂–∏–¥–∞–µ—Ç UTF-8) –∏—Ö –Ω—É–∂–Ω–æ –ø—Ä–æ–≥–Ω–∞—Ç—å —á–µ—Ä–µ–∑ safe_u8,
                        -- –∏–Ω–∞—á–µ –ø–æ–ª—É—á–∞—é—Ç—Å—è "–≤–æ–ø—Ä–æ—Å–∏–∫–∏" ‚Äî —ç—Ç–æ –∏ –±—ã–ª–∞ –ø—Ä–∏—á–∏–Ω–∞ –∫—Ä–∞–∫–æ–∑—è–±—Ä.
                        fh_stat_row({
                            {'##dc1', fa_icon.HOUSE,      u8'\xd1\xe5\xec\xfc\xff',  settings.family_info.family_name ~= '' and safe_u8(settings.family_info.family_name) or '\x97'},
                            {'##dc2', fa_icon.USER,       u8'\xcd\xe8\xea',          settings.family_info.my_name ~= '' and safe_u8(settings.family_info.my_name) or '\x97'},
                            {'##dc3', fa_icon.MEDAL,      u8'\xd0\xe0\xed\xe3',      settings.family_info.my_rank ~= '' and safe_u8(settings.family_info.my_rank) or '\x97'},
                            {'##dc4', fa_icon.SIGNAL,     u8'\xce\xed\xeb\xe0\xe9\xed', online_text, online_color},
                        }, 54*d)
                        imgui.Spacing()
                        fh_render_family_edit()
                        imgui.Spacing(); imgui.Separator()

                        imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd0\xe0\xf1\xf8\xe8\xf0\xe5\xed\xed\xfb\xe5 \xe4\xe0\xed\xed\xfb\xe5 \xf1\xe5\xec\xfc\xe8')
                        imgui.SameLine(imgui.GetWindowContentRegionWidth() - 26*d)
                        if imgui.Button(fa_icon.ROTATE .. '##fammenu_upd', imgui.ImVec2(26*d, 20*d)) then
                            sampSendChat('/fammenu')
                        end
                        imgui.Separator()

                        local fm = fh_fammenu_data
                        if not fm then
                            imgui.TextDisabled(u8'  \xcd\xe0\xe6\xec\xe8\xf2\xe5 \xea\xed\xee\xef\xea\xf3 \xee\xe1\xed\xee\xe2\xeb\xe5\xed\xe8\xff \x97 \xf1\xea\xf0\xe8\xef\xf2 \xee\xf2\xef\xf0\xe0\xe2\xe8\xf2 /fammenu')
                        else
                            -- –†—è–¥ 1: —Ä–µ–ø—É—Ç–∞—Ü–∏—è / –¥–µ–Ω—å–≥–∏ –Ω–∞ —Å–∫–ª–∞–¥–µ / –º–æ–Ω–µ—Ç—ã / % —Å –¥–µ–ø–æ–∑–∏—Ç–∞. (4 –∫–∞—Ä—Ç–æ—á–∫–∏)
                            -- –†–∞–Ω—å—à–µ "\xc4\xe5\xef\xee\xe7\xe8\xf2 %" –∏ "\xc7\xe0\xf0\xef\xeb\xe0\xf2\xe0 \xf7\xe5\xf0\xe5\xe7" –±—ã–ª–∏
                            -- –ø–æ–¥–ø–∏—Å–∞–Ω—ã –Ω–µ–≤–µ—Ä–Ω–æ –∏ –ø—É—Ç–∞–ª–∏—Å—å –º–µ—Å—Ç–∞–º–∏ –ø–æ —Å–º—ã—Å–ª—É: fm.deposit ‚Äî —ç—Ç–æ
                            -- % –Ω–∞—á–∏—Å–ª–µ–Ω–∏–π —Å –¥–µ–ø–æ–∑–∏—Ç–∞, –∞ fm.payDay ‚Äî —Ä–µ–ø—É—Ç–∞—Ü–∏—è —Å–æ–¥–µ—Ä–∂–∞–Ω–∏—è —Å–µ–º—å–∏
                            -- –≤ PayDay (—Ç–æ —Å–∞–º–æ–µ "39 —Ä–µ–ø." –∏–∑ –∏–≥—Ä–æ–≤–æ–≥–æ –æ–∫–Ω–∞), –∞ –Ω–µ "–∑–∞—Ä–ø–ª–∞—Ç–∞ —á–µ—Ä–µ–∑".
                            fh_stat_row({
                                {'##fs1', fa_icon.STAR,                 u8'\xd0\xe5\xef\xf3\xf2\xe0\xf6\xe8\xff',            fh_num_fmt(fm.reputation or 0)},
                                {'##fs2', fa_icon.SACK_DOLLAR,          u8'\xd1\xea\xeb\xe0\xe4',                            '$' .. fh_num_fmt(fm.money or 0)},
                                {'##fs3', fa_icon.COINS,                u8'\xcc\xee\xed\xe5\xf2\xfb',                        fh_num_fmt(fm.coins or 0)},
                                {'##fs4', fa_font_src.PERCENT,          u8'\xcd\xe0\xf7\xe8\xf1\xeb\xe5\xed\xe8\xff \xf1 \xe4\xe5\xef\xee\xe7\xe8\xf2\xe0', (fm.deposit or 0) .. '%'},
                            }, 66*d)
                            imgui.Spacing()

                            -- –†—è–¥ 2: —Å–æ–¥–µ—Ä–∂–∞–Ω–∏–µ –≤ PayDay / —É—Ä–æ–≤–µ–Ω—å —Å–µ–º—å–∏ / –æ–ø—ã—Ç. (3 –∫–∞—Ä—Ç–æ—á–∫–∏)
                            -- "–£—á–∞—Å—Ç–Ω–∏–∫–∏/–û–Ω–ª–∞–π–Ω" —É–±—Ä–∞–Ω–æ: —É —Å–µ—Ä–≤–µ—Ä–∞ –Ω–µ—Ç –ø–∞–∫–µ—Ç–∞
                            -- —Å –æ–±—â–∏–º —á–∏—Å–ª–æ–º —É—á–∞—Å—Ç–Ω–∏–∫–æ–≤ —Å–µ–º—å–∏ (—Ç–æ–ª—å–∫–æ /fmembers,
                            -- –∞ –æ–Ω –ø–æ–∫–∞–∑—ã–≤–∞–µ—Ç –∏—Å–∫–ª—é—á–∏—Ç–µ–ª—å–Ω–æ online-–∏–≥—Ä–æ–∫–æ–≤) ‚Äî
                            -- –ø–æ–∫–∞–∑—ã–≤–∞—Ç—å —Ç—É—Ç –±—ã–ª–æ –Ω–µ—á–µ–≥–æ, –∫—Ä–æ–º–µ —É–∂–µ –æ—Ç–æ–±—Ä–∞–∂—ë–Ω–Ω–æ–≥–æ
                            -- –≤—ã—à–µ "–û–Ω–ª–∞–π–Ω" –≤ –ø–µ—Ä–≤–æ–º –∏–Ω—Ñ–æ-—Ä—è–¥—É.
                            -- "–ê–≤—Ç–æ—Ä–∏—Ç–µ—Ç" (fm.evil) —Ç–æ–∂–µ —É–±—Ä–∞–Ω: –Ω–∏ –≤ –æ–¥–Ω–æ–º
                            -- –ø–µ—Ä–µ—Ö–≤–∞—á–µ–Ω–Ω–æ–º –ø–∞–∫–µ—Ç–µ –∏ –Ω–∏ –Ω–∞ —Ñ–æ—Ä—É–º–∞—Ö Arizona RP
                            -- –Ω–µ –Ω–∞—à–ª–æ—Å—å –æ—Ñ–∏—Ü–∏–∞–ª—å–Ω–æ–≥–æ –Ω–∞–∑–≤–∞–Ω–∏—è –¥–ª—è —ç—Ç–æ–≥–æ –ø–æ–ª—è,
                            -- –ø–æ–∫–∞–∑—ã–≤–∞—Ç—å —Ü–∏—Ñ—Ä—É –ø–æ–¥ –≥–∞–¥–∞—Ç–µ–ª—å–Ω–æ–π –ø–æ–¥–ø–∏—Å—å—é –Ω–µ —Å—Ç–∞–ª–∏.
                            fh_stat_row({
                                {'##fs5', fa_icon.BRIEFCASE,    u8'\xd1\xee\xe4\xe5\xf0\xe6\xe0\xed\xe8\xe5 \xe2 PayDay', fh_num_fmt(fm.payDay or 0) .. ' ' .. u8'\xf0\xe5\xef.'},
                                {'##fs6', fa_icon.LAYER_GROUP,  u8'\xd3\xf0\xee\xe2\xe5\xed\xfc \xf1\xe5\xec\xfc\xe8', fm.level or 0},
                                {'##fs7', fa_icon.CHART_LINE,   u8'\xce\xef\xfb\xf2',                    (fm.currentExp or 0) .. ' / ' .. (fm.totalExp or 0)},
                            }, 66*d)
                            imgui.Spacing()

                            -- –†—è–¥ 3: –∞–ª—å—è–Ω—Å / —Ñ–ª–∞–≥ / –∫–≤–∞—Ä—Ç–∏—Ä–∞. (3 –∫–∞—Ä—Ç–æ—á–∫–∏)
                            -- fm.flag/fm.apart –ø—Ä–∏—Ö–æ–¥—è—Ç –æ—Ç —Å–µ—Ä–≤–µ—Ä–∞ –≤ CP1251 (–∫–∞–∫ –∏
                            -- fm.message/ldr.role), –ø–æ—ç—Ç–æ–º—É –Ω—É–∂–µ–Ω safe_u8 ‚Äî –±–µ–∑ –Ω–µ–≥–æ
                            -- imgui –ø–æ–ª—É—á–∞–µ—Ç —Å—ã—Ä—ã–µ CP1251-–±–∞–π—Ç—ã –∏ —Ä–∏—Å—É–µ—Ç "??????".
                            fh_stat_row({
                                {'##fs10', fa_icon.HANDSHAKE,    u8'\xc0\xeb\xfc\xff\xed\xf1',    fm.aliance ~= '' and fm.aliance or '\x97'},
                                {'##fs11', fa_icon.FLAG,         u8'\xd4\xeb\xe0\xe3',            fm.flag ~= '' and safe_u8(fm.flag) or '\x97'},
                                {'##fs12', fa_icon.BUILDING,     u8'\xca\xe2\xe0\xf0\xf2\xe8\xf0\xe0', fm.apart ~= '' and safe_u8(fm.apart) or '\x97'},
                            }, 66*d)

                            if fm.message and fm.message ~= '' then
                                imgui.Spacing()
                                imgui.TextColored(imgui.ImVec4(.55,.55,.55,1), u8' \xce\xef\xe8\xf1\xe0\xed\xe8\xe5:'); imgui.SameLine()
                                imgui.TextWrapped(safe_u8(' ' .. fm.message))
                            end

                            if fm.leaders and #fm.leaders > 0 then
                                imgui.Spacing()
                                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd1\xee\xe2\xe5\xf2 \xf1\xe5\xec\xfc\xe8'); imgui.Separator()
                                for _, ldr in ipairs(fm.leaders) do
                                    local is_on = (ldr.online == 1)
                                    imgui.TextColored(
                                        is_on and imgui.ImVec4(0.2,1.0,0.3,1.0) or imgui.ImVec4(.5,.5,.5,1),
                                        u8(is_on and ' \xce' or ' \x97'))
                                    imgui.SameLine()
                                    imgui.Text(safe_u8(' ' .. (ldr.role or '') .. ':'))
                                    imgui.SameLine()
                                    imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), safe_u8(' ' .. (ldr.name or '')))
                                end
                            end

                            imgui.Spacing()
                            imgui.TextDisabled(safe_u8('  \xee\xe1\xed\xee\xe2\xeb\xe5\xed\xee: ' .. (fh_fammenu_last_update > 0 and os.date('%H:%M:%S', fh_fammenu_last_update) or '\x97')))
                        end

                        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                        imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd1\xef\xe0\xe2\xed \xf2\xf0\xe0\xed\xf1\xef\xee\xf0\xf2\xe0'); imgui.Separator()
                        local spawn_hw = (imgui.GetWindowContentRegionWidth() - 12*d) / 4
                        local spawn_opts = {
                            {'10\xf1##sp10', 10000, fa_icon.CLOCK},
                            {'20\xf1##sp20', 20000, fa_icon.CLOCK},
                            {'30\xf1##sp30', 30000, fa_icon.CLOCK},
                            {'\xd1\xe5\xe9\xf7\xe0\xf1##sp0', 0, fa_icon.BOLT},
                        }
                        for si, sd in ipairs(spawn_opts) do
                            if si > 1 then imgui.SameLine() end
                            if imgui.Button(sd[3] .. '  ' .. u8(sd[1]), imgui.ImVec2(spawn_hw, 28*d)) then
                                lua_thread.create(function()
                                    if sd[2] > 0 then
                                        sampSendChat('/fam \xc2\xed\xe8\xec\xe0\xed\xe8\xe5! \xd7\xe5\xf0\xe5\xe7 ' .. (sd[2]/1000) .. ' \xf1\xe5\xea \xf1\xef\xe0\xe2\xed \xf2\xf0\xe0\xed\xf1\xef\xee\xf0\xf2\xe0!')
                                        wait(sd[2])
                                    end
                                    sampSendChat('/famspawn')
                                    wait(200); sampSendChat('/fam \xd2\xf0\xe0\xed\xf1\xef\xee\xf0\xf2 \xe7\xe0\xf1\xef\xe0\xe2\xed\xe5\xed!')
                                end)
                            end
                        end
                        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                        imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xc8\xed\xe2\xe0\xe9\xf2\xfb'); imgui.Separator()
                        imgui.TextDisabled(safe_u8('  \xd1\xe5\xf1\xf1\xe8\xff: ' .. invite_session .. '   \xc2\xf1\xe5\xe3\xee: ' .. (settings.general.invite_total or 0) .. '   \xcd\xe5\xee\xef\xeb\xe0\xf7.: ' .. (settings.general.invite_unpaid or 0)))
                        local stat_hw = (imgui.GetWindowContentRegionWidth() - 8*d) / 2
                        if imgui.Button(fa_icon.ROTATE_LEFT .. '  ' .. u8'\xd1\xe1\xf0\xee\xf1 \xf1\xe5\xf1\xf1\xe8\xe8##rstinv', imgui.ImVec2(stat_hw, 24*d)) then invite_session = 0 end
                        imgui.SameLine()
                        if imgui.Button(fa_icon.ROTATE_LEFT .. '  ' .. u8'\xd1\xe1\xf0\xee\xf1 \xe2\xf1\xe5\xe3\xee##rstall', imgui.ImVec2(stat_hw, 24*d)) then
                            invite_session = 0; settings.general.invite_total = 0; save_settings()
                        end
                        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                        imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xcf\xee\xf1\xeb\xe5\xe4\xed\xe8\xe5 \xf1\xee\xe1\xfb\xf2\xe8\xff'); imgui.Separator()
                        local combined_events = {}
                        local news = famlog and famlog.news or {}
                        for i = 1, math.min(8, #news) do
                            local ev = news[i]
                            if ev then
                                local nick = ev.nick or ''
                                local msg  = ev.msg  or ''
                                local t    = (ev.time or '') ~= '' and ('[' .. ev.time .. '] ') or ''
                                table.insert(combined_events, t .. nick .. (nick ~= '' and ': ' or '') .. msg)
                            end
                        end
                        for _, ev in ipairs(event_log) do
                            table.insert(combined_events, ev)
                            if #combined_events >= 10 then break end
                        end
                        if #combined_events == 0 then
                            imgui.TextDisabled(u8'  \xcd\xe5\xf2 \xf1\xee\xe1\xfb\xf2\xe8\xe9')
                        else
                            for ei = 1, math.min(8, #combined_events) do
                                imgui.TextDisabled(safe_u8('  ' .. combined_events[ei]))
                            end
                        end
                        imgui.EndChild()
                    end
                    imgui.EndTabItem()
                end
                if imgui.BeginTabItem(fa_icon.SLIDERS .. '  ' .. u8'\xd4\xf3\xed\xea\xf6\xe8\xe8') then
                    if imgui.BeginChild('##func', imgui.ImVec2(-1, -1), false) then
                        fh_touch_scroll('##func')
                        imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd4\xf3\xed\xea\xf6\xe8\xe8 \xf1\xea\xf0\xe8\xef\xf2\xe0'); imgui.Separator()
                        local funcs = {

                            {u8'\xc0\xe2\xf2\xee-\xe8\xed\xe2\xe0\xe9\xf2',        'auto_invite',         'g'},
                            {u8'\xc0\xe2\xf2\xee-\xef\xf0\xe8\xe2\xe5\xf2\xf1\xf2\xe2\xe8\xe5',  'auto_welcome',        'g'},
                            {u8'\xc0\xe2\xf2\xee-\xef\xee\xe7\xe4\xf0\xe0\xe2\xeb\xe5\xed\xe8\xe5','auto_congrats',       'g'},
                            {u8'\xc0\xe2\xf2\xee \xea\xe2\xe5\xf1\xf2',            'auto_quest_congrats',  'g'},
                            {u8'\xc8\xed\xe2\xe0\xe9\xf2 \xef\xee \xf1\xeb\xee\xe2\xe0\xec',  'auto_keyword_invite',  'g'},

                            {u8'\xd0\xcf-\xf7\xe0\xf2',                   'rp_chat',             'g'},
                            {u8'\xc0\xe2\xf2\xee /ad \xef\xee\xe4\xf2\xe2\xe5\xf0\xe6\xe4\xe5\xed\xe8\xe5',  'auto_ad_confirm',     'g'},
                            {u8'\xc0\xe2\xf2\xee /storage \xf1\xe1\xee\xf0',   'auto_storage_collect', 'g'},
                            {u8'\xc0\xe2\xf2\xee \xd0\xcf-\xee\xf0\xf3\xe6\xe8\xe5',        'auto_rp_guns',         'g'},
                            {u8'\xc0\xe2\xf2\xee-\xec\xf3\xf2 \xec\xe0\xf2\xee\xe2',  'auto_mute_insults',   'g'},
                            {u8'\xc0\xe2\xf2\xee-\xec\xf3\xf2 \xf1\xef\xe0\xec\xe0',  'auto_mute_spam',      'g'},
                            {u8'\xc0\xe2\xf2\xee-\xec\xf3\xf2 \xf4\xeb\xf3\xe4\xe0',  'auto_mute_flood',     'g'},

                            {u8'\xcf\xeb\xe0\xe2\xe0\xfe\xf9\xe0\xff \xea\xed\xee\xef\xea\xe0','float_btn_enable',   'g'},
                            {u8'\xc0\xe2\xf2\xee\xf0\xe5\xea\xee\xed\xed\xe5\xea\xf2','__reconnect',         'r'},
                        }

                        local cw3 = imgui.GetWindowContentRegionWidth()
                        local toggle_w = 44*d
                        local min_col_w = 220*d
                        local ncols = math.max(1, math.min(3, math.floor(cw3 / min_col_w)))
                        local col_w3 = cw3 / ncols
                        local per_col = math.ceil(#funcs / ncols)
                        imgui.Columns(ncols, '##funcols', false)
                        for ci = 0, ncols - 1 do imgui.SetColumnWidth(ci, col_w3) end
                        for fi, f in ipairs(funcs) do
                            if fi > 1 and (fi - 1) % per_col == 0 then imgui.NextColumn() end
                            local on
                            if f[3] == 'r' then
                                on = settings.reconnect.enabled
                            else
                                on = settings.general[f[2]]
                            end
                            imgui.AlignTextToFramePadding()
                            imgui.Text(f[1])
                            local this_col_w = imgui.GetColumnWidth() - 16*d
                            imgui.SameLine(this_col_w - toggle_w)
                            if fh_toggle('##fn'..fi, on, toggle_w) then
                                if f[3]=='r' then settings.reconnect.enabled = not settings.reconnect.enabled
                                else settings.general[f[2]] = not settings.general[f[2]] end
                                save_settings()
                            end
                            imgui.Spacing()
                        end
                        imgui.Columns(1)
                        imgui.Separator(); imgui.Spacing()
                        imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xcd\xe0\xf1\xf2\xf0\xee\xe9\xea\xe8'); imgui.Separator()
                        local lbl_w = 160*d
                        local sld_w = imgui.GetWindowContentRegionWidth() - lbl_w - 8*d
                        if settings.general.auto_ad_confirm then
                            imgui.TextDisabled(u8' \xd1\xf2\xe0\xed\xf6\xe8\xff /ad:'); imgui.SameLine(lbl_w)
                            local st_names = {u8'Los Santos##adst', u8'Las Venturas##adst', u8'San Fierro##adst'}
                            local st_idx = settings.general.auto_ad_station_idx or 2
                            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15,0.25,0.45,1))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.2,0.35,0.6,1))
                            if imgui.SmallButton(st_names[st_idx + 1]) then
                                settings.general.auto_ad_station_idx = (st_idx + 1) % 3; save_settings()
                            end
                            imgui.SameLine(0, 16*d)
                            local ad_type_lbl = (settings.general.auto_ad_type or 0) == 0 and u8'\xce\xe1\xfb\xf7\xed\xee\xe5##adtype' or u8'VIP##adtype'
                            if imgui.SmallButton(ad_type_lbl) then
                                settings.general.auto_ad_type = (settings.general.auto_ad_type or 0) == 0 and 1 or 0; save_settings()
                            end
                            imgui.PopStyleColor(2)
                        end
                        if settings.general.auto_mute_insults then
                            imgui.TextDisabled(u8' \xc2\xf0\xe5\xec\xff \xec\xf3\xf2\xe0 \xec\xe0\xf2\xee\xe2 (\xec\xe8\xed):'); imgui.SameLine(lbl_w); imgui.PushItemWidth(sld_w)
                            if imgui.SliderInt('##amtime_insults', sl.auto_mute_time, 1, 300) then settings.general.auto_mute_insults_time=sl.auto_mute_time[0]; save_settings() end
                            imgui.PopItemWidth()
                        end
                        if settings.general.auto_mute_spam then
                            imgui.TextDisabled(u8' \xc2\xf0\xe5\xec\xff \xec\xf3\xf2\xe0 \xf1\xef\xe0\xec\xe0 (\xec\xe8\xed):'); imgui.SameLine(lbl_w); imgui.PushItemWidth(sld_w)
                            if imgui.SliderInt('##amtime_spam', sl.auto_mute_spam_time, 1, 300) then settings.general.auto_mute_spam_time=sl.auto_mute_spam_time[0]; save_settings() end
                            imgui.PopItemWidth()
                        end
                        if settings.general.auto_mute_flood then
                            imgui.TextDisabled(u8' \xc2\xf0\xe5\xec\xff \xec\xf3\xf2\xe0 \xf4\xeb\xf3\xe4\xe0 (\xec\xe8\xed):'); imgui.SameLine(lbl_w); imgui.PushItemWidth(sld_w)
                            if imgui.SliderInt('##amtime_flood', sl.auto_mute_flood_time, 1, 300) then settings.general.auto_mute_flood_time=sl.auto_mute_flood_time[0]; save_settings() end
                            imgui.PopItemWidth()
                            imgui.TextDisabled(u8' \xd4\xeb\xf3\xe4: \xf1\xee\xee\xe1\xf9\xe5\xed\xe8\xe9:'); imgui.SameLine(lbl_w); imgui.PushItemWidth(sld_w)
                            if not sl.flood_msg_count then sl.flood_msg_count = imgui.new.int(settings.general.flood_msg_count or 5) end
                            if imgui.SliderInt('##flood_msg', sl.flood_msg_count, 2, 20) then settings.general.flood_msg_count=sl.flood_msg_count[0]; save_settings() end
                            imgui.PopItemWidth()
                            imgui.TextDisabled(u8' \xd4\xeb\xf3\xe4: \xe7\xe0 \xf1\xe5\xea\xf3\xed\xe4:'); imgui.SameLine(lbl_w); imgui.PushItemWidth(sld_w)
                            if not sl.flood_interval then sl.flood_interval = imgui.new.int(settings.general.flood_interval or 15) end
                            if imgui.SliderInt('##flood_sec', sl.flood_interval, 3, 60) then settings.general.flood_interval=sl.flood_interval[0]; save_settings() end
                            imgui.PopItemWidth()
                            imgui.TextDisabled(safe_u8('  \xec\xf3\xf2 \xe5\xf1\xeb\xe8 ' .. (settings.general.flood_msg_count or 5) .. '+ \xf1\xee\xee\xe1\xf9\xe5\xed\xe8\xe9 \xe7\xe0 ' .. (settings.general.flood_interval or 15) .. ' \xf1\xe5\xea'))
                        end
                        imgui.TextDisabled(u8' \xd0\xe0\xe4\xe8\xf3\xf1 \xe8\xed\xe2\xe0\xe9\xf2\xe0:'); imgui.SameLine(lbl_w); imgui.PushItemWidth(sld_w)
                        if imgui.SliderFloat('##invite_r', sl.invite_radius, 2, 20) then settings.general.auto_invite_radius=sl.invite_radius[0]; save_settings() end
                        imgui.PopItemWidth()
                        imgui.TextDisabled(u8' \xc7\xe0\xe4\xe5\xf0\xe6\xea\xe0 \xe8\xed\xe2\xe0\xe9\xf2\xe0:'); imgui.SameLine(lbl_w); imgui.PushItemWidth(sld_w)
                        if imgui.SliderFloat('##invite_d', sl.invite_delay, 1, 15) then settings.general.auto_invite_delay=sl.invite_delay[0]; save_settings() end
                        imgui.PopItemWidth()
                        imgui.TextDisabled(u8' \xd0\xe0\xe4\xe8\xf3\xf1 \xea\xed\xee\xef\xea\xe8:'); imgui.SameLine(lbl_w); imgui.PushItemWidth(sld_w)
                        if imgui.SliderFloat('##float_r', sl.float_radius, 5, 50) then settings.general.float_btn_radius=sl.float_radius[0]; save_settings() end
                        imgui.PopItemWidth()
                        imgui.EndChild()
                    end
                    imgui.EndTabItem()
                end
                imgui.EndTabBar()
            end
end

local function fh_render_tab2()
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
            if imgui.BeginTabBar('##cmdtabs') then
            if imgui.BeginTabItem(fa_icon.TERMINAL .. '  ' .. u8'\xca\xee\xec\xe0\xed\xe4\xfb') then

            local _line_h = imgui.GetFrameHeightWithSpacing()
            local _sep_h = imgui.GetStyle().ItemSpacing.y * 2 + 1
            local qa_h = imgui.GetTextLineHeightWithSpacing() + _sep_h + _line_h * 5 + imgui.GetStyle().WindowPadding.y * 2
            if imgui.BeginChild('##quick_actions', imgui.ImVec2(-1, qa_h), true) then
                fh_touch_scroll('##quick_actions')
                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xc1\xfb\xf1\xf2\xf0\xfb\xe5 \xe4\xe5\xe9\xf1\xf2\xe2\xe8\xff'); imgui.Separator()

                imgui.PushItemWidth(50*d); imgui.InputTextWithHint('##inv_id', 'ID', qa.invite_id, 32); imgui.PopItemWidth()
                imgui.SameLine(0,4)
                if imgui.Button(fa_icon.PAPER_PLANE .. '  ' .. u8'\xd0\xcf \xc8\xed\xe2\xe0\xe9\xf2 ', imgui.ImVec2(120*d, 0)) then
                    local id = ffi.string(qa.invite_id)
                    if id ~= '' then send_lines(settings.rp_invite.text, settings.rp_invite.waiting, tonumber(id)) end
                end
                imgui.SameLine(0,6); imgui.TextDisabled(u8'/faminvite ID \xcf\xee \xd0\xcf')

                imgui.PushItemWidth(50*d); imgui.InputTextWithHint('##mute_id2', 'ID', qa.mute_id, 32); imgui.PopItemWidth()
                imgui.SameLine(0,4)
                imgui.PushItemWidth(55*d); imgui.InputTextWithHint(u8'##mute2', u8'\xcc\xe8\xed.', qa.mute_time, 32); imgui.PopItemWidth()
                imgui.SameLine(0,4)
                local mute_btns_w = 85*d*2 + 2*d
                local mute_reason_w = math.max(80*d, imgui.GetWindowContentRegionWidth() - imgui.GetCursorPosX() - mute_btns_w - 8*d)
                imgui.PushItemWidth(mute_reason_w); imgui.InputTextWithHint(u8'##muter', u8'\xcf\xf0\xe8\xf7\xe8\xed\xe0', qa.mute_reason, 128); imgui.PopItemWidth()
                imgui.SameLine(0,4)
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.6,0.1,0.1,1))
                if imgui.Button(fa_icon.MICROPHONE_SLASH .. '  ' .. u8'\xcc\xf3\xf2##m2', imgui.ImVec2(85*d, 0)) then
                    local id=ffi.string(qa.mute_id); local t=ffi.string(qa.mute_time); local r=u8:decode(ffi.string(qa.mute_reason))
                    if id~='' and t~='' then sampSendChat(string.format('/fammute %s %s %s', id, t, r)) end
                end
                imgui.PopStyleColor()
                imgui.SameLine(0,2)
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.1,0.45,0.1,1))
                if imgui.Button(fa_icon.MICROPHONE .. '  ' .. u8'-\xcc\xf3\xf2##um2', imgui.ImVec2(85*d, 0)) then
                    local id=ffi.string(qa.mute_id)
                    if id~='' then sampSendChat(string.format('/famunmute %s', id)) end
                end
                imgui.PopStyleColor()

                imgui.PushItemWidth(50*d); imgui.InputTextWithHint('##rank_id2', 'ID', qa.rank_id, 32); imgui.PopItemWidth()
                imgui.SameLine(0,4)
                if imgui.Button(fa_icon.MINUS .. '##rkd2', imgui.ImVec2(22*d,0)) then local v=tonumber(ffi.string(qa.rank_val)) or 1; ffi.copy(qa.rank_val, tostring(math.max(1,v-1))) end
                imgui.SameLine(0,2)
                imgui.PushItemWidth(32*d); imgui.InputText('##rkv2', qa.rank_val, 32); imgui.PopItemWidth()
                imgui.SameLine(0,2)
                if imgui.Button(fa_icon.CIRCLE_PLUS .. '##rku2', imgui.ImVec2(22*d,0)) then local v=tonumber(ffi.string(qa.rank_val)) or 0; ffi.copy(qa.rank_val, tostring(math.min(10,v+1))) end
                imgui.SameLine(0,4)
                if imgui.Button(fa_icon.CROWN .. '  ' .. u8'\xd0\xe0\xed\xe3##rkset2', imgui.ImVec2(85*d, 0)) then
                    local id=ffi.string(qa.rank_id); local rank=ffi.string(qa.rank_val)
                    if id~='' and rank~='' then
                    if id~='' and rank~='' then
                        sampSendChat(string.format('/setfrank %s %s', id, rank))

                        local rank_nick = nil

                        if sampIsPlayerConnected(tonumber(id)) then
                            rank_nick = sampGetPlayerNickname(tonumber(id))
                        end
                        if rank_nick then
                            for _, t in ipairs(settings.auto_tags) do
                                if tostring(t.rank) == tostring(rank) and t.tag ~= '' then
                                    lua_thread.create(function()
                                        wait(600)
                                        sampSendChat('/famtag ' .. rank_nick .. ' ' .. t.tag)
                                        sampAddChatMessage('[Family Helper] {aaffaa}/famtag ' .. rank_nick .. ' ' .. t.tag, 0xFFA500)
                                    end)
                                    break
                                end
                            end
                        end
                    end
                    end
                end

                imgui.PushItemWidth(50*d); imgui.InputTextWithHint('##kick_id2', 'ID', qa.kick_id, 32); imgui.PopItemWidth()
                imgui.SameLine(0,4)
                local kick_btn_w = 85*d
                local kick_reason_w = math.max(80*d, imgui.GetWindowContentRegionWidth() - imgui.GetCursorPosX() - kick_btn_w - 8*d)
                imgui.PushItemWidth(kick_reason_w); imgui.InputTextWithHint(u8'##kickr', u8'\xcf\xf0\xe8\xf7\xe8\xed\xe0', qa.kick_reason, 128); imgui.PopItemWidth()
                imgui.SameLine(0,4)
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.55,0.1,0.1,1))
                if imgui.Button(fa_icon.USER_XMARK .. '  ' .. u8'\xca\xe8\xea##k2', imgui.ImVec2(kick_btn_w, 0)) then
                    local id=ffi.string(qa.kick_id); local r=u8:decode(ffi.string(qa.kick_reason))
                    if id~='' then sampSendChat(string.format('/famuninvite %s %s', id, r)) end
                end
                imgui.PopStyleColor()

                local offk_btn_w = 125*d
                local offk_field_w = math.max(80*d, imgui.GetWindowContentRegionWidth() - offk_btn_w - 8*d)
                imgui.PushItemWidth(offk_field_w)
                imgui.InputTextWithHint(u8'##offkick_n', 'Nick_Name', qa.offkick_nick, 64)
                imgui.PopItemWidth()
                imgui.SameLine(0,4)
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.55,0.1,0.1,1))
                if imgui.Button(fa_icon.USER_SLASH .. '  ' .. u8'\xca\xe8\xea \xee\xf4\xf4\xeb\xe0\xe9\xed##offk', imgui.ImVec2(offk_btn_w, 0)) then
                    local nick = u8:decode(ffi.string(qa.offkick_nick)):match('^%s*(.-)%s*$')
                    if nick ~= '' then sampSendChat('/famoffkick ' .. nick) end
                end
                imgui.PopStyleColor()

                imgui.EndChild()
            end

            local cmds_h = imgui.GetContentRegionAvail().y - imgui.GetFrameHeightWithSpacing()
            if imgui.BeginChild('##cmds', imgui.ImVec2(-1, cmds_h), true) then
                fh_touch_scroll('##cmds')
                local cw = imgui.GetWindowContentRegionWidth()

                local _spx = imgui.GetStyle().ItemSpacing.x
                local _btn_toggle_w = 28*d
                local _btn_edit_w = imgui.CalcTextSize(fa_icon.PEN_TO_SQUARE).x + imgui.GetStyle().FramePadding.x * 2
                local _btn_x_w = imgui.CalcTextSize(fa_icon.TRASH).x + imgui.GetStyle().FramePadding.x * 2
                local col_btns = _btn_toggle_w + _btn_edit_w + _btn_x_w + _spx * 2 + _spx * 0.5 + 4*d
                local col_cmd = 115*d; local col_desc = math.max(80*d, cw - col_cmd - col_btns)
                imgui.Columns(4, '##cmdhdr', false)
                imgui.SetColumnWidth(0, 18*d)
                imgui.SetColumnWidth(1, col_cmd)
                imgui.SetColumnWidth(2, col_desc)
                imgui.SetColumnWidth(3, col_btns)

                imgui.NextColumn(); imgui.TextDisabled(u8'\xca\xee\xec\xe0\xed\xe4\xe0')
                imgui.NextColumn(); imgui.TextDisabled(u8'\xce\xef\xe8\xf1\xe0\xed\xe8\xe5')
                imgui.NextColumn(); imgui.TextDisabled(u8'\xc4\xe5\xe9\xf1\xf2\xe2\xe8\xff')
                imgui.NextColumn(); imgui.Columns(1); imgui.Separator()

                for _, c in ipairs(settings.commands) do
                    if not c.deleted then
                        imgui.Columns(4, '##cmdrow_'..(c.cmd or''), false)
                        imgui.SetColumnWidth(0, 18*d)
                        imgui.SetColumnWidth(1, col_cmd)
                        imgui.SetColumnWidth(2, col_desc)
                        imgui.SetColumnWidth(3, col_btns)

                        if c.enable then
                            imgui.TextColored(imgui.ImVec4(0.2,0.85,0.2,1), u8'\x95')
                        else
                            imgui.TextColored(imgui.ImVec4(0.85,0.2,0.2,1), u8'\x95')
                        end
                        imgui.NextColumn()
                        local cn = '/'..safe_u8(c.cmd)
                        if c.enable then imgui.Text(cn) else imgui.TextDisabled(cn) end
                        imgui.NextColumn()
                        local cd = safe_u8(c.description)
                        if c.enable then imgui.Text(cd) else imgui.TextDisabled(cd) end
                        imgui.NextColumn()

                        do
                            local _c_on = c.enable
                            local _toggle_h = 16*d
                            if fh_toggle('##t'..(c.cmd or''), _c_on, _btn_toggle_w, _toggle_h) then
                                if _c_on then
                                    c.enable=false; save_settings(); pcall(sampUnregisterChatCommand, c.cmd)
                                else
                                    c.enable=true; save_settings(); if(c.cmd or'')~='' then reg_cmd(c.cmd,c.arg,c.text,tonumber(c.waiting)) end
                                end
                            end
                        end
                        imgui.SameLine()
                        if imgui.SmallButton(fa_icon.PEN_TO_SQUARE .. '##e'..(c.cmd or'')) then
                            change_description=c.description or''; input_description=imgui.new.char[256](safe_u8(change_description))
                            change_arg=c.arg or''; ComboTags[0]=({['']=0,['{arg}']=1,['{arg_id}']=2,['{arg_id} {arg2}']=3})[change_arg] or 0
                            change_cmd=c.cmd or''; input_cmd=imgui.new.char[256](safe_u8(c.cmd))
                            change_text=(c.text or''):gsub('&','\n'); input_text=imgui.new.char[8192](safe_u8(change_text))
                            change_waiting=c.waiting or'1.500'; waiting_slider=imgui.new.float(tonumber(change_waiting) or 1.5)
                            BinderWindow[0]=true
                        end
                        imgui.SameLine()
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.4,0.1,0.1,1))
                        if imgui.SmallButton(fa_icon.TRASH .. '##d'..(c.cmd or'')) then c.deleted=true; c.enable=false; pcall(sampUnregisterChatCommand, c.cmd); save_settings() end
                        imgui.PopStyleColor()
                        imgui.NextColumn(); imgui.Columns(1); imgui.Separator()
                    end
                end
                imgui.EndChild()
            end
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(ar*0.3,ag*0.3,ab*0.3,1))
            if imgui.Button(fa_icon.CIRCLE_PLUS .. '  ' .. u8'\xca\xee\xec\xe0\xed\xe4\xe0', imgui.ImVec2(-1, 0)) then
                local nc={cmd='',description='\xcd\xee\xe2\xe0\xff',text='',arg='',enable=true,waiting='1.500',deleted=false}
                table.insert(settings.commands, nc)
                change_description=nc.description; input_description=imgui.new.char[256](u8(nc.description))
                change_arg=''; ComboTags[0]=0; change_cmd=''; input_cmd=imgui.new.char[256]('')
                change_text=''; input_text=imgui.new.char[8192](''); change_waiting='1.500'; waiting_slider=imgui.new.float(1.5)
                BinderWindow[0]=true
            end
            imgui.PopStyleColor()
            imgui.EndTabItem()
            end
            if imgui.BeginTabItem(fa_icon.USER_PLUS .. '  ' .. u8'\xc2\xe5\xf0\xe1\xee\xe2\xea\xe0') then
            local ar3 = settings.interface.accent_r or 1
            local ag3 = settings.interface.accent_g or .65
            if imgui.BeginTabBar('##verbtabs') then
                if imgui.BeginTabItem(fa_icon.LIST_OL .. '  ' .. u8'\xd8\xe0\xe3\xe8') then

                    if imgui.BeginChild('##verb_steps', imgui.ImVec2(-1, 0), false) then
                        fh_touch_scroll('##verb_steps')
                        imgui.TextColored(imgui.ImVec4(ar3,ag3,0,1), u8' \xd8\xe0\xe3\xe8 \xe2\xe5\xf0\xe1\xee\xe2\xea\xe8')
                        imgui.SameLine()
                        imgui.TextDisabled(u8'  {get_ru_nick} {arg_id} {family_name} {my_name}  | /fi [ID]')
                        imgui.Separator()
                        local inters_h = imgui.GetContentRegionAvail().y - imgui.GetFrameHeightWithSpacing()
                        if imgui.BeginChild('##inters', imgui.ImVec2(-1, inters_h), true) then
                            fh_touch_scroll('##inters')
                            for i, inter in ipairs(settings.interactions) do
                                imgui.Columns(2, '##intcol'..i, false)
                                imgui.SetColumnWidth(0, 555*d)
                                imgui.TextColored(imgui.ImVec4(0.2,0.85,0.2,1), u8'\x95')
                                imgui.SameLine(0, 4)
                                imgui.Text(safe_u8(' ' .. (inter.name or '')))
                                imgui.NextColumn()
                                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15,0.35,0.55,1))
                                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.2,0.45,0.7,1))
                                if imgui.SmallButton(fa_icon.PEN_TO_SQUARE .. u8('##ie'..i)) then interact_edit_index=i; InteractEditWindow[0]=true end
                                imgui.PopStyleColor(2)
                                imgui.SameLine()
                                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.45,0.1,0.1,1))
                                if imgui.SmallButton(fa_icon.TRASH .. '##id'..i) then table.remove(settings.interactions, i); save_settings() end
                                imgui.PopStyleColor()
                                imgui.Columns(1)
                                imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(0.3,0.2,0.0,0.6))
                                imgui.Separator()
                                imgui.PopStyleColor()
                            end
                            imgui.EndChild()
                        end
                        local add_bw = (imgui.GetWindowContentRegionWidth() - 4*d) / 2
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.1,0.35,0.1,1))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.15,0.5,0.15,1))
                        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.2,0.6,0.2,1))
                        if imgui.Button(fa_icon.CIRCLE_PLUS .. '  ' .. u8'\xc4\xee\xe1\xe0\xe2\xe8\xf2\xfc \xf8\xe0\xe3##addstp', imgui.ImVec2(add_bw, 0)) then
                            table.insert(settings.interactions, {name='\xcd\xee\xe2\xfb\xe9', lines={'\xd2\xe5\xea\xf1\xf2'}, waiting=1.5}); save_settings()
                            interact_edit_index=#settings.interactions; InteractEditWindow[0]=true
                        end
                        imgui.PopStyleColor(3)
                        imgui.SameLine()
                        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.5,0.1,0.1,1))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.7,0.2,0.2,1))
                        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.9,0.3,0.3,1))
                        if imgui.Button(fa_icon.ROTATE_LEFT .. u8'  \xd1\xe1\xf0\xee\xf1\xe8\xf2\xfc \xed\xe0 \xf1\xf2\xe0\xed\xe4\xe0\xf0\xf2\xed\xfb\xe5##rststp', imgui.ImVec2(add_bw, 0)) then
                    settings.interactions = {
                        { name = '1. \xcf\xf0\xe8\xe2\xe5\xf2\xf1\xf2\xe2\xe8\xe5', lines = {
                            '/me \xef\xee\xe4\xf5\xee\xe4\xe8\xf2 \xea {get_ru_nick} \xe8 \xef\xf0\xe8\xe2\xe5\xf2\xeb\xe8\xe2\xee \xec\xe0\xf8\xe5\xf2 \xf0\xf3\xea\xee\xe9',
                            '\xcf\xf0\xe8\xe2\xe5\xf2, {get_ru_nick}! \xcc\xee\xe3\xf3 \xe7\xe0\xe4\xe0\xf2\xfc \xf2\xe5\xe1\xe5 \xef\xe0\xf0\xf3 \xe2\xee\xef\xf0\xee\xf1\xee\xe2?',
                        }, waiting = 2.5 },
                        { name = '2. \xcf\xf0\xe5\xe4\xeb\xee\xe6\xe5\xed\xe8\xe5', lines = {
                            '\xd1\xec\xee\xf2\xf0\xfe, \xf2\xfb \xef\xee\xea\xe0 \xe1\xe5\xe7 \xf1\xe5\xec\xfc\xe8 - \xec\xee\xe3\xf3 \xf0\xe0\xf1\xf1\xea\xe0\xe7\xe0\xf2\xfc \xef\xf0\xee {family_name}, \xe5\xf1\xeb\xe8 \xe8\xed\xf2\xe5\xf0\xe5\xf1\xed\xee.',
                            '{pause}',
                            '\xd0\xe0\xf1\xf1\xea\xe0\xe6\xf3 \xef\xee \xf4\xe0\xea\xf2\xe0\xec: \xf7\xf2\xee \xe4\xe0\xb8\xec, \xea\xe0\xea\xe8\xe5 \xef\xeb\xfe\xf1\xfb, \xe8 \xf7\xf2\xee \xed\xf3\xe6\xed\xee \xee\xf2 \xf2\xe5\xe1\xff - \xe1\xe5\xe7 \xe2\xee\xe4\xfb.',
                        }, waiting = 2.5 },
                        { name = '3. \xc0\xe2\xf2\xee\xef\xe0\xf0\xea', lines = {
                            '\xc2 {family_name} \xf1\xe2\xee\xe9 \xe0\xe2\xf2\xee\xef\xe0\xf0\xea - \xe1\xe5\xf0\xb8\xf8\xfc \xf2\xe0\xf7\xea\xf3 \xf1 \xf1\xe5\xec\xe5\xe9\xed\xee\xe9 \xef\xe0\xf0\xea\xee\xe2\xea\xe8 \xe2 \xeb\xfe\xe1\xee\xe9 \xec\xee\xec\xe5\xed\xf2, \xed\xe5 \xed\xf3\xe6\xed\xee \xea\xee\xef\xe8\xf2\xfc \xed\xe0 \xef\xe5\xf0\xe2\xf3\xfe \xec\xe0\xf8\xe8\xed\xf3.',
                            '{pause}',
                            '\xcf\xeb\xfe\xf1 \xe2 \xe3\xe0\xf0\xe0\xe6\xe5 \xeb\xe8\xec\xe8\xf2\xea\xe8 - \xed\xe5 \xef\xe5\xf0\xe5\xe2\xee\xf0\xe0\xf7\xe8\xe2\xe0\xfe\xf2\xf1\xff, \xed\xe5 \xeb\xee\xec\xe0\xfe\xf2\xf1\xff, \xe8 \xf1\xf2\xee\xff\xf2 \xef\xee 10 \xec\xe8\xeb\xeb\xe8\xe0\xf0\xe4\xee\xe2 - \xf2\xe0\xea\xee\xe5 \xed\xe5 \xe2 \xea\xe0\xe6\xe4\xee\xe9 \xf1\xe5\xec\xfc\xe5 \xf3\xe2\xe8\xe4\xe8\xf8\xfc.',
                        }, waiting = 2.5 },
                        { name = '4. \xc6\xca / \xea\xe2\xe0\xf0\xf2\xe8\xf0\xe0', lines = {
                            '\xc5\xf9\xb8 \xf3 \xed\xe0\xf1 \xf1\xe5\xec\xe5\xe9\xed\xe0\xff \xea\xe2\xe0\xf0\xf2\xe8\xf0\xe0 \xe2 Arizona Tower - \xfd\xf2\xee \xed\xe5 \xef\xf0\xee\xf1\xf2\xee \xea\xf0\xfb\xf8\xe0 \xed\xe0\xe4 \xe3\xee\xeb\xee\xe2\xee\xe9.',
                            '{pause}',
                            '\xce\xf2\xf2\xf3\xe4\xe0 \xe8\xe4\xb8\xf2 \xe2\xf1\xff \xe4\xe2\xe8\xe6\xf3\xf5\xe0: \xe2\xee\xe9\xed\xfb \xe7\xe0 \xf2\xe5\xf0\xf0\xe8\xf2\xee\xf0\xe8\xe8, \xe4\xee\xf5\xee\xe4 \xf1 \xe7\xe0\xf5\xe2\xe0\xf7\xe5\xed\xed\xfb\xf5 \xf2\xee\xf7\xe5\xea, \xf1\xe2\xee\xe8 \xf4\xf3\xf0\xe3\xee\xed\xfb. \xc0 \xe5\xf9\xb8 \xc6\xca \xef\xf0\xff\xec\xee \xf0\xff\xe4\xee\xec \xf1 \xd6\xe5\xed\xf2\xf0\xe0\xeb\xfc\xed\xfb\xec \xf0\xfb\xed\xea\xee\xec - \xee\xf7\xe5\xed\xfc \xf3\xe4\xee\xe1\xed\xee, \xe5\xf1\xeb\xe8 \xeb\xfe\xe1\xe8\xf8\xfc \xf2\xee\xf0\xe3\xee\xe2\xe0\xf2\xfc.',
                        }, waiting = 2.5 },
                        { name = '5. \xcf\xf0\xee\xea\xe0\xf7\xea\xe0 \xed\xe0 \xf0\xe0\xe1\xee\xf2\xe0\xf5', lines = {
                            '\xd3 \xed\xe0\xf1 \xe5\xf9\xb8 \xef\xf0\xee\xea\xe0\xf7\xe0\xed\xfb \xe7\xe0\xf0\xef\xeb\xe0\xf2\xfb \xed\xe0 \xf0\xe0\xe1\xee\xf2\xe0\xf5 - \xe4\xe0\xeb\xfc\xed\xee\xe1\xee\xe9\xf9\xe8\xea, \xef\xe8\xeb\xee\xf2, \xef\xee\xe6\xe0\xf0\xed\xfb\xe9 \xe8 \xe4\xf0\xf3\xe3\xe8\xe5, \xeb\xe8\xe4\xe5\xf0 \xe2\xea\xeb\xe0\xe4\xfb\xe2\xe0\xe5\xf2\xf1\xff \xe2 \xfd\xf2\xee \xee\xf2\xe4\xe5\xeb\xfc\xed\xee.',
                            '{pause}',
                            '\xd2\xee \xe5\xf1\xf2\xfc \xf1 \xee\xe4\xed\xee\xe9 \xe8 \xf2\xee\xe9 \xe6\xe5 \xf0\xe0\xe1\xee\xf2\xfb \xe2 \xed\xe0\xf8\xe5\xe9 \xf1\xe5\xec\xfc\xe5 \xe7\xe0\xf0\xe0\xe1\xee\xf2\xe0\xe5\xf8\xfc \xe1\xee\xeb\xfc\xf8\xe5, \xf7\xe5\xec \xf1\xe0\xec \xef\xee \xf1\xe5\xe1\xe5.',
                        }, waiting = 2.5 },
                        { name = '6. \xcf\xeb\xfe\xf1\xfb (\xe3\xe0\xeb\xee\xf7\xea\xe0/\xe1\xf0\xe5\xed\xe4/\xf4\xeb\xe0\xe3)', lines = {
                            '\xd3 \xed\xe0\xf1 \xe2\xf1\xb8 \xef\xf0\xee\xea\xe0\xf7\xe0\xed\xee - \xe3\xe0\xeb\xee\xf7\xea\xe0, \xe1\xf0\xe5\xed\xe4 \xe8 \xf4\xeb\xe0\xe3, \xf1\xe5\xec\xfc\xff \xee\xf4\xe8\xf6\xe8\xe0\xeb\xfc\xed\xee \xed\xe0 \xf1\xe5\xf0\xfc\xb8\xe7\xed\xee\xec \xf3\xf0\xee\xe2\xed\xe5.',
                            '{pause}',
                            '\xc8\xe7 \xef\xee\xeb\xe5\xe7\xed\xee\xe3\xee \xeb\xe8\xf7\xed\xee \xf2\xe5\xe1\xe5: \xf4\xeb\xe0\xe3 \xe4\xe0\xb8\xf2 +7% \xea \xe7\xe0\xf0\xef\xeb\xe0\xf2\xe5 \xe2 \xee\xf0\xe3\xe0\xed\xe8\xe7\xe0\xf6\xe8\xe8 \xe8 \xe1\xee\xed\xf3\xf1\xfb \xed\xe0 \xf0\xe0\xe1\xee\xf2\xe0\xf5, \xe3\xe0\xeb\xee\xf7\xea\xe0 \xe7\xe0\xf9\xe8\xf9\xe0\xe5\xf2 \xee\xf2 \xea\xee\xef\xe8\xf0\xee\xe2\xe0\xed\xe8\xff \xe8 \xf1\xed\xe8\xe6\xe0\xe5\xf2 \xef\xee\xf2\xe5\xf0\xe8 \xf0\xe5\xef\xf3\xf2\xe0\xf6\xe8\xe8 \xef\xf0\xe8 \xed\xe0\xea\xe0\xe7\xe0\xed\xe8\xff\xf5, \xe0 \xe1\xf0\xe5\xed\xe4 \xe4\xe0\xb8\xf2 \xeb\xe8\xf8\xed\xe8\xe9 \xe4\xee\xec \xe8 \xef\xee\xe2\xfb\xf8\xe5\xed\xed\xfb\xe5 \xf8\xe0\xed\xf1\xfb \xed\xe0 \xf0\xf3\xeb\xe5\xf2\xea\xe8.',
                        }, waiting = 2.5 },
                        { name = '7. \xc2\xee\xe7\xf0\xe0\xe6\xe5\xed\xe8\xe5 - \xed\xe5 \xed\xe0\xe4\xee \xec\xed\xe5 \xfd\xf2\xee', lines = {
                            '\xcf\xee\xed\xe8\xec\xe0\xfe, \xe4\xe5\xeb\xee \xf2\xe2\xee\xb8 - \xf2\xee\xeb\xfc\xea\xee \xf3\xf7\xf2\xe8, \xf7\xf2\xee \xef\xee \xf1\xf2\xe0\xf0\xf2\xee\xe2\xfb\xec \xea\xe2\xe5\xf1\xf2\xe0\xec \xe2\xf1\xf2\xf3\xef\xeb\xe5\xed\xe8\xe5 \xe2 \xf1\xe5\xec\xfc\xfe \xe2\xf1\xb8 \xf0\xe0\xe2\xed\xee \xef\xee\xed\xe0\xe4\xee\xe1\xe8\xf2\xf1\xff, \xe1\xe5\xe7 \xfd\xf2\xee\xe3\xee \xe4\xe0\xeb\xfc\xf8\xe5 \xed\xe5 \xef\xf0\xee\xe4\xe2\xe8\xed\xe5\xf8\xfc\xf1\xff.',
                            '{pause}',
                            '\xd2\xe0\xea \xf7\xf2\xee \xf1\xec\xfb\xf1\xeb\xe0 \xf2\xff\xed\xf3\xf2\xfc \xee\xf1\xee\xe1\xee \xed\xe5\xf2 - \xeb\xf3\xf7\xf8\xe5 \xf1\xf0\xe0\xe7\xf3 \xea \xf2\xe5\xec, \xf3 \xea\xee\xe3\xee \xe5\xf1\xf2\xfc \xf7\xe5\xec \xef\xee\xec\xee\xf7\xfc: \xe0\xe2\xf2\xee\xef\xe0\xf0\xea, \xea\xe2\xe0\xf0\xf2\xe8\xf0\xe0, \xef\xf0\xee\xea\xe0\xf7\xe0\xed\xed\xfb\xe5 \xe7\xe0\xf0\xef\xeb\xe0\xf2\xfb. \xce\xe1\xfb\xf7\xed\xee \xef\xee\xf2\xee\xec \xf1\xe0\xec\xe8 \xf1\xe5\xec\xfc\xfe \xe8\xf9\xf3\xf2, \xef\xf0\xee\xf1\xf2\xee \xe2\xf0\xe5\xec\xff \xf2\xe5\xf0\xff\xfe\xf2.',
                        }, waiting = 2.5 },
                        { name = '8. \xc2\xee\xe7\xf0\xe0\xe6\xe5\xed\xe8\xe5 - \xe2\xf1\xf2\xf3\xef\xeb\xfe \xef\xee\xe7\xe6\xe5', lines = {
                            '\xcd\xe5 \xe2\xee\xef\xf0\xee\xf1, \xf1\xef\xe5\xf8\xe8\xf2\xfc \xed\xe5\xea\xf3\xe4\xe0 - \xed\xee \xf1\xec\xfb\xf1\xeb \xf2\xff\xed\xf3\xf2\xfc, \xe5\xf1\xeb\xe8 \xef\xee \xea\xe2\xe5\xf1\xf2\xf3 \xe2\xf1\xb8 \xf0\xe0\xe2\xed\xee \xef\xee\xed\xe0\xe4\xee\xe1\xe8\xf2\xf1\xff?',
                            '{pause}',
                            '\xc7\xe0\xee\xe4\xed\xee \xf1 \xea\xe2\xe5\xf1\xf2\xee\xec \xf1\xf0\xe0\xe7\xf3 \xe7\xe0\xea\xf0\xee\xe5\xf8\xfc \xe8 \xe0\xe2\xf2\xee\xef\xe0\xf0\xea, \xe8 \xea\xe2\xe0\xf0\xf2\xe8\xf0\xf3, \xe8 \xef\xf0\xee\xea\xe0\xf7\xe0\xed\xed\xfb\xe5 \xe7\xe0\xf0\xef\xeb\xe0\xf2\xfb - \xe0 \xed\xe5 \xe1\xf3\xe4\xe5\xf8\xfc \xef\xee\xf2\xee\xec \xe8\xf1\xea\xe0\xf2\xfc \xfd\xf2\xee \xee\xf2\xe4\xe5\xeb\xfc\xed\xee.',
                        }, waiting = 2.5 },
                        { name = '9. \xc2\xee\xe7\xf0\xe0\xe6\xe5\xed\xe8\xe5 - \xf7\xf2\xee \xe2\xee\xee\xe1\xf9\xe5 \xe4\xe5\xeb\xe0\xf2\xfc \xe2 \xf1\xe5\xec\xfc\xe5', lines = {
                            '\xcd\xe8\xf7\xe5\xe3\xee \xf1\xe2\xe5\xf0\xf5\xfa\xe5\xf1\xf2\xe5\xf1\xf2\xe2\xe5\xed\xed\xee\xe3\xee - \xee\xe1\xfb\xf7\xed\xe0\xff \xe8\xe3\xf0\xe0, \xf2\xee\xeb\xfc\xea\xee \xf1 \xe1\xee\xed\xf3\xf1\xe0\xec\xe8 \xe8 \xef\xee\xe4\xe4\xe5\xf0\xe6\xea\xee\xe9 \xf0\xff\xe4\xee\xec.',
                            '{pause}',
                            '\xc0\xea\xf2\xe8\xe2\xed\xee\xf1\xf2\xfc \xef\xee \xe6\xe5\xeb\xe0\xed\xe8\xfe: \xea\xf2\xee-\xf2\xee \xf4\xe0\xf0\xec\xe8\xf2 \xf1 \xf1\xe5\xec\xfc\xb8\xe9, \xea\xf2\xee-\xf2\xee \xef\xf0\xee\xf1\xf2\xee \xf7\xe8\xf1\xeb\xe8\xf2\xf1\xff \xe8 \xef\xee\xeb\xfc\xe7\xf3\xe5\xf2\xf1\xff \xe0\xe2\xf2\xee\xef\xe0\xf0\xea\xee\xec \xf1 \xea\xe2\xe0\xf0\xf2\xe8\xf0\xee\xe9 - \xed\xe8\xea\xf2\xee \xed\xe8\xea\xee\xe3\xee \xed\xe5 \xe7\xe0\xf1\xf2\xe0\xe2\xeb\xff\xe5\xf2.',
                        }, waiting = 2.5 },
                        { name = '10. \xd3\xf1\xeb\xee\xe2\xe8\xff', lines = {
                            '\xd3\xf1\xeb\xee\xe2\xe8\xff \xef\xf0\xee\xf1\xf2\xfb\xe5 - \xe1\xf3\xe4\xfc \xed\xe0 \xf1\xe2\xff\xe7\xe8, \xef\xee\xec\xee\xe3\xe0\xe9 \xf1\xe2\xee\xe8\xec \xe8 \xf1\xee\xe1\xeb\xfe\xe4\xe0\xe9 \xef\xf0\xe0\xe2\xe8\xeb\xe0 \xf1\xe5\xec\xfc\xe8.',
                            '\xcb\xe8\xe4\xe5\xf0 - {my_name}, \xe2\xf1\xe5\xe3\xe4\xe0 \xed\xe0 \xf1\xe2\xff\xe7\xe8 \xe8 \xef\xee\xec\xee\xe6\xe5\xf2 \xee\xf1\xe2\xee\xe8\xf2\xfc\xf1\xff \xf1 \xef\xe5\xf0\xe2\xee\xe3\xee \xe4\xed\xff.',
                        }, waiting = 2.5 },
                        { name = '11. \xc8\xed\xe2\xe0\xe9\xf2 (\xd0\xcf)', lines = {
                            '/me \xe4\xee\xf1\xf2\xe0\xb8\xf2 \xf2\xe5\xeb\xe5\xf4\xee\xed \xe8 \xee\xf2\xea\xf0\xfb\xe2\xe0\xe5\xf2 \xef\xf0\xe8\xeb\xee\xe6\xe5\xed\xe8\xe5 \xf1\xe5\xec\xfc\xe8',
                            '/do \xcd\xe0 \xfd\xea\xf0\xe0\xed\xe5 \xef\xee\xff\xe2\xeb\xff\xe5\xf2\xf1\xff \xf4\xee\xf0\xec\xe0 \xef\xf0\xe8\xe3\xeb\xe0\xf8\xe5\xed\xe8\xff \xe2 \xf1\xe5\xec\xfc\xfe.',
                            '\xce\xf2\xef\xf0\xe0\xe2\xeb\xff\xfe \xf2\xe5\xe1\xe5 \xef\xf0\xe8\xe3\xeb\xe0\xf8\xe5\xed\xe8\xe5 - \xe6\xe4\xe8 \xe2 \xea\xee\xec\xe0\xed\xe4\xe5.',
                            '/faminvite {arg_id}',
                            '/b \xcf\xf0\xe8\xe3\xeb\xe0\xf8\xe5\xed\xe8\xe5 \xee\xf2\xef\xf0\xe0\xe2\xeb\xe5\xed\xee, \xef\xf0\xe8\xec\xe8 \xea\xee\xec\xe0\xed\xe4\xee\xe9 /offer.',
                        }, waiting = 2.0 },
                        { name = '12. \xcd\xe0\xef\xee\xec\xed\xe8\xf2\xfc /offer', lines = {
                            '/b \xcf\xf0\xe8\xe3\xeb\xe0\xf8\xe5\xed\xe8\xe5 \xf3\xe6\xe5 \xf3 \xf2\xe5\xe1\xff, \xef\xf0\xe8\xec\xe8 \xea\xee\xec\xe0\xed\xe4\xee\xe9 /offer.',
                        }, waiting = 2.0 },
                        { name = '13. \xcf\xf0\xee\xf9\xe0\xed\xe8\xe5 (\xef\xf0\xe8\xed\xff\xeb)', lines = {
                            '/me \xf2\xe5\xef\xeb\xee \xf3\xeb\xfb\xe1\xe0\xe5\xf2\xf1\xff \xed\xee\xe2\xee\xec\xf3 \xf3\xf7\xe0\xf1\xf2\xed\xe8\xea\xf3 \xf1\xe5\xec\xfc\xe8',
                            '\xce\xf2\xeb\xe8\xf7\xed\xee, \xe4\xee\xe1\xf0\xee \xef\xee\xe6\xe0\xeb\xee\xe2\xe0\xf2\xfc \xe2 {family_name}! \xc5\xf1\xeb\xe8 \xf7\xf2\xee-\xf2\xee \xe1\xf3\xe4\xe5\xf2 \xed\xe5\xef\xee\xed\xff\xf2\xed\xee - \xef\xe8\xf8\xe8 \xe2 \xf1\xe5\xec\xe5\xe9\xed\xfb\xe9 \xf7\xe0\xf2, \xef\xee\xe4\xf1\xea\xe0\xe6\xe5\xec \xe8 \xef\xee\xec\xee\xe6\xe5\xec.',
                        }, waiting = 2.5 },
                        { name = '14. \xce\xf2\xea\xe0\xe7 (\xed\xe5 \xf5\xee\xf7\xe5\xf2)', lines = {
                            '/me \xef\xee\xed\xe8\xec\xe0\xfe\xf9\xe5 \xea\xe8\xe2\xe0\xe5\xf2',
                            '\xc1\xe5\xe7 \xef\xf0\xee\xe1\xeb\xe5\xec. \xc5\xf1\xeb\xe8 \xef\xe5\xf0\xe5\xe4\xf3\xec\xe0\xe5\xf8\xfc - \xef\xe8\xf8\xe8 \xe2 \xeb\xfe\xe1\xee\xe5 \xe2\xf0\xe5\xec\xff, \xe1\xf3\xe4\xe5\xec \xf0\xe0\xe4\xfb. \xd3\xe4\xe0\xf7\xe8 \xf2\xe5\xe1\xe5!',
                        }, waiting = 2.5 },
                    }
                            save_settings()
                        end
                        imgui.PopStyleColor(3)
                    imgui.EndChild()
                    end
                    imgui.EndTabItem()
                end
                if imgui.BeginTabItem(fa_icon.BOLT .. '  ' .. u8'\xc0\xe2\xf2\xee-\xe8\xed\xe2\xe0\xe9\xf2') then
                    if imgui.BeginChild('##verb_ai', imgui.ImVec2(-1, 0), false) then
                        fh_touch_scroll('##verb_ai')
                        imgui.TextColored(imgui.ImVec4(ar3,ag3,0,1), u8' \xc0\xe2\xf2\xee-\xe8\xed\xe2\xe0\xe9\xf2: \xea\xeb\xfe\xf7\xe5\xe2\xfb\xe5 \xf1\xeb\xee\xe2\xe0'); imgui.Separator()
                        imgui.TextDisabled(u8' \xc8\xe3\xf0\xee\xea \xed\xe0\xef\xe8\xf1\xe0\xeb \xf1\xeb\xee\xe2\xee \xe8\xe7 \xf1\xef\xe8\xf1\xea\xe0 -> \xf1\xea\xf0\xe8\xef\xf2 \xf1\xe0\xec \xee\xf2\xef\xf0\xe0\xe2\xe8\xf2 /faminvite')
                        imgui.Spacing()
                        imgui.TextDisabled(u8' \xd0\xe0\xe4\xe8\xf3\xf1 \xe8\xed\xe2\xe0\xe9\xf2\xe0:'); imgui.SameLine(); imgui.PushItemWidth(140*d)
                        if imgui.SliderFloat('##kai_r', sl.invite_radius, 2, 20) then settings.general.auto_invite_radius=sl.invite_radius[0]; save_settings() end
                        imgui.PopItemWidth()
                        imgui.TextDisabled(u8' \xc7\xe0\xe4\xe5\xf0\xe6\xea\xe0 (\xf1):'); imgui.SameLine(); imgui.PushItemWidth(140*d)
                        if imgui.SliderFloat('##kai_d', sl.invite_delay, 1, 15) then settings.general.auto_invite_delay=sl.invite_delay[0]; save_settings() end
                        imgui.PopItemWidth()
                        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                        do
                            local kai = settings.general.auto_keyword_invite
                            imgui.Text(u8'\xc0\xe2\xf2\xee \xef\xee \xf1\xeb\xee\xe2\xe0\xec'); imgui.SameLine()
                            if fh_toggle('##kai', kai, 40*d, 22*d) then
                                settings.general.auto_keyword_invite = not kai; save_settings()
                            end
                        end
                        imgui.Spacing()
                        local kwlist_h = imgui.GetContentRegionAvail().y - imgui.GetFrameHeightWithSpacing()
                        if imgui.BeginChild('##kwlist', imgui.ImVec2(-1, kwlist_h), true) then
                            fh_touch_scroll('##kwlist')
                            local kwl = settings.general.keyword_invite_list or {}
                            local rm_kw = nil
                            local cols = 3
                            for ki, kw in ipairs(kwl) do
                                if (ki-1) % cols ~= 0 then imgui.SameLine() end
                                local bw_kw = (imgui.GetWindowContentRegionWidth() - (cols-1)*5*d) / cols
                                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18,0.18,0.28,1))
                                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.5,0.12,0.12,1))
                                if imgui.Button(safe_u8(kw) .. '  ' .. fa_icon.XMARK .. '##kw'..ki, imgui.ImVec2(bw_kw, 22*d)) then rm_kw = ki end
                                imgui.PopStyleColor(2)
                            end
                            if rm_kw then table.remove(settings.general.keyword_invite_list, rm_kw); save_settings() end
                            imgui.EndChild()
                        end
                        imgui.PushItemWidth(340*d)
                        imgui.InputText(u8'##kwinput', kw_input, 128)
                        imgui.PopItemWidth(); imgui.SameLine()
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.1,0.35,0.1,1))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.15,0.5,0.15,1))
                        if imgui.Button(fa_icon.CIRCLE_PLUS .. '  ' .. u8'\xc4\xee\xe1\xe0\xe2\xe8\xf2\xfc##kwbtn') then
                            local kw_new = u8:decode(ffi.string(kw_input)):match('^%s*(.-)%s*$')
                            if kw_new ~= '' then
                                if not settings.general.keyword_invite_list then settings.general.keyword_invite_list = {} end
                                table.insert(settings.general.keyword_invite_list, kw_new:lower())
                                save_settings(); kw_input[0] = 0
                            end
                        end
                        imgui.PopStyleColor(2)
                    imgui.EndChild()
                    end
                    imgui.EndTabItem()
                end
                imgui.EndTabBar()
            end
            imgui.EndTabItem()
            end
            if imgui.BeginTabItem(fa_icon.FILE_LINES .. '  ' .. u8'\xd2\xe5\xea\xf1\xf2\xfb') then
            local texts_h = imgui.GetContentRegionAvail().y
            if imgui.BeginChild('##texts_wrap', imgui.ImVec2(-1, texts_h), false) then
                fh_touch_scroll('##texts_wrap')
                local ar_t = settings.interface.accent_r or 1
                local ag_t = settings.interface.accent_g or .65
                local avail_w = imgui.GetWindowContentRegionWidth()
                local tw_btns = 80*d
                local tw_time = 80*d
                local tw_idx  = 16*d
                local tw_gap  = 24*d
                local tw_field = math.max(80*d, avail_w - tw_btns - tw_time - tw_idx - tw_gap)

                local function section_header(icon_text, title_text, hint_text)
                    imgui.Spacing()
                    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(ar_t*0.12, ag_t*0.12, 0.0, 1.0))
                    imgui.BeginChild('##hdr_'..title_text, imgui.ImVec2(-1, 26*d), false)
                        imgui.SetCursorPosY(imgui.GetCursorPosY() + 4*d)
                        imgui.TextColored(imgui.ImVec4(ar_t, ag_t, 0.1, 1), icon_text .. '  ' .. u8(title_text))
                    imgui.EndChild()
                    imgui.PopStyleColor()
                    if hint_text and hint_text ~= '' then
                        imgui.TextDisabled(u8('  ' .. hint_text))
                    end
                    imgui.Spacing()
                end

                local function toggle_button(label_on, label_off, id, state, on_cb, off_cb)
                    imgui.AlignTextToFramePadding()
                    if fh_toggle('##' .. id, state, 40*d, 22*d) then
                        if state then off_cb() else on_cb() end
                    end
                end

                local function text_row(prefix, idx, item, buf, wbuf, on_delete)
                    if not buf then return end
                    imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.08, 0.08, 0.10, 1))

                    imgui.TextColored(imgui.ImVec4(ar_t*0.6, ag_t*0.6, 0.1, 1), u8(tostring(idx)))
                    imgui.SameLine(0, 6*d)

                    imgui.PushItemWidth(tw_field)
                    if imgui.InputText('##' .. prefix .. 't' .. idx, buf, 512) then
                        item.text = u8:decode(ffi.string(buf)); save_settings()
                    end
                    imgui.PopItemWidth()
                    imgui.SameLine(0, 6*d)

                    imgui.PushItemWidth(tw_time)
                    if imgui.InputFloat('##' .. prefix .. 'w' .. idx, wbuf, 0.5, 1.0, '%.1f') then
                        item.waiting = math.max(0.5, wbuf[0]); save_settings()
                    end
                    imgui.PopItemWidth()
                    imgui.SameLine(0, 6*d)
                    imgui.TextDisabled(u8'\xf1')
                    imgui.SameLine(0, 8*d)

                    imgui.PushStyleColor(imgui.Col.Button,       imgui.ImVec4(0.45, 0.08, 0.08, 1))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.10, 0.10, 1))
                    if imgui.SmallButton(fa_icon.TRASH .. '##' .. prefix .. 'r' .. idx) then on_delete() end
                    imgui.PopStyleColor(2)
                    imgui.PopStyleColor()
                end

                local function variants_section(key, sett, prefix, on_toggle, toggle_state, extra_controls)
                    if not sett.variants then return end

                    on_toggle()
                    if extra_controls then extra_controls() end
                    imgui.Spacing()

                    local next_vi = (sett.variant_idx or 0) % 3 + 1
                    imgui.TextDisabled(safe_u8('  \xd1\xeb\xe5\xe4\xf3\xfe\xf9\xe8\xe9: \xc2\xe0\xf0\xe8\xe0\xed\xf2 ' .. next_vi))
                    imgui.Spacing()

                    if not _G['vtab_'..key] then _G['vtab_'..key] = 1 end
                    local vtab = _G['vtab_'..key]
                    local vbw = (imgui.GetWindowContentRegionWidth() - 8*d) / 3
                    for vi = 1, 3 do
                        if vi > 1 then imgui.SameLine(0, 4*d) end
                        local is_next = (vi == next_vi)
                        local is_cur  = (vtab == vi)
                        if is_cur then
                            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(ar_t*0.5, ag_t*0.5, 0.05, 1))
                        elseif is_next then
                            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10, 0.35, 0.10, 1))
                        else
                            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.18, 0.22, 1))
                        end
                        local lbl = safe_u8('\xc2\xe0\xf0\xe8\xe0\xed\xf2 ' .. vi .. (is_next and ' (\xf1\xeb\xe5\xe4.)' or '') .. '##vt'..key..vi)
                        if imgui.Button(lbl, imgui.ImVec2(vbw, 22*d)) then _G['vtab_'..key] = vi end
                        imgui.PopStyleColor()
                    end
                    imgui.Spacing()

                    local var = sett.variants[vtab] or {items={}}
                    local bkey = prefix .. vtab
                    if not _G['vbufs_'..bkey] or #_G['vbufs_'..bkey] ~= #(var.items or {}) then
                        _G['vbufs_'..bkey] = {}; _G['vwbufs_'..bkey] = {}
                        for i, it in ipairs(var.items or {}) do
                            _G['vbufs_'..bkey][i]  = imgui.new.char[512](safe_u8(it.text or ''))
                            _G['vwbufs_'..bkey][i] = imgui.new.float(it.waiting or 1.5)
                        end
                    end
                    local to_rm = nil
                    for ri, ritem in ipairs(var.items or {}) do
                        if _G['vbufs_'..bkey][ri] then
                            text_row(bkey, ri, ritem, _G['vbufs_'..bkey][ri], _G['vwbufs_'..bkey][ri],
                                function() to_rm = ri; _G['vbufs_'..bkey]=nil; _G['vwbufs_'..bkey]=nil end)
                        end
                    end
                    if to_rm then table.remove(var.items, to_rm); save_settings() end

                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15,0.25,0.40,1))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18,0.32,0.52,1))
                    if imgui.Button(fa_icon.CIRCLE_PLUS .. u8'  \xd1\xf2\xf0\xee\xea\xe0##'..key..'add'..vtab, imgui.ImVec2(90*d, 0)) then
                        if not var.items then var.items = {} end
                        table.insert(var.items, {text='', waiting=1.5}); save_settings()
                        _G['vbufs_'..bkey]=nil; _G['vwbufs_'..bkey]=nil
                    end
                    imgui.PopStyleColor(2)
                end

                section_header(fa_icon.HAND_SPARKLES, '\xcf\xf0\xe8\xe2\xe5\xf2\xf1\xf2\xe2\xe8\xe5 \xef\xf0\xe8 \xe2\xf1\xf2\xf3\xef\xeb\xe5\xed\xe8\xe8', '{player_name} = \xed\xe8\xea.  \xd1\xf0\xe0\xe1\xe0\xf2\xfb\xe2\xe0\xe5\xf2 \xea\xee\xe3\xe4\xe0 \xea\xf2\xee-\xf2\xee \xe2\xf1\xf2\xf3\xef\xe8\xeb \xe2 \xf1\xe5\xec\xfc\xfe.')
                do
                    local uw_auto = settings.general.auto_welcome
                    variants_section('wel', settings.welcome, 'w',
                        function()
                            toggle_button('\xc2\xca\xcb', '\xc2\xdb\xca\xcb', 'welcome_tog', uw_auto,
                                function() settings.general.auto_welcome=true;  save_settings() end,
                                function() settings.general.auto_welcome=false; save_settings() end)
                        end, uw_auto, nil)
                end

                section_header(fa_icon.CHART_LINE, '\xcf\xee\xe7\xe4\xf0\xe0\xe2\xeb\xe5\xed\xe8\xe5 \xf1 \xf3\xf0\xee\xe2\xed\xe5\xec', '{player_name} = \xed\xe8\xea.  \xd1\xf0\xe0\xe1\xe0\xf2\xfb\xe2\xe0\xe5\xf2 \xea\xee\xe3\xe4\xe0 \xf7\xeb\xe5\xed \xf1\xe5\xec\xfc\xe8 \xef\xee\xe4\xed\xff\xeb \xf3\xf0\xee\xe2\xe5\xed\xfc.')
                do
                    local uc_auto = settings.general.auto_congrats
                    variants_section('cng', settings.congrats, 'c',
                        function()
                            toggle_button('\xc2\xca\xcb', '\xc2\xdb\xca\xcb', 'congrats_tog', uc_auto,
                                function() settings.general.auto_congrats=true;  save_settings() end,
                                function() settings.general.auto_congrats=false; save_settings() end)
                        end, uc_auto, nil)
                end

                imgui.Spacing()
                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.07,0.07,0.09,1))
                imgui.BeginChild('##batch_box', imgui.ImVec2(-1, 178*d), true)
                    imgui.Spacing()
                    imgui.TextColored(imgui.ImVec4(ar_t*0.7, ag_t*0.7, 0.1, 1), u8'  \xc3\xf0\xf3\xef\xef\xee\xe2\xee\xe5 \xef\xee\xe7\xe4\xf0\xe0\xe2\xeb\xe5\xed\xe8\xe5:')
                    imgui.SameLine(0, 10*d)
                    imgui.TextDisabled(u8'\xe5\xf1\xeb\xe8')
                    imgui.SameLine(0, 5*d)
                    imgui.PushItemWidth(40*d)
                    local _bs = imgui.new.int(CONGRATS_BATCH_SINGLE)
                    if imgui.InputInt('##bsingle', _bs, 0) then CONGRATS_BATCH_SINGLE = math.max(2, math.min(20, _bs[0])) end
                    imgui.PopItemWidth()
                    imgui.SameLine(0, 5*d)
                    imgui.TextDisabled(u8'\xe8 \xe1\xee\xeb\xe5\xe5 \xf7\xe5\xeb. \xef\xee\xe4\xed\xff\xeb\xe8 \xf3\xf0\xee\xe2\xe5\xed\xfc \xe7\xe0')
                    imgui.SameLine(0, 5*d)
                    imgui.PushItemWidth(40*d)
                    local _bw = imgui.new.int(CONGRATS_BATCH_WINDOW)
                    if imgui.InputInt('##bwin', _bw, 0) then CONGRATS_BATCH_WINDOW = math.max(2, math.min(30, _bw[0])) end
                    imgui.PopItemWidth()
                    imgui.SameLine(0, 5*d)
                    imgui.TextDisabled(u8'\xf1 \x97 3 \xe2\xe0\xf0\xe8\xe0\xed\xf2\xe0 \xef\xee \xea\xf0\xf3\xe3\xf3:')
                    imgui.Spacing()
                    imgui.TextDisabled(u8'  {names} = \xf1\xef\xe8\xf1\xee\xea \xed\xe8\xea\xee\xe2 \xf7\xe5\xf0\xe5\xe7 \xe7\xe0\xef\xff\xf2\xf3\xfe')
                    imgui.Spacing()
                    if not _G.bmsg_bufs then
                        _G.bmsg_bufs = {}
                        for bi = 1, 3 do
                            _G.bmsg_bufs[bi] = imgui.new.char[256](safe_u8(CONGRATS_BATCH_MSGS[bi] or ''))
                        end
                    end
                    local next_bi = CONGRATS_BATCH_MSG_IDX % 3 + 1
                    for bi = 1, 3 do
                        local is_next = (bi == next_bi)
                        if is_next then
                            imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.10, 0.25, 0.10, 1))
                        else
                            imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.08, 0.08, 0.10, 1))
                        end
                        imgui.TextDisabled(safe_u8(bi .. (is_next and ' (\xf1\xeb\xe5\xe4.)' or '') .. ':'))
                        imgui.SameLine(0, 6*d)
                        imgui.PushItemWidth(-1)
                        if imgui.InputText('##bmsg'..bi, _G.bmsg_bufs[bi], 256) then
                            CONGRATS_BATCH_MSGS[bi] = u8:decode(ffi.string(_G.bmsg_bufs[bi]))
                        end
                        imgui.PopItemWidth()
                        imgui.PopStyleColor()
                    end
                    imgui.Spacing()
                    imgui.TextDisabled(u8'  \xc5\xf1\xeb\xe8 \xec\xe5\xed\xfc\xf8\xe5 \xef\xee\xf0\xee\xe3\xe0 \x97 \xea\xe0\xe6\xe4\xfb\xe9 \xef\xee\xe7\xe4\xf0\xe0\xe2\xeb\xff\xe5\xf2\xf1\xff \xee\xf2\xe4\xe5\xeb\xfc\xed\xee \xe2\xe0\xf0\xe8\xe0\xed\xf2\xee\xec \xe2\xfb\xf8\xe5.')
                imgui.EndChild()
                imgui.PopStyleColor()

                if not settings.quest_congrats then settings.quest_congrats = {variants={{items={{text='{player_name}, \xee\xf2\xeb\xe8\xf7\xed\xe0\xff \xf0\xe0\xe1\xee\xf2\xe0! \xca\xe2\xe5\xf1\xf2 \xe2\xfb\xef\xee\xeb\xed\xe5\xed!',waiting=1.5}}}}, use_fam=true, enabled=true, variant_idx=0} end
                section_header(fa_icon.LIST_CHECK, '\xcf\xee\xe7\xe4\xf0\xe0\xe2\xeb\xe5\xed\xe8\xe5 \xf1 \xea\xe2\xe5\xf1\xf2\xee\xec', '{player_name} = \xed\xe8\xea.  \xd1\xf0\xe0\xe1\xe0\xf2\xfb\xe2\xe0\xe5\xf2 \xea\xee\xe3\xe4\xe0 \xea\xf2\xee-\xf2\xee \xe2\xfb\xef\xee\xeb\xed\xe8\xeb \xf1\xe5\xec\xe5\xe9\xed\xfb\xe9 \xea\xe2\xe5\xf1\xf2.')
                do
                    local uqe = settings.quest_congrats.enabled
                    variants_section('qcg', settings.quest_congrats, 'q',
                        function()
                            toggle_button('\xc2\xca\xcb', '\xc2\xdb\xca\xcb', 'qcong_tog', uqe,
                                function() settings.quest_congrats.enabled=true;  save_settings() end,
                                function() settings.quest_congrats.enabled=false; save_settings() end)
                        end, uqe, nil)
                end

                if not settings.coins_thanks then settings.coins_thanks = {items={{text='/b \xd1\xef\xe0\xf1\xe8\xe1\xee, {player_name}! \xcc\xee\xed\xe5\xf2\xfb \xef\xf0\xe8\xed\xff\xf2\xfb!',waiting=1.0}}, use_fam=false, enabled=true} end
                section_header(fa_icon.COINS, '\xc1\xeb\xe0\xe3\xee\xe4\xe0\xf0\xed\xee\xf1\xf2\xfc \xe7\xe0 \xec\xee\xed\xe5\xf2\xfb / \xf2\xe0\xeb\xee\xed\xfb', '{player_name} = \xed\xe8\xea.  \xd1\xf0\xe0\xe1\xe0\xf2\xfb\xe2\xe0\xe5\xf2 \xea\xee\xe3\xe4\xe0 \xe8\xe3\xf0\xee\xea \xf1\xe4\xe0\xeb \xf1\xe5\xec\xe5\xe9\xed\xfb\xe5 \xec\xee\xed\xe5\xf2\xfb.')
                do
                    local ect = settings.coins_thanks.enabled
                    toggle_button('\xc2\xca\xcb', '\xc2\xdb\xca\xcb', 'cthx_tog',
                        ect,
                        function() settings.coins_thanks.enabled=true;  save_settings() end,
                        function() settings.coins_thanks.enabled=false; save_settings() end
                    )
                    imgui.SameLine(0, 12*d)
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15,0.25,0.40,1))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18,0.32,0.52,1))
                    if imgui.Button(fa_icon.CIRCLE_PLUS .. u8'  \xd1\xf2\xf0\xee\xea\xe0##cthx', imgui.ImVec2(90*d,0)) then
                        table.insert(settings.coins_thanks.items, {text='', waiting=1.0}); save_settings(); _G.tbufs=nil; _G.twbufs=nil
                    end
                    imgui.PopStyleColor(2)
                end
                imgui.Spacing()
                if not _G.tbufs or #_G.tbufs ~= #settings.coins_thanks.items then
                    _G.tbufs = {}; _G.twbufs = {}
                    for i, it in ipairs(settings.coins_thanks.items) do
                        _G.tbufs[i]  = imgui.new.char[512](safe_u8(it.text))
                        _G.twbufs[i] = imgui.new.float(it.waiting or 1.0)
                    end
                end
                local to_rm_ct = nil
                for ti, titem in ipairs(settings.coins_thanks.items) do
                    if _G.tbufs[ti] then
                        text_row('th', ti, titem, _G.tbufs[ti], _G.twbufs[ti],
                            function() to_rm_ct = ti; _G.tbufs=nil; _G.twbufs=nil end)
                    end
                end
                if to_rm_ct then table.remove(settings.coins_thanks.items, to_rm_ct); save_settings() end

                if not settings.talon_congrats then settings.talon_congrats = {items={{text='{player_name}, \xf1\xef\xe0\xf1\xe8\xe1\xee \xe7\xe0 \xf2\xe0\xeb\xee\xed\xfb! \xcc\xee\xeb\xee\xe4\xe5\xf6!',waiting=1.5}}, use_fam=true, enabled=true} end
                section_header(fa_icon.TICKET, '\xcf\xee\xe7\xe4\xf0\xe0\xe2\xeb\xe5\xed\xe8\xe5 \xf1 \xee\xe1\xec\xe5\xed\xee\xec \xf2\xe0\xeb\xee\xed\xee\xe2', '{player_name} = \xed\xe8\xea.  \xd1\xf0\xe0\xe1\xe0\xf2\xfb\xe2\xe0\xe5\xf2 \xea\xee\xe3\xe4\xe0 \xe8\xe3\xf0\xee\xea \xee\xe1\xec\xe5\xed\xff\xeb \xf2\xe0\xeb\xee\xed\xfb \xed\xe0 \xf0\xe5\xef\xf3\xf2\xe0\xf6\xe8\xfe.')
                do
                    local etlc = settings.talon_congrats.enabled
                    toggle_button('\xc2\xca\xcb', '\xc2\xdb\xca\xcb', 'tlc_tog',
                        etlc,
                        function() settings.talon_congrats.enabled=true;  save_settings() end,
                        function() settings.talon_congrats.enabled=false; save_settings() end
                    )
                    imgui.SameLine(0, 12*d)
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15,0.25,0.40,1))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18,0.32,0.52,1))
                    if imgui.Button(fa_icon.CIRCLE_PLUS .. u8'  \xd1\xf2\xf0\xee\xea\xe0##tlcl', imgui.ImVec2(90*d,0)) then
                        table.insert(settings.talon_congrats.items, {text='', waiting=1.5}); save_settings(); _G.tlcbufs=nil; _G.tlcwbufs=nil
                    end
                    imgui.PopStyleColor(2)
                end
                imgui.Spacing()
                if not _G.tlcbufs or #_G.tlcbufs ~= #settings.talon_congrats.items then
                    _G.tlcbufs = {}; _G.tlcwbufs = {}
                    for i, it in ipairs(settings.talon_congrats.items) do
                        _G.tlcbufs[i]  = imgui.new.char[512](safe_u8(it.text))
                        _G.tlcwbufs[i] = imgui.new.float(it.waiting or 1.5)
                    end
                end
                local to_rm_tlc = nil
                for tlci, tlcitem in ipairs(settings.talon_congrats.items) do
                    if _G.tlcbufs[tlci] then
                        text_row('tlc', tlci, tlcitem, _G.tlcbufs[tlci], _G.tlcwbufs[tlci],
                            function() to_rm_tlc = tlci; _G.tlcbufs=nil; _G.tlcwbufs=nil end)
                    end
                end
                if to_rm_tlc then table.remove(settings.talon_congrats.items, to_rm_tlc); save_settings() end

                section_header(fa_icon.PAPER_PLANE, '\xc0\xe2\xf2\xee \xe8\xed\xe2\xe0\xe9\xf2 \xf2\xe5\xea\xf1\xf2', '& = \xef\xe5\xf0\xe5\xed\xee\xf1 \xf1\xf2\xf0\xee\xea\xe8,  {arg_id} = ID \xe8\xe3\xf0\xee\xea\xe0.  \xce\xf2\xef\xf0\xe0\xe2\xeb\xff\xe5\xf2\xf1\xff \xef\xf0\xe8 /fi [ID].')
                local rpt = (settings.rp_invite.text or ''):gsub('&', '\n')
                if not _G._rpi_buf then _G._rpi_buf = imgui.new.char[4096](safe_u8(rpt)) end
                imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.08,0.08,0.10,1))
                imgui.PushItemWidth(-1)
                if imgui.InputTextMultiline('##rpi', _G._rpi_buf, 4096, imgui.ImVec2(-1, 72*d)) then
                    settings.rp_invite.text = u8:decode(ffi.string(_G._rpi_buf)):gsub('\n', '&'); save_settings()
                end
                imgui.PopItemWidth()
                imgui.PopStyleColor()

                imgui.Spacing()
                imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xc0\xe2\xf2\xee-\xee\xf2\xf7\xb8\xf2 \xef\xee \xe8\xed\xe2\xe0\xe9\xf2\xe0\xec')
                imgui.Separator()
                if not settings.tg.auto_inv_hour then settings.tg.auto_inv_hour = 23 end
                if not settings.tg.auto_inv_min  then settings.tg.auto_inv_min  = 59 end
                local auto_en = settings.tg.auto_inv_report or false
                if fh_toggle_row(u8'\xc0\xe2\xf2\xee-\xee\xf2\xf7\xb8\xf2 \xe2 \xea\xee\xed\xf6\xe5 \xe4\xed\xff', '##tg_autoinv', auto_en, 220*d) then
                    settings.tg.auto_inv_report = not auto_en; save_settings()
                end
                imgui.SameLine(0, 16*d)
                imgui.TextDisabled(u8'\xc2\xf0\xe5\xec\xff:')
                imgui.SameLine(0, 6*d)
                imgui.PushItemWidth(44*d)
                local _aih = imgui.new.int(settings.tg.auto_inv_hour or 23)
                if imgui.InputInt('##tg_aih', _aih, 0) then
                    settings.tg.auto_inv_hour = math.max(0, math.min(23, _aih[0])); save_settings()
                end
                imgui.PopItemWidth()
                imgui.SameLine(0, 4*d)
                imgui.TextDisabled(u8':')
                imgui.SameLine(0, 4*d)
                imgui.PushItemWidth(44*d)
                local _aim = imgui.new.int(settings.tg.auto_inv_min or 59)
                if imgui.InputInt('##tg_aim', _aim, 0) then
                    settings.tg.auto_inv_min = math.max(0, math.min(59, _aim[0])); save_settings()
                end
                imgui.PopItemWidth()
                imgui.SameLine(0, 12*d)
                imgui.TextDisabled(u8'\x97 \xea\xe0\xe6\xe4\xfb\xe9 \xe7\xe0\xec \xee\xf2\xef\xf0\xe0\xe2\xeb\xff\xe5\xf2 \xf1\xe2\xee\xe9 \xee\xf2\xf7\xb8\xf2')

                imgui.EndChild()
            end
            imgui.EndTabItem()
            end
                imgui.EndTabBar()
            end
end

local function fh_render_tab3()
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
        local ar=settings.interface.accent_r or 1
        local ag=settings.interface.accent_g or .65
        local ab=settings.interface.accent_b or 0

        imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd8\xe0\xe1\xeb\xee\xed\xfb \xe0\xe2\xf2\xee\xef\xe8\xe0\xf0\xe0')
        imgui.SameLine()
        imgui.TextDisabled(u8'/fp [\xed\xee\xec\xe5\xf0] \x97 \xf0\xf3\xf7\xed\xee\xe9 \xe7\xe0\xef\xf3\xf1\xea')
        imgui.Separator()

        local piar_h = imgui.GetContentRegionAvail().y - imgui.GetFrameHeightWithSpacing()
        if imgui.BeginChild('##piars', imgui.ImVec2(-1, piar_h), true) then
            fh_touch_scroll('##piars')
            local cw = imgui.GetWindowContentRegionWidth()

            local col_dot  = 18*d
            local col_btns = math.max(140*d, math.min(280*d, cw * 0.42))
            col_btns = math.min(col_btns, math.max(80*d, cw - col_dot - 80*d))
            local col_info = math.max(60*d, cw - col_dot - col_btns)

            imgui.Columns(3, '##phdr', false)
            imgui.SetColumnWidth(0, col_dot)
            imgui.SetColumnWidth(1, col_info)
            imgui.SetColumnWidth(2, col_btns)
            imgui.NextColumn()
            imgui.TextDisabled(u8'\xd8\xe0\xe1\xeb\xee\xed')
            imgui.NextColumn()
            imgui.TextDisabled(u8'\xc4\xe5\xe9\xf1\xf2\xe2\xe8\xff')
            imgui.NextColumn(); imgui.Columns(1); imgui.Separator()

            for i, t in ipairs(settings.piar_templates) do
                imgui.Columns(3, '##pr'..i, false)
                imgui.SetColumnWidth(0, col_dot)
                imgui.SetColumnWidth(1, col_info)
                imgui.SetColumnWidth(2, col_btns)

                if t.auto then
                    imgui.TextColored(imgui.ImVec4(0.2,0.85,0.2,1), u8'\x95')
                else
                    imgui.TextColored(imgui.ImVec4(0.85,0.2,0.2,1), u8'\x95')
                end
                imgui.NextColumn()

                imgui.Text(safe_u8(' ' .. (t.name or '')))
                imgui.TextDisabled(safe_u8('  ' .. #(t.lines or {}) .. ' \xf1\xf2\xf0 | ' .. (t.waiting or 1.5) .. '\xf1'))
                if t.auto then
                    local elapsed = os.time() - (t.last_time or 0)
                    local interval = t._next_interval or t.auto_interval or 300
                    local left = math.max(0, interval - elapsed)
                    local rng_str = (t.auto_interval_max or 0) > (t.auto_interval or 300) and (' [\xf0\xe0\xed\xe4 ' .. (t.auto_interval or 300) .. '-' .. t.auto_interval_max .. '\xf1]') or ''
                    imgui.TextDisabled(safe_u8('  \xce\xf7\xe5\xf0\xe5\xe4\xfc: ' .. left .. '\xf1 / ' .. interval .. '\xf1' .. rng_str))
                end
                imgui.NextColumn()

                local avail_w2 = col_btns - imgui.GetStyle().ItemSpacing.x * 0.5
                local toggle_w2 = 40*d
                local auto_label_w = imgui.CalcTextSize(u8'\xc0\xe2\xf2\xee').x
                local gap2 = 4*d
                local gap3 = 8*d
                local gap4 = 4*d
                local min_btn_w = 46*d

                local need_w2 = min_btn_w * 2 + gap2 + gap3 + auto_label_w + gap4 + toggle_w2
                local btns_fit_row2 = avail_w2 >= need_w2
                local bw2
                if btns_fit_row2 then

                    bw2 = math.max(min_btn_w, (avail_w2 - gap3 - auto_label_w - gap4 - toggle_w2 - gap2) / 2)
                else

                    bw2 = math.max(min_btn_w, (avail_w2 - gap2) / 2)
                end
                if imgui.Button(fa_icon.PLAY .. u8'  \xcf\xf3\xf1\xea##p'..i, imgui.ImVec2(bw2, 0)) then send_piar(i) end
                imgui.SameLine(0,gap2)
                if imgui.Button(fa_icon.PEN_TO_SQUARE .. u8'  \xd0\xe5\xe4.##e'..i, imgui.ImVec2(bw2, 0)) then
                    for _k in pairs(_G) do if type(_k)=='string' and _k:find('^fh_piar_linebuf_') then _G[_k]=nil end end
                    piar_edit_index=i; PiarEditWindow[0]=true
                end

                if btns_fit_row2 then
                    imgui.SameLine(0,gap3)
                else
                    imgui.Spacing()
                end
                imgui.AlignTextToFramePadding()
                imgui.TextDisabled(u8'\xc0\xe2\xf2\xee'); imgui.SameLine(0,gap4)
                if fh_toggle('##pauto'..i, t.auto, toggle_w2) then
                    if t.auto then t.auto=false else t.auto=true; t.last_time=os.time() end
                    save_settings()
                end
                imgui.NextColumn(); imgui.Columns(1); imgui.Separator()
            end
            imgui.EndChild()
        end
        if imgui.Button(fa_icon.CIRCLE_PLUS .. '  ' .. u8'\xd8\xe0\xe1\xeb\xee\xed', imgui.ImVec2(-1, 0)) then
            table.insert(settings.piar_templates, {name='\xcd\xee\xe2\xfb\xe9',enable=true,auto=false,auto_interval=300,auto_interval_max=0,waiting=1.5,lines={'/s \xd2\xe5\xea\xf1\xf2 {family_name}'},last_time=0})
            save_settings()
            for _k in pairs(_G) do if type(_k)=='string' and _k:find('^fh_piar_linebuf_') then _G[_k]=nil end end
            piar_edit_index=#settings.piar_templates; PiarEditWindow[0]=true
        end
end

local function fh_render_tab4()
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
            if imgui.BeginTabBar('##onltabs') then
                if imgui.BeginTabItem(fa_icon.USERS .. '  ' .. u8'\xd3\xf7\xe0\xf1\xf2\xed\xe8\xea\xe8') then
                local onl_h = imgui.GetContentRegionAvail().y

                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd7\xeb\xe5\xed\xfb \xf1\xe5\xec\xfc\xe8 \xee\xed\xeb\xe0\xe9\xed')
                if fmembers_last_update > 0 then
                    imgui.SameLine()
                    imgui.TextDisabled(safe_u8(' (\xee\xe1\xed\xee\xe2\xeb\xe5\xed\xee: ' .. os.date('%H:%M:%S', fmembers_last_update) .. ')'))
                end
                imgui.Separator()
                if _G.fmembers_collecting then
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.5,0.4,0.0,1))
                    imgui.Button(fa_icon.HOURGLASS_HALF .. u8'  \xd1\xe1\xee\xf0... ', imgui.ImVec2(-1 - 80*d, 28*d))
                    imgui.PopStyleColor()
                    imgui.SameLine(0, 4*d)
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.4,0.1,0.1,1))
                    if imgui.Button(fa_icon.XMARK .. '##fmreset', imgui.ImVec2(-1, 28*d)) then
                        _G.fmembers_collecting = false; _G.fmembers_collect_start = nil
                    end
                    imgui.PopStyleColor()
                else
                    if imgui.Button(fa_icon.ROTATE .. u8'  \xce\xe1\xed\xee\xe2\xe8\xf2\xfc (/fmembers) ', imgui.ImVec2(-1, 28*d)) then
                        _G.fmembers_collecting = false
                        _G.fmembers_requested = true
                        sampSendChat('/fmembers')
                    end
                end
                imgui.Spacing()

                if fmembers_last_update == 0 and not _G.fmembers_collecting then
                    imgui.TextDisabled(u8'  \xcd\xe0\xe6\xec\xe8\xf2\xe5 "\xce\xe1\xed\xee\xe2\xe8\xf2\xfc" \x97 \xf1\xea\xf0\xe8\xef\xf2 \xee\xf2\xef\xf0\xe0\xe2\xe8\xf2 /fmembers')
                    imgui.TextDisabled(u8'  \xe8 \xe0\xe2\xf2\xee\xec\xe0\xf2\xe8\xf7\xe5\xf1\xea\xe8 \xef\xe5\xf0\xe5\xf5\xe2\xe0\xf2\xe8\xf2 \xf1\xef\xe8\xf1\xee\xea \xee\xed\xeb\xe0\xe9\xed')
                elseif _G.fmembers_collecting then
                    local cnt_so_far = 0; for _ in pairs(fmembers_online) do cnt_so_far = cnt_so_far + 1 end
                    imgui.TextColored(imgui.ImVec4(1,0.8,0.2,1), safe_u8('  \xd1\xe1\xee\xf0 \xf1\xef\xe8\xf1\xea\xe0... \xed\xe0\xe9\xe4\xe5\xed\xee: ' .. cnt_so_far))
                else
                    local count = 0
                    for _ in pairs(fmembers_online) do count = count + 1 end
                    if count == 0 then
                        imgui.TextColored(imgui.ImVec4(1,0.6,0.2,1), u8'  \xcd\xe8\xea\xee\xe3\xee \xe8\xe7 \xf1\xe5\xec\xfc\xe8 \xed\xe5\xf2 \xee\xed\xeb\xe0\xe9\xed')
                    else

                        local onl_w = imgui.GetWindowContentRegionWidth()
                        local onl_c2 = math.max(60*d, math.min(90*d, onl_w * 0.15))
                        local onl_c1 = onl_w - onl_c2
                        imgui.Columns(2, '##onlcols', false)
                        imgui.SetColumnWidth(0, onl_c1)
                        imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xcd\xe8\xea')
                        imgui.NextColumn()
                        imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd0\xe0\xed\xe3')
                        imgui.NextColumn(); imgui.Separator(); imgui.Columns(1)

                        if imgui.BeginChild('##onllist', imgui.ImVec2(-1, -1), false) then
                            fh_touch_scroll('##onllist')
                            local onl2_w = imgui.GetWindowContentRegionWidth()
                            local onl2_c3 = math.max(40*d, math.min(60*d, onl2_w * 0.10))
                            local onl2_c2 = math.max(80*d, math.min(200*d, onl2_w * 0.30))
                            local onl2_c1 = onl2_w - onl2_c2 - onl2_c3
                            imgui.Columns(3, '##onlcols2', false)
                            imgui.SetColumnWidth(0, onl2_c1)
                            imgui.SetColumnWidth(1, onl2_c2)
                            imgui.SetColumnWidth(2, onl2_c3)

                            local sorted = {}
                            for nick, rank in pairs(fmembers_online) do
                                local rn = tonumber(rank:match('%d+')) or 0
                                sorted[#sorted+1] = {nick=nick, rank=rank, rn=rn}
                            end
                            table.sort(sorted, function(a,b)
                                if a.rn ~= b.rn then return a.rn > b.rn end
                                return a.nick < b.nick
                            end)
                            for _, m in ipairs(sorted) do
                                imgui.Text(fa_icon.USER .. '  ' .. safe_u8(m.nick)); imgui.NextColumn()
                                imgui.TextDisabled(fa_icon.CROWN .. '  ' .. safe_u8(m.rank)); imgui.NextColumn()
                                if imgui.SmallButton(fa_icon.USER_GEAR .. u8('##ctx_' .. m.nick)) then
                                    fmember_ctx_nick = m.nick
                                    ctx_rank_input[0] = m.rn > 0 and m.rn or 1
                                    ctx_mute_min[0] = 10
                                    ffi.copy(ctx_reason_buf, '')
                                    ffi.copy(ctx_tag_buf, '')
                                    MemberCtxWindow[0] = true
                                end
                                imgui.NextColumn()
                            end
                            imgui.Columns(1)
                            imgui.EndChild()
                        end
                    end
                end
                    imgui.EndTabItem()
                end
                if imgui.BeginTabItem(fa_icon.BAN .. '  ' .. u8'\xd7\xd1') then
                    local ar=settings.interface.accent_r or 1
                    local ag=settings.interface.accent_g or .65
                    local ab=settings.interface.accent_b or 0
                    imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd7\xb8\xf0\xed\xfb\xe9 \xf1\xef\xe8\xf1\xee\xea \xf1\xe5\xec\xfc\xe8'); imgui.Separator()
                    local bl_row_w = imgui.GetWindowContentRegionWidth()
                    local bl_btn_w = 90*d
                    local bl_name_w = math.max(90*d, math.min(150*d, bl_row_w * 0.28))
                    local bl_reason_w = math.max(90*d, bl_row_w - bl_name_w - bl_btn_w - 16*d)
                    imgui.PushItemWidth(bl_name_w)
                    imgui.InputTextWithHint(u8'##bl_n', u8'\xcd\xe8\xea\xed\xe5\xe9\xec', qa.bl_name, 256)
                    imgui.SameLine(0,4)
                    imgui.PushItemWidth(bl_reason_w)
                    imgui.InputTextWithHint(u8'##bl_r', u8'\xcf\xf0\xe8\xf7\xe8\xed\xe0', qa.bl_reason, 256)
                    imgui.PopItemWidth(); imgui.PopItemWidth()
                    imgui.SameLine(0,4)
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.55,0.1,0.1,1))
                    if imgui.Button(fa_icon.USER_SLASH .. u8'  \xc2 \xd7\xd1', imgui.ImVec2(bl_btn_w, 0)) then
                        local n = ffi.string(qa.bl_name)
                        local r = u8:decode(ffi.string(qa.bl_reason))
                        if n ~= '' then
                            table.insert(settings.blacklist, {name=n, reason=r})
                            save_settings(); qa.bl_name[0]=0; qa.bl_reason[0]=0
                        end
                    end
                    imgui.PopStyleColor()
                    imgui.Separator()
                    local bl_h = imgui.GetContentRegionAvail().y
                    if imgui.BeginChild('##bl_list', imgui.ImVec2(-1, bl_h), true) then
                        fh_touch_scroll('##bl_list')
                        if #settings.blacklist == 0 then
                            imgui.TextDisabled(u8'  \xd1\xef\xe8\xf1\xee\xea \xef\xf3\xf1\xf2')
                        else
                            local blc_w = imgui.GetWindowContentRegionWidth()
                            local blc0 = math.max(120*d, blc_w * 0.30)
                            local blc1 = math.max(120*d, blc_w * 0.40)
                            imgui.Columns(3, '##blcols', false)
                            imgui.SetColumnWidth(0, blc0)
                            imgui.SetColumnWidth(1, blc1)
                            imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xcd\xe8\xea'); imgui.NextColumn()
                            imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xcf\xf0\xe8\xf7\xe8\xed\xe0'); imgui.NextColumn()
                            imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xc4\xe5\xe9\xf1\xf2\xe2\xe8\xe5'); imgui.NextColumn()
                            imgui.Separator()
                            local rm_bl = nil
                            for i, v in ipairs(settings.blacklist) do
                                imgui.Text(safe_u8(' ' .. (v.name or ''))); imgui.NextColumn()
                                imgui.TextDisabled(safe_u8(' ' .. tostring(v.reason or ''))); imgui.NextColumn()
                                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.4,0.1,0.1,1))
                                if imgui.SmallButton(fa_icon.TRASH .. u8'  \xd3\xe4\xe0\xeb\xe8\xf2\xfc##bl'..i) then rm_bl = i end
                                imgui.PopStyleColor()
                                imgui.NextColumn()
                            end
                            if rm_bl then table.remove(settings.blacklist, rm_bl); save_settings() end
                            imgui.Columns(1)
                        end
                        imgui.EndChild()
                    end
                    imgui.EndTabItem()
                end
                imgui.EndTabBar()
            end
end

local function fh_render_tab5()
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
          local pr_h = imgui.GetContentRegionAvail().y
          if imgui.BeginChild('##premii_wrap', imgui.ImVec2(-1, pr_h), false) then
              fh_touch_scroll('##premii_wrap')
              local ar=settings.interface.accent_r or 1
              local ag=settings.interface.accent_g or .65
              local ab=settings.interface.accent_b or 0

              imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), fa_icon.SACK_DOLLAR .. '  ' .. u8'\xd0\xe0\xf1\xf6\xe5\xed\xea\xe8:')
              if not _G.coin_reward_buf then _G.coin_reward_buf = imgui.new.int(1) end
              if not _G.talon_reward_buf then _G.talon_reward_buf = imgui.new.int(1) end
              fh_labeled_inputs_row({
                  {label=u8'\xc7\xe0 \xea\xe2\xe5\xf1\xf2', id='qra', buf=qa.reward_amount, value=settings.quest_reward_amount or 1000000},
                  {label=u8'\xc7\xe0 \xec\xee\xed\xe5\xf2\xf3', id='cra', buf=_G.coin_reward_buf, value=settings.coin_reward_amount or 10000},
                  {label=u8'\xc7\xe0 \xf2\xe0\xeb\xee\xed', id='tra', buf=_G.talon_reward_buf, value=settings.talon_reward_amount or 30000},
              }, function(idx, val)
                  if idx == 1 then settings.quest_reward_amount = math.max(0, val)
                  elseif idx == 2 then settings.coin_reward_amount = math.max(0, val)
                  elseif idx == 3 then settings.talon_reward_amount = math.max(0, val) end
                  save_settings()
              end)
              imgui.Separator()

              local half_w = (imgui.GetWindowContentRegionWidth() - 8*d) / 2

              local pr_avail = imgui.GetContentRegionAvail().y
              local pr_tg_row_h = imgui.GetFrameHeightWithSpacing() + 8*d
              local pr_seps_h = 3 * (imgui.GetTextLineHeightWithSpacing() * 0.5 + 4*d)
              local pr_panels_h = math.max(120*d, math.min(220*d, (pr_avail - pr_tg_row_h - pr_seps_h) / 2))

              if imgui.BeginChild('##q_panel', imgui.ImVec2(half_w, pr_panels_h), true) then
                  fh_touch_scroll('##q_panel')
                  imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), fa_icon.LIST_CHECK .. '  ' .. u8'\xca\xe2\xe5\xf1\xf2\xfb')
                  imgui.SameLine()
                  if imgui.SmallButton(fa_icon.ROTATE_LEFT .. '##qrst') then settings.quests_stats = {}; save_settings() end
                  imgui.Separator()
                  local q_total_sum = 0
                  local q_list = {}
                  for k, v in pairs(settings.quests_stats or {}) do
                      q_total_sum = q_total_sum + v * (settings.quest_reward_amount or 1000000)
                      table.insert(q_list, {nick=k, count=v})
                  end
                  table.sort(q_list, function(a,b) return a.count > b.count end)
                  imgui.TextDisabled(safe_u8('\xc8\xf2\xee\xe3\xee \xef\xf0\xe5\xec\xe8\xe9: ' .. q_total_sum .. '$'))
                  imgui.Separator()
                  if #q_list == 0 then
                      imgui.TextDisabled(u8'  \xcd\xe5\xf2 \xe4\xe0\xed\xed\xfb\xf5')
                  else
                      imgui.Columns(3, '##qcols', false)
                      imgui.SetColumnWidth(0, half_w * 0.45)
                      imgui.SetColumnWidth(1, half_w * 0.25)
                      imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xcd\xe8\xea'); imgui.NextColumn()
                      imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xca\xe2.'); imgui.NextColumn()
                      imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd1\xf3\xec\xec\xe0'); imgui.NextColumn()
                      imgui.Separator()
                      for _, row in ipairs(q_list) do
                          local sum = row.count * (settings.quest_reward_amount or 1000000)
                          imgui.Text(safe_u8(' '..row.nick)); imgui.NextColumn()
                          imgui.Text(safe_u8(' '..row.count)); imgui.NextColumn()
                          imgui.Text(safe_u8(' '..sum..'$')); imgui.NextColumn()
                      end
                      imgui.Columns(1)
                  end
                  imgui.EndChild()
              end

              imgui.SameLine(0, 8*d)

              if imgui.BeginChild('##c_panel', imgui.ImVec2(half_w, pr_panels_h), true) then
                  fh_touch_scroll('##c_panel')
                  imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), fa_icon.COINS .. '  ' .. u8'\xcc\xee\xed\xe5\xf2\xfb')
                  imgui.SameLine()
                  if imgui.SmallButton(fa_icon.ROTATE_LEFT .. '##crst') then settings.coins_stats = {}; save_settings() end
                  imgui.Separator()
                  local c_total_sum = 0
                  local c_list = {}
                  for k, v in pairs(settings.coins_stats or {}) do
                      c_total_sum = c_total_sum + v * (settings.coin_reward_amount or 10000)
                      table.insert(c_list, {nick=k, count=v})
                  end
                  table.sort(c_list, function(a,b) return a.count > b.count end)
                  imgui.TextDisabled(safe_u8('\xc8\xf2\xee\xe3\xee \xef\xf0\xe5\xec\xe8\xe9: ' .. c_total_sum .. '$'))
                  imgui.Separator()
                  if #c_list == 0 then
                      imgui.TextDisabled(u8'  \xcd\xe5\xf2 \xe4\xe0\xed\xed\xfb\xf5')
                  else
                      imgui.Columns(3, '##ccols', false)
                      imgui.SetColumnWidth(0, half_w * 0.45)
                      imgui.SetColumnWidth(1, half_w * 0.25)
                      imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xcd\xe8\xea'); imgui.NextColumn()
                      imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd0\xe0\xe7.'); imgui.NextColumn()
                      imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd1\xf3\xec\xec\xe0'); imgui.NextColumn()
                      imgui.Separator()
                      for _, row in ipairs(c_list) do
                          local sum = row.count * (settings.coin_reward_amount or 10000)
                          imgui.Text(safe_u8(' '..row.nick)); imgui.NextColumn()
                          imgui.Text(safe_u8(' '..row.count)); imgui.NextColumn()
                          imgui.Text(safe_u8(' '..sum..'$')); imgui.NextColumn()
                      end
                      imgui.Columns(1)
                  end
                  imgui.EndChild()
              end

              imgui.Spacing()
              imgui.Separator()
              imgui.Spacing()

              local full_w = imgui.GetWindowContentRegionWidth()
              if imgui.BeginChild('##t_panel', imgui.ImVec2(full_w, pr_panels_h), true) then
                  fh_touch_scroll('##t_panel')
                  imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), fa_icon.TICKET .. '  ' .. u8'\xd2\xe0\xeb\xee\xed\xfb (\xee\xe1\xec\xe5\xed \xed\xe0 \xf0\xe5\xef\xf3\xf2\xe0\xf6\xe8\xfe)')
                  imgui.SameLine()
                  if imgui.SmallButton(fa_icon.ROTATE_LEFT .. '##trst') then settings.talons_stats = {}; save_settings() end
                  imgui.Separator()
                  local t_total_sum = 0
                  local t_list = {}
                  for k, v in pairs(settings.talons_stats or {}) do
                      t_total_sum = t_total_sum + v * (settings.talon_reward_amount or 30000)
                      table.insert(t_list, {nick=k, count=v})
                  end
                  table.sort(t_list, function(a,b) return a.count > b.count end)
                  imgui.TextDisabled(safe_u8('\xc8\xf2\xee\xe3\xee \xef\xf0\xe5\xec\xe8\xe9: ' .. t_total_sum .. '$  |  30 000$ \xe7\xe0 \xea\xe0\xe6\xe4\xfb\xe9 \xf2\xe0\xeb\xee\xed'))
                  imgui.Separator()
                  if #t_list == 0 then
                      imgui.TextDisabled(u8'  \xcd\xe5\xf2 \xe4\xe0\xed\xed\xfb\xf5 \x97 \xf2\xe0\xeb\xee\xed\xfb \xe5\xf9\xb8 \xed\xe5 \xee\xe1\xec\xe5\xed\xe8\xe2\xe0\xeb\xe8\xf1\xfc')
                  else
                      local col_w = full_w / 3
                      imgui.Columns(3, '##tcols', false)
                      imgui.SetColumnWidth(0, col_w * 1.4)
                      imgui.SetColumnWidth(1, col_w * 0.8)
                      imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xcd\xe8\xea'); imgui.NextColumn()
                      imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd2\xe0\xeb\xee\xed\xee\xe2'); imgui.NextColumn()
                      imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd1\xf3\xec\xec\xe0'); imgui.NextColumn()
                      imgui.Separator()
                      for _, row in ipairs(t_list) do
                          local sum = row.count * (settings.talon_reward_amount or 30000)
                          imgui.Text(safe_u8(' '..row.nick)); imgui.NextColumn()
                          imgui.Text(safe_u8(' '..row.count)); imgui.NextColumn()
                          imgui.Text(safe_u8(' '..sum..'$')); imgui.NextColumn()
                      end
                      imgui.Columns(1)
                  end
                  imgui.EndChild()
              end

              imgui.Spacing()
              imgui.Separator()
              imgui.Spacing()

              imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), fa_icon.PAPER_PLANE .. '  ' .. u8'\xce\xf2\xef\xf0\xe0\xe2\xe8\xf2\xfc \xe2 Telegram:')
              imgui.SameLine(0, 12*d)

              local btn_w3 = (imgui.GetWindowContentRegionWidth() - imgui.GetCursorPosX() + 8*d) / 3 - 4*d

              imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.10,0.30,0.15,1))
              imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.13,0.40,0.20,1))
              if imgui.Button(fa_icon.LIST_CHECK .. '  ' .. u8'\xca\xe2\xe5\xf1\xf2\xfb ##pr_tg_q', imgui.ImVec2(btn_w3, 26*d)) then
                  local q_list = {}
                  local q_total = 0
                  for k, v in pairs(settings.quests_stats or {}) do
                      local sum = v * (settings.quest_reward_amount or 1000000)
                      table.insert(q_list, {nick=k, count=v, sum=sum})
                      q_total = q_total + sum
                  end
                  table.sort(q_list, function(a,b) return a.count > b.count end)
                  local lines = {
                      '[FH] \xcf\xf0\xe5\xec\xe8\xe8 \x97 \xca\xe2\xe5\xf1\xf2\xfb',
                      string.rep('-', 25),
                  }
                  if #q_list == 0 then
                      table.insert(lines, '\xcd\xe5\xf2 \xe4\xe0\xed\xed\xfb\xf5')
                  else
                      for i, r in ipairs(q_list) do
                          local marker_q = r.nick == (my_nick()) and '' or ' (\xed\xe5 \xf2\xee\xf7\xed\xee)'
                      table.insert(lines, i..'. '..r.nick..' \x97 '..r.count..' \xea\xe2. ('..r.sum..'$)'..marker_q)
                      end
                      table.insert(lines, string.rep('-', 25))
                      table.insert(lines, '\xc8\xf2\xee\xe3\xee: '..q_total..'$  |  '..
                          (settings.quest_reward_amount or 1000000)..'$ \xe7\xe0 \xea\xe2\xe5\xf1\xf2')
                  end
                  tg_send(table.concat(lines, '\n'))
                  sampAddChatMessage('[Family Helper] {00cc00}\xce\xf2\xf7\xb8\xf2 \xef\xee \xea\xe2\xe5\xf1\xf2\xe0\xec \xee\xf2\xef\xf0\xe0\xe2\xeb\xe5\xed \xe2 \xd2\xc3!', 0xFFFFFF)
              end
              imgui.PopStyleColor(2)
              imgui.SameLine(0, 4*d)

              imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.30,0.20,0.05,1))
              imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.40,0.28,0.07,1))
              if imgui.Button(fa_icon.COINS .. '  ' .. u8'\xcc\xee\xed\xe5\xf2\xfb ##pr_tg_c', imgui.ImVec2(btn_w3, 26*d)) then
                  local c_list = {}
                  local c_total = 0
                  for k, v in pairs(settings.coins_stats or {}) do
                      local sum = v * (settings.coin_reward_amount or 10000)
                      table.insert(c_list, {nick=k, count=v, sum=sum})
                      c_total = c_total + sum
                  end
                  table.sort(c_list, function(a,b) return a.count > b.count end)
                  local lines = {
                      '[FH] \xcf\xf0\xe5\xec\xe8\xe8 \x97 \xcc\xee\xed\xe5\xf2\xfb',
                      string.rep('-', 25),
                  }
                  if #c_list == 0 then
                      table.insert(lines, '\xcd\xe5\xf2 \xe4\xe0\xed\xed\xfb\xf5')
                  else
                      for i, r in ipairs(c_list) do
                          local marker_c = r.nick == (my_nick()) and '' or ' (\xed\xe5 \xf2\xee\xf7\xed\xee)'
                      table.insert(lines, i..'. '..r.nick..' \x97 '..r.count..' \xf0\xe0\xe7 ('..r.sum..'$)'..marker_c)
                      end
                      table.insert(lines, string.rep('-', 25))
                      table.insert(lines, '\xc8\xf2\xee\xe3\xee: '..c_total..'$  |  '..
                          (settings.coin_reward_amount or 10000)..'$ \xe7\xe0 \xec\xee\xed\xe5\xf2\xf3')
                  end
                  tg_send(table.concat(lines, '\n'))
                  sampAddChatMessage('[Family Helper] {00cc00}\xce\xf2\xf7\xb8\xf2 \xef\xee \xec\xee\xed\xe5\xf2\xe0\xec \xee\xf2\xef\xf0\xe0\xe2\xeb\xe5\xed \xe2 \xd2\xc3!', 0xFFFFFF)
              end
              imgui.PopStyleColor(2)
              imgui.SameLine(0, 4*d)

              imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.10,0.15,0.35,1))
              imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.14,0.20,0.48,1))
              if imgui.Button(fa_icon.TICKET .. '  ' .. u8'\xd2\xe0\xeb\xee\xed\xfb ##pr_tg_t', imgui.ImVec2(btn_w3, 26*d)) then
                  local t_list = {}
                  local t_total = 0
                  for k, v in pairs(settings.talons_stats or {}) do
                      local sum = v * (settings.talon_reward_amount or 30000)
                      table.insert(t_list, {nick=k, count=v, sum=sum})
                      t_total = t_total + sum
                  end
                  table.sort(t_list, function(a,b) return a.count > b.count end)
                  local lines = {
                      '[FH] \xcf\xf0\xe5\xec\xe8\xe8 \x97 \xd2\xe0\xeb\xee\xed\xfb',
                      string.rep('-', 25),
                  }
                  if #t_list == 0 then
                      table.insert(lines, '\xcd\xe5\xf2 \xe4\xe0\xed\xed\xfb\xf5')
                  else
                      for i, r in ipairs(t_list) do
                          local marker_t = r.nick == (my_nick()) and '' or ' (\xed\xe5 \xf2\xee\xf7\xed\xee)'
                      table.insert(lines, i..'. '..r.nick..' \x97 '..r.count..' \xf2\xe0\xeb. ('..r.sum..'$)'..marker_t)
                      end
                      table.insert(lines, string.rep('-', 25))
                      table.insert(lines, '\xc8\xf2\xee\xe3\xee: '..t_total..'$  |  '..
                          (settings.talon_reward_amount or 30000)..'$ \xe7\xe0 \xf2\xe0\xeb\xee\xed')
                  end
                  tg_send(table.concat(lines, '\n'))
                  sampAddChatMessage('[Family Helper] {00cc00}\xce\xf2\xf7\xb8\xf2 \xef\xee \xf2\xe0\xeb\xee\xed\xe0\xec \xee\xf2\xef\xf0\xe0\xe2\xeb\xe5\xed \xe2 \xd2\xc3!', 0xFFFFFF)
              end
              imgui.PopStyleColor(2)

              imgui.Spacing()

              imgui.EndChild()
          end
end

local function fh_render_tab6()
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
          local inv_total_h = imgui.GetContentRegionAvail().y
          if imgui.BeginChild('##inv_wrap', imgui.ImVec2(-1, inv_total_h), false) then
              fh_touch_scroll('##inv_wrap')
              local ar4=settings.interface.accent_r or 1
              local ag4=settings.interface.accent_g or .65
              local ab4=settings.interface.accent_b or 0
              local unpaid = settings.general.invite_unpaid or 0
              local price_n = settings.general.invite_price_normal or 2000000
              local price_b = settings.general.invite_price_bonus or 4000000
              local thresh  = settings.general.invite_bonus_threshold or 50
              local pay_sum = unpaid * (unpaid >= thresh and price_b or price_n)
              local total_paid = settings.general.total_paid_amount or 0

              imgui.TextColored(imgui.ImVec4(ar4,ag4,ab4,1), fa_icon.USER_PLUS .. '  ' .. u8'\xd1\xf2\xe0\xf2\xe8\xf1\xf2\xe8\xea\xe0 \xe8\xed\xe2\xe0\xe9\xf2\xee\xe2:')
              imgui.PushTextWrapPos(0)
              imgui.TextDisabled(safe_u8('\xcd\xe5\xee\xef\xeb\xe0\xf7\xe5\xed\xed\xfb\xf5: ' .. unpaid .. '   \xd1\xf3\xec\xec\xe0: ' .. pay_sum .. '$   \xc2\xf1\xe5\xe3\xee \xe7\xe0\xf0\xe0\xe1\xee\xf2\xe0\xed\xee: ' .. total_paid .. '$'))
              imgui.PopTextWrapPos()
              imgui.Separator()

              fh_labeled_inputs_row({
                  {label=u8'\xd6\xe5\xed\xe0 \xe7\xe0 \xe8\xed\xe2\xe0\xe9\xf2', id='ipn', buf=invite_price_normal_input, value=settings.general.invite_price_normal or 2000000},
                  {label=u8'\xd6\xe5\xed\xe0 \xe1\xee\xed\xf3\xf1', id='ipb', buf=invite_price_bonus_input, value=settings.general.invite_price_bonus or 4000000},
                  {label=u8'\xcf\xee\xf0\xee\xe3 \xe1\xee\xed\xf3\xf1\xe0', id='ipt', buf=invite_bonus_thresh_input, value=settings.general.invite_bonus_threshold or 50},
              }, function(idx, val)
                  if idx == 1 then settings.general.invite_price_normal = math.max(0, val)
                  elseif idx == 2 then settings.general.invite_price_bonus = math.max(0, val)
                  elseif idx == 3 then settings.general.invite_bonus_threshold = math.max(1, val) end
                  save_settings()
              end)

              if unpaid > 0 then
                  if imgui.Button(fa_icon.CIRCLE_DOLLAR_TO_SLOT .. '  ' .. safe_u8(' \xc2\xfb\xef\xeb\xe0\xf7\xe5\xed\xee (' .. pay_sum .. '$) '), imgui.ImVec2(-1, 26*d)) then
                      if not settings.invite_history then settings.invite_history = {} end
                      table.insert(settings.invite_history, 1, {
                          date = os.date('%d.%m.%Y %H:%M'),
                          invites = unpaid,
                          amount = pay_sum
                      })
                      settings.general.total_paid_amount = (settings.general.total_paid_amount or 0) + pay_sum
                      settings.general.invite_unpaid = 0
                      save_settings()
                      log_event('\xc2\xfb\xef\xeb\xe0\xf7\xe5\xed\xee: ' .. pay_sum .. '$ \xe7\xe0 ' .. unpaid .. ' \xe8\xed\xe2')
                  end
              else
                  imgui.TextDisabled(u8'  \xcd\xe5\xf2 \xed\xe5\xee\xef\xeb\xe0\xf7\xe5\xed\xed\xfb\xf5 \xe8\xed\xe2\xe0\xe9\xf2\xee\xe2')
              end
              imgui.Spacing()

              imgui.TextColored(imgui.ImVec4(ar4,ag4,ab4,1), fa_icon.CLOCK_ROTATE_LEFT .. '  ' .. safe_u8(' \xc8\xf1\xf2\xee\xf0\xe8\xff \xe2\xfb\xef\xeb\xe0\xf2 (\xe2\xf1\xe5\xe3\xee \xe7\xe0\xf0\xe0\xe1\xee\xf2\xe0\xed\xee: ' .. total_paid .. '$)'))
              if imgui.BeginChild('##inv_hist', imgui.ImVec2(-1, 120*d), true) then
                  fh_touch_scroll('##inv_hist')
                  local hist = settings.invite_history or {}
                  if #hist == 0 then
                      imgui.TextDisabled(u8'  \xcd\xe5\xf2 \xe7\xe0\xef\xe8\xf1\xe5\xe9')
                  else
                      imgui.Columns(3, '##inv_hist_cols', false)
                      imgui.SetColumnWidth(0, 160*d)
                      imgui.SetColumnWidth(1, 80*d)
                      imgui.TextColored(imgui.ImVec4(ar4,ag4,ab4,1), u8' \xc4\xe0\xf2\xe0'); imgui.NextColumn()
                      imgui.TextColored(imgui.ImVec4(ar4,ag4,ab4,1), u8' \xc8\xed\xe2.'); imgui.NextColumn()
                      imgui.TextColored(imgui.ImVec4(ar4,ag4,ab4,1), u8' \xd1\xf3\xec\xec\xe0'); imgui.NextColumn()
                      imgui.Separator()
                      for _, h in ipairs(hist) do
                          imgui.Text(safe_u8('  ' .. (h.date or ''))); imgui.NextColumn()
                          imgui.Text(safe_u8('  ' .. (h.invites or 0))); imgui.NextColumn()
                          imgui.Text(safe_u8('  ' .. (h.amount or 0) .. '$')); imgui.NextColumn()
                      end
                      imgui.Columns(1)
                  end
                  imgui.EndChild()
              end
              imgui.Spacing()

              imgui.TextColored(imgui.ImVec4(ar4,ag4,ab4,1), fa_icon.CHART_COLUMN .. '  ' .. u8'\xd1\xf2\xe0\xf2\xe8\xf1\xf2\xe8\xea\xe0 \xe8\xed\xe2\xe0\xe9\xf2\xee\xe2 \xef\xee \xe8\xe3\xf0\xee\xea\xe0\xec')
              imgui.SameLine(0, 12*d)

              imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.10,0.30,0.10,1))
              imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.14,0.42,0.14,1))
              if imgui.SmallButton(fa_icon.PAPER_PLANE .. u8'  \xce\xf2\xef\xf0\xe0\xe2\xe8\xf2\xfc \xe2 \xd2\xc3  ##invtg_mine') then
                  local stats2    = settings.invite_stats or {}
                  local self_nick = my_nick()
                  local self_s    = stats2[self_nick] or {}
                  local lines = {
                      '[FH] \xcc\xee\xe8 \xe8\xed\xe2\xe0\xe9\xf2\xfb \x97 ' .. self_nick,
                      string.rep('-', 25),
                      '\xd1\xe5\xe3\xee\xe4\xed\xff:   ' .. (self_s.today or 0),
                      '\xcd\xe5\xe4\xe5\xeb\xff:    ' .. (self_s.week  or 0),
                      '\xcc\xe5\xf1\xff\xf6:     ' .. (self_s.month or 0),
                      '\xc2\xf1\xb8 \xe2\xf0\xe5\xec\xff: ' .. (self_s.total or 0),
                  }
                  tg_send(table.concat(lines, '\n'))
                  sampAddChatMessage('[Family Helper] {00cc00}\xcc\xee\xe8 \xe8\xed\xe2\xe0\xe9\xf2\xfb \xee\xf2\xef\xf0\xe0\xe2\xeb\xe5\xed\xfb \xe2 \xd2\xc3!', 0xFFFFFF)
              end
              imgui.PopStyleColor(2)

              if not _G.inv_sort then _G.inv_sort = 'total' end
              local st_list = {}
              local stats = settings.invite_stats or {}
              for nick, s in pairs(stats) do
                  local dk = os.date('%d.%m.%Y')
                  local wk = os.date('%V.%G')
                  local mk = os.date('%m.%Y')
                  if s.day_key   ~= dk then s.today = 0; s.day_key   = dk end
                  if s.week_key  ~= wk then s.week  = 0; s.week_key  = wk end
                  if s.month_key ~= mk then s.month = 0; s.month_key = mk end
                  table.insert(st_list, {nick=nick, s=s})
              end
              table.sort(st_list, function(a, b)
                  return (a.s[_G.inv_sort] or 0) > (b.s[_G.inv_sort] or 0)
              end)
              if imgui.BeginChild('##inv_stats', imgui.ImVec2(-1, -1), true) then
                  fh_touch_scroll('##inv_stats')
                  local cw1 = 180*d
                  local cw2 = (imgui.GetWindowContentRegionWidth() - cw1) / 4
                  imgui.Columns(5, 'inv_stats_cols', true)
                  imgui.SetColumnWidth(0, cw1)
                  imgui.SetColumnWidth(1, cw2)
                  imgui.SetColumnWidth(2, cw2)
                  imgui.SetColumnWidth(3, cw2)
                  imgui.SetColumnWidth(4, cw2)
                  imgui.Text(u8' \xc8\xe3\xf0\xee\xea'); imgui.NextColumn()
                  local sorts = {{'today','\xd1\xe5\xe3\xee\xe4\xed\xff'},{'week','\xcd\xe5\xe4\xe5\xeb\xff'},{'month','\xcc\xe5\xf1\xff\xf6'},{'total','\xc2\xf1\xe5\xe3\xee'}}
                  for _, sv in ipairs(sorts) do
                      local active = _G.inv_sort == sv[1]
                      if active then imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(ar4*0.6,ag4*0.6,ab4*0.6+0.3,1)) end
                      if imgui.Button(safe_u8(sv[2]..(active and ' v' or '')..'##isort_'..sv[1]), imgui.ImVec2(-1,0)) then
                          _G.inv_sort = sv[1]
                      end
                      if active then imgui.PopStyleColor() end
                      imgui.NextColumn()
                  end
                  imgui.Separator()
                  if #st_list == 0 then
                      imgui.Text(u8'  \xcd\xe5\xf2 \xe4\xe0\xed\xed\xfb\xf5.')
                      imgui.NextColumn(); imgui.NextColumn(); imgui.NextColumn(); imgui.NextColumn()
                  end
                  for ri, item in ipairs(st_list) do
                      local s = item.s
                      local row_color = ri % 2 == 0 and imgui.ImVec4(1,1,1,0.6) or imgui.ImVec4(1,1,1,1)
                      imgui.TextColored(row_color, safe_u8(' '..item.nick)); imgui.NextColumn()
                      imgui.TextColored(row_color, safe_u8(' '..(s.today or 0))); imgui.NextColumn()
                      imgui.TextColored(row_color, safe_u8(' '..(s.week  or 0))); imgui.NextColumn()
                      imgui.TextColored(row_color, safe_u8(' '..(s.month or 0))); imgui.NextColumn()
                      imgui.TextColored(row_color, safe_u8(' '..(s.total or 0))); imgui.NextColumn()
                  end
                  imgui.Columns(1)
                  imgui.EndChild()
              end
              imgui.Spacing()
              imgui.Separator()
              imgui.Spacing()

              imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.35,0.08,0.08,1))
              imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.55,0.12,0.12,1))
              if imgui.Button(fa_icon.TRASH .. '  ' .. u8'\xd1\xe1\xf0\xee\xf1\xe8\xf2\xfc \xe2\xf1\xfe \xf1\xf2\xe0\xf2\xe8\xf1\xf2\xe8\xea\xf3 \xe8\xed\xe2\xe0\xe9\xf2\xee\xe2  ##invst_reset', imgui.ImVec2(-1, 22*d)) then
                  settings.invite_stats = {}; save_settings()
                  sampAddChatMessage('[Family Helper] {ff4444}\xd1\xf2\xe0\xf2\xe8\xf1\xf2\xe8\xea\xe0 \xe8\xed\xe2\xe0\xe9\xf2\xee\xe2 \xf1\xe1\xf0\xee\xf8\xe5\xed\xe0.', 0xFFFFFF)
              end
              imgui.PopStyleColor(2)
              imgui.EndChild()
          end
end

local function fh_render_tab7()
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
            local log_h = imgui.GetContentRegionAvail().y
            if imgui.BeginChild('##log_wrap', imgui.ImVec2(-1, log_h), false) then
                fh_touch_scroll('##log_wrap')
                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xcb\xee\xe3 \xf1\xee\xe1\xfb\xf2\xe8\xe9 \xf1\xe5\xec\xfc\xe8')
                imgui.Separator()
                if not _G.log_tab then _G.log_tab = 1 end
                if not settings.log_enabled then settings.log_enabled = {bank=true,coins=true,mute=true,invite=true,level=true,quest=true,rank=true} end
                local log_cats = {
                    {1, '\xcd\xee\xe2\xee\xf1\xf2\xe8', 'news',   fa_icon.NEWSPAPER},
                    {2, '\xd7\xe0\xf2',     'chat',   fa_icon.COMMENTS},
                    {3, '\xd1\xea\xeb\xe0\xe4 $', 'bank',   fa_icon.VAULT},
                    {4, '\xcc\xee\xed\xe5\xf2\xfb',  'coins',  fa_icon.COINS},
                    {5, '\xcc\xf3\xf2\xfb',    'mute',   fa_icon.MICROPHONE_SLASH},
                    {6, '\xd1\xee\xf1\xf2\xe0\xe2',  'invite', fa_icon.USER_PLUS},
                    {7, '\xd3\xf0\xee\xe2\xed\xe8',  'level',  fa_icon.CHART_LINE},
                    {8, '\xca\xe2\xe5\xf1\xf2\xfb',  'quest',  fa_icon.LIST_CHECK},
                    {9, '\xd0\xe0\xed\xe3\xe8',   'rank',   fa_icon.CROWN},
                }

                local half = math.ceil(#log_cats / 2)
                local full_w = imgui.GetWindowContentRegionWidth()
                local btn_h = 24*d
                local chip_h = btn_h + 10*d

                imgui.TextDisabled(u8' \xcb\xee\xe3\xe8\xf0\xee\xe2\xe0\xf2\xfc:')
                imgui.Spacing()
                for li, cat in ipairs(log_cats) do
                    if li > 1 and (li-1) % half ~= 0 then imgui.SameLine(0, 6*d) end
                    local bw = (full_w - (half-1)*6*d) / half
                    local enabled = settings.log_enabled[cat[3]]
                    imgui.PushStyleColor(imgui.Col.ChildBg, enabled and imgui.ImVec4(ar*0.18,ag*0.18,ab*0.18,1) or imgui.ImVec4(0.10,0.10,0.12,1))
                    if imgui.BeginChild('##lchip'..li, imgui.ImVec2(bw, chip_h), true, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse) then
                        imgui.SetCursorPosY((chip_h - 16*d)/2)
                        imgui.TextColored(enabled and imgui.ImVec4(ar,ag,ab,1) or imgui.ImVec4(0.5,0.5,0.5,1), cat[4])
                        imgui.SameLine(0, 4*d)
                        imgui.SetCursorPosY((chip_h - 16*d)/2)
                        imgui.TextColored(enabled and imgui.ImVec4(0.92,0.92,0.92,1) or imgui.ImVec4(0.5,0.5,0.5,1), safe_u8(cat[2]))
                        local chip_w = imgui.GetWindowContentRegionWidth()
                        imgui.SameLine(chip_w - 40*d - 8*d)
                        imgui.SetCursorPosY((chip_h - 22*d)/2)
                        if fh_toggle('##ltog'..li, enabled, 40*d, 22*d) then
                            settings.log_enabled[cat[3]] = not enabled; save_settings()
                        end
                    end
                    imgui.EndChild()
                    imgui.PopStyleColor()
                end
                imgui.Spacing()

                imgui.TextDisabled(u8' \xcf\xf0\xee\xf1\xec\xee\xf2\xf0:')
                imgui.Spacing()
                local view_cols = half + 1
                local vbw = (full_w - (view_cols-1)*6*d) / view_cols
                for li, cat in ipairs(log_cats) do
                    if li > 1 and (li-1) % half ~= 0 then imgui.SameLine(0, 6*d) end
                    local active = _G.log_tab == cat[1]
                    if active then
                        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(ar*0.55,ag*0.55,ab*0.55,1))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered,  imgui.ImVec4(ar*0.65,ag*0.65,ab*0.65,1))
                    else
                        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.15,0.15,0.18,1))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered,  imgui.ImVec4(0.22,0.22,0.26,1))
                    end
                    local cnt = #famlog[cat[3]]
                    local vlabel = cat[4] .. '  ' .. safe_u8(cat[2] .. (cnt>0 and (' '..cnt) or ''))
                    if imgui.Button(vlabel .. '##lcat'..li, imgui.ImVec2(vbw, btn_h)) then
                        _G.log_tab = cat[1]; _G.log_page = 1
                    end
                    imgui.PopStyleColor(2)

                    if li == half then
                        imgui.SameLine(0, 6*d)
                        local active_all = _G.log_tab == 0
                        if active_all then
                            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(ar*0.55,ag*0.55,ab*0.55,1))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered,  imgui.ImVec4(ar*0.65,ag*0.65,ab*0.65,1))
                        else
                            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.15,0.15,0.18,1))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered,  imgui.ImVec4(0.22,0.22,0.26,1))
                        end
                        if imgui.Button(fa_icon.LAYER_GROUP .. '  ' .. u8'\xc2\xf1\xe5##logall', imgui.ImVec2(vbw, btn_h)) then _G.log_tab = 0; _G.log_page = 1 end
                        imgui.PopStyleColor(2)
                    end
                end
                imgui.SameLine(0, 6*d)
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.38, 0.10, 0.10, 1))
                imgui.PushStyleColor(imgui.Col.ButtonHovered,  imgui.ImVec4(0.48, 0.12, 0.12, 1))
                imgui.PushStyleColor(imgui.Col.ButtonActive,   imgui.ImVec4(0.30, 0.08, 0.08, 1))
                if imgui.Button(fa_icon.TRASH .. '##logclear', imgui.ImVec2(btn_h, btn_h)) then
                    for _, cat in ipairs(log_cats) do famlog[cat[3]] = {} end
                    lua_thread.create(function() save_log() end)
                end
                imgui.PopStyleColor(3)
                imgui.Separator(); imgui.Spacing()

                local function fmt_entry(e, cat_key)
                    local line = '[' .. (e.date or '') .. ' ' .. (e.time or '') .. '] '
                    if cat_key == 'news' then

                        local nick = e.nick or ''
                        local msg  = e.msg  or ''
                        if msg:find('\xf1\xe0\xec\xee\xf1\xf2\xee\xff\xf2\xe5\xeb\xfc\xed\xee \xef\xee\xea\xe8\xed\xf3\xeb') then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xf1\xe0\xec\xee\xf1\xf2\xee\xff\xf2\xe5\xeb\xfc\xed\xee \xef\xee\xea\xe8\xed\xf3\xeb \xf1\xe5\xec\xfc\xfe!'
                        elseif msg:find('\xe2\xf1\xf2\xf3\xef\xe8\xeb \xe2 \xf1\xe5\xec\xfc\xfe') then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xe2\xf1\xf2\xf3\xef\xe8\xeb \xe2 \xf1\xe5\xec\xfc\xfe.'
                        elseif msg:find('\xef\xf0\xe8\xe3\xeb\xe0\xf1\xe8\xeb ') then
                            local inv = msg:match('\xef\xf0\xe8\xe3\xeb\xe0\xf1\xe8\xeb (.+)')
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xef\xf0\xe8\xe3\xeb\xe0\xf1\xe8\xeb \xe8\xe3\xf0\xee\xea\xe0 ' .. (inv or '?') .. ' \xe2 \xf1\xe5\xec\xfc\xfe.'
                        elseif msg:find('\xea\xe8\xea\xed\xf3\xeb ') then
                            local kicked = msg:match('\xea\xe8\xea\xed\xf3\xeb (.+) \xe8\xe7 \xf1\xe5\xec\xfc\xe8')
                            if msg:find('\xee\xf4\xf4\xeb\xe0\xe9\xed') then
                                line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xe2 \xee\xf4\xf4\xeb\xe0\xe9\xed\xe5 \xe2\xfb\xe3\xed\xe0\xeb \xe8\xe3\xf0\xee\xea\xe0 ' .. (kicked or '?') .. ' \xe8\xe7 \xf1\xe5\xec\xfc\xe8!'
                            else
                                line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xe2\xfb\xe3\xed\xe0\xeb \xe8\xe3\xf0\xee\xea\xe0 ' .. (kicked or '?') .. ' \xe8\xe7 \xf1\xe5\xec\xfc\xe8!'
                            end
                        elseif msg:find('\xec\xf3\xf2 ') then
                            local muted = msg:match('\xec\xf3\xf2 (.+) \xed\xe0')
                            local dur   = msg:match('\xed\xe0 (%d+)\xec\xe8\xed')
                            local reas  = msg:match(': (.+)')
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xe2\xfb\xe4\xe0\xeb \xec\xf3\xf2 \xe8\xe3\xf0\xee\xea\xf3 ' .. (muted or '?') .. ' \xed\xe0 ' .. (dur or '?') .. ' \xec\xe8\xed.' .. (reas and (' \xcf\xf0\xe8\xf7\xe8\xed\xe0: ' .. reas) or '')
                        elseif msg:find('\xe4\xee\xf1\xf2\xe8\xe3 ') then
                            local lvl = msg:match('\xe4\xee\xf1\xf2\xe8\xe3 (%d+) \xf3\xf0\xee\xe2\xed\xff')
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xe4\xee\xf1\xf2\xe8\xe3 ' .. (lvl or '?') .. ' \xf3\xf0\xee\xe2\xed\xff.'
                        elseif msg:find('\xf3\xf0\xee\xe2\xe5\xed\xfc') or msg:find('\xf3\xf0\xee\xe2\xed\xff') then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xef\xee\xe4\xed\xff\xeb \xf3\xf0\xee\xe2\xe5\xed\xfc.'
                        elseif msg:find('\xe2\xfb\xef\xee\xeb\xed\xe8\xeb \xea\xe2\xe5\xf1\xf2') or msg:find('\xea\xe2\xe5\xf1\xf2') then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xe2\xfb\xef\xee\xeb\xed\xe8\xeb \xf1\xe5\xec\xe5\xe9\xed\xfb\xe9 \xea\xe2\xe5\xf1\xf2.'
                        elseif msg:find('\xcf\xee\xef\xee\xeb\xed\xe8\xeb \xf1\xea\xeb\xe0\xe4') or msg:find('\xcf\xee\xef\xee\xeb') then
                            local sum = msg:match('%$(.+)')
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xef\xee\xef\xee\xeb\xed\xe8\xeb \xf1\xea\xeb\xe0\xe4 \xf1\xe5\xec\xfc\xe8 \xed\xe0 $' .. (sum or '?') .. '.'
                        elseif msg:find('\xc2\xe7\xff\xeb') or msg:find('\xe2\xe7\xff\xeb') then
                            local sum = msg:match('%$(.+)')
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xf1\xed\xff\xeb \xf1\xee \xf1\xea\xeb\xe0\xe4\xe0 \xf1\xe5\xec\xfc\xe8 $' .. (sum or '?') .. '.'
                        elseif msg:find('\xed\xe0\xe7\xed\xe0\xf7\xe5\xed \xe7\xe0\xec\xe5\xf1\xf2\xe8\xf2\xe5\xeb\xe5\xec') then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xed\xe0\xe7\xed\xe0\xf7\xe8\xeb ' .. (msg:match('(.+) \xed\xe0\xe7\xed\xe0\xf7\xe5\xed') or '?') .. ' \xe7\xe0\xec\xe5\xf1\xf2\xe8\xf2\xe5\xeb\xe5\xec!'
                        elseif msg:find('\xf1\xed\xff\xf2 \xf1 \xef\xee\xf1\xf2\xe0 \xe7\xe0\xec\xe0') then
                            local zam = msg:match('(.+) \xf1\xed\xff\xf2 \xf1 \xef\xee\xf1\xf2\xe0 \xe7\xe0\xec\xe0')
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xf1\xed\xff\xeb ' .. (zam or '?') .. ' \xf1 \xef\xee\xf1\xf2\xe0 \xe7\xe0\xec\xe5\xf1\xf2\xe8\xf2\xe5\xeb\xff!'
                        elseif msg:find('\xf0\xe0\xed\xe3 ') then
                            local rn = msg:match('\xf0\xe0\xed\xe3 (%d+) %->') or msg:match('\xf0\xe0\xed\xe3 (%d+)')
                            local tgt = msg:match('-> (.+)')
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xf3\xf1\xf2\xe0\xed\xee\xe2\xe8\xeb \xf0\xe0\xed\xe3 ' .. (rn or '?') .. (tgt and (' \xe8\xe3\xf0\xee\xea\xf3 ' .. tgt) or '') .. '.'
                        elseif msg:find('\xee\xe1\xec\xe5\xed\xff\xeb') and msg:find('\xf2\xe0\xeb\xee\xed') then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' ' .. msg .. '.'
                        elseif msg:find('\xf1\xe5\xf0\xf2\xe8\xf4\xe8\xea\xe0\xf2') then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xe8\xf1\xef\xee\xeb\xfc\xe7\xee\xe2\xe0\xeb \xf1\xe5\xf0\xf2\xe8\xf4\xe8\xea\xe0\xf2 \xf0\xe5\xef\xf3\xf2\xe0\xf6\xe8\xe8.'
                        else
                            line = line .. (nick ~= '' and ('\xc8\xe3\xf0\xee\xea ' .. nick .. ': ') or '') .. msg
                        end
                    elseif cat_key == 'chat' then
                        line = line .. '[\xd7\xe0\xf2 \xf1\xe5\xec\xfc\xe8] ' .. (e.nick or '?') .. ': ' .. (e.msg or '')
                    elseif cat_key == 'bank' then
                        if (e.op or '') == '\xcf\xee\xef\xee\xeb\xed\xe8\xeb' then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. (e.nick or '?') .. ' \xef\xee\xef\xee\xeb\xed\xe8\xeb \xf1\xea\xeb\xe0\xe4 \xf1\xe5\xec\xfc\xe8 \xed\xe0 $' .. (e.sum or '?') .. '.'
                        else
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. (e.nick or '?') .. ' \xf1\xed\xff\xeb \xf1\xee \xf1\xea\xeb\xe0\xe4\xe0 \xf1\xe5\xec\xfc\xe8 $' .. (e.sum or '?') .. '.'
                        end
                    elseif cat_key == 'coins' then
                        local msg = e.msg or ''
                        if msg:find('\xee\xe1\xec\xe5\xed\xff\xeb') and msg:find('\xf2\xe0\xeb\xee\xed') then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. (e.nick or '?') .. ' ' .. msg .. '.'
                        else
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. (e.nick or '?') .. ' \xf1\xe4\xe0\xeb \xf1\xe5\xec\xe5\xe9\xed\xfb\xe5 \xec\xee\xed\xe5\xf2\xfb/\xf2\xe0\xeb\xee\xed\xfb.'
                        end
                    elseif cat_key == 'mute' then
                        line = line .. '\xc8\xe3\xf0\xee\xea ' .. (e.by or '?') .. ' \xe2\xfb\xe4\xe0\xeb \xec\xf3\xf2 \xe8\xe3\xf0\xee\xea\xf3 ' .. (e.nick or '?') .. ' \xed\xe0 ' .. (e.duration or '?') .. ' \xec\xe8\xed.'
                        if e.reason and e.reason ~= '' then line = line .. ' \xcf\xf0\xe8\xf7\xe8\xed\xe0: ' .. e.reason end
                    elseif cat_key == 'invite' then
                        local tp = e.type or '?'
                        local nick = e.nick or '?'
                        if tp == '\xc8\xed\xe2\xe0\xe9\xf2 \xef\xf0\xe8\xed\xff\xf2' or tp == '\xcf\xf0\xe8\xe3\xeb\xe0\xf8\xb8\xed' then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. (e.by ~= '' and e.by or '?') .. ' \xef\xf0\xe8\xe3\xeb\xe0\xf1\xe8\xeb \xe8\xe3\xf0\xee\xea\xe0 ' .. nick .. ' \xe2 \xf1\xe5\xec\xfc\xfe.'
                        elseif tp == '\xc2\xf1\xf2\xf3\xef\xe8\xeb' then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xe2\xf1\xf2\xf3\xef\xe8\xeb \xe2 \xf1\xe5\xec\xfc\xfe.'
                        elseif tp == '\xcf\xee\xea\xe8\xed\xf3\xeb' then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. nick .. ' \xf1\xe0\xec\xee\xf1\xf2\xee\xff\xf2\xe5\xeb\xfc\xed\xee \xef\xee\xea\xe8\xed\xf3\xeb \xf1\xe5\xec\xfc\xfe!'
                        elseif tp == '\xca\xe8\xea' then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. (e.by ~= '' and e.by or '?') .. ' \xe2\xfb\xe3\xed\xe0\xeb \xe8\xe3\xf0\xee\xea\xe0 ' .. nick .. ' \xe8\xe7 \xf1\xe5\xec\xfc\xe8!'
                        else
                            line = line .. tp .. ': ' .. nick
                        end
                        if e.total then line = line .. ' (\xe2\xf1\xe5\xe3\xee \xe8\xed\xe2\xe0\xe9\xf2\xee\xe2: ' .. e.total .. ')' end
                    elseif cat_key == 'level' then
                        line = line .. '\xc8\xe3\xf0\xee\xea ' .. (e.nick or '?') .. ' \xe4\xee\xf1\xf2\xe8\xe3 ' .. (e.lvl and (e.lvl .. ' \xf3\xf0\xee\xe2\xed\xff') or '\xed\xee\xe2\xee\xe3\xee \xf3\xf0\xee\xe2\xed\xff') .. '.'
                    elseif cat_key == 'quest' then
                        line = line .. '\xc8\xe3\xf0\xee\xea ' .. (e.nick or '?') .. ' \xe2\xfb\xef\xee\xeb\xed\xe8\xeb \xf1\xe5\xec\xe5\xe9\xed\xfb\xe9 \xea\xe2\xe5\xf1\xf2.'
                    elseif cat_key == 'rank' then
                        local rk = e.rank or '?'
                        local who = e.nick or '?'
                        local by  = e.by or ''
                        if rk == '\xe7\xe0\xec' then
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. by .. ' \xed\xe0\xe7\xed\xe0\xf7\xe8\xeb ' .. who .. ' \xe7\xe0\xec\xe5\xf1\xf2\xe8\xf2\xe5\xeb\xe5\xec!'
                        else
                            line = line .. '\xc8\xe3\xf0\xee\xea ' .. (by ~= '' and by or '?') .. ' \xf3\xf1\xf2\xe0\xed\xee\xe2\xe8\xeb \xf0\xe0\xed\xe3 ' .. rk .. ' \xe8\xe3\xf0\xee\xea\xf3 ' .. who .. '.'
                        end
                    end
                    return line
                end

                if not _G.log_filter_buf then _G.log_filter_buf = imgui.new.char[128]() end
                local show_filter = (_G.log_tab == 0 or (log_cats[_G.log_tab] and (log_cats[_G.log_tab][3] == 'news' or log_cats[_G.log_tab][3] == 'chat')))
                if show_filter then
                    if not _G.log_qf then _G.log_qf = '' end

                    imgui.TextDisabled(fa_icon.MAGNIFYING_GLASS)
                    imgui.SameLine(0, 6*d)
                    imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.10,0.10,0.13,1))
                    imgui.PushItemWidth(full_w - 44*d)
                    if imgui.InputTextWithHint('##logflt', u8'\xcf\xee\xe8\xf1\xea...', _G.log_filter_buf, 128) then _G.log_page = 1 end
                    imgui.PopItemWidth()
                    imgui.PopStyleColor()
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.38, 0.10, 0.10, 1))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered,  imgui.ImVec4(0.48, 0.12, 0.12, 1))
                    imgui.PushStyleColor(imgui.Col.ButtonActive,   imgui.ImVec4(0.30, 0.08, 0.08, 1))
                    if imgui.Button(fa_icon.XMARK .. '##logfltcl', imgui.ImVec2(24*d, 0)) then
                        ffi.fill(_G.log_filter_buf, 128); _G.log_qf = ''
                    end
                    imgui.PopStyleColor(3)

                    local qfilters = {
                        {'', '\xc2\xf1\xe5', fa_icon.LAYER_GROUP},
                        {'\xf1\xea\xeb\xe0\xe4', '\xd1\xea\xeb\xe0\xe4', fa_icon.VAULT},
                        {'\xf2\xe0\xeb\xee\xed', '\xd2\xe0\xeb\xee\xed', fa_icon.TICKET},
                        {'\xf0\xe5\xef\xf3\xf2\xe0\xf6', '\xd0\xe5\xef\xe0', fa_icon.SEEDLING},
                        {'\xec\xf3\xf2', '\xcc\xf3\xf2', fa_icon.MICROPHONE_SLASH},
                        {'\xe2\xf1\xf2\xf3\xef', '\xc2\xf1\xf2\xf3\xef', fa_icon.USER_PLUS},
                        {'\xf3\xf0\xee\xe2\xed', '\xd3\xf0\xee\xe2\xe5\xed\xfc', fa_icon.CHART_LINE},
                    }
                    local qbw = (full_w - (#qfilters-1)*4*d) / #qfilters
                    for qi, qf in ipairs(qfilters) do
                        if qi > 1 then imgui.SameLine() end
                        local qactive = _G.log_qf == qf[1]
                        if qactive then
                            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(ar*0.55,ag*0.55,ab*0.55,1))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered,  imgui.ImVec4(ar*0.65,ag*0.65,ab*0.65,1))
                        else
                            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.15,0.15,0.18,1))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered,  imgui.ImVec4(0.22,0.22,0.26,1))
                        end
                        if imgui.Button(qf[3] .. '  ' .. safe_u8(qf[2]) .. '##qf'..qi, imgui.ImVec2(qbw, 20*d)) then
                            _G.log_qf = qf[1]; ffi.fill(_G.log_filter_buf, 128); _G.log_page = 1
                        end
                        imgui.PopStyleColor(2)
                    end
                    imgui.Spacing()
                end

                local filter_str = show_filter and u8:decode(ffi.string(_G.log_filter_buf)):lower() or ''
                if show_filter and _G.log_qf and _G.log_qf ~= '' and filter_str == '' then
                    filter_str = _G.log_qf
                end

                local show_entries = {}
                if _G.log_tab == 0 then
                    for _, cat in ipairs(log_cats) do
                        for _, e in ipairs(famlog[cat[3]]) do
                            table.insert(show_entries, {e=e, k=cat[3]})
                        end
                    end
                    table.sort(show_entries, function(a, b)
                        return ((a.e.date or '')  .. (a.e.time or '')) > ((b.e.date or '') .. (b.e.time or ''))
                    end)
                else
                    local cur_cat = log_cats[_G.log_tab]
                    if cur_cat then
                        for _, e in ipairs(famlog[cur_cat[3]]) do
                            table.insert(show_entries, {e=e, k=cur_cat[3]})
                        end

                        if cur_cat[3] == 'news' then
                            local qf = _G.log_qf or ''
                            if qf == 'ÏÛÚ' then
                                for _, e in ipairs(famlog['mute'] or {}) do
                                    table.insert(show_entries, {e=e, k='mute'})
                                end
                            elseif qf == '‚ÒÚÛÔ' then
                                for _, e in ipairs(famlog['invite'] or {}) do
                                    table.insert(show_entries, {e=e, k='invite'})
                                end
                            elseif qf == 'ÛÓ‚Ì' then
                                for _, e in ipairs(famlog['level'] or {}) do
                                    table.insert(show_entries, {e=e, k='level'})
                                end
                            end

                            table.sort(show_entries, function(a, b)
                                return ((a.e.date or '') .. (a.e.time or '')) > ((b.e.date or '') .. (b.e.time or ''))
                            end)
                        end
                    end
                end

                if filter_str ~= '' then
                    local filtered = {}
                    for _, item in ipairs(show_entries) do
                        local line = ((item.e.nick or '') .. ' ' .. (item.e.msg or '') .. ' ' ..
                                      (item.e.op or '') .. ' ' .. (item.e.sum or '') .. ' ' ..
                                      (item.e.reason or '') .. ' ' .. (item.e.type or '')):lower()
                        if line:find(filter_str, 1, true) then
                            table.insert(filtered, item)
                        end
                    end
                    show_entries = filtered
                end

                if #show_entries == 0 then
                    imgui.TextDisabled(u8'  \xcd\xe5\xf2 \xe7\xe0\xef\xe8\xf1\xe5\xe9.')
                else
                    local page_size = 50
                    local total_pages = math.max(1, math.ceil(#show_entries / page_size))
                    if not _G.log_page then _G.log_page = 1 end

                    if _G.log_page > total_pages then _G.log_page = total_pages end

                    imgui.TextDisabled(safe_u8('  \xc7\xe0\xef\xe8\xf1\xe5\xe9: ' .. #show_entries))
                    imgui.SameLine()

                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18,0.18,0.22,1))
                    if imgui.SmallButton(fa_icon.ANGLES_LEFT .. '##logp_first') then _G.log_page = 1 end
                    imgui.SameLine(0, 2*d)
                    if imgui.SmallButton(fa_icon.ANGLE_LEFT .. '##logp_prev') then
                        if _G.log_page > 1 then _G.log_page = _G.log_page - 1 end
                    end
                    imgui.PopStyleColor()
                    imgui.SameLine(0, 6*d)
                    imgui.TextDisabled(safe_u8('\xf1\xf2\xf0. ' .. _G.log_page .. ' / ' .. total_pages))
                    imgui.SameLine(0, 6*d)
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18,0.18,0.22,1))
                    if imgui.SmallButton(fa_icon.ANGLE_RIGHT .. '##logp_next') then
                        if _G.log_page < total_pages then _G.log_page = _G.log_page + 1 end
                    end
                    imgui.SameLine(0, 2*d)
                    if imgui.SmallButton(fa_icon.ANGLES_RIGHT .. '##logp_last') then _G.log_page = total_pages end
                    imgui.PopStyleColor()

                    local i_from = (_G.log_page - 1) * page_size + 1
                    local i_to   = math.min(_G.log_page * page_size, #show_entries)

                    if imgui.BeginChild('##loglist', imgui.ImVec2(-1, -1), false) then
                        fh_touch_scroll('##loglist')
                        for i = i_from, i_to do
                            local item = show_entries[i]
                            imgui.PushTextWrapPos(0)
                            imgui.TextDisabled(safe_u8(fmt_entry(item.e, item.k)))
                            imgui.PopTextWrapPos()
                        end
                        imgui.EndChild()
                    end
                end
                imgui.EndChild()
            end
end

local function fh_render_tab8()
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
            local rcon = settings.reconnect
            local cw = imgui.GetWindowContentRegionWidth()
            local bw = (cw - 8*d) / 2

            local function dot_btn(label, key, tbl, w, h, icon)
                local is_on = tbl[key]
                w = w or -1
                h = h or 30*d
                local tw = 40*d
                local th = 22*d
                local disp = icon and (icon .. '  ' .. u8(label)) or u8(label)
                imgui.PushStyleColor(imgui.Col.ChildBg, is_on and imgui.ImVec4(ar*0.14,ag*0.14,ab*0.14,1) or imgui.ImVec4(0.10,0.10,0.12,1))
                if imgui.BeginChild('##dot_'..key, imgui.ImVec2(w, h), true, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse) then
                    local inner_w = imgui.GetWindowContentRegionWidth()
                    imgui.SetCursorPosY((h - 18*d)/2)
                    imgui.SetCursorPosX(8*d)
                    imgui.TextColored(is_on and imgui.ImVec4(0.4,1.0,0.4,1) or imgui.ImVec4(0.7,0.7,0.7,1), disp)
                    imgui.SameLine(inner_w - tw - 6*d)
                    imgui.SetCursorPosY((h - th)/2)
                    if fh_toggle('##dot_tog_'..key, is_on, tw, th) then
                        tbl[key] = not is_on; save_settings()
                    end
                end
                imgui.EndChild()
                imgui.PopStyleColor()
            end

            imgui.Spacing()

            dot_btn('¿‚ÚÓÂÍÓÌÌÂÍÚ', 'enabled', rcon, bw, 34*d)
            imgui.SameLine(0, 8*d)
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.13, 0.20, 0.38, 1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.20, 0.30, 0.58, 1))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.10, 0.15, 0.28, 1))
            if imgui.Button(fa_icon.ROTATE .. '  ' .. u8'–ÂÍÓÌÌÂÍÚ ÒÂÈ˜‡Ò', imgui.ImVec2(bw, 34*d)) then
                fh_reconnect_active = false
                fh_do_reconnect()
            end
            imgui.PopStyleColor(3)

            if fh_reconnect_active then
                imgui.Spacing()
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.40, 0.12, 0.08, 1))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.18, 0.10, 1))
                imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.30, 0.08, 0.06, 1))
                if imgui.Button(fa_icon.XMARK .. '  ' .. u8'ŒÚÏÂÌËÚ¸ ÂÍÓÌÌÂÍÚ', imgui.ImVec2(-1, 30*d)) then
                    fh_reconnect_active = false
                end
                imgui.PopStyleColor(3)
            end

            imgui.Spacing(); imgui.Separator(); imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(ar, ag, ab, 1), u8' «‡‰ÂÊÍ‡ ÔÂÂ‰ ÂÍÓÌÌÂÍÚÓÏ:')
            imgui.Spacing()
            if not _G.rec_delay_buf then _G.rec_delay_buf = imgui.new.float(rcon.delay or 5.0) end
            imgui.PushItemWidth(-1)
            if imgui.SliderFloat('##rec_delay', _G.rec_delay_buf, 0.0, 60.0) then
                rcon.delay = _G.rec_delay_buf[0]; save_settings()
            end
            imgui.PopItemWidth()

            imgui.Spacing(); imgui.Separator(); imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(ar, ag, ab, 1), fa_icon.BOLT .. u8'  –ÂÍÓÌÌÂÍÚ ÔË:')
            imgui.Spacing()
            local triggers = {
                {' ËÍ  (ÒÓÂ‰. Á‡Í˚ÚÓ)',           'on_kicked',   fa_icon.USER_SLASH},
                {'ŒÚÍ‡Á ÌËÍ‡  (Á‡ÌˇÚ / ÌÂ‚ÂÌ˚È)', 'on_rejected', fa_icon.USER_XMARK},
                {'¡‡Ì  (Á‡·‡ÌÂÌ)',                 'on_banned',   fa_icon.BAN},
                {'◊ÛÊÓÈ Ô‡ÓÎ¸ ÒÂ‚Â‡',           'on_password', fa_icon.LOCK},
            }
            for _, tr in ipairs(triggers) do
                dot_btn(tr[1], tr[2], rcon, -1, 30*d, tr[3])
                imgui.Spacing()
            end

            imgui.Separator(); imgui.Spacing()

            dot_btn('¿‚ÚÓÎÓ„ËÌ', 'auto_login', rcon, -1, 34*d, fa_icon.RIGHT_TO_BRACKET)

            if rcon.auto_login then
                imgui.Spacing()
                if not _G.rec_login_buf then _G.rec_login_buf = imgui.new.char[256](u8(rcon.login or '')) end
                if not _G.rec_pass_buf  then _G.rec_pass_buf  = imgui.new.char[256](u8(rcon.password or '')) end
                imgui.TextColored(imgui.ImVec4(ar, ag, ab, 1), fa_icon.USER .. u8'  ÕËÍÌÂÈÏ:')
                imgui.PushItemWidth(-1)
                if imgui.InputText('##rec_login', _G.rec_login_buf, 256) then
                    rcon.login = u8:decode(ffi.string(_G.rec_login_buf)):match('^%s*(.-)%s*$'); save_settings()
                end
                imgui.PopItemWidth()
                imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(ar, ag, ab, 1), fa_icon.KEY .. u8'  œ‡ÓÎ¸:')
                imgui.PushItemWidth(-1)
                if imgui.InputText('##rec_pass', _G.rec_pass_buf, 256) then
                    rcon.password = u8:decode(ffi.string(_G.rec_pass_buf)):match('^%s*(.-)%s*$'); save_settings()
                end
                imgui.PopItemWidth()
                imgui.Spacing()
                imgui.TextDisabled(u8'  ¿‚ÚÓ‚ıÓ‰ ÔÓÒÎÂ ÂÍÓÌÌÂÍÚ‡')

                imgui.Spacing(); imgui.Separator(); imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(ar, ag, ab, 1), fa_icon.LOCATION_DOT .. u8'  ÃÂÒÚÓ ÒÔ‡‚Ì‡:')
                imgui.Spacing()
                local spawn_items = settings._spawn_items or {}
                if #spawn_items == 0 then
                    imgui.TextDisabled(u8'  —ÔËÒÓÍ ÔÓˇ‚ËÚÒˇ ÔÓÒÎÂ ÔÂ‚Ó„Ó Á‡ıÓ‰‡ Ì‡ ÒÂ‚Â')
                else
                    if not _G.rec_spawn_idx then _G.rec_spawn_idx = imgui.new.int(rcon.spawn_use or 0) end
                    _G.rec_spawn_idx[0] = rcon.spawn_use or 0
                    local spawn_c_items = imgui.new['const char*'][#spawn_items](
                        (function() local t={}; for i,v in ipairs(spawn_items) do t[i]=safe_u8(v) end; return t end)()
                    )
                    imgui.PushItemWidth(-1)
                    if imgui.Combo('##rec_spawn', _G.rec_spawn_idx, spawn_c_items, #spawn_items) then
                        rcon.spawn_use = _G.rec_spawn_idx[0]; save_settings()
                    end
                    imgui.PopItemWidth()
                end
            end
            imgui.Spacing()
end

local function fh_render_tab9()
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
            local tg_h = imgui.GetContentRegionAvail().y
            if imgui.BeginChild('##tg_wrap', imgui.ImVec2(-1, tg_h), false) then
                fh_touch_scroll('##tg_wrap')
                if not settings.tg then settings.tg = {token='',chat_id='',enabled=false,ev_invite=true,ev_join=true,ev_leave=true,ev_level=true,ev_quest=true,ev_mute=true,ev_coins=true} end

                if not tg_token_buf then
                    tg_token_buf  = imgui.new.char[512](safe_u8(settings.tg.token  or ''))
                    tg_chatid_buf = imgui.new.char[128](safe_u8(settings.tg.chat_id or ''))
                    tg_token2_buf = imgui.new.char[512](safe_u8(settings.tg.token2   or ''))
                    tg_chanid_buf   = imgui.new.char[128](safe_u8(settings.tg.channel_id or ''))
                end

                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' Telegram \xf3\xe2\xe5\xe4\xee\xec\xeb\xe5\xed\xe8\xff')
                imgui.Separator()

                local tg_en = settings.tg.enabled
                if fh_toggle_row(u8'\xc2\xea\xeb\xfe\xf7\xe8\xf2\xfc \xf3\xe2\xe5\xe4\xee\xec\xeb\xe5\xed\xe8\xff', '##tgen', tg_en) then
                    settings.tg.enabled = not tg_en; save_settings()
                end
                imgui.Spacing()
                imgui.Separator(); imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' TG \xcf\xf0\xee\xea\xf1\xe8 (\xe4\xeb\xff \xd0\xee\xf1\xf1\xe8\xe8)')
                imgui.Separator()
                imgui.TextDisabled(u8' \xd7\xe5\xf0\xe5\xe7 \xf1\xe5\xf0\xe2\xe5\xf0, \xe5\xf1\xeb\xe8 TG \xe7\xe0\xe1\xeb\xee\xea\xe8\xf0\xee\xe2\xe0\xed')
                imgui.Spacing()
                local tg_px = settings.tg.use_proxy or false
                if fh_toggle_row(u8' \xcf\xf0\xee\xea\xf1\xe8 \xf7\xe5\xf0\xe5\xe7 FH-\xf1\xe5\xf0\xe2\xe5\xf0', '##tgproxy', tg_px) then
                    settings.tg.use_proxy = not tg_px; save_settings()
                end
                imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xcd\xe0\xf1\xf2\xf0\xee\xe9\xea\xe0 \xe1\xee\xf2\xe0')
                imgui.Separator()
                imgui.TextDisabled(u8' 1. \xcd\xe0\xef\xe8\xf8\xe8\xf2\xe5 @BotFather \xe2 Telegram -> /newbot')
                imgui.TextDisabled(u8' 2. \xd1\xea\xee\xef\xe8\xf0\xf3\xe9\xf2\xe5 \xf2\xee\xea\xe5\xed \xe1\xee\xf2\xe0 \xf1\xfe\xe4\xe0')
                imgui.TextDisabled(u8' 3. \xc4\xee\xe1\xe0\xe2\xfc\xf2\xe5 \xe1\xee\xf2\xe0 \xe2 \xe2\xe0\xf8 \xf7\xe0\xf2/\xea\xe0\xed\xe0\xeb')
                imgui.TextDisabled(u8' 4. \xd3\xe7\xed\xe0\xe9\xf2\xe5 ID \xf7\xe0\xf2\xe0 \xf7\xe5\xf0\xe5\xe7 @getmyid_bot')
                imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd0\xe5\xe6\xe8\xec \xf0\xe0\xe1\xee\xf2\xfb')
                imgui.Separator()
                local d = settings.general.custom_dpi

                settings.tg.auto_role = true
                local senior = am_i_senior()
                local cnt = 0; for _ in pairs(fh_online) do cnt = cnt + 1 end
                if senior then
                    imgui.TextColored(imgui.ImVec4(0.2,1,0.2,1), u8'  \xc2\xfb \xe3\xeb\xe0\xe2\xed\xfb\xe9 \x97 \xe2\xf1\xe5 \xf1\xee\xe1\xfb\xf2\xe8\xff \xe8\xe4\xf3\xf2 \xe2 \xd2\xc3')
                else
                    imgui.TextColored(imgui.ImVec4(1,0.8,0.2,1), u8'  \xc7\xe0\xec \x97 \xe5\xf1\xf2\xfc \xea\xf2\xee \xf1\xf2\xe0\xf0\xf8\xe5 \xee\xed\xeb\xe0\xe9\xed')
                end
                imgui.TextDisabled(safe_u8('  \xd1\xea\xf0\xe8\xef\xf2\xee\xe2 \xee\xed\xeb\xe0\xe9\xed: ' .. cnt))
                if cnt > 0 then
                    local names = {}
                    for nick, data in pairs(fh_online) do
                        local marker = (nick == my_nick()) and ' <' or ''
                        table.insert(names, nick .. '(\xf0' .. data.rank .. ')' .. marker)
                    end
                    table.sort(names)
                    imgui.TextDisabled(safe_u8('  ' .. table.concat(names, ', ')))
                end
                imgui.TextDisabled(u8'  \xc3\xeb\xe0\xe2\xed\xfb\xe9 \xee\xef\xf0\xe5\xe4\xe5\xeb\xff\xe5\xf2\xf1\xff \xe0\xe2\xf2\xee\xec\xe0\xf2\xe8\xf7\xe5\xf1\xea\xe8 \xef\xee \xf0\xe0\xed\xe3\xf3 \xe8 \xe2\xf0\xe5\xec\xe5\xed\xe8 \xe2\xf5\xee\xe4\xe0')
                imgui.Spacing(); imgui.Separator(); imgui.Spacing()

                imgui.Text(u8' \xd2\xee\xea\xe5\xed \xe1\xee\xf2\xe0:')
                imgui.PushItemWidth(-1)
                if imgui.InputText('##tg_token', tg_token_buf, 512) then
                    settings.tg.token = u8:decode(ffi.string(tg_token_buf)):match('^%s*(.-)%s*$')
                    save_settings()
                end
                imgui.PopItemWidth()
                imgui.Spacing()
                imgui.Text(u8' “ÓÍÂÌ ·ÓÚ‡ 2 (˜ÚÂÌËÂ ËÁ Í‡Ì‡Î‡):')
                imgui.TextDisabled(u8'  ¡ÓÚ 2 ‚Ë‰ËÚ ÒÓÓ·˘ÂÌËˇ ·ÓÚ‡ 1 - ÌÂÓ·ıÓ‰ËÏ ‰Îˇ Á‡ÔËÒË ÎÓ„‡')
                imgui.PushItemWidth(-1)
                if imgui.InputText('##tg_token2', tg_token2_buf, 512) then
                    settings.tg.token2 = u8:decode(ffi.string(tg_token2_buf)):match('^%s*(.-)%s*$')
                    save_settings()
                end
                imgui.PopItemWidth()
                imgui.Text(u8' ID \xf7\xe0\xf2\xe0 (\xef\xf0\xe8\xec\xe5\xf0: -100123456789):')
                imgui.PushItemWidth(-1)
                if imgui.InputText('##tg_chatid', tg_chatid_buf, 128) then
                    settings.tg.chat_id = u8:decode(ffi.string(tg_chatid_buf)):match('^%s*(.-)%s*$')
                    save_settings()
                end
                imgui.PopItemWidth()
                imgui.Spacing()
                imgui.Text(u8' ID Í‡Ì‡Î‡ (˜ÚÂÌËÂ ÔÓÔÛ˘ÂÌÌ˚ı):')
                imgui.TextDisabled(u8'  —ÓÁ‰‡È Í‡Ì‡Î Ë ‰Ó·‡‚¸ ·ÓÚ‡ ‡‰ÏËÌÓÏ')
                imgui.PushItemWidth(-1)
                if imgui.InputText('##tg_chanid', tg_chanid_buf, 128) then
                    settings.tg.channel_id = u8:decode(ffi.string(tg_chanid_buf)):match('^%s*(.-)%s*$')
                    save_settings()
                end
                imgui.PopItemWidth()
                if imgui.Button(fa_icon.ROTATE_LEFT .. '  ' .. u8'—·ÓÒËÚ¸ offset ##tgreset', imgui.ImVec2(-1, 28*d)) then
                    settings.tg.last_update_offset = 0
                    save_settings()
                    sampAddChatMessage('[Family Helper] TG: offset Ò·Ó¯ÂÌ, ÔË ÒÎÂ‰. ‚ıÓ‰Â ÔÂ˜ËÚ‡ÂÚÒˇ ‚Ò∏', 0xFFAA00)
                end
                imgui.Spacing()
                if imgui.Button(fa_icon.PAPER_PLANE .. '  ' .. u8'ŒÚÔ‡‚ËÚ¸ ÚÂÒÚ ‚ Telegram ##tgtest', imgui.ImVec2(-1, 28*d)) then
                    local ttest_tok = settings.tg.token or ''
                    local ttest_cid = settings.tg.chat_id or ''
                    if ttest_tok == '' or ttest_cid == '' then
                        sampAddChatMessage('[Family Helper] {ff4444}TG: Á‡ÔÓÎÌË ÚÓÍÂÌ Ë chat_id!', 0xFFFFFF)
                    elseif not settings.tg.enabled then
                        sampAddChatMessage('[Family Helper] {ff4444}TG: ‚ÍÎ˛˜Ë Û‚Â‰ÓÏÎÂÌËˇ!', 0xFFFFFF)
                    else
                        tg_send('[Family Helper] “ÂÒÚ! —ÂÏ¸ˇ: ' .. (settings.family_info.family_name or '?'))
                        sampAddChatMessage('[Family Helper] {00cc00}TG: ÓÚÔ‡‚ÎÂÌÓ!', 0xFFFFFF)
                    end
                end
                imgui.Spacing()

                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.07,0.07,0.07,1))
                imgui.BeginChild('##tg_hint', imgui.ImVec2(-1, 70*d), true)
                    imgui.TextDisabled(u8' \xc5\xf1\xeb\xe8 \xf2\xe5\xf1\xf2 \xed\xe5 \xef\xf0\xe8\xf5\xee\xe4\xe8\xf2:')
                    imgui.TextDisabled(u8'  - \xd3\xe1\xe5\xe4\xe8\xf2\xe5\xf1\xfc \xf7\xf2\xee \xe1\xee\xf2 \xc4\xce\xc1\xc0\xc2\xcb\xc5\xcd \xe2 \xf7\xe0\xf2/\xea\xe0\xed\xe0\xeb \xea\xe0\xea \xe0\xe4\xec\xe8\xed\xe8\xf1\xf2\xf0\xe0\xf2\xee\xf0')
                    imgui.TextDisabled(u8'  - chat_id \xe4\xeb\xff \xeb\xe8\xf7\xed\xfb\xf5 \xf1\xee\xee\xe1\xf9\xe5\xed\xe8\xe9: \xef\xf0\xee\xf1\xf2\xee \xe2\xe0\xf8 ID \xe1\xe5\xe7 \xec\xe8\xed\xf3\xf1\xe0')
                    imgui.TextDisabled(u8'  - \xc4\xeb\xff \xe3\xf0\xf3\xef\xef\xfb/\xea\xe0\xed\xe0\xeb\xe0 ID \xed\xe0\xf7\xe8\xed\xe0\xe5\xf2\xf1\xff \xf1 -100...')
                imgui.EndChild()
                imgui.PopStyleColor()
                imgui.Spacing(); imgui.Separator(); imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xca\xe0\xea\xe8\xe5 \xf1\xee\xe1\xfb\xf2\xe8\xff \xee\xf2\xef\xf0\xe0\xe2\xeb\xff\xf2\xfc:')
                imgui.Separator()
                local evs = {
                    {'ev_invite', '\xcf\xf0\xe8\xed\xff\xeb \xe8\xed\xe2\xe0\xe9\xf2'},
                    {'ev_join',   '\xc2\xf1\xf2\xf3\xef\xe8\xeb \xe2 \xf1\xe5\xec\xfc\xfe'},
                    {'ev_leave',  '\xcf\xee\xea\xe8\xed\xf3\xeb / \xea\xe8\xea\xed\xf3\xf2'},
                    {'ev_level',  '\xcf\xee\xe4\xed\xff\xeb \xf3\xf0\xee\xe2\xe5\xed\xfc'},
                    {'ev_quest',  '\xc2\xfb\xef\xee\xeb\xed\xe8\xeb \xea\xe2\xe5\xf1\xf2'},
                    {'ev_mute',   '\xcc\xf3\xf2 (\xf1\xe5\xec\xe5\xe9\xed\xfb\xe9)'},
                    {'ev_coins',  '\xcc\xee\xed\xe5\xf2\xfb/\xf2\xe0\xeb\xee\xed\xfb'},
                    {'ev_bank',   '\xd1\xea\xeb\xe0\xe4 ($)'},
                }
                local ev_w = (imgui.GetWindowContentRegionWidth() - 4*d) / 2
                for ei, ev in ipairs(evs) do
                    if ei % 2 == 0 then imgui.SameLine() end
                    local val = settings.tg[ev[1]]
                    if val == nil then val = true; settings.tg[ev[1]] = true; save_settings() end
                    imgui.BeginGroup()
                    if fh_toggle_row(safe_u8(ev[2]), '##tgev_' .. ev[1], val, ev_w - 8*d) then
                        settings.tg[ev[1]] = not val; save_settings()
                    end
                    imgui.EndGroup()
                end

                imgui.EndChild()
            end
end

local function fh_render_tab10()
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
            local vid_h = imgui.GetContentRegionAvail().y
            if imgui.BeginChild('##vid_wrap', imgui.ImVec2(-1, vid_h), false) then
                fh_touch_scroll('##vid_wrap')
                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xc2\xed\xe5\xf8\xed\xe8\xe9 \xe2\xe8\xe4'); imgui.Separator()
                imgui.Spacing()
                imgui.TextDisabled(u8' \xc0\xea\xf6\xe5\xed\xf2\xed\xfb\xe9 \xf6\xe2\xe5\xf2:')
                imgui.PushItemWidth(-1)
                if imgui.ColorEdit3('##acc', accent_color) then
                    settings.interface.accent_r=accent_color[0]; settings.interface.accent_g=accent_color[1]
                    settings.interface.accent_b=accent_color[2]; save_settings(); apply_theme()
                end
                imgui.PopItemWidth()
                imgui.Spacing()
                imgui.TextDisabled(u8' \xcf\xf0\xe5\xf1\xe5\xf2\xfb:')
                local presets = {
                    {u8'\xce\xf0\xe0\xed\xe6', 1,.65,0},
                    {u8'\xd1\xe8\xed\xe8\xe9', .2,.5,1},
                    {u8'\xc7\xe5\xeb\xb8\xed', .2,.8,.3},
                    {u8'\xca\xf0\xe0\xf1\xed', .9,.2,.2},
                    {u8'\xd4\xe8\xee\xeb', .6,.3,.9},
                    {u8'\xc1\xe5\xeb\xfb\xe9', .85,.85,.85},
                }
                local pw = (imgui.GetWindowContentRegionWidth() - 5*4*d) / #presets
                for pi, pr in ipairs(presets) do
                    if pi > 1 then imgui.SameLine() end
                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(pr[2]*.4,pr[3]*.4,pr[4]*.4,1))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(pr[2]*.6,pr[3]*.6,pr[4]*.6,1))
                    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(pr[2]*.8,pr[3]*.8,pr[4]*.8,1))
                    if imgui.Button(pr[1]..'##pr'..pi, imgui.ImVec2(pw, 28*d)) then
                        settings.interface.accent_r=pr[2]; settings.interface.accent_g=pr[3]; settings.interface.accent_b=pr[4]
                        accent_color[0]=pr[2]; accent_color[1]=pr[3]; accent_color[2]=pr[4]; save_settings(); apply_theme()
                    end
                    imgui.PopStyleColor(3)
                end
                imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xcf\xe0\xf0\xe0\xec\xe5\xf2\xf0\xfb'); imgui.Separator()
                imgui.TextDisabled(u8' \xdf\xf0\xea\xee\xf1\xf2\xfc \xf4\xee\xed\xe0:'); imgui.SameLine(); imgui.PushItemWidth(-1)
                if imgui.SliderFloat('##\xd1\x8f\xd1\x80\xd0\xba\xd0\xbe_v', sl.bg_bright, 0.05, 0.30) then settings.interface.bg_brightness=sl.bg_bright[0]; save_settings(); apply_theme() end
                imgui.PopItemWidth()
                imgui.TextDisabled(u8' \xcf\xf0\xee\xe7\xf0\xe0\xf7\xed\xee\xf1\xf2\xfc:'); imgui.SameLine(); imgui.PushItemWidth(-1)
                if imgui.SliderFloat('##\xd0\xbf\xd1\x80\xd0\xbe\xd0\xb7_v', sl.window_alpha, 0.5, 1.0) then settings.interface.window_alpha=sl.window_alpha[0]; save_settings(); apply_theme() end
                imgui.PopItemWidth()
                imgui.TextDisabled(u8' \xd0\xe0\xe7\xec\xe5\xf0 \xea\xed\xee\xef\xea\xe8:'); imgui.SameLine(); imgui.PushItemWidth(-1)
                if imgui.SliderFloat('##\xd1\x80\xd0\xb0\xd0\xb7\xd0\xbc_v', sl.float_size, 0.5, 2.0) then settings.general.float_btn_size=sl.float_size[0]; save_settings() end
                imgui.PopItemWidth()
                imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xcc\xe0\xf1\xf8\xf2\xe0\xe1 (DPI)'); imgui.Separator()
                imgui.TextDisabled(u8'  \xd2\xe5\xea\xf3\xf9\xe8\xe9: ' .. string.format('%.2f', settings.general.custom_dpi or 1.0))
                imgui.PushItemWidth(-1)
                if imgui.SliderFloat('##dpi_sl', sl.dpi, 0.5, 3.0, '%.2f') then
                    settings.general.custom_dpi=sl.dpi[0]; save_settings(); apply_theme()
                end
                imgui.PopItemWidth()
                imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(ar,ag,ab,1), u8' \xd0\xe0\xe7\xec\xe5\xf0 \xf8\xf0\xe8\xf4\xf2\xe0'); imgui.Separator()
                imgui.TextDisabled(u8'  \xd2\xe5\xea\xf3\xf9\xe8\xe9: ' .. string.format('%.2f', settings.general.custom_font_scale or 1.0))
                imgui.PushItemWidth(-1)
                if imgui.SliderFloat('##font_scale_sl', sl.font_scale, 0.5, 2.0, '%.2f') then
                    settings.general.custom_font_scale=sl.font_scale[0]; save_settings()
                end
                imgui.PopItemWidth()
                imgui.EndChild()
            end
end

local function fh_render_tab11()
    local d = settings.general.custom_dpi
    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0
            local ar=settings.interface.accent_r or 1
            local ag=settings.interface.accent_g or .65
            local ab=settings.interface.accent_b or 0
            if imgui.BeginTabBar('##wikitabs') then
                if imgui.BeginTabItem(fa_icon.TERMINAL .. '  ' .. u8'\xca\xee\xec\xe0\xed\xe4\xfb') then

                    local wiki_cmds_h = imgui.GetContentRegionAvail().y
                    if imgui.BeginChild('##wiki_cmds', imgui.ImVec2(-1, wiki_cmds_h), false) then
                        fh_touch_scroll('##wiki_cmds')
                        imgui.TextColored(imgui.ImVec4(ar,ag,0,1), u8' \xd1\xe5\xf0\xe2\xe5\xf0\xed\xfb\xe5 \xea\xee\xec\xe0\xed\xe4\xfb \xf1\xe5\xec\xfc\xe8'); imgui.Separator()
                        local cmds = {
                            {u8'/fam [\xf2\xe5\xea\xf1\xf2]', u8'\xd7\xe0\xf2 \xf1\xe5\xec\xfc\xe8'},
                            {u8'/fammenu', u8'\xcc\xe5\xed\xfe \xf1\xe5\xec\xfc\xe8'},
                            {u8'/fmembers', u8'\xd1\xef\xe8\xf1\xee\xea \xee\xed\xeb\xe0\xe9\xed'},
                            {u8'/faminfo', u8'\xd1\xf2\xe0\xf2\xe8\xf1\xf2\xe8\xea\xe0 \xf1\xe5\xec\xfc\xe8'},
                            {u8'/faminvite [ID]', u8'\xcf\xf0\xe8\xe3\xeb\xe0\xf1\xe8\xf2\xfc \xe8\xe3\xf0\xee\xea\xe0'},
                            {u8'/famuninvite [ID] [\xef\xf0\xe8\xf7\xe8\xed\xe0]', u8'\xca\xe8\xea \xe8\xe7 \xf1\xe5\xec\xfc\xe8 (online)'},
                            {u8'/famoffkick [\xed\xe8\xea]', u8'\xca\xe8\xea \xe8\xe7 \xf1\xe5\xec\xfc\xe8 (offline)'},
                            {u8'/fammute [ID] [\xec\xe8\xed.] [\xef\xf0\xe8\xf7\xe8\xed\xe0]', u8'\xcc\xf3\xf2 \xf3\xf7\xe0\xf1\xf2\xed\xe8\xea\xe0'},
                            {u8'/famunmute [ID]', u8'\xd1\xed\xff\xf2\xfc \xec\xf3\xf2'},
                            {u8'/setfrank [ID] [\xf0\xe0\xed\xe3]', u8'\xd3\xf1\xf2\xe0\xed\xee\xe2\xe8\xf2\xfc \xf0\xe0\xed\xe3'},
                            {u8'/famtag [ID] [\xf2\xe5\xe3]', u8'\xd3\xf1\xf2\xe0\xed\xee\xe2\xe8\xf2\xfc \xf2\xe5\xe3'},
                            {u8'/famuntag [ID]', u8'\xd1\xed\xff\xf2\xfc \xf2\xe5\xe3'},
                            {u8'/famwarn [ID] [\xef\xf0\xe8\xf7\xe8\xed\xe0]', u8'\xc2\xfb\xe3\xee\xe2\xee\xf0'},
                            {u8'/unfamwarn [ID]', u8'\xd1\xed\xff\xf2\xfc \xe2\xfb\xe3\xee\xe2\xee\xf0'},
                            {u8'/famaddzam [ID]', u8'\xcd\xe0\xe7\xed\xe0\xf7\xe8\xf2\xfc \xe7\xe0\xec\xe0'},
                            {u8'/famdelzam [ID]', u8'\xd1\xed\xff\xf2\xfc \xe7\xe0\xec\xe0'},
                            {u8'/famcarrank [ID] [\xf0\xe0\xed\xe3]', u8'\xd0\xe0\xed\xe3 \xe4\xee\xf1\xf2\xf3\xef\xe0 \xea \xe0\xe2\xf2\xee'},
                            {u8'/famspawn', u8'\xd1\xef\xe0\xe2\xed \xf1\xe5\xec\xe5\xe9\xed\xee\xe3\xee \xf2/\xf1'},
                            {u8'/famdisband', u8'\xd0\xe0\xf1\xf4\xee\xf0\xec\xe8\xf0\xee\xe2\xe0\xf2\xfc \xf1\xe5\xec\xfc\xfe'},
                            {u8'/faminfoset', u8'\xcd\xe0\xf1\xf2\xf0\xee\xe9\xea\xe8 \xf1\xe5\xec\xfc\xe8'},
                        }
                        local half = imgui.GetWindowContentRegionWidth() / 2 - 8*d
                        imgui.Columns(2, '##cmgrid', false)
                        imgui.SetColumnWidth(0, imgui.GetWindowContentRegionWidth() / 2)
                        imgui.SetColumnWidth(1, imgui.GetWindowContentRegionWidth() / 2)
                        for ci, row in ipairs(cmds) do
                            imgui.TextColored(imgui.ImVec4(ar,ag,0,1), row[1])
                            imgui.SameLine(0,4)
                            imgui.TextDisabled(safe_u8(' \x97 ' .. u8:decode(row[2])))
                            imgui.NextColumn()
                        end
                        imgui.Columns(1)
                        imgui.EndChild()
                    end
                    imgui.EndTabItem()
                end
                if imgui.BeginTabItem(fa_icon.NOTE_STICKY .. '  ' .. u8'\xc7\xe0\xec\xe5\xf2\xea\xe8') then

                    local wiki_notes_h = imgui.GetContentRegionAvail().y - imgui.GetFrameHeightWithSpacing()
                    if imgui.BeginChild('##wiki_notes', imgui.ImVec2(-1, wiki_notes_h), true) then
                        fh_touch_scroll('##wiki_notes')
                        imgui.TextColored(imgui.ImVec4(ar,ag,0,1), u8' \xc7\xe0\xec\xe5\xf2\xea\xe8'); imgui.Separator()
                        for i, n in ipairs(settings.note) do
                            if not n.deleted then
                                imgui.Columns(2, '##nr'..i, false)
                                imgui.SetColumnWidth(0, 450*d)
                                imgui.Text(safe_u8(' ' .. (n.note_name or '')))
                                imgui.NextColumn()
                                if imgui.SmallButton(fa_icon.PEN_TO_SQUARE .. '  ' .. u8'\xce\xf2\xea\xf0\xfb\xf2\xfc##n'..i) then
                                    edit_note_index = i
                                    ffi.copy(note_name_buf, safe_u8(n.note_name or ''))
                                    ffi.copy(note_text_buf, safe_u8((n.note_text or ''):gsub('&', '\n')))
                                    NoteWindow[0]=true
                                end
                                imgui.SameLine()
                                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.4,0.1,0.1,1))
                                if imgui.SmallButton(fa_icon.TRASH .. '##nd'..i) then n.deleted=true; save_settings() end
                                imgui.PopStyleColor()
                                imgui.Columns(1); imgui.Separator()
                            end
                        end
                        imgui.EndChild()
                    end
                    if imgui.Button(fa_icon.CIRCLE_PLUS .. '  ' .. u8'\xc7\xe0\xec\xe5\xf2\xea\xe0', imgui.ImVec2(-1, 0)) then
                        table.insert(settings.note, {note_name='\xcd\xee\xe2\xe0\xff', note_text='\xd2\xe5\xea\xf1\xf2', deleted=false}); save_settings()
                    end
                    imgui.EndTabItem()
                end
                if imgui.BeginTabItem(fa_icon.CIRCLE_INFO .. '  ' .. u8'\xce \xf1\xea\xf0\xe8\xef\xf2\xe5') then
                    local wiki_about_h = imgui.GetContentRegionAvail().y
                    if imgui.BeginChild('##wiki_about', imgui.ImVec2(-1, wiki_about_h), false) then
                        fh_touch_scroll('##wiki_about')
                        imgui.Spacing()
                        imgui.TextColored(imgui.ImVec4(ar,ag,0,1), u8'  Family Helper v' .. thisScript().version)
                        imgui.TextDisabled(u8'  \xc0\xe2\xf2\xee\xf0: Shinik_Pupckin')
                        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                        imgui.TextColored(imgui.ImVec4(ar,ag,0,1), u8'  \xc8\xed\xf1\xf2\xf0\xf3\xea\xf6\xe8\xff'); imgui.Separator()
                        imgui.TextDisabled(u8'  1. /fh \x97 \xee\xf2\xea\xf0\xfb\xf2\xfc/\xe7\xe0\xea\xf0\xfb\xf2\xfc \xe3\xeb\xe0\xe2\xed\xee\xe5 \xee\xea\xed\xee')
                        imgui.TextDisabled(u8'  2. /fi [ID] \x97 \xe1\xfb\xf1\xf2\xf0\xee\xe5 \xec\xe5\xed\xfe \xe4\xe5\xe9\xf1\xf2\xe2\xe8\xe9 \xf1 \xe8\xe3\xf0\xee\xea\xee\xec')
                        imgui.TextDisabled(u8'  3. /fm [ID] \x97 \xe1\xfb\xf1\xf2\xf0\xee\xe5 \xec\xe5\xed\xfe \xe8\xe3\xf0\xee\xea\xe0')
                        imgui.TextDisabled(u8'  4. /fai \x97 \xe0\xe2\xf2\xee-\xe8\xed\xe2\xe0\xe9\xf2 \xe2\xea\xeb/\xe2\xfb\xea\xeb')
                        imgui.TextDisabled(u8'  5. /fp [\xed\xee\xec\xe5\xf0] \x97 \xe7\xe0\xef\xf3\xf1\xf2\xe8\xf2\xfc \xf8\xe0\xe1\xeb\xee\xed \xef\xe8\xe0\xf0\xe0')
                        imgui.TextDisabled(u8'  6. /fhdlg \x97 \xe4\xe5\xe1\xe0\xe3 \xe4\xe8\xe0\xeb\xee\xe3\xee\xe2 \xe2\xea\xeb/\xe2\xfb\xea\xeb')
                        imgui.TextDisabled(u8'  7. /fhstats \x97 \xf1\xf2\xe0\xf2\xe8\xf1\xf2\xe8\xea\xe0 \xf1\xea\xf0\xe8\xef\xf2\xe0')
                        imgui.TextDisabled(u8'  8. /stop \x97 \xee\xf1\xf2\xe0\xed\xee\xe2\xe8\xf2\xfc \xe2\xfb\xef\xee\xeb\xed\xe5\xed\xe8\xe5 \xea\xee\xec\xe0\xed\xe4\xfb')
                        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                        imgui.TextColored(imgui.ImVec4(ar,ag,0,1), u8'  \xd3\xef\xf0\xe0\xe2\xeb\xe5\xed\xe8\xe5 \xf1\xea\xf0\xe8\xef\xf2\xee\xec'); imgui.Separator()
                        local bw2 = (imgui.GetWindowContentRegionWidth() - 8*d) / 3
                        if imgui.Button(fa_icon.ROTATE .. '  ' .. u8'\xcf\xe5\xf0\xe5\xe7\xe0\xe3\xf0\xf3\xe7\xe8\xf2\xfc', imgui.ImVec2(bw2, 0)) then reload_script=true; thisScript():reload() end
                        imgui.SameLine(0,4)
                        if imgui.Button(fa_icon.TRASH_ARROW_UP .. '  ' .. u8'\xd1\xe1\xf0\xee\xf1 \xed\xe0\xf1\xf2\xf0\xee\xe5\xea', imgui.ImVec2(bw2, 0)) then settings=default_settings; save_settings(); reload_script=true; thisScript():reload() end
                        imgui.SameLine(0,4)
                        if imgui.Button(fa_icon.POWER_OFF .. '  ' .. u8'\xc2\xfb\xea\xeb\xfe\xf7\xe8\xf2\xfc', imgui.ImVec2(bw2, 0)) then reload_script=true; thisScript():unload() end
                        imgui.EndChild()
                    end
                    imgui.EndTabItem()
                end
                imgui.EndTabBar()
            end
end

imgui.OnFrame(function() return MainWindow[0] end, function()
    local d = settings.general.custom_dpi

    local ar = settings.interface.accent_r or 1.0
    local ag = settings.interface.accent_g or 0.65
    local ab = settings.interface.accent_b or 0.0

    local _saved_w = tonumber(settings.general.main_win_w) or 0
    local _saved_h = tonumber(settings.general.main_win_h) or 0
    local _saved_x = tonumber(settings.general.main_win_x) or -1
    local _saved_y = tonumber(settings.general.main_win_y) or -1
    local _default_w = math.min(780*d, sizeX - 20)
    local _default_h = math.min(500*d, sizeY - 20)
    local _init_w = (_saved_w > 0) and math.min(_saved_w, sizeX - 10) or _default_w
    local _init_h = (_saved_h > 0) and math.min(_saved_h, sizeY - 10) or _default_h
    if _saved_x >= 0 and _saved_y >= 0 then
        imgui.SetNextWindowPos(imgui.ImVec2(math.min(_saved_x, sizeX - 10), math.min(_saved_y, sizeY - 10)), imgui.Cond.FirstUseEver)
    else
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    end
    imgui.SetNextWindowSize(imgui.ImVec2(_init_w, _init_h), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSizeConstraints(imgui.ImVec2(math.min(480*d, sizeX - 20), math.min(320*d, sizeY - 20)), imgui.ImVec2(sizeX - 10, sizeY - 10))

    if _G.fh_force_fit_win then
        _G.fh_force_fit_win = nil
        imgui.SetNextWindowPos(_G.fh_fit_pos, imgui.Cond.Always)
        imgui.SetNextWindowSize(_G.fh_fit_size, imgui.Cond.Always)
    end

    imgui.GetIO().ConfigWindowsMoveFromTitleBarOnly = true
    imgui.GetIO().ConfigFlags = bit.bor(imgui.GetIO().ConfigFlags, imgui.ConfigFlags.IsTouchScreen)
    imgui.Begin(u8(' Family Helper v' .. thisScript().version), MainWindow, imgui.WindowFlags.NoCollapse)

    _G.fh_last_win_dpi = d

    do
        local wp = imgui.GetWindowPos()
        local ws = imgui.GetWindowSize()
        local max_w = sizeX - 10
        local max_h = sizeY - 10
        local fit_w = math.min(ws.x, max_w)
        local fit_h = math.min(ws.y, max_h)
        local fit_x = math.max(0, math.min(wp.x, sizeX - fit_w))
        local fit_y = math.max(0, math.min(wp.y, sizeY - fit_h))
        if fit_w ~= ws.x or fit_h ~= ws.y or fit_x ~= wp.x or fit_y ~= wp.y then
            _G.fh_force_fit_win = true
            _G.fh_fit_pos = imgui.ImVec2(fit_x, fit_y)
            _G.fh_fit_size = imgui.ImVec2(fit_w, fit_h)
        end
    end

    do
        local ws = imgui.GetWindowSize()
        local wp = imgui.GetWindowPos()
        local wi, hi, xi, yi = math.floor(ws.x), math.floor(ws.y), math.floor(wp.x), math.floor(wp.y)
        if wi ~= (tonumber(settings.general.main_win_w) or 0)
        or hi ~= (tonumber(settings.general.main_win_h) or 0)
        or xi ~= (tonumber(settings.general.main_win_x) or -1)
        or yi ~= (tonumber(settings.general.main_win_y) or -1) then
            local now = os.clock()
            if not _G.fh_last_win_save or (now - _G.fh_last_win_save) > 0.5 then
                settings.general.main_win_w = wi
                settings.general.main_win_h = hi
                settings.general.main_win_x = xi
                settings.general.main_win_y = yi
                save_settings()
                _G.fh_last_win_save = now
            end
        end
    end

    change_dpi()

    fh_side_tab = fh_side_tab or 1
    local _sidebar_w = math.min(150 * d, imgui.GetWindowContentRegionWidth() * 0.32, 230)

    local _content_h = imgui.GetContentRegionAvail().y
    if imgui.BeginChild('##fh_sidebar', imgui.ImVec2(_sidebar_w, _content_h), true) then
        fh_touch_scroll('##fh_sidebar')
        local _tabs_count = #fh_side_tabs
        local _spacing_y = imgui.GetStyle().ItemSpacing.y
        local _avail_h = imgui.GetContentRegionAvail().y - _spacing_y * (_tabs_count - 1)
        local _tab_btn_h = math.max(32*d, _avail_h / _tabs_count)
        for _, _t in ipairs(fh_side_tabs) do
            local _active = (fh_side_tab == _t.id)
            if _active then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(ar*.5, ag*.5, ab*.5, 1))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(ar*.5, ag*.5, ab*.5, 1))
            end
            local _btn_id = '##fh_tab_' .. _t.id
            local _btn_w = _sidebar_w - imgui.GetStyle().WindowPadding.x * 2
            local _btn_pos = imgui.GetCursorScreenPos()
            if imgui.Button(_btn_id, imgui.ImVec2(-1, _tab_btn_h)) then
                fh_side_tab = _t.id
            end
            if _active then
                imgui.PopStyleColor(2)
            end
            if _t.icon then
                local _dl = imgui.GetWindowDrawList()
                local _ic_col
                if _active and _t.icon_color then
                    _ic_col = imgui.GetColorU32Vec4(_t.icon_color)
                elseif _active then
                    _ic_col = imgui.GetColorU32Vec4(imgui.ImVec4(ar, ag, ab, 1))
                else
                    _ic_col = imgui.GetColorU32Vec4(imgui.ImVec4(0.55, 0.55, 0.58, 1))
                end
                local _ic_x = _btn_pos.x + 10 * d
                local _ic_y = _btn_pos.y + (_tab_btn_h - 15 * d) / 2
                _dl:AddText(imgui.ImVec2(_ic_x, _ic_y), _ic_col, _t.icon)
                local _lbl_col = _active and imgui.GetColorU32(imgui.Col.Text) or imgui.GetColorU32Vec4(imgui.ImVec4(0.75, 0.75, 0.78, 1))
                local _lbl_x = _ic_x + 24 * d
                local _lbl_y = _btn_pos.y + (_tab_btn_h - imgui.GetTextLineHeight()) / 2
                _dl:AddText(imgui.ImVec2(_lbl_x, _lbl_y), _lbl_col, _t.label)
            end
        end
    end
    imgui.EndChild()
    imgui.SameLine()
    if imgui.BeginChild('##fh_content', imgui.ImVec2(-1, _content_h), true) then
        fh_touch_scroll('##fh_content')

        if fh_side_tab == 1 then fh_render_tab1() end

        if fh_side_tab == 2 then fh_render_tab2() end
        if fh_side_tab == 3 then fh_render_tab3() end

        if fh_side_tab == 4 then fh_render_tab4() end

        if fh_side_tab == 5 then fh_render_tab5() end

        if fh_side_tab == 6 then fh_render_tab6() end

        if fh_side_tab == 7 then fh_render_tab7() end

        if fh_side_tab == 8 then fh_render_tab8() end

        if fh_side_tab == 9 then fh_render_tab9() end

        if fh_side_tab == 10 then fh_render_tab10() end

        if fh_side_tab == 11 then fh_render_tab11() end

    end
    imgui.EndChild()

    imgui.End()
end)

imgui.OnFrame(function() return InteractEditWindow[0] and interact_edit_index ~= nil end, function()
    if not interact_edit_index or not settings.interactions[interact_edit_index] then InteractEditWindow[0]=false; interact_edit_index=nil; return end
    local inter = settings.interactions[interact_edit_index]; local d = settings.general.custom_dpi
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(480*d, 350*d), imgui.Cond.FirstUseEver)
    imgui.Begin(safe_u8(' \xd8\xe0\xe3: '..(inter.name or'')), InteractEditWindow, imgui.WindowFlags.NoCollapse+imgui.WindowFlags.NoResize)
    change_dpi()
    imgui.Text(u8'\xcd\xe0\xe7\xe2\xe0\xed\xe8\xe5:'); local inn=imgui.new.char[256](safe_u8(inter.name)); imgui.PushItemWidth(-1)
    if imgui.InputText('##ien',inn,256) then inter.name=u8:decode(ffi.string(inn)); save_settings() end
    imgui.Text(u8'\xc7\xe0\xe4\xe5\xf0\xe6\xea\xe0 (\xf1):'); local sl=imgui.new.float(inter.waiting or 1.5); imgui.PushItemWidth(-1)
    if imgui.SliderFloat('##iew',sl,0.5,10) then inter.waiting=sl[0]; save_settings() end
    imgui.Separator(); imgui.Text(u8'\xd1\xf2\xf0\xee\xea\xe8:')
    if imgui.BeginChild('##iel', imgui.ImVec2(-1, 140*d), true) then
        fh_touch_scroll('##iel')
        local rm=nil
        for li, line in ipairs(inter.lines or{}) do
            local inp=imgui.new.char[512](safe_u8(line)); imgui.PushItemWidth(370*d)
            if imgui.InputText('##il'..li,inp,512) then inter.lines[li]=u8:decode(ffi.string(inp)); save_settings() end
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Button,       imgui.ImVec4(0.45, 0.08, 0.08, 1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.10, 0.10, 1))
            if imgui.SmallButton(fa_icon.TRASH .. '##ild'..li) then rm=li end
            imgui.PopStyleColor(2)
        end
        if rm then table.remove(inter.lines, rm); save_settings() end
        imgui.EndChild()
    end
    if imgui.Button(fa_icon.CIRCLE_PLUS .. '  ' .. u8'\xd1\xf2\xf0\xee\xea\xe0', imgui.ImVec2(imgui.GetMiddleButtonX(2),0)) then table.insert(inter.lines,'\xd2\xe5\xea\xf1\xf2'); save_settings() end
    imgui.SameLine()
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.38, 0.10, 0.10, 1))
    imgui.PushStyleColor(imgui.Col.ButtonHovered,  imgui.ImVec4(0.48, 0.12, 0.12, 1))
    imgui.PushStyleColor(imgui.Col.ButtonActive,   imgui.ImVec4(0.30, 0.08, 0.08, 1))
    if imgui.Button(fa_icon.TRASH .. '  ' .. u8'\xd3\xe4\xe0\xeb\xe8\xf2\xfc', imgui.ImVec2(imgui.GetMiddleButtonX(2),0)) then
        table.remove(settings.interactions, interact_edit_index); save_settings(); InteractEditWindow[0]=false; interact_edit_index=nil
    end
    imgui.PopStyleColor(3)
    imgui.End()
end)

imgui.OnFrame(function() return PiarEditWindow[0] and piar_edit_index ~= nil end, function()
    if not piar_edit_index or not settings.piar_templates[piar_edit_index] then PiarEditWindow[0]=false; piar_edit_index=nil; return end
    local t = settings.piar_templates[piar_edit_index]; local d = settings.general.custom_dpi
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(500*d, 380*d), imgui.Cond.FirstUseEver)
    imgui.Begin(safe_u8(' \xcf\xe8\xe0\xf0: '..(t.name or'')), PiarEditWindow, imgui.WindowFlags.NoCollapse+imgui.WindowFlags.NoResize)
    change_dpi()
    imgui.Text(u8'\xcd\xe0\xe7\xe2\xe0\xed\xe8\xe5:'); local pn=imgui.new.char[256](safe_u8(t.name)); imgui.PushItemWidth(-1)
    if imgui.InputText('##pn',pn,256) then t.name=u8:decode(ffi.string(pn)); save_settings() end
    imgui.Text(u8'\xc7\xe0\xe4\xe5\xf0\xe6\xea\xe0:'); local pw=imgui.new.float(t.waiting or 1.5); imgui.PushItemWidth(-1)
    if imgui.SliderFloat('##pw',pw,0.5,10) then t.waiting=pw[0]; save_settings() end
    imgui.Text(u8'\xc0\xe2\xf2\xee-\xe8\xed\xf2\xe5\xf0\xe2\xe0\xeb \xec\xe8\xed:')
    local pi=imgui.new.int(t.auto_interval or 300); imgui.PushItemWidth(-1)
    if imgui.SliderInt('##pi',pi,30,3600) then t.auto_interval=pi[0]; if (t.auto_interval_max or 0) < pi[0] then t.auto_interval_max=pi[0] end; save_settings() end
    imgui.Text(u8'\xc0\xe2\xf2\xee-\xe8\xed\xf2\xe5\xf0\xe2\xe0\xeb \xec\xe0\xea\xf1 (0=\xed\xe5\xf2 \xf0\xe0\xed\xe4\xee\xec\xe0):')
    local pm=imgui.new.int(t.auto_interval_max or 0); imgui.PushItemWidth(-1)
    if imgui.SliderInt('##pm',pm,0,3600) then t.auto_interval_max=pm[0]; save_settings() end
    imgui.Text(u8'\xcb\xe8\xec\xe8\xf2 \xe0\xe2\xf2\xee-\xee\xf2\xef\xf0\xe0\xe2\xee\xea (0 = \xe1\xe5\xe7 \xeb\xe8\xec\xe8\xf2\xe0):')
    local pl=imgui.new.int(t.auto_limit or 0); imgui.PushItemWidth(-1)
    if imgui.SliderInt('##pl_lim',pl,0,100) then t.auto_limit=pl[0]; t.auto_count=0; save_settings() end
    if (t.auto_limit or 0) > 0 then
        imgui.SameLine(); imgui.TextDisabled(safe_u8('  (' .. (t.auto_count or 0) .. '/' .. t.auto_limit .. ')'))
    end
    if fh_toggle_row(u8'\xd1\xeb\xf3\xf7\xe0\xe9\xed\xe0\xff \xf1\xf2\xf0\xee\xea\xe0', '##prl', t.random_line or false) then
        t.random_line = not (t.random_line or false); save_settings()
    end
    imgui.Separator()
    if t.random_line then
        imgui.TextDisabled(u8'\xd1\xf2\xf0\xee\xea\xe8 (\xee\xe4\xed\xe0 \xe2\xfb\xe1\xe8\xf0\xe0\xe5\xf2\xf1\xff \xf1\xeb\xf3\xf7\xe0\xe9\xed\xee \xef\xf0\xe8 \xea\xe0\xe6\xe4\xee\xe9 \xee\xf2\xef\xf0\xe0\xe2\xea\xe5):')
    else
        imgui.TextDisabled(u8'\xd1\xf2\xf0\xee\xea\xe8 (\xee\xf2\xef\xf0\xe0\xe2\xeb\xff\xfe\xf2\xf1\xff \xe2\xf1\xe5 \xef\xee\xe4\xf0\xff\xe4 \xf1 \xe7\xe0\xe4\xe5\xf0\xe6\xea\xee\xe9):')
    end
    imgui.Separator()
    if imgui.BeginChild('##pl', imgui.ImVec2(-1, 120*d), true) then
        fh_touch_scroll('##pl')
        local rm=nil
        for li, line in ipairs(t.lines or{}) do
            local _lbk = 'fh_piar_linebuf_'..tostring(piar_edit_index)..'_'..li
            if not _G[_lbk] then _G[_lbk] = imgui.new.char[512](safe_u8(line)) end
            imgui.PushItemWidth(390*d)
            if imgui.InputText('##pli'..li,_G[_lbk],512) then t.lines[li]=u8:decode(ffi.string(_G[_lbk])); save_settings() end
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Button,       imgui.ImVec4(0.45, 0.08, 0.08, 1))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.10, 0.10, 1))
            if imgui.SmallButton(fa_icon.TRASH .. '##pld'..li) then rm=li end
            imgui.PopStyleColor(2)
        end
        if rm then
            table.remove(t.lines, rm)
            for _ci = rm, #t.lines + 1 do
                _G['fh_piar_linebuf_'..tostring(piar_edit_index)..'_'.._ci] = nil
            end
            save_settings()
        end
        imgui.EndChild()
    end
    if imgui.Button(fa_icon.CIRCLE_PLUS .. '  ' .. u8'\xd1\xf2\xf0\xee\xea\xe0', imgui.ImVec2(imgui.GetMiddleButtonX(2),0)) then
        table.insert(t.lines,'/s \xd2\xe5\xea\xf1\xf2'); save_settings()
        _G['fh_piar_linebuf_'..tostring(piar_edit_index)..'_'..#t.lines] = nil
    end
    imgui.SameLine()
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.38, 0.10, 0.10, 1))
    imgui.PushStyleColor(imgui.Col.ButtonHovered,  imgui.ImVec4(0.48, 0.12, 0.12, 1))
    imgui.PushStyleColor(imgui.Col.ButtonActive,   imgui.ImVec4(0.30, 0.08, 0.08, 1))
    if imgui.Button(fa_icon.TRASH .. '  ' .. u8'\xd3\xe4\xe0\xeb\xe8\xf2\xfc', imgui.ImVec2(imgui.GetMiddleButtonX(2),0)) then
        table.remove(settings.piar_templates, piar_edit_index); save_settings()
        for _k in pairs(_G) do if type(_k)=='string' and _k:find('^fh_piar_linebuf_') then _G[_k]=nil end end
        PiarEditWindow[0]=false; piar_edit_index=nil
    end
    imgui.PopStyleColor(3)
    imgui.End()
end)

imgui.OnFrame(function() return FastMenu[0] end, function()
    if not player_id or not sampIsPlayerConnected(player_id) then FastMenu[0]=false; return end
    local d = settings.general.custom_dpi
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(' '..(sampGetPlayerNickname(player_id) or'???')..' ['..player_id..']##FM', FastMenu, imgui.WindowFlags.NoCollapse+imgui.WindowFlags.NoResize+imgui.WindowFlags.AlwaysAutoResize)
    change_dpi()
    for _, c in ipairs(settings.commands) do
        if c.enable and not c.deleted and c.arg == '{arg_id}' then
            if imgui.Button(safe_u8(c.description), imgui.ImVec2(250*d, 26*d)) then
                sampProcessChatInput("/"..(c.cmd or'').." "..player_id); FastMenu[0]=false
            end
        end
    end
    imgui.Separator()
    if imgui.Button(fa_icon.COMMENTS .. u8'  \xc2\xe5\xf0\xe1\xee\xe2\xea\xe0', imgui.ImVec2(-1, 0)) then interact_player_id=player_id; InteractMenu[0]=true; FastMenu[0]=false end
    imgui.End()
end)

imgui.OnFrame(function() return CommandStopWindow[0] end, function()
    local d=settings.general.custom_dpi
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY-50*d), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5,0.5))
    imgui.Begin("##stop",_,imgui.WindowFlags.NoCollapse+imgui.WindowFlags.NoResize+imgui.WindowFlags.AlwaysAutoResize+imgui.WindowFlags.NoTitleBar)
    change_dpi()
    if isActiveCommand then
        if imgui.Button(fa_icon.CIRCLE_STOP .. u8'  \xd1\xf2\xee\xef') then command_stop=true; CommandStopWindow[0]=false end
    else CommandStopWindow[0]=false end
    imgui.End()
end)

imgui.OnFrame(function() return CommandPauseWindow[0] end, function()
    local d=settings.general.custom_dpi
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY-50*d), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5,0.5))
    imgui.Begin("##pause",_,imgui.WindowFlags.NoCollapse+imgui.WindowFlags.NoResize+imgui.WindowFlags.AlwaysAutoResize+imgui.WindowFlags.NoTitleBar)
    change_dpi()
    if command_pause then
        if imgui.Button(fa_icon.PLAY .. u8'  \xc4\xe0\xeb\xe5\xe5', imgui.ImVec2(120*d,0)) then command_pause=false; CommandPauseWindow[0]=false end
        imgui.SameLine()
        if imgui.Button(fa_icon.CIRCLE_STOP .. u8'  \xd1\xf2\xee\xef', imgui.ImVec2(120*d,0)) then command_stop=true; command_pause=false; CommandPauseWindow[0]=false end
    else CommandPauseWindow[0]=false end
    imgui.End()
end)

imgui.OnFrame(function() return NoteWindow[0] end, function()
    if not edit_note_index or not settings.note[edit_note_index] then NoteWindow[0]=false; return end
    local d = settings.general.custom_dpi
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(420*d, 360*d), imgui.Cond.FirstUseEver)
    imgui.Begin(u8' \xd0\xe5\xe4\xe0\xea\xf2\xe8\xf0\xee\xe2\xe0\xed\xe8\xe5 \xe7\xe0\xec\xe5\xf2\xea\xe8##notewin', NoteWindow, imgui.WindowFlags.NoCollapse)
    change_dpi()
    imgui.Text(u8' \xcd\xe0\xe7\xe2\xe0\xed\xe8\xe5:')
    imgui.PushItemWidth(-1)
    imgui.InputText('##note_name', note_name_buf, 128)
    imgui.PopItemWidth()
    imgui.Spacing()
    imgui.Text(u8' \xd2\xe5\xea\xf1\xf2:')
    imgui.PushItemWidth(-1)
    imgui.InputTextMultiline('##note_text', note_text_buf, 4096, imgui.ImVec2(-1, 200*d))
    imgui.PopItemWidth()
    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
    local bw = (imgui.GetWindowContentRegionWidth() - 8*d) / 2
    if imgui.Button(fa_icon.FLOPPY_DISK .. u8'  \xd1\xee\xf5\xf0\xe0\xed\xe8\xf2\xfc', imgui.ImVec2(bw, 28*d)) then
        local n = settings.note[edit_note_index]
        if n then
            local new_name = u8:decode(ffi.string(note_name_buf)):match('^%s*(.-)%s*$')
            local new_text = u8:decode(ffi.string(note_text_buf)):gsub('\r\n','\n'):gsub('\n','&')
            n.note_name = new_name ~= '' and new_name or n.note_name
            n.note_text = new_text
            save_settings()
        end
        NoteWindow[0]=false
    end
    imgui.SameLine()
    if imgui.Button(fa_icon.XMARK .. u8'  \xce\xf2\xec\xe5\xed\xe0', imgui.ImVec2(bw, 28*d)) then NoteWindow[0]=false end
    imgui.End()
end)

imgui.OnFrame(function() return BinderWindow[0] end, function()
    local d=settings.general.custom_dpi
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX/2, sizeY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(560*d, 380*d), imgui.Cond.FirstUseEver)
    imgui.Begin(u8' \xd0\xe5\xe4\xe0\xea\xf2\xee\xf0 \xea\xee\xec\xe0\xed\xe4\xfb', BinderWindow, imgui.WindowFlags.NoCollapse+imgui.WindowFlags.NoResize)
    change_dpi()
    if imgui.BeginChild('##be', imgui.ImVec2(549*d, 300*d), true) then
        fh_touch_scroll('##be')
        imgui.CenterText(u8'\xce\xef\xe8\xf1\xe0\xed\xe8\xe5:'); imgui.PushItemWidth(-1); imgui.InputText("##bd",input_description,256)
        imgui.Separator()
        imgui.CenterText(u8'\xca\xee\xec\xe0\xed\xe4\xe0 (\xe1\xe5\xe7 /):'); imgui.PushItemWidth(-1); imgui.InputText("##bc",input_cmd,256)
        imgui.Separator()
        imgui.CenterText(u8'\xc0\xf0\xe3\xf3\xec\xe5\xed\xf2\xfb:'); imgui.Combo('##ba',ComboTags,ImItems,#item_list)
        imgui.Separator()
        imgui.CenterText(u8'\xd2\xe5\xea\xf1\xf2 (& = \xf1\xf2\xf0\xee\xea\xe0):')
        imgui.InputTextMultiline("##bt",input_text,8192,imgui.ImVec2(-1,100*d))
        imgui.EndChild()
    end
    imgui.Text(u8'\xc7\xe0\xe4\xe5\xf0\xe6\xea\xe0:'); imgui.SameLine(); imgui.PushItemWidth(180*d); imgui.SliderFloat('##bw',waiting_slider,0.5,5)
    if imgui.Button(fa_icon.XMARK .. u8'  \xce\xf2\xec\xe5\xed\xe0', imgui.ImVec2(imgui.GetMiddleButtonX(2),0)) then BinderWindow[0]=false end
    imgui.SameLine()
    if imgui.Button(fa_icon.FLOPPY_DISK .. u8'  \xd1\xee\xf5\xf0\xe0\xed\xe8\xf2\xfc', imgui.ImVec2(imgui.GetMiddleButtonX(2),0)) then
        local nc=ffi.string(input_cmd); local nt=ffi.string(input_text)
        if nc~='' and nt~='' then
            local na=({'','{arg}','{arg_id}','{arg_id} {arg2}'})[ComboTags[0]+1] or''
            for _, c in ipairs(settings.commands) do
                if c.cmd==change_cmd and c.description==change_description then
                    pcall(sampUnregisterChatCommand, c.cmd)
                    c.cmd=u8:decode(nc); c.arg=na; c.description=u8:decode(ffi.string(input_description))
                    c.text=u8:decode(nt):gsub('\n','&'); c.waiting=tostring(waiting_slider[0])
                    c.enable=true; c.deleted=false; save_settings()
                    reg_cmd(c.cmd, c.arg, c.text, tonumber(c.waiting)); break
                end
            end
            BinderWindow[0]=false
        end
    end
    imgui.End()
end)

function imgui.CenterText(t)
    t=t or''; local w=imgui.GetWindowWidth(); imgui.SetCursorPosX(w/2-imgui.CalcTextSize(t).x/2); imgui.Text(t)
end
function imgui.CenterColumnText(t)
    t=t or''; imgui.SetCursorPosX((imgui.GetColumnOffset()+(imgui.GetColumnWidth()/2))-imgui.CalcTextSize(t).x/2); imgui.Text(t)
end
function imgui.CenterColumnTextDisabled(t)
    t=t or''; imgui.SetCursorPosX((imgui.GetColumnOffset()+(imgui.GetColumnWidth()/2))-imgui.CalcTextSize(t).x/2); imgui.TextDisabled(t)
end
function imgui.CenterColumnSmallButton(t)
    local d=(t or''):match('(.+)##') or t or''; imgui.SetCursorPosX((imgui.GetColumnOffset()+(imgui.GetColumnWidth()/2))-imgui.CalcTextSize(d).x/2); return imgui.SmallButton(t or'')
end
function imgui.GetMiddleButtonX(c)
    local w=imgui.GetWindowContentRegionWidth(); local s=imgui.GetStyle().ItemSpacing.x; return c==1 and w or w/c-((s*(c-1))/c)
end

function apply_theme()
    imgui.SwitchContext()
    local s=imgui.GetStyle(); local d=settings.general.custom_dpi
    local bg=settings.interface.bg_brightness or 0.13
    local wa=settings.interface.window_alpha or 0.97
    local ar=settings.interface.accent_r or 1; local ag=settings.interface.accent_g or .65; local ab=settings.interface.accent_b or 0
    s.WindowPadding=imgui.ImVec2(5*d,5*d); s.FramePadding=imgui.ImVec2(5*d,5*d)
    s.ItemSpacing=imgui.ImVec2(5*d,5*d); s.ItemInnerSpacing=imgui.ImVec2(2*d,2*d)
    s.ScrollbarSize=15*d; s.GrabMinSize=15*d
    s.TouchExtraPadding=imgui.ImVec2(4*d,4*d)
    s.WindowBorderSize=1*d; s.ChildBorderSize=1*d; s.PopupBorderSize=1*d; s.FrameBorderSize=1*d; s.TabBorderSize=1*d
    s.WindowRounding=8*d; s.ChildRounding=8*d; s.FrameRounding=8*d; s.PopupRounding=8*d
    s.ScrollbarRounding=6*d; s.GrabRounding=6*d; s.TabRounding=8*d
    s.WindowTitleAlign=imgui.ImVec2(.5,.5); s.ButtonTextAlign=imgui.ImVec2(.5,.5); s.SelectableTextAlign=imgui.ImVec2(.5,.5)
    s.Colors[imgui.Col.Text]=imgui.ImVec4(.92,.92,.92,1)
    s.Colors[imgui.Col.TextDisabled]=imgui.ImVec4(.55,.55,.55,1)
    s.Colors[imgui.Col.WindowBg]=imgui.ImVec4(bg,bg,bg+.01,wa)
    s.Colors[imgui.Col.ChildBg]=imgui.ImVec4(bg+.02,bg+.02,bg+.03,wa)
    s.Colors[imgui.Col.PopupBg]=imgui.ImVec4(bg+.01,bg+.01,bg+.02,wa)
    s.Colors[imgui.Col.Border]=imgui.ImVec4(bg+.17,bg+.17,bg+.19,.65)
    s.Colors[imgui.Col.BorderShadow]=imgui.ImVec4(0,0,0,0)
    s.Colors[imgui.Col.FrameBg]=imgui.ImVec4(bg+.05,bg+.05,bg+.07,1)
    s.Colors[imgui.Col.FrameBgHovered]=imgui.ImVec4(bg+.13,bg+.13,bg+.15,1)
    s.Colors[imgui.Col.FrameBgActive]=imgui.ImVec4(bg+.17,bg+.17,bg+.20,1)
    s.Colors[imgui.Col.TitleBg]=imgui.ImVec4(bg-.01,bg-.01,bg,1)
    s.Colors[imgui.Col.TitleBgActive]=imgui.ImVec4(ar*.25,ag*.25,ab*.25,1)
    s.Colors[imgui.Col.TitleBgCollapsed]=imgui.ImVec4(bg-.01,bg-.01,bg,1)
    s.Colors[imgui.Col.MenuBarBg]=imgui.ImVec4(bg+.03,bg+.03,bg+.05,1)
    s.Colors[imgui.Col.ScrollbarBg]=imgui.ImVec4(bg+.01,bg+.01,bg+.02,1)
    s.Colors[imgui.Col.ScrollbarGrab]=imgui.ImVec4(bg+.15,bg+.15,bg+.17,1)
    s.Colors[imgui.Col.ScrollbarGrabHovered]=imgui.ImVec4(bg+.25,bg+.25,bg+.27,1)
    s.Colors[imgui.Col.ScrollbarGrabActive]=imgui.ImVec4(bg+.35,bg+.35,bg+.37,1)
    s.Colors[imgui.Col.CheckMark]=imgui.ImVec4(ar,ag,ab,1)
    s.Colors[imgui.Col.SliderGrab]=imgui.ImVec4(ar*.5,ag*.5,ab*.5,1)
    s.Colors[imgui.Col.SliderGrabActive]=imgui.ImVec4(ar*.7,ag*.7,ab*.7,1)
    s.Colors[imgui.Col.Button]=imgui.ImVec4(bg+.07,bg+.07,bg+.09,1)
    s.Colors[imgui.Col.ButtonHovered]=imgui.ImVec4(ar*.35,ag*.35,ab*.35,1)
    s.Colors[imgui.Col.ButtonActive]=imgui.ImVec4(ar*.5,ag*.5,ab*.5,1)
    s.Colors[imgui.Col.Header]=imgui.ImVec4(ar*.2,ag*.2,ab*.2,1)
    s.Colors[imgui.Col.HeaderHovered]=imgui.ImVec4(ar*.35,ag*.35,ab*.35,1)
    s.Colors[imgui.Col.HeaderActive]=imgui.ImVec4(ar*.5,ag*.5,ab*.5,1)
    s.Colors[imgui.Col.Separator]=imgui.ImVec4(bg+.12,bg+.12,bg+.14,1)
    s.Colors[imgui.Col.Tab]=imgui.ImVec4(bg+.03,bg+.03,bg+.05,1)
    s.Colors[imgui.Col.TabHovered]=imgui.ImVec4(ar*.4,ag*.4,ab*.4,1)
    s.Colors[imgui.Col.TabActive]=imgui.ImVec4(ar*.3,ag*.3,ab*.3,1)
    s.Colors[imgui.Col.ModalWindowDimBg]=imgui.ImVec4(.1,.1,.1,.85)
end

function onScriptTerminate(s, q)
    if s==thisScript() then
        save_log()
        save_settings()
        if not q and not reload_script then
            sampAddChatMessage('[Family Helper] {ffffff}\xd5\xe5\xeb\xef\xe5\xf0 \xee\xf1\xf2\xe0\xed\xee\xe2\xeb\xe5\xed!', message_color)
        end
    end
end
