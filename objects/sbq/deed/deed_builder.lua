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
		-- sanity to remove potential data leak
		for i, tenant in ipairs((parameters.scriptStorage.occupier or {}).tenants or {}) do
			if sbq.query(tenant, {"overrides", "scriptConfig", "initialStorage", "sbqSettings"}) then
				parameters.scriptStorage.occupier.tenants[i].overrides.scriptConfig.initialStorage.sbqSettings = nil
			end
			if sbq.query(tenant, {"overrides", "scriptConfig", "sbqSettings", "recentlyDigested"}) then
				parameters.scriptStorage.occupier.tenants[i].overrides.scriptConfig.sbqSettings.recentlyDigested = nil
			end
			for k, v in pairs(sbq.query(tenant, {"overrides", "scriptConfig", "sbqSettings", "infuseSlots"}) or {}) do
				if sbq.query(v, {"item", "parameters", "npcArgs", "npcParam", "scriptConfig", "sbqSettings", "recentlyDigested"}) then
					parameters.scriptStorage.occupier.tenants[i].overrides.scriptConfig.sbqSettings.infuseSlots[k].item.parameters.npcArgs.npcParam.scriptConfig.sbqSettings.recentlyDigested = nil
				end
				if sbq.query(v, {"item", "parameters", "npcArgs", "npcParam", "scriptConfig", "sbqSettings", "infuseSlots"}) then
					parameters.scriptStorage.occupier.tenants[i].overrides.scriptConfig.sbqSettings.infuseSlots[k].item.parameters.npcArgs.npcParam.scriptConfig.sbqSettings.infuseSlots = nil
				end
				if sbq.query(v, {"item", "parameters", "npcArgs", "npcParam", "scriptConfig", "initialStorage", "sbqSettings"}) then
					parameters.scriptStorage.occupier.tenants[i].overrides.scriptConfig.sbqSettings.infuseSlots[k].item.parameters.npcArgs.npcParam.scriptConfig.initialStorage.sbqSettings = nil
				end
			end
		end
	end

	return config, parameters
end
