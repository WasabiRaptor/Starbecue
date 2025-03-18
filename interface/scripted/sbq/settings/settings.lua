if not _ENV.metagui.inputData.sbq then sb.logInfo("failed to get settings data") return pane.dismiss() end

function init()
	if _ENV.mainSettingsPanel then
		_ENV.mainSettingsPanel:clearChildren()
		local mainSettings = { { type = "label", text = ":mainSettings", inline = true } }
		for _, k in ipairs(sbq.voreConfig.settingsOrder or sbq.gui.settingsOrder) do
			if type(k) == "string" then
				sbq.setupSetting(mainSettings, k)
			end
		end
		if player.isAdmin() and sbq.debug then
			table.insert(mainSettings, {type = "label", text = ":unordered", inline = true})
			for k, v in pairs(sbq.config.defaultSettings) do
				sbq.setupSetting(mainSettings, k)
			end
		end
		_ENV.mainSettingsPanel:addChild({type = "layout", mode = "vertical", children = mainSettings})
	end
	if _ENV.locationTabField then
		local locationSettings = {}
		for _, name in ipairs(sbq.voreConfig.locationOrder or sbq.gui.locationOrder) do
			sbq.setupLocation(name, locationSettings)
		end
		if player.isAdmin() and sbq.debug then
			table.insert(locationSettings, {type = "label", text = ":unordered", inline = true})
			for name, location in pairs(sbq.locations) do
				sbq.setupLocation(name, locationSettings)
			end
		end
		for _, v in ipairs(locationSettings) do
			_ENV.locationTabField:newTab(v)
		end
	end

	if _ENV.mainPrefsPanel then
		local otherVisible = not (sbq.voreConfig.hideOtherSettings or false)
		local preyVisible = not (sbq.voreConfig.hidePreySettings or false)
		local predVisible = not (sbq.voreConfig.hidePredSettings or false)
		local infusePredVisible = not (sbq.voreConfig.hideInfusePredSettings or false)
		local infusePreyVisible = not (sbq.voreConfig.hideInfusePreySettings or false)
		local TFVisible = not (sbq.voreConfig.hideTFsettings or false)
		local sizeVisible = not (sbq.voreConfig.hideSizeSettings or false)

		_ENV.vorePreyPrefsPanel:setVisible(preyVisible)
		_ENV.infusePreyPrefsPanel:setVisible(infusePreyVisible)

		_ENV.transformationPrefsPanel:setVisible(TFVisible)
		_ENV.resistancesPanel:setVisible(preyVisible)
		_ENV.otherPrefsPanel:setVisible(otherVisible)
		_ENV.sizePrefsPanel:setVisible(sizeVisible)

		_ENV.vorePredPrefsPanel:setVisible((sbq.voreConfig.availableVoreTypes or false) and predVisible)
		_ENV.infusePredPrefsPanel:setVisible((sbq.voreConfig.availableInfuseTypes or false) and infusePredVisible)

		for _, voreType in pairs(sbq.gui.voreTypeOrder) do
			_ENV.vorePredPrefsPanel.children[1]:addChild({type = "sbqSetting", groupKey = voreType, groupName = "vorePrefs", setting = voreType.."PredPrefs"})
			_ENV.vorePreyPrefsPanel.children[1]:addChild({type = "sbqSetting", groupKey = voreType, groupName = "vorePrefs", setting = voreType.."PreyPrefs"})
			local widget = _ENV[voreType.."predPrefLayout"]
			if widget then widget:setVisible((sbq.voreConfig.availableVoreTypes or {})[voreType] or false) end
		end
		for _, infuseType in pairs(sbq.gui.infuseTypeOrder) do
			_ENV.infusePredPrefsPanel.children[1]:addChild({type = "sbqSetting", groupKey = infuseType, groupName = "infusePrefs", setting = infuseType.."PredPrefs"})
			_ENV.infusePreyPrefsPanel.children[1]:addChild({type = "sbqSetting", groupKey = infuseType, groupName = "infusePrefs", setting = infuseType.."PreyPrefs"})

			local widget = _ENV[infuseType.."predPrefLayout"]
			if widget then widget:setVisible((sbq.voreConfig.availableInfuseTypes or {})[infuseType] or false) end
		end
		local cockInfusepreyPrefLayout = _ENV.cockInfusepreyPrefLayout
		_ENV.currentScale:setText(tostring(sbq.currentScale))
	end

	sbq.assignSettingValues()
	sbq.refreshSettingVisibility()
