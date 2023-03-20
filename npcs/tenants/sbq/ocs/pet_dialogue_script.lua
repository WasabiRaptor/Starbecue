local petCount = 0

function dialogueBoxScripts.petting(dialogueTree, settings, branch, eid, ...)
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
	local dialogueTree = sb.jsonMerge({}, dialogueTree[petType])
	if addPetActions then
		local options = {}
		for i = 1, petCount do
			table.insert(options, dialogueTree.options[#dialogueTree.options] )
		end
		dialogueTree.options = options
	end

	return dialogueTree
end
