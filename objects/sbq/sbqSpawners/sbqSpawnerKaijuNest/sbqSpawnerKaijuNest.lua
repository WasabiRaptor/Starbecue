local inited
function update()
	if inited then return end
	local nestFGPos = object.toAbsolutePosition({-1, 0})
	if world.entityName(world.objectAt(nestFGPos) or 0) ~= "sbqSpawnerKaijuNestFG" then
		world.placeObject("sbqSpawnerKaijuNestFG", nestFGPos, object.direction(), {unbreakable = true})
	end
	inited = true
end

function die()
	local nestFGId = world.objectAt(object.toAbsolutePosition({-1, 0}))
	if world.entityName(nestFGId or 0) == "sbqSpawnerKaijuNestFG" then
		world.breakObject(nestFGId, true)
	end
end
