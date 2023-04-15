---@diagnostic disable: undefined-global
sbq = {
	config = root.assetJson("/sbqGeneral.config"),
	tenantCatalogue = root.assetJson("/npcs/tenants/sbqTenantCatalogue.json"),
	storage = metagui.inputData,
	deedUI = true,
	playeruuid = world.entityUniqueId(player.id())
}

indexes = {
	tenantIndex = 1
}

require("/interface/scripted/sbq/sbqSettings/extraTabs.lua")
require("/scripts/speciesAnimOverride_validateIdentity.lua")

local cosmeticSlots = { "headCosmetic", "chestCosmetic", "legsCosmetic", "backCosmetic", "underchestCosmetic", "underlegsCosmetic" }
local cosmeticItemType =  { "headarmor", "chestarmor", "legsarmor", "backarmor", "chestarmor", "legsarmor" }

function sbq.changeSelectedFromList(list, label, indexName, inc )
	indexes[indexName] = (indexes[indexName] or 1) + inc
	if indexes[indexName] < 1 then
		indexes[indexName] = #list
	elseif indexes[indexName] > #list then
		indexes[indexName] = 1
	end
	label:setText(list[indexes[indexName]])
	return list[indexes[indexName]]
end

sbq.validTenantCatalogueList = {}
for name, tenant in pairs(sbq.tenantCatalogue) do
	local tenant = tenant
	if type(tenant) == "table" then
		tenant = tenant[1]
	end
	local data = root.tenantConfig(tenant).checkRequirements or {}
	local addToList = true
	if addToList and data.checkItems then
		for i, item in ipairs(data.checkItems) do
			addToList = root.itemConfig(item)
			if not addToList then break end
		end
	end
	if addToList and data.checkJson then
		addToList, json = pcall(root.assetJson, data.checkJson)
	end
	if addToList and data.checkImage then
		success, notEmpty = pcall(root.nonEmptyRegion, data.checkImage)
		addToList = (success and notEmpty ~= nil)
	end
	if addToList then
		table.insert(sbq.validTenantCatalogueList, name)
	end
end
table.sort(sbq.validTenantCatalogueList)

require("/scripts/SBQ_RPC_handling.lua")
require("/interface/scripted/sbq/sbqSettings/sbqSettingsEffectsPanel.lua")
require("/scripts/SBQ_species_config.lua")
require("/interface/scripted/sbq/sbqSettings/autoSetSettings.lua")
require("/interface/scripted/sbq/sbqVoreColonyDeed/sbqHuntingSettings.lua")

function sbq.drawLocked(w, icon)
	local c = widget.bindCanvas(w.backingWidget)
	c:clear()
	local pos = vec2.mul(c:size(), 0.5)
	c:drawImageDrawable(icon, pos, 1)
end

mainTabField.tabs.deedTab:select()
if (sbq.storage.detached) or (sbq.storage.respawner ~= nil) then
	mainTabField.tabs.deedTab:setVisible(false)
	mainTabField.tabs.tenantTab:select()
	metagui.setTitle("Preditor")
	metagui.setIcon("/items/active/sbqNominomicon/sbqNominomicon.png")
	theme.drawFrame()
end

sbq.playerPreySettings = status.statusProperty("sbqPreyEnabled") or {}
sbq.playerPredatorSettings = (player.getProperty("sbqSettings") or {}).global or {}

function init()
	sbq.refreshDeedPage()
	sbq.refreshTenantPages()
end

