---@diagnostic disable: undefined-global
local old = {
    init = init,
    update = update,
	uninit = uninit
}

function init()
	old.init()

	message.setHandler("sbqPlayerCompanions", function(_, _)
		local crew = {}
		for category, companions in pairs(recruitSpawner:storeCrew()) do
			if category == "followers" then
				util.appendLists(crew, companions)
			elseif onOwnShip() and category == "shipCrew" then
				util.appendLists(crew, companions)
			end
		end
		return crew
	end)

	local companionTypes = { "followers", "shipCrew" }
	message.setHandler("sbqCrewSaveSettings", function(_, _, settings, uniqueId)
		for _, companionType in ipairs(companionTypes) do
			local companions = recruitSpawner[companionType]
			for i, follower in pairs(companions) do
				if follower.uniqueId == uniqueId or follower.spawnConfig.parameters.scriptConfig.preservedUuid == uniqueId then
					follower.spawnConfig.parameters.scriptConfig.sbqSettings = settings
					break
				end
			end
		end
		recruitSpawner:markDirty()
	end)
	message.setHandler("sbqCrewSaveDigestedPrey", function(_, _, digestedStoredTable, uniqueId)
		for _, companionType in ipairs(companionTypes) do
			local companions = recruitSpawner[companionType]
			for i, follower in pairs(companions) do
				if follower.uniqueId == uniqueId or follower.spawnConfig.parameters.scriptConfig.preservedUuid == uniqueId then
					follower.spawnConfig.parameters.statusControllerSettings = follower.spawnConfig.parameters.statusControllerSettings or {}
					follower.spawnConfig.parameters.statusControllerSettings.statusProperties = follower.spawnConfig.parameters.statusControllerSettings.statusProperties or {}
					follower.spawnConfig.parameters.statusControllerSettings.statusProperties.sbqStoredDigestedPrey = digestedStoredTable
					break
				end
			end
		end
		recruitSpawner:markDirty()
	end)
	message.setHandler("sbqCrewSaveStatusProperty", function(_, _, property, data, uniqueId)
		for _, companionType in ipairs(companionTypes) do
			local companions = recruitSpawner[companionType]
			for i, follower in pairs(companions) do
				if follower.uniqueId == uniqueId or follower.spawnConfig.parameters.scriptConfig.preservedUuid == uniqueId then
					follower.spawnConfig.parameters.statusControllerSettings = follower.spawnConfig.parameters.statusControllerSettings or {}
					follower.spawnConfig.parameters.statusControllerSettings.statusProperties = follower.spawnConfig.parameters.statusControllerSettings.statusProperties or {}
					follower.spawnConfig.parameters.statusControllerSettings.statusProperties[property] = data
					break
				end
			end
		end
		recruitSpawner:markDirty()
	end)


	message.setHandler( "sbqRequestFollow", function (_,_, uniqueId, recruitUuid, recruitInfo)
		if not checkCrewLimits(recruitUuid) then
			return false
		end
		promises:add(world.sendEntityMessage(uniqueId, "recruit.confirmFollow"), function(success)
			recruitSpawner:recruitFollowing(onOwnShip(), recruitUuid, recruitInfo)
		end)
	end)
end
