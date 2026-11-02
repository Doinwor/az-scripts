script_name('Rodina Optimizer')
script_author('Killsize Genocide')
script_version('1.0.0 Beta')

require 'lib.moonloader'

local imgui = require 'mimgui'
local encoding = require 'encoding'
local inicfg = require 'inicfg'
local events = require 'samp.events'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- =========================================================
-- CONFIG & CONSTANTS
-- =========================================================

local SCRIPT_NAME = 'Rodina Optimizer'
local SCRIPT_VERSION = '1.0.0 Beta'
local CONFIG_NAME = 'RodinaOptimizer.ini'

local defaultConfig = {
General = {
notifications = false,
themeR = 0.54,
themeG = 0.20,
themeB = 0.85
},

Players = {
    enabled = false
},

Vehicles = {
    enabled = false
},

Objects = {
    enabled = false
},

Accessories = {
    all = false,
    me = false
},

Graphics = {
    text3dEnabled = false,
    text3dDistance = 80
}

}

local ini = inicfg.load(defaultConfig, CONFIG_NAME)

if not ini then
ini = defaultConfig
inicfg.save(ini, CONFIG_NAME)
end

local function ensureConfig()

if not ini.General then
    ini.General = {}
end

if not ini.Players then
    ini.Players = {}
end

if not ini.Vehicles then
    ini.Vehicles = {}
end

if not ini.Objects then
    ini.Objects = {}
end

if not ini.Accessories then
    ini.Accessories = {}
end

if not ini.Graphics then
    ini.Graphics = {}
end

if ini.General.notifications == nil then
    ini.General.notifications = false
end

if ini.General.themeR == nil then
    ini.General.themeR = 0.54
end

if ini.General.themeG == nil then
    ini.General.themeG = 0.20
end

if ini.General.themeB == nil then
    ini.General.themeB = 0.85
end

if ini.Players.enabled == nil then
    ini.Players.enabled = false
end

if ini.Vehicles.enabled == nil then
    ini.Vehicles.enabled = false
end

if ini.Objects.enabled == nil then
    ini.Objects.enabled = false
end

if ini.Accessories.all == nil then
    ini.Accessories.all = false
end

if ini.Accessories.me == nil then
    ini.Accessories.me = false
end

if ini.Graphics.text3dEnabled == nil then
    ini.Graphics.text3dEnabled = false
end

if ini.Graphics.text3dDistance == nil then
    ini.Graphics.text3dDistance = 80
end

ini.Graphics.text3dDistance =
    math.max(
        0,
        math.min(
            tonumber(ini.Graphics.text3dDistance) or 80,
            100
        )
    )

inicfg.save(
    ini,
    CONFIG_NAME
)

end

ensureConfig()

-- =========================================================
-- UI STATE & VARIABLES
-- =========================================================

local window = imgui.new.bool(false)

local notifications =
imgui.new.bool(
ini.General.notifications
)

local uiColor =
imgui.new.float[3](
ini.General.themeR,
ini.General.themeG,
ini.General.themeB
)

local playersEnabled =
imgui.new.bool(
ini.Players.enabled
)

local vehiclesEnabled =
imgui.new.bool(
ini.Vehicles.enabled
)

local objectsEnabled =
imgui.new.bool(
ini.Objects.enabled
)

local accessoriesAll =
imgui.new.bool(
ini.Accessories.all
)

local accessoriesMe =
imgui.new.bool(
ini.Accessories.me
)

local text3dEnabled =
imgui.new.bool(
ini.Graphics.text3dEnabled
)

local text3dDistance =
imgui.new.int(
ini.Graphics.text3dDistance
)

local currentTab = 1
local localPlayerId = -1

-- =========================================================
-- PARTICLES & TAB ANIMATIONS
-- =========================================================

local particleCount = 67
local particles = {}
local lastTime = os.clock()
local particlesInited = false

local function spawnParticle(p, sw, sh)

