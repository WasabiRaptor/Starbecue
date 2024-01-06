function init()
	activeItem.setArmAngle(-math.pi/4)
	animator.resetTransformationGroup("potion")
	animator.rotateTransformationGroup("potion", math.pi/4)
end

function update(dt, fireMode, shiftHeld)
	if fireMode == "primary" and not activeItem.callOtherHandScript("isDartGun") then
		local parameters = humanoid.getIdentity()
		parameters.potionPath = "/items/active/sbqTransformation/sbqDuplicatePotion/"
		parameters.rarity = "legendary"
		player.giveItem({name = "sbqMysteriousPotion", parameters = parameters})
		item.consume(1)
	end
end

function dartGunData()
	return { funcName = "transform", data = humanoid.getIdentity()}
end
