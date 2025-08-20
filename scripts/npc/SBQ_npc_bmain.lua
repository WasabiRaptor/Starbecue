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
	tenant_setNpcType = tenant.setNpcType,
	recruitable_generateRecruitInfo = recruitable.generateRecruitInfo,
}

local convertBackType
local convert
function init()
	old.init()

	sbq.targetPosition = npc.aimPosition
	sbq.resetLounging = npc.resetLounging
	sbq.species = npc.species
	sbq.gender = npc.gender
	sbq.humanoidIdentity = npc.humanoidIdentity
	sbq.setHumanoidIdentity = npc.setHumanoidIdentity
	sbq.humanoid = npc
	sbq.humanoidInit()

	sbq.getItemSlot = npc.getItemSlot
	sbq.setItemSlot = npc.setItemSlot

	sbq.setLoungeControlHeld = npc.setLoungeControlHeld
	sbq.isLoungeControlHeld = npc.isLoungeControlHeld

	sbq.config = root.assetJson("/sbq.config")
	local speciesConfig = root.speciesConfig(npc.species())
	local humanoidConfig = npc.humanoidConfig()
	sbq.settings = sbq._Settings.new(
		sb.jsonMerge(
			config.getParameter("sbqSettingsConfig") or {
				hideBehaviorSettings = true,
				hidePredSettings = true,
			},
            speciesConfig.sbqSettingsConfig or {},
			humanoidConfig.sbqSettingsConfig or {}
		),
		storage.sbqSettings,
		entity.entityType()
    )
	sbq.settings:setParameterSettings()
	sbq.settings:setMessageHandlers()

    sbq.upgrades = sbq._Upgrades.new(storage.sbqUpgrades)
    sbq.upgrades:setMessageHandlers()

	sbq.upgrades:apply(sbq.settings)
	sbq.settings:setPublicSettings()
    sbq.settings:setStatSettings()

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
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	if status.statPositive("sbqIsPrey") then
		sbq.struggleBehavior(dt)
	end

	old.update(dt)

	local occupantData = status.statusProperty("sbqOccupantData")
	if occupantData
		and not ((occupantData.flags or {}).newOccupant or (occupantData.flags or {}).releasing)
		and sbq.timer("missingPredCheck", sbq.config.missingPredCheck) and occupantData.predUUID
		and not sbq.loungingIn()
	then
		local eid = world.uniqueEntityId(occupantData.predUUID)
		if eid then
			if not sbq.namedRPCList.missingPredFound then
				sbq.addNamedRPC("missingPredFound",
					world.sendEntityMessage(eid, "sbqRecieveOccupants",
						{ sb.jsonMerge(occupantData, { entityId = entity.id() }) }))
			end
		else
			status.setPersistentEffects("sbqMissingPred", { "sbqMissingPred" })
			sbq.timer("missingPredEscape", sbq.config.missingPredTimeout, function()
				local occupantData = status.statusProperty("sbqOccupantData")
				if occupantData then
					local eid = world.uniqueEntityId(occupantData.predUUID)
					if not eid then
						status.setStatusProperty("sbqOccupantData", nil)
						status.clearPersistentEffects("sbqMissingPred")
					end
				end
			end)
		end
	end
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
				sbqSettings = storage.sbqSettings,
				sbqUpgrades = storage.sbqUpgrades,
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
