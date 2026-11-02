script_name("Chat Color")
script_author("mav1ck(discord), T23Vladimir+Claude")
script_description("Activation: /cc")

local imgui = require("mimgui")
local encoding = require("encoding")
local fa = require("fAwesome6")
local monet = require("MoonMonet")
local inicfg = require("inicfg")
local sampev = require("lib.samp.events")
encoding.default = "CP1251"
local u8 = encoding.UTF8

local menuColor = 759410733

local confq = inicfg.load({
    config = {
        RChatColor = 4282626093, -- rchat
        DChatColor = 4294940723, -- dchat
        FChatColor = 4282626093, -- fchat
        RToggled = true,
        DToggled = true,
        FToggled = true,
    },
}, 'changecolor')

inicfg.save(confq, "ChatColor.ini")

local new = imgui.new

function join_argb(a, r, g, b)
    local argb = b
    argb = bit.bor(argb, bit.lshift(g, 8))
    argb = bit.bor(argb, bit.lshift(r, 16))
    argb = bit.bor(argb, bit.lshift(a, 24))
    return argb
end

function vec4ToFloat4(vec4, type)
    type = type or 1
    if type == 1 then
        return new.float[4](vec4.x, vec4.y, vec4.z, vec4.w)
    else
        return new.float[4](vec4.z, vec4.y, vec4.x, vec4.w)
    end
end

local chatcolors = {
    RChatColor = vec4ToFloat4(imgui.ColorConvertU32ToFloat4(confq.config.RChatColor)),
    DChatColor = vec4ToFloat4(imgui.ColorConvertU32ToFloat4(confq.config.DChatColor)),
    FChatColor = vec4ToFloat4(imgui.ColorConvertU32ToFloat4(confq.config.FChatColor)),
}

local rToggled = imgui.new.bool(confq.config.RToggled)
local dToggled = imgui.new.bool(confq.config.DToggled)
local fToggled = imgui.new.bool(confq.config.FToggled)

function imgui.CircleCheckbox(label, boolRef)
    local style = imgui.GetStyle()
    local prevPadding = style.FramePadding
    style.FramePadding = imgui.ImVec2(3, 3)
    if imgui.RadioButtonBool(label, boolRef[0]) then
        boolRef[0] = not boolRef[0]
    end
    style.FramePadding = prevPadding
end

function imgui.VerticalSeparatorFull(offsetX, topPadding, bottomPadding)
    local winPos = imgui.GetWindowPos()
    local winSize = imgui.GetWindowSize()
    local titleBarHeight = imgui.GetFrameHeight()
    local x = winPos.x + offsetX
    local y1 = winPos.y + titleBarHeight + (topPadding or 20)
    local y2 = winPos.y + winSize.y - (bottomPadding or 20)
    local drawList = imgui.GetWindowDrawList()
    local col = imgui.ColorConvertFloat4ToU32(imgui.GetStyle().Colors[imgui.Col.Border])
    drawList:AddLine(imgui.ImVec2(x, y1), imgui.ImVec2(x, y2), col, 1.0)
end

local winState = imgui.new.bool(false)