function sbq.refreshTenantPages()
	local occupier = sbq.storage.occupier
	if type(occupier) == "table" and type(occupier.tenants) == "table" and
		type(occupier.tenants[indexes.tenantIndex]) == "table" and
		type(occupier.tenants[indexes.tenantIndex].species) == "string"
	then
		sbq.tenant = occupier.tenants[indexes.tenantIndex]
		sbq.npcConfig = root.npcConfig(sbq.tenant.type)

		sbq.sbqCurrentData = ((sbq.tenant.overrides.statusControllerSettings or {}).statusProperties or {}).sbqCurrentData or {}

		sbq.getOccupantHolderData()

		sbq.speciesFile = root.assetJson( "/species/"..(sbq.speciesConfig.species)..".species" )

		sbq.overrideSettings = sb.jsonMerge(sbq.predatorConfig.overrideSettings or {}, sbq.npcConfig.scriptConfig.sbqOverrideSettings or {})
		sbq.overridePreyEnabled = sb.jsonMerge(sbq.predatorConfig.overridePreyEnabled or {}, sbq.npcConfig.scriptConfig.sbqOverridePreyEnabled or {})

		sbq.tenant.overrides.statusControllerSettings = sbq.tenant.overrides.statusControllerSettings or {}
		sbq.tenant.overrides.statusControllerSettings.statusProperties = sbq.tenant.overrides.statusControllerSettings.statusProperties or {}
		sbq.tenant.overrides.statusControllerSettings.statusProperties.sbqPreyEnabled = sbq.tenant.overrides.statusControllerSettings.statusProperties.sbqPreyEnabled or {}

		sbq.predatorSettings = sb.jsonMerge( sb.jsonMerge(sb.jsonMerge(sbq.config.defaultSettings, sbq.predatorConfig.defaultSettings or {}), sbq.config.tenantDefaultSettings),
			sb.jsonMerge( sbq.npcConfig.scriptConfig.sbqDefaultSettings or {},
				sb.jsonMerge( sbq.tenant.overrides.scriptConfig.sbqSettings or {}, sbq.overrideSettings)
			)
		)
		sbq.tenant.overrides.scriptConfig.sbqSettings = sbq.predatorSettings
		sbq.predatorSettings.firstLoadDone = true

		sbq.preySettings = sb.jsonMerge( sbq.config.defaultPreyEnabled.player,
			sb.jsonMerge(sbq.tenant.overrides.statusControllerSettings.statusProperties.sbqPreyEnabled or {}, sbq.overridePreyEnabled or {})
		)
		sbq.tenant.overrides.statusControllerSettings.statusProperties.sbqPreyEnabled = sbq.preySettings

		sbq.cumulativeData = sbq.tenant.overrides.statusControllerSettings.statusProperties.sbqCumulativeData or {}
		sbq.cumulativeData[sbq.playeruuid] = (player.getProperty("sbqCumulativeData") or {})[sbq.tenant.uniqueId] or {}
		sbq.cumulativeData[sbq.playeruuid].name = world.entityName(player.id())
		local swapData = sbq.cumulativeData[sbq.playeruuid].pred
		sbq.cumulativeData[sbq.playeruuid].pred = sbq.cumulativeData[sbq.playeruuid].prey
		sbq.cumulativeData[sbq.playeruuid].prey = swapData
		sbq.cumulativeData[sbq.playeruuid].type = "player"
		sbq.tenant.overrides.statusControllerSettings.statusProperties.sbqCumulativeData = sbq.cumulativeData

		sbq.storedDigestedPrey = sbq.tenant.overrides.statusControllerSettings.statusProperties.sbqStoredDigestedPrey or {}
		sbq.tenant.overrides.statusControllerSettings.statusProperties.sbqStoredDigestedPrey = sbq.storedDigestedPrey

		sbq.animOverrideSettings = sb.jsonMerge(sb.jsonMerge(root.assetJson("/animOverrideDefaultSettings.config"), sbq.speciesFile.animOverrideDefaultSettings or {}), sbq.tenant.overrides.statusControllerSettings.statusProperties.speciesAnimOverrideSettings or {})
		sbq.animOverrideSettings.scale = ((sbq.tenant.overrides.statusControllerSettings or {}).statusProperties or {}).animOverrideScale or 1
		sbq.animOverrideOverrideSettings = sb.jsonMerge(sbq.tenant.overrides.statusControllerSettings.statusProperties.speciesAnimOverrideOverrideSettings or {}, sbq.npcConfig.scriptConfig.speciesAnimOverrideOverrideSettings)

		sbq.tenant.overrides.statusControllerSettings.statusProperties.speciesAnimOverrideSettings = sbq.animOverrideSettings

		sbq.globalSettings = sbq.predatorSettings
		escapeValue:setText(tostring(sbq.overrideSettings.escapeDifficulty or sbq.predatorSettings.escapeDifficulty or 0))
		escapeValueMin:setText(tostring(sbq.overrideSettings.escapeDifficultyMin or sbq.predatorSettings.escapeDifficultyMin or 0))
		escapeValueMax:setText(tostring(sbq.overrideSettings.escapeDifficultyMax or sbq.predatorSettings.escapeDifficultyMax or 0))
		sbq.numberBoxColor(escapeValue, sbq.overrideSettings.escapeDifficultyMin or sbq.predatorSettings.escapeDifficultyMin, sbq.overrideSettings.escapeDifficultyMax or sbq.predatorSettings.escapeDifficultyMax)
		sbq.numberBoxColor(escapeValueMin, sbq.overrideSettings.escapeDifficultyMin, sbq.overrideSettings.escapeDifficulty or sbq.predatorSettings.escapeDifficulty )
		sbq.numberBoxColor(escapeValueMax, sbq.overrideSettings.escapeDifficulty or sbq.predatorSettings.escapeDifficulty, sbq.overrideSettings.escapeDifficultyMax )

		personalityText:setText(sbq.predatorSettings.personality or "default")
		moodText:setText(sbq.predatorSettings.mood or "default")

		sbq.onTenantChanged()

		local bio = sbq.tenant.overrides.scriptConfig.tenantBio or sbq.npcConfig.scriptConfig.tenantBio
		if bio ~= nil then
			bioPanel:clearChildren()
			if type(bio) == "string" then
				bio = root.assetJson(bio)
			end
			sb.logInfo(sb.printJson(bio))
			bioPanel:addChild(bio)
		end
		bioPanel:setVisible(bio ~= nil)
		hideBio:setVisible(bio ~= nil)

		local sbqNPC = sbq.npcConfig.scriptConfig.sbqNPC or false
		globalTenantSettingsLayout:setVisible(sbqNPC)
		notStarbecueNPC:setVisible(not sbqNPC)
		if not sbqNPC then
			local convertible = sbq.config.vornyConvertTable[sbq.tenant.type]
			if convertible ~= nil then
				convertNPC:setVisible(true)
				convertNPC:setText("Convert")
				local applyCount = 0
				function convertNPC:onClick()
					applyCount = applyCount + 1

					if applyCount > 3 then
						world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSetNPCType", convertible)
						if sbq.storage.crewUI then
							for i, follower in ipairs(sbq.followers) do
								if follower.uniqueId == sbq.tenant.uniqueId then
									follower.config.type = convertible
									break
								end
							end
							world.sendEntityMessage(player.id(), "sbqSetRecruits", "followers", sbq.followers)
						end
						pane.dismiss()
					end
					convertNPC:setText(tostring(4 - applyCount))
				end
			else
				convertNPC:setVisible(false)
			end
		else
			local visible = false
			for convertible, converted in pairs(sbq.config.vornyConvertTable) do
				if converted == sbq.tenant.type then
					visible = true
					local applyCount = 0

					function revertNPC:onClick()
						applyCount = applyCount + 1
						if applyCount > 3 then
							world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSetNPCType", convertible)
							if sbq.storage.crewUI then
								for i, follower in ipairs(sbq.followers) do
									if follower.uniqueId == sbq.tenant.uniqueId then
										follower.config.type = convertible
										break
									end
								end
								world.sendEntityMessage(player.id(), "sbqSetRecruits", "followers", sbq.followers)
							end
							pane.dismiss()
						end
						revertNPC:setText(tostring(4 - applyCount))
					end
					break
				end
			end
			revertNPC:setVisible(visible)
		end

		local predTabVisible = (sbq.npcConfig.scriptConfig.isPredator or (sbq.npcConfig.scriptConfig.isPredator == nil)) and sbqNPC
		notPredText:setVisible(not predTabVisible)
		globalPredSettingsLayout:setVisible(predTabVisible)

		local preyTabVisible = sbq.npcConfig.scriptConfig.isPrey or (sbq.npcConfig.scriptConfig.isPrey == nil)
		notPreyText:setVisible(not preyTabVisible)
		globalPreySettingsLayout:setVisible(preyTabVisible)

		sbq.effectsPanel()

		sbq.setSpeciesHelpTab(species)
		sbq.setSpeciesSettingsTab(species)
		sbq.setHelpTab()

		function settingsButtonScripts.questParticipation()
			if not sbq.storage.detached then
				world.sendEntityMessage(sbq.storage.respawner or pane.sourceEntity(), "sbqSaveQuestGenSetting", "enableParticipation", questParticipation.checked, sbq.storage.forcedIndex or indexes.tenantIndex)
			end
		end
		function settingsButtonScripts.crewmateGraduation()
			if not sbq.storage.detached then
				local graduation = {
					["true"] = {
						nextNpcType =sbq.npcConfig.scriptConfig.questGenerator.graduation.nextNpcType
					},
					["false"] = {
						nextNpcType = {nil}
					}
				}
				world.sendEntityMessage(sbq.storage.respawner or pane.sourceEntity(), "sbqSaveQuestGenSetting", "graduation", graduation[tostring(crewmateGraduation.checked or false)], sbq.storage.forcedIndex or indexes.tenantIndex)
			end
		end

		sbq.huntingSettingsPanel()

		sbq.refreshButtons()

		sbq.checkLockedSettingsButtons("preySettings", "overridePreyEnabled", "changePreySetting")
		sbq.checkLockedSettingsButtons("animOverrideSettings", "animOverrideOverrideSettings", "changeAnimOverrideSetting")

		for i, slot in ipairs(cosmeticSlots) do
			local itemSlot = _ENV[slot]
			if itemSlot then
				itemSlot:setItem(sbq.predatorSettings[slot])
				itemSlot.autoInteract = (sbq.overrideSettings[slot] == nil)
				function itemSlot:acceptsItem(item)
					if sbq.overrideSettings[slot] == nil then
						return (root.itemType((item or {}).name)) == cosmeticItemType[i]
					end
				end
				function itemSlot:onItemModified()
					local item = itemSlot:item()
					sbq.changePredatorSetting(slot, item)
				end
			end
		end
		mainTabField.tabs.tenantTab:setTitle(((sbq.tenant.overrides or {}).identity or {}).name or "")
	end
