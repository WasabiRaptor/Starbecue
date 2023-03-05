local old = {
	init = init,
	update = update
}
sbq = {}
require("/scripts/SBQ_everything_primary.lua")

function init()
	old.init()
	sbq.everything_primary()
end
