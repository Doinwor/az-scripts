script_author('Radare')
script_version("v1.0")
script_description('pc html hud arizona rp & example of using webviews library')

local fa = require('fAwesome6_solid')
local imgui = require ('mimgui')
local cjson = require("cjson")
local ffi = require("ffi")
local inicfg = require("inicfg")
local jar = require("webviews")
local encoding = require("encoding")
local sampev = require("lib.samp.events")
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local keysWindow = imgui.new.bool(false)
local cefSettingsWindow = imgui.new.bool(false)

function generateRandomHash()local a="0123456789abcdef"local b=""math.randomseed(os.time())for c=1,64 do local d=math.random(1,#a)b=b..a:sub(d,d)end;return b end
local ini = inicfg.load({
    settings = {
        branch = "arzcef",
        size = "default",
        enabled = true
    },
    hash = {
        _64 = generateRandomHash()
    }
    
}, "CEFMobile.ini")
inicfg.save(ini, "CEFMobile.ini")

local callbackConnected, hudToggle, queues, isPause = false, true, {}, false

local FRONTEND_DIRECTORY = getWorkingDirectory().."/frontend/"
local FRONTEND_URL = "https://idmkdev.github.io/arz-interface-link/"

local branches = {"arzcef (actual, not stable)", "halloween25_stable (stable)"}
local sizes = {"default", "16x9", "21x9", "32x9", "4x3", "5x4", "16x10"}


local CEF = {
    SendKey = function(keyid)
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 220)
        raknetBitStreamWriteInt8(bs, 0)
        raknetBitStreamWriteInt8(bs, keyid)
        raknetBitStreamWriteInt8(bs, 64)
        raknetSendBitStreamEx(bs, 1, 7, 1)
        raknetDeleteBitStream(bs)
    end,
    Message = function(str, browserid)
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 220)
        raknetBitStreamWriteInt8(bs, 18)
        raknetBitStreamWriteInt16(bs, #str)
        raknetBitStreamWriteString(bs, str)
        raknetBitStreamWriteInt32(bs, browserid)
        raknetSendBitStreamEx(bs, 1, 7, 1)
        raknetDeleteBitStream(bs)
    end,
    Hash = function(hash)
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 220)
        raknetBitStreamWriteInt8(bs, 38)
        raknetBitStreamWriteInt8(bs, #hash)
        raknetBitStreamWriteString(bs, hash)
        raknetSendBitStreamEx(bs, 1, 7, 1)
        raknetDeleteBitStream(bs)
    end,
    WindowSize = function(x, y)
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 220)
        raknetBitStreamWriteInt8(bs, 20)
        raknetBitStreamWriteInt32(bs, x)
        raknetBitStreamWriteInt32(bs, y)
        raknetSendBitStreamEx(bs, 1, 7, 1)
        raknetDeleteBitStream(bs)
    end,
    ClickStatus = function(id, click)
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 220)
        raknetBitStreamWriteInt8(bs, 24)
        raknetBitStreamWriteInt32(bs, id)
        raknetBitStreamWriteBool(bs, click)
        raknetSendBitStreamEx(bs, 1, 7, 1)
        raknetDeleteBitStream(bs)
    end,
    BrowserCreated = function(id)
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 220)
        raknetBitStreamWriteInt8(bs, 10)
        raknetBitStreamWriteInt32(bs, id)
        raknetSendBitStreamEx(bs, 1, 7, 1)
        raknetDeleteBitStream(bs)
    end,
    LoadedEvent = function(id)
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 220)
        raknetBitStreamWriteInt8(bs, 17)
        raknetBitStreamWriteInt32(bs, id)
        raknetBitStreamWriteInt32(bs, 255)
        raknetSendBitStreamEx(bs, 1, 7, 1)
        raknetDeleteBitStream(bs)
    end,
    CommandLine = function(cmd)
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, 220)
        raknetBitStreamWriteInt8(bs, 140)
        raknetBitStreamWriteInt16(bs, #cmd)
        raknetBitStreamWriteString(bs, cmd)
        raknetBitStreamWriteInt8(bs, 0)
        raknetSendBitStreamEx(bs, 1, 7, 1)
        raknetDeleteBitStream(bs)
    end 
}


