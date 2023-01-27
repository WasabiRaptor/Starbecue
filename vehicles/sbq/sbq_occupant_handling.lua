function sbq.forceSeat( occupantId, seatindex )
	if occupantId then
		vehicle.setLoungeEnabled("occupant"..seatindex, true)
		world.sendEntityMessage( occupantId, "sbqForceSit", {index=seatindex, source=entity.id()})
	end
end

function sbq.unForceSeat(occupantId)
	if occupantId then
		world.sendEntityMessage( occupantId, "applyStatusEffect", "sbqRemoveForceSit", 1, entity.id())
	end
end

function sbq.eat( occupantId, location, size, voreType, locationSide, force )
	local seatindex = sbq.occupants.total + sbq.startSlot
	if seatindex > sbq.occupantSlots then return false end
	local locationSpace = sbq.locationSpaceAvailable(location, locationSide)
	if locationSpace < ((size or 1) * (sbq.settings[location.."Multiplier"] or 1)) then return false end
	if (not occupantId) or (not world.entityExists(occupantId))
	or ((sbq.entityLounging(occupantId) or sbq.inedible(occupantId)) and not force)
	then return false end

	local loungeables = world.entityQuery( world.entityPosition(occupantId), 5, {
		withoutEntityId = entity.id(), includedTypes = { "vehicle" },
		callScript = "sbq.entityLounging", callScriptArgs = { occupantId }
	} )

	local edibles = world.entityQuery( world.entityPosition(occupantId), 2, {
		withoutEntityId = entity.id(), includedTypes = { "vehicle" },
		callScript = "sbq.edible", callScriptArgs = { occupantId, seatindex, entity.id(), force}
	} )
	if edibles[1] == nil then
		if loungeables[1] == nil then -- now just making sure the prey doesn't belong to another loungable now
			sbq.gotEaten(seatindex, occupantId, location, size, voreType, locationSide, force)
			sbq.addRPC(world.sendEntityMessage(occupantId, "sbqGetSpeciesVoreConfig"), function (data)
				sbq.occupant[seatindex].scale = data[2]
				sbq.occupant[seatindex].scaleYOffset = data[3]
			end)
			return true -- not lounging
		else
			return false -- lounging in something inedible
		end
	end
	-- lounging in edible smol thing
	local species = world.entityName(edibles[1])
	sbq.gotEaten(seatindex, occupantId, location, size, voreType, locationSide, force)
	sbq.occupant[seatindex].species = species
	return true
end

function sbq.gotEaten(seatindex, occupantId, location, size, voreType, locationSide, force)
	local entityType = world.entityType(occupantId)
	if entityType == "player" then
		sbq.addRPC(world.sendEntityMessage(occupantId, "sbqGetCumulativeOccupancyTimeAndFlags", sbq.spawnerUUID),
			function(data)
			if not data then return end
			sbq.occupant[seatindex].cumulative = data.times or {}
			sbq.occupant[seatindex].cumulativeStart = sb.jsonMerge(data.times or {}, {})
			sbq.occupant[seatindex].flags = sb.jsonMerge(sbq.occupant[seatindex].flags or {}, data.flags or {} )
		end)
	else
		sbq.addRPC(world.sendEntityMessage(sbq.spawner, "sbqGetCumulativeOccupancyTimeAndFlags",
			world.entityUniqueId(occupantId), true), function(data)
			if not data then return end
			sbq.occupant[seatindex].cumulative = data.times or {}
			sbq.occupant[seatindex].cumulativeStart = sb.jsonMerge(data.times or {}, {})
			sbq.occupant[seatindex].flags = sb.jsonMerge(sbq.occupant[seatindex].flags or {}, data.flags or {} )
		end)
	end

	sbq.occupant[seatindex].id = occupantId
	sbq.occupant[seatindex].location = location
	sbq.occupant[seatindex].locationSide = locationSide
	sbq.occupant[seatindex].size = size or 1
	sbq.occupant[seatindex].entryType = voreType
	world.sendEntityMessage( occupantId, "sbqMakeNonHostile")
	sbq.forceSeat( occupantId, seatindex)
	sbq.refreshList = true
end

function sbq.uneat( occupantId )
	if occupantId == nil or not world.entityExists(occupantId) then return end
	world.sendEntityMessage( occupantId, "sbqClearDrawables")
	world.sendEntityMessage( occupantId, "applyStatusEffect", "sbqRemoveBellyEffects")
	world.sendEntityMessage( occupantId, "primaryItemLock", false)
	world.sendEntityMessage( occupantId, "altItemLock", false)
	world.sendEntityMessage( occupantId, "sbqLight", nil )
	sbq.unForceSeat( occupantId )
	if not sbq.lounging[occupantId] then return end

	local seatindex = sbq.lounging[occupantId].index
	local occupantData = sbq.lounging[occupantId]
	if world.entityType(occupantId) == "player" then
		world.sendEntityMessage(occupantId, "sbqOpenInterface", "sbqClose")
	end

	if occupantData.species ~= nil and occupantData.smolPreyData ~= nil then
		if type(occupantData.smolPreyData.id) == "number" and world.entityExists(occupantData.smolPreyData.id) then
			world.sendEntityMessage(occupantData.smolPreyData.id, "uneaten")
		else
			world.spawnVehicle( occupantData.species, sbq.localToGlobal({ occupantData.victimAnim.last.x or 0, occupantData.victimAnim.last.y or 0}), { driver = occupantId, settings = occupantData.smolPreyData.settings, uneaten = true, startState = occupantData.smolPreyData.state, layer = occupantData.smolPreyData.layer })
		end
	else
		world.sendEntityMessage(occupantId, "sbqRemoveStatusEffects", sbq.config.predStatusEffects)
		world.sendEntityMessage( occupantId, "sbqPredatorDespawned", true ) -- to clear the current data for players
	end

	world.sendEntityMessage(occupantId, "sbqSetCumulativeOccupancyTime", sbq.spawnerUUID, false, sbq.lounging[occupantId].cumulative )
	world.sendEntityMessage(sbq.spawner, "sbqSetCumulativeOccupancyTime", world.entityUniqueId(occupantId), true, sbq.lounging[occupantId].cumulative)

	world.sendEntityMessage(sbq.spawner, "sbqCheckRewards", sbq.trimOccupantData(sbq.lounging[occupantId]) )

	sbq.refreshList = true
	sbq.lounging[occupantId] = nil
	sbq.occupant[seatindex] = sbq.clearOccupant(seatindex)
	return true