end

function sbq.refreshButtons()
	sbq.checkLockedSettingsButtons("predatorSettings", "overrideSettings", "changePredatorSetting")
	--sbq.checkLockedSettingsButtons("globalSettings", "overrideSettings", "changeGlobalSetting")
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
				if sbq.drawSpecialButtons[setting] then
					function button:draw() button.drawSpecial() end
				else
					function button:draw() theme.drawCheckBox(self) end
				end
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
	local dt = script.updateDt()
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
end

function sbq.getOccupantHolderData(settings)
	sbq.getSpeciesConfig(sbq.tenant.species, settings or sbq.tenant.overrides.scriptConfig.sbqSettings)
	sbq.predatorConfig = sbq.speciesConfig.sbqData
end

function sbq.savePredSettings()
	sbq.tenant.overrides.scriptConfig.sbqSettings = sbq.predatorSettings
	if not sbq.storage.detached then
		world.sendEntityMessage(sbq.storage.respawner or pane.sourceEntity(), "sbqSaveSettings", sbq.predatorSettings, sbq.storage.forcedIndex or indexes.tenantIndex)
	end
	if sbq.storage.occupier then
		world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSaveSettings", sbq.predatorSettings)
	end
end
sbq.saveSettings = sbq.savePredSettings

function sbq.savePreySettings()
	sbq.tenant.overrides.statusControllerSettings.statusProperties.sbqPreyEnabled = sbq.preySettings
	if not sbq.storage.detached then
		world.sendEntityMessage(sbq.storage.respawner or pane.sourceEntity(), "sbqSavePreySettings", sbq.preySettings, sbq.storage.forcedIndex or indexes.tenantIndex)
	end
	if sbq.storage.occupier then
		world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSavePreySettings", sbq.preySettings)
	end
