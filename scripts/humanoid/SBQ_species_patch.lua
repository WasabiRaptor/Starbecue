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
	if config.sbqCompatible == false then
		return sb.jsonMerge(config, {
			humanoidOverrides = {
				sbqCompatible = false,
			},
			sbqPartImages = {},
			sbqSettingsConfig = {}
		})
	end
	config.buildScripts = config.buildScripts or { "/humanoid/opensb/build.lua" }
	addScript(config, { "buildScripts" }, "/scripts/humanoid/SBQ_humanoid_build.lua")

	config.sbqSettingsConfig = mergeIncludes(config.sbqSettingsConfig or {})
	if config.sbqSettingsConfig.groupedDefaultSettings then
		local sbqSettingsConfig = config.sbqSettingsConfig
		local defaultSettings = assets.json("/sbq.config:defaultSettings.any")
		sbqSettingsConfig.defaultSettings = sbqSettingsConfig.defaultSettings or {}
		for entityType, entityTypeSettings in pairs(sbqSettingsConfig.groupedDefaultSettings) do
			sbqSettingsConfig.defaultSettings[entityType] = sbqSettingsConfig.defaultSettings[entityType] or {}
			for groupName, groupDefaultSettings in pairs(entityTypeSettings) do
				sbqSettingsConfig.defaultSettings[entityType][groupName] = sbqSettingsConfig.defaultSettings[entityType][groupName] or {}
				for groupId, _ in pairs(defaultSettings[groupName]) do
					sbqSettingsConfig.defaultSettings[entityType][groupName][groupId] = sb.jsonMerge(
						groupDefaultSettings,
						sbqSettingsConfig.defaultSettings[entityType][groupName][groupId] or {}
					)
				end
			end
		end
		sbqSettingsConfig.groupedDefaultSettings = nil
	end
	if config.sbqSettingsConfig.groupedOverrideSettings then
		local sbqSettingsConfig = config.sbqSettingsConfig
		local defaultSettings = assets.json("/sbq.config:defaultSettings.any")
		sbqSettingsConfig.overrideSettings = sbqSettingsConfig.overrideSettings or {}
		for entityType, entityTypeSettings in pairs(sbqSettingsConfig.groupedOverrideSettings) do
			sbqSettingsConfig.overrideSettings[entityType] = sbqSettingsConfig.overrideSettings[entityType] or {}
			for groupName, groupOverrideSettings in pairs(entityTypeSettings) do
				sbqSettingsConfig.overrideSettings[entityType][groupName] = sbqSettingsConfig.overrideSettings[entityType][groupName] or {}
				for groupId, _ in pairs(defaultSettings[groupName]) do
					sbqSettingsConfig.overrideSettings[entityType][groupName][groupId] = sb.jsonMerge(
						groupOverrideSettings,
						sbqSettingsConfig.overrideSettings[entityType][groupName][groupId] or {}
					)
				end
			end
		end
		sbqSettingsConfig.groupedOverrideSettings = nil
	end

	if (not config.sbqPartImages) and (assets.json("/player.config:defaultCodexes")[config.kind]) then
		sb.logInfo("[SBQ] playable species '%s' has no part images defined, generating placeholder images.", config.kind)
		config.sbqPartImages = assets.json("/species/sbq/placeholderImages.config")
	end
	if type(sb.jsonQuery(config, "humanoidOverrides.sbqConfig.modules")) == "string" then
		config.humanoidOverrides.sbqConfig.modules = assets.json(config.humanoidOverrides.sbqConfig.modules)
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
