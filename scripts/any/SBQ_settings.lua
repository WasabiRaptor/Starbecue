function sbq.settingsInit()
	message.setHandler("sbqSetGroupedSetting", function(_, _, ...)
		return sbq.setGroupedSetting(...)
	end)
	message.setHandler("sbqSetSetting", function (_,_, ...)
		return sbq.setSetting(...)
	end)
	message.setHandler("sbqGetUpgrade", function (_,_, ...)
		return sbq.getUpgrade(...)
	end)
	message.setHandler("sbqImportSettings", function (_,_, ...)
		return sbq.importSettings(...)
	end)
	message.setHandler("sbqRefreshSettings", function (_,_, ...)
		sbq.refreshPublicSettings()
		sbq.refreshSettings()
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
	storage.sbqUpgrades[upgradeName] = storage.sbqUpgrades[upgradeName] or {}
	local oldScore = storage.sbqUpgrades[upgradeName][tier] or 0
	if bonus <= oldScore then return end
	local parent, recruitUuid = sbq.parentEntity()
	if parent then
		world.sendEntityMessage(parent, "sbqParentGetUpgrade", recruitUuid, entity.uniqueId(), upgradeName, tier, bonus)
	end
	if player then
		player.queueUIMessage(sbq.getString(":"..upgradeName.."Increased"))
	end
	storage.sbqUpgrades[upgradeName][tier] = bonus
	sbq.refreshUpgrades(true)
	sbq.refreshSettings()
	sbq.refreshPublicSettings()
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
	if SpeciesScript then
		SpeciesScript:settingAnimations()
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
	sbq.setProperty("sbqPublicSettings", sbq.publicSettings)
end

function sbq.randomizeSettings()
	local randomizeSettings = config.getParameter("sbqRandomizeSettings")
	if randomizeSettings and not storage.sbqSettings then
		randomizeSettings = root.fetchConfigArray(randomizeSettings)
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
							if v:sub(1,1) == "." then
								storage.sbqSettings[k][g][setting] = sbq.queryPath(storage.sbqSettings, v:sub(2,-1))
							else
								storage.sbqSettings[k][g][setting] = storage.sbqSettings[k][g][v]
							end
						end
					end
				end
			else
				if type(v) == "string" then
					if v:sub(1, 1) == "." then
						storage.sbqSettings[k] = sbq.queryPath(storage.sbqSettings, v:sub(2,-1))
					else
						storage.sbqSettings[k] = storage.sbqSettings[v]
					end
				end
			end
		end
	end
	storage.sbqSettings = storage.sbqSettings or {}
end
