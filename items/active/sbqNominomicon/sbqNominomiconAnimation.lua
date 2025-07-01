function update()
    local position = activeItemAnimation.ownerPosition()
    local entities = world.entityQuery(position, 20, {
        includedTypes = { "vehicle", "npc", "object", "monster" }
    })

    localAnimator.clearDrawables()
    for _, eid in ipairs(entities) do
        local entityType = world.entityType(eid)
        if entityType == "npc" then
            if world.entityStatPositive(eid, "sbqIsPrey") then
            elseif world.getNpcScriptParameter(eid, "sbqNPC") then
                localAnimator.addDrawable({
                    image = "/items/active/sbqNominomicon/indicator.png",
                    centered = true,
                    position = world.entityPosition(eid)
                }, "ForegroundOverlay+2")
            elseif world.entityStatPositive(eid, "sbqActorScript") then
                localAnimator.addDrawable({
                    image = "/items/active/sbqNominomicon/indicator.png?hueshift=-64",
                    centered = true,
                    position = world.entityPosition(eid)
                }, "ForegroundOverlay+2")
            end
        elseif entityType == "monster" then
            if world.entityStatPositive(eid, "sbqIsPrey") then
            elseif world.entityStatPositive(eid, "sbqActorScript") then
                localAnimator.addDrawable({
                    image = "/items/active/sbqNominomicon/indicator.png?hueshift=-64",
                    centered = true,
                    position = world.entityPosition(eid)
                }, "ForegroundOverlay+2")
            end
        elseif entityType == "vehicle" then

        elseif entityType == "object" then
            if world.getObjectParameter(eid, "sbqObject") then
                localAnimator.addDrawable({
                    image = "/items/active/sbqNominomicon/indicator.png",
                    centered = true,
                    position = world.entityPosition(eid)
                }, "ForegroundOverlay+2")
            elseif world.getObjectParameter(eid, "sbqConfigGui") then
                localAnimator.addDrawable({
                    image = "/items/active/sbqNominomicon/indicator.png?hueshift=64",
                    centered = true,
                    position = world.entityPosition(eid)
                }, "ForegroundOverlay+2")
            end
        end
    end
end
