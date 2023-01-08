
require("/stats/sbq/sbqEffectsGeneral.lua")

function init()
	script.setUpdateDelta(5)

	removeOtherBellyEffects()

	self.cdamage = 0
	self.digested = false
	self.dropItem = false
	self.turboDigest = false

	message.setHandler("sbqTurboDigest", function()
		self.turboDigest = true
	end)

	message.setHandler("sbqDigestResponse", function(_,_, time)
		effect.modifyDuration((time or self.targetTime)+1)
		self.targetTime = time or self.targetTime
		self.dropItem = true
	end)

end

function update(dt)
	if world.entityExists(effect.sourceEntity()) and (effect.sourceEntity() ~= entity.id()) then

		self.powerMultiplier = (status.statusProperty("sbqDigestData") or {}).power or 1

		local health = world.entityHealth(entity.id())
		local digestRate = 1
		if self.turboDigest then
			digestRate = 10
		end

		local digestAmount = (digestRate * dt * self.powerMultiplier)

		if health[1] > (digestAmount + 1) and not self.digested and health[1] > 1 then
			if config.getParameter("displayDamage") then
				digestAmount = digestAmount + self.cdamage
				if digestAmount >= 1 then
					self.cdamage = digestAmount % 1
					digestAmount = math.floor(digestAmount)
					status.applySelfDamageRequest({
						damageType = "IgnoresDef",
						damage = digestAmount,
						damageSourceKind = "poison",
						sourceEntityId = entity.id()
					})
				else
					self.cdamage = digestAmount
					digestAmount = 0
				end
			else
				status.modifyResource("health", -digestAmount)
			end
			if config.getParameter("sendHunger") and (digestAmount > 0) then
				world.sendEntityMessage(effect.sourceEntity(), "sbqAddHungerHealth", digestAmount )
			end
		elseif not self.digested then
			self.cdt = 0
			self.targetTime = 2
			effect.modifyDuration(2+1)

			self.turboDigest = false
			self.digested = true
			world.sendEntityMessage(effect.sourceEntity(), config.getParameter("digestMessage") or (config.getParameter("fatal") and "sbqDigest" ) or "sbqSoftDigest", entity.id())
			status.setResource("health", 1)
		else
			self.turboDigest = false
			self.cdt = self.cdt + dt
			if self.cdt >= self.targetTime then
				doItemDrop()
				if config.getParameter("fatal") then
					status.setResource("health", -1)
					return
				end
			end
			status.setResource("health", 1)
		end
	else
		effect.expire()
	end
end

function uninit()

end
