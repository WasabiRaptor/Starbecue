
function init()
	activeItem.setArmAngle(-math.pi / 4)
	animator.resetTransformationGroup("potion")
	animator.rotateTransformationGroup("potion", math.pi / 4)
end

function update(dt, fireMode, shiftHeld)
	if not self.useTimer and fireMode == "primary" and not activeItem.callOtherHandScript("isDartGun") then
		self.useTimer = 0
		activeItem.setArmAngle(0)
		animator.playSound("drink", 4)
	end

	if self.useTimer then
		self.useTimer = self.useTimer + dt

		if self.useTimer < 3.1 then
			activeItem.setArmAngle(self.useTimer / 5)
		elseif self.useTimer < 5.5 then
			activeItem.setArmAngle(math.max(3.1 / 5 - (self.useTimer - 3.1) * 3, -math.pi / 3))
        else
            player.setScriptContext("starbecue")
			player.callScript("sbq.doTransformation", config.getParameter("args"))
		end
	end
end

function transformationItemArgs(useType)
	return { message = "sbqDoTransformation", itemName = item.name(), args = config.getParameter("args"), consume = true }
end
