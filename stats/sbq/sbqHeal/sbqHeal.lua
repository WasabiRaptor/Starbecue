
require("/stats/sbq/sbqEffectsGeneral.lua")

function init()
	script.setUpdateDelta(5)
	self.powerMultiplier = effect.duration()
	self.digested = false
	self.cdt = 0
	removeOtherBellyEffects()
	self.healStat = config.getParameter("healStat")
	self.healRate = config.getParameter("healRate") or 1
	self.take = config.getParameter("take")
	self.takeMultiplier = config.getParameter("takeMultiplier")
	self.takeThreshold = config.getParameter("takeThreshold")

end


function update(dt)
	if not status.isResource(self.healStat) then return end
	sbq.checkRPCsFinished(dt)
	local data = status.statusProperty("sbqDigestData") or {}
	local active = status.resourcePercentage(self.healStat) < 1
	animator.setParticleEmitterActive("healing", active and data.displayEffect)
	if active then
		self.powerMultiplier = data.power or 1
		animator.setParticleEmitterEmissionRate("healing", self.powerMultiplier)
		local restoreHealth = dt * self.powerMultiplier * self.healRate
		if self.take then
			sbq.addRPC(world.sendEntityMessage(effect.sourceEntity(), "sbqTakeFromResources", restoreHealth, self.take,
				self.takeMultiplier, self.takeThreshold), function(amount)
					status.modifyResource(self.healStat, amount)
				end)
		else
			status.modifyResource(self.healStat, restoreHealth)
		end
	end
end

function uninit()

end
