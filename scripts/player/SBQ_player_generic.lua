---@diagnostic disable: undefined-global
sbq = {}
require "/scripts/any/SBQ_RPC_handling.lua"
require "/scripts/rect.lua"
require "/scripts/any/SBQ_vore_main.lua"
require "/scripts/humanoid/SBQ_humanoid.lua"
require "/scripts/actor/SBQ_actor.lua"
require "/scripts/player/SBQ_player_notifs.lua"
require "/scripts/any/SBQ_util.lua"
local old = {
	init = init or function () end,
	update = update or function() end,
	uninit = uninit or function () end
}
local occupantData
local sbqCommands = {}
function init()
	old.init()
	player.setProperty("sbqPredHudOpen", false)
	storage = storage or {}
	storage.sbqSettings = storage.sbqSettings or player.getProperty("sbqSettingsStorage")
	storage.sbqUpgrades = storage.sbqUpgrades or player.getProperty("sbqUpgradesStorage")

	sbq.targetPosition = player.aimPosition
	sbq.loungingIn = player.loungingIn
	sbq.resetLounging = player.resetLounging
	sbq.species = player.species
	sbq.gender = player.gender
	sbq.humanoid = player
	sbq.humanoidIdentity = player.humanoidIdentity
	sbq.setHumanoidIdentity = player.setHumanoidIdentity
	sbq.getItemSlot = player.equippedItem
	sbq.setItemSlot = player.setEquippedItem

	sbq.config = root.assetJson("/sbq.config")
	sbq.pronouns = root.assetJson("/sbqPronouns.config")

	for _, v in ipairs(storage.sbqCapturedOccupants or {}) do
		table.insert(sbq.Occupants.captured, sbq._CapturedOccupant.new(v))
		sbq.Occupants.queueHudRefresh = true
	end

	local speciesConfig = root.speciesConfig(player.species())
	local humanoidConfig = player.humanoidConfig()
	sbq.settings = sbq._Settings.new(
		sb.jsonMerge(
			speciesConfig.sbqSettingsConfig or {},
			humanoidConfig.sbqSettingsConfig or {},
			sbqSettingsConfig()
		),
		storage.sbqSettings,
		entity.entityType()
	)
	sbq.settings:setParameterSettings()
	sbq.settings:setMessageHandlers(true)

	sbq.upgrades = sbq._Upgrades.new(storage.sbqUpgrades)
	sbq.upgrades:setMessageHandlers(true)

	sbq.upgrades:apply(sbq.settings)
	sbq.settings:setPublicSettings()
	sbq.settings:setStatSettings()

	humanoidConfig = player.humanoidConfig()

	sbq.humanoidInit()
	if player.getProperty("sbqAgreedTerms") then
		if player.getHumanoidParameter("sbqEnabled") then
			if humanoidConfig.sbqConfig and humanoidConfig.sbqEnabled and not (humanoidConfig.sbqPostloadError or (humanoidConfig.sbqCompatible == false)) then
				sbq.init(humanoidConfig.sbqConfig)
			else
				sbq.uninit("refresh")
			end
		else
			player.setHumanoidParameter("sbqEnabled", true)
			player.refreshHumanoidParameters()
		end
	end
	sbq.notifyPlayer()

	message.setHandler({ name = "/sbq", localOnly = true }, function(args)
		local parsed = {chat.parseArguments(args)}
		local command = table.remove(parsed, 1)
		if not command then
			return "[SBQ]" .. sbq.getString(":sbqCommands")
		elseif type(sbqCommands[command:lower()]) == "function" then
			return sbqCommands[command:lower()](table.unpack(parsed))
		else
			return "[SBQ]" .. sbq.getString(":invalidCommand"):format(command:lower())
		end
	end)

	message.setHandler("sbqInteractWith", function(_, _, entityId)
		player.interactWithEntity(entityId)
	end)

	message.setHandler("sbqOpenMetagui", function(_, _, name, sourceEntity, data)
		player.interact("ScriptPane", { gui = {}, scripts = { "/metagui/sbq/build.lua" }, ui = name, data = data },
			sourceEntity)
	end)

	message.setHandler("sbqCloseDialogueBox", function(_, _, ...)
		interface.sendMessage("sbqCloseDialogueBox", ...)
	end)
	message.setHandler("sbqPredHudPreyDialogue", function(_, _, ...)
		interface.sendMessage("sbqPredHudPreyDialogue", ...)
	end)
	message.setHandler("sbqHudRefreshPortrait", function(_, _, ...)
		interface.sendMessage("sbqHudRefreshPortrait", ...)
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
				cumulativeDataTable[uniqueId].flags[rewardName .. "CountReceived"] = (cumulativeDataTable[uniqueId].flags[rewardName .. "CountReceived"] or 0) +
					reward.count
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

	message.setHandler("sbqRefreshLocationData", function(_, _, id, locationData, newOccupantData)
		sbq.setCurrentLocationData(id, locationData, newOccupantData)
		player.setProperty("sbqPredPortrait", world.entityPortrait(id, "full"))
		player.setProperty("sbqPredWarpAttempted", 0)
		if interface.sendMessage("sbqRefreshLocationData", id, locationData, newOccupantData):result() then return end
		player.interact("ScriptPane", {
			baseConfig = "/interface/scripted/sbq/preyHud/preyHud.config",
			gui = player.getProperty("sbqPredHudOpen") and { panefeature = { offset = { -104, 0 } } } or {},
			locationData = locationData,
			occupantData = newOccupantData
		}, id)
	end)

	message.setHandler("sbqRefreshHudOccupants", function(_, _, occupants, captured, settingsData)
		if interface.sendMessage("sbqRefreshHudOccupants", occupants, captured, settingsData):result() then return end
		player.interact("ScriptPane",
			{
				gui = {},
				scripts = { "/metagui/sbq/build.lua" },
				data = { occupants = occupants, captured = captured, sbq = settingsData },
				ui = "starbecue:predHud"
			})
	end)

	message.setHandler("sbqChooseLocation", function(_, _, id, target, locations)
		local options = {}
		for _, data in ipairs(locations or {}) do
			table.insert(options, {
				name = sbq.getString(data.name),
				args = { false, "moveToLocation", target, data.location, data.subLocation },
				locked = not data.space,
			})
		end
		player.interact("ScriptPane", {
			baseConfig = "/interface/wr/radialMenu/radialMenu.config",
			sourceRadius = -1,
			options = options,
			default = {
				onDown = true,
				messageTarget = id,
				message = "sbqRequestAction",
				close = true,
				description = sbq.getString((entity.id() == target) and ":chooseLocationPreyPrompt" or
					":chooseLocationDesc")
			},
			cancel = {
				args = false,
				message = false
			}
		}, id)
	end)

	message.setHandler("sbqPromptAction", function(_, _, id, action, isDom)
		local options = {
			{
				name = sbq.getString(":no"),
				args = { false, isDom, "no", action, entity.id() }
			},
			{
				name = sbq.getString(":yes"),
				args = { true, isDom, "yes", action, entity.id() }
			},
			{
				name = sbq.getString(":noYes"),
				args = { true, isDom, "noYes", action, entity.id() }
			}
		}
		local description = sb.replaceTags(sbq.getString((isDom and ":genericDomPrompt") or ":genericSubPrompt"),
			{ actionName = sbq.getString(":" .. action), entityName = sbq.entityName(id) })
		local sourceRadius
		if (player.loungingIn() == id) or sbq.Occupants.entityId[tostring(id)] then
			sourceRadius = -1
		end
		player.interact("ScriptPane", {
			baseConfig = "/interface/wr/radialMenu/radialMenu.config",
			sourceRadius = sourceRadius,
			options = options,
			default = {
				onDown = true,
				messageTarget = id,
				description = description,
				message = "sbqPromptResponse",
				close = true
			},
			cancel = {
				args = false,
				message = false
			}
		}, id)
	end)
	message.setHandler("sbqPromptResponse", function(_, _, tryAction, isDom, line, action, target)
		if tryAction then
			if isDom then
				sbq.SpeciesScript:requestAction(false, action, target)
			else
				world.sendEntityMessage(target, "sbqRequestAction", false, action, entity.id())
			end
		end
	end)

	message.setHandler("sbqRequestActions", function(_, _, id, actionList)
		local sourceRadius
		if (player.loungingIn() == id) or sbq.Occupants.entityId[tostring(id)] then
			sourceRadius = -1
		end
		player.interact("ScriptPane", {
			baseConfig = "/interface/wr/radialMenu/radialMenu.config",
			sourceRadius = sourceRadius,
			options = sbq.buildActionRequestOptions(id, actionList),
			default = {
				onDown = true,
			},
			cancel = {
				args = false,
				message = false,
				close = true
			}
		}, entity.id())
	end)
	message.setHandler("sbqRequestRecruitActions", function(_, _, id, actionList, isFollowing, recruitUuid)
		local options = sbq.buildActionRequestOptions(id, actionList)
		if isFollowing then
			table.insert(options, 1, {
				name = sbq.getString(":stay"),
				messageTarget = id,
				message = "sbqRecruitUnfollow",
				close = true
			})
		else
			table.insert(options, 1, {
				name = sbq.getString(":follow"),
				messageTarget = id,
				message = "sbqRecruitFollow",
				close = true
			})
		end
		local sourceRadius
		if (player.loungingIn() == id) or sbq.Occupants.entityId[tostring(id)] then
			sourceRadius = -1
		end
		player.interact("ScriptPane", {
			sourceRadius = sourceRadius,
			baseConfig = "/interface/wr/radialMenu/radialMenu.config",
			options = options,
			default = {
				onDown = true,
			},
			cancel = {
				args = false,
				message = false,
				close = true
			}
		}, entity.id())
	end)
	message.setHandler("sbqHideDeathParticles", function()
		player.setDeathParticleBurst()
	end)
	message.setHandler("sbqRequestFailed", function (_,_,success,reason)
		interface.queueMessage(sbq.getString(":request_" .. tostring(reason)))
	end)
	message.setHandler({ name = "sbqSetIdentity", localOnly = true }, function (identity, parameters)
		local speciesIdentities = storage.sbqSpeciesIdentities or status.statusProperty("sbqSpeciesIdentities") or {}
		identity.parameters = parameters

		speciesIdentities[identity.species] = identity
		storage.sbqSpeciesIdentities = speciesIdentities
		status.setStatusProperty("sbqSpeciesIdentities", speciesIdentities)

		player.setHumanoidParameters(parameters)
		player.setHumanoidIdentity(identity)
	end)

	sbq.timer("preyMissingWaitPrompt", 60)
	occupantData = status.statusProperty("sbqOccupantStorage")
	if occupantData then
		occupantData = root.loadVersionedJson(occupantData, "sbqOccupantStorage")
	end

end

function update(dt)
	old.update(dt)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)

	sbq.update(dt)

	if sbq.loungingIn() or sbq.timerRunning("missingPredCheck") or (not entity.id()) then return end
	if occupantData
		and (not (occupantData.flags.newOccupant or occupantData.flags.releasing))
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
								occupantData = nil
								status.setStatusProperty("sbqOccupantStorage", nil)
								status.clearPersistentEffects("sbqMissingPred")
							end
						else
							occupantData = nil
						end
					end
				end)
			end
		else
			status.setPersistentEffects("sbqMissingPred", { "sbqMissingPred" })
			if not ((player.getProperty("sbqPredWarpAttempted") or 0) >= sbq.config.missingPredWarpAttempts) and (occupantData.playerPred or occupantData.crewPred) and sbq.timer("missingPredWarp", sbq.config.missingPredWarpDelay) then
				if occupantData.playerPred then
					pcall(player.warp("player:" .. occupantData.predUUID, "beam"))
				elseif occupantData.crewPred and (occupantData.parentUUID ~= player.uniqueId()) then
					pcall(player.warp("player:" .. occupantData.parentUUID, "beam"))
				end
				player.setProperty("sbqPredWarpAttempted", (player.getProperty("sbqPredWarpAttempted") or 0) + 1)
			elseif not sbq.namedRPCList.missingPredCheck then
				sbq.addNamedRPC("missingPredCheck", player.confirm({
					paneLayout = "/interface/windowconfig/portraitconfirmation.config:paneLayout",
					icon = "/interface/confirmation/confirmationicon.png",
					title = sbq.getString(":missingPred"),
					message = sbq.getString(":missingPredPrompt"),
					okCaption = sbq.getString(":missingPredEscape"),
					cancelCaption = sbq.getString(":missingPredWait"),
					images = { portrait = player.getProperty("sbqPredPortrait") or jarray() }
				}), function(escape)
					if escape then
						status.setStatusProperty("sbqOccupantStorage", nil)
						status.clearPersistentEffects("sbqMissingPred")
						occupantData = nil
					else
						player.setProperty("sbqPredWarpAttempted", 0)
					end
				end)
			end
		end
	end
