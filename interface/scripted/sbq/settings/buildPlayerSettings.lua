cfg = root.assetJson("/interface/scripted/sbq/settings/settings.ui")

local sbq = world.sendEntityMessage(player.id(), "sbqSettingsPageData"):result() or {}
cfg.inputData = {
	sbq = sbq
}

cfg.title = root.assetJson("/sbqStrings.config:settingsTitle")
table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/preferences.config"))

if sbq.helpTab then
	table.insert(cfg.children[1].tabs, root.assetJson(sbq.helpTab))
end
table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/misc.config"))
table.insert(cfg.scripts, 1, "misc.lua")

table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/help.config"))
table.insert(cfg.scripts, 1, "help.lua")

table.insert(cfg.scripts, 1, "playerSettings.lua")
