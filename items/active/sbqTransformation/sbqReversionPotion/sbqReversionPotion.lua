function init()
	self.useTimer = nil
	activeItem.setArmAngle(-math.pi/4)
	animator.resetTransformationGroup("potion")
	animator.rotateTransformationGroup("potion", math.pi/4)
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
		else
			self.useTimer = nil
			activeItem.setArmAngle(-math.pi / 4)
			player.setScriptContext("starbecue")
			player.callScript("sbq.revertTF")
			if not player.isAdmin() then item.consume(1) end
			init()
		end
	end
end

function transformationItemArgs(useType)
	return { message = "sbqRevertTF", itemName = item.name(), consume = not player.isAdmin() }
end
