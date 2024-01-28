---@diagnostic disable: undefined-global
local old = {
    init = init,
	update = update
}
sbq = {}
require("/scripts/SBQ_humanoidAnimator.lua")
require("/scripts/SBQ_public_settings.lua")

local interactive = true
local _npc_setInteractive
function capture_npc_setInteractive(bool)
	interactive = bool
	_npc_setInteractive(bool)
end

local _npc_setDamageTeam
function capture_npc_setDamageTeam(data)
	status.setStatusProperty("sbqOriginalDamageTeam", data)
	local type = status.statusProperty("sbqType")
	if type ~= "prey" then
		_npc_setDamageTeam(data)
	end
end

function sbq.calcSize()
	local boundRectSize = rect.size(mcontroller.boundBox())
	local size = math.sqrt(boundRectSize[1] * boundRectSize[2]) /
	root.assetJson("/sbqGeneral.config:size")                                                            -- size is being based on the player, 1 prey would be math.sqrt(1.4x3.72) as that is the bound rect of the humanoid hitbox
	status.setStatusProperty("sbqSize", size)
	return size
end

local controlPathMoveRPC
function sbq.controlPathMove(target, run, options)
	local current = status.statusProperty("sbqCurrentData")
	if current and type(current.id) == "number" and current.species ~= "sbqOccupantHolder" and status.statusProperty("sbqType") == "driver" then
		local newRPC = world.sendEntityMessage(current.id, "sbqControlPathMove", target, run, options)
		local syncResult = newRPC:finished() and newRPC:succeeded() and newRPC:result()
		if syncResult ~= nil then
			controlPathMoveRPC = nil
			return syncResult
		end
		-- this logic is a mess... that's what happens when you send another message without waiting for the previous
		local oldFinished = controlPathMoveRPC and controlPathMoveRPC:finished() and controlPathMoveRPC:succeeded()
		local oldResult = oldFinished and controlPathMoveRPC:result()
		if oldFinished and oldResult ~= nil then
			controlPathMoveRPC = nil
			return oldResult
		end
		if (oldFinished and oldResult == nil) or (options ~= nil) then
			controlPathMoveRPC = newRPC
			return nil
		end
	else
		return old.controlPathMove(target, run, options)
	end
end

function sbq.setPosition(position)
	local current = status.statusProperty("sbqCurrentData")
	local type = status.statusProperty("sbqType")
	if current and current.species ~= "sbqOccupantHolder" and type == "driver" then
		world.sendEntityMessage(current.id, "sbqSetPosition", position)
	else
		old.setPosition(position)
	end
end

require("/scripts/SBQ_RPC_handling.lua")

