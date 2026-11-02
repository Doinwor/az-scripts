script_name("Mimgui Dialog")
script_version("1.0 alpha version")

local sampev = require("lib.samp.events")
local ffi = require("ffi")

local lfs = require("lfs")
local fa = require("fAwesome6_solid")
local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local new = imgui.new

title = ""
text = ""
button1 = ""
button2 = ""
dialogID = ""

local ICONS_DIR = getWorkingDirectory() .. "/resource/icons/"

if not doesDirectoryExist(ICONS_DIR) then
    createDirectory(ICONS_DIR)
end

local icon_names = { 'bug.png', 'circle-info.png', 'crown.png', 'gears.png', 'hammer.png', 'money-check.png', 'phone.png',
    'user-secret.png', 'user.png', 'users.png', 'wallet.png', 'snowflake.png', 'bussines.png', 'car.png', 'family.png', 'gift.png',
    'house.png', 'leaders.png', 'license.png', 'passport.png', 'quest.png'
}

local base_url = "https://raw.githubusercontent.com/Theopochka/Icons-/refs/heads/main/icons/"
local icon_links = {}
for _, name in ipairs(icon_names) do
    icon_links[#icon_links + 1] = {
        ICONS_DIR .. name,
        base_url .. name
    }
end

--local statsrender = new.bool()
local windowmm    = new.bool()
local windowmm2   = new.bool()

local button_mm1_size = imgui.ImVec2(123 * MONET_DPI_SCALE, 120 * MONET_DPI_SCALE)
local button_mm2_size = imgui.ImVec2(123 * MONET_DPI_SCALE, 120 * MONET_DPI_SCALE)

function sampev.onShowDialog(did, style, dialogTitle, b1, b2, dialogText)
    --sampAddChatMessage(did, -1)
    --[[if did == 0 then
        title    = dialogTitle
        text     = dialogText
        button1  = b1
        button2  = b2
        dialogID = did

        statsrender[0] = true
        return false
    end]]
    if did == 722 then
        windowmm[0] = true
        return false
    end
    if did == 600 then
        windowmm2[0] = true
        return false
    end
end

local images = {}
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    fa.Init(15)

    for i, file in ipairs(listFiles(ICONS_DIR)) do
        local iconname = file:match("([^/\\]+)%.png$")
        images[iconname] = imgui.CreateTextureFromFile(file)
    end
    xey()
end)

function removeColorCodes(str)
    return str:gsub("{%x%x%x%x%x%x}", "")
