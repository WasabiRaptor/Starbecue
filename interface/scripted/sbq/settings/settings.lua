if not _ENV.metagui.inputData.sbq then sb.logInfo("failed to get settings data") return pane.dismiss() end

local prefTemplate = root.assetJson("/interface/scripted/sbq/settings/prefTemplate.config")

function init()
	if _ENV.mainSettingsPanel then
		_ENV.mainSettingsPanel:clearChildren()
		local mainSettings = { { type = "label", text = ":mainSettings", inline = true } }
		for _, k in ipairs(sbq.voreConfig.settingsOrder or sbq.gui.settingsOrder) do
			if type(k) == "string" then
				sbq.setupSetting(mainSettings, k)
			end
		end
		if player.isAdmin() then
			table.insert(mainSettings, {type = "label", text = ":unordered", inline = true})
			for k, v in pairs(sbq.config.defaultSettings) do
				sbq.setupSetting(mainSettings, k)
			end
		end
		_ENV.mainSettingsPanel:addChild({type = "layout", mode = "vertical", children = mainSettings})
    end
	if _ENV.locationSettingsPanel then
		_ENV.locationSettingsPanel:clearChildren()
		local locationSettings = {}
		for _, name in ipairs(sbq.voreConfig.locationOrder or sbq.gui.locationOrder) do
			sbq.setupLocation(name, locationSettings)
		end
		if player.isAdmin() then
			table.insert(locationSettings, {type = "label", text = ":unordered", inline = true})
			for name, location in pairs(sbq.locations) do
				sbq.setupLocation(name, locationSettings)
			end
		end
		_ENV.locationSettingsPanel:addChild({ type = "layout", mode = "vertical", children = locationSettings })
		for name, location in pairs(sbq.locations) do
			local collapseButton = _ENV[name .. "CollapseButton"]
			local collapseLayout = _ENV[name .. "CollapseLayout"]
			if collapseButton and collapseLayout then
				function collapseButton:onClick()
					collapseLayout:setVisible(self.checked)
				end
			end
		end
    end

    for _, voreType in pairs(sbq.gui.voreTypeOrder) do
		_ENV.vorePredPrefsPanel.children[1]:addChild(sbq.replaceConfigTags(prefTemplate, {groupKey = voreType, groupName = "vorePrefs", setting = "pred"}))
		_ENV.vorePreyPrefsPanel.children[1]:addChild(sbq.replaceConfigTags(prefTemplate, {groupKey = voreType, groupName = "vorePrefs", setting = "prey"}))

		local widget = _ENV[voreType.."predPrefLayout"]
        if widget and sbq.voreConfig.availableVoreTypes then
			widget:setVisible(sbq.voreConfig.availableVoreTypes[voreType] or false)
		end
    end
    for _, infuseType in pairs(sbq.gui.infuseTypeOrder) do
		_ENV.infusePredPrefsPanel.children[1]:addChild(sbq.replaceConfigTags(prefTemplate, {groupKey = infuseType, groupName = "infusePrefs", setting = "pred"}))
		_ENV.infusePreyPrefsPanel.children[1]:addChild(sbq.replaceConfigTags(prefTemplate, {groupKey = infuseType, groupName = "infusePrefs", setting = "prey"}))

		local widget = _ENV[infuseType.."predPrefLayout"]
		if widget and sbq.voreConfig.availableInfuseTypes then
			widget:setVisible(sbq.voreConfig.availableInfuseTypes[infuseType] or false)
		end
    end
	_ENV.currentScale:setText(tostring(sbq.currentScale))

    sbq.assignSettingValues()
	sbq.refreshSettingVisibility()
end
local locationSetup = {}
function sbq.setupLocation(name, list)
	local location = sbq.locations[name]
	if (not location) or locationSetup[name] then return end
    locationSetup[name] = true

	local locationPanel = {
		id = name.."LocationPanel",
		type = "panel",
        style = "convex",
		visible = sbq.tableMatches(location.activeSettings, sbq.settings, true),
		expandMode = { 1, 0 },
        children = {
            {
				{
                    type = "sbqCheckBox",
					id = name.."CollapseButton"
				},
				{
					align = "center",
					type = "label",
					text = location.name or (":"..name)
				}
            },
            { type = "panel", style = "flat", children = {
                { type = "layout", id = name .. "CollapseLayout", mode = "vertical", visible = false, children = {
				}}
			}}
		}
	}
    for _, k in ipairs(location.settingsOrder or sbq.voreConfig.locationSettingsOrder or sbq.gui.locationSettingsOrder) do
		if type(k) == "string" then
			sbq.setupSetting(locationPanel.children[2].children[1].children, k, "locations", name)
		end
	end
	if player.isAdmin() then
		table.insert(locationPanel.children[2].children[1].children, {type = "label", text = ":unordered", inline = true})
		for k, v in pairs(sbq.config.groupedSettings.locations.defaultSettings) do
			sbq.setupSetting(locationPanel.children[2].children[1].children, k, "locations", name)
		end
	end
	table.insert(list, locationPanel)