end

function sbq.edible( occupantId, seatindex, source, force )
	if sbq.driver ~= occupantId or (sbq.isNested and not force) then return false end

	if sbq.stateconfig[sbq.state].edible then
		world.sendEntityMessage(source, "sbqSmolPreyData", seatindex,
			sbq.getSmolPreyData(
				sbq.settings,
				world.entityName( entity.id() ),
				sbq.state,
				sbq.partTags,
				sbq.seats[sbq.driverSeat].smolPreyData
			),
			entity.id()
		)
		world.sendEntityMessage( sbq.driver, "sbqOpenInterface", "sbqClose", false, false, entity.id() )
		sbq.isNested = true
		sbq.scaleTransformationGroup("globalScale", {0,0})
		return true
	end
end

sbq.sendAllPreyTo = nil
function sbq.sendAllPrey()
	if type(sbq.sendAllPreyTo) == "number" and world.entityExists(sbq.sendAllPreyTo) then
		for i = sbq.startSlot, sbq.occupantSlots do
			if type(sbq.occupant[i].id) == "number" and world.entityExists(sbq.occupant[i].id)
				and (sbq.occupant[i].location ~= "escaping" )
			then
				sbq.occupant[i].visible = false
				if sbq.digestSendPrey then
					world.sendEntityMessage(sbq.sendAllPreyTo, "addDigestPrey", sbq.occupant[i], sbq.driver)
				else
					world.sendEntityMessage(sbq.sendAllPreyTo, "addPrey", sbq.occupant[i])
				end
				sbq.occupant[i] = sbq.clearOccupant(i)
			end
		end
		sbq.updateOccupants(0)
		sbq.onDeath()
	end
end

function sbq.firstNotLounging(entityaimed)
	for _, eid in ipairs(entityaimed) do
		if not sbq.entityLounging(eid) then
			return eid
		end
	end
end

function sbq.moveOccupantLocation(args, location, side)
	local space = sbq.locationSpaceAvailable(location, side)
	if not args.id or (space < ((sbq.lounging[args.id].size or 1) * (sbq.settings[location.."Multiplier"] or 1))) then return false end

	sbq.lounging[args.id].location = location
	sbq.lounging[args.id].locationSide = side
	return true
end

function sbq.findFirstOccupantIdForLocation(location)
	for i = 0, sbq.occupantSlots do
		if sbq.occupant[i].location == location and type(sbq.occupant[i].id) == "number" and world.entityExists(sbq.occupant[i].id) then
			return sbq.occupant[i].id, i
		end
	end
end

function sbq.locationVisualSize(location, side)
	local locationSize = sbq.occupants[location]
	local data = sbq.sbqData.locations[location] or {}
	if data.sided then
		if (sbq.settings[location.."Symmetrical"] or data.symmetrical) or not side then
			locationSize = math.max(sbq.occupants[location.."L"], sbq.occupants[location.."R"])
		else
			locationSize = sbq.occupants[location..(side or "L")]
		end
	end
	local minMaxed = math.max((sbq.settings[location .. "VisualMin"] or data.minVisual or 0),
		math.min((locationSize / sbq.predScale), sbq.settings[location .. "VisualMax"] or data.maxVisual or data.max or
			math.huge))

	if data.sizes then
		return sbq.getClosestValue(minMaxed, data.sizes.struggle)
	else
		return math.floor(minMaxed)
	end
end

function sbq.locationSpaceAvailable(location, side)
	if sbq.settings.hammerspace and sbq.sbqData.locations[location].hammerspace
	and not sbq.settings[location.."HammerspaceDisabled"] then
		return math.huge
	end
	return (sbq.sbqData.locations[location..(side or "")].max * (sbq.predScale or 1)) - sbq.occupants[location..(side or "")]
end

function sbq.getSidedLocationWithSpace(location, size)
	local data = sbq.sbqData.locations[location]
	if data.sided then
		local leftHasSpace = sbq.locationSpaceAvailable(location, "L") > ((size or 1) * (sbq.settings[location.."Multiplier"] or 1))
		local rightHasSpace = sbq.locationSpaceAvailable(location, "R") > ((size or 1) * (sbq.settings[location.."Multiplier"] or 1))
		if sbq.occupants[location.."L"] == sbq.occupants[location.."R"] then
			if sbq.direction > 0 then -- thinking about it, after adding everything underneath to prioritize the one with less prey, this is kinda useless
				if leftHasSpace then return location, "L", data
				elseif rightHasSpace then return location, "R", data
				else return false end
			else
				if rightHasSpace then return location, "R", data
				elseif leftHasSpace then return location, "L", data
				else return false end
			end
		elseif sbq.occupants[location .. "L"] < sbq.occupants[location .. "R"] and leftHasSpace then return location, "L", data
		elseif sbq.occupants[location .. "L"] > sbq.occupants[location .. "R"] and rightHasSpace then return location, "R", data
		else return false end
	end
	return location, "", data
