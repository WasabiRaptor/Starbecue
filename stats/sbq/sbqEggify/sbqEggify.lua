local replaceColors = {}
function init()
	local preyEnabled = sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], sb.jsonMerge((status.statusProperty("sbqPreyEnabled") or {}), (status.statusProperty("sbqOverridePreyEnabled")or {})))
	local currentData = status.statusProperty("sbqCurrentData") or {}
	local type = status.statusProperty("sbqType")

	if (not preyEnabled.eggAllow) or type == "prey" then
		return
	end

	local eggData = root.assetJson("/vehicles/sbq/sbqEgg/sbqEgg.vehicle")
	replaceColors = {
		math.random(1, #eggData.sbqData.replaceColors[1] - 1),
		math.random(1, #eggData.sbqData.replaceColors[2] - 1)
	}

	world.spawnProjectile("sbqWarpInEffect", mcontroller.position(), entity.id(), { 0, 0 }, true)
	eggSpawned = world.spawnVehicle("sbqEgg", mcontroller.position(), { driver = entity.id(), direction = mcontroller.facingDirection(), settings = { replaceColors = replaceColors, escapeDifficulty = -2 } })
end