end

function sbq.saveDigestedPrey()
	if not sbq.storage.detached then
		world.sendEntityMessage(sbq.storage.respawner or pane.sourceEntity(), "sbqSaveDigestedPrey", sbq.storedDigestedPrey, sbq.storage.forcedIndex or indexes.tenantIndex )
	end
	if sbq.storage.occupier then
		world.sendEntityMessage( sbq.tenant.uniqueId, "sbqSaveDigestedPrey", sbq.storedDigestedPrey )
	end
end

function sbq.changePredatorSetting(settingname, value)
	sbq.predatorSettings[settingname] = value
	sbq.autoSetSettings(settingname, value)

	sbq.savePredSettings()
end
sbq.changeGlobalSetting = sbq.changePredatorSetting

function sbq.changePreySetting(settingname, value)
	sbq.preySettings[settingname] = value
	sbq.savePreySettings()
end

function sbq.changeAnimOverrideSetting(settingname, settingvalue)
	sbq.animOverrideSettings[settingname] = settingvalue
	sbq.tenant.overrides.statusControllerSettings.statusProperties.speciesAnimOverrideSettings = sbq.animOverrideSettings
	if not sbq.storage.detached then
		world.sendEntityMessage(sbq.storage.respawner or pane.sourceEntity(), "sbqSaveAnimOverrideSettings", sbq.animOverrideSettings, sbq.storage.forcedIndex or indexes.tenantIndex)
	end
	if sbq.storage.occupier then
		world.sendEntityMessage(sbq.tenant.uniqueId, "sbqSaveAnimOverrideSettings", sbq.animOverrideSettings)
		world.sendEntityMessage(sbq.tenant.uniqueId, "speciesAnimOverrideRefreshSettings", sbq.animOverrideSettings)
		world.sendEntityMessage(sbq.tenant.uniqueId, "animOverrideScale", sbq.animOverrideSettings.scale)
	end