end


function sbq.doVore(args, location, statuses, sound, voreType )
	if sbq.isNested then return false end
	local location, locationSide = sbq.getSidedLocationWithSpace(location, args.size)
	if not location then return false end
	if sbq.eat( args.id, location, args.size, voreType, locationSide ) then
		sbq.justAte = args.id
		vehicle.setInteractive( false )
		sbq.showEmote("emotehappy")
		sbq.transitionLock = true
		world.sendEntityMessage( args.id, "sbqApplyStatusEffects", statuses )

		local settings = {
			voreType = voreType or "default",
			predator = sbq.species,
			location = location,
			entryType = voreType
		}
		local entityType = world.entityType(args.id)
		local sayLine = entityType == "npc" or entityType == "player" and type(sbq.driver) == "number" and world.entityExists(sbq.driver)

		if sayLine then world.sendEntityMessage( args.id, "sbqSayRandomLine", sbq.driver, sb.jsonMerge(sbq.settings, settings), {"vored"}, true ) end

		return true, function()
			sbq.justAte = nil
			sbq.transitionLock = false
			sbq.checkDrivingInteract()
			if sound then animator.playSound( sound ) end
		end
	else
		return false
	end
end

function sbq.doEscape(args, statuses, afterstatuses, voreType )
	if sbq.isNested then return false end

	local victim = args.id
	if not victim then return false end -- could be part of above but no need to log an error here
	local location = sbq.lounging[victim].location

	local settings = sb.jsonMerge(sb.jsonMerge(sbq.lounging[victim].visited,{
		voreType = voreType or "default",
		struggleTrigger = args.struggleTrigger,
		location = location,
		progressBarType = sbq.lounging[victim].progressBarType,
		progressBar = sbq.lounging[victim].progressBar
	}), sbq.lounging[victim].flags)

	local entityType = world.entityType(args.id)
	local sayLine = entityType == "npc" or entityType == "player" and type(sbq.driver) == "number" and world.entityExists(sbq.driver)

	if sayLine then world.sendEntityMessage( sbq.driver, "sbqSayRandomLine", args.id, settings, {"letout"}, true ) end
	sbq.lounging[victim].location = "escaping"

	vehicle.setInteractive( false )
	world.sendEntityMessage( victim, "sbqApplyStatusEffects", statuses )
	sbq.transitionLock = true
	return true, function()
		if sayLine then world.sendEntityMessage( args.id, "sbqSayRandomLine", sbq.driver, sb.jsonMerge(sbq.settings, settings), {"escape"}, false) end
		sbq.transitionLock = false
		sbq.checkDrivingInteract()
		sbq.uneat( victim )
		world.sendEntityMessage( victim, "sbqApplyStatusEffects", afterstatuses )
	end
end

function sbq.applyStatusLists()
	for i = 0, sbq.occupantSlots do
		if type(sbq.occupant[i].id) == "number" and world.entityExists(sbq.occupant[i].id) then
			if not sbq.weirdFixFrame then
				vehicle.setLoungeEnabled(sbq.occupant[i].seatname, true)
			end
			sbq.loopedMessage( sbq.occupant[i].seatname.."StatusEffects", sbq.occupant[i].id, "sbqApplyStatusEffects", {sbq.occupant[i].statList} )
			sbq.loopedMessage( sbq.occupant[i].seatname.."ForceSeat", sbq.occupant[i].id, "sbqForceSit", {{index=i, source=entity.id(), rotation=sbq.occupant[i].victimAnim.last.r, driver = (sbq.occupant[i].seatname == sbq.driverSeat) }})
		else
			vehicle.setLoungeEnabled(sbq.occupant[i].seatname, false)
		end
	end
	sbq.weirdFixFrame = nil
end

function sbq.addStatusToList(eid, status, data)
	sbq.lounging[eid].statList[status] = sb.jsonMerge({
		power = 1,
		source = sbq.driver or entity.id(),
	}, data)
end

function sbq.removeStatusFromList(eid, status)
	sbq.lounging[eid].statList[status] = nil
	world.sendEntityMessage(eid, "sbqRemoveStatusEffect", status)
end

function sbq.resetOccupantCount()
	sbq.occupantsPrev = sb.jsonMerge(sbq.occupants, {})
	sbq.occupantsPrevVisualSize = sb.jsonMerge(sbq.occupantsVisualSize, {})

	sbq.occupants.total = 0
	sbq.occupants.totalSize = 0
	for location, data in pairs(sbq.sbqData.locations) do
		sbq.occupants[location] = 0
	end
	sbq.occupants.mass = 0
end

sbq.addPreyQueue = {}
function sbq.recievePrey()
	for i, prey in ipairs(sbq.addPreyQueue) do
		local seatindex = sbq.occupants.total + sbq.startSlot + i - 1
		prey.visible = false
		if seatindex > sbq.occupantSlots then break end
		sbq.occupant[seatindex] = prey
	end
	sbq.addPreyQueue = {}
end