function sendPacket(bytes) 
    local bs = raknetNewBitStream() 
    for i = 1, #bytes do raknetBitStreamWriteInt8(bs, bytes[i]) end 
    raknetSendBitStreamEx(bs, 1, 7, 1) 
    raknetDeleteBitStream(bs) 
end 

function emulatePacket(id, bytes) 
    local bs = raknetNewBitStream() 
    for i = 1, #bytes do raknetBitStreamWriteInt8(bs, bytes[i]) end 
    raknetEmulPacketReceiveBitStream(id, bs) 
    raknetDeleteBitStream(bs) 
end

function getAdjustedResolution(size)
    if size == "default" then
        return getScreenResolution()
    end
    
    local screen_w, screen_h = getScreenResolution()
    local new_w, new_h = screen_w, screen_h
    
    if size == "16x9" then
        local target_ratio = 16/9
        local current_ratio = screen_w / screen_h
        if current_ratio > target_ratio then
            new_w = math.floor(screen_h * target_ratio)
        else
            new_h = math.floor(screen_w / target_ratio)
        end
    elseif size == "21x9" then
        local target_ratio = 21/9
        local current_ratio = screen_w / screen_h
        if current_ratio > target_ratio then
            new_w = math.floor(screen_h * target_ratio)
        else
            new_h = math.floor(screen_w / target_ratio)
        end
    elseif size == "32x9" then
        local target_ratio = 32/9
        local current_ratio = screen_w / screen_h
        if current_ratio > target_ratio then
            new_w = math.floor(screen_h * target_ratio)
        else
            new_h = math.floor(screen_w / target_ratio)
        end
    elseif size == "4x3" then
        local target_ratio = 4/3
        local current_ratio = screen_w / screen_h
        if current_ratio > target_ratio then
            new_w = math.floor(screen_h * target_ratio)
        else
            new_h = math.floor(screen_w / target_ratio)
        end
    elseif size == "5x4" then
        local target_ratio = 5/4
        local current_ratio = screen_w / screen_h
        if current_ratio > target_ratio then
            new_w = math.floor(screen_h * target_ratio)
        else
            new_h = math.floor(screen_w / target_ratio)
        end
    elseif size == "16x10" then
        local target_ratio = 16/10
        local current_ratio = screen_w / screen_h
        if current_ratio > target_ratio then
            new_w = math.floor(screen_h * target_ratio)
        else
            new_h = math.floor(screen_w / target_ratio)
        end
    end
    
    return new_w, new_h
end

function getCleanBranch(branch)
    local clean_branch = string.match(branch, "([^%s]+)")
    return clean_branch or branch
end

function getBrowserPosition(size)
    if size == "default" then
        return 0, 0
    end
    
    local screen_w, screen_h = getScreenResolution()
    local adj_w, adj_h = getAdjustedResolution(size)
    local pos_x, pos_y = 0, 0
    
    if size == "4x3" or size == "5x4" or size == "16x10" or size == "16x9" then
        pos_x = math.floor((screen_w - adj_w) / 2)
    elseif size == "21x9" or size == "32x9" then
        pos_y = math.floor((screen_h - adj_h) / 2)
    end
    
    return pos_x, pos_y
end

function cefInfo()
    wait(10) 
    CEF.WindowSize(getScreenResolution())
    CEF.Hash(ini.hash._64)
    sendPacket({220, 50, 1, 0})
end

function sampev.onInitGame() emulatePacket(220, {84, 9, 3, 7, 0, 0, 115,  117, 99, 99, 101, 115, 115}) end
function sampev.onConnectionLost() for i, id in ipairs(jar.getBrowsers()) do jar.deleteBrowser(id) end end
function sampev.onAuthenticationRequest() for i, id in ipairs(jar.getBrowsers()) do jar.deleteBrowser(id) end end
function sampev.onSendClientJoin(version, mod, nickname, challengeResponse, joinAuthKey, clientVer, challengeResponse2)
    if ini.settings.enabled then lua_thread.create(cefInfo) end
    return {version, mod, nickname, challengeResponse, "363267237FD9BCE4A3DFCF917AF4017C4209106C215", ini.settings.enabled and "Arizona PC" or clientVer, challengeResponse2}
