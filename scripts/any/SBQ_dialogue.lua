
dialogueProcessor = {}
dialogue = {
	position = 1,
	result = {},
	prev = {}
}
function dialogueProcessor.getDialogue(path, eid, settings, dialogueTree, dialogueTreeTop)
	dialogue.finished = false
	dialogue.position = 1
	dialogue.result = {}
	if path ~= nil then
		_, dialogueTree, dialogueTreeTop = dialogueProcessor.getDialogueBranch(path, settings, eid, dialogueTree, dialogueTreeTop or sbq.dialogueTree)
		if not dialogueTree then return false end
		dialogue.path = path

		if not dialogue.result.useLastRandom then
			dialogue.randomRolls = {}
		end
		if type(dialogue.result.dialogue) == "string" then
			dialogue.result.dialogue = dialogueProcessor.getRedirectedDialogue(dialogue.result.dialogue, true, settings, dialogueTree, dialogueTreeTop)
			if type(dialogue.result.dialogue) == "table" and dialogue.result.dialogue.dialogue ~= nil then
				dialogue.result = sb.jsonMerge(dialogue.result, dialogue.result.dialogue)
			end
		end
		local handleRandom = true
		local startIndex = 1
		while handleRandom == true do
			handleRandom = dialogueProcessor.handleRandomDialogue(settings, eid, dialogueTree, dialogueTreeTop, startIndex)
			startIndex = #dialogue.randomRolls + 1
		end
	end
	dialogue.prev = dialogueTree
	dialogue.prevTop = dialogueTreeTop
	return true
end

dialogueProcessor.resultKeys = {
	"source",
	"target",
	"dialogue",
	"textSound",
	"textSpeed",
	"name",
	"portrait",
	"emote",
	"buttonText",
	"tags"
}

function dialogueProcessor.processDialogueResults()
	local results = {}
	for _, k in ipairs(dialogueProcessor.resultKeys) do
		results[k] = dialogueProcessor.maxOfKey(dialogue.result, k, dialogue.position)
	end

	results.source = results.source or pane.sourceEntity()
	if type(results.source) == "string" then
		results.source = world.getUniqueEntityId(results.source)
	end
	results.name = results.name or sbq.entityName(results.source)

	results.target = results.target or player.id()
	if type(results.target) == "string" then
		results.target = world.getUniqueEntityId(results.target)
	end

	results.portrait = results.portrait or sbq.defaultPortrait
	results.dialogue = dialogueProcessor.generateKeysmashes(results.dialogue)
	results.buttonText = results.buttonText or "[...]"
	results.tags = sb.jsonMerge(
		{ sourceName = results.name, targetName = sbq.entityName(results.target), dontSpeak = "", love = "", slowlove = "", confused = "", sleepy = "", sad = "" },
		results.tags or {},
		sbq.replaceConfigTags(dialogueProcessor.getPronouns(results.source), { t = "source" }),
		sbq.replaceConfigTags(dialogueProcessor.getPronouns(results.target), { t = "target" })
	)
	return results
end

function dialogueProcessor.getPronouns(entityId)
	local pronouns = sbq.getPublicProperty(entityId, "sbqPronouns") or {}
	for _, fallback in ipairs(pronouns.fallback or {world.entityGender(entityId) or "object", "neutral"}) do
		pronouns = sb.jsonMerge(sbq.pronouns[fallback], pronouns)
	end
	return pronouns
end


