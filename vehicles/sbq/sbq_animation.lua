
function sbq.updateAnims(dt)
	for statename, state in pairs(sbq.animStateData) do
		state.animationState.time = state.animationState.time + dt
		local ended, times, time = sbq.hasAnimEnded(statename)
		if (not ended) or (state.animationState.mode == "loop") then
			local frame = math.floor( time * state.animationState.speed )
			state.animationState.frame = frame + 1
			state.animationState.reverseFrame = math.abs(frame - state.animationState.frames)
			sbq.setPartTag("global", statename.."Frame", state.animationState.frame or 1 )
		end
	end

	for i = 0, sbq.occupantSlots do
		sbq.victimAnimUpdate(sbq.occupant[i].id)
		sbq.updateVisibilityAndSmolprey(i)
	end
	sbq.offsetAnimUpdate()
	sbq.rotationAnimUpdate()

	sbq.emoteCooldown =  math.max( 0, sbq.emoteCooldown - dt )

	for statename, state in pairs(sbq.animStateData) do
		local ended, times, time = sbq.hasAnimEnded(statename)
		if ended then
			sbq.endAnim(state, statename)
		end
		if ended and state.animationState.mode == "transition" then
			sbq.doAnim(statename, state.animationState.transition)
		end
	end
end

function sbq.endAnim(state, statename)
	for _, func in pairs(sbq.animFunctionQueue[statename]) do
		func()
	end
	sbq.animFunctionQueue[statename] = {}

	if (state.tag ~= nil) and state.tag.reset then
		if state.tag.part == "global" then
			sbq.setPartTag( "global", state.tag.name, "" )
		else
			sbq.setPartTag( state.tag.part, state.tag.name, "" )
		end
		state.tag = nil
	end
end

sbq.armRotation = {
	target = {0,0},
	enabledR = false,
	enabledL = false,
	groupsR = {},
	groupsL = {},
	occupantR = nil,
	occupantL = nil,
	backarmsAngle = 0,
	frontarmsAngle = 0,
	backarmsVelocity = 0,
	frontarmsVelocity = 0
}
function sbq.armRotationUpdate()
	sbq.setGrabTarget()

	if sbq.armRotation.enabledR or sbq.armRotation.enabledL then
		sbq.movement.aimingLock = 0.1
		local LR = "L"
		if sbq.direction > 0 then
			LR = "R"
		end

		sbq.faceDirection(sbq.armRotation["target"..LR][1]*sbq.direction)
	end
	if sbq.direction > 0 then
		sbq.rotateArm( sbq.armRotation.enabledL, "backarms", "L")
		sbq.rotateArm( sbq.armRotation.enabledR, "frontarms", "R")
	else
		sbq.rotateArm( sbq.armRotation.enabledR, "backarms", "R")
		sbq.rotateArm( sbq.armRotation.enabledL, "frontarms", "L")
	end
end

function sbq.rotateArm(enabled, arm, LR)
	if enabled and (sbq.stateconfig[sbq.state].rotationCenters or {})[arm] ~= nil then
		animator.setAnimationState(arm.."_rotationState", sbq.stateconfig[sbq.state].rotationArmState or "rotation", true )


		local occupantId = sbq.armRotation["occupant"..LR]
		local groups = sbq.armRotation["groups"..LR]

		local center = {(sbq.stateconfig[sbq.state].rotationCenters[arm][1] or 0) / 8, (sbq.stateconfig[sbq.state].rotationCenters[arm][2] or 0) / 8}
		local handOffset = {(sbq.stateconfig[sbq.state].handOffsets[arm][1] or 0) / 8, (sbq.stateconfig[sbq.state].handOffsets[arm][2] or 0) / 8}

		local target = sbq.armRotation["target"..LR] or {}
		if target ~= nil then
			local angle = math.atan((target[2] - center[2]), (target[1] - center[1]))

			sbq.armRotation[arm.."Velocity"] = (((angle - sbq.armRotation[arm.."Angle"]) / sbq.dt) * math.sqrt(handOffset[1]^2 + handOffset[2]^2))
			sbq.armRotation[arm.."Angle"] = angle
			sbq.armRotation["armAngle"..LR] = angle
		end

		sbq.resetTransformationGroup(arm.."rotation")
		sbq.rotateTransformationGroup(arm.."rotation", sbq.armRotation[arm.."Angle"], center)

		for i, group in ipairs(groups) do
			sbq.resetTransformationGroup(group)
			sbq.translateTransformationGroup(group, handOffset, true)
			sbq.rotateTransformationGroup(group, sbq.armRotation[arm.."Angle"], center)
		end

		if occupantId ~= nil and sbq.lounging[occupantId] ~= nil then
			local victimAnim = sbq.lounging[occupantId].victimAnim
