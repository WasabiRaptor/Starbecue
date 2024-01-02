
function sbq.setPartTag(part, tag, value)
	if sbq.partTags[part][tag] ~= value then
		sbq.partTags[part][tag] = value
		if part == "global" then
			world.sendEntityMessage(sbq.spawner, "sbqSetGlobalTag", tag, value)
		else
			world.sendEntityMessage(sbq.spawner, "sbqSetPartTag", part, tag, value)
		end
	end
end

function sbq.getAnimData()
	sbq.loopedMessage("getAnimData", sbq.spawner, "sbqGetAnimData", {}, function(direction)
		animator.setFlipped(direction==-1)
		sbq.direction = direction
	end)
end

function sbq.updateAnims(dt)
	for statename, state in pairs(sbq.animStateData) do
		state.animationState.time = state.animationState.time + dt
		local ended, times, time = sbq.hasAnimEnded(statename)
		if (not ended) or (state.animationState.mode == "loop") then
			state.animationState.frame = math.floor( time * state.animationState.speed ) + 1
		elseif ended and state.animationState.mode == "transition" then
			sbq.doAnim(statename, state.animationState.transition)
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
		if state.animationState.time >= state.animationState.cycle then
			sbq.endAnim(state, statename)
		end
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
			sbq.changePriorityLength( anim )
		else
			sbq.doAnim( state.."State", anim, force)
		end
	end
end

function sbq.doAnim(state, anim, force)
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
			elseif mode == "loop" then
				return
			end
		end
		sbq.animStateData[state].animationState = {
			anim = anim,
			priority = newPriority,
			cycle = sbq.animStateData[state].states[anim].cycle,
			frames = sbq.animStateData[state].states[anim].frames,
			mode = sbq.animStateData[state].states[anim].mode,
			speed = sbq.animStateData[state].states[anim].frames / sbq.animStateData[state].states[anim].cycle,
			frame = 1,
			time = 0
        }
		world.sendEntityMessage(sbq.spawner, "sbqDoAnim", state, anim, force)
	end
end