end

imgui.OnInitialize(function()
    fa.Init()
end)


local keyboard = {
    {
        { id = 27, label = "Esc", width = 40 },
        { id = 112, label = "F1", width = 40 }, 
        { id = 113, label = "F2", width = 40 },
        { id = 114, label = "F3", width = 40 }, 
        { id = 115, label = "F4", width = 40 },
        { id = 116, label = "F5", width = 40 }, 
        { id = 117, label = "F6", width = 40 },
        { id = 118, label = "F7", width = 40 }, 
        { id = 119, label = "F8", width = 40 },
        { id = 120, label = "F9", width = 40 }, 
        { id = 121, label = "F10", width = 40 },
        { id = 122, label = "F11", width = 40 }, 
        { id = 123, label = "F12", width = 40 }
    },
    {
        { id = 192, label = "`", width = 40 },
        { id = 49, label = "1", width = 40 }, 
        { id = 50, label = "2", width = 40 },
        { id = 51, label = "3", width = 40 }, 
        { id = 52, label = "4", width = 40 },
        { id = 53, label = "5", width = 40 }, 
        { id = 54, label = "6", width = 40 },
        { id = 55, label = "7", width = 40 }, 
        { id = 56, label = "8", width = 40 },
        { id = 57, label = "9", width = 40 },
        { id = 48, label = "0", width = 40 },
        { id = 189, label = "-", width = 40 },
        { id = 187, label = "=", width = 40 },
        { id = 8, label = "Backspace", width = 120 },
        { id = "", label = "", width = 40, visible = false },
        { id = 45, label = "Insert", width = 60, visible = true },
        { id = 36, label = "Home", width = 60, visible = true },
        { id = 33, label = "PgUp", width = 60, visible = true }
    },
    {
        { id = 9, label = "Tab", width = 60 },
        { id = 81, label = "q", width = 40 },
        { id = 87, label = "w", width = 40 },
        { id = 69, label = "e", width = 40 },
        { id = 82, label = "r", width = 40 },
        { id = 84, label = "t", width = 40 },
        { id = 89, label = "y", width = 40 },
        { id = 85, label = "u", width = 40 },
        { id = 73, label = "i", width = 40 },
        { id = 79, label = "o", width = 40 },
        { id = 80, label = "p", width = 40 },
        { id = 219, label = "[", width = 40 },
        { id = 221, label = "]", width = 40 },
        { id = 220, label = "\\", width = 40 },
        { id = "", label = "", width = 100, visible = false },
        { id = 46, label = "Del", width = 60, visible = true },
        { id = 35, label = "End", width = 60, visible = true },
        { id = 34, label = "PgDn", width = 60, visible = true }
    },
    {
        { id = 20, label = "Caps", width = 80 },
        { id = 65, label = "a", width = 40 },
        { id = 83, label = "s", width = 40 },
        { id = 68, label = "d", width = 40 },
        { id = 70, label = "f", width = 40 },
        { id = 71, label = "g", width = 40 },
        { id = 72, label = "h", width = 40 },
        { id = 74, label = "j", width = 40 },
        { id = 75, label = "k", width = 40 },
        { id = 76, label = "l", width = 40 },
        { id = 186, label = ";", width = 40 },
        { id = 222, label = "'", width = 40 },
        { id = 13, label = "Enter", width = 80 }
    },
    {
        { id = 160, label = "Shift", width = 100 },
        { id = 90, label = "z", width = 40 },
        { id = 88, label = "x", width = 40 },
        { id = 67, label = "c", width = 40 },
        { id = 86, label = "v", width = 40 },
        { id = 66, label = "b", width = 40 },
        { id = 78, label = "n", width = 40 },
        { id = 77, label = "m", width = 40 },
        { id = 188, label = ",", width = 40 },
        { id = 190, label = ".", width = 40 },
        { id = 191, label = "/", width = 40 },
        { id = 161, label = "Shift", width = 100 },
        { id = "", label = "", width = 40, visible = false },
        { id = 38, label = fa.ARROW_UP, width = 60 }
    },
    {
        { id = 162, label = "Ctrl", width = 60 },
        { id = 91, label = "Win", width = 60 },
        { id = 164, label = "Alt", width = 60 }, 
        { id = 32, label = " ", width = 500 },
        { id = 164, label = "Alt", width = 60 },
        { id = 17, label = "Ctrl", width = 60 },
        { id = "", label = "", width = 40, visible = false },
        { id = 37, label = fa.ARROW_LEFT, width = 60 },
        { id = 40, label = fa.ARROW_DOWN, width = 60 },
        { id = 39, label = fa.ARROW_RIGHT, width = 60 }
    }
}

