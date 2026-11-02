local effil = require('effil')
local imgui = require('mimgui')
local encoding = require('encoding')
local fa = require('fAwesome6_solid')
local sampev = require('lib.samp.events')
local ffi = require("ffi")
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local inicfg = require 'inicfg'
local directIni = 'marketplace.ini'
local ini = inicfg.load(inicfg.load({
    main = {
        notify_enabled_profit = true,
        notify_min_profit = 0,
        notify_enabled_lowprice = true,
        notify_min_lowprice = 0,
    },
}, directIni))
inicfg.save(ini, directIni)

local FONT_SCALE = 1.3

req = require "requests"

local notifyNewArbitrage = imgui.new.bool(ini.main.notify_enabled_profit)
local minProfitThreshold = imgui.new.int(ini.main.notify_min_profit)
local minDiscountThreshold = imgui.new.int(ini.main.notify_min_lowprice)
local notifyNewCheapItems = imgui.new.bool(ini.main.notify_enabled_lowprice)

local renderWindow = imgui.new.bool(false)

local header_content_types = {
    ['xform'] = 'application/x-www-form-urlencoded',
    ['json'] = 'application/json',
}
local function encodeUrl(data) local function valueToUrlEncode(str) str = str:gsub('([^%w])', function(char) return string.format('%%%02X', string.byte(char)) end) return str end local t = {} for k, v in pairs(data) do if type(v) == 'table' then local n = {} for _, j in ipairs(v) do table.insert(n, valueToUrlEncode(u8(tostring(j)))) end if #n ~= 0 then table.insert(t, string.format('%s=%s', k, table.concat(n, '%2C'))) end else v = valueToUrlEncode(u8(tostring(v))) table.insert(t, string.format('%s=%s', k, v)) end end return u8(table.concat(t, '&')) end local function createRequest(_method, _url, _body) local requests = require('requests') local success, response = pcall(requests.request, _method, _url, _body) if success then response.json, response.xml = nil, nil return true, response else return false, response end end local function createEffilThread(method, url, body, callback) local thread = effil.thread(createRequest)(method, url, body) lua_thread.create(function() while true do wait(10) local status, err = thread:status() if not status or err then return callback(nil, nil, err) end if status == 'completed' or status == 'canceled' then local success, response = thread:get() if not success then return callback(nil, nil, response) end if response and type(response.text) == 'string' and response.text:len() ~= 0 then response.text = u8:decode(response.text) end return callback(response.status_code, response.text, nil) end end end) end
local async_http_request = { request = {} }
async_http_request.__index = async_http_request

---@diagnostic disable-next-line:deprecated
local lower, sub, char, upper = string.lower, string.sub, string.char, string.upper
local concat = table.concat
table.push = table.insert;
function table.forEach(self, callback) for k, v in pairs(self) do callback(v, k); end end
function table.includes(self, value, searchStartIndex) local foundIndex; table.forEach(self, function(v, index) if (v == value and index >= (searchStartIndex or 1)) then foundIndex = index; end end); return foundIndex ~= nil, foundIndex; end
function table.filter(self, callback) table.forEach(self, function(value, index) if (not callback(value, index)) then self[index] = nil; end end); end
function table.keys(self) local keys = {}; table.forEach(self, function(_, k) table.insert(keys, k); end); return keys; end
function table.values(self) local values = {}; table.forEach(self, function(v, _) table.insert(values, v); end); return values; end
local lu_rus, ul_rus = {}, {}; local E, e = char(168), char(184); ul_rus[E] = e; lu_rus[e] = E
for i = 192, 223 do local A, a = char(i), char(i + 32) ul_rus[A] = a lu_rus[a] = A end
function string.nlower(s) s = lower(s) local len, res = #s, {} for i = 1, len do local ch = sub(s, i, i) res[i] = ul_rus[ch] or ch end return concat(res) end
function string.nupper(s) s = upper(s) local len, res = #s, {} for i = 1, len do local ch = sub(s, i, i) res[i] = lu_rus[ch] or ch end return concat(res) end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    --imgui.GetIO().Fonts:Clear()
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    --imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14)..'\\trebucbd.ttf', 20.0, nil, glyph_ranges)
    --imgui.InvalidateFontsTexture()
    Theme()
    fa.Init(64)
end)

local search = imgui.new.char[256]("")
local thresholdPercent = imgui.new.int(50)

local servers = {
    {name = 'Phoenix', number = '1'},
    {name = 'Tucson', number = '2'},
    {name = 'Scottdale', number = '3'},
    {name = 'Chandler', number = '4'},
    {name = 'Brainburg', number = '5'},
    {name = 'SaintRose', number = '6'},
    {name = 'Mesa', number = '7'},
    {name = 'Red Rock', number = '8'},
    {name = 'Yuma', number = '9'},
    {name = 'Surprise', number = '10'},
    {name = 'Prescott', number = '11'},
    {name = 'Glendale', number = '12'},
    {name = 'Kingman', number = '13'},
    {name = 'Winslow', number = '14'},
    {name = 'Payson', number = '15'},
    {name = 'Gilbert', number = '16'},
    {name = 'Show Low', number = '17'},
    {name = 'CasaGrande', number = '18'},
    {name = 'Page', number = '19'},
    {name = 'Sun City', number = '20'},
    {name = 'Queen Creek', number = '21'},
    {name = 'Sedona', number = '22'},
    {name = 'Holiday', number = '23'},
    {name = 'Wednesday', number = '24'},
    {name = 'Yava', number = '25'},
    {name = 'Faraway', number = '26'},
    {name = 'Bumble Bee', number = '27'},
    {name = 'Christmas', number = '28'},
    {name = 'Mirage', number = '29'},
    {name = 'Love', number = '30'},
    {name = 'Drake', number = '31'},
    {name = 'Space', number = '32'},
    {name = 'Mobile III', number = '103'},
    {name = 'Mobile II', number = '102'},
    {name = 'Mobile I', number = '101'},
    {name = 'Vice City', number = '200'},
}

