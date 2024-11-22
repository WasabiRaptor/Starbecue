require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/scripts/poly.lua"
require "/scripts/interp.lua"
require "/scripts/any/SBQ_util.lua"
require "/scripts/any/SBQ_override_dummies.lua"
require "/scripts/any/SBQ_settings.lua"
require "/scripts/any/SBQ_anim_util.lua"

_SpeciesScript = {scripted = true}
_SpeciesScript.__index = _SpeciesScript

_State = {scripted = true}
_State.__index = _State

_Action = {scripted = true}
_Action.__index = _Action

_Location = {scripted = true}
_Location.__index = _Location

_Occupant = {scripted = true}
_Occupant.__index = _Occupant

Species = {}
SpeciesScript = {
	baseLocations = {},
	locations = {},
	states = {}
}
setmetatable(SpeciesScript, _SpeciesScript)

Occupants = {
	list = {},
	seat = {},
	entityId = {},
	locations = {}
}

function controlPressed(seat, control, time)
	if SpeciesScript.active and Occupants.seat[seat] then
		Occupants.seat[seat]:controlPressed(control, time)
	else
		local eid = loungeable.entityLoungingIn(seat)
		if eid and world.entityExists(eid) then
			world.sendEntityMessage(eid, "sbqReleased")
		end
		loungeable.setLoungeEnabled(seat, false)
	end
	-- sb.logInfo("Pressed:"..sb.printJson({seat,control,time}))
end
function controlReleased(seat, control, time)
	if SpeciesScript.active and Occupants.seat[seat] then
		Occupants.seat[seat]:controlReleased(control, time)
	else
		local eid = loungeable.entityLoungingIn(seat)
		if eid and world.entityExists(eid) then
			world.sendEntityMessage(eid, "sbqReleased")
		end
		loungeable.setLoungeEnabled(seat, false)
	end
	-- sb.logInfo("Released:"..sb.printJson({seat,control,time}))
end

function sbq.init(config)
	sbq.defaultAnimatorTags = animator.getTags()
	sbq.clearStatModifiers("sbqLockDown")
	sbq.clearStatModifiers("sbqHideSlots")
	sbq.clearStatModifiers("sbqStripping")
	sbq.settingsInit()
	sbq.lists = {}
	message.setHandler("sbqAddOccupant", function (_,_, ...)
		return Occupants.newOccupant(...)
	end)
	message.setHandler("sbqTryAction", function(_, _, ...)
		return sbq.tryAction(...)
	end)
	message.setHandler("sbqActionAvailable", function(_, _, ...)
		return sbq.actionAvailable(...)
	end)
	message.setHandler("sbqQueueAction", function(_, _, ...)
		return sbq.queueAction(...)
	end)
	message.setHandler("sbqSettingsPageData", function ()
		return sbq.getSettingsPageData()
	end)
	message.setHandler("sbqActionList", function (_,_, ...)
		return sbq.actionList(...)
	end)
	message.setHandler("sbqRequestAction", function (_,_, ...)
		return sbq.requestAction(...)
	end)
	message.setHandler("sbqRecieveOccupants", function (_,_, ...)
		return sbq.recieveOccupants(...)
	end)
	message.setHandler("sbqDumpOccupants", function (_,_, ...)
		return sbq.dumpOccupants(...)
	end)

	sbq.reloadVoreConfig(config)
end

function sbq.update(dt)
	if SpeciesScript.active then
		if (not SpeciesScript.lockActions) and SpeciesScript.actionQueue[1]  then
			SpeciesScript:tryAction(table.unpack(table.remove(SpeciesScript.actionQueue, 1)))
		end
		Occupants.update(dt)
		SpeciesScript:update(dt)
		SpeciesScript.state:update(dt)
		if sbq.timer("stripping", 5) then SpeciesScript:refreshStripping() end
		for k, v in pairs(sbq.voreConfig.transformGroupAnimProperties or {}) do
			local transformGroup = animator.applyTags(k)
			local part = animator.applyTags(v.part)
			if v.translate then
				sbq_animator.setTranslation(transformGroup, animator.partProperty(part, animator.applyTags(v.translate)))
			end
			if v.rotate then
				sbq_animator.setRotation(transformGroup, animator.partProperty(part, animator.applyTags(v.rotate)), animator.partProperty("rotationCenter"))
			end
			if v.scale then
				sbq_animator.setScale(transformGroup, animator.partProperty(part, animator.applyTags(v.scale)), animator.partProperty("scaleCenter"))
			end
		end
	end
	sbq.passiveStatChanges(dt)
end

function sbq.uninit()
	if SpeciesScript.active then
		SpeciesScript:uninit()
		SpeciesScript.state:uninit()
		SpeciesScript.active = false
	end
end

function sbq.passiveStatChanges(dt)
	if sbq.isResource("sbqLust") then
		local hornyPercent = sbq.resourcePercentage("sbqLust")
		if hornyPercent < sbq.stat("sbqLustScriptMax") then
			sbq.modifyResource("sbqLust", sbq.stat("sbqLustScriptDelta") * dt * sbq.resourcePercentage("food"))
		end
	end
	if sbq.isResource("sbqRest") then
		if sbq.loungingIn() then
			sbq.modifyResource("sbqRest", sbq.stat("sbqRestScriptDelta") * dt * (sbq.resourcePercentage("health")))
		else
			sbq.modifyResource("sbqRest", sbq.stat("sbqRestScriptDelta") * dt * (1 - math.min(sbq.resourcePercentage("health"), 0.8)))
		end
	end
end

function sbq.reloadVoreConfig(config)
	sbq.clearStatModifiers("occupantModifiers")
	Occupants.refreshOccupantModifiers = true
	-- if reloading while another transformation is already active, uninitialize it first
	if SpeciesScript.active then
		SpeciesScript.state:uninit()
		SpeciesScript:uninit()
		SpeciesScript.active = false
	end
	-- store the last input so it's used again on the next initiaization
	sbq.lastVoreConfig = config

	-- load config from species or config input, such as from a tech transformation
	sbq.voreConfig = root.fetchConfigArray(config, sbq.directory())
	-- reset setting tables on reload
	sbq.setupSettingMetatables(entity.entityType())

	-- load scripts
	for _, script in ipairs(sbq.voreConfig.scripts or {}) do
		require(script)
	end
	SpeciesScript = { baseLocations = {}, locations = {}, states = {}, actionQueue = {} }
	SpeciesScript.species = Species[sbq.voreConfig.species or "default"]
	setmetatable(SpeciesScript, {__index = SpeciesScript.species})

	if sbq.voreConfig.pred.appendLists then
		for k, list in pairs(sbq.voreConfig.pred) do
			if type(list) == "table" and list[1] then
				util.appendLists(list, sbq.config.pred[k])
			end
		end
	end
	if sbq.voreConfig.prey.appendLists then
		for k, list in pairs(sbq.voreConfig.prey) do
			if type(list) == "table" and list[1] then
				util.appendLists(list, sbq.config.prey[k])
			end
		end
	end
	-- initial setup of location data based on species and infusion
	for location, locationData in pairs(sbq.voreConfig.locations) do
		SpeciesScript:addLocation(location, locationData)
	end
	-- load states
	for name, stateConfig in pairs(sbq.voreConfig.states or {}) do
		SpeciesScript:addState(name, stateConfig)
	end
	-- put settings meant to be public and accessible by other entities in a status property
	sbq.refreshPublicSettings()
	sbq.refreshSettings()
	SpeciesScript:init()
	SpeciesScript:changeState((SpeciesScript.states[storage.lastState or "default"] and storage.lastState) or "default")
	SpeciesScript.active = true

	SpeciesScript:refreshInfusion()
	for _, occupant in ipairs(Occupants.list) do
		occupant:refreshLocation(occupant.location, occupant.subLocation, true)
	end
	for locationName, _ in pairs(SpeciesScript.locations) do
		local location = SpeciesScript:getLocation(locationName)
		if location then
			location:doSizeChangeAnims(location.occupancy.visualSize, location.occupancy.count)
			if location.subLocations then
				for k, _ in pairs(location.subLocations) do
					local location = SpeciesScript:getLocation(locationName, k)
					location:doSizeChangeAnims(location.occupancy.visualSize, location.occupancy.count)
				end
			end
		end
	end
	sbq.refreshPublicSettings()
	sbq.refreshSettings()
end

function sbq.actionList(type, target)
	local list = {}
	local actions = sb.jsonMerge({}, sbq.voreConfig.actionList)
	if type == "rp" then
		actions = sb.jsonMerge({}, sbq.voreConfig.rpActionList)
	elseif target then
		local occupant = Occupants.entityId[tostring(target)]
		if occupant then
			local location = occupant:getLocation()
			if occupant.flags.infused then
				actions = sb.jsonMerge({}, location.infusedActions)
			elseif occupant.flags.digested then
				actions = sb.jsonMerge({}, location.digestedActions)
			else
				actions = sb.jsonMerge({}, location.actions)
			end
		elseif sbq.loungingIn() == target then
			-- TODO some sort of list of actions for prey NPCs when they're inside? like asking them to struggle more, or stop struggling, idk, maybe just leave it as nothing
			return {}
		end
	end
	for _, action in ipairs(actions or {}) do
		local available, reason = SpeciesScript:actionAvailable(action.action, target, table.unpack(action.args or {}))
		if (not sbq.config.dontDisplayAction[tostring(reason)]) and not (action.noDisplay or {})[type] then
			table.insert(list, sb.jsonMerge(action, {available = available}))
		end
	end
	return list
end

function sbq.tryAction(action, target, ...)
	if not SpeciesScript.active then return {false, "inactive"} end
	return {SpeciesScript:tryAction(action, target, ...)}
end

function sbq.queueAction(action, target, ...)
	if not SpeciesScript.active then return false end
	return {SpeciesScript:queueAction(action, target, ...)}
end

function sbq.actionAvailable(action, target, ...)
	if not SpeciesScript.active then return {false, "inactive"} end
	return {SpeciesScript:actionAvailable(action, target, ...)}
end

function sbq.requestAction(forcing, action, target, ...)
	if not SpeciesScript.active then return {false, "inactive"} end
	return {SpeciesScript:requestAction(forcing, action, target, ...)}
end

function sbq.recieveOccupants(newOccupants)
	if not SpeciesScript.active then return false end
	return SpeciesScript:recieveOccupants(newOccupants)
end
function sbq.dumpOccupants(location, subLocation, digestType, ...)
	if not SpeciesScript.active then return false end
	return SpeciesScript:dumpOccupants(location, subLocation, digestType, ...)
end

