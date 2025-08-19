local _Settings = {}
sbq._Settings = _Settings
_Settings.__index = _Settings

function _Settings.new(settingsConfig, storedSettings, entityType)
    local self = {}
    setmetatable(self, _Settings)
    self.settingsConfig = settingsConfig
    self.overrideSettings = sb.jsonMerge(
        (settingsConfig.overrideSettings or {}).any or {},
        (settingsConfig.overrideSettings or {})[entityType] or {},
        world.getProperty("sbqOverrideSettings_" .. entityType) or world.getProperty("sbqOverrideSettings_any") or {}
    )
    self.lockedSettings = {}
    for setting, v in pairs(self.overrideSettings) do
        if sbq.config.groupedSettings[setting] then
            local groupName = setting
            self.lockedSettings[groupName] = {}
            for groupId, groupSettings in pairs(v) do
                self.lockedSettings[groupName][groupId] = {}
                for setting, v in pairs(groupSettings) do
                    self.lockedSettings[groupName][groupId][setting] = true
                end
            end
        else
            self.lockedSettings[setting] = true
        end
    end

    self.invalidSettings = sb.jsonMerge(
        (settingsConfig.invalidSettings or {}).any or {},
        (settingsConfig.invalidSettings or {})[entityType] or {},
        world.getProperty("sbqInvalidSettings_" .. entityType) or world.getProperty("sbqInvalidSettings_any") or {}
    )
    if entityType == "player" then
        -- a player should never be able to be locked out of changing their species
        self.overrideSettings.speciesTF = nil
        self.invalidSettings.speciesTF = nil
    end

    self.defaultSettings = sb.jsonMerge(
        (sbq.config.defaultSettings or {}).any or {},
        (sbq.config.defaultSettings or {})[entityType] or {},
        (settingsConfig.defaultSettings or {}).any or {},
        (settingsConfig.defaultSettings or {})[entityType] or {}
    )

	self.read = {}
	self:import(storedSettings)
    return self
end

function _Settings:import(newSettings)
    if not newSettings then
		newSettings = root.makeCurrentVersionedJson("sbqSettings", {})
    elseif not (newSettings.id and newSettings.version and newSettings.content) then
        newSettings = {
            id = "sbqSettings",
            version = 0,
            content = newSettings
        }
    end
    self.storedSettings = sb.jsonMerge(self.storedSettings or {}, root.loadVersionedJson(newSettings, "sbqSettings") or {})
	-- validate the stored settings for the entity type
    for setting, v in pairs(self.storedSettings) do
        local defaultType = type(self.defaultSettings[setting])
        if (type(v) ~= defaultType) and (defaultType ~= "table") then
            self.storedSettings[setting] = nil
            if (defaultType == "nil") then
                sbq.logWarn(string.format("Removed setting '%s' no defined default value.", setting))
            else
                sbq.logWarn(string.format("Defaulted setting '%s' value '%s'\nShould be type '%s'", setting, v,
                    defaultType))
            end
        end
        if sbq.config.groupedSettings[setting] then
            local groupName = setting
            for groupId, groupSettings in pairs(v) do
                for setting, v in pairs(groupSettings) do
                    local defaultType = type(self.defaultSettings[groupName][groupId][setting])
                    if (type(v) ~= defaultType) and (defaultType ~= "table") then
                        self.storedSettings[groupName][groupId][setting] = nil
                        if (defaultType == "nil") then
                            sbq.logWarn(string.format("Removed setting '%s.%s.%s' no defined default value.", groupName,
                                groupId, setting))
                        else
                            sbq.logWarn(string.format("Defaulted setting '%s.%s.%s' value '%s'\nShould be type '%s'",
                                groupName, groupId, setting, v,
                                defaultType))
                        end
                    end
                end
            end
        end
    end

	local function readOnlyWarn(t, k, v)
		sbq.logWarn(("Attempted write '%s' to '%s', must call the 'set' method to write to settings."):format(v, k))
	end
	-- setup metatable inheritance
    setmetatable(self.read, { __index = self.overrideSettings, __newindex = readOnlyWarn })
    setmetatable(self.overrideSettings, { __index = self.storedSettings })
    setmetatable(self.storedSettings, { __index = self.defaultSettings })

    -- check for invalid setting values that must be added to the overrides
    for setting, v in pairs(self.defaultSettings) do
        local value = self.read[setting]

        if sbq.config.groupedSettings[setting] then
            local groupName = setting
            rawset(self.read, groupName, rawget(self.read, groupName) or {})
            rawset(self.overrideSettings, groupName, rawget(self.overrideSettings, groupName) or {})
            rawset(self.lockedSettings, groupName, rawget(self.lockedSettings, groupName) or {})
            rawset(self.storedSettings, groupName, rawget(self.storedSettings, groupName) or {})

            setmetatable(self.read[groupName], { __index = self.overrideSettings[groupName], __newindex = readOnlyWarn })
            setmetatable(self.overrideSettings[groupName], { __index = self.storedSettings[groupName] })
            setmetatable(self.storedSettings[groupName], { __index = self.defaultSettings[groupName] })

            for groupId, groupSettings in pairs(v) do
                rawset(self.read[groupName], groupId, rawget(self.read[groupName], groupId) or {})
                rawset(self.overrideSettings[groupName], groupId, rawget(self.overrideSettings[groupName], groupId) or {})
                rawset(self.lockedSettings[groupName], groupId, rawget(self.lockedSettings[groupName], groupId) or {})
                rawset(self.storedSettings[groupName], groupId, rawget(self.storedSettings[groupName], groupId) or {})

                setmetatable(self.read[groupName][groupId],
                    { __index = self.overrideSettings[groupName][groupId], __newindex = readOnlyWarn })
                setmetatable(self.overrideSettings[groupName][groupId],
                    { __index = self.storedSettings[groupName][groupId] })
                setmetatable(self.storedSettings[groupName][groupId],
                    { __index = self.defaultSettings[groupName][groupId] })

                for setting, v in pairs(groupSettings) do
                    local value = self.read[groupName][groupId][setting]
                    local result = self:checkInvalid(value, setting, groupName, groupId)
                    if result ~= nil then
                        sbq.debugLogInfo(string.format(
                            "Invalid setting '%s.%s.%s' value '%s' was set to temporary value '%s'",
                            groupName, groupId, setting,
                            v, result))
                        self.overrideSettings[groupName][groupId][setting] = result
                    end
                end
            end
        else
            local result = self:checkInvalid(value, setting)
            if result ~= nil then
                sbq.debugLogInfo(string.format("Invalid setting '%s' value '%s' was set to temporary value '%s'", setting,
                    v, result))
                self.overrideSettings[setting] = result
            end
        end
    end

