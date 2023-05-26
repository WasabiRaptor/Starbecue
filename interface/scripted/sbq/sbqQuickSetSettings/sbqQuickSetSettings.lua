---@diagnostic disable: undefined-global

sbq = {
	config = root.assetJson( "/sbqGeneral.config" ),
	overrideSettings = {},
}
settingsButtonScripts = {}
speciesOverride = {}

function speciesOverride._species()
	return (status.statusProperty("speciesAnimOverrideData") or {}).species or speciesOverride.species()
end

function speciesOverride._gender()
	return (status.statusProperty("speciesAnimOverrideData") or {}).gender or speciesOverride.gender()
end
speciesOverride.species = player.species
player.species = speciesOverride._species

speciesOverride.gender = player.gender
player.gender = speciesOverride._gender

require("/scripts/SBQ_RPC_handling.lua")
require("/scripts/SBQ_species_config.lua")
require("/interface/scripted/sbq/sbqSettings/autoSetSettings.lua")



function init()
	player.setProperty("sbqSettingsVersion", sbq.config.settingsVersion)

	sbq.animOverrideSettings = sb.jsonMerge(root.assetJson("/animOverrideDefaultSettings.config"), status.statusProperty("speciesAnimOverrideSettings") or {})
	sbq.animOverrideSettings.scale = status.statusProperty("animOverrideScale") or 1
	sbq.animOverrideOverrideSettings = status.statusProperty("speciesAnimOverrideOverrideSettings") or {}

	sbq.sbqSettings = player.getProperty("sbqSettings") or {}

	sbq.sbqCurrentData = player.getProperty("sbqCurrentData") or {}
	sbq.lastSpecies = sbq.sbqCurrentData.species
	sbq.lastType = sbq.sbqCurrentData.type

	sbq.storedDigestedPrey = status.statusProperty("sbqStoredDigestedPrey") or {}

	sbq.predatorEntity = sbq.sbqCurrentData.id


	sbq.sbqCurrentData.species = sbq.sbqCurrentData.species or "sbqOccupantHolder"

	sbq.globalSettings = sb.jsonMerge(sbq.config.globalSettings, sbq.sbqSettings.global)

	if sbq.sbqCurrentData.species ~= nil then
		if sbq.sbqCurrentData.species == "sbqOccupantHolder" then
			sbq.getOccupantHolderData()
		else
			sbq.predatorConfig = root.assetJson("/vehicles/sbq/" .. sbq.sbqCurrentData.species .. "/" .. sbq.sbqCurrentData.species .. ".vehicle").sbqData or {}
			for location, data in pairs(sbq.predatorConfig.locations or {}) do
				sbq.predatorConfig.locations[location] = sb.jsonMerge(sbq.config.defaultLocationData[location] or {}, data)
			end
		end
		sbq.predatorSettings = sb.jsonMerge(sb.jsonMerge(sb.jsonMerge(sbq.config.defaultSettings, sbq.predatorConfig.defaultSettings or {}), sbq.sbqSettings[sbq.sbqCurrentData.species] or {}), sbq.globalSettings)
	else
		sbq.getOccupantHolderData()
		sbq.predatorSettings = sb.jsonMerge(sb.jsonMerge(sb.jsonMerge(sbq.config.defaultSettings, sbq.predatorConfig.defaultSettings or {}), sbq.sbqSettings.sbqOccupantHolder or {}), sbq.globalSettings)
	end
	sbq.overrideSettings = sbq.predatorConfig.overrideSettings or {}

	sbq.checkLockedSettingsButtons("predatorSettings", "overrideSettings", "changePredatorSetting")
	sbq.checkLockedSettingsButtons("globalSettings", "overrideSettings", "changeGlobalSetting")
	sbq.checkLockedSettingsButtons("animOverrideSettings", "animOverrideOverrideSettings", "changeAnimOverrideSetting")

	sbq.preySettings = sb.jsonMerge(sbq.config.defaultPreyEnabled.player, status.statusProperty("sbqPreyEnabled") or {})
	sbq.overridePreyEnabled = status.statusProperty("sbqOverridePreyEnabled") or {}
	sbq.checkLockedSettingsButtons("sbqPreyEnabled", "overridePreyEnabled", "changePreySetting")

	scaleValue.handles[2].locked = not player.hasItem("sbqSizeRay")
	scaleValue.handles[2].value = sbq.animOverrideOverrideSettings.scale or sbq.animOverrideSettings.scale or 1
	scaleValue.handles[1].value = sbq.animOverrideOverrideSettings.scaleMin or sbq.animOverrideSettings.scaleMin or 0.1
	scaleValue.handles[3].value = sbq.animOverrideOverrideSettings.scaleMax or sbq.animOverrideSettings.scaleMax or 3

	scaleValue.handles[1].locked = sbq.animOverrideOverrideSettings.scaleMin ~= nil
	scaleValue.handles[3].locked = sbq.animOverrideOverrideSettings.scaleMax ~= nil
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

	defaultInfusedMultiplier:setText(tostring(sbq.overrideSettings["default" .. "InfusedMultiplier"] or sbq.predatorSettings["default" .. "InfusedMultiplier"] or sbq.predatorSettings["default".."InfusedMultiplier"] or 0.5))
	function defaultInfusedMultiplier:onEnter() sbq.numberBox(self, "changeGlobalSetting", "default" .. "InfusedMultiplier", "globalSettings", "overrideSettings", 0) end
	function defaultInfusedMultiplier:onTextChanged() sbq.numberBoxColor(self, 0) end
	function defaultInfusedMultiplier:onEscape() self:onEnter() end
	function defaultInfusedMultiplier:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end
	sbq.numberBoxColor(defaultInfusedMultiplier, 0)

	defaultCompressionMultiplier:setText(tostring(sbq.overrideSettings["default" .. "CompressionMultiplier"] or sbq.predatorSettings["default" .. "CompressionMultiplier"] or sbq.predatorSettings["default".."CompressionMultiplier"] or 0.25))
	function defaultCompressionMultiplier:onEnter() sbq.numberBox(self, "changeGlobalSetting", "default" .. "CompressionMultiplier", "globalSettings", "overrideSettings", 0) end
	function defaultCompressionMultiplier:onTextChanged() sbq.numberBoxColor(self, 0) end
	function defaultCompressionMultiplier:onEscape() self:onEnter() end
	function defaultCompressionMultiplier:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end
	sbq.numberBoxColor(defaultCompressionMultiplier, 0)
