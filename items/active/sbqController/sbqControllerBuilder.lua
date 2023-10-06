
function build(directory, config, parameters, level, seed)

	if parameters.scriptStorage ~= nil and parameters.scriptStorage.clickAction ~= nil then
		local sbqConfig = root.assetJson("/sbqGeneral.config")
		local shortdescription = (config.descriptions[parameters.scriptStorage.clickAction] or {}).shortdescription
		local description = (config.descriptions[parameters.scriptStorage.clickAction] or {}).description
		if not shortdescription then
			if parameters.scriptStorage.clickActionName then
				shortdescription = parameters.scriptStorage.clickActionName.." Controller"
			elseif sbqConfig.generalVoreTypeData[parameters.scriptStorage.clickAction] then
				shortdescription = sbqConfig.generalVoreTypeData[parameters.scriptStorage.clickAction].name.." Controller"
			else
				shortdescription = parameters.scriptStorage.clickAction.." Controller"
			end
		end
		if not description then
			if parameters.scriptStorage.clickActionName then
				description = "Triggers your "..parameters.scriptStorage.clickActionName.." action."
			elseif sbqConfig.generalVoreTypeData[parameters.scriptStorage.clickAction] then
				description = "Triggers your "..sbqConfig.generalVoreTypeData[parameters.scriptStorage.clickAction].name.." action."
			else
				description = "Triggers your "..parameters.scriptStorage.clickAction.." action."
			end
		end

		parameters.shortdescription = shortdescription
		parameters.description = description..config.appendedDescription
		parameters.inventoryIcon = (parameters.scriptStorage.icon or ("/items/active/sbqController/"..(parameters.scriptStorage.clickAction or "unassigned")..".png"))..(parameters.scriptStorage.directives or "")
	end

	return config, parameters
end
