require("/scripts/actor/SBQ_actor_primary.lua")
local old = {
	init = init,
	update = update
}
function init()
	sbq.say = monster.say
	sbq.sayPortrait = monster.sayPortrait
	sbq.setLoungeControlHeld = monster.setLoungeControlHeld
	sbq.isLoungeControlHeld = monster.isLoungeControlHeld
	sbq.releaseLoungeControl = monster.releaseLoungeControl
	sbq.loungingIn = monster.loungingIn
	sbq.resetLounging = monster.resetLounging

	old.init()
end
