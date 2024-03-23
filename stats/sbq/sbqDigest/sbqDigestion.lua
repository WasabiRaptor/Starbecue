sbq = {}
require "/scripts/any/SBQ_RPC_handling.lua"

function init()
	script.setUpdateDelta(5)

	self.cdamage = 0
	self.digested = false
	self.dropItem = false
	self.turboDigest = 0
	self.send = config.getParameter("send")
	self.sendMultiplier = config.getParameter("sendMultiplier")
	self.digestRate = config.getParameter("digestRate") or 1
	self.digestKind = config.getParameter("damageSourceKind") or "sbq_digest"
	self.digestSent = false

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
	sbq.checkRPCsFinished(dt)
	if self.digested then
		if not self.digestSent then
			self.digestSent = true
			sbq.addRPC(world.sendEntityMessage(
				effect.sourceEntity(),
				config.getParameter("digestMessage") or "sbqDigestPrey",
				entity.id()
			), function (data)
				if (not data) or (not data[1]) then self.digestSent = false end
			end, function ()
				self.digestSent = false
			end)
		end
	else
		local health = status.resource("health")
		local digestAmount = (self.digestRate * dt * status.stat(config.getParameter("resistance") or "sbqDigestResistance") * status.stat("sbqDigestingPower"))
		if self.turboDigest > 0 then
			digestAmount = digestAmount * 100
		end
		digestAmount = digestAmount + self.cdamage
		self.cdamage = digestAmount % 1
		digestAmount = math.floor(digestAmount)
		if digestAmount >= health then
			self.digested = true
			digestAmount = health - 1
			if digestAmount <= 0 then return end
		end
		if digestAmount >= math.max(1, status.stat("sbqDigestTick")) then
			self.turboDigest = self.turboDigest - digestAmount
			if self.send then
				world.sendEntityMessage(effect.sourceEntity(), "sbqAddToResources", digestAmount, self.send, self.sendMultiplier )
			end
			if status.statPositive("sbqDisplayEffect") then
				status.applySelfDamageRequest({
					hitType = (self.turboDigest > 0) and "strongHit" or "hit",
					damageType = "IgnoresDef",
					damage = digestAmount,
					damageSourceKind = self.digestKind,
					sourceEntityId = entity.id()
				})
			else
				status.modifyResource("health", -digestAmount)
			end
		else
			self.cdamage = self.cdamage + digestAmount
		end
	end
end

function uninit()
	if config.getParameter("fatal") and self.digested then
		local entityType = world.entityType(entity.id())
		if entityType == "npc" or entityType == "monster" then
			world.callScriptedEntity(entity.id(), entityType..".setDeathParticleBurst")
		end
		status.setResource("health", -1)
		mcontroller.resetAnchorState()
	end
end
