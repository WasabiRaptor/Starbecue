require("/scripts/actor/SBQ_actor_primary.lua")
local old = {
	init = init,
	update = update
}
function init()
	message.setHandler("sbqResetOuchNoise", function ()
		local ouchNoise = status.statusProperty("ouchNoise")
		if ouchNoise then
		  animator.setSoundPool("ouch", {ouchNoise})
		end
	end)
	old.init()
end
