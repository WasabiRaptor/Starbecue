local speciesFile
local strings
sbq = {}
function build(directory, config, parameters, level, seed)
	local config = sb.jsonMerge(config, parameters or {})
	strings = root.assetJson("/sbqStrings.config")
	sbq.config = root.assetJson("/sbq.config")

	config.identity = parameters.identity or (parameters.args or {})[1] or config.identity or config.args[1]
	config.duration = parameters.duration or (parameters.args or {})[2] or config.duration or config.args[2] or sbq.config.defaultTFDuration

	parameters.args = {
		config.identity,
		config.duration
	}

	if config.identity then
		if config.identity.species then
			if config.identity.species == "any" then
				config.shortdescription = strings.mysteryPotionName
				config.description = strings.mysteryPotionDesc
			elseif sbq.config.transformationBlacklist[config.identity.species] then
				speciesFile = root.speciesConfig(config.identity.species)
				config.shortdescription = sb.replaceTags(strings.invalidPotionName, { species = speciesFile.charCreationTooltip.title, duration = tostring(config.duration) })
				config.description = sb.replaceTags(strings.invalidPotionDesc, {species = speciesFile.charCreationTooltip.title, duration = tostring(config.duration)})
				config.inventoryIcon = "/interface/xhover.png"
				config.largeImage = "/interface/xhover.png"
				config.invalidPotion = true
				return config, parameters
			else
				speciesFile = root.speciesConfig(config.identity.species)
				if speciesFile then
					config.shortdescription = sb.replaceTags(speciesFile.potionShortDesc or strings.speciesPotionName, {species = speciesFile.charCreationTooltip.title, duration = tostring(config.duration)})
					config.description = sb.replaceTags(speciesFile.potionDesc or strings.speciesPotionDesc, {species = speciesFile.charCreationTooltip.title, duration = tostring(config.duration)})
					config.inventoryIcon = (speciesFile.potionImagePath or "") .. "potion.png"
					config.largeImage = (speciesFile.potionImagePath or "") .. "potionLarge.png"
					if speciesFile.baseColorPalette then
						-- TODO make potions use the species colors
					end
					if speciesFile.potionRarity then
						parameters.rarity = speciesFile.potionRarity
					else
						parameters.rarity = "rare"
					end
					if speciesFile.forceName then
						config.identity.name = speciesFile.forceName
					end
				end
			end
		end
		if config.identity.name then
			config.shortdescription = sb.replaceTags(strings.duplicatePotionName, { name = config.identity.name, duration = tostring(config.duration) })
			config.description = sb.replaceTags(strings.duplicatePotionDesc, {name = config.identity.name, duration = tostring(config.duration)})
		end
	end
	parameters.animationParts = {
		potion = config.inventoryIcon
	}

	return config, parameters
end
