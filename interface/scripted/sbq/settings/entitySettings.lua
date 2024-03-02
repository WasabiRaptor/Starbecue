
function init()
	local entityType = world.entityType(pane.sourceEntity())
	if (entityType == "object") or (entityType == "vehicle") then
		_ENV.preyPrefsPanel:setVisible(false)
		_ENV.transformationPrefsPanel:setVisible(false)
		_ENV.otherPrefsPanel:setVisible(false)
	elseif entityType == "monster" then
		_ENV.transformationPrefsPanel:setVisible(false)
	end
end
