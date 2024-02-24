
dialogueBoxScripts = {}
optionCheckScripts = {}

function init()
	sbq.name = world.entityName(pane.sourceEntity())
    nameLabel:setText(sbq.name)

	sbq.entityId = pane.sourceEntity

	-- local species = (metagui.inputData.settings or {}).race or world.entitySpecies(pane.sourceEntity())
    -- if species then
	-- 	sbq.data.icons = sb.jsonMerge(sbq.data.icons, root.speciesConfig(species).voreIcons or {})
    -- end
	-- for voreType, icon in pairs(sbq.data.icons) do
	-- 	sbq.data.icons[voreType] = icon..(metagui.inputData.iconDirectives or "")
	-- end

	-- sbq.data = sb.jsonMerge(sbq.data, metagui.inputData)
	-- if sbq.data.settings.playerPrey then
	-- 	sbq.data.settings = sb.jsonMerge(sbq.data.settings, sb.jsonMerge( sbq.config.defaultPreyEnabled.player, player.getProperty("sbqPreyEnabled") or {}))
	-- end
	-- sbq.occupant = metagui.inputData.occupant
	-- sbq.data.settings.playerRace = player.species()

	-- sbq.settings = sb.jsonMerge(sbq.data.settings, (player.getProperty("sbqDialogueSettings") or {})[world.entityUniqueId(pane.sourceEntity()) or "noUUID"] or {})
	-- sbq.sbqData = (sbq.data.speciesConfig or {}).sbqData
	-- sbq.speciesConfig = sbq.data.speciesConfig

	-- for _, script in ipairs(sbq.data.dialogueBoxScripts or {}) do
	-- 	require(script)
	-- end
	-- if sbq.data.entityPortrait then
	-- 	dialoguePortraitCanvas:setVisible(true)
	-- else
	-- 	dialoguePortrait:setVisible(true)
	-- end
	-- sbq.dialogueTree = sbq.data.dialogueTree

	-- sbq.updateDialogueBox(sbq.data.dialogueTreeStart or ".greeting", sbq.dialogueTree)
end

function update()
	local dt = script.updateDt()
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
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
				if (resultVal == "dialogue") and (sb.replaceTags(randomResult, {dontSpeak = "", love = "", slowlove = "", confused = "",  sleepy = "", sad = ""}) == "") then
					return true
				end
				dialogue.result[resultVal] = {randomResult}
			end
		end
	end
end

function sbq.updateDialogueBox(path, dialogueTree, dialogueTreeTop)
	_, dialogueTree, dialogueTreeTop = sbq.getDialogue()
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

	local tags = { entityname = playerName, dontSpeak = "", love = "", slowlove = "", confused = "",  sleepy = "", sad = "" }
	local imagePortrait

	nameLabel:setText(name)
	dialogueCont:setText(buttonText)

	if sbq.data.entityPortrait then
		sbq.setPortrait( dialoguePortraitCanvas, world.entityPortrait(speaker, portrait), {32,8} )
	else
		dialoguePortrait:setFile(sb.assetPath(portrait, dialogue.result.portraitPath or sbq.data.portraitPath or "/"))
	end

	dialogueLabel:setText(sb.replaceTags(printDialogue, tags), dialogue.result.textSounds[dialogue.position] or dialogue.result.textSounds[#dialogue.result.textSounds])
	world.sendEntityMessage(speaker, "sbqSay", printDialogue, tags, imagePortrait, emote)

	if dialogue.position >= #dialogue.result.dialogue then
		dialogue.finished = true
		sbq.dismissAfterTimer(dialogue.result.dismissTime)
	end

	return path, dialogueTree, dialogueTreeTop
end

function sbq.setPortrait( canvasName, data, offset )
	local canvas = widget.bindCanvas( canvasName.backingWidget )
	canvas:clear()
	for k,v in ipairs(data or {}) do
		local pos = v.position or {0, 0}
		canvas:drawImage(v.image, { pos[1]+offset[1], pos[2]+offset[2]}, 4, nil, true )
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