function init()
	message.setHandler("sbqGetSeatEquips", function(_, _, current)
		status.setStatusProperty("sbqCurrentData", current)
		local type = status.statusProperty("sbqType")
		if type == "prey" then
			status.setStatusProperty("sbqDontTouchDoors", true)
		else
			status.setStatusProperty("sbqDontTouchDoors", false)
		end
		if current.species ~= "sbqOccupantHolder" then
			_npc_setInteractive(false)
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
			effectDirectives = status.statusProperty("effectDirectives")
		}
	end)
	message.setHandler("sbqSetCurrentData", function(_, _, current)
		status.setStatusProperty("sbqCurrentData", current)
		local type = status.statusProperty("sbqType")
		if type == "prey" then
			status.setStatusProperty("sbqDontTouchDoors", true)
			if current.species ~= "sbqOccupantHolder" then
				_npc_setInteractive(false)
			end
		else
			status.setStatusProperty("sbqDontTouchDoors", false)
		end
	end)
	message.setHandler("sbqSetType", function(_, _, current)
		status.setStatusProperty("sbqType", current)
	end)

	message.setHandler("sbqInteract", function(_, _, pred, predData)
		return interact({ sourceId = pred, sourcePosition = world.entityPosition(pred), predData = predData })
	end)
	message.setHandler("sbqVehicleInteracted", function(_, _, args)
		world.sendEntityMessage(args.sourceId, "sbqPlayerInteract", interact(args), entity.id())
	end)

	message.setHandler("sbqPredatorDespawned", function(_, _, eaten, species, occupants)
		sbq.timer("sbqPredatorDespawned", 0.5, function()
			_npc_setInteractive(interactive)
			local sbqOriginalDamageTeam = status.statusProperty("sbqOriginalDamageTeam")
			if sbqOriginalDamageTeam then
				_npc_setDamageTeam(sbqOriginalDamageTeam)
			end
			sbq.timer("sbqPredatorDespawned2", 5, function()
				_npc_setInteractive(interactive)
				if sbqOriginalDamageTeam then
					_npc_setDamageTeam(sbqOriginalDamageTeam)
				end
			end)

			status.setStatusProperty("sbqPreyList", nil)
			status.setStatusProperty("sbqCurrentData", nil)
			if not eaten then
				local resolvePosition = world.resolvePolyCollision(mcontroller.collisionPoly(), mcontroller.position(), 5)
				if resolvePosition ~= nil then
					mcontroller.setPosition(resolvePosition)
				end
			end
		end)
	end)

	message.setHandler("sbqMakeNonHostile", function(_, _)
		local damageTeam = entity.damageTeam()
		if (status.statusProperty("sbqOriginalDamageTeam") == nil) then
			status.setStatusProperty("sbqOriginalDamageTeam", damageTeam)
		end
		_npc_setDamageTeam({ type = "ghostly", team = damageTeam.team })
	end)

	message.setHandler("sbqSaveSettings", function(_, _, settings, menuName)
		if menuName and menuName ~= "sbqOccupantHolder" then
		else
		end
	end)
	message.setHandler("sbqSavePreySettings", function(_, _, settings)
		status.setStatusProperty("sbqPreyEnabled", settings)
		world.sendEntityMessage(entity.id(), "sbqRefreshDigestImmunities")
	end)
	message.setHandler("sbqSaveAnimOverrideSettings", function(_, _, settings)
		status.setStatusProperty("speciesAnimOverrideSettings", settings)
	end)
	message.setHandler("sbqSetNPCType", function(_, _, npcType)
		sbq.tenant_setNpcType(npcType)
	end)

	message.setHandler("sbqGetCumulativeOccupancyTimeAndFlags", function(_, _, uniqueId, isPrey)
		if not uniqueId then return end
		local cumData = status.statusProperty("sbqCumulativeData") or {}
		if isPrey then
			return { times = (cumData[uniqueId] or {}).prey, flags = (cumData[uniqueId] or {}).flags }
		else
			return { times = (cumData[uniqueId] or {}).pred, flags = (cumData[uniqueId] or {}).flags }
		end
	end)

	message.setHandler("sbqSetCumulativeOccupancyTime",
		function(_, _, uniqueId, name, entityType, typeName, isPrey, data)
			if not uniqueId then return end
			local cumData = status.statusProperty("sbqCumulativeData") or {}
			cumData[uniqueId] = cumData[uniqueId] or {}
			if isPrey then
				cumData[uniqueId].prey = data
			else
				cumData[uniqueId].pred = data
			end
			cumData[uniqueId].name = name
			cumData[uniqueId].type = entityType
			cumData[uniqueId].typeName = typeName
			status.setStatusProperty("sbqCumulativeData", cumData)
		end)

	status.setStatusProperty("sbqCurrentData", nil)
    sbq.setupPublicSettings()

	old.init()

	if type(_npc_setInteractive) ~= "function" then
		_npc_setInteractive = npc.setInteractive
		npc.setInteractive = capture_npc_setInteractive

		_npc_setDamageTeam = npc.setDamageTeam
		npc.setDamageTeam = capture_npc_setDamageTeam

		old_tenant_setNpcType = tenant.setNpcType
		tenant.setNpcType = sbq.tenant_setNpcType

		old.getgenerateRecruitInfo = recruitable.generateRecruitInfo
		recruitable.generateRecruitInfo = sbq.generateRecruitInfo

		old.controlPathMove = mcontroller.controlPathMove
		mcontroller.controlPathMove = sbq.controlPathMove

		old.setPosition = mcontroller.setPosition
		mcontroller.setPosition = sbq.setPosition
	end


	sbq.config = root.assetJson("/sbqGeneral.config")
	status.clearPersistentEffects("digestImmunity")
	status.setPersistentEffects("digestImmunity", { "sbqDigestImmunity" })
	if not status.statusProperty("sbqDidVornyConvertCheck") then
		sbq.maybeConvert()
    end

end

function sbq.maybeConvert()
	status.setStatusProperty("sbqDidVornyConvertCheck", true)
	if config.getParameter("uniqueId") or ((config.getParameter("behaviorConfig") or {}).beamOutWhenNotInUse == true) then
		return
	end
	status.setStatusProperty("sbqDidVornyConvertCheck", true)
	if tenant ~= nil then
		local npcType = sbq.config.vornyConvertTable[npc.npcType()]
		if (math.random(8) == 8) and npcType ~= nil then
			sbq.tenant_setNpcType(npcType)
		end
	end
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)

	old.update(dt)
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
				sbqSettings = storage.settings,
				uniqueId = config.getParameter("preservedUuid") or config.getParameter("uniqueId") or entity.uniqueId(),
				preservedUuid = config.getParameter("preservedUuid") or config.getParameter("uniqueId") or
				entity.uniqueId()
			},
			statusControllerSettings = {
				statusProperties = {
					sbqPreyEnabled = status.statusProperty("sbqPreyEnabled"),
					sbqStoredDigestedPrey = status.statusProperty("sbqStoredDigestedPrey"),
					sbqCumulativeData = status.statusProperty("sbqCumulativeData"),
					speciesAnimOverrideSettings = status.statusProperty("speciesAnimOverrideSettings")
				}
			}
		},
		storage = storage
	}
	world.spawnStagehand(entity.position(), "sbqReplaceNPC", parameters)

	tenant.despawn(false)
end

function sbq.generateRecruitInfo()
	local recruitInfo = old.getgenerateRecruitInfo()
	recruitInfo.config.parameters.scriptConfig.preservedUuid = recruitInfo.uniqueId
	return recruitInfo
end