function samp_create_sync_data(a,b)local c=require'ffi'local d=require'sampfuncs'local e=require'samp.raknet'require'samp.synchronization'b=b or true;local f={player={'PlayerSyncData',e.PACKET.PLAYER_SYNC,sampStorePlayerOnfootData},vehicle={'VehicleSyncData',e.PACKET.VEHICLE_SYNC,sampStorePlayerIncarData},passenger={'PassengerSyncData',e.PACKET.PASSENGER_SYNC,sampStorePlayerPassengerData},aim={'AimSyncData',e.PACKET.AIM_SYNC,sampStorePlayerAimData},trailer={'TrailerSyncData',e.PACKET.TRAILER_SYNC,sampStorePlayerTrailerData},unoccupied={'UnoccupiedSyncData',e.PACKET.UNOCCUPIED_SYNC,nil},bullet={'BulletSyncData',e.PACKET.BULLET_SYNC,nil},spectator={'SpectatorSyncData',e.PACKET.SPECTATOR_SYNC,nil}}local g=f[a]local h='struct '..g[1]local i=c.new(h,{})local j=tonumber(c.cast('uintptr_t',c.new(h..'*',i)))if b then local k=g[3]if k then local l,m;if b==true then l,m=sampGetPlayerIdByCharHandle(PLAYER_PED)else m=tonumber(b)end;k(m,j)end end;local n=function()local o=raknetNewBitStream()raknetBitStreamWriteInt8(o,g[2])raknetBitStreamWriteBuffer(o,j,c.sizeof(i))raknetSendBitStreamEx(o,d.HIGH_PRIORITY,d.UNRELIABLE_SEQUENCED,1)raknetDeleteBitStream(o)end;local p={__index=function(q,r)return i[r]end,__newindex=function(q,r,s)i[r]=s end}return setmetatable({send=n},p)end
function sendSyncKey(k)local a=samp_create_sync_data(isCharOnFoot(PLAYER_PED) and 'player' or 'vehicle')local b,c,d=getCharCoordinates(PLAYER_PED)a.keysData=k;a.position={b,c,d}a.send()end
imgui.OnFrame(function() return keysWindow[0] end,
  function(player)
    imgui.Begin("##Virtual Keyboard", keysWindow, imgui.WindowFlags.NoTitleBar)


    local min_window_size = imgui.ImVec2(800, 400)
    local content_region = imgui.GetContentRegionAvail()
    local content_width = math.max(content_region.x, min_window_size.x)
    local content_height = math.max(content_region.y, min_window_size.y)
    
    local total_rows = #keyboard
    local row_height = content_height / total_rows
    for _, row in ipairs(keyboard) do
        local row_width = 0
        local sum_width = 0

        for _, key in ipairs(row) do
            if key.visible == false then
                sum_width = sum_width + key.width
            else
                sum_width = sum_width + key.width + 15
            end
        end

        for _, key in ipairs(row) do
            if key.visible == false then
                imgui.SameLine(row_width + key.width * (content_width / sum_width))
                row_width = row_width + key.width * (content_width / sum_width)
            else
                local button_width = key.width * (content_width / sum_width)
                imgui.SetCursorPosX(row_width)
                if imgui.Button(key.label, imgui.ImVec2(button_width, row_height)) then
                    CEF.SendKey(key.id)
                    if key.id == 13 then sendSyncKey(16) end
                    if key.id == 32 then sendSyncKey(8) end
                    if key.id == 164 then sendSyncKey(1024) end
                    if key.id == 72 then 
                        if isCharOnFoot(PLAYER_PED) then
                        local data = samp_create_sync_data("player")
                        data.quaternion[4] = 1.7632555392181e-38
                        local x, y, z = getCharCoordinates(PLAYER_PED)
                        data.position = { x, y, z }
                        data.send()
                    else
                        local data = samp_create_sync_data("vehicle")
                        data.keysData = data.keysData + 2
                        local x, y, z = getCharCoordinates(PLAYER_PED)
                        data.position = { x, y, z }
                        data.send()
                    end
                    end
                    if key.id == 78 then 
                        if isCharOnFoot(PLAYER_PED) then
                            local data = samp_create_sync_data("player")
                            local x, y, z = getCharCoordinates(PLAYER_PED)
                            data.position = { x, y, z }
                            data.quaternion[4] = 1.1755083638069e-38
                            data.send()
                        else
                            sampSendChat("/engine")
                        end
                    end
                    if key.id == 89 then sampSendChat("/invent") end
                    if key.id == 32 then
                        if isCharOnFoot(PLAYER_PED) then
                            local data = samp_create_sync_data("player")
                            data.keysData = data.keysData + 32
                            local x, y, z = getCharCoordinates(PLAYER_PED)
                            data.position = { x, y, z }
                            data.send()
                        else
                            local data = samp_create_sync_data("vehicle")
                            data.keysData = data.keysData + 128
                            local x, y, z = getCharCoordinates(PLAYER_PED)
                            data.position = { x, y, z }
                            data.send()
                        end
                    end
                end
                row_width = row_width + button_width + 10
                imgui.SameLine()
            end
        end


        if imgui.GetWindowSize().x < min_window_size.x then
            imgui.SetWindowSizeVec2(imgui.ImVec2(min_window_size.x, imgui.GetWindowSize().y))
        end

        if imgui.GetWindowSize().y < min_window_size.y then
            imgui.SetWindowSizeVec2(imgui.ImVec2(imgui.GetWindowSize().x, min_window_size.y))
        end

        imgui.NewLine()
    end

    imgui.End()
  end
)

