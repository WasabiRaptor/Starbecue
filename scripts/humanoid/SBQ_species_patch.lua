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

function patch(config, path)
    config.buildScripts = config.buildScripts or { "/humanoid/opensb/build.lua" }
    addScript(config, {"buildScripts"}, "/scripts/humanoid/SBQ_humanoid_build.lua")
    return config
end
