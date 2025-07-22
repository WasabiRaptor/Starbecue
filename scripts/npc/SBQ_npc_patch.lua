function patch(config, path)
    if config.scriptConfig then
        config.scriptConfig.sbqNPC = config.scriptConfig.sbqNPC or false
    end
    if config.disableSBQ then return config end

    addScript(config, { "scripts" }, "/scripts/npc/SBQ_npc_bmain.lua")
    addScript(config, { "statusControllerSettings", "primaryScriptSources" }, "/scripts/npc/SBQ_npc_primary.lua")


    return config
end

function query(input, query)
	if not input then return input end
	local out = input
	for _, v in ipairs(query) do
		out = out[v]
		if not out then return out end
	end
	return out
end

function addScript(config, path, script)
    local scripts = query(config, path)
    if not scripts then return end
    for _, v in ipairs(scripts) do
        if v == script then return end
    end
    table.insert(scripts, script)
end
