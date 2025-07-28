sbq = {}
require "/items/active/sbqController/sbqControllerSetup.lua"

function build(directory, config, parameters, level, seed)
	sbq.strings = root.assetJson("/sbqStrings.config")
	sbq.gui = root.assetJson("/sbqGui.config")
	parameters = parameters or {}
	parameters.scriptStorage = parameters.scriptStorage or {}

	config.inventoryIcon, config.shortdescription, config.description = sbq.getActionData(
		parameters.scriptStorage.action,
		true,
		parameters.scriptStorage.iconDirectories or {"/humanoid/any/sbqActionIcons/"}
	)
	config.description = config.description.."\n"..sbq.strings.controllerDescAppend

	return config, parameters
end
