---@diagnostic disable: undefined-global

sbq.extraTabs = root.assetJson("/interface/scripted/sbq/sbqSettings/sbqSettingsTabs.json")

function sbq.getPatronsString()
	local patronsString = ""
	for _, patron in ipairs(root.assetJson("/patrons.json")) do
		patronsString = patronsString..patron.."^reset;\n"
	end
	return patronsString
end
sbq.patronsString = sbq.getPatronsString()
function sbq.getKofiString()
	local patronsString = ""
	for _, patron in ipairs(root.assetJson("/kofiSupporters.json")) do
		patronsString = patronsString..patron.."^reset;\n"
	end
	return patronsString
end
sbq.KoFiString = sbq.getKofiString()

function sbq.setHelpTab()
	if sbq.doneHelpTab then return end
	sbq.doneHelpTab = true
	helpTabContents:clearChildren()
	helpTabContents:addChild({ type = "layout", mode = "horizontal", children = sbq.extraTabs.helpTab.contents })
	kofiLabel:setText(sbq.KoFiString)
	patronsLabel:setText(sbq.patronsString)

	sbq.selectedHelpTab = helpTabs.tabs.predHelpTab
	function helpTabs:onTabChanged(tab, previous)
		sbq.selectedHelpTab = tab
	end

	require("/interface/scripted/sbq/sbqSettings/sbqResetSettings.lua")
	if root.itemConfig("vorechipkit") ~= nil and sbq.config.SSVMParityEnabled then
		sbq.setSSVMTab = true
		helpTabs:newTab(sbq.extraTabs.SSVMOverridesTab)
		SSVMTargetCreatures:setChecked(status.statusProperty("sbqSSVMTargeting") == "creature")

		function SSVMTargetCreatures:onClick()
			if SSVMTargetCreatures.checked then
				status.setStatusProperty("sbqSSVMTargeting", "creature")
			else
				status.setStatusProperty("sbqSSVMTargeting", nil)
			end
		end
	end
end

function sbq.setSpeciesHelpTab(entitySpecies)
	speciesHelpTabContents:clearChildren()

	local helpOrInfo = "speciesHelpTabs"
	if sbq.sbqCurrentData.type == "object" then
		helpOrInfo = "speciesInfoTabs"
	end
	local species = sbq.sbqCurrentData.species or "sbqOccupantHolder"
	if (species == "sbqOccupantHolder") and sbq.extraTabs[helpOrInfo][entitySpecies] ~= nil then
		species = entitySpecies
	end
	local tabData = sbq.extraTabs[helpOrInfo][species]
	if tabData ~= nil then
		mainTabField.tabs.speciesHelpTab:setVisible(true)
		mainTabField.tabs.speciesHelpTab:setTitle(tabData.title, tabData.icon)
		speciesHelpTabContents:addChild({type = "layout", mode = "horizontal", children = tabData.contents})

		sbq.selectedSpeciesHelpTab = speciesHelpTabs.tabs.generalTab
		function speciesHelpTabs:onTabChanged(tab, previous)
			sbq.selectedSpeciesHelpTab = tab
		end
	else
		mainTabField.tabs.speciesHelpTab:setVisible(false)
	end
end

settingsButtonScripts = {}
local setIcon
function sbq.setSpeciesSettingsTab(entitySpecies)
	speciesConfigTabContents:clearChildren()
	settingsButtonScripts = {}

	local species = sbq.sbqCurrentData.species or "sbqOccupantHolder"
	if (species == "sbqOccupantHolder") and sbq.extraTabs.speciesSettingsTabs[entitySpecies] ~= nil then
		species = entitySpecies
	end
	local tabData = sbq.extraTabs.speciesSettingsTabs[species]
	if tabData ~= nil then
		setIcon = true
		mainTabField.tabs.speciesConfigTab:setVisible(true)
		mainTabField.tabs.speciesConfigTab:setTitle(tabData.tab.title, tabData.tab.icon)
		speciesConfigTabContents:addChild({type = "layout", mode = "horizontal", children = tabData.tab.contents})


		if tabData.scripts ~= nil then
			for _, script in ipairs(tabData.scripts) do
				require(script)
			end
		end
	else
		setIcon = false
		mainTabField.tabs.speciesConfigTab:setVisible(false)
	end
end

function sbq.setIconDirectives()
	if setIcon then
		mainTabField.tabs.speciesConfigTab:setTitle("Config", "/vehicles/sbq/"..sbq.sbqCurrentData.species.."/skins/"..((sbq.predatorSettings.skinNames or {}).head or "default").."/icon.png"..(sbq.predatorSettings.directives or ""))
	end
end

function mainTabField:onTabChanged(tab, previous)
	sbq.selectedMainTabFieldTab = tab
	local newSelected = tab.id

	if newSelected == "globalPredSettings" and sbq.selectedLocationTab ~= nil then
		locationTabField:pushEvent("tabChanged", sbq.selectedLocationTab, sbq.selectedLocationTab)
	end
	if newSelected == "speciesHelpTab" and sbq.selectedSpeciesHelpTab ~= nil then
		speciesHelpTabs:pushEvent("tabChanged", sbq.selectedSpeciesHelpTab, sbq.selectedSpeciesHelpTab)
	end
	if newSelected == "helpTab" and sbq.selectedHelpTab ~= nil then
		helpTabs:pushEvent("tabChanged", sbq.selectedHelpTab, sbq.selectedHelpTab)
	end
end
