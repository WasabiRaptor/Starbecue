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

local _npc_setItemSlot

function new_npc_setItemSlot(slot, data)
	storage.saveCosmeticSlots[slot] = data
	_npc_setItemSlot(slot, data)
	sbq.updateCosmeticSlots()
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
			end
		end)
	end
	_tenant_setHome(position, boundary, deedUniqueId, skipNotification)
end

function init()
	sbq.config = root.assetJson("/sbqGeneral.config")
	sbq.NPCconfig = root.npcConfig(npc.npcType())

	if type(_npc_setItemSlot) ~= "function" then
		_npc_setItemSlot = npc.setItemSlot
		npc.setItemSlot = new_npc_setItemSlot
	end

	sbq.saveCosmeticSlots()

	oldinit()

	sbq.setSpeciesConfig()
	sbq.predatorConfig = sbq.speciesConfig.sbqData
	sbq.sbqData = sbq.predatorConfig

	if not storage.settings then
		storage.settings = sb.jsonMerge( sbq.config.defaultSettings,
			sb.jsonMerge(sbq.speciesConfig.sbqData.defaultSettings or {},
				sb.jsonMerge( config.getParameter("sbqDefaultSettings") or {}, config.getParameter("sbqSettings") or {})
			)
		)
	end
	local preySettings = status.statusProperty("sbqPreyEnabled")
	status.setStatusProperty("sbqPreyEnabled",
		sb.jsonMerge(sbq.config.defaultPreyEnabled.player,
			sb.jsonMerge(preySettings, config.getParameter("sbqOverridePreyEnabled") or {})
		)
	)
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

	storage.settings.ownerUuid = recruitable.ownerUuid()
	storage.settings.isFollowing = recruitable.isFollowing()

	sbq.dialogueTree = config.getParameter("dialogueTree")
	sbq.dialogueBoxScripts = config.getParameter("dialogueBoxScripts")
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
		if not sbq.occupantHolder then
			sbq.occupantHolder = world.spawnVehicle( "sbqOccupantHolder", mcontroller.position(), { driver = entity.id(), settings = storage.settings, doExpandAnim = true } )
		end
		table.insert(sbq.queuedTransitions, {transition, args})
	end)
	message.setHandler("sbqSwapFollowing", function(_, _)
		if storage.behaviorFollowing then
			if world.getProperty("ephemeral") then
				recruitable.confirmUnfollowBehavior()
				storage.settings.isFollowing = recruitable.isFollowing()
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
		storage.settings.isFollowing = recruitable.isFollowing()
	end)
	message.setHandler("recruit.confirmUnfollow", function(_,_)
		recruitable.confirmUnfollow(true)
		storage.settings.isFollowing = recruitable.isFollowing()
	end)
	message.setHandler("recruit.confirmUnfollowBehavior", function(_,_)
		recruitable.confirmUnfollowBehavior(true)
		storage.settings.isFollowing = recruitable.isFollowing()
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
		if storage.respawner and index ~= nil then
			world.sendEntityMessage(storage.respawner, "sbqSaveDigestedPrey", digestedStoredTable, index)
		end
		if recruitable.ownerUuid() then
			world.sendEntityMessage(recruitable.ownerUuid(), "sbqCrewSaveDigestedPrey", digestedStoredTable, entity.uniqueId())
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
					sbq.getRandomDialogue( {"gotSteppy"}, eid, sb.jsonMerge(storage.settings, {steppyType = steppyType}) )
				end
			elseif sbq.timer("sbqSteppy", 5) then
				sbq.getRandomDialogue( {"gotSteppy"}, eid, sb.jsonMerge(storage.settings, {steppyType = steppyType}) )
			end
		end
	end)
	message.setHandler("sbqDidSteppy", function(_, _, eid, steppyType)
		if sbq.timer("sbqDidSteppy", 5) then
			sbq.getRandomDialogue( {"didSteppy"}, eid, sb.jsonMerge(storage.settings, {steppyType = steppyType}) )
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
	end
	)
end

