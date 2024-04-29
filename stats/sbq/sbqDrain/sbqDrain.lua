sbq = {}
require "/scripts/any/SBQ_RPC_handling.lua"

function init()
	script.setUpdateDelta(5)
	self.powerMultiplier = effect.duration()
	self.digested = false
	self.cdt = 0
	self.drain = config.getParameter("drain")
	self.send = config.getParameter("send")
	self.drainRate = config.getParameter("drainRate") or 1
	self.regenStat = config.getParameter("regenStat")
	self.regenStatMultiply = config.getParameter("regenStatMultiply")
	self.sendMultiplier = config.getParameter("sendMultiplier")
	self.drainCount = 0
	self.turboDrainRate = config.getParameter("turboDrainRate")

	message.setHandler(config.getParameter("turboMessage") or "sbqTurboDrain", function()
		self.turboDrain = true
	end)
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	if not status.isResource(self.drain) then return end
	if (status.resourcePercentage(self.drain) > 0) and (not status.resourceLocked(self.drain)) then
		local data = status.statusProperty("sbqDigestData") or {}
		self.powerMultiplier = data.power or 1

		local drainRate = self.drainRate
		if self.turboDrain then
			drainRate = self.turboDrainRate or (self.drainRate * 10)
		end

		local drainAmount = (drainRate * dt * self.powerMultiplier)

		local drainedAll = (status.resource(self.drain) < drainAmount)
		if self.send and (drainAmount > 0) then
			status.modifyResource(self.drain, -drainAmount)
			world.sendEntityMessage(effect.sourceEntity(), "sbqAddToResources", drainAmount * 2 ^ self.drainCount, self.send,
				self.sendMultiplier)
		end
		if drainedAll then
			status.setResourceLocked(self.drain, true)
			if self.regenStat then
				self.drainCount = self.drainCount + 1
				effect.addStatModifierGroup({ { stat = self.regenStat, effectiveMultiplier = self.regenStatMultiply or 0.5 } })
			end
		end
	end
end

function uninit()

end
