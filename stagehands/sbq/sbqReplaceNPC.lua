---@diagnostic disable: undefined-field

function update()
	local position = stagehand.position()
	if (world ~= nil) and (world.regionActive ~= nil) and world.regionActive({position[1]-1,position[2]-1,position[1]+1,position[2]+1}) then

		local parameters = config.getParameter("npcParameters")
		local doSpawn = true
		if type(parameters.scriptConfig.uniqueId) == "string" then
			local entity = world.loadUniqueEntity(parameters.scriptConfig.uniqueId)
			if entity then
				if world.entityExists(entity) then
					doSpawn = false
				end
			end
		end
		if doSpawn then
			local newEntityId = world.spawnNpc(position, config.getParameter("npc"), config.getParameter("npcTypeName"),
				config.getParameter("npcLevel") or world.threatLevel(), config.getParameter("npcSeed"),
				config.getParameter("npcParameters"))

			storage = config.getParameter("storage")
			if storage.respawner then
				assert(parameters.scriptConfig.uniqueId and newEntityId)
				world.callScriptedEntity(newEntityId, "tenant.setHome", storage.homePosition, storage.homeBoundary, storage.respawner
					, true)

				local spawnerId = world.loadUniqueEntity(storage.respawner)
				assert(spawnerId and world.entityExists(spawnerId))
				world.callScriptedEntity(spawnerId, "replaceTenant", entity.uniqueId(), {
					type = config.getParameter("npcTypeName")
				})
			end
			stagehand.die()
		end
	end
end