sbq.actualOccupants = {}
function sbq.updateOccupants(dt)
	sbq.resetOccupantCount()

	local lastFilled = true

	local list = {}
	local powerMultiplier = math.atan(math.max(sbq.seats[sbq.driverSeat].controls.powerMultiplier, 1)/3) * 5

	for i = sbq.startSlot, sbq.occupantSlots do
		if type(sbq.occupant[i].id) == "number" and world.entityExists(sbq.occupant[i].id) then
			table.insert(list, sbq.occupant[i].id)

			sbq.occupants.total = sbq.occupants.total + 1
			if not lastFilled and sbq.swapCooldown <= 0 then
				sbq.swapOccupants(i - 1, i)
				i = i - 1
			end

			sbq.occupant[i].index = i
			local seatname = "occupant" .. i
			sbq.occupant[i].seatname = seatname
			sbq.lounging[sbq.occupant[i].id] = sbq.occupant[i]
			sbq.seats[sbq.occupant[i].seatname] = sbq.occupant[i]
			sbq.occupant[i].visited.totalTime = (sbq.occupant[i].visited.totalTime or 0) + dt
			sbq.occupant[i].cumulative.totalTime = (sbq.occupant[i].cumulative.totalTime or 0) + dt

			local massMultiplier = 0
			local mass = sbq.occupant[i].controls.mass
			local location = sbq.occupant[i].location
			local sidedLocation = location .. (sbq.occupant[i].locationSide or "")

			if location == "escaping" then
			elseif (location == nil) or (sbq.sbqData.locations[location] == nil) or
				((sbq.sbqData.locations[location].max or 0) == 0) then
				sbq.uneat(sbq.occupant[i].id)
				return
			else
				sbq.doBellyEffect(i, sbq.occupant[i].id, dt, location, powerMultiplier)

				sbq.occupant[i].visited[location .. "Visited"] = true
				sbq.occupant[i].visited[location .. "Time"] = (sbq.occupant[i].visited[location .. "Time"] or 0) + dt
				sbq.occupant[i].cumulative[location .. "Time"] = (sbq.occupant[i].cumulative[location .. "Time"] or 0) + dt

				local size = ((sbq.occupant[i].size * sbq.occupant[i].sizeMultiplier) * (sbq.settings[location.."Multiplier"] or 1))
				sbq.occupants[sidedLocation] = sbq.occupants[sidedLocation] + size
				sbq.occupants.totalSize = sbq.occupants.totalSize + size

				massMultiplier = sbq.sbqData.locations[location].mass or 0

				sbq.occupants.mass = sbq.occupants.mass + mass * massMultiplier

				if sbq.sbqData.locations[location].transformGroups ~= nil then
					sbq.copyTransformationFromGroupsToGroup(sbq.sbqData.locations[location].transformGroups, seatname .. "Position")
				end
			end

			lastFilled = true
		elseif type(sbq.occupant[i].id) == "number" and not world.entityExists(sbq.occupant[i].id) then
			sbq.occupant[i] = sbq.clearOccupant(i)
			sbq.refreshList = true
			lastFilled = false
		else
			lastFilled = false
			sbq.occupant[i] = sbq.clearOccupant(i)
		end
	end
	sbq.loopedMessage("preyList", sbq.driver, "sbqPreyList", {list})
	sbq.swapCooldown = math.max(0, sbq.swapCooldown - 1)

	mcontroller.applyParameters({mass = sbq.movementParams.mass + sbq.occupants.mass})

	sbq.setOccupantTags()
end

sbq.expandQueue = {}
sbq.shrinkQueue = {}

