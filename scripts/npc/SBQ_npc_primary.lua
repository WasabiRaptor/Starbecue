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

	old.init()
end
