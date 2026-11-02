local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local utf8_to_cp_tbl = {}
for code = 0x0410, 0x044F do utf8_to_cp_tbl[code] = code - 0x0410 + 0xC0 end
utf8_to_cp_tbl[0x0401] = 0xA8
utf8_to_cp_tbl[0x0451] = 0xB8
local cp_to_utf8_tbl = {}
for code = 0x0410, 0x044F do cp_to_utf8_tbl[code - 0x0410 + 0xC0] = code end
cp_to_utf8_tbl[0xA8] = 0x0401
cp_to_utf8_tbl[0xB8] = 0x0451
local function isValidUTF8(s)
    if type(s) ~= 'string' or s == '' then return false end
    local i, n = 1, #s
    while i <= n do
        local b = s:byte(i)
        if b < 0x80 then i = i + 1
        elseif b >= 0xC0 and b <= 0xDF then
            if i + 1 > n then return false end
            local b2 = s:byte(i + 1)
            if b2 < 0x80 or b2 > 0xBF then return false end
            i = i + 2
        elseif b >= 0xE0 and b <= 0xEF then
            if i + 2 > n then return false end
            local b2, b3 = s:byte(i + 1), s:byte(i + 2)
            if b2 < 0x80 or b2 > 0xBF or b3 < 0x80 or b3 > 0xBF then return false end
            i = i + 3
        else return false end
    end
    return true
end
function utf8_to_cp(s)
    if type(s) ~= 'string' or s == '' then return s end
    if not isValidUTF8(s) then return s end
    local out, n_out = {}, 0
    local i, n = 1, #s
    while i <= n do
        local b = s:byte(i)
        if b < 0x80 then n_out = n_out + 1; out[n_out] = string.char(b); i = i + 1
        elseif b >= 0xC0 and b <= 0xDF and i + 1 <= n then
            local b2 = s:byte(i + 1)
            if b2 >= 0x80 and b2 <= 0xBF then
                local code = (b - 0xC0) * 0x40 + (b2 - 0x80)
                local cp = utf8_to_cp_tbl[code]
                n_out = n_out + 1; out[n_out] = string.char(cp or 0x3F); i = i + 2
            else n_out = n_out + 1; out[n_out] = string.char(b); i = i + 1 end
        else n_out = n_out + 1; out[n_out] = string.char(b); i = i + 1 end
    end
    return table.concat(out)
end
function cp_to_utf8(s)
    if type(s) ~= 'string' or s == '' then return s end
    if isValidUTF8(s) then return s end
    local out, n_out = {}, 0
    for i = 1, #s do
        local b = s:byte(i)
        local cp = cp_to_utf8_tbl[b]
        if cp then n_out = n_out + 1; out[n_out] = string.char(0xC0 + math.floor(cp / 0x40), 0x80 + (cp % 0x40))
        else n_out = n_out + 1; out[n_out] = string.char(b) end
    end
    return table.concat(out)
end
function chat_str(s) return utf8_to_cp(s) end
function chat_add(text, color) sampAddChatMessage(utf8_to_cp(text), color or -1) end
function has_cyrillic(s)
    if type(s) ~= 'string' then return false end
    return s:find('[\128-\255]') ~= nil
end
function match_any_group(q, patterns)
    if type(q) ~= 'string' or q == '' then return false end
    local q_cp, q_utf = utf8_to_cp(q), cp_to_utf8(q)
    for i = 1, #patterns do
        local p = patterns[i]
        if type(p) == 'string' and p ~= '' then
            local p_cp, p_utf = utf8_to_cp(p), cp_to_utf8(p)
            if q_cp:find(p_cp, 1, true) or q_cp:find(p_utf, 1, true)
               or q_utf:find(p_cp, 1, true) or q_utf:find(p_utf, 1, true) then
                return true
            end
        end
    end
    return false
