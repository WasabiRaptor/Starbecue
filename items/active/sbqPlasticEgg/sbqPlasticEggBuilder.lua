sbq = {}
require("/scripts/any/SBQ_util.lua")

function build(directory, config, parameters, level, seed)
	config.shortdescription = sbq.getString(config.shortdescription)
	config.description = sbq.getString(config.description)

	if parameters.eggParameters then
		config.inventoryIcon = parameters.eggParameters.icon..parameters.eggParameters.directives
	end
	return config, parameters
end
