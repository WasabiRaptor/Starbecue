
require("/vehicles/sbq/sbq_main.lua")
state = {
	stand = {},
	crouch = {},
	fly = {},
	sit = {},
	hug = {}
}
-------------------------------------------------------------------------------
--[[

Commissioned by:
	-xeronious#8891			https://www.furaffinity.net/user/xeronious/

Sprites created by:
	-Wasabi_Raptor#1533		https://www.furaffinity.net/user/lokithevulpix/

Scripts created by:
	Zygan#0404
	Wasabi_Raptor#1533

TODO:
	-roaming behavior
]]--
-------------------------------------------------------------------------------

function sbq.init()
	getColors()
end

sbq.fullSuccTime = 3

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

		sbq.settings.firstLoadDone = true
		sbq.setColorReplaceDirectives()
		sbq.setSkinPartTags()
		world.sendEntityMessage(sbq.spawner, "sbqSaveSettings", sbq.settings, "sbqXeronious")
	end
end


function sbq.update(dt)
	sbq.whenFalling()
	sbq.armRotationUpdate()
	sbq.setGrabTarget()
	if not sbq.heldControl(sbq.driverSeat, sbq.succControl or "primaryFire") then
		if sbq.succTime >= sbq.fullSuccTime then
			sbq.doAnims(sbq.succArgs.puffAnim or sbq.succArgs.animation)
			sbq.succTime = 0
			sbq.projectile(sbq.succArgs.puff, sbq.driver)
		end
		sbq.succTime = math.max(0, sbq.succTime - sbq.dt)
	end
end

-------------------------------------------------------------------------------

function sbq.whenFalling()
	if not (sbq.state == "stand" or sbq.state == "fly" or sbq.state == "crouch") and not mcontroller.onGround() then
		sbq.setState( "stand" )
		sbq.grabbing = sbq.findFirstOccupantIdForLocation("hug")
	end
end

function sbq.setItemActionColorReplaceDirectives()
	local colorReplaceString = sbq.sbqData.itemActionDirectives or ""

	if sbq.sbqData.replaceColors ~= nil then
		colorReplaceString = sbq.doColorReplaceString(colorReplaceString, 1, { "154247", "23646a", "39979e", "4cc1c9" })
		colorReplaceString = sbq.doColorReplaceString(colorReplaceString, 4, { "63263d", "7a334d", "9d4165" } )
	end

	sbq.itemActionDirectives = colorReplaceString
end

function sbq.letout(id)
	local id = id or sbq.getRecentPrey()
	if (not id) or (not sbq.lounging[id]) then return false end

	local location = sbq.lounging[id].location

	if location == "belly" then
		if sbq.lounging[id].species == "sbqEgg"then
			return sbq.doTransition("eggEscape", {id = id})
		end
		if sbq.heldControl(sbq.driverSeat, "down") then
			return sbq.doTransition("analEscape", {id = id})
		else
			return sbq.doTransition("oralEscape", {id = id})
		end
	elseif location == "tail" then
		return sbq.doTransition("tailEscape", {id = id})
	elseif location == "hug" then
		sbq.grabbing = nil
		return sbq.uneat(id)
	end
end

function checkEggSitup()
	if not sbq.driving then
		for i = 0, sbq.occupantSlots do
			if sbq.occupant[i].species == "sbqEgg" then
				return sbq.doTransition("up")
			end
		end
	end
end

