function sbq.getDialogueBoxData()
	local dialogueBoxData = {
		entityPortrait = config.getParameter("entityPortrait"),
		defaultPortrait = config.getParameter("defaultPortrait"),
		portraitPath = config.getParameter("portraitPath"),
		defaultName = config.getParameter("defaultName"),
	}
	dialogueBoxData.settings.ownerUuid = recruitable.ownerUuid()
	dialogueBoxData.settings.isFollowing = recruitable.isFollowing()

	return dialogueBoxData
end

local randomDialogueHandling = {
	{ "randomDialogue", "dialogue" },
	{ "randomPortrait", "portrait" },
	{ "randomEmote", "emote" },
}

function sbq.getDialogue(path, eid, settings, dialogueTree, dialogueTreeTop)
    if not dialogue.finished then return false, dialogueTree, dialogueTreeTop end
	dialogue.finished = false
	dialogue.result = {}
	if path ~= nil then
		_, dialogueTree, dialogueTreeTop = sbq.getDialogueBranch(path, settings, eid, dialogueTree, dialogueTreeTop or sbq.dialogueTree)
		if not dialogueTree then return false end
		dialogue.path = path

		if not dialogue.result.useLastRandom then
			dialogue.randomRolls = {}
		end
		if type(dialogue.result.dialogue) == "string" then
			dialogue.result.dialogue = sbq.getRedirectedDialogue(dialogue.result.dialogue, true, settings, dialogueTree, dialogueTreeTop)
			if type(dialogue.result.dialogue) == "table" and dialogue.result.dialogue.dialogue ~= nil then
				dialogue.result = sb.jsonMerge(dialogue.result, dialogue.result.dialogue)
			end
		end
		local handleRandom = true
		local startIndex = 1
		while handleRandom == true do
			handleRandom = sbq.handleRandomDialogue(settings, eid, dialogueTree, dialogueTreeTop, startIndex)
			startIndex = #dialogue.randomRolls + 1
		end
    end
	return true, dialogueTree, dialogueTreeTop
end

function sbq.processDialogueResults()
	if not dialogue.result.dialogue then
        dialogue.finished = true
		return
	end

	local playerName = world.entityName(player.id())
	local speaker = pane.sourceEntity()
	local name = sbq.data.defaultName or world.entityName(pane.sourceEntity())
	local buttonText = "..."
	local portrait = sbq.data.defaultPortrait

	local tags = { entityname = playerName, dontSpeak = "", love = "", slowlove = "", confused = "",  sleepy = "", sad = "" }
	local imagePortrait

	local dialogueTarget = sbq.maxOfKey(dialogue.result, "dialogueTarget", dialogue.position)
	local printDialogue = sbq.generateKeysmashes(sbq.maxOfKey(dialogue.result, "dialogue", dialogue.position))


    return
		sbq.maxOfKey(dialogue.result, "source", dialogue.position),
		sbq.maxOfKey(dialogue.result, "name", dialogue.position),
		sbq.maxOfKey(dialogue.result, "portrait", dialogue.position),
        sbq.maxOfKey(dialogue.result, "textSounds", dialogue.position),
        sbq.maxOfKey(dialogue.result, "buttonText", dialogue.position),
		,
end