end

function sbq.drawLocked(w, icon)
	local c = widget.bindCanvas(w.backingWidget)
	c:clear()
	local pos = vec2.mul(c:size(), 0.5)
	c:drawImageDrawable(icon, pos, 1)
end

function sbq.checkLockedSettingsButtons(settings, override, func)
	for setting, value in pairs(sbq[settings] or {}) do
		local button = _ENV[setting]
		if button ~= nil and type(value) == "boolean" then
			if sbq[override][setting] ~= nil then
				if sbq[override][setting] then
					function button:draw() sbq.drawLocked(button, "/interface/scripted/sbq/sbqVoreColonyDeed/lockedEnabled.png") end
				else
					function button:draw() sbq.drawLocked(button, "/interface/scripted/sbq/sbqVoreColonyDeed/lockedDisabled.png") end
				end
				function button:onClick() end
			else
				button:setChecked(value)
				function button:onClick()
					sbq[func](setting, button.checked)
					if type(settingsButtonScripts[setting]) == "function" then
						settingsButtonScripts[setting](setting, button.checked)
					end
				end
			end
		end
	end
end

function titleCanvas:draw()
	local c = widget.bindCanvas(self.backingWidget) c:clear()
	c:drawText("Starbecue "..root.assetJson("/sbqGeneral.config:settingsVersion"), {
		position = {titleCanvas.size[1]/2, titleCanvas.size[2]},
		horizontalAnchor = "mid",
		verticalAnchor = "top",
	}, 24)

end

function sbq.saveSettings()
	if type(sbq.sbqCurrentData.id) == "number" and sbq.sbqCurrentData.type == "driver" and world.entityExists(sbq.sbqCurrentData.id) then
		world.sendEntityMessage( sbq.sbqCurrentData.id, "settingsMenuSet", sb.jsonMerge(sbq.predatorSettings, sbq.globalSettings))
	end

	sbq.sbqSettings[sbq.sbqCurrentData.species or "sbqOccupantHolder"] = sbq.predatorSettings
	sbq.sbqSettings.global = sbq.globalSettings
	player.setProperty( "sbqSettings", sbq.sbqSettings )
	world.sendEntityMessage( player.id(), "sbqRefreshSettings", sbq.sbqSettings )
end

function sbq.changeGlobalSetting(settingname, settingvalue)
	sbq.globalSettings[settingname] = settingvalue
	sbq.predatorSettings[settingname] = settingvalue
	sbq.autoSetSettings(settingname, settingvalue)

	sbq.saveSettings()
end

function sbq.changePredatorSetting(settingname, settingvalue)
	sbq.predatorSettings[settingname] = settingvalue
	sbq.autoSetSettings(settingname, settingvalue)

	sbq.saveSettings()
end

function sbq.changeAnimOverrideSetting(settingname, settingvalue)
	sbq.animOverrideSettings[settingname] = settingvalue
	status.setStatusProperty("speciesAnimOverrideSettings", sbq.animOverrideSettings)
	world.sendEntityMessage(player.id(), "speciesAnimOverrideRefreshSettings", sbq.animOverrideSettings)
	world.sendEntityMessage(player.id(), "animOverrideScale", sbq.animOverrideSettings.scale)
end

function sbq.changePreySetting(settingname, settingvalue)
	sbq.preySettings = status.statusProperty("sbqPreyEnabled") or {}
	sbq.preySettings[settingname] = settingvalue
	status.setStatusProperty("sbqPreyEnabled", sbq.preySettings)
	world.sendEntityMessage(player.id(), "sbqRefreshDigestImmunities")
