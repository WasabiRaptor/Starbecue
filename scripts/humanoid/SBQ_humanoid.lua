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

function refreshHumanoidParameters()
	local humanoid = (player or npc)
	old.refreshHumanoidParameters()
	local humanoidConfig = humanoid.humanoidConfig()

	sbq.refreshRemapTags()

	if humanoid.getHumanoidParameter("sbqEnabled") and sbq.init then
		sbq.init({root.speciesConfig(sbq.species()).voreConfig or "/humanoid/any/vore.config", config and config.getParameter("voreConfig")})
	end
end

function sbq.refreshRemapTags()
	local defaultColorMap = root.assetJson("/humanoid/any/sbqVoreParts/palette.config")
	local speciesConfig = root.speciesConfig(sbq.species())
	if speciesConfig.useImagePathSpecies then
		speciesConfig = root.speciesConfig(sbq.humanoidIdentity().imagePath or sbq.species())
	end
	for tag, remaps in pairs(speciesConfig.colorRemapGlobalTags or {}) do
		local sourceColorMap = sbq.query(speciesConfig, { "colorRemapSources", tag })
		if sourceColorMap then sourceColorMap = root.speciesConfig(sourceColorMap).baseColorMap end
		local directives = sbq.remapColor(remaps, sourceColorMap or defaultColorMap,
			speciesConfig.baseColorMap or defaultColorMap)
		--sb.logInfo(tag.." "..directives)
		animator.setGlobalTag(tag, directives)
	end
	for part, tags in pairs(speciesConfig.colorRemapPartTags or {}) do
		for tag, remaps in pairs(tags or {}) do
			local sourceColorMap = sbq.query(speciesConfig, { "colorRemapSources", part, tag }) or
				sbq.query(speciesConfig, { "colorRemapSources", tag })
			if sourceColorMap then sourceColorMap = root.speciesConfig(sourceColorMap).baseColorMap end
			local directives = sbq.remapColor(remaps, sourceColorMap or defaultColorMap,
				speciesConfig.baseColorMap or defaultColorMap)
			--sb.logInfo(tag.." "..directives)
			animator.setPartTag(part, tag, directives)
		end
	end
end

equipped = {}
function equipped.chestSlot(itemDescriptor)
	if not humanoid.getItemSlot("chestCosmetic") then
		equipped.chestCosmeticSlot(itemDescriptor)
	end
end

function equipped.legsSlot(itemDescriptor)
	if not humanoid.getItemSlot("legsCosmetic") then
		equipped.legsCosmeticSlot(itemDescriptor)
	end
end

function equipped.headSlot(itemDescriptor)
	if not humanoid.getItemSlot("headCosmetic") then
		equipped.headCosmeticSlot(itemDescriptor)
	end
end

function equipped.backSlot(itemDescriptor)
	if not humanoid.getItemSlot("backCosmetic") then
		equipped.backCosmeticSlot(itemDescriptor)
	end
end

function equipped.chestCosmeticSlot(itemDescriptor)
	if not itemDescriptor then itemDescriptor = humanoid.getItemSlot("chest") end
	if itemDescriptor then
		local item = root.itemConfig(itemDescriptor)
		if item then
			sbq.setStarpoundsSlot(item, "chest")
		end
	else
	end
	if SpeciesScript then
		SpeciesScript:settingAnimations()
	end
end

function equipped.legsCosmeticSlot(itemDescriptor)
	if not itemDescriptor then itemDescriptor = humanoid.getItemSlot("legs") end
	if itemDescriptor then
		local item = root.itemConfig(itemDescriptor)
		if item then
			sbq.setStarpoundsSlot(item, "legs")
		end
	else
	end
	if SpeciesScript then
		SpeciesScript:settingAnimations()
	end
end

function equipped.headCosmeticSlot(itemDescriptor)
	if not itemDescriptor then itemDescriptor = humanoid.getItemSlot("head") end
	if itemDescriptor then
		local item = root.itemConfig(itemDescriptor)
	else
	end
	if SpeciesScript then
		SpeciesScript:settingAnimations()
	end
end

