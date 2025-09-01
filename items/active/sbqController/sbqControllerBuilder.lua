sbq = {}
require "/items/active/sbqController/sbqControllerSetup.lua"

function build(directory, config, parameters, level, seed)
	sbq.strings = root.assetJson("/sbqStrings.config")
	sbq.gui = root.assetJson("/sbqGui.config")
	parameters = parameters or {}
	parameters.scriptStorage = parameters.scriptStorage or { actions = {} }
	parameters.scriptStorage.actions = parameters.scriptStorage.actions or {}

	local icon, shortdescription, description = sbq.getActionData(parameters.scriptStorage.actions.primary,
		true,
		parameters.scriptStorage.iconDirectories or {"/humanoid/any/sbqActionIcons/"})
	local icon2, shortdescription2, description2 = sbq.getActionData(parameters.scriptStorage.actions.alt,
		true,
		parameters.scriptStorage.iconDirectories or {"/humanoid/any/sbqActionIcons/"})

	config.inventoryIcon = icon
	config.secondaryIcon = icon2
	config.shortdescription = shortdescription
	config.description = (sbq.strings.controllerDescFormat or ":controllerDescFormat"):format(description, description2)

	return config, parameters
end
