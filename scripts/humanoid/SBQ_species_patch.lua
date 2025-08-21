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

    config.sbqSettingsConfig = mergeIncludes(config.sbqSettingsConfig or {})
    if config.sbqSettingsConfig.groupedDefaultSettings then
        local sbqSettingsConfig = config.sbqSettingsConfig
        local defaultSettings = assets.json("/sbq.config:defaultSettings.any")
        for groupName, groupDefaultSettings in pairs(sbqSettingsConfig.groupedDefaultSettings) do
            sbqSettingsConfig.defaultSettings[groupName] = sbqSettingsConfig.defaultSettings[groupName] or {}
            for groupId, _ in pairs(defaultSettings[groupName]) do
                sbqSettingsConfig.defaultSettings[groupName][groupId] = sb.jsonMerge(
                    groupDefaultSettings,
                    sbqSettingsConfig.defaultSettings[groupName][groupId] or {}
                )
            end
        end
        sbqSettingsConfig.groupedDefaultSettings = nil
    end

    if (not config.sbqPartImages) and (assets.json("/player.config:defaultCodexes")[config.kind]) then
        sb.logInfo("[SBQ] playable species '%s' has no part images defined, generating blank images.", config.kind)
        config.sbqPartImages = assets.json("/species/sbq/blankPartImages.config")
    end

    local sbqPartImages = {}
    for imagePath, data in pairs(config.sbqPartImages or {}) do
        if data.sourceImage:sub(1, 1) ~= "/" then
            data.sourceImage = "/humanoid/" .. config.kind .. "/" .. data.sourceImage
        end
        local sourcePalettePath = (data.sourcePalette or "/humanoid/any/sbqModules/palette.config")
        data.processingDirectives = data.processingDirectives or ""
        if assets.exists(sourcePalettePath) and assets.exists(data.sourceImage) then
            local sourcePalette = assets.json(sourcePalettePath)
            for i, remap in ipairs(data.remapDirectives or {}) do
                if type(remap) == "string" then
                    data.processingDirectives = data.processingDirectives .. remap
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
                                data.processingDirectives = data.processingDirectives .. "?replace;" .. v .. "=" .. (to[j] or to[#to]) .. ";"
                            end
                        else
                            sb.logInfo(
                                "[SBQ] '%s' has invalid color remap for '%s' remapDirectives[%s], species is missing palette named '%s' in 'baseColorPalette'",
                                config.kind, imagePath, i, remap[2])
                        end
                    else -- if theres no color to remap to, remove the color by replacing with transparent pixels
                        for j, v in ipairs(from) do
                            data.processingDirectives = data.processingDirectives .. "?replace;" .. v .. "=00000000;"
                        end
                    end
                else
                    sb.logInfo(
                        "[SBQ] '%s' has invalid color remap for '%s' remapDirectives index '%s', should be String or Array",
                        config.kind, imagePath, i)
                end
            end
            sbqPartImages[imagePath] = data
        else
            if not assets.exists(sourcePalettePath) then
                sb.logInfo("[SBQ] '%s' has invalid source color remap for '%s' sourcePalette '%s' does not exist",
                    config.kind, imagePath, sourcePalettePath)
            end
            if not assets.exists(data.sourceImage) then
                sb.logInfo("[SBQ] '%s' has invalid source image for '%s' sourceImage '%s' does not exist",
                    config.kind, imagePath, sourcePalettePath)
            end
            -- nothing to do if it don't exist
        end
    end

    config.sbqPartImages = sbqPartImages
    return config
end

function mergeIncludes(settingConfig)
    local out = {}
    for _, path in ipairs(settingConfig.includes or {}) do
        out = sb.jsonMerge(out, mergeIncludes(assets.json(path)))
    end
    out.includes = nil
    settingConfig.includes = nil
    return sb.jsonMerge(out, settingConfig)
end
