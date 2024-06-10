
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
		item.parameters.npcArgs.npcParam.scriptConfig.sbqSettings = sbq.getSettingsOf.all()
		item.parameters.tooltipFields.collarNameLabel = sbq.createdDate()
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


function sbq.doTransformation(newIdentity, duration, ...)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
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
		elseif not newIdentity.gender then
			newIdentity.gender = currentIdentity.gender
		end
	else
		newIdentity.gender = currentIdentity.gender
	end

	if sbq.settings.speciesTF then
		if newIdentity.species == "any" then
			local speciesList = root.assetJson("/interface/windowconfig/charcreation.config").speciesOrdering
			newIdentity.species = speciesList[math.random(#speciesList)]
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
	local preserveColors = {

	}
	if oldSpeciesFile.baseColorMap and speciesFile.baseColorMap then
		for _, oldColors in pairs(oldSpeciesFile.baseColorMap) do
			for _, newColors in pairs(speciesFile.baseColorMap) do
				if #oldColors == #newColors then
					local same = true
					for k, v in ipairs(oldColors) do
						if not v == newColors[k] then same = false break end
					end
					if same then
						for _, v in ipairs(oldColors) do
							preserveColors[v] = true
						end
					end
				end
			end
		end
	end
	for color, _ in pairs(preserveColors) do
		for k, v in pairs(currentIdentity) do
			if type(v) == "string" then
				local _, last = string.find(v, color .. "=")
				if last then
					local _, found = string.find(v, ";", last)
					if found then
						preserveColors[color] = string.sub(v, last+1, found-1)
					end
				end
			end
		end
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
		((not force) and speciesIdentites[newIdentity.species]) or {}
	)
	if not force then
		for k, v in pairs(newIdentity) do
			if type(v) == "string" then
				for color, replace in pairs(preserveColors) do
					if type(replace) == "string" then
						newIdentity[k] = string.gsub(v, color.."%b=;", color.."="..replace..";")
					end
				end
			end
		end
	end

	if (not speciesIdentites[newIdentity.species]) and not speciesFile.noUnlock then
		local speciesCount = 0
		for _, _ in pairs(speciesIdentites) do
			speciesCount = speciesCount + 1
		end
		speciesIdentites[newIdentity.species] = newIdentity
		status.setStatusProperty("sbqSpeciesIdentities", speciesIdentites)
		if (speciesCount >= sbq.config.transformMenuUnlock) and player then
			player.makeTechAvailable("sbqTransform")
			player.enableTech("sbqTransform")
			player.radioMessage("sbqTransformUnlocked")
		end
	end

	humanoid.setIdentity(newIdentity)

	if duration and (not sbq.settings.indefiniteTF) then
		status.addEphemeralEffect("sbqTransformed", (duration or sbq.config.defaultTFDuration) * 60)
	end
	if sbq.settings.permanentTF then
		status.setStatusProperty("sbqOriginalSpecies", newIdentity.species)
		status.setStatusProperty("sbqOriginalGender", newIdentity.gender)
	end
	sbq.refreshPredHudPortrait()
	if sbq.reloadVoreConfig then
		sbq.reloadVoreConfig({root.speciesConfig(humanoid.species()).voreConfig or "/humanoid/any/vore.config", config and config.getParameter("voreConfig")})
	end
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
