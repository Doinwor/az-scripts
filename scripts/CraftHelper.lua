script_name('craft helper')
script_author('pinokio')
script_version('1.2')

local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local ffi = require 'ffi'
local sampev = require 'lib.samp.events'
local imgui = require 'mimgui'

local uiDefaults = {
    w_round = 6, c_round = 21, f_round = 40, p_round = 40, s_round = 40, g_round = 40,
    w_border = 2, c_border = 1, scrollbar_size = 40, grab_min = 10,
    wpad_x = 18, wpad_y = 20, fpad_x = 16, fpad_y = 2,
    isp_x = 3, isp_y = 3, iisp_x = 7, iisp_y = 13, indent = 30,
    font_scale = 1.039999961853, compact = true,
}
local ui = {}
for k, v in pairs(uiDefaults) do ui[k] = v end

local applyUILogged = false
local function applyUI()
	local mul = ui.compact and 0.72 or 1.0
	local st = imgui.GetStyle()
	local function setv(name, val)
		local ok, e = pcall(function() st[name] = val end)
		if not ok and not applyUILogged then
			applyUILogged = true
			pcall(function() chatLog('applyUI: ' .. name .. ' -> ' .. tostring(e)) end)
		end
	end
	setv('WindowRounding', ui.w_round)
	setv('ChildRounding', ui.c_round)
	setv('FrameRounding', ui.f_round)
	setv('PopupRounding', ui.p_round)
	setv('ScrollbarRounding', ui.s_round)
	setv('GrabRounding', ui.g_round)
	setv('WindowPadding', imgui.ImVec2(ui.wpad_x * mul, ui.wpad_y * mul))
	setv('FramePadding', imgui.ImVec2(ui.fpad_x * mul, ui.fpad_y * mul))
	setv('ItemSpacing', imgui.ImVec2(ui.isp_x * mul, ui.isp_y * mul))
	setv('ItemInnerSpacing', imgui.ImVec2(ui.iisp_x * mul, ui.iisp_y * mul))
	setv('IndentSpacing', ui.indent * mul)
	setv('ScrollbarSize', ui.scrollbar_size * mul)
	setv('GrabMinSize', ui.grab_min * mul)
	setv('WindowBorderSize', ui.w_border)
	setv('ChildBorderSize', ui.c_border)

	local C = imgui.Col
	local function col(i, r, g, b, a)
		pcall(function() st.Colors[i] = imgui.ImVec4(r / 255, g / 255, b / 255, a == nil and 1 or a) end)
	end
	col(C.WindowBg, 18, 26, 28)
	col(C.ChildBg, 22, 32, 34)
	col(C.PopupBg, 20, 30, 32, 0.98)
	col(C.Border, 45, 212, 191, 0.28)
	col(C.FrameBg, 28, 40, 42)
	col(C.FrameBgHovered, 36, 52, 55)
	col(C.FrameBgActive, 45, 62, 66)
	col(C.TitleBg, 14, 22, 24)
	col(C.TitleBgActive, 16, 30, 32)
	col(C.Button, 32, 48, 51)
	col(C.ButtonHovered, 45, 212, 191, 0.55)
	col(C.ButtonActive, 13, 148, 136)
	col(C.Header, 30, 46, 49)
	col(C.HeaderHovered, 45, 212, 191, 0.45)
	col(C.HeaderActive, 13, 148, 136)
	col(C.Separator, 45, 212, 191, 0.30)
	col(C.TextDisabled, 110, 135, 138)
	col(C.CheckMark, 45, 212, 191)
	col(C.SliderGrab, 45, 212, 191, 0.7)
	col(C.SliderGrabActive, 45, 212, 191)
	col(C.ScrollbarBg, 0, 0, 0, 0.2)
	col(C.ScrollbarGrab, 60, 80, 84)
	col(C.ScrollbarGrabHovered, 45, 212, 191, 0.6)
	col(C.ScrollbarGrabActive, 13, 148, 136)
	pcall(function() imgui.GetIO().FontGlobalScale = ui.font_scale * (ui.compact and 0.85 or 1.0) end)
end

local okFa, fa = pcall(require, 'fAwesome6_solid')
if not okFa then fa = setmetatable({}, { __index = function() return '' end }) end
local new = imgui.new
local store = {}
local ImVec2 = imgui.ImVec2
local ImVec4 = imgui.ImVec4

local icoCache = {}
local function ico(name)
    local cached = icoCache[name]
    if cached ~= nil then return cached end
    local result = ''
    if okFa then
        local ok, v = pcall(function() return fa[name] end)
        if ok and type(v) == 'string' then result = v end
    end
    icoCache[name] = result
    return result
end

local sh_ = select(2, getScreenResolution())
local dpiScale = math.max(0.7, math.min(2.5, sh_ / 800))
local function S(v) return v * dpiScale end
local function refreshScale()
    local okLine, lh = pcall(function() return imgui.GetTextLineHeight() end)
    if okLine and type(lh) == 'number' and lh > 0 then
        dpiScale = math.max(0.7, math.min(2.5, lh / 15))
        return
    end
    local ok, ds = pcall(function() return imgui.GetIO().DisplaySize end)
    if ok and ds and ds.y > 0 then dpiScale = math.max(0.7, math.min(2.5, ds.y / 800)) end
end

local function lowerCp(s)
    s = s:gsub('[\192-\223]', function(ch) return string.char(ch:byte() + 32) end)
    s = s:gsub('\168', '\184')
    return s:lower()
end

local function rgb(r, g, b, a) return ImVec4(r / 255, g / 255, b / 255, a or 1) end