function equipped.backCosmeticSlot(itemDescriptor)
	if not itemDescriptor then itemDescriptor = humanoid.getItemSlot("back") end
	if itemDescriptor then
		local item = root.itemConfig(itemDescriptor)
	else
	end
	if SpeciesScript then
		SpeciesScript:settingAnimations()
	end
end

function equipped.primary(itemDescriptor)
end

function equipped.alt(itemDescriptor)
end

local starpoundsSlot = {
	chest = false,
	legs = false
}
function sbq.setStarpoundsSlot(item, slot)
	starpoundsSlot[slot] = (item.config.tooltipKind == "starpoundsarmor")
	animator.setAnimationState("starpounds", tostring(sbq.checkStarpounds(slot)))
end

function sbq.checkStarpounds(slot)
	return starpoundsSlot.chest or starpoundsSlot.legs
end

function sbq.remapColor(remaps, fromMap, toMap)
	local directives = "?replace"
	for _, remap in ipairs(remaps or {}) do
		if remap[1] and remap[2] and toMap then
			local from = fromMap[remap[1]]
			local to = toMap[remap[2]]
			local check = remap[3]
			if from and to and sbq.tableMatches(check, sbq.settings, true) then
				for i, fromColor in ipairs(from) do
					local toColor = to[i] or to[#to]
					if (fromColor ~= toColor) then
						directives = directives .. ";" .. fromColor .. "=" .. toColor
					end
				end
			end
		elseif remap[1] then
			local from = fromMap[remap[1]]
			if from then
				for i, fromColor in ipairs(from) do
					directives = directives .. ";" .. fromColor .. "=00000000" -- so colors can be removed
				end
			end
		elseif sbq.tableMatches(remap.check, sbq.settings, true) then
			for color, replace in pairs(remap or {}) do
				if type(replace) == "string" then
					directives = directives .. ";" .. color .. "=" .. replace
				end
			end
			directives = directives .. "?replace"
		end
	end
	return ((directives ~= "?replace") and directives) or ""
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
		sbq.doTransformation(...)
	end)
	message.setHandler("sbqHybridTransformation", function(_, _, ...)
		sbq.hybridTransformation(...)
	end)
	message.setHandler("sbqRevertTF", function(_, _)
		sbq.revertTF()
	end)
	message.setHandler("sbqGetIdentity", function(_, _)
		return sbq.humanoidIdentity()
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
		elseif entityType == "player" then
			item.parameters.rarity = "legendary"
			item.parameters.npcArgs.npcType = "generictenant"
			item.parameters.npcArgs.npcLevel = 1
			item.parameters.npcArgs.npcSeed = 1
			item.parameters.tooltipFields.subtitle = "player"
			item.parameters.npcArgs.npcParam.wasPlayer = true
		end
		local identity = sbq.humanoidIdentity()
		item.parameters.npcArgs.npcSpecies = sbq.species()
		item.parameters.shortdescription = world.entityName(entity.id())
		item.parameters.npcArgs.npcParam.identity = identity
		item.parameters.npcArgs.npcParam.scriptConfig.sbqSettings = sbq.getSettingsOf.current()
		item.parameters.npcArgs.npcParam.scriptConfig.sbqUpgrades = storage.sbqUpgrades
		item.parameters.npcArgs.npcParam.scriptConfig.uniqueId = entity.uniqueId()
		item.parameters.tooltipFields.collarNameLabel = sbq.createdDateString()
		item.parameters.createdDate = sbq.createdDate()
		item.parameters.tooltipFields.objectImage = world.entityPortrait(entity.id(), "full")
		item.parameters.inventoryIcon = world.entityPortrait(entity.id(), "bust")
		item.parameters.preySize = sbq.size()
		item.parameters.npcArgs.npcParam.statusControllerSettings.statusProperties.sbqPronouns = status.statusProperty(
		"sbqPronouns")
		return item
	end)
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

