local clicked
function update(dt, fireMode, shiftHeld, controls)

	if fireMode == "primary" and not clicked then
		clicked = true
		local preyEnabled = sb.jsonMerge(root.assetJson("/sbqGeneral.config").defaultPreyEnabled[world.entityType(entity.id())], status.statusProperty("sbqPreyEnabled") or {})
		if not (preyEnabled.eggAllow) then
			return
		end
		eggSpawned = world.spawnVehicle("sbqEgg", mcontroller.position(), { driver = player.id(), direction = mcontroller.facingDirection(), settings = storage.settings or { skinNames = { head = "plastic" }, scale = mcontroller.scale() } })
		item.consume(1)

	elseif fireMode == "none" then
		clicked = false
	end
end