function dialogueProcessor.maxOfKey(table, key, index)
	if not table then return end
	if not table[key] then return end
	return table[key][index] or table[key][#table[key]]
end


function dialogueProcessor.handleRandomDialogue(settings, eid, dialogueTree, dialogueTreeTop, rollno)
	for _, key in ipairs(dialogueProcessor.resultKeys) do
		local randomKey = key.."Random"
		if dialogue.result[randomKey] and not dialogue.result[key] then
			local randomResult = dialogueProcessor.getRandomDialogueTreeValue(settings, eid, rollno, dialogue.result[randomKey], dialogueTree, dialogueTreeTop)
			if type(randomResult) == "table" then
				dialogue.result = sb.jsonMerge(dialogue.result, randomResult)
				for _, k in ipairs(dialogueProcessor.resultKeys) do
					if randomResult[k.."Random"] then return true end
				end
			elseif type(randomResult) == "string" then
				dialogue.result[key] = {randomResult}
			end
		end
	end
end

local keysmashchars = {"a","s","d","f","g","h","j","k","","l",";","\'"}
function dialogueProcessor.generateKeysmashes(input, lengthMin, lengthMax)
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
function dialogueProcessor.finishDialogue()
	dialogue.finished = false
	dialogue.position = 1
	dialogue.result = {}
end

function dialogueProcessor.getDialogueBranch(path, settings, eid, dialogueTree, dialogueTreeTop)
	local dialogueTreeTop = dialogueProcessor.getRedirectedDialogue(dialogueTreeTop or dialogueTree, false, settings, dialogueTreeTop or dialogueTree, dialogueTreeTop or dialogueTree)
	local dialogueTree = dialogueProcessor.getRedirectedDialogue(path, false, settings, dialogueTree or dialogueTreeTop, dialogueTreeTop)
	if not dialogueTree then return false end
	dialogueProcessor.processDialogueStep(dialogueTree)
	local finished = false
	if dialogueTree.next and not finished then
		if dialogueTree.settings then
			if dialogueTree.settings == "target" then
				eid = sbq.target()
				if eid and world.entityExists(eid) then
					settings = sbq.getPublicProperty(eid, "sbqPublicSettings")
				end
			elseif dialogueTree.settings == "source" then
				eid = sbq.entityId()
				settings = sbq.settings
			else
				eid = world.getUniqueEntityId(dialogueTree.settings)
				if eid and world.entityExists(eid) then
					settings = sbq.getPublicProperty(eid, "sbqPublicSettings")
				end
			end
		end
		if dialogueTree.randomNext and type(dialogueTree.next) == "table" then
			local step = dialogueTree.next[math.random(#dialogueTree.next)]
			finished = dialogueProcessor.doNextStep(step, settings, eid, dialogueTree, dialogueTreeTop, dialogueTree.seperateNext)
		elseif type(dialogueTree.next) == "table" then
			for _, step in ipairs(dialogueTree.next) do
				finished = dialogueProcessor.doNextStep(step, settings, eid, dialogueTree, dialogueTreeTop, dialogueTree.seperateNext)
				if finished then break end
			end
		elseif type(dialogueTree.next) == "string" then
			finished = dialogueProcessor.doNextStep(dialogueTree.next, settings, eid, dialogueTree, dialogueTreeTop, dialogueTree.seperateNext)
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

function dialogueProcessor.doNextStep(step, settings, eid, dialogueTree, dialogueTreeTop, useStepPath)
	if not useStepPath then
		if dialogueStepScripts[step] then
			return dialogueProcessor.getDialogueBranch("."..tostring((dialogueStepScripts[step](dialogueTree, dialogueTreeTop, settings, step, eid))), settings, eid, dialogueTree, dialogueTreeTop)
		elseif settings[step] ~= nil then
			return dialogueProcessor.getDialogueBranch("."..tostring(settings[step]), settings, eid, dialogueTree, dialogueTreeTop)
		else
			return dialogueProcessor.getDialogueBranch("."..step, settings, eid, dialogueTree, dialogueTreeTop)
		end
	elseif useStepPath and dialogueTree[step] then
		local dialogueTree = dialogueProcessor.getRedirectedDialogue("."..step, false, settings, dialogueTree, dialogueTreeTop)
		return dialogueProcessor.doNextStep(step, settings, eid, dialogueTree, dialogueTreeTop)
	else
		return false
	end
end

function dialogueProcessor.processDialogueStep(dialogueTree)
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

function dialogueProcessor.getRedirectedDialogue(path, returnStrings, settings, dialogueTree, dialogueTreeTop)
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

function dialogueProcessor.getRandomDialogueTreeValue(settings, eid, rollNo, randomTable, dialogueTree, dialogueTreeTop)
	local rollNo = rollNo or 1
	local randomTable = dialogueProcessor.getRedirectedDialogue(randomTable, true, settings, dialogueTree, dialogueTreeTop)
	if type(randomTable) == "table" then
		if not sbq.tableMatches(randomTable.check, settings) then return end
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
				return dialogueProcessor.getRandomDialogueTreeValue(settings, eid, rollNo + 1, randomTable.full, dialogueTree, dialogueTreeTop)
			elseif percentage <= 0 and randomTable.empty then
				return dialogueProcessor.getRandomDialogueTreeValue(settings, eid, rollNo + 1, randomTable.empty, dialogueTree, dialogueTreeTop)
			end
			return dialogueProcessor.getRandomDialogueTreeValue(settings, eid, rollNo+1, randomTable.pools[math.min((math.floor((#randomTable.pools * percentage) + 0.5) + 1), #randomTable.pools)], dialogueTree, dialogueTreeTop)
		end
		local location = dialogue.result.location or settings.location
		if randomTable.infusedSlot and location then
			local uuid = sb.jsonQuery(settings, location.."InfusedItem.parameters.npcArgs.npcParam.scriptConfig.uniqueId")
			if uuid then
				return dialogueProcessor.getRandomDialogueTreeValue(settings, eid, rollNo+1, randomTable[uuid] or randomTable.default, dialogueTree, dialogueTreeTop)
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
				randomTable = dialogueProcessor.getRandomDialogueTreeValue(settings, eid, rollNo + 1,
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

dialogueStepScripts = {}
dialogueOptionScripts = {}

function dialogueStepScripts.isOwner(dialogueTree, dialogueTreeTop, settings, step, eid, ...)
	local result = false
	if eid then
		local uuid = world.entityUniqueId(eid)
		result = uuid ~= nil and uuid == settings.ownerUuid
	end
	return tostring(result)
end

function dialogueStepScripts.percentage(dialogueTree, dialogueTreeTop, settings, step, eid, ...)
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
