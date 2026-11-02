local samp = require('samp.events')
function samp.onServerMessage(color, text)
    id = string.match(string.gsub(text, '{%x+}', ''), ('%[(%d+)%].+: инв'))
    if id then sampSendChat('/invite ' .. id) end
end