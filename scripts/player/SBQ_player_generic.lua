---@diagnostic disable: undefined-global
sbq = {}
require"/scripts/any/SBQ_RPC_handling.lua"
require"/scripts/rect.lua"
require"/scripts/humanoid/SBQ_humanoidAnimator.lua"
require"/scripts/any/SBQ_vore_main.lua"
require"/scripts/humanoid/SBQ_humanoid.lua"
require"/scripts/actor/SBQ_vore_actor.lua"
function init()
	storage = storage or {}
    storage.sbqSettings = storage.sbqSettings or player.getProperty("sbqSettingsStorage")

    sbq.targetPosition = player.aimPosition

    sbq.config = root.assetJson("/sbq.config")

    sbq.actorInit()
	sbq.humanoidInit()
    sbq.init()

	message.setHandler("sbqOpenMetagui", function(_, _, name, sourceEntity, data)
		player.interact("ScriptPane", { gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = name, data = data }, sourceEntity )
    end)

	message.setHandler("sbqQueueTenantRewards", function(_, _, uniqueId, newRewards)
		if not uniqueId then return end
		local tenantRewardsTable = player.getProperty("sbqTenantRewards") or {}
		tenantRewardsTable[uniqueId] = tenantRewardsTable[uniqueId] or {}

		local cumulativeDataTable = player.getProperty("sbqCumulativeData") or {}
		cumulativeDataTable[uniqueId] = cumulativeDataTable[uniqueId] or {}
		cumulativeDataTable[uniqueId].flags = cumulativeDataTable[uniqueId].flags or {}

		for rewardName, reward in pairs(newRewards) do
			if reward.cumulative then
				cumulativeDataTable[uniqueId].flags[rewardName] = true
				cumulativeDataTable[uniqueId].flags[rewardName.."CountRecieved"] = (cumulativeDataTable[uniqueId].flags[rewardName.."CountRecieved"] or 0) + reward.count
			end
			for i = 1, reward.count do
				local loot = root.createTreasure(reward.pool, reward.level or 0)
				for i, item in ipairs(loot or {}) do
					table.insert(tenantRewardsTable[uniqueId], item)
				end
			end
			if reward.dialogue and tenantRewardsTable[uniqueId][1] then
				tenantRewardsTable[uniqueId][#tenantRewardsTable[uniqueId]].rewardDialogue = reward.dialogue
			end
		end

		player.setProperty("sbqTenantRewards", tenantRewardsTable)
		player.setProperty("sbqCumulativeData", cumulativeDataTable)
	end)

	player.interact("ScriptPane", { gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:preyHud" })
end

function update(dt)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
    sbq.checkTimers(dt)

	sbq.update(dt)
end

function uninit()
	player.setProperty("sbqSettingsStorage", storage.sbqSettings)
end
