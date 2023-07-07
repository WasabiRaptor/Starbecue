local oldinit = init
sbq = {}
require("/scripts/SBQ_everything_primary.lua")
function init()
	oldinit()
	sbq.everything_primary()

	message.setHandler("sbqGetSeatEquips", function(_,_, current)
		status.setStatusProperty("sbqCurrentData", current)
		local type = status.statusProperty("sbqType")
		if type == "prey" then
			status.setStatusProperty("sbqDontTouchDoors", true)
		else
			status.setStatusProperty("sbqDontTouchDoors", false)
		end
	end)
	message.setHandler("sbqSetType", function(_, _, current)
		status.setStatusProperty("sbqType", current)
	end)

	message.setHandler("sbqSetCurrentData", function(_,_, current)
		status.setStatusProperty("sbqCurrentData", current)
		local type = status.statusProperty("sbqType")
		if type == "prey" then
			status.setStatusProperty("sbqDontTouchDoors", true)
		else
			status.setStatusProperty("sbqDontTouchDoors", false)
		end
	end)
end
