sbq = {}
require "/scripts/any/SBQ_RPC_handling.lua"

function init()
	effect.addStatModifierGroup({{stat = effect.name(), amount = 1}})
	script.setUpdateDelta(5)

	self.cdamage = 0
	self.digested = false
	self.turboDigest = 0
	self.send = config.getParameter("send")
	self.sendMultiplier = config.getParameter("sendMultiplier")
	self.digestRate = config.getParameter("digestRate") or 1
	self.digestKind = config.getParameter("damageSourceKind") or "sbq_digest"
	self.digestSent = false
	self.resistance = "sbq_"..(config.getParameter("digestType") or "acidDigest").."Resistance"

	message.setHandler("sbqTurboDigest", function(_,_, amount)
		self.turboDigest = amount
	end)
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	if self.digested then
		sendDigest()
	else
		local health = status.resource("health")
		local digestAmount = (self.digestRate * dt * status.stat(self.resistance) * status.stat("sbqDigestingPower"))
		if self.turboDigest > 0 then
			digestAmount = digestAmount * 10
		end
		digestAmount = digestAmount + self.cdamage
		self.cdamage = digestAmount % 1
		digestAmount = math.floor(digestAmount)
		if digestAmount >= health then
			digestAmount = health - 1
			if digestAmount <= 0 then return setDigested() end
			return tickDigest(digestAmount)
		end
		if (digestAmount >= math.max(1, status.stat("sbqDigestTick"))) then
			tickDigest(digestAmount)
		else
			self.cdamage = self.cdamage + digestAmount
		end
	end
end

function onExpire()
	if self.digested then sendDigest() end
	if (config.getParameter("fatal") and self.digested) and not status.statPositive("sbq_"..(config.getParameter("digestType") or "acidDigest").."FatalImmune") then
		local entityType = world.entityType(entity.id())
		if entityType == "npc" or entityType == "monster" then
			world.callScriptedEntity(entity.id(), entityType..".setDeathParticleBurst")
		end
		status.modifyResourcePercentage("health", -2)
	end
end

function setDigested()
	self.digested = true
	sendDigest()
	effect.addStatModifierGroup({
		{ stat = "healingBonus", amount = -10 },
		{ stat = "healingStatusImmunity", amount = 999 },
		{ stat = "healthRegen", effectiveMultiplier = 0 },
		{ stat = "energyRegenPercentageRate", effectiveMultiplier = 0 }
	})
end

function tickDigest(digestAmount)
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
	if status.resource("health") <= 1 then
		setDigested()
	end
end

function sendDigest()
	if not self.digestSent then
		local item = config.getParameter("itemDrop")
		sbq.addRPC(world.sendEntityMessage(entity.id(), "sbqGetCard"), function(card)
			card.name = item
			item = card
		end)
		self.digestSent = true
		sbq.addRPC(world.sendEntityMessage(
			effect.sourceEntity(),
			"sbqQueueAction",
			config.getParameter("digestedAction") or "digested",
			entity.id(),
			(item ~= nil) and (((type(item) == "table") and item) or {name = item, parameters = {}}),
			config.getParameter("digestType"),
			status.statPositive("sbq_"..config.getParameter("digestType").."DropsAllow")
		), function (recieved)
			if not recieved then self.digestSent = false end
		end, function ()
			self.digestSent = false
		end)
	end
end
