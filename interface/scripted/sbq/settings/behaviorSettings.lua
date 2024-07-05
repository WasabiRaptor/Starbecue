
function init()
	local seekActions = {}
	util.appendLists(seekActions, sbq.gui.seekActionOrder)
	util.appendLists(seekActions, sbq.gui.voreTypeOrder)
	util.appendLists(seekActions, sbq.gui.infuseTypeOrder)

	local baseTab = root.assetJson("/interface/scripted/sbq/settings/tabs/actionBehavior.config")
	for i, action in ipairs(seekActions) do
		local isVore = sbq.config.voreTypeData[action] ~= nil
		local isInfuse = sbq.config.infuseTypeData[action] ~= nil
		_ENV.behaviorTabField:newTab(sbq.replaceConfigTags(baseTab, {
			action = action,
			subBehavior = (isVore and ":preyBehavior") or (isInfuse and ":infuseeBehavior") or ":domBehavior",
			domBehavior = (isVore and ":predBehavior") or (isInfuse and ":infuseHostBehavior") or ":subBehavior"
		}))
	end

end

function sbq.refreshBehaviorTabVisibility()
	for action, tab in pairs(_ENV.behaviorTabField.tabs) do
		local domVisible = sbq.tableMatches(sbq.config.seekActionsSettings.dom[action], sbq.settings)
		local subVisible = sbq.tableMatches(sbq.config.seekActionsSettings.sub[action], sbq.settings)
		tab:setVisible(subVisible or domVisible)
		_ENV[action.."SubBehaviorPanel"]:setVisible(subVisible)
		_ENV[action.."DomBehaviorPanel"]:setVisible(domVisible)
	end
end
