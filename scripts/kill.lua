local sampev = require('lib.samp.events')

function sampev.onPlayerDeath(playerId)
	printStringNow("+kill", 1000)
end