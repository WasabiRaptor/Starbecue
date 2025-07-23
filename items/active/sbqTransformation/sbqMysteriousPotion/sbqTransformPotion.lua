sbq = {}
require("/scripts/any/SBQ_util.lua")
function init()
	activeItem.setArmAngle(-math.pi / 4)
	animator.resetTransformationGroup("potion")
	animator.rotateTransformationGroup("potion", math.pi / 4)
end

function update(dt, fireMode, shiftHeld)
	if not self.useTimer and fireMode == "primary" and not activeItem.callOtherHandScript("isDartGun") then
		if sbq.tableMatches(config.getParameter("args")[1], sbq.humanoidIdentity()) then return end
		if config.getParameter("invalidPotion") then
			animator.playSound("error")
			player.radioMessage("sbqTransformIntoBlacklist")
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

			world.sendEntityMessage(player.id(), "sbqDoTransformation", table.unpack(config.getParameter("args") or {}))
			if not player.isAdmin() then item.consume(1) end
		end
	end
end

function transformationItemArgs(useType)
	if config.getParameter("invalidPotion") then
		animator.playSound("error")
		player.radioMessage("sbqTransformBindBlacklist")
		return
	end
	return { message = "sbqDoTransformation", itemName = item.name(), args = config.getParameter("args"), consume = not player.isAdmin() }
end
