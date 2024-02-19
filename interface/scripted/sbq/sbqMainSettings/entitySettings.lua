sbq = {
	config = root.assetJson("/sbq.config")
}
settingSetup = {}
widgetScripts = {}
getWidget = {}
storage = {}

require("/scripts/any/SBQ_RPC_handling.lua")
require("/scripts/any/SBQ_util.lua")

function init()
    local data = metagui.inputData
	if not data then sb.logInfo("failed to get settings data") return pane.dismiss() end
	for k, v in pairs(data) do
		sbq[k] = v
    end
	storage.sbqSettings = sbq.storageSettings
    sbq.defaultSettings = sbq.config.entityTypeDefaultSettings.player or {}

	sbq.setupSettingMetatables(world.entityType(pane.sourceEntity()))
end

function widgetScripts.changeSetting(setting,value,location)
	if location then
        world.sendEntityMessage(pane.sourceEntity(), "sbqSetLocationSetting", location, setting, value)
		storage.sbqSettings.locations[setting] = value
    else
		world.sendEntityMessage(pane.sourceEntity(), "sbqSetSetting", setting, value)
		storage.sbqSettings[setting] = value
	end
end

function widgetScripts.changeTableSetting(setting,value,location)
    local table = sb.parseJson(value)
	if not table then pane.playSound("/sfx/interface/clickon_error.ogg") return false end
	if location then
        world.sendEntityMessage(pane.sourceEntity(), "sbqSetLocationSetting", location, setting, table)
		storage.sbqSettings.locations[setting] = table
    else
		world.sendEntityMessage(pane.sourceEntity(), "sbqSetSetting", setting, table)
		storage.sbqSettings[setting] = table
	end
end
