
function init()
	local seekActions = {}
	util.appendLists(seekActions, sbq.gui.voreTypeOrder)
	util.appendLists(seekActions, sbq.gui.infuseTypeOrder)

	local baseTab = root.assetJson("/interface/scripted/sbq/settings/tabs/actionBehavior.config")
	for i, action in ipairs(seekActions) do
		_ENV.behaviorTabField:newTab(sbq.replaceConfigTags(baseTab, {action = action}))
	end

end

function sbq.refreshBehaviorTabVisibility()
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
