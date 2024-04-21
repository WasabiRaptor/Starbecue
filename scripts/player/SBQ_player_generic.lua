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
	sbq.loungingIn = player.loungingIn

	sbq.config = root.assetJson("/sbq.config")
	sbq.pronouns = root.assetJson("/sbqPronouns.config")

	sbq.actorInit()
	sbq.settingsInit()
	sbq.humanoidInit()
	function sbq.setProperty(...)
		if player.getProperty("sbqAgreedTerms") then status.setStatusProperty(...) end
	end
	if player.getProperty("sbqAgreedTerms") then
		sbq.init(root.speciesConfig(humanoid.species()).voreConfig or "/humanoid/any/vore.config")
		sbq.actorMessages()
	else
		status.setStatusProperty("sbqPublicSettings", nil)
		sbq.lists = {}
		sbq.voreConfig = root.fetchConfigArray(root.speciesConfig(humanoid.species()).voreConfig or "/humanoid/any/vore.config")
		sbq.setupSettingMetatables("player")
	end
	sbq.notifyPlayer()

	message.setHandler("sbqGuiMessage",function (_,_,message,...)
		player.interact("Message", {messageType = message, messageArgs = {...}})
	end)
	message.setHandler("sbqInteractWith", function (_,_,entityId)
		player.interactWithEntity(entityId)
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
		sbq.setCurrentLocationData(locationData)
		local struggleActions = locationData.struggleActions or {}
		player.interact("ScriptPane", {
			baseConfig = "/interface/scripted/sbq/preyHud/preyHud.config",
			time = additionalData.time,
			location = locationData.name,
			directions = {
				up = (struggleActions.up and (struggleActions.up.indicate or struggleActions.any.indicate or "default")),
				down = (struggleActions.down and (struggleActions.down.indicate or struggleActions.any.indicate or "default")),
				left = (struggleActions.left and (struggleActions.left.indicate or struggleActions.any.indicate or "default")),
				right = (struggleActions.right and (struggleActions.right.indicate or struggleActions.any.indicate or "default")),
				front = (struggleActions.front and (struggleActions.front.indicate or struggleActions.any.indicate or "default")),
				back = (struggleActions.back and (struggleActions.back.indicate or struggleActions.any.indicate or "default")),
				interact = world.isEntityInteractive(id) and "default"
			}
		}, id)
	end)

	message.setHandler("sbqRefreshHudOccupants", function(_, _, occupants)
		player.interact("ScriptPane", { gui = { }, scripts = {"/metagui/sbq/build.lua"}, data = { occupants = occupants }, ui = "starbecue:predHud" })
	end)

	message.setHandler("sbqChooseLocation", function(_, _, id, target, locations)
		local options = {}
		for _, data in ipairs(locations or {}) do
			table.insert(options, {
				name = sbq.getString(data.name),
				args = { "moveToLocation", target, data.location, data.subLocation },
				locked = not data.space,
			})
		end
		player.interact("ScriptPane", {
			baseConfig = "/interface/scripted/sbq/radialMenu/sbqRadialMenu.config",
			options = options,
			default = {
				messageTarget = id,
				message = "sbqTryAction",
				close = true
			},
			cancel = {
				args = false,
				message = false
			}
		}, player.id())
	end)
end

function update(dt)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)

	sbq.update(dt)
end

function uninit()
	player.setProperty("sbqSettingsStorage", storage.sbqSettings)
	player.setProperty("sbqUpgradesStorage", storage.sbqUpgrades)
end