end
function compile_group(patterns)
    local compiled = {}
    for i = 1, #patterns do
        local p = patterns[i]
        if type(p) == 'string' and p ~= '' then
            compiled[#compiled + 1] = { utf8_to_cp(p), cp_to_utf8(p) }
        end
    end
    return compiled
end
function match_compiled(q, compiled)
    if type(q) ~= 'string' or q == '' then return false end
    local q_cp, q_utf = utf8_to_cp(q), cp_to_utf8(q)
    for i = 1, #compiled do
        local a, b = compiled[i][1], compiled[i][2]
        if q_cp:find(a, 1, true) or (b ~= a and q_cp:find(b, 1, true))
           or q_utf:find(a, 1, true) or (b ~= a and q_utf:find(b, 1, true)) then
            return true
        end
    end
    return false
end
function bamnuc(s)
    if type(s) ~= 'string' then return '' end
    local b = {}
    for i = 1, #s do
        local c = s:byte(i)
        if c >= 192 and c <= 223 then c = c + 32
        elseif c == 168 then c = 184
        elseif c >= 65 and c <= 90 then c = c + 32 end
        b[i] = string.char(c)
    end
    return table.concat(b)
end
lower1251 = bamnuc
function pinokio(s)
    if type(s) ~= 'string' then return '' end
    return (bamnuc(s:gsub('{[^}]*}', '')):gsub('%s', ''))
end
function strip_color(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub('{[^}]*}', ''))
end
script_name(u8'zumi (бот на тср)')
script_author(u8'pinokio')
script_version('1')
script_description(u8'тср-бот: мусор, еда, стирка, ящики. Автоответчик, антиадмин, телеграм.')
local tsr_sep = (MONET_VERSION == nil) and '\\' or '/'
local tsr_cfg_dir = getWorkingDirectory() .. tsr_sep .. 'config' .. tsr_sep .. 'tsr'
if not doesDirectoryExist(tsr_cfg_dir) then createDirectory(tsr_cfg_dir) end
local function tsr_cfg_file(name) return 'tsr' .. tsr_sep .. name end
local imgui = require('mimgui')
local new = imgui.new
local fa = require('fAwesome6_solid')
local ffi = require('ffi')
local hook = require('monethook')
local inicfg = require('inicfg')
local samem_ok, samem = pcall(require, 'SAMemory')
if samem_ok then pcall(function() require('SAMemory.shared').require('CObject') end) end
if samem_ok then pcall(function() require('SAMemory.shared').require('CPed') end) end
local sampev = require('lib.samp.events')
local ImVec2 = imgui.ImVec2
local ImVec4 = imgui.ImVec4
function ico(name)
    local ok, v = pcall(function() return fa[name] end)
    if ok and type(v) == 'string' then return v end
    return ''
end
is_x64_build = false

arch_check = (function()
    local m = { architecture = 'unknown', warning_open = new.bool(false), handled = false, timer_start = 0 }
    function m.detect()
        if ffi.abi then
            local ok, is64 = pcall(ffi.abi, '64bit')
            if ok then return is64 and 'x64' or 'x32' end
        end
        return 'unknown'
    end
    function m.mark_read()
        cfg.misc.arch_warned = true
        if type(save_cfg) == 'function' then pcall(save_cfg) end
    end
    function m.delete_script()
        local ok = pcall(function()
            local path = thisScript().path
            if not path or path == '' then error('no path') end
            if not os.remove(path) then error('remove failed') end
        end)
        if ok then
            m.warning_open[0] = false
            lua_thread.create(function() wait(100); pcall(function() thisScript():unload() end) end)
        end
    end
    return m
end)()
effil_ok, effil = pcall(require, 'effil')
json = { parse = function(data) local ok, res = pcall(function() return decodeJson(data) end); if ok then return res else return nil end end }
function url_enc8(str)
    if not str then return '' end
    local s = tostring(str)
    s = s:gsub('\n', '%%0A'):gsub(' ', '%%20')
    s = s:gsub('([^%w%-_%.~%%])', function(c) return string.format('%%%02X', string.byte(c)) end)
    return s
end
function req_runner()
    return effil.thread(function(u, a)
        local https = require 'ssl.https'
        local ok, result
        if a == nil then ok, result = pcall(https.request, u)
        else ok, result = pcall(https.request, u, a) end
        if ok then return {true, result} else return {false, tostring(result)} end
    end)
end
function th_handle(runner, url, args, resolve, reject)
    local t = runner(url, args)
    local r = t:get(0)
    while not r do r = t:get(0); wait(0) end
    local status = t:status()
    if status == 'completed' then
        local ok, result = r[1], r[2]
        if ok then if resolve then resolve(result) end
        else if reject then reject(result) end end
    elseif status == 'canceled' then if reject then reject('canceled') end
    else if reject then reject('unknown_status:'..tostring(status)) end end
    t:cancel(0)
end
function http_async(url, args, resolve, reject)
    if not effil_ok then if reject then reject('effil not found') end return end
    local runner = req_runner()
    if not reject then reject = function() end end
    lua_thread.create(function() th_handle(runner, url, args, resolve, reject) end)
end
tg_cfg = inicfg.load({ settings = { token = '', chat_id = '', enabled = false, log_admin = false } }, tsr_cfg_file('TSRM_telegram'))
function save_tg_cfg() inicfg.save(tg_cfg, tsr_cfg_file('TSRM_telegram')) end
function tg_send(token, chat_id, text)
    if not token or token == '' or not chat_id or chat_id == '' then return end
    local url = string.format('https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s', token, chat_id, url_enc8(text))
    http_async(url, '', function(res) end, function(err) end)
end
function tg_send_photo(token, chat_id, photo_url, caption)
    if not token or token == '' or not chat_id or chat_id == '' then return end
    local url = string.format('https://api.telegram.org/bot%s/sendPhoto?chat_id=%s&photo=%s&caption=%s', token, chat_id, url_enc8(photo_url), url_enc8(caption or ''))
    http_async(url, '', function(res) end, function(err) end)
end
function tg_send_btns(token, chat_id, text, buttons)
    if not token or token == '' or not chat_id or chat_id == '' then return end
    local rows = {}
    for _, row in ipairs(buttons) do
        local btns = {}
        for _, b in ipairs(row) do
            table.insert(btns, string.format('{"text":"%s","callback_data":"%s"}', b.text:gsub('"', '\\"'), b.data:gsub('"', '\\"')))
        end
        table.insert(rows, '[' .. table.concat(btns, ',') .. ']')
    end
    local markup = '{"inline_keyboard":[' .. table.concat(rows, ',') .. ']}'
    local url = string.format('https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s&reply_markup=%s', token, chat_id, url_enc8(text), url_enc8(markup))
    http_async(url, '', function(res) end, function(err) end)
end
function tg_bot_menu()
    if not tg_cfg.settings.enabled then return end
    if not tg_cfg.settings.token or tg_cfg.settings.token == '' then return end
    if not tg_cfg.settings.chat_id or tg_cfg.settings.chat_id == '' then return end
    local text = u8'Меню управления ботом'
    local buttons = {
        { { text = u8'Прогресс работы', data = 'work_progress' },
          { text = u8'Выключить бота', data = 'bot_stop' } }
    }
    tg_send_btns(tg_cfg.settings.token, tg_cfg.settings.chat_id, text, buttons)
end
gta = ffi.load('GTASA')
ffi.cdef[[
void*  _ZN4CPad6GetPadEi(int num);
uint8_t _ZN4CPad9GetSprintEi(void* thiz, int playerid);
int8_t  _ZN4CPad12JumpJustDownEv(void* thiz);
int8_t  _ZN4CPad12DuckJustDownEP4CPed(void* thiz, void* ped);
]]
local_pad = nil
is_running, do_jump_this_frame = false, false
do_duck_press = false
orig_sprint, orig_jump = nil, nil
orig_duck_down = nil
sj_disabled = false
hook_conf_win = new.bool(false)
function sprint_hook(thiz, pid)
    if sj_disabled then if orig_sprint == nil then return 0 end; return orig_sprint(thiz, pid) end
    if is_running and pid == 0 then return 1 end
    if orig_sprint == nil then return 0 end
    return orig_sprint(thiz, pid)
end
function jump_hook(thiz)
    if sj_disabled then if orig_jump == nil then return false end; return orig_jump(thiz) end
    if do_jump_this_frame and thiz == local_pad then do_jump_this_frame = false; return true end
    if orig_jump == nil then return false end
    return orig_jump(thiz)
end
function duck_down_hook(thiz, ped)
    if sj_disabled then if orig_duck_down == nil then return 0 end; return orig_duck_down(thiz, ped) end
    if do_duck_press and thiz == local_pad then do_duck_press = false; return 1 end
    if orig_duck_down == nil then return 0 end
    return orig_duck_down(thiz, ped)
end
function press_duck()
    lua_thread.create(function()
        for i = 1, 6 do do_duck_press = true; wait(0); wait(25) end
        do_duck_press = false
    end)
end
hook_flag = tsr_cfg_dir .. tsr_sep .. 'hook_retry.flag'
hook_ttl = 30
function inst_hooks()
    local_pad = gta._ZN4CPad6GetPadEi(0)
    local ok1, err1 = pcall(function()
        orig_sprint = hook.new('uint8_t(*)(void*, int)', sprint_hook, ffi.cast('uintptr_t', ffi.cast('void*', gta._ZN4CPad9GetSprintEi)))
    end)
    if not ok1 then chat_add('{FF5555}[zumi] Не удалось поставить хук бега: ' .. chat_str(tostring(err1)), -1) end
    local ok2, err2 = pcall(function()
        orig_jump = hook.new('int8_t(*)(void*)', jump_hook, ffi.cast('uintptr_t', ffi.cast('void*', gta._ZN4CPad12JumpJustDownEv)))
    end)
    if not ok2 then chat_add('{FF5555}[zumi] Не удалось поставить хук прыжка: ' .. chat_str(tostring(err2)), -1) end
    local ok3, err3 = pcall(function()
        orig_duck_down = hook.new('int8_t(*)(void*, void*)', duck_down_hook, ffi.cast('uintptr_t', ffi.cast('void*', gta._ZN4CPad12DuckJustDownEP4CPed)))
    end)
    if not ok3 then chat_add('{FFCC55}[zumi] Хук приседа не встал: ' .. chat_str(tostring(err3)), -1) end
    if ok1 and ok2 then
        chat_add('{55FF55}[zumi] Хуки установлены.', -1)
        pcall(os.remove, hook_flag)
    else
        local was_retried = false
        local f = io.open(hook_flag, 'r')
        if f then
            local ts = tonumber(f:read('*a')); f:close()
            if ts and os.time() - ts < hook_ttl then was_retried = true end
        end
        if not was_retried then
            local wf = io.open(hook_flag, 'w')
            if wf then wf:write(tostring(os.time())); wf:close() end
            chat_add('{FFCC55}[zumi] Хуки не встали, перезапуск.', -1)
            lua_thread.create(function() wait(300); pcall(function() thisScript():reload() end) end)
        else
            pcall(os.remove, hook_flag); sj_disabled = true; hook_conf_win[0] = true
        end
    end
end
cfg = inicfg.load({
    ui = {
        accent_r = 0.96, accent_g = 0.56, accent_b = 0.72, accent_a = 1,
        bg_r = 0.13, bg_g = 0.07, bg_b = 0.13, bg_a = 0.96,
        text_r = 1.00, text_g = 0.95, text_b = 0.97, text_a = 1,
        tab_r = 0.87, tab_g = 0.76, tab_b = 0.84, tab_a = 1,
        win_w = 1285, win_h = 691, win_x = -68, win_y = 358,
        tabs_side = 'left', tabs_width = 156, scrollbar_size = 28,
        window_rounding = 19, frame_rounding = 13,
        child_rounding = 28, popup_rounding = 40,
        tab_rounding = 38, grab_rounding = 39, scrollbar_rounding = 40,
        window_pad_x = 15, window_pad_y = 14,
        frame_pad_x = 7, frame_pad_y = 5,
        item_sp_x = 0, item_sp_y = 8,
        inner_sp_x = 12, inner_sp_y = 5,
        indent_sp = 19, grab_min_size = 5, border_thickness = 5,
        tab_height = 80, tab_gap = 2, tab_pad_left = 0, tab_pad_top = 0,
        text_scale = 1, title_show = true, title_scale = 1, order = '1,5,6,7,8,9',
    },
    bot = { max_search = 200, avoid_obstacles = false, alt_pickup = true, jump = true, run = true, pickup_radius = 1.5, handin_radius = 0.5 },
    laundry = { max_search = 150, avoid_obstacles = false, machine_radius = 0.3, wait_radius = 4, chat_timeout = 8, scan_interval = 0.3, collision_2315 = true, collision_2994 = true, machine_cooldown = 130, enabled = true, pickup_radius = 0.5, run = false },
    food = { run = false, jump = false, avoid_obstacles = true, avoid_mode = 1, pickup_radius = 0.5, oven_radius = 0.5, fridge_radius = 0.5, max_search = 150, recheck_radius = 3.0, alt_dwell = 1.4, chat_timeout = 15, dialog_wait = 1.5, fridge_confirm_timeout = 8, oven_dialog_give_up = 6, search_stuck_timeout = 15 },
    box = { avoid_obstacles = false, run = true },
    autofood = { threshold_max = 38, enabled = false, food_type = 2, threshold = 25 },
    healbot = { notify_on_hit = true, auto_heal = true },
    tsrhelper = { auto_rm_cell = true, auto_rm_door = false, auto_rm_fence = false, render_lockpick = false, chips_amount = 56 },
    antiadmin = { smart_reply = true, auto_exit = false, auto_exit_delay_min = 4, auto_exit_delay_max = 8 },
    behavior = { micro_pauses = false, miss_chance = 10 },
    mini_hud = { locked = false, enabled = false, win_x = -1, win_y = -1, last_bot = 'bot' },
    misc = { player_collision_off = false, arch_warned = false },
    hooks = { anti_stamina = false },
}, tsr_cfg_file('TSRM_config'))
if cfg.ui.tabs_side ~= 'left' and cfg.ui.tabs_side ~= 'right' then cfg.ui.tabs_side = 'left' end
if cfg.bot.avoid_obstacles == nil then cfg.bot.avoid_obstacles = true end
if cfg.laundry.avoid_obstacles == nil then cfg.laundry.avoid_obstacles = true end
if cfg.food.avoid_obstacles == nil then cfg.food.avoid_obstacles = true end
if cfg.box == nil then cfg.box = {} end
if cfg.box.avoid_obstacles == nil then cfg.box.avoid_obstacles = true end
if cfg.hooks == nil then cfg.hooks = {} end
if cfg.hooks.anti_stamina == nil then cfg.hooks.anti_stamina = false end
cfg.food.avoid_mode = 1
if cfg.bot.run == nil then cfg.bot.run = true end
if cfg.laundry.run == nil then cfg.laundry.run = true end
if cfg.food.run == nil then cfg.food.run = true end
if cfg.box.run == nil then cfg.box.run = true end
if cfg.antiadmin.auto_exit == nil then cfg.antiadmin.auto_exit = false end
if cfg.behavior.miss_chance == nil then cfg.behavior.miss_chance = 10 end
if cfg.mini_hud.last_bot == nil then cfg.mini_hud.last_bot = 'bot' end
cfg.food.max_search = 150; cfg.food.jump = false; cfg.food.dialog_wait = 3
cfg.food.pickup_radius = 0.5; cfg.food.run = false; cfg.food.chat_timeout = 8
cfg.food.fridge_confirm_timeout = 8; cfg.food.alt_dwell = 1.4; cfg.food.recheck_radius = 3
if cfg.food.oven_dialog_give_up == nil then cfg.food.oven_dialog_give_up = 6 end
if cfg.food.search_stuck_timeout == nil then cfg.food.search_stuck_timeout = 15 end
cfg.food.avoid_obstacles = true; cfg.food.oven_radius = 0.5; cfg.food.fridge_radius = 0.5
cfg.laundry.pickup_radius = 0.5; cfg.laundry.machine_radius = 0.3
function save_cfg() inicfg.save(cfg, tsr_cfg_file('TSRM_config')) end
tick_cache = { px = 0, py = 0, pz = 0, updated_at = 0, chars = {}, chars_updated_at = 0, objects = {}, objects_updated_at = 0, texts = {}, texts_updated_at = 0, my_id = -1, my_id_updated_at = 0 }
lua_thread.create(function()
    while true do
        wait(0)
        local now = os.clock()
        if doesCharExist(PLAYER_PED) then
            local x, y, z = getCharCoordinates(PLAYER_PED)
            if x then tick_cache.px, tick_cache.py, tick_cache.pz = x, y, z end
            tick_cache.updated_at = now
        end
    end
end)
lua_thread.create(function()
    while true do
        wait(250)
        local ok, chars = pcall(getAllChars)
        if ok and chars then tick_cache.chars = chars; tick_cache.chars_updated_at = os.clock() end
    end
end)
lua_thread.create(function()
    while true do
        wait(500)
        local ok, objs = pcall(getAllObjects)
        if ok and objs then tick_cache.objects = objs; tick_cache.objects_updated_at = os.clock() end
    end
end)
lua_thread.create(function()
    while true do
        wait(300)
        local list = {}
        local n = 0
        for i = 0, 2048 do
            if sampIs3dTextDefined(i) then
                local t, c, x, y, z = sampGet3dTextInfoById(i)
                if t and type(x) == 'number' then
                    n = n + 1
                    list[n] = { id = i, text = t, color = c, x = x, y = y, z = z }
                end
            end
        end
        tick_cache.texts = list
        tick_cache.texts_updated_at = os.clock()
    end
end)
lua_thread.create(function()
    while true do
        wait(2000)
        local id = -1
        if LOCAL_PLAYER_ID and type(LOCAL_PLAYER_ID) == 'number' and LOCAL_PLAYER_ID >= 0 then id = LOCAL_PLAYER_ID
        else
            local pcall_ok, ok, got = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
            if pcall_ok and ok and type(got) == 'number' and got >= 0 then id = got end
        end
        tick_cache.my_id = id
        tick_cache.my_id_updated_at = os.clock()
    end
end)
lua_thread.create(function()
    while true do
        wait(250)
        if samem_ok and not is_x64_build and (cfg.laundry.collision_2315 or cfg.laundry.collision_2994) then
            local objs = tick_cache.objects
            for i = 1, #objs do
                local obj = objs[i]
                if doesObjectExist(obj) then
                    local m = getObjectModel(obj)
                    if (m == 2315 and cfg.laundry.collision_2315) or (m == 2994 and cfg.laundry.collision_2994) then
                        local ok, cobject = pcall(samem.cast, 'CObject*', getObjectPointer(obj))
                        if ok and cobject then cobject.bUsesCollision = 0; cobject.bCollisionProcessed = 0 end
                    end
                end
            end
        end
        if samem_ok and not is_x64_build and cfg.misc.player_collision_off then
            local chars = tick_cache.chars
            for i = 1, #chars do
                local ped = chars[i]
                if ped ~= PLAYER_PED and doesCharExist(ped) then
                    local okp, cped = pcall(samem.cast, 'CPed*', getCharPointer(ped))
                    if okp and cped then cped.bUsesCollision = 0; cped.bCollisionProcessed = 0 end
                end
            end
        end
    end
end)
function get_my_id() return tick_cache.my_id end
function my_player_id() return tick_cache.my_id end
function get_player_pos() return tick_cache.px, tick_cache.py, tick_cache.pz end
function my_fmt_nick()
    local id = tick_cache.my_id
    if not id or id < 0 then return nil end
    local okn, nick = pcall(sampGetPlayerNickname, id)
    if not okn or type(nick) ~= 'string' or nick == '' then return nil end
    return nick
end
function nick_to_name_comma(nick)
    if type(nick) ~= 'string' or nick == '' then return nick end
    local base = nick:gsub('_', ' ')
    return base .. ',' .. base:lower()
end
function los_clear(x1, y1, z1, x2, y2, z2)
    if not processLineOfSight then return true end
    local ok, hit = pcall(processLineOfSight, x1, y1, z1, x2, y2, z2, true, true, true, false, false, false, false)
    if not ok then return true end
    return not hit
end
function find_near_id(radius)
    local my_ped = PLAYER_PED
    local px, py, pz = get_player_pos()
    local chars = tick_cache.chars
    local best_id, best_dist = nil, radius
    for i = 1, #chars do
        local ped = chars[i]
        if ped ~= my_ped and doesCharExist(ped) then
            local pcall_ok, ok_id, other_id = pcall(sampGetPlayerIdByCharHandle, ped)
            if pcall_ok and ok_id and type(other_id) == 'number' then
                local cok, cx, cy, cz = pcall(getCharCoordinates, ped)
                if cok and cx then
                    local d = getDistanceBetweenCoords3d(px, py, pz, cx, cy, cz)
                    if d <= best_dist and los_clear(px, py, pz + 0.6, cx, cy, cz + 0.6) then
                        best_id, best_dist = other_id, d
                    end
                end
            end
        end
    end
    return best_id
end
function find_admin_nick(text)
    return text:match('A:%s*%[([%w_]+)%]')
        or text:match('Администратор%s+([%w_]+)')
        or text:match('([%w_]+)%s*%(Администратор%)')
end
last_sent = {}
function pick_random(list, anti_repeat_key)
    if type(list) ~= 'table' or #list == 0 then return nil end
    local chosen
    if #list == 1 then chosen = list[1]
    else
        for _ = 1, 8 do
            chosen = list[math.random(1, #list)]
            if not anti_repeat_key or chosen ~= last_sent[anti_repeat_key] then break end
        end
        if chosen == last_sent[anti_repeat_key] then chosen = list[math.random(1, #list)] end
    end
    if anti_repeat_key then last_sent[anti_repeat_key] = chosen end
    return chosen
end
function delay_by_length(text)
    local n = #tostring(text or '')
    if n < 20 then return 1.0
    elseif n < 50 then return 2.0 + math.random() * 1.0
    else return 4.0 + math.random() * 1.0 end
end
admin_test_mode = false
admin_test_token = 0
local KEY_ROW = {
    ['й']=1, ['ц']=1, ['у']=1, ['к']=1, ['е']=1, ['н']=1, ['г']=1, ['ш']=1, ['щ']=1, ['з']=1, ['х']=1, ['ъ']=1,
    ['ф']=2, ['ы']=2, ['в']=2, ['а']=2, ['п']=2, ['р']=2, ['о']=2, ['л']=2, ['д']=2, ['ж']=2, ['э']=2,
    ['я']=3, ['ч']=3, ['с']=3, ['м']=3, ['и']=3, ['т']=3, ['ь']=3, ['б']=3, ['ю']=3, ['.']=3,
}
local KEY_COL = {
    ['й']=1, ['ц']=2, ['у']=3, ['к']=4, ['е']=5, ['н']=6, ['г']=7, ['ш']=8, ['щ']=9, ['з']=10, ['х']=11, ['ъ']=12,
    ['ф']=1, ['ы']=2, ['в']=3, ['а']=4, ['п']=5, ['р']=6, ['о']=7, ['л']=8, ['д']=9, ['ж']=10, ['э']=11,
    ['я']=1, ['ч']=2, ['с']=3, ['м']=4, ['и']=5, ['т']=6, ['ь']=7, ['б']=8, ['ю']=9, ['.']=10,
}
function apply_typo(text)
    if type(text) ~= 'string' or text == '' then return text end
    local positions = {}
    for i = 1, #text do
        local b = text:byte(i)
        if (b >= 0xE0 and b <= 0xFF) or (b >= 0xC0 and b <= 0xDF) or b == 0xB8 or b == 0xA8 then
            positions[#positions + 1] = i
        end
    end
    if #positions == 0 then return text end
    local pos = positions[math.random(1, #positions)]
    local b = text:byte(pos)
    local is_upper = (b >= 0xC0 and b <= 0xDF) or b == 0xA8
    local lower_code = b
    if b >= 0xC0 and b <= 0xDF then lower_code = b + 32
    elseif b == 0xA8 then lower_code = 0xB8 end
    local ch = string.char(lower_code)
    local row, col = KEY_ROW[ch], KEY_COL[ch]
    if not row or not col then return text end
    local candidates = {}
    for k, r in pairs(KEY_ROW) do
        local c = KEY_COL[k]
        if r == row and math.abs(c - col) == 1 then
            candidates[#candidates + 1] = k
        elseif math.abs(r - row) == 1 and math.abs(c - col) <= 1 then
            candidates[#candidates + 1] = k
        end
    end
    if #candidates == 0 then return text end
    local replacement = candidates[math.random(1, #candidates)]
    local rep_byte = replacement:byte(1)
    if is_upper then
        if rep_byte >= 0xE0 and rep_byte <= 0xFF then rep_byte = rep_byte - 32
        elseif rep_byte == 0xB8 then rep_byte = 0xA8 end
    end
    return text:sub(1, pos - 1) .. string.char(rep_byte) .. text:sub(pos + 1)
end
function apply_digit_typo(text)
    if type(text) ~= 'string' or text == '' then return text end
    local positions = {}
    for i = 1, #text do
        local b = text:byte(i)
        if b >= 0x30 and b <= 0x39 then positions[#positions + 1] = i end
    end
    if #positions == 0 then return text end
    local pairs_adj = {}
    for i = 1, #positions - 1 do
        if positions[i + 1] == positions[i] + 1 then
            pairs_adj[#pairs_adj + 1] = { positions[i], positions[i + 1] }
        end
    end
    if #pairs_adj > 0 then
        local p = pairs_adj[math.random(1, #pairs_adj)]
        local a, b = p[1], p[2]
        return text:sub(1, a - 1) .. text:sub(b, b) .. text:sub(a, a) .. text:sub(b + 1)
    end
    local pos = positions[math.random(1, #positions)]
    local d = tonumber(text:sub(pos, pos))
    local nd = d
    while nd == d do nd = math.random(0, 9) end
    return text:sub(1, pos - 1) .. tostring(nd) .. text:sub(pos + 1)
end
function emulate_miss()
    if admin_test_mode then return false end
    return math.random(1, 100) <= (cfg and cfg.behavior.miss_chance or 10)
end
function tg_admin_log(question, answer)
    if admin_test_mode then return end
    if not tg_cfg.settings.log_admin then return end
    if not tg_cfg.settings.enabled then return end
    if not tg_cfg.settings.token or tg_cfg.settings.token == '' then return end
    local msg = '[zumi admin]\nQ: ' .. tostring(question) .. '\nA: ' .. tostring(answer or '<тишина>')
    tg_send(tg_cfg.settings.token, tg_cfg.settings.chat_id, msg)
end
watchdog = { last_q = '', repeat_count = 0 }
function watchdog_check(q)
    if q == watchdog.last_q then watchdog.repeat_count = watchdog.repeat_count + 1
    else watchdog.repeat_count = 0; watchdog.last_q = q end
    return watchdog.repeat_count >= 2
end
work_counter = { field = nil, initial = nil, current = nil, done = 0, initialized = false, bot_name = nil }
function work_counter_reset(bot_name, field)
    work_counter.bot_name = bot_name
    work_counter.field = field
    work_counter.initial = nil
    work_counter.current = nil
    work_counter.done = 0
    work_counter.initialized = false
    tsr_req_sum(function(data)
        local val = data and data[field]
        if val == nil then return end
        work_counter.initial = val
        work_counter.current = val
        work_counter.initialized = true
    end)
end
function work_counter_decrement()
    if work_counter.initialized and work_counter.current and work_counter.current > 0 then
        work_counter.current = work_counter.current - 1
    end
    work_counter.done = work_counter.done + 1
    if mini_hud_data and work_counter.field and mini_hud_data[work_counter.field]
       and mini_hud_data[work_counter.field] > 0 then
        mini_hud_data[work_counter.field] = mini_hud_data[work_counter.field] - 1
    end
end
TRIGGER_GROUPS = {
    { key = 'answers_1', label = u8'Ответы: стадия 1 (спокойные)', default = { u8'Ну да', u8'ну', u8'да', u8'че', u8'что', u8'че надо', u8'я тут', u8'слушаю', u8'да я тут', u8'да, я здесь', u8'что вам надо', u8'че нужно вам от меня', u8'что такое?' } },
    { key = 'answers_2', label = u8'Ответы: стадия 2 (раздраженные)', default = { u8'Я выхожу из тср мб отстанете?', u8'Че вам надо', u8'отвалите уже', u8'да госпади отвалите уже', u8'я здесь не понятно?', u8'хватит уже', u8'хватет уже', u8'хватит', u8'прекратите уже' } },
    { key = 'answers_3', label = u8'Ответы: стадия 3 (предел)', default = { u8'да сколько можно', u8'ты издеваешься?', u8'Отвалите от меня уже', u8'сколько уже можно до меня докапываться', u8'может быть вы не будете меня тролить?', u8'админ,я тут,хватит уже до меня докапываться', u8'плиз,остановись' } },
    { key = 'bot_answers', label = u8'Ответы: "ты бот?"', pair = 'bot_questions', default = { u8'какой бот?', u8'я сам играю', u8'это руки', u8'какой бот, ты о чем', u8'не бот я', u8'с чего ты взял', u8'я обычный игрок' } },
    { key = 'not_reply_answers', label = u8'Ответы: "почему не отвечаешь?"', pair = 'not_reply_questions', default = { u8'да тут я, инет лагает', u8'я тут, просто залип', u8'слышу, тут я', u8'тут я, просто отвлекся', u8'здесь, связь тупит' } },
    { key = 'how_long_answers', label = u8'Ответы: "давно тут?"', pair = 'how_long_questions', default = { u8'полчаса примерно', u8'минут 20', u8'уже давно', u8'с утра', u8'да не считал особо', u8'хз если честно' } },
    { key = 'are_you_here_answers', label = u8'Ответы: "ты тут?"', pair = 'here_questions', default = { u8'да', u8'да, тут', u8'да, здесь', u8'конечно', u8'да конеч', u8'ду, здесь', u8'ды', u8'дадада', u8'ыддывдыж ятутт', u8'здесь' } },
    { key = 'afk_check_answers', label = u8'Ответы: AFK-проверка (диалог)', default = { u8'да я тут', u8'да', u8'здесь', u8'ага тут', u8'тут', u8'да тут я', u8'на месте', u8'здесь я', u8'да да тут', u8'тут конечно', u8'я на месте', u8'ага', u8'здесь конечно', u8'да здесь', u8'тут я', u8'я здесь че надо', u8'че надо,тут я', u8'что такое, я тут' } },
    { key = 'busy_trash', label = u8'Ответы: "что делаешь" - мусор', default = { u8'мусор таскаю', u8'мусор собираю', u8'на мусорке', u8'мусор таскаю, отвали' } },
    { key = 'busy_food', label = u8'Ответы: "что делаешь" - еда', default = { u8'пеку', u8'мясо готовлю', u8'на кухне', u8'у печки стою' } },
    { key = 'busy_laundry', label = u8'Ответы: "что делаешь" - одежда', default = { u8'стираю', u8'одежду стираю', u8'на стирке', u8'у машинки' } },
    { key = 'busy_box', label = u8'Ответы: "что делаешь" - ящики', default = { u8'ящики вожу', u8'грузчиком работаю', u8'ящики таскаю' } },
    { key = 'busy_idle', label = u8'Ответы: "что делаешь" - простой', default = { u8'работаю', u8'фармлю', u8'занят', u8'а тебе что' } },
    { key = 'move_jump', label = u8'Движение: прыгни', default = { u8'прыгни', u8'прыгай', u8'прыжок' } },
    { key = 'move_back', label = u8'Движение: шаг назад', default = { u8'шаг назад', u8'отойди назад', u8'назад шаг' } },
    { key = 'move_fwd', label = u8'Движение: шаг вперед', default = { u8'шаг вперед', u8'шаг вперед', u8'вперед шаг' } },
    { key = 'move_left', label = u8'Движение: шаг влево', default = { u8'шаг влево', u8'влево шаг' } },
    { key = 'move_right', label = u8'Движение: шаг вправо', default = { u8'шаг вправо', u8'вправо шаг' } },
    { key = 'move_crouch', label = u8'Движение: присядь', default = { u8'присядь', u8'сядь', u8'садись' } },
    { key = 'move_run', label = u8'Движение: беги', default = { u8'беги', u8'побежал' } },
    { key = 'move_stop', label = u8'Движение: стой', default = { u8'стой', u8'остановись', u8'стоп' } },
    { key = 'move_turn_left', label = u8'Движение: налево', default = { u8'поверни налево', u8'повернись налево', u8'повернись влево', u8'повернись на лево', u8'развернись налево', u8'развернись влево', u8'налево' } },
    { key = 'move_turn_right', label = u8'Движение: направо', default = { u8'поверни направо', u8'повернись направо', u8'повернись вправо', u8'повернись на право', u8'развернись направо', u8'развернись вправо', u8'направо' } },
    { key = 'move_turn_back', label = u8'Движение: разворот', default = { u8'повернись назад', u8'развернись назад', u8'повернись обратно', u8'развернись обратно', u8'повернись ко мне спиной', u8'повернись тылом' } },
    { key = 'how_much_boxes', label = u8'Вопрос: сколько ящиков', default = { u8'сколько ящиков', u8'сколько осталось ящиков' } },
    { key = 'how_much_food', label = u8'Вопрос: сколько еды', default = { u8'сколько еды', u8'сколько осталось еды', u8'сколько порций' } },
    { key = 'how_much_clothes', label = u8'Вопрос: сколько одежды', default = { u8'сколько одежды', u8'сколько осталось одежды' } },
    { key = 'how_much_trash', label = u8'Вопрос: сколько мусора', default = { u8'сколько мусора', u8'сколько осталось мусора' } },
    { key = 'how_much_minutes', label = u8'Вопрос: сколько минут', default = { u8'сколько осталось минут', u8'сколько минут осталось', u8'сколько сидеть' } },
    { key = 'nick_questions', label = u8'Вопрос: ник', default = { u8'как тебя зовут', u8'как вас зовут', u8'как тебя звать', u8'как вас звать', u8'твой ник', u8'ваш ник', u8'какой у тебя ник', u8'какой у вас ник', u8'назови свой ник', u8'назовите свой ник', u8'скажи свой ник', u8'скажите свой ник', u8'кто ты', u8'кто вы' } },
    { key = 'id_questions', label = u8'Вопрос: айди', default = { u8'твой айди', u8'ваш айди', u8'твой ид', u8'ваш ид', u8'какой у тебя id', u8'какой у вас id', u8'скажи id', u8'скажите id', u8'назови id', u8'назовите id', u8'твой id', u8'ваш id' } },
    { key = 'nearest_questions', label = u8'Вопрос: ближайший игрок', default = { u8'ближайший игрок', u8'ближайшего игрока', u8'кто рядом с тобой', u8'кто рядом с вами', u8'кто ближе всех', u8'кто стоит рядом', u8'кто стоит с тобой', u8'кто стоит с вами', u8'кто около тебя', u8'кто около вас' } },
    { key = 'nearest_nick_hint', label = u8'Уточнение: ближайший ник', default = { u8'ник', u8'никнейм', u8'зовут', u8'звать' } },
    { key = 'level_questions', label = u8'Вопрос: "какой уровень" (запускает /stats)', default = { u8'какой у тебя уровень', u8'твой уровень', u8'какой уровень' } },
    { key = 'my_nick_questions', label = u8'Вопрос: "какой у меня ник"', default = { u8'какой у меня ник', u8'как меня зовут', u8'мой ник' } },
    { key = 'bot_questions', label = u8'Вопрос: "ты бот?"', hidden = true, default = { u8'ты бот', u8'ты читер', u8'ты скрипт', u8'ты авто' } },
    { key = 'what_doing_questions', label = u8'Вопрос: "что делаешь"', default = { u8'что делаешь', u8'чем занят', u8'чем занимаешься' } },
    { key = 'not_reply_questions', label = u8'Вопрос: "почему не отвечаешь?"', hidden = true, default = { u8'почему не отвечаешь', u8'ты спишь', u8'спишь?', u8'ты тут вообще' } },
    { key = 'afk_questions', label = u8'Вопрос: "ты афк?"', default = { u8'ты афк', u8'ты afk', u8'афк?' } },
    { key = 'how_long_questions', label = u8'Вопрос: "давно тут?"', hidden = true, default = { u8'сколько ты тут сидишь', u8'давно тут', u8'сколько играешь' } },
    { key = 'exit_soon_questions', label = u8'Вопрос: "скоро выйдешь?"', default = { u8'ты скоро выйдешь', u8'когда выйдешь' } },
    { key = 'here_questions', label = u8'Вопрос: "ты тут?"', hidden = true, default = { u8'ты тут', u8'ты здесь', u8'онлайн?', u8'здесь?' } },
}
triggers_store = {}
trigger_cfg = inicfg.load({ data = {} }, tsr_cfg_file('TSRM_trigger_groups'))
function triggers_init()
    for _, g in ipairs(TRIGGER_GROUPS) do
        local saved = trigger_cfg.data and trigger_cfg.data[g.key]
        if type(saved) == 'string' and saved ~= '' then
            local list = {}
            for chunk in (saved .. '\2'):gmatch('(.-)\2') do
                if chunk ~= '' then table.insert(list, chunk) end
            end
            triggers_store[g.key] = list
        else
            local list = {}
            for i, v in ipairs(g.default) do list[i] = v end
            triggers_store[g.key] = list
        end
    end
end
function triggers_save()
    local data = {}
    for _, g in ipairs(TRIGGER_GROUPS) do
        local list = triggers_store[g.key] or {}
        data[g.key] = table.concat(list, '\2')
    end
    trigger_cfg.data = data
    inicfg.save(trigger_cfg, tsr_cfg_file('TSRM_trigger_groups'))
    if rebuild_dynamic_compiled then rebuild_dynamic_compiled() end
end
function triggers_reset_group(key)
    for _, g in ipairs(TRIGGER_GROUPS) do
        if g.key == key then
            local list = {}
            for i, v in ipairs(g.default) do list[i] = v end
            triggers_store[key] = list
            triggers_save()
            return
        end
    end
end
triggers_init()
compiled_dynamic = {}
function rebuild_dynamic_compiled()
    compiled_dynamic = {
        admin        = compile_group({ 'телепортировал вас на координаты', 'Администратор ', 'ответил вам:', 'вас заспавнил', 'вызывает вас на собеседование', 'выдал вам предупреждение', 'предупреждение выдано', 'заблокировал вас', 'заблокирован администратором', 'кикнул вас', 'кик от администратора' }),
        nick         = compile_group(triggers_store.nick_questions),
        id           = compile_group(triggers_store.id_questions),
        nearest      = compile_group(triggers_store.nearest_questions),
        nearest_hint = compile_group(triggers_store.nearest_nick_hint),
        move         = {
            jump = compile_group(triggers_store.move_jump), back = compile_group(triggers_store.move_back),
            fwd = compile_group(triggers_store.move_fwd), left = compile_group(triggers_store.move_left),
            right = compile_group(triggers_store.move_right), crouch = compile_group(triggers_store.move_crouch),
            run = compile_group(triggers_store.move_run), stop = compile_group(triggers_store.move_stop),
            turn_left = compile_group(triggers_store.move_turn_left), turn_right = compile_group(triggers_store.move_turn_right),
            turn_back = compile_group(triggers_store.move_turn_back),
        },
        how_much = {
            boxes = compile_group(triggers_store.how_much_boxes), food = compile_group(triggers_store.how_much_food),
            clothes = compile_group(triggers_store.how_much_clothes), trash = compile_group(triggers_store.how_much_trash),
            minutes = compile_group(triggers_store.how_much_minutes),
        },
        level_q = compile_group(triggers_store.level_questions),
        my_nick_q = compile_group(triggers_store.my_nick_questions),
        bot_q = compile_group(triggers_store.bot_questions),
        what_doing = compile_group(triggers_store.what_doing_questions),
        not_reply = compile_group(triggers_store.not_reply_questions),
        afk_q = compile_group(triggers_store.afk_questions),
        how_long = compile_group(triggers_store.how_long_questions),
        exit_soon = compile_group(triggers_store.exit_soon_questions),
        here_q = compile_group(triggers_store.here_questions),
    }
end
rebuild_dynamic_compiled()
custom_triggers = {}
local custom_trig_path = tsr_cfg_dir .. tsr_sep .. 'custom_triggers.txt'
trig_fire_log = {}
local TRIG_FIRE_LOG_MAX = 100
function log_trigger_fire(words, kind)
    table.insert(trig_fire_log, 1, { words = words, kind = kind, time = os.time() })
    if #trig_fire_log > TRIG_FIRE_LOG_MAX then table.remove(trig_fire_log) end
end
function save_custom_triggers()
    local f = io.open(custom_trig_path, 'w')
    if not f then return end
    for _, t in ipairs(custom_triggers) do
        local function esc(x)
            x = tostring(x or '')
            x = x:gsub('\\', '\\\\'):gsub('\n', '\\n'):gsub('\r', '\\r')
            x = x:gsub('\t', '\\t'):gsub('|', '\\|')
            return x
        end
        local active_flag = (t.active == false) and '0' or '1'
        f:write(esc(t.words) .. '|' .. esc(t.kind or 'reply') .. '|' .. esc(t.value or '') .. '|' .. esc(t.extra or '')
            .. '|' .. tostring(t.created_at or os.time()) .. '|' .. active_flag .. '|' .. esc(t.tags or '') .. '\n')
    end
    f:close()
end
function load_custom_triggers()
    custom_triggers = {}
    local f = io.open(custom_trig_path, 'r')
    if not f then return end
    for line in f:lines() do
        local function unesc(x)
            x = x:gsub('\\n', '\n'):gsub('\\r', '\r')
            x = x:gsub('\\t', '\t'):gsub('\\|', '|')
            x = x:gsub('\\\\', '\\')
            return x
        end
        local parts = {}
        for p in (line .. '|'):gmatch('(.-)|') do parts[#parts+1] = p end
        if #parts >= 4 then
            table.insert(custom_triggers, {
                words = unesc(parts[1]),
                kind  = unesc(parts[2]),
                value = unesc(parts[3]),
                extra = unesc(parts[4]),
                created_at = tonumber(parts[5]) or os.time(),
                active = (parts[6] == nil or parts[6] == '' or parts[6] == '1'),
                tags = parts[7] and unesc(parts[7]) or '',
                session_hits = 0,
            })
        end
    end
    f:close()
end
load_custom_triggers()
function migrate_custom_action_presets()
    local OLD_CODE = {
        fwd = 'setGameKeyState(1, -255); wait(800); setGameKeyState(1, 0)',
        back = 'setGameKeyState(1, 255); wait(800); setGameKeyState(1, 0)',
        run = 'is_running = true; setGameKeyState(1, -255); wait(2000); setGameKeyState(1, 0); is_running = false',
    }
    local changed = false
    for _, ct in ipairs(custom_triggers) do
        if ct.kind == 'action' and ct.value and OLD_CODE[ct.value] and ct.extra == OLD_CODE[ct.value] then
            ct.extra = custom_action_code(ct.value)
            changed = true
        end
    end
    if changed then save_custom_triggers() end
end
function split_by_comma(s)
    local out = {}
    for w in tostring(s or ''):gmatch('([^,]+)') do
        local t = w:match('^%s*(.-)%s*$')
        if t ~= '' then table.insert(out, t) end
    end
    return out
end
function duplicate_custom_trigger(idx)
    local src = custom_triggers[idx]
    if not src then return end
    local words_out = {}
    for _, w in ipairs(split_by_comma(src.words)) do
        table.insert(words_out, w .. u8'_copy')
    end
    table.insert(custom_triggers, idx + 1, {
        words = table.concat(words_out, ', '),
        kind = src.kind,
        value = src.value,
        extra = src.extra,
        tags = src.tags,
        active = src.active,
        created_at = os.time(),
        session_hits = 0,
    })
    save_custom_triggers()
    chat_add('{55FF55}[mytrig] Триггер скопирован.', -1)
end
CUSTOM_ACTIONS = {
    { id = 'jump',       label = u8'Прыжок',             code = 'do_jump_this_frame = true' },
    { id = 'crouch',     label = u8'Присесть',           code = 'press_duck()' },
    { id = 'fwd',        label = u8'Шаг вперед',         code = 'press_fwd(800, false)' },
    { id = 'back',       label = u8'Шаг назад',          code = 'press_back(800)' },
    { id = 'left',       label = u8'Шаг влево',          code = 'move_and_go(-90, 800, false)' },
    { id = 'right',      label = u8'Шаг вправо',         code = 'move_and_go(90, 800, false)' },
    { id = 'turn_left',  label = u8'Повернуться налево', code = 'move_and_go(-90, 900, false)' },
    { id = 'turn_right', label = u8'Повернуться направо',code = 'move_and_go(90, 900, false)' },
    { id = 'turn_back',  label = u8'Развернуться',       code = 'move_and_go(180, 900, false)' },
    { id = 'run',        label = u8'Бежать 2 сек',       code = 'press_fwd(2000, true)' },
    { id = 'stop',       label = u8'Остановиться',       code = 'stop_move()' },
    { id = 'custom',     label = u8'Свой код',           code = '' },
}
CUSTOM_KINDS = {
    { id = 'reply',  label = u8'Ответ (текст)' },
    { id = 'stats',  label = u8'Команда + захват диалога' },
    { id = 'action', label = u8'Действие (пресет или код)' },
}
function custom_kind_label(id)
    for _, k in ipairs(CUSTOM_KINDS) do if k.id == id then return k.label end end
    return id or '?'
end
function custom_action_label(id)
    for _, a in ipairs(CUSTOM_ACTIONS) do if a.id == id then return a.label end end
    return id or '?'
end
function custom_action_code(id)
    for _, a in ipairs(CUSTOM_ACTIONS) do if a.id == id then return a.code end end
    return ''
end
migrate_custom_action_presets()
function run_custom_code(code)
    if type(code) ~= 'string' or code == '' then return end
    lua_thread.create(function()
        local chunk, err = loadstring(code)
        if not chunk then chat_add('{FF5555}[mytrig] Ошибка загрузки: ' .. chat_str(tostring(err)), -1); return end
        local ok, err2 = pcall(chunk)
        if not ok then chat_add('{FF5555}[mytrig] Ошибка выполнения: ' .. chat_str(tostring(err2)), -1) end
    end)
end
stats_capture = {
    open = new.bool(false), for_idx = nil, lines = {}, waiting = false, cmd = '/stats',
    dialog_id = nil,
}
stats_cap_dialog = nil
local function stats_capture_listen()
    stats_capture.waiting = true
    stats_capture.dialog_id = nil
    stats_capture.lines = {}
    stats_cap_dialog = nil
    lua_thread.create(function()
        local tries = 0
        while stats_cap_dialog == nil and tries < 50 do wait(100); tries = tries + 1 end
        stats_capture.waiting = false
        if not stats_cap_dialog then
            stats_capture.lines = { u8'Диалог не появился. Проверь команду.' }
            return
        end
        local d = stats_cap_dialog
        stats_cap_dialog = nil
        local lines = {}
        for line in (d.text .. '\n'):gmatch('(.-)\n') do
            local trimmed = line:gsub('^%s+', ''):gsub('%s+$', '')
            if trimmed ~= '' then table.insert(lines, trimmed) end
        end
        stats_capture.lines = lines
        stats_capture.dialog_id = d.id
    end)
end
function stats_capture_open_row(i)
    if stats_capture.dialog_id then
        pcall(sampSendDialogResponse, stats_capture.dialog_id, 1, i - 1, '')
    end
    stats_capture.dialog_id = nil
    stats_capture_listen()
end
function stats_capture_pick_row(i)
    local picked = 'line:' .. tostring(i - 1)
    if stats_capture.dialog_id then
        pcall(sampSendDialogResponse, stats_capture.dialog_id, 1, i - 1, '')
    end
    if stats_capture.for_idx and stats_capture.for_idx > 0 then
        local ct = custom_triggers[stats_capture.for_idx]
        if ct then
            ct.value = picked
            if ct._buf_value then imgui.StrCopy(ct._buf_value, ct.value) end
            save_custom_triggers()
        end
    else
        imgui.StrCopy(custom_new_value, picked)
    end
    chat_add('{55FF55}[mytrig] Строка выбрана как ответ.', -1)
    stats_capture.dialog_id = nil
    stats_capture.open[0] = false
end
function stats_capture_cancel()
    if stats_capture.dialog_id then
        pcall(sampSendDialogResponse, stats_capture.dialog_id, 0, 0, '')
    end
    stats_capture.dialog_id = nil
    stats_capture.open[0] = false
end
function start_stats_capture(trig_idx, cmd)
    stats_capture.for_idx = trig_idx or -1
    stats_capture.open[0] = true
    stats_capture.cmd = (cmd and cmd ~= '') and cmd or '/stats'
    sampProcessChatInput(stats_capture.cmd)
    stats_capture_listen()
end
trash_texts = { bamnuc('свалка'), bamnuc('мусорка') }
pick_trig = {
    pinokio('Вы подобрали'), pinokio('Мусор,который лежал'),
    pinokio('на полу.'), pinokio('отнесите его на тюрменую свалку,'),
    pinokio('отнесите его на тюремную свалку,'), pinokio('которая находится на улице!'),
}
coll_models = { [2670] = true, [2673] = true, [2674] = true, [2677] = true }
los_ok = pcall(function() return processLineOfSight(0, 0, 0, 0, 0, 0, true, true, true, false, false, false, false) end)
function obj_coords(obj)
    local a, b, c, d = getObjectCoordinates(obj)
    if type(a) == 'number' then return a, b, c end
    if type(b) == 'number' then return b, c, d end
    return nil
end
function dist3(x, y, z)
    local px, py, pz = get_player_pos()
    return getDistanceBetweenCoords3d(px, py, pz, x, y, z)
end
cam_was_act = false
move_token = 0
function stop_move() move_token = move_token + 1; setGameKeyState(1, 0); is_running = false; cam_was_act = false end
function los_clear_scan(x1, y1, z1, x2, y2, z2)
    if not los_ok then return true end
    local ok, hit, cp, nrm, obj = pcall(processLineOfSight, x1, y1, z1, x2, y2, z2, true, true, true, false, false, false, false)
    if not ok then return true end
    if not hit then return true end
    if obj and obj ~= 0 and coll_models[getObjectModel(obj)] then return true end
    return false
end
cur_ang, tgt_ang = 0, 0
function set_tgt_angle(a)
    tgt_ang = a
    while tgt_ang > 360 do tgt_ang = tgt_ang - 360 end
    while tgt_ang < 0 do tgt_ang = tgt_ang + 360 end
    if not cam_was_act then cur_ang = tgt_ang; cam_was_act = true end
end
function smooth_cam(factor, min_step, max_step)
    factor = factor or 0.1; min_step = min_step or 0.25
    local d = tgt_ang - cur_ang
    while d > 180 do d = d - 360 end
    while d < -180 do d = d + 360 end
    if math.abs(d) > 1 then
        local step = d * factor
        if math.abs(step) < min_step then step = d > 0 and min_step or -min_step end
        if max_step and math.abs(step) > max_step then step = d > 0 and max_step or -max_step end
        cur_ang = cur_ang + step
    else cur_ang = tgt_ang end
    setCameraPositionUnfixed(0, math.rad(cur_ang - 90))
end
side_dir = 1; side_until = 0
avoid_dir, avoid_until = 0, 0
check_dists = {1.5, 3.0, 4.5}
commit_time = 1.6
side_angles = {0, 20, -20, 35, -35, 55, -55, 80, -80}
function check_angle(px, py, pz, a)
    local r = math.rad(a)
    local dx, dy = math.sin(r), math.cos(r)
    for _, d in ipairs(check_dists) do
        local ex, ey = px + dx * d, py + dy * d
        if not los_clear_scan(px, py, pz + 0.6, ex, ey, pz + 0.6) then return false end
    end
    return true
end
next_m_pause = 0; m_pause_until = 0
function upd_m_pause()
    if not cfg.behavior.micro_pauses then return false end
    local now = os.clock()
    if now < m_pause_until then return true end
    if next_m_pause == 0 then next_m_pause = now + math.random(20, 45) end
    if now >= next_m_pause then
        m_pause_until = now + math.random(8, 20) / 10
        next_m_pause = now + math.random(20, 45)
        return true
    end
    return false
end
function steer_direct(tx, ty, tz, run_override, opts)
    if upd_m_pause() then setGameKeyState(1, 0); is_running = false; return end
    opts = opts or {}
    local cam_factor = opts.camFactor or 0.12
    local cam_min = opts.camMin or 0.3
    local cam_max = opts.maxStep
    local look = opts.look or 0
    local px, py, pz = get_player_pos()
    local base = getHeadingFromVector2d(tx - px, ty - py)
    local want_run = true
    if run_override ~= nil then want_run = run_override end
    set_tgt_angle(base + look)
    smooth_cam(cam_factor, cam_min, cam_max)
    if upd_m_pause() then setGameKeyState(1, 0); is_running = false; return end
    setGameKeyState(1, -255)
    is_running = want_run
end
function steer_to(tx, ty, tz, run_override, opts)
    if upd_m_pause() then setGameKeyState(1, 0); is_running = false; return end
    opts = opts or {}
    local cam_factor = opts.camFactor or 0.12
    local cam_min = opts.camMin or 0.3
    local cam_max = opts.maxStep
    local look = opts.look or 0
    local px, py, pz = get_player_pos()
    local base = getHeadingFromVector2d(tx - px, ty - py)
    local now = os.clock()
    local want_run = true
    if run_override ~= nil then want_run = run_override end
    if now < side_until then
        set_tgt_angle(base + side_dir * 70)
        smooth_cam(cam_factor, cam_min, cam_max)
        setGameKeyState(1, -255)
        is_running = want_run
        return
    end
    local chosen = base
    if los_ok then
        local straight_ok = check_angle(px, py, pz, base)
        if straight_ok then chosen = base; avoid_dir = 0
        elseif avoid_dir ~= 0 and now < avoid_until and check_angle(px, py, pz, base + avoid_dir * 35) then
            chosen = base + avoid_dir * 35
        else
            avoid_dir = 0
            local found = false
            for _, off in ipairs(side_angles) do
                if off ~= 0 then
                    local a = base + off
                    if check_angle(px, py, pz, a) then
                        chosen = a; avoid_dir = off > 0 and 1 or -1
                        avoid_until = now + commit_time; found = true; break
                    end
                end
            end
            if not found then chosen = base + side_dir * 130; side_dir = -side_dir; avoid_dir = 0 end
        end
    end
    set_tgt_angle(chosen + look)
    smooth_cam(cam_factor, cam_min, cam_max)
    setGameKeyState(1, -255)
    is_running = want_run
end
function steer_smart(tx, ty, tz, run_override, opts, avoid_enabled)
    if avoid_enabled then steer_to(tx, ty, tz, run_override, opts)
    else steer_direct(tx, ty, tz, run_override, opts) end
end
look_ang, look_until, next_look = 0, 0, 0
function upd_hum_look(now)
    if now >= next_look then
        next_look = now + math.random(10, 13) / 10
        local dir = (math.random(0, 1) == 0) and -1 or 1
        look_ang = dir * math.random(12, 30)
        look_until = now + math.random(25, 40) / 100
    end
    if now < look_until then return look_ang end
    return 0
end
function move_and_go(angle_offset, duration_ms, want_run)
    move_token = move_token + 1
    local my_token = move_token
    lua_thread.create(function()
        local h = getCharHeading(PLAYER_PED)
        if type(h) ~= 'number' then return end
        local new_h = h + angle_offset
        while new_h >= 360 do new_h = new_h - 360 end
        while new_h < 0 do new_h = new_h + 360 end
        pcall(setCharHeading, PLAYER_PED, new_h)
        pcall(setCameraPositionUnfixed, 0, math.rad(new_h - 90))
        cur_ang, tgt_ang = new_h, new_h
        cam_was_act = false
        wait(100)
        if move_token ~= my_token then return end
        setGameKeyState(1, -255)
        is_running = want_run ~= false
        wait(duration_ms or 900)
        if move_token ~= my_token then return end
        setGameKeyState(1, 0)
        is_running = false
    end)
end
function press_fwd(duration_ms, want_run)
    move_token = move_token + 1
    local my_token = move_token
    lua_thread.create(function()
        setGameKeyState(1, -255)
        is_running = want_run and true or false
        wait(duration_ms or 800)
        if move_token ~= my_token then return end
        setGameKeyState(1, 0)
        is_running = false
    end)
end
function press_back(duration_ms)
    move_token = move_token + 1
    local my_token = move_token
    lua_thread.create(function()
        setGameKeyState(1, 255)
        wait(duration_ms or 800)
        if move_token ~= my_token then return end
        setGameKeyState(1, 0)
    end)
end
function do_action_press(key_state, duration_ms)
    move_token = move_token + 1
    local my_token = move_token
    lua_thread.create(function()
        local deadline = os.clock() + (duration_ms or 800) / 1000
        while os.clock() < deadline do
            if move_token ~= my_token then break end
            setGameKeyState(1, key_state)
            wait(0)
        end
        if move_token == my_token then
            setGameKeyState(1, 0)
            is_running = false
        end
    end)
end
function do_action_turn(angle_offset)
    move_token = move_token + 1
    local my_token = move_token
    lua_thread.create(function()
        local h = getCharHeading(PLAYER_PED)
        if type(h) ~= 'number' then return end
        local new_h = h + angle_offset
        while new_h >= 360 do new_h = new_h - 360 end
        while new_h < 0 do new_h = new_h + 360 end
        pcall(setCharHeading, PLAYER_PED, new_h)
        pcall(setCameraPositionUnfixed, 0, math.rad(new_h - 90))
        wait(50)
        if move_token ~= my_token then return end
        local deadline = os.clock() + 0.8
        while os.clock() < deadline do
            if move_token ~= my_token then break end
            setGameKeyState(1, -255)
            wait(0)
        end
        if move_token == my_token then
            setGameKeyState(1, 0)
            is_running = false
        end
    end)
end
function do_action(kind)
    if kind == 'jump' then do_jump_this_frame = true
    elseif kind == 'crouch' then press_duck()
    elseif kind == 'turn_left' then do_action_turn(-90)
    elseif kind == 'turn_right' then do_action_turn(90)
    elseif kind == 'turn_back' then do_action_turn(180)
    elseif kind == 'back' then do_action_press(255, 800)
    elseif kind == 'fwd' then do_action_press(-255, 800)
    elseif kind == 'left' then do_action_turn(-90)
    elseif kind == 'right' then do_action_turn(90)
    elseif kind == 'run' then do_action_press(-255, 2000)
    elseif kind == 'stop' then stop_move()
    end
end
last_alt_times = { alt = 0, la = 0, fd = 0, wa = 0 }
function press_alt_kind(kind, cooldown)
    local now = os.clock()
    if now - last_alt_times[kind] < cooldown then return end
    last_alt_times[kind] = now
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220); raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, 8); raknetBitStreamWriteInt32(bs, 7)
    raknetBitStreamWriteInt32(bs, -1); raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteString(bs, "")
    raknetSendBitStreamEx(bs, 1, 7, 1)
    raknetDeleteBitStream(bs)
end
function press_alt() press_alt_kind('alt', 1.2) end
function press_alt_la() press_alt_kind('la', 1.6) end
function press_alt_fd() press_alt_kind('fd', 1.2) end
function press_alt_wa() press_alt_kind('wa', 1.5) end
bot = { active=false, state='find', item=nil, trash=nil, collected=0, next_jump=0, picked=false, retries=0, wait_start=0, stuck_x=0, stuck_y=0, stuck_t=0, near_since=0, was_active=false, anim_until=0, last_find_at=0, status='' }
laundry_bot = {
    active = false, state = 'scan_free', target = nil, free_machine = nil,
    wait_start = 0, awaiting_chat = false, put_confirmed = false,
    took_confirmed = false, delivered_confirmed = false,
    dirty_pickup_confirmed = false, error_no_dirty = false, error_no_clean = false,
    stuck_x = 0, stuck_y = 0, stuck_t = 0, near_since = 0,
    next_jump = 0, step_until = 0, dirty_fail_count = 0,
    was_active = false, used_machines = {}, last_used_machine_id = nil,
    carrying_dirty = false, carrying_clean = false, next_alt_press = 0, status = '',
}
food_cook_s = 100
af_crit_eaten = false
autofood_eating_until_full = false
function eat_auto_food(ft)
    if ft == 0 then sampProcessChatInput('/jmeat')
    elseif ft == 1 then sampProcessChatInput('/jfish')
    elseif ft == 2 then sampProcessChatInput('/cheeps')
    else return end
    lua_thread.create(function()
        wait(250)
        pcall(taskClearSecondary, PLAYER_PED)
        pcall(clearCharTasksImmediately, PLAYER_PED)
        wait(700); pcall(taskClearSecondary, PLAYER_PED)
        wait(700); pcall(taskClearSecondary, PLAYER_PED)
        wait(700); pcall(taskClearSecondary, PLAYER_PED)
    end)
end
food_bot = {
    active = false, state = 'discover', status = 'Ожидание', ovens = {}, check_oven_idx = 1,
    carrying_raw = false, carrying_cooked = false, target = nil,
    raw_origin = nil, raw_return_confirmed = false, raw_return_wait_start = 0,
    raw_return_next_alt = 0, raw_search_started_at = 0, expect_ready = false,
    stuck_x = 0, stuck_y = 0, stuck_t = 0, stuck_since = 0, near_since = 0,
    next_jump = 0, wait_start = 0, next_alt_press = 0,
    awaiting_chat = false, raw_confirmed = false, was_active = false,
    fridge_lock = nil, raw_lock = nil,
    awaiting_fridge_chat = false, fridge_confirmed = false, fridge_wait_start = 0,
    return_oven_idx = nil, found_empty_oven_idx = nil, visited_since_action = 0,
    round_active = false, round_idx = 1, round_any_cooking = false, fill_queue = {},
    oven_wait_started_at = 0, search_started_at = 0, search_nudge_at = 0,
    hands_full_error = false,
    first_scan_active = false, first_scan_idx = 1,
}
function food_reset_transient()
    food_bot.target = nil
    food_bot.stuck_x, food_bot.stuck_y, food_bot.stuck_t = 0, 0, 0
    food_bot.stuck_since = 0
    food_bot.near_since = 0
    food_bot.wait_start = 0
    food_bot.next_alt_press = 0
    food_bot.awaiting_chat = false; food_bot.raw_confirmed = false
    food_bot.awaiting_fridge_chat = false; food_bot.fridge_confirmed = false
    food_bot.fridge_wait_start = 0
    food_bot.fridge_lock = nil
    food_bot.raw_lock = nil
    food_bot.oven_wait_started_at = 0
    food_bot.search_started_at = 0
    food_bot.search_nudge_at = 0
    food_bot.raw_return_confirmed = false
    food_bot.raw_return_wait_start = 0
    food_bot.raw_return_next_alt = 0
    food_bot.raw_search_started_at = 0
    food_bot.expect_ready = false
    food_bot.first_scan_active = false
    food_bot.first_scan_idx = 1
    food_bot.round_active = false
    food_bot.round_idx = 1
    food_bot.round_any_cooking = false
    food_bot.fill_queue = {}
    food_dialog.active = false
end
la_mach_txt = 'Стиральная машина'
la_free_sub = '[ {97F85E}Свободная{FFFFFF} ]'
la_fin_sub = { '[ {F8F05E}Закончила работу{FFFFFF} ]', 'Заберите чистые вещи!' }
la_clean_sub = { 'Выдают автоматически!' }
la_dirty_sub = { 'Грязная {99CC00}одежда{FFFFFF}' }
la_busy_sub = { '[ {F8645E}Работает{FFFFFF} ]', '[ {F8F05E}Закончила работу{FFFFFF} ]', 'Заберите чистые вещи!', 'Чистая {99CC00}одежда{FFFFFF}' }
food_raw_req = { 'сырое', 'мясо' }
food_ovn_req = { 'печка' }
food_fr_req = { 'холодильник' }
la_mach_txt_lc = bamnuc(la_mach_txt)
la_free_sub_lc = bamnuc(la_free_sub)
la_fin_sub_lc, la_clean_sub_lc, la_dirty_sub_lc, la_busy_sub_lc = {}, {}, {}, {}
for i, v in ipairs(la_fin_sub) do la_fin_sub_lc[i] = bamnuc(v) end
for i, v in ipairs(la_clean_sub) do la_clean_sub_lc[i] = bamnuc(v) end
for i, v in ipairs(la_dirty_sub) do la_dirty_sub_lc[i] = bamnuc(v) end
for i, v in ipairs(la_busy_sub) do la_busy_sub_lc[i] = bamnuc(v) end
food_raw_req_lc, food_ovn_req_lc, food_fr_req_lc = {}, {}, {}
for i, v in ipairs(food_raw_req) do food_raw_req_lc[i] = pinokio(v) end
for i, v in ipairs(food_ovn_req) do food_ovn_req_lc[i] = pinokio(v) end
for i, v in ipairs(food_fr_req) do food_fr_req_lc[i] = pinokio(v) end
function txt_has_all_n(text, subs_pinokio)
    local nt = pinokio(text)
    for i = 1, #subs_pinokio do
        if not nt:find(subs_pinokio[i], 1, true) then return false end
    end
    return true
end
function find_txt_n_cached(subs_pinokio, max_dist)
    local px, py, pz = get_player_pos()
    local best, bestd = nil, max_dist
    local texts = tick_cache.texts
    for i = 1, #texts do
        local item = texts[i]
        if txt_has_all_n(item.text, subs_pinokio) then
            local d = getDistanceBetweenCoords3d(px, py, pz, item.x, item.y, item.z)
            if d < bestd then bestd = d; best = item end
        end
    end
    return best
end
function find_all_txt_n_cached(subs_pinokio, max_dist)
    local px, py, pz = get_player_pos()
    local list, n = {}, 0
    local texts = tick_cache.texts
    for i = 1, #texts do
        local item = texts[i]
        if txt_has_all_n(item.text, subs_pinokio) then
            local d = getDistanceBetweenCoords3d(px, py, pz, item.x, item.y, item.z)
            if d <= max_dist then
                n = n + 1
                list[n] = { id = item.id, x = item.x, y = item.y, z = item.z, text = item.text, dist = d }
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end
function find_txt(substrings, max_dist, exclude_ids)
    local px, py, pz = get_player_pos()
    local best, bestd = nil, max_dist
    local texts = tick_cache.texts
    for i = 1, #texts do
        local item = texts[i]
        if not (exclude_ids and exclude_ids[item.id]) then
            local lt = bamnuc(item.text)
            for _, sub in ipairs(substrings) do
                if lt:find(bamnuc(sub), 1, true) then
                    local d = getDistanceBetweenCoords3d(px, py, pz, item.x, item.y, item.z)
                    if d < bestd then
                        bestd = d
                        best = { id = item.id, x = item.x, y = item.y, z = item.z, text = item.text }
                    end
                    break
                end
            end
        end
    end
    return best
end
function la_txt_match(target, sub_list)
    if not target or not target.id then return false end
    if not sampIs3dTextDefined(target.id) then return false end
    local text = sampGet3dTextInfoById(target.id)
    if type(text) ~= 'string' then return false end
    local lt = bamnuc(text)
    for _, sub in ipairs(sub_list) do
        if lt:find(bamnuc(sub), 1, true) then return true end
    end
    return false
end
function is_near_fin_cached(text)
    if type(text) ~= 'string' then return false end
    return bamnuc(text):match('осталось%s*{f8645e}(%d+)%s*мин') ~= nil
end
function find_near_fin_cached(max_dist)
    local px, py, pz = get_player_pos()
    local best, bestd = nil, max_dist
    local texts = tick_cache.texts
    for i = 1, #texts do
        local item = texts[i]
        if is_near_fin_cached(item.text) then
            local d = getDistanceBetweenCoords3d(px, py, pz, item.x, item.y, item.z)
            if d < bestd then bestd = d; best = item end
        end
    end
    return best
end
function find_free_m(max_dist, exclude_ids, avoid_last_id)
    local px, py, pz = get_player_pos()
    local candidates, n = {}, 0
    local now = os.clock()
    local texts = tick_cache.texts
    for i = 1, #texts do
        local item = texts[i]
        local excluded = exclude_ids and exclude_ids[item.id] and exclude_ids[item.id] > now
        if not excluded then
            local lt = bamnuc(item.text)
            local d = getDistanceBetweenCoords3d(px, py, pz, item.x, item.y, item.z)
            if d <= max_dist then
                local expl_free = lt:find(la_free_sub_lc, 1, true) ~= nil
                local looks_mach = lt:find(la_mach_txt_lc, 1, true) ~= nil
                local is_busy = false
                if looks_mach then
                    for k = 1, #la_busy_sub_lc do
                        if lt:find(la_busy_sub_lc[k], 1, true) then is_busy = true; break end
                    end
                end
                if expl_free or (looks_mach and not is_busy) then
                    n = n + 1
                    candidates[n] = { id = item.id, x = item.x, y = item.y, z = item.z, text = item.text, d = d }
                end
            end
        end
    end
    if n == 0 then return nil end
    table.sort(candidates, function(a, b) return a.d < b.d end)
    if avoid_last_id and candidates[1].id == avoid_last_id and candidates[2] then return candidates[2] end
    return candidates[1]
end
function is_spot_busy(x, y, z, radius)
    local my_ped = PLAYER_PED
    local chars = tick_cache.chars
    for i = 1, #chars do
        local ped = chars[i]
        if ped ~= my_ped and doesCharExist(ped) then
            local pcall_ok, is_player = pcall(sampGetPlayerIdByCharHandle, ped)
            if pcall_ok and is_player then
                local cok, cx, cy, cz = pcall(getCharCoordinates, ped)
                if cok and cx then
                    local d = getDistanceBetweenCoords3d(x, y, z, cx, cy, cz)
                    if d <= radius then return true end
                end
            end
        end
    end
    return false
end
function find_item()
    local px, py, pz = get_player_pos()
    local best, bestd = nil, cfg.bot.max_search
    local objs = tick_cache.objects
    for i = 1, #objs do
        local obj = objs[i]
        if coll_models[getObjectModel(obj)] then
            local ox, oy, oz = obj_coords(obj)
            if ox then
                local d = getDistanceBetweenCoords3d(px, py, pz, ox, oy, oz)
                if d < bestd then bestd = d; best = { handle = obj, x = ox, y = oy, z = oz } end
            end
        end
    end
    return best
end
function find_trash()
    local px, py, pz = get_player_pos()
    local best, bestd = nil, 1e9
    local texts = tick_cache.texts
    for i = 1, #texts do
        local item = texts[i]
        local lt = bamnuc(item.text)
        local is_prison = lt:find('тюремная', 1, true) or lt:find('тюрменую', 1, true)
        local is_trash = lt:find('мусорка', 1, true) or lt:find('свалка', 1, true)
        if is_prison and is_trash then
            if not is_spot_busy(item.x, item.y, item.z, 2.0) then
                local d = getDistanceBetweenCoords3d(px, py, pz, item.x, item.y, item.z)
                if d < bestd then bestd = d; best = { x = item.x, y = item.y, z = item.z } end
            end
        end
    end
    return best
end
food_dialog = { active = false, id = nil, kind = nil, rows = {} }
chips_buy = { pending = false, bought = 0, target = 0, wait_start = 0 }
last_dlg_txt = ''
last_question = ''
last_admin_nick = ''
stats_level_last = nil
stats_full_dialog = nil
stats_capture_pending = false
function parse_food_dialog_rows(text)
    local rows = {}
    local lines = {}
    for line in (text .. '\n'):gmatch('(.-)\n') do table.insert(lines, line) end
    for i = 2, #lines do
        if lines[i] ~= '' then
            local cols = {}
            for col in (lines[i] .. '\t'):gmatch('(.-)\t') do table.insert(cols, col) end
            table.insert(rows, { idx = #rows, state = strip_color(cols[2] or ''), action = strip_color(cols[3] or '') })
        end
    end
    return rows
end
function is_msg_about_me(text)
    if type(text) ~= 'string' or text == '' then return false end
    local lt = lower1251(text)
    for _, m in ipairs({ ' вас', ' вам', ' вы ', 'вас,', 'вам,', 'вас.', 'вам.', ' тебя', ' тебе', ' твой', ' твоя', ' твои', ' твоё', ' твое', ' ваше', ' ваша', ' ваши', ' ваш ' }) do
        if lt:find(m, 1, true) then return true end
    end
    local my_nick = my_fmt_nick()
    if my_nick and my_nick ~= '' then
        local n1 = lower1251(my_nick)
        if n1 ~= '' and lt:find(n1, 1, true) then return true end
        local n2 = lower1251(my_nick:gsub('_', ' '))
        if n2 ~= n1 and n2 ~= '' and lt:find(n2, 1, true) then return true end
    end
    return false
end
function send_admin_reply_instant(text, channel)
    if admin_test_mode then chat_add('{FFAA00}[ответ]{FFFFFF} ' .. chat_str(text), -1); return end
    channel = channel or 'chat'
    local cp_text = chat_str(text)
    if channel == 'b' then sampSendChat('/b ' .. cp_text)
    else sampSendChat(cp_text) end
end
function send_admin_reply(text, channel)
    if admin_test_mode then chat_add('{FFAA00}[ответ]{FFFFFF} ' .. chat_str(text), -1); return end
    channel = channel or 'chat'
    local delay = delay_by_length(last_question)
    lua_thread.create(function()
        wait(math.floor(delay * 1000))
        local out_text = text
        local miss = emulate_miss()
        if miss then out_text = apply_typo(out_text) end
        local cp_text = chat_str(out_text)
        if channel == 'b' then sampProcessChatInput('/b ' .. cp_text)
        else sampProcessChatInput(cp_text) end
        tg_admin_log(last_question, miss and ('<typo> ' .. out_text) or out_text)
    end)
end
function run_stats_trigger(cmd, pattern, channel)
    cmd = cmd or '/stats'
    stats_capture_pending = true
    sampProcessChatInput(cmd)
    lua_thread.create(function()
        local tries = 0
        while stats_full_dialog == nil and tries < 25 do wait(100); tries = tries + 1 end
        local txt = stats_full_dialog
        stats_full_dialog = nil
        stats_capture_pending = false
        if not txt then send_admin_reply(u8'не вижу ответа', channel); return end
        local out = nil
        if pattern and pattern ~= '' then
            local clean = strip_color(txt)
            local a, b = clean:find(pattern, 1, true)
            if not a then a, b = clean:find(u8(pattern), 1, true) end
            if not a then
                local clean_utf = cp_to_utf8(clean)
                a, b = clean_utf:find(pattern, 1, true)
                if a then clean = clean_utf end
            end
            if a then
                local tail = clean:sub(b + 1)
                local num = tail:match('^%s*:?%s*(%-?%d+%.?%d*)')
                if num then out = num
                else
                    local word = tail:match('^%s*:?%s*([^%s\n]+)')
                    if word then out = word end
                end
            end
            if not out then out = clean:match(pattern .. '%s*:?%s*(%-?%d+%.?%d*)') end
        end
        if not out then out = strip_color(txt):gsub('\n', ' | ') end
        send_admin_reply(out, channel)
    end)
end
function try_custom_trigger(text_plain, channel)
    for _, ct in ipairs(custom_triggers) do
        if ct.active ~= false and type(ct.words) == 'string' and ct.words ~= '' then
            for _, w in ipairs(split_by_comma(ct.words)) do
                if w ~= '' and match_any_group(text_plain, {w}) then
                    ct.session_hits = (ct.session_hits or 0) + 1
                    log_trigger_fire(ct.words, ct.kind or 'reply')
                    if ct.kind == 'stats' then
                        local cmd = (ct.extra ~= '' and ct.extra) or '/stats'
                        local val = ct.value or ''
                        local line_idx = tonumber(val:match('^line:(%d+)$'))
                        if line_idx then
                            stats_capture_pending = true
                            sampProcessChatInput(cmd)
                            lua_thread.create(function()
                                local tries = 0
                                while stats_full_dialog == nil and tries < 25 do wait(100); tries = tries + 1 end
                                local txt = stats_full_dialog; stats_full_dialog = nil
                                stats_capture_pending = false
                                if not txt then send_admin_reply(u8'нет данных', channel); return end
                                local lines = {}
                                for line in (txt .. '\n'):gmatch('(.-)\n') do
                                    local t = line:gsub('^%s+', ''):gsub('%s+$', '')
                                    if t ~= '' then table.insert(lines, t) end
                                end
                                local target = lines[line_idx + 1]
                                if target then send_admin_reply(target, channel)
                                else send_admin_reply(u8'строка не найдена', channel) end
                            end)
                        else
                            run_stats_trigger(cmd, val, channel)
                        end
                    elseif ct.kind == 'action' then
                        local preset = ct.value or ''
                        if preset ~= '' and preset ~= 'custom' and custom_action_code(preset) ~= '' then
                            do_action(preset)
                        else
                            local code = ct.extra
                            if not code or code == '' then code = custom_action_code(preset) end
                            run_custom_code(code)
                        end
                        lua_thread.create(function()
                            wait(1500)
                            send_admin_reply_instant(u8'ок', channel)
                        end)
                    else
                        send_admin_reply(ct.value or '', channel)
                    end
                    return true
                end
            end
        end
    end
    return false
end
function try_handle_admin_question(text_plain, channel)
    if not text_plain or text_plain == '' then return false end
    last_question = text_plain
    local an = find_admin_nick(text_plain)
    if an then last_admin_nick = an end
    watchdog_check(text_plain)
    if try_custom_trigger(text_plain, channel) then return true end
    if match_compiled(text_plain, compiled_dynamic.level_q) then
        run_stats_trigger('/stats', 'Уровень', channel)
        return true
    end
    if match_compiled(text_plain, compiled_dynamic.my_nick_q) then
        if last_admin_nick and last_admin_nick ~= '' then send_admin_reply(last_admin_nick, channel)
        else send_admin_reply(u8'не вижу твой ник', channel) end
        return true
    end
    for k, cmp in pairs(compiled_dynamic.how_much) do
        if match_compiled(text_plain, cmp) then
            tsr_req_sum(function(data)
                local v = data[k] or '?'
                send_admin_reply(tostring(v), channel)
            end)
            return true
        end
    end
    if match_compiled(text_plain, compiled_dynamic.bot_q) then send_admin_reply(pick_random(triggers_store.bot_answers, 'bot'), channel); return true end
    if match_compiled(text_plain, compiled_dynamic.what_doing) then
        local key = 'busy_idle'
        if bot.active then key = 'busy_trash'
        elseif laundry_bot.active then key = 'busy_laundry'
        elseif food_bot.active then key = 'busy_food'
        elseif box.active then key = 'busy_box' end
        send_admin_reply(pick_random(triggers_store[key] or triggers_store.busy_idle, 'busy'), channel)
        return true
    end
    if match_compiled(text_plain, compiled_dynamic.not_reply) then send_admin_reply(pick_random(triggers_store.not_reply_answers, 'notreply'), channel); return true end
    if match_compiled(text_plain, compiled_dynamic.afk_q) then
        send_admin_reply(pick_random(triggers_store.not_reply_answers, 'notreply'), channel)
        lua_thread.create(function()
            for i = 1, 20 do
                local h = getCharHeading(PLAYER_PED)
                setCameraPositionUnfixed(0, math.rad(h + math.random(-8, 8)))
                wait(15)
            end
        end)
        return true
    end
    if match_compiled(text_plain, compiled_dynamic.how_long) then send_admin_reply(pick_random(triggers_store.how_long_answers, 'howlong'), channel); return true end
    if match_compiled(text_plain, compiled_dynamic.exit_soon) then
        tsr_req_sum(function(data) send_admin_reply(u8'осталось ' .. tostring(data.minutes or '?') .. u8' мин', channel) end)
        return true
    end
    if match_compiled(text_plain, compiled_dynamic.nick) then
        local nick = my_fmt_nick()
        if nick then send_admin_reply(nick:gsub('_', ' '), channel)
        else send_admin_reply(u8'не помню ник', channel) end
        return true
    end
    if match_compiled(text_plain, compiled_dynamic.id) then
        local delay = 4.0 + math.random() * 1.5
        local id = my_player_id()
        lua_thread.create(function()
            wait(math.floor(delay * 1000))
            if admin_test_mode then chat_add('{FFAA00}[ответ]{FFFFFF} ' .. tostring(id or '?'), -1); return end
            local real_txt = tostring(id or '?')
            local miss = emulate_miss()
            if miss then
                local wrong_txt = apply_digit_typo(real_txt)
                if wrong_txt == real_txt then wrong_txt = apply_typo(real_txt) end
                local cp_wrong = chat_str(wrong_txt)
                if channel == 'b' then sampProcessChatInput('/b ' .. cp_wrong)
                else sampProcessChatInput(cp_wrong) end
                tg_admin_log(last_question, '<typo> ' .. wrong_txt)
                wait(math.random(1500, 3000))
                local cp_real = chat_str(real_txt)
                if channel == 'b' then sampProcessChatInput('/b ' .. cp_real)
                else sampProcessChatInput(cp_real) end
                tg_admin_log(last_question, '<fix> ' .. real_txt)
            else
                local cp_txt = chat_str(real_txt)
                if channel == 'b' then sampProcessChatInput('/b ' .. cp_txt)
                else sampProcessChatInput(cp_txt) end
                tg_admin_log(last_question, real_txt)
            end
        end)
        return true
    end
    if match_compiled(text_plain, compiled_dynamic.nearest) then
        if match_compiled(text_plain, compiled_dynamic.nearest_hint) then
            local id = find_near_id(20.0)
            if id then
                local okn, nick = pcall(sampGetPlayerNickname, id)
                if okn and nick then send_admin_reply(nick_to_name_comma(nick), channel); return true end
            end
            send_admin_reply(u8'никого рядом нет', channel)
            return true
        else
            local id = find_near_id(20.0)
            if id then send_admin_reply(tostring(id), channel)
            else send_admin_reply(u8'никого рядом нет', channel) end
            return true
        end
    end
    if match_compiled(text_plain, compiled_dynamic.here_q) then send_admin_reply(pick_random(triggers_store.are_you_here_answers, 'areuhere'), channel); return true end
    if match_compiled(text_plain, compiled_dynamic.move.stop) then do_action('stop'); send_admin_reply_instant(u8'ок', channel); return true end
    if match_compiled(text_plain, compiled_dynamic.move.jump) then do_action('jump'); send_admin_reply_instant(u8'прыгнул', channel); return true end
    if match_compiled(text_plain, compiled_dynamic.move.crouch) then do_action('crouch'); send_admin_reply_instant(u8'присел', channel); return true end
    if match_compiled(text_plain, compiled_dynamic.move.turn_left) then do_action('turn_left'); send_admin_reply_instant(u8'ок', channel); return true end
    if match_compiled(text_plain, compiled_dynamic.move.turn_right) then do_action('turn_right'); send_admin_reply_instant(u8'ок', channel); return true end
    if match_compiled(text_plain, compiled_dynamic.move.turn_back) then do_action('turn_back'); send_admin_reply_instant(u8'ок', channel); return true end
    if match_compiled(text_plain, compiled_dynamic.move.back) then do_action('back'); send_admin_reply_instant(u8'ок', channel); return true end
    if match_compiled(text_plain, compiled_dynamic.move.fwd) then do_action('fwd'); send_admin_reply_instant(u8'ок', channel); return true end
    if match_compiled(text_plain, compiled_dynamic.move.left) then do_action('left'); send_admin_reply_instant(u8'ок', channel); return true end
    if match_compiled(text_plain, compiled_dynamic.move.right) then do_action('right'); send_admin_reply_instant(u8'ок', channel); return true end
    if match_compiled(text_plain, compiled_dynamic.move.run) then do_action('run'); send_admin_reply_instant(u8'побежал', channel); return true end
    local function extract_after(prefix)
        if type(text_plain) ~= 'string' then return nil end
        local p = text_plain:find(prefix, 1, true)
        if p == 1 then
            return (text_plain:sub(#prefix + 1):gsub('^%s+', ''):gsub('%s+$', ''))
        end
        return nil
    end
    local wp_b = extract_after('напиши в чат /b ') or extract_after('напиши /b ')
    if wp_b and wp_b ~= '' then
        lua_thread.create(function()
            wait(math.random(800, 1600))
            if admin_test_mode then chat_add('{FFAA00}[отправка в /b]{FFFFFF} ' .. chat_str(wp_b), -1); return end
            sampProcessChatInput('/b ' .. chat_str(wp_b))
            tg_admin_log(last_question, '/b ' .. wp_b)
        end)
        return true
    end
    local wp_plain = extract_after('напиши в чат ') or extract_after('напиши ')
    if wp_plain and wp_plain ~= '' and not wp_plain:find('^/') then
        lua_thread.create(function()
            wait(math.random(800, 1600))
            if admin_test_mode then chat_add('{FFAA00}[отправка в чат]{FFFFFF} ' .. chat_str(wp_plain), -1); return end
            sampProcessChatInput(chat_str(wp_plain))
            tg_admin_log(last_question, wp_plain)
        end)
        return true
    end
    return false
end
function sampev_on_show_dialog_capture(dialog_id, style, title, b1, b2, text)
    local plain = strip_color(text or '')
    stats_full_dialog = plain
    local lvl = plain:match('Уровень%s*:?%s*%[?(%d+)') or plain:match(u8'Уровень%s*:?%s*%[?(%d+)')
    if lvl then stats_level_last = tonumber(lvl) end
    return false
end
tsr_dialog = { pending = false, stage = 0, wait_start = 0, on_result = nil }
tsr_menu_idx = 10
function tsr_parse(text)
    local clean = text:gsub('{%x%x%x%x%x%x}', '')
    return {
        boxes   = tonumber(clean:match('Перенести%s+(%d+)%s+ящиков')),
        food    = tonumber(clean:match('Приготовить%s+(%d+)%s+порций')),
        clothes = tonumber(clean:match('Перестирать%s+(%d+)%s+грязной одежды')),
        trash   = tonumber(clean:match('вынести на мусорку%s+(%d+)%s+мусора')),
        minutes = tonumber(clean:match('Отсидеть%s+(%d+)%s+минут')),
    }
end
function tsr_fmt_sum(d)
    local function v(x) return x and tostring(x) or '?' end
    return string.format('тср осталось:\nЯщики: %s\nЕда: %s\nОдежда: %s\nМусор: %s\nМинуты: %s',
        v(d.boxes), v(d.food), v(d.clothes), v(d.trash), v(d.minutes))
end
function tsr_req_sum(on_result)
    if tsr_dialog.pending then return end
    tsr_dialog.pending = true; tsr_dialog.stage = 0
    tsr_dialog.wait_start = os.clock(); tsr_dialog.on_result = on_result
    sampProcessChatInput('/mm')
end
function tsr_on_dialog(dialog_id, title, text)
    if tsr_dialog.pending and tsr_dialog.stage == 0 then
        local plain_title = title:gsub('{%x%x%x%x%x%x}', '')
        if plain_title:find('Игровое меню', 1, true) then
            sampSendDialogResponse(dialog_id, 1, tsr_menu_idx, '')
            tsr_dialog.stage = 1; tsr_dialog.wait_start = os.clock()
            return true
        end
    end
    if tsr_dialog.pending and tsr_dialog.stage == 1 then
        local plain_title = title:gsub('{%x%x%x%x%x%x}', '')
        if plain_title:find('Информация', 1, true) then
            local data = tsr_parse(text)
            sampSendDialogResponse(dialog_id, 1, 0, '')
            tsr_dialog.pending = false; tsr_dialog.stage = 0
            local cb = tsr_dialog.on_result; tsr_dialog.on_result = nil
            if cb then cb(data)
            else tg_send(tg_cfg.settings.token, tg_cfg.settings.chat_id, tsr_fmt_sum(data)) end
            return true
        end
    end
    return false
end
tg_last_upd = 0
tg_in_flight = false
tg_last_sent = {}
tg_min_int = 20
function tg_get_upd(resolve, reject)
    if not tg_cfg.settings.enabled then return end
    if not tg_cfg.settings.token or tg_cfg.settings.token == '' then return end
    if tg_in_flight then return end
    tg_in_flight = true
    local url = string.format('https://api.telegram.org/bot%s/getUpdates?offset=%d&timeout=25', tg_cfg.settings.token, tg_last_upd + 1)
    http_async(url, '', function(res) tg_in_flight = false; if resolve then resolve(res) end
    end, function(err) tg_in_flight = false; if reject then reject(err) end end)
end
tg_help = u8[[Привет! Я бот-помощник для игры.

Команды:
/r - показать сколько осталось до выхода из тюрьмы
/menu - показать меню с кнопками
/help - показать это сообщение]]
function sampev.onShowDialog(dialog_id, style, title, b1, b2, text)
    local title_plain = strip_color(title or '')
    local text_plain = strip_color(text or '')
    last_dlg_txt = text_plain
    if stats_capture.waiting then
        stats_cap_dialog = { id = dialog_id, text = text_plain }
        return false
    end
    if stats_capture_pending and stats_full_dialog == nil then
        sampev_on_show_dialog_capture(dialog_id, style, title, b1, b2, text)
        if stats_full_dialog ~= nil then
            stats_capture_pending = false
            if dialog_id then
                local resp = 1
                if b2 and b2 ~= '' then resp = 0 end
                pcall(sampSendDialogResponse, dialog_id, resp, 0, '')
            end
            return false
        end
    end
    if chips_buy.pending and text_plain:find('Чипсы', 1, true) then
        local lines = {}
        for line in (text .. '\n'):gmatch('(.-)\n') do table.insert(lines, line) end
        local chips_idx = nil
        for i, line in ipairs(lines) do
            if strip_color(line):find('Чипсы', 1, true) then chips_idx = i - 1; break end
        end
        if chips_idx then sampSendDialogResponse(dialog_id, 1, chips_idx, '')
        else chips_buy.pending = false end
        return false
    end
    if title_plain:find('Тюрьма Строгого Режима', 1, true) then
        sampSendDialogResponse(dialog_id, 1, 0, '')
        return false
    end
    if text_plain:find('Ваша сытость:', 1, true) then
        local satiety = tonumber(text_plain:match('Ваша сытость:%s*(%d+%.?%d*)'))
        sampSendDialogResponse(dialog_id, 1, 0, '')
        if cfg.autofood.enabled and satiety then
            if cfg.autofood.threshold == 0 then if satiety > 0 then af_crit_eaten = false end
            elseif satiety <= cfg.autofood.threshold then
                autofood_eating_until_full = true
                eat_auto_food(cfg.autofood.food_type)
            elseif autofood_eating_until_full then
                if satiety < cfg.autofood.threshold_max then eat_auto_food(cfg.autofood.food_type)
                else autofood_eating_until_full = false end
            end
        end
        return false
    end
    if title_plain:find('Вы тут?', 1, true) or text_plain:find('Вы тут?', 1, true) then
        lua_thread.create(function()
            wait(math.random(2000, 4000))
            sampSendDialogResponse(dialog_id, 1, 0, '')
            sampProcessChatInput('/b ' .. chat_str(pick_random(triggers_store.afk_check_answers, 'afk')))
        end)
        return false
    end
    if cfg.antiadmin.auto_exit then
        if match_compiled(title_plain .. ' ' .. text_plain, compiled_dynamic.admin) and is_msg_about_me(text_plain) then
            lua_thread.create(function()
                stop_all()
                wait(math.random(math.floor(cfg.antiadmin.auto_exit_delay_min * 1000), math.floor(cfg.antiadmin.auto_exit_delay_max * 1000)))
                sampProcessChatInput('/b ' .. chat_str(pick_random(triggers_store.answers_1, 'exit1')))
                wait(math.random(9000, 12000))
                sampProcessChatInput('/b ' .. chat_str(pick_random(triggers_store.answers_2, 'exit2')))
                wait(3000)
                sampProcessChatInput('/q')
                wait(500)
                os.exit(1)
            end)
            return false
        end
    end
    if match_compiled(title_plain .. ' ' .. text_plain, compiled_dynamic.admin) and is_msg_about_me(text_plain) then
        local an = find_admin_nick(title_plain .. ' ' .. text_plain)
        if cfg.antiadmin.smart_reply then
            if not try_handle_admin_question(text_plain, 'b') then
                send_admin_reply(pick_random(triggers_store.answers_1, 'adm1'), 'b')
            end
        else
            stop_all()
            tg_send_btns(tg_cfg.settings.token, tg_cfg.settings.chat_id,
                (an or 'admin') .. ' ' .. text_plain,
                {{ {text = u8'Продолжить работу', data = 'admin_resume'}, {text = u8'Выйти с игры', data = 'admin_quit'} }})
        end
        return false
    end
    if tsr_on_dialog(dialog_id, title, text) then
        if tsr_cfg.settings.hide_dialog then return false end
        return
    end
    local ttl = bamnuc(strip_color(title or ''))
    local kind = nil
    if ttl:find('печка', 1, true) then kind = 'oven'
    elseif ttl:find('холодильник', 1, true) then kind = 'fridge' end
    if kind then
        food_dialog.active = true
        food_dialog.id = dialog_id
        food_dialog.kind = kind
        food_dialog.rows = parse_food_dialog_rows(text)
        return false
    else food_dialog.active = false end
end
function sampev.onDialogResponse(dialog_id, response, listitem, inputtext)
    if dialog_id == food_dialog.id then food_dialog.active = false end
end
function sampev.onServerMessage(color, text)
    if type(text) ~= 'string' then return end
    local clean_text = strip_color(text)
    if match_compiled(clean_text, compiled_dynamic.admin) and is_msg_about_me(clean_text) then
        local an = find_admin_nick(clean_text)
        if cfg.antiadmin.smart_reply then
            if not try_handle_admin_question(clean_text, 'chat') then
                send_admin_reply(pick_random(triggers_store.answers_1, 'adm1'), 'chat')
            end
        else
            stop_all()
            tg_send_btns(tg_cfg.settings.token, tg_cfg.settings.chat_id,
                (an or 'admin') .. ' ' .. clean_text,
                {{ {text = u8'Продолжить работу', data = 'admin_resume'}, {text = u8'Выйти с игры', data = 'admin_quit'} }})
        end
    end
    if cfg.autofood.enabled and clean_text:find('Пополнить сытость можно в любой закусочной штата', 1, true) then
        local satiety = tonumber(clean_text:match('(%d+)%.'))
        if satiety and cfg.autofood.threshold ~= 0 then
            if satiety <= cfg.autofood.threshold then
                autofood_eating_until_full = true
                eat_auto_food(cfg.autofood.food_type)
            elseif autofood_eating_until_full and satiety < cfg.autofood.threshold_max then
                eat_auto_food(cfg.autofood.food_type)
            elseif autofood_eating_until_full then autofood_eating_until_full = false end
        end
    end
    if cfg.autofood.enabled and clean_text:find('Вам срочно необходимо покушать, или вам повысят срок!', 1, true) then
        if cfg.autofood.threshold == 0 then
            if not af_crit_eaten then af_crit_eaten = true; eat_auto_food(cfg.autofood.food_type) end
        else autofood_eating_until_full = true; eat_auto_food(cfg.autofood.food_type) end
    end
    local nt = pinokio(text)
    if bot.active then
        for i = 1, #pick_trig do
            if nt:find(pick_trig[i], 1, true) then bot.picked = true; return end
        end
    end
    if food_bot.active and food_bot.awaiting_chat then
        for _, sub in ipairs({ pinokio('Вы взяли кусок мяса. Отнесите его в печку и включите её!') }) do
            if nt:find(sub, 1, true) then food_bot.raw_confirmed = true; break end
        end
    end
    if food_bot.active then
        if nt:find(pinokio('[Ошибка] Ваши руки заняты!'), 1, true) then food_bot.hands_full_error = true end
        if nt:find(pinokio('Вы вернули мясо на своё место'), 1, true) then
            food_bot.raw_return_confirmed = true
        end
    end
    if food_bot.active and food_bot.awaiting_fridge_chat then
        for _, sub in ipairs({ pinokio('Вы успешно положили в холодильник {97F85E}готовую{FFFFFF} еду!') }) do
            if nt:find(sub, 1, true) then food_bot.fridge_confirmed = true; break end
        end
    end
    if laundry_bot.active then
        if nt:find(pinokio('Вы уронили зековскую одежду'), 1, true) then
            laundry_bot.awaiting_chat = false; laundry_bot.state = 'scan_free'
            laundry_bot.carrying_dirty = false; laundry_bot.carrying_clean = false
        end
        for _, sub in ipairs({ pinokio('Вы взяли грязную одежду. Отнесите её в стиральную машину!') }) do
            if nt:find(sub, 1, true) then
                laundry_bot.carrying_dirty = true; laundry_bot.carrying_clean = false
                if laundry_bot.awaiting_chat then laundry_bot.dirty_pickup_confirmed = true end
                break
            end
        end
        for _, sub in ipairs({ pinokio('Вы взяли чистую одежду из стиральной машины. Отнесите на полку с чистой одеждой рядом.') }) do
            if nt:find(sub, 1, true) then
                laundry_bot.carrying_clean = true; laundry_bot.carrying_dirty = false
                if laundry_bot.awaiting_chat then laundry_bot.took_confirmed = true end
                break
            end
        end
        for _, sub in ipairs({ pinokio('Вы успешно положили чистую одежду из стиральной машины!') }) do
            if nt:find(sub, 1, true) then
                laundry_bot.carrying_clean = false; laundry_bot.carrying_dirty = false
                if laundry_bot.awaiting_chat then laundry_bot.delivered_confirmed = true end
                if work_counter.bot_name == 'laundry_bot' then work_counter_decrement() end
                break
            end
        end
        for _, sub in ipairs({ pinokio('Вы положили грязную одежду в стиральную машину. Вещи будут постираны через 2 минуты!') }) do
            if nt:find(sub, 1, true) then
                laundry_bot.carrying_dirty = false
                if laundry_bot.awaiting_chat then laundry_bot.put_confirmed = true end
                break
            end
        end
        if laundry_bot.awaiting_chat then
            for _, sub in ipairs({ pinokio('[Ошибка] У Вас в руках нет грязной одежды!'), pinokio('[Ошибка] У вас в руках нет грязной одежды!') }) do
                if nt:find(sub, 1, true) then laundry_bot.error_no_dirty = true; break end
            end
            for _, sub in ipairs({ pinokio('[Ошибка] У вас в руках нет чистой одежды!'), pinokio('[Ошибка] У Вас в руках нет чистой одежды!') }) do
                if nt:find(sub, 1, true) then laundry_bot.error_no_clean = true; break end
            end
        end
    end
end

local function food_count_self_cooking()
    local n = 0
    for _, ov in ipairs(food_bot.ovens) do
        for _, _ in pairs(ov.slots) do n = n + 1 end
    end
    return n
end
local laundry_scan_state = { last_scan = 0, cached_free = nil, cached_dirty = nil, c_finished = nil, c_near_finish = nil, c_delivery = nil }
local function laundry_tick()
    if not laundry_bot.active then
        if laundry_bot.was_active then stop_move(); laundry_bot.was_active = false end
        laundry_bot.awaiting_chat = false; laundry_bot.put_confirmed = false
        laundry_bot.took_confirmed = false; laundry_bot.delivered_confirmed = false
        laundry_bot.dirty_pickup_confirmed = false; laundry_bot.error_no_dirty = false
        laundry_bot.error_no_clean = false; laundry_bot.carrying_dirty = false
        laundry_bot.carrying_clean = false
        return
    end
    laundry_bot.was_active = true
    local now = os.clock()
    local px, py, pz = get_player_pos()
    local S = laundry_scan_state
    if now - S.last_scan >= cfg.laundry.scan_interval then
        S.last_scan = now
        S.cached_free = find_free_m(cfg.laundry.max_search, laundry_bot.used_machines, laundry_bot.last_used_machine_id)
        S.cached_dirty = find_txt(la_dirty_sub, cfg.laundry.max_search)
        S.c_finished = find_txt(la_fin_sub, cfg.laundry.max_search)
        S.c_near_finish = find_near_fin_cached(cfg.laundry.max_search)
        S.c_delivery = find_txt(la_clean_sub, cfg.laundry.max_search)
    end
    local moving_state = (laundry_bot.state == 'to_dirty' or laundry_bot.state == 'to_free_machine' or
        laundry_bot.state == 'to_finished' or laundry_bot.state == 'to_delivery' or
        laundry_bot.state == 'wait_for_finish' or laundry_bot.state == 'wait_at_delivery')
    if moving_state then
        if laundry_bot.stuck_t == 0 then laundry_bot.stuck_x, laundry_bot.stuck_y, laundry_bot.stuck_t = px, py, now end
        if now - laundry_bot.stuck_t > 0.9 then
            local moved = getDistanceBetweenCoords2d(laundry_bot.stuck_x, laundry_bot.stuck_y, px, py)
            if moved < 0.3 then side_dir = -side_dir; side_until = now + 2.4; avoid_dir = 0 end
            laundry_bot.stuck_x, laundry_bot.stuck_y, laundry_bot.stuck_t = px, py, now
        end
    else laundry_bot.stuck_t = 0 end
    local function approach(tx, ty, tz, radius, on_arrive)
        local d = dist3(tx, ty, tz)
        if d <= radius then laundry_bot.near_since = 0; on_arrive(); return end
        if d <= radius + 0.15 then
            if laundry_bot.near_since == 0 then laundry_bot.near_since = now end
            if now - laundry_bot.near_since > 0.15 then laundry_bot.near_since = 0; on_arrive(); return end
        else laundry_bot.near_since = 0 end
        steer_smart(tx, ty, tz, cfg.laundry.run, nil, cfg.laundry.avoid_obstacles)
    end
    local function laundry_idle_wait()
        local spot = laundry_bot.idle_spot
        if not spot or not (spot.id and sampIs3dTextDefined(spot.id)) then
            local choices = {}
            if S.c_delivery then table.insert(choices, S.c_delivery) end
            if S.cached_dirty then table.insert(choices, S.cached_dirty) end
            spot = (#choices > 0) and choices[math.random(#choices)] or nil
            laundry_bot.idle_spot = spot
        end
        if spot then
            local d = dist3(spot.x, spot.y, spot.z)
            if d and d > 1.5 then steer_smart(spot.x, spot.y, spot.z, cfg.laundry.run, nil, cfg.laundry.avoid_obstacles)
            else stop_move() end
        else
            stop_move()
        end
    end
    if laundry_bot.carrying_clean and laundry_bot.state ~= 'to_delivery' and laundry_bot.state ~= 'delivery_wait' then
        laundry_bot.state = 'to_delivery'
    end
    if laundry_bot.state == 'scan_free' then
        if laundry_bot.carrying_dirty then
            if S.cached_free then
                laundry_bot.free_machine = S.cached_free
                if S.cached_free.id then
                    laundry_bot.used_machines[S.cached_free.id] = now + cfg.laundry.machine_cooldown
                    laundry_bot.last_used_machine_id = S.cached_free.id
                end
                laundry_bot.state = 'to_free_machine'
            else stop_move() end
        elseif S.c_finished then laundry_bot.target = S.c_finished; laundry_bot.state = 'to_finished'
        elseif S.cached_dirty and S.cached_free then laundry_bot.target = S.cached_dirty; laundry_bot.state = 'to_dirty'
        elseif S.cached_dirty and not S.cached_free then laundry_bot.state = 'wait_machines'
        elseif S.c_delivery then laundry_bot.target = S.c_delivery; laundry_bot.state = 'wait_at_delivery'
        elseif S.cached_free and not S.cached_dirty then laundry_idle_wait()
        elseif S.c_near_finish then laundry_bot.target = S.c_near_finish; laundry_bot.state = 'wait_for_finish'
        else laundry_idle_wait() end
    elseif laundry_bot.state == 'wait_machines' then
        local wx, wy, wz = 1396.897, 1352.999, 10.939
        local d = dist3(wx, wy, wz)
        if S.cached_free and S.cached_dirty then laundry_bot.target = S.cached_dirty; laundry_bot.state = 'to_dirty'
        elseif S.c_finished then laundry_bot.target = S.c_finished; laundry_bot.state = 'to_finished'
        elseif S.c_near_finish then laundry_bot.target = S.c_near_finish; laundry_bot.state = 'wait_for_finish'
        elseif d > 3.0 then steer_smart(wx, wy, wz, cfg.laundry.run, nil, cfg.laundry.avoid_obstacles)
        else stop_move() end
    elseif laundry_bot.state == 'wait_at_delivery' then
        if S.c_finished then laundry_bot.target = S.c_finished; laundry_bot.state = 'to_finished'
        elseif S.cached_dirty and S.cached_free then laundry_bot.target = S.cached_dirty; laundry_bot.state = 'to_dirty'
        else
            local t = laundry_bot.target
            if not t then laundry_bot.state = 'scan_free'
            elseif t.id and not sampIs3dTextDefined(t.id) then laundry_bot.state = 'scan_free'
            else
                local d = dist3(t.x, t.y, t.z)
                if d and d > 1.0 then steer_smart(t.x, t.y, t.z, cfg.laundry.run, nil, cfg.laundry.avoid_obstacles)
                else stop_move() end
            end
        end
    elseif laundry_bot.state == 'to_dirty' then
        local live_dirty = S.cached_dirty or find_txt(la_dirty_sub, cfg.laundry.max_search)
        if not live_dirty then stop_move()
        else
            laundry_bot.target = live_dirty
            approach(live_dirty.x, live_dirty.y, live_dirty.z, cfg.laundry.pickup_radius, function()
                stop_move(); press_alt_la()
                laundry_bot.awaiting_chat = true
                laundry_bot.dirty_pickup_confirmed = false
                laundry_bot.error_no_dirty = false
                laundry_bot.wait_start = now
                laundry_bot.next_alt_press = now + 1.6
                laundry_bot.state = 'pick_dirty_wait'
            end)
        end
    elseif laundry_bot.state == 'pick_dirty_wait' then
        stop_move()
        if laundry_bot.dirty_pickup_confirmed then
            laundry_bot.awaiting_chat = false; laundry_bot.dirty_pickup_confirmed = false
            laundry_bot.dirty_fail_count = 0; laundry_bot.carrying_dirty = true
            laundry_bot.state = 'to_free_machine'
            if S.cached_free then
                laundry_bot.free_machine = S.cached_free
                if S.cached_free.id then
                    laundry_bot.used_machines[S.cached_free.id] = now + cfg.laundry.machine_cooldown
                    laundry_bot.last_used_machine_id = S.cached_free.id
                end
            end
        elseif laundry_bot.error_no_dirty or (now - laundry_bot.wait_start > 5) then
            laundry_bot.awaiting_chat = false; laundry_bot.error_no_dirty = false
            laundry_bot.step_until = now + 0.6; laundry_bot.state = 'step_to_dirty'
        elseif now >= (laundry_bot.next_alt_press or 0) then
            press_alt_la(); laundry_bot.next_alt_press = now + 1.6
        end
    elseif laundry_bot.state == 'step_to_dirty' then
        local live_dirty = find_txt(la_dirty_sub, cfg.laundry.max_search)
        if live_dirty then steer_smart(live_dirty.x, live_dirty.y, live_dirty.z, cfg.laundry.run, nil, cfg.laundry.avoid_obstacles) end
        if now >= (laundry_bot.step_until or 0) then
            stop_move()
            laundry_bot.dirty_fail_count = laundry_bot.dirty_fail_count + 1
            if laundry_bot.dirty_fail_count >= 2 then
                if cfg.laundry.jump then do_jump_this_frame = true end
                laundry_bot.dirty_fail_count = 0
            end
            laundry_bot.state = 'to_dirty'
        end
    elseif laundry_bot.state == 'to_free_machine' then
        if not laundry_bot.free_machine then laundry_bot.state = 'scan_free'
        else
            local fm = laundry_bot.free_machine
            approach(fm.x, fm.y, fm.z, cfg.laundry.machine_radius, function()
                if not laundry_bot.carrying_dirty then laundry_bot.state = 'scan_free'; laundry_bot.free_machine = nil; return end
                if not la_txt_match(fm, {la_free_sub}) then
                    if fm.id then laundry_bot.used_machines[fm.id] = now + 15 end
                    laundry_bot.free_machine = nil; laundry_bot.state = 'scan_free'; return
                end
                stop_move()
                if fm.id then
                    laundry_bot.used_machines[fm.id] = now + cfg.laundry.machine_cooldown
                    laundry_bot.last_used_machine_id = fm.id
                end
                press_alt_la()
                laundry_bot.awaiting_chat = true; laundry_bot.put_confirmed = false
                laundry_bot.error_no_dirty = false; laundry_bot.wait_start = now
                laundry_bot.next_alt_press = now + 1.6
                laundry_bot.state = 'put_machine_wait'
            end)
        end
    elseif laundry_bot.state == 'put_machine_wait' then
        stop_move()
        if laundry_bot.error_no_dirty then
            laundry_bot.awaiting_chat = false; laundry_bot.error_no_dirty = false
            laundry_bot.carrying_dirty = false; laundry_bot.free_machine = nil
            laundry_bot.state = 'scan_free'
        elseif laundry_bot.put_confirmed then
            laundry_bot.put_confirmed = false; laundry_bot.awaiting_chat = false
            laundry_bot.carrying_dirty = false; laundry_bot.free_machine = nil
            laundry_bot.state = 'scan_free'
        elseif now - laundry_bot.wait_start > cfg.laundry.chat_timeout then
            laundry_bot.awaiting_chat = false; laundry_bot.state = 'scan_free'
        elseif now >= (laundry_bot.next_alt_press or 0) then
            press_alt_la(); laundry_bot.next_alt_press = now + 1.6
        end
    elseif laundry_bot.state == 'wait_for_finish' then
        local t = laundry_bot.target
        if not t then laundry_bot.state = 'scan_free'
        else
            local d = dist3(t.x, t.y, t.z)
            if d > cfg.laundry.wait_radius + 1 then steer_smart(t.x, t.y, t.z, cfg.laundry.run, nil, cfg.laundry.avoid_obstacles)
            else stop_move() end
            if sampIs3dTextDefined(t.id) then
                local text = sampGet3dTextInfoById(t.id)
                if text then
                    local lt = bamnuc(text)
                    for _, sub in ipairs(la_fin_sub) do
                        if lt:find(bamnuc(sub), 1, true) then laundry_bot.state = 'to_finished'; break end
                    end
                end
            else laundry_bot.state = 'scan_free' end
        end
    elseif laundry_bot.state == 'to_finished' then
        if not laundry_bot.target then laundry_bot.state = 'scan_free'
        else
            local t = laundry_bot.target
            approach(t.x, t.y, t.z, cfg.laundry.machine_radius, function()
                if laundry_bot.carrying_clean then laundry_bot.state = 'to_delivery'; return end
                if not la_txt_match(t, la_fin_sub) then laundry_bot.state = 'scan_free'; return end
                stop_move(); press_alt_la()
                laundry_bot.awaiting_chat = true; laundry_bot.took_confirmed = false
                laundry_bot.error_no_clean = false; laundry_bot.wait_start = now
                laundry_bot.next_alt_press = now + 1.6
                laundry_bot.state = 'take_clean_wait'
            end)
        end
    elseif laundry_bot.state == 'take_clean_wait' then
        stop_move()
        if laundry_bot.took_confirmed or laundry_bot.carrying_clean then
            laundry_bot.awaiting_chat = false; laundry_bot.took_confirmed = false
            laundry_bot.carrying_clean = true; laundry_bot.state = 'to_delivery'
        elseif laundry_bot.error_no_clean then
            laundry_bot.awaiting_chat = false; laundry_bot.error_no_clean = false
            laundry_bot.state = 'scan_free'
        elseif now - laundry_bot.wait_start > cfg.laundry.chat_timeout then
            laundry_bot.awaiting_chat = false; laundry_bot.state = 'scan_free'
        elseif now >= (laundry_bot.next_alt_press or 0) then
            press_alt_la(); laundry_bot.next_alt_press = now + 1.6
        end
    elseif laundry_bot.state == 'to_delivery' then
        local delivery = S.c_delivery or find_txt(la_clean_sub, cfg.laundry.max_search)
        if not delivery then laundry_bot.state = 'scan_free'
        else
            approach(delivery.x, delivery.y, delivery.z, cfg.laundry.machine_radius, function()
                if not la_txt_match(delivery, la_clean_sub) then laundry_bot.state = 'scan_free'; return end
                stop_move(); press_alt_la()
                laundry_bot.awaiting_chat = true; laundry_bot.delivered_confirmed = false
                laundry_bot.error_no_clean = false; laundry_bot.wait_start = now
                laundry_bot.next_alt_press = now + 1.6
                laundry_bot.state = 'delivery_wait'
            end)
        end
    elseif laundry_bot.state == 'delivery_wait' then
        stop_move()
        if laundry_bot.delivered_confirmed then
            laundry_bot.awaiting_chat = false; laundry_bot.delivered_confirmed = false
            laundry_bot.carrying_clean = false
            if S.c_finished then laundry_bot.target = S.c_finished; laundry_bot.state = 'to_finished'
            else laundry_bot.state = 'scan_free' end
        elseif laundry_bot.error_no_clean then
            laundry_bot.awaiting_chat = false; laundry_bot.error_no_clean = false
            laundry_bot.state = 'scan_free'
        elseif now - laundry_bot.wait_start > cfg.laundry.chat_timeout then
            laundry_bot.awaiting_chat = false; laundry_bot.state = 'scan_free'
        elseif now >= (laundry_bot.next_alt_press or 0) then
            press_alt_la(); laundry_bot.next_alt_press = now + 1.6
        end
    end
end
lua_thread.create(function() while true do wait(0); laundry_tick() end end)
local function food_tick()
    if not food_bot.active then
        if food_bot.was_active then
            stop_move()
            food_bot.was_active = false
            food_reset_transient()
        end
        return
    end
    food_bot.was_active = true
    if food_bot.hands_full_error then
        food_bot.hands_full_error = false
        food_bot.raw_lock = nil
        food_bot.state = 'to_raw'
        food_bot.status = u8'Проверяю руки - иду к сырому мясу'
    end
    local px, py, pz = get_player_pos()
    local now = os.clock()
    local ready_count, cooking_count = 0, 0
    for _, ov in ipairs(food_bot.ovens) do
        for _, ready_at in pairs(ov.slots) do
            if ready_at - now <= 0 then ready_count = ready_count + 1
            else cooking_count = cooking_count + 1 end
        end
    end
    if ready_count > 0 then food_bot.status = string.format(u8'Готово %d, печка #%d', ready_count, food_bot.check_oven_idx)
    elseif cooking_count > 0 then food_bot.status = string.format(u8'Готовится %d, печка #%d', cooking_count, food_bot.check_oven_idx) end
    local moving_state = (food_bot.state == 'to_raw' or food_bot.state == 'to_oven' or food_bot.state == 'to_fridge'
        or food_bot.state == 'to_raw_return' or food_bot.state == 'raw_return_search')
    if moving_state and food_bot.target then
        local d = dist3(food_bot.target.x, food_bot.target.y, food_bot.target.z)
        if food_bot.stuck_t == 0 then
            food_bot.stuck_x, food_bot.stuck_y, food_bot.stuck_t = px, py, now
            food_bot.stuck_since = now
        end
        if now - food_bot.stuck_t > 0.9 then
            local moved = getDistanceBetweenCoords2d(food_bot.stuck_x, food_bot.stuck_y, px, py)
            if moved < 0.3 then
                side_dir = -side_dir; side_until = now + 2.4; avoid_dir = 0
            else
                food_bot.stuck_since = now
            end
            food_bot.stuck_x, food_bot.stuck_y, food_bot.stuck_t = px, py, now
        end
    else food_bot.stuck_t = 0; food_bot.stuck_since = 0 end
    local function approachTarget(tx, ty, tz, radius, onArrive)
        local d = dist3(tx, ty, tz)
        if d <= radius then food_bot.near_since = 0; onArrive(); return end
        if d <= radius * 2.2 then
            if food_bot.near_since == 0 then food_bot.near_since = now end
            if now - food_bot.near_since > 2.0 then food_bot.near_since = 0; onArrive(); return end
        else food_bot.near_since = 0 end
        food_steer_smart(tx, ty, tz, cfg.food.run, nil, cfg.food.avoid_obstacles)
    end
    if food_bot.state == 'discover' then
        if #food_bot.ovens == 0 then
            local list = find_all_txt_n_cached(food_ovn_req_lc, cfg.food.max_search)
            for _, item in ipairs(list) do
                local dup = false
                for _, ov in ipairs(food_bot.ovens) do
                    if getDistanceBetweenCoords3d(item.x, item.y, item.z, ov.x, ov.y, ov.z) < 1.5 then dup = true; break end
                end
                if not dup then table.insert(food_bot.ovens, { x = item.x, y = item.y, z = item.z, slots = {} }) end
            end
            if #food_bot.ovens == 0 then food_bot.status = u8'Нет печек'; stop_move(); return end
        end
        food_bot.check_oven_idx = 1
        food_bot.visited_since_action = 0
        food_bot.return_oven_idx = nil
        food_bot.found_empty_oven_idx = nil
        food_bot.round_active = true
        food_bot.round_idx = 1
        food_bot.round_any_cooking = false
        food_bot.fill_queue = {}
        if not food_bot.first_scan_active then
            food_bot.first_scan_active = true
            food_bot.first_scan_idx = 1
        end
        food_bot.state = 'plan'
    elseif food_bot.state == 'plan' then
        if food_bot.first_scan_active then
            local ov = food_bot.ovens[food_bot.first_scan_idx]
            if not ov then
                food_bot.first_scan_active = false
                food_bot.check_oven_idx = 1
                food_bot.state = 'plan'
            else
                food_bot.check_oven_idx = food_bot.first_scan_idx
                food_bot.target = ov
                food_bot.expect_ready = false
                food_bot.state = 'to_oven'
                food_bot.status = string.format(u8'Первый обход печек: #%d/%d', food_bot.first_scan_idx, #food_bot.ovens)
            end
        elseif food_bot.carrying_cooked then
            food_bot.state = 'to_fridge'
            food_bot.status = u8'Несу готовое в холодильник'
        else
            local ready_idx, soon_idx = nil, nil
            for idx, ov in ipairs(food_bot.ovens) do
                for _, ready_at in pairs(ov.slots) do
                    local left = ready_at - now
                    if left <= 0 and not ready_idx then ready_idx = idx
                    elseif left > 0 and left <= 20 and not soon_idx then soon_idx = idx end
                end
            end
            if not food_bot.carrying_raw and ready_idx then
                food_bot.check_oven_idx = ready_idx
                food_bot.expect_ready = true
                food_bot.target = food_bot.ovens[ready_idx]
                food_bot.state = 'to_oven'
                food_bot.status = u8'Готовое в печке, иду забирать'
            elseif not food_bot.carrying_raw and soon_idx then
                food_bot.check_oven_idx = soon_idx
                food_bot.expect_ready = true
                food_bot.target = food_bot.ovens[soon_idx]
                food_bot.state = 'to_oven'
                food_bot.status = u8'Скоро готово, иду ждать'
            else
                local n = #food_bot.ovens
                if n == 0 then
                    food_bot.status = u8'Нет известных печек'
                    stop_move()
                else
                    local chosen = food_bot.check_oven_idx
                    food_bot.check_oven_idx = chosen
                    food_bot.expect_ready = false
                    food_bot.target = food_bot.ovens[chosen]
                    food_bot.state = 'to_oven'
                    food_bot.status = food_bot.carrying_raw and u8'Несу сырое к печке' or u8'Проверяю печку'
                end
            end
        end
    elseif food_bot.state == 'to_oven' then
        local ov = food_bot.ovens[food_bot.check_oven_idx]
        if not ov then food_bot.state = 'plan'; return end
        approachTarget(ov.x, ov.y, ov.z, cfg.food.oven_radius, function()
            stop_move()
            food_dialog.active = false
            press_alt_fd()
            food_bot.wait_start = now
            food_bot.oven_wait_started_at = now
            food_bot.state = 'oven_dialog_wait'
        end)
    elseif food_bot.state == 'oven_dialog_wait' then
        stop_move()
        if food_bot.first_scan_active then
            if food_dialog.active and food_dialog.kind == 'oven' then
                local ready_row, empty_row = nil, nil
                for _, r in ipairs(food_dialog.rows) do
                    local st = bamnuc(r.state)
                    if not ready_row and st:find('готовое', 1, true) then ready_row = r end
                    if not empty_row and st:find('пустая', 1, true) then empty_row = r end
                end
                local oven_rec = food_bot.ovens[food_bot.check_oven_idx]
                if not ready_row and oven_rec then
                for k, v in pairs(oven_rec.slots) do
                    if v <= now then oven_rec.slots[k] = nil end
                end
            end
                if ready_row and not food_bot.carrying_raw then
                    sampSendDialogResponse(food_dialog.id, 1, ready_row.idx, '')
                    food_dialog.active = false
                    food_bot.carrying_cooked = true
                    if oven_rec then oven_rec.slots[ready_row.idx] = nil end
                    food_bot.first_scan_idx = food_bot.first_scan_idx + 1
                    food_bot.state = 'to_fridge'
                else
                    sampSendDialogResponse(food_dialog.id, 0, 0, '')
                    food_dialog.active = false
                    food_bot.first_scan_idx = food_bot.first_scan_idx + 1
                    food_bot.state = 'plan'
                end
            elseif now - food_bot.oven_wait_started_at > cfg.food.oven_dialog_give_up then
                food_dialog.active = false
                food_bot.first_scan_idx = food_bot.first_scan_idx + 1
                food_bot.state = 'plan'
            elseif now - food_bot.wait_start > cfg.food.dialog_wait then
                press_alt_fd()
                food_bot.wait_start = now
            end
        elseif food_dialog.active and food_dialog.kind == 'oven' then
            local ready_row, empty_row = nil, nil
            for _, r in ipairs(food_dialog.rows) do
                local st = bamnuc(r.state)
                if not ready_row and st:find('готовое', 1, true) then ready_row = r end
                if not empty_row and st:find('пустая', 1, true) then empty_row = r end
            end
            local oven_rec = food_bot.ovens[food_bot.check_oven_idx]
            if not ready_row and oven_rec then
                for k, v in pairs(oven_rec.slots) do
                    if v <= now then oven_rec.slots[k] = nil end
                end
            end
            if ready_row and not food_bot.carrying_raw then
                sampSendDialogResponse(food_dialog.id, 1, ready_row.idx, '')
                food_dialog.active = false
                food_bot.carrying_cooked = true
                food_bot.expect_ready = false
                if oven_rec then oven_rec.slots[ready_row.idx] = nil end
                food_bot.state = 'to_fridge'
                food_bot.status = u8'Забрал готовое'
            elseif food_bot.carrying_raw and empty_row then
                sampSendDialogResponse(food_dialog.id, 1, empty_row.idx, '')
                food_dialog.active = false
                food_bot.carrying_raw = false
                food_bot.expect_ready = false
                if oven_rec then oven_rec.slots[empty_row.idx] = now + food_cook_s end
                food_bot.state = 'plan'
                food_bot.status = u8'Положил мясо'
            elseif (not food_bot.carrying_raw) and empty_row then
                sampSendDialogResponse(food_dialog.id, 0, 0, '')
                food_dialog.active = false
                if food_bot.expect_ready then
                    food_bot.state = 'plan'
                    food_bot.status = u8'Жду готовности'
                else
                    food_bot.state = 'to_raw'
                    food_bot.status = u8'Есть место, иду за сырым'
                end
            else
                sampSendDialogResponse(food_dialog.id, 0, 0, '')
                food_dialog.active = false
                food_bot.check_oven_idx = (food_bot.check_oven_idx % #food_bot.ovens) + 1
                food_bot.state = 'plan'
                food_bot.status = u8'Печка занята, иду к следующей'
            end
        elseif now - food_bot.oven_wait_started_at > cfg.food.oven_dialog_give_up then
            food_dialog.active = false
            food_bot.check_oven_idx = (food_bot.check_oven_idx % #food_bot.ovens) + 1
            food_bot.state = 'plan'
        elseif now - food_bot.wait_start > cfg.food.dialog_wait then
            press_alt_fd()
            food_bot.wait_start = now
        end
    elseif food_bot.state == 'wait_meat_ready' then
        stop_move()
        local any_ready, have_tracked_slot, earliest_ready = false, false, nil
        for _, ov in ipairs(food_bot.ovens) do
            for _, ready_at in pairs(ov.slots) do
                have_tracked_slot = true
                if ready_at - now <= 0 then any_ready = true end
                if not earliest_ready or ready_at < earliest_ready then earliest_ready = ready_at end
            end
        end
        if any_ready then
            food_bot.state = 'plan'
        elseif have_tracked_slot then
            if earliest_ready and now >= earliest_ready then
                food_bot.state = 'plan'
            end
        elseif now - food_bot.wait_start > 20 then
            food_bot.state = 'plan'
            food_bot.check_oven_idx = 1
        end
    elseif food_bot.state == 'to_raw' then
        local pre_ready_idx = nil
        for idx, ov in ipairs(food_bot.ovens) do
            for _, ready_at in pairs(ov.slots) do
                if ready_at - now <= 20 then pre_ready_idx = idx; break end
            end
            if pre_ready_idx then break end
        end
        if pre_ready_idx and not food_bot.carrying_raw then
            food_bot.raw_lock = nil
            food_bot.check_oven_idx = pre_ready_idx
            food_bot.expect_ready = true
            food_bot.target = food_bot.ovens[pre_ready_idx]
            food_bot.state = 'to_oven'
            food_bot.status = u8'Готовое в печке, иду забирать'
        else
            if food_bot.raw_lock and not sampIs3dTextDefined(food_bot.raw_lock.id) then food_bot.raw_lock = nil end
            if not food_bot.raw_lock then food_bot.raw_lock = find_txt_n_cached(food_raw_req_lc, cfg.food.max_search) end
            local raw = food_bot.raw_lock
            if not raw then
                stop_move()
                if food_bot.search_started_at == 0 then food_bot.search_started_at = now end
                food_bot.status = u8'Ищу сырое мясо'
                if now - food_bot.search_started_at > cfg.food.search_stuck_timeout then
                    food_bot.search_started_at = 0
                    food_bot.state = 'discover'
                elseif now >= (food_bot.search_nudge_at or 0) then
                    do_jump_this_frame = true
                    food_bot.search_nudge_at = now + 3
                end
            else
                food_bot.search_started_at = 0
                food_bot.target = raw
                food_bot.raw_origin = { x = raw.x, y = raw.y, z = raw.z }
                approachTarget(raw.x, raw.y, raw.z, cfg.food.pickup_radius, function()
                    stop_move()
                    food_bot.raw_lock = nil
                    press_alt_fd()
                    food_bot.awaiting_chat = true
                    food_bot.raw_confirmed = false
                    food_bot.wait_start = now
                    food_bot.next_alt_press = now + 1.6
                    food_bot.alt_retries = 0
                    food_bot.state = 'raw_wait'
                end)
            end
        end
    elseif food_bot.state == 'raw_wait' then
        stop_move()
        if food_bot.raw_confirmed then
            food_bot.awaiting_chat = false; food_bot.raw_confirmed = false
            food_bot.carrying_raw = true
            food_bot.state = 'plan'
        elseif now - food_bot.wait_start > cfg.food.chat_timeout then
            food_bot.awaiting_chat = false
            food_bot.carrying_raw = true
            food_bot.state = 'plan'
        elseif now - food_bot.wait_start > 3.5 and (food_bot.alt_retries or 0) < 1 then
            food_bot.alt_retries = (food_bot.alt_retries or 0) + 1
            press_alt_fd()
        end
    elseif food_bot.state == 'to_fridge' then
        if food_bot.fridge_lock and not sampIs3dTextDefined(food_bot.fridge_lock.id) then food_bot.fridge_lock = nil end
        if not food_bot.fridge_lock then food_bot.fridge_lock = find_txt_n_cached(food_fr_req_lc, cfg.food.max_search) end
        local fridge = food_bot.fridge_lock
        if not fridge then
            stop_move()
            if food_bot.search_started_at == 0 then food_bot.search_started_at = now end
            food_bot.status = u8'Ищу холодильник'
            if now - food_bot.search_started_at > cfg.food.search_stuck_timeout then
                food_bot.search_started_at = 0
                food_bot.state = 'discover'
            elseif now >= (food_bot.search_nudge_at or 0) then
                do_jump_this_frame = true
                food_bot.search_nudge_at = now + 3
            end
        else
            food_bot.search_started_at = 0
            food_bot.target = fridge
            approachTarget(fridge.x, fridge.y, fridge.z, cfg.food.fridge_radius, function()
                food_bot.fridge_lock = nil
                stop_move()
                food_dialog.active = false
                press_alt_fd()
                food_bot.wait_start = now
                food_bot.awaiting_fridge_chat = true
                food_bot.fridge_confirmed = false
                food_bot.fridge_wait_start = now
                food_bot.next_alt_press = now + 1.6
                food_bot.state = 'fridge_dialog_wait'
            end)
        end
    elseif food_bot.state == 'fridge_dialog_wait' then
        stop_move()
        local function finish_fridge()
            food_bot.carrying_cooked = false
            food_bot.awaiting_fridge_chat = false
            food_bot.fridge_confirmed = false
            if work_counter.bot_name == 'food_bot' then work_counter_decrement() end
            if food_bot.return_oven_idx then
                food_bot.check_oven_idx = food_bot.return_oven_idx
                food_bot.return_oven_idx = nil
            end
            food_bot.visited_since_action = 0
            food_bot.state = 'plan'
        end
        if food_dialog.active and food_dialog.kind == 'fridge' then
            local row = food_dialog.rows[1]
            if row then sampSendDialogResponse(food_dialog.id, 1, row.idx, '')
            else sampSendDialogResponse(food_dialog.id, 1, 0, '') end
            food_dialog.active = false
            finish_fridge()
        elseif food_bot.fridge_confirmed then
            finish_fridge()
        elseif now - food_bot.fridge_wait_start > cfg.food.fridge_confirm_timeout then
            food_bot.carrying_cooked = false; food_bot.awaiting_fridge_chat = false
            food_bot.fridge_confirmed = false; do_jump_this_frame = true
            food_bot.state = 'plan'
        elseif now - food_bot.wait_start > cfg.food.dialog_wait and (not food_bot.awaiting_fridge_chat) then
            food_bot.awaiting_fridge_chat = true
            food_bot.fridge_wait_start = now
            food_bot.next_alt_press = now + 1.6
        elseif food_bot.awaiting_fridge_chat and now >= (food_bot.next_alt_press or 0) then
            press_alt_fd(); food_bot.next_alt_press = now + 1.6
        end
    end
end
lua_thread.create(function() while true do wait(0); food_tick() end end)
food_check_dists = { 1.5, 2.5, 3.5 }
function food_check_angle(px, py, pz, a)
    local r = math.rad(a)
    local dx, dy = math.sin(r), math.cos(r)
    for _, d in ipairs(food_check_dists) do
        local ex, ey = px + dx * d, py + dy * d
        if not los_clear_scan(px, py, pz + 0.6, ex, ey, pz + 0.6) then return false end
    end
    return true
end
food_slide_state = { dir = 0, angle = 0 }
function food_steer_variant1(tx, ty, tz, run_override, opts)
    opts = opts or {}
    local px, py, pz = get_player_pos()
    local base = getHeadingFromVector2d(tx - px, ty - py)
    if los_ok and not food_check_angle(px, py, pz, base) then
        if food_slide_state.dir == 0 then
            local right_ok = food_check_angle(px, py, pz, base + 25)
            food_slide_state.dir = right_ok and 1 or -1
        end
        food_slide_state.angle = math.min(85, (food_slide_state.angle or 0) + 3)
    else
        food_slide_state.angle = math.max(0, (food_slide_state.angle or 0) - 5)
        if food_slide_state.angle == 0 then food_slide_state.dir = 0 end
    end
    local chosen = base + food_slide_state.dir * (food_slide_state.angle or 0)
    set_tgt_angle(chosen + (opts.look or 0))
    smooth_cam(opts.camFactor or 0.12, opts.camMin or 0.3, opts.maxStep)
    setGameKeyState(1, -255)
    is_running = (run_override == nil) or run_override
end
food_wall_state = { side = 0, until_t = 0, last_dir = 0 }
function food_steer_variant2(tx, ty, tz, run_override, opts)
    opts = opts or {}
    local px, py, pz = get_player_pos()
    local base = getHeadingFromVector2d(tx - px, ty - py)
    local now = os.clock()
    local chosen = base
    if los_ok then
        local blocked = not food_check_angle(px, py, pz, base)
        if blocked and food_wall_state.side == 0 then
            local right_ok = food_check_angle(px, py, pz, base + 75)
            food_wall_state.side = right_ok and 1 or -1
        end
        if blocked then
            chosen = base + food_wall_state.side * 65
            food_wall_state.until_t = now + 0.35
            food_wall_state.last_dir = food_wall_state.side
        elseif now < food_wall_state.until_t then
            chosen = base + food_wall_state.side * 35
        elseif food_wall_state.last_dir ~= 0 then
            chosen = base + food_wall_state.last_dir * 15
            if food_check_angle(px, py, pz, base) then
                food_wall_state.side = 0
                food_wall_state.last_dir = 0
            end
        end
    end
    set_tgt_angle(chosen + (opts.look or 0))
    smooth_cam(opts.camFactor or 0.12, opts.camMin or 0.3, opts.maxStep)
    setGameKeyState(1, -255)
    is_running = (run_override == nil) or run_override
end
food_wide_state = { side = 0, until_t = 0, stuck_count = 0, last_pos = nil, last_check = 0, back_until = 0 }
function food_steer_variant3(tx, ty, tz, run_override, opts)
    opts = opts or {}
    local px, py, pz = get_player_pos()
    local base = getHeadingFromVector2d(tx - px, ty - py)
    local now = os.clock()
    if now - (food_wide_state.last_check or 0) > 0.8 then
        food_wide_state.last_check = now
        local lp = food_wide_state.last_pos
        if lp and getDistanceBetweenCoords2d(lp.x, lp.y, px, py) < 0.25 then
            food_wide_state.stuck_count = food_wide_state.stuck_count + 1
        else
            food_wide_state.stuck_count = 0
        end
        food_wide_state.last_pos = { x = px, y = py }
    end
    if food_wide_state.stuck_count >= 2 and now >= (food_wide_state.until_t or 0) then
        food_wide_state.side = (math.random(0, 1) == 0) and -1 or 1
        food_wide_state.until_t = now + 1.6
        food_wide_state.back_until = now + 0.5
        food_wide_state.stuck_count = 0
    end
    local chosen = base
    if now < food_wide_state.back_until then
        chosen = base + 180
        set_tgt_angle(chosen)
        smooth_cam(opts.camFactor or 0.12, opts.camMin or 0.3, opts.maxStep)
        setGameKeyState(1, -255)
        is_running = false
        return
    end
    if now < (food_wide_state.until_t or 0) and food_wide_state.side ~= 0 then
        chosen = base + food_wide_state.side * 115
    elseif los_ok and not food_check_angle(px, py, pz, base) then
        local right_ok = food_check_angle(px, py, pz, base + 50)
        chosen = base + (right_ok and 50 or -50)
    end
    set_tgt_angle(chosen + (opts.look or 0))
    smooth_cam(opts.camFactor or 0.12, opts.camMin or 0.3, opts.maxStep)
    setGameKeyState(1, -255)
    is_running = (run_override == nil) or run_override
end
food_smart_state = { wall_dir = 0, wall_until = 0, stuck_count = 0, last_pos = nil, last_check = 0, escalate_until = 0, escalate_side = 0, back_until = 0 }
function food_steer_variant4(tx, ty, tz, run_override, opts)
    opts = opts or {}
    local px, py, pz = get_player_pos()
    local base = getHeadingFromVector2d(tx - px, ty - py)
    local now = os.clock()
    local S = food_smart_state

    if now - (S.last_check or 0) > 0.8 then
        S.last_check = now
        local lp = S.last_pos
        if lp and getDistanceBetweenCoords2d(lp.x, lp.y, px, py) < 0.25 then
            S.stuck_count = S.stuck_count + 1
        else
            S.stuck_count = 0
        end
        S.last_pos = { x = px, y = py }
    end

    if S.stuck_count >= 5 and now >= (S.escalate_until or 0) and now >= (S.back_until or 0) then
        S.back_until = now + 0.45
        local left_ok = food_check_angle(px, py, pz, base - 100)
        local right_ok = food_check_angle(px, py, pz, base + 100)
        if left_ok and not right_ok then S.escalate_side = -1
        elseif right_ok and not left_ok then S.escalate_side = 1
        else S.escalate_side = (math.random(0, 1) == 0) and -1 or 1 end
        S.escalate_until = now + 0.45 + 2.5
        S.stuck_count = 0
        S.wall_dir = 0
    end

    if now < (S.back_until or 0) then
        set_tgt_angle(base + 180)
        smooth_cam(opts.camFactor or 0.12, opts.camMin or 0.3, opts.maxStep)
        setGameKeyState(1, -255)
        is_running = false
        return
    end

    local chosen = base
    if now < (S.escalate_until or 0) then
        chosen = base + S.escalate_side * 110
    elseif los_ok then
        local blocked = not food_check_angle(px, py, pz, base)
        if blocked and S.wall_dir == 0 then
            local right_ok = food_check_angle(px, py, pz, base + 70)
            S.wall_dir = right_ok and 1 or -1
        end
        if blocked then
            chosen = base + S.wall_dir * 60
            S.wall_until = now + 0.35
        elseif now < (S.wall_until or 0) then
            chosen = base + S.wall_dir * 30
        elseif S.wall_dir ~= 0 then
            chosen = base + S.wall_dir * 12
            if food_check_angle(px, py, pz, base) then S.wall_dir = 0 end
        end
    end
    set_tgt_angle(chosen + (opts.look or 0))
    smooth_cam(opts.camFactor or 0.12, opts.camMin or 0.3, opts.maxStep)
    setGameKeyState(1, -255)
    is_running = (run_override == nil) or run_override
end
function food_steer_variant5(tx, ty, tz, run_override, opts)
    opts = opts or {}
    local px, py, pz = get_player_pos()
    local base = getHeadingFromVector2d(tx - px, ty - py)
    local chosen = base
    if los_ok then
        local best_off, best_score = 0, -1
        for _, off in ipairs({ 0, -15, 15, -30, 30, -45, 45, -60, 60 }) do
            local clear = 0
            for _, d in ipairs({ 1.5, 2.5, 3.5, 5.0 }) do
                local r = math.rad(base + off)
                local ex, ey = px + math.sin(r) * d, py + math.cos(r) * d
                if los_clear_scan(px, py, pz + 0.6, ex, ey, pz + 0.6) then clear = clear + 1
                else break end
            end
            local score = clear - math.abs(off) / 90
            if score > best_score then best_score = score; best_off = off end
        end
        chosen = base + best_off
    end
    set_tgt_angle(chosen + (opts.look or 0))
    smooth_cam(opts.camFactor or 0.12, opts.camMin or 0.3, opts.maxStep)
    setGameKeyState(1, -255)
    is_running = (run_override == nil) or run_override
end
function food_steer_variant6(tx, ty, tz, run_override, opts)
    opts = opts or {}
    local px, py, pz = get_player_pos()
    local base = getHeadingFromVector2d(tx - px, ty - py)
    local chosen = base
    if los_ok and not food_check_angle(px, py, pz, base) then
        local found = false
        for _, off in ipairs({ 10, -10, 20, -20, 30, -30, 45, -45, 60, -60, 90, -90 }) do
            if food_check_angle(px, py, pz, base + off) then
                chosen = base + off
                found = true
                break
            end
        end
        if not found then chosen = base + 180 end
    end
    set_tgt_angle(chosen + (opts.look or 0))
    smooth_cam(opts.camFactor or 0.12, opts.camMin or 0.3, opts.maxStep)
    setGameKeyState(1, -255)
    is_running = (run_override == nil) or run_override
end
function food_steer_smart(tx, ty, tz, run_override, opts, avoid_enabled)
    local mode = cfg.food.avoid_mode or 0
    if mode == 1 then food_steer_variant1(tx, ty, tz, run_override, opts)
    elseif mode == 2 then food_steer_variant2(tx, ty, tz, run_override, opts)
    elseif mode == 3 then food_steer_variant3(tx, ty, tz, run_override, opts)
    elseif mode == 4 then food_steer_variant4(tx, ty, tz, run_override, opts)
    elseif mode == 5 then food_steer_variant5(tx, ty, tz, run_override, opts)
    elseif mode == 6 then food_steer_variant6(tx, ty, tz, run_override, opts)
    else steer_smart(tx, ty, tz, run_override, opts, avoid_enabled) end
end
local function trash_tick()
    if not bot.active then
        if bot.was_active then stop_move(); bot.was_active = false end
        bot.picked = false
        return
    end
    bot.was_active = true
    local px, py, pz = get_player_pos()
    local has_target = (bot.state == 'to_item' and bot.item ~= nil) or (bot.state == 'to_trash' and bot.trash ~= nil)
    local near_target = false
    if bot.state == 'to_item' and bot.item then
        local d = dist3(bot.item.x, bot.item.y, bot.item.z)
        near_target = d <= cfg.bot.pickup_radius
    elseif bot.state == 'to_trash' and bot.trash then
        local d = dist3(bot.trash.x, bot.trash.y, bot.trash.z)
        near_target = d <= cfg.bot.handin_radius
    end
    local in_anim = os.clock() < (bot.anim_until or 0)
    if has_target and not near_target and not in_anim then
        if bot.stuck_t == 0 then bot.stuck_x, bot.stuck_y, bot.stuck_t = px, py, os.clock() end
        if os.clock() - bot.stuck_t > 0.9 then
            local moved = getDistanceBetweenCoords2d(bot.stuck_x, bot.stuck_y, px, py)
            if moved < 0.3 then side_dir = -side_dir; side_until = os.clock() + 2.4; avoid_dir = 0; do_jump_this_frame = true end
            bot.stuck_x, bot.stuck_y, bot.stuck_t = px, py, os.clock()
        end
    else bot.stuck_t = 0 end
    local function approach(tx, ty, tz, radius, on_arrive)
        local d = dist3(tx, ty, tz)
        if d <= radius then bot.near_since = 0; on_arrive(); return end
        if d <= radius * 2.2 then
            if bot.near_since == 0 then bot.near_since = os.clock() end
            if os.clock() - bot.near_since > 2.0 then bot.near_since = 0; on_arrive(); return end
        else bot.near_since = 0 end
        steer_smart(tx, ty, tz, cfg.bot.run, {camFactor = 0.08, camMin = 0.2, maxStep = 6.0}, cfg.bot.avoid_obstacles)
    end
    if bot.state == 'find' then
        local now_find = os.clock()
        if now_find - (bot.last_find_at or 0) >= 3 then bot.last_find_at = now_find; bot.item = find_item() end
        if bot.item then bot.state = 'to_item' else stop_move() end
    elseif bot.state == 'to_item' then
        if not bot.item or not doesObjectExist(bot.item.handle) then bot.state = 'find'
        else
            approach(bot.item.x, bot.item.y, bot.item.z, cfg.bot.pickup_radius, function()
                stop_move()
                bot.stuck_t = 0
                if cfg.bot.alt_pickup then press_alt() end
                bot.picked = false; bot.wait_start = os.clock()
                bot.anim_until = os.clock() + 2.5
                bot.state = 'wait_pickup'
            end)
        end
    elseif bot.state == 'wait_pickup' then
        stop_move()
        if bot.picked then
            bot.picked = false; bot.retries = 0; bot.trash = nil
            bot.anim_until = os.clock() + 2.0
            bot.state = 'to_trash'
        elseif os.clock() - bot.wait_start > 4 then
            if bot.retries < 3 then
                bot.retries = bot.retries + 1
                if cfg.bot.alt_pickup then press_alt() end
                bot.wait_start = os.clock()
            else bot.retries = 0; bot.picked = false; bot.state = 'find' end
        end
    elseif bot.state == 'to_trash' then
        if not bot.trash then bot.trash = find_trash() end
        if not bot.trash then bot.state = 'find'
        else
            approach(bot.trash.x, bot.trash.y, bot.trash.z, cfg.bot.handin_radius, function()
                stop_move()
                if cfg.bot.alt_pickup then press_alt() end
                bot.collected = bot.collected + 1
                if work_counter.bot_name == 'bot' then work_counter_decrement() end
                bot.state = 'find'
            end)
        end
    end
end
lua_thread.create(function() while true do wait(0); trash_tick() end end)
box_path = {
    { x = 257.86, y = 2012.86, z = 16.64, r = 1.8, alt = true },
    { x = 211.674, y = 2014.011, z = 17.667, r = 2.2 },
    { x = 212.415, y = 2019.332, z = 17.667, r = 2.2 },
    { x = 234.131, y = 2021.774, z = 17.687, r = 1.5 },
    { x = 239.1629943848, y = 2026.7818603516, z = 16.687019348145, r = 1.8, alt = true },
    { x = 234.131, y = 2021.774, z = 17.687, r = 1.5 },
    { x = 212.415, y = 2019.332, z = 17.667, r = 2.2 },
    { x = 211.674, y = 2014.011, z = 17.667, r = 2.2 },
}
box_path_idx = 1
box = { active=false, stuck_x=0, stuck_y=0, stuck_t=0, was_active=false }
tsr_font = renderCreateFont('Arial', 10, 5)
function draw_arrow(target_x, target_y, target_z, color)
    local px, py, pz = get_player_pos()
    local okh, heading = pcall(getCharHeading, PLAYER_PED)
    if not okh or not heading then return end
    local tgt_heading = getHeadingFromVector2d(target_x - px, target_y - py)
    local diff = tgt_heading - heading
    while diff > 180 do diff = diff - 360 end
    while diff < -180 do diff = diff + 360 end
    local rad = math.rad(diff)
    local sw, sh = getScreenResolution()
    local cx, cy = sw / 2, sh / 2
    local edge_margin = 60
    local radius_x = cx - edge_margin
    local radius_y = cy - edge_margin
    local dx = math.sin(rad)
    local dy = -math.cos(rad)
    local scale = math.min(dx ~= 0 and math.abs(radius_x / dx) or math.huge, dy ~= 0 and math.abs(radius_y / dy) or math.huge)
    local ax = cx + dx * scale
    local ay = cy + dy * scale
    local arrow_rad = rad
    local size = 14
    local p1x = ax + math.sin(arrow_rad) * size
    local p1y = ay - math.cos(arrow_rad) * size
    local p2x = ax + math.sin(arrow_rad + 2.6) * (size * 0.6)
    local p2y = ay - math.cos(arrow_rad + 2.6) * (size * 0.6)
    local p3x = ax + math.sin(arrow_rad - 2.6) * (size * 0.6)
    local p3y = ay - math.cos(arrow_rad - 2.6) * (size * 0.6)
    renderDrawLine(p1x, p1y, p2x, p2y, 3, color)
    renderDrawLine(p1x, p1y, p3x, p3y, 3, color)
    renderDrawLine(p2x, p2y, p3x, p3y, 3, color)
end
lua_thread.create(function()
    while true do
        wait(500)
        if cfg.tsrhelper.auto_rm_cell or cfg.tsrhelper.auto_rm_door or cfg.tsrhelper.auto_rm_fence then
            local objs = tick_cache.objects
            for i = 1, #objs do
                local obj = objs[i]
                local m = getObjectModel(obj)
                if cfg.tsrhelper.auto_rm_cell and m == 19303 then deleteObject(obj)
                elseif cfg.tsrhelper.auto_rm_door and m == 19857 then deleteObject(obj)
                elseif cfg.tsrhelper.auto_rm_fence and (m == 19912 or m == 19913) then deleteObject(obj) end
            end
        end
    end
end)
lua_thread.create(function()
    while true do
        wait(100)
        if cfg.tsrhelper.render_lockpick then
            local list = find_all_txt_n_cached({ pinokio('отмычка') }, 300)
            if #list > 0 then
                local px, py, pz = get_player_pos()
                for i = 1, #list do
                    local item = list[i]
                    local on_screen_ok, on_screen = pcall(isPointOnScreen, item.x, item.y, item.z, 0.0)
                    if on_screen_ok and on_screen then
                        local c1, c2 = convert3DCoordsToScreen(px, py, pz)
                        local o1, o2 = convert3DCoordsToScreen(item.x, item.y, item.z)
                        local dist = math.floor(item.dist)
                        renderDrawLine(c1, c2, o1, o2, 1, 0xB8FCB8FF)
                        renderFontDrawText(tsr_font, ('Отмычка\nDIST: ' .. dist .. 'м.'), o1, o2, -1)
                    else draw_arrow(item.x, item.y, item.z, 0xB8FCB8FF) end
                end
            end
        end
    end
end)
lua_thread.create(function()
    while true do
        wait(200)
        if chips_buy.pending then
            if chips_buy.bought >= chips_buy.target then chips_buy.pending = false
            elseif os.clock() - chips_buy.wait_start > 8 then chips_buy.pending = false
            elseif os.clock() - chips_buy.wait_start > 1.5 then
                chips_buy.bought = chips_buy.bought + 1
                chips_buy.wait_start = os.clock()
                if chips_buy.bought < chips_buy.target then press_alt() end
            end
        end
    end
end)
last_atk_id = nil
last_atk_at = 0
last_tg_attacker = {}
function sampev.onSendDeathNotification(reason, killer_id)
    bot.active = false; laundry_bot.active = false
    food_bot.active = false; box.active = false
    pcall(function() setGameKeyState(1, 0); is_running = false; cam_was_act = false end)
    local nick = 'Unknown'
    if last_atk_id then
        local okn, resn = pcall(sampGetPlayerNickname, last_atk_id)
        if okn and resn then nick = resn end
    end
    tg_send(tg_cfg.settings.token, tg_cfg.settings.chat_id, u8('меня убил - ' .. nick .. ', я закончил работу.'))
    chat_add('{FF5555}[zumi] Меня убил ' .. chat_str(nick) .. ', работа остановлена.', -1)
end
function sampev.onSendTakeDamage(player_id, damage, weapon)
    if player_id == 65535 then return end
    local id_ok = tonumber(player_id) ~= nil and player_id >= 0 and player_id <= 999
    if not id_ok then return end
    local connected = false
    local okc, res = pcall(sampIsPlayerConnected, player_id)
    if okc then connected = res end
    if not connected then return end
    last_atk_id = player_id; last_atk_at = os.clock()
    if cfg.healbot.notify_on_hit then
        local now = os.clock()
        if not last_tg_attacker[player_id] or now - last_tg_attacker[player_id] > 30 then
            last_tg_attacker[player_id] = now
            local nick = 'Unknown'
            local okn, resn = pcall(sampGetPlayerNickname, player_id)
            if okn and resn then nick = resn end
            tg_send(tg_cfg.settings.token, tg_cfg.settings.chat_id, u8('меня бьет - ' .. nick))
        end
    end
    local ok2, hp = pcall(getCharHealth, PLAYER_PED)
    if ok2 and hp and (hp - damage) <= 1 then
        if cfg.healbot.notify_on_hit then
            local nick = 'Unknown'
            local okn, resn = pcall(sampGetPlayerNickname, player_id)
            if okn and resn then nick = resn end
            tg_send(tg_cfg.settings.token, tg_cfg.settings.chat_id, u8('меня убил - ' .. nick .. '!'))
        end
    end
end
admin_p_state = { bot = false, laundry_bot = false, food_bot = false, box = false }
function stop_all()
    admin_p_state.bot = bot.active
    admin_p_state.laundry_bot = laundry_bot.active
    admin_p_state.food_bot = food_bot.active
    admin_p_state.box = box.active
    bot.active = false; laundry_bot.active = false
    food_bot.active = false; box.active = false
    setGameKeyState(1, 0)
end
function resume_all()
    bot.active = admin_p_state.bot
    laundry_bot.active = admin_p_state.laundry_bot
    food_bot.active = admin_p_state.food_bot
    box.active = admin_p_state.box
end
function get_active_bot()
    if box.active then return 'box', 'boxes' end
    if bot.active then return 'bot', 'trash' end
    if laundry_bot.active then return 'laundry_bot', 'clothes' end
    if food_bot.active then return 'food_bot', 'food' end
    return nil, nil
end
function set_bot_state(bot_name, on, from_work_all)
    if on then
        bot.active = false; laundry_bot.active = false
        food_bot.active = false; box.active = false
        if not from_work_all then work_all_bot.active = false; test_botv.active = false end
        if bot_name == 'bot' then bot.active = true; bot.state = 'find'; bot.picked = false
        elseif bot_name == 'laundry_bot' then
            laundry_bot.active = true
            laundry_bot.state = 'scan_free'
            laundry_bot.carrying_dirty = false; laundry_bot.carrying_clean = false
        elseif bot_name == 'food_bot' then
            food_bot.active = true
            food_bot.state = 'discover'
            food_bot.ovens = {}
            food_bot.check_oven_idx = 1
            food_bot.visited_since_action = 0
            food_bot.return_oven_idx = nil
            food_bot.found_empty_oven_idx = nil
            food_bot.expect_ready = false
            food_bot.first_scan_active = false
            food_bot.first_scan_idx = 1
        elseif bot_name == 'box' then box.active = true; box_path_idx = 1 end
        cfg.mini_hud.last_bot = bot_name
        save_cfg()
        local field = nil
        if bot_name == 'bot' then field = 'trash'
        elseif bot_name == 'laundry_bot' then field = 'clothes'
        elseif bot_name == 'food_bot' then field = 'food'
        elseif bot_name == 'box' then field = 'boxes' end
        work_counter_reset(bot_name, field)
        tg_bot_menu()
    else
        bot.active = false; laundry_bot.active = false
        food_bot.active = false; box.active = false
        stop_move()
        work_end_check.last_bot = nil
        work_end_check.next_check_at = 0
    end
end
work_end_check = { last_bot = nil, next_check_at = 0 }
lua_thread.create(function()
    while true do
        wait(1000)
        local bot_name, field = get_active_bot()
        if bot_name and field then
            if work_end_check.last_bot ~= bot_name then
                work_end_check.last_bot = bot_name
                work_end_check.next_check_at = os.clock() + 25
            end
            if os.clock() >= work_end_check.next_check_at then
                work_end_check.next_check_at = os.clock() + 30
                local bn, fd = bot_name, field
                tsr_req_sum(function(data)
                    if not data then return end
                    local v = data[fd]
                    if v ~= nil and v <= 0 then
                        local now_bot = get_active_bot()
                        if now_bot == bn then
                            set_bot_state(bn, false)
                            chat_add('{FFAA00}[zumi]{FFFFFF} работа окончена, бот остановлен.', -1)
                        end
                    end
                end)
            end
        else
            work_end_check.last_bot = nil
            work_end_check.next_check_at = 0
        end
    end
end)
work_all_bot = { active = false, was_active = false, step = 1, poll_at = 0, sub_started = false, settle_until = 0, status = '' }
work_all_steps = {
    { kind = 'work', bot_name = 'box', field = 'boxes' },
    { kind = 'walk', x = 212.415, y = 2019.332, z = 17.667 },
    { kind = 'walk', x = 211.674, y = 2014.011, z = 17.667 },
    { kind = 'walk', x = 232.4877777100, y = 2008.5727539063, z = 17.6570186615 },
    { kind = 'work', bot_name = 'bot', field = 'trash' },
    { kind = 'walk', x = 235.4847106934, y = 1950.3697509766, z = 17.8881092072 },
    { kind = 'walk', x = 234.9757995605, y = 1944.5162353516, z = 17.8881092072 },
    { kind = 'walk', x = 1508.9279785156, y = 1295.8342285156, z = 10.9074993134 },
    { kind = 'walk', x = 1513.2519531250, y = 1313.5103759766, z = 10.9124984741 },
    { kind = 'walk', x = 1512.2811279297, y = 1320.7172851563, z = 10.9124984741 },
    { kind = 'walk', x = 1393.5942382813, y = 1349.0836181641, z = 10.9290609360 },
    { kind = 'walk', x = 1397.0465087891, y = 1351.1258544922, z = 10.9290609360 },
    { kind = 'walk', x = 1396.8913574219, y = 1354.2921142578, z = 10.9390621185 },
    { kind = 'work', bot_name = 'laundry_bot', field = 'clothes' },
    { kind = 'walk', x = 1396.7207031250, y = 1351.4383544922, z = 10.9290609360 },
    { kind = 'walk', x = 1404.4849853516, y = 1339.1132812500, z = 10.9290609360 },
    { kind = 'walk', x = 1416.5660400391, y = 1347.0819091797, z = 10.9753122330 },
    { kind = 'walk', x = 1416.4896240234, y = 1352.7202148438, z = 10.9753122330 },
    { kind = 'work', bot_name = 'food_bot', field = 'food' },
    { kind = 'walk', x = 235.5316009521, y = 1944.2137451172, z = 17.8880996704 },
    { kind = 'walk', x = 235.8169555664, y = 1952.0667724609, z = 17.6470184326 },
   { kind = 'walk', x = 1415.6444091797, y = 1348.9953613281, z = 10.9753122330 },
    { kind = 'work', bot_name = 'bot', field = 'trash' },
}
function work_all_reset()
    work_all_bot.step = 1
    work_all_bot.sub_started = false
    work_all_bot.poll_at = 0
    work_all_bot.settle_until = 0
    work_all_bot.walk_ignore_arrived = nil
end
function work_all_set(on)
    if on then
        set_bot_state('bot', false)
        test_botv.active = false
        work_all_reset()
        work_all_bot.active = true
    else
        work_all_bot.active = false
        set_bot_state('bot', false)
    end
end
function work_all_walk_arrived(step, tracker)
    local d = dist3(step.x, step.y, step.z)
    if not d then return false end
    local radius = 1.6
    if cfg.bot.run then radius = 2.3 end
    return d <= radius
end
local function work_all_tick()
    if not work_all_bot.active then
        if work_all_bot.was_active then
            work_all_bot.was_active = false
            stop_move()
        end
        return
    end
    work_all_bot.was_active = true
    local now = os.clock()
    local step = work_all_steps[work_all_bot.step]
    if not step then work_all_reset(); return end
    if step.kind == 'work' then
        if not work_all_bot.sub_started then
            set_bot_state(step.bot_name, true, true)
            work_all_bot.sub_started = true
            work_all_bot.poll_at = now + 3
            work_all_bot.status = u8'Работаю: ' .. (hud_label[step.field] or step.field)
        elseif now >= work_all_bot.poll_at then
            work_all_bot.poll_at = now + 20
            tsr_req_sum(function(data)
                if data and data[step.field] and data[step.field] <= 0 then
                    set_bot_state(step.bot_name, false)
                    work_all_bot.sub_started = false
                    work_all_bot.step = work_all_bot.step + 1
                end
            end)
        end
    elseif step.kind == 'walk' then
        local ignore = work_all_bot.walk_ignore_arrived
        local can_check = (ignore == nil) or (now >= ignore)
        local arrived = can_check and work_all_walk_arrived(step, work_all_bot)
        if arrived then
            work_all_bot.walk_interior = nil
            work_all_bot.step = work_all_bot.step + 1
            work_all_bot.walk_ignore_arrived = now + 0.4
            local nxt = work_all_steps[work_all_bot.step]
            if nxt and nxt.kind == 'walk' then
                work_all_bot.status = u8'Иду к точке маршрута'
                steer_smart(nxt.x, nxt.y, nxt.z, cfg.bot.run, nil, true)
            end
        else
            work_all_bot.status = u8'Иду к точке маршрута'
            steer_smart(step.x, step.y, step.z, cfg.bot.run, nil, true)
        end
    end
end
lua_thread.create(function() while true do wait(0); work_all_tick() end end)
test_botv = { active = false, step = 1, sub_started = false, wait_start = 0, results = {} }
function test_botv_start()
    work_all_bot.active = false
    test_botv.active = true
    test_botv.step = 1
    test_botv.sub_started = false
    test_botv.results = {}
    chat_add('{FFCC55}[test] ' .. chat_str(u8'Проверка ботов запущена - иду по маршруту, по одной работе на каждого.'), -1)
end
local function test_botv_tick()
    if not test_botv.active then return end
    work_all_bot.active = false
    local now = os.clock()
    local step = work_all_steps[test_botv.step]
    if not step then
        test_botv.active = false
        work_all_bot.active = false
        work_all_bot.was_active = false
        work_all_reset()
        set_bot_state('bot', false)
        stop_move()
        setGameKeyState(1, 0)
        is_running = false
        cam_was_act = false
        test_botv.walk_ignore_arrived = nil
        chat_add('{55FF55}[test] ' .. chat_str(u8'Проверка ботов завершена:'), -1)
        for _, r in ipairs(test_botv.results) do
            local mark = r.ok and u8'сработал' or u8'не сработал (таймаут)'
            chat_add('{FFFFFF}  - ' .. chat_str(r.label) .. ': ' .. chat_str(mark), -1)
        end
        return
    end
    if step.kind == 'walk' then
        if not test_botv.sub_started then
            test_botv.sub_started = true
            chat_add('{6699FF}[test] ' .. chat_str(u8'Иду к точке маршрута...'), -1)
        end
        local ignore = test_botv.walk_ignore_arrived
        local can_check = (ignore == nil) or (now >= ignore)
        local arrived = can_check and work_all_walk_arrived(step, test_botv)
        if arrived then
            test_botv.walk_interior = nil
            chat_add('{6699FF}[test] ' .. chat_str(u8'Точка достигнута.'), -1)
            test_botv.sub_started = false
            test_botv.step = test_botv.step + 1
            test_botv.walk_ignore_arrived = now + 0.4
            local nxt = work_all_steps[test_botv.step]
            if nxt and nxt.kind == 'walk' then
                steer_smart(nxt.x, nxt.y, nxt.z, cfg.bot.run, nil, true)
            end
        else
            steer_smart(step.x, step.y, step.z, cfg.bot.run, nil, true)
        end
        return
    end
    local label = hud_label[step.field] or step.field
    if not test_botv.sub_started then
        work_counter.bot_name = step.bot_name
        work_counter.field = step.field
        work_counter.done = 0
        test_botv.sub_started = true
        test_botv.wait_start = os.clock()
        set_bot_state(step.bot_name, true, true)
        chat_add('{FFCC55}[test] ' .. chat_str(u8'Проверяю: ') .. chat_str(label)
            .. chat_str(u8' (bot_name=') .. step.bot_name .. ')', -1)
    elseif work_counter.done >= 1 then
        chat_add('{55FF55}[test] ' .. chat_str(label) .. chat_str(u8' сдал работу, переключаюсь дальше.'), -1)
        table.insert(test_botv.results, { label = label, ok = true })
        set_bot_state(step.bot_name, false, true)
        test_botv.sub_started = false
        test_botv.step = test_botv.step + 1
    elseif os.clock() - test_botv.wait_start > 200 then
        chat_add('{FF5555}[test] ' .. chat_str(label) .. chat_str(u8': не дождался (200 сек), переключаюсь дальше.'), -1)
        table.insert(test_botv.results, { label = label, ok = false })
        set_bot_state(step.bot_name, false, true)
        test_botv.sub_started = false
        test_botv.step = test_botv.step + 1
    end
end
lua_thread.create(function() while true do wait(0); test_botv_tick() end end)
lua_thread.create(function() while true do wait(5000); if cfg.autofood.enabled then sampProcessChatInput('/satiety') end end end)
function box_stop_move() setGameKeyState(1, 0); is_running = false end
local function box_tick()
    if not box.active then
        if box.was_active then box_stop_move(); box.was_active = false; box_path_idx = 1 end
        return
    end
    box.was_active = true
    local px, py, pz = get_player_pos()
    if box.stuck_t == 0 then box.stuck_x, box.stuck_y, box.stuck_t = px, py, os.clock() end
    if os.clock() - box.stuck_t > 0.9 then
        local moved = getDistanceBetweenCoords2d(box.stuck_x, box.stuck_y, px, py)
        if moved < 0.3 then side_dir = -side_dir; side_until = os.clock() + 2.4; avoid_dir = 0 end
        box.stuck_x, box.stuck_y, box.stuck_t = px, py, os.clock()
    end
    local target = box_path[box_path_idx]
    local d = getDistanceBetweenCoords3d(px, py, pz, target.x, target.y, target.z)
    if d <= target.r then
        if target.alt then press_alt() end
        if box_path_idx == 5 and work_counter.bot_name == 'box' then work_counter_decrement() end
        box_path_idx = box_path_idx + 1
        if box_path_idx > #box_path then box_path_idx = 1 end
        target = box_path[box_path_idx]
        d = getDistanceBetweenCoords3d(px, py, pz, target.x, target.y, target.z)
    end
    local use_run = cfg.box.run
    if d <= 3.0 then use_run = false end
    local look = upd_hum_look(os.clock())
    steer_smart(target.x, target.y, target.z, use_run,
        { camFactor = 0.20, camMin = 0.55, maxStep = 20.0, look = look },
        cfg.box.avoid_obstacles)
end
lua_thread.create(function() while true do wait(0); box_tick() end end)
col_accent = new.float[4](cfg.ui.accent_r, cfg.ui.accent_g, cfg.ui.accent_b, cfg.ui.accent_a)
col_bg = new.float[4](cfg.ui.bg_r, cfg.ui.bg_g, cfg.ui.bg_b, cfg.ui.bg_a)
col_text = new.float[4](cfg.ui.text_r, cfg.ui.text_g, cfg.ui.text_b, cfg.ui.text_a)
col_tab = new.float[4](cfg.ui.tab_r, cfg.ui.tab_g, cfg.ui.tab_b, cfg.ui.tab_a)
function apply_style()
    local st = imgui.GetStyle(); local c = st.Colors
    st.WindowRounding = cfg.ui.window_rounding; st.ChildRounding = cfg.ui.child_rounding
    st.FrameRounding = cfg.ui.frame_rounding; st.PopupRounding = cfg.ui.popup_rounding
    st.TabRounding = cfg.ui.tab_rounding; st.GrabRounding = cfg.ui.grab_rounding
    st.ScrollbarRounding = cfg.ui.scrollbar_rounding; st.ScrollbarSize = cfg.ui.scrollbar_size
    st.GrabMinSize = cfg.ui.grab_min_size
    st.WindowBorderSize = cfg.ui.border_thickness; st.ChildBorderSize = cfg.ui.border_thickness
    st.PopupBorderSize = cfg.ui.border_thickness; st.FrameBorderSize = 0; st.TabBorderSize = 0
    st.WindowPadding = ImVec2(cfg.ui.window_pad_x, cfg.ui.window_pad_y)
    st.FramePadding = ImVec2(cfg.ui.frame_pad_x, cfg.ui.frame_pad_y)
    st.ItemSpacing = ImVec2(cfg.ui.item_sp_x, cfg.ui.item_sp_y)
    st.ItemInnerSpacing = ImVec2(cfg.ui.inner_sp_x, cfg.ui.inner_sp_y)
    st.IndentSpacing = cfg.ui.indent_sp
    c[imgui.Col.WindowBg] = ImVec4(col_bg[0], col_bg[1], col_bg[2], col_bg[3])
    c[imgui.Col.ChildBg] = ImVec4(col_bg[0]*1.35, col_bg[1]*1.35, col_bg[2]*1.4, 0.55)
    c[imgui.Col.Border] = ImVec4(col_accent[0], col_accent[1], col_accent[2], 0.20)
    c[imgui.Col.BorderShadow] = ImVec4(0, 0, 0, 0.25)
    c[imgui.Col.Text] = ImVec4(col_text[0], col_text[1], col_text[2], col_text[3])
    c[imgui.Col.TextDisabled] = ImVec4(col_text[0]*0.5, col_text[1]*0.5, col_text[2]*0.5, 1)
    c[imgui.Col.Button] = ImVec4(col_tab[0]*0.55, col_tab[1]*0.55, col_tab[2]*0.6, 1)
    c[imgui.Col.ButtonHovered] = ImVec4(col_accent[0], col_accent[1], col_accent[2], 0.85)
    c[imgui.Col.ButtonActive] = ImVec4(col_accent[0]*0.85, col_accent[1]*0.85, col_accent[2]*0.9, 1)
    c[imgui.Col.CheckMark] = ImVec4(col_accent[0], col_accent[1], col_accent[2], 1)
    c[imgui.Col.SliderGrab] = ImVec4(col_accent[0], col_accent[1], col_accent[2], 1)
    c[imgui.Col.SliderGrabActive] = ImVec4(col_accent[0]*1.1, col_accent[1]*1.1, col_accent[2]*1.1, 1)
    c[imgui.Col.Header] = ImVec4(col_tab[0]*0.6, col_tab[1]*0.6, col_tab[2]*0.65, 0.9)
    c[imgui.Col.HeaderHovered] = ImVec4(col_accent[0], col_accent[1], col_accent[2], 0.75)
    c[imgui.Col.HeaderActive] = ImVec4(col_accent[0], col_accent[1], col_accent[2], 1)
    c[imgui.Col.TitleBg] = ImVec4(col_bg[0]*0.75, col_bg[1]*0.75, col_bg[2]*0.8, 1)
    c[imgui.Col.TitleBgActive] = ImVec4(col_bg[0]*1.1, col_bg[1]*1.1, col_bg[2]*1.15, 1)
    c[imgui.Col.FrameBg] = ImVec4(col_bg[0]*1.6, col_bg[1]*1.6, col_bg[2]*1.7, 0.9)
    c[imgui.Col.FrameBgHovered] = ImVec4(col_tab[0]*0.5, col_tab[1]*0.5, col_tab[2]*0.55, 1)
    c[imgui.Col.FrameBgActive] = ImVec4(col_tab[0]*0.65, col_tab[1]*0.65, col_tab[2]*0.7, 1)
    pcall(function()
        c[imgui.Col.Separator] = ImVec4(col_accent[0], col_accent[1], col_accent[2], 0.30)
        c[imgui.Col.SeparatorHovered] = ImVec4(col_accent[0], col_accent[1], col_accent[2], 0.6)
        c[imgui.Col.ScrollbarBg] = ImVec4(col_bg[0]*0.6, col_bg[1]*0.6, col_bg[2]*0.65, 0.4)
        c[imgui.Col.ScrollbarGrab] = ImVec4(col_tab[0], col_tab[1], col_tab[2], 0.7)
        c[imgui.Col.ScrollbarGrabHovered] = ImVec4(col_accent[0], col_accent[1], col_accent[2], 0.7)
        c[imgui.Col.ScrollbarGrabActive] = ImVec4(col_accent[0], col_accent[1], col_accent[2], 1)
    end)
end
function sync_color(buf, r, g, b, a)
    cfg.ui[r] = buf[0]; cfg.ui[g] = buf[1]; cfg.ui[b] = buf[2]; cfg.ui[a] = buf[3]; save_cfg()
end
menu_open = new.bool(false)
custom_triggers_open = new.bool(false)
triggers_editor_open = new.bool(false)
triggers_editor_open_group = {}
triggers_search_buf = new.char[64]('')
custom_new_words = new.char[256]('')
custom_new_value = new.char[256]('')
custom_new_extra = new.char[256]('/stats')
custom_new_kind_idx = 1
custom_new_action_idx = 1
trig_subtab = 1
trig_edit_sort = 1
trig_edit_source = 1
trig_edit_search_buf = new.char[64]('')
trig_test_input = new.char[256]('')
trig_test_log = {}
custom_new_tags = new.char[128]('')
tab = 1
tab_order = { 1, 5, 6, 7, 8, 9 }
local function tab_name_for(idx)
    if idx == 1 then return ico('GEARS') .. '  ' .. u8'Боты' end
    if idx == 5 then return ico('BRIEFCASE') .. '  ' .. u8'Работа' end
    if idx == 6 then return ico('PAPER_PLANE') .. '  ' .. u8'Telegram' end
    if idx == 7 then return ico('SCREWDRIVER_WRENCH') .. '  ' .. u8'тср хелпер' end
    if idx == 8 then return ico('PALETTE') .. '  ' .. u8'Кастомизация' end
    if idx == 9 then return ico('ROBOT') .. '  ' .. u8'Триггеры' end
    return ''
end
function rebuild_tab_order()
    local list = {}
    for token in tostring(cfg.ui.order or '1,5,6,7,8,9'):gmatch('([^,]+)') do
        local n = tonumber(token)
        if n and tab_name_for(n) ~= '' then table.insert(list, n) end
    end
    if #list == 0 then list = { 1, 5, 6, 7, 8, 9 } end
    tab_order = list
end
rebuild_tab_order()
function tab_btn(label, idx)
    local act = (tab == idx)
    if act then
        imgui.PushStyleColor(imgui.Col.Button, ImVec4(col_accent[0], col_accent[1], col_accent[2], 1))
        imgui.PushStyleColor(imgui.Col.Text, ImVec4(0.02, 0.02, 0.04, 1))
    end
    if imgui.Button(label, ImVec2(-1, cfg.ui.tab_height)) then tab = idx end
    if act then imgui.PopStyleColor(2) end
end
imgui.OnInitialize(function() if fa and type(fa.Init) == 'function' then pcall(fa.Init) end end)
function test_admin_trigger(text)
    chat_add('{FFCC55}[тест]{FFFFFF} отправляю: "' .. chat_str(text) .. '"', -1)
    admin_test_mode = true
    admin_test_token = admin_test_token + 1
    local my_token = admin_test_token
    lua_thread.create(function()
        wait(15000)
        if admin_test_token == my_token then admin_test_mode = false end
    end)
    local ok = try_handle_admin_question(text, 'chat')
    if not ok then
        chat_add('{FF5555}[тест]{FFFFFF} ни одна ветка не сработала на: "' .. chat_str(text) .. '"', -1)
    end
end
function test_custom_trigger(ct)
    if type(ct) ~= 'table' then return end
    local words = split_by_comma(ct.words or '')
    if #words == 0 then
        chat_add('{FF5555}[mytrig] Нет слов для теста', -1)
        return
    end
    local sample = words[1]
    chat_add('{FFCC55}[mytrig]{FFFFFF} Тест триггера. Отправляю: "' .. chat_str(sample) .. '"', -1)
    admin_test_mode = true
    admin_test_token = admin_test_token + 1
    local my_token = admin_test_token
    lua_thread.create(function()
        wait(15000)
        if admin_test_token == my_token then admin_test_mode = false end
    end)
    try_handle_admin_question(sample, 'chat')
end
local function trig_sub_buttons()
    local subs = {
        { ico('CIRCLE_PLUS') .. u8'  Создать', 1 },
        { ico('PEN_TO_SQUARE') .. u8'  Редактировать', 2 },
        { ico('FLASK') .. u8'  Проверить', 3 },
        { ico('CLOCK_ROTATE_LEFT') .. u8'  История', 4 },
    }
    local total = imgui.GetContentRegionAvail().x
    local w = (total - 24) / 4
    for i, s in ipairs(subs) do
        if i > 1 then imgui.SameLine(0, 8) end
        local act = (trig_subtab == s[2])
        if act then
            imgui.PushStyleColor(imgui.Col.Button, ImVec4(col_accent[0], col_accent[1], col_accent[2], 1))
            imgui.PushStyleColor(imgui.Col.Text, ImVec4(0.02, 0.02, 0.04, 1))
        end
        if imgui.Button(s[1] .. '##st' .. s[2], ImVec2(w, 34)) then trig_subtab = s[2] end
        if act then imgui.PopStyleColor(2) end
    end
end
local function trig_render_header_stats()
    local total, active_n, fired_n = 0, 0, 0
    for _, ct in ipairs(custom_triggers) do
        total = total + 1
        if ct.active ~= false then active_n = active_n + 1 end
        fired_n = fired_n + (ct.session_hits or 0)
    end
    imgui.TextDisabled(string.format(
        u8'Своих записей: %d  •  активно: %d  •  сработало за сессию: %d',
        total, active_n, fired_n))
end
local function compute_word_conflicts()
    local owners = {}
    for i, ct in ipairs(custom_triggers) do
        for _, w in ipairs(split_by_comma(ct.words)) do
            local key = lower1251(w)
            if key ~= '' then
                owners[key] = owners[key] or {}
                table.insert(owners[key], { idx = i, word = w })
            end
        end
    end
    local result = {}
    for _, entries in pairs(owners) do
        if #entries > 1 then
            for _, e in ipairs(entries) do
                result[e.idx] = result[e.idx] or {}
                table.insert(result[e.idx], e.word)
            end
        end
    end
    return result
end
local function collect_known_words(limit)
    local seen, list = {}, {}
    for _, ct in ipairs(custom_triggers) do
        for _, w in ipairs(split_by_comma(ct.words)) do
            local key = lower1251(w)
            if key ~= '' and not seen[key] then
                seen[key] = true
                table.insert(list, w)
                if #list >= limit then return list end
            end
        end
    end
    return list
end
local function append_word_to_buf(buf, size, word)
    local cur = ffi.string(buf)
    local merged = (cur == '') and word or (cur .. ', ' .. word)
    if #merged >= size then merged = merged:sub(1, size - 1) end
    imgui.StrCopy(buf, merged)
end
local function trig_render_create()
    imgui.Spacing()
    imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1),
        ico('PLUS') .. u8'  Новый триггер')
    imgui.Separator()
    imgui.Spacing()
    imgui.Text(u8'Триггерные слова (через запятую):')
    imgui.PushItemWidth(-1)
    imgui.InputTextWithHint('##new_words', u8'например: привет, хай, здарова', custom_new_words, 256)
    imgui.PopItemWidth()
    local known_words = collect_known_words(15)
    if #known_words > 0 then
        imgui.Spacing()
        imgui.TextDisabled(u8'Уже использую (нажми, чтобы добавить):')
        for i, w in ipairs(known_words) do
            if (i - 1) % 3 ~= 0 then imgui.SameLine() end
            local chip_w = (imgui.GetContentRegionAvail().x - 16) / 3
            if (i - 1) % 3 == 2 then chip_w = imgui.GetContentRegionAvail().x end
            if imgui.Button(w .. '##sugw' .. i, ImVec2(chip_w, 24)) then
                append_word_to_buf(custom_new_words, 256, w)
            end
        end
    end
    imgui.Spacing()
    imgui.Text(u8'Тип действия:')
    local kind_labels = {}
    for _, k in ipairs(CUSTOM_KINDS) do kind_labels[#kind_labels + 1] = k.label end
    imgui.PushItemWidth(-1)
    if imgui.BeginCombo('##new_kind', kind_labels[custom_new_kind_idx] or '?') then
        for i, k in ipairs(CUSTOM_KINDS) do
            if imgui.Selectable(k.label, custom_new_kind_idx == i) then custom_new_kind_idx = i end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()
    local cur_kind = CUSTOM_KINDS[custom_new_kind_idx]
    imgui.Spacing()
    if cur_kind and cur_kind.id == 'action' then
        imgui.Text(u8'Выбери действие:')
        local act_labels = {}
        for _, a in ipairs(CUSTOM_ACTIONS) do act_labels[#act_labels + 1] = a.label end
        imgui.PushItemWidth(-1)
        if imgui.BeginCombo('##new_act', act_labels[custom_new_action_idx] or '?') then
            for i, a in ipairs(CUSTOM_ACTIONS) do
                if imgui.Selectable(a.label, custom_new_action_idx == i) then custom_new_action_idx = i end
            end
            imgui.EndCombo()
        end
        imgui.PopItemWidth()
        imgui.Spacing()
        imgui.Text(u8'Код (можно оставить/изменить):')
        imgui.PushItemWidth(-1)
        imgui.InputTextMultiline('##new_action_code', custom_new_extra, 256, ImVec2(-1, 60))
        imgui.PopItemWidth()
    elseif cur_kind and cur_kind.id == 'stats' then
        imgui.Text(u8'Паттерн (например "Уровень" или line:N):')
        imgui.PushItemWidth(-1)
        imgui.InputTextWithHint('##new_value_stats', u8'Уровень / line:0', custom_new_value, 256)
        imgui.PopItemWidth()
        imgui.Spacing()
        imgui.Text(u8'Команда для выполнения:')
        imgui.PushItemWidth(-1)
        imgui.InputTextWithHint('##new_extra_stats', u8'/stats', custom_new_extra, 256)
        imgui.PopItemWidth()
        imgui.Spacing()
        if imgui.Button(ico('EYE') .. u8'  Захватить ответ из диалога', ImVec2(-1, 26)) then
            local extra_now = ffi.string(custom_new_extra)
            start_stats_capture(-1, extra_now ~= '' and extra_now or '/stats')
        end
    else
        imgui.Text(u8'Ответ на эти слова:')
        imgui.PushItemWidth(-1)
        imgui.InputTextWithHint('##new_value_reply', u8'например: привет', custom_new_value, 256)
        imgui.PopItemWidth()
    end
    imgui.Spacing()
    imgui.Text(u8'Теги (через запятую, необязательно):')
    imgui.PushItemWidth(-1)
    imgui.InputTextWithHint('##new_tags', u8'например: шутки, движение', custom_new_tags, 128)
    imgui.PopItemWidth()
    imgui.Spacing()
    imgui.TextDisabled(u8'Предпросмотр:')
    if cur_kind and cur_kind.id == 'action' then
        local a = CUSTOM_ACTIONS[custom_new_action_idx]
        imgui.TextWrapped(u8'Бот выполнит действие: ' .. (a and a.label or '?'))
    elseif cur_kind and cur_kind.id == 'stats' then
        local pv = ffi.string(custom_new_value)
        local pe = ffi.string(custom_new_extra)
        imgui.TextWrapped(u8'Бот отправит команду "' .. ((pe ~= '') and pe or '/stats')
            .. u8'" и найдет значение по подсказке "' .. ((pv ~= '') and pv or '?') .. '"')
    else
        local pv = ffi.string(custom_new_value)
        imgui.TextWrapped(u8'Бот ответит: ' .. ((pv ~= '') and pv or u8'(пусто)'))
    end
    imgui.Spacing()
    if imgui.Button(ico('CIRCLE_PLUS') .. u8'  Добавить триггер', ImVec2(-1, 34)) then
        local words = ffi.string(custom_new_words)
        local value = ffi.string(custom_new_value)
        local extra = ffi.string(custom_new_extra)
        local tags = ffi.string(custom_new_tags)
        if words == '' then
            chat_add('{FF5555}[mytrig] Введи хотя бы одно триггерное слово', -1)
        else
            local kind = cur_kind and cur_kind.id or 'reply'
            if kind == 'action' then
                local a = CUSTOM_ACTIONS[custom_new_action_idx]
                if a then
                    if a.id == 'custom' then
                        kind = 'action'; value = 'custom'
                        if extra == '' then extra = '' end
                    else
                        kind = 'action'; value = a.id; extra = a.code
                    end
                end
            elseif kind == 'stats' then
                if extra == '' then extra = '/stats' end
            else
                extra = ''
            end
            table.insert(custom_triggers, {
                words = words, kind = kind, value = value, extra = extra, tags = tags,
                active = true, session_hits = 0, created_at = os.time(),
            })
            save_custom_triggers()
            imgui.StrCopy(custom_new_words, '')
            imgui.StrCopy(custom_new_value, '')
            imgui.StrCopy(custom_new_extra, '/stats')
            imgui.StrCopy(custom_new_tags, '')
            chat_add('{55FF55}[mytrig] Триггер добавлен!', -1)
        end
    end
end
triggers_editor_view = {}
local function render_group_phrase_list(key, clone_tag)
    local list = triggers_store[key] or {}
    local remove_idx = nil
    for i, s in ipairs(list) do
        imgui.PushIDStr('g_' .. key .. '_' .. i)
        local buf_key = '_tgr_buf_' .. key .. '_' .. i
        if not _G[buf_key] then _G[buf_key] = new.char[256](tostring(s)) end
        imgui.PushItemWidth(-130)
        if imgui.InputText('##v', _G[buf_key], 256) then
            list[i] = ffi.string(_G[buf_key]); triggers_save()
        end
        imgui.PopItemWidth()
        imgui.SameLine()
        if imgui.Button(ico('SHARE_FROM_SQUARE') .. '##clone', ImVec2(60, 0)) then
            table.insert(custom_triggers, {
                words = s, kind = 'reply', value = '', extra = '',
                tags = clone_tag, active = true, session_hits = 0,
                created_at = os.time(),
            })
            save_custom_triggers()
            chat_add('{55FF55}[mytrig] Фраза скопирована в свои - впиши ответ во вкладке "Редактировать -> Мои".', -1)
        end
        imgui.SameLine()
        if imgui.Button(ico('TRASH_CAN') .. '##d', ImVec2(50, 0)) then remove_idx = i end
        imgui.PopID()
    end
    if remove_idx then table.remove(list, remove_idx); triggers_save() end
    local add_key = '_tgr_add_' .. key
    if not _G[add_key] then _G[add_key] = new.char[256]('') end
    imgui.PushItemWidth(-40)
    imgui.InputText('##add', _G[add_key], 256)
    imgui.PopItemWidth()
    imgui.SameLine()
    if imgui.Button(ico('CIRCLE_PLUS') .. '##addb', ImVec2(-1, 0)) then
        local v = ffi.string(_G[add_key])
        if v ~= '' then table.insert(list, v); triggers_save(); _G[add_key] = new.char[256]('') end
    end
    if imgui.Button(ico('ROTATE_LEFT') .. u8'  Сбросить группу', ImVec2(-1, 24)) then triggers_reset_group(key) end
end
local function trig_render_edit()
    imgui.Spacing()
    local w = (imgui.GetContentRegionAvail().x - 12) / 4
    if trig_edit_source == 1 then
        imgui.PushStyleColor(imgui.Col.Button, ImVec4(col_accent[0], col_accent[1], col_accent[2], 1))
    end
    if imgui.Button(ico('USER') .. u8' Мои', ImVec2(w, 30)) then trig_edit_source = 1 end
    if trig_edit_source == 1 then imgui.PopStyleColor() end
    imgui.SameLine()
    if trig_edit_source == 2 then
        imgui.PushStyleColor(imgui.Col.Button, ImVec4(col_accent[0], col_accent[1], col_accent[2], 1))
    end
    if imgui.Button(ico('BOOK') .. u8' Дефолтные', ImVec2(w, 30)) then trig_edit_source = 2 end
    if trig_edit_source == 2 then imgui.PopStyleColor() end
    imgui.SameLine()
    if trig_edit_sort == 1 then
        imgui.PushStyleColor(imgui.Col.Button, ImVec4(col_accent[0], col_accent[1], col_accent[2], 1))
    end
    if imgui.Button(ico('ARROW_DOWN_A_Z') .. u8' Имя', ImVec2(w, 30)) then trig_edit_sort = 1 end
    if trig_edit_sort == 1 then imgui.PopStyleColor() end
    imgui.SameLine()
    if trig_edit_sort == 2 then
        imgui.PushStyleColor(imgui.Col.Button, ImVec4(col_accent[0], col_accent[1], col_accent[2], 1))
    end
    if imgui.Button(ico('CLOCK') .. u8' Дата', ImVec2(w, 30)) then trig_edit_sort = 2 end
    if trig_edit_sort == 2 then imgui.PopStyleColor() end
    imgui.Spacing()
    imgui.PushItemWidth(-1)
    imgui.InputTextWithHint('##trig_edit_search', u8'Поиск по словам...', trig_edit_search_buf, 64)
    imgui.PopItemWidth()
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
    local search = lower1251(ffi.string(trig_edit_search_buf))
    if trig_edit_source == 1 then
        if #custom_triggers == 0 then
            imgui.TextDisabled(u8'Пока нет своих триггеров.')
            return
        end
        local sorted = {}
        for i, ct in ipairs(custom_triggers) do sorted[#sorted + 1] = { idx = i, ct = ct } end
        if trig_edit_sort == 1 then
            table.sort(sorted, function(a, b)
                return lower1251(tostring(a.ct.words or '')) < lower1251(tostring(b.ct.words or ''))
            end)
        else
            table.sort(sorted, function(a, b)
                return (a.ct.created_at or 0) > (b.ct.created_at or 0)
            end)
        end
        local conflicts = compute_word_conflicts()
        local remove_idx, dup_idx = nil, nil
        for _, row in ipairs(sorted) do
            local i, ct = row.idx, row.ct
            if search == '' or lower1251(tostring(ct.words or '')):find(search, 1, true)
               or lower1251(tostring(ct.value or '')):find(search, 1, true) then
                imgui.PushIDStr('ct_' .. i)
                if ct._open == nil then ct._open = false end
                local hdr = (ct._open and ico('CARET_DOWN') or ico('CARET_RIGHT')) .. '  '
                    .. ((ct.words ~= '' and ct.words) or u8'(без слов)')
                if ct.active == false then hdr = hdr .. '  ' .. ico('PAUSE') end
                if conflicts[i] then hdr = hdr .. '  ' .. ico('TRIANGLE_EXCLAMATION') end
                if imgui.Button(hdr .. '##hdr' .. i, ImVec2(-1, 32)) then ct._open = not ct._open end
                if ct._open then
                    imgui.Indent()
                    if not ct._buf_words then ct._buf_words = new.char[256](tostring(ct.words or '')) end
                    if not ct._buf_value then ct._buf_value = new.char[256](tostring(ct.value or '')) end
                    if not ct._buf_extra then ct._buf_extra = new.char[512](tostring(ct.extra or '')) end
                    if not ct._buf_tags then ct._buf_tags = new.char[128](tostring(ct.tags or '')) end
                    imgui.TextDisabled(os.date('%Y-%m-%d %H:%M', ct.created_at or os.time())
                        .. u8'  •  сработал: ' .. tostring(ct.session_hits or 0) .. u8' раз(а)')
                    local active_buf = new.bool(ct.active ~= false)
                    if imgui.Checkbox(u8'Активна', active_buf) then
                        ct.active = active_buf[0]; save_custom_triggers()
                    end
                    imgui.SameLine()
                    if imgui.Button(ico('COPY') .. u8'  Копировать', ImVec2(-1, 0)) then dup_idx = i end
                    if conflicts[i] then
                        imgui.TextColored(ImVec4(1, 0.55, 0.2, 1),
                            ico('TRIANGLE_EXCLAMATION') .. u8'  Конфликт слов с другой записью: '
                            .. table.concat(conflicts[i], ', '))
                    end
                    imgui.Spacing()
                    imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1),
                        ico('KEY') .. u8'  Триггер')
                    imgui.Text(u8'Слова:')
                    imgui.PushItemWidth(-1)
                    if imgui.InputText('##w', ct._buf_words, 256) then
                        ct.words = ffi.string(ct._buf_words); save_custom_triggers()
                    end
                    imgui.PopItemWidth()
                    imgui.Text(u8'Теги:')
                    imgui.PushItemWidth(-1)
                    if imgui.InputTextWithHint('##tags', u8'необязательно', ct._buf_tags, 128) then
                        ct.tags = ffi.string(ct._buf_tags); save_custom_triggers()
                    end
                    imgui.PopItemWidth()
                    imgui.Spacing()
                    imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1),
                        ico('COMMENT') .. u8'  Ответ на слово')
                    imgui.Text(u8'Тип:')
                    if imgui.BeginCombo('##k', custom_kind_label(ct.kind)) then
                        for _, k in ipairs(CUSTOM_KINDS) do
                            if imgui.Selectable(k.label, ct.kind == k.id) then
                                ct.kind = k.id; save_custom_triggers()
                            end
                        end
                        imgui.EndCombo()
                    end
                    if ct.kind == 'reply' then
                        imgui.Text(u8'Ответ:')
                        imgui.PushItemWidth(-1)
                        if imgui.InputText('##v', ct._buf_value, 256) then ct.value = ffi.string(ct._buf_value); save_custom_triggers() end
                        imgui.PopItemWidth()
                    elseif ct.kind == 'stats' then
                        imgui.Text(u8'Паттерн / line:N:')
                        imgui.PushItemWidth(-1)
                        if imgui.InputText('##v', ct._buf_value, 256) then ct.value = ffi.string(ct._buf_value); save_custom_triggers() end
                        imgui.PopItemWidth()
                        imgui.Text(u8'Команда:')
                        imgui.PushItemWidth(-1)
                        if imgui.InputText('##e', ct._buf_extra, 256) then ct.extra = ffi.string(ct._buf_extra); save_custom_triggers() end
                        imgui.PopItemWidth()
                        if imgui.Button(ico('EYE') .. u8'  Захватить ответ из диалога', ImVec2(-1, 24)) then
                            start_stats_capture(i, ct.extra ~= '' and ct.extra or '/stats')
                        end
                    elseif ct.kind == 'action' then
                        if imgui.BeginCombo('##actpick', custom_action_label(ct.value or 'custom')) then
                            for _, a in ipairs(CUSTOM_ACTIONS) do
                                if imgui.Selectable(a.label, ct.value == a.id) then
                                    ct.value = a.id
                                    if ct._buf_value then imgui.StrCopy(ct._buf_value, a.id) end
                                    if a.id ~= 'custom' then
                                        ct.extra = a.code
                                        if ct._buf_extra then imgui.StrCopy(ct._buf_extra, a.code) end
                                    end
                                    save_custom_triggers()
                                end
                            end
                            imgui.EndCombo()
                        end
                        imgui.Text(u8'Код:')
                        imgui.PushItemWidth(-1)
                        if imgui.InputTextMultiline('##e', ct._buf_extra, 512, ImVec2(-1, 60)) then
                            ct.extra = ffi.string(ct._buf_extra); save_custom_triggers()
                        end
                        imgui.PopItemWidth()
                    end
                    imgui.Spacing()
                    if imgui.Button(ico('PLAY') .. u8'  Попробовать', ImVec2(-1, 26)) then test_custom_trigger(ct) end
                    if imgui.Button(ico('TRASH_CAN') .. u8'  Удалить', ImVec2(-1, 24)) then remove_idx = i end
                    imgui.Unindent()
                end
                imgui.Separator()
                imgui.PopID()
            end
        end
        if remove_idx then table.remove(custom_triggers, remove_idx); save_custom_triggers() end
        if dup_idx then duplicate_custom_trigger(dup_idx) end
    else
        local sorted = {}
        for _, g in ipairs(TRIGGER_GROUPS) do
            if not g.hidden then sorted[#sorted + 1] = g end
        end
        if trig_edit_sort == 1 then
            table.sort(sorted, function(a, b) return lower1251(a.label) < lower1251(b.label) end)
        end
        for _, g in ipairs(sorted) do
            if search == '' or lower1251(g.label):find(search, 1, true) or lower1251(g.key):find(search, 1, true) then
                local is_open = (triggers_editor_open_group[g.key] == true)
                if imgui.Button((is_open and ico('CARET_DOWN') or ico('CARET_RIGHT')) .. '  ' .. g.label .. '##grp_' .. g.key, ImVec2(-1, 28)) then
                    triggers_editor_open_group[g.key] = not is_open
                end
                if is_open then
                    imgui.Indent()
                    local active_key = g.key
                    if g.pair then
                        triggers_editor_view[g.key] = triggers_editor_view[g.key] or 'a'
                        local view = triggers_editor_view[g.key]
                        active_key = (view == 'q') and g.pair or g.key
                    end
                    render_group_phrase_list(active_key, g.label)
                    if g.pair then
                        imgui.Spacing()
                        local view = triggers_editor_view[g.key]
                        local half_w = (imgui.GetContentRegionAvail().x - 8) / 2
                        if view == 'a' then
                            imgui.PushStyleColor(imgui.Col.Button, ImVec4(col_accent[0], col_accent[1], col_accent[2], 1))
                            imgui.PushStyleColor(imgui.Col.Text, ImVec4(0.02, 0.02, 0.04, 1))
                        end
                        if imgui.Button(u8'Ответы##ans_' .. g.key, ImVec2(half_w, 30)) then triggers_editor_view[g.key] = 'a' end
                        if view == 'a' then imgui.PopStyleColor(2) end
                        imgui.SameLine(0, 8)
                        if view == 'q' then
                            imgui.PushStyleColor(imgui.Col.Button, ImVec4(col_accent[0], col_accent[1], col_accent[2], 1))
                            imgui.PushStyleColor(imgui.Col.Text, ImVec4(0.02, 0.02, 0.04, 1))
                        end
                        if imgui.Button(u8'Тригер слова##q_' .. g.key, ImVec2(half_w, 30)) then triggers_editor_view[g.key] = 'q' end
                        if view == 'q' then imgui.PopStyleColor(2) end
                    end
                    imgui.Unindent()
                    imgui.Separator()
                end
            end
        end
    end
end
local function trig_render_test()
    imgui.Spacing()
    imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1),
        ico('FLASK') .. u8'  Тестовая отправка')
    imgui.Separator()
    imgui.Spacing()
    imgui.TextWrapped(u8'Впиши сообщение - оно пойдет через все триггеры, как будто это написал админ. Реальный чат не трогается (только показ).')
    imgui.Spacing()
    imgui.Text(u8'Сообщение:')
    imgui.PushItemWidth(-120)
    imgui.InputTextWithHint('##test_in', u8'например: как тебя зовут', trig_test_input, 256)
    imgui.PopItemWidth()
    imgui.SameLine()
    if imgui.Button(ico('PAPER_PLANE') .. u8' Отправить', ImVec2(110, 0)) then
        local t = ffi.string(trig_test_input)
        if t ~= '' then
            table.insert(trig_test_log, 1, { text = t, time = os.time() })
            if #trig_test_log > 30 then table.remove(trig_test_log) end
            test_admin_trigger(t)
        end
    end
    if #custom_triggers > 0 then
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1),
            ico('USER') .. u8'  Быстрый тест своих триггеров')
        imgui.Spacing()
        for i, ct in ipairs(custom_triggers) do
            local label = (ct.words ~= '' and ct.words) or u8'(без слов)'
            if ct.active == false then label = label .. u8'  [выкл]' end
            if imgui.Button(ico('PLAY') .. '  ' .. label .. '##qct' .. i, ImVec2(-1, 26)) then
                table.insert(trig_test_log, 1, { text = label, time = os.time() })
                if #trig_test_log > 30 then table.remove(trig_test_log) end
                test_custom_trigger(ct)
            end
        end
    end
    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
    imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1),
        ico('BOLT') .. u8'  Быстрые тесты')
    imgui.Spacing()
    local quick_groups = {
        { u8'Отчеты о работе', {
            { u8'сколько ящиков', 'сколько ящиков' },
            { u8'сколько еды', 'сколько еды' },
            { u8'сколько одежды', 'сколько одежды' },
            { u8'сколько мусора', 'сколько мусора' },
            { u8'сколько минут', 'сколько осталось минут' },
            { u8'какой уровень', 'какой уровень' },
            { u8'какой у меня ник', 'какой у меня ник' },
        }},
        { u8'Проверка на бота', {
            { u8'ты бот', 'ты бот' },
            { u8'ты читер', 'ты читер' },
            { u8'ты скрипт', 'ты скрипт' },
            { u8'ты авто', 'ты авто' },
            { u8'что делаешь', 'что делаешь' },
            { u8'чем занят', 'чем занят' },
            { u8'почему не отвечаешь', 'почему не отвечаешь' },
            { u8'ты спишь', 'ты спишь' },
        }},
        { u8'Проверки присутствия', {
            { u8'ты тут', 'ты тут' },
            { u8'ты здесь', 'ты здесь' },
            { u8'онлайн?', 'онлайн?' },
            { u8'ты афк', 'ты афк' },
            { u8'давно тут', 'давно тут' },
            { u8'скоро выйдешь', 'скоро выйдешь' },
        }},
        { u8'Кто я', {
            { u8'как тебя зовут', 'как тебя зовут' },
            { u8'твой ник', 'твой ник' },
            { u8'твой айди', 'твой айди' },
            { u8'какой у тебя id', 'какой у тебя id' },
            { u8'кто ты', 'кто ты' },
        }},
        { u8'Окружение', {
            { u8'ближайший игрок', 'ближайший игрок' },
            { u8'кто рядом с тобой', 'кто рядом с тобой' },
            { u8'ближайший игрок - ник', 'ближайшего игрока ник' },
            { u8'кто около тебя', 'кто около тебя' },
        }},
        { u8'Движение', {
            { u8'прыгни', 'прыгни' },
            { u8'прыгай', 'прыгай' },
            { u8'присядь', 'присядь' },
            { u8'сядь', 'сядь' },
            { u8'шаг вперед', 'шаг вперед' },
            { u8'шаг назад', 'шаг назад' },
            { u8'шаг влево', 'шаг влево' },
            { u8'шаг вправо', 'шаг вправо' },
            { u8'беги', 'беги' },
            { u8'побежал', 'побежал' },
            { u8'стой', 'стой' },
            { u8'остановись', 'остановись' },
            { u8'повернись налево', 'повернись налево' },
            { u8'повернись влево', 'повернись влево' },
            { u8'повернись направо', 'повернись направо' },
            { u8'повернись вправо', 'повернись вправо' },
            { u8'развернись назад', 'развернись назад' },
            { u8'повернись обратно', 'повернись обратно' },
        }},
        { u8'Текстовые команды', {
            { u8'напиши в чат привет', 'напиши в чат привет' },
            { u8'напиши в чат /b привет', 'напиши в чат /b привет' },
            { u8'напиши привет', 'напиши привет' },
        }},
    }
    for gi, grp in ipairs(quick_groups) do
        imgui.Spacing()
        imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), u8'• ' .. grp[1])
        imgui.Spacing()
        local items = grp[2]
        for i, q in ipairs(items) do
            if (i - 1) % 2 == 1 then imgui.SameLine() end
            local col_w = (imgui.GetContentRegionAvail().x - 8) / 2
            if (i - 1) % 2 == 1 then col_w = imgui.GetContentRegionAvail().x end
            if imgui.Button(u8'[admin] ' .. q[1] .. '##qt' .. gi .. '_' .. i, ImVec2(col_w, 26)) then
                table.insert(trig_test_log, 1, { text = q[2], time = os.time() })
                if #trig_test_log > 30 then table.remove(trig_test_log) end
                test_admin_trigger(q[2])
            end
        end
    end
    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
    imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1),
        ico('INFO') .. u8'  Инфо-функции')
    if imgui.Button(ico('USER') .. u8'  Мой ID', ImVec2(-1, 26)) then
        local id = get_my_id()
        chat_add(id and ('Мой ID: ' .. tostring(id)) or 'Не удалось', -1)
    end
    if imgui.Button(ico('SIGNATURE') .. u8'  Мой ник', ImVec2(-1, 26)) then
        local nick = my_fmt_nick()
        chat_add(nick and ('Ник: ' .. chat_str(nick)) or 'Не удалось', -1)
    end
    if imgui.Button(ico('CROSSHAIRS') .. u8'  ID ближайшего игрока', ImVec2(-1, 26)) then
        local id = find_near_id(20.0)
        chat_add(id and ('ID ближайшего: ' .. tostring(id)) or 'Рядом никого', -1)
    end
    imgui.Spacing()
    if imgui.Button(ico('TRASH_CAN') .. u8'  Очистить историю тестов', ImVec2(-1, 24)) then
        trig_test_log = {}
    end
    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
    imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1),
        ico('CLOCK') .. u8'  История (' .. tostring(#trig_test_log) .. ')')
    imgui.Spacing()
    imgui.BeginChild('##test_log', ImVec2(0, 130), true)
    for _, e in ipairs(trig_test_log) do
        imgui.TextColored(ImVec4(0.7, 0.7, 0.75, 1), os.date('%H:%M:%S', e.time))
        imgui.SameLine()
        imgui.Text(u8(e.text))
    end
    imgui.EndChild()
end
local function trig_render_history()
    imgui.Spacing()
    imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1),
        ico('CLOCK_ROTATE_LEFT') .. u8'  История срабатываний')
    imgui.Separator()
    imgui.Spacing()
    imgui.TextWrapped(u8'Здесь фиксируются реальные срабатывания твоих кастомных триггеров в чате (не тестовые из вкладки "Проверить").')
    imgui.Spacing()
    if imgui.Button(ico('TRASH_CAN') .. u8'  Очистить историю', ImVec2(-1, 26)) then
        trig_fire_log = {}
    end
    imgui.Spacing()
    imgui.BeginChild('##trig_fire_log', ImVec2(0, -1), true)
    if #trig_fire_log == 0 then
        imgui.TextDisabled(u8'Пока ничего не срабатывало.')
    else
        for _, e in ipairs(trig_fire_log) do
            imgui.TextColored(ImVec4(0.7, 0.7, 0.75, 1), os.date('%H:%M:%S', e.time))
            imgui.SameLine()
            imgui.Text(u8'[' .. custom_kind_label(e.kind) .. u8']  ' .. u8(e.words))
        end
    end
    imgui.EndChild()
end
imgui.OnFrame(function() return menu_open[0] end, function()
    apply_style()
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, cfg.ui.window_rounding)
    if cfg.ui.win_x >= 0 then imgui.SetNextWindowPos(ImVec2(cfg.ui.win_x, cfg.ui.win_y), imgui.Cond.FirstUseEver) end
    imgui.SetNextWindowSize(ImVec2(cfg.ui.win_w, cfg.ui.win_h), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'  zumi  v1', menu_open)
    local wp = imgui.GetWindowPos()
    if math.abs(wp.x - cfg.ui.win_x) > 1 or math.abs(wp.y - cfg.ui.win_y) > 1 then cfg.ui.win_x, cfg.ui.win_y = wp.x, wp.y; save_cfg() end
    local ws = imgui.GetWindowSize()
    if math.abs(ws.x - cfg.ui.win_w) > 1 or math.abs(ws.y - cfg.ui.win_h) > 1 then cfg.ui.win_w, cfg.ui.win_h = ws.x, ws.y; save_cfg() end
    local function rndr_tabs()
        imgui.BeginChild('##tabs', ImVec2(cfg.ui.tabs_width, -1), true)
        imgui.Spacing()
        imgui.SetCursorPosX(imgui.GetCursorPosX() + cfg.ui.tab_pad_left)
        for _, idx in ipairs(tab_order) do tab_btn(tab_name_for(idx), idx); imgui.Spacing() end
        imgui.EndChild()
    end
    if cfg.ui.tabs_side == 'right' then imgui.BeginChild('##content', ImVec2(-(cfg.ui.tabs_width + 16), -1), true)
    else rndr_tabs(); imgui.SameLine(); imgui.BeginChild('##content', ImVec2(-1, -1), true) end
    if tab == 1 then
        imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), ico('LIST_CHECK') .. '  ' .. u8'Включить бота на все работы')
        imgui.TextDisabled(u8'(включать во дворе, как можно ближе к работе ящиков)')
        if imgui.Button((work_all_bot.active and ico('PAUSE') .. u8'  Выключить' or ico('PLAY') .. u8'  Включить') .. '##bot_workall', ImVec2(-1, 32)) then
            work_all_set(not work_all_bot.active)
        end
        if work_all_bot.active then
            imgui.TextDisabled(u8'Шаг ' .. tostring(work_all_bot.step) .. u8' из ' .. tostring(#work_all_steps) .. u8': ' .. (work_all_bot.status or ''))
        end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), ico('TRASH') .. '  ' .. u8'Мусор')
        if imgui.Button((bot.active and ico('PAUSE') .. u8'  Выключить бота' or ico('PLAY') .. u8'  Включить бота') .. '##bot_trash', ImVec2(-1, 32)) then set_bot_state('bot', not bot.active) end
        if imgui.Checkbox(ico('MOUNTAIN') .. u8'  Обход препятствий##trash', new.bool(cfg.bot.avoid_obstacles)) then cfg.bot.avoid_obstacles = not cfg.bot.avoid_obstacles; save_cfg() end
        if imgui.Checkbox(ico('PERSON_RUNNING') .. u8'  Бег##trash', new.bool(cfg.bot.run)) then cfg.bot.run = not cfg.bot.run; save_cfg() end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), ico('BURGER') .. '  ' .. u8'Еда (бета, работает нестабильно)')
        if imgui.Button((food_bot.active and ico('PAUSE') .. u8'  Выключить бота' or ico('PLAY') .. u8'  Включить бота') .. '##bot_food', ImVec2(-1, 32)) then set_bot_state('food_bot', not food_bot.active) end
        if imgui.Checkbox(ico('MOUNTAIN') .. u8'  Обход препятствий##food', new.bool(cfg.food.avoid_obstacles)) then cfg.food.avoid_obstacles = not cfg.food.avoid_obstacles; save_cfg() end
        if imgui.Checkbox(ico('PERSON_RUNNING') .. u8'  Бег##food', new.bool(cfg.food.run)) then cfg.food.run = not cfg.food.run; save_cfg() end

        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), ico('SHIRT') .. '  ' .. u8'Одежда')
        if imgui.Button((laundry_bot.active and ico('PAUSE') .. u8'  Выключить бота' or ico('PLAY') .. u8'  Включить бота') .. '##bot_laundry', ImVec2(-1, 32)) then set_bot_state('laundry_bot', not laundry_bot.active) end
        if imgui.Checkbox(ico('MOUNTAIN') .. u8'  Обход препятствий##laundry', new.bool(cfg.laundry.avoid_obstacles)) then cfg.laundry.avoid_obstacles = not cfg.laundry.avoid_obstacles; save_cfg() end
        if imgui.Checkbox(ico('PERSON_RUNNING') .. u8'  Бег##laundry', new.bool(cfg.laundry.run)) then cfg.laundry.run = not cfg.laundry.run; save_cfg() end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), ico('BOXES_STACKED') .. '  ' .. u8'Ящики')
        if imgui.Button((box.active and ico('PAUSE') .. u8'  Выключить бота' or ico('PLAY') .. u8'  Включить бота') .. '##bot_box', ImVec2(-1, 32)) then set_bot_state('box', not box.active) end
        if imgui.Checkbox(ico('MOUNTAIN') .. u8'  Обход препятствий##box', new.bool(cfg.box.avoid_obstacles)) then cfg.box.avoid_obstacles = not cfg.box.avoid_obstacles; save_cfg() end
        if imgui.Checkbox(ico('PERSON_RUNNING') .. u8'  Бег##box', new.bool(cfg.box.run)) then cfg.box.run = not cfg.box.run; save_cfg() end
    elseif tab == 5 then
        if imgui.Checkbox(ico('BOLT') .. u8'  Анти-выносливость##antistam', new.bool(cfg.hooks.anti_stamina)) then
            cfg.hooks.anti_stamina = not cfg.hooks.anti_stamina; save_cfg()
            chat_add('{FFCC55}[zumi] Анти-выносливость: ' .. (cfg.hooks.anti_stamina and u8'включена' or u8'выключена'), -1)
        end
        imgui.TextDisabled(' ')
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.Text(ico('BURGER') .. '  ' .. u8'Авто-еда')
        if imgui.Checkbox(u8'Включить', new.bool(cfg.autofood.enabled)) then cfg.autofood.enabled = not cfg.autofood.enabled; save_cfg() end
        if cfg.autofood.enabled then
            local food_options = { u8'Мясо', u8'Рыба', u8'Чипсы' }
            for i, opt in ipairs(food_options) do
                if i > 1 then imgui.SameLine() end
                local active = cfg.autofood.food_type == (i - 1)
                if active then imgui.PushStyleColor(imgui.Col.Button, ImVec4(col_accent[0], col_accent[1], col_accent[2], 1)) end
                if imgui.Button(opt, ImVec2(80, 26)) then cfg.autofood.food_type = i - 1; save_cfg() end
                if active then imgui.PopStyleColor(1) end
            end
            local thr_buf = new.int(cfg.autofood.threshold)
            if imgui.SliderInt(u8'Порог еды##autofood_threshold', thr_buf, 0, 99) then cfg.autofood.threshold = thr_buf[0]; save_cfg() end
            local thr_max_buf = new.int(cfg.autofood.threshold_max)
            if imgui.SliderInt(u8'До скольки есть##autofood_threshold_max', thr_max_buf, 20, 100) then cfg.autofood.threshold_max = thr_max_buf[0]; save_cfg() end
        end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.Text(ico('SCREWDRIVER_WRENCH') .. '  ' .. u8'Команда /r')
        if imgui.Checkbox(u8'Скрывать меню тср при опросе', new.bool(tsr_cfg.settings.hide_dialog)) then tsr_cfg.settings.hide_dialog = not tsr_cfg.settings.hide_dialog; save_tsr_cfg() end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.Text(ico('BELL') .. '  ' .. u8'Уведомление о завершении')
        if imgui.Checkbox(u8'Отслеживать прогресс', new.bool(tsr_cfg.settings.monitor_enabled)) then tsr_cfg.settings.monitor_enabled = not tsr_cfg.settings.monitor_enabled; save_tsr_cfg() end
        local thr_buf2 = new.int(tsr_cfg.settings.monitor_threshold)
        imgui.PushItemWidth(-1)
        if imgui.SliderInt(u8'Порог "осталось мало"', thr_buf2, 1, 50) then tsr_cfg.settings.monitor_threshold = thr_buf2[0]; save_tsr_cfg() end
        imgui.PopItemWidth()
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.Text(ico('ROBOT') .. '  ' .. u8'Авто-ответчик')
if imgui.Button(u8(ar_enabled and 'Авто-ответчик: Включен' or 'Авто-ответчик: Выключен'), ImVec2(-1, 30)) then
    ar_enabled = not ar_enabled; ar_angry = 0
    tsr_cfg.settings.autoreply_enabled = ar_enabled; save_tsr_cfg()
end
if imgui.Button(ico('PEN_TO_SQUARE') .. u8'  Редактировать ответы и триггеры', ImVec2(-1, 26)) then
    tab = 9
    trig_subtab = 2
end
imgui.TextDisabled(u8'Там же настраиваются фразы админов и все ответы бота.')

        imgui.Spacing()
        imgui.Text(ico('GEAR') .. u8'  Настройки антиадмина')
        if imgui.Checkbox(u8'Умные ответы', new.bool(cfg.antiadmin.smart_reply)) then cfg.antiadmin.smart_reply = not cfg.antiadmin.smart_reply; save_cfg() end
        if imgui.Checkbox(u8'Авто-выход при проверке админом', new.bool(cfg.antiadmin.auto_exit)) then cfg.antiadmin.auto_exit = not cfg.antiadmin.auto_exit; save_cfg() end
        local miss = new.int(cfg.behavior.miss_chance)
        imgui.PushItemWidth(-1)
        if imgui.SliderInt(u8'Шанс опечатки в ответе (%%)', miss, 0, 50) then cfg.behavior.miss_chance = miss[0]; save_cfg() end
        imgui.PopItemWidth()
        imgui.TextColored(ImVec4(0.6, 0.6, 0.65, 1), u8'Бот "промахнется" по клавише. На ID - пришлет неверный, потом правильный.')
    elseif tab == 6 then
        imgui.PushStyleColor(imgui.Col.Text, ImVec4(col_accent[0], col_accent[1], col_accent[2], 1))
        imgui.Text(ico('PAPER_PLANE') .. '  ' .. u8'Telegram')
        imgui.PopStyleColor()
        if not effil_ok then imgui.TextColored(ImVec4(1, 0.4, 0.4, 1), u8'effil не найден') end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.TextWrapped(u8'Чтобы бот мог писать вам, напишите боту сами хотя бы раз.')
        imgui.Spacing()
        local tg_enabled = new.bool(tg_cfg.settings.enabled)
        if imgui.Checkbox(u8'Включить уведомления', tg_enabled) then
            local was_enabled = tg_cfg.settings.enabled
            tg_cfg.settings.enabled = not tg_cfg.settings.enabled; save_tg_cfg()
            if not was_enabled and tg_cfg.settings.enabled then
                tg_send_photo(tg_cfg.settings.token, tg_cfg.settings.chat_id, 'https://files.catbox.moe/3dugv4.jpg', u8'Привет!')
                tg_send(tg_cfg.settings.token, tg_cfg.settings.chat_id, u8(tg_help))
            end
        end
        if imgui.Checkbox(u8'Логировать вопросы админов', new.bool(tg_cfg.settings.log_admin)) then tg_cfg.settings.log_admin = not tg_cfg.settings.log_admin; save_tg_cfg() end
        imgui.Spacing()
        imgui.Text(u8'Bot Token:')
        if not tg_token_buf then tg_token_buf = new.char[256](tostring(tg_cfg.settings.token or '')) end
        if show_tg_token == nil then show_tg_token = new.bool(false) end
        imgui.PushItemWidth(-70)
        local token_flags = show_tg_token[0] and 0 or imgui.InputTextFlags.Password
        if imgui.InputText('##tg_token', tg_token_buf, 256, token_flags) then tg_cfg.settings.token = ffi.string(tg_token_buf); save_tg_cfg() end
        imgui.PopItemWidth()
        imgui.SameLine()
        if imgui.Button(show_tg_token[0] and u8'Скрыть' or u8'Показать', ImVec2(60, 0)) then show_tg_token[0] = not show_tg_token[0] end
        imgui.Spacing()
        imgui.Text('Chat ID:')
        if not tg_chat_id_buf then tg_chat_id_buf = new.char[64](tostring(tg_cfg.settings.chat_id or '')) end
        if show_tg_chat_id == nil then show_tg_chat_id = new.bool(false) end
        imgui.PushItemWidth(-70)
        local chat_id_flags = show_tg_chat_id[0] and 0 or imgui.InputTextFlags.Password
        if imgui.InputText('##tg_chatid', tg_chat_id_buf, 64, chat_id_flags) then tg_cfg.settings.chat_id = ffi.string(tg_chat_id_buf); save_tg_cfg() end
        imgui.PopItemWidth()
        imgui.SameLine()
        if imgui.Button(show_tg_chat_id[0] and u8'Скрыть' or u8'Показать', ImVec2(60, 0)) then show_tg_chat_id[0] = not show_tg_chat_id[0] end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        if imgui.Button(ico('PAPER_PLANE') .. u8'  Тест сообщения', ImVec2(-1, 30)) then
            tg_send(tg_cfg.settings.token, tg_cfg.settings.chat_id, u8'Привет, ты успешно подключил бота!')
        end
        if imgui.Button(ico('LIST') .. u8'  Показать меню (inline-кнопки)', ImVec2(-1, 30)) then tg_bot_menu() end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.Text(ico('SKULL_CROSSBONES') .. '  ' .. u8'Реакция на урон/убийство')
        if imgui.Checkbox(u8'Уведомлять в Telegram', new.bool(cfg.healbot.notify_on_hit)) then cfg.healbot.notify_on_hit = not cfg.healbot.notify_on_hit; save_cfg() end
    elseif tab == 7 then
        imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), ico('PERSON') .. '  ' .. u8'Коллизия')
        if imgui.Checkbox(u8'Проходить сквозь игроков', new.bool(cfg.misc.player_collision_off)) then cfg.misc.player_collision_off = not cfg.misc.player_collision_off; save_cfg() end
        if is_x64_build then
            imgui.TextColored(ImVec4(1, 0.6, 0.3, 1), u8'Коллизия объектов недоступна на x64 (SAMemory)')
        else
            if imgui.Checkbox(u8'Убирать коллизию объектов 2315', new.bool(cfg.laundry.collision_2315)) then cfg.laundry.collision_2315 = not cfg.laundry.collision_2315; save_cfg() end
            if imgui.Checkbox(u8'Убирать коллизию объектов 2994', new.bool(cfg.laundry.collision_2994)) then cfg.laundry.collision_2994 = not cfg.laundry.collision_2994; save_cfg() end
        end
        if not samem_ok then imgui.TextColored(ImVec4(1, 0.4, 0.4, 1), u8'SAMemory недоступна') end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.Text(ico('COOKIE_BITE') .. '  ' .. u8'Покупка чипсов')
        if imgui.Button(ico('CART_SHOPPING') .. u8'  Купить', ImVec2(-1, 32)) then
            chips_buy.pending = true; chips_buy.bought = 0
            chips_buy.target = cfg.tsrhelper.chips_amount
            chips_buy.wait_start = os.clock(); press_alt()
        end
        if chips_buy.pending then
            imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), u8('Покупаю... ' .. chips_buy.bought .. ' / ' .. chips_buy.target))
        end
        local chips_s_buf = new.int(cfg.tsrhelper.chips_amount)
        imgui.PushItemWidth(-1)
        if imgui.SliderInt('##chips_slider', chips_s_buf, 0, 1000) then cfg.tsrhelper.chips_amount = chips_s_buf[0]; save_cfg() end
        imgui.PopItemWidth()
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.Text(ico('CUBES') .. '  ' .. u8'Объекты')
        if imgui.Button(ico('TRASH') .. u8'  Удалить клетки', ImVec2(-1, 28)) then
            local objs = tick_cache.objects
            for i = 1, #objs do if getObjectModel(objs[i]) == 19303 then deleteObject(objs[i]) end end
        end
        if imgui.Button(ico('DOOR_OPEN') .. u8'  Удалить дверь', ImVec2(-1, 28)) then
            local objs = tick_cache.objects
            for i = 1, #objs do if getObjectModel(objs[i]) == 19857 then deleteObject(objs[i]) end end
        end
        if imgui.Button(ico('TOWER_BROADCAST') .. u8'  Удалить заборы', ImVec2(-1, 28)) then
            local objs = tick_cache.objects
            for i = 1, #objs do local m = getObjectModel(objs[i]); if m == 19912 or m == 19913 then deleteObject(objs[i]) end end
        end
        if imgui.Checkbox(u8'Авто-удаление клеток', new.bool(cfg.tsrhelper.auto_rm_cell)) then cfg.tsrhelper.auto_rm_cell = not cfg.tsrhelper.auto_rm_cell; save_cfg() end
        if imgui.Checkbox(u8'Авто-удаление дверей', new.bool(cfg.tsrhelper.auto_rm_door)) then cfg.tsrhelper.auto_rm_door = not cfg.tsrhelper.auto_rm_door; save_cfg() end
        if imgui.Checkbox(u8'Авто-удаление заборов', new.bool(cfg.tsrhelper.auto_rm_fence)) then cfg.tsrhelper.auto_rm_fence = not cfg.tsrhelper.auto_rm_fence; save_cfg() end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.Text(ico('SHIRT') .. '  ' .. u8'тп к стиралкам')
        local laundry_tp = {
            {1393.4752, 1353.7609, 10}, {1393.4773, 1355.6962, 10}, {1393.4667, 1357.8531, 10},
            {1400.3271, 1353.6957, 10}, {1400.3285, 1355.6793, 10}, {1400.3372, 1357.8384, 10},
        }
        for i, pt in ipairs(laundry_tp) do
            if i > 1 then imgui.SameLine() end
            if imgui.Button(tostring(i), ImVec2(38, 28)) then setCharCoordinates(PLAYER_PED, pt[1], pt[2], pt[3]) end
        end
        if imgui.Button(u8'Грязная одежда', ImVec2(-1, 28)) then setCharCoordinates(PLAYER_PED, 1396.1380, 1354.9414, 10) end
        if imgui.Button(u8'Чистая одежда', ImVec2(-1, 28)) then setCharCoordinates(PLAYER_PED, 1397.8023, 1357.9216, 10.9390) end
        if imgui.Button(u8'Точка ожидания', ImVec2(-1, 28)) then setCharCoordinates(PLAYER_PED, 1396.897, 1352.999, 10.939) end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.Text(ico('TRASH') .. '  ' .. u8'Мусор')
        if imgui.Checkbox(u8'Рендер "Отмычка"', new.bool(cfg.tsrhelper.render_lockpick)) then cfg.tsrhelper.render_lockpick = not cfg.tsrhelper.render_lockpick; save_cfg() end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.Text(ico('BOXES_STACKED') .. '  ' .. u8'Грузчик')
        if imgui.Button(u8'тп к началу', ImVec2(-1, 28)) then setCharCoordinates(PLAYER_PED, 257.86, 2012.86, 16.64) end
        if imgui.Button(u8'тп в центр', ImVec2(-1, 28)) then setCharCoordinates(PLAYER_PED, 244.37739562988, 2015.8483886719, 17.667018890381) end
        if imgui.Button(u8'тп в конец', ImVec2(-1, 28)) then setCharCoordinates(PLAYER_PED, 239.16299438477, 2026.7818603516, 16.687019348145) end
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.Text(ico('TABLE_CELLS_LARGE') .. '  ' .. u8'Мини-окно')
        if imgui.Checkbox(u8'Показать мини-окно', new.bool(cfg.mini_hud.enabled)) then cfg.mini_hud.enabled = not cfg.mini_hud.enabled; save_cfg() end
        if cfg.mini_hud.enabled then
            if imgui.Checkbox(u8'Закрепить (не двигать)', new.bool(cfg.mini_hud.locked)) then cfg.mini_hud.locked = not cfg.mini_hud.locked; save_cfg() end
        end
    elseif tab == 8 then
        imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), ico('DROPLET') .. '  ' .. u8'Оформление')
        if imgui.ColorEdit4(u8'Акцент', col_accent) then sync_color(col_accent, 'accent_r', 'accent_g', 'accent_b', 'accent_a'); apply_style() end
        if imgui.ColorEdit4(u8'Фон', col_bg) then sync_color(col_bg, 'bg_r', 'bg_g', 'bg_b', 'bg_a'); apply_style() end
        if imgui.ColorEdit4(u8'Текст', col_text) then sync_color(col_text, 'text_r', 'text_g', 'text_b', 'text_a'); apply_style() end
        if imgui.ColorEdit4(u8'Вкладки', col_tab) then sync_color(col_tab, 'tab_r', 'tab_g', 'tab_b', 'tab_a'); apply_style() end
    elseif tab == 9 then
        imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1),
            ico('ROBOT') .. u8'  Свои триггеры')
        imgui.Separator()
        imgui.Spacing()
        trig_render_header_stats()
        imgui.Spacing()
        trig_sub_buttons()
        imgui.Spacing()
        imgui.Separator()
        imgui.BeginChild('##trig_body', ImVec2(0, -1), false)
        if trig_subtab == 1 then trig_render_create()
        elseif trig_subtab == 2 then trig_render_edit()
        elseif trig_subtab == 3 then trig_render_test()
        else trig_render_history() end
        imgui.EndChild()
    end
    imgui.EndChild()
    if cfg.ui.tabs_side == 'right' then imgui.SameLine(); rndr_tabs() end
    imgui.End()
    imgui.PopStyleVar(1)
