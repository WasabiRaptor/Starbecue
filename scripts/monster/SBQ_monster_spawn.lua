local old = {
    init = init,
	update = update
}
sbq = {}

require"/scripts/any/SBQ_RPC_handling.lua"

require "/scripts/any/SBQ_override_dummies.lua"
require "/scripts/actor/SBQ_actor.lua"
require "/scripts/any/SBQ_public_settings.lua"

function init()
    old.init()
	sbq.actorInit()
	sbq.setupPublicSettings()

	sbq.say = monster.say
    sbq.sayPortrait = monster.sayPortrait


	if self.behavior then
		local behavior = {}
		local _behavior = self.behavior
		setmetatable(behavior, {__index = _behavior})
		function behavior:run(...)
			if sbq.isLoungeDismountable() then
				return _behavior:run(...)
			else
				sbq.struggleBehavior(...)
			end
		end
		-- the metatable __index on this table seems to not get this so I have to define it
		function behavior:blackboard(...)
			return _behavior:blackboard(...)
		end
		self.behavior = behavior
	end
end

function sbq.struggleBehavior(dt)
	-- TODO
end

function update(dt)
	sbq.checkRPCsFinished(dt)
    sbq.checkTimers(dt)
	old.update(dt)
end
