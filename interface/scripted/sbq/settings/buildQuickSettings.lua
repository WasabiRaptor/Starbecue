cfg = root.assetJson("/interface/scripted/sbq/settings/quickSettings.ui")

player.setScriptContext("starbecue")
sbq = player.callScript("sbq.getSettingsPageData")
cfg.inputData = {
	sbq = sbq
}

table.insert(cfg.children, 2, root.assetJson("/interface/scripted/sbq/settings/tabs/preferences.config:contents"))
