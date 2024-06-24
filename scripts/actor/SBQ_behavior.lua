local old = {
	entityInSight = entityInSight,
	isValidTarget = isValidTarget,
	sayToEntity = sayToEntity,
	entityInRange = entityInRange,
	entityAggressive = entityAggressive,
	entityHoldingWeapon = entityHoldingWeapon
}
function entityInSight(args, ...)
	local res = old.entityInSight(args, ...)
	if res then
		return not world.entityStatPositive(args.entity, "sbqIsPrey")
	end
	return res
end
function isValidTarget(args, ...)
	local res = old.isValidTarget(args, ...)
	if res then
		return not world.entityStatPositive(args.entity, "sbqIsPrey")
	end
	return res
end
function entityInRange(args, ...)
	local res = old.entityInRange(args, ...)
	if res then
		return not world.entityStatPositive(args.entity, "sbqIsPrey")
	end
	return res
end
function entityAggressive(args, ...)
	local res = old.entityAggressive(args, ...)
	if res then
		return not world.entityStatPositive(args.entity, "sbqIsPrey")
	end
	return res
end
function entityHoldingWeapon(args, ...)
	local res = old.entityHoldingWeapon(args, ...)
	if res then
		return not world.entityStatPositive(args.entity, "sbqIsPrey")
	end
	return res
end


function sayToEntity(args, ...)
	if args.dialogType == "dialog.lostTarget" and args.entity and world.entityExists(args.entity) and world.entityStatPositive(args.entity, "sbqIsPrey") then
		return true
	end
	return old.sayToEntity(args, ...)
end
