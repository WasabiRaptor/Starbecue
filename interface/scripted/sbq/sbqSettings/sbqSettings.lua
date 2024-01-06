
---@diagnostic disable:undefined-global

require( "/lib/stardust/json.lua" )

sbq = {
	config = root.assetJson( "/sbqGeneral.config" ),
	overrideSettings = {},
	playerSettings = true,
	playerPreySettings = status.statusProperty("sbqPreyEnabled") or {},
	playerPredatorSettings = (player.getProperty("sbqSettings") or {}).global or {}
}

mainTabField.subTabs = {}

require("/scripts/SBQ_RPC_handling.lua")
require("/interface/scripted/sbq/sbqSettings/sbqSettingsEffectsPanel.lua")
require("/scripts/SBQ_species_config.lua")
require("/interface/scripted/sbq/sbqSettings/extraTabs.lua")
require("/interface/scripted/sbq/sbqSettings/autoSetSettings.lua")
require("/interface/scripted/sbq/sbqSettings/sbqExtraTab.lua")

mainTabField.tabs.globalPredSettings:select()

function sbq.getInitialData()
	sbq.preySettings = sb.jsonMerge(sbq.config.defaultPreyEnabled.player, status.statusProperty("sbqPreyEnabled") or {})
	sbq.overridePreyEnabled = status.statusProperty("sbqOverridePreyEnabled") or {}

	sbq.sbqSettings = player.getProperty("sbqSettings") or {}

	sbq.sbqCurrentData = player.getProperty("sbqCurrentData") or {}
	sbq.lastSpecies = sbq.sbqCurrentData.species
	sbq.lastType = player.getProperty("sbqType")

	sbq.storedDigestedPrey = status.statusProperty("sbqStoredDigestedPrey") or {}

	sbq.predatorEntity = sbq.sbqCurrentData.id

	sbq.cumulativeData = player.getProperty("sbqCumulativeData") or {}

	sbq.animOverrideSettings = sb.jsonMerge(sb.jsonMerge(root.assetJson("/animOverrideDefaultSettings.config"), sbq.speciesFile.animOverrideDefaultSettings or {}), status.statusProperty("speciesAnimOverrideSettings") or {})
	sbq.animOverrideSettings.scale = status.statusProperty("animOverrideScale") or 1
	sbq.animOverrideOverrideSettings = status.statusProperty("speciesAnimOverrideOverrideSettings") or {}

	sbq.sbqCurrentData.species = sbq.sbqCurrentData.species or "sbqOccupantHolder"
end

function sbq.getOccupantHolderData(settings)
	sbq.getSpeciesConfig(player.species(), settings or sbq.sbqSettings.global)
	sbq.predatorConfig = sbq.speciesConfig.sbqData
	sbq.speciesFile = root.assetJson( "/species/"..(sbq.speciesConfig.species)..".species" )
end

function sbq.drawLocked(w, icon)
	local c = widget.bindCanvas(w.backingWidget)
	c:clear()
	local pos = vec2.mul(c:size(), 0.5)
	c:drawImageDrawable(icon, pos, 1)
end

function sbq.getSpeciesAndSettings()
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
	sbq.overridePreyEnabled = sb.jsonMerge(sbq.predatorConfig.overridePreyEnabled or {}, sbq.overridePreyEnabled or {})
end

