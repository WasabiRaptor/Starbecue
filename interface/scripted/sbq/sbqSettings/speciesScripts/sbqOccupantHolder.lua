---@diagnostic disable: undefined-global

local genderList = {
	noChange = "No Change",
	swap = "Swap",
	random = "Random",
	male = "Male",
	female = "Female"
}
genderSwapButton:setText(genderList[sbq.predatorSettings.TFTG])

sbq.dropdownButton(genderSwapButton, "TFTG", {
	{ "noChange", "No Change" },
	{ "swap", "Swap" },
	{ "random", "Random" },
	{ "male", "Male" },
	{ "female", "Female"}
}, "changePredatorSetting", "overrideSettings")

if sbq.overrideSettings.TFTGEnable == false then
	genderswapPanel:setVisible(false)
end

scaleValue.handles[2].locked = not player.hasItem("sbqSizeRay")
scaleValue.handles[2].value = sbq.animOverrideOverrideSettings.scale or sbq.animOverrideSettings.scale or 1
scaleValue.handles[1].value = sbq.animOverrideOverrideSettings.scaleMin or sbq.animOverrideSettings.scaleMin or 0.1
scaleValue.handles[3].value = sbq.animOverrideOverrideSettings.scaleMax or sbq.animOverrideSettings.scaleMax or 3
function scaleValue:onChange(index, value)
	if index == 1 then
		sbq.changeAnimOverrideSetting("scaleMin", value)
	elseif index == 2 then
		sbq.changeAnimOverrideSetting("scale", value)
	elseif index == 3 then
		sbq.changeAnimOverrideSetting("scaleMax", value)
	end
	sbq.saveSettings()
end

-- scaleValue:setVisible(player.hasItem("sbqSizeRay"))
-- scaleValue:setText(tostring(sbq.animOverrideOverrideSettings.scale or sbq.animOverrideSettings.scale or 1))
-- local minmaxTable = {math.max(sbq.animOverrideSettings.scaleMin or 0.1, (sbq.animOverrideOverrideSettings.scaleMin or 0.1)), (sbq.animOverrideOverrideSettings.scaleMax or sbq.animOverrideSettings.scaleMax or 3)}
-- function scaleValue:onEnter() sbq.numberBox(self, "changeAnimOverrideSetting", "scale", "animOverrideSettings", "animOverrideOverrideSettings", table.unpack(minmaxTable) )  end
-- function scaleValue:onTextChanged() sbq.numberBoxColor(self, table.unpack(minmaxTable) ) end
-- function scaleValue:onEscape() self:onEnter() end
-- function scaleValue:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end
-- sbq.numberBoxColor(scaleValue, table.unpack(minmaxTable) )


-- scaleValueMin:setText(tostring(sbq.animOverrideOverrideSettings.scaleMin or sbq.animOverrideSettings.scaleMin or 0.1))
-- local minmaxTable = {(sbq.animOverrideOverrideSettings.scaleMin or 0.1), (sbq.animOverrideOverrideSettings.scale or sbq.animOverrideSettings.scale or 1)}
-- function scaleValueMin:onEnter() sbq.numberBox(self, "changeAnimOverrideSetting", "scaleMin", "animOverrideSettings", "animOverrideOverrideSettings", table.unpack(minmaxTable) ) end
-- function scaleValueMin:onTextChanged() sbq.numberBoxColor(self, table.unpack(minmaxTable) ) end
-- function scaleValueMin:onEscape() self:onEnter() end
-- function scaleValueMin:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end
-- sbq.numberBoxColor(scaleValueMin, table.unpack(minmaxTable) )


-- scaleValueMax:setText(tostring(sbq.animOverrideOverrideSettings.scaleMax or sbq.animOverrideSettings.scaleMax or 3))
-- local minmaxTable = { (sbq.animOverrideOverrideSettings.scale or sbq.animOverrideSettings.scale or 1), (sbq.animOverrideOverrideSettings.scaleMax or 3)}
-- function scaleValueMax:onEnter() sbq.numberBox(self, "changeAnimOverrideSetting", "scaleMax", "animOverrideSettings", "animOverrideOverrideSettings", table.unpack(minmaxTable) ) end
-- function scaleValueMax:onTextChanged() sbq.numberBoxColor(self, table.unpack(minmaxTable) ) end
-- function scaleValueMax:onEscape() self:onEnter() end
-- function scaleValueMax:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end
-- sbq.numberBoxColor(scaleValueMax, table.unpack(minmaxTable))

require("/interface/scripted/sbq/sbqSettings/speciesScripts/sbqBallsAndBreastsRefresh.lua")
