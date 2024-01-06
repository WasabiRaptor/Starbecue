
require("/scripts/speciesAnimOverride_validateIdentity.lua")

function build(directory, config, parameters, level, seed)
	config = sb.jsonMerge(config, parameters)
	if (config or {}).npcArgs ~= nil then
		parameters.tooltipKind = "filledcapturepod"
		parameters.tooltipFields = parameters.tooltipFields or {}
		parameters.tooltipFields.subtitle = (config.npcArgs.npcParam.wasPlayer and "Player") or config.npcArgs.npcType or "generictenant"
		parameters.tooltipFields.noCollarLabel = ""

		local speciesFile = root.speciesConfig(config.npcArgs.npcSpecies)

		local colorRemap = "?replace"
		config.baseColorMap = config.baseColorMap or {
			primary = { "6f2919", "a85636", "e0975c", "ffca8a" },
			secondary = { "951500", "be1b00", "dc1f00", "f32200" }
		}

		for colorName, from in pairs(config.baseColorMap) do
			local to = ((speciesFile) or config.speciesFile).baseColorMap[colorName] or from
			if from and to then
				for i, color in ipairs(from or {}) do
					colorRemap = colorRemap .. ";" .. color .. "=" .. (to[i] or to[#to])
				end
			end
		end

		parameters.directives = colorRemap ..
				((((config.npcArgs.npcParam or {}).identity or {}).bodyDirectives or "") ..
					(((config.npcArgs.npcParam or {}).identity or {}).hairDirectives or ""))

		local success2, npcConfig = pcall(root.npcConfig, (config.npcArgs.npcType))
		if speciesFile and success2 then
			validateIdentity(config.npcArgs.npcParam.identity or {})

			parameters.inventoryIcon = root.npcPortrait("bust", config.npcArgs.npcSpecies, config.npcArgs.npcType or "generictenant",
				config.npcArgs.npcLevel or 1, config.npcArgs.npcSeed, sb.jsonMerge(config.npcArgs.npcParam, parameters.portraitNpcParam or {}))

			parameters.tooltipFields.collarNameLabel = ""

			parameters.description = npcConfig.scriptConfig.cardDesc or parameters.description or "A Container filled with "..((config.npcArgs.npcParam.identity or {}).name or "Someone").."'s Essence"

			parameters.tooltipFields.objectImage = config.fullPortrait or
			root.npcPortrait("full", config.npcArgs.npcSpecies, config.npcArgs.npcType or "generictenant",
					config.npcArgs.npcLevel or 1, config.npcArgs.npcSeed, sb.jsonMerge(config.npcArgs.npcParam, parameters.portraitNpcParam or {}))
		elseif config.speciesFile or (speciesFile) then

			parameters.inventoryIcon = (config.useIcon or "/objects/sbq/digestResults/sbqNPCEssenceJar/sbqNPCEssenceJarCombo.png")..parameters.directives

			parameters.tooltipFields.collarNameLabel = "^red;Placeholder"
		end
	end

	return config, parameters
end
