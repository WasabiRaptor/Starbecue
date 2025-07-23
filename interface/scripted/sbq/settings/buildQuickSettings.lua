cfg = root.assetJson("/interface/scripted/sbq/settings/quickSettings.ui")

local sbq = world.sendEntityMessage(player.id(), "sbqSettingsPageData"):result()
cfg.inputData = {
	sbq = sbq
}

table.insert(cfg.children, #cfg.children, root.assetJson("/interface/scripted/sbq/settings/tabs/preferences.config:contents")[1])
