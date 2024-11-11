require("/scripts/actor/SBQ_actor_primary.lua")
local old = {
	init = init,
	update = update
}
function init()
	sbq.say = npc.say
	sbq.sayPortrait = npc.sayPortrait
	sbq.setLoungeControlHeld = npc.setLoungeControlHeld
	sbq.isLoungeControlHeld = npc.isLoungeControlHeld
	sbq.releaseLoungeControl = npc.releaseLoungeControl
	sbq.loungingIn = npc.loungingIn
	sbq.resetLounging = npc.resetLounging
	sbq.gender = humanoid.gender

	old.init()
end
