local replaceItems = {
	sbqPotionAvian = {name = "sbqMysteriousPotion", parameters = {identity = {species = "avian"}}},
	sbqPotionVaporeon = {name = "sbqMysteriousPotion", parameters = {identity = {species = "sbq/vaporeonGiant"}}},
	sbqPotionXeronious = {name = "sbqMysteriousPotion", parameters = {identity = {species = "sbq/Xeronious/Kaiju"}}},
	sbqConsumableZiellekPearl = {name = "sbqMysteriousPotion", parameters = {identity = {species = "sbq/LakotaAmitola/ziellekDragon"}}},
	sbqPotionSlime = { name = "sbqMysteriousPotion", parameters = { identity = { species = "sbq/slime" } } },

	sbqCoreVaporeon = {name = "sbqMysteriousPotion", parameters = {identity = {species = "sbq/vaporeonGiant"}}},
	sbqCoreXeronious = {name = "sbqMysteriousPotion", parameters = {identity = {species = "sbq/Xeronious/Kaiju"}}},

	sbqCoreCharem = {name = "dirtmaterial"},

}
function error(itemDescriptor)
	if itemDescriptor.name then
		if replaceItems[itemDescriptor.name] then
			itemDescriptor.parameters = {}
			return sb.jsonMerge(itemDescriptor, replaceItems[itemDescriptor.name])
		end
	end
	return itemDescriptor
end
