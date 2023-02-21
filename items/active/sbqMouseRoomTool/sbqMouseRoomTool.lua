
sbq = {}

require("/scripts/SBQ_RPC_handling.lua")

function init()
	activeItem.setHoldingItem(false)
end

local clicked
function update(dt, fireMode, shiftHeld, controls)
	if fireMode == "primary" and not clicked then
		clicked = true
		local object = world.objectAt(activeItem.ownerAimPosition())
		if object then
			if not world.isTileProtected(world.entityPosition(object)) then
				if world.entityName(object) == "sbqMouseHole" then
					player.interact("ScriptPane",
						{ data = world.getObjectParameter(object, "savedData"), gui = {}, scripts = { "/metagui/sbq/build.lua" },
							ui = "starbecue:mouseHoleTool" }, object)
				elseif world.entityName(object) == "sbqMouseRoom" then
					player.interact("ScriptPane",
						{ data = world.getObjectParameter(object, "savedData"), gui = {}, scripts = { "/metagui/sbq/build.lua" },
							ui = "starbecue:mouseRoomTool" }, object)
				end
			end
		end
	elseif fireMode == "none" then
		clicked = false
	end
end
