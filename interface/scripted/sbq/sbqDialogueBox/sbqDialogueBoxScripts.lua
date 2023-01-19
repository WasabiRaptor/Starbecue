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

function sbq.getDialogueBranch(dialogueTreeLocation, settings, entity, dialogueTree)
	local dialogueTree = sbq.getRedirectedDialogue(dialogueTree or sbq.dialogueTree, settings) or {}

	for _, branch in ipairs(dialogueTreeLocation) do
		dialogueTree = sbq.checkDialogueBranch(dialogueTree, settings, branch, entity)
	end

	local continue = true
	while continue and type(dialogueTree) == "table" do
		continue = false
		local nextType = type(dialogueTree.next)
		if nextType == "string" then
			dialogueTree = sbq.checkDialogueBranch(dialogueTree, settings, dialogueTree.next, entity)
			continue = true
		elseif nextType == "table" then
			dialogueTree = sbq.checkDialogueBranch(dialogueTree, settings, dialogueTree.next[math.random(#dialogueTree.next)], entity)
			continue = true
		end
	end

	return dialogueTree
end

function sbq.checkDialogueBranch(dialogueTree, settings, branch, entity)
	local dialogueTree = dialogueTree
	if type(dialogueTree) == "table" then
		if type(dialogueBoxScripts[branch]) == "function" then
			dialogueTree = dialogueBoxScripts[branch](dialogueTree, settings, branch, entity)
		elseif settings[branch] ~= nil then
			dialogueTree = dialogueTree[tostring(settings[branch])] or dialogueTree[branch] or dialogueTree.default
		else
			dialogueTree = dialogueTree[branch]
		end
	end
	return sbq.getRedirectedDialogue(dialogueTree, settings, entity)
end

local recursionCount = 0
-- for dialog in other files thats been pointed to
function sbq.getRedirectedDialogue(dialogueTree, settings, entity)
	local dialogueTree = dialogueTree
	if type(dialogueTree) == "string" then
		local firstChar = dialogueTree:sub(1,1)
		if firstChar == "/" then
			dialogueTree = root.assetJson(dialogueTree)
		else
			local found1 = dialogueTree:find("%.")
			local jump = {}
			while found1 do
				table.insert(jump, dialogueTree:sub(1,found1-1))
				dialogueTree = dialogueTree:sub(found1+1,-1)
				found1 = dialogueTree:find("%.")
			end
			table.insert(jump, dialogueTree)
			if recursionCount > 10 then return {} end -- protection against possible infinite loops of recusion
			recursionCount = recursionCount + 1
			dialogueTree = sbq.getDialogueBranch(jump, settings, entity)
		end
	end
	return dialogueTree or {}
end

function sbq.getRandomDialogueTreeValue(dialogueTree, settings, randomRolls, randomTable, name)
	local randomRolls = randomRolls
	local randomTable = randomTable
	local badRolls = {}
	local i = 1
	local prevTable
	while type(randomTable) == "table" do
		if randomTable.add then
			if randomTable.check then
				if sbq.checkSettings(randomTable.check, settings) then
					if type(randomTable.add) == "string" then
						randomTable = sbq.getRedirectedDialogue(randomTable.add, settings)[name]
					else
						randomTable = randomTable.add
					end
				elseif randomTable.fail ~= nil then
					if type(randomTable.fail) == "string" then
						randomTable = sbq.getRedirectedDialogue(randomTable.fail, settings)[name]
					else
						randomTable = randomTable.fail
					end
				else
					i = i - 1
					badRolls[randomRolls[i]] = true
					randomRolls[i] = nil -- clear the saved random value so it chooses a different one next round
					randomTable = prevTable
				end
			else
				if type((randomTable or {}).add) == "string" then
					randomTable = sbq.getRedirectedDialogue((randomTable or {}).add, settings)[name]
				else
					randomTable = (randomTable or {}).add
				end
			end
		elseif randomTable.infusedSlot then
			local itemSlot = settings[((dialogueTree.location or settings.location) or "").."InfusedItem"]
			if type(randomTable.infusedSlot) == "string" then
				itemSlot = settings[randomTable.infusedSlot]
			end
			if ((itemSlot or {}).parameters or {}).npcArgs then
				local uniqueId = (((((itemSlot or {}).parameters or {}).npcArgs or {}).npcParam or {}).scriptConfig or {}).uniqueId
				if uniqueId and randomTable[uniqueId] ~= nil then
					randomTable = randomTable[uniqueId]
				else
					randomTable = randomTable.default
				end
				if type(randomTable) == "string" then
					randomTable = sbq.getRedirectedDialogue(randomTable, settings)[name]
				end
			else
				i = i - 1
				badRolls[randomRolls[i]] = true
				randomRolls[i] = nil -- clear the saved random value so it chooses a different one next round
				randomTable = prevTable
			end
		else
			if randomRolls[i] == nil then
				local roll = math.random(#randomTable)
				while badRolls[roll] do
					roll = math.random(#randomTable)
				end
				table.insert(randomRolls, roll)
			end
			prevTable = randomTable
			randomTable = randomTable[randomRolls[i]] or randomTable[1]
			i = i + 1
		end
	end
	recursionCount = 0 -- since we successfully made it here, reset the recursion count
	return randomRolls, randomTable
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


function dialogueBoxScripts.getLocationEffect(dialogueTree, settings, branch, entity, ...)
	local dialogueTree = dialogueTree
	local options = {}
	local effect = settings[(dialogueTree.location or settings.location).."Effect"]
	if settings.digested then
		return dialogueTree.digested or dialogueTree.default
	end

	if settings.cumDigesting or settings.digesting then
		effect = ((settings.locationsData[(dialogueTree.location or settings.location)] or {}).digest).effect or "sbqDigest"
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

function dialogueBoxScripts.locationEffect(dialogueTree, settings, branch, entity, ...)
	local dialogueTree = dialogueTree
	local effect = settings[(dialogueTree.location or settings.location).."Effect"]
	if settings.digested then
		return dialogueTree.digested or dialogueTree.default
	end
	if settings.cumDigesting or settings.digesting then
		effect = ((settings.locationsData[(dialogueTree.location or settings.location)] or {}).digest).effect or "sbqDigest"
	end

	return dialogueTree[effect] or dialogueTree.default
end

function dialogueBoxScripts.digestImmunity(dialogueTree, settings, branch, entity, ...)
	if (not settings.digestAllow) and (settings.softDigestAllow and settings[(dialogueTree.location or settings.location).."EffectSlot"] == "softDigest") then
		return dialogueTree["false"] or dialogueTree.default
	elseif (not settings.digestAllow) then
		return dialogueTree["true"] or dialogueTree.default
	else
		return dialogueTree["false"] or dialogueTree.default
	end
end

function dialogueBoxScripts.cumDigestImmunity(dialogueTree, settings, branch, entity, ...)
	if (not settings.cumDigestAllow) and (settings.cumSoftDigestAllow and settings[(dialogueTree.location or settings.location).."EffectSlot"] == "softDigest") then
		return dialogueTree["false"] or dialogueTree.default
	elseif (not settings.cumDigestAllow) then
		return dialogueTree["true"] or dialogueTree.default
	else
		return dialogueTree["false"] or dialogueTree.default
	end
end

function dialogueBoxScripts.femcumDigestImmunity(dialogueTree, settings, branch, entity, ...)
	if (not settings.femcumDigestAllow) and (settings.femcumSoftDigestAllow and settings[(dialogueTree.location or settings.location).."EffectSlot"] == "softDigest") then
		return dialogueTree["false"] or dialogueTree.default
	elseif (not settings.femcumDigestAllow) then
		return dialogueTree["true"] or dialogueTree.default
	else
		return dialogueTree["false"] or dialogueTree.default
	end
end

function dialogueBoxScripts.milkDigestImmunity(dialogueTree, settings, branch, entity, ...)
	if (not settings.milkDigestAllow) and (settings.milkSoftDigestAllow and settings[(dialogueTree.location or settings.location).."EffectSlot"] == "softDigest") then
		return dialogueTree["false"] or dialogueTree.default
	elseif (not settings.milkDigestAllow) then
		return dialogueTree["true"] or dialogueTree.default
	else
		return dialogueTree["false"] or dialogueTree.default
	end
end

function dialogueBoxScripts.openNewDialogueBox(dialogueTree, settings, branch, entity, ...)
	player.interact("ScriptPane", { data = sb.jsonMerge(metagui.inputData, dialogueTree.inputData), gui = { }, scripts = {"/metagui.lua"}, ui = dialogueTree.ui }, pane.sourceEntity())
	pane.dismiss()
end

function dialogueBoxScripts.isOwner(dialogueTree, settings, branch, entity, ...)
	local result = false
	if entity then
		local uuid = world.entityUniqueId(entity)
		result = uuid ~= nil and uuid == settings.ownerUuid
	end
	return dialogueTree[tostring(result) or "false"]
end

function dialogueBoxScripts.dismiss(dialogueTree, settings, branch, entity, ...)
	pane.dismiss()
end

function dialogueBoxScripts.swapFollowing(dialogueTree, settings, branch, entity, ...)
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

function dialogueBoxScripts.infusedCharacter(dialogueTree, settings, branch, entity, ...)
	if (((settings[(dialogueTree.location or settings.location).."InfusedItem"] or {}).parameters or {}).npcArgs) ~= nil then
		local uniqueID = settings[(dialogueTree.location or settings.location) .. "InfusedItem"].parameters.npcArgs.npcParam.scriptConfig.uniqueId
		if dialogueTree[uniqueID] then
			return dialogueTree[uniqueID]
		else
			return dialogueTree.defaultInfused
		end
	end
	return dialogueTree.default
end

function dialogueBoxScripts.giveTenantRewards(dialogueTree, settings, branch, entity, ...)
	if player ~= nil then
		local uuid = world.entityUniqueId(pane.sourceEntity())
		local tenantRewardsTable = player.getProperty("sbqTenantRewards") or {}
		local rewards = tenantRewardsTable[uuid]
		if rewards then
			local rewardDialogue
			for rewardName, reward in pairs(rewards) do
				for i = 1, reward.count do
					world.spawnTreasure( world.entityPosition(pane.sourceEntity()), reward.pool, reward.level or 0)
				end
				if reward.dialogue then
					rewardDialogue = reward.dialogue
				end
			end
			tenantRewardsTable[uuid] = nil

			player.setProperty("sbqTenantRewards", tenantRewardsTable)

			return dialogueTree[rewardDialogue or "rewards"] or dialogueTree.default
		end
	end
	return dialogueTree.default
end
