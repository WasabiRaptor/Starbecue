local oldinit = init
local _update = update
sbq = {}

local _monster_setDamageTeam
function capture_monster_setDamageTeam(data)
	status.setStatusProperty("sbqOriginalDamageTeam", data)
	if (status.statusProperty( "sbqCurrentData" ) or {}).type ~= "prey" then
		_monster_setDamageTeam(data)
	end
end

require("/scripts/SBQ_RPC_handling.lua")

function init()

	status.setStatusProperty( "sbqCurrentData", nil)

	message.setHandler("sbqPredatorDespawned", function(_, _, eaten, species, occupants)
		sbq.timer("sbqPredatorDespawned", 0.5, function()
			local sbqOriginalDamageTeam = status.statusProperty("sbqOriginalDamageTeam")
			if sbqOriginalDamageTeam then
				_monster_setDamageTeam(sbqOriginalDamageTeam)
			end
			status.setStatusProperty("sbqPreyList", nil)
			sbq.timer("sbqPredatorDespawned2", 5, function()
				if sbqOriginalDamageTeam then
					_monster_setDamageTeam(sbqOriginalDamageTeam)
				end
			end)

			status.setStatusProperty("sbqCurrentData", nil)
			if not eaten then
				local resolvePosition = world.resolvePolyCollision(mcontroller.collisionPoly(), mcontroller.position(), 5)
				if resolvePosition ~= nil then
					mcontroller.setPosition(resolvePosition)
				end
			end
		end)
	end)

	if type(_monster_setDamageTeam) ~= "function" then
		_monster_setDamageTeam = monster.setDamageTeam
		monster.setDamageTeam = capture_monster_setDamageTeam
	end

	message.setHandler("sbqMakeNonHostile", function(_,_)
		local damageTeam = entity.damageTeam()
		if (status.statusProperty("sbqOriginalDamageTeam") == nil) then
			status.setStatusProperty("sbqOriginalDamageTeam", damageTeam)
		end
		_monster_setDamageTeam({ type = "ghostly", team = damageTeam.team })
	end)

	status.clearPersistentEffects("digestImmunity")
	status.setPersistentEffects("digestImmunity", {"sbqDigestImmunity"})
	oldinit()
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)

	_update(dt)
end
