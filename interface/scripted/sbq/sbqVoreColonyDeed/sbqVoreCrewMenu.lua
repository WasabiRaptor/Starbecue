---@diagnostic disable: undefined-global

sbq.followers = world.sendEntityMessage(player.id(), "sbqPlayerCompanions", "getCompanions", "followers"):result()

sbq.storage.occupier = { tenants = {}}

for i, follower in ipairs(sbq.followers) do
	if (follower.config.parameters.scriptConfig or {}).ownerUuid == player.uniqueId() then
		local tenant = {
			overrides = follower.config.parameters,
			species = follower.config.species,
			uniqueId = follower.uniqueId,
			type = follower.config.type,
			followerTable = follower
		}
		follower.config.parameters.scriptConfig.preservedUuid = follower.uniqueId
		table.insert(sbq.storage.occupier.tenants, tenant)
	end
end

function sbq.savePredSettings()
	sbq.tenant.overrides.scriptConfig.sbqSettings = sbq.predatorSettings
	if sbq.storage.occupier then
		world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSaveSettings", sbq.predatorSettings)

		for i, follower in ipairs(sbq.followers) do
			if follower.uniqueId == sbq.tenant.uniqueId then
				world.sendEntityMessage(player.id(), "sbqSetRecruit", follower)
				break
			end
		end
	end
end
sbq.saveSettings = sbq.savePredSettings

function sbq.savePreySettings()
	sbq.tenant.overrides.statusControllerSettings.statusProperties.sbqPreyEnabled = sbq.preySettings
	if sbq.storage.occupier then
		world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSavePreySettings", sbq.preySettings)

		for i, follower in ipairs(sbq.followers) do
			if follower.uniqueId == sbq.tenant.uniqueId then
				world.sendEntityMessage(player.id(), "sbqSetRecruit", follower)
				break
			end
		end
	end
end

function sbq.changeAnimOverrideSetting(settingname, settingvalue)
	sbq.animOverrideSettings[settingname] = settingvalue
	sbq.tenant.overrides.statusControllerSettings.statusProperties.speciesAnimOverrideSettings = sbq.animOverrideSettings
	if sbq.storage.occupier then
		world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSaveAnimOverrideSettings", sbq.animOverrideSettings)
		world.sendEntityMessage(sbq.tenant.uniqueId, "speciesAnimOverrideRefreshSettings", sbq.animOverrideSettings)
		world.sendEntityMessage(sbq.tenant.uniqueId, "animOverrideScale", sbq.animOverrideSettings.scale)

		for i, follower in ipairs(sbq.followers) do
			if follower.uniqueId == sbq.tenant.uniqueId then
				world.sendEntityMessage(player.id(), "sbqSetRecruit", follower)
				break
			end
		end
	end
end

function sbq.saveDigestedPrey()
	if sbq.storage.occupier then
		world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSaveDigestedPrey", sbq.storedDigestedPrey)
		for i, follower in ipairs(sbq.followers) do
			if follower.uniqueId == sbq.tenant.uniqueId then
				world.sendEntityMessage(player.id(), "sbqSetRecruit", follower)
				break
			end
		end
	end
end

function sbq.onTenantChanged()

	mainTabField:pushEvent("tabChanged", sbq.selectedMainTabFieldTab, sbq.selectedMainTabFieldTab)
end
