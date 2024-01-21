
function sbq.updateDriving(dt)
	if sbq.isNested then return end

	if sbq.driver and sbq.driving then
		local light = sbq.sbqData.lights.driver
		if light ~= nil then
			local lightPosition
			if light.position ~= nil then
				lightPosition = sbq.localToGlobal(light.position)
			else
				lightPosition = world.entityPosition( sbq.driver )
			end
			world.sendEntityMessage( sbq.driver, "sbqLight", sb.jsonMerge(light, {position = lightPosition}) )
		end

		sbq.predHudOpen = math.max(0, sbq.predHudOpen - dt)
		if ((not sbq.driving) or (sbq.isNested)) or sbq.settings.disableHud then
		else
			if sbq.predHudOpen <= 0 then
				sbq.predHudOpen = 2
				world.sendEntityMessage( sbq.driver, "sbqOpenMetagui", "starbecue:predHud" )
			end
		end

		--local aim = vehicle.aimPosition(sbq.driverSeat)
		--local cursor = "/cursors/cursors.png:pointer"
		--world.sendEntityMessage( sbq.driver, "sbqDrawCursor", aim, cursor)
	end

	if not mcontroller.onGround() and not sbq.underWater() then
		sbq.movement.airtime = sbq.movement.airtime + dt
	end

	if (sbq.stateconfig[sbq.state].control ~= nil) and not sbq.movementLock then
		local state = sbq.stateconfig[sbq.state]
		sbq.doClickActions(state, dt)

		sbq.movement.aimingLock = math.max(0, sbq.movement.aimingLock - dt)

		local dx = sbq.seats[sbq.driverSeat].controls.dx
		if sbq.activeControls.moveDirection then
			dx = sbq.activeControls.moveDirection
		end
		local dy = sbq.seats[sbq.driverSeat].controls.dy
		if (dx ~= 0) then
			if (sbq.movement.aimingLock <= 0) then
				sbq.faceDirection( dx )
			end
			if (sbq.direction * dx) > 0 then
				sbq.movement.direction = 1
			else
				sbq.movement.direction = -1
			end
			sbq.setPartTag( "global", "direction", sbq.movement.direction)
		end

		if sbq.stateconfig[sbq.state].defaultActions ~= nil and sbq.driver ~= nil then
			sbq.loopedMessage("primaryItemData", sbq.driver, "primaryItemData", {{
				defaultClickAction = sbq.stateconfig[sbq.state].defaultActions[1],
				directives = sbq.itemActionDirectives,
				defaultIcon = (state.actions[sbq.stateconfig[sbq.state].defaultActions[1]] or {}).icon
			}})
			sbq.loopedMessage("altItemData", sbq.driver, "altItemData", {{
				defaultClickAction = sbq.stateconfig[sbq.state].defaultActions[2],
				directives = sbq.itemActionDirectives,
				defaultIcon = (state.actions[sbq.stateconfig[sbq.state].defaultActions[2]] or {}).icon
			}})
		end

		sbq.groundMovement(dx, dy, state, dt)
		sbq.waterMovement(dx, dy, state, dt)
		sbq.jumpMovement(dx, dy, state, dt)
		sbq.airMovement(dx, dy, state, dt)
		sbq.flyMovement(dx, dy, state, dt)
		sbq.doControls() -- set by mcontroller.control*(), used by pathfinding
	end
	sbq.driverSeatStateChange()
end

function sbq.groundMovement(dx, dy, state, dt)
	sbq.movement.groundMovement = "run"
	if sbq.heldControl(sbq.driverSeat, "shift") or (sbq.occupants.mass >= (sbq.movementParams.fullThreshold or 1)) or (sbq.activeControls.run == false) then
		sbq.movement.groundMovement = "walk"
	end
	if mcontroller.onGround() and not sbq.movement.flying then
		if dx ~= 0 and not state.control.groundMovementDisabled then
			sbq.movingDX = dx
			sbq.doAnims( state.control.animations[sbq.movement.groundMovement] )
			sbq.movement.animating = true
			mcontroller.applyParameters{ groundFriction = sbq.movementParams.ambulatingGroundFriction }
			mcontroller.approachXVelocity( dx * sbq.movementParams[sbq.movement.groundMovement.."Speed"], sbq.movementParams.groundForce * sbq.movementParams.mass)
		elseif sbq.movement.animating then
			sbq.doAnims( state.idle )
			sbq.movement.animating = false
			mcontroller.applyParameters{ groundFriction = sbq.movementParams.normalGroundFriction }
		end
		sbq.movement.jumps = 0
		sbq.movement.falling = false
		sbq.movement.airtime = 0
	end
