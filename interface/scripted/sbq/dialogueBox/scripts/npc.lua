
function dialogueStepScripts.queueVore(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	sbq.timer("eatMessage", dialogue.result.delay or 1.5, function()
		sbq.requestTransition(settings.voreType, { id = eid, willing = settings.willing, keepWindow = true})
		sbq.timer("gotVored", dialogue.result.delay or 1.5, function()
			for i, occupant in pairs(sbq.occupant or {}) do
				if occupant.id == eid then
					dialogueProcessor.getRandomDialogue( ".after", eid, settings, dialogueTree, false, dialogueTreeTop )
					return
				end
			end
		end)
	end)
end

function dialogueStepScripts.queuePrey(dialogueTree, dialogueTreeTop, settings, branch, eid, ...)
	sbq.timer("eatMessage", dialogue.result.delay or 1.5, function()
		world.sendEntityMessage(eid, "requestTransition", settings.voreType, { id = entity.id(), willing = settings.willing, keepWindow = true })
	end)
end
