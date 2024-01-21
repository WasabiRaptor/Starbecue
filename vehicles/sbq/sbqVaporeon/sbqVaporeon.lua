
require("/vehicles/sbq/sbq_main.lua")

state = {
	stand = {},
	sit = {},
	lay = {},
	sleep = {},
	back = {},
	hug = {},
	smol = {},
	chonk_ball = {}
}

-------------------------------------------------------------------------------

function sbq.init()
	getColors()
end

function getColors()
	if not sbq.settings.firstLoadDone then
		sb.logInfo("rolling for shiny...")
		sbq.settings.shinyRoll = math.random(1, 4096)
		local presetName = "kantonian"

		if sbq.settings.shinyRoll == 1 then
			sbq.settings.shiny = true
			presetName = presetName.."Shiny"
			sb.logInfo("woah a shiny pokemon!")
		else
			sb.logInfo("meh... not a shiny...")
		end

		sbq.settings = sb.jsonMerge(sbq.settings, sbq.sbqData.customizePresets[presetName])

		sbq.settings.firstLoadDone = true
		sbq.setColorReplaceDirectives()
		sbq.setSkinPartTags()
		world.sendEntityMessage(sbq.spawner, "sbqSaveSettings", sbq.settings, "sbqVaporeon")
	end
end

-------------------------------------------------------------------------------

function sbq.update(dt)
	sbq.whenFalling()
	sbq.changeSize()
end

function sbq.whenFalling()
	if sbq.state == "stand" or sbq.state == "smol" or sbq.state == "chonk_ball" then return end
	if not mcontroller.onGround() and sbq.totalTimeAlive > 1 then
		sbq.setState( "stand" )
		sbq.doAnims( sbq.stateconfig[sbq.state].control.animations.fall )
		sbq.movement.falling = true
		sbq.uneat(sbq.findFirstOccupantIdForLocation("hug"))
	end
end

function sbq.changeSize()
	if sbq.tapControl( sbq.driverSeat, "special1" ) and sbq.totalTimeAlive > 0.5 and not sbq.transitionLock then
		sbq.uneat(sbq.findFirstOccupantIdForLocation("hug"))

		local changeSize = "smol"
		if sbq.occupantsVisualSize.belly >= 2 then
			changeSize = "chonk_ball"
		end
		if sbq.state == changeSize then
			changeSize = "stand"
		end
		sbq.warpInEffect(); --Play warp in effect
		sbq.setState( changeSize )
	end
end

function analEscape(args, tconfig)
	return sbq.doEscape(args, {}, {}, tconfig.voreType )
end

function eatAnal(args, tconfig)
	return sbq.doVore(args, "belly", {}, "swallow", tconfig.voreType)
end

function checkAnalVore()
	return sbq.checkEatPosition(sbq.localToGlobal({-5, -3}), 3, "belly", "eatAnal")
end

-------------------------------------------------------------------------------

function state.stand.begin()
	sbq.setMovementParams( "default" )
	sbq.resolvePosition(5)
end

function state.stand.eat( args, tconfig )
	if not mcontroller.onGround() or sbq.movement.falling then return false end
	return sbq.doVore(args, "belly", {}, "swallow", tconfig.voreType)
end

function state.stand.letout( args, tconfig )
	if not mcontroller.onGround() or sbq.movement.falling then return false end
	return sbq.doEscape(args, {wet = { power = 5, source = entity.id()}}, {}, tconfig.voreType )
end

function state.stand.vore()
	return sbq.checkEatPosition(sbq.localToGlobal( sbq.stateconfig.stand.actions.oralVore.position ), 2, "belly", "oralVore")
end

-------------------------------------------------------------------------------

function state.sit.pin( args )
	local pinnable = { args.id }
	-- if not interact target or target isn't in front
	if args.id == nil or sbq.globalToLocal( world.entityPosition( args.id ) )[1] < 3 then
		local pinbounds = {
			sbq.localToGlobal({2, -4}),
			sbq.localToGlobal({4, -2})
		}
		pinnable = world.playerQuery( pinbounds[1], pinbounds[2] )
		if #pinnable == 0 and sbq.driving then
			pinnable = world.npcQuery( pinbounds[1], pinbounds[2] )
		end
	end
	if #pinnable >= 1 then
		sbq.addRPC(world.sendEntityMessage(pinnable[1], "sbqIsPreyEnabled", "held"), function(enabled)
			if enabled and enabled.enabled then
				sbq.eat( { id = pinnable[1], size = enabled.size or 1}, "held", "hug" )
			end
			sbq.doTransition("lay")
		end)
	else
		sbq.doTransition("lay")
	end
	return true
end

function state.sit.grabPin()
	local target = sbq.checkValidAim(sbq.driverSeat, 3)
	if target ~= nil and sbq.globalToLocal( world.entityPosition( target ) )[1] < 3 then
		return state.sit.pin({ id = target })
	end
end

-------------------------------------------------------------------------------

function absorb(args)
	args.id = sbq.findFirstOccupantIdForLocation("hug")
	if not args.id then return false end
	animator.playSound( "slurp" )
	return true, function() sbq.moveOccupantLocation(args, "belly") end
