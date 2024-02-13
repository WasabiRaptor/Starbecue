function sbq.getDialogueBoxData()
	local overrideData = humanoid.getIdentity()
	local dialogueBoxData = {
		speciesConfig = sbq.speciesConfig,
		dialogueBoxScripts = sbq.dialogueBoxScripts,
		settings = sb.jsonMerge(storage.settings, status.statusProperty("sbqPreyEnabled") or {} ),
		dialogueTree = sbq.dialogueTree,
		icons = config.getParameter("voreIcons"),
		iconDirectives = (config.getParameter("iconDirectives") or "")..(overrideData.directives or ""),
		entityPortrait = config.getParameter("entityPortrait"),
		defaultPortrait = config.getParameter("defaultPortrait"),
		portraitPath = config.getParameter("portraitPath"),
		defaultName = config.getParameter("defaultName"),
		occupantHolder = sbq.occupantHolder,
		scale = status.statusProperty("sbqScale"),
		occupant = sbq.occupant
	}
	dialogueBoxData.settings.race = npc.species()
	dialogueBoxData.settings.ownerUuid = recruitable.ownerUuid()
	dialogueBoxData.settings.isFollowing = recruitable.isFollowing()
	dialogueBoxData.settings.horny = status.resourcePercentage("sbqLust")
	dialogueBoxData.settings.food = status.resourcePercentage("food")
	dialogueBoxData.settings.energy = status.resourcePercentage("energy")

	return dialogueBoxData
end

local randomDialogueHandling = {
	{ "randomDialogue", "dialogue" },
	{ "randomPortrait", "portrait" },
	{ "randomEmote", "emote" },
}

function sbq.getRandomDialogue(path, eid, settings, dialogueTree, appendName, dialogueTreeTop)
	settings.race = npc.species()
	local dialogueTree, dialogueTreeTop = dialogueTree, dialogueTreeTop
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

function sbq.say(string, tags, imagePortrait, emote, appendName)
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
			npc.sayPortrait(string, imagePortrait, nil, options)
		else
			npc.say(string, nil, options )
		end
		if type(emote) == "string" then
			npc.emote(emote)
		end
	end
end