p.x = math.random() * sw
p.y = -math.random(10, 80)
p.speed = math.random(40, 120)
p.size = math.random(3, 7)
p.phase = math.random() * math.pi * 2
p.sway = math.random(15, 40)
p.alpha = 0.4 + math.random() * 0.5

end

local function initParticles(sw, sh)

for i = 1, particleCount do

    local p = {}

    spawnParticle(
        p,
        sw,
        sh
    )

    p.y = math.random() * sh

    particles[i] = p
end

end

local function updateAndDrawParticles(
dt,
sw,
sh
)

if not particlesInited then

    initParticles(
        sw,
        sh
    )

    particlesInited = true
end

local dl =
    imgui.GetForegroundDrawList()

for _, p in ipairs(particles) do

    p.y =
        p.y +
        p.speed * dt

    local drawX =
        p.x +
        math.sin(
            os.clock() * 1.2 +
            p.phase
        ) *
        p.sway

    local drawY = p.y

    if drawY > sh + 20 then

        spawnParticle(
            p,
            sw,
            sh
        )
    end

    local ai =
        math.floor(
            p.alpha * 255
        )

    local col =
        (ai * 0x1000000) +
        (255 * 0x10000) +
        (math.floor(0.6 * 255) * 0x100) +
        math.floor(0.8 * 255)

    dl:AddCircleFilled(
        imgui.ImVec2(
            drawX,
            drawY
        ),
        p.size,
        col,
        8
    )

    local ai2 =
        math.floor(
            p.alpha * 0.7 * 255
        )

    local col2 =
        (ai2 * 0x1000000) +
        (255 * 0x10000) +
        (math.floor(0.9 * 255) * 0x100) +
        math.floor(0.95 * 255)

    dl:AddCircleFilled(
        imgui.ImVec2(
            drawX,
            drawY
        ),
        math.floor(
            p.size * 0.4
        ),
        col2,
        6
    )
end

end

local function drawOverlay(sw, sh)

local dl =
    imgui.GetBackgroundDrawList()

local col =
    imgui.ColorConvertFloat4ToU32(
        imgui.ImVec4(
            0.05,
            0.04,
            0.08,
            0.45
        )
    )

dl:AddRectFilled(
    imgui.ImVec2(
        0,
        0
    ),
    imgui.ImVec2(
        sw,
        sh
    ),
    col
)

end

local tabFadeStart = os.clock()
local tabFadeDuration = 0.35
local tabSlideDistance = 24

local function easeOut(t)

local f = t - 1

return
    f * f * f +
    1

end

local function tabFadeAlpha()

local dt =
    os.clock() -
    tabFadeStart

if dt >= tabFadeDuration then
    return 1.0
end

return easeOut(
    dt / tabFadeDuration
)

end

local function tabSlideOffset()

local dt =
    os.clock() -
    tabFadeStart

if dt >= tabFadeDuration then
    return 0
end

local t =
    dt / tabFadeDuration

return
    (1.0 - easeOut(t)) *
    tabSlideDistance

end

local function tabButton(
label,
idx,
width
)

local active =
    currentTab == idx

local r =
    uiColor[0]

local g =
    uiColor[1]

local b =
    uiColor[2]

if active then

    imgui.PushStyleColor(
        imgui.Col.Button,
        imgui.ImVec4(
            r,
            g,
            b,
            1.0
        )
    )

    imgui.PushStyleColor(
        imgui.Col.ButtonHovered,
        imgui.ImVec4(
            math.min(
                r * 1.15,
                1.0
            ),
            math.min(
                g * 1.15,
                1.0
            ),
            math.min(
                b * 1.15,
                1.0
            ),
            1.0
        )
    )

    imgui.PushStyleColor(
        imgui.Col.ButtonActive,
        imgui.ImVec4(
            r * 0.8,
            g * 0.8,
            b * 0.8,
            1.0
        )
    )

    imgui.PushStyleColor(
        imgui.Col.Text,
        imgui.ImVec4(
            1.00,
            1.00,
            1.00,
            1.0
        )
    )