end

--------------------------------------------------------------------------------------------------

if callTenant ~= nil then
	function callTenant:onClick()
		world.sendEntityMessage(sbq.storage.respawner or pane.sourceEntity(), "sbqDeedInteract", {sourceId = player.id(), sourcePosition = world.entityPosition(player.id())})
	end

	if sbq.storage.detached then
		callTenant:setVisible(false)
	end

	local applyCount = 0
	function summonTenant:onClick()
		applyCount = applyCount + 1

		if applyCount > 3 or sbq.storage.occupier == nil then
			world.sendEntityMessage(sbq.storage.respawner or pane.sourceEntity(), "sbqSummonNewTenant", sbq.getGuardTier() or tenantText.text)
			pane.dismiss()
		end
		summonTenant:setText(tostring(4 - applyCount))
	end
end

function sbq.getGuardTier()
	local remap = (sbq.tenantCatalogue[tenantText.text])
	if type(remap) == "table" then
		local tags = sbq.storage.house.contents
		local index = 1
		if type(tags.tier2) == "number" and tags.tier2 >= 12 then
			index = 2
		end
		if type(tags.tier3) == "number" and tags.tier3 >= 12 then
			index = 3
		end
		if type(tags.tier4) == "number" and tags.tier4 >= 12 then
			index = 3
		end
		return remap[index]
	else
		return remap
	end
end

--------------------------------------------------------------------------------------------------

if decTenant ~= nil then
	function decTenant:onClick()
		sbq.changeSelectedFromList(sbq.validTenantCatalogueList, tenantText, "tenantSelectorIndex", -1)
	end

	function incTenant:onClick()
		sbq.changeSelectedFromList(sbq.validTenantCatalogueList, tenantText, "tenantSelectorIndex", 1)
	end
end

function sbq.onTenantChanged()
end

--------------------------------------------------------------------------------------------------

function decPersonality:onClick()
	if sbq.overrideSettings.personality ~= nil then return end
	sbq.changePredatorSetting("personality", sbq.changeSelectedFromList(sbq.config.npcPersonalities, personalityText, "personalityIndex", -1))
end

function incPersonality:onClick()
	if sbq.overrideSettings.personality ~= nil then return end
	sbq.changePredatorSetting("personality", sbq.changeSelectedFromList(sbq.config.npcPersonalities, personalityText, "personalityIndex", 1))
end

--------------------------------------------------------------------------------------------------

