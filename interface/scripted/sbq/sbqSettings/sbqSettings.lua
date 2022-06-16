
---@diagnostic disable:undefined-global

require( "/lib/stardust/json.lua" )

sbq = {
	extraTabs = root.assetJson("/interface/scripted/sbq/sbqSettings/sbqSettingsTabs.json"),
	config = root.assetJson( "/sbqGeneral.config" )

}

require("/scripts/SBQ_RPC_handling.lua")
require("/scripts/speciesAnimOverride_player_species.lua")
require("/interface/scripted/sbq/sbqSettings/sbqSettingsLocationPanel.lua")

function sbq.getPatronsString()
	local patronsString = ""
	for _, patron in ipairs(root.assetJson("/patrons.json")) do
		patronsString = patronsString..patron.."^reset;\n"
	end
	return patronsString
end
sbq.patronsString = sbq.getPatronsString()

function sbq.getInitialData()
	sbq.sbqSettings = player.getProperty("sbqSettings") or {}

	sbq.sbqCurrentData = player.getProperty("sbqCurrentData") or {}
	sbq.lastSpecies = sbq.sbqCurrentData.species
	sbq.lastType = sbq.sbqCurrentData.type

	if sbq.sbqCurrentData.type == "prey" then
		mainTabField.tabs.globalPredSettings:setVisible(false)
	else
		mainTabField.tabs.globalPredSettings:setVisible(true)
	end

	sbq.predatorEntity = player.loungingIn() or sbq.sbqCurrentData.id
end

function sbq.getHelpTab()
	if sbq.extraTabs.speciesHelpTabs[sbq.sbqCurrentData.species] ~= nil then
		sbq.speciesHelpTab = mainTabField:newTab( sbq.extraTabs.speciesHelpTabs[sbq.sbqCurrentData.species] )
	end
end

