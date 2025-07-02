local old = {
	init = init,
	update = update,
	applyDamageRequest = applyDamageRequest
}
sbq = {}

require"/scripts/rect.lua"
require"/scripts/any/SBQ_RPC_handling.lua"
require"/scripts/actor/SBQ_actor.lua"

local destScale = 1
local scaleTime = 0
local scaleDuration = 0
local oldScale = 1
local scaling = false
local leftoverScale = 0

local seatToForce
function init()
	old.init()
	sbq.config = root.assetJson("/sbq.config")
	sbq.actorInit()
	status.setStatusProperty("sbqProgressBar", 0)

	message.setHandler("sbqReleased", function(_, _, data)
		mcontroller.resetAnchorState()
		sbq.resetLounging()
		status.setStatusProperty("sbqProgressBar", 0)
		status.setStatusProperty("sbqProgressBarColor", {})
		seatToForce = nil
		status.setStatusProperty("sbqOccupantData", nil)
		sbq.checkStuck()
		sbq.timer("stuckCheck", 0.5, sbq.checkStuck)
	end)

	message.setHandler("sbqForceSit", function(_, _, data)
		local source, index = mcontroller.anchorState()
		if (source == data.source) and (index == data.index) then return end
		sbq.resetLounging()
		mcontroller.setPosition(world.entityPosition(data.source))
		if not pcall(mcontroller.setAnchorState, data.source, data.index) then
			seatToForce = data
		end
	end)

	message.setHandler("sbqOverConsumeResource", function(_, _, resource, amount, ignoreBlock)
		local res = status.overConsumeResource(resource, amount)
		if not res and ignoreBlock then status.modifyResource(resource, -amount) end
		return res
	end)
	message.setHandler("sbqConsumeResource", function (_,_, resource, amount, ignoreBlock)
		local res = status.consumeResource(resource, amount)
		if not res and ignoreBlock then status.modifyResource(resource, -amount) end
		return res
	end)
	message.setHandler("sbqGiveResource", function (_,_, resource, amount)
		return status.giveResource(resource, amount)
	end)
	message.setHandler("sbqModifyResourcePercentage", function (_,_, resource, amount)
		return status.modifyResourcePercentage(resource, amount)
	end)

	message.setHandler("sbqAddToResources", function(_, _, amount, resources, multipliers)
		for i, resource in ipairs(resources or {}) do
			if amount <= 0 then break end
			local mul = ((multipliers or {})[i] or 1)
			amount = amount - (status.giveResource(resource, (amount * mul)) / mul)
		end
	end)
	message.setHandler("sbqTakeFromResources", function(_, _, amount, resources, multipliers, thresholds)
		local amountRemaining = amount
		for i, resource in ipairs(resources or {}) do
			if amountRemaining <= 0 then break end
			if status.isResource(resource) then
				local threshold = ((thresholds or {})[i] or 0)
				if status.resourcePercentage(resource) > threshold then
					local mul = ((multipliers or {})[i] or 1)
					local before = status.resource(resource) / mul
					status.modifyResource(resource, -(amountRemaining * mul))
					amountRemaining = math.max((amountRemaining - before), 0)
					if resource == "energy" then
						status.setResourcePercentage("energyRegenBlock", math.max(status.resourcePercentage("energyRegenBlock"),0.1))
					end
				end
			end
		end
		return amount - amountRemaining
	end)

	message.setHandler("sbqScale", function(_, _, scale, duration)
		sbq.applyScale(scale,duration)
	end)
	destScale = mcontroller.scale()
	oldScale = mcontroller.scale()
	sbq.timer("initScale", 0.25, function ()
		sbq.applyScale(mcontroller.scale())
	end)


	-- captures
	old.status_applySelfDamageRequest = status.applySelfDamageRequest
	function status.applySelfDamageRequest(damageRequest)
		if damageRequest.damageSourceKind == "falling" then
			if self.fallDistance > (sbq.config.minimumFallDistance * mcontroller.scale()) then
				old.status_applySelfDamageRequest(damageRequest)
			end
		else
			old.status_applySelfDamageRequest(damageRequest)
		end
	end
	old.status_statusProperty = status.statusProperty
	function status.statusProperty(key,...)
		if key == "mouthPosition" then return humanoid.mouthPosition() end
		return old.status_statusProperty(key,...)
	end

	-- status effects
	status.clearPersistentEffects("sbqMissingPred")
	status.setPersistentEffects("sbqStatusPrimaryScript", {
		{stat = "sbqStatusPrimaryScript", amount = 1} -- set this stat to mark that status primary has initialized
	})
