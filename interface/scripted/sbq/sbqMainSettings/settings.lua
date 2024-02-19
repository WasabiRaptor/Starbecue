
function init()
    mainSettingsPanel:clearChildren()
    local mainSettings = { { type = "label", text = ":mainSettings", inline = true } }
	for _, k in ipairs(sbq.voreConfig.settingsOrder or sbq.config.settingsOrder) do
		sbq.setupSetting(mainSettings, k, storage.sbqSettings[k])
    end
    if not sbq.voreConfig.settingsOrder then
		table.insert(mainSettings, {type = "label", text = ":unordered", inline = true})
		for k, v in pairs(sbq.config.defaultSettings) do
			sbq.setupSetting(mainSettings, k, storage.sbqSettings[k])
		end
	end
	mainSettingsPanel:addChild({type = "layout", mode = "vertical", children = mainSettings})

    locationSettingsPanel:clearChildren()
    local locationSettings = {}
	for _, name in ipairs(sbq.voreConfig.locationOrder or sbq.config.locationOrder) do
		sbq.setupLocation(name, locationSettings)
    end
	if not sbq.voreConfig.locationOrder then
		table.insert(locationSettings, {type = "label", text = ":unordered", inline = true})
		for name, location in pairs(sbq.locations) do
			sbq.setupLocation(name, locationSettings)
		end
	end
    locationSettingsPanel:addChild({ type = "layout", mode = "vertical", children = locationSettings })

	for _, settingIdentifier in ipairs(getWidget) do
		settingWidgets[settingIdentifier] = _ENV[settingIdentifier]
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
				text = location.name
			}
		}
	}
	for _, k in ipairs(location.settingsOrder or sbq.voreConfig.locationSettingsOrder or sbq.config.locationSettingsOrder) do
		sbq.setupSetting(locationPanel.children, k, storage.sbqSettings.locations[name][k], name)
    end
    if not (location.settingsOrder or sbq.voreConfig.locationSettingsOrder)then
		table.insert(locationPanel.children, {type = "label", text = ":unordered", inline = true})
        for k, v in pairs(sbq.config.defaultLocationSettings) do
			sbq.setupSetting(locationPanel.children, k, storage.sbqSettings.locations[name][k], name)
		end
	end
	table.insert(list, locationPanel)
end


function sbq.setupSetting(parent, setting, value, location)
	local settingType = type(value)
	local settingIdentifier = (location or "")..setting
    if not (settingWidgets[settingIdentifier] or settingSetup[settingIdentifier])  then
        local layout = {
			id = settingIdentifier.."Layout",
			type = "layout",
            mode = "horizontal",
			children = {}
        }
        if settingType == "boolean" then
			table.insert(getWidget, settingIdentifier)
			table.insert(layout.children, {
                type = "iconCheckBox",
				id = settingIdentifier,
				setting = setting,
				checked = value,
				script = "changeSetting",
				toolTip = ":" .. setting .. "Tip",
				location = location
			})
        elseif settingType == "number" or settingType == "string" then
			table.insert(getWidget, settingIdentifier)
			table.insert(layout.children, {
                type = "sbqTextBox",
				id = settingIdentifier,
				setting = setting,
                text = tostring(value),
				settingType = settingType,
				script = "changeSetting",
				toolTip = ":" .. setting .. "Tip",
				location = location
            })
		elseif settingType == "table" then
			table.insert(getWidget, settingIdentifier)
			table.insert(layout.children, {
                type = "sbqTextBox",
				id = settingIdentifier,
				setting = setting,
                text = sb.printJson(value),
				settingType = settingType,
				script = "changeTableSetting",
				toolTip = ":" .. setting .. "Tip",
				location = location
            })
        end
		table.insert(layout.children, {
			type = "label",
			text = ":"..setting

        })
        settingSetup[settingIdentifier] = true
		table.insert(parent, layout)
    elseif not settingSetup[settingIdentifier] then
        local widget = settingWidgets[settingIdentifier]
		if settingType == "boolean" then
            widget:setChecked(value)
        elseif settingType == "number" or settingType == "string" then
			widget:setText(tostring(value))
		end
	end
end
