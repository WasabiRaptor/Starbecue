function init()
    sbqWorldRefreshOverrideSettings()
    message.setHandler("sbqWorldRefreshOverrideSettings", sbqWorldRefreshOverrideSettings)
end
function update(dt)

end
function uninit()

end

function sbqWorldRefreshOverrideSettings()
    local worldOverrideSettings = world.getProperty("sbqOverrideSettings") or {}
    local serverOverrideSettings = root.getConfigurationPath("sbq.overrideSettings") or {}
    world.setProperty("sbqOverrideSettings_player", sb.jsonMerge(
        worldOverrideSettings.any or {},
        worldOverrideSettings.player or {},
        serverOverrideSettings.any or {},
        serverOverrideSettings.player or {}
    ))
    world.setProperty("sbqOverrideSettings_npc", sb.jsonMerge(
        worldOverrideSettings.any or {},
        worldOverrideSettings.npc or {},
        serverOverrideSettings.any or {},
        serverOverrideSettings.npc or {}
    ))
    world.setProperty("sbqOverrideSettings_monster", sb.jsonMerge(
        worldOverrideSettings.any or {},
        worldOverrideSettings.monster or {},
        serverOverrideSettings.any or {},
        serverOverrideSettings.monster or {}
    ))
    world.setProperty("sbqOverrideSettings_object", sb.jsonMerge(
        worldOverrideSettings.any or {},
        worldOverrideSettings.object or {},
        serverOverrideSettings.any or {},
        serverOverrideSettings.object or {}
    ))
    world.setProperty("sbqOverrideSettings_vehicle", sb.jsonMerge(
        worldOverrideSettings.any or {},
        worldOverrideSettings.vehicle or {},
        serverOverrideSettings.any or {},
        serverOverrideSettings.vehicle or {}
    ))
    world.setProperty("sbqOverrideSettings_any", sb.jsonMerge(
        worldOverrideSettings.any or {},
        serverOverrideSettings.any or {}
    ))

    local worldInvalidSettings = world.getProperty("sbqInvalidSettings") or {}
    local serverInvalidSettings = root.getConfigurationPath("sbq.invalidSettings") or {}
    world.setProperty("sbqInvalidSettings_player", sb.jsonMerge(
        worldInvalidSettings.any or {},
        worldInvalidSettings.player or {},
        serverInvalidSettings.any or {},
        serverInvalidSettings.player or {}
    ))
    world.setProperty("sbqInvalidSettings_npc", sb.jsonMerge(
        worldInvalidSettings.any or {},
        worldInvalidSettings.npc or {},
        serverInvalidSettings.any or {},
        serverInvalidSettings.npc or {}
    ))
    world.setProperty("sbqInvalidSettings_monster", sb.jsonMerge(
        worldInvalidSettings.any or {},
        worldInvalidSettings.monster or {},
        serverInvalidSettings.any or {},
        serverInvalidSettings.monster or {}
    ))
    world.setProperty("sbqInvalidSettings_object", sb.jsonMerge(
        worldInvalidSettings.any or {},
        worldInvalidSettings.object or {},
        serverInvalidSettings.any or {},
        serverInvalidSettings.object or {}
    ))
    world.setProperty("sbqInvalidSettings_vehicle", sb.jsonMerge(
        worldInvalidSettings.any or {},
        worldInvalidSettings.vehicle or {},
        serverInvalidSettings.any or {},
        serverInvalidSettings.vehicle or {}
    ))
    world.setProperty("sbqInvalidSettings_any", sb.jsonMerge(
        worldInvalidSettings.any or {},
        serverInvalidSettings.any or {}
    ))

end
