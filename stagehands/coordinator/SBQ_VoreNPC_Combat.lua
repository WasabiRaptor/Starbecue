local _npcCombat = npcCombat
function npcCombat(...)
	if self.goal and world.entityExists(self.goal) and world.entityStatPositive(self.goal, "sbqIsPrey") then
		self.success = true
		die()
		return
	end
	return _npcCombat(...)
end