function sbq.getSettingsPageData()
	local settingsPageData = {
		settingsPageName = sbq.entityName(entity.id()),
		storageSettings = storage.sbqSettings or {},
		storageUpgrades = storage.sbqUpgrades or {},
		settings = sbq.settings or {},
		voreConfig = sbq.voreConfig or {},
		locations = SpeciesScript.locations or {},
		baseLocations = SpeciesScript.baseLocations or {},
		currentScale = sbq.scale(),
		parentEntityData = { sbq.parentEntity() },
		infuseOverrideSettings = sbq.infuseOverrideSettings or {}
	}
	return settingsPageData
end

function sbq.groupedSettingChanged.locations(name,k,v)
	local location = SpeciesScript:getLocation(name)
	if location then
		location:markSettingsDirty()
	end
end

function sbq.groupedSettingChanged.infuseSlots(name, k, v)
	SpeciesScript:refreshInfusion(name)
end

function sbq.refreshInfusion()
	SpeciesScript:refreshInfusion()
end

-- transformation handling
function _SpeciesScript:getLocation(...)
	if not self.state then return false end
	return self.state:getLocation(...)
end

function _SpeciesScript:tryAction(action, target, ...)
	if not self.state then return false, "missingState" end
	return self.state:tryAction(action, target, ...)
end

function _SpeciesScript:queueAction(action, target, ...)
	if not self.state then return false, "missingState" end
	return self.state:queueAction(action, target, ...)
end

function _SpeciesScript:actionAvailable(action, target, ...)
	if not self.state then return false, "missingState" end
	return self.state:actionAvailable(action, target, ...)
end

function _SpeciesScript:requestAction(forcing, action, target, ...)
	if not self.state then return false, "missingState" end
	return self.state:requestAction(forcing, action, target, ...)
end

function _SpeciesScript:recieveOccupants(newOccupants)
	if not self.state then return false end
	return self.state:recieveOccupants(newOccupants)
end
function _SpeciesScript:dumpOccupants(location, subLocation, digestType, ...)
	if not self.state then return false end
	return self.state:dumpOccupants(location, subLocation, digestType, ...)
end

function _SpeciesScript:doAnimations(...)
	if not self.state then return 0 end
	return self.state:doAnimations(...)
end

function _SpeciesScript:checkAnimations(...)
	if not self.state then return 0 end
	return self.state:checkAnimations(...)
end

function _SpeciesScript:interact(...)
	if not self.state then return end
	return self.state:interact(...)
end

function _SpeciesScript:interactAction(...)
	if not self.state then return false, "invalidState" end
	return self.state:interactAction(...)
end

function _SpeciesScript:emergencyEscape(...)
	if not self.state then return end
	return self.state:emergencyEscape(...)
end

function _SpeciesScript:climax(...)
	if not self.state then return end
	return self.state:climax(...)
end

function _SpeciesScript:changeState(stateName)
	local state = self.states[stateName]
	if not state then sbq.logError("Attempt to switch to invalid state: " .. stateName) return false end
	if self.lockStateChanges then return false end
	if stateName == self.stateName then return false end
	storage.lastState = stateName
	local lastStateName
	if self.state then
		self.state:uninit(stateName)
		lastStateName = self.stateName
	end
	self.stateName = stateName
	self.state = state
	self.state:init(lastStateName)
	self.state:refreshActions()
	return true
end

function _SpeciesScript:settingAnimations()
end

-- State Handling
function _SpeciesScript:addState(stateName, config)
	local state = sb.jsonMerge(config, {})
	state.locations = state.locations or {}
	for k, location in pairs(self.locations) do
		state.locations[k] = state.locations[k] or {}
		for k2, subLocation in pairs(location.subLocations or {}) do
			local subLocationData = sb.jsonMerge(subLocation, state.locations[k].subLocations[k2] or {})
			subLocationData.struggleActions = subLocationData.struggleActions or {}
			for actionName, struggleAction in pairs(subLocationData.struggleActions) do
				if subLocationData.struggleActions.any and actionName ~= "any" then
					setmetatable(struggleAction, {__index = subLocationData.struggleActions.any})
				end
			end
			setmetatable(subLocationData, { __index = state.locations[k] })
			state.locations[k].subLocations[k2] = subLocationData
		end

		state.locations[k].struggleActions = state.locations[k].struggleActions or {}

		for actionName, struggleAction in pairs(state.locations[k].struggleActions) do
			if state.locations[k].struggleActions.any and actionName ~= "any" then
				setmetatable(struggleAction, {__index = state.locations[k].struggleActions.any})
			end
		end

		setmetatable(state.locations[k], { __index = location })
	end
	for actionName, action in pairs(state.actions or {}) do
		if action then
			setmetatable(action, _Action)
		end
	end
	setmetatable(state, {__index = self.species.states[stateName] or _State})
	self.states[stateName] = state
end

function _State:init(prevStateName)
end
function _State:uninit(newStateName)
end
function _State:update(dt)
end

function _State:refreshActions()
	local publicActionData = {}
	for k, action in pairs(self.actions) do
		if action then
			publicActionData[k] = {
				targetSettings = action.targetSettings,
				settings = action.settings
			}
		end
	end
	sbq.setProperty("sbqActionData", publicActionData)
end

function _State:recieveOccupants(newOccupants)
	for _, newOccupant in ipairs(newOccupants) do
		local eid = newOccupant.entityId
		if eid and Occupants.insertOccupant(newOccupant) then
			Occupants.queueHudRefresh = true
			local occupant = Occupants.entityId[tostring(eid)]
			if occupant and occupant.flags.infuseType and occupant.flags.infused then
				local infuseType = occupant.flags.infuseType
				sbq.addRPC(occupant:sendEntityMessage("sbqGetCard"), function(card)
					sbq.settings.infuseSlots[infuseType].item = card
					sbq.infuseOverrideSettings[infuseType] = {
						infuseSlots = { [infuseType] = { item = card}}
					}
					SpeciesScript:refreshInfusion(infuseType)
					occupant:refreshLocation()
					occupant:getLocation():markSizeDirty()
				end)
			end
		else
			sbq.logInfo(("Could not recieve Occupant: %s %s"):format(eid, sbq.entityName(eid)))
		end
	end
	return true
end
function _State:dumpOccupants(location, subLocation, digestType)
	local dump = {}
	for _, occupant in ipairs(Occupants.list) do
		local output = sb.jsonMerge(occupant, {})
		output.seat = nil
		output.location = location
		output.subLocation = subLocation
		output.struggleVec = { 0, 0 }
		output.struggleGracePeriod = 0
		output.time = 0
		output.struggleTime = 0
		output.struggleCount = 0
		output.locationStore = {}
		output.locationSettings = {}
		if output.flags.infused then
			output.flags.infused = false
			output.flags.infuseType = nil
			output.flags.digested = true
		end
		if output.flags.digested and digestType then
			output.flags.digestedLocation = location
			output.flags.digestType = digestType
		end
		table.insert(dump, output)
	end
	while Occupants.list[1] do
		Occupants.list[1]:remove()
	end
	return dump
end

function _State:getLocation(locationName, subLocation)
	local location = self.locations[locationName]
	if not location then return end
	if subLocation and location.subLocations then
		location = location.subLocations[subLocation] or location
	end
	if not location.scripted then return end
	return location
end

function _State:queueAction(name, target, ...)
	local res = { SpeciesScript:actionAvailable(name, target, ...) }
	if res[1] then table.insert(SpeciesScript.actionQueue, {name, target, ...}) end
	return table.unpack(res)
end

function _State:tryAction(name, target, ...)
	local action = self.actions[name]
	if not action then return self:actionFailed(name, action, target, "missingAction", ...) end
	if SpeciesScript.lockActions then return self:actionFailed(name, action, target, "actionsLocked", ...) end
	if action.onCooldown then return self:actionFailed(name, action, target, "onCooldown", ...) end
	if target and not world.entityStatPositive(target, "sbqStatusPrimaryScript") then return self:actionFailed(name, action, target, "targetMissingStatusPrimaryScript", ...) end
	if target and not world.entityStatPositive(target, "sbqActorScript") then return self:actionFailed(name, action, target, "targetMissingActorScript", ...) end
	if action.settings and not sbq.tableMatches(action.settings, sbq.settings, true) then return self:actionFailed(name, action, target, "settingsMismatch", ...) end
	if action.targetSettings then
		if not target or not world.entityExists(target) then return self:actionFailed(name, action, target, "targetMissing", ...) end
		local targetSettings = sbq.getPublicProperty(target, "sbqPublicSettings")
		if not sbq.tableMatches(action.targetSettings, targetSettings, true) then return self:actionFailed(name, action, target, "targetSettingsMismatch", ...) end
		if not action.ignoreTargetOccupants then
			local targetOccupants = world.entitiesLounging(target)
			for _, occupant in ipairs(targetOccupants or {}) do
				local occupantSettings = sbq.getPublicProperty(occupant, "sbqPublicSettings")
				if not sbq.tableMatches(action.targetSettings, occupantSettings, true) then return self:actionFailed(name, action, target, "targetPreySettingsMismatch", ...) end
			end
		end
	end
	local result1, result2 = true, false
	if action.script then
		if self[action.script] then
			result1, result2 = self[action.script](self, name, action, target, ...)
		else
			return self:actionFailed(name, action, target, "missingScript", ...)
		end
	end
	if not result1 then return self:actionFailed(name, action, target, result2, ...) end

	local longest = SpeciesScript:doAnimations(action.animations, action.tags, target)
	local cooldown = action.cooldown or longest
	action.onCooldown = true
	sbq.timer(name.."Cooldown", cooldown, function (...)
		action.onCooldown = false
		if type(result2) == "function" then
			result2(...)
		end
	end, name, action, target, result2, ..., longest)

	if target then
		world.sendEntityMessage(target, "sbqActionOccuring", entity.id(), name, longest)
	end

	if type(result2) ~= "function" then
		return result1, result2 or result1 or false, longest
	end
	return result1, result1 or false, longest
end

