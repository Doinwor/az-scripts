script_name('FPS Unlock')
script_author('nebymaga')

local memory = require("memory")

local function getRefreshRate()
  local paths = {
    '/sys/class/graphics/fb0/mode',
    '/sys/class/drm/card0-DSI-1/mode',
    '/sys/class/drm/card1-DSI-1/mode',
    '/sys/class/drm/card0-eDP-1/mode',
  }
  for _, p in ipairs(paths) do
    local f = io.open(p, 'r')
    if f then
      local line = f:read('*line')
      f:close()
      if line then
        local hz = line:match('(%d+)%.?%d*$') or line:match('p%-?(%d+)')
        if hz and tonumber(hz) and tonumber(hz) >= 30 then
          return tonumber(hz)
        end
      end
    end
  end
  local f = io.popen('dumpsys display 2>/dev/null')
  if f then
    for line in f:lines() do
      local hz = line:match('renderFrameRate (%d+%.?%d*)')
      if hz and tonumber(hz) and tonumber(hz) >= 30 then
        f:close()
        return tonumber(hz)
      end
    end
    f:close()
  end
  return 144
end

local names = { 'libGTASA.so', 'libgtasa.so', 'libGTASA', 'GTASA' }
local base = nil
for i = 1, 100 do
  local f = io.open('/proc/self/maps', 'r')
  if f then
    for line in f:read('*all'):gmatch('[^\n]+') do
      for _, name in ipairs(names) do
        if line:lower():find(name:lower(), 1, true) then
          base = tonumber(line:match('^([%x]+)'), 16)
          break
        end
      end
      if base then break end
    end
    f:close()
    if base then break end
  end
end
if not base then print('[FPS] libGTASA.so not found'); return end

local hz = getRefreshRate()
print('[FPS] Display: ' .. math.floor(hz + 0.5) .. ' Hz')

memory.setint8(base + 0x5E49EE, 0x00, true)
memory.setint8(base + 0x5E49EE + 1, 0xBF, true)
print('[FPS] Frame limiter disabled -> V-Sync caps at ' .. math.floor(hz + 0.5) .. ' FPS')
