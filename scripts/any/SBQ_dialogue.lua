
dialogueProcessor = {}
dialogue = {
	finished = true,
	position = 1,
	queue = {},
	randomRolls = {},
	result = {},
	prev = {},
	default = {},
	path = "",
	redirect = "",
}
function dialogueProcessor.getDialogue(path, eid, settings, dialogueTree, dialogueTreeTop)
	dialogue.finished = false
	dialogue.position = 1
	if path ~= nil then
		dialogue.path = path
		_, dialogueTree, dialogueTreeTop = dialogueProcessor.getDialogueBranch(path, settings, eid, dialogueTree or dialogue.prev, dialogueTreeTop or dialogue.prevTop)
		if (not dialogueTree) or (not dialogueTreeTop) then dialogue.finished = true return false end
		if not dialogue.result.useLastRandom then
			dialogue.randomRolls = {}
		end
		dialogueProcessor.getDialogueBranch(".defaultResults", settings, eid, dialogueTree, dialogueTreeTop)
		local startIndex = 1
		while dialogueProcessor.handleRandomDialogue(settings, eid, dialogueTree, dialogueTreeTop, startIndex) do
			startIndex = #dialogue.randomRolls + 1
		end
	end
	dialogue.result = sb.jsonMerge(dialogueTreeTop.defaultResults or {}, dialogue.result)
	for _, key in ipairs(dialogueProcessor.resultKeys) do
		if dialogue.result[key] and type(dialogue.result[key]) ~= "table" then
			dialogue.result[key] = {dialogue.result[key]}
		end
	end
	dialogue.prev = dialogueTree or {}
	dialogue.prevTop = dialogueTreeTop or {}
	return true
end

dialogueProcessor.resultKeys = {
	"source",
	"target",
	"dialogue",
	"textSound",
	"textSpeed",
	"name",
	"imagePortrait",
	"imagePath",
	"entityPortrait",
	"emote",
	"buttonText",
	"tags",
	"dismissTime"
}

function dialogueProcessor.processDialogueResults(i)
	local results = {}
	for _, k in ipairs(dialogueProcessor.resultKeys) do
		results[k] = dialogueProcessor.maxOfKey(dialogue.result, k, dialogue.position)
	end
	results.dialogue = dialogueProcessor.getRedirectedDialogue(results.dialogue, true, sbq.settings, dialogue.prev, dialogue.prevTop)

	results.source = results.source or sbq.entityId()
	if type(results.source) == "string" then
		results.source = world.getUniqueEntityId(results.source)
	end
	results.name = results.name or sbq.entityName(results.source)

	results.target = results.target or sbq.target
	if type(results.target) == "string" then
		results.target = world.getUniqueEntityId(results.target)
	end

	results.portrait = results.portrait or sbq.defaultPortrait
	results.dialogue = dialogueProcessor.generateKeysmashes(results.dialogue)
	results.buttonText = results.buttonText or "[...]"
	local targetName = results.target and (sbq.entityName(results.target) .. "^reset;")
	results.tags = sb.jsonMerge(
		{
			dialoguePath = dialogue.path or "",
			dialogueRedirect = dialogue.redirect or "",
			sourceName = results.name .. "^reset;",
			targetName = targetName,
			entityName = targetName,
			entityname = targetName,
			dontSpeak = "", love = "", slowlove = "", confused = "", sleepy = "", sad = "",
		},
		results.tags or {},
		sbq.replaceConfigTags(dialogueProcessor.getPronouns(results.source), { t = "source" }),
		sbq.replaceConfigTags(dialogueProcessor.getPronouns(results.target), { t = "target" })
	)
	return results
end

function dialogueProcessor.getPronouns(entityId)
	if not entityId then return {} end
	local pronouns = sbq.getPublicProperty(entityId, "sbqPronouns") or {}
	for _, fallback in ipairs(pronouns.fallback or {world.entityGender(entityId) or "object", "neutral"}) do
		pronouns = sb.jsonMerge(sbq.pronouns[fallback], pronouns)
	end
	return pronouns
end


function dialogueProcessor.maxOfKey(table, key, index)
	if not table then return end
	if table[key] == nil then return end
	if type(table[key]) ~= "table" then return table[key] end
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
			else
				dialogue.result[key] = randomResult
			end
		end
		if type(dialogue.result[key]) == "string" then
			dialogue.result[key] = dialogueProcessor.getRedirectedDialogue(dialogue.result[key], true, settings, dialogueTree, dialogueTreeTop)
		end
	end
end

