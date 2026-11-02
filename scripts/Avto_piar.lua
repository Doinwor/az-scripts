script_name("autopiar 2.0")
script_author("major")
script_version("2.1")

-- либы
local mimgui = require 'mimgui'
local encoding = require 'encoding'
local sampev = require 'lib.samp.events'
local ffi = require 'ffi'
local inicfg = require 'inicfg'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

local function lower_cp1251(s)
    local res = ""
    for i = 1, #s do
        local c = s:byte(i)
        if c >= 192 and c <= 223 then
            res = res .. string.char(c + 32)
        elseif c == 168 then -- Ё
            res = res .. string.char(184) -- ё
        else
            res = res .. string.char(c)
        end
    end
    return string.lower(res) 
end

local config_file = "apr.ini"

local renderWindow = mimgui.new.bool(false)
local tab = 1
local editingIndex = nil
local newMessage = mimgui.new.char[256]('')

local status = mimgui.new.bool(false)
local globalCooldown = mimgui.new.int(3)
local vrSkipEnabled = mimgui.new.bool(false)
local vrTriggers = mimgui.new.char[256](u8"sell,buy,продам,куплю")

local lastGlobalSend = 0
local lastVrMessage = "" 
local isRodina = false 

-- чаты 
local chatTypes = {
    { id = '',    name = 'Обычный чат',     enabled = false, delay = 30, messages = {}, lastSend = 0, index = 1 },
    { id = 's',   name = 'Крик (/s)',       enabled = false, delay = 30, messages = {}, lastSend = 0, index = 1 },
    { id = 'vr',  name = 'VIP-чат (/vr)',   enabled = false, delay = 303, messages = {}, lastSend = 0, index = 1 },
    { id = 'j',   name = 'РП Чат-работ (/j)',enabled = false, delay = 30, messages = {}, lastSend = 0, index = 1 },
    { id = 'jb',  name = 'НРП Чат-работ (/jb)',enabled= false, delay = 30, messages = {}, lastSend = 0, index = 1 },
    { id = 'fam', name = 'Семейный (/fam)', enabled = false, delay = 30, messages = {}, lastSend = 0, index = 1 },
    { id = 'f',   name = 'РП Нелегал (/f)', enabled = false, delay = 30, messages = {}, lastSend = 0, index = 1 },
    { id = 'fb',  name = 'НРП Нелегал (/fb)',enabled = false, delay = 30, messages = {}, lastSend = 0, index = 1 },
    { id = 'al',  name = 'Альянс (/al)',    enabled = false, delay = 30, messages = {}, lastSend = 0, index = 1 },
    { id = 'gd',  name = 'Чат Коалиции (/gd)', enabled = false, delay = 30, messages = {}, lastSend = 0, index = 1 },
}