end

function sbq.jumpMovement(dx, dy, state, dt)
	sbq.movement.sinceLastJump = sbq.movement.sinceLastJump + dt

	if not mcontroller.onGround() and (dy == -1 or sbq.activeControls.drop) then
		mcontroller.applyParameters{ ignorePlatformCollision = true }
	elseif sbq.isPathfinding and sbq.pathMover.downHoldTimer2 and sbq.pathMover.downHoldTimer2 > 0 then
		sbq.pathMover.downHoldTimer2 = sbq.pathMover.downHoldTimer2 - dt
	else
		mcontroller.applyParameters{ ignorePlatformCollision = false }
	end

	sbq.movement.jumpProfile = "airJumpProfile"
	if mcontroller.liquidPercentage() ~= 0 then
		sbq.movement.jumpProfile = "liquidJumpProfile"
	end

	if state.control.jumpMovementDisabled or sbq.movement.flying then return end

	if sbq.heldControl( sbq.driverSeat, "jump" ) or sbq.activeControls.drop then
		if (sbq.movement.jumps < sbq.movementParams.jumpCount) and (sbq.movement.sinceLastJump >= sbq.movementParams[sbq.movement.jumpProfile].reJumpDelay)
		and ((not sbq.movement.jumped) or sbq.movementParams[sbq.movement.jumpProfile].autoJump) and ((not sbq.underWater()) or mcontroller.onGround()) and not sbq.activeControls.drop
		then
			if state.control.jumpMovementDisabled then return end
			sbq.movement.sinceLastJump = 0
			sbq.movement.jumps = sbq.movement.jumps + 1
			sbq.movement.jumped = true
			if (dy ~= -1) then
				sbq.doAnims( state.control.animations.jump )
				sbq.movement.animating = true
				sbq.movement.falling = false
				mcontroller.setYVelocity(sbq.movementParams[sbq.movement.jumpProfile].jumpSpeed)
				if (sbq.movement.jumps > 1) and mcontroller.liquidPercentage() == 0 then
					-- particles from effects/multiJump.effectsource
					if sbq.movementParams.pulseEffect then
						animator.burstParticleEmitter( sbq.movementParams.pulseEffect )
						animator.playSound( "doublejump" )
						for i = 1, sbq.movementParams.pulseSparkles do
							animator.burstParticleEmitter( "defaultblue" )
							animator.burstParticleEmitter( "defaultlightblue" )
						end
					end
				end
			end
		end
		if dy == -1 or sbq.activeControls.drop then
			mcontroller.applyParameters{ ignorePlatformCollision = true }
		elseif sbq.movement.jumped and sbq.heldControlMax(sbq.driverSeat, "Jump", sbq.movementParams[sbq.movement.jumpProfile].jumpHoldTime) and mcontroller.yVelocity() <= sbq.movementParams[sbq.movement.jumpProfile].jumpSpeed then
			mcontroller.force({ 0, sbq.movementParams[sbq.movement.jumpProfile].jumpControlForce * sbq.movementParams.mass})
		end
	else
		sbq.movement.jumped = false
	end
end