imgui.OnFrame(function() return winState[0] end, function(player)
    local sx, sy = getScreenResolution()
    imgui.SetNextWindowSize(imgui.ImVec2(500, 130), imgui.Cond.Always)
    imgui.SetNextWindowPos(imgui.ImVec2(sx/2, sy/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(thisScript().name, winState, bit.bor(imgui.WindowFlags.NoScrollbar, imgui.WindowFlags.NoScrollWithMouse, imgui.WindowFlags.NoResize))

    imgui.VerticalSeparatorFull(290, 5, 5)

    imgui.CircleCheckbox('##RToggle', rToggled)
    if imgui.IsItemEdited() then
        confq.config.RToggled = rToggled[0]
        inicfg.save(confq, 'ChatColor.ini')
    end
    imgui.SameLine()
    imgui.Text(u8'Чат госс. организаций (/r /rb)')
    imgui.SameLine(310)
    if imgui.ColorEdit4(u8'##RSet', chatcolors.RChatColor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoAlpha) then
        confq.config.RChatColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(chatcolors.RChatColor[0], chatcolors.RChatColor[1], chatcolors.RChatColor[2], chatcolors.RChatColor[3]))
        inicfg.save(confq, 'ChatColor.ini')
    end
    imgui.SameLine(345)
    if imgui.Button(u8'Сбросить##RCol', imgui.ImVec2(80,25)) then
        confq.config.RChatColor = 4282626093
        if inicfg.save(confq, 'ChatColor.ini') then
            chatcolors.RChatColor = vec4ToFloat4(imgui.ColorConvertU32ToFloat4(confq.config.RChatColor))
        end
    end
    imgui.SameLine(435)
    if imgui.Button(u8'Тест##RTest', imgui.ImVec2(50,25)) then
        local result, myid = sampGetPlayerIdByCharHandle(playerPed)
        local color4 = imgui.ColorConvertU32ToFloat4(confq.config.RChatColor)
        local r, g, b, a = color4.x * 255, color4.y * 255, color4.z * 255, color4.w * 255
        sampAddChatMessage('[R] Test_Testing['..myid..']: (( Это сообщение видите только Вы! ))', join_argb(a, r, g, b))
    end

    imgui.CircleCheckbox('##FToggle', fToggled)
    if imgui.IsItemEdited() then
        confq.config.FToggled = fToggled[0]
        inicfg.save(confq, 'ChatColor.ini')
    end
    imgui.SameLine()
    imgui.Text(u8'Чат нелегал.организаций (/f /fb)')
    imgui.SameLine(310)
    if imgui.ColorEdit4(u8'##FSet', chatcolors.FChatColor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoAlpha) then
        confq.config.FChatColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(chatcolors.FChatColor[0], chatcolors.FChatColor[1], chatcolors.FChatColor[2], chatcolors.FChatColor[3]))
        inicfg.save(confq, 'ChatColor.ini')
    end
    imgui.SameLine(345)
    if imgui.Button(u8'Сбросить##FCol', imgui.ImVec2(80,25)) then
        confq.config.FChatColor = 4282626093
        if inicfg.save(confq, 'ChatColor.ini') then
            chatcolors.FChatColor = vec4ToFloat4(imgui.ColorConvertU32ToFloat4(confq.config.FChatColor))
        end
    end
    imgui.SameLine(435)
    if imgui.Button(u8'Тест##FTest', imgui.ImVec2(50,25)) then
        local result, myid = sampGetPlayerIdByCharHandle(playerPed)
        local color4 = imgui.ColorConvertU32ToFloat4(confq.config.FChatColor)
        local r, g, b, a = color4.x * 255, color4.y * 255, color4.z * 255, color4.w * 255
        sampAddChatMessage('[F] Test_Testing['..myid..']: (( Это сообщение видите только Вы! ))', join_argb(a, r, g, b))
    end

    imgui.CircleCheckbox('##DToggle', dToggled)
    if imgui.IsItemEdited() then
        confq.config.DToggled = dToggled[0]
        inicfg.save(confq, 'ChatColor.ini')
    end
    imgui.SameLine()
    imgui.Text(u8'Чат департамента (/d)')
    imgui.SameLine(310)
    if imgui.ColorEdit4(u8'##DSet', chatcolors.DChatColor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoAlpha) then
        confq.config.DChatColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(chatcolors.DChatColor[0], chatcolors.DChatColor[1], chatcolors.DChatColor[2], chatcolors.DChatColor[3]))
        inicfg.save(confq, 'ChatColor.ini')
    end
    imgui.SameLine(345)
    if imgui.Button(u8'Сбросить##DCol', imgui.ImVec2(80,25)) then
        confq.config.DChatColor = 4294940723
        if inicfg.save(confq, 'ChatColor.ini') then
            chatcolors.DChatColor = vec4ToFloat4(imgui.ColorConvertU32ToFloat4(confq.config.DChatColor))
        end
    end
    imgui.SameLine(435)
    if imgui.Button(u8'Тест##DTest', imgui.ImVec2(50,25)) then
        local result, myid = sampGetPlayerIdByCharHandle(playerPed)
        local color4 = imgui.ColorConvertU32ToFloat4(confq.config.DChatColor)
        local r, g, b, a = color4.x * 255, color4.y * 255, color4.z * 255, color4.w * 255
        sampAddChatMessage('[D] Test_Testing['..myid..']: Это сообщение видите только Вы!', join_argb(a, r, g, b))
    end

    imgui.End()
end)

function sampev.onServerMessage(color, text)
    if confq.config.RToggled and text:find('%[R%]') and color == 766526463 then
        local color = imgui.ColorConvertU32ToFloat4(confq.config.RChatColor)
        local r,g,b,a = color.x*255, color.y*255, color.z*255, color.w*255
        return { join_argb(r, g, b, a), text }
    end
    if confq.config.FToggled and text:find('%[F%]') and color == 766526463 then
        local color = imgui.ColorConvertU32ToFloat4(confq.config.FChatColor)
        local r,g,b,a = color.x*255, color.y*255, color.z*255, color.w*255
        return { join_argb(r, g, b, a), text }
    end
    if confq.config.DToggled and text:find('%[D%]') and (color == 865730559 or color == 865665023) then
        local color = imgui.ColorConvertU32ToFloat4(confq.config.DChatColor)
        local r,g,b,a = color.x*255, color.y*255, color.z*255, color.w*255
        return { join_argb(r, g, b, a), text }
    end
end

function main()
    sampRegisterChatCommand("cc", function() winState[0] = not winState[0] end)
    while true do
        wait(0)
    end
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    local config = imgui.ImFontConfig()
    config.MergeMode, config.PixelSnapH = true, true
    iconRanges = imgui.new.ImWchar[3](fa.min_range, fa.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85("duotune"), 17, config, iconRanges)
    apply_monet()
    decor()
