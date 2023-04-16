---@diagnostic disable:undefined-global

function sbq.checkSettings(checkSettings, settings)
	for setting, value in pairs(checkSettings or {}) do
		if (type(settings[setting]) == "table") and settings[setting].name ~= nil then
			if not value then return false
			elseif type(value) == "table" then
				if not sbq.checkTable(value, settings[setting]) then return false end
			end
		elseif type(value) == "table" then
			local match = false
			for i, value in ipairs(value) do if (settings[setting] or false) == value then
				match = true
				break
			end end
			if not match then return false end
		elseif (settings[setting] or false) ~= value then return false
		end
	end
	return true
end

function sbq.checkTable(check, checked)
	for k, v in pairs(check) do
		if type(v) == "table" then
			if not sbq.checkTable(v, (checked or {})[k]) then return false end
		elseif v == true and type((checked or {})[k]) ~= "boolean" and ((checked or {})[k]) ~= nil then
		elseif not (v == (checked or {})[k] or false) then return false
		end
	end
	return true
end

sbq.drawSpecialButtons = {}
function sbq.effectsPanel()
	sbq.locationTabs = {}
	if not sbq.predatorConfig or not sbq.predatorConfig.locations then return end
	locationTabLayout:clearChildren()
	locationTabLayout:addChild({ id = "locationTabField", type = "tabField", layout = "vertical", tabWidth = 40, tabs = {} })
	mainTabField.subTabs.globalPredSettings = {locationTabField}

	for i, location in ipairs(sbq.predatorConfig.listLocations or {}) do
		local tab = sbq.updateLocationTab(location)
		if i == 1 then
			tab:select()
		end
	end
