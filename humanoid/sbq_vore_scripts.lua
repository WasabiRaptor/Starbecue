
function sbq.update(dt)
	sbq.detectShirt()
	sbq.detectPants()
end

function state.stand.oralVore(args, tconfig)
	return sbq.doVore(args, "belly", {}, "swallow", tconfig.voreType)
end

function state.stand.oralEscape(args, tconfig)
	return sbq.doEscape(args, tconfig.releaseEffects or {wet = { power = 5, source = entity.id()}}, {}, tconfig.voreType )
end

function state.stand.analVore(args, tconfig)
	return sbq.doVore(args, "belly", {}, "swallow", tconfig.voreType)
end

function state.stand.analEscape(args, tconfig)
	return sbq.doEscape(args, tconfig.releaseEffects or {}, {}, tconfig.voreType )
end

function state.stand.unbirth(args, tconfig)
	return sbq.doVore(args, "womb", {}, "swallow", tconfig.voreType)
end

function state.stand.unbirthEscape(args, tconfig)
	return sbq.doEscape(args, tconfig.releaseEffects or {wet = { power = 5, source = entity.id()}}, {}, tconfig.voreType )
end

function state.stand.cockVore(args, tconfig)
	if not args.id then
		sbq.moveToLocation({id = sbq.findFirstOccupantIdForLocation("shaft")}, {location = "balls"})
		return false
	end
	return sbq.doVore(args, "shaft", {}, "swallow", tconfig.voreType)
end

state.stand.moveToLocation = sbq.moveToLocation
state.stand.switchBalls = sbq.switchBalls

function state.stand.cockEscape(args, tconfig)
	return sbq.doEscape(args, tconfig.releaseEffects or {glueslow = { power = 5 + (sbq.lounging[args.id].progressBar), source = entity.id()}}, {}, tconfig.voreType )
end

function state.stand.breastVore(args, tconfig)
	return sbq.doVore(args, "breasts", {}, "swallow", tconfig.voreType)
end

function state.stand.breastEscape(args, tconfig)
	return sbq.doEscape(args, tconfig.releaseEffects or {}, {}, tconfig.voreType )
end

function state.stand.navelVore(args, tconfig)
	return sbq.doVore(args, "belly", tconfig.releaseEffects or {}, "swallow", tconfig.voreType)
end

function state.stand.navelEscape(args, tconfig)
	return sbq.doEscape(args, tconfig.releaseEffects or {}, {}, tconfig.voreType )
end

function sbq.detectShirt()
	if (sbq.sbqData.overrideSettings or {}).shirt == false then return false end
	if sbq.settings.bra then return true end
	local shirt = sbq.seats[sbq.driverSeat].controls.chestCosmetic or sbq.seats[sbq.driverSeat].controls.chest or {}
	local result = not sbq.config.chestVoreWhitelist[shirt.name or "none"]
	sbq.settings.shirt = result
end

function sbq.detectPants()
	if (sbq.sbqData.overrideSettings or {}).pants == false then return false end
	if sbq.settings.underwear then return true end
	local pants = sbq.seats[sbq.driverSeat].controls.legsCosmetic or sbq.seats[sbq.driverSeat].controls.legs or {}
	local result = not sbq.config.legsVoreWhitelist[pants.name or "none"]
	sbq.settings.pants = result
end

function sbq.letout(id)
	local id = id or sbq.getRecentPrey()
	if (not id) or (not sbq.lounging[id]) then return false end

	local location = sbq.lounging[id].location

	if location == "belly" then
		if (sbq.seats[sbq.driverSeat].controls.primaryHandItem == "sbqController") and sbq.seats[sbq.driverSeat].controls.primaryHandItemDescriptor.parameters.scriptStorage.clickAction == "analVore" then
			return sbq.doTransition("analEscape", {id = id})
		elseif (sbq.seats[sbq.driverSeat].controls.primaryHandItem == "sbqController") and sbq.seats[sbq.driverSeat].controls.primaryHandItemDescriptor.parameters.scriptStorage.clickAction == "navelVore" then
			return sbq.doTransition("navelEscape", {id = id})
		else
			return sbq.doTransition("oralEscape", {id = id})
		end
	elseif location == "tail" then
		return sbq.doTransition("tailEscape", {id = id})
	elseif location == "shaft" then
		return sbq.doTransition("cockEscape", {id = id})
	elseif location == "ballsL" or location == "ballsR" or location == "balls" then
		return sbq.moveToLocation({id = id}, {location = "shaft"})
	elseif location == "breastsL" or location == "breastsR" or location == "breasts" then
		return sbq.doTransition("breastEscape", {id = id})
	elseif location == "womb" then
		return sbq.doTransition("unbirthEscape", {id = id})
	end
end

function sbq.settingsMenuUpdated()
	sbq.handleBodyParts()
	sbq.handleUnderwear()