end

function sbq.getOccupantHolderData()
	sbq.getSpeciesConfig(player.species(), sbq.sbqSettings.global)
	sbq.predatorConfig = sbq.speciesConfig.sbqData
end

function sbq.setSettingsList(list, value)
	for i, setting in ipairs(list) do
		local button = _ENV[setting]
		if button ~= nil then
			button:setChecked(value)
			button:onClick()
		end
	end
end

function sbq.numberBox(textbox, settingsFunc, settingName, settings, overrideSettings, min, max )
	local value = tonumber(textbox.text)
	local isNumber = type(value) == "number"
	if isNumber and (sbq[overrideSettings] or {})[settingName] == nil then
		local newValue = math.min(math.max(value, (min or -math.huge)), (max or math.huge))
		textbox:setText(tostring(newValue))
		sbq[settingsFunc](settingName, newValue)
		sbq.numberBoxColor(textbox, min, max)
		sbq.saveSettings()
	else
		textbox:setText(tostring((sbq[overrideSettings] or {})[settingName] or (sbq[settings] or {})[settingName] or 0))
	end
end
function sbq.numberBoxColor(textbox, min, max)
	local value = tonumber(textbox.text)
	local isNumber = type(value) == "number"
	local color = "FFFFFF"
	if isNumber then
		if type(max) == "number" and value == max
		or type(min) == "number" and value == min
		then
			color = "FFFF00"
		elseif type(max) == "number" and type(min) == "number" then
			if value > min and value < max then
				color = "00FF00"
			end
		end
		if type(max) == "number" and value > max
		or type(min) == "number" and value < min
		then
			color = "FF0000"
		end
	else
		color = "FF0000"
	end
	textbox:setColor(color)
end


local predSettingList = {
	"oralVorePred",
	"tailVorePred",
	"absorbVorePred",
	"navelVorePred",

	"analVorePred",
	"unbirthPred",
	"cockVorePred",
	"breastVorePred",

	"cockInfusionPred",
	"pussyInfusionPred",
	"bellyInfusionPred",
	"breastsInfusionPred",

	"oralVorePredUnwilling",
	"tailVorePredUnwilling",
	"absorbVorePredUnwilling",
	"navelVorePredUnwilling",

	"analVorePredUnwilling",
	"unbirthPredUnwilling",
	"cockVorePredUnwilling",
	"breastVorePredUnwilling",

	"cockInfusionPredUnwilling",
	"pussyInfusionPredUnwilling",
	"bellyInfusionPredUnwilling",
	"breastsInfusionPredUnwilling"
}
local preySettingList = {
	"oralVore",
	"tailVore",
	"absorbVore",
	"navelVore",

	"analVore",
	"unbirth",
	"cockVore",
	"breastVore",

	"cockInfusion",
	"pussyInfusion",
	"bellyInfusion",
	"breastsInfusion"
}
local digestPreyList = {
	"digestAllow", "softDigestAllow", "digestItemDropsAllow",
	"cumDigestAllow", "cumSoftDigestAllow", "cumDigestItemDropsAllow",
	"femcumDigestAllow", "femcumSoftDigestAllow", "femcumDigestItemDropsAllow",
	"milkDigestAllow", "milkSoftDigestAllow", "milkDigestItemDropsAllow"
}
local transformList = {
	"transformAllow",
	"cumTransformAllow",
	"genderswapAllow",
	"eggAllow"
}

function allPred:onClick()
	sbq.setSettingsList(predSettingList, true)
end
function nonePred:onClick()
	sbq.setSettingsList(predSettingList, false)
end

function allPrey:onClick()
	sbq.setSettingsList(preySettingList, true)
end
function nonePrey:onClick()
	sbq.setSettingsList(preySettingList, false)
end
function allDigestPrey:onClick()
	sbq.setSettingsList(digestPreyList, true)
end
function noneDigestPrey:onClick()
	sbq.setSettingsList(digestPreyList, false)
end
function allTtransform:onClick()
	sbq.setSettingsList(transformList, true)
end
function noneTtransform:onClick()
	sbq.setSettingsList(transformList, false)
end

function allKinks:onClick()
	sbq.setSettingsList(predSettingList, true)
	sbq.setSettingsList(preySettingList, true)
	sbq.setSettingsList(digestPreyList, true)
	sbq.setSettingsList(transformList, true)
end
function noneKinks:onClick()
	sbq.setSettingsList(predSettingList, false)
	sbq.setSettingsList(preySettingList, false)
	sbq.setSettingsList(digestPreyList, false)
	sbq.setSettingsList(transformList, false)
	sbq.changeAnimOverrideSetting("scaleMin", 1)
	sbq.changeAnimOverrideSetting("scaleMax", 1)
	pane.dismiss()
end

function mainSettings:onClick()
	player.interact("ScriptPane", { gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:settings" })
	pane.dismiss()
end
function close:onClick()
	pane.dismiss()
end
