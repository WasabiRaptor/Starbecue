---@diagnostic disable: undefined-global
local old = {
	init = init,
	update = update,
	tenant_setNpcType = tenant.setNpcType,
	recruitable_generateRecruitInfo = recruitable.generateRecruitInfo,
	preservedStorage = preservedStorage,
}
sbq = {}
require "/scripts/any/SBQ_override_dummies.lua"
require "/scripts/actor/SBQ_actor.lua"
require "/scripts/any/SBQ_public_settings.lua"

require"/scripts/humanoid/SBQ_humanoidAnimator.lua"
require"/scripts/humanoid/SBQ_humanoid.lua"
require"/scripts/any/SBQ_RPC_handling.lua"

local convertBackType
function init()
	old.init()

	sbq.config = root.assetJson("/sbq.config")
	sbq.targetPosition = npc.aimPosition
	sbq.actorInit()
	sbq.humanoidInit()
	sbq.actorMessages()
	sbq.setupPublicSettings()

	sbq.say = npc.say
	sbq.sayPortrait = npc.sayPortrait
	sbq.setLoungeControlHeld = npc.setLoungeControlHeld
	sbq.releaseLoungeControl = npc.releaseLoungeControl
	sbq.loungingIn = npc.loungingIn

	message.setHandler("sbqConvertNPC", function(_, _)
		convertBackType = npc.npcType()
		local convertType = config.getParameter("sbqConvertType")
		if convertType then
			sbq.tenant_setNpcType(convertType)
		end
	end)

	if self.behavior then
		local behavior = {}
		local _behavior = self.behavior
		function behavior:run(...)
			if sbq.isLoungeDismountable() then
				_behavior:run(...)
			else
				sbq.struggleBehavior(...)
			end
		end
		-- the metatable __index on this table seems to not get this so I have to define it
		function behavior:blackboard(...)
			return _behavior:blackboard(...)
		end
		function behavior:clear(...)
			return _behavior:clear(...)
		end
		self.behavior = behavior
	end

	if not status.statusProperty("sbqDidVornyConvertCheck") then
		status.setStatusProperty("sbqDidVornyConvertCheck", true)
		if not root.speciesConfig(npc.species()).voreConfig then return end

		if config.getParameter("sbqNPC") or config.getParameter("uniqueId") or ((config.getParameter("behaviorConfig") or {}).beamOutWhenNotInUse == true) then
			return
		end
		if tenant then
			sbq.timer("maybeConvert", 0.1, function()
				if sbq.parentEntity() then return end
				convertBackType = npc.npcType()
				local convertType = config.getParameter("sbqConvertType")
				if convertType and (math.random(8) == 8) then
					sbq.tenant_setNpcType(convertType)
				end
			end)
		end
	end
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)

	old.update(dt)
end

function preservedStorage()
	return sb.jsonMerge(old.preservedStorage(), {
		sbqSettings = storage.sbqSettings,
		sbqUpgrades = storage.sbqUpgrades,
	})
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
				recruitUuid = recruitable.recruitUuid(),
				sbqConvertType = convertBackType,
				personality = personality(),
				initialStorage = preservedStorage(),
				uniqueId = uuid,
				sbqOverrideUniqueId = uuid
			}
		},
		storage = storage
	}
	world.spawnStagehand(entity.position(), "sbqReplaceNPC", parameters)

	if storage.respawner then
		local spawnerId = world.loadUniqueEntity(storage.respawner)
		assert(spawnerId and world.entityExists(spawnerId))
		world.callScriptedEntity(spawnerId, "replaceTenant", uuid, {replacing = true})
	end

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
	return _ENV.recruitable.ownerUuid() or storage.respawner, _ENV.recruitable.recruitUuid(), _ENV.recruitable.isFollowing()
end
