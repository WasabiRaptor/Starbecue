---@diagnostic disable: undefined-global
sbq = {}
require("/scripts/SBQ_RPC_handling.lua")
require("/scripts/rect.lua")
require("/scripts/SBQ_humanoidAnimator.lua")
require("/scripts/SBQ_vore_main.lua")

function init()
	storage = storage or {}
    sbq.config = root.assetJson("/sbq.config")
	storage.sbqSettings = storage.sbqSettings or player.getProperty("sbqSettingsStorage")
	sbq.init()
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

	sbq.timer("spawn", 0, function()
		local current = player.getProperty("sbqCurrentData") or {}
		if current.species then
			world.spawnVehicle(current.species, entity.position(), {
				driver = player.id(), layer = current.layer, startState = current.state,
				settings = current.settings, scale = mcontroller.scale()
			})
		elseif player.getProperty("sbqType") == "prey" then
			for i, effect in ipairs(root.assetJson("/sbqGeneral.config").predStatusEffects) do
				status.removeEphemeralEffect(effect)
			end
		end
		player.setProperty("sbqCurrentData", nil) -- after spawning the vehicle, clear it so it can set its own current data
	end)
end

function update(dt)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
    sbq.checkTimers(dt)
    sbq.scale = mcontroller.scale()
	sbq.facingDirection = mcontroller.facingDirection()
    sbq.facingRight = (sbq.facingDirection == 1)

	sbq.update(dt)
end

function sbq.calcSize()
	local boundRectSize = rect.size(mcontroller.boundBox())
	local size = math.sqrt(boundRectSize[1] * boundRectSize[2]) / root.assetJson("/sbqGeneral.config:size") -- size is being based on the player, 1 prey would be math.sqrt(1.4x3.72) as that is the bound rect of the humanoid hitbox
	status.setStatusProperty("sbqSize", size)
	return size
end

function uninit()
	player.setProperty("sbqSettingsStorage", storage.sbqSettings)
end