---@diagnostic disable-next-line: param-type-mismatch
			victimAnim.last.x = math.cos(sbq.armRotation[arm.."Angle"]) * handOffset[1]
---@diagnostic disable-next-line: param-type-mismatch
			victimAnim.last.y = math.sin(sbq.armRotation[arm.."Angle"]) * handOffset[2]
		end

		sbq.setPartTag( arm, "armVisible", "?multiply=FFFFFF00" )
		sbq.setPartTag( arm.."_rotation", "armVisible", "" )
	else
		sbq.setPartTag( arm, "armVisible", "" )
		sbq.setPartTag( arm.."_rotation", "armVisible", "?multiply=FFFFFF00" )
	end
end

function sbq.setGrabTarget()
	local controls = sbq.seats[sbq.driverSeat].controls
	if sbq.driver and (not (((controls.primaryHandItem == "sbqController") or (controls.altHandItem == "sbqController"))
	or ((controls.primaryHandItem == nil) and (controls.altHandItem == nil))))
	then
		if sbq.armRotation.occupantL ~= nil or sbq.armRotation.occupantR ~= nil then
			sbq.grabbing = nil
			sbq.uneat(sbq.armRotation.occupantL)
			sbq.uneat(sbq.armRotation.occupantR)
		end
	end
	if sbq.justAte ~= nil and sbq.justAte == sbq.grabbing then
		sbq.wasEating = true
		sbq.armRotation.enabledL = true
		sbq.armRotation.enabledR = true
		sbq.armRotation.targetL = sbq.globalToLocal(world.entityPosition(sbq.justAte))
		sbq.armRotation.targetR = sbq.armRotation.targetL
		sbq.armRotation.groupsR = {}
		sbq.armRotation.groupsL = {}
		sbq.armRotation.occupantR = nil
		sbq.armRotation.occupantL = nil
	elseif sbq.wasEating then
		sbq.wasEating = nil
		sbq.grabbing = nil
	elseif sbq.grabbing ~= nil and sbq.entityLounging(sbq.grabbing) then
		sbq.armRotation.enabledL = true
		sbq.armRotation.enabledR = true
		sbq.armRotation.targetL = sbq.globalToLocal(sbq.seats[sbq.driverSeat].controls.aim)
		sbq.armRotation.targetR = sbq.armRotation.targetL
		sbq.armRotation.groupsR = {sbq.lounging[sbq.grabbing].seatname.."Position"}
		sbq.armRotation.groupsL = {sbq.lounging[sbq.grabbing].seatname.."Position"}
		sbq.armRotation.occupantR = sbq.grabbing
		sbq.armRotation.occupantL = sbq.grabbing
	else
		sbq.armRotation.enabledL = false
		sbq.armRotation.enabledR = false
		sbq.armRotation.groupsR = {}
		sbq.armRotation.groupsL = {}
		sbq.armRotation.occupantR = nil
		sbq.armRotation.occupantL = nil
	end
end


function sbq.updateVisibilityAndSmolprey(i)
	if sbq.isNested then return end
	if sbq.occupant[i].id == nil or not world.entityExists(sbq.occupant[i].id) then
		animator.setAnimationState( sbq.occupant[i].seatname.."State", "empty", true )
		return
	end
	if sbq.occupant[i].visible then
		if (sbq.occupant[i].species ~= nil) and (sbq.occupant[i].species ~= "sbqOccupantHolder") then
			vehicle.setLoungeDirectives(sbq.occupant[i].seatname, "crop;0;0;0;0")
			if sbq.occupant[i].smolPreyData.recieved then
				if sbq.occupant[i].smolPreyData.update then
					sbq.smolPreyAnimPath(sbq.occupant[i])
				end
				animator.setAnimationState( sbq.occupant[i].seatname.."State", "smol", true )
			end
		else
			local seatname = sbq.occupant[i].seatname
			vehicle.setLoungeDirectives(sbq.occupant[i].seatname, "scalenearest="..math.abs(sbq.occupant[i].victimAnim.last.xs)..";"..math.abs(sbq.occupant[i].victimAnim.last.ys))
		end
	else
		vehicle.setLoungeDirectives(sbq.occupant[i].seatname, "crop;0;0;0;0")
		animator.setAnimationState( sbq.occupant[i].seatname.."State", "empty", true )
	end
