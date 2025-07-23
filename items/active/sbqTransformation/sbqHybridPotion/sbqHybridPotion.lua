sbq = {}
function init()
	sbq.config = root.assetJson("/sbq.config")
	activeItem.setArmAngle(-math.pi/4)
	animator.resetTransformationGroup("potion")
	animator.rotateTransformationGroup("potion", math.pi/4)
end

function update(dt, fireMode, shiftHeld)
	if not self.useTimer and fireMode == "primary" and not activeItem.callOtherHandScript("isDartGun") then
		if not config.getParameter("species") then
			animator.playSound("error")
			return
		end
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

			world.sendEntityMessage(player.id(), "sbqHybridTransformation", config.getParameter("species"), config.getParameter("duration") or sbq.config.defaultTFDuration)
			if not player.isAdmin() then item.consume(1) end
		end
	end
end

function transformationItemArgs(useType)
	if not config.getParameter("species") then
		animator.playSound("error")
		return
	end
	return { message = "sbqHybridTransformation", itemName = item.name(), args = {config.getParameter("species"), config.getParameter("duration") or sbq.config.defaultTFDuration}, consume = not player.isAdmin() }
end
