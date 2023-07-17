---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field

local oldinit = init
local oldupdate = update
local olduninit = uninit

sbq.currentData = {}
sbq.dialogueBoxOpen = 0
sbq.targetedEntities = {}
sbq.queuedTransitions = {}

dialogueBoxScripts = {}

require("/lib/stardust/json.lua")
require("/interface/scripted/sbq/sbqDialogueBox/sbqDialogueBoxScripts.lua")
require("/scripts/SBQ_species_config.lua")
require("/interface/scripted/sbq/sbqSettings/autoSetSettings.lua")
require("/npcs/tenants/sbq/SBQ_tenant_rewards.lua")
require("/interface/scripted/sbq/sbqDialogueBox/scripts/npc.lua")

local _npc_setItemSlot

function new_npc_setItemSlot(slot, data)
	storage.saveCosmeticSlots[slot] = data
	_npc_setItemSlot(slot, data)
	sbq.updateCosmeticSlots()
end

function getHeldItems()
	local result = {}
	-- table.insert has no effect on the table when given a nil
	table.insert(result, self.primary)
	table.insert(result, self.sheathedPrimary)
	table.insert(result, self.sheathedPrimary2)
	table.insert(result, self.alt)
	table.insert(result, self.sheathedAlt)
	table.insert(result, self.sheathedAlt2)
	return result
end


function preservedStorage()
	return {
		itemSlots = storage.itemSlots,
		relationships = storage.relationships,
		criminal = storage.criminal,
		stolen = storage.stolen,
		extraMerchantItems = storage.extraMerchantItems,
		saveCosmeticSlots = storage.ssaveCosmeticSlots,
		settings = storage.settings
	  }
  end


local _tenant_setHome = tenant.setHome
function tenant.setHome(position, boundary, deedUniqueId, skipNotification)
	if deedUniqueId and not storage.settings.dontSaveToDeed then
		sbq.timer("setHome", 0.5, function ()
			local id = world.loadUniqueEntity(deedUniqueId)
			local index = config.getParameter("tenantIndex")
			if id and world.entityExists(id) and index ~= nil then
				world.sendEntityMessage(id, "sbqSaveSettings", storage.settings or {}, index )
				world.sendEntityMessage(id, "sbqSavePreySettings", status.statusProperty("sbqPreyEnabled") or {}, index)
				world.sendEntityMessage(id, "sbqSaveDigestedPrey", status.statusProperty("sbqStoredDigestedPrey"), index)
				world.sendEntityMessage(id, "sbqSaveStatusProperty", "sbqCumulativeData", status.statusProperty("sbqStoredDigestedPrey"), index)
			end
		end)
	end
	_tenant_setHome(position, boundary, deedUniqueId, skipNotification)
end