end

function sbq.setupSetting(parent, setting, group, name)
    local settingIdentifier = sbq.concatStrings(setting, group, name)
    sbq.settingIdentifiers[settingIdentifier] = {setting, group, name }
    if (sbq.settingWidgets[settingIdentifier] == nil) then
		sbq.settingWidgets[settingIdentifier] = false
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

function sbq.refreshSettingVisibility()
	_ENV.currentScale.locked = not player.hasItemWithParameter("sbqSizeModifier", true)
	for settingIdentifier, widget in pairs(sbq.settingWidgets) do
        local setting, group, name = table.unpack(sbq.settingIdentifiers[settingIdentifier])
        local label = _ENV[settingIdentifier .. "Label"]
		local layout = _ENV[settingIdentifier .. "Layout"]
        local panel = _ENV[settingIdentifier .. "Panel"]
		local visible = sbq.tableMatches( sbq.gui.settingVisibility[setting] or {}, sbq.settings, true)
		if group and name then
			visible = visible and sbq.tableMatches((sbq.gui.groupSettingVisibility[group] or {})[setting] or {}, sbq.settings[group][name], true)
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
        local widget = _ENV[name .. "LocationPanel"]
		if widget then
			widget:setVisible(sbq.tableMatches(location.activeSettings, sbq.settings, true))
		end
    end
	if sbq.refreshBehaviorTabVisibility then
		sbq.refreshBehaviorTabVisibility()
	end
end

function sbq.assignSettingValues()
    for settingIdentifier, widget in pairs(sbq.settingWidgets) do
		sbq.assignSettingValue(table.unpack(sbq.settingIdentifiers[settingIdentifier]))
	end
end

function sbq.assignSettingValue(setting, group, name)
    local settingIdentifier = sbq.concatStrings(setting, group, name)
	local widget = sbq.settingWidgets[settingIdentifier]
	local value = sbq.settings[setting]
	local locked = sbq.overrideSettings[setting]
	if group and name then
		value = sbq.settings[group][name][setting]
		locked = ((sbq.overrideSettings[group] or {})[name] or {})[setting]
	end
    local valueType = type(value)
    if not widget then
		return
	end
	if widget.widgetType == "sbqCheckBox" then
		if valueType == "boolean" then
			widget:setChecked(value)
		else
			widget:selectValue(value)
        end
		widget.locked = locked
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
	end
end

function sbq.widgetScripts.changeSetting(value, setting, group, name)
	local result = ((sbq.voreConfig.invalidSettings or {})[setting] or {})[tostring(value)] or ((group and name) and ((((sbq.voreConfig.invalidSettings or {})[group] or {})[name] or {})[setting] or {})[tostring(value)])
	if result then pane.playSound("/sfx/interface/clickon_error.ogg") sbq.assignSettingValue(setting, group, name) return false end

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
	local result = ((sbq.voreConfig.invalidSettings or {})[setting] or {})[tostring(value)] or ((group and name) and ((((sbq.voreConfig.invalidSettings or {})[group] or {})[name] or {})[setting] or {})[tostring(value)])
	if result then pane.playSound("/sfx/interface/clickon_error.ogg") sbq.assignSettingValue(setting, group, name) return false end

	local table = sb.parseJson(value)
	if not table then pane.playSound("/sfx/interface/clickon_error.ogg") return false end
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
    local layout = { type = "panel", children = {{mode = "h"}} }
    local location = sbq.locations[param.groupKey]
    for _, k in ipairs(sbq.gui.mainEffectOrder) do
        if (location.mainEffect or {})[k] then
			local visible = true
			local result = ((sbq.voreConfig.invalidSettings or {}).mainEffect or {})[tostring(k)] or ((((sbq.voreConfig.invalidSettings or {}).locations or {})[param.groupKey] or {}).mainEffect or {})[tostring(k)]
			if result ~= nil then
				visible = false
			end
			local toolTip = sbq.strings[k] or k
			local icon
            for _, status in ipairs(location.mainEffect[k]) do
                if type(status) == "string" then

                    local effectConfig = (root.effectConfig(status) or {}).effectConfig or {}
					if effectConfig.description then
						toolTip = toolTip.."\n"..(sbq.strings[effectConfig.description] or effectConfig.description)
                    end
					if effectConfig.checkBoxIcon and not icon then
						icon =  effectConfig.checkBoxIcon
					end
				end
            end
			table.insert(layout.children, sb.jsonMerge(param,{type = "sbqCheckBox", script = "changeSetting", visible = visible, icon = icon, toolTip = toolTip, value = k, radioGroup = "mainEffect" }))
		end
    end

	return sb.jsonMerge(param, layout)
end

function sbq.widgetScripts.changeScale(value)
	world.sendEntityMessage(sbq.entityId(), "sbqScale", value)
end
