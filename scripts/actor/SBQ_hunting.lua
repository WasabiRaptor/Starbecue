sbq_hunting = {
	targets = {},
	prompted = {}
}

function sbq_hunting.start()
	if math.random() < sbq.settings.leanSubDom then
		sbq_hunting.dom()
	else
		sbq_hunting.sub()
	end
end

function sbq_hunting.dom()
	sbq_hunting.clearTarget()
	local actions = {}
	for _, action in ipairs(sbq.lists.seekActions) do
		local settings = sbq.settings.domBehavior[action]
		if (settings.favored > 0) and sbq_hunting.checkResources(settings) and SpeciesScript:actionAvailable(action) then
			for i = 1, settings.favored do
				table.insert(actions, action)
			end
		end
	end
	if not actions[1] then return false end
	local action = actions[math.random(#actions)]
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
end

function sbq_hunting.huntTarget(target)
	sbq_hunting.clearTarget()
	local actions = {}
	for _, action in ipairs(sbq.lists.seekActions) do
		local settings = sbq.settings.domBehavior[action]
		if (settings.favored > 0) and sbq_hunting.checkResources(settings) and sbq_hunting.checkTarget(action, true, target, false) and SpeciesScript:actionAvailable(action, target) then
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

function sbq_hunting.sub()
	sbq_hunting.clearTarget()
	local actions = {}
	for _, action in ipairs(sbq.lists.seekActions) do
		local settings = sbq.settings.subBehavior[action]
		if (settings.favored > 0) and sbq_hunting.checkResources(settings) and SpeciesScript:actionAvailable(action) then
			for i = 1, settings.favored do
				table.insert(actions, action)
			end
		end
	end
	if not actions[1] then return false end
	local action = actions[math.random(#actions)]
	local settings = sbq.settings.subBehavior[action]
	local targets = {}
	local consent = math.random() < settings.getConsentChance
	for _, target in ipairs(world.entityQuery(mcontroller.position(), 50, {
		withoutEntityId = entity.id(), includedTypes = { "creature" },
		withoutEntityIds = loungeable.entitiesLounging(),
	}) or {}) do
		local targetSettings = sbq.getPublicProperty(target, "sbqPublicSettings") or {}
		local targetAction = (sbq.getPublicProperty(target, "sbqActionData") or {})[action]
		if action and sbq_hunting.checkTarget(action, false, target, consent)
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
end

function sbq_hunting.checkTarget(action, isDom, target, consent)
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
	if (sbq.getScriptParameter(target, "sbqNPC") or sbq.getScriptParameter(target, "sbqObject")) and settings.targetOther then return true end
	return false
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
	if not sbq.timer("huntingActionAttemptCooldown", 5) then return end
	if sbq_hunting.prompted[target] ~= nil then return end
	if sbq_hunting.isDom then
		if SpeciesScript:actionAvailable(sbq_hunting.action, target) then
			if not sbq_hunting.getConsent then -- if not getting consent, just eat them immediately
				if sbq.settings.interactDialogue then
					-- TODO dialogue here for before eating someone without consent
				end
				if SpeciesScript:tryAction(sbq_hunting.action, target) then
					if math.random() < sbq.settings.huntingSpreeChance then -- a chance to continue the hunting spree
						sbq_hunting.nextTarget()
					else
						sbq_hunting.clearTarget()
					end
				else
					sbq_hunting.nextTarget()
				end
				return
			end
			local interactData
			if false and sbq.settings.interactDialogue then
				if world.entityType(target) == "player" then

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
	else -- being prey
		sbq.addRPC(world.sendEntityMessage(target, "sbqActionAvailable", sbq_hunting.action, entity.id()), function (results)
			if not results then sbq_hunting.nextTarget() return end
			local success, reason = table.unpack(results)
			if not success then sbq_hunting.nextTarget() return end
			if not sbq_hunting.getConsent then -- if not getting consent, just eat them immediately
				if sbq.settings.interactDialogue then
					-- TODO dialogue here for before getting into someone without consent
				end
				sbq.addRPC(world.sendEntityMessage(target, "sbqTryAction", sbq_hunting.action, entity.id()), function (results)
					if not results then sbq_hunting.nextTarget() return end
					local success, reason = table.unpack(results)
					if not success then sbq_hunting.nextTarget() return end
					sbq_hunting.clearTarget()
				end)
				return
			end

			local interactData
			if false and sbq.settings.interactDialogue then
				if world.entityType(target) == "player" then

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
		end)
	end
end

function sbq_hunting.promptResponse(response)
	if not response then
		sbq.timer("huntingNextTarget", 60, sbq_hunting.nextTarget)
		return
	end
	local tryAction, isDom, line, action, target = table.unpack(response)
	sbq_hunting.prompted[target] = nil
	if tryAction then
		if isDom then
			local success, reason = SpeciesScript:tryAction(action, target)
			if success then
				if math.random() < sbq.settings.huntingSpreeChance then -- a chance to continue the hunting spree
					sbq_hunting.nextTarget()
				else
					sbq_hunting.clearTarget()
				end
			else
				sbq_hunting.nextTarget()
			end
		else
			sbq.addRPC(world.sendEntityMessage(target, "sbqTryAction", action, entity.id()), function (results)
				if not results then return end
				local success, reason = table.unpack(results)
				if success then
					sbq_hunting.clearTarget()
					-- TODO re-implement dialogue
				else
					sbq_hunting.nextTarget()
				end
			end)
		end
	else
		sbq_hunting.nextTarget()
	end
end