end
sbq.locationTabs = {}
function sbq.updateLocationTab(location)
	local locationData = sbq.predatorConfig.locations[location]
	if type(locationData) == "table" then
		sbq.locationDefaultSettings(locationData, location)


		local requiresInfusionVisible = true
		if locationData.requiresInfusion then
			requiresInfusionVisible = sbq.infusionSlotAccepts(locationData, sbq.predatorSettings[location .. "InfusedItem"])
		end

		local mainEffectLayout = { type = "panel", style = "flat", visible = requiresInfusionVisible and locationData.selectEffect or false, expandMode = {1,0}, children = {
			{ type = "layout", mode = "horizontal", spacing = 0, expandMode = {1,0}, size = {100, 20}, children = {
				{
					{
						{
							type = "checkBox", id = location.."None", checked = sbq.predatorSettings[location.."EffectSlot"] == "none" or sbq.predatorSettings[location.."EffectSlot"] == nil,
							radioGroup = location.."EffectGroup", value = "none",
							visible = (locationData.selectEffect and not ((sbq.overrideSettings[location.."Effect"] ~= nil and sbq.overrideSettings[location.."EffectSlot"] ~= "none" ) or (sbq.overrideSettings[location.."NoneEnable"] == false) or (sbq.overrideSettings.noneEnable == false) or (locationData.none == false))) or false,
							toolTip = ((locationData.none or {}).toolTip or "No effects will be applied to prey.")
						},{
							type = "checkBox", id = location.."Heal", checked = sbq.predatorSettings[location.."EffectSlot"] == "heal",
							radioGroup = location.."EffectGroup", value = "heal",
							visible = (locationData.selectEffect and not ((sbq.overrideSettings[location.."Effect"] ~= nil and sbq.overrideSettings[location.."EffectSlot"] ~= "heal" ) or (sbq.overrideSettings[location.."HealEnable"] == false) or (sbq.overrideSettings.healEnable == false) or (locationData.heal == false))) or false,
							toolTip = ((locationData.heal or {}).toolTip or "Prey within will be healed, boosted by your attack power.")
						},{
							type = "checkBox", id = location.."SoftDigest", checked = sbq.predatorSettings[location.."EffectSlot"] == "softDigest",
							radioGroup = location.."EffectGroup", value = "softDigest",
							visible = (locationData.selectEffect and not ((sbq.overrideSettings[location.."Effect"] ~= nil and sbq.overrideSettings[location.."EffectSlot"] ~= "softDigest") or (sbq.overrideSettings[location.."SoftDigestEnable"] == false) or (sbq.overrideSettings.softDigestEnable == false) or (locationData.softDigest == false))) or false,
							toolTip = ((locationData.softDigest or {}).toolTip or "Prey within will be digested, boosted by your attack power.\nBut they will always retain 1HP.")
						},{
							type = "checkBox", id = location.."Digest", checked = sbq.predatorSettings[location.."EffectSlot"] == "digest",
							radioGroup = location.."EffectGroup", value = "digest",
							visible = (locationData.selectEffect and not ((sbq.overrideSettings[location.."Effect"] ~= nil and sbq.overrideSettings[location.."Effect"] ~= "digest") or (sbq.overrideSettings[location.."DigestEnable"] == false) or (sbq.overrideSettings.digestEnable == false) or (locationData.digest == false))) or false,
							toolTip = ((locationData.digest or {}).toolTip or "Prey within will be digested, boosted by your attack power.")
						},
					}, {}
				},
				{type = "spacer", size = 1},
				{type = "label", align = "center", id = location.."EffectLabel", text = (sbq.config.bellyStatusEffectNames[sbq.getStatusEffectSlot(location, locationData)] or "No Effect")},
			}}
		} }

		local extraEffectToggles = {}
		local extraEffectsVisible = false
		for i, extraEffect in ipairs(locationData.passiveToggles or {}) do
			local toggleData = locationData[extraEffect]
			if toggleData then
				extraEffectsVisible = extraEffectsVisible or ((locationData[extraEffect] and not (sbq.overrideSettings[location..extraEffect] ~= nil)) or false)

				sbq.predatorSettings[location..extraEffect] = sbq.predatorSettings[location..extraEffect] or false
				table.insert(extraEffectToggles,{
					type = "checkBox", id = location..extraEffect, checked = sbq.predatorSettings[location..extraEffect],
					visible = (locationData[extraEffect] and not (sbq.overrideSettings[location..extraEffect] ~= nil)) or false,
					toolTip = ((locationData[extraEffect] or {}).toolTip or "Prey within will be transformed.")
				})
			end
		end
		local extraEffectLayout = { type = "panel", style = "flat", expandMode = {1,0}, visible = requiresInfusionVisible and extraEffectsVisible, children = {
			{ type = "layout", mode = "vertical", spacing = 0, children = {
				extraEffectToggles
			}}
		} }
		local digestDropsVisible = (
			((locationData.selectEffect and not ((sbq.overrideSettings[location.."Effect"] ~= nil and sbq.overrideSettings[location.."EffectSlot"] ~= "softDigest") or (sbq.overrideSettings[location.."SoftDigestEnable"] == false) or (sbq.overrideSettings.softDigestEnable == false) or (locationData.softDigest == false))) or false)
			or ((locationData.selectEffect and not ((sbq.overrideSettings[location.."Effect"] ~= nil and sbq.overrideSettings[location.."Effect"] ~= "digest") or (sbq.overrideSettings[location.."DigestEnable"] == false) or (sbq.overrideSettings.digestEnable == false) or (locationData.digest == false))) or false)
		)
		local otherLayout = { type = "panel", style = "flat", visible = requiresInfusionVisible or false, expandMode = {1,0}, children = {
			{ type = "layout", mode = "vertical", spacing = 0, children = {
				{
					{
						type = "checkBox", id = location.."PredDigestDrops", checked = sbq.globalSettings[location.."PredDigestDrops"],
						toolTip = "Prey may drop an item upon digestion.", visible = digestDropsVisible
					},
					{ type = "label", text = "Digest Drops", visible = digestDropsVisible }
				},
				{
					{
						type = "checkBox", id = location.."Sounds", checked = sbq.globalSettings[location.."Sounds"],
						toolTip = "Will emit gurgling sounds when prey is within."
					},
					{ type = "label", text = "Gurgling Sounds" }
				},
				{
					{
						type = "checkBox", id = location.."StruggleSounds", checked = sbq.globalSettings[location.."StruggleSounds"],
						toolTip = "Will emit sounds when a prey struggles."
					},
					{ type = "label", text = "Struggle Sounds" }
				}
			}}
		}}

		local n1 = sbq.overrideSettings[location.."VisualMin"] or locationData.minVisual or 0
		local n2 = sbq.overrideSettings[location.."VisualMax"] or locationData.maxVisual or locationData.max or 1
		local notches = (locationData.sizes or {}).struggle
		if not notches then
			notches = {}
			for i = n1, n2 do
				table.insert(notches, i)
			end
		end
		local min = sbq.overrideSettings[location .. "VisualMin"] or locationData.minVisual or 0
		local max = sbq.overrideSettings[location .. "VisualMax"] or locationData.maxVisual or locationData.max or 1

		local modifiersLayout = { type = "panel", style = "flat", visible = requiresInfusionVisible or false, expandMode = {1,0}, children = {
			{ type = "layout", mode = "vertical", spacing = 0, children = {
				{type = "label", text = "Size Modifiers", align = "center"},
				{
					{ spacing = -1 },
					{ type = "checkBox", id = location .. "VisualMinAdditive", checked = sbq.predatorSettings[location .. "VisualMinAdditive"], toolTip = "Whether the Minimum actually counts towards the fill level." },
						{ type = "slider", id = location .. "VisualSize", notches = notches,
							handles = {
								{ value = math.max(min, sbq.predatorSettings[location .. "VisualMin"] or min), locked = sbq.overrideSettings[location .. "VisualMin"] ~= nil, toolTip = "Minimum Visual Size" },
								{ value = math.min(max, sbq.predatorSettings[location .. "VisualMax"] or max), locked = sbq.overrideSettings[location .. "VisualMax"] ~= nil, toolTip = "Maximum Visual Size" }
							}
						},
					{ type = "textBox", align = "center", id = location .. "Multiplier", size = {25,14}, expandMode = {0,0}, toolTip = "Fill Level Multiplier"},
				},
				{
					{ type = "checkBox", id = location .. "Hammerspace",
						checked = sbq.predatorSettings[location .. "Hammerspace"],
						toolTip = "This location will ignore the size limit.",
						visible = locationData.hammerspace or false
					},
					{ type = "label", text = "Hammerspace", visible = locationData.hammerspace or false}
				},
				{
					{ type = "checkBox", id = location .. "Compression", checked = sbq.predatorSettings[location .. "Compression"], toolTip = "Prey will be compressed to a smaller size over time." },
					{ type = "label", text = "Compression " },
					{ type = "textBox", align = "center", id = location .. "CompressionMultiplier", size = {25,14}, expandMode = {0,0}, toolTip = "Minimum multiplier compression can apply."},
				}
			}}
		} }
		local difficultyMod = { type = "panel", style = "flat", visible = requiresInfusionVisible or false, expandMode = {0,1}, size = {50, 30}, children = {
			{ type = "layout", mode = "vertical", spacing = 0, children = {
				{type = "label", text = "Difficulty", align = "center"},
				{ type = "textBox", align = "center", id = location .. "DifficultyMod", size = {30,14}, expandMode = {0,0}, toolTip = "Make this location easier or harder relative to the main difficulty."},
			}}
		} }
		local InfusionPanel = { type = "panel", style = "flat", expandMode = {1,1}, visible = locationData.infusion or false, children = {
			{ type = "layout", mode = "vertical", spacing = -2, children = {
				{type = "label", text = "Infusion", align = "center"},
				{
					{ expandMode = {0,0}, spacing = -2, },
					{ type = "itemSlot", autoInteract = true, id = location .. "InfusedItem", item = sbq.predatorSettings[location .. "InfusedItem"] },
					{
						{ mode = "h", spacing = -2 },
						{ type = "checkBox", id = location .. "InfusedVisual", checked = sbq.predatorSettings[location .. "InfusedVisual"], toolTip = "Change colors to match infused character if applicable.", visible = locationData.infusedVisual or false },
						{
							{ spacing = -2, expandMode = {0,0}, },
							{ type = "checkBox", id = location .. "InfusedSize", checked = sbq.predatorSettings[location .. "InfusedSize"], toolTip = "Add infused character's size if applicable." },
							{ type = "checkBox", id = location .. "InfusedSizeAdditive", checked = sbq.predatorSettings[location .. "InfusedSizeAdditive"], toolTip = "If adding a character's size, make it count towards the fill level." },
						},
						{ type = "textBox", align = "center", id = location .. "InfusedMultiplier", size = {25,14}, expandMode = {0,0}, toolTip = "Size Multiplier on Infused Characters if size is being added."},
					}
				}
			}}
		} }
		local absorbedPreyList
		local absorbedPreyPanel = { type = "panel", style = "flat", expandMode = {1,0}, children = {
			{ type = "layout", mode = "vertical", spacing = 0, children = {
				{
					{ type = "label", text = "Absorbed Prey", align = "center" },
					{ type = "checkBox", id = location .. "AbsorbPlayers", checked = sbq.predatorSettings[location .. "AbsorbPlayers"], toolTip = "Absorb Players upon Digestion." },
					{ type = "checkBox", id = location .. "AbsorbOCs", checked = sbq.predatorSettings[location .. "AbsorbOCs"], toolTip = "Absorb OCs upon Digestion." },
					{ type = "checkBox", id = location .. "AbsorbSBQNPCs", checked = sbq.predatorSettings[location .. "AbsorbSBQNPCs"], toolTip = "Absorb SBQ NPCs upon Digestion." },
					{ type = "checkBox", id = location .. "AbsorbOthers", checked = sbq.predatorSettings[location .. "AbsorbOthers"], toolTip = "Absorb any other NPCs upon Digestion." },
				},
				{ type = "itemGrid", slots = 5, id = location .. "ItemGrid", autoInteract = true },
				{ type = "label", text = "Clear Prey", align = "center" },
				{
					{ type = "button", id = location .. "ClearPlayers", caption = "Players", toolTip = "Clear Absorbed Players" },
					{ type = "button", id = location .. "ClearOCs", caption = "OCs", toolTip = "Clear Absorbed OCs" },
				},
				{
					{ type = "button", id = location .. "ClearSBQNPCs", caption = "SBQ NPCs", toolTip = "Clear SBQ NPCs" },
					{ type = "button", id = location .. "ClearOthers", caption = "Others", toolTip = "Clear any Other NPCs" },
				}
			}}
		} }
		local count = 5
		if type(sbq.storedDigestedPrey[location]) == "table" then
			local players = {}
			local ocs = {}
			local sbqNPCs = {}
			local other = {}
			for uniqueId, item in pairs(sbq.storedDigestedPrey[location]) do
				count = count + 1
				local success, npcConfig = pcall(root.npcConfig, item.parameters.npcArgs.npcType)
				if not success then
					npcConfig = item.parameters.npcArgs.npcParam
				end
				if item.parameters.npcArgs.npcParam.wasPlayer then
					item.parameters.rarity = "legendary"
					table.insert(players, item)
				elseif ((npcConfig or {}).scriptConfig or {}).isOC then
					item.parameters.rarity = "rare"
					table.insert(ocs, item)
				elseif ((npcConfig or {}).scriptConfig or {}).sbqNPC then
					item.parameters.rarity = "uncommon"
					table.insert(sbqNPCs, item)
				else
					item.parameters.rarity = "common"
					table.insert(other, item)
				end
			end
			count = (count + 5) - ((count + 5) % 5)
			local function sortItems(a, b)
				return a.parameters.shortdescription < b.parameters.shortdescription
			end
			table.sort(players, sortItems)
			table.sort(ocs, sortItems)
			table.sort(sbqNPCs, sortItems)
			table.sort(other, sortItems)
			absorbedPreyList = players
			util.appendLists(absorbedPreyList, ocs)
			util.appendLists(absorbedPreyList, sbqNPCs)
			util.appendLists(absorbedPreyList, other)
			absorbedPreyPanel.children[1].children[2].slots = count
		end

		local tab
		if sbq.locationTabs[location] then
			tab = sbq.locationTabs[location]
			tab:setVisible(sbq.checkSettings(locationData.checkSettings, sbq.predatorSettings))
			local scrollArea = _ENV[location.."TabScrollArea"]
			scrollArea:clearChildren()
		else
			tab = locationTabField:newTab({
				type = "tab", id = location .. "Tab", title = ((locationData.name or location) .. " "), visible = sbq.checkSettings(locationData.checkSettings, sbq.predatorSettings),
				contents = {
					{ id = location.."TabScrollArea", type = "scrollArea", scrollBars = true, thumbScrolling = true, scrollDirections = {0,1}, children = {
					}}
				}
			})
		end
		local scrollArea = _ENV[location.."TabScrollArea"]
		scrollArea:addChild(
			{ type = "panel", style = "convex", children = {
				mainEffectLayout,
				extraEffectLayout,
				otherLayout,
				modifiersLayout,
				{ type = "layout", mode = "horizontal", expandMode = {1,0}, size = {100, 30}, children = {difficultyMod, InfusionPanel} },
				absorbedPreyPanel
			} }
		)
		sbq.locationTabs[location] = tab

		local itemGrid = _ENV[location .. "ItemGrid"]
		for i, item in ipairs(absorbedPreyList or {}) do
			itemGrid:setItem(i, item)
		end
		for i = 1, count do
			local itemSlot = itemGrid:slot(i)
			function itemSlot:acceptsItem(item)
				if not ((((item.parameters or {}).npcArgs or {}).npcParam or {}).scriptConfig or {}).uniqueId then pane.playSound("/sfx/interface/clickon_error.ogg") return false end

				local preySettings = sbq.getItemPreySettings(item)

				local validPrey = true
				for i, voreType in ipairs(locationData.voreTypes or {}) do
					validPrey = preySettings[voreType]
					if validPrey then return true end
				end
				if not validPrey then
					pane.playSound("/sfx/interface/clickon_error.ogg")
					return false
				end
				return true
			end
			function itemSlot:onItemModified()
				local itemList = {}
				for i = 1, count do
					local item = itemGrid:item(i)
					if item then
						table.insert(itemList, item)
					end
				end
				sbq.storedDigestedPrey[location] = {}
				for i, item in ipairs(itemList) do
					local uniqueId = item.parameters.npcArgs.npcParam.scriptConfig.uniqueId
					sbq.storedDigestedPrey[location][uniqueId] = item
				end
				sbq.saveDigestedPrey()
			end
		end

		local infusedItemSlot = _ENV[location .. "InfusedItem"]

		function infusedItemSlot:acceptsItem(item)
			if sbq.infusionSlotAccepts(locationData, item) then return true
			else pane.playSound("/sfx/interface/clickon_error.ogg") return false end
		end
		function infusedItemSlot:onItemModified()
			sbq.changeGlobalSetting(location .. "InfusedItem", infusedItemSlot:item())
			sbq.getOccupantHolderData(sbq.predatorSettings)
			sbq.updateLocationTab(location)
			sbq.refreshButtons()
		end

		for i, extraEffect in ipairs(locationData.passiveToggles or {}) do
			local toggleData = locationData[extraEffect]
			if toggleData then
				local toggleButton = _ENV[location .. extraEffect]
				if toggleButton ~= nil then
					function toggleButton:drawSpecial() sbq.drawEffectButton(toggleButton, ((locationData[extraEffect] or {}).icon or "/interface/scripted/sbq/sbqSettings/transform.png")) end
					sbq.drawSpecialButtons[location .. extraEffect] = true
				end
			end
		end

		local noneButton = _ENV[location.."None"]
		local healButton = _ENV[location.."Heal"]
		local softDigestButton = _ENV[location.."SoftDigest"]
		local digestButton = _ENV[location.."Digest"]
		local effectLabel = _ENV[location.."EffectLabel"]

		function noneButton:draw() sbq.drawEffectButton(noneButton, ((locationData.none or {}).icon or "/interface/scripted/sbq/sbqSettings/noEffect.png") ) end
		function healButton:draw() sbq.drawEffectButton(healButton, ((locationData.heal or {}).icon or "/interface/scripted/sbq/sbqSettings/heal.png")) end
		function softDigestButton:draw() sbq.drawEffectButton(softDigestButton, ((locationData.softDigest or {}).icon or "/interface/scripted/sbq/sbqSettings/softDigest.png")) end
		function digestButton:draw() sbq.drawEffectButton(digestButton, ((locationData.digest or {}).icon or "/interface/scripted/sbq/sbqSettings/digest.png")) end

		function noneButton:onClick() sbq.locationEffectButton(noneButton, location, locationData, effectLabel) end
		function healButton:onClick() sbq.locationEffectButton(healButton, location, locationData, effectLabel) end
		function softDigestButton:onClick() sbq.locationEffectButton(softDigestButton, location, locationData, effectLabel) end
		function digestButton:onClick() sbq.locationEffectButton(digestButton, location, locationData, effectLabel) end

		local visualSize = _ENV[location .. "VisualSize"]
		local multiplier = _ENV[location .. "Multiplier"]
		local difficultyTextbox = _ENV[location.."DifficultyMod"]

		function visualSize:onChange(index, value)
			if index == 1 then
				sbq.changePredatorSetting(location .. "VisualMin", value)
			elseif index == 2 then
				sbq.changePredatorSetting(location .. "VisualMax", value)
			end
		end

		multiplier:setText(tostring(sbq.overrideSettings[location .. "Multiplier"] or sbq.predatorSettings[location .. "Multiplier"] or 1))
		function multiplier:onEnter() sbq.numberBox(self, "changeGlobalSetting", location .. "Multiplier", "globalSettings", "overrideSettings", 0) end
		function multiplier:onTextChanged() sbq.numberBoxColor(self, 0) end
		function multiplier:onEscape() self:onEnter() end
		function multiplier:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end
		sbq.numberBoxColor(multiplier, 0)

		difficultyTextbox:setText(tostring(sbq.overrideSettings[location .. "DifficultyMod"] or sbq.predatorSettings[location .. "DifficultyMod"] or 0))
		function difficultyTextbox:onEnter() sbq.numberBox(self, "changeGlobalSetting", location .. "DifficultyMod", "globalSettings", "overrideSettings", sbq.overrideSettings[location.."DifficultyModMin"], sbq.overrideSettings[location.."DifficultyModMax"]) end
		function difficultyTextbox:onTextChanged() sbq.numberBoxColor(self, sbq.overrideSettings[location.."DifficultyModMin"], sbq.overrideSettings[location.."DifficultyModMax"]) end
		function difficultyTextbox:onEscape() self:onEnter() end
		function difficultyTextbox:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end
		sbq.numberBoxColor(difficultyTextbox, sbq.overrideSettings[location .. "DifficultyModMin"],
			sbq.overrideSettings[location .. "DifficultyModMax"])

		local InfusionMultiplier = _ENV[location .. "InfusedMultiplier"]

		InfusionMultiplier:setText(tostring(sbq.overrideSettings[location .. "InfusedMultiplier"] or sbq.predatorSettings[location .. "InfusedMultiplier"] or sbq.predatorSettings["default".."InfusedMultiplier"] or 0.5))
		function InfusionMultiplier:onEnter() sbq.numberBox(self, "changeGlobalSetting", location .. "InfusedMultiplier", "globalSettings", "overrideSettings", 0) end
		function InfusionMultiplier:onTextChanged() sbq.numberBoxColor(self, 0) end
		function InfusionMultiplier:onEscape() self:onEnter() end
		function InfusionMultiplier:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end
		sbq.numberBoxColor(InfusionMultiplier, 0)

		local compressionMultiplier = _ENV[location .. "CompressionMultiplier"]

		compressionMultiplier:setText(tostring(sbq.overrideSettings[location .. "CompressionMultiplier"] or sbq.predatorSettings[location .. "CompressionMultiplier"] or sbq.predatorSettings["default".."CompressionMultiplier"] or 0.25))
		function compressionMultiplier:onEnter() sbq.numberBox(self, "changeGlobalSetting", location .. "CompressionMultiplier", "globalSettings", "overrideSettings", 0) end
		function compressionMultiplier:onTextChanged() sbq.numberBoxColor(self, 0) end
		function compressionMultiplier:onEscape() self:onEnter() end
		function compressionMultiplier:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end
		sbq.numberBoxColor(compressionMultiplier, 0)

		local clearPlayers = _ENV[location.."ClearPlayers"]
		local clearOCs = _ENV[location.."ClearOCs"]
		local clearSBQNPCs = _ENV[location.."ClearSBQNPCs"]
		local clearOthers = _ENV[location.."ClearOthers"]

		function clearPlayers:onClick() sbq.clearLocationEssences(location, "Players", count) end
		function clearOCs:onClick() sbq.clearLocationEssences(location, "OCs", count) end
		function clearSBQNPCs:onClick() sbq.clearLocationEssences(location, "SBQNPCs", count) end
		function clearOthers:onClick() sbq.clearLocationEssences(location, "Others", count) end

		return tab
	end
