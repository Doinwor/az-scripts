local imgui = require 'mimgui'
local encoding = require 'encoding'
local ffi = require 'ffi'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local new = imgui.new

local renderWindow = new.bool(true)

    if doesFileExist("buttons.json") then
        sampAddChatMessage("Файл загружен!",-1)
    else
    	local file = io.open("buttons.json", "a")        
        file:write('{"Нарко" : ["/usedrugs 3"], "Броник(надеть)" : ["/armour"]}')
        file:close()
    end
local newButtonNameInput = imgui.new.char(255)
        local newButtonCommandInput = imgui.new.char(255)
function jsonSave(jsonFilePath, t)
    file = io.open(jsonFilePath, "w")
    file:write(encodeJson(t))
    file:flush()
    file:close()
end
    
function jsonRead(jsonFilePath)
    local file, err = io.open(jsonFilePath, "r")
    if not file then
        print("Error opening file: " .. err)
        return nil  -- или можно вернуть пустую таблицу {}
    end
    local jsonInString = file:read("*a")
    file:close()
    local jsonTable = decodeJson(jsonInString)
    return jsonTable
end

local tableButtons = jsonRead("buttons.json")


local function darktheme_custom()
    local style = imgui.GetStyle();
    local colors = style.Colors;
    imgui.SwitchContext()
    style.Alpha = 1;
    style.WindowPadding = imgui.ImVec2(8.00, 8.00);
    style.WindowRounding = 7;
    style.WindowBorderSize = 0;
    style.WindowMinSize = imgui.ImVec2(32.00, 32.00);
    style.WindowTitleAlign = imgui.ImVec2(0.50, 0.50);
    style.ChildRounding = 0;
    style.ChildBorderSize = 1;
    style.PopupRounding = 0;
    style.PopupBorderSize = 1;
    style.FramePadding = imgui.ImVec2(6.00, 2.00);
    style.FrameRounding = 11;
    style.FrameBorderSize = 0;
    style.ItemSpacing = imgui.ImVec2(14.00, 5.00);
    style.ItemInnerSpacing = imgui.ImVec2(10.00, 4.00);
    style.IndentSpacing = 20;
    style.ScrollbarSize = 13;
    style.ScrollbarRounding = 9;
    style.GrabMinSize = 11;
    style.GrabRounding = 12;
    style.TabRounding = 4;
    style.ButtonTextAlign = imgui.ImVec2(0.50, 0.50);
    style.SelectableTextAlign = imgui.ImVec2(0.00, 0.00);
    colors[imgui.Col.Text] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00);
    colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.67, 0.62, 0.62, 1.00);
    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.00, 0.00, 0.00, 1.00);
    colors[imgui.Col.ChildBg] = imgui.ImVec4(0.00, 0.00, 0.00, 1.00);
    colors[imgui.Col.PopupBg] = imgui.ImVec4(0.08, 0.08, 0.08, 0.94);
    colors[imgui.Col.Border] = imgui.ImVec4(0.43, 0.43, 0.50, 0.50);
    colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.FrameBg] = imgui.ImVec4(0.07, 0.08, 0.08, 1.00);
    colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.03, 0.03, 0.03, 0.40);
    colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.10, 0.10, 0.11, 0.67);
    colors[imgui.Col.TitleBg] = imgui.ImVec4(0.04, 0.04, 0.04, 1.00);
    colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.00, 0.00, 0.00, 1.00);
    colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.00, 0.00, 0.00, 0.51);
    colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.14, 0.14, 0.14, 1.00);
    colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.02, 0.02, 0.02, 0.53);
    colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.31, 0.31, 0.31, 1.00);
    colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.41, 0.41, 0.41, 1.00);
    colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.51, 0.51, 0.51, 1.00);
    colors[imgui.Col.CheckMark] = imgui.ImVec4(0.33, 0.42, 0.53, 1.00);
    colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.32, 0.33, 0.35, 1.00);
    colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.24, 0.26, 0.27, 1.00);
    colors[imgui.Col.Button] = imgui.ImVec4(0.25, 0.28, 0.32, 0.39);
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.17, 0.18, 0.20, 1.00);
    colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.21, 0.22, 0.24, 1.00);
    colors[imgui.Col.Header] = imgui.ImVec4(0.19, 0.21, 0.23, 0.31);
    colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.16, 0.17, 0.18, 0.80);
    colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.13, 0.15, 0.17, 1.00);
    colors[imgui.Col.Separator] = imgui.ImVec4(0.19, 0.19, 0.21, 1.00);
    colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.13, 0.15, 0.18, 0.78);
    colors[imgui.Col.SeparatorActive] = imgui.ImVec4(0.12, 0.13, 0.15, 1.00);
    colors[imgui.Col.ResizeGrip] = imgui.ImVec4(0.35, 0.37, 0.40, 0.25);
    colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.09, 0.10, 0.10, 0.67);
    colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.10, 0.11, 0.12, 0.95);
    colors[imgui.Col.Tab] = imgui.ImVec4(0.07, 0.07, 0.08, 0.92);
    colors[imgui.Col.TabHovered] = imgui.ImVec4(0.05, 0.06, 0.06, 0.80);
    colors[imgui.Col.TabActive] = imgui.ImVec4(0.10, 0.10, 0.11, 1.00);
    colors[imgui.Col.TabUnfocused] = imgui.ImVec4(0.08, 0.09, 0.09, 0.97);
    colors[imgui.Col.TabUnfocusedActive] = imgui.ImVec4(0.13, 0.14, 0.16, 1.00);
    colors[imgui.Col.PlotLines] = imgui.ImVec4(0.61, 0.61, 0.61, 1.00);
    colors[imgui.Col.PlotLinesHovered] = imgui.ImVec4(0.24, 0.20, 0.20, 1.00);
    colors[imgui.Col.PlotHistogram] = imgui.ImVec4(0.90, 0.70, 0.00, 1.00);
    colors[imgui.Col.PlotHistogramHovered] = imgui.ImVec4(1.00, 0.60, 0.00, 1.00);
    colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(0.32, 0.32, 0.35, 0.55);
    colors[imgui.Col.DragDropTarget] = imgui.ImVec4(1.00, 1.00, 0.00, 0.90);
    colors[imgui.Col.NavHighlight] = imgui.ImVec4(0.08, 0.09, 0.10, 1.00);
    colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1.00, 1.00, 1.00, 0.70);
    colors[imgui.Col.NavWindowingDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.20);
    colors[imgui.Col.ModalWindowDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.35);