function init()
	sbq.config = root.assetJson("/sbqGeneral.config")
	sbq.NPCconfig = root.npcConfig(npc.npcType())

	--status.resetAllResources()

	if type(_npc_setItemSlot) ~= "function" then
		_npc_setItemSlot = npc.setItemSlot
		npc.setItemSlot = new_npc_setItemSlot
	end

	sbq.saveCosmeticSlots()

	oldinit()

	sbq.setSpeciesConfig()
	sbq.occupants = {}
	sbq.occupants.total = 0
	sbq.occupants.totalSize = 0
	for location, data in pairs(sbq.sbqData.locations) do
		sbq.occupants[location] = 0
	end
	sbq.occupants.mass = 0

	if not storage.settings then
		storage.settings = sb.jsonMerge( sb.jsonMerge(sbq.config.defaultSettings, sbq.config.npcDefaultSettings),
			sb.jsonMerge(sbq.speciesConfig.sbqData.defaultSettings or {},
				sb.jsonMerge( config.getParameter("sbqDefaultSettings") or {}, config.getParameter("sbqSettings") or {})
			)
		)
	end
	sbq.preySettings = sb.jsonMerge(sbq.config.defaultPreyEnabled.player,
		sb.jsonMerge(status.statusProperty("sbqPreyEnabled") or {}, config.getParameter("sbqOverridePreyEnabled") or {})
	)
	status.setStatusProperty("sbqPreyEnabled", sbq.preySettings)
	storage.settings = sb.jsonMerge(storage.settings or {}, config.getParameter("sbqOverrideSettings") or {})
	sbq.predatorSettings = storage.settings
	if not storage.settings.firstLoadDone then
		storage.settings.firstLoadDone = true
		sbq.randomizeTenantSettings()
	end

	sbq.setRelevantPredSettings()

	if not self.uniqueId then
		self.uniqueId = sb.makeUuid()
		updateUniqueId()
	end

	sbq.dialogueTree = config.getParameter("dialogueTree")
	sbq.dialogueBoxScripts = config.getParameter("dialogueBoxScripts")

	storage.isHorny = config.getParameter("isHorny")
	storage.isHungry = config.getParameter("isHungry")
	storage.isHungry = config.getParameter("isSleepy")
	storage.persistentTarget = config.getParameter("persistentTarget")

	for _, script in ipairs(sbq.dialogueBoxScripts or {}) do
		require(script)
	end

	message.setHandler("sbqRefreshDialogueBoxData", function (_,_, id, isPrey)
		sbq.talkingWithPrey = (isPrey == "prey")
		if not sbq.talkingWithPrey and type(id) == "number" then
			self.interacted = true
			self.board:setEntity("interactionSource", id)
		end
		sbq.dialogueBoxOpen = 0.5
		return { occupantHolder = sbq.occupantHolder }
	end)
	message.setHandler("sbqSay", function (_,_, string, tags, imagePortrait, emote, appendName)
		sbq.say(string, tags, imagePortrait, emote, appendName)
	end)
	message.setHandler("sbqSetInteracted", function (_,_, id)
		self.interacted = true
		self.board:setEntity("interactionSource", id)
	end)
	message.setHandler("sbqGetSpeciesVoreConfig", function (_,_)
		sbq.setSpeciesConfig()
		return {sbq.speciesConfig, status.statusProperty("animOverrideScale") or 1, status.statusProperty("animOverridesGlobalScaleYOffset") or 0}
	end)
	message.setHandler("sbqSaveSettings", function (_,_, settings, menuName)
		if menuName and menuName ~= "sbqOccupantHolder" then
		else
			storage.settings = settings
			sbq.predatorSettings = storage.settings
			sbq.setRelevantPredSettings()
			if type(sbq.occupantHolder) == "number" and world.entityExists(sbq.occupantHolder) then
				world.sendEntityMessage(sbq.occupantHolder, "settingsMenuSet", storage.settings)
			end
		end
	end)
	message.setHandler("sbqSavePreySettings", function (_,_, settings)
		status.setStatusProperty("sbqPreyEnabled", settings)
		sbq.preySettings = settings
		world.sendEntityMessage(entity.id(), "sbqRefreshDigestImmunities")
	end)
	message.setHandler("sbqSaveAnimOverrideSettings", function (_,_, settings)
		status.setStatusProperty("speciesAnimOverrideSettings", settings)
	end)
	message.setHandler("sbqSayRandomLine", function ( _,_, entity, settings, treestart, getVictimPreySettings )
		if getVictimPreySettings then
			if type(entity) == "number" and world.entityExists(entity) then
				sbq.addRPC(world.sendEntityMessage(entity, "sbqGetPreyEnabled" ), function (sbqPreyEnabled)
					sbq.getRandomDialogue( treestart, entity, sb.jsonMerge(storage.settings, sb.jsonMerge(sbqPreyEnabled or {}, settings or {})) )
				end)
			else
				sbq.getRandomDialogue( treestart, entity, sb.jsonMerge(storage.settings, settings or {}) )
			end
		else
			sbq.getRandomDialogue( treestart, entity, sb.jsonMerge(settings, sb.jsonMerge({personality = storage.settings.personality, mood = storage.settings.mood}, status.statusProperty("sbqPreyEnabled") or {})), nil, true)
		end
	end)
	message.setHandler( "sbqLoadSettings", function(_,_, menuName )
		if menuName then return sb.jsonMerge((config.getParameter("sbqPredatorSettings") or {})[menuName] or {}, storage.settings or {}) end
		return storage.settings
	end)
	message.setHandler("requestTransition", function ( _,_, transition, args)
		sbq.requestTransition(transition, args)
	end)
	message.setHandler("sbqSwapFollowing", function(_, _)
		if storage.behaviorFollowing then
			if world.getProperty("ephemeral") then
				recruitable.confirmUnfollowBehavior()
				return { "None", {} }
			else
				return recruitable.generateUnfollowInteractAction()
			end
		else
			return recruitable.generateFollowInteractAction()
		end
	end)
	message.setHandler("recruit.confirmFollow", function(_,_)
		recruitable.confirmFollow(true)
	end)
	message.setHandler("recruit.confirmUnfollow", function(_,_)
		recruitable.confirmUnfollow(true)
	end)
	message.setHandler("recruit.confirmUnfollowBehavior", function(_,_)
		recruitable.confirmUnfollowBehavior(true)
	end)
	message.setHandler("sbqDigestStore", function(_, _, location, uniqueId, item)
		if (not uniqueId) or (not item) or (not location) then return end
		local item = item
		local digestedStoredTable = status.statusProperty("sbqStoredDigestedPrey") or {}
		digestedStoredTable[location] = digestedStoredTable[location] or {}
		item.count = (item.count or 1) + ((digestedStoredTable[location][uniqueId] or {}).count or 0)
		digestedStoredTable[location][uniqueId] = item
		status.setStatusProperty("sbqStoredDigestedPrey", digestedStoredTable)
		local index = config.getParameter("tenantIndex")
		if recruitable.ownerUuid() then
			world.sendEntityMessage(recruitable.ownerUuid(), "sbqCrewSaveDigestedPrey", digestedStoredTable, entity.uniqueId())
		elseif storage.respawner and index ~= nil then
			world.sendEntityMessage(storage.respawner, "sbqSaveDigestedPrey", digestedStoredTable, index)
		end
	end)
	message.setHandler("sbqSaveDigestedPrey", function(_, _, digestedStoredTable )
		status.setStatusProperty("sbqStoredDigestedPrey", digestedStoredTable)
	end)
	message.setHandler("sbqCheckRewards", function(_, _, occupant)
		local rewards = config.getParameter("sbqPredRewards") or {}
		sbq.checkOccupantRewards(occupant, sbq.checkSpeciesRootTable(rewards), false, occupant.id, sbq.occupantHolder)
	end)
	message.setHandler("sbqCheckPreyRewards", function(_, _, occupant, recipient, holder)
		local rewards = config.getParameter("sbqPreyRewards") or {}
		sbq.checkOccupantRewards(occupant, sbq.checkSpeciesRootTable(rewards), false, recipient, holder)
	end)

	message.setHandler("sbqSteppy", function(_, _, eid, steppyType, steppySize)
		local size = sbq.calcSize()
		if size <= (steppySize*0.4) then
			world.sendEntityMessage(eid, "sbqDidSteppy", entity.id(), steppyType)
			if steppyType == "falling" then
				if sbq.timer("sbqSteppyFall", 0.5) then
					sbq.getRandomDialogue(".gotSteppy", eid, sb.jsonMerge(storage.settings, { steppyType = steppyType }))
					if config.getParameter("likesSteppy") then
						status.giveResource("horny",5)
					end
				end
			elseif sbq.timer("sbqSteppy", 5) then
				sbq.getRandomDialogue(".gotSteppy", eid, sb.jsonMerge(storage.settings, { steppyType = steppyType }))
				if config.getParameter("likesSteppy") then
					status.giveResource("horny",5)
				end
			end
		end
	end)
	message.setHandler("sbqDidSteppy", function(_, _, eid, steppyType)
		if sbq.timer("sbqDidSteppy", 5) then
			sbq.getRandomDialogue( ".didSteppy", eid, sb.jsonMerge(storage.settings, {steppyType = steppyType}) )
		end
	end)
	message.setHandler("sbqReplaceInfusion", function(_, _, location, itemDrop, preyId, primaryLocation)

		local alreadyInfused = storage.settings[location .. "InfusedItem"]
		world.sendEntityMessage(entity.id(), "sbqDigestStore", location, (((((alreadyInfused or {}).parameters or {}).npcArgs or {}).npcParam or {}).scriptConfig or {}).uniqueId, alreadyInfused)
		storage.settings[location .. "InfusedItem"] = itemDrop

		sbq.saveSettingsToDeed()

		local current = status.statusProperty("sbqCurrentData") or {}
		if current and type(current.id) == "number" and world.entityExists(current.id) then
			world.sendEntityMessage(current.id, "setInfusedCharacter", location, storage.settings[location.."InfusedItem"], preyId, primaryLocation )
		end
	end)

	message.setHandler("changeBack", function(_, _, uniqueId, locations)
		if not uniqueId then return end
		if not locations then
			for location, data in pairs(sbq.sbqData.locations) do
				local uuid = (((((storage.settings[location .. "InfusedItem"] or {}).parameters or {}).npcArgs or {}).npcParam or {}).scriptConfig or {}).uniqueId
				if uuid == uniqueId then
					storage.settings[location .. "InfusedItem"] = nil
				end
			end
		else
			for i, location in ipairs(locations) do
				local uuid = (((((storage.settings[location .. "InfusedItem"] or {}).parameters or {}).npcArgs or {}).npcParam or {}).scriptConfig or {}).uniqueId
				if uuid == uniqueId then
					storage.settings[location .. "InfusedItem"] = nil
				end
			end
		end
		sbq.saveSettingsToDeed()
		sbq.saveSettingsToOccupantHolder()
	end)

	message.setHandler("getEntitySettingsMenuData", function(_, _, uniqueId)
		local owner = recruitable.ownerUuid()
		local occupier = {
			tenants = {
				{
					type = npc.npcType(),
					species = npc.species(),
					uniqueId = entity.uniqueId(),
					overrides = {
						identity = npc.humanoidIdentity(),
						scriptConfig = {
							sbqSettings = sbq.predatorSettings,
							tenantBio = config.getParameter("tenantBio")
						},
						statusControllerSettings = {
							statusProperties = {
								sbqPreyEnabled = status.statusProperty("sbqPreyEnabled"),
								sbqStoredDigestedPrey = status.statusProperty("sbqStoredDigestedPrey"),
								speciesAnimOverrideSettings = status.statusProperty("speciesAnimOverrideSettings"),
								animOverrideScale = status.statusProperty("animOverrideScale")
							}
						}
					}
				}
			}
		}
		if owner then
			if owner == uniqueId then
				return {
					ui = "starbecue:voreCrewMenu"
				}
			end
		elseif storage.respawner then
			return {
				ui = "starbecue:voreColonyDeed",
				respawner = storage.respawner,
				forcedIndex = config.getParameter("tenantIndex"),
				occupier = occupier
			}
		else
			return {
				ui = "starbecue:voreColonyDeed",
				detached = true,
				occupier = occupier
			}
		end
	end)

	message.setHandler("sbqSetCumulativeOccupancyTime", function(_, _, uniqueId, name, entityType, typeName, isPrey, data)
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

		if recruitable.ownerUuid() then
			world.sendEntityMessage(recruitable.ownerUuid(), "sbqCrewSaveStatusProperty", "sbqCumulativeData", cumData, entity.uniqueId())
		elseif storage.respawner and index ~= nil then
			world.sendEntityMessage(storage.respawner, "sbqSaveStatusProperty", "sbqCumulativeData", cumData, index)
		end
	end)

	message.setHandler("sbqIsPredEnabled", function(_,_, voreType)
		local settings = storage.settings or {}
		local type = status.statusProperty("sbqType")
		return {enabled = settings[voreType.."Pred"], unwilling = settings[voreType.."PredUnwilling"] and settings.forcefulPrey, size = sbq.calcSize(), type = type}
	end)
	message.setHandler("sbqCheckAssociatedEffects", function(_, _, voreType)
		local settings = storage.settings
		local effects = {}
		local data = sbq.speciesConfig.sbqData.voreTypeData[voreType]
		local transition = (((sbq.speciesConfig.states or {})[sbq.state or "stand"] or {}).transitions or {})[voreType]
		if not transition then return end
		if not sbq.checkSettings(transition.settings, settings) then return end
		for i, location in ipairs( data.locations ) do
			table.insert(effects, settings[location.."EffectSlot"])
		end
		return effects
	end)
	message.setHandler("sbqNPCGetConsent", function(_, _, eid, data)
		local predOrPrey = sbq.getPredOrPrey()
		if predOrPrey == data.predOrPrey then
			if not ((data.predOrPrey == "pred" and storage.settings[data.voreType .. "PreyAlwaysAccept"])
			or ((data.predOrPrey == "prey" and storage.settings[data.voreType .. "PredAlwaysAccept"]))) then
				return 2 -- the "No." option
			end
		end
		if ((data.predOrPrey == "pred" and storage.settings[data.voreType .. "PreyAlwaysSeemUnwilling"])
		or ((data.predOrPrey == "prey" and storage.settings[data.voreType .. "PredAlwaysSeemUnwilling"]))) then
			return 3 -- the "No... (But actually yes)" option
		end
		local favoredVoreTypes = sbq.getFavoredVoreTypes(predOrPrey)
		for i = 1, 5 do
			if favoredVoreTypes[math.random(#favoredVoreTypes)] == data.voreType then
				return 1 -- the "Yes!" option
			end
		end
		return 3 -- the "No... (But actually yes)" option
	end)
	message.setHandler("sbqIsPreyEnabled", function(_,_, voreType)
		local preySettings = sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))
		if preySettings.preyEnabled == false then return false end
		local enabled = true
		if type(voreType) == "table" then
			for i, voreType in ipairs(voreType) do
				enabled = enabled and preySettings[voreType]
				if not enabled then break end
			end
		else
			enabled = preySettings[voreType]
		end
		local willing = false
		if enabled then
			if type(voreType) == "table" then
				willing = sbq.getPreyWilling(voreType)
			else
				willing = sbq.getPreyWilling({voreType})
			end
		end
		local type = status.statusProperty("sbqType")
		return { willing = willing,  enabled = enabled, size = sbq.calcSize(), preyList = status.statusProperty("sbqPreyList"), type = type}
	end)
