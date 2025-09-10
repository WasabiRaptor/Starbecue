local oldIdMap = {
	["sbq/flareon"] = "wr/flareon",
	["sbq/vaporeon"] = "wr/vaporeon",
	["sbq/meowscarada"] = "wr/meowscarada",
	["sbq/nickit_anthro"] = "wr/nickit",
}
function error(diskStore, e)
	if oldIdMap[diskStore.npcVariant.species:lower()] then
		diskStore.npcVariant.species = oldIdMap[diskStore.npcVariant.species:lower()]
	end
	if oldIdMap[diskStore.npcVariant.humanoidIdentity.species:lower()] then
		diskStore.npcVariant.humanoidIdentity.species = oldIdMap[diskStore.npcVariant.humanoidIdentity.species:lower()]
	end
	local overrideSpecies = sb.jsonQuery(diskStore.npcVariant, "overrides.identity.species")
	if overrideSpecies then
		if oldIdMap[overrideSpecies:lower()] then
			diskStore.npcVariant.overrides.identity.species = oldIdMap[overrideSpecies:lower()]
		end
	end
	return diskStore
end
