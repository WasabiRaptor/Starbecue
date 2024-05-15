
function dialogueStepScripts.percentage(dialogueTree, dialogueTreeTop, settings, step, eid, ...)
	local best = "default"
	local bestScore = 0
	for key, value in pairs(dialogueTree.percentage or {}) do
		local checkValue
		if world.entityIsResource(eid, key) then
			checkValue = world.entityResourcePercentage(eid, key)
		elseif type(settings[key]) == "number" then
			checkValue = settings[key]
		elseif type(sbq.getPublicProperty(eid, key)) == "number" then
			checkValue = sbq.getPublicProperty(eid, key)
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

function dialogueStepScripts.isOwner(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	local result = false
	local parentEntityData = sbq.parentEntity()
	if parentEntityData and parentEntityData[1] then
		result = world.entityUniqueId(eid) == parentEntityData[1]
	end
	return tostring(result)
end

function dialogueStepScripts.isFollowing(dialogueTree, dialogueTreeTop, settings, step, eid, ...)
	local result = false
	local parentEntityData = sbq.parentEntity()
	if parentEntityData and parentEntityData[1] then
		result = (world.entityUniqueId(eid) == parentEntityData[1]) and parentEntityData[3]
	end

	return tostring(result)
end

function dialogueStepScripts.promptResponse(dialogueTree, dialogueTreeTop, settings, step, eid, ...)
	world.sendEntityMessage(pane.sourceEntity, "sbqPromptResponse", table.unpack(dialogueTree.promptResponse), eid)
end

function dialogueStepScripts.statPositive(dialogueTree, dialogueTreeTop, settings, step, eid, ...)
	return world.entityStatPositive(eid, step) and step or step.."_notPositive"
end
dialogueStepScripts.sbqHeal = dialogueStepScripts.statPositive
dialogueStepScripts.sbqFemcumHeal = dialogueStepScripts.statPositive

dialogueStepScripts.sbqAcidSoftDigest = dialogueStepScripts.statPositive
dialogueStepScripts.sbqCumSoftDigest = dialogueStepScripts.statPositive
dialogueStepScripts.sbqFemcumSoftDigest = dialogueStepScripts.statPositive
dialogueStepScripts.sbqMilkSoftDigest = dialogueStepScripts.statPositive

dialogueStepScripts.sbqAcidDigest = dialogueStepScripts.statPositive
dialogueStepScripts.sbqCumDigest = dialogueStepScripts.statPositive
dialogueStepScripts.sbqFemcumDigest = dialogueStepScripts.statPositive
dialogueStepScripts.sbqMilkDigest = dialogueStepScripts.statPositive

dialogueStepScripts.sbqTransformation = dialogueStepScripts.statPositive
dialogueStepScripts.sbqDrainEnergy = dialogueStepScripts.statPositive
dialogueStepScripts.sbqEggify = dialogueStepScripts.statPositive

dialogueStepScripts.sbq_tailInfuse = dialogueStepScripts.statPositive
dialogueStepScripts.sbq_pawInfuse = dialogueStepScripts.statPositive
dialogueStepScripts.sbq_thighsInfuse = dialogueStepScripts.statPositive
dialogueStepScripts.sbq_bellyInfuse = dialogueStepScripts.statPositive
dialogueStepScripts.sbq_breastInfuse = dialogueStepScripts.statPositive
dialogueStepScripts.sbq_cockInfuse = dialogueStepScripts.statPositive
dialogueStepScripts.sbq_pussyInfuse = dialogueStepScripts.statPositive

dialogueStepScripts.sbqAcidDigestResistance = dialogueStepScripts.statPositive
dialogueStepScripts.sbqCumDigestResistance = dialogueStepScripts.statPositive
dialogueStepScripts.sbqFemcumDigestResistance = dialogueStepScripts.statPositive
dialogueStepScripts.sbqMilkDigestResistance = dialogueStepScripts.statPositive
