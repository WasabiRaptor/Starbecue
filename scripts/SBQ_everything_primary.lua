local old = {
	init = init,
	update = update
}
sbq = {}


require("/scripts/rect.lua")
require("/scripts/SBQ_RPC_handling.lua")

local destScale = 1
local scaleTime = 0
local scaleDuration = 0
local oldScale = 1
local scaling = false

function init()
    old.init()

	status.setStatusProperty("sbqType", nil)
	message.setHandler("sbqApplyStatusEffects", function(_,_, statlist)
		for statusEffect, data in pairs(statlist) do
			status.setStatusProperty(statusEffect, data.property)
			status.addEphemeralEffect(statusEffect, data.power, data.source)
		end
	end)
	message.setHandler("sbqRemoveStatusEffects", function(_,_, statlist, resetHealth)
		for _, statusEffect in ipairs(statlist) do
			status.removeEphemeralEffect(statusEffect)
		end
		if resetHealth then
			status.resetResource("health")
		end
	end)
	message.setHandler("sbqRemoveStatusEffect", function(_,_, statusEffect)
		status.removeEphemeralEffect(statusEffect)
	end)


	message.setHandler("sbqForceSit", function(_,_, data)
		mcontroller.setAnchorState(data.source, data.index)
	end)

	message.setHandler("sbqGetSeatInformation", function()
		return {
			mass = mcontroller.mass(),
			powerMultiplier = status.stat("powerMultiplier")
		}
	end)

	message.setHandler("sbqSucc", function(_,_, data)
		status.setStatusProperty("sbqSuccData", data)
		status.addEphemeralEffect("sbqSucc", 1, data.source)
	end)

	message.setHandler("sbqIsPreyEnabled", function(_,_, voreType)
		local preySettings = sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))
		if preySettings.preyEnabled == false then return false end
		local enabled = true
		if type(voreType) == "table" then
			for i, voreType in ipairs(voreType) do
				enabled = enabled and preySettings[voreType]
				if not enabled then break end
			end
		else
			enabled = preySettings[voreType]
		end

		return { enabled = enabled, size = sbq.calcSize(), preyList = status.statusProperty("sbqPreyList"), type = status.statusProperty("sbqType")}
	end)

	message.setHandler("sbqGetPreyEnabled", function(_, _)
		return sb.jsonMerge({size = sbq.calcSize(), preyList = status.statusProperty("sbqPreyList"), type = status.statusProperty("sbqType")}, sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {}))))
	end)

	message.setHandler("sbqGetPreyEnabledSetting", function(_,_, setting)
		return sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))[setting]
	end)


	message.setHandler("sbqProjectileSource", function (_,_, source)
		status.setStatusProperty("sbqProjectileSource", source)
	end)

	message.setHandler("sbqDigest", function (_,_,id)
		local currentData = status.statusProperty("sbqCurrentData") or {}
		if type(currentData.id) == "number" and world.entityExists(currentData.id) then
			world.sendEntityMessage(currentData.id, "sbqDigest", id)
		end
	end)
	message.setHandler("sbqSoftDigest", function (_,_,id)
		local currentData = status.statusProperty("sbqCurrentData") or {}
		if type(currentData.id) == "number" and world.entityExists(currentData.id) then
			world.sendEntityMessage(currentData.id, "sbqSoftDigest", id)
		end
	end)
	message.setHandler("sbqPreyList", function (_,_,preyList)
		status.setStatusProperty("sbqPreyList", preyList)
	end)

	message.setHandler("sbqApplyDigestEffects", function(_, _, effects, data, sourceEntityId)
		status.setStatusProperty("sbqDigestData", data)
		for i, effect in ipairs(effects) do
			status.addEphemeralEffect(effect, 1, sourceEntityId)
		end
	end)

	message.setHandler("sbqConsumeResource", function(_, _, resourceName, amount)
		if status.resourceLocked(resourceName) then return false end
		return status.overConsumeResource(resourceName, amount)
	end)

	message.setHandler("sbqGetResourcePercentage", function(_, _, resourceName)
		return status.resourcePercentage(resourceName)
	end)

	message.setHandler("sbqAddToResources", function(_, _, amount, resources, multipliers)
		local amountRemaining = amount
		for i, resource in ipairs(resources or {}) do
			if amountRemaining <= 0 then break end
			if status.isResource(resource) then
				local mul = ((multipliers or {})[i] or 1)
				local before = status.resource(resource) / mul
				status.giveResource(resource, (amountRemaining * mul))
				amountRemaining = (before + amountRemaining) - (status.resourceMax(resource) / mul)
			end
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


	message.setHandler("sbqGetDriverStat", function( _, _, stat)
		return status.stat(stat)
	end )

	message.setHandler("sbqDigestStore", function(_, _, location, uniqueId, item)
		if (not uniqueId) or (not item) or (not location) then return end
		local item = item
		local digestedStoredTable = status.statusProperty("sbqStoredDigestedPrey") or {}
		digestedStoredTable[location] = digestedStoredTable[location] or {}
		item.count = (item.count or 1) + ((digestedStoredTable[location][uniqueId] or {}).count or 0)
		digestedStoredTable[location][uniqueId] = item
		status.setStatusProperty("sbqStoredDigestedPrey", digestedStoredTable)
	end)

	message.setHandler("sbqCheckInfusion", function(_, _, location, locationData, pred, primaryLocation)
		local enabled = sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))[locationData.infusionSetting]
		if not enabled then return end

		local uniqueId = world.entityUniqueId(entity.id())
		if locationData.infusionAccepts and locationData.infusionAccepts.characters then
			if type((locationData.infusionAccepts or {}).characters) == "table" then
				local continue
				for i, uuid in ipairs((locationData.infusionAccepts or {}).characters or {}) do
					if uuid == uniqueId then
						continue = true
						break
					end
				end
				if not continue then return end
			end
		end
		if (locationData.infusionAccepts or {}).rejectCharacters then
			if ((locationData.infusionAccepts or {}).rejectCharacters) == true then return end
			for i, uuid in ipairs((locationData.infusionAccepts or {}).rejectCharacters or {}) do
				if uuid == uniqueId then
					return
				end
			end
		end


		local template = locationData.infusionItem
		if type(template) == "string" then
			template = root.assetJson(template)
		end
		local itemDrop = sbq.generateItemDrop(pred, locationData.infuseText or "Infused By: ",
			template or root.assetJson("/sbqGeneral.config:npcEssenceTemplate"))
		world.sendEntityMessage(pred, "sbqReplaceInfusion", location, itemDrop, entity.id(), primaryLocation)
	end)

    message.setHandler("sbqSteppy", function(_, _, eid, steppyType, steppySize)
		if status.statusProperty("sbqType") == "prey" then return end
		local size = sbq.calcSize()
		if size <= (steppySize*0.4) then
			world.sendEntityMessage(eid, "sbqDidSteppy", entity.id(), steppyType)
		end
    end)

    message.setHandler("animOverrideScale", function(_, _, scale, duration)
        status.setStatusProperty("animOverrideScale", scale)
		oldScale = mcontroller.scale()
        destScale = scale
		scaleTime = 0
        scaleDuration = duration or 1
		scaling = true
    end)
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
		local currentData = status.statusProperty("sbqCurrentData")
		if currentData then
			world.sendEntityMessage(currentData.id, "sbqOccupantHolderScale", currentScale)
		end
		if scaleTime >= scaleDuration then
			scaling = false
		end
	end

end

function sbq.calcSize()
	local boundRectSize = rect.size(mcontroller.boundBox())
	local size = math.sqrt(boundRectSize[1] * boundRectSize[2]) / root.assetJson("/sbqGeneral.config:size") -- size is being based on the player, 1 prey would be math.sqrt(1.4x3.72) as that is the bound rect of the humanoid hitbox
	status.setStatusProperty("sbqSize", size)
	return size
end


require("/scripts/SBQ_generate_drop.lua")