end

function _Settings:save()
    return root.makeCurrentVersionedJson("sbqSettings", self.storedSettings)
end

function _Settings:export(exportSettings)
	local squashed = sb.jsonMerge(self.defaultSettings, self.storedSettings, self.overrideSettings)
    if (not exportSettings) then
        return root.makeCurrentVersionedJson("sbqSettings", squashed)
    end
	local filter = function (input, filter)
		local output = {}
        for k, v in pairs(input) do
            if type(filter[k]) == "table" then
				output[k] = filter(v, filter[k])
            elseif filter[k] ~= nil then
                output[k] = v
            end
        end
		return output
	end
	root.makeCurrentVersionedJson("sbqSettings", filter(squashed, exportSettings))
end

function _Settings:checkInvalid(value, setting, groupName, groupId)
    if type(value) == "number" then
        local result
        local min = sbq.query(self.invalidSettings, { setting, "min" }) or
            ((groupName and groupId) and sbq.query(self.invalidSettings, { groupName, groupId, setting, "min" }))
        if min and ((result or value) < min) then result = min end

        local max = sbq.query(self.invalidSettings, { setting, "max" }) or
            ((groupName and groupId) and sbq.query(self.invalidSettings, { groupName, groupId, setting, "max" }))
        if max and ((result or value) > max) then result = max end

        return result
    else
        local value = tostring(value)
        return sbq.query(self.invalidSettings, { setting, value }) or
            ((groupName and groupId) and sbq.query(self.invalidSettings, { groupName, groupId, setting, value }))
    end
end

function _Settings:check(setting, groupName, groupId)
	if groupName and groupId then
        return self.settings[groupName][groupId][setting]
    else
		return self.settings[setting]
	end
end
function _Settings:set(value, setting, groupName, groupId)
    if self:checkInvalid(value, setting, groupName, groupId) then return end
    if groupName and groupId then
        if not self.lockedSettings[groupName][groupId][setting] then
            self.settings[groupName][groupId][setting] = value
        end
    else
        if not self.lockedSettings[setting] then
            self.settings[setting] = value
        end
    end
end

