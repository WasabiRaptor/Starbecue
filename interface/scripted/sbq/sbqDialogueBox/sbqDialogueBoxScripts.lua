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

function sbq.getDialogueBranch(dialogueTreeLocation, settings, eid, dialogueTree, dialogueTreeTop)
	--(sb.printJson(dialogueTreeLocation))
	local dialogueTree = sbq.getRedirectedDialogue(dialogueTree or sbq.dialogueTree, settings, eid, dialogueTreeTop) or {}
	local dialogueTreeTop = dialogueTreeTop or dialogueTree

	for _, branch in ipairs(dialogueTreeLocation) do
		dialogueTree = sbq.checkDialogueBranch(dialogueTree, settings, branch, eid, dialogueTreeTop)
	end

	local continue = true
	while continue and type(dialogueTree) == "table" do
		continue = false
		local next
		if type(dialogueTree.next) == "string" then
			next = dialogueTree.next
		elseif type(next) == "table" then
			next = dialogueTree.next[math.random(#dialogueTree.next)]
		end
		if next then
			--sb.logInfo(next)
			dialogueTree = sbq.checkDialogueBranch(dialogueTree, settings, next, eid, dialogueTreeTop)
			continue = true
		end
	end

	return dialogueTree
end

function sbq.checkDialogueBranch(dialogueTree, settings, branch, eid, dialogueTreeTop)
	local dialogueTree = dialogueTree
	if type(dialogueTree) == "table" then
		-- if we are moving down the tree its nice to have it automatically set a point to return to as we move past it
		sbq.dialogueTreeReturn = dialogueTree.dialogueTreeReturn or sbq.dialogueTreeReturn

		if type(dialogueBoxScripts[branch]) == "function" then
			dialogueTree = dialogueBoxScripts[branch](dialogueTree, settings, branch, eid)
		elseif settings[branch] ~= nil then
			dialogueTree = dialogueTree[tostring(settings[branch])] or dialogueTree[branch] or dialogueTree.default
		else
			dialogueTree = dialogueTree[branch]
		end
	end
	return sbq.getRedirectedDialogue(dialogueTree, settings, eid, dialogueTreeTop)
end

local recursionCount = 0
-- for dialog in other files thats been pointed to
function sbq.getRedirectedDialogue(dialogueTree, settings, eid, dialogueTreeTop)
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
			dialogueTree = sbq.getDialogueBranch(jump, settings, eid, dialogueTreeTop, dialogueTreeTop)
		end
	end
	return dialogueTree or {}
end

function sbq.getRandomDialogueTreeValue(dialogueTree, settings, randomRolls, randomTable, name, dialogueTreeTop)
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
						randomTable = sbq.getRedirectedDialogue(randomTable.add, settings, nil, dialogueTreeTop)[name]
					else
						randomTable = randomTable.add
					end
				elseif randomTable.fail ~= nil then
					if type(randomTable.fail) == "string" then
						randomTable = sbq.getRedirectedDialogue(randomTable.fail, settings, nil, dialogueTreeTop)[name]
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
					randomTable = sbq.getRedirectedDialogue((randomTable or {}).add, settings, nil, dialogueTreeTop)[name]
				else
					randomTable = (randomTable or {}).add
				end
			end
		elseif randomTable.infusedSlot
		and (sbq.sbqData.locations[(dialogueTree.location or settings.location)] or {}).infusion
		and settings[(((sbq.sbqData.locations[(dialogueTree.location or settings.location)] or {}).infusionSetting or "infusion").."Pred")]
		then
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
					randomTable = sbq.getRedirectedDialogue(randomTable, settings, nil, dialogueTreeTop)[name]
				end
			else
				i = i - 1
				badRolls[randomRolls[i]] = true
				randomRolls[i] = nil -- clear the saved random value so it chooses a different one next round
				randomTable = prevTable
			end
		else
			if randomRolls[i] == nil then
				if randomTable[1] then
					local roll = math.random(#randomTable)
					while badRolls[roll] do
						roll = math.random(#randomTable)
					end
					table.insert(randomRolls, roll)
				end
			end
			prevTable = randomTable
			randomTable = randomTable[randomRolls[i] or 1]
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


function dialogueBoxScripts.getLocationEffect(dialogueTree, settings, branch, eid, ...)
	local dialogueTree = dialogueTree
	local options = {}
	local effect = settings[(dialogueTree.location or settings.location).."Effect"]
	if settings.digested then
		return dialogueTree.digested or dialogueTree.default
	end

	if settings.digesting then
		effect = settings.predDigestEffect or ((sbq.sbqData.locations[(dialogueTree.location or settings.location)] or {}).digest or {}).effect or "sbqDigest"
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
	end

	return dialogueTree[effect] or dialogueTree.default
end

function dialogueBoxScripts.digestImmunity(dialogueTree, settings, branch, eid, ...)
	if (not settings.digestAllow) and (settings.softDigestAllow and settings[(dialogueTree.location or settings.location).."EffectSlot"] == "softDigest") then
		return dialogueTree["false"] or dialogueTree.default
	elseif (not settings.digestAllow) then
		return dialogueTree["true"] or dialogueTree.default
	else
		return dialogueTree["false"] or dialogueTree.default
	end
end

function dialogueBoxScripts.cumDigestImmunity(dialogueTree, settings, branch, eid, ...)
	if (not settings.cumDigestAllow) and (settings.cumSoftDigestAllow and settings[(dialogueTree.location or settings.location).."EffectSlot"] == "softDigest") then
		return dialogueTree["false"] or dialogueTree.default
	elseif (not settings.cumDigestAllow) then
		return dialogueTree["true"] or dialogueTree.default
	else
		return dialogueTree["false"] or dialogueTree.default
	end
end

function dialogueBoxScripts.femcumDigestImmunity(dialogueTree, settings, branch, eid, ...)
	if (not settings.femcumDigestAllow) and (settings.femcumSoftDigestAllow and settings[(dialogueTree.location or settings.location).."EffectSlot"] == "softDigest") then
		return dialogueTree["false"] or dialogueTree.default
	elseif (not settings.femcumDigestAllow) then
		return dialogueTree["true"] or dialogueTree.default
	else
		return dialogueTree["false"] or dialogueTree.default
	end
end

function dialogueBoxScripts.milkDigestImmunity(dialogueTree, settings, branch, eid, ...)
	if (not settings.milkDigestAllow) and (settings.milkSoftDigestAllow and settings[(dialogueTree.location or settings.location).."EffectSlot"] == "softDigest") then
		return dialogueTree["false"] or dialogueTree.default
	elseif (not settings.milkDigestAllow) then
		return dialogueTree["true"] or dialogueTree.default
	else
		return dialogueTree["false"] or dialogueTree.default
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

function dialogueBoxScripts.cockTFmePls(dialogueTree, settings, branch, eid, ...)
	world.sendEntityMessage(sbq.data.occupantHolder or pane.sourceEntity(), "requestTransition", "cockVore",{ id = player.id(), force = true })
	sbq.timer("ctfDelay", 0.25, function()
		shaftBallsInfusion:onClick()
	end)
	return dialogueTree.continue or {dialogue = {""}}
end