end

function uninit()
	old.uninit()
	sbq.uninit(status.resourcePositive("health") and "uninit" or "died")
	storage = storage or {}
	storage.sbqSettings = sbq.settings:save()
	storage.sbqUpgrades = sbq.upgrades:save()
	player.setProperty("sbqSettingsStorage", storage.sbqSettings)
	player.setProperty("sbqUpgradesStorage", storage.sbqUpgrades)
	storage.sbqCapturedOccupants = jarray()
	for _, capturedOccupant in ipairs(sbq.Occupants.captured) do
		table.insert(storage.sbqCapturedOccupants, capturedOccupant:save())
	end
end

function sbq.buildActionRequestOptions(id, actionList)
	local options = {}
	for _, action in ipairs(actionList or {}) do
		table.insert(options, {
			name = sbq.getString((action.name or (":" .. action.action)) or ""),
			args = { false, action.action, entity.id(), table.unpack(action.args or {}) },
			locked = not action.available,
			description = sbq.getString(action.requestDescription or (":" .. action.action .. "RequestDesc")),
			messageTarget = id,
			message = "sbqRequestAction",
			close = true
		})
	end
	return options
end


function sbq.collapseEssenceStacks()
	local count = 0
	local output = {}
	for _, item in ipairs(player.itemsWithTag("sbqEssence") or {}) do
		count = count + item.count
		local uuid = sbq.query(item.parameters, { "npcArgs", "npcParam", "scriptConfig", "uniqueId" }) or
			sbq.query(item.parameters, { "npcArgs", "npcParam", "identity", "name" }) or "unknown"
		local predUUID = item.parameters.predUuid or "noPred"
		output[predUUID] = output[predUUID] or {}
		output[predUUID][uuid] = output[predUUID][uuid] or {}
		local current = output[predUUID][uuid][item.name]

		local createdDate = 0
		local createdDateType = type(sbq.query(item.parameters, { "createdDate" }))
		if createdDateType == "number" then
			createdDate = item.parameters.createdDate
		elseif createdDateType == "table" then
			createdDate = os.time(item.parameters.createdDate)
		end

		local curCreatedDate = 0
		local curCreatedDateType = type(sbq.query(current, { "parameters", "createdDate" }))
		if curCreatedDateType == "number" then
			curCreatedDate = current.parameters.createdDate
		elseif curCreatedDateType == "table" then
			curCreatedDate = os.time(current.parameters.createdDate)
		end

		if createdDate >= curCreatedDate then
			output[predUUID][uuid][item.name] = item
			output[predUUID][uuid][item.name].count = output[predUUID][uuid][item.name].count +
				((current or {}).count or 0)
		end
	end
	player.consumeTaggedItem("sbqEssence", count)
	player.cleanupItems()

	for pred, prey in pairs(output) do
		for _, items in pairs(prey) do
			for _, item in pairs(items) do
				player.giveItem(item)
			end
		end
	end
