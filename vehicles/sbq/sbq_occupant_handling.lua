function sbq.forceSeat( occupantId, seatindex, predPrey, delay )
	if occupantId then
		local seatname = "occupant" .. seatindex
		vehicle.setLoungeEnabled(seatname, true)
		vehicle.setItemBlacklist(seatname, sbq.config2[predPrey].itemBlacklist)
		vehicle.setItemWhitelist(seatname, sbq.config2[predPrey].itemWhitelist)
		vehicle.setItemTagBlacklist(seatname, sbq.config2[predPrey].itemTagBlacklist)
		vehicle.setItemTagWhitelist(seatname, sbq.config2[predPrey].itemTagWhitelist)
		vehicle.setItemTypeBlacklist(seatname, sbq.config2[predPrey].itemTypeBlacklist)
		vehicle.setItemTypeWhitelist(seatname, sbq.config2[predPrey].itemTypeWhitelist)
		vehicle.setToolUsageSuppressed(seatname, sbq.config2[predPrey].toolUsageSuppressed)
		sbq.timer(seatname.."forceSit", delay or 0, function ()
			vehicle.setLoungeEnabled(seatname, true)
			world.sendEntityMessage(occupantId, "sbqForceSit", { index = seatindex, source = entity.id() })
		end)
	end
end