end
imgui.OnFrame(
    function() return windowmm[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        if imgui.Begin(u8 'mm1', windowmm, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoMove) then
            -- Персонаж
            if imgui.IconButtonWithText(images['user'], button_mm1_size, u8 "Персонаж") then
                sampSendDialogResponse(722, 1, 0, nil)
                windowmm[0] = false
            end
            imgui.SameLine()
            
            -- Хелп меню
            if imgui.IconButtonWithText(images['hammer'], button_mm1_size, u8 " Хелп меню") then
                sampSendDialogResponse(722, 1, 1, nil)
                windowmm[0] = false
            end
            imgui.SameLine()

            -- Репорт
            if imgui.IconButtonWithText(images['bug'], button_mm1_size, u8 " Репорт") then
                sampSendChat("/rep")
                windowmm[0] = false
            end
            imgui.SameLine()

            -- Хелп меню
            if imgui.IconButtonWithText(images['circle-info'], button_mm1_size, u8 " Хелп меню") then
                sampSendChat("/help")
                windowmm[0] = false
            end
            imgui.SameLine()

            -- Настройки
            if imgui.IconButtonWithText(images['gears'], button_mm1_size, u8 " Настройки") then
                sampSendChat("/settings")
                windowmm[0] = false
            end
            imgui.SameLine()

            -- Донат
            if imgui.IconButtonWithText(images['money-check'], button_mm1_size, u8 " Донат") then
                sampSendChat("/donate")
                windowmm[0] = false
            end

            -- нижний полоска
            if imgui.IconButtonWithText(images['phone'], button_mm1_size, u8 " Телефон") then
                sampSendChat("/phone")
                windowmm[0] = false
            end
            imgui.SameLine()

            -- История ников
            if imgui.IconButtonWithText(images['users'], button_mm1_size, u8 " История ников") then
                sampSendDialogResponse(722, 1, 7, nil)
                windowmm[0] = false
            end
            imgui.SameLine()

            -- Наказания
            if imgui.IconButtonWithText(images['user-secret'], button_mm1_size, u8 " Наказания") then
                sampSendDialogResponse(722, 1, 8, nil)
                windowmm[0] = false
            end
            imgui.SameLine()

            -- Премиум игроки
            if imgui.IconButtonWithText(images['crown'], button_mm1_size, u8 " Премиум игроки") then
                sampSendDialogResponse(722, 1, 9, nil)
                windowmm[0] = false
            end
            imgui.SameLine()

            -- Промо-код
            if imgui.IconButtonWithText(images['wallet'], button_mm1_size, u8 " Промо-код") then
                sampSendDialogResponse(722, 1, 10, nil)
                windowmm[0] = false
            end
            imgui.SameLine()

            -- адвент календарь
            if imgui.IconButtonWithText(images['snowflake'], button_mm1_size, u8 " Календарь") then
                sampSendDialogResponse(722, 1, 12, nil)
                windowmm[0] = false
            end

            if imgui.Button(fa.XMARK .. u8 " Закрыть", imgui.ImVec2(-1 * MONET_DPI_SCALE, 20 * MONET_DPI_SCALE)) then
                windowmm[0] = false
            end
            imgui.End()
        end
    end
)
imgui.OnFrame(
    function() return windowmm2[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        if imgui.Begin('mm2', windowmm2, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoMove) then
            if imgui.IconButtonWithText(images['user'], button_mm2_size, u8 " Статистика") then
                sampSendDialogResponse(600, 1, 0, nil)
                windowmm2[0] = false
            end

            imgui.SameLine()
            if imgui.IconButtonWithText(images['car'], button_mm2_size, u8 " Автомобиль") then
                sampSendDialogResponse(600, 1, 1, nil)
                windowmm2[0] = false
            end

            imgui.SameLine()
            if imgui.IconButtonWithText(images['house'], button_mm2_size, u8 " Дом") then
                sampSendDialogResponse(600, 1, 2, nil)
                windowmm2[0] = false
            end

            imgui.SameLine()
            if imgui.IconButtonWithText(images['bussines'], button_mm2_size, u8 " Бизнес") then
                sampSendDialogResponse(600, 1, 3, nil)
                windowmm2[0] = false
            end

            imgui.SameLine()
            if imgui.IconButtonWithText(images['leaders'], button_mm2_size, u8 " Меню лидера") then
                sampSendDialogResponse(600, 1, 4, nil)
                windowmm2[0] = false
            end
            
            -- нижния полоска
            if imgui.IconButtonWithText(images['gift'], button_mm2_size, u8 " Улучшения") then
                sampSendDialogResponse(600, 1, 5, nil)
                windowmm2[0] = false
            end

            imgui.SameLine()
            if imgui.IconButtonWithText(images['license'], button_mm2_size, u8 " Лицензии") then
                sampSendDialogResponse(600, 1, 6, nil)
                windowmm2[0] = false
            end

            imgui.SameLine()
            if imgui.IconButtonWithText(images['passport'], button_mm2_size, u8 " Паспорт") then
                sampSendDialogResponse(600, 1, 7, nil)
                windowmm2[0] = false
            end

            imgui.SameLine()
            if imgui.IconButtonWithText(images['quest'], button_mm2_size, u8 " Квесты") then
                sampSendDialogResponse(600, 1, 8, nil)
                windowmm2[0] = false
            end

            imgui.SameLine()
            if imgui.IconButtonWithText(images['family'], button_mm2_size, u8 " Меню семьи") then
                sampSendDialogResponse(600, 1, 9, nil)
                windowmm2[0] = false
            end
            if imgui.Button(fa.XMARK .. u8 " Закрыть", imgui.ImVec2(-1 * MONET_DPI_SCALE, 20 * MONET_DPI_SCALE)) then
                windowmm2[0] = false
            end
            imgui.End()
        end
    end
)
function main()
    local needReinstall = false
    if #listFiles(ICONS_DIR) ~= #icon_links then
        needReinstall = true
    end

    if needReinstall then
        local pool = ThreadHelper.newThreadPool(icon_links, function(file)
            local requests = require("requests")
            local http = require("socket.http")
            local ltn12 = require("ltn12")
            http.request({ method = "GET", url = file[2], sink = ltn12.sink.file(io.open(file[1], "wb")) })

            return true
        end)

        pool:run()

        pool:listen(function(result, err, index)
            if err then
                print("An error occurred while downloading icon: " .. err)
            else
                print("Icon " .. icon_links[index][1] .. " downloaded successfully")
            end
        end)
    end

    while not isSampAvailable() do wait(0) end
    wait(-1)
end

function imgui.TextColoredRGB(text)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local ImVec4 = imgui.ImVec4
    local explode_argb = function(argb)
        local a = bit.band(bit.rshift(argb, 24), 0xFF)
        local r = bit.band(bit.rshift(argb, 16), 0xFF)
        local g = bit.band(bit.rshift(argb, 8), 0xFF)
        local b = bit.band(argb, 0xFF)
        return a, r, g, b
    end
    local getcolor = function(color)
        if color:sub(1, 6):upper() == 'SSSSSS' then
            local r, g, b = colors[1].x, colors[1].y, colors[1].z
            local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
            return ImVec4(r, g, b, a / 255)
        end
        local color = type(color) == 'string' and tonumber(color, 16) or color
        if type(color) ~= 'number' then return end
        local r, g, b, a = explode_argb(color)
        return imgui.ImVec4(r / 255, g / 255, b / 255, a / 255)
    end
    local render_text = function(text_)
        for w in text_:gmatch('[^\r\n]+') do
            local text, colors_, m = {}, {}, 1
            w = w:gsub('{(......)}', '{%1FF}')
            while w:find('{........}') do
                local n, k = w:find('{........}')
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end
                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end
            if text[0] then
                for i = 0, #text do
                    imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else
                imgui.Text(u8(w))
            end
        end
    end
    render_text(text)
end

function imgui.IconButtonWithText(icon_texture, button_size, label, colors)
    local icon_size = imgui.ImVec2(button_size.x * 0.543, button_size.y * 0.543)

    colors = colors or {
        normal = imgui.GetColorU32(imgui.Col.Button),
        hover = imgui.GetColorU32(imgui.Col.ButtonHovered),
        border = imgui.GetColorU32(imgui.Col.ButtonHovered),
        hover_border = imgui.GetColorU32(imgui.Col.Button),
        text = imgui.GetColorU32(imgui.Col.Text)
    }

    local style = imgui.GetStyle()
    local rounding = style.FrameRounding

    local draw_list = imgui.GetWindowDrawList()
    local cursor_pos = imgui.GetCursorScreenPos()

    local icon_width, icon_height = icon_size.x, icon_size.y
    local text_size = imgui.CalcTextSize(label)

    -- Button size is exactly the specified size
    local button_width = button_size.x
    local button_height = button_size.y

    imgui.InvisibleButton("##" .. label, button_size)
    local is_hovered = imgui.IsItemHovered()
    local is_clicked = imgui.IsItemClicked()

    local bg_color = is_hovered and colors.hover or colors.normal
    local border_color = is_hovered and colors.hover_border or colors.border

    -- Background rectangle
    draw_list:AddRectFilled(cursor_pos, imgui.ImVec2(cursor_pos.x + button_width, cursor_pos.y + button_height), bg_color,
        rounding)

    -- Border rectangle
    draw_list:AddRect(cursor_pos, imgui.ImVec2(cursor_pos.x + button_width, cursor_pos.y + button_height), border_color,
        rounding)

    -- Icon
    local icon_x = cursor_pos.x + (button_width - icon_width) * 0.5
    local icon_y = cursor_pos.y + (button_height - icon_height - text_size.y) * 0.5
    draw_list:AddImage(icon_texture, imgui.ImVec2(icon_x, icon_y),
        imgui.ImVec2(icon_x + icon_width, icon_y + icon_height))

    -- Text
    local text_x = cursor_pos.x + (button_width - text_size.x) * 0.5
    local text_y = icon_y + icon_height + 2
    draw_list:AddText(imgui.ImVec2(text_x, text_y), colors.text, label)

    return is_clicked
end

function listFiles(path, recursive)
    recursive = recursive or false
    local files = {}

    local function scan_dir(dir)
        for file in lfs.dir(dir) do
            if file ~= "." and file ~= ".." then
                local full_path = dir .. "/" .. file
                local attributes = lfs.attributes(full_path)

                if attributes.mode == "file" then
                    table.insert(files, full_path)
                elseif attributes.mode == "directory" and recursive then
                    scan_dir(full_path)
                end
            end
        end
    end

    local attributes = lfs.attributes(path)
    if attributes and attributes.mode == "directory" then
        scan_dir(path)
    else
        error("Invalid directory: " .. path)
    end

    return files
end

local effil = require("effil")

ThreadHelper = {}

local function awaitThread(thread)
    while thread:status() == "running" do
        wait(0)
    end
    return thread:status()
end

--- Создает новый поток
---@param func fun(...): boolean, any
---@return table
function ThreadHelper.newThread(func)
    if type(func) ~= "function" then
        error("Expected function, got " .. type(func))
    end

    local h = {}
    h.runner = effil.thread(func)
    h.thread = nil ---@type ThreadHandle

    ---Запускает поток
    ---@return table
    function h:start(...)
        if self.thread then
            error("Thread already running")
        end
        self.thread = self.runner(...)
        return self
    end

    ---Синхронно ожидает завершения потока
    ---@return string? value
    ---@return string? err
    ---@return string? stacktrace
    function h:await()
        if not self.thread then
            error("Thread is not running")
        end

        local status, err, stack = awaitThread(self.thread)
        if status == "failed" then
            return nil, err, stack
        end

        local success, result = self.thread:get()
        if success then
            return result
        else
            return nil, result
        end
    end

    ---Асинхронное ожидание завершения потока
    ---@param cb? fun(value: any, err:string?, stacktrace:string?)
    function h:listen(cb)
        cb = cb or function(val, err, stack)
            if err then print(err .. "\n" .. stack) end
        end

        if not self.thread then
            error("Thread is not running")
        end

        lua_thread.create(function()
            local status, err, stack = awaitThread(self.thread)
            if status == "failed" then
                cb(nil, err, stack)
                return
            end
            local success, result = self.thread:get()
            if success then
                cb(result)
            else
                cb(nil, result)
            end
        end)
    end

    function h:stop()
        if self.thread and self.thread:status() == "running" then
            self.thread:cancel()
        end
        self.thread = nil
    end

    return h
end

--- Создает пул потоков
---@param array table
---@param func fun(...): boolean, any
function ThreadHelper.newThreadPool(array, func)
    local self = {}
    self.threads = {}

    for _, v in ipairs(array) do
        table.insert(self.threads, {
            thread = ThreadHelper.newThread(func),
            args = v,
        })
    end

    function self:run()
        for _, t in ipairs(self.threads) do
            t.thread:start(t.args)
        end
    end

    ---@param cb fun(value: any, err: string?, index: number)
    function self:listen(cb)
        cb = cb or function(result, index)
            if result then
                print("Result from thread " .. index .. ": " .. tostring(result))
            else
                print("Error from thread " .. index)
            end
        end

        lua_thread.create(function()
            while #self.threads > 0 do
                for k, t in ipairs(self.threads) do
                    local thread = t.thread
                    if thread.thread and thread.thread:status() ~= "running" then
                        local result, err, stack = thread:await()
                        if result then
                            cb(result, nil, k)       -- Успех
                        else
                            cb(nil, err or stack, k) -- Ошибка
                        end
                        table.remove(self.threads, k)
                    end
                end
                wait(0)
            end
        end)
    end

    function self:stopAll()
        for _, t in ipairs(self.threads) do
            t.thread:stop()
        end
        self.threads = {}
    end

    return self
end

function xey()
    local style = imgui.GetStyle();
    local colors = style.Colors;
    style.Alpha = 1;
    style.WindowPadding = imgui.ImVec2(8.00, 8.00);
    style.WindowRounding = 12;
    style.WindowBorderSize = 1;
    style.WindowMinSize = imgui.ImVec2(32.00, 32.00);
    style.WindowTitleAlign = imgui.ImVec2(0.50, 0.50);
    style.ChildRounding = 11;
    style.ChildBorderSize = 1;
    style.PopupRounding = 12;
    style.PopupBorderSize = 1;
    style.FramePadding = imgui.ImVec2(4.00, 3.00);
    style.FrameRounding = 12;
    style.FrameBorderSize = 0;
    style.ItemSpacing = imgui.ImVec2(8.00, 4.00);
    style.ItemInnerSpacing = imgui.ImVec2(4.00, 4.00);
    style.IndentSpacing = 21;
    style.ScrollbarSize = 14;
    style.ScrollbarRounding = 12;
    style.GrabMinSize = 10;
    style.GrabRounding = 8;
    style.TabRounding = 12;

    style.ButtonTextAlign = imgui.ImVec2(0.50, 0.50);
    style.SelectableTextAlign = imgui.ImVec2(0.00, 0.00);
    colors[imgui.Col.Text] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00);
    colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.50, 0.50, 0.50, 1.00);
    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.60, 0.56, 0.45, 1.00);
    colors[imgui.Col.ChildBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.PopupBg] = imgui.ImVec4(0.08, 0.08, 0.08, 0.94);
    colors[imgui.Col.Border] = imgui.ImVec4(0.00, 0.00, 0.00, 0.50);
    colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.FrameBg] = imgui.ImVec4(0.29, 0.27, 0.19, 0.54);
    colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 0.40);
    colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.26, 0.59, 0.98, 0.67);
    colors[imgui.Col.TitleBg] = imgui.ImVec4(0.32, 0.29, 0.21, 1.00);
    colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.37, 0.34, 0.25, 1.00);
    colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.00, 0.00, 0.00, 0.51);
    colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.14, 0.14, 0.14, 1.00);
    colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.02, 0.02, 0.02, 0.53);
    colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.31, 0.31, 0.31, 1.00);
    colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.41, 0.41, 0.41, 1.00);
    colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.51, 0.51, 0.51, 1.00);
    colors[imgui.Col.CheckMark] = imgui.ImVec4(0.76, 0.72, 0.60, 1.00);
    colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.24, 0.52, 0.88, 1.00);
    colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    colors[imgui.Col.Button] = imgui.ImVec4(0.40, 0.35, 0.28, 1.00);
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.70, 0.65, 0.50, 1.00);
    colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.80, 0.75, 0.60, 1.00);
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