end

function teleportOut()
	local occupantData = status.statusProperty("sbqOccupantStorage")
	if occupantData and not (occupantData.playerPred or occupantData.crewPred) then
		status.setStatusProperty("sbqOccupantStorage", nil)
		status.clearPersistentEffects("sbqMissingPred")
	end
	for i, occupant in ipairs(sbq.Occupants.list) do
		if world.entityType(occupant.entityId) ~= "player" then
			occupant:remove("teleportOut")
		end
	end
end

function die()
end

function sbqCommands.help(name)

	if not name then
		player.interact("ScriptPane", { gui = {}, scripts = { "/metagui/sbq/build.lua" }, data = { helpPage = "commands" }, ui = "starbecue:help" })
		return "[SBQ] ".. sbq.getString(":openedHelp")
	end
	if type(sbqCommands[name]) == "function" then
		return "[SBQ] ".. (sbq.getString(":helpCommand."..(name):lower())) .. ((name == "help") and ("\n[SBQ]" .. sbq.getString(":sbqCommands")) or (""))
	else
		return "[SBQ] ".. sbq.getString(":help_invalid")
	end
end
function sbqCommands.settings()
	player.interact("ScriptPane",
		{ gui = {}, scripts = { "/metagui/sbq/build.lua" }, ui = "starbecue:playerSettings" })
	return "[SBQ] ".. sbq.getString(":openedSettings")