end

function update(dt)
	old.update(dt)
	sbq.checkTimers(dt)

	if scaling then
		scaleTime = scaleTime + dt
		local currentScale = oldScale + (destScale - oldScale) * (scaleTime / scaleDuration)
		if destScale > oldScale then
			currentScale = math.min(destScale, currentScale)
		elseif destScale < oldScale then
			currentScale = math.max(destScale, currentScale)
		end
		local bounds = mcontroller.boundBox()
		mcontroller.setScale(currentScale)
		local newBounds = mcontroller.boundBox()
		mcontroller.translate({0,bounds[2]-newBounds[2]})
		if (scaleTime >= scaleDuration) or (currentScale == destScale) then
			scaling = false
		end
	end

	if seatToForce then
		if world.entityExists(seatToForce.source) then
			mcontroller.setPosition(world.entityPosition(seatToForce.source))
			local success, error = pcall(mcontroller.setAnchorState, seatToForce.source, seatToForce.index)
			if success then seatToForce = nil else
				-- sb.logError(error)
			end
		else
			seatToForce = nil
		end
	end
end

function applyDamageRequest(damageRequest)
	if damageRequest.damageSourceKind == "sbq_status" then
		status.addEphemeralEffects(damageRequest.statusEffects, damageRequest.sourceEntityId)
		return {}
	elseif (damageRequest.damageSourceKind == "sbq_digest")
		or (damageRequest.damageSourceKind == "sbq_cumdigest")
		or (damageRequest.damageSourceKind == "sbq_femcumdigest")
		or (damageRequest.damageSourceKind == "sbq_milkdigest")
	then
		local healthLost = math.min(damageRequest.damage, status.resource("health"))
		status.modifyResource("health", -damageRequest.damage)
		return { {
			sourceEntityId = damageRequest.sourceEntityId,
			targetEntityId = entity.id(),
			position = mcontroller.position(),
			damageDealt = damageRequest.damage,
			healthLost = healthLost,
			hitType = damageRequest.hitType,
			damageSourceKind = damageRequest.damageSourceKind,
			targetMaterialKind = ""
		} }
	elseif damageRequest.damageSourceKind == "sbq_heal" then
		return { {
			sourceEntityId = damageRequest.sourceEntityId,
			targetEntityId = entity.id(),
			position = mcontroller.position(),
			damageDealt = damageRequest.damage,
			healthLost = status.giveResource("health", damageRequest.damage),
			hitType = damageRequest.hitType,
			damageSourceKind = damageRequest.damageSourceKind,
			targetMaterialKind = ""
		} }
	elseif damageRequest.damageSourceKind == "sbq_size" then
		local scaleAmount = damageRequest.damage + leftoverScale
		leftoverScale     = (scaleAmount % sbq.config.scaleSnap)
		scaleAmount       = scaleAmount - leftoverScale
        local min, max    = math.abs(damageRequest.knockbackMomentum[1]), math.abs(damageRequest.knockbackMomentum[2])
		if (min == 0) and (max == 0) then
			min, max = nil, nil
		end
		if (math.abs(scaleAmount)) < sbq.config.scaleSnap then
			leftoverScale = leftoverScale + scaleAmount
			return {}
		end
		sbq.applyScale(destScale + scaleAmount,
			math.max(0.25, scaleDuration - scaleTime, math.abs(damageRequest.damage / 2)), min, max)
		return {}
	end
	return old.applyDamageRequest(damageRequest)
end

function sbq.applyScale(scale, duration, min, max)
	local publicSettings = status.statusProperty("sbqPublicSettings") or {}
	destScale = math.min(publicSettings.maximumScale or 1, math.max(scale or 1, sbq.config.scaleSnap, publicSettings.minimumScale or 1, min or -math.huge), max or math.huge)
	oldScale = mcontroller.scale()
	scaleTime = 0
	scaleDuration = duration or 1
	scaling = true
end

function sbq.checkStuck()
	if mcontroller.isCollisionStuck() then -- copy of vanilla's "checkStuck" but without the lounge check
		-- sloppy catch-all correction for various cases of getting stuck in things
		-- due to bad spawn position, failure to exit loungeable (on ships), etc.
		local poly = mcontroller.collisionPoly()
		local pos = mcontroller.position()
		for maxDist = 2, 5 do
			local resolvePos = world.resolvePolyCollision(poly, pos, maxDist)
			if resolvePos then
				mcontroller.setPosition(resolvePos)
				break
			end
		end
	end
end
