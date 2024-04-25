
function doSBQTargetAction(args, board)
	if args.entity == nil or not world.entityExists(args.entity) then return false end
	sbq_hunting.attemptAction(args.entity)
	return true
end

function sbqSetHostileTarget(args, board)
	-- if args.entity ~= nil and world.entityExists(args.entity) and args.entity ~= (storage.huntingTarget or {}).id then
	-- 	sbq.combatSwitchHuntingTarget(args.entity)
	-- end
	return true
end

function swapItemSlots(args, board)
	npc.setItemSlot("primary", self.sheathedPrimary)
	local primary = self.primary
	self.primary = self.sheathedPrimary
	self.sheathedPrimary = self.sheathedPrimary2
	self.sheathedPrimary2 = primary

	npc.setItemSlot("alt", self.sheathedAlt)
	local alt = self.alt
	self.alt = self.sheathedAlt
	self.sheathedAlt = self.sheathedAlt2
	self.sheathedAlt2 = alt
	return true
end
