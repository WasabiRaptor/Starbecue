local old = {
	init = init,
	update = update
}
sbq = {}
require("/scripts/SBQ_everything_primary.lua")
require("/scripts/SBQ_RPC_handling.lua")

function init()
	old.init()
	sbq.everything_primary()

	message.setHandler("sbqPredatorDespawned", function(_, _, eaten, species, occupants)
		sbq.timer("sbqPredatorDespawned", 0.5, function ()
			status.setStatusProperty("sbqPreyList", nil)
			world.sendEntityMessage(player.id(), "sbqRefreshSettings", player.getProperty( "sbqSettings") or {} )
			world.sendEntityMessage(player.id(), "sbqLight")

			if not eaten then
				local resolvePosition = world.resolvePolyCollision(mcontroller.collisionPoly(), mcontroller.position(), 5)
				if resolvePosition ~= nil then
					mcontroller.setPosition(resolvePosition)
				end

				for i, effect in ipairs(root.assetJson("/sbqGeneral.config").predStatusEffects) do
					status.removeEphemeralEffect(effect)
				end
				if species == "sbqOccupantHolder" and occupants == 0 and not (status.statusProperty("speciesAnimOverrideData") or {}).permanent then
					status.clearPersistentEffects("speciesAnimOverride")
				end
			end

			player.setProperty( "sbqCurrentData", nil)
			status.setStatusProperty( "sbqCurrentData", nil)
		end)
	end)
end

function update(dt)
	sbq.checkTimers(dt)
	old.update(dt)
end
