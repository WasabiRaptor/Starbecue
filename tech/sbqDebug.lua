local pressed = true

function update(args)
	if args.moves["special1"] and not pressed then
		local targets = world.entityQuery(tech.aimPosition(), 2, {
			withoutEntityId = entity.id(),
			includedTypes = {"creature"}
		})
		sb.logInfo(sb.printJson(targets))
		if targets[1] then
			world.sendEntityMessage(entity.id(), "sbqAddOccupant", targets[1])
		end
	end
	pressed = args.moves["special1"]
end