local serversId = {
    [u8'Все сервера'] = -1,
    ['Vice City'] = 0,
    ['Phoenix'] = 1,
    ['Tucson'] = 2,
    ['Scottdale'] = 3,
    ['Chandler'] = 4,
    ['Brainburg'] = 5,
    ['SaintRose'] = 6,
    ['Mesa'] = 7,
    ['Red Rock'] = 8,
    ['Yuma'] = 9,
    ['Surprise'] = 10,
    ['Prescott'] = 11,
    ['Glendale'] = 12,
    ['Kingman'] = 13,
    ['Winslow'] = 14,
    ['Payson'] = 15,
    ['Gilbert'] = 16,
    ['Show Low'] = 17,
    ['CasaGrande'] = 18,
    ['Page'] = 19,
    ['Sun City'] = 20,
    ['Queen Creek'] = 21,
    ['Sedona'] = 22,
    ['Holiday'] = 23,
    ['Wednesday'] = 24,
    ['Yava'] = 25,
    ['Faraway'] = 26,
    ['Bumble Bee'] = 27,
    ['Christmas'] = 28,
    ['Mirage'] = 29,
    ['Love'] = 30,
    ['Drake'] = 31,
    ['Space'] = 32,
}

local serversName = {
    u8'Все сервера',
    'Vice City',
    'Phoenix',
    'Tucson',
    'Scottdale',
    'Chandler',
    'Brainburg',
    'SaintRose',
    'Mesa',
    'Red Rock',
    'Yuma',
    'Surprise',
    'Prescott',
    'Glendale',
    'Kingman',
    'Winslow',
    'Payson',
    'Gilbert',
    'Show Low',
    'CasaGrande',
    'Page',
    'Sun City',
    'Queen Creek',
    'Sedona',
    'Holiday',
    'Wednesday',
    'Yava',
    'Faraway',
    'Bumble Bee',
    'Christmas',
    'Mirage',
    'Love',
    'Drake',
    'Space',
}

local function getARZServerNumber()
	local server = "0"
    if isSampAvailable() then
        for _, s in ipairs(servers) do
            if sampGetCurrentServerName():gsub('%-', ' '):find(s.name) then
                server = s.number
                break
            end
        end
    end
	return server
end