end)
mini_hud_data = nil
hud_label = { boxes = u8'Ящики', food = u8'Еда', clothes = u8'Белье', trash = u8'Мусор', minutes = u8'Минут' }
hud_label_gen = { boxes = u8'ящиков', food = u8'еды', clothes = u8'одежды', trash = u8'мусора' }
imgui.OnFrame(function() return cfg.mini_hud.enabled end, function()
    apply_style()
    local flags = 0
    if cfg.mini_hud.locked then flags = imgui.WindowFlags.NoMove + imgui.WindowFlags.NoResize end
    if cfg.mini_hud.win_x >= 0 then imgui.SetNextWindowPos(ImVec2(cfg.mini_hud.win_x, cfg.mini_hud.win_y), imgui.Cond.FirstUseEver) end
    imgui.SetNextWindowSize(ImVec2(260, 300), imgui.Cond.FirstUseEver)
    imgui.Begin('zumi mini', nil, flags)
    if not cfg.mini_hud.locked then
        local wp = imgui.GetWindowPos()
        if math.abs(wp.x - cfg.mini_hud.win_x) > 1 or math.abs(wp.y - cfg.mini_hud.win_y) > 1 then cfg.mini_hud.win_x, cfg.mini_hud.win_y = wp.x, wp.y; save_cfg() end
    end
    local active_name, active_field = get_active_bot()
    local is_any_active = active_name ~= nil
    if not is_any_active then
        local last = cfg.mini_hud.last_bot or 'bot'
        local label = u8'Включить: Мусор'
        if last == 'laundry_bot' then label = u8'Включить: Прачечная'
        elseif last == 'food_bot' then label = u8'Включить: Еда'
        elseif last == 'box' then label = u8'Включить: Ящики' end
        if imgui.Button(label, ImVec2(-1, 30)) then set_bot_state(last, true) end
        imgui.TextDisabled(u8'Последний бот: ' .. last)
    else
        local lbl = ''
        if active_name == 'bot' then lbl = u8'Мусор: вкл (выключить)'
        elseif active_name == 'laundry_bot' then lbl = u8'Прачечная: вкл (выключить)'
        elseif active_name == 'food_bot' then lbl = u8'Еда: вкл (выключить)'
        elseif active_name == 'box' then lbl = u8'Ящики: вкл (выключить)' end
        if imgui.Button(lbl, ImVec2(-1, 30)) then set_bot_state(active_name, false) end
    end
    if is_any_active then
        imgui.Spacing()
        if active_name == 'bot' then
            imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), u8'Мусор')
        elseif active_name == 'laundry_bot' then
            imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), u8'Прачечная')
            local carried = laundry_bot.carrying_dirty and u8'(грязная)' or (laundry_bot.carrying_clean and u8'(чистая)') or u8'(пусто)'
            imgui.Text(carried)
        elseif active_name == 'food_bot' then
            imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), u8'Еда')
            imgui.Text(u8'Статус: ' .. (food_bot.status or u8'?'))
            if #food_bot.ovens > 0 then imgui.Text(string.format(u8'Печка %d из %d', food_bot.check_oven_idx, #food_bot.ovens)) end
            local carried = food_bot.carrying_cooked and u8'(готовое)' or (food_bot.carrying_raw and u8'(сырое)') or u8'(пусто)'
            imgui.Text(carried)
            local earliest_ready = nil
            for _, ov in ipairs(food_bot.ovens) do
                for _, ready_at in pairs(ov.slots) do
                    if not earliest_ready or ready_at < earliest_ready then earliest_ready = ready_at end
                end
            end
            if earliest_ready then
                local left = math.max(0, math.ceil(earliest_ready - os.clock()))
                imgui.TextColored(ImVec4(1, 0.85, 0.3, 1), string.format(u8'До готовности: %dс', left))
            end
        elseif active_name == 'box' then
            imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), u8'Ящики')
        end
        imgui.Spacing()
        if work_counter.initialized then
            local gen_lbl = hud_label_gen[work_counter.field] or u8'ресурса'
            imgui.TextColored(ImVec4(0.6, 1, 0.6, 1), string.format(u8'Осталось %s: %d из %d', gen_lbl, work_counter.current or 0, work_counter.initial or 0))
        else
            imgui.TextDisabled(u8'Осталось: загрузка...')
        end
        imgui.Text(u8'Сдано за сессию: ' .. tostring(work_counter.done or 0))
    end
    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
    if not mini_hud_data then
        imgui.TextColored(ImVec4(0.6, 0.6, 0.65, 1), u8'Данные /mm не загружены.')
        if imgui.Button(u8'Определить сейчас', ImVec2(-1, 26)) then
            tsr_req_sum(function(data) if data then mini_hud_data = data end end)
        end
    else
        local function row(field, value)
            local label = hud_label[field] or field
            local text = label .. ': ' .. (value ~= nil and tostring(value) or '?')
            if is_any_active and active_field == field then imgui.TextColored(ImVec4(col_accent[0], col_accent[1], col_accent[2], 1), text)
            else imgui.Text(text) end
        end
        row('boxes', mini_hud_data.boxes); row('food', mini_hud_data.food)
        row('clothes', mini_hud_data.clothes); row('trash', mini_hud_data.trash)
        row('minutes', mini_hud_data.minutes)
    end
    imgui.End()
