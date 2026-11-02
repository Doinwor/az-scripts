script_name('Watermarks')
script_version('1488')
script_author('Huesos and gemini')

local imgui = require 'mimgui'
local ffi = require 'ffi'
local encoding = require 'encoding'
local lfs = require 'lfs'

encoding.default = 'CP1251'
local u8 = encoding.UTF8
local new = imgui.new

-- == VARIABLES ==
local show_settings = new.bool(false)
local edit_mode = new.bool(false)

local image_windows = {}
local available_images = {}
local loaded_textures = {}

local config_dir = getWorkingDirectory() .. '/config/'
local config_path = config_dir .. 'floating_images_v1_2.lua'
local images_dir = getWorkingDirectory() .. '/images/'

if not doesDirectoryExist(config_dir) then createDirectory(config_dir) end
if not doesDirectoryExist(images_dir) then createDirectory(images_dir) end

local function generate_uuid()
    return string.format("%os%d", os.time(), math.random(1000, 9999))
end

-- == IMAGE SCANNING ==
local function scanImages()
    available_images = {}
    if lfs.attributes(images_dir, "mode") == "directory" then
        for file in lfs.dir(images_dir) do
            -- Added .gif to supported formats
            if file:match("%.png$") or file:match("%.jpg$") or file:match("%.gif$") then
                table.insert(available_images, file)
            end
        end
    end
end

local function getTexture(filename)
    if not loaded_textures[filename] then
        local filepath = images_dir .. filename
        if doesFileExist(filepath) then
            -- Mimgui handles transparency in PNG automatically
            loaded_textures[filename] = imgui.CreateTextureFromFile(filepath)
        end
    end
    return loaded_textures[filename]
end

-- == SAVE / LOAD ==
local function saveConfig()
    local file = io.open(config_path, "w")
    if file then
        file:write("return {\n    list = {\n")
        for _, win in ipairs(image_windows) do
            file:write(string.format(
                '        {uid="%s", file="%s", x=%d, y=%d, w=%d, h=%d, cmd="%s", clickable=%s},\n', 
                win.uid, win.file, win.x, win.y, win.w, win.h, win.cmd or "", tostring(win.clickable)
            ))
        end
        file:write("    }\n}\n")
        file:close()
    end
end

local function loadConfig()
    if not doesFileExist(config_path) then return end
    local f = loadfile(config_path)
    if f then
        local success, result = pcall(f)
        if success and result.list then 
            image_windows = result.list 
            for _, win in ipairs(image_windows) do
                if win.clickable == nil then win.clickable = false end
            end
        end
    end
end

imgui.OnInitialize(function()
    imgui.GetStyle().WindowRounding = 5.0
    loadConfig()
    scanImages()
end)

-- == RENDER ==
imgui.OnFrame(function() return true end, function(player)
    
    -- 1. MANAGER MENU
    if show_settings[0] then
        imgui.SetNextWindowSize(imgui.ImVec2(450, 550), imgui.Cond.FirstUseEver)
        if imgui.Begin('WT', show_settings) then
            if imgui.Button('Refresh Folder', imgui.ImVec2(-1, 30)) then scanImages() end
            
            imgui.Separator()
            imgui.Checkbox('EDIT MODE (Unlock & Move)', edit_mode)
            imgui.Separator()

            if #image_windows > 0 then
                imgui.Text("Active Images:")
                for i = #image_windows, 1, -1 do
                    local win = image_windows[i]
                    if imgui.CollapsingHeader(win.file .. "##" .. win.uid) then
                        -- Size Sliders
                        local pw, ph = new.int(win.w), new.int(win.h)
                        if imgui.SliderInt("Width##"..win.uid, pw, 10, 2000) then win.w = pw[0]; saveConfig() end
                        if imgui.SliderInt("Height##"..win.uid, ph, 10, 2000) then win.h = ph[0]; saveConfig() end
                        
                        -- Command Logic
                        local p_cmd = new.char[256](win.cmd or "")
                        if imgui.InputText("Command##"..win.uid, p_cmd, 256) then
                            win.cmd = ffi.string(p_cmd)
                            saveConfig()
                        end
                        
                        -- Clickable toggle
                        local p_click = new.bool(win.clickable)
                        if imgui.Checkbox("Enable Click-to-Command##"..win.uid, p_click) then
                            win.clickable = p_click[0]
                            saveConfig()
                        end

                        if imgui.Button("Remove##"..win.uid) then table.remove(image_windows, i); saveConfig() end
                    end
                end
                imgui.Separator()
            end

            imgui.Text("Available Files:")
            imgui.BeginChild("Files", imgui.ImVec2(-1, -1), true)
            for _, file in ipairs(available_images) do
                imgui.Text(file)
                imgui.SameLine(imgui.GetWindowWidth() - 70)
                if imgui.Button('Add##'..file) then
                    table.insert(image_windows, {uid=generate_uuid(), file=file, x=500, y=500, w=150, h=150, cmd="", clickable=false})
                    saveConfig()
                end
            end
            imgui.EndChild()
            imgui.End()
        end
    end

    -- 2. IMAGE WINDOWS
    for i, win in ipairs(image_windows) do
        local flags = imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoResize
        
        if not edit_mode[0] then
            flags = flags + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoBackground
            -- If NOT clickable and NOT in edit mode, pass clicks through to the game
            if not win.clickable then
                flags = flags + imgui.WindowFlags.NoInputs
            end
            imgui.SetNextWindowPos(imgui.ImVec2(win.x, win.y), imgui.Cond.Always)
        else
            imgui.SetNextWindowPos(imgui.ImVec2(win.x, win.y), imgui.Cond.FirstUseEver)
        end

        imgui.SetNextWindowSize(imgui.ImVec2(win.w, win.h + (edit_mode[0] and 35 or 0)), imgui.Cond.Always)
        
        if not edit_mode[0] then imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0)) end

        if imgui.Begin("Img##"..win.uid, nil, flags) then
            if edit_mode[0] then
                local pos = imgui.GetWindowPos()
                if pos.x ~= win.x or pos.y ~= win.y then win.x, win.y = pos.x, pos.y; saveConfig() end
            end

            local tex = getTexture(win.file)
            if tex then
                local size = imgui.GetContentRegionAvail()
                
                -- Transparent Background Button (ImageButton)
                -- This allows the image to react to clicks
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0,0,0,0))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,1,1,0.1))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(1,1,1,0.2))
                
                if imgui.ImageButton(tex, size) then
                    if not edit_mode[0] and win.clickable and win.cmd ~= "" then
                        sampProcessChatInput(u8:decode(win.cmd))
                    end
                end
                
                imgui.PopStyleColor(3)
            end
            imgui.End()
        end
        if not edit_mode[0] then imgui.PopStyleVar() end
    end
end)

function main()
    while not isSampAvailable() do wait(100) end
    sampRegisterChatCommand('fimg', function() show_settings[0] = not show_settings[0] end)
    wait(-1)
end