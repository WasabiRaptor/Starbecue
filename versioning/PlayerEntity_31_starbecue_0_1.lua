require "/scripts/versioningutils.lua"

local oldIdMap = {
	["sbq/flareon"] = "wr/flareon",
	["sbq/vaporeon"] = "wr/vaporeon",
	["sbq/meowscarada"] = "wr/meowscarada",
	["sbq/nickit_anthro"] = "wr/nickit_anthro"
}
function update(diskStore)
	if oldIdMap[diskStore.identity.species:lower()] then
		diskStore.identity.species = oldIdMap[diskStore.identity.species:lower()]
	end
	return diskStore
end
