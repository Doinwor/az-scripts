script_properties('work-in-pause', 'forced-reloading-only')

local ffi = require('ffi')
local hook = require('monethook')
local gta = ffi.load('GTASA')

ffi.cdef[[
  void  _ZN5CFont11PrintStringEffPt(float x, float y, uint16_t* gxt);
  void  _Z14AsciiToGxtCharPKcPt(const char* ascii, uint16_t* gxt);
  uint8_t* _Z14GxtCharToAsciiPth(uint16_t* gxt, uint8_t flag);
]]

local money = "0"
local orig_PrintString

local moneyGxtBuf = ffi.new("uint16_t[64]")
local asciiBuf    = ffi.new("char[64]")

function rebuild_money_gxt()
  local newStr = "$" .. money
  ffi.copy(asciiBuf, newStr)
  asciiBuf[#newStr] = 0
  gta._Z14AsciiToGxtCharPKcPt(asciiBuf, moneyGxtBuf)
end

function print_string_hook(x, y, gxt)
  local resultPtr = gta._Z14GxtCharToAsciiPth(gxt, 0)
  if resultPtr[0] == 36 and resultPtr[1] == 48 then
    return orig_PrintString(x, y, moneyGxtBuf)
  end
  return orig_PrintString(x, y, gxt)
end

function onReceivePacket(id, bs)
  if id == 220 then
    raknetBitStreamIgnoreBits(bs, 8)
    if raknetBitStreamReadInt8(bs) == 84 and raknetBitStreamReadInt8(bs) == 8 and raknetBitStreamReadInt8(bs) == 47 then
      local length  = raknetBitStreamReadInt16(bs)
      local encoded = raknetBitStreamReadInt8(bs)
      money = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or raknetBitStreamReadString(bs, length)
      rebuild_money_gxt()
    end
  end
end

function main()
  rebuild_money_gxt()
  orig_PrintString = hook.new(
    'void(*)(float, float, uint16_t*)',
    print_string_hook,
    ffi.cast('uintptr_t', ffi.cast('void*', gta._ZN5CFont11PrintStringEffPt))
  )
  wait(-1)
end