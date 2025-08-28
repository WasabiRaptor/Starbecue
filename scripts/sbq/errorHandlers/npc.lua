local oldIdMap = {
    ["sbq/flareon"] = "wr/flareon",
    ["sbq/vaporeon"] = "wr/vaporeon",
    ["sbq/meowscarada"] = "wr/meowscarada",
    ["sbq/nickit_anthro"] = "wr/nickit",
}
function error(diskStore, e)
    if oldIdMap[diskStore.npcVariant.species] then
        diskStore.npcVariant.species = oldIdMap[diskStore.npcVariant.species]
    end
    if oldIdMap[diskStore.npcVariant.humanoidIdentity.species] then
        diskStore.npcVariant.humanoidIdentity.species = oldIdMap[diskStore.npcVariant.humanoidIdentity.species]
    end
    local overrideSpecies = sb.jsonQuery(diskStore.npcVariant, "overrides.identity.species")
    if overrideSpecies then
        if oldIdMap[overrideSpecies] then
            diskStore.npcVariant.overrides.identity.species = oldIdMap[overrideSpecies]
        end
    end
    return diskStore
end
