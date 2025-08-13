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
    addScript(config, { "buildScripts" }, "/scripts/humanoid/SBQ_humanoid_build.lua")

    for imagePath, data in pairs(config.sbqPartImages or {}) do
        if type(data) == "table" then
            local sourceColorMap = assets.json(data.sourceColorMap or "/humanoid/any/sbqVoreParts/palette.config")
            local result = data.sourceImage
            for i, remap in ipairs(data.remapDirectives or {}) do
                if type(remap) == "string" then
                    result = result .. remap
                elseif type(remap) == "table" and remap[1] then
                    if remap[2] then
                        local from = sourceColorMap[remap[1]]
                        local to = config.baseColorMap[remap[2]]
                        if not from then
                            sb.logInfo(
                                "'%s' has invalid color remap for '%s' remapDirectives[%s], missing palette in source named '%s'",
                                config.kind, imagePath, i, remap[1])
                        end
                        if not to then
                            sb.logInfo(
                            "'%s' has invalid color remap for '%s' remapDirectives[%s], species is missing palette named '%s' in 'baseColorMap'",
                                config.kind, imagePath, i, remap[2])
                        end
                        if from and to then
                            for j, v in ipairs(from) do
                                result = result .. "?replace;" .. v .. "=" .. to[j] .. ";"
                            end
                        end
                    else
                        sb.logInfo(
                        "'%s' has invalid color remap for '%s' 'remapDirectives[%s]', missing palette to remap to",
                        config.kind, imagePath, i)
                    end
                else
                    sb.logInfo("'%s' has invalid color remap for '%s' 'remapDirectives[%s]', should be String or Array",
                        config.kind, imagePath, i)
                end
            end
            config.sbqPartImages[imagePath] = result
        end
    end
    return config
end
