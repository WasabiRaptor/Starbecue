function build(directory, config, parameters, level, seed)
	local strings = root.assetJson("/sbqStrings.config")
	parameters.level = math.floor(math.max(parameters.level or 0, level or 0, 1))
	parameters.seed = parameters.seed or seed or 0
	config = sb.jsonMerge(config, parameters)
	math.randomseed(parameters.seed);

	config.inventoryIcon = "sbqCandyT" .. math.floor(parameters.level) .. ".png"
	if not root.assetOrigin(directory..config.inventoryIcon) then
		config.inventoryIcon = "sbqCandyT"..math.random(1,6)..".png"
	end
	local max = math.ceil(parameters.level/2)
	if (not parameters.bonus) and (parameters.seed and (parameters.seed ~= 0)) then
		parameters.bonus = 1
		for i = 1, max do
			if math.random() > 0.5 then parameters.bonus = parameters.bonus + 1 end
		end
		config.inventoryIcon = config.inventoryIcon..((parameters.bonus == (max + 1)) and "?border=1;00FF00FF;00FF0088;" or "").."?hueshift="..math.random(0,360)..";"
	elseif parameters.bonus and (parameters.bonus > 1) then
		config.inventoryIcon = config.inventoryIcon..((parameters.bonus == (max + 1)) and "?border=1;00FF00FF;00FF0088;" or "").."?hueshift="..math.random(0,360)..";"
	end
	config.shortdescription = strings.candyName[config.level] or (strings.mysteryCandyName.." (T"..math.floor(parameters.level)..")")
	config.description = strings.candyDesc[config.level] or strings.mysteryCandyDesc
	config.foodValue = config.foodValue * config.level
	config.price = config.price * config.level

	return config, parameters
end
