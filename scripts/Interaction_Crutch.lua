--Head


script_name("Interaction Crutch")
script_author("Harm_Dominate")
local imgui = require "mimgui"
local encoding = require "encoding"
encoding.default = "CP1251"
local u8 = encoding.UTF8
local new = imgui.new
local ImVec2 = imgui.ImVec2
local MainWindow = imgui.new.bool(true)
local sampev = require "samp.events"


--Body

imgui.OnInitialize(function()
  theme()
  imgui.GetIO()iniFilename = nil
end)

local rX, rY = getScreenResolution()
local size = imgui.ImVec2(35 * MONET_DPI_SCALE, 35 * MONET_DPI_SCALE)
imgui.OnFrame(
  function() return MainWindow[0] end,
  function(player)
    imgui.SetNextWindowPos(ImVec2(rX / 2, rY / 2), imgui.Cond.FirstUseEver)
   local vsize = imgui.SetNextWindowSize(ImVec2(850 * MONET_DPI_SCALE, 35 * MONET_DPI_SCALE), imgui.Cond.FirstUseEver)
    if imgui.Begin("MainWindow", MainWindow, imgui.WindowFlags.NoDecoration) then
  
  
  if imgui.Button("ESC", size) then
  end
  imgui.SameLine()
  
  
  if imgui.Button("ALT", size) then
    if isCharOnFoot(PLAYER_PED) then
      local data = samp_create_sync_data("player")
      data.keysData = data.keysData + 1024
      local x, y, z = getCharCoordinates(PLAYER_PED)
      data.position = { x, y, z }
      data.send()
    else
      local data = samp_create_sync_data("vehicle")
      data.keysData = data.keysData + 4
      local x, y, z = getCharCoordinates(PLAYER_PED)
      data.position = { x, y, z }
      data.send()
    end
  end
  imgui.SameLine()
  
  
  if imgui.Button("F", size) then
     local data = samp_create_sync_data(isCharOnFoot(PLAYER_PED) and "player" or "vehicle")
    data.keysData = data.keysData + 16
    local x, y, z = getCharCoordinates(PLAYER_PED)
    data.position = { x, y, z }
    data.send()
  end
  imgui.SameLine()
  
  
  if imgui.Button("H", size) then
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
  imgui.SameLine()
  
  
  if imgui.Button("2", size) then
    if isCharInAnyCar(PLAYER_PED) then
      local data = samp_create_sync_data("vehicle")
      data.keysData = data.keysData + 512
      local x, y, z = getCharCoordinates(PLAYER_PED)
      data.position = { x, y, z }
      data.send()
    end
  end
  imgui.SameLine()
  
  
  if imgui.Button("SPC", size) then
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
  imgui.SameLine()
  
  
  if imgui.Button("Y", size) then
    sampSendChat("/invent")
  end
  imgui.SameLine()
  
  
  if imgui.Button("N", size) then
    if isCharOnFoot(PLAYER_PED) then
    local data = samp_create_sync_data("player")
    data.quaternion[4] = 1.1755083638069e-38
    local x, y, z = getCharCoordinates(PLAYER_PED)
    data.position = { x, y, z }
    data.send()
    else
    sampSendChat("/engine")
    end
  end
  imgui.SameLine()
  
  
  if imgui.Button("MASK", size) then
    sampSendChat("/mask")
  end
  imgui.SameLine()
  
  
  if imgui.Button("ARM", size) then
    sampSendChat("/armour")
  end
  imgui.SameLine()
  
  
  if imgui.Button(u8"REPC", size) then
    sampSendChat("/repcar")
  end
  
  imgui.End()
  end
  end
)
  
  
    
  
  
  
  
  
  
  
  
  
  
  
  --Найкрутейшая тема
  function theme()
    local style = imgui.GetStyle();
    local colors = style.Colors;
    style.Alpha = 1;
    style.WindowPadding = imgui.ImVec2(8.00, 8.00);
    style.WindowRounding = 7;
    style.WindowBorderSize = 0;
    style.WindowMinSize = imgui.ImVec2(32.00, 32.00);
    style.WindowTitleAlign = imgui.ImVec2(0.00, 0.50);
    style.ChildRounding = 0;
    style.ChildBorderSize = 1;
    style.PopupRounding = 0;
    style.PopupBorderSize = 1;
    style.FramePadding = imgui.ImVec2(4.00, 3.00);
    style.FrameRounding = 0;
    style.FrameBorderSize = 0;
    style.ItemSpacing = imgui.ImVec2(8.00, 4.00);
    style.ItemInnerSpacing = imgui.ImVec2(4.00, 4.00);
    style.IndentSpacing = 21;
    style.ScrollbarSize = 14;
    style.ScrollbarRounding = 9;
    style.GrabMinSize = 10;
    style.GrabRounding = 0;
    style.TabRounding = 4;
    style.ButtonTextAlign = imgui.ImVec2(0.50, 0.50);
    style.SelectableTextAlign = imgui.ImVec2(0.00, 0.00);
    colors[imgui.Col.Text] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00);
    colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.50, 0.50, 0.50, 1.00);
    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.ChildBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.PopupBg] = imgui.ImVec4(0.08, 0.08, 0.08, 0.94);
    colors[imgui.Col.Border] = imgui.ImVec4(0.43, 0.43, 0.50, 0.50);
    colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.FrameBg] = imgui.ImVec4(0.16, 0.29, 0.48, 0.54);
    colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 0.40);
    colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.26, 0.59, 0.98, 0.67);
    colors[imgui.Col.TitleBg] = imgui.ImVec4(0.04, 0.04, 0.04, 1.00);
    colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.16, 0.29, 0.48, 1.00);
    colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.00, 0.00, 0.00, 0.51);
    colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.14, 0.14, 0.14, 1.00);
    colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.02, 0.02, 0.02, 0.53);
    colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.31, 0.31, 0.31, 1.00);
    colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.41, 0.41, 0.41, 1.00);
    colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.51, 0.51, 0.51, 1.00);
    colors[imgui.Col.CheckMark] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.24, 0.52, 0.88, 1.00);
    colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    colors[imgui.Col.Button] = imgui.ImVec4(0.04, 0.04, 0.04, 1.00);
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.06, 0.53, 0.98, 1.00);
    colors[imgui.Col.Header] = imgui.ImVec4(0.26, 0.59, 0.98, 0.31);
    colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 0.80);
    colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    colors[imgui.Col.Separator] = imgui.ImVec4(0.43, 0.43, 0.50, 0.50);
    colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.10, 0.40, 0.75, 0.78);
    colors[imgui.Col.SeparatorActive] = imgui.ImVec4(0.10, 0.40, 0.75, 1.00);
    colors[imgui.Col.ResizeGrip] = imgui.ImVec4(0.26, 0.59, 0.98, 0.25);
    colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 0.67);
    colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.26, 0.59, 0.98, 0.95);
    colors[imgui.Col.Tab] = imgui.ImVec4(0.18, 0.35, 0.58, 0.86);
    colors[imgui.Col.TabHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 0.80);
    colors[imgui.Col.TabActive] = imgui.ImVec4(0.20, 0.41, 0.68, 1.00);
    colors[imgui.Col.TabUnfocused] = imgui.ImVec4(0.07, 0.10, 0.15, 0.97);
    colors[imgui.Col.TabUnfocusedActive] = imgui.ImVec4(0.14, 0.26, 0.42, 1.00);
    colors[imgui.Col.PlotLines] = imgui.ImVec4(0.61, 0.61, 0.61, 1.00);
    colors[imgui.Col.PlotLinesHovered] = imgui.ImVec4(1.00, 0.43, 0.35, 1.00);
    colors[imgui.Col.PlotHistogram] = imgui.ImVec4(0.90, 0.70, 0.00, 1.00);
    colors[imgui.Col.PlotHistogramHovered] = imgui.ImVec4(1.00, 0.60, 0.00, 1.00);
    colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(0.26, 0.59, 0.98, 0.35);
    colors[imgui.Col.DragDropTarget] = imgui.ImVec4(1.00, 1.00, 0.00, 0.90);
    colors[imgui.Col.NavHighlight] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1.00, 1.00, 1.00, 0.70);
    colors[imgui.Col.NavWindowingDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.20);
    colors[imgui.Col.ModalWindowDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.35);
