local old = {
	refreshHumanoidParameters = refreshHumanoidParameters or (function() end),
	-- equipmentSlotUpdated = equipmentSlotUpdated or (function() end)
}
require("/scripts/any/SBQ_util.lua")

-- function equipmentSlotUpdated(slot, itemDescriptor)
-- 	old.equipmentSlotUpdated(slot, itemDescriptor)
-- 	local slotFunc = equipped[slot .. "Slot"] or function(_) end
-- 	slotFunc(itemDescriptor)
-- end

function sbqSettingsConfig()
	return {}
end

local initialized = false
function refreshHumanoidParameters()
	old.refreshHumanoidParameters()
	if not initialized then return end
	if sbq.uninit then
		sbq.uninit("refresh")
	end
	local speciesConfig = root.speciesConfig(sbq.humanoid.species())
	local humanoidConfig = sbq.humanoid.humanoidConfig()

	sbq.settings = sbq._Settings.new(
		sb.jsonMerge(
			speciesConfig.sbqSettingsConfig or {},
			humanoidConfig.sbqSettingsConfig or {},
			sbqSettingsConfig()
		),
		sbq.settings:save(),
		entity.entityType()
	)
	if sbq.settings:setParameterSettings() then return end
	sbq.settings:setMessageHandlers(player and true)

	sbq.upgrades:apply(sbq.settings)
	sbq.settings:setPublicSettings()
	sbq.settings:setStatSettings()
	sbq.refreshPredHudPortrait()
	humanoidConfig = sbq.humanoid.humanoidConfig()

	if humanoidConfig.sbqEnabled and sbq.init and not (humanoidConfig.sbqPostloadError or (humanoidConfig.sbqCompatible == false)) then
		if humanoidConfig.sbqConfig then
			sbq.init(humanoidConfig.sbqConfig)
		end
	end
	if player then
		interface.sendMessage("sbqRefreshMainSettingsPage", sbq.entityId(), sbq.settingsPageData())
	else
		for k, _ in pairs(sbq.settings.hasSettingsOpen) do
			world.sendEntityMessage(k, "sbqRefreshMainSettingsPage", sbq.entityId(), sbq.settingsPageData())
		end
	end
end


-- this function in it's current state was made explicitly to add a missing color to familar's palettes
-- however, it should probably be repurposed to add a missing color to all palettes
function sbq.addDirectives()
	local directives = self.identity.bodyDirectives:lower()
	local found1, found2 = directives:find("00ffa1=")
	if found1 then
		local colorStartIndex = found2 + 1
		local colorEndIndex = #directives
		local found4 = directives:find(";", colorStartIndex)
		if found4 then
			local found5 = directives:find("?", colorStartIndex)
			if found5 and found4 > found5 then
				colorEndIndex = found5 - 1
			else
				colorEndIndex = found4 - 1
			end
		end

		local multiplyAmount = 0.75
		local color = directives:sub(colorStartIndex, colorEndIndex)
		local R = tonumber(color:sub(1, 2), 16)
		local G = tonumber(color:sub(3, 4), 16)
		local B = tonumber(color:sub(5, 6), 16)
		local A = ""
		if #color == 8 then
			A = color:sub(7, 8)
		end
		local newReplaceColors = "?replace;00c77d=" ..
			string.format("%02x", math.floor(R * multiplyAmount)) ..
			string.format("%02x", math.floor(G * multiplyAmount)) ..
			string.format("%02x", math.floor(B * multiplyAmount)) ..
			A
		self.identity.bodyDirectives = self.identity.bodyDirectives .. newReplaceColors
	end
end

