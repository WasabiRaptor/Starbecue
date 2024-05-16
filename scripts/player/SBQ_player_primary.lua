require("/scripts/actor/SBQ_actor_primary.lua")
local old = {
	init = init,
	update = update
}
function init()
	sbq.targetPosition = player.aimPosition
	sbq.loungingIn = player.loungingIn
	sbq.resetLounging = player.stopLounging

    old.init()
end
