local _npcCombat = npcCombat
function npcCombat(dt)
	if self.goal and world.entityExists(self.goal) and world.entityStatPositive(self.goal, "sbqIsPrey") then
		self.success = true
		return
	end

	return _npcCombat(dt)
end
