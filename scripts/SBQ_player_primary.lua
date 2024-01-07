require("/scripts/SBQ_everything_primary.lua")
require("/scripts/SBQ_humanoid.lua")
local old = {
	init = init,
	update = update
}
function init()
    old.init()
	message.setHandler("cleanAnimOverrideScriptItems", function(_,_)
		cleanAnimOverrideScriptItems()
	end)
end

function cleanAnimOverrideScriptItems()
	player.makeTechUnavailable("storeDirectivesEmpty")

	local lockedItemList = player.getProperty("sbqLockedItems")
	for i, lockedItemData in pairs(lockedItemList or {}) do
		player.giveItem(lockedItemData)
		table.remove(lockedItemList, i)
	end
	player.setProperty("sbqLockedItems", lockedItemList)

	local essentialItems = {"beamaxe", "wiretool", "painttool", "inspectiontool"}
	for _, slot in ipairs(essentialItems) do
		local item = player.essentialItem(slot)
		if item and item.parameters.itemHasOverrideLockScript then
			for slotname, itemDescriptor in pairs(item.scriptStorage.lockedEssentialItems or {}) do
				player.giveEssentialItem(slotname, itemDescriptor)
			end
		end
	end

	local hasOverrideItem = true
	while hasOverrideItem do
		item = player.getItemWithParameter("itemHasOverrideLockScript", true)
		if item then
			consumed = player.consumeItem(item, false, true)
			if consumed then
				consumed.parameters.scripts = nil
				consumed.parameters.animationScripts = nil
				consumed.parameters.itemHasOverrideLockScript = nil
				player.giveItem(consumed)
			end
		else
			hasOverrideItem = false
		end
	end
end
