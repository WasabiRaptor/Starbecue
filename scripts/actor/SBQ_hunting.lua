sbq_hunting = {
	targets = {},
	prompted = {}
}

function sbq_hunting.start(action)
	if math.random() < sbq.settings.leanSubDom then
		return sbq_hunting.dom(action)
	else
		return sbq_hunting.sub(action)
	end
end

function sbq_hunting.log()
	local curTarget = self.board:getEntity("sbqHuntingTarget")
	if not curTarget then return string.format("No %s target for %s", sbq_hunting.isDom and "hunting" or "baiting", sbq_hunting.action) end
	local targets = ("%s:%s\n"):format(curTarget, sbq.entityName(curTarget))
	for _, v in ipairs(sbq_hunting.targets) do
		targets = targets..("%s:%s\n"):format(v, sbq.entityName(v))
	end
	return string.format("%s for %s\npotential targets:\n%s", sbq_hunting.isDom and "Hunting" or "Baiting", sbq_hunting.action, targets)
end

function sbq_hunting.dom(action)
	sbq_hunting.clearTarget()
	local actions = {}
	if not action then
		for action, check in pairs(sbq.config.seekActionsSettings.dom) do
			local settings = sbq.settings.domBehavior[action]
			if (settings.favored > 0) and sbq_hunting.checkResources(settings) and SpeciesScript:actionAvailable(action) and sbq.tableMatches(check, sbq.settings, true) then
				for i = 1, settings.favored do
					table.insert(actions, action)
				end
			end
		end
		if not actions[1] then return false end
		action = actions[math.random(#actions)]
	end
	local settings = sbq.settings.domBehavior[action]
	local targets = {}
	local consent = math.random() < settings.getConsentChance
	for _, target in ipairs(world.entityQuery(mcontroller.position(), 50, {
		withoutEntityId = entity.id(), includedTypes = { "creature" },
		withoutEntityIds = loungeable.entitiesLounging(),
	}) or {}) do
		if sbq_hunting.checkTarget(action, true, target, consent) and SpeciesScript:actionAvailable(action, target) then
			table.insert(targets, target)
		end
	end
	sbq_hunting.targets = targets
	sbq_hunting.action = action
	sbq_hunting.isDom = true
	sbq_hunting.getConsent = consent
	sbq_hunting.nextTarget()
	return sbq_hunting.log()
end

function sbq_hunting.huntTarget(target, action)
	sbq_hunting.clearTarget()
	local actions = {}
	for action, check in pairs(sbq.config.seekActionsSettings.dom) do
		local settings = sbq.settings.domBehavior[action]
		if (settings.favored > 0) and sbq_hunting.checkResources(settings) and sbq_hunting.checkTarget(action, true, target, false) and SpeciesScript:actionAvailable(action, target) and sbq.tableMatches(check, sbq.settings, true) then
			for i = 1, settings.favored do
				table.insert(actions, action)
			end
		end
	end
	if not actions[1] then return false end
	sbq_hunting.targets = {target}
	sbq_hunting.action = actions[math.random(#actions)]
	sbq_hunting.isDom = true
	sbq_hunting.getConsent = false
	sbq_hunting.nextTarget()
end

function sbq_hunting.nextTarget()
	self.board:setEntity("sbqHuntingTarget", table.remove(sbq_hunting.targets, 1))
end
function sbq_hunting.clearTarget()
	self.board:setEntity("sbqHuntingTarget", nil)
	sbq_hunting.targets = {}
	sbq_hunting.prompted = {}
end

function sbq_hunting.sub(action)
	sbq_hunting.clearTarget()
	local actions = {}
	if not action then
		for action, check in pairs(sbq.config.seekActionsSettings.sub) do
			local settings = sbq.settings.subBehavior[action]
			if (settings.favored > 0) and sbq_hunting.checkResources(settings) and sbq.tableMatches(check, sbq.settings, true) then
				for i = 1, settings.favored do
					table.insert(actions, action)
				end
			end
		end
		if not actions[1] then return false end
		action = actions[math.random(#actions)]
	end
	local settings = sbq.settings.subBehavior[action]
	local targets = {}
	local consent = math.random() < settings.getConsentChance
	for _, target in ipairs(world.entityQuery(mcontroller.position(), 50, {
		withoutEntityId = entity.id(), includedTypes = { "creature" },
		withoutEntityIds = loungeable.entitiesLounging(),
	}) or {}) do
		local targetSettings = sbq.getPublicProperty(target, "sbqPublicSettings") or {}
		local targetAction = (sbq.getPublicProperty(target, "sbqActionData") or {})[action]
		if action and targetAction
			and sbq_hunting.checkTarget(action, false, target, consent)
			and sbq.tableMatches(targetAction.targetSettings, sbq.settings, true)
			and sbq.tableMatches(targetAction.settings, targetSettings, true)
		then
			table.insert(targets, target)
		end
	end
	sbq_hunting.targets = targets
	sbq_hunting.action = action
	sbq_hunting.isDom = false
	sbq_hunting.getConsent = consent
	sbq_hunting.nextTarget()
	return sbq_hunting.log()
end

function sbq_hunting.checkTarget(action, isDom, target, consent)
	if world.entityStatPositive(target, "sbqIsPrey") or world.entityStatPositive(target, "sbqEntrapped") then return false end
	local settings = ((isDom and sbq.settings.domBehavior) or sbq.settings.subBehavior or {})[action]
	local targetSettings = sbq.getPublicProperty(target, "sbqPublicSettings") or {}
	local targetBehaviorSettings = ((isDom and targetSettings.subBehavior) or targetSettings.domBehavior or {})[action] or {}
	if (not consent) and targetBehaviorSettings.consentRequired then return false end
	local hostile = entity.isValidTarget(target)
	if hostile and (not settings.targetHostile) then return false end
	if (not hostile) and (not settings.targetFriendly) then return false end
	local entityType = world.entityType(target)
	if (entityType == "player") and settings.targetPlayer then return true end
	if sbq.getScriptParameter(target, "sbqOC") and settings.targetOC then return true end
	if ((sbq.getScriptParameter(target, "sbqNPC") or sbq.getScriptParameter(target, "sbqObject"))) and settings.targetCompatible then return true end
	return settings.targetOther or false
end

function sbq_hunting.checkResources(settings)
	if status.isResource("health") then
		local resource = status.resourcePercentage("health")
		if not (settings.healthThresholdMin <= resource) and (resource <= settings.healthThresholdMax) then return false end
	end
	if status.isResource("sbqLust") then
		local resource = status.resourcePercentage("sbqLust")
		if not (settings.lustThresholdMin <= resource) and (resource <= settings.lustThresholdMax) then return false end
	end
	if status.isResource("sbqRest") then
		local resource = status.resourcePercentage("sbqRest")
		if not (settings.restThresholdMin <= resource) and (resource <= settings.restThresholdMax) then return false end
	end
	if status.isResource("food") then
		local resource = status.resourcePercentage("food")
		if not (settings.hungerThresholdMin <= resource) and (resource <= settings.hungerThresholdMax) then return false end
	end
	return true
end

function sbq_hunting.attemptAction(target)
	if not sbq.timer("huntingActionAttemptCooldown", sbq.config.huntTargetActionCooldown) then return end
	if sbq_hunting.prompted[target] ~= nil then sbq_hunting.nextTarget() return end
	if sbq_hunting.isDom then
		if SpeciesScript:actionAvailable(sbq_hunting.action, target) then
			if sbq_hunting.getConsent then
				sbq_hunting.domSendPrompt(target)
			else
				sbq_hunting.domNoPrompt(target)
			end
		else
			sbq_hunting.nextTarget()
		end
	else -- being prey
		sbq.addRPC(world.sendEntityMessage(target, "sbqActionAvailable", sbq_hunting.action, entity.id()), function (results)
			if not results then sbq_hunting.nextTarget() return end
			local success, failReason, time = table.unpack(results)
			if not success then sbq_hunting.nextTarget() return end
			if sbq_hunting.getConsent then
				sbq_hunting.subSendPrompt(target)
			else
				sbq_hunting.subNoPrompt(target)
			end
		end, sbq_hunting.nextTarget)
	end
end

function sbq_hunting.promptResponse(response)
	if not response then
		sbq.timer("huntingNextTarget", 60, sbq_hunting.nextTarget)
		return
	end
	local try, isDom, line, action, target = table.unpack(response)
	world.sendEntityMessage(target, "scriptPaneMessage", "sbqCloseDialogueBox")
	if isDom then
		sbq_hunting.domPromptResponse(try, line, action, target)
	else
		sbq_hunting.subPromptResponse(try, line, action, target)
	end
end

function sbq_hunting.domPromptResponse(try, line, action, target)
	local function callback()
		sbq_hunting.prompted[target] = nil
		if try then
			local success, failReason, time, successfulFail, failReason2 =  SpeciesScript:tryAction(action, target)
			if success then
				if math.random() < sbq.settings.huntingSpreeChance then -- a chance to continue the hunting spree
					sbq_hunting.nextTarget()
				else
					sbq_hunting.clearTarget()
				end
				sbq.forceTimer("dialogueAfter", time + sbq.config.afterDialogueDelay, function()
					if sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".promptAction."..action.."."..line..".after", target) then
						dialogueProcessor.sendPlayerDialogueBox()
						dialogueProcessor.speakDialogue()
					end
				end)
			else
				sbq_hunting.nextTarget()
			end
		else
			sbq_hunting.nextTarget()
		end
	end
	if sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".promptAction."..action.."."..line..".before", target) then
		dialogueProcessor.sendPlayerDialogueBox()
		dialogueProcessor.speakDialogue(callback)
	else
		callback()
	end
end

function sbq_hunting.domSendPrompt(target)
	local interactData
	if sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".promptAction."..sbq_hunting.action, target) then
		interactData = dialogueProcessor.sendPlayerDialogueBox()
		if interactData then
			dialogueProcessor.speakDialogue()
		else
			dialogueProcessor.speakDialogue(function ()
				sbq.addRPC(world.sendEntityMessage(target, "sbqPromptAction", entity.id(), sbq_hunting.action, sbq_hunting.isDom), sbq_hunting.promptResponse)
			end)
		end
	else
		if world.entityType(target) == "player" then
			interactData = {"Message", { messageType = "sbqPromptAction", messageArgs = {entity.id(), sbq_hunting.action, sbq_hunting.isDom}}}
		end
		sbq.addRPC(world.sendEntityMessage(target, "sbqPromptAction", entity.id(), sbq_hunting.action, sbq_hunting.isDom), sbq_hunting.promptResponse)
	end
	if interactData then
		sbq_hunting.prompted[target] = interactData
		sbq.forceTimer(target.."PromptTimeout", 3 * 60, function ()
			sbq_hunting.prompted[target] = nil
		end)
	end
end

function sbq_hunting.domNoPrompt(target)
	local function callback()
		local success, failReason, time, successfulFail, failReason2 =  SpeciesScript:tryAction(sbq_hunting.action, target)
		if success then
			if not sbq.statPositive("sbqLockDown") and (math.random() < (sbq.settings.lockDownChance)) then
				sbq.queueAction("lockDown", target)
			end
			if math.random() < sbq.settings.huntingSpreeChance then -- a chance to continue the hunting spree
				sbq_hunting.nextTarget()
			else
				sbq_hunting.clearTarget()
			end
			sbq.forceTimer("dialogueAfter", time + sbq.config.afterDialogueDelay, function()
				if sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".noPromptAction."..sbq_hunting.action..".after", target) then
					dialogueProcessor.speakDialogue()
				end
			end)
		else
			sbq_hunting.nextTarget()
		end
	end
	if sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".noPromptAction."..sbq_hunting.action, target) then
		dialogueProcessor.sendPlayerDialogueBox()
		if entity.isValidTarget(target) then -- if we're not getting consent, and the target is hostile, we're not gonna stand there and wait for dialogue to finish before eating!
			dialogueProcessor.speakDialogue()
			callback()
		else
			dialogueProcessor.speakDialogue(callback)
		end
	else
		callback()
	end
end

function sbq_hunting.subPromptResponse(try, line, action, target)
	local function callback ()
		sbq_hunting.prompted[target] = nil
		if try then
			sbq.expectedActions[action] = true
			sbq.addRPC(world.sendEntityMessage(target, "sbqRequestAction", false, action, entity.id()), function(results)
				if not results then sbq_hunting.nextTarget() return end
				local success, failReason, time, successfulFail, failReason2 =  table.unpack(results)
				if not success then sbq_hunting.nextTarget() return end
				sbq.setLoungeControlHeld("Shift")
				sbq.forceTimer("willingPreyTime", sbq.config.willingPreyTime * 60, function ()
					sbq.releaseLoungeControl("Shift")
				end)
				sbq_hunting.clearTarget()
				sbq.forceTimer("dialogueAfter", time + sbq.config.afterDialogueDelay, function()
					if sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".requestAction."..action.."."..line..".after", target) then
						dialogueProcessor.speakDialogue()
					end
				end, sbq_hunting.nextTarget)
			end, sbq_hunting.nextTarget)
		else
			sbq_hunting.nextTarget()
		end
	end
	if sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".requestAction."..action.."."..line..".before", target) then
		dialogueProcessor.sendPlayerDialogueBox()
		dialogueProcessor.speakDialogue(callback)
	else
		callback()
	end

