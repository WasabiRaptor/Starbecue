cfg = root.assetJson("/interface/scripted/sbq/settings/settings.ui")
sbq = config.getParameter("data").sbq or {}

local entityType = world.entityType(pane.sourceEntity())

if sbq.bioTab then
	table.insert(cfg.children[1].tabs, 1, root.assetJson(sbq.bioTab))
end

if (entityType == "object") or (entityType == "vehicle") then
	cfg.title = root.assetJson("/sbqStrings.config:preditor")
    table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/objectBehavior.config"))
else
	cfg.title = world.entityName(pane.sourceEntity()).." "..root.assetJson("/sbqStrings.config:settings")
    table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/behavior.config"))
	table.insert(cfg.scripts, 1, "behaviorSettings.lua")
end

table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/preferences.config"))

if sbq.helpTab then
	table.insert(cfg.children[1].tabs, root.assetJson(sbq.helpTab))
end

table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/help.config"))

table.insert(cfg.scripts, 1, "entitySettings.lua")

table.insert(cfg.children[1].tabs, root.assetJson("/interface/scripted/sbq/settings/tabs/misc.config"))
table.insert(cfg.scripts, "misc.lua")