function sbq.hybridTransformation(newSpecies, duration, ...)
	local newSpeciesConfig = root.speciesConfig(newSpecies)
	local curIdentity = sbq.humanoidIdentity()
	local newIdentity = { species = newSpecies }
	if newSpecies ~= curIdentity.species then
		local curSpeciesConfig = root.speciesConfig(curIdentity.species)
		if (newSpeciesConfig.hybridSpeciesBlacklist or {})[curIdentity.species] then
			player.radioMessage("sbqHybridBlacklisted")
			sbq.logWarn("Attempted to hybridize blacklisted species for " .. newSpecies .. ": " .. newIdentity.species)
			return
		end
		if not curSpeciesConfig.voreConfig then
			player.radioMessage("sbqHybridUnsupported")
		end

		for _, v in ipairs(curSpeciesConfig.hybridAppendIdentity or {}) do
			if v[3] then
				curIdentity[v[1]] = curIdentity[v[2]]
			else
				curIdentity[v[1]] = curIdentity[v[1]] .. curIdentity[v[2]]
			end
		end

		for k, v in pairs(curIdentity) do
			if not (newSpeciesConfig.hybridCopyIdentityBlacklist or {})[k] then newIdentity[k] = v end
		end
		newIdentity.imagePath = curIdentity.species
		newIdentity.species = newSpecies
		sbq.doTransformation(newIdentity, duration, true, true, ...)
	else
		newIdentity.imagePath = newSpecies
		sbq.doTransformation(newIdentity, duration, true, true, ...) -- forces customization data to be cleared and regenerated
	end
end