function sbq.airMovement( dx, dy, state, dt )
	if sbq.underWater() or mcontroller.onGround() or state.control.airMovementDisabled or sbq.movement.flying then return end

	sbq.movement.animating = true

	if dx ~= 0 then
		mcontroller.approachXVelocity( dx * sbq.movementParams[sbq.movement.groundMovement.."Speed"], sbq.movementParams.airForce * sbq.movementParams.mass)
	end

	if (mcontroller.yVelocity() < sbq.movementParams.fallStatusSpeedMin ) and (not sbq.movement.falling) and sbq.movement.airtime >= 0.25 then
		sbq.doAnims( state.control.animations.fall )
		sbq.movement.falling = true
	elseif (mcontroller.yVelocity() > 0) and (sbq.movement.falling) then
		sbq.doAnims( state.control.animations.jump )
		sbq.movement.falling = false
	end
end

function sbq.waterMovement( dx, dy, state, dt )
	if not sbq.underWater() or mcontroller.onGround() or state.control.waterMovementDisabled then return end

	local swimSpeed = sbq.movementParams.swimSpeed or sbq.movementParams[sbq.movement.groundMovement.."Speed"]
	local dy = dy
	if sbq.heldControl(sbq.driverSeat, "jump") and (dy ~= 1) then
		dy = dy + 1
	end
	if (dx ~= 0) or (dy ~= 0)then
		sbq.doAnims( state.control.animations.swim )
		if (dx ~= 0) then
			mcontroller.approachXVelocity( dx * sbq.movementParams[sbq.movement.groundMovement.."Speed"], sbq.movementParams.liquidForce * sbq.movementParams.mass)
		end
		if (dy ~= 0) then
			mcontroller.approachYVelocity( dy * sbq.movementParams.liquidJumpProfile.jumpSpeed or sbq.movementParams.airJumpProfile.jumpSpeed, (sbq.movementParams.liquidJumpProfile.jumpControlForce or sbq.movementParams.airJumpProfile.jumpControlForce) * sbq.movementParams.mass)
		end
	else
		sbq.doAnims( state.control.animations.swimIdle )
	end
	sbq.movement.animating = true
	sbq.movement.jumps = 0
	sbq.movement.falling = false
	sbq.movement.airtime = 0
end

function sbq.flyMovement( dx, dy, state, dt )
	if sbq.movementParams.flySpeed == 0 or state.control.flyMovementDisabled or mcontroller.onGround() or sbq.underWater() or not sbq.movement.flying then return end

	sbq.doAnims( state.control.animations.fly )
	mcontroller.approachXVelocity( dx * sbq.movementParams.flySpeed, sbq.movementParams.airForce * sbq.movementParams.mass)
	mcontroller.approachYVelocity( dy * sbq.movementParams.flySpeed, sbq.movementParams.airForce * sbq.movementParams.mass)
	sbq.movement.animating = true

end

sbq.clickActionCooldowns = {
	vore = 0
}

function sbq.assignTransformMenu()

	sbq.addRPC(world.sendEntityMessage(sbq.driver, "sbqLoadSettings"), function (settings)
		if settings and settings.types then
			local options = {
				{
					name = "despawn",
					icon = "/interface/xhover.png"
				}
			}
			for pred, data in pairs(settings.types) do
				if data.enable then
					local skin = (settings[pred].skinNames or {}).head or "default"
					local directives = sbq.getColorReplaceDirectives(root.assetJson("/vehicles/sbq/"..pred.."/"..pred..".vehicle").sbqData, settings[pred] or {}) or ""
					if #options <= 10 then
						if data.index ~= nil and data.index+1 <= #options then
							table.insert(options, data.index+1, {
								name = pred,
								icon = "/vehicles/sbq/"..pred.."/skins/"..skin.."/icon.png"..directives
							})
						else
							table.insert(options, {
								name = pred,
								icon = "/vehicles/sbq/"..pred.."/skins/"..skin.."/icon.png"..directives
							})
						end
					end
				end
			end
			world.sendEntityMessage( sbq.driver, "sbqOpenInterface", "sbqRadialMenu", {options = options, type = "transformSelect" } )
		else
			noTFMenu = true
			sbq.lastRadialSelection = "despawn"
			sbq.radialSelectionType = "transformSelect"
		end
	end, function () -- the fail callback
		noTFMenu = true
		sbq.lastRadialSelection = "despawn"
		sbq.radialSelectionType = "transformSelect"
	end)
end