end

imgui.OnInitialize(function()
    darktheme_custom()
end)

local newFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 400, 400
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, 400), imgui.Cond.FirstUseEver)
        imgui.Begin('Окошко', renderWindow, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoBackground + imgui.WindowFlags.NoResize)
        for key, commands in pairs(tableButtons) do
    if imgui.Button(u8(key)) then
        -- Запускаем поток, который последовательно отправляет команды
        lua_thread.create(function()
            for i = 1, #commands do
                sampSendChat(commands[i])
                wait(1500)  -- Ждем 1.5 секунды перед отправкой следующей команды
            end
        end)
    end
end
        if imgui.Button(u8"Нарко") then
            sampSendChat("/usedrugs 3")
        end
        if imgui.Button(u8"Сбить аним") then
            sampSendChat("Ай")
        end
        imgui.SameLine()
        if imgui.Button(u8"Достать телефон") then
            sampSendChat("/phone")
        end
        if imgui.Button(u8'Убрать оружие') then
            setCurrentCharWeapon(PLAYER_PED, 0) -- скроллит на фист
        end
        imgui.End()
    end
)




local showAddButtonPanel = imgui.new.bool(false)
local renderWindowMenu = new.bool(false)

local newFrameTwo = imgui.OnFrame(
    function() return renderWindowMenu[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 300, 300
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('Buttons Menu', renderWindowMenu)
        imgui.Text(u8'Кнопка удаляется при нажатии на нее')
        for key, _ in pairs(tableButtons) do
            if imgui.Button(u8(key)) then
                tableButtons[key] = nil
                jsonSave("buttons.json", tableButtons)
            end
        end
        
        -- Добавляем кнопку для добавления новой кнопки
        if imgui.Button(u8"Добавить") then
            showAddButtonPanel[0] = not showAddButtonPanel[0]  -- Переключаем видимость панели добавления кнопки
        end

        
        
        imgui.End()
    end
)

local newFrameThird = imgui.OnFrame(
    function() return showAddButtonPanel[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 300, 300
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('Buttons Menu Add', showAddButtonPanel)
        
            imgui.InputText(u8"Название кнопки", newButtonNameInput, 256)
            imgui.InputTextMultiline(u8"То, что будет писаться в чат", newButtonCommandInput, 512)
            newButtonName = u8:decode(ffi.string(newButtonNameInput))
            newButtonCommand = u8:decode(ffi.string(newButtonCommandInput))
            if imgui.Button(u8"Сохранить") then
                if newButtonName ~= "" and newButtonCommand ~= "" then
                    -- Разделяем команды на основе символа новой строки
                    local commands = {}
                    for command in string.gmatch(newButtonCommand, "[^\n]+") do
                        table.insert(commands, command)
                    end
                    
                    -- Сохраняем новую кнопку в tableButtons
                    tableButtons[newButtonName] = commands
                    jsonSave("buttons.json", tableButtons)
                    
                    sampAddChatMessage("Успешно!", -1)
                end
            end
        
        imgui.End()
    end
)

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('buttons.m', function()
        renderWindowMenu[0] = not renderWindowMenu[0]
    end)
    sampRegisterChatCommand('buttons.set', function()
        renderWindow[0] = not renderWindow[0]
    end)
    while true do
        wait(0)

    end
end