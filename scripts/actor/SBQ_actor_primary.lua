local old = {
	init = init,
	update = update
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

local seatToForce
function init()
	sbq.actorInit()
    old.init()

	status.setStatusProperty("sbqType", nil)

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