end

function sbq_hunting.subSendPrompt(target)
	local interactData
	if sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".requestAction."..sbq_hunting.action, target) then
		interactData = dialogueProcessor.sendPlayerDialogueBox()
		if interactData then
			dialogueProcessor.speakDialogue()
		else
			dialogueProcessor.speakDialogue(function ()
				sbq.addRPC(world.sendEntityMessage(target, "sbqPromptAction", entity.id(), sbq_hunting.action, sbq_hunting.isDom), sbq_hunting.promptResponse)
			end)
		end
	else
		if world.entityType(target) == "player" then
			interactData = {"Message", { messageType = "sbqPromptAction", messageArgs = {entity.id(), sbq_hunting.action, sbq_hunting.isDom}}}
		end
		sbq.addRPC(world.sendEntityMessage(target, "sbqPromptAction", entity.id(), sbq_hunting.action, sbq_hunting.isDom), sbq_hunting.promptResponse)
	end
	if interactData then
		sbq_hunting.prompted[target] = interactData
		sbq.forceTimer(target.."PromptTimeout", 3 * 60, function ()
			sbq_hunting.prompted[target] = nil
		end)
	end
end

function sbq_hunting.subNoPrompt(target)
	sbq.expectedActions[sbq_hunting.action] = true
	local function callback()
		sbq.addRPC(world.sendEntityMessage(target, "sbqRequestAction", true, sbq_hunting.action, entity.id()), function (results)
			if not results then sbq_hunting.nextTarget() return end
			local success, failReason, time, successfulFail, failReason2 =  table.unpack(results)
			if not success then sbq_hunting.nextTarget() return end
			sbq.setLoungeControlHeld("Shift")
			sbq.forceTimer("willingPreyTime", sbq.config.willingPreyTime * 60, function ()
				sbq.releaseLoungeControl("Shift")
			end)
			sbq.forceTimer("dialogueAfter", time + sbq.config.afterDialogueDelay, function()
				if sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".forcingAction."..sbq_hunting.action..".after", target) then
					dialogueProcessor.speakDialogue()
				end
			end)
			sbq_hunting.clearTarget()
		end, sbq_hunting.nextTarget)
	end
	if sbq.settings.actionDialogue and dialogueProcessor.getDialogue(".forcingAction."..sbq_hunting.action, target) then
		dialogueProcessor.sendPlayerDialogueBox()
		dialogueProcessor.speakDialogue(callback)
	else
		callback()
	end
end
