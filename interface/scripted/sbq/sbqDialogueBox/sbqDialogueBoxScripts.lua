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

function sbq.getDialogueBranch(path, settings, eid, dialogueTree, dialogueTreeTop)
	local dialogueTreeTop = dialogueTreeTop or dialogueTree
	local dialogueTree = sbq.getRedirectedDialogue(path, false, dialogueTree, dialogueTree or dialogueTreeTop)
	if not dialogueTree then return false end
	local finished = sbq.processDialogueStep(dialogueTree)
	if dialogueTree.next and not finished then
		if dialogueTree.randomNext then
			local step = dialogueTree.next[math.random(#dialogueTree.next)]
			finished = sbq.doNextStep(step, settings, eid, dialogueTree, dialogueTreeTop)
		else
			for _, step in ipairs(dialogueTree.next) do
				finished = sbq.doNextStep(step, settings, eid, dialogueTree, dialogueTreeTop)
			end
		end
	end
	return finished or false, dialogueTree, dialogueTreeTop
end

function sbq.doNextStep(step, settings, eid, dialogueTree, dialogueTreeTop)
	if dialogueTree[step] then
		if dialogueBoxScripts[step] then
			return sbq.getDialogueBranch("."..step.."."..(dialogueBoxScripts[step](dialogueTree, settings, branch, eid) or "default"), settings, dialogueTree, dialogueTreeTop)
		elseif settings[step] then
			return sbq.getDialogueBranch("."..step.."."..(settings[step] or "default"), settings, dialogueTree, dialogueTreeTop)
		else
			return sbq.getDialogueBranch("."..step, settings, dialogueTree, dialogueTreeTop)
		end
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
	if not dialogueTree.next or dialogueTree.addQueued then
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
	if dialogueTree.finished then return true end
end

function sbq.getRedirectedDialogue(path, returnStrings, dialogueTree, dialogueTreeTop )
	if type(path) == "string" then
		if path[1] == "/" then
			return root.assetJson(path) or {}
		elseif path[1] == ":" then
			return root.assetJson(dialogue.result.useFile or dialogueTreeTop.dialogueFile..path) or {}
		elseif path[1] == "." then
			return sb.jsonQuery(dialogueTree, path:sub(2, -1)) or sb.jsonQuery(dialogueTreeTop, path:sub(2, -1))
		elseif returnStrings then
			return path
		end
	elseif type(path) == "table" then
		return path
	end
end

function sbq.getRandomDialogueTreeValue(settings, eid, rollNo, randomTable, dialogueTree, dialogueTreeTop)
	local rollNo = rollNo or 1
	local randomTable = sbq.getRedirectedDialogue(randomTable, true, dialogueTree, dialogueTreeTop)
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
			return sbq.getRandomDialogueTreeValue(settings, eid, rollNo+1, randomTable.pools[math.min((math.floor((#randomTable.pools * percentage) + 0.5) + 1), #randomTable.pools)], dialogueTree, dialogueTreeTop)
		end
		if randomTable.dialogue or randomTable.portrait or randomTable.emote or randomTable.name or randomTable.buttonText or randomTable.speaker then
			return randomTable
		end
		local selection = randomTable.add or randomTable
		if selection[1] ~= nil then
			local badroll = true
			randomRolls[rollNo] = randomRolls[rollNo] or math.random(#selection)
			while badroll do
				while badrolls[tostring(randomRolls[rollNo])] do
					randomRolls[rollNo] = math.random(#selection)
				end
				randomTable = sbq.getRandomDialogueTreeValue(settings, eid, rollNo+1, selection[randomRolls[rollNo]], dialogueTree, dialogueTreeTop)
				if randomTable then
					badroll = false
				else
					badrolls[tostring(randomRolls[rollNo])] = true
					badrolls.count = (badrolls.count or 0) + 1
					if badrolls.count >= #selection then return end
				end
			end
		end
	end
	return randomTable
end

function sbq.checkSettings(checkSettings, settings)
	for setting, value in pairs(checkSettings or {}) do
		if (type(settings[setting]) == "table") and settings[setting].name ~= nil then
			if not value then return false
			elseif type(value) == "table" then
				if not sbq.checkTable(value, settings[setting]) then return false end
			end
		elseif type(value) == "table" then
			local match = false
			for i, value in ipairs(value) do if (settings[setting] or false) == value then
				match = true
				break
			end end
			if not match then return false end
		elseif (settings[setting] or false) ~= value then return false
		end
	end
	return true
end

function sbq.checkTable(check, checked)
	for k, v in pairs(check) do
		if type(v) == "table" then
			if not sbq.checkTable(v, (checked or {})[k]) then return false end
		elseif v == true and type((checked or {})[k]) ~= "boolean" and ((checked or {})[k]) ~= nil then
		elseif not (v == (checked or {})[k] or false) then return false
		end
	end
	return true
end


function dialogueBoxScripts.getLocationEffect(dialogueTree, settings, branch, eid, ...)
	local dialogueTree = dialogueTree
	local options = {}
	local effect = settings[(dialogueTree.location or settings.location).."Effect"]
	if settings.digested then
		return dialogueTree.digested or dialogueTree.default
	end

	if settings.healing then
		effect = settings.predDigestEffect or ((sbq.sbqData.locations[(dialogueTree.location or settings.location)] or {}).heal or {}).effect or "sbqHeal"
	end
	if settings.digesting then
		effect = settings.predDigestEffect or ((sbq.sbqData.locations[(dialogueTree.location or settings.location)] or {}).digest or {}).effect or "sbqDigest"
	elseif settings.healing then
		effect = settings.predDigestEffect or ((sbq.sbqData.locations[(dialogueTree.location or settings.location)] or {}).heal or {}).effect or "sbqHeal"
	end
	table.insert(options, effect or "default")

	if settings[(dialogueTree.location or settings.location).."Compression"] then
		table.insert(options, (dialogueTree.location or settings.location).."Compression")
	end
	if settings.transformed and dialogueTree.transformed then
		table.insert(options, "transformed")
	elseif not settings.transformed and settings.progressBarType == "transforming" and dialogueTree.transform then
		table.insert(options, "transform")
	end
	if settings.egged and dialogueTree.egged then
		table.insert(options, "egged")
	elseif not settings.egged and settings.progressBarType == "eggifying" and dialogueTree.eggify then
		table.insert(options, "eggify")
	end

	return dialogueTree[options[math.random(#options)]] or dialogueTree.default
end

function dialogueBoxScripts.locationEffect(dialogueTree, settings, branch, eid, ...)
	local dialogueTree = dialogueTree
	local effect = settings[(dialogueTree.location or settings.location).."Effect"]
	if settings.digested then
		return dialogueTree.digested or dialogueTree.default
	end
	if settings.digesting then
		effect = settings.predDigestEffect or ((sbq.sbqData.locations[(dialogueTree.location or settings.location)] or {}).digest or {}).effect or "sbqDigest"
	elseif settings.healing then
		effect = settings.predDigestEffect or ((sbq.sbqData.locations[(dialogueTree.location or settings.location)] or {}).heal or {}).effect or "sbqHeal"
	end

	return dialogueTree[effect] or dialogueTree.default
end

function dialogueBoxScripts.digestImmunity(dialogueTree, settings, branch, eid, ...)
	local effectSlot = (settings[(dialogueTree.location or settings.location) .. "EffectSlot"])
	if (settings.digestAllow and (effectSlot == "digest"))
	or (settings.softDigestAllow and (effectSlot == "softDigest"))
	then
		return dialogueTree["false"] or dialogueTree.default
	else
		return dialogueTree["true"] or dialogueTree.default
	end
end

function dialogueBoxScripts.cumDigestImmunity(dialogueTree, settings, branch, eid, ...)
	local effectSlot = (settings[(dialogueTree.location or settings.location) .. "EffectSlot"])
	if (settings.cumDigestAllow and (effectSlot == "digest"))
	or (settings.cumSoftDigestAllow and (effectSlot == "softDigest"))
	then
		return dialogueTree["false"] or dialogueTree.default
	else
		return dialogueTree["true"] or dialogueTree.default
	end
end

function dialogueBoxScripts.femcumDigestImmunity(dialogueTree, settings, branch, eid, ...)
	local effectSlot = (settings[(dialogueTree.location or settings.location) .. "EffectSlot"])
	if (settings.femcumDigestAllow and (effectSlot == "digest"))
	or (settings.femcumSoftDigestAllow and (effectSlot == "softDigest"))
	then
		return dialogueTree["false"] or dialogueTree.default
	else
		return dialogueTree["true"] or dialogueTree.default
	end
end

function dialogueBoxScripts.milkDigestImmunity(dialogueTree, settings, branch, eid, ...)
	local effectSlot = (settings[(dialogueTree.location or settings.location) .. "EffectSlot"])
	if (settings.milkDigestAllow and (effectSlot == "digest"))
	or (settings.milkSoftDigestAllow and (effectSlot == "softDigest"))
	then
		return dialogueTree["false"] or dialogueTree.default
	else
		return dialogueTree["true"] or dialogueTree.default
	end
end

function dialogueBoxScripts.openNewDialogueBox(dialogueTree, settings, branch, eid, ...)
	player.interact("ScriptPane", { data = sb.jsonMerge(metagui.inputData, dialogueTree.inputData), gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = dialogueTree.ui }, pane.sourceEntity())
	pane.dismiss()
end

function dialogueBoxScripts.isOwner(dialogueTree, settings, branch, eid, ...)
	local result = false
	if eid then
		local uuid = world.entityUniqueId(eid)
		result = uuid ~= nil and uuid == settings.ownerUuid
	end
	return dialogueTree[tostring(result) or "false"]
end

function dialogueBoxScripts.dismiss(dialogueTree, settings, branch, eid, ...)
	pane.dismiss()
end

function dialogueBoxScripts.swapFollowing(dialogueTree, settings, branch, eid, ...)
	sbq.addRPC(world.sendEntityMessage(pane.sourceEntity(), "sbqSwapFollowing"), function(data)
		if data and data[1] then
			if data[1] == "None" then
				sbq.updateDialogueBox({}, dialogueTree.continue)
			elseif data[1] == "Message" then
				if data[2].messageType == "recruits.requestUnfollow" then
					world.sendEntityMessage(player.id(), "recruits.requestUnfollow", table.unpack(data[2].messageArgs))
					sbq.updateDialogueBox({}, dialogueTree.continue)
				elseif data[2].messageType == "recruits.requestFollow" then
					local result = world.sendEntityMessage(player.id(), "sbqRequestFollow", table.unpack(data[2].messageArgs)):result()
					if result == nil then
						sbq.updateDialogueBox({}, dialogueTree.continue)
					else
						sbq.updateDialogueBox({}, dialogueTree.fail)
					end
				end
			end
		end
	end)
	return {}
end

function dialogueBoxScripts.infusedCharacter(dialogueTree, settings, branch, eid, ...)
	if (sbq.sbqData[(dialogueTree.location or settings.location)] or {}).infusion
	and settings[(((sbq.sbqData[(dialogueTree.location or settings.location)] or {}).infusionSetting or "infusion").."Pred")]
	and (((settings[(dialogueTree.location or settings.location) .. "InfusedItem"] or {}).parameters or {}).npcArgs) ~= nil
	then
		local uniqueID = settings[(dialogueTree.location or settings.location) .. "InfusedItem"].parameters.npcArgs.npcParam.scriptConfig.uniqueId
		if dialogueTree[uniqueID] then
			return dialogueTree[uniqueID]
		else
			return dialogueTree.defaultInfused
		end
	end
	return dialogueTree.default
end

function dialogueBoxScripts.giveTenantRewards(dialogueTree, settings, branch, eid, ...)
	if player ~= nil then
		local uuid = world.entityUniqueId(pane.sourceEntity())
		local tenantRewardsTable = player.getProperty("sbqTenantRewards") or {}

		local rewards = tenantRewardsTable[uuid]
		if rewards then
			player.cleanupItems()

			local rewardDialogue
			local remainingRewards = {}
			local remainingRewardsCount = 0
			local itemsGiven = 0

			for i, item in ipairs(rewards) do
				local count = player.hasCountOfItem(item, false)
				player.giveItem(item)
				local newCount = player.hasCountOfItem(item, false)
				local itemType = root.itemType(item.name)
				local diff = newCount - count
				if (itemType ~= "currency") and (diff < (item.count or 0)) then
					item.count = item.count - diff
					remainingRewardsCount = remainingRewardsCount + item.count
					table.insert(remainingRewards, item)
				elseif (itemType == "currency") then
					itemsGiven = itemsGiven + item.count
				end
				itemsGiven = itemsGiven + diff
				if ((diff > 0) or (itemType == "currency")) and item.rewardDialogue then rewardDialogue = item.rewardDialogue end
			end

			if remainingRewardsCount > 0 then
				tenantRewardsTable[uuid] = remainingRewards
			else
				tenantRewardsTable[uuid] = nil
			end
			player.setProperty("sbqTenantRewards", tenantRewardsTable)

			if itemsGiven > 0 then return dialogueTree[rewardDialogue or "rewards"] or dialogueTree.default end
		end
	end
	return dialogueTree.default
end

-- this doesn't work
function dialogueBoxScripts.cockTFmePls(dialogueTree, settings, branch, eid, ...)
	world.sendEntityMessage(sbq.data.occupantHolder or pane.sourceEntity(), "requestTransition", "cockVore",{ id = player.id(), force = true })
	sbq.timer("ctfDelay", 0.25, function()
		shaftBallsInfusion:onClick()
	end)
end
