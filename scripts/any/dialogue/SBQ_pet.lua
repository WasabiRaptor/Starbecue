local petCount = 0

function dialogueStepScripts.petting(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	petCount = petCount + 1
	local petType = "normal"
	local addPetActions = false
	if petCount > 55 then
		addPetActions = true
		petType = "problem"
	elseif petCount > 25 then
		addPetActions = true
		petType = "excessive"
	elseif petCount > 2 then
		addPetActions = true
		petType = "many"
	end
	local optionCount = petCount^1.25
	dialogue.result.optionsColumns = math.max(2, math.floor(optionCount / 40))
	optionCount = optionCount - (optionCount % dialogue.result.optionsColumns)

	if addPetActions then
		for i = #dialogue.result.options + 1, optionCount do
			table.insert(dialogue.result.options, dialogue.result.options[#dialogue.result.options] )
		end
	else
		dialogue.result.options = nil
	end

	return petType
end