function sbq.setOccupantTags()
	for location, occupancy in pairs(sbq.occupants) do
		sbq.actualOccupants[location] = occupancy
	end
	-- because of the fact that pairs feeds things in a random ass order we need to make sure these have tripped on every location *before* setting the occupancy tags or checking the expand/shrink queue
	for location, data in pairs(sbq.sbqData.locations) do
		if data.combine then
			for _, combine in ipairs(data.combine) do
				sbq.occupants[location] = sbq.occupants[location] + sbq.occupants[combine]
				sbq.occupants[combine] = sbq.occupants[location]
			end
		end
	end
	for location, data in pairs(sbq.sbqData.locations) do
		if data.copy then
			local copyTable = {0}
			for _, copy in ipairs(data.copy) do
				table.insert(copyTable, sbq.occupants[copy])
			end
			sbq.occupants[location] = math.max(table.unpack(copyTable))
		end
	end

	for location, data in pairs(sbq.sbqData.locations) do
		sbq.occupantsVisualSize[location] = sbq.locationVisualSize(location)
		if data.sided then
			if sbq.settings[location.."Symmetrical"] or data.symmetrical then -- for when people want their balls and boobs to be the same size
				if sbq.occupantsVisualSize[location] ~= sbq.occupantsPrevVisualSize[location] or sbq.refreshSizes then
					sbq.setPartTag( "global", location.."FrontOccupants", tostring(sbq.occupantsVisualSize[location]) )
					sbq.setPartTag( "global", location.."BackOccupants", tostring(sbq.occupantsVisualSize[location]) )
				end
				sbq.interpolateLocation(location, location .. "FrontOccupantsInterpolate")
				sbq.interpolateLocation(location, location .. "BackOccupantsInterpolate")

				if sbq.occupantsVisualSize[location] > sbq.occupantsPrevVisualSize[location] then
					sbq.setLocationInterpolation(sbq.expandQueue[location] or (sbq.stateconfig[sbq.state].expandAnims or {})[location])
				elseif sbq.occupantsVisualSize[location] < sbq.occupantsPrevVisualSize[location] then
					sbq.setLocationInterpolation(sbq.shrinkQueue[location] or (sbq.stateconfig[sbq.state].shrinkAnims or {})[location])
				end

			else
				sbq.occupantsVisualSize[location.."L"] = sbq.locationVisualSize(location, "L")
				sbq.occupantsVisualSize[location .. "R"] = sbq.locationVisualSize(location, "R")

				if sbq.direction > 0 then -- to make sure those in the balls in CV and breasts in BV cases stay on the side they were on instead of flipping
					if sbq.occupantsVisualSize[location.."R"] ~= sbq.occupantsPrevVisualSize[location.."R"] or sbq.direction ~= sbq.prevDirection or sbq.refreshSizes then
						sbq.setPartTag("global", location .. "FrontOccupants", tostring(sbq.occupantsVisualSize[location .. "R"]))
					end
					sbq.interpolateLocation(location.."R", location .. "FrontOccupantsInterpolate")

					if sbq.occupantsVisualSize[location.."L"] ~= sbq.occupantsPrevVisualSize[location.."L"] or sbq.direction ~= sbq.prevDirection or sbq.refreshSizes then
						sbq.setPartTag( "global", location.."BackOccupants", tostring(sbq.occupantsVisualSize[location.."L"]) )
					end
					sbq.interpolateLocation(location.."L", location .. "BackOccupantsInterpolate")

				else
					if sbq.occupantsVisualSize[location.."R"] ~= sbq.occupantsPrevVisualSize[location.."R"] or sbq.direction ~= sbq.prevDirection or sbq.refreshSizes then
						sbq.setPartTag( "global", location.."BackOccupants", tostring(sbq.occupantsVisualSize[location.."R"]) )
					end
					sbq.interpolateLocation(location.."R", location .. "BackOccupantsInterpolate")

					if sbq.occupantsVisualSize[location.."L"] ~= sbq.occupantsPrevVisualSize[location.."L"] or sbq.direction ~= sbq.prevDirection or sbq.refreshSizes then
						sbq.setPartTag( "global", location.."FrontOccupants", tostring(sbq.occupantsVisualSize[location.."L"]) )
					end
					sbq.interpolateLocation(location.."L", location .. "FrontOccupantsInterpolate")

				end

				if (sbq.occupantsVisualSize[location.."R"] > sbq.occupantsPrevVisualSize[location.."R"]) then
					sbq.setLocationInterpolation(location.."R", data, sbq.expandQueue[location] or (sbq.stateconfig[sbq.state].expandAnims or {})[location])
				elseif sbq.occupantsVisualSize[location.."R"] < sbq.occupantsPrevVisualSize[location.."R"] then
					sbq.setLocationInterpolation(location.."R", data, sbq.shrinkQueue[location] or (sbq.stateconfig[sbq.state].shrinkAnims or {})[location])
				end

				if sbq.occupantsVisualSize[location.."L"] > sbq.occupantsPrevVisualSize[location.."L"] then
					sbq.setLocationInterpolation(location.."L", data, sbq.expandQueue[location] or (sbq.stateconfig[sbq.state].expandAnims or {})[location])
				elseif sbq.occupantsVisualSize[location.."L"] < sbq.occupantsPrevVisualSize[location.."L"] then
					sbq.setLocationInterpolation(location.."L", data, sbq.shrinkQueue[location] or (sbq.stateconfig[sbq.state].shrinkAnims or {})[location])
				end
			end

		else
			if sbq.occupantsVisualSize[location] ~= sbq.occupantsPrevVisualSize[location] or sbq.refreshSizes then
				sbq.setPartTag( "global", location.."Occupants", tostring(sbq.occupantsVisualSize[location]) )
			end
			sbq.interpolateLocation(location, location .. "OccupantsInterpolate")

			if sbq.totalTimeAlive > 0.5 or config.getParameter("doExpandAnim") then
				if sbq.occupantsVisualSize[location] > sbq.occupantsPrevVisualSize[location] then
					sbq.setLocationInterpolation(location, data, sbq.expandQueue[location] or (sbq.stateconfig[sbq.state].expandAnims or {})[location])
				elseif sbq.occupantsVisualSize[location] < sbq.occupantsPrevVisualSize[location] then
					sbq.setLocationInterpolation(location, data, sbq.shrinkQueue[location] or (sbq.stateconfig[sbq.state].shrinkAnims or {})[location])
				end
			end

		end

		sbq.expandQueue[location] = nil
		sbq.shrinkQueue[location] = nil
	end
	sbq.refreshSizes = false
	sbq.prevDirection = sbq.direction
end

sbq.locationInterpolation = {}
function sbq.setLocationInterpolation(location, data, animations)
	local result = sbq.occupantsVisualSize[location]
	sbq.doAnims(animations)
	if type(sbq.locationInterpolation[location]) ~= "table" then
		local interpolationTable = sbq.getLocationSizeInterpolationTable(location, data, sbq.occupantsPrevVisualSize[location], result)
		if not interpolationTable then return end
		sbq.locationInterpolation[location] = {
			result = result,
			current = sbq.occupantsPrevVisualSize[location],
			time = 0,
			speed = #interpolationTable / sbq.getLongestAnimationTime(animations),
			interpolationTable = interpolationTable
		}
	elseif result ~= sbq.locationInterpolation[location].result then
		local current = sbq.locationInterpolation[location].current
		local interpolationTable = sbq.getLocationSizeInterpolationTable(location, data, current, result)
		if not interpolationTable then return end
		sbq.locationInterpolation[location] = {
			result = result,
			current = current,
			time = 0,
			speed = #interpolationTable / sbq.getLongestAnimationTime(animations),
			interpolationTable = interpolationTable
		}
	end
end