sbq.succTime = 0
sbq.succing = false
function succ(args, control, pressed)
	if control == "force" or sbq.transitionLock then return false end

	sbq.succControl = control
	sbq.succArgs = args

	local aim = sbq.seats[sbq.driverSeat].controls.aim
	sbq.facePoint(aim[1])

	if sbq.succTime > sbq.fullSuccTime then
		sbq.doAnims(args.fullPuffAnim)
		return false
	end


	local globalSuccPosition = sbq.localToGlobal(args.position or {0,0})

	local magnitude = world.magnitude(globalSuccPosition, aim)
	local range = 30
	if magnitude > range then return end

	sbq.succTime = sbq.succTime + sbq.dt
	sbq.movement.aimingLock = 0.1

	local entities = world.entityLineQuery(globalSuccPosition, aim, {
		withoutEntityId = entity.id()
	})

	local data = {
		destination = globalSuccPosition,
		source = entity.id(),
		speed = 15,
		force = 500,
		direction = sbq.direction,
		range = range
	}

	for i, id in ipairs(entities) do
		if id and entity.entityInSight(id) then
			sbq.loopedMessage("succ"..i, id, "sbqSucc", {data})
		end
	end

	sbq.randomTimer("succ", 0, 0.3, function ()
		local effectPosition = { aim[1]+math.random(-3,3)*math.random(), aim[2]+math.random(-3,3)*math.random() }

		local aimLine = world.lineCollision(globalSuccPosition, effectPosition, { "Null", "block", "slippery" })
		if aimLine ~= nil then
			effectPosition = aimLine
		end
		world.spawnProjectile( "sbqSuccEffect", effectPosition, entity.id(), world.distance( globalSuccPosition, effectPosition ), false, {data = data} )
	end)

	sbq.checkEatPosition( globalSuccPosition, 3, "belly", "succEat", true)
	return true
end

function grab()
	sbq.grab("hug")
end

function hugGrab()
	return sbq.checkEatPosition(mcontroller.position(), 5, "hug", "hug")
end

function hugUnGrab()
	return sbq.uneat(sbq.findFirstOccupantIdForLocation("hug"))
end

function bellyToTail(args)
	return sbq.moveOccupantLocation(args, "tail")
end

function tailToBelly(args)
	return sbq.moveOccupantLocation(args, "belly")
end

function grabOralEat(args, tconfig)
	sbq.grabbing = args.id
	return sbq.doVore(args, "belly", {}, "swallow", tconfig.voreType)
end

function oralEat(args, tconfig)
	return sbq.doVore(args, "belly", {}, "swallow", tconfig.voreType)
end

function tailVore(args, tconfig)
	return sbq.doVore(args, "tail", {}, "swallow", tconfig.voreType)
end

function analVore(args, tconfig)
	return sbq.doVore(args, "belly", {}, "swallow", tconfig.voreType)
end

function sitAnalEat(args)
	local args = { id = sbq.findFirstOccupantIdForLocation("pinned")}
	if not args.id then return false end
	if sbq.moveOccupantLocation(args, "belly") then
		sbq.lounging[args.id].visible = false
		return true
	end
end

function checkOral()
	return sbq.checkEatPosition(sbq.localToGlobal( {0, 0} ), 5, "belly", "oralVore")
end

function checkTail()
	return sbq.checkEatPosition(sbq.localToGlobal({-5, -2}), 2, "tail", "tailVore")
end

function checkAnal()
	return sbq.checkEatPosition(sbq.localToGlobal({-1, -3}), 2, "belly", "analVore")
end

function sitCheckAnal()
	local victim = sbq.findFirstOccupantIdForLocation("pinned")
	local entityaimed = world.entityQuery(sbq.seats[sbq.driverSeat].controls.aim, 2, {
		withoutEntityId = sbq.driver,
		includedTypes = {"creature"}
	})
	if entityaimed[1] == victim then
		sbq.doTransition("analVore")
		return true
	end
end

function oralEscape(args, tconfig)
	return sbq.doEscape(args, {wet = { power = 5, source = entity.id()}}, {}, tconfig.voreType )
end

function analEscape(args, tconfig)
	return sbq.doEscape(args, {}, {}, tconfig.voreType )
end

function tailEscape(args, tconfig)
	return sbq.doEscape(args, {wet = { power = 5, source = entity.id()}}, {}, tconfig.voreType )
end

function checkVore()
	if checkAnal() then return true end
	if checkTail() then return true end
	if checkOral() then return true end
end

function sitCheckVore()
	if checkOral() then return true end
	if checkTail() then return true end
	if sitCheckAnal() then return true end
end