end
function uninit()
	if world.entityExists(sbq.entityId()) then
		world.sendEntityMessage(sbq.entityId(), "sbqRefreshSettings")
	end
end
local locationSetup = {}
function sbq.setupLocation(name, list)
	local location = sbq.locations[name]
	if (not location) or locationSetup[name] then return end
	locationSetup[name] = true
	local tabContents = {
		{ mode = "v" },
		{ align = "center",type = "label",text = location.name or (":"..name) }
	}
	local icon
	if root.assetExists("/interface/scripted/sbq/"..name..".png") then
		icon = "/interface/scripted/sbq/"..name..".png"
	end
	local locationTab = {
		id = name,
		icon = icon,
		title = location.name or (":"..name),
		visible = sbq.tableMatches(location.activeSettings, sbq.settings, true) and not location.disabled,
		color = "ff00ff",
		contents = {
			{ type = "scrollArea", scrollDirections = { 0, 1 }, children = {
				{ type = "panel", style = "convex", expandMode = { 2, 2 }, children = tabContents },
			}}
		}
	}

	for _, k in ipairs(location.settingsOrder or sbq.voreConfig.locationSettingsOrder or sbq.gui.locationSettingsOrder) do
		if type(k) == "string" then
			sbq.setupSetting(tabContents, k, "locations", name)
		end
	end
	if player.isAdmin() and sbq.debug then
		table.insert(tabContents, {type = "label", text = ":unordered", inline = true})
		for k, v in pairs(sbq.config.groupedSettings.locations.defaultSettings) do
			sbq.setupSetting(tabContents, k, "locations", name)
		end
	end
	table.insert(list, locationTab)
end

function sbq.setupSetting(parent, setting, group, name)
	local settingIdentifier = sbq.concatStrings(setting, group, name)
	if (not sbq.settingIdentifiers[settingIdentifier]) then
		sbq.settingIdentifiers[settingIdentifier] = {setting, group, name }
		table.insert(parent, {
			type = "sbqSetting",
			id = settingIdentifier,
			setting = setting,
			groupName = group,
			groupKey = name,
			makeLabel = true
		})
	end
end

function sbq.settingVisibility(input, setting, group, name)
	if not input then return true end
	if type(input) == "table" then
		return sbq.tableMatches(sbq.replaceConfigTags(input, {groupKey = name, groupName = group, setting = setting}), sbq.settings, true)
	elseif type(input) == "string" then
		return sbq.widgetScripts[input](setting,group,name)
	end
	return false
end

function sbq.refreshSettingVisibility()
	if _ENV.currentScale then
		_ENV.currentScale.locked = not player.hasItemWithParameter("sbqSizeModifier", true)
	end
	for settingIdentifier, identifier in pairs(sbq.settingIdentifiers) do
		local setting, group, name = table.unpack(identifier)
		local widget = sbq.settingWidgets[settingIdentifier] or _ENV[settingIdentifier]
		local label = _ENV[settingIdentifier .. "Label"]
		local layout = _ENV[settingIdentifier .. "Layout"]
		local panel = _ENV[settingIdentifier .. "Panel"]
		local visible = sbq.settingVisibility(sbq.gui.settingVisibility[setting] or {}, setting, group, name)
		if group and name then
			visible = visible and sbq.settingVisibility((sbq.gui.groupSettingVisibility[group] or {})[setting] or {}, setting, group, name)
		end
		if widget then
			widget:setVisible(visible)
		end
		if label then
			label:setVisible(visible)
		end
		if layout then
			layout:setVisible(visible)
		end
		if panel then
			panel:setVisible(visible)
		end
	end
	for name, location in pairs(sbq.locations) do
		local widget = ((_ENV.locationTabField or {}).tabs or {})[name]
		if widget then
			widget:setVisible(sbq.tableMatches(location.activeSettings, sbq.settings, true) and not location.disabled)
		end
	end
	if sbq.refreshBehaviorTabVisibility then
		sbq.refreshBehaviorTabVisibility()
	end
end

function sbq.assignSettingValues()
	for settingIdentifier, identifier in pairs(sbq.settingIdentifiers) do
		sbq.assignSettingValue(table.unpack(identifier))
	end
end

function sbq.fetchSettingValueAndType(setting, group, name)
	if group and name then
		return sbq.settings[group][name][setting], type(sbq.defaultSettings[group][name][setting])
	else
		return sbq.settings[setting], type(sbq.defaultSettings[setting])
	end
end

