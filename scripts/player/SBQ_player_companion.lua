
local old = {
	init = init,
	update = update,
	uninit = uninit,
	recruit_spawn = _ENV.Recruit._spawn,
}

function init()
	old.init()

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
	if world.uniqueEntityId(self.uniqueId) then return end
	old.recruit_spawn(self, position, parameters)
end
