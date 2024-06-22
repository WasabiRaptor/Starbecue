
require("/vehicles/sbq/sbq_main.lua")

state = {
	stand = {},
}

function sbq.init()
	getColors()
	checkPartsEnabled()
end

function sbq.settingsMenuUpdated()
	checkPartsEnabled()
end

function sbq.setItemActionColorReplaceDirectives()
	local colorReplaceString = sbq.sbqData.itemActionDirectives or ""

	if sbq.sbqData.replaceColors ~= nil then
		colorReplaceString = sbq.doColorReplaceString(colorReplaceString, 1, { "154247", "23646a", "39979e", "4cc1c9" })
		colorReplaceString = sbq.doColorReplaceString(colorReplaceString, 7, { "63263d", "7a334d", "9d4165" } )
	end

	sbq.itemActionDirectives = colorReplaceString
end

function sbq.letout(id)
	local id = id or sbq.getRecentPrey()
	if (not id) or (not sbq.lounging[id]) then return false end

	local location = sbq.lounging[id].location

	if location == "belly" then
		if sbq.heldControl(sbq.driverSeat, "down") then
			return sbq.doTransition("analEscape", {id = id})
		else
			return sbq.doTransition("oralEscape", {id = id})
		end
	elseif location == "cock" then
		return sbq.doTransition("cockEscape", {id = id})

	elseif location == "ballsL" or location == "ballsR" or location == "balls" then
		return sbq.moveToLocation({id = id}, {location = "cock"})
	elseif location == "womb" then
		return sbq.doTransition("unbirthEscape", {id = id})
	end
end

-------------------------------------------------------------------------------

function getColors()
	if not sbq.settings.firstLoadDone then
		for i, colors in ipairs(sbq.sbqData.replaceColors or {}) do
			sbq.settings.replaceColors[i] = math.random( #colors - 1 )
		end
		for skin, data in pairs(sbq.sbqData.replaceSkin or {}) do
			local result = data.skins[math.random(#data.skins)]
			for i, partname in ipairs(data.parts) do
				sbq.settings.skinNames[partname] = result
			end
		end
		for settingname, settingvalue in pairs(sbq.settings) do
			sbq.autoSetSettings(settingname, settingvalue)
		end

		sbq.settings.firstLoadDone = true
		sbq.setColorReplaceDirectives()
		sbq.setSkinPartTags()
		world.sendEntityMessage(sbq.spawner, "sbqSaveSettings", sbq.settings, "sbqZiellekDragon")
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
	return sbq.doVore(args, "belly", {}, "swallow", tconfig.voreType)
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
	return sbq.doVore(args, "cock", {}, "swallow", tconfig.voreType)
end

function checkCockVore()
	local shaftOccupant = sbq.findFirstOccupantIdForLocation("cock")
	if shaftOccupant then
		return sbq.moveToLocation({id = shaftOccupant}, {location = "balls"})
	end
	return sbq.checkEatPosition(sbq.localToGlobal( sbq.stateconfig[sbq.state].actions.cockVore.position ), 5, "cock", "cockVore")
end

function cockEscape(args, tconfig)
	return sbq.doEscape(args, {glueslow = { power = 5 + (sbq.lounging[args.id].progressBar), source = entity.id()}}, {}, tconfig.voreType )
end

-------------------------------------------------------------------------------

function analVore(args, tconfig)
	if not mcontroller.onGround() or sbq.movement.falling then return false end
	return sbq.doVore(args, "belly", {}, "swallow", tconfig.voreType)
end

function checkAnalVore()
	return sbq.checkEatPosition(sbq.localToGlobal( sbq.stateconfig[sbq.state].actions.analVore.position ), 4, "belly", "analVore")
end

function analEscape(args, tconfig)
	return sbq.doEscape(args, {}, {}, tconfig.voreType )
end

-------------------------------------------------------------------------------

function unbirth(args, tconfig)
	if not sbq.settings.pussy or not mcontroller.onGround() or sbq.movement.falling then return false end
	return sbq.doVore(args, "womb", {}, "swallow", tconfig.voreType)
end

function checkUnbirth()
	if not sbq.settings.pussy then return false end
	return sbq.checkEatPosition(sbq.localToGlobal( sbq.stateconfig[sbq.state].actions.unbirth.position ), 4, "womb", "unbirth")
end

function unbirthEscape(args, tconfig)
	if not sbq.settings.pussy then return false end
	return sbq.doEscape(args, {wet = { power = 5, source = entity.id()}}, {}, tconfig.voreType )
end

-------------------------------------------------------------------------------

function checkVore()
	if checkOralVore() then return true end
	if checkCockVore() then return true end
	if checkUnbirth() then return true end
	if checkAnalVore() then return true end
end

-------------------------------------------------------------------------------

state.stand.oralVore = oralVore
state.stand.cockVore = cockVore
state.stand.analVore = analVore
state.stand.unbirth = unbirth

state.stand.checkVore = checkVore
state.stand.checkOralVore = checkOralVore
state.stand.checkCockVore = checkCockVore
state.stand.checkAnalVore = checkAnalVore
state.stand.checkUnbirth = checkUnbirth

state.stand.oralEscape = oralEscape
state.stand.cockEscape = cockEscape
state.stand.analEscape = analEscape
state.stand.unbirthEscape = unbirthEscape

state.stand.moveToLocation = sbq.moveToLocation
state.stand.switchBalls = sbq.switchBalls

-------------------------------------------------------------------------------
