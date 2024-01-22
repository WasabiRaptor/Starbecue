sbq.controlsPressed = {}
sbq.controlsReleased = {}
function controlPressed(seat, control, time)
	-- sbq.logJson({seat,control,time})
	if seat == sbq.driverSeat then
		if control == "Special2" then
			sbq.letout()
		end
    end
	sbq.controlsPressed = sb.jsonMerge(sbq.controlsPressed, {[seat] = {[control] = time}})
end
function controlReleased(seat, control, time)
	sbq.controlsReleased = sb.jsonMerge(sbq.controlsReleased, {[seat] = {[control] = time}})
end


function sbq.pressControl(seat, control)
	return sb.jsonQuery(sbq.controlsPressed, seat.."."..control)
end

function sbq.tapControl(seat, control)
    local released = sb.jsonQuery(sbq.controlsReleased, seat .. "." .. control)
	return released and (released < 0.19)
end

function sbq.heldControl(seat, control, min)
	return vehicle.controlHeld(seat, control) and (vehicle.controlHeldTime(seat, control) > (min or 0))
end

function sbq.heldControlMax(seat, control, max)
	return vehicle.controlHeld(seat, control) and (vehicle.controlHeldTime(seat, control) < (max or 1))
end

function sbq.heldControlMinMax(seat, control, min, max)
	return sbq.heldControl(seat, control, min) and sbq.heldControlMax(seat, control, max)
end

function sbq.heldControls(seat, controlList, time)
	for _, control in pairs(controlList) do
		if not sbq.heldControl(seat, control, time) then return false end
	end
	return true
end

function sbq.updateDirectionControl(seatname, control, direction, val, dt, forceHold)
	if vehicle.controlHeld(seatname, control) or forceHold then
		sbq.seats[seatname].controls[direction] = sbq.seats[seatname].controls[direction] + val
	end
end

function sbq.updateControls(dt)
	for i = 0, sbq.occupantSlots do
		local seatname = sbq.occupant[i].seatname
		local eid = sbq.occupant[i].id
		if type(eid) == "number" and world.entityExists(eid) and not (seatname == sbq.driverSeat and sbq.isPathfinding) then
			sbq.occupant[i].controls.dx = 0
			sbq.occupant[i].controls.dy = 0
			sbq.updateDirectionControl(seatname, "left", "dx", -1, dt)
			sbq.updateDirectionControl(seatname, "right", "dx", 1, dt)
			sbq.updateDirectionControl(seatname, "down", "dy", -1, dt)
			sbq.updateDirectionControl(seatname, "up", "dy", 1, dt)

			sbq.occupant[i].controls.aim = vehicle.aimPosition( seatname ) or {0,0}
			sbq.getSeatData(sbq.occupant[i], seatname, eid)
		end
	end
end

function sbq.getSeatData(occupant, seatname, eid)

	occupant.controls.species = world.entitySpecies(eid) or world.monsterType(eid)
	occupant.controls.primaryHandItem = world.entityHandItem(eid, "primary")
	occupant.controls.altHandItem = world.entityHandItem(eid, "alt")
	occupant.controls.primaryHandItemDescriptor = world.entityHandItemDescriptor(eid, "primary")
	occupant.controls.altHandItemDescriptor = world.entityHandItemDescriptor(eid, "alt")

	local seatType
	local data
	if (seatname == sbq.driverSeat) then
		if sbq.isNested then return end

		seatType = "driver"
		data = {
			species = world.entityName(entity.id()),
			settings = sbq.settings,
			layer = occupant.smolPreyData,
			state = sbq.state,
			edible = sbq.stateconfig[sbq.state].edible,
			totalOccupants = sbq.occupants.total,
			hitbox = sbq.movementParams.collisionPoly,
			id = entity.id()
		}
	else
		data = occupant.smolPreyData
		data.predId = entity.id()
	end
	data.type = seatType
	data.location = occupant.location

	if sbq.timer(seatname .. "Info", 1) then
		if seatType == "driver" and not sbq.isNested then
			world.sendEntityMessage(eid, "sbqSetType", "driver")
		end
		if occupant.controls.primaryHandItem ~= nil and occupant.controls.primaryHandItemDescriptor.parameters.scriptStorage ~= nil and occupant.controls.primaryHandItemDescriptor.parameters.scriptStorage.seatdata ~= nil then
			occupant.controls = sb.jsonMerge(occupant.controls, occupant.controls.primaryHandItemDescriptor.parameters.scriptStorage.seatdata)
		elseif occupant.controls.altHandItem ~= nil and occupant.controls.altHandItemDescriptor.parameters.scriptStorage ~= nil and occupant.controls.altHandItemDescriptor.parameters.scriptStorage.seatdata ~= nil then
			occupant.controls = sb.jsonMerge(occupant.controls, occupant.controls.altHandItemDescriptor.parameters.scriptStorage.seatdata)
		else
			sbq.loopedMessage(seatname .. "Info", eid, "sbqGetSeatInformation", { seatType }, function(seatdata)
				occupant.controls = sb.jsonMerge(occupant.controls, seatdata)
			end)
		end
	end

	if sbq.timedLoopedMessage(seatname .. "Equips", 1, eid, "sbqGetSeatEquips", { data }, function(seatdata)
			occupant.controls = sb.jsonMerge(occupant.controls, seatdata)
		end)
	then
		world.sendEntityMessage(eid, "sbqSetCurrentData", data)
	end
end

sbq.monsterstrugglecooldown = {}

local struggleDirections = { "back", "front", "up", "down", "jump" }
function sbq.getSeatDirections(seatname)
	local occupantId = sbq.seats[seatname].id
	local occupantData = sbq.seats[seatname]

	if not occupantId or not world.entityExists(occupantId) then return end

	if world.entityType( occupantId ) ~= "player" then
		sbq.monsterstrugglecooldown[occupantId] = math.max(0, (sbq.monsterstrugglecooldown[occupantId] or 0) - sbq.dt)
		if (sbq.monsterstrugglecooldown[occupantId] or 0) > 0 then return end
		local EffectSlot = sbq.getLocationSetting(occupantData.location, "EffectSlot")
		if (math.random() < 0.5) and not (EffectSlot == "softDigest" or EffectSlot == "digest" or occupantData.visited.totalTime > 600 or sbq.species == "sbqEgg")  then sbq.monsterstrugglecooldown[occupantId] = math.random(0,2) + math.random() end -- there still should be a chance for them to "rest" but not when being digested because it'd be urgent to escape
		if occupantData.controls.favorDirection and (math.random() > 0.5) then
			return occupantData.controls.favorDirection
		else
			local dir = struggleDirections[math.random(1, #struggleDirections)]
			if dir == occupantData.controls.disfavorDirection then
				dir = struggleDirections[math.random(1, #struggleDirections)]
			end
			return dir
		end
	else
		local direction = sbq.relativeDirectionName(sbq.seats[seatname].controls.dx, sbq.seats[seatname].controls.dy)
		if direction then return direction end
		if sbq.seats[seatname].controls.jump > 0 then
			return "jump"
		end
	end
end

function sbq.relativeDirectionName(dx, dy)
	local dx = dx * sbq.direction
	if dx ~= 0 then
		if dx >= 1 then
			return "front"
		else
			return "back"
		end
	end
	if dy ~= 0 then
		if dy >= 1 then
			return "up"
		else
			return "down"
		end
	end
end
