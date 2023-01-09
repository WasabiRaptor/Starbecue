---@diagnostic disable: undefined-global
local _init = init
local _update = update

local interactive = true
local _npc_setInteractive
function capture_npc_setInteractive(bool)
	interactive = bool
	_npc_setInteractive(bool)
end
local _npc_setDamageTeam
function capture_npc_setDamageTeam(data)
	status.setStatusProperty("sbqOriginalDamageTeam", data)
	if (status.statusProperty( "sbqCurrentData" ) or {}).type ~= "prey" then
		_npc_setDamageTeam(data)
	end
end

sbq = {}

local old = {}

require("/scripts/SBQ_RPC_handling.lua")

function init()
	message.setHandler("sbqGetSeatEquips", function(_,_, current)
		status.setStatusProperty( "sbqCurrentData", current)
		if current.type == "prey" then
			status.setStatusProperty("sbqDontTouchDoors", true)
			if current.species ~= "sbqOccupantHolder" then
				_npc_setInteractive(false)
			end
		else
			status.setStatusProperty("sbqDontTouchDoors", false)
		end
		return {
			head = npc.getItemSlot("head") or false,
			chest = npc.getItemSlot("chest") or false,
			legs = npc.getItemSlot("legs") or false,
			back = npc.getItemSlot("back") or false,
			headCosmetic = npc.getItemSlot("headCosmetic") or false,
			chestCosmetic = npc.getItemSlot("chestCosmetic") or false,
			legsCosmetic = npc.getItemSlot("legsCosmetic") or false,
			backCosmetic = npc.getItemSlot("backCosmetic") or false,
			statusDirectives = status.statusProperty("speciesAnimOverrideDirectives"),
			effectDirectives = status.statusProperty("effectDirectives")
		}
	end)
	message.setHandler("sbqSetCurrentData", function(_,_, current)
		status.setStatusProperty( "sbqCurrentData", current)
		if current.type == "prey" then
			status.setStatusProperty("sbqDontTouchDoors", true)
			if current.species ~= "sbqOccupantHolder" then
				_npc_setInteractive(false)
			end
		else
			status.setStatusProperty("sbqDontTouchDoors", false)
		end
	end)

	message.setHandler("sbqInteract", function(_,_, pred, predData)
		return interact({sourceId = pred, sourcePosition = world.entityPosition(pred), predData = predData})
	end)
	message.setHandler("sbqVehicleInteracted", function (_,_, args)
		world.sendEntityMessage(args.sourceId, "sbqPlayerInteract", interact(args), entity.id() )
	end)

	message.setHandler("sbqPredatorDespawned", function(_, _, eaten, species, occupants)
		sbq.timer("sbqPredatorDespawned", 0.5, function()
			sb.logInfo("interactive"..tostring(interactive))
			_npc_setInteractive(interactive)
			status.setStatusProperty("sbqPreyList", nil)
			status.setStatusProperty("sbqCurrentData", nil)

			local sbqOriginalDamageTeam = status.statusProperty("sbqOriginalDamageTeam")
			if sbqOriginalDamageTeam then
				_npc_setDamageTeam(sbqOriginalDamageTeam)
			end
		end)
	end)

	message.setHandler("sbqMakeNonHostile", function(_,_)
		local damageTeam = entity.damageTeam()
		if (status.statusProperty("sbqOriginalDamageTeam") == nil) then
			status.setStatusProperty("sbqOriginalDamageTeam", damageTeam)
		end
		_npc_setDamageTeam({ type = "ghostly", team = damageTeam.team })
	end)

	message.setHandler("sbqDigestDrop", function(_,_, itemDrop)
		local itemDrop = itemDrop
		local overrideData = status.statusProperty("speciesAnimOverrideData") or {}
		local identity = overrideData.identity or npc.identity()
		local species = npc.species()
		local speciesFile = root.assetJson("/species/"..species..".species")
		itemDrop.parameters.predSpecies = species
		itemDrop.parameters.predDirectives = (overrideData.directives or "")..(identity.bodyDirectives or "")..(identity.hairDirectives or "")
		itemDrop.parameters.predColorMap = speciesFile.baseColorMap

		world.spawnItem(itemDrop, mcontroller.position())
	end)

	message.setHandler("sbqSaveSettings", function (_,_, settings, menuName)
		if menuName and menuName ~= "sbqOccupantHolder" then
		else
		end
	end)
	message.setHandler("sbqSavePreySettings", function(_, _, settings)
		status.setStatusProperty("sbqPreyEnabled", settings)
		status.clearPersistentEffects("digestImmunity")
		status.setPersistentEffects("digestImmunity", { "sbqDigestImmunity" })
	end)
	message.setHandler("sbqSaveAnimOverrideSettings", function (_,_, settings)
		status.setStatusProperty("speciesAnimOverrideSettings", settings)
	end)
	message.setHandler("sbqSetNPCType", function(_, _, npcType)
		sbq.tenant_setNpcType(npcType)
	end)

	status.setStatusProperty( "sbqCurrentData", nil)

	_init()

	if type(_npc_setInteractive) ~= "function" then
		_npc_setInteractive = npc.setInteractive
		npc.setInteractive = capture_npc_setInteractive

		_npc_setDamageTeam = npc.setDamageTeam
		npc.setDamageTeam = capture_npc_setDamageTeam

		old_tenant_setNpcType = tenant.setNpcType
		tenant.setNpcType = sbq.tenant_setNpcType

		old.getgenerateRecruitInfo = recruitable.generateRecruitInfo
		recruitable.generateRecruitInfo = sbq.generateRecruitInfo
	end


	sbq.config = root.assetJson("/sbqGeneral.config")
	status.clearPersistentEffects("digestImmunity")
	status.setPersistentEffects("digestImmunity", {"sbqDigestImmunity"})
	if not status.statusProperty("sbqDidVornyConvertCheck") then
		status.setStatusProperty("sbqDidVornyConvertCheck", true)
		if tenant ~= nil then
			local npcType = sbq.config.vornyConvertTable[npc.npcType()]
			if (math.random(8) == 8) and npcType ~= nil then
				sbq.tenant_setNpcType(npcType)
			end
		end
	end
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)

	_update(dt)
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

	local parameters = {
		npc = npc.species(),
		npcTypeName = npcType,
		npcLevel = npc.level(),
		npcSeed = npc.seed(),
		npcParameters = {
			identity = npc.humanoidIdentity(),
			scriptConfig = {
				ownerUuid = config.getParameter("ownerUuid"),
				personality = personality(),
				initialStorage = preservedStorage(),
				uniqueId = config.getParameter("preservedUuid") or config.getParameter("uniqueId") or entity.uniqueId(),
				preservedUuid = config.getParameter("preservedUuid") or config.getParameter("uniqueId") or entity.uniqueId()
			}
		},
		storage = storage
	}
	world.spawnStagehand(entity.position(), "sbqReplaceNPC", parameters)

	function die()
	end

	tenant.despawn(false)
end

function sbq.generateRecruitInfo()
	local recruitInfo = old.getgenerateRecruitInfo()
	recruitInfo.config.parameters.scriptConfig.preservedUuid = recruitInfo.uniqueId
	return recruitInfo
end
