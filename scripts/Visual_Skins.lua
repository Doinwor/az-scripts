script_name('SkinChanger')
script_author('Victor Strand')
script_version('1.2')
local imgui    = require('mimgui')
local sampev   = require('lib.samp.events')
local inicfg   = require('inicfg')
local encoding = require('encoding')
local faicons  = require('fAwesome6')
local fa       = require('fAwesome6_solid')
local ffi      = require('ffi')
local new      = imgui.new
encoding.default = 'CP1251'
u8 = encoding.UTF8
local MDS = MONET_DPI_SCALE * 0.9
local CFG_FILE    = 'SkinChanger.ini'
local CFG_VERSION = 3
local PAGE_SIZE   = 150
local SKIN_OFF    = -1
local ini = inicfg.load({
    main = {
        skin       = SKIN_OFF,
        favorites  = '',
        winX       = -1,
        winY       = -1,
        winW       = -1,
        winH       = -1,
        subscribed = 'false',
        ver        = 0,
    }
}, CFG_FILE)
inicfg.save(ini, CFG_FILE)
local TG_LINK  = 'https://t.me/strand_scripts'
local YT_LINK  = 'https://youtube.com/@strand_samp'
local TT_LINK  = 'https://www.tiktok.com/@victor_st1'
local gta = ffi.load('GTASA')
ffi.cdef[[ void _Z12AND_OpenLinkPKc(const char* link); ]]
local function openLink(url)
    pcall(gta._Z12AND_OpenLinkPKc, url)
