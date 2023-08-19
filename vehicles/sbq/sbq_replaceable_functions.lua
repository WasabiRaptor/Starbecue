--[[
	Functions placed here are in key locations in the sbq scripts where I believe people would want to place predator specific actions
	these will typically be empty, but are called at points in the main loop

	they're meant to be replaced in the predator itself to have it have said specific actions happen
]]
---------------------------------------------------------------------------------------------------------------------------------

function sbq.init()
end

function sbq.uninit()
end

-- to have something in the main loop rather than a state loop
function sbq.update(dt)
end

-- the standard state called when a state's script is undefined
function sbq.standardState(dt)
end

-- the pathfinding function called if a state doesn't have its own pathfinding script
function sbq.pathfinding(dt)
end

-- the function that gets called upon a prey inputting the escape combo (every direction + space)
function sbq.escapeScript(i)
	sbq.uneat(sbq.occupant[i].id)
end

function sbq.struggleMessages(id)
	local entityType = world.entityType(id)
	if entityType == "npc" or entityType == "player" and type(sbq.driver) == "number" and world.entityExists(sbq.driver) then
		local location = sbq.lounging[id].location
		local settings = sb.jsonMerge(sb.jsonMerge(sbq.lounging[id].visited, {
			predDigestEffect = (((sbq.sbqData.locations[location] or {}).digest or {}).effect or "sbqDigest"),
			predator = sbq.species,
			location = location,
			progressBarType = sbq.lounging[id].progressBarType,
			progressBar = sbq.lounging[id].progressBar,
			entryType = sbq.lounging[id].entryType
		}), sbq.lounging[id].flags)

		if sbq.lounging[id].flags.infused and sbq.randomTimer(sbq.driver.."struggleLine", 5, 15) then
			world.sendEntityMessage(sbq.driver, "sbqSayRandomLine", id, settings, ".infusedTease", true)
			return
		end

		if math.random() >= 0.5 then
			if sbq.randomTimer(sbq.driver.."struggleLine", 5, 15) then
				world.sendEntityMessage(sbq.driver, "sbqSayRandomLine", id, settings, ".struggle", true )
			end
		else
			if sbq.randomTimer(id.."struggleLine", 5, 15) then
				world.sendEntityMessage(id, "sbqSayRandomLine", sbq.driver, sb.jsonMerge(sbq.settings, settings), ".struggling", false )
			end
		end
	end
end

-- for handling the grab action when clicked, some things may want to handle it differently
function sbq.handleGrab()
	local primary = (((sbq.seats[sbq.driverSeat].controls.primaryHandItemDescriptor or {}).parameters or {}).scriptStorage or {}).clickAction
	local alt = (((sbq.seats[sbq.driverSeat].controls.altHandItemDescriptor or {}).parameters or {}).scriptStorage or {}).clickAction
	local victim = sbq.grabbing

	if sbq.pressControl(sbq.driverSeat, "primaryFire") then
		sbq.uneat(sbq.grabbing)
		sbq.grabbing = nil
		if primary == "grab" then
			--sbq.grabAngleTransitions(victim)
		else
			sbq.doTransition(primary, { id = victim })
		end
	elseif sbq.pressControl(sbq.driverSeat, "altFire") then
		sbq.uneat(sbq.grabbing)
		sbq.grabbing = nil
		if alt == "grab" then
			--sbq.grabAngleTransitions(victim)
		else
			sbq.doTransition(alt, { id = victim })
		end
	end
end

function sbq.grabAngleTransitions(victim)
	--if math.abs(sbq.armRotation.frontarmsVelocity) > 5 then return end
	local angle = sbq.armRotation.frontarmsAngle * 180/math.pi
	local transition
	if (angle >= 45 and angle <= 135) then
		transition = "oralVore"
	elseif (angle >= 0 and angle <= 45) then
		transition = "breastVore"
	elseif (angle <= 0 and angle >= -30) then
		transition = "cockVore"
	elseif (angle <= -30 and angle >= -60) then
		transition = "unbirth"
	elseif (angle <= -60 and angle >= -135) then
		transition = "analVore"
	end
	sbq.doTransition(transition, { id = victim })
