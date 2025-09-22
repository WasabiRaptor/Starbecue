sbq = {}
require "/scripts/any/SBQ_RPC_handling.lua"

function init()
	effect.addStatModifierGroup({{stat = effect.name(), amount = 1}})
	script.setUpdateDelta(5)
	self.fillRate = config.getParameter("fillRate") or 1
	self.turboFill = 0
	message.setHandler(config.getParameter("turboMessage") or "sbqTurboTransform", function(_,_, amount)
		self.turboFill = amount
	end)
	self.statusProperty = config.getParameter("transformProperty") or "sbqTransformProgress"
	self.progressBarColor = config.getParameter("progressBarColor")

	self.finished = false
	self.progress = 0
end


function update(dt)
	sbq.checkRPCsFinished(dt)
	if self.finished then
		if not self.messageSent then
			self.messageSent = true
			sbq.addRPC(world.sendEntityMessage(
				effect.sourceEntity(),
				"sbqQueueAction",
				config.getParameter("finishAction") or "transformed",
				entity.id()
			), function (received)
				if not received then self.messageSent = false end
			end, function ()
				self.messageSent = false
			end)
		end
	else
		local fillAmount = (self.fillRate * dt * status.stat("sbqDigestingPower")) * 0.1
		if self.turboFill > 0 then
			fillAmount = fillAmount * 10
		end
		self.progress = math.min(self.progress + fillAmount, 1)
		status.setStatusProperty(self.statusProperty, self.progress)
		status.setStatusProperty("sbqProgressBarColor", self.progressBarColor)
		status.setStatusProperty("sbqProgressBar", self.progress)

		if self.progress >= 1 then
			self.finished = true
		end
	end
end

function uninit()

end
