---@diagnostic disable: undefined-global
local old = {
	init = init,
	update = update
}
sbq = {}
require("/scripts/SBQ_RPC_handling.lua")
require("/scripts/rect.lua")
require("/scripts/SBQ_humanoid.lua")

function init()
	old.init()

	message.setHandler("sbqMysteriousPotionTF", function (_,_, data, duration)
		sbq.doMysteriousTF(data)
	end)
	message.setHandler("sbqEndMysteriousPotionTF", function (_,_)
		sbq.endMysteriousTF()
	end)

	message.setHandler("sbqLight", function (_,_, light)
		player.setProperty("sbqLight", light)
		if light == nil then
			localAnimator.clearLightSources()
		end
	end)
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
			status.setStatusProperty("sbqCurrentData", nil)
		end)
	end)
	message.setHandler("sbqIsPredEnabled", function(_,_, voreType)
		local settings = (player.getProperty("sbqSettings") or {}).global or {}
		local type = player.getProperty("sbqType")
		return {enabled = settings[voreType.."Pred"], unwilling = settings[voreType.."PredUnwilling"] and settings.forcefulPrey, size = sbq.calcSize(), type = type}
	end)

end

function update(dt)
	sbq.checkTimers(dt)
	old.update(dt)
	local light = player.getProperty( "sbqLight" )
	if light ~= nil then
		localAnimator.clearLightSources()
		localAnimator.addLightSource(light)
	end
end

function sbq.calcSize()
	local boundRectSize = rect.size(mcontroller.boundBox())
	local size = math.sqrt(boundRectSize[1] * boundRectSize[2]) / root.assetJson("/sbqGeneral.config:size") -- size is being based on the player, 1 prey would be math.sqrt(1.4x3.72) as that is the bound rect of the humanoid hitbox
	status.setStatusProperty("sbqSize", size)
	return size
end
