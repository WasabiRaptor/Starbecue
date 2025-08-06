sbq = {}
require"/scripts/any/SBQ_RPC_handling.lua"
require "/scripts/any/SBQ_override_dummies.lua"
require "/scripts/actor/SBQ_actor.lua"
require "/scripts/any/SBQ_public_settings.lua"
local old = {
	init = init,
	update = update
}

function init()
	old.init()
	sbq.config = root.assetJson("/sbq.config")
	sbq.setupPublicSettings()

	sbq.say = monster.say
	sbq.sayPortrait = monster.sayPortrait
	sbq.setLoungeControlHeld = monster.setLoungeControlHeld
	sbq.isLoungeControlHeld = monster.isLoungeControlHeld
	sbq.releaseLoungeControl = monster.releaseLoungeControl
	sbq.loungingIn = monster.loungingIn
	sbq.resetLounging = monster.resetLounging

	-- if self.behavior then
	-- 	local behavior = {}
	-- 	local _behavior = self.behavior
	-- 	function behavior:run(...)
	-- 		if not status.statPositive("sbqIsPrey") then
	-- 			return _behavior:run(...)
	-- 		else
	-- 			sbq.struggleBehavior(...)
	-- 		end
	-- 	end
	-- 	setmetatable(behavior, {
	-- 		__index = function (t, k)
	-- 			return _behavior[k]
	-- 		end
	-- 	})
	-- 	self.behavior = behavior
	-- end

	local occupantData = status.statusProperty("sbqOccupantData")
	if occupantData
		and not ((occupantData.flags or {}).newOccupant or (occupantData.flags or {}).releasing)
		and sbq.timer("missingPredCheck", sbq.config.missingPredCheck) and occupantData.predUUID
		and not sbq.loungingIn()
	then
		local eid = world.getUniqueEntityId(occupantData.predUUID)
		if eid then
			if not sbq.namedRPCList.missingPredFound then
				sbq.addNamedRPC("missingPredFound", world.sendEntityMessage(eid, "sbqRecieveOccupants", {sb.jsonMerge(occupantData,{entityId = entity.id()})}))
			end
		else
			status.setPersistentEffects("sbqMissingPred",{"sbqMissingPred"})
			sbq.timer("missingPredEscape", sbq.config.missingPredTimeout, function()
				local occupantData = status.statusProperty("sbqOccupantData")
				if occupantData then
					local eid = world.getUniqueEntityId(occupantData.predUUID)
					if not eid then
						status.setStatusProperty("sbqOccupantData", nil)
						status.clearPersistentEffects("sbqMissingPred")
					end
				end
			end)
		end
	end
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	old.update(dt)
end

function sbq.parentEntity()
	return _ENV.capturable and (_ENV.capturable.tetherUniqueId() or _ENV.capturable.ownerUuid()) or storage.respawner, _ENV.capturable and (_ENV.capturable.podUuid()), true
end
