local petCount = 0

function dialogueBoxScripts.petting(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	petCount = petCount + 1
	local petType = "normal"
	local addPetActions = false
	if petCount > 20 then
		addPetActions = true
		petType = "problem"
	elseif petCount > 10 then
		addPetActions = true
		petType = "excessive"
	elseif petCount > 2 then
		addPetActions = true
		petType = "many"
	end
	if addPetActions then
		for i = 1, petCount do
			table.insert(dialogue.result.options, dialogue.result.options[#dialogue.result.options] )
		end
	end

	return petType
end