function _State:requestAction(forcing, name, target, ...)
	local success, reason, cooldown = SpeciesScript:actionAvailable(name, target, ...)
	local wait = 0
	if forcing then
		success, reason, cooldown = SpeciesScript:tryAction(name, target, ...)
		if success then
			if sbq.settings.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".forcedAction."..name, target) then
				dialogueProcessor.sendPlayerDialogueBox()
				dialogueProcessor.speakDialogue()
				wait = dialogueProcessor.predictTime()
			end
			sbq.forceTimer("dialogueAfter", cooldown + sbq.config.afterDialogueDelay, function ()
				if sbq.settings.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".forcedAction."..name..".after", target) then
					dialogueProcessor.sendPlayerDialogueBox()
					dialogueProcessor.speakDialogue()
				end
			end)
		end
		return success or false, reason or success or false, (cooldown or 0) + wait
	end
	if success then
		local args = { ... }
		local callback = function()
			local success, reason, cooldown = SpeciesScript:tryAction(name, target, table.unpack(args))
			if success then
				sbq.forceTimer("dialogueAfter", cooldown + wait + sbq.config.afterDialogueDelay, function ()
					if sbq.settings.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".actionRequested."..name..".true.after", target) then
						dialogueProcessor.sendPlayerDialogueBox()
						dialogueProcessor.speakDialogue()
					end
				end)
			end
		end
		if sbq.settings.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".actionRequested."..name..".true", target) then
			dialogueProcessor.sendPlayerDialogueBox()
			wait = dialogueProcessor.predictTime()
			dialogueProcessor.speakDialogue(callback)
		else
			world.sendEntityMessage(target, "scriptPaneMessage", "sbqCloseDialogueBox")
			callback()
		end
	else
		if sbq.settings.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".actionRequested."..name..".false."..tostring(reason), target) then
			dialogueProcessor.sendPlayerDialogueBox()
			dialogueProcessor.speakDialogue()
		else
			world.sendEntityMessage(target, "scriptPaneMessage", "sbqCloseDialogueBox")
		end
	end
	return success or false, reason or success or false, (cooldown or 0) + wait
end

function _State:actionFailed(name, action, target, reason, ...)
	-- sbq.logInfo({name, target, reason},2)
	if not action then return false, reason or false, 0, ... end
	local cooldown = action.failureCooldown or 0
	action.onCooldown = true
	local result1, result2  = false, false
	if action.failureScript and self[action.failureScript] then result1, result2 = self[action.failureScript](self, name, action, target, reason, ...) end
	sbq.timer(name.."Cooldown", cooldown, function (...)
		action.onCooldown = false
		if type(result2) == "function" then
			result2(...)
		end
	end, name, action, target, result2, ...)
	if type(result2) ~= "function" then
		return result1, reason or result1 or false, cooldown or 0, result2 or false, ...
	end
	return result1, reason or result1 or false, cooldown or 0, ...
end

function _State:actionAvailable(name, target, ...)
	if not name then return false end
	local action = self.actions[name]
	if not action then return false, "missingAction" end
	if action.settings and not sbq.tableMatches(action.settings, sbq.settings, true) then return false, "settingsMismatch" end
	if target and action.targetSettings then
		if not world.entityExists(target) then return false, "targetMissing" end
		local targetSettings = sbq.getPublicProperty(target, "sbqPublicSettings")
		if not sbq.tableMatches(action.targetSettings, targetSettings, true) then return false, "targetSettingsMismatch" end
		if not action.ignoreTargetOccupants then
			local targetOccupants = world.entitiesLounging(target)
			for _, occupant in ipairs(targetOccupants or {}) do
				local occupantSettings = sbq.getPublicProperty(occupant, "sbqPublicSettings")
				if not sbq.tableMatches(action.targetSettings, occupantSettings, true) then return false, "targetPreySettingsMismatch" end
			end
		end
	end
	local result1, result2 = true, false
	if action.availableScript then
		if self[action.availableScript] then
			result1, result2 = self[action.availableScript](self, name, action, target, ...)
		else
			return false, "missingScript", 0
		end
	end
	local longest = SpeciesScript:checkAnimations(false, action.animations, action.tags, target)
	return result1 or false, result2 or result1 or false, longest or 0
end

function _State:animationTags(tags, target)
	local targetTags = {}
	if target then
		local occupant = Occupants.entityId[tostring(target)]
		if occupant then
			local location = occupant:getLocation()
			targetTags.occupant = occupant.seat
			targetTags.location = occupant.location
			targetTags.subLocation = occupant.subLocation
			targetTags.locationTag = location.tag
			targetTags.locationSize = tostring(location.visualSize)
		end
	end
	return sb.jsonMerge(tags or {}, targetTags)
end

function _State:doAnimations(animations, tags, target)
	tags = self:animationTags(tags, target)
	local longest = 0
	for k, v in pairs(animations or {}) do
		local state = animator.applyTags(sb.replaceTags(k, tags))
		local anim = v
		local force = false
		local reversed = false
		local waitForEnd = false
		if type(v) == "table" then
			anim, force, reversed, waitForEnd = table.unpack(v)
		end
		anim = animator.applyTags(sb.replaceTags(anim, tags))
		if animator.hasState(state, anim) then
			if (not waitForEnd) or animator.animationEnded(state) then
				animator.setAnimationState(state, anim, force, reversed)
				local timer = animator.animationTimer(state)
				longest = math.max(longest, timer[2] - timer[1])
			else
				-- sbq.logError(string.format("Animation hasn't ended '%s' '%s'", state, anim))
			end
		else
			-- sbq.logError(string.format("No animation state '%s' '%s'", state, anim))
		end
	end
	return longest
end

function _State:checkAnimations(activeOnly, animations, tags, target)
	tags = self:animationTags(tags, target)
	local longest = 0
	for k, v in pairs(animations or {}) do
		local state = animator.applyTags(sb.replaceTags(k, tags))
		local anim = v
		if type(v) == "table" then
			anim, force, reversed, waitForEnd = table.unpack(v)
		end
		anim = animator.applyTags(sb.replaceTags(anim, tags))
		if (animator.hasState(state, anim) and not activeOnly)
		or (animator.hasState(state) and animator.animationState(state) == "anim")
		then
			local timer = animator.animationTimer(state, anim)
			longest = math.max(longest, timer[2] - timer[1])
		end
	end
	return longest
end

function _State:interact(args)
	if SpeciesScript.lockActions or sbq.timerRunning("dialogueAfter") then return end
	local start = ".greeting"
	local actions = true
	local occupant = Occupants.entityId[tostring(args.sourceId)]
	if sbq.loungingIn() == args.sourceId then
		start = ".loungingInteract"
		actions = false
	elseif occupant then
		start = ".occupantInteract"
	end
	if sbq.settings.interactDialogue and dialogueProcessor and dialogueProcessor.getDialogue(start, args.sourceId) then
		dialogueProcessor.speakDialogue()
		return dialogueProcessor.getPlayerDialogueBox(actions)
	elseif occupant then
		return {"Message", {messageType = "sbqRequestActions", messageArgs = {entity.id(), sbq.actionList("request", args.sourceId)}}}
	else
		if sbq.loungingIn() == args.sourceId then return end

		local parent, recruitUuid, following = sbq.parentEntity()
		if world.entityUniqueId(args.sourceId) == parent then
			return {"Message", {messageType = "sbqRequestRecruitActions", messageArgs = {entity.id(), sbq.actionList("request", args.sourceId), following, recruitUuid}}}
		end

		local results = { SpeciesScript:interactAction(args) }
		if results[2] == "interactAction" then
			return results[3]
		end
	end
end

function _State:interactAction(args)
	local interactActions = self.interactActions
	local occupant = Occupants.entityId[tostring(args.sourceId)]
	if occupant then
		location = occupant:getLocation()
		interactActions = location.interactActions
	end
	-- find closest interaction point, 4d voronoi style
	local pos = sbq.globalToLocal(args.sourcePosition)
	local aim = sbq.globalToLocal(args.interactPosition)
	local closest = nil
	local distance = math.huge
	for action, v in pairs(interactActions or {}) do
		if not v.action then
			v.action = action
		end
		local p
		local a
		if (v.posPart or v.part) and v.pos then
			p = sbq.localPartPoint(v.posPart or v.part, v.pos)
		end
		if (v.aimPart or v.part) and v.aim then
			a = sbq.localPartPoint(v.aimPart or v.part, v.aim)
		end
		-- check if we should even consider this action
		local valid = SpeciesScript:actionAvailable(v.action, args.sourceId, table.unpack(v.args or {}))
		-- check if there either point must be within a radius
		if valid and p and (v.posRadius or v.radius) then
			valid = ((v.posRadius or v.radius) > vec2.mag(vec2.sub(p, pos)))
		end
		if valid and a and (v.aimRadius or v.radius) then
			valid = ((v.aimRadius or v.radius) > vec2.mag(vec2.sub(a, aim)))
		end
		if valid then
			if not p and not a then
				-- no pos or aim, just make this one happen
				p = pos
				a = aim
			elseif a and not p then
				-- pos isn't specified, default to same as aim but less weight
				p = {
					(a[1] + pos[1])/2,
					(a[2] + pos[2])/2
				}
			elseif p and not a then
				-- aim isn't specified, default to same as pos but less weight
				a = {
					(p[1] + aim[1])/2,
					(p[2] + aim[2])/2
				}
			end
			local d = math.sqrt(
				(pos[1] - p[1])^2 +
				(pos[2] - p[2])^2 +
				(aim[1] - a[1])^2 +
				(aim[2] - a[2])^2
			)
			if d < distance then
				distance = d
				closest = v
			end
		end
	end
	if closest then
		SpeciesScript:tryAction(closest.action, args.sourceId, table.unpack(closest.args or {}))
	end
end

function _State:emergencyEscape(occupant)
	world.spawnProjectile("sbqMemeExplosion", occupant:position())
	occupant:remove()
end

local function climaxBurst(emitter, burstChance)
	animator.setParticleEmitterBurstCount(emitter, burstChance * 10)
	animator.burstParticleEmitter(emitter)
	if math.random() < burstChance then
		sbq.timer(nil, math.random(), climaxBurst, emitter, burstChance * 0.75)
	end
end
function _State:climax(entityId)
	SpeciesScript:doAnimations(self.climaxAnimations, {}, entityId)

	local occupant = Occupants.entityId[tostring(entityId)]
	if occupant then
		local location = occupant:getLocation()
		if location then
			local leakiness = sbq.settings[location.emitterSetting] or 0
			if leakiness > 0 then for _, emitter in ipairs(location.climaxEmitters or {}) do
				climaxBurst(emitter, leakiness)
			end end
		end
	end

	if dialogueProcessor and sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".climax", entityId) then
		dialogueProcessor.speakDialogue(function ()
			sbq.resetResource("sbqLust")
		end)
	else
		sbq.resetResource("sbqLust")
	end
end

