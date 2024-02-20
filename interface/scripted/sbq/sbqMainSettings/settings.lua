
function init()
	mainSettingsPanel:clearChildren()
	local mainSettings = { { type = "label", text = ":mainSettings", inline = true } }
	for _, k in ipairs(sbq.voreConfig.settingsOrder or sbq.gui.settingsOrder) do
		sbq.setupSetting(mainSettings, k, sbq.settings[k], nil, sbq.overrideSettings[k])
	end
	if player.isAdmin() then
		table.insert(mainSettings, {type = "label", text = ":unordered", inline = true})
		for k, v in pairs(sbq.config.defaultSettings) do
			sbq.setupSetting(mainSettings, k, sbq.settings[k], nil, sbq.overrideSettings[k])
		end
	end
	mainSettingsPanel:addChild({type = "layout", mode = "vertical", children = mainSettings})

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

	for _, settingIdentifier in ipairs(sbq.getWidget) do
		sbq.settingWidgets[settingIdentifier] = _ENV[settingIdentifier]
	end
end
local locationSetup = {}
function sbq.setupLocation(name, list)
	local location = sbq.locations[name]
	if (not location) or locationSetup[name] then return end
	locationSetup[name] = true
	local locationPanel = {
		id = name.."Panel",
		type = "panel",
		style = "convex",
		expandMode = { 1, 0 },
		children = {
			{
				inline = true,
				type = "label",
				text = location.name or (":"..name)
			}
		}
	}
	for _, k in ipairs(location.settingsOrder or sbq.voreConfig.locationSettingsOrder or sbq.gui.locationSettingsOrder) do
		sbq.setupSetting(locationPanel.children, k, sbq.settings.locations[name][k], name, sbq.overrideSettings.locations[name][k])
	end
	if player.isAdmin() then
		table.insert(locationPanel.children, {type = "label", text = ":unordered", inline = true})
		for k, v in pairs(sbq.config.defaultLocationSettings) do
			sbq.setupSetting(locationPanel.children, k, sbq.settings.locations[name][k], name, sbq.overrideSettings.locations[name][k])
		end
	end
	table.insert(list, locationPanel)
end


function sbq.setupSetting(parent, setting, value, location, locked)
	local settingIdentifier = (location or "")..setting
	if not (sbq.settingWidgets[settingIdentifier] or sbq.settingsSetup[settingIdentifier])  then
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
					text = ":"..setting
				}
			}
		}
		sbq.settingsSetup[settingIdentifier] = true

		table.insert(sbq.getWidget, settingIdentifier)
		table.insert(parent, layout)
	elseif not sbq.settingsSetup[settingIdentifier] then
		local widget = sbq.settingWidgets[settingIdentifier]
		if widget.widgetType == "iconCheckBox" and type(value) == "boolean" then
			widget:setChecked(value)
		elseif widget.widgetType == "sbqTextBox" and type(value) == "table" then
			widget:setText(sb.printJson(value))
		elseif widget.widgetType == "sbqTextBox" then
			widget:setText(tostring(value))
		elseif widget.widgetType == "sbqSlider" then
			for i, handle in ipairs(widget.handles) do
				if (handle.setting == setting) and (handle.location == location) then
					handle.value = (widget.inverted and (widget.notches[#widget.notches] - value)) or value
					handle.locked = locked
				end
			end
		end
		sbq.settingsSetup[settingIdentifier] = true
	end
end
