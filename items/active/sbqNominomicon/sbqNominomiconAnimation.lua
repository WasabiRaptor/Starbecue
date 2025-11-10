function update()
	local position = activeItemAnimation.ownerPosition()
	local entities = world.entityQuery(position, 20, {
		includedTypes = { "vehicle", "npc", "object", "monster" }
	})

	localAnimator.clearDrawables()
	for _, eid in ipairs(entities) do
		local entityType = world.entityType(eid)
		local indicator
		local entityMethods = world.entity(eid)
		if entityType == "npc" then
			if entityMethods:statPositive("sbqIsPrey") then
			elseif world.getNpcScriptParameter(eid, "sbqNPC") then
				indicator = {
					image = "/items/active/sbqNominomicon/indicator.png",
					centered = true,
					fullbright = true,
					position = world.entityPosition(eid)
				}
			elseif entityMethods:statPositive("sbqActorScript") then
				indicator = {
					image = "/items/active/sbqNominomicon/indicator.png?hueshift=-64",
					centered = true,
					fullbright = true,
					position = world.entityPosition(eid)
				}
			end
		elseif entityType == "monster" then
			if entityMethods:statPositive("sbqIsPrey") then
			elseif entityMethods:statPositive("sbqActorScript") then
				indicator = {
					image = "/items/active/sbqNominomicon/indicator.png?hueshift=-64",
					centered = true,
					fullbright = true,
					position = world.entityPosition(eid)
				}
			end
		elseif entityType == "vehicle" then

		elseif entityType == "object" then
			if world.getObjectParameter(eid, "sbqObject") then
				indicator = {
					image = "/items/active/sbqNominomicon/indicator.png",
					centered = true,
					fullbright = true,
					position = objectCenter(eid)
				}
			elseif world.getObjectParameter(eid, "sbqConfigGui") then
				indicator = {
					image = "/items/active/sbqNominomicon/indicator.png?hueshift=64",
					centered = true,
					fullbright = true,
					position = objectCenter(eid)
				}
			end
		end
		if not indicator and entityMethods:getParameter("sbqHelpPage") and not entityMethods:statPositive("sbqIsPrey")  then
			local pos = world.entityPosition(eid)
			if entityType == "object" then
				pos = objectCenter(eid)
			end
			indicator = {
				image = "/items/active/sbqNominomicon/helpIndicator.png",
				centered = true,
				fullbright = true,
				position = pos
			}
		end
		if indicator then
			localAnimator.addDrawable( indicator, "ForegroundOverlay+2")
		end
	end
end

function objectCenter(eid)
	local pos = world.entityPosition(eid)
	local bounds = {9999, 9999, 0, 0}
	local spaces = world.objectSpaces(eid)
	for _, space in pairs(spaces) do
		bounds = {
			math.min(space[1], bounds[1]),
			math.min(space[2], bounds[2]),
			math.max(space[1] + 1, bounds[3]),
			math.max(space[2] + 1, bounds[4])
		}
	end
	return {
		pos[1] + bounds[1] + (bounds[3] - bounds[1]) * 0.5,
		pos[2] + bounds[2] + (bounds[4] - bounds[2]) * 0.5
	}
end