end

local clicked =
    imgui.Button(
        label,
        imgui.ImVec2(
            width,
            38
        )
    )

if active then
    imgui.PopStyleColor(4)
end

if clicked
    and currentTab ~= idx then

    currentTab = idx

    tabFadeStart =
        os.clock()
end

end

-- =========================================================
-- ACCESSORY CLEANER & HELPERS
-- =========================================================

local lastAccessoryCheck = 0
local ACCESSORY_CHECK_INTERVAL = 5000

local function applyStyle()

local style =
    imgui.GetStyle()

style.WindowRounding = 12
style.ChildRounding = 10
style.FrameRounding = 8
style.PopupRounding = 8
style.GrabRounding = 8
style.ScrollbarRounding = 8

style.WindowPadding =
    imgui.ImVec2(
        14,
        14
    )

style.FramePadding =
    imgui.ImVec2(
        10,
        7
    )

style.ItemSpacing =
    imgui.ImVec2(
        8,
        8
    )

-- Обычный вертикальный скроллбар
style.ScrollbarSize = 12

local r =
    uiColor[0]

local g =
    uiColor[1]

local b =
    uiColor[2]

local C =
    style.Colors

C[imgui.Col.WindowBg] =
    imgui.ImVec4(
        0.055,
        0.055,
        0.070,
        0.98
    )

C[imgui.Col.ChildBg] =
    imgui.ImVec4(
        0.040,
        0.040,
        0.052,
        0.90
    )

C[imgui.Col.TitleBg] =
    imgui.ImVec4(
        r * 0.40,
        g * 0.40,
        b * 0.40,
        0.90
    )

C[imgui.Col.TitleBgActive] =
    imgui.ImVec4(
        r * 0.75,
        g * 0.75,
        b * 0.75,
        1.00
    )

C[imgui.Col.TitleBgCollapsed] =
    imgui.ImVec4(
        r * 0.25,
        g * 0.25,
        b * 0.25,
        0.70
    )

C[imgui.Col.FrameBg] =
    imgui.ImVec4(
        r * 0.25,
        g * 0.25,
        b * 0.25,
        0.60
    )

C[imgui.Col.FrameBgHovered] =
    imgui.ImVec4(
        r * 0.40,
        g * 0.40,
        b * 0.40,
        0.70
    )

C[imgui.Col.FrameBgActive] =
    imgui.ImVec4(
        r * 0.55,
        g * 0.55,
        b * 0.55,
        0.80
    )

C[imgui.Col.Button] =
    imgui.ImVec4(
        r * 0.70,
        g * 0.70,
        b * 0.70,
        0.85
    )

C[imgui.Col.ButtonHovered] =
    imgui.ImVec4(
        r,
        g,
        b,
        0.95
    )

C[imgui.Col.ButtonActive] =
    imgui.ImVec4(
        r * 0.60,
        g * 0.60,
        b * 0.60,
        1.00
    )

C[imgui.Col.CheckMark] =
    imgui.ImVec4(
        r,
        g,
        b,
        1.00
    )

C[imgui.Col.SliderGrab] =
    imgui.ImVec4(
        r * 0.85,
        g * 0.85,
        b * 0.85,
        1.00
    )

C[imgui.Col.SliderGrabActive] =
    imgui.ImVec4(
        r,
        g,
        b,
        1.00
    )

C[imgui.Col.Header] =
    imgui.ImVec4(
        r * 0.50,
        g * 0.50,
        b * 0.50,
        0.70
    )

C[imgui.Col.HeaderHovered] =
    imgui.ImVec4(
        r * 0.75,
        g * 0.75,
        b * 0.75,
        0.85
    )

C[imgui.Col.HeaderActive] =
    imgui.ImVec4(
        r,
        g,
        b,
        1.00
    )

