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
    player.setScriptContext("starbecue")
    local data = player.callScript("sbq.getSettingsPageData")
	if not data then sb.logInfo("failed to get settings data") return pane.dismiss() end
	for k, v in pairs(data) do
		sbq[k] = v
    end
	storage.sbqSettings = sbq.storageSettings
    sbq.defaultSettings = sbq.config.entityTypeDefaultSettings.player or {}

	sbq.setupSettingMetatables("player")
end

function widgetScripts.changeSetting(setting,value,location)
    player.setScriptContext("starbecue")
	if location then
        player.callScript("sbq.setLocationSetting", location, setting, value)
		storage.sbqSettings.locations[setting] = value
    else
		player.callScript("sbq.setSetting", setting, value)
		storage.sbqSettings[setting] = value
	end
end

function widgetScripts.changeTableSetting(setting,value,location)
    player.setScriptContext("starbecue")
    local table = sb.parseJson(value)
	if not table then pane.playSound("/sfx/interface/clickon_error.ogg") return false end
	if location then
        player.callScript("sbq.setLocationSetting", location, setting, table)
		storage.sbqSettings.locations[setting] = table
    else
		player.callScript("sbq.setSetting", setting, table)
		storage.sbqSettings[setting] = table
	end
end
