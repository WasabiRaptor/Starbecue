---@diagnostic disable: undefined-global


require("/interface/scripted/sbq/sbqSettings/sbqStatsTab.lua")

function sbq.extraTab()
	--sbq.statsTab()
	mainTabField.subTabs.otherGlobalTab = {statsTabField}
end
