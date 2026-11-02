local imgui = require('mimgui')
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local a = imgui.new.bool()
local ffi = require('ffi')
function emulFrontendMessage(interfaceid, subid, json)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 84)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteInt8(bs, subid)
    raknetBitStreamWriteInt32(bs, #json)
    raknetBitStreamWriteString(bs, json)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

function emulToggleInterface(interfaceid, toggle)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 62)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteBool(bs, toggle)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

NotifType = {
    SUCCESS = 1,
    FAILURE = 2,
    INFO = 3
}

function showArizonaNotification(type, title, text, duration)
    type = type or NotifType.INFO
    title = title or 'NULL VALUE'
    text = text or 'NULL VALUE'
    duration = duration or 3500
    emulToggleInterface(6, true)
    emulFrontendMessage(6, 0, encodeJson({
        styleInt = type,
        title = title,
        text = text,
        duration = duration
    }))
end

function main()
    sampRegisterChatCommand('notif', function(arg)
        a[0] = not a[0]
    end)
    wait(-1)
end

local ComboTest = imgui.new.int() -- создаём буфер для комбо
local item_list = {u8'SUCCESS', u8'FAILULE', u8'INFO'} -- создаём таблицу с содержимым списка
local ImItems = imgui.new['const char*'][#item_list](item_list)
local inputField = imgui.new.char[256]()
local inputField2 = imgui.new.char[256]()
local slider = imgui.new.int()

-- в мимгуи

imgui.OnFrame(function() return a[0] end, function(player)
    imgui.Begin('Arizona Notification Demonstration', a)
    imgui.Text(u8'Для того чтобы сделать Notification заполните поля ниже:')
    imgui.Combo(u8'Типы', ComboTest, ImItems, #item_list)
    imgui.InputText(u8"Заголовок", inputField, 256)
    imgui.InputText(u8"Текст", inputField2, 256)
    imgui.SliderInt(u8'Длительность (мс)', slider, 0, 5000)
    if imgui.Button(u8'Вывести') then
        showArizonaNotification(ComboTest[0]+1, u8:decode(ffi.string(inputField)), u8:decode(ffi.string(inputField2)), slider[0])
    end
    imgui.End()
end)