local noTFMenu

function sbq.transformAction()
	if sbq.heldControl(sbq.driverSeat, "special1", 0.2) and sbq.totalTimeAlive > 1 and not noTFMenu then
		if not sbq.movement.transformActionRadial then
			sbq.movement.transformActionRadial = true
			sbq.assignTransformMenu()
		else
			sbq.loopedMessage("radialSelection", sbq.driver, "sbqGetRadialSelection", {}, function(data)

				if data.selection ~= nil and data.type == "transformSelect" then
					sbq.lastRadialSelection = data.selection
					sbq.radialSelectionType = data.type
					if data.selection == "cancel" then return end
					if data.pressed and data.selection == "despawn" and not sbq.click then
						sbq.reversion()
					elseif data.pressed and not sbq.click then
						sbq.addRPC(world.sendEntityMessage(sbq.driver, "sbqLoadSettings", data.selection), function(settings)
							sbq.transformVehicle(settings, data.selection)
						end)
					end
					if data.button == 0 and not sbq.click then
					elseif data.button == 2 and not sbq.click then
					end
					sbq.click = data.pressed
				end
			end)
		end
		return true
	elseif sbq.movement.transformActionRadial then
		world.sendEntityMessage( sbq.driver, "sbqOpenInterface", "sbqClose" )
		if sbq.radialSelectionType == "transformSelect" then
			if sbq.lastRadialSelection == "despawn" then
				sbq.reversion()
			elseif sbq.lastRadialSelection ~= "cancel" then
				sbq.addRPC(world.sendEntityMessage(sbq.driver, "sbqLoadSettings", sbq.lastRadialSelection), function(settings)
					sbq.transformVehicle(settings, sbq.lastRadialSelection)
				end)
			end
		end
		sbq.movement.transformActionRadial = nil
	end
end

function sbq.transformVehicle(settings, selection)
	if not sbq.findFirstOccupantIdForLocation("escaping") then
		world.spawnVehicle( selection, mcontroller.position(), { driver = sbq.driver, settings = settings, retrievePrey = entity.id(), direction = sbq.direction, scale = mcontroller.scale() } )
	end
end


