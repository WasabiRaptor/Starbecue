sbq = {}
function init()
	sbq.config = root.assetJson("/sbq.config")
	activeItem.setArmAngle(-math.pi/4)
	animator.resetTransformationGroup("potion")
	animator.rotateTransformationGroup("potion", math.pi/4)
end

function update(dt, fireMode, shiftHeld)
	if fireMode == "primary" and not activeItem.callOtherHandScript("isDartGun") then
		if root.speciesConfig(player.species()).sbqCompatible == false then
			animator.playSound("error")
			player.radioMessage("sbqTransformBindBlacklist")
			return
		end

		player.giveItem({ name = "sbqMysteriousPotion", parameters = {
			args = {player.humanoidIdentity(), config.getParameter("duration") or sbq.config.defaultTFDuration, true},
		}})
		if not player.isAdmin() then item.consume(1) end
	end
end

function transformationItemArgs(useType)
	if root.speciesConfig(player.species()).sbqCompatible == false then
		animator.playSound("error")
		player.radioMessage("sbqTransformBindBlacklist")
		return
	end
	return { message = "sbqDoTransformation", itemName = "sbqMysteriousPotion", consume = not player.isAdmin(), args = {player.humanoidIdentity(), config.getParameter("duration") or sbq.config.defaultTFDuration, true} }
end
