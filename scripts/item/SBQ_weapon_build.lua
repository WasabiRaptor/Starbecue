require("/items/buildscripts/buildunrandweapon.lua")
local old = {
	build = build
}
sbq = {}
require("/scripts/any/SBQ_util.lua")

function build(directory, config, parameters, level, seed)
	config.shortdescription = sbq.getString(config.shortdescription)
	config.description = sbq.getString(config.description)
	return old.build(directory, config, parameters, level, seed)
end
