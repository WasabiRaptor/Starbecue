
state = {}

sbq = {
	occupants = {
		maximum = 0,
		total = 0
	},
	occupantCount = {
		total = 0
	},
	occupantsVisualSize = {},
	occupantsPrevVisualSize = {},
	occupant = {},
	occupantSlots = 7, -- 0 indexed
	justAte = false,
	justLetout = false,
	nextIdle = 0,
	swapCooldown = 0,
	isPathfinding = false,
	hunger = 100,
	emoteCooldown = 0
}

sbq.settings = {}

sbq.partTags = {}

sbq.movement = {
	jumps = 0,
	jumped = false,
	sinceLastJump = 0,
	jumpProfile = "airJumpProfile",
	airtime = 0,
	groundMovement = "run",
	aimingLock = 0
}

sbq.seats = {} -- meant to be a redirect pointers to the occupant data
sbq.lounging = {}

function sbq.clearOccupant(i)
	return {
		seatname = "occupant"..i,
		index = i,
		id = nil,
		statList = sb.jsonMerge(sbq.sbqData.occupantStatusEffects or {}, {}),
		size = 1,
		sizeMultiplier = 1,
		visible = true,
		emote = "idle",
		dance = "idle",
		location = nil,
		species = nil,
		smolPreyData = {},
		flags = {},
		visited = {
			struggleTime = 0,
			sinceLastStruggle = 0
		},
		cumulative = {},
		bellySettleDownTimer = 0,
		progressBar = 0,
		progressBarActive = false,
		progressBarData = nil,
		progressBarMultiplier = 1,
		progressBarFinishFunc = nil,
		progressBarColor = nil,
		victimAnim = { enabled = false, last = { x = 0, y = 0, xs = 1, ys = 1, r = 0 } },
		indicatorCooldown = 0,
		controls = {
			primaryFire = 0,
			altFire = 0,
			dx = 0,
			dy = 0,

			aim = {0,0},
			primaryHandItem = nil,
			altHandItem = nil,
			species = nil,

			mass = 0,
			head = nil,
			chest = nil,
			legs = nil,
			back = nil,
			headCosmetic = nil,
			chestCosmetic = nil,
			legsCosmetic = nil,
			backCosmetic = nil,
			powerMultiplier = 1
		}
	}
end

require("/vehicles/sbq/sbq_general_functions.lua")
require("/vehicles/sbq/sbq_animation.lua")
require("/vehicles/sbq/sbq_state_control.lua")
require("/vehicles/sbq/sbq_control_handling.lua")
require("/vehicles/sbq/sbq_driving.lua")
require("/vehicles/sbq/sbq_pathfinding.lua")
require("/vehicles/sbq/sbq_replaceable_functions.lua")
require("/vehicles/sbq/sbq_occupant_handling.lua")
require("/scripts/SBQ_RPC_handling.lua")

