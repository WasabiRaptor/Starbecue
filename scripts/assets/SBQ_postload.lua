
assets.patch("/sbq.config", "/sbq_config_patch.lua")

for _, path in ipairs(assets.byExtension("monstertype")) do
    assets.patch(path, "/scripts/monster/SBQ_monster_patch.lua")
end

for _, path in ipairs(assets.byExtension("npctype")) do
    assets.patch(path, "/scripts/npc/SBQ_npc_patch.lua")
end

local armorLists = assets.json("/scripts/assets/SBQ_amor.config")
for _, path in ipairs(assets.byExtension("legs")) do
    local armor = assets.json(path)
    if not armor.sbqCompatible then
        if not armorLists.legsWhitelist[armor.itemName] then
            assets.patch(path, "/scripts/assets/SBQ_armor_hideCrotch_patch.config")
        end
        if armorLists.chestBlacklist[armor.itemName] then
            assets.patch(path, "/scripts/assets/SBQ_armor_hideChest_patch.config")
        end

    end
end
for _, path in ipairs(assets.byExtension("chest")) do
    local armor = assets.json(path)
    if not armor.sbqCompatible then
        if not armorLists.chestWhitelist[armor.itemName] then
            assets.patch(path, "/scripts/assets/SBQ_armor_hideChest_patch.config")
        end
        if armorLists.legsBlacklist[armor.itemName] then
            assets.patch(path, "/scripts/assets/SBQ_armor_hideCrotch_patch.config")
        end
    end
end
for _, path in ipairs(assets.byExtension("head")) do
    local armor = assets.json(path)
    if not armor.sbqCompatible then
        if armorLists.legsBlacklist[armor.itemName] then
            assets.patch(path, "/scripts/assets/SBQ_armor_hideCrotch_patch.config")
        end
        if armorLists.chestBlacklist[armor.itemName] then
            assets.patch(path, "/scripts/assets/SBQ_armor_hideChest_patch.config")
        end
    end
end
for _, path in ipairs(assets.byExtension("back")) do
    local armor = assets.json(path)
    if not armor.sbqCompatible then
        if armorLists.legsBlacklist[armor.itemName] then
            assets.patch(path, "/scripts/assets/SBQ_armor_hideCrotch_patch.config")
        end
        if armorLists.chestBlacklist[armor.itemName] then
            assets.patch(path, "/scripts/assets/SBQ_armor_hideChest_patch.config")
        end
    end
end

for _, path in ipairs(assets.byExtension("species")) do
    assets.patch(path, "/scripts/humanoid/SBQ_species_patch.lua")
    local speciesConfig = assets.json(path)
    local humanoidPath = "/humanoid/" .. speciesConfig.kind .. "/"
    for image, newImage in pairs(speciesConfig.sbqPartImages or {}) do
        -- sb.logInfo("[SBQ] generating '%s' from '%s'", humanoidPath..image, newImage..newImage.processingDirectives)
        assets.add(humanoidPath .. image, assets.image(newImage.sourceImage .. newImage.processingDirectives))
        assets.add(humanoidPath .. (image:gsub("%.png", ".frames")), assets.bytes(assets.frames(newImage.sourceImage).file))
    end
end
