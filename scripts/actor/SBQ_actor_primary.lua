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
	sbq.config = root.assetJson("/sbq.config")

	sbq.actorInit()
	old.init()
	status.setStatusProperty("sbqProgressBar", 0)

	message.setHandler("sbqReleased", function(_, _, data)
		status.setStatusProperty("sbqProgressBar", 0)
	end)

	message.setHandler("sbqForceSit", function(_, _, data)
		mcontroller.resetAnchorState()
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
		local publicSettings = status.statusProperty("sbqPublicSettings") or {}
		destScale = math.min(publicSettings.maximumScale or 1, math.max(scale or 1, sbq.config.scaleSnap, publicSettings.minimumScale or 1))
		oldScale = mcontroller.scale()
		scaleTime = 0
		scaleDuration = duration or 1
		scaling = true
		leftoverScale = 0
	end)
	destScale = mcontroller.scale()
	oldScale = mcontroller.scale()



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
		mcontroller.setScale(currentScale)
		if scaleTime >= scaleDuration then
			scaling = false
		end
	end

	if seatToForce then
		if world.entityExists(seatToForce.source) then
			local success, error = pcall(mcontroller.setAnchorState, seatToForce.source, seatToForce.index)
			if success then seatToForce = nil else
				-- sb.logError(error)
			end
		end
	end
end

function applyDamageRequest(damageRequest)
	if (damageRequest.damageSourceKind == "sbq_digest")
	or (damageRequest.damageSourceKind == "sbq_cumdigest")
	or (damageRequest.damageSourceKind == "sbq_femcumdigest")
	or (damageRequest.damageSourceKind == "sbq_milkdigest")
	then
		local healthLost = math.min(damageRequest.damage, status.resource("health"))
		status.modifyResource("health", -damageRequest.damage)
		return {{
			sourceEntityId = damageRequest.sourceEntityId,
			targetEntityId = entity.id(),
			position = mcontroller.position(),
			damageDealt = damageRequest.damage,
			healthLost = healthLost,
			hitType = damageRequest.hitType,
			damageSourceKind = damageRequest.damageSourceKind,
			targetMaterialKind = ""
		}}
	elseif damageRequest.damageSourceKind == "sbq_heal" then
		return {{
			sourceEntityId = damageRequest.sourceEntityId,
			targetEntityId = entity.id(),
			position = mcontroller.position(),
			damageDealt = damageRequest.damage,
			healthLost = status.giveResource("health", damageRequest.damage),
			hitType = damageRequest.hitType,
			damageSourceKind = damageRequest.damageSourceKind,
			targetMaterialKind = ""
		}}
	elseif damageRequest.damageSourceKind == "sbq_size" then
		local scaleAmount = damageRequest.damage + leftoverScale
		leftoverScale = (scaleAmount % sbq.config.scaleSnap)
		scaleAmount  = scaleAmount - leftoverScale
		if (math.abs(scaleAmount)) < sbq.config.scaleSnap then
			leftoverScale = leftoverScale + scaleAmount
			return {}
		end
		scaling = true
		oldScale = mcontroller.scale()
		local publicSettings = status.statusProperty("sbqPublicSettings") or {}
		destScale = math.min(publicSettings.maximumScale or 1, math.max(destScale + scaleAmount, sbq.config.scaleSnap, publicSettings.minimumScale or 1))
		scaleDuration = math.max(0.25, scaleDuration - scaleTime, math.abs(damageRequest.damage / 2))
		scaleTime = 0
		return {}
	end
	return old.applyDamageRequest(damageRequest)
end


require("/scripts/any/SBQ_generate_drop.lua")
