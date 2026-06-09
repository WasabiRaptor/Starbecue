local worldOverrideSettings = sb.jsonMerge(world.getProperty("sbqOverrideSettings"), {
	any = {},
	npc = {},
	player = {},
	monster = {},
	object = {}
})
local globalOverrideSettings = sb.jsonMerge(root.getConfigurationPath("sbq.overrideSettings"),{
	any = {},
	npc = {},
	player = {},
	monster = {},
	object = {}
})
local worldInvalidSettings = sb.jsonMerge(world.getProperty("sbqInvalidSettings"),{
	any = {},
	npc = {},
	player = {},
	monster = {},
	object = {}
})
local globalInvalidSettings = sb.jsonMerge(root.getConfigurationPath("sbq.invalidSettings"),{
	any = {},
	npc = {},
	player = {},
	monster = {},
	object = {}
})
if not (player.isAdmin() or (player.id() == world.mainPlayer())) then
	_ENV.mainTabField.tabs.world:setVisible(false)
end
local inactiveLayout = root.assetData("/interface/scripted/sbq/globalConfig/inactiveLayout.config")
local booleanLayout = root.assetData("/interface/scripted/sbq/globalConfig/booleanLayout.config")
local numberLayout = root.assetData("/interface/scripted/sbq/globalConfig/numberLayout.config")
local jsonLayout = root.assetData("/interface/scripted/sbq/globalConfig/jsonLayout.config")

local settingsLists = {
	any = {},
	npc = {},
	player = {},
	monster = {},
	object = {}
}
local defaultSettings = {
	any = {},
	npc = {},
	player = {},
	monster = {},
	object = {}

}
for k, _ in pairs(settingsLists) do
	defaultSettings[k] = sb.jsonMerge(sbq.config.defaultSettings.any, sbq.config.defaultSettings[k])
	for setting, _ in pairs(defaultSettings[k]) do
		table.insert(settingsLists[k], setting)
	end
	table.sort(settingsLists[k], function(a,b)
		return a < b
	end)

end

local settingGroups = {}

function init()
	searchSettings()
end


function searchSettings()
	local searchText = _ENV.overridesSearchTextbox.text
	local overrideType = _ENV.mainTabField.currentTab.id
	local entityType = _ENV.entityTabField.currentTab.id
	_ENV.mainScrollArea:clearChildren()
	for _, setting in pairs(settingsLists[entityType]) do
		if (searchText == "") or setting:find(searchText) or sbq.getString(":"..setting):find(searchText) then

			local newLayout = _ENV.mainScrollArea:addChild({
				type = "layout",
				mode = "v",
				expandMode = {1,0},
				children = {}
			})
			setupOverrideLayout(newLayout, overrideType, entityType, setting)
		end
	end
end

