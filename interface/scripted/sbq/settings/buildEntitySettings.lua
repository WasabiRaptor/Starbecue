cfg = root.assetJson("/interface/scripted/sbq/settings/settings.ui")
sbq = config.getParameter("data").sbq or {}
sbq.voreConfig = sbq.voreConfig or {}
sbq.settingsConfig = sbq.settingsConfig or {}

local entityType = world.entityType(pane.sourceEntity())
cfg.title = sbq.settingsPageName .. " " .. root.assetJson("/sbqStrings.config:settings")
cfg.inputData = {sbq = sbq}

if sbq.settingsConfig.hidePredSettings then
	table.remove(cfg.children[1].tabs, 1)
end
if not sbq.settingsConfig.hideBehaviorSettings then
	if (entityType == "object") or (entityType == "vehicle") then
		-- table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/objectBehavior.config"))
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
table.insert(cfg.scripts, 1, "misc.lua")

if sbq.helpTab then
	table.insert(cfg.children[1].tabs, root.assetJson(sbq.helpTab))
end

table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/help.config"))
table.insert(cfg.scripts, 1, "help.lua")