function init()

	sbq.getInitialData()

	sbq.globalSettings = sbq.sbqSettings.global or sbq.config.defaultSettings

	if sbq.sbqCurrentData.species ~= nil then
		if sbq.sbqCurrentData.species == "sbqOccupantHolder" then
			local species = player.species()
			local registry = root.assetJson("/humanoid/sbqDataRegistry.config")
			local path = registry[species] or "/humanoid/sbqData.config"
			if path:sub(1,1) ~= "/" then
				path = "/humanoid/"..species.."/"..path
			end
			sbq.predatorConfig = root.assetJson(path).sbqData


			local mergeConfigs = sbq.predatorConfig.merge or {}
			local configs = { sbq.predatorConfig }
			while type(mergeConfigs[#mergeConfigs]) == "string" do
				local insertPos = #mergeConfigs
				local newConfig = root.assetJson(mergeConfigs[#mergeConfigs]).sbqData
				for i = #(newConfig.merge or {}), 1, -1 do
					table.insert(mergeConfigs, insertPos, newConfig.merge[i])
				end

				table.insert(configs, 1, newConfig)

				table.remove(mergeConfigs, #mergeConfigs)
			end
			local scripts = {}
			local finalConfig = {}
			for i, config in ipairs(configs) do
				finalConfig = sb.jsonMerge(finalConfig, config)
				for j, script in ipairs(config.scripts or {}) do
					table.insert(scripts, script)
				end
			end
			sbq.predatorConfig = finalConfig
			sbq.predatorConfig.scripts = scripts
		else
			sbq.predatorConfig = root.assetJson("/vehicles/sbq/"..sbq.sbqCurrentData.species.."/"..sbq.sbqCurrentData.species..".vehicle").sbqData or {}
		end
		sbq.predatorSettings = sb.jsonMerge(sb.jsonMerge(sb.jsonMerge(sbq.config.defaultSettings, sbq.predatorConfig.defaultSettings or {}), sbq.sbqSettings[sbq.sbqCurrentData.species] or {}), sbq.globalSettings)
	else
		sbq.predatorConfig = {}
		sbq.predatorSettings = sb.jsonMerge(sbq.config.defaultSettings, sbq.globalSettings)
	end

	sbq.locationPanel()

	if ((sbq.sbqCurrentData.type ~= "prey") or (sbq.sbqCurrentData.type == "object")) then
		mainTabField.tabs.customizeTab:setVisible(true)

		if sbq.predatorConfig.customizePresets ~= nil then
			presetsPanel:setVisible(true)
			sbq.preset = 1
			presetText:setText(sbq.predatorSettings.presetText or sbq.predatorConfig.presetList[sbq.preset])
		else
			presetsPanel:setVisible(false)
		end
		if not player.loungingIn() and sbq.sbqCurrentData.type ~= "object" and player.isAdmin() then
			speciesPanel:setVisible(true)
		elseif sbq.sbqCurrentData.type ~= "object" then
			speciesPanel:setVisible(false)
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

	if sbq.speciesSettingsTab ~= nil then
		sbq.speciesSettingsTab:setVisible(false)
		sbq.speciesSettingsTab = nil
	end
	local species = sbq.sbqCurrentData.species
	local playerSpecies = player.species()
	if species == "sbqOccupantHolder" and sbq.extraTabs.speciesSettingsTabs[playerSpecies] ~= nil then
		species = playerSpecies
	end
	if sbq.extraTabs.speciesSettingsTabs[species] ~= nil then
		sbq.speciesSettingsTab = mainTabField:newTab( sbq.extraTabs.speciesSettingsTabs[species].tab )
		sbq.setIconDirectives()
		if sbq.extraTabs.speciesSettingsTabs[species].scripts ~= nil then
			for _, script in ipairs(sbq.extraTabs.speciesSettingsTabs[species].scripts) do
				require(script)
			end
		end
	end

	if sbq.speciesHelpTab ~= nil then
		sbq.speciesHelpTab:setVisible(false)
		sbq.speciesHelpTab = nil
	end

	sbq.getHelpTab()

	if sbq.helpTab ~= nil then
		sbq.helpTab:setVisible(false)
		sbq.helpTab = nil
	end

	sbq.helpTab = mainTabField:newTab( sbq.extraTabs.helpTab )
	patronsLabel:setText(sbq.patronsString)

	if root.itemConfig("vorechipkit") ~= nil then
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

	BENone:selectValue(sbq.globalSettings.bellyEffect or "sbqRemoveBellyEffects")
	escapeValue:setText(tostring(sbq.globalSettings.escapeDifficulty or 0))

	for setting, value in pairs(sbq.predatorSettings) do
		local button = _ENV[setting]
		if button ~= nil and type(value) == "boolean" then
			button:setChecked(value)
			function button:onClick()
				sbq.changePredatorSetting(setting, button.checked)
			end
		end
	end
	for setting, value in pairs(sbq.globalSettings) do
		local button = _ENV[setting]
		if button ~= nil and type(value) == "boolean" then
			button:setChecked(value)
			function button:onClick()
				sbq.changeGlobalSetting(setting, button.checked)
			end
		end
	end

	function hammerspace:onClick() -- only one that has unique logic
		sbq.changeGlobalSetting("hammerspace", hammerspace.checked)
		sbq.locationPanel()
	end

end
local init = init

function update()
	sbq.sbqCurrentData = player.getProperty("sbqCurrentData") or {}
	if sbq.sbqCurrentData.species ~= sbq.lastSpecies or sbq.sbqCurrentData.type ~= sbq.lastType then
		init()
	end
end

--------------------------------------------------------------------------------------------------

function sbq.saveSettings()
	if sbq.predatorEntity ~= nil and sbq.sbqCurrentData.type == "driver" then
		world.sendEntityMessage( sbq.predatorEntity, "settingsMenuSet", sb.jsonMerge(sbq.predatorSettings, sbq.globalSettings))
	end

	sbq.sbqSettings[sbq.sbqCurrentData.species or "sbqOccupantHolder"] = sbq.predatorSettings
	sbq.sbqSettings.global = sbq.globalSettings
	player.setProperty( "sbqSettings", sbq.sbqSettings )
	world.sendEntityMessage( player.id(), "sbqRefreshSettings", sbq.sbqSettings )
end

function sbq.changeGlobalSetting(settingname, settingvalue)
	sbq.globalSettings[settingname] = settingvalue
	sbq.predatorSettings[settingname] = settingvalue

	sbq.saveSettings()
end

function sbq.changePredatorSetting(settingname, settingvalue)
	sbq.predatorSettings[settingname] = settingvalue

	sbq.saveSettings()
end

function sbq.setBellyEffect()
	sbq.changeGlobalSetting("bellyEffect", BENone:getGroupValue())
end

function sbq.changeEscapeModifier(inc)
	sbq.changeGlobalSetting("escapeDifficulty", (sbq.globalSettings.escapeDifficulty or 0) + inc)
	escapeValue:setText(tostring(sbq.globalSettings.escapeDifficulty or 0))
end

function sbq.changePreySetting(settingname, settingvalue)
	sbq.sbqPreyEnabled = status.statusProperty("sbqPreyEnabled") or {}
	sbq.sbqPreyEnabled[settingname] = settingvalue
	status.setStatusProperty("sbqPreyEnabled", sbq.sbqPreyEnabled)
end

function sbq.setIconDirectives()
	if sbq.speciesSettingsTab ~= nil then
		sbq.speciesSettingsTab:setTitle("Config", "/vehicles/sbq/"..sbq.sbqCurrentData.species.."/skins/"..((sbq.predatorSettings.skinNames or {}).head or "default").."/icon.png"..(sbq.predatorSettings.directives or ""))
	end
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
					color = color.."fb"
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


sbq.speciesOverrideIndex = 1
function sbq.changeSpecies(inc)
	local speciesIndex = (sbq.speciesOverrideIndex or 1) + inc
	if speciesIndex > #sbq.extraTabs.speciesPresetList then
		speciesIndex = 1
	elseif speciesIndex < 1 then
		speciesIndex = #sbq.extraTabs.speciesPresetList
	end
	sbq.speciesOverrideIndex = speciesIndex
	speciesText:setText(sbq.extraTabs.speciesPresetList[sbq.speciesOverrideIndex])
end

--------------------------------------------------------------------------------------------------

function BENone:onClick()
	sbq.setBellyEffect()
end

function BEHeal:onClick()
	sbq.setBellyEffect()
end

function BEDigest:onClick()
	sbq.setBellyEffect()
end

function BESoftDigest:onClick()
	sbq.setBellyEffect()
end

--------------------------------------------------------------------------------------------------

function decEscape:onClick()
	sbq.changeEscapeModifier(-1)
end

function incEscape:onClick()
	sbq.changeEscapeModifier(1)
end

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
if speciesPanel ~= nil then
	function decSpecies:onClick()
		sbq.changeSpecies(-1)
	end

	function incSpecies:onClick()
		sbq.changeSpecies(1)
	end

	function applySpecies:onClick()
		if speciesText.text ~= "" then
			local table = { species = speciesText.text }
			if type(sbq.extraTabs.speciesPresets[speciesText.text]) == "table" then
				table = sbq.extraTabs.speciesPresets[speciesText.text]
			end
			local success, table2 = pcall(json.decode, speciesText.text )
			if success and type(table2) == "table" then
				table = table2
			end
			status.clearPersistentEffects("speciesAnimOverride")
			status.setStatusProperty("speciesAnimOverrideData", table)
			status.setPersistentEffects("speciesAnimOverride", { table.customAnimStatus or "speciesAnimOverride"})
		else
			status.clearPersistentEffects("speciesAnimOverride")
			status.setStatusProperty("speciesAnimOverrideData", nil)
		end
	end
	function speciesText:onEnter()
		applySpecies:onClick()
	end
end

--------------------------------------------------------------------------------------------------


if mainTabField.tabs.globalPreySettings ~= nil then
	sbq.sbqPreyEnabled = sb.jsonMerge(sbq.config.defaultPreyEnabled.player, status.statusProperty("sbqPreyEnabled") or {})

	for setting, value in pairs(sbq.sbqPreyEnabled) do
		local button = _ENV[setting]
		if button ~= nil and type(value) == "boolean" then
			button:setChecked(value)
			function button:onClick()
				sbq.changePreySetting(setting, button.checked)
			end
		end
	end

	function digestImmunity:onClick()
		sbq.changePreySetting("digestImmunity", digestImmunity.checked)
		if digestImmunity.checked then
			status.setPersistentEffects("digestImmunity", {"sbqDigestImmunity"})
		else
			status.clearPersistentEffects("digestImmunity")
		end
	end

	function cumDigestImmunity:onClick()
		sbq.changePreySetting("cumDigestImmunity", cumDigestImmunity.checked)
		if cumDigestImmunity.checked then
			status.setPersistentEffects("cumDigestImmunity", {"sbqCumDigestImmunity"})
		else
			status.clearPersistentEffects("cumDigestImmunity")
		end
	end
end
--------------------------------------------------------------------------------------------------
