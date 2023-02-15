
function build(directory, config, parameters, level, seed)

	if parameters ~= nil then
		if parameters.species then
			local success, speciesFile = pcall(root.assetJson, ("/species/"..parameters.species..".species") )
			if success then
				config.shortdescription = speciesFile.charCreationTooltip.title.." Potion"
			end
		end
		if parameters.name then
			config.shortdescription = parameters.name.." Potion"
		end
		local directives = ((parameters.directives or "")..((parameters.identity or {}).bodyDirectives or ""))..(parameters.potionDirectives or "")
		local largeDirectives = ((parameters.directives or "")..((parameters.identity or {}).bodyDirectives or ""))..(parameters.potionDirectives or "")

		if parameters.species and not parameters.specialPotionIcon then
			local success, notEmpty = pcall(root.nonEmptyRegion, "/humanoid/"..(parameters.species).."/sbqPotion.png")
			if success and notEmpty ~= nil then
				parameters.potionPath = "/humanoid/"..(parameters.species).."/"
			end
		end
		if parameters.potionPath then
			local success, notEmpty = pcall(root.nonEmptyRegion, parameters.potionPath.."/sbqPotionBlend.png")
			if success and notEmpty ~= nil then
				directives = directives.."?blendmult="..parameters.potionPath.."/sbqPotionBlend.png"
				largeDirectives = largeDirectives.."?blendmult="..parameters.potionPath.."/sbqPotionLargeBlend.png"
			end

			config.inventoryIcon = parameters.potionPath.."sbqPotion.png"..directives
			config.largeImage = parameters.potionPath.."sbqPotionLarge.png"..largeDirectives
			config.animationParts = {
				potion = parameters.potionPath.."sbqPotion.png"..directives
			}
		end
	end

	return config, parameters
end
