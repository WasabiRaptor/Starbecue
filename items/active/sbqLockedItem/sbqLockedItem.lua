function init()
    activeItem.setHoldingItem(false)

	local lockedItemList = player.getProperty("sbqLockedItems")
	for i, lockedItemData in pairs(lockedItemList or {}) do
		player.giveItem(lockedItemData)
	end
	player.setProperty("sbqLockedItems", {})

	for slotname, itemDescriptor in pairs(storage.lockedEssentialItems or {}) do
		player.giveEssentialItem(slotname, itemDescriptor)
	end
end
