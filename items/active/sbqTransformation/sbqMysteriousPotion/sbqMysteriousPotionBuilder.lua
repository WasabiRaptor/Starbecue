local speciesFile
local strings
function build(directory, config, parameters, level, seed)
    local config = sb.jsonMerge(config, parameters or {})
	strings = root.assetJson("/sbqStrings.config")
	if config.args and config.args[1] then
        local identity = config.args[1]
        if identity.species then
            if identity.species == "any" then
                config.shortdescription = strings.mysteryPotionName
				config.description = strings.mysteryPotionDesc
			else
				speciesFile = root.speciesConfig(identity.species)
				if speciesFile then
					config.shortdescription = sb.replaceTags(strings.speciesPotionName, {species = speciesFile.charCreationTooltip.title, duration = tostring(config.duration)})
					config.description = sb.replaceTags(strings.speciesPotionDesc, {species = speciesFile.charCreationTooltip.title, duration = tostring(config.duration)})
					if speciesFile.potionImagePath then
                        config.inventoryIcon = speciesFile.potionImagePath .. "potion.png"
						config.largeImage = speciesFile.potionImagePath .. "potionLarge.png"
					end
					if speciesFile.baseColorMap then
						-- TODO make potions use the species colors
                    end
				end
			end
        end
        if identity.name then
            config.shortdescription = sb.replaceTags(strings.duplicatePotionName, { name = identity.name, duration = tostring(config.duration) })
			config.description = sb.replaceTags(strings.duplicatePotionDesc, {name = identity.name, duration = tostring(config.duration)})
		end
	end

	return config, parameters
end
