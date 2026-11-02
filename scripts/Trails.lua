local imgui = require('mimgui')
local inicfg = require('inicfg')

local points = {}
local col = 0xFFFFFFFF

local menu = imgui.new.bool(false)
local activated = imgui.new.bool(true)
local rainbowc = imgui.new.bool(true)
local width = imgui.new.int(3)
local length = imgui.new.int(50)
local waits = imgui.new.int(30)
local trailoffset = imgui.new.int(0)
local position = imgui.new.int(0)
local mode = imgui.new.int(0)
local trailalpha = imgui.new.int(256)
local trailspeed = imgui.new.int(1)
local color1 = imgui.new.float(1.0)
local color2 = imgui.new.float(1.0)
local color3 = imgui.new.float(1.0)
local color4 = imgui.new.float(1.0)

local zpos = imgui.new.float(0)

local newFrame = imgui.OnFrame(
    function() return menu[0] end,
    function(player)
      imgui.SetNextWindowPos(imgui.ImVec2(350.0, 250.0), imgui.Cond.FirstUseEver)
      imgui.SetNextWindowSize(imgui.ImVec2(300.0, 430.0), imgui.Cond.FirstUseEver)
      imgui.Begin('Trails', menu)

      imgui.Checkbox('Activated', activated)

      imgui.SliderInt('Width', width, 1, 10)
      if imgui.SliderInt('Length', length, 1, 1000) then points = {} end
      imgui.SliderInt('Wait', waits, 0, 1000)
      imgui.Checkbox('Rainbow', rainbowc)

      if rainbowc[0] then
          imgui.RadioButtonIntPtr("Default", mode, 1)
          imgui.RadioButtonIntPtr("Static", mode, 2)
          if mode[0] == 1 then
              imgui.SliderInt('Offset', trailoffset, -200, 200)
          end
          imgui.SliderInt('Speed', trailspeed, 1, 10)
          imgui.SliderInt('Alpha', trailalpha, 1, 256, trailalpha[0] == 256 and "Smooth")
      else
          imgui.SliderFloat('Line color1', color1, 0, 255)
          imgui.SliderFloat('Line color2', color2, 0, 255)
          imgui.SliderFloat('Line color3', color3, 0, 255)
          imgui.SliderFloat('Line color4', color4, 0, 255)

          if imgui.Button("apply") then
              col = join_argb(color1[0], color2[0], color3[0], color4[0])
          end
      end
      
     -- imgui.Combo('Trail Position', position, {"CharPos", "Left Knee", "Right Knee", "Right Elbow", "Left Elbow", "Body", "Right Shoulder", "Left Shoulder", "Head", "Right Foot", "Left Foot", "Right Hand", "Left Hand"}, -1)
      imgui.SliderFloat('Z Position', zpos, -1, 1, '%.1f')
    imgui.End()
end)

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('trail', function() menu[0] = not menu[0] end)
    while true do
        wait(0)
        if activated[0] and #points > 0 then
            local x,y,z = getPos(PLAYER_PED)
            points[#points] = {x = x, y = y, z = z + zpos[0]}
            for i = 1, #points do
                if  points[i] ~= nil
                and points[i+1] ~= nil
                and isPointOnScreen(points[i].x, points[i].y,points[i].z, 0)
                and isPointOnScreen(points[i+1].x, points[i+1].y,points[i+1].z, 0)
                then
                    local col = col
                    if rainbowc[0] then
                        local r,g,b,a = (mode[0] == 0 and rainbow or rainbow_v2)(trailspeed[0], 255, (i+(mode[0] == 1 and trailoffset[0] or 0)) / -50)
                        local alpha = trailalpha[0] == 256 and i*(255/(#points > 255 and 255 or #points)) or trailalpha[0]
                        col = join_argb(alpha > 255 and 255 or alpha,r,g,b)
                    end
                    local x,y = convert3DCoordsToScreen(points[i].x, points[i].y,points[i].z)
            local x1,y1 = convert3DCoordsToScreen(points[i+1].x, points[i+1].y,points[i+1].z) 
                    renderDrawLine(x,y,x1,y1,width[0],col)
                end 
            end
        end
    end
end

lua_thread.create(function()
    while not isSampAvailable() do wait(100) end
    while true do
        wait(waits[0])
        local x,y,z = getPos(PLAYER_PED)
        points[#points+1] = {x = x, y = y, z = z + zpos[0]}
        if #points > length[0] then
            table.remove(points, 1)
        end
    end
end)

local ffi = require('ffi')
local gta = ffi.load('GTASA')
ffi.cdef[[
  typedef struct RwV3d {
    float x, y, z;
  } RwV3d;
  // void CPed::GetBonePosition(CPed *this, RwV3d *posn, uint32 bone, bool calledFromCam) - Mangled name
  void _ZN4CPed15GetBonePositionER5RwV3djb(void* thiz, RwV3d* posn, uint32_t bone, bool calledFromCam);
]]

function GetBodyPartCoordinates(ped, bone)
    local pedptr = ffi.cast('void*', getCharPointer(ped))
    local posn = ffi.new('RwV3d[1]')
    gta._ZN4CPed15GetBonePositionER5RwV3djb(pedptr, posn, bone, false)
    return vec[0], vec[1], vec[2]
  end
  

function getPos(handle)
    if position[0] == 0 then local x,y,z = getCharCoordinates(handle) return x,y,z end
    local bone = {42, 52, 23, 33, 3, 22, 32, 8, 54, 44, 25, 35}
    local x,y,z = GetBodyPartCoordinates(ped, bone[position[0]])
    return x,y,z
end

function join_argb(a, r, g, b)
    local argb = b
    argb = bit.bor(argb, bit.lshift(g, 8))
    argb = bit.bor(argb, bit.lshift(r, 16))
    argb = bit.bor(argb, bit.lshift(a, 24))
    return argb
end

function rainbow(speed, alpha, offset) -- by rraggerr
    local clock = os.clock() + offset
    local r = math.floor(math.sin(clock * speed) * 127 + 128)
    local g = math.floor(math.sin(clock * speed + 2) * 127 + 128)
    local b = math.floor(math.sin(clock * speed + 4) * 127 + 128)
    return r,g,b,alpha
end

function rainbow_v2(speed, alpha, offset) -- by rraggerr
    local r = math.floor(math.sin(offset * speed) * 127 + 128)
    local g = math.floor(math.sin(offset * speed + 2) * 127 + 128)
    local b = math.floor(math.sin(offset * speed + 4) * 127 + 128)
    return r,g,b,alpha
end