C[imgui.Col.Separator] =
    imgui.ImVec4(
        r * 0.60,
        g * 0.60,
        b * 0.60,
        0.60
    )

C[imgui.Col.SeparatorHovered] =
    imgui.ImVec4(
        r * 0.80,
        g * 0.80,
        b * 0.80,
        0.80
    )

C[imgui.Col.SeparatorActive] =
    imgui.ImVec4(
        r,
        g,
        b,
        1.00
    )

end

local function saveConfig()

ini.General.notifications =
    notifications[0]

ini.General.themeR =
    uiColor[0]

ini.General.themeG =
    uiColor[1]

ini.General.themeB =
    uiColor[2]

ini.Players.enabled =
    playersEnabled[0]

ini.Vehicles.enabled =
    vehiclesEnabled[0]

ini.Objects.enabled =
    objectsEnabled[0]

ini.Accessories.all =
    accessoriesAll[0]

ini.Accessories.me =
    accessoriesMe[0]

ini.Graphics.text3dEnabled =
    text3dEnabled[0]

ini.Graphics.text3dDistance =
    text3dDistance[0]

inicfg.save(
    ini,
    CONFIG_NAME
)

end

local function message(
text,
color
)

if not notifications[0] then
    return
end

color =
    color or
    '{FFFFFF}'

sampAddChatMessage(
    '{8A2BE2}[Rodina Optimizer] {FFFFFF}' ..
    color ..
    text,
    -1
)

end

local function clamp(
value,
minValue,
maxValue
)

if value < minValue then
    return minValue
end

if value > maxValue then
    return maxValue
end

return value

end

-- =========================================================
-- GAME EVENTS & NETWORK FILTERS
-- =========================================================

function events.onPlayerStreamIn(
playerId
)

if playersEnabled[0] then
    return false
end

if accessoriesAll[0] then

    lua_thread.create(
        function()

            wait(250)

            removePlayerAccessories(
                playerId
            )

        end
    )

end

end

function events.onVehicleStreamIn(
vehicleId,
data
)

if vehiclesEnabled[0] then
    return false
end

end

function events.onCreateObject(
objectId,
data
)

if objectsEnabled[0] then
    return false
end

end

function events.onCreate3DText(
id,
color,
position,
distance,
los,
attachedPlayer,
attachedVehicle,
text
)

if not text3dEnabled[0] then
    return
end

local customDistance =
    clamp(
        text3dDistance[0],
        0,
        100
    )

if distance ~= nil
    and distance > 0 then

    customDistance =
        math.min(
            customDistance,
            distance
        )
end

return {
    id,
    color,
    position,
    customDistance,
    los,
    attachedPlayer,
    attachedVehicle,
    text
}

end

function removePlayerAccessories(
playerId
)

if playerId == nil
    or playerId < 0 then
    return
end

local bs =
    raknetNewBitStream()

if not bs then
    return
end

for slot = 0, 9 do

    raknetBitStreamWriteInt16(
        bs,
        playerId
    )

    raknetBitStreamWriteInt32(
        bs,
        slot
    )

    raknetBitStreamWriteBool(
        bs,
        false
    )

    raknetEmulRpcReceiveBitStream(
        113,
        bs
    )

    raknetResetBitStream(bs)

    raknetBitStreamWriteInt8(
        bs,
        155
    )

    raknetBitStreamWriteInt16(
        bs,
        playerId
    )

    raknetBitStreamWriteInt32(
        bs,
        slot
    )

    raknetBitStreamWriteBool(
        bs,
        false
    )

    raknetEmulPacketReceiveBitStream(
        220,
        bs
    )

    raknetResetBitStream(bs)

end

raknetDeleteBitStream(bs)

end

local function cleanAllStreamedAccessories()

if not accessoriesAll[0]
    and not accessoriesMe[0] then
    return
end

if localPlayerId < 0 then
    return
end

if accessoriesMe[0] then

    removePlayerAccessories(
        localPlayerId
    )

