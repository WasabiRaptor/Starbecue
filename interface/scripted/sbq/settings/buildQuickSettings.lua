cfg = root.assetJson("/interface/scripted/sbq/settings/quickSettings.ui")

local sbq = world.sendEntityMessage(player.id(), "sbqSettingsPageData"):result()
cfg.inputData = {
	sbq = sbq
}
local sbqConfig = root.assetJson("/sbq.config")
sbq.voreConfig = sbq.voreConfig or {}
sbq.voreConfig.availableVoreTypes = sbq.voreConfig.availableVoreTypes or {}
sbq.voreConfig.availableInfuseTypes = sbq.voreConfig.availableInfuseTypes or {}
for k, v in pairs(sbqConfig.voreTypeData) do
	sbq.voreConfig.availableVoreTypes[k] = true
end
for k, v in pairs(sbqConfig.infuseTypeData) do
	sbq.voreConfig.availableInfuseTypes[k] = true
end

table.insert(cfg.children, #cfg.children, root.assetJson("/interface/scripted/sbq/settings/tabs/preferences.config:contents")[1])
