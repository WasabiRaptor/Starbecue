local oldIdMap = {
    ["sbq/flareon"] = "wr/flareon",
    ["sbq/vaporeon"] = "wr/vaporeon",
    ["sbq/meowscarada"] = "wr/meowscarada",
    ["sbq/nickit_anthro"] = "wr/nickit"
}
function error(diskStore, e)
    if oldIdMap[diskStore.identity.species:lower()] then
        diskStore.identity.species = oldIdMap[diskStore.identity.species:lower()]
    end
    return diskStore
end