function sbq.humanoidInit()
	message.setHandler("sbqDoTransformation", function(_, _, ...)
		return sbq.doTransformation(...)
	end)
	message.setHandler("sbqRevertTF", function(_, _)
		return sbq.revertTF()
	end)

	message.setHandler("sbqGetCard", function()
		local item = root.assetJson("/sbqItemTemplates.config:npcCard")
		local entityType = entity.entityType()
		if entityType == "npc" then
			local npcConfig = root.npcConfig(npc.npcType())
			if npcConfig.scriptConfig.isOC then
				item.parameters.rarity = "rare"
			elseif npcConfig.scriptConfig.sbqNPC then
				item.parameters.rarity = "uncommon"
			end
			item.parameters.npcArgs.npcType = npc.npcType()
			item.parameters.npcArgs.npcLevel = npc.level()
			item.parameters.npcArgs.npcSeed = npc.seed()
			item.parameters.tooltipFields.subtitle = npc.npcType()
			item.parameters.npcArgs.npcParam.scriptConfig.initialStorage = preservedStorage()
			item.parameters.npcArgs.npcParam.scriptConfig.initialStorage.sbqSettings = sbq.settings:export()
			item.parameters.npcArgs.npcParam.scriptConfig.initialStorage.sbqRandomizedSettings = true
			if storage.respawner then
				item.parameters.npcArgs.npcParam.scriptConfig.originalWorldId = world.id()
				item.parameters.npcArgs.npcParam.scriptConfig.originalWorldRespawner = storage.respawner
			end
		elseif entityType == "player" then
			item.parameters.rarity = "legendary"
			item.parameters.npcArgs.npcType = "generictenant"
			item.parameters.npcArgs.npcLevel = 1
			item.parameters.npcArgs.npcSeed = 1
			item.parameters.tooltipFields.subtitle = "player"
			item.parameters.npcArgs.npcParam.wasPlayer = true
			item.parameters.npcArgs.npcParam.scriptConfig.initialStorage.sbqSettings = sbq.settings:export()
			item.parameters.npcArgs.npcParam.scriptConfig.initialStorage.sbqRandomizedSettings = true
			item.parameters.npcArgs.npcParam.scriptConfig.initialStorage.sbqUpgrades = sbq.upgrades:save()
			item.parameters.npcArgs.npcParam.scriptConfig.initialStorage.wr_speciesIdentities = storage.wr_speciesIdentities
		end
		local identity = sbq.humanoid.humanoidIdentity()
		item.parameters.npcArgs.npcSpecies = sbq.species()
		item.parameters.shortdescription = world.entityName(entity.id())
		item.parameters.npcArgs.npcParam.identity = identity
		item.parameters.npcArgs.npcParam.humanoidParameters = sbq.humanoid.getHumanoidParameters()
		item.parameters.npcArgs.npcParam.scriptConfig.uniqueId = entity.uniqueId()
		item.parameters.tooltipFields.collarNameLabel = sbq.createdDateString()
		item.parameters.createdDate = sbq.createdDate()
		item.parameters.tooltipFields.objectImage = world.entityPortrait(entity.id(), "full")
		item.parameters.inventoryIcon = world.entityPortrait(entity.id(), "bust")
		item.parameters.preySize = sbq.size()
		item.parameters.bodyFullbright = sbq.humanoid.humanoidConfig().bodyFullbright
		item.parameters.npcArgs.npcParam.statusControllerSettings.statusProperties.sbqPronouns = status.statusProperty("sbqPronouns")
		return item
	end)

	-- make sure these are initialized
	storage.wr_originalIdentity = storage.wr_originalIdentity or status.statusProperty("wr_originalIdentity")
	storage.wr_speciesIdentities = storage.wr_speciesIdentities or status.statusProperty("wr_speciesIdentities") or {}
	if not storage.wr_originalIdentity then
		storage.wr_originalIdentity = sbq.humanoid.humanoidIdentity()
		storage.wr_originalIdentity.parameters = sbq.humanoid.getHumanoidParameters()
	end
	if not storage.wr_speciesIdentities[storage.wr_originalIdentity.species] then
		storage.wr_speciesIdentities[storage.wr_originalIdentity.species] = storage.wr_originalIdentity
	end
	status.setStatusProperty("wr_originalIdentity", storage.wr_originalIdentity)
	status.setStatusProperty("wr_speciesIdentities", storage.wr_speciesIdentities)

	message.setHandler("wr_setCurrentIdentity", function(_, localMessage, newIdentity)
		if player and not localMessage then return end
		local context = player or npc
		local currentIdentity = context.humanoidIdentity()
		context.setHumanoidParameters(newIdentity.parameters or {})
		context.setHumanoidIdentity(newIdentity)
		if player and interface and (currentIdentity.species ~= newIdentity.species) then
			interface.sendMessage("wr_closeCustomize")
		end
		if player and chat and newIdentity.name and (newIdentity.name ~= currentIdentity.name) then
			chat.command("/nick "..newIdentity.name)
		end
	end)
	message.setHandler("wr_setOriginalIdentity", function(_, localMessage, newIdentity)
		if player and not localMessage then return end
		storage.wr_originalIdentity = newIdentity
		status.setStatusProperty("wr_originalIdentity", storage.wr_originalIdentity)
	end)
	message.setHandler("wr_setSpeciesIdentity", function (_, localMessage, newIdentity)
		if player and not localMessage then return end
		storage.wr_speciesIdentities[newIdentity.species] = newIdentity
		status.setStatusProperty("wr_speciesIdentities", storage.wr_speciesIdentities)
		if storage.wr_originalIdentity.species == newIdentity.species then
			storage.wr_originalIdentity = newIdentity
			status.setStatusProperty("wr_originalIdentity", storage.wr_originalIdentity)
		end
	end)

	initialized = true