end)

function bit_argb(a, r, g, b) return bit.bor(bit.lshift(a, 24), bit.lshift(r, 16), bit.lshift(g, 8), b) end
function bit_explode(c) return bit.band(bit.rshift(c,24),0xFF), bit.band(bit.rshift(c,16),0xFF), bit.band(bit.rshift(c,8),0xFF), bit.band(c,0xFF) end

function ColorAccentsAdapter(color)
    local a, r, g, b = bit_explode(color)
    local ret = { a = a, r = r, g = g, b = b }
    function ret:apply_alpha(x) self.a = x; return self end
    function ret:as_vec4() return imgui.ImVec4(self.r/255, self.g/255, self.b/255, self.a/255) end
    return ret
end

function apply_monet()
    imgui.SwitchContext()
    local colors, clr = imgui.GetStyle().Colors, imgui.Col
    local g = monet.buildColors(menuColor, 1.0, true)
    local function c(color, alpha) local a = ColorAccentsAdapter(color); if alpha then a:apply_alpha(alpha) end; return a:as_vec4() end
    local a1, a2 = g.accent1.color_600, g.accent2.color_700

    colors[clr.Text] = c(g.accent2.color_50)
    colors[clr.TextDisabled] = c(g.neutral1.color_600)
    colors[clr.WindowBg] = c(g.accent2.color_900)
    colors[clr.ChildBg] = c(g.accent2.color_800)
    colors[clr.PopupBg] = c(g.accent2.color_700)
    colors[clr.Border] = c(g.accent1.color_200, 0xcc)
    colors[clr.Separator] = c(g.accent1.color_200, 0xcc)
    colors[clr.BorderShadow] = imgui.ImVec4(0,0,0,0)
    colors[clr.FrameBg] = c(a1, 0x60)
    colors[clr.FrameBgHovered] = c(a1, 0x70)
    colors[clr.FrameBgActive] = c(a1, 0x50)
    colors[clr.TitleBg] = c(a2, 0xcc)
    colors[clr.TitleBgCollapsed] = c(a2, 0x7f)
    colors[clr.TitleBgActive] = c(a2)
    colors[clr.MenuBarBg] = c(a1, 0x91)
    colors[clr.ScrollbarBg] = imgui.ImVec4(0,0,0,0)
    colors[clr.ScrollbarGrab] = c(a1, 0x85)
    colors[clr.ScrollbarGrabHovered] = c(a1)
    colors[clr.ScrollbarGrabActive] = c(a1, 0xb3)
    colors[clr.CheckMark] = c(a1, 0xcc)
    colors[clr.SliderGrab] = c(a1, 0xcc)
    colors[clr.SliderGrabActive] = c(a1, 0x80)
    colors[clr.Button] = c(a1, 0xcc)
    colors[clr.ButtonHovered] = c(a1)
    colors[clr.ButtonActive] = c(a1, 0xb3)
    colors[clr.Tab] = c(a1, 0xcc)
    colors[clr.TabActive] = c(a1, 0xb3)
    colors[clr.TabHovered] = c(a1)
    colors[clr.Header] = c(a1, 0xcc)
    colors[clr.HeaderHovered] = c(a1)
    colors[clr.HeaderActive] = c(a1, 0xb3)
    colors[clr.ResizeGrip] = c(a2, 0xcc)
    colors[clr.ResizeGripHovered] = c(a2)
    colors[clr.ResizeGripActive] = c(a2, 0xb3)
    colors[clr.PlotLines] = c(g.accent2.color_600)
    colors[clr.PlotLinesHovered] = c(a1)
    colors[clr.PlotHistogram] = c(g.accent2.color_600)
    colors[clr.PlotHistogramHovered] = c(a1)
    colors[clr.TextSelectedBg] = c(a1)
    colors[clr.ModalWindowDimBg] = c(g.accent1.color_200, 0x26)
end

function decor()
    imgui.SwitchContext()
    local s = imgui.GetStyle()
    local pad = imgui.ImVec2(5, 5)
    s.WindowPadding, s.FramePadding, s.ItemSpacing = pad, pad, pad
    s.ItemInnerSpacing = imgui.ImVec2(2, 2)
    s.TouchExtraPadding = imgui.ImVec2(0, 0)
    s.IndentSpacing, s.ScrollbarSize, s.GrabMinSize = 0, 10, 10
    s.WindowBorderSize, s.ChildBorderSize, s.PopupBorderSize, s.FrameBorderSize, s.TabBorderSize = 1, 1, 1, 1, 1
    s.WindowRounding, s.ChildRounding, s.FrameRounding, s.PopupRounding, s.ScrollbarRounding, s.GrabRounding, s.TabRounding = 8, 8, 8, 8, 8, 8, 8
    s.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
end
