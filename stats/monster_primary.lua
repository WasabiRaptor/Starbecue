require "/scripts/vec2.lua"

--[[
I want this to be standalone, and I want it to be compatible with SSVM, but doing that requires a bit of some funny business
to keep compatiblity while modifying this file, I'll need to have some of their message handlers, or at the very least, message
handlers of our own with the same name that give the same outputs, HOWEVER we also want to not cause any incompatibility issues with
any other mods, we want to make sure these two mods can handle this even if we don't *require* them

https://steamcommunity.com/sharedfiles/filedetails/?id=2442860690
https://steamcommunity.com/sharedfiles/filedetails/?id=2442873217

having these installed should allow us to co-exist with other mods that modify monsters nicely, as well as make it easier for us to
add message handlers
]]

function init()
	self.damageFlashTime = 0

	message.setHandler("applyStatusEffect", function(_, _, effectConfig, duration, sourceEntityId)
		status.addEphemeralEffect(effectConfig, duration, sourceEntityId)
	end)
end

function applyDamageRequest(damageRequest)
	if world.getProperty("nonCombat") then
		return {}
	end

	-- don't get hit by knockback attacks if immune to knockback
	if damageRequest.damageType == "Knockback" and status.stat("grit") >= 1 then
		return {}
	end

	local damage = 0
	if damageRequest.damageType == "Damage" or damageRequest.damageType == "Knockback" then
		damage = damage + root.evalFunction2("protection", damageRequest.damage, status.stat("protection"))
	elseif damageRequest.damageType == "IgnoresDef" then
		damage = damage + damageRequest.damage
	elseif damageRequest.damageType == "Status" then
		-- only apply status effects
		status.addEphemeralEffects(damageRequest.statusEffects, damageRequest.sourceEntityId)
		return {}
	elseif damageRequest.damageType == "Environment" then
		return {}
	end

	if status.resourcePositive("shieldHealth") then
		local shieldAbsorb = math.min(damage, status.resource("shieldHealth"))
		status.modifyResource("shieldHealth", -shieldAbsorb)
		damage = damage - shieldAbsorb
	end

	local hitType = damageRequest.hitType
	local elementalStat = root.elementalResistance(damageRequest.damageSourceKind)
	local resistance = status.stat(elementalStat)
	damage = damage - (resistance * damage)
	if resistance ~= 0 and damage > 0 then
		hitType = resistance > 0 and "weakhit" or "stronghit"
	end

	local healthLost = math.min(damage, status.resource("health"))
	if healthLost > 0 and damageRequest.damageType ~= "Knockback" then
		status.modifyResource("health", -healthLost)
		if hitType == "stronghit" then
			self.damageFlashTime = 0.07
			self.damageFlashType = "strong"
		elseif hitType == "weakhit" then
			self.damageFlashTime = 0.07
			self.damageFlashType = "weak"
		else
			self.damageFlashTime = 0.07
			self.damageFlashType = "default"
		end
	end

	status.addEphemeralEffects(damageRequest.statusEffects, damageRequest.sourceEntityId)

	local knockbackFactor = (1 - status.stat("grit"))
	local momentum = knockbackMomentum(vec2.mul(damageRequest.knockbackMomentum, knockbackFactor))
	if status.resourcePositive("health") and vec2.mag(momentum) > 0 then
		self.applyKnockback = momentum
		if vec2.mag(momentum) > status.stat("knockbackThreshold") then
			status.setResource("stunned", math.max(status.resource("stunned"), status.stat("knockbackStunTime")))
		end
	end

	if not status.resourcePositive("health") then
		hitType = "kill"
	end
	return {{
		sourceEntityId = damageRequest.sourceEntityId,
		targetEntityId = entity.id(),
		position = mcontroller.position(),
		damageDealt = damage,
		healthLost = healthLost,
		hitType = hitType,
		kind = "Normal",
		damageSourceKind = damageRequest.damageSourceKind,
		targetMaterialKind = status.statusProperty("targetMaterialKind")
	}}
end

function knockbackMomentum(momentum)
	local knockback = vec2.mag(momentum)
	if mcontroller.baseParameters().gravityEnabled and math.abs(momentum[1]) > 0	then
		local dir = momentum[1] > 0 and 1 or -1
		return {dir * knockback / 1.41, knockback / 1.41}
	else
		return momentum
	end
end

function update(dt)
	if self.damageFlashTime > 0 then
		local color = status.statusProperty("damageFlashColor") or "ff0000=0.85"
		if self.damageFlashType == "strong" then
			color = status.statusProperty("strongDamageFlashColor") or "ffffff=1.0" or color
		elseif self.damageFlashType == "weak" then
			color = status.statusProperty("weakDamageFlashColor") or "000000=0.0" or color
		end
		status.setPrimaryDirectives(string.format("fade=%s", color))
	else
		status.setPrimaryDirectives()
	end
	self.damageFlashTime = math.max(0, self.damageFlashTime - dt)

	if self.applyKnockback then
		mcontroller.setVelocity({0,0})
		if vec2.mag(self.applyKnockback) > status.stat("knockbackThreshold") then
			mcontroller.addMomentum(self.applyKnockback)
		end
		self.applyKnockback = nil
	end

	if mcontroller.atWorldLimit(true) then
		status.setResourcePercentage("health", 0)
	end
end

require("/scripts/monster/SBQ_monster_primary.lua")
require("/scripts/monster/SSVM_compatibility_monster.lua")
