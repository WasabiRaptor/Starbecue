---@diagnostic disable: undefined-global
sbq = {}
require "/scripts/any/SBQ_override_dummies.lua"
require "/scripts/actor/SBQ_actor.lua"
require "/scripts/any/SBQ_settings.lua"

require "/scripts/humanoid/SBQ_humanoid.lua"
require "/scripts/any/SBQ_RPC_handling.lua"
require "/scripts/any/SBQ_util.lua"

local old = {
	init = init,
	update = update,
	uninit = uninit,
	tenant_setNpcType = tenant.setNpcType,
	recruitable_generateRecruitInfo = recruitable.generateRecruitInfo,
	preservedStorage = preservedStorage or function () return {} end
}

local convertBackType
local convert
local occupantData
function init()
	old.init()

	sbq.targetPosition = npc.aimPosition
	sbq.loungingIn = npc.loungingIn
	sbq.resetLounging = npc.resetLounging
	sbq.species = npc.species
	sbq.gender = npc.gender
	sbq.humanoidIdentity = npc.humanoidIdentity
	sbq.setHumanoidIdentity = npc.setHumanoidIdentity
	sbq.humanoid = npc

	sbq.getItemSlot = npc.getItemSlot
	sbq.setItemSlot = npc.setItemSlot

	sbq.setLoungeControlHeld = npc.setLoungeControlHeld
	sbq.isLoungeControlHeld = npc.isLoungeControlHeld

	sbq.config = root.assetJson("/sbq.config")
	sbq.pronouns = root.assetJson("/sbqPronouns.config")

	local speciesConfig = root.speciesConfig(npc.species())
	local humanoidConfig = npc.humanoidConfig()
	sbq.settings = sbq._Settings.new(
		sb.jsonMerge(
			speciesConfig.sbqSettingsConfig or {},
			humanoidConfig.sbqSettingsConfig or {},
			config.getParameter("sbqSettingsConfig") or {
				hideBehaviorSettings = true,
				hidePredSettings = true,
			}
		),
		storage.sbqSettings or config.getParameter("sbqSettings"),
		entity.entityType()
	)
	sbq.settings:setParameterSettings()
	sbq.settings:setMessageHandlers()

	sbq.upgrades = sbq._Upgrades.new(storage.sbqUpgrades or config.getParameter("sbqUpgrades"))
	sbq.upgrades:setMessageHandlers()

	sbq.upgrades:apply(sbq.settings)
	if not sbq.upgrades.storedUpgrades.candyBonus then
		for i = 1, math.floor(math.max(npc.level(), 1)) do
			sbq.upgrades:setTiered("candyBonus", i, 1)
		end
	end
	sbq.settings:setPublicSettings()
	sbq.settings:setStatSettings()

	if not storage.sbqRandomizedSettings then
		sbq.settings:randomize(config.getParameter("sbqRandomizeSettings"), npc.seed())
	end

	if not sbq.init then
		sbq.humanoidInit()
	end
	message.setHandler("sbqConvertNPC", function(_, _)
		convertBackType = npc.npcType()
		local convertType = config.getParameter("sbqConvertType")
		if convertType then
			sbq.tenant_setNpcType(convertType)
		end
	end)
	message.setHandler("sbqUpdateCosmeticSlot", function(_, _, slot, item)
		setNpcItemSlot(slot, item)
		tenant.backup()
	end)
	message.setHandler("sbqHideDeathParticles", function()
		npc.setDeathParticleBurst()
	end)
	message.setHandler("sbqCaptured", function (_,_, id, name)
		tenant.backup()
		if storage.respawner and entity.uniqueId() then
			local entityId = world.loadUniqueEntity(storage.respawner)
			if entityId and world.entityExists(entityId) then
				world.callScriptedEntity(entityId, "tenantStolen", entity.uniqueId(), id, name)
			end
		end

		tenant.despawn(false)
	end)
	occupantData = status.statusProperty("sbqOccupantStorage")
	if occupantData then
		occupantData = root.loadVersionedJson(occupantData, "sbqOccupantStorage")
	end
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	if status.statPositive("sbqIsPrey") then
		sbq.struggleBehavior(dt)
	end

	old.update(dt)

	if sbq.loungingIn() or sbq.timerRunning("missingPredCheck") or (not entity.id()) then return end
	if occupantData and occupantData.wasCaptured then
		local originalWorldId = config.getParameter("originalWorldId")
		local originalWorldRespawner = config.getParameter("originalWorldRespawner")
		if (originalWorldId == world.id()) and (world.findUniqueEntity(originalWorldRespawner):result()) then
			local entityId = world.loadUniqueEntity(originalWorldRespawner)
			if entityId and world.entityExists(entityId) then
				world.callScriptedEntity(entityId, "tenantRestored", entity.uniqueId())
			end
		end
		occupantData.wasCaptured = false
		status.setStatusProperty("sbqOccupantStorage", root.makeCurrentVersionedJson("sbqOccupantStorage",occupantData))
	end
	if occupantData
		and (not (occupantData.flags.newOccupant or occupantData.flags.releasing))
		and sbq.timer("missingPredCheck", sbq.config.missingPredCheck) and occupantData.predUUID
	then
		local eid = world.uniqueEntityId(occupantData.predUUID)
		if eid then
			if not sbq.namedRPCList.missingPredFound then
				sbq.addNamedRPC("missingPredFound", world.sendEntityMessage(eid, "sbqReceiveOccupant", sb.jsonMerge(occupantData,{entityId = entity.id()})), function (response)
					if response then
						local success, reason = table.unpack(response)
						if not success then
							if reason ~= "inactive" then
								occupantData = nil
								status.setStatusProperty("sbqOccupantStorage", nil)
								status.clearPersistentEffects("sbqMissingPred")
							end
						else
							occupantData = nil
						end
					end
				end)
			end
		else
			status.setPersistentEffects("sbqMissingPred", { "sbqMissingPred" })
			sbq.timer("missingPredEscape", sbq.config.missingPredTimeout, function()
				occupantData = status.statusProperty("sbqOccupantStorage")
				if occupantData then
					occupantData = root.loadVersionedJson(occupantData, "sbqOccupantStorage")
				end
				if occupantData then
					local eid = world.uniqueEntityId(occupantData.predUUID)
					if not eid then
						status.setStatusProperty("sbqOccupantStorage", nil)
						status.clearPersistentEffects("sbqMissingPred")
					end
				end
			end)
			sbq.logInfo(("Could not find pred '%s' time remaining: %s"):format(occupantData.predUUID, sbq.timerRemaining("missingPredEscape")))
		end
	end