end

if accessoriesAll[0] then

    local chars =
        getAllChars()

    if chars then

        for _, ped in ipairs(chars) do

            if ped ~= PLAYER_PED then

                local result, playerId =
                    sampGetPlayerIdByCharHandle(
                        ped
                    )

                if result
                    and playerId ~= localPlayerId
                    and not sampIsPlayerNpc(playerId) then

                    removePlayerAccessories(
                        playerId
                    )

                end

            end

        end

    end

end

end

function events.onSetPlayerAttachedObject(
playerId,
index,
create,
object
)

if not create then
    return
end

if localPlayerId < 0 then
    return
end

if playerId == localPlayerId
    and accessoriesMe[0] then

    return false
end

if playerId ~= localPlayerId
    and accessoriesAll[0] then

    return false
end

end

function onReceivePacket(
id,
bs
)

if id ~= 220
    or not bs then
    return
end

if not accessoriesAll[0]
    and not accessoriesMe[0] then
    return
end

raknetBitStreamIgnoreBits(
    bs,
    8
)

local packetType =
    raknetBitStreamReadInt8(bs)

if packetType ~= 155 then
    return
end

local playerId =
    raknetBitStreamReadInt16(bs)

raknetBitStreamReadInt32(bs)

local create =
    raknetBitStreamReadBool(bs)

if not create then
    return
end

if localPlayerId < 0 then
    return
end

if playerId == localPlayerId
    and accessoriesMe[0] then

    return false
end

if playerId ~= localPlayerId
    and accessoriesAll[0] then

    return false
end

end

-- =========================================================
-- UI DRAWING HELPERS & TABS
-- =========================================================

local function separator()

imgui.Dummy(
    imgui.ImVec2(
        0,
        3
    )
)

imgui.Separator()

imgui.Dummy(
    imgui.ImVec2(
        0,
        3
    )
)

end

local function header(text)

imgui.TextColored(
    imgui.ImVec4(
        uiColor[0],
        uiColor[1],
        uiColor[2],
        1.0
    ),
    text
)

imgui.Dummy(
    imgui.ImVec2(
        0,
        3
    )
)

end

local function drawGeneralTab()

header(
    u8'Основные настройки'
)

if imgui.Checkbox(
    u8'Уведомления в чате',
    notifications
) then

    saveConfig()

end

imgui.Spacing()

imgui.Text(
    u8'Кастомный цвет интерфейса:'
)

imgui.PushItemWidth(-1)

if imgui.ColorEdit3(
    '##uicolor',
    uiColor
) then

    saveConfig()
    applyStyle()

end

imgui.PopItemWidth()

end

local function drawWorldTab()

header(
    u8'Мир'
)

if imgui.Checkbox(
    u8'Убирать игроков',
    playersEnabled
) then

    saveConfig()

    if playersEnabled[0] then

        message(
            'Игроки будут скрываться при следующем появлении.',
            '{FFD700}'
        )

    else

        message(
            'Скрытие игроков отключено.',
            '{7CFC00}'
        )

    end

end

if imgui.Checkbox(
    u8'Убирать транспорт',
    vehiclesEnabled
) then

    saveConfig()

    if vehiclesEnabled[0] then

        message(
            'Транспорт будет блокироваться при появлении.',
            '{FFD700}'
        )

    else

        message(
            'Скрытие транспорта отключено.',
            '{7CFC00}'
        )

    end

end

if imgui.Checkbox(
    u8'Убирать объекты',
    objectsEnabled
) then

    saveConfig()

    if objectsEnabled[0] then

        message(
            'Объекты будут блокироваться при создании.',
            '{FFD700}'
        )

    else

        message(
            'Скрытие объектов отключено.',
            '{7CFC00}'
        )

    end

end

end

local function drawGraphicsTab()

header(
    u8'Дальность прорисовки'
)

