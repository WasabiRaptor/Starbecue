
function sbq.humanoidInit()
	sbq.species = humanoid.species
	sbq.getItemSlot = humanoid.getItemSlot

	message.setHandler("sbqDoTransformation", function (_,_, ...)
		sbq.doTransformation(...)
	end)
	message.setHandler("sbqEndMysteriousPotionTF", function (_,_)
		sbq.revertTF()
	end)
	message.setHandler("sbqGetIdentity", function (_,_)
		return humanoid.getIdentity()
	end)
	message.setHandler("sbqDigestDrop", function(_, _, itemDrop)
		local itemDrop = itemDrop
		local identity = humanoid.getIdentity()
		local species = humanoid.species()
		local speciesFile = root.speciesConfig(species)
		itemDrop.parameters.predSpecies = species
		itemDrop.parameters.predDirectives = (identity.bodyDirectives or "") .. (identity.hairDirectives or "")
		itemDrop.parameters.predColorMap = speciesFile.baseColorMap
		world.spawnItem(itemDrop, mcontroller.position())
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

		return item
	end)
end

function sbq.directory()
	return "/humanoid/" .. humanoid.species() .. "/"
end


function sbq.doTransformation(newIdentity, duration, ...)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
	local currentIdentity =	humanoid.getIdentity()
	local speciesIdentites = status.statusProperty("sbqSpeciesIdentities") or {}
	local originalSpecies = status.statusProperty("sbqOriginalSpecies")
	local originalGender = status.statusProperty("sbqOriginalGender")

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


	newIdentity = sb.jsonMerge(
		humanoid.randomIdentity(newIdentity.species, newIdentity.personalityIndex, newIdentity.seed),
		newIdentity,
		((not newIdentity.force) and speciesIdentites[newIdentity.species]) or {}
	)

	local speciesFile = root.speciesConfig(newIdentity.species)

	if (not speciesIdentites[newIdentity.species]) and not speciesFile.noUnlock then
		local speciesCount = 0
		for _, _ in pairs(speciesIdentites) do
			speciesCount = speciesCount + 1
		end
		speciesIdentites[newIdentity.species] = newIdentity
		status.setStatusProperty("sbqSpeciesIdentities", speciesIdentites)
		if (speciesCount >= sbq.config.transformMenuUnlock) and player then
			player.enableTech("sbqTransform")
			player.radioMessage("sbqTransformUnlocked")
		end
	end

	humanoid.setIdentity(newIdentity)

	if duration and (not sbq.settings.indefiniteTF) then
		sbq.forceTimer("revertTF", (duration or 5) * 60, sbq.revertTF)
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
			world.sendEntityMessage(loungeAnchor.entityId, "sbqGuiMessage", "sbqHudRefreshPortrait", entity.id())
		end
	end)
end
