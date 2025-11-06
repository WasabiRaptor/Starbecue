function patch(config, path)
	if config.disableSBQ then return config end
	config.scriptConfig = config.scriptConfig or {}
	if config.scriptConfig.uniqueId and not (config.scriptConfig.sbqSettingsConfig) then
		config.scriptConfig.sbqSettingsConfig = {
			includes = {
				"/species/sbq/disableAllVorePred.config",
				"/species/sbq/disableAllVorePrey.config",
				"/species/sbq/disableAllInfusePred.config",
				"/species/sbq/disableAllInfusePrey.config",
				"/species/sbq/disableAllTF.config",
				"/species/sbq/disableAllSize.config"
			}
		}
	end

	addScript(config, { "scripts" }, "/scripts/npc/SBQ_npc_bmain.lua")
	addScript(config, { "statusControllerSettings", "primaryScriptSources" }, "/scripts/npc/SBQ_npc_primary.lua")

	config.humanoidParameters = config.humanoidParameters or {}
	if config.scriptConfig.sbqNPC then
		config.humanoidParameters.sbqEnabled = true
	end

	if config.scriptConfig.sbqSettingsConfig then
		config.scriptConfig.sbqSettingsConfig = mergeIncludes(config.scriptConfig.sbqSettingsConfig or {})
		if config.scriptConfig.sbqSettingsConfig.groupedDefaultSettings then
			local sbqSettingsConfig = config.scriptConfig.sbqSettingsConfig
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
		if config.scriptConfig.sbqSettingsConfig.groupedOverrideSettings then
			local sbqSettingsConfig = config.scriptConfig.sbqSettingsConfig
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
