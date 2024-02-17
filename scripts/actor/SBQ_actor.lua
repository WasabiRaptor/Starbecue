local old = {
	faceEntity = faceEntity
}

function sbq.actorInit()
	sbq.facingDirection = mcontroller.facingDirection
	sbq.scale = mcontroller.scale
	sbq.area = mcontroller.area

	sbq.setProperty = status.setStatusProperty

	sbq.stat = status.stat
	sbq.statPositive = status.statPositive

	sbq.isResource = status.isResource
	sbq.resource = status.resource
	sbq.resourcePositive = status.resourcePositive
	sbq.setResource = status.setResource
	sbq.modifyResource = status.modifyResource
	sbq.giveResource = status.giveResource
	sbq.consumeResource = status.consumeResource
	sbq.overConsumeResource = status.overConsumeResource
	sbq.resourceLocked = status.resourceLocked
	sbq.setResourceLocked = status.setResourceLocked
	sbq.resetResource = status.resetResource
	sbq.resetAllResources = status.resetAllResources
	sbq.resourceMax = status.resourceMax
	sbq.resetAllResources = status.resetAllResources
	sbq.resourcePercentage = status.resourcePercentage
	sbq.setResourcePercentage = status.setResourcePercentage
	sbq.modifyResourcePercentage = status.modifyResourcePercentage

	sbq.setStatModifiers = status.setPersistentEffects

	message.setHandler("sbqRefreshStruggleData", function (_,_, locationData)
		sbq.currentLocationData = locationData
		sbq.checkComfortLevel()
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
	message.setHandler("sbqOverConsumeResourcePercentage", function (_,_, resource, amount, ignoreBlock)
        local res = status.overConsumeResourcePercentage(resource, amount)
		if not res and ignoreBlock then status.modifyResourcePercentage(resource, -amount) end
		return res
    end)
	message.setHandler("sbqConsumeResourcePercentage", function (_,_, resource, amount, ignoreBlock)
        local res = status.consumeResourcePercentage(resource, amount)
		if not res and ignoreBlock then status.modifyResourcePercentage(resource, -amount) end
		return res
	end)
end

function sbq.checkComfortLevel()
	local comfortLevel = 0
	local adjectives = {}
	local loungeEffects = status.getPersistentEffects("lounging")
	for _, effect in ipairs(loungeEffects) do
		if type(effect) == "string" then
			local effectConfig = root.effectConfig(effect).effectConfig
			util.appendLists(adjectives, effectConfig.adjectives)
		end
	end
	-- until I define stuff for this we're just going to pretend
	local like = {
		soothing = true
	}
	local dislike = {
		melty = true
	}
	for _, adjective in ipairs(adjectives) do
		if like[adjective] then
			comfortLevel = comfortLevel + 1
		elseif dislike[adjective] then
			comfortLevel = comfortLevel - 1
		end
	end
	sbq.comfortLevel = comfortLevel
end

local struggleDirections = {false,"Left","Right","Up","Down"}
function sbq.struggleBehavior(dt)
	if sbq.timer("changeStruggleDirection", 2) then
		if true then -- do stuff with location data here to determine struggles later
			local dir = struggleDirections[math.random(#struggleDirections)]
			if dir then
				if sbq.randomTimer(dir .. "Press", 0, 2, function()
					sbq.releaseLoungeControl(dir)
				end) then
					sbq.setLoungeControlHeld(dir)
				end
			end
		end
	end
end

function faceEntity(args, board)
	if args.entity == nil or not world.entityExists(args.entity) then return false end
	local loungeAnchor = world.entityCurrentLounge(args.entity)
	if loungeAnchor and loungeAnchor.entityId == entity.id() then return false end
	return old.faceEntity(args, board)
end
