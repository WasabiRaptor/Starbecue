local function sbqVersion()
	return root.assetSourceMetadata(root.assetOrigin("/sbq.config")).version
end

function _ENV.titleCanvas:draw()
	local c = widget.bindCanvas(self.backingWidget) c:clear()
	c:drawText("Starbecue "..sbqVersion(), {
		position = {_ENV.titleCanvas.size[1]/2, _ENV.titleCanvas.size[2]},
		horizontalAnchor = "mid",
		verticalAnchor = "top",
	}, 24)
end

local _dismiss
function init()
	player.setProperty("sbqSettingsVersion", sbqVersion())
	_dismiss = pane.dismiss
	pane.dismiss = function ()

	end
end

function _ENV.agree:onClick()
	local first = not player.getProperty("sbqAgreedTerms")
	player.setProperty("sbqAgreedTerms", true)
	if first then
		player.setHumanoidParameter("sbqEnabled", true)
		player.refreshHumanoidParameters()
	end
	_dismiss()
end

function _ENV.allFetishes:onClick()
	_ENV.allPred:onClick()
	_ENV.allPrey:onClick()
	_ENV.allTF:onClick()
end
function _ENV.noFetishes:onClick()
	_ENV.noPred:onClick()
	_ENV.noPrey:onClick()
	_ENV.noTF:onClick()
end

function _ENV.allPred:onClick()
	sbq.setAll(true, "pred", "vorePrefs", "voreTypeData")
	sbq.setAll(true, "pred", "infusePrefs", "infuseTypeData")
	sbq.assignSettingValues()
end
function _ENV.allPrey:onClick()
	sbq.setAll(true, "prey", "vorePrefs", "voreTypeData")
	sbq.setAll(true, "prey", "infusePrefs", "infuseTypeData")
	sbq.assignSettingValues()
end
function _ENV.allTF:onClick()
	for _,v in ipairs(sbq.gui.allTF) do
		sbq.widgetScripts.changeSetting(v[2], v[1])
	end
	sbq.assignSettingValues()
end

function _ENV.noPred:onClick()
	sbq.setAll(false, "pred", "vorePrefs", "voreTypeData")
	sbq.setAll(false, "pred", "infusePrefs", "infuseTypeData")
	sbq.assignSettingValues()
end
function _ENV.noPrey:onClick()
	sbq.setAll(false, "prey", "vorePrefs", "voreTypeData")
	sbq.setAll(false, "prey", "infusePrefs", "infuseTypeData")
	sbq.assignSettingValues()
end
function _ENV.noTF:onClick()
	for _,v in ipairs(sbq.gui.allTF) do
		sbq.widgetScripts.changeSetting(v[3] or (v[3] == nil and not v[2]), v[1])
	end
	sbq.assignSettingValues()
end

function sbq.setAll(v, setting, pref, prefData)
	for k, _ in pairs(sbq.config[prefData]) do
		sbq.widgetScripts.changeSetting(v, setting, pref, k)
	end
end
