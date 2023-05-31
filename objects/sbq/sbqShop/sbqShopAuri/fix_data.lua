
function dialogueBoxScripts.fixData(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	player.setProperty("sbqCurrentData", nil)
	status.setStatusProperty("sbqCurrentData", nil)
	player.setProperty("sbqPreyWarpData", nil)
	return dialogueTree
end

function optionCheckScripts.fixData(settings, ...)
	local preyWarp = player.getProperty("sbqPreyWarpData")
	if preyWarp then return true end

	local sbqCurrentData = player.getProperty("sbqCurrentData") or {}
	local sbqCurrentData2 = status.statusProperty("sbqCurrentData") or {}
	if ((sbqCurrentData.type == "driver") and (sbqCurrentData2.type == "driver"))
	or ((sbqCurrentData.type == nil) and (sbqCurrentData2.type == nil))
	then
		return false
	end

	return true
end
