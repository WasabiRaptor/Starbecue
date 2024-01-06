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

require("/interface/scripted/sbq/sbqSettings/speciesScripts/sbqBallsAndBreastsRefresh.lua")
