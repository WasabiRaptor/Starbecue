
function init()
	local seekActions = {}
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
		local isVore = sbq.config.voreTypeData[action] ~= nil
		local isInfuse = sbq.config.infuseTypeData[action] ~= nil
		if isVore then
			tab:setVisible(sbq.settings.vorePrefs[action].pred or sbq.settings.vorePrefs[action].prey)
			_ENV[action.."SubBehaviorPanel"]:setVisible(sbq.settings.vorePrefs[action].prey)
			_ENV[action.."DomBehaviorPanel"]:setVisible(sbq.settings.vorePrefs[action].pred)
		elseif isInfuse then
			tab:setVisible(sbq.settings.infusePrefs[action].pred or sbq.settings.infusePrefs[action].prey)
			_ENV[action.."SubBehaviorPanel"]:setVisible(sbq.settings.infusePrefs[action].prey)
			_ENV[action.."DomBehaviorPanel"]:setVisible(sbq.settings.infusePrefs[action].pred)
		end
	end
end

function update()
	local source = pane.sourceEntity()
	if world.entityIsResource(source, "health") then
		_ENV.healthBar:setValue(world.entityResourcePercentage(source, "health"))
	else
		_ENV.healthBar.parent:setVisible(false)
	end
	if world.entityIsResource(source, "food") then
		_ENV.hungerBar:setValue(world.entityResourcePercentage(source,"food"))
	else
		_ENV.hungerBar.parent:setVisible(false)
	end
	if world.entityIsResource(source, "sbqLust") then
		_ENV.lustBar:setValue(world.entityResourcePercentage(source,"sbqLust"))
	else
		_ENV.lustBar.parent:setVisible(false)
	end
	if world.entityIsResource(source, "sbqRest") then
		_ENV.restBar:setValue(world.entityResourcePercentage(source,"sbqRest"))
	else
		_ENV.restBar.parent:setVisible(false)
	end


end
