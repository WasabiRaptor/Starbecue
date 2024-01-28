require("/scripts/SBQ_everything_primary.lua")
local old = {
	init = init,
	update = update
}
require("/scripts/SBQ_public_settings.lua")
function init()
	old.init()
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
	sbq.setupPublicSettings()
end