function sbq.getLocationSizeInterpolationTable(location, data, current, result)
	local interpolationTable = {}
	if not data.sizes then return end

	local closestStart, start = sbq.getClosestValue(current, data.sizes.interpolate)
	local closestEnd, ending = sbq.getClosestValue(result, data.sizes.interpolate)

	local direction = 1
	if current > result then
		direction = -1
	end
	for i = start, ending, direction do
		local size = data.sizes.interpolate[i]
		table.insert(interpolationTable, size)
	end
	return interpolationTable
end

function sbq.interpolateLocation(location, tag)
	if type(sbq.locationInterpolation[location]) == "table" then
		sbq.locationInterpolation[location].time = sbq.locationInterpolation[location].time + sbq.dt
		local interpolationTable = sbq.locationInterpolation[location].interpolationTable
		local index = math.floor(sbq.locationInterpolation[location].time * sbq.locationInterpolation[location].speed) + 1
		if index ~= sbq.locationInterpolation[location].prevIndex then
			sbq.setPartTag("global", tag, tostring(interpolationTable[index]))
			sbq.locationInterpolation[location].prevIndex = index
		end
		if index >= #interpolationTable then
			sbq.locationInterpolation[location] = nil
		end
	end
end

function sbq.swapOccupants(a, b)
	local A = sbq.occupant[a]
	local B = sbq.occupant[b]
	sbq.occupant[a] = B
	sbq.occupant[b] = A

	sbq.swapCooldown = 10 -- p.unForceSeat and p.forceSeat are asynchronous, without some cooldown it'll try to swap multiple times and bad things will happen
end

function sbq.entityLounging( entity )
	for i = 0, sbq.occupantSlots do
		if entity == sbq.occupant[i].id then return true end
	end
	return false
end

function sbq.doBellyEffect(i, eid, dt, location, powerMultiplier)
	local locationEffect = sbq.settings[(location or "").."Effect"] or "sbqRemoveBellyEffects"
	local health = world.entityHealth(eid)
	local light = sbq.sbqData.lights.prey
	if light ~= nil then
		local lightPosition
		if light.position ~= nil then
			lightPosition = sbq.localToGlobal(light.position)
		else
			lightPosition = world.entityPosition( eid )
		end
		world.sendEntityMessage( eid, "sbqLight", sb.jsonMerge(light, {position = lightPosition}) )
	end

	if sbq.occupant[i].flags.digesting then
		locationEffect = (sbq.sbqData.locations[location].digest or {}).effect or "sbqDigest"
	end

	local status = (sbq.settings.displayDigest and sbq.config.bellyDisplayStatusEffects[locationEffect] ) or locationEffect

	if (sbq.settings[location.."Sounds"] == true) and (not sbq.occupant[i].flags.digested) then
		sbq.randomTimer("gurgle", 1.0, 8.0, function() animator.playSound("digest") end)
	end
	world.sendEntityMessage( eid, "sbqApplyDigestEffect", status, { power = powerMultiplier, location = location, dropItem = sbq.settings.predDigestItemDrops}, sbq.driver or entity.id())

	if sbq.settings[location.."Compression"] and not sbq.occupant[i].flags.digested and sbq.occupant[i].bellySettleDownTimer <= 0 then
		sbq.occupant[i].sizeMultiplier = math.min(1, math.max(0.1, sbq.occupant[i].sizeMultiplier - (powerMultiplier * dt)/100 ))
	end

	local progressbarDx = 0
	if sbq.occupant[i].progressBarActive == true then
		progressbarDx = (sbq.occupant[i].progressBarLocations[location] and (powerMultiplier * sbq.occupant[i].progressBarMultiplier)) or (-(powerMultiplier * sbq.occupant[i].progressBarMultiplier))
		sbq.occupant[i].progressBar = sbq.occupant[i].progressBar + dt * progressbarDx

		if sbq.occupant[i].progressBarMultiplier > 0 then
			sbq.occupant[i].progressBar = math.min(100, sbq.occupant[i].progressBar)
			if sbq.occupant[i].progressBar >= 100 and sbq.occupant[i].progressBarFinishFuncName ~= nil then
				sbq[sbq.occupant[i].progressBarFinishFuncName](i)
				sbq.occupant[i].flags[(sbq.occupant[i].progressBarFinishFlag or "transformed")] = true
				sbq.occupant[i].progressBarActive = false
			end
		else
			sbq.occupant[i].progressBar = math.max(0, sbq.occupant[i].progressBar)
			if sbq.occupant[i].progressBar <= 0 and sbq.occupant[i].progressBarFinishFuncName ~= nil then
				sbq[sbq.occupant[i].progressBarFinishFuncName](i)
				sbq.occupant[i].flags[(sbq.occupant[i].progressBarFinishFlag or "transformed")] = true
				sbq.occupant[i].progressBarActive = false
			end
		end
	else
		for j, passiveEffect in ipairs(sbq.sbqData.locations[location].passiveToggles or {}) do
			local data = sbq.sbqData.locations[location][passiveEffect]
			if sbq.settings[location..passiveEffect] and data and (not (sbq.occupant[i].flags[(data.occupantFlag or "transformed")] or sbq.occupant[i][location..passiveEffect.."Immune"])) then
				sbq.loopedMessage(location..passiveEffect..eid, eid, "sbqGetPreyEnabledSetting", {data.immunity or "transformAllow"}, function (enabled)
					if enabled then
						sbq[data.func or "transformMessageHandler"](eid, data, passiveEffect)
					else
						sbq.occupant[i][location..passiveEffect.."Immune"] = true
					end
				end, function ()
					sbq.occupant[i][location..passiveEffect.."Immune"] = true
				end)
			end
		end
	end

	sbq.occupant[i].indicatorCooldown = sbq.occupant[i].indicatorCooldown - dt

	if world.entityType(sbq.occupant[i].id) == "player" and sbq.occupant[i].indicatorCooldown <= 0 then
		-- p.occupant[i].indicatorCooldown = 0.5
		local struggledata = (sbq.stateconfig[sbq.state].struggle or {})[location..(sbq.occupant[i].locationSide or "")] or {}
		local directions = {}
		local icon
		if not sbq.transitionLock and sbq.occupant[i].species ~= "sbqEgg" then
			for dir, data in pairs(struggledata.directions or {}) do
				if data and (not sbq.driving or data.drivingEnabled) and ((data.settings == nil) or sbq.checkSettings(data.settings)) then
					if dir == "front" then dir = ({"left","","right"})[sbq.direction+2] end
					if dir == "back" then dir = ({"right","","left"})[sbq.direction+2] end
					if sbq.isNested and data.indicate == "red" then
						directions[dir] = "default"
					else
						directions[dir] = data.indicate or "default"
					end
				elseif data then
					if dir == "front" then dir = ({"left","","right"})[sbq.direction+2] end
					if dir == "back" then dir = ({"right","","left"})[sbq.direction+2] end
					directions[dir] = "default"
				end
			end
		end
		if sbq.occupant[i].species and sbq.occupant[i].species ~= "sbqOccupantHolder" then
			icon = "/vehicles/sbq/"..sbq.occupant[i].species.."/skins/"..((sbq.occupant[i].smolPreyData.settings.skinNames or {}).head or "default").."/icon.png"..((sbq.occupant[i].smolPreyData.settings or {}).directives or "")
		end
		sbq.openPreyHud(i, directions, progressbarDx, icon, location..(sbq.occupant[i].locationSide or ""))
	end
	sbq.otherLocationEffects(i, eid, health, locationEffect, status, location, powerMultiplier )