end

function sbq.getPreyWilling(voreTypes)
	local favoredVoreTypes = sbq.getFavoredVoreTypes("prey", preySettings, healOrDigest)
	if not favoredVoreTypes[1] then return false end
	local favoredSelection = {
		favoredVoreTypes[math.random(#favoredVoreTypes)],
		favoredVoreTypes[math.random(#favoredVoreTypes)],
		favoredVoreTypes[math.random(#favoredVoreTypes)],
		favoredVoreTypes[math.random(#favoredVoreTypes)]
	}
	for i, voreType in ipairs(voreTypes) do
		for j, voreType2 in ipairs(favoredSelection) do
			if voreType == voreType2 then return true end
		end
	end
	return false
end

function sbq.requestTransition(transition, args)
	if not sbq.occupantHolder then
		sbq.occupantHolder = world.spawnVehicle( "sbqOccupantHolder", mcontroller.position(), { driver = entity.id(), settings = storage.settings, doExpandAnim = true } )
	end
	table.insert(sbq.queuedTransitions, {transition, args})
end

function sbq.setSpeciesConfig()
	sbq.getSpeciesConfig(npc.species(), storage.settings)
	sbq.predatorConfig = sbq.speciesConfig.sbqData
	sbq.sbqData = sbq.predatorConfig
	sbq.initLocationSizes()
	status.setStatusProperty("sbqOverridePreyEnabled", sbq.speciesConfig.sbqData.overridePreyEnabled)
	local speciesAnimOverrideData = status.statusProperty("speciesAnimOverrideData") or {}
	local effects = status.getPersistentEffects("speciesAnimOverride")
	if not effects[1] then
		status.setPersistentEffects("speciesAnimOverride", { speciesAnimOverrideData.customAnimStatus or "speciesAnimOverride" })
	end
	status.clearPersistentEffects("digestImmunity")
	status.setPersistentEffects("digestImmunity", {"sbqDigestImmunity"})
end

function sbq.initLocationSizes()
	for location, data in pairs(sbq.sbqData.locations) do
		if data.sided then
			sbq.sbqData.locations[location.."L"] = sbq.sbqData.locations[location.."L"] or {}
			sbq.sbqData.locations[location.."R"] = sbq.sbqData.locations[location.."R"] or {}
			for name, copy in pairs(data) do
				if name ~= "combine" and name ~= "sided" then
					sbq.sbqData.locations[location.."L"][name] = sbq.sbqData.locations[location.."L"][name] or copy
					sbq.sbqData.locations[location.."R"][name] = sbq.sbqData.locations[location.."R"][name] or copy
				end
			end
			sbq.sbqData.locations[location .. "L"].side = sbq.sbqData.locations[location .. "L"].side or "L"
			sbq.sbqData.locations[location .. "R"].side = sbq.sbqData.locations[location .. "R"].side or "R"
		end
	end
end


function update(dt)
	sbq.currentData = status.statusProperty("sbqCurrentData") or {}

	sbq.occupantHolder = sbq.currentData.id
	sbq.loopedMessage("checkRefresh", sbq.occupantHolder, "getOccupancyData", {}, function (result)
		if result ~= nil then
			sbq.occupants = result.occupants
			sbq.occupant = result.occupant
		end
	end)
	sbq.timer("rewardCheck", 30, function()
		local rewards = config.getParameter("sbqPredRewards") or {}
		for i, occupant in pairs(sbq.occupant or {}) do
			sbq.checkOccupantRewards(occupant, sbq.checkSpeciesRootTable(rewards), false)
		end
	end)
	sbq.randomTimer("hunting", 15, 60, function () -- get a new hunting target every 15 to 60 seconds
		sbq.getTarget()
	end)
	sbq.timer("clothes", 5, sbq.updateCosmeticSlots)

	if type(sbq.occupantHolder) == "number" and world.entityExists(sbq.occupantHolder) then
		for _, transition in ipairs(sbq.queuedTransitions) do
			world.sendEntityMessage(sbq.occupantHolder, "requestTransition", transition[1], transition[2])
		end
		sbq.queuedTransitions = {}
	end

	sbq.dialogueBoxOpen = math.max(0, sbq.dialogueBoxOpen - dt)

	sbq.passiveStatChanges(dt)

	oldupdate(dt)
end

function uninit()
	olduninit()
end

function sbq.getDialogueBoxData()
	local overrideData = status.statusProperty("speciesAnimOverrideData") or {}
	local dialogueBoxData = {
		speciesConfig = sbq.speciesConfig,
		dialogueBoxScripts = sbq.dialogueBoxScripts,
		settings = sb.jsonMerge(storage.settings, status.statusProperty("sbqPreyEnabled") or {} ),
		dialogueTree = sbq.dialogueTree,
		icons = config.getParameter("voreIcons"),
		iconDirectives = (config.getParameter("iconDirectives") or "")..(overrideData.directives or ""),
		entityPortrait = config.getParameter("entityPortrait"),
		defaultPortrait = config.getParameter("defaultPortrait"),
		portraitPath = config.getParameter("portraitPath"),
		defaultName = config.getParameter("defaultName"),
		occupantHolder = sbq.occupantHolder,
		scale = status.statusProperty("animOverrideScale")
	}
	dialogueBoxData.settings.race = npc.species()
	dialogueBoxData.settings.ownerUuid = recruitable.ownerUuid()
	dialogueBoxData.settings.isFollowing = recruitable.isFollowing()
	dialogueBoxData.settings.horny = status.resourcePercentage("horny")
	dialogueBoxData.settings.food = status.resourcePercentage("food")
	dialogueBoxData.settings.energy = status.resourcePercentage("energy")

	return dialogueBoxData
end

function interact(args)
	if recruitable.isRecruitable() then
		return recruitable.generateRecruitInteractAction()
	end

	local dialogueBoxData = sbq.getDialogueBoxData()

	if status.statusProperty("sbqType") == "prey" then
		if args.predData then
			sbq.predData = args.predData
			local settings = args.predData.settings
			settings.location = args.predData.location
			settings.predator = args.predData.predator
			settings.isPrey = true

			settings.personality = storage.settings.personality
			settings.mood = storage.settings.mood

			dialogueBoxData.settings = sb.jsonMerge(dialogueBoxData.settings, settings)
			dialogueBoxData.dialogueTreeStart = ".struggling"
			return {"ScriptPane", { data = dialogueBoxData, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:dialogueBox" }}
		else
			return
		end
	else
		local location = sbq.getOccupantArg(args.sourceId, "location")
		if location ~= nil then
			local flags = sbq.getOccupantArg(args.sourceId, "flags") or {}
			dialogueBoxData.dialogueTreeStart = ".struggle"
			dialogueBoxData.settings.location = location
			dialogueBoxData.settings.playerPrey = true
			if flags.infused then
				dialogueBoxData.settings.predator = npc.species()
				dialogueBoxData.dialogueTreeStart = ".infusedTease"
			end
		end
		return {"ScriptPane", { data = dialogueBoxData, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:dialogueBox" }}
	end
end

function sbq.passiveStatChanges(dt)
	if (storage.isHorny ~= false) then
		local hornyPercent = status.resourcePercentage("horny")
		if hornyPercent < status.stat("hornyPassiveLimit") then
			status.modifyResource("horny", status.stat("hornyDelta") * dt * status.resourcePercentage("food"))
		end
		if hornyPercent >= 1 then
			if sbq.timer("hornyReset", 5, function ()
				status.resetResource("horny")
			end) then
				if sbq.occupant then
					local entitys = {}
					local players = {}
					for i, occupant in pairs(sbq.occupant) do
						local location = occupant.location
						local locationData = sbq.predatorConfig.locations[location]
						for _, satisfy in ipairs((locationData or {}).satisfiesPred or {}) do
							if satisfy == "horny" then
								world.sendEntityMessage(sbq.occupantHolder, "causedClimax", occupant.id)
								if world.entityType(occupant.id) == "player" then
									table.insert(players, { occupant.id, location })
								else
									table.insert(entitys, { occupant.id, location })
								end
							end
						end
					end
					local chosen
					if players[1] then
						chosen = players[math.random(#players)]
					elseif entitys[1] then
						chosen = entitys[math.random(#entitys)]
					end

					local settings = { predOrPrey = "pred", location = chosen[2] }
					sbq.getRandomDialogue(".climax", chosen[1], sb.jsonMerge(storage.settings, settings))
				end
			end
		end
	end
	if (storage.isSleepy ~= false) then
		if npc.loungingIn() ~= nil then
			status.modifyResource("rest", status.stat("restDelta") * dt * (4 * status.resourcePercentage("health")))
		else
			status.modifyResource("rest", status.stat("restDelta") * dt * (2 - status.resourcePercentage("health")))
		end
	end
end

function sbq.logInfo(input)
	sb.logInfo("["..world.entityName(entity.id()).."]".. input)
end

function sbq.doTargetAction()
	if npc.loungingIn() ~= nil then
		storage.huntingTarget = nil
		self.board:setEntity("sbqHuntingTarget", nil)
		sbq.targetedEntities = {}
		return
	end
	sbq.logInfo("Trying action: " .. sb.printJson(storage.huntingTarget))
	if storage.huntingTarget then
		if storage.huntingTarget.combat then
			if storage.huntingTarget.predOrPrey == "pred" then
				sbq.combatEat()
			end
		else
			if not sbq.timer("targetReachedCooldown", 5) then return end
			if storage.huntingTarget.predOrPrey == "pred" then
				if storage.huntingTarget.getConsent then
					sbq.askToVore()
				else
					sbq.eatUnprompted()
				end
			elseif storage.huntingTarget.predOrPrey == "prey" then
				if storage.huntingTarget.getConsent then
					sbq.askToBeVored()
				else
					sbq.forcePrey()
				end
			end
		end
	end
end

function sbq.askToVore()
	entityType = world.entityType(storage.huntingTarget.id)
	if entityType == "player" then
		if sbq.timer("leaveUnresponsivePlayer", 30, function ()
			sbq.getNextTarget()
		end) then
			local dialogueBoxData = sbq.getDialogueBoxData()
			dialogueBoxData.dialogueTreeStart = ".vore"
			dialogueBoxData.settings = sb.jsonMerge(dialogueBoxData.settings, {
				voreType = storage.huntingTarget.voreType,
				voreResponse = "selfRequest"
			})
			world.sendEntityMessage(storage.huntingTarget.id, "sbqOpenMetagui", "starbecue:dialogueBox", entity.id(), dialogueBoxData )
		end
	elseif entityType == "npc" then
		local settings = sb.jsonMerge(storage.settings, {
			voreType = storage.huntingTarget.voreType,
			voreResponse = "selfRequest"
		})
		sbq.getRandomDialogue(".vore", storage.huntingTarget.id, settings)
		sbq.addNamedRPC("sbqNPCGetConsent",
			world.sendEntityMessage(storage.huntingTarget.id, "sbqNPCGetConsent", entity.id(), storage.huntingTarget),
			function(result)
				if result == 1 then
					settings.willing = true
				end
				sbq.getRandomDialogue(dialogue.result.options[result][2], storage.huntingTarget.id, settings)
				if result == 2 then -- "No."
					sbq.getNextTarget()
				end
			end)
	elseif entityType == "monster" then
		sbq.eatUnprompted()
	end
end

function sbq.askToBeVored()
	entityType = world.entityType(storage.huntingTarget.id)
	if entityType == "player" then
		if sbq.timer("leaveUnresponsivePlayer", 30, function ()
			sbq.getNextTarget()
		end) then
			local dialogueBoxData = sbq.getDialogueBoxData()
			dialogueBoxData.dialogueTreeStart = ".preyRequest"
			dialogueBoxData.settings = sb.jsonMerge(dialogueBoxData.settings, {
				voreType = storage.huntingTarget.voreType,
			})
			world.sendEntityMessage(storage.huntingTarget.id, "sbqOpenMetagui", "starbecue:dialogueBox", entity.id(), dialogueBoxData )
		end
	elseif entityType == "npc" then
		local settings = sb.jsonMerge(storage.settings, {
			voreType = storage.huntingTarget.voreType,
		})
		sbq.getRandomDialogue(".preyRequest", storage.huntingTarget.id, settings)

		sbq.addNamedRPC("sbqNPCGetConsent",
			world.sendEntityMessage(storage.huntingTarget.id, "sbqNPCGetConsent", entity.id(), storage.huntingTarget),
			function(result)
				if result == 1 then
					settings.willing = true
				end
				sbq.getRandomDialogue(dialogue.result.options[result][2], storage.huntingTarget.id, settings)
				if result == 2 then -- "No."
					sbq.getNextTarget()
				end
			end)
	elseif entityType == "monster" then
		sbq.forcePrey()
	end
end

function sbq.combatSwitchHuntingTarget(newTarget)
	if sbq.timer("combatSwitchHuntingTarget", 10) then
		sbq.searchForHealTarget(true)
		storage.huntingTarget = nil
		sbq.targetedEntities = {}
		sbq.addRPC(world.sendEntityMessage(newTarget, "sbqGetPreyEnabled"), function(preySettings)
			if (not preySettings) or (preySettings.preyEnabled == false) then return end
			local voreType = sbq.getCurrentVorePref("pred", preySettings, storage.settings.preferDigestHostiles and "digest" )
			if not voreType then return end
			local ext = sbq.getTargetExt(newTarget)
			local aggressive = world.entityAggressive(newTarget)
			local validTarget = false
			if aggressive and storage.settings[voreType .. "HuntHostile" .. ext] then
				validTarget = true
			end
			if not validTarget then return end
			storage.huntingTarget = {
				index = 1,
				id = newTarget,
				voreType = voreType,
				predOrPrey = "pred",
				combat = true,
			}
			self.board:setEntity("sbqHuntingTarget", newTarget)
		end)
	end
end

function sbq.searchForHealTarget(combat)
	if not storage.settings.preferHealFriendlies then return false end
	local entities = world.entityQuery(mcontroller.position(), 25, {
		withoutEntityId = entity.id(), includedTypes = {"creature"}
	})
	for i, newTarget in ipairs(entities) do
		if not world.entityAggressive(newTarget) then
			local health = world.entityHealth(newTarget)
			if health then
				local percent = health[1] / health[2]
				if percent < 0.25 then
					sbq.addRPC(world.sendEntityMessage(newTarget, "sbqGetPreyEnabled"), function(preySettings)
						if (not preySettings) or (preySettings.preyEnabled == false) then return end
						local voreType = sbq.getCurrentVorePref("pred", preySettings, storage.settings.preferHealFriendlies and "heal")
						if not voreType then return end
						local ext = sbq.getTargetExt(newTarget)
						local validTarget = false
						if storage.settings[voreType .. "HuntFriendly"..ext] then
							validTarget = true
						end
						if not validTarget then return end
						storage.huntingTarget = {
							index = 1,
							id = newTarget,
							voreType = voreType,
							predOrPrey = "pred",
							combat = combat,
						}
						self.board:setEntity("sbqHuntingTarget", newTarget)
					end)
				end
			end
		end
	end
end


function sbq.getTargetExt(target)
	local entityType = world.entityType(target)
	if entityType == "npc" then
		if world.callScriptedEntity(target, "config.getParameter", "isOC" ) then
			return "OCs"
		end
		if world.callScriptedEntity(target, "config.getParameter", "sbqNPC" ) then
			return "SBQNPCs"
		end
	elseif entityType == "player" then
		return "Players"
	end
	return "Other"
end

function sbq.combatEat()
	local settings = {
		voreType = storage.huntingTarget.voreType,
		voreResponse = "unprompted",
		location = sbq.predatorConfig.voreTypes[storage.huntingTarget.voreType],
		doingVore = "before"
	}
	sbq.requestTransition(storage.huntingTarget.voreType,
		{ id = storage.huntingTarget.id, hostile = world.entityAggressive(storage.huntingTarget.id) })

	sbq.forceTimer("gotVored", delay or 1.5, function()
		if not storage.huntingTarget then return end
		settings.doingVore = "after"
		if sbq.checkOccupant(storage.huntingTarget.id) then
			sbq.getRandomDialogue(".vore", storage.huntingTarget.id, sb.jsonMerge(storage.settings, sb.jsonMerge(sbqPreyEnabled or {}, settings)))
			storage.huntingTarget = nil
			self.board:setEntity("sbqHuntingTarget", nil)
		end
	end)
end

function sbq.eatUnprompted()
	sbq.addNamedRPC("attemptingToEat", world.sendEntityMessage(storage.huntingTarget.id, "sbqGetPreyEnabled"), function(sbqPreyEnabled)
		if sbqPreyEnabled[storage.huntingTarget.voreType] and (sbqPreyEnabled.type ~= "prey")then
			local settings = {
				voreType = storage.huntingTarget.voreType,
				voreResponse = "unprompted",
				location = sbq.predatorConfig.voreTypes[storage.huntingTarget.voreType],
				doingVore = "before"
			}
			sbq.getRandomDialogue(".vore", storage.huntingTarget.id, sb.jsonMerge(storage.settings, sb.jsonMerge(sbqPreyEnabled or {}, settings)))
			local delay = dialogue.result.delay
			sbq.timer("eatMessage", delay or 1.5, function()
				if not storage.huntingTarget then sbq.getNextTarget() return end
				self.board:setEntity("sbqHuntingTarget", nil)
				sbq.requestTransition(storage.huntingTarget.voreType, { id = storage.huntingTarget.id })
				sbq.timer("gotVored", delay or 1.5, function()
					if not storage.huntingTarget then sbq.getNextTarget() return end
					settings.doingVore = "after"
					if sbq.checkOccupant(storage.huntingTarget.id) then
						sbq.getRandomDialogue(".vore", storage.huntingTarget.id, sb.jsonMerge(storage.settings, sb.jsonMerge(sbqPreyEnabled or {}, settings)))
						storage.huntingTarget = nil
						sbq.targetedEntities = {}
					else
						settings.voreResponse = "couldnt"
						sbq.getRandomDialogue(".vore", storage.huntingTarget.id, sb.jsonMerge(storage.settings, sb.jsonMerge(sbqPreyEnabled or {}, settings)))
						self.board:setEntity("sbqHuntingTarget", storage.huntingTarget.id)
					end
				end)
			end)
		else
			sbq.getNextTarget()
		end
	end)
end

function sbq.forcePrey()
	sbq.getRandomDialogue(".forcingPrey", storage.huntingTarget.id, storage.settings)
	sbq.timer("forcedPreyDialogue", dialogue.result.delay or 1.5, function ()
		world.sendEntityMessage(storage.huntingTarget.id, "requestTransition", storage.huntingTarget.voreType, { id = entity.id(), willing = true })
		sbq.timer("forcedPreyCheckInside", 1, function ()
			if status.statusProperty("sbqType") == "prey" then
				world.sendEntityMessage(storage.huntingTarget.id, "sbqSayRandomLine", entity.id(), {voreType = storage.huntingTarget.voreType}, ".unwillingPred")
			else
				sbq.getNextTarget()
			end
		end)
	end)
end

function sbq.getLocationSetting(location, setting, default)
	return storage.settings[location..setting] or storage.settings["default"..setting] or default
end

function sbq.locationSpaceAvailable(location, side)
	if sbq.getLocationSetting(location, "Hammerspace") and sbq.sbqData.locations[location].hammerspace then
		return math.huge
	end
	return (((sbq.sbqData.locations[location..(side or "")] or {}).max or 0) * ((status.statusProperty("animOverrideScale") or 1))) - (sbq.occupants[location..(side or "")] or 0)
end

function sbq.getSidedLocationWithSpace(location, size)
	local data = sbq.sbqData.locations[location] or {}
	local sizeMultiplied = ((size or 1) * (sbq.getLocationSetting(location, "Multiplier", 1) ))
	if data.sided then
		local leftHasSpace = sbq.locationSpaceAvailable(location, "L") > sizeMultiplied
		local rightHasSpace = sbq.locationSpaceAvailable(location, "R") > sizeMultiplied
		if sbq.occupants[location.."L"] == sbq.occupants[location.."R"] then
			if mcontroller.facingDirection() > 0 then -- thinking about it, after adding everything underneath to prioritize the one with less prey, this is kinda useless
				if leftHasSpace then return location, "L", data
				elseif rightHasSpace then return location, "R", data
				else return false end
			else
				if rightHasSpace then return location, "R", data
				elseif leftHasSpace then return location, "L", data
				else return false end
			end
		elseif sbq.occupants[location .. "L"] < sbq.occupants[location .. "R"] and leftHasSpace then return location, "L", data
		elseif sbq.occupants[location .. "L"] > sbq.occupants[location .. "R"] and rightHasSpace then return location, "R", data
		else return false end
	else
		if sbq.locationSpaceAvailable(location, "") > sizeMultiplied then
			return location, "", data
		end
	end
	return false
end

function sbq.getTarget()
	if npc.loungingIn() ~= nil then
		storage.huntingTarget = nil
		self.board:setEntity("sbqHuntingTarget", nil)
		return
	end
	sbq.searchForHealTarget(false)
	if storage.huntingTarget and type(storage.huntingTarget.id) == "number" and world.entityExists(storage.huntingTarget.id) then
		if storage.persistentTarget and entity.entityInSight(storage.huntingTarget.id) then
			sbq.addRPC(world.sendEntityMessage(storage.huntingTarget.id, "sbqIsPreyEnabled", storage.huntingTarget.voreType), function (enabled)
				if enabled and enabled.enabled and enabled.type ~= "prey" and enabled.size
				and sbq.getSidedLocationWithSpace(sbq.predatorConfig.voreTypes[storage.huntingTarget.voreType], enabled.size)
				then
					self.board:setEntity("sbqHuntingTarget", storage.huntingTarget.id)
				else
					sbq.getNextTarget()
				end
			end)
			return
		end
		if math.random() > 0.5 then
			sbq.getNextTarget()
		end
	elseif storage.huntingTarget then
		sbq.getNextTarget()
	elseif (math.random() > 0.5) then
		local voreType, predOrPrey = sbq.getCurrentVorePref()
		if not voreType then return end
		local consent = sbq.huntingAskConsent()
		if predOrPrey == "pred" then
			sbq.searchForValidPrey(voreType, consent)
		elseif predOrPrey == "prey" then
			sbq.searchForValidPred(voreType, consent)
		end
		sbq.timer("targeting", 1, function()
			table.sort(sbq.targetedEntities, function(a, b)
				return a[2] < b[2]
			end)
			if sbq.targetedEntities[1] then
				storage.huntingTarget = {
					index = 1,
					id = sbq.targetedEntities[1][1],
					voreType = voreType,
					predOrPrey = predOrPrey,
					getConsent = consent
				}
				self.board:setEntity("sbqHuntingTarget", sbq.targetedEntities[1][1])
			end
		end)
	end
end

function sbq.getNextTarget()
	if not sbq.targetedEntities then storage.huntingTarget = nil return end
	if storage.huntingTarget then
		local newTarget = {
			index = storage.huntingTarget.index + 1,
			id = (sbq.targetedEntities[storage.huntingTarget.index+1] or {})[1],
		}
		if newTarget.id ~= nil then
			storage.huntingTarget = sb.jsonMerge(storage.huntingTarget, newTarget)
		else
			storage.huntingTarget = nil
			self.board:setEntity("sbqHuntingTarget", nil)
		end
	end
end

function sbq.huntingAskConsent()
	if storage.huntingTarget then
		local consentVal
		if storage.huntingTarget.predOrPrey == "pred" then
			consentVal = storage.settings[storage.huntingTarget.voreType .. "ConsentPred"] or 0.5
		elseif storage.huntingTarget.predOrPrey == "prey" then
			consentVal = storage.settings[storage.huntingTarget.voreType .. "ConsentPrey"] or 0.5
		end
		if consentVal == 1 then return true end
		if consentVal == 0 then return false end
		return consentVal < math.random()
	end
end

function sbq.getFavoredVoreTypes(predOrPrey, preySettings, effectSlot)
	local favoredVoreTypes = {}
	for voreType, data in pairs(sbq.speciesConfig.sbqData.voreTypeData or {}) do
		if predOrPrey == "pred" and sbq.predatorSettings[voreType .. "Pred"]
			and (((sbq.speciesConfig.states or {})[sbq.state or "stand"] or {}).transitions or {})[voreType]
			and sbq.checkSettings((((sbq.speciesConfig.states or {})[sbq.state or "stand"] or {}).transitions or {})[voreType].settings, storage.settings)
		then
			local addType = true
			if preySettings then
				addType = preySettings[voreType]
			end
			if effectSlot then
				addType = false
				for i, location in ipairs(data.locations) do
					if storage.settings[location.."EffectSlot"] == effectSlot then
						addType = true break
					end
					if (effectSlot == "digest") and (storage.settings[location.."EffectSlot"] == "softDigest") and storage.settings.overrideSoftDigestForHostiles then
						addType = true break
					end
				end
			end
			if addType then
				for i = 1, (sbq.predatorSettings[voreType .. "PreferredPred"] or 5) do
					table.insert(favoredVoreTypes, voreType)
				end
			end
		elseif predOrPrey == "prey" and sbq.preySettings[voreType] then
			for i = 1, (sbq.predatorSettings[voreType .. "PreferredPrey"] or 5) do
				table.insert(favoredVoreTypes, voreType)
			end
		end
	end
	return favoredVoreTypes
end

function sbq.getCurrentVorePref(predOrPrey, preySettings, healOrDigest)
	local predOrPrey = predOrPrey or sbq.getPredOrPrey() -- commented out so it only rolls pred for now for testing
	if not predOrPrey then return end
	local favoredVoreTypes = sbq.getFavoredVoreTypes(predOrPrey, preySettings, healOrDigest)
	if not favoredVoreTypes[1] then return end
	local favoredSelection = {
		{ favoredVoreTypes[math.random(#favoredVoreTypes)] },
		{ favoredVoreTypes[math.random(#favoredVoreTypes)] },
		{ favoredVoreTypes[math.random(#favoredVoreTypes)] },
		{ favoredVoreTypes[math.random(#favoredVoreTypes)] }
	}
	for i, selection in ipairs(favoredSelection) do
		local voreType = selection[1]
		local data = sbq.config.generalVoreTypeData[voreType] or {}
		local satisfyTable = {}
		if predOrPrey == "prey" then
			satisfyTable = data.satisfiesPrey
		elseif predOrPrey == "pred" then
			satisfyTable = data.satisfiesPred
		end
		for j, satisfy in ipairs(satisfyTable or {}) do
			if sbq.satisfyInverse[satisfy] then
				favoredSelection[i][2] = (favoredSelection[i][2] or 0) + (1 - status.resourcePercentage(satisfy))
			else
				favoredSelection[i][2] = (favoredSelection[i][2] or 0) + (status.resourcePercentage(satisfy))
			end
		end
	end
	table.sort(favoredSelection, function (a, b)
		return a[2] > b[2]
	end)

	return favoredSelection[1][1], predOrPrey
end
sbq.satisfyInverse = {
	health = true,
	food = true,
	rest = true,
}


local negative = { 1, -1 }
local function getPositiveNegativeFloat()
	return math.random() * negative[math.random(#negative)]
end
function sbq.getClosestValue(x, list)
	local closest
	local closestKey
	local closestDiff = math.huge
	for k, v in ipairs(list) do
		diff = math.abs(v - x)
		if diff <= closestDiff then
			closestDiff = diff
			closest = v
			closestKey = k
		end
	end
	return closest, closestKey
end

function sbq.getPredOrPrey()
	local bias = 0
	if storage.isHungry ~= false then
		bias = bias + ((1 - status.resourcePercentage("food")) * 0.5)
	end
	if storage.isSleepy ~= false then
		bias = bias + ((1 - status.resourcePercentage("rest")) * 0.5)
	end
	local result = math.max(sbq.predatorSettings.predPreyLeanMin or -1, math.min(sbq.predatorSettings.predPreyLeanMax or 1, (bias or 0) + sbq.getClosestValue(sbq.predatorSettings.predPreyLean or 0, {
		getPositiveNegativeFloat(),
		getPositiveNegativeFloat(),
		getPositiveNegativeFloat(),
		getPositiveNegativeFloat(),
		getPositiveNegativeFloat()
	})))

	if (result >= 0) and (sbq.occupants.total or 0) < 8 then return "pred" end
	if result < 0 then return "prey" end
end

function sbq.checkOccupant(id)
	if sbq.occupant == nil then return end
	for i, occupant in pairs(sbq.occupant) do
		if occupant.id == id then
			return true
		end
	end
end


function sbq.getOccupantArg(id, arg)
	if sbq.occupant == nil then return end
	for i, occupant in pairs(sbq.occupant) do
		if occupant.id == id then
			return occupant[arg]
		end
	end
end

function sbq.saveSettingsToDeed()
	local index = config.getParameter("tenantIndex")
	if storage.respawner and index ~= nil then
		world.sendEntityMessage(storage.respawner, "sbqSaveSettings", storage.settings or {}, index)
	end
	if recruitable.ownerUuid() then
		world.sendEntityMessage(recruitable.ownerUuid(), "sbqCrewSaveSettings", storage.settings or {}, entity.uniqueId())
	end
end
function sbq.saveSettingsToOccupantHolder()
	if type(sbq.occupantHolder) == "number" and world.entityExists(sbq.occupantHolder) then
		world.sendEntityMessage(sbq.occupantHolder, "settingsMenuSet", storage.settings)
	end
end

local randomDialogueHandling = {
	{ "randomDialogue", "dialogue" },
	--{ "randomPortrait", "portrait" },
	{ "randomEmote", "emote" },
}

function sbq.getRandomDialogue(path, eid, settings, dialogueTree, appendName, dialogueTreeTop)
	settings.race = npc.species()
	local _, dialogueTree, dialogueTreeTop = sbq.getDialogueBranch(path, settings, eid, dialogueTreeTop or dialogueTree or sbq.dialogueTree)
	if not dialogueTree then return false end

	dialogue.randomRolls = {}

	for _, v in ipairs(randomDialogueHandling) do
		local randomVal = v[1]
		local resultVal = v[2]
		if not dialogue.result[resultVal] then
			local randomResult = sbq.getRandomDialogueTreeValue(settings, eid, 1, dialogue.result[randomVal],
				dialogueTree, dialogueTreeTop)
			if type(randomResult) == "table" then
				sb.jsonMerge(dialogue.result, randomResult)
			elseif type(randomResult) == "string" then
				dialogue.result[resultVal] = { randomResult }
			end
		end
	end

	local entityname

	if type(eid) == "number" then entityname = world.entityName(eid) end

	local tags = { entityname = entityname or "", dontSpeak = "", love = "", slowlove = "", confused = "",  sleepy = "", sad = "", infusedName = sb.jsonQuery(settings, (dialogue.result.location or settings.location or "default").."InfusedItem.parameters.npcArgs.npcParam.identity.name") or "" }

	for i, line in ipairs(dialogue.result.dialogue or {}) do
		sbq.timer("dialogue" .. 1, (i - 1) * (dialogue.result.delay or 1.5), function ()
			sbq.say(sbq.generateKeysmashes(line, dialogue.result.keysmashMin, dialogue.result.keysmashMax), tags,
				(dialogue.result.portrait or {})[i], (dialogue.result.emote or {})[i], appendName)
			if i == #dialogue.result.dialogue then
				sbq.finishDialogue()
			end
		end)
	end
end

function sbq.say(string, tags, imagePortrait, emote, appendName)
	if type(string) == "string" and string ~= "" then
		if string:find("<love>") then
			status.addEphemeralEffect("love")
		end
		if string:find("<slowlove>") then
			status.addEphemeralEffect("slowlove")
		end
		if string:find("<confused>") then
			status.addEphemeralEffect("sbqConfused")
		end
		if string:find("<sleepy>") then
			status.addEphemeralEffect("sbqSleepy")
		end
		if string:find("<sad>") then
			status.addEphemeralEffect("sbqSad")
		end
		if string:find("<dontSpeak>") then return end

		string = sb.replaceTags(string, tags)
		if string == "" then return end

		if appendName then
			string = world.entityName(entity.id())..":\n"..string
		end
		local options = {sound = randomChatSound()}
		if type(imagePortrait) == "string" and config.getParameter("sayPortrait") then
			npc.sayPortrait(string, imagePortrait, nil, options)
		else
			npc.say(string, nil, options )
		end
		if type(emote) == "string" then
			npc.emote(emote)
		end
	end
end

function sbq.saveCosmeticSlots()
	if (not storage.saveCosmeticSlots) then
		storage.saveCosmeticSlots = {}
		local slots = { "headCosmetic", "chestCosmetic", "legsCosmetic", "backCosmetic" }
		for i, slot in ipairs(slots) do
			storage.saveCosmeticSlots[slot] = npc.getItemSlot(slot)
		end
		storage.originalCosmeticSlots = sb.jsonMerge({}, storage.saveCosmeticSlots)
	elseif (not storage.originalCosmeticSlots) then
		storage.originalCosmeticSlots = sb.jsonMerge({}, storage.saveCosmeticSlots)
	end
end

function sbq.randomizeTenantSettings()
	local randomizeSettings = sbq.checkSpeciesRootTable(config.getParameter("sbqRandomizeSettings") or {})
	for setting, values in pairs(randomizeSettings) do
		if type(values) == "table" then
			local value = values[math.random(#values)]
			storage.settings[setting] = value
			sbq.autoSetSettings(setting, value)
		end
	end
	for setting, value in pairs(randomizeSettings) do
		if type(value) == "string" then
			storage.settings[setting] = storage.settings[value]
			sbq.autoSetSettings(setting, storage.settings[setting])
		end
	end

	local randomizePreySettings = sbq.checkSpeciesRootTable(config.getParameter("sbqRandomizePreySettings") or {})
	local preySettings = status.statusProperty("sbqPreyEnabled") or {}
	for setting, values in pairs(randomizePreySettings) do
		if type(values) == "table" then
			preySettings[setting] = values[math.random(#values)]
		end
	end
	status.setStatusProperty("sbqPreyEnabled", preySettings)
	status.clearPersistentEffects("digestImmunity")
	status.setPersistentEffects("digestImmunity", {"sbqDigestImmunity"})
end

function sbq.setRelevantPredSettings()
	local slots = { "headCosmetic", "chestCosmetic", "legsCosmetic", "backCosmetic" }
	for i, slot in ipairs(slots) do
		npc.setItemSlot(slot, storage.settings[slot] or storage.originalCosmeticSlots[slot])
	end

	local speciesAnimOverrideData = status.statusProperty("speciesAnimOverrideData") or {}

	if storage.settings.breasts or storage.settings.penis or storage.settings.balls or storage.settings.pussy
		or storage.settings.bra or storage.settings.underwear
		or speciesAnimOverrideData.species ~= speciesOverride.species()
		or speciesAnimOverrideData.gender ~= speciesOverride.gender()
	then
		local effects = status.getPersistentEffects("speciesAnimOverride")
		if not effects[1] then
			status.setPersistentEffects("speciesAnimOverride", { speciesAnimOverrideData.customAnimStatus or "speciesAnimOverride" })
		end
		sbq.timer("setOverrideSettings", 0.5, function()
			world.sendEntityMessage(entity.id(), "sbqSetInfusedPartColors", "cock", storage.settings.shaftInfusedVisual and storage.settings.shaftInfusedItem)
			world.sendEntityMessage(entity.id(), "sbqSetInfusedPartColors", "breastsCover", storage.settings.breastsInfusedVisual and storage.settings.breastsInfusedItem)
			world.sendEntityMessage(entity.id(), "sbqSetInfusedPartColors", "breastsFront", storage.settings.breastsInfusedVisual and storage.settings.breastsInfusedItem)
			world.sendEntityMessage(entity.id(), "sbqSetInfusedPartColors", "breastsBack", storage.settings.breastsInfusedVisual and storage.settings.breastsInfusedItem)
			world.sendEntityMessage(entity.id(), "sbqSetInfusedPartColors", "ballsFront", storage.settings.ballsInfusedVisual and storage.settings.ballsInfusedItem)
			world.sendEntityMessage(entity.id(), "sbqSetInfusedPartColors", "ballsBack", storage.settings.ballsInfusedVisual and storage.settings.ballsInfusedItem)
			world.sendEntityMessage(entity.id(), "sbqSetInfusedPartColors", "pussy", storage.settings.wombInfusedVisual and storage.settings.wombInfusedItem)

			if storage.settings.penis and sbq.predatorConfig.locations.shaft and ((not sbq.predatorConfig.locations.shaft.requiresInfusion) or (sbq.predatorConfig.locations.shaft.requiresInfusion and storage.settings.shaftInfusedItem ~= nil)) then
				if storage.settings.underwear then
					sbq.setStatusValue( "cockVisible", "?crop;0;0;0;0")
				else
					sbq.setStatusValue( "cockVisible", "")
				end
			else
				sbq.setStatusValue( "cockVisible", "?crop;0;0;0;0")
			end
			if storage.settings.balls and sbq.predatorConfig.locations.balls and ((not sbq.predatorConfig.locations.balls.requiresInfusion) or (sbq.predatorConfig.locations.balls.requiresInfusion and storage.settings.ballsInfusedItem ~= nil)) then
				if storage.settings.underwear then
					sbq.setStatusValue( "ballsVisible", "?crop;0;0;0;0")
				else
					sbq.setStatusValue( "ballsVisible", "")
				end
			else
				sbq.setStatusValue( "ballsVisible", "?crop;0;0;0;0")
			end
			if storage.settings.breasts and sbq.predatorConfig.locations.breasts and ((not sbq.predatorConfig.locations.breasts.requiresInfusion) or (sbq.predatorConfig.locations.breasts.requiresInfusion and storage.settings.breastsInfusedItem ~= nil)) then
				sbq.setStatusValue( "breastsVisible", "")
			else
				sbq.setStatusValue( "breastsVisible", "?crop;0;0;0;0")
			end
			if storage.settings.pussy and sbq.predatorConfig.locations.pussy and ((not sbq.predatorConfig.locations.womb.requiresInfusion) or (sbq.predatorConfig.locations.womb.requiresInfusion and storage.settings.wombInfusedItem ~= nil)) then
				sbq.setStatusValue( "pussyVisible", "")
			else
				sbq.setStatusValue( "pussyVisible", "?crop;0;0;0;0")
			end
			sbq.handleUnderwear()
		end)
	elseif (not sbq.occupantHolder and not speciesAnimOverrideData.permanent) and (status.statusProperty("animOverrideScale") or 1) == 1 then
		status.clearPersistentEffects("speciesAnimOverride")
	end

	status.setStatusProperty("sbqSettings", storage.settings)

	sbq.updateCosmeticSlots()
end

function sbq.handleUnderwear()
	world.sendEntityMessage(entity.id(), "sbqEnableUnderwear", storage.settings.underwear)
	world.sendEntityMessage(entity.id(), "sbqEnableBra", storage.settings.bra)
end

function sbq.setStatusValue(name, value)
	world.sendEntityMessage(entity.id(), "sbqSetStatusValue", name, value)
end

function sbq.updateCosmeticSlots()
	if type(storage.settings) == "table" then
		local hornyPercent = status.resourcePercentage("horny")
		if (storage.settings.stripHead or 0.6) < hornyPercent then
			_npc_setItemSlot("headCosmetic", "sbq_nude_chest")
		else
			_npc_setItemSlot("headCosmetic", storage.saveCosmeticSlots.headCosmetic)
		end
		if (storage.settings.stripChest or 0.6) < hornyPercent then
			_npc_setItemSlot("chestCosmetic", "sbq_nude_chest")
		else
			_npc_setItemSlot("chestCosmetic", storage.saveCosmeticSlots.chestCosmetic)
		end
		if (storage.settings.stripLegs or 0.6) < hornyPercent then
			_npc_setItemSlot("legsCosmetic", "sbq_nude_legs")
		else
			_npc_setItemSlot("legsCosmetic", storage.saveCosmeticSlots.legsCosmetic)
		end
	end
end

function sbq.searchForValidPrey(voreType, consent)
	sbq.targetedEntities = {
	}

	if storage.settings[voreType.."HuntFriendlyPlayers"] or storage.settings[voreType.."HuntHostilePlayers"] then
		local entities = world.playerQuery(mcontroller.position(), 50)
		for i, eid in ipairs(entities) do
			sbq.maybeAddPreyToTargetList(eid, voreType, "Players", 1.5)
		end
	end
	if storage.settings[voreType.."HuntFriendlyOCs"] or storage.settings[voreType.."HuntHostileOCs"] then
		local entities = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = entity.id(), callScript = "config.getParameter", callScriptArgs = { "isOC" } })
		for i, eid in ipairs(entities) do
			sbq.maybeAddPreyToTargetList(eid, voreType, "OCs", 2)
		end
	end
	if storage.settings[voreType.."HuntFriendlySBQNPCs"] or storage.settings[voreType.."HuntHostileSBQNPCs"] then
		local entities = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = entity.id(), callScript = "config.getParameter", callScriptArgs = { "sbqNPC" } })
		for i, eid in ipairs(entities) do
			if not world.callScriptedEntity(eid, "config.getParameter", "isOC") then
				sbq.maybeAddPreyToTargetList(eid, voreType, "SBQNPCs", 3)
			end
		end
	end
	if storage.settings[voreType.."HuntFriendlyOther"] or storage.settings[voreType.."HuntHostileOther"] then
		local entities = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = entity.id(), callScript = "config.getParameter", callScriptArgs = { "sbqNPC" }, callScriptResult = false })
		util.appendLists(entities, world.monsterQuery(mcontroller.position(), 50))
		for i, eid in ipairs(entities) do
			sbq.maybeAddPreyToTargetList(eid, voreType, "Other", 4)
		end
	end
end

function sbq.maybeAddPreyToTargetList(eid, voreType, ext, score)
	local aggressive = world.entityAggressive(eid)
	local validTarget = false
	if aggressive and storage.settings[voreType .. "HuntHostile" .. ext] then
		validTarget = true
	elseif not aggressive and storage.settings[voreType .. "HuntFriendly"..ext] then
		validTarget = true
	end
	if validTarget then
		sbq.addRPC(world.sendEntityMessage(eid, "sbqIsPreyEnabled", voreType), function (enabled)
			if enabled and enabled.enabled and enabled.type ~= "prey" and enabled.size then
				local scale = (status.statusProperty("animOverrideScale") or 1)
				local relativeSize = enabled.size / scale
				local location = ((((sbq.speciesConfig.states or {})[sbq.state or "stand"] or {}).transitions or {})[voreType] or {}).location
				if (relativeSize > (storage.settings[voreType .. "PreferredPreySizeMin"] or 0.1))
				and (relativeSize < (storage.settings[voreType .. "PreferredPreySizeMax"] or 1.25))
				and location and sbq.getSidedLocationWithSpace(location, enabled.size)
				then
					table.insert(sbq.targetedEntities, {eid, score * ((math.abs((storage.settings[voreType .. "PreferredPreySize"] or 0.5)-relativeSize) * 5) + world.magnitude(mcontroller.position(), world.entityPosition(eid)))})
				end
			end
		end)
	end
end

function sbq.searchForValidPred(voreType, consent)
	sbq.targetedEntities = {
	}

	if storage.settings[voreType.."BaitFriendlyPlayers"] or storage.settings[voreType.."BaitHostilePlayers"] then
		local entities = world.playerQuery(mcontroller.position(), 50)
		for i, eid in ipairs(entities) do
			sbq.maybeAddPredToTargetList(eid, voreType, "Players", 1.5, consent)
		end
	end
	if storage.settings[voreType.."BaitFriendlyOCs"] or storage.settings[voreType.."BaitHostileOCs"] then
		local entities = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = entity.id(), callScript = "config.getParameter", callScriptArgs = { "isOC" } })
		for i, eid in ipairs(entities) do
			sbq.maybeAddPredToTargetList(eid, voreType, "OCs", 2)
		end
	end
	if storage.settings[voreType.."BaitFriendlySBQNPCs"] or storage.settings[voreType.."BaitHostileSBQNPCs"] then
		local entities = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = entity.id(), callScript = "config.getParameter", callScriptArgs = { "sbqNPC" } })
		for i, eid in ipairs(entities) do
			if not world.callScriptedEntity(eid, "config.getParameter", "isOC") then
				sbq.maybeAddPredToTargetList(eid, voreType, "SBQNPCs", 3)
			end
		end
	end
	if storage.settings[voreType.."BaitFriendlyOther"] or storage.settings[voreType.."BaitHostileOther"] then
		local entities = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = entity.id(), callScript = "config.getParameter", callScriptArgs = { "sbqNPC" }, callScriptResult = false })
		util.appendLists(entities, world.monsterQuery(mcontroller.position(), 50))
		for i, eid in ipairs(entities) do
			sbq.maybeAddPredToTargetList(eid, voreType, "Other", 4)
		end
	end
end

function sbq.maybeAddPredToTargetList(eid, voreType, ext, score, consent)
	local aggressive = world.entityAggressive(eid)
	local validTarget = false
	if aggressive and storage.settings[voreType .. "BaitHostile" .. ext] then
		validTarget = true
	elseif not aggressive and storage.settings[voreType .. "BaitFriendly"..ext] then
		validTarget = true
	end
	if validTarget then
		sbq.addRPC(world.sendEntityMessage(eid, "sbqIsPredEnabled", voreType), function(enabled)
			if enabled and enabled.enabled and enabled.type ~= "prey" and enabled.size and (consent or enabled.unwilling) then
				sbq.addRPC(world.sendEntityMessage(eid, "sbqCheckAssociatedEffects", voreType), function(effects)
					if effects then
						local badEffect = false
						local effectScore = 0
						for i, effect in ipairs(effects) do
							if (effect == "none" and storage.settings[voreType .. "PreyDislikesNone"])
								or (effect == "heal" and storage.settings[voreType .. "PreyDislikesHeal"])
								or (effect == "digest" and storage.settings[voreType .. "PreyDislikesDigest"])
								or (effect == "softDigest" and storage.settings[voreType .. "PreyDislikesSoftDigest"])
							then
								badEffect = true
								break
							elseif (effect == "none" and storage.settings[voreType .. "PreyPrefersNone"])
								or (effect == "heal" and storage.settings[voreType .. "PreyPrefersHeal"])
								or (effect == "digest" and storage.settings[voreType .. "PreyPrefersDigest"])
								or (effect == "softDigest" and storage.settings[voreType .. "PreyPrefersSoftDigest"])
							then
								effectScore = effectScore + (10/#effects)
							end
						end
						local scale = (status.statusProperty("animOverrideScale") or 1)
						local relativeSize = enabled.size / scale
						if not badEffect
						and (relativeSize > (storage.settings[voreType .. "PreferredPredSizeMin"] or 0.75))
						and (relativeSize < (storage.settings[voreType .. "PreferredPredSizeMax"] or 3))
						then
							table.insert(sbq.targetedEntities, { eid, score * (
								(math.abs((storage.settings[voreType .. "PreferredPredSize"] or 2) - relativeSize) * 5)
									+ world.magnitude(mcontroller.position(), world.entityPosition(eid))
									- effectScore
							)})
						end
					end
				end)
			end
		end)
	end
end

function sbq.checkOccupantRewards(occupant, rewards, notify, recipient, holder, treestart)
	if type(recipient) == "number" and world.entityExists(recipient) and world.entityType(recipient) == "player" then
		local setFlags, newRewards = sbq.getTenantRewards(rewards, occupant, npc.level())
		world.sendEntityMessage(holder, "sbqSetOccupantFlags", recipient, setFlags)
		local sendRewards = false
		local rewardNotifyDelay = 0
		for rewardName, data in pairs(newRewards) do
			sendRewards = true
			if notify and sbq.getRandomDialogue( treestart or ".rewardNotify", recipient, sb.jsonMerge(storage.settings, sb.jsonMerge(sb.jsonMerge(occupant.flags, occupant.visited), { rewardName = rewardName, poolName = data.pool, isPrey = (occupant.id == entity.id()) }))) then
				rewardNotifyDelay = rewardNotifyDelay + 5
			end
		end
		if sendRewards then
			world.sendEntityMessage(recipient, "sbqQueueTenantRewards", entity.uniqueId(), newRewards)
		end
	end
end

function sbq.checkSpeciesRootTable(input)
	local input = input
	if type(input) == "string" then
		input = root.assetJson(input)
	end
	input = input[npc.species()] or input.default or input
	if type(input) == "string" then
		input = sbq.checkSpeciesRootTable(input)
	end
	return input
end
