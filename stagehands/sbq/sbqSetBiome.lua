
function update()
	local position = stagehand.position()
	if (world ~= nil) and (world.regionActive ~= nil) and world.regionActive({position[1]-1,position[2]-1,position[1]+1,position[2]+1}) then
		world.addBiomeRegion(position, config.getParameter("biomeName"), config.getParameter("subBlockSelector") or "largeClumps", config.getParameter("width") or 1)
		stagehand.die()
	end
end