end
function sbqCommands.config()
	player.interact("ScriptPane",
		{ gui = {}, scripts = { "/metagui/sbq/build.lua" }, ui = "starbecue:globalConfig" })
	return "[SBQ] ".. sbq.getString(":openedConfig")
end
function sbqCommands.escape()
	if player.loungingIn() then
		world.sendEntityMessage(player.loungingIn(), "sbqReleaseOccupant", player.id())
	end
	world.sendEntityMessage(player.id(), "sbqReleased")
end
function sbqCommands.settieredupgrade(...)
	sbq.upgrades:setTiered(...)
	return "[SBQ] ".. sbq.getString(":appliedTieredUpgrade"):format(...)
end
function sbqCommands.setupgrade(...)
	sbq.upgrades:set(...)
	return "[SBQ] ".. sbq.getString(":appliedUpgrade"):format(...)
end
function sbqCommands.setsetting(setting, value, groupName, groupId, ...)
	sbq.settings:set(setting, value, groupName, groupId, ...)
	if groupName and groupId then
		return "[SBQ] ".. sbq.getString(":appliedGroupSetting"):format(setting, value, groupName, groupId)
	else
		return "[SBQ] ".. sbq.getString(":appliedSetting"):format(setting, value)
	end
end
function sbqCommands.skiptotier(tier)
	local result = ""
	for i = 1, tier do
		for _, v in ipairs(chat.command(("/sbq setTieredUpgrade candyBonus %s 1"):format(i))) do
			result = result..v.."\n"
		end
	end
	return result
end

function sbqCommands.customize()
	player.interact("ScriptPane",{
		gui = {},
		scripts = { "/metagui/sbq/build.lua" },
		data = { identity = player.humanoidIdentity(), parameters = player.getHumanoidParameters() },
		ui = "starbecue:customize"
	}, player.id())
	return "[SBQ] ".. sbq.getString(":openedCustomize")
end
