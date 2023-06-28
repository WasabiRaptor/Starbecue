---@diagnostic disable: undefined-global

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

dialogue = {
	queue = {},
	result = {},
	randomRolls = {},
	position = 1,
}
function sbq.finishDialogue()
	dialogue.finished = false
	dialogue.position = 1
end

function sbq.getDialogueBranch(path, settings, eid, dialogueTree, dialogueTreeTop)
	local dialogueTreeTop = sbq.getRedirectedDialogue(dialogueTreeTop or dialogueTree, false, settings, dialogueTreeTop or dialogueTree, dialogueTreeTop or dialogueTree)
	local dialogueTree = sbq.getRedirectedDialogue(path, false, settings, dialogueTree or dialogueTreeTop, dialogueTreeTop)
	if not dialogueTree then return false end
	sbq.processDialogueStep(dialogueTree)
	local finished = false
	if dialogueTree.next and not finished then
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
	local tags = {}
	for k, v in pairs(settings or {}) do
		if (type(v) ~= "table") then
			tags[tostring(k)] = tostring(v)
		end
	end
	while type(returnVal) == "string" do
		returnVal = sb.replaceTags(returnVal, tags)
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
	local badrolls = {}
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
			local badroll = true
			dialogue.randomRolls[rollNo] = dialogue.randomRolls[rollNo] or math.random(#selection)
			while badroll do
				while badrolls[tostring(dialogue.randomRolls[rollNo])] do
					dialogue.randomRolls[rollNo] = math.random(#selection)
				end
				---@diagnostic disable-next-line: cast-local-type
				randomTable = sbq.getRandomDialogueTreeValue(settings, eid, rollNo+1, selection[dialogue.randomRolls[rollNo]], dialogueTree, dialogueTreeTop)
				if randomTable then
					badroll = false
				else
					badrolls[tostring(dialogue.randomRolls[rollNo])] = true
					badrolls.count = (badrolls.count or 0) + 1
					if badrolls.count >= #selection then return end
				end
			end
		end
	end
	return randomTable
end

require("/scripts/SBQ_check_settings.lua")


function dialogueBoxScripts.locationEffectSlot(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	if settings.digesting or (settings.hostile and settings.overrideSoftDigestForHostiles and (settings[(dialogueTree.location or dialogue.result.location or settings.location).."EffectSlot"] == "softDigest")) then
		return "digest"
	elseif settings.healing then
		return "heal"
	end
	return settings[(dialogueTree.location or dialogue.result.location or settings.location).."EffectSlot"]
end
function dialogueBoxScripts.locationEffect(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	if settings.digesting or (settings.hostile and settings.overrideSoftDigestForHostiles and (settings[(dialogueTree.location or dialogue.result.location or settings.location).."EffectSlot"] == "softDigest")) then
		return settings.predDigestEffect or ((sbq.sbqData.locations[(dialogueTree.location or dialogue.result.location or settings.location)] or {}).digest or {}).effect or "sbqDigest"
	elseif settings.healing then
		return settings.predDigestEffect or ((sbq.sbqData.locations[(dialogueTree.location or dialogue.result.location or settings.location)] or {}).heal or {}).effect or "sbqHeal"
	end
	return settings[(dialogueTree.location or dialogue.result.location or settings.location).."Effect"]
end

function dialogueBoxScripts.locationCompression(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	return settings[(dialogueTree.location or dialogue.result.location or settings.location).."Compression"] or false
end
function dialogueBoxScripts.locationEnergyDrain(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	return settings[(dialogueTree.location or dialogue.result.location or settings.location).."EnergyDrain"] or false
end

function dialogueBoxScripts.digestImmunity(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	local effectSlot = (settings[(dialogueTree.location or dialogue.result.location or settings.location) .. "EffectSlot"])
	if effectSlot == "softDigest" and settings.hostile and settings.overrideSoftDigestForHostiles then
		effectSlot = "digest"
	end
	return not (settings.digestAllow and (effectSlot == "digest")) or (settings.softDigestAllow and (effectSlot == "softDigest"))
end

function dialogueBoxScripts.cumDigestImmunity(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	local effectSlot = (settings[(dialogueTree.location or dialogue.result.location or settings.location) .. "EffectSlot"])
	if effectSlot == "softDigest" and settings.hostile and settings.overrideSoftDigestForHostiles then
		effectSlot = "digest"
	end
	return not (settings.cumDigestAllow and (effectSlot == "digest")) or (settings.cumSoftDigestAllow and (effectSlot == "softDigest"))
end

function dialogueBoxScripts.femcumDigestImmunity(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	local effectSlot = (settings[(dialogueTree.location or dialogue.result.location or settings.location) .. "EffectSlot"])
	if effectSlot == "softDigest" and settings.hostile and settings.overrideSoftDigestForHostiles then
		effectSlot = "digest"
	end
	return not (settings.femcumDigestAllow and (effectSlot == "digest")) or (settings.femcumSoftDigestAllow and (effectSlot == "softDigest"))
end

function dialogueBoxScripts.milkDigestImmunity(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	local effectSlot = (settings[(dialogueTree.location or dialogue.result.location or settings.location) .. "EffectSlot"])
	if effectSlot == "softDigest" and settings.hostile and settings.overrideSoftDigestForHostiles then
		effectSlot = "digest"
	end
	return not (settings.milkDigestAllow and (effectSlot == "digest")) or (settings.milkSoftDigestAllow and (effectSlot == "softDigest"))
end

function dialogueBoxScripts.infuseLayered(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	return sb.jsonQuery(settings, (dialogueTree.location or dialogue.result.location or settings.location).."InfusedItem.parameters.npcArgs.npcParam.scriptConfig.uniqueId")
end

function dialogueBoxScripts.transforming(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	return tostring(type(settings.transforming) == "number")
end
function dialogueBoxScripts.eggify(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	return tostring(type(settings.Eggifying) == "number")
end


function dialogueBoxScripts.isOwner(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	local result = false
	if eid then
		local uuid = world.entityUniqueId(eid)
		result = uuid ~= nil and uuid == settings.ownerUuid
	end
	return tostring(result)
end

function dialogueBoxScripts.infusedCharacter(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	local infusedChar = sb.jsonQuery(settings, (dialogueTree.location or dialogue.result.location or settings.location).."InfusedItem.parameters.npcArgs")
	if (sbq.sbqData[(dialogueTree.location or dialogue.result.location or settings.location)] or {}).infusion
	and settings[(((sbq.sbqData[(dialogueTree.location or dialogue.result.location or settings.location)] or {}).infusionSetting or "infusion").."Pred")]
	and infusedChar
	then
		local uniqueID = sb.jsonQuery(infusedChar, "npcParam.scriptConfig.uniqueId")
		if dialogueTree[uniqueID] or (dialogueTree.infusedCharacter or {})[uniqueID] then
			return uniqueID
		else
			return "defaultInfused"
		end
	end
	return "default"
end

function dialogueBoxScripts.percentage(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	local best = "default"
	local bestScore = 0
	for key, value in pairs(dialogueTree.percentage) do
		if type(settings[key]) == "number" then
			local score
			if value < 0 then
				if settings[key] < math.abs(value) then
					score = settings[key] - value
				end
			else
				if settings[key] > math.abs(value) then
					score = value + settings[key]
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
