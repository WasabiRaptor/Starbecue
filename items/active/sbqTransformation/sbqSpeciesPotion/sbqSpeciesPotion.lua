function init()
	activeItem.setArmAngle(-math.pi/4)
	animator.rotateTransformationGroup("potion", math.pi/4)
end

function update(dt, fireMode, shiftHeld)
	if fireMode == "primary" and not activeItem.callOtherHandScript("isDartGun") then
		player.giveItem({ name = "sbqMysteriousPotion", parameters = {
			args = {{species = humanoid.species()},5},
		}})
		item.consume(1)
	end
end

function transformationItemArgs(useType)
	return { message = "sbqDoTransformation", itemName = "sbqMysteriousPotion", args = {{species= humanoid.species()},5}, consume = true}
end