-- Location handling
function _SpeciesScript:addLocation(name, config)
	local infuseLocation = {}
	local location = sb.jsonMerge(sbq.config.defaultLocationData, sbq.config.locations[name] or {}, root.fetchConfigArray(config, sbq.directory()), sbq.voreConfig.locationOverrides or {})
	location.tag = name
	location.key = name
	location.name = location.name or (":"..name)
	-- easier to make it default to math.huge than have it check if it's defined or not
	location.maxFill = location.maxFill or math.huge
	-- setup occupancy values
	location.occupancy = {
		sizeDirty = true,
		settingsDirty = true,
		list = {},
		size = 0,
		count = 0,
		visualSize = (location.struggleSizes or {})[1] or 0,
		interpolating = false,
		struggleVec = {0,0},
		interpolateFrom = 0,
		interpolateTime = 0,
		subLocations = {}
	}
	-- sub locations are for things that are different spots techincally, but inherit values and use the settings
	-- of a single location, such as with the sidedness of breasts, or perhaps a multi chambered stomach
	for k, subLocation in pairs(location.subLocations or {}) do
		subLocation.occupancy = {
			sizeDirty = true,
			settingsDirty = true,
			list = {},
			size = 0,
			count = 0,
			visualSize = (location.struggleSizes or {})[1] or 0,
			interpolating = false,
			interpolateFrom = 0,
			interpolateTime = 0,
		}
		subLocation.tag = name .. "_".. k
		subLocation.subKey = k
		location.occupancy.subLocations[k] = subLocation.occupancy
		setmetatable(subLocation, { __index = infuseLocation })
	end

	Occupants.locations[name] = location.occupancy
	location.settings = {}
	setmetatable(location.settings, {__index = sbq.settings.locations[location.settingsTable or name]})
	setmetatable(location, { __index = self.species.locations[name] or _Location })
	self.baseLocations[name] = location
	setmetatable(infuseLocation, {__index = location})
	self.locations[name] = infuseLocation
end

sbq.infuseOverrideSettings = {}
function _SpeciesScript:refreshInfusion(slot)
	sbq.infuseOverrideSettings.cockMatchGender = sbq.settings.cockMatchGender and (sbq.gender() == "male") and sbq.voreConfig.cockMatchGenderOverrides or {}
	sbq.infuseOverrideSettings.ballsMatchGender = sbq.settings.ballsMatchGender and (sbq.gender() == "male") and sbq.voreConfig.ballsMatchGenderOverrides or {}
	sbq.infuseOverrideSettings.pussyMatchGender = sbq.settings.pussyMatchGender and (sbq.gender() == "female") and sbq.voreConfig.pussyMatchGenderOverrides or {}
	sbq.infuseOverrideSettings.breastsMatchGender = sbq.settings.breastsMatchGender and (sbq.gender() == "female") and sbq.voreConfig.breastsMatchGenderOverrides or {}

	for k, v in pairs(self.locations) do
		local location = self:getLocation(k)
		if location and location.infuseType and ((not slot) or (slot == location.infuseType)) then
			location:setInfusionData()
		end
	end
	sbq.setupSettingMetatables(entity.entityType())
	sbq.refreshSettings()
end


function _Location:setInfusionData()
	if self.infuseTagsSet then
		for k, _ in pairs(self.infuseTagsSet.globalTags) do
			animator.setGlobalTag(k, sbq.defaultAnimatorTags.globalTags[k] or "default")
		end
		for part, v in pairs(self.infuseTagsSet.partTags) do
			for k, _ in pairs(v) do
				animator.setPartTag(part, k, sbq.defaultAnimatorTags.partTags[part][k])
			end
		end
	end
	local infusedItem = sbq.settings.infuseSlots[self.infuseType].item
	local infuseSpeciesConfig = root.speciesConfig(sbq.query(infusedItem, {"parameters", "npcArgs", "npcSpecies"}) or "") or (sbq.query(infusedItem, {"parameters", "speciesConfig"}) or {})
	local infuseIdentity = sbq.query(infusedItem, {"parameters", "npcArgs", "npcParam", "identity"}) or {}
	if infusedItem.name and self.infusedItemType and infusedItem.name ~= self.infusedItemType then
		infusedItem.name = self.infusedItemType
	end
	local infuseData = root.fetchConfigArray(infuseSpeciesConfig.infuseData or {})
	infuseData = sb.jsonMerge(root.fetchConfigArray(infuseData.default or {}), root.fetchConfigArray(infuseData[sbq.species()] or {}))
	infuseData = sb.jsonMerge(infuseData, (((infuseData or {}).locations or {})[self.tag]) or {})

	for k, v in pairs(self.settingInfusion or {}) do
		local v2 = (infuseData.settingInfusion or {})[k] or {}
		local value = sbq.settings[k]
		if sbq.config.settingInfusionPreyMap[k] and sbq.settings[k .. "Override"] then
			local preyVal = sbq.query(infusedItem, {"parameters", "npcArgs", "npcParam", "scriptConfig", "sbqSettings", sbq.config.settingInfusionPreyMap[k]})
			value = ((preyVal ~= "auto") and preyVal) or value
		end
		infuseData = sb.jsonMerge(
			infuseData,
			(type(v2[value]) == "string") and v2[v2[value]] or v2[value] or {},
			(type(v[value]) == "string") and v[v[value]] or v[value] or {}
		)
	end

	sbq.infuseOverrideSettings[self.tag] = infuseData.overrideSettings

	local tagsSet = {
		globalTags = {},
		partTags = {}
	}
	for k, v in pairs(infuseData.globalTags or {}) do
		animator.setGlobalTag(k, v)
		tagsSet.globalTags[k] = v
	end
	for part, tags in pairs(infuseData.partTags or {}) do
		tagsSet.partTags[part] = tagsSet.partTags[part] or {}
		for k, v in pairs(tags) do
			animator.setPartTag(part,k,v)
			tagsSet.partTags[part][k] = v
		end
	end

	local defaultColorMap = root.assetJson("/humanoid/any/sbqVoreParts/palette.config")
	local speciesConfig = root.speciesConfig(humanoid.species())
	for tag, remaps in pairs(infuseData.colorRemapGlobalTags or {}) do
		local sourceColorMap = sbq.query(infuseData, {"colorRemapSources", tag})
		if sourceColorMap then sourceColorMap = root.speciesConfig(sourceColorMap).baseColorMap end
		local directives = sbq.remapColor(remaps, sourceColorMap or defaultColorMap, speciesConfig.baseColorMap or defaultColorMap)
		animator.setGlobalTag(tag, directives)
		tagsSet.globalTags[tag] = directives
	end
	for part, tags in pairs(infuseData.colorRemapPartTags or {}) do
		tagsSet.partTags[part] = tagsSet.partTags[part] or {}
		for tag, remaps in pairs(tags or {}) do
			local sourceColorMap = sbq.query(infuseData, {"colorRemapSources", part, tag}) or sbq.query(infuseData, {"colorRemapSources", tag})
			if sourceColorMap then sourceColorMap = root.speciesConfig(sourceColorMap).baseColorMap end
			local directives = sbq.remapColor(remaps, sourceColorMap or defaultColorMap, speciesConfig.baseColorMap or defaultColorMap)
			animator.setPartTag(part, tag, directives)
			tagsSet.partTags[part][tag] = directives
		end
	end
	for tag, remaps in pairs(infuseData.infuseColorRemapGlobalTags or {}) do
		local sourceColorMap = sbq.query(infuseData, {"colorRemapSources", tag})
		if sourceColorMap then sourceColorMap = root.speciesConfig(sourceColorMap).baseColorMap end
		local directives = sbq.remapColor(remaps, sourceColorMap or defaultColorMap, infuseSpeciesConfig.baseColorMap)
		animator.setGlobalTag(tag, directives)
		tagsSet.globalTags[tag] = directives
	end
	for part, tags in pairs(infuseData.infuseColorRemapPartTags or {}) do
		tagsSet.partTags[part] = tagsSet.partTags[part] or {}
		for tag, remaps in pairs(tags or {}) do
			local sourceColorMap = sbq.query(infuseData, {"colorRemapSources", part, tag}) or sbq.query(infuseData, {"colorRemapSources", tag})
			if sourceColorMap then sourceColorMap = root.speciesConfig(sourceColorMap).baseColorMap end
			local directives = sbq.remapColor(remaps, sourceColorMap or defaultColorMap, infuseSpeciesConfig.baseColorMap)
			animator.setPartTag(part, tag, directives)
			tagsSet.partTags[part][tag] = directives
		end
	end
	local directives = (infuseIdentity.bodyDirectives or "") .. (infuseIdentity.hairDirectives or "")
	animator.setGlobalTag(self.tag.."InfusedDirectives", directives)
	tagsSet.globalTags[self.tag.."InfusedDirectives"] = directives

	local locationData = sb.jsonMerge(infuseIdentity and {transformResult = {species = infuseIdentity.species}} or {}, infuseData.locationOverrides, {
		infuseTagsSet = tagsSet
	})
	for k, _ in pairs(SpeciesScript.locations[self.key]) do
		SpeciesScript.locations[self.key][k] = nil
	end
	util.mergeTable(SpeciesScript.locations[self.key], locationData)
	self:markSettingsDirty()
	self:markSizeDirty()
end
function _Location:hasSpace(size)
	if (not sbq.tableMatches(self.activeSettings, sbq.settings, true)) or self.disabled then return false end
	if self.maxCount and (self.occupancy.count >= self.maxCount) then return false end
	local shared = 0
	for _, name in ipairs(self.sharedWith or {}) do
		local location = SpeciesScript:getLocation(name)
		shared = shared + location.occupancy.size
	end
	if (not self.subLocations) or self.subKey then
		if self.settings.hammerspace then return math.huge, self.subKey end
		return self:getRemainingSpace(self.maxFill, self.occupancy.size + shared, (size or 0) * self.settings.multiplyFill), self.subKey
	elseif self.subLocations[1] then
		if self.subLocations[1].maxCount and (self.occupancy.count >= self.subLocations[1].maxCount) then return false end
		-- if an array, assuming locations are ordered, only check if theres space in the first
		return self:getRemainingSpace(self.subLocations[1].maxFill, self.occupancy.subLocations[1].size + shared, (size or 0) * self.settings.multiplyFill), 1
	else
		-- if an object assume any is valid and choose one with the most space available
		local best = { 0 }
		local least = {math.huge}
		for k, v in pairs(self.subLocations) do
			if not (v.maxCount and (v.occupancy.count >= v.maxCount)) then
				local space = self:getRemainingSpace(v.maxFill, v.occupancy.size, size)
				if space and space >= best[1] then
					best = {space, k}
				end
				if v.occupancy.size <= least[1] then
					least = {v.occupancy.size, k}
				end
			end
		end
		if best[2] then
			return best[1], best[2]
		elseif self.settings.hammerspace and least[2] then
			return math.huge, least[2]
		end
	end
	return false
