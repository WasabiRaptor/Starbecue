---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field

local inited

sbq = {
	config = root.assetJson("/sbqGeneral.config"),
	data = {
		settings = { personality = "default", mood = "default" },
		defaultPortrait = "/empty_image.png",
		icons = {
			bellyInfusion = "/items/active/sbqController/bellyInfusion.png",
			breastsInfusion = "/items/active/sbqController/breastsInfusion.png",
			pussyInfusion = "/items/active/sbqController/pussyInfusion.png",
			cockInfusion = "/items/active/sbqController/cockInfusion.png",
			ballsInfusion = "/items/active/sbqController/ballsInfusion.png",
			shaftBallsInfusion = "/items/active/sbqController/shaftBallsInfusion.png"
		}
	}
}
dialogueBoxScripts = {}
optionCheckScripts = {}

speciesOverride = {}

function speciesOverride._species()
	return (status.statusProperty("speciesAnimOverrideData") or {}).species or speciesOverride.species()
end

function speciesOverride._gender()
	return (status.statusProperty("speciesAnimOverrideData") or {}).gender or speciesOverride.gender()
end
speciesOverride.species = player.species
player.species = speciesOverride._species

speciesOverride.gender = player.gender
player.gender = speciesOverride._gender

require("/scripts/SBQ_RPC_handling.lua")
require("/lib/stardust/json.lua")
require("/interface/scripted/sbq/sbqDialogueBox/sbqDialogueBoxScripts.lua")
require("/interface/scripted/sbq/sbqDialogueBox/scripts/player.lua")


function init()
	sbq.name = world.entityName(pane.sourceEntity())
	nameLabel:setText(sbq.name)

	local species = (metagui.inputData.settings or {}).race or world.entitySpecies(pane.sourceEntity())
	if species then
		for i, voreType in ipairs(sbq.config.voreTypes) do
			local icon =  "/items/active/sbqController/"..voreType..".png".. (metagui.inputData.iconDirectives or "")
			local success, notEmpty = pcall(root.nonEmptyRegion, ("/humanoid/" .. species .. "/voreControllerIcons/" .. voreType .. ".png"))
			if success and notEmpty ~= nil then
				icon = "/humanoid/" .. species .. "/voreControllerIcons/" .. voreType .. ".png" ..  (metagui.inputData.iconDirectives or "")
			end
			sbq.data.icons[voreType] = icon
		end
	else
		for i, voreType in ipairs(sbq.config.voreTypes) do
			local icon =  "/items/active/sbqController/"..voreType..".png".. (metagui.inputData.iconDirectives or "")
			sbq.data.icons[voreType] = icon
		end
	end

	sbq.data = sb.jsonMerge(sbq.data, metagui.inputData)
	if sbq.data.settings.playerPrey then
		sbq.data.settings = sb.jsonMerge(sbq.data.settings, sb.jsonMerge( sbq.config.defaultPreyEnabled.player, player.getProperty("sbqPreyEnabled") or {}))
	end
	sbq.data.settings.playerRace = player.species()

	sbq.settings = sb.jsonMerge(sbq.data.settings, (player.getProperty("sbqDialogueSettings") or {})[world.entityUniqueId(pane.sourceEntity()) or "noUUID"] or {})
	sbq.sbqData = (sbq.data.speciesConfig or {}).sbqData
	sbq.speciesConfig = sbq.data.speciesConfig

	for _, script in ipairs(sbq.data.dialogueBoxScripts or {}) do
		require(script)
	end
	if sbq.data.entityPortrait then
		dialoguePortraitCanvas:setVisible(true)
	else
		dialoguePortrait:setVisible(true)
	end
	sbq.dialogueTree = sbq.data.dialogueTree

	sbq.updateDialogueBox(sbq.data.dialogueTreeStart or ".greeting", sbq.dialogueTree )
end

function update()
	local dt = script.updateDt()
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	sbq.refreshData()
	sbq.getOccupancy()
