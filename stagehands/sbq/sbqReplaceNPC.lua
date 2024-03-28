---@diagnostic disable: undefined-field

local doSpawn = false
local npcParameters
local npc
local npcTypeName
local npcLevel
local npcSeed
local scriptConfig
local ownerUuid
local recruitUuid
local uuid
local storage

function init()
	npcParameters = config.getParameter("npcParameters")
	npc = config.getParameter("npc")
	npcTypeName = config.getParameter("npcTypeName")
	npcLevel = config.getParameter("npcLevel") or world.threatLevel()
	npcSeed = config.getParameter("npcSeed")
	scriptConfig = npcParameters.scriptConfig or {}
	ownerUuid = scriptConfig.ownerUuid
	recruitUuid = scriptConfig.recruitUuid
	uuid = scriptConfig.uniqueId
	storage = config.getParameter("storage") or {}
end

function update()
	local position = stagehand.position()
	if (world ~= nil) and (world.regionActive ~= nil) and world.regionActive({position[1]-1,position[2]-1,position[1]+1,position[2]+1}) then
		if uuid then
			local entity = world.loadUniqueEntity(uuid)
			if entity then
				if not world.entityExists(entity) then
					doSpawn = true
				end
			else
				doSpawn = true
			end
		else
			doSpawn = true
		end
		if doSpawn then
			local newEntityId = world.spawnNpc(position, npc, npcTypeName, npcLevel, npcSeed, npcParameters)
			if storage.respawner then
				assert(uuid and newEntityId)
				world.callScriptedEntity(newEntityId, "tenant.setHome", storage.homePosition, storage.homeBoundary, storage.respawner, true)
				local spawnerId = world.loadUniqueEntity(storage.respawner)
				assert(spawnerId and world.entityExists(spawnerId))
				world.callScriptedEntity(spawnerId, "replaceTenant", uuid, {
					uniqueId = uuid,
					type = npcTypeName,
					species = npc,
				})
			elseif ownerUuid and recruitUuid then
					world.sendEntityMessage(ownerUuid, "sbqParentUpdateType", recruitUuid, uuid, {
					type = npcTypeName,
					species = npc,
					uniqueId = uuid
				})
			end
			stagehand.die()
		end
	end
end
