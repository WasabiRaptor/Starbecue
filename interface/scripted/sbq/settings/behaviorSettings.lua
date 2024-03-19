function init()
	_ENV.mainTabField.tabs.behavior.subTabFields = {
		_ENV.voreTypeBehaviorTabField,
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
		_ENV.voreTypeBehaviorTabField:newTab(tab)
	end
end

function sbq.refreshBehaviorTabVisibility()
	for _, voreType in ipairs(sbq.gui.voreTypeOrder) do
		tab = _ENV.voreTypeBehaviorTabField.tabs[voreType]
		tab:setVisible(sbq.settings.vorePrefs[voreType].pred or sbq.settings.vorePrefs[voreType].prey or false)
		_ENV[voreType .. "PredBehaviorPanel"]:setVisible(sbq.settings.vorePrefs[voreType].pred)
		_ENV[voreType .. "PreyBehaviorPanel"]:setVisible(sbq.settings.vorePrefs[voreType].prey)
	end
	for _, voreType in ipairs(sbq.gui.infuseTypeOrder) do
		tab = _ENV.voreTypeBehaviorTabField.tabs[voreType]
		tab:setVisible(sbq.settings.infusePrefs[voreType].pred or sbq.settings.infusePrefs[voreType].prey or false)
		_ENV[voreType .. "PredBehaviorPanel"]:setVisible(sbq.settings.infusePrefs[voreType].pred)
		_ENV[voreType .. "PreyBehaviorPanel"]:setVisible(sbq.settings.infusePrefs[voreType].prey)
	end
end
