function build(directory, config, parameters, level, seed)
	local strings = root.assetJson("/sbqStrings.config")
    parameters.level = math.max(parameters.level or 0, level or 0, 1)
	parameters.seed = parameters.seed or seed
    config = sb.jsonMerge(config, parameters)
    math.randomseed(parameters.seed);

    config.inventoryIcon = "sbqCandyT" .. parameters.level .. ".png"
	if not root.assetExists(directory..config.inventoryIcon) then
		config.inventoryIcon = "sbqCandyT"..math.random(1,6)".png?hueshift="..math.random(0,360)..";"
	end
    config.shortdescription = strings.candyName[config.level] or strings.mysteryCandyName
    config.description = strings.candyDesc[config.level] or strings.mysteryCandyDesc
    config.foodValue = config.foodValue * config.level
	config.price = config.price * config.level

	return config, parameters
end
