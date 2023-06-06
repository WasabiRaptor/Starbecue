
function doSBQTargetAction(args, board)
	if args.entity == nil or not world.entityExists(args.entity) then return false end
	sbq.doTargetAction()
	return true
end

function sbqSetHostileTarget(args, board)
	if args.entity ~= nil and world.entityExists(args.entity) and args.entity ~= (storage.huntingTarget or {}).id then
		sbq.setCombatHuntingTarget(args.entity)
	end
	return true
end
