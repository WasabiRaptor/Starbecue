sbq = {}
require "/scripts/any/SBQ_RPC_handling.lua"

function init()
	effect.addStatModifierGroup({{stat = effect.name(), amount = 1}})
	script.setUpdateDelta(5)
	self.healStat = config.getParameter("healStat") or "health"
	self.healRate = config.getParameter("healRate") or 1
	self.damageSourceKind = config.getParameter("damageSourceKind") or "sbq_heal"
	self.turboHeal = 0
	message.setHandler("sbqTurboHeal", function(_,_, amount)
		self.turboHeal = amount
	end)

	self.cheal = 0
end


function update(dt)
	sbq.checkRPCsFinished(dt)
	if not status.isResource(self.healStat) then return end
	if status.resourcePercentage(self.healStat) >= 1 then
		if not self.messageSent and config.getParameter("finishAction") then
			self.messageSent = true
			sbq.addRPC(world.sendEntityMessage(
				effect.sourceEntity(),
				"sbqQueueAction",
				config.getParameter("finishAction"),
				entity.id()
			), function (received)
				if not received then self.messageSent = false end
			end, function ()
				self.messageSent = false
			end)
		end
		return
	else
		self.messageSent = false
	end
	local healAmount = (self.healRate * dt * status.stat("sbqDigestingPower"))
	if self.turboHeal > 0 then
		healAmount = healAmount * 10
	end
	healAmount = healAmount + self.cheal
	self.cheal = healAmount % 1
	healAmount = math.floor(healAmount)
	if healAmount >= math.max(1, status.stat("sbqDigestTick")) then
		self.turboHeal = self.turboHeal - healAmount
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
