---@diagnostic disable: undefined-global
local old = {
	init = init,
	update = update
}
sbq = {}
require "/scripts/any/SBQ_override_dummies.lua"
require "/scripts/actor/SBQ_actor.lua"
require "/scripts/any/SBQ_public_settings.lua"

require"/scripts/humanoid/SBQ_humanoidAnimator.lua"
require"/scripts/humanoid/SBQ_humanoid.lua"
require"/scripts/any/SBQ_RPC_handling.lua"

function init()
	old.init()

	sbq.config = root.assetJson("/sbq.config")
	sbq.actorInit()
	sbq.humanoidInit()
	sbq.setupPublicSettings()

	sbq.say = npc.say
	sbq.sayPortrait = npc.sayPortrait
	sbq.setLoungeControlHeld = npc.setLoungeControlHeld
	sbq.releaseLoungeControl = npc.releaseLoungeControl


	message.setHandler("sbqInteract", function(_, _, pred, predData)
		return interact({ sourceId = pred, sourcePosition = world.entityPosition(pred), predData = predData })
	end)

	if self.behavior then
		local behavior = {}
		local _behavior = self.behavior
		function behavior:run(...)
			if sbq.isLoungeDismountable() then
				_behavior:run(...)
			else
				sbq.struggleBehavior(...)
			end
		end
		-- the metatable __index on this table seems to not get this so I have to define it
		function behavior:blackboard(...)
			return _behavior:blackboard(...)
		end
		function behavior:clear(...)
			return _behavior:clear(...)
		end
		self.behavior = behavior
	end
end

function sbq.maybeConvert()
	status.setStatusProperty("sbqDidVornyConvertCheck", true)
	if config.getParameter("uniqueId") or ((config.getParameter("behaviorConfig") or {}).beamOutWhenNotInUse == true) then
		return
	end
	status.setStatusProperty("sbqDidVornyConvertCheck", true)
	if tenant ~= nil then
		local npcType = sbq.config.vornyConvertTable[npc.npcType()]
		if (math.random(8) == 8) and npcType ~= nil then
			sbq.tenant_setNpcType(npcType)
		end
	end
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)

	old.update(dt)
end

function sbq.generateRecruitInfo()
	local recruitInfo = old.getgenerateRecruitInfo()
	recruitInfo.config.parameters.scriptConfig.preservedUuid = recruitInfo.uniqueId
	return recruitInfo
end
