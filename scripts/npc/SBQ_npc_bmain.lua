---@diagnostic disable: undefined-global
sbq = {}
require "/scripts/any/SBQ_override_dummies.lua"
require "/scripts/actor/SBQ_actor.lua"
require "/scripts/any/SBQ_public_settings.lua"

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

	sbq.config = root.assetJson("/sbq.config")

	sbq.targetPosition = npc.aimPosition
	sbq.resetLounging = npc.resetLounging
	sbq.species = npc.species
	sbq.gender = npc.gender
	sbq.humanoidIdentity = npc.humanoidIdentity
    sbq.setHumanoidIdentity = npc.setHumanoidIdentity
	sbq.humanoid = npc
	sbq.humanoidInit()

	sbq.setLoungeControlHeld = npc.setLoungeControlHeld
	sbq.isLoungeControlHeld = npc.isLoungeControlHeld
	sbq.releaseLoungeControl = npc.releaseLoungeControl

	message.setHandler("sbqConvertNPC", function(_, _)
		convertBackType = npc.npcType()
		local convertType = config.getParameter("sbqConvertType")
		if convertType then
			sbq.tenant_setNpcType(convertType)
		end
	end)

	-- if self.behavior then
	-- 	local behavior = {}
	-- 	local _behavior = self.behavior
	-- 	function behavior:run(...)
	-- 		if not status.statPositive("sbqIsPrey") then
	-- 			_behavior:run(...)
	-- 		else
	-- 			sbq.struggleBehavior(...)
	-- 		end
	-- 	end
	-- 	setmetatable(behavior, {
	-- 		__index = function (t, k)
	-- 			return _behavior[k]
	-- 		end
	-- 	})
	-- 	self.behavior = behavior
	-- end

	sbq.rollConvert()
	if not convert then
		sbq.setupPublicSettings()
		if npc.getHumanoidParameter("sbqEnabled") and not config.getParameter("sbqNPC") then
			npc.setHumanoidParameter("sbqEnabled")
			npc.refreshHumanoidParameters()
		end
	end
end

function sbq.rollConvert()
	if config.getParameter("sbqConvertType") and not status.statusProperty("sbqDidConvertCheck") then
		status.setStatusProperty("sbqDidConvertCheck", true)
		if entity.uniqueId() then return end
		local speciesConfig = root.speciesConfig(npc.species())
		if not speciesConfig.voreConfig then return end

		if config.getParameter("sbqNPC")
			or config.getParameter("uniqueId")
			or ((config.getParameter("behaviorConfig") or {}).beamOutWhenNotInUse == true)
			or npc.humanoidIdentity().imagePath ~= nil
		then
			return
		end
		if tenant then
			convert = (math.random() <= math.max(config.getParameter("sbqConvertChance") or 0, speciesConfig.sbqConvertChance or 0, sbq.config.convertChance))
			if convert then
				sbq.timer("maybeConvert", 0.1,
					function()
						if sbq.parentEntity() or entity.uniqueId() then
							sbq.setupPublicSettings()
							return
						end
						if npc.species() == config.getParameter("sbqConvertSpecies") then
							local speciesList = root.assetJson("/interface/windowconfig/charcreation.config")
								.speciesOrdering
							local badSpecies = true
							local newSpecies
							while badSpecies do
								local i = math.random(#speciesList)
								newSpecies = speciesList[i]
								badSpecies = sbq.config.transformationBlacklist[newSpecies] or false
								if not badSpecies then
									local speciesFile = root.speciesConfig(newSpecies)
									if speciesFile.forceName then
										badSpecies = true
									elseif speciesFile.voreConfig then
										if sbq.query(sbq.fetchConfigArray(speciesFile.voreConfig) or {}, { "overrideSettings", "speciesTF" }) == false then
											badSpecies = true
										end
									else
										badSpecies = true
									end
								end
								if badSpecies then
									table.remove(speciesList, i)
								end
							end
							npc.setHumanoidIdentity(root.generateHumanoidIdentity(newSpecies, npc.seed(), npc.gender()))
						end
						convertBackType = npc.npcType()
						local convertType = config.getParameter("sbqConvertType")
						if convertType and convert then
							sbq.tenant_setNpcType(convertType)
						end
					end)
			end
		end
	end
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)

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
