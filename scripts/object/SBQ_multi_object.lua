local inited = false
function update()
	if inited then return end
	local objectList = config.getParameter("placeObjects")
	local placed = config.getParameter("placedObjects") or {}
	for i, v in ipairs(objectList) do
		local name, relativePos, direction, params = table.unpack(v)
		local pos = object.toAbsolutePosition({relativePos[1] * object.direction(), relativePos[2]})
		if ((not placed[i]) or config.getParameter("debug")) and (world.entityName(world.objectAt(pos) or 0) ~= name) then
			if world.placeObject(name, pos, direction * object.direction(), sb.jsonMerge(config.getParameter("placeObjectsParameters") or {}, params)) then
				placed[i] = true
			end
		end
	end
	object.setConfigParameter("placedObjects", placed)
	inited = true
	script.setUpdateDelta(0)
end

function die()
	local objectList = config.getParameter("placeObjects")
	local placed = config.getParameter("placedObjects") or {}
	for i, v in ipairs(objectList) do
		local name, relativePos, direction, params = table.unpack(v)
		local pos = object.toAbsolutePosition({relativePos[1] * object.direction(), relativePos[2]})
		local eid = world.objectAt(pos)
		if world.entityName(eid or 0) == name then
			if world.breakObject(eid, true) then
				placed[i] = false
			end
		end
	end
	object.setConfigParameter("placedObjects", placed)
end