function sbq.doTransformation(newIdentity, duration, forceIdentity, forceCustomization, ...)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
	if sbq.config.transformationBlacklist[sbq.species()] then
		if player then
			sbq.logWarn("Attempted to transform as blacklisted species: " .. newIdentity.species)
			player.radioMessage("sbqTransformFromBlacklist")
		end
		return false
	end

	local currentIdentity = sbq.humanoidIdentity()
	local speciesIdentites = status.statusProperty("sbqSpeciesIdentities") or {}
	local originalSpecies = status.statusProperty("sbqOriginalSpecies")
	local originalGender = status.statusProperty("sbqOriginalGender")
	local currentName = currentIdentity.name

	if not originalSpecies then
		originalSpecies = sbq.species()
		status.setStatusProperty("sbqOriginalSpecies", originalSpecies)
		speciesIdentites[originalSpecies] = currentIdentity
		status.setStatusProperty("sbqSpeciesIdentities", speciesIdentites)
	end
	if not originalGender then
		originalGender = sbq.gender()
		status.setStatusProperty("sbqOriginalGender", originalGender)
	end

	if sbq.settings.genderTF then
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

	if sbq.settings.speciesTF then
		if newIdentity.species == "any" then
			local speciesList = root.assetJson("/interface/windowconfig/charcreation.config").speciesOrdering
			local badSpecies = true
			while badSpecies do
				local i = math.random(#speciesList)
				newIdentity.species = speciesList[i]
				badSpecies = sbq.config.transformationBlacklist[newIdentity.species] or false
				if not badSpecies then
					local speciesFile = root.speciesConfig(newIdentity.species)
					if speciesFile.forceName then
						badSpecies = true
					elseif speciesFile.voreConfig then
						if sbq.query(sbq.fetchConfigArray(speciesFile.voreConfig) or {}, { "overrideSettings", "speciesTF" }) == false then
							badSpecies = true
						end
					elseif sbq.config.anyTFSupportedOnly then
						badSpecies = true
					end
				end
				if badSpecies then
					table.remove(speciesList, i)
				end
			end
		elseif newIdentity.species == "originalSpecies" then
			newIdentity.species = originalSpecies
		elseif not newIdentity.species then
			newIdentity.species = currentIdentity.species
		end
	else
		newIdentity.species = currentIdentity.species
	end
	local oldSpeciesFile = root.speciesConfig(currentIdentity.species)
	local speciesFile = root.speciesConfig(newIdentity.species)
	if not speciesFile then return false end
	newIdentity.species = speciesFile.kind
	if sbq.config.transformationBlacklist[newIdentity.species] then
		if player then
			sbq.logWarn("Attempted to transform into blacklisted species: " .. newIdentity.species)
			player.radioMessage("sbqTransformIntoBlacklist")
		end
		return false
	end
	if npc and speciesFile.voreConfig then
		if sbq.query(sbq.fetchConfigArray(speciesFile.voreConfig) or {}, { "overrideSettings", "speciesTF" }) == false then
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
	if not speciesIdentites[newIdentity.species] then
		-- if oldSpeciesFile.baseColorMap and speciesFile.baseColorMap then
		-- 	for k, oldColors in pairs(oldSpeciesFile.baseColorMap) do
		-- 		for k2, newColors in pairs(speciesFile.baseColorMap) do
		-- 			if (#oldColors >= #newColors) and (k == k2) then
		-- 				for i, color in ipairs(newColors) do
		-- 					preserveColors[color:lower()] = sbq.findIdentityColor(currentIdentity, oldColors[i])
		-- 				end
		-- 			end
		-- 		end
		-- 	end
		-- end
	end

	if not forceIdentity then
		newIdentity.name = currentName
	end
	if speciesFile.forceName then
		newIdentity.name = speciesFile.forceName
	end

	newIdentity = sb.jsonMerge(
		root.generateHumanoidIdentity(newIdentity.species, newIdentity.seed, newIdentity.gender),
		newIdentity,
		((not forceIdentity) and speciesIdentites[newIdentity.species]) or {},
		{ gender = newIdentity.gender } -- preserve new gender if applicable
	)
	if not (forceIdentity or speciesIdentites[newIdentity.species]) then
		-- for k, v in pairs(newIdentity) do
		-- 	if type(v) == "string" and v:find("replace;") then
		-- 		local newString = v:lower()
		-- 		if not newString:sub(-1) == ";" then
		-- 			newString = newString..";"
		-- 		end
		-- 		for color, replace in pairs(preserveColors) do
		-- 			newString = newString:gsub(color .. "%b=;", color .. "=" .. replace .. ";")
		-- 		end
		-- 		newIdentity[k] = newString
		-- 	end
		-- end
	end

	if ((not speciesIdentites[newIdentity.species]) or forceCustomization) and not speciesFile.noUnlock then
		speciesIdentites[newIdentity.species] = newIdentity
		local speciesCount = 0
		for _, _ in pairs(speciesIdentites) do
			speciesCount = speciesCount + 1
		end

		status.setStatusProperty("sbqSpeciesIdentities", speciesIdentites)
		if player then
			if (speciesCount >= sbq.config.transformMenuUnlock) then
				player.makeTechAvailable("sbqTransform")
				player.enableTech("sbqTransform")
				player.radioMessage("sbqTransformUnlocked")
			elseif speciesCount >= 2 then
				player.radioMessage("sbqTransformedFirst")
				player.radioMessage("sbqTransformedHint")
			end
		end
	end

	sbq.setHumanoidIdentity(newIdentity)

	if duration and (not sbq.settings.indefiniteTF) then
		status.addEphemeralEffect("sbqTransformed", (duration or sbq.config.defaultTFDuration) * 60)
	else
		world.sendEntityMessage(entity.id(), "sbqClearTransformed")
	end
	if sbq.settings.permanentTF then
		status.setStatusProperty("sbqOriginalSpecies", newIdentity.species)
		status.setStatusProperty("sbqOriginalGender", newIdentity.gender)
	end
	sbq.refreshPredHudPortrait()
end

function sbq.revertTF()
	local currentData = sbq.humanoidIdentity()
	local originalSpecies = status.statusProperty("sbqOriginalSpecies") or sbq.species()
	local originalGender = status.statusProperty("sbqOriginalGender") or sbq.gender()
	local speciesIdentities = status.statusProperty("sbqSpeciesIdentities") or {}
	local customData = speciesIdentities[originalSpecies] or
	root.generateHumanoidIdentity(originalSpecies, math.randomseed(), originalGender)
	customData.gender = originalGender
	sbq.setHumanoidIdentity(customData)
	sbq.refreshPredHudPortrait()
end

function sbq.refreshPredHudPortrait()
	sbq.timer("predHudPortrait", 1, function()
		local loungeId = world.entityAnchorState(entity.id())
		if loungeId then
			world.sendEntityMessage(loungeId, "sbqScriptPaneMessage", "sbqHudRefreshPortrait", entity.id())
		end
	end)
end