local function saveConfig()
    local data = { Settings = {} }
    data.Settings.status = status[0]
    data.Settings.globalCooldown = globalCooldown[0]
    data.Settings.vrSkipEnabled = vrSkipEnabled[0]
    data.Settings.vrTriggers = u8:decode(ffi.string(vrTriggers))
    for i, chat in ipairs(chatTypes) do
        local section = "Chat_" .. tostring(i)
        data[section] = { enabled = chat.enabled, delay = chat.delay, msgCount = #chat.messages }
        for j, msg in ipairs(chat.messages) do
            data[section]["msg" .. j .. "_active"] = msg.active
            data[section]["msg" .. j .. "_text"] = tostring(msg.text)
        end
    end
    inicfg.save(data, config_file)
end

local function loadConfig()
    local data = inicfg.load(nil, config_file)
    if data then
        if data.Settings then
            status[0] = data.Settings.status or false
            globalCooldown[0] = tonumber(data.Settings.globalCooldown) or 3
            vrSkipEnabled[0] = data.Settings.vrSkipEnabled or false
            if data.Settings.vrTriggers then ffi.copy(vrTriggers, u8(tostring(data.Settings.vrTriggers))) end
        end
        for i, chat in ipairs(chatTypes) do
            local section = "Chat_" .. tostring(i)
            if data[section] then
                chat.enabled = data[section].enabled or false
                chat.delay = tonumber(data[section].delay) or 30
                chat.messages = {}
                local count = tonumber(data[section].msgCount) or 0
                for j = 1, count do
                    local m_act = data[section]["msg" .. j .. "_active"]
                    local m_txt = data[section]["msg" .. j .. "_text"]
                    if m_txt ~= nil then table.insert(chat.messages, {active = m_act, text = tostring(m_txt)}) end
                end
            end
        end
    end
end

local function applyStyle()
    local style = mimgui.GetStyle()
    local clr = style.Colors
    style.WindowRounding = 6.0
    style.ChildRounding = 4.0
    style.FrameRounding = 4.0
    clr[mimgui.Col.WindowBg] = mimgui.ImVec4(0.08, 0.10, 0.12, 0.85)
    clr[mimgui.Col.ChildBg] = mimgui.ImVec4(0.12, 0.14, 0.18, 0.40)
    clr[mimgui.Col.TitleBg] = mimgui.ImVec4(0.08, 0.10, 0.12, 0.90)
    clr[mimgui.Col.TitleBgActive] = mimgui.ImVec4(0.15, 0.20, 0.25, 1.00)
    clr[mimgui.Col.Button] = mimgui.ImVec4(0.15, 0.20, 0.25, 1.0)
    clr[mimgui.Col.ButtonHovered] = mimgui.ImVec4(0.20, 0.30, 0.40, 1.0)
    clr[mimgui.Col.ButtonActive] = mimgui.ImVec4(0.25, 0.35, 0.45, 1.0)
    clr[mimgui.Col.CheckMark] = mimgui.ImVec4(0.30, 0.80, 0.50, 1.0)
end

function mimgui.ButtonActivated(active, text, size)
    if active then
        mimgui.PushStyleColor(mimgui.Col.Button, mimgui.ImVec4(0.25, 0.40, 0.55, 1.0))
        local res = mimgui.Button(text, size)
        mimgui.PopStyleColor()
        return res
    end
    return mimgui.Button(text, size)
end

mimgui.OnFrame(function() return renderWindow[0] end, function(player)
    applyStyle()
    local resX, resY = getScreenResolution()
    mimgui.SetNextWindowPos(mimgui.ImVec2(resX / 2, resY / 2), mimgui.Cond.FirstUseEver, mimgui.ImVec2(0.5, 0.5))
    mimgui.SetNextWindowSize(mimgui.ImVec2(750, 500), mimgui.Cond.FirstUseEver)

    if mimgui.Begin(u8"AutoPiar 3.2 by major", renderWindow, mimgui.WindowFlags.NoCollapse + mimgui.WindowFlags.NoResize) then
        
        mimgui.BeginChild("left_pane", mimgui.ImVec2(180, -40), true)
        for i, chat in ipairs(chatTypes) do
            if mimgui.ButtonActivated(tab == i, u8(chat.name), mimgui.ImVec2(-1, 30)) then 
                tab = i 
                editingIndex = nil 
            end
        end
        mimgui.EndChild()
        
        mimgui.SameLine()
        
        mimgui.BeginChild("right_pane", mimgui.ImVec2(0, -40), true)
        local current = chatTypes[tab]
        
        if current then
            mimgui.Text(u8("Настройки для: " .. current.name))
            mimgui.Separator()
            
            local check_chat = mimgui.new.bool(current.enabled)
            if mimgui.Checkbox(u8("Включить рассылку в этот чат"), check_chat) then 
                current.enabled = check_chat[0]; saveConfig() 
            end
            
            mimgui.PushItemWidth(100)
            local delay_buf = mimgui.new.int(current.delay)
            if mimgui.InputInt(u8"Задержка чата (сек)", delay_buf) then 
                current.delay = math.max(1, delay_buf[0]); saveConfig() 
            end
            mimgui.PopItemWidth()

            if current.id == 'vr' then
                mimgui.Separator()
                if mimgui.Checkbox(u8"Авто-скип окна рекламы VR(триггерные слова)", vrSkipEnabled) then saveConfig() end
                if vrSkipEnabled[0] then
                    mimgui.PushItemWidth(-1)
                    if mimgui.InputTextWithHint("##vrtrig", u8"Триггеры (через запятую): продам, куплю, фама", vrTriggers, 256) then
                        saveConfig()
                    end
                    mimgui.PopItemWidth()
                end
            end

            mimgui.Separator()
            mimgui.Text(u8"Список сообщений:")
            
            if mimgui.BeginChild("messages_list", mimgui.ImVec2(-1, 180), true) then
                mimgui.PushStyleVarVec2(mimgui.StyleVar.ItemSpacing, mimgui.ImVec2(5, 5))
                for i, msg in ipairs(current.messages) do
                    local chk = mimgui.new.bool(msg.active)
                    if mimgui.Checkbox("##chk"..i, chk) then msg.active = chk[0]; saveConfig() end
                    mimgui.SameLine()
                    
                    mimgui.PushStyleVarVec2(mimgui.StyleVar.FramePadding, mimgui.ImVec2(0, 0))
                    
                    if mimgui.Button(u8"Ред.##edit"..i, mimgui.ImVec2(40, 22)) then
                        ffi.copy(newMessage, u8(tostring(msg.text)))
                        editingIndex = i
                    end
                    
                    mimgui.SameLine()
                    
                    if mimgui.Button(u8"X##del"..i, mimgui.ImVec2(32, 22)) then
                        table.remove(current.messages, i)
                        if editingIndex == i then editingIndex = nil end
                        saveConfig()
                    end
                    
                    mimgui.PopStyleVar()
                    mimgui.SameLine()
                    
                    mimgui.TextWrapped(u8(tostring(msg.text)))
                end
                mimgui.PopStyleVar()
                mimgui.EndChild()
            end
            
            mimgui.PushItemWidth(-1)
            mimgui.InputTextWithHint("##new_msg", u8"Введите текст сообщения...", newMessage, 256)
            mimgui.PopItemWidth()
            
            if mimgui.Button(editingIndex and u8"Сохранить изменение" or u8"Добавить сообщение", mimgui.ImVec2(-1, 30)) then
                local text = u8:decode(ffi.string(newMessage))
                if #text > 0 then
                    if editingIndex then
                        current.messages[editingIndex].text = text
                        editingIndex = nil
                    else
                        table.insert(current.messages, {active = true, text = text})
                    end
                    ffi.fill(newMessage, ffi.sizeof(newMessage), 0)
                    saveConfig()
                end
            end
        end
        
        mimgui.EndChild()

        mimgui.BeginChild("bottom_pane", mimgui.ImVec2(-1, -1), false)
        if mimgui.Checkbox(u8"Включить скрипт", status) then saveConfig() end
        mimgui.SameLine(200)
        
        mimgui.PushItemWidth(80)
        if mimgui.InputInt(u8"КД между сообщениями (сек)", globalCooldown) then
            if globalCooldown[0] < 1 then globalCooldown[0] = 1 end
            saveConfig()
        end
        mimgui.PopItemWidth()
        
        mimgui.EndChild()
        mimgui.End()
    end
end)

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    wait(2000) 
    
    local serverName = sampGetCurrentServerName()
    
    if serverName and (serverName:lower():find("rodina") or serverName:lower():find("родина")) then
        isRodina = true
        for i = #chatTypes, 1, -1 do
            if chatTypes[i].id == "gd" then
                table.remove(chatTypes, i)
                break
            end
        end
    end
    
    loadConfig()
    sampRegisterChatCommand("apr", function() renderWindow[0] = not renderWindow[0] end)
    
    sampAddChatMessage("[AutoPiar] {FFFFFF}Скрипт загружен! Открыть меню: {00FF00}/apr", 0x00FF00)
    
    lua_thread.create(function()
        while true do
            wait(500)
            if status[0] then
                local osTime = os.time()
                local clockTime = os.clock()
                if (clockTime - lastGlobalSend) >= globalCooldown[0] then
                    for _, chat in ipairs(chatTypes) do
                        if chat.enabled and #chat.messages > 0 then
                            if (osTime - chat.lastSend) >= chat.delay then
                                local msgData = chat.messages[chat.index]
                                if msgData and msgData.active then
                                    if chat.id == "vr" then lastVrMessage = lower_cp1251(tostring(msgData.text)) end
                                    local prefix = chat.id ~= "" and ("/" .. chat.id .. " ") or ""
                                    sampSendChat(u8:decode(u8(prefix .. tostring(msgData.text))))
                                    chat.lastSend = osTime
                                    lastGlobalSend = clockTime
                                    chat.index = chat.index + 1
                                    if chat.index > #chat.messages then chat.index = 1 end
                                    break 
                                else
                                    chat.index = chat.index + 1
                                    if chat.index > #chat.messages then chat.index = 1 end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    wait(-1)
end

function sampev.onSendCommand(cmd)
    if cmd:lower():find("^/vr ") then lastVrMessage = lower_cp1251(cmd:sub(5)) end
end

-- скип родина
function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if vrSkipEnabled[0] then
        if isRodina then
            if dialogId == 1296 then
                sampSendDialogResponse(dialogId, 1, 0, "")
                return false
            elseif dialogId == 1295 then
                local isAd = false
                local triggers_str = lower_cp1251(u8:decode(ffi.string(vrTriggers)))
                for trigger in string.gmatch(triggers_str, "([^,]+)") do
                    trigger = trigger:match("^%s*(.-)%s*$")
                    if trigger ~= "" and lastVrMessage:find(trigger) then
                        isAd = true
                        break
                    end
                end
                
                if isAd then 
                    sampSendDialogResponse(dialogId, 1, 0, "") 
                else 
                    sampSendDialogResponse(dialogId, 0, 0, "") 
                end
                return false
            end
        else
        -- скип арз
            if dialogId == 25621 or title:find('VIP') or text:find('рекламного сообщения') then
                local isAd = false
                local triggers_str = lower_cp1251(u8:decode(ffi.string(vrTriggers)))
                for trigger in string.gmatch(triggers_str, "([^,]+)") do
                    trigger = trigger:match("^%s*(.-)%s*$")
                    if trigger ~= "" and lastVrMessage:find(trigger) then
                        isAd = true
                        break
                    end
                end
                if isAd then 
                    sampSendDialogResponse(dialogId, 1, 0, "")
                else 
                    sampSendDialogResponse(dialogId, 0, 0, "") 
                end
                return false
            end
        end
    end
end
