local oldIdMap = {
	["sbq/flareon"] = "wr/flareon",
	["sbq/vaporeon"] = "wr/vaporeon",
	["sbq/meowscarada"] = "wr/meowscarada",
	["sbq/nickit_anthro"] = "wr/nickit_anthro"
}
function error(diskStore, e)
	if oldIdMap[diskStore.identity.species:lower()] then
		diskStore.identity.species = oldIdMap[diskStore.identity.species:lower()]
	end
	if diskStore.humanoidParameters then -- clear humanoid parameters just in case its a specific part causing the issue
		for k, v in pairs(root.assetJson("/sbq.config:parameterSettings")) do
			diskStore.humanoidParameters[v] = nil
			if sb.jsonQuery(diskStore, "genericScriptStorage.starbecue.sbqSettings.content") then
				diskStore.genericScriptStorage.starbecue.sbqSettings.content[k] = nil
			end
			if sb.jsonQuery(diskStore, "genericProperties.sbqSettings.content") then
				diskStore.genericProperties.sbqSettings.content[k] = nil
			end
		end
	end
	return diskStore
end
