
function build(directory, config, parameters, level, seed)
	if parameters.eggParameters then
		config.inventoryIcon = parameters.eggParameters.icon..parameters.eggParameters.directives
	end
	return config, parameters
end