imgui.OnFrame(function() return cefSettingsWindow[0] end,
  function(player)
    imgui.Begin("CEF Settings", cefSettingsWindow)
    
    imgui.Text("Branch Selection:")
    local current_branch = ini.settings.branch
    if imgui.BeginCombo("##branch", current_branch) then
      for i, branch in ipairs(branches) do
        if imgui.Selectable(branch, branch == current_branch) then
          ini.settings.branch = branch
          inicfg.save(ini, "CEFMobile.ini")
        end
      end
      imgui.EndCombo()
    end
    
    imgui.Spacing()
    imgui.Text("Size Selection:")
    local current_size = ini.settings.size
    if imgui.BeginCombo("##size", current_size) then
      for i, size in ipairs(sizes) do
        if imgui.Selectable(size, size == current_size) then
          ini.settings.size = size
          inicfg.save(ini, "CEFMobile.ini")
        end
      end
      imgui.EndCombo()
    end
    
    imgui.Spacing()
    local enabled = imgui.new.bool(ini.settings.enabled)
    if imgui.Checkbox("Enabled", enabled) then
      ini.settings.enabled = enabled[0]
      inicfg.save(ini, "CEFMobile.ini")
    end
    
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
    
    imgui.Text("Current URL: " .. FRONTEND_URL .. getCleanBranch(ini.settings.branch) .. "/")
    
    local screen_w, screen_h = getScreenResolution()
    local adj_w, adj_h = getAdjustedResolution(ini.settings.size)
    imgui.Text("Screen Resolution: " .. screen_w .. "x" .. screen_h)
    imgui.Text("Adjusted Resolution: " .. adj_w .. "x" .. adj_h)
    imgui.Text("All changes will be applied after the game is restarted.")
    
    imgui.End()
  end
)

function main() 
    print("CEFMobile "..thisScript().version.. " (webviews library version = "..jar.getVersion().name..") by Radare (t.me/ryderinc) loaded!")
    jar.addLog("CEFMobile "..thisScript().version.. " (webviews library version = "..jar.getVersion().name..") by Radare (t.me/ryderinc) loaded!")
    check = lua_thread.create(visibleInterfaces)
    check.work_in_pause = true
    sampRegisterChatCommand("keyboard", function() keysWindow[0] = not keysWindow[0] end)
    sampRegisterChatCommand("cefsettings", function() cefSettingsWindow[0] = not cefSettingsWindow[0] end)
    while true do wait(0) displayHud(hudToggle) end
