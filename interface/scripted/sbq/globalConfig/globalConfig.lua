local function loadVersioned(a, jsonVersion)
	a = a or {}
	if not (a.id and a.version and a.content) then
		a = {
			id = jsonVersion,
			version = 0,
			content = a
		}
	end
	return root.loadVersionedJson(a, jsonVersion)
end
local worldOverrideSettings = sb.jsonMerge(loadVersioned(world.getProperty("sbqOverrideSettings"), "sbqOverrideSettings"), {
	any = {},
	npc = {},
	player = {},
	monster = {},
	object = {}
})
local globalOverrideSettings = sb.jsonMerge(loadVersioned(root.getConfigurationPath("sbq.overrideSettings"), "sbqOverrideSettings"),{
	any = {},
	npc = {},
	player = {},
	monster = {},
	object = {}
})
local worldInvalidSettings = sb.jsonMerge(loadVersioned(world.getProperty("sbqInvalidSettings"),"sbqInvalidSettings"),{
	any = {},
	npc = {},
	player = {},
	monster = {},
	object = {}
})
local globalInvalidSettings = sb.jsonMerge(loadVersioned(root.getConfigurationPath("sbq.invalidSettings"),"sbqInvalidSettings"),{
	any = {},
	npc = {},
	player = {},
	monster = {},
	object = {}
})

_ENV.overridesSearchTextbox.caption = sbq.getString(":search")
_ENV.overridesSearchTextbox:setText("")

function _ENV.exportOverridesButton:onClick()
	local global = _ENV.mainTabField.currentTab.id == "global"
	player.giveItem({ name = "secretnote", count = 1, parameters = {
		shortdescription = sbq.getString(":overridesCardShortDesc"):format(sbq.entityName(sbq.entityId())),
		description = sbq.getString(":overridesCardDesc"),
		tooltipKind = "filledcapturepod",
		tooltipFields = {
			noCollarLabel = "",
			collarNameLabel = sbq.createdDateString(),
			objectImage = world.entityPortrait(player.id(), "full")
		},
		sbqOverrideSettings = root.makeCurrentVersionedJson("sbqOverrideSettings", global and globalOverrideSettings or worldOverrideSettings),
		sbqInvalidSettings = root.makeCurrentVersionedJson("sbqInvalidSettings", global and globalInvalidSettings or worldInvalidSettings),
	}})