end
local skins = {
    {id = 0,     name = 'Carl "CJ" Johnson (Main Character)'},
    {id = 1,     name = 'The Truth'},
    {id = 2,     name = 'Maccer'},
    {id = 3,     name = 'Andre'},
    {id = 4,     name = 'Barry "Big Bear" Thorne [Thin]'},
    {id = 5,     name = 'Barry "Big Bear" Thorne [Big]'},
    {id = 6,     name = 'Emmet'},
    {id = 7,     name = 'Taxi Driver/Train Driver'},
    {id = 8,     name = 'Janitor'},
    {id = 9,     name = 'Normal Ped'},
    {id = 10,    name = 'Old Woman'},
    {id = 11,    name = 'Casino croupier'},
    {id = 12,    name = 'Rich Woman'},
    {id = 13,    name = 'Street Girl'},
    {id = 14,    name = 'Normal Ped'},
    {id = 15,    name = 'Mr.Whittaker (RS Haul Owner)'},
    {id = 16,    name = 'Airport Ground Worker'},
    {id = 17,    name = 'Businessman'},
    {id = 18,    name = 'Beach Visitor'},
    {id = 19,    name = 'DJ'},
    {id = 20,    name = "Rich Guy (Madd Dogg's Manager)"},
    {id = 21,    name = 'Normal Ped'},
    {id = 22,    name = 'Normal Ped'},
    {id = 23,    name = 'BMXer'},
    {id = 24,    name = 'Madd Dogg Bodyguard'},
    {id = 25,    name = 'Madd Dogg Bodyguard'},
    {id = 26,    name = 'Backpacker'},
    {id = 27,    name = 'Construction Worker'},
    {id = 28,    name = 'Drug Dealer'},
    {id = 29,    name = 'Drug Dealer'},
    {id = 30,    name = 'Drug Dealer'},
    {id = 31,    name = 'Farm-Town inhabitant'},
    {id = 32,    name = 'Farm-Town inhabitant'},
    {id = 33,    name = 'Farm-Town inhabitant'},
    {id = 34,    name = 'Farm-Town inhabitant'},
    {id = 35,    name = 'Gardener'},
    {id = 36,    name = 'Golfer'},
    {id = 37,    name = 'Golfer'},
    {id = 38,    name = 'Normal Ped'},
    {id = 39,    name = 'Normal Ped'},
    {id = 40,    name = 'Normal Ped'},
    {id = 41,    name = 'Normal Ped'},
    {id = 42,    name = 'Jethro'},
    {id = 43,    name = 'Normal Ped'},
    {id = 44,    name = 'Normal Ped'},
    {id = 45,    name = 'Beach Visitor'},
    {id = 46,    name = 'Normal Ped'},
    {id = 47,    name = 'Normal Ped'},
    {id = 48,    name = 'Normal Ped'},
    {id = 49,    name = 'Snakehead (Da Nang)'},
    {id = 50,    name = 'Mechanic'},
    {id = 51,    name = 'Mountain Biker'},
    {id = 52,    name = 'Mountain Biker'},
    {id = 53,    name = 'Unknown'},
    {id = 54,    name = 'Normal Ped'},
    {id = 55,    name = 'Normal Ped'},
    {id = 56,    name = 'Normal Ped'},
    {id = 57,    name = 'Oriental Ped'},
    {id = 58,    name = 'Oriental Ped'},
    {id = 59,    name = 'Normal Ped'},
    {id = 60,    name = 'Normal Ped'},
    {id = 61,    name = 'Pilot'},
    {id = 62,    name = 'Colonel Fuhrberger'},
    {id = 63,    name = 'Prostitute'},
    {id = 64,    name = 'Prostitute'},
    {id = 65,    name = 'Kendl Johnson'},
    {id = 66,    name = 'Pool Player'},
    {id = 67,    name = 'Pool Player'},
    {id = 68,    name = 'Priest/Preacher'},
    {id = 69,    name = 'Normal Ped'},
    {id = 70,    name = 'Scientist'},
    {id = 71,    name = 'Security Guard'},
    {id = 72,    name = 'Hippy'},
    {id = 73,    name = 'Hippy'},
    {id = 74,    name = '-'},
    {id = 75,    name = 'Prostitute'},
    {id = 76,    name = 'Stewardess'},
    {id = 77,    name = 'Homeless'},
    {id = 78,    name = 'Homeless'},
    {id = 79,    name = 'Homeless'},
    {id = 80,    name = 'Boxer'},
    {id = 81,    name = 'Boxer'},
    {id = 82,    name = 'Black Elvis'},
    {id = 83,    name = 'White Elvis'},
    {id = 84,    name = 'Blue Elvis'},
    {id = 85,    name = 'Prostitute'},
    {id = 86,    name = 'Ryder with robbery mask'},
    {id = 87,    name = 'Stripper'},
    {id = 88,    name = 'Normal Ped'},
    {id = 89,    name = 'Normal Ped'},
    {id = 90,    name = 'Jogger'},
    {id = 91,    name = 'Rich Woman'},
    {id = 92,    name = 'Rollerskater'},
    {id = 93,    name = 'Normal Ped'},
    {id = 94,    name = 'Normal Ped'},
    {id = 95,    name = 'Normal Ped, Works at Dillimore Gas Station'},
    {id = 96,    name = 'Jogger'},
    {id = 97,    name = 'Lifeguard'},
    {id = 98,    name = 'Normal Ped'},
    {id = 99,    name = 'Rollerskater'},
    {id = 100,   name = 'Biker'},
    {id = 101,   name = 'Normal Ped'},
    {id = 102,   name = 'Balla'},
    {id = 103,   name = 'Balla'},
    {id = 104,   name = 'Balla'},
    {id = 105,   name = 'Grove Street Families'},
    {id = 106,   name = 'Grove Street Families'},
    {id = 107,   name = 'Grove Street Families'},
    {id = 108,   name = 'Los Santos Vagos'},
    {id = 109,   name = 'Los Santos Vagos'},
    {id = 110,   name = 'Los Santos Vagos'},
    {id = 111,   name = 'The Russian Mafia'},
    {id = 112,   name = 'The Russian Mafia'},
    {id = 113,   name = 'The Russian Mafia'},
    {id = 114,   name = 'Varios Los Aztecas'},
    {id = 115,   name = 'Varios Los Aztecas'},
    {id = 116,   name = 'Varios Los Aztecas'},
    {id = 117,   name = 'Triad'},
    {id = 118,   name = 'Triad'},
    {id = 119,   name = 'Johhny Sindacco'},
    {id = 120,   name = 'Triad Boss'},
    {id = 121,   name = 'Da Nang Boy'},
    {id = 122,   name = 'Da Nang Boy'},
    {id = 123,   name = 'Da Nang Boy'},
    {id = 124,   name = 'The Mafia'},
    {id = 125,   name = 'The Mafia'},
    {id = 126,   name = 'The Mafia'},
    {id = 127,   name = 'The Mafia'},
    {id = 128,   name = 'Farm Inhabitant'},
    {id = 129,   name = 'Farm Inhabitant'},
    {id = 130,   name = 'Farm Inhabitant'},
    {id = 131,   name = 'Farm Inhabitant'},
    {id = 132,   name = 'Farm Inhabitant'},
    {id = 133,   name = 'Farm Inhabitant'},
    {id = 134,   name = 'Homeless'},
    {id = 135,   name = 'Homeless'},
    {id = 136,   name = 'Normal Ped'},
    {id = 137,   name = 'Homeless'},
    {id = 138,   name = 'Beach Visitor'},
    {id = 139,   name = 'Beach Visitor'},
    {id = 140,   name = 'Beach Visitor'},
    {id = 141,   name = 'Businesswoman'},
    {id = 142,   name = 'Taxi Driver'},
    {id = 143,   name = 'Crack Maker'},
    {id = 144,   name = 'Crack Maker'},
    {id = 145,   name = 'Crack Maker'},
    {id = 146,   name = 'Crack Maker'},
    {id = 147,   name = 'Businessman'},
    {id = 148,   name = 'Businesswoman'},
    {id = 149,   name = 'Big Smoke Armored'},
    {id = 150,   name = 'Businesswoman'},
    {id = 151,   name = 'Normal Ped'},
    {id = 152,   name = 'Prostitute'},
    {id = 153,   name = 'Construction Worker'},
    {id = 154,   name = 'Beach Visitor'},
    {id = 155,   name = 'Well Stacked Pizza Worker'},
    {id = 156,   name = 'Barber'},
    {id = 157,   name = 'Hillbilly'},
    {id = 158,   name = 'Farmer'},
    {id = 159,   name = 'Hillbilly'},
    {id = 160,   name = 'Hillbilly'},
    {id = 161,   name = 'Farmer'},
    {id = 162,   name = 'Hillbilly'},
    {id = 163,   name = 'Black Bouncer'},
    {id = 164,   name = 'White Bouncer'},
    {id = 165,   name = 'White MIB agent'},
    {id = 166,   name = 'Black MIB agent'},
    {id = 167,   name = "Cluckin' Bell Worker"},
    {id = 168,   name = 'Hotdog/Chilli Dog Vendor'},
    {id = 169,   name = 'Normal Ped'},
    {id = 170,   name = 'Normal Ped'},
    {id = 171,   name = 'Blackjack Dealer'},
    {id = 172,   name = 'Casino croupier'},
    {id = 173,   name = 'San Fierro Rifa'},
    {id = 174,   name = 'San Fierro Rifa'},
    {id = 175,   name = 'San Fierro Rifa'},
    {id = 176,   name = 'Barber'},
    {id = 177,   name = 'Barber'},
    {id = 178,   name = 'Whore'},
    {id = 179,   name = 'Ammunation Salesman'},
    {id = 180,   name = 'Tattoo Artist'},
    {id = 181,   name = 'Punk'},
    {id = 182,   name = 'Cab Driver'},
    {id = 183,   name = 'Normal Ped'},
    {id = 184,   name = 'Normal Ped'},
    {id = 185,   name = 'Normal Ped'},
    {id = 186,   name = 'Normal Ped'},
    {id = 187,   name = 'Businessman'},
    {id = 188,   name = 'Normal Ped'},
    {id = 189,   name = 'Valet'},
    {id = 190,   name = 'Barbara Schternvart'},
    {id = 191,   name = 'Helena Wankstein'},
    {id = 192,   name = 'Michelle Cannes'},
    {id = 193,   name = 'Katie Zhan'},
    {id = 194,   name = 'Millie Perkins'},
    {id = 195,   name = 'Denise Robinson'},
    {id = 196,   name = 'Farm-Town inhabitant'},
    {id = 197,   name = 'Hillbilly'},
    {id = 198,   name = 'Farm-Town inhabitant'},
    {id = 199,   name = 'Farm-Town inhabitant'},
    {id = 200,   name = 'Hillbilly'},
    {id = 201,   name = 'Farmer'},
    {id = 202,   name = 'Farmer'},
    {id = 203,   name = 'Karate Teacher'},
    {id = 204,   name = 'Karate Teacher'},
    {id = 205,   name = 'Burger Shot Cashier'},
    {id = 206,   name = 'Cab Driver'},
    {id = 207,   name = 'Prostitute'},
    {id = 208,   name = 'Su Xi Mu (Suzie)'},
    {id = 209,   name = 'Oriental Noodle stand vendor'},
    {id = 210,   name = 'Oriental Boating School Instructor'},
    {id = 211,   name = 'Clothes shop staff'},
    {id = 212,   name = 'Homeless'},
    {id = 213,   name = 'Weird old man'},
    {id = 214,   name = 'Waitress (Maria Latore)'},
    {id = 215,   name = 'Normal Ped'},
    {id = 216,   name = 'Normal Ped'},
    {id = 217,   name = 'Clothes shop staff'},
    {id = 218,   name = 'Normal Ped'},
    {id = 219,   name = 'Rich Woman'},
    {id = 220,   name = 'Cab Driver'},
    {id = 221,   name = 'Normal Ped'},
    {id = 222,   name = 'Normal Ped'},
    {id = 223,   name = 'Normal Ped'},
    {id = 224,   name = 'Normal Ped'},
    {id = 225,   name = 'Normal Ped'},
    {id = 226,   name = 'Normal Ped'},
    {id = 227,   name = 'Oriental Businessman'},
    {id = 228,   name = 'Oriental Ped'},
    {id = 229,   name = 'Oriental Ped'},
    {id = 230,   name = 'Homeless'},
    {id = 231,   name = 'Normal Ped'},
    {id = 232,   name = 'Normal Ped'},
    {id = 233,   name = 'Normal Ped'},
    {id = 234,   name = 'Cab Driver'},
    {id = 235,   name = 'Normal Ped'},
    {id = 236,   name = 'Normal Ped'},
    {id = 237,   name = 'Prostitute'},
    {id = 238,   name = 'Prostitute'},
    {id = 239,   name = 'Homeless'},
    {id = 240,   name = 'The D.A'},
    {id = 241,   name = 'Afro-American'},
    {id = 242,   name = 'Mexican'},
    {id = 243,   name = 'Prostitute'},
    {id = 244,   name = 'Stripper'},
    {id = 245,   name = 'Prostitute'},
    {id = 246,   name = 'Stripper'},
    {id = 247,   name = 'Biker'},
    {id = 248,   name = 'Biker'},
    {id = 249,   name = 'Pimp'},
    {id = 250,   name = 'Normal Ped'},
    {id = 251,   name = 'Lifeguard'},
    {id = 252,   name = 'Naked Valet'},
    {id = 253,   name = 'Bus Driver'},
    {id = 254,   name = 'Biker Drug Dealer'},
    {id = 255,   name = 'Chauffeur (Limo Driver)'},
    {id = 256,   name = 'Stripper'},
    {id = 257,   name = 'Stripper'},
    {id = 258,   name = 'Heckler'},
    {id = 259,   name = 'Heckler'},
    {id = 260,   name = 'Construction Worker'},
    {id = 261,   name = 'Cab driver'},
    {id = 262,   name = 'Cab driver'},
    {id = 263,   name = 'Normal Ped'},
    {id = 264,   name = 'Clown (Ice-cream Van Driver)'},
    {id = 265,   name = 'Officer Frank Tenpenny (Corrupt Cop)'},
    {id = 266,   name = 'Officer Eddie Pulaski (Corrupt Cop)'},
    {id = 267,   name = 'Officer Jimmy Hernandez'},
    {id = 268,   name = 'Dwaine/Dwayne'},
    {id = 269,   name = 'Melvin "Big Smoke" Harris (Mission)'},
    {id = 270,   name = "Sean 'Sweet' Johnson"},
    {id = 271,   name = "Lance 'Ryder' Wilson"},
    {id = 272,   name = 'Mafia Boss'},
    {id = 273,   name = 'T-Bone Mendez'},
    {id = 274,   name = 'Paramedic (Emergency Medical Technician)'},
    {id = 275,   name = 'Paramedic (Emergency Medical Technician)'},
    {id = 276,   name = 'Paramedic (Emergency Medical Technician)'},
    {id = 277,   name = 'Firefighter'},
    {id = 278,   name = 'Firefighter'},
    {id = 279,   name = 'Firefighter'},
    {id = 280,   name = 'Los Santos Police Officer'},
    {id = 281,   name = 'San Fierro Police Officer'},
    {id = 282,   name = 'Las Venturas Police Officer'},
    {id = 283,   name = 'County Sheriff'},
    {id = 284,   name = 'LSPD Motorbike Cop'},
    {id = 285,   name = 'S.W.A.T Special Forces'},
    {id = 286,   name = 'Federal Agent'},
    {id = 287,   name = 'San Andreas Army'},
    {id = 288,   name = 'Desert Sheriff'},
    {id = 289,   name = 'Zero'},
    {id = 290,   name = 'Ken Rosenberg'},
    {id = 291,   name = 'Kent Paul'},
    {id = 292,   name = 'Cesar Vialpando'},
    {id = 293,   name = 'Jeffery "OG Loc" Martin/Cross'},
    {id = 294,   name = 'Wu Zi Mu (Woozie)'},
    {id = 295,   name = 'Michael Toreno'},
    {id = 296,   name = 'Jizzy B.'},
    {id = 297,   name = 'Madd Dogg'},
    {id = 298,   name = 'Catalina'},
    {id = 299,   name = 'Claude Speed'},
    {id = 300,   name = 'Los Santos Police Officer (Without gun holster)'},
    {id = 301,   name = 'San Fierro Police Officer (Without gun holster)'},
    {id = 302,   name = 'Las Venturas Police Officer (Without gun holster)'},
    {id = 303,   name = 'Los Santos Police Officer (Without uniform)'},
    {id = 304,   name = 'Los Santos Police Officer (Without uniform)'},
    {id = 305,   name = 'Las Venturas Police Officer (Without uniform)'},
    {id = 306,   name = 'Los Santos Police Officer'},
    {id = 307,   name = 'San Fierro Police Officer'},
    {id = 308,   name = 'San Fierro Paramedic (Emergency Medical Technician)'},
    {id = 309,   name = 'Las Venturas Police Officer'},
    {id = 310,   name = 'Country Sheriff (Without hat)'},
    {id = 311,   name = 'Desert Sheriff (Without hat)'},
    {id = 312,   name = 'albert'},
    {id = 313,   name = 'amiran'},
    {id = 314,   name = 'bathory'},
    {id = 315,   name = 'brulov'},
    {id = 316,   name = 'creed'},
    {id = 317,   name = 'delorenzy'},
    {id = 318,   name = 'edvardbil'},
    {id = 319,   name = 'lj'},
    {id = 329,   name = 'evaelfie'},
    {id = 332,   name = 'feduk'},
    {id = 340,   name = 'kovalevsky'},
    {id = 382,   name = 'litvin'},
    {id = 383,   name = 'maras'},
    {id = 398,   name = 'morgershtern'},
    {id = 399,   name = 'nurmagamedov'},
    {id = 795,   name = 'oxymiron'},
    {id = 796,   name = 'dante'},
    {id = 797,   name = 'ravyazan'},
    {id = 798,   name = 'romeru'},
    {id = 799,   name = 'sammason'},
    {id = 907,   name = 'shurigina'},
    {id = 908,   name = 'valik'},
    {id = 999,   name = 'umpa_lump'},
    {id = 1206,  name = 'basta'},
    {id = 1326,  name = 'byzova'},
    {id = 1573,  name = 'dzyuba'},
    {id = 1699,  name = 'urgant'},
    {id = 2883,  name = 'khovanksy'},
    {id = 2884,  name = 'lukashenko'},
    {id = 3136,  name = 'maddyson'},
    {id = 3137,  name = 'noize'},
    {id = 3138,  name = 'technic'},
    {id = 3139,  name = 'restorator'},
    {id = 3140,  name = 'richi'},
    {id = 3141,  name = 'sashagrey'},
    {id = 3142,  name = 'yurydud'},
    {id = 3143,  name = 'snowman'},
    {id = 3144,  name = 'elf'},
    {id = 3145,  name = 'farmernewyear'},
    {id = 3146,  name = 'dedmoroz'},
    {id = 3147,  name = 'yoda'},
    {id = 3148,  name = 'leshiy'},
    {id = 3149,  name = 'newshuba'},
    {id = 3150,  name = 'deer'},
    {id = 3151,  name = 'penguin'},
    {id = 3152,  name = 'snegurochka'},
    {id = 3153,  name = 'footba'},
    {id = 3154,  name = 'elfa'},
    {id = 3159,  name = 'gentelman1'},
    {id = 3160,  name = 'gentelman2'},
    {id = 3161,  name = 'gentelman3'},
    {id = 3162,  name = 'gentelman4'},
    {id = 3163,  name = 'gentelman5'},
    {id = 3164,  name = 'gentelman6'},
    {id = 3165,  name = 'minecraft1'},
    {id = 3166,  name = 'minecraft2'},
    {id = 3176,  name = 'minecraft3'},
    {id = 3177,  name = 'minecraft4'},
    {id = 3179,  name = 'minecraft5'},
    {id = 3180,  name = 'minecraft6'},
    {id = 3181,  name = 'minecraft7'},
    {id = 3182,  name = 'minecraft8'},
    {id = 3183,  name = 'minecraft9'},
    {id = 3184,  name = 'minecraft10'},
    {id = 3185,  name = 'navalny'},
    {id = 3186,  name = 'putin'},
    {id = 3188,  name = 'ironman'},
    {id = 3189,  name = 'spiderman'},
    {id = 3190,  name = 'venom'},
    {id = 3191,  name = 'captainamerica'},
    {id = 3192,  name = 'batman'},
    {id = 3225,  name = 'anonimys'},
    {id = 3226,  name = 'rabbit1'},
    {id = 3227,  name = 'rabbit2'},
    {id = 3228,  name = 'rabbit3'},
    {id = 3229,  name = 'rabbit4'},
    {id = 3230,  name = 'rabbit5'},
    {id = 3231,  name = 'rabbitfarmer'},
    {id = 3349,  name = 'alpachino'},
    {id = 3416,  name = 'bradpitt'},
    {id = 3429,  name = 'dikaprio'},
    {id = 3610,  name = 'disel'},
    {id = 3611,  name = 'kianu'},
    {id = 3784,  name = 'imask'},
    {id = 3870,  name = 'robertjr'},
    {id = 3871,  name = 'shwarz'},
    {id = 3883,  name = 'statham'},
    {id = 3889,  name = 'tarantino'},
    {id = 4549,  name = 'stalone'},
    {id = 4763,  name = 'murphy'},
    {id = 4764,  name = 'hardy'},
    {id = 4765,  name = 'tyson'},
    {id = 4766,  name = 'kanye'},
    {id = 4767,  name = 'mcgregor'},
    {id = 4768,  name = 'travolta'},
    {id = 4769,  name = 'cluni'},
    {id = 4770,  name = 'markcyker'},
    {id = 4771,  name = 'dwaynej'},
    {id = 4772,  name = 'kage'},
    {id = 4773,  name = 'will'},
    {id = 4804,  name = 'aaron'},
    {id = 4805,  name = 'cooper'},
    {id = 5085,  name = 'defo'},
    {id = 5090,  name = 'evans'},
    {id = 5091,  name = 'ryan'},
    {id = 5092,  name = 'hannem'},
    {id = 5093,  name = 'hbirth1'},
    {id = 5094,  name = 'hbirth2'},
    {id = 5095,  name = 'hbirth3'},
    {id = 5096,  name = 'hbirth4'},
    {id = 5097,  name = 'hbirth5'},
    {id = 5098,  name = 'hbirth6'},
    {id = 5099,  name = 'hbirth7'},
    {id = 5100,  name = 'hbirth8'},
    {id = 5101,  name = 'hbirth9'},
    {id = 5102,  name = 'hbirth10'},
    {id = 5103,  name = 'jackiechan'},
    {id = 5104,  name = 'maccon'},
    {id = 5376,  name = 'matt'},
    {id = 5377,  name = 'morgan'},
    {id = 5378,  name = 'tatum'},
    {id = 5379,  name = 'polyok'},
    {id = 5380,  name = 'wood'},
    {id = 5381,  name = 'beth'},
    {id = 5382,  name = 'big_g'},
    {id = 5383,  name = 'gnom'},
    {id = 5384,  name = 'goblin1'},
    {id = 5385,  name = 'goblin2'},
    {id = 5386,  name = 'goblin3'},
    {id = 5387,  name = 'grinchjim'},
    {id = 5388,  name = 'lmike'},
    {id = 5389,  name = 'morty'},
    {id = 5683,  name = 'olen'},
    {id = 5684,  name = 'osel'},
    {id = 5685,  name = 'rick'},
    {id = 5686,  name = 'rofls'},
    {id = 5687,  name = 'yeti'},
    {id = 5688,  name = 'fiona'},
    {id = 5689,  name = 'fionah'},
    {id = 5690,  name = 'shrek'},
    {id = 5691,  name = 'shrek2'},
    {id = 5692,  name = 'wolf'},
    {id = 6014,  name = 'hall0'},
    {id = 6015,  name = 'hall1'},
    {id = 6016,  name = 'hall2'},
    {id = 6017,  name = 'hall4'},
    {id = 6018,  name = 'hall5'},
    {id = 6019,  name = 'hall6'},
    {id = 6020,  name = 'hall7'},
    {id = 6021,  name = 'hasbik'},
    {id = 6022,  name = 'hellmem'},
    {id = 6023,  name = 'pubgmaskgirl'},
    {id = 6024,  name = 'pubgmaskman'},
    {id = 6025,  name = 'pubggirl1'},
    {id = 6026,  name = 'pubgman1'},
    {id = 6027,  name = 'pubggirl2'},
    {id = 6028,  name = 'pubgman2'},
    {id = 6029,  name = 'pubggirl3'},
    {id = 6030,  name = 'pubgman3'},
    {id = 6031,  name = 'pubggirl4'},
    {id = 6032,  name = 'pubgman4'},
    {id = 6545,  name = 'adidas'},
    {id = 6546,  name = 'farquad'},
    {id = 6547,  name = 'gwendolyn'},
    {id = 6548,  name = 'jizzly'},
    {id = 6549,  name = 'marat'},
    {id = 6550,  name = 'palto'},
    {id = 6551,  name = 'ptich'},
    {id = 6552,  name = 'summer'},
    {id = 6557,  name = 'aura'},
    {id = 6558,  name = 'aza'},
    {id = 6559,  name = 'crack1'},
    {id = 6560,  name = 'fishscale'},
    {id = 6561,  name = 'gojo'},
    {id = 6562,  name = 'midas'},
    {id = 6563,  name = 'nalog1'},
    {id = 6583,  name = 'nalog2'},
    {id = 6584,  name = 'ninja'},
    {id = 6585,  name = 'yen'},
    {id = 6586,  name = 'twinl'},
    {id = 6587,  name = 'twinr'},
    {id = 6588,  name = 'taker'},
    {id = 6589,  name = 'jrc'},
    {id = 6590,  name = 'peely'},
    {id = 6591,  name = 'huntert'},
    {id = 6592,  name = 'hogan'},
    {id = 6593,  name = 'hbk'},
    {id = 6594,  name = 'egg'},
    {id = 6595,  name = 'cena'},
    {id = 6596,  name = 'stonegolem'},
    {id = 6597,  name = 'wildcat'},
    {id = 6598,  name = 'cat1'},
    {id = 6599,  name = 'braun'},
    {id = 6627,  name = 'irina'},
    {id = 6661,  name = 'ak'},
    {id = 6662,  name = 'bandit'},
    {id = 6663,  name = 'degtyarev'},
    {id = 6664,  name = 'dolgovec'},
    {id = 6665,  name = 'karl'},
    {id = 6666,  name = 'me4eniy'},
    {id = 6667,  name = 'natasha'},
    {id = 6668,  name = 'penek'},
    {id = 6669,  name = 'sidorovich'},
    {id = 6670,  name = 'vova'},
    {id = 6671,  name = 'wanderer'},
    {id = 6672,  name = 'wolter'},
    {id = 6689,  name = 'girl1'},
    {id = 6690,  name = 'girl2'},
    {id = 6691,  name = 'men1'},
    {id = 6692,  name = 'dmen4'},
    {id = 6701,  name = 'billie'},
    {id = 6703,  name = 'belleniko'},
    {id = 6704,  name = 'dit'},
    {id = 6705,  name = 'dvoreckov'},
    {id = 6706,  name = 'ernesto'},
    {id = 6707,  name = 'gorshok'},
    {id = 6708,  name = 'noro'},
    {id = 6791,  name = 'zomfat'},
    {id = 6792,  name = 'zomskin'},
    {id = 6793,  name = 'davydj'},
    {id = 6794,  name = 'pir3'},
    {id = 6795,  name = 'pirat'},
    {id = 6796,  name = 'pirm1'},
    {id = 6797,  name = 'pirw2'},
    {id = 6798,  name = 'fpirat'},
    {id = 9202,  name = '5ka'},
    {id = 11786, name = 'shock'},
    {id = 11787, name = 'sclaus'},
    {id = 11789, name = 'barrel'},
    {id = 11790, name = 'lock'},
    {id = 11791, name = 'jackx'},
    {id = 11792, name = 'jackskel'},
    {id = 11793, name = 'sally'},
    {id = 11795, name = 'antim'},
    {id = 11796, name = 'facevoid'},
    {id = 11797, name = 'phantoml'},
    {id = 11798, name = 'pudge'},
    {id = 11799, name = 'ringm'},
    {id = 11801, name = 'voker'},
    {id = 11802, name = 'wking'},
    {id = 11803, name = 'amf'},
    {id = 11804, name = 'lanaya'},
    {id = 11805, name = 'marci'},
    {id = 11807, name = 'rilai'},
    {id = 11808, name = 'joke'},
    {id = 11809, name = 'supa'},
    {id = 11812, name = 'traxa'},
    {id = 11813, name = 'mummy_boi'},
    {id = 11814, name = 'ogboogie'},
    {id = 12032, name = 'devilboss'},
    {id = 12033, name = 'icec'},
    {id = 12034, name = 'biggi'},
    {id = 12035, name = 'tupak'},
    {id = 12036, name = 'locd'},
    {id = 12037, name = 'arocky'},
    {id = 12038, name = 'corleone'},
    {id = 12039, name = 'alt'},
    {id = 12040, name = 'lfam1'},
    {id = 12041, name = 'llsv1'},
    {id = 12042, name = 'xtentacion'},
    {id = 12043, name = 'treho'},
    {id = 12044, name = 'snoop'},
    {id = 12045, name = 'diedn'},
    {id = 12046, name = 'yoland'},
    {id = 12047, name = 'skuf'},
    {id = 12061, name = 'behemoth'},
    {id = 12062, name = 'cursekid'},
    {id = 12063, name = 'xmsmayor'},
    {id = 12151, name = 'invisible'},
    {id = 12152, name = 'hika1'},
    {id = 12153, name = 'hika2'},
    {id = 12154, name = 'hika3'},
    {id = 12155, name = 'hika4'},
    {id = 12156, name = 'hika5'},
    {id = 12157, name = 'babka1'},
    {id = 12158, name = 'babka2'},
    {id = 12159, name = 'depo'},
    {id = 12160, name = 'diva'},
    {id = 12161, name = 'dtrump'},
    {id = 12162, name = 'face'},
    {id = 12163, name = 'grib1'},
    {id = 12164, name = 'grib2'},
    {id = 12165, name = 'molly'},
    {id = 12166, name = 'nagiev'},
    {id = 12167, name = 'nvasil'},
    {id = 12168, name = 'rabitgrl'},
    {id = 12169, name = 'slavik'},
    {id = 12171, name = 'harly'},
    {id = 12176, name = 'rab_m'},
    {id = 12177, name = 'rab_w'},
    {id = 12178, name = 'farmer'},
    {id = 12182, name = 'pharaoh'},
    {id = 12183, name = 'mercy'},
    {id = 12184, name = 'fox2'},
    {id = 12185, name = 'judy2'},
    {id = 12186, name = 'schlg'},
    {id = 12187, name = 'schlm'},
    {id = 12188, name = 'larin'},
    {id = 12392, name = 'armyponch'},
    {id = 12395, name = 'ghrid'},
    {id = 12415, name = '10pencivil'},
    {id = 12489, name = 'zek2', isNew = true},
    {id = 12490, name = 'zek3', isNew = true},
    {id = 12491, name = 'zomb1_n'},
    {id = 12492, name = 'zombie2_n'},
    {id = 12493, name = 'zomb3_n'},
    {id = 12494, name = 'skeleton'},
    {id = 12519, name = 'm_gose2', isNew = true},
    {id = 12520, name = 'm_gose1', isNew = true},
    {id = 12521, name = 'gosw', isNew = true},
    {id = 12592, name = 'b_lich'},
    {id = 12593, name = 'b_lich1'},
    {id = 12594, name = 'dcfranz'},
    {id = 12595, name = 'drak'},
    {id = 12596, name = 'frank1'},
    {id = 12597, name = 'helsing'},
    {id = 12608, name = 'lich'},
    {id = 12609, name = 'rooster'},
    {id = 12610, name = 'jan'},
    {id = 12612, name = 'sabrina2'},
    {id = 12617, name = 'vdra'},
    {id = 12629, name = 'ellie'},
    {id = 12641, name = 'toph'},
    {id = 12642, name = 'aang'},
    {id = 12643, name = 'zuko'},
    {id = 12644, name = 'pubgf'},
    {id = 12645, name = 'pubgm1'},
    {id = 12646, name = 'pubg1'},
    {id = 12647, name = 'pubg2'},
    {id = 12648, name = 'asuka'},
    {id = 12649, name = 'rei'},
    {id = 12650, name = 'mell'},
    {id = 12654, name = 'baiden'},
    {id = 12655, name = 'bumbl'},
    {id = 12656, name = 'demorog'},
    {id = 12658, name = 'optimus'},
    {id = 12660, name = 'acuddle'},
    {id = 12661, name = 'vi'},
    {id = 12662, name = 'castor'},
    {id = 12663, name = 'crazy8'},
    {id = 12664, name = 'doggo'},
    {id = 12665, name = 'fallenl'},
    {id = 12667, name = 'sanboy'},
    {id = 12672, name = 'bunny1'},
    {id = 12673, name = 'bunny2'},
    {id = 12674, name = 'bunny3'},
    {id = 12675, name = 'shagg'},
    {id = 12676, name = 'alien'},
    {id = 12700, name = 'chistmasbomj1'},
    {id = 12701, name = 'chistmasbomj2'},
    {id = 12702, name = 'chistmasbomj3'},
    {id = 12703, name = 'chistmasbomj4'},
    {id = 12704, name = 'chistmasbomj5'},
    {id = 12705, name = 'elf2021'},
    {id = 12706, name = 'grinch'},
    {id = 12707, name = 'littlebill'},
    {id = 12708, name = 'santa'},
    {id = 12709, name = 'yearroliki1'},
    {id = 12710, name = 'yearroliki2'},
    {id = 12711, name = 'yearroliki3'},
    {id = 12712, name = 'yearroliki4'},
    {id = 12778, name = 'yoda1'},
    {id = 12779, name = 'warh1'},
    {id = 12780, name = 'stray'},
    {id = 12781, name = 'spcfarm'},
    {id = 12782, name = 'grut'},
    {id = 12784, name = 'doom'},
    {id = 12785, name = 'cosmom'},
    {id = 12786, name = 'chik'},
    {id = 12787, name = 'bomjr'},
    {id = 12788, name = 'bomjb'},
    {id = 13945, name = 'footbal'},
    {id = 13946, name = 'minefarmer'},
    {id = 13947, name = 'villager'},
    {id = 13956, name = 'minechiken'},
    {id = 13979, name = 'tramp1'},
    {id = 13980, name = 'tramp2'},
    {id = 14003, name = 'minechiken_big'},
    {id = 14006, name = 'fox1'},
    {id = 14008, name = 'judy1'},
    {id = 14009, name = 'dora2'},
    {id = 14043, name = 'bob1'},
    {id = 14048, name = 'rollerm'},
    {id = 14049, name = 'rollerw'},
    {id = 14050, name = 'prcatg'},
    {id = 14051, name = 'pkiberg'},
    {id = 14052, name = 'pscm'},
    {id = 14053, name = 'ppanam'},
    {id = 14054, name = 'ppunk'},
    {id = 14055, name = 'pbiker'},
    {id = 14056, name = 'photdog'},
    {id = 14057, name = 'pcat'},
    {id = 14082, name = 'ksam'},
    {id = 14083, name = 'panm'},
    {id = 14084, name = 'rbcat'},
    {id = 14085, name = 'robo_chicken'},
    {id = 14088, name = 'moroz'},
    {id = 14089, name = 'moroz2'},
    {id = 14114, name = 'chicken2'},
    {id = 14146, name = 'quincy'},
    {id = 14147, name = 'seagers'},
    {id = 14148, name = 'eb'},
    {id = 14169, name = 'artur'},
    {id = 14192, name = 'bbt'},
    {id = 14266, name = 'a4'},
    {id = 14267, name = 'acad'},
    {id = 14268, name = 'beast'},
    {id = 14269, name = 'brian'},
    {id = 14270, name = 'dvid'},
    {id = 14271, name = 'fil'},
    {id = 14272, name = 'ghoul'},
    {id = 14273, name = 'homeland'},
    {id = 14274, name = 'kosmos'},
    {id = 14275, name = 'malfoy'},
    {id = 14276, name = 'marshm'},
    {id = 14277, name = 'meow'},
    {id = 14278, name = 'pchela'},
    {id = 14279, name = 'roger'},
    {id = 14280, name = 'lucif'},
    {id = 14337, name = 'belik'},
    {id = 14339, name = 'hran'},
    {id = 14341, name = 'bratok'},
    {id = 14342, name = 'conor'},
    {id = 14343, name = 'daeneris'},
    {id = 14344, name = 'eilish'},
    {id = 14345, name = 'graims'},
    {id = 14346, name = 'joel'},
    {id = 14347, name = 'kratos'},
    {id = 14348, name = 'levi'},
    {id = 14349, name = 'merser'},
    {id = 14350, name = 'mia'},
    {id = 14351, name = 'reizor'},
    {id = 14352, name = 'silver'},
    {id = 14353, name = 'snoy'},
    {id = 14354, name = 'tris'},
    {id = 14358, name = 'kolabaka'},
    {id = 14925, name = 'canae'},
    {id = 14926, name = 'stark'},
    {id = 14938, name = 'kalkin'},
    {id = 14939, name = 'roblox'},
    {id = 14986, name = 'friren'},
    {id = 14987, name = 'itpedia'},
    {id = 15010, name = 'bestavto'},
    {id = 15011, name = 'bestavtobar'},
    {id = 15012, name = 'bestclad'},
    {id = 15013, name = 'bestcliver'},
    {id = 15014, name = 'bestcr'},
    {id = 15015, name = 'bestshaxt'},
    {id = 15016, name = 'mortaljax'},
    {id = 15017, name = 'mortalliu'},
    {id = 15018, name = 'mortalnoob'},
    {id = 15019, name = 'mortalsony'},
    {id = 15020, name = 'shut'},
    {id = 15021, name = 'mortaltsung'},
    {id = 15022, name = 'mortraiden'},
    {id = 15023, name = 'mortscorpion'},
    {id = 15024, name = 'mortsub'},
    {id = 15065, name = 'new1'},
    {id = 15066, name = 'new2'},
    {id = 15067, name = 'new3'},
    {id = 15068, name = 'new4'},
    {id = 15069, name = 'new5'},
    {id = 15070, name = 'new6'},
    {id = 15071, name = 'new7'},
    {id = 15072, name = 'new8'},
    {id = 15073, name = 'new9'},
    {id = 15074, name = 'new10'},
    {id = 15075, name = 'new11'},
    {id = 15076, name = 'new12'},
    {id = 15077, name = 'new13'},
    {id = 15078, name = 'new14'},
    {id = 15079, name = 'new15'},
    {id = 15080, name = 'new16'},
    {id = 15081, name = 'new17'},
    {id = 15082, name = 'new18'},
    {id = 15083, name = 'new19'},
    {id = 15084, name = 'new20'},
    {id = 15086, name = '03bestcar'},
    {id = 15087, name = '03besthouse'},
    {id = 15088, name = '03bomj'},
    {id = 15089, name = '03bomj1'},
    {id = 15090, name = '03bomj2'},
    {id = 15091, name = '03brayant'},
    {id = 15092, name = '03chiken'},
    {id = 15093, name = '03cristiano'},
    {id = 15094, name = '03messi'},
    {id = 15095, name = '03ovechkin'},
    {id = 15096, name = '03usyk'},
    {id = 15097, name = '03zelenskiy'},
    {id = 15128, name = 'fol1'},
    {id = 15129, name = 'fol2'},
    {id = 15130, name = 'fol3'},
    {id = 15131, name = 'glent2'},
    {id = 15164, name = 'armybomj1'},
    {id = 15165, name = 'armybomj2'},
    {id = 15166, name = 'bsty'},
    {id = 15176, name = 'sahur'},
    {id = 15177, name = 'shpio'},
    {id = 15179, name = 'golem'},
    {id = 15194, name = 'boatkid'},
    {id = 15224, name = 'tron'},
    {id = 15225, name = 'wolf1'},
    {id = 15226, name = 'raragorn'},
    {id = 15227, name = 'gats'},
    {id = 15228, name = 'gimli'},
    {id = 15229, name = 'galadriel'},
    {id = 15230, name = 'frodo'},
    {id = 15231, name = 'gandelf'},
    {id = 15232, name = 'golum'},
    {id = 15265, name = 'f_fantc', isNew = true},
    {id = 15267, name = 'frank_big'},
    {id = 15268, name = 'lich_big'},
    {id = 15269, name = 'zomb1_n1'},
    {id = 15288, name = 'zomb2_n2'},
    {id = 15289, name = 'zomb3_n3'},
    {id = 15290, name = 'ghos'},
    {id = 15292, name = 'f_shelb', isNew = true},
    {id = 15296, name = 'family1'},
    {id = 15297, name = 'family2'},
    {id = 15298, name = 'family3'},
    {id = 15299, name = 'family4'},
    {id = 15300, name = 'family5'},
    {id = 15301, name = 'family6'},
    {id = 15302, name = 'family7'},
    {id = 15303, name = 'family8'},
    {id = 15304, name = 'family9'},
    {id = 15305, name = 'family10'},
    {id = 15306, name = 'family11'},
    {id = 15307, name = 'family12'},
    {id = 15308, name = 'family13'},
    {id = 15309, name = 'family14'},
    {id = 15310, name = 'family15'},
    {id = 15311, name = 'family16'},
    {id = 15312, name = 'family17'},
    {id = 15313, name = 'family18'},
    {id = 15314, name = 'family19'},
    {id = 15315, name = 'family20'},
    {id = 15316, name = 'family21'},
    {id = 15317, name = 'family22'},
    {id = 15318, name = 'family23'},
    {id = 15319, name = 'family24'},
    {id = 15320, name = 'family25'},
    {id = 15321, name = 'family26'},
    {id = 15322, name = 'family27'},
    {id = 15323, name = 'family28'},
    {id = 15324, name = 'family29'},
    {id = 15325, name = 'family30'},
    {id = 15400, name = 'arab1'},
    {id = 15401, name = 'arab2'},
    {id = 15402, name = 'bomj1'},
    {id = 15403, name = 'bomj3'},
    {id = 15404, name = 'maneken'},
    {id = 15405, name = 'bukin'},
    {id = 15406, name = 'fenni'},
    {id = 15408, name = 'frankg'},
    {id = 15409, name = 'ghost'},
    {id = 15410, name = 'iza'},
    {id = 15411, name = 'katsu'},
    {id = 15412, name = 'maysonv'},
    {id = 15413, name = 'michael'},
    {id = 15440, name = 'velma'},
    {id = 15441, name = 'pcon'},
    {id = 15448, name = 'hika'},
    {id = 15450, name = 'phil'},
    {id = 15458, name = 'vc_skin1'},
    {id = 15459, name = 'vc_skin2'},
    {id = 15460, name = 'vc_skin3'},
    {id = 15461, name = 'vc_skin4'},
    {id = 15462, name = 'vc_skin5'},
    {id = 15463, name = 'vc_skin6'},
    {id = 15464, name = 'vc_skin7'},
    {id = 15465, name = 'vc_skin8'},
    {id = 15466, name = 'vc_skin9'},
    {id = 15467, name = 'vc_skin10'},
    {id = 15468, name = 'vc_skin11'},
    {id = 15469, name = 'vc_skin12'},
    {id = 15470, name = 'vc_skin13'},
    {id = 15471, name = 'vc_skin14'},
    {id = 15472, name = 'vc_skin15'},
    {id = 15473, name = 'vc_skin16'},
    {id = 15474, name = 'vc_skin17'},
    {id = 15475, name = 'vc_skin18'},
    {id = 15476, name = 'vc_skin19'},
    {id = 15477, name = 'vc_skin20'},
    {id = 15478, name = 'vc_skin21'},
    {id = 15479, name = 'vc_skin22'},
    {id = 15480, name = 'vc_skin23'},
    {id = 15481, name = 'vc_skin24'},
    {id = 15482, name = 'vc_skin25'},
    {id = 15483, name = 'vc_skin26'},
    {id = 15484, name = 'vc_skin27'},
    {id = 15516, name = 'carti'},
    {id = 15521, name = 'zek', isNew = true},
    {id = 15524, name = 'zekw', isNew = true},
    {id = 15530, name = 'ant'},
    {id = 15531, name = 'antxs'},
    {id = 15532, name = 'mary'},
    {id = 15533, name = 'prbos'},
    {id = 15534, name = 'prish'},
    {id = 15535, name = 'raiden'},
    {id = 15536, name = 'sidni'},
    {id = 15537, name = 'spcfarmxs'},
    {id = 15538, name = 'ham2'},
    {id = 15557, name = 'vercetti'},
    {id = 15567, name = 'zomb_big'},
    {id = 15570, name = 'scooby'},
    {id = 15571, name = 'scooby_hallowen'},
    {id = 15573, name = 'werewolf'},
    {id = 15577, name = 'antoha'},
    {id = 15578, name = 'aqua'},
    {id = 15579, name = 'beetlej'},
    {id = 15588, name = 'csgo'},
    {id = 15589, name = 'csparrow'},
    {id = 15593, name = 'denji'},
    {id = 15596, name = 'dpool'},
    {id = 15598, name = 'dvoreck'},
    {id = 15600, name = 'edit'},
    {id = 15601, name = 'fester'},
    {id = 15603, name = 'ghost_bomj'},
    {id = 15604, name = 'ghost_cj'},
    {id = 15606, name = 'ghost_ponchik'},
    {id = 15611, name = 'ghost_stantz'},
    {id = 15612, name = 'hyde'},
    {id = 15613, name = 'jewish'},
    {id = 15614, name = 'kolyan'},
    {id = 15615, name = 'krug'},
    {id = 15616, name = 'kult'},
    {id = 15617, name = 'larisa'},
    {id = 15624, name = 'arab3'},
    {id = 15625, name = 'lego'},
    {id = 15633, name = 'polyok2'},
    {id = 15638, name = 'm_shelb', isNew = true},
    {id = 15644, name = 'leps'},
    {id = 15645, name = 'kirkov'},
    {id = 15696, name = 'bomj001'},
    {id = 15697, name = 'bomj002'},
    {id = 15698, name = 'bomj003'},
    {id = 15699, name = 'bomj004'},
    {id = 15700, name = 'bomjclassic1'},
    {id = 15701, name = 'bomjclassic2'},
    {id = 15702, name = 'bomjclassic3'},
    {id = 15703, name = 'bomjclassic4'},
    {id = 15704, name = 'bomjclassic5'},
    {id = 15705, name = 'bomjg001'},
    {id = 15706, name = 'bomjg002'},
    {id = 15707, name = 'leshen'},
    {id = 15709, name = 'makima'},
    {id = 15712, name = 'nsparrow'},
    {id = 15714, name = 'durov'},
    {id = 15715, name = 'hitok'},
    {id = 15716, name = 'judge'},
    {id = 15717, name = 'power'},
    {id = 15718, name = 'sndk'},
    {id = 15719, name = 'sherf'},
    {id = 15726, name = 'slender2'},
    {id = 15727, name = 'bigbomj1'},
    {id = 15728, name = 'bigbomj2'},
    {id = 15729, name = 'bigbomj3'},
    {id = 15732, name = 'swensd'},
    {id = 15774, name = 'sfpd1'},
    {id = 15775, name = 'verka'},
    {id = 15789, name = 'bojack'},
    {id = 15790, name = 'viking'},
    {id = 15803, name = 'bomjy'},
    {id = 15804, name = 'spacehik'},
    {id = 15823, name = 'antxl'},
    {id = 15825, name = 'spedf'},
    {id = 15826, name = 'spedm'},
    {id = 15827, name = 'man_wolf'},
    {id = 15828, name = 'bladev'},
    {id = 15867, name = 'vovan'},
    {id = 15868, name = 'wolvr'},
    {id = 15884, name = 'zombie_man3'},
    {id = 15890, name = 'blog1'},
    {id = 15891, name = 'blog2'},
    {id = 15892, name = 'blog3'},
    {id = 15893, name = 'blog4'},
    {id = 15894, name = 'blog5'},
    {id = 15895, name = 'pcon2'},
    {id = 15896, name = 'blog7'},
    {id = 15899, name = 'tidex1'},
    {id = 15900, name = 'tidex2'},
    {id = 15901, name = 'tidex3'},
    {id = 15945, name = 'bomjg1'},
    {id = 15947, name = 'bomjg2'},
    {id = 15948, name = 'bomjm'},
    {id = 15949, name = 'bomz3'},
    {id = 15958, name = 'reedus'},
    {id = 15966, name = 'hnina'},
    {id = 15967, name = 'hzombie1'},
    {id = 15968, name = 'hzombie2'},
    {id = 15969, name = 'hzombie3'},
    {id = 15970, name = 'hzombie4'},
    {id = 15971, name = 'hzombie5'},
    {id = 15972, name = 'hzombie6'},
    {id = 15973, name = 'hzombie7'},
    {id = 15974, name = 'hzombie8'},
    {id = 15975, name = 'hzombie9'},
    {id = 15976, name = 'ork'},
    {id = 15977, name = 'szombie1'},
    {id = 15978, name = 'szombie2'},
    {id = 15979, name = 'szombie3'},
    {id = 15980, name = 'szombie5'},
    {id = 15981, name = 'szombie4'},
    {id = 15982, name = 'szombie6'},
    {id = 15983, name = 'szombie7'},
    {id = 15984, name = 'szombie8'},
    {id = 15985, name = 'bigfoot_man'},
    {id = 15986, name = 'clown_man'},
    {id = 15987, name = 'fredi_street'},
    {id = 15988, name = 'jayson_friday13'},
    {id = 15989, name = 'mymia_man'},
    {id = 15990, name = 'zombie_girl1'},
    {id = 15991, name = 'zombie_man1'},
    {id = 15992, name = 'zombie_man2'},
    {id = 15994, name = 'zombie_man4'},
    {id = 16810, name = 'bomz4'},
    {id = 16815, name = 'gimpy_diffuse'},
    {id = 16816, name = 'leatherface'},
    {id = 16817, name = 'nlo'},
    {id = 16818, name = 'piggsy'},
    {id = 16819, name = 'yasher'},
    {id = 16820, name = 'zombieevil'},
    {id = 16830, name = 'snowman3'},
    {id = 16831, name = 'cyberpunk_lucy'},
    {id = 16832, name = 'cyberpunk_rebecca'},
    {id = 16833, name = 'cyberpunk_david'},
    {id = 16834, name = 'dora'},
    {id = 16835, name = 'maybe_baby'},
    {id = 16836, name = 'witch'},
    {id = 16837, name = 'addams'},
    {id = 16838, name = 'harly_queen'},
    {id = 16839, name = 'scream'},
    {id = 16840, name = 'alice_madness'},
    {id = 16841, name = 'geralt_witcher'},
    {id = 16843, name = 'trevor'},
    {id = 16844, name = 'dark_elf'},
    {id = 16845, name = 'leshiy_new'},
    {id = 16846, name = 'light_elf'},
    {id = 16847, name = 'chiken'},
    {id = 16848, name = 'snowman1'},
    {id = 16849, name = 'snowman2'},
    {id = 16850, name = 'ciri_witcher'},
    {id = 16851, name = 'albert_mironov'},
    {id = 16852, name = 'valentin'},
    {id = 16853, name = 'dsher'},
    {id = 16854, name = 'usatiycop'},
    {id = 16880, name = 'stasbr', isNew = true},
    {id = 16888, name = 'm_ybanz', isNew = true},
    {id = 16891, name = 'mayson'},
    {id = 16901, name = 'jinx'},
    {id = 16902, name = 'ortega'},
    {id = 16905, name = 'svat'},
    {id = 16927, name = 'maska2', isNew = true},
    {id = 16929, name = 'maska', isNew = true},
    {id = 16931, name = 'iluminat2', isNew = true},
    {id = 16939, name = 'ilum3', isNew = true},
    {id = 16943, name = 'ilum1m', isNew = true},
    {id = 16960, name = 'admingirl1'},
    {id = 16961, name = 'admingirl2'},
    {id = 16962, name = 'adminman1'},
    {id = 16963, name = 'adminman3'},
    {id = 16965, name = 'adminman4'},
    {id = 16966, name = 'adminman5'},
    {id = 16967, name = 'adminman6'},
    {id = 16968, name = 'adminman7'},
    {id = 16997, name = 'security1'},
    {id = 16998, name = 'security2'},
    {id = 16999, name = 'security3'},
    {id = 17475, name = 'security4'},
    {id = 17476, name = 'willi'},
    {id = 17477, name = 'tan'},
    {id = 17478, name = 'snape'},
    {id = 17479, name = 'ron'},
    {id = 17480, name = 'luci'},
    {id = 17481, name = 'hermiona'},
    {id = 17482, name = 'harry'},
    {id = 17483, name = 'hagrid'},
    {id = 17484, name = 'draco'},
    {id = 18107, name = 'lod_checker', isNew = true},
    {id = 18131, name = 'aragon'},
    {id = 18132, name = 'cbale'},
    {id = 18133, name = 'gandalf'},
    {id = 18134, name = 'gordon'},
    {id = 18135, name = 'hansel'},
    {id = 18136, name = 'johny'},
    {id = 18137, name = 'kupidon'},
    {id = 18138, name = 'legolas'},
    {id = 18139, name = 'rblue'},
    {id = 18140, name = 'rred'},
    {id = 18141, name = 'rwhite'},
    {id = 18142, name = 'stalin'},
    {id = 18143, name = 'stiller'},
    {id = 18144, name = 'tylerd'},
    {id = 18145, name = 'beliy'},
    {id = 18146, name = 'bodrov'},
    {id = 18147, name = 'letov'},
    {id = 18148, name = 'mavrodi'},
    {id = 18149, name = 'bomj2'},
    {id = 18150, name = 'drockw'},
    {id = 18151, name = 'tsoy'},
    {id = 18162, name = 'mehanika69'},
    {id = 18163, name = 'kenobi'},
    {id = 18168, name = 'vader'},
}
for i = 1, #skins do
    local s = skins[i]
    s.idStr     = tostring(s.id)
    s.lowerName = s.name:lower()
    s.uiFav     = '##fav' .. i
    s.uiSkin    = '##sk'  .. i