end
function _Location:getRemainingSpace(maxFill, occupancy, size)
	local remainingSpace = maxFill - (occupancy + (size or 0))
	if remainingSpace < 0 then return false end
	return remainingSpace
end

function _Location:markSizeDirty(force)
	self.occupancy.sizeDirty = true
	self.occupancy.forceSizeRefresh = force
	if self.subKey then
		local parentLocation = SpeciesScript:getLocation(self.key)
		parentLocation.occupancy.sizeDirty = true
		parentLocation.occupancy.forceSizeRefresh = force
	else
		for k, v in pairs(self.subLocations or {}) do
			local subLocation = SpeciesScript:getLocation(self.key, k)
			subLocation.occupancy.sizeDirty = true
			subLocation.occupancy.forceSizeRefresh = force
		end
	end
	for _, sharedName in ipairs(self.sharedWith or {}) do
		local shared = SpeciesScript:getLocation(sharedName)
		shared.occupancy.sizeDirty = true
		shared.occupancy.forceSizeRefresh = force
	end
end
function _Location:markSettingsDirty()
	self:markSizeDirty()
	local parentLocation = SpeciesScript:getLocation(self.key)
	parentLocation.occupancy.settingsDirty = true
	for k, v in pairs(self.subLocations or {}) do
		local subLocation = SpeciesScript:getLocation(self.key, k)
		subLocation.occupancy.settingsDirty = true
	end
end

function _Location:updateOccupancy(dt)
	if not self.subKey then
		for k, v in pairs(self.subLocations or {}) do
			local subLocation = SpeciesScript:getLocation(self.key, k)
			subLocation:updateOccupancy(dt)
		end
	end
	local prevVisualSize = self.occupancy.visualSize
	local prevCount = self.occupancy.count
	if (self.occupancy.sizeDirty or (Occupants.lastScale ~= sbq.scale())) and not self.occupancy.lockSize then
		self.occupancy.symmetry = (self.symmetrySettings and sbq.tableMatches(self.symmetrySettings, sbq.settings, true))
		self.occupancy.sizeDirty = false
		self.occupancy.size = (self.settings.visualMinAdd and self.settings.visualMin) or 0
		self.occupancy.count = 0
		if self.subLocationBehavior and not self.subKey then
			if self.subLocationBehavior == "average" then
				local total = 0
				local amount = 0
				for _, subLocation in pairs(self.subLocations) do
					total = subLocation.occupancy.size + total
					amount = amount + 1
				end
				self.occupancy.size = (total / math.max(1,amount))
			elseif self.subLocationBehavior == "largest" then
				local best = 0
				for _, subLocation in pairs(self.subLocations) do
					best = math.max(best, subLocation.occupancy.size)
				end
				self.occupancy.size = self.occupancy.size + best
			elseif self.subLocationBehavior == "smallest" then
				local best = self.maxFill
				for _, subLocation in pairs(self.subLocations) do
					best = math.min(best, subLocation.occupancy.size)
				end
				self.occupancy.size = self.occupancy.size + best
			end
		else
			for _, occupant in ipairs(self.occupancy.list) do
				if not (occupant.flags.digested or occupant.flags.infused) then
					self.occupancy.count = self.occupancy.count + 1
				end
				if not (occupant.flags.infused or occupant.flags.infusing) then
					self.occupancy.size = self.occupancy.size + math.max((self.digestedSize or 0), (occupant.size * occupant.sizeMultiplier * self.settings.multiplyFill / sbq.scale()))
				end
			end
		end
		local addVisual = 0
		for _, name in ipairs(self.addFill or {}) do
			local location = SpeciesScript:getLocation(name)
			location:updateOccupancy(0, name)
			addVisual = addVisual + location.occupancy.size
		end
		if self.infuseType then
			local infusedItem = sbq.settings.infuseSlots[self.infuseType].item
			addVisual = addVisual + ((((infusedItem or {}).parameters or {}).preySize or 0) * self.settings.infusedSize)
		end
		self.occupancy.visualSize = sbq.getClosestValue(
			math.min(
				self.settings.visualMax,
				math.max(
					self.settings.visualMin,
					(self.occupancy.size + addVisual)
				)
			),
			self.struggleSizes or { 0 }
		)

		if self.occupancy.forceSizeRefresh or ((prevVisualSize ~= self.occupancy.visualSize) or (self.countBasedOccupancy and (prevCount ~= self.occupancy.count)))
			and not (self.subKey and self.occupancy.symmetry)
		then
			self:doSizeChangeAnims(prevVisualSize, prevCount)
			if self.occupancy.symmetry then
				for k, v in pairs(self.subLocations or {}) do
					subLocation = SpeciesScript:getLocation(self.key, k)
					subLocation.occupancy.visualSize = self.occupancy.visualSize
					subLocation:doSizeChangeAnims(prevVisualSize, prevCount)
				end
			end
		end
		-- sbq.logInfo(("[%s]:%s"):format(self.tag, sb.printJson(self.occupancy, 2, true)))
	end
	if self.occupancy.interpolating then
		self.interpolateCurTime = self.interpolateCurTime + dt
		self.occupancy.interpolateSize = sbq.getClosestValue(
			interp.linear(
				self.interpolateCurTime / self.interpolateTime,
				self.occupancy.interpolateFrom,
				self.occupancy.visualSize
			),
			self.interpolateSizes or self.struggleSizes or {0}
		)
		if self.occupancy.interpolateSize == sbq.getClosestValue(self.occupancy.visualSize, self.interpolateSizes or self.struggleSizes or {0}) then self.occupancy.interpolating = false end
		animator.setGlobalTag(animator.applyTags(self.tag) .. "InterpolateSize", tostring(self.occupancy.interpolateSize))
	end
	local fade = string.format("%02x", math.floor(self.settings.infusedFade * 255))
	if (fade == "fe") then -- so theres no accidental glowy
		fade = "ff"
	end
	animator.setGlobalTag(self.tag.."InfusedFade", "?multiply=FFFFFF"..fade)
end

function _Location:update(dt)
	if sbq.randomTimer(self.tag.."_gurgle", 3, 15) then
		if (self.occupancy.count > 0) and self.settings.gurgleSounds then
			local occupant = self.occupancy.list[math.random(self.occupancy.count)]
			animator.setSoundPosition(self.gurgleSound or "gurgle", occupant:localPosition())
			if sbq.isResource(self.gurgleResource or "food") then
				local res = sbq.resourcePercentage(self.gurgleResource or "food")
				animator.setSoundVolume(self.gurgleSound or "gurgle", 0.5 + ((self.gurgleResourceInvert and (1 - res)) or res), 0.25)
			end
			animator.playSound(self.gurgleSound or "gurgle")
		end
	end
end

function _Location:doSizeChangeAnims(prevVisualSize, prevCount)
	self.occupancy.forceSizeRefresh = false
	animator.setGlobalTag(animator.applyTags(self.tag) .. "Count", tostring(self.occupancy.count))
	animator.setGlobalTag(animator.applyTags(self.tag) .. "Size", tostring(self.occupancy.visualSize))
	if self.idleAnims then
		SpeciesScript:doAnimations(self.idleAnims)
	end
	if self.occupantAnims then
		for _, occupant in ipairs(self.occupancy.list) do
			SpeciesScript:doAnimations(self.occupantAnims, {}, occupant.entityId)
		end
	end
	local sizeChangeAnims = self.occupancy.queuedSizeChangeAnims or self.sizeChangeAnims
	if sizeChangeAnims then
		self.occupancy.interpolateFrom = (self.occupancy.interpolating and self.occupancy.interpolateSize) or prevVisualSize
		self.occupancy.interpolating = true
		self.interpolateTime = SpeciesScript:doAnimations(sizeChangeAnims, {
			prevSize = tostring(prevVisualSize),
			newSize = tostring(self.occupancy.visualSize),
			prevCount = tostring(prevCount),
			newCount = tostring(self.occupancy.count)
		})
		self.interpolateCurTime = 0
	end
	self.occupancy.queuedSizeChangeAnims = nil
end

function _Location:refreshStruggleDirection(id)
	self.occupancy.struggleVec = {0,0}
	for _, occupant in ipairs(self.occupancy.list) do
		occupant:checkStruggleDirection(0)
		self.occupancy.struggleVec = vec2.add(self.occupancy.struggleVec, occupant.struggleVec)
	end
	for _, locationName in ipairs(self.sharedWith or {}) do
		local location = SpeciesScript:getLocation(locationName)
		for _, occupant in ipairs(location.occupancy.list) do
			occupant:checkStruggleDirection(0)
			self.occupancy.struggleVec = vec2.add(self.occupancy.struggleVec, occupant.struggleVec)
		end
	end
	local occupant = Occupants.entityId[tostring(id)]
	local newVec = self.occupancy.struggleVec
	local oldAction = self.occupancy.struggleAction
	local oldDirection = self.occupancy.struggleDirection
	local newDirection
	-- check if struggle direction anims should change
	if math.abs(newVec[1]) > math.abs(newVec[2]) then
		-- left/right struggle
		if newVec[1] < 0 then -- left struggle
			newDirection = "left"
		elseif newVec[1] > 0 then -- right struggle
			newDirection = "right"
		end
	else
		-- up down struggle
		if newVec[2] < 0 then -- left struggle
			newDirection = "down"
		elseif newVec[2] > 0 then -- right struggle
			newDirection = "up"
		end
	end
	local struggleAction, direction = self:getStruggleAction(newDirection)
	if direction ~= oldDirection then
		self.occupancy.struggleDirection = direction
		self.occupancy.struggleAction = struggleAction
		local newAnims = {}
		if struggleAction then
			newAnims = struggleAction.pressAnimations or struggleAction.holdAnimations or {}
		end
		if oldDirection and oldAction then
			if oldAction.releaseAnimations then
				local delay = SpeciesScript:doAnimations(oldAction.releaseAnimations or {}, { s_direction = oldDirection }, id)
				sbq.forceTimer(self.tag.."StruggleChange", delay, function ()
					SpeciesScript:doAnimations(newAnims, { s_direction = oldDirection }, id)
				end)
				return SpeciesScript:checkAnimations(false, newAnims, { s_direction = direction }, id) + delay, direction
			end
		end
		if newAnims and self.settings.struggleSounds and occupant and not (occupant.flags.digested or occupant.flags.infused) then
			animator.setSoundPosition(self.struggleSound or "struggle", occupant:localPosition())
			animator.setSoundVolume(self.struggleSound or "struggle", occupant:resourcePercentage("energy"), 0.25)
			animator.playSound(self.struggleSound or "struggle")
		end
		return SpeciesScript:doAnimations(newAnims, { s_direction = direction }, id), direction
	end
	return 0, direction