function sbq.maxOfKey(table, key, index)
    if not table then return end
	if not table[key] then return end
	return table[key][index] or table[key][#table[key]]
end

function sbq.getRandomDialogue(path, eid, settings, dialogueTree, dialogueTreeTop, appendName)
	if path ~= nil then
		_, dialogueTree, dialogueTreeTop = sbq.getDialogueBranch(path, settings, eid, dialogueTree, dialogueTreeTop or sbq.dialogueTree)
		if not dialogueTree then return false end
		dialogue.path = path

		if not dialogue.result.useLastRandom then
			dialogue.randomRolls = {}
		end
		if type(dialogue.result.dialogue) == "string" then
			dialogue.result.dialogue = sbq.getRedirectedDialogue(dialogue.result.dialogue, true, settings, dialogueTree, dialogueTreeTop)
			if type(dialogue.result.dialogue) == "table" and dialogue.result.dialogue.dialogue ~= nil then
				dialogue.result = sb.jsonMerge(dialogue.result, dialogue.result.dialogue)
			end
		end
		local handleRandom = true
		local startIndex = 1
		while handleRandom == true do
			handleRandom = sbq.handleRandomDialogue(settings, eid, dialogueTree, dialogueTreeTop, startIndex)
			startIndex = #dialogue.randomRolls + 1
		end
	end

	local entityname

	if type(eid) == "number" then entityname = world.entityName(eid) end

	local tags = { entityname = entityname or "", dontSpeak = "", love = "", slowlove = "", confused = "",  sleepy = "", sad = "", infusedName = sb.jsonQuery(settings, (dialogue.result.location or settings.location or "default").."InfusedItem.parameters.npcArgs.npcParam.identity.name") or "" }

	if dialogue.result.dialogue and dialogue.result.dialogue[1] then
		local dialogue = sb.jsonMerge(dialogue, {})
		for i, line in ipairs(dialogue.result.dialogue) do
			sbq.timer("dialogue" .. 1, (i - 1) * (dialogue.result.delay or 1.5), function ()
				sbq.say(sbq.generateKeysmashes(line, dialogue.result.keysmashMin, dialogue.result.keysmashMax), tags,
					(dialogue.result.portrait or {})[i], (dialogue.result.emote or {})[i], appendName)
				if i >= #dialogue.result.dialogue then
					sbq.finishDialogue()
				end
			end)
		end
	end
end

function sbq.handleRandomDialogue(settings, eid, dialogueTree, dialogueTreeTop, rollno)
	for _, v in ipairs(randomDialogueHandling) do
		local randomVal = v[1]
		local resultVal = v[2]
		if not dialogue.result[resultVal] then
			local randomResult = sbq.getRandomDialogueTreeValue(settings, eid, rollno, dialogue.result[randomVal], dialogueTree, dialogueTreeTop)
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
end

function sbq.sayDialogue(string, tags, imagePortrait, emote, appendName)
	if type(string) == "string" and string ~= "" then
		if string:find("<love>") then
			status.addEphemeralEffect("love")
		end
		if string:find("<slowlove>") then
			status.addEphemeralEffect("slowlove")
		end
		if string:find("<confused>") then
			status.addEphemeralEffect("sbqConfused")
		end
		if string:find("<sleepy>") then
			status.addEphemeralEffect("sbqSleepy")
		end
		if string:find("<sad>") then
			status.addEphemeralEffect("sbqSad")
		end
		if string:find("<dontSpeak>") then return end

		string = sb.replaceTags(string, tags)
		if string == "" then return end

		if appendName then
			string = world.entityName(entity.id())..":\n"..string
		end
---@diagnostic disable-next-line: undefined-global
		local options = {sound = randomChatSound()}
		if type(imagePortrait) == "string" and config.getParameter("sayPortrait") then
			sbq.sayPortrait(string, imagePortrait, nil, options)
		else
			sbq.say(string, nil, options )
		end
		if type(emote) == "string" then
			sbq.emote(emote)
		end
	end
end


local keysmashchars = {"a","s","d","f","g","h","j","k","","l",";","\'"}
function sbq.generateKeysmashes(input, lengthMin, lengthMax)
	input = input or ""
	return input:gsub("<keysmash>", function ()
		local keysmash = ""
		for i = 1, math.random(lengthMin or 5, lengthMax or 15) do
			keysmash = keysmash..keysmashchars[math.random(#keysmashchars)]
		end
		return keysmash
	end)
end

dialogue = {
	queue = {},
	result = {},
	randomRolls = {},
	position = 1,
}
function sbq.finishDialogue()
	dialogue.finished = false
	dialogue.position = 1
	dialogue.result = {}
end

function sbq.getDialogueBranch(path, settings, eid, dialogueTree, dialogueTreeTop)
	local dialogueTreeTop = sbq.getRedirectedDialogue(dialogueTreeTop or dialogueTree, false, settings, dialogueTreeTop or dialogueTree, dialogueTreeTop or dialogueTree)
	local dialogueTree = sbq.getRedirectedDialogue(path, false, settings, dialogueTree or dialogueTreeTop, dialogueTreeTop)
	if not dialogueTree then return false end
	sbq.processDialogueStep(dialogueTree)
	local finished = false
    if dialogueTree.next and not finished then
		if dialogueTree.target then
			if dialogueTree.target == "default" then
                eid = sbq.defaultTarget
				settings = world.getStatusProperty(eid, "sbqPublicSettings")
			elseif dialogueTree.target == "source" then
                eid = sbq.entityId()
				settings = sbq.settings
            else
                eid = world.getUniqueEntityId(dialogueTree.target)
				settings = world.getStatusProperty(eid, "sbqPublicSettings")
            end

		end
		if dialogueTree.randomNext and type(dialogueTree.next) == "table" then
			local step = dialogueTree.next[math.random(#dialogueTree.next)]
			finished = sbq.doNextStep(step, settings, eid, dialogueTree, dialogueTreeTop, dialogueTree.seperateNext)
		elseif type(dialogueTree.next) == "table" then
			for _, step in ipairs(dialogueTree.next) do
				finished = sbq.doNextStep(step, settings, eid, dialogueTree, dialogueTreeTop, dialogueTree.seperateNext)
				if finished then break end
			end
		elseif type(dialogueTree.next) == "string" then
			finished = sbq.doNextStep(dialogueTree.next, settings, eid, dialogueTree, dialogueTreeTop, dialogueTree.seperateNext)
		end
	end
	if dialogueTree.addQueued then
		for k, v in pairs(dialogue.queue) do
			if type(v) == "table" then
				dialogue.result[k] = dialogue.result[k] or {}
				util.appendLists(dialogue.result[k], v)
			elseif type(v) == "string" then
				dialogue.result[k] = (dialogue.result[k] or "") .. v
			elseif type(v) == "number" then
				dialogue.result[k] = (dialogue.result[k] or 0) + v
			end
		end
		dialogue.queue = sb.jsonMerge({}, {})
	end
	return finished or dialogueTree.finished or false, dialogueTree, dialogueTreeTop
end

function sbq.doNextStep(step, settings, eid, dialogueTree, dialogueTreeTop, useStepPath)
	if not useStepPath then
		if dialogueBoxScripts[step] then
			return sbq.getDialogueBranch("."..tostring((dialogueBoxScripts[step](dialogueTree, dialogueTreeTop, settings, branch, eid))), settings, eid, dialogueTree, dialogueTreeTop)
		elseif settings[step] ~= nil then
			return sbq.getDialogueBranch("."..tostring(settings[step]), settings, eid, dialogueTree, dialogueTreeTop)
		else
			return sbq.getDialogueBranch("."..step, settings, eid, dialogueTree, dialogueTreeTop)
		end
	elseif useStepPath and dialogueTree[step] then
		local dialogueTree = sbq.getRedirectedDialogue("."..step, false, settings, dialogueTree, dialogueTreeTop)
		return sbq.doNextStep(step, settings, eid, dialogueTree, dialogueTreeTop)
	else
		return false
	end
end

function sbq.processDialogueStep(dialogueTree)
	if dialogueTree.new then
		dialogue.result = sb.jsonMerge({}, dialogueTree.new)
		dialogue.queue = sb.jsonMerge({}, {})
	end
	if dialogueTree.clear then
		for _, k in ipairs(dialogueTree.clear) do
			dialogue.result[k] = nil
		end
	end
	if dialogueTree.replace then
		dialogue.result = sb.jsonMerge(dialogue.result, dialogueTree.replace)
	end
	if dialogueTree.add then
		for k, v in pairs(dialogueTree.add) do
			if type(v) == "table" then
				dialogue.result[k] = dialogue.result[k] or {}
				util.appendLists(dialogue.result[k], v)
			elseif type(v) == "string" then
				dialogue.result[k] = (dialogue.result[k] or "") .. v
			elseif type(v) == "number" then
				dialogue.result[k] = (dialogue.result[k] or 0) + v
			end
		end
	end
	if dialogueTree.newQueue then
		dialogue.queue = sb.jsonMerge({}, dialogueTree.newQueue)
	end
	if dialogueTree.clearQueue then
		for _, k in ipairs(dialogueTree.clearQueue) do
			dialogue.queue[k] = nil
		end
	end
	if dialogueTree.replaceQueue then
		dialogue.queue = sb.jsonMerge(dialogue.queue, dialogueTree.replaceQueue)
	end
	if dialogueTree.addQueue then
		for k, v in pairs(dialogueTree.addQueue) do
			if type(v) == "table" then
				dialogue.queue[k] = dialogue.queue[k] or {}
				util.appendLists(dialogue.queue[k], v)
			elseif type(v) == "string" then
				dialogue.queue[k] = (dialogue.queue[k] or "") .. v
			elseif type(v) == "number" then
				dialogue.queue[k] = (dialogue.queue[k] or 0) + v
			end
		end
	end
end

function sbq.getRedirectedDialogue(path, returnStrings, settings, dialogueTree, dialogueTreeTop)
	local returnVal = path
	while type(returnVal) == "string" do
		firstChar = returnVal:sub(1,1)
		if firstChar == "/" then
			returnVal = root.assetJson(returnVal) or {}
		elseif firstChar == ":" then
			returnVal = root.assetJson(dialogue.result.useFile or dialogueTreeTop.dialogueFile..returnVal) or {}
		elseif firstChar == "." then
			local trim = returnVal:sub(2, -1)
			returnVal = sb.jsonQuery(dialogueTree or {}, trim) or sb.jsonQuery(dialogueTreeTop or {}, trim)
		else break end
	end
	if (type(returnVal) == "string" and returnStrings) or type(returnVal) == "table" then
		return returnVal
	end
end

function sbq.getRandomDialogueTreeValue(settings, eid, rollNo, randomTable, dialogueTree, dialogueTreeTop)
	local rollNo = rollNo or 1
	local randomTable = sbq.getRedirectedDialogue(randomTable, true, settings, dialogueTree, dialogueTreeTop)
	if type(randomTable) == "table" then
		if not sbq.checkSettings(randomTable.check, settings) then return end
		if randomTable.percentage then
			local percentage = 0.5
			if randomTable.percentage == "selfHealth" then
				local health = world.entityHealth(entity.id())
				percentage = health[1] / health[2]
			elseif randomTable.percentage == "targetHealth" then
				local health = world.entityHealth(eid)
				percentage = health[1] / health[2]
			else
				percentage = settings[randomTable.percentage] or 0.5
			end
			if percentage >= 1 and randomTable.full then
				return sbq.getRandomDialogueTreeValue(settings, eid, rollNo + 1, randomTable.full, dialogueTree, dialogueTreeTop)
			elseif percentage <= 0 and randomTable.empty then
				return sbq.getRandomDialogueTreeValue(settings, eid, rollNo + 1, randomTable.empty, dialogueTree, dialogueTreeTop)
			end
			return sbq.getRandomDialogueTreeValue(settings, eid, rollNo+1, randomTable.pools[math.min((math.floor((#randomTable.pools * percentage) + 0.5) + 1), #randomTable.pools)], dialogueTree, dialogueTreeTop)
		end
		local location = dialogue.result.location or settings.location
		if randomTable.infusedSlot and location then
			local uuid = sb.jsonQuery(settings, location.."InfusedItem.parameters.npcArgs.npcParam.scriptConfig.uniqueId")
			if uuid then
				return sbq.getRandomDialogueTreeValue(settings, eid, rollNo+1, randomTable[uuid] or randomTable.default, dialogueTree, dialogueTreeTop)
			end
		end
		if 	randomTable.dialogue or randomTable.portrait or randomTable.emote or randomTable.name or randomTable.buttonText or
			randomTable.speaker or randomTable.randomDialogue or randomTable.randomPortrait or randomTable.randomButtonText or
			randomTable.randomEmote or randomTable.randomName
			then
			return randomTable
		end
		local selection = randomTable.add or randomTable
		if selection[1] ~= nil then
			local selectionRolls = {}
			for i = 1, #selection do
				selectionRolls[i] = i
			end
			while selectionRolls[1] ~= nil do
				dialogue.randomRolls[rollNo] = dialogue.randomRolls[rollNo] or
				selectionRolls[math.random(#selectionRolls)]
				---@diagnostic disable-next-line: cast-local-type
				randomTable = sbq.getRandomDialogueTreeValue(settings, eid, rollNo + 1,
					selection[dialogue.randomRolls[rollNo]], dialogueTree, dialogueTreeTop)
				if randomTable then
					break
				else
					table.remove(selectionRolls, dialogue.randomRolls[rollNo])
					dialogue.randomRolls[rollNo] = nil
				end
			end
		end
	end
	return randomTable
end

function dialogueBoxScripts.isOwner(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	local result = false
	if eid then
		local uuid = world.entityUniqueId(eid)
		result = uuid ~= nil and uuid == settings.ownerUuid
	end
	return tostring(result)
end

function dialogueBoxScripts.percentage(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	local best = "default"
	local bestScore = 0
    for key, value in pairs(dialogueTree.percentage or {}) do
		local checkValue
		if world.entityIsResource(eid, key) then
            checkValue = world.entityResourcePercentage(eid, key)
        elseif type(settings[key]) == "number" then
			checkValue = settings[key]
		end

		if type(checkValue) == "number" then
			local score
			if value < 0 then
				if checkValue < math.abs(value) then
					score = checkValue - value
				end
			else
				if checkValue > math.abs(value) then
					score = value + checkValue
				end
			end
			if type(score) == "number" then
				if score > bestScore then
					bestScore = score
					best = key
				end
			end
		end
	end
	return best
end