function setupOverrideLayout(layout, overrideType, entityType, setting, group, groupKey)
	local overrideSettings
	local invalidSettings
	if overrideType == "global" then
		overrideSettings = globalOverrideSettings
		invalidSettings = globalInvalidSettings
	elseif overrideType == "world" then
		overrideSettings = worldOverrideSettings
		invalidSettings = worldInvalidSettings
	end
	local settingId = (group and (group..".") or "")..(groupKey and (groupKey..".") or "")..setting
	local settingType
	local overrideValue
	local invalidValueMap
	if group and groupKey then
		overrideValue = ((overrideSettings[entityType][group] or {})[groupKey] or {})[setting]
		invalidValueMap = ((invalidSettings[entityType][group] or {})[groupKey] or {})[setting]
		settingType = type(defaultSettings[entityType][group][groupKey][setting])
	else
		overrideValue = overrideSettings[entityType][setting]
		invalidValueMap = invalidSettings[entityType][setting]
		settingType = type(defaultSettings[entityType][setting])
	end
	local function parseLayout(input)
		return sb.parseJson(sb.replaceTags(input, {
			setting = setting,
			settingId = settingId,
			overrideType = overrideType,
			entityType = entityType
		}))
	end
	local function setOverrideValue(value)
		local updated
		if group and groupKey then
			updated = overrideSettings[entityType][group][groupKey][setting] ~= value
			overrideSettings[entityType][group][groupKey][setting] = value
		else
			updated = overrideSettings[entityType][setting] ~= value
			overrideSettings[entityType][setting] = value
		end
		if updated then
			if overrideType == "world" then
				world.setProperty("sbqOverrideSettings", worldInvalidSettings)
			elseif overrideType == "global" then
				root.setConfigurationPath("sbq.overrideSettings", globalInvalidSettings)
			end
		end
	end
	local function setInvalidMapping(invalidValue, value)
		local updated
		if group and groupKey then
			updated = invalidSettings[entityType][group][groupKey][setting][invalidValue] ~= value
			invalidSettings[entityType][group][groupKey][setting][invalidValue] = value
		else
			updated = invalidSettings[entityType][setting][invalidValue] ~= value
			invalidSettings[entityType][setting][invalidValue] = value
		end
		if updated then
			if overrideType == "world" then
				world.setProperty("sbqInvalidSettings", worldInvalidSettings)
			elseif overrideType == "global" then
				root.setConfigurationPath("sbq.invalidSettings", globalInvalidSettings)
			end
		end
	end

	local function parseTextBoxValue(textbox)
		local success, value = pcall(sb.parseJson, textbox.text)
		if success then
			local valueType = type(value)
			if (valueType == settingType) or (valueType == "nil") then
				textbox.color = "00FF00"
				return value
			end
		end
		textbox.color = "FF0000"
		return nil
	end
	local activeSetup
	local inactiveSetup

	activeSetup = function()
		layout:clearChildren()
		if group and groupKey then
			overrideSettings[entityType][group] = overrideSettings[entityType][group] or {}
			overrideSettings[entityType][group][groupKey] = overrideSettings[entityType][group][groupKey] or {}
			invalidSettings[entityType][group] = invalidSettings[entityType][group] or {}
			invalidSettings[entityType][group][groupKey] = invalidSettings[entityType][group][groupKey] or {}
			invalidSettings[entityType][group][groupKey][setting] = invalidSettings[entityType][group][groupKey][setting] or {}
			invalidValueMap = invalidSettings[entityType][group][groupKey][setting]
		else
			invalidSettings[entityType][setting] = invalidSettings[entityType][setting] or {}
			invalidValueMap = invalidSettings[entityType][setting]
		end

		if settingType == "boolean" then
			layout:addChild(parseLayout(booleanLayout))
			local checkBox = _ENV["override_"..settingId]
			checkBox:setChecked(overrideValue)
			if overrideValue == nil then
				setOverrideValue(false)
			end
		elseif settingType == "number" then
			layout:addChild(parseLayout(numberLayout))
			local overrideTextBox = _ENV["override_"..settingId]
			local invalidMinTextBox = _ENV["invalidMin_"..settingId]
			local invalidMaxTextBox = _ENV["invalidMax_"..settingId]
			function invalidMinTextBox:onTextChanged()
				setInvalidMapping("min", parseTextBoxValue(self, "number"))
			end
			function invalidMaxTextBox:onTextChanged()
				setInvalidMapping("max", parseTextBoxValue(self, "number"))
			end
			function overrideTextBox:onTextChanged()
				setOverrideValue(parseTextBoxValue(self, "number"))
			end
			overrideTextBox:setText(sb.printJson(overrideValue))
			invalidMinTextBox:setText(sb.printJson(invalidValueMap.min))
			invalidMaxTextBox:setText(sb.printJson(invalidValueMap.max))
		else
			layout:addChild(parseLayout(jsonLayout))
			local overrideTextBox = _ENV["override_"..settingId]
			function overrideTextBox:onTextChanged()
				setOverrideValue(parseTextBoxValue(self, settingType))
			end
			overrideTextBox:setText(sb.printJson(overrideValue))
			local invalidMapLayout = _ENV["invalidMapLayout_"..settingId]
			local invalidMapAddButton = _ENV["invalidMapAddButton_"..settingId]
			local invalidMappingsList = {}
			for k, v in pairs(invalidValueMap) do
				table.insert(invalidMappingsList, k)
			end
			local function addNewMapping(k,v)
				local newMappingLayout = invalidMapLayout:addChild({type = "layout", mode = "h", expandMode = {1,0}, children = {
					{type = "textBox"},
					{type = "label", text = "->", inline = true},
					{type = "textBox"}
				}})
				local keyTextBox = newMappingLayout.children[1]
				local valueTextBox = newMappingLayout.children[3]
				local prevKey = k
				function keyTextBox:onTextChanged()
					local k = parseTextBoxValue(keyTextBox)
					local v = parseTextBoxValue(valueTextBox)
					if prevKey and (prevKey ~= k) then
						invalidValueMap[prevKey] = nil
						prevKey = k
					end
					if k then
						setInvalidMapping(k, v)
					end
				end
				valueTextBox.onTextChanged = keyTextBox.onTextChanged
				keyTextBox:setText(sb.printJson(k))
				valueTextBox:setText(sb.printJson(v))
			end
			if #invalidMappingsList > 0 then
				table.sort(invalidMappingsList, function(a,b)
					return a < b
				end)
				for k, v in ipairs(invalidMappingsList) do
					addNewMapping(k,v)
				end
			else
				addNewMapping(nil,nil)
			end
			function invalidMapAddButton:onClick()
				addNewMapping(nil,nil)
			end
		end
		local removeButton = _ENV["remove_"..settingId]
		function removeButton:onClick()
			inactiveSetup()
		end
	end
	inactiveSetup = function()
		if group and groupKey then
			((overrideSettings[entityType][group] or {})[groupKey] or {})[setting] = nil
			((invalidSettings[entityType][group] or {})[groupKey] or {})[setting] = nil
		else
			overrideSettings[entityType][setting] = nil
			invalidSettings[entityType][setting] = nil
		end
		layout:clearChildren()
		layout:addChild(parseLayout(inactiveLayout))
		local addButton = _ENV["add_"..settingId]
		function addButton:onClick()
			activeSetup()
		end
	end
	if (overrideValue ~= nil) or (invalidValueMap ~= nil) then
		activeSetup()
	else
		inactiveSetup()
	end

end
