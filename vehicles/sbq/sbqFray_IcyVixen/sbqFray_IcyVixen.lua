
require("/vehicles/sbq/sbq_main.lua")
require("/scripts/vec2.lua")

state = {
	stand = {},
}

function sbq.init()
	if not sbq.settings.firstLoadDone then
		for settingname, settingvalue in pairs(sbq.settings) do
			sbq.autoSetSettings(settingname, settingvalue)
		end
		sbq.settings.firstLoadDone = true

		world.sendEntityMessage(sbq.spawner, "sbqSaveSettings", sbq.settings, "sbq/IcyVixen/Fray")
	end

	checkPartsEnabled()
end

function sbq.settingsMenuUpdated()
	checkPartsEnabled()
end

function sbq.update(dt)
	eyeTracking()
	detectEmote()
end

function sbq.letout(id)
	local id = id or sbq.getRecentPrey()
	if (not id) or (not sbq.lounging[id]) then return false end

	local location = sbq.lounging[id].location

	if location == "belly" then
		if sbq.heldControl(sbq.driverSeat, "down") then
			return sbq.doTransition("analPushOut", {id = id})
		else
			return sbq.doTransition("oralEscape", {id = id})
		end
	elseif location == "shaft" then
		return sbq.doTransition("cockEscape", { id = id })
	elseif location == "butt" then
		return sbq.doTransition("analEscape", { id = id })
	elseif location == "ballsL" or location == "ballsR" or location == "balls" then
		return sbq.moveToLocation({id = id}, {location = "shaft"})
	end
end

local _setColorReplaceDirectives = sbq.setColorReplaceDirectives
function sbq.setColorReplaceDirectives()
	_setColorReplaceDirectives()

	local projectileConfig = root.projectileConfig(sbq.stateconfig.stand.actions.specialAttack.projectile.name)
	local childProjectileConfig = root.projectileConfig(sbq.stateconfig.stand.actions.specialAttack.projectile.params.childProjectile)

	local projectileParameters = {
		periodicActions = projectileConfig.periodicActions,
		actionOnReap = projectileConfig.actionOnReap
	}
	local childProjectileParameters = {
		periodicActions = childProjectileConfig.periodicActions,
		actionOnReap = childProjectileConfig.actionOnReap
	}

	local i = 4
	local colorGroup = sbq.sbqData.replaceColors[i]
	local basePalette = {"ff9418","ffac18","ffd539"}
	local replacePalette = colorGroup[
		((sbq.settings.replaceColors or {})[i] or (sbq.sbqData.defaultSettings.replaceColors or {})[i] or 1) + 1]
	local colorReplaceString = "?replace"

	if sbq.settings.replaceColorTable and sbq.settings.replaceColorTable[i] then
		replacePalette = sbq.settings.replaceColorTable[i]
		if type(replacePalette) == "string" then
			return
		end
	end

	for j, color in ipairs(replacePalette) do
		colorReplaceString = colorReplaceString .. ";" .. (basePalette[j] or ""):sub(1, 6) .. "=" .. (color or "")
		if color and j == 3 then

			local R = tonumber(color:sub(1,2), 16)
			local G = tonumber(color:sub(3,4), 16)
			local B = tonumber(color:sub(5, 6), 16)
			local RGB = { R, G, B }
			for i, data in ipairs(projectileParameters.periodicActions or {}) do
				if data.color then
					projectileParameters.periodicActions[i].color = RGB
				end
				if data.specification then
					projectileParameters.periodicActions[i].specification.color = RGB
					projectileParameters.periodicActions[i].specification.processing = colorReplaceString
				end
			end
			for i, data in ipairs(childProjectileParameters.periodicActions or {}) do
				if data.color then
					childProjectileParameters.periodicActions[i].color = RGB
				end
				if data.specification then
					childProjectileParameters.periodicActions[i].specification.color = RGB
					childProjectileParameters.periodicActions[i].specification.processing = colorReplaceString
				end
			end
			for i, data in ipairs(projectileParameters.actionOnReap or {}) do
				for j, data in ipairs(data.body or {}) do
					if data.specification and data.specification.color then
						projectileParameters.actionOnReap[i].body[j].specification.color = RGB
					end
				end
			end
			for i, data in ipairs(childProjectileParameters.actionOnReap or {}) do
				for j, data in ipairs(data.body or {}) do
					if data.specification and data.specification.color then
						childProjectileParameters.actionOnReap[i].body[j].specification.color = RGB
					end
				end
			end
		end
	end
	projectileParameters.processing = colorReplaceString
	childProjectileParameters.processing = colorReplaceString
	projectileParameters.childParams = childProjectileParameters

	sbq.stateconfig.stand.actions.specialAttack.projectile.params = sb.jsonMerge(sbq.stateconfig.stand.actions.specialAttack.projectile.params, projectileParameters)