function init()

	sbq.getInitialData()

	sbq.globalSettings = sb.jsonMerge(sbq.config.globalSettings, sbq.sbqSettings.global)

	sbq.getSpeciesAndSettings()

	sbq.effectsPanel()
	sbq.extraTab()

	if ((sbq.lastType ~= "prey") or (sbq.lastType == "object")) then
		mainTabField.tabs.customizeTab:setVisible(true)

		if sbq.predatorConfig.customizePresets ~= nil then
			presetsPanel:setVisible(true)
			sbq.preset = 1
			presetText:setText(sbq.predatorSettings.presetText or sbq.predatorConfig.presetList[sbq.preset])
		else
			presetsPanel:setVisible(false)
		end
		if not player.loungingIn() and sbq.lastType ~= "object" and (sbq.sbqCurrentData.species == nil or sbq.sbqCurrentData.species == "sbqOccupantHolder") then
			speciesLayout:setVisible( not sbq.hideSpeciesPanel )
		elseif sbq.lastType ~= "object" then
			speciesLayout:setVisible(false)
		end


		if sbq.predatorConfig.replaceColors ~= nil then
			colorsPanel:setVisible(true)
			colorsScrollArea:clearChildren()
			for i, colors in ipairs(sbq.predatorConfig.replaceColors) do
				colorsScrollArea:addChild({ type = "layout", mode = "horizontal", children = {
					{{size = {48,10}},{ type = "label", text = (sbq.predatorConfig.replaceColorNames or {})[i] or ("Color "..i), inline = true}},
					{ type = "checkBox", id = "color"..i.."Fullbright", checked = (sbq.predatorSettings.fullbright or {})[i] or (sbq.predatorConfig.defaultSettings.fullbright or {})[i], toolTip = "Fullbright" },
					{ type = "iconButton", id = "color"..i.."Prev", image = "/interface/pickleft.png", hoverImage = "/interface/pickleftover.png"},
					{ type = "textBox", id = "color"..i.."TextEntry", toolTip = "Edit the text here to define a custom palette, make sure to match the formatting.", expandMode = {2,2} },
					{ type = "iconButton", id = "color"..i.."Next", image = "/interface/pickright.png", hoverImage = "/interface/pickrightover.png"}
				}})
				local fullbright = _ENV["color"..i.."Fullbright"]
				local prev = _ENV["color"..i.."Prev"]
				local textbox = _ENV["color"..i.."TextEntry"]
				local next = _ENV["color"..i.."Next"]

				if type((sbq.predatorSettings.replaceColorTable or {})[i]) == "string" then
					textbox:setText((sbq.predatorSettings.replaceColorTable or {})[i])
				else
					textbox:setText(sb.printJson( ( (sbq.predatorSettings.replaceColorTable or {})[i]) or ( sbq.predatorConfig.replaceColors[i][ (sbq.predatorSettings.replaceColors[i] or (sbq.predatorConfig.defaultSettings.replaceColors or {})[i] or 1 ) + 1 ] ) ) )
				end

				function fullbright:onClick()
					sbq.predatorSettings.fullbright[i] = fullbright.checked
					sbq.saveSettings()
				end
				function prev:onClick()
					sbq.changeColorSetting(textbox, i, -1)
				end
				function textbox:onTextChanged()
					local decoded = json.decode(textbox.text)
					if type(decoded) == "table" then
						sbq.predatorSettings.replaceColorTable[i] = decoded
					else
						sbq.predatorSettings.replaceColorTable[i] = nil
					end
					sbq.setColorReplaceDirectives()
					sbq.saveSettings()
				end
				function next:onClick()
					sbq.changeColorSetting(textbox, i, 1)
				end
			end
		else
			colorsScrollArea:clearChildren()
			colorsPanel:setVisible(false)
		end
		if sbq.predatorConfig.replaceSkin then
			skinsPanel:setVisible(true)
			skinsScrollArea:clearChildren()
			for part, _ in pairs(sbq.predatorConfig.replaceSkin) do
				skinsScrollArea:addChild({ type = "layout", mode = "horizontal", children = {
					{{size = {48,10}},{ type = "label", text = " "..sbq.predatorConfig.replaceSkin[part].name, inline = true}},
					{ type = "iconButton", id = part.."Prev", image = "/interface/pickleft.png", hoverImage = "/interface/pickleftover.png"},
					{ type = "textBox", id = part.."TextEntry", toolTip = "Edit the text here to define a specific skin, if it exists", expandMode = {2,2} },
					{ type = "iconButton", id = part.."Next", image = "/interface/pickright.png", hoverImage = "/interface/pickrightover.png"}
				}})
				local prev = _ENV[part.."Prev"]
				local textbox = _ENV[part.."TextEntry"]
				local next = _ENV[part.."Next"]

				textbox:setText((sbq.predatorSettings.skinNames or {})[part] or "default")

				function prev:onClick()
					sbq.changeSkinSetting(textbox, part, -1)
				end
				function textbox:onTextChanged()
					if textbox.text ~= nil and textbox.text ~= "" then
						for i, partname in ipairs(sbq.predatorConfig.replaceSkin[part].parts) do
							sbq.predatorSettings.skinNames[partname] = textbox.text
						end
						sbq.saveSettings()
					end
				end
				function next:onClick()
					sbq.changeSkinSetting(textbox, part, 1)
				end
			end
		else
			skinsScrollArea:clearChildren()
			skinsPanel:setVisible(false)
		end
	else
		mainTabField.tabs.customizeTab:setVisible(false)
		presetsPanel:setVisible(false)
		colorsScrollArea:clearChildren()
		skinsScrollArea:clearChildren()
	end

	local species = player.species()
	sbq.setSpeciesHelpTab(species)
	sbq.setSpeciesSettingsTab(species)
	sbq.setHelpTab()

	escapeValue:setText(tostring(sbq.globalSettings.escapeDifficulty or 0))
	sbq.numberBoxColor(escapeValue, sbq.overrideSettings.escapeDifficultyMin, sbq.overrideSettings.escapeDifficultyMax)
	sbq.refreshButtons()
	sbq.checkLockedSettingsButtons("animOverrideSettings", "animOverrideOverrideSettings", "changeAnimOverrideSetting")

	if mainTabField.tabs.globalPreySettings ~= nil then
		sbq.checkLockedSettingsButtons("preySettings", "overridePreyEnabled", "changePreySetting")
	end
