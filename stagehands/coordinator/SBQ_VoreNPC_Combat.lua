local _npcCombat = npcCombat

function npcCombat(dt)
	if world.entityExists(self.goal) and world.entityType(self.goal) ~= "player" and ((world.callScriptedEntity(self.goal, "status.statusProperty", ("sbqType"))) == "prey") then
		self.success = true
		return
	end

	return _npcCombat(dt)
end

-- tried to get this working, it doesn't seem to do anything even when loaded