function sbq.setSpeciesConfig()
	sbq.getSpeciesConfig(npc.species(), storage.settings)
	status.setStatusProperty("sbqOverridePreyEnabled", sbq.speciesConfig.sbqData.overridePreyEnabled)
	local speciesAnimOverrideData = status.statusProperty("speciesAnimOverrideData") or {}
	local effects = status.getPersistentEffects("speciesAnimOverride")
	if not effects[1] then
		status.setPersistentEffects("speciesAnimOverride", { speciesAnimOverrideData.customAnimStatus or "speciesAnimOverride" })
	end
	status.clearPersistentEffects("digestImmunity")
	status.setPersistentEffects("digestImmunity", {"sbqDigestImmunity"})
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
	sbq.timer("hunting", 15, function ()
		sbq.GoHunting()
	end)

	if type(sbq.occupantHolder) == "number" and world.entityExists(sbq.occupantHolder) then
		for _, transition in ipairs(sbq.queuedTransitions) do
			world.sendEntityMessage(sbq.occupantHolder, "requestTransition", transition[1], transition[2])
		end
		sbq.queuedTransitions = {}
	end

	sbq.dialogueBoxOpen = math.max(0, sbq.dialogueBoxOpen - dt)

	oldupdate(dt)
end

function uninit()
	olduninit()
end