end

function onScriptTerminate(script, q) if script == thisScript() then for i, id in ipairs(jar.getBrowsers()) do jar.deleteBrowser(id) end end end

function visibleInterfaces()
    while true do
        wait(0)
        state = (isGamePaused() or (sampIsDialogActive() and focus))
        if state ~= needHide then
            for i, id in ipairs(jar.getBrowsers()) do 
                jar.setVisible(id, not state) 
                jar.setClickableAsync(id, not state)
            end
            needHide = state
        end
    end
end


function jar.onAction(data) 
    if data.type == "PING" and data.msg and data.msg == "STATUS_OK" then 
         callbackConnected = true
    elseif data.type == "WV_ANSWER" then
        CEF.Message(data.msg, tonumber(data.browserid))
    elseif data.type == "WV_DIE" then
        local browser = cjson.decode(data.msg)
        jar.deleteBrowser(data.browserid)
        jar.createBrowser(data.browserid, browser.url)
        jar.setPos(data.browserid, browser.x, browser.y)
        jar.setSize(data.browserid, browser.width, browser.height)
        jar.setVisible(data.browserid, browser.visible)
    elseif data.type == "WV_ERROR" then
        error(data.msg.." browserid: "..data.browserid)
    elseif data.type == "WV_CLOSE" then
        jar.setClickableAsync(browserid, false)
        focus = false
        CEF.ClickStatus(tonumber(data.browserid), false)
        CEF.SendKey(27)
    elseif data.type == "WV_LOADED" then
        browserid = tonumber(data.browserid)
        CEF.BrowserCreated(browserid)
        if queues[browserid] then
            while #queues[browserid] > 0 do
                local item = table.remove(queues[browserid], 1)
                jar.executeJS(browserid, u8(item))
            end
        end
    end
end


function onReceivePacket(id, bs)
    if id == 220 and ini.settings.enabled then
        raknetBitStreamIgnoreBits(bs, 8)
        method = raknetBitStreamReadInt8(bs)
        if method == 17 then
            if not callbackConnected then jar.restartCallback() end
            browserid = raknetBitStreamReadInt32(bs)
            event = readArzString(bs)
            interfaceid = raknetBitStreamReadInt32(bs)

            local eventName, args = event:match("window%.executeEvent%('([^']+)',%s*`([^`]+)`%)")
    
            if eventName == "cef.toggleServerCursor" then
                local focus = args:match("%[(%a+),")
                jar.setClickableAsync(browserid, focus == "true")
                jar.showCloseButton(browserid, focus == "true")
            end

            if jar.getStatus(browserid) then 
                jar.executeJS(browserid, u8(event))
                CEF.LoadedEvent(browserid)
            else
                if queues[browserid] then table.insert(queues[browserid], event) end
            end
        end
        if method == 10 then
            size_w, size_h = raknetBitStreamReadInt32(bs), raknetBitStreamReadInt32(bs)
            pos_x, pos_y = raknetBitStreamReadInt32(bs), raknetBitStreamReadInt32(bs)
            url = readArzString(bs)
            header = readArzString(bs)
            browserid = raknetBitStreamReadInt32(bs)
            
            if ini.settings.size ~= "default" then
                size_w, size_h = getAdjustedResolution(ini.settings.size)
                pos_x, pos_y = getBrowserPosition(ini.settings.size)
            end
            
            if doesDirectoryExist(FRONTEND_DIRECTORY) then
                jar.createBrowserFromFile(browserid, url)
                jar.setSetting(browserid, "setAllowFileAccess", true)
                jar.setSetting(browserid, "setAllowContentAccess", true)
            else
                CDNUrl = string.gsub(url, "file:///", FRONTEND_URL .. getCleanBranch(ini.settings.branch) .. "/")
                jar.createBrowser(browserid, CDNUrl)
            end
            jar.setPos(browserid, pos_x, pos_y)
            jar.setSize(browserid, size_w, size_h)
            jar.setVisible(browserid, true)
            CEF.Message("onSvelteAppInit", tonumber(browserid))
            queues[browserid] = {}
        end
        if method == 16 then
            browserid = raknetBitStreamReadInt32(bs)
            url = readArzString(bs)
            CDNUrl = string.gsub(url, "file:///", FRONTEND_URL .. getCleanBranch(ini.settings.branch) .. "/")
            jar.changeUrl(browserid, CDNUrl)
        end
        if method == 25 then
            browserid = raknetBitStreamReadInt32(bs)
            focus = raknetBitStreamReadBool(bs)
            jar.setClickableAsync(browserid, focus)
            jar.showCloseButton(browserid, focus)
        end
        if method == 14 then
            browserid = raknetBitStreamReadInt32(bs)
            jar.deleteBrowser(browserid)
        end
        if method == 8 then
            hudtype = raknetBitStreamReadInt8(bs)
            if hudtype > 0 then hudToggle = false
            else hudToggle = true end
            return false
        end
        if method == 199 then
            connect = raknetBitStreamReadInt8(bs)
            if connect == 1 then lua_thread.create(cefInfo) end
       end
    end