end
local init = init

function sbq.refreshButtons()
	sbq.checkLockedSettingsButtons("predatorSettings", "overrideSettings", "changePredatorSetting")
	sbq.checkLockedSettingsButtons("globalSettings", "overrideSettings", "changeGlobalSetting")
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

function update()
	sbq.sbqCurrentData = player.getProperty("sbqCurrentData") or {}
	sbq.sbqSettings = player.getProperty("sbqSettings") or {}
	sbq.globalSettings = sb.jsonMerge(sbq.config.globalSettings, sbq.sbqSettings.global or {})

	mainTabField:doUpdate(script.updateDt())

	if sbq.sbqCurrentData.id ~= sbq.predatorEntity then
		init()
	end
end

--------------------------------------------------------------------------------------------------

function sbq.saveSettings()
	if type(sbq.sbqCurrentData.id) == "number" and sbq.lastType == "driver" and world.entityExists(sbq.sbqCurrentData.id) then
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

function sbq.changeColorSetting(textbox, color, inc)
	if sbq.predatorConfig.replaceColors == nil then return end

	sbq.predatorSettings.replaceColors[color] = ((sbq.predatorSettings.replaceColors[color] or ((sbq.predatorConfig.defaultSettings.replaceColorTable or {})[color]) or 1 ) + inc)

	if sbq.predatorSettings.replaceColors[color] < 1 then
		sbq.predatorSettings.replaceColors[color] = (#sbq.predatorConfig.replaceColors[color] -1)
	elseif sbq.predatorSettings.replaceColors[color] > (#sbq.predatorConfig.replaceColors[color] -1) then
		sbq.predatorSettings.replaceColors[color] = 1
	end

	local colorTable = sbq.predatorConfig.replaceColors[color][ (sbq.predatorSettings.replaceColors[color] or ((sbq.predatorConfig.defaultSettings.replaceColorTable or {})[color]) or 1 ) + 1 ]

	textbox:setText(sb.printJson(colorTable))

	sbq.predatorSettings.replaceColorTable[color] = colorTable

	sbq.setColorReplaceDirectives()
	sbq.setIconDirectives()
	sbq.saveSettings()
end

function sbq.setColorReplaceDirectives()
	if sbq.predatorConfig.replaceColors ~= nil then
		local colorReplaceString = ""
		for i, colorGroup in ipairs(sbq.predatorConfig.replaceColors) do
			local basePalette = colorGroup[1]
			local replacePalette = colorGroup[((sbq.predatorSettings.replaceColors or {})[i] or (sbq.predatorConfig.defaultSettings.replaceColors or {})[i] or 1) + 1]
			local fullbright = (sbq.predatorSettings.fullbright or {})[i]

			if sbq.predatorSettings.replaceColorTable and sbq.predatorSettings.replaceColorTable[i] then
				replacePalette = sbq.predatorSettings.replaceColorTable[i]
				if type(replacePalette) == "string" then
					sbq.predatorSettings.directives = replacePalette
					return
				end
			end

			for j, color in ipairs(replacePalette) do
				if fullbright and #color <= #"ffffff" then -- don't tack it on it if it already has a defined opacity or fullbright
					color = color.."fe"
				end
				colorReplaceString = colorReplaceString.."?replace;"..(basePalette[j] or "").."="..(color or "")
			end
		end
		sbq.predatorSettings.directives = colorReplaceString
	end
end

function sbq.changeSkinSetting(textbox, part, inc)
	local skinIndex = (sbq.predatorSettings.replaceSkin[part] or 1) + inc
	if skinIndex > #sbq.predatorConfig.replaceSkin[part].skins then
		skinIndex = 1
	elseif skinIndex < 1 then
		skinIndex = #sbq.predatorConfig.replaceSkin[part].skins
	end

	sbq.predatorSettings.replaceSkin[part] = skinIndex

	textbox:setText(sbq.predatorConfig.replaceSkin[part].skins[skinIndex])

	for i, partname in ipairs(sbq.predatorConfig.replaceSkin[part].parts) do
		sbq.predatorSettings.skinNames[partname] = sbq.predatorConfig.replaceSkin[part].skins[skinIndex]
	end
	sbq.saveSettings()
end

function sbq.changePreset(inc)
	local presetIndex = (sbq.preset or 1) + inc
	if presetIndex > #sbq.predatorConfig.presetList then
		presetIndex = 1
	elseif presetIndex < 1 then
		presetIndex = #sbq.predatorConfig.presetList
	end
	sbq.preset = presetIndex
	presetText:setText(sbq.predatorConfig.presetList[sbq.preset])
end

--------------------------------------------------------------------------------------------------


function escapeValue:onEnter()
	sbq.numberBox(self, "changeGlobalSetting", "escapeDifficulty", "predatorSettings", "overrideSettings", sbq.overrideSettings.escapeDifficultyMin, sbq.overrideSettings.escapeDifficultyMax)
end
function escapeValue:onTextChanged()
	sbq.numberBoxColor(self, sbq.overrideSettings.escapeDifficultyMin, sbq.overrideSettings.escapeDifficultyMax)
end
function escapeValue:onEscape() self:onEnter() end
function escapeValue:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end


--------------------------------------------------------------------------------------------------

function decPreset:onClick()
	sbq.changePreset(-1)
end

function incPreset:onClick()
	sbq.changePreset(1)
end

function applyPreset:onClick()
	local preset = sbq.predatorConfig.customizePresets[presetText.text]
	if preset then
		sbq.predatorSettings = sb.jsonMerge(sbq.predatorSettings, preset)
		if preset.replaceColors then
			sbq.predatorSettings.replaceColorTable = {}
		end
		sbq.predatorSettings.presetText = presetText.text
		sbq.setColorReplaceDirectives()
		sbq.setIconDirectives()
		sbq.saveSettings()
	end
end

function presetText:onEnter()
	applyPreset:onClick()
end

--------------------------------------------------------------------------------------------------

function sbq.nextDifferentListEntry(list, index, inc)
	local current = list[index]
	local index = index
	while list[index] == current do
		index = index + inc
		if index > #list then
			index = 1
		elseif index < 1 then
			index = #list
		end
	end
	return index, list[index]
end

function sbq.generateItemCard(overrideData)
	local item = copy(sbq.config.npcCardTemplate)
	local npcOverrides = {
		identity = sb.jsonMerge(overrideData, {gender = overrideData.gender}),
		items = {
			override = {
				{0,
					{
						{
						}
					}
				}
			}
		}
	}

	item.parameters.shortdescription = sbq.speciesFile.charCreationTooltip.title
	item.parameters.inventoryIcon = root.npcPortrait("bust", overrideData.species, "generictenant", 1, 0, npcOverrides)
	item.parameters.description = "Player Customization Card"
	item.parameters.tooltipFields.collarNameLabel = ""
	item.parameters.tooltipFields.objectImage = root.npcPortrait("full", overrideData.species, "generictenant", 1, 0, npcOverrides)
	item.parameters.tooltipFields.subtitle = "Player"
	item.parameters.tooltipFields.collarIconImage = nil
	item.parameters.npcArgs = {
		npcSpecies = overrideData.species,
		npcSeed = 0,
		npcType = "generictenant",
		npcLevel = 1,
		npcParam = npcOverrides
	}
	speciesCardSlot:setItem(item, true)
end


if speciesLayout ~= nil then
	function refreshOccupantHolder()
		local currentData = status.statusProperty("sbqCurrentData") or {}
		if type(currentData.id) == "number" and world.entityExists(currentData.id) then
			world.sendEntityMessage(currentData.id, "reversion")
			if currentData.species == "sbqOccupantHolder" then
				world.spawnProjectile("sbqWarpInEffect", world.entityPosition(player.id()), player.id(), { 0, 0 }, true)
			elseif type(currentData.species) == "nil" then
				world.sendEntityMessage(entity.id(), "sbqGetSpeciesVoreConfig")
			end
		else
			world.spawnProjectile("sbqWarpInEffect", world.entityPosition(player.id()), player.id(), { 0, 0 }, true)
		end
	end

	function decSpecies:onClick()
		sbq.changeSpecies(-1)
	end

	function incSpecies:onClick()
		sbq.changeSpecies(1)
	end

    function applySpecies:onClick()
		-- small hack for now to maybe have this function
        if (speciesText.text ~= "" and type(sbq.customizedSpecies[speciesText.text]) == "table")
		or (player.isAdmin() and root.speciesConfig(speciesText.text))
        then
            status.setStatusProperty("sbqOriginalSpecies", speciesText.text)
			status.statusProperty("sbqOriginalGender", sbq.customizedSpecies.gender)
			world.sendEntityMessage(player.id(), "sbqMysteriousPotionTF", { species = speciesText.text, gender = sbq.currentCustomSpecies.gender })
		end
	end
	function speciesText:onEnter() applySpecies:onClick() end
	function speciesBodyColorText:onEnter() sbq.saveSpeciesCustomize() end
	function speciesHairColorText:onEnter() sbq.saveSpeciesCustomize() end
	function speciesFacialHairColorText:onEnter() sbq.saveSpeciesCustomize() end
	function speciesFacialMaskColorText:onEnter() sbq.saveSpeciesCustomize() end
	function speciesEmoteColorText:onEnter() sbq.saveSpeciesCustomize() end

	local originalSpecies = world.entitySpecies(player.id())
	sbq.unlockedSpeciesList = {originalSpecies}
	sbq.customizedSpecies = status.statusProperty("sbqCustomizedSpecies") or {}
	sbq.currentCustomSpecies = {}
	for species, data in pairs(sbq.customizedSpecies) do
		if species ~= originalSpecies then
			table.insert(sbq.unlockedSpeciesList, species)
		end
	end
	table.sort(sbq.unlockedSpeciesList)
	if player.isAdmin() then
		local list = root.assetJson("/interface/windowconfig/charcreation.config:speciesOrdering")
		table.sort(list)
		util.appendLists(sbq.unlockedSpeciesList, list or {})
	end
	for i, species in ipairs(sbq.unlockedSpeciesList) do
		if species == player.species() then
			sbq.speciesOverrideIndex = i
			break
		end
	end
	function speciesGenderToggle:onClick()
		local table = {
			male = "female",
			female = "male"
		}
		sbq.currentCustomSpecies.gender = table[sbq.currentCustomSpecies.gender or world.entityGender(player.id())]
		for i, data in ipairs(sbq.speciesFile.genders or {}) do
			if data.name == sbq.currentCustomSpecies.gender then
				sbq.genderTable = data
				speciesGenderToggle:setImage(data.image)
			end
		end
		sbq.saveSpeciesCustomize()
	end
	function sbq.changeSpecies(inc)
		local index = (sbq.speciesOverrideIndex or 1) + inc
		local list = sbq.unlockedSpeciesList
		if index > #list then
			index = 1
		elseif index < 1 then
			index = #list
		end
		sbq.speciesOverrideIndex = index
		local selectedSpecies = sbq.unlockedSpeciesList[sbq.speciesOverrideIndex]
		sbq.currentCustomSpecies = sbq.customizedSpecies[selectedSpecies] or {gender = player.gender(), identity = {}}
		if not selectedSpecies then
			sbq.hideSpeciesPanel = true
			return
		end
		local hidePanels = (selectedSpecies ~= originalSpecies) and type(sbq.customizedSpecies[selectedSpecies]) == "table"
		speciesColorPanel:setVisible(hidePanels)
		speciesStylePanel:setVisible(hidePanels)
		speciesManualColorPanel:setVisible(hidePanels)

		local speciesFile = root.speciesConfig(selectedSpecies)
		if speciesFile then
			sbq.speciesFile = speciesFile
			speciesText:setText(selectedSpecies)

			for i, data in ipairs(speciesFile.genders or {}) do
				if data.name == sbq.currentCustomSpecies.gender then
					sbq.genderTable = data
					for i, type in ipairs(data.hair) do
						if sbq.currentCustomSpecies.hairType == type then
							sbq.hairTypeIndex = i
						end
					end
					for i, type in ipairs(data.facialHair) do
						if sbq.currentCustomSpecies.facialHairType == type then
							sbq.facialHairTypeIndex = i
						end
					end
					for i, type in ipairs(data.facialMask) do
						if sbq.currentCustomSpecies.facialMaskType == type then
							sbq.facialMaskTypeIndex = i
						end
					end
					speciesGenderToggle:setImage(data.image)
				end
			end

			if not hidePanels then speciesCardSlot:setItem(nil, true) return end

			sbq.generateItemCard(sbq.currentCustomSpecies)

			speciesCustomColorText:setText(sbq.currentCustomSpecies.directives)
			speciesBodyColorText:setText(sbq.currentCustomSpecies.bodyDirectives)
			speciesHairColorText:setText(sbq.currentCustomSpecies.hairDirectives)
			speciesFacialHairColorText:setText(sbq.currentCustomSpecies.facialHairDirectives)
			speciesFacialMaskColorText:setText(sbq.currentCustomSpecies.facialMaskDirectives)
			speciesEmoteColorText:setText(sbq.currentCustomSpecies.emoteDirectives)

			speciesHairTypeLabel:setText(sbq.currentCustomSpecies.hairType)
			speciesFacialHairTypeLabel:setText(sbq.currentCustomSpecies.facialHairType)
			speciesFacialMaskTypeLabel:setText(sbq.currentCustomSpecies.facialMaskType)

			speciesBodyColorNameLabel:setText(speciesFile.charGenTextLabels[1])
			speciesHairTypeNameLabel:setText(speciesFile.charGenTextLabels[2])
			local visible = false
			if speciesFile.altOptionAsFacialMask then
				visible = true
				speciesFacialMaskTypeNameLabel:setText(speciesFile.charGenTextLabels[5])
			end
			speciesFacialMaskTypeNameLabel:setVisible(visible)
			speciesFacialMaskTypeLabel:setVisible(visible)
			incSpeciesFacialMaskType:setVisible(visible)
			decSpeciesFacialMaskType:setVisible(visible)

			visible = false
			if speciesFile.altOptionAsUndyColor then
				visible = true
				speciesUndyColorNameLabel:setText(speciesFile.charGenTextLabels[5])
			end
			speciesUndyColorNameLabel:setVisible(visible)
			speciesUndyColorLabel:setVisible(visible)
			incSpeciesUndyColor:setVisible(visible)
			decSpeciesUndyColor:setVisible(visible)

			visible = false
			if speciesFile.headOptionAsFacialhair then
				visible = true
				speciesFacialHairTypeNameLabel:setText(speciesFile.charGenTextLabels[6])
			end
			speciesFacialHairTypeNameLabel:setVisible(visible)
			speciesFacialHairTypeLabel:setVisible(visible)
			incSpeciesFacialHairType:setVisible(visible)
			decSpeciesFacialHairType:setVisible(visible)

			visible = false
			if speciesFile.headOptionAsHairColor then
				visible = true
				speciesHairColorNameLabel:setText(speciesFile.charGenTextLabels[6])
			end
			speciesHairColorNameLabel:setVisible(visible)
			speciesHairColorLabel:setVisible(visible)
			incSpeciesHairColor:setVisible(visible)
			decSpeciesHairColor:setVisible(visible)

			speciesBodyColorLabel:setText(sbq.currentCustomSpecies.bodyColorIndex or 1)
			speciesUndyColorLabel:setText(sbq.currentCustomSpecies.undyColorIndex or 1)
			speciesHairColorLabel:setText(sbq.currentCustomSpecies.hairColorIndex or 1)
		end
	end

	function sbq.changeHairType(inc)
		local index, result = sbq.nextDifferentListEntry(sbq.genderTable.hair, (sbq.hairTypeIndex or 1), inc)
		sbq.hairTypeIndex = index
		sbq.currentCustomSpecies.hairType = result
		speciesHairTypeLabel:setText(result)
		sbq.saveSpeciesCustomize()
	end
	function decSpeciesHairType:onClick() sbq.changeHairType(-1) end
	function incSpeciesHairType:onClick() sbq.changeHairType(1) end

	function sbq.changeFacialHairType(inc)
		local index, result = sbq.nextDifferentListEntry(sbq.genderTable.facialHair, (sbq.facialHairTypeIndex or 1), inc)
		sbq.facialHairTypeIndex = index
		sbq.currentCustomSpecies.facialHairType = result
		speciesFacialHairTypeLabel:setText(result)
		sbq.saveSpeciesCustomize()
	end
	function decSpeciesFacialHairType:onClick() sbq.changeFacialHairType(-1) end
	function incSpeciesFacialHairType:onClick() sbq.changeFacialHairType(1) end

	function sbq.changeFacialMaskType(inc)
		local index, result = sbq.nextDifferentListEntry(sbq.genderTable.facialMask, (sbq.facialMaskTypeIndex or 1), inc)
		sbq.facialMaskTypeIndex = index
		sbq.currentCustomSpecies.facialMaskType = result
		speciesFacialMaskTypeLabel:setText(result)
		sbq.saveSpeciesCustomize()
	end
	function decSpeciesFacialMaskType:onClick() sbq.changeFacialMaskType(-1) end
	function incSpeciesFacialMaskType:onClick() sbq.changeFacialMaskType(1) end

	function sbq.applySpeciesColors()
		local overrideData = sbq.currentCustomSpecies
		local speciesFile = sbq.speciesFile

		local bodyColor = sbq.colorTable((speciesFile.bodyColor or {})[overrideData.bodyColorIndex])
		local undyColor = sbq.colorTable((speciesFile.undyColor or {})[overrideData.undyColorIndex])
		local hairColor = sbq.colorTable((speciesFile.hairColor or {})[overrideData.hairColorIndex])

		overrideData.undyColor = undyColor
		overrideData.bodyColor = bodyColor
		overrideData.hairColor = hairColor

		overrideData.bodyDirectives = bodyColor
		if speciesFile.altOptionAsUndyColor then
			overrideData.bodyDirectives = overrideData.bodyDirectives..undyColor
		end
		if speciesFile.hairColorAsBodySubColor then
			overrideData.bodyDirectives = overrideData.bodyDirectives..hairColor
		end


		if speciesFile.headOptionAsHairColor then
			overrideData.hairDirectives = hairColor
		else
			overrideData.hairDirectives = bodyColor
			hairColor = bodyColor
		end
		if speciesFile.altOptionAsHairColor then
			overrideData.hairDirectives = overrideData.hairDirectives..undyColor
		end
		if speciesFile.bodyColorAsHairSubColor then -- this isn't real
			overrideData.hairDirectives = overrideData.hairDirectives..bodyColor
		end


		overrideData.facialHairDirectives = overrideData.hairDirectives


		overrideData.facialMaskDirectives = hairColor
		if speciesFile.bodyColorAsFacialMaskSubColor then
			overrideData.facialMaskDirectives = overrideData.facialMaskDirectives..bodyColor
		end
		if speciesFile.altColorAsFacialMaskSubColor then
			overrideData.facialMaskDirectives = overrideData.facialMaskDirectives..undyColor
		end

		overrideData.emoteDirectives = overrideData.bodyDirectives

		speciesBodyColorText:setText(sbq.currentCustomSpecies.bodyDirectives)
		speciesHairColorText:setText(sbq.currentCustomSpecies.hairDirectives)
		speciesFacialHairColorText:setText(sbq.currentCustomSpecies.facialHairDirectives)
		speciesFacialMaskColorText:setText(sbq.currentCustomSpecies.facialMaskDirectives)
		speciesEmoteColorText:setText(sbq.currentCustomSpecies.emoteDirectives)

		sbq.saveSpeciesCustomize()
	end

	function sbq.changeSpeciesBodyColor(inc)
		local index = (sbq.currentCustomSpecies.bodyColorIndex or 1) + inc
		local list = sbq.speciesFile.bodyColor
		if index > #list then
			index = 1
		elseif index < 1 then
			index = #list
		end
		sbq.currentCustomSpecies.bodyColorIndex = index
		speciesBodyColorLabel:setText(index)
		sbq.applySpeciesColors()
	end
	function decSpeciesBodyColor:onClick() sbq.changeSpeciesBodyColor(-1) end
	function incSpeciesBodyColor:onClick() sbq.changeSpeciesBodyColor(1) end

	function sbq.changeSpeciesUndyColor(inc)
		local index = (sbq.currentCustomSpecies.undyColorIndex or 1) + inc
		local list = sbq.speciesFile.undyColor
		if index > #list then
			index = 1
		elseif index < 1 then
			index = #list
		end
		sbq.currentCustomSpecies.undyColorIndex = index
		speciesUndyColorLabel:setText(index)
		sbq.applySpeciesColors()
	end
	function decSpeciesUndyColor:onClick() sbq.changeSpeciesUndyColor(-1) end
	function incSpeciesUndyColor:onClick() sbq.changeSpeciesUndyColor(1) end

	function sbq.changeSpeciesHairColor(inc)
		local index = (sbq.currentCustomSpecies.hairColorIndex or 1) + inc
		local list = sbq.speciesFile.hairColor
		if index > #list then
			index = 1
		elseif index < 1 then
			index = #list
		end
		sbq.currentCustomSpecies.hairColorIndex = index
		speciesHairColorLabel:setText(index)
		sbq.applySpeciesColors()
	end
	function decSpeciesHairColor:onClick() sbq.changeSpeciesHairColor(-1) end
	function incSpeciesHairColor:onClick() sbq.changeSpeciesHairColor(1) end

	function speciesCustomColorText:onEnter() sbq.saveSpeciesCustomize() end


	function sbq.saveSpeciesCustomize()
		sbq.currentCustomSpecies.bodyDirectives = speciesBodyColorText.text
		sbq.currentCustomSpecies.hairDirectives = speciesHairColorText.text
		sbq.currentCustomSpecies.facialHairDirectives = speciesFacialHairColorText.text
		sbq.currentCustomSpecies.facialMaskDirectives = speciesFacialMaskColorText.text
		sbq.currentCustomSpecies.emoteDirectives = speciesEmoteColorText.text
		sbq.currentCustomSpecies.directives = speciesCustomColorText.text

		status.setStatusProperty("sbqCustomizedSpecies", sbq.customizedSpecies )
		applySpecies:onClick()
	end

	sbq.changeSpecies(0)
end

function sbq.colorTable(input)
	local result = ""
	if type(input) == "table" then
		result = "?replace"
		for color, replace in pairs(input) do
			result = result..";"..color.."="..replace
		end
	end
	return result
end

--------------------------------------------------------------------------------------------------

function sbq.saveDigestedPrey()
	status.setStatusProperty("sbqStoredDigestedPrey", sbq.storedDigestedPrey)
end
