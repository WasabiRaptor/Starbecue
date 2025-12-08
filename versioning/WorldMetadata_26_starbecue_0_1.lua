require "/scripts/versioningutils.lua"

local oldIdMap = {
	["sbq/flareon"] = "wr/flareon",
	["sbq/vaporeon"] = "wr/vaporeon",
	["sbq/meowscarada"] = "wr/meowscarada",
	["sbq/nickit_anthro"] = "wr/nickit_anthro"
}
function update(diskStore)
	sb.logInfo(sb.printJson(diskStore,2))
	if diskStore.worldProperties["ship.species"] and oldIdMap[diskStore.worldProperties["ship.species"]] then
		 diskStore.worldProperties["ship.species"] = oldIdMap[diskStore.worldProperties["ship.species"]]
	end
	return diskStore
end
