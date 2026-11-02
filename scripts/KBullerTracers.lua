-- code writen in cp1521
script_name('KBulletTracers')
script_authors('kyrtion')
script_version('1.1')

local sampev = require('samp.events')
local imgui = require('mimgui')
local encoding = require('encoding')

encoding.default = 'CP1251'
local u8 = encoding.UTF8
local new = imgui.new

-- local font = {}
local chat = { log = function(str, ...) return sampAddChatMessage(string.format(str, ...), -1) end }
local bullets = {
    { -- первый трейсер, это специально чтобы не показывало курсор при выстрелов, то есть, при запуске первый скрипт, потом сразу пропадает
        clock = 0,
        timer = 0,
        col4 = { [0]=0,[1]=0,[2]=0,[3]=0 },
        alpha = 0,
        origin = { x = 0, y = 0, z = 0 },
        target = { x = 0, y = 0, z = 0 },
        transition = 0,
        thickness = 0,
        circle_radius = 0,
        step_alpha = 1,
        degree_polygon = 0,
        draw_polygon = false,
    }
}

---[[ ImGui
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil

    --[[do -- font
        local defGlyph = imgui.GetIO().Fonts.ConfigData.Data[0].GlyphRanges
        local font_config = imgui.ImFontConfig()
        for size = 8, 25 do
            font_config.SizePixels = size
            font_config.GlyphExtraSpacing.x = 0.1
            font[size] = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', font_config.SizePixels, font_config, defGlyph)
        end
    end]]

    do -- theme
        local vec2 = imgui.ImVec2
        local st = imgui.GetStyle()
        imgui.SwitchContext()

        st.WindowPadding = vec2(4, 5)
        st.WindowRounding = 6.0
        st.WindowBorderSize = 0
        st.WindowTitleAlign = vec2(0.5, 0.5)
        st.ChildRounding = 5.0
        st.ChildBorderSize = 2.0
        st.PopupRounding = 5.0
        st.PopupBorderSize = 1.0
        st.FramePadding = vec2(6, 4)
        st.FrameRounding = 3.0
        st.ItemSpacing = vec2(4, 4)
        st.GrabMinSize = 9
        st.GrabRounding = 15
        st.ButtonTextAlign = vec2(0.5, 0.5)
    end
end)

local windowSettings = new.bool(false)

local test_bullets = {
    ['my']    = { clock = os.clock(), alpha = 0 },
    ['other'] = { clock = os.clock(), alpha = 0 }
}

function drawTestBullet(DL, tip, ig)
    local p = imgui.GetCursorScreenPos()
    local indent = 11
    local size = {
        min = {
            x = p.x + indent - 2,
            y = p.y + indent
        },
        max = {
            x = p.x + imgui.GetWindowContentRegionWidth() - indent + 2,
            y = p.y + indent
        }
    }

    if test_bullets[tip].alpha <= 0 then
        test_bullets[tip].clock = os.clock()
        test_bullets[tip].alpha = ig.col_vec4.test[3]
    end

    test_bullets[tip] = {
        clock = test_bullets[tip].clock,
        timer = ig.timer[0],
        col4 = ig.col_vec4.test,
        alpha = test_bullets[tip].alpha,
        origin = {x = size.min.x, y = size.min.y},
        target = {x = size.max.x, y = size.max.y},
        transition = ig.transition[0],
        thickness = ig.thickness[0],
        circle_radius = ig.circle_radius[0],
        step_alpha = ig.step_alpha[0],
        degree_polygon = ig.degree_polygon[0],
        draw_polygon = ig.draw_polygon[0],
    }

    local target_offset = {
        x = bringFloatTo(test_bullets[tip].origin.x, test_bullets[tip].target.x, test_bullets[tip].clock, test_bullets[tip].transition),
        y = bringFloatTo(test_bullets[tip].origin.y, test_bullets[tip].target.y, test_bullets[tip].clock, test_bullets[tip].transition)
    }

    local oX, oY = test_bullets[tip].origin.x, test_bullets[tip].origin.y
    local tX, tY = target_offset.x, target_offset.y

    local col4u32 = imgui.ImVec4(test_bullets[tip].col4[0], test_bullets[tip].col4[1], test_bullets[tip].col4[2], test_bullets[tip].alpha)

    if ig.draw[0] then
        DL:AddLine(imgui.ImVec2(oX, oY), imgui.ImVec2(tX, tY), imgui.GetColorU32Vec4(col4u32), test_bullets[tip].thickness)
        if ig.draw_polygon[0] then
            DL:AddCircleFilled(imgui.ImVec2(tX, tY), test_bullets[tip].circle_radius, imgui.GetColorU32Vec4(col4u32), test_bullets[tip].degree_polygon)
        end
    end

    if (os.clock() - test_bullets[tip].clock > ig.timer[0]) and (test_bullets[tip].alpha > 0) then
        test_bullets[tip].alpha = test_bullets[tip].alpha - test_bullets[tip].step_alpha
    end
end

function config()
    local con = {}

    function con:get_default_table()
        local config_data = {
            default = {
                version = 2,
                settings = {
                    enabled_bullets_in_screen = true,
                    warning_new_tracer = true,
                    radius_render_in_stream = {
                        is_active = false,
                        distance = 20,
                    }
                },
                my_bullets = {
                    draw = true,
                    draw_polygon = true,
                    thickness = 1.4,
                    timer = 3,
                    step_alpha = 0.01,
                    circle_radius = 4,
                    degree_polygon = 15,
                    transition = 0.2,
                    col_vec4 = {
                        -----       Red  Gre  Blu  Alp
                        stats   = { 0.8, 0.8, 0.8, 0.7 }, -- statis.object
                        ped     = { 1.0, 0.4, 0.4, 0.7 }, -- ped
                        car     = { 0.8, 0.8, 0.0, 0.7 }, -- car
                        dynam   = { 0.0, 0.8, 0.8, 0.7 }, -- dynam.object?
                        test    = { 0.8, 0.8, 0.8, 0.7 }, -- test color tracer
                        unknown = { 1.0, 0.0, 1.0, 1.0 }, --* added 1.1
                    }
                },
                other_bullets = {
                    draw = true,
                    draw_polygon = true,
                    thickness = 1.4,
                    timer = 3,
                    step_alpha = 0.01,
                    circle_radius = 4,
                    degree_polygon = 15,
                    transition = 0.2,
                    col_vec4 = {
                        stats   = { 0.8, 0.8, 0.8, 0.7 },
                        ped     = { 1.0, 0.4, 0.4, 0.7 },
                        car     = { 0.8, 0.8, 0.0, 0.7 },
                        dynam   = { 0.0, 0.8, 0.8, 0.7 },
                        test    = { 0.8, 0.8, 0.8, 0.7 },
                        unknown = { 1.0, 0.0, 1.0, 1.0 },
                    }
                },
            },
            folderpath_config = getWorkingDirectory()..'\\config',
            filepath_json = getWorkingDirectory()..'\\config\\KBulletTracers.json',
        }
        return config_data
    end

    function con:check()
        local def = config():get_default_table()
        if not doesDirectoryExist(def.folderpath_config) then createDirectory(def.folderpath_config) end
        if doesFileExist(def.filepath_json) then
            local file = io.open(def.filepath_json, 'r+')
            local json_string = file:read('*a')
            file:close()
            local config_json = decodeJson(json_string)

            if config_json.version ~= def.default.version then
                config_json.version = def.default.version
                config_json = config():update(config_json, def.default)
                config():save(config_json)
            end
        else
            local file = io.open(def.filepath_json, 'w')
            file:write(encodeJson(def.default))
            file:flush()
            file:close()
        end
    end

    function con:load()
        local file = io.open(config():get_default_table().filepath_json, 'r+')
        local json_string = file:read('*a')
        file:close()
        return decodeJson(json_string)
    end

    function con:save(tabl)
        local file = io.open(config():get_default_table().filepath_json, 'w')
        file:write(encodeJson(tabl))
        file:flush()
        file:close()
    end

    function con:update(conf, def) -- Рекурсивная функция
        for k,v in pairs(def) do
            if conf[k] == nil then
                conf[k] = v
            elseif type(v) == 'table' then
                if type(conf[k]) == 'table' then
                    conf[k] = config():update(conf[k], v)
                end
            end
        end

        for k,v in pairs(conf) do
            if def[k] == nil then
                conf[k] = nil
            elseif type(v) == 'table' then
                if type(def[k]) == 'table' then
                    conf[k] = config():update(conf[k], def[k])
                end
            end
        end

        for k,v in pairs(conf) do
            if def[k] ~= nil and type(v) ~= 'table' and type(v) == type(def[k]) and v == def[k] then
                conf[k] = v
            end
        end
        return conf
    end

    function con:convert_to_imgui(config)
        local ig = {}
        ig.version = new.int(config.version)
        ig.settings = {
            enabled_bullets_in_screen = new.bool(config.settings.enabled_bullets_in_screen),
            warning_new_tracer = new.bool(config.settings.warning_new_tracer),
            radius_render_in_stream = {
                is_active = new.bool(config.settings.radius_render_in_stream.is_active),
                distance = new.int(config.settings.radius_render_in_stream.distance),
            },
        }
        ig.my_bullets = {
            draw = new.bool(config.my_bullets.draw),
            draw_polygon = new.bool(config.my_bullets.draw_polygon),
            thickness = new.float(config.my_bullets.thickness),
            timer = new.float(config.my_bullets.timer),
            step_alpha = new.float(config.my_bullets.step_alpha),
            circle_radius = new.float(config.my_bullets.circle_radius),
            degree_polygon = new.int(config.my_bullets.degree_polygon),
            transition = new.float(config.my_bullets.transition),
            col_vec4 = {
                stats   = new.float[4](config.my_bullets.col_vec4.stats),
                ped     = new.float[4](config.my_bullets.col_vec4.ped),
                car     = new.float[4](config.my_bullets.col_vec4.car),
                dynam   = new.float[4](config.my_bullets.col_vec4.dynam),
                test    = new.float[4](config.my_bullets.col_vec4.test),
                unknown = new.float[4](config.my_bullets.col_vec4.unknown),
            }
        }
        ig.other_bullets = {
            draw = new.bool(config.other_bullets.draw),
            draw_polygon = new.bool(config.other_bullets.draw_polygon),
            thickness = new.float(config.other_bullets.thickness),
            timer = new.float(config.other_bullets.timer),
            step_alpha = new.float(config.other_bullets.step_alpha),
            circle_radius = new.float(config.other_bullets.circle_radius),
            degree_polygon = new.int(config.other_bullets.degree_polygon),
            transition = new.float(config.other_bullets.transition),
            col_vec4 = {
                stats   = new.float[4](config.other_bullets.col_vec4.stats),
                ped     = new.float[4](config.other_bullets.col_vec4.ped),
                car     = new.float[4](config.other_bullets.col_vec4.car),
                dynam   = new.float[4](config.other_bullets.col_vec4.dynam),
                test    = new.float[4](config.other_bullets.col_vec4.test),
                unknown = new.float[4](config.other_bullets.col_vec4.unknown),
            }
        }
        return ig
    end

    function con:convert_to_table(ig)
        local config = {}
        config.version = ig.version[0]
        config.settings = {
            enabled_bullets_in_screen = ig.settings.enabled_bullets_in_screen[0],
            warning_new_tracer = ig.settings.warning_new_tracer[0],
            radius_render_in_stream = {
                is_active = ig.settings.radius_render_in_stream.is_active[0],
                distance = ig.settings.radius_render_in_stream.distance[0],
            }
        }
        config.my_bullets = {
            draw = ig.my_bullets.draw[0],
            thickness = ig.my_bullets.thickness[0],
            timer = ig.my_bullets.timer[0],
            step_alpha = ig.my_bullets.step_alpha[0],
            circle_radius = ig.my_bullets.circle_radius[0],
            degree_polygon = ig.my_bullets.degree_polygon[0],
            draw_polygon = ig.my_bullets.draw_polygon[0],
            transition = ig.my_bullets.transition[0],
            col_vec4 = {
                stats   = { ig.my_bullets.col_vec4.stats[0],   ig.my_bullets.col_vec4.stats[1],   ig.my_bullets.col_vec4.stats[2],   ig.my_bullets.col_vec4.stats[3]   },
                ped     = { ig.my_bullets.col_vec4.ped[0],     ig.my_bullets.col_vec4.ped[1],     ig.my_bullets.col_vec4.ped[2],     ig.my_bullets.col_vec4.ped[3]     },
                car     = { ig.my_bullets.col_vec4.car[0],     ig.my_bullets.col_vec4.car[1],     ig.my_bullets.col_vec4.car[2],     ig.my_bullets.col_vec4.car[3]     },
                dynam   = { ig.my_bullets.col_vec4.dynam[0],   ig.my_bullets.col_vec4.dynam[1],   ig.my_bullets.col_vec4.dynam[2],   ig.my_bullets.col_vec4.dynam[3]   },
                test    = { ig.my_bullets.col_vec4.test[0],    ig.my_bullets.col_vec4.test[1],    ig.my_bullets.col_vec4.test[2],    ig.my_bullets.col_vec4.test[3]    },
                unknown = { ig.my_bullets.col_vec4.unknown[0], ig.my_bullets.col_vec4.unknown[1], ig.my_bullets.col_vec4.unknown[2], ig.my_bullets.col_vec4.unknown[3] },
            }
        }
        config.other_bullets = {
            draw = ig.other_bullets.draw[0],
            thickness = ig.other_bullets.thickness[0],
            timer = ig.other_bullets.timer[0],
            step_alpha = ig.other_bullets.step_alpha[0],
            circle_radius = ig.other_bullets.circle_radius[0],
            degree_polygon = ig.other_bullets.degree_polygon[0],
            draw_polygon = ig.other_bullets.draw_polygon[0],
            transition = ig.other_bullets.transition[0],
            col_vec4 = {
                stats   = { ig.other_bullets.col_vec4.stats[0],   ig.other_bullets.col_vec4.stats[1],   ig.other_bullets.col_vec4.stats[2],   ig.other_bullets.col_vec4.stats[3]   },
                ped     = { ig.other_bullets.col_vec4.ped[0],     ig.other_bullets.col_vec4.ped[1],     ig.other_bullets.col_vec4.ped[2],     ig.other_bullets.col_vec4.ped[3]     },
                car     = { ig.other_bullets.col_vec4.car[0],     ig.other_bullets.col_vec4.car[1],     ig.other_bullets.col_vec4.car[2],     ig.other_bullets.col_vec4.car[3]     },
                dynam   = { ig.other_bullets.col_vec4.dynam[0],   ig.other_bullets.col_vec4.dynam[1],   ig.other_bullets.col_vec4.dynam[2],   ig.other_bullets.col_vec4.dynam[3]   },
                test    = { ig.other_bullets.col_vec4.test[0],    ig.other_bullets.col_vec4.test[1],    ig.other_bullets.col_vec4.test[2],    ig.other_bullets.col_vec4.test[3]    },
                unknown = { ig.other_bullets.col_vec4.unknown[0], ig.other_bullets.col_vec4.unknown[1], ig.other_bullets.col_vec4.unknown[2], ig.other_bullets.col_vec4.unknown[3] },
            }
        }
        return config
    end

    return con
end

config():check()
local config_table = config():load()
local config_imgui = config():convert_to_imgui(config_table)

local frameSettings = imgui.OnFrame(
    function() return windowSettings[0] and not isPauseMenuActive() end,
    function()
        local resX, resY = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(resX/2, resY/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.Begin(string.format('%s [%s] by %s', thisScript().name, thisScript().version, thisScript().authors[1]), windowSettings, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize)

        local sizeX = imgui.GetWindowContentRegionWidth() - imgui.GetStyle().WindowPadding.x - imgui.GetStyle().ItemSpacing.x
        local sl = imgui.SameLine
        local sniw = imgui.SetNextItemWidth
        local DL = imgui.GetWindowDrawList()
        local indentWidth = 100

        do
            if imgui.BeginChild('##mySettings', imgui.ImVec2(490, 240), true) then
                imgui.CenterText(u8'Настройка своих пуль')
                imgui.Separator()
                imgui.BeginGroup()
                    sniw(indentWidth); imgui.DragFloat(u8'Время задержки трейсера##mySettings',        config_imgui.my_bullets.timer,          0.01,  0.01,  10,  u8'%.2f сек')
                    sniw(indentWidth); imgui.DragFloat(u8'Время появление до попадании##mySettings',   config_imgui.my_bullets.transition,     0.01,  0,     2,   u8'%.2f сек')
                    sniw(indentWidth); imgui.DragFloat(u8'Шаг исчезнование##mySettings',               config_imgui.my_bullets.step_alpha,     0.001, 0.001, 0.5, u8'%.3f шаг')
                    sniw(indentWidth); imgui.DragFloat(u8'Толщина линий##mySettings',                  config_imgui.my_bullets.thickness,      0.1,   1,     10,  u8'%.2f мм')
                    sniw(indentWidth); imgui.DragFloat(u8'Размер окончания трейсера##mySettings',      config_imgui.my_bullets.circle_radius,  0.2,   0,     15,  u8'%.2f радиус')
                    sniw(indentWidth); imgui.DragInt(  u8'Количество углов на окончаниях##mySettings', config_imgui.my_bullets.degree_polygon, 0.2,   3,     40,  u8'%d угол')
                imgui.EndGroup(); sl(_, 20);
                imgui.BeginGroup()
                    imgui.Checkbox(u8'Отрисовку своих пуль', config_imgui.my_bullets.draw)
                    imgui.Checkbox(u8'Окончания у линий',    config_imgui.my_bullets.draw_polygon)
                    imgui.ColorEdit4('##mySettings__Player', config_imgui.my_bullets.col_vec4.ped,   imgui.ColorEditFlags.NoInputs); sl(); imgui.Text(u8'Игрок')
                    imgui.ColorEdit4('##mySettings__Car',    config_imgui.my_bullets.col_vec4.car,   imgui.ColorEditFlags.NoInputs); sl(); imgui.Text(u8'Машина')
                    imgui.ColorEdit4('##mySettings__Stats',  config_imgui.my_bullets.col_vec4.stats, imgui.ColorEditFlags.NoInputs); sl(); imgui.Text(u8'Статический объект')
                    imgui.ColorEdit4('##mySettings__Dynam',  config_imgui.my_bullets.col_vec4.dynam, imgui.ColorEditFlags.NoInputs); sl(); imgui.Text(u8'Динамический объект')
                    imgui.ColorEdit4('##mySettings__Test',   config_imgui.my_bullets.col_vec4.test,  imgui.ColorEditFlags.NoInputs); sl(); imgui.Text(u8'Тестовый трейсер')
                imgui.EndGroup()
                imgui.Separator()
                    drawTestBullet(DL, 'my', config_imgui.my_bullets)
                imgui.EndChild()
            end

            imgui.NewLine()

            if imgui.BeginChild('##otherSettings', imgui.ImVec2(490, 240), true) then
                imgui.CenterText(u8'Настройка чужих пуль')
                imgui.Separator()
                imgui.BeginGroup()
                    sniw(indentWidth); imgui.DragFloat(u8'Время задержки трейсера##otherSettings',        config_imgui.other_bullets.timer,          0.01,  0.01,  10,  u8'%.2f сек')
                    sniw(indentWidth); imgui.DragFloat(u8'Время появление до попадании##otherSettings',   config_imgui.other_bullets.transition,     0.01,  0,     2,   u8'%.2f сек')
                    sniw(indentWidth); imgui.DragFloat(u8'Шаг исчезнование##otherSettings',               config_imgui.other_bullets.step_alpha,     0.001, 0.001, 0.5, u8'%.3f шаг')
                    sniw(indentWidth); imgui.DragFloat(u8'Толщина линий##otherSettings',                  config_imgui.other_bullets.thickness,      0.1,   1,     10,  u8'%.2f мм')
                    sniw(indentWidth); imgui.DragFloat(u8'Размер окончания трейсера##otherSettings',      config_imgui.other_bullets.circle_radius,  0.2,   0,     15,  u8'%.2f радиус')
                    sniw(indentWidth); imgui.DragInt(  u8'Количество углов на окончаниях##otherSettings', config_imgui.other_bullets.degree_polygon, 0.2,   3,     40,  u8'%d угол')
                imgui.EndGroup(); sl(_, 20);
                imgui.BeginGroup()
                    imgui.Checkbox(u8'Отрисовку чужих пуль',    config_imgui.other_bullets.draw)
                    imgui.Checkbox(u8'Окончания у линий',       config_imgui.other_bullets.draw_polygon)
                    imgui.ColorEdit4('##otherSettings__Player', config_imgui.other_bullets.col_vec4.ped,   imgui.ColorEditFlags.NoInputs); sl(); imgui.Text(u8'Игрок')
                    imgui.ColorEdit4('##otherSettings__Car',    config_imgui.other_bullets.col_vec4.car,   imgui.ColorEditFlags.NoInputs); sl(); imgui.Text(u8'Машина')
                    imgui.ColorEdit4('##otherSettings__Stats',  config_imgui.other_bullets.col_vec4.stats, imgui.ColorEditFlags.NoInputs); sl(); imgui.Text(u8'Статический объект')
                    imgui.ColorEdit4('##otherSettings__Dynam',  config_imgui.other_bullets.col_vec4.dynam, imgui.ColorEditFlags.NoInputs); sl(); imgui.Text(u8'Динамический объект')
                    imgui.ColorEdit4('##otherSettings__Test',   config_imgui.other_bullets.col_vec4.test,  imgui.ColorEditFlags.NoInputs); sl(); imgui.Text(u8'Тестовый трейсер')
                imgui.EndGroup()
                imgui.Separator()
                    drawTestBullet(DL, 'other', config_imgui.other_bullets)
                imgui.EndChild()
            end

            imgui.NewLine()

            if imgui.BeginChild('##globalSettings', imgui.ImVec2(490, 108), true) then
                imgui.CenterText(u8'Параметры трейсеров пуль')
                imgui.Separator()
                imgui.Checkbox(u8'Проходить трейсер пули сквозь экран (нестабильно)', config_imgui.settings.enabled_bullets_in_screen)
                imgui.Checkbox(u8'Сообщить в чате, если трейсер не распознан', config_imgui.settings.warning_new_tracer)
                imgui.Checkbox(u8'Ограничить радиус', config_imgui.settings.radius_render_in_stream.is_active)
                if config_imgui.settings.radius_render_in_stream.is_active[0] then
                    sl(); sniw(100); imgui.DragInt('##globalSettings__RadiusRender', config_imgui.settings.radius_render_in_stream.distance, 0.1, 5, 300, u8'%d метров')
                end
                imgui.EndChild()
            end

            imgui.NewLine()

            if imgui.Button(u8'Сохранить', imgui.ImVec2(sizeX/3, 0)) then
                config():save(config():convert_to_table(config_imgui))
                chat.log('Успешно сохранено!')
            end; sl();
            if imgui.Button(u8'Сбросить', imgui.ImVec2(sizeX/3, 0)) then
                config_imgui = config():convert_to_imgui(config():get_default_table().default)
            end; sl();
            if imgui.Button(string.format(u8'Очистить пули [%d]', #bullets), imgui.ImVec2(sizeX/3, 0)) then
                bullets = {}
            end
        end

        imgui.End()
    end
)

local frameDrawList = imgui.OnFrame(
    function() return #bullets ~= 0 and not isPauseMenuActive() end,
    function(self)
        self.HideCursor = true
        local DL = imgui.GetBackgroundDrawList()

        for i=#bullets, 1, -1 do
            local target_offset = {
                x = bringFloatTo(bullets[i].origin.x, bullets[i].target.x, bullets[i].clock, bullets[i].transition),
                y = bringFloatTo(bullets[i].origin.y, bullets[i].target.y, bullets[i].clock, bullets[i].transition),
                z = bringFloatTo(bullets[i].origin.z, bullets[i].target.z, bullets[i].clock, bullets[i].transition)
            }

            local _, oX, oY, oZ, _, _ = convert3DCoordsToScreenEx(bullets[i].origin.x, bullets[i].origin.y, bullets[i].origin.z, false, false)
            local _, tX, tY, tZ, _, _ = convert3DCoordsToScreenEx(target_offset.x, target_offset.y, target_offset.z, false, false)

            local col4u32 = imgui.ImVec4(bullets[i].col4[0], bullets[i].col4[1], bullets[i].col4[2], bullets[i].alpha)

            if config_imgui.settings.enabled_bullets_in_screen[0] then
                if oZ > 0 and tZ > 0 then -- default
                    DL:AddLine(imgui.ImVec2(oX, oY), imgui.ImVec2(tX, tY), imgui.GetColorU32Vec4(col4u32), bullets[i].thickness)
                    if bullets[i].draw_polygon then
                        DL:AddCircleFilled(imgui.ImVec2(tX, tY), bullets[i].circle_radius, imgui.GetColorU32Vec4(col4u32), bullets[i].degree_polygon)
                    end
                elseif oZ <= 0 and tZ > 0 then -- fix origin coords
                    local newPos = getFixScreenPos(target_offset, bullets[i].origin, tZ)
                    _, oX, oY, oZ, _, _ = convert3DCoordsToScreenEx(newPos.x, newPos.y, newPos.z, false, false)
                    DL:AddLine(imgui.ImVec2(oX, oY), imgui.ImVec2(tX, tY), imgui.GetColorU32Vec4(col4u32), bullets[i].thickness)
                    if bullets[i].draw_polygon then DL:AddCircleFilled(imgui.ImVec2(tX, tY), bullets[i].circle_radius, imgui.GetColorU32Vec4(col4u32), bullets[i].degree_polygon) end
                elseif oZ > 0 and tZ <= 0 then -- fix target coords --! dont draw circle
                    local newPos = getFixScreenPos(bullets[i].origin, target_offset, oZ)
                    _, tX, tY, tZ, _, _ = convert3DCoordsToScreenEx(newPos.x, newPos.y, newPos.z, false, false)
                    DL:AddLine(imgui.ImVec2(oX, oY), imgui.ImVec2(tX, tY), imgui.GetColorU32Vec4(col4u32), bullets[i].thickness)
                end
            else
                if tZ > 0 then
                    if oZ > 0 then
                        DL:AddLine(imgui.ImVec2(oX, oY), imgui.ImVec2(tX, tY), imgui.GetColorU32Vec4(col4u32), bullets[i].thickness)
                    end
                    if bullets[i].draw_polygon then
                        DL:AddCircleFilled(imgui.ImVec2(tX, tY), bullets[i].circle_radius, imgui.GetColorU32Vec4(col4u32), bullets[i].degree_polygon)
                    end
                end
            end

            -- Плавное исчезновение
            if (os.clock() - bullets[i].clock > bullets[i].timer) and (bullets[i].alpha > 0) then
                bullets[i].alpha = bullets[i].alpha - bullets[i].step_alpha
            end

            -- Удаляем трейсер, если альфа ниже/равна 0
            if bullets[i].alpha <= 0 then
                table.remove(bullets, i)
                if #bullets == 0 then break end
            end
        end
    end
)

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('kbt', function() windowSettings[0] = not windowSettings[0] end)
    wait(-1)
end

function bringFloatTo(from, dest, start_time, duration) -- спс космо за функи
    local timer = os.clock() - start_time
    if timer >= 0 and timer <= duration then
        local count = timer / (duration / 100)
        return from + (count * (dest - from) / 100)
    end
    return (timer > duration) and dest or from
end

function getFixScreenPos(pos1, pos2, distance) -- TODO: Незаконченная функа
    distance = math.abs(distance)
    local direct = { x = pos2.x - pos1.x, y = pos2.y - pos1.y, z = pos2.z - pos1.z }
    local length = math.sqrt(direct.x * direct.x + direct.y * direct.y + direct.z * direct.z)
    direct = { x = direct.x / length, y = direct.y / length, z = direct.z / length }
    local newPos = { x = pos1.x + direct.x * distance, y = pos1.y + direct.y * distance, z = pos1.z + direct.z * distance }
    return newPos
end

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(text).x / 2)
    imgui.Text(text)
end

function getDistancePosition(plPos, distance)
    if not config_imgui.settings.radius_render_in_stream.is_active[0] then return true end

    local myPos = { getCharCoordinates(PLAYER_PED) }
    local dist_ped = getDistanceBetweenCoords3d(plPos.x, plPos.y, plPos.z, myPos[1], myPos[2], myPos[3])

    if dist_ped <= distance then
        return true
    else
        return false
    end
end

local function getColorTargetType(target, con_imgui)
    if     target == 0 then return con_imgui.col_vec4.stats
    elseif target == 1 then return con_imgui.col_vec4.ped
    elseif target == 2 then return con_imgui.col_vec4.car
    elseif target == 3 then return con_imgui.col_vec4.dynam
    elseif target == 4 then return con_imgui.col_vec4.dynam --* added 1.1 - modelId 3626
    else
        if config_imgui.settings.warning_new_tracer[0] then
            chat.log('Появился новый нераспознованный трейсер %d. Сообщите разработчику @kyrtion в blast.hk, VK или TG', target)
        end
        return con_imgui.col_vec4.unknown
    end
end

function sampev.onSendBulletSync(data) -- my
    -- chat.log('X:%02f Y:%02f Z:%02f - [%d]', data.origin.x, data.origin.y, data.origin.z, data.targetType) -- DEBUG
    if config_imgui.my_bullets.draw[0] and (data.center.x ~= 0 and data.center.y ~= 0 and data.center.z ~= 0) then
        local ig = config_imgui.my_bullets
        local color = getColorTargetType(data.targetType, ig)
        bullets[#bullets+1] = {
            clock = os.clock(),
            timer = ig.timer[0],
            col4 = color,
            alpha = color[3],
            origin = { x = data.origin.x, y = data.origin.y, z = data.origin.z },
            target = { x = data.target.x, y = data.target.y, z = data.target.z },
            transition = ig.transition[0],
            thickness = ig.thickness[0],
            circle_radius = ig.circle_radius[0],
            step_alpha = ig.step_alpha[0],
            degree_polygon = ig.degree_polygon[0],
            draw_polygon = ig.draw_polygon[0],
        }
    end
end

function sampev.onBulletSync(_, data) -- player
    -- chat.log('[%d] - X:%02f Y:%02f Z:%02f - [%d]', playerid, data.origin.x, data.origin.y, data.origin.z, data.targetType) -- DEBUG
    if config_imgui.other_bullets.draw[0] and (data.center.x ~= 0 and data.center.y ~= 0 and data.center.z ~= 0) and getDistancePosition(data.origin, config_imgui.settings.radius_render_in_stream.distance[0]) then
        local ig = config_imgui.other_bullets
        local color = getColorTargetType(data.targetType, ig)
        bullets[#bullets+1] = {
            clock = os.clock(),
            timer = ig.timer[0],
            col4 = color,
            alpha = color[3],
            origin = { x = data.origin.x, y = data.origin.y, z = data.origin.z },
            target = { x = data.target.x, y = data.target.y, z = data.target.z },
            transition = ig.transition[0],
            thickness = ig.thickness[0],
            circle_radius = ig.circle_radius[0],
            step_alpha = ig.step_alpha[0],
            degree_polygon = ig.degree_polygon[0],
            draw_polygon = ig.draw_polygon[0],
        }
    end
end