end

function sbq.handleBodyParts()
	local defaultSbqData = sbq.defaultSbqData
	world.sendEntityMessage(sbq.driver, "sbqSetInfusedPartColors", "cock", sbq.settings.shaftInfusedVisual and sbq.settings.shaftInfusedItem)
	world.sendEntityMessage(sbq.driver, "sbqSetInfusedPartColors", "breastsCover", sbq.settings.breastsInfusedVisual and sbq.settings.breastsInfusedItem)
	world.sendEntityMessage(sbq.driver, "sbqSetInfusedPartColors", "breastsFront", sbq.settings.breastsInfusedVisual and sbq.settings.breastsInfusedItem)
	world.sendEntityMessage(sbq.driver, "sbqSetInfusedPartColors", "breastsBack", sbq.settings.breastsInfusedVisual and sbq.settings.breastsInfusedItem)
	world.sendEntityMessage(sbq.driver, "sbqSetInfusedPartColors", "ballsFront", sbq.settings.ballsInfusedVisual and sbq.settings.ballsInfusedItem)
	world.sendEntityMessage(sbq.driver, "sbqSetInfusedPartColors", "ballsBack", sbq.settings.ballsInfusedVisual and sbq.settings.ballsInfusedItem)
	world.sendEntityMessage(sbq.driver, "sbqSetInfusedPartColors", "pussy", sbq.settings.wombInfusedVisual and sbq.settings.wombInfusedItem)
	if sbq.settings.penis and ((not defaultSbqData.locations.shaft.requiresInfusion) or (defaultSbqData.locations.shaft.requiresInfusion and sbq.settings.shaftInfusedItem ~= nil)) then
		if sbq.settings.underwear then
			sbq.setStatusValue( "cockVisible", "?crop;0;0;0;0")
		else
			sbq.setStatusValue( "cockVisible", "")
		end
		sbq.sbqData.locations.shaft.max = defaultSbqData.locations.shaft.max
	else
		sbq.setStatusValue( "cockVisible", "?crop;0;0;0;0")
		sbq.sbqData.locations.shaft.max = 0
	end
	if sbq.settings.balls and ((not defaultSbqData.locations.balls.requiresInfusion) or (defaultSbqData.locations.balls.requiresInfusion and sbq.settings.ballsInfusedItem ~= nil)) then
		if sbq.settings.underwear then
			sbq.setStatusValue( "ballsVisible", "?crop;0;0;0;0")
		else
			sbq.setStatusValue( "ballsVisible", "")
		end
		sbq.sbqData.locations.balls.max = defaultSbqData.locations.balls.max
		sbq.sbqData.locations.ballsL.max = defaultSbqData.locations.balls.max
		sbq.sbqData.locations.ballsR.max = defaultSbqData.locations.balls.max
	else
		sbq.setStatusValue("ballsVisible", "?crop;0;0;0;0")
		sbq.sbqData.locations.balls.max = 0
		sbq.sbqData.locations.ballsL.max = 0
		sbq.sbqData.locations.ballsR.max = 0
	end
	if sbq.sbqData.locations.breasts then
		if sbq.settings.breasts and ((not defaultSbqData.locations.breasts.requiresInfusion) or (defaultSbqData.locations.breasts.requiresInfusion and sbq.settings.breastsInfusedItem ~= nil)) then
			sbq.setStatusValue("breastsVisible", "")
			sbq.sbqData.locations.breasts.max = defaultSbqData.locations.breasts.max
			sbq.sbqData.locations.breastsL.max = defaultSbqData.locations.breasts.max
			sbq.sbqData.locations.breastsR.max = defaultSbqData.locations.breasts.max
		else
			sbq.setStatusValue("breastsVisible", "?crop;0;0;0;0")
			sbq.sbqData.locations.breasts.max = 0
			sbq.sbqData.locations.breastsL.max = 0
			sbq.sbqData.locations.breastsR.max = 0
		end
		world.sendEntityMessage(sbq.driver, "setBoobMask", sbq.settings.breasts)
	end
	if sbq.settings.pussy and ((not defaultSbqData.locations.womb.requiresInfusion) or (defaultSbqData.locations.womb.requiresInfusion and sbq.settings.wombInfusedItem ~= nil)) then
		sbq.setStatusValue("pussyVisible", "")
		sbq.sbqData.locations.womb.max = defaultSbqData.locations.womb.max
	else
		sbq.setStatusValue("pussyVisible", "?crop;0;0;0;0")
		sbq.sbqData.locations.womb.max = 0
	end
end

function sbq.handleUnderwear()
	world.sendEntityMessage(sbq.driver, "sbqEnableUnderwear", sbq.settings.underwear)
	world.sendEntityMessage(sbq.driver, "sbqEnableBra", sbq.settings.bra)
end
