local speciesFile
local strings
sbq = {}
function build(directory, config, parameters, level, seed)
	local config = sb.jsonMerge(config, parameters or {})
	strings = root.assetJson("/sbqStrings.config")
	sbq.config = root.assetJson("/sbq.config")

	if config.species then
		speciesFile = root.speciesConfig(config.species)
		if speciesFile then
			config.shortdescription = sb.replaceTags(speciesFile.hybridPotionShortDesc or strings.speciesHybridPotionName, {species = speciesFile.charCreationTooltip.title, duration = tostring(config.duration)})
			config.description = sb.replaceTags(speciesFile.hybridPotionDesc or strings.speciesHybridPotionDesc, {species = speciesFile.charCreationTooltip.title, duration = tostring(config.duration)})
			config.inventoryIcon = (speciesFile.potionImagePath or "") .. "potion.png"
			config.largeImage = (speciesFile.potionImagePath or "") .. "potionLarge.png"
			if speciesFile.baseColorMap then
				-- TODO make potions use the species colors
			end
			if speciesFile.potionRarity then
				parameters.rarity = speciesFile.potionRarity
			else
				parameters.rarity = "rare"
			end
		end
	end
	parameters.animationParts = {
		potion = config.inventoryIcon
	}

	return config, parameters
end