end

function sbq.openPreyHud(i, directions, progressbarDx, icon, location)
	sbq.loopedMessage(sbq.occupant[i].id .. "-indicator", sbq.occupant[i].id, -- update quickly but minimize spam
		"sbqOpenInterface", { "sbqIndicatorHud",
		{
			owner = entity.id(),
			directions = directions,
			progress = {
				active = sbq.occupant[i].progressBarActive,
				color = sbq.occupant[i].progressBarColor,
				percent = sbq.occupant[i].progressBar,
				dx = progressbarDx
			},
			icon = icon,
			time = sbq.occupant[i].visited.totalTime,
			location = (sbq.sbqData.locations[location] or {}).name
		}
	})
end

function sbq.validStruggle(struggler, dt)
	sbq.occupant[struggler].bellySettleDownTimer = math.max( 0, sbq.occupant[struggler].bellySettleDownTimer - dt)
	if (sbq.occupant[struggler].seatname == sbq.driverSeat) then return end


	if sbq.heldControl(sbq.occupant[struggler].seatname, "left") and sbq.heldControl(sbq.occupant[struggler].seatname, "right")
	and sbq.pressControl(sbq.occupant[struggler].seatname, "jump") then
		sbq.escapeScript(struggler)
		return
	end


	local movedir = sbq.getSeatDirections( sbq.occupant[struggler].seatname )
	if not (sbq.occupant[struggler].bellySettleDownTimer <= 0) then return end
	if not movedir then sbq.occupant[struggler].struggleTime = math.max( 0, sbq.occupant[struggler].struggleTime - dt) return end

	local struggling
	struggledata = sbq.stateconfig[sbq.state].struggle[(sbq.occupant[struggler].location or "")..(sbq.occupant[struggler].locationSide or "")]

	if (struggledata == nil or struggledata.directions == nil or struggledata.directions[movedir] == nil) then return end

	if struggledata.parts ~= nil then
		struggling = sbq.partsAreStruggling(struggledata.parts)
	end
	if (not struggling) and (struggledata.sided ~= nil) then
		local parts = struggledata.sided.rightParts
		if sbq.direction == -1 then
			parts = struggledata.sided.leftParts
		end
		struggling = sbq.partsAreStruggling(parts)
	end

	if struggling then return end

	if sbq.config.speciesStrugglesDisabled[config.getParameter("name")] then
		if sbq.isNested then return end
	else
		if (sbq.occupant[struggler].species ~= nil and sbq.config.speciesStrugglesDisabled[sbq.occupant[struggler].species]) or sbq.occupant[struggler].flags.digested then
			if not sbq.driving or world.entityType(sbq.driver) == "npc" then
				sbq.occupant[struggler].struggleTime = math.max(0, sbq.occupant[struggler].struggleTime + dt)
				if sbq.occupant[struggler].struggleTime > 1 then
					sbq.letout(sbq.occupant[struggler].id)
				end
			end
			return
		end
	end

	return movedir, struggledata
end

