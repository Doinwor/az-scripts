script_author('@T23Vladimir, FreX')
require 'lib.moonloader'
local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8
local sampev = require 'lib.samp.events'
local inicfg = require 'inicfg'
local act = false
local editing = false
local sending = false
local window_alovlya = imgui.new.bool()
local window_settings = imgui.new.bool()
local new = imgui.new
local checkbox = new.bool()
local delay = new.int(0)

local cfgPath = 'CNN.ini'
local defaultCfg = {
    main = {
        delay = 0,
        priority = 0,
        timePriority = 0
    }
}
local cnnCfg = inicfg.load(defaultCfg, cfgPath) or defaultCfg
local priority = new.int(0)
local timePriority = new.int(0)
local priorityItems = u8('Без приоритета') .. '\0VIP\0' .. u8('Обычный') .. '\0\0'
local timePriorityItems = u8('Без приоритета') .. '\0' .. u8('Сначала старые') .. '\0' .. u8('Сначала новые') .. '\0\0'

function imgui.CircleCheckbox(label, boolRef)
    if imgui.RadioButtonBool(label, boolRef[0]) then
        boolRef[0] = not boolRef[0]
    end
end

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(text).x / 2)
    imgui.Text(text)
end

function imgui.CenterTextInWidth(text, width)
    local offset = (width - imgui.CalcTextSize(text).x) / 2
    if offset > 0 then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + offset)
    end
    imgui.Text(text)
end

imgui.OnInitialize(function()
    local style = imgui.GetStyle()
    style.FrameRounding = 12
    style.GrabRounding = 12
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    local colors = style.Colors
    colors[imgui.Col.TitleBg] = colors[imgui.Col.TitleBgActive]
    colors[imgui.Col.TitleBgCollapsed] = colors[imgui.Col.TitleBgActive]
end)



function main()
    while not isSampAvailable() do wait(0) end

    delay[0] = tonumber(cnnCfg.main.delay) or 0
    priority[0] = tonumber(cnnCfg.main.priority) or 0
    timePriority[0] = tonumber(cnnCfg.main.timePriority) or 0


    sampRegisterChatCommand('cnn', function() window_alovlya[0] = not window_alovlya[0] end)
    sampRegisterChatCommand('cnnm', function() window_settings[0] = not window_settings[0] end)



    while true do wait(0)
    end
end


