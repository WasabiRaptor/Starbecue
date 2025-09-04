local oldIdMap = {
    ["sbq/flareon"] = "wr/flareon",
    ["sbq/vaporeon"] = "wr/vaporeon",
    ["sbq/meowscarada"] = "wr/meowscarada",
    ["sbq/nickit_anthro"] = "wr/nickit",
    ["sbq/zygahedron/zevi"] = "sbq/Zygahedron/Zevi",
}
function error(diskStore, e)
    if oldIdMap[diskStore.identity.species] then
        diskStore.identity.species = oldIdMap[diskStore.identity.species]
    end
    return diskStore
end
