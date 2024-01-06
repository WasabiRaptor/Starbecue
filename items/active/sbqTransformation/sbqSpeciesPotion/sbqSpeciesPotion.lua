function init()
	activeItem.setArmAngle(-math.pi/4)
	animator.rotateTransformationGroup("potion", math.pi/4)
end

function update(dt, fireMode, shiftHeld)
	if fireMode == "primary" and not activeItem.callOtherHandScript("isDartGun") then
		data.species = humanoid.species()
		data.potionPath = "/items/active/sbqTransformation/sbqSpeciesPotion/"
		data.rarity = "rare"
		player.giveItem({name = "sbqMysteriousPotion", parameters = data})
		item.consume(1)
	end
end

function dartGunData()
	return { funcName = "transform", data = {species= humanoid.species()}}
end
