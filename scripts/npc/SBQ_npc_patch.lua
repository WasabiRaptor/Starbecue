function patch(config, path)
    if config.scriptConfig then
        config.scriptConfig.sbqNPC = config.scriptConfig.sbqNPC or false
    else
        config.scriptConfig = { sbqNPC = false }
    end
    if config.disableSBQ then return config end

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

    config.scriptConfig.sbqSettingsConfig = mergeIncludes(config.scriptConfig.sbqSettingsConfig or {})
    if config.scriptConfig.sbqSettingsConfig.groupedDefaultSettings then
        local sbqSettingsConfig = config.scriptConfig.sbqSettingsConfig
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
