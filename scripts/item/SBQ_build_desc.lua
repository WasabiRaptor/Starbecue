sbq = {}
require("/scripts/any/SBQ_util.lua")

function build(directory, config, parameters, level, seed)
	parameters.shortdescription = sbq.getString(config.shortdescription)
	parameters.description = sbq.getString(config.description)
	return config, parameters
end
