local _Settings = {
    updated = {}
}
sbq._Settings = _Settings
_Settings.__index = _Settings

function _Settings.new(settingsConfig, storedSettings, entityType, storage)
    local self = {}
    setmetatable(self, _Settings)
    self.storage = storage
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
                    local result = self:checkInvalid(setting, value, groupName, groupId)
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
            local result = self:checkInvalid(setting, value)
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

function _Settings:checkInvalid(setting, value, groupName, groupId)
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
function _Settings:checkLocked(setting, groupName, groupId)
	if groupName and groupId then
        return self.lockedSettings[groupName][groupId][setting]
    else
		return self.lockedSettings[setting]
	end
end

function _Settings:get(setting, groupName, groupId)
	if groupName and groupId then
        return self.read[groupName][groupId][setting]
    else
		return self.read[setting]
	end
end
function _Settings:getStored(setting, groupName, groupId)
	if groupName and groupId then
        return rawget(self.storedSettings[groupName][groupId], setting)
    else
		return rawget(self.storedSettings, setting)
	end
end

function _Settings:set(setting, value, groupName, groupId)
    local oldValue = self:get(setting, groupName, groupId)
    local value = self:checkInvalid(setting, value, groupName, groupId) or value
    if groupName and groupId then
        if not self.lockedSettings[groupName][groupId][setting] then
            rawset(self.storedSettings[groupName][groupId], setting, value)
        end
    else
        if not self.lockedSettings[setting] then
            rawset(self.storedSettings, setting, value)
        end
    end
    if oldValue ~= self:get(setting, groupName, groupId) then
        if self.updated[setting] then
            self.updated[setting](self, oldValue, setting, groupName, groupId)
        else
            self.updated.any(self, oldValue, setting, groupName, groupId)
        end
    end
end
function _Settings.updated:any(oldValue, setting, groupName, groupId)
    if self.storage then
        self.storage.sbqSettings = self:save()
    end
    -- local parent, recruitUuid = sbq.parentEntity()
	-- if parent then
	-- 	world.sendEntityMessage(parent, "sbqParentSetSetting", recruitUuid, entity.uniqueId(), setting, value)
    -- end
    if sbq.config.publicSettings[setting] then
        self.updated.publicSetting(self, oldValue, setting, groupName, groupId)
    end
    if sbq.config.statSettings[setting] then
        self.updated.statSetting(self, oldValue, setting, groupName, groupId)
    end
    if sbq.config.parameterSettings[setting] then
        self.updated.parameterSetting(self, oldValue, setting, groupName, groupId)
    end

    if groupName == "locations" then
        self.updated.locationSetting(self, oldValue, setting, groupName, groupId)
    end
end
function _Settings.updated:publicSetting(oldValue, setting, groupName, groupId)
    self:setPublicSettings()
end
function _Settings.updated:statSetting(oldValue, setting, groupName, groupId)
    self:setStatSettings()
end

function _Settings.updated:locationSetting(oldValue, setting, groupName, groupId)
    if sbq.SpeciesScript then
        local location = sbq.SpeciesScript:getLocation(groupId)
        if location then
            location:markSettingsDirty()
        end
    end
end

function _Settings.updated:parameterSetting(oldValue, setting, ...)
    self:setParameterSettings()
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
    status.setStatusProperty("sbqPublicSettings", self.publicSettings)
end

function _Settings:setParameterSettings()
    if not sbq.humanoid then return end
    local refresh = false
    for setting, parameter in pairs(sbq.config.parameterSettings) do
        local value = self:get(setting)
        if sbq.humanoid.getHumanoidParameter(parameter) ~= value then
            sbq.humanoid.setHumanoidParameter(parameter, value)
            refresh = true
        end
    end
    if refresh then sbq.humanoid.refreshHumanoidParameters() end
    return refresh
end

function _Settings:setStatSettings()
    local modifiers = {}
    for k, v in pairs(sbq.config.statSettings or {}) do
        local amount = self.read[k]
        if type(amount) == "boolean" then
            amount = (amount and 1) or 0
        end
        table.insert(modifiers, { stat = v, amount = tonumber(amount) or 0 })
    end
    status.setPersistentEffects("sbqStats", modifiers)
end

function _Settings:setMessageHandlers(localOnly)
    if localOnly then
        message.setHandler({ name = "sbqSetSetting", localOnly = true }, function(...)
            return self:set(...)
        end)
        message.setHandler({ name = "sbqImportSettings", localOnly = true }, function(...)
            return self:import(...)
        end)
        message.setHandler({ name = "sbqRefreshSettings", localOnly = true }, function(...)
            self:setPublicSettings()
            sbq.refreshSettings()
        end)
    else
        message.setHandler({ name = "sbqSetSetting" }, function(_, ...)
            return self:set(...)
        end)
        message.setHandler({ name = "sbqImportSettings" }, function(_, ...)
            return self:import(...)
        end)
        message.setHandler({ name = "sbqRefreshSettings" }, function(_, ...)
            self:setPublicSettings()
            sbq.refreshSettings()
        end)
    end
    message.setHandler({ name = "sbqGetSetting" }, function(_, ...)
        return self:get(...)
    end)
    message.setHandler({ name = "sbqSettingsMatches" }, function(_, ...)
        return self:matches(...)
    end)
    message.setHandler({ name = "sbqSettingsPageData" }, function(_, ...)
        return sbq.settingsPageData(...)
    end)
end

function _Settings:matches(input, isAny)
    return sbq.tableMatches(input, self.read, isAny)
end

local _Upgrades = {
    updated = {}
}
sbq._Upgrades = _Upgrades
_Upgrades.__index = _Upgrades