end
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
local groupedSettingsLists = {
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
local groupList = {}
local groupKeysLists = {}
for group, v in pairs(sbq.config.groupedSettings) do
	groupKeysLists[group] = {}
	table.insert(groupList, group)
	for groupKey, _ in pairs(sbq.config.defaultSettings.any[group]) do
		table.insert(groupKeysLists[group], groupKey)
	end
	table.sort(groupKeysLists[group], function(a,b)
		return a < b
	end)
end
table.sort(groupList, function(a,b)
	return a < b
end)
for _, group in ipairs(groupList) do
	local tabs = {}
	for _, groupKey in ipairs(groupKeysLists[group]) do
		table.insert(tabs, { type= "tab",id = groupKey,title= sbq.getString(":"..groupKey), visible= true,color= "ff00ff", contents= {}} )
	end
	_ENV.groupsTabField:newTab({ type= "tab",id = group,title= sbq.getString(":"..group), visible= true,color= "ff00ff", contents= {
		{ type="tabField",id=group.."_tabField",layout="horizontal",tabs=tabs}
	}})
end

for entityType, _ in pairs(settingsLists) do
	defaultSettings[entityType] = sb.jsonMerge(sbq.config.defaultSettings.any or {}, sbq.config.defaultSettings[entityType] or {})
	for setting, _ in pairs(defaultSettings[entityType]) do
		if not sbq.config.groupedSettings[setting] then
			table.insert(settingsLists[entityType], setting)
		end
	end
	table.sort(settingsLists[entityType], function(a,b)
		return a < b
	end)

	for group, v in pairs(sbq.config.groupedSettings) do
		groupedSettingsLists[entityType][group] = {}
		for groupKey, settings in pairs(defaultSettings[entityType][group]) do
			groupedSettingsLists[entityType][group][groupKey] = {}
			for setting, _ in pairs(defaultSettings[entityType][group][groupKey]) do
				table.insert(groupedSettingsLists[entityType][group][groupKey], setting)
			end
			table.sort(groupedSettingsLists[entityType][group][groupKey], function(a,b)
				return a < b
			end)
		end
	end
end

local settingGroups = {}

function init()
	searchSettings()
end


function searchSettings()
	local searchText = _ENV.overridesSearchTextbox.text
	local overrideType = _ENV.mainTabField.currentTab.id
	local entityType = _ENV.global_tabField.currentTab.id
	local group = _ENV.groupsTabField.currentTab.id
	local groupKey = _ENV[group.."_tabField"].currentTab.id
	_ENV.mainScrollArea:clearChildren()
	_ENV.groupScrollArea:clearChildren()
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
	_ENV.groupScrollArea:addChild({type = "label", align = "center", text = sbq.getString(":overallGroupOverrides"):format(sbq.getString(":"..group))})
	for _, setting in pairs(groupedSettingsLists[entityType][group][groupKey]) do
		if (searchText == "") or setting:find(searchText) or sbq.getString(":"..setting):find(searchText) then
			local newLayout = _ENV.groupScrollArea:addChild({
				type = "layout",
				mode = "v",
				expandMode = {1,0},
				children = {}
			})
			setupOverrideLayout(newLayout, overrideType, entityType, setting, group, groupKey, true)
		end
	end
	_ENV.groupScrollArea:addChild({type = "spacer", size = 10})
	_ENV.groupScrollArea:addChild({type = "label", align = "center", text = sbq.getString(":specificGroupOverrides"):format(sbq.getString(":"..groupKey))})
	for _, setting in pairs(groupedSettingsLists[entityType][group][groupKey]) do
		if (searchText == "") or setting:find(searchText) or sbq.getString(":"..setting):find(searchText) then
			local newLayout = _ENV.groupScrollArea:addChild({
				type = "layout",
				mode = "v",
				expandMode = {1,0},
				children = {}
			})
			setupOverrideLayout(newLayout, overrideType, entityType, setting, group, groupKey)
		end
	end

end
for k, v in pairs(_ENV.global_tabField.tabs) do
	local worldTab = _ENV.world_tabField.tabs[k]
	function v:onSelect()
		searchSettings()
		if _ENV.world_tabField.currentTab ~= worldTab then
			worldTab:select()
		end
	end
	function worldTab:onSelect()
		v:select()
	end
end
for k, v in pairs(_ENV.mainTabField.tabs) do
	function v:onSelect()
		searchSettings()
	end
end
for k, v in pairs(_ENV.groupsTabField.tabs) do
	function v:onSelect()
		searchSettings()
	end
	for k, v in pairs(_ENV[k.."_tabField"].tabs) do
		function v:onSelect()
			searchSettings()
		end
	end
end
function _ENV.overridesSearchTextbox:onTextChanged()
	searchSettings()
end
function _ENV.importOverridesItemSlot:acceptsItem(item)
	sb.logInfo(sb.printJson(item,2))
	return (item.parameters.sbqOverrideSettings ~= nil) and (item.parameters.sbqInvalidSettings ~= nil)
end
function _ENV.importOverridesButton:onClick()
	local item = _ENV.importOverridesItemSlot:item()
	if not item then return sbq.playErrorSound() end
	if _ENV.mainTabField.currentTab.id == "global" then
		globalOverrideSettings = sb.jsonMerge(loadVersioned(item.parameters.sbqOverrideSettings, "sbqOverrideSettings"), {
			any = {},
			npc = {},
			player = {},
			monster = {},
			object = {}
		})
		globalInvalidSettings = sb.jsonMerge(loadVersioned(item.parameters.sbqInvalidSettings,"sbqInvalidSettings"),{
			any = {},
			npc = {},
			player = {},
			monster = {},
			object = {}
		})
	else
		worldOverrideSettings = sb.jsonMerge(loadVersioned(item.parameters.sbqOverrideSettings, "sbqOverrideSettings"), {
			any = {},
			npc = {},
			player = {},
			monster = {},
			object = {}
		})
		worldInvalidSettings = sb.jsonMerge(loadVersioned(item.parameters.sbqInvalidSettings,"sbqInvalidSettings"),{
			any = {},
			npc = {},
			player = {},
			monster = {},
			object = {}
		})
	end
	searchSettings()
end

function setupOverrideLayout(layout, overrideType, entityType, setting, group, groupKey, overall)
	local overrideSettings
	local invalidSettings
	if overrideType == "global" then
		overrideSettings = globalOverrideSettings
		invalidSettings = globalInvalidSettings
	elseif overrideType == "world" then
		overrideSettings = worldOverrideSettings
		invalidSettings = worldInvalidSettings
	end
	local settingId = setting
	local settingType
	local overrideValue
	local invalidValueMap
	if group and groupKey then
		if overall then
			overrideValue = overrideSettings[entityType][setting]
			invalidValueMap = invalidSettings[entityType][setting]
			settingType = type(defaultSettings[entityType][group][groupKey][setting])
		else
			settingId = ("%s.%s.%s"):format(group, groupKey,setting)
			overrideValue = ((overrideSettings[entityType][group] or {})[groupKey] or {})[setting]
			invalidValueMap = ((invalidSettings[entityType][group] or {})[groupKey] or {})[setting]
			settingType = type(defaultSettings[entityType][group][groupKey][setting])
		end
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
		if group and groupKey and not overall then
			updated = overrideSettings[entityType][group][groupKey][setting] ~= value
			overrideSettings[entityType][group][groupKey][setting] = value
		else
			updated = overrideSettings[entityType][setting] ~= value
			overrideSettings[entityType][setting] = value
		end
		if updated then
			if overrideType == "world" then
				world.setProperty("sbqOverrideSettings", root.makeCurrentVersionedJson("sbqOverrideSettings", worldOverrideSettings) )
			elseif overrideType == "global" then
				root.setConfigurationPath("sbq.overrideSettings", root.makeCurrentVersionedJson("sbqOverrideSettings", globalOverrideSettings) )
			end
		end
	end
	local function setInvalidMapping(invalidValue, value)
		local updated
		if group and groupKey and not overall then
			updated = invalidSettings[entityType][group][groupKey][setting][invalidValue] ~= value
			invalidSettings[entityType][group][groupKey][setting][invalidValue] = value
		else
			updated = invalidSettings[entityType][setting][invalidValue] ~= value
			invalidSettings[entityType][setting][invalidValue] = value
		end
		if updated then
			if overrideType == "world" then
				world.setProperty("sbqInvalidSettings", root.makeCurrentVersionedJson("sbqInvalidSettings", worldInvalidSettings))
			elseif overrideType == "global" then
				root.setConfigurationPath("sbq.invalidSettings", root.makeCurrentVersionedJson("sbqInvalidSettings", globalInvalidSettings) )
			end
		end
	end

	local function parseTextBoxValue(textbox, getType)
		if textbox.text == "" then return nil end
		local success, value = pcall(sb.parseJson, textbox.text)
		if success then
			local valueType = type(value)
			if (valueType == getType) or (valueType == "nil") then
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
		if group and groupKey and not overall then
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
			if overrideValue == nil then
				setOverrideValue(false)
				checkBox:setChecked(false)
			else
				checkBox:setChecked(overrideValue)
			end
			function checkBox:onClick()
				setOverrideValue(self.checked)
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
					{type = "button", caption = "x", color = "FF0000", expandMode = {0,0}, size = {11,11}},
					{type = "textBox"},
					{type = "label", text = "->", inline = true},
					{type = "textBox"}
				}})
				local button = newMappingLayout.children[1]
				local keyTextBox = newMappingLayout.children[2]
				local valueTextBox = newMappingLayout.children[4]
				local prevKey = k
				function keyTextBox:onTextChanged()
					local newK = parseTextBoxValue(keyTextBox, settingType)
					local newV = parseTextBoxValue(valueTextBox, settingType)
					if prevKey and (prevKey ~= newK) then
						invalidValueMap[prevKey] = nil
						prevKey = newK
					end
					if newK then
						setInvalidMapping(newK, newV)
					end
				end
				function button:onClick()
					newMappingLayout:delete()
					if prevKey then
						setInvalidMapping(prevKey, nil)
					end
				end
				valueTextBox:setText(sb.printJson(v))
				valueTextBox.onTextChanged = keyTextBox.onTextChanged
				keyTextBox:setText(sb.printJson(k))
			end
			if #invalidMappingsList > 0 then
				table.sort(invalidMappingsList, function(a,b)
					return a < b
				end)
				for _, k in pairs(invalidMappingsList) do
					addNewMapping(k,invalidValueMap[k])
				end
			else
				addNewMapping(nil,nil)
			end
			function invalidMapAddButton:onClick()
				addNewMapping(nil,nil)
			end
		end
		local settingAdminTip = _ENV[settingId.."AdminTipLabel1"]
		if sbq.strings[setting.."AdminTip"] then
			settingAdminTip:setVisible(true)
		end
		if group and groupKey and not overall then
			local settingIdAdminTip = _ENV[settingId.."AdminTipLabel2"]
			if sbq.strings[settingId.."AdminTip"] then
				settingIdAdminTip:setVisible(true)
			end
		end
		local removeButton = _ENV["remove_"..settingId]
		function removeButton:onClick()
			inactiveSetup()
		end
	end
	inactiveSetup = function()
		if group and groupKey and not overall then
			((overrideSettings[entityType][group] or {})[groupKey] or {})[setting] = nil
			((invalidSettings[entityType][group] or {})[groupKey] or {})[setting] = nil
		else
			overrideSettings[entityType][setting] = nil
			invalidSettings[entityType][setting] = nil
		end
		if overrideType == "world" then
			world.setProperty("sbqOverrideSettings", root.makeCurrentVersionedJson("sbqOverrideSettings", worldOverrideSettings) )
			world.setProperty("sbqInvalidSettings", root.makeCurrentVersionedJson("sbqInvalidSettings", worldInvalidSettings) )
		elseif overrideType == "global" then
			root.setConfigurationPath("sbq.overrideSettings", root.makeCurrentVersionedJson("sbqOverrideSettings", globalOverrideSettings) )
			root.setConfigurationPath("sbq.invalidSettings", root.makeCurrentVersionedJson("sbqInvalidSettings", globalInvalidSettings) )
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
