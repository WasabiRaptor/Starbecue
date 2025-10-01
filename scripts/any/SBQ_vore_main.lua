require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/scripts/poly.lua"
require "/scripts/interp.lua"
require "/scripts/any/SBQ_util.lua"
require "/scripts/any/SBQ_override_dummies.lua"
require "/scripts/any/SBQ_settings.lua"
require "/scripts/any/SBQ_anim_util.lua"

sbq._SpeciesScript = {scripted = true}
sbq._SpeciesScript.__index = sbq._SpeciesScript

sbq._State = {scripted = true}
sbq._State.__index = sbq._State

sbq._Action = {scripted = true}
sbq._Action.__index = sbq._Action

sbq._Location = {scripted = true}
sbq._Location.__index = sbq._Location

sbq._Occupant = {scripted = true}
sbq._Occupant.__index = sbq._Occupant

local _CapturedOccupant = {scripted = true}
_CapturedOccupant.__index = _CapturedOccupant
sbq._CapturedOccupant = _CapturedOccupant

sbq.SpeciesScripts = {}
sbq.SpeciesScript = {
	locations = {},
	states = {}
}
setmetatable(sbq.SpeciesScript, sbq._SpeciesScript)

sbq.Occupants = {
	list = jarray(),
	seat = {},
	entityId = {},
	locations = {},
	captured = jarray()
}

