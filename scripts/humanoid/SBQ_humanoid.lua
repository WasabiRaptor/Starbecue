
function sbq.humanoidInit()
	sbq.species = humanoid.species
	sbq.getItemSlot = humanoid.getItemSlot

	message.setHandler("sbqDoTransformation", function (_,_, ...)
		sbq.doTransformation(...)
	end)
	message.setHandler("sbqRevertTF", function (_,_)
		sbq.revertTF()
	end)
	message.setHandler("sbqGetIdentity", function (_,_)
		return humanoid.getIdentity()
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
		local identity = humanoid.getIdentity()
		item.parameters.npcArgs.npcSpecies = humanoid.species()
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
		item.parameters.npcArgs.npcParam.statusControllerSettings.statusProperties.sbqPronouns = status.statusProperty("sbqPronouns")
		return item
	end)
end

function sbq.directory()
	return "/humanoid/" .. humanoid.species() .. "/"
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

function sbq.doTransformation(newIdentity, duration, ...)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
	if sbq.config.transformationBlacklist[humanoid.species()] then
		if player then sbq.logWarn("Attempted to transform as blacklisted species: ".. newIdentity.species) player.radioMessage("sbqTransformFromBlacklist") end
		return false
	end

	local force = newIdentity.force
	local currentIdentity =	humanoid.getIdentity()
	local speciesIdentites = status.statusProperty("sbqSpeciesIdentities") or {}
	local originalSpecies = status.statusProperty("sbqOriginalSpecies")
	local originalGender = status.statusProperty("sbqOriginalGender")
	local currentName = currentIdentity.name

	if not originalSpecies then
		originalSpecies = humanoid.species()
		status.setStatusProperty("sbqOriginalSpecies", originalSpecies)
		speciesIdentites[originalSpecies] = currentIdentity
		status.setStatusProperty("sbqSpeciesIdentities", speciesIdentites)
	end
	if not originalGender then
		originalGender = humanoid.gender()
		status.setStatusProperty("sbqOriginalGender", originalGender)
	end

	if sbq.settings.genderTF then
		if newIdentity.gender == "random" then
			newIdentity.gender = ({"male", "female"})[math.random(2)]
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
						if sbq.query(root.fetchConfigArray(speciesFile.voreConfig) or {}, {"overrideSettings", "speciesTF"}) == false then
							badSpecies = true
						end
					elseif sbq.config.anyTFSupportedOnly then
						badSpecies = true
					end
				end
				if badSpecies then
					table.remove(speciesList,i)
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
		if player then sbq.logWarn("Attempted to transform into blacklisted species: ".. newIdentity.species) player.radioMessage("sbqTransformIntoBlacklist") end
		return false
	end
	if npc and speciesFile.voreConfig then
		if sbq.query(root.fetchConfigArray(speciesFile.voreConfig) or {}, {"overrideSettings", "speciesTF"}) == false then
			sbq.logWarn("NPC cannot be transformed into TF locked species: " .. newIdentity.species)
			return false
		end
	end
	if player and not (
		root.assetExists(sb.replaceTags(root.assetJson("/client.config:respawnCinematic"), {species = newIdentity.species, mode = "casual"}))
		and root.assetExists(sb.replaceTags(root.assetJson("/client.config:respawnCinematic"), {species = newIdentity.species, mode = "survival"}))
		and root.assetExists(sb.replaceTags(root.assetJson("/client.config:warpCinematic"), {species = newIdentity.species}))
		and root.assetExists(sb.replaceTags(root.assetJson("/client.config:deployCinematic"), {species = newIdentity.species}))
		and root.assetJson("/universe_server.config:speciesShips")[newIdentity.species]
		and root.assetJson("/ai/ai.config:species")[newIdentity.species]
		and root.assetJson("/quests/quests.config:initialquests")[newIdentity.species]
	) then
		player.radioMessage("sbqTransformNPCOnly")
		sbq.logWarn("Attempted to transform into NPC only species: "..newIdentity.species)
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

	if not force then
		newIdentity.name = currentName
	end
	if speciesFile.forceName then
		newIdentity.name = speciesFile.forceName
	end

	newIdentity = sb.jsonMerge(
		humanoid.randomIdentity(newIdentity.species, newIdentity.personalityIndex, newIdentity.seed),
		newIdentity,
		((not force) and speciesIdentites[newIdentity.species]) or {},
		{gender = newIdentity.gender} -- preserve new gender if applicable
	)
	if not (force or speciesIdentites[newIdentity.species]) then
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

	if (not speciesIdentites[newIdentity.species]) and not speciesFile.noUnlock then
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

	humanoid.setIdentity(newIdentity)

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
	local currentData = humanoid.getIdentity()
	local originalSpecies = status.statusProperty("sbqOriginalSpecies") or humanoid.species()
	local originalGender = status.statusProperty("sbqOriginalGender") or humanoid.gender()
	local speciesIdentities = status.statusProperty("sbqSpeciesIdentities") or {}
	local customData = speciesIdentities[originalSpecies] or humanoid.randomIdentity(originalSpecies, currentData.personalityIndex)
	customData.gender = originalGender
	humanoid.setIdentity(customData)
	sbq.refreshPredHudPortrait()
end

function sbq.refreshPredHudPortrait()
	sbq.timer("predHudPortrait", 1, function ()
		local loungeAnchor = world.entityCurrentLounge(entity.id())
		if loungeAnchor then
			world.sendEntityMessage(loungeAnchor.entityId, "scriptPaneMessage", "sbqHudRefreshPortrait", entity.id())
		end
	end)
end
