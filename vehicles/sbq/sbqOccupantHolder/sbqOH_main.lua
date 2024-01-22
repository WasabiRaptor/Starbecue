state = {
	stand = {}
}

sbq = {
	occupants = {
		maximum = 8,
		total = 0,
	},
	occupantCount = {
		total = 0
	},
	occupantsVisualSize = {},
	occupantsPrevVisualSize = {},
	includeDriver = true,
	occupant = {},
	occupantSlots = 7, -- 0 indexed
	justAte = false,
	justLetout = false,
	nextIdle = 0,
	swapCooldown = 0,
	emoteCooldown = 0,
	isPathfinding = false,
	hunger = 100,
	state = "stand",
	direction = 1
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

sbq.movementParams = {
	mass = 0
}

sbq.seats = {} -- meant to be a redirect pointers to the occupant data
sbq.lounging = {}

function sbq.clearOccupant(i)
	return {
		seatname = "occupant"..i,
		index = i,
		id = nil,
		statList = sb.jsonMerge((sbq.sbqData or {}).occupantStatusEffects or {}, {}),
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
require("/vehicles/sbq/sbq_control_handling.lua")
require("/vehicles/sbq/sbq_occupant_handling.lua")
require("/vehicles/sbq/sbq_state_control.lua")
require("/vehicles/sbq/sbq_animation.lua")
require("/vehicles/sbq/sbq_replaceable_functions.lua")
require("/scripts/SBQ_RPC_handling.lua")


require("/vehicles/sbq/sbqOccupantHolder/sbqOH_animation.lua")
function sbq.logInfo(arg)
	sb.logInfo("["..tostring(world.entityName(sbq.spawner)).."]"..tostring(arg))
end

local inited

function init()
	sbq.config = root.assetJson("/sbqGeneral.config")
	sbq.config2 = root.assetJson("/sbq.config")
	sbq.spawner = config.getParameter("spawner") or config.getParameter("driver")
	sbq.driver = sbq.spawner
	sbq.driving = world.entityType(sbq.spawner) == "player"
	sbq.startSlot = 0

	for i = 0, sbq.occupantSlots do
		sbq.occupant[i] = sbq.clearOccupant(i)
		sbq.seats["occupant"..i] = sbq.occupant[i]
	end
	sbq.seats.occupantD = sbq.clearOccupant("D")
	sbq.seats.occupantD.id = sbq.spawner
	sbq.lounging[sbq.spawner] = sbq.seats.occupantD
	sbq.driverSeat = "occupantD"

	for _, script in ipairs(sbq.config.scripts) do
		require(script)
	end

	sbq.timer("init", 0, function ()
		sbq.getInit()
	end)
end

function sbq.getInit()
	sbq.addRPC(world.sendEntityMessage(sbq.spawner, "sbqGetSpeciesVoreConfig"), function (data)
		initAfterInit(table.unpack(data))
		inited = true
	end, function ()
		sbq.getInit()
	end)
end

function initAfterInit(data, scale)
	sbq.sbqData = sb.jsonMerge(config.getParameter("sbqData"), data.sbqData)
	sbq.species = data.species
	sbq.defaultSbqData = sb.jsonMerge(sbq.sbqData, {})
	sbq.cfgAnimationFile = sbq.sbqData.animation
	sbq.victimAnimations = root.assetJson(sbq.sbqData.victimAnimations)
	sbq.stateconfig = sb.jsonMerge(config.getParameter("states"), data.states)
	sbq.loungePositions = config.getParameter("loungePositions")
	sbq.animStateData = root.assetJson( sbq.cfgAnimationFile ).animatedParts.stateTypes
	sbq.transformGroups = {
		globalScale = {},
		occupant0Position = {},
		occupant1Position = {},
		occupant2Position = {},
		occupant3Position = {},
		occupant4Position = {},
		occupant5Position = {},
		occupant6Position = {},
		occupant7Position = {},
    }
	sbq.logJson(world.getStatusProperty(sbq.spawner, "sbqPreyEnabled"))

	sbq.predScale = scale
	mcontroller.setScale(scale)

	sbq.settings = sb.jsonMerge(sbq.config.defaultSettings, sb.jsonMerge( sbq.sbqData.defaultSettings or {}, sb.jsonMerge(config.getParameter( "settings" ) or {}, sbq.sbqData.overrideSettings or {})))
	sbq.predatorSettings = sbq.settings
	sbq.predatorConfig = sbq.sbqData

	sbq.partTags.global = {}

	for part, _ in pairs(root.assetJson( sbq.cfgAnimationFile ).animatedParts.parts) do
		sbq.partTags[part] = {}
	end
	for part, _ in pairs(root.assetJson( "/vehicles/sbq/sbqOccupantHolder/sbqOccupantHolder.animation" ).animatedParts.parts) do
		sbq.partTags[part] = {}
	end

	for transformGroup, _ in pairs(sbq.transformGroups) do
		sbq.resetTransformationGroup(transformGroup)
	end

	sbq.animFunctionQueue = {}
	for statename, state in pairs(sbq.animStateData) do
        state.animationState = sb.jsonMerge(state.states[state.default], {
			anim = state.default,
			speed = state.states[state.default].frames / state.states[state.default].cycle,
			frame = 1,
			time = 0
		})
		sbq.animFunctionQueue[statename] = {}
		state.tag = nil
	end

	if sbq.spawner then
		sbq.spawnerUUID = world.entityUniqueId(sbq.spawner)
	end

	sbq.resetOccupantCount()
	sbq.resetOccupantCount()

	mcontroller.applyParameters({ collisionEnabled = false, frictionEnabled = false, gravityEnabled = false, ignorePlatformCollision = true})

	if sbq.sbqData.scripts ~= nil then
		for _, script in ipairs(sbq.sbqData.scripts) do
			require(script)
		end
	end
	sbq.initLocations()

	local retrievePrey = config.getParameter("retrievePrey")
	if type(retrievePrey) == "number" and world.entityExists(retrievePrey) then
		world.sendEntityMessage(retrievePrey, "sbqSendAllPreyTo", entity.id())
	end

	sbq.settingsMenuUpdated()
end

sbq.totalTimeAlive = 0
function update(dt)
	if world.pointTileCollision(entity.position(), { "Null" }) then return end
	sbq.checkSpawnerExists()
	sbq.totalTimeAlive = sbq.totalTimeAlive + dt
	sbq.dt = dt
	sbq.checkRPCsFinished(dt)
	sbq.checkTimers(dt)

	if not inited then return end

	sbq.getAnimData()
	sbq.updateAnims(dt)

	sbq.updateControls(dt)
	sbq.getSeatData(sbq.seats.occupantD, "occupantD", sbq.driver)
	sbq.openPredHud(dt)

	sbq.sendAllPrey()
	sbq.recievePrey()
	sbq.updateOccupants(dt)
	sbq.handleStruggles(dt)
	sbq.applyStatusLists()

	sbq.update(dt)
    sbq.applyTransformations()
	sbq.controlsPressed = {}
	sbq.controlsReleased = {}
end

function uninit()
end

sbq.predHudOpen = 1

function sbq.openPredHud(dt)
	if ((not sbq.driving) or (sbq.isNested)) or sbq.settings.disableHud then return end
	sbq.predHudOpen = math.max( 0, sbq.predHudOpen - dt )
	if sbq.predHudOpen <= 0 then
		sbq.predHudOpen = 2
		world.sendEntityMessage( sbq.driver, "sbqOpenMetagui", "starbecue:predHud" )
	end
end

function sbq.checkSpawnerExists()
	if sbq.spawner and world.entityExists(sbq.spawner) then
		local position = world.entityPosition(sbq.spawner)
		mcontroller.setPosition({position[1], position[2]})
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
		for i = 0, #sbq.occupant do
			sbq.uneat(sbq.occupant[i].id)
		end
		sbq.getAnimData()
	end

	vehicle.destroy()
end


-------------------------------------------------------------------------------------------------------

function sbq.entityLounging( entity )
	if entity == sbq.spawner then return true end

	for i = 0, sbq.occupantSlots do
		if entity == sbq.occupant[i].id then return true end
	end
	return false
end

function sbq.setStatusValue(name, value)
	world.sendEntityMessage(sbq.driver, "sbqSetStatusValue", name, value)
end

-------------------------------------------------------------------------------------------------------

function sbq.openPreyHud(i, directions, progressbarDx, icon, location)
	sbq.loopedMessage(sbq.occupant[i].id .. "-indicator", sbq.occupant[i].id, -- update quickly but minimize spam
		"sbqOpenInterface", { "sbqIndicatorHud",
		{
			owner = entity.id(),
			directions = directions,
			progress = {
				active = sbq.occupant[i].progressBarActive,
				color = sbq.occupant[i].progressBarColor,
				percent = sbq.occupant[i].progressBar,
				dx = progressbarDx
			},
			icon = icon,
			time = sbq.occupant[i].visited.totalTime,
			location = (sbq.sbqData.locations[location] or {}).name
		},
		entity.id()
	})
end