function sbq.assignClickAction(state)
	if sbq.heldControl(sbq.driverSeat, "shift", 0.2) and sbq.heldControl(sbq.driverSeat, "up", 0.2) then
		if sbq.movement.occupantsWhenAssigned ~= sbq.occupants.total then
			sbq.movement.assignClickActionRadial = false
		end
		if not sbq.movement.assignClickActionRadial then
			sbq.movement.assignClickActionRadial = true
			sbq.assignClickActionMenu(state)
		else
			sbq.loopedMessage("radialSelection", sbq.driver, "sbqGetRadialSelection", {}, function(data)

				if data.selection ~= nil and data.type == "actionSelect" then
					sbq.lastRadialSelection = data.selection
					sbq.radialSelectionType = data.type
					if data.selection == "cancel" then return end
					if data.pressed and data.selection == "despawn" then
						if sbq.occupants.total > 0 then
							sbq.letout()
						else
							sbq.onDeath()
						end
						return
					end
					if data.button == 0 and data.pressed and not sbq.click then
						sbq.click = true
						if sbq.grabbing ~= nil then
							sbq.uneat(sbq.grabbing)
							local victim = sbq.grabbing
							sbq.grabbing = nil
							sbq.doTransition(data.selection, { id = victim })
							return
						elseif sbq.seats[sbq.driverSeat].controls.primaryHandItem == "sbqController" then
							world.sendEntityMessage(sbq.driver, "primaryItemData", {assignClickAction = data.selection, directives = sbq.itemActionDirectives, icon = (state.actions[data.selection] or {}).icon })
						elseif sbq.seats[sbq.driverSeat].controls.primaryHandItem == nil then
							world.sendEntityMessage(sbq.driver, "sbqGiveItem", {
								name = "sbqController",
								parameters = { scriptStorage = { clickAction = data.selection, directives = sbq.itemActionDirectives, icon = (state.actions[data.selection] or {}).icon } }
							})
						end
					elseif data.button == 2 and data.pressed and not sbq.click then
						sbq.click = true
						if sbq.grabbing ~= nil then
							sbq.uneat(sbq.grabbing)
							local victim = sbq.grabbing
							sbq.grabbing = nil
							sbq.doTransition(data.selection, { id = victim })
							return
						elseif sbq.seats[sbq.driverSeat].controls.altHandItem == "sbqController" then
							world.sendEntityMessage(sbq.driver, "altItemData", {assignClickAction = data.selection, directives = sbq.itemActionDirectives, icon = (state.actions[data.selection] or {}).icon})
						elseif sbq.seats[sbq.driverSeat].controls.altHandItem == nil then
							world.sendEntityMessage(sbq.driver, "sbqGiveItem", {
								name = "sbqController",
								parameters = { scriptStorage = { clickAction = data.selection, directives = sbq.itemActionDirectives, icon = (state.actions[data.selection] or {}).icon } }
							})
						end
					elseif not data.pressed then
						sbq.click = false
					end
				end
			end)
		end
		return true
	elseif sbq.movement.assignClickActionRadial then
		world.sendEntityMessage( sbq.driver, "sbqOpenInterface", "sbqClose" )
		if sbq.radialSelectionType == "actionSelect" and (not sbq.click) then
			if sbq.lastRadialSelection == "despawn" then
				if sbq.occupants.total > 0 then
					sbq.letout()
				else
					sbq.onDeath()
				end
			elseif sbq.lastRadialSelection ~= "cancel" and sbq.lastRadialSelection ~= nil then
				if sbq.grabbing ~= nil then
					sbq.uneat(sbq.grabbing)
					local victim = sbq.grabbing
					sbq.grabbing = nil
					sbq.doTransition(sbq.lastRadialSelection, { id = victim })
					return
				else
					sbq.action(state, sbq.lastRadialSelection, "force")
				end
			end
		end
		sbq.movement.assignClickActionRadial = nil
	end
end

function sbq.doClickActions(state, dt)
	for name, cooldown in pairs(sbq.clickActionCooldowns) do
		sbq.clickActionCooldowns[name] = math.max( 0, cooldown - dt)
	end

	if sbq.assignClickAction(state) then return end
	if sbq.transformAction() then return end

	if sbq.grabbing ~= nil then sbq.handleGrab() return end

	if (sbq.seats[sbq.driverSeat].controls.primaryHandItem ~= nil) and (not sbq.seats[sbq.driverSeat].controls.primaryHandItem == "sbqController") then
		sbq.action(state, (state.defaultActions or {})[1], "primaryFire")
		sbq.action(state, (state.defaultActions or {})[2], "altFire")
	else
		if (sbq.seats[sbq.driverSeat].controls.primaryHandItem == "sbqController") then
			local action = ((sbq.seats[sbq.driverSeat].controls.primaryHandItemDescriptor.parameters or {}).scriptStorage or {}).clickAction
			if not action or action == "unassigned" then
				action = (state.defaultActions or {})[1]
			end
			sbq.action(state, action, "primaryFire")
		elseif (sbq.seats[sbq.driverSeat].controls.primaryHandItem == nil) then
			sbq.action(state, (state.defaultActions or {})[1], "primaryFire")
		end

		if (sbq.seats[sbq.driverSeat].controls.altHandItem == "sbqController") then
			local action = ((sbq.seats[sbq.driverSeat].controls.altHandItemDescriptor.parameters or {}).scriptStorage or {}).clickAction
			if not action or action == "unassigned" then
				action = (state.defaultActions or {})[2]
			end
			sbq.action(state, action, "altFire")
		elseif (sbq.seats[sbq.driverSeat].controls.altHandItem == nil) then
			sbq.action(state, (state.defaultActions or {})[2], "altFire")
		end
	end
end