function sbq.assignSettingValue(setting, group, name)
	local settingIdentifier = sbq.concatStrings(setting, group, name)
	local widget = sbq.settingWidgets[settingIdentifier] or _ENV[settingIdentifier]
	local locked = sbq.checkLockedSetting(setting, group, name)
	local value, valueType = sbq.fetchSettingValueAndType(setting, group, name)

	if not widget then
		return
	end
	if widget.widgetType == "sbqCheckBox" then
		if valueType == "boolean" then
			widget:setChecked(value)
		else
			widget:selectValue(value)
		end
		widget:setLocked(locked)
	elseif widget.widgetType == "sbqTextBox" then
		if valueType == "table" then
			widget:setText(sb.printJson(value))
		else
			widget:setText(tostring(value))
		end
		widget.locked = locked
	elseif widget.widgetType == "sbqSlider" then
		for i, handle in ipairs(widget.handles) do
			if (handle.setting == setting) and (handle.groupName == group) and (handle.groupKey == name) then
				handle.value = (widget.inverted and (widget.notches[#widget.notches] - value)) or value
				handle.locked = locked
			end
		end
	elseif widget.widgetType == "sbqItemSlot" then
        widget:setItem(value.name and value)
		widget.locked = locked
	end
end

function sbq.widgetScripts.changeSetting(value, setting, group, name)
	local result = sbq.checkInvalidSetting(value, setting, group, name)
	if (result ~= nil) or sbq.checkLockedSetting(setting,group,name) then sbq.playErrorSound() sbq.assignSettingValue(setting, group, name) return false end

	if group and name then
		world.sendEntityMessage(sbq.entityId(), "sbqSetGroupedSetting", group, name, setting, value)
		storage.sbqSettings[group][name][setting] = value
	else
		world.sendEntityMessage(sbq.entityId(), "sbqSetSetting", setting, value)
		storage.sbqSettings[setting] = value
	end
	sbq.refreshSettingVisibility()
end

function sbq.widgetScripts.changeTableSetting(value, setting, group, name)
	local result = sbq.checkInvalidSetting(value, setting, group, name)
	if (result ~= nil) or sbq.checkLockedSetting(setting,group,name) then sbq.playErrorSound() sbq.assignSettingValue(setting, group, name) return false end

	local table = sb.parseJson(value)
	if not table then sbq.playErrorSound() return false end
	if group and name then
		world.sendEntityMessage(sbq.entityId(), "sbqSetGroupedSetting", group, name, setting, table)
		storage.sbqSettings[group][name][setting] = table
	else
		world.sendEntityMessage(sbq.entityId(), "sbqSetSetting", setting, table)
		storage.sbqSettings[setting] = table
	end
	sbq.refreshSettingVisibility()
end

function sbq.importSettings(newSettings)
	storage.sbqSettings = sb.jsonMerge(storage.sbqSettings, newSettings)
	sbq.sbqSettings = storage.sbqSettings
	world.sendEntityMessage(sbq.entityId(), "sbqImportSettings", newSettings)
	sbq.setupSettingMetatables(world.entityType(sbq.entityId()))
	sbq.assignSettingValues()
	sbq.refreshSettingVisibility()
end

function sbq.widgetScripts.makeMainEffectButtons(param)
	local effectButtons = {
		{mode = "h", spacing = 0, expandMode = {0,0}}
	}
	local layout = {
		type = "panel",
		id = sbq.widgetSettingIdentifier(param).."Panel",
		expandMode = { 1, 0 },
		children = param.makeLabel and {
			{ mode = "v", expandMode = { 1, 0 } },
			{ type = "label", text = ":" .. param.setting },
			effectButtons } or effectButtons,
		makeLabel = false
	}
	local location = sbq.locations[param.groupKey]
	for _, k in ipairs(sbq.gui.mainEffectOrder) do
		if (location[param.setting] or {})[k] then
			local visible = true
			local result = sbq.checkInvalidSetting(k, param.setting, param.groupName, param.groupKey)
			if result == nil then
				local toolTip = sbq.getString(location.name or (":"..param.groupKey))..": "..sbq.getString(":"..k)
				local icon
				for _, status in ipairs(location[param.setting][k]) do

					if type(status) == "string" then
						local effectConfig = (root.effectConfig(status) or {}).effectConfig or {}
						if effectConfig.description then
							toolTip = toolTip.."\n"..(sbq.strings[effectConfig.description] or effectConfig.description)
						end
						if effectConfig.checkBoxIcon and not icon then
							icon =  effectConfig.checkBoxIcon
						end
					elseif status.icon and not icon then
						icon = status.icon
					end
				end
				table.insert(effectButtons, sb.jsonMerge(param,{type = "sbqCheckBox", script = "changeSetting", visible = visible, icon = icon, toolTip = toolTip, value = k, radioGroup = param.setting }))
			end
		end
	end
	return sb.jsonMerge(param, layout)
end
function sbq.widgetScripts.makeSecondaryEffectButtons(param)
	local effectButtons = {
		{mode = "h", spacing = 0, expandMode = {0,0}}
	}
	sbq.settingIdentifiers[sbq.widgetSettingIdentifier(param)] = {param.setting, param.groupName, param.groupKey}
	local layout = {
		type = "panel",
		id = sbq.widgetSettingIdentifier(param).."Panel",
		expandMode = { 1, 0 },
		children = param.makeLabel and {
			{ mode = "v", expandMode = { 1, 0 } },
			{ type = "label", text = ":" .. param.setting },
			effectButtons,
		} or effectButtons,
		makeLabel = false
	}
	local location = sbq.locations[param.groupKey]
	local effects = location[param.setting]
	if not effects then return false end
	for _, k in ipairs(sbq.gui.secondaryEffectOrder) do
		local result = sbq.checkInvalidSetting("true", param.setting, param.groupName, param.groupKey)
		if (effects or {})[k] and (result == nil) then
			local toolTip = sbq.getString(location.name or (":"..param.groupKey))..": "..sbq.getString(":"..k)
			local icon
			local status
			for _, v in ipairs(effects[k]) do
				if type(v) == "string" then
					status = v
					local effectConfig = (root.effectConfig(status) or {}).effectConfig or {}
					if effectConfig.description then
						toolTip = toolTip.."\n"..(sbq.strings[effectConfig.description] or effectConfig.description)
					end
					if effectConfig.checkBoxIcon and not icon then
						icon =  effectConfig.checkBoxIcon
					end

				end
			end
			table.insert(effectButtons, sb.jsonMerge(
				param,
				sbq.gui.secondaryEffectButton[k] and sbq.replaceConfigTags(sbq.gui.secondaryEffectButton[k], {groupKey = param.groupKey, groupName = param.groupName, setting = param.setting, icon = icon, toolTip = toolTip} )
				or { type = "sbqCheckBox", script = "changeSetting", setting = k, icon = icon, toolTip = toolTip }
			))
		end
	end
	return sb.jsonMerge(param, layout)
end

function sbq.widgetScripts.makeInfuseSlots(param)
	local infuseSlots = {}
	sbq.settingIdentifiers[sbq.widgetSettingIdentifier(param)] = {param.setting, param.groupName, param.groupKey}
	local layout = {
		type = "panel",
		id = sbq.widgetSettingIdentifier(param).."Panel",
		expandMode = { 1, 0 },
		children = { { mode = "v", expandMode = { 1, 0 } }, { type = "label", text = ":" .. param.setting }, { type = "sbqItemGrid", autoInteract = true, slots = infuseSlots} },
		makeLabel = false
	}
	local canInfuse = false
	for _, infuseType in pairs(sbq.gui.infuseTypeOrder) do
		if (sbq.voreConfig.availableInfuseTypes or {})[infuseType] then
			canInfuse = true
			local glyph = "/interface/scripted/sbq/" .. infuseType .. "Slot.png"
			local item = sbq.settings[param.setting][infuseType].item
			local slot = {
				item = item.name and item,
				glyph = root.assetExists(glyph) and glyph,
				toolTip = string.format("%s %s", sbq.strings[infuseType], sbq.strings.slot),
				setting = "item",
				groupName = param.setting,
				groupKey = infuseType,
				script = "changeSetting",
				acceptScript = "infuseSlotAccepts"
			}
			sbq.settingIdentifiers[sbq.widgetSettingIdentifier(slot)] = { slot.setting, slot.groupName, slot.groupKey }
			table.insert(infuseSlots, slot)
		end
	end
	if not canInfuse then return false end

	return sb.jsonMerge(param, layout)
end

function sbq.widgetScripts.infuseSlotAccepts(w, item)
	if w.locked then return false end
	if not item then return true end
	if sbq.query(item, {"parameters", "npcArgs", "npcParam", "scriptConfig", "sbqSettings", "infusePrefs", w.groupKey, "prey"}) then return true end
	sbq.playErrorSound()
	player.queueUIMessage(sbq.getString(":action_targetSettingsMismatch"))
	return false
end

function sbq.widgetScripts.changeScale(value)
	world.sendEntityMessage(sbq.entityId(), "sbqScale", value)
end

function sbq.widgetScripts.visualMinMax(param)
	param.type = "sbqTextBox"
	param.min = 0
	local location = sbq.locations[param.groupKey]
	param.max = location.maxSize
	param.settingType = "number"
	if storage.sbqSettings.locations[param.groupKey][param.setting] >= location.maxSize then
		storage.sbqSettings.locations[param.groupKey][param.setting] = location.maxSize
	end
	return param
end

function sbq.widgetScripts.fillControlVisible(setting, group, name)
	local location = sbq.locations[name]
	if (not location.maxSize) or (location.maxSize == math.huge) or (not location.struggleSizes) or (#location.struggleSizes < 2) then
		return false
	end
	return true
end
function sbq.widgetScripts.infusedSizeVisible(setting, group, name)
	return sbq.widgetScripts.fillControlVisible(setting, group, name) and sbq.locations[name].infuseSize
end
function sbq.widgetScripts.infusedFadeVisible(setting, group, name)
	local location = sbq.locations[name]
	return location.infuseColors
end
function sbq.widgetScripts.infusedVisible(setting, group, name)
	local location = sbq.locations[name]
	if (not location.infuseType) or (not sbq.settings.infusePrefs[location.infuseType].pred) or (not sbq.query(sbq.settings.infuseSlots[location.infuseType], {"item", "name"})) then
		return false
	end
	return true
end

function sbq.widgetScripts.makeRecentlyDigested(param)
	if not storage.sbqSettings.recentlyDigested[1] then return false end
	local slots = {}
	local layout = {
		type = "panel",
		id = sbq.widgetSettingIdentifier(param).."Panel",
		expandMode = { 1, 0 },
		children = {
			{ mode = "v", expandMode = { 1, 0 } },
			{ type = "label", text = ":" .. param.setting },
			{
				{ mode = "h", expandMode = { 0, 0 } },
				{ type = "sbqItemGrid", id = "recentlyDigestedItemGrid", autoInteract = true, slots = slots },
				{ type = "sbqIconButton", id = "clearRecentlyDigested", toolTip = ":clearRecentlyDigestedTip", script = "clearRecentlyDigested", image = "/interface/x.png", hoverImage = "/interface/xhover.png", pressImage = "/interface/xpress.png"}
            },
            { type = "sbqButton", id = "collapseEssenceStacksDigested", caption = ":collapseEssenceStacks", toolTip = ":collapseEssenceStacksTip", script = "collapseEssenceStacks" }
		},
		makeLabel = false
	}
	for _, item in ipairs(storage.sbqSettings.recentlyDigested) do
		local slot = {
			item = item.name and item,
		}
		table.insert(slots, slot)
	end
	return sb.jsonMerge(param, layout)
end
function sbq.widgetScripts.clearRecentlyDigested()
    sbq.widgetScripts.changeSetting(jarray(), "recentlyDigested")
end
function sbq.widgetScripts.collapseEssenceStacks()
	player.setScriptContext("starbecue")
	player.callScript("sbq.collapseEssenceStacks")
end

function sbq.widgetScripts.dropDownSetting(_, setting, group, name)
	local value, valueType = sbq.fetchSettingValueAndType(setting, group, name)
	local locked = sbq.checkLockedSetting(setting, group, name)
	local options = {}
	if not sbq.voreConfig.selectValues[setting] then
		sbq.playErrorSound()
	end
	for _, v in ipairs(sbq.voreConfig.selectValues[setting]) do
		local result = sbq.checkInvalidSetting(value, setting, group, name)
		if result == nil then
			if sbq.gui.dropDownOptions[v] then
				table.insert(options, {
					sbq.replaceConfigTags(sbq.gui.dropDownOptions[v][1], {selectedDirectives = ((value == v) and "?border=1;00FF00FF;00FF0088") or ""}),
					function()
						if not locked then
							sbq.widgetScripts.changeSetting(v, setting, group, name)
						end
					end,
					sbq.gui.dropDownOptions[v][2]
				})
			else
				table.insert(options, {
					((value == v and "^green;") or "") .. (sbq.getString(":" .. v)),
					function()
						if not locked then
							sbq.widgetScripts.changeSetting(v, setting, group, name)
						end
					end
				})
			end
		end
	end
	_ENV.metagui.dropDownMenu(options, table.unpack(sbq.gui.dropDownArgs[setting] or {}))
end