end
local favorites = {}
local favCount  = 0
local function loadFavorites()
    favorites = {}
    favCount  = 0
    for part in tostring(ini.main.favorites or ''):gmatch('[^,]+') do
        local n = tonumber(part)
        if n and not favorites[n] then
            favorites[n] = true
            favCount = favCount + 1
        end
    end
end
local cacheSearch, cacheTab
local activeTab = 1
local function saveFavorites()
    local t = {}
    for k in pairs(favorites) do t[#t+1] = k end
    table.sort(t)
    ini.main.favorites = table.concat(t, ',')
    inicfg.save(ini, CFG_FILE)
    if activeTab == 2 then cacheTab = nil end
end
local function migrateConfig()
    local ver = tonumber(ini.main.ver) or 0
    if ver >= CFG_VERSION then return end
    if ver < 2 then
        local legacy = {}
        for i = 1, #skins do
            if not skins[i].isNew then legacy[#legacy+1] = skins[i].id end
        end
        local oldSkin = tonumber(ini.main.skin) or 0
        ini.main.skin = (oldSkin > 0 and legacy[oldSkin]) and legacy[oldSkin] or SKIN_OFF
        local conv = {}
        for part in tostring(ini.main.favorites or ''):gmatch('[^,]+') do
            local n = tonumber(part)
            if n and legacy[n] then conv[#conv+1] = legacy[n] end
        end
        table.sort(conv)
        ini.main.favorites = table.concat(conv, ',')
    end
    if ver < 3 then
        ini.main.winW = -1
        ini.main.winH = -1
    end
    ini.main.ver = CFG_VERSION
    inicfg.save(ini, CFG_FILE)
end
migrateConfig()
loadFavorites()
local newCount = 0
for i = 1, #skins do if skins[i].isNew then newCount = newCount + 1 end end
local subscribed  = ini.main.subscribed == true or ini.main.subscribed == 'true'
local subWindow   = new.bool(false)
local subVisited  = {tt = false, yt = false, tg = false}
local window      = new.bool(false)
local isEmulating = false
local originalSkin = 0
local selected = { id = tonumber(ini.main.skin) or SKIN_OFF }
local searchBuf = new.char[256]('')
local function ic(name, fb)
    local v = fa[name]
    if v and v ~= '' then return v end
    return fb or ''
end
local ICON = {}
local CLR = {
    accent  = imgui.ImVec4(1.000, 0.302, 0.302, 1.00),
    accentD = imgui.ImVec4(0.545, 0.176, 0.176, 1.00),
    text    = imgui.ImVec4(0.950, 0.960, 0.980, 1.00),
    textDim = imgui.ImVec4(0.620, 0.650, 0.720, 1.00),
    border  = imgui.ImVec4(1.000, 1.000, 1.000, 0.09),
    orange  = imgui.ImVec4(0.980, 0.600, 0.050, 1.00),
    green   = imgui.ImVec4(0.000, 0.780, 0.390, 1.00),
    blue    = imgui.ImVec4(0.235, 0.580, 1.000, 1.00),
    dim2    = imgui.ImVec4(0.620, 0.650, 0.720, 0.35),
}
local GRAD = {
    {0.00, 1.000, 0.430, 0.160},
    {0.18, 0.940, 0.180, 0.315},
    {0.38, 0.845, 0.160, 0.590},
    {0.58, 0.550, 0.275, 0.865},
    {0.78, 0.175, 0.470, 0.920},
    {1.00, 0.510, 0.865, 1.000},
}
local function u32c(v, a)
    return imgui.ColorConvertFloat4ToU32(imgui.ImVec4(v.x, v.y, v.z, a ~= nil and a or v.w))
end
local function u32(r, g, b, a)
    return imgui.ColorConvertFloat4ToU32(imgui.ImVec4(r, g, b, a or 1))
end
local function gradU32(t)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local i = 1
    while i < #GRAD - 1 and t > GRAD[i+1][1] do i = i + 1 end
    local a, b = GRAD[i], GRAD[i+1]
    local k = (t - a[1]) / (b[1] - a[1])
    return u32(a[2] + (b[2]-a[2])*k, a[3] + (b[3]-a[3])*k, a[4] + (b[4]-a[4])*k)
end
local U = nil
local function ensureColors()
    if U then return end
    U = {
        accent   = u32c(CLR.accent),
        text     = u32c(CLR.text),
        textDim  = u32c(CLR.textDim),
        border   = u32c(CLR.border),
        orange   = u32c(CLR.orange),
        green    = u32c(CLR.green),
        white    = u32(1, 1, 1, 1),
        white0   = u32(1, 1, 1, 0),
        white35  = u32(1, 1, 1, 0.35),
        panel    = u32(1, 1, 1, 0.05),
        panelBg  = u32(0.075, 0.080, 0.095, 1.00),
        pill     = u32(1, 1, 1, 0.08),
        pillSel  = u32c(CLR.accent, 0.85),
        rowSel   = u32c(CLR.accentD, 0.55),
        rowSel0  = u32c(CLR.accentD, 0.00),
        rowHov   = u32c(CLR.accent, 0.09),
        favOff   = u32(0.62, 0.65, 0.72, 0.32),
        favHov   = u32(0.62, 0.65, 0.72, 0.85),
        bgTop    = u32(0.075, 0.082, 0.100, 0.985),
        bgBot    = u32(0.040, 0.043, 0.055, 0.985),
        headerBg = u32(0.100, 0.110, 0.140, 0.60),
        newBg    = u32c(CLR.accent, 0.16),
    }
end
local _va, _vb, _vc = imgui.ImVec2(0, 0), imgui.ImVec2(0, 0), imgui.ImVec2(0, 0)
local function VA(x, y) _va.x = x _va.y = y return _va end
local function VB(x, y) _vb.x = x _vb.y = y return _vb end
local function VC(x, y) _vc.x = x _vc.y = y return _vc end
local function applyTheme()
    local C  = imgui.GetStyle().Colors
    local cl = imgui.Col
    local V4 = imgui.ImVec4
    C[cl.Text]                 = CLR.text
    C[cl.ChildBg]              = V4(0.065, 0.070, 0.085, 1.00)
    C[cl.ScrollbarBg]          = V4(0.05, 0.05, 0.06, 0.00)
    C[cl.ScrollbarGrab]        = V4(0.24, 0.25, 0.30, 1.00)
    C[cl.ScrollbarGrabHovered] = V4(0.34, 0.35, 0.42, 1.00)
    C[cl.ScrollbarGrabActive]  = CLR.accent
    C[cl.ResizeGrip]           = V4(1.00, 0.30, 0.30, 0.18)
    C[cl.ResizeGripHovered]    = V4(1.00, 0.30, 0.30, 0.45)
    C[cl.ResizeGripActive]     = V4(1.00, 0.30, 0.30, 0.75)
    C[cl.TextSelectedBg]       = V4(1.00, 0.30, 0.30, 0.25)
    local st = imgui.GetStyle()
    st.WindowRounding    = 14 * MDS
    st.ChildRounding     = 10 * MDS
    st.ScrollbarRounding = 6  * MDS
    st.ScrollbarSize     = 18 * MDS
    st.GrabMinSize       = 22 * MDS
    st.WindowBorderSize  = 0
    st.FrameBorderSize   = 0
    st.ChildBorderSize   = 0
    st.FramePadding      = imgui.ImVec2(10 * MDS, 6 * MDS)
end
local fMain, fTitle, fIcon
imgui.OnInitialize(function()
    imgui.SwitchContext()
    local io = imgui.GetIO()
    io.IniFilename = nil
    imgui.GetStyle():ScaleAllSizes(MDS)
    local ttf = getWorkingDirectory() .. '/lib/mimgui/trebucbd.ttf'
    if not doesFileExist(ttf) then
        ttf = getWorkingDirectory() .. '/../trebucbd.ttf'
    end
    local ranges = io.Fonts:GetGlyphRangesCyrillic()
    if doesFileExist(ttf) then
        fMain  = io.Fonts:AddFontFromFileTTF(ttf, 14 * MDS, nil, ranges)
        fTitle = io.Fonts:AddFontFromFileTTF(ttf, 19 * MDS, nil, ranges)
        local cfg2 = imgui.ImFontConfig()
        cfg2.MergeMode  = false
        cfg2.PixelSnapH = true
        local faRange = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
        fIcon = io.Fonts:AddFontFromMemoryCompressedBase85TTF(
            faicons.get_font_data_base85('solid'), 14 * MDS, cfg2, faRange)
    end
    ICON.close   = fa.XMARK
    ICON.search  = fa.MAGNIFYING_GLASS
    ICON.clear   = ic('CIRCLE_XMARK', fa.XMARK)
    ICON.list    = fa.LIST
    ICON.star    = fa.STAR
    ICON.bolt    = ic('BOLT', fa.STAR)
    ICON.first   = ic('ANGLES_LEFT',  '<<')
    ICON.prev    = ic('ANGLE_LEFT',   '<')
    ICON.next    = ic('ANGLE_RIGHT',  '>')
    ICON.last    = ic('ANGLES_RIGHT', '>>')
    ICON.dice    = ic('DICE', ic('SHUFFLE', fa.STAR))
    ICON.reset   = ic('ROTATE_LEFT', ic('ARROW_ROTATE_LEFT', fa.XMARK))
    ICON.person  = ic('PERSON', ic('USER', fa.SHIRT))
    ICON.tg      = fa.PAPER_PLANE
    ICON.music   = fa.MUSIC
    ICON.play    = fa.PLAY
    applyTheme()
end)
local winPos  = { x = tonumber(ini.main.winX) or -1, y = tonumber(ini.main.winY) or -1 }
local winSize = { w = tonumber(ini.main.winW) or -1, h = tonumber(ini.main.winH) or -1 }
local winDirty = false
local function saveConfig()
    ini.main.skin = selected.id
    inicfg.save(ini, CFG_FILE)
end
local function saveWinState()
    ini.main.winX = math.floor(winPos.x)
    ini.main.winY = math.floor(winPos.y)
    ini.main.winW = math.floor(winSize.w)
    ini.main.winH = math.floor(winSize.h)
    inicfg.save(ini, CFG_FILE)
end
local function apply(custom_skin)
    local target_skin = custom_skin or (selected.id >= 0 and selected.id or nil)
    local ok, res, myId = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
    if not ok or not res then return end
    if target_skin then
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt32(bs, myId)
        raknetBitStreamWriteInt32(bs, target_skin)
        isEmulating = true
        raknetEmulRpcReceiveBitStream(153, bs)
        isEmulating = false
        raknetDeleteBitStream(bs)
    end
    saveConfig()
end
function sampev.onSetPlayerSkin(playerId, skinId)
    local ok, res, myId = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
    if ok and res and playerId == myId and not isEmulating then
        originalSkin = skinId
    end
end
local sdrag = { active = false, moved = false, wasDown = false, y0 = 0, s0 = 0 }
local cachedList  = {}
local currentPage = 1
local resetScroll = false
local function rebuildCache(searchStr, tab)
    cachedList = {}
    local q = searchStr:lower():match('^%s*(.-)%s*$') or ''
    local onlyNew = (q == 'new')
    for i = 1, #skins do
        local s = skins[i]
        local hit
        if onlyNew then
            hit = s.isNew == true
        elseif q == '' then
            hit = true
        else
            hit = s.lowerName:find(q, 1, true) ~= nil or s.idStr:find(q, 1, true) ~= nil
        end
        if hit and (tab == 1
                or (tab == 2 and favorites[s.id])
                or (tab == 3 and s.isNew)) then
            cachedList[#cachedList+1] = i
        end
    end
    cacheSearch = searchStr
    cacheTab    = tab
    currentPage = 1
    resetScroll = true
end
local labelWidth = -1
local function fitLabel(s, maxW)
    if imgui.CalcTextSize(s).x <= maxW then return s end
    local lo, hi = 1, #s
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if imgui.CalcTextSize(s:sub(1, mid)).x <= maxW then lo = mid else hi = mid - 1 end
    end
    return s:sub(1, math.max(1, lo - 2)) .. '..'
end
local function getLabel(s, maxW)
    if maxW ~= labelWidth then
        for i = 1, #skins do skins[i].lbl = nil end
        labelWidth = maxW
    end
    if not s.lbl then s.lbl = fitLabel(s.name, maxW) end
    return s.lbl
end
local txtCache = {}
local function textW(str)
    local w = txtCache[str]
    if not w then
        w = imgui.CalcTextSize(str).x
        txtCache[str] = w
    end
    return w
end
local iconCache = {}
local function iconW(str)
    local w = iconCache[str]
    if not w then
        if fIcon then imgui.PushFont(fIcon) end
        w = imgui.CalcTextSize(str).x
        if fIcon then imgui.PopFont() end
        iconCache[str] = w
    end
    return w
end
local titleCache = {}
local function titleW(str)
    local w = titleCache[str]
    if not w then
        if fTitle then imgui.PushFont(fTitle) end
        w = imgui.CalcTextSize(str).x
        if fTitle then imgui.PopFont() end
        titleCache[str] = w
    end
    return w
end
local txtHeight
local function textH()
    if not txtHeight then txtHeight = imgui.CalcTextSize('Ag').y end
    return txtHeight
end
local anim = {
    now = 0, dt = 0, last = 0,
    tabX = -1, tabW = 0,
    hoverId = nil, hoverK = 0,
    favPop = {},
    pulse = 0, shine = 0,
}
local function tickAnim()
    local now = getGameTimer()
    if anim.last == 0 then anim.last = now end
    anim.dt   = math.min(0.1, (now - anim.last) / 1000)
    anim.last = now
    anim.now  = now
    anim.pulse = 0.5 + 0.5 * math.sin(now / 420)
    anim.shine = (now % 3200) / 3200
end
local function lerp(a, b, k) return a + (b - a) * k end
local HEAD_H  = 46 * MDS
local CFLAGS  = imgui.DrawCornerFlags or {}
local CF_ALL  = CFLAGS.All or 15
local CF_TOP  = CFLAGS.Top or ((CFLAGS.TopLeft or 1) + (CFLAGS.TopRight or 2))
local CF_BOT  = CFLAGS.Bot or ((CFLAGS.BotLeft or 4) + (CFLAGS.BotRight or 8))
local function drawShell(DL, WP, W, H)
    local r = 14 * MDS
    DL:AddRectFilled(VA(WP.x, WP.y), VB(WP.x + W, WP.y + H), U.bgTop, r, CF_ALL)
    DL:AddRectFilledMultiColor(VA(WP.x, WP.y + r), VB(WP.x + W, WP.y + H - r),
        U.bgTop, U.bgTop, U.bgBot, U.bgBot)
    DL:AddRectFilled(VA(WP.x, WP.y + H - r*2), VB(WP.x + W, WP.y + H), U.bgBot, r, CF_BOT)
    DL:AddRectFilled(VA(WP.x, WP.y), VB(WP.x + W, WP.y + HEAD_H), U.headerBg, r, CF_TOP)
    local barY  = WP.y + 3 * MDS
    local barH  = 3 * MDS
    local barX0 = WP.x + 18 * MDS
    local barX1 = WP.x + W - 18 * MDS
    local barW  = barX1 - barX0
    for k = 0, 11 do
        DL:AddRectFilled(VA(barX0 + barW * (k / 12), barY),
                         VB(barX0 + barW * ((k + 1) / 12) + 1, barY + barH),
                         gradU32(k / 11))
    end
    local sw = barW * 0.28
    local sx = barX0 - sw + (barW + sw) * anim.shine
    if sx + sw > barX0 and sx < barX1 then
        local a = math.max(barX0, sx)
        local b = math.min(barX1, sx + sw * 0.5)
        if b > a then
            DL:AddRectFilledMultiColor(VA(a, barY), VB(b, barY + barH),
                U.white0, U.white35, U.white35, U.white0)
        end
        a = math.max(barX0, sx + sw * 0.5)
        b = math.min(barX1, sx + sw)
        if b > a then
            DL:AddRectFilledMultiColor(VA(a, barY), VB(b, barY + barH),
                U.white35, U.white0, U.white0, U.white35)
        end
    end
    DL:AddRect(VA(WP.x, WP.y), VB(WP.x + W, WP.y + H), U.border, r, CF_ALL, 1.2)
end
local constraintsOk = true
local TAB_TITLES = {
    u8('\xc2\xf1\xe5'),
    u8('\xc8\xe7\xe1\xf0\xe0\xed\xed\xee\xe5'),
    u8('\xcd\xee\xe2\xfb\xe5'),
}
local EMPTY_MSG = {
    u8('\xcd\xe8\xf7\xe5\xe3\xee \xed\xe5 \xed\xe0\xe9\xe4\xe5\xed\xee'),
    u8('\xed\xe5\xf2 \xe8\xe7\xe1\xf0\xe0\xed\xed\xee\xe3\xee'),
    u8('\xed\xe5\xf2 \xed\xee\xe2\xfb\xf5'),
}
local function clearSearch()
    searchBuf[0] = 0
end
local function iconButton(id, x, y, w, h, icon, col)
    imgui.SetCursorPos(imgui.ImVec2(x, y))
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.Text, col)
    if fIcon then imgui.PushFont(fIcon) end
    local pressed = imgui.Button(icon .. id, imgui.ImVec2(w, h))
    if fIcon then imgui.PopFont() end
    imgui.PopStyleColor(4)
    return pressed
end
local function ghostButton(id, x, y, w, h)
    imgui.SetCursorPos(imgui.ImVec2(x, y))
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0, 0, 0, 0))
    local pressed = imgui.Button(id, imgui.ImVec2(w, h))
    imgui.PopStyleColor(3)
    return pressed
end
imgui.OnFrame(function() return window[0] end, function(self)
    self.HideCursor = false
    ensureColors()
    tickAnim()
    local resX, resY = getScreenResolution()
    local defW, defH = 520 * MDS, 500 * MDS
    local iW = (winSize.w > 200) and winSize.w or defW
    local iH = (winSize.h > 200) and winSize.h or defH
    local initX = (winPos.x >= 0) and winPos.x or (resX / 2 - iW / 2)
    local initY = (winPos.y >= 0) and winPos.y or (resY / 2 - iH / 2)
    imgui.SetNextWindowPos(imgui.ImVec2(initX, initY), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(imgui.ImVec2(iW, iH), imgui.Cond.FirstUseEver)
    if constraintsOk then
        constraintsOk = pcall(imgui.SetNextWindowSizeConstraints,
            imgui.ImVec2(430 * MDS, 390 * MDS), imgui.ImVec2(resX, resY))
    end
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))
    imgui.Begin('SkinChanger##main', window,
        imgui.WindowFlags.NoTitleBar +
        imgui.WindowFlags.NoScrollbar +
        imgui.WindowFlags.NoScrollWithMouse)
    imgui.PopStyleColor()
    local DL = imgui.GetWindowDrawList()
    local WP = imgui.GetWindowPos()
    local ws = imgui.GetWindowSize()
    local W, H = ws.x, ws.y
    local pad  = 14 * MDS
    local mp   = imgui.GetMousePos()
    local mx, my = mp.x, mp.y
    if math.abs(WP.x - winPos.x) > 0.5 or math.abs(WP.y - winPos.y) > 0.5
    or math.abs(W - winSize.w) > 0.5 or math.abs(H - winSize.h) > 0.5 then
        winPos.x, winPos.y  = WP.x, WP.y
        winSize.w, winSize.h = W, H
        winDirty = true
    end
    if winDirty and not imgui.IsMouseDown(0) then
        winDirty = false
        saveWinState()
    end
    drawShell(DL, WP, W, H)
    if fMain then imgui.PushFont(fMain) end
    local txtH = textH()
    local hcY = WP.y + HEAD_H / 2
    if fIcon then
        DL:AddTextFontPtr(fIcon, 20*MDS, VC(WP.x + pad, hcY - 10*MDS),
            u32c(CLR.blue, 0.85 + 0.15*anim.pulse), ICON.person)
    end
    local tx = WP.x + pad + 28*MDS
    if fTitle then
        DL:AddTextFontPtr(fTitle, 19*MDS, VC(tx, hcY - 10*MDS), U.text, 'Skin Changer')
    else
        DL:AddText(VC(tx, hcY - txtH/2), U.text, 'Skin Changer')
    end
    local isOn = selected.id >= 0
    local sub  = isOn and (u8('\xb7  \xe2\xfb\xe1\xf0\xe0\xed #') .. selected.id)
                      or  u8('\xb7  \xf1\xea\xe8\xed \xee\xf2\xea\xeb\xfe\xf7\xb8\xed')
    DL:AddText(VC(tx + titleW('Skin Changer') + 10*MDS, hcY - txtH/2),
        isOn and u32c(CLR.accent, 0.9) or U.favOff, sub)
    local btnSz  = 30 * MDS
    local closeX = W - pad - btnSz
    local closeY = HEAD_H/2 - btnSz/2
    local hovClose = mx >= WP.x+closeX and mx <= WP.x+closeX+btnSz
                 and my >= WP.y+closeY and my <= WP.y+closeY+btnSz
    DL:AddRectFilled(VA(WP.x+closeX, WP.y+closeY), VB(WP.x+closeX+btnSz, WP.y+closeY+btnSz),
        hovClose and u32c(CLR.accent, 0.75) or U.panel, 9*MDS, CF_ALL)
    if iconButton('##close', closeX, closeY, btnSz, btnSz, ICON.close,
        hovClose and CLR.text or CLR.textDim) then
        window[0] = false
    end
    local searchStr = ffi.string(searchBuf)
    local searchY = HEAD_H + 8 * MDS
    local searchH = 34 * MDS
    local clearW  = (searchStr ~= '') and (34 * MDS) or 0
    local panelW  = W - pad*2 - (clearW > 0 and (clearW + 6*MDS) or 0)
    DL:AddRectFilled(VA(WP.x+pad, WP.y+searchY), VB(WP.x+pad+panelW, WP.y+searchY+searchH),
        U.panelBg, 10*MDS, CF_ALL)
    if fIcon then
        DL:AddTextFontPtr(fIcon, 14*MDS,
            VC(WP.x+pad+12*MDS, WP.y+searchY+searchH/2-7*MDS),
            clearW > 0 and U.accent or U.textDim, ICON.search)
    end
    imgui.SetCursorPos(imgui.ImVec2(pad + 34*MDS, searchY + (searchH - 26*MDS)/2))
    imgui.PushStyleColor(imgui.Col.FrameBg,        imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.FrameBgHovered, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.FrameBgActive,  imgui.ImVec4(0, 0, 0, 0))
    imgui.PushItemWidth(panelW - 44*MDS)
    imgui.InputText('##search', searchBuf, 256)
    local searchActive = imgui.IsItemActive()
    imgui.PopItemWidth()
    imgui.PopStyleColor(3)
    if clearW == 0 and not searchActive then
        DL:AddText(VC(WP.x+pad+44*MDS, WP.y+searchY+searchH/2-txtH/2), U.favOff,
            u8('\xef\xee\xe8\xf1\xea: id, \xe8\xec\xff \xe8\xeb\xe8 new'))
    end
    if searchActive then
        DL:AddRect(VA(WP.x+pad, WP.y+searchY), VB(WP.x+pad+panelW, WP.y+searchY+searchH),
            u32c(CLR.accent, 0.55), 10*MDS, CF_ALL, 1.4)
    end
    if clearW > 0 then
        local cx = W - pad - clearW
        local hovC = mx >= WP.x+cx and mx <= WP.x+cx+clearW
                 and my >= WP.y+searchY and my <= WP.y+searchY+searchH
        DL:AddRectFilled(VA(WP.x+cx, WP.y+searchY), VB(WP.x+cx+clearW, WP.y+searchY+searchH),
            hovC and u32c(CLR.accent, 0.35) or U.panelBg, 10*MDS, CF_ALL)
        if iconButton('##clearsearch', cx, searchY, clearW, searchH, ICON.clear,
            hovC and CLR.text or CLR.textDim) then
            clearSearch()
        end
    end
    local tabsY = searchY + searchH + 8 * MDS
    local tabH  = 34 * MDS
    local tabGap = 6 * MDS
    local tabW  = (W - pad*2 - tabGap*2) / 3
    local tabIcons  = {ICON.list, ICON.star, ICON.bolt}
    local tabCounts = {#skins, favCount, newCount}
    DL:AddRectFilled(VA(WP.x+pad, WP.y+tabsY), VB(WP.x+W-pad, WP.y+tabsY+tabH),
        U.panelBg, 10*MDS, CF_ALL)
    if anim.tabX < 0 then
        anim.tabX = pad + (activeTab-1)*(tabW+tabGap)
        anim.tabW = tabW
    end
    local targetX = pad + (activeTab-1)*(tabW+tabGap)
    local k = math.min(1, anim.dt * 16)
    anim.tabX = lerp(anim.tabX, targetX, k)
    anim.tabW = lerp(anim.tabW, tabW, k)
    DL:AddRectFilled(VA(WP.x+anim.tabX, WP.y+tabsY+3*MDS),
                     VB(WP.x+anim.tabX+anim.tabW, WP.y+tabsY+tabH-3*MDS),
                     u32c(CLR.accent, 0.20), 8*MDS, CF_ALL)
    DL:AddRectFilled(VA(WP.x+anim.tabX+anim.tabW*0.18, WP.y+tabsY+tabH-4*MDS),
                     VB(WP.x+anim.tabX+anim.tabW*0.82, WP.y+tabsY+tabH-2*MDS),
                     U.accent, 2*MDS, CF_ALL)
    for ti = 1, 3 do
        local bx    = pad + (ti-1)*(tabW+tabGap)
        local isAct = activeTab == ti
        local hov   = mx>=WP.x+bx and mx<=WP.x+bx+tabW and my>=WP.y+tabsY and my<=WP.y+tabsY+tabH
        local label = TAB_TITLES[ti]
        local cnt   = '(' .. tabCounts[ti] .. ')'
        local lw    = textW(label)
        local cwd   = textW(cnt)
        local iw    = fIcon and (iconW(tabIcons[ti]) + 6*MDS) or 0
        local total = iw + lw + 5*MDS + cwd
        local sx    = WP.x + bx + tabW/2 - total/2
        local col   = isAct and U.accent or (hov and U.text or U.textDim)
        if fIcon then
            local bob = isAct and (math.sin(anim.now / 260) * 1.2 * MDS) or 0
            DL:AddTextFontPtr(fIcon, 14*MDS,
                VC(sx, WP.y + tabsY + tabH/2 - 7*MDS + bob), col, tabIcons[ti])
        end
        DL:AddText(VC(sx + iw, WP.y + tabsY + tabH/2 - txtH/2), col, label)
        DL:AddText(VC(sx + iw + lw + 5*MDS, WP.y + tabsY + tabH/2 - txtH/2),
            isAct and u32c(CLR.accent, 0.6) or U.favOff, cnt)
        if ghostButton('##tab'..ti, bx, tabsY, tabW, tabH) then
            activeTab = ti
        end
    end
    local pagerH  = 30 * MDS
    local footerH = 32 * MDS
    local listTop = tabsY + tabH + 9 * MDS
    local listH   = H - listTop - 8*MDS - pagerH - 6*MDS - footerH - 10*MDS
    if listH < 70 * MDS then listH = 70 * MDS end
    local listW   = W - pad*2
    if searchStr ~= cacheSearch or activeTab ~= cacheTab then
        rebuildCache(searchStr, activeTab)
    end
    local visibleList = cachedList
    local totalItems  = #visibleList
    local pageCount   = math.max(1, math.ceil(totalItems / PAGE_SIZE))
    if currentPage > pageCount then currentPage = pageCount end
    local pageFirst = (currentPage - 1) * PAGE_SIZE
    local pageRows  = math.min(PAGE_SIZE, totalItems - pageFirst)
    if pageRows < 0 then pageRows = 0 end
    imgui.SetCursorPos(imgui.ImVec2(pad, listTop))
    imgui.BeginChild('##skinlist', imgui.ImVec2(listW, listH), false,
        imgui.WindowFlags.NoScrollWithMouse)
    local cdl  = imgui.GetWindowDrawList()
    local cp0  = imgui.GetWindowPos()
    local cw   = imgui.GetWindowWidth()
    local sbSz = imgui.GetStyle().ScrollbarSize
    local sc   = imgui.GetScrollY()
    if resetScroll then
        if imgui.SetScrollY then imgui.SetScrollY(0) end
        resetScroll  = false
        sc           = 0
        sdrag.active = false
    end
    local rowH      = math.floor(txtH + 14 * MDS)
    local contentH  = math.max(pageRows * rowH, listH)
    local maxScroll = math.max(0, contentH - listH)
    local trackX    = cp0.x + cw - sbSz
    local inList = mx >= cp0.x and mx < trackX and my >= cp0.y and my <= cp0.y + listH
    local mdown  = imgui.IsMouseDown(0)
    if mdown and not sdrag.wasDown then
        sdrag.moved  = false
        sdrag.active = inList
        sdrag.y0     = my
        sdrag.s0     = sc
    elseif not mdown then
        sdrag.active = false
    end
    sdrag.wasDown = mdown
    if sdrag.active and maxScroll > 0 then
        local d = my - sdrag.y0
        if sdrag.moved or (d > 4*MDS or d < -4*MDS) then
            sdrag.moved = true
            local ns = sdrag.s0 - d
            if ns < 0 then ns = 0 elseif ns > maxScroll then ns = maxScroll end
            if imgui.SetScrollY and (ns - sc > 0.5 or sc - ns > 0.5) then
                imgui.SetScrollY(ns)
                sc = ns
            end
        end
    end
    cdl:PushClipRect(VA(cp0.x, cp0.y), VB(cp0.x + cw, cp0.y + listH), true)
    local pillW   = 56 * MDS
    local pillX   = cp0.x + 8 * MDS
    local nameX   = pillX + pillW + 10 * MDS
    local rowBtn  = 28 * MDS
    local favX    = cp0.x + cw - sbSz - rowBtn - 2*MDS
    local newW    = textW('NEW')
    local badgeW  = newW + 14 * MDS
    local newSlot = badgeW + 8 * MDS
    local maxTW   = favX - newSlot - nameX - 8 * MDS
    local hovAny  = nil
    local firstVis = math.max(1, math.floor(sc / rowH))
    local lastVis  = math.min(pageRows, math.ceil((sc + listH) / rowH) + 1)
    for vi = firstVis, lastVis do
        local i = visibleList[pageFirst + vi]
        if not i then break end
        local s     = skins[i]
        local ry    = cp0.y + (vi-1)*rowH - sc
        local isSel = selected.id == s.id
        local inFav = favorites[s.id] == true
        local hovRow = mx>=cp0.x and mx<favX and my>=ry and my<ry+rowH
        local hovFav = mx>=favX and mx<=favX+rowBtn and my>=ry and my<ry+rowH
        if hovRow then hovAny = s.id end
        if isSel then
            cdl:AddRectFilledMultiColor(VA(cp0.x, ry+1), VB(cp0.x+cw, ry+rowH-1),
                U.rowSel, U.rowSel0, U.rowSel0, U.rowSel)
        elseif hovRow then
            cdl:AddRectFilled(VA(cp0.x, ry+1), VB(cp0.x+cw, ry+rowH-1), U.rowHov, 6*MDS, CF_ALL)
        end
        if isSel or hovRow then
            local kk = isSel and 1 or (anim.hoverId == s.id and anim.hoverK or 0)
            local bh = rowH * (0.35 + 0.65*kk)
            cdl:AddRectFilled(VA(cp0.x, ry + rowH/2 - bh/2),
                              VB(cp0.x + 3*MDS, ry + rowH/2 + bh/2), U.accent, 2*MDS, CF_ALL)
        end
        cdl:AddRectFilled(VA(pillX, ry+5*MDS), VB(pillX+pillW, ry+rowH-5*MDS),
            isSel and U.pillSel or (s.isNew and U.newBg or U.pill), 6*MDS, CF_ALL)
        local idW = textW(s.idStr)
        cdl:AddText(VC(pillX + pillW/2 - idW/2, ry + rowH/2 - txtH/2),
            isSel and U.white or (s.isNew and U.accent or U.textDim), s.idStr)
        cdl:AddText(VC(nameX, ry + rowH/2 - txtH/2),
            isSel and U.white or U.text, getLabel(s, maxTW))
        if s.isNew then
            local bx = favX - badgeW - 8*MDS
            local a  = 0.14 + 0.16 * anim.pulse
            cdl:AddRectFilled(VA(bx, ry + rowH/2 - 9*MDS), VB(bx + badgeW, ry + rowH/2 + 9*MDS),
                u32c(CLR.accent, a), 9*MDS, CF_ALL)
            cdl:AddText(VC(bx + badgeW/2 - newW/2, ry + rowH/2 - txtH/2),
                u32c(CLR.accent, 0.75 + 0.25*anim.pulse), 'NEW')
        end
        if fIcon then
            local pop = anim.favPop[s.id]
            local ks  = 1
            if pop then
                local t = (anim.now - pop) / 280
                if t >= 1 then anim.favPop[s.id] = nil else ks = 1 + math.sin(t*3.14159)*0.55 end
            end
            local isz = 15 * MDS * ks
            cdl:AddTextFontPtr(fIcon, isz,
                VC(favX + rowBtn/2 - isz/2, ry + rowH/2 - isz/2),
                inFav and U.orange or (hovFav and U.favHov or U.favOff), ICON.star)
        end
        imgui.SetCursorScreenPos(VA(favX, ry))
        if imgui.InvisibleButton(s.uiFav, VB(rowBtn, rowH)) and not sdrag.moved then
            if inFav then
                favorites[s.id] = nil
                favCount = favCount - 1
            else
                favorites[s.id] = true
                favCount = favCount + 1
                anim.favPop[s.id] = anim.now
            end
            saveFavorites()
        end
        imgui.SetCursorScreenPos(VA(cp0.x, ry))
        if imgui.InvisibleButton(s.uiSkin, VB(favX - cp0.x, rowH)) and not sdrag.moved then
            selected.id = s.id
            apply()
        end
    end
    if anim.hoverId ~= hovAny then
        anim.hoverId = hovAny
        anim.hoverK  = 0
    elseif anim.hoverK < 1 then
        anim.hoverK = math.min(1, anim.hoverK + anim.dt * 7)
    end
    imgui.SetCursorPos(imgui.ImVec2(0, 0))
    imgui.InvisibleButton('##listbg', VB(math.max(1, cw - sbSz), contentH))
    if pageRows == 0 then
        local msg = (searchStr ~= '') and EMPTY_MSG[1] or EMPTY_MSG[activeTab]
        cdl:AddText(VC(cp0.x + cw/2 - textW(msg)/2, cp0.y + listH/2 - txtH/2), U.favOff, msg)
    end
    cdl:PopClipRect()
    imgui.EndChild()
    local pagerY = listTop + listH + 8 * MDS
    local pbW    = 36 * MDS
    local function pagerBtn(id, x, icon, enabled)
        local hov = mx>=WP.x+x and mx<=WP.x+x+pbW and my>=WP.y+pagerY and my<=WP.y+pagerY+pagerH
        DL:AddRectFilled(VA(WP.x+x, WP.y+pagerY), VB(WP.x+x+pbW, WP.y+pagerY+pagerH),
            (hov and enabled) and u32c(CLR.accent, 0.30) or U.panelBg, 8*MDS, CF_ALL)
        local col = enabled and CLR.text or CLR.dim2
        return iconButton(id, x, pagerY, pbW, pagerH, icon, col) and enabled
    end
    if pagerBtn('##pfirst', pad, ICON.first, currentPage > 1) then
        currentPage, resetScroll = 1, true
    end
    if pagerBtn('##pprev', pad + pbW + 5*MDS, ICON.prev, currentPage > 1) then
        currentPage, resetScroll = currentPage - 1, true
    end
    if pagerBtn('##pnext', W - pad - pbW*2 - 5*MDS, ICON.next, currentPage < pageCount) then
        currentPage, resetScroll = currentPage + 1, true
    end
    if pagerBtn('##plast', W - pad - pbW, ICON.last, currentPage < pageCount) then
        currentPage, resetScroll = pageCount, true
    end
    local pageStr = u8('\xd1\xf2\xf0. ') .. currentPage .. '/' .. pageCount ..
        u8('  \xb7  ') .. totalItems .. u8(' \xf1\xea\xe8\xed\xee\xe2')
    DL:AddText(VC(WP.x + W/2 - textW(pageStr)/2, WP.y + pagerY + pagerH/2 - txtH/2),
        U.text, pageStr)
    local footY = pagerY + pagerH + 7 * MDS
    local function actionBtn(id, x, w, icon, label, active)
        local hov = mx>=WP.x+x and mx<=WP.x+x+w and my>=WP.y+footY and my<=WP.y+footY+footerH
        DL:AddRectFilled(VA(WP.x+x, WP.y+footY), VB(WP.x+x+w, WP.y+footY+footerH),
            active and u32c(CLR.accent, 0.30) or (hov and u32c(CLR.accent, 0.20) or U.panelBg),
            9*MDS, CF_ALL)
        local col = (hov or active) and U.white or U.textDim
        local lw  = textW(label)
        local iw  = fIcon and (iconW(icon) + 7*MDS) or 0
        local sx  = WP.x + x + w/2 - (lw + iw)/2
        if fIcon then
            DL:AddTextFontPtr(fIcon, 14*MDS, VC(sx, WP.y+footY+footerH/2-7*MDS), col, icon)
        end
        DL:AddText(VC(sx + iw, WP.y + footY + footerH/2 - txtH/2), col, label)
        return ghostButton(id, x, footY, w, footerH)
    end
    local rndW, rstW = 112*MDS, 100*MDS
    if actionBtn('##rnd', pad, rndW, ICON.dice, u8('\xd0\xe0\xed\xe4\xee\xec'), false) then
        if totalItems > 0 then
            local vi  = math.random(1, totalItems)
            local idx = visibleList[vi]
            selected.id = skins[idx].id
            apply()
            currentPage = math.floor((vi - 1) / PAGE_SIZE) + 1
            resetScroll = true
        end
    end
    if actionBtn('##rst', pad + rndW + 6*MDS, rstW, ICON.reset, u8('\xd1\xe1\xf0\xee\xf1'),
        selected.id == SKIN_OFF) then
        selected.id = SKIN_OFF
        if originalSkin ~= 0 then apply(originalSkin) end
        saveConfig()
    end
    local authorStr = 'Victor Strand'
    local aw = textW(authorStr)
    local aiw = fIcon and (iconW(ICON.tg) + 7*MDS) or 0
    local ax = W - pad - aw - aiw
    local hovA = mx>=WP.x+ax and mx<=WP.x+W-pad and my>=WP.y+footY and my<=WP.y+footY+footerH
    if fIcon then
        DL:AddTextFontPtr(fIcon, 14*MDS, VC(WP.x+ax, WP.y+footY+footerH/2-7*MDS),
            hovA and U.accent or U.textDim, ICON.tg)
    end
    DL:AddText(VC(WP.x + ax + aiw, WP.y + footY + footerH/2 - txtH/2),
        hovA and U.accent or U.textDim, authorStr)
    if ghostButton('##tglink', ax, footY, W - pad - ax, footerH) then
        openLink(TG_LINK)
    end
    if fMain then imgui.PopFont() end
    imgui.End()
end)
imgui.OnFrame(function() return subWindow[0] end, function(self)
    self.HideCursor = false
    ensureColors()
    tickAnim()
    local resX, resY = getScreenResolution()
    local W = 440 * MDS
    local H = 300 * MDS
    imgui.SetNextWindowPos(imgui.ImVec2(resX/2 - W/2, resY/2 - H/2), imgui.Cond.Always)
    imgui.SetNextWindowSize(imgui.ImVec2(W, H), imgui.Cond.Always)
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))
    imgui.Begin('##SubWin', nil,
        imgui.WindowFlags.NoTitleBar  +
        imgui.WindowFlags.NoResize    +
        imgui.WindowFlags.NoMove      +
        imgui.WindowFlags.NoScrollbar +
        imgui.WindowFlags.NoScrollWithMouse)
    imgui.PopStyleColor()
    local DL  = imgui.GetWindowDrawList()
    local WP  = imgui.GetWindowPos()
    local pad = 14 * MDS
    local mp  = imgui.GetMousePos()
    local mx, my = mp.x, mp.y
    drawShell(DL, WP, W, H)
    if fMain then imgui.PushFont(fMain) end
    local txtH = textH()
    local hcY = WP.y + HEAD_H / 2
    if fIcon then
        DL:AddTextFontPtr(fIcon, 20*MDS, VC(WP.x + pad, hcY - 10*MDS),
            u32c(CLR.blue, 0.85 + 0.15*anim.pulse), ICON.person)
    end
    local tx = WP.x + pad + 28*MDS
    if fTitle then
        DL:AddTextFontPtr(fTitle, 19*MDS, VC(tx, hcY - 10*MDS), U.text, 'Skin Changer')
    else
        DL:AddText(VC(tx, hcY - txtH/2), U.text, 'Skin Changer')
    end
    local headerH = HEAD_H
    DL:AddText(VC(WP.x + pad, WP.y + headerH + 10*MDS), U.textDim,
        u8('\xc0\xe2\xf2\xee\xf0: Victor Strand'))
    DL:AddText(VC(WP.x + pad, WP.y + headerH + 30*MDS), U.text,
        u8('\xd7\xf2\xee\xe1\xfb \xee\xf2\xea\xf0\xfb\xf2\xfc \xec\xe5\xed\xfe, \xef\xee\xf1\xe5\xf2\xe8 \xe2\xf1\xe5 3 \xea\xe0\xed\xe0\xeb\xe0 \xe0\xe2\xf2\xee\xf0\xe0:'))
    local allVisited = subVisited.tt and subVisited.yt and subVisited.tg
    local btnW = (W - pad*2 - 8*MDS*2) / 3
    local btnH = 40 * MDS
    local btnY = headerH + 56 * MDS
    local socials = {
        { key = 'tt', label = 'TikTok',   icon = ICON.music, link = TT_LINK },
        { key = 'yt', label = 'YouTube',  icon = ICON.play,  link = YT_LINK },
        { key = 'tg', label = 'Telegram', icon = ICON.tg,    link = TG_LINK },
    }
    for i, s in ipairs(socials) do
        local bx  = pad + (i-1)*(btnW + 8*MDS)
        local vis = subVisited[s.key]
        local hov = mx >= WP.x+bx and mx <= WP.x+bx+btnW and my >= WP.y+btnY and my <= WP.y+btnY+btnH
        DL:AddRectFilled(VA(WP.x+bx, WP.y+btnY), VB(WP.x+bx+btnW, WP.y+btnY+btnH),
            vis and u32c(CLR.green, 0.22) or (hov and u32c(CLR.accent, 0.30) or U.panelBg),
            10*MDS, CF_ALL)
        if vis then
            DL:AddRect(VA(WP.x+bx, WP.y+btnY), VB(WP.x+bx+btnW, WP.y+btnY+btnH),
                u32c(CLR.green, 0.55), 10*MDS, CF_ALL, 1.2)
        end
        local col = vis and U.green or ((hov and U.white) or U.text)
        local lw  = textW(s.label)
        local iw  = fIcon and (iconW(s.icon) + 7*MDS) or 0
        local sx  = WP.x + bx + btnW/2 - (lw + iw)/2
        if fIcon then
            DL:AddTextFontPtr(fIcon, 14*MDS, VC(sx, WP.y+btnY+btnH/2-7*MDS), col, s.icon)
        end
        DL:AddText(VC(sx + iw, WP.y + btnY + btnH/2 - txtH/2), col, s.label)
        if ghostButton('##sub'..s.key, bx, btnY, btnW, btnH) then
            subVisited[s.key] = true
            openLink(s.link)
        end
    end
    local confirmY = btnY + btnH + 16*MDS
    if not allVisited then
        DL:AddText(VC(WP.x + pad, WP.y + confirmY), u32c(CLR.accent, 0.85),
            u8('\xd1\xed\xe0\xf7\xe0\xeb\xe0 \xef\xee\xf1\xe5\xf2\xe8 \xe2\xf1\xe5 3 \xea\xe0\xed\xe0\xeb\xe0 \xe2\xfb\xf8\xe5!'))
    end
    local cY  = confirmY + (allVisited and 0 or 22*MDS)
    local cH  = 40 * MDS
    local cW  = W - pad*2
    local hovC = mx >= WP.x+pad and mx <= WP.x+pad+cW and my >= WP.y+cY and my <= WP.y+cY+cH
    DL:AddRectFilled(VA(WP.x+pad, WP.y+cY), VB(WP.x+pad+cW, WP.y+cY+cH),
        allVisited and u32c(CLR.green, hovC and 0.45 or 0.30) or U.panelBg, 10*MDS, CF_ALL)
    local cLabel = u8('\xdf \xef\xee\xe4\xef\xe8\xf1\xe0\xeb\xf1\xff \xe2 \xe2\xf1\xe5 \xea\xe0\xed\xe0\xeb\xfb \xe2\xfb\xf8\xe5 \xe2 \xee\xf2\xea\xf0\xfb\xf2\xfc \xec\xe5\xed\xfe')
    DL:AddText(VC(WP.x + pad + cW/2 - textW(cLabel)/2, WP.y + cY + cH/2 - txtH/2),
        allVisited and U.green or U.favOff, cLabel)
    if ghostButton('##subconfirm', pad, cY, cW, cH) and allVisited then
        subscribed = true
        ini.main.subscribed = 'true'
        inicfg.save(ini, CFG_FILE)
        subWindow[0] = false
        window[0] = true
    end
    local skipW, skipH = 140*MDS, 30*MDS
    local skipY = H - 42*MDS
    local hovS = mx >= WP.x+W/2-skipW/2 and mx <= WP.x+W/2+skipW/2
             and my >= WP.y+skipY and my <= WP.y+skipY+skipH
    DL:AddText(VC(WP.x + W/2 - textW(u8('\xcf\xf0\xee\xef\xf3\xf1\xf2\xe8\xf2\xfc'))/2,
        WP.y + skipY + skipH/2 - txtH/2), hovS and U.text or U.favOff,
        u8('\xcf\xf0\xee\xef\xf3\xf1\xf2\xe8\xf2\xfc'))
    if ghostButton('##skip', W/2 - skipW/2, skipY, skipW, skipH) then
        subscribed = true
        ini.main.subscribed = 'true'
        inicfg.save(ini, CFG_FILE)
        subWindow[0] = false
        window[0] = true
    end
    if fMain then imgui.PopFont() end
    imgui.End()
end)
function main()
    while not isSampAvailable() do wait(200) end
    while not sampIsLocalPlayerSpawned() do wait(200) end
    math.randomseed(os.time())
    local ok, res = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
    if ok and res then
        local ok2, skin = pcall(getCharModel, PLAYER_PED)
        if ok2 then originalSkin = skin end
    end
    sampRegisterChatCommand('askin', function()
        if subscribed then
            window[0] = not window[0]
        else
            subWindow[0] = true
        end
    end)
    sampAddChatMessage('\xd1\xea\xe8\xed\xf7\xe0\xed\xe3\xe5\xf0 \xe7\xe0\xe3\xf0\xf3\xe6\xe5\xed. /askin', 0x58A6FF)
    local lastCheck = 0
    while true do
        wait(0)
        local now = getGameTimer()
        if selected.id >= 0 and (now - lastCheck) >= 500 then
            lastCheck = now
            local ok, curModel = pcall(getCharModel, PLAYER_PED)
            if ok and curModel ~= selected.id then
                apply(selected.id)
            end
        end
    end
end
