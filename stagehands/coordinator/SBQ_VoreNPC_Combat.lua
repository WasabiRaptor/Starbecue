local _npcCombat = npcCombat

function npcCombat(dt)
	if world.entityExists(self.goal) and world.entityType(self.goal) ~= "player" and ((world.callScriptedEntity(self.goal, "status.statusProperty", ("sbqCurrentData")) or {}).type == "prey") then
		self.success = true
		return
	end
	for i, id in ipairs(self.group.members or {}) do
		if world.entityExists(id) and world.entityType(id) ~= "player" and world.callScriptedEntity(id, "sbq.checkOccupant", self.goal) then
			self.success = true
			return
		end
	end

	return _npcCombat(dt)
end

-- tried to get this working, it doesn't seem to do anything even when loaded