function unpin(args)
	args.id = sbq.findFirstOccupantIdForLocation("pinned")
	local returnval = {}
	returnval[1], returnval[2], returnval[3] = sbq.doEscape(args, {}, {})
	return true, returnval[2], returnval[3]
end

-------------------------------------------------------------------------------

function state.stand.begin()
	sbq.grabbing = sbq.findFirstOccupantIdForLocation("hug")
	sbq.movement.flying = nil
	sbq.setMovementParams( "default" )
	sbq.resolvePosition(5)
end

function state.stand.update()
	if not sbq.transitionLock then
		if mcontroller.onGround() and sbq.heldControl(sbq.driverSeat, "shift") and sbq.heldControl(sbq.driverSeat, "down") then
			sbq.letGrabGo("hug")
			sbq.doTransition( "crouch" )
			return
		elseif not mcontroller.onGround() and sbq.pressControl(sbq.driverSeat, "jump") then
			sbq.letGrabGo("hug")
			sbq.setState( "fly" )
			return
		end
	end
end

function state.stand.sitpin(args)
	local pinnable = { args.id }
	local sat

	if sbq.grabbing ~= nil and sbq.occupants.hug <= sbq.sbqData.locations.pinned.maxNested then
		local angle = sbq.armRotation.frontarmsAngle * 180/math.pi
		if (angle >= 225 and angle <= 315) or (angle <= -45 and angle >= -135) then
			sbq.uneat(sbq.grabbing)
			pinnable = { sbq.grabbing }
			sbq.grabbing = nil
			sat = true
			sbq.timer("restoreClickActions", 0.5, function()
				sbq.movement.clickActionsDisabled = false
			end)
		end
	end
	-- if not interact target or target isn't too far away
	if not sat and (args.id == nil or math.abs(sbq.globalToLocal( world.entityPosition( args.id ) )[1]) > 3) then
		local pinbounds = {
			sbq.localToGlobal({-3, -4}),
			sbq.localToGlobal({-1, -5})
		}
		pinnable = world.playerQuery( pinbounds[1], pinbounds[2] )
		if #pinnable == 0 and sbq.driving then
			pinnable = world.npcQuery( pinbounds[1], pinbounds[2] )
		end
	end
	if #pinnable >= 1 then
		sbq.addRPC(world.sendEntityMessage(pinnable[1], "sbqIsPreyEnabled", "held"), function(enabled)
			if enabled and enabled.enabled then
				sbq.eat( { id = pinnable[1], size = enabled.size or 1}, "held", "pinned" )
			end
			sbq.doTransition("sit")
		end)
	else
		sbq.doTransition("sit")
	end
end

state.stand.bellyToTail = bellyToTail
state.stand.tailToBelly = tailToBelly
state.stand.eat = grabOralEat
state.stand.succEat = oralEat
state.stand.tailVore = tailVore
state.stand.analVore = analVore

state.stand.checkOralVore = checkOral
state.stand.checkTailVore = checkTail
state.stand.checkAnalVore = checkAnal
state.stand.vore = checkVore

state.stand.oralEscape = oralEscape
state.stand.analEscape = analEscape
state.stand.tailEscape = tailEscape

state.stand.succ = succ
state.stand.grab = grab

-------------------------------------------------------------------------------

function state.sit.update()
	checkEggSitup()

	if sbq.pressControl(sbq.driverSeat, "jump") then
		sbq.doTransition("analVore")
	end

	if sbq.occupants.hug > 0 then
		sbq.setState("hug")
	end

	-- simulate npc interaction when nearby
	if sbq.occupants.hug == 0 and not sbq.isObject and not sbq.transitionLock then
		if sbq.randomChance(1) then -- every frame, we don't want it too often
			local npcs = world.npcQuery(mcontroller.position(), 4)
			if npcs[1] ~= nil then
				sbq.doTransition( "hug", {id=npcs[1]} )
			end
		end
	end
end

function state.sit.hug( args )
	sbq.addRPC(world.sendEntityMessage(args.id, "sbqIsPreyEnabled", "held"), function(enabled)
		if enabled and enabled.enabled then
			return sbq.eat( args, "held", "hug" )
		end
	end)