end



function sbq.drawEffectButton(w, icon)
	local c = widget.bindCanvas(w.backingWidget) c:clear()
	local directives = ""
	if w.state == "press" then directives = "?brightness=-50" end
	local pos = vec2.mul(c:size(), 0.5)

	c:drawImageDrawable(icon..directives, pos, 1)
	if w.checked then
		c:drawImageDrawable(icon.."?outline=1;FFFFFFFF;FFFFFFFF"..directives, pos, 1)
	end
end

function sbq.locationEffectButton(button, location, locationData, effectLabel)
	local value = button:getGroupChecked().value
	sbq.globalSettings[location .. "EffectSlot"] = value
	sbq.predatorSettings[location.."EffectSlot"] = value
	local effect = sbq.getStatusEffectSlot(location, locationData)
	sbq.predatorSettings[location.."Effect"] = effect

	effectLabel:setText((sbq.config.bellyStatusEffectNames[effect] or "No Effect"))
	sbq.saveSettings()
end

function sbq.locationDefaultSettings(locationData,location)

	sbq.defaultGlobalSetting(location, "PredDigestDrops")
	sbq.defaultGlobalSetting(location, "Hammerspace")
	sbq.defaultGlobalSetting(location, "Compression")
	sbq.defaultGlobalSetting(location, "Sounds")
	sbq.defaultGlobalSetting(location, "StruggleSounds")
	sbq.defaultGlobalSetting(location, "InfusedVisual")
	sbq.defaultGlobalSetting(location, "InfusedSize")
	sbq.defaultGlobalSetting(location, "InfusedSizeAdditive")
	sbq.defaultGlobalSetting(location, "VisualMinAdditive")
	sbq.defaultGlobalSetting(location, "AbsorbPlayers")
	sbq.defaultGlobalSetting(location, "AbsorbOCs")
	sbq.defaultGlobalSetting(location, "AbsorbSBQNPCs")
	sbq.defaultGlobalSetting(location, "AbsorbOthers")