if imgui.Checkbox(
    u8'Изменять дальность 3D-текстов',
    text3dEnabled
) then

    saveConfig()

    if text3dEnabled[0] then

        message(
            'Ограничение 3D-текстов включено.',
            '{7CFC00}'
        )

    else

        message(
            'Ограничение 3D-текстов выключено.',
            '{FF6347}'
        )

    end

end

imgui.PushItemWidth(-1)

if imgui.SliderInt(
    '##3ddist',
    text3dDistance,
    0,
    100
) then

    text3dDistance[0] =
        clamp(
            text3dDistance[0],
            0,
            100
        )

    saveConfig()

end

imgui.PopItemWidth()

imgui.Text(
    u8(
        'Текущая дальность 3D-текстов: %d м'
    ):format(
        text3dDistance[0]
    )
)

separator()

header(
    u8'Аксессуары'
)

if imgui.Checkbox(
    u8'Убирать аксессуары всех игроков',
    accessoriesAll
) then

    saveConfig()

    if accessoriesAll[0] then

        message(
            'Аксессуары игроков будут скрываться.',
            '{7CFC00}'
        )

        lua_thread.create(
            function()

                wait(100)

                cleanAllStreamedAccessories()

            end
        )

    else

        message(
            'Убирание аксессуаров игроков выключено.',
            '{FF6347}'
        )

    end

end

if imgui.Checkbox(
    u8'Убирать мои аксессуары',
    accessoriesMe
) then

    saveConfig()

    if accessoriesMe[0] then

        message(
            'Ваши аксессуары будут скрываться.',
            '{7CFC00}'
        )

        lua_thread.create(
            function()

                wait(100)

                cleanAllStreamedAccessories()

            end
        )

    else

        message(
            'Убирание ваших аксессуаров выключено.',
            '{FF6347}'
        )

    end

end

end

local function drawInfoTab()

header(
    u8'Информация об авторе'
)

imgui.Text(
    u8'Автор скрипта: Killsize Genocide (True_Chad).'
)

imgui.Text(
    u8'Тг автора: @sxxydie.'
)

imgui.Text(
    u8'Тгк со скриптами и сборками на мобилы: @size1338.'
)

separator()

imgui.TextWrapped(
    u8'Этот скрипт был создан через ИИшку, я просто пидорасик. Анимки и бекграунд спиздил со скрипта пинокио и я их не буду убирать потому что я не только пидорасик.'
)

imgui.Dummy(
    imgui.ImVec2(
        0,
        5
    )
)

imgui.TextWrapped(
    u8'Крч, все функции блокируют создание новых объектов, игроков, 3д текстов и прочего, поэтому если вы хотите включить/выключить какую-то функцию: перезайдите в инту для желательного результата, или пиздуйте куда-то и объекты и вся хуйня не будет создаваться.'
)

imgui.Dummy(
    imgui.ImVec2(
        0,
        5
    )
)

imgui.TextWrapped(
    u8'Вот когда вы у себя убрали аксы то они убираются сразу. Но когда вы хотите их вернуть — то нужно сесть в машину и выйти с неё. Аксы с игроков работают по схеме выше.'
)

imgui.Dummy(
    imgui.ImVec2(
        0,
        5
    )
)

imgui.TextWrapped(
    u8'По багам, предложкам по улучшению в лс тг или в чат тгк, также пацаны и вообще ребятки будет обзорчик скрипта на моём ужасном ютуб-канале, и вообще не заходите туда ведь там очень страшно.'
)

end

-- =========================================================
-- IMGUI INITIALIZATION & MAIN FRAME
-- =========================================================

imgui.OnInitialize(
function()

    imgui.GetIO().IniFilename = nil

    applyStyle()

end

)

