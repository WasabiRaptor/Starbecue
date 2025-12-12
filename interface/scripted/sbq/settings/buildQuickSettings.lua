cfg = root.assetJson("/interface/scripted/sbq/settings/quickSettings.ui")

local sbq = world.sendEntityMessage(player.id(), "sbqSettingsPageData"):result() or {}
cfg.inputData = {
	sbq = sbq
}
sbq.voreConfig = sbq.voreConfig or {}
sbq.settingsConfig = sbq.settingsConfig or {}

local sbqConfig = root.assetJson("/sbq.config")
sbq.voreConfig.availableVoreTypes = sbq.voreConfig.availableVoreTypes or {}
sbq.voreConfig.availableInfuseTypes = sbq.voreConfig.availableInfuseTypes or {}
for k, v in pairs(sbqConfig.voreTypeData) do
	sbq.voreConfig.availableVoreTypes[k] = true
end
for k, v in pairs(sbqConfig.infuseTypeData) do
	sbq.voreConfig.availableInfuseTypes[k] = true
end
