local speciesFile
function build(directory, config, parameters, level, seed)

	if parameters ~= nil then
		if parameters.species then
			speciesFile = root.speciesConfig(parameters.species)
			if speciesFile then
                config.shortdescription = speciesFile.charCreationTooltip.title .. " Potion"
				parameters.potionPath = speciesFile.potionPath or parameters.potionPath
			end
		end
		if parameters.name then
			config.shortdescription = parameters.name.." Potion"
		end
		local directives = ((parameters.directives or "")..(parameters.bodyDirectives or "")..(parameters.secondaryDirectives or ""))
		if parameters.potionPath then
			config.inventoryIcon = parameters.potionPath.."sbqPotion.png"..directives
			config.largeImage = parameters.potionPath.."sbqPotionLarge.png"..directives
			config.animationParts = {
				potion = parameters.potionPath.."sbqPotion.png"..directives
			}
		end
	end
	return config, parameters
end
