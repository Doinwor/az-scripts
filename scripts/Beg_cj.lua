script_author("Egorka")
script_name("CG runerspeed.lua")

sgrun = false 

require "lib.moonloader"
local sas = require "lib.samp.events"
local tag = ("[sgrun]:")
function main()
	if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    sampAddChatMessage(tag.."Загружен", -1  )
    sampAddChatMessage(tag.."Активация /cj", -1  )
    sampRegisterChatCommand("cj", cmd_cjrun  )
end

function cmd_cjrun()
	sgrun = not sgrun
	sampAddChatMessage(sgrun and tag.."On" or tag.."Off", -1  ) 
	if cj then
        local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        idskin = getCharModel(PLAYER_PED)
        bss = raknetNewBitStream()
        raknetBitStreamWriteInt32(bss, id)
        raknetBitStreamWriteInt32(bss, 74)
        raknetEmulRpcReceiveBitStream(153, bss)
        raknetDeleteBitStream(bss)
      else
        local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        bs = raknetNewBitStream()
        raknetBitStreamWriteInt32(bs, id)
        raknetBitStreamWriteInt32(bs, idskin)
        raknetEmulRpcReceiveBitStream(153, bs)
        raknetDeleteBitStream(bs)
    end
end
