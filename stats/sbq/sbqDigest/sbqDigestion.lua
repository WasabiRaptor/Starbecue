
require("/stats/sbq/sbqEffectsGeneral.lua")

function init()
	script.setUpdateDelta(5)

	removeOtherBellyEffects()

	self.cdamage = 0
	self.digested = false
	self.dropItem = false
	self.turboDigest = 0
	self.send = config.getParameter("send")
	self.sendMultiplier = config.getParameter("sendMultiplier")
	self.digestMessage = config.getParameter("digestMessage")
	self.fatal = config.getParameter("fatal")

	message.setHandler("sbqTurboDigest", function(_,_, amount)
		self.turboDigest = amount
	end)

	message.setHandler("sbqDigestResponse", function(_,_, time)
		effect.modifyDuration((time or self.targetTime)+1)
		self.targetTime = time or self.targetTime
		self.dropItem = true
	end)

end

function update(dt)

	local health = world.entityHealth(entity.id())
	local digestRate = 1
	if self.turboDigest < 0 then
		digestRate = 10
	end

	local digestAmount = (digestRate * dt * status.stat(config.getParameter("resistance") or "sbqDigestResistance"))

	if health[1] > (digestAmount + 1) and not self.digested and health[1] > 1 then
		if status.statPositive("sbqDisplayEffect") then
			digestAmount = digestAmount + self.cdamage
			if digestAmount >= 1 then
				self.cdamage = digestAmount % 1
                digestAmount = math.floor(digestAmount)
				self.turboDigest = self.turboDigest - digestAmount
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
		if self.send and (digestAmount > 0) then
			world.sendEntityMessage(effect.sourceEntity(), "sbqAddToResources", digestAmount, self.send, self.sendMultiplier )
		end
	elseif not self.digested then
		self.cdt = 0
		self.targetTime = 2
		effect.modifyDuration(2+1)

		self.digested = true
		world.sendEntityMessage(effect.sourceEntity(), self.digestMessage or (self.fatal and "sbqDigest" ) or "sbqSoftDigest", entity.id())
		status.setResource("health", 1)
	else
		self.cdt = self.cdt + dt
		if self.cdt >= self.targetTime then
			doItemDrop()
			if self.fatal then
				local entityType = world.entityType(entity.id())
				if entityType == "npc" or entityType == "monster" then
					world.callScriptedEntity(entity.id(), entityType..".setDeathParticleBurst")
				end
				status.setResource("health", -1)
				return
			end
		end
		status.setResource("health", 1)
	end
end

function uninit()

end
