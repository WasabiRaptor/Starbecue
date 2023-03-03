

function sbq.updateState(dt)
	if sbq.prevState == sbq.state then
		if state[sbq.state] ~= nil and state[sbq.state].update ~= nil then
			state[sbq.state].update(dt)
		else
			sbq.standardState(dt)
		end
	else
		if state[sbq.prevState] ~= nil and state[sbq.prevState].ending ~= nil then
			state[sbq.prevState].ending(dt)
		end

		sbq.checkDrivingInteract()

		if state[sbq.state] ~= nil and state[sbq.state].begin ~= nil then
			state[sbq.state].begin(dt)
		end
		sbq.prevState = sbq.state
	end
end

function sbq.setState(state)
	if state == nil then
		sbq.logError( "nil state from ".. sbq.state )
		return
	end
	if not sbq.stateconfig[state] then
		sbq.logError( "invalid state "..state.." from ".. sbq.state)
		return
	end
	sbq.prevState = sbq.state
	sbq.state = state
	sbq.setPartTag( "global", "state", sbq.stateconfig[state].baseState or state )
	sbq.doAnims( sbq.stateconfig[state].idle, true )
end

function sbq.checkDrivingInteract()
	if type(sbq.driver) == "number" and world.entityType(sbq.driver) == "npc" then
		vehicle.setInteractive(true)
	elseif sbq.driving and sbq.stateconfig[sbq.state].interact ~= nil then
		for _, interaction in pairs(sbq.stateconfig[sbq.state].interact) do
			if interaction.drivingEnabled then
				return vehicle.setInteractive(true)
			end
		end
		vehicle.setInteractive(false)
	else
		vehicle.setInteractive(sbq.stateconfig[sbq.state].interact ~= nil)
	end
end

sbq.transitionLock = false
sbq.movementLock = false


function sbq.checkPreyListEnabled(direction, tconfig, scriptargs, preyIndex, preyList)
	if not world.entityExists(preyList[preyIndex]) then
		if preyIndex >= #preyList then
			sbq.doingTransition(tconfig, direction, scriptargs)
		else
			preyIndex = preyIndex + 1
			sbq.checkPreyListEnabled(direction, tconfig, scriptargs, preyIndex, preyList)
		end
	end
	sbq.addRPC(world.sendEntityMessage(preyList[preyIndex], "sbqIsPreyEnabled", tconfig.voreType), function(enabled)
		if enabled and enabled.enabled then
			if enabled.preyList then
				for _, prey in ipairs(enabled.preyList) do
					if prey == sbq.driver then
						animator.playSound("error")
						return
					end
					local repeated = false
					for _, prey2 in ipairs(preyList) do
						if prey == prey2 then repeated = true end
					end
					if not repeated then
						table.insert(preyList, prey)
					end
				end
			end
			if preyIndex >= #preyList then
				sbq.doingTransition(tconfig, direction, scriptargs)
			else
				preyIndex = preyIndex + 1
				sbq.checkPreyListEnabled(direction, tconfig, scriptargs, preyIndex, preyList)
			end
		else
			animator.playSound("error")
		end
	end)
end

function sbq.doTransition(direction, scriptargs, log)
	local scriptargs = scriptargs or {}
	if (not sbq.stateconfig or not sbq.stateconfig[sbq.state].transitions[direction]) then return end
	if sbq.transitionLock then return end
	local tconfig = sbq.getOccupancyTransition(sbq.stateconfig[sbq.state].transitions[direction], scriptargs)
	if tconfig == nil then return end
	if tconfig.settings then
		if not sbq.checkSettings(tconfig.settings) then return end
	end
	local id = sbq.getTransitionVictimId(scriptargs, tconfig)

	if tconfig.voreType ~= nil and type(id) == "number" and world.entityExists(id) then
		sbq.addRPC(world.sendEntityMessage(id, "sbqIsPreyEnabled", tconfig.voreType), function(enabled)
			if enabled and enabled.enabled then
				scriptargs.size = enabled.size
				tconfig = sbq.getOccupancyTransition(tconfig, scriptargs)
				if tconfig == nil then return end

				if enabled.preyList and type(enabled.preyList[1]) == "number" then
					local preyIndex = 1
					sbq.checkPreyListEnabled(direction, tconfig, scriptargs, preyIndex, enabled.preyList)
				else
					sbq.doingTransition(tconfig, direction, scriptargs)
				end
			else
				animator.playSound("error")
			end
		end)
	else
		return sbq.doingTransition(tconfig, direction, scriptargs)
	end
end

