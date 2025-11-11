


function build(directory, config, parameters, level, seed)
	_ENV.build = nil
	config = sb.jsonMerge(config, parameters)

	local speciesConfig = root.speciesConfig(config.species)
	local humanoidConfig = sb.jsonMerge(root.assetJson(speciesConfig.humanoidConfig or "/humanoid.config"), speciesConfig.humanoidOverrides or {})
	if not humanoidConfig.sbqOccupantSlots then
		humanoidConfig.sbqOccupantSlots = 1
	end
	if (not parameters.identity) or (not parameters.humanoidParameters) then
		parameters.identity, parameters.humanoidParameters = root.generateHumanoidIdentity(config.species)
	end
	parameters.humanoidParameters.sbqEnabled = true
	if speciesConfig.buildScripts then
		for i, v in ipairs(speciesConfig.buildScripts) do
			sb.logInfo(i)
			sb.logInfo(v)
			require(v)
		end
		humanoidConfig = _ENV.build(parameters.identity, parameters.humanoidParameters, humanoidConfig)
	end
	parameters.animationCustom = humanoidConfig.animation
	parameters.sbqConfig = humanoidConfig.sbqConfig
	parameters.sbqConfig.debug = true
	parameters.sbqSettingsConfig = humanoidConfig.sbqSettingsConfig
	parameters.loungePositions = humanoidConfig.loungePositions

	return config, parameters
end