function interact(args)
	if recruitable.isRecruitable() then
		return recruitable.generateRecruitInteractAction()
	end

	local overrideData = status.statusProperty("speciesAnimOverrideData") or {}

	local dialogueBoxData = {
		sbqData = sbq.speciesConfig.sbqData,
		dialogueBoxScripts = sbq.dialogueBoxScripts,
		settings = sb.jsonMerge(storage.settings, status.statusProperty("sbqPreyEnabled") or {} ),
		dialogueTree = sbq.dialogueTree,
		icons = config.getParameter("voreIcons"),
		iconDirectives = (config.getParameter("iconDirectives") or "")..(overrideData.directives or ""),
		entityPortrait = config.getParameter("entityPortrait"),
		defaultPortrait = config.getParameter("defaultPortrait"),
		portraitPath = config.getParameter("portraitPath"),
		defaultName = config.getParameter("defaultName"),
		occupantHolder = sbq.occupantHolder
	}
	dialogueBoxData.settings.race = npc.species()

	if sbq.currentData.type == "prey" then
		if args.predData then
			sbq.predData = args.predData
			local settings = args.predData.settings
			settings.location = args.predData.location
			settings.predator = args.predData.predator
			settings.isPrey = true

			settings.personality = storage.settings.personality
			settings.mood = storage.settings.mood

			dialogueBoxData.settings = sb.jsonMerge(dialogueBoxData.settings, settings)
			dialogueBoxData.dialogueTreeStart = { "struggling" }
			return {"ScriptPane", { data = dialogueBoxData, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:dialogueBox" }}
		else
			return
		end
	else
		local location = sbq.getOccupantArg(args.sourceId, "location")
		if location ~= nil then
			local flags = sbq.getOccupantArg(args.sourceId, "flags") or {}
			dialogueBoxData.dialogueTreeStart = { "struggle" }
			dialogueBoxData.settings.location = location
			dialogueBoxData.settings.playerPrey = true
			if flags.infused then
				dialogueBoxData.settings.predator = npc.species()
				dialogueBoxData.dialogueTreeStart = { "infusedTease" }
			end
		end
		return {"ScriptPane", { data = dialogueBoxData, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:dialogueBox" }}
	end
end

function sbq.GoHunting()
	storage.huntingTarget = (world.playerQuery( entity.position(), 50) or {})[1]
	if type(storage.huntingTarget) == "number" and world.entityExists(storage.huntingTarget) then
		--self.board:setEntity("sbqHuntingTarget", storage.huntingTarget)
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


function sbq.getRandomDialogue(dialogueTreeLocation, eid, settings, dialogueTree, appendName)
	settings.race = npc.species()
	local dialogueTree = sbq.getDialogueBranch(dialogueTreeLocation, settings, eid, dialogueTree)
	if not dialogueTree then return false end
	recursionCount = 0 -- since we successfully made it here, reset the recursion count

	local randomRolls = {}
	local randomDialogue = dialogueTree.randomDialogue
	local randomPortrait = dialogueTree.randomPortrait
	local randomEmote = dialogueTree.randomEmote

	randomRolls, randomDialogue		= sbq.getRandomDialogueTreeValue(dialogueTree, settings, randomRolls, randomDialogue, "randomDialogue")
	randomRolls, randomPortrait		= sbq.getRandomDialogueTreeValue(dialogueTree, settings, randomRolls, randomPortrait, "randomPortrait")
	randomRolls, randomEmote		= sbq.getRandomDialogueTreeValue(dialogueTree, settings, randomRolls, randomEmote, "randomEmote")

--[[
	local imagePortrait
	if not config.getParameter("entityPortrait") then
		imagePortrait = ((config.getParameter("portraitPath") or "")..(randomPortrait or config.getParameter("defaultPortrait")))
	end
]]
	local playerName

	if type(eid) == "number" then
		playerName = world.entityName(eid)
	end

	local tags = { entityname = playerName, dontSpeak = "", love = "", slowlove = "", confused = "",  sleepy = "", sad = "", steppyType = settings.steppyType, infusedName = (((((settings[(dialogueTree.location or settings.location or "").."InfusedItem"] or {}).parameters or {}).npcArgs or {}).npcParam or {}).identity or {}).name or "" }

	if type(randomDialogue) == "string" then
		sbq.say(sbq.generateKeysmashes(randomDialogue, dialogueTree.keysmashMin, dialogueTree.keysmashMax), tags, imagePortrait, randomEmote, appendName)
		return true
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
		if storage.settings.breastVorePred then
			_npc_setItemSlot("chestCosmetic", "sbq_nude_chest")
		else
			_npc_setItemSlot("chestCosmetic", storage.saveCosmeticSlots.chestCosmetic)
		end

		if storage.settings.unbirthPred or storage.settings.cockVorePred or storage.settings.analVorePred then
			_npc_setItemSlot("legsCosmetic", "sbq_nude_legs")
		else
			_npc_setItemSlot("legsCosmetic", storage.saveCosmeticSlots.legsCosmetic)
		end
	end
end

function sbq.searchForValidPrey(voreType)
	local players = world.playerQuery(mcontroller.position(), 50)
	local npcs = world.npcQuery(mcontroller.position(), 50, { withoutEntityId = npc.id() })
	local monsters = world.monsterQuery(mcontroller.position(), 50)

	if storage.settings.huntFriendlyPlayers or storage.settings.huntHostilePlayers then
		for i, entity in ipairs(players) do
			sbq.addRPC(world.sendEntityMessage(entity, "sbqIsPreyEnabled", voreType), function (enabled)
				if enabled and enabled.enabled then
					table.insert(sbq.targetedEntities, {entity, voreType})
				end
			end)
		end
	end
	if storage.settings.huntHostileNPCs or storage.settings.huntFriendlyNPCs then
		for i, entity in ipairs(npcs) do
			sbq.addRPC(world.sendEntityMessage(entity, "sbqIsPreyEnabled", voreType), function (enabled)
				if enabled and enabled.enabled then
					table.insert(sbq.targetedEntities, {entity, voreType})
				end
			end)
		end
	end
	if storage.settings.huntHostileMonsters or storage.settings.huntFriendlyMonsters then
		for i, entity in ipairs(monsters) do
			sbq.addRPC(world.sendEntityMessage(entity, "sbqIsPreyEnabled", voreType), function (enabled)
				if enabled and enabled.enabled then
					table.insert(sbq.targetedEntities, {entity, voreType})
				end
			end)
		end
	end

end

function sbq.searchForValidPred(setting)

end

function sbq.checkOccupantRewards(occupant, rewards, notify, recipient, holder, treestart)
	if type(recipient) == "number" and world.entityExists(recipient) and world.entityType(recipient) == "player" then
		local setFlags, newRewards = sbq.getTenantRewards(rewards, occupant, npc.level())
		world.sendEntityMessage(holder, "sbqSetOccupantFlags", recipient, setFlags)
		local sendRewards = false
		local rewardNotifyDelay = 0
		for rewardName, data in pairs(newRewards) do
			sendRewards = true
			if notify and sbq.getRandomDialogue( treestart or {"rewardNotify"}, recipient, sb.jsonMerge(storage.settings, sb.jsonMerge(sb.jsonMerge(occupant.flags, occupant.visited), { rewardName = rewardName, poolName = data.pool, isPrey = (occupant.id == entity.id()) }))) then
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
