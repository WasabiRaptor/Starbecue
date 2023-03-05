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
	sbq.sbqData = sbq.data.sbqData

	for _, script in ipairs(sbq.data.dialogueBoxScripts or {}) do
		require(script)
	end
	if sbq.data.entityPortrait then
		dialoguePortraitCanvas:setVisible(true)
	else
		dialoguePortrait:setVisible(true)
	end
	sbq.dialogueTree = sbq.data.dialogueTree


	sbq.updateDialogueBox(sbq.data.dialogueTreeStart or { "greeting" })
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


local prevRandomRolls = {}
local finished = false
local dialoguePos = 1

function sbq.updateDialogueBox(dialogueTreeLocation, dialogueTree)
	local dialogueTree = sbq.getDialogueBranch(dialogueTreeLocation, sbq.settings, player.id(), dialogueTree)
	if not dialogueTree then return false end
	recursionCount = 0 -- since we successfully made it here, reset the recursion count

	sbq.prevDialogueBranch = dialogueTree

	sbq.checkVoreButtonsEnabled()

	local randomDialogue = dialogueTree.randomDialogue
	local randomPortrait = dialogueTree.randomPortrait
	local randomName = dialogueTree.randomName
	local randomButtonText = dialogueTree.randomButtonText
	local randomEmote = dialogueTree.randomEmote

	local randomRolls = {}

	if dialogueTree.useLastRandom then
		randomRolls = prevRandomRolls
	end
	-- we want to make sure the rolls for the portraits and the dialogue line up
	randomRolls, randomDialogue		= sbq.getRandomDialogueTreeValue(dialogueTree, sbq.settings, randomRolls, randomDialogue, "randomDialogue")
	randomRolls, randomPortrait		= sbq.getRandomDialogueTreeValue(dialogueTree, sbq.settings, randomRolls, randomPortrait, "randomPortrait")
	randomRolls, randomName			= sbq.getRandomDialogueTreeValue(dialogueTree, sbq.settings, randomRolls, randomName, "randomName")
	randomRolls, randomButtonText	= sbq.getRandomDialogueTreeValue(dialogueTree, sbq.settings, randomRolls, randomButtonText, "randomButtonText")
	randomRolls, randomEmote		= sbq.getRandomDialogueTreeValue(dialogueTree, sbq.settings, randomRolls, randomEmote, "randomEmote")

	prevRandomRolls = randomRolls

	local playerName = world.entityName(player.id())
	local speaker = pane.sourceEntity()

	if dialogueTree.speaker ~= nil then
		if type(dialogueTree.speaker) == "table" then
			speaker = dialogueTree.speaker[dialoguePos] or dialogueTree.speaker[#dialogueTree.speaker]
		end
		speaker = dialogueTree.speaker
	end
	local tags = { entityname = playerName, dontSpeak = "", love = "", slowlove = "", confused = "",  sleepy = "", sad = "", infusedName = (((((sbq.settings[(dialogueTree.location or sbq.settings.location or "").."InfusedItem"] or {}).parameters or {}).npcArgs or {}).npcParam or {}).identity or {}).name or "" }
	local imagePortrait

	if type(randomName) == "string" then
		nameLabel:setText(randomName)
	elseif dialogueTree.name ~= nil then
		if type(dialogueTree.name) == "table" then
			nameLabel:setText(dialogueTree.name[dialoguePos] or dialogueTree.name[#dialogueTree.name] or sbq.data.defaultName or world.entityName(pane.sourceEntity()))
		else
			nameLabel:setText(dialogueTree.name)
		end
	else
		nameLabel:setText(sbq.data.defaultName or world.entityName(pane.sourceEntity()))
	end

	if type(randomButtonText) == "string" then
		dialogueCont:setText(randomButtonText)
	elseif dialogueTree.buttonText ~= nil then
		if type(dialogueTree.buttonText) == "table" then
			dialogueCont:setText(dialogueTree.buttonText[dialoguePos] or dialogueTree.buttonText[#dialogueTree.buttonText] or "...")
		else
			dialogueCont:setText(dialogueTree.buttonText)
		end
	else
		dialogueCont:setText("...")
	end

	if type(randomPortrait) == "string" then
		if sbq.data.entityPortrait then
			sbq.setPortrait( dialoguePortraitCanvas, world.entityPortrait( speaker, randomPortrait or sbq.data.defaultPortrait ), {32,8} )
		else
			dialoguePortrait:setFile(sbq.getPortraitPath(dialogueTree, (randomPortrait or sbq.data.defaultPortrait)))
		end
	elseif dialogueTree.portrait ~= nil then
		if type(dialogueTree.portrait) == "table" then
			if sbq.data.entityPortrait then
				sbq.setPortrait( dialoguePortraitCanvas, world.entityPortrait( speaker, dialogueTree.portrait[dialoguePos] or dialogueTree.portrait[#dialogueTree.portrait] or sbq.data.defaultPortrait ), {32,8} )
			else
				dialoguePortrait:setFile(sbq.getPortraitPath(dialogueTree, (dialogueTree.portrait[dialoguePos] or dialogueTree.portrait[#dialogueTree.portrait] or sbq.data.defaultPortrait)))
			end
		else
			if sbq.data.entityPortrait then
				sbq.setPortrait( dialoguePortraitCanvas, world.entityPortrait( speaker, dialogueTree.portrait or sbq.data.defaultPortrait ), {32,8} )
			else
				dialoguePortrait:setFile(sbq.getPortraitPath(dialogueTree, (dialogueTree.portrait or sbq.data.defaultPortrait) ))
			end
		end
	else
		if sbq.data.entityPortrait then
			sbq.setPortrait( dialoguePortraitCanvas, world.entityPortrait( speaker, sbq.data.defaultPortrait ), {32,8} )
		else
			dialoguePortrait:setFile(sbq.getPortraitPath(dialogueTree, (sbq.data.defaultPortrait)))
		end
	end

	if type(randomDialogue) == "string" then
		local randomDialogue = sbq.generateKeysmashes(randomDialogue, dialogueTree.keysmashMin, dialogueTree.keysmashMax)
		dialogueLabel:setText(sb.replaceTags(randomDialogue, tags))
		world.sendEntityMessage(speaker, "sbqSay", randomDialogue, tags, imagePortrait, randomEmote)
		finished = true
	elseif dialogueTree.dialogue ~= nil then
		local dialogue = sbq.generateKeysmashes(dialogueTree.dialogue[dialoguePos] or dialogueTree.dialogue[#dialogueTree.dialogue], dialogueTree.keysmashMin, dialogueTree.keysmashMax)
		dialogueLabel:setText(sb.replaceTags(dialogue, tags ))
		world.sendEntityMessage(speaker, "sbqSay", dialogue, tags, imagePortrait, (dialogueTree.emote or {})[dialoguePos])
		if dialoguePos >= #dialogueTree.dialogue then
			finished = true
			dialoguePos = 1
		else
			dialoguePos = dialoguePos + 1
		end
	else
		dialogueLabel:setText("")
	end

	sbq.dismissAfterTimer(dialogueTree.dismissTime)

	return dialogueTree, randomRolls
end

function sbq.getPortraitPath(dialogueTree, portrait)
	if portrait:find("^/") then
		return portrait
	else
		return (dialogueTree.portraitPath or sbq.data.portraitPath or "")..portrait
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

	local locationName = sbq.sbqData.voreTypes[voreType]
	if not locationName then return "hidden" end

	local locationData = sbq.sbqData.locations[locationName]
	if not locationData then return "hidden" end

	local size = status.statusProperty("sbqSize") or 1


	local preyEnabled = sb.jsonMerge( sbq.config.defaultPreyEnabled.player, (status.statusProperty("sbqPreyEnabled") or {}))
	if ( sbq.settings[voreType.."Pred"]) and preyEnabled.preyEnabled and preyEnabled[voreType] and ( currentData.type ~= "prey" ) then
		if sbq.settings[voreType .. "Pred"] and not (currentData.type == "driver" and (not currentData.edible)) then
			if type(sbq.data.occupantHolder) ~= "nil" and type(sbq.occupants) == "table" then
				if sbq.occupants[locationName] == nil then return "hidden" end
				if locationData.requiresInfusion and not sbq.settings[locationName.."InfusedItem"] then return "needsInfusion" end
				local full = (
					not locationData.sided
					and ((sbq.occupants[locationName] + size) > (sbq.settings[locationName .. "VisualMax"] or locationData.max))
					and not (sbq.settings[locationName .. "Hammerspace"])
				)
				local sidedFull = (
					locationData.sided
					and ((sbq.occupants[locationName.."L"] + size) > (sbq.settings[locationName .. "VisualMax"] or locationData.max))
					and ((sbq.occupants[locationName.."R"] + size) > (sbq.settings[locationName .. "VisualMax"] or locationData.max))
					and not (sbq.settings[locationName .. "Hammerspace"])
				)
				if full or sidedFull then
					return "tooBig", locationName, locationData
				elseif not locationData.sided and (sbq.occupants[locationName] >= (sbq.settings[locationName.."VisualMax"] or locationData.max))
				or locationData.sided and (
					(sbq.occupants[locationName.."L"] >= (sbq.settings[locationName.."LVisualMax"] or locationData.max))
					and (sbq.occupants[locationName.."R"] >= (sbq.settings[locationName.."RVisualMax"] or locationData.max))
				)
				then
					if sbq.actualOccupants == 0 then
						return "otherLocationFull", locationName, locationData
					else
						return "full", locationName, locationData
					end
				else
					return "request", locationName, locationData
				end
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

function sbq.checkVoreButtonsEnabled()
	if not sbq.sbqData then return end
	for i, voreType in pairs(sbq.config.voreTypes or {}) do
		local button = _ENV[voreType]
		if (sbq.prevDialogueBranch or {}).hideVoreButtons then
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
	local breastsInfusionActive = sbq.checkInfusionActionActive("breasts", locationTFs.breasts)
	local pussyInfusionActive = sbq.checkInfusionActionActive("womb", locationTFs.womb or {"balls","shaft","womb"} )

	sbq.infusionButtonSetup(bellyInfusionActive, bellyInfusion, "bellyInfusion")
	sbq.infusionButtonSetup(ballsInfusionActive, ballsInfusion, "ballsInfusion")
	sbq.infusionButtonSetup(cockInfusionActive, cockInfusion, "cockInfusion")
	sbq.infusionButtonSetup(breastsInfusionActive, breastsInfusion, "breastsInfusion")
	sbq.infusionButtonSetup(pussyInfusionActive, pussyInfusion, "pussyInfusion")

	letOut:setVisible(alreadyInfused)
	if alreadyInfused and changeBackImage then
		--changeBack:setImage(changeBackImage)
		--changeBack:setVisible(true)
	end

	sbq.infusionButtonSetup((ballsInfusionActive ~= "hidden") and (cockInfusionActive ~= "hidden") and cockInfusionActive or "hidden", shaftBallsInfusion, "shaftBallsInfusion")
end

function sbq.infusionButtonSetup(active, button, voreType)
	if (sbq.prevDialogueBranch or {}).hideVoreButtons then
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
	sbq.settings.getVoreButtonAction = active
	sbq.settings.location = locationName
	if active == "request" or active == "requestLayer" then
		sbq.settings.doingVore = "before"
		local dialogueTree = sbq.updateDialogueBox({ "infusePrey" }) or {}
		sbq.timer("infuseMessage", dialogueTree.delay or 1.5, function ()
			world.sendEntityMessage(sbq.data.occupantHolder or pane.sourceEntity(), "infuseLocation", player.id(), locations)
			sbq.timer("gotInfused", dialogueTree.delay or 1.5, function ()
				for i, occupant in pairs(sbq.occupant or {}) do
					if occupant.id == player.id() and occupant.flags.infused then
						sbq.settings.doingVore = "after"
						sbq.updateDialogueBox({ "infusePrey" })
						return
					end
				end
				sbq.settings.getVoreButtonAction = "notFeelingIt"
				sbq.updateDialogueBox({ "infusePrey" })
			end)
		end)
	else
		sbq.updateDialogueBox({ "infusePrey" })
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
		if not locations then
			if playerLocation ~= location then return "otherLocation" end
			local npcArgs = ((sbq.settings[location .. "InfusedItem"] or {}).parameters or {}).npcArgs
			if npcArgs then
				local uniqueId = (npcArgs.scriptConfig or {}).uniqueId
				if uniqueId and world.entityUniqueId(player.id()) == uniqueId then
					return "youreAlreadyInfused"
				end
				if isInfused then return "alreadyInfused" end
				return "requestLayer"
			end
			if isInfused then return "alreadyInfused" end
			return "request"
		end
		for i, location in ipairs(locations or {}) do
			if playerLocation == location then
				local npcArgs = ((sbq.settings[location .. "InfusedItem"] or {}).parameters or {}).npcArgs
				if npcArgs then
					local uniqueId = (npcArgs.scriptConfig or {}).uniqueId
					if uniqueId and world.entityUniqueId(player.id()) == uniqueId then
						return "youreAlreadyInfused"
					end
					if isInfused then return "alreadyInfused" end
					return "requestLayer"
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
	sbq.settings.getVoreButtonAction = active
	sbq.settings.location = locationName

	if active == "request" then
		sbq.settings.doingVore = "before"
		local dialogueTree = sbq.updateDialogueBox({ "vore" }) or {}
		sbq.timer("eatMessage", dialogueTree.delay or 1.5, function ()
			world.sendEntityMessage(sbq.data.occupantHolder or pane.sourceEntity(), "requestTransition", voreType,
				{ id = player.id() })
			sbq.timer("gotVored", dialogueTree.delay or 1.5, function ()
				for i, occupant in pairs(sbq.occupant or {}) do
					if occupant.id == player.id() then
						sbq.settings.doingVore = "after"
						sbq.updateDialogueBox({ "vore" })
						return
					end
				end
				sbq.settings.getVoreButtonAction = "notFeelingIt"
				sbq.updateDialogueBox({ "vore" })
			end)
		end)
	else
		sbq.updateDialogueBox({ "vore" })
	end
end

function sbq.dismissAfterTimer(time)
	if not time then
		sbq.timerList.dismissAfterTime = nil
	else
		sbq.forceTimer("dismissAfterTime", time, function ()
			pane.dismiss()
		end)
	end
end

function dialogueCont:onClick()
	local contextMenu = {}
	if not finished then
		return sbq.updateDialogueBox({}, sbq.prevDialogueBranch)
	else
		finished = false
	end
	if type(sbq.prevDialogueBranch.saveSettings) == "table" then
		for setting, value in pairs(sbq.prevDialogueBranch.saveSettings) do

		end
	end
	if type(sbq.prevDialogueBranch.playerSaveSettings) == "table" then
		local settings = player.getProperty("sbqDialogueSettings") or {}
		local uuid = sbq.prevDialogueBranch.saveForUUID or world.entityUniqueId(pane.sourceEntity()) or "noUUID"
		settings[uuid] = settings[uuid] or {}
		for setting, value in pairs(sbq.prevDialogueBranch.playerSaveSettings) do
			settings[uuid][setting] = value
			sbq.settings[setting] = value
		end
		player.setProperty("sbqDialogueSettings", settings)
	end
	if type(sbq.prevDialogueBranch.callScript) == "string" then
		if type(dialogueBoxScripts[sbq.prevDialogueBranch.callScript]) == "function" then
			local dialogueTree = dialogueBoxScripts[sbq.prevDialogueBranch.callScript](sbq.prevDialogueBranch, sbq.settings,"callScript", player.id(), table.unpack(sbq.prevDialogueBranch.scriptArgs or {}))
			if dialogueTree then sbq.updateDialogueBox({}, dialogueTree) end
		end
	elseif sbq.prevDialogueBranch.continue ~= nil then
		local continue = true
		local entities = {}
		if continue and sbq.prevDialogueBranch.continue.nearEntitiesNamed ~= nil then
			continue = false
			local found = checkEntityName( world.entityQuery( world.entityPosition(player.id()), sbq.prevDialogueBranch.continue.range or 10, sbq.prevDialogueBranch.continue.queryArgs or {includedTypes = {"object", "npc", "vehicle", "monster"}}), sbq.prevDialogueBranch.continue.nearEntitiesNamed)
			for _, id in ipairs(found) do
				continue = true
				table.insert(entities, id)
			end
		end
		if continue and sbq.prevDialogueBranch.continue.nearUniqueId ~= nil then
			local found = checkEntityUniqueId( world.entityQuery( world.entityPosition(player.id()), sbq.prevDialogueBranch.continue.range or 10, sbq.prevDialogueBranch.continue.queryArgs or {includedTypes = {"object", "npc", "vehicle", "monster"}}), sbq.prevDialogueBranch.continue.nearUniqueId)
			for _, id in ipairs(found) do
				continue = true
				table.insert(entities, id)
			end
		end
		if continue then
			sbq.updateDialogueBox({}, sbq.prevDialogueBranch.continue)
		else
			sbq.updateDialogueBox({}, sbq.prevDialogueBranch.fail)
		end
	elseif sbq.prevDialogueBranch.jump ~= nil then
		sbq.updateDialogueBox(sbq.prevDialogueBranch.jump)
	elseif sbq.prevDialogueBranch.options ~= nil then
		for i, option in ipairs(sbq.prevDialogueBranch.options) do
			local action = {option[1]}
			local continue = true
			local entities = {}
			if continue and option[2].check ~= nil then
				continue = sbq.checkSettings(option[2].check, sbq.settings)
			end
			if continue and option[2].checkPlayer ~= nil then
				continue = sbq.checkSettings(option[2].checkPlayer, sb.jsonMerge(sb.jsonMerge(root.assetJson("/sbqGeneral.config:globalSettings"),root.assetJson("/sbqGeneral.config:defaultPreyEnabled.player")),sb.jsonMerge((player.getProperty("sbqSettings") or {}).global or {}, status.statusProperty("sbqPreyEnabled") or {})))
			end
			if continue and option[2].checkPlayerLikesKinks ~= nil then
				local settings = sb.jsonMerge(sb.jsonMerge(root.assetJson("/sbqGeneral.config:globalSettings"),
					root.assetJson("/sbqGeneral.config:defaultPreyEnabled.player")),
					sb.jsonMerge((player.getProperty("sbqSettings") or {}).global or {}, status.statusProperty("sbqPreyEnabled") or {}))
				for i, kink in ipairs(option[2].checkPlayerLikesKinks) do
					if not (settings[kink] or settings[kink.."Pred"]) then
						continue = false break
					end
				end
			end
			if continue and option[2].nearEntitiesNamed ~= nil then
				continue = false
				local found = checkEntityName( world.entityQuery( world.entityPosition(player.id()), option[2].range or 10, sbq.prevDialogueBranch.continue.queryArgs or {includedTypes = {"object", "npc", "vehicle", "monster"}}), option[2].nearEntitiesNamed)
				for _, id in ipairs(found) do
					continue = true
					table.insert(entities, id)
				end
			end
			if continue and option[2].nearUniqueId ~= nil then
				local found = checkEntityUniqueId( world.entityQuery( world.entityPosition(player.id()), option[2].range or 10, sbq.prevDialogueBranch.continue.queryArgs or {includedTypes = {"object", "npc", "vehicle", "monster"}}), option[2].nearUniqueId)
				for _, id in ipairs(found) do
					continue = true
					table.insert(entities, id)
				end
			end
			if continue and ((option[2].voreType == nil) or ( sbq.checkVoreTypeActive(option[2].voreType) ~= "hidden" )) then
				if option[2].dialogue ~= nil or option[2].randomDialogue ~= nil or option[2].next then
					action[2] = function ()
						for _, entity in ipairs(entities) do
							world.sendEntityMessage( entity, "sbqSetInteracted", player.id())
						end
						sbq.updateDialogueBox( {}, option[2] )
					end
				elseif option[2].jump ~= nil then
					action[2] = function() sbq.updateDialogueBox(option[2].jump) end
				elseif type(option[2].callScript) == "string" and type(dialogueBoxScripts[option[2].callScript]) == "function" then
					action[2] = function()
						local dialogueTree = dialogueBoxScripts[option[2].callScript](option[2], sbq.settings, "callScript", player.id(), table.unpack(option[2].scriptArgs or {}))
						if dialogueTree then sbq.updateDialogueBox({}, dialogueTree) end
					end
				end
				table.insert(contextMenu, action)
			end
		end
	elseif type(sbq.dialogueTreeReturn) == "table" then -- if nothing else above was triggered, theres nothing to continue to, so might as well jump to a return point if we have one
		sbq.updateDialogueBox(sbq.dialogueTreeReturn)
	end
	if #contextMenu > 0 then
		metagui.contextMenu(contextMenu)
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
end
