function init()
	activeItem.setArmAngle(-math.pi/4)
	animator.resetTransformationGroup("potion")
	animator.rotateTransformationGroup("potion", math.pi/4)
end

function update(dt, fireMode, shiftHeld)
	if fireMode == "primary" and not activeItem.callOtherHandScript("isDartGun") then
        player.giveItem({ name = "sbqMysteriousPotion", parameters = {
            args = { sb.jsonMerge(humanoid.getIdentity(), { force = true }), 5 },
			rarity = "legendary"
		}})
		item.consume(1)
	end
end

function transformationItemArgs(useType)
	return { message = "sbqDoTransformation", itemName = "sbqMysteriousPotion", consume = true, args = {sb.jsonMerge(humanoid.getIdentity(), {force = true}), 5} }
end