function sbq.action(stateData, name, control)
	if name == nil or (stateData.actions or {})[name] == nil then return end
	if not sbq.clickActionCooldowns[name] then
		sbq.clickActionCooldowns[name] = 0
	end

	if sbq.clickActionCooldowns[name] > 0 then return end

	local pressed = (sbq.pressControl(sbq.driverSeat, control))
	local actionData = stateData.actions[name]

	if control == "force" or pressed or actionData.hold and (sbq.heldControl(sbq.driverSeat, control))
	then
		sbq.clickActionCooldowns[name] = actionData.cooldown or 0
		if actionData.script ~= nil then
			if state[sbq.state][actionData.script] ~= nil then
				if not state[sbq.state][actionData.script](actionData, control, pressed) then return end
			else
				sbq.logError("no script named: ["..actionData.script.."] in state: ["..sbq.state.."]")
			end
		end
		local sounds = actionData.sounds
		local cooldown = actionData.cooldown
		local projectiledata = actionData.projectile

		sbq.doTransition(actionData.transition)
		if actionData.animation ~= nil then
			sbq.doAnims(actionData.animation)
		end
		if actionData.projectile ~= nil then
			sbq.projectile(projectiledata, sbq.driver )
		end
		if sounds ~= nil then
			if pressed then
				if sounds.fireStart then
					animator.setSoundPosition(sounds.fireStart, actionData.position or projectiledata.position )
					animator.playSound(sounds.fireStart)
				end
				if sounds.fireLoop then
					animator.setSoundPosition(sounds.fireLoop, actionData.position or projectiledata.position )
					animator.playSound(sounds.fireLoop, -1)
				end
				if sounds.fireEnd then
					animator.setSoundPosition(sounds.fireEnd, actionData.position or projectiledata.position )
				end
			end
			sbq.forceTimer( name.."ActionSounds", (cooldown or 0) + 0.05, function ()
				sbq.stopSounds(sounds)
			end)
		end
	end
end

function sbq.assignClickActionMenu(state)
	local options = {
		{
			name = "despawn",
			icon = "/interface/xhover.png",
			title = "Let Out"
		},
		{
			name = "unassigned",
			icon = "/items/active/sbqController/unassigned.png"..(sbq.itemActionDirectives or "")
		}
	}
	sbq.movement.occupantsWhenAssigned = sbq.occupants.total
	if sbq.occupants.total > 0 then
		options[1].icon = nil
	end

	for action, data in pairs((state.actions or {})) do
		if (sbq.checkSettings(data.settings) ) then
			table.insert(options, {
				name = action,
				icon = ((data.icon) or ("/items/active/sbqController/"..action..".png"))..(sbq.itemActionDirectives or "")
			})
		end
	end

	world.sendEntityMessage( sbq.driver, "sbqOpenInterface", "sbqRadialMenu", {options = options, type = "actionSelect" } )
end

function sbq.checkValidAim(seat, range)
	local entityaimed = world.entityQuery(sbq.seats[seat].controls.aim, range or 2, {
		withoutEntityId = sbq.driver,
		includedTypes = {"creature"}
	})
	local target = sbq.firstNotLounging(entityaimed)

	if target and target ~= entity.id() and entity.entityInSight(target) then
		return target
	end
end

function sbq.checkEatPosition(position, range, location, transition, noaim, aimrange)
	local location, side = sbq.getSidedLocationWithSpace(location, 0.1)
	if location then
		local target = sbq.checkValidAim(sbq.driverSeat, aimrange)

		local prey = world.entityQuery(position, range, {
			withoutEntityId = sbq.driver,
			includedTypes = {"creature"}
		})

		for _, entity in ipairs(prey) do
			if (noaim or (entity == target)) and not sbq.entityLounging(entity) then
				sbq.doTransition( transition, {id=entity} )
				return true
			end
		end
		return false
	end
end

function getDriverStat(eid, stat, callback)
	sbq.addRPC( world.sendEntityMessage(eid, "sbqGetDriverStat", stat), callback)
end