function decMood:onClick()
	if sbq.overrideSettings.mood ~= nil then return end
	sbq.changePredatorSetting("mood", sbq.changeSelectedFromList(sbq.config.npcMoods, moodText, "moodIndex", -1))
end

function incMood:onClick()
	if sbq.overrideSettings.mood ~= nil then return end
	sbq.changePredatorSetting("mood", sbq.changeSelectedFromList(sbq.config.npcMoods, moodText, "moodIndex", 1))
end

--------------------------------------------------------------------------------------------------

function escapeValue:onEnter() sbq.numberBox(escapeValue, "changePredatorSetting", "escapeDifficulty", "predatorSettings", "overrideSettings", sbq.overrideSettings.escapeDifficultyMin or sbq.predatorSettings.escapeDifficultyMin, sbq.overrideSettings.escapeDifficultyMax or sbq.predatorSettings.escapeDifficultyMax ) end
function escapeValue:onTextChanged() sbq.numberBoxColor(escapeValue, sbq.overrideSettings.escapeDifficultyMin or sbq.predatorSettings.escapeDifficultyMin, sbq.overrideSettings.escapeDifficultyMax or sbq.predatorSettings.escapeDifficultyMax ) end
function escapeValue:onEscape() self:onEnter() end
function escapeValue:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end

function escapeValueMin:onEnter() sbq.numberBox(escapeValueMin, "changePredatorSetting", "escapeDifficultyMin", "predatorSettings", "overrideSettings", sbq.overrideSettings.escapeDifficultyMin, sbq.overrideSettings.escapeDifficulty or sbq.predatorSettings.escapeDifficulty ) end
function escapeValueMin:onTextChanged() sbq.numberBoxColor(escapeValueMin, sbq.overrideSettings.escapeDifficultyMin, sbq.overrideSettings.escapeDifficulty or sbq.predatorSettings.escapeDifficulty ) end
function escapeValueMin:onEscape() self:onEnter() end
function escapeValueMin:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end

function escapeValueMax:onEnter() sbq.numberBox(escapeValueMax, "changePredatorSetting", "escapeDifficultyMax", "predatorSettings", "overrideSettings", sbq.overrideSettings.escapeDifficulty or sbq.predatorSettings.escapeDifficulty, sbq.overrideSettings.escapeDifficultyMax ) end
function escapeValueMax:onTextChanged() sbq.numberBoxColor(escapeValueMax, sbq.overrideSettings.escapeDifficulty or sbq.predatorSettings.escapeDifficulty, sbq.overrideSettings.escapeDifficultyMax ) end
function escapeValueMax:onEscape() self:onEnter() end
function escapeValueMax:onUnfocus() self.focused = false self:queueRedraw() self:onEnter() end

--------------------------------------------------------------------------------------------------

if orderFurniture ~= nil then
	function orderFurniture:onClick()
		local occupier = sbq.storage.occupier
		local contextMenu = {}

		if occupier.name then
			local config = root.tenantConfig(occupier.name)
			occupier.orderFurniture = config.orderFurniture or occupier.orderFurniture
		end


		for i, item in pairs(occupier.orderFurniture or {}) do
			local itemConfig = root.itemConfig(item)
			if not itemConfig then
				sb.logInfo(item.name.." can't be ordered: doesn't exist")
			elseif (type(item.price) ~= "number" and type((itemConfig.config or {}).price) ~= "number") then
				sb.logInfo(item.name.." can't be ordered: has no price")
			else
				local actionLabel = itemConfig.config.shortdescription.."^reset;"
				if item.count ~= nil and item.count > 1 then
					actionLabel = actionLabel.." x"..item.count
				end
				if type((item.parameters or {}).color) == "string" then
					actionLabel = "^"..item.parameters.color..";"..actionLabel
				end

				local price = ((item.count or 1)*(item.price or itemConfig.config.price))
				actionLabel = actionLabel.." ^#555;Price: ^yellow;"..price.."^reset;"

				local comma = ""
				local gotReqTag = false
				for reqTag, value in pairs(occupier.tagCriteria or {}) do
					for j, tag in ipairs(itemConfig.config.colonyTags or {}) do
						if tag == reqTag then
							if not gotReqTag then
								actionLabel = actionLabel.." ^#555;Tags:"
								gotReqTag = true
							end
							actionLabel = actionLabel..comma.." ^green;"..tag.."^reset;"
							comma = ","
							break
						end
					end
				end

				table.insert(contextMenu, {actionLabel, function () sbq.orderItem(item, price) end})
			end
		end
		metagui.contextMenu(contextMenu)
	end

	function sbq.orderItem(item, price)
		if player.isAdmin() or player.consumeCurrency( "money", price ) then
			player.giveItem(item)
		else
			pane.playSound("/sfx/interface/clickon_error.ogg")
		end
	end
