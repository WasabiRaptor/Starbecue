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

function prepSBQModule(humanoidConfig, module)
    for _, v in ipairs(module.includes or {}) do
        humanoidConfig = prepSBQModule(humanoidConfig, root.assetJson(v))
        table.insert(humanoidConfig.sbqConfig.includes, v)
    end
    for _, v in ipairs(module.scripts or {}) do
        table.insert(humanoidConfig.sbqConfig.scripts, v)
    end
    if module.animation then
        table.insert(humanoidConfig.animation.includes, module.animation)
    end
    if module.cosmeticAnimation then
        local cosmeticAnimation = root.assetJson(module.cosmeticAnimation)
        for i = 1, 20 do
            humanoidConfig.animation = sb.jsonMerge(humanoidConfig.animation, fixSlotAnimation(cosmeticAnimation, i))
        end
    end
    if module.occupantAnimation then
        local occupantSlot = root.assetJson(module.occupantAnimation)
        for i = 1, (humanoidConfig.sbqOccupantSlots or 1) do
            humanoidConfig.animation = sb.jsonMerge(humanoidConfig.animation, fixSlotAnimation(occupantSlot, i))
        end
    end
    return humanoidConfig
end

function build(identity, humanoidParameters, humanoidConfig, npcHumanoidConfig)
    if humanoidParameters.sbqEnabled then
        humanoidConfig.useAnimation = true
    end
    humanoidConfig = old.build(identity, humanoidParameters, humanoidConfig, npcHumanoidConfig)
    if not (humanoidConfig.useAnimation and humanoidConfig.sbqEnabled and (type(humanoidConfig.animation) == "table") and humanoidConfig.sbqConfig) then
        return humanoidConfig
    end
    local sbqConfig = root.assetJson("/sbq.config")
    humanoidConfig.loungePositions = humanoidConfig.loungePositions or {}

    humanoidConfig.sbqOccupantSlots = humanoidConfig.sbqOccupantSlots or sbqConfig.seatCount or 0
    for i = 1, (humanoidConfig.sbqOccupantSlots) do
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
    end
    local baseModule = humanoidConfig.sbqConfig
    humanoidConfig.sbqConfig = {
        includes = jarray(),
        scripts = jarray()
    }
    prepSBQModule(baseModule)
    for i, slot in ipairs(humanoidConfig.sbqModuleOrder or sbqConfig.moduleOrder or {}) do
        local modules = humanoidConfig.sbqModules[slot]
        local selectedModule = humanoidParameters["sbqModule_" .. slot]
        if selectedModule then
            if modules[selectedModule] then
                humanoidConfig = prepSBQModule(humanoidConfig, root.assetJson(modules[selectedModule]))
            else
                humanoidConfig = prepSBQModule(humanoidConfig, root.assetJson(modules.default))
            end
        end
    end

    return humanoidConfig
end
