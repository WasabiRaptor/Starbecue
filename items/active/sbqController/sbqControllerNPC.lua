sbq = {}
function init()
	activeItem.setHoldingItem(false)
	storage = storage or {}
	message.setHandler("sbqControllerRotation", function(_, _, enabled)
		sbq.rotationEnabled = enabled
		activeItem.setHoldingItem(enabled)
		if not enabled then
			activeItem.setFacingDirection(0)
		end
	end)
end

function update()
	if sbq.rotationEnabled then
		sbq.aimAngle, sbq.aimDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
		activeItem.setArmAngle(sbq.aimAngle)
		activeItem.setFacingDirection(sbq.aimDirection)
	end
end

function uninit()
	if world.entityExists(entity.id()) then
		return world.callScriptedEntity(entity.id(),"sbq.tryAction", "grabRelease")
	end
end
