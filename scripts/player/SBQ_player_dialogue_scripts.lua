function dialogueStepScripts.giveRewards(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
    -- TODO redo all of this

	-- if player ~= nil then
	-- 	local uuid = world.entityUniqueId(pane.sourceEntity())
	-- 	local tenantRewardsTable = player.getProperty("sbqTenantRewards") or {}

	-- 	local rewards = tenantRewardsTable[uuid]
	-- 	if rewards then
	-- 		player.cleanupItems()

	-- 		local rewardDialogue
	-- 		local remainingRewards = {}
	-- 		local remainingRewardsCount = 0
	-- 		local itemsGiven = 0

	-- 		for i, item in ipairs(rewards) do
	-- 			local count = player.hasCountOfItem(item, false)
	-- 			player.giveItem(item)
	-- 			local newCount = player.hasCountOfItem(item, false)
	-- 			local itemType = root.itemType(item.name)
	-- 			local diff = newCount - count
	-- 			if (itemType ~= "currency") and (diff < (item.count or 0)) then
	-- 				item.count = item.count - diff
	-- 				remainingRewardsCount = remainingRewardsCount + item.count
	-- 				table.insert(remainingRewards, item)
	-- 			elseif (itemType == "currency") then
	-- 				itemsGiven = itemsGiven + item.count
	-- 			end
	-- 			itemsGiven = itemsGiven + diff
	-- 			if ((diff > 0) or (itemType == "currency")) and item.rewardDialogue then rewardDialogue = item.rewardDialogue end
	-- 		end

	-- 		if remainingRewardsCount > 0 then
	-- 			tenantRewardsTable[uuid] = remainingRewards
	-- 		else
	-- 			tenantRewardsTable[uuid] = nil
	-- 		end
	-- 		player.setProperty("sbqTenantRewards", tenantRewardsTable)

	-- 		if itemsGiven > 0 then return "rewards" end
	-- 	end
	-- end
	return "default"
end

function dialogueStepScripts.dismiss(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	pane.dismiss()
end

function dialogueStepScripts.openNewDialogueBox(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	player.interact("ScriptPane", { sourceRadius = config.getParameter("sourceRadius"), data = sb.jsonMerge(_ENV.metagui.inputData, dialogue.result.inputData), gui = { }, scripts = {"/metagui/sbq/build.lua"}, ui = dialogue.result.ui }, pane.sourceEntity())
	pane.dismiss()
end

function dialogueStepScripts.isOwner(dialogueTree, dialogueTreeTop, settings, step, eid, ...)
	local result = false
	if sbq.parentEntityData and sbq.parentEntityData[1] then
		result = player.uniqueId() == sbq.parentEntityData[1]
	end
	return tostring(result)
end

function dialogueStepScripts.isFollowing(dialogueTree, dialogueTreeTop, settings, step, eid, ...)
	local result = false
	if sbq.parentEntityData and sbq.parentEntityData[1] then
		result = (player.uniqueId() == sbq.parentEntityData[1]) and sbq.parentEntityData[3]
	end
	return tostring(result)
end

function dialogueStepScripts.requestFollow()
	world.sendEntityMessage(pane.sourceEntity(), "sbqRecruitFollow")

end
function dialogueStepScripts.requestUnfollow()
	world.sendEntityMessage(pane.sourceEntity(), "sbqRecruitUnfollow")
end

function dialogueStepScripts.canGainFollowers()
	local canGainFollowers = false
	if sbq.parentEntityData and sbq.parentEntityData[2] then
		sbq.addRPC(world.sendEntityMessage(player.id(), "sbqCanGainFollower", sbq.parentEntityData[2]), function (res)
			canGainFollowers = res or false
		end)
	end
	return tostring(canGainFollowers)
end

function dialogueStepScripts.funnyError(dialogueTree, dialogueTreeTop, settings, step, eid, ...)
	player.funnyError(dialogueProcessor.getRedirectedDialogue(dialogueTree.funnyError, true, settings, dialogueTree, dialogueTreeTop))
end
