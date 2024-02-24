function titleCanvas:draw()
	local c = widget.bindCanvas(self.backingWidget) c:clear()
	c:drawText("Starbecue "..root.modMetadata("Starbecue").version, {
		position = {titleCanvas.size[1]/2, titleCanvas.size[2]},
		horizontalAnchor = "mid",
		verticalAnchor = "top",
	}, 24)
end

local _dismiss
function init()
    player.setProperty("sbqSettingsVersion", root.modMetadata("Starbecue").version)
    _dismiss = pane.dismiss
	pane.dismiss = nil
end

function agree:onClick()
    player.setProperty("sbqAgreedTerms", true)
	player.setScriptContext("starbecue")
    player.callScript("sbq.init")
	_dismiss()
end

function allFetishes:onClick()
    allPred:onClick()
	allPrey:onClick()
	allTF:onClick()
end
function noFetishes:onClick()
    noPred:onClick()
	noPrey:onClick()
	noTF:onClick()
end

function allPred:onClick()
	for _,v in ipairs(sbq.gui.allPred) do
		sbq.widgetScripts.changeSetting(v[1],v[2])
    end
	sbq.assignSettingValues()
end
function allPrey:onClick()
	for _,v in ipairs(sbq.gui.allPrey) do
		sbq.widgetScripts.changeSetting(v[1],v[2])
    end
	sbq.assignSettingValues()
end
function allTF:onClick()
	for _,v in ipairs(sbq.gui.allTF) do
		sbq.widgetScripts.changeSetting(v[1],v[2])
    end
	sbq.assignSettingValues()
end

function noPred:onClick()
	for _,v in ipairs(sbq.gui.allPred) do
		sbq.widgetScripts.changeSetting(v[1],v[3] or (v[3] == nil and not v[2]))
    end
	sbq.assignSettingValues()
end
function noPrey:onClick()
	for _,v in ipairs(sbq.gui.allPrey) do
		sbq.widgetScripts.changeSetting(v[1],v[3] or (v[3] == nil and not v[2]))
    end
	sbq.assignSettingValues()
end
function noTF:onClick()
	for _,v in ipairs(sbq.gui.allTF) do
		sbq.widgetScripts.changeSetting(v[1],v[3] or (v[3] == nil and not v[2]))
    end
	sbq.assignSettingValues()
end
