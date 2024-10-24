local old = {
	isHouseBoundaryTile = isHouseBoundaryTile,
	countTags = countTags
}
function isHouseBoundaryTile(position)
	return old.isHouseBoundaryTile(position) or (world.magnitude(object.position(), position) > config.getParameter("campRadius"))
end

function countTags(...)
	local tags = old.countTags(...) or {}
	if storage.house and storage.house.boundary then
		local prev
		for _, v in ipairs(storage.house.boundary) do
			if prev then
				if not world.lineCollision(prev, v) then
					local mag = world.magnitude(prev, v)
					tags.door = math.floor((tags.door or 0) + mag)
					tags.open_air = math.floor((tags.open_air or 0) + mag)
				end
			end
			prev = v
		end
	end
	return tags
end