end

function readArzString(bs)
    length = raknetBitStreamReadInt16(bs)
    encoded = raknetBitStreamReadInt8(bs)
    str = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or raknetBitStreamReadString(bs, length)
    return str
end

function onSendPacket(id, bs)
    if id == 220 and ini.settings.enabled then
        raknetBitStreamIgnoreBits(bs, 8)
        method = raknetBitStreamReadInt8(bs) 
        if method == 63 then return false end
        if method == 66 then return false end
        if method == 78 then return false end
        if method == 109 then return false end
        if method == 140 then CEF.CommandLine("gta_sa.exe -c -h "..select(1, sampGetCurrentServerAddress()).." -p 7777 -n "..(select(1, sampGetPlayerIdByCharHandle(PLAYER_PED)) and sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) or "Test_Arizona").." -mem 4096 -x -seasons -enable_grass -allow_hdr -arizona -auth_cef_enable") return false end
    end
end

-- big thx https://t.me/scripters_lair/497
local crypto = ffi.load("crypto")
local ARIZONA_HMAC_KEY = "\x4A\x8F\x2C\xD1\x73\xE5\xB6\x9A\x1D\x5E\x30\xC7\xF4\x82\x6B\x3F\xA9\x17\x4C\xD8\x60\xEB\x25\x7A\x93\x0B\x58\xF2\xDE\x41\xC6\x8E\x98\x2F\x8A\x42\x91\x44\x37\x71\xCF\xFB\xC0\xB5\xA5\xDB\xB5\xE9\x5B\xC2\x56\x39\xF1\x11\xF1\x59\xA4\x82\x3F\x92\xD5\x5E\x1C\xAB"

ffi.cdef[[
    unsigned char* HMAC(const void* evp_md, const void* key, int key_len,
                        const unsigned char* d, size_t n,
                        unsigned char* md, unsigned int* md_len);
    const void* EVP_sha256(void);
]]

function get_hmac_sha256(key, message)
    local out = ffi.new("unsigned char[32]")
    local outlen = ffi.new("unsigned int[1]")
    crypto.HMAC(crypto.EVP_sha256(), key, #key, message, #message, out, outlen)
    return ffi.string(out, 32)
end

function onReceiveRpc(id,bs)
    if id == 186 then
        if raknetBitStreamGetNumberOfUnreadBits(bs)/8 >= 16 then
            local nonce = raknetBitStreamReadString(bs, 16)
            local tag = get_hmac_sha256(string.sub(ARIZONA_HMAC_KEY, 1, 32), nonce)

            if tag and #tag == 32 then
                local bsOut = raknetNewBitStream()
                raknetBitStreamWriteString(bsOut, tag)
                raknetSendRpcEx(187, bsOut, 1, 9, 0, false)
                raknetDeleteBitStream(bsOut)
            end
        end
    end
end

EXPORTS = {
   canToggle = function() return true end,
   getToggle = function() return cefSettingsWindow[0] end,
   toggle = function() cefSettingsWindow[0] = not cefSettingsWindow[0] end
}