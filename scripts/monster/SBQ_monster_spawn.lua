sbq = {}
require "/scripts/any/SBQ_RPC_handling.lua"
require "/scripts/any/SBQ_util.lua"
require "/scripts/any/SBQ_override_dummies.lua"
require "/scripts/actor/SBQ_actor.lua"
require "/scripts/any/SBQ_settings.lua"
local old = {
	init = init or (function ()end),
	update = update or (function ()end),
	uninit = uninit or (function ()end)
}

function init()
	old.init()
	sbq.config = root.assetJson("/sbq.config")
	sbq.settings = sbq._Settings.new(
		sb.jsonMerge(
			config.getParameter("sbqSettingsConfig") or {
				hideBehaviorSettings = true,
				hidePredSettings = true,
			}
		),
		storage.sbqSettings or config.getParameter("sbqSettings"),
		entity.entityType()
	)
	sbq.settings:setMessageHandlers()

	sbq.upgrades = sbq._Upgrades.new(storage.sbqUpgrades or config.getParameter("sbqUpgrades"))
	sbq.upgrades:setMessageHandlers()

	sbq.upgrades:apply(sbq.settings)
	if not sbq.upgrades.storedUpgrades.candyBonus then
		for i = 1, math.floor(math.max(monster.level(), 1)) do
			sbq.upgrades:setTiered("candyBonus", i, 1)
		end
	end

	sbq.settings:setPublicSettings()
	sbq.settings:setStatSettings()

	sbq.say = monster.say
	sbq.sayPortrait = monster.sayPortrait
	sbq.setLoungeControlHeld = monster.setLoungeControlHeld
	sbq.isLoungeControlHeld = monster.isLoungeControlHeld
	sbq.loungingIn = monster.loungingIn
	sbq.resetLounging = monster.resetLounging

	message.setHandler("sbqHideDeathParticles", function()
		monster.setDeathParticleBurst()
	end)
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	if status.statPositive("sbqIsPrey") then
		sbq.struggleBehavior(dt)
	end
	old.update(dt)

	if sbq.loungingIn() or sbq.timerList.missingPredCheck then return end
	local occupantData = status.statusProperty("sbqOccupantStorage")
	if occupantData then
		occupantData = root.loadVersionedJson(occupantData, "sbqOccupantStorage")
	end
	if occupantData
		and (not ((occupantData.flags or {}).newOccupant or (occupantData.flags or {}).releasing))
		and sbq.timer("missingPredCheck", sbq.config.missingPredCheck) and occupantData.predUUID
	then
		local eid = world.uniqueEntityId(occupantData.predUUID)
		if eid then
			if not sbq.namedRPCList.missingPredFound then
				sbq.addNamedRPC("missingPredFound", world.sendEntityMessage(eid, "sbqReceiveOccupant", sb.jsonMerge(occupantData,{entityId = entity.id()})), function (response)
					if response then
						local success, reason = table.unpack(response)
						if not success then
							if reason ~= "inactive" then
								status.setStatusProperty("sbqOccupantStorage", nil)
								status.clearPersistentEffects("sbqMissingPred")
							end
						end
					end
				end)
			end
		else
			status.setPersistentEffects("sbqMissingPred",{"sbqMissingPred"})
			sbq.timer("missingPredEscape", sbq.config.missingPredTimeout, function()
				local occupantData = status.statusProperty("sbqOccupantStorage")
				if occupantData then
					occupantData = root.loadVersionedJson(occupantData, "sbqOccupantStorage")
				end
				if occupantData then
					local eid = world.uniqueEntityId(occupantData.predUUID)
					if not eid then
						status.setStatusProperty("sbqOccupantStorage", nil)
						status.clearPersistentEffects("sbqMissingPred")
					end
				end
			end)
			sbq.logInfo(("Could not find pred '%s' time remaining: %s"):format(occupantData.predUUID, sbq.timerRemaining("missingPredEscape")))
		end
	end
end

function uninit()
	old.uninit()
	storage = storage or {}
	storage.sbqSettings = sbq.settings:save()
	storage.sbqUpgrades = sbq.upgrades:save()
end

function sbq.parentEntity()
	return _ENV.capturable and (_ENV.capturable.tetherUniqueId() or _ENV.capturable.ownerUuid()) or storage.respawner, _ENV.capturable and (_ENV.capturable.podUuid()), true
end
