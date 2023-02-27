---@diagnostic disable:undefined-global

function resetGlobalSettings:onClick()
	sbq.globalSettings = sb.jsonMerge(sbq.config.globalSettings, {})
	sbq.saveSettings()
	sbq.despawnPred()
	if sbq.playerSettings then
		player.interact("ScriptPane", { gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:quickSettings" })
	end
	pane.dismiss()
end

function resetAllPredSettings:onClick()
	sbq.predatorSettings = {}
	if sbq.sbqSettings ~= nil then
		for pred, settings in pairs(sbq.sbqSettings) do
			if pred == "selected" then
				sbq.sbqSettings[pred] = nil
			elseif pred ~= "types" then
				sbq.sbqSettings[pred] = {}
			end
		end
	end
	sbq.saveSettings()
	sbq.despawnPred()
	pane.dismiss()

end

function resetCurPredSettings:onClick()
	sbq.predatorSettings = {}
	sbq.saveSettings()
	sbq.despawnPred()
	pane.dismiss()
end

function sbq.despawnPred()
	if sbq.sbqCurrentData ~= nil and type(sbq.sbqCurrentData.id) == "number" and world.entityExists(sbq.sbqCurrentData.id) then
		world.sendEntityMessage(sbq.sbqCurrentData.id, "despawn")
	end
end
