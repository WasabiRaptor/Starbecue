local old = {
	init = init,
	update = update,
	uninit = uninit,
	pet_spawn = _ENV.Pet._spawn,
}

function init()
	old.init()
	message.setHandler("sbqParentSetSetting", function(_, _, recruitUuid, uuid, ...)
		local recruit = _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
		if not recruit then return end
		recruit:sbqSetSetting(...)
	end)
	message.setHandler("sbqParentSetGroupedSetting", function(_, _, recruitUuid, uuid, ...)
		local recruit = _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
		if not recruit then return end
		recruit:sbqSetGroupedSetting(...)
	end)
	message.setHandler("sbqParentGetTieredUpgrade", function(_, _, recruitUuid, uuid, ...)
		local recruit = _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
		if not recruit then return end
		recruit:sbqSetTieredUpgrade(...)

	end)
	message.setHandler("sbqParentImportSettings", function(_, _, recruitUuid, uuid, ...)
		local recruit = _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
		if not recruit then return end
		recruit:sbqImportSettings(...)
	end)
    message.setHandler("sbqParentUpdateType", function(_, _, recruitUuid, uuid, ...)
		local recruit = _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
		if not recruit then return end
		recruit:sbqUpdateType(...)
	end)
    message.setHandler("sbqParentUpdateIdentities", function(_, _, recruitUuid, uuid, ...)
		local recruit = _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
		if not recruit then return end
		recruit:sbqUpdateIdentities(...)
	end)

end

function _ENV.Pet:_spawn(position, parameters)
	local scriptConfig = self:_scriptConfig(parameters)
	if scriptConfig.sbqOverrideUniqueId then
		self.uniqueId = scriptConfig.sbqOverrideUniqueId
		scriptConfig.uniqueId = scriptConfig.sbqOverrideUniqueId
	end
	if world.uniqueEntityId(self.uniqueId) then return end
	old.pet_spawn(self, position, parameters)
end

function _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
    local pod = self.pods[recruitUuid]
    if not pod then return end
	return pod:findPet(uuid)
end

function _ENV.Pet:sbqSetSetting(k, v)
	local scriptConfig = self:_scriptConfig(self.spawnConfig.parameters)
	scriptConfig.sbqSettings = scriptConfig.sbqSettings or {}
	scriptConfig.sbqSettings[k] = v
	self.spawner:markDirty()
end
function _ENV.Pet:sbqSetGroupedSetting(group, name, k, v)
	local scriptConfig = self:_scriptConfig(self.spawnConfig.parameters)
	scriptConfig.sbqSettings = scriptConfig.sbqSettings or {}
	scriptConfig.sbqSettings[group] = scriptConfig.sbqSettings[group] or {}
	scriptConfig.sbqSettings[group][name] = scriptConfig.sbqSettings[group][name] or {}
	scriptConfig.sbqSettings[group][name][k] = v
	self.spawner:markDirty()
end
function _ENV.Pet:sbqImportSettings(newSettings)
	local scriptConfig = self:_scriptConfig(self.spawnConfig.parameters)
	scriptConfig.sbqSettings = newSettings
	self.spawner:markDirty()
end
function _ENV.Pet:sbqSetTieredUpgrade(upgradeName, tier, bonus)
	local scriptConfig = self:_scriptConfig(self.spawnConfig.parameters)
	scriptConfig.sbqUpgrades = scriptConfig.sbqUpgrades or {}
	scriptConfig.sbqUpgrades[upgradeName] = scriptConfig.sbqUpgrades[upgradeName] or {}
	scriptConfig.sbqUpgrades[upgradeName][tier] = math.max(scriptConfig.sbqUpgrades[upgradeName][tier] or 0, bonus)
	self.spawner:markDirty()
end

function _ENV.Pet:sbqUpdateType(newConfig)
	util.mergeTable(self.spawnConfig, newConfig)
	self.spawner:markDirty()
end

function _ENV.Pet:sbqUpdateIdentities(response)
	self.spawnConfig.parameters.identity = response.currentIdentity
	self.spawnConfig.parameters.statusControllerSettings = self.spawnConfig.parameters.statusControllerSettings or {}
	self.spawnConfig.parameters.statusControllerSettings.statusProperties = self.spawnConfig.parameters.statusControllerSettings.statusProperties or {}
	self.spawnConfig.parameters.statusControllerSettings.statusProperties.sbqSpeciesIdentities = response.speciesIdentites
	self.spawner:markDirty()
end
