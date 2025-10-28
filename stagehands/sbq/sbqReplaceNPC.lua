---@diagnostic disable: undefined-field

local doSpawn = false
local overrides
local npc
local type
local level
local seed
local scriptConfig
local ownerUuid
local recruitUuid
local uuid
local storage

function init()
	overrides = config.getParameter("overrides")
	npc = config.getParameter("npc")
	type = config.getParameter("type")
	level = config.getParameter("level") or world.threatLevel()
	seed = config.getParameter("seed")
	scriptConfig = overrides.scriptConfig or {}
	ownerUuid = scriptConfig.ownerUuid
	recruitUuid = scriptConfig.podUuid
	uuid = scriptConfig.uniqueId
	storage = config.getParameter("storage") or {}
end

function update()
	local position = stagehand.position()
	if (world ~= nil) and (world.regionActive ~= nil) and world.regionActive({position[1]-1,position[2]-1,position[1]+1,position[2]+1}) then
		if uuid then
			local eid = world.loadUniqueEntity(uuid)
			if eid then
				if not world.entityExists(eid) then
					doSpawn = true
				end
			else
				doSpawn = true
			end
		else
			doSpawn = true
		end
		if doSpawn then
			local newEntityId = world.spawnNpc(position, npc, type, level, seed, overrides)
			if storage.respawner then
				assert(uuid and newEntityId)
				world.callScriptedEntity(newEntityId, "tenant.setHome", storage.homePosition, storage.homeBoundary, storage.respawner, true)
				local spawnerId = world.loadUniqueEntity(storage.respawner)
				assert(spawnerId and world.entityExists(spawnerId))
				world.callScriptedEntity(spawnerId, "replaceTenant", uuid, {
					replacing = false,
					uniqueId = uuid,
					type = type,
					species = npc,
				})
			elseif ownerUuid and recruitUuid then
					world.sendEntityMessage(ownerUuid, "sbqParentUpdateType", recruitUuid, uuid, {
					type = type,
					species = npc,
					uniqueId = uuid
				})
			end
			stagehand.die()
		end
	end
end