end
function uninit()
	old.uninit()
	storage.sbqSettings = sbq.settings:save()
	storage.sbqUpgrades = sbq.upgrades:save()
end

function preservedStorage()
	local ps = old.preservedStorage()
	ps.sbqSettings = sbq.settings:save()
	ps.sbqUpgrades = sbq.upgrades:save()
	ps.sbqConvertRoll = true
	ps.sbqRandomizedSettings = storage.sbqRandomizedSettings
	ps.sbqSpeciesIdentities = storage.sbqSpeciesIdentities
	ps.sbqOriginalSpecies = storage.sbqOriginalSpecies
	ps.sbqOriginalGender = storage.sbqOriginalGender
	return ps
end

function sbq.tenant_setNpcType(npcType)
	if npc.npcType() == npcType then return end

	npc.resetLounging()

	-- how vanilla does it is dumb so we're going to do it better and preserve the uuid because why the fuck wouldn't you
	-- Changing the tenant's npc type consists of:
	-- 1. Spawning a stagehand with the NPC data we want to preserve, inculding the new uuid
	-- 3. despawning ourself
	-- 3. the stagehand spawns the new NPC and updates the colonydeed with the new npc's npcType then despawns
	-- This is done to turn villagers into crewmembers.

	-- Preserve head item slots, even if they haven't changed from the default:
	storage.itemSlots = storage.itemSlots or {}
	if not storage.itemSlots.headCosmetic and not storage.itemSlots.headCosmetic then
		storage.itemSlots.headCosmetic = npc.getItemSlot("headCosmetic")
	end
	if not storage.itemSlots.head then
		storage.itemSlots.head = npc.getItemSlot("head")
	end
	storage.itemSlots.primary = nil
	storage.itemSlots.alt = nil

	local uuid = config.getParameter("sbqOverrideUniqueId") or config.getParameter("uniqueId") or entity.uniqueId()
	local parameters = {
		npc = npc.species(),
		npcTypeName = npcType,
		npcLevel = npc.level(),
		npcSeed = npc.seed(),
		npcParameters = {
			identity = npc.humanoidIdentity(),
			scriptConfig = {
				crew = config.getParameter("crew"),
				ownerUuid = recruitable.ownerUuid(),
				podUuid = recruitable.recruitUuid(),
				sbqConvertType = convertBackType,
				personality = personality(),
				initialStorage = preservedStorage(),
				uniqueId = uuid,
				sbqOverrideUniqueId = uuid
			},
			scale = mcontroller.getScale(),
			statusControllerSettings = {
				statusProperties = {
					sbqSpeciesIdentities = status.statusProperty("sbqSpeciesIdentities")
				}
			}
		},
		storage = storage
	}
	world.spawnStagehand(entity.position(), "sbqReplaceNPC", parameters)

	-- if storage.respawner then
	-- 	local spawnerId = world.loadUniqueEntity(storage.respawner)
	-- 	assert(spawnerId and world.entityExists(spawnerId))
	-- 	world.callScriptedEntity(spawnerId, "replaceTenant", uuid, {replacing = true})
	-- end

	function die()
	end

	tenant.despawn(false)
end

tenant.setNpcType = sbq.tenant_setNpcType

function recruitable.generateRecruitInfo()
	local recruitInfo = old.recruitable_generateRecruitInfo()
	recruitInfo.config.parameters.scriptConfig.sbqOverrideUniqueId = entity.uniqueId()
	recruitInfo.config.parameters.scriptConfig.sbqSettings = storage.sbqSettings
	recruitInfo.config.parameters.scriptConfig.sbqUpgrades = storage.sbqUpgrades
	return recruitInfo
end

function sbq.parentEntity()
	return _ENV.recruitable.ownerUuid() or storage.respawner, _ENV.recruitable.recruitUuid(),
		_ENV.recruitable.isFollowing()
end
