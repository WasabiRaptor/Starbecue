function sbq.settingsInit()
	message.setHandler("sbqSetGroupedSetting", function(_, _, ...)
		return sbq.setGroupedSetting(...)
	end)
	message.setHandler("sbqSetSetting", function (_,_, ...)
		return sbq.setSetting(...)
	end)
	message.setHandler("sbqSetUpgrade", function (_,_, ...)
		return sbq.getUpgrade(...)
	end)
	message.setHandler("sbqImportSettings", function (_,_, ...)
		return sbq.importSettings(...)
	end)
end

function sbq.setSetting(k, v)
	local parent, recruitUuid = sbq.parentEntity()
	if parent then
		world.sendEntityMessage(parent, "sbqParentSetSetting", recruitUuid, entity.uniqueId(), k, v)
	end
	local old = sbq.settings[k]
	storage.sbqSettings[k] = v
	if old == sbq.settings[k] then return end
	sbq.refreshSettings()
	if sbq.config.publicSettings[k] then
		sbq.publicSettings[k] = sbq.settings[k]
		sbq.setProperty("sbqPublicSettings", sbq.publicSettings)
	end
	if (sbq.voreConfig.settingUpdateScripts or {})[k] then
		for _, script in ipairs(sbq.voreConfig.settingUpdateScripts[k]) do
			sbq[script](k,v)
		end
	end
end

function sbq.getUpgrade(upgradeName, tier, bonus)
	local parent, recruitUuid = sbq.parentEntity()
	if parent then
		world.sendEntityMessage(parent, "sbqParentGetUpgrade", recruitUuid, entity.uniqueId(), upgradeName, tier, bonus)
	end
	storage.sbqUpgrades[upgradeName] = storage.sbqUpgrades[upgradeName] or {}
	storage.sbqUpgrades[upgradeName][tier] = math.max(storage.sbqUpgrades[upgradeName][tier] or 0, bonus)
	sbq.refreshUpgrades(true)
end

function sbq.setGroupedSetting(group, name, k, v)
	local parent, recruitUuid = sbq.parentEntity()
	if parent then
		world.sendEntityMessage(parent, "sbqParentSetGroupedSetting", recruitUuid, entity.uniqueId(), group, name, k, v)
	end
	local old = sbq.settings[group][name][k]
	storage.sbqSettings[group][name][k] = v
	if type(v) ~= "table" and old == sbq.settings[group][name][k] then return end
	if sbq.groupedSettingChanged[group] then sbq.groupedSettingChanged[group](name, k, v) end
	if (sbq.voreConfig.settingUpdateScripts or {})[k] then
		for _, script in ipairs(sbq.voreConfig.settingUpdateScripts[k]) do
			sbq[script](k,v, group, name)
		end
	end
	sbq.refreshSettings()
	if sbq.config.publicSettings[k] then
		sbq.publicSettings[group][name][k] = sbq.settings[group][name][k]
		sbq.setProperty("sbqPublicSettings", sbq.publicSettings)
	end
end
sbq.groupedSettingChanged = {}

function sbq.importSettings(newSettings)
	local parent, recruitUuid = sbq.parentEntity()
	if parent then
		world.sendEntityMessage(parent, "sbqParentImportSettings", recruitUuid, entity.uniqueId(), newSettings)
	end
	storage.sbqSettings = sb.jsonMerge(storage.sbqSettings, newSettings)
	sbq.setupSettingMetatables(entity.entityType())
	sbq.refreshPublicSettings()
	sbq.refreshSettings()
	for k, location in pairs(SpeciesScript.locations) do
		location:markSettingsDirty()
	end
end

function sbq.refreshSettings()
	local modifiers = {}
	for k, v in pairs(sbq.config.statSettings or {}) do
		local amount = sbq.settings[k]
		if type(amount) == "boolean" then
			amount = (amount and 1) or 0
		end
		table.insert(modifiers, {stat = v, amount = tonumber(amount) or 0})
	end
	sbq.setStatModifiers("sbqStats", modifiers)

	for _, settingsAnim in ipairs(sbq.voreConfig.settingAnimationStates or {}) do
		if sbq.tableMatches(settingsAnim[1], sbq.settings, true) then
			SpeciesScript:doAnimations(settingsAnim[2])
		end
	end
end

function sbq.refreshPublicSettings()
	for setting, v in pairs(sbq.config.publicSettings) do
		if v == true then sbq.publicSettings[setting] = sbq.settings[setting] end
	end
	for k, v in pairs(sbq.config.groupedSettings) do
		for name, settings in pairs(sbq.defaultSettings[k]) do
			for setting, _ in pairs(settings) do
				if sbq.config.publicSettings[setting] == true then
					sbq.publicSettings[k][name][setting] = sbq.settings[k][name][setting]
				end
			end
		end
	end
	sbq.setProperty("sbqPublicSettings", sbq.publicSettings)
end