local newFrame3 = imgui.OnFrame(function() return window_alovlya[0] end, function(player)
    local displaySize = imgui.GetIO().DisplaySize
    imgui.SetNextWindowPos(imgui.ImVec2(displaySize.x / 2, displaySize.y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(u8('Автоловля обьяв'), window_alovlya, imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoScrollbar)
    imgui.Dummy(imgui.ImVec2(165, 0))
    imgui.CircleCheckbox(u8'##act_checkbox', checkbox)
    imgui.SameLine()
    if act and not checkbox[0] then
        editing = false
        sending = false
    end
    act = checkbox[0]

    if act == true then
        imgui.Text(u8('Состояние: вкл' ))
    else
        imgui.Text(u8('Состояние: выкл' ))
    end

    imgui.End()
end)

local newFrame4 = imgui.OnFrame(function() return window_settings[0] end, function(player)
    local displaySize4 = imgui.GetIO().DisplaySize
    imgui.SetNextWindowPos(imgui.ImVec2(displaySize4.x / 2, displaySize4.y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(367, 151), imgui.Cond.FirstUseEver)
    imgui.Begin(u8('Настройка автоловли объявлений'), window_settings, imgui.WindowFlags.NoResize)

    imgui.PushItemWidth(180)
    if imgui.SliderInt(u8('##delay'), delay, 0, 4000) then
        cnnCfg.main.delay = delay[0]
        inicfg.save(cnnCfg, cfgPath)
    end
    imgui.PopItemWidth()
    imgui.SameLine()
    imgui.Text(u8('Задержка (мс)'))

    imgui.Dummy(imgui.ImVec2(0, 6))
    imgui.CenterText(u8('Приоритеты ловли'))

    imgui.BeginGroup()
    imgui.CenterTextInWidth(u8('По типу'), 160)
    imgui.PushItemWidth(160)
    if imgui.ComboStr(u8('##priority'), priority, priorityItems) then
        cnnCfg.main.priority = priority[0]
        inicfg.save(cnnCfg, cfgPath)
    end
    imgui.PopItemWidth()
    imgui.EndGroup()

    imgui.SameLine(0, 30)

    imgui.BeginGroup()
    imgui.CenterTextInWidth(u8('По времени'), 160)
    imgui.PushItemWidth(160)
    if imgui.ComboStr(u8('##timePriority'), timePriority, timePriorityItems) then
        cnnCfg.main.timePriority = timePriority[0]
        inicfg.save(cnnCfg, cfgPath)
    end
    imgui.PopItemWidth()
    imgui.EndGroup()

    imgui.End()
end)

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if dialogId == 25628  then
        sampSendDialogResponse(25628,1,0,0)
        return false
    end
    if act and dialogId == 557 then
        editing = true
        sending = false
    end
    if act and not editing then
        if dialogId == 25899  then
            lua_thread.create(function()
                wait(delay[0])
                sampSendDialogResponse(25899,1,0,0)
            end)
            return false
        end
        if dialogId == 25618   then
            lua_thread.create(function()
                wait(delay[0])
                sampSendDialogResponse(25618,1,0,0)
            end)
            return false
        end
        if dialogId == 556  then
            local candidates = {}
            local idx = -1
            for line in (text .. '\n'):gmatch('(.-)\n') do
                if idx >= 0 and not line:find('В редакции', 1, true) then
                    local isVip = line:find('VIP', 1, true) ~= nil
                    local timeSec = tonumber(line:match('(%d+)c')) or 0
                    table.insert(candidates, {index = idx, isVip = isVip, time = timeSec})
                end
                idx = idx + 1
            end

            local function pickBest(list)
                if #list == 0 then return nil end
                if timePriority[0] == 0 then
                    return list[1].index
                end
                local best = list[1]
                for i = 2, #list do
                    if timePriority[0] == 1 and list[i].time > best.time then
                        best = list[i]
                    elseif timePriority[0] == 2 and list[i].time < best.time then
                        best = list[i]
                    end
                end
                return best.index
            end

            local vipList = {}
            local normalList = {}
            for _, c in ipairs(candidates) do
                if c.isVip then
                    table.insert(vipList, c)
                else
                    table.insert(normalList, c)
                end
            end

            local freeIndex = nil
            if priority[0] == 1 then
                freeIndex = pickBest(vipList) or pickBest(candidates)
            elseif priority[0] == 2 then
                freeIndex = pickBest(normalList) or pickBest(candidates)
            else
                freeIndex = pickBest(candidates)
            end
            if freeIndex then
                lua_thread.create(function()
                    wait(delay[0])
                    sampSendDialogResponse(556,1,freeIndex,0)
                end)
            end
        end
    end
end

addEventHandler('onSendRpc', function(id, bs)
    if id == 62 then
        local dlgId = raknetBitStreamReadInt16(bs)
        raknetBitStreamResetReadPointer(bs)
        if dlgId == 557 then
            editing = false
            sending = false
        end
    end
end)

function sampev.onServerMessage(color, text)
    if act == true and not editing and not sending then
        if color == -1048826369 then
            sending = true
            sampSendChat('/newsredak')
        end
    end
    if text:find('за отредактированое вами', 1, true) then
        editing = false
        sending = false
    end
    if text:find('отклонил объявление', 1, true) then
        editing = false
        sending = false
    end
    if text:find('отправка будет доступна через', 1, true) then
        editing = false
        sending = false
    end
    if text:find('Произошла ошибка', 1, true) then
        editing = false
        sending = false
    end
    if text:find('это объявление уже редактирует', 1, true) then
        editing = false
        sending = false
    end
end