end

function sbq.smolPreyAnimPath(occupant)
	local seatname = occupant.seatname

	sbq.setSmolOccupantPart(seatname, "head", occupant.smolPreyData.images.head)
	sbq.setSmolOccupantPart(seatname, "head1", occupant.smolPreyData.images.head1)
	sbq.setSmolOccupantPart(seatname, "head2", occupant.smolPreyData.images.head2)
	sbq.setSmolOccupantPart(seatname, "head3", occupant.smolPreyData.images.head3)

	sbq.setSmolOccupantPart(seatname, "body", occupant.smolPreyData.images.body)
	sbq.setSmolOccupantPart(seatname, "belly", occupant.smolPreyData.images.belly)

	sbq.setSmolOccupantPart(seatname, "tail", occupant.smolPreyData.images.tail)

	sbq.setSmolOccupantPart(seatname, "cock", occupant.smolPreyData.images.cock)

	sbq.setSmolOccupantPart(seatname, "backlegs", occupant.smolPreyData.images.backlegs)
	sbq.setSmolOccupantPart(seatname, "frontlegs", occupant.smolPreyData.images.frontlegs)

	sbq.setSmolOccupantPart(seatname, "backarm", occupant.smolPreyData.images.backarms)
	sbq.setSmolOccupantPart(seatname, "frontarm", occupant.smolPreyData.images.frontarms)

	sbq.setSmolOccupantPart(seatname, "ballsBack", occupant.smolPreyData.images.ballsBack)
	sbq.setSmolOccupantPart(seatname, "ballsFront", occupant.smolPreyData.images.ballsFront)

	sbq.setSmolOccupantPart(seatname, "breastsBack", occupant.smolPreyData.images.breastsBack)
	sbq.setSmolOccupantPart(seatname, "breastsFront", occupant.smolPreyData.images.breastsFront)

	occupant.smolPreyData.update = false
end

function sbq.setSmolOccupantPart(seatname, part, path)
	if path then sbq.setPartTag(seatname..part, "smolpath", path) else sbq.setPartTag(seatname..part, "smolpath", "/empty_image.png") end
end

