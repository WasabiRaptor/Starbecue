function init()
	activeItem.setArmAngle(-math.pi/4)
	animator.rotateTransformationGroup("potion", math.pi/4)
end

function update(dt, fireMode, shiftHeld)
	if fireMode == "primary" and not activeItem.callOtherHandScript("isDartGun") then
		local data = {}
		local speciesAnimOverrideData = status.statusProperty("speciesAnimOverrideData") or {}
		data.species = speciesAnimOverrideData.species or world.entitySpecies(entity.id())
		data.potionPath = "/items/active/sbqTransformation/sbqSpeciesPotion/"
		data.rarity = "rare"
		player.giveItem({name = "sbqMysteriousPotion", parameters = data})
		item.consume(1)
	end
end

function dartGunData()
	local data = {}
	local speciesAnimOverrideData = status.statusProperty("speciesAnimOverrideData") or {}
	data.species = speciesAnimOverrideData.species or world.entitySpecies(entity.id())

	return { funcName = "transform", data = data}
end