end

function sbq.defaultGlobalSetting(location, setting)
	sbq.globalSettings[location .. setting] = sbq.globalSettings[location .. setting] or ((sbq.globalSettings[location .. setting] == nil) and sbq.globalSettings["default" .. setting]) or false
end

local map = {
	heal = "Heal",
	none = "None",
	digest = "Digest",
	softDigest = "SoftDigest"
}

function sbq.getStatusEffectSlot(location, locationData)
	local value = sbq.globalSettings[location .. "EffectSlot"]
	local effect = "sbqRemoveBellyEffects"
	if value then
		effect = (locationData[value] or {}).effect or (sbq.predatorConfig.effectDefaults or {})[value] or
			(sbq.config.effectDefaults or {})[value] or "sbqRemoveBellyEffects"
		if (sbq.predatorConfig.overrideSettings or {})[location .. map[value] .. "Enable"] == false then
			effect = (sbq.predatorConfig.defaultSettings or {})[location .. "Effect"] or "sbqRemoveBellyEffects"
		end
	end
	return effect
end

function sbq.numberBox(textbox, settingsFunc, settingName, settings, overrideSettings, min, max )
	local value = tonumber(textbox.text)
	local isNumber = type(value) == "number"
	if isNumber and (sbq[overrideSettings] or {})[settingName] == nil then
		local newValue = math.min(math.max(value, (min or -math.huge)), (max or math.huge))
		textbox:setText(tostring(newValue))
		sbq[settingsFunc](settingName, newValue)
		sbq.numberBoxColor(textbox, min, max)
		sbq.saveSettings()
	else
		textbox:setText(tostring((sbq[overrideSettings] or {})[settingName] or (sbq[settings] or {})[settingName] or 0))
	end
