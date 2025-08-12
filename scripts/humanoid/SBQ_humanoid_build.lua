local old = {
    build = build or function() end
}

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

function build(identity, humanoidParameters, humanoidConfig, npcHumanoidConfig)
    if humanoidParameters.sbqEnabled then
        humanoidConfig.useAnimation = true
    end
    humanoidConfig = old.build(identity, humanoidParameters, humanoidConfig, npcHumanoidConfig)
    if not (humanoidConfig.useAnimation and humanoidConfig.sbqEnabled and (type(humanoidConfig.animation) == "table")) then
        return humanoidConfig
    end
    humanoidConfig.loungePositions = humanoidConfig.loungePositions or {}
    local speciesConfig = root.speciesConfig(identity.species)

    for _, v in ipairs(speciesConfig.animationCustom or {}) do -- temporary, will have to rethink this
        if type(v) == "string" then
            table.insert(humanoidConfig.animation.includes, v)
        else
            humanoidConfig.animation = sb.jsonMerge(humanoidConfig.animation, v)
        end
    end

    -- TODO make these more modular later
    -- vore occupant slots
    local occupantSlot = root.assetJson(humanoidConfig.sbqOccupantAnimation or "/humanoid/any/voreOccupant.animation")
    humanoidConfig.sbqOccupantSlots = humanoidConfig.sbqOccupantSlots or root.assetJson("/sbq.config:seatCount") or 0
    for i = 1, (humanoidConfig.sbqOccupantSlots or 1) do
        humanoidConfig.loungePositions["occupant" .. tostring(i)] = {
            part = "occupant" .. tostring(i),
            partAnchor = "loungeOffset",
            orientation = "stand",
            statusEffects = jarray(),
            dance = "sbqIdle",
            enabled = false,
            usePartZLevel = true,
            dismountable = false,
        }
        humanoidConfig.animation = sb.jsonMerge(humanoidConfig.animation, fixSlotAnimation(occupantSlot, i))
    end

    -- cosmetic slots
    -- local cosmeticSlot = root.assetJson(humanoidConfig.sbqCosmeticAnimation or "/humanoid/any/voreOccupant.animation")
    -- for i = 1, 20 do
    --     humanoidConfig.animation = sb.jsonMerge(humanoidConfig.animation, fixSlotAnimation(cosmeticSlot, i))
    -- end

    return humanoidConfig
end
