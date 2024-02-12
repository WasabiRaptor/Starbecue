local oldinit = init
local _update = update
sbq = {}

local _monster_setDamageTeam
function capture_monster_setDamageTeam(data)
	status.setStatusProperty("sbqOriginalDamageTeam", data)
	local type = status.statusProperty("sbqType")
	if type ~= "prey" then
		_monster_setDamageTeam(data)
	end
end

require("/scripts/any/SBQ_RPC_handling.lua")

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

	if self.behavior then
		local behavior = {}
		local _behavior = self.behavior
		setmetatable(behavior, {__index = _behavior})
		function behavior:run(...)
			local loungeAnchor = world.entityLoungingIn(entity.id())
			if (not loungeAnchor) or (loungeAnchor and loungeAnchor.dismountable) then
				return _behavior:run(...)
			else
				sbq.struggleBehavior(...)
			end
		end
		-- the metatable __index on this table seems to not get this so I have to define it
		function behavior:blackboard(...)
			return _behavior:blackboard(...)
		end
		self.behavior = behavior
	end
end

function sbq.struggleBehavior(dt)
	-- TODO
end

function update(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)

	_update(dt)
end
