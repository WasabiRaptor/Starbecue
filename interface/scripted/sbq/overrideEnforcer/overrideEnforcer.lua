storage = _ENV.metagui.inputData or {}
if not storage.ownerUUID then
	storage.ownerUUID = player.uniqueId()
	world.sendEntityMessage(pane.sourceEntity(), "sbqSetOwner", player.uniqueId())
elseif (storage.ownerUUID ~= player.uniqueId()) and not player.isAdmin() then
	sbq.playErrorSound()
	pane.dismiss()
	return
end

-- actually build and make the menu functional

function _ENV.breakObject:onClick()
	world.sendEntityMessage(pane.sourceEntity(), "sbqSmash")
end
