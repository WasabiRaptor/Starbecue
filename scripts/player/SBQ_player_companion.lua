require("/scripts/any/SBQ_petSpawner.lua")

local old = {
	init = init,
	update = update,
	uninit = uninit,
	recruit_spawn = _ENV.Recruit._spawn,
}

function init()
	old.init()

	message.setHandler("sbqParentSetSetting", function(_, _, recruitUuid, uuid, ...)
		local recruit = _ENV.recruitSpawner:getRecruit(recruitUuid)
		if not recruit then
			recruit = _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
		end
		if not recruit then return end
		recruit:sbqSetSetting(...)
	end)
	message.setHandler("sbqParentSetGroupedSetting", function(_, _, recruitUuid, uuid, ...)
		local recruit = _ENV.recruitSpawner:getRecruit(recruitUuid)
		if not recruit then
			recruit = _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
		end
		if not recruit then return end
		recruit:sbqSetGroupedSetting(...)
	end)
	message.setHandler("sbqParentGetTieredUpgrade", function(_, _, recruitUuid, uuid, ...)
		local recruit = _ENV.recruitSpawner:getRecruit(recruitUuid)
		if not recruit then
			recruit = _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
		end
		if not recruit then return end
		recruit:sbqGetTieredUpgrade(...)

	end)
	message.setHandler("sbqParentImportSettings", function(_, _, recruitUuid, uuid, ...)
		local recruit = _ENV.recruitSpawner:getRecruit(recruitUuid)
		if not recruit then
			recruit = _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
		end
		if not recruit then return end
		recruit:sbqImportSettings(...)
	end)
	message.setHandler("sbqParentUpdateType", function(_, _, recruitUuid, uuid, ...)
		local recruit = _ENV.recruitSpawner:getRecruit(recruitUuid)
		if not recruit then
			recruit = _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
		end
		if not recruit then return end
		recruit:sbqUpdateType(...)
	end)
	message.setHandler("sbqParentUpdateIdentities", function(_, _, recruitUuid, uuid, ...)
		local recruit = _ENV.recruitSpawner:getRecruit(recruitUuid)
		if not recruit then
			recruit = _ENV.petSpawner:sbqGetPet(recruitUuid, uuid)
		end
		if not recruit then return end
		recruit:sbqUpdateIdentities(...)
	end)

	message.setHandler("sbqCanGainFollower", function (_,_, recruitUuid)
		return _ENV.checkCrewLimits(recruitUuid) or false
	end)
end

function _ENV.Recruit:_spawn(position, parameters)
	local scriptConfig = self:_scriptConfig(parameters)
	if scriptConfig.sbqOverrideUniqueId then
		self.uniqueId = scriptConfig.sbqOverrideUniqueId
		scriptConfig.uniqueId = scriptConfig.sbqOverrideUniqueId
	end
	if world.getUniqueEntityId(self.uniqueId) then return end
	old.recruit_spawn(self, position, parameters)
end