function sbq.init(sbqConfig)
	status.clearPersistentEffects("sbqLockDown")
	status.clearPersistentEffects("sbqHideSlots")
	status.clearPersistentEffects("sbqStripping")
	message.setHandler("sbqAddOccupant", function (_,_, ...)
		return sbq.Occupants.newOccupant(...)
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
	message.setHandler("sbqActionList", function (_,_, ...)
		return sbq.actionList(...)
	end)
	message.setHandler("sbqRequestAction", function (_,_, ...)
		return sbq.requestAction(...)
	end)
	message.setHandler("sbqReceiveOccupants", function (_,_, ...)
		return sbq.receiveOccupants(...)
	end)
	message.setHandler("sbqReceiveOccupant", function (_,_, ...)
		return sbq.receiveOccupant(...)
	end)
	message.setHandler("sbqCaptureOccupant", function (_,_, ...)
		return sbq.captureOccupant(...)
	end)
	message.setHandler("sbqReleaseCapturedOccupant", function (_,_, ...)
		return sbq.releaseCapturedOccupant(...)
	end)
	message.setHandler("sbqDumpOccupants", function (_,_, ...)
		return sbq.dumpOccupants(...)
	end)
	message.setHandler("sbqReleaseOccupant", function (_,_, ...)
		return sbq.releaseOccupant(...)
	end)

	sbq.reloadVoreConfig(sbqConfig)
end

function sbq.update(dt)
	if sbq.SpeciesScript.active then
		if (not sbq.SpeciesScript.lockActions) and sbq.SpeciesScript.actionQueue[1]  then
			sbq.SpeciesScript:tryAction(table.unpack(table.remove(sbq.SpeciesScript.actionQueue, 1)))
		end
		sbq.Occupants.update(dt)
		sbq.SpeciesScript:update(dt)
		sbq.SpeciesScript.state:update(dt)
		if sbq.timer("stripping", 5) then sbq.SpeciesScript:refreshStripping() end
		for k, v in pairs(sbq.voreConfig.transformGroupAnimProperties or {}) do
			local transformGroup = animator.applyPartTags("body",k)
			local part = animator.applyPartTags("body",v.part)
			if v.translate then
				sbq_animator.setTranslation(transformGroup, animator.partProperty(part, animator.applyPartTags("body",v.translate)))
			end
			if v.rotate then
				sbq_animator.setRotation(transformGroup, animator.partProperty(part, animator.applyPartTags("body",v.rotate)), animator.partProperty("rotationCenter"))
			end
			if v.scale then
				sbq_animator.setScale(transformGroup, animator.partProperty(part, animator.applyPartTags("body",v.scale)), animator.partProperty("scaleCenter"))
			end
		end
	end
	sbq.passiveStatChanges(dt)
end

function sbq.uninit(reason)
	if sbq.SpeciesScript.active then
		sbq.SpeciesScript.state:uninit(reason)
		sbq.SpeciesScript:uninit(reason)
		sbq.SpeciesScript.active = false
	end
	if reason == "died" then
		status.setStatusProperty("sbqOccupantStorage", nil)
		for i, occupant in ipairs(sbq.Occupants.list) do
			occupant:remove("died")
		end
	end
end

function sbq.passiveStatChanges(dt)
	if status.isResource("sbqLust") then
		local hornyPercent = status.resourcePercentage("sbqLust")
		if hornyPercent < status.stat("sbqLustScriptMax") then
			status.modifyResource("sbqLust", status.stat("sbqLustScriptDelta") * dt * status.resourcePercentage("food"))
		end
	end
	if status.isResource("sbqRest") then
		if sbq.loungingIn() then
			status.modifyResource("sbqRest", status.stat("sbqRestScriptDelta") * dt * (status.resourcePercentage("health")))
		else
			status.modifyResource("sbqRest", status.stat("sbqRestScriptDelta") * dt * (1 - math.min(status.resourcePercentage("health"), 0.8)))
		end
	end
end

function sbq.reloadVoreConfig(sbqConfig)
	status.clearPersistentEffects("occupantModifiers")
	sbq.Occupants.refreshOccupantModifiers = true
	-- if reloading while another transformation is already active, uninitialize it first
	if sbq.SpeciesScript.active then
		sbq.SpeciesScript.state:uninit("refresh")
		sbq.SpeciesScript:uninit("refresh")
		sbq.SpeciesScript.active = false
	end

	-- load config from species or config input, such as from a tech transformation
	sbq.voreConfig = {}
	for _, v in ipairs(sbqConfig.includes or {}) do
		sbq.voreConfig = sb.jsonMerge(sbq.voreConfig, root.assetJson(v))
	end
	sbq.voreConfig = sb.jsonMerge(sbq.voreConfig, sbqConfig)
	-- sbq.debugLogInfo(sbq.voreConfig, 2)
	-- load scripts
	for _, script in ipairs(sbq.voreConfig.scripts or {"/humanoid/any/sbqModules/base/voreScripts.lua"}) do
		require(script)
	end
	sbq.SpeciesScript = { locations = {}, states = {}, actionQueue = {} }
	sbq.SpeciesScript.species = sbq.SpeciesScripts[sbq.voreConfig.species or "default"]
	setmetatable(sbq.SpeciesScript, {__index = sbq.SpeciesScript.species})

	if sbq.voreConfig.pred and sbq.voreConfig.pred.appendLists then
		for k, list in pairs(sbq.voreConfig.pred) do
			if type(list) == "table" and list[1] then
				util.appendLists(list, sbq.config.pred[k])
			end
		end
	end
	if sbq.voreConfig.prey and sbq.voreConfig.prey.appendLists then
		for k, list in pairs(sbq.voreConfig.prey) do
			if type(list) == "table" and list[1] then
				util.appendLists(list, sbq.config.prey[k])
			end
		end
	end
	-- initial setup of location data based on species and infusion
	for location, locationData in pairs(sbq.voreConfig.locations or {}) do
		sbq.SpeciesScript:addLocation(location, locationData)
	end
	-- load states
	for name, stateConfig in pairs(sbq.voreConfig.states or {}) do
		sbq.SpeciesScript:addState(name, stateConfig)
	end
	-- put settings meant to be public and accessible by other entities in a status property
	sbq.refreshSettings()
	sbq.SpeciesScript:init()
	sbq.SpeciesScript:changeState((sbq.SpeciesScript.states[storage.lastState or "default"] and storage.lastState) or "default")
	sbq.SpeciesScript.active = true

	for _, occupant in ipairs(sbq.Occupants.list) do
		occupant:setLoungeEnabled(true)
		occupant:setLoungeDismountable(false)
		world.sendEntityMessage(occupant.entityId, "sbqForceSit", { index = occupant:getLoungeIndex(), source = entity.id() })
		occupant:refreshLocation(occupant.location, occupant.subLocation, true)
	end
	for locationName, _ in pairs(sbq.SpeciesScript.locations) do
		local location = sbq.SpeciesScript:getLocation(locationName)
		location:markSizeDirty(true)
	end
	sbq.refreshSettings()
end

function sbq.actionList(type, target)
	local list = {}
	local actions = sb.jsonMerge({}, sbq.voreConfig.actionList)
	if type == "rp" then
		actions = sb.jsonMerge({}, sbq.voreConfig.rpActionList)
	elseif target then
		local occupant = sbq.Occupants.entityId[tostring(target)]
		if occupant then
			local location = occupant:getLocation()
			if occupant.flags.infused then
				actions = sb.jsonMerge({}, location.infusedActions)
			elseif occupant.flags.digested then
				actions = sb.jsonMerge({}, location.digestedActions)
			elseif occupant.flags.digesting then
				actions = {}
			elseif occupant.flags.releasing then
				actions = {}
			else
				actions = sb.jsonMerge({}, location.actions)
			end
		elseif sbq.loungingIn() == target then
			-- TODO some sort of list of actions for prey NPCs when they're inside? like asking them to struggle more, or stop struggling, idk, maybe just leave it as nothing
			return {}
		end
	end
	for _, action in ipairs(actions or {}) do
		local success, failReason, time = sbq.SpeciesScript:actionAvailable(action.action, target, table.unpack(action.args or {}))
		if (not sbq.config.dontDisplayAction[tostring(failReason)]) and not (action.noDisplay or {})[type] then
			table.insert(list, sb.jsonMerge(action, { available = success }))
		end
	end
	return list
end

function sbq.tryAction(action, target, ...)
	if not sbq.SpeciesScript.active then return {false, "inactive"} end
	return {sbq.SpeciesScript:tryAction(action, target, ...)}
end

function sbq.queueAction(action, target, ...)
	if not sbq.SpeciesScript.active then return {false, "inactive"} end
	return {sbq.SpeciesScript:queueAction(action, target, ...)}
end

function sbq.actionAvailable(action, target, ...)
	if not sbq.SpeciesScript.active then return {false, "inactive"} end
	return {sbq.SpeciesScript:actionAvailable(action, target, ...)}
end

function sbq.requestAction(forcing, action, target, ...)
	if not sbq.SpeciesScript.active then return {false, "inactive"} end
	return {sbq.SpeciesScript:requestAction(forcing, action, target, ...)}
end

function sbq.receiveOccupants(newOccupants)
	if not sbq.SpeciesScript.active then return {false, "inactive"} end
	return {sbq.SpeciesScript:receiveOccupants(newOccupants)}
end
function sbq.receiveOccupant(newOccupant)
	if not sbq.SpeciesScript.active then return {false, "inactive"} end
	return {sbq.SpeciesScript:receiveOccupant(newOccupant)}
end
function sbq.captureOccupant(eid)
	if not sbq.SpeciesScript.active then return {false, "inactive"} end
	return {sbq.SpeciesScript:captureOccupant(eid)}
end
function sbq.releaseCapturedOccupant(uuid)
	if not sbq.SpeciesScript.active then return {false, "inactive"} end
	return {sbq.SpeciesScript:releaseCapturedOccupant(uuid)}
end
function sbq.dumpOccupants(location, subLocation, digestType, ...)
	if not sbq.SpeciesScript.active then return jarray() end
	return sbq.SpeciesScript:dumpOccupants(location, subLocation, digestType, ...)
end
function sbq.releaseOccupant(id, ...)
	if not sbq.SpeciesScript.active then return {false, "inactive"} end
	return {sbq.SpeciesScript:releaseOccupant(id, ...)}
end

-- transformation handling
function sbq._SpeciesScript:getLocation(...)
	if not self.state then return false end
	return self.state:getLocation(...)
end

function sbq._SpeciesScript:tryAction(action, target, ...)
	if not self.state then return false, "missingState" end
	return self.state:tryAction(action, target, ...)
end

function sbq._SpeciesScript:queueAction(action, target, ...)
	if not self.state then return false, "missingState" end
	return self.state:queueAction(action, target, ...)
end

function sbq._SpeciesScript:actionAvailable(action, target, ...)
	if not self.state then return false, "missingState" end
	return self.state:actionAvailable(action, target, ...)
end

function sbq._SpeciesScript:requestAction(forcing, action, target, ...)
	if not self.state then return false, "missingState" end
	return self.state:requestAction(forcing, action, target, ...)
end

function sbq._SpeciesScript:receiveOccupants(newOccupants)
	if not self.state then return false, "missingState" end
	return self.state:receiveOccupants(newOccupants)
end
function sbq._SpeciesScript:receiveOccupant(newOccupant)
	if not self.state then return false, "missingState" end
	return self.state:receiveOccupant(newOccupant)
end
function sbq._SpeciesScript:captureOccupant(eid)
	if not self.state then return false, "missingState" end
	return self.state:captureOccupant(eid)
end
function sbq._SpeciesScript:releaseCapturedOccupant(uuid)
	if not self.state then return false, "missingState" end
	return self.state:releaseCapturedOccupant(uuid)
end
function sbq._SpeciesScript:dumpOccupants(location, subLocation, digestType, ...)
	if not self.state then return jarray() end
	return self.state:dumpOccupants(location, subLocation, digestType, ...)
end
function sbq._SpeciesScript:releaseOccupant(id, ...)
	if not self.state then return false, "missingState" end
	return self.state:releaseOccupant(id, ...)
end

function sbq._SpeciesScript:doAnimations(...)
	if not self.state then return 0 end
	return self.state:doAnimations(...)
end

function sbq._SpeciesScript:checkAnimations(...)
	if not self.state then return 0 end
	return self.state:checkAnimations(...)
end

function sbq._SpeciesScript:interact(...)
	if not self.state then return end
	return self.state:interact(...)
end

function sbq._SpeciesScript:interactAction(...)
	if not self.state then return false, "invalidState" end
	return self.state:interactAction(...)
end

function sbq._SpeciesScript:emergencyEscape(...)
	if not self.state then return end
	return self.state:emergencyEscape(...)
end

function sbq._SpeciesScript:climax(...)
	if not self.state then return end
	return self.state:climax(...)
end

function sbq._SpeciesScript:changeState(stateName)
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

function sbq._SpeciesScript:settingAnimations()
end

-- State Handling
function sbq._SpeciesScript:addState(stateName, config)
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
			setmetatable(action, sbq._Action)
		end
	end
	setmetatable(state, {__index = self.species.states[stateName] or sbq._State})
	self.states[stateName] = state
end

function sbq._State:init(prevStateName)
end
function sbq._State:uninit(newStateName)
end
function sbq._State:update(dt)
end

function sbq._State:refreshActions()
	local publicActionData = {}
	for k, action in pairs(self.actions) do
		if action then
			publicActionData[k] = {
				targetSettings = action.targetSettings,
				settings = action.settings
			}
		end
	end
	status.setStatusProperty("sbqActionData", publicActionData)
end

function sbq._State:receiveOccupants(newOccupants)
	for _, newOccupant in ipairs(newOccupants) do
		self:receiveOccupant(newOccupant)
	end
	return true
end
function sbq._State:receiveOccupant(newOccupant)
	local success, reason = sbq.Occupants.insertOccupant(newOccupant)
	if success then
		sbq.Occupants.queueHudRefresh = true
	elseif reason ~= "alreadyThere" then
		sbq.logWarn(("Could not receive Occupant: %s %s %s"):format(newOccupant.entityId, sbq.entityName(newOccupant.entityId), reason))
	end
	return success, reason
end
function sbq._State:captureOccupant(id)
	local occupant = sbq.Occupants.entityId[tostring(id)]
	if not occupant then return false, "missingOccupant" end
	return occupant:capture()
end
function sbq._State:releaseCapturedOccupant(uuid)
	for i = #sbq.Occupants.captured, 1, -1 do
		local captured = sbq.Occupants.captured[i]
		if captured and ((captured.captureId == uuid) or (captured.npcArgs.npcParam.scriptConfig.uniqueId == uuid)) then
			return captured:release()
		end
	end
	return false, "missingOccupant"
end
function sbq._State:dumpOccupants(location, subLocation, digestType)
	local dump = jarray()
	for _, occupant in ipairs(sbq.Occupants.list) do
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
		if output.flags.digesting then
			output.flags.digesting = false
			output.flags.digested = true
		end
		if output.flags.infused then
			output.flags.infused = false
			output.flags.infuseType = nil
			output.flags.infuseSlots = nil
			output.flags.digested = true
		end
		if output.flags.digested and digestType then
			output.flags.digestedLocation = location
			output.flags.digestType = digestType
		end
		table.insert(dump, output)
	end
	while sbq.Occupants.list[1] do
		sbq.Occupants.list[1]:remove("occupantDump")
	end
	return dump
end
function sbq._State:releaseOccupant(id)
	local occupant = sbq.Occupants.entityId[tostring(id)]
	if occupant then
		occupant:remove("released")
	end
	return true
end
function sbq._State:getLocation(locationName, subLocation)
	local location = self.locations[locationName]
	if not location then return end
	if subLocation and location.subLocations then
		location = location.subLocations[subLocation] or location
	end
	if not location.scripted then return end
	return location
end

function sbq._State:queueAction(name, target, ...)
	local res = { sbq.SpeciesScript:actionAvailable(name, target, ...) }
	if res[1] then table.insert(sbq.SpeciesScript.actionQueue, {name, target, ...}) end
	return table.unpack(res)
end

function sbq._State:tryAction(name, target, ...)
	sbq.debugLogInfo(("Trying Action '%s' on target '%s' with arguments '%s'"):format(name, target, sb.printJson({...})))
	local action = self.actions[name]
	if not action then return self:actionFailed(name, action, target, "missingAction", ...) end
	if sbq.SpeciesScript.lockActions then return self:actionFailed(name, action, target, "actionsLocked", ...) end
	if action.onCooldown then return self:actionFailed(name, action, target, "onCooldown", ...) end
	if target and not world.entity(target):statPositive("sbqStatusPrimaryScript") then return self:actionFailed(name, action, target, "targetMissingStatusPrimaryScript", ...) end
	if target and not world.entity(target):statPositive("sbqActorScript") then return self:actionFailed(name, action, target, "targetMissingActorScript", ...) end
	if action.settings and not sbq.settings:matches(action.settings, true) then return self:actionFailed(name, action, target, "settingsMismatch", ...) end
	if action.targetSettings then
		if not target or not world.entityExists(target) then return self:actionFailed(name, action, target, "targetMissing", ...) end
		local targetSettings = sbq.getPublicProperty(target, "sbqPublicSettings")
		if not sbq.tableMatches(action.targetSettings, targetSettings, true) then return self:actionFailed(name, action, target, "targetSettingsMismatch", ...) end
		if not action.ignoreTargetOccupants then
			local targetOccupants = world.loungingEntities(target)
			for _, occupant in ipairs(targetOccupants or {}) do
				local occupantSettings = sbq.getPublicProperty(occupant, "sbqPublicSettings")
				if not sbq.tableMatches(action.targetSettings, occupantSettings, true) then return self:actionFailed(name, action, target, "targetPreySettingsMismatch", ...) end
			end
		end
	end
	local success, result2 = true, false
	if action.script then
		if self[action.script] then
			success, result2 = self[action.script](self, name, action, target, ...)
		else
			return self:actionFailed(name, action, target, "missingScript", ...)
		end
	end
	if not success then return self:actionFailed(name, action, target, result2, ...) end

	local longest = sbq.SpeciesScript:doAnimations(action.animations, action.tags, target)
	local cooldown = action.cooldown or longest
	action.onCooldown = true
	sbq.timer(name.."Cooldown", cooldown, function (...)
		action.onCooldown = false
		if type(result2) == "function" then
			result2(...)
		end
	end, name, action, target, result2, ..., longest)

	if target then
		for _, effectData in ipairs(action.applyStatusEffects or {}) do
			local effect, duration = table.unpack(effectData)
			local effectConfig = root.effectConfig(effect)
			world.sendEntityMessage(target, "applyStatusEffect", effect, (duration or effectConfig.defaultDuration or 1) + longest, entity.id())
		end

		world.sendEntityMessage(target, "sbqActionOccuring", entity.id(), name, longest)
	end

	if type(result2) ~= "function" then
		return success or false, result2 or success or false, cooldown or 0, false, false, ...
	end
	return success or false, success or false, cooldown or 0, false, false, ...
end

function sbq._State:requestAction(forcing, name, target, ...)
	local success, failReason, time, successfulFail, failReason2 = sbq.SpeciesScript:actionAvailable(name, target, ...)
	local wait = 0
	if forcing then
		success, failReason, time, successfulFail, failReason2 =  sbq.SpeciesScript:tryAction(name, target, ...)
		if success then
			if sbq.settings.read.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".forcedAction."..name, target) then
				dialogueProcessor.sendPlayerDialogueBox()
				dialogueProcessor.speakDialogue()
				wait = dialogueProcessor.predictTime()
			end
			sbq.forceTimer("dialogueAfter", time + wait + sbq.config.afterDialogueDelay, function ()
				if sbq.settings.read.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".forcedAction."..name..".after", target) then
					dialogueProcessor.sendPlayerDialogueBox()
					dialogueProcessor.speakDialogue()
				end
			end)
		end
		return success or false, failReason or success or false, (time or 0) + wait
	end
	if success then
		local args = { ... }
		local callback = function()
			success, failReason, time, successfulFail, failReason2 =  sbq.SpeciesScript:tryAction(name, target, table.unpack(args))
			if success then
				sbq.forceTimer("dialogueAfter", time + wait + sbq.config.afterDialogueDelay, function ()
					if sbq.settings.read.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".actionRequested."..name..".true.after", target) then
						dialogueProcessor.sendPlayerDialogueBox()
						dialogueProcessor.speakDialogue()
					end
				end)
			else
				-- to give the fail dialogue in the rare case they thought they could but can't actually
				if sbq.settings.read.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".actionRequested."..name..".false."..tostring(failReason), target) then
					dialogueProcessor.sendPlayerDialogueBox()
					dialogueProcessor.speakDialogue()
				else
					world.sendEntityMessage(target, "sbqScriptPaneMessage", "sbqCloseDialogueBox")
				end
			end
		end
		if sbq.settings.read.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".actionRequested."..name..".true", target) then
			dialogueProcessor.sendPlayerDialogueBox()
			wait = dialogueProcessor.predictTime()
			dialogueProcessor.speakDialogue(callback)
		else
			world.sendEntityMessage(target, "sbqScriptPaneMessage", "sbqCloseDialogueBox")
			callback()
		end
	else
		if sbq.settings.read.actionDialogue and dialogueProcessor and dialogueProcessor.getDialogue(".actionRequested."..name..".false."..tostring(failReason), target) then
			dialogueProcessor.sendPlayerDialogueBox()
			dialogueProcessor.speakDialogue()
		else
			world.sendEntityMessage(target, "sbqScriptPaneMessage", "sbqCloseDialogueBox")
		end
	end
	return success or false, failReason or success or false, (time or 0) + wait, successfulFail, failReason2
