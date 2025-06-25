sbq = {}
function init()
	sbq.config = root.assetJson("/sbq.config")
	activeItem.setArmAngle(-math.pi/4)
	animator.rotateTransformationGroup("potion", math.pi/4)
end

function update(dt, fireMode, shiftHeld)
	if fireMode == "primary" and not activeItem.callOtherHandScript("isDartGun") then
		if sbq.config.transformationBlacklist[humanoid.species()] then
			animator.playSound("error")
			player.radioMessage("sbqTransformBindBlacklist")
			return
		end
		player.giveItem({ name = "sbqMysteriousPotion", parameters = {
			args = {{species = humanoid.species()}, sbq.config.defaultTFDuration},
		}})
		item.consume(1)
	end
end

function transformationItemArgs(useType)
	if sbq.config.transformationBlacklist[humanoid.species()] then
		animator.playSound("error")
		player.radioMessage("sbqTransformBindBlacklist")
		return
	end
	return { message = "sbqDoTransformation", itemName = "sbqMysteriousPotion", args = {{species= humanoid.species()}, sbq.config.defaultTFDuration}, consume = true}
end
