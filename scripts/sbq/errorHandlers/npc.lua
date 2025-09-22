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
	if diskStore.npcVariant.humanoidParameters then -- clear humanoid parameters just in case its a specific part causing the issue
		for k, v in pairs(root.assetJson("/sbq.config:parameterSettings")) do
			diskStore.npcVariant.humanoidParameters[v] = nil
			if sb.jsonQuery(diskStore, "scriptStorage.sbqSettings.content") then
				diskStore.scriptStorage.sbqSettings.content[k] = nil
			end
			if sb.jsonQuery(diskStore, "npcVariant.overrides.scriptConfig.sbqSettings.content") then
				diskStore.npcVariant.overrides.scriptConfig.sbqSettings.content[k] = nil
			end
			if sb.jsonQuery(diskStore, "npcVariant.overrides.scriptConfig.initialStorage.sbqSettings.content") then
				diskStore.npcVariant.overrides.scriptConfig.initialStorage.sbqSettings.content[k] = nil
			end
		end
	end
	return diskStore
end