local keysmashchars = {"a","s","d","f","g","h","j","k","","l",";","\'"}
function dialogueProcessor.generateKeysmashes(input, lengthMin, lengthMax)
	if not input then return end
	return input:gsub("<keysmash>", function ()
		local keysmash = ""
		for i = 1, math.random(lengthMin or 5, lengthMax or 15) do
			keysmash = keysmash..keysmashchars[math.random(#keysmashchars)]
		end
		return keysmash
	end)
end

function dialogueProcessor.getDialogueBranch(path, settings, eid, dialogueTree, dialogueTreeTop)
	dialogueTreeTop = dialogueProcessor.getRedirectedDialogue(dialogueTreeTop or dialogueTree, false, settings, dialogueTreeTop or dialogueTree, dialogueTreeTop or dialogueTree)
	dialogueTree = dialogueProcessor.getRedirectedDialogue(path, false, settings, dialogueTree or dialogueTreeTop, dialogueTreeTop)
	if not dialogueTree then return false end
	dialogueProcessor.processDialogueStep(dialogueTree)
	local finished = false
	if dialogueTree.next and not finished then
		if dialogueTree.settings then
			if dialogueTree.settings == "target" then
				eid = sbq.target
				if eid and world.entityExists(eid) then
					settings = sbq.getPublicProperty(eid, "sbqPublicSettings")
				end
			elseif dialogueTree.settings == "self" then
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
		dialogueTree = dialogueProcessor.getRedirectedDialogue("."..step, false, settings, dialogueTree, dialogueTreeTop)
		return dialogueProcessor.doNextStep(step, settings, eid, dialogueTree, dialogueTreeTop)
	else
		return false
	end
end

function dialogueProcessor.processDialogueStep(dialogueTree)
	if dialogueTree.new then
		dialogue.result = sb.jsonMerge(dialogueTree.new, {})
		dialogue.queue = {}
	end
	if dialogueTree.fill then
		dialogue.result = sb.jsonMerge(dialogueTree.fill, dialogue.result)
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
	if dialogueTree.queueNew then
		dialogue.queue = sb.jsonMerge(dialogueTree.queueNew, {})
	end
	if dialogueTree.queueClear then
		for _, k in ipairs(dialogueTree.queueClear) do
			dialogue.queue[k] = nil
		end
	end
	if dialogueTree.queueReplace then
		dialogue.queue = sb.jsonMerge(dialogue.queue, dialogueTree.queueReplace)
	end
	if dialogueTree.queueAdd then
		for k, v in pairs(dialogueTree.queueAdd) do
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
			local val = root.assetJson(dialogue.result.useFile or dialogueTreeTop.dialogueFile)[returnVal:sub(2,-1)]
			if not val then
				returnVal = sbq.getString(returnVal)
				break
			else
				returnVal = val
			end
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

function dialogueProcessor.sendPlayerDialogueBox()
	if world.entityType(sbq.target) == "player" then
		local dialogueBoxData = sb.jsonMerge(sbq.getSettingsPageData(), {
			dialogueTree = sbq.dialogueTree,
			dialogueTreeStart = dialogue.path,
			noActions = true,
			dialogue = dialogue
		})
		world.sendEntityMessage(sbq.target, "sbqOpenMetagui", "starbecue:dialogueBox", entity.id(), { sbq = dialogueBoxData })
		return {"ScriptPane", { data = {sbq = dialogueBoxData}, gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = "starbecue:dialogueBox" }, entity.id()}
	end
end

function dialogueProcessor.speakDialogue(callback)
	sbq.timerList.speakDialogue = nil
	local results = dialogueProcessor.processDialogueResults()
	if (not results.dialogue) or dialogue.finished then
		dialogue.finished = true
		if callback then
			callback()
		end
		return
	end
	if self.board then
		self.interacted = true
		self.board:setEntity("interactionSource", sbq.target)
	end
	local lifetime = (results.dismissTime or 0) + (((results.textSpeed or 1) * sbq.config.textSpeedMul) * string.len(results.dialogue))
	if status.statPositive("sbqIsPrey") and sbq.loungingIn() then
		world.sendEntityMessage(sbq.loungingIn(), "scriptPaneMessage", "sbqPredHudPreyDialogue", entity.id(),
			sb.replaceTags(results.dialogue, results.tags), results.textSound, results.textSpeed, results.textVolume or 1, lifetime)
	else
		sbq.sayDialogue(results.dialogue, results.tags, results.speechPortrait, results.emote)
	end
	dialogue.position = dialogue.position + 1
	if dialogue.position > #(dialogue.result.dialogue or {}) then
		dialogue.finished = true
	end
	sbq.timer(nil, lifetime, dialogueProcessor.speakDialogue, callback)
end
function dialogueProcessor.predictTime()
	local time = 0
	for i, v in ipairs(dialogue.result.dialogue or {}) do
		local dismissTime = dialogueProcessor.maxOfKey(dialogue.result, "dismissTime", i)
		local textSpeed = dialogueProcessor.maxOfKey(dialogue.result, "textSpeed", i)
		time = time + (dismissTime or 0) + (string.len(v) * ((textSpeed or 1) * sbq.config.textSpeedMul))
	end
	return time
end


dialogueStepScripts = {}
dialogueOptionScripts = {}