end
function sbq.numberBoxColor(textbox, min, max)
	local value = tonumber(textbox.text)
	local isNumber = type(value) == "number"
	local color = "FFFFFF"
	if isNumber then
		if type(max) == "number" and value == max
		or type(min) == "number" and value == min
		then
			color = "FFFF00"
		elseif type(max) == "number" and type(min) == "number" then
			if value > min and value < max then
				color = "00FF00"
			end
		end
		if type(max) == "number" and value > max
		or type(min) == "number" and value < min
		then
			color = "FF0000"
		end
	else
		color = "FF0000"
	end
	textbox:setColor(color)
end

function sbq.dropdownButton(button, settingname, list, func, overrides)
	local contextMenu = {}
	for i, values in ipairs(list) do
		table.insert(contextMenu, { values[2],
			function ()
				sbq[func](settingname, values[1])
				button:setText(values[2])
			end
		})
	end
	if sbq[overrides][settingname] == nil then
		function button:onClick()
			metagui.dropDownMenu(contextMenu,2)
		end
	end
end

function sbq.infusionSlotAccepts(locationData, item)
	local npcParam = (((item or {}).parameters or {}).npcArgs or {}).npcParam
	local uniqueId = (( npcParam or {}).scriptConfig or {}).uniqueId
	if npcParam and ((not locationData.infusionAccepts) or locationData.infusionAccepts.characters) then
		local preySettings = sbq.getItemPreySettings(item)
		if (not sbq.predatorSettings[(locationData.infusionSetting or "infusion").."Pred"]) or not preySettings[locationData.infusionSetting or "infusion"] then return false end
		if type((locationData.infusionAccepts or {}).characters) == "table" then
			for i, uuid in ipairs((locationData.infusionAccepts or {}).characters or {}) do
				if uuid == uniqueId then
					return true
				end
			end
			return false
		end
		if (locationData.infusionAccepts or {}).rejectCharacters then
			if ((locationData.infusionAccepts or {}).rejectCharacters) == true then return false end
			for i, uuid in ipairs((locationData.infusionAccepts or {}).rejectCharacters or {}) do
				if uuid == uniqueId then
					return false
				end
			end
		end
		return true
	elseif (((item or {}).parameters or {}).species ~= nil and item.name == "sbqMysteriousPotion") and ((not locationData.infusionAccepts) or locationData.infusionAccepts.sbqMysteriousPotion ) then
		return true
	else
		return false
	end