end

state.sit.bellyToTail = bellyToTail
state.sit.tailToBelly = tailToBelly
state.sit.eat = grabOralEat
state.sit.succEat = oralEat
state.sit.tailVore = tailVore
state.sit.analVore = sitAnalEat

state.sit.vore = sitCheckVore
state.sit.checkOralVore = checkOral
state.sit.checkTailVore = checkTail
state.sit.checkAnalVore = sitCheckAnal

state.sit.oralEscape = oralEscape
state.sit.tailEscape = tailEscape
state.sit.unpin = unpin

state.sit.succ = succ
state.sit.grab = hugGrab

-------------------------------------------------------------------------------

function state.hug.begin()
	local victim = sbq.findFirstOccupantIdForLocation("hug")
	if victim then
		sbq.grabbing = nil
		sbq.doVictimAnim( victim, "hugcenter", "bodyState")
	end
end

function state.hug.update()
	if sbq.pressControl(sbq.driverSeat, "jump") then
		sbq.doTransition("analVore")
	end

	if sbq.occupants.hug < 1 then
		sbq.setState("sit")
	end
end

function state.hug.unhug( args )
	sbq.uneat(sbq.findFirstOccupantIdForLocation("hug"))
end

state.hug.bellyToTail = bellyToTail
state.hug.tailToBelly = tailToBelly
state.hug.eat = grabOralEat
state.hug.succEat = oralEat
state.hug.tailVore = tailVore
state.hug.analVore = sitAnalEat

state.hug.vore = sitCheckVore
state.hug.checkOralVore = checkOral
state.hug.checkTailVore = checkTail
state.hug.checkAnalVore = sitCheckAnal

state.hug.oralEscape = oralEscape
state.hug.tailEscape = tailEscape
state.hug.unpin = unpin

state.hug.succ = succ
state.hug.grab = hugUnGrab

-------------------------------------------------------------------------------

function state.crouch.update()
	local pos1 = sbq.localToGlobal({3, 4})
	local pos2 = sbq.localToGlobal({-3, 1})

	if not world.rectCollision( {pos1[1], pos1[2], pos2[1], pos2[2]}, { "Null", "block", "slippery"} )
	and not (sbq.heldControl( sbq.driverSeat, "down") and sbq.heldControl( sbq.driverSeat, "shift"))
	then
		sbq.doTransition( "uncrouch" )
		return
	end
end

function state.crouch.begin()
	sbq.letGrabGo("hug")
	sbq.setMovementParams( "crouch" )
	sbq.resolvePosition(5)
end

state.crouch.bellyToTail = bellyToTail
state.crouch.tailToBelly = tailToBelly

state.crouch.succEat = oralEat
state.crouch.tailVore = tailVore
state.crouch.checkTailVore = checkTail
state.crouch.vore = checkTail

state.crouch.tailEscape = tailEscape

state.crouch.succ = succ

-------------------------------------------------------------------------------

function state.fly.update()
	if not sbq.transitionLock then
		if sbq.pressControl( sbq.driverSeat, "jump" )
		or ((sbq.occupants.mass >= sbq.movementParams.fullThreshold) and mcontroller.onGround())
		or sbq.underWater()
		then
			sbq.setState( "stand" )
			return
		end
	end
end

function state.fly.begin()
	sbq.letGrabGo("hug")
	sbq.movement.flying = true
	sbq.setMovementParams( "fly" )
end

function state.fly.vore()
	if checkAnal() then return true end
	if checkTail() then return true end
end

state.fly.bellyToTail = bellyToTail
state.fly.tailToBelly = tailToBelly
state.fly.eat = oralEat
state.fly.succEat = oralEat
state.fly.tailVore = tailVore
state.fly.analVore = analVore

state.fly.checkOralVore = checkOral
state.fly.checkTailVore = checkTail
state.fly.checkAnalVore = checkAnal

state.fly.oralEscape = oralEscape
state.fly.analEscape = analEscape
state.fly.tailEscape = tailEscape

state.fly.succ = succ

-------------------------------------------------------------------------------
