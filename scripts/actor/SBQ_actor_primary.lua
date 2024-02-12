local old = {
	init = init,
	update = update
}
sbq = {}


require("/scripts/rect.lua")
require("/scripts/any/SBQ_RPC_handling.lua")

local destScale = 1
local scaleTime = 0
local scaleDuration = 0
local oldScale = 1
local scaling = false

local seatToForce
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


    message.setHandler("sbqForceSit", function(_, _, data)
		mcontroller.resetAnchorState()
		if not pcall(mcontroller.setAnchorState, data.source, data.index) then
			seatToForce = data
		end
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

    message.setHandler("sbqScale", function(_, _, scale, duration)
		oldScale = mcontroller.scale()
        destScale = scale or 1
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
		if currentData and (type(currentData.id) == "number") and world.entityExists(currentData.id) then
			world.sendEntityMessage(currentData.id, "sbqOccupantHolderScale", currentScale)
		end
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


require("/scripts/any/SBQ_generate_drop.lua")