local sc = tonumber(getARZServerNumber())+1
local server_selected = imgui.new.int(sc)
local serverList = imgui.new['const char*'][#serversName](serversName)
local window = 1

local lavka_data = {}
local items_data = {}
local market_data = {}
local cheapItems = {}
local arbitrageResults = {}
local lastArbitrageResults = {}
local lastCheapItems = {}

local search_results = {
    sell = {},
    buy = {}
}

local avg_prices = {
    user_server = {},
    vc = {},
}

local sort_type = 1
local sort_types = {
    "Без сортировки",
    "По возрастанию",
    "По убыванию"
}

local WINDOW_STATES = {
    MARKET_LIST = 1,
    USER_LAVKA = 2,
    SEARCH_RESULTS = 3
}


local function getFilteredMarketData(serverId)
    local filtered_list = {}
    for k, v in pairs(market_data) do
        if (v.serverId == serverId) or serverId == -1 then
            table.insert(filtered_list, v)
        end
    end
    return filtered_list
end

local function getCurrentServerId()
    return serversId[serversName[server_selected[0] + 1]]
end

local function parseItemId(itemId)
    if type(itemId) == "string" then
        local item, ench = itemId:match("(%d-)%((.+)%)")
        return tonumber(item), ench or ""
    end
    return itemId, ""
end

local function LavkaButton(text, lavkaId)
    lavkaId = lavkaId or 1
    local dl = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()
    local size = imgui.CalcTextSize(text)

    if imgui.InvisibleButton(text, imgui.ImVec2(size.x, size.y)) then
        sampSendChat("/findilavka " .. lavkaId)
    end

    local hovered = imgui.IsItemHovered()
    dl:AddText(p, hovered and 0xFFaaaaaa or -1, text)
end

local function findArbitrageOpportunities(marketData)
    local opportunities = {}

    local buyOffers = {}
    local sellOffers = {}

    for _, lavka in pairs(marketData) do
        for i, itemId in ipairs(lavka.items_sell) do
            local actualItemId, enchant = parseItemId(itemId)
            if not sellOffers[actualItemId] then
                sellOffers[actualItemId] = {}
            end

            table.insert(sellOffers[actualItemId], {
                lavka = lavka,
                price = lavka.price_sell[i],
                count = lavka.count_sell[i],
                itemId = itemId,
                enchant = enchant,
                type = "sell"
            })
        end

        for i, itemId in ipairs(lavka.items_buy) do
            local actualItemId, enchant = parseItemId(itemId)
            if not buyOffers[actualItemId] then
                buyOffers[actualItemId] = {}
            end

            table.insert(buyOffers[actualItemId], {
                lavka = lavka,
                price = lavka.price_buy[i],
                count = lavka.count_buy[i],
                itemId = itemId,
                enchant = enchant,
                type = "buy"
            })
        end
    end

    for itemId, buyList in pairs(buyOffers) do
        local sellList = sellOffers[itemId]

        if sellList then
            for _, buyOffer in ipairs(buyList) do
                for _, sellOffer in ipairs(sellList) do
                    if buyOffer.lavka.LavkaUid ~= sellOffer.lavka.LavkaUid and
                       buyOffer.lavka.serverId == sellOffer.lavka.serverId then

                        local profit = (buyOffer.price * 0.92) - sellOffer.price

                        if profit > 0 then
                            local itemName = getItemNameById(itemId)

                            table.insert(opportunities, {
                                itemId = itemId,
                                itemName = itemName,
                                buyLavka = buyOffer.lavka,
                                sellLavka = sellOffer.lavka,
                                buyPrice = buyOffer.price,
                                sellPrice = sellOffer.price,
                                profit = profit,
                                buyCount = buyOffer.count,
                                sellCount = sellOffer.count,
                                enchant = buyOffer.enchant
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(opportunities, function(a, b)
        return a.profit > b.profit
    end)

    return opportunities
end

local function checkNewArbitrageOpportunities(notify)
    if not notifyNewArbitrage[0] then return end

    local newOpportunities = {}

    for _, currentOpp in ipairs(arbitrageResults) do
        local isNew = true

        for _, lastOpp in ipairs(lastArbitrageResults) do
            if currentOpp.itemId == lastOpp.itemId and
               currentOpp.buyLavka.LavkaUid == lastOpp.buyLavka.LavkaUid and
               currentOpp.sellLavka.LavkaUid == lastOpp.sellLavka.LavkaUid and
               currentOpp.buyPrice == lastOpp.buyPrice and
               currentOpp.sellPrice == lastOpp.sellPrice then
                isNew = false
                break
            end
        end

        if isNew and currentOpp.profit >= minProfitThreshold[0] then
            table.insert(newOpportunities, currentOpp)
        end
    end

    if notify then
        if #newOpportunities > 0 then
            for _, opp in ipairs(newOpportunities) do
                local message = string.format("ПРОФИТ: {ffffff}%s. Покупка: лавка %d. Продажа: лавка %d. Профит: %s$",
                    opp.itemName .. (opp.enchant ~= "" and " (" .. opp.enchant .. ")" or ""),
                    opp.buyLavka.LavkaUid,
                    opp.sellLavka.LavkaUid,
                    comma_value(math.floor(opp.profit)))

                sampAddChatMessage(message, 0xaaaaaa)
            end
            sampAddChatMessage("Всего: {ffffff}" .. #newOpportunities .. "шт", 0xaaaaaa)
        end
    end

    lastArbitrageResults = {}
    for _, opp in ipairs(arbitrageResults) do
        table.insert(lastArbitrageResults, {
            itemId = opp.itemId,
            buyLavka = {LavkaUid = opp.buyLavka.LavkaUid},
            sellLavka = {LavkaUid = opp.sellLavka.LavkaUid},
            buyPrice = opp.buyPrice,
            sellPrice = opp.sellPrice,
            profit = opp.profit
        })
    end

    return newOpportunities
end

local function findCheapItems(server, marketData, thresholdPercent)
    local cheapItems = {}

    local averagePrices = avg_prices[server].sell or {}

    for _, lavka in pairs(marketData) do
        if (server == "user_server" and lavka.serverId == getCurrentServerId()) or
           (server == "vc" and lavka.serverId == 0) then

            for i, itemId in ipairs(lavka.items_sell) do
                local actualItemId, enchant = parseItemId(itemId)
                local itemName = getItemNameById(actualItemId)

                if itemName and averagePrices[itemName] and averagePrices[itemName].list then
                    local itemData = averagePrices[itemName]
                    local marketPrice = lavka.price_sell[i]

                    local totalSum = 0
                    local totalCount = 0
                    local dayData = itemData.list[1]
                    if dayData[2] > 0 then
                        totalSum = totalSum + dayData[3]
                        totalCount = totalCount + dayData[2]
                    end

                    if totalCount > 0 then
                        local averagePrice = totalSum / totalCount
                        local discountPercent = ((averagePrice - marketPrice) / averagePrice) * 100

                        if discountPercent >= thresholdPercent then
                            table.insert(cheapItems, {
                                itemId = actualItemId,
                                itemName = itemName,
                                lavka = lavka,
                                price = marketPrice,
                                averagePrice = averagePrice,
                                discountPercent = discountPercent,
                                count = lavka.count_sell[i],
                                enchant = enchant,
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(cheapItems, function(a, b)
        return a.discountPercent > b.discountPercent
    end)

    return cheapItems
end

local function drawCheapItems(cheapItems)
    if #cheapItems == 0 then
        imgui.Text(u8("Дешевые товары не найдены"))
        return
    end

    imgui.Text(u8("Найдено дешевых товаров: " .. #cheapItems))
    imgui.Separator()

    for i, item in ipairs(cheapItems) do
        LavkaButton(u8(string.format("%s -%d процентов", item.itemName .. (item.enchant ~= "" and " (" .. item.enchant .. ")" or ""), item.discountPercent)), item.lavka.LavkaUid)

        imgui.Text(u8("Цена: " .. comma_value(item.price) .. " " .. (item.lavka.serverId == 0 and "VC$" or "SA$")))
        imgui.SameLine()
        imgui.Text(u8("Средняя: " .. comma_value(math.floor(item.averagePrice)) .. " " .. (item.lavka.serverId == 0 and "VC$" or "SA$")))

        imgui.Text(u8("Лавка " .. item.lavka.LavkaUid .. " (" .. item.lavka.username .. ") - " .. item.count .. " шт."))

        if i < #cheapItems then
            imgui.Separator()
        end
    end
end

local function checkNewCheapItems(notify)
    if not notifyNewCheapItems[0] then return end

    local newCheapItems = {}

    for _, currentItem in ipairs(cheapItems) do
        local isNew = true

        for _, lastItem in ipairs(lastCheapItems) do
            if currentItem.itemId == lastItem.itemId and
               currentItem.lavka.LavkaUid == lastItem.lavka.LavkaUid and
               currentItem.price == lastItem.price and
               currentItem.discountPercent == lastItem.discountPercent then
                isNew = false
                break
            end
        end

        if isNew and
           currentItem.discountPercent >= minDiscountThreshold[0] then
            table.insert(newCheapItems, currentItem)
        end
    end

    if notify then
        if #newCheapItems > 0 then
            for _, item in ipairs(newCheapItems) do
                local message = string.format("LOWPRICE: {ffffff}%s. Цена: %s %s. Разница: %d процентов. Лавка %d (%s) - %d шт.",
                    item.itemName .. (item.enchant ~= "" and " (" .. item.enchant .. ")" or ""),
                    comma_value(item.price), item.lavka.serverId == 0 and "VC$" or "SA$",
                    math.floor(item.discountPercent),
                    item.lavka.LavkaUid, item.lavka.username, item.count)

                sampAddChatMessage(message, 0xaaaaaa)
            end

            sampAddChatMessage("Всего: {ffffff}" .. #newCheapItems .. "шт", 0xaaaaaa)
        end
    end

    lastCheapItems = {}
    for _, item in ipairs(cheapItems) do
        table.insert(lastCheapItems, {
            itemId = item.itemId,
            lavka = {LavkaUid = item.lavka.LavkaUid, username = item.lavka.username},
            price = item.price,
            discountPercent = item.discountPercent,
            count = item.count,
            enchant = item.enchant
        })
    end

    return newCheapItems
end

local function updateCheapItemsSearch(notify)
    local currentServerId = getCurrentServerId()
    local filtered_list = getFilteredMarketData(currentServerId)
    cheapItems = findCheapItems(currentServerId == 0 and "vc" or "user_server", filtered_list, thresholdPercent[0])

    checkNewCheapItems(notify)
end

local function drawCheapItemsTab()
    imgui.InputInt(u8("Разница"), thresholdPercent, 1, 10)
    imgui.Text(u8("Товары дешевле средней цены на " .. thresholdPercent[0] .. " процентов"))

    imgui.Text(u8("Настройки уведомлений:"))
    imgui.Checkbox(u8("Уведомлять о новых дешёвых товарах"), notifyNewCheapItems)
    imgui.InputInt(u8("Мин. разница для уведомления (процентов)"), minDiscountThreshold, 1, 10)
    if imgui.Button(u8("Обновить"), imgui.ImVec2(-1, 80 * FONT_SCALE)) then
        updateCheapItemsSearch(true)
    end

    drawCheapItems(cheapItems)
end

local function drawArbitrageOpportunities(opportunities)
    if #opportunities == 0 then
        imgui.Text(u8("Не найдено"))
        return
    end

    imgui.Text(u8("Найдено: " .. #opportunities))
    imgui.Separator()

    for i, opp in ipairs(opportunities) do
        imgui.Text(u8(opp.itemName .. (opp.enchant ~= "" and " (" .. opp.enchant .. ")" or "")))

        LavkaButton(u8(string.format("ПОКУПКА: Лавка %d (%s) - %s %s (%d шт.)",
            opp.buyLavka.LavkaUid,
            opp.buyLavka.username,
            comma_value(opp.buyPrice),
            opp.buyLavka.serverId == 0 and "VC$" or "SA$",
            opp.buyCount)), opp.buyLavka.LavkaUid)

        LavkaButton(u8(string.format("ПРОДАЖА: Лавка %d (%s) - %s %s (%d шт.)",
            opp.sellLavka.LavkaUid,
            opp.sellLavka.username,
            comma_value(opp.sellPrice),
            opp.sellLavka.serverId == 0 and "VC$" or "SA$",
            opp.sellCount)), opp.sellLavka.LavkaUid)

        imgui.Text(u8("ПРОФИТ:"))
        imgui.SameLine()
        imgui.Text(u8(string.format("%s %s (с -8 процентов от цены продажи)", comma_value(opp.profit), opp.buyLavka.serverId == 0 and "VC$" or "SA$")))

        if i < #opportunities then
            imgui.Separator()
        end
    end
end

local function updateArbitrageOpportunities(notify)
    local currentServerId = getCurrentServerId()
    local filtered_list = getFilteredMarketData(currentServerId)
    local opportunities = findArbitrageOpportunities(filtered_list)
    arbitrageResults = opportunities

    checkNewArbitrageOpportunities(notify)
end

local function drawProfitTab()
    imgui.Text(u8("Покупка дороже продажи"))

    imgui.Text(u8("Настройки уведомлений:"))
    imgui.PushItemWidth(300 * FONT_SCALE)
    if imgui.InputInt(u8("Мин. профит для уведомления"), minProfitThreshold, 100, 1000) then
        ini.main.notify_min_profit = minProfitThreshold[0]
        inicfg.save(ini, directIni)
    end
    if imgui.Checkbox(u8("Уведомлять о новых предложениях"), notifyNewArbitrage) then
        ini.main.notify_enabled_profit = notifyNewArbitrage[0]
        inicfg.save(ini, directIni)
    end

    if imgui.Button(u8("Обновить"), imgui.ImVec2(-1, 80 * FONT_SCALE)) then
        updateArbitrageOpportunities(true)
    end

    imgui.NewLine()

    if arbitrageResults then
        drawArbitrageOpportunities(arbitrageResults)
    end
end

local function createItemData(lavka, itemId, price, count, index, isSell)
    local actual_item_id, enchant = parseItemId(itemId)

    return {
        item_id = actual_item_id,
        item_name = string.format("%d. %s%s", lavka.LavkaUid, getItemNameById(itemId), enchant ~= "" and ("(%s)"):format(enchant) or ""),
        lavka_uid = lavka.LavkaUid,
        server_id = lavka.serverId,
        price = price,
        count = count,
        index = index,
        is_sell = isSell
    }
end

local function SearchHeader(itemCount)
    imgui.NewLine()
    imgui.NewLine()
    imgui.Text(fa["STORE"])
    imgui.SameLine()

    local cY = imgui.GetCursorPosY()
    imgui.SetCursorPosY(cY - 40)
    imgui.Indent(80 * FONT_SCALE)

    imgui.Text(u8("Всего найдено предметов в лавках: " .. itemCount))
end

local function SortButton()
    imgui.SameLine()
    imgui.SetCursorPosX(imgui.GetWindowWidth() / 3 * 2)
    if imgui.Button(u8("Сортировка: " .. sort_types[sort_type])) then
        sort_type = (sort_type % #sort_types) + 1
        return true
    end
    return false
end

local function drawLavkaCard(data)
    imgui.BeginChild("##lavka" .. data.username .. data.LavkaUid .. data.serverId, imgui.ImVec2(imgui.GetWindowWidth()/2 - 20, 310 * FONT_SCALE), true)

    imgui.NewLine()
    imgui.NewLine()
    imgui.Text(fa["STORE"])
    imgui.SameLine()

    local cY = imgui.GetCursorPosY()
    imgui.SetCursorPosY(cY - 40)
    imgui.Indent(80 * FONT_SCALE)

    imgui.Text(u8("Лавка игрока: " .. data.username))
    imgui.Text(u8("Продажа: " .. #data.items_sell))
    imgui.Text(u8("Скупка: " .. #data.items_buy))
    imgui.Text(u8("Сервер: " .. data.serverId))
    imgui.Text(u8("Лавка: " .. data.LavkaUid))

    if imgui.Button(u8("Открыть лавку"), imgui.ImVec2(-1, 80 * FONT_SCALE)) then
        window = WINDOW_STATES.USER_LAVKA
        lavka_data = data
    end

    imgui.EndChild()
end

local function drawLavkaItems(data, prefix, items, counts, prices)
    imgui.BeginChild("##lavka" .. prefix,
        imgui.ImVec2(imgui.GetWindowWidth() / 2 - imgui.GetStyle().ItemSpacing.x / 2 - imgui.GetStyle().WindowPadding.x, -1),
        true)

    for k, itemId in pairs(items) do
        local actual_item_id, enchant = parseItemId(itemId)

        LavkaButton(
            string.format("%d. %s%s", k, u8(getItemNameById(actual_item_id)), enchant),
            data.LavkaUid
        )

        imgui.Text(u8(string.format("%s шт. | %s %s",
            counts[k], comma_value(prices[k]),
            data.serverId == 0 and "VC$" or "SA$")))

        if k ~= #items then
            imgui.Separator()
        end
    end

    imgui.EndChild()
end

local function drawUserLavka(data)
    imgui.NewLine()
    imgui.Text(fa["STORE"])
    imgui.SameLine()

    local cY = imgui.GetCursorPosY()
    imgui.SetCursorPosY(cY - 40)
    imgui.Indent(80 * FONT_SCALE)

    imgui.Text(u8("Владелец лавки: " .. data.username))
    imgui.Text(u8("ID лавки: " .. data.LavkaUid))
    imgui.Text(u8("Всего предметов в лавке: " .. #data.items_buy + #data.items_sell))
    imgui.Text(u8("Предметов на скупке: " .. #data.items_buy))
    imgui.SameLine()
    imgui.SetCursorPosX(imgui.GetWindowWidth() / 2)
    imgui.Text(u8("Предметов на продаже: " .. #data.items_sell))
    imgui.SetCursorPosX(imgui.GetStyle().WindowPadding.x)

    drawLavkaItems(data, "buy", data.items_buy, data.count_buy, data.price_buy)
    imgui.SameLine()
    drawLavkaItems(data, "sell", data.items_sell, data.count_sell, data.price_sell)
end

local function drawSearchResultsColumn(items, id)
    imgui.BeginChild("##" .. id,
        imgui.ImVec2(imgui.GetWindowWidth() / 2 - imgui.GetStyle().ItemSpacing.x / 2 - imgui.GetStyle().WindowPadding.x, -1),
        true, nil)

    for k, item in pairs(items) do
        LavkaButton(u8(item.item_name), item.lavka_uid)

        imgui.Text(u8(string.format("%s шт. | %s %s Сервер: %s",
            item.count, comma_value(item.price),
            item.server_id == 0 and "VC$" or "SA$",
            serversName[item.server_id + 2])))

        if k ~= #items then
            imgui.Separator()
        end
    end

    imgui.EndChild()
end

local function searchItems(filtered_list)
    local search_text = u8:decode(ffi.string(search)):nlower()
    local found_item_ids = findItemsByName(search_text)

    search_results = { sell = {}, buy = {} }

    for _, lavka in pairs(filtered_list) do
        for i, itemId in ipairs(lavka.items_sell) do
            local actual_item_id, enchant = parseItemId(itemId)
            if table.includes(found_item_ids, actual_item_id) then
                local item_data = createItemData(lavka, itemId, lavka.price_sell[i], lavka.count_sell[i], i, true)
                table.insert(search_results.sell, item_data)
            end
        end

        for i, itemId in ipairs(lavka.items_buy) do
            local actual_item_id, enchant = parseItemId(itemId)
            if table.includes(found_item_ids, actual_item_id) then
                local item_data = createItemData(lavka, itemId, lavka.price_buy[i], lavka.count_buy[i], i, false)
                table.insert(search_results.buy, item_data)
            end
        end
    end

    if sort_type == 2 then
        table.sort(search_results.sell, function(a, b) return a.price < b.price end)
        table.sort(search_results.buy, function(a, b) return a.price < b.price end)
    elseif sort_type == 3 then
        table.sort(search_results.sell, function(a, b) return a.price > b.price end)
        table.sort(search_results.buy, function(a, b) return a.price > b.price end)
    end
end

local function drawSearchResults(data, all)
    SearchHeader(#data.buy + #data.sell)

    if SortButton() then
        searchItems(all)
    end

    imgui.NewLine()
    imgui.Text(u8("Предметов на скупке: " .. #data.buy))
    imgui.SameLine()
    imgui.SetCursorPosX(imgui.GetWindowWidth() / 2)
    imgui.Text(u8("Предметов на продаже: " .. #data.sell))

    imgui.SetCursorPosX(imgui.GetStyle().WindowPadding.x)
    drawSearchResultsColumn(data.buy, "lavkabuy")
    imgui.SameLine()
    drawSearchResultsColumn(data.sell, "lavkasell")
end

local function drawMarketGrid(filtered_list)
    local listClipper = imgui.ImGuiListClipper()
    listClipper:Begin(math.ceil(#filtered_list / 2), 230)

    while listClipper:Step() do
        for row = listClipper.DisplayStart, listClipper.DisplayEnd - 1 do
            local index1 = row * 2 + 1
            local index2 = row * 2 + 2
            local window_width = imgui.GetWindowWidth()
            local item_width = (window_width - 10 - imgui.GetStyle().ItemSpacing.x) / 2

            imgui.BeginGroup()
            if filtered_list[index1] then
                drawLavkaCard(filtered_list[index1])
            end
            imgui.EndGroup()

            local item1_width = imgui.GetItemRectSize().x
            if item1_width < item_width then
                imgui.SameLine(0, item_width - item1_width)
            else
                imgui.SameLine()
            end

            imgui.BeginGroup()
            if filtered_list[index2] then
                drawLavkaCard(filtered_list[index2])
            end
            imgui.EndGroup()
        end
    end
end

local function handleSearchInput(filtered_list)
    if #u8:decode(ffi.string(search)) > 0 then
        window = WINDOW_STATES.SEARCH_RESULTS
        searchItems(filtered_list)
    else
        window = WINDOW_STATES.MARKET_LIST
    end
end

local function drawMarketTab(filtered_list)
    if window == WINDOW_STATES.MARKET_LIST then
        if imgui.Button(u8("Обновить")) then
            updateMarketData()
        end
        drawMarketGrid(filtered_list)
    elseif window == WINDOW_STATES.USER_LAVKA then
        if imgui.Button(u8("Назад")) then
            window = WINDOW_STATES.MARKET_LIST
        end
        imgui.NewLine()
        drawUserLavka(lavka_data)

    elseif window == WINDOW_STATES.SEARCH_RESULTS then
        drawSearchResults(search_results, filtered_list)
    end
end

local newFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(self)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 1000, 700
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), nil, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(resY * 4 / 3, resY), nil)
        if imgui.Begin(u8('Список лавок'), renderWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
            imgui.SetWindowFontScale(FONT_SCALE)
            local currentServerId = getCurrentServerId()
            local filtered_list = getFilteredMarketData(currentServerId)

            imgui.Text(u8("Лавок: " .. #filtered_list))
            imgui.SameLine(imgui.GetWindowWidth() / 2 - 400 * FONT_SCALE / 2)

            imgui.PushItemWidth(400 * FONT_SCALE)
            if imgui.InputTextWithHint("##search", u8("Поиск товара"), search, ffi.sizeof(search)) then
                handleSearchInput(filtered_list)
            end

            imgui.SameLine(imgui.GetWindowWidth() - imgui.GetStyle().ItemSpacing.x - 300 * FONT_SCALE - 20)
            imgui.PushItemWidth(300 * FONT_SCALE)
            imgui.Combo("##serverselect", server_selected, serverList, #serversName)
            if imgui.BeginTabBar("##tabs") then

                if imgui.BeginTabItem(u8("Маркет")) then
                    drawMarketTab(filtered_list)
                    imgui.EndTabItem()
                end
                if imgui.BeginTabItem(u8("Профит")) then
                    if imgui.BeginTabBar("##tabs2") then
                        if imgui.BeginTabItem(u8("Профит")) then
                            drawProfitTab()
                            imgui.EndTabItem()
                        end
                        if imgui.BeginTabItem(u8("Дешман")) then
                            drawCheapItemsTab()
                            imgui.EndTabItem()
                        end
                        imgui.EndTabBar()
                    end
                    imgui.EndTabItem()
                end
                imgui.EndTabBar()
            end
            imgui.End()
        end
    end
)

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('market', function()
        renderWindow[0] = not renderWindow[0]
    end)
    updateMarketData(-1, false)
    updateItemsData()
    updateAvgPrices(server_selected[0] > 1 and serversName[server_selected[0] + 1]:gsub("%s", ""):lower() or nil)
    while true do
        wait(30000)
        --updateMarketData(-1, true)
    end
end

addEventHandler("onWindowMessage", function (msg, wp, lp)
    if wp == 0x1B and renderWindow[0] then
        if msg == 0x100 then
            consumeWindowMessage(true, false)
        end
        if msg == 0x101 then
            renderWindow[0] = false
        end
    end
end)

function updateMarketData(server, notify)
    server = server or "-1"
    async_http_request:create('json', 'GET', "https://api.arz.market/api/getSelectedMarketplace/"..server)
    :setCallback(function (status_code, res, err)
        if status_code == 200 then
            market_data = decodeJson(res)
            updateArbitrageOpportunities(notify)
            updateCheapItemsSearch(notify)
        else
            print(status_code, res, err)
        end
    end)
    :send()
end

--[[
function DeepPrint (t)
  local request_headers_all = ""
  for k, v in pairs(t) do
    if type(v) == "table" then
      request_headers_all = request_headers_all .. "[" .. k .. " " .. DeepPrint(v) .. "] "
    else
      local rowtext = ""
      if type(k) == "string" then
        rowtext = string.format("[%s %s] ", k, v)
      else
        rowtext = string.format("[%s] ", v)
      end    
      request_headers_all = request_headers_all .. rowtext
    end
  end
  return request_headers_all
end
]]

function updateItemsData()
    --async_http_request:create('json', 'GET', "https://raw.githubusercontent.com/FREYM1337/forumnick/main/items_data.json")
    --async_http_request:create('json', 'GET', "https://items.shinoa.tech/items.php")
    async_http_request:create('json', 'GET', "https://server-api.arizona.games/client/json/table/get?project=arizona&server=0&key=inventory_items")
    :setCallback(function (status_code, res, err)
        if status_code == 200 then
            items_data = {}
            items_arz = decodeJson(res)
            for i,v in pairs(items_arz) do
            	--print(type(v.id), v.id, DeepPrint(v))
            	--print(v.id, v.item_name)
            	items_data[v.id] = u8:decode(v.name)
            end
            --print(DeepPrint(items_arz))
            --print(DeepPrint(items_data))
        else
            print(status_code, res, err)
        end
    end)
    :send()
end

function updateAvgPrices(servername)
    avg_prices.vc = {}
    if servername then
        avg_prices.user_server = {}
        async_http_request:create('json', 'GET', "https://raw.githubusercontent.com/FREYM1337/forumnick/main/avg_price/info_users_sell_"..servername..".json")
        :setCallback(function (status_code, res, err)
            if status_code == 200 then
                avg_prices.user_server.sell = decodeJson(res)
            else
                print(status_code, res, err)
            end
        end)
        :send()
    end
    async_http_request:create('json', 'GET', "https://raw.githubusercontent.com/FREYM1337/forumnick/main/avg_price/info_users_sell_vc.json")
    :setCallback(function (status_code, res, err)
        if status_code == 200 then
            avg_prices.vc.sell = decodeJson(res)
        else
            print(status_code, res, err)
        end
    end)
    :send()
end

function findItemsByName(name)
    local result = {}
    local search_lower = name:nlower()

    for itemId, item in pairs(items_data) do
        if item:nlower():find(search_lower) then
            table.insert(result, tonumber(itemId))
        end
    end

    return result
end

function getItemNameById(itemId)
    return items_data[tonumber(itemId)] or ":item"..itemId..":"
end

function sampev.onConnectionRequestAccepted(ip, port, playerId, challenge)
    sc = tonumber(getARZServerNumber())+1
    server_selected = imgui.new.int(sc)
    serverList = imgui.new['const char*'][#serversName](serversName)
end

--- @param type 'xform'|'json'
--- @param method 'GET'|'POST'
--- @param url string
function async_http_request:create(type, method, url)
    self.request = {
        method = method,
        type = type,
        url = url,
        body = {
        headers = {}
        },
        callback = function() end
    }
    self:setHeaders({ ['content-type'] = header_content_types[type] })
    return self
end

--- @param headers table
function async_http_request:setHeaders(headers)
    for k, v in pairs(headers) do
        self.request.body.headers[k] = v
    end
    return self
end

--- @param params table
function async_http_request:setParams(params)
    self.request.url = self.request.url .. '?' .. encodeUrl(params)
    return self
end

--- @param data table
function async_http_request:setData(data)
    if self.request.type == 'xform' then
        self.request.body.data = encodeUrl(data)
    elseif self.request.type == 'json' then
        self.request.body.data = u8(encodeJson(data))
    end
    return self
end

--- @param callback fun(status_code: string|nil, res: any|nil, err: string|nil)
function async_http_request:setCallback(callback)
    self.request.callback = callback
    return self
end

function async_http_request:send()
    self.request.url = u8(self.request.url)
    local resp = req.request(self.request.method, self.request.url, self.request.body)
    self.request.callback(resp.status_code, resp.text, resp.err)
    --createEffilThread(self.request.method, self.request.url, self.request.body, self.request.callback)
end

function Theme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()

    style.WindowPadding = imgui.ImVec2(15, 15)
    style.WindowRounding = 10.0
    style.ChildRounding = 6.0
    style.FramePadding = imgui.ImVec2(20 * FONT_SCALE, 20 * FONT_SCALE)
    style.FrameRounding = 20.0
    style.ItemSpacing = imgui.ImVec2(8, 8)
    style.ItemInnerSpacing = imgui.ImVec2(10, 6)
    style.IndentSpacing = 25.0
    style.ScrollbarSize = 40.0
    style.ScrollbarRounding = 20.0
    style.GrabMinSize = 10.0
    style.GrabRounding = 6.0
    style.PopupRounding = 8
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    style.Colors[imgui.Col.Text]                   = imgui.ImVec4(0.90, 0.90, 0.93, 1.00)
    style.Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    style.Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.15, 0.15, 0.15, 0.30)
    style.Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.15, 0.15, 0.15, 1.00)
    style.Colors[imgui.Col.Border]                 = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    style.Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.15, 0.15, 0.15, 1.00)
    style.Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    style.Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.TitleBg]                = imgui.ImVec4(0.15, 0.15, 0.15, 1.00)
    style.Colors[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.10, 0.10, 0.10, 1.00)
    style.Colors[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.15, 0.15, 0.15, 1.00)
    style.Colors[imgui.Col.MenuBarBg]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    style.Colors[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    style.Colors[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.40, 0.40, 0.40, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    style.Colors[imgui.Col.CheckMark]              = imgui.ImVec4(0.70, 0.70, 0.70, 1.00)
    style.Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.70, 0.70, 0.70, 1.00)
    style.Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.80, 0.80, 0.80, 1.00)
    style.Colors[imgui.Col.Button]                 = imgui.ImVec4(0.18, 0.18, 0.18, 1.00)
    style.Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    style.Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.60, 0.60, 0.60, 1.00)
    style.Colors[imgui.Col.Header]                 = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    style.Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    style.Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.Separator]              = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    style.Colors[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.60, 0.60, 0.60, 1.00)
    style.Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    style.Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    style.Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.PlotLines]              = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
    style.Colors[imgui.Col.PlotLinesHovered]       = imgui.ImVec4(0.70, 0.70, 0.70, 1.00)
    style.Colors[imgui.Col.PlotHistogram]          = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
    style.Colors[imgui.Col.PlotHistogramHovered]   = imgui.ImVec4(0.70, 0.70, 0.70, 1.00)
    style.Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    style.Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.10, 0.10, 0.10, 0.80)
    style.Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    style.Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    style.Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.60, 0.60, 0.60, 1.00)
end

function tableToString(tbl, indent)
    local function formatTableKey(k)
        local defaultType = type(k);
        if (defaultType ~= 'string') then
            k = tostring(k);
        end
        local useSquareBrackets = k:find('^(%d+)') or k:find('(%p)') or k:find('\\') or k:find('%-');
        return useSquareBrackets == nil and k or ('[%s]'):format(defaultType == 'string' and "'" .. k .. "'" or k);
    end
    local str = { '{' };
    local indent = indent or 0;
    for k, v in pairs(tbl) do
        table.insert(str, ('%s%s = %s,'):format(string.rep("    ", indent + 1), formatTableKey(k), type(v) == "table" and tableToString(v, indent + 1) or (type(v) == 'string' and "'" .. v .. "'" or tostring(v))));
    end
    table.insert(str, string.rep('    ', indent) .. '}');
    return table.concat(str, '\n');
end

function comma_value(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)','%1.'):reverse())..right
end

EXPORTS = {
   canToggle = function() return false end,
   getToggle = function() return false end,
   toggle = function() renderWindow[0] = not renderWindow[0] end
}