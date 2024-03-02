
function sbq.letout(id, i)
	world.sendEntityMessage( sbq.sbqCurrentData.id, "letout", id )
end

function sbq.npcInteract(id, i)
	local predator = sbq.sbqCurrentData.species
	if predator == "sbqOccupantHolder" then
		predator = player.species()
	end
	local predData = {
		settings = sbq.sbqCurrentData.settings,
		location = sbq.occupant[i].location,
		infused = sbq.occupant[i].flags.infused,
		predator = predator
	}
	sbq.addRPC(world.sendEntityMessage(id, "sbqInteract", player.id(), predData), function (data)
		if data then
			player.interact(data[1], data[2], id)
		end
	end)
end

function sbq.turboDigest(id, i)
	world.sendEntityMessage( id, "sbqTurboDigest" )
end

function sbq.cumDigest(id, i)
	sbq.addRPC(world.sendEntityMessage(id, "sbqGetPreyEnabledSetting", "cumDigestAllow"), function(allowed)
		if allowed then
			world.sendEntityMessage(sbq.sbqCurrentData.id, "sbqCumDigest", id)
		end
	end)
end

function sbq.transform(id, i)
	world.sendEntityMessage( sbq.sbqCurrentData.id, "transform", id )
end

function sbq.eggify(id, i)
	world.sendEntityMessage( sbq.sbqCurrentData.id, "eggify", id )
end


function sbq.infuseLocation(id, i, args)
	world.sendEntityMessage( sbq.sbqCurrentData.id, "infuseLocation", id, (args or {}).locations )
end