end

function sbq.directory()
	return "/humanoid/" .. sbq.species() .. "/"
end

-- function sbq.findIdentityColor(identity, color)
-- 	for k, v in pairs(identity) do
-- 		if type(v) == "string" and v:find("replace;") then
-- 			local newString = v:lower()
-- 			if not newString:sub(-1) == ";" then
-- 				newString = newString .. ";"
-- 			end
-- 			local _, last = newString:find(color:lower() .. "=")
-- 			if last then
-- 				local _, found = newString:find(";", last)
-- 				if found then
-- 					return newString:sub(last+1, found-1)
-- 				end
-- 			end
-- 		end
-- 	end
-- end

function sbq.doTransformation(newIdentity, duration, forceIdentity, forceCustomization, ...)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
	local oldSpeciesFile = root.speciesConfig(sbq.species())
	if oldSpeciesFile.sbqCompatible == false then
		if player then
			sbq.logWarn("Attempted to transform as blacklisted species: " .. newIdentity.species)
			player.radioMessage("sbqTransformFromBlacklist")
		end
		return false
	end
	local currentIdentity = sbq.humanoid.humanoidIdentity()
	currentIdentity.parameters = sbq.humanoid.getHumanoidParameters()

	if sbq.settings:get("genderTF") then
		if newIdentity.gender == "random" then
			newIdentity.gender = ({ "male", "female" })[math.random(2)]
		elseif newIdentity.gender == "swap" then
			newIdentity.gender = ({ male = "female", female = "male" })[currentIdentity.gender]
		elseif (newIdentity.gender ~= "male") and (newIdentity.gender ~= "female") then
			newIdentity.gender = currentIdentity.gender
		end
	else
		newIdentity.gender = currentIdentity.gender
	end
	if newIdentity.species and (newIdentity.species ~= currentIdentity.species) then
		if sbq.settings:get("speciesTF") then
			if newIdentity.species == "any" then
				local speciesList = root.assetJson("/sbqTFAny.config")
				newIdentity.species = speciesList[math.random(#speciesList)]
			elseif newIdentity.species == "originalSpecies" then
				newIdentity.species = storage.wr_originalIdentity.species
			elseif not newIdentity.species then
				newIdentity.species = currentIdentity.species
			end
		else
			return false
		end
	else
		newIdentity.species = currentIdentity.species
	end
	local speciesFile = root.speciesConfig(newIdentity.species)
	if not speciesFile then return false end
	newIdentity.species = speciesFile.kind
	if speciesFile.sbqCompatible == false then
		if player then
			sbq.logWarn("Attempted to transform into blacklisted species: " .. newIdentity.species)
			player.radioMessage("sbqTransformIntoBlacklist")
		end
		return false
	end
	if npc and speciesFile.sbqSettingsConfig then
		if sbq.query(sbq.fetchConfigArray(speciesFile.sbqSettingsConfig) or {}, { "overrideSettings", "speciesTF" }) == false then
			sbq.logWarn("NPC cannot be transformed into TF locked species: " .. newIdentity.species)
			return false
		end
	end
	if player and not (
			root.assetOrigin(sb.replaceTags(root.assetJson("/client.config:respawnCinematic"), { species = newIdentity.species, mode = "casual" }))
			and root.assetOrigin(sb.replaceTags(root.assetJson("/client.config:respawnCinematic"), { species = newIdentity.species, mode = "survival" }))
			and root.assetOrigin(sb.replaceTags(root.assetJson("/client.config:warpCinematic"), { species = newIdentity.species }))
			and root.assetOrigin(sb.replaceTags(root.assetJson("/client.config:deployCinematic"), { species = newIdentity.species }))
			and root.assetJson("/universe_server.config:speciesShips")[newIdentity.species]
			and root.assetJson("/ai/ai.config:species")[newIdentity.species]
			and root.assetJson("/quests/quests.config:initialquests")[newIdentity.species]
			and root.assetJson("/player.config:defaultCodexes")[newIdentity.species]
		) then
		player.radioMessage("sbqTransformNPCOnly")
		sbq.logWarn("Attempted to transform into NPC only species: " .. newIdentity.species)
		return false
	end
	local preserveColors = {

	}
	if not storage.wr_speciesIdentities[newIdentity.species] then
		-- if oldSpeciesFile.baseColorPalette and speciesFile.baseColorPalette then
		-- 	for k, oldColors in pairs(oldSpeciesFile.baseColorPalette) do
		-- 		for k2, newColors in pairs(speciesFile.baseColorPalette) do
		-- 			if (#oldColors >= #newColors) and (k == k2) then
		-- 				for i, color in ipairs(newColors) do
		-- 					preserveColors[color:lower()] = sbq.findIdentityColor(currentIdentity, oldColors[i])
		-- 				end
		-- 			end
		-- 		end
		-- 	end
		-- end
	end

	local randomSource = sb.makeRandomSource()

	local choices = sb.jsonMerge({}, (newIdentity.parameters or {}).choices or currentIdentity.parameters.choices or {
		0, -- will be overwritten immediately
		randomSource:randu64(),
		randomSource:randu64(),
		randomSource:randu64(),
		randomSource:randu64(),
		randomSource:randu64(),
		randomSource:randu64(),
		randomSource:randu64(),
		randomSource:randu64(),
		randomSource:randu64(),
	})
	choices[1] = ((newIdentity.gender or currentIdentity.gender) == "male") and 0 or 1

	local generatedIdentity, generatedParameters = root.createHumanoid(
		speciesFile.forceName or newIdentity.name or (storage.wr_originalIdentity or {}).name or currentIdentity.name,
		newIdentity.species,
		table.unpack(choices)
	)
	generatedParameters.sbqEnabled = true
	generatedIdentity.parameters = generatedParameters

	newIdentity = sb.jsonMerge(
		generatedIdentity,
		newIdentity,
		forceIdentity and {} or storage.wr_speciesIdentities[newIdentity.species] or {},
		{ gender = newIdentity.gender } -- preserve new gender if applicable
	)

	world.sendEntityMessage(entity.id(), "wr_setCurrentIdentity", newIdentity)
	if ((not (storage.wr_speciesIdentities[newIdentity.species] or forceIdentity)) or forceCustomization) and not speciesFile.noUnlock then
		world.sendEntityMessage(entity.id(), "wr_setSpeciesIdentity", newIdentity)
		local speciesCount = 0
		for _, _ in pairs(storage.wr_speciesIdentities) do
			speciesCount = speciesCount + 1
		end
		if player then
			if (speciesCount >= sbq.config.transformMenuUnlock) then
				player.makeTechAvailable("sbqTransform")
				player.enableTech("sbqTransform")
				player.radioMessage("sbqTransformUnlocked")
			elseif speciesCount >= 2 then
				player.radioMessage("sbqTransformedFirst")
				player.radioMessage("sbqTransformedHint")
			end
			if not speciesFile.forceName then
				player.interact("ScriptPane",{
					gui = {},
					scripts = { "/metagui/sbq/build.lua" },
					data = { identity = newIdentity, parameters = player.getHumanoidParameters() },
					ui = "starbecue:customize"
				}, player.id())
			end
		end
	end

	if duration and (not sbq.settings:get("indefiniteTF")) then
		status.addEphemeralEffect("sbqTransformed", (duration or sbq.config.defaultTFDuration) * 60)
	else
		world.sendEntityMessage(entity.id(), "sbqClearTransformed")
	end
	if sbq.settings:get("permanentTF") then
		world.sendEntityMessage(entity.id(), "wr_setOriginalIdentity", newIdentity)
	end
	return true
end

function sbq.revertTF()
	local currentIdentity = sbq.humanoid.humanoidIdentity()
	currentIdentity.parameters = sbq.humanoid.getHumanoidParameters()

	local newIdentity = storage.wr_originalIdentity
	if sb.jsonEqual(newIdentity, currentIdentity) then
		return false
	end
	world.sendEntityMessage(entity.id(), "wr_setCurrentIdentity", newIdentity)
end

function sbq.refreshPredHudPortrait()
	sbq.timer("predHudPortrait", 1, function()
		local loungeId = world.entity(entity.id()):anchorState()
		if loungeId then
			world.sendEntityMessage(loungeId, "sbqHudRefreshPortrait", entity.id())
		end
	end)
end