function _Settings:randomize(randomizeSettings, seed)
    math.randomseed(seed)
    local newSettings = {}
    for k, v in pairs(randomizeSettings) do
        if sbq.config.groupedSettings[k] then
            newSettings[k] = newSettings[k] or {}
            for g, settings in pairs(v) do
                newSettings[k][g] = {}
                for setting, v in pairs(settings) do
                    if type(v) == "table" then newSettings[k][g][setting] = v[math.random(#v)] end
                end
            end
        else
            if type(v) == "table" then newSettings[k] = v[math.random(#v)] end
        end
    end
    -- copy values from other randomized settings
    for k, v in pairs(randomizeSettings) do
        if sbq.config.groupedSettings[k] then
            for g, settings in pairs(v) do
                for setting, v in pairs(settings) do
                    if type(v) == "string" then
                        if v:sub(1, 1) == "." then
                            newSettings[k][g][setting] = sbq.queryPath(newSettings, v:sub(2, -1))
                        else
                            newSettings[k][g][setting] = newSettings[k][g][v]
                        end
                    end
                end
            end
        else
            if type(v) == "string" then
                if v:sub(1, 1) == "." then
                    newSettings[k] = sbq.queryPath(newSettings, v:sub(2, -1))
                else
                    newSettings[k] = newSettings[v]
                end
            end
        end
    end
    self:import(root.makeCurrentVersionedJson(newSettings))
end

function _Settings:setPublicSettings()
    self.publicSettings = {}
    for setting, v in pairs(sbq.config.publicSettings) do
        if v then self.publicSettings[setting] = self.read[setting] end
    end
    for k, v in pairs(sbq.config.groupedSettings) do
        self.publicSettings[k] = self.publicSettings[k] or {}
        for name, settings in pairs(self.defaultSettings[k]) do
            self.publicSettings[k][name] = self.publicSettings[k][name] or {}
            for setting, _ in pairs(settings) do
                if sbq.config.publicSettings[setting] then
                    self.publicSettings[k][name][setting] = ((self.read[k] or {})[name] or {})[setting]
                end
            end
        end
    end
    status.setStatusProperty("sbqPublicSettings", sbq.publicSettings)
end

function _Settings:setModuleSettings()
    local refresh = false
    for setting, v in pairs(sbq.config.moduleSettings) do
        local value = sbq.query(self.read, v)
        if sbq.humanoid.getHumanoidParameter("sbqModule_" .. setting) ~= value then
            sbq.humanoid.setHumanoidParameter("sbqModule_" .. setting, value)
            refresh = true
        end
    end
    if refresh then sbq.humanoid.refreshHumanoidParameters() end
end

function _Settings:setMessageHandlers(localOnly)
	message.setHandler({name = "sbqSetSetting", localOnly = localOnly}, function(_, ...)
		return self:set(...)
	end)
	message.setHandler({name = "sbqCheckSetting"}, function(_, ...)
		return self:check(...)
	end)
	message.setHandler({name = "sbqGetTieredUpgrade"}, function(_, ...)
		return sbq.getTieredUpgrade(...)
	end)
	message.setHandler({name = "sbqImportSettings", localOnly = localOnly}, function( _, ...)
		return self:import(...)
	end)
	message.setHandler({name ="sbqRefreshSettings", localOnly = localOnly}, function( _, ...)
		self:setPublicSettings()
		sbq.refreshSettings()
    end)
	message.setHandler({name = "sbqSettingsPageData"}, function ()
		return sbq.settingsPageData()
	end)

	-- shortcut to open the settings for the player
	if player then
		message.setHandler({ name = "/sbqSettings", localOnly = true }, function()
            player.interact("ScriptPane",
                { gui = {}, scripts = { "/metagui/sbq/build.lua" }, ui = "starbecue:playerSettings" })
			return "Opened Starbecue Settings"
		end)
	end
end

function sbq.settingsInit()
end

function sbq.settingsPageData()
	local settingsPageData = {
        settingsPageName = sbq.entityName(entity.id()),

        settingsConfig = sbq.settings.read.settingsConfig,
        storedSettings = sbq.settings:save(),

		voreConfig = sbq.voreConfig or {},
		locations = sbq.SpeciesScript.locations or {},
		baseLocations = sbq.SpeciesScript.baseLocations or {},
		currentScale = sbq.getScale(),
		parentEntityData = { sbq.parentEntity() },
		cosmeticSlots = {
			headCosmetic = sbq.getItemSlot("headCosmetic"),
			chestCosmetic = sbq.getItemSlot("chestCosmetic"),
			legsCosmetic = sbq.getItemSlot("legsCosmetic"),
			backCosmetic = sbq.getItemSlot("backCosmetic"),
			cosmetic1 = sbq.getItemSlot("cosmetic1"),
			cosmetic2 = sbq.getItemSlot("cosmetic2"),
			cosmetic3 = sbq.getItemSlot("cosmetic3"),
			cosmetic4 = sbq.getItemSlot("cosmetic4"),
			cosmetic5 = sbq.getItemSlot("cosmetic5"),
			cosmetic6 = sbq.getItemSlot("cosmetic6"),
			cosmetic7 = sbq.getItemSlot("cosmetic7"),
			cosmetic8 = sbq.getItemSlot("cosmetic8"),
			cosmetic9 = sbq.getItemSlot("cosmetic9"),
			cosmetic10 = sbq.getItemSlot("cosmetic10"),
			cosmetic11 = sbq.getItemSlot("cosmetic11"),
			cosmetic12 = sbq.getItemSlot("cosmetic12"),
		}
	}

	return settingsPageData
end

function sbq.setSetting(setting, value)
	if sbq.settings:checkInvalid(value, setting) ~= nil then return end
	if sbq.checkLockedSetting(setting) then return end

	local parent, recruitUuid = sbq.parentEntity()
	if parent then
		world.sendEntityMessage(parent, "sbqParentSetSetting", recruitUuid, entity.uniqueId(), setting, value)
	end
	local old = sbq.settings.read[setting]
	storage.sbqSettings[setting] = value
	sbq.settings.read[setting] = nil
	if old == sbq.settings.read[setting] then return end
	sbq.refreshSettings()
	if sbq.config.publicSettings[setting] then
		sbq.publicSettings[setting] = sbq.settings.read[setting]
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
	sbq.settings:setPublicSettings()
end


function sbq.refreshSettings()
	local modifiers = {}
	for k, v in pairs(sbq.config.statSettings or {}) do
		local amount = sbq.settings.read[k]
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
