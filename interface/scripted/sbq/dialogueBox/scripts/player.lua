---@diagnostic disable: undefined-global

function dialogueStepScripts.swapFollowing(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
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