end

--------------------------------------------------------------------------------------------------

if sbq.storage.crewUI then
	require("/interface/scripted/sbq/sbqVoreColonyDeed/sbqVoreCrewMenu.lua")
else
	function sbq.isValidTenantCard(item)
		if (item.parameters or {}).npcArgs ~= nil then
			local success, speciesFile = pcall(root.assetJson, ("/species/"..(item.parameters.npcArgs.npcSpecies or "")..".species"))
			if not success then return false end
			if item.parameters.npcArgs.npcParam.wasPlayer then return false end
			if ((item.parameters.npcArgs.npcParam or {}).scriptConfig or {}).uniqueId then
				for i, tenant in ipairs((sbq.storage.occupier or {}).tenants or {}) do
					if tenant.uniqueId == ((item.parameters.npcArgs.npcParam or {}).scriptConfig or {}).uniqueId then return false end
				end
			end
			return true
		end
	end
	function insertTenantItemSlot:acceptsItem(item)
		if not sbq.isValidTenantCard(item) then pane.playSound("/sfx/interface/clickon_error.ogg") return false
		else return true end
	end
	function insertTenant:onClick()
		local item = insertTenantItemSlot:item()

		sbq.addRPC(world.findUniqueEntity(((item.parameters.npcArgs.npcParam or {}).scriptConfig or {}).uniqueId),
			function(result)
				if not result then
					sbq.insertTenant(item)
				end
				pane.playSound("/sfx/interface/clickon_error.ogg")
			end,
			function ()
				sbq.insertTenant(item)
			end
		)
	end
	function uninit()
		local item = insertTenantItemSlot:item()
		if item then
			player.giveItem(item)
		end
	end
end

function sbq.insertTenant(item)
	insertTenantItemSlot:setItem(nil, true)
	local tenant = {
		species = item.parameters.npcArgs.npcSpecies,
		seed = item.parameters.npcArgs.npcSeed,
		type = item.parameters.npcArgs.npcType,
		level = item.parameters.npcArgs.npcLevel,
		overrides = item.parameters.npcArgs.npcParam or {},
		uniqueId = ((item.parameters.npcArgs.npcParam or {}).scriptConfig or {}).uniqueId or sb.makeUuid(),
		spawn = item.parameters.npcArgs.npcSpawn or "npc"
	}
	tenant.overrides.scriptConfig = tenant.overrides.scriptConfig or {}
	tenant.overrides.scriptConfig.uniqueId = tenant.uniqueId
	table.insert(sbq.storage.occupier.tenants, tenant)
	world.sendEntityMessage(sbq.storage.respawner or pane.sourceEntity(), "sbqSaveTenants", sbq.storage.occupier.tenants)
	init()
end

