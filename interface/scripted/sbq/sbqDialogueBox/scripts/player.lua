---@diagnostic disable: undefined-global

function dialogueBoxScripts.queueVore(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	sbq.timer("eatMessage", dialogue.result.delay or 1.5, function ()
		world.sendEntityMessage(sbq.data.occupantHolder or pane.sourceEntity(), "requestTransition", settings.voreType, { id = player.id(), willing = true })
		sbq.timer("gotVored", dialogue.result.delay or 1.5, function()
			for i, occupant in pairs(sbq.occupant or {}) do
				if occupant.id == player.id() then
					sbq.updateDialogueBox( ".after", dialogueTree, dialogueTreeTop)
					return
				end
			end
		end)
	end)
end

function dialogueBoxScripts.queuePrey(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	sbq.timer("eatMessage", dialogue.result.delay or 1.5, function ()
		world.sendEntityMessage(player.id(), "requestTransition", settings.voreType, { id = pane.sourceEntity(), willing = true })
	end)
end

function dialogueBoxScripts.giveTenantRewards(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
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

			if itemsGiven > 0 then return "rewards" end
		end
	end
	return "default"
end

-- this doesn't work
function dialogueBoxScripts.cockTFmePls(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	world.sendEntityMessage(sbq.data.occupantHolder or pane.sourceEntity(), "requestTransition", "cockVore",{ id = player.id(), force = true })
	sbq.timer("ctfDelay", 0.25, function()
		shaftBallsInfusion:onClick()
	end)
end

function dialogueBoxScripts.dismiss(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	pane.dismiss()
end

function dialogueBoxScripts.swapFollowing(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	sbq.addRPC(world.sendEntityMessage(pane.sourceEntity(), "sbqSwapFollowing"), function(data)
		if data and data[1] then
			if data[1] == "None" then
				sbq.updateDialogueBox(".stay", dialogueTree, dialogueTreeTop)
			elseif data[1] == "Message" then
				if data[2].messageType == "recruits.requestUnfollow" then
					world.sendEntityMessage(player.id(), "recruits.requestUnfollow", table.unpack(data[2].messageArgs))
					sbq.updateDialogueBox(".stay", dialogueTree, dialogueTreeTop)
				elseif data[2].messageType == "recruits.requestFollow" then
					local result = world.sendEntityMessage(player.id(), "sbqRequestFollow", table.unpack(data[2].messageArgs)):result()
					if result == nil then
						sbq.updateDialogueBox(".follow", dialogueTree, dialogueTreeTop)
					else
						sbq.updateDialogueBox(".fullCrew", dialogueTree, dialogueTreeTop)
					end
				end
			end
		end
	end)
end

function dialogueBoxScripts.openNewDialogueBox(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	player.interact("ScriptPane", { data = sb.jsonMerge(metagui.inputData, dialogue.result.inputData), gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = dialogue.result.ui }, pane.sourceEntity())
	pane.dismiss()
end
