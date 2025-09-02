sbq = {}
require "/items/active/sbqRequester/sbqRequesterSetup.lua"

function build(directory, config, parameters, level, seed)
	sbq.strings = root.assetJson("/sbqStrings.config")
	sbq.gui = root.assetJson("/sbqGui.config")
	parameters = parameters or {}
	parameters.scriptStorage = parameters.scriptStorage or { actions = {} }
	parameters.scriptStorage.actions = parameters.scriptStorage.actions or {}

	local icon, shortdescription, description = sbq.getRequestActionData(parameters.scriptStorage.actions.primary,
		parameters.scriptStorage.iconDirectories or {"/humanoid/any/sbqActionIcons/"})
	local icon2, shortdescription2, description2 = sbq.getRequestActionData(parameters.scriptStorage.actions.alt,
		parameters.scriptStorage.iconDirectories or {"/humanoid/any/sbqActionIcons/"})

	config.inventoryIcon = icon
	config.secondaryIcon = icon2
	config.shortdescription = (sbq.strings.requesterShortDescFormat or ":requestActionFormat"):format(shortdescription)
	config.description = (sbq.strings.controllerDescFormat or ":controllerDescFormat"):format(description, description2)

	return config, parameters
end