function sbq.victimAnimUpdate(eid)
	if eid == nil or not sbq.lounging[eid] then return end

	local victimAnim = sbq.lounging[eid].victimAnim
	if not victimAnim.enabled then
		local location = sbq.lounging[eid].location
		if victimAnim.location ~= location or victimAnim.state ~= sbq.state then
			if victimAnim.progress == nil or victimAnim.progress == 1 then
				victimAnim.progress = 0
			end
			victimAnim.location = location
			victimAnim.state = sbq.state
		end
		local seatname = sbq.lounging[eid].seatname
		local transformGroup = seatname.."Position"
		sbq.resetTransformationGroup(transformGroup)
		-- sbq.translateTransformationGroup(transformGroup, {0, -preyYOffset * 8}, true)

		local scale = {victimAnim.last.xs, victimAnim.last.ys}
		sbq.scaleTransformationGroup(transformGroup, scale)
		sbq.rotateTransformationGroup(transformGroup, (victimAnim.last.r * math.pi/180))

		local translation
		if sbq.stateconfig[sbq.state].locationCenters ~= nil and sbq.stateconfig[sbq.state].locationCenters[location] ~= nil
		and (victimAnim.progress < 1 )
		then
			victimAnim.progress = math.min(1, victimAnim.progress + sbq.dt)
			local progress = victimAnim.progress
			local center = sbq.stateconfig[sbq.state].locationCenters[location]
			translation = { (victimAnim.last.x + ((center[1] - victimAnim.last.x) * progress)), (victimAnim.last.y + ((center[2] - victimAnim.last.y) * progress)) }
			if progress == 1 then
				victimAnim.last.x = center[1]
				victimAnim.last.y = center[2]
			end
		else
			translation = {victimAnim.last.x, victimAnim.last.y}
		end
		sbq.translateTransformationGroup(transformGroup, translation)
		return
	end
	local statename = victimAnim.statename
	local ended, times, time = sbq.hasAnimEnded(statename)
	local anim = sbq.victimAnimations[victimAnim.anim] or {}
	if ended and not anim.loop then
		victimAnim.enabled = false
		time = sbq.animStateData[statename].animationState.cycle
		victimAnim.inside = anim.endInside
	end

	local seatname = sbq.lounging[eid].seatname
	local speed = sbq.animStateData[statename].animationState.speed
	local frame = sbq.animStateData[statename].animationState.frame -1
	local nextFrame = frame + 1
	local nextFrameIndex = nextFrame + 1

	if victimAnim.prevFrame ~= frame then
		if anim.frames ~= nil then
			for i = 1, #anim.frames do
				if (anim.frames[i] == frame) then
					victimAnim.prevFrame = frame
					victimAnim.prevIndex = i

					victimAnim.frame = anim.frames[i + 1] or frame + 1
					victimAnim.index = i + 1
				end
				if anim.loop and (i == #anim.frames) then
					victimAnim.prevFrame = frame
					victimAnim.prevIndex = i

					victimAnim.frame = 0
					victimAnim.index = 1
				end
			end
		else
			victimAnim.prevFrame = victimAnim.frame
			victimAnim.frame = nextFrame

			victimAnim.prevIndex = victimAnim.index
			victimAnim.index = nextFrameIndex
		end
	end

	sbq.lounging[eid].visible = (sbq.getPrevVictimAnimValue(victimAnim, "visible") == 1)
	local e = sbq.getVictimAnimValue(victimAnim, "e")
	if e then
		world.sendEntityMessage(eid, "applyStatusEffect", e, (victimAnim.frame - victimAnim.prevFrame) * (sbq.animStateData[statename].animationState.cycle / sbq.animStateData[statename].animationState.frames) + 0.01, entity.id())
	end
	local sitpos = sbq.getVictimAnimValue(victimAnim, "sitpos")
	if sitpos then
		vehicle.setLoungeOrientation(seatname, sitpos)
	end
	local emote = sbq.getVictimAnimValue(victimAnim, "emote")
	if emote then
		vehicle.setLoungeEmote(seatname, emote)
	end
	local dance = sbq.getVictimAnimValue(victimAnim, "dance")
	if dance then
		vehicle.setLoungeDance(seatname, dance)
	end
	local addEffects = sbq.getVictimAnimValue(victimAnim, "addEffects")
	if type(addEffects) == "table" then
		for effect, data in pairs(addEffects) do
			sbq.addStatusToList(eid, effect, data)
		end
	end
	local removeEffects = sbq.getVictimAnimValue(victimAnim, "removeEffects")
	if type(removeEffects) == "table" then
		for i, effect in ipairs(removeEffects) do
			sbq.removeStatusFromList(eid, effect)
		end
	end

	local currTime = time * speed
	local progress = (currTime - victimAnim.prevFrame)/(victimAnim.frame - victimAnim.prevFrame) * (victimAnim.interpMode or 1)
	if (victimAnim.frame - victimAnim.prevFrame) == 0 then
		progress = 0
	end
	local transformGroup = seatname.."Position"
	local scale = { sbq.getVictimAnimInterpolatedValue(victimAnim, "xs", progress), sbq.getVictimAnimInterpolatedValue(victimAnim, "ys", progress)}
	local rotation = sbq.getVictimAnimInterpolatedValue(victimAnim, "r", progress)
	local translation = { sbq.getVictimAnimInterpolatedValue(victimAnim, "x", progress), sbq.getVictimAnimInterpolatedValue(victimAnim, "y", progress)}

	--sb.setLogMap("-currTime", currTime)
	--sb.setLogMap("-progress", progress)
	--sb.setLogMap("-frame", victimAnim.frame)
	--sb.setLogMap("-Prevframe", victimAnim.prevFrame)

	sbq.resetTransformationGroup(transformGroup)
	--could probably use animator.transformTransformationGroup() and do everything below in one matrix but I don't know how those work exactly so
	-- sbq.translateTransformationGroup(transformGroup, {0, -preyYOffset * 8}, true)

	sbq.scaleTransformationGroup(transformGroup, scale)
	sbq.rotateTransformationGroup(transformGroup, (rotation * math.pi/180))
	sbq.translateTransformationGroup(transformGroup, translation)
end

function sbq.getVictimAnimInterpolatedValue(victimAnim, valName, progress)
	return (sbq.getPrevVictimAnimValue(victimAnim, valName) + (sbq.getNextVictimAnimValue(victimAnim, valName) - sbq.getPrevVictimAnimValue(victimAnim, valName)) * progress)
end

function sbq.getPrevVictimAnimValue(victimAnim, valName)
	if sbq.victimAnimations[victimAnim.anim] ~= nil and sbq.victimAnimations[victimAnim.anim][valName] ~= nil and sbq.victimAnimations[victimAnim.anim][valName][victimAnim.prevIndex] ~= nil then
		victimAnim.last[valName] = sbq.victimAnimations[victimAnim.anim][valName][victimAnim.prevIndex] or 0
	end
	return victimAnim.last[valName] or 0
end

function sbq.getVictimAnimValue(victimAnim, valName)
	if sbq.victimAnimations[victimAnim.anim] ~= nil and sbq.victimAnimations[victimAnim.anim][valName] ~= nil and
		sbq.victimAnimations[victimAnim.anim][valName][victimAnim.prevIndex] ~= nil
	then
		return sbq.victimAnimations[victimAnim.anim][valName][victimAnim.prevIndex]
	end
end

function sbq.getNextVictimAnimValue(victimAnim, valName)
	if sbq.victimAnimations[victimAnim.anim] ~= nil and sbq.victimAnimations[victimAnim.anim][valName] ~= nil and sbq.victimAnimations[victimAnim.anim][valName][victimAnim.index] ~= nil then
		return sbq.victimAnimations[victimAnim.anim][valName][victimAnim.index] or 0
	end
	return victimAnim.last[valName] or 0
end

local victimAnimArgs = {
	xs = 1,
	ys = 1,
	x = 0,
	y = 0,
	r = 0,
	sitpos = "stand",
	emote = "idle",
	dance = "none"
}

function sbq.doVictimAnim( occupantId, anim, statename )
	if not sbq.lounging[occupantId] then return end
	local last = sbq.lounging[occupantId].victimAnim.last or {}

	local victimAnim = sbq.victimAnimations[anim] or {}

	sbq.lounging[occupantId].victimAnim = {
		enabled = true,
		statename = statename,
		anim = anim,
		frame = (victimAnim.frames or {})[2] or 1,
		index = 2,
		prevFrame = 0,
		prevIndex = 1,

		last = last
	}
	if not last.inside then
		for arg, default in pairs(victimAnimArgs) do
			if sbq.victimAnimations[anim] ~= nil and sbq.victimAnimations[anim][arg] ~= nil then
				sbq.lounging[occupantId].victimAnim.last[arg] = sbq.victimAnimations[anim][arg][1]
			else
				sbq.lounging[occupantId].victimAnim.last[arg] = default
			end
		end
	end

	sbq.victimAnimUpdate(occupantId)
end

function sbq.offsetAnimUpdate()
	if sbq.offsets == nil or not sbq.offsets.enabled then return end
	local state = sbq.offsets.timing.."State"
	local ended, times, time = sbq.hasAnimEnded(state)
	if ended and not sbq.offsets.loop then sbq.offsets.enabled = false end
	local frame = sbq.animStateData[state].animationState.frame
	if sbq.offsets.reversible and sbq.movement.direction == -1 then
		frame = sbq.animStateData[state].animationState.reverseFrame
	end
	for _,r in ipairs(sbq.offsets.parts) do
		local x = r.x[ frame ] or r.x[#r.x] or 0
		local y = r.y[ frame ] or r.y[#r.y] or 0
		for i = 1, #r.groups do
			sbq.resetTransformationGroup( r.groups[i] )
			sbq.translateTransformationGroup( r.groups[i], { x / 8, y / 8 } )
		end
	end
end

function sbq.rotationAnimUpdate()
	if sbq.rotating == nil or not sbq.rotating.enabled then return end
	local state = sbq.rotating.timing.."State"
	local ended, times, time = sbq.hasAnimEnded(state)
	if ended and not sbq.rotating.loop then sbq.rotating.enabled = false end
	local speed = sbq.animStateData[state].animationState.speed
	local frame = sbq.animStateData[state].animationState.frame -1
	local index = frame + 1
	local nextFrame = frame + 1
	local nextIndex = index + 1

	if sbq.rotating.prevFrame ~= frame then
		if sbq.rotating.frames ~= nil then
			for i = 1, #sbq.rotating.frames do
				if (sbq.rotating.frames[i] == frame) then
					sbq.rotating.prevFrame = frame
					sbq.rotating.prevIndex = i

					sbq.rotating.frame = sbq.rotating.frames[i + 1] or frame + 1
					sbq.rotating.index = i + 1
				end
				if sbq.rotating.loop and (i == #sbq.rotating.frames) then
					sbq.rotating.prevFrame = frame
					sbq.rotating.prevIndex = i

					sbq.rotating.frame = 0
					sbq.rotating.index = 1
				end
			end
		else
			sbq.rotating.prevFrame = sbq.rotating.frame
			sbq.rotating.frame = nextFrame

			sbq.rotating.prevIndex = sbq.rotating.index
			sbq.rotating.index = nextIndex
		end
	end

	local currTime = time * speed
	local progress = (currTime - sbq.rotating.prevFrame)/(math.abs(sbq.rotating.frame - sbq.rotating.prevFrame))

	for _, r in ipairs(sbq.rotating.parts) do
		local previousRotation = r.rotation[sbq.rotating.prevIndex] or r.last
		local nextRotation = r.rotation[sbq.rotating.index] or previousRotation
		local rotation = previousRotation + (nextRotation - previousRotation) * progress
		r.last = previousRotation

		for _, group in ipairs(r.groups) do
			sbq.resetTransformationGroup( group )
			sbq.rotateTransformationGroup( group, (rotation * math.pi/180), r.center)
		end
	end
end

function sbq.queueAnimEndFunction(state, func, newPriority)
	if newPriority then
		sbq.animStateData[state].animationState.priority = newPriority
	end
	table.insert(sbq.animFunctionQueue[state], func)
end

function sbq.doAnim( state, anim, force)
	if not sbq.animStateData[state] then
		sbq.logError("Attempt to call invalid Anim State: "..tostring(state))
		return
	end
	if not sbq.animStateData[state].states[anim] then
		sbq.logError("Attempt to call invalid Anim State: "..tostring(state).."."..tostring(anim))
		return
	end

	local oldPriority = (sbq.animStateData[state].animationState or {}).priority or 0
	local newPriority = (sbq.animStateData[state].states[anim] or {}).priority or 0
	local isSame = sbq.animationIs( state, anim )
	local force = force
	local priorityHigher = ((newPriority >= oldPriority) or (newPriority == -1))
	if (not isSame and priorityHigher) or sbq.hasAnimEnded(state) or force then
		if isSame then
			local mode = sbq.animStateData[state].animationState.mode == "end"
			if mode == "end" then
				force = true
			elseif	mode == "loop" then
				return
			end
		end
		sbq.animStateData[state].animationState = sb.jsonMerge(sbq.animStateData[state].states[anim], {
			anim = anim,
			priority = newPriority,
			speed = sbq.animStateData[state].states[anim].frames / sbq.animStateData[state].states[anim].cycle,
			frame = 1,
			time = 0
        })
		sbq.setPartTag("global", state.."Frame", 1 )
		sbq.setPartTag("global", state.."Anim", sbq.animStateData[state].states[anim].animFrames or anim )

		animator.setAnimationState(state, sbq.animStateData[state].states[anim].baseAnim or anim, force)
	end
end

function sbq.doAnims( anims, force )
	for state,anim in pairs( anims or {} ) do
		if state == "offset" then
			sbq.offsetAnim( anim )
		elseif state == "rotate" then
			sbq.rotate( anim )
		elseif state == "tags" then
			sbq.setAnimTag( anim )
		elseif state == "priority" then
			sbq.changePriorityLength(anim)
		elseif state == "force" then
		else
			sbq.doAnim( state.."State", anim, force or anims.force)
		end
	end
end

function sbq.changePriorityLength(anim)
	for state, data in pairs(anim) do
		sbq.animStateData[state.."State"].animationState.priority = data[1] or sbq.animStateData[state.."State"].animationState.priority
		sbq.animStateData[state.."State"].animationState.cycle = data[2] or sbq.animStateData[state.."State"].animationState.cycle
	end
end

function sbq.setAnimTag(anim)
	for _,tag in ipairs(anim) do
		sbq.animStateData[tag.owner.."State"].tag = {
			part = tag.part,
			name = tag.name,
			reset = tag.reset or true
		}
		if tag.part == "global" then
			sbq.setPartTag( "global", tag.name, tag.value )
		else
			sbq.setPartTag( tag.part, tag.name, tag.value )
		end
	end
end

sbq.offsets = {enabled = false, parts = {}}
function sbq.offsetAnim( data )
	if data == sbq.offsets.data then
		if not sbq.offsets.enabled then sbq.offsets.enabled = true end
		return
	else
		for i, part in ipairs(sbq.offsets.parts) do
			for j, group in ipairs(part.groups) do
				sbq.resetTransformationGroup(group)
			end
		end
	end

	sbq.offsets = {
		enabled = data ~= nil,
		data = data,
		reversible = data.reversible,
		parts = {},
		loop = data.loop or false,
		timing = data.timing or "body"
	}
	local continue = false
	for _, part in ipairs(data.parts or {}) do
		table.insert(sbq.offsets.parts, {
			x = part.x or {0},
			y = part.y or {0},
			groups = part.groups or {"headbob"},
			})
		if (part.x and #part.x > 1) or (part.y and #part.y > 1) then
			continue = true
		end
	end
	sbq.offsetAnimUpdate()
	if not continue then
		sbq.offsets.enabled = false
	end
end

sbq.rotating = {enabled = false, parts = {}}
function sbq.rotate( data )
	if data == sbq.rotating.data and sbq.rotating.enabled then return
	else
		for i, part in ipairs(sbq.rotating.parts) do
			for j, group in ipairs(part.groups) do
				sbq.resetTransformationGroup(group)
			end
		end
	end

	sbq.rotating = {
		enabled = data ~= nil,
		data = data,
		frames = data.frames,
		parts = {},
		loop = data.loop or false,
		timing = data.timing or "body",

		frame = 1,
		index = 2,
		prevFrame = 0,
		prevIndex = 1

	}
	local continue = false
	for _, r in ipairs(data.parts or {}) do
		table.insert(sbq.rotating.parts, {
			groups = r.groups or {"frontarmsrotation"},
			center = r.center or {0,0},
			rotation = r.rotation or {0},
			last = r.rotation[1] or 0
		})
		if r.rotation and #r.rotation > 1 then
			continue = true
		end
	end
	sbq.rotationAnimUpdate()
	if not continue then
		sbq.rotating.enabled = false
	end
end

function sbq.hasAnimEnded(state)
	local ended = (sbq.animStateData[state].animationState.time >= sbq.animStateData[state].animationState.cycle)
	local times = math.floor(sbq.animStateData[state].animationState.time/sbq.animStateData[state].animationState.cycle)
	local currentCycle = (sbq.animStateData[state].animationState.time - (sbq.animStateData[state].animationState.cycle*times))
	return ended, times, currentCycle
end

function sbq.animationIs(state, anim)
	return sbq.animStateData[state].animationState.anim == anim
end

function sbq.setColorReplaceDirectives()
	if sbq.sbqData.replaceColors ~= nil then
		local colorReplaceString = ""
		for i, colorGroup in ipairs(sbq.sbqData.replaceColors) do
			colorReplaceString = colorReplaceString.."?replace"
			local basePalette = colorGroup[1]
			local replacePalette = colorGroup[((sbq.settings.replaceColors or {})[i] or (sbq.sbqData.defaultSettings.replaceColors or {})[i] or 1) + 1]
			local fullbright = (sbq.settings.fullbright or {})[i]

			if sbq.settings.replaceColorTable and sbq.settings.replaceColorTable[i] then
				replacePalette = sbq.settings.replaceColorTable[i]
				if type(replacePalette) == "string" then
					sbq.settings.directives = replacePalette
					sbq.setPartTag( "global", "directives", replacePalette )
					return
				end
			end

			for j, color in ipairs(replacePalette) do
				if fullbright and #color <= #"ffffff" then -- don't tack it on it if it already has a defined opacity or fullbright
					color = color.."fe"
				end
				colorReplaceString = colorReplaceString..";"..(basePalette[j] or "").."="..(color or "")

			end
		end
		sbq.settings.directives = colorReplaceString
		sbq.setPartTag( "global", "directives", colorReplaceString )
	end
	sbq.setItemActionColorReplaceDirectives()
end

function sbq.setSkinPartTags()
	for animPart, skin in pairs(sbq.settings.skinNames or {}) do
		if skin ~= nil and skin ~= "" and not ((skin:find("//") ~= nil) or (skin:find("%.") ~= nil) or (skin:sub(1,1) == "/") or (skin:sub(-1,-1) == "/") ) then
			sbq.setPartTag( animPart, "skin", skin )
			sbq.setPartTag( "global", animPart.."Skin", skin )
		end
	end
end

function sbq.partsAreStruggling(parts)
	for _, part in ipairs(parts) do
		if (not sbq.hasAnimEnded( part.."State" ))
		and (not sbq.animationIs( part.."State", ((sbq.stateconfig[sbq.state] or {}).idle or {})[part] ))
		then return true end
	end
end

function sbq.setPartTag(part, tag, value)
	if sbq.partTags[part] == nil then return end
	sbq.partTags[part][tag] = value

	if part == "global" then
		animator.setGlobalTag( tag, value )
	else
		animator.setPartTag( part, tag, value )
	end
end

sbq.transformGroupData = {}
function sbq.resetTransformationGroup(transformGroup)
	sbq.transformGroupData[transformGroup] = { scale = {}, rotate = {}, translate = {}, translateBR = {} }
end

function sbq.scaleTransformationGroup(transformGroup, scale)
	table.insert(sbq.transformGroupData[transformGroup].scale, scale)
end

function sbq.rotateTransformationGroup(transformGroup, angle, center)
	table.insert(sbq.transformGroupData[transformGroup].rotate, {angle, center})
end

function sbq.translateTransformationGroup(transformGroup, translation, beforeRotate)
	if beforeRotate then
		table.insert(sbq.transformGroupData[transformGroup].translateBR, translation)
	else
		table.insert(sbq.transformGroupData[transformGroup].translate, translation)
	end
end


function sbq.copyTransformationFromGroupsToGroup(transformGroups, resultTransformGroup)
	for _, transformGroup in ipairs(transformGroups) do
		for _, transformation in ipairs(sbq.transformGroupData[transformGroup].scale) do
			table.insert(sbq.transformGroupData[resultTransformGroup].scale, transformation )
		end
		for _, transformation in ipairs(sbq.transformGroupData[transformGroup].rotate) do
			table.insert(sbq.transformGroupData[resultTransformGroup].rotate, transformation )
		end
		for _, transformation in ipairs(sbq.transformGroupData[transformGroup].translate) do
			table.insert(sbq.transformGroupData[resultTransformGroup].translate, transformation )
		end
		for _, transformation in ipairs(sbq.transformGroupData[transformGroup].translateBR) do
			table.insert(sbq.transformGroupData[resultTransformGroup].translateBR, transformation )
		end
	end
end

function sbq.applyTransformations()
	for transformGroup in pairs(sbq.transformGroups) do
		animator.resetTransformationGroup(transformGroup)
		-- apply all the transformations
		for _, transformation in ipairs(sbq.transformGroupData[transformGroup].translateBR) do
			animator.translateTransformationGroup(transformGroup, transformation )
		end
		for _, transformation in ipairs(sbq.transformGroupData[transformGroup].scale) do
			animator.scaleTransformationGroup(transformGroup, transformation )
		end
		for _, transformation in ipairs(sbq.transformGroupData[transformGroup].rotate) do
			animator.rotateTransformationGroup(transformGroup, transformation[1], transformation[2] )
		end
		for _, transformation in ipairs(sbq.transformGroupData[transformGroup].translate) do
			animator.translateTransformationGroup(transformGroup, transformation )
		end
	end
end

function sbq.showEmote( emotename ) --helper function to express a emotion particle "emotesleepy","emoteconfused","emotesad","emotehappy","love"
	if sbq.emoteCooldown < 0 then
		animator.setParticleEmitterBurstCount( emotename, 1 );
		animator.burstParticleEmitter( emotename )
		sbq.emoteCooldown = 0.2; -- seconds
	end
end

function sbq.getLongestAnimationTime(animations, minTime)
	local times = {}
	for part, anim in pairs(animations) do
		local state = part.."State"
		local animData = (sbq.animStateData[state] or {}).states[anim]
		if animData then
			table.insert(times, sbq.animStateData[state].states[anim].cycle)
		end
	end
	return math.max((minTime or 0), table.unpack(times))
end

function sbq.getShortestAnimationTime(animations, maxTime)
	local times = {}
	for part, anim in pairs(animations) do
		local state = part.."State"
		local animData = (sbq.animStateData[state] or {}).states[anim]
		if animData then
			table.insert(times, animData.cycle)
		end
	end
	return math.min((maxTime or math.huge), table.unpack(times))
end
