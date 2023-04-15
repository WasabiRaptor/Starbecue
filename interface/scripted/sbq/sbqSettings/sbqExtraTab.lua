---@diagnostic disable: undefined-global


require("/interface/scripted/sbq/sbqSettings/sbqStatsTab.lua")

function sbq.extraTab()
	sbq.statsTab()
	sbq.fixMainTabSubTab.otherGlobalTab = {statsTabField}
end