end

-- for letting out prey, some predators might wand more specific logic regarding this
function sbq.letout(id)
	local id = id or sbq.getRecentPrey()
	if not id then return false end

	return sbq.doTransition( "escape", {id = id} )
end

function sbq.getRecentPrey()
	for i = sbq.occupantSlots, sbq.startSlot, -1 do
		if type(sbq.occupant[i].id) == "number" and world.entityExists(sbq.occupant[i].id)
		and sbq.occupant[i].location ~= "escaping"
		then
			return sbq.occupant[i].id
		end
	end
end

-- warp in/out effect should be replaceable if needed
function sbq.warpInEffect()
	world.spawnProjectile( "sbqWarpInEffect", mcontroller.position(), entity.id(), {0,0}, true, { processing = sbq.getWarpInOutDirectives()})
end
function sbq.warpOutEffect()
	world.spawnProjectile( "sbqWarpOutEffect", mcontroller.position(), sbq.driver or entity.id(), {0,0}, true, { processing = sbq.getWarpInOutDirectives()})
end

function sbq.getWarpInOutDirectives()
	if sbq.driver ~= nil then
		species = world.entitySpecies(sbq.driver)
		if species ~= nil then
			return root.assetJson("/species/"..species..".species").effectDirectives
		end
	end
end

-- called whenever the settings menu is updated
function sbq.settingsMenuUpdated()
end

-- used for moving around between locations

function sbq.moveToLocation(args, tconfig)
	if not args.id then return false end
	local location, side = sbq.getSidedLocationWithSpace(tconfig.location, sbq.lounging[args.id].size)
	if location then
		sbq.moveOccupantLocation(args, location, side)
	end
end

function sbq.switchBalls(args)
	local dx = sbq.lounging[args.id].controls.dx
	if dx == -1 then
		return sbq.moveOccupantLocation(args, "balls", "R")
	elseif dx == 1 then
		return sbq.moveOccupantLocation(args, "balls", "L")
	end
end

---------------------------------------------------------------------------------------------------------------------------------
--[[these are called when handling the effects applied to the occupants, called for each one and give the occupant index,
the entity id, health, and the status checked in the options]]

-- to have other effects applied in the effect application loop
function sbq.otherLocationEffects(i, eid, health, locationEffect, location, powerMultiplier)
end
function sbq.infusedLocationEffects(i, eid, health, locationEffect, location, powerMultiplier)
end

---------------------------------------------------------------------------------------------------------------------------------

-- for doing the item actions
function sbq.setItemActionColorReplaceDirectives()
	local colorReplaceString = sbq.sbqData.itemActionDirectives or ""

	if sbq.sbqData.replaceColors ~= nil then
		colorReplaceString = sbq.doColorReplaceString(colorReplaceString, 1, { "154247", "23646a", "39979e", "4cc1c9" } )
	end

	sbq.itemActionDirectives = colorReplaceString
end

function sbq.doColorReplaceString(colorReplaceString, i, basePalette)
	local colorReplaceString = colorReplaceString.."?replace"
	local replacePalette = sbq.sbqData.replaceColors[i][((sbq.settings.replaceColors or {})[i] or (sbq.sbqData.defaultSettings.replaceColors or {})[i] or 1) + 1]
	local fullbright = (sbq.settings.fullbright or {})[i]

	if sbq.settings.replaceColorTable and sbq.settings.replaceColorTable[i] then
		replacePalette = sbq.settings.replaceColorTable[i]
	end

	for j, color in ipairs(basePalette) do
		color = replacePalette[j]
		if color then
			if fullbright and #color <= #"ffffff" then -- don't tack it on it if it already has a defined opacity or fullbright
				color = color.."fe"
			end
			colorReplaceString = colorReplaceString..";"..(basePalette[j] or "").."="..(color or "")
		end
	end
	return colorReplaceString
end
