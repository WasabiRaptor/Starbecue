
function doSBQTargetAction(args, board)
	if args.entity == nil or not world.entityExists(args.entity) then return false end
	sbq.doTargetAction()
	return true
end
