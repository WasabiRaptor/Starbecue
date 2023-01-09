require("/scripts/pathing.lua")

function sbq.updatePathfinding(dt)
	if sbq.isNested then return end
	local driver = sbq.driver
	if sbq.driving and (driver ~= nil) and (world.entityType(driver) == "player") then return end
	--[[
	if a monster or an NPC or whatever ever ends up in a driver seat, possibly from setting them as a smol species,
	then we do want it to use whateve pathfinding it has so it doesn't just sit there doing nothing
	]]
	if sbq.pathMover == nil then
		sbq.pathMover = PathMover:new({ ---@diagnostic disable-line: undefined-global
			-- pathOptions = { -- all defaults here will be filled in automatically
			-- 	returnBest = false,
			-- 	mustEndOnGround = mcontroller.baseParameters().gravityEnabled,
			-- 	maxDistance = 200,
			-- 	swimCost = 5,
			-- 	dropCost = 2,
			-- 	boundBox = mcontroller.boundBox(),
			-- 	droppingBoundBox = padBoundBox(0.2, 0), --Wider bound box for dropping
			-- 	standingBoundBox = padBoundBox(-0.7, 0), --Thinner bound box for standing and landing
			-- 	smallJumpMultiplier = 1 / math.sqrt(2), -- 0.5 multiplier to jump height
			-- 	jumpDropXMultiplier = 1,
			-- 	enableWalkSpeedJumps = true,
			-- 	enableVerticalJumpAirControl = false,
			-- 	maxFScore = 400,
			-- 	maxNodesToSearch = 70000,
			-- 	maxLandingVelocity = -10.0,
			-- 	liquidJumpCost = 15
			-- },
			-- run = false,
			movementParameters = sbq.movementParams
		})
	end
	if state[sbq.state].pathfinding ~= nil then
		state[sbq.state].pathfinding(dt)
	else
		sbq.pathfinding(dt)
	end
	if sbq.isPathfinding then
		sbq.pathingState = sbq.pathMover:move(sbq.pathingTarget, dt)
		sb.setLogMap("pathingState", tostring(sbq.pathingState))
		if sbq.pathingState == "pathfinding" then
			sbq.activeControls = {} -- don't keep moving while deciding what to do
		end
		if sbq.pathingState == true then -- arrived at target
			sbq.stopPathing()
		end
	end
end

sbq.pathMover = nil
sbq.pathingTarget = nil

function sbq.controlPathMove(target, run, options)
	sbq.pathMover.options.run = run
	sbq.pathMover.finder.options = sb.jsonMerge(sbq.pathMover.finder.options, options or {})
	return sbq.pathTo(target)
end

function sbq.pathTo(target, options)
	options = sb.jsonMerge({
		maximumCorrection = math.abs(mcontroller.localBoundBox()[3] - mcontroller.localBoundBox()[1]),
		flying = false,
	}, options)
	if not target then return false end
	sbq.isPathfinding = true
	target = world.resolvePolyCollision(
		sbq.movementParams.collisionPoly, target,
		options.maximumCorrection
	)
	if not target then return false end
	if not options.flying then
		target = findGroundPosition(
			target, -- target
			-10, 10 -- min/max height
		) or target
	end
	if not target then return false end
	sbq.pathingTarget = target or mcontroller.position()
end

function sbq.stopPathing()
	sbq.isPathfinding = false
	sbq.activeControls = {}
	sbq.pathMover.downHoldTimer2 = nil
end

-- extend mcontroller to add actor methods
mcontroller_extensions = {}

sbq.activeControls = {}
function sbq.doControls()
	-- moveDirection, run, and down are handled in sbq_driving in relevant locations
	if sbq.activeControls.fly then
		mcontroller.setVelocty(sbq.activeControls.fly) -- this might be wrong?? no clue
	end
	if sbq.activeControls.targetVelocity then
		mcontroller.approachVelocity(sbq.activeControls.targetVelocity, sbq.activeControls.maxControlForce)
	end
	if sbq.activeControls.targetXVelocity then
		mcontroller.approachXVelocity(sbq.activeControls.targetXVelocity, sbq.activeControls.maxControlForce)
	end
	if sbq.activeControls.targetYVelocity then
		mcontroller.approachYVelocity(sbq.activeControls.targetYVelocity, sbq.activeControls.maxControlForce)
	end
