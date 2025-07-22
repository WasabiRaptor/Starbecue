function patch(config, path)
    if config.disableSBQ then return config end

    addScript(config, { "baseParameters", "scripts" }, "/scripts/monster/SBQ_monster_spawn.lua")
    addScript(config, { "baseParameters", "statusSettings", "primaryScriptSources" }, "/scripts/monster/SBQ_monster_primary.lua")


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
