local _Settings = {}
_Settings.__index = _Settings

function sbq.settingsInit()
	message.setHandler("sbqSetGroupedSetting", function(_, _, ...)
		return sbq.setGroupedSetting(...)
	end)
	message.setHandler("sbqSetSetting", function(_, _, ...)
		return sbq.setSetting(...)
    end)
	message.setHandler("sbqCheckGroupedSetting", function(_, _, ...)
		return sbq.checkGroupedSetting(...)
	end)
	message.setHandler("sbqCheckSetting", function(_, _, ...)
		return sbq.checkSetting(...)
	end)
	message.setHandler("sbqGetTieredUpgrade", function(_, _, ...)
		return sbq.getTieredUpgrade(...)
	end)
	message.setHandler("sbqImportSettings", function(_, _, ...)
		return sbq.importSettings(...)
	end)
	message.setHandler("sbqRefreshSettings", function(_, _, ...)
		sbq.refreshPublicSettings()
		sbq.refreshSettings()
	end)
end

function sbq.checkSetting(setting)
	return sbq.settings[setting]
end

function sbq.checkGroupedSetting(group, name, setting)
	return sbq.settings[group][name][setting]
end

function sbq.setSetting(setting, value)
	if sbq.checkInvalidSetting(value, setting) ~= nil then return end
	if sbq.checkLockedSetting(setting) then return end

	local parent, recruitUuid = sbq.parentEntity()
	if parent then
		world.sendEntityMessage(parent, "sbqParentSetSetting", recruitUuid, entity.uniqueId(), setting, value)
	end
	local old = sbq.settings[setting]
	storage.sbqSettings[setting] = value
	sbq.settings[setting] = nil
	if old == sbq.settings[setting] then return end
	sbq.refreshSettings()
	if sbq.config.publicSettings[setting] then
		sbq.publicSettings[setting] = sbq.settings[setting]
		status.setStatusProperty("sbqPublicSettings", sbq.publicSettings)
	end
	if (sbq.voreConfig.settingUpdateScripts or {})[setting] then
		for _, script in ipairs(sbq.voreConfig.settingUpdateScripts[setting]) do
			sbq[script](setting, value)
		end
	end
end

sbq.settingChanged = {}

function sbq.getTieredUpgrade(upgradeName, tier, bonus)
	storage.sbqUpgrades[upgradeName] = storage.sbqUpgrades[upgradeName] or {}
	local oldScore = storage.sbqUpgrades[upgradeName][tier] or 0
	if bonus <= oldScore then return end
	local parent, recruitUuid = sbq.parentEntity()
	if parent then
		world.sendEntityMessage(parent, "sbqParentGetTieredUpgrade", recruitUuid, entity.uniqueId(), upgradeName, tier,
			bonus)
	end
	if player then
		interface.queueMessage(sbq.getString(":" .. upgradeName .. "Increased"))
	end
	storage.sbqUpgrades[upgradeName][tier] = bonus
	sbq.refreshUpgrades(true)
	sbq.refreshSettings()
	sbq.refreshPublicSettings()
end

function sbq.setGroupedSetting(group, name, setting, value)
	if sbq.checkInvalidSetting(value, setting, group, name) ~= nil then return end
	if sbq.checkLockedSetting(setting, group, name) then return end

	local parent, recruitUuid = sbq.parentEntity()
	if parent then
		world.sendEntityMessage(parent, "sbqParentSetGroupedSetting", recruitUuid, entity.uniqueId(), group, name,
			setting, value)
	end
	local old = sbq.settings[group][name][setting]
	storage.sbqSettings[group][name][setting] = value
	sbq.settings[group][name][setting] = nil
	if type(value) ~= "table" and old == sbq.settings[group][name][setting] then return end
	if sbq.groupedSettingChanged[group] then sbq.groupedSettingChanged[group](name, setting, value) end
	if (sbq.voreConfig.settingUpdateScripts or {})[setting] then
		for _, script in ipairs(sbq.voreConfig.settingUpdateScripts[setting]) do
			sbq[script](setting, value, group, name)
		end
	end
	sbq.refreshSettings()
	if sbq.config.publicSettings[setting] then
		sbq.publicSettings[group][name][setting] = sbq.settings[group][name][setting]
		status.setStatusProperty("sbqPublicSettings", sbq.publicSettings)
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
	for k, location in pairs(sbq.SpeciesScript.locations) do
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
		table.insert(modifiers, { stat = v, amount = tonumber(amount) or 0 })
	end
	status.setPersistentEffects("sbqStats", modifiers)
	if sbq.SpeciesScript then
		sbq.SpeciesScript:settingAnimations()
	end
end

function sbq.refreshPublicSettings()
	for setting, v in pairs(sbq.config.publicSettings) do
		if v then sbq.publicSettings[setting] = sbq.settings[setting] end
	end
	for k, v in pairs(sbq.config.groupedSettings) do
		sbq.publicSettings[k] = sbq.publicSettings[k] or {}
		for name, settings in pairs(sbq.defaultSettings[k]) do
			sbq.publicSettings[k][name] = sbq.publicSettings[k][name] or {}
			for setting, _ in pairs(settings) do
				if sbq.config.publicSettings[setting] then
					sbq.publicSettings[k][name][setting] = ((sbq.settings[k] or {})[name] or {})[setting]
				end
			end
		end
	end
	status.setStatusProperty("sbqPublicSettings", sbq.publicSettings)
end

function sbq.randomizeSettings()
	local randomizeSettings = config.getParameter("sbqRandomizeSettings")
	if randomizeSettings and not storage.sbqSettings then
		randomizeSettings = sbq.fetchConfigArray(randomizeSettings)
		storage.sbqSettings = {}
		for k, v in pairs(randomizeSettings) do
			if sbq.config.groupedSettings[k] then
				storage.sbqSettings[k] = {}
				for g, settings in pairs(v) do
					storage.sbqSettings[k][g] = {}
					for setting, v in pairs(settings) do
						if type(v) == "table" then storage.sbqSettings[k][g][setting] = v[math.random(#v)] end
					end
				end
			else
				if type(v) == "table" then storage.sbqSettings[k] = v[math.random(#v)] end
			end
		end
		-- copy values from other randomized settings
		for k, v in pairs(randomizeSettings) do
			if sbq.config.groupedSettings[k] then
				for g, settings in pairs(v) do
					for setting, v in pairs(settings) do
						if type(v) == "string" then
							if v:sub(1, 1) == "." then
								storage.sbqSettings[k][g][setting] = sbq.queryPath(storage.sbqSettings, v:sub(2, -1))
							else
								storage.sbqSettings[k][g][setting] = storage.sbqSettings[k][g][v]
							end
						end
					end
				end
			else
				if type(v) == "string" then
					if v:sub(1, 1) == "." then
						storage.sbqSettings[k] = sbq.queryPath(storage.sbqSettings, v:sub(2, -1))
					else
						storage.sbqSettings[k] = storage.sbqSettings[v]
					end
				end
			end
		end
	end
	storage.sbqSettings = storage.sbqSettings or {}
end