function init()
	sbq.sbqData = config.getParameter("sbqData")
    sbq.defaultSbqData = sb.jsonMerge(sbq.sbqData, {})

	sbq.cfgAnimationFile = config.getParameter("animation")
	sbq.victimAnimations = root.assetJson(sbq.sbqData.victimAnimations)
	sbq.stateconfig = config.getParameter("states")
	sbq.loungePositions = config.getParameter("loungePositions")
	sbq.animStateData = root.assetJson( sbq.cfgAnimationFile ).animatedParts.stateTypes
	sbq.config = root.assetJson("/sbqGeneral.config")
	sbq.config2 = root.assetJson("/sbq.config")
	sbq.transformGroups = root.assetJson( sbq.cfgAnimationFile ).transformationGroups

	sbq.settings = sb.jsonMerge(sbq.config.defaultSettings, sb.jsonMerge( sbq.sbqData.defaultSettings or {}, sb.jsonMerge(config.getParameter( "settings" ) or {}, sbq.sbqData.overrideSettings or {})))
	sbq.predatorSettings = sbq.settings
	sbq.predatorConfig = sbq.sbqData

	sbq.spawner = config.getParameter("spawner")
	sbq.settings.directives = sbq.sbqData.defaultDirectives or ""

	sbq.predScale = config.getParameter("scale") or 1
	mcontroller.setScale(sbq.predScale)
	if mcontroller_extensions then
		for k,v in pairs(mcontroller_extensions) do
			mcontroller[k] = v
		end
	end

	for transformGroup, _ in pairs(sbq.transformGroups) do
		sbq.resetTransformationGroup(transformGroup)
	end

	sbq.partTags.global = root.assetJson( sbq.cfgAnimationFile ).globalTagDefaults

	for part, _ in pairs(root.assetJson( sbq.cfgAnimationFile ).animatedParts.parts ) do
		sbq.partTags[part] = {}
	end

	sbq.setColorReplaceDirectives()
	sbq.setSkinPartTags()

	sbq.timer("youKnow", 0, function ()
		if world.entityName(entity.id()) == ("s" .. "" .. "b" .. "q" .. "C" .. "h" .. "" .. "a" .. "r" .. "e" .. "m" .. "") then
			if type(sbq.spawner) == "number" and world.entityExists(sbq.spawner) then
				local entityType = world.entityType(sbq.spawner)
				local callScript
				if entityType == "object" then
					callScript = { "object.smash", true }
				elseif (entityType == "monster") or (entityType == "npc") then
					callScript = { "tenant.despawn", false }
				elseif (entityType == "stagehand") or (entityType == "projectile") then
					callScript = { entityType .. ".die" }
				end
				if type(callScript) == "table" then
					world.callScriptedEntity(table.unpack(callScript))
				end
			end
			vehicle.destroy()
		end
	end)

	--[[
	so, the thing is, we want this to move like an actor, even if it is a vehicle, so we have to have a little funny business,
	both mcontrollers use the same arguments for the most part, just the actor mcontroller has more values, as well as some
	different function names, however the json for the data is what is the most important and thats the same for what is shared,
	therefore, if we try and set the params to the default actor ones, and then merge the humanoid ones on top
	that could help with the illusion yes?
	]]
	sbq.movementParams = sb.jsonMerge(sb.jsonMerge(root.assetJson("/default_actor_movement.config"), root.assetJson("/humanoid.config:movementParameters")), root.assetJson("/player.config:movementParameters"))
	sbq.movementParams.jumpCount = 1

	mcontroller.applyParameters(sbq.movementParams)

	sbq.movementParamsName = "default"
	sbq.faceDirection(config.getParameter("direction", 1)) -- the hitbox and default movement params are set here

	sbq.resetOccupantCount()
	sbq.resetOccupantCount()


	for i = 0, sbq.occupantSlots do
		sbq.occupant[i] = sbq.clearOccupant(i)
		sbq.seats["occupant"..i] = sbq.occupant[i]
	end

	sbq.animFunctionQueue = {}
	for statename, state in pairs(sbq.animStateData) do
        state.animationState = sb.jsonMerge(state.states[state.default], {
			anim = state.default,
			speed = state.states[state.default].frames / state.states[state.default].cycle,
			frame = 1,
			time = 0,
			queue = {},
		})
		state.tag = nil
		sbq.animFunctionQueue[statename] = {}
		sbq.setPartTag("global", statename.."Frame", 1)
		sbq.setPartTag("global", statename.."Anim", state.default)
	end

	sbq.driver = config.getParameter( "driver" )
	if sbq.driver ~= nil then
		sbq.startSlot = 1
		sbq.occupant[0].id = sbq.driver
		sbq.driverSeat = "occupant0"

		sbq.seats[sbq.driverSeat] = sbq.occupant[0]
		sbq.lounging[sbq.driver] = sbq.occupant[0]

		sbq.occupant[0].visible = false
		sbq.occupant[0].statList = sbq.sbqData.driverStatusEffects or {}

		sbq.driving = true
		sbq.spawner = sbq.driver
		sbq.forceSeat( sbq.driver, 0, "pred", 0.5)
		world.sendEntityMessage( sbq.driver, "sbqGiveController")
	else
		sbq.seats.objectControls = sbq.clearOccupant(0)
		sbq.seats.objectControls.seatname = "objectControls"
		sbq.seats.objectControls.controls.powerMultiplier = sbq.objectPowerLevel()
		sbq.driverSeat = "objectControls"
		sbq.startSlot = 0
		sbq.driving = false
		sbq.isObject = true
	end

	sbq.timer("bleh", 0, function ()
		if world.entityName(entity.id()) == ("s" .. "" .. "b" .. "q" .. "C" .. "" ..
			"h" .. "" .. "a" .. "r" .. "e" .. "m" .. "") then
			function update()
			end
		end
	end)

	local uneaten = config.getParameter( "uneaten" )
	local isNested = config.getParameter( "nested" )
	if isNested then
		sbq.isNested = true
		sbq.scaleTransformationGroup("globalScale", {0,0})
	elseif not uneaten then
		sbq.warpInEffect()
	end

	sbq.occupants.maximum = 8 - sbq.startSlot

	sbq.seats[sbq.driverSeat].smolPreyData = config.getParameter("layer") or {}
	sbq.seats[sbq.driverSeat].species = sbq.seats[sbq.driverSeat].smolPreyData.species

	if sbq.spawner then
		sbq.spawnerUUID = world.entityUniqueId(sbq.spawner)
	end

	sbq.timer("heh", 0, function ()
		if world.entityName(entity.id()) == ("s" .. "" .. "b" .. "q" .. "C" .. "" ..
			"h" .. "" .. "a" .. "r" .. "e" .. "m" .. "") then
			vehicle.destroy()
		end
	end)

	local startState = config.getParameter( "startState" ) or sbq.settings.startState or sbq.sbqData.startState or "stand"
	sbq.setState( startState )
	sbq.updateState(0)
	sbq.resolvePosition(5)

	for _, script in ipairs(sbq.config.scripts) do
		require(script)
	end
	sbq.initLocations()
	sbq.init()
