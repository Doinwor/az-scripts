-- Porty Cleaner (MonetLoader UTF-8 )

local imgui = require 'mimgui'
local sampev = require 'samp.events'

local main_window_state = imgui.new.bool(false)

local del_player_active = imgui.new.bool(false)
local del_car_active = imgui.new.bool(false)
local del_object_active = imgui.new.bool(false)
local eat_active = imgui.new.bool(false)

local DEL_PLAYER = false
local DEL_CAR = false
local del_object = false
local auto_eat = false

local function u8(text) return text end

local mapp = 
{
	1000,
	1001,
	1002,
	1003,
	1004,
	1005,
	1006,
	1007,
	1011,
	1012,
	1013,
	1014,
	1015,
	1016,
	1017,
	1018,
	1019,
	1020,
	1021,
	1022,
	1023,
	1024,
	1025,
	1026,
	1027,
	1028,
	1029,
	1030,
	1031,
	1032,
	1033,
	1034,
	1035,
	1036,
	1037,
	1038,
	1039,
	1040,
	1041,
	1042,
	1043,
	1044,
	1045,
	1046,
	1047,
	1048,
	1049,
	1050,
	1051,
	1052,
	1053,
	1054,
	1055,
	1056,
	1057,
	1058,
	1059,
	1060,
	1061,
	1062,
	1063,
	1064,
	1065,
	1066,
	1067,
	1068,
	1069,
	1070,
	1071,
	1072,
	1073,
	1074,
	1075,
	1076,
	1077,
	1078,
	1079,
	1080,
	1081,
	1082,
	1083,
	1084,
	1085,
	1088,
	1089,
	1090,
	1091,
	1092,
	1093,
	1094,
	1095,
	1096,
	1097,
	1098,
	1099,
	1100,
	1101,
	1102,
	1103,
	1104,
	1105,
	1106,
	1107,
	1108,
	1110,
	1111,
	1112,
	1113,
	1114,
	1115,
	1116,
	1117,
	1118,
	1119,
	1120,
	1121,
	1122,
	1123,
	1124,
	1125,
	1126,
	1127,
	1128,
	1129,
	1130,
	1131,
	1132,
	1133,
	1134,
	1135,
	1136,
	1137,
	1138,
	1139,
	1140,
	1141,
	1142,
	1143,
	1144,
	1145,
	1146,
	1147,
	1148,
	1149,
	1150,
	1151,
	1152,
	1153,
	1154,
	1155,
	1156,
	1157,
	1158,
	1159,
	1160,
	1161,
	1162,
	1163,
	1164,
	1165,
	1166,
	1167,
	1168,
	1169,
	1170,
	1171,
	1172,
	1173,
	1174,
	1175,
	1176,
	1177,
	1178,
	1179,
	1180,
	1181,
	1182,
	1183,
	1184,
	1185,
	1186,
	1187,
	1188,
	1189,
	1190,
	1191,
	1192,
	1193,
	1327, 
	19741,
	3438,
	16101,
	19633,
	18835,
	2369,
	2411,
	2705,
	2829,
	2028,
	2103,
	2101,
	2105,
	2106,
	2316,
	2318,
	2369,
	2384,
	2404,
	2405,
	2406,
	2484,
	2485,
	2704,
	2852,
	2706,
	2705,
	2714,
	2854,
	2726,
	2828,
	1957,
	1785,
	1783,
	11704,
	11719,
	11718,
	11735,
	14705,
	19352,
	19878,
	19637,
	19638,
	19807,
	19584,
	19585,
	19624,
	19527,
	19736,
	18849,
	1807,
	2248,
	2654,
	15038,
	2241,
}

function FIND(model)
    for _, v in pairs(mapp) do
        if model == v then return true end
    end
    return false
end

imgui.OnFrame(
    function() return main_window_state[0] end,
    function()
        imgui.Begin(u8"Porty Cleaner")

        if imgui.Checkbox(u8"Удаление игроков", del_player_active) then
            DEL_PLAYER = del_player_active[0]
        end

        if imgui.Checkbox(u8"Удаление машин", del_car_active) then
            DEL_CAR = del_car_active[0]
        end

        if imgui.Checkbox(u8"Удаление объектов", del_object_active) then
            del_object = del_object_active[0]
        end

        if imgui.Checkbox(u8"Авто еда", eat_active) then
            auto_eat = eat_active[0]
        end

        imgui.End()
    end
)

function main()
    repeat wait(0) until isSampAvailable()

    sampRegisterChatCommand("pc", function()
        main_window_state[0] = not main_window_state[0]
    end)
end

function sampev.onPlayerStreamIn(playerId)
    if DEL_PLAYER then return false end
end

function sampev.onVehicleStreamIn(vehicleId)
    if DEL_CAR then return false end
end

function sampev.onCreateObject(objectId, data)
    if del_object and FIND(data.modelId) then return false end
end

function sampev.onDisplayGameText(style, time, text)
    if auto_eat and text:lower():find('hungry') then
        sampSendChat('/cheeps')
    end
end