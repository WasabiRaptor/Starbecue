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
		sb.logInfo("[SBQ] playable species '%s' has no part images defined, generating placeholder images.", config.kind)
		config.sbqPartImages = assets.json("/species/sbq/placeholderImages.config")
	end

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
