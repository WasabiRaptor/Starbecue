---@diagnostic disable: undefined-global
local old = {
	init = init,
	update = update,
	teleportOut = teleportOut
}
sbq = {}
require("/scripts/any/SBQ_RPC_handling.lua")
function init()
	old.init()
	message.setHandler("sbqLight", function (_,_, light)
		player.setProperty("sbqLight", light)
		if light == nil then
			localAnimator.clearLightSources()
		end
	end)
end

function update(dt)
	old.update(dt)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
	sbq.checkTimers(dt)
	local light = player.getProperty( "sbqLight" )
	if light ~= nil then
		localAnimator.clearLightSources()
		localAnimator.addLightSource(light)
	end
end

function teleportOut()
	old.teleportOut()
	local occupantData = status.statusProperty("sbqOccupantData")
	if not (occupantData.playerPred or occupantData.crewPred) then
		status.setStatusProperty("sbqOccupantData", nil)
		status.clearPersistentEffects("sbqMissingPred")
	end
end
