
function dialogueBoxScripts.fixData(dialogueTree, settings, branch, eid, ...)
	player.setProperty("sbqCurrentData", nil)
	status.setStatusProperty("sbqCurrentData", nil)
	player.setProperty("sbqPreyWarpData", nil)
	return dialogueTree
end
