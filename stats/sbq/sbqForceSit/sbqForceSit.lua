function init()
end

local lastPosition
local lastDt
function update(dt)
	local data = status.statusProperty("sbqForceSitData")
	local sbqCurrentData = status.statusProperty("sbqCurrentData") or {}
	lastPosition = mcontroller.position()
	lastDt = dt
	if data ~= nil and world.entityExists(data.source) and (data.source ~= entity.id()) and (world.entityType(data.source) == "vehicle") then

		mcontroller.setRotation(data.rotation or 0)
		mcontroller.controlParameters({ collisionPoly = sbqCurrentData.hitbox, collisionEnabled = false, frictionEnabled = false, gravityEnabled = false })
		mcontroller.controlModifiers({movementSuppressed = true, facingSuppressed = true, runningSuppressed = true, jumpingSuppressed = true})

		local anchorEntity, seatindex = mcontroller.anchorState()

		if (anchorEntity ~= data.source) and (seatindex ~= data.index) then
			mcontroller.resetAnchorState()
			if not pcall(mcontroller.setAnchorState, data.source, data.index ) then
			end
		end
	else
		effect.expire()
	end
end

function uninit()
	mcontroller.setRotation(0)
	local position = mcontroller.position()
	--mcontroller.setVelocity({(position[1]-lastPosition[1])/lastDt, (position[2]-lastPosition[2])/lastDt})
	mcontroller.resetAnchorState()
	status.setStatusProperty("sbqDontTouchDoors", false)
end