function sbq.doingTransition(tconfig, direction, scriptargs)
	if sbq.transitionLock then return end
	local continue = true
	local after

	if tconfig.script then
		local statescript = state[sbq.state][tconfig.script]
		local _continue, _tconfig
		if statescript ~= nil then
			_continue, after, _tconfig = statescript( scriptargs or {}, tconfig )
			if _continue ~= nil then continue = _continue end
			if _tconfig ~= nil then tconfig = _tconfig end
		else
			sbq.logError("no script named: ["..tconfig.script.."] in state: ["..sbq.state.."]")
		end
	end

	if tconfig.shrinkAnims ~= nil then
		sbq.shrinkQueue = sb.jsonMerge(sbq.shrinkQueue, tconfig.shrinkAnims)
	end
	if tconfig.expandAnims ~= nil then
		sbq.expandQueue = sb.jsonMerge(sbq.shrinkQueue, tconfig.expandAnims)
	end

	if not continue then return end

	if tconfig.timing == nil then
		tconfig.timing = "body"
	end
	if tconfig.animation ~= nil then
		sbq.doAnims( tconfig.animation )
	end
	sbq.updateOccupants(0)

	local timing
	local timingType = type(tconfig.timing)
	if timingType == "string" then
		timing = sbq.animStateData[tconfig.timing.."State" or "bodyState"].animationState.cycle
		if after ~= nil then
			sbq.queueAnimEndFunction(tconfig.timing.."State", after)
		end
		if (tconfig.state ~= nil) and (tconfig.state ~= sbq.state) then
			sbq.movementLock = true
			sbq.transitionLock = true

			sbq.queueAnimEndFunction(tconfig.timing.."State", function()
				sbq.setState( tconfig.state )
				sbq.doAnims( sbq.stateconfig[sbq.state].idle )
				sbq.transitionLock = false
				sbq.movementLock = false
			end)
		end
		if tconfig.lock then
			sbq.transitionLock = true
			sbq.queueAnimEndFunction(tconfig.timing.."State", function()
				sbq.transitionLock = false
			end)
		end
		if tconfig.movementLock then
			sbq.movementLock = true
			sbq.queueAnimEndFunction(tconfig.timing.."State", function()
				sbq.movementLock = false
			end)
		end
		if tconfig.victimAnimation ~= nil then -- lets make this use the id to get the index
			local id = sbq.getTransitionVictimId(scriptargs, tconfig)
			if id ~= nil then sbq.doVictimAnim( id, tconfig.victimAnimation, tconfig.timing.."State" or "bodyState" ) end
		end
	elseif timingType == "number" then
		timing = tconfig.timing
		if after ~= nil then
			sbq.timer(direction.."After", timing, after)
		end
		if tconfig.lock then
			sbq.transitionLock = true
			sbq.timer(direction.."Lock", timing, function()
				sbq.transitionLock = false
			end)
		end
		if tconfig.movementLock then
			sbq.movementLock = true
			sbq.timer(direction.."MovementLock", timing, function()
				sbq.movementLock = false
			end)
		end
		if (tconfig.state ~= nil) and (tconfig.state ~= sbq.state) then
			sbq.movementLock = true
			sbq.transitionLock = true

			sbq.timer(direction.."StateChange", timing, function()
				sbq.setState( tconfig.state )
				sbq.doAnims( sbq.stateconfig[sbq.state].idle )
				sbq.transitionLock = false
				sbq.movementLock = false
			end)
		end
		if tconfig.victimAnimation ~= nil then
			sbq.logError("Victim Animations MUST use a timing value from an animation part")
		end
	end
	return true, timing
end

function sbq.getTransitionVictimId(scriptargs, tconfig)
	local id = (scriptargs or {}).id
	if id == nil then
		id = sbq.justAte
	end
	if tconfig.victimAnimLocation ~= nil then
		id = sbq.findFirstOccupantIdForLocation(tconfig.victimAnimLocation)
	end
	return id
end

function sbq.idleStateChange(dt)
	if not sbq.notMoving() or sbq.movement.animating or sbq.transitionLock then return end

	if not sbq.driving and sbq.randomTimer( "idleStateChange", 5.0, 5.0 ) then -- every 5 seconds? this is arbitrary, oh well
		local transitions = sbq.stateconfig[sbq.state].transitions
		if not sbq.driver then
			local percent = math.random(100)
			for name, t in pairs(transitions) do
				local transition = sbq.getOccupancyTransition( t )
				if transition and transition.chance and transition.chance > 0 then
					percent = percent - transition.chance
					if percent <= 0 then
						sbq.doTransition( name )
						return
					end
				end
			end
		end
	end

	sbq.doAnims( sbq.stateconfig[sbq.state].idle )

	sbq.nextIdle = sbq.nextIdle - 1
	if sbq.nextIdle <= 0 then
		sbq.nextIdle = math.random(50, 300)
		local idles = sbq.stateconfig[sbq.state].idleAnimations
		if idles ~= nil and #idles >= 1 then
			local which = math.random(#idles)
			sbq.doAnims( idles[which] )
		end
	end
end
