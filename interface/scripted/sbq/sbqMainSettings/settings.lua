
function init()
	if mainSettingsPanel then
		mainSettingsPanel:clearChildren()
		local mainSettings = { { type = "label", text = ":mainSettings", inline = true } }
		for _, k in ipairs(sbq.voreConfig.settingsOrder or sbq.gui.settingsOrder) do
			if type(k) == "string" then
				sbq.setupSetting(mainSettings, k, sbq.settings[k], nil, sbq.overrideSettings[k])
			else
				table.insert(mainSettings, k)
				for _, setting in ipairs(k.settingsSetup or {}) do
					sbq.settingWidgets[setting] = {}
				end
			end
		end
		if player.isAdmin() then
			table.insert(mainSettings, {type = "label", text = ":unordered", inline = true})
			for k, v in pairs(sbq.config.defaultSettings) do
				sbq.setupSetting(mainSettings, k, sbq.settings[k], nil, sbq.overrideSettings[k])
			end
		end
		mainSettingsPanel:addChild({type = "layout", mode = "vertical", children = mainSettings})
    end
	if locationSettingsPanel then
		locationSettingsPanel:clearChildren()
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
		locationSettingsPanel:addChild({ type = "layout", mode = "vertical", children = locationSettings })
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
		visible = sbq.tableMatches(location.activeSettings or {}, sbq.settings, true),
		expandMode = { 1, 0 },
        children = {
            {
				{
                    type = "iconCheckBox",
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
			sbq.setupSetting(locationPanel.children[2].children[1].children, k, sbq.settings.locations[name][k], name, sbq.overrideSettings.locations[name][k])
        else
            table.insert(locationPanel.children[2].children[1].children, sb.jsonMerge(k, { location = location }))
            for _, setting in ipairs(k.settingsSetup or {}) do
				local settingIdentifier = (name or "") .. setting
				sbq.settingWidgets[settingIdentifier] = {}
			end
		end
	end
	if player.isAdmin() then
		table.insert(locationPanel.children[2].children[1].children, {type = "label", text = ":unordered", inline = true})
		for k, v in pairs(sbq.config.defaultLocationSettings) do
			sbq.setupSetting(locationPanel.children[2].children[1].children, k, sbq.settings.locations[name][k], name, sbq.overrideSettings.locations[name][k])
		end
	end
	table.insert(list, locationPanel)
end

function sbq.setupSetting(parent, setting, value, location, locked)
    local settingIdentifier = (location or "") .. setting
	sbq.settingIdentifiers[settingIdentifier] = {setting, location}
	if (sbq.settingWidgets[settingIdentifier] == nil) then
		local layout = {
			id = settingIdentifier.."Layout",
			type = "layout",
			mode = "horizontal",
			children = {
				{
					type = "sbqSetting",
					id = settingIdentifier,
					setting = setting,
					location = location
				},
				{
					type = "label",
                    text = ":" .. setting,
					id = settingIdentifier.."Label"
				}
			}
        }
		sbq.settingWidgets[settingIdentifier] = {}
		table.insert(parent, layout)
	end
end

function sbq.refreshSettingVisibility()
	for settingIdentifier, widget in pairs(sbq.settingWidgets) do
        local setting, location = table.unpack(sbq.settingIdentifiers[settingIdentifier])
        local label = _ENV[settingIdentifier .. "Label"]
		local layout = _ENV[settingIdentifier .. "Layout"]
		local panel = _ENV[settingIdentifier .. "Panel"]
		local visibilityCheck = sbq.gui.settingVisibility[setting]
		if location then
			visibilityCheck = (sbq.gui.locationSettingVisibility[location] or {})[setting] or visibilityCheck
        end

        if visibilityCheck then
			visible = sbq.tableMatches(visibilityCheck, sbq.settings, true)
            widget:setVisible(visible)
			widget:queueRedraw()
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
    end
	for name, location in pairs(sbq.locations) do
        local widget = _ENV[name .. "LocationPanel"]
		if widget then
			widget:setVisible(sbq.tableMatches(location.activeSettings or {}, sbq.settings, true))
		end
	end
end

function sbq.assignSettingValues()
    for settingIdentifier, widget in pairs(sbq.settingWidgets) do
        local setting, location = table.unpack(sbq.settingIdentifiers[settingIdentifier] )
		sbq.assignSettingValue(setting,location)
	end
end

function sbq.assignSettingValue(setting, location)
    local settingIdentifier = (location or "") .. setting
	local widget = sbq.settingWidgets[settingIdentifier]
	local value = sbq.settings[setting]
	local locked = sbq.overrideSettings[setting]
	if location then
		value = sbq.settings.locations[location][setting]
		locked = sbq.overrideSettings.locations[location][setting]
	end
	local valueType = type(value)
	if widget.widgetType == "iconCheckBox" then
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
			if (handle.setting == setting) and (handle.location == location) then
				handle.value = (widget.inverted and (widget.notches[#widget.notches] - value)) or value
				handle.locked = locked
			end
		end
	end
end