end

function sbq.getItemPreySettings(item)
	local success, npcConfig = pcall(root.npcConfig, (((item.parameters or {}).npcArgs or {}).npcType))
	if not success then npcConfig = {} end

	local registry = root.assetJson("/humanoid/sbqDataRegistry.config")
	local path = registry[species] or "/humanoid/sbqData.config"
	if path:sub(1,1) ~= "/" then
		path = "/humanoid/"..species.."/"..path
	end
	local speciesConfig = root.assetJson(path)
	local sbqData
	if type(speciesConfig.sbqData) == "table" then
		sbqData = speciesConfig.sbqData
	end

	local mergeConfigs = sbqData.merge or {}
	local configs = { sbqData }
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


	return sb.jsonMerge(
		sb.jsonMerge(
			sb.jsonMerge(
				sb.jsonMerge(
					sbq.config.defaultPreyEnabled.npc,
					((((npcConfig or {}).statusControllerSettings or {}).statusProperties or {}).sbqPreyEnabled or {})
				),
				(((((item.parameters.npcArgs or {}).npcParam or {}).statusControllerSettings or {}).statusProperties or {}).sbqPreyEnabled or {})
			),
			(((npcConfig or {}).scriptConfig or {}).sbqOverridePreyEnabled or {})
		),
		(finalConfig.overridePreyEnabled or {})
	)
end

function sbq.clearLocationEssences(location, essenceType, slots)
	local newList = {}
	local itemGrid = _ENV[location .. "ItemGrid"]
	for i = 1, slots do
		local item = itemGrid:item(i)
		if item then
			local success, npcConfig = pcall(root.npcConfig, item.parameters.npcArgs.npcType)
			if not success then
				npcConfig = item.parameters.npcArgs.npcParam
			end
			if (essenceType == "Players" and not (item.parameters.npcArgs.npcParam.wasPlayer))
				or (essenceType == "OCs" and not (((npcConfig or {}).scriptConfig or {}).isOC))
				or (essenceType == "SBQNPCs" and not (((npcConfig or {}).scriptConfig or {}).sbqNPC))
				or (essenceType == "Others" and not (((npcConfig or {}).scriptConfig or {}).sbqNPC or ((npcConfig or {}).scriptConfig or {}).isOC or item.parameters.npcArgs.npcParam.wasPlayer))
			then
				table.insert(newList, item)
			end
		end
	end
	for i = 1, slots do
		itemGrid:setItem(i, newList[i])
	end
	sbq.saveDigestedPrey()
end