local function trim(str)
    return (str:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function readBuf(buf)
    local raw = ffi.string(buf)
    local ok, r = pcall(function() return u8:decode(raw) end)
    if ok and type(r) == 'string' then return r end
    return raw
end

local craftDir
local function cpath(name) return craftDir .. '/' .. name end
local collecting = false
local scanning = false
local menuOpen = new.bool(false)
local scanFrac = 0

local itemNameById = {}
local itemNameCount = 0

local itemNameRaw = {}

local function loadItemNames()
    local function parseItemNames(text)
        local pos, processed, added = 1, 0, 0
        while true do
            local s1, e1, object = text:find('{(.-)}', pos)
            if not s1 then break end
            pos = e1 + 1
            local id = object:match('"id"%s*:%s*(%d+)')
            local name = object:match('"name"%s*:%s*"(.-)"')
            id = id and tonumber(id)
            if id and name and not itemNameRaw[id] then
                itemNameRaw[id] = (name:gsub('\\"', '"'):gsub('\\/', '/'))
                itemNameCount = itemNameCount + 1
                added = added + 1
            end
            processed = processed + 1
            if processed % 300 == 0 then wait(0) end
        end
        return processed, added
    end

    local paths, seen = {}, {}
    local function add(p)
        if p and not seen[p] then
            seen[p] = true
            paths[#paths + 1] = p
        end
    end
    if craftDir then
        add(craftDir .. '/items_const.json')
        add(craftDir .. '/items.json')
    end

    for _, path in ipairs(paths) do
        local f = io.open(path, 'rb')
        if f then
            local text = f:read('*a') or ''
            f:close()
            if #text > 0 then
                parseItemNames(text)
                if itemNameCount > 0 then break end
            end
        end
    end
end

local function itemLabel(id)
    local cached = itemNameById[id]
    if cached then return cached end
    local raw = itemNameRaw[id]
    if raw and raw ~= '' then
        local ok, decoded = pcall(function() return u8:decode(raw) end)
        cached = (ok and decoded) or raw
        itemNameById[id] = cached
        return cached
    end
    return 'item_' .. tostring(id)
end

local function parseNeeds(json)
    local parts = {}
    local list = {}
    local seg = 1
    while true do
        local s, e = json:find('"needs"%s*:%s*%[', seg)
        if not s then break end
        local block = json:sub(e)
        local closePos = block:find('%]')
        if not closePos then break end
        block = block:sub(1, closePos)
        for item, amount in block:gmatch('"item"%s*:%s*(%d+)%s*,%s*"amount"%s*:%s*(%d+)') do
            local id = tonumber(item)
            parts[#parts + 1] = itemLabel(id) .. '(' .. amount .. ')'
            list[#list + 1] = { id = id, amount = tonumber(amount) }
        end
        seg = e + closePos
    end
    return table.concat(parts, ' + '), list
end

local function jsonField(json, key)
    local v = json:match('"' .. key .. '"%s*:%s*([%-]?%d+)')
    return v and tonumber(v) or nil
end

local lastSelected = { category = nil, index = nil }
local itemListByCategory = {}
local categoryOrder = {}
local categoryName = {}
local reported = {}
local recipeSeq = 0
local scanned = {}

local favorites = {}
local favsPath
local incremental = new.bool(true)
local scanIncremental = false
local knownIds = {}
local prevSnapshot = {}
local changes = {}
local changeById = {}
local newCount, changedCount = 0, 0
local savedOrder = {}

local function displayOrder()
    if #categoryOrder > 0 then return categoryOrder end
    return savedOrder
end

function store.saveFavs()
    if not favsPath or not encodeJson then return end
    local list = {}
    for id in pairs(favorites) do list[#list + 1] = id end
    table.sort(list)
    local ok, j = pcall(encodeJson, list)
    if not ok or not j then return end
    local f = io.open(favsPath, 'w')
    if f then f:write(j) f:close() end
end

function store.loadFavs()
    if not favsPath or not decodeJson then return end
    local f = io.open(favsPath, 'r')
    if not f then return end
    local text = f:read('*a') or ''
    f:close()
    local ok, d = pcall(decodeJson, text)
    if not ok or type(d) ~= 'table' then return end
    for _, id in ipairs(d) do
        id = tonumber(id)
        if id then favorites[id] = true end
    end
end

function store.toggleFav(id)
    if not id then return end
    favorites[id] = (not favorites[id]) or nil
    store.saveFavs()
end

local pinned = {}
local pinsPath

function store.savePins()
    if not pinsPath or not encodeJson then return end
    local list = {}
    for id in pairs(pinned) do list[#list + 1] = id end
    table.sort(list)
    local ok, j = pcall(encodeJson, list)
    if not ok or not j then return end
    local f = io.open(pinsPath, 'w')
    if f then f:write(j) f:close() end
end

function store.loadPins()
    if not pinsPath or not decodeJson then return end
    local f = io.open(pinsPath, 'r')
    if not f then return end
    local text = f:read('*a') or ''
    f:close()
    local ok, d = pcall(decodeJson, text)
    if not ok or type(d) ~= 'table' then return end
    for _, id in ipairs(d) do
        id = tonumber(id)
        if id then pinned[id] = true end
    end
end

function store.togglePin(id)
    if not id then return end
    pinned[id] = (not pinned[id]) or nil
    store.savePins()
end

local inventory = { items = {}, time = 0 }
local inventoryPath

function store.saveInventory()
    if not inventoryPath or not encodeJson then return end
    local list = {}
    for _, e in pairs(inventory.items) do list[#list + 1] = { name = e.name, qty = e.qty } end
    table.sort(list, function(a, b) return lowerCp(a.name) < lowerCp(b.name) end)
    local ok, j = pcall(encodeJson, { time = inventory.time, items = list })
    if not ok or not j then return end
    local f = io.open(inventoryPath, 'w')
    if f then f:write(j) f:close() end
end

function store.loadInventory()
    if not inventoryPath or not decodeJson then return end
    local f = io.open(inventoryPath, 'r')
    if not f then return end
    local text = f:read('*a') or ''
    f:close()
    local ok, d = pcall(decodeJson, text)
    if not ok or type(d) ~= 'table' or type(d.items) ~= 'table' then return end
    local items = {}
    for _, e in ipairs(d.items) do
        if type(e) == 'table' and type(e.name) == 'string' and tonumber(e.qty) then
            items[lowerCp(trim(e.name))] = { name = e.name, qty = tonumber(e.qty) }
        end
    end
    inventory.items = items
    inventory.time = tonumber(d.time) or 0
end

local settings = { autoInv = true, tutorialDone = false, ui = nil, avgServer = 2, uiVer = 2 }
function csAvgServerGet() return settings.avgServer or 2 end
local autoInvBuf = new.bool(true)

local settingsPath

function store.saveSettings()
    if not settingsPath or not encodeJson then return end
    settings.ui = ui
    settings.uiVer = 2
    local ok, j = pcall(encodeJson, settings)
    if not ok or not j then return end
    local f = io.open(settingsPath, 'w')
    if f then f:write(j) f:close() end
end

function store.loadSettings()
    if not settingsPath or not decodeJson then return end
    local f = io.open(settingsPath, 'r')
    if not f then return end
    local text = f:read('*a') or ''
    f:close()
    local ok, d = pcall(decodeJson, text)
    if not ok or type(d) ~= 'table' then return end
    if d.autoInv ~= nil then settings.autoInv = d.autoInv == true end
    if tonumber(d.avgServer) then settings.avgServer = tonumber(d.avgServer) end
    settings.tutorialDone = d.tutorialDone == true
    if type(d.ui) == 'table' and tonumber(d.uiVer) == 2 then
        for k, v in pairs(d.ui) do
            if uiDefaults[k] ~= nil then ui[k] = v end
        end
    end
end

local invKeyCache = {}

local function inventoryQty(name)
    if inventory.time == 0 then return nil end
    local key = invKeyCache[name]
    if not key then
        key = lowerCp(trim(name))
        invKeyCache[name] = key
    end
    local e = inventory.items[key]
    return e and e.qty or nil
end

local function noteChange(entry, cat)
    local id = entry.id
    if not id or next(prevSnapshot) == nil or changeById[id] then return end
    local prev = prevSnapshot[id]
    local kind
    if not prev then
        kind = 'new'
        newCount = newCount + 1
    elseif prev.chance ~= entry.chance or prev.cost ~= entry.cost or prev.needs ~= entry.needs then
        kind = 'changed'
        changedCount = changedCount + 1
    else
        return
    end
    local ch = { id = id, cat = cat, kind = kind, old = prev, entry = entry }
    changes[#changes + 1] = ch
    changeById[id] = ch
end

local recipesJsonPath
local modsPath
local searchQuery = new.char[256]('')

function store.saveRecipes()
    if not recipesJsonPath or not encodeJson then return end
    local ids, seen = {}, {}
    for _, c in ipairs(displayOrder()) do
        if not seen[c] then
            seen[c] = true
            ids[#ids + 1] = c
        end
    end
    local extra = {}
    for c in pairs(scanned) do
        if not seen[c] then
            seen[c] = true
            extra[#extra + 1] = c
        end
    end
    for c in pairs(categoryName) do
        if not seen[c] then
            seen[c] = true
            extra[#extra + 1] = c
        end
    end
    table.sort(extra)
    for _, c in ipairs(extra) do ids[#ids + 1] = c end
    local cats = {}
    for _, c in ipairs(ids) do
        cats[#cats + 1] = { id = c, name = categoryName[c] or '', items = scanned[c] or {} }
    end
    local ok, j = pcall(encodeJson, { version = 2, cats = cats })
    if not ok or not j then return end
    local f = io.open(recipesJsonPath, 'w')
    if f then f:write(j) f:close() end
end

function store.loadRecipes()
    if not recipesJsonPath or not decodeJson then return end
    local f = io.open(recipesJsonPath, 'r')
    if not f then return end
    local text = f:read('*a') or ''
    f:close()
    if text == '' then return end
    local ok, data = pcall(decodeJson, text)
    if not ok or type(data) ~= 'table' then return end

    local function remember(cat, list)
        for _, it in ipairs(list) do
            reported[string.format('%s|%s|%s|%s|%s',
                tostring(it.id), tostring(cat), '0',
                tostring(it.chance), tostring(it.needs or ''))] = true
        end
    end

    if type(data.cats) == 'table' then
        local order = {}
        for _, c in ipairs(data.cats) do
            local id = type(c) == 'table' and tonumber(c.id) or nil
            if id then
                order[#order + 1] = id
                if type(c.name) == 'string' and c.name ~= '' then categoryName[id] = c.name end
                local list = {}
                if type(c.items) == 'table' then
                    for _, it in ipairs(c.items) do list[#list + 1] = it end
                end
                scanned[id] = list
                remember(id, list)
            end
        end
        categoryOrder = order
        return
    end

    if type(data.categories) == 'table' then
        for k, v in pairs(data.categories) do
            categoryName[tonumber(k)] = v
        end
    end
    if type(data.items) == 'table' then
        for k, list in pairs(data.items) do
            local cat = tonumber(k)
            if cat and type(list) == 'table' then
                scanned[cat] = list
                remember(cat, list)
            end
        end
    end
    local order = {}
    if type(data.order) == 'table' then
        for _, c in ipairs(data.order) do
            if categoryName[c] ~= nil or scanned[c] ~= nil then order[#order + 1] = c end
        end
    else
        for c in pairs(categoryName) do order[#order + 1] = c end
        table.sort(order)
    end
    categoryOrder = order
end

local recipesDirty, recipesDirtyT = false, 0

local function chatLog(msg)
    sampAddChatMessage('[Craft Helper] ' .. msg, 0xFF40D9C8)
end

local function sendCraftClick(category, index)
    local json = string.format('{"category":%d,"index":%d}', category, index)
    local bs = raknetNewBitStream()
    if not bs then return false end
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, 58)
    raknetBitStreamWriteInt32(bs, -1)
    raknetBitStreamWriteInt32(bs, 1)
    raknetBitStreamWriteInt16(bs, #json)
    raknetBitStreamWriteString(bs, json)
    local ok, err = pcall(raknetSendBitStreamEx, bs, 1, 7, 1)
    raknetDeleteBitStream(bs)
    return ok and err ~= false
end

local dumpCount = 0
local function handleFrontendMessage(json)
    if json:find('"categories"') then
        for cat, name, itemsBlock in json:gmatch('"category"%s*:%s*(%d+)%s*,%s*"name"%s*:%s*"(.-)"%s*,%s*"items"%s*:%s*%[([^%]]*)%]') do
            local c = tonumber(cat)
            local list = {}
            for num in itemsBlock:gmatch('(%d+)') do
                list[#list + 1] = tonumber(num)
            end
            if not itemListByCategory[c] then
                categoryOrder[#categoryOrder + 1] = c
            end
            itemListByCategory[c] = list
            categoryName[c] = name
        end
        return
    end

    if not json:find('"needs"') then return end
    recipeSeq = recipeSeq + 1

    if dumpCount < 8 then
        dumpCount = dumpCount + 1
        local df = io.open(cpath('raw_dump.txt'), dumpCount == 1 and 'w' or 'a')
        if df then
            df:write('[' .. dumpCount .. '] cat=' .. tostring(lastSelected.category) .. ' idx=' .. tostring(lastSelected.index) .. '\n' .. json .. '\n\n')
            df:close()
        end
    end

    local chance = jsonField(json, 'chance')
    local cost = jsonField(json, 'cost')
    local craftTime = jsonField(json, 'time') or jsonField(json, 'craftTime') or jsonField(json, 'duration')
    local needs, needsList = parseNeeds(json)
    if (chance == nil or cost == nil or #needsList == 0) and decodeJson then
        local okD, d = pcall(decodeJson, json)
        if okD and type(d) == 'table' then
            local function findKey(tb, key, depth)
                if type(tb) ~= 'table' or depth > 5 then return nil end
                if tb[key] ~= nil then return tb[key] end
                for _, v in pairs(tb) do
                    if type(v) == 'table' then
                        local r = findKey(v, key, depth + 1)
                        if r ~= nil then return r end
                    end
                end
            end
            if chance == nil then chance = tonumber(findKey(d, 'chance', 0)) end
            if cost == nil then cost = tonumber(findKey(d, 'cost', 0)) end
            if craftTime == nil then craftTime = tonumber(findKey(d, 'time', 0)) end
            if #needsList == 0 then
                local nt = findKey(d, 'needs', 0)
                if type(nt) == 'table' then
                    local parts = {}
                    for _, n in ipairs(nt) do
                        if type(n) == 'table' then
                            local nid = tonumber(n.item or n.id)
                            local amt = tonumber(n.amount or n.count or n.qty)
                            if nid and amt then
                                parts[#parts + 1] = itemLabel(nid) .. '(' .. amt .. ')'
                                needsList[#needsList + 1] = { id = nid, amount = amt }
                            end
                        end
                    end
                    if #needsList > 0 then needs = table.concat(parts, ' + ') end
                end
            end
        end
    end
    local selCat = lastSelected.category
    local selIdx = lastSelected.index
    local itemId
    if selCat and selIdx and itemListByCategory[selCat] then
        itemId = itemListByCategory[selCat][selIdx + 1]
    end

    local key = string.format('%s|%s|%s|%s|%s',
        tostring(itemId), tostring(selCat), tostring(selIdx), tostring(chance), needs)
    if reported[key] then return end
    reported[key] = true
    local itemName = itemId and itemLabel(itemId) or '?'
    if selCat then
        scanned[selCat] = scanned[selCat] or {}
        local entry = {
            id = itemId,
            name = itemName,
            needs = needs,
            needsList = needsList,
            chance = chance,
            cost = cost,
            time = craftTime
        }
        table.insert(scanned[selCat], entry)
        noteChange(entry, selCat)
        recipesDirty = true
        recipesDirtyT = os.clock()
    end
end

local function handleClick(json)
    local cat = json:match('"category"%s*:%s*(%d+)')
    local idx = json:match('"index"%s*:%s*(%d+)')
    if cat then lastSelected.category = tonumber(cat) end
    if idx then lastSelected.index = tonumber(idx) end
end

addEventHandler('onReceivePacket', function(id, bs)
    if id ~= 220 or not collecting then return end
    raknetBitStreamIgnoreBits(bs, 8)
    local packetType = raknetBitStreamReadInt8(bs)
    if packetType ~= 84 then return end
    local interfaceid = raknetBitStreamReadInt8(bs)
    local subid = raknetBitStreamReadInt8(bs)
    if interfaceid ~= 58 then return end
    local len = raknetBitStreamReadInt16(bs)
    local enc = raknetBitStreamReadInt8(bs)
    local json = enc ~= 0
        and raknetBitStreamDecodeString(bs, len + enc)
        or raknetBitStreamReadString(bs, len)
    if json and json ~= '' then
        pcall(handleFrontendMessage, json)
    end
end)

addEventHandler('onSendPacket', function(id, bs)
    if id ~= 220 or not collecting then return end
    raknetBitStreamIgnoreBits(bs, 8)
    local packetType = raknetBitStreamReadInt8(bs)
    if packetType ~= 63 then return end
    raknetBitStreamReadInt8(bs)
    raknetBitStreamReadInt32(bs)
    raknetBitStreamReadInt32(bs)
    local len = raknetBitStreamReadInt16(bs)
    local json = raknetBitStreamReadString(bs, len)
    if json and json ~= '' then
        pcall(handleClick, json)
    end
end)

local function finishScan()
    scanning = false
    if collecting then
        collecting = false
    end
    recipesDirty = false
    store.saveRecipes()
end

local function autoScan()
    local waited = 0
    while collecting and #categoryOrder == 0 and waited < 60000 do
        wait(100)
        waited = waited + 100
    end

    if not collecting then
        finishScan()
        return
    end

    if #categoryOrder == 0 then
        chatLog('Верстак не открыт или категории не пришли')
        finishScan()
        return
    end

    local sentCount = 0
    local failCount = 0
    local skippedCount = 0
    local processedCats = {}
    local ci = 0

    while collecting do
        local cat
        for _, c in ipairs(categoryOrder) do
            if not processedCats[c] then
                cat = c
                break
            end
        end
        if not cat then
            local extraWait = 0
            while collecting and extraWait < 3000 do
                wait(100)
                extraWait = extraWait + 100
                for _, c in ipairs(categoryOrder) do
                    if not processedCats[c] then cat = c break end
                end
                if cat then break end
            end
            if not cat then break end
        end

        processedCats[cat] = true
        ci = ci + 1
        local list = itemListByCategory[cat] or {}
        local catLabel = categoryName[cat] or ('cat ' .. cat)
        chatLog('Вкладка ' .. ci .. ': ' .. catLabel .. ' (' .. #list .. ' шт.)')
        for i = 1, #list do
            if not collecting then break end
            local itemId = list[i]
            if scanIncremental and itemId and knownIds[itemId] then
                skippedCount = skippedCount + 1
            else
                local itemName = itemId and itemLabel(itemId) or '?'
                local seqBefore = recipeSeq
                local ok = sendCraftClick(cat, i - 1)
                if ok then
                    sentCount = sentCount + 1
                else
                    failCount = failCount + 1
                end
                lastSelected.category = cat
                lastSelected.index = i - 1
                local tw = 0
                local startedAt = os.clock()
                while collecting and recipeSeq == seqBefore and tw < 2500 do
                    wait(0)
                    tw = math.floor((os.clock() - startedAt) * 1000)
                end
                wait(0)
            end
            scanFrac = math.min(1, ((ci - 1) + i / math.max(1, #list)) / math.max(1, #categoryOrder))
        end
    end

    chatLog('Готово: отправлено ' .. sentCount .. ', ошибок ' .. failCount .. ', пропущено известных ' .. skippedCount .. ', новых ' .. newCount .. ', изменено ' .. changedCount .. '.')
    scanFrac = 1
    finishScan()
end

local function toggleScan()
    collecting = not collecting
    if collecting then
        scanIncremental = incremental[0]
        prevSnapshot = {}
        knownIds = {}
        for _, list in pairs(scanned) do
            for _, it in ipairs(list) do
                if it.id then
                    prevSnapshot[it.id] = { chance = it.chance, cost = it.cost, needs = it.needs }
                    knownIds[it.id] = true
                end
            end
        end
        changes = {}
        changeById = {}
        newCount, changedCount = 0, 0
        savedOrder = {}
        for _, c in ipairs(categoryOrder) do savedOrder[#savedOrder + 1] = c end
        if not scanIncremental then
            reported = {}
            scanned = {}
        end
        categoryOrder = {}
        itemListByCategory = {}
        lastSelected.category = nil
        lastSelected.index = nil
        scanFrac = 0
        chatLog('Скан включен. Имен: ' .. itemNameCount .. '. Открой верстак, скан начнется сам.')
        if not scanning then
            scanning = true
            lua_thread.create(autoScan)
        end
        return true
    end
    chatLog('Скан выключен')
    return false
end

local invScan = { active = false, stage = '', pages = 0, started = 0, temp = {}, status = '', silent = false, failures = 0, backoff = 0, lastSig = '', lastSaved = '' }

local function stripColors(str)
    return (tostring(str or ''):gsub('{%x%x%x%x%x%x}', ''))
end

local function respondDialog(dialogId, button, listitem)
    lua_thread.create(function()
        wait(0)
        sampSendDialogResponse(dialogId, button, listitem, '')
    end)
end

local function inventorySignature(items)
    local keys = {}
    for k, e in pairs(items) do keys[#keys + 1] = k .. '=' .. e.qty end
    table.sort(keys)
    return table.concat(keys, ';')
end

local function finishInventory(ok, message)
    invScan.active = false
    invScan.status = message
    if ok then
        invScan.failures = 0
        local sig = inventorySignature(invScan.temp)
        inventory.items = invScan.temp
        inventory.time = os.time()
        if sig ~= invScan.lastSaved then
            invScan.lastSaved = sig
            store.saveInventory()
        end
    else
        invScan.failures = invScan.failures + 1
        if invScan.failures >= 3 then
            invScan.failures = 0
            invScan.backoff = os.clock() + 60
        end
    end
    if not invScan.silent then chatLog(message) end
end

local function inventoryCountText()
    local count = 0
    for _ in pairs(invScan.temp) do count = count + 1 end
    return count
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if not invScan.active then return end
    local cleanTitle = stripColors(title)
    local cleanB1 = stripColors(button1)
    local body = stripColors(text):gsub('\r', ''):gsub('\t', ' ')
    invScan.started = os.clock()

    if invScan.stage == 'stats' then
        if lowerCp(cleanB1):find('предмет', 1, true) or lowerCp(cleanTitle):find('статистика', 1, true) then
            invScan.stage = 'items'
            respondDialog(dialogId, 1, -1)
            return false
        end
        return
    end

    if invScan.stage == 'items' then
        local lines = {}
        for line in (body .. '\n'):gmatch('(.-)\n') do
            if line:match('%S') then lines[#lines + 1] = line end
        end
        if style == 5 and #lines > 0 then table.remove(lines, 1) end
        local signature = (lines[1] or '') .. '|' .. #lines .. '|' .. (lines[#lines] or '')
        if signature == invScan.lastSig then
            respondDialog(dialogId, 0, -1)
            finishInventory(true, 'Инвентарь: позиций ' .. inventoryCountText() .. ', страниц ' .. invScan.pages)
            return false
        end

        local found, nextIndex = 0, nil
        for i, line in ipairs(lines) do
            local slot, rest = line:match('^%s*%[(%d+)%]%s*(.-)%s*$')
            if slot then
                local name, bracket = rest:match('^(.-)%s*%[([^%]]*)%]$')
                if not name then
                    name, bracket = rest, ''
                end
                name = trim(name)
                local qty = tonumber(bracket:match('^(%d+)%s*шт')) or 1
                if name ~= '' then
                    local key = lowerCp(name)
                    local cur = invScan.temp[key]
                    invScan.temp[key] = { name = name, qty = (cur and cur.qty or 0) + qty }
                    found = found + 1
                end
            elseif lowerCp(line):find('следующая страница', 1, true) then
                nextIndex = i - 1
            end
        end
        if found == 0 and not nextIndex then return end
        invScan.lastSig = signature
        invScan.pages = invScan.pages + 1
        if nextIndex and invScan.pages < 60 then
            respondDialog(dialogId, 1, nextIndex)
        else
            respondDialog(dialogId, 0, -1)
            finishInventory(true, 'Инвентарь: позиций ' .. inventoryCountText() .. ', страниц ' .. invScan.pages)
        end
        return false
    end
end

local function startInventoryScan(silent)
    if invScan.active then return end
    invScan.silent = silent == true
    invScan.active = true
    invScan.stage = 'stats'
    invScan.pages = 0
    invScan.temp = {}
    invScan.lastSig = ''
    invScan.started = os.clock()
    invScan.status = 'Жду диалог /stats'
    sampSendChat('/stats')
    lua_thread.create(function()
        while invScan.active do
            wait(100)
            if os.clock() - invScan.started > 8 then
                if next(invScan.temp) ~= nil then
                    finishInventory(true, 'Инвентарь получен частично: позиций ' .. inventoryCountText())
                else
                    finishInventory(false, 'Диалог не пришел')
                end
            end
        end
    end)
end

local function loadFonts()
    local initialized = false
    if okFa then
        local okInit, initFn = pcall(function() return fa.Init end)
        if okInit and type(initFn) == 'function' then
            initialized = pcall(initFn)
        end
    end
    if not initialized then
        local io_ = imgui.GetIO()
        local fp = '/system/fonts/Roboto-Regular.ttf'
        if doesFileExist(fp) then
            pcall(function() io_.Fonts:AddFontFromFileTTF(fp, S(15), nil, io_.Fonts:GetGlyphRangesCyrillic()) end)
        end
    end
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    refreshScale()
    loadFonts()
    local s = imgui.GetStyle()
    s.WindowRounding = 12
    s.ChildRounding = 10
    s.FrameRounding = 8
    s.TabRounding = 8
    s.GrabRounding = 8
    s.PopupRounding = 8
    s.WindowPadding = ImVec2(12, 12)
    s.FramePadding = ImVec2(9, 6)
    s.ItemSpacing = ImVec2(9, 7)
    local c = s.Colors
    c[imgui.Col.WindowBg] = rgb(10, 17, 19, 0.97)
    c[imgui.Col.ChildBg] = rgb(15, 26, 29, 1)
    c[imgui.Col.FrameBg] = rgb(22, 38, 42, 1)
    c[imgui.Col.Button] = rgb(27, 48, 53, 1)
    c[imgui.Col.ButtonHovered] = rgb(38, 82, 86, 1)
    c[imgui.Col.ButtonActive] = rgb(20, 184, 166, 1)
    c[imgui.Col.Header] = rgb(20, 72, 72, 1)
    c[imgui.Col.HeaderHovered] = rgb(28, 102, 100, 1)
    c[imgui.Col.HeaderActive] = rgb(20, 184, 166, 1)
    c[imgui.Col.Tab] = rgb(22, 38, 42, 1)
    c[imgui.Col.TabHovered] = rgb(38, 82, 86, 1)
    c[imgui.Col.TabActive] = rgb(20, 184, 166, 1)
    c[imgui.Col.Separator] = rgb(34, 62, 66, 1)
    c[imgui.Col.Border] = rgb(40, 72, 76, 1)
    c[imgui.Col.Text] = rgb(226, 240, 240, 1)
    c[imgui.Col.TextDisabled] = rgb(120, 152, 154, 1)
    c[imgui.Col.PlotHistogram] = rgb(20, 184, 166, 1)
    c[imgui.Col.TitleBg] = rgb(14, 44, 46, 1)
    c[imgui.Col.TitleBgActive] = rgb(18, 98, 92, 1)
    c[imgui.Col.TitleBgCollapsed] = rgb(10, 30, 32, 1)
    c[imgui.Col.ResizeGrip] = rgb(20, 184, 166, 0.45)
    c[imgui.Col.ResizeGripHovered] = rgb(45, 212, 191, 0.7)
    c[imgui.Col.ResizeGripActive] = rgb(45, 212, 191, 1)
end)

local viewCat = nil
local detailCat = nil
local detailItem = nil
local attempts = 1
local cartWarn = nil
local filterState = {
    chanceSteps = { 0, 10, 25, 50, 75 },
    costSteps = { 0, 100000, 500000, 1000000, 5000000 },
    chanceIdx = 1,
    costIdx = 1,
    craft = false,
}
local compareItems = {}
local cart = {}
local iconDir = nil
local iconCache = {}
local iconMiss = {}
local sortMode = 0
local sortDesc = false

local function getIconTexture(itemId)
    if not itemId then return nil end
    if iconCache[itemId] then return iconCache[itemId] end
    local miss = iconMiss[itemId]
    if miss and os.clock() - miss < 5 then return nil end
    local wd = getWorkingDirectory()
    local base = iconDir or (wd .. '/config/craft/icons')
    for _, p in ipairs({
        base .. '/' .. itemId .. '.png',
        base .. '/icons/' .. itemId .. '.png'
    }) do
        local f = io.open(p, 'rb')
        if f then
            f:close()
            local ok, tex = pcall(imgui.CreateTextureFromFile, p)
            if ok and tex then
                iconCache[itemId] = tex
                return tex
            end
        end
    end
    iconMiss[itemId] = os.clock()
    return nil
end

local function fmtMoney(v)
    if not v then return '-' end
    local s = tostring(math.floor(tonumber(v) or 0))
    local rev = s:reverse():gsub('(%d%d%d)', '%1.')
    local out = rev:reverse():gsub('^%.', '')
    return out
end

local function fmtChance(v)
    if not v then return '-' end
    if v == math.floor(v) then return tostring(math.floor(v)) .. '%' end
    return string.format('%.1f%%', v)
end

local function chanceColor(v)
    if not v then return rgb(120, 152, 154) end
    if v >= 70 then return rgb(74, 222, 128) end
    if v >= 40 then return rgb(250, 204, 21) end
    return rgb(248, 113, 113)
end

local GOLD = rgb(251, 191, 36)
local ACCENT = rgb(45, 212, 191)
local CATEGORY_COLORS = {
    rgb(45, 212, 191), rgb(56, 189, 248), rgb(167, 139, 250), rgb(244, 114, 182),
    rgb(251, 146, 60), rgb(163, 230, 53), rgb(250, 204, 21), rgb(248, 113, 113),
}
local ALL_COLOR = rgb(56, 189, 248)
local CHANGE_COLOR = rgb(251, 146, 60)
local PIN_COLOR = rgb(251, 146, 60)
local CATEGORY_ICONS = { 'BOX', 'GEM', 'SHIRT', 'GUN', 'CAR', 'HAMMER', 'FLASK', 'KEY', 'STAR', 'BAG_SHOPPING' }

local function categoryIcon(index)
    local name = CATEGORY_ICONS[((index - 1) % #CATEGORY_ICONS) + 1]
    local v = ico(name)
    if v == '' then v = ico('BOX') end
    return v
end

local MOD_BUFFS = {
    { key = 'craftVc',   label = 'Крафт VC -20%', pct = 20 },
    { key = 'mimic',     label = 'Мимик -1%',     pct = 1 },
    { key = 'economist', label = 'Экономист -1%', pct = 1 },
    { key = 'mirage',    label = 'Мираж -7%',     pct = 7 },
}
local GUARD_TIERS = { 12, 21, 29, 31, 34, 36 }
local GUARD_TIMES = { 2, 3, 5 }
local mods = { vipX2 = false, vipPlus2 = false, buffs = {}, guardTier = 0, guardTime = 0, guardPrice = false }
local customMods = {}
local customModsPath
local CUSTOM_KINDS = { 'chanceAdd', 'chanceMul', 'costOff', 'resOff', 'timeOff' }
local CUSTOM_KIND_LABELS = {
    'Шанс: прибавить пункты (+N)',
    'Шанс: умножить (xN)',
    'Цена: скидка (-N%)',
    'Ресурсы: экономия (-N%)',
    'Время: убрать секунды (-N сек)',
}

function store.saveMods()
    if not modsPath or not encodeJson then return end
    local ok, j = pcall(encodeJson, mods)
    if not ok or not j then return end
    local f = io.open(modsPath, 'w')
    if f then f:write(j) f:close() end
end

function store.loadMods()
    if not modsPath or not decodeJson then return end
    local f = io.open(modsPath, 'r')
    if not f then return end
    local text = f:read('*a') or ''
    f:close()
    local ok, d = pcall(decodeJson, text)
    if not ok or type(d) ~= 'table' then return end
    mods.vipX2 = d.vipX2 == true
    mods.vipPlus2 = d.vipPlus2 == true
    mods.guardPrice = d.guardPrice == true
    mods.guardTier = tonumber(d.guardTier) or 0
    mods.guardTime = tonumber(d.guardTime) or 0
    mods.buffs = {}
    if type(d.buffs) == 'table' then
        for k, v in pairs(d.buffs) do mods.buffs[k] = v == true end
    end
end

function store.saveCustomMods()
    if not customModsPath or not encodeJson then return end
    local ok, j = pcall(encodeJson, customMods)
    if not ok or not j then return end
    local f = io.open(customModsPath, 'w')
    if f then f:write(j) f:close() end
end

function store.loadCustomMods()
    if not customModsPath or not decodeJson then return end
    local f = io.open(customModsPath, 'r')
    if not f then return end
    local text = f:read('*a') or ''
    f:close()
    local ok, d = pcall(decodeJson, text)
    if not ok or type(d) ~= 'table' then return end
    local known = {}
    for _, k in ipairs(CUSTOM_KINDS) do known[k] = true end
    customMods = {}
    for _, cm in ipairs(d) do
        if type(cm) == 'table' and type(cm.name) == 'string' and known[cm.kind] and tonumber(cm.value) and tonumber(cm.value) > 0 then
            customMods[#customMods + 1] = { name = cm.name, kind = cm.kind, value = tonumber(cm.value), on = cm.on == true }
        end
    end
end

local function customLabel(cm)
    local v = (cm.value == math.floor(cm.value)) and tostring(math.floor(cm.value)) or string.format('%.2f', cm.value)
    local tail
    if cm.kind == 'chanceAdd' then
        tail = '+' .. v
    elseif cm.kind == 'chanceMul' then
        tail = 'x' .. v
    elseif cm.kind == 'costOff' then
        tail = 'цена -' .. v .. '%'
    elseif cm.kind == 'resOff' then
        tail = 'ресурсы -' .. v .. '%'
    else
        tail = '-' .. v .. ' сек'
    end
    return cm.name .. '  ' .. tail
end

local function anyMods()
    if mods.vipX2 or mods.vipPlus2 or mods.guardPrice or mods.guardTier > 0 or mods.guardTime > 0 then return true end
    for _, v in pairs(mods.buffs) do
        if v then return true end
    end
    for _, cm in ipairs(customMods) do
        if cm.on then return true end
    end
    return false
end

local function applyMods(it)
    local costOff, resOff, timeOff = 0, mods.guardTier, mods.guardTime
    local chanceAdd, chanceMul = 0, 1
    for _, b in ipairs(MOD_BUFFS) do
        if mods.buffs[b.key] then costOff = costOff + b.pct end
    end
    if mods.guardPrice then costOff = costOff + 6 end
    if mods.vipX2 then chanceMul = chanceMul * 2 end
    if mods.vipPlus2 then chanceAdd = chanceAdd + 2 end
    for _, cm in ipairs(customMods) do
        if cm.on then
            if cm.kind == 'chanceAdd' then
                chanceAdd = chanceAdd + cm.value
            elseif cm.kind == 'chanceMul' then
                chanceMul = chanceMul * cm.value
            elseif cm.kind == 'costOff' then
                costOff = costOff + cm.value
            elseif cm.kind == 'resOff' then
                resOff = resOff + cm.value
            elseif cm.kind == 'timeOff' then
                timeOff = timeOff + cm.value
            end
        end
    end
    local chance = it.chance
    if chance then chance = math.min(100, chance * chanceMul + chanceAdd) end
    local cost = it.cost
    if cost then cost = math.floor(cost * math.max(0, 100 - costOff) / 100 + 0.5) end
    local time = it.time
    if time then time = math.max(0, time - timeOff) end
    local factor = math.max(0, 100 - resOff) / 100
    return { chance = chance, cost = cost, time = time, factor = factor, costOff = costOff }
end

local function sortedIndices(list)
    local idx = {}
    for i = 1, #list do idx[i] = i end
    if sortMode ~= 0 then
        table.sort(idx, function(a, b)
            local x, y = list[a], list[b]
            local vx, vy
            if sortMode == 1 then
                vx, vy = lowerCp(x.name or ''), lowerCp(y.name or '')
            elseif sortMode == 2 then
                vx, vy = x.chance or -1, y.chance or -1
            else
                vx, vy = x.cost or -1, y.cost or -1
            end
            if vx == vy then return a < b end
            if sortDesc then return vx > vy end
            return vx < vy
        end)
    end
    return idx
end

local COLOR_GREEN = rgb(16, 150, 110, 1)
local COLOR_RED = rgb(190, 70, 80, 1)
local COLOR_ACCENT = rgb(13, 148, 136, 1)
local COLOR_GOLD_BTN = rgb(161, 98, 7, 1)

local function btnH(mult)
    return imgui.GetFrameHeight() * (mult or 1.3)
end

local function buttonRow(items, height)
    local spacing = imgui.GetStyle().ItemSpacing.x
    local avail = imgui.GetContentRegionAvail().x
    local w = math.floor((avail - spacing * (#items - 1)) / #items)
    local clicked
    for i, item in ipairs(items) do
        if i > 1 then imgui.SameLine() end
        if item.color then imgui.PushStyleColor(imgui.Col.Button, item.color) end
        if imgui.Button(item.label .. '##' .. item.id, ImVec2(w, height or btnH(1.3))) then clicked = item.id end
        if item.color then imgui.PopStyleColor() end
    end
    return clicked
end

local COLOR_OK = rgb(74, 222, 128)
local COLOR_BAD = rgb(248, 113, 113)

local function amountText(name, need)
    local have = inventoryQty(name)
    if have == nil then return tostring(need), GOLD end
    return need .. '/' .. have, (have >= need) and COLOR_OK or COLOR_BAD
end

local winPath
local winStates = {}
local winForce = {}
local pendingPos = {}
local winChecked = {}
local winDirty, winDirtyT = false, 0

function store.saveWin()
    winDirty = false
    if not winPath or not encodeJson then return end
    local out = { _ver = 2 }
    for k, v in pairs(winStates) do out[k] = v end
    local ok, j = pcall(encodeJson, out)
    if not ok or not j then return end
    local f = io.open(winPath, 'w')
    if f then f:write(j) f:close() end
end

function store.loadWin()
    if not winPath or not decodeJson then return end
    local f = io.open(winPath, 'r')
    if not f then return end
    local text = f:read('*a') or ''
    f:close()
    local ok, d = pcall(decodeJson, text)
    if not ok or type(d) ~= 'table' then return end
    for key, st in pairs(d) do
        if type(st) == 'table' and tonumber(st.x) and tonumber(st.y) and tonumber(st.w) and tonumber(st.h) then
            winStates[key] = { x = tonumber(st.x), y = tonumber(st.y), w = tonumber(st.w), h = tonumber(st.h) }
        end
    end
    if tonumber(d._ver) ~= 2 then
        winStates.cmp, winStates.cart = nil, nil
        winDirty, winDirtyT = true, os.clock()
    end
end

local function displaySize()
    local ds = imgui.GetIO().DisplaySize
    local sw, sh = getScreenResolution()
    return (ds.x > 0 and ds.x or sw), (ds.y > 0 and ds.y or sh)
end

local function stateFits(st, dw, dh)
    return st and st.w >= S(220) and st.h >= S(160) and st.w <= dw and st.h <= dh
        and st.x >= 0 and st.y >= 0 and st.x <= dw - S(80) and st.y <= dh - S(80)
end

local function placeWindow(key, defW, defH, off)
    local dw, dh = displaySize()
    local st = winStates[key]
    local useSaved = not winChecked[key] and stateFits(st, dw, dh)
    local w, h = math.min(defW, dw * 0.94), math.min(defH, dh * 0.88)
    local force = winForce[key]
    if force then
        imgui.SetNextWindowSize(ImVec2(force.w, force.h), imgui.Cond.Always)
        winForce[key] = nil
    elseif useSaved then
        imgui.SetNextWindowSize(ImVec2(st.w, st.h), imgui.Cond.FirstUseEver)
    else
        imgui.SetNextWindowSize(ImVec2(w, h), imgui.Cond.FirstUseEver)
    end
    if pendingPos[key] then
        imgui.SetNextWindowPos(pendingPos[key], imgui.Cond.Always)
        pendingPos[key] = nil
    elseif useSaved then
        imgui.SetNextWindowPos(ImVec2(st.x, st.y), imgui.Cond.FirstUseEver)
    else
        local shift = (off or 0) * S(36)
        imgui.SetNextWindowPos(ImVec2((dw - w) / 2 + shift, (dh - h) / 2 + shift), imgui.Cond.FirstUseEver)
    end
end

local function trackWindow(key)
    local dw, dh = displaySize()
    local wp, wsz = imgui.GetWindowPos(), imgui.GetWindowSize()
    if not winChecked[key] then
        winChecked[key] = true
        if wp.y < 0 or wp.x < 0 or wp.y + wsz.y > dh + 1 or wp.x + wsz.x > dw + 1 then
            pendingPos[key] = ImVec2(math.max(0, math.min(wp.x, dw - wsz.x)), math.max(0, math.min(wp.y, dh - wsz.y)))
        end
    end
    local st = winStates[key]
    if not st or math.abs(wp.x - st.x) > 1 or math.abs(wp.y - st.y) > 1
        or math.abs(wsz.x - st.w) > 1 or math.abs(wsz.y - st.h) > 1 then
        winStates[key] = { x = math.floor(wp.x), y = math.floor(wp.y), w = math.floor(wsz.x), h = math.floor(wsz.y) }
        winDirty = true
        winDirtyT = os.clock()
    end
end

local function sizeButtonsInline(key) end

local function sizeButtonsRow(key) end

local mini = {
    mods   = { open = new.bool(false), title = 'Проценты', w = 380, h = 500, off = 0 },
    cmp    = { open = new.bool(false), title = 'Сравнение', w = 470, h = 380, off = 1 },
    cart   = { open = new.bool(false), title = 'Закупки', w = 400, h = 400, off = 2 },
    custom = { open = new.bool(false), title = 'Свой процент', w = 400, h = 340, off = 0, center = true },
    inv    = { open = new.bool(false), title = 'Инвентарь', w = 400, h = 480, off = 3 },
    tutorial = { open = new.bool(false), title = 'Знакомство с Craft Helper', w = 300, h = 280, off = 0, center = true, noshow = true },
}

do
local STATE_VER = 1

local function cleanItem(it)
    if type(it) ~= 'table' then return nil end
    local out = {}
    for k, v in pairs(it) do
        local tv = type(v)
        if tv == 'string' or tv == 'number' or tv == 'boolean' then
            out[k] = v
        elseif k == 'needsList' and tv == 'table' then
            local list = {}
            for _, n in ipairs(v) do
                if type(n) == 'table' then
                    local e = {}
                    for nk, nv in pairs(n) do
                        local tn = type(nv)
                        if tn == 'string' or tn == 'number' or tn == 'boolean' then e[nk] = nv end
                    end
                    list[#list + 1] = e
                end
            end
            out[k] = list
        end
    end
    return out
end

local function relinkItem(snap, cat)
    if type(snap) ~= 'table' then return nil end
    local function look(list)
        if type(list) ~= 'table' then return nil end
        for _, it in ipairs(list) do
            if snap.id ~= nil and it.id == snap.id then return it end
        end
    end
    local r = look(scanned[cat])
    if r then return r end
    for _, list in pairs(scanned) do
        r = look(list)
        if r then return r end
    end
    if snap.id == nil and snap.name then
        for _, list in pairs(scanned) do
            for _, it in ipairs(list) do
                if it.name == snap.name then return it end
            end
        end
    end
    return snap
end

local function buildState()
    local s = { ver = STATE_VER, menuOpen = menuOpen[0] == true, open = {}, cart = {}, compare = {} }
    for k, m in pairs(mini) do
        if not m.noshow then s.open[k] = m.open[0] == true end
    end
    for _, e in ipairs(cart) do
        local it = cleanItem(e.it)
        if it then s.cart[#s.cart + 1] = { it = it, qty = e.qty } end
    end
    for _, e in ipairs(compareItems) do
        local it = cleanItem(e.it)
        if it then s.compare[#s.compare + 1] = { it = it, cat = e.cat } end
    end
    local detailId
    if detailCat and detailItem and scanned[detailCat] and scanned[detailCat][detailItem] then
        detailId = scanned[detailCat][detailItem].id
    end
    s.view = { cat = viewCat, detailCat = detailCat, detailItem = detailItem, detailId = detailId, attempts = attempts }
    s.filter = { chanceIdx = filterState.chanceIdx, costIdx = filterState.costIdx, craft = filterState.craft == true }
    s.sort = { mode = sortMode, desc = sortDesc == true }
    s.search = ffi.string(searchQuery)
    return s
end

function store.saveState(force)
    if not store.statePath or not encodeJson then return end
    local ok, j = pcall(function() return encodeJson(buildState()) end)
    if not ok or not j then return end
    if not force and j == store.stateLast then return end
    local f = io.open(store.statePath, 'w')
    if f then
        f:write(j)
        f:close()
        store.stateLast = j
    end
end

function store.loadState()
    if not store.statePath or not decodeJson then return end
    local f = io.open(store.statePath, 'r')
    if f then
        local text = f:read('*a') or ''
        f:close()
        local ok, d = pcall(decodeJson, text)
        if ok and type(d) == 'table' then
            if type(d.cart) == 'table' then
                cart = {}
                for _, e in ipairs(d.cart) do
                    local qty = tonumber(type(e) == 'table' and e.qty)
                    if qty and qty >= 1 then
                        local it = relinkItem(e.it, nil)
                        if it then cart[#cart + 1] = { it = it, qty = math.min(999, math.floor(qty)) } end
                    end
                end
            end
            if type(d.compare) == 'table' then
                compareItems = {}
                for _, e in ipairs(d.compare) do
                    if type(e) == 'table' then
                        local cat = tonumber(e.cat)
                        local it = relinkItem(e.it, cat)
                        if it then compareItems[#compareItems + 1] = { it = it, cat = cat } end
                    end
                end
            end
            if type(d.open) == 'table' then
                for k, m in pairs(mini) do
                    if not m.noshow and d.open[k] ~= nil then m.open[0] = d.open[k] == true end
                end
            end
            if d.menuOpen ~= nil then menuOpen[0] = d.menuOpen == true end
            if type(d.view) == 'table' then
                local vc = d.view.cat
                if type(vc) == 'string' and (vc == 'cust' or vc == 'all' or vc == 'fav') then
                    viewCat = vc
                elseif tonumber(vc) and scanned[tonumber(vc)] ~= nil then
                    viewCat = tonumber(vc)
                end
                local dc, di = tonumber(d.view.detailCat), tonumber(d.view.detailItem)
                if dc and di and scanned[dc] and scanned[dc][di] and scanned[dc][di].id == d.view.detailId then
                    detailCat, detailItem = dc, di
                end
                local at = tonumber(d.view.attempts)
                if at then attempts = math.max(1, math.min(999, math.floor(at))) end
            end
            if type(d.filter) == 'table' then
                local ci, co = tonumber(d.filter.chanceIdx), tonumber(d.filter.costIdx)
                if ci and filterState.chanceSteps[ci] then filterState.chanceIdx = ci end
                if co and filterState.costSteps[co] then filterState.costIdx = co end
                filterState.craft = d.filter.craft == true
            end
            if type(d.sort) == 'table' then
                sortMode = tonumber(d.sort.mode) or 0
                sortDesc = d.sort.desc == true
            end
            if type(d.search) == 'string' and #d.search > 0 and #d.search < 255 then
                ffi.copy(searchQuery, d.search)
            end
        end
    end
    local ok, j = pcall(function() return encodeJson(buildState()) end)
    if ok then store.stateLast = j end
end
end

local tut = {
    stage = 'read', page = 1, q = 1, picked = nil, score = 0, wrong = {}, saved = false,
    pages = 9,
    quiz = {
        { q = 'Как открыть меню Craft Helper?',
          options = { 'Кнопкой в настройках игры', 'Командой /crh', 'Через /menu' },
          correct = 2, why = 'Меню открывается командой /crh в чате. Других команд у скрипта нет.' },
        { q = 'Что означает запись 6/12 у ресурса?',
          options = { 'Нужно 6, а у тебя есть 12', 'Нужно 12, а у тебя есть 6', 'Шанс 6 из 12' },
          correct = 1, why = 'Первое число это сколько нужно, второе сколько есть в инвентаре. Зеленый цвет значит хватает, красный не хватает.' },
        { q = 'Какой командой открывается меню?',
          options = { '/craft', '/menu', '/crh' },
          correct = 3, why = 'Меню открывается командой /crh. Других команд у скрипта нет.' },
        { q = 'Что делает кнопка Скан?',
          options = { 'Покупает ресурсы на рынке', 'Читает рецепты из открытого верстака', 'Крафтит выбранный предмет' },
          correct = 2, why = 'Нажми Скан, открой верстак, и скрипт сам пролистает все вкладки и запомнит рецепты.' },
    },
}

local uiBufs = {}

local function uiSliderF(label, key, mn, mx, fmt)
    local b = uiBufs[key]
    if not b then b = new.float(0) uiBufs[key] = b end
    b[0] = ui[key]
    imgui.TextDisabled(u8(label))
    imgui.PushItemWidth(-1)
    if imgui.SliderFloat('##ui_' .. key, b, mn, mx, fmt or '%.1f') then
        ui[key] = b[0]
        applyUI()
        store.saveSettings()
    end
    imgui.PopItemWidth()
end

local function uiSliderI(label, key, mn, mx)
    local b = uiBufs[key]
    if not b then b = new.int(0) uiBufs[key] = b end
    b[0] = math.floor(ui[key] + 0.5)
    imgui.TextDisabled(u8(label))
    imgui.PushItemWidth(-1)
    if imgui.SliderInt('##ui_' .. key, b, mn, mx) then
        ui[key] = b[0]
        applyUI()
        store.saveSettings()
    end
    imgui.PopItemWidth()
end

local function uiSection(icon, text)
    imgui.Spacing()
    imgui.TextColored(ACCENT, ico(icon) .. ' ' .. u8(text))
    imgui.Separator()
end

local function drawUiPreview(w, h)
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    imgui.Dummy(ImVec2(w, h))
    local mul = ui.compact and 0.72 or 1.0
    local fscale = 1.0
    local function U32(r,g,b,a) return imgui.GetColorU32Vec4(ImVec4(r/255,g/255,b/255,a or 1)) end
    local function RF(x0,y0,x1,y1,col,round) dl:AddRectFilled(ImVec2(pos.x+x0,pos.y+y0),ImVec2(pos.x+x1,pos.y+y1),col,round or 0) end
    local function RR(x0,y0,x1,y1,col,round,th) dl:AddRect(ImVec2(pos.x+x0,pos.y+y0),ImVec2(pos.x+x1,pos.y+y1),col,round or 0,0,th or 1) end
    RF(0,0,w,h,U32(18,26,28),ui.w_round)
    if ui.w_border>0 then RR(0,0,w,h,U32(45,212,191,0.28),ui.w_round,ui.w_border) end
    local tb = 18*mul
    RF(ui.w_border,ui.w_border,w-ui.w_border,tb,U32(16,30,32),ui.w_round)
    dl:AddText(ImVec2(pos.x+ui.wpad_x*mul,pos.y+tb*0.18),U32(240,252,250),u8'Craft Helper')
    local cx, cy = ui.wpad_x*mul, tb+ui.wpad_y*mul
    local cw = w-ui.wpad_x*mul*2
    local fpx, fpy = ui.fpad_x*mul, ui.fpad_y*mul
    local ispy = ui.isp_y*mul
    local fh = imgui.GetTextLineHeight() + fpy*2
    RF(cx,cy,cx+cw*0.6,cy+fh,U32(32,48,51),ui.f_round)
    dl:AddText(ImVec2(pos.x+cx+fpx,pos.y+cy+fpy),U32(240,252,250),u8'Кнопка')
    cy = cy + fh + ispy
    RF(cx,cy,cx+cw*0.75,cy+fh,U32(28,40,42),ui.f_round)
    dl:AddText(ImVec2(pos.x+cx+fpx,pos.y+cy+fpy),U32(110,135,138),u8'поле ввода')
    cy = cy + fh + ispy
    local bx = fh*0.8
    RR(cx,cy,cx+bx,cy+bx,U32(45,212,191,0.6),ui.f_round,1.2)
    dl:AddText(ImVec2(pos.x+cx+bx+ui.iisp_x*mul,pos.y+cy+(bx-imgui.GetTextLineHeight())/2),U32(240,252,250),u8'чекбокс')
    cy = cy + bx + ispy
    RF(cx,cy,cx+cw*0.7,cy+fh*0.4,U32(28,40,42),ui.f_round)
    RF(cx,cy,cx+cw*0.45,cy+fh*0.4,U32(45,212,191,0.6),ui.f_round)
    cy = cy + fh*0.4 + ispy
    dl:AddText(ImVec2(pos.x+cx,pos.y+cy+fpy),U32(240,252,250),u8'текст строки')
    cy = cy + fh + ispy
    local chh = h - cy - ui.wpad_y*mul
    if chh > 12 then
        RF(cx,cy,cx+cw,cy+chh,U32(22,32,34),ui.c_round)
        if ui.c_border>0 then RR(cx,cy,cx+cw,cy+chh,U32(45,212,191,0.28),ui.c_round,ui.c_border) end
        local sbw = ui.scrollbar_size*mul
        RF(cx+cw-sbw,cy+2,cx+cw-2,cy+chh-2,U32(0,0,0,0.2),ui.s_round)
        local gsize = math.max(ui.grab_min*mul,chh*0.3)
        RF(cx+cw-sbw+1,cy+4,cx+cw-3,cy+4+gsize,U32(60,80,84),ui.s_round)
    end
end

do
    local okBit, bit = pcall(require, 'bit')
    local ICONS_URL = 'https://files.catbox.moe/e95his.zip'
    local dl = { busy = false, text = '', frac = 0 }
    store.iconDl = dl

    local UA = 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36'

    local function httpGet(url)
        local okC, copas = pcall(require, 'copas')
        local okH, chttp = pcall(require, 'copas.http')
        local okL, ltn12 = pcall(require, 'ltn12')
        if okC and okH and okL and copas.addthread then
            local chunks, got, done = {}, 0, nil
            local function sink(chunk)
                if chunk then
                    chunks[#chunks + 1] = chunk
                    got = got + #chunk
                    dl.short = 'Картинки ' .. math.floor(got / 1024) .. ' КБ'
                    dl.text = 'Скачиваю: ' .. math.floor(got / 1024) .. ' КБ'
                end
                return 1
            end
            copas.addthread(function()
                local ok, r1, code, _, status = pcall(chttp.request, {
                    url = url, method = 'GET', sink = sink,
                    headers = { ['user-agent'] = UA, ['accept'] = '*/*' },
                    timeout = { connect = 30, send = 30, receive = 60 },
                })
                done = { ok = ok, r1 = r1, code = code, status = status }
            end)
            local t0 = os.clock()
            while not done do
                if copas.step then pcall(copas.step, 0.05) end
                wait(0)
                if os.clock() - t0 > 240 then return nil, 'time out' end
            end
            if not done.ok then return nil, tostring(done.r1) end
            if not done.r1 then return nil, tostring(done.code) end
            if tonumber(done.code) ~= 200 then return nil, 'HTTP ' .. tostring(done.code) end
            return table.concat(chunks)
        end
        local okS, https = pcall(require, 'ssl.https')
        if not okS or not okL then return nil, 'нет ssl.https' end
        pcall(function() require('socket.http').TIMEOUT = 120 end)
        local resp = {}
        local r1, code = https.request({ url = url, method = 'GET', sink = ltn12.sink.table(resp), headers = { ['user-agent'] = UA } })
        if not r1 then return nil, tostring(code) end
        if tonumber(code) ~= 200 then return nil, 'HTTP ' .. tostring(code) end
        return table.concat(resp)
    end

    local function u16(s, p)
        local a, b = s:byte(p, p + 1)
        return a + b * 256
    end

    local function u32(s, p)
        local a, b, c, d = s:byte(p, p + 3)
        return a + b * 256 + c * 65536 + d * 16777216
    end

    local LBASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
    local LEXT = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
    local DBASE = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 }
    local DEXT = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
    local CLORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

    local function build(lengths, n)
        local count, symbol, offs = {}, {}, {}
        for i = 0, 15 do count[i] = 0 end
        for i = 0, n - 1 do count[lengths[i]] = count[lengths[i]] + 1 end
        offs[1] = 0
        for i = 1, 14 do offs[i + 1] = offs[i] + count[i] end
        for i = 0, n - 1 do
            local l = lengths[i]
            if l ~= 0 then
                symbol[offs[l]] = i
                offs[l] = offs[l] + 1
            end
        end
        return { count = count, symbol = symbol }
    end

    local function inflate(data, startPos, expected)
        local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift
        local byte = string.byte
        local pos, bitbuf, bitcnt = startPos, 0, 0
        local out, outn, tick = {}, 0, 0

        local function bits(n)
            while bitcnt < n do
                local b = byte(data, pos)
                if not b then error('eof') end
                pos = pos + 1
                bitbuf = bor(bitbuf, lshift(b, bitcnt))
                bitcnt = bitcnt + 8
            end
            local v = band(bitbuf, lshift(1, n) - 1)
            bitbuf = rshift(bitbuf, n)
            bitcnt = bitcnt - n
            return v
        end

        local function decode(h)
            local code, first, index = 0, 0, 0
            for len = 1, 15 do
                code = bor(code, bits(1))
                local cnt = h.count[len]
                if code - cnt < first then return h.symbol[index + (code - first)] end
                index = index + cnt
                first = (first + cnt) * 2
                code = code * 2
            end
            error('bad code')
        end

        local function codes(lh, dh)
            while true do
                local sym = decode(lh)
                if sym < 256 then
                    outn = outn + 1
                    out[outn] = sym
                elseif sym == 256 then
                    return
                else
                    sym = sym - 257
                    if sym >= 29 then error('bad length') end
                    local len = LBASE[sym + 1] + bits(LEXT[sym + 1])
                    local ds = decode(dh)
                    if ds >= 30 then error('bad distance') end
                    local dist = DBASE[ds + 1] + bits(DEXT[ds + 1])
                    if dist > outn then error('distance too far') end
                    for _ = 1, len do
                        outn = outn + 1
                        out[outn] = out[outn - dist]
                    end
                end
                if outn - tick > 30000 then
                    tick = outn
                    if expected and outn > expected then error('overflow') end
                    wait(0)
                end
            end
        end

        local fixedL, fixedD
        repeat
            local final = bits(1)
            local typ = bits(2)
            if typ == 0 then
                bitbuf, bitcnt = 0, 0
                local len = byte(data, pos) + byte(data, pos + 1) * 256
                local nlen = byte(data, pos + 2) + byte(data, pos + 3) * 256
                if band(bit.bnot(nlen), 0xFFFF) ~= len then error('stored length') end
                pos = pos + 4
                if pos + len - 1 > #data then error('eof') end
                for i = 0, len - 1 do
                    outn = outn + 1
                    out[outn] = byte(data, pos + i)
                end
                pos = pos + len
            elseif typ == 1 then
                if not fixedL then
                    local l, d = {}, {}
                    for i = 0, 143 do l[i] = 8 end
                    for i = 144, 255 do l[i] = 9 end
                    for i = 256, 279 do l[i] = 7 end
                    for i = 280, 287 do l[i] = 8 end
                    for i = 0, 29 do d[i] = 5 end
                    fixedL, fixedD = build(l, 288), build(d, 30)
                end
                codes(fixedL, fixedD)
            elseif typ == 2 then
                local nlen = bits(5) + 257
                local ndist = bits(5) + 1
                local ncode = bits(4) + 4
                if nlen > 286 or ndist > 30 then error('bad counts') end
                local lengths = {}
                for i = 0, 18 do lengths[i] = 0 end
                for i = 1, ncode do lengths[CLORDER[i]] = bits(3) end
                local lencode = build(lengths, 19)
                local ll = {}
                for i = 0, nlen + ndist - 1 do ll[i] = 0 end
                local idx = 0
                while idx < nlen + ndist do
                    local sym = decode(lencode)
                    if sym < 16 then
                        ll[idx] = sym
                        idx = idx + 1
                    else
                        local prev, rep = 0, 0
                        if sym == 16 then
                            if idx == 0 then error('bad repeat') end
                            prev = ll[idx - 1]
                            rep = 3 + bits(2)
                        elseif sym == 17 then
                            rep = 3 + bits(3)
                        else
                            rep = 11 + bits(7)
                        end
                        if idx + rep > nlen + ndist then error('bad repeat') end
                        for _ = 1, rep do
                            ll[idx] = prev
                            idx = idx + 1
                        end
                    end
                end
                local lt, dt = {}, {}
                for i = 0, nlen - 1 do lt[i] = ll[i] end
                for i = 0, ndist - 1 do dt[i] = ll[nlen + i] end
                codes(build(lt, nlen), build(dt, ndist))
            else
                error('bad block')
            end
        until final == 1

        local parts = {}
        for i = 1, outn, 4000 do
            parts[#parts + 1] = string.char(unpack(out, i, math.min(i + 3999, outn)))
        end
        return table.concat(parts)
    end

    local function readZip(data)
        local eocd
        for p = #data - 21, math.max(1, #data - 65557), -1 do
            if data:sub(p, p + 3) == 'PK\5\6' then
                eocd = p
                break
            end
        end
        if not eocd then return nil end
        local total = u16(data, eocd + 10)
        local p = u32(data, eocd + 16) + 1
        local list = {}
        for _ = 1, total do
            if data:sub(p, p + 3) ~= 'PK\1\2' then break end
            local nlen, elen, clen = u16(data, p + 28), u16(data, p + 30), u16(data, p + 32)
            list[#list + 1] = {
                flags = u16(data, p + 8),
                method = u16(data, p + 10),
                csize = u32(data, p + 20),
                usize = u32(data, p + 24),
                lho = u32(data, p + 42),
                name = data:sub(p + 46, p + 45 + nlen),
            }
            p = p + 46 + nlen + elen + clen
        end
        return list
    end

    local PNG_SIG = '\137PNG\r\n\26\n'

    function store.downloadIcons()
        if dl.busy then return end
        if not okBit then
            dl.text = 'Ошибка: нет библиотеки bit'
            return
        end
        dl.busy, dl.frac, dl.text, dl.short = true, 0, 'Скачивание...', 'Картинки...'
        lua_thread.create(function()
            local written = 0
            local ok, err = pcall(function()
                if not iconDir then error('нет папки для картинок', 0) end
                if not doesDirectoryExist(iconDir) then createDirectory(iconDir) end
                local localZip = craftDir and (craftDir .. '/icons.zip')
                local lf = localZip and io.open(localZip, 'rb')
                if not lf then
                    if downloadUrlToFile then
                        dl.text = 'Скачиваю архив...'
                        local dlDone = false
                        local dlOk = false
                        downloadUrlToFile(ICONS_URL, localZip, function(id, status, p1, p2)
                            if status == 5 then
                                dl.short = 'Картинки ' .. math.floor(p1 / 1024) .. ' КБ'
                                dl.text = 'Скачиваю: ' .. math.floor(p1 / 1024) .. ' КБ'
                                if p2 > 0 then dl.frac = p1 / p2 end
                            elseif status == 6 or status == 58 then
                                dlDone = true
                                dlOk = true
                            elseif status == -1 then
                                dlDone = true
                                dlOk = false
                            end
                        end)
                        local t0 = os.clock()
                        while not dlDone do
                            wait(50)
                            if os.clock() - t0 > 240 then
                                error('Таймаут скачивания архива', 0)
                            end
                        end
                        if not dlOk then
                            error('Не удалось скачать архив с картинками', 0)
                        end
                    else
                        local data, e
                        for attempt = 1, 3 do
                            data, e = httpGet(ICONS_URL)
                            if data then break end
                            if attempt < 3 then
                                dl.text = 'Ошибка: ' .. tostring(e) .. ', повтор ' .. attempt .. '/2'
                                wait(2000)
                            end
                        end
                        if not data then error(tostring(e), 0) end
                        local f = io.open(localZip, 'wb')
                        if f then f:write(data) f:close() end
                    end
                    lf = io.open(localZip, 'rb')
                end

                dl.text = 'Распаковка архива...'
                dl.short = 'Картинки 0%'

                local unzipOk = false
                pcall(function()
                    if doesFileExist(localZip) then
                        local cmd = string.format('/system/bin/unzip -q -o "%s" -d "%s"', localZip, iconDir)
                        local res = os.execute(cmd)
                        if res == 0 or res == true then
                            unzipOk = true
                        end
                    end
                end)

                if unzipOk then
                    pcall(function()
                        local okLfs, lfs = pcall(require, 'lfs')
                        if okLfs and lfs and lfs.dir then
                            for fname in lfs.dir(iconDir) do
                                if fname:lower():match('%.png$') then
                                    written = written + 1
                                end
                            end
                        end
                    end)
                    if written == 0 then written = 100 end
                else
                    local data = lf and lf:read('*a')
                    if lf then lf:close() lf = nil end
                    if not data or data:sub(1, 2) ~= 'PK' then error('файл не является zip', 0) end
                    local list = readZip(data)
                    if not list or #list == 0 then error('не удалось прочитать архив', 0) end
                    for i, ent in ipairs(list) do
                        dl.frac = i / #list
                        dl.short = 'Картинки ' .. math.floor(dl.frac * 100) .. '%'
                        local base = ent.name:match('([^/\\]+)$')
                        local plain = ent.flags % 2 == 0 and ent.csize < 0xFFFFFFFF and ent.usize < 0xFFFFFFFF and ent.lho < 0xFFFFFFFF
                        if base and plain and base:lower():match('%.png$') and base:match('^[%w_%-%.]+$') and not base:find('..', 1, true) then
                            local lp = ent.lho + 1
                            if data:sub(lp, lp + 3) == 'PK\3\4' then
                                local start = lp + 30 + u16(data, lp + 26) + u16(data, lp + 28)
                                local raw
                                if ent.method == 0 then
                                    raw = data:sub(start, start + ent.csize - 1)
                                elseif ent.method == 8 then
                                    local okI, res = pcall(inflate, data, start, ent.usize)
                                    if okI then raw = res end
                                end
                                if raw and #raw == ent.usize and raw:sub(1, 8) == PNG_SIG then
                                    local f = io.open(iconDir .. '/' .. base, 'wb')
                                    if f then
                                        f:write(raw)
                                        f:close()
                                        written = written + 1
                                    end
                                end
                            end
                        end
                        wait(0)
                    end
                end
                if lf then pcall(function() lf:close() end) end
            end)
            dl.busy = false
            if not ok then
                dl.text = 'Ошибка: ' .. tostring(err)
                chatLog('Картинки не скачались: ' .. tostring(err))
                pcall(setClipboardText, ICONS_URL)
                chatLog('чтобы были картинки, скачайте файл отсюда - ' .. ICONS_URL .. ' и распакуйте в ' .. iconDir)
            elseif written == 0 then
                dl.text = 'В архиве нет подходящих png'
                chatLog('В архиве не нашлось картинок')
            else
                dl.text = 'Готово, картинок: ' .. written
                dl.short = 'Картинки'
                iconMiss = {}
                chatLog('Картинки скачаны и распакованы: ' .. written)
            end
        end)
    end
end

local function drawCustomizeContent()
    local cb = uiBufs._compact
    if not cb then cb = new.bool(false) uiBufs._compact = cb end
    cb[0] = ui.compact
    if imgui.Checkbox(u8'Компактный режим##uicompact', cb) then
        ui.compact = cb[0]
        applyUI()
        store.saveSettings()
    end
    imgui.TextDisabled(u8'Меньше отступы и размер элементов')

    uiSection('SQUARE', 'Скругления')
    uiSliderI('Окно', 'w_round', 0, 40)
    uiSliderI('Child', 'c_round', 0, 40)
    uiSliderI('Рамки/кнопки', 'f_round', 0, 40)
    uiSliderI('Popup', 'p_round', 0, 40)
    uiSliderI('Скроллбар', 's_round', 0, 40)
    uiSliderI('Grab', 'g_round', 0, 40)

    uiSection('BORDER_ALL', 'Границы')
    uiSliderI('Граница окна', 'w_border', 0, 5)
    uiSliderI('Граница child', 'c_border', 0, 5)

    uiSection('RULER', 'Отступы')
    uiSliderI('Окно X', 'wpad_x', 0, 40)
    uiSliderI('Окно Y', 'wpad_y', 0, 40)
    uiSliderI('Поле X', 'fpad_x', 0, 40)
    uiSliderI('Поле Y', 'fpad_y', 0, 30)
    uiSliderI('Элементы X', 'isp_x', 0, 30)
    uiSliderI('Элементы Y', 'isp_y', 0, 30)
    uiSliderI('Внутренние X', 'iisp_x', 0, 20)
    uiSliderI('Внутренние Y', 'iisp_y', 0, 20)
    uiSliderI('Отступ indent', 'indent', 0, 60)

    uiSection('SCROLL', 'Скроллбар')
    uiSliderI('Толщина', 'scrollbar_size', 4, 40)
    uiSliderI('Мин. grab', 'grab_min', 4, 40)

    uiSection('TEXT_HEIGHT', 'Размер текста и элементов')
    uiSliderF('Общий масштаб', 'font_scale', 0.5, 2.0, 'x%.2f')

    imgui.Spacing()
    if imgui.Button(ico('ROTATE') .. ' ' .. u8'Сбросить все##uireset', ImVec2(-1, btnH(1.3))) then
        for k, v in pairs(uiDefaults) do ui[k] = v end
        applyUI()
        store.saveSettings()
    end
    if imgui.Button(ico('COPY') .. ' ' .. u8'Скопировать в буфер##uicopy', ImVec2(-1, btnH(1.3))) then
        local order = { 'compact','font_scale','w_round','c_round','f_round','p_round','s_round','g_round',
            'w_border','c_border','scrollbar_size','grab_min','wpad_x','wpad_y','fpad_x','fpad_y',
            'isp_x','isp_y','iisp_x','iisp_y','indent' }
        local lines = {}
        for _, k in ipairs(order) do lines[#lines + 1] = k .. ' = ' .. tostring(ui[k]) end
        pcall(setClipboardText, table.concat(lines, '\n'))
        chatLog('Настройки кастомизации скопированы в буфер')
    end
end

local function drawMini(key, contentFn)
    local m = mini[key]
    if not m.open[0] then
        m.prev = false
        return
    end
    if m.center and not m.prev then
        local dw, dh = displaySize()
        local st = winStates[key]
        local w = st and st.w or S(m.w)
        local h = st and st.h or S(m.h)
        if m.noshow then
            w, h = S(m.w), S(m.h)
        end
        pendingPos[key] = ImVec2(math.max(0, (dw - w) / 2), math.max(0, (dh - h) / 2))
        if m.noshow then
            imgui.SetNextWindowSize(ImVec2(w, h), imgui.Cond.Always)
        end
    end
    m.prev = true
    placeWindow(key, S(m.w), S(m.h), m.off)
    imgui.Begin(u8(m.title) .. '##mini_' .. key, m.noshow and nil or m.open, imgui.WindowFlags.NoCollapse)
    trackWindow(key)
    contentFn()
    imgui.End()
end

local flowState = { used = 0, avail = 0 }

local function flowBegin()
    flowState.used = 0
    flowState.avail = imgui.GetContentRegionAvail().x
end

local function flowButton(label, active, id)
    local style = imgui.GetStyle()
    local text = u8(label)
    local w = imgui.CalcTextSize(text).x + style.FramePadding.x * 2 + 2
    if flowState.used > 0 then
        if flowState.used + style.ItemSpacing.x + w <= flowState.avail then
            imgui.SameLine()
            flowState.used = flowState.used + style.ItemSpacing.x
        else
            flowState.used = 0
        end
    end
    if active then imgui.PushStyleColor(imgui.Col.Button, COLOR_GREEN) end
    local clicked = imgui.Button(text .. '##' .. id, ImVec2(w, btnH(1.15)))
    if active then imgui.PopStyleColor() end
    flowState.used = flowState.used + w
    return clicked
end

local function drawModsContent()
    sizeButtonsRow('mods')
    imgui.Separator()
    imgui.TextDisabled(u8'ШАНС КРАФТА')
    flowBegin()
    if flowButton('VIP x2', mods.vipX2, 'vipx2') then mods.vipX2 = not mods.vipX2; store.saveMods() end
    if flowButton('VIP +2%', mods.vipPlus2, 'vipp2') then mods.vipPlus2 = not mods.vipPlus2; store.saveMods() end

    imgui.TextDisabled(u8'БАФЫ')
    flowBegin()
    for _, b in ipairs(MOD_BUFFS) do
        if flowButton(b.label, mods.buffs[b.key], 'buff' .. b.key) then
            mods.buffs[b.key] = not mods.buffs[b.key]
            store.saveMods()
        end
    end

    imgui.TextDisabled(u8'ОХРАННИК: экономия ресурсов')
    flowBegin()
    for _, t in ipairs(GUARD_TIERS) do
        if flowButton('-' .. t .. '%', mods.guardTier == t, 'gt' .. t) then
            mods.guardTier = (mods.guardTier == t) and 0 or t
            store.saveMods()
        end
    end

    imgui.TextDisabled(u8'ОХРАННИК: время и цена')
    flowBegin()
    for _, t in ipairs(GUARD_TIMES) do
        if flowButton('-' .. t .. 'сек', mods.guardTime == t, 'gs' .. t) then
            mods.guardTime = (mods.guardTime == t) and 0 or t
            store.saveMods()
        end
    end
    if flowButton('Цена -6%', mods.guardPrice, 'gp6') then mods.guardPrice = not mods.guardPrice; store.saveMods() end

    imgui.Separator()
    imgui.TextDisabled(u8'СВОИ')
    local style = imgui.GetStyle()
    local rowH = btnH(1.2)
    local removeAt
    for i, cm in ipairs(customMods) do
        local w = imgui.GetContentRegionAvail().x - rowH * 1.3 - style.ItemSpacing.x
        if cm.on then imgui.PushStyleColor(imgui.Col.Button, COLOR_GREEN) end
        if imgui.Button(u8(customLabel(cm)) .. '##cm' .. i, ImVec2(w, rowH)) then
            cm.on = not cm.on
            store.saveCustomMods()
        end
        if cm.on then imgui.PopStyleColor() end
        imgui.SameLine()
        if imgui.Button('X##cmx' .. i, ImVec2(rowH * 1.3, rowH)) then removeAt = i end
    end
    if removeAt then
        table.remove(customMods, removeAt)
        store.saveCustomMods()
    end
    if imgui.Button(ico('PLUS') .. ' ' .. u8'Добавить свое##addcustom', ImVec2(-1, btnH(1.3))) then
        mini.custom.open[0] = true
    end
    if imgui.Button(ico('ROTATE_LEFT') .. ' ' .. u8'Сбросить все##modsreset', ImVec2(-1, btnH(1.2))) then
        mods = { vipX2 = false, vipPlus2 = false, buffs = {}, guardTier = 0, guardTime = 0, guardPrice = false }
        for _, cm in ipairs(customMods) do cm.on = false end
        store.saveMods()
        store.saveCustomMods()
    end
end

local customName = ffi.new('char[?]', 64)
local customValue = new.float(5)
local customKind = new.int(0)
local customError = ''
local customKindItems = ''
do
    local parts = {}
    for _, label in ipairs(CUSTOM_KIND_LABELS) do parts[#parts + 1] = u8(label) end
    customKindItems = table.concat(parts, '\0') .. '\0\0'
end

local function drawCustomContent()
    sizeButtonsRow('custom')
    imgui.Separator()
    imgui.TextDisabled(u8'Название')
    imgui.PushItemWidth(-1)
    imgui.InputTextWithHint('##cname', u8'Например: Мой бафф', customName, 64)
    imgui.PopItemWidth()
    imgui.TextDisabled(u8'Число')
    imgui.PushItemWidth(-1)
    imgui.InputFloat('##cval', customValue, 0, 0, '%.2f')
    imgui.PopItemWidth()
    imgui.TextDisabled(u8'Что меняет процент')
    imgui.PushItemWidth(-1)
    imgui.ComboStr('##ckind', customKind, customKindItems)
    imgui.PopItemWidth()
    if customError ~= '' then imgui.TextColored(COLOR_BAD, u8(customError)) end
    imgui.Separator()
    local act = buttonRow({
        { id = 'cadd', label = ico('PLUS') .. ' ' .. u8'Добавить', color = COLOR_GREEN },
        { id = 'ccancel', label = u8'Отмена' },
    }, btnH(1.3))
    if act == 'cadd' then
        local name = trim(readBuf(customName))
        local value = customValue[0]
        if name == '' then
            customError = 'Укажи название'
        elseif value <= 0 then
            customError = 'Укажи число больше 0'
        else
            customMods[#customMods + 1] = { name = name, kind = CUSTOM_KINDS[customKind[0] + 1] or CUSTOM_KINDS[1], value = value, on = true }
            store.saveCustomMods()
            ffi.fill(customName, 64)
            customValue[0] = 5
            customError = ''
            mini.custom.open[0] = false
        end
    elseif act == 'ccancel' then
        customError = ''
        mini.custom.open[0] = false
    end
end

local function drawInventoryContent()
    sizeButtonsRow('inv')
    local label = invScan.active and (ico('SPINNER') .. ' ' .. u8'Сканирую...') or (ico('BOXES_STACKED') .. ' ' .. u8'Скан инвентаря')
    if imgui.Button(label .. '##invscan2', ImVec2(-1, btnH(1.3))) then startInventoryScan() end
    autoInvBuf[0] = settings.autoInv
    if imgui.Checkbox(u8'Автопроверка каждые 10 сек##autoinv', autoInvBuf) then
        settings.autoInv = autoInvBuf[0]
        store.saveSettings()
    end
    local list = {}
    for _, e in pairs(inventory.items) do list[#list + 1] = e end
    table.sort(list, function(a, b) return lowerCp(a.name) < lowerCp(b.name) end)
    if inventory.time > 0 then
        imgui.TextDisabled(u8('Обновлено ' .. os.date('%d.%m %H:%M', inventory.time) .. ',  позиций ' .. #list))
    end
    if invScan.status ~= '' then imgui.TextDisabled(u8(invScan.status)) end
    imgui.Separator()
    imgui.BeginChild('##invlist', ImVec2(-1, -1), false)
    local style = imgui.GetStyle()
    local maxW = 0
    for _, e in ipairs(list) do
        local w = imgui.CalcTextSize(tostring(e.qty)).x
        if w > maxW then maxW = w end
    end
    for _, e in ipairs(list) do
        imgui.Text(u8(e.name))
        imgui.SameLine(imgui.GetWindowWidth() - maxW - style.WindowPadding.x - style.ScrollbarSize)
        imgui.TextColored(GOLD, tostring(e.qty))
    end
    if #list == 0 then imgui.TextDisabled(u8'Пусто. Нажми Скан инвентаря') end
    imgui.EndChild()
end

local function drawTutorialContent()
    sizeButtonsRow('tutorial')
    imgui.Separator()
    local style = imgui.GetStyle()
    local navH = btnH(1.3) + style.ItemSpacing.y * 2

    local function para(text)
        imgui.TextWrapped(u8(text))
    end
    local function legend(color, glyph, text)
        imgui.TextColored(color, glyph)
        imgui.SameLine()
        imgui.TextWrapped(u8(text))
    end
    local check = ico('CHECK') ~= '' and ico('CHECK') or 'v'
    local starG = ico('STAR') ~= '' and ico('STAR') or '*'
    local pinG = ico('THUMBTACK') ~= '' and ico('THUMBTACK') or '#'

    if tut.stage == 'read' then
        imgui.TextDisabled(u8('Страница ' .. tut.page .. ' из ' .. tut.pages))
        imgui.ProgressBar(tut.page / tut.pages, ImVec2(-1, math.max(4, imgui.GetTextLineHeight() * 0.4)), '')
        imgui.BeginChild('##tutbody', ImVec2(-1, -navH), false)
        if tut.page == 1 then
            imgui.TextColored(ACCENT, u8'Что это за скрипт')
            para('Craft Helper читает верстак Arizona и запоминает рецепты: шанс, цену и нужные ресурсы. Потом по ним удобно выбирать, что крафтить.')
            para('Меню открывается командой /crh. Все данные скрипт хранит в папке config/craft.')
            para('Любое окно скрипта можно двигать, а размер менять кнопками - и + в правом верхнем углу окна. Положение и размер запоминаются.')
        elseif tut.page == 2 then
            imgui.TextColored(ACCENT, u8'Вкладки и список')
            para('Сверху идут вкладки верстака. Вкладка Все показывает все предметы сразу, Избранное только те, что отмечены звездочкой, Изменения что нашел последний скан.')
            para('В списке три колонки: название, шанс и цена. Кнопки Имя, Шанс и Цена над списком сортируют его.')
            imgui.TextColored(COLOR_OK, '75%')
            imgui.SameLine()
            imgui.TextColored(rgb(250, 204, 21), '45%')
            imgui.SameLine()
            imgui.TextColored(COLOR_BAD, '10%')
            para('Цвет шанса: зеленый если высокий, желтый средний, красный низкий. Цена всегда золотая.')
        elseif tut.page == 3 then
            imgui.TextColored(ACCENT, u8'Значки в строке предмета')
            legend(PIN_COLOR, pinG, ' Закрепить. Закрепленные предметы всегда стоят в списке выше остальных.')
            legend(GOLD, starG, ' Избранное. Предмет попадает во вкладку Избранное.')
            legend(COLOR_OK, check, ' Ресурсов в инвентаре хватает на крафт. Появляется после Скана инвентаря.')
            para('Если значка нет, значит чего-то не хватает или инвентарь еще не сканировали.')
        elseif tut.page == 4 then
            imgui.TextColored(ACCENT, u8'Карточка предмета')
            para('Когда выбираешь предмет, окно делится пополам: слева список, справа карточка. Крестик в карточке закрывает ее, и список снова занимает все окно.')
            para('В карточке есть число попыток с кнопками -10, -1, +1, +10, итоговая цена и шанс получить предмет хотя бы раз.')
            imgui.TextColored(COLOR_OK, '6/12')
            imgui.SameLine()
            imgui.TextColored(COLOR_BAD, '6/2')
            imgui.SameLine()
            imgui.TextColored(GOLD, '6')
            para('Так выглядят ресурсы: первое число сколько нужно, второе сколько есть у тебя. Зеленый значит хватает, красный не хватает. Одно число значит инвентарь еще не сканировали.')
        elseif tut.page == 5 then
            imgui.TextColored(ACCENT, u8'Кнопки сверху')
            legend(COLOR_OK, '>', ' Скан. Открой верстак, скрипт сам пролистает все вкладки и запишет рецепты.')
            legend(COLOR_OK, '>', ' Скан инвентаря. Читает твои предметы через /stats. Это же делается само каждые 10 секунд, если включена автопроверка.')
            legend(COLOR_OK, '>', ' Проценты. VIP, бафы, охранник и свои проценты, которые меняют шанс, цену и ресурсы.')
            legend(COLOR_OK, '>', ' Сравнение. Выбери предметы кнопкой Сравн. в карточке и смотри их рядом.')
            legend(COLOR_OK, '>', ' Закупки. Сумма всех ресурсов по выбранным предметам, ее можно скопировать.')
            legend(COLOR_OK, '>', ' Только новые. При скане пропускать то, что уже запомнено.')
        elseif tut.page == 6 then
            imgui.TextColored(ACCENT, u8'Проценты и модификаторы')
            para('В окне Проценты задаются VIP, бафы и охранник. Они меняют итоговый шанс, цену и расход ресурсов предмета.')
            para('Свои проценты добавляются вручную кнопкой внизу окна Проценты.')
            imgui.TextColored(ACCENT, u8'Сортировка и фильтры')
            para('Над списком кнопки Имя и Шанс сортируют рецепты. Фильтр Шанс отсекает слишком рискованные предметы.')
        elseif tut.page == 7 then
            imgui.TextColored(ACCENT, u8'Сравнение и закупки')
            para('В карточке предмета есть кнопка Сравн. Выбери два и более предмета - откроется окно Сравнение с их параметрами рядом.')
            para('Закупки собирают суммарный список ресурсов по выбранным предметам. Список можно скопировать и вставить в чат.')
        elseif tut.page == 8 then
            imgui.TextColored(ACCENT, u8'Инвентарь и автопроверка')
            para('Кнопка Скан инвентаря читает твои предметы через /stats. Включи автопроверку - тогда инвентарь обновляется сам каждые 10 секунд.')
            para('Зеленая галочка у предмета значит, что ресурсов хватает минимум на одну попытку крафта.')
            imgui.TextColored(ACCENT, u8'Скрытие меню при скане')
            para('В настройках можно включить скрытие окна верстака во время сканирования и выбрать мини-игру для ожидания.')
        else
            imgui.TextColored(ACCENT, u8'С чего начать')
            para('1. Нажми Скан и открой верстак. Подожди, пока скрипт пролистает все вкладки.')
            para('2. Нажми Скан инвентаря или оставь автопроверку включенной.')
            para('3. Выбери предмет и смотри раздел Нужно: зеленые числа значат, что ресурсов хватает.')
            para('4. Добавь нужное в Закупки и скопируй список.')
            para('Дальше короткий опрос из четырех вопросов, чтобы проверить, что все понятно.')
        end
        imgui.EndChild()

        local items = {}
        if tut.page > 1 then items[#items + 1] = { id = 'tutback', label = u8'Назад' } end
        items[#items + 1] = { id = 'tutnext', label = tut.page < tut.pages and u8'Далее' or u8'К опросу', color = COLOR_GREEN }
        local act = buttonRow(items, btnH(1.3))
        if act == 'tutback' then
            tut.page = tut.page - 1
        elseif act == 'tutnext' then
            if tut.page < tut.pages then
                tut.page = tut.page + 1
            else
                tut.stage = 'quiz'
                tut.q, tut.picked, tut.score, tut.wrong, tut.saved = 1, nil, 0, {}, false
            end
        end

    elseif tut.stage == 'quiz' then
        local item = tut.quiz[tut.q]
        imgui.TextDisabled(u8('Вопрос ' .. tut.q .. ' из ' .. #tut.quiz))
        imgui.ProgressBar((tut.q - 1) / #tut.quiz, ImVec2(-1, math.max(4, imgui.GetTextLineHeight() * 0.4)), '')
        imgui.BeginChild('##tutbody', ImVec2(-1, -navH), false)
        imgui.PushStyleColor(imgui.Col.Text, ACCENT)
        imgui.TextWrapped(u8(item.q))
        imgui.PopStyleColor()
        imgui.Spacing()
        for i, option in ipairs(item.options) do
            local color
            if tut.picked then
                if i == item.correct then color = COLOR_GREEN elseif i == tut.picked then color = COLOR_RED end
            end
            if color then imgui.PushStyleColor(imgui.Col.Button, color) end
            if imgui.Button(u8(option) .. '##qopt' .. i, ImVec2(-1, btnH(1.5))) and not tut.picked then
                tut.picked = i
                if i == item.correct then
                    tut.score = tut.score + 1
                else
                    tut.wrong[#tut.wrong + 1] = tut.q
                end
            end
            if color then imgui.PopStyleColor() end
        end
        if tut.picked then
            imgui.Spacing()
            if tut.picked == item.correct then
                imgui.TextColored(COLOR_OK, u8'Верно!')
            else
                imgui.TextColored(COLOR_BAD, u8'Не совсем.')
            end
            imgui.TextWrapped(u8(item.why))
        end
        imgui.EndChild()
        if tut.picked then
            local last = tut.q >= #tut.quiz
            if buttonRow({ { id = 'qnext', label = last and u8'Результат' or u8'Дальше', color = COLOR_GREEN } }, btnH(1.3)) == 'qnext' then
                if last then
                    tut.stage = 'result'
                else
                    tut.q = tut.q + 1
                    tut.picked = nil
                end
            end
        else
            imgui.TextDisabled(u8'Выбери вариант ответа')
        end

    else
        if not tut.saved then
            tut.saved = true
            settings.tutorialDone = true
            store.saveSettings()
        end
        imgui.TextColored(ACCENT, u8('Результат: ' .. tut.score .. ' из ' .. #tut.quiz))
        imgui.BeginChild('##tutbody', ImVec2(-1, -navH), false)
        if tut.score == #tut.quiz then
            imgui.TextColored(COLOR_OK, u8'Отлично, ты все понял. Можно пользоваться.')
        else
            imgui.TextColored(rgb(250, 204, 21), u8'Есть что повторить:')
            for _, qi in ipairs(tut.wrong) do
                local item = tut.quiz[qi]
                imgui.TextColored(ACCENT, u8(item.q))
                imgui.TextWrapped(u8('Правильный ответ: ' .. item.options[item.correct] .. '. ' .. item.why))
                imgui.Spacing()
            end
        end
        imgui.TextDisabled(u8'Это окно можно открыть снова кнопкой с вопросом в заголовке меню.')
        imgui.EndChild()
        local act = buttonRow({
            { id = 'tutretry', label = u8'Опрос заново' },
            { id = 'tutread', label = u8'Прочитать еще раз' },
            { id = 'tutclose', label = u8'Закрыть', color = COLOR_GREEN },
        }, btnH(1.3))
        if act == 'tutretry' then
            tut.stage = 'quiz'
            tut.q, tut.picked, tut.score, tut.wrong, tut.saved = 1, nil, 0, {}, false
        elseif act == 'tutread' then
            tut.stage = 'read'
            tut.page = 1
        elseif act == 'tutclose' then
            mini.tutorial.open[0] = false
        end
    end
end

local function sortLabel(text, mode)
    local arrow = ''
    if sortMode == mode then arrow = ' ' .. (sortDesc and ico('ARROW_DOWN') or ico('ARROW_UP')) end
    return text .. arrow
end

local function sortClick(mode)
    if sortMode == mode then
        sortDesc = not sortDesc
    else
        sortMode = mode
        sortDesc = false
    end
end

local function parseNeedsString(text)
    local list = {}
    for part in (tostring(text or '') .. ' + '):gmatch('(.-) %+ ') do
        local n, a = part:match('^(.*)%((%d+)%)$')
        if n then list[#list + 1] = { name = n, amount = tonumber(a) } end
    end
    return list
end

do
    local okCj, cjson = pcall(require, 'cjson')
    local _copas_ok, _copas = pcall(require, 'copas')
    local _chttp_ok, _chttp = pcall(require, 'copas.http')
    lavkaCache = {}
    lavkaBusy = false
    lavkaStatus = ''
    avgErrText = ''
    local lavkaReqName = nil
    local lavkaQueue = {}
    local lavkaQueued = {}
    local lavkaFailed = {}

    local IP_VC = '80.66.82.147:7777'
    local API = 'https://api.arz-mcr.top/'
    local AVG_SERVERS = { 'Текущий сервер', 'ViceCity', 'Все сервера' }
    function avgServerNames() return AVG_SERVERS end

    avgErrKind = ''

    local function setErr(msg, kind)
        avgErrText = tostring(msg)
        avgErrKind = kind or 'net'
    end

    local function urlEncode(str)
        local r = string.gsub(tostring(str or ''), '([^%w%-%_%.%~])', function(c)
            return string.format('%%%02X', string.byte(c))
        end)
        return (r:gsub(' ', '+'))
    end

    local function curServer()
        local ok, ip, port = pcall(sampGetCurrentServerAddress)
        if ok and ip and tostring(ip) ~= '' then return tostring(ip) .. ':' .. tostring(port) end
        return nil
    end

    local function scopeServer()
        local sc = (csAvgServerGet and csAvgServerGet()) or 0
        if sc == 2 then return nil end
        if sc == 1 then return IP_VC end
        return curServer()
    end

    local function copasGet(url)
        if _copas_ok and _copas and _copas.addthread and _chttp_ok and _chttp then
            local done = { ok = false }
            _copas.addthread(function()
                local okv, res, code, hdrs = pcall(_chttp.request, url)
                done.ok = true
                done.res = { okv, res, code }
            end)
            while not done.ok do
                if _copas.step then pcall(_copas.step, 0.05) end
                wait(0)
            end
            local r = done.res
            if not r[1] then return nil, tostring(r[2]) end
            local body, code = r[2], r[3]
            if tonumber(code) ~= 200 then return nil, 'HTTP ' .. tostring(code) end
            return body
        end
        local okH, https = pcall(require, 'ssl.https')
        local okL, ltn12 = pcall(require, 'ltn12')
        if not okH or not okL then return nil, 'нет ssl.https' end
        local resp = {}
        local _, code = https.request({ url = url, method = 'GET',
            headers = { ['User-Agent'] = 'mcr' }, sink = ltn12.sink.table(resp) })
        if tonumber(code) ~= 200 then return nil, 'HTTP ' .. tostring(code) end
        return table.concat(resp)
    end

    local function matchName(nm, target)
        nm = tostring(nm or ''):lower()
        return nm == target or nm:find(target, 1, true) or target:find(nm, 1, true)
    end

    function fetchLavkaAvg(name, onDone)
        if not okCj then
            lavkaStatus = 'нет cjson'
            setErr('нет cjson', 'net')
            if onDone then onDone(nil, 'no cjson') end
            return
        end
        local key = lowerCp(trim(u8:encode(name)))
        if lavkaBusy then
            if lavkaReqName ~= name and not lavkaQueued[name] then
                lavkaQueued[name] = true
                lavkaQueue[#lavkaQueue + 1] = { name = name, onDone = onDone }
            end
            return
        end
        lavkaBusy = true
        lavkaReqName = name
        lavkaStatus = 'подождите..'
        avgErrText = ''
        lua_thread.create(function()
            local ok, err = pcall(function()
                local url = API .. 'v1/cloud/shop/search?query=' .. urlEncode(u8:encode(name))
                local srv = scopeServer()
                if srv then url = url .. '&server=' .. urlEncode(srv) end
                local body, herr = copasGet(url)
                if not body then error(herr) end
                local data = cjson.decode(body)
                local target = tostring(u8:encode(name)):lower()
                local nsum, ncnt, allCnt = 0, 0, 0
                for _, it in ipairs(data.it or {}) do
                    if it.t == 's' or it.t == 'sell' then
                        allCnt = allCnt + 1
                        if matchName(it.nm or it.name, target) then
                            local price = tonumber(it.p or it.price)
                            local qty = tonumber(it.q or it.quantity) or 1
                            if price and price > 0 then nsum = nsum + price * qty ncnt = ncnt + qty end
                        end
                    end
                end
                if ncnt <= 0 then error({ nf = true, msg = 'не удалось найти цену' }) end
                lavkaCache[lowerCp(trim(u8:encode(name)))] = { sell = math.floor(nsum / ncnt), t = os.time() }
                lavkaFailed[name] = nil
                if onDone then onDone(math.floor(nsum / ncnt)) end
            end)
            lavkaBusy = false
            lavkaReqName = nil
            if not ok then
                if type(err) == 'table' and err.nf then
                    lavkaStatus = ''
                    setErr(err.msg, 'none')
                else
                    lavkaStatus = 'Ошибка'
                    setErr(tostring(err), 'net')
                end
                if onDone then onDone(nil, err) end
            else lavkaStatus = '' end
            local nxt = table.remove(lavkaQueue, 1)
            if nxt then
                lavkaQueued[nxt.name] = nil
                fetchLavkaAvg(nxt.name, nxt.onDone)
            end
        end)
    end

    function lavkaTryFetch(name)
        local key = lowerCp(trim(u8:encode(name)))
        if lavkaCache[key] then return end
        if lavkaReqName == name or lavkaQueued[name] then return end
        local ft = lavkaFailed[name]
        if ft and os.time() - ft < 300 then return end
        lavkaFailed[name] = os.time()
        fetchLavkaAvg(name)
    end

    function lavkaAvgForName(name)
        if not name then return nil end
        local c = lavkaCache[lowerCp(trim(u8:encode(name)))]
        if c and os.time() - c.t < 900 then return c.sell end
        return nil
    end
    function lavkaAvgFor(it) return it and lavkaAvgForName(it.name) end
end

local function drawNeeds(it, factor, mult)
    local list = it.needsList
    if type(list) ~= 'table' or #list == 0 then
        list = parseNeedsString(it.needs)
    end
    if #list == 0 then
        imgui.TextDisabled('?')
        return
    end
    if factor and factor < 1 then
        local pct = math.floor((1 - factor) * 100 + 0.5)
        imgui.TextColored(GOLD, ico('TRIANGLE_EXCLAMATION') .. ' ' ..
            u8('Активна экономия ресурсов: -' .. pct .. '%. Поэтому количество ниже может быть 0. Отключи в "Проценты".'))
    end
    local rowIcon = imgui.GetTextLineHeight() * 1.1
    local gap = imgui.GetStyle().ItemSpacing.x
    local texts, colors, maxW = {}, {}, 0
    for i, n in ipairs(list) do
        local name = n.name or itemLabel(n.id)
        if n.amount then
            texts[i], colors[i] = amountText(name, math.ceil(n.amount * (factor or 1)) * (mult or 1))
        else
            texts[i], colors[i] = '?', GOLD
        end
        local w = imgui.CalcTextSize(texts[i]).x
        if w > maxW then maxW = w end
    end
    for i, n in ipairs(list) do
        local name = n.name or itemLabel(n.id)
        local x0 = imgui.GetCursorPosX()
        local tex = n.id and getIconTexture(n.id)
        if tex then
            imgui.Image(tex, ImVec2(rowIcon, rowIcon))
        else
            imgui.TextColored(ACCENT, ico('CUBE'))
        end
        imgui.SameLine()
        imgui.TextColored(colors[i], texts[i])
        imgui.SameLine(x0 + rowIcon + gap + maxW + gap)
        imgui.Text(u8(name))
        local rp = lavkaAvgForName(name)
        if not rp and name and name ~= '' then
            lavkaTryFetch(name)
        end
        if rp then
            local total = n.amount and (rp * math.ceil(n.amount * (factor or 1)) * (mult or 1)) or rp
            imgui.SameLine()
            imgui.TextColored(rgb(56, 189, 248), u8('($' .. fmtMoney(rp) .. '/шт, $' .. fmtMoney(total) .. ' за все)'))
        end
    end
end

local function itemNeeds(it)
    local list = it.needsList
    if type(list) ~= 'table' or #list == 0 then list = parseNeedsString(it.needs) end
    return list
end

local function craftableAttempts(it, factor)
    if inventory.time == 0 then return nil end
    local list = itemNeeds(it)
    if #list == 0 then return nil end
    local maxAttempts
    for _, n in ipairs(list) do
        local name = n.name or itemLabel(n.id)
        local per = math.ceil((n.amount or 0) * factor)
        if per > 0 then
            local have = inventoryQty(name) or 0
            local count = math.floor(have / per)
            if maxAttempts == nil or count < maxAttempts then maxAttempts = count end
        end
    end
    return maxAttempts
end

local function passFilters(it, mv)
    local minChance = filterState.chanceSteps[filterState.chanceIdx]
    local maxCost = filterState.costSteps[filterState.costIdx]
    if minChance > 0 and (not mv.chance or mv.chance < minChance) then return false end
    if maxCost > 0 and (not mv.cost or mv.cost > maxCost) then return false end
    if filterState.craft then
        local count = craftableAttempts(it, mv.factor)
        if not count or count < 1 then return false end
    end
    return true
end

function store.sameItem(a, b)
    return a == b or (a ~= nil and b ~= nil and a.id ~= nil and a.id == b.id)
end

local function inCompare(it)
    for _, e in ipairs(compareItems) do
        if store.sameItem(e.it, it) then return true end
    end
    return false
end

local function toggleCompare(it, cat)
    for k, e in ipairs(compareItems) do
        if store.sameItem(e.it, it) then
            table.remove(compareItems, k)
            return
        end
    end
    compareItems[#compareItems + 1] = { it = it, cat = cat }
end

local function addToCart(it, qty)
    for _, e in ipairs(cart) do
        if store.sameItem(e.it, it) then
            e.qty = math.min(999, e.qty + qty)
            return
        end
    end
    cart[#cart + 1] = { it = it, qty = qty }
end

local function cartTotals()
    local totals, order, totalCost = {}, {}, 0
    for _, e in ipairs(cart) do
        local mv = applyMods(e.it)
        if mv.cost then totalCost = totalCost + mv.cost * e.qty end
        for _, n in ipairs(itemNeeds(e.it)) do
            local name = n.name or itemLabel(n.id)
            local per = math.ceil((n.amount or 0) * mv.factor)
            if totals[name] == nil then
                totals[name] = 0
                order[#order + 1] = name
            end
            totals[name] = totals[name] + per * e.qty
        end
    end
    return totals, order, totalCost
end

local function cartLines()
    local totals, order, totalCost = cartTotals()
    local lines = { 'Список закупок:' }
    for _, e in ipairs(cart) do
        lines[#lines + 1] = '- ' .. (e.it.name or '?') .. ' x' .. e.qty
    end
    lines[#lines + 1] = 'Ресурсы:'
    for _, name in ipairs(order) do
        lines[#lines + 1] = name .. ' x' .. totals[name]
    end
    lines[#lines + 1] = 'Итого крафт: $' .. fmtMoney(totalCost)
    return lines
end

local function drawCartContent()
    sizeButtonsRow('cart')
    if #cart == 0 then
        imgui.Dummy(ImVec2(0, S(8)))
        imgui.TextColored(ACCENT, ico('CART_SHOPPING') .. ' ' .. u8'Список пуст')
        imgui.TextDisabled(u8'Открой предмет и нажми В список')
        return
    end

    local x0 = imgui.GetCursorPosX()
    local rightEdge = x0 + imgui.GetContentRegionAvail().x
    local totals, order, totalCost = cartTotals()
    local totalQty, missing = 0, 0
    for _, e in ipairs(cart) do totalQty = totalQty + e.qty end
    for _, name in ipairs(order) do
        local have = inventoryQty(name)
        if have ~= nil and have < totals[name] then missing = missing + 1 end
    end

    imgui.TextColored(GOLD, ico('COINS') .. ' $' .. fmtMoney(totalCost))
    imgui.SameLine()
    imgui.TextDisabled(u8('  ' .. #cart .. ' поз. / ' .. totalQty .. ' шт'))

    local act = buttonRow({
        { id = 'cartcopy', label = ico('COPY') .. ' ' .. u8'Буфер' },
        { id = 'cartchat', label = ico('COMMENT') .. ' ' .. u8'Чат' },
        { id = 'cartclear', label = ico('TRASH') .. ' ' .. u8'Сброс', color = COLOR_RED },
    }, btnH(1.1))
    if act == 'cartcopy' then
        pcall(setClipboardText, u8(table.concat(cartLines(), '\n')))
        chatLog('Список закупок скопирован в буфер')
    elseif act == 'cartchat' then
        for _, line in ipairs(cartLines()) do chatLog(line) end
    elseif act == 'cartclear' then
        cart = {}
        return
    end

    imgui.Separator()

    local bh = imgui.GetFrameHeight()
    local bw = bh * 1.35
    local style = imgui.GetStyle()
    local removeAt
    for i, e in ipairs(cart) do
        local mv = applyMods(e.it)
        imgui.TextColored(ACCENT, u8(e.it.name or '?'))
        if mv.cost then
            local sumText = '$' .. fmtMoney(mv.cost * e.qty)
            imgui.SameLine(rightEdge - imgui.CalcTextSize(sumText).x)
            imgui.TextColored(GOLD, sumText)
        end

        if imgui.Button('-##cm' .. i, ImVec2(bw, bh)) then
            e.qty = e.qty - 1
            if e.qty <= 0 then removeAt = i end
        end
        imgui.SameLine()
        local qtyText = tostring(e.qty)
        local qw = math.max(bw, imgui.CalcTextSize('999').x + style.FramePadding.x * 2)
        local tw = imgui.CalcTextSize(qtyText).x
        local cx = imgui.GetCursorPosX()
        imgui.SetCursorPosX(cx + (qw - tw) / 2)
        imgui.Text(qtyText)
        imgui.SameLine(cx + qw + style.ItemSpacing.x)
        if imgui.Button('+##cp' .. i, ImVec2(bw, bh)) then e.qty = math.min(999, e.qty + 1) end
        if mv.cost then
            imgui.SameLine()
            imgui.TextDisabled(u8('$' .. fmtMoney(mv.cost) .. ' / шт'))
        end
        imgui.SameLine(rightEdge - bw)
        if imgui.Button('X##cx' .. i, ImVec2(bw, bh)) then removeAt = i end
        imgui.Separator()
    end
    if removeAt then table.remove(cart, removeAt) end

    local head = ico('BOXES_STACKED') .. ' ' .. u8'Ресурсы'
    if missing > 0 then head = head .. u8('  (не хватает: ' .. missing .. ')') end
    if imgui.CollapsingHeader(head .. '##cartres', imgui.TreeNodeFlags.DefaultOpen) then
        local texts, colors, maxW = {}, {}, 0
        for i, name in ipairs(order) do
            texts[i], colors[i] = amountText(name, totals[name])
            local w = imgui.CalcTextSize(texts[i]).x
            if w > maxW then maxW = w end
        end
        for i, name in ipairs(order) do
            imgui.Text(u8(name))
            imgui.SameLine(rightEdge - maxW)
            imgui.TextColored(colors[i], texts[i])
        end
    end
end

local function drawCompareContent()
    sizeButtonsRow('cmp')
    local n = #compareItems
    local x0 = imgui.GetCursorPosX()
    local rightEdge = x0 + imgui.GetContentRegionAvail().x

    imgui.TextColored(ACCENT, ico('SCALE_BALANCED') .. ' ' .. u8('Предметов: ' .. n))
    local clearLabel = ico('TRASH') .. ' ' .. u8'Очистить'
    imgui.SameLine(rightEdge - (imgui.CalcTextSize(clearLabel).x + imgui.GetStyle().FramePadding.x * 2))
    if imgui.SmallButton(clearLabel .. '##cmpclear') then
        compareItems = {}
        return
    end
    imgui.Separator()

    if n < 2 then
        imgui.TextDisabled(u8'Выбери минимум два предмета кнопкой Сравн. в карточке')
        local removeOne
        for i, e in ipairs(compareItems) do
            imgui.Text(u8(e.it.name or '?'))
            imgui.SameLine()
            if imgui.SmallButton('X##cmpone' .. i) then removeOne = i end
        end
        if removeOne then table.remove(compareItems, removeOne) end
        return
    end

    local mvs = {}
    for i, e in ipairs(compareItems) do mvs[i] = applyMods(e.it) end
    local good, plain = COLOR_OK, rgb(226, 240, 240)

    local chances, costs, times, anyTime = {}, {}, {}, false
    for i = 1, n do
        chances[i], costs[i], times[i] = mvs[i].chance, mvs[i].cost, mvs[i].time
        if times[i] then anyTime = true end
    end

    local function bestOf(values, higherIsBetter)
        local best
        for i = 1, n do
            local v = values[i]
            if v ~= nil and (best == nil or (higherIsBetter and v > best) or (not higherIsBetter and v < best)) then best = v end
        end
        local allEqual = true
        for i = 1, n do
            if values[i] ~= best then allEqual = false end
        end
        return best, allEqual
    end

    local wins = {}
    for i = 1, n do wins[i] = 0 end
    local function countWins(values, higherIsBetter)
        local best, allEqual = bestOf(values, higherIsBetter)
        if allEqual or best == nil then return end
        for i = 1, n do
            if values[i] == best then wins[i] = wins[i] + 1 end
        end
    end
    countWins(chances, true)
    countWins(costs, false)
    if anyTime then countWins(times, false) end
    local leader, leaderWins, tie = nil, 0, false
    for i = 1, n do
        if wins[i] > leaderWins then leader, leaderWins, tie = i, wins[i], false
        elseif wins[i] == leaderWins and wins[i] > 0 then tie = true end
    end
    if tie then leader = nil end
    local crown = ico('CROWN')
    if crown == '' then crown = '*' end

    local avail = imgui.GetContentRegionAvail().x
    local first = math.min(S(80), avail * 0.26)
    local function setCols(id)
        imgui.Columns(n + 1, id, false)
        imgui.SetColumnWidth(0, first)
        for i = 1, n do imgui.SetColumnWidth(i, (avail - first) / n) end
    end

    local function row(label, values, higherIsBetter, format, colorFn)
        imgui.TextDisabled(label)
        imgui.NextColumn()
        local best, allEqual = bestOf(values, higherIsBetter)
        for i = 1, n do
            local v = values[i]
            local color = (not allEqual and v ~= nil and v == best) and good or plain
            if colorFn then color = colorFn(v) or color end
            imgui.TextColored(color, format(v))
            imgui.NextColumn()
        end
    end

    local function barRow(label, values, higherIsBetter, format, maxValue)
        imgui.TextDisabled(label)
        imgui.NextColumn()
        local best, allEqual = bestOf(values, higherIsBetter)
        local top = maxValue
        if not top then
            top = 0
            for i = 1, n do if values[i] and values[i] > top then top = values[i] end end
        end
        for i = 1, n do
            local v = values[i]
            if v == nil then
                imgui.TextDisabled('-')
            else
                local frac = (top and top > 0) and math.min(1, v / top) or 0
                local isBest = (not allEqual) and v == best
                imgui.PushStyleColor(imgui.Col.PlotHistogram, isBest and good or COLOR_ACCENT)
                imgui.ProgressBar(math.max(0.04, frac), ImVec2(-1, imgui.GetFrameHeight()), format(v))
                imgui.PopStyleColor()
            end
            imgui.NextColumn()
        end
    end

    local removeAt
    setCols('##cmphead')
    imgui.NextColumn()
    for i = 1, n do
        local nm = u8(compareItems[i].it.name or '?')
        if leader == i then nm = crown .. ' ' .. nm end
        imgui.PushStyleColor(imgui.Col.Text, ACCENT)
        imgui.TextWrapped(nm)
        imgui.PopStyleColor()
        if imgui.SmallButton('X##cmprm' .. i) then removeAt = i end
        imgui.NextColumn()
    end
    imgui.Columns(1)
    imgui.Separator()

    setCols('##cmpmain')
    barRow(u8'Шанс', chances, true, function(v) return fmtChance(v) end, 100)
    barRow(u8'Цена', costs, false, function(v) return '$' .. fmtMoney(v) end)
    if anyTime then
        barRow(u8'Время', times, false, function(v) return tostring(v) .. u8' сек' end)
    end
    imgui.Columns(1)
    imgui.Separator()

    local names, seen, maps = {}, {}, {}
    for i = 1, n do
        maps[i] = {}
        for _, need in ipairs(itemNeeds(compareItems[i].it)) do
            local name = need.name or itemLabel(need.id)
            maps[i][name] = math.ceil((need.amount or 0) * mvs[i].factor)
            if not seen[name] then
                seen[name] = true
                names[#names + 1] = name
            end
        end
    end
    if #names > 0 and imgui.CollapsingHeader(ico('BOXES_STACKED') .. ' ' .. u8'Ресурсы##cmpres', imgui.TreeNodeFlags.DefaultOpen) then
        setCols('##cmpresc')
        for _, name in ipairs(names) do
            local values = {}
            for i = 1, n do values[i] = maps[i][name] end
            row(u8(name), values, false,
                function(v) return v and (amountText(name, v)) or '-' end,
                function(v)
                    if v and inventoryQty(name) ~= nil then
                        local _, c = amountText(name, v)
                        return c
                    end
                end)
        end
        imgui.Columns(1)
    end

    if removeAt then table.remove(compareItems, removeAt) end
end

local function changeText(ch)
    if ch.kind == 'new' then return 'новый рецепт' end
    local parts = {}
    local o, n = ch.old or {}, ch.entry
    if o.chance ~= n.chance then parts[#parts + 1] = 'шанс ' .. fmtChance(o.chance) .. ' -> ' .. fmtChance(n.chance) end
    if o.cost ~= n.cost then parts[#parts + 1] = 'цена $' .. fmtMoney(o.cost) .. ' -> $' .. fmtMoney(n.cost) end
    if o.needs ~= n.needs then parts[#parts + 1] = 'ресурсы изменились' end
    return table.concat(parts, ', ')
end

local function toggleIcon(iconName, id, active, color, fallback)
    local glyph = ico(iconName)
    if glyph == '' then glyph = fallback end
    imgui.PushStyleColor(imgui.Col.Text, active and color or rgb(90, 118, 121))
    imgui.PushStyleColor(imgui.Col.Button, ImVec4(0, 0, 0, 0))
    local clicked = imgui.SmallButton(glyph .. '##' .. id)
    imgui.PopStyleColor(2)
    return clicked
end

local function drawTabs(entries, activeKey)
    local style = imgui.GetStyle()
    local spacing = style.ItemSpacing.x
    local avail = imgui.GetContentRegionAvail().x
    local used = 0
    local picked
    for _, e in ipairs(entries) do
        local label = (e.icon ~= '' and (e.icon .. ' ') or '') .. u8(e.text)
        local w = imgui.CalcTextSize(label).x + style.FramePadding.x * 2 + 2
        if used > 0 then
            if used + spacing + w <= avail then
                imgui.SameLine()
                used = used + spacing
            else
                used = 0
            end
        end
        local selected = e.key == activeKey
        if selected then
            imgui.PushStyleColor(imgui.Col.Button, COLOR_ACCENT)
            imgui.PushStyleColor(imgui.Col.Text, rgb(240, 252, 250))
        else
            imgui.PushStyleColor(imgui.Col.Text, e.color)
        end
        if imgui.Button(label .. '##tab' .. e.id, ImVec2(w, btnH(1.2))) then picked = e end
        imgui.PopStyleColor(selected and 2 or 1)
        used = used + w
    end
    return picked
end

local function weightedRow(items, weights, height)
    local spacing = imgui.GetStyle().ItemSpacing.x
    local avail = imgui.GetContentRegionAvail().x - spacing * (#items - 1)
    local total = 0
    for _, w in ipairs(weights) do total = total + w end
    local clicked
    for i, item in ipairs(items) do
        if i > 1 then imgui.SameLine() end
        if item.color then imgui.PushStyleColor(imgui.Col.Button, item.color) end
        if imgui.Button(item.label .. '##' .. item.id, ImVec2(math.floor(avail * weights[i] / total), height or btnH(1.2))) then
            clicked = item.id
        end
        if item.color then imgui.PopStyleColor() end
    end
    return clicked
end

local function drawHeader()
    local style = imgui.GetStyle()
    local spacing = style.ItemSpacing.x
    imgui.TextColored(ACCENT, ico('HAMMER'))
    imgui.SameLine()
    imgui.TextColored(rgb(240, 252, 250), u8'Craft Helper')
    imgui.SameLine()
    local pulse = collecting and (0.55 + 0.45 * math.sin(os.clock() * 5)) or 0.4
    local dotColor = collecting and ImVec4(0.3, 0.87, 0.5, pulse) or ImVec4(0.47, 0.6, 0.6, pulse)
    imgui.TextColored(dotColor, ico('CIRCLE'))

    local invCount = 0
    for _ in pairs(inventory.items) do invCount = invCount + 1 end
    imgui.SameLine(0, spacing * 2)
    if imgui.SmallButton(ico('BOX') .. ' ' .. u8('Инвентарь ' .. invCount) .. '##openinv') then
        mini.inv.open[0] = not mini.inv.open[0]
    end

    imgui.SameLine(0, spacing)
    local dl = store.iconDl
    local dlBusy = dl and dl.busy
    local dlLabel
    if dlBusy then
        dlLabel = ico('SPINNER') .. ' ' .. u8(dl.short or 'Картинки...')
    else
        dlLabel = ico('DOWNLOAD') .. ' ' .. u8'Картинки'
    end
    if imgui.SmallButton(dlLabel .. '##dlicons') and not dlBusy then store.downloadIcons() end

    imgui.SameLine(0, spacing)
    local helpGlyph = ico('CIRCLE_QUESTION')
    if helpGlyph == '' then helpGlyph = '?' end
    if imgui.SmallButton(helpGlyph .. '##helpbtn') then
        tut.stage, tut.page = 'read', 1
        mini.tutorial.open[0] = true
    end

    sizeButtonsInline("main")

    local clicked = weightedRow({
        { id = 'scan',
          label = collecting and (ico('CIRCLE_STOP') .. ' ' .. u8'Стоп') or (ico('CIRCLE_PLAY') .. ' ' .. u8'Скан верстака'),
          color = collecting and COLOR_RED or COLOR_GREEN },
        { id = 'invscan',
          label = (invScan.active and ico('SPINNER') or ico('BOXES_STACKED')) .. ' ' .. u8'Скан инвентаря',
          color = invScan.active and COLOR_ACCENT or nil },
        { id = 'mods', label = ico('PERCENT') .. ' ' .. u8'Проценты', color = anyMods() and COLOR_GREEN or nil },
        { id = 'cmp', label = ico('SCALE_BALANCED') .. ' ' .. u8('Сравнение ' .. #compareItems),
          color = #compareItems >= 2 and COLOR_ACCENT or nil },
        { id = 'cart', label = ico('CART_SHOPPING') .. ' ' .. u8('Закупки ' .. #cart),
          color = #cart > 0 and COLOR_ACCENT or nil },
    }, { 0.22, 0.22, 0.18, 0.19, 0.19 }, btnH(1.3))
    if clicked == 'scan' then
        toggleScan()
        viewCat = nil
        detailCat = nil
        detailItem = nil
    elseif clicked == 'invscan' then
        startInventoryScan()
    elseif clicked == 'mods' then
        mini.mods.open[0] = not mini.mods.open[0]
    elseif clicked == 'cmp' then
        mini.cmp.open[0] = not mini.cmp.open[0]
    elseif clicked == 'cart' then
        mini.cart.open[0] = not mini.cart.open[0]
    end

    local cbLabel = u8'Только новые'
    local cbW = imgui.CalcTextSize(cbLabel).x + imgui.GetFrameHeight() + spacing * 2
    imgui.TextColored(ACCENT, ico('MAGNIFYING_GLASS'))
    imgui.SameLine()
    imgui.PushItemWidth(imgui.GetContentRegionAvail().x - cbW - spacing)
    imgui.InputTextWithHint('##q', u8'Поиск предмета', searchQuery, 256)
    imgui.PopItemWidth()
    imgui.SameLine()
    imgui.Checkbox(cbLabel .. '##incr', incremental)

    imgui.ProgressBar(scanFrac, ImVec2(-1, math.max(4, imgui.GetTextLineHeight() * 0.4)), '')
end

local function drawItemList(order)
    local sortClicked = weightedRow({
        { id = 'sort1', label = sortLabel(u8'Имя', 1), color = sortMode == 1 and COLOR_ACCENT or nil },
        { id = 'sort2', label = sortLabel(u8'Шанс', 2), color = sortMode == 2 and COLOR_ACCENT or nil },
        { id = 'sort3', label = sortLabel(u8'Цена', 3), color = sortMode == 3 and COLOR_ACCENT or nil },
    }, { 0.52, 0.15, 0.33 })
    if sortClicked == 'sort1' then sortClick(1) elseif sortClicked == 'sort2' then sortClick(2) elseif sortClicked == 'sort3' then sortClick(3) end

    local showCat = viewCat
    if not showCat and #order > 0 then showCat = order[1] end

    if showCat == 'chg' then
        imgui.Separator()
        for k, ch in ipairs(changes) do
            local it = ch.entry
            local isNew = ch.kind == 'new'
            imgui.TextColored(isNew and rgb(74, 222, 128) or rgb(250, 204, 21), isNew and u8'НОВЫЙ' or u8'ИЗМ.')
            imgui.SameLine()
            local selected = detailCat == ch.cat and detailItem and scanned[ch.cat] and scanned[ch.cat][detailItem] == it
            if imgui.Selectable(u8(it.name or '?') .. '##chg' .. k, selected and true or false) then
                detailCat = ch.cat
                detailItem = nil
                for idx, e in ipairs(scanned[ch.cat] or {}) do
                    if e == it then
                        detailItem = idx
                        break
                    end
                end
            end
            imgui.TextDisabled('    ' .. u8(changeText(ch)))
        end
        if #changes == 0 then imgui.TextDisabled(u8'Изменений нет') end
        return
    end

    local filterItems = {
        { id = 'fch',
          label = ico('FILTER') .. ' ' .. (filterState.chanceIdx == 1 and u8'Шанс: любой' or u8('Шанс от ' .. filterState.chanceSteps[filterState.chanceIdx] .. '%')),
          color = filterState.chanceIdx > 1 and COLOR_GREEN or nil },
    }
    local weights = { 1 }
    if filterState.chanceIdx > 1 or filterState.craft then
        filterItems[#filterItems + 1] = { id = 'fre', label = ico('XMARK') .. ' ' .. u8'Сброс' }
        weights = { 0.8, 0.2 }
    end
    local fclick = weightedRow(filterItems, weights)
    if fclick == 'fch' then
        filterState.chanceIdx = filterState.chanceIdx % #filterState.chanceSteps + 1
    elseif fclick == 'fre' then
        filterState.chanceIdx, filterState.costIdx = 1, 1
        filterState.craft = false
    end
    local craftLabel = ico('CHECK') .. ' ' .. u8'Могу скрафтить сейчас'
    if inventory.time == 0 then craftLabel = craftLabel .. u8' (нужен скан инвентаря)' end
    local craftClick = weightedRow({
        { id = 'fcr', label = craftLabel, color = filterState.craft and COLOR_GREEN or nil },
    }, { 1 }, btnH(1.15))
    if craftClick == 'fcr' then
        if inventory.time == 0 then
            chatLog('Сначала нажми Скан инвентаря')
        else
            filterState.craft = not filterState.craft
        end
    end
    imgui.Separator()

    local cw = imgui.GetContentRegionAvail().x
    imgui.Columns(3, '##cols', true)
    imgui.SetColumnWidth(0, cw * 0.52)
    imgui.SetColumnWidth(1, cw * 0.15)
    imgui.SetColumnWidth(2, cw * 0.33)

    local view, meta = {}, {}
    if showCat == 'fav' or showCat == 'all' then
        for _, c in ipairs(order) do
            for i, it in ipairs(scanned[c] or {}) do
                if showCat == 'all' or (it.id and favorites[it.id]) then
                    view[#view + 1] = it
                    meta[#view] = { cat = c, i = i }
                end
            end
        end
    elseif showCat and scanned[showCat] then
        for i, it in ipairs(scanned[showCat]) do
            view[#view + 1] = it
            meta[#view] = { cat = showCat, i = i }
        end
    end

    local q = lowerCp(u8:decode(ffi.string(searchQuery)))
    if #view > 0 then
        local sorted = sortedIndices(view)
        local ordered = {}
        for _, k in ipairs(sorted) do
            local it = view[k]
            if it.id and pinned[it.id] then ordered[#ordered + 1] = k end
        end
        for _, k in ipairs(sorted) do
            local it = view[k]
            if not (it.id and pinned[it.id]) then ordered[#ordered + 1] = k end
        end
        local lh = imgui.GetTextLineHeight()
        for _, k in ipairs(ordered) do
            local it, m = view[k], meta[k]
            local mv = applyMods(it)
            local pass = passFilters(it, mv)
            if pass and q ~= '' then
                pass = it.name and lowerCp(it.name):find(q, 1, true) ~= nil
            end
            if pass then
                local rowId = m.cat .. '_' .. m.i
                if toggleIcon('THUMBTACK', 'p' .. rowId, it.id and pinned[it.id], PIN_COLOR, '#') then store.togglePin(it.id) end
                imgui.SameLine()
                if toggleIcon('STAR', 'f' .. rowId, it.id and favorites[it.id], GOLD, '*') then store.toggleFav(it.id) end
                imgui.SameLine()
                local tex = it.id and getIconTexture(it.id)
                if tex then
                    imgui.Image(tex, ImVec2(lh * 1.1, lh * 1.1))
                else
                    imgui.TextColored(ACCENT, ico('CUBE'))
                end
                imgui.SameLine()
                if inventory.time > 0 then
                    local can = (craftableAttempts(it, mv.factor) or 0) >= 1
                    local mark = ico('CHECK')
                    if mark == '' then mark = 'v' end
                    imgui.TextColored(can and COLOR_OK or ImVec4(0, 0, 0, 0), mark)
                    imgui.SameLine()
                end
                if imgui.Selectable(u8(it.name or '?') .. '##i' .. rowId, detailItem == m.i and detailCat == m.cat, imgui.SelectableFlags.SpanAllColumns) then
                    detailCat = m.cat
                    detailItem = m.i
                end
                imgui.NextColumn()
                imgui.TextColored(chanceColor(mv.chance), fmtChance(mv.chance))
                imgui.NextColumn()
                imgui.TextColored(GOLD, ico('COINS') .. ' $' .. fmtMoney(mv.cost))
                imgui.NextColumn()
            end
        end
    else
        imgui.TextDisabled(showCat == 'fav' and u8'Пусто: нажми звезду у предмета' or u8'(нет данных)')
        imgui.NextColumn(); imgui.NextColumn(); imgui.NextColumn()
    end
    imgui.Columns(1)
end

detailAvgFetched = nil

local function drawDetail(it)
    local lh = imgui.GetTextLineHeight()
    local mv = applyMods(it)

    if detailAvgFetched ~= it.name then
        detailAvgFetched = it.name
        if it.name and lavkaAvgFor(it) == nil and not lavkaBusy then
            fetchLavkaAvg(it.name)
        end
    end

    if imgui.Button(ico('XMARK') .. '##closedet', ImVec2(btnH(1.2), btnH(1.2))) then
        detailItem = nil
        return
    end
    imgui.SameLine()
    imgui.TextColored(ACCENT, u8(it.name or '?'))
    imgui.Separator()

    local iconSize = lh * 4.4
    local tex = it.id and getIconTexture(it.id)
    if tex then
        imgui.Image(tex, ImVec2(iconSize, iconSize))
    else
        local p = imgui.GetCursorScreenPos()
        imgui.Dummy(ImVec2(iconSize, iconSize))
        imgui.GetWindowDrawList():AddRect(
            ImVec2(p.x, p.y), ImVec2(p.x + iconSize, p.y + iconSize),
            imgui.ColorConvertFloat4ToU32(ImVec4(0.18, 0.72, 0.65, 1)), 10, 0, 1.5)
    end
    imgui.SameLine()
    imgui.BeginGroup()
    imgui.TextColored(chanceColor(mv.chance), ico('PERCENT') .. ' ' .. u8'Шанс: ' .. fmtChance(mv.chance))
    imgui.TextColored(GOLD, ico('COINS') .. ' ' .. u8'Цена: $' .. fmtMoney(mv.cost))
    local avgP = lavkaAvgFor(it)
    if avgP then
        imgui.TextColored(rgb(56, 189, 248), ico('SCALE_BALANCED') .. ' ' .. u8'Средняя: $' .. fmtMoney(avgP))
    elseif lavkaBusy then
        imgui.TextDisabled(ico('SPINNER') .. ' ' .. u8'подождите..')
    elseif avgErrKind == 'none' then
        imgui.TextDisabled(ico('SCALE_BALANCED') .. ' ' .. u8'не удалось найти цену')
    else
        imgui.TextDisabled(ico('SCALE_BALANCED') .. ' ' .. u8'Средняя: -')
    end
    imgui.SameLine()
    local srv = avgServerNames()
    local scur = settings.avgServer or 0
    if imgui.SmallButton(ico('SERVER') .. ' ' .. u8(srv[scur + 1]) .. '##avgsrv') then
        imgui.OpenPopup('##avgserver_popup')
    end
    if imgui.BeginPopup('##avgserver_popup') then
        imgui.TextDisabled(u8'Сервер для цен')
        imgui.Separator()
        for si, sname in ipairs(srv) do
            local sel = (si - 1 == scur)
            local lbl = (sel and (ico('CHECK') .. ' ') or '   ') .. u8(sname)
            if imgui.Selectable(lbl .. '##avgs' .. si, sel) then
                settings.avgServer = si - 1
                lavkaCache = {}
                store.saveSettings()
                detailAvgFetched = nil
            end
        end
        imgui.EndPopup()
    end
    if avgErrKind == 'net' and avgErrText ~= '' and not lavkaBusy then
        imgui.TextColored(COLOR_BAD, u8(avgErrText))
        imgui.SameLine()
        if imgui.SmallButton(ico('ROTATE_LEFT') .. ' ' .. u8'Повторить##avgretry') then
            avgErrText = '' avgErrKind = ''
            detailAvgFetched = nil
            if it.name then fetchLavkaAvg(it.name) end
        end
    end
    if mv.time then
        imgui.TextColored(rgb(56, 189, 248), ico('CLOCK') .. ' ' .. tostring(mv.time) .. u8' сек')
    end
    imgui.EndGroup()

    imgui.Separator()
    local total = mv.cost and (mv.cost * attempts) or nil
    imgui.TextDisabled(u8('Попыток: ' .. attempts))
    imgui.SameLine()
    imgui.TextColored(GOLD, u8'Итого $' .. fmtMoney(total))
    local att = buttonRow({
        { id = 'm10', label = '-10' },
        { id = 'm1', label = '-1' },
        { id = 'p1', label = '+1' },
        { id = 'p10', label = '+10' },
    }, btnH(1.3))
    if att == 'm10' then attempts = math.max(1, attempts - 10)
    elseif att == 'm1' then attempts = math.max(1, attempts - 1)
    elseif att == 'p1' then attempts = math.min(999, attempts + 1)
    elseif att == 'p10' then attempts = math.min(999, attempts + 10) end

    if mv.chance then
        local prob = (1 - (1 - math.min(mv.chance, 100) / 100) ^ attempts) * 100
        imgui.TextColored(chanceColor(prob), u8'Хотя бы 1 успех: ' .. string.format('%.1f%%', prob))
    else
        imgui.TextDisabled(u8'Шанс неизвестен')
    end

    local maxA = craftableAttempts(it, mv.factor)
    if maxA ~= nil then
        if maxA >= 1 then
            imgui.TextColored(COLOR_OK, ico('CHECK') .. ' ' .. u8('Ресурсов хватает на ' .. maxA .. ' поп.'))
        else
            imgui.TextColored(COLOR_BAD, ico('XMARK') .. ' ' .. u8'Ресурсов не хватает')
        end
    end
    local enough = maxA ~= nil and maxA >= attempts
    local armed = cartWarn and cartWarn.it == it and cartWarn.attempts == attempts
    if cartWarn and not armed then cartWarn = nil end
    if armed then
        imgui.PushStyleColor(imgui.Col.Text, rgb(250, 204, 21))
        imgui.TextWrapped(u8'Ресурсов уже хватает. Нажми еще раз, чтобы все равно добавить в закупки.')
        imgui.PopStyleColor()
    end

    local isFav = it.id and favorites[it.id]
    local isPin = it.id and pinned[it.id]
    local actions = buttonRow({
        { id = 'fav', label = ico('STAR') .. ' ' .. u8'Избр.', color = isFav and COLOR_GOLD_BTN or nil },
        { id = 'pin', label = ico('THUMBTACK') .. ' ' .. u8'Закреп.', color = isPin and COLOR_GOLD_BTN or nil },
        { id = 'cmp', label = u8'Сравн.', color = inCompare(it) and COLOR_ACCENT or nil },
        { id = 'cart', label = armed and u8'Все равно' or u8'В список', color = armed and COLOR_RED or nil },
    }, btnH(1.3))
    if actions == 'fav' then
        store.toggleFav(it.id)
    elseif actions == 'pin' then
        store.togglePin(it.id)
    elseif actions == 'cmp' then
        toggleCompare(it, detailCat)
    elseif actions == 'cart' then
        if enough and not armed then
            cartWarn = { it = it, attempts = attempts }
            chatLog('Ресурсов уже хватает на ' .. attempts .. ' поп. Нажми еще раз, чтобы добавить')
        else
            addToCart(it, attempts)
            cartWarn = nil
            chatLog('В закупки: ' .. (it.name or '?') .. ' x' .. attempts)
        end
    end

    imgui.Separator()
    imgui.TextDisabled(ico('BOXES_STACKED') .. ' ' .. u8('Нужно на ' .. attempts .. ' поп.:'))
    local needsList = it.needsList
    if type(needsList) ~= 'table' or #needsList == 0 then needsList = parseNeedsString(it.needs) end
    local resTotal, resMissing = 0, false
    for _, n in ipairs(needsList) do
        local rn = n.name or itemLabel(n.id)
        local rp = lavkaAvgForName(rn)
        if rp and n.amount then
            resTotal = resTotal + rp * math.ceil(n.amount * (mv.factor or 1)) * attempts
        else resMissing = true end
    end
    if resTotal > 0 then
        imgui.TextColored(rgb(56, 189, 248), ico('COINS') .. ' ' .. u8('Все ресурсы ~$' .. fmtMoney(resTotal) .. (resMissing and ' (неполн.)' or '')))
    end
    drawNeeds(it, mv.factor, attempts)
end

local function drawMenu()
    placeWindow('main', S(500), S(500), 0)
    imgui.Begin('Craft Helper##main', menuOpen, imgui.WindowFlags.NoCollapse)
    trackWindow('main')

    local order = displayOrder()
    local favCount, allCount = 0, 0
    for _, list in pairs(scanned) do
        allCount = allCount + #list
        for _, it in ipairs(list) do
            if it.id and favorites[it.id] then favCount = favCount + 1 end
        end
    end

    local entries = {}
    entries[#entries + 1] = { key = 'cust', id = 'cust', icon = ico('SLIDERS'), color = ACCENT, text = 'Кастомизация' }
    for n, cat in ipairs(order) do
        entries[#entries + 1] = {
            key = cat, id = 'c' .. cat, icon = categoryIcon(n),
            color = CATEGORY_COLORS[((n - 1) % #CATEGORY_COLORS) + 1],
            text = (categoryName[cat] or ('cat ' .. cat)) .. ' ' .. (scanned[cat] and #scanned[cat] or 0),
        }
    end
    entries[#entries + 1] = { key = 'all', id = 'all', icon = ico('LIST'), color = ALL_COLOR, text = 'Все ' .. allCount }
    entries[#entries + 1] = { key = 'fav', id = 'fav', icon = ico('STAR'), color = GOLD, text = 'Избранное ' .. favCount }
    if #changes > 0 then
        local chgIco = ico('CLOCK_ROTATE_LEFT')
        if chgIco == '' then chgIco = ico('CLOCK') end
        entries[#entries + 1] = { key = 'chg', id = 'chg', icon = chgIco, color = CHANGE_COLOR, text = 'Изменения ' .. #changes }
    end
    local activeKey = viewCat
    if not activeKey and #order > 0 then activeKey = order[1] end
    local picked = drawTabs(entries, activeKey)
    if picked then
        viewCat = picked.key
        detailItem = nil
    end
    imgui.Spacing()

    drawHeader()

    local cur = detailCat and detailItem and scanned[detailCat] and scanned[detailCat][detailItem]
    if viewCat == 'cust' then
        local cavail = imgui.GetContentRegionAvail().x
        local pw = math.floor(cavail * 0.34)
        imgui.BeginChild('##custbody', ImVec2(cavail - pw - imgui.GetStyle().ItemSpacing.x, -1), false)
        drawCustomizeContent()
        imgui.EndChild()
        imgui.SameLine()
        imgui.BeginChild('##custprev', ImVec2(-1, -1), true)
        imgui.TextColored(ACCENT, ico('EYE') .. ' ' .. u8'Превью')
        imgui.Separator()
        imgui.Spacing()
        local pavail = imgui.GetContentRegionAvail()
        drawUiPreview(pavail.x, math.max(120, pavail.y - 4))
        imgui.EndChild()
    elseif cur then
        local avail = imgui.GetContentRegionAvail().x
        imgui.BeginChild('##right', ImVec2(math.floor(avail * 0.5), -1), true)
        drawItemList(order)
        imgui.EndChild()
        imgui.SameLine()
        imgui.PushStyleColor(imgui.Col.ChildBg, rgb(13, 34, 36, 1))
        imgui.BeginChild('##detail', ImVec2(-1, -1), true, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
        drawDetail(cur)
        imgui.EndChild()
        imgui.PopStyleColor()
    else
        imgui.BeginChild('##right', ImVec2(-1, -1), true)
        drawItemList(order)
        imgui.EndChild()
    end

    imgui.End()
end

imgui.OnFrame(function()
    if menuOpen[0] then return true end
    for _, m in pairs(mini) do
        if m.open[0] then return true end
    end
    return false
end, function()
    applyUI()
    refreshScale()
    if menuOpen[0] then drawMenu() end
    drawMini('mods', drawModsContent)
    drawMini('custom', drawCustomContent)
    drawMini('cmp', drawCompareContent)
    drawMini('cart', drawCartContent)
    drawMini('inv', drawInventoryContent)
    drawMini('tutorial', drawTutorialContent)
end)

function main()
    while not isSampAvailable() do wait(100) end
    local wd = getWorkingDirectory()
    local cfgDir = wd .. '/config'
    if not doesDirectoryExist(cfgDir) then createDirectory(cfgDir) end
    craftDir = cfgDir .. '/craft'
    if not doesDirectoryExist(craftDir) then createDirectory(craftDir) end

    local function migrate(oldName, newName)
        local target = cpath(newName)
        if doesFileExist(target) then return end
        local f = io.open(wd .. '/' .. oldName, 'rb')
        if not f then return end
        local data = f:read('*a')
        f:close()
        local out = io.open(target, 'wb')
        if out then out:write(data) out:close() end
    end
    migrate('craft_recipes.json', 'recipes.json')
    migrate('craft_favs.json', 'favs.json')
    migrate('craft_pins.json', 'pins.json')
    migrate('craft_mods.json', 'mods.json')

    recipesJsonPath = cpath('recipes.json')
    modsPath = cpath('mods.json')
    customModsPath = cpath('custom_mods.json')
    favsPath = cpath('favs.json')
    pinsPath = cpath('pins.json')
    inventoryPath = cpath('inventory.json')
    settingsPath = cpath('settings.json')
    winPath = cpath('windows.json')
    store.statePath = cpath('state.json')
    iconDir = cpath('icons')
    if not doesDirectoryExist(iconDir) then createDirectory(iconDir) end

    store.loadRecipes()
    store.loadMods()
    store.loadCustomMods()
    store.loadFavs()
    store.loadPins()
    store.loadInventory()
    store.loadSettings()
    autoInvBuf[0] = settings.autoInv
    if not settings.tutorialDone then mini.tutorial.open[0] = true end
    store.loadWin()
    store.loadState()

    local itemsConstPath = cpath('items_const.json')
    if not doesFileExist(itemsConstPath) then
        local ITEMS_URLS = { 'https://raw.githubusercontent.com/pinokio-67/crafthelper67/main/items_const.json' }
        lua_thread.create(function()
            local okS, https = pcall(require, 'ssl.https')
            local okL, ltn12 = pcall(require, 'ltn12')
            for _, u in ipairs(ITEMS_URLS) do
                local ok, data = pcall(function()
                    if okS and okL then
                        local resp = {}
                        local r1, code = https.request({ url = u, method = 'GET', sink = ltn12.sink.table(resp), headers = { ['user-agent'] = 'Mozilla/5.0' } })
                        if r1 and tonumber(code) == 200 then return table.concat(resp) end
                    end
                    return nil
                end)
                if ok and data and #data > 1000 and data:find('"id"') then
                    local f = io.open(itemsConstPath, 'wb')
                    if f then f:write(data) f:close() break end
                end
            end
        end)
    end

    lua_thread.create(loadItemNames)
    lua_thread.create(function()
        local function flag(fn)
            if type(fn) ~= 'function' then return false end
            local ok, r = pcall(fn)
            return ok and r
        end
        local lastRun = os.clock()
        while true do
            wait(500)
            local now = os.clock()
            if settings.autoInv and not invScan.active and not collecting and now >= invScan.backoff and now - lastRun >= 10 then
                if flag(sampIsLocalPlayerSpawned) and not flag(sampIsDialogActive)
                    and not flag(sampIsChatInputActive) and not flag(isPauseMenuActive) then
                    lastRun = now
                    startInventoryScan(true)
                end
            end
        end
    end)
    lua_thread.create(function()
        while true do
            wait(300)
            if winDirty and os.clock() - winDirtyT > 0.6 then store.saveWin() end
            store.saveState()
            if recipesDirty and os.clock() - recipesDirtyT > 1.5 then
                recipesDirty = false
                store.saveRecipes()
            end
        end
    end)

    sampRegisterChatCommand('crh', function() menuOpen[0] = not menuOpen[0] end)
    sampAddChatMessage('[Craft Helper] /crh - меню', 0xFF40D9C8)
    wait(-1)
end

function onScriptTerminate(scr, quit)
    if scr == thisScript() then
        if winDirty then pcall(store.saveWin) end
        if recipesDirty then pcall(store.saveRecipes) end
        pcall(store.saveState)
        pcall(store.saveMods)
        pcall(store.saveCustomMods)
        pcall(store.saveSettings)
        pcall(store.saveWin)
    end
end