end

function sbq._State:actionFailed(name, action, target, failReason, ...)
	sbq.debugLogWarn(("Failed Action '%s' on target '%s' with arguments '%s' with reason '%s'"):format(name, target, sb.printJson({...}), failReason))
	-- sbq.logInfo({name, target, reason},2)
	if not action then return false, failReason or false, 0, ... end
	local cooldown = action.failureCooldown or 0
	action.onCooldown = true
	local successfulFail, result2  = false, false
	if action.failureScript and self[action.failureScript] then successfulFail, result2 = self[action.failureScript](self, name, action, target, failReason, ...) end
	sbq.timer(name.."Cooldown", cooldown, function (...)
		action.onCooldown = false
		if type(result2) == "function" then
			result2(...)
		end
	end, name, action, target, result2, ...)
	if type(result2) ~= "function" then
		return false, failReason or false, cooldown or 0, successfulFail or false, result2 or false, ...
	end
	return false, failReason or false, cooldown or 0, successfulFail or false, false, ...
end

function sbq._State:actionAvailable(name, target, ...)
	if not name then return false, "invalidAction" end
	local action = self.actions[name]
	if not action then return false, "missingAction" end
	if action.settings and not sbq.settings:matches(action.settings, true) then return false, "settingsMismatch", action.failureCooldown or 0, false, false end
	if target and action.targetSettings then
		if not world.entityExists(target) then return false, "targetMissing" end
		local targetSettings = sbq.getPublicProperty(target, "sbqPublicSettings")
		if not sbq.tableMatches(action.targetSettings, targetSettings, true) then return false, "targetSettingsMismatch", action.failureCooldown or 0, false, false end
		if not action.ignoreTargetOccupants then
			local targetOccupants = world.loungingEntities(target)
			for _, occupant in ipairs(targetOccupants or {}) do
				local occupantSettings = sbq.getPublicProperty(occupant, "sbqPublicSettings")
				if not sbq.tableMatches(action.targetSettings, occupantSettings, true) then return false, "targetPreySettingsMismatch", action.failureCooldown or 0, false, false end
			end
		end
	end
	local success, failReason = true, false
	if action.availableScript then
		if self[action.availableScript] then
			success, failReason = self[action.availableScript](self, name, action, target, ...)
		else
			return false, "missingScript", action.failureCooldown or 0, false, false
		end
	end
	local longest = (success and sbq.SpeciesScript:checkAnimations(false, action.animations, action.tags, target)) or
	action.failureCooldown or 0
	return success or false, failReason or success or false, longest or 0, false, false
end

function sbq._State:animationTags(tags, target)
	local targetTags = {}
	if target then
		local occupant = sbq.Occupants.entityId[tostring(target)]
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

function sbq._State:doAnimations(animations, tags, target)
	tags = self:animationTags(tags, target)
	local longest = 0
	for k, v in pairs(animations or {}) do
		local state = animator.applyPartTags("body", sb.replaceTags(k, tags))
		local anim = v
		local force = false
		local reversed = false
		local waitForEnd = false
		if type(v) == "table" then
			anim, force, reversed, waitForEnd = table.unpack(v)
		end
		anim = animator.applyPartTags("body",sb.replaceTags(anim, tags))
		if animator.hasState(state, anim) then
			if (not waitForEnd) or (animator.animationStateTimer(state) >= animator.stateCycle(state)) then
				animator.setAnimationState(state, anim, force, reversed)
				longest = math.max(longest, animator.stateCycle(state) - animator.animationStateTimer(state))
			else
				sbq.debugLogError(string.format("Animation hasn't ended '%s' '%s'", state, anim))
			end
		else
			sbq.debugLogError(string.format("No animation state '%s' '%s'", state, anim))
		end
	end
	return longest
end

function sbq._State:checkAnimations(activeOnly, animations, tags, target)
	tags = self:animationTags(tags, target)
	local longest = 0
	for k, v in pairs(animations or {}) do
		local state = animator.applyPartTags("body",sb.replaceTags(k, tags))
		local anim = v
		if type(v) == "table" then
			anim, force, reversed, waitForEnd = table.unpack(v)
		end
		anim = animator.applyPartTags("body", sb.replaceTags(anim, tags))
		if animator.hasState(state, anim) then
			if (animator.animationState(state) == "anim") then
				longest = math.max(longest,
					animator.stateCycle(state) - (force and 0 or animator.animationStateTimer(state)))
			elseif (not activeOnly) then
				longest = math.max(longest, animator.stateCycle(state, anim))
			end
		else
			sbq.debugLogError(string.format("No animation state '%s' '%s'", state, anim))
		end
	end
	return longest
end

