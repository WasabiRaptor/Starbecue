-- this runs in postload just to be sure
function patch(config)
	for name, data in pairs(config.locations) do
		for entityType, settings in pairs(config.groupedSettings.locations.defaultSettings) do
			config.defaultSettings[entityType].locations = config.defaultSettings[entityType].locations or {}
			config.defaultSettings[entityType].locations[name] = sb.jsonMerge(
				settings,
				config.defaultSettings[entityType].locations[name] or {}
			)
		end
	end
	for name, data in pairs(config.voreTypeData) do
		for entityType, settings in pairs(config.groupedSettings.vorePrefs.defaultSettings) do
			config.defaultSettings[entityType].vorePrefs = config.defaultSettings[entityType].vorePrefs or {}
			config.defaultSettings[entityType].vorePrefs[name] = sb.jsonMerge(
				settings,
				config.defaultSettings[entityType].vorePrefs[name] or {}
			)
		end
		for entityType, settings in pairs(config.groupedSettings.domBehavior.defaultSettings) do
			config.defaultSettings[entityType].domBehavior = config.defaultSettings[entityType].domBehavior or {}
			config.defaultSettings[entityType].domBehavior[name] = sb.jsonMerge(
				settings,
				config.defaultSettings[entityType].domBehavior[name] or {}
			)
		end
		for entityType, settings in pairs(config.groupedSettings.subBehavior.defaultSettings) do
			config.defaultSettings[entityType].subBehavior = config.defaultSettings[entityType].subBehavior or {}
			config.defaultSettings[entityType].subBehavior[name] = sb.jsonMerge(
				settings,
				config.defaultSettings[entityType].subBehavior[name] or {}
			)
		end

		for entityType, settings in pairs(config.groupedSettings.vorePrefs.overrideSettings) do
			config.overrideSettings[entityType].vorePrefs = config.overrideSettings[entityType].vorePrefs or {}
			config.overrideSettings[entityType].vorePrefs[name] = sb.jsonMerge(
				settings,
				config.overrideSettings[entityType].vorePrefs[name] or {}
			)
		end
		for entityType, settings in pairs(config.groupedSettings.domBehavior.overrideSettings) do
			config.overrideSettings[entityType].domBehavior = config.overrideSettings[entityType].domBehavior or {}
			config.overrideSettings[entityType].domBehavior[name] = sb.jsonMerge(
				settings,
				config.overrideSettings[entityType].domBehavior[name] or {}
			)
		end
		for entityType, settings in pairs(config.groupedSettings.subBehavior.overrideSettings) do
			config.overrideSettings[entityType].subBehavior = config.overrideSettings[entityType].subBehavior or {}
			config.overrideSettings[entityType].subBehavior[name] = sb.jsonMerge(
				settings,
				config.overrideSettings[entityType].subBehavior[name] or {}
			)
		end
	end
	for name, data in pairs(config.infuseTypeData) do
		for entityType, settings in pairs(config.groupedSettings.infusePrefs.defaultSettings) do
			config.defaultSettings[entityType].infusePrefs = config.defaultSettings[entityType].infusePrefs or {}
			config.defaultSettings[entityType].infusePrefs[name] = sb.jsonMerge(
				settings,
				config.defaultSettings[entityType].infusePrefs[name] or {}
			)
		end
		for entityType, settings in pairs(config.groupedSettings.domBehavior.defaultSettings) do
			config.defaultSettings[entityType].domBehavior = config.defaultSettings[entityType].domBehavior or {}
			config.defaultSettings[entityType].domBehavior[name] = sb.jsonMerge(
				settings,
				config.defaultSettings[entityType].domBehavior[name] or {}
			)
		end
		for entityType, settings in pairs(config.groupedSettings.subBehavior.defaultSettings) do
			config.defaultSettings[entityType].subBehavior = config.defaultSettings[entityType].subBehavior or {}
			config.defaultSettings[entityType].subBehavior[name] = sb.jsonMerge(
				settings,
				config.defaultSettings[entityType].subBehavior[name] or {}
			)
		end

		for entityType, settings in pairs(config.groupedSettings.infusePrefs.overrideSettings) do
			config.overrideSettings[entityType].infusePrefs = config.overrideSettings[entityType].infusePrefs or {}
			config.overrideSettings[entityType].infusePrefs[name] = sb.jsonMerge(
				settings,
				config.overrideSettings[entityType].infusePrefs[name] or {}
			)
		end
		for entityType, settings in pairs(config.groupedSettings.domBehavior.overrideSettings) do
			config.overrideSettings[entityType].domBehavior = config.overrideSettings[entityType].domBehavior or {}
			config.overrideSettings[entityType].domBehavior[name] = sb.jsonMerge(
				settings,
				config.overrideSettings[entityType].domBehavior[name] or {}
			)
		end
		for entityType, settings in pairs(config.groupedSettings.subBehavior.overrideSettings) do
			config.overrideSettings[entityType].subBehavior = config.overrideSettings[entityType].subBehavior or {}
			config.overrideSettings[entityType].subBehavior[name] = sb.jsonMerge(
				settings,
				config.overrideSettings[entityType].subBehavior[name] or {}
			)
		end
	end
	return config
end