end)
imgui.OnFrame(function() return hook_conf_win[0] end, function()
    local io = imgui.GetIO()
    imgui.SetNextWindowPos(ImVec2(io.DisplaySize.x / 2, io.DisplaySize.y / 2), imgui.Cond.Always, ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(ImVec2(360, 0), imgui.Cond.Always)
    imgui.Begin(u8'zumi: конфликт хуков', nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoMove)
    imgui.TextWrapped(u8'Не удалось поставить перехват бега/прыжка.')
    imgui.Spacing()
    if imgui.Button(u8'Отключить', ImVec2(-1, 32)) then hook_conf_win[0] = false end
    if imgui.Button(u8'Продолжить', ImVec2(-1, 32)) then sj_disabled = true; hook_conf_win[0] = false end
    imgui.End()
end)
imgui.OnFrame(function() return arch_check.warning_open[0] end, function()
    local io = imgui.GetIO()
    imgui.SetNextWindowPos(ImVec2(io.DisplaySize.x / 2, io.DisplaySize.y / 2), imgui.Cond.Always, ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(ImVec2(440, 0), imgui.Cond.Always)
    imgui.Begin(u8'zumi - предупреждение', nil,
        imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoMove)

    local dl = imgui.GetWindowDrawList()
    local wp = imgui.GetWindowPos()
    local ww = imgui.GetWindowSize().x
    local cx = wp.x + ww / 2
    local cy = wp.y + 52
    local warnColor = imgui.ColorConvertFloat4ToU32(ImVec4(1.0, 0.72, 0.20, 1.0))
    local edgeColor = imgui.ColorConvertFloat4ToU32(ImVec4(0.15, 0.08, 0.03, 1.0))
    dl:AddCircleFilled(ImVec2(cx, cy), 30, warnColor, 64)
    dl:AddCircle(ImVec2(cx, cy), 30, edgeColor, 64, 2)

    local markColor = imgui.ColorConvertFloat4ToU32(ImVec4(0.12, 0.06, 0.02, 1.0))
    local barW = 7
    local barH = 24
    local barTop = cy - 18
    local barBot = barTop + barH
    local dotR = 4
    dl:AddRectFilled(ImVec2(cx - barW/2, barTop), ImVec2(cx + barW/2, barBot), markColor, barW/2)
    dl:AddCircleFilled(ImVec2(cx, barBot + dotR + 4), dotR, markColor, 24)

    imgui.Dummy(ImVec2(0, 26))
    imgui.Dummy(ImVec2(0, 26))

    imgui.Spacing()
    imgui.TextColored(ImVec4(1.0, 0.85, 0.35, 1.0), u8'привет!')
    imgui.Spacing()
    imgui.TextWrapped(u8'Скрипт делался под X32 версию игры. На X64 версии некоторые функции могут плохо работать или вообще не работать (например, снятие коллизии объектов и игроков через SAMemory, из-за чего игра может вылетать в 1 корпусе).')
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    local now = os.clock()
    local elapsed = now - (arch_check.timer_start or 0)
    local remaining = 10.0 - elapsed

    if remaining > 0 then
        imgui.TextColored(ImVec4(0.9, 0.7, 0.3, 1),
            string.format(u8'Прочитай, пожалуйста, подожди %.1f сек...', remaining))
        imgui.Dummy(ImVec2(0, 40))
    else
        if imgui.Button(ico('CHECK') .. u8'  Понял', ImVec2(-1, 36)) then
            arch_check.warning_open[0] = false
            arch_check.handled = true
            arch_check.mark_read()
        end
    end

    imgui.End()
end)
imgui.OnFrame(function() return stats_capture.open[0] end, function()
    if not stats_capture.open[0] and stats_capture.dialog_id then stats_capture_cancel() end
    apply_style()
    local io = imgui.GetIO()
    local sw, sh = io.DisplaySize.x, io.DisplaySize.y
    local win_w, win_h = 640, math.min(sh - 80, 640)
    imgui.SetNextWindowSize(ImVec2(win_w, win_h), imgui.Cond.Always)
    imgui.SetNextWindowPos(ImVec2(sw / 2 - win_w / 2, sh / 2 - win_h / 2), imgui.Cond.Always)
    imgui.Begin(u8'Ответ на /stats', stats_capture.open, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
    imgui.TextWrapped(u8'Команда: ' .. stats_capture.cmd)
    if stats_capture.waiting then
        imgui.TextColored(ImVec4(1, 0.8, 0.2, 1), u8'Жду диалог...')
    elseif stats_capture.dialog_id == nil then
        imgui.TextWrapped(u8'Диалог не появился. Проверь команду и попробуй снова.')
    else
        imgui.TextWrapped(u8'Если это меню - жми "Открыть" на нужном пункте, чтобы перейти дальше. Если это уже нужный текст - жми "Выбрать".')
        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
        imgui.BeginChild('##stats_lines', ImVec2(0, -40), true)
        for i, line in ipairs(stats_capture.lines) do
            imgui.PushIDStr('statline_' .. i)
            imgui.TextWrapped(tostring(i - 1) .. ': ' .. u8(line))
            local btn_w = (imgui.GetContentRegionAvail().x - 8) / 2
            if imgui.Button(u8'Выбрать' .. '##pick', ImVec2(btn_w, 0)) then stats_capture_pick_row(i) end
            imgui.SameLine()
            if imgui.Button(u8'Открыть' .. '##open', ImVec2(btn_w, 0)) then stats_capture_open_row(i) end
            imgui.Separator()
            imgui.PopID()
        end
        imgui.EndChild()
        if imgui.Button(u8'Отмена', ImVec2(-1, 26)) then stats_capture_cancel() end
    end
    imgui.End()
end)
ar_enabled = false
ar_angry = 0
ar_last_at = 0
ar_silent_until = 0
tsr_cfg = inicfg.load({
    settings = { hide_dialog = true, monitor_enabled = false, monitor_threshold = 5, autoreply_enabled = false },
}, tsr_cfg_file('TSRM_tsr'))
if tsr_cfg.settings.autoreply_enabled == nil then tsr_cfg.settings.autoreply_enabled = false end
function save_tsr_cfg() inicfg.save(tsr_cfg, tsr_cfg_file('TSRM_tsr')) end
function main()
    while not (isSampAvailable() and PLAYER_PED and doesCharExist(PLAYER_PED)) do wait(100) end
    wait(500)
    inst_hooks()
    ar_enabled = tsr_cfg.settings.autoreply_enabled or false
    sampRegisterChatCommand('zumi', function() menu_open[0] = not menu_open[0] end)
    sampRegisterChatCommand('tsm', function() menu_open[0] = not menu_open[0] end)
    sampRegisterChatCommand('testbotv', function() test_botv_start() end)
    chat_add('{35C8E8}[zumi]{FFFFFF} /zumi, /tsm', -1)
    lua_thread.create(function()
        wait(10000)
        tsr_req_sum(function(data) if data then mini_hud_data = data end end)
    end)
    lua_thread.create(function()
        while true do
            wait(1000)
            pcall(setPlayerNeverGetsTired, PLAYER_HANDLE, cfg.hooks.anti_stamina)
            if cfg.hooks.anti_stamina then pcall(setAnimGroupForChar, PLAYER_PED, 'PLAYER') end
        end
    end)
    arch_check.architecture = arch_check.detect()
    is_x64_build = (arch_check.architecture == 'x64')
    if cfg.misc.arch_warned == nil then cfg.misc.arch_warned = false end
    if is_x64_build and not cfg.misc.arch_warned then
        lua_thread.create(function()
            local t0 = os.clock()
            while not isSampAvailable() do wait(100) end
            while not sampIsLocalPlayerSpawned() do
                if os.clock() - t0 > 60 then break end
                wait(100)
            end
            wait(15000)
            arch_check.timer_start = os.clock()
            arch_check.warning_open[0] = true
        end)
    end
    lua_thread.create(function()
        while true do
            wait(1000)
            if tsr_dialog.pending and os.clock() - tsr_dialog.wait_start > 12 then
                tsr_dialog.pending = false; tsr_dialog.stage = 0; tsr_dialog.on_result = nil
            end
            if tg_cfg.settings.enabled and tg_cfg.settings.token ~= '' then
                tg_get_upd(function(res)
                    local ok = json.parse(res)
                    if not (ok and ok.ok and ok.result) then return end
                    for _, upd in ipairs(ok.result) do
                        if upd.update_id and upd.update_id > tg_last_upd then tg_last_upd = upd.update_id end
                        local cq = upd.callback_query
                        if cq and cq.message and cq.message.chat and cq.message.chat.id then
                            if tostring(cq.message.chat.id) == tostring(tg_cfg.settings.chat_id) then
                                if cq.data == 'admin_resume' then
                                    if resume_all then resume_all() end
                                elseif cq.data == 'admin_quit' then
                                    if stop_all then stop_all() end
                                    lua_thread.create(function() wait(500); os.exit() end)
                                elseif cq.data == 'work_progress' then
                                    tsr_req_sum(function(data)
                                        local txt = tsr_fmt_sum(data)
                                        tg_send(tg_cfg.settings.token, tg_cfg.settings.chat_id, txt)
                                    end)
                                elseif cq.data == 'bot_stop' then
                                    stop_all()
                                    tg_send(tg_cfg.settings.token, tg_cfg.settings.chat_id, u8'Бот выключен.')
                                end
                                if cq.id then
                                    local ack = string.format('https://api.telegram.org/bot%s/answerCallbackQuery?callback_query_id=%s', tg_cfg.settings.token, tostring(cq.id))
                                    http_async(ack, '', function() end, function() end)
                                end
                            end
                        end
                        local msg = upd.message
                        if msg and msg.text and msg.chat and msg.chat.id then
                            if tostring(msg.chat.id) == tostring(tg_cfg.settings.chat_id) then
                                local txt = msg.text:gsub('^%s+', ''):gsub('%s+$', '')
                                if txt == '/r' then
                                    tsr_req_sum()
                                elseif txt == '/help' or txt == '/start' then
                                    tg_bot_menu()
                                    tg_send(tg_cfg.settings.token, tg_cfg.settings.chat_id, tg_help)
                                elseif txt == '/menu' then
                                    tg_bot_menu()
                                elseif msg.reply_to_message then
                                    local ok2, game_text = pcall(function() return u8:decode(msg.text) end)
                                    sampProcessChatInput(chat_str(ok2 and game_text or msg.text))
                                end
                            end
                        end
                    end
                end, function(err) end)
            end
        end
    end)
    while true do wait(1000) end
end