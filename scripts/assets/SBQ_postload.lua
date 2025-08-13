




for _, config in ipairs(assets.byExtension("monstertype")) do
    assets.patch(config, "/scripts/monster/SBQ_monster_patch.lua")
end

for _, config in ipairs(assets.byExtension("npctype")) do
    assets.patch(config, "/scripts/npc/SBQ_npc_patch.lua")
end

for _, config in ipairs(assets.byExtension("species")) do
    assets.patch(config, "/scripts/humanoid/SBQ_species_patch.lua")
    local speciesConfig = assets.json(config)
    local humanoidPath = "/humanoid/" .. speciesConfig.kind .. "/"
    for image, newImage in pairs(speciesConfig.sbqPartImages or {}) do
        if assets.exists(newImage) then
            sb.logInfo("[SBQ] generating '%s' from '%s'", humanoidPath..image)
            assets.add(humanoidPath .. image, assets.image(newImage))
            assets.add(humanoidPath .. (image:gsub("%.png", ".frames")), assets.frames(newImage))
        else
            sb.logInfo("[SBQ] unable to generate '%s' because '%s' does not exist", humanoidPath .. image, newImage)
        end
    end

end
