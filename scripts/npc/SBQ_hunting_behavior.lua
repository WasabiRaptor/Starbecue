function doSBQTargetAction(args, board)
	if (args.entity == nil) or (not world.entityExists(args.entity)) then return false end
	sbq_hunting.attemptAction(args.entity)
	return true
end
function entityInSBQActionRange(args, board)
	if (args.entity == nil) or (not world.entityExists(args.entity)) then return false end
	local bounds = mcontroller.collisionBoundBox()
	local paddedbounds = rect.pad(bounds, sbq.config.actionRange * mcontroller.scale())
	local targetBounds = world.entityCollisionBoundBox(args.entity)
	if rect.intersects(bounds, targetBounds) or ((entity.entityInSight(args.entity)) and (rect.intersects(paddedbounds, targetBounds))) then
		return true
	end
	return false
end


function sbqSetHostileTarget(args, board)
	if (args.entity ~= nil) and world.entityExists(args.entity) and (args.entity ~= args.hunting) and sbq.timer("huntTargetSwitchCooldown", sbq.config.huntTargetSwitchCooldown) then
		sbq_hunting.huntTarget(args.entity)
	end
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

function hasMeleeSheathed(args, board)
	if self.sheathedPrimary == nil then return false end
	return root.itemHasTag(self.sheathedPrimary.name, "melee") or root.itemHasTag(self.sheathedPrimary2.name, "melee")
end

function hasRangedSheathed(args, board)
	if self.sheathedPrimary == nil then return false end
	return root.itemHasTag(self.sheathedPrimary.name, "ranged") or root.itemHasTag(self.sheathedPrimary2.name, "ranged")
end

function hasShieldSheathed(args, board)
	if self.sheathedAlt== nil then return false end
	return root.itemHasTag(self.sheathedAlt.name, "shield") or root.itemHasTag(self.sheathedAlt2.name, "shield")
end

function isFollowingRecruiter(args, board)
	return not Occupants.entityId[_ENV.recruitable.ownerUuid()] and _ENV.recruitable.isFollowing()
end
