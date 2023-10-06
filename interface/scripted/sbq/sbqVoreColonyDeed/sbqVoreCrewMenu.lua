---@diagnostic disable: undefined-global

sbq.followers = world.sendEntityMessage(player.id(), "sbqPlayerCompanions"):result()

sbq.storage.occupier = { tenants = {}}

for i, follower in ipairs(sbq.followers) do
	if (follower.config.parameters.scriptConfig or {}).ownerUuid == player.uniqueId() then
		local tenant = {
			overrides = follower.config.parameters,
			species = follower.config.species,
			uniqueId = follower.config.parameters.scriptConfig.preservedUuid or follower.uniqueId,
			type = follower.config.type,
			followerTable = follower
		}
		follower.config.parameters.scriptConfig.preservedUuid = follower.config.parameters.scriptConfig.preservedUuid or follower.uniqueId

		table.insert(sbq.storage.occupier.tenants, tenant)
	end
end

function sbq.savePredSettings()
	sbq.tenant.overrides.scriptConfig.sbqSettings = sbq.predatorSettings
	if sbq.storage.occupier then
		world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSaveSettings", sbq.predatorSettings)
		world.sendEntityMessage(player.id(), "sbqCrewSaveSettings", sbq.predatorSettings, sbq.tenant.uniqueId)
	end
end
sbq.saveSettings = sbq.savePredSettings

function sbq.savePreySettings()
	sbq.tenant.overrides.statusControllerSettings.statusProperties.sbqPreyEnabled = sbq.preySettings
	if sbq.storage.occupier then
		world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSavePreySettings", sbq.preySettings)
		world.sendEntityMessage(player.id(), "sbqCrewSaveStatusProperty", "sbqPreyEnabled", sbq.preySettings, sbq.tenant.uniqueId)
	end
end

function sbq.changeAnimOverrideSetting(settingname, settingvalue)
	sbq.animOverrideSettings[settingname] = settingvalue
	sbq.tenant.overrides.statusControllerSettings.statusProperties.speciesAnimOverrideSettings = sbq.animOverrideSettings
	if sbq.storage.occupier then
		world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSaveAnimOverrideSettings", sbq.animOverrideSettings)
		world.sendEntityMessage(sbq.tenant.uniqueId, "speciesAnimOverrideRefreshSettings", sbq.animOverrideSettings)
		world.sendEntityMessage(sbq.tenant.uniqueId, "animOverrideScale", sbq.animOverrideSettings.scale)
		world.sendEntityMessage(player.id(), "sbqCrewSaveStatusProperty", "speciesAnimOverrideSettings", sbq.animOverrideSettings, sbq.tenant.uniqueId)
	end
end

function sbq.saveDigestedPrey()
	sbq.tenant.overrides.statusControllerSettings.statusProperties.sbqStoredDigestedPrey = sbq.storedDigestedPrey
	if sbq.storage.occupier then
		world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSaveDigestedPrey", sbq.storedDigestedPrey)
		world.sendEntityMessage(player.id(), "sbqCrewSaveStatusProperty", "sbqStoredDigestedPrey", sbq.storedDigestedPrey, sbq.tenant.uniqueId)
	end
end

function sbq.onTenantChanged()
	mainTabField:pushEvent("tabChanged", mainTabField.currentTab, mainTabField.currentTab)
end