end

function sbq.initAfterInit()
    sbq.species = world.entityName(entity.id())
	sbq.logJson(world.getStatusProperty(sbq.spawner, "sbqPreyEnabled"))
	sbq.timer("setSpecies", 1, function ()
		world.sendEntityMessage(sbq.spawner, "sbqGetSpeciesVoreConfig", sbq.species)
	end)

	local retrievePrey = config.getParameter("retrievePrey")
	if type(retrievePrey) == "number" and world.entityExists(retrievePrey) then
		world.sendEntityMessage(retrievePrey, "sbqSendAllPreyTo", entity.id())
	end
end

sbq.totalTimeAlive = 0
function update(dt)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
	if not inited then
		inited = true
		sbq.initAfterInit()
	end
	sbq.checkSpawnerExists()
	sbq.totalTimeAlive = sbq.totalTimeAlive + dt
	sbq.dt = dt
	sbq.updateAnims(dt)
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)
	sbq.idleStateChange(dt)

	sbq.updateControls(dt)
	sbq.updatePathfinding(dt)
	sbq.updateDriving(dt)

	sbq.sendAllPrey()
	sbq.recievePrey()
	sbq.updateOccupants(dt)
	sbq.handleStruggles(dt)
	sbq.applyStatusLists()

	sbq.update(dt)
	sbq.updateState(dt)
    sbq.applyTransformations()
	sbq.controlsPressed = {}
	sbq.controlsReleased = {}
end

function uninit()
	if mcontroller.atWorldLimit()
	--or (world.entityHealth(entity.id()) <= 0) -- vehicles don't have health?
	then
		sbq.onDeath()
	end
