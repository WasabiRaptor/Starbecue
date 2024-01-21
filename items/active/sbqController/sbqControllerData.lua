
local oldinit = init
function init()
	if oldinit ~= nil then oldinit() end
	activeItem.setInstanceValue("itemHasSbqControllerScript", true)
	storage.seatdata = {}
end

local oldupdate = update
function update(dt, fireMode, shiftHeld, controls)
	if oldupdate ~= nil then oldupdate(dt, fireMode, shiftHeld, controls) end
	storage.seatdata.mass = mcontroller.mass()
	storage.seatdata.powerMultiplier = status.stat("powerMultiplier")
	storage.seatdata.head = player.equippedItem("head") or false
	storage.seatdata.chest = player.equippedItem("chest") or false
	storage.seatdata.legs = player.equippedItem("legs") or false
	storage.seatdata.back = player.equippedItem("back") or false
	storage.seatdata.headCosmetic = player.equippedItem("headCosmetic") or false
	storage.seatdata.chestCosmetic = player.equippedItem("chestCosmetic") or false
	storage.seatdata.legsCosmetic = player.equippedItem("legsCosmetic") or false
	storage.seatdata.backCosmetic = player.equippedItem("backCosmetic") or false
end
