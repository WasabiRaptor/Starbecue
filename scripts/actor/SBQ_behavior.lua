local old = {
	entityInSight = entityInSight,
	isValidTarget = isValidTarget,
	sayToEntity = sayToEntity
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

function sayToEntity(args, ...)
	if args.dialogType == "dialog.lostTarget" and world.entityStatPositive(args.entity, "sbqIsPrey") then
		return false
	end
	old.sayToEntity(args, ...)
end
