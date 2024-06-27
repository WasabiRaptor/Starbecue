cfg = root.assetJson("/interface/scripted/sbq/settings/settings.ui")
sbq = config.getParameter("data").sbq or {}

local entityType = world.entityType(pane.sourceEntity())
cfg.title = sbq.settingsPageName .. " " .. root.assetJson("/sbqStrings.config:settings")
cfg.inputData = {sbq = {voreConfig = {}}}
if (entityType == "object") or (entityType == "vehicle") then
	cfg.inputData.sbq.voreConfig.hideOtherSettings = true
	cfg.inputData.sbq.voreConfig.hidePreySettings = true
	cfg.inputData.sbq.voreConfig.hideTFsettings = true
	cfg.inputData.sbq.voreConfig.hideSizeSettings = true
elseif entityType == "monster" then
	cfg.inputData.sbq.voreConfig.hideTFsettings = true
end

if sbq.voreConfig.hidePredSettings then
	table.remove(cfg.children[1].tabs, 1)
end
if not sbq.voreConfig.hideBehaviorSettings then
	if (entityType == "object") or (entityType == "vehicle") then
		table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/objectBehavior.config"))
	else
		table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/behavior.config"))
		table.insert(cfg.scripts, 1, "behaviorSettings.lua")
	end
end

if sbq.bioTab then
	table.insert(cfg.children[1].tabs, 1, root.assetJson(sbq.bioTab))
end

table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/preferences.config"))

table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/misc.config"))
table.insert(cfg.scripts, "misc.lua")

if sbq.helpTab then
	table.insert(cfg.children[1].tabs, root.assetJson(sbq.helpTab))
end

table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/help.config"))
table.insert(cfg.scripts, 1, "help.lua")