end

function state.lay.update()
	if sbq.driving then
		if sbq.pressControl( sbq.driverSeat, "Jump" ) then
			sbq.doTransition( "absorb" )
		end
		if sbq.pressControl( sbq.driverSeat, "PrimaryFire" ) or sbq.pressControl( sbq.driverSeat, "AltFire" )then
			sbq.doTransition( "lick" )
		end
	end
end

state.lay.absorb = absorb

function state.lay.unpin(args)
	args.id = sbq.findFirstOccupantIdForLocation("hug")
	local returnval = {}
	returnval[1], returnval[2], returnval[3] = sbq.doEscape(args, {}, {})
	return true, returnval[2], returnval[3]
end

-------------------------------------------------------------------------------

function state.sleep.update()
	if sbq.driving and sbq.pressControl( sbq.driverSeat, "Jump" ) then
		sbq.doTransition( "absorb" )
	end
end

state.sleep.absorb = absorb

-------------------------------------------------------------------------------

function state.back.update()
	-- simulate npc interaction when nearby
	if sbq.occupants.total == 0 and not sbq.isObject then
		if sbq.randomChance(1) then -- every frame, we don't want it too often
			local npcs = world.npcQuery(mcontroller.position(), 4)
			if npcs[1] ~= nil then
				sbq.doTransition( "bed", {id=npcs[1]} )
			end
		end
	end
end

function state.back.bed( args )
	return sbq.eat( args, "held", "hug" )
end

function state.back.unbed(args)
	return sbq.uneat(sbq.findFirstOccupantIdForLocation("hug"))
end

state.back.analEscape = analEscape
state.back.eatAnal = eatAnal
state.back.analVore = checkAnalVore
state.back.vore = checkAnalVore

function state.back.grab()
	if sbq.findFirstOccupantIdForLocation("hug") == nil then
		sbq.checkEatPosition(sbq.localToGlobal({1, -2}), 3, "hug", "bed" )
	end
	sbq.doTransition("down")
end

-------------------------------------------------------------------------------

function state.hug.update()
	if sbq.pressControl( sbq.driverSeat, "Jump" ) then
		sbq.doTransition( "absorb" )
	end
end

state.hug.absorb = absorb
state.hug.analEscape = analEscape
state.hug.eatAnal = eatAnal

state.hug.analVore = checkAnalVore
state.hug.vore = checkAnalVore

function state.hug.grab()
	sbq.doTransition("up")
	sbq.doTransition("unhug")
end

-------------------------------------------------------------------------------

function state.smol.begin()
	sbq.setMovementParams( "smol" )
	sbq.resolvePosition(3)
end

-------------------------------------------------------------------------------

function state.chonk_ball.update(dt)
	roll_chonk_ball(dt)
	sbq.movement.aimingLock = 0.1
	if sbq.occupantsVisualSize.belly < 2 and not sbq.transitionLock then
		sbq.warpInEffect();

		sbq.setState( "smol" )
	end
end

function state.chonk_ball.begin()
	sbq.setPartTag( "global","rotationFlip", sbq.direction * -1)
	sbq.setMovementParams( "chonk_ball" )
	sbq.resolvePosition(3)
	self.ballFrames = sbq.stateconfig.chonk_ball.control.ballFrames
	self.ballRadius = sbq.stateconfig.chonk_ball.control.ballRadius
	self.angularVelocity = 0
	self.angle = 0
end

function state.chonk_ball.nudge(args)
	if args.direction ~= nil then
		local dx = 0
		if args.direction == "front" then
			dx = 1
		elseif args.direction == "back" then
			dx = -1
		end
		dx = dx * sbq.direction
		if math.abs(mcontroller.xVelocity()) <= sbq.movementParams.walkSpeed * 1.5 then
			mcontroller.force({sbq.movementParams.groundForce * 1.5 * dx, 0})
		end
	end
end

function roll_chonk_ball(dt)
	updateAngularVelocity(dt)
	updateRotationFrame(dt)
	self.lastPosition = mcontroller.position()
end

--these are taken from /tech/distortionsphere/distortionsphere.lua
require "/scripts/vec2.lua"

function updateRotationFrame(dt)
	self.angle = math.fmod(math.pi * 2 + self.angle + self.angularVelocity * dt, math.pi * 2)

	-- Rotation frames for the ball are given as one *half* rotation so two
	-- full cycles of each of the ball frames completes a total rotation.
	local rotationFrame = math.floor(self.angle / math.pi * self.ballFrames) % self.ballFrames
	sbq.setPartTag( "global","rotationFrame", rotationFrame)
end

function updateAngularVelocity(dt)
	if mcontroller.onGround() then
		-- If we are on the ground, assume we are rolling without slipping to
		-- determine the angular velocity
		local positionDiff = world.distance(self.lastPosition or mcontroller.position(), mcontroller.position())
		self.angularVelocity = -vec2.mag(positionDiff) / dt / self.ballRadius

		if positionDiff[1] > 0 then
			self.angularVelocity = -self.angularVelocity
		end
	end
end
