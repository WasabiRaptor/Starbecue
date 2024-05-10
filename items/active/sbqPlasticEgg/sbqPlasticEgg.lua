local clicked
function update(dt, fireMode, shiftHeld, controls)

	if fireMode == "primary" and not clicked then
		status.setStatusProperty("sbqPlasticEgg", config.getParameter("eggParameters"))
		status.addEphemeralEffect("sbqPlasticEgg")
		item.consume(1)
	elseif fireMode == "none" then
		clicked = false
	end
end
