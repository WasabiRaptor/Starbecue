
function dialogueStepScripts.fixData(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	player.setProperty("sbqCurrentData", nil)
	status.setStatusProperty("sbqCurrentData", nil)
	player.setProperty("sbqPreyWarpData", nil)
	return dialogueTree
end

function dialogueOptionScripts.fixData(settings, ...)
	local preyWarp = player.getProperty("sbqPreyWarpData")
	if preyWarp then return true end

	local type = status.statusProperty("sbqType")
	local type2 = player.getProperty("sbqType")
	if ((type == "driver") and (type2 == "driver"))
	or ((type == nil) and (type2 == nil))
	then
		return false
	end

	return true
end
