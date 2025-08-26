
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


local function fixSlotProperties(properties, slot)
    if not properties then return end
    if properties.zLevel then
        properties.zLevel = properties.zLevel + slot / 1000
    end
    if properties.flippedZLevel then
        properties.flippedZLevel = properties.flippedZLevel + slot / 1000
    end
    if properties.zLevelSlot then
        properties.zLevel = properties.zLevelSlot[slot]
    end
    if properties.flippedZLevelSlot then
        properties.flippedZLevel = properties.flippedZLevelSlot[slot]
    end
end

local function fixSlotFrameProperties(frameProperties, slot)
    if not frameProperties then return end
    if frameProperties.zLevel then
        for i, v in ipairs(frameProperties.zLevel) do
            frameProperties.zLevel[i] = v + slot / 1000
        end
    end
    if frameProperties.flippedZLevel then
        for i, v in ipairs(frameProperties.flippedZLevel) do
            frameProperties.flippedZLevel[i] = v + slot / 1000
        end
    end
    if frameProperties.zLevelSlot then
        for i, v in ipairs(frameProperties.zLevelSlot) do
            frameProperties.zLevel[i] = v[slot]
        end
    end
    if frameProperties.flippedZLevelSlot then
        for i, v in ipairs(frameProperties.flippedZLevelSlot) do
            frameProperties.flippedZLevel[i] = v[slot]
        end
    end
end

local function fixSlotAnimation(animation, slot)
    local animation = sb.parseJson(sb.printJson(animation):gsub("%<slot%>", tostring(slot)))
    for stateTypeName, stateType in pairs(animation.animatedParts.stateTypes or {}) do
        fixSlotProperties(stateType.properties, slot)
        fixSlotFrameProperties(stateType.frameProperties, slot)
        for stateName, state in pairs(stateType.states) do
            fixSlotProperties(state.properties, slot)
            fixSlotFrameProperties(state.frameProperties, slot)
        end
    end
    for partName, part in pairs(animation.animatedParts.parts or {}) do
        fixSlotProperties(part.properties, slot)
        fixSlotFrameProperties(part.frameProperties, slot)
        for stateTypeName, stateType in pairs(part.partStates or {}) do
            for stateName, state in pairs(stateType) do
                if type(state) == "table" then
                    fixSlotProperties(state.properties, slot)
                    fixSlotFrameProperties(state.frameProperties, slot)
                end
            end
        end
    end
    return animation
end

local occupantSlotCap = assets.json("/sbq.config:occpantSlotCap")
for _, path in ipairs(assets.scan("", "sbqOccupant.animation")) do
    local animation = assets.json(path)
    for i = 1, (animation.slots or occupantSlotCap) do
        assets.add(path.."."..i, sb.printJson(fixSlotAnimation(animation, i)))
    end
end
