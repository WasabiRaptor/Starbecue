function init()
    _ENV.mainTabField.tabs.behavior.subTabFields = {
        _ENV.voreTypeBehaviorTabField,
		_ENV.infuseTypeBehaviorTabField
	}
	local baseVoreTab = root.assetJson("/interface/scripted/sbq/settings/tabs/voreBehavior.config")
    for i, voreType in ipairs(sbq.gui.voreTypeOrder) do
		local data = sbq.config.voreTypeData[voreType]
        local tab = sbq.replaceConfigTags(baseVoreTab, sb.jsonMerge(data.tags or {}, { voreType = voreType }))
		tab.icon = sbq.getActionIcon(voreType, sbq.iconDirectory)
		_ENV.voreTypeBehaviorTabField:newTab(tab)
    end

	local baseInfuseTab = root.assetJson("/interface/scripted/sbq/settings/tabs/infuseBehavior.config")
    for i, infuseType in ipairs(sbq.gui.infuseTypeOrder) do
		local data = sbq.config.infuseTypeData[infuseType]
        local tab = sbq.replaceConfigTags(baseInfuseTab, sb.jsonMerge(data.tags or {}, { infuseType = infuseType }))
		tab.icon = sbq.getActionIcon(infuseType, sbq.iconDirectory)
        _ENV.infuseTypeBehaviorTabField:newTab(tab)
    end
end

function sbq.refreshBehaviorTabVisibility()
    for id, tab in pairs(_ENV.voreTypeBehaviorTabField.tabs) do
        tab:setVisible(sbq.settings.vorePrefs[id].pred or sbq.settings.vorePrefs[id].prey or false)
        _ENV[id .. "PredBehaviorPanel"]:setVisible(sbq.settings[id .. "Pred"])
        _ENV[id .. "PreyBehaviorPanel"]:setVisible(sbq.settings[id .. "Prey"])
    end
	for id, tab in pairs(_ENV.infuseTypeBehaviorTabField.tabs) do
        tab:setVisible(sbq.settings.infusePrefs[id].pred or sbq.settings.infusePrefs[id].prey or false)
		_ENV[id .. "PredBehaviorPanel"]:setVisible(sbq.settings[id .. "Pred"])
        _ENV[id .. "PreyBehaviorPanel"]:setVisible(sbq.settings[id .. "Prey"])
	end
end
