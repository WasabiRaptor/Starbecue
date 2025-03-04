require("/scripts/actor/SBQ_actor_primary.lua")
local old = {
	init = init,
	update = update
}
function init()
	sbq.targetPosition = player.aimPosition
	sbq.loungingIn = player.loungingIn
	sbq.resetLounging = player.stopLounging
	sbq.gender = humanoid.gender

	message.setHandler("sbqResetOuchNoise", function ()
		local ouchNoise = status.statusProperty("ouchNoise")
		if ouchNoise then
		  animator.setSoundPool("ouch", {ouchNoise})
		end
	end)
	old.init()
end