function _Upgrades.new(storedUpgrades, storage)
    local self = {}
    self.storage = storage
    setmetatable(self, {__index = _Upgrades})
    if not storedUpgrades then
        storedUpgrades = root.makeCurrentVersionedJson("sbqUpgrades", {})
    elseif not (storedUpgrades.id and storedUpgrades.version and storedUpgrades.content) then
        storedUpgrades = {
            id = "sbqUpgrades",
            version = 0,
            content = storedUpgrades
        }
    end
    self.storedUpgrades = root.loadVersionedJson(storedUpgrades, "sbqUpgrades")
    self.values = {}
    setmetatable(self.values, { __index = self.storedUpgrades })
    for _, name in ipairs(sbq.config.tieredUpgrades) do
        local value = 0
        for _, v in ipairs(self.storedUpgrades[name] or {}) do
            value = value + v
        end
        rawset(self.values, name, value)
    end
    return self
end
function _Upgrades:save()
    return root.makeCurrentVersionedJson("sbqUpgrades", self.storedUpgrades)
end

function _Upgrades:setTiered(name, tier, bonus)
    self.storedUpgrades[name] = self.storedUpgrades[name] or jarray()
    for i = 1, tier do
        self.storedUpgrades[name][i] = self.storedUpgrades[name][i] or 0
    end
    self.storedUpgrades[name][tier] = math.max(self.storedUpgrades[name][tier], bonus)
    local oldValue = self:get(name)
    local value = 0
    for _, v in ipairs(self.storedUpgrades[name]) do
        value = value + v
    end
    rawset(self.values, name, value)
    if value ~= oldValue then
        if self.updated[name] then
            self.updated[name](self, name, oldValue)
        else
            self.updated.any(self, name, oldValue)
        end
    end
end
function _Upgrades:set(name, value)
    local oldValue = self:get(name)
    self.storedUpgrades[name] = value
    if self:get(name) ~= oldValue then
        if self.updated[name] then
            self.updated[name](self, name, oldValue)
        else
            self.updated.any(self, name, oldValue)
        end
    end
end
function _Upgrades:get(name)
    return self.values[name]
end
function _Upgrades.updated:any(name, oldValue)
    if self.storage then
        self.storage.sbqUpgrades = self:save()
    end
    if not self.applyTo then return end
    -- do things here
end
function _Upgrades.updated:candyBonus(name, oldValue)
    if not self.applyTo then return end
    local oldMaxDigest = self.applyTo:get("maxDigestPower")
    local oldMaxScale = self.applyTo:get("maxPossibleScale")
    local oldMaxOcccupants = self.applyTo:get("maxOccupantSlots")

    local candyBonus = self:get("candyBonus")
    self.applyTo:set("maxDigestPower", 1 + (candyBonus / 2))
    self.applyTo:set("maxPossibleScale", math.min(2 + (candyBonus), sbq.config.scaleCap))
    self.applyTo:set("maxOccupantSlots", math.min(4 + (candyBonus * 2), sbq.config.occpantSlotCap))

    for _, k in ipairs(sbq.config.digestPowerSettings) do
        if self.applyTo:get(k) == oldMaxDigest then
            self.applyTo:set(k, self.applyTo:get("maxDigestPower"))
        end
    end
    if self.applyTo:get("maxScale") == oldMaxScale then
        self.applyTo:set("maxScale", self.applyTo:get("maxPossibleScale"))
    end
    if self.applyTo:get("occupantSlots") == oldMaxOcccupants then
        self.applyTo:set("occupantSlots", self.applyTo:get("maxOccupantSlots"))
    end

    self.updated.any(self, name, oldValue)
end

function _Upgrades:apply(settings)
    self.applyTo = settings or self.applyTo
    if not self.applyTo then return end
    local candyBonus = self:get("candyBonus")
    self.applyTo:set("maxDigestPower", 1 + (candyBonus / 2))
    self.applyTo:set("maxPossibleScale", math.min(2 + (candyBonus), sbq.config.scaleCap))
    self.applyTo:set("maxOccupantSlots", math.min(4 + (candyBonus * 2), sbq.config.occpantSlotCap))
end

function _Upgrades:setMessageHandlers(localOnly)
    if localOnly then
        message.setHandler({ name = "sbqSetTieredUpgrade", localOnly = true }, function(...)
            return self:setTiered(...)
        end)
        message.setHandler({ name = "sbqSetUpgrade", localOnly = true }, function(...)
            return self:set(...)
        end)
    else
        message.setHandler({ name = "sbqSetTieredUpgrade" }, function(_, ...)
            return self:setTiered(...)
        end)
        message.setHandler({ name = "sbqSetUpgrade" }, function(_, ...)
            return self:set(...)
        end)
    end
    message.setHandler({ name = "sbqGetUpgrade" }, function(_, ...)
        return self:get(...)
    end)

end

function sbq.settingsPageData(...)
	local settingsPageData = {
        settingsPageName = sbq.entityName(entity.id()),

        settingsConfig = sbq.settings.settingsConfig,
        storedSettings = sbq.settings:save(),
        storedUpgrades = sbq.upgrades:save(),

		voreConfig = sbq.voreConfig or {},
		locations = (sbq.SpeciesScript or {}).locations or {},
		baseLocations = (sbq.SpeciesScript or {}).baseLocations or {},
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

sbq.settingChanged = {}


function sbq.refreshSettings()
	if sbq.SpeciesScript and sbq.SpeciesScript.active then
		sbq.SpeciesScript:settingAnimations()
	end
end