end


function sbq.setItemActionColorReplaceDirectives()
	local colorReplaceString = sbq.sbqData.itemActionDirectives or ""

	if sbq.sbqData.replaceColors ~= nil then
		colorReplaceString = sbq.doColorReplaceString(colorReplaceString, 1, { "154247", "23646a", "39979e", "4cc1c9" })
		colorReplaceString = sbq.doColorReplaceString(colorReplaceString, 4, { "63263d", "7a334d", "9d4165" })
		colorReplaceString = sbq.doColorReplaceString(colorReplaceString, 4, { "ff9418", "ffac18", "ffd539"} )

	end

	sbq.itemActionDirectives = colorReplaceString
end

-------------------------------------------------------------------------------

function getVisibleEntity(entities)
	for _, id in ipairs(entities) do
		if entity.entityInSight(id) then
			return id
		end
	end
end

function eyeTracking()
	local X = 0
	local Y = 0
	local target
	local center = { 2.5, 0.5 }
	if sbq.driving then
		target = sbq.globalToLocal(sbq.seats[sbq.driverSeat].controls.aim)
	else
		local center = sbq.localToGlobal(center)
		local targetEntity = getVisibleEntity(world.playerQuery(center, 50))
		if not targetEntity then
			targetEntity = getVisibleEntity(world.npcQuery(center, 50 ))
		end
		if targetEntity then
			target = sbq.globalToLocal(world.entityPosition(targetEntity))
		end
	end

	if target ~= nil then
		local angle = math.atan((target[2] - center[2]), (target[1] - center[1])) * 180/math.pi

		if angle <= 15 and angle >= -15 then
			X = 1
			Y = 0
		elseif angle <= 75 and angle > 15 then
			X = 1
			Y = 1
		elseif angle <= 105 and angle > 75 then
			X = 0
			Y = 1
		elseif angle <= 165 and angle > 105 then
			X = -1
			Y = 1
		elseif angle > 165 then
			X = -1
			Y = 0

		elseif angle >= -75 and angle < -15 then
			X = 1
			Y = -1
		elseif angle >= -105 and angle < -75 then
			X = 0
			Y = -1
		elseif angle >= -165 and angle < -105 then
			X = -1
			Y = -1
		elseif angle < -165 then
			X = -1
			Y = 0
		end

		if math.abs(target[1]-center[1]) > 10 then
			X = X * 2
		end
	end
	animator.setGlobalTag("eyesX", X)
	animator.setGlobalTag("eyesY", Y)
end

function detectEmote()
	if sbq.driver and world.entityExists(sbq.driver) then
		local portrait = world.entityPortrait(sbq.driver, "full")
		for _, part in ipairs(portrait) do
			local imageString = part.image
			-- check for doing an emote animation
			local found1, found2 = imageString:find("/emote.png:")
			if found1 ~= nil then
				local found3, found4 = imageString:find(".1", found2, found2 + 10)
				if found3 ~= nil then
					local emote = imageString:sub(found2 + 1, found3 - 1)
					if type((sbq.stateconfig[sbq.state].emoteAnimations or {})[emote]) == "table" then
						sbq.doAnims((sbq.stateconfig[sbq.state].emoteAnimations or {})[emote])
					else
						sbq.doAnim("emoteState", emote)
					end
					break
				end
			end
		end
	end
