-- this runs in postload just to be sure
function patch(config)
    for name, data in pairs(config.locations) do
        for entityType, settings in pairs(config.groupedSettings.locations) do
            config.defaultSettings[entityType].locations = config.defaultSettings[entityType].locations or {}
            config.defaultSettings[entityType].locations[name] = sb.jsonMerge(
                settings,
                config.defaultSettings[entityType].locations[name] or {}
            )
        end
    end
    for name, data in pairs(config.voreTypeData) do
        for entityType, settings in pairs(config.groupedSettings.vorePrefs) do
            config.defaultSettings[entityType].vorePrefs = config.defaultSettings[entityType].vorePrefs or {}
            config.defaultSettings[entityType].vorePrefs[name] = sb.jsonMerge(
                settings,
                config.defaultSettings[entityType].vorePrefs[name] or {}
            )
        end
        for entityType, settings in pairs(config.groupedSettings.domBehavior) do
            config.defaultSettings[entityType].domBehavior = config.defaultSettings[entityType].domBehavior or {}
            config.defaultSettings[entityType].domBehavior[name] = sb.jsonMerge(
                settings,
                config.defaultSettings[entityType].domBehavior[name] or {}
            )
        end
        for entityType, settings in pairs(config.groupedSettings.subBehavior) do
            config.defaultSettings[entityType].subBehavior = config.defaultSettings[entityType].subBehavior or {}
            config.defaultSettings[entityType].subBehavior[name] = sb.jsonMerge(
                settings,
                config.defaultSettings[entityType].subBehavior[name] or {}
            )
        end
    end
    for name, data in pairs(config.infuseTypeData) do
        for entityType, settings in pairs(config.groupedSettings.infusePrefs) do
            config.defaultSettings[entityType].infusePrefs = config.defaultSettings[entityType].infusePrefs or {}
            config.defaultSettings[entityType].infusePrefs[name] = sb.jsonMerge(
                settings,
                config.defaultSettings[entityType].infusePrefs[name] or {}
            )
        end
        for entityType, settings in pairs(config.groupedSettings.infuseSlots) do
            config.defaultSettings[entityType].infuseSlots = config.defaultSettings[entityType].infuseSlots or {}
            config.defaultSettings[entityType].infuseSlots[name] = sb.jsonMerge(
                settings,
                config.defaultSettings[entityType].infuseSlots[name] or {}
            )
        end
        for entityType, settings in pairs(config.groupedSettings.domBehavior) do
            config.defaultSettings[entityType].domBehavior = config.defaultSettings[entityType].domBehavior or {}
            config.defaultSettings[entityType].domBehavior[name] = sb.jsonMerge(
                settings,
                config.defaultSettings[entityType].domBehavior[name] or {}
            )
        end
        for entityType, settings in pairs(config.groupedSettings.subBehavior) do
            config.defaultSettings[entityType].subBehavior = config.defaultSettings[entityType].subBehavior or {}
            config.defaultSettings[entityType].subBehavior[name] = sb.jsonMerge(
                settings,
                config.defaultSettings[entityType].subBehavior[name] or {}
            )
        end

    end

    return config
end