function sbq.eat( args, voreType, location, locationSide )
	local seatindex = math.floor(sbq.occupants.total + sbq.startSlot)
	if seatindex > sbq.occupantSlots then return false end
	local locationSpace = sbq.locationSpaceAvailable(location, locationSide)

	if (locationSpace < ((args.size or 1) * (sbq.getLocationSetting(location, "Multiplier", 1)))) and not args.force then return false end

	if (not args.id) or (not world.entityExists(args.id))
	or ((sbq.entityLounging(args.id) or sbq.inedible(args.id)) and not args.force)
	then return false end

	local loungeables = world.entityQuery( world.entityPosition(args.id), 5, {
		withoutEntityId = entity.id(), includedTypes = { "vehicle" },
		callScript = "sbq.entityLounging", callScriptArgs = { args.id }
	} )

	local edibles = world.entityQuery( world.entityPosition(args.id), 2, {
		withoutEntityId = entity.id(), includedTypes = { "vehicle" },
		callScript = "sbq.edible", callScriptArgs = { args.id, seatindex, entity.id(), args.force}
	})
	sbq.occupant[seatindex].force = args.force
	if edibles[1] == nil then
		if loungeables[1] == nil then -- now just making sure the prey doesn't belong to another loungable now
			sbq.gotEaten(args, voreType, location, locationSide, seatindex)
			sbq.addRPC(world.sendEntityMessage(args.id, "sbqGetSpeciesVoreConfig"), function (data)
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
	sbq.gotEaten(args, voreType, location, locationSide, seatindex)
	sbq.occupant[seatindex].species = species
	return true
end

function sbq.gotEaten(args, voreType, location, locationSide, seatindex)
	local entityType = world.entityType(args.id)
	if entityType == "player" then
		if args.keepWindow then
			world.sendEntityMessage( args.id, "sbqOpenInterface", "sbqClose", nil, sbq.driver )
		end
		sbq.addRPC(world.sendEntityMessage(args.id, "sbqGetCumulativeOccupancyTimeAndFlags", sbq.spawnerUUID),
		function(data)
			if not data then return end
			sbq.occupant[seatindex].cumulative = data.times or {}
			sbq.occupant[seatindex].flags = sb.jsonMerge(sbq.occupant[seatindex].flags or {}, data.flags or {} )
		end)
	else
		sbq.addRPC(world.sendEntityMessage(sbq.spawner, "sbqGetCumulativeOccupancyTimeAndFlags", world.entityUniqueId(args.id), true),
		function(data)
			if not data then return end
			sbq.occupant[seatindex].cumulative = data.times or {}
			sbq.occupant[seatindex].flags = sb.jsonMerge(sbq.occupant[seatindex].flags or {}, data.flags or {} )
		end)
	end
	world.sendEntityMessage(args.id, "sbqSetType", "prey")

	sbq.occupant[seatindex].id = args.id
	sbq.occupant[seatindex].location = location
	sbq.occupant[seatindex].locationSide = locationSide
	sbq.occupant[seatindex].size = args.size or 1
	sbq.occupant[seatindex].entryType = voreType
	sbq.occupant[seatindex].flags.hostile = args.hostile
	sbq.occupant[seatindex].flags.willing = args.willing
	world.sendEntityMessage( args.id, "sbqMakeNonHostile")
	sbq.forceSeat( args.id, seatindex, "prey" )
	sbq.refreshList = true
end

function sbq.uneat( occupantId )
	if occupantId == nil or not world.entityExists(occupantId) then return end
	world.sendEntityMessage( occupantId, "sbqClearDrawables")
	world.sendEntityMessage( occupantId, "applyStatusEffect", "sbqRemoveBellyEffects")
	world.sendEntityMessage( occupantId, "primaryItemLock", false)
	world.sendEntityMessage( occupantId, "altItemLock", false)
	world.sendEntityMessage( occupantId, "sbqLight", nil )
	if not sbq.lounging[occupantId] then return end

	local seatindex = sbq.lounging[occupantId].index
	local occupantData = sbq.lounging[occupantId]

	vehicle.setLoungeEnabled(sbq.lounging[occupantId].seatname, false)

	if world.entityType(occupantId) == "player" then
		world.sendEntityMessage(occupantId, "sbqOpenInterface", "sbqClose")
	end
	world.sendEntityMessage(occupantId, "sbqSetType", nil)

	if occupantData.species ~= nil and occupantData.smolPreyData ~= nil then
		if type(occupantData.smolPreyData.id) == "number" and world.entityExists(occupantData.smolPreyData.id) then
			world.sendEntityMessage(occupantData.smolPreyData.id, "uneaten")
		else
			world.spawnVehicle( occupantData.species, sbq.localToGlobal({ occupantData.victimAnim.last.x or 0, occupantData.victimAnim.last.y or 0}), { driver = occupantId, settings = occupantData.smolPreyData.settings, uneaten = true, startState = occupantData.smolPreyData.state, layer = occupantData.smolPreyData.layer, scale = mcontroller.scale() })
		end
	else
		world.sendEntityMessage(occupantId, "sbqRemoveStatusEffects", sbq.config.predStatusEffects, (occupantData.flags.digested or occupantData.flags.infused) and sbq.settings.reformResetHealth and not (occupantData.flags.hostile and sbq.settings.overrideSoftDigestForHostiles))
		world.sendEntityMessage( occupantId, "sbqPredatorDespawned" ) -- to clear the current data for players
	end

	world.sendEntityMessage(occupantId, "sbqSetCumulativeOccupancyTime", sbq.spawnerUUID, world.entityName(sbq.spawner), world.entityType(sbq.spawner), world.entityTypeName(sbq.spawner), false, sbq.lounging[occupantId].cumulative )
	world.sendEntityMessage(sbq.spawner, "sbqSetCumulativeOccupancyTime", world.entityUniqueId(occupantId), world.entityName(occupantId), world.entityType(occupantId), world.entityTypeName(occupantId), true, sbq.lounging[occupantId].cumulative)

	world.sendEntityMessage(occupantId, "sbqCheckPreyRewards", sbq.trimOccupantData(sbq.lounging[occupantId]), sbq.spawner, entity.id() )
	world.sendEntityMessage(sbq.spawner, "sbqCheckRewards", sbq.trimOccupantData(sbq.lounging[occupantId]) )

	sbq.refreshList = true
	sbq.lounging[occupantId] = nil
	sbq.occupant[seatindex] = sbq.clearOccupant(seatindex)
	return true
end

function sbq.edible(occupantId, seatindex, source, force)
	if not sbq.stateconfig then return false end
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
		world.sendEntityMessage( sbq.driver, "sbqOpenInterface", "sbqClose", nil, entity.id() )
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
	if not args.id or (space < ((sbq.lounging[args.id].size or 1) * (sbq.getLocationSetting(location, "Multiplier", 1)))) then return false end

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
		if sbq.getLocationSetting(location, "Symmetrical", data.symmetrical) or not side then
			locationSize = math.max(sbq.occupants[location.."L"], sbq.occupants[location.."R"])
		else
			locationSize = sbq.occupants[location..(side or "L")]
		end
	end
	local minMaxed = math.max(math.max(((sbq.getLocationSetting(location,  "VisualMin", 0)) + ( (sbq.getLocationSetting(location, "InfusedSize") and ((((sbq.getLocationSetting(location, "InfusedItem", {})).parameters or {}).preySize or 0) * (sbq.getLocationSetting(location, "InfusedMultiplier", 0.5)))) or 0 ) ), data.minVisual or 0),
		math.min((locationSize / sbq.predScale), sbq.getLocationSetting(location, "VisualMax") or data.maxVisual or data.max or
			math.huge))

	if data.sizes then
		return sbq.getClosestValue(minMaxed, data.sizes.struggle)
	else
		return math.floor(minMaxed+0.4)
	end
end

function sbq.locationSpaceAvailable(location, side)
	if sbq.getLocationSetting(location, "Hammerspace") and sbq.sbqData.locations[location].hammerspace then
		return math.huge
	end
	return (((sbq.sbqData.locations[location..(side or "")] or {}).max or 0) * (sbq.predScale or 1)) - (sbq.occupants[location..(side or "")] or 0)
end

function sbq.getSidedLocationWithSpace(location, size)
	local data = sbq.sbqData.locations[location] or {}
	local sizeMultiplied = ((size or 1) * (sbq.getLocationSetting(location, "Multiplier", 1) ))
	if data.sided then
		local leftHasSpace = sbq.locationSpaceAvailable(location, "L") > sizeMultiplied
		local rightHasSpace = sbq.locationSpaceAvailable(location, "R") > sizeMultiplied
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
	else
		if sbq.locationSpaceAvailable(location, "") > sizeMultiplied then
			return location, "", data
		end
	end
	return false
end

function sbq.doVore(args, location, statuses, sound, voreType )
	if sbq.isNested then return false end
	local location = location
	local locationSide
	if not args.force then
		location, locationSide = sbq.getSidedLocationWithSpace(location, args.size)
	end
	if not location then return false end
	if sbq.eat(args, voreType, location, locationSide) then
		sbq.justAte = args.id
		vehicle.setInteractive( false )
		sbq.showEmote("emotehappy")
		sbq.transitionLock = true
		world.sendEntityMessage( args.id, "sbqApplyStatusEffects", statuses )

		local settings = {
			voreType = voreType or "default",
			predator = sbq.species,
			location = location,
			entryType = voreType,
			willing = args.willing or false,
			hostile = args.hostile or false,
		}
		local entityType = world.entityType(args.id)
		local sayLine = entityType == "npc" or entityType == "player" and type(sbq.driver) == "number" and world.entityExists(sbq.driver)

		if sayLine then world.sendEntityMessage( args.id, "sbqSayRandomLine", sbq.driver, sb.jsonMerge(sbq.settings, settings), ".vored", true ) end

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
	local sayLine = (entityType == "npc" or entityType == "player") and type(sbq.driver) == "number" and world.entityExists(sbq.driver)

	if sayLine then world.sendEntityMessage( sbq.driver, "sbqSayRandomLine", args.id, settings, ".letout", true ) end
	sbq.lounging[victim].location = "escaping"

	vehicle.setInteractive( false )
	world.sendEntityMessage( victim, "sbqApplyStatusEffects", statuses )
	sbq.transitionLock = true
	return true, function()
		if sayLine then world.sendEntityMessage( args.id, "sbqSayRandomLine", sbq.driver, sb.jsonMerge(sbq.settings, settings), ".escape", false) end
		sbq.transitionLock = false
		sbq.checkDrivingInteract()
		sbq.uneat( victim )
		world.sendEntityMessage( victim, "sbqApplyStatusEffects", afterstatuses )
	end
end

function sbq.applyStatusLists()
	for i = 0, sbq.occupantSlots do
		if type(sbq.occupant[i].id) == "number" and world.entityExists(sbq.occupant[i].id) then
			sbq.loopedMessage( sbq.occupant[i].seatname.."StatusEffects", sbq.occupant[i].id, "sbqApplyStatusEffects", {sbq.occupant[i].statList} )
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
		sbq.occupantCount[location] = 0
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

			if sbq.occupant[i].visited.totalTime >= 900 and not sbq.occupant[i].player then
				sbq.occupant[i].player = world.entityType(sbq.occupant[i].id) == "player"
				if not sbq.occupant[i].player then
					sbq.timer("letOut"..sbq.occupant[i].id, 1, function()
						sbq.letout(sbq.occupant[i].id)
					end)
				end
			end

			local massMultiplier = 0
			local mass = sbq.occupant[i].controls.mass
			local location = sbq.occupant[i].location
			local sidedLocation = location .. (sbq.occupant[i].locationSide or "")

			if location == "escaping" then
			elseif not sbq.occupant[i].force and ((location == nil) or (sbq.sbqData.locations[location] == nil) or ((sbq.sbqData.locations[location].max or 0) == 0)) then
				sbq.uneat(sbq.occupant[i].id)
			else
				sbq.doBellyEffect(i, sbq.occupant[i].id, dt, location, powerMultiplier)

				sbq.occupant[i].visited[location .. "Visited"] = true
				sbq.occupant[i].visited[location .. "Time"] = (sbq.occupant[i].visited[location .. "Time"] or 0) + dt
				sbq.occupant[i].cumulative[location .. "Time"] = (sbq.occupant[i].cumulative[location .. "Time"] or 0) + dt

				local size = ((sbq.occupant[i].size * sbq.occupant[i].sizeMultiplier) * (sbq.getLocationSetting(location, "Multiplier", 1) ))
				sbq.occupants[sidedLocation] = (sbq.occupants[sidedLocation] or 0) + size
				sbq.occupants.totalSize = sbq.occupants.totalSize + size
				sbq.occupantCount.total = sbq.occupantCount.total + 1
				sbq.occupantCount[sidedLocation] = (sbq.occupantCount[sidedLocation] or 0) + 1

				massMultiplier = sbq.sbqData.locations[location].mass or 0

				sbq.occupants.mass = sbq.occupants.mass + mass * massMultiplier

				if sbq.sbqData.locations[location].transformGroups ~= nil then
					sbq.copyTransformationFromGroupsToGroup(sbq.sbqData.locations[location].transformGroups, seatname .. "Position")
				end
			end

			if sbq.timer(seatname .. "PreyRewards", 30) and sbq.driving and world.entityType(sbq.driver) == "player" then
				if sbq.occupant[i].id then
					world.sendEntityMessage(sbq.occupant[i].id, "sbqCheckPreyRewards", sbq.trimOccupantData(sbq.occupant[i]), sbq.spawner, entity.id() )
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

function sbq.infusedStruggleDialogue(location, data, npcArgs, eid)
	if (sbq.totalTimeAlive > 0.5) then
		if (math.random() > 0.5) then
			local dialogue, tags, imagePortrait = sbq.getNPCDialogue(".infused", location, data, npcArgs) -- this will change to its own part of the tree
			world.spawnMonster("sbqDummySpeech", mcontroller.position(), {
				parent = entity.id(), offset = (((sbq.stateconfig[sbq.state] or {}).locationCenters or {})[location]),
				sayLine = dialogue, sayTags = tags, sayImagePortait = imagePortrait, sayAppendName = npcArgs.npcParam.identity.name
			})
		else
			world.sendEntityMessage(sbq.driver, "sbqSayRandomLine", nil, {location = location, predator = sbq.species, race = npcArgs.npcSpecies}, ".teaseInfused", true )
		end
	end
	if (not eid) or ((type(eid)=="number") and (world.entityType(eid)~="player")) then
		sbq.doLocationStruggle(location, data)
	end
end

function sbq.setOccupantTags()
	for location, occupancy in pairs(sbq.occupants) do
		sbq.occupants[location] = sbq.occupants[location] + (sbq.getLocationSetting(location, "VisualMinAdditive") and sbq.getLocationSetting(location, "VisualMin") or 0)
		sbq.occupants[location] = sbq.occupants[location] + ((sbq.getLocationSetting(location, "InfusedSizeAdditive") and (sbq.getLocationSetting(location, "InfusedItem", {}).parameters or {}).preySize or 0) * (sbq.getLocationSetting(location, "InfusedMultiplier", 0.5)))
		sbq.actualOccupants[location] = sbq.occupants[location]
	end
	-- because of the fact that pairs feeds things in a random ass order we need to make sure these have tripped on every location *before* setting the occupancy tags or checking the expand/shrink queue
	for location, data in pairs(sbq.sbqData.locations) do
		if data.useOccupantCount then
			sbq.occupants[location] = sbq.occupantCount[location]
		end
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
		local npcArgs = ((sbq.getLocationSetting(location, "InfusedItem", {})).parameters or {}).npcArgs
		if data.infusion and sbq.settings[data.infusionSetting.."Pred"] and npcArgs and (((npcArgs or {}).npcParam or {}).identity or {}).name then
			if sbq.randomTimer(location .. "InfusedStruggleDialogue", 15, 60) and sbq.checkSettings(data.checkSettings) then
				local uniqueId = ((npcArgs.npcParam or {}).scriptConfig or {}).uniqueId
				if not uniqueId then return end
				local eid = world.loadUniqueEntity(uniqueId)
				if (not eid) or (type(eid)=="number" and (sbq.lounging[eid]) or (not entity.entityInSight(eid))) then
					sbq.infusedStruggleDialogue(location, data, npcArgs, eid)
				end
			end
		end

		if data.sided then
			if sbq.getLocationSetting(location, "Symmetrical", data.symmetrical) then -- for when people want their balls and boobs to be the same size
				local setTag = sbq.interpolateLocation(location, location .. "FrontOccupantsInterpolate")
				if setTag then
					sbq.setPartTag("global", location .. "BackOccupantsInterpolate", setTag)
				end

				if sbq.occupantsVisualSize[location] ~= sbq.occupantsPrevVisualSize[location] then
					local size = tostring(sbq.occupantsVisualSize[location])
					sbq.setPartTag( "global", location.."FrontOccupants", size )
					sbq.setPartTag( "global", location.."BackOccupants", size )
				end

				if sbq.occupantsVisualSize[location] > sbq.occupantsPrevVisualSize[location] then
					sbq.setLocationInterpolation(location, data, sbq.expandQueue[location] or (sbq.stateconfig[sbq.state].expandAnims or {})[location])
				elseif sbq.occupantsVisualSize[location] < sbq.occupantsPrevVisualSize[location] then
					sbq.setLocationInterpolation(location, data, sbq.shrinkQueue[location] or (sbq.stateconfig[sbq.state].shrinkAnims or {})[location])
				end

			else

				sbq.occupantsVisualSize[location.."L"] = sbq.locationVisualSize(location, "L")
				sbq.occupantsVisualSize[location .. "R"] = sbq.locationVisualSize(location, "R")
				local flipped = sbq.direction ~= sbq.prevDirection

				if sbq.direction > 0 then -- to make sure those in the balls in CV and breasts in BV cases stay on the side they were on instead of flipping
					if sbq.occupantsVisualSize[location.."R"] ~= sbq.occupantsPrevVisualSize[location.."R"] or flipped  then
						sbq.setPartTag("global", location .. "FrontOccupants", tostring(sbq.occupantsVisualSize[location .. "R"]))
					end
					sbq.interpolateLocation(location.."R", location .. "FrontOccupantsInterpolate", flipped)

					if sbq.occupantsVisualSize[location.."L"] ~= sbq.occupantsPrevVisualSize[location.."L"] or flipped then
						sbq.setPartTag( "global", location.."BackOccupants", tostring(sbq.occupantsVisualSize[location.."L"]) )
					end
					sbq.interpolateLocation(location.."L", location .. "BackOccupantsInterpolate", flipped)

				else
					if sbq.occupantsVisualSize[location.."R"] ~= sbq.occupantsPrevVisualSize[location.."R"] or flipped then
						sbq.setPartTag( "global", location.."BackOccupants", tostring(sbq.occupantsVisualSize[location.."R"]) )
					end
					sbq.interpolateLocation(location.."R", location .. "BackOccupantsInterpolate", flipped)

					if sbq.occupantsVisualSize[location.."L"] ~= sbq.occupantsPrevVisualSize[location.."L"] or flipped then
						sbq.setPartTag( "global", location.."FrontOccupants", tostring(sbq.occupantsVisualSize[location.."L"]) )
					end
					sbq.interpolateLocation(location.."L", location .. "FrontOccupantsInterpolate", flipped)

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

		elseif not data.side then

			if sbq.occupantsVisualSize[location] ~= sbq.occupantsPrevVisualSize[location] then
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
	sbq.prevDirection = sbq.direction
end

sbq.locationInterpolation = {}
function sbq.setLocationInterpolation(location, data, animations)
	if not animations then return end
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

function sbq.interpolateLocation(location, tag, update)
	local setTag
	if type(sbq.locationInterpolation[location]) == "table" then
		sbq.locationInterpolation[location].time = sbq.locationInterpolation[location].time + sbq.dt
		local interpolationTable = sbq.locationInterpolation[location].interpolationTable
		local index = math.floor(sbq.locationInterpolation[location].time * sbq.locationInterpolation[location].speed) + 1
		if index ~= sbq.locationInterpolation[location].prevIndex then
			sbq.locationInterpolation[location].prevIndex = index
		end
        if index > #interpolationTable then
            sbq.locationInterpolation[location] = nil
        else
			setTag = tostring(interpolationTable[index])
		end
    end
	setTag = setTag or tostring(sbq.occupantsVisualSize[location] or 0)
	sbq.setPartTag("global", tag, setTag)
	return setTag
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
	if sbq.occupant[i].flags.infused then
		sbq.loopedMessage(eid.."LocationEffectLoop", eid, "applyStatusEffect", {"sbqRemoveBellyEffects"})
		return sbq.infusedLocationEffects(i, eid, health, locationEffect, location, powerMultiplier)
	end
	if sbq.occupant[i].flags.digesting or (sbq.occupant[i].flags.hostile and sbq.settings.overrideSoftDigestForHostiles and (sbq.settings[location.."EffectSlot"] == "softDigest")) then
		locationEffect = (sbq.sbqData.locations[location].digest or {}).effect or "sbqDigest"
	elseif sbq.occupant[i].flags.healing then
		locationEffect = (sbq.sbqData.locations[location].heal or {}).effect or "sbqHeal"
	end

	local effects = {locationEffect}
	local args = {
		power = powerMultiplier,
		location = location,
		dropItem = sbq.getLocationSetting(location, "PredDigestDrops"),
		absorbPlayers = sbq.getLocationSetting(location, "AbsorbPlayers"),
		absorbOCs =  sbq.getLocationSetting(location, "AbsorbOCs"),
		absorbSBQNPCs = sbq.getLocationSetting(location, "AbsorbSBQNPCs"),
		absorbOthers =  sbq.getLocationSetting(location, "AbsorbOthers")
	}
	if (sbq.getLocationSetting(location, "Sounds")) and (not sbq.occupant[i].flags.digested) then
		sbq.randomTimer("gurgle", 1.0, 8.0, function() animator.playSound("digest") end)
	end

	local compression = sbq.getLocationSetting(location, "Compression")

	if ( compression == "time") and not sbq.occupant[i].flags.digested and sbq.occupant[i].bellySettleDownTimer <= 0 then
		sbq.occupant[i].sizeMultiplier = math.min(1,
			math.max(sbq.getLocationSetting(location, "CompressionMultiplier", 0.25), sbq.occupant[i].sizeMultiplier - (powerMultiplier * dt * 0.01)))
	end
	if ( compression == "health") and not sbq.occupant[i].flags.digested then
		sbq.occupant[i].sizeMultiplier = math.min(1,
			math.max(sbq.getLocationSetting(location, "CompressionMultiplier", 0.25), (health[1] / health[2])))
	end


	local progressbarDx = 0
	if sbq.occupant[i].progressBarActive == true then
		progressbarDx = (sbq.occupant[i].progressBarLocations[location] and (powerMultiplier * sbq.occupant[i].progressBarMultiplier)) or (-(powerMultiplier * sbq.occupant[i].progressBarMultiplier))
		sbq.occupant[i].progressBar = sbq.occupant[i].progressBar + dt * progressbarDx
		sbq.occupant[i].flags[sbq.occupant[i].progressBarType] = sbq.occupant[i].progressBar / 100
		sbq.occupant[i].progressBar = math.min(100, sbq.occupant[i].progressBar)
		if sbq.occupant[i].progressBar >= 100 and sbq.occupant[i].progressBarFinishFuncName ~= nil then
			sbq[sbq.occupant[i].progressBarFinishFuncName](i)
			sbq.occupant[i].progressBarActive = false
		end
	else
		for j, passiveEffect in ipairs(sbq.sbqData.locations[location].passiveToggles or {}) do
			local data = sbq.sbqData.locations[location][passiveEffect]
			if data and data.effect and sbq.getLocationSetting(location, passiveEffect) then
				table.insert(effects, data.effect)
			elseif sbq.getLocationSetting(location, passiveEffect) and data and (sbq.occupant[i].flags[data.occupantFlag] == nil) and (not sbq.occupant[i].progressBarActive) and (not sbq.occupant[i][passiveEffect.."Immune"]) then
				sbq.loopedMessage(passiveEffect..eid, eid, "sbqGetPreyEnabledSetting", {data.immunity or "transformAllow"}, function (enabled)
					if enabled then
						sbq[data.func or "transformMessageHandler"](eid, data, passiveEffect)
					else
						sbq.occupant[i][passiveEffect.."Immune"] = true
					end
				end, function ()
					sbq.occupant[i][passiveEffect.."Immune"] = true
				end)
			end
		end
	end

	sbq.loopedMessage(eid.."LocationExtraEffectLoop", eid, "sbqApplyDigestEffects", {effects, args, sbq.driver or entity.id()})


	sbq.occupant[i].indicatorCooldown = sbq.occupant[i].indicatorCooldown - dt

	if world.entityType(sbq.occupant[i].id) == "player" and sbq.occupant[i].indicatorCooldown <= 0 then
		-- p.occupant[i].indicatorCooldown = 0.5
		local struggledata = (sbq.stateconfig[sbq.state].struggle or {})[location..(sbq.occupant[i].locationSide or "")] or {}
		local directions = {}
		local icon
		if not sbq.transitionLock and sbq.occupant[i].species ~= "sbqEgg" and (not sbq.occupant[i].flags.infused) then
			for dir, data in pairs(struggledata.directions or {}) do
				if data and (not sbq.driving or data.drivingEnabled) and (sbq.checkSettings(data.settings)) then
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
			icon = "/vehicles/sbq/"..sbq.occupant[i].species.."/skins/"..(((sbq.occupant[i].smolPreyData.settings or {}).skinNames or {}).head or "default").."/icon.png"..((sbq.occupant[i].smolPreyData.settings or {}).directives or "")
		end
		sbq.openPreyHud(i, directions, progressbarDx, icon, location..(sbq.occupant[i].locationSide or ""))
	end
	sbq.otherLocationEffects(i, eid, health, locationEffect, location, powerMultiplier )
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
	if not movedir then
		sbq.occupant[struggler].visited.struggleTime = math.max(0, sbq.occupant[struggler].visited.struggleTime - dt)
		sbq.occupant[struggler].visited.sinceLastStruggle = sbq.occupant[struggler].visited.struggleTime + dt
		return
	else
		sbq.occupant[struggler].visited.sinceLastStruggle = 0
	end

	local infusedNonPlayer = (sbq.occupant[struggler].flags.infused and world.entityType(sbq.occupant[struggler].id) ~= "player")

	if sbq.config.speciesStrugglesDisabled[config.getParameter("name")] then
		if sbq.isNested then return end
	else
		if (sbq.occupant[struggler].species ~= nil and sbq.config.speciesStrugglesDisabled[sbq.occupant[struggler].species]) or (sbq.occupant[struggler].flags.digested or infusedNonPlayer) then
			if not sbq.driving or world.entityType(sbq.driver) == "npc" then
				sbq.occupant[struggler].visited.struggleTime = math.max(0, sbq.occupant[struggler].visited.struggleTime + dt)
				if sbq.occupant[struggler].visited.struggleTime > 1 then
					sbq.letout(sbq.occupant[struggler].id)
				end
			end
			return
		end
	end

	local struggling
	struggledata = sbq.stateconfig[sbq.state].struggle[(sbq.occupant[struggler].location or "")..(sbq.occupant[struggler].locationSide or "")]

	if (sbq.occupant[struggler].flags.digested or infusedNonPlayer) or (struggledata == nil or struggledata.directions == nil or struggledata.directions[movedir] == nil) then return end

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
		time = sbq.getLongestAnimationTime(animation, 0.25)

		for _, part in ipairs(struggledata.additionalParts or {}) do -- these are parts that it doesn't matter if it struggles or not, meant for multiple parts triggering the animation but never conflicting since it doesn't check if its struggling already or not
			animation[part] = prefix .. "s_" .. movedir
		end
	end

	local entityType = world.entityType(strugglerId)
	if entityType == "player" or entityType == "npc" then
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
		sbq.occupant[struggler].visited.struggleTime = 0
		sbq.occupant[struggler].bellySettleDownTimer = 0.1
		sbq.doTransition( struggledata.directions[movedir].transition, {direction = movedir, id = strugglerId, struggleTrigger = true} )
	else
		local location = sbq.occupant[struggler].location
		local locationData = sbq.sbqData.locations[location] or {}

		if (struggledata.directions[movedir].indicate == "red" or struggledata.directions[movedir].indicate == "green") and
			(sbq.checkSettings(struggledata.directions[movedir].settings)) then
			local isPlayerDriver = sbq.driver and world.entityType(sbq.driver) == "player"
			if sbq.occupant[struggler].flags.willing and (isPlayerDriver or sbq.occupant[struggler].visited.totalTime < 600) then
				sbq.occupant[struggler].controls.disfavorDirection = movedir
			else
				sbq.occupant[struggler].controls.favorDirection = movedir
			end
		elseif not struggledata.directions[movedir].indicate then
			sbq.occupant[struggler].controls.disfavorDirection = movedir
		elseif sbq.occupant[struggler].flags.hostile then
			sbq.occupant[struggler].controls.disfavorDirection = movedir
		end

		sbq.doAnims(animation)

		if locationData.satisfiesPred and sbq.driver then
			world.sendEntityMessage(sbq.driver, "sbqAddToResources", time, locationData.satisfiesPred)
		end
		if locationData.satisfiesPrey then
			world.sendEntityMessage(strugglerId, "sbqAddToResources", time, locationData.satisfiesPrey)
		end


		sbq.occupant[struggler].bellySettleDownTimer = time / 2
		sbq.occupant[struggler].visited.struggleTime = sbq.occupant[struggler].visited.struggleTime + time
		sbq.occupant[struggler].visited[location.."StruggleTime"] = (sbq.occupant[struggler].visited[location.."StruggleTime"] or 0) + time
		sbq.occupant[struggler].visited.totalStruggleTime = (sbq.occupant[struggler].visited.totalStruggleTime or 0) + time

		sbq.occupant[struggler].cumulative[location.."StruggleTime"] = (sbq.occupant[struggler].cumulative[location.."StruggleTime"] or 0) + time
		sbq.occupant[struggler].cumulative.totalStruggleTime = (sbq.occupant[struggler].cumulative.totalStruggleTime or 0) + time

		if sbq.getLocationSetting(location, "Compression") and not sbq.occupant[struggler].flags.digested then
			sbq.occupant[struggler].sizeMultiplier = math.min(1,(sbq.occupant[struggler].sizeMultiplier + (time * 2)/100))
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
		if sound ~= false and sbq.getLocationSetting(location, "StruggleSounds") then
			animator.playSound( sound or "struggle" )
		end
	end
end

function sbq.struggleChance(struggledata, struggler, movedir, location)
	if sbq.occupant[struggler].flags.infused or not ( sbq.checkSettings(struggledata.directions[movedir].settings) ) then return false end

	local chances = struggledata.chances
	if struggledata.directions[movedir].chances ~= nil then
		chances = struggledata.directions[movedir].chances
	end
	if chances ~= nil and chances.max == 0 then return true end
	if sbq.settings.impossibleEscape then return false end
	if sbq.driving and not struggledata.directions[movedir].drivingEnabled then return false end

	local escapeDifficulty = ((sbq.settings.escapeDifficulty or 0) + (sbq.getLocationSetting(location, "DifficultyMod", 0)))
	return chances ~= nil and (chances.min ~= nil) and (chances.max ~= nil)
	and (math.random(math.floor(chances.min + escapeDifficulty), math.ceil(chances.max + escapeDifficulty)) <= (sbq.occupant[struggler].visited.struggleTime or 0))
end

function sbq.inedible(occupantId)
	return sbq.config.inedibleCreatures[world.entityTypeName(occupantId)]
end

function sbq.removeOccupantsFromLocation(location)
	for i = 0, #sbq.occupant do
		if sbq.occupant[i].location == location then
			sbq.uneat(sbq.occupant[i].id)
		end
	end
end
