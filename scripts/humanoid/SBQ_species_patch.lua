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

    local sbqPartImages = {}
    for imagePath, data in pairs(config.sbqPartImages or {}) do
        if type(data) == "table" then
            local sourcePalettePath = (data.sourcePalette or "/humanoid/any/sbqModules/palette.config")
            if assets.exists(sourcePalettePath) then
                local sourcePalette = assets.json(sourcePalettePath)
                local result = data.sourceImage
                if result:sub(1, 1) ~= "/" then
                    result = "/humanoid/" .. config.kind .. "/" .. result
                end
                for i, remap in ipairs(data.remapDirectives or {}) do
                    if type(remap) == "string" then
                        result = result .. remap
                    elseif type(remap) == "table" and remap[1] then
                        local from = sourcePalette[remap[1]]
                        if not from then
                            sb.logInfo(
                                "[SBQ] '%s' has invalid color remap for '%s' remapDirectives[%s], missing palette in source named '%s'",
                                config.kind, imagePath, i, remap[1])
                        elseif remap[2] then
                            local to = config.baseColorPalette[remap[2]]
                            if to then
                                for j, v in ipairs(from) do
                                    result = result .. "?replace;" .. v .. "=" .. (to[j] or to[#to]) .. ";"
                                end
                            else
                                sb.logInfo(
                                    "[SBQ] '%s' has invalid color remap for '%s' remapDirectives[%s], species is missing palette named '%s' in 'baseColorPalette'",
                                    config.kind, imagePath, i, remap[2])
                            end
                        else -- if theres no color to remap to, remove the color by replacing with transparent pixels
                            for j, v in ipairs(from) do
                                result = result .. "?replace;" .. v .. "=00000000;"
                            end
                        end
                    else
                        sb.logInfo(
                            "[SBQ] '%s' has invalid color remap for '%s' remapDirectives index '%s', should be String or Array",
                            config.kind, imagePath, i)
                    end
                end
                sbqPartImages[imagePath] = result
            else
                sb.logInfo("[SBQ] '%s' has invalid source color remap for '%s' sourcePalette '%s' does not exist",
                    config.kind, imagePath, sourcePalettePath)
                -- nothing to do if it don't exist
            end
        end
    end

    config.sbqPartImages = sbqPartImages
    return config
end
