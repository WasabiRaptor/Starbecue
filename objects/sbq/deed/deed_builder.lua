sbq = {}
require("/scripts/any/SBQ_util.lua")

function build(directory, config, parameters, level, seed)

	parameters.shortdescription = sbq.getString(config.shortdescription)
	parameters.description = sbq.getString(config.description)

	parameters.saveTenants = nil -- clear the duplicate data saves in older versions
	if parameters.scriptStorage ~= nil then
		local name = ((parameters.scriptStorage or {}).occupier or {}).partyName or (((((parameters.scriptStorage.occupier or {}).tenants or {})[1] or {}).overrides or {}).identity or {}).name
		if name then
			local ownership = "'s "
			if name:sub(-1,-1) == "s" then
				ownership = "' "
			end
			parameters.shortdescription = name..ownership..parameters.shortdescription
		end
	end

	return config, parameters
end
