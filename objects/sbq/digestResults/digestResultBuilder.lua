
function build( directory, config, parameters, level, seed )
	parameters.originalColonyTags = parameters.originalColonyTags or config.colonyTags
	parameters.colonyTags = parameters.originalColonyTags
	config = sb.jsonMerge(config, parameters)

	if not parameters.generated then
		parameters.generated = true
		local preyPossessive = "'s"
		if config.prey then
			if config.prey:sub(-1,-1) == "s" then
				preyPossessive = "'"
			end
			if config.preyUUID then
				table.insert(config.colonyTags, config.objectName.."Prey"..config.preyUUID)
			end
		end
		local predPossessive = "'s"
		if config.pred then
			if config.pred:sub(-1,-1) == "s" then
				predPossessive = "'"
			end
			if config.predUUID then
				table.insert(config.colonyTags, config.objectName.."Pred"..config.predUUID)
			end
		end
		local replaceTagTable = { predName = config.pred, preyName = config.prey, predPossessive = predPossessive, preyPossessive = preyPossessive}

		local description
		local shortdescription
		if config.pred and config.prey then
			if type(config.replaceDescPredPrey) == "table" then
				local random = math.random(#config.replaceDescPredPrey)
				description = config.replaceDescPredPrey[random][1]
				shortdescription = config.replaceDescPredPrey[random][2] or config.replaceShortDescPredPrey
			else
				description = config.replaceDescPredPrey
				shortdescription = config.replaceShortDescPredPrey
			end
		elseif config.prey then
			if type(config.replaceDescPrey) == "table" then
				local random = math.random(#config.replaceDescPrey)
				description = config.replaceDescPrey[random][1]
				shortdescription = config.replaceDescPrey[random][2] or config.replaceShortDescPrey
			else
				description = config.replaceDescPrey
				shortdescription = config.replaceShortDescPrey
			end
		elseif config.pred then
			if type(config.replaceDescPred) == "table" then
				local random = math.random(#config.replaceDescPred)
				description = config.replaceDescPred[random][1]
				shortdescription = config.replaceDescPred[random][2] or config.replaceShortDescPred
			else
				description = config.replaceDescPred
				shortdescription = config.replaceShortDescPred
			end
		end
		if config.preyColorMap and config.preyDirectives then
			local colorRemap = "?replace"
			for colorName, from in pairs(config.baseColorMap) do
				local to = config.preyColorMap[colorName] or from
				for i, color in ipairs(from or {}) do
					colorRemap = colorRemap .. ";" .. color .. "=" .. (to[i] or to[#to])
				end
			end
			config.directives = colorRemap..config.preyDirectives
		elseif config.predColorMap and config.predDirectives then
			local colorRemap = "?replace"
			for colorName, from in pairs(config.baseColorMap) do
				local to = config.predColorMap[colorName] or from
				for i, color in ipairs(from or {}) do
					colorRemap = colorRemap .. ";" .. color .. "=" .. (to[i] or to[#to])
				end
			end
			config.directives = colorRemap..config.predDirectives
		end

		if description then
			config.description = sb.replaceTags(description, replaceTagTable)
		end
		if shortdescription then
			config.shortdescription = sb.replaceTags(shortdescription, replaceTagTable)
		end
	end

	if (config or {}).npcArgs ~= nil then
		parameters.tooltipKind = "filledcapturepod"
		parameters.tooltipFields = parameters.tooltipFields or {}
		parameters.tooltipFields.subtitle = (config.npcArgs.wasPlayer and "Player") or config.npcArgs.npcType or "generictenant"

		parameters.tooltipFields.objectImage = parameters.fullPortrait or
			root.npcPortrait("full", config.npcArgs.npcSpecies, config.npcArgs.npcType or "generictenant",
				config.npcArgs.npcLevel or 1, config.npcArgs.npcSeed, config.npcArgs.npcParam)
		if config.pred then
			parameters.tooltipFields.collarNameLabel = (config.gurgledBy or "Gurgled by: ")..config.pred
		end
	end
	config.animationParts.object = config.objectImage
	config.inventoryIcon = config.iconImage..(config.directives or "")

	parameters.orientations = config.orientations
	parameters.inventoryIcon = config.inventoryIcon
	parameters.animationParts = config.animationParts
	parameters.directives = config.directives
	parameters.description = config.description
	parameters.shortdescription = config.shortdescription
	parameters.colonyTags = config.colonyTags

	return config, parameters
end
