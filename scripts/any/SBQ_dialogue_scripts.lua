function dialogueStepScripts.isOwner(dialogueTree, dialogueTreeTop, settings, step, eid, ...)
	local result = false
	if eid then
		local uuid = world.entityUniqueId(eid)
		result = uuid ~= nil and uuid == settings.ownerUuid
	end
	return tostring(result)
end

function dialogueStepScripts.percentage(dialogueTree, dialogueTreeTop, settings, step, eid, ...)
	local best = "default"
	local bestScore = 0
	for key, value in pairs(dialogueTree.percentage or {}) do
		local checkValue
		if world.entityIsResource(eid, key) then
			checkValue = world.entityResourcePercentage(eid, key)
		elseif type(settings[key]) == "number" then
			checkValue = settings[key]
		end

		if type(checkValue) == "number" then
			local score
			if value < 0 then
				if checkValue < math.abs(value) then
					score = checkValue - value
				end
			else
				if checkValue > math.abs(value) then
					score = value + checkValue
				end
			end
			if type(score) == "number" then
				if score > bestScore then
					bestScore = score
					best = key
				end
			end
		end
	end
	return best
end

function dialogueStepScripts.giveRewards(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	return "default"
end
