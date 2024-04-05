
require("/stats/sbq/sbqEffectsGeneral.lua")

function init()
	script.setUpdateDelta(5)
	self.healStat = config.getParameter("healStat") or "health"
	self.healRate = config.getParameter("healRate") or 1
	self.damageSourceKind = config.getParameter("damageSourceKind") or "sbq_heal"

	self.cheal = 0
end


function update(dt)
	if not status.isResource(self.healStat) then return end
	local healAmount = (self.healRate * dt * status.stat("sbqDigestingPower"))
	healAmount = healAmount + self.cheal
	self.cheal = healAmount % 1
	healAmount = math.floor(healAmount)
	if healAmount >= math.max(1, status.stat("sbqDigestTick")) then
		if status.statPositive("sbqDisplayEffect") and (status.resourcePercentage(self.healStat)<1) then
			status.applySelfDamageRequest({
				hitType = "hit",
				damageType = "IgnoresDef",
				damage = healAmount,
				damageSourceKind = self.damageSourceKind,
				sourceEntityId = entity.id()
			})
		else
			status.modifyResource("health", healAmount)
		end
	else
		self.cheal = self.cheal + healAmount
	end
end

function uninit()

end