end

function mcontroller_extensions.clearControls() -- not used by pathing.lua? good to have anyway
	sbq.activeControls = {}
end

function mcontroller_extensions.controlMove(direction, run)
	-- Controls movement in a direction.
	-- Each control replaces the previous one.
	sbq.activeControls = {
		moveDirection = direction,
		run = run
	}
end

function mcontroller_extensions.baseParameters()
	-- Returns the base movement parameters.
	return sbq.movementParams
end

function mcontroller_extensions.boundBox()
	-- Returns a rect containing the entire collision of the movement controller, in local coordinates.
	return mcontroller.localBoundBox()
end

function mcontroller_extensions.facingDirection()
	-- Returns the facing direction. -1 for left, 1 for right.
	return sbq.direction
end

function mcontroller_extensions.movingDirection()
	-- Returns the direction that the actor movement controller is currently moving in. -1 for left, 1 for right.
	local vel = mcontroller.xVelocity()
	return (vel > 0 and 1) or (vel == 0 and 0) or -1
end

function mcontroller_extensions.controlParameters(parameters)
	-- Changes movement parameters. Parameters are merged into the base parameters.
	-- Each control is merged into the previous one.
	sbq.activeControls.parameters = sb.jsonMerge(sbq.activeControls.parameters, parameters)
	sbq.setMovementParams(sbq.movementParamsName)
end

function mcontroller_extensions.controlDown()
	-- Controls dropping through platforms.
	sbq.activeControls.drop = true -- no override
	if sbq.pathMover.downHoldTimer2 == nil then
		sbq.pathMover.downHoldTimer2 = 0.1 -- hack because downHoldTimer gets reset too soon
	end
end

function mcontroller_extensions.controlApproachVelocity(targetVelocity, maxControlForce)
	-- Approaches the targetVelocity using the force provided.
	-- If the current velocity is higher than the provided targetVelocity,
	-- the targetVelocity will still be approached, effectively slowing down the entity.
	-- Each control overrides the previous one.
	sbq.activeControls = {
		targetVelocity = targetVelocity,
		maxControlForce = maxControlForce
	}
end

function mcontroller_extensions.controlApproachXVelocity(targetVelocity, maxControlForce)
	-- Approaches an X velocity. Same as using approachVelocityAlongAngle with angle 0.
	-- Each control overrides the previous one.
	sbq.activeControls = {
		targetXVelocity = targetVelocity,
		maxControlForce = maxControlForce
	}
end

function mcontroller_extensions.controlApproachYVelocity(targetVelocity, maxControlForce)
	-- Approaches a Y velocity. Same as using approachVelocityAlongAngle with angle (Pi / 2).
	-- Each control overrides the previous one.
	sbq.activeControls = {
		targetYVelocity = targetVelocity,
		maxControlForce = maxControlForce
	}
end

function mcontroller_extensions.liquidMovement()
	-- Returns whether the controller is currently in liquid movement mode.
	return sbq.underWater()
end

function mcontroller_extensions.controlFly(velocity)
	-- Controls flying in the specified velocity.
	-- Each control overrides the previous one.
	sbq.activeControls = {
		fly = velocity
	}
end

-- technically not part of mcontroller but it's relevant the same way
status = {}
function status.stat(stat)
	-- Returns the value for the specified stat. Defaults to 0.0 if the stat does not exist.
	-- (we only need this to support "jumpModifier")
	if stat == "jumpModifier" then
		return 0.45 -- this'll probably change later but I don't think anything affects this yet
	else
		return 0.0
	end
end
