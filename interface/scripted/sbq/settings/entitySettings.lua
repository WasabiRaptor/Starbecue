
function init()
	local entityType = world.entityType(pane.sourceEntity())
	if (entityType == "object") or (entityType == "vehicle") then
        _ENV.vorePreyPrefsPanel:setVisible(false)
		_ENV.infusePreyPrefsPanel:setVisible(false)
        _ENV.transformationPrefsPanel:setVisible(false)
		_ENV.resistancesPanel:setVisible(false)
        _ENV.otherPrefsPanel:setVisible(false)
		_ENV.sizePrefsPanel:setVisible(false)
	elseif entityType == "monster" then
		_ENV.transformationPrefsPanel:setVisible(false)
	end
end