end
  
  
  
  --Ебанутые RPC махинации
  function samp_create_sync_data(sync_type, copy_from_player)
    local ffi = require 'ffi'
    local sampfuncs = require 'sampfuncs'
    -- from SAMP.Lua
    local raknet = require 'samp.raknet'
    require 'samp.synchronization'

    copy_from_player = copy_from_player or true
    local sync_traits = {
        player = {'PlayerSyncData', raknet.PACKET.PLAYER_SYNC, sampStorePlayerOnfootData},
        vehicle = {'VehicleSyncData', raknet.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData},
        passenger = {'PassengerSyncData', raknet.PACKET.PASSENGER_SYNC, sampStorePlayerPassengerData},
        aim = {'AimSyncData', raknet.PACKET.AIM_SYNC, sampStorePlayerAimData},
        trailer = {'TrailerSyncData', raknet.PACKET.TRAILER_SYNC, sampStorePlayerTrailerData},
        unoccupied = {'UnoccupiedSyncData', raknet.PACKET.UNOCCUPIED_SYNC, nil},
        bullet = {'BulletSyncData', raknet.PACKET.BULLET_SYNC, nil},
        spectator = {'SpectatorSyncData', raknet.PACKET.SPECTATOR_SYNC, nil}
    }
    local sync_info = sync_traits[sync_type]
    local data_type = 'struct ' .. sync_info[1]
    local data = ffi.new(data_type, {})
    local raw_data_ptr = tonumber(ffi.cast('uintptr_t', ffi.new(data_type .. '*', data)))
    -- copy player's sync data to the allocated memory
    if copy_from_player then
        local copy_func = sync_info[3]
        if copy_func then
            local _, player_id
            if copy_from_player == true then
                _, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            else
                player_id = tonumber(copy_from_player)
            end
            copy_func(player_id, raw_data_ptr)
        end
    end
    -- function to send packet
    local func_send = function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, sync_info[2])
        raknetBitStreamWriteBuffer(bs, raw_data_ptr, ffi.sizeof(data))
        raknetSendBitStreamEx(bs, sampfuncs.HIGH_PRIORITY, sampfuncs.UNRELIABLE_SEQUENCED, 1)
        raknetDeleteBitStream(bs)
    end
    -- metatable to access sync data and 'send' function
    local mt = {
        __index = function(t, index)
            return data[index]
        end,
        __newindex = function(t, index, value)
            data[index] = value
        end
    }
    return setmetatable({send = func_send}, mt)
end



function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('kostil', function()
        MainWindow[0] = not MainWindow[0]
    end)
    wait(-1)
end

  
  