end

function sbq.getOccupancy()
	if sbq.data.occupantHolder ~= nil then
		sbq.loopedMessage("getOccupancy", sbq.data.occupantHolder, "getOccupancyData", {}, function (occupancyData)
			sbq.occupant = occupancyData.occupant
			sbq.occupants = occupancyData.occupants
			sbq.actualOccupants = occupancyData.actualOccupants
			sbq.checkVoreButtonsEnabled()
		end)
	end
end

function sbq.refreshData()
	sbq.loopedMessage("refreshData", pane.sourceEntity(), "sbqRefreshDialogueBoxData", { player.id(), (player.getProperty("sbqCurrentData") or {}).type }, function (dialogueBoxData)
		sbq.data = sb.jsonMerge(sbq.data, dialogueBoxData)
	end)
end


local randomDialogueHandling = {
	{ "randomDialogue", "dialogue" },
	{ "randomPortrait", "portrait" },
	{ "randomButtonText", "buttonText" },
	{ "randomEmote", "emote" },
	{ "randomName", "name" },
}

function sbq.handleRandomDialogue(dialogueTree, dialogueTreeTop, rollno)
	for _, v in ipairs(randomDialogueHandling) do
		local randomVal = v[1]
		local resultVal = v[2]
		if not dialogue.result[resultVal] then
			local randomResult = sbq.getRandomDialogueTreeValue(sbq.settings, player.id(), rollno, dialogue.result[randomVal], dialogueTree, dialogueTreeTop)
			if type(randomResult) == "table" then
				dialogue.result = sb.jsonMerge(dialogue.result, randomResult)
				if randomResult.randomDialogue or randomResult.randomPortrait or randomResult.randomButtonText or randomResult.randomEmote or randomResult.randomName then
					return true
				end
			elseif type(randomResult) == "string" then
				dialogue.result[resultVal] = {randomResult}
			end
		end
	end
	return startAgain
end