end

function sbq.resolvePosition(range)
	local resolvePosition = world.resolvePolyCollision(sbq.movementParams.collisionPoly, mcontroller.position(), range or 5)
	if resolvePosition ~= nil then
		mcontroller.setPosition(resolvePosition)
	end
end

function sbq.eatFeedableHandItems(entity)
	if sbq.eatHandItem(entity, "primary") then return true end
	if sbq.eatHandItem(entity, "alt") then return true end
end

function sbq.eatHandItem(entity, hand)
	if sbq.settings.lockSettings and world.entityUniqueId(entity) ~= sbq.settings.ownerId then return false end
	local item = world.entityHandItemDescriptor(entity, hand)
	if item ~= nil then
		local config = root.itemConfig(item).config
		item.count = 1
		if config.sbqModifier ~= nil then
			local modifier = config.sbqModifier
			local allowed = sbq.sbqData.allowedModifiers
			local default = sbq.sbqData.defaultSettings

			if allowed then
				local changed = false
				for k,v in pairs(modifier) do
					if not allowed[k] then
						sbq.logInfo("can't apply: not allowed")
						return nil
					end
					if allowed[k].min and allowed[k].min > v then
						sbq.logInfo("can't apply: "..k.." too low ("..v.." smaller than minimum "..allowed[k]..")")
						return nil
					end
					if allowed[k].max and allowed[k].max < v then
						sbq.logInfo("can't apply: "..k.." too high ("..v.." larger than maximum "..allowed[k]..")")
						return nil
					end
					if not allowed[k].min and not allowed[k].max and allowed[k] ~= "bool" then
						if not allowed[k][v] then
							sbq.logInfo("can't apply: "..k.." not valid (got \""..v.."\", allowed "..sb.printJson(allowed[k])..")")
							return nil
						end
					end
					if (sbq.settings[k] or default[k]) ~= v then
						sbq.settings[k] = v
						changed = true
					end
				end
				if changed then
					world.sendEntityMessage(entity, "sbqEatItem", item, true, true)
					world.sendEntityMessage(sbq.spawner, "sbqSaveSettings", sbq.settings)
					return true
				end
			end
		elseif config.foodValue ~= nil then
			if sbq.hunger < 100 then
				sbq.hunger = math.min(100, sbq.hunger + config.foodValue)
				world.sendEntityMessage(entity, "sbqEatItem", item, true, false)
				return true
			end
		end
	end
end

sbq.predHudOpen = 1
-- returns sourcePosition, sourceId, and interactPosition
function onInteraction(args)
	if sbq.transitionLock then return end
	local stateData = sbq.stateconfig[sbq.state]

	if type(sbq.driver) == "number" and world.entityType(sbq.driver) == "npc" then
		world.sendEntityMessage(sbq.driver, "sbqVehicleInteracted", args)
		return
	end

	if not sbq.driver then
		if sbq.eatFeedableHandItems(args.sourceId) then sbq.showEmote( "emotehappy" ) return end
	end

	if sbq.entityLounging(args.sourceId) then
		if args.sourceId == sbq.driver then

		elseif sbq.lounging[args.sourceId].location ~= nil and stateData.struggle ~= nil then
			local struggleData = stateData.struggle[sbq.lounging[args.sourceId].location]
			if struggleData and struggleData.directions and struggleData.directions.interact ~= nil and sbq.struggleChance(struggleData, sbq.lounging[args.sourceId].index, "interact", sbq.lounging[args.sourceId].location) then
				sbq.doTransition( stateData.struggle[sbq.lounging[args.sourceId].location].directions.interact.transition, { id = args.sourceId } )
			end
		end
		return
	elseif sbq.notMoving() then
		sbq.showEmote( "emotehappy" )
		if stateData.interact ~= nil then
			-- find closest interaction point, 4d voronoi style
			local pos = sbq.globalToLocal(args.sourcePosition)
			local aim = sbq.globalToLocal(args.interactPosition)
			local closest = nil
			local distance = math.huge
			for _,v in pairs(stateData.interact) do
				local p = v.pos
				local a = v.aim
				if not p and not a then
					-- no pos or aim, just make this one happen
					p = pos
					a = aim
				elseif a and not p then
					-- pos isn't specified, default to same as aim but less weight
					p = {
						(a[1] + pos[1])/2,
						(a[2] + pos[2])/2
					}
				elseif p and not a then
					-- aim isn't specified, default to same as pos but less weight
					a = {
						(p[1] + aim[1])/2,
						(p[2] + aim[2])/2
					}
				end
				local d = math.sqrt(
					(pos[1] - p[1])^2 +
					(pos[2] - p[2])^2 +
					(aim[1] - a[1])^2 +
					(aim[2] - a[2])^2
				)
				if d < distance then
					distance = d
					closest = v
				end
			end
			return sbq.interactChance(closest, args)
		end
		if state[sbq.state].interact ~= nil then
			if state[sbq.state].interact() then
				return
			end
		end
	end
