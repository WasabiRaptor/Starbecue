local inited = false
function update()
	if inited then return end
	local objectList = config.getParameter("placeObjects")
	for _, v in ipairs(objectList) do
		local name, relativePos, direction, params = table.unpack(v)
		local pos = object.toAbsolutePosition({relativePos[1] * object.direction(), relativePos[2]})
		if world.entityName(world.objectAt(pos) or 0) ~= name then
			world.placeObject(name, pos, direction * object.direction(), sb.jsonMerge({unbreakable = true}, params))
		end
	end
	inited = true
	script.setUpdateDelta(0)
end

function die()
	local objectList = config.getParameter("placeObjects")
	for _, v in ipairs(objectList) do
		local name, relativePos, direction, params = table.unpack(v)
		local pos = object.toAbsolutePosition({relativePos[1] * object.direction(), relativePos[2]})
		local eid = world.objectAt(pos)
		if world.entityName(eid or 0) == name then
			world.breakObject(eid, true)
		end
	end
end
