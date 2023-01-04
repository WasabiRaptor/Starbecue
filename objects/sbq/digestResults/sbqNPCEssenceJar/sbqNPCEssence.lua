function build(directory, config, parameters, level, seed)
	config = sb.jsonMerge(config, parameters)
	if (config or {}).npcArgs ~= nil then
		parameters.tooltipKind = "filledcapturepod"
		parameters.tooltipFields = parameters.tooltipFields or {}
		parameters.tooltipFields.subtitle = (config.npcArgs.wasPlayer and "Player") or config.npcArgs.npcType or "generictenant"
		parameters.tooltipFields.noCollarLabel = ""

		local success, speciesFile = pcall(root.assetJson, ("/species/"..(config.npcArgs.npcSpecies or "")..".species"))

		local colorRemap = "?replace"
		config.baseColorMap = config.baseColorMap or {
			primary = { "6f2919", "a85636", "e0975c", "ffca8a" },
			secondary = { "951500", "be1b00", "dc1f00", "f32200" }
		}

		for colorName, from in pairs(config.baseColorMap) do
			local to = ((success and speciesFile) or config.speciesFile).baseColorMap[colorName] or from
			for i, color in ipairs(from or {}) do
				colorRemap = colorRemap .. ";" .. color .. "=" .. (to[i] or to[#to])
			end
		end

		parameters.directives = colorRemap ..
				((((config.npcArgs.npcParam or {}).identity or {}).bodyDirectives or "") ..
					(((config.npcArgs.npcParam or {}).identity or {}).hairDirectives or ""))


		if success then
			parameters.inventoryIcon = root.npcPortrait("bust", config.npcArgs.npcSpecies, config.npcArgs.npcType or "generictenant",
				config.npcArgs.npcLevel or 1, config.npcArgs.npcSeed, config.npcArgs.npcParam)

			parameters.tooltipFields.collarNameLabel = ""

			local npcConfig = root.npcConfig(config.npcArgs.npcType)

			parameters.description = npcConfig.scriptConfig.cardDesc or parameters.description or ""

			parameters.tooltipFields.objectImage = config.fullPortrait or
			root.npcPortrait("full", config.npcArgs.npcSpecies, config.npcArgs.npcType or "generictenant",
					config.npcArgs.npcLevel or 1, config.npcArgs.npcSeed, config.npcArgs.npcParam)
		elseif config.speciesFile then

			parameters.inventoryIcon = (config.useIcon or "/objects/sbq/digestResults/sbqNPCEssenceJar/sbqNPCEssenceJarCombo.png")..parameters.directives

			parameters.tooltipFields.collarNameLabel = "^red;Placeholder"
		end
	end

	return config, parameters
end