function sbq.updateDialogueBox(path, dialogueTree, dialogueTreeTop)
	local dialogueTree, dialogueTreeTop = dialogueTree, dialogueTreeTop
	if path ~= nil then
		_, dialogueTree, dialogueTreeTop = sbq.getDialogueBranch(path, sbq.settings, player.id(), dialogueTree, dialogueTreeTop)
		if not dialogueTree then return false end
		dialogue.path = path

		sbq.prevDialogueBranch = dialogueTree

		if not dialogue.result.useLastRandom then
			dialogue.randomRolls = {}
		end
		if type(dialogue.result.dialogue) == "string" then
			dialogue.result.dialogue = sbq.getRedirectedDialogue(dialogue.result.dialogue, true, sbq.settings, dialogueTree, dialogueTreeTop)
			if type(dialogue.result.dialogue) == "table" and dialogue.result.dialogue.dialogue ~= nil then
				dialogue.result = sb.jsonMerge(dialogue.result, dialogue.result.dialogue)
			end
		end
		local handleRandom = true
		local startIndex = 1
		while handleRandom == true do
			handleRandom = sbq.handleRandomDialogue(dialogueTree, dialogueTreeTop, startIndex)
			startIndex = #dialogue.randomRolls + 1
		end
	end

	sbq.checkVoreButtonsEnabled()
	if not dialogue.result.dialogue then
		dialogue.finished = true
		return path, dialogueTree, dialogueTreeTop
	end

	local playerName = world.entityName(player.id())
	local speaker = pane.sourceEntity()
	local name = sbq.data.defaultName or world.entityName(pane.sourceEntity())
	local buttonText = "..."
	local portrait = sbq.data.defaultPortrait
	local printDialogue = sbq.generateKeysmashes(dialogue.result.dialogue[dialogue.position] or dialogue.result.dialogue[#dialogue.result.dialogue], dialogue.result.keysmashMin, dialogue.result.keysmashMax)

	if dialogue.result.speaker then
		speaker = dialogue.result.speaker[dialogue.position] or dialogue.result.speaker[#dialogue.result.speaker]
	end
	if dialogue.result.name then
		name = dialogue.result.name[dialogue.position] or dialogue.result.name[#dialogue.result.name]
	end
	if dialogue.result.buttonText then
		buttonText = dialogue.result.buttonText[dialogue.position] or dialogue.result.buttonText[#dialogue.result.buttonText]
	end
	if dialogue.result.portrait then
		portrait = dialogue.result.portrait[dialogue.position] or dialogue.result.portrait[#dialogue.result.portrait]
	end

	local tags = { entityname = playerName, dontSpeak = "", love = "", slowlove = "", confused = "",  sleepy = "", sad = "", infusedName = sb.jsonQuery(sbq.settings, (dialogue.result.location or sbq.settings.location or "default").."InfusedItem.parameters.npcArgs.npcParam.identity.name") or "" }
	local imagePortrait

	nameLabel:setText(name)
	dialogueCont:setText(buttonText)

	if sbq.data.entityPortrait then
		sbq.setPortrait( dialoguePortraitCanvas, world.entityPortrait(speaker, portrait), {32,8} )
	else
		dialoguePortrait:setFile(sbq.getPortraitPath(portrait))
	end

	dialogueLabel:setText(sb.replaceTags(printDialogue, tags))
	world.sendEntityMessage(speaker, "sbqSay", printDialogue, tags, imagePortrait, emote)

	if dialogue.position >= #dialogue.result.dialogue then
		dialogue.finished = true
		sbq.dismissAfterTimer(dialogue.result.dismissTime)
	end

	return path, dialogueTree, dialogueTreeTop
end

function sbq.getPortraitPath(portrait)
	if portrait[1] == "/" then
		return portrait
	else
		return (dialogue.result.portraitPath or sbq.data.portraitPath or "")..portrait
	end
end

function sbq.setPortrait( canvasName, data, offset )
	local canvas = widget.bindCanvas( canvasName.backingWidget )
	canvas:clear()
	for k,v in ipairs(data or {}) do
		local pos = v.position or {0, 0}
		canvas:drawImage(v.image, { pos[1]+offset[1], pos[2]+offset[2]}, 4, nil, true )
	end
end

local keysmashchars = {"a","s","d","f","g","h","j","k","","l",";","\'"}
function sbq.generateKeysmashes(input, lengthMin, lengthMax)
	local input = input or ""
	return input:gsub("<keysmash>", function ()
		local keysmash = ""
		for i = 1, math.random(lengthMin or 5, lengthMax or 15) do
			keysmash = keysmash..keysmashchars[math.random(#keysmashchars)]
		end
		return keysmash
	end)
end

function sbq.checkVoreTypeActive(voreType)
	if (not sbq.settings) or sbq.settings.isPrey then return "hidden" end
	if not (sbq.settings[voreType.."Pred"] --[[or sbq.settings[voreType.."PredEnable"] ]]) then return "hidden" end
	local currentData = player.getProperty( "sbqCurrentData") or {}

	local transition = (((sbq.speciesConfig.states or {})[sbq.state or "stand"] or {}).transitions or {})[voreType]
	if not transition then return "hidden" end

	if not sbq.checkSettings(transition.settings, sbq.settings) then return "hidden" end

	local locationName = (transition or {}).location
	if not locationName then return "hidden" end

	local locationData = sbq.sbqData.locations[locationName]
	if not locationData then return "hidden" end

	local size = status.statusProperty("sbqSize") or 1


	local preyEnabled = sb.jsonMerge( sbq.config.defaultPreyEnabled.player, (status.statusProperty("sbqPreyEnabled") or {}))
	if ( sbq.settings[voreType.."Pred"]) and preyEnabled.preyEnabled and preyEnabled[voreType] and ( currentData.type ~= "prey" ) then
		if sbq.settings[voreType .. "Pred"] and not (currentData.type == "driver" and (not currentData.edible)) then
			if type(sbq.data.occupantHolder) ~= "nil" and type(sbq.occupants) == "table" then
				if sbq.occupants[locationName] == nil then return "hidden" end
				if locationData.requiresInfusion and not sbq.settings[locationName .. "InfusedItem"] then return "needsInfusion" end
				if size < ((sbq.settings[voreType .. "PreferredPreySizeMin"] or 0.1) * (sbq.data.scale or 1)) then return "tooSmall", locationName, locationData end
				if size > ((sbq.settings[voreType .. "PreferredPreySizeMax"] or 1.25) * (sbq.data.scale or 1)) then return "tooBig", locationName, locationData end
				if sbq.getSidedLocationWithSpace(locationName, size) then return "request", locationName, locationData end
				return "full", locationName, locationData
			else
				return "request", locationName, locationData
			end
		else
			return "notFeelingIt", locationName, locationData
		end
	else
		return "hidden", locationName, locationData
	end
end

function sbq.getLocationSetting(location, setting, default)
	return sbq.settings[location..setting] or sbq.settings["default"..setting] or default
end

function sbq.locationSpaceAvailable(location, side)
	if sbq.getLocationSetting(location, "Hammerspace") and sbq.sbqData.locations[location].hammerspace then
		return math.huge
	end
	return (((sbq.sbqData.locations[location..(side or "")] or {}).max or 0) * ((sbq.data.scale or 1))) - (sbq.occupants[location..(side or "")] or 0)
end

function sbq.getSidedLocationWithSpace(location, size)
	local data = sbq.sbqData.locations[location] or {}
	local sizeMultiplied = ((size or 1) * (sbq.getLocationSetting(location, "Multiplier", 1) ))
	if data.sided then
		local leftHasSpace = sbq.locationSpaceAvailable(location, "L") > sizeMultiplied
		local rightHasSpace = sbq.locationSpaceAvailable(location, "R") > sizeMultiplied
		if sbq.occupants[location.."L"] == sbq.occupants[location.."R"] then
			if sbq.direction > 0 then -- thinking about it, after adding everything underneath to prioritize the one with less prey, this is kinda useless
				if leftHasSpace then return location, "L", data
				elseif rightHasSpace then return location, "R", data
				else return false end
			else
				if rightHasSpace then return location, "R", data
				elseif leftHasSpace then return location, "L", data
				else return false end
			end
		elseif sbq.occupants[location .. "L"] < sbq.occupants[location .. "R"] and leftHasSpace then return location, "L", data
		elseif sbq.occupants[location .. "L"] > sbq.occupants[location .. "R"] and rightHasSpace then return location, "R", data
		else return false end
	else
		if sbq.locationSpaceAvailable(location, "") > sizeMultiplied then
			return location, "", data
		end
	end
	return false
end

function sbq.checkVoreButtonsEnabled()
	if not sbq.speciesConfig then return end
	for i, voreType in pairs(sbq.config.voreTypes or {}) do
		local button = _ENV[voreType]
		if dialogue.result.hideVoreButtons then
			button:setVisible(false)
		else
			local active = sbq.checkVoreTypeActive(voreType)
			button:setVisible(active ~= "hidden")
			local image = sbq.data.icons[voreType]
			if active ~= "request" then
				image = image.."?brightness=-25?saturation=-100"
			end
			button:setImage(image)
		end
	end
	sbq.checkInfusionActionButtonsEnabled()
end

local alreadyInfused
local changeBackImage
function sbq.checkInfusionActionButtonsEnabled()
	local locationTFs = sbq.sbqData.locationTFs or {}

	alreadyInfused = false

	local bellyInfusionActive = sbq.checkInfusionActionActive("belly", locationTFs.belly )
	local ballsInfusionActive = sbq.checkInfusionActionActive("balls", locationTFs.balls or {"balls","shaft","womb"})
	local cockInfusionActive = sbq.checkInfusionActionActive("shaft", locationTFs.shaft or {"balls","shaft","womb"})
	local breastsInfusionActive = sbq.checkInfusionActionActive("breasts", locationTFs.breasts or {"belly", "breasts"})
	local pussyInfusionActive = sbq.checkInfusionActionActive("womb", locationTFs.womb or {"balls","shaft","womb"} )

	sbq.infusionButtonSetup(bellyInfusionActive, bellyInfusion, "bellyInfusion")
	sbq.infusionButtonSetup(ballsInfusionActive, ballsInfusion, "ballsInfusion")
	sbq.infusionButtonSetup(cockInfusionActive, cockInfusion, "cockInfusion")
	sbq.infusionButtonSetup(breastsInfusionActive, breastsInfusion, "breastsInfusion")
	sbq.infusionButtonSetup(pussyInfusionActive, pussyInfusion, "pussyInfusion")

	letOut:setVisible(alreadyInfused)
	if alreadyInfused and changeBackImage then
		changeBack:setImage(changeBackImage)
		changeBack:setVisible(true)
	else
		changeBack:setVisible(false)
	end

	sbq.infusionButtonSetup((ballsInfusionActive ~= "hidden") and (cockInfusionActive ~= "hidden") and cockInfusionActive or "hidden", shaftBallsInfusion, "shaftBallsInfusion")
end

function sbq.infusionButtonSetup(active, button, voreType)
	if dialogue.result.hideVoreButtons then
		button:setVisible(false)
	else
		button.active = active
		if active == "alreadyInfused" or active == "youreAlreadyInfused" then
			alreadyInfused = true
		end
		button:setVisible(active == "request" or active == "requestLayer")
		local image = sbq.data.icons[voreType]
		if active == "youreAlreadyInfused" then
			changeBackImage = image.."?brightness=-25?saturation=-100"
		end
		if active == "request" or active == "requestLayer" then
		else
			image = image.."?brightness=-25?saturation=-100"
		end
		button:setImage(image)
	end
end

function sbq.infusionButton(active, kind, locationName, locations)
	sbq.settings.voreType = kind
	sbq.settings.voreResponse = active
	sbq.settings.location = locationName
	sbq.settings.doingVore = "before"
	sbq.updateDialogueBox( ".infusePrey", sbq.dialogueTree)
	if active == "request" or active == "requestLayer" then
		sbq.timer("infuseMessage", dialogue.result.delay or 1.5, function ()
			world.sendEntityMessage(sbq.data.occupantHolder or pane.sourceEntity(), "infuseLocation", player.id(), locations or {locationName})
			sbq.timer("gotInfused", dialogue.result.delay or 1.5, function()
				sbq.settings.doingVore = "after"
				for i, occupant in pairs(sbq.occupant or {}) do
					if occupant.id == player.id() and occupant.flags.infused then
						sbq.updateDialogueBox( ".infusePrey", sbq.dialogueTree)
						return
					end
				end
				sbq.settings.voreResponse = "couldnt"
				sbq.updateDialogueBox(".infusePrey", sbq.dialogueTree)
			end)
		end)
	end
end

function sbq.checkInfusionActionActive(location, locations)
	if (not sbq.settings) then return "hidden" end
	local locationData = sbq.sbqData.locations[location]
	if not locationData or not locationData.infusion then return "hidden" end
	local currentData = player.getProperty( "sbqCurrentData") or {}
	local preyEnabled = sb.jsonMerge( sbq.config.defaultPreyEnabled.player, (status.statusProperty("sbqPreyEnabled") or {}))
	if (sbq.settings[(locationData.infusionSetting or "infusion") .. "Pred"]) and preyEnabled.preyEnabled and
		preyEnabled[(locationData.infusionSetting or "infusion")] and (currentData.type == "prey")
	then
		local playerLocation
		local isInfused
		for i, occupant in pairs(sbq.occupant or {}) do
			if occupant.id == player.id() then
				playerLocation = occupant.location
				isInfused = occupant.flags.infused
			end
		end
		if not playerLocation then return "hidden" end
		if (playerLocation == location) then
			if playerLocation ~= location then return "otherLocation" end
			local npcArgs = ((sbq.settings[location .. "InfusedItem"] or {}).parameters or {}).npcArgs
			if npcArgs then
				local uniqueId = ((npcArgs.npcParam or {}).scriptConfig or {}).uniqueId
				if uniqueId and world.entityUniqueId(player.id()) == uniqueId then
					return "youreAlreadyInfused"
				end
			end
			if isInfused then return "alreadyInfused" end
			return "request"
		end
		for i, location in ipairs(locations or {}) do
			if playerLocation == location then
				local npcArgs = ((sbq.settings[location .. "InfusedItem"] or {}).parameters or {}).npcArgs
				if npcArgs then
				end
				if isInfused then return "alreadyInfused" end
				return "request"
			end
		end
		return "otherLocation"
	else return "hidden" end
end

function sbq.voreButton(voreType)
	local active, locationName, locationData = sbq.checkVoreTypeActive(voreType)
	sbq.settings.voreType = voreType
	sbq.settings.voreResponse = active
	sbq.settings.location = locationName
	sbq.settings.doingVore = "before"
	sbq.updateDialogueBox( ".vore", sbq.dialogueTree )
	if active == "request" then
		sbq.timer("eatMessage", dialogue.result.delay or 1.5, function ()
			world.sendEntityMessage(sbq.data.occupantHolder or pane.sourceEntity(), "requestTransition", voreType,
				{ id = player.id(), willing = true })
			sbq.timer("gotVored", dialogue.result.delay or 1.5, function()
				sbq.settings.doingVore = "after"
				for i, occupant in pairs(sbq.occupant or {}) do
					if occupant.id == player.id() then
						sbq.updateDialogueBox( ".vore", sbq.dialogueTree)
						return
					end
				end
				sbq.settings.voreResponse = "couldnt"
				sbq.updateDialogueBox(".vore", sbq.dialogueTree )
			end)
		end)
	end
end

function sbq.dismissAfterTimer(time)
	if not time then
		sbq.timerList.dismissAfterTime = nil
	else
		sbq.forceTimer("dismissAfterTime", time, function()
			if not dialogue.finished then
				sbq.updateDialogueBox()
			elseif dialogue.result.jump then
				local path = dialogue.result.jump
				sbq.finishDialogue()
				sbq.updateDialogueBox(path, sbq.prevDialogueBranch, sbq.dialogueTree)
			else
				pane.dismiss()
			end
		end)
	end
end

function dialogueCont:onClick()
	local contextMenu = {}
	if not dialogue.finished then
		dialogue.position = dialogue.position + 1
		return sbq.updateDialogueBox()
	end

	if type(dialogue.result.saveSettings) == "table" then
		for setting, value in pairs(dialogue.result.saveSettings) do

		end
	end
	if type(dialogue.result.playerSaveSettings) == "table" then
		local settings = player.getProperty("sbqDialogueSettings") or {}
		local uuid = dialogue.result.saveForUUID or world.entityUniqueId(pane.sourceEntity()) or "noUUID"
		settings[uuid] = settings[uuid] or {}
		for setting, value in pairs(dialogue.result.playerSaveSettings) do
			settings[uuid][setting] = value
			sbq.settings[setting] = value
		end
		player.setProperty("sbqDialogueSettings", settings)
	end
	if type(dialogue.result.callScript) == "string" then
		if type(dialogueBoxScripts[dialogue.result.callScript]) == "function" then
			local path = dialogueBoxScripts[dialogue.result.callScript](sbq.prevDialogueBranch, sbq.dialogueTree, sbq.settings,
				"callScript", player.id(), table.unpack(dialogue.result.scriptArgs or {}))
			if path then
				sbq.updateDialogueBox(path, sbq.prevDialogueBranch, sbq.dialogueTree)
			end
		end
	elseif dialogue.result.options ~= nil then
		for i, option in ipairs(dialogue.result.options) do
			local action = { option[1] }
			local checks = option[3] or {}
			local path = option[2]
			local continue = true
			local entities = {}
			if continue and (type(checks.checkScript) == "string") then
				if (type(optionCheckScripts[checks.checkScript]) == "function") then
					continue = optionCheckScripts[checks.checkScript](sbq.settings, table.unpack(checks.checkScriptArgs or {}))
				else continue = false
				end
			end
			if continue and (type(checks.check) == "table") then
				continue = sbq.checkSettings(checks.check, sbq.settings)
			end
			if continue and (type(checks.checkPlayer) == "table") then
				continue = sbq.checkSettings(checks.checkPlayer, sb.jsonMerge(sb.jsonMerge(root.assetJson("/sbqGeneral.config:globalSettings"),root.assetJson("/sbqGeneral.config:defaultPreyEnabled.player")),sb.jsonMerge((player.getProperty("sbqSettings") or {}).global or {}, status.statusProperty("sbqPreyEnabled") or {})))
			end
			if continue and checks.checkPlayerLikesKinks ~= nil then
				local settings = sb.jsonMerge(sb.jsonMerge(root.assetJson("/sbqGeneral.config:globalSettings"),
					root.assetJson("/sbqGeneral.config:defaultPreyEnabled.player")),
					sb.jsonMerge((player.getProperty("sbqSettings") or {}).global or {}, status.statusProperty("sbqPreyEnabled") or {}))
				for i, kink in ipairs(checks.checkPlayerLikesKinks) do
					if not (settings[kink] or settings[kink.."Pred"]) then
						continue = false break
					end
				end
			end
			if continue and checks.nearEntitiesNamed ~= nil then
				continue = false
				local found = checkEntityName( world.entityQuery( world.entityPosition(player.id()), checks.range or 10, checks.queryArgs or {includedTypes = {"object", "npc", "vehicle", "monster"}}), checks.nearEntitiesNamed)
				for _, id in ipairs(found) do
					continue = true
					table.insert(entities, id)
				end
			end
			if continue and checks.nearUniqueId ~= nil then
				local found = checkEntityUniqueId( world.entityQuery( world.entityPosition(player.id()), checks.range or 10, checks.queryArgs or {includedTypes = {"object", "npc", "vehicle", "monster"}}), checks.nearUniqueId)
				for _, id in ipairs(found) do
					continue = true
					table.insert(entities, id)
				end
			end
			if continue and ((checks.voreType == nil) or (sbq.checkVoreTypeActive(checks.voreType) ~= "hidden")) then
				action[2] = function()
					sbq.finishDialogue()
					if type(path) == "table" then
						local newpath = "."
						for i, step in ipairs(path) do
							newpath = newpath.."."..tostring(sbq.doNextStep(step, settings, eid, sbq.prevDialogueBranch, sbq.dialogueTree, sbq.prevDialogueBranch.useStepPath))
						end
						path = newpath
					end
					sbq.updateDialogueBox( path, sbq.prevDialogueBranch, sbq.dialogueTree )
				end
				table.insert(contextMenu, action)
			end
		end
	elseif dialogue.result.continue ~= nil then
		local continue = true
		local entities = {}
		if continue and dialogue.result.continue.nearEntitiesNamed ~= nil then
			continue = false
			local found = checkEntityName( world.entityQuery( world.entityPosition(player.id()), dialogue.result.continue.range or 10, dialogue.result.continue.queryArgs or {includedTypes = {"object", "npc", "vehicle", "monster"}}), dialogue.result.continue.nearEntitiesNamed)
			for _, id in ipairs(found) do
				continue = true
				table.insert(entities, id)
			end
		end
		if continue and dialogue.result.continue.nearUniqueId ~= nil then
			local found = checkEntityUniqueId( world.entityQuery( world.entityPosition(player.id()), dialogue.result.continue.range or 10, dialogue.result.continue.queryArgs or {includedTypes = {"object", "npc", "vehicle", "monster"}}), dialogue.result.continue.nearUniqueId)
			for _, id in ipairs(found) do
				continue = true
				table.insert(entities, id)
			end
		end
		local path = dialogue.result.continue.fail
		if continue then
			path = dialogue.result.continue.path
		end
		sbq.finishDialogue()
		sbq.updateDialogueBox(path, sbq.prevDialogueBranch, sbq.dialogueTree)
		return
	elseif dialogue.result.jump ~= nil then
		local path = dialogue.result.jump
		sbq.finishDialogue()
		sbq.updateDialogueBox(path, sbq.prevDialogueBranch, sbq.dialogueTree)
		return
	end
	if #contextMenu > 0 then
		metagui.dropDownMenu(contextMenu, dialogue.result.optionsColumns or 2, dialogue.result.optionsW, dialogue.result.optionsH, dialogue.result.optionsS, dialogue.result.optionsAlign)
	end
	if dialogue.finished and dialogue.result.options == nil then
		sbq.finishDialogue()
	end
end

function checkEntityName(entities, find)
	local found = {}
	local continue
	for _, name in ipairs(find) do
		for _, entity in ipairs(entities) do
			if name == world.entityName(entity) then
				table.insert(found, entity)
				continue = true
			end
		end
		if not continue then return {} end
	end
	return found
end

function checkEntityUniqueId(entities, find)
	local found = {}
	local continue
	for _, name in ipairs(find) do
		for _, entity in ipairs(entities) do
			if name == world.entityUniqueId(entity) then
				table.insert(found, entity)
				continue = true
			end
		end
		if not continue then return {} end
	end
	return found
end

function close:onClick()
	pane.dismiss()
end

-----------------------------------------------------------

function oralVore:onClick()
	sbq.voreButton("oralVore")
end

function tailVore:onClick()
	sbq.voreButton("tailVore")
end

function absorbVore:onClick()
	sbq.voreButton("absorbVore")
end

function navelVore:onClick()
	sbq.voreButton("navelVore")
end

function analVore:onClick()
	sbq.voreButton("analVore")
end

function cockVore:onClick()
	sbq.voreButton("cockVore")
end

function breastVore:onClick()
	sbq.voreButton("breastVore")
end

function unbirth:onClick()
	sbq.voreButton("unbirth")
end

-----------------------------------------------------------

function bellyInfusion:onClick()
	sbq.infusionButton(self.active, "bellyInfusion", "belly" )
end

function pussyInfusion:onClick()
	sbq.infusionButton(self.active, "pussyInfusion", "womb" )
end

function breastsInfusion:onClick()
	sbq.infusionButton(self.active, "breastsInfusion", "breasts" )
end

function cockInfusion:onClick()
	sbq.infusionButton(self.active, "cockInfusion", "shaft" )
end

function ballsInfusion:onClick()
	sbq.infusionButton(self.active, "ballsInfusion", "balls" )
end

function shaftBallsInfusion:onClick()
	sbq.infusionButton(self.active, "cockInfusion", "shaft", {"shaft","balls"} )
end

-----------------------------------------------------------

function letOut:onClick()
	world.sendEntityMessage(sbq.data.occupantHolder or pane.sourceEntity(), "letout", player.id())
end

function changeBack:onClick()
	sbq.addRPC(world.sendEntityMessage(sbq.data.occupantHolder, "changeBack", player.id()),function ()
		world.sendEntityMessage(pane.sourceEntity(), "changeBack", world.entityUniqueId(player.id()))
	end)
end