function sbq.handleStruggles(dt)
	if sbq.transitionLock then return end
	local struggler = -1
	local struggledata
	local movedir = nil

	while (movedir == nil) and struggler < sbq.occupantSlots do
		struggler = struggler + 1
		movedir, struggledata = sbq.validStruggle(struggler, dt)
	end

	if movedir == nil or struggledata == nil then return end -- invalid struggle

	local strugglerId = sbq.occupant[struggler].id

	if struggledata.script ~= nil then
		local statescript = state[sbq.state][struggledata.script]
		if statescript ~= nil then
			statescript({id = strugglerId, direction = movedir})
		else
			sbq.logError("no script named: ["..struggledata.script.."] in state: ["..sbq.state.."]")
		end
	end

	local animation = { offset = struggledata.directions[movedir].offset }
	local prefix = struggledata.prefix or ""
	local parts = struggledata.parts
	if struggledata.sided ~= nil then
		parts = struggledata.sided.rightParts
		if sbq.direction == -1 then
			parts = struggledata.sided.leftParts
		end
	end

	local time = 0.25
	if parts ~= nil then
		for _, part in ipairs(parts) do
			animation[part] = prefix .. "s_" .. movedir
		end
		for _, part in ipairs(struggledata.additionalParts or {}) do -- these are parts that it doesn't matter if it struggles or not, meant for multiple parts triggering the animation but never conflicting since it doesn't check if its struggling already or not
			animation[part] = prefix .. "s_" .. movedir
		end
		time = sbq.getLongestAnimationTime(animation, 0.25)
	end

	local entityType = world.entityType(strugglerId)
	if entityType == "player" then
		sbq.addNamedRPC(strugglerId.."ConsumeEnergy", world.sendEntityMessage(strugglerId, "sbqConsumeResource", "energy", time * 5), function (consumed)
			if consumed then
				sbq.doStruggle(struggledata, struggler, movedir, animation, strugglerId, time)
			end
		end)
	else
		sbq.doStruggle(struggledata, struggler, movedir, animation, strugglerId, time)
	end
end

function sbq.doStruggle(struggledata, struggler, movedir, animation, strugglerId, time)
	if sbq.struggleChance(struggledata, struggler, movedir, sbq.occupant[struggler].location ) then
		sbq.occupant[struggler].struggleTime = 0
		sbq.occupant[struggler].bellySettleDownTimer = 0.1
		sbq.doTransition( struggledata.directions[movedir].transition, {direction = movedir, id = strugglerId, struggleTrigger = true} )
	else
		local location = sbq.occupant[struggler].location

		if (struggledata.directions[movedir].indicate == "red" or struggledata.directions[movedir].indicate == "green") and ( struggledata.directions[movedir].settings == nil or sbq.checkSettings(struggledata.directions[movedir].settings) ) then
			sbq.occupant[struggler].controls.favorDirection = movedir
		elseif not struggledata.directions[movedir].indicate then
			sbq.occupant[struggler].controls.disfavorDirection = movedir
		end

		sbq.doAnims(animation)

		sbq.occupant[struggler].bellySettleDownTimer = time / 2
		sbq.occupant[struggler].struggleTime = sbq.occupant[struggler].struggleTime + time
		sbq.occupant[struggler].visited[location.."StruggleTime"] = (sbq.occupant[struggler].visited[location.."StruggleTime"] or 0) + time
		sbq.occupant[struggler].visited.totalStruggleTime = (sbq.occupant[struggler].visited.totalStruggleTime or 0) + time

		sbq.occupant[struggler].cumulative[location.."StruggleTime"] = (sbq.occupant[struggler].cumulative[location.."StruggleTime"] or 0) + time
		sbq.occupant[struggler].cumulative.totalStruggleTime = (sbq.occupant[struggler].cumulative.totalStruggleTime or 0) + time

		if sbq.settings[location.."Compression"] and not sbq.occupant[struggler].flags.digested then
			sbq.occupant[struggler].sizeMultiplier = sbq.occupant[struggler].sizeMultiplier + (time * 2)/100
		end

		if not sbq.movement.animating then
			sbq.doAnims( struggledata.directions[movedir].animation or struggledata.animation )
		else
			sbq.doAnims( struggledata.directions[movedir].animationWhenMoving or struggledata.animationWhenMoving )
		end

		sbq.struggleMessages(strugglerId)

		if struggledata.directions[movedir].victimAnimation then
			local id = strugglerId
			if struggledata.directions[movedir].victimAnimLocation ~= nil then
				id = sbq.findFirstOccupantIdForLocation(struggledata.directions[movedir].victimAnimLocation)
			end
			sbq.doVictimAnim( id, struggledata.directions[movedir].victimAnimation, (struggledata.parts[1] or "body").."State" )
		end

		local sound = struggledata.sound
		if struggledata.directions[movedir].sound ~= nil then
			sound = struggledata.directions[movedir].sound
		end
		if sound ~= false then
			animator.playSound( sound or "struggle" )
		end
	end
end

function sbq.struggleChance(struggledata, struggler, movedir, location)
	if not ((struggledata.directions[movedir].settings == nil) or sbq.checkSettings(struggledata.directions[movedir].settings) ) then return false end

	local chances = struggledata.chances
	if struggledata.directions[movedir].chances ~= nil then
		chances = struggledata.directions[movedir].chances
	end
	if chances ~= nil and chances.max == 0 then return true end
	if sbq.settings.impossibleEscape then return false end
	if sbq.driving and not struggledata.directions[movedir].drivingEnabled then return false end

	local escapeDifficulty = ((sbq.settings.escapeDifficulty or 0) + (sbq.settings[location.."DifficultyMod"] or 0))
	return chances ~= nil and (chances.min ~= nil) and (chances.max ~= nil)
	and (math.random(math.floor(chances.min + escapeDifficulty), math.ceil(chances.max + escapeDifficulty)) <= (sbq.occupant[struggler].struggleTime or 0))
end

function sbq.inedible(occupantId)
	return sbq.config.inedibleCreatures[world.entityType(occupantId)]
end

function sbq.removeOccupantsFromLocation(location)
	for i = 0, #sbq.occupant do
		if sbq.occupant[i].location == location then
			sbq.uneat(sbq.occupant[i].id)
		end
	end
end
