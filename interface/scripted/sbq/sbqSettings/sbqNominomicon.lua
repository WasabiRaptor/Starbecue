
---@diagnostic disable:undefined-global

require("/interface/scripted/sbq/sbqSettings/sbqSettings.lua")

-- replace functions that would be using the player table to save data, instead now they will send messages to the predator to save its data, the settings menu should behave exactly the same otherwise

local oldInit = init

function init()
	local id = pane.sourceEntity()
	sbq.sbqCurrentData = {
		id = id,
		species = world.entityName(id),
		type = "object"
	}

	local data = metagui.inputData


	sbq.sbqSettings = { global = data.settings }
	sbq.sbqSettings[sbq.sbqCurrentData.species] = data.settings
	sbq.predatorSpawner = data.spawner
	sbq.storedDigestedPrey = data.storedDigestedPrey or {}
	sbq.cumulativeData = data.cumulativeData or {}
	sbq.playerSettings = false

	oldInit()

	function lockSettings:onClick()
		sbq.changeGlobalSetting("lockSettings", lockSettings.checked)
		if lockSettings.checked then
			sbq.changeGlobalSetting("ownerId", player.uniqueId())
			local ownerName = world.entityName(player.id())
			sbq.changeGlobalSetting("ownerName", ownerName)
			ownerLabel:setText("Owner: "..ownerName)
		else
			sbq.changeGlobalSetting("ownerId", "")
			sbq.changeGlobalSetting("ownerName", "")
			ownerLabel:setText("")
		end
	end


	if (data.settings.lockSettings and data.settings.ownerId ~= player.uniqueId()) and not player.isAdmin() then
		mainTabField.tabs.globalPredSettings:setVisible(false)
		mainTabField.tabs.customizeTab:setVisible(false)
		lockSettings:setVisible(false)
		if sbq.speciesSettingsTab ~= nil then
			sbq.speciesSettingsTab:setVisible(false)
		end
	end
	if data.settings.ownerName ~= nil and data.settings.ownerName ~= "" then
		ownerLabel:setText("Owner: "..data.settings.ownerName)
	end

	sbq.globalSettings = sbq.predatorSettings
end

function update()
	local dt = script.updateDt()
	sbq.checkRPCsFinished(dt)
end

function sbq.getInitialData()
	sbq.lastSpecies = sbq.sbqCurrentData.species
	sbq.lastType = sbq.sbqCurrentData.type
	sbq.predatorEntity = sbq.sbqCurrentData.id
end

function sbq.getHelpTab()
	if sbq.extraTabs.speciesInfoTabs[sbq.sbqCurrentData.species] ~= nil then
		sbq.speciesHelpTab = mainTabField:newTab( sbq.extraTabs.speciesInfoTabs[sbq.sbqCurrentData.species] )
	end
end

function sbq.saveSettings()
	world.sendEntityMessage( sbq.predatorEntity, "settingsMenuSet", sbq.predatorSettings )
	world.sendEntityMessage( sbq.predatorSpawner, "sbqSaveSettings", sbq.predatorSettings )
end

sbq.changePredatorSetting = sbq.changeGlobalSetting

--------------------------------------------------------------------------------------

function sbq.saveDigestedPrey()
	world.sendEntityMessage( sbq.predatorEntity, "sbqSaveDigestedPrey", sbq.storedDigestedPrey )
	world.sendEntityMessage( sbq.predatorSpawner, "sbqSaveDigestedPrey", sbq.storedDigestedPrey )
end