function sbq._State:interact(args)
	if sbq.SpeciesScript.lockActions or sbq.timerRunning("dialogueAfter") then return end
	local start = ".greeting"
	local actions = true
	local occupant = sbq.Occupants.entityId[tostring(args.sourceId)]
	local sourceRadius
	if sbq.loungingIn() == args.sourceId then
		sourceRadius = -1
		start = ".loungingInteract"
		actions = false
	elseif occupant then
		start = ".occupantInteract"
		sourceRadius = -1
	end
	if sbq.settings.read.interactDialogue and dialogueProcessor and dialogueProcessor.getDialogue(start, args.sourceId) then
		dialogueProcessor.speakDialogue()
		return dialogueProcessor.getPlayerDialogueBox(actions, sourceRadius)
	elseif occupant then
		return {"Message", {messageType = "sbqRequestActions", messageArgs = {entity.id(), sbq.actionList("request", args.sourceId)}}}
	else
		if sbq.loungingIn() == args.sourceId then return end

		local actionList = sbq.actionList("request", args.sourceId)
		local parent, recruitUuid, following = sbq.parentEntity()
		if world.entityUniqueId(args.sourceId) == parent then
			return {"Message", {messageType = "sbqRequestRecruitActions", messageArgs = {entity.id(), actionList, following, recruitUuid}}}
		elseif not (sbq.SpeciesScript.state.useInteractActions) and (#actionList > 1) then
			return {"Message", {messageType = "sbqRequestActions", messageArgs = {entity.id(), actionList}}}
		end

		local results = { sbq.SpeciesScript:interactAction(args) }
		if results[2] == "interactAction" then
			return results[3]
		end
	end
end

function sbq._State:interactAction(args)
	local interactActions = self.interactActions
	local occupant = sbq.Occupants.entityId[tostring(args.sourceId)]
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
		local valid = sbq.SpeciesScript:actionAvailable(v.action, args.sourceId, table.unpack(v.args or {}))
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
		sbq.SpeciesScript:requestAction(false, closest.action, args.sourceId, table.unpack(closest.args or {}))
	end
end

function sbq._State:emergencyEscape(occupant)
	world.spawnProjectile("sbqMemeExplosion", occupant:position())
	occupant:remove("emergencyEscape")
end

local function climaxBurst(emitter, burstChance)
	animator.setParticleEmitterBurstCount(emitter, burstChance * 10)
	animator.burstParticleEmitter(emitter)
	if math.random() < burstChance then
		sbq.timer(nil, math.random(), climaxBurst, emitter, burstChance * 0.75)
	end
end
function sbq._State:climax(entityId)
	sbq.SpeciesScript:doAnimations(self.climaxAnimations, {}, entityId)

	local occupant = sbq.Occupants.entityId[tostring(entityId)]
	if occupant then
		local location = occupant:getLocation()
		if location then
			local leakiness = sbq.settings.read[location.emitterSetting] or 0
			if leakiness > 0 then for _, emitter in ipairs(location.climaxEmitters or {}) do
				climaxBurst(emitter, leakiness)
			end end
		end
	end

	if dialogueProcessor and sbq.settings.read.actionDialogue and dialogueProcessor.getDialogue(".climax", entityId) then
		dialogueProcessor.speakDialogue(function ()
			status.resetResource("sbqLust")
		end)
	else
		status.resetResource("sbqLust")
	end
end

-- Location handling
function sbq._SpeciesScript:addLocation(name, config)
	if not sbq.config.locations[name] then
		sbq.logError("Location '%s' must be defined in '/sbq.config:locations' as well.")
	end
	local location = sb.jsonMerge(sbq.config.defaultLocationData, sbq.config.locations[name], config, sbq.voreConfig.locationOverrides or {})
	location.tag = name
	location.key = name
	location.name = location.name or (":"..name)
	-- easier to make it default to math.huge than have it check if it's defined or not
	location.maxSize = location.maxSize or location.maxFill or math.huge -- account for values named when I wasn't being consistent
	location.addSize = location.addSize or location.addFill -- account for values named when I wasn't being consistent
	location.addCount = location.addCount or location.addFill -- account for values named when I wasn't being consistent
	-- setup occupancy values
	location.occupancy = sbq.Occupants.locations[name] or { -- inherit occupancy if its already active
		sizeDirty = true,
		settingsDirty = true,
		list = jarray(),
		captured = nil,
		size = 0,
		count = 0,
		addedSize = 0,
		addedCount = 0,
		visualSize = (location.struggleSizes or {})[1] or 0,
		interpolating = false,
		struggleVec = {0,0},
		interpolateFrom = 0,
		interpolateTime = 0,
		interpolateCurTime = 0,
		subLocations = {}
	}
	sbq.Occupants.locations[name] = location.occupancy
	if not location.occupancy.captured then
		location.occupancy.captured = jarray()
		for _, capturedOccupant in ipairs(sbq.Occupants.captured) do
			if capturedOccupant.location == name then
				table.insert(location.occupancy.captured, capturedOccupant)
			end
		end
	end
	-- sub locations are for things that are different spots techincally, but inherit values and use the settings
	-- of a single location, such as with the sidedness of breasts, or perhaps a multi chambered stomach
	for k, subLocation in pairs(location.subLocations or {}) do
		subLocation.tag = name .. "_".. k
		subLocation.subKey = k

		subLocation.occupancy = location.occupancy.subLocations[k] or { -- inherit occupancy if its already active
			sizeDirty = true,
			settingsDirty = true,
			list = jarray(),
			captured = nil,
			size = 0,
			count = 0,
			addedSize = 0,
			addedCount = 0,
			visualSize = (location.struggleSizes or {})[1] or 0,
			visualCount = (location.struggleSizes or {})[1] or 0,
			interpolating = false,
			interpolateFrom = 0,
			interpolateTime = 0,
			interpolateCurTime = 0,
		}
		location.occupancy.subLocations[k] = subLocation.occupancy
		if not subLocation.occupancy.captured then
			subLocation.occupancy.captured = jarray()
			for _, capturedOccupant in ipairs(sbq.Occupants.captured) do
				if (capturedOccupant.location == name) and (capturedOccupant.subLocation == k) then
					table.insert(subLocation.occupancy.captured, capturedOccupant)
				end
			end
		end

		setmetatable(subLocation, { __index = location })
	end

	location.settings = {}
	setmetatable(location.settings, {__index = sbq.settings.read.locations[location.settingsTable or name]})
	setmetatable(location, { __index = self.species.locations[name] or sbq._Location })
	self.locations[name] = location
end

function sbq._Location:hasSpace(size)
	if (not sbq.settings:matches(self.activeSettings, true)) or self.disabled then return false end
	if self.maxCount and (self.occupancy.count >= self.maxCount) then return false end
	if (not self.subLocations) or self.subKey then
		if self.settings.hammerspace then return math.huge, self.subKey end
		return self:getRemainingSpace(size), self.subKey
	elseif self.subLocations[1] then
		if self.subLocations[1].maxCount and (self.occupancy.count >= self.subLocations[1].maxCount) then return false end
		-- if an array, assuming locations are ordered, only check if theres space in the first
		return self.subLocations[1]:getRemainingSpace(size), 1
	else
		-- if an object assume any is valid and choose one with the most space available
		local best = { 0 }
		local least = {math.huge}
		for k, v in pairs(self.subLocations) do
			if not (v.maxCount and (v.occupancy.count >= v.maxCount)) then
				local space = v:getRemainingSpace(size)
				if space and space >= best[1] then
					best = {space, k}
				end
				if v.occupancy.size <= least[1] then
					least = {v.occupancy.size, k}
				end
			end
		end
		if self.settings.hammerspace and least[2] then
			return math.huge, least[2]
		elseif best[2] then
			return best[1], best[2]
		end
	end
	return false
end
function sbq._Location:getRemainingSpace(size)
	local remainingSpace = self.maxSize - (self.occupancy.size + self.occupancy.addedSize + ((size or 0) * self.settings.multiplyFill  / sbq.getScale()))
	if remainingSpace < 0 then return false end
	return remainingSpace
end

function sbq._Location:markSizeDirty(force)
	self.occupancy.sizeDirty = true
	self.occupancy.forceSizeRefresh = force
	if self.subKey then
		local parentLocation = sbq.SpeciesScript:getLocation(self.key)
		if parentLocation then
			parentLocation.occupancy.sizeDirty = true
			parentLocation.occupancy.forceSizeRefresh = force
		end
	else
		for k, v in pairs(self.subLocations or {}) do
			local subLocation = sbq.SpeciesScript:getLocation(self.key, k)
			if subLocation then
				subLocation.occupancy.sizeDirty = true
				subLocation.occupancy.forceSizeRefresh = force
			end
		end
	end
	for _, sharedName in ipairs(self.addSize or {}) do
		local location = sbq.SpeciesScript:getLocation(sharedName)
		if location then
			location.occupancy.sizeDirty = true
			location.occupancy.forceSizeRefresh = force
		end
	end
	for _, sharedName in ipairs(self.addCount or {}) do
		local location = sbq.SpeciesScript:getLocation(sharedName)
		if location then
			location.occupancy.sizeDirty = true
			location.occupancy.forceSizeRefresh = force
		end
	end
end
function sbq._Location:markSettingsDirty()
	self:markSizeDirty()
	local parentLocation = sbq.SpeciesScript:getLocation(self.key)
	if parentLocation then
		parentLocation.occupancy.settingsDirty = true
		for k, v in pairs(self.subLocations or {}) do
			local subLocation = sbq.SpeciesScript:getLocation(self.key, k)
			subLocation.occupancy.settingsDirty = true
		end
	end
end

function sbq._Location:updateOccupancy(dt)
	if self.occupancy.working then return end -- prevents stack overflow from potential dependency loops
	if not self.subKey then
		for k, v in pairs(self.subLocations or {}) do
			local subLocation = sbq.SpeciesScript:getLocation(self.key, k)
			if subLocation then
				subLocation:updateOccupancy(dt)
			end
		end
	end
	local prevVisualSize = self.occupancy.visualSize
	local prevVisualCount = self.occupancy.visualCount
	if (self.occupancy.sizeDirty or (sbq.Occupants.lastScale ~= sbq.getScale())) and not self.occupancy.lockSize then
		self.occupancy.working = true -- prevents stack overflow from potential dependency loops

		self.occupancy.symmetry = (self.symmetrySettings and sbq.settings:matches(self.symmetrySettings, true))
		self.occupancy.sizeDirty = false

		self.occupancy.size = (self.settings.visualMinAdd and self.settings.visualMin) or 0
		self.occupancy.count = 0

		self.occupancy.digestedCount = 0

		self.occupancy.addedSize = 0
		self.occupancy.addedCount = 0

		if self.subLocationBehavior and not self.subKey then
			if self.subLocationBehavior == "average" then
				local size = 0
				local count = 0
				local amount = 0
				for _, subLocation in pairs(self.subLocations) do
					size = subLocation.occupancy.size + size
					count = subLocation.occupancy.count + count
					amount = amount + 1
				end
				self.occupancy.size = (size / math.max(1, amount))
				self.occupancy.count = math.ceil(count / math.max(1, amount))
			elseif self.subLocationBehavior == "largest" then
				local bestSize = 0
				local bestCount = 0
				for _, subLocation in pairs(self.subLocations) do
					bestSize = math.max(bestSize, subLocation.occupancy.size)
					bestCount = math.max(bestCount, subLocation.occupancy.count)
				end
				self.occupancy.size = self.occupancy.size + bestSize
				self.occupancy.count = self.occupancy.count + bestCount
			elseif self.subLocationBehavior == "smallest" then
				local bestSize = self.maxSize
				local bestCount = self.maxSize
				for _, subLocation in pairs(self.subLocations) do
					bestSize = math.min(bestSize, subLocation.occupancy.size)
					bestCount = math.min(bestCount, subLocation.occupancy.count)
				end
				self.occupancy.size = self.occupancy.size + bestSize
				self.occupancy.count = self.occupancy.count + bestCount
			end
		else
			for _, occupant in ipairs(self.occupancy.list) do
				if not (occupant.flags.digested or occupant.flags.infused or occupant.flags.digesting or occupant.flags.infusing or occupant.flags.releasing) then
					self.occupancy.count = self.occupancy.count + 1
				elseif occupant.flags.digested then
					self.occupancy.digestedCount = self.occupancy.digestedCount + 1
				end
				if not (occupant.flags.infused or occupant.flags.infusing or occupant.flags.releasing) then
					self.occupancy.size = self.occupancy.size + math.max((self.digestedSize or 0), (occupant.size * occupant.sizeMultiplier * self.settings.multiplyFill / sbq.getScale()))
				end
			end
			for _, occupant in ipairs(self.occupancy.captured) do
				if not (occupant.flags.digested or occupant.flags.infused or occupant.flags.digesting or occupant.flags.infusing or occupant.flags.releasing) then
					self.occupancy.count = self.occupancy.count + 1
				elseif occupant.flags.digested then
					self.occupancy.digestedCount = self.occupancy.digestedCount + 1
				end
				if not (occupant.flags.infused or occupant.flags.infusing or occupant.flags.releasing) then
					self.occupancy.size = self.occupancy.size + math.max((self.digestedSize or 0), (occupant.size * occupant.sizeMultiplier * self.settings.multiplyFill / sbq.getScale()))
				end
			end
		end

		for _, name in ipairs(self.addSize or {}) do
			local location = sbq.SpeciesScript:getLocation(name)
			if location then
				location:updateOccupancy(0)
				self.occupancy.addedSize = self.occupancy.addedSize + location.occupancy.size
			else
				sbq.debugLogWarn(("'%s' Attempting to add size from '%s' which does not exist."):format(self.key, name))
			end
		end
		for _, name in ipairs(self.addCount or {}) do
			local location = sbq.SpeciesScript:getLocation(name)
			if location then
				location:updateOccupancy(0)
				self.occupancy.addedCount = self.occupancy.addedCount + location.occupancy.count
			else
				sbq.debugLogWarn(("'%s' Attempting to add count from '%s' which does not exist."):format(self.key, name))
			end
		end

		local infuseSize = 0
		local infuseCount = 0
		if  self.infuseType and self.infuseSize then
			for _, capturedOccupant in ipairs(self.occupancy.captured) do
				if capturedOccupant.infused then
					infuseSize = (capturedOccupant.size * self.settings.infusedSize)
					infuseCount = self.settings.infusedSize
				end
			end
			for _, occupant in ipairs(self.occupancy.list) do
				if occupant.infused then
					infuseSize = (occupant.size * self.settings.infusedSize)
					infuseCount = self.settings.infusedSize
				end
			end
		end
		self.occupancy.visualSize = sbq.getClosestValue(
			math.min(
				self.settings.visualMax,
				math.max(
					self.settings.visualMin,
					(self.occupancy.size + self.occupancy.addedSize + infuseSize)
				)
			),
			self.struggleSizes or { 0 }
		)

		local refreshSize = false
		if self.countBasedOccupancy then
			self.occupancy.visualCount = sbq.getClosestValue(
				math.min(
					self.settings.visualMax,
					math.max(
						self.settings.visualMin,
						(self.occupancy.count + self.occupancy.addedCount)
					)
				),
				self.struggleSizes or { 0 }
			)
			refreshSize = (prevVisualCount ~= self.occupancy.visualCount + infuseCount)
		else
			self.occupancy.visualCount = self.occupancy.count + self.occupancy.addedCount + infuseCount
			refreshSize = (prevVisualSize ~= self.occupancy.visualSize)
		end
		self.occupancy.visualCount = math.ceil(self.occupancy.visualCount)
		self.occupancy.count = math.ceil(self.occupancy.count)

		if self.occupancy.forceSizeRefresh or refreshSize and not (self.subKey and self.occupancy.symmetry) then
			self:doSizeChangeAnims(prevVisualSize, prevVisualCount)
			if self.occupancy.symmetry then
				for k, v in pairs(self.subLocations or {}) do
					subLocation = sbq.SpeciesScript:getLocation(self.key, k)
					if subLocation then
						subLocation.occupancy.visualSize = self.occupancy.visualSize
						subLocation.occupancy.visualCount = self.occupancy.visualCount
						subLocation:doSizeChangeAnims(prevVisualSize, prevVisualCount)
					end
				end
			end
		end
		self.occupancy.working = false -- no longer working, clear this so it can be updated again
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
		if self.occupancy.interpolateSize == sbq.getClosestValue(self.occupancy.visualSize, self.interpolateSizes or self.struggleSizes or { 0 }) then
			self.occupancy.interpolating = false
			self.occupancy.interpolateFrom = self.occupancy.visualSize
		end
		animator.setGlobalTag(animator.applyPartTags("body",self.tag) .. "InterpolateSize", tostring(self.occupancy.interpolateSize))
	end
	local fade = string.format("%02x", math.floor(self.settings.infusedFade * 255))
	if (fade == "fe") then -- so theres no accidental glowy
		fade = "ff"
	end
	animator.setGlobalTag(self.tag.."InfusedFade", "?multiply=FFFFFF"..fade)
end

function sbq._Location:update(dt)
	if sbq.randomTimer(self.tag .. "_gurgle", 3, 15) then
		if (self.occupancy.count > 0) and self.settings.gurgleSounds and self.occupancy.list[1] then
			local occupant = self.occupancy.list[#self.occupancy.list]
			animator.setSoundPosition(self.gurgleSound or "gurgle", occupant:localPosition())
			if status.isResource(self.gurgleResource or "food") then
				local res = status.resourcePercentage(self.gurgleResource or "food")
				animator.setSoundVolume(self.gurgleSound or "gurgle",
					0.5 + ((self.gurgleResourceInvert and (1 - res)) or res), 0.25)
			end
			animator.playSound(self.gurgleSound or "gurgle")
		end
	end
	if sbq.timer(self.tag.."_refreshStruggle", 1) then
		self:refreshStruggleDirection()
	end
end

-- safe iterate over occupants when they might be removing themselves from the location while iterating
function sbq._Location:safeIterateOccupants(func)
	local list = {}
	for _, v in ipairs(self.occupancy.list) do
		table.insert(list, v)
	end
	for _, v in ipairs(list) do
		if v and (v.location == self.key) then if func(v) then break end end
	end
end

function sbq._Location:randomActiveOccupant()
	local i = math.random(#self.occupancy.list)
	for j = 1, #self.occupancy.list do
		local occupant = self.occupancy.list[i]
		if occupant and occupant:active() then return occupant.entityId end
		i = i + 1
		if i > #self.occupancy.list then i = 1 end
	end
end
function sbq._Location:randomOccupant()
	local i = math.random(#self.occupancy.list)
	for j = 1, #self.occupancy.list do
		local occupant = self.occupancy.list[i]
		if occupant and occupant:valid() then return occupant.entityId end
		i = i + 1
		if i > #self.occupancy.list then i = 1 end
	end
end
function sbq._Location:lockSize(locked)
	self.occupancy.lockSize = locked or self.occupancy.lockSize
end
function sbq._Location:unlockSize()
	self.occupancy.lockSize = false
end
function sbq._Location:queueSizeChangeAnims(anims)
	if not anims then return end
	if self.occupancy.queuedSizeChangeAnims then
		self.occupancy.queuedSizeChangeAnims = sb.jsonMerge(self.occupancy.queuedSizeChangeAnims, anims)
	else
		self.occupancy.queuedSizeChangeAnims = anims
	end
end
function sbq._Location:clearQueuedSizeChangeAnims()
	self.occupancy.queuedSizeChangeAnims = nil
end

function sbq._Location:doSizeChangeAnims(prevVisualSize, prevCount)
	self.occupancy.forceSizeRefresh = false
	animator.setGlobalTag(animator.applyPartTags("body",self.tag) .. "Count", tostring(self.occupancy.visualCount))
	animator.setGlobalTag(animator.applyPartTags("body",self.tag) .. "Size", tostring(self.occupancy.visualSize))
	animator.setGlobalTag(animator.applyPartTags("body",self.tag) .. "PrevCount", tostring(prevCount))
	animator.setGlobalTag(animator.applyPartTags("body",self.tag) .. "PrevSize", tostring(prevVisualSize))
	local sizeTags = {
		prevSize = tostring(prevVisualSize),
		newSize = tostring(self.occupancy.visualSize),
		prevCount = tostring(prevCount),
		newCount = tostring(self.occupancy.visualCount)
	}
	if self.occupantAnims then
		for _, occupant in ipairs(self.occupancy.list) do
			sbq.SpeciesScript:doAnimations(self.occupantAnims, sizeTags, occupant.entityId)
		end
	end
	local sizeChangeAnims = self.occupancy.queuedSizeChangeAnims or self.sizeChangeAnims
	if sizeChangeAnims then
		self.occupancy.interpolateFrom = (self.occupancy.interpolating and self.occupancy.interpolateSize) or prevVisualSize
		self.interpolateTime = sbq.SpeciesScript:doAnimations(sizeChangeAnims, sizeTags)
		self.interpolateCurTime = 0
		self.occupancy.interpolating = true
	end
	self.occupancy.queuedSizeChangeAnims = nil
end

function sbq._Location:refreshStruggleDirection(id)
	self.occupancy.struggleVec = {0,0}
	for _, occupant in ipairs(self.occupancy.list) do
		occupant:checkStruggleDirection(0)
		self.occupancy.struggleVec = vec2.add(self.occupancy.struggleVec, occupant.struggleVec)
	end
	for _, locationName in ipairs(self.sharedWith or {}) do
		local location = sbq.SpeciesScript:getLocation(locationName)
		if location then
			for _, occupant in ipairs(location.occupancy.list) do
				occupant:checkStruggleDirection(0)
				self.occupancy.struggleVec = vec2.add(self.occupancy.struggleVec, occupant.struggleVec)
			end
		end
	end
	local occupant = sbq.Occupants.entityId[tostring(id)]
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
				local delay = sbq.SpeciesScript:doAnimations(oldAction.releaseAnimations or {}, { s_direction = oldDirection }, id)
				sbq.forceTimer(self.tag.."StruggleChange", delay, function ()
					sbq.SpeciesScript:doAnimations(newAnims, { s_direction = oldDirection }, id)
				end)
				return sbq.SpeciesScript:checkAnimations(false, newAnims, { s_direction = direction }, id) + delay, direction
			end
		end
		if newAnims and self.settings.struggleSounds and occupant and not (occupant.flags.digested or occupant.flags.infused) then
			animator.setSoundPosition(self.struggleSound or "struggle", occupant:localPosition())
			animator.setSoundVolume(self.struggleSound or "struggle", occupant:resourcePercentage("energy"), 0.25)
			animator.playSound(self.struggleSound or "struggle")
		end
		return sbq.SpeciesScript:doAnimations(newAnims, { s_direction = direction }, id), direction
	end
	return 0, direction
end
function sbq._Location:getStruggleAction(direction)
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

function sbq._Location:outputData(entityId)
	local output = {struggleActions = {}}
	for _, k in ipairs(sbq.voreConfig.preyHudLocationOutput or sbq.config.preyHudLocationOutput) do
		output[k] = self[k]
	end
	for k, struggleAction in pairs(self.struggleActions or {}) do
		output.struggleActions[k] = {}
		if not sbq.SpeciesScript:actionAvailable(struggleAction.action, entityId, table.unpack(struggleAction.args or {})) then
			output.struggleActions[k].indicate = "default"
		else
			output.struggleActions[k].indicate = struggleAction.indicate
		end
	end
	return output
end

-- Occupant Handling
function sbq.Occupants.newOccupant(entityId, size, location, subLocation, flags)
	-- sanity check
	if not entityId then return false end

	-- check if we already have them
	local occupant = sbq.Occupants.entityId[tostring(entityId)]
	if occupant then
		occupant.flags = sb.jsonMerge(occupant.flags, flags or {}, { newOccupant = true })
		occupant:refreshLocation(location, subLocation, true)
		return true
	end
	if (#sbq.Occupants.list + #sbq.Occupants.captured) >= sbq.voreConfig.seatCount then return false end
	local seat
	-- check for unoccupied occupant seat
	for i = 1, sbq.voreConfig.seatCount do
		if not (sbq.Occupants.seat["occupant"..i] or loungeable.entityLoungingIn("occupant"..i)) then
			seat = "occupant"..i
			break
		end
	end

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
		persistentStatusEffects = jarray(),
		controls = {
			Left = { last = false, time = 0 },
			Right = { last = false, time = 0 },
			Up = { last = false, time = 0 },
			Down = { last = false, time = 0 },
			PrimaryFire = { last = false, time = 0 },
			AltFire = { last = false, time = 0 },
			Special1 = { last = false, time = 0 },
			Special2 = { last = false, time = 0 },
			Special3 = { last = false, time = 0 },
			Walk = { last = false, time = 0 }, -- shift
			-- Interact = { last = false, time = 0 }
		}
	}
	return sbq.Occupants.finishOccupantSetup(occupant)
end

function sbq.Occupants.insertOccupant(newOccupant)
	-- sanity check
	if not newOccupant.entityId then return false, "invalidEntityId" end
	-- check if we already have them
	local occupant = sbq.Occupants.entityId[tostring(newOccupant.entityId)]
	if occupant then
		occupant:setLoungeEnabled(true)
		occupant:setLoungeDismountable(false)
		world.sendEntityMessage(occupant.entityId, "sbqForceSit", { index = occupant:getLoungeIndex(), source = entity.id() })
		occupant:refreshLocation()
		-- assume data being received is out of date and just use current
		return false, "alreadyThere"
	end

	local seat
	-- check for unoccupied occupant seat
	for i = 1, sbq.voreConfig.seatCount do
		if not (sbq.Occupants.seat["occupant"..i] or loungeable.entityLoungingIn("occupant"..i)) then
			seat = "occupant"..i
			break
		end
	end
	if not seat then return false, "noSlots" end
	local location = sbq.SpeciesScript:getLocation(newOccupant.location, newOccupant.subLocation)
	if not location then return false, "invalidLocation" end
	if newOccupant.flags.digesting then
		newOccupant.flags.digesting = false
		newOccupant.flags.digested = true
	end
	local space, subLocation = location:hasSpace(newOccupant.size * newOccupant.sizeMultiplier)

	if (not space) and not (newOccupant.flags.digested or newOccupant.flags.infused) then return false end
	-- if we receive data for an occupant that is infused somewhere we already have someone infused, then treat them as digested instead
	if location.infusedEntity and sbq.Occupants.entityId[tostring(location.infusedEntity)] then
		newOccupant.flags.infused = false
		newOccupant.flags.infuseSlots = nil
		newOccupant.flags.infuseType = nil
		newOccupant.flags.digested = true
	end
	if newOccupant.flags.infused then
		sbq.settings:setParameterSettings()
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
		persistentStatusEffects = jarray(),
		controls = {
			Left = { last = false, time = 0 },
			Right = { last = false, time = 0 },
			Up = { last = false, time = 0 },
			Down = { last = false, time = 0 },
			PrimaryFire = { last = false, time = 0 },
			AltFire = { last = false, time = 0 },
			Special1 = { last = false, time = 0 },
			Special2 = { last = false, time = 0 },
			Special3 = { last = false, time = 0 },
			Walk = { last = false, time = 0 }, -- shift
			-- Interact = { last = false, time = 0 }
		}
	}, newOccupant, {
		seat = seat,
		subLocation = subLocation,
	})
	return sbq.Occupants.finishOccupantSetup(occupant)
end

function sbq.Occupants.finishOccupantSetup(occupant)
	setmetatable(occupant, sbq._Occupant)
	-- add occupant to tables for easily referencing it
	table.insert(sbq.Occupants.list, occupant)
	sbq.Occupants.seat[occupant.seat] = occupant
	local eid = occupant.entityId
	sbq.Occupants.entityId[tostring(eid)] = occupant
	local uuid = world.entityUniqueId(occupant.entityId)
	if uuid then
		sbq.Occupants.entityId[uuid] = occupant
	end
	-- refresh the location data for this occupant
	occupant:refreshLocation(occupant.location, occupant.subLocation, true)
	occupant:setLoungeEnabled(true)
	occupant:setLoungeDismountable(false)
	world.sendEntityMessage(occupant.entityId, "sbqForceSit", { index = occupant:getLoungeIndex(), source = entity.id() })

	sbq.forceTimer(occupant.seat .. "Timeout", 1, function()
		local occupant = sbq.Occupants.entityId[tostring(eid)]

		if occupant and (occupant:entityLoungingIn() ~= occupant.entityId) then occupant:remove("failedToLounge") end
	end)
	return true
end

function sbq.Occupants.saveCaptured()
	local saveCaptured = jarray()
	for _, capturedOccupant in ipairs(sbq.Occupants.captured) do
		table.insert(saveCaptured, capturedOccupant:save())
	end
end

function sbq._Occupant:remove(reason)
	sbq.forceTimer("huntingActionAttemptCooldown", 10)
	self:debugLogInfo("removed: "..tostring(reason))
	self:setLoungeEnabled(false)
	local location = sbq.SpeciesScript:getLocation(self.location)

	sbq.Occupants.seat[self.seat] = nil

	if self.flags.infused then
		if location then location.infusedEntity = nil end
	end

	if self.subLocation then
		local subLocation = sbq.SpeciesScript:getLocation(self.location, self.subLocation)
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

	for i, occupant in ipairs(sbq.Occupants.list) do
		if occupant.entityId == self.entityId then
			table.remove(sbq.Occupants.list, i)
			break
		end
	end
	for k, occupant in pairs(sbq.Occupants.entityId) do
		if occupant.entityId == self.entityId then
			sbq.Occupants.entityId[k] = nil
		end
	end
	if self.flags.infused then
		sbq.settings:setParameterSettings()
	end
	sbq.Occupants.refreshOccupantModifiers = true
	if reason ~= "occupantDump" then
		self:sendEntityMessage("sbqReleased")
	end
	sbq.Occupants.queueHudRefresh = true
	if not sbq.Occupants.checkActiveOccupants() then sbq.SpeciesScript:queueAction("lockDownClear", self.entityId) end
end

function sbq.Occupants.update(dt)
	for name, _ in pairs(sbq.SpeciesScript.locations) do
		local location = sbq.SpeciesScript:getLocation(name)
		if location then
			location:updateOccupancy(dt)
			location:update(dt)
		end
	end
	for _, occupant in ipairs(sbq.Occupants.list) do
		occupant:update(dt)
	end
	for name, _ in pairs(sbq.SpeciesScript.locations) do
		local location = sbq.SpeciesScript:getLocation(name)
		if location then
			for k, _ in pairs(location.subLocations or {}) do
				local subLocation = sbq.SpeciesScript:getLocation(name, k)
				if subLocation then
					subLocation.occupancy.settingsDirty = false
				end
			end
			location.occupancy.settingsDirty = false
		end
	end
	sbq.Occupants.lastScale = sbq.getScale()

	if sbq.Occupants.queueHudRefresh then
		world.sendEntityMessage(entity.id(), "sbqScriptPaneMessage", "sbqRefreshHudOccupants", sbq.Occupants.list, sbq.Occupants.captured, sbq.settingsPageData())
		sbq.Occupants.queueHudRefresh = false
	end
	if sbq.Occupants.refreshOccupantModifiers then
		sbq.Occupants.refreshOccupantModifiers = false
		local modifiers = {}
		for _, occupant in ipairs(sbq.Occupants.list) do
			util.appendLists(modifiers, occupant.predModifiers or {})
		end
		status.setPersistentEffects("occupantModifiers", modifiers)
	end
end

function sbq.Occupants.checkActiveOccupants()
	for _, occupant in ipairs(sbq.Occupants.list) do
		if occupant and occupant:active() then return true end
	end
	return false
end
function sbq.Occupants.checkValidOccupants()
	for _, occupant in ipairs(sbq.Occupants.list) do
		if occupant and occupant:valid() then return true end
	end
	return false
end
function sbq.Occupants.randomActiveOccupant()
	if not sbq.Occupants.list[1] then return end
	local i = math.random(#sbq.Occupants.list)
	for j = 1, #sbq.Occupants.list do
		local occupant = sbq.Occupants.list[i]
		if occupant and occupant:active() then return occupant.entityId end
		i = i + 1
		if i > #sbq.Occupants.list then i = 1 end
	end
end
function sbq.Occupants.randomOccupant()
	if not sbq.Occupants.list[1] then return end
	local i = math.random(#sbq.Occupants.list)
	for j = 1, #sbq.Occupants.list do
		local occupant = sbq.Occupants.list[i]
		if occupant and occupant:valid() then return occupant.entityId end
		i = i + 1
		if i > #sbq.Occupants.list then i = 1 end
	end
end


function sbq._Occupant:update(dt)
	local location = self:getLocation()
	if not location then return self:remove("invalidLocation") end
	if not world.entityExists(self.entityId) then return self:remove("entityDoesNotExist") end
	if sbq.loungingIn() == self.entityId then return self:remove("recursiveLounge") end
	-- if (loungeable.entityLoungingIn(self.seat) ~= self.entityId) and not self.flags.newOccupant then return self:remove("noLongerLounging") end

	if location.occupancy.settingsDirty then self:refreshLocation() end
	if not (animator.animationStateTimer(self.seat .. "State") >= animator.stateCycle(self.seat .. "State")) then
		if self.flags.releasing and self:animProperty("release") then return self:remove("releasing") end
		self:setLoungeHidden(self:animProperty("hidden") or self.flags.digested or self.flags.infused or self.flags.digesting)
		self:setLoungeOrientation(self:animProperty("orientation"))
		self:setLoungeDance(self:animProperty("dance"))
		self:setLoungeEmote(self:animProperty("emote"))
	else
		if self.flags.releasing then return self:remove("releasing") end
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
	elseif self:active() then
		local oldMultiplier = self.sizeMultiplier
		local compression = self.locationSettings.compression
		local compressionMin = self.locationSettings.compressionMin
		if compression == "time" then
			self.sizeMultiplier = math.max( compressionMin, self.sizeMultiplier - (status.stat(location.powerMultiplier) * dt * sbq.config.compressionRate))
		elseif compression == "health" then
			self.sizeMultiplier = math.max( compressionMin, self:resourcePercentage("health"))
		end
		if oldMultiplier ~= self.sizeMultiplier then
			location:markSizeDirty()
		end
	end
	for k, v in pairs(self.controls) do
		local held = self:controlHeld(k)
		if v.last == held then
			v.time = v.time + dt
		else
			if held then
				self:controlPressed(k, v.time)
			else
				self:controlReleased(k, v.time)
			end
			v.time = 0
			v.last = held
		end
	end
	self:checkStruggleDirection(dt)
end

function sbq._Occupant:refreshLocation(name, subLocation, force)
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
		if not location then return self:remove("invalidLocation") end
		self.locationName = location.name
		table.insert(location.occupancy.list, self)
		location:markSizeDirty()
		sbq.Occupants.queueHudRefresh = true
	end
	if not location then return self:remove("invalidLocation") end
	if (not (self.flags.infusing or self.flags.infused)) and ((not sbq.settings:matches(location.activeSettings, true)) or location.disabled) then return self:remove("disabledLocation") end
	setmetatable(self.locationSettings, {__index = location.settings})

	local occupantAnims = location.occupantAnims
	if occupantAnims then
		sbq.SpeciesScript:doAnimations(occupantAnims, {}, self.entityId)
	end
	if self.flags.releasing and self:animProperty("release") then return self:remove("releasing") end
	self:setLoungeHidden(self:animProperty("hidden") or self.flags.digested or self.flags.infused or self.flags.digesting)
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
		{ stat = "sbqDigestTick", amount = math.floor(status.stat(location.powerMultiplier or "powerMultiplier")) },
		{ stat = "sbqDigestingPower", amount = status.stat(location.powerMultiplier or "powerMultiplier") },
		{ stat = "sbqDisplayEffect", amount = sbq.settings.read.displayEffect and 1 or 0 },
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
	elseif self:valid() then
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
				util.appendLists(predModifiers, sbq.getModifiers(effectConfig.predStatModifiers, status.stat(location.powerMultiplier or "powerMultiplier")))
			end
			if effectConfig.preyStatModifiers then
				util.appendLists(preyModifiers, sbq.getModifiers(effectConfig.preyStatModifiers, status.stat(location.powerMultiplier or "powerMultiplier")))
			end
		end
	end
	util.appendLists(persistentStatusEffects, preyModifiers)
	util.appendLists(persistentStatusEffects, self.persistentStatusEffects)
	self:setLoungeStatusEffects(persistentStatusEffects)
	self.predModifiers = predModifiers
	sbq.Occupants.refreshOccupantModifiers = true

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
		local eid = world.uniqueEntityId(parent)
		if eid then
			crewPred = following and (world.entityType(eid) == "player")
		end
	end
	self:sendEntityMessage(
		"sbqScriptPaneMessage",
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
		sbq.Occupants.queueHudRefresh = true
	else
		world.sendEntityMessage(entity.id(), "sbqScriptPaneMessage", "sbqHudRefreshPortrait", self.entityId, sb.jsonMerge(self.flags, {
			time = self.time,
			location = self.location,
			subLocation = self.subLocation,
			locationName = self.locationName
		}))
	end
end

function sbq._Occupant:checkValidEffects(setting, effects)
	if not (effects and self.locationSettings[setting]) then return false end
	for _, effect in ipairs(effects) do
		if type(effect) == "string" then
			local effectConfig = root.effectConfig(effect).effectConfig or {}
			if effectConfig.finishAction then
				local success, failReason = sbq.SpeciesScript:actionAvailable(effectConfig.finishAction, self.entityId)
				if not success then return false end
			end
		end
	end
	return true
end

function sbq._Occupant:active()
	return self:valid() and not (self.flags.digested or self.flags.infused or self.flags.infusing or self.flags.digesting)
end
function sbq._Occupant:valid()
	return not (self.flags.newOccupant or self.flags.releasing)
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

function sbq._Occupant:attemptStruggle(control)
	local location = self:getLocation()
	local bonusTime = 0
	local maybeBonus, locationDirection = location:refreshStruggleDirection(self.entityId)
	local struggleAction, direction = location:getStruggleAction(control)
	local powerMultiplier = self:stat("powerMultiplier")
	if locationDirection == direction then
		bonusTime = bonusTime + maybeBonus
	end
	if sbq.randomTimer("occupantStruggleDialogue", sbq.voreConfig.occupantStruggleDialogueMin or sbq.config.occupantStruggleDialogueMin, sbq.voreConfig.occupantStruggleDialogueMax or sbq.config.occupantStruggleDialogueMax) and dialogueProcessor and dialogue.finished and sbq.settings.read.actionDialogue and not sbq.timerRunning("dialogueAfter") then
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
			bonusTime = bonusTime +
				sbq.SpeciesScript:doAnimations(struggleAction.pressAnimations, { s_direction = direction }, self.entityId)
		end
		if (bonusTime > 0) then
			if not self:controlHeld("Walk") then
				status.modifyResource("energy", -(struggleAction.predCost or sbq.config.predStruggleCost) * powerMultiplier)
			end
			if not self:overConsumeResource("energy", (struggleAction.preyCost or sbq.config.preyStruggleCost) * powerMultiplier ) then return end

			for k, v in pairs(struggleAction.givePreyResource or {}) do
				self:giveResource(k,v)
			end
			for k, v in pairs(struggleAction.givePredResource or {}) do
				status.giveResource(k,v)
			end
			if status.isResource("sbqLust") and status.resourcePercentage("sbqLust") >= 1 then
				sbq.SpeciesScript:climax(self.entityId)
			end
		end
		self:tryStruggleAction(1, bonusTime)
	end
end
function sbq._Occupant:releaseStruggle(control, time)
	local location = self:getLocation()
	location:refreshStruggleDirection(self.entityId)
end

function sbq._Occupant:getLocation()
	return sbq.SpeciesScript:getLocation(self.location, (not self.flags.infused) and self.subLocation)
end

function sbq._Occupant:checkStruggleDirection(dt)
	local dx = 0
	local dy = 0
	local powerMultiplier = self:stat("powerMultiplier")
	local effectiveness = (self.flags.digested and 0) or (self.flags.infused and 1) or (self.sizeMultiplier * self.size / sbq.getScale()) * powerMultiplier
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
		if not self:consumeResource("energy", ((self.struggleAction or {}).preyCost or sbq.config.preyStruggleCost) * powerMultiplier * dt, true) then return end
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

function sbq._Occupant:tryStruggleAction(inc, bonusTime)
	if (not self.struggleAction) or (not self:active())
		or self:controlHeld("Walk") or self:resourceLocked("energy")
		or (status.statPositive("sbqLockDown") and (status.resource("energy") > 0))
	then return false end
	if status.statPositive("sbqLockDown") then sbq.SpeciesScript:queueAction("lockDownClear", self.entityId) end
	locationStore = self.locationStore[self.location]
	if self.struggleAction.holdAnimations and not self.struggleAction.pressAnimations then
		sbq.SpeciesScript:doAnimations(self.struggleAction.holdAnimations or {}, {s_direction = self.struggleDirection})
	end
	local powerMultiplier = self:stat("powerMultiplier")
	self.struggleTime = (self.struggleTime or 0) + bonusTime
	self.struggleCount = (self.struggleCount or 0) + inc
	locationStore.struggleCount = (locationStore.struggleCount or 0) + inc
	if self.struggleAction.action then
		local timeSucceeded = (self.struggleTime * powerMultiplier) >= (sbq.settings.read.escapeDifficulty + math.random(table.unpack(self.struggleAction.time or { 0, 0 })))
		local countSucceeded = (self.struggleCount * powerMultiplier) >= (sbq.settings.read.escapeDifficulty + math.random(table.unpack(self.struggleAction.count or { 0, 0 })))
		if (self.struggleAction.both and (timeSucceeded and countSucceeded))
		or (not self.struggleAction.both and (timeSucceeded or countSucceeded))
		then
			if sbq.SpeciesScript:requestAction(true, self.struggleAction.action, self.entityId, table.unpack(self.struggleAction.args or {})) then
				self.struggleCount = math.ceil(math.sqrt(self.struggleCount))
				self.struggleTime = math.sqrt(self.struggleTime)
			end
		end
	end
end

function sbq._Occupant:controlPressed(control, time)
	if control == "Jump" then
		if self:controlHeld("Walk") and self:controlHeld("Down") then
			sbq.SpeciesScript:emergencyEscape(self)
			return
		end
	elseif control == "Interact" then
		self:sendEntityMessage("sbqInteractWith", entity.id())
		return
	end
	self:attemptStruggle(control)
end
function sbq._Occupant:controlReleased(control, time)
	self:releaseStruggle(control)
end

function sbq._Occupant:consumeResource(resource, amount, ignoreBlock)
	-- if an entity doesn't have the resource, they get to have it for free
	if not world.entity(self.entityId):isResource(resource) then return true end
	if (world.entity(self.entityId):resource(resource) >= amount) and ignoreBlock or not world.entity(self.entityId):resourceLocked(resource) then
		world.sendEntityMessage(self.entityId, "sbqOverConsumeResource", resource, amount, ignoreBlock)
		return true
	end
	return false
end
function sbq._Occupant:consumeResource(resource, amount, ignoreBlock)
	-- if an entity doesn't have the resource, they get to have it for free
	if not world.entity(self.entityId):isResource(resource) then return true end
	if (world.entity(self.entityId):resource(resource) >= amount) and ignoreBlock or not world.entity(self.entityId):resourceLocked(resource) then
		world.sendEntityMessage(self.entityId, "sbqOverConsumeResource", resource, amount, ignoreBlock)
		return true
	end
	return false
end
function sbq._Occupant:overConsumeResource(resource, amount, ignoreBlock)
	-- if an entity doesn't have the resource, they get to have it for free
	if not world.entity(self.entityId):isResource(resource) then return true end
	if (world.entity(self.entityId):resource(resource) > 0) and ignoreBlock or not world.entity(self.entityId):resourceLocked(resource) then
		world.sendEntityMessage(self.entityId, "sbqOverConsumeResource", resource, amount, ignoreBlock)
		return true
	end
	return false
end

function sbq._Occupant:resourceLocked(resource)
	-- if they don't have the resource, it can't be locked
	if not world.entity(self.entityId):isResource(resource) then return false end
	return world.entity(self.entityId):resourceLocked(resource)
end

function sbq._Occupant:resourcePercentage(resource)
	-- if they don't have the resource, treat it as empty
	if not world.entity(self.entityId):isResource(resource) then return 0 end
	return world.entity(self.entityId):resourcePercentage(resource)
end

function sbq._Occupant:modifyResourcePercentage(resource, amount)
	-- if they don't have the resource, treat it as empty
	if not world.entity(self.entityId):isResource(resource) then return 0 end
	return world.sendEntityMessage(self.entityId, "sbqModifyResourcePercentage", resource, amount)
end

function sbq._Occupant:resource(resource)
	-- if they don't have the resource, treat it as empty
	if not world.entity(self.entityId):isResource(resource) then return 0 end
	return world.entity(self.entityId):resource(resource)
end

function sbq._Occupant:giveResource(resource, amount)
	-- if they don't have the resource, do nothing
	if not world.entity(self.entityId):isResource(resource) then return end
	return world.sendEntityMessage(self.entityId, "sbqGiveResource", resource, amount)
end

function sbq._Occupant:stat(stat)
	return world.entity(self.entityId):stat(stat) or 0
end
function sbq._Occupant:statPositive(stat)
	return world.entity(self.entityId):statPositive(stat) or false
end

function sbq._Occupant:sendEntityMessage(...)
	if not world.entityExists(self.entityId) then return false end
	return world.sendEntityMessage(self.entityId, ...)
end

function sbq._Occupant:animProperty(property)
	return animator.partProperty(self.seat, property)
end
function sbq._Occupant:animNextProperty(property)
	return animator.partNextProperty(self.seat, property)
end
function sbq._Occupant:getPublicProperty(property)
	return world.entity(self.entityId):statusProperty(property)
end
function sbq._Occupant:position()
	return sbq.globalPartPoint(self.seat, "loungeOffset")
end
function sbq._Occupant:localPosition()
	return sbq.localPartPoint(self.seat, "loungeOffset")
end
function sbq._Occupant:controlHeld(...)
	return loungeable.controlHeld(self.seat, ...)
end
function sbq._Occupant:controlHeldTime(control)
	return self.controls[control].time
end
function sbq._Occupant:aimPosition(...)
	return loungeable.aimPosition(self.seat, ...)
end
function sbq._Occupant:entityLoungingIn(...)
	return loungeable.entityLoungingIn(self.seat, ...)
end
function sbq._Occupant:setLoungeEnabled(...)
	return loungeable.setLoungeEnabled(self.seat, ...)
end
function sbq._Occupant:setLoungeOrientation(...)
	return loungeable.setLoungeOrientation(self.seat, ...)
end
function sbq._Occupant:setLoungeEmote(...)
	return loungeable.setLoungeEmote(self.seat, ...)
end
function sbq._Occupant:setLoungeDance(...)
	return loungeable.setLoungeDance(self.seat, ...)
end
function sbq._Occupant:setLoungeDirectives(...)
	return loungeable.setLoungeDirectives(self.seat, ...)
end
function sbq._Occupant:setLoungeStatusEffects(...)
	return loungeable.setLoungeStatusEffects(self.seat, ...)
end
function sbq._Occupant:setToolUsageSuppressed(...)
	-- return loungeable.setToolUsageSuppressed(self.seat, ...)
end
function sbq._Occupant:setLoungeDismountable(...)
	return loungeable.setLoungeDismountable(self.seat, ...)
end
function sbq._Occupant:setLoungeHidden(...)
	return loungeable.setLoungeHidden(self.seat, ...)
end
function sbq._Occupant:setItemBlacklist(...)
	-- return loungeable.setItemBlacklist(self.seat, ...)
end
function sbq._Occupant:setItemWhitelist(...)
	-- return loungeable.setItemWhitelist(self.seat, ...)
end
function sbq._Occupant:setItemTagBlacklist(...)
	-- return loungeable.setItemTagBlacklist(self.seat, ...)
end
function sbq._Occupant:setItemTagWhitelist(...)
	-- return loungeable.setItemTagWhitelist(self.seat, ...)
end
function sbq._Occupant:setItemTypeBlacklist(...)
	-- return loungeable.setItemTypeBlacklist(self.seat, ...)
end
function sbq._Occupant:setItemTypeWhitelist(...)
	-- return loungeable.setItemTypeWhitelist(self.seat, ...)
end
function sbq._Occupant:getLoungeIndex()
	return loungeable.getLoungeIndex(self.seat)
end

function sbq._Occupant:logInfo(json)
	sbq.logInfo(("[%s][%s]%s"):format(self.seat, world.entityName(self.entityId), json))
end
function sbq._Occupant:logError(json)
	sbq.logError(("[%s][%s]%s"):format(self.seat, world.entityName(self.entityId), json))
end
function sbq._Occupant:debugLogInfo(json)
	sbq.debugLogInfo(("[%s][%s]%s"):format(self.seat, world.entityName(self.entityId), json))
end
function sbq._Occupant:debugLogError(json)
	sbq.debugLogError(("[%s][%s]%s"):format(self.seat, world.entityName(self.entityId), json))
end

function sbq._Occupant:capture()
	sbq.addRPC(self:sendEntityMessage("sbqGetCard"), function(card)
		if card then
			local humanoidConfig = world.entity(self.entityId):humanoidConfig()
			local newCapturedOccupant = {
				captureId = sb.makeUuid(),

				npcArgs = card.parameters.npcArgs,
				humanoidConfig = {
					bodyFullbright = humanoidConfig.bodyFullbright
				},

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
				locationSettings = self.locationSettings,

			}
			setmetatable(newCapturedOccupant, _CapturedOccupant)
			table.insert(sbq.Occupants.captured, newCapturedOccupant)
			table.insert(self:getLocation().occupancy.captured, newCapturedOccupant)
			self:remove("captured")
			self:sendEntityMessage("sbqCaptured", entity.id(), sbq.entityName(entity.id()))
		end
	end)
	return true
end

function _CapturedOccupant:save()
	return root.makeCurrentVersionedJson("sbqCapturedOccupant", {
		npcArgs = self.npcArgs,
		humanoidConfig = self.humanoidConfig,

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
		locationSettings = self.locationSettings,

	})
end
function _CapturedOccupant.new(capturedData)
	newCapturedOccupant = root.loadVersionedJson(capturedData, "sbqCapturedOccupant")
	newCapturedOccupant.captureId = sb.makeUuid()
	setmetatable(newCapturedOccupant, _CapturedOccupant)
	return newCapturedOccupant
end
function _CapturedOccupant:remove(reason)
	if self.subLocation then
		local subLocation = sbq.SpeciesScript:getLocation(self.location, self.subLocation)
		if subLocation then
			for i, occupant in ipairs(subLocation.occupancy.captured) do
				if occupant.captureId == self.captureId then
					subLocation:markSizeDirty()
					table.remove(subLocation.occupancy.captured, i)
					subLocation:refreshStruggleDirection()
					break
				end
			end
		end
	end
	local location = sbq.SpeciesScript:getLocation(self.location)
	if location then for i, occupant in ipairs(location.occupancy.captured) do
		if occupant.captureId == self.captureId then
			location:markSizeDirty()
			table.remove(location.occupancy.captured, i)
			location:refreshStruggleDirection()
			break
		end
	end end

	for i, occupant in ipairs(sbq.Occupants.captured) do
		if occupant.captureId == self.captureId then
			table.remove(sbq.Occupants.captured, i)
			break
		end
	end
	if self.flags.infused then
		sbq.settings:setParameterSettings()
	end
	sbq.Occupants.queueHudRefresh = true
	return true
end
function _CapturedOccupant:release()
	if not self.npcArgs.npcParam.wasPlayer then
		if self.npcArgs.npcParam.scriptConfig.uniqueId then
			sbq.addRPC(world.findUniqueEntity(self.npcArgs.npcParam.scriptConfig.uniqueId), function(found)
				if self.attemptedRelease then
					local npcConfig = root.npcConfig(self.npcArgs.npcType)
					local item = root.assetJson("/sbqItemTemplates.config:npcCard")
					if npcConfig.scriptConfig.isOC then
						item.parameters.rarity = "rare"
					elseif npcConfig.scriptConfig.sbqNPC then
						item.parameters.rarity = "uncommon"
					end
					item.parameters.preySize = self.size
					item.parameters.shortdescription = ((self.npcArgs.npcParam or {}).identity or {}).name or ""
					item.parameters.inventoryIcon = root.npcPortrait("bust", self.npcArgs.npcSpecies, self.npcArgs.npcType, self.npcArgs.npcLevel or 1, self.npcArgs.npcSeed, self.npcArgs.npcParam)
					item.parameters.description = (npcConfig.scriptConfig or {}).cardDesc or ""
					item.parameters.tooltipFields.collarNameLabel = sbq.createdDateString()
					item.parameters.createdDate = sbq.createdDate()
					item.parameters.tooltipFields.objectImage = root.npcPortrait("full", self.npcArgs.npcSpecies, self.npcArgs.npcType, self.npcArgs.npcLevel or 1, self.npcArgs.npcSeed, self.npcArgs.npcParam)
					item.parameters.tooltipFields.subtitle = self.npcArgs.npcType
					item.parameters.tooltipFields.collarIconImage = nil
					item.parameters.npcArgs = self.npcArgs
					world.spawnItem(item, entity.position())
					return self:remove("released")
				else
					self.attemptedRelease = true
					if _ENV.player and _ENV.interface then
						interface.queueMessage(sbq.getString(":releaseAgain"))
						interface.queueMessage(sbq.getString(":npcAlreadyExists"))
					end
				end
			end, function()
				local parent, recruitUUID, following = sbq.parentEntity()
				local crewPred
				if parent then
					local eid = world.uniqueEntityId(parent)
					if eid then
						crewPred = following and (world.entityType(eid) == "player")
					end
				end
				-- assume we're a client player and that we won't get the ID immediately, so supply all data needed in the initialization arguments
				self.npcArgs.npcParam.statusControllerSettings = sb.jsonMerge(self.npcArgs.npcParam.statusControllerSettings or {}, {
					statusProperties = {
						sbqOccupantStorage = root.makeCurrentVersionedJson("sbqOccupantStorage",{
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
							locationSettings = self.locationSettings,

							wasCaptured = true,
						})
					}
				})
				world.spawnNpc(entity.position(), self.npcArgs.npcSpecies, self.npcArgs.npcType, self.npcArgs.npcLevel, self.npcArgs.npcSeed, self.npcArgs.npcParam)
				return self:remove("released")
			end)
		else
			return self:remove("released")
		end
		return true
	else
		return self:remove("released")
	end
end


function _CapturedOccupant:infuseParameters(slot)
	local identity = self.npcArgs.npcParam.identity
	local humanoidConfig = self.humanoidConfig
	return {
		directives = identity.bodyDirectives .. identity.hairDirectives,
		species = identity.species,
		gender = identity.gender,
		bodyFullbright = humanoidConfig.bodyFullbright
	}
end
function sbq._Occupant:infuseParameters(slot)
	local identity = world.entity(self.entityId):humanoidIdentity()
	local humanoidConfig = world.entity(self.entityId):humanoidConfig()
	return {
		directives = identity.bodyDirectives .. identity.hairDirectives,
		species = identity.species,
		gender = identity.gender,
		bodyFullbright = humanoidConfig.bodyFullbright
	}
end