function dark_grey()
    local style = imgui.GetStyle();
    local colors = style.Colors;
    style.Alpha = 1;
    style.WindowPadding = imgui.ImVec2(8.00, 8.00);
    style.WindowRounding = 7;
    style.WindowBorderSize = 0;
    style.WindowMinSize = imgui.ImVec2(32.00, 32.00);
    style.WindowTitleAlign = imgui.ImVec2(0.00, 0.50);
    style.ChildRounding = 12;
    style.ChildBorderSize = 1;
    style.PopupRounding = 0;
    style.PopupBorderSize = 0;
    style.FramePadding = imgui.ImVec2(4.00, 3.00);
    style.FrameRounding = 12;
    style.FrameBorderSize = 1;
    style.ItemSpacing = imgui.ImVec2(8.00, 4.00);
    style.ItemInnerSpacing = imgui.ImVec2(4.00, 4.00);
    style.IndentSpacing = 21;
    style.ScrollbarSize = 14;
    style.ScrollbarRounding = 12;
    style.GrabMinSize = 10;
    style.GrabRounding = 12;
    style.TabRounding = 9;
    style.ButtonTextAlign = imgui.ImVec2(0.50, 0.50);
    style.SelectableTextAlign = imgui.ImVec2(0.00, 0.00);
    colors[imgui.Col.Text] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00);
    colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.50, 0.50, 0.50, 1.00);
    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.09, 0.09, 0.09, 1.00);
    colors[imgui.Col.ChildBg] = imgui.ImVec4(0.13, 0.13, 0.13, 1.00);
    colors[imgui.Col.PopupBg] = imgui.ImVec4(0.12, 0.12, 0.12, 1.00);
    colors[imgui.Col.Border] = imgui.ImVec4(0.19, 0.19, 0.19, 1.00);
    colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.FrameBg] = imgui.ImVec4(0.08, 0.08, 0.08, 0.54);
    colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.16, 0.16, 0.16, 0.54);
    colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.17, 0.17, 0.17, 0.54);
    colors[imgui.Col.TitleBg] = imgui.ImVec4(0.21, 0.21, 0.21, 1.00);
    colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.37, 0.37, 0.37, 1.00);
    colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.00, 0.00, 0.00, 0.51);
    colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.14, 0.14, 0.14, 1.00);
    colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.24, 0.24, 0.24, 1.00);
    colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.18, 0.18, 0.18, 1.00);
    colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.18, 0.18, 0.18, 1.00);
    colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.36, 0.36, 0.36, 1.00);
    colors[imgui.Col.CheckMark] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00);
    colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.24, 0.24, 0.24, 1.00);
    colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.37, 0.37, 0.37, 1.00);
    colors[imgui.Col.Button] = imgui.ImVec4(0.24, 0.24, 0.24, 1.00);
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.37, 0.37, 0.37, 1.00);
    colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.37, 0.37, 0.37, 1.00);
    colors[imgui.Col.Header] = imgui.ImVec4(0.24, 0.24, 0.24, 1.00);
    colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.37, 0.37, 0.37, 1.00);
    colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.37, 0.37, 0.37, 1.00);
    colors[imgui.Col.Separator] = imgui.ImVec4(0.71, 0.71, 0.71, 1.00);
    colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.71, 0.71, 0.71, 1.00);
    colors[imgui.Col.SeparatorActive] = imgui.ImVec4(0.71, 0.71, 0.71, 1.00);
    colors[imgui.Col.ResizeGrip] = imgui.ImVec4(0.71, 0.71, 0.71, 1.00);
    colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.48, 0.48, 0.48, 1.00);
    colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.48, 0.48, 0.48, 1.00);
    colors[imgui.Col.Tab] = imgui.ImVec4(0.24, 0.24, 0.24, 1.00);
    colors[imgui.Col.TabHovered] = imgui.ImVec4(0.37, 0.37, 0.37, 1.00);
    colors[imgui.Col.TabActive] = imgui.ImVec4(0.37, 0.37, 0.37, 1.00);
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