function sbq.driverSeatStateChange()
	if sbq.movement.animating then return end
	local transitions = sbq.stateconfig[sbq.state].transitions
	local dx = 0
	local dy = 0
	if sbq.tapControl(sbq.driverSeat, "left") then
		dx = dx -1
	end
	if sbq.tapControl(sbq.driverSeat, "right") then
		dx = dx +1
	end
	if sbq.tapControl(sbq.driverSeat, "up") then
		dy = dy +1
	end
	if sbq.tapControl(sbq.driverSeat, "down") then
		dy = dy -1
	end
	local movedir = sbq.relativeDirectionName(dx, dy)

	if (movedir == nil) and sbq.tapControl(sbq.driverSeat, "jump") then
		movedir = "jump"
	end

	if movedir ~= nil then
		if transitions[movedir] ~= nil then
			sbq.doTransition(movedir)
		elseif (movedir == "front" or movedir == "back") and transitions.side ~= nil then
			sbq.doTransition("side")
		end
	end
end

function sbq.projectile(projectiledata, driver)
	if projectiledata.energy and driver then
		sbq.useEnergy(driver, projectiledata.cost, function(energyUsed)
			if energyUsed then
				sbq.fireProjectile( projectiledata, driver)
			end
		end)
	else
		sbq.fireProjectile( projectiledata, driver)
	end
end

function sbq.fireProjectile(projectiledata, driver )

	local position = {0,0}
	if projectiledata.position then
		if type(projectiledata.position[1]) == "table" then
			local boundBox = poly.boundBox(projectiledata.position)
			position = rect.randomPoint(boundBox)
			while not world.polyContains(projectiledata.position, position) do
				position = rect.randomPoint(boundBox)
			end
		elseif #projectiledata.position == 4 then
			position = rect.randomPoint(projectiledata.position)
		else
			position = projectiledata.position
		end
	end
	position = sbq.localToGlobal(position)

	local direction
	local params = projectiledata.params or {}

	if projectiledata.aimable then
		sbq.movement.aimingLock = 0.1

		local aiming = sbq.seats[sbq.driverSeat].controls.aim
		params.targetPosition = aiming
		sbq.facePoint( aiming[1] )
		aiming[2] = aiming[2] + (projectiledata.aimAdjust or 0) * sbq.direction * (aiming[1] - position[1])
		direction = world.distance(aiming, position)
	else
		direction = { sbq.direction, 0 }
	end

	if driver then
		params.powerMultiplier = sbq.seats[sbq.driverSeat].controls.powerMultiplier
		world.spawnProjectile( projectiledata.name, position, driver, direction, projectiledata.relative, params )
	else
		params.powerMultiplier = sbq.objectPowerLevel()
		world.spawnProjectile( projectiledata.name, position, entity.id(), direction, projectiledata.relative, params )
	end
end

function sbq.stopSounds(sounds)
	if sounds.fireStart then
		animator.stopAllSounds(sounds.fireStart)
	end
	if sounds.fireLoop then
		animator.stopAllSounds(sounds.fireLoop)
	end
	if sounds.fireEnd then
		animator.playSound(sounds.fireEnd)
	end
end

function sbq.grab(location, aimrange, grabrange)
	local target = sbq.checkValidAim(sbq.driverSeat, aimrange or 2)
	if target then
		sbq.addRPC(world.sendEntityMessage(target, "sbqIsPreyEnabled", "held"), function(enabled)
			if enabled and enabled.enabled then
				local prey = world.entityQuery(mcontroller.position(), grabrange or 5, {
					withoutEntityId = sbq.driver,
					includedTypes = {"creature"}
				})
				for _, entity in ipairs(prey) do
					if entity == target then
						if sbq.eat({id = target, size = enabled.size or 1}, "held", location) then
							sbq.grabbing = target
							sbq.movement.clickActionsDisabled = true
						end
					end
				end
			end
		end)
		return true
	end
end

function sbq.letGrabGo(location)
	local victim = sbq.findFirstOccupantIdForLocation(location)
	sbq.grabbing = nil
	sbq.armRotation.enabledL = false
	sbq.armRotation.enabledR = false
	sbq.armRotation.groupsR = {}
	sbq.armRotation.groupsL = {}
	sbq.armRotation.occupantL = nil
	sbq.armRotation.occupantR = nil
	sbq.uneat(victim)
end