end
function _Location:getStruggleAction(direction)
	if not direction then return end
	direction = string.lower(direction)
	local newDirection = direction
	if direction == "right" then
		newDirection = animator.flipped() and "back" or "front"
	elseif direction == "left" then
		newDirection = animator.flipped() and "front" or "back"
	end
	if self.struggleActions[direction] then
		return self.struggleActions[direction], newDirection
	end
	return self.struggleActions[newDirection], newDirection
end

function _Location:outputData(entityId)
	local output = {struggleActions = {}}
	for _, k in ipairs(sbq.voreConfig.preyHudLocationOutput or sbq.config.preyHudLocationOutput) do
		output[k] = self[k]
	end
	for k, struggleAction in pairs(self.struggleActions or {}) do
		output.struggleActions[k] = {}
		if not SpeciesScript:actionAvailable(struggleAction.action, entityId, table.unpack(struggleAction.args or {})) then
			output.struggleActions[k].indicate = "default"
		else
			output.struggleActions[k].indicate = struggleAction.indicate
		end
	end
	return output
end

-- Occupant Handling
function Occupants.newOccupant(entityId, size, location, subLocation, flags)
	-- sanity check
	if not entityId then return false end

	-- check if we already have them
	local occupant = Occupants.entityId[tostring(entityId)]
	if occupant then
		occupant.flags = sb.jsonMerge(occupant.flags, flags or {}, { newOccupant = true })
		occupant:refreshLocation(location, subLocation, true)
		return true
	end
	local seat
	-- check for unoccupied occupant seat
	for i = 0, (sbq.voreConfig.seatCount or sbq.config.seatCount) - 1 do
		if not (Occupants.seat["occupant"..i] or loungeable.entityLoungingIn("occupant"..i)) then
			seat = "occupant"..i
			break
		end
	end
	-- -- if in the future we ever can have dynamic animation parts and seats
	-- local occupantAnim = sbq.replaceConfigTags(
	-- 	root.fetchConfigArray(sbq.voreConfig.occupantAnimationConfig or "/humanoid/any/voreOccupant.animation"),
	-- 	{occupant = seat}
	-- )

	-- if there is no available seat we cannot add the occupant
	if not seat then return false end
	-- setup occupant values
	local occupant = {
		entityId = entityId,
		seat = seat,
		flags = sb.jsonMerge(flags or {}, { newOccupant = true }),
		locationSettings = {},
		location = location,
		subLocation = subLocation,
		size = size or 1,
		sizeMultiplier = 1,
		struggleGracePeriod = 0,
		time = 0,
		struggleTime = 0,
		struggleCount = 0,
		struggleVec = {0,0},
		locationStore = {},
		persistentStatusEffects = jarray()
	}
	return Occupants.finishOccupantSetup(occupant)
end

function Occupants.insertOccupant(newOccupant)
	-- sanity check
	if not newOccupant.entityId then return false end
	-- check if we already have them
	local occupant = Occupants.entityId[tostring(newOccupant.entityId)]
	if occupant then
		world.sendEntityMessage(occupant.entityId, "sbqForceSit", { index = occupant:getLoungeIndex(), source = entity.id() })
		occupant:refreshLocation()
		-- assume data being recieved is out of date and just use current
		return false
	end

	local seat
	-- check for unoccupied occupant seat
	for i = 0, sbq.config.seatCount - 1 do
		if not (Occupants.seat["occupant"..i] or loungeable.entityLoungingIn("occupant"..i)) then
			seat = "occupant"..i
			break
		end
	end
	if not seat then return false end
	local location = SpeciesScript:getLocation(newOccupant.location, newOccupant.subLocation)
	if not location then return false end
	local space, subLocation = location:hasSpace(newOccupant.size * newOccupant.sizeMultiplier)
	if (not space) and not (newOccupant.flags.digested or newOccupant.flags.infused) then return false end
	-- if we recieve data for an occupant that is infused somewhere we already have someone infused, then treat them as digested instead
	if location.infusedEntity and Occupants.entityId[tostring(location.infusedEntity)]then
		newOccupant.flags.infused = false
		newOccupant.flags.infuseType = nil
		newOccupant.flags.digested = true
	end

	local occupant = sb.jsonMerge({
		flags = {},
		locationSettings = {},
		size = 1,
		sizeMultiplier = 1,
		struggleGracePeriod = 0,
		time = 0,
		struggleTime = 0,
		struggleCount = 0,
		struggleVec = {0,0},
		locationStore = {},
		persistentStatusEffects = jarray()
	}, newOccupant, {
		seat = seat,
		subLocation = subLocation,
	})
	return Occupants.finishOccupantSetup(occupant)
end

function Occupants.finishOccupantSetup(occupant)
	setmetatable(occupant, _Occupant)
	-- add occupant to tables for easily referencing it
	table.insert(Occupants.list, occupant)
	Occupants.seat[occupant.seat] = occupant
	local eid = occupant.entityId
	Occupants.entityId[tostring(eid)] = occupant
	local uuid = world.entityUniqueId(occupant.entityId)
	if uuid then
		Occupants.entityId[uuid] = occupant
	end
	-- refresh the location data for this occupant
	occupant:refreshLocation(occupant.location, occupant.subLocation, true)
	occupant:setLoungeEnabled(true)
	occupant:setDismountable(false)
	world.sendEntityMessage(occupant.entityId, "sbqForceSit", { index = occupant:getLoungeIndex(), source = entity.id() })

	sbq.forceTimer(occupant.seat .. "Timeout", 1, function()
		local occupant = Occupants.entityId[tostring(eid)]
		if occupant and occupant:entityLoungingIn() ~= occupant.entityId then occupant:remove() end
	end)
	return true
end

function _Occupant:remove()
	sbq.forceTimer("huntingActionAttemptCooldown", 10)
	self:setLoungeEnabled(false)
	local location = SpeciesScript:getLocation(self.location)

	Occupants.seat[self.seat] = nil

	if self.flags.infused then
		if location then location.infusedEntity = nil end
		sbq.settings.infuseSlots[self.flags.infuseType].item = nil
		sbq.infuseOverrideSettings[self.flags.infuseType] = nil
		SpeciesScript:refreshInfusion(self.flags.infuseType)
	end

	if self.subLocation then
		local subLocation = SpeciesScript:getLocation(self.location, self.subLocation)
		if subLocation then for i, occupant in ipairs(subLocation.occupancy.list) do
			if occupant.entityId == self.entityId then
				subLocation:markSizeDirty()
				table.remove(subLocation.occupancy.list, i)
				subLocation:refreshStruggleDirection()
				break
			end
		end end
	end
	if location then for i, occupant in ipairs(location.occupancy.list) do
		if occupant.entityId == self.entityId then
			location:markSizeDirty()
			table.remove(location.occupancy.list, i)
			location:refreshStruggleDirection()
			break
		end
	end end

	for i, occupant in ipairs(Occupants.list) do
		if occupant.entityId == self.entityId then
			table.remove(Occupants.list, i)
			break
		end
	end
	for k, occupant in pairs(Occupants.entityId) do
		if occupant.entityId == self.entityId then
			Occupants.entityId[k] = nil
		end
	end
	Occupants.refreshOccupantModifiers = true
	self:sendEntityMessage("sbqReleased")
	Occupants.queueHudRefresh = true
	if not Occupants.checkActiveOccupants() then SpeciesScript:queueAction("lockDownClear", self.entityId) end
end

function Occupants.update(dt)
	for name, _ in pairs(SpeciesScript.locations) do
		local location = SpeciesScript:getLocation(name)
		location:updateOccupancy(dt)
		location:update(dt)
	end
	for _, occupant in ipairs(Occupants.list) do
		occupant:update(dt)
	end
	for name, _ in pairs(SpeciesScript.locations) do
		local location = SpeciesScript:getLocation(name)
		for k, _ in pairs(location.subLocations or {}) do
			local subLocation = SpeciesScript:getLocation(name, k)
			subLocation.occupancy.settingsDirty = false
		end
		location.occupancy.settingsDirty = false
	end
	Occupants.lastScale = sbq.scale()

	if Occupants.queueHudRefresh then
		world.sendEntityMessage(entity.id(), "scriptPaneMessage", "sbqRefreshHudOccupants", Occupants.list, sbq.getSettingsPageData())
		Occupants.queueHudRefresh = false
	end
	if Occupants.refreshOccupantModifiers then
		Occupants.refreshOccupantModifiers = false
		local modifiers = {}
		for _, occupant in ipairs(Occupants.list) do
			util.appendLists(modifiers, occupant.predModifiers or {})
		end
		sbq.setStatModifiers("occupantModifiers", modifiers)
	end
end

function Occupants.checkActiveOccupants()
	for _, occupant in ipairs(Occupants.list) do
		if not (occupant.flags.digested or occupant.flags.infused) then return true end
	end
	return false