function sbq.refreshDeedPage()
	sbq.tenantList = {}
	local occupier = sbq.storage.occupier or {}
	tenantListScrollArea:clearChildren()

	if sbq.storage.occupier then
		if type(occupier) == "table" and type(occupier.tenants) == "table" then
			indexes.tenantIndex = math.min(indexes.tenantIndex, #occupier.tenants)
		end
		if type(occupier) == "table" and type(occupier.tenants) == "table" and
			type(occupier.tenants[indexes.tenantIndex]) == "table" and
			type(occupier.tenants[indexes.tenantIndex].species) == "string"
		then
			for i, tenant in ipairs(occupier.tenants) do
				local name = ((tenant.overrides or {}).identity or {}).name or ""
				table.insert(sbq.tenantList, name)

				local panel = { type = "panel", expandMode = { 0, 1 }, style = "flat", children = {
					{ mode = "vertical" },
					{ type = "itemSlot", autoInteract = false, item = sbq.generateNPCItemCard(tenant), id = "tenant" .. i .. "ItemSlot" },
					{
						{ type = "label", text = ((tenant.overrides or {}).identity or {}).name or "" },
						{ type = "button", visible = not sbq.storage.crewUI, caption = "X", color = "FF0000",
							id = "tenant" .. i .. "Remove", size = { 12, 12 }, expandMode = { 0, 0 } }
					}
				} }
				tenantListScrollArea:addChild(panel)
				local button = _ENV["tenant" .. i .. "Remove"]
				local itemSlot = _ENV["tenant" .. i .. "ItemSlot"]
				function button:onClick()
					player.giveItem(sbq.generateNPCItemCard(sbq.storage.occupier.tenants[i]))
					table.remove(sbq.storage.occupier.tenants, i)
					world.sendEntityMessage(sbq.storage.respawner or pane.sourceEntity(), "sbqSaveTenants", sbq.storage.occupier.tenants)
					init()
				end

				function itemSlot:onMouseButtonEvent(btn, down)
					indexes.tenantIndex = i
					sbq.refreshTenantPages()
				end
			end
		end
	end

	if (not sbq.storage.crewUI) and not (sbq.storage.detached or sbq.storage.respawner) then
		tenantNote:setVisible(occupier.tenantNote ~= nil)
		tenantNote.toolTip = occupier.tenantNote

		orderFurniture:setVisible(occupier.orderFurniture ~= nil)

		tenantText:setText(occupier.name or "")
		local tags = sbq.storage.house.contents
		local listed = { sbqVore = true }
		requiredTagsScrollArea:clearChildren()
		local colonyTagLabels = {}
		for tag, value in pairs(occupier.tagCriteria or {}) do
			if tag ~= "sbqVore" then
				listed[tag] = true
				local amount = tags[tag] or 0
				local string = "^green;" .. tag .. ": " .. amount
				if amount < value then
					string = "^red;" .. tag .. ": " .. amount .. " ^yellow;(Need " .. value .. ")"
				end
				table.insert(colonyTagLabels, { type = "label", text = string })
			end
		end
		for tag, value in pairs(tags or {}) do
			if not listed[tag] then
				table.insert(colonyTagLabels, { type = "label", text = tag .. ": " .. value })
			end
		end
		requiredTagsScrollArea:addChild({ type = "panel", style = "flat", children = colonyTagLabels })
	end
end

function sbq.generateNPCItemCard(tenant)
	local npcConfig = root.npcConfig(tenant.type)

	validateIdentity(tenant.overrides.identity or {})

	local item = copy(sbq.config.npcCardTemplate)

	if npcConfig.scriptConfig.isOC then
		item.parameters.rarity = "rare"
	elseif npcConfig.scriptConfig.sbqNPC then
		item.parameters.rarity = "uncommon"
	end

	item.parameters.shortdescription = ((tenant.overrides or {}).identity or {}).name or ""
	item.parameters.inventoryIcon = root.npcPortrait("bust", tenant.species, tenant.type, tenant.level or 1, tenant.seed, tenant.overrides)
	item.parameters.description = (npcConfig.scriptConfig or {}).cardDesc or ""
	item.parameters.tooltipFields.collarNameLabel = ""
	item.parameters.tooltipFields.objectImage = root.npcPortrait("full", tenant.species, tenant.type, tenant.level or 1, tenant.seed, tenant.overrides)
	item.parameters.tooltipFields.subtitle = tenant.type
	item.parameters.tooltipFields.collarIconImage = nil
	item.parameters.npcArgs = {
		npcSpecies = tenant.species,
		npcSeed = tenant.seed,
		npcType = tenant.type,
		npcLevel = tenant.level,
		npcParam = tenant.overrides,
		npcSpawn = tenant.spawn
	}
	item.parameters.preySize = 1
	return item
end

function hideBio:onClick()
	bioPanel:setVisible(false)
	hideBio:setVisible(false)
end
