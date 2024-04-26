sbq_hunting = {
	targets = {},
	prompted = {}
}

function sbq_hunting:start()
	if true then
		sbq_hunting.dom()
	else
		sbq_hunting.sub()
	end
end

function sbq_hunting.dom()
	local actions = {}
	for _, action in ipairs(sbq.lists.seekActions) do
		local settings = sbq.settings.domBehavior[action]
		if sbq_hunting.checkResources(settings) and (settings.favored > 0) and SpeciesScript:actionAvailable(action) then
			for i = 1, settings.favored do
				table.insert(actions, action)
			end
		end
	end
	if not actions[1] then return false end
	local action = actions[math.random(#actions)]
	local settings = sbq.settings.domBehavior[action]
	local targets = {}
	for _, eid in ipairs(world.entityQuery(mcontroller.position(), 50, {
		withoutEntityId = entity.id(), includedTypes = { "creature" },
		withoutEntityIds = loungeable.entitiesLounging(),
	}) or {}) do
		if sbq_hunting.checkTarget(settings, eid) and SpeciesScript:actionAvailable(action, eid) then
			table.insert(targets, eid)
		end
	end
	sbq_hunting.prompted = {}
	sbq_hunting.targets = targets
	sbq_hunting.action = action
	sbq_hunting.isDom = true
	sbq_hunting.nextTarget()
end

function sbq_hunting.nextTarget()
	self.board:setEntity("sbqHuntingTarget", sbq_hunting.targets[1])
	table.remove(sbq_hunting.targets, 1)
end

function sbq_hunting.checkTarget(settings, target)
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
	if sbq_hunting.isDom then
		if SpeciesScript:actionAvailable(sbq_hunting.action, target) then
			if false and sbq.settings.interactDialogue then
				if world.entityType(target) == "player" then

				end
			else
				if world.entityType(target) == "player" then
					interactData = {"Message", { messageType = "sbqPromptAction", messageArgs = {entity.id(), sbq_hunting.action, sbq_hunting.isDom}}}
				end
				sbq.addRPC(world.sendEntityMessage(target, "sbqPromptAction", entity.id(), sbq_hunting.action, sbq_hunting.isDom), sbq_hunting.promptResponse)
			end
			sbq_hunting.prompted[target] = interactData
			sbq.forceTimer(target.."PromptTimeout", 3 * 60, function ()
				sbq_hunting.prompted[target] = nil
			end)
		end
	end
end

function sbq_hunting.promptResponse(response)
	if not response then
		sbq.timer("huntingNextTarget", 60, sbq_hunting.nextTarget)
		return
	end
	local tryAction, isDom, line, action, target = table.unpack(response)
	if tryAction then
		if isDom then
			local success, reason = SpeciesScript:tryAction(action, target)
			if success then
				-- TODO re-implement dialogue
			else
			end
		else
			sbq.addRPC(world.sendEntityMessage(target, "sbqTryAction", action, entity.id()), function (results)
				if not results then return end
				local success, reason = table.unpack(results)
				if success then
					-- TODO re-implement dialogue
				else
				end
			end)
		end
	else
		sbq_hunting.nextTarget()
	end
end