end

function checkPartsEnabled()
	local defaultSbqData = config.getParameter("sbqData")
	if sbq.settings.penis then
		sbq.setPartTag("global", "cockVisible", "")
		sbq.sbqData.locations.shaft.max = defaultSbqData.locations.shaft.max
	else
		sbq.setPartTag("global", "cockVisible", "?crop;0;0;0;0")
		sbq.sbqData.locations.shaft.max = 0
	end
	if sbq.settings.balls then
		sbq.setPartTag("global", "ballsVisible", "")
		sbq.sbqData.locations.ballsL.max = defaultSbqData.locations.balls.max
		sbq.sbqData.locations.ballsR.max = defaultSbqData.locations.balls.max
	else
		sbq.setPartTag("global", "ballsVisible", "?crop;0;0;0;0")
		sbq.sbqData.locations.ballsL.max = 0
		sbq.sbqData.locations.ballsR.max = 0
	end
end

-------------------------------------------------------------------------------

function oralVore(args, tconfig)
	if not mcontroller.onGround() or sbq.movement.falling then return false end
	return sbq.doVore(args, tconfig.location, {}, "swallow", tconfig.voreType)
end

function checkOralVore()
	return sbq.checkEatPosition(sbq.localToGlobal( sbq.stateconfig[sbq.state].actions.oralVore.position ), 5, "belly", "oralVore")
end

function oralEscape(args, tconfig)
	return sbq.doEscape(args, {wet = { power = 5, source = entity.id()}}, {}, tconfig.voreType )
end

-------------------------------------------------------------------------------

function cockVore(args, tconfig)
	if not mcontroller.onGround() or sbq.movement.falling then return false end
	return sbq.doVore(args, tconfig.location, {}, "swallow", tconfig.voreType)
end

function checkCockVore()
	local shaftOccupant = sbq.findFirstOccupantIdForLocation("shaft")
	if shaftOccupant then
		return sbq.moveToLocation({id = shaftOccupant}, {location = "balls"})
	end
	return sbq.checkEatPosition(sbq.localToGlobal( sbq.stateconfig[sbq.state].actions.cockVore.position ), 5, "shaft", "cockVore")
end

function cockEscape(args, tconfig)
	return sbq.doEscape(args, {glueslow = { power = 5 + (sbq.lounging[args.id].progressBar), source = entity.id()}}, {}, tconfig.voreType )
end

-------------------------------------------------------------------------------

function analVore(args, tconfig)
	if not mcontroller.onGround() or sbq.movement.falling then return false end
	return sbq.doVore(args, tconfig.location, {}, "swallow", tconfig.voreType)
end

function checkAnalVore()
	local buttOccupant = sbq.findFirstOccupantIdForLocation("butt")
	if buttOccupant then
		sbq.doTransition("analPullInside", { id = buttOccupant })
		return true
	end
	return sbq.checkEatPosition(sbq.localToGlobal( sbq.stateconfig[sbq.state].actions.analVore.position ), 4, "butt", "analVore")
end

function analEscape(args, tconfig)
	return sbq.doEscape(args, {}, {}, tconfig.voreType )
end

-------------------------------------------------------------------------------


-------------------------------------------------------------------------------

function checkVore()
	if checkOralVore() then return true end
	if checkCockVore() then return true end
	if checkAnalVore() then return true end
end

-------------------------------------------------------------------------------

state.stand.oralVore = oralVore
state.stand.cockVore = cockVore
state.stand.analVore = analVore

state.stand.checkVore = checkVore
state.stand.checkOralVore = checkOralVore
state.stand.checkCockVore = checkCockVore
state.stand.checkAnalVore = checkAnalVore

state.stand.oralEscape = oralEscape
state.stand.cockEscape = cockEscape
state.stand.analEscape = analEscape

state.stand.moveToLocation = sbq.moveToLocation
state.stand.switchBalls = sbq.switchBalls

-------------------------------------------------------------------------------
