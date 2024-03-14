---@diagnostic disable: undefined-global
sbq = {}
require"/scripts/any/SBQ_RPC_handling.lua"
require"/scripts/rect.lua"
require"/scripts/humanoid/SBQ_humanoidAnimator.lua"
require"/scripts/any/SBQ_vore_main.lua"
require"/scripts/humanoid/SBQ_humanoid.lua"
require "/scripts/actor/SBQ_actor.lua"
require"/scripts/player/SBQ_player_notifs.lua"
function init()
	storage = storage or {}
    storage.sbqSettings = storage.sbqSettings or player.getProperty("sbqSettingsStorage")
    storage.sbqUpgrades = storage.sbqUpgrades or player.getProperty("sbqUpgradesStorage")

    sbq.targetPosition = player.aimPosition

    sbq.config = root.assetJson("/sbq.config")

    sbq.actorInit()
    sbq.humanoidInit()
	function sbq.setProperty(...)
		if player.getProperty("sbqAgreedTerms") then status.setStatusProperty(...) end
	end
	if player.getProperty("sbqAgreedTerms") then
        sbq.init()
        sbq.actorMessages()
    else
        status.setStatusProperty("sbqPublicSettings", nil)
		message.setHandler("sbqSetGroupedSetting", function (_,_, ...)
			return sbq.setGroupedSetting(...)
		end)
		message.setHandler("sbqSetSetting", function (_,_, ...)
			return sbq.setSetting(...)
        end)
		sbq.lists = {}
		sbq.voreConfig = root.fetchConfigArray(storage.lastVoreConfig or {})
		sbq.setupSettingMetatables("player")
    end
    sbq.notifyPlayer()

	message.setHandler("sbqGuiMessage",function (_,_,message,...)
		player.interact("Message", {messageType = message, messageArgs = {...}})
	end)

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

	message.setHandler("sbqRefreshLocationData", function(_, _, id, locationData, additionalData)
		sbq.currentLocationData = locationData
		local struggleActions = locationData.struggleActions or {}
		player.interact("ScriptPane", {
			baseConfig = "/interface/scripted/sbq/preyHud/preyHud.config",
			time = additionalData.time,
			progressBar = additionalData.progressBar,
			location = locationData.name,
			directions = {
				up = (struggleActions.up and (struggleActions.up.indicate or struggleActions.any.indicate or "default")),
				down = (struggleActions.down and (struggleActions.down.indicate or struggleActions.any.indicate or "default")),
				left = (struggleActions.left and (struggleActions.left.indicate or struggleActions.any.indicate or "default")),
				right = (struggleActions.right and (struggleActions.right.indicate or struggleActions.any.indicate or "default")),
				front = (struggleActions.front and (struggleActions.front.indicate or struggleActions.any.indicate or "default")),
				back = (struggleActions.back and (struggleActions.back.indicate or struggleActions.any.indicate or "default")),
			}
		}, id)
    end)

    message.setHandler("sbqRefreshHudOccupants", function(_, _, occupants)
		player.interact("ScriptPane", { gui = { }, scripts = {"/metagui/sbq/build.lua"}, data = { occupants = occupants }, ui = "starbecue:predHud" })
	end)
end

function update(dt)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
    sbq.checkTimers(dt)

	sbq.update(dt)
end

function uninit()
    player.setProperty("sbqSettingsStorage", storage.sbqSettings)
	player.setProperty("sbqUpgradesStorage", storage.sbqUpgrades)
end