end
function Occupants.randomActiveOccupant()
	if not Occupants.list[1] then return end
	local i = math.random(#Occupants.list)
	for j = 1, #Occupants.list do
		local occupant = Occupants.list[i]
		if not (occupant.flags.digested or occupant.flags.infused) then return occupant.entityId end
		i = i + 1
		if i > #Occupants.list then i = 1 end
	end
end


function _Occupant:update(dt)
	local location = self:getLocation()
	if (not location) or (not world.entityExists(self.entityId)) or (sbq.loungingIn() == self.entityId) then return self:remove() end
	if location.occupancy.settingsDirty then self:refreshLocation() end
	if not animator.animationEnded(self.seat .. "State") then
		if self.flags.releasing and self:animProperty("release") then return self:remove() end
		self:setHidden(self:animProperty("hidden") or self.flags.digested or self.flags.infused)
		self:setLoungeOrientation(self:animProperty("orientation"))
		self:setLoungeDance(self:animProperty("dance"))
		self:setLoungeEmote(self:animProperty("emote"))
	end
	if not self.locationStore[self.location] then self.locationStore[self.location] = {time = 0, struggleTime = 0} end
	local locationStore = self.locationStore[self.location]

	locationStore.time = locationStore.time + dt
	self.time = self.time + dt

	if self.flags.infused then
	elseif self.flags.digested then
		local oldMultiplier = self.sizeMultiplier
		local compression = self.locationSettings.compression
		local compressionMin = location.digestedSize or 0
		if (compression == "health") then
			self.sizeMultiplier = math.max( compressionMin, self:resourcePercentage("health"))
		end
		if oldMultiplier ~= self.sizeMultiplier then
			location:markSizeDirty()
		end
	elseif not (self.flags.newOccupant or self.flags.releasing) then
		local oldMultiplier = self.sizeMultiplier
		local compression = self.locationSettings.compression
		local compressionMin = self.locationSettings.compressionMin
		if compression == "time" then
			self.sizeMultiplier = math.max( compressionMin, self.sizeMultiplier - (sbq.stat(location.powerMultiplier) * dt * sbq.config.compressionRate))
		elseif compression == "health" then
			self.sizeMultiplier = math.max( compressionMin, self:resourcePercentage("health"))
		end
		if oldMultiplier ~= self.sizeMultiplier then
			location:markSizeDirty()
		end
	end
	self:checkStruggleDirection(dt)
end

function _Occupant:refreshLocation(name, subLocation, force)
	local location = self:getLocation()

	if force or (name and (self.location ~= name)) or (subLocation and (self.subLocation ~= subLocation)) then
		if location then
			location:markSizeDirty()
			for i, occupant in ipairs(location.occupancy.list) do
				if occupant.entityId == self.entityId then
					table.remove(location.occupancy.list, i)
					break
				end
			end
		end
		self.location = name
		self.subLocation = subLocation
		location = self:getLocation()
		if not location then return self:remove() end
		self.locationName = location.name
		table.insert(location.occupancy.list, self)
		location:markSizeDirty()
	end
	if not location then return self:remove() end
	if (not (self.flags.infusing or self.flags.infused)) and ((not sbq.tableMatches(location.activeSettings, sbq.settings, true)) or location.disabled) then return self:remove() end
	setmetatable(self.locationSettings, {__index = location.settings})

	local occupantAnims = location.occupantAnims
	if occupantAnims then
		SpeciesScript:doAnimations(occupantAnims, {}, self.entityId)
	end
	if self.flags.releasing and self:animProperty("release") then return self:remove() end
	self:setHidden(self:animProperty("hidden") or self.flags.digested or self.flags.infused)
	self:setLoungeOrientation(self:animProperty("orientation"))
	self:setLoungeDance(self:animProperty("dance"))
	self:setLoungeEmote(self:animProperty("emote"))

	if not self.locationStore[self.location] then
		self.locationStore[self.location] = {
			time = 0,
			struggleTime = 0
		}
	end

	local persistentStatusEffects = {
		{ stat = "sbqDigestTick", amount = math.floor(sbq.stat(location.powerMultiplier or "powerMultiplier")) },
		{ stat = "sbqDigestingPower", amount = sbq.stat(location.powerMultiplier or "powerMultiplier") },
		{ stat = "sbqDisplayEffect", amount = sbq.settings.displayEffect and 1 or 0 },
	}
	util.appendLists(persistentStatusEffects, sbq.voreConfig.prey.statusEffects or sbq.config.prey.statusEffects)
	if self.flags.infused then
		util.appendLists(persistentStatusEffects, location.infusedPassiveEffects or {})
		for setting, effects in pairs(location.infusedEffects or {}) do
			if self:checkValidEffects(setting, effects) then
				util.appendLists(persistentStatusEffects, effects or {})
			end
		end
	elseif self.flags.digested then
		util.appendLists(persistentStatusEffects, location.digestedPassiveEffects or {})
		for setting, effects in pairs(location.digestedEffects or {}) do
			if self:checkValidEffects(setting, effects) then
				util.appendLists(persistentStatusEffects, effects or {})
			end
		end
	elseif not (self.flags.newOccupant or self.flags.releasing) then
		table.insert(persistentStatusEffects, {stat = "sbq_compression_"..self.locationSettings.compression, amount = 1})
		util.appendLists(persistentStatusEffects, location.passiveEffects or {})
		util.appendLists(persistentStatusEffects, (location.mainEffect or {})[self.overrideEffect or self.locationSettings.mainEffect or "none"] or {})
		for setting, effects in pairs(location.secondaryEffects or {}) do
			if self:checkValidEffects(setting, effects) then
				util.appendLists(persistentStatusEffects, effects or {})
			end
		end
	end
	local predModifiers = {}
	local preyModifiers = {}

	for _, effect in ipairs(persistentStatusEffects) do
		if type(effect) == "string" then
			local effectConfig = root.effectConfig(effect).effectConfig or {}
			if effectConfig.predModifiers then
				util.appendLists(predModifiers, effectConfig.predModifiers)
			end
			if effectConfig.preyModifiers then
				util.appendLists(preyModifiers, effectConfig.preyModifiers)
			end
			if effectConfig.predStatModifiers then
				util.appendLists(predModifiers, sbq.getModifiers(effectConfig.predStatModifiers, sbq.stat(location.powerMultiplier or "powerMultiplier")))
			end
			if effectConfig.preyStatModifiers then
				util.appendLists(preyModifiers, sbq.getModifiers(effectConfig.preyStatModifiers, sbq.stat(location.powerMultiplier or "powerMultiplier")))
			end
		end
	end
	util.appendLists(persistentStatusEffects, preyModifiers)
	util.appendLists(persistentStatusEffects, self.persistentStatusEffects)
	self:setLoungeStatusEffects(persistentStatusEffects)
	self.predModifiers = predModifiers
	Occupants.refreshOccupantModifiers = true

	self:setItemBlacklist(location.itemBlacklist or sbq.voreConfig.prey.itemBlacklist or sbq.config.prey.itemBlacklist)
	self:setItemWhitelist(location.itemWhitelist or sbq.voreConfig.prey.itemWhitelist or sbq.config.prey.itemWhitelist)
	self:setItemTagBlacklist(location.itemTagBlacklist or sbq.voreConfig.prey.itemTagBlacklist or sbq.config.prey.itemTagBlacklist)
	self:setItemTagWhitelist(location.itemTagWhitelist or sbq.voreConfig.prey.itemTagWhitelist or sbq.config.prey.itemTagWhitelist)
	self:setItemTypeBlacklist(location.itemTypeBlacklist or sbq.voreConfig.prey.itemTypeBlacklist or sbq.config.prey.itemTypeBlacklist)
	self:setItemTypeWhitelist(location.itemTypeWhitelist or sbq.voreConfig.prey.itemTypeWhitelist or sbq.config.prey.itemTypeWhitelist)
	self:setToolUsageSuppressed(location.toolUsageSuppressed or sbq.voreConfig.prey.toolUsageSuppressed or sbq.config.prey.toolUsageSuppressed)

	local parent, recruitUUID, following = sbq.parentEntity()
	local crewPred
	if parent then
		local eid = world.getUniqueEntityId(parent)
		if eid then
			crewPred = following and (world.entityType(eid) == "player")
		end
	end
	self:sendEntityMessage(
		"scriptPaneMessage",
		"sbqRefreshLocationData",
		entity.id(),
		location:outputData(self.entityId),
		{
			playerPred = entity.entityType() == "player",
			predUUID = entity.uniqueId(),
			crewPred = crewPred,
			parentUUID = parent,

			time = self.time,
			struggleTime = self.struggleTime,
			struggleCount = self.struggleCount,

			locationName = self.locationName,
			location = self.location,
			subLocation = self.subLocation,

			size = self.size,
			sizeMultiplier = self.sizeMultiplier,

			flags = self.flags,
			locationStore = self.locationStore,
			locationSettings = self.locationSettings
		}
	)
	if self.flags.newOccupant then
		Occupants.queueHudRefresh = true
	else
		world.sendEntityMessage(entity.id(), "scriptPaneMessage", "sbqHudRefreshPortrait", self.entityId, sb.jsonMerge(self.flags, {
			time = self.time,
			location = self.location,
			subLocation = self.subLocation,
			locationName = self.locationName
		}))
	end
end

function _Occupant:checkValidEffects(setting, effects)
	if not (effects and self.locationSettings[setting]) then return false end
	for _, effect in ipairs(effects) do
		if type(effect) == "string" then
			local effectConfig = root.effectConfig(effect).effectConfig or {}
			if effectConfig.finishAction then
				local success, reason = SpeciesScript:actionAvailable(effectConfig.finishAction, self.entityId)
				if not success then return false end
			end
		end
	end
	return true
end

function sbq.getModifiers(modifiers, power)
	local output = {}
	for k, v in pairs(modifiers) do
		local modifier = { stat = k }
		if v.op == "div" then
			modifier[v.type] = 1 / math.max(power * (v.base or 1), 1)
		elseif v.op == "sub" then
			modifier[v.type] = 1 - (power * (v.base or 1))
		elseif v.op == "mul" then
			modifier[v.type] = math.max(power * (v.base or 1), 1)
		elseif v.op == "add" then
			modifier[v.type] = (power * (v.base or 1))
		end
		table.insert(output, modifier)
	end
	return output
end

function _Occupant:attemptStruggle(control)
	local location = self:getLocation()
	local bonusTime = 0
	local maybeBonus, locationDirection = location:refreshStruggleDirection(self.entityId)
	local struggleAction, direction = location:getStruggleAction(control)
	if locationDirection == direction then
		bonusTime = bonusTime + maybeBonus
	end
	if sbq.randomTimer("occupantStruggleDialogue", sbq.voreConfig.occupantStruggleDialogueMin or sbq.config.occupantStruggleDialogueMin, sbq.voreConfig.occupantStruggleDialogueMax or sbq.config.occupantStruggleDialogueMax) and dialogueProcessor and dialogue.finished and sbq.settings.actionDialogue and not sbq.timerRunning("dialogueAfter") then
		if dialogueProcessor.getDialogue(".occupantStruggle", self.entityId) then
			dialogueProcessor.speakDialogue()
		end
	end
	if struggleAction then
		self.struggleAction = struggleAction
		self.struggleDirection = direction
		if struggleAction.action then
			self:sendEntityMessage("sbqStruggleAction", entity.id(), struggleAction.action)
		end

		if struggleAction.pressAnimations and not struggleAction.holdAnimations then
			bonusTime = bonusTime + SpeciesScript:doAnimations(struggleAction.pressAnimations, {s_direction = direction}, self.entityId)
		end
		if (bonusTime > 0) then
			if not self:controlHeld("Shift") then
				sbq.modifyResource("energy", -(struggleAction.predCost or (sbq.config.predStruggleCost * bonusTime)))
			end
			if not self:overConsumeResource("energy", (struggleAction.preyCost or (sbq.config.preyStruggleCost * bonusTime))) then return end

			for k, v in pairs(struggleAction.givePreyResource or {}) do
				self:giveResource(k,v)
			end
			for k, v in pairs(struggleAction.givePredResource or {}) do
				sbq.giveResource(k,v)
			end
			if sbq.isResource("sbqLust") and sbq.resourcePercentage("sbqLust") >= 1 then
				SpeciesScript:climax(self.entityId)
			end
		end
		self:tryStruggleAction((bonusTime > 0) and 1 or 0, bonusTime)
	end
end
function _Occupant:releaseStruggle(control, time)
	local location = self:getLocation()
	location:refreshStruggleDirection(self.entityId)
end

function _Occupant:getLocation()
	return SpeciesScript:getLocation(self.location, (not self.flags.infused) and self.subLocation)
end

function _Occupant:checkStruggleDirection(dt)
	local dx = 0
	local dy = 0
	local effectiveness = (self.flags.digested and 0) or (self.flags.infused and 1) or (self.sizeMultiplier * self.size / sbq.scale())
	local staleTime = 5
	if self:controlHeld("Up") then
		dy = dy + 1
		-- if self:controlHeldTime("Up") > staleTime then effectiveness = effectiveness * 0.5 end
	end
	if self:controlHeld("Down") then
		dy = dy - 1
		-- if self:controlHeldTime("Down") > staleTime then effectiveness = effectiveness * 0.5 end
	end
	if self:controlHeld("Left") then
		dx = dx - 1
		-- if self:controlHeldTime("Left") > staleTime then effectiveness = effectiveness * 0.5 end
	end
	if self:controlHeld("Right") then
		dx = dx + 1
		-- if self:controlHeldTime("Right") > staleTime then effectiveness = effectiveness * 0.5 end
	end
	self.struggleVec = {dx * effectiveness, dy * effectiveness}
	if (dx ~= 0 or dy ~= 0) then
		self.struggleTime = self.struggleTime + (dt * effectiveness)
		self.locationStore[self.location].struggleTime = self.locationStore[self.location].struggleTime + dt
		if not self:consumeResource("energy", ((self.struggleAction or {}).preyCost or sbq.config.preyStruggleCost) * dt, true) then return end
		self.struggleGracePeriod = sbq.config.struggleGracePeriod * effectiveness
		if sbq.timer(self.seat.."StruggleActionCooldown", 1) and dt ~= 0 then
			self:tryStruggleAction(0,0)
		end
	else
		if self.struggleGracePeriod <= 0 then
			if self.struggleTime <= 0 then
				self.struggleCount = 0
			else
				self.struggleTime = self.struggleTime - dt
			end
		else
			self.struggleGracePeriod = self.struggleGracePeriod - dt
		end
	end
end

function _Occupant:tryStruggleAction(inc, bonusTime)
	if (not self.struggleAction) or self.flags.newOccupant or self.flags.infused or self.flags.digested
		or self:controlHeld("Shift") or self:resourceLocked("energy")
		or (sbq.statPositive("sbqLockDown") and (sbq.resource("energy") > 0))
	then return false end
	if sbq.statPositive("sbqLockDown") then SpeciesScript:queueAction("lockDownClear", self.entityId) end
	locationStore = self.locationStore[self.location]
	if self.struggleAction.holdAnimations and not self.struggleAction.pressAnimations then
		SpeciesScript:doAnimations(self.struggleAction.holdAnimations or {}, {s_direction = self.struggleDirection})
	end
	self.struggleTime = (self.struggleTime or 0) + bonusTime
	self.struggleCount = (self.struggleCount or 0) + inc
	locationStore.struggleCount = (locationStore.struggleCount or 0) + inc
	if self.struggleAction.action then
		local timeSucceeded = self.struggleTime >= (sbq.settings.escapeDifficulty + math.random(table.unpack(self.struggleAction.time or { 0, 0 })))
		local countSucceeded = self.struggleCount >= (sbq.settings.escapeDifficulty + math.random(table.unpack(self.struggleAction.count or { 0, 0 })))
		if (self.struggleAction.both and (timeSucceeded and countSucceeded))
		or (not self.struggleAction.both and (timeSucceeded or countSucceeded))
		then
			if SpeciesScript:requestAction(true, self.struggleAction.action, self.entityId, table.unpack(self.struggleAction.args or {})) then
				self.struggleCount = math.ceil(math.sqrt(self.struggleCount))
				self.struggleTime = math.sqrt(self.struggleTime)
			end
		end
	end
end

function _Occupant:controlPressed(control, time)
	if control == "Jump" then
		if self:controlHeld("Shift") and self:controlHeld("Down") then
			SpeciesScript:emergencyEscape(self)
			return
		end
	elseif control == "Interact" then
		self:sendEntityMessage("sbqInteractWith", entity.id())
		return
	end
	self:attemptStruggle(control)
end
function _Occupant:controlReleased(control, time)
	self:releaseStruggle(control)
end

function _Occupant:consumeResource(resource, amount, ignoreBlock)
	-- if an entity doesn't have the resource, they get to have it for free
	if not world.entityIsResource(self.entityId, resource) then return true end
	if (world.entityResource(self.entityId, resource) >= amount) and ignoreBlock or not world.entityResourceLocked(self.entityId, resource) then
		world.sendEntityMessage(self.entityId, "sbqOverConsumeResource", resource, amount, ignoreBlock)
		return true
	end
	return false
end
function _Occupant:consumeResource(resource, amount, ignoreBlock)
	-- if an entity doesn't have the resource, they get to have it for free
	if not world.entityIsResource(self.entityId, resource) then return true end
	if (world.entityResource(self.entityId, resource) >= amount) and ignoreBlock or not world.entityResourceLocked(self.entityId, resource) then
		world.sendEntityMessage(self.entityId, "sbqOverConsumeResource", resource, amount, ignoreBlock)
		return true
	end
	return false
end
function _Occupant:overConsumeResource(resource, amount, ignoreBlock)
	-- if an entity doesn't have the resource, they get to have it for free
	if not world.entityIsResource(self.entityId, resource) then return true end
	if (world.entityResource(self.entityId, resource) > 0) and ignoreBlock or not world.entityResourceLocked(self.entityId, resource) then
		world.sendEntityMessage(self.entityId, "sbqOverConsumeResource", resource, amount, ignoreBlock)
		return true
	end
	return false
end

function _Occupant:resourceLocked(resource)
	-- if they don't have the resource, it can't be locked
	if not world.entityIsResource(self.entityId, resource) then return false end
	return world.entityResourceLocked(self.entityId, resource)
end

function _Occupant:resourcePercentage(resource)
	-- if they don't have the resource, treat it as empty
	if not world.entityIsResource(self.entityId, resource) then return 0 end
	return world.entityResourcePercentage(self.entityId, resource)
end

function _Occupant:modifyResourcePercentage(resource, amount)
	-- if they don't have the resource, treat it as empty
	if not world.entityIsResource(self.entityId, resource) then return 0 end
	return world.sendEntityMessage(self.entityId, "sbqModifyResourcePercentage", resource, amount)
end

function _Occupant:resource(resource)
	-- if they don't have the resource, treat it as empty
	if not world.entityIsResource(self.entityId, resource) then return 0 end
	return world.entityResource(self.entityId, resource)
end

function _Occupant:giveResource(resource, amount)
	-- if they don't have the resource, do nothing
	if not world.entityIsResource(self.entityId, resource) then return end
	return world.sendEntityMessage(self.entityId, "sbqGiveResource", resource, amount)
end

function _Occupant:stat(stat)
	return world.entityStat(self.entityId, stat)
end
function _Occupant:statPositive(stat)
	return world.entityStatPositive(self.entityId, stat)
end

function _Occupant:sendEntityMessage(...)
	if not world.entityExists(self.entityId) then return false end
	return world.sendEntityMessage(self.entityId, ...)
end

function _Occupant:animProperty(property)
	return animator.partProperty(self.seat, property)
end
function _Occupant:getPublicProperty(property)
	return world.entityStatusProperty(self.entityId, property)
end
function _Occupant:position()
	return sbq.globalPartPoint(self.seat, "loungeOffset")
end
function _Occupant:localPosition()
	return sbq.localPartPoint(self.seat, "loungeOffset")
end
function _Occupant:controlHeld(...)
	return loungeable.controlHeld(self.seat, ...)
end
function _Occupant:controlHeldTime(...)
	return loungeable.controlHeldTime(self.seat, ...)
end
function _Occupant:aimPosition(...)
	return loungeable.aimPosition(self.seat, ...)
end
function _Occupant:entityLoungingIn(...)
	return loungeable.entityLoungingIn(self.seat, ...)
end
function _Occupant:setLoungeEnabled(...)
	return loungeable.setLoungeEnabled(self.seat, ...)
end
function _Occupant:setLoungeOrientation(...)
	return loungeable.setLoungeOrientation(self.seat, ...)
end
function _Occupant:setLoungeEmote(...)
	return loungeable.setLoungeEmote(self.seat, ...)
end
function _Occupant:setLoungeDance(...)
	return loungeable.setLoungeDance(self.seat, ...)
end
function _Occupant:setLoungeDirectives(...)
	return loungeable.setLoungeDirectives(self.seat, ...)
end
function _Occupant:setLoungeStatusEffects(...)
	return loungeable.setLoungeStatusEffects(self.seat, ...)
end
function _Occupant:setToolUsageSuppressed(...)
	return loungeable.setToolUsageSuppressed(self.seat, ...)
end
function _Occupant:setDismountable(...)
	return loungeable.setDismountable(self.seat, ...)
end
function _Occupant:setHidden(...)
	return loungeable.setHidden(self.seat, ...)
end
function _Occupant:setItemBlacklist(...)
	return loungeable.setItemBlacklist(self.seat, ...)
end
function _Occupant:setItemWhitelist(...)
	return loungeable.setItemWhitelist(self.seat, ...)
end
function _Occupant:setItemTagBlacklist(...)
	return loungeable.setItemTagBlacklist(self.seat, ...)
end
function _Occupant:setItemTagWhitelist(...)
	return loungeable.setItemTagWhitelist(self.seat, ...)
end
function _Occupant:setItemTypeBlacklist(...)
	return loungeable.setItemTypeBlacklist(self.seat, ...)
end
function _Occupant:setItemTypeWhitelist(...)
	return loungeable.setItemTypeWhitelist(self.seat, ...)
end
function _Occupant:getLoungeIndex()
	return loungeable.getIndexFromName(self.seat)
end

function _Occupant:logInfo(json)
	sbq.logInfo("["..self.seat.."]["..world.entityName(self.entityId).."]"..tostring(json))
end
function _Occupant:logError(json)
	sbq.logError("["..self.seat.."]["..world.entityName(self.entityId).."]"..tostring(json))
end