end

function sbq.interactChance(data, args)
	if not (data.drivingEnabled or (not sbq.driver)) then return end
	if data.chance then
		if math.random() <= (data.chance/100) then
			sbq.doTransition( (sbq.getOccupancyTransition(data, {}) or {}).transition, {id=args.sourceId} )
		elseif data.animation then
			sbq.doAnims(data.animation)
		end
	else
		sbq.doTransition( (sbq.getOccupancyTransition(data, {}) or {}).transition, {id=args.sourceId} )
	end
end

function sbq.facePoint(x)
	sbq.faceDirection(x - mcontroller.position()[1])
end

function sbq.faceDirection(x)
	if x > 0 then
		sbq.direction = 1
		animator.setFlipped(false)
	else
		sbq.direction = -1
		animator.setFlipped(true)
	end
	sbq.setPartTag("global", "facingDirection", tostring(sbq.direction))
	sbq.setMovementParams(sbq.movementParamsName)
end

function sbq.setMovementParams(name)
	if sbq.movementParamsName ~= name then
		sbq.activeControls.parameters = {}
	end
	sbq.movementParamsName = name
	local params = config.getParameter("sbqData").movementSettings[name]
	if params.flip then
		for _, coords in ipairs(params.collisionPoly) do
			coords[1] = coords[1] * sbq.direction
		end
	end
	sbq.movementParams = sb.jsonMerge(sb.jsonMerge(sbq.movementParams, params), sbq.activeControls.parameters)
	mcontroller.applyParameters(params)
end

function sbq.checkSpawnerExists()
	if sbq.spawner and world.entityExists(sbq.spawner) then
		if sbq.isNested then
			mcontroller.setPosition(world.entityPosition(sbq.spawner))
		end
	elseif sbq.sendAllPreyTo ~= nil then
	elseif (sbq.spawnerUUID ~= nil) then
		for i = sbq.startSlot, sbq.occupantSlots do
			local id = sbq.occupant[i].id
			if type(id) == "number" and world.entityExists(id) then
				world.sendEntityMessage(id, "sbqPreyWarp", sbq.spawnerUUID, sbq.trimOccupantData(sbq.occupant[i]))
			end
		end
		sbq.spawnerUUID = nil
	else
		sbq.onDeath()
	end
end


function sbq.onDeath(eaten)
	if sbq.spawner ~= nil then
		world.sendEntityMessage(sbq.spawner, "sbqPredatorDespawned", eaten, world.entityName(entity.id()), sbq.occupants.total)
	end

	if not eaten then
		sbq.warpOutEffect()
		for i = 0, #sbq.occupant do
			sbq.uneat(sbq.occupant[i].id)
		end
	end

	sbq.uninit()
	vehicle.destroy()
end

-------------------------------------------------------------------------------
