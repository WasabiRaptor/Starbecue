
require("/stats/sbq/sbqEffectsGeneral.lua")

function init()
	script.setUpdateDelta(5)
	self.powerMultiplier = effect.duration()
	self.cdt = 0

	removeOtherBellyEffects()

	animator.setParticleEmitterOffsetRegion("healing", mcontroller.boundBox())

end

function update(dt)
	self.powerMultiplier = (status.statusProperty("sbqDigestData") or {}).power or 1
	animator.setParticleEmitterEmissionRate("healing", self.powerMultiplier * 3)
	status.modifyResource("health", dt * self.powerMultiplier)
	local health = world.entityHealth(entity.id())
	animator.setParticleEmitterActive("healing", health[1] < health[2])
end

function uninit()

end
