local pressed = true
local rpcSettings = "send"
local settings
local pred = "sbqAvian"

function update(args)
	if rpcSettings == "send" then
		rpcSettings = world.sendEntityMessage( entity.id(), "sbqLoadSettings")
	elseif rpcSettings ~= nil and rpcSettings:finished() then
		if rpcSettings:succeeded() then
			local result = rpcSettings:result()
			if result ~= nil then
				settings = result
			end
		else
			sb.logError( "Couldn't load SBQ debug settings." )
			sb.logError( rpcSettings:error() )
		end
		rpcSettings = nil
	end
	if args.moves["special1"] and not pressed then
		world.spawnVehicle( pred, mcontroller.position(), { driver = entity.id(), settings = sb.jsonMerge(settings[pred] or {}, settings.global or {}), direction = mcontroller.facingDirection(), scale = mcontroller.scale()  } )
	end
	pressed = args.moves["special1"]
end