local WindowFrame =
imgui.OnFrame(
function()
return window[0]
end,

    function()

        local sw, sh =
            getScreenResolution()

        drawOverlay(
            sw,
            sh
        )

        local now =
            os.clock()

        local dt =
            math.min(
                now - lastTime,
                0.05
            )

        lastTime = now

        updateAndDrawParticles(
            dt,
            sw,
            sh
        )

        imgui.SetNextWindowPos(
            imgui.ImVec2(
                sw / 2,
                sh / 2
            ),
            imgui.Cond.FirstUseEver,
            imgui.ImVec2(
                0.5,
                0.5
            )
        )

        imgui.SetNextWindowSize(
            imgui.ImVec2(
                700,
                560
            ),
            imgui.Cond.FirstUseEver
        )

        if imgui.Begin(
            u8(
                'Rodina Optimizer | %s'
            ):format(
                SCRIPT_VERSION
            ),
            window
        ) then

            imgui.TextColored(
                imgui.ImVec4(
                    uiColor[0],
                    uiColor[1],
                    uiColor[2],
                    1.0
                ),
                u8'RODINA OPTIMIZER'
            )

            imgui.SameLine()

            imgui.TextColored(
                imgui.ImVec4(
                    0.55,
                    0.55,
                    0.60,
                    1.0
                ),
                '  ' ..
                SCRIPT_VERSION
            )

            separator()

            local tabCount = 4

            local tabSpacing =
                imgui.GetStyle().ItemSpacing.x

            local tabAreaWidth =
                imgui.GetWindowWidth() -
                imgui.GetStyle().WindowPadding.x * 2

            local tabWidth =
                (
                    tabAreaWidth -
                    tabSpacing *
                    (tabCount - 1)
                ) /
                tabCount

            tabButton(
                u8'Основные',
                1,
                tabWidth
            )

            imgui.SameLine()

            tabButton(
                u8'Мир',
                2,
                tabWidth
            )

            imgui.SameLine()

            tabButton(
                u8'Графика',
                3,
                tabWidth
            )

            imgui.SameLine()

            tabButton(
                u8'Инфо',
                4,
                tabWidth
            )

            separator()

            -- Анимация теперь без PushStyleVar,
            -- потому что в этой версии mimgui
            -- PushStyleVar отсутствует.

            local slide =
                tabSlideOffset()

            if slide > 0 then

                local pos =
                    imgui.GetCursorPos()

                imgui.SetCursorPos(
                    imgui.ImVec2(
                        pos.x,
                        pos.y + slide
                    )
                )

            end

            imgui.BeginChild(
                'OptimizerContent',
                imgui.ImVec2(
                    0,
                    -5
                ),
                true
            )

            if currentTab == 1 then

                drawGeneralTab()

            end

            if currentTab == 2 then

                drawWorldTab()

            end

            if currentTab == 3 then

                drawGraphicsTab()

            end

            if currentTab == 4 then

                drawInfoTab()

            end

            imgui.EndChild()

        end

        imgui.End()

    end
)

-- =========================================================
-- MAIN FUNCTION
-- =========================================================

function main()

while not isSampAvailable() do
    wait(100)
end

sampRegisterChatCommand(
    'opt',
    function()

        window[0] =
            not window[0]

        if not window[0] then

            particlesInited = false

        end

    end
)

wait(1000)

sampAddChatMessage(
    '{8A2BE2}[Rodina Optimizer] {FFFFFF}Загружен. {AAAAAA}/opt {FFFFFF}- открыть меню.',
    -1
)

while true do

    wait(100)

    -- Кэшируем ID игрока, чтобы не дергать нативки в пакетах
    local result, id =
        sampGetPlayerIdByCharHandle(
            PLAYER_PED
        )

    if result then

        localPlayerId = id

    else

        localPlayerId = -1

    end

    if accessoriesAll[0]
        or accessoriesMe[0] then

        local now =
            os.clock() * 1000

        if now -
            lastAccessoryCheck >=
            ACCESSORY_CHECK_INTERVAL then

            lastAccessoryCheck =
                now

            cleanAllStreamedAccessories()

        end

    else

        lastAccessoryCheck = 0

    end

end

end